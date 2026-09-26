--!strict
-- Инвентарь: Перчатка Бесконечности и 6 камней. Открывается кнопкой слева или клавишей B.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Abilities = require(ReplicatedStorage.Shared.Abilities)
local Items = require(ReplicatedStorage.Shared.Items)

local PlayerState = require(script.Parent.Parent.PlayerState)
local Ui = require(script.Parent.Parent.Ui)

local player = Players.LocalPlayer

local PANEL_SIZE = Vector2.new(640, 400)
local TOGGLE_KEY = Enum.KeyCode.B

type Entry = {
	id: string, -- "Gauntlet" или id камня
	button: TextButton,
	icon: Frame,
	stroke: UIStroke,
	title: TextLabel,
}

local InventoryController = {}

local panel: Frame
local panelScale: UIScale
local entries: { Entry } = {}
local selectedId = "Gauntlet"

local details: {
	icon: Frame,
	name: TextLabel,
	status: TextLabel,
	body: TextLabel,
}
local progressLabel: TextLabel

local function abilityLine(ability: Abilities.Ability, stones: { [string]: boolean }): string
	local unlocked = Abilities.isUnlocked(ability, stones)
	local mark = if unlocked then "✅" else "🔒"
	local hex = ability.color:ToHex()
	return `{mark} <font color="#{hex}"><b>[{ability.keyLabel}] {ability.name}</b></font> — {ability.description}`
end

local function renderDetails()
	local stones = PlayerState.stones()
	if selectedId == "Gauntlet" then
		details.icon.BackgroundColor3 = Items.Gauntlet.color
		details.name.Text = "🧤 " .. Items.Gauntlet.name
		details.name.TextColor3 = Items.Gauntlet.color
		details.status.Text = `Камней в перчатке: {Items.countStones(stones)}/{#Items.Stones}`
		local lines = { Items.Gauntlet.description, "" }
		for _, ability in Abilities.List do
			if ability.kind ~= "stone" then
				table.insert(lines, abilityLine(ability, stones))
			end
		end
		details.body.Text = table.concat(lines, "\n")
		return
	end

	local stone = Items.StoneById[selectedId]
	local owned = stones[stone.id] == true
	details.icon.BackgroundColor3 = if owned then stone.color else Ui.Colors.Locked
	details.name.Text = stone.name
	details.name.TextColor3 = if owned then stone.color else Ui.Colors.Muted
	details.status.Text = if owned then "✅ В перчатке" else "❔ Не найден"
	local lines = {
		stone.description,
		"",
		abilityLine(Abilities.ById[stone.ability], stones),
	}
	if not owned then
		table.insert(lines, "")
		table.insert(lines, `📍 <b>Где искать:</b> {stone.hint}`)
	end
	details.body.Text = table.concat(lines, "\n")
end

local function render()
	local stones = PlayerState.stones()
	progressLabel.Text = `Камни: {Items.countStones(stones)}/{#Items.Stones}`
	for _, entry in entries do
		local selected = entry.id == selectedId
		entry.stroke.Color = if selected then Color3.new(1, 1, 1) else Ui.Colors.PanelLight
		entry.stroke.Thickness = if selected then 3 else 2
		if entry.id ~= "Gauntlet" then
			local stone = Items.StoneById[entry.id]
			local owned = stones[entry.id] == true
			entry.icon.BackgroundColor3 = if owned then stone.color else Ui.Colors.Locked
			entry.title.TextColor3 = if owned then Ui.Colors.Text else Ui.Colors.Muted
		end
	end
	renderDetails()
end

local function createEntry(id: string, name: string, color: Color3, order: number, parent: Instance): Entry
	local stroke = Ui.stroke(Ui.Colors.PanelLight, 2)
	local icon = Ui.gem(color, UDim2.fromScale(0.5, 0.5))
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.Position = UDim2.fromScale(0.5, 0.12)
	local title = Ui.label({
		Size = UDim2.new(1, -8, 0, 14),
		Position = UDim2.new(0, 4, 1, -20),
		Text = name,
		Font = Enum.Font.GothamMedium,
	})
	local button = Ui.create("TextButton", {
		Name = id,
		Text = "",
		LayoutOrder = order,
		BackgroundColor3 = Ui.Colors.PanelLight,
		AutoButtonColor = true,
		Parent = parent,
	}, { Ui.corner(12), stroke, icon, title })

	local entry: Entry = { id = id, button = button, icon = icon, stroke = stroke, title = title }
	button.Activated:Connect(function()
		selectedId = id
		render()
	end)
	return entry
end

local function setOpen(open: boolean)
	if open == panel.Visible then
		return
	end
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
		Name = "Inventory",
		ResetOnSpawn = false,
		DisplayOrder = 10,
		Parent = player:WaitForChild("PlayerGui"),
	})

	-- Кнопка открытия слева по центру.
	local toggle = Ui.create("TextButton", {
		Name = "Toggle",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.5, 0),
		Size = UDim2.fromOffset(60, 60),
		BackgroundColor3 = Ui.Colors.Panel,
		BackgroundTransparency = 0.1,
		Text = "🎒",
		TextScaled = true,
		Font = Enum.Font.GothamBold,
		Parent = gui,
	}, {
		Ui.corner(14),
		Ui.stroke(Ui.Colors.Gold, 2),
		Ui.padding(10),
		Ui.label({
			Size = UDim2.new(1, 20, 0, 14),
			Position = UDim2.new(0, -10, 1, 6),
			Text = if UserInputService.KeyboardEnabled
				then "Инвентарь [B]"
				else "Инвентарь",
			TextColor3 = Ui.Colors.Muted,
		}),
	})
	toggle.Activated:Connect(function()
		setOpen(not panel.Visible)
	end)

	panelScale = Ui.create("UIScale", {})
	panel = Ui.create("Frame", {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.47),
		Size = UDim2.fromOffset(PANEL_SIZE.X, PANEL_SIZE.Y),
		BackgroundColor3 = Ui.Colors.Panel,
		BackgroundTransparency = 0.05,
		Visible = false,
		Parent = gui,
	}, { Ui.corner(16), Ui.stroke(Ui.Colors.Gold, 2), panelScale })

	-- Подгоняем панель под маленькие экраны.
	local fitScale = Ui.create("UIScale", {})
	local wrapper = Ui.create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = panel,
	})
	local function fit()
		local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize
			or Vector2.new(1280, 720)
		local s = math.min(1, (viewport.X - 40) / PANEL_SIZE.X, (viewport.Y - 60) / PANEL_SIZE.Y)
		panel.Size = UDim2.fromOffset(PANEL_SIZE.X * s, PANEL_SIZE.Y * s)
		fitScale.Scale = s
	end
	-- UIScale на обёртке масштабирует содержимое, а размер панели меняем вручную.
	wrapper.Size = UDim2.fromOffset(PANEL_SIZE.X, PANEL_SIZE.Y)
	fitScale.Parent = wrapper
	fit()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end

	-- Шапка.
	Ui.label({
		Size = UDim2.fromOffset(300, 30),
		Position = UDim2.fromOffset(20, 14),
		Text = "ИНВЕНТАРЬ",
		Font = Enum.Font.GothamBlack,
		TextColor3 = Ui.Colors.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = wrapper,
	})
	progressLabel = Ui.label({
		Size = UDim2.fromOffset(160, 20),
		Position = UDim2.fromOffset(PANEL_SIZE.X - 230, 20),
		Text = "",
		TextColor3 = Ui.Colors.Muted,
		TextXAlignment = Enum.TextXAlignment.Right,
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
		setOpen(false)
	end)

	-- Сетка предметов слева.
	local grid = Ui.create("Frame", {
		Position = UDim2.fromOffset(20, 60),
		Size = UDim2.fromOffset(282, 320),
		BackgroundTransparency = 1,
		Parent = wrapper,
	}, {
		Ui.create("UIGridLayout", {
			CellSize = UDim2.fromOffset(88, 88),
			CellPadding = UDim2.fromOffset(9, 9),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	table.insert(entries, createEntry("Gauntlet", "Перчатка", Items.Gauntlet.color, 0, grid))
	for _, stone in Items.Stones do
		local shortName = string.gsub(stone.name, "^Камень ", "")
		table.insert(entries, createEntry(stone.id, shortName, stone.color, stone.order, grid))
	end

	-- Описание выбранного предмета справа.
	local info = Ui.create("Frame", {
		Position = UDim2.fromOffset(318, 60),
		Size = UDim2.fromOffset(302, 320),
		BackgroundColor3 = Ui.Colors.PanelLight,
		BackgroundTransparency = 0.3,
		Parent = wrapper,
	}, { Ui.corner(12) })
	local icon = Ui.gem(Items.Gauntlet.color, UDim2.fromOffset(56, 56), info)
	icon.Position = UDim2.fromOffset(14, 14)
	details = {
		icon = icon,
		name = Ui.label({
			Size = UDim2.fromOffset(214, 26),
			Position = UDim2.fromOffset(80, 16),
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = Enum.Font.GothamBlack,
			Text = "",
			Parent = info,
		}),
		status = Ui.label({
			Size = UDim2.fromOffset(214, 18),
			Position = UDim2.fromOffset(80, 46),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Ui.Colors.Muted,
			Font = Enum.Font.GothamMedium,
			Text = "",
			Parent = info,
		}),
		body = Ui.label({
			Size = UDim2.new(1, -10, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextScaled = false,
			TextSize = 14,
			TextWrapped = true,
			RichText = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Font = Enum.Font.Gotham,
			Text = "",
			Parent = Ui.create("ScrollingFrame", {
				Position = UDim2.fromOffset(14, 84),
				Size = UDim2.fromOffset(280, 224),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollBarThickness = 4,
				ScrollBarImageColor3 = Ui.Colors.Gold,
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				Parent = info,
			}),
		}),
	}
end

function InventoryController:Start()
	build()
	PlayerState.Changed:Connect(function()
		if panel.Visible then
			render()
		end
	end)
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed and input.KeyCode == TOGGLE_KEY then
			setOpen(not panel.Visible)
		end
	end)
end

return InventoryController
