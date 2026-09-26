--!strict
-- Логика всех способностей Перчатки. Каждый обработчик получает Context
-- (уже проверенный CombatService: способность открыта, перезарядка прошла, цель в пределах дальности).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Abilities = require(ReplicatedStorage.Shared.Abilities)
local Items = require(ReplicatedStorage.Shared.Items)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Damage = require(script.Parent.Damage)
local Fx = require(script.Parent.Fx)
local Status = require(script.Parent.Status)

export type Context = {
	player: Player,
	character: Model,
	humanoid: Humanoid,
	root: BasePart,
	target: Vector3, -- точка прицела (уже ограничена дальностью способности)
	abilityId: string,
	damageMult: number, -- от прокачки "Мощь"
	accent: Color3, -- цвет скина Перчатки (для базовых атак)
}

local screenFx = Remotes.event("ScreenFx")

local function color(id: string): Color3
	return Abilities.ById[id].color
end

-- Урон с учётом прокачки, подписью способности и цветом цифр.
local function hit(
	ctx: Context,
	target: Damage.Target,
	amount: number,
	colorOverride: Color3?,
	ignoreShield: boolean?
)
	local ability = Abilities.ById[ctx.abilityId]
	Damage.deal(ctx.player, target.humanoid, amount * ctx.damageMult, {
		source = ability.name,
		color = colorOverride or ability.color,
		ignoreShield = ignoreShield,
	})
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
		local before = target.humanoid.Health
		hit(ctx, target, amount)
		healed += before - math.max(target.humanoid.Health, 0)
		Fx.beam(target.root.Position, ctx.root.Position, fxColor, 0.6, 0.6)
		Fx.burst(target.root.Position, fxColor, 12, 15)
	end
	if healed > 0 then
		Damage.heal(ctx.humanoid, math.min(healed * 0.75, 60))
		Fx.burst(ctx.root.Position, Color3.fromRGB(120, 255, 140), 20, 10)
	end
end

local comboState: { [Player]: { count: number, last: number } } = setmetatable({}, { __mode = "k" }) :: any

local Handlers: { [string]: (Context) -> () } = {}

-- Базовая атака: серия из 3 ударов, третий сильнее и отбрасывает.
function Handlers.Punch(ctx)
	local now = os.clock()
	local state: { count: number, last: number } = comboState[ctx.player] or { count = 0, last = 0 }
	comboState[ctx.player] = state
	state.count = if now - state.last < 1 then state.count % 3 + 1 else 1
	state.last = now

	local finisher = state.count == 3
	local direction = aimDirection(ctx)
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
	Fx.sound("Beam", origin, 0.6)
	Fx.beam(origin, hitPosition, ctx.accent, 1.1, 0.4)
	Fx.sphere(origin, ctx.accent, 2, 0.5, 0.2)
	Fx.sphere(hitPosition, ctx.accent, 1, 6, 0.3)
	Fx.burst(hitPosition, ctx.accent, 20, 30)
	Fx.flash(hitPosition, ctx.accent, 16)

	if result then
		local target = Damage.fromPart(result.Instance, ctx.character)
		if target then
			hit(ctx, target, 20, ctx.accent)
		end
	end
end

-- Камень Силы: волна вокруг себя.
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

-- Камень Пространства: телепорт.
function Handlers.SpaceWarp(ctx)
	local c = color("SpaceWarp")
	Fx.sound("Teleport", ctx.root.Position, 0.8, 0.8)
	Fx.sphere(ctx.root.Position, c, 7, 1, 0.35)
	Fx.burst(ctx.root.Position, c, 30, 20)
	Fx.beam(ctx.root.Position, ctx.target + Vector3.new(0, 3, 0), c, 0.4, 0.3)
	teleport(ctx, ctx.target)
	local arrival = ctx.target + Vector3.new(0, 3, 0)
	Fx.sound("Teleport", arrival, 0.8, 1.3)
	Fx.sphere(arrival, c, 1, 9, 0.4)
	Fx.burst(arrival, c, 40, 30)
	Fx.flash(arrival, c, 20)
end

-- Камень Реальности: урон и уменьшение врагов в зоне.
function Handlers.RealityShrink(ctx)
	local radius = 10
	local c = color("RealityShrink")
	Fx.sound("Magic", ctx.target, 0.9, 0.7)
	Fx.sphere(ctx.target, c, 2, radius * 2, 0.5)
	Fx.ring(ctx.target, c, radius, 0.5)
	Fx.burst(ctx.target, c, 50, 35, "Fire")
	for _, target in Damage.inRadius(ctx.target, radius, ctx.character) do
		hit(ctx, target, 25)
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
	local c = color("SoulDrain")
	Fx.sound("Magic", ctx.root.Position, 0.9, 0.6)
	Fx.sphere(ctx.root.Position, c, radius * 2, 2, 0.5)
	Fx.ring(ctx.root.Position - Vector3.new(0, 2.5, 0), c, radius, 0.6)
	drainAll(ctx, Damage.inRadius(ctx.root.Position, radius, ctx.character), 20, c)
end

-- Камень Времени: замедление врагов и лечение себя.
function Handlers.TimeSlow(ctx)
	local radius = Abilities.ById.TimeSlow.range
	local center = ctx.root.Position
	local c = color("TimeSlow")
	Fx.sound("Magic", center, 0.9, 0.5)
	local dome = Fx.sphere(center, c, 2, radius * 2, 1.2)
	dome.Transparency = 0.6
	Fx.ring(center - Vector3.new(0, 2.5, 0), c, radius, 0.8)
	Fx.burst(center, c, 40, 15)
	for _, target in Damage.inRadius(center, radius, ctx.character) do
		Status.apply(target.humanoid, "Slow", 5, 0.35)
		Fx.burst(target.root.Position, c, 15, 8)
	end
	Damage.heal(ctx.humanoid, 20)
end

-- Камень Разума: оглушение в точке.
function Handlers.MindStun(ctx)
	local radius = 12
	local c = color("MindStun")
	Fx.sound("Magic", ctx.target, 0.9, 1.4)
	Fx.shockwave(ctx.target, c, radius)
	Fx.sphere(ctx.target, c, 1, 6, 0.4)
	Fx.flash(ctx.target, c, 24)
	for _, target in Damage.inRadius(ctx.target, radius, ctx.character) do
		hit(ctx, target, 15)
		Status.apply(target.humanoid, "Stun", 2.5)
		Fx.sphere(target.root.Position + Vector3.new(0, 3, 0), c, 1.5, 0.5, 2.5)
	end
end

-- Комбо Сила + Пространство: телепорт в небо и падение метеором.
function Handlers.Meteor(ctx)
	Fx.sound("Teleport", ctx.root.Position, 0.8, 0.8)
	Fx.sphere(ctx.root.Position, color("SpaceWarp"), 6, 1, 0.3)
	Fx.pillar(ctx.target, color("Meteor"), 60, 0.6)
	teleport(ctx, ctx.target + Vector3.new(0, 14, 0))
	task.wait(0.35)
	if ctx.humanoid.Health <= 0 then
		return
	end
	teleport(ctx, ctx.target)
	local radius = 16
	Fx.sound("Wave", ctx.target, 1.2, 0.8)
	Fx.shockwave(ctx.target, color("Meteor"), radius)
	Fx.sphere(ctx.target, color("PowerWave"), 4, radius * 1.6, 0.5)
	Fx.burst(ctx.target, color("Meteor"), 80, 70, "Fire")
	Fx.burst(ctx.target, Color3.fromRGB(120, 100, 90), 30, 25, "Smoke")
	Fx.flash(ctx.target, color("Meteor"), 50, 0.7)
	for _, target in Damage.inRadius(ctx.target, radius, ctx.character) do
		hit(ctx, target, 40)
		Damage.pushAway(target, ctx.target, 90, 45)
	end
end

-- Комбо Время + Реальность: заморозка в кристалле.
function Handlers.Stasis(ctx)
	local radius = 15
	local duration = 3.5
	local c = color("Stasis")
	Fx.sound("Magic", ctx.target, 1, 0.4)
	Fx.sphere(ctx.target, c, 2, radius * 2, 0.5)
	Fx.shockwave(ctx.target, c, radius)
	for _, target in Damage.inRadius(ctx.target, radius, ctx.character) do
		hit(ctx, target, 15)
		Status.apply(target.humanoid, "Stun", duration)
		Fx.crystal(target.root.Position, c, duration)
	end
end

-- Комбо Душа + Разум: оглушение и вытягивание жизни у всех рядом.
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
	drainAll(ctx, targets, 25, c)
end

-- Ультимейт: Щелчок. Половина врагов в радиусе обращается в пыль.
function Handlers.Snap(ctx)
	local radius = Abilities.ById.Snap.range
	local center = ctx.root.Position
	Status.apply(ctx.humanoid, "Stun", 1.8)

	-- Кинематографичная подготовка у всех, кто рядом.
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and (root.Position - center).Magnitude <= radius * 1.5 then
			screenFx:FireClient(player, "SnapCharge", center)
		end
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
	-- Перемешиваем и берём половину (округляя вверх).
	for i = #targets, 2, -1 do
		local j = math.random(1, i)
		targets[i], targets[j] = targets[j], targets[i]
	end
	local erased = math.ceil(#targets / 2)

	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and (root.Position - center).Magnitude <= radius * 1.5 then
			screenFx:FireClient(player, "Snap", center, erased)
		end
	end

	for i = 1, erased do
		local target = targets[i]
		local victim = Players:GetPlayerFromCharacter(target.model)
		if victim then
			screenFx:FireClient(victim, "Erased", center)
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

return Handlers
