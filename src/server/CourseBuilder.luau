-- Genera un circuito de prueba si en Workspace no hay una carpeta "Course".
-- Puedes construir tu propio mapa en Studio con la misma estructura:
--   Course/Spawn          (SpawnLocation)
--   Course/Start          (Part que inicia el tiempo al tocarla)
--   Course/Finish         (Part que para el tiempo)
--   Course/Checkpoints/*  (Parts con el atributo "Index" = 1, 2, 3...)
--   Course/KillParts/*    (opcional: Parts que te devuelven al checkpoint)
--   Course/Leaderboard    (opcional: Part donde se muestra el ranking)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local CourseBuilder = {}

local COLORS = {
	Platform = Color3.fromRGB(230, 232, 240),
	Runway = Color3.fromRGB(60, 64, 80),
	Wall = Color3.fromRGB(255, 120, 40),
	Start = Color3.fromRGB(0, 170, 255),
	Checkpoint = Color3.fromRGB(0, 255, 140),
	Finish = Color3.fromRGB(255, 210, 0),
	Board = Color3.fromRGB(25, 25, 35),
}

local function newPart(className: string, props: { [string]: any }, parent: Instance): BasePart
	local part = Instance.new(className) :: BasePart
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(part :: any)[key] = value
	end
	part.Parent = parent
	return part
end

function CourseBuilder.build(): Folder
	-- Desactiva otros spawns (p. ej. el de la plantilla Baseplate) para aparecer siempre en la salida
	for _, descendant in workspace:GetDescendants() do
		if descendant:IsA("SpawnLocation") then
			descendant.Enabled = false
		end
	end

	local course = Instance.new("Folder")
	course.Name = "Course"

	local checkpointsFolder = Instance.new("Folder")
	checkpointsFolder.Name = "Checkpoints"
	checkpointsFolder.Parent = course

	local baseY = Config.CourseHeight
	local cursor = 0 -- distancia recorrida hacia -Z (hacia donde mira el jugador al aparecer)
	local checkpointCount = 0

	-- Plataforma que empieza en el cursor y avanza "length" studs
	local function block(length: number, width: number, height: number, x: number?, color: Color3?): BasePart
		local part = newPart("Part", {
			Size = Vector3.new(width, 2, length),
			Position = Vector3.new(x or 0, baseY + height - 1, -(cursor + length / 2)),
			Color = color or COLORS.Platform,
		}, course)
		cursor += length
		return part
	end

	local function gap(distance: number)
		cursor += distance
	end

	-- Puerta invisible (detector) en la posición actual del cursor
	local function gate(name: string, width: number, color: Color3, floorY: number): BasePart
		return newPart("Part", {
			Name = name,
			Size = Vector3.new(width, 10, 1),
			Position = Vector3.new(0, floorY + 5, -cursor),
			Color = color,
			Material = Enum.Material.Neon,
			Transparency = 0.6,
			CanCollide = false,
			CanQuery = false,
		}, course)
	end

	local function checkpoint(platform: BasePart)
		checkpointCount += 1
		local cp = newPart("Part", {
			Name = tostring(checkpointCount),
			Size = Vector3.new(platform.Size.X, 8, 2),
			CFrame = CFrame.new(platform.Position + Vector3.new(0, platform.Size.Y / 2 + 4, 0)),
			Color = COLORS.Checkpoint,
			Material = Enum.Material.Neon,
			Transparency = 0.6,
			CanCollide = false,
			CanQuery = false,
		}, checkpointsFolder)
		cp:SetAttribute("Index", checkpointCount)
	end

	-- Hueco con una pared al lado para correr por ella. side: -1 izquierda, 1 derecha
	local function wallRunSection(side: number, length: number): BasePart
		newPart("Part", {
			Name = "WallRun",
			Size = Vector3.new(2, 24, length + 8),
			Position = Vector3.new(side * 8, baseY + 6, -(cursor + length / 2)),
			Color = COLORS.Wall,
		}, course)
		gap(length)
		return block(16, 16, 0)
	end

	-- 1. Salida
	newPart("SpawnLocation", {
		Name = "Spawn",
		Size = Vector3.new(24, 2, 24),
		Position = Vector3.new(0, baseY - 1, -12),
		Color = COLORS.Runway,
		Neutral = true,
		Duration = 0,
	}, course)
	cursor = 24
	gate("Start", 24, COLORS.Start, baseY)

	-- 2. Pista para coger velocidad
	block(40, 12, 0, 0, COLORS.Runway)

	-- 3. Saltos entre plataformas
	local jumps = {
		{ x = 4, h = 1 },
		{ x = -4, h = 3 },
		{ x = 3, h = 5 },
		{ x = -3, h = 3 },
		{ x = 0, h = 1 },
	}
	for _, jump in jumps do
		gap(7)
		block(8, 8, jump.h, jump.x)
	end
	gap(7)
	checkpoint(block(16, 16, 0))

	-- 4. Doble wall run (izquierda y luego derecha)
	wallRunSection(-1, 34)
	checkpoint(wallRunSection(1, 34))

	-- 5. Rampa: hace falta ir rápido (o deslizarse) para pasar el hueco
	block(40, 10, 0, 0, COLORS.Runway)
	local rampLength, rampRise = 16, 6
	newPart("Part", {
		Name = "Ramp",
		Size = Vector3.new(10, 1, math.sqrt(rampLength ^ 2 + rampRise ^ 2)),
		CFrame = CFrame.new(0, baseY + rampRise / 2 - 0.5, -(cursor + rampLength / 2))
			* CFrame.Angles(math.atan2(rampRise, rampLength), 0, 0),
		Color = COLORS.Start,
	}, course)
	cursor += rampLength
	gap(18)
	checkpoint(block(20, 14, 2))

	-- 6. Escalera final
	local stairs = {
		{ x = -4, h = 6 },
		{ x = 4, h = 10 },
		{ x = -4, h = 14 },
		{ x = 2, h = 18 },
	}
	for _, step in stairs do
		gap(5)
		block(6, 6, step.h, step.x)
	end

	-- 7. Meta
	gap(6)
	gate("Finish", 24, COLORS.Finish, baseY + 20)
	block(24, 24, 20, 0, COLORS.Finish)

	-- Ranking global junto a la salida
	newPart("Part", {
		Name = "Leaderboard",
		Size = Vector3.new(14, 12, 1),
		CFrame = CFrame.lookAt(Vector3.new(16, baseY + 7, -12), Vector3.new(0, baseY + 7, -12)),
		Color = COLORS.Board,
	}, course)

	course.Parent = workspace
	return course
end

return CourseBuilder
