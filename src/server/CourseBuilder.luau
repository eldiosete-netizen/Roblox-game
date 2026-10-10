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
}

-- Para añadir un mapa nuevo: añade una entrada aquí
CourseBuilder.Definitions = {
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
}

-- Lobby ------------------------------------------------------------------------------

local function buildLobby(maps: { Folder }): Folder
	local lobby = Instance.new("Folder")
	lobby.Name = "Lobby"
	local y = Config.CourseHeight

	newPart("Part", {
		Name = "Floor",
		Size = Vector3.new(170, 2, 110),
		Position = Vector3.new(0, y - 1, -10),
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

	local spacing = 26
	for i, map in maps do
		local x = (i - (#maps + 1) / 2) * spacing
		local z = -45
		local color = map:GetAttribute("Color") or Color3.new(1, 1, 1)
		local isVip = map:GetAttribute("Vip") == true

		-- Marco del portal
		for _, side in { -1, 1 } do
			newPart("Part", {
				Name = "Pillar",
				Size = Vector3.new(2, 14, 2),
				Position = Vector3.new(x + side * 7, y + 7, z),
				Color = color,
				Material = Enum.Material.Neon,
			}, portals)
		end
		local top = newPart("Part", {
			Name = "Top",
			Size = Vector3.new(16, 2, 2),
			Position = Vector3.new(x, y + 15, z),
			Color = color,
			Material = Enum.Material.Neon,
		}, portals)
		billboard(
			top,
			(if isVip then "⭐ VIP · " else "") .. (map:GetAttribute("DisplayName") or map.Name),
			Vector2.new(14, 3),
			Vector3.new(0, 3, 0)
		)

		local portal = newPart("Part", {
			Name = "Portal",
			Size = Vector3.new(12, 14, 1),
			Position = Vector3.new(x, y + 7, z),
			Color = color,
			Material = Enum.Material.ForceField,
			Transparency = 0.3,
			CanCollide = false,
		}, portals)
		portal:SetAttribute("MapId", map.Name)

		-- Ranking del mapa encima del portal
		if not map:GetAttribute("Tutorial") then
			local board = newPart("Part", {
				Name = "Board",
				Size = Vector3.new(18, 16, 1),
				CFrame = CFrame.lookAt(Vector3.new(x, y + 28, z - 1), Vector3.new(x, y + 28, z + 10)),
				Color = Color3.fromRGB(20, 20, 30),
			}, boards)
			board:SetAttribute("MapId", map.Name)
		end
	end

	-- Plataforma para unirse a la carrera en vivo
	local pad = newPart("Part", {
		Name = "LiveRacePad",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, 18, 18),
		CFrame = CFrame.new(55, y + 0.5, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(170, 80, 255),
		Material = Enum.Material.Neon,
	}, lobby)
	billboard(pad, "🏁 CARRERA EN VIVO", Vector2.new(16, 3), Vector3.new(0, 7, 0), Color3.fromRGB(220, 180, 255))

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
