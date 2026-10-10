-- Genera el lobby y los mapas si en Workspace no existe una carpeta "Maps".
-- Puedes construir tus propios mapas en Studio con la estructura del README.
--
-- Cada mapa es una carpeta dentro de Workspace/Maps con atributos:
--   DisplayName, Order, Color, Bronze, Silver, Gold, Dev (tiempos de medalla)
--   Vip (solo VIP), Tutorial (sin ranking ni medallas)
-- y estos hijos: StartPad, Start, Finish, Checkpoints/1..n
-- Los obstáculos especiales se marcan con etiquetas (CollectionService):
--   MovingPlatform, Trampoline, Zipline, LowGravity

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local CourseBuilder = {}

local function newPart(className: string, props: { [string]: any }, parent: Instance?): BasePart
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

local function billboard(part: BasePart, text: string, size: Vector2, offset: Vector3, color: Color3?)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(size.X, size.Y)
	gui.StudsOffsetWorldSpace = offset
	gui.MaxDistance = 120
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Text = text
	label.Parent = gui
end

-- Constructor de un mapa ---------------------------------------------------------
-- Coordenadas locales: x = lateral, h = altura sobre la base, el cursor avanza
-- hacia delante (-Z en el mundo, que es hacia donde mira el jugador).

type Theme = { platform: Color3, runway: Color3, accent: Color3, wall: Color3, material: Enum.Material }

local MapBuilder = {}
MapBuilder.__index = MapBuilder

function MapBuilder.new(parent: Instance, id: string, attributes: { [string]: any }, originX: number, theme: Theme)
	local folder = Instance.new("Folder")
	folder.Name = id
	for name, value in attributes do
		folder:SetAttribute(name, value)
	end
	local checkpoints = Instance.new("Folder")
	checkpoints.Name = "Checkpoints"
	checkpoints.Parent = folder
	folder.Parent = parent

	return setmetatable({
		folder = folder,
		checkpoints = checkpoints,
		origin = Vector3.new(originX, Config.CourseHeight, 0),
		cursor = 0,
		count = 0,
		theme = theme,
	}, MapBuilder)
end

function MapBuilder:point(x: number, h: number, distance: number): Vector3
	return self.origin + Vector3.new(x, h, -distance)
end

function MapBuilder:gap(distance: number)
	self.cursor += distance
end

function MapBuilder:block(length: number, width: number, h: number, x: number?, color: Color3?): BasePart
	local part = newPart("Part", {
		Size = Vector3.new(width, 2, length),
		Position = self:point(x or 0, h - 1, self.cursor + length / 2),
		Color = color or self.theme.platform,
		Material = self.theme.material,
	}, self.folder)
	self.cursor += length
	return part
end

function MapBuilder:runway(length: number, h: number?): BasePart
	return self:block(length, 12, h or 0, 0, self.theme.runway)
end

-- Detector invisible que cruza el circuito en la posición actual
function MapBuilder:gate(name: string, width: number, h: number, color: Color3): BasePart
	return newPart("Part", {
		Name = name,
		Size = Vector3.new(width, 10, 1),
		Position = self:point(0, h + 5, self.cursor),
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.6,
		CanCollide = false,
		CanQuery = false,
	}, self.folder)
end

function MapBuilder:start()
	newPart("Part", {
		Name = "StartPad",
		Size = Vector3.new(24, 2, 24),
		Position = self:point(0, -1, 12),
		Color = self.theme.runway,
		Material = self.theme.material,
	}, self.folder)
	self.cursor = 24
	self:gate("Start", 24, 0, Color3.fromRGB(0, 170, 255))
end

function MapBuilder:checkpoint(platform: BasePart)
	self.count += 1
	local cp = newPart("Part", {
		Name = tostring(self.count),
		Size = Vector3.new(platform.Size.X, 8, 2),
		CFrame = CFrame.new(platform.Position + Vector3.new(0, platform.Size.Y / 2 + 4, 0)),
		Color = Color3.fromRGB(0, 255, 140),
		Material = Enum.Material.Neon,
		Transparency = 0.6,
		CanCollide = false,
		CanQuery = false,
	}, self.checkpoints)
	cp:SetAttribute("Index", self.count)
end

function MapBuilder:finish(h: number)
	self:gate("Finish", 24, h, Color3.fromRGB(255, 210, 0))
	self:block(24, 24, h, 0, Color3.fromRGB(255, 210, 0))
end

-- Hueco con una pared al lado para el wall run. side: -1 izquierda, 1 derecha
function MapBuilder:wallRun(side: number, length: number, h: number?): BasePart
	local height = h or 0
	newPart("Part", {
		Name = "WallRun",
		Size = Vector3.new(2, 24, length + 8),
		Position = self:point(side * 8, height + 6, self.cursor + length / 2),
		Color = self.theme.wall,
		Material = self.theme.material,
	}, self.folder)
	self:gap(length)
	return self:block(16, 16, height)
end

function MapBuilder:ramp(length: number, rise: number, h: number?)
	local base = h or 0
	newPart("Part", {
		Name = "Ramp",
		Size = Vector3.new(10, 1, math.sqrt(length ^ 2 + rise ^ 2)),
		CFrame = CFrame.new(self:point(0, base + rise / 2 - 0.5, self.cursor + length / 2))
			* CFrame.Angles(math.atan2(rise, length), 0, 0),
		Color = self.theme.accent,
		Material = self.theme.material,
	}, self.folder)
	self.cursor += length
end

-- Plataforma que te lanza hacia arriba
function MapBuilder:trampoline(h: number, x: number?): BasePart
	local pad = newPart("Part", {
		Name = "Trampoline",
		Size = Vector3.new(8, 1, 8),
		Position = self:point(x or 0, h - 0.5, self.cursor + 4),
		Color = Color3.fromRGB(255, 60, 180),
		Material = Enum.Material.Neon,
	}, self.folder)
	pad:SetAttribute("Power", Config.TrampolinePower)
	CollectionService:AddTag(pad, "Trampoline")
	self.cursor += 8
	return pad
end

-- Plataforma que se mueve de un lado a otro (la animan los clientes)
function MapBuilder:moving(length: number, width: number, h: number, offset: Vector3, period: number, phase: number?): BasePart
	local part = self:block(length, width, h, 0, self.theme.accent)
	part.Name = "MovingPlatform"
	part.Material = Enum.Material.Neon
	part:SetAttribute("Offset", offset)
	part:SetAttribute("Period", period)
	part:SetAttribute("Phase", phase or 0)
	CollectionService:AddTag(part, "MovingPlatform")
	return part
end

-- Zona de gravedad baja que cubre los próximos "length" studs
function MapBuilder:lowGravity(length: number, h: number)
	local zone = newPart("Part", {
		Name = "LowGravity",
		Size = Vector3.new(40, 60, length),
		Position = self:point(0, h + 20, self.cursor + length / 2),
		Color = Color3.fromRGB(120, 80, 255),
		Material = Enum.Material.ForceField,
		Transparency = 0.5,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	}, self.folder)
	zone:SetAttribute("Gravity", Config.LowGravityFactor)
	CollectionService:AddTag(zone, "LowGravity")
end

-- Tirolina desde el borde actual, bajando "drop" studs a lo largo de "length"
function MapBuilder:zipline(length: number, drop: number, h: number)
	local a = self:point(0, h + 7, self.cursor + 2)
	local b = self:point(0, h + 7 - drop, self.cursor + length)
	local rope = newPart("Part", {
		Name = "Zipline",
		Size = Vector3.new(0.3, 0.3, (b - a).Magnitude),
		CFrame = CFrame.lookAt((a + b) / 2, b),
		Color = Color3.fromRGB(40, 40, 40),
		Material = Enum.Material.Metal,
		CanCollide = false,
		CanQuery = false,
	}, self.folder)
	rope:SetAttribute("A", a)
	rope:SetAttribute("B", b)
	CollectionService:AddTag(rope, "Zipline")

	for _, point in { a, b } do
		newPart("Part", {
			Name = "ZiplinePole",
			Size = Vector3.new(1, 12, 1),
			Position = point + Vector3.new(3, -5, 0),
			Color = self.theme.wall,
			Material = Enum.Material.Metal,
		}, self.folder)
	end
	self.cursor += length
end

function MapBuilder:sign(text: string, h: number)
	local anchor = newPart("Part", {
		Name = "Sign",
		Size = Vector3.new(1, 1, 1),
		Position = self:point(0, h + 9, self.cursor),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	}, self.folder)
	billboard(anchor, text, Vector2.new(24, 4), Vector3.zero)
end

-- Mapas ------------------------------------------------------------------------------

local THEMES: { [string]: Theme } = {
	Ciudad = {
		platform = Color3.fromRGB(230, 232, 240),
		runway = Color3.fromRGB(60, 64, 80),
		accent = Color3.fromRGB(0, 170, 255),
		wall = Color3.fromRGB(255, 120, 40),
		material = Enum.Material.SmoothPlastic,
	},
	Neon = {
		platform = Color3.fromRGB(30, 30, 45),
		runway = Color3.fromRGB(20, 20, 30),
		accent = Color3.fromRGB(0, 255, 230),
		wall = Color3.fromRGB(255, 0, 170),
		material = Enum.Material.Glass,
	},
	Selva = {
		platform = Color3.fromRGB(120, 90, 60),
		runway = Color3.fromRGB(70, 110, 50),
		accent = Color3.fromRGB(160, 220, 80),
		wall = Color3.fromRGB(90, 140, 60),
		material = Enum.Material.Wood,
	},
	Cielo = {
		platform = Color3.fromRGB(250, 250, 255),
		runway = Color3.fromRGB(200, 205, 225),
		accent = Color3.fromRGB(255, 205, 40),
		wall = Color3.fromRGB(255, 225, 120),
		material = Enum.Material.Marble,
	},
}

-- Para añadir un mapa nuevo: añade una entrada aquí
CourseBuilder.Definitions = {
	{
		id = "tutorial",
		theme = THEMES.Ciudad,
		attributes = {
			DisplayName = "Tutorial",
			Order = 0,
			Color = Color3.fromRGB(0, 230, 120),
			Tutorial = true,
		},
		build = function(m)
			m:start()
			m:sign("Corre sin parar: cuanto más corres, más rápido vas", 0)
			m:runway(40)
			m:sign("Salta los huecos con Espacio", 0)
			m:gap(5)
			m:block(10, 10, 1)
			m:gap(5)
			m:block(10, 10, 2)
			m:sign("Pulsa C (o el botón Deslizar) para ganar velocidad", 2)
			m:runway(30, 2)
			m:gap(12)
			m:checkpoint(m:block(16, 16, 2))
			m:sign("Salta hacia la pared naranja mientras corres", 2)
			m:wallRun(-1, 24, 2)
			m:sign("En la pared, pulsa Espacio para hacer un wall jump", 2)
			m:checkpoint(m:wallRun(1, 30, 2))
			m:sign("Los trampolines rosas te lanzan muy alto", 2)
			m:trampoline(2)
			m:gap(8)
			m:block(16, 12, 18)
			m:sign("Salta hacia el cable para usar la tirolina", 18)
			m:zipline(60, 10, 18)
			m:checkpoint(m:block(16, 14, 6))
			m:sign("Zona morada: gravedad baja, ¡salta lejos!", 6)
			m:lowGravity(30, 6)
			m:gap(24)
			m:block(10, 10, 10)
			m:gap(6)
			m:sign("¡Llega a la meta!", 10)
			m:finish(10)
		end,
	},
	{
		id = "ciudad",
		theme = THEMES.Ciudad,
		attributes = {
			DisplayName = "Ciudad",
			Order = 1,
			Color = THEMES.Ciudad.accent,
			Bronze = 35,
			Silver = 25,
			Gold = 19,
			Dev = 15,
		},
		build = function(m)
			m:start()
			m:runway(40)
			for _, jump in { { 4, 1 }, { -4, 3 }, { 3, 5 }, { -3, 3 }, { 0, 1 } } do
				m:gap(7)
				m:block(8, 8, jump[2], jump[1])
			end
			m:gap(7)
			m:checkpoint(m:block(16, 16, 0))
			m:wallRun(-1, 34)
			m:checkpoint(m:wallRun(1, 34))
			m:runway(40)
			m:ramp(16, 6)
			m:gap(18)
			m:checkpoint(m:block(20, 14, 2))
			for _, step in { { -4, 6 }, { 4, 10 }, { -4, 14 }, { 2, 18 } } do
				m:gap(5)
				m:block(6, 6, step[2], step[1])
			end
			m:gap(6)
			m:finish(20)
		end,
	},
	{
		id = "neon",
		theme = THEMES.Neon,
		attributes = {
			DisplayName = "Neón",
			Order = 2,
			Color = THEMES.Neon.accent,
			Bronze = 45,
			Silver = 33,
			Gold = 26,
			Dev = 21,
		},
		build = function(m)
			m:start()
			m:runway(30)
			m:gap(6)
			m:moving(8, 8, 0, Vector3.new(10, 0, 0), 3)
			m:gap(6)
			m:moving(8, 8, 0, Vector3.new(10, 0, 0), 3, 0.5)
			m:gap(6)
			m:checkpoint(m:block(14, 14, 0))
			m:trampoline(0)
			m:gap(10)
			m:block(20, 12, 18)
			m:gap(8)
			m:block(10, 10, 16)
			m:gap(8)
			m:block(10, 10, 14)
			-- Gravedad baja: saltos largos
			m:lowGravity(76, 0)
			m:gap(20)
			m:block(8, 8, 20)
			m:gap(20)
			m:block(8, 8, 12)
			m:gap(20)
			m:checkpoint(m:block(14, 14, 8))
			m:wallRun(1, 34, 8)
			m:checkpoint(m:wallRun(-1, 34, 8))
			m:gap(6)
			m:moving(8, 8, 8, Vector3.new(0, 10, 0), 4) -- ascensor
			m:gap(6)
			m:block(10, 10, 16)
			m:gap(6)
			m:finish(18)
		end,
	},
	{
		id = "selva",
		theme = THEMES.Selva,
		attributes = {
			DisplayName = "Selva",
			Order = 3,
			Color = THEMES.Selva.accent,
			Bronze = 50,
			Silver = 38,
			Gold = 30,
			Dev = 24,
		},
		build = function(m)
			m:start()
			m:runway(30)
			m:ramp(16, 6)
			m:gap(16)
			m:block(16, 14, 2)
			m:gap(5)
			m:block(6, 6, 6, -3)
			m:gap(5)
			m:block(6, 6, 10, 3)
			m:gap(5)
			m:checkpoint(m:block(12, 12, 14))
			-- Tirolina: salta hacia el cable para engancharte
			m:zipline(90, 12, 14)
			m:block(20, 16, 0)
			m:gap(6)
			m:trampoline(0)
			m:gap(10)
			m:checkpoint(m:block(20, 12, 16))
			m:wallRun(-1, 36, 12)
			m:gap(6)
			m:moving(8, 8, 12, Vector3.new(8, 0, 0), 2.5)
			m:gap(6)
			m:moving(8, 8, 12, Vector3.new(8, 0, 0), 2.5, 0.5)
			m:gap(6)
			m:checkpoint(m:block(14, 14, 12))
			m:runway(30, 12)
			m:ramp(16, 6, 12)
			m:gap(18)
			m:block(20, 14, 14)
			m:gap(6)
			m:finish(16)
		end,
	},
	{
		id = "cielo",
		theme = THEMES.Cielo,
		attributes = {
			DisplayName = "Cielo",
			Order = 4,
			Color = THEMES.Cielo.accent,
			Vip = true,
			Bronze = 55,
			Silver = 42,
			Gold = 33,
			Dev = 27,
		},
		build = function(m)
			m:start()
			m:runway(40)
			for _, jump in { { 4, 1 }, { -4, 3 }, { 4, 5 } } do
				m:gap(9)
				m:block(6, 6, jump[2], jump[1])
			end
			m:gap(9)
			m:checkpoint(m:block(12, 12, 3))
			m:wallRun(1, 40, 3)
			m:checkpoint(m:wallRun(-1, 40, 3))
			m:trampoline(3)
			m:gap(12)
			m:block(16, 10, 24)
			m:zipline(80, 14, 24)
			m:block(16, 14, 10)
			m:lowGravity(56, 10)
			m:gap(22)
			m:block(6, 6, 16)
			m:gap(22)
			m:block(6, 6, 10)
			m:gap(8)
			m:checkpoint(m:block(14, 14, 8))
			m:runway(30, 8)
			m:ramp(16, 6, 8)
			m:gap(18)
			m:finish(12)
		end,
	},
}

-- Lobby ------------------------------------------------------------------------------

local DARK_METAL = Color3.fromRGB(35, 38, 52)

-- Partículas brillantes que flotan (portales y carrera en vivo)
local function sparkles(parent: BasePart, color: Color3, direction: Enum.NormalId, rate: number)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 1
	emitter.EmissionDirection = direction
	emitter.Rate = rate
	emitter.Lifetime = NumberRange.new(1.5, 2.5)
	emitter.Speed = NumberRange.new(2, 5)
	emitter.SpreadAngle = Vector2.new(25, 25)
	emitter.Size = NumberSequence.new(0.5, 0)
	emitter.Transparency = NumberSequence.new(0.2, 1)
	emitter.Parent = parent
end

-- Cartel con fondo oscuro y borde de color en la cara frontal de una Part
local function namePlate(part: BasePart, text: string, color: Color3)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.Parent = part

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(18, 20, 30)
	frame.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 18)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 6
	stroke.Parent = frame

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -40, 1, -20)
	label.Position = UDim2.fromOffset(20, 10)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = text
	label.Parent = frame
end

-- Portal con arco de neón, superficie de energía, luz, partículas y cartel con el nombre
local function buildPortal(portals: Folder, map: Folder, base: Vector3)
	local color = map:GetAttribute("Color") or Color3.new(1, 1, 1)
	local isVip = map:GetAttribute("Vip") == true
	local isTutorial = map:GetAttribute("Tutorial") == true
	local trim = if isVip then Color3.fromRGB(255, 205, 40) else color
	local facing = Vector3.new(0, 0, 1) -- los portales miran hacia el spawn

	local radius = 6.5 -- distancia del centro a cada columna
	local pillarHeight = 13
	local archCenter = base + Vector3.new(0, pillarHeight, 0)

	-- Escalón de la base
	newPart("Part", {
		Name = "Step",
		Size = Vector3.new(radius * 2 + 6, 0.4, 7),
		Position = base + Vector3.new(0, 0.2, 0),
		Color = DARK_METAL,
		Material = Enum.Material.Metal,
	}, portals)
	newPart("Part", {
		Name = "StepGlow",
		Size = Vector3.new(radius * 2 + 6, 0.1, 0.4),
		Position = base + Vector3.new(0, 0.45, 3.3),
		Color = trim,
		Material = Enum.Material.Neon,
	}, portals)

	-- Columnas oscuras con una franja de neón delante
	for _, side in { -1, 1 } do
		newPart("Part", {
			Name = "Pillar",
			Size = Vector3.new(2.5, pillarHeight, 2.5),
			Position = base + Vector3.new(side * radius, pillarHeight / 2 + 0.4, 0),
			Color = DARK_METAL,
			Material = Enum.Material.Metal,
		}, portals)
		newPart("Part", {
			Name = "PillarGlow",
			Size = Vector3.new(0.5, pillarHeight - 1, 0.2),
			Position = base + Vector3.new(side * radius, pillarHeight / 2 + 0.4, 1.3),
			Color = trim,
			Material = Enum.Material.Neon,
		}, portals)
	end

	-- Arco de neón (semicírculo hecho con segmentos)
	local segments = 12
	local segmentLength = 2 * radius * math.sin(math.pi / (2 * segments)) * 1.25
	for k = 0, segments - 1 do
		local angle = (k + 0.5) / segments * math.pi
		local position = archCenter + Vector3.new(radius * math.cos(angle), radius * math.sin(angle) + 0.4, 0)
		newPart("Part", {
			Name = "Arch",
			Size = Vector3.new(2.5, segmentLength, 2.5),
			CFrame = CFrame.new(position) * CFrame.Angles(0, 0, angle),
			Color = trim,
			Material = Enum.Material.Neon,
		}, portals)
	end

	-- Superficie de energía (rectángulo + semicírculo). Solo "Portal" detecta al jugador.
	local inner = radius * 2 - 2.5
	local portal = newPart("Part", {
		Name = "Portal",
		Size = Vector3.new(inner, pillarHeight, 0.4),
		Position = base + Vector3.new(0, pillarHeight / 2 + 0.4, 0),
		Color = color,
		Material = Enum.Material.ForceField,
		Transparency = 0.15,
		CanCollide = false,
	}, portals)
	portal:SetAttribute("MapId", map.Name)
	newPart("Part", {
		Name = "PortalTop",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, inner, inner),
		CFrame = CFrame.new(archCenter + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, math.rad(90), 0),
		Color = color,
		Material = Enum.Material.ForceField,
		Transparency = 0.15,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
	}, portals)

	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 18
	light.Brightness = 2
	light.Parent = portal
	sparkles(portal, color, Enum.NormalId.Front, 6)

	-- Cartel con el nombre, encima del arco
	local name = map:GetAttribute("DisplayName") or map.Name
	local plateCenter = archCenter + Vector3.new(0, radius + 3.4, 0)
	local plate = newPart("Part", {
		Name = "NamePlate",
		Size = Vector3.new(13, 3, 0.5),
		CFrame = CFrame.lookAt(plateCenter, plateCenter + facing),
		Color = DARK_METAL,
	}, portals)
	namePlate(
		plate,
		if isVip then "⭐ " .. name .. " · VIP" elseif isTutorial then "📘 " .. name else name,
		trim
	)
	if isTutorial then
		billboard(plate, "¡Empieza aquí!", Vector2.new(10, 2), Vector3.new(0, 2.6, 0), Color3.fromRGB(0, 230, 120))
	end

end

-- Zona de rankings: una fila de carteles a la altura de los ojos.
-- "origin" es el centro de la fila en el suelo y "facing" hacia dónde miran.
local function buildRankingWall(lobby: Folder, boards: Folder, maps: { Folder }, origin: Vector3, facing: Vector3)
	local ranked = {}
	for _, map in maps do
		if not map:GetAttribute("Tutorial") then
			table.insert(ranked, map)
		end
	end

	local along = Vector3.yAxis:Cross(facing) -- de izquierda a derecha vista de frente
	local boardSize = Vector3.new(18, 14, 1)
	local spacing = boardSize.X + 4
	local rowLength = #ranked * spacing

	-- Suelo de la zona y muro trasero
	newPart("Part", {
		Name = "RankingFloor",
		Size = Vector3.new(rowLength + 6, 0.2, 16),
		CFrame = CFrame.lookAt(origin + facing * 6 + Vector3.new(0, 0.1, 0), origin + facing * 7 + Vector3.new(0, 0.1, 0)),
		Color = Color3.fromRGB(30, 32, 46),
	}, lobby)
	newPart("Part", {
		Name = "RankingWall",
		Size = Vector3.new(rowLength + 6, 22, 2),
		CFrame = CFrame.lookAt(origin - facing * 1.5 + Vector3.new(0, 11, 0), origin + facing + Vector3.new(0, 11, 0)),
		Color = DARK_METAL,
		Material = Enum.Material.Metal,
	}, lobby)

	-- Título de la zona
	local titleCenter = origin + Vector3.new(0, 19, 0) + facing * 0.2
	local title = newPart("Part", {
		Name = "RankingTitle",
		Size = Vector3.new(26, 4, 0.5),
		CFrame = CFrame.lookAt(titleCenter, titleCenter + facing),
		Color = DARK_METAL,
	}, lobby)
	namePlate(title, "🏆 RANKINGS", Color3.fromRGB(255, 205, 40))

	for i, map in ranked do
		local color = map:GetAttribute("Color") or Color3.new(1, 1, 1)
		local offset = (i - (#ranked + 1) / 2) * spacing
		local center = origin + along * offset + Vector3.new(0, boardSize.Y / 2 + 1.5, 0) + facing * 0.5

		local board = newPart("Part", {
			Name = "Board",
			Size = boardSize,
			CFrame = CFrame.lookAt(center, center + facing),
			Color = Color3.fromRGB(20, 20, 30),
		}, boards)
		board:SetAttribute("MapId", map.Name)

		-- Marco de neón del color del mapa
		local frameCenter = center - facing * 0.1
		local frame = CFrame.lookAt(frameCenter, frameCenter + facing)
		local w, h = boardSize.X / 2 + 0.3, boardSize.Y / 2 + 0.3
		for _, piece in {
			{ CFrame.new(0, h, 0), Vector3.new(boardSize.X + 1.2, 0.6, 0.6) },
			{ CFrame.new(0, -h, 0), Vector3.new(boardSize.X + 1.2, 0.6, 0.6) },
			{ CFrame.new(w, 0, 0), Vector3.new(0.6, boardSize.Y + 1.2, 0.6) },
			{ CFrame.new(-w, 0, 0), Vector3.new(0.6, boardSize.Y + 1.2, 0.6) },
		} do
			newPart("Part", {
				Name = "BoardFrame",
				Size = piece[2],
				CFrame = frame * piece[1],
				Color = color,
				Material = Enum.Material.Neon,
			}, lobby)
		end

		-- Luz suave delante del cartel para que se lea bien
		local light = Instance.new("SurfaceLight")
		light.Face = Enum.NormalId.Front
		light.Color = color
		light.Range = 10
		light.Brightness = 0.6
		light.Parent = board
	end
end

-- Plataforma de la carrera en vivo: anillo de neón, partículas y cartel alto en un poste
local function buildLiveRacePad(lobby: Folder, center: Vector3, viewer: Vector3)
	local purple = Color3.fromRGB(170, 80, 255)
	local flat = CFrame.Angles(0, 0, math.rad(90)) -- cilindros tumbados (eje vertical)

	newPart("Part", {
		Name = "LiveRaceRing",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.5, 22, 22),
		CFrame = CFrame.new(center + Vector3.new(0, 0.25, 0)) * flat,
		Color = purple,
		Material = Enum.Material.Neon,
	}, lobby)
	newPart("Part", {
		Name = "LiveRaceBase",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, 19.5, 19.5),
		CFrame = CFrame.new(center + Vector3.new(0, 0.3, 0)) * flat,
		Color = Color3.fromRGB(28, 20, 42),
	}, lobby)
	local pad = newPart("Part", {
		Name = "LiveRacePad",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.7, 15, 15),
		CFrame = CFrame.new(center + Vector3.new(0, 0.35, 0)) * flat,
		Color = Color3.fromRGB(120, 50, 200),
		Material = Enum.Material.Neon,
	}, lobby)
	local light = Instance.new("PointLight")
	light.Color = purple
	light.Range = 20
	light.Brightness = 2
	light.Parent = pad
	-- Con el cilindro tumbado, su cara "Right" mira hacia arriba
	sparkles(pad, Color3.fromRGB(220, 180, 255), Enum.NormalId.Right, 15)

	-- Poste detrás del círculo (visto desde el spawn) con el cartel bien alto
	local away = Vector3.new(center.X - viewer.X, 0, center.Z - viewer.Z).Unit
	local postBase = center + away * 13
	newPart("Part", {
		Name = "LiveRacePost",
		Size = Vector3.new(1.5, 18, 1.5),
		Position = postBase + Vector3.new(0, 9, 0),
		Color = DARK_METAL,
		Material = Enum.Material.Metal,
	}, lobby)
	local signCenter = postBase + Vector3.new(0, 19, 0) - away * 0.8
	local sign = newPart("Part", {
		Name = "LiveRaceSign",
		Size = Vector3.new(22, 5, 0.6),
		CFrame = CFrame.lookAt(signCenter, signCenter - away),
		Color = DARK_METAL,
	}, lobby)
	namePlate(sign, "🏁 CARRERA EN VIVO", purple)
	billboard(
		sign,
		"Pisa el círculo para unirte",
		Vector2.new(14, 1.8),
		Vector3.new(0, -3.8, 0),
		Color3.fromRGB(220, 180, 255)
	)
end

local function buildLobby(maps: { Folder }): Folder
	local lobby = Instance.new("Folder")
	lobby.Name = "Lobby"
	local y = Config.CourseHeight

	newPart("Part", {
		Name = "Floor",
		Size = Vector3.new(170, 2, 140),
		Position = Vector3.new(0, y - 1, -5),
		Color = Color3.fromRGB(45, 48, 62),
	}, lobby)

	newPart("SpawnLocation", {
		Name = "Spawn",
		Size = Vector3.new(12, 1, 12),
		Position = Vector3.new(0, y + 0.5, 20),
		Color = Color3.fromRGB(0, 170, 255),
		Material = Enum.Material.Neon,
		Neutral = true,
		Duration = 0,
	}, lobby)

	local portals = Instance.new("Folder")
	portals.Name = "Portals"
	portals.Parent = lobby
	local boards = Instance.new("Folder")
	boards.Name = "Boards"
	boards.Parent = lobby

	table.sort(maps, function(a, b)
		return (a:GetAttribute("Order") or 0) < (b:GetAttribute("Order") or 0)
	end)

	local spacing = 28
	for i, map in maps do
		local x = (i - (#maps + 1) / 2) * spacing
		buildPortal(portals, map, Vector3.new(x, y, -45))
	end

	-- Rankings detrás del spawn (no tapan los portales ni la carrera en vivo)
	buildRankingWall(lobby, boards, maps, Vector3.new(0, y, 58), Vector3.new(0, 0, -1))

	buildLiveRacePad(lobby, Vector3.new(58, y, 0), Vector3.new(0, y, 20))

	lobby.Parent = workspace
	return lobby
end

function CourseBuilder.buildAll(): (Folder, Folder)
	-- Desactiva otros spawns (p. ej. el de la plantilla Baseplate) para aparecer en el lobby
	for _, descendant in workspace:GetDescendants() do
		if descendant:IsA("SpawnLocation") then
			descendant.Enabled = false
		end
	end

	local mapsFolder = Instance.new("Folder")
	mapsFolder.Name = "Maps"
	mapsFolder.Parent = workspace

	local built = {}
	for i, definition in CourseBuilder.Definitions do
		local builder = MapBuilder.new(mapsFolder, definition.id, definition.attributes, i * Config.MapSpacing, definition.theme)
		definition.build(builder)
		table.insert(built, builder.folder)
	end

	local lobby = buildLobby(built)
	return mapsFolder, lobby
end

return CourseBuilder
