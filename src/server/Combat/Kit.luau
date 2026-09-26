--!strict
-- Общие инструменты способностей всех героев: контекст, урон, прицел, телепорт,
-- невидимость Локи, двойники-иллюзии.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Abilities = require(ReplicatedStorage.Shared.Abilities)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Damage = require(script.Parent.Damage)
local Fx = require(script.Parent.Fx)

export type Context = {
	player: Player,
	character: Model,
	humanoid: Humanoid,
	root: BasePart,
	target: Vector3, -- точка прицела (уже ограничена дальностью способности)
	abilityId: string,
	damageMult: number, -- от прокачки "Мощь"
	accent: Color3, -- цвет героя/скина для базовых атак
	stones: { [string]: boolean },
}

local Kit = {}

Kit.screenFx = Remotes.event("ScreenFx")
Kit.notify = Remotes.event("Notify")

function Kit.color(id: string): Color3
	return Abilities.ById[id].color
end

-- Урон с учётом прокачки, подписью способности и цветом цифр.
function Kit.hit(
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
function Kit.aimFlat(ctx: Context): Vector3
	local flat = (ctx.target - ctx.root.Position) * Vector3.new(1, 0, 1)
	if flat.Magnitude < 0.01 then
		return ctx.root.CFrame.LookVector
	end
	return flat.Unit
end

-- Полное (с высотой) направление от груди персонажа к прицелу.
function Kit.aim3D(ctx: Context, origin: Vector3): Vector3
	local direction = ctx.target - origin
	if direction.Magnitude < 0.01 then
		return ctx.root.CFrame.LookVector
	end
	return direction.Unit
end

-- Безопасный телепорт: чуть выше точки, взгляд сохраняет направление прицела.
function Kit.teleport(ctx: Context, position: Vector3)
	local look = Kit.aimFlat(ctx)
	local destination = position + Vector3.new(0, 3, 0)
	ctx.character:PivotTo(CFrame.lookAt(destination, destination + look))
end

function Kit.drainAll(ctx: Context, targets: { Damage.Target }, amount: number, fxColor: Color3)
	local healed = 0
	for _, target in targets do
		local before = target.humanoid.Health
		Kit.hit(ctx, target, amount)
		healed += before - math.max(target.humanoid.Health, 0)
		Fx.beam(target.root.Position, ctx.root.Position, fxColor, 0.6, 0.6)
		Fx.burst(target.root.Position, fxColor, 12, 15)
	end
	if healed > 0 then
		Damage.heal(ctx.humanoid, math.min(healed * 0.75, 60))
		Fx.burst(ctx.root.Position, Color3.fromRGB(120, 255, 140), 20, 10)
	end
end

-- Цели в конусе перед персонажем.
function Kit.inCone(ctx: Context, range: number, halfAngle: number): { Damage.Target }
	local forward = Kit.aimFlat(ctx)
	local result = {}
	for _, target in Damage.inRadius(ctx.root.Position, range, ctx.character) do
		local offset = (target.root.Position - ctx.root.Position) * Vector3.new(1, 0, 1)
		if offset.Magnitude < 3 or forward:Dot(offset.Unit) >= math.cos(math.rad(halfAngle)) then
			table.insert(result, target)
		end
	end
	return result
end

-- Цели вдоль прямой (пробивающие лучи). Луч останавливается о стены.
function Kit.alongLine(
	ctx: Context,
	origin: Vector3,
	direction: Vector3,
	range: number,
	width: number
): ({ Damage.Target }, Vector3)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { ctx.character, Fx.Folder }
	-- Персонажей луч пробивает, поэтому стену ищем, исключая всех персонажей.
	local exclude: { Instance } = { ctx.character, Fx.Folder }
	for _, target in Damage.getTargets(ctx.character) do
		table.insert(exclude, target.model)
	end
	params.FilterDescendantsInstances = exclude
	local wall = workspace:Raycast(origin, direction * range, params)
	local length = if wall then (wall.Position - origin).Magnitude else range
	local finish = origin + direction * length

	local result = {}
	for _, target in Damage.getTargets(ctx.character) do
		local offset = target.root.Position - origin
		local along = offset:Dot(direction)
		if along > 0 and along <= length and (offset - direction * along).Magnitude <= width then
			table.insert(result, target)
		end
	end
	return result, finish
end

-- Копия персонажа-"манекен" для иллюзий: без скриптов, заякорена, сквозь неё можно пройти.
function Kit.cloneCharacter(character: Model): Model?
	local wasArchivable = character.Archivable
	character.Archivable = true
	local ok, copy = pcall(function()
		return character:Clone()
	end)
	character.Archivable = wasArchivable
	if not ok or not copy then
		return nil
	end
	local clone = copy :: Model
	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("BaseScript") or descendant:IsA("ForceField") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			local original = descendant:GetAttribute("OrigTransparency")
			if typeof(original) == "number" then
				descendant.Transparency = original
			end
		elseif descendant:IsA("Decal") then
			local original = descendant:GetAttribute("OrigTransparency")
			if typeof(original) == "number" then
				descendant.Transparency = original
			end
		end
	end
	clone.Name = character.Name
	clone.Parent = Fx.Folder
	return clone
end

-- Невидимость Локи: все детали прозрачные, имя над головой скрыто.
function Kit.setInvisible(character: Model, invisible: boolean)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") or descendant:IsA("Decal") then
			local visual = descendant :: any
			if invisible then
				if descendant:GetAttribute("OrigTransparency") == nil then
					descendant:SetAttribute("OrigTransparency", visual.Transparency)
				end
				visual.Transparency = 1
			else
				local original = descendant:GetAttribute("OrigTransparency")
				if typeof(original) == "number" then
					visual.Transparency = original
				end
				descendant:SetAttribute("OrigTransparency", nil)
			end
		end
	end
	if humanoid then
		humanoid.DisplayDistanceType = if invisible
			then Enum.HumanoidDisplayDistanceType.None
			else Enum.HumanoidDisplayDistanceType.Viewer
	end
	character:SetAttribute("Invisible", if invisible then true else nil)
end

-- Выход из невидимости с зелёной вспышкой. Возвращает true, если персонаж был невидим.
function Kit.reveal(character: Model): boolean
	if not character:GetAttribute("Invisible") then
		return false
	end
	Kit.setInvisible(character, false)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		Fx.burst(root.Position, Color3.fromRGB(60, 200, 90), 30, 20)
	end
	return true
end

-- Все игроки рядом с точкой (для экранных эффектов).
function Kit.playersNear(position: Vector3, radius: number): { Player }
	local result = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and (root.Position - position).Magnitude <= radius then
			table.insert(result, player)
		end
	end
	return result
end

return Kit
