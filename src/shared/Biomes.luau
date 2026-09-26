--!strict
-- Биомы большой карты: по одному на каждый Камень Бесконечности, как в фильмах.
-- Общие для сервера (строит MapService/BiomeBuilder, камни ставит StoneService, порталы — TravelService)
-- и клиента (мини-карта, большая карта, баннер «📍 Вормир» при входе в зону).

export type Biome = {
	id: string,
	name: string,
	stoneId: string,
	center: Vector3,
	radius: number,
	color: Color3,
	description: string,
}

local Biomes = {}

Biomes.WorldHalf = 900 -- карта 1800×1800 стадов
Biomes.Distance = 560 -- от центра карты до центра биома
Biomes.Radius = 150

local function at(angleDegrees: number): Vector3
	local angle = math.rad(angleDegrees)
	return Vector3.new(math.cos(angle) * Biomes.Distance, 0, math.sin(angle) * Biomes.Distance)
end

Biomes.List = {
	{
		id = "Morag",
		name = "Мораг",
		stoneId = "Power",
		center = at(30),
		radius = Biomes.Radius,
		color = Color3.fromRGB(170, 60, 255),
		description = "Затопленный храм. Камень Силы — на вершине башни посреди озера.",
	},
	{
		id = "Wakanda",
		name = "Ваканда",
		stoneId = "Mind",
		center = at(90),
		radius = Biomes.Radius,
		color = Color3.fromRGB(255, 215, 40),
		description = "Джунгли и Водопад Воинов. Камень Разума — на вершине холма у водопада.",
	},
	{
		id = "Asgard",
		name = "Асгард",
		stoneId = "Space",
		center = at(150),
		radius = Biomes.Radius,
		color = Color3.fromRGB(40, 130, 255),
		description = "Золотой город и Радужный мост. Камень Пространства — над обсерваторией Хеймдалля.",
	},
	{
		id = "Vormir",
		name = "Вормир",
		stoneId = "Soul",
		center = at(210),
		radius = Biomes.Radius,
		color = Color3.fromRGB(255, 140, 20),
		description = "Снежная гора и скала жертвы. Камень Души — на вершине утёса.",
	},
	{
		id = "Svartalfheim",
		name = "Свартальфхейм",
		stoneId = "Reality",
		center = at(270),
		radius = Biomes.Radius,
		color = Color3.fromRGB(235, 35, 45),
		description = "Мир тёмных эльфов: чёрные кристаллы и Эфир. Камень Реальности — в сердце лабиринта.",
	},
	{
		id = "KamarTaj",
		name = "Камар-Тадж",
		stoneId = "Time",
		center = at(330),
		radius = Biomes.Radius,
		color = Color3.fromRGB(40, 220, 90),
		description = "Храм мастеров мистических искусств. Камень Времени — над парящими ступенями.",
	},
} :: { Biome }

Biomes.ById = {} :: { [string]: Biome }
Biomes.ByStone = {} :: { [string]: Biome }
for _, biome in Biomes.List do
	Biomes.ById[biome.id] = biome
	Biomes.ByStone[biome.stoneId] = biome
end

-- В каком биоме точка (по горизонтали), или nil — в диких землях.
function Biomes.at(position: Vector3): Biome?
	for _, biome in Biomes.List do
		if ((position - biome.center) * Vector3.new(1, 0, 1)).Magnitude <= biome.radius then
			return biome
		end
	end
	return nil
end

-- Порталы между зонами: хаб у спавна, вход в каждый биом (со стороны центра) и разлом Дормамму.
export type Waystone = { id: string, name: string, position: Vector3, color: Color3 }

Biomes.Waystones = {
	{
		id = "Hub",
		name = "Спавн",
		position = Vector3.new(-40, 0, 0),
		color = Color3.fromRGB(230, 175, 50),
	},
} :: { Waystone }
for _, biome in Biomes.List do
	local inward = -(biome.center * Vector3.new(1, 0, 1)).Unit
	table.insert(Biomes.Waystones, {
		id = biome.id,
		name = biome.name,
		position = biome.center + inward * (biome.radius - 25),
		color = biome.color,
	})
end
table.insert(Biomes.Waystones, {
	id = "Rift",
	name = "Разлом Дормамму",
	position = Vector3.new(-130, 0, 100),
	color = Color3.fromRGB(190, 60, 255),
})

Biomes.WaystoneById = {} :: { [string]: Waystone }
for _, waystone in Biomes.Waystones do
	Biomes.WaystoneById[waystone.id] = waystone
end

return table.freeze(Biomes)
