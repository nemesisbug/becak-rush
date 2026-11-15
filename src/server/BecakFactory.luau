-- Becak Rush: builds the becak, its pedalling driver, and passengers.

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local BecakFactory = {}

local BODY = Config.PALETTE.Body
local CANOPY = Config.PALETTE.Canopy
local SEAT = Config.PALETTE.Seat
local TIRE = Config.PALETTE.Tire
local SKIN = Color3.fromRGB(222, 184, 135)
local PANTS = Color3.fromRGB(50, 50, 70)

local function makePart(parent: Instance, name: string, size: Vector3, pos: Vector3, color: Color3, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = pos
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function makeWheel(parent: Instance, name: string, position: Vector3, radius: number): Part
	local wheel = Instance.new("Part")
	wheel.Name = name
	wheel.Shape = Enum.PartType.Cylinder
	wheel.Size = Vector3.new(0.5, radius * 2, radius * 2)
	wheel.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	wheel.Color = TIRE
	wheel.Anchored = true
	wheel.CanCollide = false
	wheel.Parent = parent
	local hub = Instance.new("Part")
	hub.Name = name .. "Hub"
	hub.Shape = Enum.PartType.Cylinder
	hub.Size = Vector3.new(0.56, radius * 0.7, radius * 0.7)
	hub.CFrame = wheel.CFrame
	hub.Color = Config.PALETTE.Hub
	hub.Anchored = true
	hub.CanCollide = false
	hub.Parent = parent
	return wheel
end

local function buildDriver(model: Model, origin: CFrame): { leftLeg: Part, rightLeg: Part }
	local function at(offset: Vector3): Vector3
		return (origin * CFrame.new(offset)).Position
	end
	local shirt = Color3.fromRGB(255, 255, 255)
	local torso = makePart(model, "DriverTorso", Vector3.new(1.1, 1.3, 0.6), at(Vector3.new(0, 3.4, 1.6)), shirt)
	torso.CFrame = CFrame.new(torso.Position) * CFrame.Angles(math.rad(-14), 0, 0)
	makePart(model, "DriverHead", Vector3.new(0.9, 0.9, 0.9), at(Vector3.new(0, 4.5, 1.35)), SKIN)
	local cap = makePart(model, "DriverCap", Vector3.new(1.0, 0.25, 1.0), at(Vector3.new(0, 5.0, 1.35)), CANOPY)
	cap.CFrame = CFrame.new(cap.Position) * CFrame.Angles(math.rad(-10), 0, 0)
	makePart(model, "DriverCapBrim", Vector3.new(1.0, 0.12, 0.5), at(Vector3.new(0, 4.95, 0.8)), CANOPY)
	local leftArm = makePart(model, "DriverArmL", Vector3.new(0.35, 1.2, 0.35), at(Vector3.new(-0.7, 3.7, 1.0)), SKIN)
	leftArm.CFrame = CFrame.new(leftArm.Position) * CFrame.Angles(math.rad(-55), 0, math.rad(12))
	local rightArm = makePart(model, "DriverArmR", Vector3.new(0.35, 1.2, 0.35), at(Vector3.new(0.7, 3.7, 1.0)), SKIN)
	rightArm.CFrame = CFrame.new(rightArm.Position) * CFrame.Angles(math.rad(-55), 0, math.rad(-12))
	local leftLeg = makePart(model, "DriverLegL", Vector3.new(0.4, 1.3, 0.4), at(Vector3.new(-0.35, 2.4, 1.3)), Color3.fromRGB(40, 60, 120))
	local rightLeg = makePart(model, "DriverLegR", Vector3.new(0.4, 1.3, 0.4), at(Vector3.new(0.35, 2.4, 1.3)), Color3.fromRGB(40, 60, 120))
	return { leftLeg = leftLeg, rightLeg = rightLeg }
end

function BecakFactory.buildBecak(parent: Instance, origin: CFrame): {
	model: Model,
	primary: Part,
	driverLegs: { leftLeg: Part, rightLeg: Part },
	frontWheel: Part,
	rearWheelL: Part,
	rearWheelR: Part,
	passengerSeat: Part,
}
	local model = Instance.new("Model")
	model.Name = "Becak"
	local function at(offset: Vector3): Vector3
		return (origin * CFrame.new(offset)).Position
	end
	local function rot(offset: Vector3, angles: Vector3): CFrame
		return CFrame.new(at(offset)) * CFrame.Angles(angles.X, angles.Y, angles.Z)
	end
	local chassis = makePart(model, "Chassis", Vector3.new(3.2, 0.35, 6.4), at(Vector3.new(0, 1.0, 0)), BODY)
	makePart(model, "Bench", Vector3.new(2.8, 0.4, 1.6), at(Vector3.new(0, 1.6, -1.7)), SEAT)
	local backrest = makePart(model, "BenchBack", Vector3.new(2.8, 1.2, 0.35), at(Vector3.new(0, 2.3, -2.4)), SEAT)
	backrest.CFrame = rot(Vector3.new(0, 2.3, -2.4), Vector3.new(math.rad(10), 0, 0))
	makePart(model, "Footrest", Vector3.new(2.6, 0.25, 0.7), at(Vector3.new(0, 0.9, -2.9)), BODY)
	local canopy = makePart(model, "Canopy", Vector3.new(3.4, 0.25, 2.6), at(Vector3.new(0, 4.3, -1.7)), CANOPY)
	canopy.CFrame = rot(Vector3.new(0, 4.3, -1.7), Vector3.new(math.rad(-6), 0, 0))
	makePart(model, "CanopyStripe", Vector3.new(3.42, 0.27, 0.5), at(Vector3.new(0, 4.32, -1.7)), Config.PALETTE.CanopyStripe)
	makePart(model, "PostL", Vector3.new(0.18, 2.6, 0.18), at(Vector3.new(-1.5, 3.0, -2.6)), BODY)
	makePart(model, "PostR", Vector3.new(0.18, 2.6, 0.18), at(Vector3.new(1.5, 3.0, -2.6)), BODY)
	makePart(model, "Saddle", Vector3.new(1.0, 0.35, 0.9), at(Vector3.new(0, 2.5, 1.9)), SEAT)
	local bar = Instance.new("Part")
	bar.Name = "Handlebar"
	bar.Shape = Enum.PartType.Cylinder
	bar.Size = Vector3.new(0.25, 2.2, 2.2)
	bar.CFrame = CFrame.new(at(Vector3.new(0, 3.6, 0.4))) * CFrame.Angles(0, 0, math.rad(90))
	bar.Color = Config.PALETTE.Hub
	bar.Anchored = true
	bar.CanCollide = false
	bar.Parent = model
	local lamp = makePart(model, "Headlamp", Vector3.new(0.5, 0.5, 0.5), at(Vector3.new(0, 1.5, -3.3)), Config.PALETTE.LampGlow, Enum.Material.Neon)
	lamp.Shape = Enum.PartType.Ball
	local frontWheel = makeWheel(model, "WheelFront", at(Vector3.new(0, 0.75, -2.6)), 0.75)
	local rearWheelL = makeWheel(model, "WheelRearL", at(Vector3.new(-1.5, 0.75, 1.9)), 0.75)
	local rearWheelR = makeWheel(model, "WheelRearR", at(Vector3.new(1.5, 0.75, 1.9)), 0.75)
	local driverLegs = buildDriver(model, origin)
	local passengerSeat = makePart(model, "PassengerSeat", Vector3.new(0.1, 0.1, 0.1), at(Vector3.new(0, 1.9, -1.7)), SEAT)
	passengerSeat.Transparency = 1
	model.PrimaryPart = chassis
	model.Parent = parent
	return {
		model = model,
		primary = chassis,
		driverLegs = driverLegs,
		frontWheel = frontWheel,
		rearWheelL = rearWheelL,
		rearWheelR = rearWheelR,
		passengerSeat = passengerSeat,
	}
end

function BecakFactory.buildPassenger(parent: Instance, color: Color3): Model
	local figure = Instance.new("Model")
	figure.Name = "Passenger"
	makePart(figure, "Torso", Vector3.new(1.0, 1.1, 0.55), Vector3.new(0, 0.6, 0), color)
	makePart(figure, "Head", Vector3.new(0.85, 0.85, 0.85), Vector3.new(0, 1.6, 0), SKIN)
	makePart(figure, "LegL", Vector3.new(0.35, 0.35, 1.0), Vector3.new(-0.3, 0.1, -0.6), PANTS)
	makePart(figure, "LegR", Vector3.new(0.35, 0.35, 1.0), Vector3.new(0.3, 0.1, -0.6), PANTS)
	makePart(figure, "ArmL", Vector3.new(0.3, 0.9, 0.3), Vector3.new(-0.65, 0.6, 0), SKIN)
	makePart(figure, "ArmR", Vector3.new(0.3, 0.9, 0.3), Vector3.new(0.65, 0.6, 0), SKIN)
	figure.Parent = parent
	return figure
end

function BecakFactory.buildWaitingPassenger(parent: Instance, color: Color3, position: Vector3): Model
	local figure = Instance.new("Model")
	figure.Name = "WaitingPassenger"
	local function p(name: string, size: Vector3, offset: Vector3, col: Color3): Part
		return makePart(figure, name, size, position + offset, col)
	end
	p("Torso", Vector3.new(1.0, 1.2, 0.55), Vector3.new(0, 1.5, 0), color)
	p("Head", Vector3.new(0.85, 0.85, 0.85), Vector3.new(0, 2.55, 0), SKIN)
	local arm = p("ArmWave", Vector3.new(0.3, 1.1, 0.3), Vector3.new(0.65, 2.1, 0), SKIN)
	arm.CFrame = CFrame.new(arm.Position) * CFrame.Angles(0, 0, math.rad(-140))
	p("ArmL", Vector3.new(0.3, 1.0, 0.3), Vector3.new(-0.65, 1.5, 0), SKIN)
	p("LegL", Vector3.new(0.38, 1.0, 0.38), Vector3.new(-0.28, 0.5, 0), PANTS)
	p("LegR", Vector3.new(0.38, 1.0, 0.38), Vector3.new(0.28, 0.5, 0), PANTS)
	figure.Parent = parent
	return figure
end

return BecakFactory
