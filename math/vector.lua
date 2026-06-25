-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Simple object-oriented 3D Vector struct

-- Features:
-- Fast numeric storage (vec[1], vec[2], vec[3]); no hashing, raw lookup
-- Convenient field access (vec.x, vec.y, vec.z)
-- Shorthand constructor; Vector(1, 2, 3) instead of Vector.new(1, 2, 3)

-- Distance Functions:
-- Vector.distance(a, b) - Euclidean distance (L2 norm)
-- Vector.distance_squared(a, b) - Squared Euclidean distance (faster, avoids sqrt)
-- Vector.distance_manhattan(a, b) - Manhattan distance (L1 norm)
-- Vector.distance_chebyshev(a, b) - Chebyshev distance (L∞ norm)
-- Vector.distance_minkowski(a, b, p) - Minkowski distance (Lp norm, p >= 1)
--  - p=1: Manhattan, p=2: Euclidean, p=∞: Chebyshev

-- Localized global functions for better performance
local error, getmetatable, rawget, rawset, setmetatable, tonumber, tostring, type =
	error, getmetatable, rawget, rawset, setmetatable, tonumber, tostring, type
local math_abs, math_acos, math_asin, math_atan2, math_ceil, math_cos, math_floor, math_random, math_sin, math_sqrt =
	math.abs, math.acos, math.asin, math.atan2, math.ceil, math.cos, math.floor, math.random, math.sin, math.sqrt
local math_pi = math.pi
local string_format = string.format

----------------------------------------------------------------------
-- Coordinate System Configuration
----------------------------------------------------------------------

---@class math.CoordinateSystem
---@field handedness "left"|"right" Coordinate system handedness
---@field up_axis "x"|"y"|"z" Which axis represents up
---@field forward_axis "x"|"y"|"z" Which axis represents forward
---@field name string Display name for this coordinate system

--- Engine-specific coordinate system presets
---@type table<string, math.CoordinateSystem>
local COORD_SYSTEMS = {
	unreal = { -- (+Y is right)
		handedness = "left",
		up_axis = "z",
		forward_axis = "x",
		name = "unreal"
	},
	source = { -- quake (+Y is left)
		handedness = "left",
		up_axis = "z",
		forward_axis = "x",
		name = "source"
	},
	unity = {
		handedness = "left",
		up_axis = "y",
		forward_axis = "z",
		name = "unity"
	},
	godot = {
		handedness = "right",
		up_axis = "y",
		forward_axis = "z", -- negative Z
		name = "godot"
	},
	blender = {
		handedness = "right",
		up_axis = "z",
		forward_axis = "y", -- negative Y
		name = "blender"
	}
}

---@type math.CoordinateSystem
local current_coord_system = COORD_SYSTEMS.unreal

---@class math.vector
---@field [1] number X component
---@field [2] number Y component
---@field [3] number Z component
---@field x number X component
---@field y number Y component
---@field z number Z component

local self = {}   -- module
local Vector = {} -- method table

---@return math.vector vector A new 3D vector object
local function Vector_new(x, y, z)
	x = tonumber(x) or 0
	return setmetatable({ x, tonumber(y) or x, tonumber(z) or x }, Vector)
end

self.new = Vector_new

self.zero = Vector_new()
self.one = Vector_new(1)
self.unit_x = Vector_new(1, 0, 0)
self.unit_y = Vector_new(0, 1, 0)
self.unit_z = Vector_new(0, 0, 1)

local cross_left_handed, cross_right_handed

--- Cross product: a × b (left-handed)
---@param a math.vector
---@param b math.vector
---@return math.vector
function cross_left_handed(a, b)
	-- Left-handed cross product
	return Vector_new(
		a[3] * b[2] - a[2] * b[3],
		a[1] * b[3] - a[3] * b[1],
		a[2] * b[1] - a[1] * b[2]
	)
end

--- Cross product: a × b (right-handed)
---@param a math.vector
---@param b math.vector
---@return math.vector
function cross_right_handed(a, b)
	-- Right-handed cross product (negated)
	return Vector_new(
		a[2] * b[3] - a[3] * b[2],
		a[3] * b[1] - a[1] * b[3],
		a[1] * b[2] - a[2] * b[1]
	)
end

-- Initialize cross product function for default handedness
if current_coord_system.handedness == "left" then
	Vector.cross = cross_left_handed
else
	Vector.cross = cross_right_handed
end

self.cross = Vector.cross

-- Direction vectors (automatically updated based on coordinate system)
local function update_direction_vectors()
	local cs = current_coord_system
	local forward, right, up

	-- Set forward direction
	if cs.forward_axis == "x" then
		forward = Vector_new(1, 0, 0)
	elseif cs.forward_axis == "y" then
		forward = Vector_new(0, 1, 0)
	else -- z
		forward = Vector_new(0, 0, 1)
	end

	-- Set up direction
	if cs.up_axis == "x" then
		up = Vector_new(1, 0, 0)
	elseif cs.up_axis == "y" then
		up = Vector_new(0, 1, 0)
	else -- z
		up = Vector_new(0, 0, 1)
	end

	-- Calculate right direction using cross product (respects handedness)
	right = Vector.cross(forward, up)

	-- Update module direction vectors
	self.forward = forward
	self.back = forward * -1
	self.right = right
	self.left = right * -1
	self.up = up
	self.down = up * -1
end

--- Test whether an object is a Vector (by its metatable)
---@param obj any
---@return boolean
local function isvector(obj)
	return getmetatable(obj) == Vector
end

self.is = isvector

function Vector.__index(t, k)
	-- Try to access properties first
	-- TODO: benchmark this vs. lookup/dispatch table
	if k == "x" then
		return rawget(t, 1)
	end
	if k == "y" then
		return rawget(t, 2)
	end
	if k == "z" then
		return rawget(t, 3)
	end
	-- Otherwise, fallback to accessing the method table
	return rawget(Vector, k)
end

function Vector.__newindex(t, k, v)
	-- TODO: benchmark this vs. lookup/dispatch table
	if k == "x" then
		return rawset(t, 1, v) -- tailcall
	end
	if k == "y" then
		return rawset(t, 2, v) -- tailcall
	end
	if k == "z" then
		return rawset(t, 3, v) -- tailcall
	end
	return rawset(t, k, v) -- tailcall
end

----------------------------------------------------------------------
-- Vector arithmetic metamethods
----------------------------------------------------------------------

--- Addition: a + b
function Vector.__add(a, b)
	if not isvector(a) or not isvector(b) then
		return error("Vector addition requires two vectors", 2)
	end
	return Vector_new(a[1] + b[1], a[2] + b[2], a[3] + b[3])
end

--- Subtraction: a - b
function Vector.__sub(a, b)
	if not isvector(a) or not isvector(b) then
		return error("Vector subtraction requires two vectors", 2)
	end
	return Vector_new(a[1] - b[1], a[2] - b[2], a[3] - b[3])
end

--- Scalar multiplication: vec * scalar or scalar * vec
function Vector.__mul(a, b)
	if type(a) == "number" then -- scalar * vec
		if not isvector(b) then
			return error("Vector multiplication requires a vector and a number", 2)
		end
		a, b = b, a
	elseif not isvector(a) then
		return error("Vector multiplication requires a vector and a number", 2)
	end
	if type(b) ~= "number" then
		return error("Vector multiplication requires a vector and a number", 2)
	end
	return Vector_new(a[1] * b, a[2] * b, a[3] * b)
end

--- Scalar division: vec / scalar
function Vector.__div(a, b)
	if not isvector(a) then
		return error("Vector division requires a vector", 2)
	end
	if type(b) ~= "number" then
		return error("Vector division requires a number", 2)
	end
	if b == 0 then
		return error("Vector division by zero", 2)
	end
	return Vector_new(a[1] / b, a[2] / b, a[3] / b)
end

--- Negation: -vec
function Vector.__unm(a)
	if not isvector(a) then
		return error("Vector negation requires a vector", 2)
	end
	return Vector_new(-a[1], -a[2], -a[3])
end

--- Length operator: #vec
function Vector.__len(t)
	if not isvector(t) then
		return error("Length operator requires a vector", 2)
	end
	return math_sqrt(t[1] * t[1] + t[2] * t[2] + t[3] * t[3])
end

--- Readable string representation
function Vector.__tostring(t)
	if not isvector(t) then
		return tostring(t)
	end
	return string_format("Vector(%.6g, %.6g, %.6g)", t[1], t[2], t[3])
end

--- Concatenation: vec1 .. vec2
function Vector.__concat(a, b)
	if isvector(a) and isvector(b) then
		return string_format("Vector(%.6g, %.6g, %.6g) + Vector(%.6g, %.6g, %.6g)", a[1], a[2], a[3], b[1], b[2], b[3])
	end
	-- Fallback for non-vector concatenation
	return tostring(a) .. tostring(b)
end

--- Equality check: a == b
function Vector.__eq(a, b)
	if not isvector(a) or not isvector(b) then
		return false
	end
	return a[1] == b[1] and a[2] == b[2] and a[3] == b[3]
end

--- Less than comparison: a < b (compares by squared magnitude)
function Vector.__lt(a, b)
	if not isvector(a) or not isvector(b) then
		return error("Vector comparison requires two vectors", 2)
	end
	return (a[1] * a[1] + a[2] * a[2] + a[3] * a[3]) < (b[1] * b[1] + b[2] * b[2] + b[3] * b[3])
end

--- Less than or equal comparison: a <= b (compares by squared magnitude)
function Vector.__le(a, b)
	if not isvector(a) or not isvector(b) then
		return error("Vector comparison requires two vectors", 2)
	end
	return (a[1] * a[1] + a[2] * a[2] + a[3] * a[3]) <= (b[1] * b[1] + b[2] * b[2] + b[3] * b[3])
end

--- Greater than comparison: a > b (compares by squared magnitude)
function Vector.__gt(a, b)
	if not isvector(a) or not isvector(b) then
		return error("Vector comparison requires two vectors", 2)
	end
	return (a[1] * a[1] + a[2] * a[2] + a[3] * a[3]) > (b[1] * b[1] + b[2] * b[2] + b[3] * b[3])
end

--- Greater than or equal comparison: a >= b (compares by squared magnitude)
function Vector.__ge(a, b)
	if not isvector(a) or not isvector(b) then
		return error("Vector comparison requires two vectors", 2)
	end
	return (a[1] * a[1] + a[2] * a[2] + a[3] * a[3]) >= (b[1] * b[1] + b[2] * b[2] + b[3] * b[3])
end

----------------------------------------------------------------------
-- Vector utility functions
----------------------------------------------------------------------

--- Create a shallow copy
---@return math.vector
function Vector.clone(t)
	if not isvector(t) then
		return error("Vector.clone requires a vector", 2)
	end
	return Vector_new(t[1], t[2], t[3])
end

self.clone = Vector.clone

--- Set components of an existing vector (modifies self)
---@param t math.vector
---@param x number
---@param y number
---@param z number
---@return math.vector
function Vector.set(t, x, y, z)
	if not isvector(t) then
		return error("Vector.set requires a vector", 2)
	end
	t[1], t[2], t[3] = x, y, z
	return t
end

self.set = Vector.set

--- Unpack vector components
---@param t math.vector
---@return number x
---@return number y
---@return number z
function Vector.unpack(t)
	if not isvector(t) then
		return error("Vector.unpack requires a vector", 2)
	end
	return t[1], t[2], t[3]
end

self.unpack = Vector.unpack

--- Dot product: a · b
---@param a math.vector
---@param b math.vector
---@return number
function Vector.dot(a, b)
	if not isvector(a) or not isvector(b) then
		return error("Vector.dot requires two vectors", 2)
	end
	return a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
end

self.dot = Vector.dot

--- Get Euclidean length (magnitude)
---@param t math.vector
---@return number
function Vector.length(t)
	if not isvector(t) then
		return error("Vector.length requires a vector", 2)
	end
	return math_sqrt(t[1] * t[1] + t[2] * t[2] + t[3] * t[3])
end

self.length = Vector.length

--- Get squared length (faster, avoids expensive sqrt)
---@param t math.vector
---@return number
function Vector.length_squared(t)
	if not isvector(t) then
		return error("Vector.length_squared requires a vector", 2)
	end
	return t[1] * t[1] + t[2] * t[2] + t[3] * t[3]
end

self.length_squared = Vector.length_squared

--- Normalize in-place (modifies self, returns self)
---@param t math.vector
---@return math.vector
function Vector.normalize(t)
	if not isvector(t) then
		return error("Vector.normalize requires a vector", 2)
	end
	local len = t[1] * t[1] + t[2] * t[2] + t[3] * t[3]
	if len ~= 0 then
		len = math_sqrt(len)
		t[1], t[2], t[3] = t[1] / len, t[2] / len, t[3] / len
	end
	return t
end

self.normalize = Vector.normalize

--- Return a new normalized vector (does not modify self)
---@param t math.vector
---@return math.vector
function Vector.normalized(t)
	if not isvector(t) then
		return error("Vector.normalized requires a vector", 2)
	end
	local len = t[1] * t[1] + t[2] * t[2] + t[3] * t[3]
	if len == 0 then
		return Vector_new()
	end
	len = math_sqrt(len)
	return Vector_new(t[1] / len, t[2] / len, t[3] / len)
end

self.normalized = Vector.normalized

--- Interpolate linearly between a and b by factor t (t in [0,1])
---@param a math.vector
---@param b math.vector
---@param t number
---@return math.vector
function Vector.lerp(a, b, t)
	if not isvector(a) or not isvector(b) then
		return error("Vector.lerp requires two vectors", 2)
	end
	return Vector_new(
		a[1] + (b[1] - a[1]) * t,
		a[2] + (b[2] - a[2]) * t,
		a[3] + (b[3] - a[3]) * t
	)
end

self.lerp = Vector.lerp

--- Distance between two vectors
---@param a math.vector
---@param b math.vector
---@return number
function Vector.distance(a, b)
	if not isvector(a) or not isvector(b) then
		return error("Vector.distance requires two vectors", 2)
	end
	local dx, dy, dz = a[1] - b[1], a[2] - b[2], a[3] - b[3]
	return math_sqrt(dx * dx + dy * dy + dz * dz)
end

self.distance = Vector.distance

--- Squared distance between two vectors (faster, avoids expensive sqrt)
---@param a math.vector
---@param b math.vector
---@return number
function Vector.distance_squared(a, b)
	if not isvector(a) or not isvector(b) then
		return error("Vector.distance_squared requires two vectors", 2)
	end
	local dx, dy, dz = a[1] - b[1], a[2] - b[2], a[3] - b[3]
	return dx * dx + dy * dy + dz * dz
end

self.distance_squared = Vector.distance_squared

--- Manhattan distance (L1 norm) between two vectors
---@param a math.vector
---@param b math.vector
---@return number
function Vector.distance_manhattan(a, b)
	if not isvector(a) or not isvector(b) then
		return error("Vector.distance_manhattan requires two vectors", 2)
	end
	return math_abs(a[1] - b[1]) + math_abs(a[2] - b[2]) + math_abs(a[3] - b[3])
end

self.distance_manhattan = Vector.distance_manhattan

--- Chebyshev distance (L∞ norm) between two vectors
---@param a math.vector
---@param b math.vector
---@return number
function Vector.distance_chebyshev(a, b)
	if not isvector(a) or not isvector(b) then
		return error("Vector.distance_chebyshev requires two vectors", 2)
	end
	local dx = math_abs(a[1] - b[1])
	local dy = math_abs(a[2] - b[2])
	local dz = math_abs(a[3] - b[3])
	return math_max(dx, math_max(dy, dz))
end

self.distance_chebyshev = Vector.distance_chebyshev

--- Minkowski distance (Lp norm) between two vectors
---@param a math.vector
---@param b math.vector
---@param p number Order parameter (p >= 1), defaults to 2 (Euclidean)
---@return number
function Vector.distance_minkowski(a, b, p)
	if not isvector(a) or not isvector(b) then
		return error("Vector.distance_minkowski requires two vectors", 2)
	end
	p = tonumber(p) or 2
	if p < 1 then
		return error("Minkowski distance requires p >= 1", 2)
	end

	local dx = math_abs(a[1] - b[1])
	local dy = math_abs(a[2] - b[2])
	local dz = math_abs(a[3] - b[3])

	if p == 1 then
		return dx + dy + dz                     -- Manhattan
	elseif p == 2 then
		return math_sqrt(dx * dx + dy * dy + dz * dz) -- Euclidean
	elseif p == math.huge or p == 1 / 0 then
		return math_max(dx, math_max(dy, dz))   -- Chebyshev
	else
		return (dx ^ p + dy ^ p + dz ^ p) ^ (1 / p)
	end
end

self.distance_minkowski = Vector.distance_minkowski

--- Angle between two vectors in radians
---@param a math.vector
---@param b math.vector
---@return number
function Vector.angle(a, b)
	if not isvector(a) or not isvector(b) then
		return error("Vector.angle requires two vectors", 2)
	end
	local dot = a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
	local len_a = math_sqrt(a[1] * a[1] + a[2] * a[2] + a[3] * a[3])
	local len_b = math_sqrt(b[1] * b[1] + b[2] * b[2] + b[3] * b[3])
	if len_a == 0 or len_b == 0 then
		return 0
	end
	local cos_angle = dot / (len_a * len_b)
	cos_angle = cos_angle > 1 and 1 or (cos_angle < -1 and -1 or cos_angle)
	return math_acos(cos_angle)
end

self.angle = Vector.angle

--- Project vector a onto vector b
---@param a math.vector
---@param b math.vector
---@return math.vector
function Vector.project(a, b)
	if not isvector(a) or not isvector(b) then
		return error("Vector.project requires two vectors", 2)
	end
	local len_sq = b[1] * b[1] + b[2] * b[2] + b[3] * b[3]
	if len_sq == 0 then
		return Vector_new()
	end
	local dot = a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
	local scale = dot / len_sq
	return Vector_new(b[1] * scale, b[2] * scale, b[3] * scale)
end

self.project = Vector.project

--- Reflect vector across a normal
---@param vec math.vector
---@param normal math.vector
---@return math.vector
function Vector.reflect(vec, normal)
	if not isvector(vec) or not isvector(normal) then
		return error("Vector.reflect requires two vectors", 2)
	end
	local dot = vec[1] * normal[1] + vec[2] * normal[2] + vec[3] * normal[3]
	return Vector_new(
		vec[1] - 2 * dot * normal[1],
		vec[2] - 2 * dot * normal[2],
		vec[3] - 2 * dot * normal[3]
	)
end

self.reflect = Vector.reflect

--- Clamp vector magnitude to a maximum length
---@param vec math.vector
---@param max_len number
---@return math.vector
function Vector.clamp_length(vec, max_len)
	if max_len < 0 then
		max_len = 0
	end
	local len_sq = vec[1] * vec[1] + vec[2] * vec[2] + vec[3] * vec[3]
	if len_sq <= max_len * max_len then
		return Vector_new(vec[1], vec[2], vec[3])
	end
	local len = math_sqrt(len_sq)
	if len == 0 then
		return Vector_new()
	end
	local scale = max_len / len
	return Vector_new(vec[1] * scale, vec[2] * scale, vec[3] * scale)
end

self.clamp_length = Vector.clamp_length

--- Check if vector is approximately zero (within epsilon)
---@param vec math.vector
---@param epsilon number|nil Optional epsilon, defaults to 1e-6
---@return boolean
function Vector.is_zero(vec, epsilon)
	if not isvector(vec) then
		return error("Vector.is_zero requires a vector", 2)
	end
	epsilon = epsilon or 1e-6
	local len_sq = vec[1] * vec[1] + vec[2] * vec[2] + vec[3] * vec[3]
	return len_sq < epsilon * epsilon
end

self.is_zero = Vector.is_zero

--- Check if two vectors are approximately equal (within epsilon)
---@param a math.vector
---@param b math.vector
---@param epsilon number|nil Optional epsilon, defaults to 1e-6
---@return boolean
function Vector.is_near(a, b, epsilon)
	if not isvector(a) or not isvector(b) then
		return error("Vector.is_near requires two vectors", 2)
	end
	epsilon = epsilon or 1e-6
	local dx, dy, dz = a[1] - b[1], a[2] - b[2], a[3] - b[3]
	return (dx * dx + dy * dy + dz * dz) < epsilon * epsilon
end

self.is_near = Vector.is_near

--- Move current vector towards target by max_delta
---@param current math.vector
---@param target math.vector
---@param max_delta number
---@return math.vector
function Vector.move_towards(current, target, max_delta)
	if not isvector(current) or not isvector(target) then
		return error("Vector.move_towards requires two vectors", 2)
	end
	local dx, dy, dz = target[1] - current[1], target[2] - current[2], target[3] - current[3]
	local dist_sq = dx * dx + dy * dy + dz * dz
	if dist_sq <= max_delta * max_delta or dist_sq == 0 then
		return Vector_new(target[1], target[2], target[3])
	end
	local dist = math_sqrt(dist_sq)
	local scale = max_delta / dist
	return Vector_new(
		current[1] + dx * scale,
		current[2] + dy * scale,
		current[3] + dz * scale
	)
end

self.move_towards = Vector.move_towards

--- Absolute value of vector components
---@param t math.vector
---@return math.vector
function Vector.abs(t)
	if not isvector(t) then
		return error("Vector.abs requires a vector", 2)
	end
	return Vector_new(
		t[1] >= 0 and t[1] or -t[1],
		t[2] >= 0 and t[2] or -t[2],
		t[3] >= 0 and t[3] or -t[3]
	)
end

self.abs = Vector.abs

--- Minimum of two vectors (component-wise)
---@param a math.vector
---@param b math.vector
---@return math.vector
function Vector.min(a, b)
	if not isvector(a) or not isvector(b) then
		return error("Vector.min requires two vectors", 2)
	end
	return Vector_new(
		a[1] < b[1] and a[1] or b[1],
		a[2] < b[2] and a[2] or b[2],
		a[3] < b[3] and a[3] or b[3]
	)
end

self.min = Vector.min

--- Maximum of two vectors (component-wise)
---@param a math.vector
---@param b math.vector
---@return math.vector
function Vector.max(a, b)
	if not isvector(a) or not isvector(b) then
		return error("Vector.max requires two vectors", 2)
	end
	return Vector_new(
		a[1] > b[1] and a[1] or b[1],
		a[2] > b[2] and a[2] or b[2],
		a[3] > b[3] and a[3] or b[3]
	)
end

self.max = Vector.max

--- Rotate vector around an axis by angle (in radians)
---@param vec math.vector
---@param axis math.vector Must be normalized
---@param angle number Rotation angle in radians
---@return math.vector
function Vector.rotate_around(vec, axis, angle)
	if not isvector(vec) or not isvector(axis) then
		return error("Vector.rotate_around requires two vectors", 2)
	end
	local cos_a = math_cos(angle)
	local sin_a = math_sin(angle)
	local dot = vec[1] * axis[1] + vec[2] * axis[2] + vec[3] * axis[3]
	local cross_x = axis[2] * vec[3] - axis[3] * vec[2]
	local cross_y = axis[3] * vec[1] - axis[1] * vec[3]
	local cross_z = axis[1] * vec[2] - axis[2] * vec[1]
	return Vector_new(
		vec[1] * cos_a + cross_x * sin_a + axis[1] * dot * (1 - cos_a),
		vec[2] * cos_a + cross_y * sin_a + axis[2] * dot * (1 - cos_a),
		vec[3] * cos_a + cross_z * sin_a + axis[3] * dot * (1 - cos_a)
	)
end

self.rotate_around = Vector.rotate_around

--- Spherical linear interpolation between a and b by factor t (t in [0,1])
---@param a math.vector
---@param b math.vector
---@param t number
---@return math.vector
function Vector.slerp(a, b, t)
	if not isvector(a) or not isvector(b) then
		return error("Vector.slerp requires two vectors", 2)
	end
	local dot = a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
	dot = dot > 1 and 1 or (dot < -1 and -1 or dot)
	local acos_dot = math_acos(dot)
	local theta = acos_dot * t
	local sin_theta = math_sin(theta)
	local sin_total = math_sqrt(1 - dot * dot)
	if sin_total < 1e-6 then
		return Vector.lerp(a, b, t)
	end
	local scale_a = math_sin((1 - t) * acos_dot) / sin_total
	local scale_b = sin_theta / sin_total
	return Vector_new(
		a[1] * scale_a + b[1] * scale_b,
		a[2] * scale_a + b[2] * scale_b,
		a[3] * scale_a + b[3] * scale_b
	)
end

self.slerp = Vector.slerp

--- Reject vector a from vector b (perpendicular component)
---@param a math.vector
---@param b math.vector
---@return math.vector
function Vector.reject(a, b)
	if not isvector(a) or not isvector(b) then
		return error("Vector.reject requires two vectors", 2)
	end
	local len_sq = b[1] * b[1] + b[2] * b[2] + b[3] * b[3]
	if len_sq == 0 then
		return Vector_new()
	end
	local dot = a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
	local scale = dot / len_sq
	return Vector_new(
		a[1] - b[1] * scale,
		a[2] - b[2] * scale,
		a[3] - b[3] * scale
	)
end

self.reject = Vector.reject

--- Clamp each component individually between min and max values
---@param vec math.vector
---@param min_vec math.vector
---@param max_vec math.vector
---@return math.vector
function Vector.clamp(vec, min_vec, max_vec)
	if not isvector(vec) or not isvector(min_vec) or not isvector(max_vec) then
		return error("Vector.clamp requires three vectors", 2)
	end
	return Vector_new(
		vec[1] < min_vec[1] and min_vec[1] or (vec[1] > max_vec[1] and max_vec[1] or vec[1]),
		vec[2] < min_vec[2] and min_vec[2] or (vec[2] > max_vec[2] and max_vec[2] or vec[2]),
		vec[3] < min_vec[3] and min_vec[3] or (vec[3] > max_vec[3] and max_vec[3] or vec[3])
	)
end

self.clamp = Vector.clamp

--- Floor each component
---@param t math.vector
---@return math.vector
function Vector.floor(t)
	if not isvector(t) then
		return error("Vector.floor requires a vector", 2)
	end
	return Vector_new(math_floor(t[1]), math_floor(t[2]), math_floor(t[3]))
end

self.floor = Vector.floor

--- Ceil each component
---@param t math.vector
---@return math.vector
function Vector.ceil(t)
	if not isvector(t) then
		return error("Vector.ceil requires a vector", 2)
	end
	return Vector_new(math_ceil(t[1]), math_ceil(t[2]), math_ceil(t[3]))
end

self.ceil = Vector.ceil

--- Round each component
---@param t math.vector
---@return math.vector
function Vector.round(t)
	if not isvector(t) then
		return error("Vector.round requires a vector", 2)
	end
	return Vector_new(math_floor(t[1] + 0.5), math_floor(t[2] + 0.5), math_floor(t[3] + 0.5))
end

self.round = Vector.round

--- Generate a random unit vector
---@return math.vector
function Vector.random_unit()
	local theta = math_random() * 2 * math_pi
	local phi = math_acos(2 * math_random() - 1)
	return Vector_new(
		math_sin(phi) * math_cos(theta),
		math_sin(phi) * math_sin(theta),
		math_cos(phi)
	)
end

self.random_unit = Vector.random_unit

--- Generate a random vector within a range
---@param min_val number Minimum value for each component
---@param max_val number Maximum value for each component
---@return math.vector
function Vector.random(min_val, max_val)
	return Vector_new(
		math_random() * (max_val - min_val) + min_val,
		math_random() * (max_val - min_val) + min_val,
		math_random() * (max_val - min_val) + min_val
	)
end

self.random = Vector.random

--- Get a perpendicular vector in the XY plane (ignores Z)
---@param t math.vector
---@return math.vector
function Vector.perpendicular_2d(t)
	if not isvector(t) then
		return error("Vector.perpendicular_2d requires a vector", 2)
	end
	return Vector_new(-t[2], t[1], 0)
end

self.perpendicular_2d = Vector.perpendicular_2d

--- Convert vector to array
---@param t math.vector
---@return number[]
function Vector.to_array(t)
	if not isvector(t) then
		return error("Vector.to_array requires a vector", 2)
	end
	return { t[1], t[2], t[3] }
end

self.to_array = Vector.to_array

--- Convert vector to table
---@param t math.vector
---@return table
function Vector.to_table(t)
	if not isvector(t) then
		return error("Vector.to_table requires a vector", 2)
	end
	return { x = t[1], y = t[2], z = t[3] }
end

self.to_table = Vector.to_table

--- Create vector from table
---@param tbl table Table with x, y, z keys or numeric indices
---@return math.vector
function Vector.from_table(tbl)
	return Vector_new(tbl.x or tbl[1], tbl.y or tbl[2], tbl.z or tbl[3])
end

self.from_table = Vector.from_table

--- Convert from spherical coordinates (radius, theta, phi)
--- theta: azimuthal angle (0 to 2π)
--- phi: polar angle from up axis (0 to π)
---@param radius number
---@param theta number
---@param phi number
---@return math.vector
function Vector.from_spherical(radius, theta, phi)
	local sin_phi = math_sin(phi)
	return Vector_new(
		radius * sin_phi * math_cos(theta),
		radius * sin_phi * math_sin(theta),
		radius * math_cos(phi)
	)
end

self.from_spherical = Vector.from_spherical

--- Convert vector to spherical coordinates (radius, theta, phi)
---@param t math.vector
---@return number radius
---@return number theta
---@return number phi
function Vector.to_spherical(t)
	if not isvector(t) then
		return error("Vector.to_spherical requires a vector", 2)
	end
	local radius = math_sqrt(t[1] * t[1] + t[2] * t[2] + t[3] * t[3])
	if radius == 0 then
		return 0, 0, 0
	end
	local theta = math_atan2(t[2], t[1])
	local phi = math_acos(t[3] / radius)
	return radius, theta, phi
end

self.to_spherical = Vector.to_spherical

--- Look at target: returns a direction vector pointing from source to target
---@param source math.vector
---@param target math.vector
---@return math.vector
function Vector.look_at(source, target)
	if not isvector(source) or not isvector(target) then
		return error("Vector.look_at requires two vectors", 2)
	end
	local dx, dy, dz = target[1] - source[1], target[2] - source[2], target[3] - source[3]
	local len = math_sqrt(dx * dx + dy * dy + dz * dz)
	if len == 0 then
		return Vector_new(0, 0, 1)
	end
	return Vector_new(dx / len, dy / len, dz / len)
end

self.look_at = Vector.look_at

--- Smoothstep interpolation between two vectors (Hermite interpolation)
---@param a math.vector
---@param b math.vector
---@param t number Interpolation factor (usually 0 to 1)
---@return math.vector
function Vector.smoothstep(a, b, t)
	if not isvector(a) or not isvector(b) then
		return error("Vector.smoothstep requires two vectors", 2)
	end
	t = t < 0 and 0 or (t > 1 and 1 or t)
	local smooth_t = t * t * (3 - 2 * t)
	return Vector_new(
		a[1] + (b[1] - a[1]) * smooth_t,
		a[2] + (b[2] - a[2]) * smooth_t,
		a[3] + (b[3] - a[3]) * smooth_t
	)
end

self.smoothstep = Vector.smoothstep

--- Mix/blend two vectors with a factor (same as lerp but more explicit naming)
---@param a math.vector
---@param b math.vector
---@param t number Blend factor
---@return math.vector
function Vector.mix(a, b, t)
	if not isvector(a) or not isvector(b) then
		return error("Vector.mix requires two vectors", 2)
	end
	return Vector_new(
		a[1] + (b[1] - a[1]) * t,
		a[2] + (b[2] - a[2]) * t,
		a[3] + (b[3] - a[3]) * t
	)
end

self.mix = Vector.mix

--- Find an arbitrary vector orthogonal to the given vector
---@param vec math.vector
---@return math.vector
function Vector.orthogonal_to(vec)
	local len_sq = vec[1] * vec[1] + vec[2] * vec[2] + vec[3] * vec[3]
	if len_sq == 0 then
		return Vector_new(1, 0, 0)
	end
	local abs_x, abs_y, abs_z = math_abs(vec[1]), math_abs(vec[2]), math_abs(vec[3])
	if abs_x < abs_y and abs_x < abs_z then
		return Vector_new(0, -vec[3], vec[2])
	elseif abs_y < abs_z then
		return Vector_new(-vec[3], 0, vec[1])
	else
		return Vector_new(-vec[2], vec[1], 0)
	end
end

self.orthogonal_to = Vector.orthogonal_to

--- Rotate vector around X axis by angle (in radians)
---@param vec math.vector
---@param angle number Rotation angle in radians
---@return math.vector
function Vector.rotate_x(vec, angle)
	if not isvector(vec) then
		return error("Vector.rotate_x requires a vector", 2)
	end
	local cos_a = math_cos(angle)
	local sin_a = math_sin(angle)
	return Vector_new(
		vec[1],
		vec[2] * cos_a - vec[3] * sin_a,
		vec[2] * sin_a + vec[3] * cos_a
	)
end

self.rotate_x = Vector.rotate_x

--- Rotate vector around Y axis by angle (in radians)
---@param vec math.vector
---@param angle number Rotation angle in radians
---@return math.vector
function Vector.rotate_y(vec, angle)
	if not isvector(vec) then
		return error("Vector.rotate_y requires a vector", 2)
	end
	local cos_a = math_cos(angle)
	local sin_a = math_sin(angle)
	return Vector_new(
		vec[1] * cos_a + vec[3] * sin_a,
		vec[2],
		-vec[1] * sin_a + vec[3] * cos_a
	)
end

self.rotate_y = Vector.rotate_y

--- Rotate vector around Z axis by angle (in radians)
---@param vec math.vector
---@param angle number Rotation angle in radians
---@return math.vector
function Vector.rotate_z(vec, angle)
	if not isvector(vec) then
		return error("Vector.rotate_z requires a vector", 2)
	end
	local cos_a = math_cos(angle)
	local sin_a = math_sin(angle)
	return Vector_new(
		vec[1] * cos_a - vec[2] * sin_a,
		vec[2] * cos_a + vec[1] * sin_a,
		vec[3]
	)
end

self.rotate_z = Vector.rotate_z

----------------------------------------------------------------------
-- Coordinate System Management
----------------------------------------------------------------------

--- Set coordinate system by name or configuration
---@param system string|math.CoordinateSystem Coordinate system name or config table
function self.set_coordinate_system(system)
	if type(system) == "string" then
		if not COORD_SYSTEMS[system] then
			return error("Unknown coordinate system: " .. system, 2)
		end
		current_coord_system = COORD_SYSTEMS[system]
	else
		current_coord_system = system
	end

	-- Swap cross product function for performance
	Vector.cross = current_coord_system.handedness == "left" and cross_left_handed or cross_right_handed
	self.cross = Vector.cross

	update_direction_vectors()
end

--- Get current coordinate system configuration
---@return math.CoordinateSystem
function self.get_coordinate_system()
	return current_coord_system
end

--- Get available coordinate system names
---@return table
function self.get_available_coordinate_systems()
	local systems = {}
	for name, _ in next, COORD_SYSTEMS do
		systems[#systems + 1] = name
	end
	return systems
end

--- Transform vector from one coordinate system to another
---@param vec math.vector Source vector
---@param from_system string|math.CoordinateSystem Source coordinate system
---@param to_system string|math.CoordinateSystem Target coordinate system
---@return math.vector
function self.transform_coordinate_system(vec, from_system, to_system)
	local from_cs = type(from_system) == "string" and COORD_SYSTEMS[from_system] or from_system
	local to_cs = type(to_system) == "string" and COORD_SYSTEMS[to_system] or to_system

	if not from_cs or not to_cs then
		return error("Invalid coordinate system specified", 2)
	end

	-- If systems are the same, return clone
	if from_cs.name == to_cs.name then
		return Vector.clone(vec)
	end

	-- Create transformation based on axis mapping and handedness
	local result = Vector.clone(vec)

	-- Handle axis remapping
	if from_cs.up_axis ~= to_cs.up_axis or from_cs.forward_axis ~= to_cs.forward_axis then
		-- Remap components based on axis differences
		local temp = { result[1], result[2], result[3] }

		-- Map forward axis
		if from_cs.forward_axis ~= to_cs.forward_axis then
			if (from_cs.forward_axis == "x" and to_cs.forward_axis == "z") or
				(from_cs.forward_axis == "z" and to_cs.forward_axis == "x") then
				result[1], result[3] = temp[3], temp[1]
			elseif (from_cs.forward_axis == "y" and to_cs.forward_axis == "z") or
				(from_cs.forward_axis == "z" and to_cs.forward_axis == "y") then
				result[2], result[3] = temp[3], temp[2]
			end
		end

		-- Map up axis
		if from_cs.up_axis ~= to_cs.up_axis then
			if (from_cs.up_axis == "y" and to_cs.up_axis == "z") or
				(from_cs.up_axis == "z" and to_cs.up_axis == "y") then
				result[2], result[3] = temp[2], temp[3]
			end
		end
	end

	-- Handle handedness difference (invert one axis)
	if from_cs.handedness ~= to_cs.handedness then
		result[1] = -result[1]
	end

	return result
end

-- Initialize direction vectors with default coordinate system (after all metatable methods are defined)
update_direction_vectors()

-- Export
return setmetatable(self, {
	__call = function(_, ...)
		return Vector_new(...)
	end
})
