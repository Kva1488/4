--!strict
-- Карта мира:
-- • мини-карта справа сверху: биомы, дорожки, камни (собранные — с галочкой), разлом Дормамму,
--   портал на арену, порталы между зонами и стрелка игрока;
-- • большая карта (клавиша M или кнопка): то же крупно с названиями;
-- • у портала (E) большая карта открывается в режиме перемещения — нажми на портал, чтобы перенестись;
-- • баннер «📍 Вормир» при входе в биом.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Biomes = require(ReplicatedStorage.Shared.Biomes)
local Items = require(ReplicatedStorage.Shared.Items)
local Places = require(ReplicatedStorage.Shared.Places)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local PlayerState = require(script.Parent.Parent.PlayerState)
local Ui = require(script.Parent.Parent.Ui)
local NotifyController = require(script.Parent.NotifyController)

local player = Players.LocalPlayer

local MINI_SIZE = 180
local BIG_SIZE = 560
local TOGGLE_KEY = Enum.KeyCode.M
local GROUND = Color3.fromRGB(120, 72, 52)

local MapController = {}

type Drawn = {
	root: Frame,
	arrow: TextLabel,
	stones: { [string]: Frame },
	size: number,
}

local mini: Drawn
local big: Drawn
local bigPanel: Frame
local bigTitle: TextLabel
local zoneTitle: TextLabel
local zoneSubtitle: TextLabel
local travelMode = false
local travelFunc: RemoteFunction
local currentBiome: string? = nil
local busy = false

-- Мировые координаты → доля карты (0..1). Север (−Z) сверху.
local function toMap(position: Vector3): UDim2
	local half = Biomes.WorldHalf
	return UDim2.fromScale((position.X + half) / (half * 2), (position.Z + half) / (half * 2))
end

local function dot(parent: Instance, position: Vector3, size: number, color: Color3, zIndex: number): Frame
	return Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = toMap(position),
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = color,
		ZIndex = zIndex,
		Parent = parent,
	}, { Ui.round() })
end

local function icon(
	parent: Instance,
	position: Vector3,
	text: string,
	size: number,
	zIndex: number
): TextLabel
	return Ui.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = toMap(position),
		Size = UDim2.fromOffset(size, size),
		Text = text,
		ZIndex = zIndex,
		Parent = parent,
	})
end

-- Линия между двумя точками мира (дорожки).
local function line(parent: Instance, a: Vector3, b: Vector3, mapSize: number, color: Color3)
	local half = Biomes.WorldHalf
	local scale = mapSize / (half * 2)
	local from = Vector2.new(a.X, a.Z) * scale
	local to = Vector2.new(b.X, b.Z) * scale
	local mid = (a + b) / 2
	local length = (to - from).Magnitude
	Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = toMap(mid),
		Size = UDim2.fromOffset(length, if mapSize > 300 then 3 else 2),
		Rotation = math.deg(math.atan2(to.Y - from.Y, to.X - from.X)),
		BackgroundColor3 = color,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = parent,
	})
end

local function travelTo(waystoneId: string)
	if not travelMode or busy then
		return
	end
	busy = true
	local ok, success, message = pcall(travelFunc.InvokeServer, travelFunc, waystoneId)
	busy = false
	if not ok then
		NotifyController.show("Ошибка связи с сервером", Color3.fromRGB(255, 90, 90))
	elseif success then
		Ui.playSound("Purchase", 0.6, 1.4)
		NotifyController.show(message, Biomes.WaystoneById[waystoneId].color)
		Ui.togglePanel("Map", false)
	else
		NotifyController.show(message, Color3.fromRGB(255, 90, 90))
	end
end

local function draw(parent: Instance, mapSize: number): Drawn
	local large = mapSize > 300
	local root = Ui.create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = GROUND,
		ClipsDescendants = true,
		Parent = parent,
	}, {
		Ui.corner(if large then 14 else 12),
		Ui.create("UIGradient", {
			Rotation = 45,
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(170, 150, 150)),
		}),
	})
	local scale = mapSize / (Biomes.WorldHalf * 2)
	-- Дорожки к биомам и к разлому.
	for _, biome in Biomes.List do
		line(root, Vector3.zero, biome.center, mapSize, Items.StoneById[biome.stoneId].color)
	end
	line(root, Vector3.zero, Places.BossCenter, mapSize, Color3.fromRGB(190, 60, 255))
	-- Биомы.
	for _, biome in Biomes.List do
		local circle = Ui.create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = toMap(biome.center),
			Size = UDim2.fromOffset(biome.radius * 2 * scale, biome.radius * 2 * scale),
			BackgroundColor3 = biome.color,
			BackgroundTransparency = 0.55,
			ZIndex = 3,
			Parent = root,
		}, { Ui.round(), Ui.stroke(biome.color, if large then 2 else 1, 0.2) })
		if large then
			Ui.label({
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 1, 2),
				Size = UDim2.fromOffset(140, 18),
				Text = biome.name,
				TextColor3 = Color3.new(1, 1, 1),
				Font = Enum.Font.GothamBlack,
				ZIndex = 8,
				Parent = circle,
			})
		end
	end
	-- Центральная арена, разлом, портал на арену.
	dot(root, Vector3.zero, if large then 14 else 7, Color3.fromRGB(230, 175, 50), 4)
	icon(root, Places.BossCenter, "🔥", if large then 26 else 14, 5)
	icon(root, Places.ArenaPortal + Vector3.new(30, 0, 0), "⚔️", if large then 22 else 12, 5)
	-- Порталы между зонами (на большой карте — кнопки).
	for _, waystone in Biomes.Waystones do
		if large then
			local button = Ui.create("TextButton", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = toMap(waystone.position),
				Size = UDim2.fromOffset(28, 28),
				BackgroundColor3 = Ui.Colors.Panel,
				Text = "🌀",
				TextScaled = true,
				ZIndex = 9,
				Parent = root,
			}, { Ui.round(), Ui.stroke(waystone.color, 2) })
			Ui.bounce(button)
			button.Activated:Connect(function()
				travelTo(waystone.id)
			end)
		else
			dot(root, waystone.position, 5, waystone.color, 5)
		end
	end
	-- Камни (обновляются по данным игрока).
	local stones: { [string]: Frame } = {}
	for _, stone in Items.Stones do
		local biome = Biomes.ByStone[stone.id]
		if biome then
			local gem =
				Ui.gem(stone.color, UDim2.fromOffset(if large then 16 else 8, if large then 16 else 8), root)
			gem.AnchorPoint = Vector2.new(0.5, 0.5)
			gem.Position = toMap(biome.center)
			gem.ZIndex = 6
			Ui.create("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 1.5, Parent = gem })
			Ui.label({
				Name = "Check",
				Size = UDim2.fromScale(1.4, 1.4),
				Position = UDim2.fromScale(-0.2, -0.2),
				Text = "✔",
				TextColor3 = Color3.fromRGB(120, 255, 140),
				Visible = false,
				ZIndex = 7,
				Parent = gem,
			})
			stones[stone.id] = gem
		end
	end
	local arrow = Ui.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(if large then 26 else 16, if large then 26 else 16),
		Text = "▲",
		TextColor3 = Color3.new(1, 1, 1),
		ZIndex = 10,
		Parent = root,
	})
	Ui.create("UIStroke", { Thickness = 2, Parent = arrow })
	return { root = root, arrow = arrow, stones = stones, size = mapSize }
end

local function refreshStones()
	local owned = PlayerState.stones()
	for _, drawn in { mini, big } do
		for stoneId, gem in drawn.stones do
			local check = gem:FindFirstChild("Check") :: TextLabel
			check.Visible = owned[stoneId] == true
			gem.BackgroundTransparency = if owned[stoneId] then 0.5 else 0
		end
	end
end

local zoneToken = 0
local function showZone(biome: Biomes.Biome)
	zoneToken += 1
	local token = zoneToken
	zoneTitle.Text = `📍 {biome.name}`
	zoneTitle.TextColor3 = biome.color
	zoneSubtitle.Text = biome.description
	zoneTitle.TextTransparency = 0
	zoneSubtitle.TextTransparency = 0
	local scale = zoneTitle:FindFirstChildOfClass("UIScale") :: UIScale
	scale.Scale = 0.8
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(3.5, function()
		if token == zoneToken then
			TweenService:Create(zoneTitle, TweenInfo.new(0.6), { TextTransparency = 1 }):Play()
			TweenService:Create(zoneSubtitle, TweenInfo.new(0.6), { TextTransparency = 1 }):Play()
		end
	end)
end

local function setBigVisible(open: boolean)
	bigPanel.Visible = open
	if open then
		bigTitle.Text = if travelMode
			then "🌀 ПОРТАЛЫ — нажми на портал, чтобы перенестись"
			else "🗺️ КАРТА — подойди к порталу 🌀 и нажми E, чтобы перенестись"
		local scale = bigPanel:FindFirstChildOfClass("UIScale") :: UIScale
		scale.Scale = 0.85
		TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	else
		travelMode = false
	end
end

local function build()
	local gui = Ui.create("ScreenGui", {
		Name = "Map",
		ResetOnSpawn = false,
		DisplayOrder = 8,
		Parent = player:WaitForChild("PlayerGui"),
	})
	-- Мини-карта.
	local miniFrame = Ui.create("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 12),
		Size = UDim2.fromOffset(MINI_SIZE, MINI_SIZE),
		BackgroundTransparency = 1,
		Parent = gui,
	}, { Ui.stroke(Ui.Colors.Gold, 2, 0.3), Ui.corner(12) })
	mini = draw(miniFrame, MINI_SIZE)
	local open = Ui.create("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, MINI_SIZE + 16),
		Size = UDim2.fromOffset(MINI_SIZE, 22),
		BackgroundColor3 = Ui.Colors.Panel,
		BackgroundTransparency = 0.2,
		Text = if UserInputService.KeyboardEnabled then "🗺️ Карта [M]" else "🗺️ Карта",
		TextScaled = true,
		Font = Enum.Font.GothamBold,
		TextColor3 = Ui.Colors.Text,
		Parent = gui,
	}, { Ui.corner(8), Ui.padding(3) })
	open.Activated:Connect(function()
		travelMode = false
		Ui.togglePanel("Map")
	end)

	-- Большая карта.
	bigPanel = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(BIG_SIZE + 24, BIG_SIZE + 64),
		BackgroundColor3 = Ui.Colors.Panel,
		BackgroundTransparency = 0.05,
		Visible = false,
		Parent = gui,
	}, { Ui.corner(16), Ui.stroke(Ui.Colors.Gold, 2), Ui.create("UIScale", {}) })
	local fitScale = Ui.create("UIScale", {})
	local wrapper = Ui.create("Frame", {
		Size = UDim2.fromOffset(BIG_SIZE + 24, BIG_SIZE + 64),
		BackgroundTransparency = 1,
		Parent = bigPanel,
	}, { fitScale })
	local function fit()
		local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize
			or Vector2.new(1280, 720)
		local s = math.min(1, (viewport.X - 20) / (BIG_SIZE + 24), (viewport.Y - 40) / (BIG_SIZE + 64))
		bigPanel.Size = UDim2.fromOffset((BIG_SIZE + 24) * s, (BIG_SIZE + 64) * s)
		fitScale.Scale = s
	end
	fit()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end
	bigTitle = Ui.label({
		Position = UDim2.fromOffset(14, 12),
		Size = UDim2.fromOffset(BIG_SIZE - 40, 26),
		Text = "",
		TextColor3 = Ui.Colors.Gold,
		Font = Enum.Font.GothamBlack,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = wrapper,
	})
	local close = Ui.create("TextButton", {
		Position = UDim2.fromOffset(BIG_SIZE - 20, 10),
		Size = UDim2.fromOffset(32, 32),
		BackgroundColor3 = Ui.Colors.PanelLight,
		Text = "✕",
		TextScaled = true,
		Font = Enum.Font.GothamBlack,
		TextColor3 = Color3.new(1, 1, 1),
		Parent = wrapper,
	}, { Ui.corner(8), Ui.padding(6) })
	close.Activated:Connect(function()
		Ui.togglePanel("Map", false)
	end)
	local canvas = Ui.create("Frame", {
		Position = UDim2.fromOffset(12, 50),
		Size = UDim2.fromOffset(BIG_SIZE, BIG_SIZE),
		BackgroundTransparency = 1,
		Parent = wrapper,
	})
	big = draw(canvas, BIG_SIZE)
	Ui.registerPanel("Map", setBigVisible)

	-- Баннер зоны.
	zoneTitle = Ui.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.22),
		Size = UDim2.fromOffset(520, 44),
		Text = "",
		Font = Enum.Font.GothamBlack,
		TextTransparency = 1,
		Parent = gui,
	})
	Ui.create("UIScale", { Parent = zoneTitle })
	Ui.create("UIStroke", { Thickness = 2.5, Transparency = 0.2, Parent = zoneTitle })
	zoneSubtitle = Ui.label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.22, 26),
		Size = UDim2.fromOffset(620, 22),
		Text = "",
		Font = Enum.Font.GothamMedium,
		TextTransparency = 1,
		Parent = gui,
	})
	Ui.create("UIStroke", { Thickness = 1.5, Transparency = 0.3, Parent = zoneSubtitle })
end

function MapController:Init()
	travelFunc = Remotes.func("TravelTo")
end

function MapController:Start()
	build()
	refreshStones()
	PlayerState.Changed:Connect(refreshStones)
	Remotes.event("Travel").OnClientEvent:Connect(function(kind: string)
		if kind == "Open" then
			travelMode = true
			Ui.togglePanel("Map", true)
		end
	end)
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed and input.KeyCode == TOGGLE_KEY then
			travelMode = false
			Ui.togglePanel("Map")
		end
	end)

	local lastZoneCheck = 0
	RunService.RenderStepped:Connect(function()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local camera = workspace.CurrentCamera
		if not root or not camera then
			return
		end
		local look = camera.CFrame.LookVector
		local rotation = math.deg(math.atan2(look.X, -look.Z))
		local onArena = character:GetAttribute("Zone") == "Arena"
		for _, drawn in { mini, big } do
			drawn.arrow.Visible = not onArena
			drawn.arrow.Position = toMap(root.Position)
			drawn.arrow.Rotation = rotation
		end
		if os.clock() - lastZoneCheck > 0.5 then
			lastZoneCheck = os.clock()
			local biome = if onArena then nil else Biomes.at(root.Position)
			local id = biome and biome.id
			if id ~= currentBiome then
				currentBiome = id
				if biome then
					showZone(biome)
				end
			end
		end
	end)
end

return MapController
