--!strict
-- Общие настройки игры. Доступны и серверу, и клиенту.

local Config = {
	DataStoreName = "PlayerData_v1",
	AutosaveInterval = 120, -- секунды

	DefaultData = {
		Coins = 0,
		Stones = {} :: { [string]: boolean }, -- собранные Камни Бесконечности
	},

	Rewards = {
		DummyKill = 10,
		PlayerKill = 25,
	},
}

export type PlayerData = typeof(Config.DefaultData)

return table.freeze(Config)
