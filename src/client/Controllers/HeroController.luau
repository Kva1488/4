--!strict
-- Меню героев: Танос, Локи и Локи, бог времени. Открывается кнопкой слева или клавишей H.
-- Бог времени открывается после 25 убийств за Локи — прогресс показан на карточке.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Abilities = require(ReplicatedStorage.Shared.Abilities)
local Heroes = require(ReplicatedStorage.Shared.Heroes)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local PlayerState = require(script.Parent.Parent.PlayerState)
local Ui = require(script.Parent.Parent.Ui)
local NotifyController = require(script.Parent.NotifyController)

local player = Players.LocalPlayer

local PANEL_SIZE = Vector2.new(660, 440)
local TOGGLE_KEY = Enum.KeyCode.H
local CARD_WIDTH = 200

type Card = {
	hero: Heroes.Hero,
	stroke: UIStroke,
	button: TextButton,
	progress: Frame,
	progressFill: Frame,
}

local HeroController = {}

local panel: Frame
local panelScale: UIScale
local cards: { Card } = {}
local selectHero: RemoteFunction
local busy = false

local function render()
	local data = PlayerState.get()
	if not data then
		return
	end
	for _, card in cards do
		local hero = card.hero
		local unlocked = Heroes.isUnlocked(hero, data.LokiKills)
		local selected = data.Hero == hero.id
		card.stroke.Color = if selected then hero.color else Ui.Colors.PanelLight
		card.stroke.Thickness = if selected then 3 else 2
		card.progress.Visible = not unlocked
		if selected then
			card.button.Text = "ВЫБРАН ✓"
			card.button.BackgroundColor3 = hero.color
		elseif unlocked then
			card.button.Text = "ВЫБРАТЬ"
			card.button.BackgroundColor3 = Color3.fromRGB(70, 190, 100)
		else
			local need = hero.unlockLokiKills or 0
			card.button.Text = `🔒 {data.LokiKills}/{need} убийств за Локи`
			card.button.BackgroundColor3 = Ui.Colors.Locked
			card.progressFill.Size = UDim2.fromScale(math.clamp(data.LokiKills / math.max(need, 1), 0, 1), 1)
		end
	end
end

local function choose(hero: Heroes.Hero)
	if busy then
		return
	end
	busy = true
	local ok, success, message = pcall(function()
		return selectHero:InvokeServer(hero.id)
	end)
	busy = false
	if not ok then
		NotifyController.show("Ошибка связи с сервером", Color3.fromRGB(255, 90, 90))
	elseif success then
		NotifyController.show(message, hero.color)
		Ui.togglePanel("Heroes", false)
	else
		NotifyController.show(message, Color3.fromRGB(255, 90, 90))
	end
end

local function createCard(hero: Heroes.Hero, index: number, parent: Instance): Card
	local stroke = Ui.stroke(Ui.Colors.PanelLight, 2)
	local card = Ui.create("Frame", {
		Size = UDim2.fromOffset(CARD_WIDTH, 350),
		BackgroundColor3 = Ui.Colors.PanelLight,
		LayoutOrder = index,
		Parent = parent,
	}, {
		Ui.corner(14),
		stroke,
		Ui.create("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(hero.color:Lerp(Color3.new(0, 0, 0), 0.55), Ui.Colors.PanelLight),
		}),
	})
	Ui.label({
		Size = UDim2.new(1, 0, 0, 54),
		Position = UDim2.fromOffset(0, 10),
		Text = hero.icon,
		Parent = card,
	})
	Ui.label({
		Size = UDim2.new(1, -16, 0, 24),
		Position = UDim2.fromOffset(8, 68),
		Text = hero.name,
		Font = Enum.Font.GothamBlack,
		TextColor3 = hero.color,
		Parent = card,
	})
	Ui.label({
		Size = UDim2.new(1, -16, 0, 16),
		Position = UDim2.fromOffset(8, 93),
		Text = hero.title,
		TextColor3 = Ui.Colors.Muted,
		Font = Enum.Font.GothamMedium,
		Parent = card,
	})

	-- Описание и список способностей.
	local lines = { hero.description, "" }
	for _, ability in Abilities.forHero(hero.id) do
		table.insert(
			lines,
			`<font color="#{ability.color:ToHex()}"><b>[{ability.keyLabel}]</b></font> {ability.name}`
		)
	end
	local scroll = Ui.create("ScrollingFrame", {
		Position = UDim2.fromOffset(10, 116),
		Size = UDim2.new(1, -20, 0, 170),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = hero.color,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = card,
	})
	Ui.label({
		Size = UDim2.new(1, -6, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextScaled = false,
		TextSize = 13,
		TextWrapped = true,
		RichText = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Font = Enum.Font.Gotham,
		Text = table.concat(lines, "\n"),
		Parent = scroll,
	})

	local progressFill = Ui.create("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = hero.color,
	}, { Ui.corner(4) })
	local progress = Ui.create("Frame", {
		Position = UDim2.new(0, 12, 1, -58),
		Size = UDim2.new(1, -24, 0, 6),
		BackgroundColor3 = Color3.fromRGB(20, 18, 28),
		Visible = false,
		Parent = card,
	}, { Ui.corner(4), progressFill })

	local button = Ui.create("TextButton", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.new(1, -20, 0, 38),
		Text = "",
		TextScaled = true,
		Font = Enum.Font.GothamBlack,
		TextColor3 = Color3.new(1, 1, 1),
		Parent = card,
	}, { Ui.corner(10), Ui.padding(8) })
	Ui.bounce(button)
	button.Activated:Connect(function()
		choose(hero)
	end)

	return { hero = hero, stroke = stroke, button = button, progress = progress, progressFill = progressFill }
end

local function setVisible(open: boolean)
	if open then
		render()
		panel.Visible = true
		panelScale.Scale = 0.85
		TweenService:Create(panelScale, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	else
		panel.Visible = false
	end
end

local function build()
	local gui = Ui.create("ScreenGui", {
		Name = "Heroes",
		ResetOnSpawn = false,
		DisplayOrder = 10,
		Parent = player:WaitForChild("PlayerGui"),
	})

	local accent = Color3.fromRGB(110, 255, 150)
	local toggle = Ui.create("TextButton", {
		Name = "Toggle",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.5, 96),
		Size = UDim2.fromOffset(60, 60),
		BackgroundColor3 = Ui.Colors.Panel,
		BackgroundTransparency = 0.1,
		Text = "🦸",
		TextScaled = true,
		Font = Enum.Font.GothamBold,
		Parent = gui,
	}, {
		Ui.corner(14),
		Ui.stroke(accent, 2),
		Ui.padding(10),
		Ui.label({
			Size = UDim2.new(1, 20, 0, 14),
			Position = UDim2.new(0, -10, 1, 6),
			Text = if UserInputService.KeyboardEnabled then "Герои [H]" else "Герои",
			TextColor3 = Ui.Colors.Muted,
		}),
	})
	Ui.bounce(toggle)
	toggle.Activated:Connect(function()
		Ui.togglePanel("Heroes")
	end)

	panelScale = Ui.create("UIScale", {})
	panel = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.47),
		Size = UDim2.fromOffset(PANEL_SIZE.X, PANEL_SIZE.Y),
		BackgroundColor3 = Ui.Colors.Panel,
		BackgroundTransparency = 0.05,
		Visible = false,
		Parent = gui,
	}, { Ui.corner(16), Ui.stroke(accent, 2), panelScale })

	local wrapper = Ui.create("Frame", {
		Size = UDim2.fromOffset(PANEL_SIZE.X, PANEL_SIZE.Y),
		BackgroundTransparency = 1,
		Parent = panel,
	})
	local fitScale = Ui.create("UIScale", { Parent = wrapper })
	local function fit()
		local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize
			or Vector2.new(1280, 720)
		local s = math.min(1, (viewport.X - 40) / PANEL_SIZE.X, (viewport.Y - 60) / PANEL_SIZE.Y)
		panel.Size = UDim2.fromOffset(PANEL_SIZE.X * s, PANEL_SIZE.Y * s)
		fitScale.Scale = s
	end
	fit()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end

	Ui.label({
		Size = UDim2.fromOffset(300, 30),
		Position = UDim2.fromOffset(20, 14),
		Text = "ГЕРОИ",
		Font = Enum.Font.GothamBlack,
		TextColor3 = accent,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = wrapper,
	})
	local close = Ui.create("TextButton", {
		Size = UDim2.fromOffset(32, 32),
		Position = UDim2.fromOffset(PANEL_SIZE.X - 50, 14),
		BackgroundColor3 = Ui.Colors.PanelLight,
		Text = "✕",
		TextColor3 = Ui.Colors.Text,
		TextScaled = true,
		Font = Enum.Font.GothamBold,
		Parent = wrapper,
	}, { Ui.corner(8), Ui.padding(6) })
	close.Activated:Connect(function()
		Ui.togglePanel("Heroes", false)
	end)

	local row = Ui.create("Frame", {
		Position = UDim2.fromOffset(20, 64),
		Size = UDim2.fromOffset(PANEL_SIZE.X - 40, 350),
		BackgroundTransparency = 1,
		Parent = wrapper,
	}, {
		Ui.create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for index, hero in Heroes.List do
		table.insert(cards, createCard(hero, index, row))
	end

	Ui.registerPanel("Heroes", setVisible)
end

function HeroController:Init()
	selectHero = Remotes.func("SelectHero")
end

function HeroController:Start()
	build()
	PlayerState.Changed:Connect(function()
		if panel.Visible then
			render()
		end
	end)
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed and input.KeyCode == TOGGLE_KEY then
			Ui.togglePanel("Heroes")
		end
	end)
end

return HeroController
