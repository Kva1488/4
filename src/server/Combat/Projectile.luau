--!strict
-- Летящие снаряды (кинжал Локи, сгусток ветви времени).
-- Сервер двигает снаряд каждый кадр: лучом проверяет стены, радиусом — попадания по целям.

local RunService = game:GetService("RunService")

local Damage = require(script.Parent.Damage)
local Fx = require(script.Parent.Fx)

export type Options = {
	origin: Vector3,
	direction: Vector3, -- единичный вектор
	speed: number,
	range: number,
	radius: number,
	owner: Model, -- персонаж стрелка: в него снаряд не попадает
	pierce: boolean?, -- лететь дальше после попадания
	visual: BasePart?, -- деталь, которая летит вместе со снарядом (удаляется в конце)
	onHit: (target: Damage.Target, position: Vector3) -> (),
	onEnd: ((position: Vector3) -> ())?,
}

local Projectile = {}

function Projectile.fire(options: Options)
	local position = options.origin
	local travelled = 0
	local alreadyHit: { [Model]: boolean } = {}
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { options.owner, Fx.Folder }

	local visual = options.visual
	if visual then
		visual.Anchored = true
		visual.CanCollide = false
		visual.CanQuery = false
		visual.CanTouch = false
		visual.CFrame = CFrame.lookAt(position, position + options.direction)
		visual.Parent = Fx.Folder
	end

	local connection: RBXScriptConnection
	local function finish()
		connection:Disconnect()
		if visual then
			visual:Destroy()
		end
		if options.onEnd then
			options.onEnd(position)
		end
	end

	connection = RunService.Heartbeat:Connect(function(dt)
		local step = math.min(options.speed * dt, options.range - travelled)
		local wall = workspace:Raycast(position, options.direction * step, params)
		local nextPosition = if wall then wall.Position else position + options.direction * step

		-- Проверяем попадания в нескольких точках отрезка, чтобы быстрый снаряд не "проскакивал" цели.
		local samples = math.max(1, math.ceil(step / options.radius))
		for i = 1, samples do
			local point = position:Lerp(nextPosition, i / samples)
			for _, target in Damage.inRadius(point, options.radius, options.owner) do
				if not alreadyHit[target.model] then
					alreadyHit[target.model] = true
					options.onHit(target, point)
					if not options.pierce then
						position = point
						finish()
						return
					end
				end
			end
		end

		position = nextPosition
		travelled += step
		if visual then
			visual.CFrame = CFrame.lookAt(position, position + options.direction)
		end
		if wall or travelled >= options.range then
			finish()
		end
	end)
end

-- Бумеранг (Мьёльнир, Громсекира): летит до конца дальности или стены и возвращается к хозяину.
-- makeVisual вызывается дважды — для полёта туда и обратно. onHit срабатывает по одному разу на каждом отрезке.
function Projectile.boomerang(
	options: Options,
	owner: BasePart,
	makeVisual: () -> BasePart,
	onCaught: (() -> ())?
)
	local outward = table.clone(options)
	outward.visual = makeVisual()
	outward.onEnd = function(turnPoint: Vector3)
		if options.onEnd then
			options.onEnd(turnPoint)
		end
		if not owner.Parent then
			return
		end
		local back = owner.Position - turnPoint
		if back.Magnitude < 1 then
			return
		end
		Projectile.fire({
			origin = turnPoint,
			direction = back.Unit,
			speed = options.speed * 1.2,
			range = back.Magnitude,
			radius = options.radius,
			owner = options.owner,
			pierce = true,
			visual = makeVisual(),
			onHit = options.onHit,
			onEnd = function()
				if onCaught then
					onCaught()
				end
			end,
		})
	end
	Projectile.fire(outward)
end

return Projectile
