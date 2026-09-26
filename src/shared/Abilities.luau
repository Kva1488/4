--!strict
-- Описание всех способностей всех героев: клавиши, перезарядки, требования.
-- Логика — на сервере: src/server/Combat/Heroes/<Герой>.luau.
-- У разных героев клавиши могут совпадать: панель показывает только способности текущего героя.

export type Ability = {
	id: string,
	hero: "Thanos" | "Loki" | "GodLoki",
	name: string,
	description: string,
	input: Enum.KeyCode | Enum.UserInputType,
	keyLabel: string,
	cooldown: number,
	requires: { string }, -- id Камней Бесконечности (только у Таноса)
	color: Color3,
	range: number, -- дальность прицела (для способностей без прицела — радиус)
	kind: "basic" | "stone" | "combo" | "ultimate",
}

local GOLD = Color3.fromRGB(230, 175, 50)
local LOKI_GREEN = Color3.fromRGB(60, 200, 90)
local TIME_GREEN = Color3.fromRGB(110, 255, 150)
local ALL_STONES = { "Power", "Space", "Reality", "Soul", "Time", "Mind" }

local LMB = Enum.UserInputType.MouseButton1
local K = Enum.KeyCode

local List: { Ability } = {
	-- ТАНОС: способности по сценам "Войны бесконечности" и "Финала".
	{
		id = "Punch",
		hero = "Thanos",
		name = "Удар",
		description = "Серия из 3 ударов Перчаткой, третий сильнее и отбрасывает.",
		input = LMB,
		keyLabel = "ЛКМ",
		cooldown = 0.35,
		requires = {},
		color = GOLD,
		range = 6,
		kind = "basic",
	},
	{
		id = "Beam",
		hero = "Thanos",
		name = "Залп Перчатки",
		description = "Энергетический луч из Перчатки. С Камнем Силы становится фиолетовым и сильнее.",
		input = K.F,
		keyLabel = "F",
		cooldown = 2,
		requires = {},
		color = Color3.fromRGB(255, 235, 150),
		range = 120,
		kind = "basic",
	},
	{
		id = "PowerWave",
		hero = "Thanos",
		name = "Удар Силы",
		description = "Удар Камнем Силы о землю: волна на 35 урона с мощным отбрасыванием.",
		input = K.One,
		keyLabel = "1",
		cooldown = 8,
		requires = { "Power" },
		color = Color3.fromRGB(170, 60, 255),
		range = 18,
		kind = "stone",
	},
	{
		id = "SpaceWarp",
		hero = "Thanos",
		name = "Портал",
		description = "Камень Пространства открывает портал: мгновенное перемещение в точку прицела.",
		input = K.Two,
		keyLabel = "2",
		cooldown = 6,
		requires = { "Space" },
		color = Color3.fromRGB(40, 130, 255),
		range = 80,
		kind = "stone",
	},
	{
		id = "RealityWarp",
		hero = "Thanos",
		name = "Распад реальности",
		description = "Как Дракс на Забвении: враги в зоне рассыпаются на кубы, "
			.. "получают 25 урона и не могут двигаться 2.5 секунды.",
		input = K.Three,
		keyLabel = "3",
		cooldown = 12,
		requires = { "Reality" },
		color = Color3.fromRGB(235, 35, 45),
		range = 80,
		kind = "stone",
	},
	{
		id = "SoulDrain",
		hero = "Thanos",
		name = "Похищение души",
		description = "Высасывает по 20 здоровья из каждого врага рядом и лечит тебя.",
		input = K.Four,
		keyLabel = "4",
		cooldown = 10,
		requires = { "Soul" },
		color = Color3.fromRGB(255, 140, 20),
		range = 22,
		kind = "stone",
	},
	{
		id = "TimeRewind",
		hero = "Thanos",
		name = "Перемотка времени",
		description = "Как с Вижном в Ваканде: Камень Времени отматывает тебя на 4 секунды назад, "
			.. "вместе с позицией и здоровьем.",
		input = K.Five,
		keyLabel = "5",
		cooldown = 14,
		requires = { "Time" },
		color = Color3.fromRGB(40, 220, 90),
		range = 0,
		kind = "stone",
	},
	{
		id = "MindBeam",
		hero = "Thanos",
		name = "Луч Разума",
		description = "Жёлтый луч Камня Разума, как у Вижна: пробивает всех на линии, "
			.. "22 урона и оглушение на 1.5 секунды.",
		input = K.Six,
		keyLabel = "6",
		cooldown = 10,
		requires = { "Mind" },
		color = Color3.fromRGB(255, 215, 40),
		range = 110,
		kind = "stone",
	},
	{
		id = "MoonRain",
		hero = "Thanos",
		name = "Луна Титана",
		description = "Сила + Пространство, как на Титане: на зону прицела обрушиваются "
			.. "осколки луны, до 12 урона каждый.",
		input = K.Z,
		keyLabel = "Z",
		cooldown = 16,
		requires = { "Power", "Space" },
		color = Color3.fromRGB(110, 90, 255),
		range = 90,
		kind = "combo",
	},
	{
		id = "RockPrison",
		hero = "Thanos",
		name = "Каменная тюрьма",
		description = "Пространство + Реальность, как с Халкбастером в Ваканде: "
			.. "враги замурованы в скалу на 3.5 секунды.",
		input = K.X,
		keyLabel = "X",
		cooldown = 16,
		requires = { "Space", "Reality" },
		color = Color3.fromRGB(160, 110, 80),
		range = 80,
		kind = "combo",
	},
	{
		id = "SoulHarvest",
		hero = "Thanos",
		name = "Жатва душ",
		description = "Душа + Разум: оглушает всех врагов рядом и забирает у каждого по 25 здоровья.",
		input = K.C,
		keyLabel = "C",
		cooldown = 18,
		requires = { "Soul", "Mind" },
		color = Color3.fromRGB(255, 120, 90),
		range = 32,
		kind = "combo",
	},
	{
		id = "Snap",
		hero = "Thanos",
		name = "ЩЕЛЧОК",
		description = "Все 6 камней: половина врагов в радиусе 100 обращается в пыль.",
		input = K.G,
		keyLabel = "G",
		cooldown = 90,
		requires = ALL_STONES,
		color = Color3.fromRGB(255, 255, 255),
		range = 100,
		kind = "ultimate",
	},

	-- ЛОКИ, бог обмана: фильмы "Тор", "Мстители", "Рагнарёк" и 1 сезон сериала.
	{
		id = "DaggerSlash",
		hero = "Loki",
		name = "Кинжалы",
		description = "Быстрые удары двумя кинжалами. Удар в спину наносит двойной урон.",
		input = LMB,
		keyLabel = "ЛКМ",
		cooldown = 0.28,
		requires = {},
		color = Color3.fromRGB(200, 230, 210),
		range = 6,
		kind = "basic",
	},
	{
		id = "DaggerThrow",
		hero = "Loki",
		name = "Метательный кинжал",
		description = "Бросок кинжала по прицелу, 18 урона.",
		input = K.F,
		keyLabel = "F",
		cooldown = 1.2,
		requires = {},
		color = LOKI_GREEN,
		range = 110,
		kind = "basic",
	},
	{
		id = "Illusion",
		hero = "Loki",
		name = "Иллюзия",
		description = "Ты становишься невидимым на 4 секунды, а на месте остаётся иллюзия. "
			.. "Следующий удар из невидимости: «Сюрприз!» — тройной урон.",
		input = K.One,
		keyLabel = "1",
		cooldown = 12,
		requires = {},
		color = LOKI_GREEN,
		range = 0,
		kind = "stone",
	},
	{
		id = "Duplicates",
		hero = "Loki",
		name = "Двойники",
		description = "Три двойника Локи бросаются на ближайших врагов и взрываются зелёной магией.",
		input = K.Two,
		keyLabel = "2",
		cooldown = 14,
		requires = {},
		color = LOKI_GREEN,
		range = 40,
		kind = "stone",
	},
	{
		id = "Scepter",
		hero = "Loki",
		name = "Скипетр",
		description = "Синий луч скипетра с Камнем Разума, как в «Мстителях»: 25 урона, "
			.. "враг под контролем разума 2 секунды.",
		input = K.Three,
		keyLabel = "3",
		cooldown = 9,
		requires = {},
		color = Color3.fromRGB(70, 170, 255),
		range = 100,
		kind = "stone",
	},
	{
		id = "LokiTeleport",
		hero = "Loki",
		name = "Телепорт",
		description = "Зелёная вспышка — и ты уже в точке прицела.",
		input = K.Four,
		keyLabel = "4",
		cooldown = 5,
		requires = {},
		color = LOKI_GREEN,
		range = 60,
		kind = "stone",
	},
	{
		id = "Casket",
		hero = "Loki",
		name = "Ларец Древних Зим",
		description = "Реликвия ётунов из «Тора»: ледяной конус замораживает врагов перед тобой "
			.. "на 3 секунды и наносит 30 урона.",
		input = K.G,
		keyLabel = "G",
		cooldown = 40,
		requires = {},
		color = Color3.fromRGB(140, 220, 255),
		range = 45,
		kind = "ultimate",
	},

	-- ЛОКИ, БОГ ВРЕМЕНИ: финал 2 сезона сериала "Локи" ("Славная цель").
	{
		id = "TimeThread",
		hero = "GodLoki",
		name = "Нить времени",
		description = "Хлёсткий удар зелёной нитью времени на 12 метров. Цель подтягивает к тебе.",
		input = LMB,
		keyLabel = "ЛКМ",
		cooldown = 0.45,
		requires = {},
		color = TIME_GREEN,
		range = 12,
		kind = "basic",
	},
	{
		id = "BranchBolt",
		hero = "GodLoki",
		name = "Ветвь",
		description = "Сгусток энергии ветви времени пробивает всех на пути, 22 урона.",
		input = K.F,
		keyLabel = "F",
		cooldown = 1.5,
		requires = {},
		color = TIME_GREEN,
		range = 110,
		kind = "basic",
	},
	{
		id = "Timeslip",
		hero = "GodLoki",
		name = "Сдвиг во времени",
		description = "Как в сериале, Локи соскальзывает во времени: "
			.. "ты возвращаешься туда, где был 3 секунды назад, с тем же здоровьем.",
		input = K.One,
		keyLabel = "1",
		cooldown = 8,
		requires = {},
		color = TIME_GREEN,
		range = 0,
		kind = "stone",
	},
	{
		id = "TimePause",
		hero = "GodLoki",
		name = "Остановка времени",
		description = "Локи научился ставить время на паузу: все враги в радиусе 35 застывают на 3.5 секунды.",
		input = K.Two,
		keyLabel = "2",
		cooldown = 18,
		requires = {},
		color = TIME_GREEN,
		range = 35,
		kind = "stone",
	},
	{
		id = "YggdrasilBranches",
		hero = "GodLoki",
		name = "Ветви Иггдрасиля",
		description = "Из земли вырастают ветви времени, оплетают врагов и поднимают их в воздух: "
			.. "25 урона и 2.5 секунды оглушения.",
		input = K.Three,
		keyLabel = "3",
		cooldown = 12,
		requires = {},
		color = TIME_GREEN,
		range = 80,
		kind = "stone",
	},
	{
		id = "TemPadDoor",
		hero = "GodLoki",
		name = "Дверь TVA",
		description = "Оранжевая временная дверь TemPad: мгновенный проход в точку прицела.",
		input = K.Four,
		keyLabel = "4",
		cooldown = 6,
		requires = {},
		color = Color3.fromRGB(255, 150, 50),
		range = 100,
		kind = "stone",
	},
	{
		id = "GloriousPurpose",
		hero = "GodLoki",
		name = "Славная цель",
		description = "Локи поднимается над землёй, и вокруг него вырастает Иггдрасиль. "
			.. "Ветви хватают всех врагов в радиусе 70: 60 урона и 4 секунды оглушения.",
		input = K.G,
		keyLabel = "G",
		cooldown = 75,
		requires = {},
		color = TIME_GREEN,
		range = 70,
		kind = "ultimate",
	},
}

local ById: { [string]: Ability } = {}
for _, ability in List do
	ById[ability.id] = ability
end

local Abilities = {
	List = List,
	ById = ById,
}

-- Способности героя в порядке показа на панели.
function Abilities.forHero(heroId: string): { Ability }
	local result = {}
	for _, ability in List do
		if ability.hero == heroId then
			table.insert(result, ability)
		end
	end
	return result
end

function Abilities.isUnlocked(ability: Ability, stones: { [string]: boolean }?): boolean
	for _, stoneId in ability.requires do
		if not (stones and stones[stoneId]) then
			return false
		end
	end
	return true
end

return Abilities
