-- Pequeña librería para crear la interfaz con un estilo común.

local TweenService = game:GetService("TweenService")

local UI = {}

UI.Colors = {
	Background = Color3.fromRGB(18, 20, 30),
	Panel = Color3.fromRGB(28, 31, 45),
	Card = Color3.fromRGB(38, 42, 60),
	Accent = Color3.fromRGB(0, 170, 255),
	Text = Color3.new(1, 1, 1),
	Muted = Color3.fromRGB(160, 165, 190),
	Good = Color3.fromRGB(0, 230, 120),
	Bad = Color3.fromRGB(255, 90, 90),
	Gold = Color3.fromRGB(255, 205, 40),
}

function UI.new(className: string, props: { [string]: any }?, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in (props or {}) :: { [string]: any } do
		(instance :: any)[key] = value
	end
	instance.Parent = parent
	return instance
end

function UI.corner(parent: Instance, radius: number?)
	UI.new("UICorner", { CornerRadius = UDim.new(0, radius or 10) }, parent)
end

function UI.padding(parent: Instance, pixels: number)
	local p = UDim.new(0, pixels)
	UI.new("UIPadding", { PaddingTop = p, PaddingBottom = p, PaddingLeft = p, PaddingRight = p }, parent)
end

function UI.label(parent: Instance, props: { [string]: any }): TextLabel
	local label = UI.new("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextColor3 = UI.Colors.Text,
		TextScaled = true,
	}, nil)
	for key, value in props do
		(label :: any)[key] = value
	end
	label.Parent = parent
	return label
end

function UI.button(parent: Instance, text: string, color: Color3?, props: { [string]: any }?): TextButton
	local button = UI.new("TextButton", {
		BackgroundColor3 = color or UI.Colors.Accent,
		Font = Enum.Font.GothamBlack,
		TextColor3 = UI.Colors.Text,
		TextScaled = true,
		Text = text,
		AutoButtonColor = true,
	}, nil)
	for key, value in (props or {}) :: { [string]: any } do
		(button :: any)[key] = value
	end
	UI.corner(button, 8)
	UI.new("UITextSizeConstraint", { MaxTextSize = 28 }, button)
	button.Parent = parent
	return button
end

-- Escala un elemento según el tamaño de la pantalla (móviles más pequeño)
function UI.autoScale(guiObject: GuiObject, minScale: number?)
	local scale = UI.new("UIScale", nil, guiObject)
	local camera = workspace.CurrentCamera
	local function update()
		local size = camera.ViewportSize
		scale.Scale = math.clamp(math.min(size.X / 1100, size.Y / 650), minScale or 0.55, 1)
	end
	update()
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
end

-- Paneles: solo uno abierto a la vez -----------------------------------------------

local panels: { [string]: { frame: GuiObject, onOpen: (() -> ())? } } = {}
local openName: string? = nil

function UI.panel(gui: ScreenGui, name: string, title: string, size: UDim2): (Frame, Frame)
	local frame = UI.new("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = size,
		BackgroundColor3 = UI.Colors.Panel,
		Visible = false,
	}, gui)
	UI.corner(frame, 14)
	UI.new("UIStroke", { Color = UI.Colors.Accent, Thickness = 2, Transparency = 0.4 }, frame)
	UI.autoScale(frame)

	UI.label(frame, {
		Name = "Title",
		Size = UDim2.new(1, -120, 0, 40),
		Position = UDim2.fromOffset(20, 14),
		Font = Enum.Font.GothamBlack,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = title,
	})

	local close = UI.button(frame, "X", UI.Colors.Bad, {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 14),
		Size = UDim2.fromOffset(40, 40),
	})
	close.Activated:Connect(function()
		UI.close(name)
	end)

	local content = UI.new("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(20, 66),
		Size = UDim2.new(1, -40, 1, -86),
	}, frame)

	panels[name] = { frame = frame }
	return frame, content
end

-- Registra un panel con diseño propio (para que se abra y cierre como los demás)
function UI.registerPanel(name: string, frame: GuiObject)
	frame.Visible = false
	panels[name] = { frame = frame }
end

function UI.onOpen(name: string, callback: () -> ())
	panels[name].onOpen = callback
end

function UI.open(name: string)
	if not panels[name] then
		return
	end
	for other, panel in panels do
		panel.frame.Visible = other == name
	end
	openName = name
	local panel = panels[name]
	if panel.onOpen then
		panel.onOpen()
	end
	local scale = panel.frame:FindFirstChildOfClass("UIScale")
	if scale then
		local target = scale.Scale
		scale.Scale = target * 0.9
		TweenService:Create(scale, TweenInfo.new(0.15, Enum.EasingStyle.Back), { Scale = target }):Play()
	end
end

function UI.close(name: string?)
	local target = name or openName
	if target and panels[target] then
		panels[target].frame.Visible = false
	end
	if target == openName then
		openName = nil
	end
end

function UI.toggle(name: string)
	if openName == name then
		UI.close(name)
	else
		UI.open(name)
	end
end

function UI.isOpen(name: string): boolean
	return openName == name
end

return UI
