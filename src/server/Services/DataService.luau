--!strict
-- Сохранение данных игроков в DataStore.
-- Загрузка с повторами, автосейв, сохранение при выходе и при выключении сервера.
-- В Studio без включённого "Enable Studio Access to API Services" работает в памяти.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

type PlayerData = Config.PlayerData

local MAX_RETRIES = 3

local DataService = {}

local store: DataStore? = nil
local profiles: { [Player]: PlayerData } = {}
local readOnly: { [Player]: true } = {}
local changedListeners: { (Player, PlayerData) -> () } = {}

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

local function reconcile(data: any): PlayerData
	local result = table.clone(Config.DefaultData) :: any
	if type(data) == "table" then
		for key, value in data do
			if result[key] ~= nil and typeof(value) == typeof(result[key]) then
				result[key] = value
			end
		end
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
	local ok, err = withRetries(function()
		return (store :: DataStore):UpdateAsync(key(player), function()
			return data
		end)
	end)
	if not ok then
		warn(`[DataService] save failed for {player.Name}: {err}`)
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

	if not player.Parent then
		return
	end
	profiles[player] = reconcile(raw)
	for _, listener in changedListeners do
		task.spawn(listener, player, profiles[player])
	end
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
	for _, listener in changedListeners do
		task.spawn(listener, player, data)
	end
end

function DataService:OnChanged(listener: (Player, PlayerData) -> ())
	table.insert(changedListeners, listener)
	for player, data in profiles do
		task.spawn(listener, player, data)
	end
end

function DataService:Init()
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
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				save(player)
				pending -= 1
			end)
		end
		while pending > 0 do
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
