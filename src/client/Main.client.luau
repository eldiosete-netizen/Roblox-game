-- Arranque del cliente: pone en marcha la interfaz y los sistemas locales.

local Client = script.Parent

local HUD = require(Client:WaitForChild("HUD"))
local MapMenu = require(Client:WaitForChild("MapMenu"))
local Obstacles = require(Client:WaitForChild("Obstacles"))

HUD.start()
MapMenu.start()
Obstacles.start()
