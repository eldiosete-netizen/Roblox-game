-- Arranque del cliente: pone en marcha la interfaz y los sistemas locales.

local Client = script.Parent

local HUD = require(Client:WaitForChild("HUD"))
local MapMenu = require(Client:WaitForChild("MapMenu"))
local LiveRaceUI = require(Client:WaitForChild("LiveRaceUI"))
local ShopMenu = require(Client:WaitForChild("ShopMenu"))
local SettingsMenu = require(Client:WaitForChild("SettingsMenu"))
local RankingsMenu = require(Client:WaitForChild("RankingsMenu"))
local StartMenu = require(Client:WaitForChild("StartMenu"))
local Obstacles = require(Client:WaitForChild("Obstacles"))
local Ghost = require(Client:WaitForChild("Ghost"))

HUD.start()
MapMenu.start()
LiveRaceUI.start()
ShopMenu.start()
RankingsMenu.start()
SettingsMenu.start()
StartMenu.start()
Obstacles.start()
Ghost.start()

-- El servidor puede pedir abrir un menú (p. ej. al tocar un portal bloqueado)
local Remotes = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Remotes"))
local UI = require(Client:WaitForChild("UI"))
Remotes.OpenMenu.OnClientEvent:Connect(function(panel: string)
	if typeof(panel) == "string" then
		UI.open(panel)
	end
end)
