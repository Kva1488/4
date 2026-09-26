--!strict
-- Режимы летающей арены. Сменяют друг друга по кругу; сервер ведёт раунды (ArenaService),
-- клиент показывает табло (ArenaController).

export type Mode = {
	id: string,
	name: string,
	icon: string,
	color: Color3,
	goal: number, -- столько очков — досрочная победа
	duration: number, -- секунды на раунд
	description: string,
}

local ArenaModes = {}

ArenaModes.List = {
	{
		id = "KingOfHill",
		name = "Царь горы",
		icon = "👑",
		color = Color3.fromRGB(255, 205, 70),
		goal = 60,
		duration = 150,
		description = "Стой в светящемся круге один: +1 очко в секунду. Двое в круге — никому. Круг переезжает!",
	},
	{
		id = "Gauntlet",
		name = "Захват Перчатки",
		icon = "🧤",
		color = Color3.fromRGB(230, 175, 50),
		goal = 60,
		duration = 150,
		description = "Держи Перчатку Бесконечности: +1 очко в секунду. Убей держателя — +5 очков и Перчатка падает.",
	},
	{
		id = "Deathmatch",
		name = "Схватка",
		icon = "⚔️",
		color = Color3.fromRGB(255, 90, 90),
		goal = 15,
		duration = 150,
		description = "Больше всех убийств — победа. Возрождение сразу на арене.",
	},
} :: { Mode }

ArenaModes.ById = {} :: { [string]: Mode }
for _, mode in ArenaModes.List do
	ArenaModes.ById[mode.id] = mode
end

ArenaModes.Intermission = 12 -- секунды между раундами
ArenaModes.ResultsTime = 7
ArenaModes.WinCoins = 150
ArenaModes.ParticipationCoins = 30

return table.freeze(ArenaModes)
