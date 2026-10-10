-- Arranque del servidor: crea los remotes, carga mapas y pone en marcha los sistemas.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes")) -- crea los RemoteEvents antes que nada

local Server = script.Parent
local PlayerData = require(Server:WaitForChild("PlayerData"))
local Maps = require(Server:WaitForChild("Maps"))
local Leaderboard = require(Server:WaitForChild("Leaderboard"))
local RaceService = require(Server:WaitForChild("RaceService"))
local Ghosts = require(Server:WaitForChild("Ghosts"))
local LiveRace = require(Server:WaitForChild("LiveRace"))
local Economy = require(Server:WaitForChild("Economy"))
local Shop = require(Server:WaitForChild("Shop"))
local Passes = require(Server:WaitForChild("Passes"))

local Config = require(Shared:WaitForChild("Config"))

Maps.init()

-- Carteles de ranking del lobby
local boards = Maps.lobby():FindFirstChild("Boards")
if boards then
	for _, board in boards:GetChildren() do
		local map = Maps.get(board:GetAttribute("MapId") or "")
		if map and board:IsA("BasePart") then
			Leaderboard.startBoard(board, map.id, map.name, map.folder:GetAttribute("Color") or Color3.new(1, 1, 1))
		end
	end
end

RaceService.init()

-- Rankings para el menú del cliente (usa la caché, no gasta peticiones extra)
Remotes.GetLeaderboard.OnServerInvoke = function(_player, mapId)
	local map = typeof(mapId) == "string" and Maps.get(mapId)
	if not map or map.tutorial then
		return nil
	end
	return {
		all = Leaderboard.getTop(map.id, "all", Config.LeaderboardSize),
		week = Leaderboard.getTop(map.id, "week", Config.LeaderboardSize),
	}
end
Ghosts.init()
LiveRace.init()
Economy.init()
Shop.init()
Passes.init()

-- Tabla de jugadores (leaderstats)
local function countMedals(data): number
	local total = 0
	for _, mapData in data.maps do
		total += mapData.medal or 0
	end
	return total
end

local function setupLeaderstats(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	for _, name in { "Nivel", "Monedas", "Medallas" } do
		local value = Instance.new("IntValue")
		value.Name = name
		value.Parent = leaderstats
	end
	leaderstats.Parent = player
end

Players.PlayerAdded:Connect(setupLeaderstats)
for _, player in Players:GetPlayers() do
	setupLeaderstats(player)
end

-- Se ejecuta en cada sincronización de datos: actualiza la tabla de jugadores
PlayerData.addSnapshotField(function(player, snapshot)
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local stats = leaderstats :: any
		stats.Nivel.Value = Config.LevelFromXP(snapshot.xp)
		stats.Monedas.Value = snapshot.coins
		stats.Medallas.Value = countMedals(snapshot)
	end
end)
