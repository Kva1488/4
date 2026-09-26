--!strict
-- Камни на карте: плавно вращаются и покачиваются (только у этого игрока, без нагрузки на сервер).
-- Уже собранные камни становятся полупрозрачными, и подсказка "Взять" у них скрывается.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Items = require(ReplicatedStorage.Shared.Items)

local PlayerState = require(script.Parent.Parent.PlayerState)

local TAG = "StonePickup"

local StoneVisualsController = {}

-- Исходная позиция каждого камня, чтобы анимация не "уплывала".
local basePositions: { [BasePart]: Vector3 } = {}

local function refresh(part: BasePart)
	local stoneId = part:GetAttribute("StoneId")
	if typeof(stoneId) ~= "string" or not Items.StoneById[stoneId] then
		return
	end
	local owned = PlayerState.stones()[stoneId] == true
	part.Transparency = if owned then 0.75 else 0

	local prompt = part:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Enabled = not owned
	end
	local light = part:FindFirstChildOfClass("PointLight")
	if light then
		light.Enabled = not owned
	end
end

local function track(instance: Instance)
	if instance:IsA("BasePart") then
		basePositions[instance] = instance.Position
		refresh(instance)
	end
end

function StoneVisualsController:Start()
	for _, instance in CollectionService:GetTagged(TAG) do
		track(instance)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(track)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(instance)
		basePositions[instance :: BasePart] = nil
	end)

	PlayerState.Changed:Connect(function()
		for part in basePositions do
			refresh(part)
		end
	end)

	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		for part, base in basePositions do
			local bob = math.sin(t * 2 + base.X) * 0.4
			part.CFrame = CFrame.new(base + Vector3.new(0, bob, 0))
				* CFrame.Angles(0, t * 1.5, math.sin(t) * 0.3)
		end
	end)
end

return StoneVisualsController
