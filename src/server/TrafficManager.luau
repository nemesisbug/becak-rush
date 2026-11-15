-- Becak Rush: cars, buses, potholes, puddles and coins.

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local Util = require(game:GetService("ReplicatedStorage").Shared.Util)

local TrafficManager = {}
TrafficManager.__index = TrafficManager

local function part(parent: Instance, name: string, size: Vector3, pos: Vector3, color: Color3, material: Enum.Material?, transparency: number?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Position = pos
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Transparency = transparency or 0
	p.Anchored = true
	p.CanCollide = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function shiftZ(item: Instance, dz: number)
	if item:IsA("BasePart") then
		item.Position += Vector3.new(0, 0, dz)
	elseif item:IsA("Model") then
		for _, descendant in item:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Position += Vector3.new(0, 0, dz)
			end
		end
	end
end

local function addWheel(vehicle: Model, x: number, y: number, z: number)
	local wheel = Instance.new("Part")
	wheel.Name = "Wheel"
	wheel.Shape = Enum.PartType.Cylinder
	wheel.Size = Vector3.new(0.4, 1.1, 1.1)
	wheel.CFrame = CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.rad(90))
	wheel.Color = Config.PALETTE.Tire
	wheel.Anchored = true
	wheel.CanCollide = false
	wheel.Parent = vehicle
end

local function buildVehicle(parent: Instance, laneX: number, z: number, color: Color3, facing: number, isBus: boolean): (Model, number)
	local vehicle = Instance.new("Model")
	vehicle.Name = if isBus then "Bus" else "Car"
	local len = if isBus then 11 else 6.4
	local half = len / 2
	part(vehicle, "Body", Vector3.new(3.5, if isBus then 2.6 else 1.1, len), Vector3.new(laneX, if isBus then 1.8 else 1.1, z), color, Enum.Material.Metal)
	if isBus then
		part(vehicle, "Roof", Vector3.new(3.7, 0.3, len + 0.2), Vector3.new(laneX, 3.2, z), Color3.fromRGB(240, 240, 240))
		for i = -2, 2 do
			part(vehicle, "Window", Vector3.new(0.15, 1.0, 1.2), Vector3.new(laneX - 1.82, 2.2, z + i * 2), Config.PALETTE.WindowLit, Enum.Material.Neon)
			part(vehicle, "WindowR", Vector3.new(0.15, 1.0, 1.2), Vector3.new(laneX + 1.82, 2.2, z + i * 2), Config.PALETTE.WindowLit, Enum.Material.Neon)
		end
	else
		part(vehicle, "Cabin", Vector3.new(2.8, 1.0, 3.2), Vector3.new(laneX, 2.1, z + 0.3), Color3.fromRGB(40, 60, 80), Enum.Material.Glass)
	end
	for _, sx in { -1.7, 1.7 } do
		for _, sz in { -2.2, 2.2 } do
			addWheel(vehicle, laneX + sx, 0.55, z + sz * (len / 6.4))
		end
	end
	local front = (half + 0.05) * facing
	part(vehicle, "HeadlightL", Vector3.new(0.6, 0.4, 0.2), Vector3.new(laneX - 1.1, 1.1, z + front), Config.PALETTE.LampGlow, Enum.Material.Neon)
	part(vehicle, "HeadlightR", Vector3.new(0.6, 0.4, 0.2), Vector3.new(laneX + 1.1, 1.1, z + front), Config.PALETTE.LampGlow, Enum.Material.Neon)
	if not isBus then
		part(vehicle, "TaillightL", Vector3.new(0.6, 0.4, 0.2), Vector3.new(laneX - 1.1, 1.1, z - front), Color3.fromRGB(255, 40, 40), Enum.Material.Neon)
		part(vehicle, "TaillightR", Vector3.new(0.6, 0.4, 0.2), Vector3.new(laneX + 1.1, 1.1, z - front), Color3.fromRGB(255, 40, 40), Enum.Material.Neon)
	end
	vehicle.Parent = parent
	return vehicle, len
end

local function buildCoin(parent: Instance, x: number, z: number): Part
	local coin = Instance.new("Part")
	coin.Name = "Coin"
	coin.Shape = Enum.PartType.Cylinder
	coin.Size = Vector3.new(0.3, 2.0, 2.0)
	coin.CFrame = CFrame.new(x, 1.6, z) * CFrame.Angles(0, 0, math.rad(90))
	coin.Color = Config.PALETTE.Coin
	coin.Material = Enum.Material.Neon
	coin.Anchored = true
	coin.CanCollide = false
	coin.Parent = parent
	return coin
end

local function buildDisc(parent: Instance, name: string, x: number, z: number, radius: number, color: Color3, transparency: number): Part
	local disc = Instance.new("Part")
	disc.Name = name
	disc.Shape = Enum.PartType.Cylinder
	disc.Size = Vector3.new(0.2, radius * 2, radius * 2)
	disc.CFrame = CFrame.new(x, 0.08, z) * CFrame.Angles(0, 0, math.rad(90))
	disc.Color = color
	disc.Material = if name == "Puddle" then Enum.Material.Glass else Enum.Material.SmoothPlastic
	disc.Transparency = transparency
	disc.Anchored = true
	disc.CanCollide = false
	disc.Parent = parent
	return disc
end

function TrafficManager.new(trackFolder: Instance, offsetX: number, seed: number): any
	local self = setmetatable({}, TrafficManager)
	self.folder = Instance.new("Folder")
	self.folder.Name = "Traffic"
	self.folder.Parent = trackFolder
	self.offsetX = offsetX
	self.rng = Random.new(seed)
	self.items = {} -- { kind, instance, lane, z, relative, length, passed, hit }
	self.distanceSinceWave = 0
	self.nextWaveGap = Config.TRAFFIC_WAVE_GAP_MIN
	self.raining = false
	self.spinAngle = 0
	return self
end

function TrafficManager:addItem(kind: string, instance: Instance, lane: number, z: number, relative: number, length: number)
	table.insert(self.items, { kind = kind, instance = instance, lane = lane, z = z, relative = relative, length = length, passed = false, hit = false })
end

function TrafficManager:spawnTrafficWave()
	local rng = self.rng
	local lanes = { 1, 2, 3 }
	for i = #lanes, 2, -1 do
		local j = rng:NextInteger(1, i)
		lanes[i], lanes[j] = lanes[j], lanes[i]
	end
	local blockedCount = if rng:NextNumber() < 0.55 then 1 else 2
	local openLane = lanes[3]
	local waveZ = Config.SPAWN_Z - rng:NextNumber(0, 20)
	for b = 1, blockedCount do
		local lane = lanes[b]
		local laneX = self.offsetX + Config.LANE_X[lane]
		local oncoming = rng:NextNumber() < Config.ONCOMING_CHANCE
		local facing = if oncoming then 1 else -1
		local z = waveZ + rng:NextNumber(-6, 6)
		local isBus = rng:NextNumber() < Config.BUS_CHANCE
		local color = if isBus then Config.PALETTE.BusColour else Util.pickOne(Config.PALETTE.CarColours, rng)
		local model, length = buildVehicle(self.folder, laneX, z, color, facing, isBus)
		local relative = if oncoming
			then rng:NextNumber(Config.ONCOMING_SPEED_MIN, Config.ONCOMING_SPEED_MAX)
			else -rng:NextNumber(Config.CAR_SPEED_MIN, Config.CAR_SPEED_MAX)
		if isBus then
			relative *= 0.8
		end
		self:addItem("vehicle", model, lane, z, relative, length)
	end
	if rng:NextNumber() < Config.POTHOLE_CHANCE then
		local hole = buildDisc(self.folder, "Pothole", self.offsetX + Config.LANE_X[openLane], waveZ + rng:NextNumber(8, 26), 2.1, Config.PALETTE.Pothole, 0)
		self:addItem("pothole", hole, openLane, hole.Position.Z, 0, 4)
	end
	local puddleChance = if self.raining then Config.PUDDLE_CHANCE + 0.3 else Config.PUDDLE_CHANCE
	if rng:NextNumber() < puddleChance then
		local lane = lanes[rng:NextInteger(1, 3)]
		local puddle = buildDisc(self.folder, "Puddle", self.offsetX + Config.LANE_X[lane], waveZ + rng:NextNumber(14, 34), 2.5, Config.PALETTE.Puddle, 0.35)
		self:addItem("puddle", puddle, lane, puddle.Position.Z, 0, 5)
	end
	if rng:NextNumber() < 0.55 then
		local coinLanes = if rng:NextNumber() < 0.6 then { openLane, openLane, openLane, openLane, openLane } else { 1, 2, 3, 2, 1 }
		for i, lane in coinLanes do
			local coin = buildCoin(self.folder, self.offsetX + Config.LANE_X[lane], waveZ - (i - 1) * 5)
			self:addItem("coin", coin, lane, coin.Position.Z, 0, 2)
		end
	end
end

function TrafficManager:update(dt: number, worldSpeed: number, playerX: number, airborne: boolean): { { type: string, item: any } }
	local events = {}
	self.spinAngle += dt * 4
	self.distanceSinceWave += worldSpeed * dt
	if self.distanceSinceWave >= self.nextWaveGap then
		self.distanceSinceWave = 0
		self.nextWaveGap = self.rng:NextNumber(Config.TRAFFIC_WAVE_GAP_MIN, Config.TRAFFIC_WAVE_GAP_MAX)
		self:spawnTrafficWave()
	end
	local i = 1
	while i <= #self.items do
		local item = self.items[i]
		local dz = (worldSpeed + item.relative) * dt
		item.z += dz
		shiftZ(item.instance, dz)
		if item.kind == "coin" then
			local coin = item.instance :: Part
			coin.CFrame = CFrame.new(coin.Position) * CFrame.Angles(self.spinAngle, 0, math.rad(90))
		end
		if item.z > Config.DESPAWN_Z then
			item.instance:Destroy()
			table.remove(self.items, i)
			continue
		end
		local dx = math.abs(playerX - (self.offsetX + Config.LANE_X[item.lane]))
		if item.kind == "vehicle" then
			if not item.hit and math.abs(item.z) < item.length / 2 + 1.5 and dx < 3.2 then
				item.hit = true
				table.insert(events, { type = "crash", item = item })
			elseif not item.passed and item.z > 0 then
				item.passed = true
				if dx > 3.2 and dx < 10.5 then
					table.insert(events, { type = "nearMiss", item = item })
				end
			end
		elseif item.kind == "pothole" then
			if not item.hit and math.abs(item.z) < 2.5 and dx < 3 and not airborne then
				item.hit = true
				table.insert(events, { type = "pothole", item = item })
			end
		elseif item.kind == "puddle" then
			if not item.hit and math.abs(item.z) < 3 and dx < 3.2 then
				item.hit = true
				table.insert(events, { type = "puddle", item = item })
			end
		elseif item.kind == "coin" then
			if not item.hit and math.abs(item.z) < Config.COIN_COLLECT_RADIUS and dx < 3.2 then
				item.hit = true
				table.insert(events, { type = "coin", item = item })
				item.instance:Destroy()
				table.remove(self.items, i)
				continue
			end
		end
		i += 1
	end
	return events
end

function TrafficManager:clear()
	for _, item in self.items do
		item.instance:Destroy()
	end
	table.clear(self.items)
	self.distanceSinceWave = 0
end

return TrafficManager
