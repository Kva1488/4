-- Выгружает геометрию Перчатки (src/shared/GauntletModel.luau) в JSON для превью.
-- Запуск: lune run tools/export_gauntlet.luau > gauntlet.json
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local env = {
	CFrame = roblox.CFrame,
	Vector3 = roblox.Vector3,
	math = math,
	table = table,
	ipairs = ipairs,
	pairs = pairs,
}
local GauntletModel = luau.load(fs.readFile("src/shared/GauntletModel.luau"), { environment = env })()

local out = {}
for _, spec in GauntletModel.build(1) do
	local c = { spec.cframe:GetComponents() }
	table.insert(out, {
		name = spec.name,
		role = spec.role,
		shape = spec.shape,
		stone = spec.stone,
		size = { spec.size.X, spec.size.Y, spec.size.Z },
		pos = { c[1], c[2], c[3] },
		rot = { { c[4], c[5], c[6] }, { c[7], c[8], c[9] }, { c[10], c[11], c[12] } },
	})
end
print(serde.encode("json", out))
