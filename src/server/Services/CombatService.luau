--!strict
-- Принимает запросы способностей от клиентов и проверяет каждый:
-- валидные аргументы, живой персонаж, нет оглушения, камни собраны, перезарядка прошла.
-- Клиенту никогда не доверяем: дальность прицела ограничивается на сервере.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Abilities = require(ReplicatedStorage.Shared.Abilities)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local AbilityHandlers = require(script.Parent.Parent.Combat.AbilityHandlers)
local Status = require(script.Parent.Parent.Combat.Status)
local DataService = require(script.Parent.DataService)

-- Небольшой запас на сетевую задержку, чтобы кнопка не "проглатывалась".
local COOLDOWN_TOLERANCE = 0.1

local CombatService = {}

local cooldowns: { [Player]: { [string]: number } } = {}

local function isFiniteVector(v: Vector3): boolean
	return v.X == v.X
		and v.Y == v.Y
		and v.Z == v.Z
		and math.abs(v.X) < 1e5
		and math.abs(v.Y) < 1e5
		and math.abs(v.Z) < 1e5
end

local function clampTarget(origin: Vector3, target: Vector3?, range: number, look: Vector3): Vector3
	if not target then
		return origin + look * range
	end
	local offset = target - origin
	if offset.Magnitude > range then
		return origin + offset.Unit * range
	end
	return target
end

local function onUseAbility(player: Player, abilityId: unknown, rawTarget: unknown)
	if typeof(abilityId) ~= "string" then
		return
	end
	local ability = Abilities.ById[abilityId]
	if not ability then
		return
	end
	local target: Vector3? = nil
	if typeof(rawTarget) == "Vector3" and isFiniteVector(rawTarget) then
		target = rawTarget
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (character and humanoid and root and root:IsA("BasePart")) or humanoid.Health <= 0 then
		return
	end
	if Status.isStunned(humanoid) then
		return
	end

	local data = DataService:Get(player)
	if not data or not Abilities.isUnlocked(ability, data.Stones) then
		return
	end

	local playerCooldowns = cooldowns[player]
	if not playerCooldowns then
		playerCooldowns = {}
		cooldowns[player] = playerCooldowns
	end
	local now = os.clock()
	if now < (playerCooldowns[abilityId] or 0) - COOLDOWN_TOLERANCE then
		return
	end
	playerCooldowns[abilityId] = now + ability.cooldown

	Remotes.event("AbilityCast"):FireClient(player, abilityId)

	local handler = AbilityHandlers[abilityId]
	local ok, err = pcall(handler, {
		player = player,
		character = character,
		humanoid = humanoid,
		root = root,
		target = clampTarget(root.Position, target, ability.range, root.CFrame.LookVector),
	})
	if not ok then
		warn(`[CombatService] {abilityId} failed: {err}`)
	end
end

function CombatService:Init()
	Remotes.event("AbilityCast")
	Remotes.event("UseAbility").OnServerEvent:Connect(onUseAbility)

	for _, ability in Abilities.List do
		assert(
			AbilityHandlers[ability.id],
			`Нет обработчика для способности {ability.id}`
		)
	end
end

function CombatService:Start()
	Players.PlayerRemoving:Connect(function(player)
		cooldowns[player] = nil
	end)
end

return CombatService
