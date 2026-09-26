--!strict
-- Строит шесть биомов большой карты (Shared/Biomes): рельеф из Terrain и декор из деталей.
-- Середину каждого биома (радиус ~35) оставляет свободной: там StoneService ставит испытание
-- с камнем (башня, паркур, лабиринт, пьедестал) на высоте BiomeBuilder.stoneBase(stoneId).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Biomes = require(ReplicatedStorage.Shared.Biomes)

local BiomeBuilder = {}

-- Высота, на которой начинается испытание с камнем (озёрный остров, холм и т. д.).
local STONE_HEIGHT: { [string]: number } = {
	Power = 2, -- остров посреди озера Мораг
	Mind = 30, -- вершина холма у Водопада Воинов
}

function BiomeBuilder.stoneBase(stoneId: string): Vector3
	local biome = Biomes.ByStone[stoneId]
	return biome.center + Vector3.new(0, STONE_HEIGHT[stoneId] or 0, 0)
end

local CYLINDER_UP = CFrame.Angles(0, 0, math.rad(90)) -- ось цилиндра вертикально

local folder: Folder
local rng: Random

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		if key ~= "Parent" then
			(p :: any)[key] = value
		end
	end
	p.Parent = props.Parent or folder
	return p
end

local function ghost(p: Part): Part
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	return p
end

local function light(parent: Instance, color: Color3, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Parent = parent
end

-- Случайная точка в кольце биома (вне центра с испытанием и вне дорожки к центру карты).
local function spotIn(biome: Biomes.Biome, minR: number, maxR: number): Vector3
	for _ = 1, 20 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * rng:NextNumber(minR, maxR)
		local inward = -(biome.center * Vector3.new(1, 0, 1)).Unit
		-- Дорожка и портал лежат на луче к центру карты: там ничего не ставим.
		local along = offset:Dot(inward)
		local side = (offset - inward * along).Magnitude
		if not (along > 0 and side < 12) then
			return biome.center + offset
		end
	end
	return biome.center + Vector3.new(minR, 0, 0)
end

local function groundLayer(biome: Biomes.Biome, material: Enum.Material)
	workspace.Terrain:FillCylinder(
		CFrame.new(biome.center + Vector3.new(0, -2, 0)),
		4,
		biome.radius,
		material
	)
end

local function tree(position: Vector3, height: number, leaves: Color3)
	part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, 1.6, 1.6),
		CFrame = CFrame.new(position + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Wood,
		Color = Color3.fromRGB(95, 65, 40),
	})
	for i = 1, 3 do
		local offset = Vector3.new(rng:NextNumber(-2, 2), height + i * 1.2 - 1, rng:NextNumber(-2, 2))
		part({
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * rng:NextNumber(6, 9),
			Position = position + offset,
			Material = Enum.Material.Grass,
			Color = leaves:Lerp(Color3.new(0, 0, 0), rng:NextNumber(0, 0.25)),
			CanCollide = false,
		})
	end
end

-- ── Мораг: затопленный храм посреди озера ──────────────────────────────────
local function buildMorag(biome: Biomes.Biome)
	local terrain = workspace.Terrain
	local c = biome.center
	terrain:SetMaterialColor(Enum.Material.Sand, Color3.fromRGB(150, 120, 110))
	groundLayer(biome, Enum.Material.Sand)
	-- Озеро и остров.
	terrain:FillCylinder(CFrame.new(c + Vector3.new(0, -4, 0)), 8, 75, Enum.Material.Water)
	terrain:FillCylinder(CFrame.new(c + Vector3.new(0, -3, 0)), 10, 20, Enum.Material.Sandstone)
	-- Каменный мост к острову со стороны центра карты.
	local inward = -(c * Vector3.new(1, 0, 1)).Unit
	for step = 0, 11 do
		local position = c + inward * (20 + step * 5) + Vector3.new(0, 1.2, 0)
		part({
			Size = Vector3.new(6, 1, 5.2),
			CFrame = CFrame.lookAt(position, position + inward),
			Material = Enum.Material.Cobblestone,
			Color = Color3.fromRGB(120, 105, 110),
		})
	end
	-- Храм: колонны по кругу острова, часть обрушена.
	for i = 1, 10 do
		local angle = (i / 10) * math.pi * 2
		local base = c + Vector3.new(math.cos(angle) * 15, 2, math.sin(angle) * 15)
		local broken = i % 3 == 0
		local height = if broken then rng:NextNumber(4, 8) else 16
		part({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(height, 2.4, 2.4),
			CFrame = CFrame.new(base + Vector3.new(0, height / 2, 0)) * CYLINDER_UP,
			Material = Enum.Material.Marble,
			Color = Color3.fromRGB(160, 140, 170),
		})
	end
	-- Руины в воде и светящиеся фиолетовые кристаллы (энергия Камня Силы).
	for _ = 1, 16 do
		local spot = spotIn(biome, 30, 70)
		part({
			Size = Vector3.new(rng:NextNumber(3, 7), rng:NextNumber(4, 12), rng:NextNumber(3, 7)),
			CFrame = CFrame.new(spot) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 6), 0.3),
			Material = Enum.Material.Marble,
			Color = Color3.fromRGB(140, 120, 150),
		})
	end
	for _ = 1, 14 do
		local spot = spotIn(biome, 78, 140)
		local crystal = ghost(part({
			Size = Vector3.new(1.5, rng:NextNumber(4, 9), 1.5),
			CFrame = CFrame.new(spot)
				* CFrame.Angles(rng:NextNumber(-0.4, 0.4), 0, rng:NextNumber(-0.4, 0.4)),
			Material = Enum.Material.Neon,
			Color = biome.color,
		}))
		light(crystal, biome.color, 14, 1.5)
	end
end

-- ── Ваканда: джунгли, холм и Водопад Воинов ────────────────────────────────
local function buildWakanda(biome: Biomes.Biome)
	local terrain = workspace.Terrain
	local c = biome.center
	terrain:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromRGB(70, 130, 60))
	groundLayer(biome, Enum.Material.LeafyGrass)
	-- Холм с Камнем Разума: пологий склон, на вершине — площадка.
	terrain:FillBall(c + Vector3.new(0, -50, 0), 80, Enum.Material.Grass)
	part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, 16, 16),
		CFrame = CFrame.new(c + Vector3.new(0, STONE_HEIGHT.Mind - 0.5, 0)) * CYLINDER_UP,
		Material = Enum.Material.Marble,
		Color = Color3.fromRGB(200, 190, 170),
	})
	-- Водопад Воинов: две скалы и поток между ними с бассейном.
	local outward = (c * Vector3.new(1, 0, 1)).Unit
	local right = Vector3.new(-outward.Z, 0, outward.X)
	local fallBase = c + outward * 95
	for _, side in { -1, 1 } do
		terrain:FillBlock(
			CFrame.lookAt(
				fallBase + right * side * 16 + Vector3.new(0, 20, 0),
				fallBase + Vector3.new(0, 20, 0)
			),
			Vector3.new(14, 44, 30),
			Enum.Material.Rock
		)
	end
	terrain:FillCylinder(
		CFrame.new(fallBase - outward * 14 + Vector3.new(0, -3, 0)),
		6,
		16,
		Enum.Material.Water
	)
	local fall = ghost(part({
		Size = Vector3.new(16, 40, 2),
		CFrame = CFrame.lookAt(fallBase + Vector3.new(0, 20, 0), fallBase + Vector3.new(0, 20, 0) - outward),
		Material = Enum.Material.Glass,
		Color = Color3.fromRGB(120, 190, 255),
		Transparency = 0.35,
	}))
	local mist = Instance.new("ParticleEmitter")
	mist.Texture = "rbxasset://textures/particles/smoke_main.dds"
	mist.Color = ColorSequence.new(Color3.fromRGB(220, 240, 255))
	mist.Size = NumberSequence.new(4, 9)
	mist.Transparency = NumberSequence.new(0.6, 1)
	mist.Lifetime = NumberRange.new(1.5, 2.5)
	mist.Speed = NumberRange.new(2, 5)
	mist.EmissionDirection = Enum.NormalId.Bottom
	mist.Rate = 12
	mist.Parent = fall
	-- Джунгли.
	for _ = 1, 45 do
		local spot = spotIn(biome, 66, 145)
		if ((spot - fallBase) * Vector3.new(1, 0, 1)).Magnitude > 28 then
			tree(spot, rng:NextNumber(10, 20), Color3.fromRGB(60, 140, 60))
		end
	end
	-- Светящиеся жилы вибраниума.
	for _ = 1, 12 do
		local spot = spotIn(biome, 40, 130)
		local vein = ghost(part({
			Size = Vector3.new(0.6, 0.3, rng:NextNumber(6, 14)),
			CFrame = CFrame.new(spot + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0),
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(140, 110, 255),
		}))
		light(vein, vein.Color, 10, 1)
	end
end

-- ── Асгард: золотые шпили, дворец и Радужный мост к обсерватории ───────────
local function buildAsgard(biome: Biomes.Biome)
	local terrain = workspace.Terrain
	local c = biome.center
	local gold = Color3.fromRGB(225, 180, 70)
	terrain:SetMaterialColor(Enum.Material.Pavement, Color3.fromRGB(200, 190, 165))
	groundLayer(biome, Enum.Material.Pavement)
	-- Обсерватория Хеймдалля: золотой купол у подножия паркура.
	part({
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 14,
		Position = c + Vector3.new(0, -2, 0),
		Material = Enum.Material.Metal,
		Color = gold,
	})
	-- Радужный мост (Биврёст) от портала к обсерватории.
	local inward = -(c * Vector3.new(1, 0, 1)).Unit
	local stripes = {
		Color3.fromRGB(255, 70, 70),
		Color3.fromRGB(255, 170, 60),
		Color3.fromRGB(255, 240, 80),
		Color3.fromRGB(80, 230, 110),
		Color3.fromRGB(70, 160, 255),
		Color3.fromRGB(170, 90, 255),
	}
	local length = biome.radius - 30
	local mid = c + inward * (length / 2 + 10) + Vector3.new(0, 0.12, 0)
	local right = Vector3.new(-inward.Z, 0, inward.X)
	for i, color in stripes do
		ghost(part({
			Size = Vector3.new(1, 0.2, length),
			CFrame = CFrame.lookAt(mid + right * (i - 3.5) * 1, mid + right * (i - 3.5) + inward),
			Material = Enum.Material.Neon,
			Color = color,
			Transparency = 0.1,
		}))
	end
	-- Золотые шпили кольцом.
	for i = 1, 14 do
		local angle = (i / 14) * math.pi * 2
		local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * rng:NextNumber(70, 130)
		if offset.Unit:Dot(inward) < 0.9 then
			local height = rng:NextNumber(35, 80)
			local base = c + offset
			part({
				Size = Vector3.new(8, height, 8),
				CFrame = CFrame.new(base + Vector3.new(0, height / 2, 0)),
				Material = Enum.Material.Marble,
				Color = Color3.fromRGB(230, 220, 195),
			})
			part({
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(14, 5, 5),
				CFrame = CFrame.new(base + Vector3.new(0, height + 7, 0)) * CYLINDER_UP,
				Material = Enum.Material.Metal,
				Color = gold,
			})
			local tip = ghost(part({
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * 3,
				Position = base + Vector3.new(0, height + 15, 0),
				Material = Enum.Material.Neon,
				Color = Color3.fromRGB(255, 230, 150),
			}))
			light(tip, tip.Color, 30, 2)
		end
	end
	-- Дворец Одина: ступенчатое здание с золотыми краями за обсерваторией.
	local palace = c - inward * 110
	for level = 0, 4 do
		local size = 60 - level * 11
		local height = 8 + level * 2
		local y = level * 8
		part({
			Size = Vector3.new(size, height, size * 0.7),
			CFrame = CFrame.lookAt(
				palace + Vector3.new(0, y + height / 2, 0),
				c + Vector3.new(0, y + height / 2, 0)
			),
			Material = Enum.Material.Marble,
			Color = Color3.fromRGB(235, 225, 200),
		})
		ghost(part({
			Size = Vector3.new(size + 0.4, 0.8, size * 0.7 + 0.4),
			CFrame = CFrame.lookAt(palace + Vector3.new(0, y + height, 0), c + Vector3.new(0, y + height, 0)),
			Material = Enum.Material.Neon,
			Color = gold,
		}))
	end
end

-- ── Вормир: снег, чёрная гора и две скалы-стражи у жертвенника ────────────
local function buildVormir(biome: Biomes.Biome)
	local terrain = workspace.Terrain
	local c = biome.center
	terrain:SetMaterialColor(Enum.Material.Snow, Color3.fromRGB(215, 220, 235))
	terrain:SetMaterialColor(Enum.Material.Slate, Color3.fromRGB(60, 58, 66))
	groundLayer(biome, Enum.Material.Snow)
	-- Горы-фон за утёсом.
	local outward = (c * Vector3.new(1, 0, 1)).Unit
	for i = -2, 2 do
		local right = Vector3.new(-outward.Z, 0, outward.X)
		local peak = c + outward * (105 + math.abs(i) * 8) + right * i * 36
		local radius = 45 - math.abs(i) * 6
		terrain:FillBall(peak + Vector3.new(0, -radius * 0.2, 0), radius, Enum.Material.Slate)
		terrain:FillBall(peak + Vector3.new(0, radius * 0.55, 0), radius * 0.45, Enum.Material.Snow)
	end
	-- Две каменные скалы-стражи и кольцо камней вокруг башни с Камнем Души.
	for _, side in { -1, 1 } do
		local right = Vector3.new(-outward.Z, 0, outward.X)
		local base = c + right * side * 18
		part({
			Size = Vector3.new(6, 50, 6),
			CFrame = CFrame.new(base + Vector3.new(0, 25, 0)) * CFrame.Angles(0, 0, math.rad(side * 4)),
			Material = Enum.Material.Slate,
			Color = Color3.fromRGB(40, 38, 46),
		})
	end
	for i = 1, 12 do
		local angle = (i / 12) * math.pi * 2
		part({
			Size = Vector3.new(3, rng:NextNumber(3, 6), 3),
			CFrame = CFrame.new(c + Vector3.new(math.cos(angle) * 12, 1.5, math.sin(angle) * 12))
				* CFrame.Angles(0, angle, 0),
			Material = Enum.Material.Slate,
			Color = Color3.fromRGB(55, 52, 60),
		})
	end
	-- Снег идёт всегда (частицы над биомом).
	local sky = ghost(part({
		Size = Vector3.new(biome.radius * 1.6, 1, biome.radius * 1.6),
		Position = c + Vector3.new(0, 70, 0),
		Transparency = 1,
	}))
	local snow = Instance.new("ParticleEmitter")
	snow.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	snow.Color = ColorSequence.new(Color3.new(1, 1, 1))
	snow.Size = NumberSequence.new(0.35)
	snow.Lifetime = NumberRange.new(8, 12)
	snow.Speed = NumberRange.new(6, 9)
	snow.EmissionDirection = Enum.NormalId.Bottom
	snow.SpreadAngle = Vector2.new(15, 15)
	snow.Rate = 60
	snow.Parent = sky
	-- Ледяные глыбы.
	for _ = 1, 18 do
		local spot = spotIn(biome, 35, 95)
		terrain:FillBall(spot, rng:NextNumber(3, 7), Enum.Material.Glacier)
	end
end

-- ── Свартальфхейм: чёрная земля, кристаллы тёмных эльфов и алый Эфир ───────
local function buildSvartalfheim(biome: Biomes.Biome)
	local terrain = workspace.Terrain
	local c = biome.center
	terrain:SetMaterialColor(Enum.Material.Basalt, Color3.fromRGB(38, 34, 40))
	groundLayer(biome, Enum.Material.Basalt)
	for _ = 1, 26 do
		local spot = spotIn(biome, 40, 145)
		local height = rng:NextNumber(12, 40)
		local tilt = CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6), rng:NextNumber(-0.3, 0.3))
		local spire = part({
			Size = Vector3.new(rng:NextNumber(3, 6), height, rng:NextNumber(3, 6)),
			CFrame = CFrame.new(spot + Vector3.new(0, height / 2 - 2, 0)) * tilt,
			Material = Enum.Material.Glass,
			Color = Color3.fromRGB(20, 16, 24),
			Reflectance = 0.15,
		})
		ghost(part({
			Size = Vector3.new(0.3, height * 0.8, spire.Size.Z + 0.1),
			CFrame = spire.CFrame,
			Material = Enum.Material.Neon,
			Color = biome.color,
		}))
	end
	-- Алые трещины Эфира по земле.
	for _ = 1, 30 do
		local spot = spotIn(biome, 30, 140)
		local crack = ghost(part({
			Size = Vector3.new(0.7, 0.2, rng:NextNumber(5, 16)),
			CFrame = CFrame.new(spot + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0),
			Material = Enum.Material.Neon,
			Color = biome.color,
		}))
		if rng:NextNumber() < 0.3 then
			light(crack, biome.color, 12, 1.5)
		end
	end
	-- Разбитый корабль тёмных эльфов (огромный наклонённый клинок).
	local ship = c + (c * Vector3.new(1, 0, 1)).Unit * 100
	part({
		Size = Vector3.new(14, 70, 5),
		CFrame = CFrame.new(ship + Vector3.new(0, 25, 0)) * CFrame.Angles(math.rad(20), 0.6, math.rad(12)),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(30, 28, 34),
	})
end

-- ── Камар-Тадж: двор храма, стены с крышами и зелёные фонари ───────────────
local function buildKamarTaj(biome: Biomes.Biome)
	local terrain = workspace.Terrain
	local c = biome.center
	terrain:SetMaterialColor(Enum.Material.Cobblestone, Color3.fromRGB(140, 130, 120))
	groundLayer(biome, Enum.Material.Cobblestone)
	local wall = Color3.fromRGB(170, 150, 130)
	local roof = Color3.fromRGB(60, 80, 70)
	-- Квадратная стена двора с воротами на все четыре стороны.
	local half = 60
	for side = 0, 3 do
		local angle = math.rad(side * 90)
		local normal = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local along = Vector3.new(-normal.Z, 0, normal.X)
		for piece = -3, 3 do
			local position = c + normal * half + along * piece * 17
			if piece ~= 0 then
				part({
					Size = Vector3.new(17.2, 12, 3),
					CFrame = CFrame.lookAt(position + Vector3.new(0, 6, 0), c + Vector3.new(0, 6, 0)),
					Material = Enum.Material.Brick,
					Color = wall,
				})
				part({
					Size = Vector3.new(18, 1.5, 6),
					CFrame = CFrame.lookAt(position + Vector3.new(0, 12.7, 0), c + Vector3.new(0, 12.7, 0)),
					Material = Enum.Material.Slate,
					Color = roof,
				})
			end
		end
	end
	-- Дома-пагоды по углам двора.
	for corner = 0, 3 do
		local angle = math.rad(45 + corner * 90)
		local base = c + Vector3.new(math.cos(angle), 0, math.sin(angle)) * 64
		for level = 0, 2 do
			local size = 18 - level * 4
			part({
				Size = Vector3.new(size, 7, size),
				CFrame = CFrame.new(base + Vector3.new(0, 3.5 + level * 9, 0)),
				Material = Enum.Material.Brick,
				Color = wall,
			})
			part({
				Size = Vector3.new(size + 5, 1.5, size + 5),
				CFrame = CFrame.new(base + Vector3.new(0, 7.7 + level * 9, 0)),
				Material = Enum.Material.Slate,
				Color = roof,
			})
		end
	end
	-- Зелёные фонари и деревья во дворе.
	for i = 1, 16 do
		local angle = (i / 16) * math.pi * 2
		local base = c + Vector3.new(math.cos(angle), 0, math.sin(angle)) * 40
		part({
			Size = Vector3.new(0.6, 6, 0.6),
			Position = base + Vector3.new(0, 3, 0),
			Material = Enum.Material.Wood,
			Color = Color3.fromRGB(80, 55, 35),
		})
		local lamp = ghost(part({
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 1.4,
			Position = base + Vector3.new(0, 6.5, 0),
			Material = Enum.Material.Neon,
			Color = biome.color,
		}))
		light(lamp, biome.color, 12, 1.5)
	end
	for _ = 1, 16 do
		tree(spotIn(biome, 75, 145), rng:NextNumber(9, 15), Color3.fromRGB(80, 150, 70))
	end
end

local BUILDERS: { [string]: (Biomes.Biome) -> () } = {
	Morag = buildMorag,
	Wakanda = buildWakanda,
	Asgard = buildAsgard,
	Vormir = buildVormir,
	Svartalfheim = buildSvartalfheim,
	KamarTaj = buildKamarTaj,
}

function BiomeBuilder.build(parent: Folder, seed: number)
	folder = Instance.new("Folder")
	folder.Name = "Biomes"
	folder.Parent = parent
	rng = Random.new(seed)
	for _, biome in Biomes.List do
		local builder = BUILDERS[biome.id]
		if builder then
			local ok, err = pcall(function()
				builder(biome)
			end)
			if not ok then
				warn(`[BiomeBuilder] {biome.id}: {err}`)
			end
		end
	end
end

return BiomeBuilder
