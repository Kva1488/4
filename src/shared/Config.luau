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
