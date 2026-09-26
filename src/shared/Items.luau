--!strict
-- Предметы: Перчатка Бесконечности и 6 Камней Бесконечности.

export type Stone = {
	id: string,
	name: string,
	color: Color3,
	description: string,
	ability: string, -- id способности из Abilities
	hint: string, -- где искать на карте
	order: number,
}

local Stones: { Stone } = {
	{
		id = "Power",
		name = "Камень Силы",
		color = Color3.fromRGB(170, 60, 255),
		description = "Чистая разрушительная энергия. Бьёт всех вокруг волной и отбрасывает.",
		ability = "PowerWave",
		hint = "На вершине фиолетовой башни.",
		order = 1,
	},
	{
		id = "Space",
		name = "Камень Пространства",
		color = Color3.fromRGB(40, 130, 255),
		description = "Власть над пространством. Мгновенный телепорт в точку прицела.",
		ability = "SpaceWarp",
		hint = "Над синими парящими платформами.",
		order = 2,
	},
	{
		id = "Reality",
		name = "Камень Реальности",
		color = Color3.fromRGB(235, 35, 45),
		description = "Переписывает реальность. Враги в зоне уменьшаются и получают урон.",
		ability = "RealityShrink",
		hint = "В центре кирпичного лабиринта.",
		order = 3,
	},
	{
		id = "Soul",
		name = "Камень Души",
		color = Color3.fromRGB(255, 140, 20),
		description = "Вытягивает жизнь из врагов рядом и лечит тебя.",
		ability = "SoulDrain",
		hint = "На самой высокой башне в дальнем углу карты.",
		order = 4,
	},
	{
		id = "Time",
		name = "Камень Времени",
		color = Color3.fromRGB(40, 220, 90),
		description = "Замедляет время для всех врагов вокруг и отматывает твои раны назад.",
		ability = "TimeSlow",
		hint = "Над зелёным паркуром.",
		order = 5,
	},
	{
		id = "Mind",
		name = "Камень Разума",
		color = Color3.fromRGB(255, 215, 40),
		description = "Подчиняет разум. Оглушает врагов в точке прицела.",
		ability = "MindStun",
		hint = "На пьедестале в дальнем поле.",
		order = 6,
	},
}

local StoneById: { [string]: Stone } = {}
for _, stone in Stones do
	StoneById[stone.id] = stone
end

local Items = {
	Stones = Stones,
	StoneById = StoneById,
	Gauntlet = {
		name = "Перчатка Бесконечности",
		color = Color3.fromRGB(230, 175, 50),
		description = "Выкована на Нидавеллире. Даёт удар, серию ударов и луч. "
			.. "Собери все 6 камней, чтобы открыть Щелчок.",
	},
}

function Items.countStones(stones: { [string]: boolean }?): number
	local count = 0
	if stones then
		for _, stone in Stones do
			if stones[stone.id] then
				count += 1
			end
		end
	end
	return count
end

return Items
