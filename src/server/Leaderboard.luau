-- Guarda los mejores tiempos (OrderedDataStore) y muestra el ranking global.
-- En Studio, activa "Enable Studio Access to API Services" para que se guarde.
-- Sin acceso a DataStore, el ranking sigue funcionando con los tiempos de la sesión.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Leaderboard = {}

local store: OrderedDataStore? = nil
pcall(function()
	store = DataStoreService:GetOrderedDataStore(Config.DataStoreName)
end)

local sessionBests: { [number]: number } = {}
local names: { [number]: string } = {}
local refreshCallbacks: { () -> () } = {}

local function getName(userId: number): string
	if names[userId] then
		return names[userId]
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	names[userId] = if ok then name else "Jugador"
	return names[userId]
end

-- Devuelve el mejor tiempo guardado (en segundos) o nil
function Leaderboard.loadBest(userId: number): number?
	if not store then
		return nil
	end
	local ok, value = pcall(function()
		return store:GetAsync(tostring(userId))
	end)
	if ok and typeof(value) == "number" then
		return value / 1000
	end
	return nil
end

function Leaderboard.submit(player: Player, seconds: number)
	local userId = player.UserId
	names[userId] = player.Name
	if not sessionBests[userId] or seconds < sessionBests[userId] then
		sessionBests[userId] = seconds
	end

	if store then
		local ms = math.floor(seconds * 1000 + 0.5)
		task.spawn(function()
			local ok, err = pcall(function()
				store:UpdateAsync(tostring(userId), function(old)
					if typeof(old) == "number" and old <= ms then
						return nil -- el récord guardado ya es mejor
					end
					return ms
				end)
			end)
			if not ok then
				warn("[Leaderboard] No se pudo guardar el tiempo:", err)
			end
		end)
	end

	for _, refresh in refreshCallbacks do
		task.spawn(refresh)
	end
end

export type Entry = { userId: number, name: string, seconds: number }

function Leaderboard.getTop(count: number): { Entry }
	local byUser: { [number]: number } = {}

	if store then
		local ok, pages = pcall(function()
			return store:GetSortedAsync(true, count)
		end)
		if ok then
			for _, item in pages:GetCurrentPage() do
				local userId = tonumber(item.key)
				if userId then
					byUser[userId] = item.value / 1000
				end
			end
		end
	end

	for userId, seconds in sessionBests do
		if not byUser[userId] or seconds < byUser[userId] then
			byUser[userId] = seconds
		end
	end

	local list = {}
	for userId, seconds in byUser do
		table.insert(list, { userId = userId, seconds = seconds, name = "" })
	end
	table.sort(list, function(a, b)
		return a.seconds < b.seconds
	end)

	local result = {}
	for i = 1, math.min(count, #list) do
		local entry = list[i]
		entry.name = getName(entry.userId)
		result[i] = entry
	end
	return result
end

-- Crea un SurfaceGui con el top en la cara frontal de la Part
function Leaderboard.startBoard(part: BasePart)
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

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 20)
	padding.PaddingLeft = UDim.new(0, 30)
	padding.PaddingRight = UDim.new(0, 30)
	padding.Parent = frame

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = frame

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 70)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 210, 0)
	title.Text = "🏆 MEJORES TIEMPOS"
	title.LayoutOrder = 0
	title.Parent = frame

	local rows = {}
	for i = 1, Config.LeaderboardSize do
		local row = Instance.new("TextLabel")
		row.Size = UDim2.new(1, 0, 0, 34)
		row.BackgroundTransparency = 1
		row.Font = Enum.Font.GothamBold
		row.TextScaled = true
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = if i <= 3 then Color3.fromRGB(255, 255, 255) else Color3.fromRGB(180, 180, 200)
		row.Text = string.format("%d. ---", i)
		row.LayoutOrder = i
		row.Parent = frame
		rows[i] = row
	end

	local refreshing = false
	local function refresh()
		if refreshing then
			return
		end
		refreshing = true
		local top = Leaderboard.getTop(Config.LeaderboardSize)
		for i, row in rows do
			local entry = top[i]
			row.Text = if entry
				then string.format("%d. %s  —  %s", i, entry.name, Config.FormatTime(entry.seconds))
				else string.format("%d. ---", i)
		end
		refreshing = false
	end
	table.insert(refreshCallbacks, refresh)

	task.spawn(function()
		while part.Parent do
			refresh()
			task.wait(Config.LeaderboardRefresh)
		end
	end)
end

return Leaderboard
