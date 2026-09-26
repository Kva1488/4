--!strict
-- Визуальные и звуковые эффекты способностей. Создаются на сервере, поэтому их видят все игроки.
-- Частицы рисуют клиенты по событию "Burst" (встроенные текстуры Roblox, без внешних ассетов).

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sounds = require(ReplicatedStorage.Shared.Sounds)

local Fx = {}

local folder = workspace:FindFirstChild("Effects") :: Folder?
if not folder then
	local newFolder = Instance.new("Folder")
	newFolder.Name = "Effects"
	newFolder.Parent = workspace
	folder = newFolder
end
Fx.Folder = folder :: Folder

local burstEvent = Remotes.event("Burst")

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

-- Невидимый "якорь" в точке, к которому цепляем частицы, свет и звук.
local function anchor(position: Vector3, lifetime: number): Part
	local part = basePart(Enum.PartType.Block, Color3.new())
	part.Transparency = 1
	part.Size = Vector3.one * 0.2
	part.Position = position
	part.Parent = Fx.Folder
	Debris:AddItem(part, lifetime)
	return part
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

-- Двойная волна: яркое быстрое кольцо + мягкое широкое.
function Fx.shockwave(position: Vector3, color: Color3, radius: number)
	Fx.ring(position, color, radius, 0.45)
	Fx.ring(position, Color3.new(1, 1, 1), radius * 0.7, 0.3)
	Fx.ring(position + Vector3.new(0, 0.2, 0), color, radius * 1.25, 0.8).Transparency = 0.6
end

-- Луч между двумя точками: яркое ядро + цветное свечение вокруг.
function Fx.beam(from: Vector3, to: Vector3, color: Color3, width: number, duration: number)
	local length = (to - from).Magnitude
	local cframe = CFrame.lookAt(from, to) * CFrame.new(0, 0, -length / 2)

	local glow = basePart(Enum.PartType.Block, color)
	glow.Size = Vector3.new(width, width, length)
	glow.CFrame = cframe
	glow.Transparency = 0.35
	glow.Parent = Fx.Folder
	tween(glow, duration, { Size = Vector3.new(0, 0, length), Transparency = 1 })
	Debris:AddItem(glow, duration + 0.1)

	local core = basePart(Enum.PartType.Block, Color3.new(1, 1, 1))
	core.Size = Vector3.new(width * 0.35, width * 0.35, length)
	core.CFrame = cframe
	core.Parent = Fx.Folder
	tween(core, duration * 0.8, { Size = Vector3.new(0, 0, length), Transparency = 1 })
	Debris:AddItem(core, duration + 0.1)
	return glow
end

-- Дуга-"слэш" перед персонажем (для ударов).
function Fx.slash(origin: CFrame, color: Color3, size: number, flip: boolean?)
	local part = basePart(Enum.PartType.Block, color)
	part.Size = Vector3.new(size, 0.15, size * 0.35)
	local tilt = if flip then -35 else 35
	part.CFrame = origin * CFrame.new(0, 0, -size * 0.45) * CFrame.Angles(0, 0, math.rad(tilt))
	part.Transparency = 0.1
	part.Parent = Fx.Folder
	local goal = origin * CFrame.new(0, 0, -size * 0.7) * CFrame.Angles(0, 0, math.rad(tilt * 1.3))
	tween(part, 0.18, { CFrame = goal, Transparency = 1, Size = Vector3.new(size * 1.3, 0.05, size * 0.1) })
	Debris:AddItem(part, 0.25)
	return part
end

-- Всплеск частиц. Частицы выпускает каждый клиент у себя (WorldFxController):
-- ParticleEmitter:Emit() с сервера реплицируется ненадёжно.
function Fx.burst(position: Vector3, color: Color3, count: number, speed: number?, texture: string?)
	burstEvent:FireAllClients(position, color, count, speed or 25, texture or "Sparkle")
end

-- Вспышка света, которая быстро гаснет.
function Fx.flash(position: Vector3, color: Color3, range: number, duration: number?)
	local holder = anchor(position, (duration or 0.4) + 0.1)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = 6
	light.Shadows = false
	light.Parent = holder
	tween(light, duration or 0.4, { Brightness = 0 })
end

-- Звук в точке мира. name — ключ из Shared/Sounds.
function Fx.sound(name: string, position: Vector3, volume: number?, pitch: number?)
	local id = (Sounds :: any)[name]
	if type(id) ~= "string" or id == "" then
		return
	end
	local holder = anchor(position, 6)
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume or 0.8
	sound.PlaybackSpeed = (pitch or 1) * (0.93 + math.random() * 0.14)
	sound.RollOffMaxDistance = 250
	sound.Parent = holder
	sound:Play()
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
		Fx.burst(position, color, 25, 30)
		tween(part, 0.3, { Transparency = 1, Size = Vector3.new(6, 8, 6) })
	end)
	Debris:AddItem(part, duration + 0.4)
	return part
end

-- Столб света с неба (Метеор, получение камня).
function Fx.pillar(position: Vector3, color: Color3, height: number, duration: number)
	local part = basePart(Enum.PartType.Cylinder, color)
	part.Size = Vector3.new(height, 6, 6)
	part.CFrame = CFrame.new(position + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	part.Transparency = 0.3
	part.Parent = Fx.Folder
	tween(part, duration, { Size = Vector3.new(height, 0, 0), Transparency = 1 })
	Debris:AddItem(part, duration + 0.1)
end

return Fx
