--!strict
-- Внешний вид героев Локи: шлем с рогами, плащ с наплечниками, кинжалы.
-- Детали описаны относительно частей тела (голова, верх торса, кисти) в их системе координат:
-- +Y вверх, −Z вперёд (лицо), +X вправо.
-- Используется HeroService (сборка на персонаже) и tools/export_hero (превью).

export type Role = "plate" | "trim" | "cape" | "lining" | "steel" | "dark" | "glow"

export type PartSpec = {
	name: string,
	role: Role,
	shape: "Block" | "Ball" | "Cylinder",
	size: Vector3,
	cframe: CFrame,
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

local function spec(
	name: string,
	role: Role,
	shape: "Block" | "Ball" | "Cylinder",
	size: Vector3,
	cframe: CFrame
): PartSpec
	return { name = name, role = role, shape = shape, size = size, cframe = cframe }
end

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

local function helmet(god: boolean): { PartSpec }
	local parts: { PartSpec } = {
		spec("Band", "plate", "Block", Vector3.new(1.34, 0.3, 1.34), CFrame.new(0, 0.22, 0)),
		spec("Cap", "plate", "Block", Vector3.new(1.3, 0.16, 1.3), CFrame.new(0, 0.62, 0)),
		spec("Crest", "trim", "Block", Vector3.new(0.18, 0.16, 1.38), CFrame.new(0, 0.74, 0)),
		spec("Brow", "plate", "Block", Vector3.new(0.28, 0.56, 0.12), CFrame.new(0, 0.2, -0.69)),
		spec("Nose", "trim", "Block", Vector3.new(0.14, 0.34, 0.1), CFrame.new(0, -0.12, -0.7)),
		spec("CheekL", "plate", "Block", Vector3.new(0.12, 0.62, 0.52), CFrame.new(-0.69, -0.08, -0.18)),
		spec("CheekR", "plate", "Block", Vector3.new(0.12, 0.62, 0.52), CFrame.new(0.69, -0.08, -0.18)),
		spec("Back", "trim", "Block", Vector3.new(1.3, 0.6, 0.1), CFrame.new(0, 0.24, 0.69)),
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
		local haloSegments = 20
		for i = 1, haloSegments do
			local angle = (i / haloSegments) * math.pi * 2
			table.insert(
				parts,
				spec(
					`Halo{i}`,
					"glow",
					"Block",
					Vector3.new(0.34, 0.07, 0.07),
					CFrame.new(0, 0.35, 0.95) * CFrame.Angles(0, 0, angle) * CFrame.new(0, 1.25, 0)
				)
			)
		end
	else
		horn(parts, -1, 6, 0.38, 0.28, 20)
		horn(parts, 1, 6, 0.38, 0.28, 20)
	end
	return parts
end

local function cape(god: boolean): { PartSpec }
	local parts: { PartSpec } = {
		spec("Collar", "trim", "Block", Vector3.new(2.1, 0.32, 0.3), CFrame.new(0, 0.74, 0.42)),
		spec(
			"CapeTop",
			"cape",
			"Block",
			Vector3.new(2.0, 1.7, 0.08),
			CFrame.new(0, -0.05, 0.6) * CFrame.Angles(rad(6), 0, 0)
		),
		spec(
			"CapeBottom",
			"cape",
			"Block",
			Vector3.new(2.15, 2.4, 0.08),
			CFrame.new(0, -2.1, 0.8) * CFrame.Angles(rad(10), 0, 0)
		),
		spec("PauldronL", "plate", "Ball", Vector3.new(0.95, 0.5, 0.95), CFrame.new(-1.02, 0.72, 0)),
		spec("PauldronR", "plate", "Ball", Vector3.new(0.95, 0.5, 0.95), CFrame.new(1.02, 0.72, 0)),
		spec("ChestV", "trim", "Block", Vector3.new(0.9, 0.12, 0.08), CFrame.new(0, 0.5, -0.52)),
	}
	if god then
		table.insert(
			parts,
			spec(
				"CapeEdge",
				"lining",
				"Block",
				Vector3.new(2.16, 0.12, 0.1),
				CFrame.new(0, -3.28, 1.0) * CFrame.Angles(rad(10), 0, 0)
			)
		)
		table.insert(parts, spec("ChestGem", "glow", "Ball", Vector3.one * 0.3, CFrame.new(0, 0.5, -0.58)))
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
	}
end

function HeroModel.outfit(heroId: string): Outfit?
	if heroId == "Loki" then
		return { head = helmet(false), torso = cape(false), rightHand = dagger(), leftHand = dagger() }
	elseif heroId == "GodLoki" then
		return { head = helmet(true), torso = cape(true), rightHand = {}, leftHand = {} }
	end
	return nil
end

return HeroModel
