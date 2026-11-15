-- Becak Rush: every tuning number, in one place.

local Config = {}

Config.LANE_X = { -7, 0, 7 }
Config.LANE_COUNT = 3
Config.ROAD_HALF_WIDTH = 13
Config.TRACK_SPACING = 90 -- studs between one player's track and the next

Config.BASE_SPEED = 26
Config.SPEED_PER_METRE = 0.045
Config.MAX_SPEED = 58
Config.CRASH_SPEED_PENALTY = 10
Config.PUDDLE_SLOW = 0.55
Config.PUDDLE_SLOW_SECONDS = 2.5

Config.SEGMENT_LENGTH = 30
Config.SEGMENT_COUNT = 14 -- 420 studs of road alive per track
Config.SPAWN_Z = -390 -- where traffic, coins and passengers appear
Config.DESPAWN_Z = 45 -- where they are removed, behind the player
Config.PLAYER_Z = 0 -- the becak stays at z = 0; the world scrolls past it

Config.MAX_HEARTS = 3
Config.INVULNERABLE_SECONDS = 2.5
Config.JUMP_SECONDS = 0.62
Config.JUMP_HEIGHT = 4.2
Config.JUMP_COOLDOWN = 0.25

Config.COIN_SCORE = 25
Config.COIN_COLLECT_RADIUS = 3.2
Config.PASSENGER_NAMES = { "Bu Siti", "Pak Budi", "Mbak Rina", "Mas Agus", "Dewi", "Pak Slamet", "Bu Ani", "Kak Fajar" }
Config.DELIVERY_FARE = 150
Config.PICKUP_RADIUS = 3.5
Config.DELIVER_RADIUS = 4

Config.COMBO_MAX = 5
Config.COMBO_WINDOW = 6 -- seconds without a scoring event before it resets
Config.NEAR_MISS_SCORE = 15

Config.TRAFFIC_WAVE_GAP_MIN = 26
Config.TRAFFIC_WAVE_GAP_MAX = 48
Config.CAR_SPEED_MIN = 6
Config.CAR_SPEED_MAX = 13
Config.ONCOMING_CHANCE = 0.35
Config.ONCOMING_SPEED_MIN = 9
Config.ONCOMING_SPEED_MAX = 16
Config.BUS_CHANCE = 0.22
Config.POTHOLE_CHANCE = 0.45
Config.PUDDLE_CHANCE = 0.3

Config.DAY_LENGTH_SECONDS = 240 -- one full day/night cycle
Config.DAY_START_HOUR = 8.5 -- runs start on a bright Jakarta morning
Config.RAIN_EVERY_MIN = 45
Config.RAIN_EVERY_MAX = 80
Config.RAIN_DURATION = 12

Config.SCORE_PER_METRE = 1
Config.MAX_TRACKS = 8 -- players beyond this wait for a free track

Config.PALETTE = {
	Road = Color3.fromRGB(52, 52, 58),
	RoadEdge = Color3.fromRGB(245, 245, 240),
	Sidewalk = Color3.fromRGB(168, 158, 140),
	Grass = Color3.fromRGB(86, 148, 84),
	BuildingA = Color3.fromRGB(232, 178, 120),
	BuildingB = Color3.fromRGB(126, 178, 196),
	BuildingC = Color3.fromRGB(198, 132, 132),
	BuildingD = Color3.fromRGB(244, 214, 140),
	WindowLit = Color3.fromRGB(255, 214, 120),
	WindowDark = Color3.fromRGB(70, 84, 96),
	Canopy = Color3.fromRGB(249, 115, 22),
	CanopyStripe = Color3.fromRGB(255, 255, 255),
	Body = Color3.fromRGB(15, 118, 110),
	Seat = Color3.fromRGB(146, 90, 48),
	Tire = Color3.fromRGB(30, 30, 34),
	Hub = Color3.fromRGB(220, 220, 220),
	Coin = Color3.fromRGB(251, 191, 36),
	PassengerRing = Color3.fromRGB(74, 222, 128),
	DestinationRing = Color3.fromRGB(251, 191, 36),
	Pothole = Color3.fromRGB(24, 24, 28),
	Puddle = Color3.fromRGB(96, 165, 250),
	CarColours = {
		Color3.fromRGB(220, 68, 68),
		Color3.fromRGB(68, 120, 220),
		Color3.fromRGB(245, 200, 60),
		Color3.fromRGB(120, 200, 120),
		Color3.fromRGB(200, 200, 200),
		Color3.fromRGB(150, 90, 200),
	},
	BusColour = Color3.fromRGB(30, 130, 90),
	LampGlow = Color3.fromRGB(255, 200, 110),
}

return Config
