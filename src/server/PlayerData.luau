-- Datos guardados de cada jugador (DataStore) y sincronización con su cliente.
-- Si el DataStore no está disponible (Studio sin acceso a API), el juego
-- funciona igual pero no se guarda nada entre sesiones.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local PlayerData = {}

local DEFAULT = {
	coins = 0,
	xp = 0,
	maps = {}, -- [mapId] = { best = segundos, splits = {...}, medal = rango, runs = n }
	mapsVersion = 0,
	unlockedMaps = {}, -- [mapId] = true (niveles comprados con monedas)
	owned = {}, -- [itemId] = true
	equipped = {}, -- [tipo] = itemId
	settings = {},
	tutorialDone = false,
}

local store: DataStore? = nil
pcall(function()
	store = DataStoreService:GetDataStore(Config.DataStores.Player)
end)

type Profile = { data: { [string]: any }, canSave: boolean, dirty: boolean }

local profiles: { [Player]: Profile } = {}
local session: { [Player]: { [string]: any } } = {} -- datos que no se guardan (VIP, etc.)
local snapshotBuilders: { (Player, { [string]: any }) -> () } = {}
local loadedCallbacks: { (Player, { [string]: any }) -> () } = {}

local function deepCopy(value: any): any
	if typeof(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopy(v)
	end
	return copy
end

-- Añade los campos que falten (por ejemplo, tras una actualización del juego)
local function reconcile(data: { [string]: any }, template: { [string]: any })
	for key, value in template do
		if data[key] == nil then
			data[key] = deepCopy(value)
		elseif typeof(value) == "table" and typeof(data[key]) == "table" then
			reconcile(data[key], value)
		end
	end
end

local function key(player: Player): string
	return "player_" .. player.UserId
end

function PlayerData.load(player: Player): { [string]: any }
	local data = nil
	local canSave = store ~= nil

	if store then
		for attempt = 1, 3 do
			local ok, result = pcall(function()
				return store:GetAsync(key(player))
			end)
			if ok then
				data = result
				break
			elseif attempt == 3 then
				warn("[PlayerData] No se pudieron cargar los datos de", player.Name, result)
				canSave = false -- no sobrescribir datos buenos con datos vacíos
			else
				task.wait(1)
			end
		end
	end

	if typeof(data) ~= "table" then
		data = {}
	end
	reconcile(data, DEFAULT)
	-- Los recorridos cambiaron: los récords antiguos ya no valen
	if data.mapsVersion ~= Config.MapDataVersion then
		data.maps = {}
		data.mapsVersion = Config.MapDataVersion
	end

	profiles[player] = { data = data, canSave = canSave, dirty = false }
	session[player] = session[player] or {}
	for _, callback in loadedCallbacks do
		task.spawn(callback, player, data)
	end
	PlayerData.sync(player)
	return data
end

function PlayerData.get(player: Player): { [string]: any }?
	local profile = profiles[player]
	return profile and profile.data
end

-- Espera a que los datos estén cargados (máx. 10 s)
function PlayerData.wait(player: Player): { [string]: any }?
	local start = os.clock()
	while not profiles[player] and player.Parent and os.clock() - start < 10 do
		task.wait(0.1)
	end
	return PlayerData.get(player)
end

function PlayerData.session(player: Player): { [string]: any }
	session[player] = session[player] or {}
	return session[player]
end

function PlayerData.onLoaded(callback: (Player, { [string]: any }) -> ())
	table.insert(loadedCallbacks, callback)
end

-- Otros módulos pueden añadir campos calculados a lo que recibe el cliente
function PlayerData.addSnapshotField(builder: (Player, { [string]: any }) -> ())
	table.insert(snapshotBuilders, builder)
end

local syncQueued: { [Player]: boolean } = {}

-- Marca los datos como cambiados y los envía al cliente (agrupado por frame)
function PlayerData.sync(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.dirty = true
	if syncQueued[player] then
		return
	end
	syncQueued[player] = true
	task.defer(function()
		syncQueued[player] = nil
		local current = profiles[player]
		if not current or not player.Parent then
			return
		end
		local snapshot = deepCopy(current.data)
		for _, builder in snapshotBuilders do
			builder(player, snapshot)
		end
		Remotes.DataSync:FireClient(player, snapshot)
	end)
end

function PlayerData.save(player: Player)
	local profile = profiles[player]
	if not profile or not profile.canSave or not profile.dirty or not store then
		return
	end
	local ok, err = pcall(function()
		store:SetAsync(key(player), profile.data, { player.UserId })
	end)
	if ok then
		profile.dirty = false
	else
		warn("[PlayerData] No se pudieron guardar los datos de", player.Name, err)
	end
end

function PlayerData.release(player: Player)
	PlayerData.save(player)
	profiles[player] = nil
	session[player] = nil
end

-- task.defer: deja que los demás módulos registren sus callbacks antes de cargar
Players.PlayerAdded:Connect(function(player)
	task.defer(PlayerData.load, player)
end)
for _, player in Players:GetPlayers() do
	task.defer(PlayerData.load, player)
end
Players.PlayerRemoving:Connect(PlayerData.release)

-- El cliente pide sus datos al arrancar (por si se perdió el primer envío)
Remotes.DataSync.OnServerEvent:Connect(function(player)
	PlayerData.sync(player)
end)

-- Ajustes del jugador (solo claves conocidas y valores sí/no)
Remotes.UpdateSetting.OnServerEvent:Connect(function(player, settingKey, value)
	local profile = profiles[player]
	if not profile or typeof(settingKey) ~= "string" or typeof(value) ~= "boolean" then
		return
	end
	if Config.DefaultSettings[settingKey] == nil then
		return
	end
	profile.data.settings[settingKey] = value
	PlayerData.sync(player)
end)

task.spawn(function()
	while true do
		task.wait(Config.AutosaveInterval)
		for player in profiles do
			task.spawn(PlayerData.save, player)
		end
	end
end)

game:BindToClose(function()
	local pending = 0
	for player in profiles do
		pending += 1
		task.spawn(function()
			PlayerData.save(player)
			pending -= 1
		end)
	end
	local start = os.clock()
	while pending > 0 and os.clock() - start < 25 do
		task.wait(0.1)
	end
end)

return PlayerData
