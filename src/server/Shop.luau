-- Tienda de cosméticos y efectos visibles para todos (rastro).
-- Los Game Pass (VIP y monedas) están en Passes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog"))
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Economy = require(script.Parent:WaitForChild("Economy"))
local PlayerData = require(script.Parent:WaitForChild("PlayerData"))

local Shop = {}

function Shop.isVip(player: Player): boolean
	return PlayerData.session(player).vip == true
end

local function canUse(player: Player, data: { [string]: any }, item: Catalog.Item): boolean
	if item.vip then
		return Shop.isVip(player)
	end
	return item.price == 0 or data.owned[item.id] == true
end

-- Objeto equipado de un tipo (o el de por defecto si ya no se puede usar)
local function equippedItem(player: Player, data: { [string]: any }, kind: string): Catalog.Item
	local item = Catalog.byId[data.equipped[kind] or ""]
	if item and item.kind == kind and canUse(player, data, item) then
		return item
	end
	return Catalog.byId[Catalog.Defaults[kind]]
end

-- Rastro en el servidor para que lo vean todos los jugadores
local function applyTrail(player: Player, item: Catalog.Item)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local trail = root:FindFirstChild("CosmeticTrail") :: Trail?
	if not trail then
		local top = Instance.new("Attachment")
		top.Name = "TrailTop"
		top.Position = Vector3.new(0, 0.8, 0.4)
		top.Parent = root
		local bottom = Instance.new("Attachment")
		bottom.Name = "TrailBottom"
		bottom.Position = Vector3.new(0, -0.8, 0.4)
		bottom.Parent = root

		local newTrail = Instance.new("Trail")
		newTrail.Name = "CosmeticTrail"
		newTrail.Attachment0 = top
		newTrail.Attachment1 = bottom
		newTrail.Lifetime = 0.35
		newTrail.LightEmission = 1
		newTrail.FaceCamera = true
		newTrail.Transparency = NumberSequence.new(0.3, 1)
		newTrail.WidthScale = NumberSequence.new(1, 0)
		newTrail.Enabled = false
		newTrail.Parent = root
		trail = newTrail
	end
	(trail :: Trail).Color = Catalog.colorSequence(item)
end

function Shop.applyCosmetics(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return
	end
	for _, kind in Catalog.Kinds do
		local item = equippedItem(player, data, kind.id)
		player:SetAttribute(kind.id .. "Item", item.id) -- los clientes leen esto para los efectos
		if kind.id == "Trail" then
			applyTrail(player, item)
		end
	end
end

local function purchase(player: Player, itemId: any): (boolean, string?)
	local data = PlayerData.get(player)
	local item = typeof(itemId) == "string" and Catalog.byId[itemId]
	if not data or not item then
		return false, "Objeto no válido"
	end
	if item.vip then
		return false, "Este objeto es solo para VIP"
	end
	if canUse(player, data, item) then
		return false, "Ya lo tienes"
	end
	if not Economy.spend(player, item.price) then
		return false, "No tienes suficientes monedas"
	end
	data.owned[item.id] = true
	data.equipped[item.kind] = item.id
	Shop.applyCosmetics(player)
	PlayerData.sync(player)
	return true, "¡Comprado y equipado: " .. item.name .. "!"
end

local function equip(player: Player, itemId: any): (boolean, string?)
	local data = PlayerData.get(player)
	local item = typeof(itemId) == "string" and Catalog.byId[itemId]
	if not data or not item then
		return false, "Objeto no válido"
	end
	if not canUse(player, data, item) then
		return false, if item.vip then "Este objeto es solo para VIP" else "Todavía no lo tienes"
	end
	data.equipped[item.kind] = item.id
	Shop.applyCosmetics(player)
	PlayerData.sync(player)
	return true, nil
end

function Shop.init()
	Remotes.Purchase.OnServerInvoke = purchase
	Remotes.Equip.OnServerInvoke = equip

	local function onPlayerAdded(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("HumanoidRootPart")
			Shop.applyCosmetics(player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	-- Enciende el rastro cuando el jugador va rápido
	task.spawn(function()
		while true do
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				local trail = root and root:FindFirstChild("CosmeticTrail") :: Trail?
				if root and trail then
					local velocity = root.AssemblyLinearVelocity
					trail.Enabled = Vector3.new(velocity.X, 0, velocity.Z).Magnitude > Config.TrailSpeed
				end
			end
			task.wait(0.15)
		end
	end)
end

return Shop
