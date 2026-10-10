-- Movimiento de parkour: momentum al correr, deslizamiento, wall run y wall jump.
-- Va en StarterCharacterScripts, así que se reinicia con cada personaje.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local player = Players.LocalPlayer
local character = script:FindFirstAncestorOfClass("Model") :: Model
local humanoid = character:WaitForChild("Humanoid") :: Humanoid
local root = character:WaitForChild("HumanoidRootPart") :: BasePart
local camera = workspace.CurrentCamera

local CAMERA_STEP = "ParkourCameraTilt"
local SLIDE_ACTION = "ParkourSlide"

humanoid.UseJumpPower = true
humanoid.JumpPower = Config.JumpPower
humanoid.WalkSpeed = Config.BaseWalkSpeed

-- Fuerza que usamos para pegarnos a la pared durante el wall run
local attachment = Instance.new("Attachment")
attachment.Name = "ParkourAttachment"
attachment.Parent = root

local wallVelocity = Instance.new("LinearVelocity")
wallVelocity.Attachment0 = attachment
wallVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
wallVelocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
wallVelocity.MaxForce = math.huge
wallVelocity.Enabled = false
wallVelocity.Parent = root

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.FilterDescendantsInstances = { character }

-- Estado
local currentSpeed = Config.BaseWalkSpeed
local slideEndTime = 0
local lastSlideTime = -math.huge
local wallRunning = false
local wallNormal = Vector3.zero
local wallTangent = Vector3.zero
local wallRunStart = 0
local lastWallRunEnd = -math.huge
local lastWall: Instance? = nil
local cameraTilt = 0

-- Estado visible para el script de efectos (Effects): "None", "Slide" o "WallRun"
local function setParkourState(name: string)
	if character:GetAttribute("ParkourState") ~= name then
		character:SetAttribute("ParkourState", name)
	end
end

local function isGrounded(): boolean
	return humanoid.FloorMaterial ~= Enum.Material.Air
end

local function horizontalSpeed(): number
	local v = root.AssemblyLinearVelocity
	return Vector3.new(v.X, 0, v.Z).Magnitude
end

-- Deslizamiento ------------------------------------------------------------

local function trySlide()
	local now = os.clock()
	if now < slideEndTime or now - lastSlideTime < Config.SlideCooldown then
		return
	end
	if not isGrounded() or humanoid.MoveDirection.Magnitude < 0.1 then
		return
	end
	lastSlideTime = now
	slideEndTime = now + Config.SlideDuration
	-- El deslizamiento también deja buena parte del momentum ganado
	currentSpeed = math.max(currentSpeed, Config.BaseWalkSpeed + (Config.MaxWalkSpeed - Config.BaseWalkSpeed) * 0.75)
	humanoid.CameraOffset = Vector3.new(0, -1.5, 0)
end

ContextActionService:BindAction(SLIDE_ACTION, function(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		trySlide()
	end
	return Enum.ContextActionResult.Sink
end, true, Enum.KeyCode.C, Enum.KeyCode.LeftControl, Enum.KeyCode.ButtonB)
ContextActionService:SetTitle(SLIDE_ACTION, "Deslizar")
ContextActionService:SetPosition(SLIDE_ACTION, UDim2.new(1, -170, 1, -110))

-- Wall run -----------------------------------------------------------------

local function findWall(): RaycastResult?
	local right = root.CFrame.RightVector
	for _, side in { 1, -1 } do
		local result = workspace:Raycast(root.Position, right * side * Config.WallRunCheckDistance, rayParams)
		if result and math.abs(result.Normal.Y) < 0.2 then
			return result
		end
	end
	return nil
end

local function stopWallRun()
	if not wallRunning then
		return
	end
	wallRunning = false
	wallVelocity.Enabled = false
	lastWallRunEnd = os.clock()
end

local function tryStartWallRun()
	local now = os.clock()
	if wallRunning or isGrounded() or now - lastWallRunEnd < Config.WallRunCooldown then
		return
	end
	if humanoid.MoveDirection.Magnitude < 0.1 or horizontalSpeed() < Config.WallRunMinSpeed then
		return
	end

	local hit = findWall()
	if not hit then
		return
	end
	-- No volver a engancharse a la misma pared justo después de saltar de ella
	if hit.Instance == lastWall and now - lastWallRunEnd < 0.6 then
		return
	end

	local tangent = hit.Normal:Cross(Vector3.yAxis).Unit
	if tangent:Dot(root.CFrame.LookVector) < 0 then
		tangent = -tangent
	end

	wallRunning = true
	-- 1 = pared a la derecha, -1 = pared a la izquierda
	character:SetAttribute("WallSide", if hit.Normal:Dot(root.CFrame.RightVector) < 0 then 1 else -1)
	wallNormal = hit.Normal
	wallTangent = tangent
	wallRunStart = now
	lastWall = hit.Instance
	wallVelocity.Enabled = true
end

local function updateWallRun()
	local elapsed = os.clock() - wallRunStart
	local stillOnWall = workspace:Raycast(root.Position, -wallNormal * (Config.WallRunCheckDistance + 1), rayParams)

	if
		not stillOnWall
		or elapsed > Config.WallRunMaxTime
		or isGrounded()
		or humanoid.MoveDirection.Magnitude < 0.1
	then
		stopWallRun()
		return
	end

	local fall = Config.WallRunFallSpeed + elapsed * 8
	wallVelocity.VectorVelocity = wallTangent * Config.WallRunSpeed - wallNormal * 1 - Vector3.new(0, fall, 0)
end

-- Salto desde la pared
UserInputService.JumpRequest:Connect(function()
	if not wallRunning then
		return
	end
	stopWallRun()
	root.AssemblyLinearVelocity = wallNormal * Config.WallJumpOutForce
		+ Vector3.new(0, Config.WallJumpUpForce, 0)
		+ wallTangent * Config.WallRunSpeed * 0.8
	humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	character:SetAttribute("WallJumpTick", (character:GetAttribute("WallJumpTick") or 0) + 1)
end)

-- Bucle principal ------------------------------------------------------------

local connection = RunService.Heartbeat:Connect(function(dt)
	-- Congelado durante la cuenta atrás
	if player:GetAttribute("Frozen") then
		stopWallRun()
		slideEndTime = 0
		currentSpeed = Config.BaseWalkSpeed
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.CameraOffset = Vector3.zero
		setParkourState("None")
		return
	end
	humanoid.JumpPower = Config.JumpPower

	-- En la tirolina manda el script de obstáculos
	if character:GetAttribute("Riding") then
		stopWallRun()
		setParkourState("None")
		return
	end

	local now = os.clock()
	local moving = humanoid.MoveDirection.Magnitude > 0.1

	-- Momentum: acelera corriendo en el suelo, se pierde al pararse
	if not moving then
		currentSpeed = Config.BaseWalkSpeed
	elseif isGrounded() then
		currentSpeed = math.min(currentSpeed + Config.Acceleration * dt, Config.MaxWalkSpeed)
	end

	if wallRunning then
		updateWallRun()
	else
		tryStartWallRun()
	end

	-- Velocidad final según la acción actual
	if wallRunning then
		humanoid.WalkSpeed = Config.WallRunSpeed
		setParkourState("WallRun")
	elseif now < slideEndTime then
		local remaining = (slideEndTime - now) / Config.SlideDuration
		humanoid.WalkSpeed = currentSpeed + Config.SlideBoost * remaining
		setParkourState("Slide")
	else
		humanoid.WalkSpeed = currentSpeed
		setParkourState("None")
		if humanoid.CameraOffset ~= Vector3.zero then
			humanoid.CameraOffset = Vector3.zero
		end
	end

	-- FOV según la velocidad
	local speedAlpha = math.clamp(
		(horizontalSpeed() - Config.BaseWalkSpeed) / (Config.WallRunSpeed - Config.BaseWalkSpeed),
		0,
		1
	)
	local targetFov = Config.BaseFOV + (Config.MaxFOV - Config.BaseFOV) * speedAlpha
	camera.FieldOfView += (targetFov - camera.FieldOfView) * math.min(dt * 6, 1)
end)

-- Inclinar la cámara durante el wall run (después de que la cámara se actualice)
pcall(RunService.UnbindFromRenderStep, RunService, CAMERA_STEP)
RunService:BindToRenderStep(CAMERA_STEP, Enum.RenderPriority.Camera.Value + 1, function(dt)
	local target = 0
	if wallRunning then
		local side = if wallNormal:Dot(camera.CFrame.RightVector) > 0 then 1 else -1
		target = math.rad(Config.WallRunCameraTilt) * side
	end
	cameraTilt += (target - cameraTilt) * math.min(dt * 10, 1)
	if math.abs(cameraTilt) > 0.001 then
		camera.CFrame *= CFrame.Angles(0, 0, cameraTilt)
	end
end)

-- Cuando el servidor nos teletransporta (checkpoint / reinicio), perdemos la velocidad
local teleportConnection = player:GetAttributeChangedSignal("TeleportTick"):Connect(function()
	stopWallRun()
	slideEndTime = 0
	currentSpeed = Config.BaseWalkSpeed
	root.AssemblyLinearVelocity = Vector3.zero
end)

local function cleanup()
	connection:Disconnect()
	teleportConnection:Disconnect()
	pcall(RunService.UnbindFromRenderStep, RunService, CAMERA_STEP)
	ContextActionService:UnbindAction(SLIDE_ACTION)
	camera.FieldOfView = Config.BaseFOV
end

humanoid.Died:Connect(cleanup)
