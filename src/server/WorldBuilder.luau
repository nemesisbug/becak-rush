-- Becak Rush: builds and recycles the endless Jakarta street.

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local Util = require(game:GetService("ReplicatedStorage").Shared.Util)

local WorldBuilder = {}

local SEG_LEN = Config.SEGMENT_LENGTH
local SEG_COUNT = Config.SEGMENT_COUNT

local function part(folder: Instance, name: string, size: Vector3, pos: Vector3, color: Color3, material: Enum.Material?, transparency: number?): Part
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
	p.Parent = folder
	return p
end

local function buildBuilding(folder: Instance, rng: Random, side: number, z: number, litWindows: { Part }, offsetX: number)
	local palette = Config.PALETTE
	local colour = Util.pickOne({ palette.BuildingA, palette.BuildingB, palette.BuildingC, palette.BuildingD }, rng)
	local width = rng:NextNumber(9, 14)
	local height = rng:NextNumber(9, 26)
	local depth = rng:NextNumber(9, 13)
	local x = offsetX + side * (Config.ROAD_HALF_WIDTH + 9 + width / 2)
	part(folder, "Building", Vector3.new(width, height, depth), Vector3.new(x, height / 2 - 0.5, z), colour)
	part(folder, "Roof", Vector3.new(width + 0.6, 0.8, depth + 0.6), Vector3.new(x, height - 0.1, z), Color3.fromRGB(70, 60, 55))
	local faceX = x - side * (width / 2 + 0.06)
	-- One glowing strip per floor, instead of a grid of windows: cheaper,
	-- and it still reads as lit windows from the street.
	for row = 1, math.floor(height / 4) do
		local lit = rng:NextNumber() < 0.45
		local win = part(folder, "Window", Vector3.new(0.12, 1.6, depth - 2),
			Vector3.new(faceX, 2.5 + (row - 1) * 4, z),
			if lit then palette.WindowLit else palette.WindowDark, Enum.Material.Neon)
		win.Transparency = if lit then 0.15 else 0.55
		table.insert(litWindows, win)
	end
end

local function buildWarung(folder: Instance, side: number, z: number, offsetX: number)
	local palette = Config.PALETTE
	local x = offsetX + side * (Config.ROAD_HALF_WIDTH + 5.5)
	part(folder, "Stall", Vector3.new(4, 3, 3), Vector3.new(x, 1.5, z), Color3.fromRGB(150, 100, 60), Enum.Material.Wood)
	part(folder, "Counter", Vector3.new(4.4, 0.4, 1.2), Vector3.new(x, 2.2, z), Color3.fromRGB(90, 60, 40), Enum.Material.Wood)
	for i = 0, 3 do
		local stripe = part(folder, "Awning", Vector3.new(1.1, 0.15, 3.6),
			Vector3.new(x - 1.65 + i * 1.1, 3.6, z), if i % 2 == 0 then palette.Canopy else Color3.fromRGB(255, 247, 237))
		stripe.CFrame = CFrame.new(stripe.Position) * CFrame.Angles(math.rad(-12), 0, 0)
	end
	local board = part(folder, "MenuBoard", Vector3.new(2.2, 1.4, 0.15), Vector3.new(x, 4.4, z), Color3.fromRGB(40, 40, 45))
	board.CFrame = CFrame.new(board.Position) * CFrame.Angles(0, math.rad(if side > 0 then -90 else 90), 0)
end

local function buildLamp(folder: Instance, side: number, z: number, lampHeads: { Part }, offsetX: number)
	local x = offsetX + side * (Config.ROAD_HALF_WIDTH + 1.2)
	part(folder, "LampPole", Vector3.new(0.35, 7, 0.35), Vector3.new(x, 3.5, z), Color3.fromRGB(50, 50, 55), Enum.Material.Metal)
	part(folder, "LampArm", Vector3.new(1.8, 0.3, 0.3), Vector3.new(x - side * 0.8, 6.9, z), Color3.fromRGB(50, 50, 55), Enum.Material.Metal)
	local head = part(folder, "LampHead", Vector3.new(0.9, 0.35, 0.9),
		Vector3.new(x - side * 1.6, 6.8, z), Config.PALETTE.LampGlow, Enum.Material.Neon)
	head.Transparency = 0.7 -- dim by day; the day/night cycle brightens it
	local light = Instance.new("PointLight")
	light.Name = "LampLight"
	light.Color = Config.PALETTE.LampGlow
	light.Range = 16
	light.Brightness = 0
	light.Parent = head
	table.insert(lampHeads, head)
end

local function buildTree(folder: Instance, rng: Random, side: number, z: number, offsetX: number)
	local x = offsetX + side * (Config.ROAD_HALF_WIDTH + 4 + rng:NextNumber(0, 3))
	part(folder, "Trunk", Vector3.new(0.7, 3, 0.7), Vector3.new(x, 1.5, z), Color3.fromRGB(110, 75, 45), Enum.Material.Wood)
	local leaves = part(folder, "Leaves", Vector3.new(3.4, 3.4, 3.4), Vector3.new(x, 4.6, z), Config.PALETTE.Grass)
	leaves.Shape = Enum.PartType.Ball
	part(folder, "LeavesTop", Vector3.new(2.2, 2.2, 2.2), Vector3.new(x, 6.2, z), Color3.fromRGB(110, 180, 100)).Shape = Enum.PartType.Ball
end

function WorldBuilder.rollSegmentDecor(segment: Folder, rng: Random, litWindows: { Part }, lampHeads: { Part }, offsetX: number)
	for _, child in segment:GetChildren() do
		if child.Name == "Decor" then
			child:Destroy()
		end
	end
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = segment
	local centreZ = segment:GetAttribute("CentreZ") :: number
	for _, side in { -1, 1 } do
		local roll = rng:NextNumber()
		if roll < 0.62 then
			buildBuilding(decor, rng, side, centreZ + rng:NextNumber(-8, 8), litWindows, offsetX)
		elseif roll < 0.78 then
			buildWarung(decor, side, centreZ + rng:NextNumber(-6, 6), offsetX)
		else
			buildTree(decor, rng, side, centreZ + rng:NextNumber(-8, 8), offsetX)
		end
		if rng:NextNumber() < 0.5 then
			buildLamp(decor, side, centreZ + rng:NextNumber(-12, 12), lampHeads, offsetX)
		end
	end
end

local function buildSegment(track: Folder, index: number, centreZ: number, offsetX: number): Folder
	local segment = Instance.new("Folder")
	segment.Name = "Segment" .. tostring(index)
	segment:SetAttribute("CentreZ", centreZ)
	segment.Parent = track
	local palette = Config.PALETTE
	local w = Config.ROAD_HALF_WIDTH
	part(segment, "Road", Vector3.new(w * 2, 1, SEG_LEN), Vector3.new(offsetX, -0.5, centreZ), palette.Road, Enum.Material.Asphalt)
	part(segment, "EdgeL", Vector3.new(0.5, 1.05, SEG_LEN), Vector3.new(offsetX - w, -0.5, centreZ), palette.RoadEdge)
	part(segment, "EdgeR", Vector3.new(0.5, 1.05, SEG_LEN), Vector3.new(offsetX + w, -0.5, centreZ), palette.RoadEdge)
	for _, lx in { -3.5, 3.5 } do
		part(segment, "Marking", Vector3.new(0.35, 1.06, 6), Vector3.new(offsetX + lx, -0.5, centreZ), palette.RoadEdge)
	end
	part(segment, "SidewalkL", Vector3.new(6, 1.4, SEG_LEN), Vector3.new(offsetX - (w + 3), -0.3, centreZ), palette.Sidewalk)
	part(segment, "SidewalkR", Vector3.new(6, 1.4, SEG_LEN), Vector3.new(offsetX + w + 3, -0.3, centreZ), palette.Sidewalk)
	part(segment, "GrassL", Vector3.new(24, 0.8, SEG_LEN), Vector3.new(offsetX - (w + 18), -0.6, centreZ), palette.Grass)
	part(segment, "GrassR", Vector3.new(24, 0.8, SEG_LEN), Vector3.new(offsetX + w + 18, -0.6, centreZ), palette.Grass)
	return segment
end

function WorldBuilder.buildTrack(parent: Instance, name: string, offsetX: number, seed: number): {
	folder: Folder,
	segments: { Folder },
	litWindows: { Part },
	lampHeads: { Part },
	offsetX: number,
}
	local rng = Random.new(seed)
	local track = Instance.new("Folder")
	track.Name = name
	track.Parent = parent
	local segments = {}
	local litWindows = {}
	local lampHeads = {}
	for i = 1, SEG_COUNT do
		local centreZ = 30 - (i - 1) * SEG_LEN - SEG_LEN / 2
		local segment = buildSegment(track, i, centreZ, offsetX)
		WorldBuilder.rollSegmentDecor(segment, rng, litWindows, lampHeads, offsetX)
		table.insert(segments, segment)
	end
	return { folder = track, segments = segments, litWindows = litWindows, lampHeads = lampHeads, offsetX = offsetX }
end

function WorldBuilder.scrollTrack(trackData: {
	folder: Folder,
	segments: { Folder },
	litWindows: { Part },
	lampHeads: { Part },
	offsetX: number,
}, dz: number, rng: Random)
	local totalLength = SEG_LEN * SEG_COUNT
	for _, segment in trackData.segments do
		local oldCentre = segment:GetAttribute("CentreZ") :: number
		local newCentre = oldCentre + dz
		if newCentre - SEG_LEN / 2 > Config.DESPAWN_Z then
			newCentre -= totalLength
			WorldBuilder.rollSegmentDecor(segment, rng, trackData.litWindows, trackData.lampHeads, trackData.offsetX)
		end
		segment:SetAttribute("CentreZ", newCentre)
		local moveZ = newCentre - oldCentre
		for _, descendant in segment:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Position += Vector3.new(0, 0, moveZ)
			end
		end
	end
end

function WorldBuilder.applyTimeOfDay(lighting: Lighting, lampHeads: { Part }, clockTime: number)
	lighting.ClockTime = clockTime
	local night = clockTime >= 17.5 or clockTime < 6
	lighting.Brightness = if night then 1.2 else 2
	lighting.Ambient = if night then Color3.fromRGB(30, 30, 45) else Color3.fromRGB(120, 120, 120)
	for _, head in lampHeads do
		if head.Parent then
			head.Transparency = if night then 0 else 0.7
			local light = head:FindFirstChild("LampLight") :: PointLight?
			if light then
				light.Brightness = if night then 2 else 0
			end
		end
	end
end

return WorldBuilder
