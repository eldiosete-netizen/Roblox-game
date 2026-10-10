-- Modo fantasma: graba tu carrera y, en el siguiente intento, muestra una
-- silueta de tu mejor intento corriendo a tu lado.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local ClientState = require(script.Parent:WaitForChild("ClientState"))

local player = Players.LocalPlayer

local Ghost = {}

type Sample = { position: Vector3, yaw: number }

local ghosts: { [string]: { Sample }? } = {} -- mejor intento por mapa

local recording: { Sample }? = nil
local recordStart = 0

local playback: { samples: { Sample }, model: Model, start: number }? = nil

-- Formato: "x,y,z,yaw;x,y,z,yaw;..."
local function encode(samples: { Sample }): string
	local parts = table.create(#samples)
	for i, sample in samples do
		local p = sample.position
		parts[i] = string.format("%.1f,%.1f,%.1f,%.2f", p.X, p.Y, p.Z, sample.yaw)
	end
	return table.concat(parts, ";")
end

local function decode(encoded: string): { Sample }
	local samples = {}
	for _, chunk in string.split(encoded, ";") do
		local values = string.split(chunk, ",")
		local x, y, z, yaw = tonumber(values[1]), tonumber(values[2]), tonumber(values[3]), tonumber(values[4])
		if x and y and z and yaw then
			table.insert(samples, { position = Vector3.new(x, y, z), yaw = yaw })
		end
	end
	return samples
end

local function getRoot(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Copia translúcida de tu personaje, sin scripts ni colisiones
local function makeModel(): Model?
	local character = player.Character
	if not character then
		return nil
	end
	local archivable = character.Archivable
	character.Archivable = true
	local clone = character:Clone()
	character.Archivable = archivable
	if not clone then
		return nil
	end

	for _, descendant in clone:GetDescendants() do
		if
			descendant:IsA("LuaSourceContainer")
			or descendant:IsA("Sound")
			or descendant:IsA("ParticleEmitter")
			or descendant:IsA("Trail")
			or descendant:IsA("Constraint")
			or descendant:IsA("BillboardGui")
		then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.CastShadow = false
			descendant.Color = Config.GhostColor
			descendant.Material = Enum.Material.ForceField
			descendant.Transparency = if descendant.Name == "HumanoidRootPart" then 1 else 0.2
		elseif descendant:IsA("Decal") then
			descendant.Transparency = 1
		end
	end
	local humanoid = clone:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	clone.Name = "Ghost"
	clone.Parent = workspace
	return clone
end

local function stopPlayback()
	if playback then
		playback.model:Destroy()
		playback = nil
	end
end

local function startPlayback(mapId: string)
	stopPlayback()
	local samples = ghosts[mapId]
	if not samples or #samples < 2 or not ClientState.setting("ghost") then
		return
	end
	local model = makeModel()
	if model then
		playback = { samples = samples, model = model, start = os.clock() }
	end
end

local function update()
	local now = os.clock()

	if recording then
		local index = math.floor((now - recordStart) / Config.GhostSampleInterval) + 1
		local root = getRoot()
		-- Si bajan los FPS, repetimos la muestra para no desincronizar el tiempo
		while root and #recording < index and #recording < Config.GhostMaxSamples do
			local look = root.CFrame.LookVector
			table.insert(recording, { position = root.Position, yaw = math.atan2(-look.X, -look.Z) })
		end
	end

	if playback then
		local samples = playback.samples
		local t = (now - playback.start) / Config.GhostSampleInterval + 1
		local i = math.clamp(math.floor(t), 1, #samples - 1)
		local alpha = math.clamp(t - i, 0, 1)
		local a, b = samples[i], samples[i + 1]
		local position = a.position:Lerp(b.position, alpha)
		local turn = (b.yaw - a.yaw + math.pi) % (2 * math.pi) - math.pi -- giro más corto
		local yaw = a.yaw + turn * alpha
		playback.model:PivotTo(CFrame.new(position) * CFrame.Angles(0, yaw, 0))
		if t > #samples + 10 then
			stopPlayback() -- 1 segundo después de llegar a la meta
		end
	end
end

function Ghost.start()
	Remotes.GhostData.OnClientEvent:Connect(function(mapId: string, encoded: string?)
		ghosts[mapId] = if encoded then decode(encoded) else nil
	end)

	Remotes.RaceCountdown.OnClientEvent:Connect(function()
		recording = nil
		stopPlayback()
	end)

	Remotes.RaceStarted.OnClientEvent:Connect(function(mapId: string)
		recording = {}
		recordStart = os.clock()
		startPlayback(mapId)
	end)

	Remotes.RaceFinished.OnClientEvent:Connect(function(result)
		local samples = recording
		recording = nil
		if result.isRecord and samples and #samples > 1 then
			local root = getRoot()
			if root then
				local look = root.CFrame.LookVector
				table.insert(samples, { position = root.Position, yaw = math.atan2(-look.X, -look.Z) })
			end
			ghosts[result.mapId] = samples
			Remotes.SubmitGhost:FireServer(result.mapId, encode(samples))
		end
	end)

	Remotes.RaceCancelled.OnClientEvent:Connect(function()
		recording = nil
		stopPlayback()
	end)

	ClientState.Changed:Connect(function()
		if not ClientState.setting("ghost") then
			stopPlayback()
		end
	end)

	RunService.Heartbeat:Connect(update)
end

return Ghost
