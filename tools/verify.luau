-- Проверка проекта: структура собранного Game.rbxl и согласованность предметов/способностей.
-- Запуск: rojo build -o Game.rbxl && lune run tools/verify.luau Game.rbxl

local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local luau = require("@lune/luau")
local process = require("@lune/process")

local failures = 0
local function check(cond, msg)
	if cond then
		print("  ok   " .. msg)
	else
		failures += 1
		print("  FAIL " .. msg)
	end
end

-- 1. Структура собранного place-файла
print("[place]")
local game = roblox.deserializePlace(fs.readFile(process.args[1]))
local function find(path)
	local node = game
	for part in string.gmatch(path, "[^%.]+") do
		node = if node == game then game:GetService(part) else node:FindFirstChild(part)
		if not node then
			return nil
		end
	end
	return node
end
local expected = {
	["ServerScriptService.Server"] = "Script",
	["ServerScriptService.Server.Services.DataService"] = "ModuleScript",
	["ServerScriptService.Server.Services.CombatService"] = "ModuleScript",
	["ServerScriptService.Server.Services.StoneService"] = "ModuleScript",
	["ServerScriptService.Server.Services.GauntletService"] = "ModuleScript",
	["ServerScriptService.Server.Services.DummyService"] = "ModuleScript",
	["ServerScriptService.Server.Services.LeaderstatsService"] = "ModuleScript",
	["ServerScriptService.Server.Services.ShopService"] = "ModuleScript",
	["ServerScriptService.Server.Services.MapService"] = "ModuleScript",
	["ServerScriptService.Server.Combat.AbilityHandlers"] = "ModuleScript",
	["ServerScriptService.Server.Combat.Damage"] = "ModuleScript",
	["ServerScriptService.Server.Combat.Status"] = "ModuleScript",
	["ServerScriptService.Server.Combat.Fx"] = "ModuleScript",
	["ReplicatedStorage.Shared.Items"] = "ModuleScript",
	["ReplicatedStorage.Shared.Abilities"] = "ModuleScript",
	["ReplicatedStorage.Shared.Config"] = "ModuleScript",
	["ReplicatedStorage.Shared.Remotes"] = "ModuleScript",
	["ReplicatedStorage.Shared.Shop"] = "ModuleScript",
	["ReplicatedStorage.Shared.Sounds"] = "ModuleScript",
	["ReplicatedStorage.Shared.GauntletModel"] = "ModuleScript",
	["StarterPlayer.StarterPlayerScripts.Client"] = "LocalScript",
	["StarterPlayer.StarterPlayerScripts.Client.PlayerState"] = "ModuleScript",
	["StarterPlayer.StarterPlayerScripts.Client.Ui"] = "ModuleScript",
	["StarterPlayer.StarterPlayerScripts.Client.Controllers.AbilityController"] = "ModuleScript",
	["StarterPlayer.StarterPlayerScripts.Client.Controllers.InventoryController"] = "ModuleScript",
	["StarterPlayer.StarterPlayerScripts.Client.Controllers.NotifyController"] = "ModuleScript",
	["StarterPlayer.StarterPlayerScripts.Client.Controllers.StoneVisualsController"] = "ModuleScript",
	["StarterPlayer.StarterPlayerScripts.Client.Controllers.HudController"] = "ModuleScript",
	["StarterPlayer.StarterPlayerScripts.Client.Controllers.ShopController"] = "ModuleScript",
	["StarterPlayer.StarterPlayerScripts.Client.Controllers.DamageFxController"] = "ModuleScript",
	["StarterPlayer.StarterPlayerScripts.Client.Controllers.ScreenFxController"] = "ModuleScript",
	["StarterPlayer.StarterPlayerScripts.Client.Controllers.PoseController"] = "ModuleScript",
	["StarterPlayer.StarterPlayerScripts.Client.Controllers.WorldFxController"] = "ModuleScript",
	["Lighting.Atmosphere"] = "Atmosphere",
	["Lighting.Bloom"] = "BloomEffect",
	["Workspace.SpawnLocation"] = "SpawnLocation",
}
for path, className in expected do
	local node = find(path)
	check(node ~= nil and node.ClassName == className, `{path} is {className}`)
end

-- 2. Согласованность данных Items / Abilities / обработчиков
print("[data]")
local env = {
	CFrame = roblox.CFrame,
	Vector3 = roblox.Vector3,
	Color3 = roblox.Color3,
	Enum = roblox.Enum,
	table = table,
	string = string,
	math = math,
	ipairs = ipairs,
	pairs = pairs,
	typeof = typeof,
	type = type,
	print = print,
}
local function loadModule(path)
	return luau.load(fs.readFile(path), { debugName = path, environment = env })()
end
local Items = loadModule("src/shared/Items.luau")
local Abilities = loadModule("src/shared/Abilities.luau")
local handlersSource = fs.readFile("src/server/Combat/AbilityHandlers.luau")

check(#Items.Stones == 6, "6 stones")
local keys = {}
for _, a in Abilities.List do
	check(string.find(handlersSource, "function Handlers." .. a.id .. "%(") ~= nil, `handler for {a.id}`)
	check(not keys[a.input], `unique input for {a.id} ({a.keyLabel})`)
	keys[a.input] = true
	for _, s in a.requires do
		check(Items.StoneById[s] ~= nil, `{a.id} requires valid stone {s}`)
	end
end
for _, s in Items.Stones do
	local a = Abilities.ById[s.ability]
	check(a ~= nil and a.requires[1] == s.id and #a.requires == 1, `{s.id} unlocks {s.ability}`)
end
check(not Abilities.isUnlocked(Abilities.ById.Snap, { Power = true }), "Snap locked with 1 stone")
local all = {}
for _, s in Items.Stones do
	all[s.id] = true
end
check(Abilities.isUnlocked(Abilities.ById.Snap, all), "Snap unlocked with all stones")
check(Abilities.isUnlocked(Abilities.ById.Punch, nil), "Punch always unlocked")
check(Items.countStones(all) == 6 and Items.countStones(nil) == 0, "countStones")

-- 3. Магазин: скины, прокачка, данные по умолчанию
print("[shop]")
local Shop = loadModule("src/shared/Shop.luau")
local Config = loadModule("src/shared/Config.luau")
check(
	Shop.SkinById[Shop.DefaultSkin] ~= nil and Shop.SkinById[Shop.DefaultSkin].price == 0,
	"default skin exists and is free"
)
check(Config.DefaultData.Skins[Shop.DefaultSkin] == true, "default skin owned by default")
check(Config.DefaultData.EquippedSkin == Shop.DefaultSkin, "default skin equipped by default")
local seenSkins = {}
for _, skin in Shop.Skins do
	check(not seenSkins[skin.id], `unique skin id {skin.id}`)
	seenSkins[skin.id] = true
end
for _, upgrade in Shop.Upgrades do
	check(Config.DefaultData.Upgrades[upgrade.id] == 0, `default level 0 for {upgrade.id}`)
	local previous = 0
	for level = 0, upgrade.max - 1 do
		local cost = Shop.upgradeCost(upgrade, level)
		check(cost ~= nil and cost > previous, `{upgrade.id} lvl {level + 1} costs more ({cost})`)
		previous = cost or previous
	end
	check(Shop.upgradeCost(upgrade, upgrade.max) == nil, `{upgrade.id} capped at {upgrade.max}`)
end
check(Shop.cooldownMult({ Cooldown = 5 }) > 0.5, "cooldown mult stays sane at max")
check(Shop.maxHealth(nil) == 100, "base max health 100")

-- 4. Модель Перчатки: уникальные имена, у каждого камня есть гнездо и сам камень, размеры корректны
print("[gauntlet]")
local GauntletModel = loadModule("src/shared/GauntletModel.luau")
local specs = GauntletModel.build(1)
check(#specs >= 40, `gauntlet has {#specs} parts`)
local names = {}
for _, spec in specs do
	check(not names[spec.name], `unique part name {spec.name}`)
	names[spec.name] = spec
	local size = spec.size
	check(size.X > 0 and size.Y > 0 and size.Z > 0 and size.X == size.X, `positive size for {spec.name}`)
end
check(names.Glove ~= nil, "core part 'Glove' exists (light, aura)")
check(names.Index2 ~= nil and names.Pinky2 ~= nil, "fingertips for swipe trail exist")
for _, stone in Items.Stones do
	check(names[stone.id] ~= nil and names[stone.id].role == "gem", `gem for {stone.id}`)
	check(names[stone.id .. "Socket"] ~= nil, `socket for {stone.id}`)
end

print(if failures == 0 then "ALL CHECKS PASSED" else `{failures} FAILURES`)
process.exit(if failures == 0 then 0 else 1)
