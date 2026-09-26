--!strict
-- Сохранение данных игроков в DataStore и их отправка клиенту.
-- Загрузка с повторами, автосейв, сохранение при выходе и при выключении сервера.
-- В Studio без включённого "Enable Studio Access to API Services" работает в памяти.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Items = require(ReplicatedStorage.Shared.Items)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Heroes = require(ReplicatedStorage.Shared.Heroes)
local Shop = require(ReplicatedStorage.Shared.Shop)

type PlayerData = Config.PlayerData

local MAX_RETRIES = 3

local DataService = {}

local store: DataStore? = nil
local profiles: { [Player]: PlayerData } = {}
local readOnly: { [Player]: true } = {}
local changedListeners: { (Player, PlayerData) -> () } = {}
local savesInFlight = 0

local dataChanged: RemoteEvent
local getData: RemoteFunction

local function withRetries<T>(fn: () -> T): (boolean, T | string)
	local lastErr: any
	for attempt = 1, MAX_RETRIES do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastErr = result
		task.wait(attempt)
	end
	return false, tostring(lastErr)
end

local function deepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value :: any do
		copy[k] = deepCopy(v)
	end
	return copy :: any
end

-- Берём дефолтные данные и переносим из сохранения только корректные поля.
local function reconcile(raw: any): PlayerData
	local result = deepCopy(Config.DefaultData)
	if type(raw) ~= "table" then
		return result
	end
	if type(raw.Coins) == "number" and raw.Coins == raw.Coins then
		result.Coins = math.max(0, math.floor(raw.Coins))
	end
	if type(raw.Stones) == "table" then
		for id, owned in raw.Stones do
			if Items.StoneById[id] and owned == true then
				result.Stones[id] = true
			end
		end
	end
	if type(raw.Upgrades) == "table" then
		for _, upgrade in Shop.Upgrades do
			local level = raw.Upgrades[upgrade.id]
			if type(level) == "number" and level == level then
				result.Upgrades[upgrade.id] = math.clamp(math.floor(level), 0, upgrade.max)
			end
		end
	end
	if type(raw.Skins) == "table" then
		for id, owned in raw.Skins do
			if Shop.SkinById[id] and owned == true then
				result.Skins[id] = true
			end
		end
	end
	if type(raw.EquippedSkin) == "string" and result.Skins[raw.EquippedSkin] then
		result.EquippedSkin = raw.EquippedSkin
	end
	for _, stat in { "LokiKills", "UltronKills" } do
		local value = raw[stat]
		if type(value) == "number" and value == value then
			(result :: any)[stat] = math.max(0, math.floor(value))
		end
	end
	local hero = if type(raw.Hero) == "string" then Heroes.ById[raw.Hero] else nil
	if hero and Heroes.isUnlocked(hero, result) then
		result.Hero = hero.id
	end
	return result
end

local function key(player: Player): string
	return `Player_{player.UserId}`
end

local function save(player: Player)
	local data = profiles[player]
	if not data or not store or readOnly[player] then
		return
	end
	savesInFlight += 1
	local ok, err = withRetries(function()
		return (store :: DataStore):UpdateAsync(key(player), function()
			return data
		end)
	end)
	savesInFlight -= 1
	if not ok then
		warn(`[DataService] save failed for {player.Name}: {err}`)
	end
end

local function notifyChanged(player: Player, data: PlayerData)
	for _, listener in changedListeners do
		task.spawn(listener, player, data)
	end
	if player.Parent == Players then
		dataChanged:FireClient(player, data)
	end
end

local function load(player: Player)
	local raw: any = nil
	if store then
		local ok, result = withRetries(function()
			return (store :: DataStore):GetAsync(key(player))
		end)
		if ok then
			raw = result
		elseif RunService:IsStudio() then
			-- В Studio без доступа к API играем на дефолтных данных и ничего не сохраняем.
			warn(
				`[DataService] DataStore недоступен в Studio, данные не сохранятся: {result}`
			)
			readOnly[player] = true
		else
			-- Не пускаем играть с пустыми данными, чтобы не затереть сохранение.
			player:Kick(
				"Не удалось загрузить данные. Попробуйте перезайти."
			)
			return
		end
	end

	if player.Parent ~= Players then
		return
	end
	profiles[player] = reconcile(raw)
	notifyChanged(player, profiles[player])
end

function DataService:Get(player: Player): PlayerData?
	return profiles[player]
end

-- Изменение данных: передай функцию, которая правит таблицу данных.
function DataService:Update(player: Player, mutator: (PlayerData) -> ())
	local data = profiles[player]
	if not data then
		return
	end
	mutator(data)
	notifyChanged(player, data)
end

function DataService:OnChanged(listener: (Player, PlayerData) -> ())
	table.insert(changedListeners, listener)
	for player, data in profiles do
		task.spawn(listener, player, data)
	end
end

function DataService:Init()
	dataChanged = Remotes.event("DataChanged")
	getData = Remotes.func("GetData")
	getData.OnServerInvoke = function(player)
		return profiles[player]
	end

	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName)
	end)
	if ok then
		store = result
	else
		warn(
			`[DataService] DataStore недоступен, данные не будут сохраняться: {result}`
		)
	end
end

function DataService:Start()
	Players.PlayerAdded:Connect(load)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		save(player)
		profiles[player] = nil
		readOnly[player] = nil
	end)

	game:BindToClose(function()
		for player in profiles do
			task.spawn(save, player)
		end
		-- Ждём и эти сохранения, и те, что начались в PlayerRemoving.
		task.wait()
		while savesInFlight > 0 do
			task.wait()
		end
	end)

	while true do
		task.wait(Config.AutosaveInterval)
		for player in profiles do
			task.spawn(save, player)
		end
	end
end

return DataService
