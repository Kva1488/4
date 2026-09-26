--!strict
-- Все обработчики способностей всех героев в одной таблице (id способности → функция).
-- Логика героев лежит в Combat/Heroes/<Герой>.luau.

local Kit = require(script.Parent.Kit)

export type Context = Kit.Context

local Handlers: { [string]: (Context) -> () } = {}

for _, module in script.Parent.Heroes:GetChildren() do
	if module:IsA("ModuleScript") then
		local hero = require(module) :: any
		for id, handler in hero.Handlers do
			assert(Handlers[id] == nil, `Способность {id} описана дважды`)
			Handlers[id] = handler
		end
	end
end

return Handlers
