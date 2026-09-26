--!strict
-- Анимация декора на клиенте (без нагрузки на сервер и сеть):
-- • детали с тегом "Spin" (кристаллы на колоннах арены) вращаются и покачиваются;
-- • радужные Перчатки (атрибут Rainbow у детали Glove) переливаются цветами;
-- • всплески частиц по событию "Burst" от сервера (удары, взрывы, подбор камней).

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Shop = require(ReplicatedStorage.Shared.Shop)

local MAX_BURST_DISTANCE = 250

local TEXTURES = {
	Sparkle = "rbxasset://textures/particles/sparkles_main.dds",
	Smoke = "rbxasset://textures/particles/smoke_main.dds",
	Fire = "rbxasset://textures/particles/fire_main.dds",
}

local WorldFxController = {}

local spinning: { [BasePart]: CFrame } = {}

local function trackSpin(instance: Instance)
	if instance:IsA("BasePart") then
		spinning[instance] = instance.CFrame
	end
end

local function findGloves(): { BasePart }
	local gloves = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local gauntlet = character and character:FindFirstChild("InfinityGauntlet")
		local glove = gauntlet and gauntlet:FindFirstChild("Glove")
		if glove and glove:IsA("BasePart") and glove:GetAttribute("Rainbow") then
			table.insert(gloves, glove)
		end
	end
	return gloves
end

local function burst(position: Vector3, color: Color3, count: number, speed: number, texture: string)
	local camera = workspace.CurrentCamera
	if not camera or (camera.CFrame.Position - position).Magnitude > MAX_BURST_DISTANCE then
		return
	end
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.one * 0.2
	holder.Position = position
	holder.Parent = camera

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = TEXTURES[texture] or TEXTURES.Sparkle
	emitter.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, if texture == "Smoke" then 3 else 1.2),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new(0, 1)
	emitter.Lifetime = NumberRange.new(0.4, 0.9)
	emitter.Speed = NumberRange.new(speed * 0.5, speed)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Drag = 4
	emitter.Rate = 0
	emitter.Parent = holder
	emitter:Emit(math.clamp(count, 0, 120))
	Debris:AddItem(holder, 1.5)
end

function WorldFxController:Start()
	Remotes.event("Burst").OnClientEvent:Connect(burst)

	for _, instance in CollectionService:GetTagged("Spin") do
		trackSpin(instance)
	end
	CollectionService:GetInstanceAddedSignal("Spin"):Connect(trackSpin)
	CollectionService:GetInstanceRemovedSignal("Spin"):Connect(function(instance)
		spinning[instance :: BasePart] = nil
	end)

	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		for part, base in spinning do
			local bob = math.sin(t * 1.5 + base.X * 0.1) * 0.6
			part.CFrame = CFrame.new(base.Position + Vector3.new(0, bob, 0))
				* CFrame.Angles(0, t * 0.8, 0)
				* (base - base.Position)
		end

		local rainbow = Shop.skinColor(Shop.SkinById.Rainbow, t)
		for _, glove in findGloves() do
			glove.Color = rainbow
			local light = glove:FindFirstChildOfClass("PointLight")
			if light then
				light.Color = rainbow
			end
		end
	end)
end

return WorldFxController
