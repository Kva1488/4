--!strict
-- Покупки за робуксы (Shared/Monetization):
-- • геймпассы проверяются при входе и сразу после покупки, их эффект выдаётся на сервере;
-- • Developer Products (монеты, опыт) — через ProcessReceipt, каждая покупка выдаётся ровно один раз
--   (номер покупки сохраняется в данных игрока);
-- • пока ID = 0, в Studio покупка выдаётся бесплатно для проверки, а в живой игре не продаётся.
-- Клиент только просит купить (remote BuyItem), всё решает сервер.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Heroes = require(ReplicatedStorage.Shared.Heroes)
local Items = require(ReplicatedStorage.Shared.Items)
local Monetization = require(ReplicatedStorage.Shared.Monetization)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Fx = require(script.Parent.Parent.Combat.Fx)
local DataService = require(script.Parent.DataService)
local ProgressionService = require(script.Parent.ProgressionService)
local StoneService = require(script.Parent.StoneService)

local MonetizationService = {}

local MAX_RECEIPTS = 200

local notify: RemoteEvent
local screenFx: RemoteEvent

local function waitForData(player: Player): boolean
	for _ = 1, 60 do
		if DataService:Get(player) then
			return true
		end
		if player.Parent ~= Players then
			return false
		end
		task.wait(0.5)
	end
	return DataService:Get(player) ~= nil
end

local function celebrate(player: Player, color: Color3)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		Fx.pillar(root.Position - Vector3.new(0, 3, 0), color, 60, 1.2)
		Fx.burst(root.Position, color, 60, 35)
		Fx.flash(root.Position, color, 30, 0.8)
		Fx.sound("Purchase", root.Position, 1, 1.1)
	end
end

-- Выдать эффект геймпасса. announce = true — сразу после покупки (с поздравлением).
local function applyPass(player: Player, pass: Monetization.Pass, announce: boolean)
	if not waitForData(player) then
		return
	end
	player:SetAttribute(Monetization.attribute(pass), true)
	local data = DataService:Get(player) :: any
	if pass.kind == "DoubleCoins" then
		player:SetAttribute("CoinMult", Monetization.CoinMultiplier)
	elseif pass.kind == "DoubleXp" then
		player:SetAttribute("XpMult", Monetization.XpMultiplier)
	elseif pass.kind == "Stone" and pass.stone then
		if not data.Stones[pass.stone] then
			StoneService:GiveStone(player, pass.stone)
		end
	elseif pass.kind == "Hero" and pass.hero then
		local hero = Heroes.ById[pass.hero]
		if hero and not data.OwnedHeroes[hero.id] then
			DataService:Update(player, function(d)
				d.OwnedHeroes[hero.id] = true
			end)
			if announce then
				screenFx:FireClient(player, "HeroUnlocked", Vector3.zero, hero.id)
			end
		end
	elseif pass.kind == "StarterPack" then
		if data.Passes.StarterPack then
			return -- набор выдаётся один раз навсегда
		end
		-- Случайные камни из тех, которых ещё нет; за недостающие — монеты.
		local missing = {}
		for _, stone in Items.Stones do
			if not data.Stones[stone.id] then
				table.insert(missing, stone.id)
			end
		end
		local given = 0
		for _ = 1, Monetization.StarterStones do
			if #missing == 0 then
				break
			end
			local stoneId = table.remove(missing, math.random(1, #missing))
			StoneService:GiveStone(player, stoneId :: string)
			given += 1
		end
		local coins = Monetization.StarterCoins + (Monetization.StarterStones - given) * 500
		DataService:Update(player, function(d)
			d.Passes.StarterPack = true
			d.Coins += coins
		end)
		notify:FireClient(
			player,
			`🎒 Стартовый набор: {given} камня и +{coins} монет!`,
			pass.color
		)
		DataService:SaveNow(player)
	end
	if announce then
		notify:FireClient(
			player,
			`{pass.icon} Куплено: {pass.name}. Спасибо за поддержку!`,
			pass.color
		)
		celebrate(player, pass.color)
	end
end

local function grantProduct(player: Player, product: Monetization.Product)
	if product.coins then
		local coins = product.coins
		DataService:Update(player, function(d)
			d.Coins += coins
		end)
	end
	if product.xp then
		ProgressionService:AddXp(player, product.xp, true)
	end
	notify:FireClient(player, `{product.icon} Куплено: {product.name}!`, product.color)
	celebrate(player, product.color)
end

local function checkOwnedPasses(player: Player)
	for _, pass in Monetization.Passes do
		if pass.id ~= 0 then
			local ok, owns =
				pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.id)
			if ok and owns then
				task.spawn(applyPass, player, pass, false)
			end
		end
	end
end

local function processReceipt(receipt: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local product = Monetization.ProductById[receipt.ProductId]
	if not player or not product then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = DataService:Get(player)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(receipt.PurchaseId)
	if data.Receipts[purchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted -- уже выдано раньше
	end
	grantProduct(player, product)
	DataService:Update(player, function(d)
		local count = 0
		for _ in d.Receipts do
			count += 1
		end
		if count >= MAX_RECEIPTS then
			table.clear(d.Receipts) -- старые покупки Roblox повторно не присылает
		end
		d.Receipts[purchaseId] = true
	end)
	DataService:SaveNow(player)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- Запрос покупки от клиента: kind = "pass" | "product", key — из Shared/Monetization.
local function onBuy(player: Player, kind: unknown, key: unknown): (boolean, string)
	if type(key) ~= "string" then
		return false, "Неизвестный товар"
	end
	if kind == "pass" then
		local pass = Monetization.PassByKey[key]
		if not pass then
			return false, "Неизвестный товар"
		end
		if player:GetAttribute(Monetization.attribute(pass)) then
			return false, "Уже куплено"
		end
		if pass.id == 0 then
			if RunService:IsStudio() then
				task.spawn(applyPass, player, pass, true)
				return true, "Тест в Studio: выдано бесплатно (ID ещё не задан)"
			end
			return false, "Скоро в продаже"
		end
		MarketplaceService:PromptGamePassPurchase(player, pass.id)
		return true, ""
	elseif kind == "product" then
		local product = Monetization.ProductByKey[key]
		if not product then
			return false, "Неизвестный товар"
		end
		if product.id == 0 then
			if RunService:IsStudio() then
				grantProduct(player, product)
				return true, "Тест в Studio: выдано бесплатно (ID ещё не задан)"
			end
			return false, "Скоро в продаже"
		end
		MarketplaceService:PromptProductPurchase(player, product.id)
		return true, ""
	end
	return false, "Неизвестный товар"
end

function MonetizationService:Init()
	notify = Remotes.event("Notify")
	screenFx = Remotes.event("ScreenFx")
	Remotes.func("BuyItem").OnServerInvoke = onBuy
	MarketplaceService.ProcessReceipt = processReceipt
end

function MonetizationService:Start()
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local pass = Monetization.PassById[passId]
		if purchased and pass then
			applyPass(player, pass, true)
		end
	end)
	local function onPlayer(player: Player)
		if waitForData(player) then
			checkOwnedPasses(player)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayer, player)
	end
end

return MonetizationService
