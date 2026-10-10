-- Interfaz de la carrera: cronómetro, parciales, medallas, cuenta atrás,
-- mensajes y botones laterales (Mapas, Lobby...).

local ContextActionService = game:GetService("ContextActionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Sfx = require(Shared:WaitForChild("Sfx"))

local ClientState = require(script.Parent:WaitForChild("ClientState"))
local UI = require(script.Parent:WaitForChild("UI"))

local player = Players.LocalPlayer

local HUD = {}

local gui: ScreenGui
local racePanel: Frame
local timerLabel: TextLabel
local checkpointLabel: TextLabel
local deltaLabel: TextLabel
local mapLabel: TextLabel
local popupLabel: TextLabel
local subPopupLabel: TextLabel
local countdownLabel: TextLabel
local countdownScale: UIScale
local controlsLabel: TextLabel
local sideBar: Frame
local levelLabel: TextLabel
local xpFill: Frame
local coinsLabel: TextLabel

local running = false
local startTime = 0
local countdownToken: {}? = nil

-- Mensajes emergentes ----------------------------------------------------------------

local popupTweens: { Tween } = {}

function HUD.popup(text: string, color: Color3?, subtext: string?)
	for _, tween in popupTweens do
		tween:Cancel()
	end
	table.clear(popupTweens)

	popupLabel.Text = text
	popupLabel.TextColor3 = color or UI.Colors.Text
	subPopupLabel.Text = subtext or ""
	for _, label in { popupLabel, subPopupLabel } do
		label.TextTransparency = 0
		label.TextStrokeTransparency = 0.4
		local tween = TweenService:Create(
			label,
			TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 2),
			{ TextTransparency = 1, TextStrokeTransparency = 1 }
		)
		tween:Play()
		table.insert(popupTweens, tween)
	end
end

-- Botones laterales (otros módulos añaden los suyos) -----------------------------------

function HUD.addSideButton(text: string, order: number, color: Color3?, callback: () -> ()): TextButton
	local button = UI.button(sideBar, text, color or UI.Colors.Card, {
		Size = UDim2.fromOffset(170, 48),
		LayoutOrder = order,
	})
	button.Activated:Connect(callback)
	return button
end

-- Información del mapa actual ----------------------------------------------------------

local function updateStats()
	local data = ClientState.data
	if not data then
		return
	end
	local level, current, needed = Config.LevelFromXP(data.xp)
	levelLabel.Text = string.format("Nivel %d", level) .. (if data.vip then "  ⭐ VIP" else "")
	xpFill.Size = UDim2.fromScale(math.clamp(current / needed, 0, 1), 1)
	coinsLabel.Text = string.format("🪙 %d", data.coins)
end

local function nextMedalText(mapId: string): string
	local folder = ClientState.mapFolder(mapId)
	if not folder or folder:GetAttribute("Tutorial") then
		return ""
	end
	local mapData = ClientState.mapData(mapId)
	local current = mapData and mapData.medal or 0
	if current >= #Config.Medals then
		return "  ·  ¡Todas las medallas!"
	end
	local nextMedal = Config.MedalInfo(current + 1)
	local seconds = folder:GetAttribute(nextMedal.id)
	return string.format("  ·  %s: %s", nextMedal.name, Config.FormatTime(seconds))
end

local function updateMapInfo()
	local mapId = player:GetAttribute("MapId")
	if typeof(mapId) ~= "string" then
		racePanel.Visible = false
		return
	end
	racePanel.Visible = true
	local folder = ClientState.mapFolder(mapId)
	local mapData = ClientState.mapData(mapId)
	local name = folder and folder:GetAttribute("DisplayName") or mapId
	mapLabel.Text = string.format(
		"%s  ·  Mejor: %s%s",
		name,
		Config.FormatTime(mapData and mapData.best),
		nextMedalText(mapId)
	)
end

-- Confeti al batir un récord
local function confetti()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local emitter = UI.new("ParticleEmitter", {
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
			ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 210, 0)),
			ColorSequenceKeypoint.new(0.66, Color3.fromRGB(0, 255, 140)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 170, 255)),
		}),
		EmissionDirection = Enum.NormalId.Top,
		Speed = NumberRange.new(20, 35),
		SpreadAngle = Vector2.new(60, 60),
		Lifetime = NumberRange.new(1, 2),
		Acceleration = Vector3.new(0, -30, 0),
		Size = NumberSequence.new(0.6, 0.2),
		LightEmission = 0.5,
		Rate = 0,
	}, root)
	emitter:Emit(80)
	Debris:AddItem(emitter, 3)
end

-- Cuenta atrás -------------------------------------------------------------------------

local function bumpCountdown(text: string, color: Color3)
	countdownLabel.Visible = true
	countdownLabel.Text = text
	countdownLabel.TextColor3 = color
	countdownScale.Scale = 1.6
	TweenService:Create(countdownScale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

local function hideCountdown()
	countdownToken = nil
	countdownLabel.Visible = false
end

local function resetTimer(text: string)
	running = false
	timerLabel.Text = Config.FormatTime(0)
	timerLabel.TextColor3 = UI.Colors.Text
	checkpointLabel.Text = text
	deltaLabel.Text = ""
end

local function formatDelta(delta: number): (string, Color3)
	if delta <= 0 then
		return string.format("-%.3f", -delta), UI.Colors.Good
	end
	return string.format("+%.3f", delta), UI.Colors.Bad
end

-- Construcción -------------------------------------------------------------------------

local function build()
	gui = UI.new("ScreenGui", {
		Name = "HUD",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, player:WaitForChild("PlayerGui"))
	HUD.gui = gui

	racePanel = UI.new("Frame", {
		Name = "Race",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 44),
		Size = UDim2.fromOffset(520, 150),
		BackgroundTransparency = 1,
		Visible = false,
	}, gui)
	UI.autoScale(racePanel, 0.7)

	timerLabel = UI.label(racePanel, {
		Size = UDim2.new(1, 0, 0, 60),
		Font = Enum.Font.GothamBlack,
		TextStrokeTransparency = 0.5,
		Text = Config.FormatTime(0),
	})
	deltaLabel = UI.label(racePanel, {
		Position = UDim2.fromOffset(0, 60),
		Size = UDim2.new(1, 0, 0, 26),
		TextStrokeTransparency = 0.5,
		Text = "",
	})
	checkpointLabel = UI.label(racePanel, {
		Position = UDim2.fromOffset(0, 88),
		Size = UDim2.new(1, 0, 0, 26),
		TextStrokeTransparency = 0.5,
		Text = "",
	})
	mapLabel = UI.label(racePanel, {
		Position = UDim2.fromOffset(0, 118),
		Size = UDim2.new(1, 0, 0, 22),
		TextColor3 = UI.Colors.Gold,
		TextStrokeTransparency = 0.5,
		Text = "",
	})

	popupLabel = UI.label(gui, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.33),
		Size = UDim2.new(0.8, 0, 0, 64),
		Font = Enum.Font.GothamBlack,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		Text = "",
	})
	UI.new("UITextSizeConstraint", { MaxTextSize = 56 }, popupLabel)
	subPopupLabel = UI.label(gui, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.33, 50),
		Size = UDim2.new(0.8, 0, 0, 30),
		TextColor3 = UI.Colors.Gold,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		Text = "",
	})
	UI.new("UITextSizeConstraint", { MaxTextSize = 28 }, subPopupLabel)

	countdownLabel = UI.label(gui, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(260, 160),
		Font = Enum.Font.GothamBlack,
		TextStrokeTransparency = 0.3,
		Visible = false,
		Text = "",
	})
	countdownScale = UI.new("UIScale", nil, countdownLabel)

	local isTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	controlsLabel = UI.label(gui, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -16),
		Size = UDim2.fromOffset(420, 70),
		Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTransparency = 0.2,
		TextStrokeTransparency = 0.6,
		Text = if isTouch
			then "Botón Deslizar: más velocidad\nSalta hacia una pared: wall run\nSalta en la pared: wall jump"
			else "Corre para ganar velocidad  ·  C / Ctrl: deslizar\nSalta hacia una pared: wall run  ·  Espacio en la pared: wall jump\nR: reiniciar",
		Visible = not isTouch,
	})
	UI.new("UITextSizeConstraint", { MaxTextSize = 18 }, controlsLabel)

	-- Nivel, XP y monedas (arriba a la izquierda)
	local stats = UI.new("Frame", {
		Name = "Stats",
		Position = UDim2.fromOffset(16, 64),
		Size = UDim2.fromOffset(220, 84),
		BackgroundColor3 = UI.Colors.Background,
		BackgroundTransparency = 0.3,
	}, gui)
	UI.corner(stats, 10)
	UI.autoScale(stats, 0.6)
	levelLabel = UI.label(stats, {
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -24, 0, 26),
		Font = Enum.Font.GothamBlack,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Nivel 1",
	})
	local xpBar = UI.new("Frame", {
		Position = UDim2.fromOffset(12, 36),
		Size = UDim2.new(1, -24, 0, 10),
		BackgroundColor3 = UI.Colors.Card,
	}, stats)
	UI.corner(xpBar, 5)
	xpFill = UI.new("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = UI.Colors.Good,
	}, xpBar)
	UI.corner(xpFill, 5)
	coinsLabel = UI.label(stats, {
		Position = UDim2.fromOffset(12, 52),
		Size = UDim2.new(1, -24, 0, 26),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.Colors.Gold,
		Text = "🪙 0",
	})

	UI.label(gui, {
		Name = "Version",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -8, 1, -4),
		Size = UDim2.fromOffset(120, 16),
		Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTransparency = 0.5,
		Text = "v" .. Config.Version,
	})

	sideBar = UI.new("Frame", {
		Name = "SideBar",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.45, 0),
		Size = UDim2.fromOffset(170, 300),
		BackgroundTransparency = 1,
	}, gui)
	UI.new("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}, sideBar)
	UI.autoScale(sideBar, 0.6)
end

-- En móvil, los botones de ContextActionService son pequeños: los agrandamos
function HUD.enlargeTouchButton(actionName: string, position: UDim2)
	local button = ContextActionService:GetButton(actionName)
	if button then
		button.Size = UDim2.fromOffset(80, 80)
		button.Position = position
		local title = button:FindFirstChild("ActionTitle")
		if title and title:IsA("TextLabel") then
			title.TextScaled = true
		end
	end
end

function HUD.setControlsVisible(visible: boolean)
	local isTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	controlsLabel.Visible = visible and not isTouch
end

function HUD.start()
	build()

	RunService.RenderStepped:Connect(function()
		if running then
			timerLabel.Text = Config.FormatTime(os.clock() - startTime)
		end
	end)

	player:GetAttributeChangedSignal("MapId"):Connect(updateMapInfo)
	ClientState.Changed:Connect(updateMapInfo)
	ClientState.Changed:Connect(updateStats)
	ClientState.Changed:Connect(function()
		HUD.setControlsVisible(ClientState.setting("hints"))
	end)
	updateMapInfo()
	updateStats()

	HUD.addSideButton("🏠 Lobby", 90, nil, function()
		Remotes.ReturnToLobby:FireServer()
	end)

	Remotes.RaceCountdown.OnClientEvent:Connect(function(_mapId: string, seconds: number)
		resetTimer("¡Prepárate!")
		local token = {}
		countdownToken = token
		for i = seconds, 1, -1 do
			if countdownToken ~= token then
				return
			end
			bumpCountdown(tostring(i), UI.Colors.Text)
			Sfx.play("Countdown", 0.8)
			task.wait(1)
		end
	end)

	Remotes.RaceStarted.OnClientEvent:Connect(function(_mapId: string, total: number)
		-- "¡YA!" llega del servidor, así el tiempo empieza a la vez en los dos lados
		local token = {}
		countdownToken = token
		bumpCountdown("¡YA!", UI.Colors.Good)
		Sfx.play("Go", 1.4, 0.8)
		task.delay(0.8, function()
			if countdownToken == token then
				hideCountdown()
			end
		end)
		running = true
		startTime = os.clock()
		checkpointLabel.Text = string.format("Checkpoint 0/%d", total)
		deltaLabel.Text = ""
	end)

	Remotes.CheckpointReached.OnClientEvent:Connect(function(index: number, total: number, split: number, delta: number?)
		checkpointLabel.Text = string.format("Checkpoint %d/%d", index, total)
		local subtext = nil
		if delta then
			local text, color = formatDelta(delta)
			deltaLabel.Text = text
			deltaLabel.TextColor3 = color
			subtext = text .. " respecto a tu récord"
		end
		HUD.popup(string.format("Checkpoint %d  ·  %s", index, Config.FormatTime(split)), UI.Colors.Good, subtext)
		Sfx.play("Checkpoint", 1.2)
	end)

	Remotes.RaceFinished.OnClientEvent:Connect(function(result)
		running = false
		timerLabel.Text = Config.FormatTime(result.time) -- tiempo oficial del servidor
		checkpointLabel.Text = "¡Meta!"

		local parts = {}
		if result.rewards.place then
			table.insert(parts, string.format("Puesto %dº en la carrera en vivo", result.rewards.place))
		end
		if result.newMedal then
			local medal = Config.MedalInfo(result.medal)
			table.insert(parts, "¡Medalla de " .. medal.name .. "!")
		end
		if result.rewards.coins and result.rewards.coins > 0 then
			table.insert(parts, string.format("+%d monedas", result.rewards.coins))
		end
		if result.rewards.xp and result.rewards.xp > 0 then
			table.insert(parts, string.format("+%d XP", result.rewards.xp))
		end
		if result.rewards.levelUp then
			table.insert(parts, string.format("¡Nivel %d!", result.rewards.levelUp))
		end
		local subtext = table.concat(parts, "   ")

		if result.isRecord then
			timerLabel.TextColor3 = UI.Colors.Gold
			HUD.popup("¡NUEVO RÉCORD!  " .. Config.FormatTime(result.time), UI.Colors.Gold, subtext)
			Sfx.play("Record", 1, 0.8)
			confetti()
		else
			local text, color = formatDelta(result.time - result.best)
			deltaLabel.Text = text
			deltaLabel.TextColor3 = color
			HUD.popup(string.format("%s  (%s)", Config.FormatTime(result.time), text), UI.Colors.Bad, subtext)
			Sfx.play("Finish", 1, 0.5)
		end
		if result.newMedal then
			Sfx.play("Medal", 1.6, 0.7)
		end
	end)

	Remotes.RaceCancelled.OnClientEvent:Connect(function(reason: string?)
		hideCountdown()
		resetTimer("Cruza la salida azul para empezar")
		if reason then
			HUD.popup(reason, UI.Colors.Bad)
		end
	end)

	Remotes.Notify.OnClientEvent:Connect(function(text: string, color: Color3?)
		HUD.popup(text, color or UI.Colors.Text)
	end)

	-- Reiniciar
	ContextActionService:BindAction("ParkourRestart", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			Remotes.RequestRestart:FireServer()
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.R, Enum.KeyCode.ButtonY)
	ContextActionService:SetTitle("ParkourRestart", "Reiniciar")
	ContextActionService:SetPosition("ParkourRestart", UDim2.new(1, -200, 1, -210))
	HUD.enlargeTouchButton("ParkourRestart", UDim2.new(1, -200, 1, -230))
end

return HUD
