-- Todos los RemoteEvents/RemoteFunctions del juego en un solo sitio.
-- El servidor los crea; el cliente espera a que existan.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTS = {
	-- Carrera
	"RaceCountdown", -- (mapId, seconds)
	"RaceStarted", -- (mapId, totalCheckpoints, mode)
	"CheckpointReached", -- (index, total, split, delta?)
	"RaceFinished", -- (result)
	"RaceCancelled", -- (reason?)
	"RequestRestart",
	"ReturnToLobby",
	-- Datos
	"DataSync", -- (snapshot)
	"Notify", -- (text, color?)
	"UpdateSetting", -- (key, value)
	"PromptPass", -- (passKey) pide al servidor abrir la compra de un Game Pass
	-- Competición
	"GhostData", -- (mapId, encoded?)
	"SubmitGhost", -- (mapId, encoded)
	"LiveRaceUpdate", -- (status)
	"OpenMenu", -- (panelName) el servidor pide abrir un menú (p. ej. al tocar un portal bloqueado)
}

local FUNCTIONS = {
	"RequestMap", -- (mapId) -> ok, message
	"SetLiveRaceQueue", -- (join) -> ok, message
	"Purchase", -- (itemId) -> ok, message
	"Equip", -- (itemId) -> ok, message
	"GetLeaderboard", -- (mapId) -> { all = entries, week = entries }
	"UnlockMap", -- (mapId) -> ok, message
}

local Remotes = {}

if RunService:IsServer() then
	local folder = Instance.new("Folder")
	folder.Name = "Remotes"
	for _, name in EVENTS do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
		Remotes[name] = remote
	end
	for _, name in FUNCTIONS do
		local remote = Instance.new("RemoteFunction")
		remote.Name = name
		remote.Parent = folder
		Remotes[name] = remote
	end
	folder.Parent = ReplicatedStorage
else
	local folder = ReplicatedStorage:WaitForChild("Remotes")
	for _, name in EVENTS do
		Remotes[name] = folder:WaitForChild(name)
	end
	for _, name in FUNCTIONS do
		Remotes[name] = folder:WaitForChild(name)
	end
end

return Remotes :: { [string]: any }
