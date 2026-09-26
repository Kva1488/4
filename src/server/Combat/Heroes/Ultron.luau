--!strict
-- Альтрон — «Мстители: Эра Альтрона». Вибраниевые когти, репульсоры, армия часовых,
-- антигравитация «Левиафана», перенос сознания между телами и подъём Соковии.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Abilities = require(ReplicatedStorage.Shared.Abilities)

local Damage = require(script.Parent.Parent.Damage)
local Fx = require(script.Parent.Parent.Fx)
local Kit = require(script.Parent.Parent.Kit)
local Sentries = require(script.Parent.Parent.Sentries)
local Status = require(script.Parent.Parent.Status)

type Context = Kit.Context

local color = Kit.color
local hit = Kit.hit

local RED = Color3.fromRGB(235, 50, 45)
local STEEL = Color3.fromRGB(200, 205, 215)

local comboState: { [Player]: { count: number, last: number } } = setmetatable({}, { __mode = "k" }) :: any

local Handlers: { [string]: (Context) -> () } = {}

-- Когти: серия из 3, третий удар сильнее и отбрасывает.
function Handlers.UltronClaw(ctx)
	local now = os.clock()
	local state: { count: number, last: number } = comboState[ctx.player] or { count = 0, last = 0 }
	comboState[ctx.player] = state
	state.count = if now - state.last < 1 then state.count % 3 + 1 else 1
	state.last = now
	local heavy = state.count == 3

	local direction = Kit.aimFlat(ctx)
	local origin = CFrame.lookAt(ctx.root.Position, ctx.root.Position + direction)
	local hitPoint = ctx.root.Position + direction * 3.5
	-- Три параллельных следа когтей.
	for offset = -1, 1 do
		Fx.slash(
			origin * CFrame.new(offset * 0.5, offset * 0.3, 0),
			if heavy then RED else STEEL,
			5,
			state.count == 2
		)
	end
	Fx.sound(if heavy then "PunchFinisher" else "Punch", hitPoint, 0.7, 0.8)

	for _, target in Damage.inRadius(hitPoint, 4.5, ctx.character) do
		hit(ctx, target, if heavy then 24 else 11, if heavy then RED else STEEL)
		Fx.burst(target.root.Position, RED, if heavy then 25 else 10, 25)
		if heavy then
			Damage.knockback(target.root, direction * 65 + Vector3.new(0, 20, 0))
		end
	end
end

-- Репульсор из ладони.
function Handlers.Repulsor(ctx)
	local origin = ctx.root.Position + Vector3.new(0, 1, 0)
	local direction = Kit.aim3D(ctx, origin) * Abilities.ById.Repulsor.range
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { ctx.character, Fx.Folder }
	local result = workspace:Raycast(origin, direction, params)
	local finish = if result then result.Position else origin + direction

	Fx.sound("Beam", origin, 0.6, 0.9)
	Fx.beam(origin, finish, RED, 1, 0.3)
	Fx.lightning(origin, finish, Color3.fromRGB(255, 160, 140), 8, 0.2)
	Fx.sphere(origin, RED, 2.2, 0.5, 0.2)
	Fx.sphere(finish, RED, 1, 5, 0.3)
	Fx.burst(finish, RED, 18, 28)
	Fx.flash(finish, RED, 14)
	if result then
		local target = Damage.fromPart(result.Instance, ctx.character)
		if target then
			hit(ctx, target, 20)
		end
	end
end

-- Часовые: 3 дрона на 10 секунд.
function Handlers.Sentries(ctx)
	Fx.sound("Magic", ctx.root.Position, 0.7, 1.3)
	Sentries.spawn(ctx.player, function(target, damage)
		hit(ctx, target, damage)
	end, 3, 10, 6)
end

-- Антигравитационный рывок.
function Handlers.AntiGravDash(ctx)
	local direction = Kit.aim3D(ctx, ctx.root.Position)
	local flat = Kit.aimFlat(ctx)
	local velocity = flat * 110 + Vector3.new(0, math.clamp(direction.Y, -0.2, 0.6) * 90 + 25, 0)
	Fx.sound("Wave", ctx.root.Position, 0.6, 1.5)
	Fx.ring(ctx.root.Position - Vector3.new(0, 2.5, 0), RED, 6, 0.3)
	Damage.knockback(ctx.root, velocity, 0.3)
	-- Реактивный след и серия послеобразов.
	for i = 1, 6 do
		task.delay(i * 0.05, function()
			if ctx.root.Parent then
				Fx.burst(ctx.root.Position, RED, 6, 4, "Fire")
				if i % 2 == 0 then
					Fx.afterimage(ctx.character, RED, 0.35)
				end
			end
		end)
	end
end

-- Гравитационный пресс: подбросить и впечатать в землю.
function Handlers.GravityCrush(ctx)
	local radius = 12
	local center = ctx.target
	local c = color("GravityCrush")
	Fx.sound("Magic", center, 0.9, 0.6)
	Fx.ring(center, c, radius, 0.6)
	local targets = Damage.inRadius(center, radius, ctx.character)
	for _, target in targets do
		Damage.knockback(target.root, Vector3.new(0, 70, 0), 0.3)
		Fx.burst(target.root.Position, c, 10, 10)
	end
	task.wait(0.65)
	Fx.shockwave(center, c, radius)
	Fx.burst(center, Color3.fromRGB(120, 100, 90), 30, 25, "Smoke")
	for _, target in targets do
		if target.humanoid.Health > 0 then
			Damage.knockback(target.root, Vector3.new(0, -140, 0), 0.25)
			hit(ctx, target, 30)
			Status.apply(target.humanoid, "Stun", 1)
		end
	end
end

-- Перенос сознания: переселиться в ближайшего часового.
function Handlers.ConsciousnessTransfer(ctx)
	local from = ctx.root.Position
	local body = Sentries.take(ctx.player, ctx.target)
	Fx.sound("Teleport", from, 0.8, 0.7)
	Fx.burst(from, RED, 25, 15)
	Fx.afterimage(ctx.character, RED, 0.6)
	if body then
		Fx.lightning(from, body, RED, 10, 0.4)
		ctx.character:PivotTo(CFrame.lookAt(body, body + Kit.aimFlat(ctx)))
		Damage.heal(ctx.humanoid, 25)
		Fx.sphere(body, RED, 1, 7, 0.4)
	else
		local destination = from + Kit.aimFlat(ctx) * Abilities.ById.ConsciousnessTransfer.range
		Kit.teleport(ctx, destination - Vector3.new(0, 3, 0))
		Fx.sphere(destination, RED, 1, 6, 0.35)
	end
end

-- Подъём Соковии: пласт земли взлетает вместе с врагами и рушится.
function Handlers.SokoviaRise(ctx)
	local radius = 16
	local center = ctx.target
	local c = color("SokoviaRise")
	for _, player in Kit.playersNear(center, 120) do
		Kit.screenFx:FireClient(player, "Sokovia", center)
	end
	Fx.sound("Wave", center, 1.2, 0.5)
	Fx.ring(center, c, radius, 1)

	local slab = Instance.new("Part")
	slab.Name = "Sokovia"
	slab.Shape = Enum.PartType.Cylinder
	slab.Anchored = true
	slab.CanCollide = false
	slab.CanQuery = false
	slab.Material = Enum.Material.Rock
	slab.Color = Color3.fromRGB(110, 90, 75)
	slab.Size = Vector3.new(5, radius * 2, radius * 2)
	slab.CFrame = CFrame.new(center - Vector3.new(0, 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	slab.Parent = Fx.Folder
	game:GetService("TweenService")
		:Create(
			slab,
			TweenInfo.new(1.2, Enum.EasingStyle.Sine),
			{ CFrame = slab.CFrame + Vector3.new(0, 28, 0) }
		)
		:Play()

	local targets = Damage.inRadius(center, radius, ctx.character)
	for _, target in targets do
		Status.apply(target.humanoid, "Stun", 2.2)
		Damage.knockback(target.root, Vector3.new(0, 42, 0), 0.8)
	end
	task.wait(1.3)
	-- Пласт раскалывается на обломки, и все падают.
	local top = slab.Position
	slab:Destroy()
	Fx.burst(top, c, 60, 40, "Smoke")
	for i = 1, 10 do
		local offset = Vector3.new(math.random(-radius, radius), 0, math.random(-radius, radius))
		task.delay(i * 0.05, function()
			local fall = Fx.meteor(center + offset, 0.5)
			task.wait(fall)
			Fx.burst(center + offset, Color3.fromRGB(120, 100, 90), 10, 15, "Smoke")
		end)
	end
	task.wait(0.6)
	Fx.shockwave(center, c, radius * 1.3)
	Fx.flash(center, c, 40, 0.6)
	for _, target in targets do
		if target.humanoid.Health > 0 then
			hit(ctx, target, 45)
		end
	end
end

-- Взлом: урон и 3 секунды без способностей у всех в зоне.
function Handlers.Hack(ctx)
	local radius = 12
	local center = ctx.target
	Fx.sound("Magic", center, 0.9, 1.8)
	Fx.ring(center, RED, radius, 0.5)
	for _, target in Damage.inRadius(center, radius, ctx.character) do
		Fx.lightning(ctx.root.Position + Vector3.new(0, 1, 0), target.root.Position, RED, 10, 0.4)
		hit(ctx, target, 15)
		Status.apply(target.humanoid, "Silence", 3)
		Fx.clock(target.root.Position + Vector3.new(0, 1, 0), RED, 3, 3)
		local victim = game:GetService("Players"):GetPlayerFromCharacter(target.model)
		if victim then
			Kit.screenFx:FireClient(victim, "Hacked", center, 3)
		end
	end
end

-- Вибраниевый таран: рывок, все на пути отлетают.
function Handlers.VibraniumRam(ctx)
	local range = Abilities.ById.VibraniumRam.range
	local origin = ctx.root.Position
	local direction = Kit.aimFlat(ctx)
	local targets, finish = Kit.alongLine(ctx, origin, direction, range, 5)
	for i = 1, 4 do
		task.delay(i * 0.04, function()
			Fx.afterimage(ctx.character, STEEL, 0.35)
		end)
	end
	Fx.sound("PunchFinisher", origin, 1, 0.6)
	ctx.character:PivotTo(CFrame.lookAt(finish, finish + direction))
	Fx.burst(finish, STEEL, 25, 30, "Spark")
	for _, target in targets do
		hit(ctx, target, 24)
		Damage.knockback(target.root, (direction + Vector3.new(0, 0.4, 0)).Unit * 90)
	end
end

-- Ракетный залп: шесть ракет падают на врагов в зоне прицела.
function Handlers.MissileBarrage(ctx)
	local zone = 14
	local targets = Damage.inRadius(ctx.target, zone, ctx.character)
	Fx.sound("Wave", ctx.root.Position, 0.8, 1.3)
	for i = 1, 6 do
		task.delay(i * 0.12, function()
			local target = targets[((i - 1) % math.max(#targets, 1)) + 1]
			local impact = if target
				then target.root.Position
				else ctx.target + Vector3.new(math.random(-zone, zone), 0, math.random(-zone, zone))
			local launch = ctx.root.Position + Vector3.new(0, 3, 0)
			Fx.beam(launch, impact + Vector3.new(0, 25, 0), RED, 0.4, 0.3)
			Fx.beam(impact + Vector3.new(0, 25, 0), impact, RED, 0.4, 0.2)
			task.wait(0.2)
			Fx.sphere(impact, Color3.fromRGB(255, 140, 60), 1, 8, 0.35)
			Fx.burst(impact, Color3.fromRGB(255, 140, 60), 20, 30, "Fire")
			for _, victim in Damage.inRadius(impact, 5, ctx.character) do
				hit(ctx, victim, 12)
			end
		end)
	end
end

-- Магнитный захват: притянуть всех рядом и оглушить.
function Handlers.MagneticPull(ctx)
	local radius = Abilities.ById.MagneticPull.range
	local center = ctx.root.Position
	Fx.sound("Magic", center, 1, 0.5)
	Fx.sphere(center, color("MagneticPull"), radius * 2, 2, 0.5)
	for _, target in Damage.inRadius(center, radius, ctx.character) do
		Fx.lightning(center, target.root.Position, RED, 8, 0.4)
		local pull = (center - target.root.Position) * Vector3.new(1, 0, 1)
		if pull.Magnitude > 3 then
			Damage.knockback(
				target.root,
				pull.Unit * math.min(pull.Magnitude * 3.5, 90) + Vector3.new(0, 15, 0),
				0.25
			)
		end
		Status.apply(target.humanoid, "Stun", 1)
	end
end

return { Handlers = Handlers }
