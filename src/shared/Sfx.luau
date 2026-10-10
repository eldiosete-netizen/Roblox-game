-- Reproduce sonidos 2D en el cliente (solo los oye el jugador local).

local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")

local Config = require(script.Parent:WaitForChild("Config"))

local Sfx = {}

function Sfx.create(name: string, volume: number?): Sound?
	local id = Config.Sounds[name]
	if not id or id == "" then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = id
	sound.Volume = volume or 0.6
	sound.Parent = SoundService
	return sound
end

function Sfx.play(name: string, playbackSpeed: number?, volume: number?)
	local sound = Sfx.create(name, volume)
	if not sound then
		return
	end
	sound.PlaybackSpeed = playbackSpeed or 1
	sound:Play()
	Debris:AddItem(sound, 10)
end

return Sfx
