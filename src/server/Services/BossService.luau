--!strict
-- Рейд-босс Дормамму. Раз в несколько минут в Разломе Тёмного измерения открывается портал,
-- и из-под земли поднимается огромная огненная голова. Все игроки бьют её вместе.
--
-- Атаки (у каждой есть предупреждение на земле — от них можно увернуться):
-- • Взгляд Дормамму — лучи из глаз прожигают землю полосой;
-- • Столпы пламени — под каждым игроком вспыхивает огненный столб;
-- • Дождь из Тёмного измерения — метеоры по кругам-предупреждениям;
-- • Рёв — огненная волна от босса: перепрыгни её!
-- • Безликие — прислужники выходят из порталов;
-- • Руки Тёмного измерения (фаза 2) — гигантские руки вырываются из земли под игроками;
-- • Тёмное измерение поглощает мир (фаза 3) — пламя бьёт само, атаки чаще.
--
-- Награда делится по вкладу в урон: монеты, опыт и счётчик побед (титулы).

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local DormammuModel = require(ReplicatedStorage.Shared.DormammuModel)
local Places = require(ReplicatedStorage.Shared.Places)
local Progression = require(ReplicatedStorage.Shared.Progression)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Damage = require(script.Parent.Parent.Combat.Damage)
local Fx = require(script.Parent.Parent.Combat.Fx)
local DataService = require(script.Parent.DataService)
local ProgressionService = require(script.Parent.ProgressionService)

local BossService = {}

local FIRST_DELAY = if RunService:IsStudio() then 25 else 120
local INTERVAL = 8 * 60 -- пауза между появлениями
local WARNING = 20 -- портал открывается заранее
local TIME_LIMIT = 6 * 60 -- не успели — Дормамму уходит
local IDLE_LIMIT = 40 -- рядом никого — уходит
local HOVER = 17 -- высота центра головы над полом
local BASE_HEALTH = 4000
local HEALTH_PER_PLAYER = 2500
local MAX_HIT = 250 -- больше за один удар не снять (Щелчок не убивает мгновенно)
local AGGRO_RADIUS = 110
local MAX_MINIONS = 8
local MIN_SHARE_FOR_KILL = 0.01 -- с меньшим вкладом победа не засчитывается

local PURPLE = Color3.fromRGB(190, 50, 255)
local ORANGE = Color3.fromRGB(255, 130, 40)
local EYE = Color3.fromRGB(255, 170, 50)
local OBSIDIAN = Color3.fromRGB(30, 16, 40)
local DANGER = Color3.fromRGB(255, 70, 40)

local CENTER = Places.BossCenter
local FLOOR_Y = 1.5

local FIRE_TEXTURE = "rbxasset://textures/particles/fire_main.dds"
local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local SPARK_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"

type Fight = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	damage: { [Player]: number },
	maxHealth: number,
	phase: number,
	alive: boolean,
	focus: Player?,
	yaw: number,
	rise: number, -- 0..1 анимация появления из-под земли
	started: number,
	lastSeen: number,
	minions: { Model },
	heartbeat: RBXScriptConnection?,
}

local bossEvent: RemoteEvent
local notify: RemoteEvent
local screenFx: RemoteEvent
local lair: Folder
local riftParts: { BasePart } = {}
local riftEmitters: { ParticleEmitter } = {}
local signLabel: TextLabel
local fight: Fight? = nil
local nextAt = 0

-- ── Вспомогательное ────────────────────────────────────────────────────────

local function tween(instance: Instance, duration: number, goal: { [string]: any }, style: Enum.EasingStyle?)
	local t = TweenService:Create(instance, TweenInfo.new(duration, style or Enum.EasingStyle.Quad), goal)
	t:Play()
	return t
end

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		if key ~= "Parent" then
			(p :: any)[key] = value
		end
	end
	p.Parent = props.Parent or lair
	return p
end

local function ghost(p: Part): Part
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	return p
end

local function flat(v: Vector3): Vector3
	return v * Vector3.new(1, 0, 1)
end

local function emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.LightEmission = 1
	e.LightInfluence = 0
	for key, value in props do
		(e :: any)[key] = value
	end
	e.Parent = parent
	return e
end

local function fireEmitter(parent: Instance, color: Color3, rate: number, size: number): ParticleEmitter
	return emitter(parent, {
		Texture = FIRE_TEXTURE,
		Color = ColorSequence.new(color, Color3.fromRGB(255, 200, 120)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) }),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.9),
			NumberSequenceKeypoint.new(0.2, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Lifetime = NumberRange.new(0.6, 1.2),
		Speed = NumberRange.new(2, 5),
		Acceleration = Vector3.new(0, 14, 0),
		Rate = rate,
		RotSpeed = NumberRange.new(-60, 60),
		Rotation = NumberRange.new(0, 360),
		SpreadAngle = Vector2.new(30, 30),
	})
end

-- Живые игроки у разлома (не на арене).
local function targetsNear(radius: number?): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if
			character
			and humanoid
			and humanoid.Health > 0
			and root
			and Damage.zoneOf(character) == "World"
			and (flat(root.Position) - flat(CENTER)).Magnitude <= (radius or AGGRO_RADIUS)
		then
			table.insert(list, player)
		end
	end
	return list
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function groundAt(position: Vector3): Vector3
	return Vector3.new(position.X, FLOOR_Y, position.Z)
end

-- Урон Дормамму всем игрокам рядом с точкой (по горизонтали).
local function blast(
	center: Vector3,
	radius: number,
	amount: number,
	source: string,
	lift: number?,
	color: Color3?
)
	for _, player in targetsNear(AGGRO_RADIUS + 20) do
		local root = rootOf(player)
		local humanoid = humanoidOf(player)
		if root and humanoid and (flat(root.Position) - flat(center)).Magnitude <= radius then
			Damage.fromNpc(
				humanoid,
				amount,
				{ attackerName = "Дормамму", source = source, color = color or ORANGE }
			)
			if lift then
				local away = flat(root.Position - center)
				local push = if away.Magnitude > 0.1 then away.Unit * 25 else Vector3.zero
				Damage.knockback(root, push + Vector3.new(0, lift, 0), 0.25)
			end
		end
	end
end

-- Круг-предупреждение на земле: заполняется к моменту удара.
local function warnCircle(position: Vector3, radius: number, duration: number, color: Color3?)
	local tint = color or DANGER
	local flatDisc = CFrame.new(groundAt(position) + Vector3.new(0, 0.08, 0))
		* CFrame.Angles(0, 0, math.rad(90))
	local rim = ghost(part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.12, radius * 2, radius * 2),
		CFrame = flatDisc,
		Material = Enum.Material.Neon,
		Color = tint,
		Transparency = 0.75,
		Parent = Fx.Folder,
	}))
	local fill = ghost(part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.14, 0.5, 0.5),
		CFrame = flatDisc,
		Material = Enum.Material.Neon,
		Color = tint,
		Transparency = 0.45,
		Parent = Fx.Folder,
	}))
	tween(fill, duration, { Size = Vector3.new(0.14, radius * 2, radius * 2) }, Enum.EasingStyle.Linear)
	Debris:AddItem(rim, duration + 0.05)
	Debris:AddItem(fill, duration + 0.05)
end

local function callout(text: string, players: { Player })
	for _, player in players do
		bossEvent:FireClient(player, "Callout", text)
	end
end

-- ── Логово: разлом Тёмного измерения ───────────────────────────────────────

local function buildLair()
	local cylinder = CFrame.Angles(0, 0, math.rad(90))
	-- Обсидиановая платформа.
	part({
		Name = "LairFloor",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(3, Places.BossRadius * 2, Places.BossRadius * 2),
		CFrame = CFrame.new(CENTER + Vector3.new(0, FLOOR_Y - 1.5, 0)) * cylinder,
		Material = Enum.Material.Basalt,
		Color = OBSIDIAN,
	})
	-- Мандала мистических искусств на полу: светящиеся кольца.
	for i, radius in { Places.BossRadius - 2, 30, 18, 7 } do
		ghost(part({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.1, radius * 2, radius * 2),
			CFrame = CFrame.new(CENTER + Vector3.new(0, FLOOR_Y + 0.01 + i * 0.01, 0)) * cylinder,
			Material = Enum.Material.Neon,
			Color = ORANGE,
			Transparency = 0.35,
		}))
		ghost(part({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.1, radius * 2 - 1, radius * 2 - 1),
			CFrame = CFrame.new(CENTER + Vector3.new(0, FLOOR_Y + 0.015 + i * 0.01, 0)) * cylinder,
			Material = Enum.Material.Basalt,
			Color = OBSIDIAN,
		}))
	end
	-- Два квадрата под 45° — восьмиконечная звезда внутри мандалы.
	for _, turn in { 0, 45 } do
		for side = 0, 3 do
			local angle = math.rad(turn + side * 90)
			local out = Vector3.new(math.cos(angle), 0, math.sin(angle)) * 21
			local position = CENTER + out + Vector3.new(0, FLOOR_Y + 0.1, 0)
			ghost(part({
				Size = Vector3.new(0.5, 0.1, 42),
				CFrame = CFrame.lookAt(
					position,
					position + Vector3.new(-math.sin(angle), 0, math.cos(angle))
				),
				Material = Enum.Material.Neon,
				Color = ORANGE,
				Transparency = 0.3,
			}))
		end
	end
	-- Обсидиановые шипы по краю с пурпурным огнём на остриях.
	for i = 1, 12 do
		local angle = (i / 12) * math.pi * 2
		local base = CENTER + Vector3.new(math.cos(angle), 0, math.sin(angle)) * (Places.BossRadius - 3)
		local height = 12 + (i % 3) * 6
		local tilt = CFrame.lookAt(base, base + Vector3.new(math.cos(angle), 0, math.sin(angle)))
			* CFrame.Angles(math.rad(-75), 0, 0)
		local spike = part({
			Name = "Spike",
			Size = Vector3.new(3.2, 3.2, height),
			CFrame = tilt * CFrame.new(0, 0, -height / 2 + 1),
			Material = Enum.Material.Basalt,
			Color = OBSIDIAN,
		})
		ghost(part({
			Size = Vector3.new(0.3, 3.3, height * 0.8),
			CFrame = spike.CFrame,
			Material = Enum.Material.Neon,
			Color = PURPLE,
		}))
		local tip = ghost(part({
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 1.6,
			CFrame = tilt * CFrame.new(0, 0, -height + 1),
			Material = Enum.Material.Neon,
			Color = PURPLE,
		}))
		fireEmitter(tip, PURPLE, 12, 3)
		local light = Instance.new("PointLight")
		light.Color = PURPLE
		light.Range = 16
		light.Brightness = 2
		light.Parent = tip
	end
	-- Парящие осколки Тёмного измерения (крутятся на клиенте, тег Spin).
	for i = 1, 14 do
		local angle = (i / 14) * math.pi * 2
		local radius = 26 + (i % 4) * 5
		local shard = ghost(part({
			Name = "DarkShard",
			Size = Vector3.new(1.5, 4 + (i % 3) * 2, 1.5),
			CFrame = CFrame.new(
				CENTER + Vector3.new(math.cos(angle) * radius, 22 + (i % 5) * 5, math.sin(angle) * radius)
			) * CFrame.Angles(0.4, angle, 0.6),
			Material = Enum.Material.Neon,
			Color = if i % 2 == 0 then PURPLE else Color3.fromRGB(120, 30, 180),
			Transparency = 0.1,
		}))
		shard:AddTag("Spin")
	end

	-- Разлом: огромное кольцо искр (как портал Доктора Стрэнджа) за спиной босса.
	-- Смотрит на центр карты. Пока Дормамму нет — погашено.
	local outward = flat(CENTER).Unit
	local riftCenter = CENTER + outward * (Places.BossRadius - 8) + Vector3.new(0, 24, 0)
	local facing = CFrame.lookAt(riftCenter, riftCenter - outward)
	local segments = 40
	for s = 1, segments do
		local angle = (s / segments) * math.pi * 2
		local segment = ghost(part({
			Name = "RiftSpark",
			Size = Vector3.new(3.4, 0.6, 0.6),
			CFrame = facing * CFrame.Angles(0, 0, angle) * CFrame.new(0, 21, 0),
			Material = Enum.Material.Neon,
			Color = ORANGE,
			Transparency = 1,
		}))
		table.insert(riftParts, segment)
		if s % 4 == 0 then
			table.insert(
				riftEmitters,
				emitter(segment, {
					Texture = SPARK_TEXTURE,
					Color = ColorSequence.new(Color3.fromRGB(255, 220, 120), ORANGE),
					Size = NumberSequence.new(0.8, 0),
					Lifetime = NumberRange.new(0.3, 0.7),
					Speed = NumberRange.new(10, 18),
					SpreadAngle = Vector2.new(25, 25),
					Acceleration = Vector3.new(0, -25, 0),
					Rate = 0,
				})
			)
		end
	end
	local window = ghost(part({
		Name = "RiftWindow",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 40, 40),
		CFrame = facing * CFrame.Angles(0, math.rad(90), 0),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(70, 10, 110),
		Transparency = 1,
	}))
	table.insert(riftParts, window)
	table.insert(
		riftEmitters,
		emitter(window, {
			Texture = SMOKE_TEXTURE,
			Color = ColorSequence.new(PURPLE, Color3.fromRGB(40, 0, 70)),
			Size = NumberSequence.new(6, 12),
			Transparency = NumberSequence.new(0.5, 1),
			Lifetime = NumberRange.new(2, 3),
			Speed = NumberRange.new(1, 3),
			SpreadAngle = Vector2.new(180, 180),
			Rate = 0,
		})
	)

	-- Обелиск с табличкой и таймером.
	local signBase = CENTER - outward * (Places.BossRadius + 6)
	local obelisk = part({
		Name = "Obelisk",
		Size = Vector3.new(4, 16, 4),
		CFrame = CFrame.new(signBase + Vector3.new(0, 8, 0)) * CFrame.Angles(0, math.rad(45), 0),
		Material = Enum.Material.Basalt,
		Color = OBSIDIAN,
	})
	ghost(part({
		Size = Vector3.new(4.1, 0.5, 4.1),
		CFrame = obelisk.CFrame * CFrame.new(0, 5, 0),
		Material = Enum.Material.Neon,
		Color = ORANGE,
	}))
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(320, 90)
	billboard.StudsOffset = Vector3.new(0, 12, 0)
	billboard.MaxDistance = 400
	billboard.LightInfluence = 0
	billboard.Parent = obelisk
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 0.5)
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextColor3 = PURPLE
	title.TextStrokeTransparency = 0.2
	title.Text = "🔥 Разлом Тёмного измерения"
	title.Parent = billboard
	signLabel = Instance.new("TextLabel")
	signLabel.BackgroundTransparency = 1
	signLabel.Position = UDim2.fromScale(0, 0.52)
	signLabel.Size = UDim2.fromScale(1, 0.45)
	signLabel.Font = Enum.Font.GothamBold
	signLabel.TextScaled = true
	signLabel.TextColor3 = ORANGE
	signLabel.TextStrokeTransparency = 0.3
	signLabel.Text = ""
	signLabel.Parent = billboard

	-- Дорожка из пурпурных плиток от центральной арены к разлому.
	local direction = flat(CENTER).Unit
	local distance = 36
	while distance < flat(CENTER).Magnitude - Places.BossRadius - 2 do
		local position = direction * distance + Vector3.new(0, 0.05, 0)
		ghost(part({
			Name = "RiftPath",
			Size = Vector3.new(2.5, 0.3, 4),
			CFrame = CFrame.lookAt(position, position + direction),
			Material = Enum.Material.Neon,
			Color = PURPLE,
			Transparency = 0.35,
		}))
		distance += 7
	end
end

local function setRift(open: boolean)
	for _, p in riftParts do
		tween(p, 2, { Transparency = if open then (if p.Name == "RiftWindow" then 0.35 else 0) else 1 })
	end
	for _, e in riftEmitters do
		e.Rate = if open then (if e.Texture == SMOKE_TEXTURE then 8 else 25) else 0
	end
end

-- ── Модель Дормамму ────────────────────────────────────────────────────────

local function buildSpecs(
	model: Model,
	root: BasePart,
	specs: { DormammuModel.PartSpec }
): { [string]: { BasePart } }
	local byName: { [string]: { BasePart } } = {}
	for _, spec in specs do
		local look = DormammuModel.Roles[spec.role]
		local p = Instance.new("Part")
		if spec.shape == "Ball" then
			p.Shape = Enum.PartType.Ball
		elseif spec.shape == "Cylinder" then
			p.Shape = Enum.PartType.Cylinder
		elseif spec.shape == "Wedge" then
			p.Shape = Enum.PartType.Wedge
		end
		if spec.shape == "Ellipsoid" then
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = p
		end
		p.Name = spec.name
		p.Size = spec.size
		p.Color = spec.color or look.color
		p.Material = look.material
		p.Transparency = spec.transparency or look.transparency
		p.Anchored = false
		p.Massless = true
		p.CanCollide = false
		p.CanTouch = false
		-- Удары и лучи попадают в «тело», а не в пламя и ауру.
		p.CanQuery = spec.role == "skin" or spec.role == "ridge" or spec.role == "eye"
		p.CastShadow = spec.role == "skin"
		p.CFrame = root.CFrame * spec.cframe
		local weld = Instance.new("Weld")
		weld.Part0 = root
		weld.Part1 = p
		weld.C0 = spec.cframe
		weld.Parent = p
		p.Parent = model
		byName[spec.name] = byName[spec.name] or {}
		table.insert(byName[spec.name], p)
	end
	return byName
end

local function buildDormammu(): (Model, Humanoid, BasePart)
	local model = Instance.new("Model")
	model.Name = "Dormammu"
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(6, 6, 6)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.CFrame = CFrame.new(CENTER + Vector3.new(0, -40, 0))
	root.Parent = model
	model.PrimaryPart = root

	local byName = buildSpecs(model, root, DormammuModel.head())
	local function named(name: string): { BasePart }
		return byName[name] or {}
	end

	-- Глаза светят, из пасти рвётся огонь, над головой — корона пламени из частиц.
	for _, eye in named("Eye") do
		local light = Instance.new("PointLight")
		light.Color = EYE
		light.Range = 22
		light.Brightness = 4
		light.Parent = eye
	end
	for _, mouth in named("MouthFire") do
		fireEmitter(mouth, ORANGE, 30, 3)
		local light = Instance.new("PointLight")
		light.Color = ORANGE
		light.Range = 18
		light.Brightness = 3
		light.Parent = mouth
	end
	local flames = named("Flame")
	for i, flame in flames do
		if i % 3 == 0 then
			fireEmitter(flame, PURPLE, 6, 4)
		end
	end
	for i, flame in named("FlameHot") do
		if i % 2 == 0 then
			fireEmitter(flame, ORANGE, 6, 3)
		end
	end
	-- Большой объёмный излучатель над макушкой.
	local crown = Instance.new("Part")
	crown.Name = "Crown"
	crown.Size = Vector3.new(18, 6, 18)
	crown.Transparency = 1
	crown.Anchored = false
	crown.Massless = true
	crown.CanCollide = false
	crown.CanQuery = false
	crown.CanTouch = false
	crown.CFrame = root.CFrame * CFrame.new(0, 12, 2)
	local crownWeld = Instance.new("Weld")
	crownWeld.Part0 = root
	crownWeld.Part1 = crown
	crownWeld.C0 = CFrame.new(0, 12, 2)
	crownWeld.Parent = crown
	crown.Parent = model
	local crownFire = fireEmitter(crown, PURPLE, 45, 9)
	crownFire.Shape = Enum.ParticleEmitterShape.Box
	crownFire.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	crownFire.Lifetime = NumberRange.new(1, 1.8)
	crownFire.Acceleration = Vector3.new(0, 22, 6)
	local crownHot = fireEmitter(crown, ORANGE, 20, 6)
	crownHot.Shape = Enum.ParticleEmitterShape.Box
	emitter(crown, {
		Texture = SMOKE_TEXTURE,
		Color = ColorSequence.new(Color3.fromRGB(40, 10, 60)),
		LightEmission = 0,
		Size = NumberSequence.new(8, 16),
		Transparency = NumberSequence.new(0.6, 1),
		Lifetime = NumberRange.new(2, 3),
		Speed = NumberRange.new(4, 8),
		Acceleration = Vector3.new(0, 6, 4),
		Rate = 6,
	})
	local glow = Instance.new("PointLight")
	glow.Color = PURPLE
	glow.Range = 60
	glow.Brightness = 3
	glow.Parent = crown

	local humanoid = Instance.new("Humanoid")
	humanoid.DisplayName = "Дормамму"
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.WalkSpeed = 0
	humanoid:SetAttribute("BaseWalkSpeed", 0)
	humanoid.Parent = model

	model:SetAttribute("Boss", true)
	model:SetAttribute("HitRadius", DormammuModel.HitRadius)
	model:SetAttribute("MaxHitDamage", MAX_HIT)
	model:SetAttribute("KillReward", 0)
	model:SetAttribute("Phase", 1)
	return model, humanoid, root
end

local function eyePositions(root: BasePart): { Vector3 }
	return {
		(root.CFrame * CFrame.new(-4.3, 3.3, -11)).Position,
		(root.CFrame * CFrame.new(4.3, 3.3, -11)).Position,
	}
end

local function mouthPosition(root: BasePart): Vector3
	return (root.CFrame * CFrame.new(0, -5.7, -10)).Position
end

-- ── Прислужники: Безликие ──────────────────────────────────────────────────

local function spawnMinion(current: Fight, position: Vector3)
	local description = Instance.new("HumanoidDescription")
	local body = Color3.fromRGB(35, 18, 45)
	description.HeadColor = body
	description.TorsoColor = body
	description.LeftArmColor = body
	description.RightArmColor = body
	description.LeftLegColor = Color3.fromRGB(20, 10, 28)
	description.RightLegColor = Color3.fromRGB(20, 10, 28)
	local ok, created = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok then
		warn(`[BossService] не удалось создать прислужника: {created}`)
		return
	end
	local minion = created :: Model
	minion.Name = "Безликий"
	local humanoid = minion:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.DisplayName = "Безликий"
	humanoid.MaxHealth = 110
	humanoid.Health = 110
	humanoid.WalkSpeed = 15
	humanoid:SetAttribute("BaseWalkSpeed", 15)
	minion:SetAttribute("KillReward", 8)
	minion:AddTag("Enemy")
	minion:AddTag("Minion")

	-- Вместо лица — пурпурное пламя с одной горящей щелью.
	local head = minion:FindFirstChild("Head") :: BasePart?
	if head then
		for _, child in head:GetChildren() do
			if child:IsA("Decal") then
				child:Destroy()
			end
		end
		local function attach(size: Vector3, offset: CFrame, color: Color3, transparency: number): Part
			local p = Instance.new("Part")
			p.Size = size
			p.Color = color
			p.Material = Enum.Material.Neon
			p.Transparency = transparency
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.Massless = true
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = p
			p.CFrame = head.CFrame * offset
			local weld = Instance.new("Weld")
			weld.Part0 = head
			weld.Part1 = p
			weld.C0 = offset
			weld.Parent = p
			p.Parent = minion
			return p
		end
		local flame = attach(Vector3.new(1.6, 2.4, 1.6), CFrame.new(0, 0.5, 0), PURPLE, 0.35)
		attach(Vector3.new(1.1, 0.18, 0.2), CFrame.new(0, 0.05, -0.62), EYE, 0)
		fireEmitter(flame, PURPLE, 14, 1.6)
	end

	minion:PivotTo(CFrame.new(position + Vector3.new(0, 3, 0)))
	minion.Parent = lair
	local root = minion:FindFirstChild("HumanoidRootPart") :: BasePart
	pcall(root.SetNetworkOwner, root, nil)
	table.insert(current.minions, minion)

	humanoid.Died:Connect(function()
		Fx.burst(root.Position, PURPLE, 30, 25, "Smoke")
		task.delay(2, function()
			minion:Destroy()
		end)
	end)

	-- Простой ИИ: идёт к ближайшему игроку у разлома и бьёт вблизи.
	task.spawn(function()
		local lastAttack = 0
		while current.alive and humanoid.Health > 0 and minion.Parent do
			local best: BasePart? = nil
			local bestDistance = math.huge
			for _, player in targetsNear(AGGRO_RADIUS + 20) do
				local target = rootOf(player)
				if target then
					local distance = (target.Position - root.Position).Magnitude
					if distance < bestDistance then
						best, bestDistance = target, distance
					end
				end
			end
			if best then
				humanoid:MoveTo(best.Position)
				if bestDistance < 5.5 and os.clock() - lastAttack > 1.2 then
					lastAttack = os.clock()
					local victim = best.Parent and best.Parent:FindFirstChildOfClass("Humanoid")
					if victim then
						Fx.slash(CFrame.lookAt(root.Position, best.Position), PURPLE, 5)
						Damage.fromNpc(
							victim,
							12,
							{ attackerName = "Безликий", source = "Удар", color = PURPLE }
						)
					end
				end
			end
			if root.Position.Y < -40 then
				humanoid.Health = 0
			end
			task.wait(0.25)
		end
	end)
end

-- ── Атаки ──────────────────────────────────────────────────────────────────

local function aliveMinions(current: Fight): number
	local count = 0
	for i = #current.minions, 1, -1 do
		local minion = current.minions[i]
		local humanoid = minion.Parent and minion:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			count += 1
		else
			table.remove(current.minions, i)
		end
	end
	return count
end

-- Взгляд Дормамму: лучи из глаз прожигают полосу через игрока.
local function eyeBeams(current: Fight, target: Player)
	local targetRoot = rootOf(target)
	if not targetRoot then
		return
	end
	current.focus = target
	local aim = groundAt(targetRoot.Position)
	local across = flat(aim - current.root.Position)
	local direction = if across.Magnitude > 0.1 then across.Unit else Vector3.new(0, 0, 1)
	local from = aim - direction * 14
	local to = aim + direction * 14
	-- Предупреждение: полоса на земле и вспышка глаз.
	local mid = (from + to) / 2 + Vector3.new(0, 0.1, 0)
	local stripe = ghost(part({
		Size = Vector3.new(7, 0.12, 28),
		CFrame = CFrame.lookAt(mid, mid + direction),
		Material = Enum.Material.Neon,
		Color = DANGER,
		Transparency = 0.6,
		Parent = Fx.Folder,
	}))
	Debris:AddItem(stripe, 1)
	for _, eye in eyePositions(current.root) do
		Fx.flash(eye, EYE, 30, 1)
		Fx.sphere(eye, EYE, 1, 5, 0.9)
	end
	Fx.sound("Beam", current.root.Position, 1.4, 0.5)
	task.wait(1)
	local lastHit: { [Humanoid]: number } = {}
	local ticks = 12
	for tick = 0, ticks do
		if not current.alive then
			return
		end
		local point = from:Lerp(to, tick / ticks)
		for _, eye in eyePositions(current.root) do
			Fx.beam(eye, point, EYE, 1.6, 0.14)
			Fx.beam(eye, point, Color3.new(1, 1, 0.8), 0.5, 0.12)
		end
		Fx.burst(point, ORANGE, 8, 30, "Fire")
		if tick % 3 == 0 then
			Fx.ring(point, ORANGE, 4, 0.4)
		end
		for _, player in targetsNear(AGGRO_RADIUS + 20) do
			local root = rootOf(player)
			local humanoid = humanoidOf(player)
			if root and humanoid and (flat(root.Position) - flat(point)).Magnitude < 5 then
				if os.clock() - (lastHit[humanoid] or 0) > 0.4 then
					lastHit[humanoid] = os.clock()
					Damage.fromNpc(humanoid, 14, {
						attackerName = "Дормамму",
						source = "Взгляд Дормамму",
						color = EYE,
					})
				end
			end
		end
		task.wait(0.12)
	end
end

-- Столпы пламени под каждым игроком.
local function flamePillars(current: Fight, targets: { Player })
	local spots = {}
	for i, player in targets do
		if i > 6 then
			break
		end
		local root = rootOf(player)
		if root then
			local spot = groundAt(root.Position)
			table.insert(spots, spot)
			warnCircle(spot, 6, 1.2)
		end
	end
	task.wait(1.2)
	for _, spot in spots do
		if not current.alive then
			return
		end
		Fx.pillar(spot, PURPLE, 70, 1)
		Fx.pillar(spot, ORANGE, 70, 0.6)
		Fx.shockwave(spot, PURPLE, 8)
		Fx.burst(spot + Vector3.new(0, 3, 0), PURPLE, 30, 40, "Fire")
		Fx.flash(spot, PURPLE, 30, 0.6)
		blast(spot, 6, 30, "Столп пламени", 70, PURPLE)
	end
	Fx.sound("Wave", current.root.Position, 1, 0.7)
end

-- Дождь из Тёмного измерения: метеоры по кругам-предупреждениям.
local function meteorRain(current: Fight, targets: { Player })
	local count = 8 + current.phase * 4
	for _ = 1, count do
		if not current.alive then
			return
		end
		local player = targets[math.random(1, #targets)]
		local root = rootOf(player)
		if root then
			local spot = groundAt(root.Position + Vector3.new(math.random(-14, 14), 0, math.random(-14, 14)))
			if (flat(spot) - flat(CENTER)).Magnitude > Places.BossRadius then
				spot = groundAt(CENTER + flat(spot - CENTER).Unit * (Places.BossRadius - 4))
			end
			warnCircle(spot, 5, 1.3, ORANGE)
			Fx.meteor(spot, 1.3)
			task.delay(1.3, function()
				if current.alive then
					Fx.sphere(spot, PURPLE, 2, 12, 0.4)
					Fx.burst(spot, ORANGE, 20, 35, "Fire")
					blast(spot, 6, 22, "Дождь Тёмного измерения", 30)
				end
			end)
		end
		task.wait(0.18)
	end
	task.wait(1.3)
end

-- Рёв: огненная волна расходится кольцом — её нужно перепрыгнуть.
local function roar(current: Fight, targets: { Player })
	callout("⤴ ПРЫГАЙ! Огненная волна!", targets)
	local mouth = mouthPosition(current.root)
	Fx.sphere(mouth, ORANGE, 2, 9, 1)
	Fx.flash(mouth, ORANGE, 40, 1)
	Fx.sound("Wave", current.root.Position, 2, 0.4)
	task.wait(1)
	local origin = groundAt(current.root.Position)
	local segments = 36
	local ring: { Part } = {}
	for _ = 1, segments do
		table.insert(
			ring,
			ghost(part({
				Size = Vector3.new(2.8, 2.6, 0.6),
				Material = Enum.Material.Neon,
				Color = ORANGE,
				Transparency = 0.15,
				CFrame = CFrame.new(origin),
				Parent = Fx.Folder,
			}))
		)
	end
	local hitAlready: { [Humanoid]: boolean } = {}
	local maxRadius = Places.BossRadius + 6
	local steps = 26
	for step = 1, steps do
		local radius = 4 + (maxRadius - 4) * (step / steps)
		for s, segment in ring do
			local angle = (s / segments) * math.pi * 2
			local position = origin + Vector3.new(math.cos(angle) * radius, 1.3, math.sin(angle) * radius)
			segment.Size = Vector3.new(2 * math.pi * radius / segments + 0.4, 2.6, 0.6)
			segment.CFrame = CFrame.lookAt(position, origin + Vector3.new(0, 1.3, 0))
		end
		if step % 4 == 0 then
			Fx.burst(origin + Vector3.new(radius, 1, 0), ORANGE, 6, 20, "Fire")
		end
		for _, player in targetsNear(AGGRO_RADIUS + 20) do
			local root = rootOf(player)
			local humanoid = humanoidOf(player)
			if root and humanoid and not hitAlready[humanoid] then
				local distance = (flat(root.Position) - flat(origin)).Magnitude
				local airborne = root.Position.Y - FLOOR_Y > 4.6
				if math.abs(distance - radius) < 2.5 and not airborne then
					hitAlready[humanoid] = true
					Damage.fromNpc(
						humanoid,
						25,
						{ attackerName = "Дормамму", source = "Рёв", color = ORANGE }
					)
					Damage.knockback(
						root,
						flat(root.Position - origin).Unit * 60 + Vector3.new(0, 30, 0),
						0.25
					)
				end
			end
		end
		task.wait(0.075)
	end
	for _, segment in ring do
		tween(segment, 0.3, { Transparency = 1 })
		Debris:AddItem(segment, 0.35)
	end
end

-- Безликие выходят из порталов вокруг разлома.
local function summon(current: Fight, targets: { Player })
	local count = math.min(MAX_MINIONS - aliveMinions(current), 2 + #targets)
	if count <= 0 then
		return
	end
	callout("Безликие выходят из порталов!", targets)
	for i = 1, count do
		local angle = math.random() * math.pi * 2
		local spot = CENTER + Vector3.new(math.cos(angle), 0, math.sin(angle)) * math.random(16, 34)
		local look = flat(CENTER - spot)
		Fx.portal(spot + Vector3.new(0, 4, 0), look, ORANGE, 4, 1.6)
		Fx.sound("Teleport", spot, 0.8, 0.6)
		task.delay(0.7 + i * 0.1, function()
			if current.alive then
				spawnMinion(current, spot)
			end
		end)
	end
	task.wait(1)
end

-- Руки Тёмного измерения вырываются из земли под игроками (фаза 2+).
local function hands(current: Fight, targets: { Player })
	local picked = {}
	for i, player in targets do
		if i > 2 + (current.phase - 2) then
			break
		end
		local root = rootOf(player)
		if root then
			table.insert(picked, groundAt(root.Position))
		end
	end
	for _, spot in picked do
		warnCircle(spot, 9, 1.5, PURPLE)
	end
	callout("Руки Тёмного измерения!", targets)
	task.wait(1.5)
	for _, spot in picked do
		if not current.alive then
			return
		end
		local handModel = Instance.new("Model")
		handModel.Name = "DarkHand"
		local handRoot = Instance.new("Part")
		handRoot.Anchored = true
		handRoot.Transparency = 1
		handRoot.CanCollide = false
		handRoot.CanQuery = false
		handRoot.CanTouch = false
		handRoot.Size = Vector3.one
		local facing = flat(spot - current.root.Position)
		local yaw = if facing.Magnitude > 0.1 then math.atan2(-facing.X, -facing.Z) else 0
		local down = CFrame.new(spot - Vector3.new(0, 16, 0)) * CFrame.Angles(0, yaw, 0)
		handRoot.CFrame = down
		handRoot.Parent = handModel
		buildSpecs(handModel, handRoot, DormammuModel.hand())
		for _, child in handModel:GetChildren() do
			if child:IsA("BasePart") then
				child.CanQuery = false
			end
		end
		handModel.Parent = Fx.Folder
		tween(handRoot, 0.3, { CFrame = down + Vector3.new(0, 22, 0) }, Enum.EasingStyle.Back)
		Fx.shockwave(spot, PURPLE, 12)
		Fx.dust(spot, 30)
		Fx.burst(spot + Vector3.new(0, 4, 0), PURPLE, 40, 45, "Fire")
		Fx.sound("Wave", spot, 1.4, 0.6)
		blast(spot, 9, 40, "Руки Тёмного измерения", 80, PURPLE)
		task.delay(1.4, function()
			tween(handRoot, 0.6, { CFrame = down }, Enum.EasingStyle.Quad)
			task.wait(0.65)
			handModel:Destroy()
		end)
		task.wait(0.15)
	end
	task.wait(0.8)
end

-- Фаза 3: пламя само бьёт по случайным игрокам.
local function darkDimensionTick(current: Fight)
	local targets = targetsNear()
	if #targets == 0 then
		return
	end
	local root = rootOf(targets[math.random(1, #targets)])
	if not root then
		return
	end
	local spot = groundAt(root.Position + Vector3.new(math.random(-6, 6), 0, math.random(-6, 6)))
	warnCircle(spot, 5, 1, PURPLE)
	task.delay(1, function()
		if current.alive then
			Fx.pillar(spot, PURPLE, 50, 0.7)
			Fx.burst(spot, PURPLE, 15, 25, "Fire")
			blast(spot, 5, 18, "Тёмное измерение", 40, PURPLE)
		end
	end)
end

-- ── Бой ────────────────────────────────────────────────────────────────────

local function announce(title: string, subtitle: string, color: Color3)
	screenFx:FireAllClients("Banner", Vector3.zero, { title = title, subtitle = subtitle, color = color })
end

local function setPhase(current: Fight, phase: number)
	if phase <= current.phase then
		return
	end
	current.phase = phase
	current.model:SetAttribute("Phase", phase)
	bossEvent:FireAllClients("Phase", phase)
	Fx.shockwave(groundAt(current.root.Position), PURPLE, 50)
	Fx.flash(current.root.Position, PURPLE, 80, 1.5)
	Fx.sound("Wave", current.root.Position, 2, 0.35)
	if phase == 2 then
		announce(
			"ДОРМАММУ В ЯРОСТИ",
			"«Ты пришёл умереть». Из земли поднимаются руки!",
			ORANGE
		)
	elseif phase == 3 then
		announce(
			"ТЁМНОЕ ИЗМЕРЕНИЕ",
			"Мир поглощает пламя. Добейте его!",
			PURPLE
		)
	end
end

local function cleanup(current: Fight)
	current.alive = false
	if current.heartbeat then
		current.heartbeat:Disconnect()
	end
	for _, minion in current.minions do
		local humanoid = minion:FindFirstChildOfClass("Humanoid")
		local root = minion:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			Fx.portal(root.Position, Vector3.new(0, 0, 1), ORANGE, 3, 0.8)
		end
		if humanoid then
			humanoid:SetAttribute("Rewarded", true)
		end
		minion:Destroy()
	end
	table.clear(current.minions)
	setRift(false)
	fight = nil
	nextAt = workspace:GetServerTimeNow() + INTERVAL
	bossEvent:FireAllClients("Schedule", nextAt)
end

local function reward(current: Fight)
	local total = 0
	for player, amount in current.damage do
		if player.Parent == Players then
			total += amount
		end
	end
	local ranking: { { player: Player, damage: number } } = {}
	for player, amount in current.damage do
		if player.Parent == Players then
			table.insert(ranking, { player = player, damage = amount })
		end
	end
	table.sort(ranking, function(a, b)
		return a.damage > b.damage
	end)
	local board = {}
	for i, entry in ranking do
		if i > 5 then
			break
		end
		table.insert(board, {
			name = entry.player.DisplayName,
			damage = math.floor(entry.damage),
			share = if total > 0 then entry.damage / total else 0,
		})
	end
	for rank, entry in ranking do
		local share = if total > 0 then entry.damage / total else 0
		local counts = entry.damage >= current.maxHealth * MIN_SHARE_FOR_KILL
		local coins = (100 + math.floor(share * 600) + (if rank == 1 then 150 else 0))
			* DataService:CoinMultiplier(entry.player)
		local xp = Progression.Xp.BossParticipation + math.floor(share * Progression.Xp.BossShare)
		DataService:Update(entry.player, function(data)
			data.Coins += coins
			if counts then
				data.BossKills += 1
			end
		end)
		ProgressionService:AddXp(entry.player, xp)
		bossEvent:FireClient(entry.player, "Defeated", {
			board = board,
			rank = rank,
			damage = math.floor(entry.damage),
			coins = coins,
			xp = xp,
			counts = counts,
		})
	end
	-- Остальным — просто сообщение.
	for _, player in Players:GetPlayers() do
		if not current.damage[player] then
			bossEvent:FireClient(player, "Defeated", { board = board })
		end
	end
end

local function die(current: Fight)
	current.alive = false
	announce(
		"ДОРМАММУ ИЗГНАН",
		"Тёмное измерение закрывается. Награды — по вкладу в урон!",
		ORANGE
	)
	reward(current)
	-- Голова трескается и взрывается вспышками, затем проваливается в разлом.
	local root = current.root
	local parts = {}
	for _, child in current.model:GetChildren() do
		if child:IsA("BasePart") and child.Transparency < 0.5 then
			table.insert(parts, child)
		end
	end
	for _ = 1, 14 do
		local p = parts[math.random(1, math.max(#parts, 1))]
		if p then
			Fx.flash(p.Position, ORANGE, 30, 0.4)
			Fx.burst(p.Position, if math.random() < 0.5 then PURPLE else ORANGE, 25, 35, "Fire")
			Fx.sphere(p.Position, PURPLE, 1, 6, 0.4)
		end
		task.wait(0.15)
	end
	Fx.sphere(root.Position, Color3.new(1, 1, 1), 10, 70, 1.2)
	Fx.shockwave(groundAt(root.Position), ORANGE, 60)
	Fx.flash(root.Position, Color3.new(1, 1, 1), 120, 1.5)
	Fx.sound("Wave", root.Position, 2.5, 0.3)
	tween(root, 2.5, { CFrame = root.CFrame - Vector3.new(0, 45, 0) }, Enum.EasingStyle.Quad)
	task.wait(2.6)
	current.model:Destroy()
	cleanup(current)
end

local function retreat(current: Fight, reason: string)
	current.alive = false
	notify:FireAllClients(
		`🔥 Дормамму ушёл в Тёмное измерение: {reason}`,
		PURPLE
	)
	bossEvent:FireAllClients("Retreat")
	tween(current.root, 3, { CFrame = current.root.CFrame - Vector3.new(0, 45, 0) }, Enum.EasingStyle.Quad)
	task.wait(3.1)
	current.model:Destroy()
	cleanup(current)
end

local function brain(current: Fight)
	-- Появление: поднимается из-под земли.
	task.wait(4.5)
	local lastDarkTick = 0
	local lastAttack = ""
	while current.alive do
		local elapsed = os.clock() - current.started
		local targets = targetsNear()
		if #targets > 0 then
			current.lastSeen = os.clock()
		end
		if elapsed > TIME_LIMIT then
			retreat(current, "время вышло")
			return
		end
		if os.clock() - current.lastSeen > IDLE_LIMIT then
			retreat(current, "рядом никого нет")
			return
		end
		if #targets == 0 then
			task.wait(1)
			continue
		end
		if current.phase >= 3 and os.clock() - lastDarkTick > 2.2 then
			lastDarkTick = os.clock()
			darkDimensionTick(current)
		end

		-- Выбор атаки: по весам, без повтора одной и той же подряд.
		local options: { { id: string, weight: number } } = {
			{ id = "beams", weight = 3 },
			{ id = "pillars", weight = 3 },
			{ id = "meteors", weight = 2 },
			{ id = "roar", weight = 2 },
			{ id = "summon", weight = if aliveMinions(current) < MAX_MINIONS then 2 else 0 },
			{ id = "hands", weight = if current.phase >= 2 then 3 else 0 },
		}
		local sum = 0
		for _, option in options do
			if option.id == lastAttack then
				option.weight = 0
			end
			sum += option.weight
		end
		local roll = math.random() * sum
		local chosen = options[1].id
		for _, option in options do
			roll -= option.weight
			if roll <= 0 and option.weight > 0 then
				chosen = option.id
				break
			end
		end
		lastAttack = chosen
		local focus = targets[math.random(1, #targets)]
		current.focus = focus
		if chosen == "beams" then
			eyeBeams(current, focus)
		elseif chosen == "pillars" then
			flamePillars(current, targets)
		elseif chosen == "meteors" then
			meteorRain(current, targets)
		elseif chosen == "roar" then
			roar(current, targets)
		elseif chosen == "summon" then
			summon(current, targets)
		elseif chosen == "hands" then
			hands(current, targets)
		end
		task.wait(({ 2.6, 2, 1.4 })[current.phase] or 1.4)
	end
end

local function spawnBoss()
	local model, humanoid, root = buildDormammu()
	local fighters = #targetsNear(AGGRO_RADIUS * 2)
	local maxHealth = BASE_HEALTH + HEALTH_PER_PLAYER * math.max(1, fighters)
	humanoid.MaxHealth = maxHealth
	humanoid.Health = maxHealth
	model.Parent = lair
	model:AddTag("Enemy")
	model:AddTag("Boss")

	local current: Fight = {
		model = model,
		humanoid = humanoid,
		root = root,
		damage = {},
		maxHealth = maxHealth,
		phase = 1,
		alive = true,
		focus = nil,
		yaw = math.atan2(flat(CENTER).Unit.X, flat(CENTER).Unit.Z), -- лицом к центру карты
		rise = 0,
		started = os.clock(),
		lastSeen = os.clock(),
		minions = {},
		heartbeat = nil,
	}
	fight = current

	announce(
		"ДОРМАММУ",
		"Властелин Тёмного измерения прорвался в мир! Все к разлому 🔥",
		PURPLE
	)
	bossEvent:FireAllClients("Spawned")
	Fx.shockwave(groundAt(CENTER), PURPLE, 60)
	Fx.sound("Wave", CENTER, 2.5, 0.3)

	-- Движение: подъём из-под земли, покачивание, медленный дрейф, поворот к цели.
	local t = 0
	current.heartbeat = RunService.Heartbeat:Connect(function(dt)
		if not current.alive then
			return
		end
		t += dt
		current.rise = math.min(1, current.rise + dt / 4)
		local eased = 1 - (1 - current.rise) ^ 3
		local height = -40 + (HOVER + 40) * eased
		local drift = Vector3.new(math.cos(t * 0.23) * 6, math.sin(t * 0.9) * 1.4, math.sin(t * 0.23) * 6)
		local position = CENTER + Vector3.new(0, FLOOR_Y + height, 0) + drift
		local focus = current.focus and rootOf(current.focus)
		if focus then
			local toward = flat(focus.Position - position)
			if toward.Magnitude > 1 then
				local goal = math.atan2(-toward.X, -toward.Z)
				local delta = (goal - current.yaw + math.pi) % (math.pi * 2) - math.pi
				current.yaw += delta * math.min(1, dt * 1.8)
			end
		end
		root.CFrame = CFrame.new(position)
			* CFrame.Angles(0, current.yaw, 0)
			* CFrame.Angles(math.rad(-8), 0, 0)
		local ratio = humanoid.Health / maxHealth
		if ratio <= 0.3 then
			setPhase(current, 3)
		elseif ratio <= 0.6 then
			setPhase(current, 2)
		end
	end)

	humanoid.Died:Connect(function()
		if current.alive then
			die(current)
		end
	end)
	task.spawn(brain, current)
end

function BossService:Init()
	bossEvent = Remotes.event("Boss")
	notify = Remotes.event("Notify")
	screenFx = Remotes.event("ScreenFx")
end

function BossService:Start()
	lair = Instance.new("Folder")
	lair.Name = "DarkDimensionRift"
	lair.Parent = workspace
	buildLair()

	Damage.onDamaged(function(attacker, humanoid, dealt)
		local current = fight
		if current and current.alive and humanoid == current.humanoid then
			current.damage[attacker] = (current.damage[attacker] or 0) + dealt
		end
	end)
	Players.PlayerAdded:Connect(function(player)
		bossEvent:FireClient(player, "Schedule", nextAt)
	end)

	nextAt = workspace:GetServerTimeNow() + FIRST_DELAY
	bossEvent:FireAllClients("Schedule", nextAt)
	local warned = false
	while true do
		task.wait(1)
		if fight then
			signLabel.Text = "ДОРМАММУ ЗДЕСЬ!"
			continue
		end
		local left = nextAt - workspace:GetServerTimeNow()
		local seconds = math.max(0, math.floor(left))
		signLabel.Text = string.format("Прорыв через %d:%02d", seconds // 60, seconds % 60)
		if left <= WARNING and not warned then
			warned = true
			setRift(true)
			notify:FireAllClients(
				"🔥 Разлом Тёмного измерения открывается! Дормамму близко…",
				PURPLE
			)
			bossEvent:FireAllClients("Warning", math.floor(left))
		end
		if left <= 0 then
			warned = false
			spawnBoss()
		end
	end
end

return BossService
