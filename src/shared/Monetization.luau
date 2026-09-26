--!strict
-- Покупки за робуксы. ВСЕ ID — в таблице IDS ниже: создай геймпассы и Developer Products
-- на create.roblox.com (инструкция — docs/PUBLISHING.md) и впиши их номера вместо 0.
--
-- Пока ID = 0: в Studio кнопка «купить» выдаёт товар бесплатно (для проверки),
-- а в опубликованной игре товар помечен «скоро» и не продаётся.
-- Цены здесь только для витрины: настоящую цену задаёшь на сайте Roblox.

local IDS = {
	-- Геймпассы (покупаются один раз, навсегда).
	StonePower = 0,
	StoneSpace = 0,
	StoneReality = 0,
	StoneSoul = 0,
	StoneTime = 0,
	StoneMind = 0,
	StarterPack = 0,
	DoubleCoins = 0,
	DoubleXp = 0,
	HeroGodLoki = 0,
	HeroInfinityUltron = 0,
	HeroThorStormbreaker = 0,
	HeroThorBoth = 0,
	-- Developer Products (можно покупать сколько угодно раз).
	Coins1000 = 0,
	Coins5000 = 0,
	Coins20000 = 0,
	Xp1000 = 0,
	Xp5000 = 0,
}

export type PassKind = "Stone" | "StarterPack" | "DoubleCoins" | "DoubleXp" | "Hero"

export type Pass = {
	key: string,
	id: number,
	kind: PassKind,
	name: string,
	icon: string,
	description: string,
	price: number,
	color: Color3,
	stone: string?,
	hero: string?,
}

export type Product = {
	key: string,
	id: number,
	name: string,
	icon: string,
	price: number,
	coins: number?,
	xp: number?,
	color: Color3,
}

local Monetization = {}

Monetization.StarterCoins = 2500
Monetization.StarterStones = 2
Monetization.CoinMultiplier = 2
Monetization.XpMultiplier = 2

local STONES = {
	{ id = "Power", name = "Камень Силы", color = Color3.fromRGB(170, 60, 255) },
	{ id = "Space", name = "Камень Пространства", color = Color3.fromRGB(40, 130, 255) },
	{ id = "Reality", name = "Камень Реальности", color = Color3.fromRGB(235, 35, 45) },
	{ id = "Soul", name = "Камень Души", color = Color3.fromRGB(255, 140, 20) },
	{ id = "Time", name = "Камень Времени", color = Color3.fromRGB(40, 220, 90) },
	{ id = "Mind", name = "Камень Разума", color = Color3.fromRGB(255, 215, 40) },
}

local HEROES = {
	{
		id = "GodLoki",
		name = "Локи, бог времени",
		icon = "🌳",
		price = 149,
		color = Color3.fromRGB(110, 255, 150),
	},
	{
		id = "InfinityUltron",
		name = "Альтрон бесконечности",
		icon = "♾️",
		price = 199,
		color = Color3.fromRGB(255, 70, 70),
	},
	{
		id = "ThorStormbreaker",
		name = "Тор с Громсекирой",
		icon = "🪓",
		price = 99,
		color = Color3.fromRGB(140, 205, 255),
	},
	{
		id = "ThorBoth",
		name = "Тор: молот и топор",
		icon = "⚡",
		price = 199,
		color = Color3.fromRGB(140, 205, 255),
	},
}

Monetization.Passes = {} :: { Pass }

table.insert(Monetization.Passes, {
	key = "StarterPack",
	id = IDS.StarterPack,
	kind = "StarterPack",
	name = "Стартовый набор",
	icon = "🎒",
	description = `{Monetization.StarterStones} случайных камня (из тех, что ещё нет) и {Monetization.StarterCoins} монет`,
	price = 99,
	color = Color3.fromRGB(255, 190, 80),
})
table.insert(Monetization.Passes, {
	key = "DoubleCoins",
	id = IDS.DoubleCoins,
	kind = "DoubleCoins",
	name = "x2 монет",
	icon = "🪙",
	description = "Навсегда вдвое больше монет за убийства, камни, босса, арену, уровни и время в игре",
	price = 149,
	color = Color3.fromRGB(255, 215, 90),
})
table.insert(Monetization.Passes, {
	key = "DoubleXp",
	id = IDS.DoubleXp,
	kind = "DoubleXp",
	name = "x2 опыта",
	icon = "✨",
	description = "Навсегда вдвое больше опыта за всё",
	price = 149,
	color = Color3.fromRGB(150, 170, 255),
})
for _, stone in STONES do
	table.insert(Monetization.Passes, {
		key = "Stone" .. stone.id,
		id = (IDS :: any)["Stone" .. stone.id],
		kind = "Stone",
		name = stone.name,
		icon = "💎",
		description = "Сразу в Перчатку, без поисков. Открывает способности камня",
		price = 49,
		color = stone.color,
		stone = stone.id,
	})
end
for _, hero in HEROES do
	table.insert(Monetization.Passes, {
		key = "Hero" .. hero.id,
		id = (IDS :: any)["Hero" .. hero.id],
		kind = "Hero",
		name = hero.name,
		icon = hero.icon,
		description = "Открыть героя сразу, без прогресса",
		price = hero.price,
		color = hero.color,
		hero = hero.id,
	})
end

Monetization.Products = {
	{
		key = "Coins1000",
		id = IDS.Coins1000,
		name = "1 000 монет",
		icon = "🪙",
		price = 25,
		coins = 1000,
		color = Color3.fromRGB(255, 215, 90),
	},
	{
		key = "Coins5000",
		id = IDS.Coins5000,
		name = "5 000 монет",
		icon = "💰",
		price = 99,
		coins = 5000,
		color = Color3.fromRGB(255, 215, 90),
	},
	{
		key = "Coins20000",
		id = IDS.Coins20000,
		name = "20 000 монет",
		icon = "🏦",
		price = 299,
		coins = 20000,
		color = Color3.fromRGB(255, 215, 90),
	},
	{
		key = "Xp1000",
		id = IDS.Xp1000,
		name = "1 000 опыта",
		icon = "✨",
		price = 25,
		xp = 1000,
		color = Color3.fromRGB(150, 170, 255),
	},
	{
		key = "Xp5000",
		id = IDS.Xp5000,
		name = "5 000 опыта",
		icon = "🌟",
		price = 99,
		xp = 5000,
		color = Color3.fromRGB(150, 170, 255),
	},
} :: { Product }

Monetization.PassByKey = {} :: { [string]: Pass }
Monetization.PassById = {} :: { [number]: Pass }
Monetization.PassByHero = {} :: { [string]: Pass }
for _, pass in Monetization.Passes do
	Monetization.PassByKey[pass.key] = pass
	if pass.id ~= 0 then
		Monetization.PassById[pass.id] = pass
	end
	if pass.hero then
		Monetization.PassByHero[pass.hero] = pass
	end
end

Monetization.ProductByKey = {} :: { [string]: Product }
Monetization.ProductById = {} :: { [number]: Product }
for _, product in Monetization.Products do
	Monetization.ProductByKey[product.key] = product
	if product.id ~= 0 then
		Monetization.ProductById[product.id] = product
	end
end

-- Атрибут игрока, которым сервер отмечает купленный геймпасс (клиент показывает «Куплено»).
function Monetization.attribute(pass: Pass): string
	return "Pass_" .. pass.key
end

return table.freeze(Monetization)
