-- Selector de mapas: tu mejor tiempo, medallas conseguidas y tiempos objetivo.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local ClientState = require(script.Parent:WaitForChild("ClientState"))
local HUD = require(script.Parent:WaitForChild("HUD"))
local UI = require(script.Parent:WaitForChild("UI"))

local MapMenu = {}

local PANEL = "Maps"

local list: ScrollingFrame
local header: Frame

local function medalRow(parent: Instance, folder: Folder, earned: number)
	local row = UI.new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 82),
		Size = UDim2.new(1, -170, 0, 24),
	}, parent)
	UI.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 10),
	}, row)
	for rank = 1, #Config.Medals do
		local medal = Config.MedalInfo(rank)
		local seconds = folder:GetAttribute(medal.id)
		if seconds then
			UI.label(row, {
				Size = UDim2.fromOffset(110, 24),
				LayoutOrder = rank,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = medal.color,
				TextTransparency = if earned >= rank then 0 else 0.55,
				Text = (if earned >= rank then "● " else "○ ") .. string.format("%.1fs", seconds),
			})
		end
	end
end

local function play(mapId: string)
	local ok, message = Remotes.RequestMap:InvokeServer(mapId)
	if ok then
		UI.close(PANEL)
	elseif message then
		HUD.popup(message, UI.Colors.Bad)
	end
end

-- Otros módulos pueden personalizar las tarjetas (por ejemplo, bloquear mapas VIP).
-- Si el decorador devuelve una función, sustituye a la acción del botón JUGAR.
type Decorator = (Frame, Folder, TextButton) -> (() -> ())?
local cardDecorators: { Decorator } = {}

function MapMenu.decorateCards(decorator: Decorator)
	table.insert(cardDecorators, decorator)
end

-- Fila superior para botones extra (tutorial, carrera en vivo...)
function MapMenu.addHeaderButton(text: string, order: number, color: Color3, callback: () -> ()): TextButton
	local button = UI.button(header, text, color, {
		Size = UDim2.fromOffset(250, 44),
		LayoutOrder = order,
	})
	button.Activated:Connect(callback)
	return button
end

function MapMenu.refresh()
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	for i, folder in ClientState.mapsSorted() do
		if folder:GetAttribute("Tutorial") then
			continue
		end
		local color = folder:GetAttribute("Color") or UI.Colors.Accent
		local mapData = ClientState.mapData(folder.Name)
		local earned = mapData and mapData.medal or 0

		local card = UI.new("Frame", {
			Name = folder.Name,
			Size = UDim2.new(1, -12, 0, 118),
			BackgroundColor3 = UI.Colors.Card,
			LayoutOrder = i,
		}, list)
		UI.corner(card, 12)
		UI.new("Frame", {
			Size = UDim2.new(0, 8, 1, 0),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
		}, card)

		UI.label(card, {
			Position = UDim2.fromOffset(16, 10),
			Size = UDim2.new(1, -180, 0, 36),
			Font = Enum.Font.GothamBlack,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = folder:GetAttribute("DisplayName") or folder.Name,
		})
		UI.label(card, {
			Name = "Best",
			Position = UDim2.fromOffset(16, 50),
			Size = UDim2.new(1, -180, 0, 26),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = UI.Colors.Muted,
			Text = string.format(
				"Mejor: %s   ·   Medalla: %s",
				Config.FormatTime(mapData and mapData.best),
				if earned > 0 then Config.MedalInfo(earned).name else "ninguna"
			),
		})
		medalRow(card, folder, earned)

		local playButton = UI.button(card, "JUGAR", UI.Colors.Good, {
			Name = "Play",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -14, 0.5, 0),
			Size = UDim2.fromOffset(140, 56),
		})
		local action = function()
			play(folder.Name)
		end
		for _, decorate in cardDecorators do
			action = decorate(card, folder, playButton) or action
		end
		playButton.Activated:Connect(function()
			action()
		end)
	end
end

function MapMenu.start()
	local frame, content = UI.panel(HUD.gui, PANEL, "🗺  Mapas", UDim2.fromOffset(720, 560))

	header = UI.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 44),
	}, content)
	UI.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 10),
	}, header)

	list = UI.new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 54),
		Size = UDim2.new(1, 0, 1, -54),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, content)
	UI.new("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 10),
	}, list)

	UI.onOpen(PANEL, MapMenu.refresh)
	ClientState.Changed:Connect(function()
		if frame.Visible then
			MapMenu.refresh()
		end
	end)

	HUD.addSideButton("🗺 Mapas", 10, UI.Colors.Accent, function()
		UI.toggle(PANEL)
	end)
end

return MapMenu
