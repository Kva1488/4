--!strict
-- Прокачка игрока: уровни и опыт, ежедневные награды за серию входов и титулы над головой.
-- Общая для сервера (начисляет) и клиента (показывает полоску опыта, панель наград).

local Progression = {}

Progression.MaxLevel = 100

-- Опыт за действия (начисляет ProgressionService на сервере).
Progression.Xp = {
	DamagePer10 = 1, -- за каждые 10 нанесённого урона
	DummyKill = 15,
	PlayerKill = 40,
	MinionKill = 25,
	BossParticipation = 200, -- всем, кто нанёс Дормамму хоть сколько-то урона
	BossShare = 800, -- делится пропорционально вкладу в урон
	ArenaWin = 300,
	ArenaParticipation = 60,
}

-- Сколько опыта нужно, чтобы с уровня level перейти на следующий.
function Progression.xpToNext(level: number): number
	return 100 + (level - 1) * 40
end

-- Монеты за достижение уровня level.
function Progression.levelReward(level: number): number
	return 25 + level * 5
end

-- Ежедневная награда: день серии 1..7 (после седьмого серия начинается заново).
export type DailyReward = { coins: number, xp: number }
Progression.Daily = {
	{ coins = 50, xp = 50 },
	{ coins = 75, xp = 75 },
	{ coins = 100, xp = 100 },
	{ coins = 150, xp = 150 },
	{ coins = 200, xp = 200 },
	{ coins = 300, xp = 250 },
	{ coins = 500, xp = 500 },
} :: { DailyReward }

-- Номер текущего дня (UTC). Награду можно забрать один раз в день.
function Progression.today(): number
	return os.time() // 86400
end

-- Какой день серии будет следующим, если забрать награду в день today.
function Progression.nextStreak(lastDaily: number, streak: number, today: number): number
	if lastDaily == today - 1 then
		return streak % #Progression.Daily + 1
	end
	return 1
end

-- Титулы. Условие — минимальное значение поля данных игрока (Level, BossKills и т. д.).
export type Title = {
	id: string,
	name: string,
	color: Color3,
	stat: string,
	min: number,
	hint: string,
}

Progression.Titles = {
	{
		id = "Seeker",
		name = "Искатель камней",
		color = Color3.fromRGB(150, 200, 255),
		stat = "Level",
		min = 5,
		hint = "Достигни 5 уровня",
	},
	{
		id = "Avenger",
		name = "Мститель",
		color = Color3.fromRGB(90, 160, 255),
		stat = "Level",
		min = 10,
		hint = "Достигни 10 уровня",
	},
	{
		id = "Asgardian",
		name = "Воин Асгарда",
		color = Color3.fromRGB(140, 205, 255),
		stat = "Level",
		min = 20,
		hint = "Достигни 20 уровня",
	},
	{
		id = "Titan",
		name = "Титан",
		color = Color3.fromRGB(200, 120, 255),
		stat = "Level",
		min = 35,
		hint = "Достигни 35 уровня",
	},
	{
		id = "Inevitable",
		name = "Неотвратимый",
		color = Color3.fromRGB(255, 200, 60),
		stat = "Level",
		min = 50,
		hint = "Достигни 50 уровня",
	},
	{
		id = "Ruthless",
		name = "Беспощадный",
		color = Color3.fromRGB(255, 90, 90),
		stat = "Kills",
		min = 100,
		hint = "Соверши 100 убийств",
	},
	{
		id = "Challenger",
		name = "Чемпион арены",
		color = Color3.fromRGB(255, 170, 60),
		stat = "ArenaWins",
		min = 1,
		hint = "Выиграй раунд на арене",
	},
	{
		id = "Grandmaster",
		name = "Грандмастер",
		color = Color3.fromRGB(255, 120, 200),
		stat = "ArenaWins",
		min = 10,
		hint = "Выиграй 10 раундов на арене",
	},
	{
		id = "Bargainer",
		name = "Я пришёл договориться",
		color = Color3.fromRGB(255, 150, 40),
		stat = "BossKills",
		min = 1,
		hint = "Победи Дормамму",
	},
	{
		id = "DarkLord",
		name = "Повелитель Тёмного измерения",
		color = Color3.fromRGB(190, 70, 255),
		stat = "BossKills",
		min = 10,
		hint = "Победи Дормамму 10 раз",
	},
	{
		id = "Loyal",
		name = "Верный",
		color = Color3.fromRGB(120, 230, 140),
		stat = "BestStreak",
		min = 7,
		hint = "Забирай ежедневную награду 7 дней подряд",
	},
} :: { Title }

Progression.TitleById = {} :: { [string]: Title }
for _, title in Progression.Titles do
	Progression.TitleById[title.id] = title
end

function Progression.hasTitle(title: Title, data: any): boolean
	local value = data[title.stat]
	return type(value) == "number" and value >= title.min
end

return table.freeze(Progression)
