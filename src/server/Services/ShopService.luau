--!strict
-- Магазин: покупка прокачки и скинов, экипировка скина.
-- Также начисляет монеты за время в игре и применяет прокачку здоровья к персонажу.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Shop = require(ReplicatedStorage.Shared.Shop)

local Fx = require(script.Parent.Parent.Combat.Fx)
local DataService = require(script.Parent.DataService)

local ShopService = {}

local PURCHASE_COOLDOWN = 0.25
local lastPurchase: { [Player]: number } = {}

local function applyMaxHealth(player: Player)
	local data = DataService:Get(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not data or not humanoid or humanoid.Health <= 0 then
		return
	end
	local maxHealth = Shop.maxHealth(data.Upgrades)
	if humanoid.MaxHealth ~= maxHealth then
		local ratio = humanoid.Health / humanoid.MaxHealth
		humanoid.MaxHealth = maxHealth
		humanoid.Health = maxHealth * ratio
	end
end

local function celebrate(player: Player, color: Color3)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		Fx.burst(root.Position, color, 40, 25)
		Fx.sound("Purchase", root.Position, 0.8, 1.2)
	end
end

local function buyUpgrade(player: Player, upgradeId: string): (boolean, string)
	local upgrade = Shop.UpgradeById[upgradeId]
	local data = DataService:Get(player)
	if not upgrade or not data then
		return false, "Неизвестная прокачка"
	end
	local level = data.Upgrades[upgradeId] or 0
	local cost = Shop.upgradeCost(upgrade, level)
	if not cost then
		return false, "Уже максимальный уровень"
	end
	if data.Coins < cost then
		return false, `Не хватает {cost - data.Coins} 🪙`
	end
	DataService:Update(player, function(d)
		d.Coins -= cost
		d.Upgrades[upgradeId] = level + 1
	end)
	applyMaxHealth(player)
	celebrate(player, Color3.fromRGB(255, 215, 90))
	return true, `{upgrade.name}: уровень {level + 1}!`
end

local function buySkin(player: Player, skinId: string): (boolean, string)
	local skin = Shop.SkinById[skinId]
	local data = DataService:Get(player)
	if not skin or not data then
		return false, "Неизвестный скин"
	end
	if data.Skins[skinId] then
		return false, "Скин уже куплен"
	end
	if data.Coins < skin.price then
		return false, `Не хватает {skin.price - data.Coins} 🪙`
	end
	DataService:Update(player, function(d)
		d.Coins -= skin.price
		d.Skins[skinId] = true
		d.EquippedSkin = skinId
	end)
	celebrate(player, skin.color)
	return true, `Скин «{skin.name}» куплен и надет!`
end

local function equipSkin(player: Player, skinId: string): (boolean, string)
	local data = DataService:Get(player)
	if not data or not data.Skins[skinId] then
		return false, "Скин не куплен"
	end
	DataService:Update(player, function(d)
		d.EquippedSkin = skinId
	end)
	return true, `Надет скин «{Shop.SkinById[skinId].name}»`
end

local function onPurchase(player: Player, kind: unknown, id: unknown): (boolean, string)
	if typeof(kind) ~= "string" or typeof(id) ~= "string" then
		return false, "Неверный запрос"
	end
	local now = os.clock()
	if now - (lastPurchase[player] or 0) < PURCHASE_COOLDOWN then
		return false, "Слишком быстро"
	end
	lastPurchase[player] = now

	if kind == "upgrade" then
		return buyUpgrade(player, id)
	elseif kind == "skin" then
		return buySkin(player, id)
	elseif kind == "equip" then
		return equipSkin(player, id)
	end
	return false, "Неверный запрос"
end

function ShopService:Init()
	Remotes.func("ShopPurchase").OnServerInvoke = onPurchase
end

function ShopService:Start()
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Humanoid", 10)
			applyMaxHealth(player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastPurchase[player] = nil
	end)
	-- Первая загрузка данных тоже должна выставить здоровье.
	DataService:OnChanged(function(player)
		applyMaxHealth(player)
	end)

	-- Монеты за время в игре.
	while true do
		task.wait(Config.Rewards.PlaytimeInterval)
		for _, player in Players:GetPlayers() do
			DataService:Update(player, function(d)
				d.Coins += Config.Rewards.Playtime
			end)
		end
	end
end

return ShopService
