--!strict
-- Панель способностей внизу экрана: клавиши, прицел, перезарядки, блокировка по камням.
-- На телефоне способности нажимаются кнопками на панели.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Abilities = require(ReplicatedStorage.Shared.Abilities)
local Items = require(ReplicatedStorage.Shared.Items)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local PlayerState = require(script.Parent.Parent.PlayerState)
local Ui = require(script.Parent.Parent.Ui)
local NotifyController = require(script.Parent.NotifyController)
local ScreenFxController = require(script.Parent.ScreenFxController)

local player = Players.LocalPlayer

local SLOT = 58
local GAP = 6
local SHAKE_ON =
	{ PowerWave = 0.4, MoonRain = 0.7, RockPrison = 0.4, Snap = 1.2, Casket = 0.5, GloriousPurpose = 1.2 }
local FOV_PUNCH = { basic = 2, stone = 6, combo = 10, ultimate = 0 }

type Slot = {
	ability: Abilities.Ability,
	button: TextButton,
	lock: TextLabel,
	cooldown: Frame,
	cooldownText: TextLabel,
	stroke: UIStroke,
}

local AbilityController = {}

local slots: { Slot } = {}
local cooldownEnds: { [string]: number } = {}
local cooldownDurations: { [string]: number } = {}
local useAbility: RemoteEvent

local function requirementText(ability: Abilities.Ability): string
	local names = {}
	for _, stoneId in ability.requires do
		table.insert(names, Items.StoneById[stoneId].name)
	end
	return table.concat(names, " + ")
end

-- Точка прицела: под курсором (ПК) или по центру экрана (телефон / нажатие кнопки).
local function getTarget(fromButton: boolean): Vector3?
	local camera = workspace.CurrentCamera
	if not camera then
		return nil
	end
	local ray: Ray
	if fromButton or UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
		local size = camera.ViewportSize
		ray = camera:ViewportPointToRay(size.X / 2, size.Y / 2)
	else
		local mouse = UserInputService:GetMouseLocation()
		ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = {}
	if player.Character then
		table.insert(exclude, player.Character)
	end
	local effects = workspace:FindFirstChild("Effects")
	if effects then
		table.insert(exclude, effects)
	end
	params.FilterDescendantsInstances = exclude

	local result = workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
	return if result then result.Position else ray.Origin + ray.Direction * 300
end

local function faceTarget(target: Vector3)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		local flat = Vector3.new(target.X, root.Position.Y, target.Z)
		if (flat - root.Position).Magnitude > 0.5 then
			root.CFrame = CFrame.lookAt(root.Position, flat)
		end
	end
end

local function shake(strength: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	task.spawn(function()
		local finish = os.clock() + 0.35
		while os.clock() < finish do
			local decay = (finish - os.clock()) / 0.35
			humanoid.CameraOffset = Vector3.new(math.random() - 0.5, math.random() - 0.5, 0)
				* strength
				* decay
			RunService.RenderStepped:Wait()
		end
		humanoid.CameraOffset = Vector3.zero
	end)
end

local function flashLocked(slot: Slot)
	NotifyController.show(`Нужно: {requirementText(slot.ability)}`, Color3.fromRGB(255, 90, 90))
	slot.stroke.Color = Color3.fromRGB(255, 60, 60)
	task.delay(0.3, function()
		slot.stroke.Color = slot.ability.color
	end)
end

-- Заряд ульты (0..1): сервер хранит его атрибутом игрока.
local function ultCharge(): number
	local value = player:GetAttribute("UltCharge")
	return if typeof(value) == "number" then value else 0
end

local ultWasReady = false

local function activate(slot: Slot, fromButton: boolean)
	local ability = slot.ability
	if not Abilities.isUnlocked(ability, PlayerState.stones()) then
		flashLocked(slot)
		return
	end
	if os.clock() < (cooldownEnds[ability.id] or 0) then
		return
	end
	if ability.kind == "ultimate" and ultCharge() < 1 then
		NotifyController.show(
			`Ульта заряжена на {math.floor(ultCharge() * 100)}% — наноси урон`,
			ability.color
		)
		return
	end
	local target = getTarget(fromButton)
	if target then
		faceTarget(target)
	end
	useAbility:FireServer(ability.id, target)
end

local function createSlot(ability: Abilities.Ability, index: number, parent: Instance): Slot
	local stroke = Ui.stroke(ability.color, 2)
	local lock = Ui.label({
		Name = "Lock",
		Size = UDim2.fromScale(0.5, 0.5),
		Position = UDim2.fromScale(0.25, 0.15),
		Text = "🔒",
		ZIndex = 3,
	})
	local cooldownText = Ui.label({
		Size = UDim2.new(1, 0, 0, 22),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Text = "",
		ZIndex = 5,
	})
	local cooldown = Ui.create("Frame", {
		Name = "Cooldown",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		ZIndex = 4,
	}, { Ui.corner(10) })

	local icon = Ui.gem(ability.color, UDim2.fromScale(0.42, 0.42))
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.42)

	local isUltimate = ability.kind == "ultimate"
	local button = Ui.create("TextButton", {
		Name = ability.id,
		LayoutOrder = index,
		Text = "",
		AutoButtonColor = true,
		BackgroundColor3 = if isUltimate then Color3.fromRGB(60, 45, 10) else Ui.Colors.Panel,
		BackgroundTransparency = 0.1,
		Parent = parent,
	}, {
		Ui.corner(10),
		stroke,
		icon,
		Ui.label({
			Name = "Key",
			Size = UDim2.fromOffset(22, 14),
			Position = UDim2.fromOffset(4, 3),
			Text = ability.keyLabel,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Ui.Colors.Muted,
			ZIndex = 2,
		}),
		Ui.label({
			Name = "Title",
			Size = UDim2.new(1, -6, 0, 12),
			Position = UDim2.new(0, 3, 1, -15),
			Text = ability.name,
			Font = Enum.Font.GothamMedium,
			ZIndex = 2,
		}),
		lock,
		cooldown,
		cooldownText,
	})
	local slot: Slot = {
		ability = ability,
		button = button,
		lock = lock,
		cooldown = cooldown,
		cooldownText = cooldownText,
		stroke = stroke,
	}
	button.Activated:Connect(function()
		activate(slot, true)
	end)
	return slot
end

-- Кнопка способности "вспыхивает" при использовании.
local function pulseSlot(abilityId: string)
	for _, slot in slots do
		if slot.ability.id == abilityId then
			local uiScale = slot.button:FindFirstChildOfClass("UIScale")
				or Ui.create("UIScale", { Parent = slot.button }) :: UIScale
			uiScale.Scale = 1.18
			TweenService:Create(uiScale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
			slot.stroke.Thickness = 4
			TweenService:Create(slot.stroke, TweenInfo.new(0.3), { Thickness = 2 }):Play()
		end
	end
end

-- Когда способность перезарядилась — короткая вспышка обводки.
local readyFlashed: { [string]: boolean } = {}

local function refreshLocks()
	local stones = PlayerState.stones()
	for _, slot in slots do
		local unlocked = Abilities.isUnlocked(slot.ability, stones)
		slot.lock.Visible = not unlocked
		slot.stroke.Transparency = if unlocked then 0 else 0.7
		slot.button.BackgroundTransparency = if unlocked then 0.1 else 0.45
	end
end

local bar: Frame
local barScale: UIScale
local barWidth = 0
local currentHero: string? = nil
local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- Подгоняем панель под ширину экрана (на телефоне оставляем место под джойстик и прыжок).
local function fitBar()
	local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize
		or Vector2.new(1280, 720)
	local available = viewport.X * (if touch then 0.5 else 0.95)
	barScale.Scale = math.min(1, available / math.max(barWidth, 1))
end

-- Кнопки способностей текущего героя.
local function populate(heroId: string)
	currentHero = heroId
	for _, slot in slots do
		slot.button:Destroy()
	end
	table.clear(slots)

	local list = Abilities.forHero(heroId)
	local columns = if touch then math.min(6, #list) else #list
	local rows = math.ceil(#list / math.max(columns, 1))
	barWidth = columns * (SLOT + GAP) - GAP
	bar.Size = UDim2.fromOffset(barWidth, rows * (SLOT + GAP) - GAP)
	for index, ability in list do
		table.insert(slots, createSlot(ability, index, bar))
	end
	fitBar()
end

local function buildHotbar()
	local gui = Ui.create("ScreenGui", {
		Name = "Abilities",
		ResetOnSpawn = false,
		DisplayOrder = 5,
		Parent = player:WaitForChild("PlayerGui"),
	})
	bar = Ui.create("Frame", {
		Name = "Hotbar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		Ui.create("UIGridLayout", {
			CellSize = UDim2.fromOffset(SLOT, SLOT),
			CellPadding = UDim2.fromOffset(GAP, GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}),
	})
	barScale = Ui.create("UIScale", { Parent = bar })
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitBar)
	end
	local data = PlayerState.get()
	populate(if data then data.Hero else "Thanos")
end

local function onData()
	local data = PlayerState.get()
	if data and data.Hero ~= currentHero then
		populate(data.Hero)
	end
	refreshLocks()
end

function AbilityController:Init()
	useAbility = Remotes.event("UseAbility")
end

function AbilityController:Start()
	-- Свой инвентарь и панель вместо стандартного рюкзака.
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, false)

	buildHotbar()
	refreshLocks()
	PlayerState.Changed:Connect(onData)

	Remotes.event("AbilityCast").OnClientEvent:Connect(function(abilityId: string, cooldown: number?)
		local ability = Abilities.ById[abilityId]
		if ability then
			-- Сервер присылает перезарядку с учётом прокачки "Скорость".
			local duration = cooldown or ability.cooldown
			cooldownDurations[abilityId] = duration
			cooldownEnds[abilityId] = os.clock() + duration
			local strength = SHAKE_ON[abilityId]
			if strength then
				shake(strength)
			end
			ScreenFxController.fovPunch(FOV_PUNCH[ability.kind] or 3)
			pulseSlot(abilityId)
		end
	end)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		for _, slot in slots do
			local bind = slot.ability.input
			if input.KeyCode == bind or input.UserInputType == bind then
				activate(slot, false)
				return
			end
		end
	end)

	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		for _, slot in slots do
			local cooldown = cooldownDurations[slot.ability.id] or slot.ability.cooldown
			local remaining = math.max(0, (cooldownEnds[slot.ability.id] or 0) - now)
			slot.cooldown.Size = UDim2.fromScale(1, remaining / cooldown)
			slot.cooldownText.Text = if remaining >= 1
				then tostring(math.ceil(remaining))
				elseif remaining > 0 and cooldown >= 1 then string.format("%.1f", remaining)
				else ""

			-- Ульта: затемнение показывает незаряженную часть, в центре — процент.
			if slot.ability.kind == "ultimate" then
				local charge = ultCharge()
				local fraction = math.max(remaining / cooldown, 1 - charge)
				slot.cooldown.Size = UDim2.fromScale(1, fraction)
				if remaining <= 0 and charge < 1 then
					slot.cooldownText.Text = `{math.floor(charge * 100)}%`
				end
				local ready = charge >= 1 and remaining <= 0
				if ready and not ultWasReady then
					NotifyController.show(
						`⚡ Ульта «{slot.ability.name}» готова! [{slot.ability.keyLabel}]`,
						slot.ability.color
					)
					ScreenFxController.fovPunch(6)
				end
				ultWasReady = ready
				-- Готовая ульта пульсирует обводкой.
				if ready then
					slot.stroke.Thickness = 2.5 + math.sin(now * 6) * 1.5
				end
			end

			local id = slot.ability.id
			if remaining > 0 then
				readyFlashed[id] = false
			elseif readyFlashed[id] == false and cooldown >= 3 then
				readyFlashed[id] = true
				slot.stroke.Color = Color3.new(1, 1, 1)
				slot.stroke.Thickness = 4
				TweenService
					:Create(slot.stroke, TweenInfo.new(0.4), { Color = slot.ability.color, Thickness = 2 })
					:Play()
			end
		end
	end)
end

return AbilityController
