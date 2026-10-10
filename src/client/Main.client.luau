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
