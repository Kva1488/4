--!strict
-- Герои: выбор героя (с проверкой разблокировки) и внешний вид персонажа.
-- • Танос: фиолетовая кожа (перчатку надевает GauntletService).
-- • Локи: золотой шлем с рогами, зелёный плащ, наплечники, два кинжала.
-- • Локи, бог времени: рога длиннее, "часовой" нимб, тёмный плащ и зелёная аура времени.
-- • Альтрон и Альтрон бесконечности: металлический корпус (одежда снимается), голова с
--   красными глазами, ядро в груди, когти. Камни вокруг Альтрона бесконечности рисуют клиенты.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local HeroModel = require(ReplicatedStorage.Shared.HeroModel)
local Heroes = require(ReplicatedStorage.Shared.Heroes)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Fx = require(script.Parent.Parent.Combat.Fx)
local Kit = require(script.Parent.Parent.Combat.Kit)
local Status = require(script.Parent.Parent.Combat.Status)
local DataService = require(script.Parent.DataService)

local HeroService = {}

local SWITCH_COOLDOWN = 3
local COSMETICS = "HeroCosmetics"
local HIDDEN_CLOTHING = "HiddenClothing"

local SHAPES: { [string]: Enum.PartType } = {
	Block = Enum.PartType.Block,
	Ball = Enum.PartType.Ball,
	Cylinder = Enum.PartType.Cylinder,
}

-- Цвет и материал по роли детали.
local LOOKS: { [string]: { [string]: { color: Color3, material: Enum.Material } } } = {
	Loki = {
		plate = { color = Color3.fromRGB(225, 175, 60), material = Enum.Material.Metal },
		trim = { color = Color3.fromRGB(150, 110, 35), material = Enum.Material.Metal },
		cape = { color = Color3.fromRGB(25, 95, 45), material = Enum.Material.Fabric },
		lining = { color = Color3.fromRGB(110, 255, 150), material = Enum.Material.Neon },
		steel = { color = Color3.fromRGB(215, 225, 230), material = Enum.Material.Metal },
		dark = { color = Color3.fromRGB(40, 35, 30), material = Enum.Material.Metal },
		glow = { color = Color3.fromRGB(110, 255, 150), material = Enum.Material.Neon },
	},
	GodLoki = {
		plate = { color = Color3.fromRGB(235, 190, 80), material = Enum.Material.Metal },
		trim = { color = Color3.fromRGB(160, 120, 40), material = Enum.Material.Metal },
		cape = { color = Color3.fromRGB(18, 58, 36), material = Enum.Material.Fabric },
		lining = { color = Color3.fromRGB(110, 255, 150), material = Enum.Material.Neon },
		steel = { color = Color3.fromRGB(215, 225, 230), material = Enum.Material.Metal },
		dark = { color = Color3.fromRGB(40, 35, 30), material = Enum.Material.Metal },
		glow = { color = Color3.fromRGB(110, 255, 150), material = Enum.Material.Neon },
	},
	Ultron = {
		plate = { color = Color3.fromRGB(170, 175, 187), material = Enum.Material.DiamondPlate },
		trim = { color = Color3.fromRGB(105, 108, 118), material = Enum.Material.Metal },
		steel = { color = Color3.fromRGB(215, 225, 235), material = Enum.Material.Metal },
		eye = { color = Color3.fromRGB(255, 45, 40), material = Enum.Material.Neon },
		lining = { color = Color3.fromRGB(255, 45, 40), material = Enum.Material.Neon },
		gem = { color = Color3.fromRGB(255, 215, 40), material = Enum.Material.Neon },
	},
	InfinityUltron = {
		plate = { color = Color3.fromRGB(125, 130, 146), material = Enum.Material.DiamondPlate },
		trim = { color = Color3.fromRGB(78, 80, 94), material = Enum.Material.Metal },
		steel = { color = Color3.fromRGB(235, 200, 110), material = Enum.Material.Metal },
		eye = { color = Color3.fromRGB(255, 45, 40), material = Enum.Material.Neon },
		lining = { color = Color3.fromRGB(235, 185, 60), material = Enum.Material.Metal },
		gem = { color = Color3.fromRGB(255, 215, 40), material = Enum.Material.Neon },
	},
}

local lastSwitch: { [Player]: number } = {}

-- Куда крепить одежду на R15 и R6 (часть тела и смещение центра).
local function mount(character: Model, slot: string): (BasePart?, CFrame)
	local function part(name: string): BasePart?
		local found = character:FindFirstChild(name)
		return if found and found:IsA("BasePart") then found else nil
	end
	if slot == "head" then
		return part("Head"), CFrame.new()
	elseif slot == "torso" then
		local upper = part("UpperTorso")
		if upper then
			return upper, CFrame.new()
		end
		return part("Torso"), CFrame.new(0, 0.2, 0)
	elseif slot == "rightHand" then
		local hand = part("RightHand")
		if hand then
			return hand, CFrame.new()
		end
		return part("Right Arm"), CFrame.new(0, -0.8, 0)
	elseif slot == "leftHand" then
		local hand = part("LeftHand")
		if hand then
			return hand, CFrame.new()
		end
		return part("Left Arm"), CFrame.new(0, -0.8, 0)
	end
	return nil, CFrame.new()
end

-- Кожа: запоминаем исходный цвет, чтобы вернуть при смене героя.
local SKIN_PARTS = {
	"Head",
	"LeftHand",
	"RightHand",
	"LeftLowerArm",
	"RightLowerArm",
	"LeftUpperArm",
	"RightUpperArm",
	"Left Arm",
	"Right Arm",
}

-- Роботу красим ещё и торс с ногами.
local ROBOT_PARTS = {
	"UpperTorso",
	"LowerTorso",
	"Torso",
	"LeftUpperLeg",
	"RightUpperLeg",
	"LeftLowerLeg",
	"RightLowerLeg",
	"LeftFoot",
	"RightFoot",
	"Left Leg",
	"Right Leg",
}

-- Одежда робота прячется в папку внутри персонажа (так она не рисуется) и возвращается обратно.
local function setClothingHidden(character: Model, hidden: boolean)
	local stash = character:FindFirstChild(HIDDEN_CLOTHING)
	if hidden then
		if not stash then
			local folder = Instance.new("Folder")
			folder.Name = HIDDEN_CLOTHING
			folder.Parent = character
			stash = folder
		end
		for _, item in character:GetChildren() do
			if item:IsA("Clothing") or item:IsA("ShirtGraphic") then
				(item :: Instance).Parent = stash
			end
		end
	elseif stash then
		for _, item in stash:GetChildren() do
			item.Parent = character
		end
		stash:Destroy()
	end
end

local function paint(character: Model, names: { string }, color: Color3?)
	for _, name in names do
		local part = character:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			local original = part:GetAttribute("OrigColor")
			if original == nil then
				part:SetAttribute("OrigColor", part.Color)
				original = part.Color
			end
			part.Color = color or original :: Color3
		end
	end
end

local function setSkin(character: Model, color: Color3?, robot: boolean?)
	paint(character, SKIN_PARTS, color)
	paint(character, ROBOT_PARTS, if robot then color else nil)
	setClothingHidden(character, robot == true)
end

local function addAura(character: Model)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "TimeAura"
	attachment.Parent = root
	local aura = Instance.new("ParticleEmitter")
	aura.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	aura.Color = ColorSequence.new(Color3.fromRGB(110, 255, 150), Color3.fromRGB(40, 190, 90))
	aura.LightEmission = 1
	aura.LightInfluence = 0
	aura.Size = NumberSequence.new(0.4, 0)
	aura.Transparency = NumberSequence.new(0.2, 1)
	aura.Lifetime = NumberRange.new(0.8, 1.4)
	aura.Speed = NumberRange.new(0.5, 2)
	aura.SpreadAngle = Vector2.new(180, 180)
	aura.Rate = 14
	aura.Parent = attachment
	-- Свет от бога времени.
	local light = Instance.new("PointLight")
	light.Name = "TimeLight"
	light.Color = Color3.fromRGB(110, 255, 150)
	light.Range = 10
	light.Brightness = 1
	light.Parent = root
end

local function clearCosmetics(character: Model)
	local folder = character:FindFirstChild(COSMETICS)
	if folder then
		folder:Destroy()
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		for _, name in { "TimeAura", "TimeLight" } do
			local item = root:FindFirstChild(name)
			if item then
				item:Destroy()
			end
		end
	end
	setSkin(character, nil)
end

function HeroService:Apply(character: Model, heroId: string)
	if not character:FindFirstChildOfClass("Humanoid") then
		return
	end
	-- Невидимость Локи не должна "переехать" на другого героя.
	Kit.reveal(character)
	clearCosmetics(character)
	character:SetAttribute("Hero", heroId)

	local hero = Heroes.ById[heroId]
	if hero and hero.bodyColor then
		setSkin(character, hero.bodyColor, hero.robot)
	end
	if heroId == "Thanos" then
		return
	end

	local outfit = HeroModel.outfit(heroId)
	local looks = LOOKS[heroId]
	if not outfit or not looks then
		return
	end
	local folder = Instance.new("Model")
	folder.Name = COSMETICS
	for slot, specs in outfit :: any do
		local anchor, offset = mount(character, slot)
		if anchor then
			for _, spec: HeroModel.PartSpec in specs do
				local look = looks[spec.role]
				local part = Instance.new("Part")
				part.Name = spec.name
				part.Shape = SHAPES[spec.shape]
				part.Size = spec.size
				part.Color = look.color
				part.Material = look.material
				part.CanCollide = false
				part.CanQuery = false
				part.CanTouch = false
				part.Massless = true
				part.CastShadow = spec.role == "cape"
				part.CFrame = anchor.CFrame * offset * spec.cframe
				local weld = Instance.new("Weld")
				weld.Part0 = anchor
				weld.Part1 = part
				weld.C0 = offset * spec.cframe
				weld.Parent = part
				part.Parent = folder
			end
		end
	end
	folder.Parent = character
	if heroId == "GodLoki" then
		addAura(character)
	end
end

local function onSelect(player: Player, heroId: unknown): (boolean, string)
	if typeof(heroId) ~= "string" then
		return false, "Неверный запрос"
	end
	local hero = Heroes.ById[heroId]
	local data = DataService:Get(player)
	if not hero or not data then
		return false, "Неизвестный герой"
	end
	if not Heroes.isUnlocked(hero, data) then
		local have, need = Heroes.progress(hero, data)
		local label = if hero.unlock then hero.unlock.label else ""
		return false, `Нужно {need} {label} (сейчас {have})`
	end
	if data.Hero == heroId then
		return false, "Этот герой уже выбран"
	end
	local now = os.clock()
	if now - (lastSwitch[player] or 0) < SWITCH_COOLDOWN then
		return false, "Смена героя раз в 3 секунды"
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and Status.isStunned(humanoid) then
		return false, "Нельзя сменить героя под оглушением"
	end
	lastSwitch[player] = now

	DataService:Update(player, function(d)
		d.Hero = hero.id
	end)
	if character then
		HeroService:Apply(character, hero.id)
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			Fx.pillar(root.Position - Vector3.new(0, 3, 0), hero.color, 60, 1)
			Fx.burst(root.Position, hero.color, 60, 30)
			Fx.flash(root.Position, hero.color, 30, 0.8)
			Fx.sound("Magic", root.Position, 1, 0.8)
		end
	end
	return true, `Теперь ты — {hero.name}!`
end

function HeroService:Init()
	Remotes.func("SelectHero").OnServerInvoke = onSelect
end

function HeroService:Start()
	local function applySaved(player: Player, character: Model)
		local data = DataService:Get(player)
		HeroService:Apply(character, if data then data.Hero else Heroes.Default)
	end

	local function onPlayer(player: Player)
		-- Цвета кожи и одежда применяются после загрузки внешности, иначе их перетрёт BodyColors.
		player.CharacterAppearanceLoaded:Connect(function(character)
			applySaved(player, character)
		end)
		-- Запасной вариант, если внешность так и не загрузилась.
		player.CharacterAdded:Connect(function(character)
			task.delay(3, function()
				if character.Parent and character:GetAttribute("Hero") == nil then
					applySaved(player, character)
				end
			end)
		end)
		if player.Character then
			local data = DataService:Get(player)
			task.spawn(
				HeroService.Apply,
				HeroService,
				player.Character,
				if data then data.Hero else Heroes.Default
			)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastSwitch[player] = nil
	end)
	-- Данные грузятся после спавна: как только загрузились — применяем сохранённого героя.
	DataService:OnChanged(function(player, data: Config.PlayerData)
		local character = player.Character
		if character and character:GetAttribute("Hero") ~= data.Hero then
			HeroService:Apply(character, data.Hero)
		end
	end)
end

return HeroService
