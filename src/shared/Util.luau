-- Becak Rush: small pure helpers shared by server and client.

local Util = {}

function Util.clamp(value: number, low: number, high: number): number
	if value < low then
		return low
	elseif value > high then
		return high
	else
		return value
	end
end

function Util.moveTowards(current: number, target: number, maxStep: number): number
	if math.abs(target - current) <= maxStep then
		return target
	elseif target > current then
		return current + maxStep
	else
		return current - maxStep
	end
end

function Util.jumpHeight(t: number, peak: number): number
	return 4 * peak * t * (1 - t)
end

function Util.pickOne<T>(list: { T }, rng: Random): T
	return list[rng:NextInteger(1, #list)]
end

function Util.formatNumber(n: number): string
	local s = tostring(math.floor(n))
	local out = ""
	while #s > 3 do
		out = "," .. string.sub(s, -3) .. out
		s = string.sub(s, 1, #s - 3)
	end
	return s .. out
end

function Util.formatDistance(metres: number): string
	if metres >= 1000 then
		return string.format("%.1f km", metres / 1000)
	else
		return string.format("%d m", math.floor(metres))
	end
end

function Util.formatTime(seconds: number): string
	return string.format("%d:%02d", math.floor(seconds / 60), math.floor(seconds % 60))
end

function Util.formatFare(name: string, fare: number): string
	return name .. " +Rp" .. Util.formatNumber(fare)
end

return Util
