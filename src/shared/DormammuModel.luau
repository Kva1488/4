--!strict
-- Внешний вид Дормамму, властелина Тёмного измерения («Доктор Стрэндж», 2016): гигантская голова
-- из тёмной, будто остывшей лавы, с пурпурными трещинами, горящими оранжевыми глазами и пастью,
-- из которой рвётся огонь, в короне из языков пурпурно-оранжевого пламени.
-- Во второй фазе из земли поднимаются огромные огненные руки.
--
-- Координаты — относительно центра головы: +Y вверх, −Z вперёд (лицо), +X вправо.
-- Форма "Ellipsoid" — деталь со SpecialMesh-сферой (эллипсоид любого размера).
-- Используется BossService (сборка) и tools/export_boss (превью без Studio).

export type Role =
	"skin" -- кожа из тёмной лавы
	| "ridge" -- выступы (брови, скулы), чуть светлее
	| "void" -- глазницы, ноздри, глубина пасти
	| "crack" -- светящиеся пурпурные трещины
	| "eye" -- горящие глаза
	| "core" -- раскалённая сердцевина глаз и пасти
	| "flame" -- пурпурное пламя
	| "flameHot" -- оранжевое пламя
	| "aura" -- полупрозрачная аура
	| "rune" -- оранжевые кольца мистических искусств

export type Shape = "Block" | "Ball" | "Cylinder" | "Wedge" | "Ellipsoid"

export type PartSpec = {
	name: string,
	role: Role,
	shape: Shape,
	size: Vector3,
	cframe: CFrame,
	color: Color3?,
	transparency: number?,
}

export type Look = {
	color: Color3,
	material: Enum.Material,
	transparency: number,
}

local DormammuModel = {}

DormammuModel.Roles = {
	skin = { color = Color3.fromRGB(46, 18, 58), material = Enum.Material.Basalt, transparency = 0 },
	ridge = { color = Color3.fromRGB(72, 28, 86), material = Enum.Material.Rock, transparency = 0 },
	void = { color = Color3.fromRGB(8, 2, 14), material = Enum.Material.SmoothPlastic, transparency = 0 },
	crack = { color = Color3.fromRGB(235, 60, 255), material = Enum.Material.Neon, transparency = 0 },
	eye = { color = Color3.fromRGB(255, 150, 30), material = Enum.Material.Neon, transparency = 0 },
	core = { color = Color3.fromRGB(255, 240, 170), material = Enum.Material.Neon, transparency = 0 },
	flame = { color = Color3.fromRGB(190, 50, 255), material = Enum.Material.Neon, transparency = 0.25 },
	flameHot = { color = Color3.fromRGB(255, 120, 40), material = Enum.Material.Neon, transparency = 0.2 },
	aura = { color = Color3.fromRGB(150, 40, 220), material = Enum.Material.Neon, transparency = 0.88 },
	rune = { color = Color3.fromRGB(255, 150, 40), material = Enum.Material.Neon, transparency = 0.1 },
} :: { [Role]: Look }

-- Размер головы: от макушки до подбородка ~26 стадов.
DormammuModel.HeadHeight = 26
-- Радиус, которым голова «ловит» удары (Damage.hitRadius).
DormammuModel.HitRadius = 11

local rad = math.rad

-- Детерминированный «шум» 0..1, чтобы модель была одинаковой всегда.
local function noise(i: number): number
	local x = math.sin(i * 12.9898 + 78.233) * 43758.5453
	return x - math.floor(x)
end

-- CFrame в точке from, смотрящий на to (−Z к цели).
local function look(from: Vector3, to: Vector3): CFrame
	local forward = (to - from).Unit
	local up = if math.abs(forward.Y) > 0.99 then Vector3.new(1, 0, 0) else Vector3.new(0, 1, 0)
	local right = forward:Cross(up).Unit
	return CFrame.fromMatrix(from, right, right:Cross(forward))
end

local function spec(name: string, role: Role, shape: Shape, size: Vector3, cframe: CFrame): PartSpec
	return { name = name, role = role, shape = shape, size = size, cframe = cframe }
end

-- Точка на поверхности эллипсоида и нормаль в ней.
-- phi — угол от макушки (0) до низа (π), theta — вокруг вертикали (−π/2 — лицо, −Z).
local function surface(center: Vector3, radii: Vector3, theta: number, phi: number): (Vector3, Vector3)
	local unit = Vector3.new(math.sin(phi) * math.cos(theta), math.cos(phi), math.sin(phi) * math.sin(theta))
	local point = center + unit * radii
	local normal = (unit / radii).Unit
	return point, normal
end

local CRANIUM_CENTER = Vector3.new(0, 2, 1)
local CRANIUM_RADII = Vector3.new(10, 12.5, 10.5)

local function buildFace(parts: { PartSpec })
	-- Череп и челюсть.
	table.insert(parts, spec("Cranium", "skin", "Ellipsoid", CRANIUM_RADII * 2, CFrame.new(CRANIUM_CENTER)))
	table.insert(parts, spec("Jaw", "skin", "Ellipsoid", Vector3.new(15, 9, 15), CFrame.new(0, -6.5, -2.5)))
	table.insert(
		parts,
		spec(
			"Chin",
			"ridge",
			"Ellipsoid",
			Vector3.new(7, 4.5, 5.5),
			CFrame.new(0, -10, -6.8) * CFrame.Angles(rad(-15), 0, 0)
		)
	)
	-- Надбровная дуга и нахмуренные брови (V-образно к переносице).
	table.insert(
		parts,
		spec("Brow", "ridge", "Ellipsoid", Vector3.new(19, 4.2, 7.5), CFrame.new(0, 5.2, -7.6))
	)
	for _, side in { -1, 1 } do
		table.insert(
			parts,
			spec(
				"BrowFurrow",
				"ridge",
				"Ellipsoid",
				Vector3.new(8.5, 2.2, 3.4),
				CFrame.new(side * 4, 5.4, -10) * CFrame.Angles(0, side * rad(12), side * rad(-16))
			)
		)
		-- Глазница, глаз и раскалённая сердцевина.
		table.insert(
			parts,
			spec(
				"EyeSocket",
				"void",
				"Ellipsoid",
				Vector3.new(5.6, 2.9, 2.2),
				CFrame.new(side * 4.3, 3.3, -9.7) * CFrame.Angles(0, 0, side * rad(-10))
			)
		)
		table.insert(
			parts,
			spec(
				"Eye",
				"eye",
				"Ellipsoid",
				Vector3.new(4.4, 1.7, 1.4),
				CFrame.new(side * 4.3, 3.3, -10.45) * CFrame.Angles(0, 0, side * rad(-10))
			)
		)
		table.insert(
			parts,
			spec(
				"EyeCore",
				"core",
				"Ellipsoid",
				Vector3.new(2.4, 0.7, 0.6),
				CFrame.new(side * 4.3, 3.35, -11) * CFrame.Angles(0, 0, side * rad(-10))
			)
		)
		-- Скулы, щёки и складки у носа.
		table.insert(
			parts,
			spec(
				"Cheekbone",
				"ridge",
				"Ellipsoid",
				Vector3.new(6.5, 4, 6),
				CFrame.new(side * 6.3, -0.2, -6.6)
			)
		)
		table.insert(
			parts,
			spec(
				"Cheek",
				"skin",
				"Ellipsoid",
				Vector3.new(5.5, 6.5, 5),
				CFrame.new(side * 5.2, -3.6, -6.9) * CFrame.Angles(0, 0, side * rad(8))
			)
		)
		table.insert(
			parts,
			spec(
				"SmileLine",
				"ridge",
				"Ellipsoid",
				Vector3.new(1.2, 5.5, 1.6),
				CFrame.new(side * 3.4, -3.2, -9.4) * CFrame.Angles(0, 0, side * rad(-18))
			)
		)
		-- Ноздри и уши-наросты.
		table.insert(
			parts,
			spec(
				"Nostril",
				"void",
				"Ellipsoid",
				Vector3.new(1.1, 0.7, 0.9),
				CFrame.new(side * 0.95, -2.35, -11.5)
			)
		)
		table.insert(
			parts,
			spec(
				"Ear",
				"ridge",
				"Ellipsoid",
				Vector3.new(2, 5.5, 3.5),
				CFrame.new(side * 10, 0.5, 0) * CFrame.Angles(rad(10), 0, side * rad(-8))
			)
		)
	end
	-- Нос: переносица (клин) и кончик.
	table.insert(
		parts,
		spec("NoseBridge", "ridge", "Wedge", Vector3.new(2.8, 5.4, 2.6), CFrame.new(0, 0.9, -10.6))
	)
	table.insert(
		parts,
		spec("NoseTip", "ridge", "Ellipsoid", Vector3.new(3.4, 2, 2.4), CFrame.new(0, -1.9, -11))
	)
	-- Пасть: провал, огонь внутри, губы.
	table.insert(
		parts,
		spec("Mouth", "void", "Ellipsoid", Vector3.new(8.6, 3.4, 3), CFrame.new(0, -5.7, -9.1))
	)
	table.insert(
		parts,
		spec("MouthFire", "flameHot", "Ellipsoid", Vector3.new(7, 2, 2.2), CFrame.new(0, -5.7, -9.7))
	)
	table.insert(
		parts,
		spec("MouthCore", "core", "Ellipsoid", Vector3.new(4.6, 0.9, 1.6), CFrame.new(0, -5.7, -10.1))
	)
	table.insert(
		parts,
		spec("UpperLip", "ridge", "Ellipsoid", Vector3.new(9.4, 1.3, 2.6), CFrame.new(0, -3.9, -9.8))
	)
	table.insert(
		parts,
		spec("LowerLip", "ridge", "Ellipsoid", Vector3.new(8, 1.6, 2.6), CFrame.new(0, -7.5, -9.4))
	)
end

-- Светящиеся пурпурные трещины по черепу — прожилки, ползущие снизу вверх.
local function buildCracks(parts: { PartSpec })
	local veins = 26
	for v = 1, veins do
		local theta = (v / veins) * math.pi * 2 + noise(v) * 0.4
		local phi = rad(95 + noise(v + 40) * 35)
		local steps = 3 + math.floor(noise(v + 80) * 3)
		local point, normal = surface(CRANIUM_CENTER, CRANIUM_RADII * 1.01, theta, phi)
		for s = 1, steps do
			theta += (noise(v * 7 + s) - 0.5) * 0.45
			phi -= rad(9 + noise(v * 3 + s) * 8)
			local nextPoint, nextNormal = surface(CRANIUM_CENTER, CRANIUM_RADII * 1.01, theta, phi)
			local a = point + normal * 0.12
			local b = nextPoint + nextNormal * 0.12
			local length = (b - a).Magnitude
			local width = 0.5 - s * 0.07
			table.insert(
				parts,
				spec("Crack", "crack", "Block", Vector3.new(width, width, length + 0.3), look((a + b) / 2, b))
			)
			point, normal = nextPoint, nextNormal
		end
	end
end

-- Корона пламени: большие пурпурные языки на макушке и затылке, внутри — оранжевые.
local function buildFlames(parts: { PartSpec })
	local up = Vector3.new(0, 1, 0)
	local back = Vector3.new(0, 0, 1)
	local count = 30
	for i = 1, count do
		local theta = (i / count) * math.pi * 2 + noise(i + 200) * 0.3
		local phi = rad(8 + noise(i + 300) * 62)
		local base, normal = surface(CRANIUM_CENTER, CRANIUM_RADII, theta, phi)
		local faceSide = normal.Z < -0.55 and phi > rad(45)
		if not faceSide then
			local direction = (normal * 0.6 + up * 1.1 + back * 0.55).Unit
			local height = 9 + noise(i + 400) * 11
			local width = 2.6 + noise(i + 500) * 2.4
			local center = base + direction * (height * 0.38)
			table.insert(
				parts,
				spec(
					"Flame",
					"flame",
					"Ellipsoid",
					Vector3.new(width, width * 0.7, height),
					look(center, center + direction)
				)
			)
			if i % 2 == 0 then
				local inner = base + direction * (height * 0.25)
				table.insert(
					parts,
					spec(
						"FlameHot",
						"flameHot",
						"Ellipsoid",
						Vector3.new(width * 0.55, width * 0.4, height * 0.55),
						look(inner, inner + direction)
					)
				)
			end
		end
	end
	-- Языки пламени по краю лица и под челюстью.
	for i = 1, 18 do
		local theta = rad(-20 + (i - 1) * (220 / 17)) -- от правой щеки через затылок к левой
		local phi = rad(100 + noise(i + 600) * 30)
		local base, normal = surface(CRANIUM_CENTER, CRANIUM_RADII, theta, phi)
		local direction = (normal + up * 0.8 + back * 0.4).Unit
		local height = 6 + noise(i + 700) * 6
		local width = 1.8 + noise(i + 800) * 1.6
		local center = base + direction * (height * 0.35)
		table.insert(
			parts,
			spec(
				if i % 3 == 0 then "FlameHot" else "Flame",
				if i % 3 == 0 then "flameHot" else "flame",
				"Ellipsoid",
				Vector3.new(width, width * 0.7, height),
				look(center, center + direction)
			)
		)
	end
end

-- Аура и два кольца мистических искусств за головой (из сегментов, с засечками-рунами).
local function buildAura(parts: { PartSpec })
	table.insert(parts, spec("Aura", "aura", "Ellipsoid", Vector3.new(30, 38, 30), CFrame.new(0, 4, 1)))
	for ring, radius in { 20, 24.5 } do
		local segments = if ring == 1 then 36 else 44
		local z = 4 + ring * 1.5
		local chord = 2 * math.pi * radius / segments
		for s = 1, segments do
			local angle = (s / segments) * math.pi * 2
			local position = Vector3.new(math.cos(angle) * radius, 3 + math.sin(angle) * radius, z)
			local tangent = Vector3.new(-math.sin(angle), math.cos(angle), 0)
			table.insert(
				parts,
				spec(
					"Halo",
					"rune",
					"Block",
					Vector3.new(0.45, 0.45, chord + 0.1),
					look(position, position + tangent)
				)
			)
			if s % 4 == 0 then
				local outward = Vector3.new(math.cos(angle), math.sin(angle), 0)
				local tick = position + outward * 0.9
				table.insert(
					parts,
					spec("Rune", "rune", "Block", Vector3.new(0.35, 0.35, 1.6), look(tick, tick + outward))
				)
			end
		end
	end
end

-- Голова Дормамму целиком.
function DormammuModel.head(): { PartSpec }
	local parts: { PartSpec } = {}
	buildFace(parts)
	buildCracks(parts)
	buildFlames(parts)
	buildAura(parts)
	return parts
end

-- Огненная рука, поднимающаяся из земли. Начало координат — запястье, пальцы вверх (+Y),
-- ладонь смотрит вперёд (−Z).
function DormammuModel.hand(): { PartSpec }
	local parts: { PartSpec } = {}
	table.insert(parts, spec("Forearm", "skin", "Ellipsoid", Vector3.new(6, 12, 6), CFrame.new(0, -5, 0.4)))
	table.insert(parts, spec("Palm", "skin", "Ellipsoid", Vector3.new(8.5, 8, 4), CFrame.new(0, 3.5, 0)))
	table.insert(
		parts,
		spec("PalmFire", "flameHot", "Ellipsoid", Vector3.new(5, 5, 0.8), CFrame.new(0, 3.5, -1.8))
	)
	-- Четыре пальца из трёх фаланг и большой палец; фаланги загибаются вперёд, как когти.
	for f = 1, 4 do
		local x = -3.3 + (f - 1) * 2.2
		local length = ({ 3.4, 3.9, 3.7, 3 })[f]
		local joint = CFrame.new(x, 7.2, 0) * CFrame.Angles(0, 0, rad((f - 2.5) * -5))
		for segment = 1, 3 do
			local size = length * (1.05 - segment * 0.15)
			local bone = joint * CFrame.new(0, size / 2, 0)
			table.insert(parts, spec("Finger", "skin", "Ellipsoid", Vector3.new(1.7, size + 0.6, 1.8), bone))
			table.insert(
				parts,
				spec(
					"Knuckle",
					"crack",
					"Ellipsoid",
					Vector3.new(0.9, 0.5, 0.4),
					joint * CFrame.new(0, 0, -0.85)
				)
			)
			joint = joint * CFrame.new(0, size, 0) * CFrame.Angles(rad(-14), 0, 0)
		end
		table.insert(
			parts,
			spec("Claw", "flameHot", "Wedge", Vector3.new(1, 1.6, 1.2), joint * CFrame.new(0, 0.6, 0))
		)
	end
	local thumb = CFrame.new(-4.2, 2.2, -0.6) * CFrame.Angles(0, 0, rad(40))
	for segment = 1, 2 do
		table.insert(
			parts,
			spec("Thumb", "skin", "Ellipsoid", Vector3.new(2, 3.6, 2), thumb * CFrame.new(0, 1.6, 0))
		)
		thumb = thumb * CFrame.new(0, 3.2, 0) * CFrame.Angles(rad(-12), 0, rad(-10 * segment))
	end
	-- Трещины и пламя по руке.
	for i = 1, 10 do
		local y = -9 + i * 1.6
		local angle = noise(i + 900) * math.pi * 2
		local radius = if y < 0 then 3 else 4.1
		table.insert(
			parts,
			spec(
				"Crack",
				"crack",
				"Block",
				Vector3.new(0.35, 2.4, 0.35),
				CFrame.new(math.cos(angle) * radius, y, math.sin(angle) * radius * 0.6)
					* CFrame.Angles(0, 0, rad((noise(i) - 0.5) * 60))
			)
		)
	end
	for i = 1, 8 do
		local angle = (i / 8) * math.pi * 2
		local base = Vector3.new(math.cos(angle) * 3.5, -8 + noise(i + 950) * 6, math.sin(angle) * 3.5)
		local direction = (Vector3.new(math.cos(angle), 2.5, math.sin(angle))).Unit
		table.insert(
			parts,
			spec(
				"Flame",
				if i % 2 == 0 then "flameHot" else "flame",
				"Ellipsoid",
				Vector3.new(2.2, 1.6, 7),
				look(base + direction * 2.5, base + direction * 3.5)
			)
		)
	end
	return parts
end

return DormammuModel
