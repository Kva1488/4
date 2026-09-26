--!strict
-- Точка входа клиента: загружает все модули из Controllers,
-- вызывает у каждого Init(), затем Start().

local controllersFolder = script:WaitForChild("Controllers")

local controllers = {}
for _, module in controllersFolder:GetChildren() do
	if module:IsA("ModuleScript") then
		controllers[module.Name] = require(module) :: any
	end
end

for name, controller in controllers do
	if controller.Init then
		local ok, err = pcall(controller.Init, controller)
		if not ok then
			warn(`[Client] {name}.Init failed: {err}`)
		end
	end
end

for name, controller in controllers do
	if controller.Start then
		task.spawn(function()
			local ok, err = pcall(controller.Start, controller)
			if not ok then
				warn(`[Client] {name}.Start failed: {err}`)
			end
		end)
	end
end

print("[Client] started")
