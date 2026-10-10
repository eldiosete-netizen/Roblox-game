-- Interfaz de la carrera: cronómetro, checkpoints, mejor tiempo y mensajes.

local ContextActionService = game:GetService("ContextActionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Sfx = require(Shared:WaitForChild("Sfx"))

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

-- Construcción de la UI -------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "RaceHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local function label(props: { [string]: any }): TextLabel
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBlack
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextStrokeTransparency = 0.5
	text.TextScaled = true
	for key, value in props do
		(text :: any)[key] = value
	end
	text.Parent = gui
	return text
end

local timerLabel = label({
	Name = "Timer",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 50),
	Size = UDim2.new(0, 320, 0, 60),
	Text = Config.FormatTime(0),
})

local checkpointLabel = label({
	Name = "Checkpoint",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 112),
	Size = UDim2.new(0, 320, 0, 26),
	Font = Enum.Font.GothamBold,
	Text = "Cruza la salida azul para empezar",
})

local bestLabel = label({
	Name = "Best",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 140),
	Size = UDim2.new(0, 320, 0, 22),
	Font = Enum.Font.GothamBold,
	TextColor3 = Color3.fromRGB(255, 210, 0),
	Text = "Mejor: " .. Config.FormatTime(nil),
})

local popupLabel = label({
	Name = "Popup",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.35),
	Size = UDim2.new(0, 600, 0, 70),
	TextTransparency = 1,
	TextStrokeTransparency = 1,
})

local countdownLabel = label({
	Name = "Countdown",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.45),
	Size = UDim2.new(0, 260, 0, 160),
	Text = "",
	Visible = false,
})
local countdownScale = Instance.new("UIScale")
countdownScale.Parent = countdownLabel

label({
	Name = "Controls",
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 16, 1, -16),
	Size = UDim2.new(0, 380, 0, 70),
	Font = Enum.Font.Gotham,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTransparency = 0.2,
	Text = "Corre para ganar velocidad\nC / Ctrl: deslizar   ·   Salta hacia una pared: wall run\nEspacio en la pared: wall jump   ·   R: reiniciar",
})

-- Mensajes emergentes ---------------------------------------------------------

local popupTween: Tween? = nil
local function showPopup(text: string, color: Color3?)
	if popupTween then
		popupTween:Cancel()
	end
	popupLabel.Text = text
	popupLabel.TextColor3 = color or Color3.new(1, 1, 1)
	popupLabel.TextTransparency = 0
	popupLabel.TextStrokeTransparency = 0.4
	popupTween = TweenService:Create(
		popupLabel,
		TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 1.6),
		{ TextTransparency = 1, TextStrokeTransparency = 1 }
	)
	popupTween:Play()
end

-- Cuenta atrás -------------------------------------------------------------------

local countdownToken: {}? = nil

local function bumpCountdown(text: string, color: Color3)
	countdownLabel.Visible = true
	countdownLabel.Text = text
	countdownLabel.TextColor3 = color
	countdownLabel.TextTransparency = 0
	countdownLabel.TextStrokeTransparency = 0.3
	countdownScale.Scale = 1.6
	TweenService:Create(countdownScale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

local function hideCountdown()
	countdownToken = nil
	countdownLabel.Visible = false
end

-- Confeti al batir un récord
local function confetti()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
		ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 210, 0)),
		ColorSequenceKeypoint.new(0.66, Color3.fromRGB(0, 255, 140)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 170, 255)),
	})
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Speed = NumberRange.new(20, 35)
	emitter.SpreadAngle = Vector2.new(60, 60)
	emitter.Lifetime = NumberRange.new(1, 2)
	emitter.Acceleration = Vector3.new(0, -30, 0)
	emitter.Size = NumberSequence.new(0.6, 0.2)
	emitter.LightEmission = 0.5
	emitter.Rate = 0
	emitter.Parent = root
	emitter:Emit(80)
	Debris:AddItem(emitter, 3)
end

-- Estado de la carrera ----------------------------------------------------------

local running = false
local startTime = 0

local function updateBest()
	bestLabel.Text = "Mejor: " .. Config.FormatTime(player:GetAttribute("BestTime"))
end
updateBest()
player:GetAttributeChangedSignal("BestTime"):Connect(updateBest)

RunService.RenderStepped:Connect(function()
	if running then
		timerLabel.Text = Config.FormatTime(os.clock() - startTime)
	end
end)

remotes:WaitForChild("RaceCountdown").OnClientEvent:Connect(function(seconds: number)
	running = false
	timerLabel.Text = Config.FormatTime(0)
	timerLabel.TextColor3 = Color3.new(1, 1, 1)
	checkpointLabel.Text = "¡Prepárate!"

	local token = {}
	countdownToken = token
	for i = seconds, 1, -1 do
		if countdownToken ~= token then
			return
		end
		bumpCountdown(tostring(i), Color3.new(1, 1, 1))
		Sfx.play("Countdown", 0.8)
		task.wait(1)
	end
end)

remotes:WaitForChild("RaceStarted").OnClientEvent:Connect(function(total: number)
	-- "¡YA!" llega del servidor, así el tiempo empieza a la vez en los dos lados
	local token = {}
	countdownToken = token
	bumpCountdown("¡YA!", Color3.fromRGB(0, 255, 140))
	Sfx.play("Go", 1.4, 0.8)
	task.delay(0.8, function()
		if countdownToken == token then
			hideCountdown()
		end
	end)

	running = true
	startTime = os.clock()
	timerLabel.TextColor3 = Color3.new(1, 1, 1)
	checkpointLabel.Text = string.format("Checkpoint 0/%d", total)
end)

remotes:WaitForChild("CheckpointReached").OnClientEvent:Connect(function(index: number, total: number, split: number)
	checkpointLabel.Text = string.format("Checkpoint %d/%d", index, total)
	showPopup(string.format("Checkpoint %d  ·  %s", index, Config.FormatTime(split)), Color3.fromRGB(0, 255, 140))
	Sfx.play("Checkpoint", 1.2)
end)

remotes:WaitForChild("RaceFinished").OnClientEvent:Connect(function(time: number, best: number, isRecord: boolean)
	running = false
	timerLabel.Text = Config.FormatTime(time) -- tiempo oficial del servidor
	checkpointLabel.Text = "¡Meta!"
	if isRecord then
		timerLabel.TextColor3 = Color3.fromRGB(255, 210, 0)
		showPopup("¡NUEVO RÉCORD!  " .. Config.FormatTime(time), Color3.fromRGB(255, 210, 0))
		Sfx.play("Record", 1, 0.8)
		confetti()
	else
		local diff = time - best
		showPopup(string.format("%s  (+%.3f)", Config.FormatTime(time), diff), Color3.fromRGB(255, 120, 120))
		Sfx.play("Finish", 1, 0.5)
	end
end)

remotes:WaitForChild("RaceCancelled").OnClientEvent:Connect(function(reason: string?)
	running = false
	hideCountdown()
	timerLabel.Text = Config.FormatTime(0)
	timerLabel.TextColor3 = Color3.new(1, 1, 1)
	checkpointLabel.Text = "Cruza la salida azul para empezar"
	if reason then
		showPopup(reason, Color3.fromRGB(255, 120, 120))
	end
end)

-- Reiniciar ---------------------------------------------------------------------

local requestRestart = remotes:WaitForChild("RequestRestart") :: RemoteEvent
ContextActionService:BindAction("ParkourRestart", function(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		requestRestart:FireServer()
	end
	return Enum.ContextActionResult.Sink
end, true, Enum.KeyCode.R, Enum.KeyCode.ButtonY)
ContextActionService:SetTitle("ParkourRestart", "Reiniciar")
ContextActionService:SetPosition("ParkourRestart", UDim2.new(1, -170, 1, -170))
