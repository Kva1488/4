--!strict
-- Показывает данные игрока (монеты и уровень) в таблице лидеров и держит их в синхроне с DataService.

local Players = game:GetService("Players")

local DataService = require(script.Parent.DataService)

local LeaderstatsService = {}

local function getValue(player: Player, name: string): IntValue
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		local folder = Instance.new("Folder")
		folder.Name = "leaderstats"
		folder.Parent = player
		leaderstats = folder
	end
	local stat = (leaderstats :: Instance):FindFirstChild(name)
	if not stat then
		local value = Instance.new("IntValue")
		value.Name = name
		value.Parent = leaderstats
		stat = value
	end
	return stat :: IntValue
end

function LeaderstatsService:Start()
	DataService:OnChanged(function(player, data)
		if player.Parent == Players then
			getValue(player, "Level").Value = data.Level
			getValue(player, "Coins").Value = data.Coins
		end
	end)
end

return LeaderstatsService
