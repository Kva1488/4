--!strict
-- Герои: у каждого свой набор способностей (Shared/Abilities, поле hero) и свой внешний вид.
-- Локи, бог времени открывается, когда игрок "дорастает" до него за Локи — как в финале 2 сезона сериала.

export type HeroId = "Thanos" | "Loki" | "GodLoki"

export type Hero = {
	id: HeroId,
	name: string,
	title: string,
	icon: string,
	color: Color3,
	description: string,
	unlockLokiKills: number?, -- сколько убийств за Локи нужно для открытия
}

local List: { Hero } = {
	{
		id = "Thanos",
		name = "Танос",
		title = "Безумный титан",
		icon = "🧤",
		color = Color3.fromRGB(150, 90, 200),
		description = "Собирает Камни Бесконечности по карте. Каждый камень открывает силу, "
			.. "пары камней дают комбо, а все шесть — Щелчок.",
	},
	{
		id = "Loki",
		name = "Локи",
		title = "Бог обмана",
		icon = "🐍",
		color = Color3.fromRGB(60, 170, 80),
		description = "Кинжалы, иллюзии и двойники. Удар в спину наносит двойной урон. "
			.. "Скипетр с Камнем Разума подчиняет волю, а Ларец Древних Зим замораживает всё вокруг.",
	},
	{
		id = "GodLoki",
		name = "Локи, бог времени",
		title = "Хранитель Иггдрасиля",
		icon = "🌳",
		color = Color3.fromRGB(90, 255, 150),
		description = "Локи управляет сдвигами во времени, останавливает время и держит ветви мультивселенной. "
			.. "Ульта «Славная цель» выращивает Иггдрасиль, и его ветви хватают всех врагов вокруг.",
		unlockLokiKills = 25,
	},
}

local ById: { [string]: Hero } = {}
for _, hero in List do
	ById[hero.id] = hero
end

local Heroes = {
	List = List,
	ById = ById,
	Default = "Thanos" :: HeroId,
}

function Heroes.isUnlocked(hero: Hero, lokiKills: number?): boolean
	return hero.unlockLokiKills == nil or (lokiKills or 0) >= hero.unlockLokiKills
end

return Heroes
