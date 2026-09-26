--!strict
-- Передвижение по большой карте:
-- • порталы (кольца искр, как у мастеров Камар-Таджа) у спавна, у входа в каждый биом и у разлома
--   Дормамму: подойди, нажми E — откроется карта, выбери, куда перенестись;
-- • бег на Shift (скорость считает сервер, см. Status.setSprint).
-- Сервер проверяет, что игрок действительно стоит у портала и не на арене.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Biomes = require(ReplicatedStorage.Shared.Biomes)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Fx = require(script.Parent.Parent.Combat.Fx)
local Status = require(script.Parent.Parent.Combat.Status)
local Timeline = require(script.Parent.Parent.Combat.Timeline)

local TravelService = {}

local USE_DISTANCE = 16
local COOLDOWN = 3

local travelEvent: RemoteEvent
local lastTravel: { [Player]: number } = {}
local folder: Folder

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = folder
	return p
end

local function buildWaystone(waystone: Biomes.Waystone)
	local base = waystone.position
	-- Портал смотрит на центр карты (у хаба — от спавна наружу).
	local toCenter = -(base * Vector3.new(1, 0, 1))
	local facing = if toCenter.Magnitude > 1 then toCenter.Unit else Vector3.new(1, 0, 0)
	local center = base + Vector3.new(0, 6.5, 0)
	local frame = CFrame.lookAt(center, center + facing)

	part({
		Name = "WaystoneBase",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, 13, 13),
		CFrame = CFrame.new(base + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Slate,
		Color = Color3.fromRGB(90, 85, 95),
	})
	part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.15, 11, 11),
		CFrame = CFrame.new(base + Vector3.new(0, 1.05, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Neon,
		Color = waystone.color,
		Transparency = 0.4,
		CanCollide = false,
	})
	local segments = 20
	for s = 1, segments do
		local angle = (s / segments) * math.pi * 2
		local spark = part({
			Size = Vector3.new(1.6, 0.3, 0.3),
			CFrame = frame * CFrame.Angles(0, 0, angle) * CFrame.new(0, 5, 0),
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(255, 160, 60),
			CanCollide = false,
			CanQuery = false,
			CastShadow = false,
		})
		if s % 4 == 0 then
			local e = Instance.new("ParticleEmitter")
			e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			e.Color = ColorSequence.new(Color3.fromRGB(255, 220, 120), waystone.color)
			e.LightEmission = 1
			e.Size = NumberSequence.new(0.4, 0)
			e.Lifetime = NumberRange.new(0.3, 0.6)
			e.Speed = NumberRange.new(5, 9)
			e.Acceleration = Vector3.new(0, -18, 0)
			e.SpreadAngle = Vector2.new(20, 20)
			e.Rate = 10
			e.Parent = spark
		end
	end
	local window = part({
		Name = "WaystoneWindow",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, 9.4, 9.4),
		CFrame = frame * CFrame.Angles(0, math.rad(90), 0),
		Material = Enum.Material.Neon,
		Color = waystone.color,
		Transparency = 0.6,
		CanCollide = false,
		CastShadow = false,
	})
	local glow = Instance.new("PointLight")
	glow.Color = waystone.color
	glow.Range = 22
	glow.Brightness = 2.5
	glow.Parent = window

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(240, 50)
	billboard.StudsOffset = Vector3.new(0, 7.5, 0)
	billboard.MaxDistance = 250
	billboard.LightInfluence = 0
	billboard.Parent = window
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = waystone.color
	label.TextStrokeTransparency = 0.2
	label.Text = `🌀 {waystone.name}`
	label.Parent = billboard

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Порталы"
	prompt.ObjectText = waystone.name
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = window
	prompt.Triggered:Connect(function(player)
		travelEvent:FireClient(player, "Open", waystone.id)
	end)
end

local function nearWaystone(position: Vector3): Biomes.Waystone?
	for _, waystone in Biomes.Waystones do
		if ((position - waystone.position) * Vector3.new(1, 0, 1)).Magnitude <= USE_DISTANCE then
			return waystone
		end
	end
	return nil
end

local function travel(player: Player, destinationId: unknown): (boolean, string)
	if type(destinationId) ~= "string" then
		return false, "Неизвестный портал"
	end
	local destination = Biomes.WaystoneById[destinationId]
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not destination or not character or not humanoid or not root or humanoid.Health <= 0 then
		return false, "Сейчас нельзя"
	end
	if character:GetAttribute("Zone") == "Arena" then
		return false, "С арены порталы не работают"
	end
	local from = nearWaystone(root.Position)
	if not from then
		return false, "Подойди к порталу"
	end
	if from.id == destination.id then
		return false, "Ты уже здесь"
	end
	if os.clock() - (lastTravel[player] or 0) < COOLDOWN then
		return false, "Портал ещё не остыл"
	end
	lastTravel[player] = os.clock()
	Fx.portal(root.Position, root.CFrame.LookVector, destination.color, 4, 0.8)
	Fx.burst(root.Position, destination.color, 30, 25)
	Fx.sound("Teleport", root.Position, 1, 0.9)
	-- Выходим перед порталом, со стороны центра карты.
	local toCenter = -(destination.position * Vector3.new(1, 0, 1))
	local facing = if toCenter.Magnitude > 1 then toCenter.Unit else Vector3.new(1, 0, 0)
	local arrival = destination.position + facing * 9 + Vector3.new(0, 4, 0)
	character:PivotTo(CFrame.lookAt(arrival, arrival + facing))
	Timeline.clear(player)
	Fx.portal(arrival, facing, destination.color, 4, 0.8)
	Fx.burst(arrival, destination.color, 30, 25)
	return true, `🌀 {destination.name}`
end

function TravelService:Init()
	travelEvent = Remotes.event("Travel")
	Remotes.func("TravelTo").OnServerInvoke = travel
	Remotes.event("Sprint").OnServerEvent:Connect(function(player, on)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			Status.setSprint(humanoid, on == true)
		end
	end)
end

function TravelService:Start()
	folder = Instance.new("Folder")
	folder.Name = "Waystones"
	folder.Parent = workspace
	for _, waystone in Biomes.Waystones do
		buildWaystone(waystone)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastTravel[player] = nil
	end)
end

return TravelService
