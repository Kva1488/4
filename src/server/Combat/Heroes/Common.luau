--!strict
-- Способности, общие для всех героев.

local Damage = require(script.Parent.Parent.Damage)
local Fx = require(script.Parent.Parent.Fx)
local Kit = require(script.Parent.Parent.Kit)
local Status = require(script.Parent.Parent.Status)

type Context = Kit.Context

local Handlers: { [string]: (Context) -> () } = {}

-- Рывок-уклонение: в сторону движения (или по прицелу, если стоишь), 0.35 с неуязвимости.
function Handlers.Dodge(ctx)
	local move = ctx.humanoid.MoveDirection * Vector3.new(1, 0, 1)
	local direction = if move.Magnitude > 0.1 then move.Unit else Kit.aimFlat(ctx)
	Status.shield(ctx.humanoid, 0.35, 1)
	Fx.afterimage(ctx.character, Color3.fromRGB(220, 230, 255), 0.35)
	Fx.burst(ctx.root.Position, Color3.fromRGB(220, 230, 255), 12, 18)
	Fx.sound("Teleport", ctx.root.Position, 0.4, 1.6)
	Damage.knockback(ctx.root, direction * 95 + Vector3.new(0, 8, 0), 0.18)
	task.delay(0.1, function()
		if ctx.root.Parent then
			Fx.afterimage(ctx.character, Color3.fromRGB(220, 230, 255), 0.3)
		end
	end)
end

return { Handlers = Handlers }
