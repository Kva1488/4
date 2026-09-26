--!strict
-- Клиентская копия данных игрока (монеты, камни). Сервер присылает обновления сам.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

type PlayerData = Config.PlayerData

local changed = Instance.new("BindableEvent")

local PlayerState = {
	Changed = changed.Event, -- (data: PlayerData)
}

local current: PlayerData? = nil

local function set(data: PlayerData?)
	if data then
		current = data
		changed:Fire(data)
	end
end

function PlayerState.get(): PlayerData?
	return current
end

function PlayerState.stones(): { [string]: boolean }
	return if current then current.Stones else {}
end

Remotes.event("DataChanged").OnClientEvent:Connect(set)
task.spawn(function()
	local data = Remotes.func("GetData"):InvokeServer()
	if not current then
		set(data)
	end
end)

return PlayerState
