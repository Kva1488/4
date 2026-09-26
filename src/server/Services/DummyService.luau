--!strict
-- Манекены для тренировки способностей. Возрождаются через несколько секунд после смерти.

local Players = game:GetService("Players")

local DummyService = {}

local RESPAWN_TIME = 5
local MAX_HEALTH = 150

local SPOTS = {
	-- За пределами центральной арены (радиус 30), между дорожками к биомам.
	Vector3.new(-30, 0, -32),
	Vector3.new(12, 0, -44),
	Vector3.new(30, 0, -40),
	Vector3.new(-52, 0, -14),
	Vector3.new(46, 0, 40),
	Vector3.new(-8, 0, 45),
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

-- Вид тренировочного чучела: мишень на груди и деревянный столб за спиной.
local function decorate(dummy: Model)
	local torso = dummy:FindFirstChild("UpperTorso") or dummy:FindFirstChild("Torso")
	if not torso or not torso:IsA("BasePart") then
		return
	end
	local function welded(
		size: Vector3,
		offset: CFrame,
		color: Color3,
		material: Enum.Material,
		shape: Enum.PartType?
	)
		local part = Instance.new("Part")
		if shape then
			part.Shape = shape
		end
		part.Size = size
		part.Color = color
		part.Material = material
		part.CanCollide = false
		part.CanQuery = false
		part.Massless = true
		part.CFrame = torso.CFrame * offset
		local weld = Instance.new("Weld")
		weld.Part0 = torso
		weld.Part1 = part
		weld.C0 = offset
		weld.Parent = part
		part.Parent = dummy
	end
	local facing = CFrame.Angles(0, math.rad(90), 0) -- ось цилиндра смотрит вперёд
	local rings: { { size: number, color: Color3 } } = {
		{ size = 1.3, color = Color3.fromRGB(230, 230, 230) },
		{ size = 0.9, color = Color3.fromRGB(210, 40, 40) },
		{ size = 0.5, color = Color3.fromRGB(230, 230, 230) },
		{ size = 0.2, color = Color3.fromRGB(210, 40, 40) },
	}
	for i, ring in rings do
		welded(
			Vector3.new(0.05, ring.size, ring.size),
			CFrame.new(0, 0.1, -0.52 - i * 0.01) * facing,
			ring.color,
			Enum.Material.SmoothPlastic,
			Enum.PartType.Cylinder
		)
	end
	welded(
		Vector3.new(0.35, 5, 0.35),
		CFrame.new(0, -1.2, 0.7),
		Color3.fromRGB(110, 75, 45),
		Enum.Material.Wood
	)
	welded(
		Vector3.new(2.6, 0.3, 0.3),
		CFrame.new(0, 0.55, 0.7),
		Color3.fromRGB(110, 75, 45),
		Enum.Material.Wood
	)
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
	decorate(dummy)

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
