--!strict
-- Поиск целей, урон, лечение, отбрасывание и награды за убийства.
-- Цели: персонажи других игроков (PvP) и модели с тегом "Enemy" (манекены, Дормамму, прислужники).
-- Каждый удар рассылается клиентам (цифры урона, хитмаркер), а убийство попадает в ленту убийств.
-- Зоны: атрибут Zone у модели ("Arena" — летающая арена). Бьют друг друга только цели одной зоны,
-- поэтому, например, Щелчок внизу не задевает игроков на арене.
-- HitRadius у модели — радиус большой цели (босс): она ловит удары краем, а не только центром.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Heroes = require(ReplicatedStorage.Shared.Heroes)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local DataService = require(script.Parent.Parent.Services.DataService)
local Status = require(script.Parent.Status)
local Fx = require(script.Parent.Fx)

-- Сколько урона нужно нанести, чтобы полностью зарядить ульту.
local ULT_DAMAGE_TO_CHARGE = 350
local PARRY_WINDOW = 0.3

export type Target = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
}

export type DamageOptions = {
	ignoreShield: boolean?, -- пробивает ForceField после спавна
	source: string?, -- название способности (для ленты убийств)
	color: Color3?, -- цвет цифр урона
}

local Damage = {}

local hitEvent = Remotes.event("Hit")
local killfeedEvent = Remotes.event("Killfeed")
local notifyEvent = Remotes.event("Notify")
local screenFxEvent = Remotes.event("ScreenFx")

-- За какого героя копится каждая статистика.
local PROGRESS_HERO: { [string]: { [string]: boolean } } = {
	LokiKills = { Loki = true },
	UltronKills = { Ultron = true },
	ThorKills = { Thor = true, ThorStormbreaker = true },
}

-- Подписчики на урон и убийства (прокачка, босс, режимы арены).
type DamageListener = (attacker: Player, humanoid: Humanoid, dealt: number) -> ()
type KillListener = (attacker: Player, humanoid: Humanoid) -> ()
local damageListeners: { DamageListener } = {}
local killListeners: { KillListener } = {}

function Damage.onDamaged(listener: DamageListener)
	table.insert(damageListeners, listener)
end

function Damage.onKilled(listener: KillListener)
	table.insert(killListeners, listener)
end

function Damage.zoneOf(model: Instance?): string
	local zone = model and model:GetAttribute("Zone")
	return if type(zone) == "string" then zone else "World"
end

function Damage.hitRadius(model: Instance): number
	local radius = model:GetAttribute("HitRadius")
	return if type(radius) == "number" then radius else 0
end

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
	local zone = if exclude then Damage.zoneOf(exclude) else nil
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character and character ~= exclude and (zone == nil or Damage.zoneOf(character) == zone) then
			local target = asTarget(character)
			if target then
				table.insert(result, target)
			end
		end
	end
	for _, model in CollectionService:GetTagged("Enemy") do
		if
			model:IsA("Model")
			and model ~= exclude
			and model:IsDescendantOf(workspace)
			and (zone == nil or Damage.zoneOf(model) == zone)
		then
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
		if (target.root.Position - position).Magnitude <= radius + Damage.hitRadius(target.model) then
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

local function displayName(humanoid: Humanoid): string
	local victimPlayer = Players:GetPlayerFromCharacter(humanoid.Parent)
	if victimPlayer then
		return victimPlayer.DisplayName
	end
	return if humanoid.DisplayName ~= "" then humanoid.DisplayName else (humanoid.Parent :: Instance).Name
end

local function onKill(attacker: Player, victim: Humanoid, source: string?, color: Color3?)
	if victim:GetAttribute("Rewarded") then
		return
	end
	victim:SetAttribute("Rewarded", true)
	local victimPlayer = Players:GetPlayerFromCharacter(victim.Parent)
	local custom = victim.Parent and victim.Parent:GetAttribute("KillReward")
	local amount = if type(custom) == "number"
		then custom
		elseif victimPlayer then Config.Rewards.PlayerKill
		else Config.Rewards.DummyKill
	-- Прогресс усиленных героев: убийства за базового героя.
	local victimHero = if victimPlayer
		then victimPlayer.Character and victimPlayer.Character:GetAttribute("Hero")
		else nil
	local unlocked: Heroes.Hero? = nil
	DataService:Update(attacker, function(data)
		data.Coins += amount
		data.Kills += 1
		local stats = data :: any
		-- Что было открыто до этого убийства.
		local before: { [string]: boolean } = {}
		for _, hero in Heroes.List do
			before[hero.id] = Heroes.isUnlocked(hero, data)
		end
		-- Каждая статистика растёт ровно на 1, даже если на неё завязано несколько героев.
		for stat, heroes in PROGRESS_HERO do
			if heroes[data.Hero] then
				stats[stat] += 1
			end
		end
		-- Канон «Что, если…?»: Альтрон убил Таноса и забрал все камни.
		if data.Hero == "Ultron" and victimHero == "Thanos" then
			local infinity = Heroes.ById.InfinityUltron.unlock
			if infinity then
				stats[infinity.stat] = math.max(stats[infinity.stat], infinity.count)
			end
		end
		for _, hero in Heroes.List do
			if not before[hero.id] and Heroes.isUnlocked(hero, data) then
				unlocked = hero
			end
		end
	end)
	if unlocked then
		local hero = unlocked :: Heroes.Hero
		notifyEvent:FireClient(
			attacker,
			`{hero.icon} Открыт герой: {hero.name}! Меню героев [H]`,
			hero.color
		)
		screenFxEvent:FireClient(attacker, "HeroUnlocked", Vector3.zero, hero.id)
	end
	-- Эффект гибели: вспышка и облако искр цвета убившей способности.
	local model = victim.Parent
	local root = model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		local tint = color or Color3.new(1, 1, 1)
		Fx.sphere(root.Position, tint, 2, 10, 0.4)
		Fx.ring(root.Position - Vector3.new(0, 2.5, 0), tint, 8, 0.5)
		Fx.burst(root.Position, tint, 40, 35, "Spark")
		Fx.flash(root.Position, tint, 20, 0.5)
	end
	killfeedEvent:FireAllClients(
		attacker.DisplayName,
		displayName(victim),
		source or "",
		color or Color3.new(1, 1, 1)
	)
	for _, listener in killListeners do
		task.spawn(listener, attacker, victim)
	end
end

-- Наносит урон. ForceField (защита после спавна) блокирует урон, кроме ignoreShield.
-- Заряд ульты (0..1) хранится атрибутом игрока: он сам реплицируется на клиент для шкалы.
function Damage.chargeUltimate(player: Player, amount: number)
	local current = player:GetAttribute("UltCharge")
	local value = if typeof(current) == "number" then current else 0
	player:SetAttribute("UltCharge", math.clamp(value + amount, 0, 1))
end

function Damage.deal(attacker: Player, humanoid: Humanoid, amount: number, options: DamageOptions?)
	if humanoid.Health <= 0 then
		return
	end
	local opts: DamageOptions = options or {}
	-- Игроки на арене и в остальном мире не задевают друг друга.
	if Damage.zoneOf(attacker.Character) ~= Damage.zoneOf(humanoid.Parent) then
		return
	end
	-- Большие цели (босс) получают не больше MaxHitDamage за удар: Щелчок не убивает их мгновенно.
	local cap = humanoid.Parent and humanoid.Parent:GetAttribute("MaxHitDamage")
	if type(cap) == "number" then
		amount = math.min(amount, cap)
	end
	local before = humanoid.Health
	-- Парирование: удар пришёл в первые 0.3 с блока — урон отменён, атакующий оглушён.
	local blockStart = humanoid:GetAttribute("BlockStart")
	if
		not opts.ignoreShield
		and humanoid:GetAttribute("Blocking")
		and typeof(blockStart) == "number"
		and os.clock() - blockStart <= PARRY_WINDOW
	then
		local attackerCharacter = attacker.Character
		local attackerHumanoid = attackerCharacter and attackerCharacter:FindFirstChildOfClass("Humanoid")
		if attackerHumanoid and attackerHumanoid ~= humanoid then
			Status.apply(attackerHumanoid, "Stun", 1.2)
		end
		local defender = Players:GetPlayerFromCharacter(humanoid.Parent)
		if defender then
			notifyEvent:FireClient(
				defender,
				"🛡️ ПАРИРОВАНИЕ! Атакующий оглушён",
				Color3.fromRGB(255, 240, 150)
			)
		end
		notifyEvent:FireClient(attacker, "Тебя парировали!", Color3.fromRGB(255, 120, 120))
		humanoid:SetAttribute("BlockStart", 0) -- одно парирование на блок
		return
	end
	-- Щит цели (блок, уклонение, вращение молота) снижает урон. Щелчок его пробивает.
	if not opts.ignoreShield then
		amount *= Status.damageMultiplier(humanoid)
		if amount <= 0 then
			return
		end
	end
	if opts.ignoreShield then
		humanoid.Health = math.max(0, humanoid.Health - amount)
	else
		humanoid:TakeDamage(amount)
	end
	local dealt = before - humanoid.Health
	if dealt <= 0 then
		return
	end
	humanoid:SetAttribute("LastAttacker", attacker.UserId)
	Damage.chargeUltimate(attacker, dealt / ULT_DAMAGE_TO_CHARGE)
	for _, listener in damageListeners do
		task.spawn(listener, attacker, humanoid, dealt)
	end

	local killed = humanoid.Health <= 0
	local model = humanoid.Parent
	local root = model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		hitEvent:FireAllClients(
			root.Position,
			dealt,
			opts.color or Color3.new(1, 1, 1),
			attacker.UserId,
			model,
			killed
		)
	end
	if killed then
		onKill(attacker, humanoid, opts.source, opts.color)
	end
end

-- Урон от NPC (Дормамму и его прислужники): блок и щиты работают, парирование гасит удар.
-- Убийство попадает в ленту от имени attackerName.
export type NpcDamageOptions = {
	attackerName: string,
	source: string,
	color: Color3?,
}

function Damage.fromNpc(humanoid: Humanoid, amount: number, opts: NpcDamageOptions)
	if humanoid.Health <= 0 then
		return
	end
	local blockStart = humanoid:GetAttribute("BlockStart")
	if
		humanoid:GetAttribute("Blocking")
		and typeof(blockStart) == "number"
		and os.clock() - blockStart <= PARRY_WINDOW
	then
		humanoid:SetAttribute("BlockStart", 0)
		local defender = Players:GetPlayerFromCharacter(humanoid.Parent)
		if defender then
			notifyEvent:FireClient(defender, "🛡️ ПАРИРОВАНИЕ!", Color3.fromRGB(255, 240, 150))
		end
		return
	end
	amount *= Status.damageMultiplier(humanoid)
	if amount <= 0 then
		return
	end
	local before = humanoid.Health
	humanoid:TakeDamage(amount)
	local dealt = before - humanoid.Health
	if dealt <= 0 then
		return
	end
	local killed = humanoid.Health <= 0
	local model = humanoid.Parent
	local root = model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
	local tint = opts.color or Color3.fromRGB(255, 120, 40)
	if root then
		hitEvent:FireAllClients(root.Position, dealt, tint, 0, model, killed)
	end
	if killed and not humanoid:GetAttribute("Rewarded") then
		humanoid:SetAttribute("Rewarded", true)
		killfeedEvent:FireAllClients(opts.attackerName, displayName(humanoid), opts.source, tint)
	end
end

function Damage.heal(humanoid: Humanoid, amount: number)
	if humanoid.Health > 0 and amount > 0 then
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
