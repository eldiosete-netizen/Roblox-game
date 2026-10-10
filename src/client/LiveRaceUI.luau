-- Carrera en vivo: menú de salas (crear, unirse, elegir mapa, empezar) y
-- banner con el estado de tu sala.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local ClientState = require(script.Parent:WaitForChild("ClientState"))
local HUD = require(script.Parent:WaitForChild("HUD"))
local MapMenu = require(script.Parent:WaitForChild("MapMenu"))
local UI = require(script.Parent:WaitForChild("UI"))

local LiveRaceUI = {}

local PANEL = "LiveRace"
local PURPLE = Color3.fromRGB(150, 70, 255)
local PLACES = { "1º", "2º", "3º" }
local PHASE_TEXT = {
	waiting = "Esperando",
	starting = "Empezando",
	launching = "Empezando",
	racing = "En carrera",
	results = "Resultados",
}

local banner: Frame
local bannerLabel: TextLabel
local panelFrame: Frame
local body: Frame
local status: { rooms: { any }, room: any? } = { rooms = {} }
local selectedMap: string? = nil
local lastPhase: string? = nil

local function action(name: string, argument: any?)
	local ok, message = Remotes.LiveRoomAction:InvokeServer(name, argument)
	if message then
		HUD.popup(message, if ok then PURPLE else UI.Colors.Bad)
	end
	return ok
end

local function standings(results: { { name: string, time: number } }, limit: number): string
	local parts = {}
	for i = 1, math.min(limit, #results) do
		local entry = results[i]
		table.insert(parts, string.format("%s %s %s", PLACES[i] or (i .. "º"), entry.name, Config.FormatTime(entry.time)))
	end
	return table.concat(parts, "   ·   ")
end

-- ¿Puede este jugador elegir el mapa al crear una sala? (el servidor lo vuelve a comprobar)
local function mapLock(folder: Folder): string?
	local data = ClientState.data
	if folder:GetAttribute("Vip") and not (data and data.vip) then
		return "⭐ Solo VIP"
	end
	local price = folder:GetAttribute("Price") or 0
	if price > 0 and not (data and data.unlockedMaps and data.unlockedMaps[folder.Name]) then
		return "🔒 Bloqueado"
	end
	return nil
end

-- Interfaz del panel -----------------------------------------------------------------------

local function clear()
	for _, child in body:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
end

local function heading(text: string, order: number)
	UI.label(body, {
		Size = UDim2.new(1, 0, 0, 30),
		LayoutOrder = order,
		Font = Enum.Font.GothamBlack,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.Colors.Gold,
		Text = text,
	})
end

-- Fila de botones con los mapas; onPick se llama con el mapa elegido
local function mapPicker(order: number, current: string?, onPick: (string) -> ())
	local row = UI.new("Frame", {
		Size = UDim2.new(1, 0, 0, 64),
		BackgroundTransparency = 1,
		LayoutOrder = order,
	}, body)
	UI.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
	}, row)
	for i, folder in ClientState.mapsSorted() do
		if folder:GetAttribute("Tutorial") then
			continue
		end
		local lock = mapLock(folder)
		local selected = folder.Name == current
		local name = folder:GetAttribute("DisplayName") or folder.Name
		local button = UI.button(row, if lock then name .. "\n" .. lock else name, if selected
			then PURPLE
			elseif lock then UI.Colors.Background
			else UI.Colors.Card, {
			Size = UDim2.fromOffset(150, 60),
			LayoutOrder = i,
			TextColor3 = if lock then UI.Colors.Muted else UI.Colors.Text,
		})
		button.Activated:Connect(function()
			if lock then
				HUD.popup(
					if folder:GetAttribute("Vip") then "⭐ Solo los VIP pueden elegir " .. name else "🔒 Desbloquea " .. name .. " primero",
					UI.Colors.Bad
				)
			else
				onPick(folder.Name)
			end
		end)
	end
end

local function renderLobby()
	heading("Salas abiertas", 1)
	local list = UI.new("ScrollingFrame", {
		Size = UDim2.new(1, 0, 0, 190),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
	}, body)
	UI.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }, list)

	if #status.rooms == 0 then
		UI.label(list, {
			Size = UDim2.new(1, 0, 0, 40),
			TextColor3 = UI.Colors.Muted,
			Text = "No hay salas. ¡Crea la primera!",
		})
	end
	for i, room in status.rooms do
		local row = UI.new("Frame", {
			Size = UDim2.new(1, -10, 0, 54),
			BackgroundColor3 = UI.Colors.Card,
			LayoutOrder = i,
		}, list)
		UI.corner(row, 10)
		UI.label(row, {
			Position = UDim2.fromOffset(14, 6),
			Size = UDim2.new(1, -170, 0, 24),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = string.format("🏁 Sala de %s  ·  %s%s", room.host, room.map, if room.vip then " ⭐" else ""),
		})
		UI.label(row, {
			Position = UDim2.fromOffset(14, 30),
			Size = UDim2.new(1, -170, 0, 18),
			Font = Enum.Font.Gotham,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = UI.Colors.Muted,
			Text = string.format("%d/%d jugadores  ·  %s", room.players, room.max, PHASE_TEXT[room.phase] or room.phase),
		})
		local canJoin = room.players < room.max and room.phase ~= "racing"
		local join = UI.button(row, if canJoin then "Unirse" else "No disponible", if canJoin then PURPLE else UI.Colors.Background, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(140, 40),
			TextColor3 = if canJoin then UI.Colors.Text else UI.Colors.Muted,
		})
		if canJoin then
			join.Activated:Connect(function()
				action("join", room.id)
			end)
		end
	end

	heading("Crear sala: elige el mapa", 3)
	mapPicker(4, selectedMap, function(mapId)
		selectedMap = mapId
		LiveRaceUI.render()
	end)
	local create = UI.button(body, if selectedMap then "➕ Crear sala" else "Elige un mapa", if selectedMap
		then UI.Colors.Good
		else UI.Colors.Background, {
		Size = UDim2.new(1, 0, 0, 48),
		LayoutOrder = 5,
		TextColor3 = if selectedMap then UI.Colors.Text else UI.Colors.Muted,
	})
	create.Activated:Connect(function()
		if selectedMap then
			action("create", selectedMap)
		end
	end)
end

local function renderRoom(room: any)
	heading(string.format("Sala de %s  ·  %s%s", room.host, room.map, if room.vip then " ⭐" else ""), 1)

	local names = {}
	for _, member in room.members do
		table.insert(names, (if member.host then "👑 " else "") .. member.name)
	end
	UI.label(body, {
		Size = UDim2.new(1, 0, 0, 50),
		LayoutOrder = 2,
		Font = Enum.Font.Gotham,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.Colors.Muted,
		Text = string.format("Jugadores (%d/%d): %s", room.players, room.max, table.concat(names, ", ")),
	})

	if room.phase ~= "waiting" then
		UI.label(body, {
			Size = UDim2.new(1, 0, 0, 34),
			LayoutOrder = 3,
			TextColor3 = PURPLE,
			Text = (PHASE_TEXT[room.phase] or room.phase) .. (if room.timeLeft > 0 then string.format("  ·  %d s", room.timeLeft) else ""),
		})
	elseif room.isHost then
		heading("Cambiar mapa", 3)
		mapPicker(4, room.mapId, function(mapId)
			action("setMap", mapId)
		end)
		local enough = room.players >= room.minPlayers
		local start = UI.button(body, if enough
			then "▶ Empezar carrera"
			else string.format("Faltan jugadores (%d/%d)", room.players, room.minPlayers), if enough
			then UI.Colors.Good
			else UI.Colors.Background, {
			Size = UDim2.new(1, 0, 0, 48),
			LayoutOrder = 5,
			TextColor3 = if enough then UI.Colors.Text else UI.Colors.Muted,
		})
		start.Activated:Connect(function()
			action("start")
		end)
	else
		UI.label(body, {
			Size = UDim2.new(1, 0, 0, 34),
			LayoutOrder = 3,
			TextColor3 = UI.Colors.Muted,
			Text = "Esperando a que el anfitrión empiece la carrera...",
		})
	end

	local leave = UI.button(body, "Salir de la sala", UI.Colors.Bad, {
		Size = UDim2.new(1, 0, 0, 44),
		LayoutOrder = 10,
	})
	leave.Activated:Connect(function()
		action("leave")
	end)
end

function LiveRaceUI.render()
	if not panelFrame.Visible then
		return
	end
	clear()
	if status.room then
		renderRoom(status.room)
	else
		renderLobby()
	end
end

-- Banner -------------------------------------------------------------------------------------

local function updateBanner()
	local room = status.room
	banner.Visible = room ~= nil
	if not room then
		lastPhase = nil
		return
	end
	if room.phase == "waiting" then
		bannerLabel.Text = string.format("🏁 Sala de %s · %s · %d/%d jugadores", room.host, room.map, room.players, room.max)
	elseif room.phase == "starting" or room.phase == "launching" then
		bannerLabel.Text = string.format("🏁 La carrera en %s empieza en %d s", room.map, room.timeLeft)
	elseif room.phase == "racing" then
		local text = string.format("🏁 %s · Quedan %d s", room.map, room.timeLeft)
		if #room.results > 0 then
			text ..= "   ·   " .. standings(room.results, 3)
		end
		bannerLabel.Text = text
	elseif room.phase == "results" then
		bannerLabel.Text = "🏁 Resultados: " .. (if #room.results > 0 then standings(room.results, 3) else "nadie terminó")
		if lastPhase ~= "results" then
			HUD.popup("¡Carrera terminada!", PURPLE, standings(room.results, 3))
		end
	end
	lastPhase = room.phase
end

function LiveRaceUI.start()
	banner = UI.new("Frame", {
		Name = "LiveRace",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.fromOffset(760, 34),
		BackgroundColor3 = PURPLE,
		BackgroundTransparency = 0.25,
		Visible = false,
	}, HUD.gui)
	UI.corner(banner, 8)
	UI.autoScale(banner, 0.5)
	bannerLabel = UI.label(banner, {
		Position = UDim2.fromOffset(12, 4),
		Size = UDim2.new(1, -24, 1, -8),
		Text = "",
	})

	local frame, content = UI.panel(HUD.gui, PANEL, "🏁  Carrera en vivo", UDim2.fromOffset(720, 560))
	panelFrame = frame
	body = content
	UI.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10) }, body)

	UI.onOpen(PANEL, function()
		LiveRaceUI.render()
		task.spawn(action, "refresh")
	end)

	MapMenu.addHeaderButton("🏁 Carrera en vivo", 2, PURPLE, function()
		UI.open(PANEL)
	end)

	Remotes.LiveRaceUpdate.OnClientEvent:Connect(function(newStatus)
		status = newStatus
		updateBanner()
		LiveRaceUI.render()
	end)
	ClientState.Changed:Connect(LiveRaceUI.render)
end

return LiveRaceUI
