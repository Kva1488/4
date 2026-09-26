--!strict
-- Точка входа сервера: загружает все модули из Services,
-- вызывает у каждого Init() (подготовка), затем Start() (запуск логики).

local servicesFolder = script:WaitForChild("Services")

local services = {}
for _, module in servicesFolder:GetChildren() do
	if module:IsA("ModuleScript") then
		services[module.Name] = require(module) :: any
	end
end

for name, service in services do
	if service.Init then
		local ok, err = pcall(service.Init, service)
		if not ok then
			warn(`[Server] {name}.Init failed: {err}`)
		end
	end
end

for name, service in services do
	if service.Start then
		task.spawn(function()
			local ok, err = pcall(service.Start, service)
			if not ok then
				warn(`[Server] {name}.Start failed: {err}`)
			end
		end)
	end
end

print("[Server] started")
