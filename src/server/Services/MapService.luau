--!strict
-- Строит карту в стиле Титана: рельеф из Terrain, кольцо гор по краю, центральная арена
-- с колоннами камней, руины, парящие скалы, светящиеся кристаллы и дорожки к каждому камню.
-- Раскладка детерминирована (Random с фиксированным seed), поэтому карта одинакова в каждой игре.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Items = require(ReplicatedStorage.Shared.Items)

local StoneService = require(script.Parent.StoneService)

local MapService = {}

local SEED = 1488
local WORLD_HALF = 300 -- невидимые стены по краю
local ARENA_RADIUS = 30

local rng = Random.new(SEED)
local folder: Folder

local PALETTE = {
	Ground = Color3.fromRGB(150, 82, 56),
	Rock = Color3.fromRGB(110, 64, 54),
	Basalt = Color3.fromRGB(58, 42, 44),
	CrackedLava = Color3.fromRGB(200, 80, 35),
	Marble = Color3.fromRGB(176, 158, 148),
	ArenaFloor = Color3.fromRGB(52, 44, 52),
	Gold = Color3.fromRGB(230, 175, 50),
}

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = props.Parent or folder
	return p
end

-- Декор, через который можно проходить и который не мешает лучам.
local function ghost(p: Part): Part
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	return p
end

local function randomAngle(): number
	return rng:NextNumber(0, math.pi * 2)
end

local function polar(angle: number, distance: number, y: number?): Vector3
	return Vector3.new(math.cos(angle) * distance, y or 0, math.sin(angle) * distance)
end

-- Расстояние от точки до отрезка по горизонтали (чтобы декор не перекрывал дорожки).
local function distanceToSegment(p: Vector3, a: Vector3, b: Vector3): number
	local ab = (b - a) * Vector3.new(1, 0, 1)
	local ap = (p - a) * Vector3.new(1, 0, 1)
	local t = math.clamp(ap:Dot(ab) / math.max(ab:Dot(ab), 1e-6), 0, 1)
	return (ap - ab * t).Magnitude
end

local function isFree(position: Vector3, clearance: number): boolean
	if position.Magnitude < ARENA_RADIUS + 20 + clearance then
		return false
	end
	for _, location in StoneService.Locations do
		if (position - location).Magnitude < 38 + clearance then
			return false
		end
		if distanceToSegment(position, Vector3.zero, location) < 6 + clearance then
			return false
		end
	end
	return true
end

-- Случайная свободная точка в кольце [minR, maxR].
local function freeSpot(minR: number, maxR: number, clearance: number): Vector3?
	for _ = 1, 30 do
		local spot = polar(randomAngle(), rng:NextNumber(minR, maxR))
		if isFree(spot, clearance) then
			return spot
		end
	end
	return nil
end

local function buildTerrain()
	local terrain = workspace.Terrain
	terrain:SetMaterialColor(Enum.Material.Ground, PALETTE.Ground)
	terrain:SetMaterialColor(Enum.Material.Rock, PALETTE.Rock)
	terrain:SetMaterialColor(Enum.Material.Basalt, PALETTE.Basalt)
	terrain:SetMaterialColor(Enum.Material.CrackedLava, PALETTE.CrackedLava)

	-- Основание: поверхность ровно на y = 0.
	terrain:FillBlock(
		CFrame.new(0, -12, 0),
		Vector3.new(WORLD_HALF * 2 + 200, 24, WORLD_HALF * 2 + 200),
		Enum.Material.Ground
	)

	-- Пятна базальта и светящейся лавы.
	for _ = 1, 70 do
		local spot = polar(randomAngle(), rng:NextNumber(ARENA_RADIUS + 8, WORLD_HALF - 20), -1)
		local material = if rng:NextNumber() < 0.3 then Enum.Material.CrackedLava else Enum.Material.Basalt
		terrain:FillCylinder(CFrame.new(spot), 2, rng:NextNumber(5, 16), material)
	end

	-- Кольцо гор по краю карты.
	local mountains = 30
	for i = 1, mountains do
		local angle = (i / mountains) * math.pi * 2 + rng:NextNumber(-0.08, 0.08)
		local distance = rng:NextNumber(330, 370)
		local radius = rng:NextNumber(55, 90)
		terrain:FillBall(polar(angle, distance, -radius * 0.25), radius, Enum.Material.Rock)
		terrain:FillBall(polar(angle, distance + 20, radius * 0.35), radius * 0.6, Enum.Material.Basalt)
	end

	-- Скальные шпили перед горами.
	for _ = 1, 16 do
		local angle = randomAngle()
		local height = rng:NextNumber(50, 120)
		local base = polar(angle, rng:NextNumber(262, 295))
		local tilt = CFrame.Angles(rng:NextNumber(-0.15, 0.15), 0, rng:NextNumber(-0.15, 0.15))
		terrain:FillCylinder(
			CFrame.new(base + Vector3.new(0, height / 2 - 4, 0)) * tilt,
			height,
			rng:NextNumber(6, 12),
			Enum.Material.Rock
		)
	end

	local clouds = terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover = 0.55
	clouds.Density = 0.55
	clouds.Color = Color3.fromRGB(235, 170, 140)
	clouds.Parent = terrain
end

local function buildBoundary()
	local height = 400
	for _, side in
		{ Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) }
	do
		local isX = side.X ~= 0
		part({
			Name = "Boundary",
			Size = if isX
				then Vector3.new(4, height, WORLD_HALF * 2)
				else Vector3.new(WORLD_HALF * 2, height, 4),
			Position = side * WORLD_HALF + Vector3.new(0, height / 2 - 10, 0),
			Transparency = 1,
			CanQuery = false,
		})
	end
end

local function buildArena()
	local cylinder = CFrame.Angles(0, 0, math.rad(90)) -- ось цилиндра вертикально

	-- Светящийся золотой край и основание арены.
	ghost(part({
		Name = "ArenaRim",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.6, ARENA_RADIUS * 2 + 2.5, ARENA_RADIUS * 2 + 2.5),
		CFrame = CFrame.new(0, 0.2, 0) * cylinder,
		Material = Enum.Material.Neon,
		Color = PALETTE.Gold,
	}))
	part({
		Name = "Arena",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2, ARENA_RADIUS * 2, ARENA_RADIUS * 2),
		CFrame = CFrame.new(0, 0, 0) * cylinder,
		Material = Enum.Material.Slate,
		Color = PALETTE.ArenaFloor,
	})

	-- Узор на полу: золотые круги.
	for i, radius in { 22, 12, 4 } do
		ghost(part({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.1, radius * 2, radius * 2),
			CFrame = CFrame.new(0, 1.02 + i * 0.01, 0) * cylinder,
			Material = Enum.Material.Neon,
			Color = PALETTE.Gold,
			Transparency = 0.55,
		}))
		ghost(part({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.1, radius * 2 - 1.2, radius * 2 - 1.2),
			CFrame = CFrame.new(0, 1.025 + i * 0.01, 0) * cylinder,
			Material = Enum.Material.Slate,
			Color = PALETTE.ArenaFloor,
		}))
	end

	-- Шесть колонн с парящими кристаллами цветов камней.
	for i, stone in Items.Stones do
		local angle = (i / #Items.Stones) * math.pi * 2
		local base = polar(angle, ARENA_RADIUS - 4, 1)

		-- Луч от центра к колонне.
		local mid = polar(angle, (ARENA_RADIUS - 4) / 2, 1.04)
		ghost(part({
			Size = Vector3.new(0.6, 0.1, ARENA_RADIUS - 8),
			CFrame = CFrame.lookAt(mid, polar(angle, ARENA_RADIUS, 1.04)),
			Material = Enum.Material.Neon,
			Color = stone.color,
			Transparency = 0.4,
		}))

		part({
			Size = Vector3.new(4, 1.5, 4),
			Position = base + Vector3.new(0, 0.75, 0),
			Material = Enum.Material.Marble,
			Color = PALETTE.Marble,
		})
		part({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(14, 2.6, 2.6),
			CFrame = CFrame.new(base + Vector3.new(0, 8.5, 0)) * cylinder,
			Material = Enum.Material.Marble,
			Color = PALETTE.Marble,
		})
		part({
			Size = Vector3.new(3.4, 1, 3.4),
			Position = base + Vector3.new(0, 16, 0),
			Material = Enum.Material.Marble,
			Color = PALETTE.Marble,
		})

		local crystal = ghost(part({
			Name = stone.id .. "Crystal",
			Size = Vector3.new(1.6, 3.2, 1.6),
			CFrame = CFrame.new(base + Vector3.new(0, 19.5, 0)) * CFrame.Angles(0, 0, math.rad(45)),
			Material = Enum.Material.Neon,
			Color = stone.color,
		}))
		crystal:AddTag("Spin")
		local light = Instance.new("PointLight")
		light.Color = stone.color
		light.Range = 18
		light.Brightness = 2.5
		light.Parent = crystal
	end
end

-- Светящиеся плитки от арены к каждому месту с камнем.
local function buildPaths()
	for stoneId, location in StoneService.Locations do
		local stone = Items.StoneById[stoneId]
		local flat = location * Vector3.new(1, 0, 1)
		local direction = flat.Unit
		local startDistance = ARENA_RADIUS + 4
		local endDistance = flat.Magnitude - 16
		local distance = startDistance
		while distance < endDistance do
			local position = direction * distance + Vector3.new(0, 0.05, 0)
			ghost(part({
				Name = "PathTile",
				Size = Vector3.new(2.5, 0.3, 4),
				CFrame = CFrame.lookAt(position, position + direction),
				Material = Enum.Material.Neon,
				Color = stone.color,
				Transparency = 0.35,
			}))
			distance += 7
		end
	end
end

local function buildRuins()
	for _ = 1, 40 do
		local spot = freeSpot(55, 250, 4)
		if spot then
			local height = rng:NextNumber(6, 22)
			local radius = rng:NextNumber(1.5, 2.6)
			part({
				Size = Vector3.new(radius * 2.6, 1.2, radius * 2.6),
				Position = spot + Vector3.new(0, 0.6, 0),
				Material = Enum.Material.Marble,
				Color = PALETTE.Marble,
			})
			if rng:NextNumber() < 0.3 then
				-- Упавшая колонна лежит на земле.
				part({
					Shape = Enum.PartType.Cylinder,
					Size = Vector3.new(height, radius * 2, radius * 2),
					CFrame = CFrame.new(spot + Vector3.new(0, radius, 0))
						* CFrame.Angles(0, randomAngle(), 0),
					Material = Enum.Material.Marble,
					Color = PALETTE.Marble,
				})
			else
				local tilt = CFrame.Angles(rng:NextNumber(-0.2, 0.2), 0, rng:NextNumber(-0.2, 0.2))
				part({
					Shape = Enum.PartType.Cylinder,
					Size = Vector3.new(height, radius * 2, radius * 2),
					CFrame = CFrame.new(spot + Vector3.new(0, height / 2 + 1, 0))
						* tilt
						* CFrame.Angles(0, 0, math.rad(90)),
					Material = Enum.Material.Marble,
					Color = PALETTE.Marble,
				})
			end
		end
	end
end

local function buildFloatingRocks()
	for _ = 1, 28 do
		local spot = freeSpot(60, 270, 0)
		if spot then
			local size = rng:NextNumber(4, 14)
			local position = spot + Vector3.new(0, rng:NextNumber(30, 90), 0)
			local rock = ghost(part({
				Name = "FloatingRock",
				Size = Vector3.new(size, size * rng:NextNumber(0.5, 0.9), size * rng:NextNumber(0.7, 1.1)),
				CFrame = CFrame.new(position) * CFrame.Angles(randomAngle(), randomAngle(), randomAngle()),
				Material = if rng:NextNumber() < 0.5 then Enum.Material.Rock else Enum.Material.Basalt,
				Color = if rng:NextNumber() < 0.5 then PALETTE.Rock else PALETTE.Basalt,
			}))
			rock.CastShadow = true
			if rng:NextNumber() < 0.5 then
				local stone = Items.Stones[rng:NextInteger(1, #Items.Stones)]
				ghost(part({
					Size = Vector3.new(1, size * 0.5, 1),
					CFrame = CFrame.new(position - Vector3.new(0, size * 0.35, 0))
						* CFrame.Angles(0, 0, math.rad(180)),
					Material = Enum.Material.Neon,
					Color = stone.color,
				}))
			end
		end
	end
end

local function buildCrystals()
	for _ = 1, 24 do
		local spot = freeSpot(45, 260, 3)
		if spot then
			local stone = Items.Stones[rng:NextInteger(1, #Items.Stones)]
			local cluster = Instance.new("Model")
			cluster.Name = "CrystalCluster"
			for _ = 1, rng:NextInteger(3, 6) do
				local height = rng:NextNumber(2, 7)
				local offset = Vector3.new(rng:NextNumber(-2, 2), 0, rng:NextNumber(-2, 2))
				local tilt =
					CFrame.Angles(rng:NextNumber(-0.5, 0.5), randomAngle(), rng:NextNumber(-0.5, 0.5))
				ghost(part({
					Size = Vector3.new(rng:NextNumber(0.6, 1.4), height, rng:NextNumber(0.6, 1.4)),
					CFrame = CFrame.new(spot + offset) * tilt * CFrame.new(0, height / 2 - 0.5, 0),
					Material = Enum.Material.Neon,
					Color = stone.color,
					Transparency = 0.15,
					Parent = cluster,
				}))
			end
			local core = cluster:FindFirstChildOfClass("Part")
			if core then
				local light = Instance.new("PointLight")
				light.Color = stone.color
				light.Range = 14
				light.Brightness = 1.5
				light.Parent = core
			end
			cluster.Parent = folder
		end
	end
end

function MapService:Init()
	folder = Instance.new("Folder")
	folder.Name = "Map"
	folder.Parent = workspace

	buildTerrain()
	buildBoundary()
	buildArena()
	buildPaths()
	buildRuins()
	buildFloatingRocks()
	buildCrystals()
end

return MapService
