--!strict
-- Надевает на правую руку каждого персонажа Перчатку Бесконечности,
-- собранную из ~50 деталей по чертежу Shared/GauntletModel (пальцы, броня, манжета, гнёзда камней).
-- • Скин окрашивает броню (plate), отделка (trim) — тот же цвет темнее.
-- • Собранные камни светятся в своих гнёздах, несобранные — пустые тёмные гнёзда.
-- • Чем больше камней, тем ярче свет перчатки; со всеми шестью появляется аура.
-- • Между кончиками указательного пальца и мизинца натянут шлейф — клиенты включают его во время ударов.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local GauntletModel = require(ReplicatedStorage.Shared.GauntletModel)
local Items = require(ReplicatedStorage.Shared.Items)
local Shop = require(ReplicatedStorage.Shared.Shop)

local DataService = require(script.Parent.DataService)

local GauntletService = {}

local SHAPES: { [string]: Enum.PartType } = {
	Block = Enum.PartType.Block,
	Ball = Enum.PartType.Ball,
	Cylinder = Enum.PartType.Cylinder,
}

local EMPTY_SOCKET = Color3.fromRGB(40, 32, 22)
local DARK_METAL = Color3.fromRGB(45, 36, 30)

-- Как крепить модель к руке: для R15 — к кисти, для R6 — к низу руки.
local function mountFor(character: Model, humanoid: Humanoid): (BasePart?, CFrame, number)
	if humanoid.RigType == Enum.HumanoidRigType.R15 then
		local hand = character:WaitForChild("RightHand", 10)
		if hand and hand:IsA("BasePart") then
			local scale = math.max(hand.Size.X, hand.Size.Z) * 0.95
			return hand, CFrame.new(), scale
		end
	else
		local arm = character:WaitForChild("Right Arm", 10)
		if arm and arm:IsA("BasePart") then
			return arm, CFrame.new(0, -0.6, 0), 0.8
		end
	end
	return nil, CFrame.new(), 1
end

local function makePart(spec: GauntletModel.PartSpec, mount: BasePart, offset: CFrame, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = spec.name
	part.Shape = SHAPES[spec.shape]
	part.Size = spec.size
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CFrame = mount.CFrame * offset * spec.cframe
	part:SetAttribute("Role", spec.role)

	-- Weld с C0 надёжнее WeldConstraint: не зависит от того, где персонаж стоял в момент сборки.
	local weld = Instance.new("Weld")
	weld.Part0 = mount
	weld.Part1 = part
	weld.C0 = offset * spec.cframe
	weld.Parent = part

	part.Parent = parent
	return part
end

-- Шлейф между кончиками указательного пальца и мизинца.
local function addTrail(gauntlet: Model)
	local index = gauntlet:FindFirstChild("Index2") :: BasePart?
	local pinky = gauntlet:FindFirstChild("Pinky2") :: BasePart?
	if not index or not pinky then
		return
	end
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, -index.Size.Y / 2, 0)
	a0.Parent = index
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -pinky.Size.Y / 2, 0)
	a1.Parent = pinky

	local trail = Instance.new("Trail")
	trail.Name = "SwipeTrail"
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.2
	trail.LightEmission = 1
	trail.FaceCamera = true
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.Enabled = false -- включают клиенты на время удара (PoseController)
	trail.Parent = index
end

-- Аура "бесконечности" со всеми шестью камнями: искры всех цветов.
local function addAura(glove: BasePart)
	local keypoints = {}
	for i, stone in Items.Stones do
		table.insert(keypoints, ColorSequenceKeypoint.new((i - 1) / (#Items.Stones - 1), stone.color))
	end
	local attachment = Instance.new("Attachment")
	attachment.Parent = glove
	local aura = Instance.new("ParticleEmitter")
	aura.Name = "InfinityAura"
	aura.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	aura.Color = ColorSequence.new(keypoints)
	aura.LightEmission = 1
	aura.LightInfluence = 0
	aura.Size = NumberSequence.new(0.35, 0)
	aura.Transparency = NumberSequence.new(0.1, 1)
	aura.Lifetime = NumberRange.new(0.5, 1)
	aura.Speed = NumberRange.new(1, 3)
	aura.SpreadAngle = Vector2.new(180, 180)
	aura.Rate = 18
	aura.Enabled = false
	aura.Parent = attachment
end

local function refresh(character: Model, data: Config.PlayerData?)
	local gauntlet = character:FindFirstChild("InfinityGauntlet")
	if not gauntlet then
		return
	end
	local stones = if data then data.Stones else {}
	local skin = Shop.SkinById[if data then data.EquippedSkin else Shop.DefaultSkin]
		or Shop.SkinById[Shop.DefaultSkin]
	local trimColor = skin.color:Lerp(Color3.new(0, 0, 0), 0.38)
	local socketColor = skin.color:Lerp(Color3.new(0, 0, 0), 0.55)
	gauntlet:SetAttribute("Rainbow", skin.rainbow == true)

	for _, part in gauntlet:GetChildren() do
		if not part:IsA("BasePart") then
			continue
		end
		local role = part:GetAttribute("Role")
		if role == "plate" then
			part.Color = skin.color
			part.Material = skin.material
			part.Reflectance = skin.reflectance
		elseif role == "trim" then
			part.Color = trimColor
			part.Material = Enum.Material.Metal
			part.Reflectance = skin.reflectance * 0.5
		elseif role == "socket" then
			part.Color = socketColor
			part.Material = Enum.Material.Metal
		elseif role == "dark" then
			part.Color = DARK_METAL
			part.Material = Enum.Material.Metal
		elseif role == "gem" then
			local stone = Items.StoneById[part.Name]
			local owned = stone ~= nil and stones[part.Name] == true
			part.Color = if owned and stone then stone.color else EMPTY_SOCKET
			part.Material = if owned then Enum.Material.Neon else Enum.Material.Glass
			part.Transparency = if owned then 0 else 0.3
		end
	end

	local count = Items.countStones(stones)
	local glove = gauntlet:FindFirstChild("Glove")
	if glove then
		local light = glove:FindFirstChildOfClass("PointLight")
		if light then
			light.Color = skin.color
			light.Brightness = 0.4 + count * 0.35
			light.Range = 4 + count * 1.5
		end
		local aura = glove:FindFirstChild("InfinityAura", true) :: ParticleEmitter?
		if aura then
			aura.Enabled = count == #Items.Stones
		end
	end
	local trail = gauntlet:FindFirstChild("SwipeTrail", true) :: Trail?
	if trail then
		trail.Color = ColorSequence.new(Color3.new(1, 1, 1), skin.color)
	end
end

local function build(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid or character:FindFirstChild("InfinityGauntlet") then
		return
	end
	-- Перчатка есть только у Таноса.
	local data = DataService:Get(player)
	if data and data.Hero ~= "Thanos" then
		return
	end
	local mount, offset, scale = mountFor(character, humanoid)
	if not mount then
		return
	end

	local gauntlet = Instance.new("Model")
	gauntlet.Name = "InfinityGauntlet"
	for _, spec in GauntletModel.build(scale) do
		makePart(spec, mount, offset, gauntlet)
	end

	-- Стандартную кисть R15 прячем: её полностью заменяет перчатка.
	if mount.Name == "RightHand" then
		mount.Transparency = 1
	end

	local glove = gauntlet:FindFirstChild("Glove") :: BasePart
	local light = Instance.new("PointLight")
	light.Shadows = false
	light.Parent = glove
	addAura(glove)
	addTrail(gauntlet)

	gauntlet.Parent = character
	refresh(character, DataService:Get(player))
end

function GauntletService:Start()
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			build(player, character)
		end)
		if player.Character then
			task.spawn(build, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end

	DataService:OnChanged(function(player, data: Config.PlayerData)
		local character = player.Character
		if not character then
			return
		end
		local gauntlet = character:FindFirstChild("InfinityGauntlet")
		if data.Hero ~= "Thanos" then
			-- Сменили героя: снимаем перчатку и возвращаем обычную кисть.
			if gauntlet then
				gauntlet:Destroy()
				local hand = character:FindFirstChild("RightHand")
				if hand and hand:IsA("BasePart") and not character:GetAttribute("Invisible") then
					hand.Transparency = 0
				end
			end
		elseif not gauntlet then
			task.spawn(build, player, character)
		else
			refresh(character, data)
		end
	end)
end

return GauntletService
