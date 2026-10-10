-- Niveles que se desbloquean con monedas (atributo Price de cada mapa).
-- El tutorial y los mapas gratis están siempre abiertos; el mapa VIP se abre
-- con el pase VIP (ver Passes), no con monedas.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local Economy = require(script.Parent:WaitForChild("Economy"))
local Maps = require(script.Parent:WaitForChild("Maps"))
local PlayerData = require(script.Parent:WaitForChild("PlayerData"))
local RaceService = require(script.Parent:WaitForChild("RaceService"))

local MapUnlocks = {}

function MapUnlocks.isUnlocked(player: Player, map: Maps.MapInfo): boolean
	if map.tutorial or map.vip or map.price <= 0 then
		return true
	end
	local data = PlayerData.get(player)
	return data ~= nil and data.unlockedMaps[map.id] == true
end

local function unlock(player: Player, mapId: any): (boolean, string?)
	local map = typeof(mapId) == "string" and Maps.get(mapId)
	local data = PlayerData.get(player)
	if not map or not data then
		return false, "Nivel no válido"
	end
	if map.vip then
		return false, "⭐ Este nivel se desbloquea con el pase VIP"
	end
	if MapUnlocks.isUnlocked(player, map) then
		return false, "Ya tienes este nivel"
	end
	if data.coins < map.price then
		return false, string.format("Te faltan %d monedas", map.price - data.coins)
	end
	if not Economy.spend(player, map.price) then
		return false, "No tienes suficientes monedas"
	end
	data.unlockedMaps[map.id] = true
	PlayerData.sync(player)
	return true, string.format("🔓 ¡%s desbloqueado!", map.name)
end

function MapUnlocks.init()
	Remotes.UnlockMap.OnServerInvoke = unlock

	RaceService.addEnterCheck(function(player, map)
		if MapUnlocks.isUnlocked(player, map) then
			return true, nil
		end
		return false, string.format("🔒 %s cuesta %d monedas: desbloquéalo en el menú de Mapas", map.name, map.price)
	end)
end

return MapUnlocks
