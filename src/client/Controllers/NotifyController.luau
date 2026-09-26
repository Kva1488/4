--!strict
-- Всплывающие уведомления сверху экрана ("Камень Силы получен!" и т.п.).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Parent.Ui)

local NotifyController = {}

local container: Frame? = nil

local function ensureContainer(): Frame
	if container then
		return container
	end
	local gui = Ui.create("ScreenGui", {
		Name = "Notifications",
		ResetOnSpawn = false,
		DisplayOrder = 20,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	container = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.new(0.9, 0, 0, 200),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		Ui.create("UIListLayout", {
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Ui.create("UISizeConstraint", { MaxSize = Vector2.new(460, math.huge) }),
	})
	return container :: Frame
end

function NotifyController.show(text: string, color: Color3?)
	local accent = color or Ui.Colors.Gold
	local toast = Ui.create("Frame", {
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundColor3 = Ui.Colors.Panel,
		BackgroundTransparency = 1,
		LayoutOrder = -os.clock() * 1000,
		Parent = ensureContainer(),
	}, {
		Ui.corner(10),
		Ui.stroke(accent, 2, 1),
		Ui.label({
			Name = "Text",
			Size = UDim2.new(1, -20, 1, -12),
			Position = UDim2.fromOffset(10, 6),
			Text = text,
			TextColor3 = accent,
			TextTransparency = 1,
		}),
	})

	local info = TweenInfo.new(0.25, Enum.EasingStyle.Quad)
	TweenService:Create(toast, info, { BackgroundTransparency = 0.1 }):Play()
	TweenService:Create(toast.UIStroke, info, { Transparency = 0 }):Play()
	TweenService:Create(toast.Text, info, { TextTransparency = 0 }):Play()

	task.delay(3, function()
		local out = TweenInfo.new(0.4)
		TweenService:Create(toast, out, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(toast.UIStroke, out, { Transparency = 1 }):Play()
		TweenService:Create(toast.Text, out, { TextTransparency = 1 }):Play()
		task.wait(0.4)
		toast:Destroy()
	end)
end

function NotifyController:Start()
	Remotes.event("Notify").OnClientEvent:Connect(function(text: string, color: Color3?)
		NotifyController.show(text, color)
	end)
end

return NotifyController
