--!strict
-- Поиск целей, урон, лечение, отбрасывание и награды за убийства.
-- Цели: персонажи других игроков (PvP) и модели с тегом "Enemy" (манекены).

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local DataService = require(script.Parent.Parent.Services.DataService)

export type Target = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
}

local Damage = {}

local function asTarget(model: Model?): Target?
	if not model then
		return nil
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return { model = model, humanoid = humanoid, root = root }
	end
	return nil
end

-- Все живые цели, кроме exclude (обычно персонаж атакующего).
function Damage.getTargets(exclude: Model?): { Target }
	local result = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character and character ~= exclude then
			local target = asTarget(character)
			if target then
				table.insert(result, target)
			end
		end
	end
	for _, model in CollectionService:GetTagged("Enemy") do
		if model:IsA("Model") and model ~= exclude and model:IsDescendantOf(workspace) then
			local target = asTarget(model)
			if target then
				table.insert(result, target)
			end
		end
	end
	return result
end

function Damage.inRadius(position: Vector3, radius: number, exclude: Model?): { Target }
	local result = {}
	for _, target in Damage.getTargets(exclude) do
		if (target.root.Position - position).Magnitude <= radius then
			table.insert(result, target)
		end
	end
	return result
end

-- Находит цель по детали, в которую попал луч.
function Damage.fromPart(part: BasePart, exclude: Model?): Target?
	local model = part:FindFirstAncestorOfClass("Model")
	while model and not model:FindFirstChildOfClass("Humanoid") do
		model = model:FindFirstAncestorOfClass("Model")
	end
	if model == exclude then
		return nil
	end
	return asTarget(model)
end

local function reward(attacker: Player, victim: Humanoid)
	if victim:GetAttribute("Rewarded") then
		return
	end
	victim:SetAttribute("Rewarded", true)
	local victimPlayer = Players:GetPlayerFromCharacter(victim.Parent)
	local amount = if victimPlayer then Config.Rewards.PlayerKill else Config.Rewards.DummyKill
	DataService:Update(attacker, function(data)
		data.Coins += amount
	end)
end

-- Наносит урон. ForceField (защита после спавна) блокирует урон, кроме ignoreShield.
function Damage.deal(attacker: Player, humanoid: Humanoid, amount: number, ignoreShield: boolean?)
	if humanoid.Health <= 0 then
		return
	end
	if ignoreShield then
		humanoid.Health = math.max(0, humanoid.Health - amount)
	else
		humanoid:TakeDamage(amount)
	end
	humanoid:SetAttribute("LastAttacker", attacker.UserId)
	if humanoid.Health <= 0 then
		reward(attacker, humanoid)
	end
end

function Damage.heal(humanoid: Humanoid, amount: number)
	if humanoid.Health > 0 then
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + amount)
	end
end

-- Отбрасывание. Работает и для игроков (у них физику считает клиент),
-- потому что LinearVelocity реплицируется и применяется владельцем.
function Damage.knockback(root: BasePart, velocity: Vector3, duration: number?)
	local attachment = Instance.new("Attachment")
	attachment.Name = "KnockbackAttachment"
	attachment.Parent = root

	local mover = Instance.new("LinearVelocity")
	mover.Name = "Knockback"
	mover.Attachment0 = attachment
	mover.RelativeTo = Enum.ActuatorRelativeTo.World
	mover.MaxForce = 1e7
	mover.VectorVelocity = velocity
	mover.Parent = root

	local lifetime = duration or 0.2
	Debris:AddItem(mover, lifetime)
	Debris:AddItem(attachment, lifetime)
end

-- Отбросить цель от точки center.
function Damage.pushAway(target: Target, center: Vector3, horizontal: number, vertical: number)
	local offset = (target.root.Position - center) * Vector3.new(1, 0, 1)
	local direction = if offset.Magnitude > 0.01 then offset.Unit else Vector3.new(0, 0, 1)
	Damage.knockback(target.root, direction * horizontal + Vector3.new(0, vertical, 0))
end

return Damage
