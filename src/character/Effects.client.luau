-- Efectos visuales y de sonido del movimiento: poses, partículas de salto y
-- deslizamiento, viento, sonidos y temblor de cámara al caer fuerte.
-- Lee el estado que publica Movement (atributos ParkourState, WallSide, WallJumpTick)
-- y los cosméticos equipados (atributos JumpItem y SlideItem del jugador).
-- Nota: estos efectos son locales, solo los ve el propio jugador. El rastro lo
-- pone el servidor (Shop) para que lo vea todo el mundo.

local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog"))
local Config = require(Shared:WaitForChild("Config"))
local Sfx = require(Shared:WaitForChild("Sfx"))

local character = script:FindFirstAncestorOfClass("Model") :: Model
local humanoid = character:WaitForChild("Humanoid") :: Humanoid
local root = character:WaitForChild("HumanoidRootPart") :: BasePart
local camera = workspace.CurrentCamera
local player = Players.LocalPlayer

local ClientState = require(player:WaitForChild("PlayerScripts"):WaitForChild("Client"):WaitForChild("ClientState"))

local function equipped(kind: string): Catalog.Item
	return Catalog.byId[player:GetAttribute(kind .. "Item") or ""] or Catalog.byId[Catalog.Defaults[kind]]
end

local SHAKE_STEP = "ParkourCameraShake"

local function horizontalSpeed(): number
	local v = root.AssemblyLinearVelocity
	return Vector3.new(v.X, 0, v.Z).Magnitude
end

-- Poses (inclinamos la articulación raíz; funciona con R15 y R6) ----------------

local lowerTorso = character:FindFirstChild("LowerTorso")
local rootJoint = (
	if lowerTorso then lowerTorso:WaitForChild("Root", 5) else root:WaitForChild("RootJoint", 5)
) :: Motor6D?
local baseC0 = if rootJoint then rootJoint.C0 else CFrame.identity
local poseOffset = CFrame.identity

local function targetPose(state: string?): CFrame
	if state == "Slide" then
		-- Cuerpo bajo e inclinado hacia atrás
		return CFrame.new(0, -1.3, 0) * CFrame.Angles(math.rad(Config.SlidePoseLean), 0, 0)
	elseif state == "WallRun" then
		local side = character:GetAttribute("WallSide") or 1
		return CFrame.Angles(0, 0, -math.rad(Config.WallRunPoseLean) * side)
	end
	return CFrame.identity
end

-- Partículas al deslizar y al saltar ----------------------------------------------

local feet = Instance.new("Attachment")
feet.Name = "SlideDust"
feet.Position = Vector3.new(0, -(humanoid.HipHeight + root.Size.Y / 2) + 0.3, 0)
feet.Parent = root

local dust = Instance.new("ParticleEmitter")
dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
dust.EmissionDirection = Enum.NormalId.Back
dust.Rate = 40
dust.Lifetime = NumberRange.new(0.3, 0.6)
dust.Speed = NumberRange.new(4, 8)
dust.SpreadAngle = Vector2.new(35, 35)
dust.Size = NumberSequence.new(0.6, 1.8)
dust.Transparency = NumberSequence.new(0.4, 1)
dust.Color = Catalog.colorSequence(equipped("Slide"))
dust.Enabled = false
dust.Parent = feet

local jumpBurst = Instance.new("ParticleEmitter")
jumpBurst.Texture = "rbxasset://textures/particles/sparkles_main.dds"
jumpBurst.EmissionDirection = Enum.NormalId.Bottom
jumpBurst.Rate = 0
jumpBurst.Lifetime = NumberRange.new(0.3, 0.6)
jumpBurst.Speed = NumberRange.new(6, 12)
jumpBurst.SpreadAngle = Vector2.new(70, 70)
jumpBurst.Size = NumberSequence.new(0.5, 0)
jumpBurst.LightEmission = 0.6
jumpBurst.Parent = feet

local function updateCosmetics()
	dust.Color = Catalog.colorSequence(equipped("Slide"))
	jumpBurst.Color = Catalog.colorSequence(equipped("Jump"))
end
updateCosmetics()
local slideItemConnection = player:GetAttributeChangedSignal("SlideItem"):Connect(updateCosmetics)
local jumpItemConnection = player:GetAttributeChangedSignal("JumpItem"):Connect(updateCosmetics)

-- Viento según la velocidad ------------------------------------------------------

local wind = Sfx.create("Wind", 0)
if wind then
	wind.Looped = true
	wind:Play()
end

-- Temblor de cámara ---------------------------------------------------------------

local SHAKE_DURATION = 0.35
local shakeTime = 0
local shakeStrength = 0

local function shake(strength: number)
	if not ClientState.setting("shake") then
		return
	end
	shakeStrength = math.max(if shakeTime > 0 then shakeStrength else 0, strength)
	shakeTime = SHAKE_DURATION
end

pcall(RunService.UnbindFromRenderStep, RunService, SHAKE_STEP)
RunService:BindToRenderStep(SHAKE_STEP, Enum.RenderPriority.Camera.Value + 2, function(dt)
	if shakeTime <= 0 then
		return
	end
	shakeTime -= dt
	local amount = shakeStrength * math.max(shakeTime, 0) / SHAKE_DURATION * 0.05
	camera.CFrame *= CFrame.Angles((math.random() - 0.5) * amount, (math.random() - 0.5) * amount, 0)
end)

-- Aterrizajes fuertes -------------------------------------------------------------

local peakFallSpeed = 0

humanoid.StateChanged:Connect(function(_, newState)
	if newState == Enum.HumanoidStateType.Jumping and equipped("Jump").id ~= Catalog.Defaults.Jump then
		jumpBurst:Emit(25)
	end
	if newState == Enum.HumanoidStateType.Landed then
		if peakFallSpeed > Config.HardLandingSpeed then
			local strength = math.clamp((peakFallSpeed - Config.HardLandingSpeed) / 80, 0.3, 1)
			shake(strength)
			Sfx.play("Land", 1, 0.4 + 0.4 * strength)
		end
		peakFallSpeed = 0
	end
end)

-- Sonidos de acciones -------------------------------------------------------------

character:GetAttributeChangedSignal("ParkourState"):Connect(function()
	if character:GetAttribute("ParkourState") == "Slide" then
		Sfx.play("Slide", 1.1, 0.5)
	end
end)

character:GetAttributeChangedSignal("WallJumpTick"):Connect(function()
	Sfx.play("WallJump", 1.3, 0.6)
end)

-- Bucle principal ------------------------------------------------------------------

local connection = RunService.Heartbeat:Connect(function(dt)
	local state = character:GetAttribute("ParkourState")
	local speed = horizontalSpeed()
	local airborne = humanoid.FloorMaterial == Enum.Material.Air

	-- Pose
	if rootJoint then
		poseOffset = poseOffset:Lerp(targetPose(state), math.min(dt * 12, 1))
		rootJoint.C0 = poseOffset * baseC0
	end

	dust.Enabled = state == "Slide" and not airborne

	if airborne then
		peakFallSpeed = math.max(peakFallSpeed, -root.AssemblyLinearVelocity.Y)
	end

	if wind then
		local alpha = math.clamp(
			(speed - Config.BaseWalkSpeed) / (Config.WallRunSpeed - Config.BaseWalkSpeed),
			0,
			1
		)
		wind.Volume = if ClientState.setting("wind") then 0.5 * alpha else 0
		wind.PlaybackSpeed = 0.8 + 0.4 * alpha
	end
end)

local function cleanup()
	connection:Disconnect()
	slideItemConnection:Disconnect()
	jumpItemConnection:Disconnect()
	pcall(RunService.UnbindFromRenderStep, RunService, SHAKE_STEP)
	if wind then
		wind:Destroy()
		wind = nil
	end
end

humanoid.Died:Connect(cleanup)
character.Destroying:Connect(cleanup)
