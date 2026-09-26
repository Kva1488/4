--!strict
-- Небольшие помощники для создания интерфейса кодом.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Sounds = require(ReplicatedStorage.Shared.Sounds)

local Ui = {}

Ui.Colors = {
	Panel = Color3.fromRGB(18, 16, 28),
	PanelLight = Color3.fromRGB(34, 30, 50),
	Text = Color3.fromRGB(240, 236, 250),
	Muted = Color3.fromRGB(150, 144, 170),
	Gold = Color3.fromRGB(230, 175, 50),
	Locked = Color3.fromRGB(70, 66, 84),
}

-- create("Frame", { Size = ..., Parent = ... }, { children })
function Ui.create(className: string, props: { [string]: any }, children: { any }?): any
	local instance = Instance.new(className) :: any
	for key, value in props do
		if key ~= "Parent" then
			instance[key] = value
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if props.Parent then
		instance.Parent = props.Parent
	end
	return instance
end

function Ui.corner(radius: number?): any
	return Ui.create("UICorner", { CornerRadius = UDim.new(0, radius or 10) })
end

function Ui.round(): any
	return Ui.create("UICorner", { CornerRadius = UDim.new(1, 0) })
end

function Ui.stroke(color: Color3, thickness: number?, transparency: number?): any
	return Ui.create("UIStroke", {
		Color = color,
		Thickness = thickness or 2,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Ui.padding(px: number): any
	return Ui.create("UIPadding", {
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
	})
end

function Ui.label(props: { [string]: any }): any
	local defaults = {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextColor3 = Ui.Colors.Text,
		TextScaled = true,
	}
	for key, value in props do
		defaults[key] = value
	end
	return Ui.create("TextLabel", defaults)
end

-- Панели (инвентарь, магазин): одновременно открыта только одна.
local panels: { [string]: (boolean) -> () } = {}
local openPanel: string? = nil

function Ui.registerPanel(name: string, setVisible: (boolean) -> ())
	panels[name] = setVisible
end

function Ui.togglePanel(name: string, open: boolean?)
	local shouldOpen = if open == nil then openPanel ~= name else open
	if shouldOpen then
		if openPanel and openPanel ~= name and panels[openPanel] then
			panels[openPanel](false)
		end
		openPanel = name
		panels[name](true)
	elseif openPanel == name then
		openPanel = nil
		panels[name](false)
	end
end

function Ui.isOpen(name: string): boolean
	return openPanel == name
end

-- Короткий звук интерфейса (ключ из Shared/Sounds).
function Ui.playSound(name: string, volume: number?, pitch: number?)
	local id = (Sounds :: any)[name]
	if type(id) ~= "string" or id == "" then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume or 0.5
	sound.PlaybackSpeed = pitch or 1
	sound.Parent = SoundService
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	task.delay(5, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end

-- Кнопка с приятным "пружинящим" нажатием.
function Ui.bounce(button: GuiButton)
	local scale = button:FindFirstChildOfClass("UIScale") or Ui.create("UIScale", { Parent = button })
	button.MouseButton1Down:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.08), { Scale = 0.92 }):Play()
	end)
	local function release()
		TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
	button.MouseButton1Up:Connect(release)
	button.MouseLeave:Connect(release)
end

-- Круглая "иконка камня": цветной шар с бликом.
function Ui.gem(color: Color3, size: UDim2, parent: Instance?): any
	return Ui.create("Frame", {
		Size = size,
		BackgroundColor3 = color,
		Parent = parent,
	}, {
		Ui.round(),
		Ui.create("UIGradient", {
			Rotation = 45,
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(0.45, 0.45, 0.45)),
		}),
		Ui.create("Frame", {
			Name = "Shine",
			Size = UDim2.fromScale(0.3, 0.3),
			Position = UDim2.fromScale(0.2, 0.18),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.35,
		}, { Ui.round() }),
	})
end

return Ui
