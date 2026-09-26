--!strict
-- Статус-эффекты:
-- • Stun — полная остановка, способности недоступны;
-- • Slow — замедление (mult — множитель скорости);
-- • Haste — ускорение (mult > 1);
-- • Silence — «немота»: ходить можно, способности недоступны (взлом Альтрона);
-- • щит — снижение входящего урона на время (рывок-уклонение, вращение молота).
-- Скорость всегда пересчитывается от базовой, поэтому эффекты корректно накладываются.

local Status = {}

local SPRINT_MULT = 1.6

type Kind = "Stun" | "Slow" | "Haste" | "Silence"
type Effect = { expires: number, mult: number }

local effects: { [Humanoid]: { [string]: Effect } } = setmetatable({}, { __mode = "k" }) :: any

local function ensureBase(humanoid: Humanoid)
	if humanoid:GetAttribute("BaseWalkSpeed") == nil then
		humanoid:SetAttribute("BaseWalkSpeed", humanoid.WalkSpeed)
	end
	if humanoid:GetAttribute("BaseJumpHeight") == nil then
		humanoid:SetAttribute("BaseJumpHeight", humanoid.JumpHeight)
	end
	if humanoid:GetAttribute("BaseJumpPower") == nil then
		humanoid:SetAttribute("BaseJumpPower", humanoid.JumpPower)
	end
end

local function isActive(effect: Effect?): boolean
	return effect ~= nil and effect.expires > os.clock()
end

local function recompute(humanoid: Humanoid)
	local list: { [string]: Effect } = effects[humanoid] or {}
	local stunned = isActive(list.Stun)
	local slowed = isActive(list.Slow)
	local hasted = isActive(list.Haste)

	local speedMult = 1
	if slowed then
		speedMult *= list.Slow.mult
	end
	if hasted then
		speedMult *= list.Haste.mult
	end
	-- Бег (Shift) не работает в замедлении.
	if humanoid:GetAttribute("Sprinting") and not slowed then
		speedMult *= SPRINT_MULT
	end
	if stunned then
		speedMult = 0
	end
	local jumpMult = if stunned then 0 elseif slowed then 0.5 else 1

	humanoid.WalkSpeed = (humanoid:GetAttribute("BaseWalkSpeed") :: number) * speedMult
	humanoid.JumpHeight = (humanoid:GetAttribute("BaseJumpHeight") :: number) * jumpMult
	humanoid.JumpPower = (humanoid:GetAttribute("BaseJumpPower") :: number) * jumpMult
	humanoid:SetAttribute("Stunned", stunned)
	humanoid:SetAttribute("Slowed", slowed)
	humanoid:SetAttribute("Hasted", hasted)
	humanoid:SetAttribute("Silenced", isActive(list.Silence))
end

function Status.apply(humanoid: Humanoid, kind: Kind, duration: number, mult: number?)
	if humanoid.Health <= 0 then
		return
	end
	ensureBase(humanoid)
	local list = effects[humanoid]
	if not list then
		list = {}
		effects[humanoid] = list
	end

	local expires = os.clock() + duration
	local current = list[kind]
	if not current or current.expires < expires then
		list[kind] = { expires = expires, mult = mult or 0 }
	end
	recompute(humanoid)

	task.delay(duration + 0.05, function()
		if humanoid.Parent then
			recompute(humanoid)
		end
	end)
end

-- Бег по большой карте: включается и выключается клиентом (сервер пересчитывает скорость сам).
function Status.setSprint(humanoid: Humanoid, on: boolean)
	if humanoid.Health <= 0 or (humanoid:GetAttribute("Sprinting") == true) == on then
		return
	end
	ensureBase(humanoid)
	humanoid:SetAttribute("Sprinting", on)
	recompute(humanoid)
end

function Status.isStunned(humanoid: Humanoid): boolean
	local list = effects[humanoid]
	return list ~= nil and isActive(list.Stun)
end

-- Досрочно снять эффект (например, замедление блока, когда блок отпущен).
function Status.clear(humanoid: Humanoid, kind: Kind)
	local list = effects[humanoid]
	if list then
		list[kind] = nil
		recompute(humanoid)
	end
end

-- Снять щит.
function Status.clearShield(humanoid: Humanoid)
	humanoid:SetAttribute("ShieldUntil", 0)
end

-- Можно ли сейчас использовать способности.
function Status.canCast(humanoid: Humanoid): boolean
	local list = effects[humanoid]
	return list == nil or not (isActive(list.Stun) or isActive(list.Silence))
end

-- Щит: входящий урон уменьшается на reduction (1 = полная неуязвимость) на duration секунд.
function Status.shield(humanoid: Humanoid, duration: number, reduction: number)
	local expiresAt = os.clock() + duration
	local current = humanoid:GetAttribute("ShieldUntil")
	if
		typeof(current) == "number"
		and current > expiresAt
		and (humanoid:GetAttribute("ShieldReduction") :: number) >= reduction
	then
		return
	end
	humanoid:SetAttribute("ShieldUntil", expiresAt)
	humanoid:SetAttribute("ShieldReduction", math.clamp(reduction, 0, 1))
end

-- Во сколько раз уменьшить входящий урон прямо сейчас (1 — без щита).
function Status.damageMultiplier(humanoid: Humanoid): number
	local expiresAt = humanoid:GetAttribute("ShieldUntil")
	if typeof(expiresAt) == "number" and expiresAt > os.clock() then
		return 1 - ((humanoid:GetAttribute("ShieldReduction") :: number?) or 0)
	end
	return 1
end

return Status
