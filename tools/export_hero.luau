-- Выгружает внешний вид героев (src/shared/HeroModel.luau) на манекене R15 в JSON для превью.
-- Запуск: lune run tools/export_hero.luau Loki > loki.json
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local env = {
	CFrame = CFrame,
	Vector3 = Vector3,
	Color3 = roblox.Color3,
	Enum = roblox.Enum,
	math = math,
	table = table,
}
local HeroModel = luau.load(fs.readFile("src/shared/HeroModel.luau"), { environment = env })()

-- Центры частей тела манекена R15 относительно UpperTorso.
local BODY = {
	head = CFrame.new(0, 1.4, 0),
	torso = CFrame.new(0, 0, 0),
	rightHand = CFrame.new(1.5, -1.95, 0),
	leftHand = CFrame.new(-1.5, -1.95, 0),
}

local out = {}
local function push(name, role, shape, size, cf, color)
	local c = { cf:GetComponents() }
	table.insert(out, {
		color = if color then { color.R, color.G, color.B } else nil,
		name = name,
		role = role,
		shape = shape,
		size = { size.X, size.Y, size.Z },
		pos = { c[1], c[2], c[3] },
		rot = { { c[4], c[5], c[6] }, { c[7], c[8], c[9] }, { c[10], c[11], c[12] } },
	})
end
-- Манекен.
push("Head", "body", "Block", Vector3.new(1.2, 1.2, 1.2), BODY.head)
push("UpperTorso", "body", "Block", Vector3.new(2, 1.6, 1), BODY.torso)
push("LowerTorso", "body", "Block", Vector3.new(2, 0.4, 1), CFrame.new(0, -1, 0))
for _, x in { -1.5, 1.5 } do
	push("Arm", "body", "Block", Vector3.new(1, 2.4, 1), CFrame.new(x, -0.6, 0))
	push("Leg", "body", "Block", Vector3.new(0.95, 2.2, 1), CFrame.new(x / 3, -2.3, 0))
end
local outfit = HeroModel.outfit(process.args[1])
for bodyPart, specs in outfit do
	for _, spec in specs do
		push(spec.name, spec.role, spec.shape, spec.size, BODY[bodyPart] * spec.cframe, spec.color)
	end
end
print(serde.encode("json", out))
