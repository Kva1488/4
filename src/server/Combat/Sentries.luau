--!strict
-- Дроны-часовые Альтрона: летают вокруг хозяина и стреляют красными лучами по ближайшим врагам.
-- Хранятся по игрокам, чтобы "Перенос сознания" мог переселить Альтрона в одного из них.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Damage = require(script.Parent.Damage)
local Fx = require(script.Parent.Fx)

export type Sentry = {
	model: Model,
	body: BasePart,
	expires: number,
	nextShot: number,
	damage: number,
	angle: number,
}

type Owner = {
	player: Player,
	hit: (Damage.Target, number) -> (), -- наносит урон от имени хозяина (с прокачкой)
}

local Sentries = {}

local RED = Color3.fromRGB(235, 50, 45)
local STEEL = Color3.fromRGB(165, 170, 182)
local ORBIT_RADIUS = 6
local RANGE = 45
local FIRE_INTERVAL = 0.8

local active: { [Player]: { Sentry } } = {}
local owners: { [Player]: Owner } = {}

local function makeDrone(position: Vector3, gold: boolean): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = "Sentry"
	local function part(
		shape: Enum.PartType,
		size: Vector3,
		color: Color3,
		material: Enum.Material,
		offset: CFrame
	): Part
		local p = Instance.new("Part")
		p.Shape = shape
		p.Size = size
		p.Color = color
		p.Material = material
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CFrame = CFrame.new(position) * offset
		p.Parent = model
		return p
	end
	local body = part(Enum.PartType.Ball, Vector3.one * 1.6, STEEL, Enum.Material.Metal, CFrame.new())
	part(
		Enum.PartType.Block,
		Vector3.new(0.9, 0.18, 0.1),
		RED,
		Enum.Material.Neon,
		CFrame.new(0, 0.15, -0.76)
	)
	part(
		Enum.PartType.Block,
		Vector3.new(2.6, 0.12, 0.5),
		if gold then Color3.fromRGB(230, 180, 60) else STEEL,
		Enum.Material.Metal,
		CFrame.new()
	)
	local light = Instance.new("PointLight")
	light.Color = RED
	light.Range = 8
	light.Brightness = 1.5
	light.Parent = body
	model.PrimaryPart = body
	model.Parent = Fx.Folder
	return model, body
end

-- Добавить хозяину count часовых на duration секунд.
function Sentries.spawn(
	player: Player,
	hit: (Damage.Target, number) -> (),
	count: number,
	duration: number,
	damage: number,
	gold: boolean?
)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	owners[player] = { player = player, hit = hit }
	local list = active[player]
	if not list then
		list = {}
		active[player] = list
	end
	for i = 1, count do
		local angle = (i / count) * math.pi * 2 + math.random()
		local position = root.Position
			+ Vector3.new(math.cos(angle) * ORBIT_RADIUS, 4, math.sin(angle) * ORBIT_RADIUS)
		local model, body = makeDrone(position, gold == true)
		Fx.burst(position, RED, 15, 12)
		table.insert(list, {
			model = model,
			body = body,
			expires = os.clock() + duration,
			nextShot = os.clock() + 0.3 + i * 0.15,
			damage = damage,
			angle = angle,
		})
	end
end

-- Забрать ближайшего к точке часового (для переноса сознания).
function Sentries.take(player: Player, near: Vector3): Vector3?
	local list = active[player]
	if not list or #list == 0 then
		return nil
	end
	local bestIndex, bestDistance = 1, math.huge
	for i, sentry in list do
		local distance = (sentry.body.Position - near).Magnitude
		if distance < bestDistance then
			bestIndex, bestDistance = i, distance
		end
	end
	local sentry = table.remove(list, bestIndex) :: Sentry
	local position = sentry.body.Position
	Fx.burst(position, RED, 30, 25)
	sentry.model:Destroy()
	return position
end

local function removeAll(player: Player)
	local list: { Sentry } = active[player] or {}
	for _, sentry in list do
		sentry.model:Destroy()
	end
	active[player] = nil
	owners[player] = nil
end

RunService.Heartbeat:Connect(function()
	local now = os.clock()
	for player, list in active do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local owner = owners[player]
		if not root or not owner then
			removeAll(player)
			continue
		end
		for i = #list, 1, -1 do
			local sentry = list[i]
			if now >= sentry.expires then
				Fx.burst(sentry.body.Position, RED, 12, 10)
				sentry.model:Destroy()
				table.remove(list, i)
				continue
			end
			-- Облёт хозяина с лёгким покачиванием.
			sentry.angle += 0.02
			local position = root.Position
				+ Vector3.new(
					math.cos(sentry.angle) * ORBIT_RADIUS,
					4 + math.sin(now * 3 + i) * 0.6,
					math.sin(sentry.angle) * ORBIT_RADIUS
				)

			local targets = Damage.inRadius(position, RANGE, character)
			table.sort(targets, function(a, b)
				return (a.root.Position - position).Magnitude < (b.root.Position - position).Magnitude
			end)
			local target = targets[1]
			local look = if target then target.root.Position else position + root.CFrame.LookVector
			sentry.model:PivotTo(CFrame.lookAt(position, look))

			if target and now >= sentry.nextShot then
				sentry.nextShot = now + FIRE_INTERVAL
				Fx.beam(position, target.root.Position, RED, 0.35, 0.18)
				owner.hit(target, sentry.damage)
			end
		end
		if #list == 0 then
			active[player] = nil
		end
	end
end)

Players.PlayerRemoving:Connect(removeAll)

return Sentries
