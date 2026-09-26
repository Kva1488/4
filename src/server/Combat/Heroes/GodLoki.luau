--!strict
-- Локи, бог времени — финал 2 сезона сериала «Локи» («Славная цель»).
-- Он управляет сдвигами во времени, умеет ставить время на паузу,
-- держит ветви мультивселенной и выращивает из них Иггдрасиль.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Abilities = require(ReplicatedStorage.Shared.Abilities)

local Damage = require(script.Parent.Parent.Damage)
local Fx = require(script.Parent.Parent.Fx)
local Kit = require(script.Parent.Parent.Kit)
local Projectile = require(script.Parent.Parent.Projectile)
local Status = require(script.Parent.Parent.Status)
local Thanos = require(script.Parent.Thanos)

type Context = Kit.Context

local hit = Kit.hit

local GREEN = Color3.fromRGB(110, 255, 150)
local DEEP = Color3.fromRGB(40, 190, 90)

local Handlers: { [string]: (Context) -> () } = {}

-- Нить времени: хлыст к первой цели в секторе, подтягивает её к Локи.
function Handlers.TimeThread(ctx)
	local range = Abilities.ById.TimeThread.range
	local hand = ctx.root.Position + Vector3.new(0, 1, 0)
	local targets = Kit.inCone(ctx, range, 30)
	table.sort(targets, function(a, b)
		return (a.root.Position - ctx.root.Position).Magnitude
			< (b.root.Position - ctx.root.Position).Magnitude
	end)
	local target = targets[1]
	local tip = if target then target.root.Position else hand + Kit.aimFlat(ctx) * range
	Fx.branch(Fx.arc(hand, tip, 2, 6), GREEN, 0.35, 0.25, 0.1)
	Fx.sound("Punch", hand, 0.5, 0.8)
	if target then
		hit(ctx, target, 14)
		Fx.burst(target.root.Position, GREEN, 14, 18)
		local pull = (ctx.root.Position - target.root.Position) * Vector3.new(1, 0, 1)
		if pull.Magnitude > 4 then
			Damage.knockback(target.root, pull.Unit * 45 + Vector3.new(0, 12, 0), 0.18)
		end
	end
end

-- Ветвь: пробивающий сгусток времени.
function Handlers.BranchBolt(ctx)
	local origin = ctx.root.Position + Vector3.new(0, 1, 0)
	local orb = Instance.new("Part")
	orb.Shape = Enum.PartType.Ball
	orb.Size = Vector3.one * 1.4
	orb.Material = Enum.Material.Neon
	orb.Color = GREEN
	local light = Instance.new("PointLight")
	light.Color = GREEN
	light.Range = 12
	light.Brightness = 3
	light.Parent = orb
	Fx.sound("Beam", origin, 0.5, 1.5)
	Projectile.fire({
		origin = origin,
		direction = Kit.aim3D(ctx, origin),
		speed = 110,
		range = Abilities.ById.BranchBolt.range,
		radius = 3,
		owner = ctx.character,
		pierce = true,
		visual = orb,
		onHit = function(target, position)
			hit(ctx, target, 22)
			Fx.burst(position, GREEN, 18, 20)
		end,
		onEnd = function(position)
			Fx.sphere(position, GREEN, 1, 5, 0.3)
			Fx.burst(position, GREEN, 12, 15)
		end,
	})
end

-- Сдвиг во времени: вернуться туда, где был 3 секунды назад.
function Handlers.Timeslip(ctx)
	Thanos.rewind(ctx, 3, GREEN)
end

-- Остановка времени: все враги в радиусе застывают.
function Handlers.TimePause(ctx)
	local radius = Abilities.ById.TimePause.range
	local duration = 3.5
	local center = ctx.root.Position
	Fx.sound("Magic", center, 1, 0.4)
	Fx.clock(center, GREEN, radius * 0.6, 1.5)
	local dome = Fx.sphere(center, GREEN, 2, radius * 2, 0.8)
	dome.Transparency = 0.7
	for _, target in Damage.inRadius(center, radius, ctx.character) do
		Status.apply(target.humanoid, "Stun", duration)
		Fx.clock(target.root.Position + Vector3.new(0, 1, 0), GREEN, 3, duration)
		local victim = Players:GetPlayerFromCharacter(target.model)
		if victim then
			Kit.screenFx:FireClient(victim, "TimePaused", center, duration)
		end
	end
end

-- Ветви Иггдрасиля: оплетают и поднимают врагов.
function Handlers.YggdrasilBranches(ctx)
	local radius = 14
	local center = ctx.target
	Fx.sound("Magic", center, 1, 0.5)
	Fx.ring(center, DEEP, radius, 0.8)
	Fx.burst(center, GREEN, 40, 25)
	-- Декоративные ветви, вырастающие из земли.
	for i = 1, 7 do
		local angle = (i / 7) * math.pi * 2
		local root = center + Vector3.new(math.cos(angle) * radius * 0.8, -1, math.sin(angle) * radius * 0.8)
		local top = center
			+ Vector3.new(
				math.cos(angle) * radius * 0.3,
				10 + math.random() * 5,
				math.sin(angle) * radius * 0.3
			)
		Fx.branch(Fx.arc(root, top, 3, 6), GREEN, 0.7, 2.5, 0.35)
	end
	for _, target in Damage.inRadius(center, radius, ctx.character) do
		hit(ctx, target, 25)
		Status.apply(target.humanoid, "Stun", 2.5)
		Damage.knockback(target.root, Vector3.new(0, 55, 0), 0.25)
		local below = target.root.Position - Vector3.new(0, 3, 0)
		Fx.branch(
			Fx.arc(below + Vector3.new(2, -1, 0), target.root.Position + Vector3.new(0, 7, 0), 2, 5),
			GREEN,
			0.5,
			2.5,
			0.25
		)
		Fx.branch(
			Fx.arc(below + Vector3.new(-2, -1, 1), target.root.Position + Vector3.new(0, 7, 0), 2, 5),
			DEEP,
			0.5,
			2.5,
			0.25
		)
	end
end

-- Дверь TVA: проход через временную дверь TemPad.
function Handlers.TemPadDoor(ctx)
	local look = Kit.aimFlat(ctx)
	Fx.door(ctx.root.Position + look * 2, look, 1.2)
	Fx.sound("Teleport", ctx.root.Position, 0.8, 0.7)
	task.wait(0.15)
	if ctx.humanoid.Health <= 0 then
		return
	end
	Fx.afterimage(ctx.character, Color3.fromRGB(255, 170, 70), 0.6)
	Kit.teleport(ctx, ctx.target)
	Fx.door(ctx.target + Vector3.new(0, 2, 0) - look * 1.5, look, 1.2)
	Fx.burst(ctx.target + Vector3.new(0, 3, 0), Color3.fromRGB(255, 170, 70), 30, 20)
end

-- Процедурное древо: ствол и ветви, раскинутые вверх и в стороны.
local function growTree(base: Vector3, height: number, spread: number)
	local top = base + Vector3.new(0, height, 0)
	Fx.branch(Fx.arc(base - Vector3.new(0, 3, 0), top, 1.5, 8), GREEN, 2.2, 5, 0.8)
	for i = 1, 8 do
		local angle = (i / 8) * math.pi * 2 + math.random() * 0.3
		local start = base + Vector3.new(0, height * (0.45 + math.random() * 0.4), 0)
		local tip = start + Vector3.new(math.cos(angle) * spread, height * 0.35, math.sin(angle) * spread)
		task.delay(0.5 + i * 0.05, function()
			Fx.branch(Fx.arc(start, tip, spread * 0.25, 7), GREEN, 1.1, 4.3, 0.6)
			-- Каждая ветка ветвится ещё раз.
			for _ = 1, 2 do
				local twigTip = tip
					+ Vector3.new(
						math.random(-spread, spread) * 0.4,
						math.random() * 8,
						math.random(-spread, spread) * 0.4
					)
				task.delay(0.6, function()
					Fx.branch(Fx.arc(tip, twigTip, 3, 4), DEEP, 0.5, 3.6, 0.4)
					Fx.sphere(twigTip, GREEN, 0.5, 3, 3.5).Transparency = 0.3
				end)
			end
		end)
	end
end

-- Ультимейт «Славная цель»: Локи поднимается, вырастает Иггдрасиль, ветви хватают всех врагов.
function Handlers.GloriousPurpose(ctx)
	local radius = Abilities.ById.GloriousPurpose.range
	local center = ctx.root.Position
	Status.apply(ctx.humanoid, "Stun", 2.2)

	for _, player in Kit.playersNear(center, radius * 1.6) do
		Kit.screenFx:FireClient(player, "GloriousPurpose", center)
	end

	-- Локи медленно поднимается над землёй.
	Damage.knockback(ctx.root, Vector3.new(0, 22, 0), 0.6)
	Fx.clock(center, GREEN, 10, 2)
	Fx.sound("Magic", center, 1.2, 0.3)
	task.wait(0.6)
	if ctx.humanoid.Health <= 0 then
		return
	end

	growTree(center - Vector3.new(0, 3, 0), 38, 24)
	Fx.shockwave(center - Vector3.new(0, 3, 0), GREEN, radius)
	Fx.flash(center, GREEN, 60, 2)
	Fx.burst(center, GREEN, 120, 60)

	task.wait(0.5)
	for _, target in Damage.inRadius(center, radius, ctx.character) do
		local grab = target.root.Position
		Fx.branch(Fx.arc(center - Vector3.new(0, 3, 0), grab, 10, 10), GREEN, 0.8, 3.5, 0.5)
		task.delay(0.5, function()
			if target.humanoid.Health <= 0 then
				return
			end
			hit(ctx, target, 60)
			Status.apply(target.humanoid, "Stun", 4)
			local pull = (center - target.root.Position) * Vector3.new(1, 0, 1)
			local horizontal = if pull.Magnitude > 1
				then pull.Unit * math.min(pull.Magnitude * 1.2, 60)
				else Vector3.zero
			Damage.knockback(target.root, horizontal + Vector3.new(0, 45, 0), 0.3)
			Fx.clock(target.root.Position, GREEN, 3, 4)
			Fx.burst(target.root.Position, GREEN, 25, 25)
		end)
	end
end

-- Обрезка: дубинка TVA выбрасывает ближайшего врага в прицеле в случайную точку карты.
function Handlers.Prune(ctx)
	local orange = Color3.fromRGB(255, 150, 50)
	local range = Abilities.ById.Prune.range
	local targets = Kit.inCone(ctx, range, 25)
	table.sort(targets, function(a, b)
		return (a.root.Position - ctx.root.Position).Magnitude
			< (b.root.Position - ctx.root.Position).Magnitude
	end)
	local target = targets[1]
	local hand = ctx.root.Position + Vector3.new(0, 1, 0)
	Fx.sound("Beam", hand, 0.8, 1.3)
	if not target then
		Fx.lightning(hand, hand + Kit.aimFlat(ctx) * range, orange, 8, 0.3)
		return
	end
	Fx.lightning(hand, target.root.Position, orange, 10, 0.35)
	Fx.door(target.root.Position - Vector3.new(0, 2, 0), Kit.aimFlat(ctx), 0.8)
	Fx.afterimage(target.model, orange, 0.8)
	hit(ctx, target, 40, orange)
	-- Игроков TVA действительно "обрезает" — выбрасывает далеко. Манекены остаются на месте.
	if Players:GetPlayerFromCharacter(target.model) and target.humanoid.Health > 0 then
		local angle = math.random() * math.pi * 2
		local distance = 60 + math.random() * 140
		local spot = Vector3.new(math.cos(angle) * distance, 6, math.sin(angle) * distance)
		target.model:PivotTo(CFrame.new(spot))
		Fx.door(spot - Vector3.new(0, 3, 0), Vector3.new(0, 0, -1), 1)
	end
end

return { Handlers = Handlers }
