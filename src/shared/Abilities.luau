--!strict
-- Описание всех способностей Перчатки: клавиши, перезарядки, какие камни нужны.
-- Логика способностей находится на сервере (src/server/Combat/AbilityHandlers.luau).

export type Ability = {
	id: string,
	name: string,
	description: string,
	input: Enum.KeyCode | Enum.UserInputType,
	keyLabel: string,
	cooldown: number,
	requires: { string }, -- id камней
	color: Color3,
	range: number, -- дальность прицела (для способностей без прицела это радиус)
	kind: "basic" | "stone" | "combo" | "ultimate",
}

local GOLD = Color3.fromRGB(230, 175, 50)
local ALL_STONES = { "Power", "Space", "Reality", "Soul", "Time", "Mind" }

local List: { Ability } = {
	{
		id = "Punch",
		name = "Удар",
		description = "Серия из 3 ударов: третий бьёт сильнее и отбрасывает.",
		input = Enum.UserInputType.MouseButton1,
		keyLabel = "ЛКМ",
		cooldown = 0.35,
		requires = {},
		color = GOLD,
		range = 6,
		kind = "basic",
	},
	{
		id = "Beam",
		name = "Луч",
		description = "Золотой луч из Перчатки по прицелу.",
		input = Enum.KeyCode.F,
		keyLabel = "F",
		cooldown = 2,
		requires = {},
		color = Color3.fromRGB(255, 235, 150),
		range = 120,
		kind = "basic",
	},
	{
		id = "PowerWave",
		name = "Волна Силы",
		description = "Взрывная волна вокруг тебя: 35 урона и мощное отбрасывание.",
		input = Enum.KeyCode.One,
		keyLabel = "1",
		cooldown = 8,
		requires = { "Power" },
		color = Color3.fromRGB(170, 60, 255),
		range = 18,
		kind = "stone",
	},
	{
		id = "SpaceWarp",
		name = "Телепорт",
		description = "Мгновенное перемещение в точку прицела.",
		input = Enum.KeyCode.Two,
		keyLabel = "2",
		cooldown = 6,
		requires = { "Space" },
		color = Color3.fromRGB(40, 130, 255),
		range = 80,
		kind = "stone",
	},
	{
		id = "RealityShrink",
		name = "Искажение",
		description = "Враги в зоне прицела получают 25 урона и уменьшаются на 6 секунд.",
		input = Enum.KeyCode.Three,
		keyLabel = "3",
		cooldown = 12,
		requires = { "Reality" },
		color = Color3.fromRGB(235, 35, 45),
		range = 80,
		kind = "stone",
	},
	{
		id = "SoulDrain",
		name = "Похищение души",
		description = "Высасывает 20 здоровья из каждого врага рядом и лечит тебя.",
		input = Enum.KeyCode.Four,
		keyLabel = "4",
		cooldown = 10,
		requires = { "Soul" },
		color = Color3.fromRGB(255, 140, 20),
		range = 22,
		kind = "stone",
	},
	{
		id = "TimeSlow",
		name = "Замедление времени",
		description = "Враги вокруг замедляются на 5 секунд, а ты восстанавливаешь 20 здоровья.",
		input = Enum.KeyCode.Five,
		keyLabel = "5",
		cooldown = 12,
		requires = { "Time" },
		color = Color3.fromRGB(40, 220, 90),
		range = 26,
		kind = "stone",
	},
	{
		id = "MindStun",
		name = "Контроль разума",
		description = "Оглушает врагов в зоне прицела на 2.5 секунды и наносит 15 урона.",
		input = Enum.KeyCode.Six,
		keyLabel = "6",
		cooldown = 10,
		requires = { "Mind" },
		color = Color3.fromRGB(255, 215, 40),
		range = 80,
		kind = "stone",
	},
	{
		id = "Meteor",
		name = "Метеор",
		description = "Сила + Пространство: телепорт в точку и сокрушительный удар по земле (40 урона).",
		input = Enum.KeyCode.Z,
		keyLabel = "Z",
		cooldown = 14,
		requires = { "Power", "Space" },
		color = Color3.fromRGB(110, 90, 255),
		range = 80,
		kind = "combo",
	},
	{
		id = "Stasis",
		name = "Стазис",
		description = "Время + Реальность: заключает врагов в кристалл времени на 3.5 секунды.",
		input = Enum.KeyCode.X,
		keyLabel = "X",
		cooldown = 16,
		requires = { "Time", "Reality" },
		color = Color3.fromRGB(80, 230, 220),
		range = 80,
		kind = "combo",
	},
	{
		id = "SoulHarvest",
		name = "Жатва душ",
		description = "Душа + Разум: оглушает всех врагов рядом и забирает у каждого 25 здоровья.",
		input = Enum.KeyCode.C,
		keyLabel = "C",
		cooldown = 18,
		requires = { "Soul", "Mind" },
		color = Color3.fromRGB(255, 120, 90),
		range = 32,
		kind = "combo",
	},
	{
		id = "Snap",
		name = "ЩЕЛЧОК",
		description = "Все 6 камней: половина врагов в радиусе 100 обращается в пыль.",
		input = Enum.KeyCode.G,
		keyLabel = "G",
		cooldown = 90,
		requires = ALL_STONES,
		color = Color3.fromRGB(255, 255, 255),
		range = 100,
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

function Abilities.isUnlocked(ability: Ability, stones: { [string]: boolean }?): boolean
	for _, stoneId in ability.requires do
		if not (stones and stones[stoneId]) then
			return false
		end
	end
	return true
end

return Abilities
