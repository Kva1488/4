--!strict
-- Прокачка: опыт за урон, убийства, босса и арену; уровни с наградой монетами; ежедневные
-- награды за серию входов; титулы над головой (вместе с уровнем).
-- Опыт копится в буфере и записывается раз в секунду, чтобы не слать данные клиенту на каждый удар.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Progression = require(ReplicatedStorage.Shared.Progression)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Damage = require(script.Parent.Parent.Combat.Damage)
local Fx = require(script.Parent.Parent.Combat.Fx)
local DataService = require(script.Parent.DataService)

local ProgressionService = {}

local GOLD = Color3.fromRGB(255, 205, 70)

local pending: { [Player]: number } = {}
local knownTitles: { [Player]: { [string]: boolean } } = {}
local notify: RemoteEvent
local screenFx: RemoteEvent

-- Начислить опыт (дробные значения копятся, в данные попадает целая часть).
-- Геймпасс «x2 опыта» ставит игроку атрибут XpMult.
-- raw = true: без множителя «x2 опыта» (купленные пакеты опыта).
function ProgressionService:AddXp(player: Player, amount: number, raw: boolean?)
	if not raw then
		local mult = player:GetAttribute("XpMult")
		if type(mult) == "number" and mult > 0 then
			amount *= mult
		end
	end
	if amount > 0 and amount < math.huge then
		pending[player] = (pending[player] or 0) + amount
	end
end

-- Переносит накопленный опыт в данные и повышает уровень.
local function flush(player: Player)
	local amount = pending[player]
	if not amount or amount < 1 then
		return
	end
	local whole = math.floor(amount)
	pending[player] = amount - whole
	local gainedLevels: { number } = {}
	local coins = 0
	DataService:Update(player, function(data)
		if data.Level >= Progression.MaxLevel then
			return
		end
		data.Xp += whole
		while data.Level < Progression.MaxLevel and data.Xp >= Progression.xpToNext(data.Level) do
			data.Xp -= Progression.xpToNext(data.Level)
			data.Level += 1
			local reward = Progression.levelReward(data.Level) * DataService:CoinMultiplier(player)
			data.Coins += reward
			coins += reward
			table.insert(gainedLevels, data.Level)
		end
		if data.Level >= Progression.MaxLevel then
			data.Xp = 0
		end
	end)
	if #gainedLevels == 0 then
		return
	end
	local level = gainedLevels[#gainedLevels]
	notify:FireClient(player, `⭐ Уровень {level}! +{coins} монет`, GOLD)
	screenFx:FireClient(player, "LevelUp", Vector3.zero, level)
	-- Золотой столб и искры вокруг героя — видно всем рядом.
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		local ground = root.Position - Vector3.new(0, 2.8, 0)
		Fx.pillar(ground, GOLD, 40, 1.2)
		Fx.ring(ground, GOLD, 10, 0.8)
		Fx.burst(root.Position, GOLD, 50, 30)
		Fx.flash(root.Position, GOLD, 24, 0.8)
		Fx.sound("StonePickup", root.Position, 1, 1.3)
	end
end

-- Надпись над головой: титул (его цветом) и уровень.
local function updateTag(player: Player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local data = DataService:Get(player)
	if not head or not data then
		return
	end
	local tag = head:FindFirstChild("TitleTag") :: BillboardGui?
	if not tag then
		local gui = Instance.new("BillboardGui")
		gui.Name = "TitleTag"
		gui.Size = UDim2.fromOffset(220, 44)
		gui.StudsOffset = Vector3.new(0, 3.2, 0)
		gui.MaxDistance = 90
		gui.LightInfluence = 0
		gui.ResetOnSpawn = false

		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.BackgroundTransparency = 1
		title.Size = UDim2.fromScale(1, 0.55)
		title.Font = Enum.Font.GothamBlack
		title.TextScaled = true
		title.TextStrokeTransparency = 0.3
		title.Parent = gui

		local level = Instance.new("TextLabel")
		level.Name = "Level"
		level.BackgroundTransparency = 1
		level.Position = UDim2.fromScale(0, 0.58)
		level.Size = UDim2.fromScale(1, 0.42)
		level.Font = Enum.Font.GothamBold
		level.TextScaled = true
		level.TextColor3 = GOLD
		level.TextStrokeTransparency = 0.4
		level.Parent = gui

		gui.Parent = head
		tag = gui
	end
	local gui = tag :: BillboardGui
	local titleLabel = gui:FindFirstChild("Title") :: TextLabel
	local levelLabel = gui:FindFirstChild("Level") :: TextLabel
	local title = Progression.TitleById[data.EquippedTitle]
	titleLabel.Visible = title ~= nil
	if title then
		titleLabel.Text = title.name
		titleLabel.TextColor3 = title.color
	end
	levelLabel.Text = `⭐ {data.Level}`
end

local function claimDaily(player: Player): (boolean, string)
	local data = DataService:Get(player)
	if not data then
		return false, "Данные ещё загружаются"
	end
	local today = Progression.today()
	if data.LastDaily == today then
		return false, "Награда уже получена. Приходи завтра!"
	end
	local streak = Progression.nextStreak(data.LastDaily, data.DailyStreak, today)
	local reward = Progression.Daily[streak]
	local coins = reward.coins * DataService:CoinMultiplier(player)
	DataService:Update(player, function(d)
		d.LastDaily = today
		d.DailyStreak = streak
		d.BestStreak = math.max(d.BestStreak, streak)
		d.Coins += coins
	end)
	ProgressionService:AddXp(player, reward.xp)
	task.defer(flush, player)
	return true, `🎁 День {streak}: +{coins} монет и +{reward.xp} опыта`
end

local function equipTitle(player: Player, titleId: unknown): (boolean, string)
	if type(titleId) ~= "string" then
		return false, "Неизвестный титул"
	end
	local data = DataService:Get(player)
	if not data then
		return false, "Данные ещё загружаются"
	end
	if titleId == "" then
		DataService:Update(player, function(d)
			d.EquippedTitle = ""
		end)
		return true, "Титул снят"
	end
	local title = Progression.TitleById[titleId]
	if not title then
		return false, "Неизвестный титул"
	end
	if not Progression.hasTitle(title, data) then
		return false, `Титул закрыт: {title.hint}`
	end
	DataService:Update(player, function(d)
		d.EquippedTitle = title.id
	end)
	return true, `Титул «{title.name}» надет`
end

function ProgressionService:Init()
	notify = Remotes.event("Notify")
	screenFx = Remotes.event("ScreenFx")
	Remotes.func("ClaimDaily").OnServerInvoke = claimDaily
	Remotes.func("EquipTitle").OnServerInvoke = equipTitle
end

function ProgressionService:Start()
	Damage.onDamaged(function(attacker, _humanoid, dealt)
		ProgressionService:AddXp(attacker, dealt / 10 * Progression.Xp.DamagePer10)
	end)
	Damage.onKilled(function(attacker, victim)
		local model = victim.Parent
		if not model or model:GetAttribute("Boss") then
			return -- за босса опыт выдаёт BossService по вкладу в урон
		end
		if Players:GetPlayerFromCharacter(model) then
			ProgressionService:AddXp(attacker, Progression.Xp.PlayerKill)
		elseif model:HasTag("Minion") then
			ProgressionService:AddXp(attacker, Progression.Xp.MinionKill)
		else
			ProgressionService:AddXp(attacker, Progression.Xp.DummyKill)
		end
	end)

	-- Сообщаем о новых титулах (при первой загрузке данных — молча).
	DataService:OnChanged(function(player, data)
		updateTag(player)
		local known = knownTitles[player]
		local now: { [string]: boolean } = {}
		for _, title in Progression.Titles do
			if Progression.hasTitle(title, data) then
				now[title.id] = true
				if known and not known[title.id] then
					notify:FireClient(
						player,
						`🏷️ Новый титул: «{title.name}»! Надень его в наградах [J]`,
						title.color
					)
				end
			end
		end
		knownTitles[player] = now
	end)
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Head", 10)
			updateTag(player)
		end)
		if player.Character then
			task.spawn(updateTag, player)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		flush(player)
		pending[player] = nil
		knownTitles[player] = nil
	end)

	while true do
		task.wait(1)
		for player in pending do
			task.spawn(flush, player)
		end
	end
end

return ProgressionService
