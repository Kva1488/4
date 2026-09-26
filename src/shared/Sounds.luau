--!strict
-- Все звуки игры в одном месте. Чтобы поставить свой звук, вставь его ID вида "rbxassetid://123456".
-- Пустая строка = звук не играет. По умолчанию стоят встроенные звуки Roblox (rbxasset://sounds/...).

local Sounds = {
	Punch = "rbxasset://sounds/swordslash.wav",
	PunchFinisher = "rbxasset://sounds/swordlunge.wav",
	Beam = "rbxasset://sounds/Rocket shot.wav",
	Wave = "rbxasset://sounds/Launching rocket.wav",
	Teleport = "rbxasset://sounds/electronicpingshort.wav",
	Magic = "rbxasset://sounds/unsheath.wav",
	Snap = "",
	StonePickup = "rbxasset://sounds/electronicpingshort.wav",
	Purchase = "rbxasset://sounds/electronicpingshort.wav",
	HitMarker = "",
	UiClick = "",
}

return table.freeze(Sounds)
