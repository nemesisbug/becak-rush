-- Becak Rush: every sound, from one built-in Roblox sound.

local SoundService = game:GetService("SoundService")

local SoundManager = {}

local PING = "rbxasset://sounds/electronicpingshort.wav" -- ships inside Roblox

local SOUNDS = {
	coin = { speed = 1.7, volume = 0.5 },
	pickup = { speed = 1.2, volume = 0.6 },
	deliver = { speed = 1.0, volume = 0.7 },
	crash = { speed = 0.45, volume = 0.9 },
	jump = { speed = 1.4, volume = 0.4 },
	count = { speed = 1.0, volume = 0.6 },
	go = { speed = 1.9, volume = 0.7 },
	nearMiss = { speed = 1.5, volume = 0.5 },
	splash = { speed = 0.7, volume = 0.6 },
	click = { speed = 1.3, volume = 0.5 },
}

function SoundManager.play(name: string)
	local def = SOUNDS[name]
	if not def then
		return
	end
	pcall(function()
		local sound = Instance.new("Sound")
		sound.SoundId = PING
		sound.PlaybackSpeed = def.speed
		sound.Volume = def.volume
		sound.Parent = SoundService
		sound:Play()
		task.delay(2, function()
			sound:Destroy()
		end)
	end)
end

function SoundManager.playDeliver()
	SoundManager.play("deliver")
	task.delay(0.14, function()
		SoundManager.play("go")
	end)
end

return SoundManager
