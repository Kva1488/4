--!strict
-- Блок и парирование для всех героев (клавиша Ctrl, удерживать).
-- • Пока держишь блок (до 3 секунд), входящий урон меньше на 60%, но ты медленнее.
-- • Если удар пришёл в первые 0.3 секунды блока — это парирование: урон отменён,
--   атакующий оглушён на 1.2 секунды (проверяется в Damage.deal).
-- • После блока — 1.5 секунды перезарядки.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Fx = require(script.Parent.Parent.Combat.Fx)
local Status = require(script.Parent.Parent.Combat.Status)

local BlockService = {}

local MAX_BLOCK = 3
local COOLDOWN = 1.5
local REDUCTION = 0.6
local BUBBLE_COLOR = Color3.fromRGB(180, 210, 255)

type State = { token: number, readyAt: number }
local states: { [Player]: State } = {}

local function stateOf(player: Player): State
	local state = states[player]
	if not state then
		state = { token = 0, readyAt = 0 }
		states[player] = state
	end
	return state
end

local function stopBlock(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or not humanoid:GetAttribute("Blocking") then
		return
	end
	humanoid:SetAttribute("Blocking", false)
	Status.clearShield(humanoid)
	Status.clear(humanoid, "Slow")
	local root = character:FindFirstChild("HumanoidRootPart")
	local bubble = root and root:FindFirstChild("BlockBubble")
	if bubble then
		bubble:Destroy()
	end
	stateOf(player).readyAt = os.clock() + COOLDOWN
end

local function startBlock(player: Player)
	local state = stateOf(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root or humanoid.Health <= 0 or humanoid:GetAttribute("Blocking") then
		return
	end
	if os.clock() < state.readyAt or Status.isStunned(humanoid) then
		return
	end
	state.token += 1
	local token = state.token
	humanoid:SetAttribute("Blocking", true)
	humanoid:SetAttribute("BlockStart", os.clock())
	Status.shield(humanoid, MAX_BLOCK, REDUCTION)
	Status.apply(humanoid, "Slow", MAX_BLOCK, 0.5)

	-- Полупрозрачный пузырь-щит вокруг героя.
	local bubble = Instance.new("Part")
	bubble.Name = "BlockBubble"
	bubble.Shape = Enum.PartType.Ball
	bubble.Size = Vector3.one * 7
	bubble.Material = Enum.Material.ForceField
	bubble.Color = BUBBLE_COLOR
	bubble.CanCollide = false
	bubble.CanQuery = false
	bubble.CanTouch = false
	bubble.Massless = true
	bubble.CastShadow = false
	bubble.CFrame = root.CFrame
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = bubble
	weld.Parent = bubble
	bubble.Parent = root
	Fx.burst(root.Position, BUBBLE_COLOR, 15, 10)

	task.delay(MAX_BLOCK, function()
		if stateOf(player).token == token then
			stopBlock(player)
		end
	end)
end

function BlockService:Init()
	Remotes.event("Block").OnServerEvent:Connect(function(player, active: unknown)
		if active == true then
			startBlock(player)
		elseif active == false then
			stopBlock(player)
		end
	end)
end

function BlockService:Start()
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
end

return BlockService
