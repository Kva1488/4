--!strict
-- Локи, бог обмана. Способности из фильмов и 1 сезона сериала:
-- кинжалы и удар в спину, иллюзия-невидимость («Сюрприз!»), двойники,
-- скипетр с Камнем Разума, телепорт и Ларец Древних Зим.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Abilities = require(ReplicatedStorage.Shared.Abilities)

local Damage = require(script.Parent.Parent.Damage)
local Fx = require(script.Parent.Parent.Fx)
local Kit = require(script.Parent.Parent.Kit)
local Projectile = require(script.Parent.Parent.Projectile)
local Status = require(script.Parent.Parent.Status)

type Context = Kit.Context

local color = Kit.color
local hit = Kit.hit

local GREEN = Color3.fromRGB(60, 200, 90)
local STEEL = Color3.fromRGB(200, 230, 210)
local INVISIBLE_TIME = 4

local slashFlip: { [Player]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local invisibleToken: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any

-- Бьёт ли атакующий цель в спину.
local function isBackstab(ctx: Context, target: Damage.Target): boolean
	local toTarget = (target.root.Position - ctx.root.Position) * Vector3.new(1, 0, 1)
	if toTarget.Magnitude < 0.01 then
		return false
	end
	local targetLook = target.root.CFrame.LookVector * Vector3.new(1, 0, 1)
	return targetLook.Magnitude > 0.01 and targetLook.Unit:Dot(toTarget.Unit) > 0.5
end

local Handlers: { [string]: (Context) -> () } = {}

-- Кинжалы: быстрые удары, в спину ×2, из невидимости ×3.
function Handlers.DaggerSlash(ctx)
	local surprise = Kit.reveal(ctx.character)
	local flip = not slashFlip[ctx.player]
	slashFlip[ctx.player] = flip

	local direction = Kit.aimFlat(ctx)
	local origin = CFrame.lookAt(ctx.root.Position, ctx.root.Position + direction)
	local hitPoint = ctx.root.Position + direction * 3.5
	Fx.slash(origin, if surprise then GREEN else STEEL, 5.5, flip)
	Fx.sound("Punch", hitPoint, 0.6, 1.3)

	for _, target in Damage.inRadius(hitPoint, 4.5, ctx.character) do
		local mult = if surprise then 3 elseif isBackstab(ctx, target) then 2 else 1
		hit(ctx, target, 9 * mult, if mult > 1 then GREEN else STEEL)
		Fx.burst(target.root.Position, if mult > 1 then GREEN else STEEL, 10 * mult, 20)
		if surprise then
			Kit.notify:FireClient(ctx.player, "Сюрприз! 🐍", GREEN)
		elseif mult == 2 then
			Kit.notify:FireClient(ctx.player, "Удар в спину ×2", GREEN)
		end
	end
end

-- Метательный кинжал.
function Handlers.DaggerThrow(ctx)
	Kit.reveal(ctx.character)
	local origin = ctx.root.Position + Vector3.new(0, 1, 0)
	local knife = Instance.new("Part")
	knife.Size = Vector3.new(0.2, 0.2, 1.4)
	knife.Material = Enum.Material.Neon
	knife.Color = STEEL
	Fx.sound("Punch", origin, 0.5, 1.6)
	Projectile.fire({
		origin = origin,
		direction = Kit.aim3D(ctx, origin),
		speed = 140,
		range = Abilities.ById.DaggerThrow.range,
		radius = 2.5,
		owner = ctx.character,
		visual = knife,
		onHit = function(target, position)
			hit(ctx, target, if isBackstab(ctx, target) then 30 else 18)
			Fx.burst(position, GREEN, 15, 20)
		end,
		onEnd = function(position)
			Fx.burst(position, STEEL, 6, 10)
		end,
	})
end

-- Иллюзия: невидимость и обманка на месте.
function Handlers.Illusion(ctx)
	local decoy = Kit.cloneCharacter(ctx.character)
	Kit.setInvisible(ctx.character, true)
	Fx.burst(ctx.root.Position, GREEN, 25, 12)
	Fx.sound("Magic", ctx.root.Position, 0.8, 1.5)
	Kit.screenFx:FireClient(ctx.player, "Invisible", ctx.root.Position, INVISIBLE_TIME)

	local token = (invisibleToken[ctx.character] or 0) + 1
	invisibleToken[ctx.character] = token
	task.delay(INVISIBLE_TIME, function()
		if decoy then
			local pivot = decoy:GetPivot().Position
			Fx.burst(pivot, GREEN, 40, 20)
			Fx.dust(pivot, 10)
			decoy:Destroy()
		end
		if invisibleToken[ctx.character] == token then
			Kit.reveal(ctx.character)
		end
	end)
end

-- Двойники бросаются на ближайших врагов и взрываются.
function Handlers.Duplicates(ctx)
	Kit.reveal(ctx.character)
	local range = Abilities.ById.Duplicates.range
	local targets = Damage.inRadius(ctx.root.Position, range, ctx.character)
	table.sort(targets, function(a, b)
		return (a.root.Position - ctx.root.Position).Magnitude
			< (b.root.Position - ctx.root.Position).Magnitude
	end)
	Fx.sound("Magic", ctx.root.Position, 0.8, 1.2)

	for i = 1, 3 do
		local clone = Kit.cloneCharacter(ctx.character)
		if not clone then
			continue
		end
		local angle = (i / 3) * math.pi * 2
		local start = ctx.root.CFrame * CFrame.new(math.cos(angle) * 4, 0, math.sin(angle) * 4)
		clone:PivotTo(start)
		Fx.burst(start.Position, GREEN, 20, 15)

		local target = targets[((i - 1) % math.max(#targets, 1)) + 1]
		local destination = if target
			then target.root.Position
			else start.Position + Kit.aimFlat(ctx) * range * 0.6
		task.spawn(function()
			local from = start.Position
			local duration = 0.45
			local startTime = os.clock()
			while os.clock() - startTime < duration do
				local t = (os.clock() - startTime) / duration
				local position = from:Lerp(destination, t)
				clone:PivotTo(CFrame.lookAt(position, destination + Vector3.new(0, 0.01, 0)))
				task.wait()
			end
			Fx.sphere(destination, GREEN, 2, 14, 0.4)
			Fx.burst(destination, GREEN, 40, 35)
			Fx.flash(destination, GREEN, 20)
			for _, victim in Damage.inRadius(destination, 7, ctx.character) do
				hit(ctx, victim, 20)
			end
			clone:Destroy()
		end)
	end
end

-- Скипетр с Камнем Разума: луч и контроль разума.
function Handlers.Scepter(ctx)
	Kit.reveal(ctx.character)
	local c = color("Scepter")
	local origin = ctx.root.Position + Vector3.new(0, 1.2, 0)
	local direction = Kit.aim3D(ctx, origin) * Abilities.ById.Scepter.range
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { ctx.character, Fx.Folder }
	local result = workspace:Raycast(origin, direction, params)
	local finish = if result then result.Position else origin + direction

	Fx.sound("Beam", origin, 0.7, 1.2)
	Fx.beam(origin, finish, c, 1.2, 0.45)
	Fx.lightning(origin, finish, c, 10, 0.3)
	Fx.lightning(origin, finish, Color3.new(1, 1, 1), 10, 0.2)
	Fx.flash(origin, c, 16)
	Fx.burst(finish, c, 20, 25)
	if result then
		local target = Damage.fromPart(result.Instance, ctx.character)
		if target then
			hit(ctx, target, 25)
			Status.apply(target.humanoid, "Stun", 2)
			-- Синее свечение "под контролем" над головой.
			Fx.sphere(target.root.Position + Vector3.new(0, 3.2, 0), c, 1.4, 0.4, 2)
			local victim = Players:GetPlayerFromCharacter(target.model)
			if victim then
				Kit.screenFx:FireClient(victim, "MindControlled", finish, 2)
			end
		end
	end
end

-- Телепорт зелёной вспышкой.
function Handlers.LokiTeleport(ctx)
	local from = ctx.root.Position
	Fx.sphere(from, GREEN, 6, 0.5, 0.3)
	Fx.burst(from, GREEN, 30, 15)
	Fx.sound("Teleport", from, 0.7, 1.1)
	Fx.afterimage(ctx.character, GREEN, 0.5)
	Kit.teleport(ctx, ctx.target)
	local arrival = ctx.target + Vector3.new(0, 3, 0)
	Fx.sphere(arrival, GREEN, 0.5, 7, 0.35)
	Fx.burst(arrival, GREEN, 30, 20)
end

-- Ларец Древних Зим: ледяной конус.
function Handlers.Casket(ctx)
	Kit.reveal(ctx.character)
	local c = color("Casket")
	local range = Abilities.ById.Casket.range
	local forward = Kit.aimFlat(ctx)
	Fx.sound("Wave", ctx.root.Position, 1, 1.4)
	Fx.flash(ctx.root.Position, c, 30, 0.8)
	-- Ледяная волна: всплески вдоль конуса.
	for step = 1, 6 do
		local distance = step * range / 6
		local spread = distance * math.tan(math.rad(30))
		task.delay(step * 0.05, function()
			for _ = 1, 2 do
				local side = CFrame.lookAt(Vector3.zero, forward).RightVector
					* (math.random() * 2 - 1)
					* spread
				local point = ctx.root.Position + forward * distance + side
				Fx.burst(point, c, 14, 12, "Smoke")
				Fx.sphere(point, c, 1, 4, 0.5)
			end
		end)
	end
	for _, target in Kit.inCone(ctx, range, 32) do
		hit(ctx, target, 30)
		Status.apply(target.humanoid, "Stun", 3)
		Fx.crystal(target.root.Position, c, 3)
	end
end

return { Handlers = Handlers }
