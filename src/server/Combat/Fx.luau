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

-- Портал Камня Пространства: вертикальное кольцо из искр, развёрнутое к направлению look.
function Fx.portal(position: Vector3, look: Vector3, color: Color3, radius: number, duration: number)
	local flat = look * Vector3.new(1, 0, 1)
	local facing = if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(0, 0, -1)
	local base = CFrame.lookAt(position, position + facing)
	local segments = 16
	for i = 1, segments do
		local angle = (i / segments) * math.pi * 2
		local part = basePart(Enum.PartType.Block, color)
		part.Size = Vector3.new(radius * 0.42, 0.35, 0.35)
		part.CFrame = base * CFrame.Angles(0, 0, angle) * CFrame.new(0, radius, 0)
		part.Parent = Fx.Folder
		tween(part, duration, { Transparency = 1, Size = Vector3.new(radius * 0.6, 0.05, 0.05) })
		Debris:AddItem(part, duration + 0.1)
	end
	local disc = basePart(Enum.PartType.Cylinder, color)
	disc.Size = Vector3.new(0.1, radius * 2, radius * 2)
	disc.CFrame = base * CFrame.Angles(0, math.rad(90), 0)
	disc.Transparency = 0.55
	disc.Parent = Fx.Folder
	tween(disc, duration, { Transparency = 1 })
	Debris:AddItem(disc, duration + 0.1)
end

-- Дверь TVA (TemPad): оранжевая рамка с сияющим проёмом.
function Fx.door(position: Vector3, look: Vector3, duration: number)
	local orange = Color3.fromRGB(255, 150, 50)
	local flat = look * Vector3.new(1, 0, 1)
	local facing = if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(0, 0, -1)
	local base = CFrame.lookAt(position + Vector3.new(0, 1, 0), position + Vector3.new(0, 1, 0) + facing)
	local pieces: { { size: Vector3, offset: CFrame } } = {
		{ size = Vector3.new(0.35, 7.4, 0.35), offset = CFrame.new(-2, 0, 0) },
		{ size = Vector3.new(0.35, 7.4, 0.35), offset = CFrame.new(2, 0, 0) },
		{ size = Vector3.new(4.35, 0.35, 0.35), offset = CFrame.new(0, 3.7, 0) },
		{ size = Vector3.new(4.35, 0.35, 0.35), offset = CFrame.new(0, -3.7, 0) },
	}
	for _, piece in pieces do
		local part = basePart(Enum.PartType.Block, orange)
		part.Size = piece.size
		part.CFrame = base * piece.offset
		part.Parent = Fx.Folder
		tween(part, duration, { Transparency = 1 })
		Debris:AddItem(part, duration + 0.1)
	end
	local glow = basePart(Enum.PartType.Block, Color3.fromRGB(255, 210, 140))
	glow.Size = Vector3.new(3.7, 7, 0.1)
	glow.CFrame = base
	glow.Transparency = 0.3
	glow.Parent = Fx.Folder
	tween(glow, duration, { Transparency = 1 })
	Debris:AddItem(glow, duration + 0.1)
	Fx.flash(position, orange, 20, duration)
end

-- Растущая ветвь времени: цепочка светящихся сегментов, которые вырастают по очереди.
function Fx.branch(points: { Vector3 }, color: Color3, width: number, lifetime: number, growTime: number?)
	local grow = growTime or 0.3
	local stepTime = grow / math.max(1, #points - 1)
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local length = (b - a).Magnitude
		if length > 0.01 then
			local thickness = width * (1 - (i - 1) / #points * 0.6)
			local part = basePart(Enum.PartType.Block, color)
			part.Size = Vector3.new(thickness, thickness, 0.01)
			part.CFrame = CFrame.lookAt(a, b)
			part.Transparency = 0.15
			part.Parent = Fx.Folder
			task.delay(stepTime * (i - 1), function()
				tween(part, stepTime, {
					Size = Vector3.new(thickness, thickness, length),
					CFrame = CFrame.lookAt(a, b) * CFrame.new(0, 0, -length / 2),
				}, Enum.EasingStyle.Linear)
			end)
			task.delay(lifetime, function()
				tween(part, 0.5, { Transparency = 1 })
			end)
			Debris:AddItem(part, lifetime + 0.6)
		end
	end
end

-- Изогнутый путь от a к b с подъёмом посередине (для ветвей и нитей).
function Fx.arc(a: Vector3, b: Vector3, lift: number, segments: number): { Vector3 }
	local points = {}
	for i = 0, segments do
		local t = i / segments
		local wobble = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5) * lift * 0.3
		local point = a:Lerp(b, t) + Vector3.new(0, math.sin(t * math.pi) * lift, 0)
		if i > 0 and i < segments then
			point += wobble
		end
		table.insert(points, point)
	end
	return points
end

-- Распад реальности: модель покрывается кубами, как Дракс на Забвении.
function Fx.cubify(model: Model, color: Color3, duration: number)
	local palette =
		{ color, Color3.fromRGB(255, 120, 150), Color3.fromRGB(255, 200, 120), Color3.fromRGB(180, 40, 60) }
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part.Transparency < 1 and part.Size.Magnitude > 0.5 then
			for _ = 1, 3 do
				local cube = basePart(Enum.PartType.Block, palette[math.random(1, #palette)])
				cube.Material = Enum.Material.SmoothPlastic
				local size = math.clamp(part.Size.Magnitude * 0.3, 0.3, 0.9)
				cube.Size = Vector3.one * size
				local offset = (Vector3.new(math.random(), math.random(), math.random()) - Vector3.one * 0.5)
					* part.Size
				cube.CFrame = part.CFrame
					* CFrame.new(offset)
					* CFrame.Angles(math.random() * 3, math.random() * 3, 0)
				cube.Parent = Fx.Folder
				task.delay(duration, function()
					tween(cube, 0.35, { Size = Vector3.zero, Transparency = 1 })
				end)
				Debris:AddItem(cube, duration + 0.4)
			end
		end
	end
end

-- Каменный кокон вокруг цели (Каменная тюрьма).
function Fx.rockPrison(position: Vector3, duration: number)
	local color = Color3.fromRGB(120, 90, 70)
	for i = 1, 9 do
		local angle = (i / 9) * math.pi * 2
		local rock = basePart(Enum.PartType.Block, color)
		rock.Material = Enum.Material.Rock
		rock.Size = Vector3.new(2.6, 3.2 + math.random() * 1.5, 2.2)
		local target = CFrame.new(
			position + Vector3.new(math.cos(angle) * 1.6, (i % 3) * 1.4 - 1.2, math.sin(angle) * 1.6)
		) * CFrame.Angles(math.random() - 0.5, angle, math.random() - 0.5)
		rock.CFrame = target * CFrame.new(0, -6, 0)
		rock.Transparency = 0
		rock.Parent = Fx.Folder
		tween(rock, 0.25, { CFrame = target }, Enum.EasingStyle.Back)
		task.delay(duration, function()
			tween(rock, 0.3, { Transparency = 1, Size = rock.Size * 0.3 })
		end)
		Debris:AddItem(rock, duration + 0.4)
	end
end

-- Падающий осколок луны. Возвращает время до удара.
function Fx.meteor(target: Vector3, fallTime: number): number
	local rock = basePart(Enum.PartType.Block, Color3.fromRGB(90, 70, 70))
	rock.Material = Enum.Material.Basalt
	rock.Size = Vector3.new(3, 2.5, 3) * (0.8 + math.random() * 0.8)
	local start = target + Vector3.new(math.random(-25, 25), 90, math.random(-25, 25))
	rock.CFrame = CFrame.new(start) * CFrame.Angles(math.random() * 6, math.random() * 6, 0)
	rock.Parent = Fx.Folder
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 140, 60)
	glow.Range = 14
	glow.Brightness = 3
	glow.Parent = rock
	tween(
		rock,
		fallTime,
		{ CFrame = CFrame.new(target) * CFrame.Angles(math.random() * 6, math.random() * 6, 0) },
		Enum.EasingStyle.Quad
	)
	task.delay(fallTime, function()
		glow:Destroy()
		tween(rock, 2, { Transparency = 1 })
	end)
	Debris:AddItem(rock, fallTime + 2.1)
	return fallTime
end

-- Кольца-"циферблаты" времени вокруг точки (остановка и перемотка времени).
function Fx.clock(position: Vector3, color: Color3, radius: number, duration: number)
	for i = 1, 3 do
		local ring = basePart(Enum.PartType.Cylinder, color)
		ring.Size = Vector3.new(0.15, radius * (0.5 + i * 0.25), radius * (0.5 + i * 0.25))
		ring.CFrame = CFrame.new(position) * CFrame.Angles(math.random() * 3, math.random() * 3, math.rad(90))
		ring.Transparency = 0.5
		ring.Parent = Fx.Folder
		tween(ring, duration, {
			CFrame = ring.CFrame * CFrame.Angles(math.rad(180 * i), 0, 0),
			Transparency = 1,
		}, Enum.EasingStyle.Linear)
		Debris:AddItem(ring, duration + 0.1)
	end
end

-- Послеобраз: светящийся силуэт персонажа, который тает на месте (телепорты, рывки, перемотка).
function Fx.afterimage(character: Model, color: Color3, duration: number)
	for _, source in character:GetDescendants() do
		if source:IsA("BasePart") and source.Name ~= "HumanoidRootPart" and source.Transparency < 0.9 then
			local ghost = basePart(Enum.PartType.Block, color)
			if source:IsA("Part") then
				ghost.Shape = source.Shape
			end
			ghost.Size = source.Size
			ghost.CFrame = source.CFrame
			ghost.Transparency = 0.55
			ghost.Parent = Fx.Folder
			tween(ghost, duration, { Transparency = 1, Size = source.Size * 1.08 })
			Debris:AddItem(ghost, duration + 0.1)
		end
	end
end

-- Ломаная молния между точками: для энергетических лучей и контроля разума.
function Fx.lightning(from: Vector3, to: Vector3, color: Color3, segments: number?, duration: number?)
	local count = segments or 8
	local life = duration or 0.25
	local jitter = math.min((to - from).Magnitude * 0.06, 2.5)
	local previous = from
	for i = 1, count do
		local point = from:Lerp(to, i / count)
		if i < count then
			point += Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * jitter * 2
		end
		local length = (point - previous).Magnitude
		local bolt = basePart(Enum.PartType.Block, color)
		bolt.Size = Vector3.new(0.18, 0.18, length)
		bolt.CFrame = CFrame.lookAt(previous, point) * CFrame.new(0, 0, -length / 2)
		bolt.Parent = Fx.Folder
		tween(bolt, life, { Transparency = 1, Size = Vector3.new(0.02, 0.02, length) })
		Debris:AddItem(bolt, life + 0.1)
		previous = point
	end
end

-- Удар молнии с неба: несколько ломаных разрядов, ослепительная вспышка и кольцо.
function Fx.lightningStrike(position: Vector3, color: Color3, height: number?)
	local top = position + Vector3.new(math.random(-6, 6), height or 90, math.random(-6, 6))
	for _ = 1, 3 do
		Fx.lightning(top, position, color, 14, 0.35)
	end
	Fx.lightning(top, position, Color3.new(1, 1, 1), 14, 0.25)
	Fx.beam(top, position, color, 1.4, 0.25)
	Fx.sphere(position, Color3.new(1, 1, 1), 2, 9, 0.3)
	Fx.ring(position, color, 10, 0.4)
	Fx.flash(position, color, 50, 0.4)
	Fx.burst(position, color, 30, 45, "Spark")
end

-- Радужный столб Биврёста.
function Fx.bifrost(position: Vector3, duration: number)
	local colors = {
		Color3.fromRGB(255, 90, 90),
		Color3.fromRGB(255, 190, 80),
		Color3.fromRGB(120, 255, 140),
		Color3.fromRGB(90, 180, 255),
		Color3.fromRGB(200, 120, 255),
	}
	for i, color in colors do
		local part = basePart(Enum.PartType.Cylinder, color)
		local radius = 7 - i
		part.Size = Vector3.new(200, radius * 2, radius * 2)
		part.CFrame = CFrame.new(position + Vector3.new(0, 100, 0)) * CFrame.Angles(0, 0, math.rad(90))
		part.Transparency = 0.25 + i * 0.08
		part.Parent = Fx.Folder
		tween(part, duration, { Size = Vector3.new(200, 0, 0), Transparency = 1 })
		Debris:AddItem(part, duration + 0.1)
	end
	Fx.ring(position, Color3.fromRGB(255, 200, 255), 14, duration)
	Fx.flash(position, Color3.fromRGB(255, 200, 255), 60, duration)
	Fx.burst(position, Color3.fromRGB(255, 180, 240), 60, 40)
end

return Fx
