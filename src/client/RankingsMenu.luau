-- Panel de rankings: top de cada mapa (histórico y semanal) desde cualquier sitio.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local ClientState = require(script.Parent:WaitForChild("ClientState"))
local HUD = require(script.Parent:WaitForChild("HUD"))
local UI = require(script.Parent:WaitForChild("UI"))

local player = Players.LocalPlayer

local RankingsMenu = {}

local PANEL = "Rankings"
local PERIODS = { { id = "all", name = "Histórico" }, { id = "week", name = "Esta semana" } }

local tabs: Frame
local columns: { [string]: Frame } = {}
local currentMap: string? = nil
local requestId = 0

local function fillColumn(column: Frame, entries: { { name: string, seconds: number } })
	for _, child in column:GetChildren() do
		if child:IsA("TextLabel") and child.Name == "Row" then
			child:Destroy()
		end
	end
	if #entries == 0 then
		UI.label(column, {
			Name = "Row",
			Size = UDim2.new(1, 0, 0, 30),
			LayoutOrder = 1,
			TextColor3 = UI.Colors.Muted,
			Text = "Aún no hay tiempos",
		})
		return
	end
	for rank, entry in entries do
		local isMe = entry.name == player.Name
		UI.label(column, {
			Name = "Row",
			Size = UDim2.new(1, 0, 0, 30),
			LayoutOrder = rank,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = if isMe then UI.Colors.Gold elseif rank <= 3 then UI.Colors.Text else UI.Colors.Muted,
			Text = string.format("%d. %s   %s", rank, entry.name, Config.FormatTime(entry.seconds)),
		})
	end
end

local function showMap(mapId: string)
	currentMap = mapId
	for _, button in tabs:GetChildren() do
		if button:IsA("TextButton") then
			button.BackgroundColor3 = if button.Name == mapId then UI.Colors.Accent else UI.Colors.Card
		end
	end

	requestId += 1
	local myRequest = requestId
	for _, column in columns do
		fillColumn(column, {})
	end
	local data = Remotes.GetLeaderboard:InvokeServer(mapId)
	if myRequest ~= requestId or not data then
		return -- el jugador ya cambió de mapa
	end
	for _, period in PERIODS do
		fillColumn(columns[period.id], data[period.id] or {})
	end
end

local function buildTabs()
	for _, child in tabs:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	local first = nil
	for i, folder in ClientState.mapsSorted() do
		if folder:GetAttribute("Tutorial") then
			continue
		end
		first = first or folder.Name
		local button = UI.button(tabs, folder:GetAttribute("DisplayName") or folder.Name, UI.Colors.Card, {
			Name = folder.Name,
			Size = UDim2.fromOffset(150, 40),
			LayoutOrder = i,
		})
		button.Activated:Connect(function()
			showMap(folder.Name)
		end)
	end
	return first
end

function RankingsMenu.start()
	local _, content = UI.panel(HUD.gui, PANEL, "🏆  Rankings", UDim2.fromOffset(720, 520))

	tabs = UI.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 40),
	}, content)
	UI.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 10),
	}, tabs)

	for i, period in PERIODS do
		local column = UI.new("Frame", {
			Position = UDim2.new((i - 1) / 2, if i == 1 then 0 else 8, 0, 54),
			Size = UDim2.new(0.5, -8, 1, -54),
			BackgroundColor3 = UI.Colors.Card,
		}, content)
		UI.corner(column, 10)
		UI.padding(column, 12)
		UI.new("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}, column)
		UI.label(column, {
			Size = UDim2.new(1, 0, 0, 34),
			LayoutOrder = 0,
			Font = Enum.Font.GothamBlack,
			TextColor3 = UI.Colors.Gold,
			Text = period.name,
		})
		columns[period.id] = column
	end

	UI.onOpen(PANEL, function()
		local first = buildTabs()
		local target = player:GetAttribute("MapId")
		if typeof(target) ~= "string" or not tabs:FindFirstChild(target) then
			target = currentMap or first
		end
		if target then
			task.spawn(showMap, target)
		end
	end)

	HUD.addSideButton("🏆 Rankings", 15, nil, function()
		UI.toggle(PANEL)
	end)
end

return RankingsMenu
