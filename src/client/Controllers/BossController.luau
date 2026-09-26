--!strict
-- Интерфейс рейда на Дормамму:
-- • таймер до прорыва и расстояние до разлома;
-- • полоска здоровья босса с фазой и «догоняющим» следом урона;
-- • подсказки посреди экрана («ПРЫГАЙ!»);
-- • итоги боя: вклад в урон и награда;
-- • в третьей фазе мир у разлома окрашивается в пурпур Тёмного измерения.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Places = require(ReplicatedStorage.Shared.Places)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Ui = require(script.Parent.Parent.Ui)
local NotifyController = require(script.Parent.NotifyController)

local player = Players.LocalPlayer

local PURPLE = Color3.fromRGB(190, 60, 255)
local ORANGE = Color3.fromRGB(255, 140, 50)
local BAR_WIDTH = 520

local BossController = {}

local gui: ScreenGui
local pill: TextLabel
local bar: Frame
local fill: Frame
local trail: Frame
local healthText: TextLabel
local phaseLabel: TextLabel
local distanceLabel: TextLabel
local calloutLabel: TextLabel
local results: Frame
local grade: ColorCorrectionEffect

local nextAt = 0
local trailRatio = 1
local calloutToken = 0

local function tween(instance: Instance, duration: number, goal: { [string]: any })
	TweenService:Create(instance, TweenInfo.new(duration, Enum.EasingStyle.Quad), goal):Play()
end

local function currentBoss(): Model?
	for _, model in CollectionService:GetTagged("Boss") do
		if model:IsA("Model") and model:IsDescendantOf(workspace) then
			return model
		end
	end
	return nil
end

local function inArena(): boolean
	local character = player.Character
	return character ~= nil and character:GetAttribute("Zone") == "Arena"
end

local function distanceToRift(): number?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end
	return ((root.Position - Places.BossCenter) * Vector3.new(1, 0, 1)).Magnitude
end

local function showCallout(text: string)
	calloutToken += 1
	local token = calloutToken
	calloutLabel.Text = text
	calloutLabel.TextTransparency = 0
	local scale = calloutLabel:FindFirstChildOfClass("UIScale") :: UIScale
	scale.Scale = 1.4
	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	Ui.playSound("Purchase", 0.5, 0.7)
	task.delay(1.8, function()
		if token == calloutToken then
			tween(calloutLabel, 0.4, { TextTransparency = 1 })
		end
	end)
end

local function hideResults()
	results.Visible = false
end

-- Итоги: таблица вклада и личная награда.
local function showResults(info: any)
	if type(info) ~= "table" or type(info.board) ~= "table" then
		return
	end
	for _, child in results:GetChildren() do
		if child:GetAttribute("Row") then
			child:Destroy()
		end
	end
	for i, entry in info.board do
		local row = Ui.create("Frame", {
			Position = UDim2.fromOffset(20, 60 + (i - 1) * 34),
			Size = UDim2.new(1, -40, 0, 28),
			BackgroundColor3 = Ui.Colors.PanelLight,
			Parent = results,
		}, { Ui.corner(8) })
		row:SetAttribute("Row", true)
		local share = tonumber(entry.share) or 0
		Ui.create("Frame", {
			Size = UDim2.fromScale(math.clamp(share, 0.02, 1), 1),
			BackgroundColor3 = if i == 1 then ORANGE else PURPLE,
			BackgroundTransparency = 0.45,
			Parent = row,
		}, { Ui.corner(8) })
		Ui.label({
			Size = UDim2.new(1, -16, 1, -8),
			Position = UDim2.fromOffset(8, 4),
			Text = `{if i == 1 then "👑" else tostring(i) .. "."} {tostring(entry.name)}`,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 2,
			Parent = row,
		})
		Ui.label({
			Size = UDim2.new(1, -16, 1, -8),
			Position = UDim2.fromOffset(8, 4),
			Text = `{tostring(entry.damage)} урона · {math.floor(share * 100 + 0.5)}%`,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = Ui.Colors.Muted,
			ZIndex = 2,
			Parent = row,
		})
	end
	local summary = results:FindFirstChild("Summary") :: TextLabel
	if info.coins then
		summary.Text = `Твоё место: {tostring(info.rank)} · +{tostring(info.coins)} монет · +{tostring(
			info.xp
		)} опыта` .. (if info.counts
			then " · победа засчитана"
			else " · слишком малый вклад для победы")
	else
		summary.Text =
			"Ты не участвовал в бою. Следующий прорыв — через несколько минут!"
	end
	results.Visible = true
	local scale = results:FindFirstChildOfClass("UIScale") :: UIScale
	scale.Scale = 0.8
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(14, hideResults)
end

local function build()
	gui = Ui.create("ScreenGui", {
		Name = "Boss",
		ResetOnSpawn = false,
		DisplayOrder = 6,
		Parent = player:WaitForChild("PlayerGui"),
	})
	pill = Ui.label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromOffset(300, 28),
		BackgroundTransparency = 0.25,
		BackgroundColor3 = Ui.Colors.Panel,
		Text = "",
		TextColor3 = ORANGE,
		Font = Enum.Font.GothamBold,
		Visible = false,
		Parent = gui,
	})
	Ui.corner(14).Parent = pill
	Ui.stroke(PURPLE, 1.5, 0.3).Parent = pill
	Ui.padding(5).Parent = pill

	bar = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromOffset(BAR_WIDTH, 62),
		BackgroundColor3 = Ui.Colors.Panel,
		BackgroundTransparency = 0.15,
		Visible = false,
		Parent = gui,
	}, {
		Ui.corner(12),
		Ui.stroke(PURPLE, 2),
		Ui.create("UISizeConstraint", { MaxSize = Vector2.new(BAR_WIDTH, 62) }),
	})
	Ui.label({
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(0.6, 0, 0, 20),
		Text = "🔥 ДОРМАММУ · Властелин Тёмного измерения",
		TextColor3 = PURPLE,
		Font = Enum.Font.GothamBlack,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = bar,
	})
	phaseLabel = Ui.label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 6),
		Size = UDim2.new(0.35, 0, 0, 18),
		Text = "Фаза 1",
		TextColor3 = ORANGE,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = bar,
	})
	local track = Ui.create("Frame", {
		Position = UDim2.fromOffset(12, 30),
		Size = UDim2.new(1, -24, 0, 18),
		BackgroundColor3 = Color3.fromRGB(30, 20, 40),
		Parent = bar,
	}, { Ui.corner(9) })
	trail = Ui.create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(255, 240, 200),
		BackgroundTransparency = 0.3,
		Parent = track,
	}, { Ui.corner(9) })
	fill = Ui.create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = track,
	}, {
		Ui.corner(9),
		Ui.create("UIGradient", { Color = ColorSequence.new(PURPLE, ORANGE) }),
	})
	-- Отметки фаз (60% и 30%).
	for _, mark in { 0.6, 0.3 } do
		Ui.create("Frame", {
			Position = UDim2.new(mark, -1, 0, -2),
			Size = UDim2.new(0, 2, 1, 4),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.3,
			ZIndex = 3,
			Parent = track,
		})
	end
	healthText = Ui.label({
		Size = UDim2.fromScale(1, 1),
		Text = "",
		ZIndex = 4,
		Parent = track,
	})
	distanceLabel = Ui.label({
		Position = UDim2.fromOffset(12, 49),
		Size = UDim2.new(1, -24, 0, 12),
		Text = "",
		TextColor3 = Ui.Colors.Muted,
		Font = Enum.Font.GothamMedium,
		Parent = bar,
	})

	calloutLabel = Ui.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.36),
		Size = UDim2.fromOffset(640, 54),
		Text = "",
		TextColor3 = ORANGE,
		Font = Enum.Font.GothamBlack,
		TextTransparency = 1,
		Parent = gui,
	})
	Ui.create("UIScale", { Parent = calloutLabel })
	Ui.create("UIStroke", { Thickness = 3, Transparency = 0.2, Parent = calloutLabel })

	results = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(480, 300),
		BackgroundColor3 = Ui.Colors.Panel,
		BackgroundTransparency = 0.05,
		Visible = false,
		Parent = gui,
	}, { Ui.corner(16), Ui.stroke(ORANGE, 2), Ui.create("UIScale", {}) })
	Ui.label({
		Position = UDim2.fromOffset(20, 14),
		Size = UDim2.new(1, -80, 0, 30),
		Text = "🔥 ДОРМАММУ ИЗГНАН",
		TextColor3 = ORANGE,
		Font = Enum.Font.GothamBlack,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = results,
	})
	Ui.label({
		Name = "Summary",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 20, 1, -14),
		Size = UDim2.new(1, -40, 0, 36),
		Text = "",
		TextColor3 = Color3.fromRGB(255, 215, 90),
		TextWrapped = true,
		Parent = results,
	})
	local close = Ui.create("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 14),
		Size = UDim2.fromOffset(32, 32),
		BackgroundColor3 = Ui.Colors.PanelLight,
		Text = "✕",
		TextScaled = true,
		Font = Enum.Font.GothamBlack,
		TextColor3 = Color3.new(1, 1, 1),
		Parent = results,
	}, { Ui.corner(8), Ui.padding(6) })
	close.Activated:Connect(hideResults)

	grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "DarkDimensionGrade"
	grade.Parent = Lighting
end

local function update(dt: number)
	local boss = currentBoss()
	local hidden = inArena()
	local distance = distanceToRift()
	local topOffset = 0
	if boss and not hidden then
		local humanoid = boss:FindFirstChildOfClass("Humanoid")
		local ratio = if humanoid
			then math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
			else 0
		bar.Visible = true
		pill.Visible = false
		fill.Size = UDim2.fromScale(ratio, 1)
		-- След урона догоняет полоску.
		trailRatio = if trailRatio < ratio
			then ratio
			else trailRatio + (ratio - trailRatio) * math.min(1, dt * 2.5)
		trail.Size = UDim2.fromScale(trailRatio, 1)
		healthText.Text = if humanoid
			then `{math.ceil(humanoid.Health)} / {math.floor(humanoid.MaxHealth)}  ({math.ceil(ratio * 100)}%)`
			else ""
		local phase = boss:GetAttribute("Phase")
		phaseLabel.Text = `Фаза {tostring(phase or 1)}`
		distanceLabel.Text = if distance and distance > 60
			then `📍 Разлом в {math.floor(distance)} м — иди по пурпурной дорожке`
			else "Уворачивайся от кругов на земле. Волну — перепрыгивай!"
		topOffset = 70
		-- Третья фаза: пурпурный мир у разлома.
		local near = distance ~= nil and distance < 160
		local goal = if phase == 3 and near then 1 else 0
		grade.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(235, 190, 255), goal)
		grade.Saturation = 0.25 * goal
	else
		bar.Visible = false
		trailRatio = 1
		grade.TintColor = Color3.new(1, 1, 1)
		grade.Saturation = 0
		local left = nextAt - workspace:GetServerTimeNow()
		if not hidden and nextAt > 0 and left > 0 and left < 60 * 30 then
			local seconds = math.floor(left)
			pill.Visible = true
			pill.Text = string.format(
				"🔥 Дормамму прорвётся через %d:%02d",
				seconds // 60,
				seconds % 60
			)
			topOffset = 34
		else
			pill.Visible = false
		end
	end
	NotifyController.setOffset("Boss", topOffset)
end

function BossController:Start()
	build()
	Remotes.event("Boss").OnClientEvent:Connect(function(kind: string, extra: any)
		if kind == "Schedule" then
			nextAt = tonumber(extra) or 0
		elseif kind == "Warning" then
			if not inArena() then
				showCallout("🔥 Разлом открывается!")
			end
		elseif kind == "Spawned" then
			nextAt = 0
			trailRatio = 1
		elseif kind == "Phase" then
			if not inArena() then
				showCallout(
					if extra == 3
						then "ТЁМНОЕ ИЗМЕРЕНИЕ!"
						else "ДОРМАММУ В ЯРОСТИ!"
				)
			end
		elseif kind == "Callout" then
			showCallout(tostring(extra))
		elseif kind == "Defeated" then
			showResults(extra)
		elseif kind == "Retreat" then
			NotifyController.show(
				"Дормамму отступил в Тёмное измерение",
				PURPLE
			)
		end
	end)
	RunService.RenderStepped:Connect(update)
end

return BossController
