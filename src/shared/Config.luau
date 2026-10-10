-- Configuración compartida entre servidor y cliente.
-- Cambia estos valores para ajustar cómo se siente el juego.

local Config = {
	-- Versión del juego (se ve en el menú de inicio y abajo a la derecha)
	Version = "2.3",

	-- Movimiento
	BaseWalkSpeed = 16, -- velocidad al empezar a correr
	MaxWalkSpeed = 34, -- velocidad máxima corriendo (momentum)
	Acceleration = 9, -- cuánto sube la velocidad por segundo corriendo en el suelo
	JumpPower = 55,

	-- Deslizamiento (C / Ctrl)
	SlideBoost = 20, -- velocidad extra al inicio del deslizamiento
	SlideDuration = 0.6,
	SlideCooldown = 1.2,

	-- Correr por paredes
	WallRunSpeed = 38,
	WallRunMaxTime = 1.6,
	WallRunFallSpeed = 3, -- caída inicial durante el wall run (aumenta con el tiempo)
	WallRunCheckDistance = 3,
	WallRunMinSpeed = 10, -- velocidad horizontal mínima para engancharse a una pared
	WallRunCooldown = 0.25,
	WallJumpOutForce = 40,
	WallJumpUpForce = 52,
	WallRunCameraTilt = 12, -- grados

	-- Cámara
	BaseFOV = 70,
	MaxFOV = 92,

	-- Efectos
	TrailSpeed = 28, -- a partir de esta velocidad aparece el rastro
	HardLandingSpeed = 60, -- caídas más rápidas que esto hacen temblar la cámara
	SlidePoseLean = 55, -- grados que se inclina el cuerpo hacia atrás al deslizar
	WallRunPoseLean = 20, -- grados que se inclina el cuerpo hacia la pared

	-- Sonidos (cámbialos por IDs de la Creator Store: "rbxassetid://123456")
	Sounds = {
		Countdown = "rbxasset://sounds/electronicpingshort.wav",
		Go = "rbxasset://sounds/electronicpingshort.wav",
		Checkpoint = "rbxasset://sounds/electronicpingshort.wav",
		Finish = "rbxasset://sounds/victory.wav",
		Record = "rbxasset://sounds/victory.wav",
		Slide = "rbxasset://sounds/swoosh.wav",
		WallJump = "rbxasset://sounds/swoosh.wav",
		Land = "rbxasset://sounds/action_jump_land.mp3",
		Wind = "rbxasset://sounds/action_falling.mp3",
		Bounce = "rbxasset://sounds/action_jump.mp3",
		Medal = "rbxasset://sounds/electronicpingshort.wav",
	},

	-- Carrera
	CountdownSeconds = 3,
	CourseHeight = 50, -- altura a la que se generan lobby y mapas
	MapSpacing = 300, -- separación entre mapas generados
	FallY = 20, -- si caes por debajo de esta Y, vuelves al último checkpoint
	MinValidTime = 5, -- tiempos más rápidos se consideran trampa
	LeaderboardSize = 8,
	LeaderboardRefresh = 120, -- segundos entre lecturas del ranking global

	-- Obstáculos
	TrampolinePower = 110,
	LowGravityFactor = 0.35, -- 1 = gravedad normal
	ZiplineMinSpeed = 30,
	ZiplineMaxSpeed = 70,
	ZiplineGrabDistance = 3.5,

	-- Fantasma (tu mejor intento)
	GhostSampleInterval = 0.1, -- segundos entre posiciones grabadas
	GhostMaxSamples = 3000, -- 5 minutos como máximo
	GhostColor = Color3.fromRGB(120, 220, 255),

	-- Carrera en vivo (todos a la vez)
	LiveRace = {
		MinPlayers = 2, -- ponlo a 1 para probar solo en Studio
		Intermission = 15, -- segundos de espera antes de empezar
		TimeLimit = 180, -- segundos máximos de carrera
	},

	-- Recompensas
	Rewards = {
		FinishCoins = 10,
		FirstFinishCoins = 25, -- la primera vez que terminas un mapa
		RecordCoins = 5,
		MedalCoins = { 15, 30, 60, 150 }, -- bronce, plata, oro, desarrollador (solo la primera vez)
		FinishXP = 40,
		MedalXP = 20, -- por cada nivel de medalla conseguido en la carrera
		RecordXP = 20,
		LivePlaceCoins = { 50, 30, 20 }, -- 1º, 2º y 3º en carrera en vivo
		LiveParticipationCoins = 10,
		LiveXP = 30,
		TutorialCoins = 50,
	},

	-- VIP (Game Pass). Crea el pase en el Creator Hub y pon aquí su ID.
	VipGamePassId = 2026076456,
	VipCoinMultiplier = 1.5,

	-- Pases de monedas (Game Pass). En la tienda se compran en orden: el x3 se
	-- desbloquea al tener el x2, etc. Se aplica el más alto que tengas (y se
	-- suma al +50% del VIP). Con id = 0 el pase sale como "Próximamente".
	CoinPasses = {
		{ key = "coins2", multiplier = 2, id = 0 },
		{ key = "coins3", multiplier = 3, id = 0 },
		{ key = "coins5", multiplier = 5, id = 0 },
		{ key = "coins10", multiplier = 10, id = 0 },
	},

	-- Ajustes por defecto del jugador
	DefaultSettings = {
		shake = true, -- temblor de cámara
		fov = true, -- efecto de velocidad en la cámara
		ghost = true, -- mostrar el fantasma
		wind = true, -- sonido de viento
		hints = true, -- mostrar controles en pantalla
	},

	-- Guardado
	DataStores = {
		Player = "PlayerData_v1",
		TimesPrefix = "Times_v1_",
		Ghosts = "Ghosts_v1",
	},
	AutosaveInterval = 120,
}

-- Medallas de mejor a peor. El tiempo de cada una se define por mapa.
Config.Medals = {
	{ id = "Dev", name = "Desarrollador", color = Color3.fromRGB(200, 90, 255) },
	{ id = "Gold", name = "Oro", color = Color3.fromRGB(255, 205, 40) },
	{ id = "Silver", name = "Plata", color = Color3.fromRGB(200, 210, 225) },
	{ id = "Bronze", name = "Bronce", color = Color3.fromRGB(205, 127, 70) },
}

-- Rango de medalla: 4 = Desarrollador, 3 = Oro, 2 = Plata, 1 = Bronce, 0 = ninguna
function Config.MedalRank(seconds: number, times: { [string]: number }): number
	for i, medal in Config.Medals do
		local limit = times[medal.id]
		if limit and seconds <= limit then
			return #Config.Medals - i + 1
		end
	end
	return 0
end

function Config.MedalInfo(rank: number)
	return Config.Medals[#Config.Medals - rank + 1]
end

-- Nivel a partir de la XP total. Devuelve: nivel, XP dentro del nivel, XP para subir
function Config.LevelFromXP(xp: number): (number, number, number)
	local level = 1
	local needed = 100
	while xp >= needed do
		xp -= needed
		level += 1
		needed = 100 + 50 * (level - 1)
	end
	return level, xp, needed
end

function Config.FormatTime(seconds: number?): string
	if not seconds then
		return "--:--.---"
	end
	local minutes = math.floor(seconds / 60)
	local rest = seconds - minutes * 60
	return string.format("%02d:%06.3f", minutes, rest)
end

return Config
