-- Becak Rush: the passengers who make the run a job.

local BecakFactory = require(script.Parent.BecakFactory)
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local Util = require(game:GetService("ReplicatedStorage").Shared.Util)

local PassengerManager = {}
PassengerManager.__index = PassengerManager

local function buildRing(parent: Instance, x: number, z: number, color: Color3): Part
	local ring = Instance.new("Part")
	ring.Name = "Ring"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.25, 7, 7)
	ring.CFrame = CFrame.new(x, 0.15, z) * CFrame.Angles(0, 0, math.rad(90))
	ring.Color = color
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.25
	ring.Anchored = true
	ring.CanCollide = false
	ring.Parent = parent
	return ring
end

local function buildSign(parent: Instance, adornee: Instance, text: string, color: Color3): BillboardGui
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Sign"
	billboard.Adornee = adornee
	billboard.Size = UDim2.fromOffset(220, 64)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 5.5, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = parent
	local label = Instance.new("TextLabel")
	label.Name = "SignText"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.25
	label.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	label.TextColor3 = color
	label.Text = text
	label.TextSize = 24
	label.Font = Enum.Font.GothamBold
	label.Parent = billboard
	return billboard
end

local function scrollParts(root: Instance, dz: number)
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Position += Vector3.new(0, 0, dz)
		end
	end
end

function PassengerManager.new(trackFolder: Instance, offsetX: number, seed: number): any
	local self = setmetatable({}, PassengerManager)
	self.folder = Instance.new("Folder")
	self.folder.Name = "Passengers"
	self.folder.Parent = trackFolder
	self.offsetX = offsetX
	self.rng = Random.new(seed)
	self.state = "idle" -- idle | waiting | riding
	self.name = nil :: string?
	self.lane = 2
	self.z = 0
	self.marker = nil :: Instance?
	self.figure = nil :: Model?
	self.sign = nil :: BillboardGui?
	self.waitTimer = 6 -- seconds until the first passenger appears
	self.destinationZ = 0
	self.destinationMarker = nil :: Instance?
	self.shirtColour = Color3.fromRGB(200, 100, 100)
	return self
end

function PassengerManager:spawnWaitingPassenger()
	local rng = self.rng
	self.name = Util.pickOne(Config.PASSENGER_NAMES, rng)
	self.lane = rng:NextInteger(1, Config.LANE_COUNT)
	self.z = Config.SPAWN_Z
	local laneX = self.offsetX + Config.LANE_X[self.lane]
	self.shirtColour = Util.pickOne({
		Color3.fromRGB(220, 90, 90),
		Color3.fromRGB(90, 160, 220),
		Color3.fromRGB(240, 200, 80),
		Color3.fromRGB(140, 200, 120),
		Color3.fromRGB(190, 120, 220),
	}, rng)
	self.marker = buildRing(self.folder, laneX, self.z, Config.PALETTE.PassengerRing)
	self.figure = BecakFactory.buildWaitingPassenger(self.folder, self.shirtColour, Vector3.new(laneX, 0, self.z))
	self.sign = buildSign(self.folder, self.marker, "NAIK! " .. (self.name or ""), Config.PALETTE.PassengerRing)
	self.state = "waiting"
end

function PassengerManager:spawnDestination()
	local rng = self.rng
	self.lane = rng:NextInteger(1, Config.LANE_COUNT)
	self.destinationZ = Config.SPAWN_Z
	local laneX = self.offsetX + Config.LANE_X[self.lane]
	local marker = Instance.new("Folder")
	marker.Name = "Destination"
	marker.Parent = self.folder
	buildRing(marker, laneX, self.destinationZ, Config.PALETTE.DestinationRing)
	local pole = Instance.new("Part")
	pole.Name = "FlagPole"
	pole.Size = Vector3.new(0.35, 12, 0.35)
	pole.Position = Vector3.new(laneX + 3, 6, self.destinationZ)
	pole.Color = Color3.fromRGB(60, 60, 65)
	pole.Material = Enum.Material.Metal
	pole.Anchored = true
	pole.CanCollide = false
	pole.Parent = marker
	local flag = Instance.new("Part")
	flag.Name = "Flag"
	flag.Size = Vector3.new(3.2, 2, 0.2)
	flag.Position = Vector3.new(laneX + 1.4, 11, self.destinationZ)
	flag.Color = Config.PALETTE.Coin
	flag.Material = Enum.Material.Neon
	flag.Anchored = true
	flag.CanCollide = false
	flag.Parent = marker
	self.destinationMarker = marker
	self.sign = buildSign(self.folder, flag, "TUJUAN: " .. (self.name or ""), Config.PALETTE.Coin)
end

function PassengerManager:clearWaiting()
	if self.marker then
		self.marker:Destroy()
		self.marker = nil
	end
	if self.figure then
		self.figure:Destroy()
		self.figure = nil
	end
	if self.sign then
		self.sign:Destroy()
		self.sign = nil
	end
end

function PassengerManager:clearDestination()
	if self.destinationMarker then
		self.destinationMarker:Destroy()
		self.destinationMarker = nil
	end
	if self.sign then
		self.sign:Destroy()
		self.sign = nil
	end
end

function PassengerManager:sendHome()
	self.state = "idle"
	self.waitTimer = self.rng:NextNumber(5, 12)
	self.name = nil
end

function PassengerManager:update(dt: number, worldSpeed: number, playerX: number): { { type: string, name: string?, fare: number? } }
	local events = {}
	if self.state == "idle" then
		self.waitTimer -= dt
		if self.waitTimer <= 0 then
			self:spawnWaitingPassenger()
		end
		return events
	end
	local dz = worldSpeed * dt
	if self.state == "waiting" and self.marker then
		self.z += dz
		local laneX = self.offsetX + Config.LANE_X[self.lane]
		local ring = self.marker :: Part
		ring.Position += Vector3.new(0, 0, dz)
		if self.figure then
			scrollParts(self.figure, dz)
			local arm = self.figure:FindFirstChild("ArmWave") :: Part?
			if arm then
				arm.CFrame = CFrame.new(arm.Position) * CFrame.Angles(0, 0, math.rad(-140 + math.sin(os.clock() * 6) * 12))
			end
		end
		if math.abs(self.z) < Config.PICKUP_RADIUS and math.abs(playerX - laneX) < 3.5 then
			self:clearWaiting()
			self.state = "riding"
			self:spawnDestination()
			table.insert(events, { type = "pickedUp", name = self.name })
		elseif self.z > 12 then
			self:clearWaiting()
			self:sendHome()
		end
	elseif self.state == "riding" and self.destinationMarker then
		self.destinationZ += dz
		local laneX = self.offsetX + Config.LANE_X[self.lane]
		scrollParts(self.destinationMarker, dz)
		if math.abs(self.destinationZ) < Config.DELIVER_RADIUS and math.abs(playerX - laneX) < 4 then
			local fare = Config.DELIVERY_FARE
			local name = self.name
			self:clearDestination()
			self:sendHome()
			table.insert(events, { type = "delivered", name = name, fare = fare })
		elseif self.destinationZ > 12 then
			self:clearDestination()
			self:sendHome()
		end
	end
	return events
end

function PassengerManager:getObjectiveDistance(): number?
	if self.state == "waiting" then
		return math.max(0, -self.z)
	elseif self.state == "riding" then
		return math.max(0, -self.destinationZ)
	else
		return nil
	end
end

function PassengerManager:clear()
	self:clearWaiting()
	self:clearDestination()
	self:sendHome()
	self.waitTimer = 6
end

return PassengerManager
