--!strict
-- Панель способностей внизу экрана: клавиши, прицел, перезарядки, блокировка по камням.
-- На телефоне способности нажимаются кнопками на панели.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Abilities = require(ReplicatedStorage.Shared.Abilities)
local Items = require(ReplicatedStorage.Shared.Items)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local PlayerState = require(script.Parent.Parent.PlayerState)
local Ui = require(script.Parent.Parent.Ui)
local NotifyController = require(script.Parent.NotifyController)

local player = Players.LocalPlayer

local SLOT = 58
local GAP = 6
local SHAKE_ON = { PowerWave = 0.4, Meteor = 0.6, Snap = 1.2 }

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

local function activate(slot: Slot, fromButton: boolean)
	local ability = slot.ability
	if not Abilities.isUnlocked(ability, PlayerState.stones()) then
		flashLocked(slot)
		return
	end
	if os.clock() < (cooldownEnds[ability.id] or 0) then
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

local function refreshLocks()
	local stones = PlayerState.stones()
	for _, slot in slots do
		local unlocked = Abilities.isUnlocked(slot.ability, stones)
		slot.lock.Visible = not unlocked
		slot.stroke.Transparency = if unlocked then 0 else 0.7
		slot.button.BackgroundTransparency = if unlocked then 0.1 else 0.45
	end
end

local function buildHotbar()
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local columns = if touch then 6 else #Abilities.List
	local rows = math.ceil(#Abilities.List / columns)
	local width = columns * (SLOT + GAP) - GAP
	local height = rows * (SLOT + GAP) - GAP

	local gui = Ui.create("ScreenGui", {
		Name = "Abilities",
		ResetOnSpawn = false,
		DisplayOrder = 5,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local bar = Ui.create("Frame", {
		Name = "Hotbar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.fromOffset(width, height),
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

	-- Масштабируем панель под ширину экрана (на телефоне оставляем место под джойстик и прыжок).
	local scale = Ui.create("UIScale", { Parent = bar })
	local function fit()
		local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize
			or Vector2.new(1280, 720)
		local available = viewport.X * (if touch then 0.5 else 0.95)
		scale.Scale = math.min(1, available / width)
	end
	fit()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end

	for index, ability in Abilities.List do
		table.insert(slots, createSlot(ability, index, bar))
	end
end

function AbilityController:Init()
	useAbility = Remotes.event("UseAbility")
end

function AbilityController:Start()
	-- Свой инвентарь и панель вместо стандартного рюкзака.
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, false)

	buildHotbar()
	refreshLocks()
	PlayerState.Changed:Connect(refreshLocks)

	Remotes.event("AbilityCast").OnClientEvent:Connect(function(abilityId: string)
		local ability = Abilities.ById[abilityId]
		if ability then
			cooldownEnds[abilityId] = os.clock() + ability.cooldown
			local strength = SHAKE_ON[abilityId]
			if strength then
				shake(strength)
			end
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
			local cooldown = slot.ability.cooldown
			local remaining = math.max(0, (cooldownEnds[slot.ability.id] or 0) - now)
			slot.cooldown.Size = UDim2.fromScale(1, remaining / cooldown)
			slot.cooldownText.Text = if remaining >= 1
				then tostring(math.ceil(remaining))
				elseif remaining > 0 and cooldown >= 1 then string.format("%.1f", remaining)
				else ""
		end
	end)
end

return AbilityController
