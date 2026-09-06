-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Simple object-oriented Angle struct for rotation and angular calculations

-- Features:
-- Fast numeric storage (angle[1]); no hashing, raw lookup
-- Convenient field access (angle.rad, angle.deg)
-- Shorthand constructor; Angle(rad) instead of Angle.new(rad)
-- Automatic normalization to [-π, π] range
-- Built-in degree/radian conversion

-- Angle Functions:
-- Angle.from_deg(deg) - Create angle from degrees
-- Angle.from_rad(rad) - Create angle from radians (alias for constructor)
-- Angle.normalize(rad) - Normalize angle to [-π, π] range
-- Angle.lerp(a, b, t) - Linear interpolation between angles
-- Angle.slerp(a, b, t) - Spherical linear interpolation
-- Angle.shortest_distance(a, b) - Shortest angular distance
-- Angle.difference(a, b) - Signed angular difference

-- Localized global functions for better performance
local error, getmetatable, rawget, rawset, setmetatable, tonumber, tostring, type =
	error, getmetatable, rawget, rawset, setmetatable, tonumber, tostring, type
local math_abs, math_acos, math_asin, math_atan, math_atan2, math_ceil, math_cos, math_floor, math_max, math_min, math_random, math_sin, math_sqrt, math_tan =
	math.abs, math.acos, math.asin, math.atan, math.atan2, math.ceil, math.cos, math.floor, math.max, math.min,
	math.random, math.sin, math.sqrt, math.tan
local math_pi = math.pi
local string_format = string.format
local two_pi = 2 * math_pi
local DEG2RAD = math_pi / 180
local RAD2DEG = 180 / math_pi

local self = {}  -- module
local Angle = {} -- method table

---@class math.angle
---@field [1] number Angle value in radians (primary storage)
---@field rad number Angle value in radians (field access)
---@field deg number Angle value in degrees (computed field)

--- Create a new angle from radians
---@param rad number Angle in radians, defaults to 0
---@return math.angle angle A new angle object
local function Angle_new(rad)
	rad = tonumber(rad) or 0

	-- Normalize to [-π, π] range
	local normalized = rad % two_pi
	if normalized > math_pi then
		normalized = normalized - two_pi
	end

	return setmetatable({ normalized }, Angle)
end

self.new = Angle_new

--- Test whether an object is an Angle (by its metatable)
---@param obj any
---@return boolean
local function isangle(obj)
	return getmetatable(obj) == Angle
end

self.is = isangle

function Angle.__index(t, k)
	if k == 1 or k == "rad" then
		return rawget(t, 1)
	end
	if k == "deg" then
		return rawget(t, 1) * 180 / math_pi
	end
	return rawget(Angle, k)
end

function Angle.__newindex(t, k, v)
	if k == 1 or k == "rad" then
		local normalized = (tonumber(v) or 0) % two_pi
		if normalized > math_pi then
			normalized = normalized - two_pi
		end
		rawset(t, 1, normalized)
	elseif k == "deg" then
		local normalized = ((tonumber(v) or 0) * DEG2RAD) % two_pi
		if normalized > math_pi then
			normalized = normalized - two_pi
		end
		rawset(t, 1, normalized)
	else
		return error("Angle only supports 'rad' and 'deg' field assignment", 2)
	end
end

----------------------------------------------------------------------
-- Angle arithmetic metamethods
----------------------------------------------------------------------

--- Addition: angle + angle
function Angle.__add(a, b)
	if isangle(a) and isangle(b) then
		return Angle_new(a[1] + b[1])
	end
	if isangle(a) and type(b) == "number" then
		return Angle_new(a[1] + b)
	end
	if type(a) == "number" and isangle(b) then
		return Angle_new(a + b[1])
	end
	return error("Angle addition requires two angles or angle and number", 2)
end

--- Subtraction: angle - angle
function Angle.__sub(a, b)
	if isangle(a) and isangle(b) then
		return Angle_new(a[1] - b[1])
	end
	if isangle(a) and type(b) == "number" then
		return Angle_new(a[1] - b)
	end
	if type(a) == "number" and isangle(b) then
		return Angle_new(a - b[1])
	end
	return error("Angle subtraction requires two angles or angle and number", 2)
end

--- Multiplication: angle * number
function Angle.__mul(a, b)
	if isangle(a) and type(b) == "number" then
		return Angle_new(a[1] * b)
	end
	if type(a) == "number" and isangle(b) then
		return Angle_new(a * b[1])
	end
	return error("Angle multiplication requires angle and number", 2)
end

--- Division: angle / number
function Angle.__div(a, b)
	if isangle(a) and type(b) == "number" then
		if b == 0 then
			return error("Division by zero", 2)
		end
		return Angle_new(a[1] / b)
	end
	if type(a) == "number" and isangle(b) then
		if b[1] == 0 then
			return error("Division by zero", 2)
		end
		return Angle_new(a / b[1])
	end
	return error("Angle division requires angle and number", 2)
end

--- Negation: -angle
function Angle.__unm(a)
	if isangle(a) then
		return Angle_new(-a[1])
	end
	return error("Angle negation requires an angle", 2)
end

--- Equality check: a == b
function Angle.__eq(a, b)
	if not isangle(a) or not isangle(b) then
		return false
	end
	return a[1] == b[1]
end

--- Less than: a < b
function Angle.__lt(a, b)
	if not isangle(a) or not isangle(b) then
		return error("Angle comparison requires two angles", 2)
	end
	return a[1] < b[1]
end

--- Less than or equal: a <= b
function Angle.__le(a, b)
	if not isangle(a) or not isangle(b) then
		return error("Angle comparison requires two angles", 2)
	end
	return a[1] <= b[1]
end

--- Readable string representation
function Angle.__tostring(t)
	if not isangle(t) then
		return tostring(t)
	end
	return string_format("Angle(%.6g rad (%.6g°))", t[1], t[1] * RAD2DEG)
end

----------------------------------------------------------------------
-- Angle utility functions
----------------------------------------------------------------------

--- Create a shallow copy
---@param t math.angle
---@return math.angle
function Angle.clone(t)
	if not isangle(t) then
		return error("Angle.clone requires an angle", 2)
	end
	return Angle_new(t[1])
end

self.clone = Angle.clone

--- Create angle from degrees
---@param deg number Angle in degrees
---@return math.angle
function Angle.from_deg(deg)
	return Angle_new((tonumber(deg) or 0) * DEG2RAD)
end

self.from_deg = Angle.from_deg

--- Create angle from radians (alias for constructor)
---@param rad number Angle in radians
---@return math.angle
function Angle.from_rad(rad)
	return Angle_new(rad)
end

self.from_rad = Angle.from_rad

--- Normalize angle to [-π, π] range
---@param rad number Angle in radians
---@return number normalized Normalized angle in radians
function Angle.normalize(rad)
	local normalized = (tonumber(rad) or 0) % two_pi
	if normalized > math_pi then
		normalized = normalized - two_pi
	end
	return normalized
end

self.normalize = Angle.normalize

--- Get sine of angle
---@param t math.angle
---@return number
function Angle.sin(t)
	if not isangle(t) then
		return error("Angle.sin requires an angle", 2)
	end
	return math_sin(t[1])
end

self.sin = Angle.sin

--- Get cosine of angle
---@param t math.angle
---@return number
function Angle.cos(t)
	if not isangle(t) then
		return error("Angle.cos requires an angle", 2)
	end
	return math_cos(t[1])
end

self.cos = Angle.cos

--- Get tangent of angle
---@param t math.angle
---@return number
function Angle.tan(t)
	if not isangle(t) then
		return error("Angle.tan requires an angle", 2)
	end
	return math_tan(t[1])
end

self.tan = Angle.tan

--- Get arcsine of value as angle
---@param value number Value between -1 and 1
---@return math.angle
function Angle.asin(value)
	value = tonumber(value) or 0
	if value < -1 or value > 1 then
		return error("Angle.asin requires value between -1 and 1", 2)
	end
	return Angle_new(math_asin(value))
end

self.asin = Angle.asin

--- Get arccosine of value as angle
---@param value number Value between -1 and 1
---@return math.angle
function Angle.acos(value)
	value = tonumber(value) or 0
	if value < -1 or value > 1 then
		return error("Angle.acos requires value between -1 and 1", 2)
	end
	return Angle_new(math_acos(value))
end

self.acos = Angle.acos

--- Get arctangent of value as angle
---@param value number
---@return math.angle
function Angle.atan(value)
	value = tonumber(value) or 0
	return Angle_new(math_atan(value))
end

self.atan = Angle.atan

--- Get arctangent2 of y,x as angle
---@param y number
---@param x number
---@return math.angle
function Angle.atan2(y, x)
	y = tonumber(y) or 0
	x = tonumber(x) or 0
	return Angle_new(math_atan2(y, x))
end

self.atan2 = Angle.atan2

--- Linear interpolation between two angles
---@param a math.angle Start angle
---@param b math.angle End angle
---@param t number Interpolation factor [0, 1]
---@return math.angle
function Angle.lerp(a, b, t)
	if not isangle(a) or not isangle(b) then
		return error("Angle.lerp requires two angles", 2)
	end
	t = tonumber(t) or 0

	-- Handle wrapping for shortest path
	local diff = Angle.shortest_distance(a, b)
	return Angle_new(a[1] + diff * t)
end

self.lerp = Angle.lerp

--- Spherical linear interpolation between two angles
---@param a math.angle Start angle
---@param b math.angle End angle
---@param t number Interpolation factor [0, 1]
---@return math.angle
function Angle.slerp(a, b, t)
	if not isangle(a) or not isangle(b) then
		return error("Angle.slerp requires two angles", 2)
	end
	t = tonumber(t) or 0

	-- Calculate dot product (cosine of angle between)
	local dot = math_cos(a[1] - b[1])

	-- Clamp to prevent numerical errors
	dot = math_max(-1, math_min(1, dot))

	-- Calculate angle between
	local theta = math_acos(dot)

	if theta == 0 then
		return Angle_new(a[1]) -- Angles are the same
	end

	-- Calculate interpolation
	local sin_theta = math_sin(theta)
	local weight_a = math_sin((1 - t) * theta) / sin_theta
	local weight_b = math_sin(t * theta) / sin_theta

	-- Interpolate in 2D space
	local x_a = math_cos(a[1])
	local y_a = math_sin(a[1])
	local x_b = math_cos(b[1])
	local y_b = math_sin(b[1])

	local x = x_a * weight_a + x_b * weight_b
	local y = y_a * weight_a + y_b * weight_b

	return Angle_new(math_atan2(y, x))
end

self.slerp = Angle.slerp

--- Get shortest angular distance between two angles
---@param a math.angle First angle
---@param b math.angle Second angle
---@return number dist Shortest distance in radians
function Angle.shortest_distance(a, b)
	if not isangle(a) or not isangle(b) then
		return error("Angle.shortest_distance requires two angles", 2)
	end

	local diff = (b[1] - a[1]) % two_pi
	if diff > math_pi then
		diff = diff - two_pi
	end

	return diff
end

self.shortest_distance = Angle.shortest_distance

--- Get signed angular difference (a to b)
---@param a math.angle Start angle
---@param b math.angle End angle
---@return number diff Signed difference in radians
function Angle.difference(a, b)
	if not isangle(a) or not isangle(b) then
		return error("Angle.difference requires two angles", 2)
	end

	local diff = (b[1] - a[1]) % two_pi
	if diff > math_pi then
		diff = diff - two_pi
	end

	return diff
end

self.difference = Angle.difference

--- Check if two angles are approximately equal (within epsilon)
---@param a math.angle First angle
---@param b math.angle Second angle
---@param epsilon? number Optional epsilon in radians, defaults to 1e-6
---@return boolean
function Angle.is_near(a, b, epsilon)
	if not isangle(a) or not isangle(b) then
		return error("Angle.is_near requires two angles", 2)
	end
	epsilon = epsilon or 1e-6
	return math_abs(Angle.shortest_distance(a, b)) < epsilon
end

self.is_near = Angle.is_near

--- Clamp angle to range
---@param t math.angle Angle to clamp
---@param min math.angle|number Minimum angle (angle or radians)
---@param max math.angle|number Maximum angle (angle or radians)
---@return math.angle
function Angle.clamp(t, min, max)
	if not isangle(t) then
		return error("Angle.clamp requires an angle", 2)
	end

	-- Convert min/max to radians
	local min_rad = isangle(min) and min[1] or tonumber(min) or -math_pi
	local max_rad = isangle(max) and max[1] or tonumber(max) or math_pi

	local clamped = t[1]
	if clamped < min_rad then
		clamped = min_rad
	elseif clamped > max_rad then
		clamped = max_rad
	end

	return Angle_new(clamped)
end

self.clamp = Angle.clamp

--- Get absolute value of angle
---@param t math.angle
---@return math.angle
function Angle.abs(t)
	if not isangle(t) then
		return error("Angle.abs requires an angle", 2)
	end
	return Angle_new(math_abs(t[1]))
end

self.abs = Angle.abs

--- Convert angle to table
---@param t math.angle
---@return table {rad, deg}
function Angle.to_table(t)
	if not isangle(t) then
		return error("Angle.to_table requires an angle", 2)
	end
	return {
		rad = t[1],
		deg = t[1] * RAD2DEG
	}
end

self.to_table = Angle.to_table

--- Create angle from table
---@param tbl table Table with rad or deg key
---@return math.angle
function Angle.from_table(tbl)
	if type(tbl) ~= "table" then
		return error("Angle.from_table requires a table", 2)
	end

	if tbl.rad ~= nil then
		return Angle_new(tonumber(tbl.rad) or 0)
	elseif tbl.deg ~= nil then
		return Angle.from_deg(tonumber(tbl.deg) or 0)
	else
		return Angle_new(0)
	end
end

self.from_table = Angle.from_table

-- Export
return setmetatable(self, {
	__call = function(_, ...)
		return Angle_new(...)
	end
})
