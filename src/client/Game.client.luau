-- Becak Rush: the client. The server owns the run; this script reads the
-- player's steering and hops, chases the becak with the camera, and draws
-- everything the player sees: the start screen, the HUD and the game-over
-- screen. HUD text stays clear of the top-left corner, where Roblox puts
-- its own menu buttons.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local SoundManager = require(script.Parent.SoundManager)
local Util = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"))

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera
camera.CameraType = Enum.CameraType.Scriptable

local remotes = ReplicatedStorage:WaitForChild("BecakRushRemotes")
local StartRun = remotes:WaitForChild("StartRun")
local LaneChange = remotes:WaitForChild("LaneChange")
local JumpRequest = remotes:WaitForChild("JumpRequest")
local HudUpdate = remotes:WaitForChild("HudUpdate")
local ToastEvent = remotes:WaitForChild("Toast")
local CountdownEvent = remotes:WaitForChild("Countdown")
local RunOver = remotes:WaitForChild("RunOver")
local Sfx = remotes:WaitForChild("Sfx")
local RainState = remotes:WaitForChild("RainState")
local CrashFlash = remotes:WaitForChild("CrashFlash")

local CREAM = Color3.fromRGB(255, 247, 237)
local ORANGE = Color3.fromRGB(249, 115, 22)
local GOLD = Color3.fromRGB(251, 191, 36)
local RED = Color3.fromRGB(220, 68, 68)
local GREEN = Color3.fromRGB(74, 222, 128)
local PANEL = Color3.fromRGB(17, 24, 39)

-- Latest HUD numbers from the server, for the camera and the labels.
local hud = { state = "lobby", score = 0, coins = 0, distance = 0, speed = 0, hearts = 3, combo = 0, multiplier = 1, passenger = nil, objective = nil, best = 0, raining = false }
local shakeTime = 0
local toastUntil = 0
local countdownHideAt = 0
local uiReady = false -- the interface below is still being built

-- The interface elements live in `ui`; they are assigned when the
-- interface is built further down, and the gameplay code above reads them.
local ui = {}


-- UI helpers ------------------------------------------------------------------
local function roundCorners(instance: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance
end

local function makeFrame(parent: Instance, name: string, size: UDim2, position: UDim2, color: Color3, transparency: number?): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = size
	frame.Position = position
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = transparency or 0
	frame.BorderSizePixel = 0
	frame.Parent = parent
	return frame
end

local function makeLabel(parent: Instance, name: string, text: string, size: UDim2, position: UDim2, textSize: number, color: Color3, font: Enum.Font?): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Text = text
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.TextColor3 = color
	label.TextSize = textSize
	label.Font = font or Enum.Font.GothamBold
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = parent
	return label
end

local function makeButton(parent: Instance, name: string, text: string, size: UDim2, position: UDim2, textSize: number): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Text = text
	button.Size = size
	button.Position = position
	button.BackgroundColor3 = ORANGE
	button.TextColor3 = CREAM
	button.TextSize = textSize
	button.Font = Enum.Font.GothamBold
	button.AutoButtonColor = true
	button.Parent = parent
	roundCorners(button, 12)
	return button
end

local function touchButton(name: string, text: string, position: UDim2): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Text = text
	button.Size = UDim2.fromOffset(96, 96)
	button.Position = position
	button.AnchorPoint = Vector2.new(0.5, 1)
	button.BackgroundColor3 = PANEL
	button.BackgroundTransparency = 0.3
	button.TextColor3 = CREAM
	button.TextSize = 44
	button.Font = Enum.Font.GothamBold
	button.Parent = ui.touchFrame
	roundCorners(button, 48)
	return button
end

-- Showing things ------------------------------------------------------------------
local function showToast(text: string, seconds: number)
	if not uiReady then
		return
	end
	ui.toastLabel.Text = text
	ui.toastLabel.Visible = true
	toastUntil = os.clock() + seconds
end

-- Draw one HUD snapshot from the server.
local function applyHud(data: any)
	for key, value in data do
		hud[key] = value
	end
	if not uiReady then
		return -- the interface is still loading; the next snapshot draws it
	end
	ui.heartsLabel.Text = string.rep("♥", hud.hearts) .. string.rep("♡", math.max(0, 3 - hud.hearts))
	ui.scoreLabel.Text = "SKOR " .. Util.formatNumber(hud.score)
	ui.coinsLabel.Text = "Koin " .. Util.formatNumber(hud.coins)
	ui.distanceLabel.Text = Util.formatDistance(hud.distance)
	ui.speedLabel.Text = tostring(hud.speed) .. " km/h"
	if hud.state == "playing" or hud.state == "countdown" then
		ui.hudFrame.Visible = true
		ui.startScreen.Visible = false
		ui.overScreen.Visible = false
	end
	if hud.passenger then
		ui.passengerLabel.Visible = true
		if hud.objective then
			ui.passengerLabel.Text = "Antar " .. hud.passenger .. " — " .. Util.formatDistance(hud.objective)
		else
			ui.passengerLabel.Text = hud.passenger .. " naik becakmu!"
		end
	elseif hud.state == "playing" then
		ui.passengerLabel.Visible = true
		ui.passengerLabel.Text = "Cari penumpang..."
	else
		ui.passengerLabel.Visible = false
	end
	if hud.multiplier > 1 then
		ui.comboLabel.Visible = true
		ui.comboLabel.Text = "KOMBO x" .. tostring(hud.multiplier)
	else
		ui.comboLabel.Visible = false
	end
	ui.rainLabel.Visible = hud.raining
	if hud.best > 0 then
		ui.bestLabel.Text = "Skor terbaikmu: " .. Util.formatNumber(hud.best)
	end
end

-- Server events ------------------------------------------------------------------
HudUpdate.OnClientEvent:Connect(applyHud)

ToastEvent.OnClientEvent:Connect(function(text: string, seconds: number)
	showToast(text, seconds or 2)
end)

CountdownEvent.OnClientEvent:Connect(function(value: number)
	if not uiReady then
		return
	end
	if value > 0 then
		ui.countdownLabel.Text = tostring(value)
		ui.countdownLabel.Visible = true
		countdownHideAt = 0
	else
		ui.countdownLabel.Text = "GAS!"
		ui.countdownLabel.Visible = true
		countdownHideAt = os.clock() + 0.8
	end
end)

RunOver.OnClientEvent:Connect(function(stats: any)
	if not uiReady then
		return
	end
	ui.overScreen.Visible = true
	ui.hudFrame.Visible = false
	ui.passengerLabel.Visible = false
	ui.comboLabel.Visible = false
	ui.overReason.Text = if stats.reason == "crash" then "Becakmu ringsek! Tiga tabrakan, tamat." else "Perjalanan selesai."
	ui.overStats.Text = "Skor: " .. Util.formatNumber(stats.score) .. "   •   Jarak: " .. Util.formatDistance(stats.distance)
		.. "\nKoin: " .. Util.formatNumber(stats.coins) .. "   •   Penumpang diantar: " .. tostring(stats.deliveries)
		.. "   •   Waktu: " .. Util.formatTime(stats.time)
	ui.overBest.Text = (if stats.isBest then "★ REKOR BARU! " else "") .. "Skor terbaikmu: " .. Util.formatNumber(stats.best)
	local lines = { "— TOP 5 SERVER INI —" }
	for i, entry in stats.top do
		table.insert(lines, tostring(i) .. ". " .. entry.name .. " — " .. Util.formatNumber(entry.score))
	end
	ui.topLabel.Text = table.concat(lines, "\n")
end)

Sfx.OnClientEvent:Connect(function(name: string)
	if name == "deliver" then
		SoundManager.playDeliver()
	else
		SoundManager.play(name)
	end
end)

RainState.OnClientEvent:Connect(function(isRaining: boolean)
	hud.raining = isRaining
	if uiReady then
		ui.rainLabel.Visible = isRaining
	end
end)

CrashFlash.OnClientEvent:Connect(function()
	if not uiReady then
		return
	end
	ui.flashFrame.Visible = true
	ui.flashFrame.BackgroundTransparency = 0.45
	shakeTime = 0.45
end)

-- Steering and hopping ------------------------------------------------------------
local function steerAction(actionName: string, inputState: Enum.UserInputState)
	if inputState ~= Enum.UserInputState.Begin then
		return
	end
	if actionName == "SteerLeft" then
		LaneChange:FireServer(-1)
	elseif actionName == "SteerRight" then
		LaneChange:FireServer(1)
	elseif actionName == "Jump" then
		JumpRequest:FireServer()
	end
end

ContextActionService:BindAction("SteerLeft", steerAction, false, Enum.KeyCode.Left, Enum.KeyCode.A)
ContextActionService:BindAction("SteerRight", steerAction, false, Enum.KeyCode.Right, Enum.KeyCode.D)
ContextActionService:BindAction("Jump", steerAction, false, Enum.KeyCode.Space, Enum.KeyCode.W, Enum.KeyCode.Up)

-- Camera ---------------------------------------------------------------------------
local function findBecak(): Part?
	local becaks = Workspace:FindFirstChild("Becaks")
	if not becaks then
		return nil
	end
	local model = becaks:FindFirstChild("Becak_" .. player.Name) :: Model?
	if model then
		return model.PrimaryPart
	end
	return nil
end

-- One frame: hide timed messages, then chase the becak with the camera.
local function updateCamera(dt: number)
	if ui.toastLabel.Visible and os.clock() > toastUntil then
		ui.toastLabel.Visible = false
	end
	if ui.countdownLabel.Visible and countdownHideAt > 0 and os.clock() > countdownHideAt then
		ui.countdownLabel.Visible = false
	end
	if ui.flashFrame.Visible then
		local transparency = ui.flashFrame.BackgroundTransparency + dt * 1.8
		if transparency >= 1 then
			ui.flashFrame.Visible = false
		else
			ui.flashFrame.BackgroundTransparency = transparency
		end
	end
	if shakeTime > 0 then
		shakeTime -= dt
	end
	local becakPart = findBecak()
	if becakPart then
		local pos = becakPart.Position
		local shake = Vector3.new(0, 0, 0)
		if shakeTime > 0 then
			shake = Vector3.new((math.random() - 0.5) * 1.2, (math.random() - 0.5) * 1.2, 0)
		end
		-- Chase cam: behind and above the becak, looking down the street.
		camera.CFrame = CFrame.lookAt(pos + Vector3.new(0, 9.5, 17) + shake, pos + Vector3.new(0, 2, -16))
		camera.FieldOfView = 70 + math.clamp(hud.speed / 120, 0, 1) * 10
	else
		-- No becak yet (waiting for a track): a calm view down the street.
		camera.CFrame = CFrame.lookAt(Vector3.new(0, 18, 42), Vector3.new(0, 2, -40))
		camera.FieldOfView = 70
	end
end

-- The whole interface ----------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "BecakRushGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

-- HUD (top-right: clear of Roblox's own top-left buttons)
ui.hudFrame = makeFrame(gui, "Hud", UDim2.fromOffset(280, 132), UDim2.new(1, -16, 0, 16), PANEL, 0.25)
ui.hudFrame.AnchorPoint = Vector2.new(1, 0)
ui.hudFrame.Visible = false
roundCorners(ui.hudFrame, 12)
ui.heartsLabel = makeLabel(ui.hudFrame, "Hearts", "♥♥♥", UDim2.new(1, -16, 0, 32), UDim2.new(0, 8, 0, 6), 26, RED)
ui.heartsLabel.TextXAlignment = Enum.TextXAlignment.Right
ui.scoreLabel = makeLabel(ui.hudFrame, "Score", "SKOR 0", UDim2.new(1, -16, 0, 30), UDim2.new(0, 8, 0, 38), 24, CREAM)
ui.scoreLabel.TextXAlignment = Enum.TextXAlignment.Right
ui.coinsLabel = makeLabel(ui.hudFrame, "Coins", "Koin 0", UDim2.new(0.5, -8, 0, 26), UDim2.new(0, 8, 0, 70), 20, GOLD)
ui.coinsLabel.TextXAlignment = Enum.TextXAlignment.Left
ui.distanceLabel = makeLabel(ui.hudFrame, "Distance", "0 m", UDim2.new(0.5, -8, 0, 26), UDim2.new(0.5, 0, 0, 70), 20, CREAM)
ui.distanceLabel.TextXAlignment = Enum.TextXAlignment.Right
ui.speedLabel = makeLabel(ui.hudFrame, "Speed", "0 km/h", UDim2.new(1, -16, 0, 26), UDim2.new(0, 8, 0, 98), 20, Color3.fromRGB(147, 197, 253))
ui.speedLabel.TextXAlignment = Enum.TextXAlignment.Right

-- Passenger banner (top-centre), combo badge and rain warning
ui.passengerLabel = makeLabel(gui, "Passenger", "", UDim2.fromOffset(420, 40), UDim2.new(0.5, -210, 0, 16), 22, GREEN)
ui.passengerLabel.BackgroundColor3 = PANEL
ui.passengerLabel.BackgroundTransparency = 0.25
ui.passengerLabel.Visible = false
roundCorners(ui.passengerLabel, 10)
ui.comboLabel = makeLabel(gui, "Combo", "", UDim2.fromOffset(180, 40), UDim2.new(0.5, -90, 0, 62), 22, GOLD)
ui.comboLabel.BackgroundColor3 = PANEL
ui.comboLabel.BackgroundTransparency = 0.25
ui.comboLabel.Visible = false
roundCorners(ui.comboLabel, 10)
ui.rainLabel = makeLabel(gui, "Rain", "HUJAN DERAS — awas genangan!", UDim2.fromOffset(360, 36), UDim2.new(0.5, -180, 0, 108), 20, Color3.fromRGB(147, 197, 253))
ui.rainLabel.BackgroundColor3 = PANEL
ui.rainLabel.BackgroundTransparency = 0.25
ui.rainLabel.Visible = false
roundCorners(ui.rainLabel, 10)

-- Toast (centre), countdown (huge, centre) and the red crash flash
ui.toastLabel = makeLabel(gui, "Toast", "", UDim2.fromOffset(640, 48), UDim2.new(0.5, -320, 0, 0.3), 28, CREAM)
ui.toastLabel.BackgroundColor3 = PANEL
ui.toastLabel.BackgroundTransparency = 0.2
ui.toastLabel.Visible = false
roundCorners(ui.toastLabel, 10)
ui.countdownLabel = makeLabel(gui, "Countdown", "", UDim2.fromOffset(300, 200), UDim2.new(0.5, -150, 0, 0.35), 120, ORANGE, Enum.Font.FredokaOne)
ui.countdownLabel.Visible = false
ui.flashFrame = makeFrame(gui, "CrashFlash", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), RED, 1)
ui.flashFrame.Visible = false

-- Start screen
ui.startScreen = makeFrame(gui, "StartScreen", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), Color3.fromRGB(10, 40, 44), 0.25)
makeLabel(ui.startScreen, "Title", "BECAK RUSH", UDim2.new(1, 0, 0, 90), UDim2.new(0, 0, 0.12, 0), 84, ORANGE, Enum.Font.FredokaOne)
makeLabel(ui.startScreen, "Subtitle", "Jakarta Delivery Dash — kayuh becakmu, antar penumpang, kalahkan macet!", UDim2.new(1, 0, 0, 36), UDim2.new(0, 0, 0.12, 96), 26, CREAM)
local howLabel = makeLabel(ui.startScreen, "HowTo",
	"◀ ▶  atau  A / D — pindah jalur      SPACE — lompat lubang\nAntar penumpang ke bendera emas  •  Kumpulkan koin  •  Jangan tabrak mobil!\n3 nyawa. Hujan bikin jalan licin. Kombo menaikkan skor sampai x5.",
	UDim2.new(0.8, 0, 0, 110), UDim2.new(0.1, 0, 0.42, 0), 22, CREAM)
howLabel.TextWrapped = true
ui.playButton = makeButton(ui.startScreen, "PlayButton", "▶  MAIN", UDim2.fromOffset(280, 72), UDim2.new(0.5, -140, 0.62, 0), 32)
ui.bestLabel = makeLabel(ui.startScreen, "Best", "", UDim2.new(1, 0, 0, 30), UDim2.new(0, 0, 0.62, 84), 20, GOLD)
makeLabel(ui.startScreen, "Credit", "Dibuat untuk make.fun — bounty Roblox Game  •  Becak Rush v1.0", UDim2.new(1, 0, 0, 26), UDim2.new(0, 0, 1, -36), 16, Color3.fromRGB(200, 210, 210))

-- Game-over screen
ui.overScreen = makeFrame(gui, "GameOverScreen", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), Color3.fromRGB(10, 20, 24), 0.35)
ui.overScreen.Visible = false
makeLabel(ui.overScreen, "OverTitle", "GAME OVER", UDim2.new(1, 0, 0, 80), UDim2.new(0, 0, 0.08, 0), 72, ORANGE, Enum.Font.FredokaOne)
ui.overReason = makeLabel(ui.overScreen, "Reason", "", UDim2.new(1, 0, 0, 32), UDim2.new(0, 0, 0.08, 84), 24, CREAM)
ui.overStats = makeLabel(ui.overScreen, "Stats", "", UDim2.new(0.8, 0, 0, 130), UDim2.new(0.1, 0, 0.26, 0), 24, CREAM)
ui.overStats.TextWrapped = true
ui.overBest = makeLabel(ui.overScreen, "Best", "", UDim2.new(1, 0, 0, 32), UDim2.new(0, 0, 0.26, 132), 22, GOLD)
ui.topLabel = makeLabel(ui.overScreen, "Top", "", UDim2.new(0.8, 0, 0, 150), UDim2.new(0.1, 0, 0.52, 0), 20, CREAM)
ui.topLabel.TextWrapped = true
ui.againButton = makeButton(ui.overScreen, "AgainButton", "↻  MAIN LAGI", UDim2.fromOffset(280, 72), UDim2.new(0.5, -140, 0.78, 0), 30)

-- Touch controls (only shown on touch devices)
ui.touchFrame = Instance.new("Frame")
ui.touchFrame.Name = "TouchControls"
ui.touchFrame.Size = UDim2.fromScale(1, 1)
ui.touchFrame.BackgroundTransparency = 1
ui.touchFrame.Visible = UserInputService.TouchEnabled
ui.touchFrame.Parent = gui
ui.leftButton = touchButton("Left", "◀", UDim2.new(0.12, 0, 1, -24))
ui.rightButton = touchButton("Right", "▶", UDim2.new(0.28, 0, 1, -24))
ui.jumpButton = touchButton("Jump", "▲", UDim2.new(0.88, 0, 1, -24))

uiReady = true

-- Buttons and the camera --------------------------------------------------------
ui.playButton.MouseButton1Click:Connect(function()
	SoundManager.play("click")
	StartRun:FireServer()
end)
ui.againButton.MouseButton1Click:Connect(function()
	SoundManager.play("click")
	StartRun:FireServer()
end)
ui.leftButton.MouseButton1Down:Connect(function()
	LaneChange:FireServer(-1)
end)
ui.rightButton.MouseButton1Down:Connect(function()
	LaneChange:FireServer(1)
end)
ui.jumpButton.MouseButton1Down:Connect(function()
	JumpRequest:FireServer()
end)

RunService.RenderStepped:Connect(updateCamera)
