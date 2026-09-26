--!strict
-- Особые места карты. MapService не ставит сюда декор, а BossService и ArenaService строят их сами.

local Places = {
	-- Разлом Тёмного измерения: логово Дормамму (северо-запад, между камнями Пространства и Разума).
	BossCenter = Vector3.new(-175, 0, 170),
	BossRadius = 44,

	-- Летающая арена режимов высоко над центром карты.
	ArenaCenter = Vector3.new(0, 320, 0),
	ArenaRadius = 56,

	-- Портал на арену возле спавна (кольцо Сантум-портала, как у Доктора Стрэнджа).
	ArenaPortal = Vector3.new(40, 0, 0),
}

return table.freeze(Places)
