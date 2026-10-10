-- Menú de inicio: aparece al entrar al juego.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local ClientState = require(script.Parent:WaitForChild("ClientState"))
local HUD = require(script.Parent:WaitForChild("HUD"))
local UI = require(script.Parent:WaitForChild("UI"))

local player = Players.LocalPlayer

local StartMenu = {}

local gui: ScreenGui
local tutorialButton: TextButton
local tutorialHint: TextLabel

local function close()
	local background = gui:FindFirstChild("Background") :: Frame
	TweenService:Create(background, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
	for _, descendant in background:GetDescendants() do
		if descendant:IsA("GuiObject") then
			descendant.Visible = false
		end
	end
	task.delay(0.3, function()
		gui.Enabled = false
	end)
end

local function updateTutorialHint()
	local data = ClientState.data
	local recommended = data ~= nil and not data.tutorialDone
	tutorialHint.Visible = recommended
	tutorialButton.BackgroundColor3 = if recommended then UI.Colors.Good else UI.Colors.Card
end

function StartMenu.start()
	gui = UI.new("ScreenGui", {
		Name = "StartMenu",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 10,
	}, player:WaitForChild("PlayerGui"))

	local background = UI.new("Frame", {
		Name = "Background",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = UI.Colors.Background,
		BackgroundTransparency = 0.15,
	}, gui)
	UI.new("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(0, 60, 110), Color3.fromRGB(60, 0, 90)),
		Rotation = 45,
	}, background)

	local column = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(520, 460),
		BackgroundTransparency = 1,
	}, background)
	UI.autoScale(column, 0.6)

	UI.label(column, {
		Size = UDim2.new(1, 0, 0, 90),
		Font = Enum.Font.GothamBlack,
		Text = "PARKOUR DE VELOCIDAD",
		TextStrokeTransparency = 0.5,
	})
	UI.label(column, {
		Position = UDim2.fromOffset(0, 92),
		Size = UDim2.new(1, 0, 0, 30),
		Font = Enum.Font.Gotham,
		TextColor3 = UI.Colors.Muted,
		Text = "Corre, desliza y salta por las paredes. Bate tu récord.",
	})

	local playButton = UI.button(column, "JUGAR", UI.Colors.Accent, {
		Position = UDim2.fromOffset(60, 160),
		Size = UDim2.new(1, -120, 0, 70),
	})
	playButton.Activated:Connect(close)

	tutorialButton = UI.button(column, "TUTORIAL", UI.Colors.Card, {
		Position = UDim2.fromOffset(60, 250),
		Size = UDim2.new(1, -120, 0, 60),
	})
	tutorialButton.Activated:Connect(function()
		close()
		local ok, message = Remotes.RequestMap:InvokeServer("tutorial")
		if not ok and message then
			HUD.popup(message, UI.Colors.Bad)
		end
	end)
	tutorialHint = UI.label(column, {
		Position = UDim2.fromOffset(60, 312),
		Size = UDim2.new(1, -120, 0, 22),
		TextColor3 = UI.Colors.Good,
		Text = "¡Recomendado si es tu primera vez!",
		Visible = false,
	})

	local settingsButton = UI.button(column, "AJUSTES", UI.Colors.Card, {
		Position = UDim2.fromOffset(60, 350),
		Size = UDim2.new(1, -120, 0, 60),
	})
	settingsButton.Activated:Connect(function()
		close()
		UI.open("Settings")
	end)

	UI.label(background, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -12),
		Size = UDim2.fromOffset(200, 24),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = UI.Colors.Muted,
		Text = "Versión " .. Config.Version,
	})

	updateTutorialHint()
	ClientState.Changed:Connect(updateTutorialHint)
end

return StartMenu
