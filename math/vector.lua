-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Simple object-oriented 3D Vector struct

-- Features:
-- Fast numeric storage (vec[1], vec[2], vec[3]); no hashing, raw lookup
-- Convenient field access (vec.x, vec.y, vec.z)
-- Shorthand constructor; Vector(1, 2, 3) instead of Vector.new(1, 2, 3)

-- Localized global functions for better performance
local getmetatable, rawget, rawset, setmetatable, tonumber, tostring, type =
	getmetatable, rawget, rawset, setmetatable, tonumber, tostring, type
local math_sqrt = math.sqrt
local string_format = string.format

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
	return Vector_new(a[1] + b[1], a[2] + b[2], a[3] + b[3])
end

--- Subtraction: a - b
function Vector.__sub(a, b)
	return Vector_new(a[1] - b[1], a[2] - b[2], a[3] - b[3])
end

--- Scalar multiplication: vec * scalar or scalar * vec
function Vector.__mul(a, b)
	if type(a) == "number" then -- scalar * vec
		a, b = b, a
	end
	return Vector_new(a[1] * b, a[2] * b, a[3] * b)
end

--- Scalar division: vec / scalar
function Vector.__div(a, b)
	return Vector_new(a[1] / b, a[2] / b, a[3] / b)
end

--- Negation: -vec
function Vector.__unm(a)
	return Vector_new(-a[1], -a[2], -a[3])
end

--- Length operator: #vec
function Vector.__len(t)
	return math_sqrt(t[1] * t[1] + t[2] * t[2] + t[3] * t[3])
end

--- Readable string representation
function Vector.__tostring(t)
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
	return a[1] == b[1] and a[2] == b[2] and a[3] == b[3]
end

--- Less than comparison: a < b (compares by squared magnitude)
function Vector.__lt(a, b)
	return (a[1] * a[1] + a[2] * a[2] + a[3] * a[3]) < (b[1] * b[1] + b[2] * b[2] + b[3] * b[3])
end

--- Less than or equal comparison: a <= b (compares by squared magnitude)
function Vector.__le(a, b)
	return (a[1] * a[1] + a[2] * a[2] + a[3] * a[3]) <= (b[1] * b[1] + b[2] * b[2] + b[3] * b[3])
end

--- Greater than comparison: a > b (compares by squared magnitude)
function Vector.__gt(a, b)
	return (a[1] * a[1] + a[2] * a[2] + a[3] * a[3]) > (b[1] * b[1] + b[2] * b[2] + b[3] * b[3])
end

--- Greater than or equal comparison: a >= b (compares by squared magnitude)
function Vector.__ge(a, b)
	return (a[1] * a[1] + a[2] * a[2] + a[3] * a[3]) >= (b[1] * b[1] + b[2] * b[2] + b[3] * b[3])
end

----------------------------------------------------------------------
-- Vector utility functions
----------------------------------------------------------------------

--- Create a shallow copy
---@return math.vector
function Vector.clone(t)
	return Vector_new(t[1], t[2], t[3])
end

self.clone = Vector.clone

--- Set components of an existing vector (modifies self)
---@param x number
---@param y number
---@param z number
---@return math.vector
function Vector.set(t, x, y, z)
	t[1], t[2], t[3] = x, y, z
	return t
end

self.set = Vector.set

--- Unpack vector components
---@return number x
---@return number y
---@return number z
function Vector.unpack(t)
	return t[1], t[2], t[3]
end

self.unpack = Vector.unpack

--- Dot product: a · b
---@param a math.vector
---@param b math.vector
---@return number
function Vector.dot(a, b)
	return a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
end

self.dot = Vector.dot

--- Cross product: a × b
---@param a math.vector
---@param b math.vector
---@return math.vector
function Vector.cross(a, b)
	return Vector_new(
		a[2] * b[3] - a[3] * b[2],
		a[3] * b[1] - a[1] * b[3],
		a[1] * b[2] - a[2] * b[1]
	)
end

self.cross = Vector.cross

--- Get Euclidean length (magnitude)
---@return number
function Vector.length(t)
	return math_sqrt(t[1] * t[1] + t[2] * t[2] + t[3] * t[3])
end

self.length = Vector.length

--- Get squared length (faster, avoids expensive sqrt)
---@return number
function Vector.length_squared(t)
	return t[1] * t[1] + t[2] * t[2] + t[3] * t[3]
end

self.length_squared = Vector.length_squared

--- Normalize in-place (modifies self, returns self)
---@return math.vector
function Vector.normalize(t)
	local len = math_sqrt(t[1] * t[1] + t[2] * t[2] + t[3] * t[3])
	if len ~= 0 then
		t[1] = t[1] / len
		t[2] = t[2] / len
		t[3] = t[3] / len
	end
	return t
end

self.normalize = Vector.normalize

--- Return a new normalized vector (does not modify self)
---@return math.vector
function Vector.normalized(t)
	local len = math_sqrt(t[1] * t[1] + t[2] * t[2] + t[3] * t[3])
	if len == 0 then
		return Vector_new()
	end
	return Vector_new(t[1] / len, t[2] / len, t[3] / len)
end

self.normalized = Vector.normalized

--- Interpolate linearly between a and b by factor t (t in [0,1])
---@param a math.vector
---@param b math.vector
---@param t number
---@return math.vector
function Vector.lerp(a, b, t)
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
	local dx, dy, dz = a[1] - b[1], a[2] - b[2], a[3] - b[3]
	return math_sqrt(dx * dx + dy * dy + dz * dz)
end

self.distance = Vector.distance

--- Squared distance between two vectors (faster, avoids expensive sqrt)
---@param a math.vector
---@param b math.vector
---@return number
function Vector.distance_squared(a, b)
	local dx, dy, dz = a[1] - b[1], a[2] - b[2], a[3] - b[3]
	return dx * dx + dy * dy + dz * dz
end

self.distance_squared = Vector.distance_squared

-- Export
return setmetatable(self, {
	__call = function(_, ...)
		return Vector_new(...)
	end
})
