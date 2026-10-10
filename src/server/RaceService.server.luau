-- Lógica de la carrera: salida, checkpoints, meta, caídas y récords.
-- El servidor es quien mide el tiempo oficial (el cliente solo lo muestra).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local CourseBuilder = require(script.Parent:WaitForChild("CourseBuilder"))
local Leaderboard = require(script.Parent:WaitForChild("Leaderboard"))

-- Remotes (se crean primero para que los clientes los encuentren)
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"

local function newRemote(name: string): RemoteEvent
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotes
	return remote
end

local RaceStarted = newRemote("RaceStarted") -- (totalCheckpoints)
local CheckpointReached = newRemote("CheckpointReached") -- (index, total, splitTime)
local RaceFinished = newRemote("RaceFinished") -- (time, bestTime, isNewRecord)
local RaceCancelled = newRemote("RaceCancelled") -- (reason)
local RequestRestart = newRemote("RequestRestart")
remotes.Parent = ReplicatedStorage

-- Circuito
local course = workspace:FindFirstChild("Course") or CourseBuilder.build()
local spawnPart = course:WaitForChild("Spawn") :: BasePart
local startGate = course:WaitForChild("Start") :: BasePart
local finishGate = course:WaitForChild("Finish") :: BasePart

local checkpoints: { BasePart } = {}
for _, cp in course:WaitForChild("Checkpoints"):GetChildren() do
	local index = cp:GetAttribute("Index")
	if cp:IsA("BasePart") and typeof(index) == "number" then
		checkpoints[index] = cp
	end
end
local totalCheckpoints = #checkpoints

local board = course:FindFirstChild("Leaderboard")
if board and board:IsA("BasePart") then
	Leaderboard.startBoard(board)
end

type State = {
	racing: boolean,
	startTime: number,
	nextCheckpoint: number,
	respawnCFrame: CFrame,
	best: number?,
	lastStart: number,
	lastRestart: number,
}

local states: { [Player]: State } = {}

local function spawnCFrame(): CFrame
	return spawnPart.CFrame * CFrame.new(0, spawnPart.Size.Y / 2 + 3, 0)
end

local function checkpointCFrame(cp: BasePart): CFrame
	return cp.CFrame * CFrame.new(0, -cp.Size.Y / 2 + 3, 0)
end

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

local function teleport(player: Player, cframe: CFrame)
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then
		return
	end
	character:PivotTo(cframe)
	-- Avisa al script de movimiento del cliente para que resetee la velocidad
	player:SetAttribute("TeleportTick", (player:GetAttribute("TeleportTick") or 0) + 1)
end

local function setBest(player: Player, state: State, seconds: number)
	state.best = seconds
	player:SetAttribute("BestTime", seconds)
	local leaderstats = player:FindFirstChild("leaderstats")
	local value = leaderstats and leaderstats:FindFirstChild("Mejor")
	if value then
		(value :: StringValue).Value = Config.FormatTime(seconds)
	end
end

local function resetState(state: State)
	state.racing = false
	state.nextCheckpoint = 1
	state.respawnCFrame = spawnCFrame()
end

local function startRace(player: Player)
	local state = states[player]
	if not state then
		return
	end
	local now = os.clock()
	if now - state.lastStart < 0.3 then
		return
	end
	state.lastStart = now
	state.racing = true
	state.startTime = now
	state.nextCheckpoint = 1
	state.respawnCFrame = spawnCFrame()
	RaceStarted:FireClient(player, totalCheckpoints)
end

local function reachCheckpoint(player: Player, index: number)
	local state = states[player]
	if not state or not state.racing or index ~= state.nextCheckpoint then
		return
	end
	state.nextCheckpoint += 1
	state.respawnCFrame = checkpointCFrame(checkpoints[index])
	CheckpointReached:FireClient(player, index, totalCheckpoints, os.clock() - state.startTime)
end

local function finishRace(player: Player)
	local state = states[player]
	if not state or not state.racing then
		return
	end
	if state.nextCheckpoint <= totalCheckpoints then
		return -- se ha saltado algún checkpoint
	end

	local elapsed = os.clock() - state.startTime
	resetState(state)

	if elapsed < Config.MinValidTime then
		RaceCancelled:FireClient(player, "Tiempo no válido")
		return
	end

	local isRecord = state.best == nil or elapsed < state.best
	if isRecord then
		setBest(player, state, elapsed)
		Leaderboard.submit(player, elapsed)
	end
	RaceFinished:FireClient(player, elapsed, state.best, isRecord)

	-- Vuelve a la salida tras unos segundos para otro intento
	task.delay(3, function()
		if states[player] == state and not state.racing then
			teleport(player, spawnCFrame())
		end
	end)
end

-- Detectores
startGate.Touched:Connect(function(hit)
	local player = playerFromHit(hit)
	if player then
		startRace(player)
	end
end)

finishGate.Touched:Connect(function(hit)
	local player = playerFromHit(hit)
	if player then
		finishRace(player)
	end
end)

for index, cp in checkpoints do
	cp.Touched:Connect(function(hit)
		local player = playerFromHit(hit)
		if player then
			reachCheckpoint(player, index)
		end
	end)
end

local killParts = course:FindFirstChild("KillParts")
if killParts then
	for _, part in killParts:GetDescendants() do
		if part:IsA("BasePart") then
			part.Touched:Connect(function(hit)
				local player = playerFromHit(hit)
				if player and states[player] then
					teleport(player, states[player].respawnCFrame)
				end
			end)
		end
	end
end

-- Reiniciar (tecla R)
RequestRestart.OnServerEvent:Connect(function(player)
	local state = states[player]
	if not state then
		return
	end
	local now = os.clock()
	if now - state.lastRestart < 0.5 then
		return
	end
	state.lastRestart = now
	resetState(state)
	RaceCancelled:FireClient(player, nil)
	teleport(player, spawnCFrame())
end)

-- Jugadores
local function onPlayerAdded(player: Player)
	local state: State = {
		racing = false,
		startTime = 0,
		nextCheckpoint = 1,
		respawnCFrame = spawnCFrame(),
		best = nil,
		lastStart = 0,
		lastRestart = 0,
	}
	states[player] = state

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local bestValue = Instance.new("StringValue")
	bestValue.Name = "Mejor"
	bestValue.Value = "--"
	bestValue.Parent = leaderstats
	leaderstats.Parent = player

	-- Si muere en mitad de la carrera, reaparece en su último checkpoint
	player.CharacterAdded:Connect(function(character)
		if state.racing then
			character:WaitForChild("HumanoidRootPart")
			task.wait()
			teleport(player, state.respawnCFrame)
		end
	end)

	task.spawn(function()
		local saved = Leaderboard.loadBest(player.UserId)
		if saved and states[player] == state and (state.best == nil or saved < state.best) then
			setBest(player, state, saved)
		end
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

Players.PlayerRemoving:Connect(function(player)
	states[player] = nil
end)

-- Caídas al vacío
task.spawn(function()
	while true do
		for player, state in states do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and root.Position.Y < Config.FallY then
				teleport(player, state.respawnCFrame)
			end
		end
		task.wait(0.1)
	end
end)
