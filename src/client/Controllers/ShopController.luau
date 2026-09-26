--!strict
-- Магазин: прокачка способностей, скины Перчатки и покупки за робуксы (геймпассы и пакеты).
-- Открывается кнопкой слева или клавишей V.
-- Все покупки проверяет сервер (ShopService), клиент только показывает и отправляет запрос.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Monetization = require(ReplicatedStorage.Shared.Monetization)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Shop = require(ReplicatedStorage.Shared.Shop)

local PlayerState = require(script.Parent.Parent.PlayerState)
local Ui = require(script.Parent.Parent.Ui)
local NotifyController = require(script.Parent.NotifyController)

local player = Players.LocalPlayer

local PANEL_SIZE = Vector2.new(640, 430)
local TOGGLE_KEY = Enum.KeyCode.V
local GREEN = Color3.fromRGB(70, 190, 100)
local DISABLED = Color3.fromRGB(70, 66, 84)

local ShopController = {}

local panel: Frame
local panelScale: UIScale
local coinsLabel: TextLabel
local tabButtons: { [string]: TextButton } = {}
local pages: { [string]: Frame } = {}
local currentTab = "Upgrades"
local busy = false
local rainbowPreviews: { Frame } = {}

local purchase: RemoteFunction
local buyItem: RemoteFunction

local function request(kind: string, id: string)
	if busy then
		return
	end
	busy = true
	local ok, success, message = pcall(function()
		return purchase:InvokeServer(kind, id)
	end)
	busy = false
	if not ok then
		NotifyController.show("Ошибка связи с сервером", Color3.fromRGB(255, 90, 90))
	elseif success then
		Ui.playSound("Purchase", 0.6, 1.2)
		NotifyController.show(message, GREEN)
	else
		NotifyController.show(message, Color3.fromRGB(255, 90, 90))
	end
end

local function actionButton(parent: Instance, props: { [string]: any }): TextButton
	local button = Ui.create("TextButton", {
		Text = "",
		TextScaled = true,
		Font = Enum.Font.GothamBlack,
		TextColor3 = Color3.new(1, 1, 1),
		AutoButtonColor = true,
		Parent = parent,
	}, { Ui.corner(10), Ui.padding(8) })
	for key, value in props do
		(button :: any)[key] = value
	end
	Ui.bounce(button)
	return button
end

-- Вкладка "Прокачка".
type UpgradeCard = { pips: { Frame }, button: TextButton, upgrade: Shop.Upgrade }
local upgradeCards: { UpgradeCard } = {}

local function buildUpgrades(page: Frame)
	Ui.create(
		"UIListLayout",
		{ Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = page }
	)
	for index, upgrade in Shop.Upgrades do
		local card = Ui.create("Frame", {
			Size = UDim2.new(1, 0, 0, 92),
			BackgroundColor3 = Ui.Colors.PanelLight,
			LayoutOrder = index,
			Parent = page,
		}, { Ui.corner(12) })
		Ui.label({
			Size = UDim2.fromOffset(56, 56),
			Position = UDim2.fromOffset(14, 18),
			Text = upgrade.icon,
			Parent = card,
		})
		Ui.label({
			Size = UDim2.fromOffset(300, 26),
			Position = UDim2.fromOffset(82, 12),
			Text = upgrade.name,
			Font = Enum.Font.GothamBlack,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = card,
		})
		Ui.label({
			Size = UDim2.fromOffset(330, 18),
			Position = UDim2.fromOffset(82, 40),
			Text = upgrade.description,
			TextColor3 = Ui.Colors.Muted,
			Font = Enum.Font.GothamMedium,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = card,
		})
		local pips = {}
		for i = 1, upgrade.max do
			table.insert(
				pips,
				Ui.create("Frame", {
					Size = UDim2.fromOffset(34, 8),
					Position = UDim2.fromOffset(82 + (i - 1) * 40, 68),
					BackgroundColor3 = DISABLED,
					Parent = card,
				}, { Ui.corner(4) })
			)
		end
		local button = actionButton(card, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -14, 0.5, 0),
			Size = UDim2.fromOffset(150, 48),
		})
		button.Activated:Connect(function()
			request("upgrade", upgrade.id)
		end)
		table.insert(upgradeCards, { pips = pips, button = button, upgrade = upgrade })
	end
end

-- Вкладка "Скины".
type SkinCard = { button: TextButton, stroke: UIStroke, skin: Shop.Skin }
local skinCards: { SkinCard } = {}

local function buildSkins(page: Frame)
	Ui.create("UIGridLayout", {
		CellSize = UDim2.fromOffset(190, 150),
		CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = page,
	})
	for index, skin in Shop.Skins do
		local stroke = Ui.stroke(Ui.Colors.PanelLight, 2)
		local card = Ui.create("Frame", {
			BackgroundColor3 = Ui.Colors.PanelLight,
			LayoutOrder = index,
			Parent = page,
		}, { Ui.corner(12), stroke })
		local preview = Ui.gem(skin.color, UDim2.fromOffset(56, 56), card)
		preview.AnchorPoint = Vector2.new(0.5, 0)
		preview.Position = UDim2.new(0.5, 0, 0, 10)
		if skin.rainbow then
			table.insert(rainbowPreviews, preview)
		end
		Ui.label({
			Size = UDim2.new(1, -16, 0, 20),
			Position = UDim2.fromOffset(8, 72),
			Text = skin.name,
			Parent = card,
		})
		local button = actionButton(card, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -10),
			Size = UDim2.new(1, -24, 0, 38),
		})
		button.Activated:Connect(function()
			local data = PlayerState.get()
			if data and data.Skins[skin.id] then
				request("equip", skin.id)
			else
				request("skin", skin.id)
			end
		end)
		table.insert(skinCards, { button = button, stroke = stroke, skin = skin })
	end
end

-- Вкладка "Робуксы": геймпассы (разово, навсегда) и пакеты монет/опыта (сколько угодно раз).
type RobuxCard = { button: TextButton, pass: Monetization.Pass? }
local robuxCards: { RobuxCard } = {}
local ROBUX_GREEN = Color3.fromRGB(0, 170, 90)

local function buy(kind: string, key: string)
	if busy then
		return
	end
	busy = true
	local ok, success, message = pcall(buyItem.InvokeServer, buyItem, kind, key)
	busy = false
	if not ok then
		NotifyController.show("Ошибка связи с сервером", Color3.fromRGB(255, 90, 90))
	elseif not success then
		NotifyController.show(message, Color3.fromRGB(255, 90, 90))
	elseif message ~= "" then
		NotifyController.show(message, GREEN)
	end
end

local function sectionTitle(page: Instance, text: string, order: number)
	local holder = Ui.create("Frame", {
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Parent = page,
	})
	Ui.label({
		Size = UDim2.new(1, 0, 1, 0),
		Text = text,
		Font = Enum.Font.GothamBlack,
		TextColor3 = Ui.Colors.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = holder,
	})
	return holder
end

local function robuxCard(
	page: Instance,
	order: number,
	icon: string,
	name: string,
	description: string,
	color: Color3
): (Frame, TextButton)
	local card = Ui.create("Frame", {
		BackgroundColor3 = Ui.Colors.PanelLight,
		LayoutOrder = order,
		Parent = page,
	}, {
		Ui.corner(12),
		Ui.stroke(color, 1.5, 0.4),
		Ui.create("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(color:Lerp(Color3.new(0, 0, 0), 0.6), Ui.Colors.PanelLight),
		}),
	})
	Ui.label({
		Size = UDim2.fromOffset(40, 40),
		Position = UDim2.fromOffset(8, 8),
		Text = icon,
		Parent = card,
	})
	Ui.label({
		Size = UDim2.new(1, -60, 0, 20),
		Position = UDim2.fromOffset(52, 10),
		Text = name,
		TextColor3 = color,
		Font = Enum.Font.GothamBlack,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = card,
	})
	Ui.label({
		Size = UDim2.new(1, -60, 0, 34),
		Position = UDim2.fromOffset(52, 32),
		Text = description,
		TextColor3 = Ui.Colors.Muted,
		Font = Enum.Font.GothamMedium,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = card,
	})
	local button = actionButton(card, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.new(1, -16, 0, 32),
		BackgroundColor3 = ROBUX_GREEN,
	})
	return card, button
end

local function buildRobux(page: Frame)
	Ui.create("UIGridLayout", {
		CellSize = UDim2.new(0.5, -6, 0, 118),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = page,
	})
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end
	-- Заголовки занимают две ячейки: второй — пустышка, чтобы сетка не сбилась.
	local function header(text: string)
		sectionTitle(page, text, nextOrder())
		sectionTitle(page, "", nextOrder())
	end
	header("⭐ Геймпассы — навсегда")
	for _, pass in Monetization.Passes do
		local _, button = robuxCard(page, nextOrder(), pass.icon, pass.name, pass.description, pass.color)
		button.Activated:Connect(function()
			if not player:GetAttribute(Monetization.attribute(pass)) then
				buy("pass", pass.key)
			end
		end)
		table.insert(robuxCards, { button = button, pass = pass })
	end
	if order % 2 == 1 then
		sectionTitle(page, "", nextOrder())
	end
	header("🪙 Пакеты — можно покупать много раз")
	for _, product in Monetization.Products do
		local description = if product.coins
			then "Монеты сразу на счёт"
			else "Опыт сразу: новые уровни и титулы"
		local _, button = robuxCard(page, nextOrder(), product.icon, product.name, description, product.color)
		button.Activated:Connect(function()
			buy("product", product.key)
		end)
		table.insert(robuxCards, { button = button, pass = nil })
		button.Text = `R$ {product.price}`
	end
end

local function renderRobux()
	for _, card in robuxCards do
		local pass = card.pass
		if pass then
			local owned = player:GetAttribute(Monetization.attribute(pass)) == true
			card.button.Text = if owned then "Куплено ✓" else `R$ {pass.price}`
			card.button.BackgroundColor3 = if owned then Ui.Colors.Gold else ROBUX_GREEN
		end
	end
end

local function render()
	local data = PlayerState.get()
	if not data then
		return
	end
	coinsLabel.Text = `🪙 {data.Coins}`
	renderRobux()

	for _, card in upgradeCards do
		local level = data.Upgrades[card.upgrade.id] or 0
		for i, pip in card.pips do
			pip.BackgroundColor3 = if i <= level then Ui.Colors.Gold else DISABLED
		end
		local cost = Shop.upgradeCost(card.upgrade, level)
		if not cost then
			card.button.Text = "МАКС"
			card.button.BackgroundColor3 = Ui.Colors.Gold
		else
			card.button.Text = `🪙 {cost}`
			card.button.BackgroundColor3 = if data.Coins >= cost then GREEN else DISABLED
		end
	end

	for _, card in skinCards do
		local owned = data.Skins[card.skin.id] == true
		local equipped = data.EquippedSkin == card.skin.id
		card.stroke.Color = if equipped then Ui.Colors.Gold else Ui.Colors.PanelLight
		if equipped then
			card.button.Text = "НАДЕТО ✓"
			card.button.BackgroundColor3 = Ui.Colors.Gold
		elseif owned then
			card.button.Text = "НАДЕТЬ"
			card.button.BackgroundColor3 = Color3.fromRGB(90, 110, 220)
		else
			card.button.Text = `🪙 {card.skin.price}`
			card.button.BackgroundColor3 = if data.Coins >= card.skin.price then GREEN else DISABLED
		end
	end
end

local function selectTab(name: string)
	currentTab = name
	for tab, page in pages do
		page.Visible = tab == name
		tabButtons[tab].BackgroundColor3 = if tab == name then Ui.Colors.Gold else Ui.Colors.PanelLight
		tabButtons[tab].TextColor3 = if tab == name then Ui.Colors.Panel else Ui.Colors.Text
	end
end

local function setVisible(open: boolean)
	if open then
		render()
		selectTab(currentTab)
		panel.Visible = true
		panelScale.Scale = 0.85
		TweenService:Create(panelScale, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	else
		panel.Visible = false
	end
end

local function build()
	local gui = Ui.create("ScreenGui", {
		Name = "Shop",
		ResetOnSpawn = false,
		DisplayOrder = 10,
		Parent = player:WaitForChild("PlayerGui"),
	})

	local toggle = Ui.create("TextButton", {
		Name = "Toggle",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.5, 0),
		Size = UDim2.fromOffset(60, 60),
		BackgroundColor3 = Ui.Colors.Panel,
		BackgroundTransparency = 0.1,
		Text = "🛒",
		TextScaled = true,
		Font = Enum.Font.GothamBold,
		Parent = gui,
	}, {
		Ui.corner(14),
		Ui.stroke(GREEN, 2),
		Ui.padding(10),
		Ui.label({
			Size = UDim2.new(1, 20, 0, 14),
			Position = UDim2.new(0, -10, 1, 6),
			Text = if UserInputService.KeyboardEnabled then "Магазин [V]" else "Магазин",
			TextColor3 = Ui.Colors.Muted,
		}),
	})
	Ui.bounce(toggle)
	toggle.Activated:Connect(function()
		Ui.togglePanel("Shop")
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
	}, { Ui.corner(16), Ui.stroke(GREEN, 2), panelScale })

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
		Size = UDim2.fromOffset(200, 30),
		Position = UDim2.fromOffset(20, 14),
		Text = "МАГАЗИН",
		Font = Enum.Font.GothamBlack,
		TextColor3 = GREEN,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = wrapper,
	})
	coinsLabel = Ui.label({
		Size = UDim2.fromOffset(160, 24),
		Position = UDim2.fromOffset(PANEL_SIZE.X - 230, 18),
		Text = "",
		TextColor3 = Color3.fromRGB(255, 215, 90),
		TextXAlignment = Enum.TextXAlignment.Right,
		Font = Enum.Font.GothamBlack,
		Parent = wrapper,
	})
	local close = actionButton(wrapper, {
		Size = UDim2.fromOffset(32, 32),
		Position = UDim2.fromOffset(PANEL_SIZE.X - 50, 14),
		BackgroundColor3 = Ui.Colors.PanelLight,
		Text = "✕",
	})
	close.Activated:Connect(function()
		Ui.togglePanel("Shop", false)
	end)

	-- Вкладки.
	for i, tab in
		{
			{ "Upgrades", "⚔️ Прокачка" },
			{ "Skins", "🧤 Скины" },
			{ "Robux", "💎 Робуксы" },
		}
	do
		local button = actionButton(wrapper, {
			Position = UDim2.fromOffset(20 + (i - 1) * 170, 56),
			Size = UDim2.fromOffset(160, 36),
			Text = tab[2],
		})
		button.Activated:Connect(function()
			selectTab(tab[1])
		end)
		tabButtons[tab[1]] = button

		local page = Ui.create("ScrollingFrame", {
			Position = UDim2.fromOffset(20, 104),
			Size = UDim2.fromOffset(PANEL_SIZE.X - 40, PANEL_SIZE.Y - 120),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 4,
			ScrollBarImageColor3 = GREEN,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			Visible = false,
			Parent = wrapper,
		})
		pages[tab[1]] = page
	end
	buildUpgrades(pages.Upgrades)
	buildSkins(pages.Skins)
	buildRobux(pages.Robux)

	Ui.registerPanel("Shop", setVisible)
end

function ShopController:Init()
	purchase = Remotes.func("ShopPurchase")
	buyItem = Remotes.func("BuyItem")
end

function ShopController:Start()
	build()
	PlayerState.Changed:Connect(function()
		if panel.Visible then
			render()
		end
	end)
	-- Купленные геймпассы сервер отмечает атрибутами игрока.
	player.AttributeChanged:Connect(function()
		if panel.Visible then
			renderRobux()
		end
	end)
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed and input.KeyCode == TOGGLE_KEY then
			Ui.togglePanel("Shop")
		end
	end)
	RunService.RenderStepped:Connect(function()
		if panel.Visible then
			for _, preview in rainbowPreviews do
				preview.BackgroundColor3 = Shop.skinColor(Shop.SkinById.Rainbow)
			end
		end
	end)
end

return ShopController
