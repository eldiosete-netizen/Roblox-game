-- Monedas, XP y niveles: recompensas al terminar mapas y carreras en vivo.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local PlayerData = require(script.Parent:WaitForChild("PlayerData"))
local RaceService = require(script.Parent:WaitForChild("RaceService"))
local LiveRace = require(script.Parent:WaitForChild("LiveRace"))

local Economy = {}

local LEVEL_COLOR = Color3.fromRGB(0, 230, 120)

-- Da monedas y XP. Si se pasa "rewards", anota lo ganado para mostrarlo al jugador.
function Economy.give(player: Player, coins: number, xp: number, rewards: { [string]: any }?)
	local data = PlayerData.get(player)
	if not data then
		return
	end
	local session = PlayerData.session(player)
	local multiplier = (session.coinMultiplier or 1) * (if session.vip then Config.VipCoinMultiplier else 1)
	coins = math.floor(coins * multiplier)

	local oldLevel = Config.LevelFromXP(data.xp)
	data.coins += coins
	data.xp += xp
	local newLevel = Config.LevelFromXP(data.xp)

	if rewards then
		rewards.coins = (rewards.coins or 0) + coins
		rewards.xp = (rewards.xp or 0) + xp
	end
	if newLevel > oldLevel then
		if rewards then
			rewards.levelUp = newLevel
		end
		task.delay(2.5, function()
			Remotes.Notify:FireClient(player, string.format("⬆ ¡Nivel %d!", newLevel), LEVEL_COLOR)
		end)
	end
	PlayerData.sync(player)
end

-- Gasta monedas. Devuelve false si no hay suficientes.
function Economy.spend(player: Player, amount: number): boolean
	local data = PlayerData.get(player)
	if not data or data.coins < amount then
		return false
	end
	data.coins -= amount
	PlayerData.sync(player)
	return true
end

function Economy.init()
	local rewards = Config.Rewards

	RaceService.onFinish(function(player, map, result)
		local data = PlayerData.get(player)
		if not data then
			return
		end
		local coins, xp = 0, rewards.FinishXP

		if map.tutorial then
			if not data.tutorialDone then
				data.tutorialDone = true
				coins += rewards.TutorialCoins
			end
		else
			coins += rewards.FinishCoins
			if result.previousBest == nil then
				coins += rewards.FirstFinishCoins
			elseif result.isRecord then
				coins += rewards.RecordCoins
				xp += rewards.RecordXP
			end
			-- Medallas nuevas (solo se cobran la primera vez)
			for rank = result.previousMedal + 1, result.medal do
				coins += rewards.MedalCoins[rank] or 0
			end
			xp += result.medal * rewards.MedalXP
			-- Los mapas más difíciles dan más monedas
			coins = math.floor(coins * map.reward + 0.5)
		end

		Economy.give(player, coins, xp, result.rewards)
	end)

	LiveRace.onRaceEnd(function(player, place, _total)
		local coins = if place then rewards.LivePlaceCoins[place] or rewards.LiveParticipationCoins else rewards.LiveParticipationCoins
		Economy.give(player, coins, rewards.LiveXP)
		Remotes.Notify:FireClient(
			player,
			string.format("🏁 Carrera en vivo: %s  ·  +%d monedas", if place then place .. "º puesto" else "sin terminar", coins)
		)
	end)
end

return Economy
