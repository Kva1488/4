--!strict
-- Герои: у каждого свой набор способностей (Shared/Abilities, поле hero) и свой внешний вид.
-- Усиленные версии открываются прогрессом за базового героя:
-- • Локи → Локи, бог времени (финал 2 сезона сериала «Локи»);
-- • Альтрон → Альтрон бесконечности («Что, если…?», эпизоды 8–9);
-- • Тор с Мьёльниром → с Громсекирой («Война бесконечности») → с обоими («Финал»).

export type HeroId =
	"Thanos"
	| "Loki"
	| "GodLoki"
	| "Ultron"
	| "InfinityUltron"
	| "Thor"
	| "ThorStormbreaker"
	| "ThorBoth"

export type Hero = {
	id: HeroId,
	name: string,
	title: string,
	icon: string,
	color: Color3,
	description: string,
	unlock: { stat: string, count: number, label: string }?, -- условие открытия по статистике игрока
	bodyColor: Color3?, -- цвет кожи/корпуса
	robot: boolean?, -- робот: красится всё тело, одежда снимается
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
		bodyColor = Color3.fromRGB(135, 95, 165),
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
		unlock = { stat = "LokiKills", count = 25, label = "убийств за Локи" },
	},
	{
		id = "Ultron",
		name = "Альтрон",
		title = "Нет на мне нитей",
		icon = "🤖",
		color = Color3.fromRGB(230, 50, 50),
		description = "ИИ в вибраниевом теле («Эра Альтрона»). Репульсоры, армия дронов-часовых, "
			.. "антигравитация и перенос сознания. Ульта поднимает кусок земли, как Соковию.",
		bodyColor = Color3.fromRGB(165, 170, 182),
		robot = true,
	},
	{
		id = "InfinityUltron",
		name = "Альтрон бесконечности",
		title = "Разрушитель мультивселенной",
		icon = "♾️",
		color = Color3.fromRGB(255, 200, 60),
		description = "«Что, если…?»: Альтрон захватил тело Вижна, разрубил Таноса и забрал все шесть камней. "
			.. "Титановая броня с золотом, камни в нагруднике, красный плащ и двуглавое копьё. "
			.. "Ульта «Конец мультивселенной» бьёт силой всех шести камней.",
		unlock = {
			stat = "UltronKills",
			count = 25,
			label = "убийств за Альтрона (или убей Таноса)",
		},
		bodyColor = Color3.fromRGB(120, 125, 140),
		robot = true,
	},
}

table.insert(List, {
	id = "Thor",
	name = "Тор",
	title = "Бог грома",
	icon = "🔨",
	color = Color3.fromRGB(120, 190, 255),
	description = "Мьёльнир: бросок с возвратом, удар молнии, полёт на молоте, громовой удар о землю. "
		.. "«Пробуждение» из «Рагнарёка» и ульта «Бог грома».",
})
table.insert(List, {
	id = "ThorStormbreaker",
	name = "Тор с Громсекирой",
	title = "Король Асгарда",
	icon = "🪓",
	color = Color3.fromRGB(150, 210, 255),
	description = "«Война бесконечности»: топор, выкованный на Нидавеллире из сердца звезды. "
		.. "Биврёст, конус молний, прыжок грома и ульта «Дайте мне Таноса!».",
	unlock = { stat = "ThorKills", count = 15, label = "убийств за Тора" },
})
table.insert(List, {
	id = "ThorBoth",
	name = "Тор: молот и топор",
	title = "Достойнейший",
	icon = "⚡",
	color = Color3.fromRGB(200, 235, 255),
	description = "Финальная битва «Финала»: Мьёльнир в одной руке, Громсекира в другой. "
		.. "Двойные удары и броски, гроза, возвращение молота и ульта «Гнев Асгарда».",
	unlock = { stat = "ThorKills", count = 40, label = "убийств за Тора (любого)" },
})

local ById: { [string]: Hero } = {}
for _, hero in List do
	ById[hero.id] = hero
end

local Heroes = {
	List = List,
	ById = ById,
	Default = "Thanos" :: HeroId,
}

-- stats — данные игрока (или любая таблица со счётчиками вроде LokiKills).
function Heroes.isUnlocked(hero: Hero, stats: { [string]: any }?): boolean
	local unlock = hero.unlock
	if not unlock then
		return true
	end
	-- Герой куплен за робуксы (геймпасс).
	local owned = stats and stats.OwnedHeroes
	if type(owned) == "table" and owned[hero.id] == true then
		return true
	end
	local value = stats and stats[unlock.stat]
	return type(value) == "number" and value >= unlock.count
end

-- Сколько уже набрано к открытию (для полоски прогресса).
function Heroes.progress(hero: Hero, stats: { [string]: any }?): (number, number)
	local unlock = hero.unlock
	if not unlock then
		return 1, 1
	end
	local value = stats and stats[unlock.stat]
	return if type(value) == "number" then value else 0, unlock.count
end

return Heroes
