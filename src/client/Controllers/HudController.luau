--!strict
-- HUD слева сверху: монеты (с анимацией счёта и всплывающими "+N"), камни, здоровье,
-- уровень и полоска опыта.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Items = require(ReplicatedStorage.Shared.Items)
local Progression = require(ReplicatedStorage.Shared.Progression)

local PlayerState = require(script.Parent.Parent.PlayerState)
local Ui = require(script.Parent.Parent.Ui)

local player = Players.LocalPlayer

local HudController = {}

local coinsLabel: TextLabel
local stonesLabel: TextLabel
local coinsRow: Frame
local healthFill: Frame
local healthText: TextLabel
local levelLabel: TextLabel
local xpFill: Frame
local xpText: TextLabel

local shownCoins = 0
local targetCoins = 0
local lastCoins: number? = nil

local function popup(amount: number)
	local positive = amount > 0
	local label = Ui.label({
		Size = UDim2.fromOffset(90, 22),
		Position = UDim2.new(1, 8, 0.5, -11),
		Text = (if positive then "+" else "") .. tostring(amount),
		TextColor3 = if positive then Color3.fromRGB(255, 225, 100) else Color3.fromRGB(255, 110, 110),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.GothamBlack,
		Parent = coinsRow,
	})
	Ui.create("UIStroke", { Thickness = 1.5, Transparency = 0.3, Parent = label })
	TweenService:Create(label, TweenInfo.new(1, Enum.EasingStyle.Quad), {
		Position = UDim2.new(1, 8, 0.5, -40),
		TextTransparency = 1,
	}):Play()
	task.delay(1, function()
		label:Destroy()
	end)

	-- Иконка монеты "подпрыгивает".
	local scale = coinsRow:FindFirstChildOfClass("UIScale") :: UIScale
	scale.Scale = 1.15
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

local function onData()
	local data = PlayerState.get()
	if not data then
		return
	end
	targetCoins = data.Coins
	if lastCoins and data.Coins ~= lastCoins then
		popup(data.Coins - lastCoins)
	end
	lastCoins = data.Coins
	stonesLabel.Text = `💎 {Items.countStones(data.Stones)}/{#Items.Stones}`
	local maxed = data.Level >= Progression.MaxLevel
	local need = Progression.xpToNext(data.Level)
	levelLabel.Text = `⭐ {data.Level}`
	xpText.Text = if maxed then "МАКС." else `{data.Xp} / {need}`
	TweenService:Create(xpFill, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
		Size = UDim2.fromScale(if maxed then 1 else math.clamp(data.Xp / need, 0, 1), 1),
	}):Play()
end

local function row(order: number, parent: Instance): Frame
	return Ui.create("Frame", {
		Size = UDim2.fromOffset(170, 38),
		BackgroundColor3 = Ui.Colors.Panel,
		BackgroundTransparency = 0.2,
		LayoutOrder = order,
		Parent = parent,
	}, { Ui.corner(10), Ui.stroke(Ui.Colors.Gold, 1.5, 0.5), Ui.create("UIScale", {}) })
end

local function bindHealth(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	local function update()
		local ratio = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
		TweenService:Create(healthFill, TweenInfo.new(0.2), {
			Size = UDim2.fromScale(ratio, 1),
			BackgroundColor3 = Color3.fromRGB(230, 60, 60):Lerp(Color3.fromRGB(80, 220, 110), ratio),
		}):Play()
		healthText.Text = `{math.ceil(humanoid.Health)} / {math.floor(humanoid.MaxHealth)}`
	end
	humanoid.HealthChanged:Connect(update)
	humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(update)
	update()
end

function HudController:Start()
	pcall(function()
		game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	end)

	local gui = Ui.create("ScreenGui", {
		Name = "Hud",
		ResetOnSpawn = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local column = Ui.create("Frame", {
		Position = UDim2.fromOffset(16, 16),
		Size = UDim2.fromOffset(220, 180),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		Ui.create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	coinsRow = row(1, column)
	coinsLabel = Ui.label({
		Size = UDim2.new(1, -20, 1, -12),
		Position = UDim2.fromOffset(10, 6),
		Text = "🪙 0",
		TextColor3 = Color3.fromRGB(255, 215, 90),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.GothamBlack,
		Parent = coinsRow,
	})

	local stonesRow = row(2, column)
	stonesLabel = Ui.label({
		Size = UDim2.new(1, -20, 1, -12),
		Position = UDim2.fromOffset(10, 6),
		Text = "💎 0/6",
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = stonesRow,
	})

	local healthRow = row(3, column)
	healthRow.Size = UDim2.fromOffset(170, 22)
	healthFill = Ui.create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(80, 220, 110),
		Parent = healthRow,
	}, { Ui.corner(10) })
	healthText = Ui.label({
		Size = UDim2.new(1, 0, 1, -6),
		Position = UDim2.fromOffset(0, 3),
		Text = "",
		ZIndex = 2,
		Parent = healthRow,
	})

	-- Уровень: значок и полоска опыта.
	local levelRow = row(4, column)
	levelRow.Size = UDim2.fromOffset(170, 26)
	levelLabel = Ui.label({
		Size = UDim2.fromOffset(44, 18),
		Position = UDim2.fromOffset(6, 4),
		Text = "⭐ 1",
		TextColor3 = Color3.fromRGB(255, 215, 90),
		Font = Enum.Font.GothamBlack,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = levelRow,
	})
	local xpTrack = Ui.create("Frame", {
		Position = UDim2.fromOffset(52, 7),
		Size = UDim2.new(1, -60, 0, 12),
		BackgroundColor3 = Ui.Colors.PanelLight,
		Parent = levelRow,
	}, { Ui.corner(6) })
	xpFill = Ui.create("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Color3.fromRGB(120, 170, 255),
		Parent = xpTrack,
	}, {
		Ui.corner(6),
		Ui.create("UIGradient", {
			Color = ColorSequence.new(Color3.fromRGB(110, 150, 255), Color3.fromRGB(200, 120, 255)),
		}),
	})
	xpText = Ui.label({
		Size = UDim2.fromScale(1, 1),
		Text = "",
		ZIndex = 2,
		Font = Enum.Font.GothamBold,
		Parent = xpTrack,
	})

	PlayerState.Changed:Connect(onData)
	onData()

	player.CharacterAdded:Connect(bindHealth)
	if player.Character then
		task.spawn(bindHealth, player.Character)
	end

	-- Плавный "накрут" числа монет.
	RunService.RenderStepped:Connect(function(dt: number)
		if shownCoins ~= targetCoins then
			local diff = targetCoins - shownCoins
			local step = math.max(1, math.abs(diff) * math.min(1, dt * 8))
			shownCoins = if math.abs(diff) <= step then targetCoins else shownCoins + math.sign(diff) * step
			coinsLabel.Text = `🪙 {math.floor(shownCoins)}`
		end
	end)
end

return HudController
