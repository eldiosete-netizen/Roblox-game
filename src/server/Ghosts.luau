-- Guarda y envía el "fantasma" (tu mejor intento grabado) de cada mapa.
-- El cliente graba sus posiciones; el servidor solo acepta el fantasma
-- justo después de un récord válido.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local RaceService = require(script.Parent:WaitForChild("RaceService"))

local Ghosts = {}

local MAX_LENGTH = Config.GhostMaxSamples * 40

local store: DataStore? = nil
pcall(function()
	store = DataStoreService:GetDataStore(Config.DataStores.Ghosts)
end)

local cache: { [Player]: { [string]: string | false } } = {}
local pending: { [Player]: { mapId: string, expires: number } } = {}

local function key(player: Player, mapId: string): string
	return player.UserId .. "_" .. mapId
end

local function load(player: Player, mapId: string)
	local playerCache = cache[player]
	if not playerCache then
		return
	end
	if playerCache[mapId] == nil then
		playerCache[mapId] = false
		if store then
			local ok, value = pcall(function()
				return store:GetAsync(key(player, mapId))
			end)
			if ok and typeof(value) == "string" then
				playerCache[mapId] = value
			end
		end
	end
	local ghost = playerCache[mapId]
	if player:GetAttribute("MapId") == mapId then
		Remotes.GhostData:FireClient(player, mapId, if ghost then ghost else nil)
	end
end

function Ghosts.init()
	local function onPlayerAdded(player: Player)
		cache[player] = {}
		-- Al entrar en un mapa, enviamos su fantasma
		player:GetAttributeChangedSignal("MapId"):Connect(function()
			local mapId = player:GetAttribute("MapId")
			if typeof(mapId) == "string" then
				task.spawn(load, player, mapId)
			end
		end)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		cache[player] = nil
		pending[player] = nil
	end)

	RaceService.onFinish(function(player, map, result)
		if result.isRecord and not map.tutorial then
			pending[player] = { mapId = map.id, expires = os.clock() + 15 }
		end
	end)

	Remotes.SubmitGhost.OnServerEvent:Connect(function(player, mapId, encoded)
		local expected = pending[player]
		if not expected or expected.mapId ~= mapId or os.clock() > expected.expires then
			return
		end
		if typeof(encoded) ~= "string" or #encoded == 0 or #encoded > MAX_LENGTH then
			return
		end
		pending[player] = nil
		if cache[player] then
			cache[player][mapId] = encoded
		end
		if store then
			task.spawn(function()
				local ok, err = pcall(function()
					store:SetAsync(key(player, mapId), encoded, { player.UserId })
				end)
				if not ok then
					warn("[Ghosts] No se pudo guardar el fantasma:", err)
				end
			end)
		end
	end)
end

return Ghosts
