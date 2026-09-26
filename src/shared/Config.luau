--!strict
-- Общие настройки игры. Доступны и серверу, и клиенту.

local Config = {
	DataStoreName = "PlayerData_v1",
	AutosaveInterval = 120, -- секунды

	DefaultData = {
		Coins = 0,
	},
}

export type PlayerData = typeof(Config.DefaultData)

return table.freeze(Config)
