-- Arranque del cliente: pone en marcha la interfaz y los sistemas locales.

local Client = script.Parent

local HUD = require(Client:WaitForChild("HUD"))
local MapMenu = require(Client:WaitForChild("MapMenu"))
local Obstacles = require(Client:WaitForChild("Obstacles"))
local Ghost = require(Client:WaitForChild("Ghost"))
local LiveRaceUI = require(Client:WaitForChild("LiveRaceUI"))
local ShopMenu = require(Client:WaitForChild("ShopMenu"))

HUD.start()
MapMenu.start()
LiveRaceUI.start()
ShopMenu.start()
Obstacles.start()
Ghost.start()
