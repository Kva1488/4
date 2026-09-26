--!strict
-- Альтрон бесконечности — «Что, если…?», эпизоды 8–9.
-- Альтрон в теле Вижна, со всеми шестью Камнями Бесконечности.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Abilities = require(ReplicatedStorage.Shared.Abilities)
local Items = require(ReplicatedStorage.Shared.Items)

local Damage = require(script.Parent.Parent.Damage)
local Fx = require(script.Parent.Parent.Fx)
local Kit = require(script.Parent.Parent.Kit)
local Projectile = require(script.Parent.Parent.Projectile)
local Sentries = require(script.Parent.Parent.Sentries)
local Status = require(script.Parent.Parent.Status)
local Thanos = require(script.Parent.Thanos)

type Context = Kit.Context

local color = Kit.color
local hit = Kit.hit

local strikeIndex: { [Player]: number } = setmetatable({}, { __mode = "k" }) :: any

local Handlers: { [string]: (Context) -> () } = {}

-- Удар бесконечности: выпады и взмахи двуглавым копьём, каждый окрашен следующим камнем.
function Handlers.InfinityStrike(ctx)
	local index = (strikeIndex[ctx.player] or 0) % #Items.Stones + 1
	strikeIndex[ctx.player] = index
	local stone = Items.Stones[index]

	local direction = Kit.aimFlat(ctx)
	local origin = CFrame.lookAt(ctx.root.Position, ctx.root.Position + direction)
	local hitPoint = ctx.root.Position + direction * 5
	local thrust = index % 3 == 0
	if thrust then
		-- Выпад: копьё пронзает линию перед собой.
		Fx.beam(
			ctx.root.Position + Vector3.new(0, 0.5, 0),
			ctx.root.Position + direction * 9,
			stone.color,
			0.5,
			0.2
		)
		Fx.lightning(ctx.root.Position, ctx.root.Position + direction * 9, stone.color, 6, 0.2)
	else
		Fx.slash(origin, stone.color, 8, index % 2 == 0)
	end
	Fx.sound("Punch", hitPoint, 0.7, 0.9)
	for _, target in Damage.inRadius(hitPoint, if thrust then 6 else 5, ctx.character) do
		hit(ctx, target, 14, stone.color)
		Fx.burst(target.root.Position, stone.color, 15, 25)
	end
end

-- Залп Камня Разума: пробивающий луч.
function Handlers.MindBlast(ctx)
	local c = color("MindBlast")
	local origin = ctx.root.Position + Vector3.new(0, 1.6, 0)
	local direction = Kit.aim3D(ctx, origin)
	local targets, finish = Kit.alongLine(ctx, origin, direction, Abilities.ById.MindBlast.range, 4)
	Fx.sound("Beam", origin, 1, 0.8)
	Fx.beam(origin, finish, c, 3, 0.6)
	Fx.beam(origin, finish, Color3.new(1, 1, 1), 1.1, 0.45)
	for _ = 1, 4 do
		Fx.lightning(origin, finish, c, 14, 0.4)
	end
	Fx.flash(origin, c, 26)
	Fx.burst(finish, c, 40, 35)
	for _, target in targets do
		hit(ctx, target, 35)
		Fx.burst(target.root.Position, c, 20, 25)
	end
end

-- Прыжок между мирами (Камень Пространства).
function Handlers.MultiversePortal(ctx)
	local c = color("MultiversePortal")
	local look = Kit.aimFlat(ctx)
	Fx.portal(ctx.root.Position, look, c, 4, 0.7)
	Fx.afterimage(ctx.character, c, 0.6)
	Fx.sound("Teleport", ctx.root.Position, 0.8, 0.7)
	Kit.teleport(ctx, ctx.target)
	Fx.portal(ctx.target + Vector3.new(0, 3, 0), look, c, 4, 0.8)
	Fx.burst(ctx.target + Vector3.new(0, 3, 0), c, 40, 30)
end

-- Сверхновая Силы.
function Handlers.PowerNova(ctx)
	local radius = Abilities.ById.PowerNova.range
	local c = color("PowerNova")
	local center = ctx.root.Position
	Fx.sound("Wave", center, 1.2, 0.7)
	Fx.shockwave(center - Vector3.new(0, 2.5, 0), c, radius)
	Fx.sphere(center, c, 3, radius * 1.4, 0.5)
	Fx.burst(center, c, 90, 70)
	Fx.flash(center, c, 50, 0.7)
	for _, target in Damage.inRadius(center, radius, ctx.character) do
		hit(ctx, target, 45)
		Damage.pushAway(target, center, 110, 40)
	end
end

-- Армия Альтронов (Камень Реальности): 5 усиленных часовых.
function Handlers.UltronArmy(ctx)
	local c = color("UltronArmy")
	Fx.sphere(ctx.root.Position, c, 2, 16, 0.5)
	Fx.burst(ctx.root.Position, c, 40, 25)
	Fx.sound("Magic", ctx.root.Position, 0.9, 0.9)
	Sentries.spawn(ctx.player, function(target, damage)
		hit(ctx, target, damage)
	end, 5, 12, 9, true)
end

-- Петля времени (Камень Времени).
function Handlers.InfinityRewind(ctx)
	Thanos.rewind(ctx, 4, color("InfinityRewind"))
end

-- Жатва Камня Души.
function Handlers.SoulSiphon(ctx)
	local radius = Abilities.ById.SoulSiphon.range
	local c = color("SoulSiphon")
	Fx.sound("Magic", ctx.root.Position, 1, 0.5)
	Fx.shockwave(ctx.root.Position - Vector3.new(0, 2.5, 0), c, radius)
	Kit.drainAll(ctx, Damage.inRadius(ctx.root.Position, radius, ctx.character), 25, c)
end

-- Конец мультивселенной: волны всех шести камней и финальный белый взрыв.
function Handlers.MultiverseEnd(ctx)
	local radius = Abilities.ById.MultiverseEnd.range
	Status.apply(ctx.humanoid, "Stun", 2.4)
	for _, player in Kit.playersNear(ctx.root.Position, radius * 1.5) do
		Kit.screenFx:FireClient(player, "MultiverseEnd", ctx.root.Position)
	end
	Damage.knockback(ctx.root, Vector3.new(0, 18, 0), 0.5)

	for _, stone in Items.Stones do
		task.wait(0.3)
		if ctx.humanoid.Health <= 0 then
			return
		end
		local center = ctx.root.Position
		Fx.shockwave(center - Vector3.new(0, 2.5, 0), stone.color, radius)
		Fx.sphere(center, stone.color, 3, radius * 0.5, 0.4)
		Fx.flash(center, stone.color, 40, 0.35)
		Fx.sound("Wave", center, 0.8, 0.8 + math.random() * 0.4)
		for _, target in Damage.inRadius(center, radius, ctx.character) do
			hit(ctx, target, 10, stone.color)
			Fx.burst(target.root.Position, stone.color, 8, 15)
		end
	end

	task.wait(0.4)
	if ctx.humanoid.Health <= 0 then
		return
	end
	local center = ctx.root.Position
	Fx.sphere(center, Color3.new(1, 1, 1), 5, radius * 2, 1.2)
	Fx.shockwave(center - Vector3.new(0, 2.5, 0), Color3.new(1, 1, 1), radius)
	Fx.flash(center, Color3.new(1, 1, 1), 60, 1.5)
	Fx.burst(center, Color3.new(1, 1, 1), 120, 80)
	for _, target in Damage.inRadius(center, radius, ctx.character) do
		hit(ctx, target, 20, Color3.new(1, 1, 1))
		Damage.pushAway(target, center, 100, 50)
	end
end

-- Бросок двуглавого копья с возвратом.
function Handlers.SpearThrow(ctx)
	local gold = color("SpearThrow")
	local origin = ctx.root.Position + Vector3.new(0, 1.2, 0)
	local function spear(): BasePart
		local part = Instance.new("Part")
		part.Size = Vector3.new(0.3, 0.3, 5)
		part.Material = Enum.Material.Neon
		part.Color = gold
		return part
	end
	Fx.sound("Beam", origin, 0.7, 0.8)
	Projectile.boomerang({
		origin = origin,
		direction = Kit.aim3D(ctx, origin),
		speed = 110,
		range = Abilities.ById.SpearThrow.range,
		radius = 3,
		owner = ctx.character,
		pierce = true,
		onHit = function(target, position)
			hit(ctx, target, 30)
			Fx.burst(position, gold, 15, 30, "Spark")
		end,
	}, ctx.root, spear)
end

-- Вращение копья: 4 удара вокруг.
function Handlers.SpearVortex(ctx)
	local radius = Abilities.ById.SpearVortex.range
	local gold = color("SpearVortex")
	for spin = 1, 4 do
		if ctx.humanoid.Health <= 0 then
			return
		end
		for i = 0, 2 do
			Fx.slash(
				ctx.root.CFrame * CFrame.Angles(0, spin * 1.3 + i * 2.1, 0),
				Items.Stones[(spin + i) % 6 + 1].color,
				9,
				i % 2 == 0
			)
		end
		Fx.ring(ctx.root.Position - Vector3.new(0, 2, 0), gold, radius, 0.3)
		for _, target in Damage.inRadius(ctx.root.Position, radius, ctx.character) do
			hit(ctx, target, 9, gold)
		end
		task.wait(0.22)
	end
end

-- Переписать реальность: кубы, урон и замедление по кругу.
function Handlers.RewriteReality(ctx)
	local radius = Abilities.ById.RewriteReality.range
	local c = color("RewriteReality")
	Fx.sound("Magic", ctx.root.Position, 1, 0.6)
	Fx.sphere(ctx.root.Position, c, 3, radius * 2, 0.5)
	Fx.burst(ctx.root.Position, c, 60, 40, "Fire")
	for _, target in Damage.inRadius(ctx.root.Position, radius, ctx.character) do
		hit(ctx, target, 25)
		Status.apply(target.humanoid, "Slow", 3, 0.4)
		Fx.cubify(target.model, c, 2)
	end
end

-- Разрез Разума: широкая жёлтая волна перед собой.
function Handlers.MindCleave(ctx)
	local range = Abilities.ById.MindCleave.range
	local c = color("MindCleave")
	local forward = Kit.aimFlat(ctx)
	local origin = CFrame.lookAt(ctx.root.Position, ctx.root.Position + forward)
	Fx.sound("Beam", ctx.root.Position, 1, 0.6)
	for step = 1, 5 do
		task.delay(step * 0.04, function()
			Fx.slash(origin * CFrame.new(0, 0, -step * range / 6), c, 10 + step * 2, false)
		end)
	end
	Fx.flash(ctx.root.Position, c, 30, 0.4)
	for _, target in Kit.inCone(ctx, range, 35) do
		hit(ctx, target, 45)
		Fx.burst(target.root.Position, c, 25, 30, "Spark")
	end
end

-- Гибель миров: дождь обломков.
function Handlers.WorldsEnd(ctx)
	local zone = 22
	local c = color("WorldsEnd")
	Fx.ring(ctx.target, c, zone, 2.5)
	Fx.sound("Wave", ctx.target, 1.2, 0.5)
	for i = 1, 14 do
		task.delay(i * 0.12, function()
			local impact = ctx.target + Vector3.new(math.random(-zone, zone), 0, math.random(-zone, zone))
			local fall = Fx.meteor(impact, 0.5)
			task.wait(fall)
			Fx.shockwave(impact, c, 6)
			Fx.burst(impact, Items.Stones[i % 6 + 1].color, 20, 30)
			for _, target in Damage.inRadius(impact, 6, ctx.character) do
				hit(ctx, target, 11)
			end
		end)
	end
end

-- Удар сквозь портал: за спину ближайшего врага и удар копьём.
function Handlers.PortalStrike(ctx)
	local c = color("PortalStrike")
	local targets = Damage.inRadius(ctx.target, 25, ctx.character)
	table.sort(targets, function(a, b)
		return (a.root.Position - ctx.target).Magnitude < (b.root.Position - ctx.target).Magnitude
	end)
	local target = targets[1]
	if not target then
		return
	end
	Fx.portal(ctx.root.Position, Kit.aimFlat(ctx), c, 3.5, 0.5)
	Fx.afterimage(ctx.character, c, 0.5)
	local behind = target.root.CFrame * CFrame.new(0, 0, 4)
	ctx.character:PivotTo(CFrame.lookAt(behind.Position, target.root.Position))
	Fx.portal(behind.Position, target.root.CFrame.LookVector, c, 3.5, 0.6)
	task.wait(0.1)
	Fx.beam(ctx.root.Position, target.root.Position, color("SpearThrow"), 0.5, 0.25)
	Fx.slash(CFrame.lookAt(ctx.root.Position, target.root.Position), color("SpearThrow"), 8)
	hit(ctx, target, 40)
	Damage.pushAway(target, ctx.root.Position, 70, 25)
end

return { Handlers = Handlers }
