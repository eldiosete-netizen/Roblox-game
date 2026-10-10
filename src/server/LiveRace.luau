-- Carreras en vivo por salas. Cualquiera puede crear una sala y elegir el mapa
-- (siempre que él pueda jugarlo: VIP para el mapa VIP, nivel desbloqueado...).
-- Los demás se unen aunque no tengan ese mapa: lo que cuenta es el anfitrión.
--
-- Fases de una sala: waiting (esperando) -> starting (cuenta atrás tras pulsar
-- "Empezar") -> racing -> results -> waiting

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Maps = require(script.Parent:WaitForChild("Maps"))
local RaceService = require(script.Parent:WaitForChild("RaceService"))

local LiveRace = {}

type Finisher = { player: Player, name: string, time: number }
type Room = {
	id: number,
	host: Player,
	mapId: string,
	members: { Player },
	phase: string,
	phaseEnds: number,
	participants: { [Player]: boolean },
	finishers: { Finisher },
	raceStart: number,
}

local settings = Config.LiveRace
local rooms: { [number]: Room } = {}
local roomOf: { [Player]: Room } = {}
local nextId = 1

local raceEndHandlers: { (Player, number?, number) -> () } = {}

-- Se llama al terminar cada carrera: (jugador, puesto o nil si no terminó, participantes)
function LiveRace.onRaceEnd(handler: (Player, number?, number) -> ())
	table.insert(raceEndHandlers, handler)
end

-- Estado para los clientes --------------------------------------------------------------

local function mapName(mapId: string): string
	local map = Maps.get(mapId)
	return if map then map.name else mapId
end

local function count(set: { [Player]: boolean }): number
	local n = 0
	for _ in set do
		n += 1
	end
	return n
end

local function publicResults(room: Room): { { name: string, time: number } }
	local list = {}
	for _, finisher in room.finishers do
		table.insert(list, { name = finisher.name, time = finisher.time })
	end
	return list
end

local function summary(room: Room): { [string]: any }
	local map = Maps.get(room.mapId)
	return {
		id = room.id,
		host = room.host.DisplayName,
		mapId = room.mapId,
		map = mapName(room.mapId),
		vip = map ~= nil and map.vip,
		players = #room.members,
		max = settings.MaxPlayers,
		phase = room.phase,
	}
end

local function details(room: Room, player: Player): { [string]: any }
	local members = {}
	for _, member in room.members do
		table.insert(members, { name = member.DisplayName, host = member == room.host })
	end
	local info = summary(room)
	info.isHost = room.host == player
	info.members = members
	info.minPlayers = settings.MinPlayers
	info.timeLeft = math.max(0, math.ceil(room.phaseEnds - os.clock()))
	info.results = publicResults(room)
	return info
end

local function broadcast()
	local list = {}
	for _, room in rooms do
		table.insert(list, summary(room))
	end
	table.sort(list, function(a, b)
		return a.id < b.id
	end)
	for _, player in Players:GetPlayers() do
		local room = roomOf[player]
		Remotes.LiveRaceUpdate:FireClient(player, { rooms = list, room = room and details(room, player) })
	end
end

-- Salas ------------------------------------------------------------------------------------

local function validMap(host: Player, mapId: any): (Maps.MapInfo?, string?)
	local map = typeof(mapId) == "string" and Maps.get(mapId)
	if not map or map.tutorial then
		return nil, "Mapa no válido"
	end
	local ok, message = RaceService.canEnter(host, map)
	if not ok then
		if map.vip then
			return nil, "⭐ Solo los VIP pueden elegir " .. map.name
		end
		return nil, message
	end
	return map, nil
end

local function removeMember(player: Player)
	local room = roomOf[player]
	if not room then
		return
	end
	roomOf[player] = nil
	room.participants[player] = nil
	local index = table.find(room.members, player)
	if index then
		table.remove(room.members, index)
	end
	if #room.members == 0 then
		rooms[room.id] = nil
	elseif room.host == player then
		room.host = room.members[1]
		Remotes.Notify:FireClient(room.host, "👑 Ahora eres el anfitrión de la sala")
	end
	-- Si estaba en plena carrera en vivo, vuelve a modo normal
	local state = RaceService.getState(player)
	if state and state.mode == "live" then
		RaceService.setMode(player, "solo")
	end
end

local actions: { [string]: (Player, any) -> (boolean, string?) } = {}

function actions.create(player: Player, mapId: any): (boolean, string?)
	if roomOf[player] then
		return false, "Ya estás en una sala"
	end
	local map, message = validMap(player, mapId)
	if not map then
		return false, message
	end
	local room: Room = {
		id = nextId,
		host = player,
		mapId = map.id,
		members = { player },
		phase = "waiting",
		phaseEnds = 0,
		participants = {},
		finishers = {},
		raceStart = 0,
	}
	nextId += 1
	rooms[room.id] = room
	roomOf[player] = room
	return true, "🏁 Sala creada en " .. map.name
end

function actions.join(player: Player, roomId: any): (boolean, string?)
	if roomOf[player] then
		return false, "Ya estás en una sala"
	end
	local room = typeof(roomId) == "number" and rooms[roomId]
	if not room then
		return false, "Esa sala ya no existe"
	end
	if #room.members >= settings.MaxPlayers then
		return false, "La sala está llena"
	end
	if room.phase == "racing" then
		return false, "La carrera ya ha empezado"
	end
	table.insert(room.members, player)
	roomOf[player] = room
	return true, "Te has unido a la sala de " .. room.host.DisplayName
end

function actions.leave(player: Player): (boolean, string?)
	if not roomOf[player] then
		return false, nil
	end
	removeMember(player)
	return true, "Has salido de la sala"
end

function actions.setMap(player: Player, mapId: any): (boolean, string?)
	local room = roomOf[player]
	if not room or room.host ~= player then
		return false, "Solo el anfitrión puede cambiar el mapa"
	end
	if room.phase ~= "waiting" then
		return false, "Espera a que termine la carrera"
	end
	local map, message = validMap(player, mapId)
	if not map then
		return false, message
	end
	room.mapId = map.id
	return true, nil
end

function actions.start(player: Player): (boolean, string?)
	local room = roomOf[player]
	if not room or room.host ~= player then
		return false, "Solo el anfitrión puede empezar la carrera"
	end
	if room.phase ~= "waiting" then
		return false, nil
	end
	if #room.members < settings.MinPlayers then
		return false, string.format("Hacen falta al menos %d jugadores", settings.MinPlayers)
	end
	-- Por si el anfitrión perdió el acceso al mapa (por ejemplo, el VIP)
	local map, message = validMap(player, room.mapId)
	if not map then
		return false, message
	end
	room.phase = "starting"
	room.phaseEnds = os.clock() + settings.StartDelay
	return true, nil
end

function actions.refresh(_player: Player): (boolean, string?)
	return true, nil
end

-- Carrera -------------------------------------------------------------------------------------

local function beginRace(room: Room)
	room.phase = "launching" -- evita empezar dos veces mientras se teletransporta
	table.clear(room.finishers)
	table.clear(room.participants)
	for _, member in room.members do
		if RaceService.enterMap(member, room.mapId, "live") then
			room.participants[member] = true
		end
	end
	task.wait(0.5)
	for member in room.participants do
		RaceService.beginCountdown(member)
	end
	room.raceStart = os.clock() + Config.CountdownSeconds
	room.phaseEnds = room.raceStart + settings.TimeLimit
	room.phase = "racing"
	broadcast()
end

local function endRace(room: Room)
	local total = count(room.participants)
	local places: { [Player]: number } = {}
	for place, finisher in room.finishers do
		places[finisher.player] = place
	end
	for player in room.participants do
		for _, handler in raceEndHandlers do
			handler(player, places[player], total)
		end
		local state = RaceService.getState(player)
		if state and state.mode == "live" then
			RaceService.setMode(player, "solo")
		end
	end
	table.clear(room.participants)
	room.phase = "results"
	room.phaseEnds = os.clock() + settings.ResultsTime
end

function LiveRace.init()
	Remotes.LiveRoomAction.OnServerInvoke = function(player, action, argument)
		local handler = typeof(action) == "string" and actions[action]
		if not handler then
			return false, "Acción no válida"
		end
		local ok, message = handler(player, argument)
		broadcast()
		return ok, message
	end

	-- La plataforma del lobby abre el menú de salas
	local lastTouch: { [Player]: number } = {}
	local pad = Maps.lobby():FindFirstChild("LiveRacePad")
	if pad and pad:IsA("BasePart") then
		pad.Touched:Connect(function(hit)
			local model = hit:FindFirstAncestorOfClass("Model")
			local player = model and Players:GetPlayerFromCharacter(model)
			if player and os.clock() - (lastTouch[player] or 0) > 3 then
				lastTouch[player] = os.clock()
				Remotes.OpenMenu:FireClient(player, "LiveRace")
			end
		end)
	end

	RaceService.onFinish(function(player, map, result)
		local room = roomOf[player]
		if not room or room.phase ~= "racing" or not room.participants[player] or map.id ~= room.mapId then
			return
		end
		for _, finisher in room.finishers do
			if finisher.player == player then
				return
			end
		end
		table.insert(room.finishers, { player = player, name = player.DisplayName, time = result.time })
		result.rewards.place = #room.finishers
	end)

	-- Si se va a otro mapa o al lobby en plena carrera, no termina (pero sigue en la sala)
	RaceService.onLeaveMap(function(player)
		local room = roomOf[player]
		if room and room.phase == "racing" then
			room.participants[player] = nil
		end
	end)

	Players.PlayerAdded:Connect(function()
		broadcast()
	end)
	Players.PlayerRemoving:Connect(function(player)
		removeMember(player)
		lastTouch[player] = nil
		task.defer(broadcast)
	end)

	task.spawn(function()
		while true do
			local now = os.clock()
			local active = false
			for _, room in rooms do
				if room.phase == "starting" then
					active = true
					if #room.members < settings.MinPlayers then
						room.phase = "waiting" -- alguien se fue durante la cuenta atrás
					elseif now >= room.phaseEnds then
						task.spawn(beginRace, room)
					end
				elseif room.phase == "racing" then
					active = true
					local finished = #room.finishers >= count(room.participants)
					if finished or now >= room.phaseEnds then
						endRace(room)
					end
				elseif room.phase == "results" then
					active = true
					if now >= room.phaseEnds then
						room.phase = "waiting"
					end
				end
			end
			if active then
				broadcast()
			end
			task.wait(1)
		end
	end)
end

return LiveRace
