--!strict
-- История положения и здоровья игроков за последние секунды.
-- Нужна для перемотки времени (Камень Времени у Таноса, Сдвиг во времени у Локи).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local SAMPLE_INTERVAL = 0.1
local HISTORY_SECONDS = 6

export type Sample = { time: number, cframe: CFrame, health: number }

local Timeline = {}

local history: { [Player]: { Sample } } = {}
local accumulator = 0

local function record()
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 then
			local samples = history[player]
			if not samples then
				samples = {}
				history[player] = samples
			end
			table.insert(samples, { time = now, cframe = root.CFrame, health = humanoid.Health })
			while #samples > 0 and now - samples[1].time > HISTORY_SECONDS do
				table.remove(samples, 1)
			end
		else
			history[player] = nil
		end
	end
end

-- Состояние игрока secondsAgo секунд назад (или самое старое из доступных).
function Timeline.at(player: Player, secondsAgo: number): Sample?
	local samples = history[player]
	if not samples or #samples == 0 then
		return nil
	end
	local target = os.clock() - secondsAgo
	for _, sample in samples do
		if sample.time >= target then
			return sample
		end
	end
	return samples[#samples]
end

-- Точки пути за последние secondsAgo секунд (для следа перемотки).
function Timeline.path(player: Player, secondsAgo: number): { Vector3 }
	local points = {}
	local target = os.clock() - secondsAgo
	local samples: { Sample } = history[player] or {}
	for _, sample in samples do
		if sample.time >= target then
			table.insert(points, sample.cframe.Position)
		end
	end
	return points
end

-- После перемотки старая история больше не нужна: иначе можно перематываться "в цепочку".
function Timeline.clear(player: Player)
	history[player] = nil
end

RunService.Heartbeat:Connect(function(dt)
	accumulator += dt
	if accumulator >= SAMPLE_INTERVAL then
		accumulator = 0
		record()
	end
end)

Players.PlayerRemoving:Connect(function(player)
	history[player] = nil
end)

return Timeline
