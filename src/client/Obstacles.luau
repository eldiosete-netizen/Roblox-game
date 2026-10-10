-- Obstáculos especiales (los simula cada cliente para que vayan suaves):
--   MovingPlatform: se mueve con el tiempo del servidor y te lleva encima
--   Trampoline: te lanza hacia arriba
--   Zipline: salta hacia el cable para engancharte; Espacio para soltarte
--   LowGravity: dentro de la zona la gravedad es menor
--   Spinner: modelo decorativo que gira y flota (atributo SpinSpeed en grados/s)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Sfx = require(Shared:WaitForChild("Sfx"))

local player = Players.LocalPlayer

local Obstacles = {}

-- Personaje actual
local character: Model? = nil
local humanoid: Humanoid? = nil
local root: BasePart? = nil
local gravityForce: VectorForce? = nil
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

-- Plataformas móviles ------------------------------------------------------------------

type Platform = { base: CFrame, offset: Vector3, period: number, phase: number }
local platforms: { [BasePart]: Platform } = {}

local function addPlatform(part: Instance)
	if not part:IsA("BasePart") then
		return
	end
	platforms[part] = {
		base = part.CFrame,
		offset = part:GetAttribute("Offset") or Vector3.zero,
		period = part:GetAttribute("Period") or 3,
		phase = part:GetAttribute("Phase") or 0,
	}
end

local function updatePlatforms()
	local now = workspace:GetServerTimeNow()
	local standingOn: Instance? = nil
	if root and humanoid and humanoid.FloorMaterial ~= Enum.Material.Air then
		local hit = workspace:Raycast(root.Position, Vector3.new(0, -6, 0), rayParams)
		standingOn = hit and hit.Instance
	end

	for part, platform in platforms do
		local alpha = math.sin((now / platform.period + platform.phase) * math.pi * 2)
		local target = platform.base + platform.offset * alpha
		local delta = target.Position - part.Position
		part.CFrame = target
		if part == standingOn and root then
			root.CFrame += delta -- te lleva con ella
		end
	end
end

-- Trampolines --------------------------------------------------------------------------

local lastBounce = 0

local function addTrampoline(part: Instance)
	if not part:IsA("BasePart") then
		return
	end
	part.Touched:Connect(function(hit)
		if not character or not root or not humanoid or not hit:IsDescendantOf(character) then
			return
		end
		local now = os.clock()
		if now - lastBounce < 0.3 then
			return
		end
		lastBounce = now
		local velocity = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(velocity.X, part:GetAttribute("Power") or Config.TrampolinePower, velocity.Z)
		humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
		Sfx.play("Bounce", 0.8, 0.6)
	end)
end

-- Tirolinas ------------------------------------------------------------------------------

type Zipline = { a: Vector3, b: Vector3, direction: Vector3, length: number }
local ziplines: { [BasePart]: Zipline } = {}

type Ride = { zipline: Zipline, distance: number, speed: number }
local riding: Ride? = nil
local rideCooldown = 0

local HANG_OFFSET = Vector3.new(0, 3.5, 0) -- las manos están por encima del centro del personaje

local function addZipline(part: Instance)
	if not part:IsA("BasePart") then
		return
	end
	local a = part:GetAttribute("A")
	local b = part:GetAttribute("B")
	if typeof(a) ~= "Vector3" or typeof(b) ~= "Vector3" then
		return
	end
	ziplines[part] = { a = a, b = b, direction = (b - a).Unit, length = (b - a).Magnitude }
end

local function stopRide(jump: boolean)
	local ride = riding
	if not ride then
		return
	end
	riding = nil
	rideCooldown = os.clock() + 0.5
	if character then
		character:SetAttribute("Riding", false)
	end
	if humanoid and root then
		humanoid.PlatformStand = false
		local up = if jump then Config.JumpPower * 0.8 else 0
		root.AssemblyLinearVelocity = ride.zipline.direction * ride.speed + Vector3.new(0, up, 0)
		humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	end
end

local function tryGrab()
	if not root or not humanoid or humanoid.FloorMaterial ~= Enum.Material.Air or os.clock() < rideCooldown then
		return
	end
	local hands = root.Position + HANG_OFFSET
	for _, zipline in ziplines do
		local t = math.clamp((hands - zipline.a):Dot(zipline.direction), 0, zipline.length)
		if t < zipline.length * 0.85 then
			local closest = zipline.a + zipline.direction * t
			if (hands - closest).Magnitude < Config.ZiplineGrabDistance then
				local velocity = root.AssemblyLinearVelocity
				riding = {
					zipline = zipline,
					distance = t,
					speed = math.max(Vector3.new(velocity.X, 0, velocity.Z).Magnitude, Config.ZiplineMinSpeed),
				}
				humanoid.PlatformStand = true
				if character then
					character:SetAttribute("Riding", true)
				end
				return
			end
		end
	end
end

local function updateRide(dt: number)
	local ride = riding
	if not ride or not root then
		return
	end
	local zipline = ride.zipline
	-- Acelera con la pendiente
	local slope = -zipline.direction.Y
	ride.speed = math.min(ride.speed + (workspace.Gravity * slope + 8) * dt, Config.ZiplineMaxSpeed)
	ride.distance += ride.speed * dt
	if ride.distance >= zipline.length then
		stopRide(false)
		return
	end
	local point = zipline.a + zipline.direction * ride.distance - HANG_OFFSET
	local flat = Vector3.new(zipline.direction.X, 0, zipline.direction.Z)
	root.CFrame = CFrame.lookAt(point, point + flat)
	root.AssemblyLinearVelocity = zipline.direction * ride.speed
end

-- Gravedad baja ----------------------------------------------------------------------------

local zones: { BasePart } = {}

local function addZone(part: Instance)
	if part:IsA("BasePart") then
		table.insert(zones, part)
	end
end

local function updateGravity()
	if not root or not gravityForce then
		return
	end
	local factor = 1
	for _, zone in zones do
		local relative = zone.CFrame:PointToObjectSpace(root.Position)
		local half = zone.Size / 2
		if math.abs(relative.X) <= half.X and math.abs(relative.Y) <= half.Y and math.abs(relative.Z) <= half.Z then
			factor = math.min(factor, zone:GetAttribute("Gravity") or Config.LowGravityFactor)
		end
	end
	if factor < 1 then
		gravityForce.Force = Vector3.new(0, root.AssemblyMass * workspace.Gravity * (1 - factor), 0)
		gravityForce.Enabled = true
	else
		gravityForce.Enabled = false
	end
end

-- Decoración que gira ------------------------------------------------------------------------

local spinners: { [Model]: { base: CFrame, speed: number } } = {}

local function addSpinner(model: Instance)
	if model:IsA("Model") then
		spinners[model] = { base = model:GetPivot(), speed = model:GetAttribute("SpinSpeed") or 30 }
	end
end

local function updateSpinners()
	local now = workspace:GetServerTimeNow()
	for model, spinner in spinners do
		if not model.Parent then
			spinners[model] = nil
			continue
		end
		local angle = math.rad(now * spinner.speed)
		local bob = math.sin(now * 1.5) * 0.6
		model:PivotTo(spinner.base * CFrame.new(0, bob, 0) * CFrame.Angles(angle * 0.3, angle, 0))
	end
end

-- Inicio ---------------------------------------------------------------------------------

local function onCharacter(newCharacter: Model)
	riding = nil
	character = newCharacter
	humanoid = newCharacter:WaitForChild("Humanoid") :: Humanoid
	root = newCharacter:WaitForChild("HumanoidRootPart") :: BasePart
	rayParams.FilterDescendantsInstances = { newCharacter }

	local attachment = Instance.new("Attachment")
	attachment.Name = "GravityAttachment"
	attachment.Parent = root
	local force = Instance.new("VectorForce")
	force.Attachment0 = attachment
	force.RelativeTo = Enum.ActuatorRelativeTo.World
	force.ApplyAtCenterOfMass = true
	force.Enabled = false
	force.Parent = root
	gravityForce = force
end

local function watchTag(tag: string, callback: (Instance) -> ())
	for _, instance in CollectionService:GetTagged(tag) do
		callback(instance)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(callback)
end

function Obstacles.start()
	watchTag("MovingPlatform", addPlatform)
	watchTag("Trampoline", addTrampoline)
	watchTag("Zipline", addZipline)
	watchTag("LowGravity", addZone)
	watchTag("Spinner", addSpinner)
	RunService.RenderStepped:Connect(updateSpinners)

	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	player.CharacterAdded:Connect(onCharacter)

	-- Al teletransportarte (checkpoint, reinicio) te sueltas de la tirolina
	player:GetAttributeChangedSignal("TeleportTick"):Connect(function()
		if riding then
			riding = nil
			rideCooldown = os.clock() + 0.5
			if humanoid then
				humanoid.PlatformStand = false
			end
			if character then
				character:SetAttribute("Riding", false)
			end
		end
	end)

	UserInputService.JumpRequest:Connect(function()
		if riding then
			stopRide(true)
		end
	end)

	RunService.PreSimulation:Connect(function(dt)
		if humanoid and humanoid.Health <= 0 then
			return
		end
		updatePlatforms()
		if riding then
			updateRide(dt)
		else
			tryGrab()
		end
		updateGravity()
	end)
end

return Obstacles
