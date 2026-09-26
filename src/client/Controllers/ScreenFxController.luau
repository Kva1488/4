--!strict
-- Эффекты на весь экран:
-- • Щелчок — кинематографичные полосы, приближение камеры, белая вспышка, мир теряет цвет;
-- • получение камня — большой баннер и вспышка цвета камня;
-- • толчок FOV при использовании способностей (вызывается из AbilityController).

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Heroes = require(ReplicatedStorage.Shared.Heroes)
local Items = require(ReplicatedStorage.Shared.Items)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Ui = require(script.Parent.Parent.Ui)

local player = Players.LocalPlayer

local BASE_FOV = 70
local BAR_HEIGHT = 0.11

local ScreenFxController = {}

local gui: ScreenGui
local topBar: Frame
local bottomBar: Frame
local flash: Frame
local bannerTitle: TextLabel
local bannerSubtitle: TextLabel
local banner: Frame
local grade: ColorCorrectionEffect

local zoom = Instance.new("NumberValue") -- постоянное смещение FOV (приближение при щелчке)
local punch = 0 -- кратковременный толчок FOV

local function tween(instance: Instance, duration: number, goal: { [string]: any }, style: Enum.EasingStyle?)
	local t = TweenService:Create(instance, TweenInfo.new(duration, style or Enum.EasingStyle.Quad), goal)
	t:Play()
	return t
end

-- Толчок FOV: положительный — "удар" наружу, отрицательный — рывок внутрь (перемотка).
function ScreenFxController.fovPunch(amount: number)
	if math.abs(amount) > math.abs(punch) then
		punch = amount
	end
end

local function setBars(visible: boolean)
	local height = if visible then BAR_HEIGHT else 0
	tween(topBar, 0.5, { Size = UDim2.fromScale(1, height) })
	tween(bottomBar, 0.5, { Size = UDim2.fromScale(1, height) })
end

local function flashScreen(color: Color3, from: number, duration: number)
	flash.BackgroundColor3 = color
	flash.BackgroundTransparency = from
	tween(flash, duration, { BackgroundTransparency = 1 })
end

local bannerToken = 0

local function showBanner(title: string, subtitle: string, color: Color3, duration: number)
	bannerToken += 1
	local token = bannerToken
	bannerTitle.Text = title
	bannerTitle.TextColor3 = color
	bannerSubtitle.Text = subtitle
	banner.Visible = true
	local scale = banner:FindFirstChildOfClass("UIScale") :: UIScale
	scale.Scale = 0.6
	bannerTitle.TextTransparency = 0
	bannerSubtitle.TextTransparency = 0
	tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(duration, function()
		-- Новый баннер мог прийти раньше — тогда старый таймер его не гасит.
		if token == bannerToken then
			tween(bannerTitle, 0.5, { TextTransparency = 1 })
			tween(bannerSubtitle, 0.5, { TextTransparency = 1 })
		end
	end)
end

-- Общий баннер от сервера (босс, арена): extra = { title, subtitle, color }.
local function onBanner(extra: any)
	if type(extra) ~= "table" then
		return
	end
	local color = if typeof(extra.color) == "Color3" then extra.color else Ui.Colors.Gold
	flashScreen(color, 0.75, 0.8)
	ScreenFxController.fovPunch(6)
	showBanner(tostring(extra.title or ""), tostring(extra.subtitle or ""), color, 4)
end

-- Новый уровень: золотая вспышка и баннер.
local function onLevelUp(level: number)
	local gold = Color3.fromRGB(255, 205, 70)
	flashScreen(gold, 0.55, 1)
	ScreenFxController.fovPunch(8)
	Ui.playSound("Purchase", 0.7, 1.4)
	showBanner(`⭐ УРОВЕНЬ {level}`, "Монеты за уровень зачислены!", gold, 3)
end

local function onSnapCharge()
	setBars(true)
	tween(zoom, 1.6, { Value = -16 }, Enum.EasingStyle.Sine)
	tween(grade, 1.6, { Saturation = -0.35, Contrast = 0.25 })
end

local function onSnap(_center: Vector3, erased: number)
	flashScreen(Color3.new(1, 1, 1), 0, 1.6)
	zoom.Value = 0
	ScreenFxController.fovPunch(25)
	grade.Saturation = -1
	grade.Contrast = 0.3
	showBanner(
		"*ЩЁЛК*",
		if erased > 0 then `Стёрто: {erased}` else "Никого не задело…",
		Color3.new(1, 1, 1),
		2.5
	)
	task.delay(2, function()
		setBars(false)
		tween(grade, 3, { Saturation = 0, Contrast = 0 })
	end)
end

local function onErased()
	task.delay(0.6, function()
		showBanner(
			"Ты стёрт щелчком…",
			"Мистер Старк, мне нехорошо…",
			Color3.fromRGB(190, 190, 190),
			3
		)
	end)
end

-- Кратковременная "плёнка" цвета поверх мира: насыщенность, оттенок и контраст с плавным возвратом.
local function tint(color: Color3, saturation: number, duration: number, fade: number?)
	grade.TintColor = color
	grade.Saturation = saturation
	task.delay(duration, function()
		tween(grade, fade or 0.6, { TintColor = Color3.new(1, 1, 1), Saturation = 0, Contrast = 0 })
	end)
end

-- Перемотка времени: зелёная вспышка и "рывок" камеры.
local function onRewind()
	flashScreen(Color3.fromRGB(110, 255, 150), 0.5, 0.6)
	ScreenFxController.fovPunch(-14)
	tint(Color3.fromRGB(190, 255, 205), -0.3, 0.3)
end

-- Тебя остановили во времени: мир серо-зелёный, пока длится пауза.
local function onTimePaused(duration: number)
	grade.Contrast = 0.2
	tint(Color3.fromRGB(170, 255, 190), -0.85, duration, 0.4)
	showBanner("ВРЕМЯ ОСТАНОВЛЕНО", "⏳", Color3.fromRGB(110, 255, 150), duration - 0.5)
end

-- Скипетр Локи: синяя пелена контроля разума.
local function onMindControlled(duration: number)
	flashScreen(Color3.fromRGB(70, 170, 255), 0.55, 0.8)
	tint(Color3.fromRGB(160, 200, 255), -0.4, duration)
	showBanner(
		"ПОД КОНТРОЛЕМ",
		"Скипетр Локи подчинил твою волю",
		Color3.fromRGB(110, 190, 255),
		duration - 0.4
	)
end

-- Невидимость Локи (видит только сам Локи).
local function onInvisible(duration: number)
	flashScreen(Color3.fromRGB(60, 200, 90), 0.6, 0.5)
	tint(Color3.fromRGB(200, 255, 210), -0.25, duration)
	showBanner(
		"НЕВИДИМОСТЬ",
		"Следующий удар кинжалом: «Сюрприз!» ×3",
		Color3.fromRGB(110, 255, 150),
		1.5
	)
end

-- «Славная цель»: кинематографичный момент для всех рядом.
local function onGloriousPurpose()
	setBars(true)
	tween(zoom, 1.2, { Value = -12 }, Enum.EasingStyle.Sine)
	tint(Color3.fromRGB(200, 255, 215), -0.3, 3.2, 1.2)
	task.delay(0.6, function()
		flashScreen(Color3.fromRGB(110, 255, 150), 0.2, 1.4)
		ScreenFxController.fovPunch(18)
		showBanner(
			"СЛАВНАЯ ЦЕЛЬ",
			"«Ради вас. Ради всех нас.»",
			Color3.fromRGB(110, 255, 150),
			3
		)
	end)
	task.delay(3.2, function()
		zoom.Value = 0
		setBars(false)
	end)
end

local function onHeroUnlocked(heroId: string)
	local hero = Heroes.ById[heroId]
	if not hero then
		return
	end
	flashScreen(hero.color, 0.3, 1.5)
	ScreenFxController.fovPunch(14)
	showBanner(
		string.upper(hero.name),
		"Новый герой открыт! Меню героев [H]",
		hero.color,
		4
	)
end

-- Подъём Соковии: земля уходит из-под ног.
local function onSokovia()
	ScreenFxController.fovPunch(10)
	flashScreen(Color3.fromRGB(255, 110, 80), 0.6, 0.8)
	showBanner(
		"ПОДЪЁМ СОКОВИИ",
		"Нет на мне нитей",
		Color3.fromRGB(255, 90, 70),
		2.2
	)
end

-- Взлом Альтрона: красные помехи, способности недоступны.
local function onHacked(duration: number)
	showBanner(
		"ВЗЛОМ",
		"Способности отключены",
		Color3.fromRGB(255, 70, 60),
		duration - 0.3
	)
	for i = 0, 5 do
		task.delay(i * 0.12, function()
			flashScreen(Color3.fromRGB(255, 40, 40), 0.7, 0.1)
		end)
	end
	tint(Color3.fromRGB(255, 190, 190), -0.5, duration)
end

-- Тор: вспышки молний и название приёма.
local function onThunder(title: string)
	local thunder = Color3.fromRGB(150, 210, 255)
	showBanner(string.upper(title), "⚡", thunder, 2)
	ScreenFxController.fovPunch(10)
	for i = 0, 2 do
		task.delay(i * 0.18, function()
			flashScreen(if i == 1 then Color3.new(1, 1, 1) else thunder, 0.55, 0.2)
		end)
	end
	tint(Color3.fromRGB(200, 225, 255), -0.3, 1.2)
end

-- Конец мультивселенной: шесть вспышек цветов камней, затем белый экран.
local function onMultiverseEnd()
	setBars(true)
	tween(zoom, 1.5, { Value = -14 }, Enum.EasingStyle.Sine)
	showBanner(
		"КОНЕЦ МУЛЬТИВСЕЛЕННОЙ",
		"Шесть камней. Одна воля.",
		Color3.fromRGB(255, 215, 90),
		3
	)
	for i, stone in Items.Stones do
		task.delay(i * 0.3, function()
			flashScreen(stone.color, 0.55, 0.3)
			ScreenFxController.fovPunch(6)
		end)
	end
	task.delay(#Items.Stones * 0.3 + 0.4, function()
		zoom.Value = 0
		flashScreen(Color3.new(1, 1, 1), 0, 1.4)
		ScreenFxController.fovPunch(25)
		tint(Color3.new(1, 1, 1), -0.8, 0.6, 2)
	end)
	task.delay(#Items.Stones * 0.3 + 2.2, function()
		setBars(false)
	end)
end

local function onStoneCollected(stoneId: string, count: number)
	local stone = Items.StoneById[stoneId]
	if not stone then
		return
	end
	flashScreen(stone.color, 0.45, 1)
	ScreenFxController.fovPunch(12)
	showBanner(string.upper(stone.name), `получен · {count}/{#Items.Stones}`, stone.color, 2.5)
	if count == #Items.Stones then
		task.delay(3.2, function()
			flashScreen(Color3.new(1, 1, 1), 0.3, 1.5)
			showBanner(
				"ПЕРЧАТКА ЗАРЯЖЕНА",
				"Щелчок [G] доступен",
				Color3.fromRGB(255, 215, 90),
				3.5
			)
		end)
	end
end

local function build()
	gui = Ui.create("ScreenGui", {
		Name = "ScreenFx",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 30,
		Parent = player:WaitForChild("PlayerGui"),
	})
	topBar = Ui.create("Frame", {
		Size = UDim2.fromScale(1, 0),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		Parent = gui,
	})
	bottomBar = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		Parent = gui,
	})
	flash = Ui.create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = gui,
	})
	banner = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromOffset(700, 110),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	}, { Ui.create("UIScale", {}), Ui.create("UISizeConstraint", { MaxSize = Vector2.new(math.huge, 110) }) })
	bannerTitle = Ui.label({
		Size = UDim2.fromScale(1, 0.65),
		Text = "",
		Font = Enum.Font.GothamBlack,
		TextTransparency = 1,
		Parent = banner,
	})
	Ui.create("UIStroke", { Thickness = 3, Transparency = 0.2, Parent = bannerTitle })
	bannerSubtitle = Ui.label({
		Position = UDim2.fromScale(0, 0.68),
		Size = UDim2.fromScale(1, 0.3),
		Text = "",
		TextColor3 = Ui.Colors.Text,
		Font = Enum.Font.GothamMedium,
		TextTransparency = 1,
		Parent = banner,
	})
	Ui.create("UIStroke", { Thickness = 1.5, Transparency = 0.4, Parent = bannerSubtitle })

	-- На узких экранах баннер сжимается по ширине.
	local function fit()
		local camera = workspace.CurrentCamera
		local width = if camera then camera.ViewportSize.X else 1280
		banner.Size = UDim2.fromOffset(math.min(700, width - 32), 110)
	end
	fit()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end

	grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "ScreenFxGrade"
	grade.Parent = Lighting
end

function ScreenFxController:Start()
	build()

	Remotes.event("ScreenFx").OnClientEvent:Connect(function(kind: string, center: Vector3, extra: any)
		if kind == "SnapCharge" then
			onSnapCharge()
		elseif kind == "Snap" then
			onSnap(center, tonumber(extra) or 0)
		elseif kind == "Erased" then
			onErased()
		elseif kind == "Rewind" then
			onRewind()
		elseif kind == "TimePaused" then
			onTimePaused(tonumber(extra) or 3)
		elseif kind == "MindControlled" then
			onMindControlled(tonumber(extra) or 2)
		elseif kind == "Invisible" then
			onInvisible(tonumber(extra) or 4)
		elseif kind == "GloriousPurpose" then
			onGloriousPurpose()
		elseif kind == "HeroUnlocked" then
			onHeroUnlocked(tostring(extra))
		elseif kind == "Sokovia" then
			onSokovia()
		elseif kind == "MultiverseEnd" then
			onMultiverseEnd()
		elseif kind == "Thunder" then
			onThunder(tostring(extra))
		elseif kind == "Hacked" then
			onHacked(tonumber(extra) or 3)
		elseif kind == "Banner" then
			onBanner(extra)
		elseif kind == "LevelUp" then
			onLevelUp(tonumber(extra) or 1)
		end
	end)
	Remotes.event("StoneCollected").OnClientEvent:Connect(onStoneCollected)

	RunService.RenderStepped:Connect(function(dt)
		punch = punch * math.exp(-dt * 7)
		local camera = workspace.CurrentCamera
		if camera then
			camera.FieldOfView = BASE_FOV + zoom.Value + punch
		end
	end)
end

return ScreenFxController
