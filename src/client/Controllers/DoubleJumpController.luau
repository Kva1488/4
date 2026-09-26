--!strict
-- Двойной прыжок для всех героев: второй прыжок в воздухе с кольцом-вспышкой под ногами.
-- Физикой персонажа управляет клиент, поэтому прыжок делается прямо здесь.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local JUMP_VELOCITY = 55

local DoubleJumpController = {}

local usedAirJump = false

local function ring(position: Vector3)
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Cylinder
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromRGB(220, 230, 255)
	part.Transparency = 0.2
	part.Size = Vector3.new(0.2, 2, 2)
	part.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	part.Parent = workspace.CurrentCamera
	TweenService:Create(part, TweenInfo.new(0.35), { Size = Vector3.new(0.2, 7, 7), Transparency = 1 }):Play()
	Debris:AddItem(part, 0.4)
end

local function bind(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not humanoid or not root then
		return
	end
	humanoid.StateChanged:Connect(function(_, new)
		if new == Enum.HumanoidStateType.Landed or new == Enum.HumanoidStateType.Running then
			usedAirJump = false
		end
	end)
	local connection = UserInputService.JumpRequest:Connect(function()
		if humanoid.Health <= 0 or humanoid:GetAttribute("Stunned") then
			return
		end
		local airborne = humanoid.FloorMaterial == Enum.Material.Air
		if airborne and not usedAirJump and humanoid:GetState() ~= Enum.HumanoidStateType.Jumping then
			usedAirJump = true
			local velocity = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = Vector3.new(velocity.X, JUMP_VELOCITY, velocity.Z)
			ring(root.Position - Vector3.new(0, 3, 0))
		end
	end)
	-- Старый персонаж больше не слушает прыжки после респавна.
	character.Destroying:Connect(function()
		connection:Disconnect()
	end)
	humanoid.Died:Connect(function()
		connection:Disconnect()
	end)
end

function DoubleJumpController:Start()
	player.CharacterAdded:Connect(bind)
	if player.Character then
		task.spawn(bind, player.Character)
	end
end

return DoubleJumpController
