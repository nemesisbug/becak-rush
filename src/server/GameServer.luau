-- Becak Rush: the server brain — sessions, scoring, rain, day and night.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local BecakFactory = require(script.Parent.BecakFactory)
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local PassengerManager = require(script.Parent.PassengerManager)
local TrafficManager = require(script.Parent.TrafficManager)
local Util = require(game:GetService("ReplicatedStorage").Shared.Util)
local WorldBuilder = require(script.Parent.WorldBuilder)

local remotes = Instance.new("Folder")
remotes.Name = "BecakRushRemotes"
remotes.Parent = ReplicatedStorage

local R = {} -- every remote, by name
for _, name in { "StartRun", "LaneChange", "JumpRequest", "HudUpdate", "Toast", "Countdown", "RunOver", "Sfx", "RainState", "CrashFlash" } do
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotes
	R[name] = remote
end
local StartRun, LaneChange, JumpRequest, HudUpdate, Toast, Countdown, RunOver, Sfx, RainState, CrashFlash =
	R.StartRun, R.LaneChange, R.JumpRequest, R.HudUpdate, R.Toast, R.Countdown, R.RunOver, R.Sfx, R.RainState, R.CrashFlash

local tracksFolder = Instance.new("Folder")
tracksFolder.Name = "Tracks"
tracksFolder.Parent = Workspace
local becaksFolder = Instance.new("Folder")
becaksFolder.Name = "Becaks"
becaksFolder.Parent = Workspace

local bestStore = nil
do
	local ok, store = pcall(function()
		return DataStoreService:GetDataStore("BecakRushBestV1")
	end)
	if ok then
		bestStore = store
	end
end

local leaderboard = {} -- the server's all-time top 5: { name, score, distance }
local sessions = {} -- [Player] = session
local tracks = {} -- one track record per active player
local nextTrackIndex = 0
local clockTime = Config.DAY_START_HOUR
local raining = false
local rainTimer = Config.RAIN_EVERY_MIN
local rainEndsAt = 0

local function newSession(player: Player, trackRecord: any): any
	return {
		player = player,
		track = trackRecord,
		state = "lobby",
		lane = 2,
		x = 0, -- becak X, easing towards the chosen lane's X
		y = 0, -- current hop height
		jumpT = nil :: number?, -- progress through the current hop, 0..1
		lastJumpAt = 0,
		speed = 0,
		distance = 0,
		score = 0,
		coins = 0,
		deliveries = 0,
		hearts = Config.MAX_HEARTS,
		combo = 0,
		comboTimer = 0,
		multiplier = 1,
		invulnerableUntil = 0,
		slowUntil = 0,
		runId = 0, -- counts restarts, so an old countdown cannot fire late
		best = 0,
		becak = nil :: any,
		rig = nil :: any, -- { part, offset, kind } per becak part
		passengerFigure = nil :: Model?,
		passengerRig = nil :: any,
		wheelSpin = 0,
		bobPhase = 0,
		runStartedAt = 0,
	}
end

local function buildRig(becak: any): any
	local origin = becak.model.PrimaryPart.CFrame
	local rig = {}
	for _, descendant in becak.model:GetDescendants() do
		if descendant:IsA("BasePart") then
			local kind = "body"
			if string.find(descendant.Name, "Wheel") then
				kind = "wheel"
			elseif descendant.Name == "DriverLegL" then
				kind = "legL"
			elseif descendant.Name == "DriverLegR" then
				kind = "legR"
			end
			table.insert(rig, { part = descendant, offset = origin:ToObjectSpace(descendant.CFrame), kind = kind })
		end
	end
	return rig
end

local function poseBecak(session: any, root: CFrame, dt: number)
	if not session.rig then
		return
	end
	session.wheelSpin += session.speed * dt / 0.75
	session.bobPhase += dt * (6 + session.speed * 0.25)
	local bob = math.sin(session.bobPhase) * 0.06
	local pedal = math.sin(session.bobPhase * 0.5)
	for _, entry in session.rig do
		local cf = root * entry.offset
		local spin = if entry.kind == "wheel"
			then session.wheelSpin
			elseif entry.kind == "legL" then pedal * 0.45
			elseif entry.kind == "legR" then -pedal * 0.45
			else 0
		cf *= CFrame.Angles(spin, 0, 0)
		entry.part.CFrame = cf * CFrame.new(0, bob, 0)
	end
	if session.passengerFigure and session.passengerRig then
		local seat = root * session.becak.passengerSeatOffset
		for _, entry in session.passengerRig do
			entry.part.CFrame = seat * entry.offset
		end
	end
end

local function seatPassenger(session: any, shirtColour: Color3)
	if session.passengerFigure then
		session.passengerFigure:Destroy()
	end
	local figure = BecakFactory.buildPassenger(session.becak.model, shirtColour)
	local seatPart = session.becak.model:FindFirstChild("PassengerSeat") :: Part
	local origin = seatPart.CFrame
	local rig = {}
	for _, descendant in figure:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(rig, { part = descendant, offset = origin:ToObjectSpace(descendant.CFrame) })
		end
	end
	session.passengerFigure = figure
	session.passengerRig = rig
end

local function unseatPassenger(session: any)
	if session.passengerFigure then
		session.passengerFigure:Destroy()
		session.passengerFigure = nil
		session.passengerRig = nil
	end
end

local function buildTrackFor(player: Player): any
	nextTrackIndex += 1
	local index = nextTrackIndex
	local offsetX = (index - 1) * Config.TRACK_SPACING
	local seed = math.floor(os.clock() * 1000) + player.UserId * 7919 + index * 104729
	local world = WorldBuilder.buildTrack(tracksFolder, "Track_" .. player.Name, offsetX, seed)
	local traffic = TrafficManager.new(world.folder, offsetX, seed + 13)
	local passengers = PassengerManager.new(world.folder, offsetX, seed + 29)
	local rainPart = Instance.new("Part")
	rainPart.Name = "RainSheet"
	rainPart.Size = Vector3.new(80, 1, 360)
	rainPart.Position = Vector3.new(offsetX, 45, -140)
	rainPart.Transparency = 1
	rainPart.Anchored = true
	rainPart.CanCollide = false
	rainPart.Parent = world.folder
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Rain"
	emitter.Rate = 500
	emitter.Lifetime = NumberRange.new(0.7, 0.9)
	emitter.Speed = NumberRange.new(65, 80)
	emitter.Size = NumberSequence.new(0.18)
	emitter.Transparency = NumberSequence.new(0.45)
	emitter.Color = ColorSequence.new(Color3.fromRGB(170, 205, 240))
	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.SpreadAngle = Vector2.new(4, 4)
	emitter.Enabled = false
	emitter.Parent = rainPart
	return { world = world, traffic = traffic, passengers = passengers, rainEmitter = emitter, offsetX = offsetX, owner = player, rng = Random.new(seed + 101) }
end

local function sendHud(session: any)
	if not session.track then
		return
	end
	local passengers = session.track.passengers
	HudUpdate:FireClient(session.player, {
		state = session.state,
		score = math.floor(session.score),
		coins = session.coins,
		distance = math.floor(session.distance),
		speed = math.floor(session.speed * 3.6), -- km/h, for the speedometer
		hearts = session.hearts,
		combo = session.combo,
		multiplier = session.multiplier,
		passenger = passengers.name,
		objective = passengers:getObjectiveDistance(),
		best = session.best,
		raining = raining,
	})
end

local function setupPlayer(player: Player)
	local trackRecord = nil
	if #tracks < Config.MAX_TRACKS then
		trackRecord = buildTrackFor(player)
		table.insert(tracks, trackRecord)
	else
		Toast:FireClient(player, "Server penuh — coba lagi sebentar!", 4)
	end
	local session = newSession(player, trackRecord)
	sessions[player] = session
	if bestStore then
		task.spawn(function()
			local ok, value = pcall(function()
				return bestStore:GetAsync("best_" .. tostring(player.UserId))
			end)
			if ok and typeof(value) == "number" then
				session.best = value
			end
		end)
	end
	if not trackRecord then
		return
	end
	local origin = CFrame.new(trackRecord.offsetX, 0, Config.PLAYER_Z)
	local becak = BecakFactory.buildBecak(becaksFolder, origin)
	becak.model.Name = "Becak_" .. player.Name
	session.becak = becak
	session.rig = buildRig(becak)
	session.x = trackRecord.offsetX
	session.becak.passengerSeatOffset = origin:ToObjectSpace((becak.model:FindFirstChild("PassengerSeat") :: Part).CFrame)
	poseBecak(session, origin, 0)
	sendHud(session)
end

local function teardownPlayer(player: Player)
	local session = sessions[player]
	if not session then
		return
	end
	if session.becak then
		session.becak.model:Destroy()
	end
	if session.track then
		session.track.world.folder:Destroy()
		for i, record in tracks do
			if record == session.track then
				table.remove(tracks, i)
				break
			end
		end
	end
	sessions[player] = nil
end

local function refreshMultiplier(session: any)
	session.multiplier = math.min(1 + math.floor(session.combo / 3), Config.COMBO_MAX)
end

local function awardScore(session: any, base: number)
	refreshMultiplier(session)
	session.score += base * session.multiplier
	session.combo += 1
	session.comboTimer = Config.COMBO_WINDOW
	refreshMultiplier(session)
end

local function resetCombo(session: any)
	session.combo = 0
	session.comboTimer = 0
	session.multiplier = 1
end

local function startRun(player: Player)
	local session = sessions[player]
	if not session or not session.track then
		return
	end
	session.state = "countdown"
	session.runId += 1
	local runId = session.runId
	session.lane = 2
	session.x = session.track.offsetX
	session.y = 0
	session.jumpT = nil
	session.speed = 0
	session.distance = 0
	session.score = 0
	session.coins = 0
	session.deliveries = 0
	session.hearts = Config.MAX_HEARTS
	resetCombo(session)
	session.invulnerableUntil = 0
	session.slowUntil = 0
	session.runStartedAt = os.clock()
	session.track.traffic:clear()
	session.track.passengers:clear()
	unseatPassenger(session)
	Countdown:FireClient(player, 3)
	Sfx:FireClient(player, "count")
	for _, pair in { { 1, 2 }, { 2, 1 } } do
		task.delay(pair[1], function()
			if session.state == "countdown" and session.runId == runId and player.Parent then
				Countdown:FireClient(player, pair[2])
				Sfx:FireClient(player, "count")
			end
		end)
	end
	task.delay(3, function()
		if session.state == "countdown" and session.runId == runId and player.Parent then
			session.state = "playing"
			Countdown:FireClient(player, 0)
			Sfx:FireClient(player, "go")
			Toast:FireClient(player, "GAS! Antar penumpang, kumpulkan koin!", 2.5)
		end
	end)
end

local function endRun(session: any, reason: string)
	session.state = "over"
	session.speed = 0
	session.track.traffic:clear()
	session.track.passengers:clear()
	unseatPassenger(session)
	local player = session.player
	local isBest = session.score > session.best
	if isBest then
		session.best = session.score
		if bestStore then
			task.spawn(function()
				pcall(function()
					bestStore:SetAsync("best_" .. tostring(player.UserId), session.best)
				end)
			end)
		end
	end
	table.insert(leaderboard, { name = player.DisplayName, score = session.score, distance = session.distance })
	table.sort(leaderboard, function(a, b)
		return a.score > b.score
	end)
	while #leaderboard > 5 do
		table.remove(leaderboard)
	end
	RunOver:FireClient(player, {
		reason = reason,
		score = session.score,
		distance = session.distance,
		coins = session.coins,
		deliveries = session.deliveries,
		best = session.best,
		isBest = isBest,
		time = os.clock() - session.runStartedAt,
		top = leaderboard,
	})
end

local function handleCrash(session: any, what: string)
	local now = os.clock()
	if now < session.invulnerableUntil or session.state ~= "playing" then
		return
	end
	session.hearts -= 1
	session.invulnerableUntil = now + Config.INVULNERABLE_SECONDS
	session.speed = math.max(Config.BASE_SPEED * 0.5, session.speed - Config.CRASH_SPEED_PENALTY)
	resetCombo(session)
	CrashFlash:FireClient(session.player)
	Sfx:FireClient(session.player, "crash")
	Toast:FireClient(session.player, if what == "pothole" then "DUK! Lubang! Hati-hati!" else "BRAK! Tabrakan!", 1.5)
	if session.hearts <= 0 then
		endRun(session, "crash")
	end
end

local function stepSession(session: any, dt: number, now: number)
	local track = session.track
	if not track then
		return
	end
	if session.state == "lobby" or session.state == "countdown" then
		WorldBuilder.scrollTrack(track.world, 6 * dt, track.rng)
		poseBecak(session, CFrame.new(session.x, 0, Config.PLAYER_Z), dt)
		return
	end
	if session.state ~= "playing" then
		poseBecak(session, CFrame.new(session.x, session.y, Config.PLAYER_Z), dt)
		return
	end
	local targetSpeed = math.min(Config.BASE_SPEED + session.distance * Config.SPEED_PER_METRE, Config.MAX_SPEED)
	if now < session.slowUntil then
		targetSpeed *= Config.PUDDLE_SLOW
	end
	session.speed = Util.moveTowards(session.speed, targetSpeed, 30 * dt)
	local worldSpeed = session.speed
	session.distance += worldSpeed * dt
	session.score += Config.SCORE_PER_METRE * worldSpeed * dt
	if session.combo > 0 then
		session.comboTimer -= dt
		if session.comboTimer <= 0 then
			resetCombo(session)
		end
	end
	local targetX = track.offsetX + Config.LANE_X[session.lane]
	session.x = Util.moveTowards(session.x, targetX, 16 * dt)
	local airborne = false
	if session.jumpT ~= nil then
		session.jumpT += dt / Config.JUMP_SECONDS
		if session.jumpT >= 1 then
			session.jumpT = nil
			session.y = 0
		else
			session.y = Util.jumpHeight(session.jumpT, Config.JUMP_HEIGHT)
			airborne = true
		end
	end
	local lean = Util.clamp((targetX - session.x) * 0.03, -0.18, 0.18)
	poseBecak(session, CFrame.new(session.x, session.y, Config.PLAYER_Z) * CFrame.Angles(0, 0, lean), dt)
	WorldBuilder.scrollTrack(track.world, worldSpeed * dt, track.rng)
	for _, event in track.traffic:update(dt, worldSpeed, session.x, airborne) do
		if event.type == "crash" then
			handleCrash(session, "car")
		elseif event.type == "pothole" then
			handleCrash(session, "pothole")
		elseif event.type == "puddle" then
			session.slowUntil = now + Config.PUDDLE_SLOW_SECONDS
			Toast:FireClient(session.player, "CEBUR! Genangan air — pelan-pelan!", 1.5)
			Sfx:FireClient(session.player, "splash")
		elseif event.type == "coin" then
			session.coins += 1
			awardScore(session, Config.COIN_SCORE)
			Sfx:FireClient(session.player, "coin")
		elseif event.type == "nearMiss" then
			awardScore(session, Config.NEAR_MISS_SCORE)
			Toast:FireClient(session.player, "NYARIS! +" .. tostring(Config.NEAR_MISS_SCORE * session.multiplier), 1)
			Sfx:FireClient(session.player, "nearMiss")
		end
		if session.state ~= "playing" then
			break
		end
	end
	if session.state ~= "playing" then
		return
	end
	for _, event in track.passengers:update(dt, worldSpeed, session.x) do
		if event.type == "pickedUp" then
			seatPassenger(session, track.passengers.shirtColour)
			Toast:FireClient(session.player, (event.name or "Penumpang") .. " naik! Antar ke bendera emas!", 2.5)
			Sfx:FireClient(session.player, "pickup")
		elseif event.type == "delivered" then
			session.deliveries += 1
			local fare = event.fare or Config.DELIVERY_FARE
			awardScore(session, fare)
			unseatPassenger(session)
			Toast:FireClient(session.player, Util.formatFare(event.name or "Penumpang", fare * session.multiplier) .. " — Terima kasih!", 2.5)
			Sfx:FireClient(session.player, "deliver")
		end
	end
end

StartRun.OnServerEvent:Connect(function(player: Player)
	startRun(player)
end)

LaneChange.OnServerEvent:Connect(function(player: Player, direction: number)
	local session = sessions[player]
	if not session or session.state ~= "playing" then
		return
	end
	session.lane = Util.clamp(session.lane + (if direction > 0 then 1 else -1), 1, Config.LANE_COUNT)
end)

JumpRequest.OnServerEvent:Connect(function(player: Player)
	local session = sessions[player]
	if not session or session.state ~= "playing" then
		return
	end
	local now = os.clock()
	if session.jumpT == nil and now - session.lastJumpAt >= Config.JUMP_COOLDOWN then
		session.jumpT = 0
		session.lastJumpAt = now
		Sfx:FireClient(player, "jump")
	end
end)

Players.PlayerAdded:Connect(setupPlayer)
Players.PlayerRemoving:Connect(teardownPlayer)
for _, player in Players:GetPlayers() do
	task.spawn(setupPlayer, player)
end

local function stepEnvironment(dt: number)
	clockTime += dt * (24 / Config.DAY_LENGTH_SECONDS)
	if clockTime >= 24 then
		clockTime -= 24
	end
	if raining then
		if os.clock() >= rainEndsAt then
			raining = false
			rainTimer = os.clock() + math.random(Config.RAIN_EVERY_MIN, Config.RAIN_EVERY_MAX)
			RainState:FireAllClients(false)
		end
	elseif os.clock() >= rainTimer then
		raining = true
		rainEndsAt = os.clock() + Config.RAIN_DURATION
		RainState:FireAllClients(true)
		Toast:FireAllClients("HUJAN DERAS! Awas genangan!", 2.5)
	end
end

local hudTimer = 0
local lightTimer = 0
RunService.Heartbeat:Connect(function(dt: number)
	local now = os.clock()
	stepEnvironment(dt)
	lightTimer += dt
	if lightTimer >= 1 then
		lightTimer = 0
		for _, track in tracks do
			WorldBuilder.applyTimeOfDay(Lighting, track.world.lampHeads, clockTime)
			track.rainEmitter.Enabled = raining
		end
	end
	for _, session in sessions do
		stepSession(session, dt, now)
	end
	hudTimer += dt
	if hudTimer >= 0.1 then
		hudTimer = 0
		for _, session in sessions do
			sendHud(session)
		end
	end
end)

return GameServer
