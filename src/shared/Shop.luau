--!strict
-- Магазин: прокачка (действует на все способности) и скины Перчатки.

export type Upgrade = {
	id: string,
	name: string,
	icon: string,
	description: string,
	max: number,
	baseCost: number,
}

export type Skin = {
	id: string,
	name: string,
	price: number,
	color: Color3,
	material: Enum.Material,
	reflectance: number,
	rainbow: boolean?, -- цвет переливается (анимируется на клиенте)
}

local Upgrades: { Upgrade } = {
	{
		id = "Damage",
		name = "Мощь",
		icon = "⚔️",
		description = "+12% урона всех способностей за уровень",
		max = 5,
		baseCost = 100,
	},
	{
		id = "Cooldown",
		name = "Скорость",
		icon = "⏱️",
		description = "-8% перезарядки всех способностей за уровень",
		max = 5,
		baseCost = 120,
	},
	{
		id = "Health",
		name = "Живучесть",
		icon = "❤️",
		description = "+20 к максимальному здоровью за уровень",
		max = 5,
		baseCost = 80,
	},
}

local Skins: { Skin } = {
	{
		id = "Gold",
		name = "Классика",
		price = 0,
		color = Color3.fromRGB(230, 175, 50),
		material = Enum.Material.Metal,
		reflectance = 0.2,
	},
	{
		id = "Silver",
		name = "Серебро Асгарда",
		price = 250,
		color = Color3.fromRGB(205, 212, 225),
		material = Enum.Material.Metal,
		reflectance = 0.4,
	},
	{
		id = "Nano",
		name = "Нано-перчатка",
		price = 600,
		color = Color3.fromRGB(175, 30, 35),
		material = Enum.Material.Metal,
		reflectance = 0.3,
	},
	{
		id = "Obsidian",
		name = "Обсидиан",
		price = 900,
		color = Color3.fromRGB(30, 24, 40),
		material = Enum.Material.Glass,
		reflectance = 0.1,
	},
	{
		id = "Cosmic",
		name = "Космическая",
		price = 1500,
		color = Color3.fromRGB(120, 80, 255),
		material = Enum.Material.ForceField,
		reflectance = 0,
	},
	{
		id = "Rainbow",
		name = "Радужная",
		price = 2500,
		color = Color3.fromRGB(255, 80, 80),
		material = Enum.Material.Neon,
		reflectance = 0,
		rainbow = true,
	},
}

local UpgradeById: { [string]: Upgrade } = {}
for _, upgrade in Upgrades do
	UpgradeById[upgrade.id] = upgrade
end

local SkinById: { [string]: Skin } = {}
for _, skin in Skins do
	SkinById[skin.id] = skin
end

local Shop = {
	Upgrades = Upgrades,
	UpgradeById = UpgradeById,
	Skins = Skins,
	SkinById = SkinById,
	DefaultSkin = "Gold",
}

-- Цена следующего уровня (level — текущий уровень). nil, если уровень максимальный.
function Shop.upgradeCost(upgrade: Upgrade, level: number): number?
	if level >= upgrade.max then
		return nil
	end
	local raw = upgrade.baseCost * (level + 1) ^ 1.5
	return math.floor(raw / 5 + 0.5) * 5
end

function Shop.damageMult(levels: { [string]: number }?): number
	return 1 + 0.12 * (levels and levels.Damage or 0)
end

function Shop.cooldownMult(levels: { [string]: number }?): number
	return 1 - 0.08 * (levels and levels.Cooldown or 0)
end

function Shop.maxHealth(levels: { [string]: number }?): number
	return 100 + 20 * (levels and levels.Health or 0)
end

-- Цвет скина в момент t (для радужного переливается).
function Shop.skinColor(skin: Skin, t: number?): Color3
	if skin.rainbow then
		return Color3.fromHSV(((t or os.clock()) * 0.25) % 1, 0.85, 1)
	end
	return skin.color
end

return Shop
