--!strict
-- Надевает на правую руку каждого персонажа Перчатку Бесконечности в выбранном скине.
-- Собранные камни светятся в перчатке, несобранные — пустые гнёзда.
-- Чем больше камней, тем ярче светится перчатка.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Items = require(ReplicatedStorage.Shared.Items)
local Shop = require(ReplicatedStorage.Shared.Shop)

local DataService = require(script.Parent.DataService)

local GauntletService = {}

local EMPTY_SOCKET = Color3.fromRGB(70, 55, 20)

local function weldedPart(
	name: string,
	parent: Instance,
	attachTo: BasePart,
	cframe: CFrame,
	size: Vector3
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = attachTo
	weld.Part1 = part
	weld.Parent = part

	part.Parent = parent
	return part
end

local function refresh(character: Model, data: Config.PlayerData?)
	local gauntlet = character:FindFirstChild("InfinityGauntlet")
	if not gauntlet then
		return
	end
	local stones = if data then data.Stones else {}
	local skin = Shop.SkinById[if data then data.EquippedSkin else Shop.DefaultSkin]
		or Shop.SkinById[Shop.DefaultSkin]

	local glove = gauntlet:FindFirstChild("Glove") :: Part?
	if glove then
		glove.Color = skin.color
		glove.Material = skin.material
		glove.Reflectance = skin.reflectance
		-- Радужный скин переливается на клиентах (GauntletFxController).
		glove:SetAttribute("Rainbow", skin.rainbow == true)
		local light = glove:FindFirstChildOfClass("PointLight")
		if light then
			local count = Items.countStones(stones)
			light.Color = skin.color
			light.Brightness = 0.5 + count * 0.4
			light.Range = 4 + count * 1.5
		end
	end

	for _, stone in Items.Stones do
		local gem = gauntlet:FindFirstChild(stone.id) :: Part?
		if gem then
			local owned = stones[stone.id] == true
			gem.Color = if owned then stone.color else EMPTY_SOCKET
			gem.Material = if owned then Enum.Material.Neon else Enum.Material.Metal
		end
	end
end

local function build(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid or character:FindFirstChild("InfinityGauntlet") then
		return
	end
	local handName = if humanoid.RigType == Enum.HumanoidRigType.R15 then "RightHand" else "Right Arm"
	local hand = character:WaitForChild(handName, 10)
	if not hand or not hand:IsA("BasePart") then
		return
	end

	local folder = Instance.new("Model")
	folder.Name = "InfinityGauntlet"

	-- У R6 рука длинная — надеваем перчатку только на кисть (низ руки).
	local isR6 = hand.Name == "Right Arm"
	local gloveSize = if isR6 then Vector3.new(1.15, 0.8, 1.15) else hand.Size * 1.2
	local gloveCFrame = if isR6 then hand.CFrame * CFrame.new(0, -0.65, 0) else hand.CFrame

	local glove = weldedPart("Glove", folder, hand, gloveCFrame, gloveSize)

	local light = Instance.new("PointLight")
	light.Shadows = false
	light.Parent = glove

	-- Манжета перчатки.
	local cuffCFrame = gloveCFrame * CFrame.new(0, gloveSize.Y * 0.55, 0) * CFrame.Angles(0, 0, math.rad(90))
	local cuff = weldedPart(
		"Cuff",
		folder,
		glove,
		cuffCFrame,
		Vector3.new(gloveSize.Y * 0.25, gloveSize.X * 1.15, gloveSize.Z * 1.15)
	)
	cuff.Shape = Enum.PartType.Cylinder
	cuff.Color = Color3.fromRGB(40, 32, 20)
	cuff.Material = Enum.Material.Metal

	-- Шесть гнёзд для камней: 5 на тыльной стороне, 1 крупный в центре.
	local gemSize = math.min(gloveSize.X, gloveSize.Z) * 0.22
	for i, stone in Items.Stones do
		local offset: Vector3
		if i == 6 then
			offset = Vector3.new(gloveSize.X / 2, 0, 0)
		else
			local t = (i - 3) / 2 -- от -1 до 1
			offset = Vector3.new(gloveSize.X / 2, gloveSize.Y * 0.3, t * gloveSize.Z * 0.35)
		end
		local gem = weldedPart(
			stone.id,
			folder,
			glove,
			glove.CFrame * CFrame.new(offset),
			Vector3.one * (if i == 6 then gemSize * 1.4 else gemSize)
		)
		gem.Shape = Enum.PartType.Ball
	end

	folder.Parent = character

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
		if player.Character then
			refresh(player.Character, data)
		end
	end)
end

return GauntletService
