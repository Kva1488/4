--!strict
-- Камни на карте: плавно вращаются и покачиваются (только у этого игрока, без нагрузки на сервер).
-- Над каждым несобранным камнем — маркер с расстоянием, видимый через стены с любой точки карты.
-- Уже собранные камни становятся полупрозрачными, подсказка "Взять" и маркер у них скрываются.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Items = require(ReplicatedStorage.Shared.Items)

local PlayerState = require(script.Parent.Parent.PlayerState)
local Ui = require(script.Parent.Parent.Ui)

local TAG = "StonePickup"
local MARKER_HIDE_DISTANCE = 25 -- вблизи маркер не нужен: камень и так видно

local player = Players.LocalPlayer

type Tracked = {
	base: Vector3, -- исходная позиция, чтобы анимация не "уплывала"
	marker: BillboardGui?,
	distanceLabel: TextLabel?,
	owned: boolean,
}

local StoneVisualsController = {}

local tracked: { [BasePart]: Tracked } = {}

local function createMarker(part: BasePart, stone: Items.Stone): (BillboardGui, TextLabel)
	local marker = Ui.create("BillboardGui", {
		Name = "StoneMarker",
		Size = UDim2.fromOffset(90, 46),
		StudsOffset = Vector3.new(0, 4, 0),
		AlwaysOnTop = true,
		MaxDistance = 4000,
		LightInfluence = 0,
		Adornee = part,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local dot = Ui.gem(stone.color, UDim2.fromOffset(20, 20), marker)
	dot.AnchorPoint = Vector2.new(0.5, 0)
	dot.Position = UDim2.fromScale(0.5, 0)
	Ui.create("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2, Parent = dot })
	local distance = Ui.label({
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.fromOffset(0, 24),
		Text = "",
		TextColor3 = stone.color,
		Font = Enum.Font.GothamBlack,
		Parent = marker,
	})
	Ui.create("UIStroke", { Thickness = 1.5, Transparency = 0.2, Parent = distance })
	return marker, distance
end

local function refresh(part: BasePart)
	local info = tracked[part]
	local stoneId = part:GetAttribute("StoneId")
	if not info or typeof(stoneId) ~= "string" or not Items.StoneById[stoneId] then
		return
	end
	local owned = PlayerState.stones()[stoneId] == true
	info.owned = owned
	part.Transparency = if owned then 0.75 else 0

	local prompt = part:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Enabled = not owned
	end
	local light = part:FindFirstChildOfClass("PointLight")
	if light then
		light.Enabled = not owned
	end
	if info.marker then
		info.marker.Enabled = not owned
	end
end

local function track(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local stone = Items.StoneById[instance:GetAttribute("StoneId") :: string]
	local info: Tracked = { base = instance.Position, owned = false }
	if stone then
		info.marker, info.distanceLabel = createMarker(instance, stone)
	end
	tracked[instance] = info
	refresh(instance)
end

local function untrack(instance: Instance)
	local info = tracked[instance :: BasePart]
	if info and info.marker then
		info.marker:Destroy()
	end
	tracked[instance :: BasePart] = nil
end

function StoneVisualsController:Start()
	for _, instance in CollectionService:GetTagged(TAG) do
		track(instance)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(track)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(untrack)

	PlayerState.Changed:Connect(function()
		for part in tracked do
			refresh(part)
		end
	end)

	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		for part, info in tracked do
			local base = info.base
			local bob = math.sin(t * 2 + base.X) * 0.4
			part.CFrame = CFrame.new(base + Vector3.new(0, bob, 0))
				* CFrame.Angles(0, t * 1.5, math.sin(t) * 0.3)

			if info.marker and info.distanceLabel and not info.owned and root then
				local distance = (root.Position - base).Magnitude
				info.marker.Enabled = distance > MARKER_HIDE_DISTANCE
				info.distanceLabel.Text = `{math.floor(distance)} м`
			end
		end
	end)
end

return StoneVisualsController
