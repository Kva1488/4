--!strict
-- Показывает данные игрока (Coins) в таблице лидеров и держит их в синхроне с DataService.

local Players = game:GetService("Players")

local DataService = require(script.Parent.DataService)

local LeaderstatsService = {}

local function getCoinsValue(player: Player): IntValue
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		local folder = Instance.new("Folder")
		folder.Name = "leaderstats"
		folder.Parent = player
		leaderstats = folder
	end
	local coins = (leaderstats :: Instance):FindFirstChild("Coins")
	if not coins then
		local value = Instance.new("IntValue")
		value.Name = "Coins"
		value.Parent = leaderstats
		coins = value
	end
	return coins :: IntValue
end

function LeaderstatsService:Start()
	DataService:OnChanged(function(player, data)
		if player.Parent == Players then
			getCoinsValue(player).Value = data.Coins
		end
	end)
end

return LeaderstatsService
