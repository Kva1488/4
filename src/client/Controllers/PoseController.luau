--!strict
-- Анимации руки с Перчаткой без внешних ассетов: сервер ставит персонажу атрибуты
-- Pose/PoseId, а каждый клиент поворачивает плечевой сустав поверх обычной анимации.
-- Motor6D.Transform меняется в Stepped — это происходит после Animator, поэтому поза видна.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

type PoseDef = {
	duration: number,
	rise: number, -- время подъёма руки
	fall: number, -- время опускания
	angle: number, -- градусы подъёма руки вперёд/вверх
}

local POSES: { [string]: PoseDef } = {
	Punch = { duration = 0.28, rise = 0.06, fall = 0.14, angle = 95 },
	Cast = { duration = 0.55, rise = 0.1, fall = 0.2, angle = 85 },
	Raise = { duration = 2.1, rise = 0.35, fall = 0.4, angle = 165 },
}

type Active = { def: PoseDef, started: number }

local PoseController = {}

local active: { [Model]: Active } = {}

local function shoulderOf(character: Model): (Motor6D?, boolean)
	local upperArm = character:FindFirstChild("RightUpperArm")
	if upperArm then
		return upperArm:FindFirstChild("RightShoulder") :: Motor6D?, false
	end
	local torso = character:FindFirstChild("Torso")
	if torso then
		return torso:FindFirstChild("Right Shoulder") :: Motor6D?, true
	end
	return nil, false
end

local function envelope(def: PoseDef, t: number): number
	if t < def.rise then
		return t / def.rise
	elseif t > def.duration - def.fall then
		return math.max(0, (def.duration - t) / def.fall)
	end
	return 1
end

local function watch(character: Model)
	character:GetAttributeChangedSignal("PoseId"):Connect(function()
		local def = POSES[character:GetAttribute("Pose") :: string]
		if def then
			active[character] = { def = def, started = os.clock() }
		end
	end)
	character.Destroying:Connect(function()
		active[character] = nil
	end)
end

local function onPlayer(player: Player)
	player.CharacterAdded:Connect(watch)
	if player.Character then
		watch(player.Character)
	end
end

function PoseController:Start()
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end

	RunService.Stepped:Connect(function()
		local now = os.clock()
		for character, pose in active do
			local t = now - pose.started
			if t >= pose.def.duration or not character.Parent then
				active[character] = nil
				continue
			end
			local motor, isR6 = shoulderOf(character)
			if motor then
				-- Плавная кривая (smoothstep), чтобы движение не было "роботным".
				local x = envelope(pose.def, t)
				local eased = x * x * (3 - 2 * x)
				local angle = math.rad(pose.def.angle) * eased
				-- У R15 рука поднимается вращением вокруг X, у R6 — вокруг Z сустава.
				local rotation = if isR6 then CFrame.Angles(0, 0, angle) else CFrame.Angles(angle, 0, 0)
				motor.Transform = motor.Transform * rotation
			end
		end
	end)
end

return PoseController
