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
	["ReplicatedStorage.Shared.Heroes"] = "ModuleScript",
	["ReplicatedStorage.Shared.HeroModel"] = "ModuleScript",
	["ServerScriptService.Server.Services.HeroService"] = "ModuleScript",
	["ServerScriptService.Server.Combat.Heroes.Thanos"] = "ModuleScript",
	["ServerScriptService.Server.Combat.Heroes.Loki"] = "ModuleScript",
	["ServerScriptService.Server.Combat.Heroes.GodLoki"] = "ModuleScript",
	["ServerScriptService.Server.Combat.Kit"] = "ModuleScript",
	["ServerScriptService.Server.Combat.Timeline"] = "ModuleScript",
	["ServerScriptService.Server.Combat.Projectile"] = "ModuleScript",
	["StarterPlayer.StarterPlayerScripts.Client.Controllers.HeroController"] = "ModuleScript",
	["ServerScriptService.Server.Combat.Heroes.Ultron"] = "ModuleScript",
	["ServerScriptService.Server.Combat.Heroes.InfinityUltron"] = "ModuleScript",
	["ServerScriptService.Server.Combat.Sentries"] = "ModuleScript",
	["ServerScriptService.Server.Combat.Heroes.Thor"] = "ModuleScript",
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
-- Исходники всех героев: обработчики способностей описаны как function Handlers.<id>(.
local handlersSource = ""
for _, file in fs.readDir("src/server/Combat/Heroes") do
	handlersSource ..= fs.readFile("src/server/Combat/Heroes/" .. file)
end
local Heroes = loadModule("src/shared/Heroes.luau")

check(#Items.Stones == 6, "6 stones")
local keys = {}
for _, a in Abilities.List do
	check(Heroes.ById[a.hero] ~= nil, `{a.id} belongs to existing hero {a.hero}`)
	check(string.find(handlersSource, "function Handlers." .. a.id .. "%(") ~= nil, `handler for {a.id}`)
	-- Клавиши уникальны в пределах героя (у разных героев могут совпадать).
	local key = a.hero .. ":" .. tostring(a.input)
	check(not keys[key], `unique input for {a.id} ({a.hero} {a.keyLabel})`)
	keys[key] = true
	for _, s in a.requires do
		check(Items.StoneById[s] ~= nil, `{a.id} requires valid stone {s}`)
	end
	check(#a.requires == 0 or a.hero == "Thanos", `only Thanos abilities need stones ({a.id})`)
end
for _, hero in Heroes.List do
	local count = #Abilities.forHero(hero.id)
	check(count >= 6, `{hero.id} has {count} abilities`)
end
check(Heroes.isUnlocked(Heroes.ById.Loki, {}), "Loki unlocked from start")
check(Heroes.isUnlocked(Heroes.ById.Ultron, {}), "Ultron unlocked from start")
check(not Heroes.isUnlocked(Heroes.ById.GodLoki, { LokiKills = 24 }), "God Loki locked at 24 kills")
check(Heroes.isUnlocked(Heroes.ById.GodLoki, { LokiKills = 25 }), "God Loki unlocked at 25 kills")
check(
	not Heroes.isUnlocked(Heroes.ById.InfinityUltron, { LokiKills = 99 }),
	"Infinity Ultron ignores Loki kills"
)
check(
	Heroes.isUnlocked(Heroes.ById.InfinityUltron, { UltronKills = 25 }),
	"Infinity Ultron unlocked at 25 kills"
)
for _, hero in Heroes.List do
	if hero.unlock then
		check(
			loadModule("src/shared/Config.luau").DefaultData[hero.unlock.stat] == 0,
			`stat {hero.unlock.stat} exists in DefaultData`
		)
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

-- 5. Внешний вид Локи
print("[heroes]")
local HeroModel = loadModule("src/shared/HeroModel.luau")
for _, id in { "Loki", "GodLoki", "Ultron", "InfinityUltron", "Thor", "ThorStormbreaker", "ThorBoth" } do
	local outfit = HeroModel.outfit(id)
	check(outfit ~= nil and #outfit.head >= 5 and #outfit.torso >= 5, `{id} has head and torso outfit`)
end
local thanos = HeroModel.outfit("Thanos")
check(
	thanos ~= nil and #thanos.rightHand == 0 and #thanos.torso >= 5,
	"Thanos armor leaves the right hand to the gauntlet"
)
local infinity = HeroModel.outfit("InfinityUltron")
local chestStones, sways = 0, 0
for _, spec in infinity.torso do
	if spec.role == "gem" then
		chestStones += 1
	end
	if spec.sway then
		sways += 1
	end
end
check(chestStones == 5, `Infinity Ultron has 5 chest stones ({chestStones})`)
check(sways >= 2, "Infinity Ultron cape sways")
local spearParts = 0
for _, spec in infinity.rightHand do
	if string.find(spec.name, "Blade") then
		spearParts += 1
	end
end
check(spearParts == 2, "Infinity Ultron spear has two blades")

-- 6. Торы
print("[thor]")
check(Heroes.isUnlocked(Heroes.ById.Thor, {}), "Thor unlocked from start")
check(not Heroes.isUnlocked(Heroes.ById.ThorStormbreaker, { ThorKills = 14 }), "Stormbreaker locked at 14")
check(Heroes.isUnlocked(Heroes.ById.ThorStormbreaker, { ThorKills = 15 }), "Stormbreaker unlocked at 15")
check(not Heroes.isUnlocked(Heroes.ById.ThorBoth, { ThorKills = 39 }), "Hammer and axe locked at 39")
check(Heroes.isUnlocked(Heroes.ById.ThorBoth, { ThorKills = 40 }), "Hammer and axe unlocked at 40")
local function hasPart(outfit, slot, name)
	for _, spec in outfit[slot] do
		if spec.name == name then
			return true
		end
	end
	return false
end
check(hasPart(HeroModel.outfit("Thor"), "rightHand", "MjolnirHead"), "Thor holds Mjolnir")
check(hasPart(HeroModel.outfit("ThorStormbreaker"), "rightHand", "AxeBlade"), "Thor holds Stormbreaker")
local both = HeroModel.outfit("ThorBoth")
check(
	hasPart(both, "rightHand", "AxeBlade") and hasPart(both, "leftHand", "MjolnirHead"),
	"Endgame Thor holds both weapons"
)

print(if failures == 0 then "ALL CHECKS PASSED" else `{failures} FAILURES`)
process.exit(if failures == 0 then 0 else 1)
