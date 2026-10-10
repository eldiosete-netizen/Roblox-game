-- Datos del jugador en el cliente (los envía el servidor con DataSync).
-- También lo usan los scripts del personaje para leer los ajustes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local ClientState = {
	data = nil :: { [string]: any }?,
}

local changed = Instance.new("BindableEvent")
ClientState.Changed = changed.Event

Remotes.DataSync.OnClientEvent:Connect(function(snapshot)
	ClientState.data = snapshot
	changed:Fire()
end)
Remotes.DataSync:FireServer() -- pide los datos por si ya se enviaron antes de cargar

function ClientState.mapData(mapId: string): { [string]: any }?
	local data = ClientState.data
	return data and data.maps[mapId]
end

-- Ajustes del jugador (con valor por defecto si aún no han llegado los datos)
function ClientState.setting(key: string): boolean
	local data = ClientState.data
	local value = data and data.settings and data.settings[key]
	if value == nil then
		return Config.DefaultSettings[key] ~= false
	end
	return value == true
end

-- Carpeta de un mapa en Workspace (con sus atributos: nombre, medallas...)
function ClientState.mapFolder(mapId: string): Folder?
	local maps = workspace:FindFirstChild("Maps")
	return maps and maps:FindFirstChild(mapId) :: Folder?
end

function ClientState.mapsSorted(): { Folder }
	local maps = workspace:WaitForChild("Maps")
	local list = {}
	for _, folder in maps:GetChildren() do
		if folder:IsA("Folder") then
			table.insert(list, folder)
		end
	end
	table.sort(list, function(a, b)
		return (a:GetAttribute("Order") or 0) < (b:GetAttribute("Order") or 0)
	end)
	return list
end

return ClientState
