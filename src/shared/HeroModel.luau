--!strict
-- Внешний вид героев из деталей: Танос (броня «Войны бесконечности»), Локи (шлем с рогами, туника,
-- плащ, кинжалы), Локи — бог времени, Альтрон и Альтрон бесконечности (шлем с маской,
-- пять камней в нагруднике, красный плащ, двуглавое копьё — как в «Что, если…?»).
--
-- Детали описаны относительно частей тела (голова, верх торса, кисти) в их системе координат:
-- +Y вверх, −Z вперёд (лицо), +X вправо.
-- Используется HeroService (сборка на персонаже) и tools/export_hero (превью).

export type Role = "plate" | "trim" | "cape" | "lining" | "steel" | "dark" | "glow" | "eye" | "gem" | "gold"

export type PartSpec = {
	name: string,
	role: Role,
	shape: "Block" | "Ball" | "Cylinder",
	size: Vector3,
	cframe: CFrame,
	color: Color3?, -- свой цвет вместо цвета роли (например, камни)
	sway: boolean?, -- плащ: развевается при движении (анимирует клиент)
}

export type Outfit = {
	head: { PartSpec },
	torso: { PartSpec },
	rightHand: { PartSpec },
	leftHand: { PartSpec },
}

local HeroModel = {}

local rad = math.rad
local ALONG_Y = CFrame.Angles(0, 0, rad(90)) -- ось цилиндра (X детали) направляем по Y
local ALONG_Z = CFrame.Angles(0, rad(90), 0)

-- Точка крепления плаща (у основания шеи сзади) — вокруг неё плащ качается.
HeroModel.CapePivot = CFrame.new(0, 0.8, 0.5)

local STONE_COLORS = {
	Power = Color3.fromRGB(170, 60, 255),
	Space = Color3.fromRGB(40, 130, 255),
	Reality = Color3.fromRGB(235, 35, 45),
	Soul = Color3.fromRGB(255, 140, 20),
	Time = Color3.fromRGB(40, 220, 90),
	Mind = Color3.fromRGB(255, 215, 40),
}

local function spec(
	name: string,
	role: Role,
	shape: "Block" | "Ball" | "Cylinder",
	size: Vector3,
	cframe: CFrame
): PartSpec
	return { name = name, role = role, shape = shape, size = size, cframe = cframe }
end

local function add(parts: { PartSpec }, item: PartSpec, extra: { color: Color3?, sway: boolean? }?): PartSpec
	if extra then
		item.color = extra.color
		item.sway = extra.sway
	end
	table.insert(parts, item)
	return item
end

-- Плащ из двух полотнищ и (по желанию) каймы. Все части качаются вокруг CapePivot.
local function capeParts(parts: { PartSpec }, trimRole: Role?)
	add(
		parts,
		spec(
			"CapeTop",
			"cape",
			"Block",
			Vector3.new(2.05, 1.75, 0.08),
			CFrame.new(0, -0.05, 0.62) * CFrame.Angles(rad(6), 0, 0)
		),
		{ sway = true }
	)
	add(
		parts,
		spec(
			"CapeBottom",
			"cape",
			"Block",
			Vector3.new(2.2, 2.45, 0.08),
			CFrame.new(0, -2.12, 0.82) * CFrame.Angles(rad(10), 0, 0)
		),
		{ sway = true }
	)
	if trimRole then
		add(
			parts,
			spec(
				"CapeHem",
				trimRole,
				"Block",
				Vector3.new(2.22, 0.14, 0.1),
				CFrame.new(0, -3.33, 1.03) * CFrame.Angles(rad(10), 0, 0)
			),
			{ sway = true }
		)
		for i, x in { -1.1, 1.1 } do
			add(
				parts,
				spec(
					`CapeSide{i}`,
					trimRole,
					"Block",
					Vector3.new(0.1, 4.1, 0.1),
					CFrame.new(x, -1.25, 0.73) * CFrame.Angles(rad(8), 0, 0)
				),
				{ sway = true }
			)
		end
	end
end

-------------------------------------------------------------------------------- ТАНОС

local function thanosHead(): { PartSpec }
	local ridge = Color3.fromRGB(95, 60, 120)
	local parts: { PartSpec } = {}
	-- Знаменитые складки на подбородке и тяжёлые надбровные дуги.
	for i, x in { -0.24, -0.08, 0.08, 0.24 } do
		add(
			parts,
			spec(`Chin{i}`, "dark", "Block", Vector3.new(0.05, 0.34, 0.05), CFrame.new(x, -0.38, -0.62)),
			{ color = ridge }
		)
	end
	add(
		parts,
		spec("Brow", "dark", "Block", Vector3.new(1.08, 0.1, 0.1), CFrame.new(0, 0.2, -0.62)),
		{ color = ridge }
	)
	return parts
end

local function thanosTorso(): { PartSpec }
	local parts: { PartSpec } = {
		spec("Armor", "plate", "Block", Vector3.new(2.06, 1.3, 1.06), CFrame.new(0, 0.12, 0)),
		spec("ChestStrip", "gold", "Block", Vector3.new(0.3, 1.25, 0.06), CFrame.new(0, 0.1, -0.55)),
		spec("Belt", "gold", "Block", Vector3.new(2.08, 0.22, 1.08), CFrame.new(0, -0.8, 0)),
		spec("Buckle", "trim", "Block", Vector3.new(0.4, 0.3, 0.08), CFrame.new(0, -0.8, -0.57)),
	}
	for i, side in { -1, 1 } do
		table.insert(
			parts,
			spec(
				`Pad{i}`,
				"plate",
				"Block",
				Vector3.new(1.18, 0.45, 1.18),
				CFrame.new(1.04 * side, 0.78, 0) * CFrame.Angles(0, 0, rad(-16 * side))
			)
		)
		table.insert(
			parts,
			spec(
				`PadRim{i}`,
				"gold",
				"Block",
				Vector3.new(1.2, 0.1, 1.2),
				CFrame.new(1.1 * side, 0.6, 0) * CFrame.Angles(0, 0, rad(-16 * side))
			)
		)
		table.insert(
			parts,
			spec(
				`Strap{i}`,
				"trim",
				"Block",
				Vector3.new(0.14, 1.1, 0.06),
				CFrame.new(0.55 * side, 0.2, -0.55) * CFrame.Angles(0, 0, rad(18 * side))
			)
		)
	end
	return parts
end

local function bracer(): { PartSpec }
	return {
		spec("Bracer", "plate", "Block", Vector3.new(1.08, 0.55, 1.08), CFrame.new(0, 0.35, 0)),
		spec("BracerRim", "gold", "Block", Vector3.new(1.1, 0.1, 1.1), CFrame.new(0, 0.1, 0)),
	}
end

-------------------------------------------------------------------------------- ЛОКИ

-- Рог из цилиндров-сегментов: растёт вверх, начиная чуть вперёд, и загибается назад.
local function horn(
	parts: { PartSpec },
	side: number,
	segments: number,
	length: number,
	radius: number,
	bend: number
)
	local joint = CFrame.new(0.42 * side, 0.6, -0.48)
		* CFrame.Angles(0, 0, rad(-20 * side))
		* CFrame.Angles(rad(-28), 0, 0)
	for i = 1, segments do
		local t = (i - 1) / math.max(segments - 1, 1)
		local r = radius * (1 - t * 0.72)
		table.insert(
			parts,
			spec(
				`Horn{side > 0 and "R" or "L"}{i}`,
				"plate",
				"Cylinder",
				Vector3.new(length * 1.08, r, r),
				joint * CFrame.new(0, length / 2, 0) * ALONG_Y
			)
		)
		joint = joint * CFrame.new(0, length, 0) * CFrame.Angles(rad(bend), 0, 0)
	end
end

local function lokiHelmet(god: boolean): { PartSpec }
	local parts: { PartSpec } = {
		spec("Band", "plate", "Block", Vector3.new(1.34, 0.3, 1.34), CFrame.new(0, 0.22, 0)),
		spec("Cap", "plate", "Block", Vector3.new(1.3, 0.16, 1.3), CFrame.new(0, 0.62, 0)),
		spec("Crest", "trim", "Block", Vector3.new(0.18, 0.16, 1.38), CFrame.new(0, 0.74, 0)),
		spec("Brow", "plate", "Block", Vector3.new(0.28, 0.56, 0.12), CFrame.new(0, 0.2, -0.69)),
		spec("Nose", "trim", "Block", Vector3.new(0.14, 0.34, 0.1), CFrame.new(0, -0.12, -0.7)),
		spec("CheekL", "plate", "Block", Vector3.new(0.12, 0.62, 0.52), CFrame.new(-0.69, -0.08, -0.18)),
		spec("CheekR", "plate", "Block", Vector3.new(0.12, 0.62, 0.52), CFrame.new(0.69, -0.08, -0.18)),
		spec("Back", "trim", "Block", Vector3.new(1.3, 0.6, 0.1), CFrame.new(0, 0.24, 0.69)),
		-- Гравировка на налобнике.
		spec(
			"EngraveL",
			"trim",
			"Block",
			Vector3.new(0.4, 0.05, 0.05),
			CFrame.new(-0.36, 0.3, -0.69) * CFrame.Angles(0, 0, rad(-20))
		),
		spec(
			"EngraveR",
			"trim",
			"Block",
			Vector3.new(0.4, 0.05, 0.05),
			CFrame.new(0.36, 0.3, -0.69) * CFrame.Angles(0, 0, rad(20))
		),
	}
	if god then
		-- Бог времени: рога длиннее и круче, зелёные вставки и "часовой" нимб за головой.
		horn(parts, -1, 7, 0.44, 0.3, 17)
		horn(parts, 1, 7, 0.44, 0.3, 17)
		table.insert(parts, spec("GemBrow", "glow", "Ball", Vector3.one * 0.2, CFrame.new(0, 0.36, -0.76)))
		table.insert(
			parts,
			spec("LineL", "lining", "Block", Vector3.new(0.04, 0.5, 0.4), CFrame.new(-0.76, -0.08, -0.18))
		)
		table.insert(
			parts,
			spec("LineR", "lining", "Block", Vector3.new(0.04, 0.5, 0.4), CFrame.new(0.76, -0.08, -0.18))
		)
		local haloSegments = 24
		for i = 1, haloSegments do
			local angle = (i / haloSegments) * math.pi * 2
			-- Каждое 6-е деление длиннее: как отметки на циферблате.
			local long = i % 6 == 0
			table.insert(
				parts,
				spec(
					`Halo{i}`,
					"glow",
					"Block",
					Vector3.new(0.3, if long then 0.18 else 0.07, 0.07),
					CFrame.new(0, 0.35, 0.95)
						* CFrame.Angles(0, 0, angle)
						* CFrame.new(0, if long then 1.18 else 1.25, 0)
				)
			)
		end
	else
		horn(parts, -1, 6, 0.38, 0.28, 20)
		horn(parts, 1, 6, 0.38, 0.28, 20)
	end
	return parts
end

local function lokiTorso(god: boolean): { PartSpec }
	local parts: { PartSpec } = {
		spec("Collar", "trim", "Block", Vector3.new(2.1, 0.32, 0.3), CFrame.new(0, 0.74, 0.42)),
		spec("PauldronL", "plate", "Ball", Vector3.new(0.95, 0.5, 0.95), CFrame.new(-1.02, 0.72, 0)),
		spec("PauldronR", "plate", "Ball", Vector3.new(0.95, 0.5, 0.95), CFrame.new(1.02, 0.72, 0)),
		-- Туника, кожаные ремни, пояс.
		spec("Tunic", "cape", "Block", Vector3.new(2.04, 1.32, 0.06), CFrame.new(0, 0.02, -0.52)),
		spec("ChestV", "trim", "Block", Vector3.new(0.9, 0.12, 0.08), CFrame.new(0, 0.5, -0.56)),
		spec(
			"StrapL",
			"dark",
			"Block",
			Vector3.new(0.14, 1.35, 0.05),
			CFrame.new(-0.5, 0.05, -0.56) * CFrame.Angles(0, 0, rad(-10))
		),
		spec(
			"StrapR",
			"dark",
			"Block",
			Vector3.new(0.14, 1.35, 0.05),
			CFrame.new(0.5, 0.05, -0.56) * CFrame.Angles(0, 0, rad(10))
		),
		spec("Belt", "trim", "Block", Vector3.new(2.08, 0.18, 1.08), CFrame.new(0, -0.8, 0)),
	}
	capeParts(parts, if god then "lining" else nil)
	if god then
		table.insert(parts, spec("ChestGem", "glow", "Ball", Vector3.one * 0.3, CFrame.new(0, 0.5, -0.6)))
	end
	return parts
end

-- Кинжал в кисти: клинок смотрит вперёд (−Z).
local function dagger(): { PartSpec }
	return {
		spec("Hilt", "dark", "Block", Vector3.new(0.14, 0.14, 0.42), CFrame.new(0, -0.15, -0.12)),
		spec("Guard", "plate", "Block", Vector3.new(0.5, 0.08, 0.1), CFrame.new(0, -0.15, -0.36)),
		spec("Blade", "steel", "Block", Vector3.new(0.06, 0.16, 1.0), CFrame.new(0, -0.15, -0.88)),
		spec("Tip", "steel", "Block", Vector3.new(0.05, 0.1, 0.12), CFrame.new(0, -0.15, -1.42) * ALONG_Z),
		spec("Fuller", "glow", "Block", Vector3.new(0.07, 0.03, 0.8), CFrame.new(0, -0.15, -0.88)),
	}
end

-------------------------------------------------------------------------------- АЛЬТРОН

-- Голова Альтрона из «Эры Альтрона»: угловатый череп, глаза, рот-щель, гребни и "плавники" назад.
local function ultronHead(): { PartSpec }
	local parts: { PartSpec } = {
		spec("Skull", "plate", "Block", Vector3.new(1.3, 1.26, 1.3), CFrame.new(0, 0.02, 0)),
		spec("Brow", "trim", "Block", Vector3.new(1.36, 0.16, 0.22), CFrame.new(0, 0.22, -0.62)),
		spec(
			"EyeL",
			"eye",
			"Block",
			Vector3.new(0.34, 0.1, 0.06),
			CFrame.new(-0.27, 0.07, -0.67) * CFrame.Angles(0, 0, rad(-12))
		),
		spec(
			"EyeR",
			"eye",
			"Block",
			Vector3.new(0.34, 0.1, 0.06),
			CFrame.new(0.27, 0.07, -0.67) * CFrame.Angles(0, 0, rad(12))
		),
		spec("Mouth", "eye", "Block", Vector3.new(0.62, 0.07, 0.06), CFrame.new(0, -0.3, -0.67)),
		spec("Jaw", "trim", "Block", Vector3.new(1.0, 0.3, 0.34), CFrame.new(0, -0.5, -0.5)),
		spec(
			"FinL",
			"trim",
			"Block",
			Vector3.new(0.1, 0.55, 0.45),
			CFrame.new(-0.7, 0.12, 0.12) * CFrame.Angles(rad(-15), 0, 0)
		),
		spec(
			"FinR",
			"trim",
			"Block",
			Vector3.new(0.1, 0.55, 0.45),
			CFrame.new(0.7, 0.12, 0.12) * CFrame.Angles(rad(-15), 0, 0)
		),
		spec(
			"SweepL",
			"plate",
			"Block",
			Vector3.new(0.1, 0.4, 0.95),
			CFrame.new(-0.45, 0.58, 0.38) * CFrame.Angles(rad(25), 0, 0)
		),
		spec(
			"SweepR",
			"plate",
			"Block",
			Vector3.new(0.1, 0.4, 0.95),
			CFrame.new(0.45, 0.58, 0.38) * CFrame.Angles(rad(25), 0, 0)
		),
		spec("Neck", "eye", "Cylinder", Vector3.new(0.12, 0.7, 0.7), CFrame.new(0, -0.66, 0) * ALONG_Y),
	}
	for i, x in { -0.36, 0, 0.36 } do
		table.insert(
			parts,
			spec(
				`Crest{i}`,
				"trim",
				"Block",
				Vector3.new(0.12, 0.3, 1.0),
				CFrame.new(x, 0.72, 0.12) * CFrame.Angles(rad(12), 0, 0)
			)
		)
	end
	return parts
end

local function ultronTorso(): { PartSpec }
	local parts: { PartSpec } = {
		spec("Chest", "plate", "Block", Vector3.new(2.08, 1.5, 1.08), CFrame.new(0, 0.05, 0)),
		spec("Core", "eye", "Ball", Vector3.one * 0.46, CFrame.new(0, 0.3, -0.56)),
		spec(
			"CoreRing",
			"trim",
			"Cylinder",
			Vector3.new(0.08, 0.7, 0.7),
			CFrame.new(0, 0.3, -0.55) * ALONG_Z
		),
		spec(
			"ShoulderL",
			"trim",
			"Block",
			Vector3.new(1.1, 0.35, 1.12),
			CFrame.new(-1.05, 0.74, 0) * CFrame.Angles(0, 0, rad(15))
		),
		spec(
			"ShoulderR",
			"trim",
			"Block",
			Vector3.new(1.1, 0.35, 1.12),
			CFrame.new(1.05, 0.74, 0) * CFrame.Angles(0, 0, rad(-15))
		),
	}
	for i = 1, 3 do
		table.insert(
			parts,
			spec(
				`Ab{i}`,
				"trim",
				"Block",
				Vector3.new(0.9, 0.06, 0.06),
				CFrame.new(0, -0.2 - i * 0.18, -0.55)
			)
		)
	end
	-- Светящиеся "вены" энергии от ядра.
	for i, side in { -1, 1 } do
		table.insert(
			parts,
			spec(
				`Vein{i}`,
				"eye",
				"Block",
				Vector3.new(0.05, 0.9, 0.04),
				CFrame.new(0.42 * side, 0.2, -0.56) * CFrame.Angles(0, 0, rad(35 * side))
			)
		)
	end
	return parts
end

-- Когти на кисти: три лезвия, смотрящие вниз, и накладка на костяшки.
local function claws(): { PartSpec }
	local parts: { PartSpec } = {
		spec("Knuckles", "trim", "Block", Vector3.new(1.04, 0.34, 1.04), CFrame.new(0, 0, 0)),
	}
	for i, z in { -0.3, 0, 0.3 } do
		table.insert(
			parts,
			spec(
				`Claw{i}`,
				"steel",
				"Block",
				Vector3.new(0.1, 0.55, 0.1),
				CFrame.new(0, -0.4, z) * CFrame.Angles(0, 0, rad(-10))
			)
		)
	end
	return parts
end

-------------------------------------------------------------------------------- АЛЬТРОН БЕСКОНЕЧНОСТИ

-- Шлем с маской в духе комиксного Альтрона: округлый купол, золотые гребень и "уши",
-- красные глаза и рот, Камень Разума во лбу.
local function infinityHelmet(): { PartSpec }
	local parts: { PartSpec } = {
		spec("Shell", "plate", "Block", Vector3.new(1.36, 1.2, 1.36), CFrame.new(0, -0.02, 0)),
		spec("Dome", "plate", "Ball", Vector3.new(1.42, 0.72, 1.42), CFrame.new(0, 0.55, 0.02)),
		spec("Mask", "trim", "Block", Vector3.new(1.12, 0.95, 0.1), CFrame.new(0, -0.06, -0.68)),
		spec(
			"EyeL",
			"eye",
			"Block",
			Vector3.new(0.36, 0.12, 0.05),
			CFrame.new(-0.26, 0.12, -0.735) * CFrame.Angles(0, 0, rad(-14))
		),
		spec(
			"EyeR",
			"eye",
			"Block",
			Vector3.new(0.36, 0.12, 0.05),
			CFrame.new(0.26, 0.12, -0.735) * CFrame.Angles(0, 0, rad(14))
		),
		spec("Mouth", "eye", "Block", Vector3.new(0.7, 0.1, 0.05), CFrame.new(0, -0.32, -0.735)),
		spec("MouthFrame", "dark", "Block", Vector3.new(0.82, 0.22, 0.04), CFrame.new(0, -0.32, -0.725)),
		spec("Crest", "gold", "Block", Vector3.new(0.18, 0.16, 1.46), CFrame.new(0, 0.87, 0.02)),
		spec(
			"EarL",
			"gold",
			"Block",
			Vector3.new(0.12, 0.72, 0.55),
			CFrame.new(-0.72, 0.08, 0.05) * CFrame.Angles(rad(-12), 0, 0)
		),
		spec(
			"EarR",
			"gold",
			"Block",
			Vector3.new(0.12, 0.72, 0.55),
			CFrame.new(0.72, 0.08, 0.05) * CFrame.Angles(rad(-12), 0, 0)
		),
		spec("BrowBand", "gold", "Block", Vector3.new(1.4, 0.12, 0.14), CFrame.new(0, 0.34, -0.66)),
		spec("Chin", "gold", "Block", Vector3.new(0.5, 0.16, 0.12), CFrame.new(0, -0.52, -0.67)),
		spec("MindSocket", "gold", "Block", Vector3.new(0.44, 0.36, 0.06), CFrame.new(0, 0.52, -0.71)),
	}
	add(
		parts,
		spec("MindStone", "gem", "Ball", Vector3.new(0.3, 0.24, 0.14), CFrame.new(0, 0.52, -0.75)),
		{ color = STONE_COLORS.Mind }
	)
	return parts
end

-- Броня: титан с золотом, пять камней по кругу в нагруднике (Реальность — сверху), красный плащ.
local function infinityTorso(): { PartSpec }
	local parts: { PartSpec } = {
		spec("Chest", "plate", "Block", Vector3.new(2.12, 1.56, 1.12), CFrame.new(0, 0.04, 0)),
		spec("CollarGold", "gold", "Block", Vector3.new(1.3, 0.28, 1.16), CFrame.new(0, 0.82, 0)),
		spec(
			"StoneFrame",
			"gold",
			"Cylinder",
			Vector3.new(0.07, 1.16, 1.16),
			CFrame.new(0, 0.22, -0.57) * ALONG_Z
		),
		spec(
			"StoneBed",
			"dark",
			"Cylinder",
			Vector3.new(0.05, 1.0, 1.0),
			CFrame.new(0, 0.22, -0.585) * ALONG_Z
		),
		spec("Belt", "gold", "Block", Vector3.new(2.14, 0.22, 1.14), CFrame.new(0, -0.85, 0)),
		spec("CapeCollar", "gold", "Block", Vector3.new(2.0, 0.4, 0.25), CFrame.new(0, 0.8, 0.5)),
	}
	local center = Vector3.new(0, 0.22, -0.6)
	for _, stone in
		{
			{ id = "Reality", angle = 90 },
			{ id = "Power", angle = 162 },
			{ id = "Space", angle = 234 },
			{ id = "Soul", angle = 306 },
			{ id = "Time", angle = 18 },
		}
	do
		local a = rad(stone.angle)
		local position = center + Vector3.new(math.cos(a) * 0.34, math.sin(a) * 0.34, 0)
		table.insert(
			parts,
			spec(
				`{stone.id}Socket`,
				"gold",
				"Cylinder",
				Vector3.new(0.05, 0.3, 0.3),
				CFrame.new(position) * ALONG_Z
			)
		)
		add(
			parts,
			spec(
				`{stone.id}Stone`,
				"gem",
				"Ball",
				Vector3.one * 0.22,
				CFrame.new(position + Vector3.new(0, 0, -0.04))
			),
			{ color = STONE_COLORS[stone.id] }
		)
	end
	for i = 1, 3 do
		table.insert(
			parts,
			spec(
				`Ab{i}`,
				"gold",
				"Block",
				Vector3.new(0.9 - i * 0.12, 0.1, 0.06),
				CFrame.new(0, -0.3 - i * 0.14, -0.57)
			)
		)
	end
	for i, side in { -1, 1 } do
		table.insert(
			parts,
			spec(
				`Pauldron{i}`,
				"plate",
				"Block",
				Vector3.new(1.2, 0.42, 1.2),
				CFrame.new(1.05 * side, 0.78, 0) * CFrame.Angles(0, 0, rad(-18 * side))
			)
		)
		table.insert(
			parts,
			spec(
				`PauldronRim{i}`,
				"gold",
				"Block",
				Vector3.new(1.22, 0.1, 1.22),
				CFrame.new(1.12 * side, 0.6, 0) * CFrame.Angles(0, 0, rad(-18 * side))
			)
		)
	end
	capeParts(parts, "gold")
	return parts
end

local function infinityGauntlet(): { PartSpec }
	return {
		spec("Glove", "plate", "Block", Vector3.new(1.06, 0.4, 1.06), CFrame.new(0, 0, 0)),
		spec("KnuckleBar", "gold", "Block", Vector3.new(1.08, 0.12, 0.3), CFrame.new(0, -0.1, -0.4)),
		spec("Cuff", "gold", "Block", Vector3.new(1.1, 0.12, 1.1), CFrame.new(0, 0.26, 0)),
	}
end

-- Двуглавое копьё: золотое древко и два стальных клинка с красной светящейся кромкой.
local function doubleSpear(): { PartSpec }
	local parts = infinityGauntlet()
	local c = CFrame.new(0, 1.8, -0.62) -- центр древка; рука держит его чуть ниже середины
	table.insert(parts, spec("Shaft", "gold", "Cylinder", Vector3.new(4.2, 0.16, 0.16), c * ALONG_Y))
	table.insert(
		parts,
		spec("Grip", "dark", "Cylinder", Vector3.new(0.8, 0.21, 0.21), CFrame.new(0, 0, -0.62) * ALONG_Y)
	)
	for i, dir in { 1, -1 } do
		local base = c * CFrame.new(0, 2.1 * dir, 0)
		table.insert(
			parts,
			spec(`Collar{i}`, "gold", "Cylinder", Vector3.new(0.18, 0.3, 0.3), base * ALONG_Y)
		)
		table.insert(
			parts,
			spec(
				`Blade{i}`,
				"steel",
				"Block",
				Vector3.new(0.08, 1.0, 0.42),
				base * CFrame.new(0, 0.55 * dir, 0)
			)
		)
		table.insert(
			parts,
			spec(
				`Point{i}`,
				"steel",
				"Block",
				Vector3.new(0.07, 0.3, 0.3),
				base * CFrame.new(0, 1.12 * dir, 0) * CFrame.Angles(rad(45), 0, 0)
			)
		)
		table.insert(
			parts,
			spec(
				`Edge{i}`,
				"eye",
				"Block",
				Vector3.new(0.1, 0.85, 0.05),
				base * CFrame.new(0, 0.55 * dir, -0.2)
			)
		)
		table.insert(
			parts,
			spec(
				`Wing{i}`,
				"gold",
				"Block",
				Vector3.new(0.1, 0.22, 0.85),
				base * CFrame.new(0, 0.1 * dir, 0) * CFrame.Angles(rad(15 * dir), 0, 0)
			)
		)
	end
	return parts
end

function HeroModel.outfit(heroId: string): Outfit?
	if heroId == "Thanos" then
		-- Правую руку занимает Перчатка Бесконечности (GauntletService).
		return { head = thanosHead(), torso = thanosTorso(), rightHand = {}, leftHand = bracer() }
	elseif heroId == "Loki" then
		return {
			head = lokiHelmet(false),
			torso = lokiTorso(false),
			rightHand = dagger(),
			leftHand = dagger(),
		}
	elseif heroId == "GodLoki" then
		return { head = lokiHelmet(true), torso = lokiTorso(true), rightHand = {}, leftHand = {} }
	elseif heroId == "Ultron" then
		return { head = ultronHead(), torso = ultronTorso(), rightHand = claws(), leftHand = claws() }
	elseif heroId == "InfinityUltron" then
		return {
			head = infinityHelmet(),
			torso = infinityTorso(),
			rightHand = doubleSpear(),
			leftHand = infinityGauntlet(),
		}
	end
	return nil
end

return HeroModel
