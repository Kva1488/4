--!strict
-- "Сочность" боя на клиенте:
-- цифры урона над целями, хитмаркер и счётчик комбо для атакующего,
-- красная вспышка и тряска при получении урона, пульсация при низком здоровье, лента убийств.

local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Ui = require(script.Parent.Parent.Ui)

local player = Players.LocalPlayer

local COMBO_WINDOW = 2.5
local MAX_NUMBERS_DISTANCE = 150
local KILLFEED_MAX = 5

local DamageFxController = {}

local gui: ScreenGui
local hitmarker: TextLabel
local comboLabel: TextLabel
local comboStroke: UIStroke
local damageOverlay: Frame
local killfeed: Frame
local lowHealthTint: ColorCorrectionEffect

local comboCount = 0
local lastHitTime = 0

local function damageNumber(position: Vector3, amount: number, color: Color3, big: boolean)
	local camera = workspace.CurrentCamera
	if not camera or (camera.CFrame.Position - position).Magnitude > MAX_NUMBERS_DISTANCE then
		return
	end
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.one * 0.1
	holder.Position = position
		+ Vector3.new(math.random() * 3 - 1.5, 2.5 + math.random(), math.random() * 3 - 1.5)
	holder.Parent = workspace.CurrentCamera

	local size = if big then 70 else 44
	local billboard = Ui.create("BillboardGui", {
		Size = UDim2.fromOffset(size * 2.4, size),
		AlwaysOnTop = true,
		LightInfluence = 0,
		Adornee = holder,
		Parent = holder,
	})
	local label = Ui.label({
		Size = UDim2.fromScale(1, 1),
		Text = tostring(math.floor(amount + 0.5)),
		TextColor3 = color,
		Font = Enum.Font.GothamBlack,
		Parent = billboard,
	})
	local stroke = Ui.create(
		"UIStroke",
		{ Thickness = 2, Color = Color3.new(0, 0, 0), Transparency = 0.2, Parent = label }
	)
	local scale = Ui.create("UIScale", { Scale = 1.8, Parent = label })

	TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	TweenService:Create(billboard, TweenInfo.new(0.9, Enum.EasingStyle.Quad), {
		StudsOffset = Vector3.new(0, 3, 0),
	}):Play()
	task.delay(0.45, function()
		TweenService:Create(label, TweenInfo.new(0.45), { TextTransparency = 1 }):Play()
		TweenService:Create(stroke, TweenInfo.new(0.45), { Transparency = 1 }):Play()
	end)
	Debris:AddItem(holder, 1)
end

local function showHitmarker(killed: boolean)
	hitmarker.TextColor3 = if killed then Color3.fromRGB(255, 70, 70) else Color3.new(1, 1, 1)
	hitmarker.TextTransparency = 0
	local scale = hitmarker:FindFirstChildOfClass("UIScale") :: UIScale
	scale.Scale = if killed then 1.8 else 1.3
	TweenService:Create(scale, TweenInfo.new(0.15), { Scale = 1 }):Play()
	TweenService:Create(hitmarker, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
	Ui.playSound("HitMarker", 0.4, if killed then 0.7 else 1.2)
end

local function bumpCombo()
	local now = os.clock()
	comboCount = if now - lastHitTime <= COMBO_WINDOW then comboCount + 1 else 1
	lastHitTime = now
	if comboCount < 2 then
		return
	end
	comboLabel.Text = `x{comboCount} КОМБО`
	comboLabel.TextTransparency = 0
	comboStroke.Transparency = 0.2
	-- Чем больше комбо, тем "горячее" цвет.
	local heat = math.clamp(comboCount / 20, 0, 1)
	comboLabel.TextColor3 = Color3.fromRGB(255, 230, 120):Lerp(Color3.fromRGB(255, 60, 60), heat)
	local scale = comboLabel:FindFirstChildOfClass("UIScale") :: UIScale
	scale.Scale = 1.35
	TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

local function shakeCamera(strength: number, duration: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	task.spawn(function()
		local finish = os.clock() + duration
		while os.clock() < finish do
			local decay = (finish - os.clock()) / duration
			humanoid.CameraOffset = Vector3.new(math.random() - 0.5, math.random() - 0.5, 0)
				* strength
				* decay
			RunService.RenderStepped:Wait()
		end
		humanoid.CameraOffset = Vector3.zero
	end)
end

-- Короткая вспышка-подсветка персонажа, по которому попали.
local flashing: { [Instance]: Highlight } = setmetatable({}, { __mode = "k" }) :: any

local function flashModel(victim: Instance?, color: Color3)
	if not victim or not victim:IsA("Model") then
		return
	end
	local highlight = flashing[victim]
	if not highlight then
		local created = Instance.new("Highlight")
		created.DepthMode = Enum.HighlightDepthMode.Occluded
		created.OutlineTransparency = 1
		created.Parent = victim
		flashing[victim] = created
		highlight = created
	end
	local h = highlight :: Highlight
	h.FillColor = Color3.new(1, 1, 1):Lerp(color, 0.3)
	h.FillTransparency = 0.25
	h.Enabled = true
	TweenService:Create(h, TweenInfo.new(0.18), { FillTransparency = 1 }):Play()
end

local function onHit(
	position: Vector3,
	amount: number,
	color: Color3,
	attackerId: number,
	victim: Instance?,
	killed: boolean
)
	local big = amount >= 30 or killed
	damageNumber(position, amount, color, big)
	flashModel(victim, color)

	if attackerId == player.UserId then
		showHitmarker(killed)
		bumpCombo()
		shakeCamera(if big then 0.35 else 0.12, 0.12)
	end
	if victim and victim == player.Character then
		damageOverlay.BackgroundTransparency = 0.55
		TweenService:Create(damageOverlay, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
		shakeCamera(math.clamp(amount / 40, 0.2, 1), 0.25)
	end
end

local function onKillfeed(killer: string, victim: string, source: string, color: Color3)
	local entry = Ui.create("Frame", {
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundColor3 = Ui.Colors.Panel,
		BackgroundTransparency = 0.25,
		LayoutOrder = -math.floor(os.clock() * 100),
		Parent = killfeed,
	}, {
		Ui.corner(8),
		Ui.create("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
		Ui.label({
			Size = UDim2.new(1, 0, 1, -8),
			Position = UDim2.fromOffset(0, 4),
			RichText = true,
			Text = `<b>{killer}</b>  <font color="#{color:ToHex()}">[{source}]</font>  {victim}`,
			TextXAlignment = Enum.TextXAlignment.Right,
			Font = Enum.Font.GothamMedium,
		}),
	})
	local entries = {}
	for _, child in killfeed:GetChildren() do
		if child:IsA("Frame") then
			table.insert(entries, child)
		end
	end
	table.sort(entries, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for i = KILLFEED_MAX + 1, #entries do
		entries[i]:Destroy()
	end
	task.delay(6, function()
		if entry.Parent then
			TweenService:Create(entry, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
			task.wait(0.4)
			entry:Destroy()
		end
	end)
end

local function build()
	gui = Ui.create("ScreenGui", {
		Name = "CombatFx",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 15,
		Parent = player:WaitForChild("PlayerGui"),
	})

	damageOverlay = Ui.create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(200, 0, 0),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		-- Затемнение к центру, чтобы вспышка шла "по краям".
		Ui.create("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.25, 0.7),
				NumberSequenceKeypoint.new(0.75, 0.7),
				NumberSequenceKeypoint.new(1, 0),
			}),
		}),
	})

	hitmarker = Ui.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(40, 40),
		Text = "✕",
		TextTransparency = 1,
		Font = Enum.Font.GothamBlack,
		Parent = gui,
	})
	Ui.create("UIScale", { Parent = hitmarker })

	comboLabel = Ui.label({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -40, 0.42, 0),
		Size = UDim2.fromOffset(260, 48),
		Text = "",
		TextTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Right,
		Font = Enum.Font.GothamBlack,
		Rotation = -4,
		Parent = gui,
	})
	comboStroke = Ui.create("UIStroke", { Thickness = 2.5, Transparency = 1, Parent = comboLabel })
	Ui.create("UIScale", { Parent = comboLabel })

	killfeed = Ui.create("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 60),
		Size = UDim2.fromOffset(340, 180),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		Ui.create("UIListLayout", {
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
		}),
	})

	lowHealthTint = Instance.new("ColorCorrectionEffect")
	lowHealthTint.Name = "LowHealthTint"
	lowHealthTint.Parent = Lighting
end

function DamageFxController:Start()
	build()
	Remotes.event("Hit").OnClientEvent:Connect(onHit)
	Remotes.event("Killfeed").OnClientEvent:Connect(onKillfeed)

	RunService.RenderStepped:Connect(function()
		-- Комбо гаснет, если долго не попадать.
		if comboCount > 0 and os.clock() - lastHitTime > COMBO_WINDOW then
			comboCount = 0
			TweenService:Create(comboLabel, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
			TweenService:Create(comboStroke, TweenInfo.new(0.3), { Transparency = 1 }):Play()
		end

		-- Пульсация и потеря цвета при здоровье ниже 30%.
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local ratio = if humanoid and humanoid.MaxHealth > 0 then humanoid.Health / humanoid.MaxHealth else 1
		if humanoid and humanoid.Health > 0 and ratio < 0.3 then
			local danger = 1 - ratio / 0.3
			local pulse = (math.sin(os.clock() * 6) + 1) / 2
			lowHealthTint.Saturation = -0.6 * danger
			lowHealthTint.TintColor = Color3.new(1, 1, 1)
				:Lerp(Color3.fromRGB(255, 150, 150), danger * (0.5 + pulse * 0.5))
		else
			lowHealthTint.Saturation = 0
			lowHealthTint.TintColor = Color3.new(1, 1, 1)
		end
	end)
end

return DamageFxController
