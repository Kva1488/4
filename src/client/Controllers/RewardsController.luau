--!strict
-- Панель наград (кнопка слева или клавиша J): ежедневные награды за серию входов и титулы.
-- Сервер проверяет и выдаёт всё сам (ProgressionService), клиент только показывает.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Progression = require(ReplicatedStorage.Shared.Progression)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local PlayerState = require(script.Parent.Parent.PlayerState)
local Ui = require(script.Parent.Parent.Ui)
local NotifyController = require(script.Parent.NotifyController)

local player = Players.LocalPlayer

local PANEL_SIZE = Vector2.new(660, 440)
local TOGGLE_KEY = Enum.KeyCode.J
local ACCENT = Color3.fromRGB(255, 160, 70)
local GREEN = Color3.fromRGB(70, 190, 100)
local RED = Color3.fromRGB(255, 90, 90)

local RewardsController = {}

local panel: Frame
local panelScale: UIScale
local badge: Frame
local tabButtons: { [string]: TextButton } = {}
local pages: { [string]: Frame } = {}
local currentTab = "Daily"
local busy = false
local notifiedDaily = false

type DayCard = { frame: Frame, stroke: UIStroke, check: TextLabel }
local dayCards: { DayCard } = {}
local streakLabel: TextLabel
local claimButton: TextButton

type TitleRow = { title: Progression.Title, button: TextButton, progress: TextLabel, stroke: UIStroke }
local titleRows: { TitleRow } = {}
local clearButton: TextButton

local claimDaily: RemoteFunction
local equipTitle: RemoteFunction

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

local function request(remote: RemoteFunction, ...: any)
	if busy then
		return
	end
	busy = true
	local ok, success, message = pcall(remote.InvokeServer, remote, ...)
	busy = false
	if not ok then
		NotifyController.show("Ошибка связи с сервером", RED)
	elseif success then
		Ui.playSound("Purchase", 0.6, 1.2)
		NotifyController.show(message, GREEN)
	else
		NotifyController.show(message, RED)
	end
end

local function dailyAvailable(): boolean
	local data = PlayerState.get()
	return data ~= nil and data.LastDaily ~= Progression.today()
end

local function formatDuration(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d:%02d", seconds // 3600, (seconds // 60) % 60, seconds % 60)
end

-- ── Ежедневные награды ─────────────────────────────────────────────────────

local function buildDaily(page: Frame)
	streakLabel = Ui.label({
		Size = UDim2.new(1, 0, 0, 22),
		Text = "",
		TextColor3 = Ui.Colors.Muted,
		Font = Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = page,
	})
	local width = (PANEL_SIZE.X - 40 - 6 * 8) / 7
	for day, reward in Progression.Daily do
		local big = day == #Progression.Daily
		local stroke = Ui.stroke(ACCENT, 2, 1)
		local card = Ui.create("Frame", {
			Position = UDim2.fromOffset((day - 1) * (width + 8), 34),
			Size = UDim2.fromOffset(width, 150),
			BackgroundColor3 = if big then Color3.fromRGB(60, 40, 80) else Ui.Colors.PanelLight,
			Parent = page,
		}, { Ui.corner(12), stroke })
		Ui.label({
			Size = UDim2.new(1, 0, 0, 20),
			Position = UDim2.fromOffset(0, 8),
			Text = `День {day}`,
			Font = Enum.Font.GothamBlack,
			Parent = card,
		})
		Ui.label({
			Size = UDim2.new(1, 0, 0, 40),
			Position = UDim2.fromOffset(0, 34),
			Text = if big then "💎" else "🪙",
			Parent = card,
		})
		Ui.label({
			Size = UDim2.new(1, -8, 0, 18),
			Position = UDim2.fromOffset(4, 84),
			Text = `{reward.coins}`,
			TextColor3 = Color3.fromRGB(255, 215, 90),
			Font = Enum.Font.GothamBlack,
			Parent = card,
		})
		Ui.label({
			Size = UDim2.new(1, -8, 0, 16),
			Position = UDim2.fromOffset(4, 106),
			Text = `+{reward.xp} опыта`,
			TextColor3 = Color3.fromRGB(170, 190, 255),
			Font = Enum.Font.GothamBold,
			Parent = card,
		})
		local check = Ui.label({
			Size = UDim2.new(1, 0, 0, 18),
			Position = UDim2.fromOffset(0, 126),
			Text = "",
			TextColor3 = GREEN,
			Parent = card,
		})
		table.insert(dayCards, { frame = card, stroke = stroke, check = check })
	end
	claimButton = actionButton(page, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 204),
		Size = UDim2.fromOffset(300, 54),
		BackgroundColor3 = GREEN,
		Text = "Забрать",
	})
	claimButton.Activated:Connect(function()
		if dailyAvailable() then
			request(claimDaily)
		end
	end)
	Ui.label({
		Position = UDim2.fromOffset(0, 272),
		Size = UDim2.new(1, 0, 0, 36),
		Text = "Заходи каждый день: награда растёт до 7-го дня. Пропуск дня сбрасывает серию.",
		TextColor3 = Ui.Colors.Muted,
		Font = Enum.Font.GothamMedium,
		TextWrapped = true,
		Parent = page,
	})
end

local function renderDaily()
	local data = PlayerState.get()
	if not data then
		return
	end
	local today = Progression.today()
	local claimed = data.LastDaily == today
	-- Какой день серии сейчас (уже забранный или следующий).
	local current = if claimed
		then data.DailyStreak
		else Progression.nextStreak(data.LastDaily, data.DailyStreak, today)
	for day, card in dayCards do
		local done = day < current or (claimed and day == current)
		local isNext = not claimed and day == current
		card.check.Text = if done then "✔ получено" elseif isNext then "СЕГОДНЯ" else ""
		card.check.TextColor3 = if done then GREEN else ACCENT
		card.stroke.Transparency = if isNext then 0 else 1
		card.frame.BackgroundTransparency = if done then 0.45 else 0
	end
	streakLabel.Text = if claimed
		then `Серия: {data.DailyStreak} дн. подряд · лучшая серия: {data.BestStreak}`
		else `Сегодня день {current} серии · лучшая серия: {data.BestStreak}`
	if claimed then
		claimButton.Text = `Следующая через {formatDuration((today + 1) * 86400 - os.time())}`
		claimButton.BackgroundColor3 = Ui.Colors.Locked
	else
		claimButton.Text = `🎁 Забрать день {current}`
		claimButton.BackgroundColor3 = GREEN
	end
end

-- ── Титулы ─────────────────────────────────────────────────────────────────

local function buildTitles(page: Frame)
	Ui.create(
		"UIListLayout",
		{ Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = page }
	)
	clearButton = actionButton(page, {
		Size = UDim2.new(1, -8, 0, 36),
		BackgroundColor3 = Ui.Colors.PanelLight,
		Text = "Без титула",
		LayoutOrder = 0,
	})
	clearButton.Activated:Connect(function()
		request(equipTitle, "")
	end)
	for index, title in Progression.Titles do
		local stroke = Ui.stroke(title.color, 2, 1)
		local row = Ui.create("Frame", {
			Size = UDim2.new(1, -8, 0, 64),
			BackgroundColor3 = Ui.Colors.PanelLight,
			LayoutOrder = index,
			Parent = page,
		}, { Ui.corner(12), stroke })
		Ui.create("Frame", {
			Size = UDim2.fromOffset(8, 44),
			Position = UDim2.fromOffset(10, 10),
			BackgroundColor3 = title.color,
			Parent = row,
		}, { Ui.corner(4) })
		Ui.label({
			Size = UDim2.fromOffset(330, 26),
			Position = UDim2.fromOffset(28, 8),
			Text = title.name,
			TextColor3 = title.color,
			Font = Enum.Font.GothamBlack,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		local progress = Ui.label({
			Size = UDim2.fromOffset(330, 18),
			Position = UDim2.fromOffset(28, 38),
			Text = title.hint,
			TextColor3 = Ui.Colors.Muted,
			Font = Enum.Font.GothamMedium,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		local button = actionButton(row, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(140, 40),
		})
		button.Activated:Connect(function()
			local data = PlayerState.get()
			if data and Progression.hasTitle(title, data) and data.EquippedTitle ~= title.id then
				request(equipTitle, title.id)
			end
		end)
		table.insert(titleRows, { title = title, button = button, progress = progress, stroke = stroke })
	end
end

local function renderTitles()
	local data = PlayerState.get()
	if not data then
		return
	end
	local stats = data :: any
	for _, row in titleRows do
		local owned = Progression.hasTitle(row.title, data)
		local equipped = data.EquippedTitle == row.title.id
		local value = stats[row.title.stat]
		local have = if type(value) == "number" then math.min(value, row.title.min) else 0
		row.progress.Text = if owned
			then `{row.title.hint} ✔`
			else `{row.title.hint} ({have}/{row.title.min})`
		row.button.Text = if equipped then "Надет" elseif owned then "Надеть" else "🔒"
		row.button.BackgroundColor3 = if equipped
			then Ui.Colors.Gold
			elseif owned then GREEN
			else Ui.Colors.Locked
		row.stroke.Transparency = if equipped then 0 else 1
	end
	clearButton.BackgroundColor3 = if data.EquippedTitle == "" then Ui.Colors.Gold else Ui.Colors.PanelLight
end

local function render()
	renderDaily()
	renderTitles()
end

local function selectTab(name: string)
	currentTab = name
	for tab, page in pages do
		page.Visible = tab == name
		tabButtons[tab].BackgroundColor3 = if tab == name then ACCENT else Ui.Colors.PanelLight
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
		Name = "Rewards",
		ResetOnSpawn = false,
		DisplayOrder = 10,
		Parent = player:WaitForChild("PlayerGui"),
	})

	local toggle = Ui.create("TextButton", {
		Name = "Toggle",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.5, 192),
		Size = UDim2.fromOffset(60, 60),
		BackgroundColor3 = Ui.Colors.Panel,
		BackgroundTransparency = 0.1,
		Text = "🎁",
		TextScaled = true,
		Font = Enum.Font.GothamBold,
		Parent = gui,
	}, {
		Ui.corner(14),
		Ui.stroke(ACCENT, 2),
		Ui.padding(10),
		Ui.label({
			Size = UDim2.new(1, 20, 0, 14),
			Position = UDim2.new(0, -10, 1, 6),
			Text = if UserInputService.KeyboardEnabled then "Награды [J]" else "Награды",
			TextColor3 = Ui.Colors.Muted,
		}),
	})
	Ui.bounce(toggle)
	toggle.Activated:Connect(function()
		Ui.togglePanel("Rewards")
	end)
	-- Красная точка: ежедневная награда ждёт.
	badge = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, 8, 0, -8),
		Size = UDim2.fromOffset(16, 16),
		BackgroundColor3 = RED,
		Visible = false,
		Parent = toggle,
	}, { Ui.round(), Ui.stroke(Color3.new(1, 1, 1), 2) })

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
	}, { Ui.corner(16), Ui.stroke(ACCENT, 2), panelScale })

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
		Size = UDim2.fromOffset(240, 30),
		Position = UDim2.fromOffset(20, 14),
		Text = "НАГРАДЫ",
		Font = Enum.Font.GothamBlack,
		TextColor3 = ACCENT,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = wrapper,
	})
	local close = actionButton(wrapper, {
		Size = UDim2.fromOffset(32, 32),
		Position = UDim2.fromOffset(PANEL_SIZE.X - 50, 14),
		BackgroundColor3 = Ui.Colors.PanelLight,
		Text = "✕",
	})
	close.Activated:Connect(function()
		Ui.togglePanel("Rewards", false)
	end)

	for i, tab in { { "Daily", "🎁 Ежедневные" }, { "Titles", "🏷️ Титулы" } } do
		local button = actionButton(wrapper, {
			Position = UDim2.fromOffset(20 + (i - 1) * 180, 56),
			Size = UDim2.fromOffset(170, 36),
			Text = tab[2],
		})
		button.Activated:Connect(function()
			selectTab(tab[1])
		end)
		tabButtons[tab[1]] = button
		local page = Ui.create(if tab[1] == "Titles" then "ScrollingFrame" else "Frame", {
			Position = UDim2.fromOffset(20, 104),
			Size = UDim2.fromOffset(PANEL_SIZE.X - 40, PANEL_SIZE.Y - 120),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Visible = false,
			Parent = wrapper,
		})
		if tab[1] == "Titles" then
			page.ScrollBarThickness = 4
			page.ScrollBarImageColor3 = ACCENT
			page.CanvasSize = UDim2.new()
			page.AutomaticCanvasSize = Enum.AutomaticSize.Y
		end
		pages[tab[1]] = page
	end
	buildDaily(pages.Daily)
	buildTitles(pages.Titles)

	Ui.registerPanel("Rewards", setVisible)
end

function RewardsController:Init()
	claimDaily = Remotes.func("ClaimDaily")
	equipTitle = Remotes.func("EquipTitle")
end

function RewardsController:Start()
	build()
	local function onData()
		badge.Visible = dailyAvailable()
		if panel.Visible then
			render()
		end
		if not notifiedDaily and dailyAvailable() then
			notifiedDaily = true
			task.delay(4, function()
				if dailyAvailable() then
					NotifyController.show(
						"🎁 Ежедневная награда ждёт! Открой награды [J]",
						ACCENT
					)
				end
			end)
		end
	end
	PlayerState.Changed:Connect(onData)
	onData()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed and input.KeyCode == TOGGLE_KEY then
			Ui.togglePanel("Rewards")
		end
	end)
	-- Таймер до следующей награды и смена дня без перезахода.
	while true do
		task.wait(1)
		badge.Visible = dailyAvailable()
		if panel.Visible then
			renderDaily()
		end
	end
end

return RewardsController
