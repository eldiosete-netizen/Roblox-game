-- Configuración compartida entre servidor y cliente.
-- Cambia estos valores para ajustar cómo se siente el juego.

local Config = {
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

	-- Carrera
	CourseHeight = 50, -- altura del circuito generado
	FallY = 20, -- si caes por debajo de esta Y, vuelves al último checkpoint
	MinValidTime = 5, -- tiempos más rápidos se consideran trampa
	LeaderboardSize = 10,
	LeaderboardRefresh = 60, -- segundos entre actualizaciones del ranking global
	DataStoreName = "ParkourBestTimes_v1",
}

function Config.FormatTime(seconds: number?): string
	if not seconds then
		return "--:--.---"
	end
	local minutes = math.floor(seconds / 60)
	local rest = seconds - minutes * 60
	return string.format("%02d:%06.3f", minutes, rest)
end

return Config
