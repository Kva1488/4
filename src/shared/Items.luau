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
		description = "Камень с Мораг: разрушительная энергия, способная уничтожать планеты.",
		ability = "PowerWave",
		hint = "Мораг: башня храма посреди озера.",
		order = 1,
	},
	{
		id = "Space",
		name = "Камень Пространства",
		color = Color3.fromRGB(40, 130, 255),
		description = "Тессеракт: порталы в любую точку пространства.",
		ability = "SpaceWarp",
		hint = "Асгард: парящие ступени над обсерваторией.",
		order = 2,
	},
	{
		id = "Reality",
		name = "Камень Реальности",
		color = Color3.fromRGB(235, 35, 45),
		description = "Переписывает материю: враги в зоне рассыпаются на кубы, как Дракс на Забвении.",
		ability = "RealityWarp",
		hint = "Свартальфхейм: в сердце лабиринта.",
		order = 3,
	},
	{
		id = "Soul",
		name = "Камень Души",
		color = Color3.fromRGB(255, 140, 20),
		description = "Вытягивает жизнь из врагов рядом и лечит тебя.",
		ability = "SoulDrain",
		hint = "Вормир: на вершине утёса среди снегов.",
		order = 4,
	},
	{
		id = "Time",
		name = "Камень Времени",
		color = Color3.fromRGB(40, 220, 90),
		description = "Власть над временем: перематывает тебя назад вместе со здоровьем, как Танос в Ваканде.",
		ability = "TimeRewind",
		hint = "Камар-Тадж: над ступенями во дворе храма.",
		order = 5,
	},
	{
		id = "Mind",
		name = "Камень Разума",
		color = Color3.fromRGB(255, 215, 40),
		description = "Сила Вижна: жёлтый луч, который пробивает и оглушает всех на линии.",
		ability = "MindBeam",
		hint = "Ваканда: на холме у Водопада Воинов.",
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
		description = "Выкована Эйтри на Нидавеллире. Даёт удар, серию ударов и залп. "
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
