--!strict
-- Статус-эффекты: замедление и оглушение.
-- Эффекты накладываются корректно: пересчёт идёт от базовой скорости, а не от текущей.

local Status = {}

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
	local list = effects[humanoid] or {}
	local stunned = isActive(list.Stun)
	local slowed = isActive(list.Slow)

	local speedMult = 1
	if slowed then
		speedMult = list.Slow.mult
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
end

-- kind: "Stun" (полная остановка) или "Slow" (mult — множитель скорости).
function Status.apply(humanoid: Humanoid, kind: "Stun" | "Slow", duration: number, mult: number?)
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

function Status.isStunned(humanoid: Humanoid): boolean
	local list = effects[humanoid]
	return list ~= nil and isActive(list.Stun)
end

return Status
