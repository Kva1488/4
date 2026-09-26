--!strict
-- Логика всех способностей Перчатки. Каждый обработчик получает Context
-- (уже проверенный CombatService: способность открыта, перезарядка прошла, цель в пределах дальности).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Abilities = require(ReplicatedStorage.Shared.Abilities)
local Items = require(ReplicatedStorage.Shared.Items)

local Damage = require(script.Parent.Damage)
local Fx = require(script.Parent.Fx)
local Status = require(script.Parent.Status)

export type Context = {
	player: Player,
	character: Model,
	humanoid: Humanoid,
	root: BasePart,
	target: Vector3, -- точка прицела (уже ограничена дальностью способности)
}

local function color(id: string): Color3
	return Abilities.ById[id].color
end

-- Горизонтальное направление от персонажа к прицелу.
local function aimDirection(ctx: Context): Vector3
	local flat = (ctx.target - ctx.root.Position) * Vector3.new(1, 0, 1)
	if flat.Magnitude < 0.01 then
		return ctx.root.CFrame.LookVector
	end
	return flat.Unit
end

-- Безопасный телепорт: ставим персонажа чуть выше точки, сохраняя направление взгляда.
local function teleport(ctx: Context, position: Vector3)
	local look = aimDirection(ctx)
	local destination = position + Vector3.new(0, 3, 0)
	ctx.character:PivotTo(CFrame.lookAt(destination, destination + look))
end

local function drainAll(ctx: Context, targets: { Damage.Target }, amount: number, fxColor: Color3)
	local healed = 0
	for _, target in targets do
		Damage.deal(ctx.player, target.humanoid, amount)
		Fx.beam(target.root.Position, ctx.root.Position, fxColor, 0.5, 0.5)
		healed += amount
	end
	Damage.heal(ctx.humanoid, math.min(healed * 0.75, 60))
end

local comboState: { [Player]: { count: number, last: number } } = setmetatable({}, { __mode = "k" }) :: any

local Handlers: { [string]: (Context) -> () } = {}

-- Базовая атака: серия из 3 ударов, третий сильнее и отбрасывает.
function Handlers.Punch(ctx)
	local now = os.clock()
	local state = comboState[ctx.player] or { count = 0, last = 0 }
	comboState[ctx.player] = state
	state.count = if now - state.last < 1 then state.count % 3 + 1 else 1
	state.last = now

	local finisher = state.count == 3
	local direction = aimDirection(ctx)
	local hitPoint = ctx.root.Position + direction * 3.5
	Fx.sphere(hitPoint, color("Punch"), 1, if finisher then 7 else 4, 0.25)

	for _, target in Damage.inRadius(hitPoint, 4.5, ctx.character) do
		Damage.deal(ctx.player, target.humanoid, if finisher then 22 else 10)
		if finisher then
			Damage.knockback(target.root, direction * 70 + Vector3.new(0, 25, 0))
		end
	end
end

-- Базовая дальняя атака: луч по прицелу.
function Handlers.Beam(ctx)
	local origin = ctx.root.Position + Vector3.new(0, 1, 0)
	local direction = ctx.target - origin
	if direction.Magnitude < 0.01 then
		direction = ctx.root.CFrame.LookVector
	end
	direction = direction.Unit * Abilities.ById.Beam.range

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { ctx.character, Fx.Folder }

	local result = workspace:Raycast(origin, direction, params)
	local hitPosition = if result then result.Position else origin + direction
	Fx.beam(origin, hitPosition, color("Beam"), 0.8, 0.35)
	Fx.sphere(hitPosition, color("Beam"), 1, 5, 0.3)

	if result then
		local target = Damage.fromPart(result.Instance, ctx.character)
		if target then
			Damage.deal(ctx.player, target.humanoid, 20)
		end
	end
end

-- Камень Силы: волна вокруг себя.
function Handlers.PowerWave(ctx)
	local radius = Abilities.ById.PowerWave.range
	local center = ctx.root.Position
	Fx.ring(center - Vector3.new(0, 2.5, 0), color("PowerWave"), radius, 0.5)
	Fx.sphere(center, color("PowerWave"), 3, radius, 0.4)
	for _, target in Damage.inRadius(center, radius, ctx.character) do
		Damage.deal(ctx.player, target.humanoid, 35)
		Damage.pushAway(target, center, 80, 30)
	end
end

-- Камень Пространства: телепорт.
function Handlers.SpaceWarp(ctx)
	Fx.sphere(ctx.root.Position, color("SpaceWarp"), 6, 1, 0.35)
	teleport(ctx, ctx.target)
	Fx.sphere(ctx.target + Vector3.new(0, 3, 0), color("SpaceWarp"), 1, 8, 0.4)
end

-- Камень Реальности: урон и уменьшение врагов в зоне.
function Handlers.RealityShrink(ctx)
	local radius = 10
	Fx.sphere(ctx.target, color("RealityShrink"), 2, radius * 2, 0.5)
	for _, target in Damage.inRadius(ctx.target, radius, ctx.character) do
		Damage.deal(ctx.player, target.humanoid, 25)
		local model = target.model
		if target.humanoid.Health > 0 and not model:GetAttribute("Shrunk") then
			model:SetAttribute("Shrunk", true)
			local original = model:GetScale()
			pcall(model.ScaleTo, model, original * 0.5)
			task.delay(6, function()
				if model.Parent then
					pcall(model.ScaleTo, model, original)
					model:SetAttribute("Shrunk", nil)
				end
			end)
		end
	end
end

-- Камень Души: вытягивание здоровья.
function Handlers.SoulDrain(ctx)
	local radius = Abilities.ById.SoulDrain.range
	Fx.sphere(ctx.root.Position, color("SoulDrain"), radius * 2, 2, 0.5)
	drainAll(ctx, Damage.inRadius(ctx.root.Position, radius, ctx.character), 20, color("SoulDrain"))
end

-- Камень Времени: замедление врагов и лечение себя.
function Handlers.TimeSlow(ctx)
	local radius = Abilities.ById.TimeSlow.range
	local center = ctx.root.Position
	local dome = Fx.sphere(center, color("TimeSlow"), 2, radius * 2, 1.2)
	dome.Transparency = 0.6
	Fx.ring(center - Vector3.new(0, 2.5, 0), color("TimeSlow"), radius, 0.8)
	for _, target in Damage.inRadius(center, radius, ctx.character) do
		Status.apply(target.humanoid, "Slow", 5, 0.35)
	end
	Damage.heal(ctx.humanoid, 20)
end

-- Камень Разума: оглушение в точке.
function Handlers.MindStun(ctx)
	local radius = 12
	Fx.ring(ctx.target, color("MindStun"), radius, 0.6)
	Fx.sphere(ctx.target, color("MindStun"), 1, 6, 0.4)
	for _, target in Damage.inRadius(ctx.target, radius, ctx.character) do
		Damage.deal(ctx.player, target.humanoid, 15)
		Status.apply(target.humanoid, "Stun", 2.5)
		Fx.sphere(target.root.Position + Vector3.new(0, 3, 0), color("MindStun"), 1.5, 0.5, 2.5)
	end
end

-- Комбо Сила + Пространство: телепорт и удар по земле.
function Handlers.Meteor(ctx)
	Fx.sphere(ctx.root.Position, color("SpaceWarp"), 6, 1, 0.3)
	teleport(ctx, ctx.target + Vector3.new(0, 12, 0))
	task.wait(0.3)
	if ctx.humanoid.Health <= 0 then
		return
	end
	teleport(ctx, ctx.target)
	local radius = 16
	Fx.ring(ctx.target, color("Meteor"), radius, 0.6)
	Fx.sphere(ctx.target, color("PowerWave"), 4, radius * 1.6, 0.5)
	for _, target in Damage.inRadius(ctx.target, radius, ctx.character) do
		Damage.deal(ctx.player, target.humanoid, 40)
		Damage.pushAway(target, ctx.target, 90, 45)
	end
end

-- Комбо Время + Реальность: заморозка в кристалле.
function Handlers.Stasis(ctx)
	local radius = 15
	local duration = 3.5
	Fx.sphere(ctx.target, color("Stasis"), 2, radius * 2, 0.5)
	for _, target in Damage.inRadius(ctx.target, radius, ctx.character) do
		Damage.deal(ctx.player, target.humanoid, 15)
		Status.apply(target.humanoid, "Stun", duration)
		Fx.crystal(target.root.Position, color("Stasis"), duration)
	end
end

-- Комбо Душа + Разум: оглушение и вытягивание жизни у всех рядом.
function Handlers.SoulHarvest(ctx)
	local radius = Abilities.ById.SoulHarvest.range
	local targets = Damage.inRadius(ctx.root.Position, radius, ctx.character)
	Fx.ring(ctx.root.Position - Vector3.new(0, 2.5, 0), color("SoulHarvest"), radius, 0.7)
	for _, target in targets do
		Status.apply(target.humanoid, "Stun", 1.5)
	end
	drainAll(ctx, targets, 25, color("SoulHarvest"))
end

-- Ультимейт: Щелчок. Половина врагов в радиусе обращается в пыль.
function Handlers.Snap(ctx)
	local radius = Abilities.ById.Snap.range
	Status.apply(ctx.humanoid, "Stun", 1.6)

	-- Замах: камни по очереди вспыхивают вокруг персонажа.
	for i, stone in Items.Stones do
		local angle = (i / #Items.Stones) * math.pi * 2
		local offset = Vector3.new(math.cos(angle) * 3, 2, math.sin(angle) * 3)
		Fx.sphere(ctx.root.Position + offset, stone.color, 0.5, 2, 1.4)
		task.wait(0.2)
	end
	task.wait(0.3)
	if ctx.humanoid.Health <= 0 then
		return
	end

	Fx.sphere(ctx.root.Position, Color3.new(1, 1, 1), 4, radius * 2, 1.2)

	local targets = Damage.inRadius(ctx.root.Position, radius, ctx.character)
	-- Перемешиваем и берём половину (округляя вверх).
	for i = #targets, 2, -1 do
		local j = math.random(1, i)
		targets[i], targets[j] = targets[j], targets[i]
	end
	for i = 1, math.ceil(#targets / 2) do
		local target = targets[i]
		task.spawn(function()
			Status.apply(target.humanoid, "Stun", 2)
			task.wait(math.random() * 0.8)
			for _, part in target.model:GetDescendants() do
				if part:IsA("BasePart") and part.Transparency < 1 then
					Fx.dust(part.Position, 3)
					part.Transparency = 1
				elseif part:IsA("Decal") then
					part.Transparency = 1
				end
				task.wait(0.03)
			end
			Damage.deal(ctx.player, target.humanoid, math.huge, true)
		end)
	end
end

return Handlers
