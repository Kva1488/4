--!strict
-- Показывает данные игрока (Coins) в таблице лидеров и держит их в синхроне с DataService.

local Players = game:GetService("Players")

local DataService = require(script.Parent.DataService)

local LeaderstatsService = {}

local function getCoinsValue(player: Player): IntValue
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end
	local coins = (leaderstats :: Folder):FindFirstChild("Coins")
	if not coins then
		coins = Instance.new("IntValue")
		coins.Name = "Coins"
		coins.Parent = leaderstats
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
