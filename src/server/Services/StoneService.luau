--!strict
-- Строит на карте места с Камнями Бесконечности (башни, паркур, лабиринт) и выдаёт камни игрокам.
-- Камень остаётся на месте для всех: каждый игрок собирает свою коллекцию.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Items = require(ReplicatedStorage.Shared.Items)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Fx = require(script.Parent.Parent.Combat.Fx)
local DataService = require(script.Parent.DataService)

local StoneService = {}

-- Где на земле стоит каждое место с камнем (MapService строит к ним светящиеся дорожки).
StoneService.Locations = (
	{
		Power = Vector3.new(70, 0, 70),
		Space = Vector3.new(-90, 0, 50),
		Reality = Vector3.new(0, 0, -130),
		Soul = Vector3.new(-160, 0, -160),
		Time = Vector3.new(150, 0, -70),
		Mind = Vector3.new(130, 0, 150),
	}
) :: { [string]: Vector3 }

local notify: RemoteEvent
local stoneCollected: RemoteEvent
local mapFolder: Folder

local STONE_COLOR = Color3.fromRGB(99, 95, 98)

local function block(size: Vector3, cframe: CFrame, color: Color3?, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color or STONE_COLOR
	part.Material = material or Enum.Material.Slate
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = mapFolder
	return part
end

-- Высокая колонна с лестницей. Возвращает точку на вершине.
local function tower(base: Vector3, height: number, color: Color3): Vector3
	block(Vector3.new(10, height, 10), CFrame.new(base + Vector3.new(0, height / 2, 0)), color)
	-- Площадка не шире колонны, чтобы не нависать над лестницей.
	block(Vector3.new(10, 1, 10), CFrame.new(base + Vector3.new(0, height + 0.5, 0)), color)

	local truss = Instance.new("TrussPart")
	truss.Anchored = true
	truss.Size = Vector3.new(2, height + 2, 2)
	truss.CFrame = CFrame.new(base + Vector3.new(0, (height + 2) / 2, 6))
	truss.Color = Color3.fromRGB(60, 60, 60)
	truss.Parent = mapFolder
	return base + Vector3.new(0, height + 1, 0)
end

-- Спиральные парящие платформы для паркура. Возвращает точку на последней платформе.
local function parkour(center: Vector3, steps: number, color: Color3): Vector3
	local top = center
	for i = 1, steps do
		local angle = i * 0.7
		local position = center + Vector3.new(math.cos(angle) * 14, i * 4, math.sin(angle) * 14)
		block(Vector3.new(6, 1, 6), CFrame.new(position), color, Enum.Material.Neon).Transparency = 0.3
		top = position
	end
	block(Vector3.new(12, 1, 12), CFrame.new(center + Vector3.new(0, steps * 4 + 3, 0)), color)
	block(Vector3.new(6, 1, 6), CFrame.new((top + center + Vector3.new(0, steps * 4 + 3, 0)) / 2), color)
	return center + Vector3.new(0, steps * 4 + 3.5, 0)
end

-- Кольцевой лабиринт из стен с проходами. Возвращает центр.
local function maze(center: Vector3, color: Color3): Vector3
	for ring = 1, 3 do
		local radius = ring * 9
		local segments = 10 + ring * 4
		local gap = math.random(1, segments)
		for s = 1, segments do
			if s ~= gap then
				local angle = (s / segments) * math.pi * 2
				local position = center + Vector3.new(math.cos(angle) * radius, 5, math.sin(angle) * radius)
				local width = 2 * math.pi * radius / segments + 0.5
				block(
					Vector3.new(width, 10, 1.5),
					CFrame.lookAt(position, center + Vector3.new(0, 5, 0)),
					color,
					Enum.Material.Brick
				)
			end
		end
	end
	return center
end

local function pedestal(position: Vector3, color: Color3): Vector3
	block(Vector3.new(4, 1, 4), CFrame.new(position + Vector3.new(0, 0.5, 0)), color, Enum.Material.Marble)
	block(Vector3.new(2.5, 2, 2.5), CFrame.new(position + Vector3.new(0, 2, 0)), color, Enum.Material.Marble)
	return position + Vector3.new(0, 5, 0)
end

local function createPickup(stone: Items.Stone, position: Vector3)
	local part = Instance.new("Part")
	part.Name = stone.id .. "Stone"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.one * 2.2
	part.Position = position
	part.Anchored = true
	part.CanCollide = false
	part.Material = Enum.Material.Neon
	part.Color = stone.color
	part:SetAttribute("StoneId", stone.id)
	part:AddTag("StonePickup")

	local light = Instance.new("PointLight")
	light.Color = stone.color
	light.Range = 16
	light.Brightness = 3
	light.Parent = part

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(220, 40)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 120
	billboard.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = stone.color
	label.TextStrokeTransparency = 0.3
	label.Text = stone.name
	label.Parent = billboard

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Взять"
	prompt.ObjectText = stone.name
	prompt.HoldDuration = 0.6
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = part

	prompt.Triggered:Connect(function(player)
		-- Дополнительная проверка на сервере: игрок действительно стоит рядом с камнем.
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and (root.Position - part.Position).Magnitude <= prompt.MaxActivationDistance + 8 then
			StoneService:GiveStone(player, stone.id)
		end
	end)

	part.Parent = mapFolder
end

function StoneService:GiveStone(player: Player, stoneId: string)
	local stone = Items.StoneById[stoneId]
	local data = DataService:Get(player)
	if not stone or not data then
		return
	end
	if data.Stones[stoneId] then
		notify:FireClient(player, `{stone.name} уже в твоей Перчатке`, stone.color)
		return
	end
	DataService:Update(player, function(d)
		d.Stones[stoneId] = true
		d.Coins += Config.Rewards.StoneFirstPickup
	end)

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		Fx.pillar(root.Position - Vector3.new(0, 3, 0), stone.color, 120, 1.5)
		Fx.burst(root.Position, stone.color, 80, 40)
		Fx.shockwave(root.Position - Vector3.new(0, 2.5, 0), stone.color, 20)
		Fx.flash(root.Position, stone.color, 40, 1)
		Fx.sound("StonePickup", root.Position, 1, 0.8)
	end

	local count = Items.countStones(data.Stones)
	stoneCollected:FireClient(player, stoneId, count)
	notify:FireClient(
		player,
		`{stone.name} получен! ({count}/{#Items.Stones}) +{Config.Rewards.StoneFirstPickup} 🪙`,
		stone.color
	)
	if count == #Items.Stones then
		notify:FireClient(
			player,
			"Все камни собраны! Щелчок [G] доступен.",
			Color3.new(1, 1, 1)
		)
	end
end

function StoneService:Init()
	notify = Remotes.event("Notify")
	stoneCollected = Remotes.event("StoneCollected")
end

function StoneService:Start()
	mapFolder = Instance.new("Folder")
	mapFolder.Name = "StoneLocations"
	mapFolder.Parent = workspace

	local at = StoneService.Locations
	local spots: { [string]: Vector3 } = {
		Power = tower(at.Power, 35, Color3.fromRGB(80, 50, 110)),
		Space = parkour(at.Space, 9, Items.StoneById.Space.color),
		Reality = maze(at.Reality, Color3.fromRGB(110, 45, 45)),
		Soul = tower(at.Soul, 60, Color3.fromRGB(120, 80, 40)),
		Time = parkour(at.Time, 12, Items.StoneById.Time.color),
		Mind = at.Mind,
	}

	for _, stone in Items.Stones do
		local position = pedestal(spots[stone.id], stone.color)
		createPickup(stone, position)
	end
end

return StoneService
