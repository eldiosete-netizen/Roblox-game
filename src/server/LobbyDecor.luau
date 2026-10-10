-- Decoración del lobby: plaza central, suelo con rejilla de neón, muros con
-- cristal, farolas, árboles, bancos, anillos holográficos, título gigante,
-- ciudad de fondo e iluminación.
--
-- Distribución del lobby (y = altura del suelo):
--   suelo x -85..85, z -75..65 · spawn (0, 20) · portales en z = -45
--   carrera en vivo en (58, 0) · pared de rankings en z = 58

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")

local BuildUtil = require(script.Parent:WaitForChild("BuildUtil"))

local newPart = BuildUtil.newPart
local DARK_METAL = BuildUtil.DarkMetal

local LobbyDecor = {}

local FLOOR_MIN = Vector2.new(-85, -75) -- (x, z)
local FLOOR_MAX = Vector2.new(85, 65)
local SPAWN = Vector2.new(0, 20)

local CYAN = Color3.fromRGB(0, 200, 255)
local PURPLE = Color3.fromRGB(170, 80, 255)
local FLAT = CFrame.Angles(0, 0, math.rad(90)) -- cilindro con el eje vertical

-- Anillo hecho con segmentos (en el plano XY local de "frame")
local function ring(parent: Instance, frame: CFrame, radius: number, thickness: number, color: Color3, segments: number)
	local length = 2 * radius * math.sin(math.pi / segments) * 1.1
	for k = 0, segments - 1 do
		local angle = k / segments * math.pi * 2
		newPart("Part", {
			Name = "RingSegment",
			Size = Vector3.new(thickness, length, thickness),
			CFrame = frame * CFrame.new(radius * math.cos(angle), radius * math.sin(angle), 0) * CFrame.Angles(0, 0, angle),
			Color = color,
			Material = Enum.Material.Neon,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
		}, parent)
	end
end

-- Plaza central alrededor del spawn
local function plaza(lobby: Folder, y: number)
	local center = Vector3.new(SPAWN.X, y, SPAWN.Y)
	newPart("Part", {
		Name = "PlazaRing",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.12, 38, 38),
		CFrame = CFrame.new(center + Vector3.new(0, 0.06, 0)) * FLAT,
		Color = CYAN,
		Material = Enum.Material.Neon,
	}, lobby)
	newPart("Part", {
		Name = "Plaza",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.16, 36, 36),
		CFrame = CFrame.new(center + Vector3.new(0, 0.08, 0)) * FLAT,
		Color = Color3.fromRGB(32, 35, 50),
		Material = Enum.Material.Slate,
	}, lobby)

	-- Anillos holográficos que giran sobre el spawn (los anima el cliente)
	local hologram = Instance.new("Model")
	hologram.Name = "Hologram"
	local holoCenter = CFrame.new(center + Vector3.new(0, 16, 0))
	ring(hologram, holoCenter, 6, 0.4, CYAN, 20)
	ring(hologram, holoCenter * CFrame.Angles(math.rad(90), 0, 0), 4.5, 0.35, PURPLE, 16)
	ring(hologram, holoCenter * CFrame.Angles(0, math.rad(90), 0), 3, 0.3, Color3.fromRGB(255, 205, 40), 14)
	local core = newPart("Part", {
		Name = "Core",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(2, 2, 2),
		CFrame = holoCenter,
		Color = Color3.new(1, 1, 1),
		Material = Enum.Material.Neon,
		CanCollide = false,
	}, hologram)
	local light = Instance.new("PointLight")
	light.Color = CYAN
	light.Range = 24
	light.Brightness = 1.5
	light.Parent = core
	hologram.PrimaryPart = core
	hologram:SetAttribute("SpinSpeed", 25) -- grados por segundo
	CollectionService:AddTag(hologram, "Spinner")
	hologram.Parent = lobby
end

-- Rejilla de neón tenue en el suelo
local function floorGrid(lobby: Folder, y: number)
	local grid = Instance.new("Folder")
	grid.Name = "FloorGrid"
	grid.Parent = lobby
	local props = {
		Color = Color3.fromRGB(40, 90, 160),
		Material = Enum.Material.Neon,
		Transparency = 0.55,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	}
	for x = FLOOR_MIN.X + 10, FLOOR_MAX.X - 10, 20 do
		props.Size = Vector3.new(0.25, 0.04, FLOOR_MAX.Y - FLOOR_MIN.Y - 4)
		props.Position = Vector3.new(x, y + 0.02, (FLOOR_MIN.Y + FLOOR_MAX.Y) / 2)
		newPart("Part", table.clone(props), grid)
	end
	for z = FLOOR_MIN.Y + 15, FLOOR_MAX.Y - 10, 20 do
		props.Size = Vector3.new(FLOOR_MAX.X - FLOOR_MIN.X - 4, 0.04, 0.25)
		props.Position = Vector3.new(0, y + 0.02, z)
		newPart("Part", table.clone(props), grid)
	end
end

-- Muro bajo con cristal y franja de neón alrededor del lobby
local function perimeter(lobby: Folder, y: number)
	local walls = Instance.new("Folder")
	walls.Name = "Perimeter"
	walls.Parent = lobby
	local width = FLOOR_MAX.X - FLOOR_MIN.X
	local depth = FLOOR_MAX.Y - FLOOR_MIN.Y
	local midZ = (FLOOR_MIN.Y + FLOOR_MAX.Y) / 2
	local sides = {
		{ position = Vector3.new(0, 0, FLOOR_MIN.Y), size = Vector3.new(width, 0, 1) },
		{ position = Vector3.new(0, 0, FLOOR_MAX.Y), size = Vector3.new(width, 0, 1) },
		{ position = Vector3.new(FLOOR_MIN.X, 0, midZ), size = Vector3.new(1, 0, depth) },
		{ position = Vector3.new(FLOOR_MAX.X, 0, midZ), size = Vector3.new(1, 0, depth) },
	}
	for _, side in sides do
		local base = side.position + Vector3.new(0, y, 0)
		newPart("Part", {
			Name = "WallBase",
			Size = side.size + Vector3.new(0, 3, 0),
			Position = base + Vector3.new(0, 1.5, 0),
			Color = DARK_METAL,
			Material = Enum.Material.Metal,
		}, walls)
		newPart("Part", {
			Name = "WallGlass",
			Size = Vector3.new(math.max(side.size.X - 0.6, 0.4), 6, math.max(side.size.Z - 0.6, 0.4)),
			Position = base + Vector3.new(0, 6, 0),
			Color = Color3.fromRGB(120, 200, 255),
			Material = Enum.Material.Glass,
			Transparency = 0.75,
		}, walls)
		newPart("Part", {
			Name = "WallGlow",
			Size = side.size + Vector3.new(0, 0.3, 0) + Vector3.new(0.2, 0, 0.2),
			Position = base + Vector3.new(0, 3.1, 0),
			Color = CYAN,
			Material = Enum.Material.Neon,
		}, walls)
	end
end

-- Farola de neón
local function lamp(parent: Instance, position: Vector3, color: Color3)
	newPart("Part", {
		Name = "LampPost",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(10, 0.8, 0.8),
		CFrame = CFrame.new(position + Vector3.new(0, 5, 0)) * FLAT,
		Color = DARK_METAL,
		Material = Enum.Material.Metal,
	}, parent)
	local head = newPart("Part", {
		Name = "LampHead",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.8, 1.8, 1.8),
		Position = position + Vector3.new(0, 10.5, 0),
		Color = color,
		Material = Enum.Material.Neon,
	}, parent)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 16
	light.Brightness = 1.2
	light.Parent = head
end

local function lamps(lobby: Folder, y: number)
	local folder = Instance.new("Folder")
	folder.Name = "Lamps"
	folder.Parent = lobby
	local positions = {
		-- A lo largo de los muros laterales
		Vector2.new(-80, -50), Vector2.new(-80, -25), Vector2.new(-80, 10), Vector2.new(-80, 40),
		Vector2.new(80, -50), Vector2.new(80, -25), Vector2.new(80, 25), Vector2.new(80, 40),
		-- Alrededor de la plaza
		Vector2.new(-20, 4), Vector2.new(20, 4), Vector2.new(-20, 36), Vector2.new(20, 36),
	}
	for i, p in positions do
		lamp(folder, Vector3.new(p.X, y, p.Y), if i % 2 == 0 then CYAN else PURPLE)
	end
end

-- Árbol estilizado en una jardinera
local function tree(parent: Instance, position: Vector3, scale: number)
	newPart("Part", {
		Name = "Planter",
		Size = Vector3.new(6, 1.6, 6),
		Position = position + Vector3.new(0, 0.8, 0),
		Color = DARK_METAL,
		Material = Enum.Material.Metal,
	}, parent)
	newPart("Part", {
		Name = "PlanterGlow",
		Size = Vector3.new(6.2, 0.2, 6.2),
		Position = position + Vector3.new(0, 1.6, 0),
		Color = Color3.fromRGB(0, 230, 120),
		Material = Enum.Material.Neon,
	}, parent)
	newPart("Part", {
		Name = "Soil",
		Size = Vector3.new(5.2, 0.2, 5.2),
		Position = position + Vector3.new(0, 1.65, 0),
		Color = Color3.fromRGB(60, 45, 35),
		Material = Enum.Material.Ground,
	}, parent)
	newPart("Part", {
		Name = "Trunk",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(7 * scale, 1, 1),
		CFrame = CFrame.new(position + Vector3.new(0, 1.6 + 3.5 * scale, 0)) * FLAT,
		Color = Color3.fromRGB(95, 65, 45),
		Material = Enum.Material.Wood,
	}, parent)
	local leaves = {
		{ Vector3.new(0, 8, 0), 6 },
		{ Vector3.new(1.6, 6.8, 0.8), 4.2 },
		{ Vector3.new(-1.4, 7, -1), 4.4 },
	}
	for _, leaf in leaves do
		newPart("Part", {
			Name = "Leaves",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * leaf[2] * scale,
			Position = position + leaf[1] * scale + Vector3.new(0, 1.6, 0),
			Color = Color3.fromRGB(60, 170, 90),
			Material = Enum.Material.Grass,
		}, parent)
	end
end

-- Banco en el que los jugadores pueden sentarse
local function bench(parent: Instance, position: Vector3, lookAt: Vector3)
	local frame = CFrame.lookAt(position, Vector3.new(lookAt.X, position.Y, lookAt.Z))
	local seat = Instance.new("Seat")
	seat.Name = "Bench"
	seat.Anchored = true
	seat.Size = Vector3.new(6, 0.5, 2)
	seat.CFrame = frame * CFrame.new(0, 1.6, 0)
	seat.Color = Color3.fromRGB(120, 85, 60)
	seat.Material = Enum.Material.Wood
	seat.TopSurface = Enum.SurfaceType.Smooth
	seat.Parent = parent
	newPart("Part", {
		Name = "BenchBack",
		Size = Vector3.new(6, 2, 0.4),
		CFrame = frame * CFrame.new(0, 2.8, 0.9),
		Color = Color3.fromRGB(120, 85, 60),
		Material = Enum.Material.Wood,
	}, parent)
	for _, side in { -2.5, 2.5 } do
		newPart("Part", {
			Name = "BenchLeg",
			Size = Vector3.new(0.4, 1.4, 1.8),
			CFrame = frame * CFrame.new(side, 0.7, 0),
			Color = DARK_METAL,
			Material = Enum.Material.Metal,
		}, parent)
	end
end

local function garden(lobby: Folder, y: number)
	local folder = Instance.new("Folder")
	folder.Name = "Garden"
	folder.Parent = lobby
	local trees = {
		{ Vector2.new(-30, 22), 1 },
		{ Vector2.new(30, 22), 1 },
		{ Vector2.new(-74, 52), 1.3 },
		{ Vector2.new(74, 52), 1.3 },
		{ Vector2.new(-76, -66), 1.3 },
		{ Vector2.new(76, -66), 1.3 },
		{ Vector2.new(-74, -10), 1.1 },
	}
	for _, t in trees do
		tree(folder, Vector3.new(t[1].X, y, t[1].Y), t[2])
	end
	local plaza = Vector3.new(SPAWN.X, y, SPAWN.Y)
	for _, p in { Vector2.new(-30, 12), Vector2.new(30, 12), Vector2.new(-30, 32), Vector2.new(30, 32) } do
		bench(folder, Vector3.new(p.X, y, p.Y), plaza)
	end
end

-- Título gigante sobre los portales
local function title(lobby: Folder, y: number)
	local center = Vector3.new(0, y + 36, -50)
	local sign = newPart("Part", {
		Name = "Title",
		Size = Vector3.new(70, 9, 1),
		CFrame = CFrame.lookAt(center, center + Vector3.new(0, 0, 1)),
		Color = DARK_METAL,
	}, lobby)
	BuildUtil.namePlate(sign, "PARKOUR DE VELOCIDAD", CYAN)
	for _, side in { -1, 1 } do
		newPart("Part", {
			Name = "TitleCable",
			Size = Vector3.new(0.3, 30, 0.3),
			Position = center + Vector3.new(side * 30, 19, 0),
			Color = DARK_METAL,
			Material = Enum.Material.Metal,
			CanCollide = false,
		}, lobby)
	end
end

-- Edificios con franjas de neón alrededor del lobby (solo decorado)
local function skyline(lobby: Folder, y: number)
	local folder = Instance.new("Folder")
	folder.Name = "Skyline"
	folder.Parent = lobby
	local random = Random.new(2024)
	local colors = { CYAN, PURPLE, Color3.fromRGB(255, 80, 180), Color3.fromRGB(255, 205, 40) }
	local count = 28
	for i = 1, count do
		local angle = (i / count) * math.pi * 2 + random:NextNumber(-0.08, 0.08)
		local distance = random:NextNumber(150, 210)
		local width = random:NextNumber(18, 34)
		local depth = random:NextNumber(18, 34)
		local height = random:NextNumber(40, 140)
		local base = Vector3.new(math.cos(angle) * distance, y - 60, math.sin(angle) * distance)
		local totalHeight = height + 60
		local frame = CFrame.lookAt(base, Vector3.new(0, base.Y, 0)) * CFrame.new(0, totalHeight / 2, 0)

		newPart("Part", {
			Name = "Building",
			Size = Vector3.new(width, totalHeight, depth),
			CFrame = frame,
			Color = Color3.fromRGB(22 + random:NextInteger(0, 12), 24 + random:NextInteger(0, 12), 38 + random:NextInteger(0, 16)),
			Material = Enum.Material.Concrete,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
		}, folder)

		local color = colors[random:NextInteger(1, #colors)]
		local bands = random:NextInteger(2, 5)
		for b = 1, bands do
			local bandY = 60 + height * (b / (bands + 1)) - totalHeight / 2
			newPart("Part", {
				Name = "NeonBand",
				Size = Vector3.new(width + 0.4, 0.6, depth + 0.4),
				CFrame = frame * CFrame.new(0, bandY, 0),
				Color = color,
				Material = Enum.Material.Neon,
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
				CastShadow = false,
			}, folder)
		end
		-- Luz roja en lo alto de los edificios más altos
		if height > 100 then
			newPart("Part", {
				Name = "Beacon",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(2, 2, 2),
				CFrame = frame * CFrame.new(0, totalHeight / 2 + 1, 0),
				Color = Color3.fromRGB(255, 50, 50),
				Material = Enum.Material.Neon,
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
			}, folder)
		end
	end
end

-- Atardecer con algo de brillo para que destaque el neón.
-- Solo añade efectos si el juego no tiene ya los suyos.
function LobbyDecor.applyLighting()
	Lighting.ClockTime = 17.6
	Lighting.Brightness = 2
	Lighting.OutdoorAmbient = Color3.fromRGB(110, 110, 140)
	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local atmosphere = Instance.new("Atmosphere")
		atmosphere.Density = 0.3
		atmosphere.Haze = 1.5
		atmosphere.Color = Color3.fromRGB(200, 170, 220)
		atmosphere.Decay = Color3.fromRGB(110, 80, 140)
		atmosphere.Parent = Lighting
	end
	if not Lighting:FindFirstChildOfClass("BloomEffect") then
		local bloom = Instance.new("BloomEffect")
		bloom.Intensity = 0.7
		bloom.Size = 24
		bloom.Threshold = 1.6
		bloom.Parent = Lighting
	end
end

function LobbyDecor.build(lobby: Folder, y: number)
	plaza(lobby, y)
	floorGrid(lobby, y)
	perimeter(lobby, y)
	lamps(lobby, y)
	garden(lobby, y)
	title(lobby, y)
	skyline(lobby, y)
	LobbyDecor.applyLighting()
end

return LobbyDecor
