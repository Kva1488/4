--!strict
-- Простой HUD: счётчик монет в левом верхнем углу.

local Players = game:GetService("Players")

local player = Players.LocalPlayer

local HudController = {}

local function createHud(): TextLabel
	local gui = Instance.new("ScreenGui")
	gui.Name = "Hud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false

	local label = Instance.new("TextLabel")
	label.Name = "Coins"
	label.AnchorPoint = Vector2.new(0, 0)
	label.Position = UDim2.fromOffset(16, 16)
	label.Size = UDim2.fromOffset(180, 44)
	label.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
	label.BackgroundTransparency = 0.25
	label.TextColor3 = Color3.fromRGB(255, 215, 90)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Text = "🪙 0"
	label.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = label

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.Parent = label

	gui.Parent = player:WaitForChild("PlayerGui")
	return label
end

function HudController:Start()
	local label = createHud()
	local leaderstats = player:WaitForChild("leaderstats")
	local coins = leaderstats:WaitForChild("Coins") :: IntValue

	local function refresh()
		label.Text = `🪙 {coins.Value}`
	end
	coins.Changed:Connect(refresh)
	refresh()
end

return HudController
