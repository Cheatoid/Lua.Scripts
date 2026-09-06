-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Simple object-oriented Quaternion struct

-- Features:
-- Fast numeric storage (quat[1], quat[2], quat[3], quat[4]); no hashing, raw lookup
-- Convenient field access (quat.x, quat.y, quat.z, quat.w)
-- Shorthand constructor; Quaternion(x, y, z, w) instead of Quaternion.new(x, y, z, w)
-- Defaults to identity quaternion: Quaternion() == Quaternion(0, 0, 0, 1)

-- Stored as (x, y, z, w): (x, y, z) is the vector/imaginary part; w is the scalar/real part

-- Localized global functions for better performance
local error, getmetatable, rawget, rawset, setmetatable, tonumber, tostring, type =
	error, getmetatable, rawget, rawset, setmetatable, tonumber, tostring, type
local math_abs, math_acos, math_asin, math_atan2, math_cos, math_random, math_sin, math_sqrt =
	math.abs, math.acos, math.asin, math.atan2, math.cos, math.random, math.sin, math.sqrt
local math_pi = math.pi
local string_format = string.format

--- A mathematical construct used to represent rotations in 3D space.<br>
--- Perfect for 3D graphics, physics simulations, and camera controls where gimbal lock must be avoided.
---@class math.quaternion
---@field [1] number X component (imaginary i)
---@field [2] number Y component (imaginary j)
---@field [3] number Z component (imaginary k)
---@field [4] number W component (real/scalar)
---@field x number X component
---@field y number Y component
---@field z number Z component
---@field w number W component

local self = {}       -- module
local Quaternion = {} -- method table

--- Create a new Quaternion instance.<br>
--- Defaults to the identity quaternion (0, 0, 0, 1) if no arguments are provided.
---@param x? number The X component (default: 0).
---@param y? number The Y component (default: 0).
---@param z? number The Z component (default: 0).
---@param w? number The W component (default: 1).
---@return math.quaternion quat New Quaternion instance.
---@usage <br>
--- ```
--- local q = Quaternion.new(0, 0, 0, 1)
--- ```
local function Quaternion_new(x, y, z, w)
	return setmetatable({
		tonumber(x) or 0,
		tonumber(y) or 0,
		tonumber(z) or 0,
		tonumber(w) or 1
	}, Quaternion)
end

self.new = Quaternion_new

self.identity = Quaternion_new(0, 0, 0, 1)
self.zero = Quaternion_new(0, 0, 0, 0)

--- Test whether an object is a Quaternion (by its metatable).<br>
--- Returns true if the object has the Quaternion metatable.
---@param obj any The object to test.
---@return boolean is_quat True if the object is a Quaternion.
---@usage <br>
--- ```
--- local q = Quaternion.new()
--- print(Quaternion.is(q)) -- true
--- ```
local function isquat(obj)
	return getmetatable(obj) == Quaternion
end

self.is = isquat

function Quaternion.__index(t, k)
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
	if k == "w" then
		return rawget(t, 4)
	end
	-- Otherwise, fallback to accessing the method table
	return rawget(Quaternion, k)
end

function Quaternion.__newindex(t, k, v)
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
	if k == "w" then
		return rawset(t, 4, v) -- tailcall
	end
	return rawset(t, k, v) -- tailcall
end

----------------------------------------------------------------------
-- Quaternion arithmetic metamethods
----------------------------------------------------------------------

--- Addition: a + b
function Quaternion.__add(a, b)
	if not isquat(a) or not isquat(b) then
		return error("Quaternion addition requires two quaternions", 2)
	end
	return Quaternion_new(a[1] + b[1], a[2] + b[2], a[3] + b[3], a[4] + b[4])
end

--- Subtraction: a - b
function Quaternion.__sub(a, b)
	if not isquat(a) or not isquat(b) then
		return error("Quaternion subtraction requires two quaternions", 2)
	end
	return Quaternion_new(a[1] - b[1], a[2] - b[2], a[3] - b[3], a[4] - b[4])
end

--- Multiplication: quat * quat (Hamilton product), quat * scalar, scalar * quat
function Quaternion.__mul(a, b)
	if type(a) == "number" then -- scalar * quat
		if not isquat(b) then
			return error("Quaternion multiplication requires a quaternion and a number", 2)
		end
		a, b = b, a
	elseif not isquat(a) then
		return error("Quaternion multiplication requires a quaternion and a number", 2)
	end
	if isquat(b) then -- quat * quat: Hamilton product
		local ax, ay, az, aw = a[1], a[2], a[3], a[4]
		local bx, by, bz, bw = b[1], b[2], b[3], b[4]
		return Quaternion_new(
			aw * bx + ax * bw + ay * bz - az * by, aw * by - ax * bz + ay * bw + az * bx,
			aw * bz + ax * by - ay * bx + az * bw, aw * bw - ax * bx - ay * by - az * bz
		)
	end
	if type(b) ~= "number" then
		return error("Quaternion multiplication requires a quaternion and a number", 2)
	end
	return Quaternion_new(a[1] * b, a[2] * b, a[3] * b, a[4] * b)
end

--- Scalar division: quat / scalar
function Quaternion.__div(a, b)
	if not isquat(a) then
		return error("Quaternion division requires a quaternion", 2)
	end
	if type(b) ~= "number" then
		return error("Quaternion division requires a number", 2)
	end
	if b == 0 then
		return error("Quaternion division by zero", 2)
	end
	return Quaternion_new(a[1] / b, a[2] / b, a[3] / b, a[4] / b)
end

--- Negation: -quat
function Quaternion.__unm(a)
	if not isquat(a) then
		return error("Quaternion negation requires a quaternion", 2)
	end
	return Quaternion_new(-a[1], -a[2], -a[3], -a[4])
end

--- Get the magnitude (length) of the quaternion using `#` operator.<br>
--- Returns the Euclidean norm of the quaternion.
---@param t math.quaternion The quaternion instance.
---@return number length The magnitude of the quaternion.
---@usage <br>
--- ```
--- local q = Quaternion.new(0, 0, 0, 1)
--- print(#q) -- 1
--- ```
function Quaternion.__len(t)
	if not isquat(t) then
		return error("Length operator requires a quaternion", 2)
	end
	return math_sqrt(t[1] * t[1] + t[2] * t[2] + t[3] * t[3] + t[4] * t[4])
end

--- Get string representation of the quaternion.<br>
--- Returns a formatted string showing its components.
---@param t math.quaternion The quaternion instance.
---@return string string String representation of the quaternion.
---@usage <br>
--- ```
--- local q = Quaternion.new(0, 0, 0, 1)
--- print(tostring(q)) -- "Quaternion(0, 0, 0, 1)"
--- ```
function Quaternion.__tostring(t)
	if not isquat(t) then
		return tostring(t)
	end
	return string_format("Quaternion(%.6g, %.6g, %.6g, %.6g)", t[1], t[2], t[3], t[4])
end

--- Concatenation: quat1 .. quat2.<br>
--- Returns a string showing both quaternions.
---@param a math.quaternion The first quaternion.
---@param b math.quaternion The second quaternion.
---@return string string Concatenated string representation.
---@usage <br>
--- ```
--- local q1 = Quaternion.new(0, 0, 0, 1)
--- local q2 = Quaternion.new(1, 0, 0, 0)
--- print(q1 .. q2)
--- ```
function Quaternion.__concat(a, b)
	if isquat(a) and isquat(b) then
		return string_format(
			"Quaternion(%.6g, %.6g, %.6g, %.6g) + Quaternion(%.6g, %.6g, %.6g, %.6g)", a[1], a[2], a[3], a[4], b[1],
			b[2], b[3], b[4]
		)
	end
	-- Fallback for non-quaternion concatenation
	return tostring(a) .. tostring(b)
end

--- Iterate over quaternion components using pairs().<br>
--- Yields index and value for each component (1:x, 2:y, 3:z, 4:w).
---@param t math.quaternion The quaternion instance.
---@return function iterator Iterator that yields index and value pairs.
---@return any state The state for the iterator.
---@return number initial_index The initial index (0).
---@usage <br>
--- ```
--- local q = Quaternion.new(1, 2, 3, 4)
--- for index, value in pairs(q) do
---   print(index, value)
--- end
--- ```
function Quaternion.__pairs(t)
	return Quaternion.iterator(t)
end

--- Iterate over quaternion components using ipairs().<br>
--- Same as pairs() for Quaternion.
---@param t math.quaternion The quaternion instance.
---@return function iterator Iterator that yields index and value pairs.
---@return any state The state for the iterator.
---@return number initial_index The initial index (0).
function Quaternion.__ipairs(t)
	return Quaternion.iterator(t)
end

--- Check if two quaternions are exactly equal.<br>
--- Compares all components directly without epsilon tolerance.
---@param a math.quaternion The first quaternion.
---@param b math.quaternion The second quaternion.
---@return boolean equal True if all components are exactly equal.
---@usage <br>
--- ```
--- local q1 = Quaternion.new(0, 0, 0, 1)
--- local q2 = Quaternion.new(0, 0, 0, 1)
--- print(q1 == q2) -- true
--- ```
function Quaternion.__eq(a, b)
	if not isquat(a) or not isquat(b) then
		return false
	end
	return a[1] == b[1] and a[2] == b[2] and a[3] == b[3] and a[4] == b[4]
end

--- Less than comparison: a < b (compares by squared magnitude).<br>
--- Returns true if the squared magnitude of a is less than b.
---@param a math.quaternion The first quaternion.
---@param b math.quaternion The second quaternion.
---@return boolean result True if a < b by magnitude.
function Quaternion.__lt(a, b)
	if not isquat(a) or not isquat(b) then
		return error("Quaternion comparison requires two quaternions", 2)
	end
	return (a[1] * a[1] + a[2] * a[2] + a[3] * a[3] + a[4] * a[4])
		< (b[1] * b[1] + b[2] * b[2] + b[3] * b[3] + b[4] * b[4])
end

--- Less than or equal comparison: a <= b (compares by squared magnitude).<br>
--- Returns true if the squared magnitude of a is less than or equal to b.
---@param a math.quaternion The first quaternion.
---@param b math.quaternion The second quaternion.
---@return boolean result True if a <= b by magnitude.
function Quaternion.__le(a, b)
	if not isquat(a) or not isquat(b) then
		return error("Quaternion comparison requires two quaternions", 2)
	end
	return (a[1] * a[1] + a[2] * a[2] + a[3] * a[3] + a[4] * a[4])
		<= (b[1] * b[1] + b[2] * b[2] + b[3] * b[3] + b[4] * b[4])
end

--- Greater than comparison: a > b (compares by squared magnitude).<br>
--- Returns true if the squared magnitude of a is greater than b.
---@param a math.quaternion The first quaternion.
---@param b math.quaternion The second quaternion.
---@return boolean result True if a > b by magnitude.
function Quaternion.__gt(a, b)
	if not isquat(a) or not isquat(b) then
		return error("Quaternion comparison requires two quaternions", 2)
	end
	return (a[1] * a[1] + a[2] * a[2] + a[3] * a[3] + a[4] * a[4])
		> (b[1] * b[1] + b[2] * b[2] + b[3] * b[3] + b[4] * b[4])
end

--- Greater than or equal comparison: a >= b (compares by squared magnitude).<br>
--- Returns true if the squared magnitude of a is greater than or equal to b.
---@param a math.quaternion The first quaternion.
---@param b math.quaternion The second quaternion.
---@return boolean result True if a >= b by magnitude.
function Quaternion.__ge(a, b)
	if not isquat(a) or not isquat(b) then
		return error("Quaternion comparison requires two quaternions", 2)
	end
	return (a[1] * a[1] + a[2] * a[2] + a[3] * a[3] + a[4] * a[4])
		>= (b[1] * b[1] + b[2] * b[2] + b[3] * b[3] + b[4] * b[4])
end

----------------------------------------------------------------------
-- Quaternion utility functions
----------------------------------------------------------------------

--- Create a shallow copy of the quaternion.<br>
--- Returns a new quaternion with the same components.
---@param t math.quaternion The quaternion to copy.
---@return math.quaternion clone A new quaternion with the same components.
---@usage <br>
--- ```
--- local q1 = Quaternion.new(1, 2, 3, 4)
--- local q2 = Quaternion.clone(q1)
--- ```
function Quaternion.clone(t)
	if not isquat(t) then
		return error("Quaternion.clone requires a quaternion", 2)
	end
	return Quaternion_new(t[1], t[2], t[3], t[4])
end

self.clone = Quaternion.clone

--- Set components of an existing quaternion (modifies self).<br>
--- Updates the quaternion components in place and returns self for chaining.
---@param t math.quaternion The quaternion to modify.
---@param x number The X component.
---@param y number The Y component.
---@param z number The Z component.
---@param w number The W component.
---@return math.quaternion self Returns self for chaining.
---@usage <br>
--- ```
--- local q = Quaternion.new()
--- q:set(1, 2, 3, 4)
--- ```
function Quaternion.set(t, x, y, z, w)
	if not isquat(t) then
		return error("Quaternion.set requires a quaternion", 2)
	end
	t[1], t[2], t[3], t[4] = x, y, z, w
	return t
end

self.set = Quaternion.set

--- Unpack quaternion components.<br>
--- Returns all four components as separate values.
---@param t math.quaternion The quaternion to unpack.
---@return number x The X component.
---@return number y The Y component.
---@return number z The Z component.
---@return number w The W component.
---@usage <br>
--- ```
--- local q = Quaternion.new(1, 2, 3, 4)
--- local x, y, z, w = Quaternion.unpack(q)
--- ```
function Quaternion.unpack(t)
	if not isquat(t) then
		return error("Quaternion.unpack requires a quaternion", 2)
	end
	return t[1], t[2], t[3], t[4]
end

self.unpack = Quaternion.unpack

--- Calculate the dot product between two quaternions.<br>
--- Returns the 4D inner product of the quaternions.
---@param a math.quaternion The first quaternion.
---@param b math.quaternion The second quaternion.
---@return number dot The dot product.
---@usage <br>
--- ```
--- local q1 = Quaternion.new(0, 0, 0, 1)
--- local q2 = Quaternion.new(0, 0, 0, 1)
--- print(Quaternion.dot(q1, q2)) -- 1
--- ```
function Quaternion.dot(a, b)
	if not isquat(a) or not isquat(b) then
		return error("Quaternion.dot requires two quaternions", 2)
	end
	return a[1] * b[1] + a[2] * b[2] + a[3] * b[3] + a[4] * b[4]
end

self.dot = Quaternion.dot

--- Get the magnitude (Euclidean norm) of the quaternion.<br>
--- Returns the length of the quaternion.
---@param t math.quaternion The quaternion instance.
---@return number mag The magnitude.
---@usage <br>
--- ```
--- local q = Quaternion.new(0, 0, 0, 1)
--- print(Quaternion.length(q)) -- 1
--- ```
function Quaternion.length(t)
	if not isquat(t) then
		return error("Quaternion.length requires a quaternion", 2)
	end
	return math_sqrt(t[1] * t[1] + t[2] * t[2] + t[3] * t[3] + t[4] * t[4])
end

self.length = Quaternion.length

--- Get the squared magnitude of the quaternion.<br>
--- Faster than length() as it avoids the expensive square root.
---@param t math.quaternion The quaternion instance.
---@return number sqrMag The squared magnitude.
---@usage <br>
--- ```
--- local q = Quaternion.new(1, 2, 3, 4)
--- print(Quaternion.length_squared(q)) -- 30
--- ```
function Quaternion.length_squared(t)
	if not isquat(t) then
		return error("Quaternion.length_squared requires a quaternion", 2)
	end
	return t[1] * t[1] + t[2] * t[2] + t[3] * t[3] + t[4] * t[4]
end

self.length_squared = Quaternion.length_squared

--- Normalize the quaternion in place.<br>
--- Makes the magnitude equal to 1. Does nothing if magnitude is 0.<br>
--- Returns self for chaining.
---@param t math.quaternion The quaternion instance.
---@return math.quaternion self Returns self for chaining.
---@usage <br>
--- ```
--- local q = Quaternion.new(2, 0, 0, 0)
--- q:normalize()
--- print(Quaternion.length(q)) -- 1
--- ```
function Quaternion.normalize(t)
	if not isquat(t) then
		return error("Quaternion.normalize requires a quaternion", 2)
	end
	local len = math_sqrt(t[1] * t[1] + t[2] * t[2] + t[3] * t[3] + t[4] * t[4])
	if len ~= 0 then
		t[1] = t[1] / len
		t[2] = t[2] / len
		t[3] = t[3] / len
		t[4] = t[4] / len
	end
	return t
end

self.normalize = Quaternion.normalize

--- Return a new normalized version of the quaternion.<br>
--- Returns the identity quaternion if the magnitude is 0.<br>
--- Does not modify the original quaternion.
---@param t math.quaternion The quaternion instance.
---@return math.quaternion quat The normalized quaternion.
---@usage <br>
--- ```
--- local q = Quaternion.new(2, 0, 0, 0)
--- local qNorm = Quaternion.normalized(q)
--- ```
function Quaternion.normalized(t)
	if not isquat(t) then
		return error("Quaternion.normalized requires a quaternion", 2)
	end
	local len = math_sqrt(t[1] * t[1] + t[2] * t[2] + t[3] * t[3] + t[4] * t[4])
	if len == 0 then
		return Quaternion_new()
	end
	return Quaternion_new(t[1] / len, t[2] / len, t[3] / len, t[4] / len)
end

self.normalized = Quaternion.normalized

--- Calculate the conjugate of the quaternion.<br>
--- Returns a new Quaternion where x, y, and z are negated.<br>
--- For unit quaternions, this is equivalent to the inverse.
---@param t math.quaternion The quaternion instance.
---@return math.quaternion quat The conjugated quaternion.
---@usage <br>
--- ```
--- local q = Quaternion.new(1, 1, 1, 1)
--- local qConj = Quaternion.conjugate(q)
--- ```
function Quaternion.conjugate(t)
	if not isquat(t) then
		return error("Quaternion.conjugate requires a quaternion", 2)
	end
	return Quaternion_new(-t[1], -t[2], -t[3], t[4])
end

self.conjugate = Quaternion.conjugate

--- Calculate the inverse of the quaternion.<br>
--- Returns conjugate divided by squared magnitude.<br>
--- For unit quaternions, this is equivalent to the conjugate.
---@param t math.quaternion The quaternion instance.
---@return math.quaternion quat The inverted quaternion.
---@usage <br>
--- ```
--- local q = Quaternion.new(1, 1, 1, 1)
--- local qInv = Quaternion.inverse(q)
--- ```
function Quaternion.inverse(t)
	if not isquat(t) then
		return error("Quaternion.inverse requires a quaternion", 2)
	end
	local len_sq = t[1] * t[1] + t[2] * t[2] + t[3] * t[3] + t[4] * t[4]
	if len_sq == 0 then
		return error("Quaternion.inverse: cannot invert a zero quaternion", 2)
	end
	return Quaternion_new(-t[1] / len_sq, -t[2] / len_sq, -t[3] / len_sq, t[4] / len_sq)
end

self.inverse = Quaternion.inverse

--- Multiply two quaternions (Hamilton product): a * b.<br>
--- This is also available via the * operator.<br>
--- Performs quaternion multiplication which is non-commutative.
---@param a math.quaternion The first quaternion.
---@param b math.quaternion The second quaternion.
---@return math.quaternion result The resulting quaternion.
---@usage <br>
--- ```
--- local q1 = Quaternion.new(0, 0, 0, 1)
--- local q2 = Quaternion.new(0, 1, 0, 0)
--- local q3 = Quaternion.multiply(q1, q2)
--- ```
function Quaternion.multiply(a, b)
	if not isquat(a) or not isquat(b) then
		return error("Quaternion.multiply requires two quaternions", 2)
	end
	local ax, ay, az, aw = a[1], a[2], a[3], a[4]
	local bx, by, bz, bw = b[1], b[2], b[3], b[4]
	return Quaternion_new(
		aw * bx + ax * bw + ay * bz - az * by, aw * by - ax * bz + ay * bw + az * bx,
		aw * bz + ax * by - ay * bx + az * bw, aw * bw - ax * bx - ay * by - az * bz
	)
end

self.multiply = Quaternion.multiply

--- Rotate a 3D vector by this quaternion.<br>
--- Uses the optimized formula: v' = v + 2w*(q×v) + 2*(q×(q×v)).<br>
--- The quaternion must be a unit quaternion for correct results.
---@param q math.quaternion The quaternion (must be a unit quaternion).
---@param vx number X component of the vector.
---@param vy number Y component of the vector.
---@param vz number Z component of the vector.
---@return number rx The rotated X component.
---@return number ry The rotated Y component.
---@return number rz The rotated Z component.
---@usage <br>
--- ```
--- local q = Quaternion.from_axis_angle(0, 1, 0, math.rad(90))
--- local rx, ry, rz = Quaternion.rotate_vector(q, 1, 0, 0)
--- ```
function Quaternion.rotate_vector(q, vx, vy, vz)
	if not isquat(q) then
		return error("Quaternion.rotate_vector requires a quaternion", 2)
	end
	local qx, qy, qz, qw = q[1], q[2], q[3], q[4]
	-- t = 2 * cross(q.xyz, v)
	local tx = 2 * (qy * vz - qz * vy)
	local ty = 2 * (qz * vx - qx * vz)
	local tz = 2 * (qx * vy - qy * vx)
	-- v' = v + qw * t + cross(q.xyz, t)
	return vx + qw * tx + qy * tz - qz * ty, vy + qw * ty + qz * tx - qx * tz, vz + qw * tz + qx * ty - qy * tx
end

self.rotate_vector = Quaternion.rotate_vector

--- Interpolate linearly between a and b by factor t (t in [0,1]).<br>
--- Note: result is not guaranteed to be a unit quaternion.<br>
--- Simple linear interpolation without normalization.
---@param a math.quaternion The starting quaternion.
---@param b math.quaternion The ending quaternion.
---@param t number The interpolation factor (0 to 1).
---@return math.quaternion result The interpolated quaternion.
---@usage <br>
--- ```
--- local q1 = Quaternion.new(0, 0, 0, 1)
--- local q2 = Quaternion.new(0, 1, 0, 0)
--- local q = Quaternion.lerp(q1, q2, 0.5)
--- ```
function Quaternion.lerp(a, b, t)
	if not isquat(a) or not isquat(b) then
		return error("Quaternion.lerp requires two quaternions", 2)
	end
	return Quaternion_new(
		a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t, a[4] + (b[4] - a[4]) * t
	)
end

self.lerp = Quaternion.lerp

--- Normalized linear interpolation between a and b by factor t (t in [0,1]).<br>
--- Faster than slerp with good quality for small angles.<br>
--- Always returns a unit quaternion and ensures shortest path.
---@param a math.quaternion The starting quaternion.
---@param b math.quaternion The ending quaternion.
---@param t number The interpolation factor (0 to 1).
---@return math.quaternion result The normalized interpolated quaternion.
---@usage <br>
--- ```
--- local q1 = Quaternion.new(0, 0, 0, 1)
--- local q2 = Quaternion.new(0, 1, 0, 0)
--- local q = Quaternion.nlerp(q1, q2, 0.5)
--- ```
function Quaternion.nlerp(a, b, t)
	if not isquat(a) or not isquat(b) then
		return error("Quaternion.nlerp requires two quaternions", 2)
	end
	-- Ensure shortest path
	local dot = a[1] * b[1] + a[2] * b[2] + a[3] * b[3] + a[4] * b[4]
	local bx, by, bz, bw
	if dot < 0 then
		bx, by, bz, bw = -b[1], -b[2], -b[3], -b[4]
	else
		bx, by, bz, bw = b[1], b[2], b[3], b[4]
	end
	local rx = a[1] + (bx - a[1]) * t
	local ry = a[2] + (by - a[2]) * t
	local rz = a[3] + (bz - a[3]) * t
	local rw = a[4] + (bw - a[4]) * t
	local len = math_sqrt(rx * rx + ry * ry + rz * rz + rw * rw)
	if len == 0 then
		return Quaternion_new()
	end
	return Quaternion_new(rx / len, ry / len, rz / len, rw / len)
end

self.nlerp = Quaternion.nlerp

--- Spherical linear interpolation between a and b by factor t (t in [0,1]).<br>
--- Provides constant angular velocity interpolation along the shortest path.<br>
--- Falls back to nlerp when quaternions are nearly identical.
---@param a math.quaternion The starting quaternion.
---@param b math.quaternion The ending quaternion.
---@param t number The interpolation factor (0 to 1).
---@return math.quaternion result The spherically interpolated quaternion.
---@usage <br>
--- ```
--- local q1 = Quaternion.new(0, 0, 0, 1)
--- local q2 = Quaternion.new(0, 1, 0, 0)
--- local q = Quaternion.slerp(q1, q2, 0.5)
--- ```
function Quaternion.slerp(a, b, t)
	if not isquat(a) or not isquat(b) then
		return error("Quaternion.slerp requires two quaternions", 2)
	end
	local dot = a[1] * b[1] + a[2] * b[2] + a[3] * b[3] + a[4] * b[4]
	-- Ensure shortest arc (negate b if quaternions point in opposite hemispheres)
	local bx, by, bz, bw
	if dot < 0 then
		dot = -dot
		bx, by, bz, bw = -b[1], -b[2], -b[3], -b[4]
	else
		bx, by, bz, bw = b[1], b[2], b[3], b[4]
	end
	dot = dot > 1 and 1 or dot
	if dot > 1 - 1e-6 then
		-- Quaternions are nearly identical; fall back to nlerp
		local rx = a[1] + (bx - a[1]) * t
		local ry = a[2] + (by - a[2]) * t
		local rz = a[3] + (bz - a[3]) * t
		local rw = a[4] + (bw - a[4]) * t
		local len = math_sqrt(rx * rx + ry * ry + rz * rz + rw * rw)
		if len == 0 then
			return Quaternion_new()
		end
		return Quaternion_new(rx / len, ry / len, rz / len, rw / len)
	end
	local theta = math_acos(dot)
	local sin_theta = math_sqrt(1 - dot * dot)
	local scale_a = math_sin((1 - t) * theta) / sin_theta
	local scale_b = math_sin(t * theta) / sin_theta
	return Quaternion_new(
		a[1] * scale_a + bx * scale_b, a[2] * scale_a + by * scale_b, a[3] * scale_a + bz * scale_b,
		a[4] * scale_a + bw * scale_b
	)
end

self.slerp = Quaternion.slerp

--- Construct quaternion from an axis and an angle (in radians).<br>
--- The axis does not need to be pre-normalized.<br>
--- Creates a rotation quaternion representing a rotation around the given axis.
---@param ax number Axis X component.
---@param ay number Axis Y component.
---@param az number Axis Z component.
---@param angle number Rotation angle in radians.
---@return math.quaternion quat The new quaternion.
---@usage <br>
--- ```
--- local q = Quaternion.from_axis_angle(0, 1, 0, math.rad(90))
--- ```
function Quaternion.from_axis_angle(ax, ay, az, angle)
	local len = math_sqrt(ax * ax + ay * ay + az * az)
	if len == 0 then
		return Quaternion_new()
	end
	local half = angle * 0.5
	local s = math_sin(half) / len
	return Quaternion_new(ax * s, ay * s, az * s, math_cos(half))
end

self.from_axis_angle = Quaternion.from_axis_angle

--- Decompose unit quaternion into an axis and an angle (in radians).<br>
--- Returns axis (1, 0, 0) and angle 0 for identity or near-identity quaternions.<br>
--- The quaternion must be a unit quaternion for correct results.
---@param q math.quaternion The quaternion (must be a unit quaternion).
---@return number ax The axis X component.
---@return number ay The axis Y component.
---@return number az The axis Z component.
---@return number angle The rotation angle in radians.
---@usage <br>
--- ```
--- local q = Quaternion.from_axis_angle(0, 1, 0, math.rad(90))
--- local ax, ay, az, angle = Quaternion.to_axis_angle(q)
--- ```
function Quaternion.to_axis_angle(q)
	if not isquat(q) then
		return error("Quaternion.to_axis_angle requires a quaternion", 2)
	end
	local qx, qy, qz, qw = q[1], q[2], q[3], q[4]
	-- Normalize to the positive-w hemisphere so angle is in [0, pi]
	if qw < 0 then
		qx, qy, qz, qw = -qx, -qy, -qz, -qw
	end
	qw = qw > 1 and 1 or qw
	local angle = 2 * math_acos(qw)
	local s = math_sqrt(1 - qw * qw)
	if s < 1e-6 then
		return 1, 0, 0, 0
	end
	return qx / s, qy / s, qz / s, angle
end

self.to_axis_angle = Quaternion.to_axis_angle

--- Construct quaternion from Euler angles (in radians), applied in ZXY intrinsic order.<br>
--- pitch: rotation around Y axis<br>
--- yaw: rotation around Z axis<br>
--- roll: rotation around X axis
---@param pitch number Rotation around Y axis in radians.
---@param yaw number Rotation around Z axis in radians.
---@param roll number Rotation around X axis in radians.
---@return math.quaternion quat The new quaternion.
---@usage <br>
--- ```
--- local q = Quaternion.from_euler(math.rad(45), 0, 0)
--- ```
function Quaternion.from_euler(pitch, yaw, roll)
	local cx = math_cos(pitch * 0.5)
	local sx = math_sin(pitch * 0.5)
	local cy = math_cos(yaw * 0.5)
	local sy = math_sin(yaw * 0.5)
	local cz = math_cos(roll * 0.5)
	local sz = math_sin(roll * 0.5)
	return Quaternion_new(
		cx * sz * cy + sx * cz * sy, sx * cz * cy - cx * sz * sy, cx * cz * sy - sx * sz * cy,
		cx * cz * cy + sx * sz * sy
	)
end

self.from_euler = Quaternion.from_euler

--- Decompose unit quaternion into Euler angles (in radians), in ZXY intrinsic order.<br>
--- Returns pitch (Y axis), yaw (Z axis), and roll (X axis) rotations.<br>
--- The quaternion must be a unit quaternion for correct results.
---@param q math.quaternion The quaternion (must be a unit quaternion).
---@return number pitch Rotation around Y axis in radians.
---@return number yaw Rotation around Z axis in radians.
---@return number roll Rotation around X axis in radians.
---@usage <br>
--- ```
--- local q = Quaternion.from_euler(math.rad(45), 0, 0)
--- local pitch, yaw, roll = Quaternion.to_euler(q)
--- ```
function Quaternion.to_euler(q)
	if not isquat(q) then
		return error("Quaternion.to_euler requires a quaternion", 2)
	end
	local qx, qy, qz, qw = q[1], q[2], q[3], q[4]
	-- Roll (X axis)
	local sinr = 2 * (qw * qx - qy * qz)
	sinr = sinr > 1 and 1 or (sinr < -1 and -1 or sinr)
	local roll = math_asin(sinr)
	local cr = math_cos(roll)
	if cr > 1e-6 then
		-- Yaw (Z axis)
		local siny = 2 * (qx * qy + qw * qz)
		local cosy = 1 - 2 * (qx * qx + qz * qz)
		local yaw = math_atan2(siny, cosy)
		-- Pitch (Y axis)
		local sinp = 2 * (qw * qy + qx * qz)
		local cosp = (1 - 2 * (qx * qx + qy * qy)) / cr
		local pitch = math_atan2(sinp, cosp)
		return pitch, yaw, roll
	end
	-- Gimbal lock: roll is ~90 degrees, yaw and pitch are coupled
	local yaw = 0
	local sinp = 2 * (qw * qy - qx * qz)
	local cosp = 1 - 2 * (qy * qy + qz * qz)
	local pitch = math_atan2(sinp, cosp)
	return pitch, yaw, roll
end

self.to_euler = Quaternion.to_euler

--- Angular distance (in radians) between two unit quaternions.<br>
--- Uses absolute dot to account for double-cover (q and -q represent the same rotation).<br>
--- Returns the angle in radians between the two rotations.
---@param a math.quaternion The first quaternion.
---@param b math.quaternion The second quaternion.
---@return number angle The angular distance in radians.
---@usage <br>
--- ```
--- local q1 = Quaternion.new(0, 0, 0, 1)
--- local q2 = Quaternion.new(0, 1, 0, 0)
--- local angle = Quaternion.angle_between(q1, q2)
--- ```
function Quaternion.angle_between(a, b)
	if not isquat(a) or not isquat(b) then
		return error("Quaternion.angle_between requires two quaternions", 2)
	end
	-- Use absolute dot to account for double-cover (q and -q represent the same rotation)
	local dot = math_abs(a[1] * b[1] + a[2] * b[2] + a[3] * b[3] + a[4] * b[4])
	dot = dot > 1 and 1 or dot
	return 2 * math_acos(dot)
end

self.angle_between = Quaternion.angle_between

--- Check if quaternion is approximately the identity (within epsilon).<br>
--- Returns true if the quaternion is close to (0, 0, 0, 1).
---@param q math.quaternion The quaternion to check.
---@param epsilon number | nil Optional epsilon, defaults to 1e-6.
---@return boolean is_identity True if approximately identity.
---@usage <br>
--- ```
--- local q = Quaternion.new(0, 0, 0, 1)
--- print(Quaternion.is_identity(q)) -- true
--- ```
function Quaternion.is_identity(q, epsilon)
	if not isquat(q) then
		return error("Quaternion.is_identity requires a quaternion", 2)
	end
	epsilon = epsilon or 1e-6
	local dx = q[1]
	local dy = q[2]
	local dz = q[3]
	local dw = q[4] - 1
	return (dx * dx + dy * dy + dz * dz + dw * dw) < epsilon * epsilon
end

self.is_identity = Quaternion.is_identity

--- Check if quaternion is approximately zero (within epsilon).<br>
--- Returns true if all components are close to zero.
---@param q math.quaternion The quaternion to check.
---@param epsilon number | nil Optional epsilon, defaults to 1e-6.
---@return boolean is_zero True if approximately zero.
---@usage <br>
--- ```
--- local q = Quaternion.new(0, 0, 0, 0)
--- print(Quaternion.is_zero(q)) -- true
--- ```
function Quaternion.is_zero(q, epsilon)
	if not isquat(q) then
		return error("Quaternion.is_zero requires a quaternion", 2)
	end
	epsilon = epsilon or 1e-6
	local len_sq = q[1] * q[1] + q[2] * q[2] + q[3] * q[3] + q[4] * q[4]
	return len_sq < epsilon * epsilon
end

self.is_zero = Quaternion.is_zero

--- Check if quaternion is a unit quaternion (within epsilon).<br>
--- Returns true if the magnitude is approximately 1.
---@param q math.quaternion The quaternion to check.
---@param epsilon number | nil Optional epsilon, defaults to 1e-6.
---@return boolean is_unit True if approximately a unit quaternion.
---@usage <br>
--- ```
--- local q = Quaternion.new(0, 0, 0, 1)
--- print(Quaternion.is_unit(q)) -- true
--- ```
function Quaternion.is_unit(q, epsilon)
	if not isquat(q) then
		return error("Quaternion.is_unit requires a quaternion", 2)
	end
	epsilon = epsilon or 1e-6
	local diff = q[1] * q[1] + q[2] * q[2] + q[3] * q[3] + q[4] * q[4] - 1
	return diff * diff < epsilon * epsilon
end

self.is_unit = Quaternion.is_unit

--- Check if two quaternions are approximately equal (within epsilon).<br>
--- Accounts for the double-cover property: q and -q represent the same rotation.<br>
--- Returns true if the quaternions are close or negations of each other.
---@param a math.quaternion The first quaternion.
---@param b math.quaternion The second quaternion.
---@param epsilon number | nil Optional epsilon, defaults to 1e-6.
---@return boolean is_near True if approximately equal.
---@usage <br>
--- ```
--- local q1 = Quaternion.new(0, 0, 0, 1)
--- local q2 = Quaternion.new(0, 0, 0, 1)
--- print(Quaternion.is_near(q1, q2)) -- true
--- ```
function Quaternion.is_near(a, b, epsilon)
	if not isquat(a) or not isquat(b) then
		return error("Quaternion.is_near requires two quaternions", 2)
	end
	epsilon = epsilon or 1e-6
	local dx, dy, dz, dw = a[1] - b[1], a[2] - b[2], a[3] - b[3], a[4] - b[4]
	if (dx * dx + dy * dy + dz * dz + dw * dw) < epsilon * epsilon then
		return true
	end
	-- Also check negated (q and -q represent the same rotation)
	dx, dy, dz, dw = a[1] + b[1], a[2] + b[2], a[3] + b[3], a[4] + b[4]
	return (dx * dx + dy * dy + dz * dz + dw * dw) < epsilon * epsilon
end

self.is_near = Quaternion.is_near

--- Generate a uniformly distributed random unit quaternion (Shoemake's method).<br>
--- Returns a random unit quaternion uniformly distributed on the 3-sphere.
---@return math.quaternion quat A random unit quaternion.
---@usage <br>
--- ```
--- local q = Quaternion.random_unit()
--- print(Quaternion.is_unit(q)) -- true
--- ```
function Quaternion.random_unit()
	local u1 = math_random()
	local u2 = math_random()
	local u3 = math_random()
	local sq1 = math_sqrt(1 - u1)
	local sq2 = math_sqrt(u1)
	local t1 = 2 * math_pi * u2
	local t2 = 2 * math_pi * u3
	return Quaternion_new(sq1 * math_sin(t1), sq1 * math_cos(t1), sq2 * math_sin(t2), sq2 * math_cos(t2))
end

self.random_unit = Quaternion.random_unit

--- Convert quaternion to array.<br>
--- Returns a Lua array with the quaternion components.
---@param t math.quaternion The quaternion to convert.
---@return number[] array Array with components [x, y, z, w].
---@usage <br>
--- ```
--- local q = Quaternion.new(1, 2, 3, 4)
--- local arr = Quaternion.to_array(q)
--- ```
function Quaternion.to_array(t)
	if not isquat(t) then
		return error("Quaternion.to_array requires a quaternion", 2)
	end
	return { t[1], t[2], t[3], t[4] }
end

self.to_array = Quaternion.to_array

--- Convert quaternion to table.<br>
--- Returns a table with named keys for the quaternion components.
---@param t math.quaternion The quaternion to convert.
---@return table tbl Table with keys {x, y, z, w}.
---@usage <br>
--- ```
--- local q = Quaternion.new(1, 2, 3, 4)
--- local tbl = Quaternion.to_table(q)
--- ```
function Quaternion.to_table(t)
	if not isquat(t) then
		return error("Quaternion.to_table requires a quaternion", 2)
	end
	return { x = t[1], y = t[2], z = t[3], w = t[4] }
end

self.to_table = Quaternion.to_table

--- Create quaternion from table.<br>
--- Accepts a table with named keys (x, y, z, w) or numeric indices (1, 2, 3, 4).
---@param tbl table Table with x, y, z, w keys or numeric indices.
---@return math.quaternion quat The new quaternion.
---@usage <br>
--- ```
--- local tbl = { x = 1, y = 2, z = 3, w = 4 }
--- local q = Quaternion.from_table(tbl)
--- ```
function Quaternion.from_table(tbl)
	return Quaternion_new(tbl.x or tbl[1], tbl.y or tbl[2], tbl.z or tbl[3], tbl.w or tbl[4])
end

self.from_table = Quaternion.from_table

--- Return an iterator over the quaternion components.<br>
--- Yields index and value for each component (1:x, 2:y, 3:z, 4:w).<br>
--- Useful for iterating with for loops.
---@param t math.quaternion The quaternion instance.
---@return function iterator Iterator that yields index and value pairs.
---@return any state The state for the iterator.
---@return number initial_index The initial index (0).
---@usage <br>
--- ```
--- local q = Quaternion.new(1, 2, 3, 4)
--- for index, value in Quaternion.iterator(q) do
---   print(index, value)
--- end
--- ```
function Quaternion.iterator(t)
	if not isquat(t) then
		return error("Quaternion.iterator requires a quaternion", 2)
	end
	return function(state, index)
		index = index + 1
		if index <= 4 then
			return index, t[index]
		end
	end, nil, 0
end

self.iterator = Quaternion.iterator

-- Export
return setmetatable(self, {
	__call = function(_, ...)
		return Quaternion_new(...)
	end
})
