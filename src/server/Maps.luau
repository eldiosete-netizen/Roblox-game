-- Registro de mapas: lee Workspace/Maps (o los genera) y el lobby.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CourseBuilder = require(script.Parent:WaitForChild("CourseBuilder"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

export type MapInfo = {
	id: string,
	folder: Folder,
	name: string,
	order: number,
	vip: boolean,
	tutorial: boolean,
	price: number, -- monedas para desbloquearlo (0 = gratis)
	medals: { [string]: number },
	startPad: BasePart,
	startGate: BasePart,
	finish: BasePart,
	checkpoints: { BasePart },
}

local Maps = {}

local list: { MapInfo } = {}
local byId: { [string]: MapInfo } = {}
local lobby: Instance

local function parse(folder: Folder): MapInfo?
	local startPad = folder:FindFirstChild("StartPad")
	local startGate = folder:FindFirstChild("Start")
	local finish = folder:FindFirstChild("Finish")
	local checkpointsFolder = folder:FindFirstChild("Checkpoints")
	if not (startPad and startGate and finish and checkpointsFolder) then
		warn("[Maps] Al mapa", folder.Name, "le falta StartPad, Start, Finish o Checkpoints")
		return nil
	end

	local checkpoints = {}
	for _, cp in checkpointsFolder:GetChildren() do
		local index = cp:GetAttribute("Index")
		if cp:IsA("BasePart") and typeof(index) == "number" then
			checkpoints[index] = cp
		end
	end

	local medals = {}
	for _, medal in Config.Medals do
		local seconds = folder:GetAttribute(medal.id)
		if typeof(seconds) == "number" then
			medals[medal.id] = seconds
		end
	end

	return {
		id = folder.Name,
		folder = folder,
		name = folder:GetAttribute("DisplayName") or folder.Name,
		order = folder:GetAttribute("Order") or 0,
		vip = folder:GetAttribute("Vip") == true,
		tutorial = folder:GetAttribute("Tutorial") == true,
		price = folder:GetAttribute("Price") or 0,
		medals = medals,
		startPad = startPad,
		startGate = startGate,
		finish = finish,
		checkpoints = checkpoints,
	}
end

function Maps.init()
	local mapsFolder = workspace:FindFirstChild("Maps")
	if mapsFolder then
		lobby = workspace:WaitForChild("Lobby")
	else
		mapsFolder, lobby = CourseBuilder.buildAll()
	end

	for _, folder in mapsFolder:GetChildren() do
		if folder:IsA("Folder") then
			local info = parse(folder)
			if info then
				table.insert(list, info)
				byId[info.id] = info
			end
		end
	end
	table.sort(list, function(a, b)
		return a.order < b.order
	end)
end

function Maps.get(id: string): MapInfo?
	return byId[id]
end

function Maps.list(): { MapInfo }
	return list
end

function Maps.lobby(): Instance
	return lobby
end

-- Posición encima de una plataforma, mirando hacia el circuito
function Maps.onTop(part: BasePart, forward: number?): CFrame
	return part.CFrame * CFrame.new(0, part.Size.Y / 2 + 3, -(forward or 0))
end

function Maps.lobbySpawn(): CFrame
	local spawn = lobby:FindFirstChild("Spawn") :: BasePart
	return Maps.onTop(spawn)
end

-- Justo delante de la línea de salida
function Maps.startLine(map: MapInfo): CFrame
	return map.startGate.CFrame * CFrame.new(0, -map.startGate.Size.Y / 2 + 3, -4)
end

function Maps.checkpointCFrame(cp: BasePart): CFrame
	return cp.CFrame * CFrame.new(0, -cp.Size.Y / 2 + 3, 0)
end

return Maps
