--!strict
-- Небольшие помощники для создания интерфейса кодом.

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
function Ui.create(className: string, props: { [string]: any }, children: { Instance }?): any
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

function Ui.corner(radius: number?): UICorner
	return Ui.create("UICorner", { CornerRadius = UDim.new(0, radius or 10) })
end

function Ui.round(): UICorner
	return Ui.create("UICorner", { CornerRadius = UDim.new(1, 0) })
end

function Ui.stroke(color: Color3, thickness: number?, transparency: number?): UIStroke
	return Ui.create("UIStroke", {
		Color = color,
		Thickness = thickness or 2,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Ui.padding(px: number): UIPadding
	return Ui.create("UIPadding", {
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
	})
end

function Ui.label(props: { [string]: any }): TextLabel
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

-- Круглая "иконка камня": цветной шар с бликом.
function Ui.gem(color: Color3, size: UDim2, parent: Instance?): Frame
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
