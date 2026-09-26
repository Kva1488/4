--!strict
-- Геометрия Перчатки Бесконечности: список деталей в системе координат кисти.
-- Используется GauntletService (сборка на персонаже) и tools/render_gauntlet (превью).
--
-- Система координат (как у RightHand в R15 и низа Right Arm в R6, рука опущена вниз):
--   +Y — к запястью и предплечью, −Y — к кончикам пальцев;
--   +X — тыльная сторона ладони (наружу от тела), −X — ладонь;
--   −Z — сторона большого пальца (вперёд), +Z — мизинец (назад).
--
-- Камни расположены как в фильме: Разум — в центре тыльной стороны,
-- Душа — на большом пальце, Реальность — указательный, Пространство — средний,
-- Сила — безымянный, Время — мизинец.

export type Role = "plate" | "trim" | "dark" | "socket" | "gem"

export type PartSpec = {
	name: string,
	role: Role,
	shape: "Block" | "Ball" | "Cylinder",
	size: Vector3,
	cframe: CFrame, -- относительно центра кисти
	stone: string?, -- для role = "gem" / "socket"
}

local GauntletModel = {}

local rad = math.rad

-- Пальцы от указательного к мизинцу: z-позиция, длины фаланг и камень.
local FINGERS = {
	{ name = "Index", z = -0.36, l1 = 0.42, l2 = 0.34, stone = "Reality" },
	{ name = "Middle", z = -0.12, l1 = 0.46, l2 = 0.38, stone = "Space" },
	{ name = "Ring", z = 0.12, l1 = 0.44, l2 = 0.36, stone = "Power" },
	{ name = "Pinky", z = 0.36, l1 = 0.34, l2 = 0.28, stone = "Time" },
}

-- Сгиб к ладони (−X) — это вращение вокруг Z с отрицательным углом.
local function curl(angle: number): CFrame
	return CFrame.Angles(0, 0, rad(-angle))
end

-- Цилиндр в Roblox вытянут по оси X детали; этот поворот направляет его ось по Z.
local ALONG_Z = CFrame.Angles(0, rad(90), 0)

function GauntletModel.build(scale: number): { PartSpec }
	local parts: { PartSpec } = {}

	local function add(
		name: string,
		role: Role,
		shape: "Block" | "Ball" | "Cylinder",
		size: Vector3,
		cframe: CFrame,
		stone: string?
	)
		table.insert(parts, {
			name = name,
			role = role,
			shape = shape,
			size = size * scale,
			cframe = CFrame.new(cframe.Position * scale) * cframe.Rotation,
			stone = stone,
		})
	end

	-- Гнездо с камнем на поверхности детали: основа (кольцо) + сам камень.
	-- surface — CFrame точки на поверхности, ось +X смотрит наружу.
	local function stoneSocket(stone: string, surface: CFrame, gemSize: number)
		add(
			stone .. "Socket",
			"socket",
			"Cylinder",
			Vector3.new(0.06, gemSize * 1.45, gemSize * 1.45),
			surface,
			stone
		)
		add(stone, "gem", "Ball", Vector3.one * gemSize, surface * CFrame.new(gemSize * 0.22, 0, 0), stone)
	end

	-- Ладонь и тыльная броня.
	add("Glove", "plate", "Block", Vector3.new(0.55, 0.9, 1.0), CFrame.new(0, -0.35, 0))
	add("BackPlate", "plate", "Block", Vector3.new(0.12, 0.8, 0.9), CFrame.new(0.32, -0.33, 0))
	add("PalmPlate", "dark", "Block", Vector3.new(0.08, 0.78, 0.86), CFrame.new(-0.3, -0.35, 0))
	-- Рёбра-гравировка на тыльной стороне, расходятся от камня Разума к пальцам.
	for i, z in { -0.3, 0.3 } do
		local tilt = if i == 1 then 8 else -8
		add(
			"BackRidge" .. i,
			"trim",
			"Block",
			Vector3.new(0.05, 0.78, 0.06),
			CFrame.new(0.39, -0.36, z) * CFrame.Angles(rad(tilt), 0, 0)
		)
	end
	-- Камень Разума в центре тыльной стороны.
	stoneSocket("Mind", CFrame.new(0.38, -0.3, 0), 0.3)

	-- Костяшки: поперечный валик у основания пальцев.
	add("Knuckles", "trim", "Cylinder", Vector3.new(1.02, 0.3, 0.3), CFrame.new(0.1, -0.8, 0) * ALONG_Z)

	-- Пластины над костяшками каждого пальца.
	for _, finger in FINGERS do
		add(
			finger.name .. "Plate",
			"plate",
			"Block",
			Vector3.new(0.1, 0.22, 0.2),
			CFrame.new(0.3, -0.76, finger.z)
		)
	end

	-- Четыре пальца по две фаланги, слегка согнуты к ладони.
	for _, finger in FINGERS do
		local joint1 = CFrame.new(0.08, -0.86, finger.z) * curl(12)
		local proximal = joint1 * CFrame.new(0, -finger.l1 / 2, 0)
		local joint2 = joint1 * CFrame.new(0, -finger.l1, 0) * curl(28)
		local distal = joint2 * CFrame.new(0, -finger.l2 / 2, 0)

		add(finger.name .. "1", "plate", "Block", Vector3.new(0.25, finger.l1, 0.2), proximal)
		add(finger.name .. "Joint", "trim", "Ball", Vector3.one * 0.23, joint2)
		add(finger.name .. "2", "plate", "Block", Vector3.new(0.22, finger.l2, 0.18), distal)
		add(finger.name .. "Tip", "dark", "Ball", Vector3.one * 0.19, joint2 * CFrame.new(0, -finger.l2, 0))
		-- Камень на тыльной стороне первой фаланги.
		stoneSocket(finger.stone, proximal * CFrame.new(0.13, 0.02, 0), 0.15)
	end

	-- Большой палец: выходит вперёд (−Z) и вниз, согнут к ладони.
	local thumbBase = CFrame.new(-0.06, -0.4, -0.5) * CFrame.Angles(rad(34), 0, 0) * curl(22)
	local thumbProximal = thumbBase * CFrame.new(0, -0.2, 0)
	local thumbJoint = thumbBase * CFrame.new(0, -0.4, 0) * curl(30)
	add("ThumbBase", "trim", "Ball", Vector3.one * 0.32, thumbBase)
	add("Thumb1", "plate", "Block", Vector3.new(0.26, 0.4, 0.24), thumbProximal)
	add("ThumbJoint", "trim", "Ball", Vector3.one * 0.24, thumbJoint)
	add("Thumb2", "plate", "Block", Vector3.new(0.23, 0.32, 0.22), thumbJoint * CFrame.new(0, -0.16, 0))
	add("ThumbTip", "dark", "Ball", Vector3.one * 0.2, thumbJoint * CFrame.new(0, -0.32, 0))
	stoneSocket("Soul", thumbProximal * CFrame.new(0.14, 0, 0), 0.16)

	-- Запястье и манжета на предплечье. Квадратные, как рука R15 (1×1),
	-- чтобы углы предплечья не торчали сквозь броню.
	add("WristRing", "trim", "Block", Vector3.new(1.12, 0.22, 1.12), CFrame.new(0, 0.1, 0))
	add("Cuff", "plate", "Block", Vector3.new(1.12, 0.52, 1.12), CFrame.new(0, 0.46, 0))
	add("CuffBand", "dark", "Block", Vector3.new(1.15, 0.06, 1.15), CFrame.new(0, 0.46, 0))
	add("CuffFlare", "plate", "Block", Vector3.new(1.24, 0.14, 1.24), CFrame.new(0, 0.78, 0))
	add("CuffRim", "trim", "Block", Vector3.new(1.3, 0.06, 1.3), CFrame.new(0, 0.87, 0))
	-- Накладка-"щиток" на внешней стороне манжеты с ромбом по центру.
	add("CuffGuard", "trim", "Block", Vector3.new(0.08, 0.5, 0.4), CFrame.new(0.6, 0.46, 0))
	add(
		"CuffGem",
		"trim",
		"Block",
		Vector3.new(0.1, 0.16, 0.16),
		CFrame.new(0.64, 0.46, 0) * CFrame.Angles(rad(45), 0, 0)
	)

	return parts
end

return GauntletModel
