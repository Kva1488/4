--!strict
-- Три Тора:
-- • Тор с Мьёльниром («Мстители», «Рагнарёк»);
-- • Тор с Громсекирой («Война бесконечности»);
-- • Тор с молотом и топором (финальная битва «Финала»).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Abilities = require(ReplicatedStorage.Shared.Abilities)

local Damage = require(script.Parent.Parent.Damage)
local Fx = require(script.Parent.Parent.Fx)
local Kit = require(script.Parent.Parent.Kit)
local Projectile = require(script.Parent.Parent.Projectile)
local Status = require(script.Parent.Parent.Status)

type Context = Kit.Context

local hit = Kit.hit

local THUNDER = Color3.fromRGB(140, 205, 255)
local WHITE = Color3.new(1, 1, 1)
local STEEL = Color3.fromRGB(150, 155, 165)
local BIFROST = Color3.fromRGB(255, 170, 240)
local STAR = Color3.fromRGB(255, 170, 70)
local AWAKENING_TIME = 6

local combo: { [Player]: { count: number, last: number } } = setmetatable({}, { __mode = "k" }) :: any

local function nextCombo(player: Player, window: number): number
	local now = os.clock()
	local state: { count: number, last: number } = combo[player] or { count = 0, last = 0 }
	combo[player] = state
	state.count = if now - state.last < window then state.count % 3 + 1 else 1
	state.last = now
	return state.count
end

-- Ближний удар оружием: дуга, попадания в точке перед героем, на третьем ударе — молния и отбрасывание.
local function melee(
	ctx: Context,
	damage: number,
	heavyDamage: number,
	reach: number,
	color: Color3,
	heavyEffect: ((Vector3) -> ())?
)
	local count = nextCombo(ctx.player, 1.1)
	local heavy = count == 3
	local direction = Kit.aimFlat(ctx)
	local origin = CFrame.lookAt(ctx.root.Position, ctx.root.Position + direction)
	local hitPoint = ctx.root.Position + direction * reach
	Fx.slash(origin, color, if heavy then 9 else 6.5, count == 2)
	Fx.sound(if heavy then "PunchFinisher" else "Punch", hitPoint, 0.8, 0.8)
	if heavy then
		Fx.lightning(hitPoint + Vector3.new(0, 12, 0), hitPoint, THUNDER, 8, 0.25)
		Fx.flash(hitPoint, THUNDER, 20, 0.3)
		if heavyEffect then
			heavyEffect(hitPoint)
		end
	end
	for _, target in Damage.inRadius(hitPoint, reach, ctx.character) do
		hit(ctx, target, if heavy then heavyDamage else damage, if heavy then THUNDER else color)
		if heavy then
			Damage.knockback(target.root, direction * 75 + Vector3.new(0, 30, 0))
		end
	end
end

-- Модели брошенного оружия.
local function mjolnirVisual(): BasePart
	local head = Instance.new("Part")
	head.Size = Vector3.new(0.9, 0.6, 0.6)
	head.Material = Enum.Material.Metal
	head.Color = STEEL
	local light = Instance.new("PointLight")
	light.Color = THUNDER
	light.Range = 10
	light.Brightness = 2
	light.Parent = head
	return head
end

local function stormbreakerVisual(): BasePart
	local blade = Instance.new("Part")
	blade.Size = Vector3.new(1.4, 0.2, 1.4)
	blade.Material = Enum.Material.Neon
	blade.Color = THUNDER
	local light = Instance.new("PointLight")
	light.Color = THUNDER
	light.Range = 12
	light.Brightness = 3
	light.Parent = blade
	return blade
end

-- Бросок с возвратом.
local function throwWeapon(
	ctx: Context,
	damage: number,
	range: number,
	makeVisual: () -> BasePart,
	pierce: boolean
)
	local origin = ctx.root.Position + Vector3.new(0, 1.2, 0)
	Fx.sound("Beam", origin, 0.6, 0.7)
	Projectile.boomerang(
		{
			origin = origin,
			direction = Kit.aim3D(ctx, origin),
			speed = 95,
			range = range,
			radius = 3,
			owner = ctx.character,
			pierce = pierce,
			onHit = function(target, position)
				hit(ctx, target, damage)
				Fx.lightning(position + Vector3.new(0, 6, 0), position, THUNDER, 5, 0.2)
			end,
			onEnd = function(position)
				Fx.burst(position, THUNDER, 20, 30, "Spark")
			end,
		},
		ctx.root,
		makeVisual,
		function()
			if ctx.root.Parent then
				Fx.flash(ctx.root.Position, THUNDER, 12, 0.3)
			end
		end
	)
end

-- Удар молнии с неба в точку.
local function strike(ctx: Context, position: Vector3, damage: number, radius: number, stun: number?)
	Fx.lightningStrike(position, THUNDER)
	Fx.sound("Beam", position, 1, 0.5)
	for _, target in Damage.inRadius(position, radius, ctx.character) do
		hit(ctx, target, damage)
		if stun then
			Status.apply(target.humanoid, "Stun", stun)
		end
	end
end

-- Волна молний от удара о землю.
local function groundSlam(ctx: Context, center: Vector3, radius: number, damage: number)
	Fx.sound("Wave", center, 1, 0.8)
	Fx.shockwave(center, THUNDER, radius)
	Fx.burst(center, THUNDER, 60, 55, "Spark")
	Fx.flash(center, THUNDER, 40, 0.5)
	for i = 1, 8 do
		local angle = (i / 8) * math.pi * 2
		Fx.lightning(
			center,
			center + Vector3.new(math.cos(angle) * radius, 0.5, math.sin(angle) * radius),
			THUNDER,
			6,
			0.3
		)
	end
	for _, target in Damage.inRadius(center, radius, ctx.character) do
		hit(ctx, target, damage)
		Damage.pushAway(target, center, 70, 35)
	end
end

-- Прыжок: вверх, затем падение в точку с ударом о землю.
local function leap(ctx: Context, target: Vector3, damage: number, radius: number)
	Damage.knockback(ctx.root, Vector3.new(0, 90, 0), 0.25)
	Fx.burst(ctx.root.Position, THUNDER, 25, 25, "Spark")
	task.wait(0.45)
	if ctx.humanoid.Health <= 0 then
		return
	end
	Fx.afterimage(ctx.character, THUNDER, 0.4)
	Kit.teleport(ctx, target + Vector3.new(0, 10, 0))
	task.wait(0.1)
	Damage.knockback(ctx.root, Vector3.new(0, -160, 0), 0.15)
	task.wait(0.15)
	groundSlam(ctx, ctx.target, radius, damage)
end

-- Перенос по Биврёсту.
local function bifrostTravel(ctx: Context, damage: number)
	local from = ctx.root.Position
	Fx.bifrost(from, 0.8)
	Fx.afterimage(ctx.character, BIFROST, 0.6)
	Fx.sound("Teleport", from, 1, 0.6)
	task.wait(0.2)
	if ctx.humanoid.Health <= 0 then
		return
	end
	Kit.teleport(ctx, ctx.target)
	Fx.bifrost(ctx.target, 1.2)
	for _, target in Damage.inRadius(ctx.target, 12, ctx.character) do
		hit(ctx, target, damage, BIFROST)
		Damage.pushAway(target, ctx.target, 60, 30)
	end
end

-- Пробуждение («Рагнарёк»): светящиеся глаза, удары сильнее и бьют цепной молнией (см. Kit.hit).
local function awaken(ctx: Context, duration: number)
	ctx.character:SetAttribute("EmpoweredUntil", os.clock() + duration)
	Fx.lightningStrike(ctx.root.Position - Vector3.new(0, 3, 0), THUNDER, 60)
	Fx.sound("Magic", ctx.root.Position, 1, 0.6)
	local attachment = Instance.new("Attachment")
	attachment.Name = "ThunderAura"
	attachment.Parent = ctx.root
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = "rbxasset://textures/particles/fire_sparks_main.dds"
	sparks.Color = ColorSequence.new(WHITE, THUNDER)
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new(0.4, 0)
	sparks.Lifetime = NumberRange.new(0.2, 0.5)
	sparks.Speed = NumberRange.new(4, 10)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Rate = 40
	sparks.Parent = attachment
	local light = Instance.new("PointLight")
	light.Color = THUNDER
	light.Range = 14
	light.Brightness = 2
	light.Parent = attachment
	Kit.screenFx:FireClient(ctx.player, "Thunder", ctx.root.Position, "Пробуждение")
	task.delay(duration, function()
		attachment:Destroy()
	end)
end

local Handlers: { [string]: (Context) -> () } = {}

---------------------------------------------------------------- ТОР С МЬЁЛЬНИРОМ

function Handlers.MjolnirStrike(ctx)
	melee(ctx, 12, 26, 4.5, STEEL)
end

function Handlers.MjolnirThrow(ctx)
	throwWeapon(ctx, 20, Abilities.ById.MjolnirThrow.range, mjolnirVisual, true)
end

function Handlers.LightningCall(ctx)
	strike(ctx, ctx.target, 30, 9, 1)
end

-- Полёт на молоте: раскрутка и рывок, за собой — молнии.
function Handlers.MjolnirFlight(ctx)
	local direction = Kit.aim3D(ctx, ctx.root.Position)
	local velocity = Kit.aimFlat(ctx) * 120 + Vector3.new(0, math.clamp(direction.Y, -0.2, 0.7) * 100 + 35, 0)
	Fx.ring(ctx.root.Position, THUNDER, 5, 0.3)
	Damage.knockback(ctx.root, velocity, 0.35)
	for i = 1, 5 do
		task.delay(i * 0.07, function()
			if ctx.root.Parent then
				Fx.afterimage(ctx.character, THUNDER, 0.3)
				Fx.burst(ctx.root.Position, THUNDER, 8, 10, "Spark")
			end
		end)
	end
end

function Handlers.ThunderSlam(ctx)
	groundSlam(ctx, ctx.root.Position - Vector3.new(0, 2.5, 0), Abilities.ById.ThunderSlam.range, 35)
end

function Handlers.Awakening(ctx)
	awaken(ctx, AWAKENING_TIME)
end

-- Бог грома: взлёт и шторм молний по всем врагам вокруг.
function Handlers.GodOfThunder(ctx)
	local radius = Abilities.ById.GodOfThunder.range
	Status.apply(ctx.humanoid, "Stun", 2.5)
	for _, player in Kit.playersNear(ctx.root.Position, radius * 1.5) do
		Kit.screenFx:FireClient(player, "Thunder", ctx.root.Position, "Бог грома")
	end
	Damage.knockback(ctx.root, Vector3.new(0, 30, 0), 0.6)
	ctx.character:SetAttribute("EmpoweredUntil", os.clock() + 3)
	task.wait(0.6)
	for wave = 1, 4 do
		if ctx.humanoid.Health <= 0 then
			return
		end
		local center = ctx.root.Position
		for _, target in Damage.inRadius(center, radius, ctx.character) do
			Fx.lightning(center, target.root.Position, THUNDER, 10, 0.3)
			strike(ctx, target.root.Position, 12, 4)
		end
		Fx.flash(center, THUNDER, 60, 0.3)
		task.wait(0.45 - wave * 0.05)
	end
end

---------------------------------------------------------------- ТОР С ГРОМСЕКИРОЙ

function Handlers.AxeCleave(ctx)
	melee(ctx, 14, 30, 5, STEEL, function(point)
		-- Третий удар раскалывает землю.
		Fx.ring(point, THUNDER, 8, 0.4)
		Fx.burst(point, Color3.fromRGB(120, 100, 90), 20, 20, "Smoke")
	end)
end

function Handlers.StormbreakerThrow(ctx)
	throwWeapon(ctx, 24, Abilities.ById.StormbreakerThrow.range, stormbreakerVisual, true)
end

function Handlers.BifrostArrival(ctx)
	bifrostTravel(ctx, 25)
end

-- Конус молний из топора.
function Handlers.StormCone(ctx)
	local range = Abilities.ById.StormCone.range
	local origin = ctx.root.Position + Vector3.new(0, 1, 0)
	local forward = Kit.aimFlat(ctx)
	local right = CFrame.lookAt(Vector3.zero, forward).RightVector
	Fx.sound("Beam", origin, 1, 0.6)
	for i = -3, 3 do
		local tip = origin + forward * range + right * (i * range * 0.1)
		Fx.lightning(origin, tip, THUNDER, 9, 0.35)
	end
	Fx.flash(origin, THUNDER, 30, 0.4)
	for _, target in Kit.inCone(ctx, range, 30) do
		hit(ctx, target, 32)
		Status.apply(target.humanoid, "Stun", 0.6)
	end
end

function Handlers.ThunderLeap(ctx)
	leap(ctx, ctx.target, 38, 14)
end

-- Сердце звезды: лечение и огонь вокруг, как в кузнице Нидавеллира.
function Handlers.NidavellirForge(ctx)
	local radius = Abilities.ById.NidavellirForge.range
	local center = ctx.root.Position
	Fx.pillar(center - Vector3.new(0, 3, 0), STAR, 70, 1)
	Fx.sphere(center, STAR, 3, radius * 2, 0.6)
	Fx.burst(center, STAR, 60, 40, "Fire")
	Fx.sound("Magic", center, 1, 0.5)
	Damage.heal(ctx.humanoid, 40)
	for _, target in Damage.inRadius(center, radius, ctx.character) do
		hit(ctx, target, 22, STAR)
	end
end

-- «Дайте мне Таноса!»: заряженный бросок сквозь всех на линии.
function Handlers.BringMeThanos(ctx)
	local range = Abilities.ById.BringMeThanos.range
	for _, player in Kit.playersNear(ctx.root.Position, 150) do
		Kit.screenFx:FireClient(player, "Thunder", ctx.root.Position, "Дайте мне Таноса!")
	end
	Status.apply(ctx.humanoid, "Stun", 0.9)
	Fx.lightningStrike(ctx.root.Position, THUNDER, 70)
	Fx.bifrost(ctx.root.Position, 0.8)
	task.wait(0.8)
	if ctx.humanoid.Health <= 0 then
		return
	end
	local origin = ctx.root.Position + Vector3.new(0, 1.2, 0)
	local direction = Kit.aim3D(ctx, origin)
	local targets, finish = Kit.alongLine(ctx, origin, direction, range, 5)
	Fx.beam(origin, finish, THUNDER, 3.5, 0.6)
	Fx.beam(origin, finish, BIFROST, 1.5, 0.5)
	for _ = 1, 4 do
		Fx.lightning(origin, finish, THUNDER, 16, 0.45)
	end
	Fx.lightningStrike(finish, THUNDER)
	Fx.sound("Wave", finish, 1.2, 0.6)
	for _, target in targets do
		hit(ctx, target, 70)
		Damage.knockback(target.root, direction * 90 + Vector3.new(0, 30, 0))
	end
end

---------------------------------------------------------------- ТОР: МОЛОТ И ТОПОР

-- Удары по очереди молотом и топором, каждый третий — двойной.
function Handlers.DualStrike(ctx)
	melee(ctx, 13, 34, 5, THUNDER, function(point)
		Fx.lightning(point + Vector3.new(4, 12, 0), point, WHITE, 8, 0.25)
		Fx.ring(point, THUNDER, 9, 0.4)
	end)
end

function Handlers.DualThrow(ctx)
	throwWeapon(ctx, 18, Abilities.ById.DualThrow.range, mjolnirVisual, true)
	task.wait(0.12)
	throwWeapon(ctx, 18, Abilities.ById.DualThrow.range, stormbreakerVisual, true)
end

-- Гроза: три молнии подряд по зоне.
function Handlers.StormCall(ctx)
	local center = ctx.target
	for i = 1, 3 do
		local offset = Vector3.new(math.random(-6, 6), 0, math.random(-6, 6))
		strike(ctx, center + offset, 18, 8, if i == 3 then 1.2 else nil)
		task.wait(0.25)
	end
end

function Handlers.BothBifrost(ctx)
	bifrostTravel(ctx, 30)
end

-- Возвращение Мьёльнира: молот летит к Тору и тащит врагов по пути.
function Handlers.MjolnirRecall(ctx)
	local range = Abilities.ById.MjolnirRecall.range
	local start = ctx.root.Position + Kit.aimFlat(ctx) * range + Vector3.new(0, 1, 0)
	Fx.lightningStrike(start - Vector3.new(0, 1, 0), THUNDER, 50)
	Projectile.fire({
		origin = start,
		direction = (ctx.root.Position - start).Unit,
		speed = 110,
		range = (ctx.root.Position - start).Magnitude,
		radius = 4,
		owner = ctx.character,
		pierce = true,
		visual = mjolnirVisual(),
		onHit = function(target)
			hit(ctx, target, 20)
			local pull = (ctx.root.Position - target.root.Position) * Vector3.new(1, 0, 1)
			if pull.Magnitude > 3 then
				Damage.knockback(target.root, pull.Unit * 70 + Vector3.new(0, 15, 0), 0.2)
			end
		end,
	})
end

function Handlers.DoubleSlam(ctx)
	local center = ctx.root.Position - Vector3.new(0, 2.5, 0)
	groundSlam(ctx, center, Abilities.ById.DoubleSlam.range, 25)
	task.wait(0.3)
	if ctx.humanoid.Health > 0 then
		groundSlam(ctx, ctx.root.Position - Vector3.new(0, 2.5, 0), Abilities.ById.DoubleSlam.range * 1.3, 20)
	end
end

-- Гнев Асгарда: сплошной луч молний из молота и топора и шторм вокруг.
function Handlers.AsgardWrath(ctx)
	local range = Abilities.ById.AsgardWrath.range
	for _, player in Kit.playersNear(ctx.root.Position, 150) do
		Kit.screenFx:FireClient(player, "Thunder", ctx.root.Position, "Гнев Асгарда")
	end
	Status.apply(ctx.humanoid, "Stun", 2.8)
	Damage.knockback(ctx.root, Vector3.new(0, 20, 0), 0.5)
	ctx.character:SetAttribute("EmpoweredUntil", os.clock() + 3)
	task.wait(0.5)
	for tick = 1, 8 do
		if ctx.humanoid.Health <= 0 then
			return
		end
		local origin = ctx.root.Position + Vector3.new(0, 1.5, 0)
		local direction = Kit.aim3D(ctx, origin)
		local targets, finish = Kit.alongLine(ctx, origin, direction, range, 5)
		Fx.beam(origin, finish, THUNDER, 3, 0.25)
		Fx.lightning(origin, finish, WHITE, 14, 0.25)
		Fx.lightning(origin, finish, THUNDER, 14, 0.25)
		for _, target in targets do
			hit(ctx, target, 9)
		end
		-- Шторм вокруг Тора.
		if tick % 2 == 0 then
			local around = ctx.root.Position + Vector3.new(math.random(-25, 25), -3, math.random(-25, 25))
			strike(ctx, around, 12, 8)
		end
		task.wait(0.22)
	end
end

---------------------------------------------------------------- НОВЫЕ СПОСОБНОСТИ (E)

-- Вращение молота: щит на 2.5 секунды и удары по всем рядом.
function Handlers.HammerSpin(ctx)
	local radius = Abilities.ById.HammerSpin.range
	Status.shield(ctx.humanoid, 2.5, 0.7)
	Fx.sound("Wave", ctx.root.Position, 0.6, 1.4)
	for tick = 1, 5 do
		if ctx.humanoid.Health <= 0 then
			return
		end
		local center = ctx.root.Position
		Fx.ring(center, THUNDER, radius, 0.4)
		for i = 0, 2 do
			Fx.slash(ctx.root.CFrame * CFrame.Angles(0, tick + i * 2.1, 0), STEEL, 6, i % 2 == 0)
		end
		for _, target in Damage.inRadius(center, radius, ctx.character) do
			hit(ctx, target, 6)
		end
		task.wait(0.5)
	end
end

-- Громовой рывок сквозь врагов.
function Handlers.ThunderDash(ctx)
	local range = Abilities.ById.ThunderDash.range
	local origin = ctx.root.Position
	local direction = Kit.aimFlat(ctx)
	local targets, finish = Kit.alongLine(ctx, origin, direction, range, 5)
	for i = 1, 4 do
		local point = origin:Lerp(finish, i / 4)
		Fx.afterimage(ctx.character, THUNDER, 0.4)
		Fx.burst(point, THUNDER, 10, 15, "Spark")
	end
	Fx.lightning(origin, finish, THUNDER, 10, 0.35)
	Fx.lightning(origin, finish, WHITE, 10, 0.25)
	Fx.sound("Beam", origin, 0.9, 0.7)
	ctx.character:PivotTo(CFrame.lookAt(finish, finish + direction))
	for _, target in targets do
		hit(ctx, target, 25)
		Fx.lightning(target.root.Position + Vector3.new(0, 8, 0), target.root.Position, THUNDER, 5, 0.25)
	end
end

-- Вихрь: враги затягиваются к Тору и получают урон.
function Handlers.Tempest(ctx)
	local radius = Abilities.ById.Tempest.range
	local center = ctx.root.Position
	Fx.sound("Wave", center, 1, 1.1)
	for i = 1, 3 do
		Fx.ring(center + Vector3.new(0, i * 2 - 3, 0), THUNDER, radius * (1 - i * 0.2), 0.6)
	end
	for i = 1, 10 do
		local angle = (i / 10) * math.pi * 2
		Fx.lightning(
			center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius),
			center,
			THUNDER,
			6,
			0.4
		)
	end
	for _, target in Damage.inRadius(center, radius, ctx.character) do
		local pull = (center - target.root.Position) * Vector3.new(1, 0, 1)
		if pull.Magnitude > 3 then
			Damage.knockback(
				target.root,
				pull.Unit * math.min(pull.Magnitude * 4, 80) + Vector3.new(0, 20, 0),
				0.25
			)
		end
		hit(ctx, target, 30)
	end
end

return { Handlers = Handlers }
