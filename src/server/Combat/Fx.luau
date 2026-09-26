--!strict
-- Визуальные эффекты способностей. Создаются на сервере, поэтому их видят все игроки.

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Fx = {}

local folder = workspace:FindFirstChild("Effects") :: Folder?
if not folder then
	local newFolder = Instance.new("Folder")
	newFolder.Name = "Effects"
	newFolder.Parent = workspace
	folder = newFolder
end
Fx.Folder = folder :: Folder

local function basePart(shape: Enum.PartType, color: Color3): Part
	local part = Instance.new("Part")
	part.Shape = shape
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	return part
end

local function tween(instance: Instance, duration: number, goal: { [string]: any }, style: Enum.EasingStyle?)
	TweenService
		:Create(
			instance,
			TweenInfo.new(duration, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			goal
		)
		:Play()
end

-- Расширяющаяся и тающая сфера.
function Fx.sphere(position: Vector3, color: Color3, fromSize: number, toSize: number, duration: number)
	local part = basePart(Enum.PartType.Ball, color)
	part.Size = Vector3.one * fromSize
	part.Position = position
	part.Transparency = 0.2
	part.Parent = Fx.Folder
	tween(part, duration, { Size = Vector3.one * toSize, Transparency = 1 })
	Debris:AddItem(part, duration + 0.1)
	return part
end

-- Плоское кольцо-волна по земле.
function Fx.ring(position: Vector3, color: Color3, radius: number, duration: number)
	local part = basePart(Enum.PartType.Cylinder, color)
	part.Size = Vector3.new(0.4, 2, 2)
	part.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	part.Transparency = 0.1
	part.Parent = Fx.Folder
	tween(part, duration, { Size = Vector3.new(0.4, radius * 2, radius * 2), Transparency = 1 })
	Debris:AddItem(part, duration + 0.1)
	return part
end

-- Луч между двумя точками.
function Fx.beam(from: Vector3, to: Vector3, color: Color3, width: number, duration: number)
	local length = (to - from).Magnitude
	local part = basePart(Enum.PartType.Block, color)
	part.Size = Vector3.new(width, width, length)
	part.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -length / 2)
	part.Parent = Fx.Folder
	tween(part, duration, { Size = Vector3.new(0, 0, length), Transparency = 1 })
	Debris:AddItem(part, duration + 0.1)
	return part
end

-- Облако пылинок (для Щелчка).
function Fx.dust(position: Vector3, count: number)
	for _ = 1, count do
		local part = basePart(Enum.PartType.Block, Color3.fromRGB(90, 70, 55))
		part.Material = Enum.Material.SmoothPlastic
		part.Size = Vector3.one * (0.2 + math.random() * 0.3)
		part.CFrame = CFrame.new(
			position + Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 3
		) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
		part.Parent = Fx.Folder
		local drift = Vector3.new(math.random() * 8 - 4, math.random() * 6 + 2, math.random() * 8 - 4)
		local duration = 1.2 + math.random()
		tween(part, duration, { Position = part.Position + drift, Transparency = 1, Size = Vector3.zero })
		Debris:AddItem(part, duration + 0.1)
	end
end

-- Кристалл-ловушка вокруг цели (Стазис).
function Fx.crystal(position: Vector3, color: Color3, duration: number)
	local part = basePart(Enum.PartType.Block, color)
	part.Material = Enum.Material.Glass
	part.Transparency = 0.45
	part.Size = Vector3.new(5, 7, 5)
	part.CFrame = CFrame.new(position) * CFrame.Angles(0, math.rad(45), 0)
	part.Parent = Fx.Folder
	task.delay(duration, function()
		tween(part, 0.3, { Transparency = 1, Size = Vector3.new(6, 8, 6) })
	end)
	Debris:AddItem(part, duration + 0.4)
	return part
end

return Fx
