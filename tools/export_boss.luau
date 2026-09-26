-- Выгружает модель Дормамму (src/shared/DormammuModel.luau) в JSON для превью без Studio.
-- Запуск: lune run tools/export_boss.luau head > dormammu.json  (или hand)
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local env = {
	CFrame = roblox.CFrame,
	Vector3 = roblox.Vector3,
	Color3 = roblox.Color3,
	Enum = roblox.Enum,
	math = math,
	table = table,
}
local DormammuModel = luau.load(fs.readFile("src/shared/DormammuModel.luau"), { environment = env })()

local which = process.args[1] or "head"
local specs = if which == "hand" then DormammuModel.hand() else DormammuModel.head()
local out = {}
for _, spec in specs do
	local look = DormammuModel.Roles[spec.role]
	local color = spec.color or look.color
	local c = { spec.cframe:GetComponents() }
	table.insert(out, {
		name = spec.name,
		role = spec.role,
		shape = spec.shape,
		color = { color.R, color.G, color.B },
		transparency = spec.transparency or look.transparency,
		size = { spec.size.X, spec.size.Y, spec.size.Z },
		pos = { c[1], c[2], c[3] },
		rot = { { c[4], c[5], c[6] }, { c[7], c[8], c[9] }, { c[10], c[11], c[12] } },
	})
end
print(serde.encode("json", out))
