--!strict
-- Танос и Перчатка Бесконечности. Способности повторяют сцены из фильмов:
-- удар Камнем Силы, порталы, Дракс в кубах, перемотка времени как с Вижном,
-- луч Разума, луна Титана, Халкбастер в скале и, конечно, Щелчок.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Abilities = require(ReplicatedStorage.Shared.Abilities)
local Items = require(ReplicatedStorage.Shared.Items)

local Damage = require(script.Parent.Parent.Damage)
local Fx = require(script.Parent.Parent.Fx)
local Kit = require(script.Parent.Parent.Kit)
local Status = require(script.Parent.Parent.Status)
local Timeline = require(script.Parent.Parent.Timeline)

type Context = Kit.Context

local color = Kit.color
local hit = Kit.hit

local comboState: { [Player]: { count: number, last: number } } = setmetatable({}, { __mode = "k" }) :: any

local Handlers: { [string]: (Context) -> () } = {}

-- Серия из 3 ударов Перчаткой, третий сильнее и отбрасывает.
function Handlers.Punch(ctx)
	local now = os.clock()
	local state: { count: number, last: number } = comboState[ctx.player] or { count = 0, last = 0 }
	comboState[ctx.player] = state
	state.count = if now - state.last < 1 then state.count % 3 + 1 else 1
	state.last = now

	local finisher = state.count == 3
	local direction = Kit.aimFlat(ctx)
	local origin = CFrame.lookAt(ctx.root.Position, ctx.root.Position + direction)
	local hitPoint = ctx.root.Position + direction * 3.5

	Fx.slash(origin, ctx.accent, if finisher then 9 else 6, state.count == 2)
	Fx.sound(if finisher then "PunchFinisher" else "Punch", hitPoint, 0.7)

	local targets = Damage.inRadius(hitPoint, 4.5, ctx.character)
	for _, target in targets do
		hit(ctx, target, if finisher then 22 else 10, ctx.accent)
		Fx.burst(target.root.Position, ctx.accent, if finisher then 30 else 12, if finisher then 40 else 20)
		if finisher then
			Damage.knockback(target.root, direction * 70 + Vector3.new(0, 25, 0))
		end
	end
	if finisher then
		Fx.sphere(hitPoint, ctx.accent, 1, 8, 0.25)
		Fx.flash(hitPoint, ctx.accent, 14, 0.25)
	elseif #targets > 0 then
		Fx.sphere(hitPoint, ctx.accent, 1, 4, 0.2)
	end
end

-- Залп Перчатки. С Камнем Силы — фиолетовый и мощнее, как на Титане.
function Handlers.Beam(ctx)
	local powered = ctx.stones.Power == true
	local beamColor = if powered then color("PowerWave") else ctx.accent
	local origin = ctx.root.Position + Vector3.new(0, 1, 0)
	local direction = Kit.aim3D(ctx, origin) * Abilities.ById.Beam.range

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { ctx.character, Fx.Folder }

	local result = workspace:Raycast(origin, direction, params)
	local hitPosition = if result then result.Position else origin + direction
	Fx.sound("Beam", origin, 0.6)
	Fx.beam(origin, hitPosition, beamColor, if powered then 1.6 else 1.1, 0.4)
	Fx.sphere(origin, beamColor, 2, 0.5, 0.2)
	Fx.sphere(hitPosition, beamColor, 1, if powered then 8 else 6, 0.3)
	Fx.burst(hitPosition, beamColor, 20, 30)
	Fx.flash(hitPosition, beamColor, 16)

	if result then
		local target = Damage.fromPart(result.Instance, ctx.character)
		if target then
			hit(ctx, target, if powered then 26 else 20, beamColor)
		end
	end
end

-- Камень Силы: удар о землю.
function Handlers.PowerWave(ctx)
	local radius = Abilities.ById.PowerWave.range
	local center = ctx.root.Position
	local ground = center - Vector3.new(0, 2.5, 0)
	Fx.sound("Wave", center, 1)
	Fx.shockwave(ground, color("PowerWave"), radius)
	Fx.sphere(center, color("PowerWave"), 3, radius, 0.4)
	Fx.burst(center, color("PowerWave"), 60, 60)
	Fx.flash(center, color("PowerWave"), 40, 0.6)
	for _, target in Damage.inRadius(center, radius, ctx.character) do
		hit(ctx, target, 35)
		Damage.pushAway(target, center, 80, 30)
	end
end

-- Камень Пространства: портал туда и обратно.
function Handlers.SpaceWarp(ctx)
	local c = color("SpaceWarp")
	local look = Kit.aimFlat(ctx)
	Fx.sound("Teleport", ctx.root.Position, 0.8, 0.8)
	Fx.portal(ctx.root.Position, look, c, 3.5, 0.7)
	Fx.burst(ctx.root.Position, c, 30, 20)
	Fx.afterimage(ctx.character, c, 0.6)
	Kit.teleport(ctx, ctx.target)
	local arrival = ctx.target + Vector3.new(0, 3, 0)
	Fx.sound("Teleport", arrival, 0.8, 1.3)
	Fx.portal(arrival, look, c, 3.5, 0.8)
	Fx.burst(arrival, c, 40, 30)
	Fx.flash(arrival, c, 20)
end

-- Камень Реальности: враги рассыпаются на кубы (как Дракс на Забвении).
function Handlers.RealityWarp(ctx)
	local radius = 10
	local duration = 2.5
	local c = color("RealityWarp")
	Fx.sound("Magic", ctx.target, 0.9, 0.7)
	Fx.sphere(ctx.target, c, 2, radius * 2, 0.5)
	Fx.ring(ctx.target, c, radius, 0.5)
	Fx.burst(ctx.target, c, 50, 35, "Fire")
	for _, target in Damage.inRadius(ctx.target, radius, ctx.character) do
		hit(ctx, target, 25)
		Status.apply(target.humanoid, "Stun", duration)
		Fx.cubify(target.model, c, duration)
	end
end

-- Камень Души: вытягивание здоровья.
function Handlers.SoulDrain(ctx)
	local radius = Abilities.ById.SoulDrain.range
	local c = color("SoulDrain")
	Fx.sound("Magic", ctx.root.Position, 0.9, 0.6)
	Fx.sphere(ctx.root.Position, c, radius * 2, 2, 0.5)
	Fx.ring(ctx.root.Position - Vector3.new(0, 2.5, 0), c, radius, 0.6)
	Kit.drainAll(ctx, Damage.inRadius(ctx.root.Position, radius, ctx.character), 20, c)
end

-- Перемотка времени (для Таноса и для Сдвига во времени Локи).
local function rewind(ctx: Context, seconds: number, c: Color3)
	local sample = Timeline.at(ctx.player, seconds)
	if not sample then
		return
	end
	local path = Timeline.path(ctx.player, seconds)
	-- Зелёный след от текущей точки назад по пройденному пути.
	local reversed = {}
	for i = #path, 1, -1 do
		table.insert(reversed, path[i])
	end
	table.insert(reversed, 1, ctx.root.Position)
	if #reversed >= 2 then
		Fx.branch(reversed, c, 0.5, 0.8, 0.25)
	end
	Fx.clock(ctx.root.Position, c, 6, 0.8)
	Fx.sound("Teleport", ctx.root.Position, 0.8, 0.6)

	Fx.afterimage(ctx.character, c, 0.8)
	ctx.character:PivotTo(sample.cframe)
	Damage.heal(ctx.humanoid, sample.health - ctx.humanoid.Health)
	Timeline.clear(ctx.player)

	Fx.clock(sample.cframe.Position, c, 6, 1)
	Fx.burst(sample.cframe.Position, c, 40, 20)
	Kit.screenFx:FireClient(ctx.player, "Rewind", sample.cframe.Position)
end

function Handlers.TimeRewind(ctx)
	rewind(ctx, 4, color("TimeRewind"))
end

-- Камень Разума: пробивающий луч Вижна.
function Handlers.MindBeam(ctx)
	local c = color("MindBeam")
	local origin = ctx.root.Position + Vector3.new(0, 1.5, 0)
	local direction = Kit.aim3D(ctx, origin)
	local targets, finish = Kit.alongLine(ctx, origin, direction, Abilities.ById.MindBeam.range, 3.5)
	Fx.sound("Beam", origin, 0.8, 1.4)
	Fx.beam(origin, finish, c, 2.2, 0.6)
	Fx.beam(origin, finish, Color3.new(1, 1, 1), 0.8, 0.4)
	for _ = 1, 3 do
		Fx.lightning(origin, finish, c, 12, 0.35)
	end
	Fx.flash(origin, c, 20)
	Fx.burst(finish, c, 30, 30)
	for _, target in targets do
		hit(ctx, target, 22)
		Status.apply(target.humanoid, "Stun", 1.5)
		Fx.burst(target.root.Position, c, 15, 20)
	end
end

-- Сила + Пространство: осколки луны падают на зону прицела (Титан).
function Handlers.MoonRain(ctx)
	local zone = 16
	local center = ctx.target
	Fx.ring(center, color("MoonRain"), zone, 1.6)
	Fx.sound("Wave", center, 1, 0.6)
	for i = 1, 11 do
		local offset = Vector3.new(math.random(-zone, zone), 0, math.random(-zone, zone))
		local impact = center + offset
		task.delay((i - 1) * 0.14, function()
			local fall = Fx.meteor(impact, 0.55)
			task.wait(fall)
			Fx.shockwave(impact, color("MoonRain"), 7)
			Fx.burst(impact, Color3.fromRGB(255, 140, 60), 30, 35, "Fire")
			Fx.burst(impact, Color3.fromRGB(110, 90, 80), 12, 15, "Smoke")
			Fx.flash(impact, Color3.fromRGB(255, 140, 60), 18, 0.4)
			for _, target in Damage.inRadius(impact, 6.5, ctx.character) do
				hit(ctx, target, 12)
				Damage.pushAway(target, impact, 40, 25)
			end
		end)
	end
end

-- Пространство + Реальность: враги замурованы в скалу (Халкбастер в Ваканде).
function Handlers.RockPrison(ctx)
	local radius = 10
	local duration = 3.5
	Fx.sound("Wave", ctx.target, 0.9, 0.5)
	Fx.portal(ctx.target, Kit.aimFlat(ctx), color("SpaceWarp"), 5, 0.6)
	Fx.burst(ctx.target, color("RockPrison"), 40, 30, "Smoke")
	for _, target in Damage.inRadius(ctx.target, radius, ctx.character) do
		hit(ctx, target, 15)
		Status.apply(target.humanoid, "Stun", duration)
		Fx.rockPrison(target.root.Position, duration)
	end
end

-- Душа + Разум: оглушение и вытягивание жизни у всех рядом.
function Handlers.SoulHarvest(ctx)
	local radius = Abilities.ById.SoulHarvest.range
	local c = color("SoulHarvest")
	local targets = Damage.inRadius(ctx.root.Position, radius, ctx.character)
	Fx.sound("Magic", ctx.root.Position, 1, 0.3)
	Fx.shockwave(ctx.root.Position - Vector3.new(0, 2.5, 0), c, radius)
	Fx.burst(ctx.root.Position, c, 50, 40)
	for _, target in targets do
		Status.apply(target.humanoid, "Stun", 1.5)
	end
	Kit.drainAll(ctx, targets, 25, c)
end

-- Щелчок: половина врагов в радиусе обращается в пыль.
function Handlers.Snap(ctx)
	local radius = Abilities.ById.Snap.range
	local center = ctx.root.Position
	Status.apply(ctx.humanoid, "Stun", 1.8)

	for _, player in Kit.playersNear(center, radius * 1.5) do
		Kit.screenFx:FireClient(player, "SnapCharge", center)
	end

	-- Замах: камни по очереди вспыхивают вокруг персонажа.
	for i, stone in Items.Stones do
		local angle = (i / #Items.Stones) * math.pi * 2
		local offset = Vector3.new(math.cos(angle) * 3, 2, math.sin(angle) * 3)
		Fx.sphere(ctx.root.Position + offset, stone.color, 0.5, 2.5, 1.4)
		Fx.burst(ctx.root.Position + offset, stone.color, 10, 6)
		Fx.flash(ctx.root.Position + offset, stone.color, 12, 1.2)
		task.wait(0.2)
	end
	task.wait(0.3)
	if ctx.humanoid.Health <= 0 then
		return
	end

	center = ctx.root.Position
	Fx.sound("Snap", center, 2)
	Fx.sphere(center, Color3.new(1, 1, 1), 4, radius * 2, 1.2)
	Fx.shockwave(center - Vector3.new(0, 2.5, 0), Color3.new(1, 1, 1), radius)
	Fx.flash(center, Color3.new(1, 1, 1), 60, 1.5)

	local targets = Damage.inRadius(center, radius, ctx.character)
	for i = #targets, 2, -1 do
		local j = math.random(1, i)
		targets[i], targets[j] = targets[j], targets[i]
	end
	local erased = math.ceil(#targets / 2)

	for _, player in Kit.playersNear(center, radius * 1.5) do
		Kit.screenFx:FireClient(player, "Snap", center, erased)
	end

	for i = 1, erased do
		local target = targets[i]
		local victim = game:GetService("Players"):GetPlayerFromCharacter(target.model)
		if victim then
			Kit.screenFx:FireClient(victim, "Erased", center)
		end
		task.spawn(function()
			Status.apply(target.humanoid, "Stun", 3)
			task.wait(0.4 + math.random() * 1.2)
			for _, part in target.model:GetDescendants() do
				if part:IsA("BasePart") and part.Transparency < 1 then
					Fx.dust(part.Position, 3)
					part.Transparency = 1
				elseif part:IsA("Decal") then
					part.Transparency = 1
				end
				task.wait(0.03)
			end
			hit(ctx, target, math.huge, Color3.new(1, 1, 1), true)
		end)
	end
end

-- Двуклинковый меч из «Финала»: вихрь из трёх ударов вокруг.
function Handlers.DoubleBlade(ctx)
	local radius = Abilities.ById.DoubleBlade.range
	local steel = color("DoubleBlade")
	for spin = 1, 3 do
		if ctx.humanoid.Health <= 0 then
			return
		end
		local base = ctx.root.CFrame
		for i = 0, 3 do
			Fx.slash(base * CFrame.Angles(0, i * math.pi / 2 + spin, 0), steel, 8, i % 2 == 0)
		end
		Fx.ring(ctx.root.Position - Vector3.new(0, 2, 0), steel, radius, 0.25)
		Fx.sound("Punch", ctx.root.Position, 0.7, 0.9 + spin * 0.1)
		for _, target in Damage.inRadius(ctx.root.Position, radius, ctx.character) do
			hit(ctx, target, 14, steel)
			if spin == 3 then
				Damage.pushAway(target, ctx.root.Position, 70, 25)
			end
		end
		task.wait(0.2)
	end
end

-- Ближайший враг в секторе перед героем.
local function nearestInFront(ctx: Context, range: number, angle: number): Damage.Target?
	local targets = Kit.inCone(ctx, range, angle)
	table.sort(targets, function(a, b)
		return (a.root.Position - ctx.root.Position).Magnitude
			< (b.root.Position - ctx.root.Position).Magnitude
	end)
	return targets[1]
end

-- Хватка Титана: поднять врага перед собой и швырнуть о землю.
function Handlers.TitanGrip(ctx)
	local c = color("TitanGrip")
	local target = nearestInFront(ctx, Abilities.ById.TitanGrip.range, 45)
	if not target then
		Fx.slash(ctx.root.CFrame, c, 6)
		return
	end
	Status.apply(target.humanoid, "Stun", 1.4)
	local hold = ctx.root.CFrame * CFrame.new(0, 3.5, -3.5)
	target.model:PivotTo(hold)
	Fx.burst(hold.Position, c, 20, 15)
	Fx.sound("Magic", hold.Position, 0.8, 0.6)
	task.wait(0.7)
	if target.humanoid.Health <= 0 or ctx.humanoid.Health <= 0 then
		return
	end
	local ground = ctx.root.Position + Kit.aimFlat(ctx) * 4
	target.model:PivotTo(CFrame.new(ground + Vector3.new(0, 2, 0)))
	Fx.shockwave(ground - Vector3.new(0, 2.5, 0), c, 10)
	Fx.burst(ground, Color3.fromRGB(120, 100, 90), 25, 25, "Smoke")
	Fx.sound("PunchFinisher", ground, 1, 0.7)
	hit(ctx, target, 30)
end

-- Апперкот: рывок вперёд и подброс врага.
function Handlers.HulkUppercut(ctx)
	local c = color("HulkUppercut")
	local direction = Kit.aimFlat(ctx)
	Fx.afterimage(ctx.character, c, 0.4)
	Damage.knockback(ctx.root, direction * 80, 0.15)
	task.wait(0.15)
	local point = ctx.root.Position + direction * 3.5
	Fx.slash(CFrame.lookAt(point, point + Vector3.new(0, 1, 0)), c, 8)
	Fx.sound("PunchFinisher", point, 1, 0.8)
	for _, target in Damage.inRadius(point, 5, ctx.character) do
		hit(ctx, target, 28)
		Damage.knockback(target.root, Vector3.new(0, 110, 0) + direction * 20, 0.25)
		Fx.burst(target.root.Position, c, 25, 35)
	end
end

-- Поглощение: полторы секунды неуязвимости, затем взрыв из поглощённого урона.
function Handlers.Absorb(ctx)
	local c = color("Absorb")
	local radius = Abilities.ById.Absorb.range
	local startHealth = ctx.humanoid.Health
	Status.shield(ctx.humanoid, 1.5, 1)
	local bubble = Fx.sphere(ctx.root.Position, c, 8, 9, 1.5)
	bubble.Transparency = 0.7
	Fx.sound("Magic", ctx.root.Position, 0.9, 0.5)
	-- Считаем, сколько ударов "впиталось": по числу врагов рядом и времени.
	local absorbed = 0
	for _ = 1, 6 do
		task.wait(0.25)
		absorbed += #Damage.inRadius(ctx.root.Position, radius, ctx.character) * 3
	end
	if ctx.humanoid.Health <= 0 then
		return
	end
	local power = 20 + math.min(absorbed, 40) + math.max(0, startHealth - ctx.humanoid.Health)
	Fx.shockwave(ctx.root.Position - Vector3.new(0, 2.5, 0), c, radius)
	Fx.sphere(ctx.root.Position, c, 3, radius * 1.6, 0.5)
	Fx.burst(ctx.root.Position, c, 70, 60)
	Fx.flash(ctx.root.Position, c, 40, 0.5)
	for _, target in Damage.inRadius(ctx.root.Position, radius, ctx.character) do
		hit(ctx, target, power)
		Damage.pushAway(target, ctx.root.Position, 80, 30)
	end
end

return {
	Handlers = Handlers,
	rewind = rewind,
}
