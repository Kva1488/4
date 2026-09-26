--!strict
-- Блок: удерживай Ctrl. Всё остальное (снижение урона, парирование) считает сервер.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local BLOCK_KEYS = {
	[Enum.KeyCode.LeftControl] = true,
	[Enum.KeyCode.RightControl] = true,
	[Enum.KeyCode.ButtonL1] = true, -- геймпад
}

local BlockController = {}

function BlockController:Start()
	local block = Remotes.event("Block")
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed and BLOCK_KEYS[input.KeyCode] then
			block:FireServer(true)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if BLOCK_KEYS[input.KeyCode] then
			block:FireServer(false)
		end
	end)
end

return BlockController
