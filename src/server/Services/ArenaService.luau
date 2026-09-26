--!strict
-- Летающая арена режимов высоко над центром карты. Попасть туда можно через портал у спавна
-- (кольцо искр, как у Доктора Стрэнджа); выйти — кнопкой «Покинуть арену».
-- Раунды идут по кругу: Царь горы → Захват Перчатки → Схватка. Победитель получает монеты,
-- опыт и победу на арене (титулы), остальные с очками — утешительный приз.
-- Игроки на арене в своей зоне (атрибут Zone = "Arena"): с остальной картой они не дерутся.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ArenaModes = require(ReplicatedStorage.Shared.ArenaModes)
local Items = require(ReplicatedStorage.Shared.Items)
local Places = require(ReplicatedStorage.Shared.Places)
local Progression = require(ReplicatedStorage.Shared.Progression)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Damage = require(script.Parent.Parent.Combat.Damage)
local Fx = require(script.Parent.Parent.Combat.Fx)
local Timeline = require(script.Parent.Parent.Combat.Timeline)
local DataService = require(script.Parent.DataService)
local ProgressionService = require(script.Parent.ProgressionService)

local ArenaService = {}

local MIN_PLAYERS = if RunService:IsStudio() then 1 else 2
local HILL_RADIUS = 9
local HILL_MOVE = 25 -- секунды до переезда круга
local GAUNTLET_RETURN = 12 -- брошенная Перчатка возвращается в центр
local HOLDER_KILL_BONUS = 5
local PORTAL_RADIUS = 5
local REJOIN_COOLDOWN = 3

local CENTER = Places.ArenaCenter
local RADIUS = Places.ArenaRadius
local FLOOR_Y = CENTER.Y

local GOLD = Color3.fromRGB(230, 175, 50)
local ORANGE = Color3.fromRGB(255, 140, 40)
local METAL = Color3.fromRGB(44, 38, 54)
local FLOOR = Color3.fromRGB(36, 30, 44)
local RED = Color3.fromRGB(255, 70, 70)

type Phase = "Waiting" | "Intermission" | "Round" | "Results"

local arenaEvent: RemoteEvent
local notify: RemoteEvent
local screenFx: RemoteEvent
local folder: Folder

local members: { [Player]: boolean } = {}
local scores: { [Player]: number } = {}
local lastLeft: { [Player]: number } = {}
local phase: Phase = "Waiting"
local phaseEnds = 0
local modeIndex = 0
local mode: ArenaModes.Mode = ArenaModes.List[1]

local spawnPoints: { CFrame } = {}
local hills: { Vector3 } = {}
local hillIndex = 1
local hillMovedAt = 0
local hillState = "free"
local hillParts: { BasePart } = {}
local hillLight: PointLight

local gauntlet: Model
local gauntletRoot: BasePart
local holder: Player? = nil
local droppedAt = 0

local portalStatus: TextLabel

-- ── Постройка ──────────────────────────────────────────────────────────────

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CastShadow = false -- арена висит над спавном: без теней на карту
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		if key ~= "Parent" then
			(p :: any)[key] = value
		end
	end
	p.Parent = props.Parent or folder
	return p
end

local function ghost(p: Part): Part
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	return p
end

local function light(parent: Instance, color: Color3, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Parent = parent
	return l
end

local function buildArena()
	local cylinder = CFrame.Angles(0, 0, math.rad(90))
	-- Пол и золотой край.
	part({
		Name = "ArenaFloor",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(4, RADIUS * 2, RADIUS * 2),
		CFrame = CFrame.new(CENTER - Vector3.new(0, 2, 0)) * cylinder,
		Material = Enum.Material.Slate,
		Color = FLOOR,
	})
	for i, radius in { RADIUS - 1, 40, 26, 12 } do
		ghost(part({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.1, radius * 2, radius * 2),
			CFrame = CFrame.new(CENTER + Vector3.new(0, 0.01 + i * 0.01, 0)) * cylinder,
			Material = Enum.Material.Neon,
			Color = GOLD,
			Transparency = 0.45,
		}))
		ghost(part({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.1, radius * 2 - 1.4, radius * 2 - 1.4),
			CFrame = CFrame.new(CENTER + Vector3.new(0, 0.015 + i * 0.01, 0)) * cylinder,
			Material = Enum.Material.Slate,
			Color = FLOOR,
		}))
	end
	-- Лучи цветов камней от центра.
	for i, stone in Items.Stones do
		local angle = (i / #Items.Stones) * math.pi * 2
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local mid = CENTER + direction * (RADIUS / 2) + Vector3.new(0, 0.06, 0)
		ghost(part({
			Size = Vector3.new(0.8, 0.1, RADIUS - 14),
			CFrame = CFrame.lookAt(mid, mid + direction),
			Material = Enum.Material.Neon,
			Color = stone.color,
			Transparency = 0.35,
		}))
	end
	-- Стены по кругу с неоновой кромкой.
	local segments = 48
	for s = 1, segments do
		local angle = (s / segments) * math.pi * 2
		local position = CENTER + Vector3.new(math.cos(angle), 0, math.sin(angle)) * (RADIUS + 1)
		local chord = 2 * math.pi * (RADIUS + 1) / segments + 0.3
		local facing = CFrame.lookAt(position + Vector3.new(0, 5, 0), CENTER + Vector3.new(0, 5, 0))
		part({
			Name = "Wall",
			Size = Vector3.new(chord, 10, 2),
			CFrame = facing,
			Material = Enum.Material.Metal,
			Color = METAL,
		})
		ghost(part({
			Size = Vector3.new(chord, 0.5, 2.1),
			CFrame = facing * CFrame.new(0, 5, 0),
			Material = Enum.Material.Neon,
			Color = if s % 2 == 0 then GOLD else ORANGE,
		}))
		-- Трибуны за стеной (две ступени).
		for tier = 1, 2 do
			local out = CENTER + Vector3.new(math.cos(angle), 0, math.sin(angle)) * (RADIUS + 3 + tier * 3.5)
			part({
				Size = Vector3.new(chord * (1 + tier * 0.12), 8 + tier * 5, 3.6),
				CFrame = CFrame.lookAt(out + Vector3.new(0, (8 + tier * 5) / 2 - 2, 0), CENTER),
				Material = Enum.Material.Concrete,
				Color = Color3.fromRGB(60, 52, 70),
			})
		end
	end
	-- Башни с огнями.
	for t = 1, 8 do
		local angle = (t / 8) * math.pi * 2 + math.pi / 8
		local base = CENTER + Vector3.new(math.cos(angle), 0, math.sin(angle)) * (RADIUS + 12)
		part({
			Name = "Tower",
			Size = Vector3.new(6, 34, 6),
			CFrame = CFrame.new(base + Vector3.new(0, 15, 0)) * CFrame.Angles(0, angle, 0),
			Material = Enum.Material.Metal,
			Color = METAL,
		})
		local beacon = ghost(part({
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 4,
			CFrame = CFrame.new(base + Vector3.new(0, 34, 0)),
			Material = Enum.Material.Neon,
			Color = Items.Stones[(t - 1) % #Items.Stones + 1].color,
		}))
		light(beacon, beacon.Color, 40, 3)
		ghost(part({
			Size = Vector3.new(0.4, 28, 3),
			CFrame = CFrame.new(base + Vector3.new(0, 15, 0))
				* CFrame.Angles(0, angle, 0)
				* CFrame.new(3.1, 0, 0),
			Material = Enum.Material.Neon,
			Color = beacon.Color,
			Transparency = 0.2,
		}))
	end
	-- Каменный остров снизу — арена «парит».
	for i = 1, 9 do
		local angle = (i / 9) * math.pi * 2
		local distance = if i == 1 then 0 else 24
		local size = if i == 1 then 70 else 38 - (i % 3) * 6
		part({
			Name = "IslandRock",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * size,
			CFrame = CFrame.new(
				CENTER + Vector3.new(math.cos(angle) * distance, -size * 0.5 - 2, math.sin(angle) * distance)
			),
			Material = Enum.Material.Rock,
			Color = Color3.fromRGB(95, 60, 55),
			CanCollide = false,
		})
	end
	for i = 1, 10 do
		local angle = (i / 10) * math.pi * 2
		local stone = Items.Stones[(i - 1) % #Items.Stones + 1]
		local crystal = ghost(part({
			Size = Vector3.new(2, 9, 2),
			CFrame = CFrame.new(CENTER + Vector3.new(math.cos(angle) * 30, -22, math.sin(angle) * 30))
				* CFrame.Angles(0, 0, math.rad(180 + (i % 3) * 8)),
			Material = Enum.Material.Neon,
			Color = stone.color,
		}))
		light(crystal, stone.color, 25, 2)
	end

	-- Точки возрождения по кругу лицом к центру.
	for i = 1, 10 do
		local angle = (i / 10) * math.pi * 2
		local position = CENTER
			+ Vector3.new(math.cos(angle), 0, math.sin(angle)) * (RADIUS - 10)
			+ Vector3.new(0, 3, 0)
		table.insert(spawnPoints, CFrame.lookAt(position, CENTER + Vector3.new(0, 3, 0)))
	end

	-- Холмы «Царя горы»: центр и два места по бокам.
	hills = {
		CENTER,
		CENTER + Vector3.new(26, 0, 18),
		CENTER + Vector3.new(-24, 0, -20),
	}
	local ring = ghost(part({
		Name = "HillRing",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, HILL_RADIUS * 2, HILL_RADIUS * 2),
		CFrame = CFrame.new(CENTER + Vector3.new(0, 0.1, 0)) * cylinder,
		Material = Enum.Material.Neon,
		Color = Color3.new(1, 1, 1),
		Transparency = 1,
	}))
	local column = ghost(part({
		Name = "HillColumn",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(40, HILL_RADIUS * 2, HILL_RADIUS * 2),
		CFrame = CFrame.new(CENTER + Vector3.new(0, 20, 0)) * cylinder,
		Material = Enum.Material.Neon,
		Color = Color3.new(1, 1, 1),
		Transparency = 1,
	}))
	hillParts = { ring, column }
	hillLight = light(ring, Color3.new(1, 1, 1), 30, 0)
end

-- Перчатка Бесконечности для режима захвата: золотая рука с шестью камнями.
local function buildGauntlet()
	gauntlet = Instance.new("Model")
	gauntlet.Name = "ArenaGauntlet"
	gauntletRoot = Instance.new("Part")
	gauntletRoot.Name = "Root"
	gauntletRoot.Size = Vector3.new(1, 1, 1)
	gauntletRoot.Transparency = 1
	gauntletRoot.Anchored = true
	gauntletRoot.CanCollide = false
	gauntletRoot.CanQuery = false
	gauntletRoot.CanTouch = false
	gauntletRoot.Massless = true
	gauntletRoot.CFrame = CFrame.new(CENTER + Vector3.new(0, 4, 0))
	gauntletRoot.Parent = gauntlet
	gauntlet.PrimaryPart = gauntletRoot

	local function piece(
		size: Vector3,
		offset: CFrame,
		color: Color3,
		material: Enum.Material,
		ellipsoid: boolean?
	)
		local p = Instance.new("Part")
		p.Size = size
		p.Color = color
		p.Material = material
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.Anchored = false
		p.CastShadow = false
		if ellipsoid then
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = p
		end
		p.CFrame = gauntletRoot.CFrame * offset
		local weld = Instance.new("Weld")
		weld.Part0 = gauntletRoot
		weld.Part1 = p
		weld.C0 = offset
		weld.Parent = p
		p.Parent = gauntlet
		return p
	end
	local metal = Enum.Material.Metal
	piece(Vector3.new(1.8, 1.6, 0.9), CFrame.new(0, 0, 0), GOLD, metal, true) -- кисть
	piece(Vector3.new(1.4, 1.6, 1.3), CFrame.new(0, -1.3, 0), GOLD, metal, true) -- манжета
	for f = 1, 4 do
		piece(Vector3.new(0.36, 1.3, 0.4), CFrame.new(-0.6 + (f - 1) * 0.4, 1.3, 0), GOLD, metal)
	end
	piece(
		Vector3.new(0.4, 0.9, 0.4),
		CFrame.new(-1, 0.4, -0.2) * CFrame.Angles(0, 0, math.rad(40)),
		GOLD,
		metal
	)
	for i, stone in Items.Stones do
		local offset = if i <= 4
			then CFrame.new(-0.6 + (i - 1) * 0.4, 0.75, -0.25)
			elseif i == 5 then CFrame.new(-0.85, 0.2, -0.4)
			else CFrame.new(0, 0, -0.5)
		local size = if i == 6 then 0.55 else 0.28
		local gem = piece(Vector3.one * size, offset, stone.color, Enum.Material.Neon)
		gem.Shape = Enum.PartType.Ball
	end
	light(gauntletRoot, GOLD, 22, 3)
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Color = ColorSequence.new(Color3.fromRGB(255, 230, 150), GOLD)
	sparkle.LightEmission = 1
	sparkle.Size = NumberSequence.new(0.5, 0)
	sparkle.Lifetime = NumberRange.new(0.6, 1)
	sparkle.Speed = NumberRange.new(2, 4)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Rate = 20
	sparkle.Parent = gauntletRoot
	gauntlet.Parent = folder
	-- Прячем до режима захвата.
	gauntlet:PivotTo(CFrame.new(CENTER - Vector3.new(0, 40, 0)))
end

-- Портал на арену у спавна: вертикальное кольцо оранжевых искр лицом к центру карты.
local function buildPortal()
	local base = Places.ArenaPortal
	local center = base + Vector3.new(0, 7, 0)
	local facing = CFrame.lookAt(center, center - (base * Vector3.new(1, 0, 1)).Unit)
	local segments = 24
	for s = 1, segments do
		local angle = (s / segments) * math.pi * 2
		local spark = ghost(part({
			Size = Vector3.new(1.8, 0.35, 0.35),
			CFrame = facing * CFrame.Angles(0, 0, angle) * CFrame.new(0, 6, 0),
			Material = Enum.Material.Neon,
			Color = ORANGE,
		}))
		if s % 3 == 0 then
			local e = Instance.new("ParticleEmitter")
			e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			e.Color = ColorSequence.new(Color3.fromRGB(255, 220, 120), ORANGE)
			e.LightEmission = 1
			e.Size = NumberSequence.new(0.5, 0)
			e.Lifetime = NumberRange.new(0.3, 0.6)
			e.Speed = NumberRange.new(6, 12)
			e.Acceleration = Vector3.new(0, -20, 0)
			e.SpreadAngle = Vector2.new(20, 20)
			e.Rate = 15
			e.Parent = spark
		end
	end
	local window = ghost(part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, 11, 11),
		CFrame = facing * CFrame.Angles(0, math.rad(90), 0),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 180, 90),
		Transparency = 0.55,
	}))
	light(window, ORANGE, 24, 3)
	part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, 14, 14),
		CFrame = CFrame.new(base + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Marble,
		Color = Color3.fromRGB(176, 158, 148),
	})
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(300, 80)
	billboard.StudsOffset = Vector3.new(0, 8, 0)
	billboard.MaxDistance = 200
	billboard.LightInfluence = 0
	billboard.Parent = window
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 0.55)
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextColor3 = GOLD
	title.TextStrokeTransparency = 0.2
	title.Text = "⚔️ АРЕНА РЕЖИМОВ"
	title.Parent = billboard
	portalStatus = Instance.new("TextLabel")
	portalStatus.BackgroundTransparency = 1
	portalStatus.Position = UDim2.fromScale(0, 0.58)
	portalStatus.Size = UDim2.fromScale(1, 0.4)
	portalStatus.Font = Enum.Font.GothamBold
	portalStatus.TextScaled = true
	portalStatus.TextColor3 = Color3.new(1, 1, 1)
	portalStatus.TextStrokeTransparency = 0.3
	portalStatus.Text = "Войди в портал"
	portalStatus.Parent = billboard
end

-- ── Участники ──────────────────────────────────────────────────────────────

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function isAlive(player: Player): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

local function memberCount(): number
	local count = 0
	for _ in members do
		count += 1
	end
	return count
end

local function toSpawn(player: Player)
	local character = player.Character
	if not character then
		return
	end
	character:SetAttribute("Zone", "Arena")
	Timeline.clear(player)
	character:PivotTo(spawnPoints[math.random(1, #spawnPoints)])
	local shield = Instance.new("ForceField")
	shield.Visible = true
	shield.Parent = character
	task.delay(2, function()
		shield:Destroy()
	end)
end

local function setHighlight(player: Player, on: boolean)
	local character = player.Character
	if not character then
		return
	end
	local existing = character:FindFirstChild("GauntletHolder")
	if on and not existing then
		local highlight = Instance.new("Highlight")
		highlight.Name = "GauntletHolder"
		highlight.FillColor = GOLD
		highlight.FillTransparency = 0.7
		highlight.OutlineColor = Color3.fromRGB(255, 240, 180)
		highlight.Parent = character
	elseif not on and existing then
		existing:Destroy()
	end
end

-- Бросить Перчатку там, где стоит держатель (или вернуть в центр).
local function dropGauntlet(at: Vector3?)
	local previous = holder
	holder = nil
	if previous then
		setHighlight(previous, false)
	end
	for _, weld in gauntletRoot:GetChildren() do
		if weld:IsA("WeldConstraint") then
			weld:Destroy()
		end
	end
	gauntletRoot.Anchored = true
	local spot = at or CENTER
	local offset = (spot - CENTER) * Vector3.new(1, 0, 1)
	if offset.Magnitude > RADIUS - 6 then
		offset = offset.Unit * (RADIUS - 6)
	end
	gauntlet:PivotTo(CFrame.new(CENTER + offset + Vector3.new(0, 4, 0)))
	droppedAt = os.clock()
end

local function pickUp(player: Player)
	local root = rootOf(player)
	if not root then
		return
	end
	holder = player
	gauntletRoot.Anchored = false
	gauntlet:PivotTo(root.CFrame * CFrame.new(0, 4.5, 0))
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = gauntletRoot
	weld.Parent = gauntletRoot
	setHighlight(player, true)
	Fx.burst(root.Position, GOLD, 40, 30)
	Fx.flash(root.Position, GOLD, 30, 0.6)
	for member in members do
		notify:FireClient(member, `🧤 {player.DisplayName} схватил Перчатку!`, GOLD)
	end
end

local function leave(player: Player, silent: boolean?)
	if not members[player] then
		return
	end
	members[player] = nil
	scores[player] = nil
	lastLeft[player] = os.clock()
	if holder == player then
		local root = rootOf(player)
		dropGauntlet(root and root.Position)
	end
	local character = player.Character
	if character then
		character:SetAttribute("Zone", nil)
		Timeline.clear(player)
		local exit = Places.ArenaPortal
			- (Places.ArenaPortal * Vector3.new(1, 0, 1)).Unit * 9
			+ Vector3.new(0, 3, 0)
		character:PivotTo(CFrame.new(exit))
	end
	if not silent then
		arenaEvent:FireClient(player, "Left")
		notify:FireClient(player, "Ты покинул арену", Color3.fromRGB(200, 200, 220))
	end
end

local function join(player: Player)
	if members[player] or not isAlive(player) then
		return
	end
	if os.clock() - (lastLeft[player] or 0) < REJOIN_COOLDOWN then
		return
	end
	members[player] = true
	scores[player] = 0
	local root = rootOf(player)
	if root then
		Fx.portal(root.Position, root.CFrame.LookVector, ORANGE, 4, 0.8)
		Fx.sound("Teleport", root.Position, 1, 0.8)
	end
	toSpawn(player)
	notify:FireClient(player, `⚔️ Ты на арене! Сейчас: {mode.icon} {mode.name}`, GOLD)
end

-- ── Раунды ─────────────────────────────────────────────────────────────────

local function hillOccupants(): { Player }
	local list = {}
	local hill = hills[hillIndex]
	for player in members do
		local root = rootOf(player)
		if root and isAlive(player) then
			local offset = root.Position - hill
			if (offset * Vector3.new(1, 0, 1)).Magnitude <= HILL_RADIUS and offset.Y < 10 then
				table.insert(list, player)
			end
		end
	end
	return list
end

local function showHill(visible: boolean)
	local hill = hills[hillIndex]
	local cylinder = CFrame.Angles(0, 0, math.rad(90))
	hillParts[1].CFrame = CFrame.new(hill + Vector3.new(0, 0.1, 0)) * cylinder
	hillParts[2].CFrame = CFrame.new(hill + Vector3.new(0, 20, 0)) * cylinder
	hillParts[1].Transparency = if visible then 0.2 else 1
	hillParts[2].Transparency = if visible then 0.85 else 1
	hillLight.Brightness = if visible then 3 else 0
end

local function paintHill(state: string)
	hillState = state
	local color = if state == "held" then GOLD elseif state == "contested" then RED else Color3.new(1, 1, 1)
	for _, p in hillParts do
		p.Color = color
	end
	hillLight.Color = color
end

local function standings(): { { name: string, score: number, player: Player } }
	local list = {}
	for player, score in scores do
		if members[player] then
			table.insert(list, { name = player.DisplayName, score = score, player = player })
		end
	end
	table.sort(list, function(a, b)
		return a.score > b.score
	end)
	return list
end

local function broadcast()
	local list = standings()
	local top = {}
	for i, entry in list do
		if i > 6 then
			break
		end
		table.insert(top, { name = entry.name, score = entry.score })
	end
	local base = {
		phase = phase,
		mode = mode.id,
		timeLeft = math.max(0, math.ceil(phaseEnds - os.clock())),
		goal = mode.goal,
		top = top,
		count = memberCount(),
		min = MIN_PLAYERS,
		hill = if phase == "Round" and mode.id == "KingOfHill" then hills[hillIndex] else nil,
		hillState = hillState,
		holder = if holder then holder.DisplayName else nil,
	}
	for player in members do
		local payload = table.clone(base)
		payload.myScore = scores[player] or 0
		arenaEvent:FireClient(player, "State", payload)
	end
	-- Табличка у портала.
	if phase == "Round" then
		portalStatus.Text = `Идёт: {mode.icon} {mode.name} · игроков: {memberCount()}`
	elseif phase == "Waiting" then
		portalStatus.Text = `Ждём игроков: {memberCount()}/{MIN_PLAYERS}`
	else
		portalStatus.Text = `Скоро: {mode.icon} {mode.name} · игроков: {memberCount()}`
	end
end

local function banner(title: string, subtitle: string, color: Color3)
	for player in members do
		screenFx:FireClient(
			player,
			"Banner",
			Vector3.zero,
			{ title = title, subtitle = subtitle, color = color }
		)
	end
end

local function startRound()
	phase = "Round"
	phaseEnds = os.clock() + mode.duration
	for player in members do
		scores[player] = 0
		toSpawn(player)
	end
	if mode.id == "KingOfHill" then
		hillIndex = 1
		hillMovedAt = os.clock()
		paintHill("free")
		showHill(true)
	elseif mode.id == "Gauntlet" then
		dropGauntlet(CENTER)
	end
	banner(`{mode.icon} {mode.name}`, mode.description, mode.color)
	for player in members do
		arenaEvent:FireClient(player, "RoundStart", mode.id)
	end
end

local function endRound()
	phase = "Results"
	phaseEnds = os.clock() + ArenaModes.ResultsTime
	showHill(false)
	if holder then
		setHighlight(holder, false)
	end
	dropGauntlet(CENTER)
	gauntlet:PivotTo(CFrame.new(CENTER - Vector3.new(0, 40, 0)))

	local list = standings()
	local winner = list[1]
	if winner and winner.score > 0 then
		local player = winner.player
		DataService:Update(player, function(data)
			data.Coins += ArenaModes.WinCoins
			data.ArenaWins += 1
		end)
		ProgressionService:AddXp(player, Progression.Xp.ArenaWin)
		local root = rootOf(player)
		if root then
			Fx.pillar(root.Position - Vector3.new(0, 3, 0), GOLD, 60, 2)
			Fx.burst(root.Position, GOLD, 80, 40)
		end
		banner(
			`🏆 {winner.name} ПОБЕДИЛ`,
			`{mode.icon} {mode.name}: {winner.score} очк. Награда: +{ArenaModes.WinCoins} монет`,
			GOLD
		)
	else
		banner("Ничья", "Никто не набрал очков", Color3.fromRGB(200, 200, 220))
	end
	for _, entry in list do
		if entry ~= winner and entry.score > 0 then
			DataService:Update(entry.player, function(data)
				data.Coins += ArenaModes.ParticipationCoins
			end)
			ProgressionService:AddXp(entry.player, Progression.Xp.ArenaParticipation)
		end
	end
	local board = {}
	for i, entry in list do
		if i > 6 then
			break
		end
		table.insert(board, { name = entry.name, score = entry.score })
	end
	for player in members do
		arenaEvent:FireClient(player, "RoundEnd", {
			mode = mode.id,
			winner = if winner and winner.score > 0 then winner.name else nil,
			board = board,
		})
	end
end

local function nextMode()
	modeIndex = modeIndex % #ArenaModes.List + 1
	mode = ArenaModes.List[modeIndex]
end

-- Очки каждую секунду: удержание холма и Перчатки.
local function scoreTick()
	if phase ~= "Round" then
		return
	end
	if mode.id == "KingOfHill" then
		if os.clock() - hillMovedAt > HILL_MOVE then
			hillMovedAt = os.clock()
			hillIndex = hillIndex % #hills + 1
			showHill(true)
			for player in members do
				notify:FireClient(player, "👑 Круг переехал!", GOLD)
			end
		end
		local occupants = hillOccupants()
		if #occupants == 1 then
			local king = occupants[1]
			scores[king] = (scores[king] or 0) + 1
			paintHill("held")
		elseif #occupants > 1 then
			paintHill("contested")
		else
			paintHill("free")
		end
	elseif mode.id == "Gauntlet" then
		if holder then
			scores[holder] = (scores[holder] or 0) + 1
			local root = rootOf(holder)
			if root then
				Fx.burst(root.Position + Vector3.new(0, 4.5, 0), GOLD, 6, 10)
			end
		end
	end
	for player, score in scores do
		if members[player] and score >= mode.goal then
			phaseEnds = os.clock() -- досрочная победа
		end
	end
end

-- Перчатку подбирают, подойдя вплотную (проверяем чаще, чем раз в секунду).
local function gauntletTick()
	if phase ~= "Round" or mode.id ~= "Gauntlet" then
		return
	end
	if holder then
		if not members[holder] or not isAlive(holder) then
			local root = rootOf(holder)
			dropGauntlet(root and root.Position)
		end
		return
	end
	if os.clock() - droppedAt > GAUNTLET_RETURN and (gauntletRoot.Position - CENTER).Magnitude > 6 then
		dropGauntlet(CENTER)
		return
	end
	-- Перчатка покачивается, пока лежит.
	local base = gauntletRoot.Position * Vector3.new(1, 0, 1) + Vector3.new(0, FLOOR_Y + 4, 0)
	gauntlet:PivotTo(
		CFrame.new(base + Vector3.new(0, math.sin(os.clock() * 2) * 0.6, 0))
			* CFrame.Angles(0, os.clock() * 1.5, 0)
	)
	for player in members do
		local root = rootOf(player)
		if root and isAlive(player) and (root.Position - gauntletRoot.Position).Magnitude < 5 then
			pickUp(player)
			return
		end
	end
end

local function loop()
	local lastScore = 0
	local lastBroadcast = 0
	while true do
		local now = os.clock()
		local count = memberCount()
		if phase == "Waiting" then
			if count >= MIN_PLAYERS then
				nextMode()
				phase = "Intermission"
				phaseEnds = now + ArenaModes.Intermission
				banner(`Скоро: {mode.icon} {mode.name}`, mode.description, mode.color)
			end
		elseif phase == "Intermission" then
			if count < MIN_PLAYERS then
				phase = "Waiting"
			elseif now >= phaseEnds then
				startRound()
			end
		elseif phase == "Round" then
			if count == 0 or now >= phaseEnds then
				endRound()
			end
		elseif phase == "Results" then
			if now >= phaseEnds then
				if memberCount() >= MIN_PLAYERS then
					nextMode()
					phase = "Intermission"
					phaseEnds = now + ArenaModes.Intermission
					banner(`Скоро: {mode.icon} {mode.name}`, mode.description, mode.color)
				else
					phase = "Waiting"
				end
			end
		end

		-- Упал с арены — обратно на точку возрождения.
		for player in members do
			local root = rootOf(player)
			if root and root.Position.Y < FLOOR_Y - 30 then
				if holder == player then
					dropGauntlet(CENTER)
				end
				toSpawn(player)
			end
		end
		-- Вход через портал.
		for _, player in Players:GetPlayers() do
			if not members[player] then
				local root = rootOf(player)
				if root then
					local offset = root.Position - (Places.ArenaPortal + Vector3.new(0, 7, 0))
					if
						(offset * Vector3.new(1, 0, 1)).Magnitude < PORTAL_RADIUS
						and math.abs(offset.Y) < 7
					then
						task.spawn(join, player)
					end
				end
			end
		end

		gauntletTick()
		if now - lastScore >= 1 then
			lastScore = now
			scoreTick()
		end
		if now - lastBroadcast >= 0.5 then
			lastBroadcast = now
			broadcast()
		end
		task.wait(0.1)
	end
end

function ArenaService:IsMember(player: Player): boolean
	return members[player] == true
end

function ArenaService:Init()
	arenaEvent = Remotes.event("Arena")
	notify = Remotes.event("Notify")
	screenFx = Remotes.event("ScreenFx")
	Remotes.event("ArenaLeave").OnServerEvent:Connect(function(player)
		leave(player)
	end)
end

function ArenaService:Start()
	folder = Instance.new("Folder")
	folder.Name = "ModeArena"
	folder.Parent = workspace
	buildArena()
	buildGauntlet()
	buildPortal()

	-- Очки за убийства на арене.
	Damage.onKilled(function(attacker, victim)
		local victimPlayer = Players:GetPlayerFromCharacter(victim.Parent)
		if phase ~= "Round" or not members[attacker] or not victimPlayer or not members[victimPlayer] then
			return
		end
		if mode.id == "Deathmatch" then
			scores[attacker] = (scores[attacker] or 0) + 1
		elseif mode.id == "Gauntlet" and victimPlayer == holder then
			scores[attacker] = (scores[attacker] or 0) + HOLDER_KILL_BONUS
			notify:FireClient(
				attacker,
				`🧤 Держатель повержен! +{HOLDER_KILL_BONUS} очков`,
				GOLD
			)
		end
	end)

	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			if not members[player] then
				return
			end
			character:SetAttribute("Zone", "Arena")
			character:WaitForChild("HumanoidRootPart", 10)
			task.wait(0.15)
			if members[player] and player.Character == character then
				toSpawn(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		leave(player, true)
		lastLeft[player] = nil
	end)

	loop()
end

return ArenaService
