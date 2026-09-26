--!strict
-- Бег по большой карте: держи Shift (на телефоне — кнопка 🏃, она переключает бег).
-- Скорость меняет сервер (Status.setSprint), поэтому бег правильно складывается с замедлениями.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Ui = require(script.Parent.Parent.Ui)

local player = Players.LocalPlayer

local SPRINT_KEYS = {
	[Enum.KeyCode.LeftShift] = true,
	[Enum.KeyCode.RightShift] = true,
	[Enum.KeyCode.ButtonL3] = true, -- геймпад: нажатие левого стика
}

local SprintController = {}

local sprintEvent: RemoteEvent
local sprinting = false
local button: TextButton?

local function set(on: boolean)
	if sprinting == on then
		return
	end
	sprinting = on
	sprintEvent:FireServer(on)
	if button then
		button.BackgroundColor3 = if on then Color3.fromRGB(70, 190, 100) else Ui.Colors.Panel
	end
end

function SprintController:Init()
	sprintEvent = Remotes.event("Sprint")
end

function SprintController:Start()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed and SPRINT_KEYS[input.KeyCode] then
			set(true)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if SPRINT_KEYS[input.KeyCode] then
			set(false)
		end
	end)
	-- Новый персонаж начинает шагом: сервер сбрасывает бег вместе с гуманоидом.
	player.CharacterAdded:Connect(function()
		sprinting = false
		if button then
			button.BackgroundColor3 = Ui.Colors.Panel
		end
	end)

	if UserInputService.TouchEnabled then
		local gui = Ui.create("ScreenGui", {
			Name = "Sprint",
			ResetOnSpawn = false,
			Parent = player:WaitForChild("PlayerGui"),
		})
		local toggle = Ui.create("TextButton", {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -24, 1, -170),
			Size = UDim2.fromOffset(56, 56),
			BackgroundColor3 = Ui.Colors.Panel,
			BackgroundTransparency = 0.2,
			Text = "🏃",
			TextScaled = true,
			Parent = gui,
		}, { Ui.round(), Ui.stroke(Ui.Colors.Gold, 2), Ui.padding(10) })
		button = toggle
		Ui.bounce(toggle)
		toggle.Activated:Connect(function()
			set(not sprinting)
		end)
	end
end

return SprintController
