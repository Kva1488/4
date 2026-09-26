--!strict
-- Общие настройки игры. Доступны и серверу, и клиенту.

local Config = {
	DataStoreName = "PlayerData_v1",
	AutosaveInterval = 120, -- секунды

	DefaultData = {
		Coins = 0,
		Stones = {} :: { [string]: boolean }, -- собранные Камни Бесконечности
		Upgrades = { Damage = 0, Cooldown = 0, Health = 0 } :: { [string]: number },
		Skins = { Gold = true } :: { [string]: boolean }, -- купленные скины Перчатки
		EquippedSkin = "Gold",
		Hero = "Thanos", -- текущий герой (Shared/Heroes)
		LokiKills = 0, -- убийства за Локи (открывают Локи, бога времени)
		UltronKills = 0, -- убийства за Альтрона (открывают Альтрона бесконечности)
		ThorKills = 0, -- убийства за Тора (открывают Громсекиру, а затем молот и топор)
		Level = 1, -- уровень игрока (Shared/Progression)
		Xp = 0, -- опыт на текущем уровне
		Kills = 0, -- все убийства (игроки, манекены, прислужники)
		BossKills = 0, -- победы над Дормамму (с вкладом в урон)
		ArenaWins = 0, -- выигранные раунды на арене
		DailyStreak = 0, -- день серии ежедневных наград (1..7)
		BestStreak = 0, -- самая длинная серия подряд
		LastDaily = -1, -- номер дня (UTC), когда забрали награду
		EquippedTitle = "", -- id титула над головой ("" — без титула)
		OwnedHeroes = {} :: { [string]: boolean }, -- герои, купленные за робуксы
		Passes = {} :: { [string]: boolean }, -- разовые награды геймпассов уже выданы (стартовый набор)
		Receipts = {} :: { [string]: boolean }, -- обработанные покупки за робуксы (чтобы не выдать дважды)
	},

	Rewards = {
		DummyKill = 10,
		PlayerKill = 25,
		StoneFirstPickup = 50,
		Playtime = 5, -- монет за каждый интервал в игре
		PlaytimeInterval = 60, -- секунды
	},
}

export type PlayerData = typeof(Config.DefaultData)

return table.freeze(Config)
