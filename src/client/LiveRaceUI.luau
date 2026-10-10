-- Interfaz de la carrera en vivo: banner con el estado y botón para unirse.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local HUD = require(script.Parent:WaitForChild("HUD"))
local MapMenu = require(script.Parent:WaitForChild("MapMenu"))
local UI = require(script.Parent:WaitForChild("UI"))

local LiveRaceUI = {}

local PURPLE = Color3.fromRGB(150, 70, 255)
local PLACES = { "1º", "2º", "3º" }

local banner: Frame
local bannerLabel: TextLabel
local joinButton: TextButton
local inQueue = false

local function setQueued(join: boolean)
	local ok, message = Remotes.SetLiveRaceQueue:InvokeServer(join)
	if message then
		HUD.popup(message, if ok then PURPLE else UI.Colors.Bad)
	end
end

local function standings(results: { { name: string, time: number } }, limit: number): string
	local parts = {}
	for i = 1, math.min(limit, #results) do
		local entry = results[i]
		table.insert(parts, string.format("%s %s %s", PLACES[i] or (i .. "º"), entry.name, Config.FormatTime(entry.time)))
	end
	return table.concat(parts, "   ·   ")
end

local function onUpdate(status: { [string]: any })
	local phase = status.phase
	inQueue = phase ~= "none" and phase ~= "results"
	joinButton.Text = if inQueue then "🏁 Salir de la carrera" else "🏁 Carrera en vivo"
	banner.Visible = phase ~= "none"

	if phase == "waiting" then
		bannerLabel.Text = string.format("🏁 Carrera en vivo · Esperando jugadores (%d/%d)", status.queued, status.needed)
	elseif phase == "intermission" then
		bannerLabel.Text = string.format("🏁 La carrera empieza en %d s · %d jugadores", status.timeLeft, status.queued)
	elseif phase == "racing" then
		local text = string.format("🏁 %s · Quedan %d s", status.map or "", status.timeLeft)
		if #status.results > 0 then
			text ..= "   ·   " .. standings(status.results, 3)
		end
		bannerLabel.Text = text
	elseif phase == "results" then
		bannerLabel.Text = "🏁 Resultados: " .. (if #status.results > 0 then standings(status.results, 3) else "nadie terminó")
		HUD.popup("¡Carrera terminada!", PURPLE, standings(status.results, 3))
		task.delay(8, function()
			if not inQueue then
				banner.Visible = false
			end
		end)
	end
end

function LiveRaceUI.start()
	banner = UI.new("Frame", {
		Name = "LiveRace",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.fromOffset(760, 34),
		BackgroundColor3 = PURPLE,
		BackgroundTransparency = 0.25,
		Visible = false,
	}, HUD.gui)
	UI.corner(banner, 8)
	UI.autoScale(banner, 0.5)

	bannerLabel = UI.label(banner, {
		Position = UDim2.fromOffset(12, 4),
		Size = UDim2.new(1, -24, 1, -8),
		Text = "",
	})

	joinButton = MapMenu.addHeaderButton("🏁 Carrera en vivo", 2, PURPLE, function()
		setQueued(not inQueue)
	end)

	Remotes.LiveRaceUpdate.OnClientEvent:Connect(onUpdate)
end

return LiveRaceUI
