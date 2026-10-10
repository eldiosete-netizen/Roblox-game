-- Lógica de las carreras: entrar en mapas, cuenta atrás, checkpoints, meta,
-- caídas, récords y medallas. El servidor mide el tiempo oficial.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Maps = require(script.Parent:WaitForChild("Maps"))
local PlayerData = require(script.Parent:WaitForChild("PlayerData"))
local Leaderboard = require(script.Parent:WaitForChild("Leaderboard"))

local RaceService = {}

export type State = {
	mapId: string?,
	mode: string, -- "solo" o "live"
	racing: boolean,
	countdownToken: {}?,
	startTime: number,
	nextCheckpoint: number,
	splits: { number },
	respawnCFrame: CFrame,
	lastStart: number,
	lastRestart: number,
	lastEnter: number,
}

export type Result = {
	mapId: string,
	time: number,
	best: number,
	previousBest: number?,
	isRecord: boolean,
	medal: number,
	previousMedal: number,
	newMedal: boolean,
	splits: { number },
	mode: string,
	rewards: { [string]: any },
}

local states: { [Player]: State } = {}

-- Ganchos para otros módulos
local enterChecks: { (Player, Maps.MapInfo) -> (boolean, string?) } = {}
local finishHandlers: { (Player, Maps.MapInfo, Result) -> () } = {}
local leaveHandlers: { (Player) -> () } = {}

function RaceService.addEnterCheck(check: (Player, Maps.MapInfo) -> (boolean, string?))
	table.insert(enterChecks, check)
end

-- ¿Puede este jugador entrar en el mapa por su cuenta? (VIP, nivel desbloqueado...)
function RaceService.canEnter(player: Player, map: Maps.MapInfo): (boolean, string?)
	for _, check in enterChecks do
		local ok, message = check(player, map)
		if not ok then
			return false, message
		end
	end
	return true, nil
end

-- Se llama al terminar, antes de avisar al cliente (puede rellenar result.rewards)
function RaceService.onFinish(handler: (Player, Maps.MapInfo, Result) -> ())
	table.insert(finishHandlers, handler)
end

-- Se llama cuando un jugador sale de su mapa (lobby, otro mapa, desconexión)
function RaceService.onLeaveMap(handler: (Player) -> ())
	table.insert(leaveHandlers, handler)
end

function RaceService.getState(player: Player): State?
	return states[player]
end

-- Cambia entre "solo" y "live" sin mover al jugador (al acabar una carrera en vivo)
function RaceService.setMode(player: Player, mode: string)
	local state = states[player]
	if state then
		state.mode = mode
	end
end

-- Utilidades -----------------------------------------------------------------------

local function playerFromHit(hit: BasePart): Player?
	local model = hit:FindFirstAncestorOfClass("Model")
	if not model then
		return nil
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return Players:GetPlayerFromCharacter(model)
end

function RaceService.teleport(player: Player, cframe: CFrame)
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then
		return
	end
	character:PivotTo(cframe)
	-- Avisa al cliente para que resetee la velocidad
	player:SetAttribute("TeleportTick", ((player:GetAttribute("TeleportTick") :: number?) or 0) + 1)
end

local function setFrozen(player: Player, frozen: boolean)
	player:SetAttribute("Frozen", frozen)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		root.Anchored = frozen
	end
end

local function stopRace(player: Player, state: State)
	if state.countdownToken then
		state.countdownToken = nil
		setFrozen(player, false)
	end
	state.racing = false
	state.nextCheckpoint = 1
	table.clear(state.splits)
end

local function currentMap(state: State): Maps.MapInfo?
	return if state.mapId then Maps.get(state.mapId) else nil
end

-- Flujo de la carrera ----------------------------------------------------------------

-- Coloca al jugador en la línea, lo congela y cuenta 3, 2, 1...
function RaceService.beginCountdown(player: Player)
	local state = states[player]
	local map = state and currentMap(state)
	if not state or not map or state.countdownToken then
		return
	end
	local now = os.clock()
	if now - state.lastStart < 0.3 then
		return
	end
	state.lastStart = now

	stopRace(player, state)
	local token = {}
	state.countdownToken = token
	state.respawnCFrame = Maps.startLine(map)

	RaceService.teleport(player, Maps.startLine(map))
	setFrozen(player, true)
	Remotes.RaceCountdown:FireClient(player, map.id, Config.CountdownSeconds)

	task.delay(Config.CountdownSeconds, function()
		if states[player] ~= state or state.countdownToken ~= token then
			return -- cancelada
		end
		state.countdownToken = nil
		setFrozen(player, false)
		state.racing = true
		state.startTime = os.clock()
		state.lastStart = state.startTime
		Remotes.RaceStarted:FireClient(player, map.id, #map.checkpoints, state.mode)
	end)
end

function RaceService.enterMap(player: Player, mapId: string, mode: string?): (boolean, string?)
	local state = states[player]
	local map = Maps.get(mapId)
	if not state or not map then
		return false, "Mapa no encontrado"
	end
	-- En las carreras en vivo se puede correr cualquier mapa (aunque no esté desbloqueado)
	if mode ~= "live" then
		for _, check in enterChecks do
			local ok, message = check(player, map)
			if not ok then
				return false, message
			end
		end
	end
	local now = os.clock()
	if now - state.lastEnter < 1 then
		return false, nil
	end
	state.lastEnter = now

	if state.mapId then
		for _, handler in leaveHandlers do
			handler(player)
		end
	end

	stopRace(player, state)
	state.mapId = map.id
	state.mode = mode or "solo"
	state.lastStart = 0
	state.respawnCFrame = Maps.startLine(map)
	player:SetAttribute("MapId", map.id)

	if state.mode == "solo" then
		RaceService.beginCountdown(player)
	else
		RaceService.teleport(player, Maps.startLine(map))
	end
	return true, nil
end

function RaceService.returnToLobby(player: Player)
	local state = states[player]
	if not state then
		return
	end
	if state.mapId then
		for _, handler in leaveHandlers do
			handler(player)
		end
	end
	stopRace(player, state)
	state.mapId = nil
	state.mode = "solo"
	state.respawnCFrame = Maps.lobbySpawn()
	player:SetAttribute("MapId", nil)
	Remotes.RaceCancelled:FireClient(player, nil)
	RaceService.teleport(player, Maps.lobbySpawn())
end

local function reachCheckpoint(player: Player, map: Maps.MapInfo, index: number)
	local state = states[player]
	if not state or state.mapId ~= map.id or not state.racing or index ~= state.nextCheckpoint then
		return
	end
	local split = os.clock() - state.startTime
	state.nextCheckpoint += 1
	state.splits[index] = split
	state.respawnCFrame = Maps.checkpointCFrame(map.checkpoints[index])

	local data = PlayerData.get(player)
	local mapData = data and data.maps[map.id]
	local bestSplit = mapData and mapData.splits and mapData.splits[index]
	local delta = if typeof(bestSplit) == "number" then split - bestSplit else nil
	Remotes.CheckpointReached:FireClient(player, index, #map.checkpoints, split, delta)
end

local function finishRace(player: Player, map: Maps.MapInfo)
	local state = states[player]
	if not state or state.mapId ~= map.id or not state.racing then
		return
	end
	if state.nextCheckpoint <= #map.checkpoints then
		return -- se ha saltado algún checkpoint
	end

	local elapsed = os.clock() - state.startTime
	local splits = table.clone(state.splits)
	stopRace(player, state)
	state.respawnCFrame = Maps.startLine(map)

	if elapsed < Config.MinValidTime then
		Remotes.RaceCancelled:FireClient(player, "Tiempo no válido")
		return
	end

	local data = PlayerData.get(player)
	local mapData = data and data.maps[map.id] or {}
	local previousBest = mapData.best
	local isRecord = previousBest == nil or elapsed < previousBest
	local oldMedal = mapData.medal or 0
	local medal = if map.tutorial then 0 else Config.MedalRank(elapsed, map.medals)

	if data then
		mapData.runs = (mapData.runs or 0) + 1
		if isRecord then
			mapData.best = elapsed
			mapData.splits = splits
		end
		mapData.medal = math.max(oldMedal, medal)
		data.maps[map.id] = mapData
	end

	local result: Result = {
		mapId = map.id,
		time = elapsed,
		best = if isRecord then elapsed else previousBest,
		previousBest = previousBest,
		isRecord = isRecord,
		medal = medal,
		previousMedal = oldMedal,
		newMedal = medal > oldMedal,
		splits = splits,
		mode = state.mode,
		rewards = {},
	}

	if isRecord and not map.tutorial then
		Leaderboard.submit(player, map.id, elapsed)
	end
	for _, handler in finishHandlers do
		handler(player, map, result)
	end
	if data then
		PlayerData.sync(player)
	end
	Remotes.RaceFinished:FireClient(player, result)

	-- En solitario, vuelve a la salida para otro intento
	if state.mode == "solo" then
		task.delay(3, function()
			if states[player] == state and state.mapId == map.id and not state.racing and not state.countdownToken then
				RaceService.teleport(player, Maps.onTop(map.startPad))
			end
		end)
	end
end

local function restart(player: Player)
	local state = states[player]
	if not state then
		return
	end
	local now = os.clock()
	if now - state.lastRestart < 0.5 then
		return
	end
	state.lastRestart = now

	if not state.mapId then
		RaceService.teleport(player, Maps.lobbySpawn())
	elseif state.mode == "live" then
		RaceService.teleport(player, state.respawnCFrame) -- en carrera en vivo no se reinicia el tiempo
	else
		RaceService.beginCountdown(player)
	end
end

-- Inicio ---------------------------------------------------------------------------------

local function onPlayerAdded(player: Player)
	local state: State = {
		mapId = nil,
		mode = "solo",
		racing = false,
		countdownToken = nil,
		startTime = 0,
		nextCheckpoint = 1,
		splits = {},
		respawnCFrame = Maps.lobbySpawn(),
		lastStart = 0,
		lastRestart = 0,
		lastEnter = 0,
	}
	states[player] = state

	-- Si muere, reaparece en su último checkpoint (o en la salida si estaba en la cuenta atrás)
	player.CharacterAdded:Connect(function(character)
		if not state.mapId then
			return
		end
		character:WaitForChild("HumanoidRootPart")
		task.wait()
		if state.countdownToken then
			stopRace(player, state)
			Remotes.RaceCancelled:FireClient(player, nil)
			RaceService.teleport(player, Maps.onTop((currentMap(state) :: Maps.MapInfo).startPad))
		else
			RaceService.teleport(player, state.respawnCFrame)
		end
	end)
end

function RaceService.init()
	for _, map in Maps.list() do
		map.startGate.Touched:Connect(function(hit)
			local player = playerFromHit(hit)
			local state = player and states[player]
			if
				player
				and state
				and state.mapId == map.id
				and state.mode == "solo"
				and not state.racing
				and not state.countdownToken
			then
				RaceService.beginCountdown(player)
			end
		end)

		map.finish.Touched:Connect(function(hit)
			local player = playerFromHit(hit)
			if player then
				finishRace(player, map)
			end
		end)

		for index, cp in map.checkpoints do
			cp.Touched:Connect(function(hit)
				local player = playerFromHit(hit)
				if player then
					reachCheckpoint(player, map, index)
				end
			end)
		end
	end

	-- Portales del lobby
	local portals = Maps.lobby():FindFirstChild("Portals")
	if portals then
		for _, portal in portals:GetChildren() do
			local mapId = portal:GetAttribute("MapId")
			if portal:IsA("BasePart") and typeof(mapId) == "string" then
				portal.Touched:Connect(function(hit)
					local player = playerFromHit(hit)
					if player and states[player] and states[player].mapId == nil then
						local ok, message = RaceService.enterMap(player, mapId, "solo")
						if not ok and message then
							Remotes.Notify:FireClient(player, message)
							Remotes.OpenMenu:FireClient(player, "Maps")
						end
					end
				end)
			end
		end
	end

	Remotes.RequestRestart.OnServerEvent:Connect(restart)
	Remotes.ReturnToLobby.OnServerEvent:Connect(RaceService.returnToLobby)
	Remotes.RequestMap.OnServerInvoke = function(player, mapId)
		if typeof(mapId) ~= "string" then
			return false, "Mapa no válido"
		end
		return RaceService.enterMap(player, mapId, "solo")
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		if states[player] and states[player].mapId then
			for _, handler in leaveHandlers do
				handler(player)
			end
		end
		states[player] = nil
	end)

	-- Caídas al vacío
	task.spawn(function()
		while true do
			for player, state in states do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root and not root.Anchored and root.Position.Y < Config.FallY then
					RaceService.teleport(player, state.respawnCFrame)
				end
			end
			task.wait(0.1)
		end
	end)
end

return RaceService
