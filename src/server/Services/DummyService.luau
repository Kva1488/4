--!strict
-- Манекены для тренировки способностей. Возрождаются через несколько секунд после смерти.

local Players = game:GetService("Players")

local DummyService = {}

local RESPAWN_TIME = 5
local MAX_HEALTH = 150

local SPOTS = {
	Vector3.new(-25, 0, -25),
	Vector3.new(0, 0, -30),
	Vector3.new(25, 0, -25),
	Vector3.new(-35, 0, 10),
	Vector3.new(35, 0, 10),
	Vector3.new(0, 0, 35),
}

local folder: Folder

local function makeDescription(): HumanoidDescription
	local description = Instance.new("HumanoidDescription")
	local skin = Color3.fromRGB(200, 170, 120)
	description.HeadColor = skin
	description.LeftArmColor = skin
	description.RightArmColor = skin
	description.LeftLegColor = Color3.fromRGB(80, 60, 40)
	description.RightLegColor = Color3.fromRGB(80, 60, 40)
	description.TorsoColor = Color3.fromRGB(160, 50, 50)
	return description
end

local function spawnDummy(position: Vector3)
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(makeDescription(), Enum.HumanoidRigType.R15)
	end)
	if not ok then
		warn(`[DummyService] не удалось создать манекен: {model}`)
		return
	end

	local dummy = model :: Model
	dummy.Name = "Манекен"
	local humanoid = dummy:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.DisplayName = "Манекен"
	humanoid.MaxHealth = MAX_HEALTH
	humanoid.Health = MAX_HEALTH
	humanoid.WalkSpeed = 0
	humanoid:SetAttribute("BaseWalkSpeed", 0)
	dummy:AddTag("Enemy")

	local lookAt = Vector3.new(0, position.Y + 3, 0)
	dummy:PivotTo(CFrame.lookAt(position + Vector3.new(0, 3, 0), lookAt))
	dummy.Parent = folder

	local root = dummy:FindFirstChild("HumanoidRootPart") :: BasePart
	pcall(root.SetNetworkOwner, root, nil)

	humanoid.Died:Connect(function()
		task.wait(RESPAWN_TIME)
		dummy:Destroy()
		spawnDummy(position)
	end)
end

function DummyService:Start()
	folder = Instance.new("Folder")
	folder.Name = "Dummies"
	folder.Parent = workspace

	for _, position in SPOTS do
		spawnDummy(position)
	end

	-- Если манекен улетел за карту после отбрасывания — возвращаем его.
	while true do
		task.wait(3)
		for _, dummy in folder:GetChildren() do
			local root = dummy:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and root.Position.Y < -40 then
				local humanoid = dummy:FindFirstChildOfClass("Humanoid")
				if humanoid then
					humanoid.Health = 0
				end
			end
		end
	end
end

return DummyService
