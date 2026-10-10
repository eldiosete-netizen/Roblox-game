-- Ajustes del jugador (se guardan en su cuenta).

local ClientState = require(script.Parent:WaitForChild("ClientState"))
local HUD = require(script.Parent:WaitForChild("HUD"))
local UI = require(script.Parent:WaitForChild("UI"))

local SettingsMenu = {}

local PANEL = "Settings"

local OPTIONS = {
	{ key = "shake", name = "Temblor de cámara al caer" },
	{ key = "fov", name = "Efecto de velocidad en la cámara" },
	{ key = "ghost", name = "Mostrar fantasma (tu mejor intento)" },
	{ key = "wind", name = "Sonido de viento" },
	{ key = "hints", name = "Mostrar controles en pantalla" },
}

local toggles: { [string]: TextButton } = {}

local function refresh()
	for key, button in toggles do
		local on = ClientState.setting(key)
		button.Text = if on then "SÍ" else "NO"
		button.BackgroundColor3 = if on then UI.Colors.Good else UI.Colors.Card
	end
end

function SettingsMenu.start()
	local frame, content = UI.panel(HUD.gui, PANEL, "⚙  Ajustes", UDim2.fromOffset(560, 470))

	UI.new("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 10),
	}, content)

	for i, option in OPTIONS do
		local row = UI.new("Frame", {
			Size = UDim2.new(1, 0, 0, 52),
			BackgroundColor3 = UI.Colors.Card,
			LayoutOrder = i,
		}, content)
		UI.corner(row, 10)
		UI.label(row, {
			Position = UDim2.fromOffset(16, 12),
			Size = UDim2.new(1, -140, 0, 28),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = option.name,
		})
		local toggle = UI.button(row, "SÍ", UI.Colors.Good, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(100, 38),
		})
		toggle.Activated:Connect(function()
			ClientState.setSetting(option.key, not ClientState.setting(option.key))
		end)
		toggles[option.key] = toggle
	end

	UI.label(content, {
		Size = UDim2.new(1, 0, 0, 40),
		LayoutOrder = 100,
		Font = Enum.Font.Gotham,
		TextColor3 = UI.Colors.Muted,
		TextWrapped = true,
		Text = "La sensibilidad de la cámara y el volumen se cambian en el menú de Roblox (tecla Esc).",
	})

	UI.onOpen(PANEL, refresh)
	ClientState.Changed:Connect(function()
		if frame.Visible then
			refresh()
		end
	end)

	HUD.addSideButton("⚙ Ajustes", 30, nil, function()
		UI.toggle(PANEL)
	end)
end

return SettingsMenu
