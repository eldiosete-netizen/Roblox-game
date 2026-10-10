-- Carreras en vivo: los jugadores en la cola corren a la vez en un mapa al azar.
-- Fases: waiting (esperando jugadores) -> intermission (cuenta atrás) ->
-- racing -> results -> waiting

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Maps = require(script.Parent:WaitForChild("Maps"))
local RaceService = require(script.Parent:WaitForChild("RaceService"))

local LiveRace = {}

type Finisher = { player: Player, name: string, time: number }

local queue: { [Player]: boolean } = {}
local participants: { [Player]: boolean } = {}
local finishers: { Finisher } = {}
local phase = "waiting"
local currentMap: Maps.MapInfo? = nil
local raceStart = 0

local raceEndHandlers: { (Player, number?, number) -> () } = {}

-- Se llama al terminar cada carrera: (jugador, puesto o nil si no terminó, participantes)
function LiveRace.onRaceEnd(handler: (Player, number?, number) -> ())
	table.insert(raceEndHandlers, handler)
end

local function count(set: { [Player]: boolean }): number
	local n = 0
	for _ in set do
		n += 1
	end
	return n
end

local function publicResults(): { { name: string, time: number } }
	local list = {}
	for _, finisher in finishers do
		table.insert(list, { name = finisher.name, time = finisher.time })
	end
	return list
end

local function broadcast(status: { [string]: any })
	local sent: { [Player]: boolean } = {}
	for _, set in { queue, participants } do
		for player in set do
			if not sent[player] then
				sent[player] = true
				Remotes.LiveRaceUpdate:FireClient(player, status)
			end
		end
	end
end

function LiveRace.setQueued(player: Player, join: boolean): (boolean, string?)
	if participants[player] then
		return false, "Ya estás en una carrera en vivo"
	end
	if join then
		queue[player] = true
		Remotes.LiveRaceUpdate:FireClient(player, { phase = phase, queued = count(queue), needed = Config.LiveRace.MinPlayers })
		return true, "Te has unido a la carrera en vivo"
	end
	queue[player] = nil
	Remotes.LiveRaceUpdate:FireClient(player, { phase = "none" })
	return true, nil
end

local function startRace()
	local candidates = {}
	for _, map in Maps.list() do
		if not map.vip and not map.tutorial then
			table.insert(candidates, map)
		end
	end
	if #candidates == 0 then
		phase = "waiting"
		return
	end
	local map = candidates[math.random(#candidates)]
	currentMap = map
	table.clear(finishers)
	table.clear(participants)

	for player in queue do
		if RaceService.enterMap(player, map.id, "live") then
			participants[player] = true
		end
	end
	table.clear(queue)

	task.wait(0.5)
	for player in participants do
		RaceService.beginCountdown(player)
	end
	raceStart = os.clock() + Config.CountdownSeconds
	phase = "racing"
end

local function endRace()
	local total = count(participants)
	local places: { [Player]: number } = {}
	for place, finisher in finishers do
		places[finisher.player] = place
	end
	broadcast({ phase = "results", map = currentMap and currentMap.name, results = publicResults() })

	for player in participants do
		for _, handler in raceEndHandlers do
			handler(player, places[player], total)
		end
		RaceService.setMode(player, "solo")
	end
	table.clear(participants)
	table.clear(finishers)
	currentMap = nil
	phase = "waiting"
end

function LiveRace.init()
	Remotes.SetLiveRaceQueue.OnServerInvoke = function(player, join)
		return LiveRace.setQueued(player, join == true)
	end

	-- Plataforma del lobby
	local pad = Maps.lobby():FindFirstChild("LiveRacePad")
	if pad and pad:IsA("BasePart") then
		pad.Touched:Connect(function(hit)
			local model = hit:FindFirstAncestorOfClass("Model")
			local player = model and Players:GetPlayerFromCharacter(model)
			if player and not queue[player] and not participants[player] then
				local _, message = LiveRace.setQueued(player, true)
				if message then
					Remotes.Notify:FireClient(player, message)
				end
			end
		end)
	end

	RaceService.onFinish(function(player, map, result)
		if phase ~= "racing" or not participants[player] or not currentMap or map.id ~= currentMap.id then
			return
		end
		for _, finisher in finishers do
			if finisher.player == player then
				return
			end
		end
		table.insert(finishers, { player = player, name = player.DisplayName, time = result.time })
		result.rewards.place = #finishers
	end)

	-- Si se va a otro mapa o al lobby, abandona la carrera
	RaceService.onLeaveMap(function(player)
		participants[player] = nil
	end)
	Players.PlayerRemoving:Connect(function(player)
		queue[player] = nil
		participants[player] = nil
	end)

	task.spawn(function()
		local timer = 0
		while true do
			if phase == "waiting" then
				if count(queue) >= Config.LiveRace.MinPlayers then
					phase = "intermission"
					timer = Config.LiveRace.Intermission
				else
					broadcast({ phase = "waiting", queued = count(queue), needed = Config.LiveRace.MinPlayers })
				end
			elseif phase == "intermission" then
				if count(queue) < Config.LiveRace.MinPlayers then
					phase = "waiting"
				elseif timer <= 0 then
					startRace()
				else
					broadcast({ phase = "intermission", queued = count(queue), timeLeft = timer })
					timer -= 1
				end
			elseif phase == "racing" then
				local elapsed = os.clock() - raceStart
				local everyoneDone = count(participants) == 0 or #finishers >= count(participants)
				if everyoneDone or elapsed > Config.LiveRace.TimeLimit then
					endRace()
				else
					broadcast({
						phase = "racing",
						map = currentMap and currentMap.name,
						timeLeft = math.max(0, math.ceil(Config.LiveRace.TimeLimit - elapsed)),
						results = publicResults(),
					})
				end
			end
			task.wait(1)
		end
	end)
end

return LiveRace
