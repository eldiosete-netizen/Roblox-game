-- Ranking global por mapa (OrderedDataStore) y carteles del lobby.
-- Sin acceso a DataStore, el ranking funciona con los tiempos de la sesión.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Leaderboard = {}

export type Entry = { userId: number, name: string, seconds: number }

type Board = {
	week: number, -- semana a la que pertenecen los datos "week"
	cached: { [string]: { [number]: number } }, -- último resultado del DataStore
	session: { [string]: { [number]: number } }, -- tiempos de esta sesión
	renderers: { () -> () },
}

local boards: { [string]: Board } = {}
local names: { [number]: string } = {}

-- "all" = histórico, "week" = esta semana (se reinicia cada lunes, hora UTC)
local PERIODS = { "all", "week" }
local PERIOD_TITLES = { all = "Histórico", week = "Esta semana" }

local function currentWeek(): number
	-- El 1 de enero de 1970 fue jueves: +3 días para que la semana empiece en lunes
	return math.floor((os.time() + 3 * 86400) / (7 * 86400))
end

local function storeName(mapId: string, period: string): string
	if period == "week" then
		return Config.DataStores.TimesPrefix .. mapId .. "_W" .. currentWeek()
	end
	return Config.DataStores.TimesPrefix .. mapId
end

local function getBoard(mapId: string): Board
	local board = boards[mapId]
	if board then
		-- Nueva semana: el ranking semanal empieza de cero
		if board.week ~= currentWeek() then
			board.week = currentWeek()
			board.cached.week = {}
			board.session.week = {}
		end
		return board
	end
	board = { week = currentWeek(), cached = {}, session = {}, renderers = {} }
	for _, period in PERIODS do
		board.cached[period] = {}
		board.session[period] = {}
	end
	boards[mapId] = board
	return board
end

local storeCache: { [string]: any } = {} -- nombre -> OrderedDataStore | false

local function getStore(mapId: string, period: string): OrderedDataStore?
	local name = storeName(mapId, period)
	if storeCache[name] == nil then
		local ok, store = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, name)
		storeCache[name] = if ok then store else false
	end
	return storeCache[name] or nil
end

local function getName(userId: number): string
	if names[userId] then
		return names[userId]
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	names[userId] = if ok then name else "Jugador"
	return names[userId]
end

local function render(mapId: string)
	for _, renderer in getBoard(mapId).renderers do
		task.spawn(renderer)
	end
end

function Leaderboard.submit(player: Player, mapId: string, seconds: number)
	local board = getBoard(mapId)
	local userId = player.UserId
	names[userId] = player.Name
	local ms = math.floor(seconds * 1000 + 0.5)

	for _, period in PERIODS do
		local session = board.session[period]
		if not session[userId] or seconds < session[userId] then
			session[userId] = seconds
		end
		local store = getStore(mapId, period)
		if store then
			task.spawn(function()
				local ok, err = pcall(function()
					store:UpdateAsync(tostring(userId), function(old)
						if typeof(old) == "number" and old <= ms then
							return nil
						end
						return ms
					end)
				end)
				if not ok then
					warn("[Leaderboard] No se pudo guardar el tiempo:", err)
				end
			end)
		end
	end
	render(mapId)
end

-- Lee el DataStore (gasta peticiones; se llama cada LeaderboardRefresh)
local function fetch(mapId: string, period: string)
	local store = getStore(mapId, period)
	if not store then
		return
	end
	local ok, pages = pcall(function()
		return store:GetSortedAsync(true, Config.LeaderboardSize)
	end)
	if not ok then
		return
	end
	local result = {}
	for _, item in pages:GetCurrentPage() do
		local userId = tonumber(item.key)
		if userId then
			result[userId] = item.value / 1000
		end
	end
	getBoard(mapId).cached[period] = result
end

function Leaderboard.getTop(mapId: string, period: string, count: number): { Entry }
	local board = getBoard(mapId)
	local merged: { [number]: number } = {}
	for userId, seconds in board.cached[period] or {} do
		merged[userId] = seconds
	end
	for userId, seconds in board.session[period] or {} do
		if not merged[userId] or seconds < merged[userId] then
			merged[userId] = seconds
		end
	end

	local list = {}
	for userId, seconds in merged do
		table.insert(list, { userId = userId, seconds = seconds, name = "" })
	end
	table.sort(list, function(a, b)
		return a.seconds < b.seconds
	end)

	local result = {}
	for i = 1, math.min(count, #list) do
		list[i].name = getName(list[i].userId)
		result[i] = list[i]
	end
	return result
end

local function makeLabel(parent: Instance, props: { [string]: any }): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	for key, value in props do
		(label :: any)[key] = value
	end
	label.Parent = parent
	return label
end

-- Dibuja el ranking de un mapa en la cara frontal de una Part
function Leaderboard.startBoard(part: BasePart, mapId: string, title: string, color: Color3)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = part

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	frame.BorderSizePixel = 0
	frame.Parent = gui

	makeLabel(frame, {
		Size = UDim2.new(1, -40, 0, 70),
		Position = UDim2.fromOffset(20, 10),
		Font = Enum.Font.GothamBlack,
		TextColor3 = color,
		Text = "🏆 " .. title,
	})

	local columns = {}
	for i, period in PERIODS do
		local column = Instance.new("Frame")
		column.BackgroundTransparency = 1
		column.Size = UDim2.new(1 / #PERIODS, -30, 1, -100)
		column.Position = UDim2.new((i - 1) / #PERIODS, 20, 0, 90)
		column.Parent = frame

		local layout = Instance.new("UIListLayout")
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Padding = UDim.new(0, 4)
		layout.Parent = column

		makeLabel(column, {
			Size = UDim2.new(1, 0, 0, 44),
			Font = Enum.Font.GothamBlack,
			TextColor3 = Color3.fromRGB(170, 170, 190),
			Text = PERIOD_TITLES[period],
			LayoutOrder = 0,
		})

		local rows = {}
		for rank = 1, Config.LeaderboardSize do
			rows[rank] = makeLabel(column, {
				Size = UDim2.new(1, 0, 0, 46),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = if rank <= 3 then Color3.new(1, 1, 1) else Color3.fromRGB(170, 170, 190),
				Text = string.format("%d. ---", rank),
				LayoutOrder = rank,
			})
		end
		columns[period] = rows
	end

	local function draw()
		for period, rows in columns do
			local top = Leaderboard.getTop(mapId, period, Config.LeaderboardSize)
			for rank, row in rows do
				local entry = top[rank]
				row.Text = if entry
					then string.format("%d. %s  %s", rank, entry.name, Config.FormatTime(entry.seconds))
					else string.format("%d. ---", rank)
			end
		end
	end
	table.insert(getBoard(mapId).renderers, draw)

	task.spawn(function()
		while part.Parent do
			for period in columns do
				fetch(mapId, period)
			end
			draw()
			task.wait(Config.LeaderboardRefresh)
		end
	end)
end

return Leaderboard
