--!strict
-- Принимает запросы способностей от клиентов и проверяет каждый:
-- валидные аргументы, живой персонаж, нет оглушения, камни собраны, перезарядка прошла.
-- Клиенту никогда не доверяем: дальность прицела ограничивается на сервере.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Abilities = require(ReplicatedStorage.Shared.Abilities)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Heroes = require(ReplicatedStorage.Shared.Heroes)
local Shop = require(ReplicatedStorage.Shared.Shop)

local AbilityHandlers = require(script.Parent.Parent.Combat.AbilityHandlers)
local Status = require(script.Parent.Parent.Combat.Status)
local Damage = require(script.Parent.Parent.Combat.Damage)
local DataService = require(script.Parent.DataService)

-- Небольшой запас на сетевую задержку, чтобы кнопка не "проглатывалась".
local COOLDOWN_TOLERANCE = 0.1

local CombatService = {}

local cooldowns: { [Player]: { [string]: number } } = {}
local poseCounter = 0

-- Какую позу руки показать всем игрокам (анимация делается кодом в PoseController).
local POSES: { [string]: string } = {
	Punch = "Punch",
	DaggerSlash = "Punch",
	TimeThread = "Punch",
	UltronClaw = "Punch",
	MjolnirStrike = "Punch",
	AxeCleave = "Punch",
	DualStrike = "Punch",
	GodOfThunder = "Raise",
	BringMeThanos = "Raise",
	AsgardWrath = "Raise",
	LightningCall = "Raise",
	StormCall = "Raise",
	InfinityStrike = "Punch",
	SokoviaRise = "Raise",
	MultiverseEnd = "Raise",
	Snap = "Raise",
	GloriousPurpose = "Raise",
	Casket = "Raise",
}

local function setPose(character: Model, abilityId: string)
	poseCounter += 1
	character:SetAttribute("Pose", POSES[abilityId] or "Cast")
	character:SetAttribute("PoseAbility", abilityId)
	character:SetAttribute("PoseId", poseCounter)
end

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
	-- Оглушение и "немота" (взлом Альтрона) блокируют способности. Рывок работает под немотой.
	if Status.isStunned(humanoid) or (abilityId ~= "Dodge" and not Status.canCast(humanoid)) then
		return
	end

	local data = DataService:Get(player)
	-- Способность должна принадлежать текущему герою и быть открыта.
	if not data then
		return
	end
	local ownsAbility = ability.hero == data.Hero or ability.hero == "All"
	if not ownsAbility or not Abilities.isUnlocked(ability, data.Stones) then
		return
	end
	-- Ульта требует полного заряда (копится уроном и со временем).
	local isUltimate = ability.kind == "ultimate"
	if isUltimate and ((player:GetAttribute("UltCharge") :: number?) or 0) < 1 then
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
	local cooldown = ability.cooldown * Shop.cooldownMult(data.Upgrades)
	playerCooldowns[abilityId] = now + cooldown
	if isUltimate then
		player:SetAttribute("UltCharge", 0)
	end

	Remotes.event("AbilityCast"):FireClient(player, abilityId, cooldown)
	setPose(character, abilityId)

	local skin = Shop.SkinById[data.EquippedSkin] or Shop.SkinById[Shop.DefaultSkin]
	-- Базовые атаки Таноса окрашены скином Перчатки, у Локи — цветом героя.
	local accent = if data.Hero == "Thanos" then Shop.skinColor(skin) else Heroes.ById[data.Hero].color
	local handler = AbilityHandlers[abilityId]
	local ok, err = pcall(handler :: any, {
		player = player,
		character = character,
		humanoid = humanoid,
		root = root,
		target = clampTarget(root.Position, target, ability.range, root.CFrame.LookVector),
		abilityId = abilityId,
		damageMult = Shop.damageMult(data.Upgrades),
		accent = accent,
		stones = data.Stones,
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
	-- Заряд ульты понемногу растёт сам: полная шкала примерно за 90 секунд без боя.
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				Damage.chargeUltimate(player, 1 / 90)
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		cooldowns[player] = nil
	end)
end

return CombatService
