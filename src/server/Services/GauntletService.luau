--!strict
-- Надевает на правую руку каждого персонажа золотую Перчатку Бесконечности.
-- Собранные камни светятся в перчатке, несобранные — пустые гнёзда.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Items = require(ReplicatedStorage.Shared.Items)

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

local function refreshGems(character: Model, stones: { [string]: boolean })
	local gauntlet = character:FindFirstChild("InfinityGauntlet")
	if not gauntlet then
		return
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
	glove.Color = Items.Gauntlet.color
	glove.Material = Enum.Material.Metal
	glove.Reflectance = 0.2

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

	local data = DataService:Get(player)
	refreshGems(character, if data then data.Stones else {})
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
			refreshGems(player.Character, data.Stones)
		end
	end)
end

return GauntletService
