-- Game Pass: VIP y multiplicadores de monedas (x2, x3, x5, x10).
-- En el juego los multiplicadores se compran en orden; si alguien compra uno
-- más alto desde la web, también funciona (se usa el más alto que tenga).

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local PlayerData = require(script.Parent:WaitForChild("PlayerData"))
local RaceService = require(script.Parent:WaitForChild("RaceService"))
local Shop = require(script.Parent:WaitForChild("Shop"))

local Passes = {}

local GOLD = Color3.fromRGB(255, 205, 40)

-- Todos los pases configurados (id ~= 0) por clave
local function configuredPasses(): { [string]: number }
	local list = {}
	if Config.VipGamePassId ~= 0 then
		list.vip = Config.VipGamePassId
	end
	for _, pass in Config.CoinPasses do
		if pass.id ~= 0 then
			list[pass.key] = pass.id
		end
	end
	return list
end

local function keyForId(passId: number): string?
	for key, id in configuredPasses() do
		if id == passId then
			return key
		end
	end
	return nil
end

-- Recalcula VIP y multiplicador a partir de los pases que tiene el jugador
local function refresh(player: Player)
	local session = PlayerData.session(player)
	local owned = session.ownedPasses or {}
	session.vip = owned.vip == true
	local multiplier = 1
	for _, pass in Config.CoinPasses do
		if owned[pass.key] then
			multiplier = math.max(multiplier, pass.multiplier)
		end
	end
	session.coinMultiplier = multiplier
	player:SetAttribute("Vip", session.vip)
	Shop.applyCosmetics(player)
	PlayerData.sync(player)
end

local function checkOwnership(player: Player)
	local owned = {}
	for key, id in configuredPasses() do
		local ok, result = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, id)
		if ok and result == true then
			owned[key] = true
		end
	end
	PlayerData.session(player).ownedPasses = owned
	refresh(player)
end

-- Devuelve el ID del pase si el jugador puede comprarlo ahora, o un mensaje si no
function Passes.canBuy(player: Player, key: string): (number?, string?)
	local owned = PlayerData.session(player).ownedPasses or {}
	if key == "vip" then
		if Config.VipGamePassId == 0 then
			return nil, "El pase VIP aún no está disponible"
		end
		if owned.vip then
			return nil, "Ya eres VIP"
		end
		return Config.VipGamePassId, nil
	end

	for i, pass in Config.CoinPasses do
		if pass.key == key then
			if pass.id == 0 then
				return nil, "Este pase estará disponible pronto"
			end
			if owned[key] then
				return nil, "Ya tienes este pase"
			end
			local previous = Config.CoinPasses[i - 1]
			if previous and not owned[previous.key] then
				return nil, string.format("Primero compra Monedas x%d", previous.multiplier)
			end
			return pass.id, nil
		end
	end
	return nil, "Pase no válido"
end

function Passes.init()
	PlayerData.onLoaded(function(player)
		checkOwnership(player)
	end)

	PlayerData.addSnapshotField(function(player, snapshot)
		local session = PlayerData.session(player)
		snapshot.vip = session.vip == true
		snapshot.coinMultiplier = session.coinMultiplier or 1
		snapshot.ownedPasses = table.clone(session.ownedPasses or {})
	end)

	Remotes.PromptPass.OnServerEvent:Connect(function(player, key)
		if typeof(key) ~= "string" then
			return
		end
		local passId, message = Passes.canBuy(player, key)
		if passId then
			MarketplaceService:PromptGamePassPurchase(player, passId)
		elseif message then
			Remotes.Notify:FireClient(player, message)
		end
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local key = purchased and keyForId(passId)
		if not key then
			return
		end
		local session = PlayerData.session(player)
		session.ownedPasses = session.ownedPasses or {}
		session.ownedPasses[key] = true
		refresh(player)

		if key == "vip" then
			Remotes.Notify:FireClient(player, "⭐ ¡Ya eres VIP! Gracias por tu apoyo", GOLD)
		else
			Remotes.Notify:FireClient(
				player,
				string.format("🪙 ¡Monedas x%d activado! Gracias por tu apoyo", session.coinMultiplier),
				GOLD
			)
		end
	end)

	-- Mapas solo para VIP
	RaceService.addEnterCheck(function(player, map)
		if map.vip and not Shop.isVip(player) then
			return false, "⭐ Este mapa es solo para VIP"
		end
		return true, nil
	end)
end

return Passes
