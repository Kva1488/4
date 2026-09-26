--!strict
-- Табло летающей арены (видно только участникам): режим, таймер, цель, лидеры и свои очки,
-- состояние холма/Перчатки и кнопка «Покинуть арену». Всё считает сервер (ArenaService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local ArenaModes = require(ReplicatedStorage.Shared.ArenaModes)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Ui = require(script.Parent.Parent.Ui)
local NotifyController = require(script.Parent.NotifyController)

local player = Players.LocalPlayer

local PANEL_WIDTH = 440
local GOLD = Color3.fromRGB(230, 175, 50)

local ArenaController = {}

local panel: Frame
local titleLabel: TextLabel
local timerLabel: TextLabel
local statusLabel: TextLabel
local chips: { TextLabel } = {}
local myLabel: TextLabel
local leaveButton: TextButton

local lastState = 0
local lastTimerSecond = -1

local function formatTime(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function setVisible(visible: boolean)
	panel.Visible = visible
	leaveButton.Visible = visible
	NotifyController.setOffset("Arena", if visible then 136 else 0)
end

local function onState(state: any)
	if type(state) ~= "table" then
		return
	end
	lastState = os.clock()
	if not panel.Visible then
		setVisible(true)
	end
	local mode = ArenaModes.ById[tostring(state.mode)] or ArenaModes.List[1]
	local phase = tostring(state.phase)
	local timeLeft = tonumber(state.timeLeft) or 0
	titleLabel.Text = `{mode.icon} {mode.name}`
	titleLabel.TextColor3 = mode.color
	timerLabel.Text = if phase == "Waiting" then "—" else formatTime(timeLeft)
	timerLabel.TextColor3 = if phase == "Round" and timeLeft <= 10
		then Color3.fromRGB(255, 90, 90)
		else Ui.Colors.Text
	-- Тиканье последних секунд раунда.
	if phase == "Round" and timeLeft <= 5 and timeLeft ~= lastTimerSecond and timeLeft > 0 then
		lastTimerSecond = timeLeft
		Ui.playSound("Purchase", 0.4, 1.8)
	end

	if phase == "Waiting" then
		statusLabel.Text =
			`Ждём игроков: {tostring(state.count)}/{tostring(state.min)} — позови друзей!`
	elseif phase == "Intermission" then
		statusLabel.Text =
			`Раунд начнётся через {formatTime(timeLeft)} · {mode.description}`
	elseif phase == "Results" then
		statusLabel.Text = "Итоги раунда. Следующий режим скоро!"
	elseif mode.id == "KingOfHill" then
		local hill = state.hillState
		statusLabel.Text = if hill == "held"
			then "👑 Круг удерживается! Выбей его оттуда"
			elseif
				hill == "contested"
			then "⚔️ Круг оспаривается — никто не получает очков"
			else "Круг свободен — займи его!"
	elseif mode.id == "Gauntlet" then
		statusLabel.Text = if state.holder
			then `🧤 Перчатка у {tostring(state.holder)} — убей держателя!`
			else "🧤 Перчатка лежит на арене — хватай!"
	else
		statusLabel.Text = `Цель: {mode.goal} убийств`
	end

	local top = if type(state.top) == "table" then state.top else {}
	for i, chip in chips do
		local entry = top[i]
		chip.Visible = entry ~= nil
		if entry then
			local mine = entry.name == player.DisplayName
			chip.Text =
				`{if i == 1 then "👑" else tostring(i)} {tostring(entry.name)}: {tostring(entry.score)}`
			chip.TextColor3 = if mine then GOLD else Ui.Colors.Text
		end
	end
	myLabel.Text = `Твои очки: {tostring(state.myScore or 0)} / {mode.goal}`
end

local function build()
	local gui = Ui.create("ScreenGui", {
		Name = "Arena",
		ResetOnSpawn = false,
		DisplayOrder = 7,
		Parent = player:WaitForChild("PlayerGui"),
	})
	panel = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.new(0.9, 0, 0, 128),
		BackgroundColor3 = Ui.Colors.Panel,
		BackgroundTransparency = 0.15,
		Visible = false,
		Parent = gui,
	}, {
		Ui.corner(12),
		Ui.stroke(GOLD, 2),
		Ui.create("UISizeConstraint", { MaxSize = Vector2.new(PANEL_WIDTH, 128) }),
	})
	titleLabel = Ui.label({
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(0.7, 0, 0, 24),
		Text = "",
		Font = Enum.Font.GothamBlack,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = panel,
	})
	timerLabel = Ui.label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 6),
		Size = UDim2.new(0.25, 0, 0, 24),
		Text = "",
		Font = Enum.Font.GothamBlack,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = panel,
	})
	statusLabel = Ui.label({
		Position = UDim2.fromOffset(12, 34),
		Size = UDim2.new(1, -24, 0, 16),
		Text = "",
		TextColor3 = Ui.Colors.Muted,
		Font = Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = panel,
	})
	local row = Ui.create("Frame", {
		Position = UDim2.fromOffset(12, 56),
		Size = UDim2.new(1, -24, 0, 44),
		BackgroundTransparency = 1,
		Parent = panel,
	}, {
		Ui.create("UIGridLayout", {
			CellSize = UDim2.new(1 / 3, -4, 0, 20),
			CellPadding = UDim2.fromOffset(4, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for i = 1, 6 do
		local chip = Ui.label({
			BackgroundColor3 = Ui.Colors.PanelLight,
			BackgroundTransparency = 0.2,
			Text = "",
			LayoutOrder = i,
			Visible = false,
			Font = Enum.Font.GothamBold,
			Parent = row,
		})
		Ui.corner(6).Parent = chip
		Ui.padding(3).Parent = chip
		table.insert(chips, chip)
	end
	myLabel = Ui.label({
		Position = UDim2.new(0, 12, 1, -22),
		Size = UDim2.new(1, -24, 0, 16),
		Text = "",
		TextColor3 = GOLD,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = panel,
	})

	leaveButton = Ui.create("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.62, 0),
		Size = UDim2.fromOffset(170, 44),
		BackgroundColor3 = Color3.fromRGB(150, 50, 60),
		Text = "🚪 Покинуть арену",
		TextScaled = true,
		Font = Enum.Font.GothamBlack,
		TextColor3 = Color3.new(1, 1, 1),
		Visible = false,
		Parent = gui,
	}, { Ui.corner(10), Ui.padding(8) })
	Ui.bounce(leaveButton)
	local leaveEvent = Remotes.event("ArenaLeave")
	leaveButton.Activated:Connect(function()
		leaveEvent:FireServer()
	end)
end

function ArenaController:Start()
	build()
	Remotes.event("Arena").OnClientEvent:Connect(function(kind: string, extra: any)
		if kind == "State" then
			onState(extra)
		elseif kind == "Left" then
			setVisible(false)
		elseif kind == "RoundStart" then
			local mode = ArenaModes.ById[tostring(extra)]
			if mode then
				Ui.playSound("Purchase", 0.7, 0.8)
			end
		elseif kind == "RoundEnd" and type(extra) == "table" then
			local winner = extra.winner
			if winner == player.DisplayName then
				NotifyController.show(`🏆 Ты победил! +{ArenaModes.WinCoins} монет`, GOLD)
			end
		end
	end)
	-- Сервер шлёт состояние дважды в секунду; нет вестей — значит, мы уже не на арене.
	RunService.Heartbeat:Connect(function()
		if panel.Visible and os.clock() - lastState > 3 then
			setVisible(false)
		end
	end)
	-- Анимация появления.
	panel:GetPropertyChangedSignal("Visible"):Connect(function()
		if panel.Visible then
			panel.BackgroundTransparency = 1
			TweenService:Create(panel, TweenInfo.new(0.3), { BackgroundTransparency = 0.15 }):Play()
		end
	end)
end

return ArenaController
