-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Simple object-oriented Euler angles struct (pitch-yaw-roll)

-- Features:
-- Fast numeric storage (euler[1], euler[2], euler[3]); no hashing, raw lookup
-- Convenient field access (euler.pitch, euler.yaw, euler.roll)
-- Shorthand constructor; Euler(pitch, yaw, roll) instead of Euler.new(pitch, yaw, roll)
-- Automatic normalization to proper ranges
-- Built-in conversion to/from matrices and quaternions

-- Euler Functions:
-- Euler.from_angles(pitch, yaw, roll) - Create from individual angles
-- Euler.from_matrix(matrix) - Extract Euler angles from rotation matrix
-- Euler.to_matrix(euler) - Convert to rotation matrix
-- Euler.lerp(a, b, t) - Linear interpolation between Euler angles
-- Euler.slerp(a, b, t) - Spherical linear interpolation
-- Euler.normalize(euler) - Normalize all angles to proper ranges

-- Localized global functions for better performance
local error, getmetatable, rawget, rawset, setmetatable, tonumber, tostring, type =
	error, getmetatable, rawget, rawset, setmetatable, tonumber, tostring, type
local math_abs, math_acos, math_asin, math_atan2, math_ceil, math_cos, math_floor, math_max, math_min, math_random, math_sin, math_sqrt, math_tan =
	math.abs, math.acos, math.asin, math.atan2, math.ceil, math.cos, math.floor, math.max, math.min, math.random,
	math.sin, math.sqrt, math.tan
local math_copysign = math.copysign or function(x, sign)
	return sign < 0 and -math_abs(x) or math_abs(x)
end
local math_pi = math.pi
local string_format = string.format
local two_pi = 2 * math_pi
local DEG2RAD = math_pi / 180

-- Import dependencies
local Angle = require "angle"
local Matrix4x4 = require "matrix4x4"
local Vector = require "vector"

local self = {}  -- module
local Euler = {} -- method table

---@class math.euler
---@field [1] number Pitch angle in radians
---@field [2] number Yaw angle in radians
---@field [3] number Roll angle in radians
---@field pitch number Pitch angle in radians (field access)
---@field yaw number Yaw angle in radians (field access)
---@field roll number Roll angle in radians (field access)

--- Create new Euler angles from pitch, yaw, roll
---@param pitch? number Pitch in radians, defaults to 0
---@param yaw? number Yaw in radians, defaults to 0
---@param roll? number Roll in radians, defaults to 0
---@return math.euler euler A new Euler angles object
local function Euler_new(pitch, yaw, roll)
	pitch = tonumber(pitch) or 0
	yaw = tonumber(yaw) or 0
	roll = tonumber(roll) or 0

	-- Normalize angles to proper ranges
	-- Pitch: [-π/2, π/2] (clamped to prevent gimbal lock)
	-- Yaw: [-π, π]
	-- Roll: [-π, π]

	pitch = math_max(-math_pi * 0.5 + 0.001, math_min(math_pi * 0.5 - 0.001, pitch))

	yaw = yaw % two_pi
	if yaw > math_pi then
		yaw = yaw - two_pi
	end

	roll = roll % two_pi
	if roll > math_pi then
		roll = roll - two_pi
	end

	return setmetatable({ pitch, yaw, roll }, Euler)
end

self.new = Euler_new

--- Test whether an object is an Euler (by its metatable)
---@param obj any
---@return boolean
local function iseuler(obj)
	return getmetatable(obj) == Euler
end

self.is = iseuler

function Euler.__index(t, k)
	if k == 1 or k == "pitch" then
		return rawget(t, 1)
	end
	if k == 2 or k == "yaw" then
		return rawget(t, 2)
	end
	if k == 3 or k == "roll" then
		return rawget(t, 3)
	end
	return rawget(Euler, k)
end

function Euler.__newindex(t, k, v)
	if k == 1 or k == "pitch" then
		local pitch = tonumber(v) or 0
		pitch = math_max(-math_pi * 0.5 + 0.001, math_min(math_pi * 0.5 - 0.001, pitch))
		rawset(t, 1, pitch)
	elseif k == 2 or k == "yaw" then
		local yaw = (tonumber(v) or 0) % two_pi
		if yaw > math_pi then
			yaw = yaw - two_pi
		end
		rawset(t, 2, yaw)
	elseif k == 3 or k == "roll" then
		local roll = (tonumber(v) or 0) % two_pi
		if roll > math_pi then
			roll = roll - two_pi
		end
		rawset(t, 3, roll)
	else
		return error("Euler only supports 'pitch', 'yaw', and 'roll' field assignment", 2)
	end
end

----------------------------------------------------------------------
-- Euler arithmetic metamethods
----------------------------------------------------------------------

--- Addition: euler + euler
function Euler.__add(a, b)
	if iseuler(a) and iseuler(b) then
		return Euler_new(a[1] + b[1], a[2] + b[2], a[3] + b[3])
	end
	return error("Euler addition requires two Euler angles", 2)
end

--- Subtraction: euler - euler
function Euler.__sub(a, b)
	if iseuler(a) and iseuler(b) then
		return Euler_new(a[1] - b[1], a[2] - b[2], a[3] - b[3])
	end
	return error("Euler subtraction requires two Euler angles", 2)
end

--- Multiplication: euler * number
function Euler.__mul(a, b)
	if iseuler(a) and type(b) == "number" then
		return Euler_new(a[1] * b, a[2] * b, a[3] * b)
	end
	if type(a) == "number" and iseuler(b) then
		return Euler_new(a * b[1], a * b[2], a * b[3])
	end
	return error("Euler multiplication requires Euler and number", 2)
end

--- Division: euler / number
function Euler.__div(a, b)
	if iseuler(a) and type(b) == "number" then
		if b == 0 then
			return error("Division by zero", 2)
		end
		return Euler_new(a[1] / b, a[2] / b, a[3] / b)
	end
	return error("Euler division requires Euler and number", 2)
end

--- Negation: -euler
function Euler.__unm(a)
	if iseuler(a) then
		return Euler_new(-a[1], -a[2], -a[3])
	end
	return error("Euler negation requires Euler angles", 2)
end

--- Equality check: a == b
function Euler.__eq(a, b)
	if not iseuler(a) or not iseuler(b) then
		return false
	end
	return a[1] == b[1] and a[2] == b[2] and a[3] == b[3]
end

--- Readable string representation
function Euler.__tostring(t)
	if not iseuler(t) then
		return tostring(t)
	end
	return string_format("Euler(pitch: %.6g rad (%.6g°), yaw: %.6g rad (%.6g°), roll: %.6g rad (%.6g°))",
		t[1], t[1] * 180 / math_pi,
		t[2], t[2] * 180 / math_pi,
		t[3], t[3] * 180 / math_pi
	)
end

----------------------------------------------------------------------
-- Euler utility functions
----------------------------------------------------------------------

--- Create a shallow copy
---@param t math.euler
---@return math.euler
function Euler.clone(t)
	if not iseuler(t) then
		return error("Euler.clone requires Euler angles", 2)
	end
	return Euler_new(t[1], t[2], t[3])
end

self.clone = Euler.clone

--- Create Euler angles from individual Angle objects
---@param pitch math.angle|number Pitch angle
---@param yaw math.angle|number Yaw angle
---@param roll math.angle|number Roll angle
---@return math.euler
function Euler.from_angles(pitch, yaw, roll)
	local pitch_rad = Angle.is and Angle.is(pitch) and pitch[1] or tonumber(pitch) or 0
	local yaw_rad = Angle.is and Angle.is(yaw) and yaw[1] or tonumber(yaw) or 0
	local roll_rad = Angle.is and Angle.is(roll) and roll[1] or tonumber(roll) or 0

	return Euler_new(pitch_rad, yaw_rad, roll_rad)
end

self.from_angles = Euler.from_angles

--- Extract Euler angles from rotation matrix
---@param matrix math.matrix4x4 Rotation matrix
---@return math.euler
function Euler.from_matrix(matrix)
	if not Matrix4x4.is(matrix) then
		return error("Euler.from_matrix requires a matrix", 2)
	end

	-- Extract Euler angles using standard extraction formulas
	-- Assuming XYZ rotation order (pitch, yaw, roll)
	local m11, m12, m13, m14 = matrix[1], matrix[2], matrix[3], matrix[4]
	local m21, m22, m23, m24 = matrix[5], matrix[6], matrix[7], matrix[8]
	local m31, m32, m33, m34 = matrix[9], matrix[10], matrix[11], matrix[12]

	-- Calculate pitch (around X axis)
	local pitch = math_atan2(m23, m33)

	-- Calculate yaw (around Y axis)
	local yaw = math_atan2(-m13, math_sqrt(m23 * m23 + m33 * m33))

	-- Calculate roll (around Z axis)
	local roll = math_atan2(m12, m11)

	return Euler_new(pitch, yaw, roll)
end

self.from_matrix = Euler.from_matrix

--- Convert Euler angles to rotation matrix
---@param t math.euler
---@return math.matrix4x4
function Euler.to_matrix(t)
	if not iseuler(t) then
		return error("Euler.to_matrix requires Euler angles", 2)
	end

	-- Create rotation matrices for each axis
	local pitch, yaw, roll = t[1], t[2], t[3]

	-- Pitch rotation matrix (X axis)
	local cp, sp = math_cos(pitch), math_sin(pitch)
	local pitch_matrix = Matrix4x4.new(
		1, 0, 0, 0,
		0, cp, sp, 0,
		0, -sp, cp, 0,
		0, 0, 0, 1
	)

	-- Yaw rotation matrix (Y axis)
	local cy, sy = math_cos(yaw), math_sin(yaw)
	local yaw_matrix = Matrix4x4.new(
		cy, 0, -sy, 0,
		0, 1, 0, 0,
		sy, 0, cy, 0,
		0, 0, 0, 1
	)

	-- Roll rotation matrix (Z axis)
	local cr, sr = math_cos(roll), math_sin(roll)
	local roll_matrix = Matrix4x4.new(
		cr, sr, 0, 0,
		-sr, cr, 0, 0,
		0, 0, 1, 0,
		0, 0, 0, 1
	)

	-- Combined rotation: Roll * Yaw * Pitch (XYZ order)
	return roll_matrix * yaw_matrix * pitch_matrix
end

self.to_matrix = Euler.to_matrix

--- Get forward vector from Euler angles
---@param t math.euler
---@return math.vector forward Forward vector
function Euler.get_forward(t)
	if not iseuler(t) then
		return error("Euler.get_forward requires Euler angles", 2)
	end

	local pitch, yaw = t[1], t[2]
	return Vector(
		math_cos(yaw) * math_cos(pitch),
		math_sin(pitch),
		math_sin(yaw) * math_cos(pitch)
	)
end

self.get_forward = Euler.get_forward

--- Get right vector from Euler angles
---@param t math.euler
---@return math.vector right Right vector
function Euler.get_right(t)
	if not iseuler(t) then
		return error("Euler.get_right requires Euler angles", 2)
	end

	local yaw = t[2]
	return Vector(
		math_cos(yaw + math_pi * 0.5),
		0,
		math_sin(yaw + math_pi * 0.5)
	)
end

self.get_right = Euler.get_right

--- Get up vector from Euler angles
---@param t math.euler
---@return math.vector up Up vector
function Euler.get_up(t)
	if not iseuler(t) then
		return error("Euler.get_up requires Euler angles", 2)
	end

	local pitch, yaw = t[1], t[2]
	local forward_x = math_cos(yaw) * math_cos(pitch)
	local forward_y = math_sin(pitch)
	local forward_z = math_sin(yaw) * math_cos(pitch)
	local right_x = math_cos(yaw + math_pi * 0.5)
	local right_y = 0
	local right_z = math_sin(yaw + math_pi * 0.5)

	-- Up = right × forward
	return Vector(
		right_y * forward_z - right_z * forward_y,
		right_z * forward_x - right_x * forward_z,
		right_x * forward_y - right_y * forward_x
	)
end

self.get_up = Euler.get_up

--- Linear interpolation between Euler angles
---@param a math.euler Start Euler angles
---@param b math.euler End Euler angles
---@param t number Interpolation factor [0, 1]
---@return math.euler
function Euler.lerp(a, b, t)
	if not iseuler(a) or not iseuler(b) then
		return error("Euler.lerp requires two Euler angles", 2)
	end
	t = tonumber(t) or 0

	return Euler_new(
		a[1] + (b[1] - a[1]) * t,
		a[2] + (b[2] - a[2]) * t,
		a[3] + (b[3] - a[3]) * t
	)
end

self.lerp = Euler.lerp

--- Spherical linear interpolation between Euler angles
---@param a math.euler Start Euler angles
---@param b math.euler End Euler angles
---@param t number Interpolation factor [0, 1]
---@return math.euler
function Euler.slerp(a, b, t)
	if not iseuler(a) or not iseuler(b) then
		return error("Euler.slerp requires two Euler angles", 2)
	end
	t = tonumber(t) or 0

	-- Convert to matrices for proper spherical interpolation
	local matrix_a = Euler.to_matrix(a)
	local matrix_b = Euler.to_matrix(b)

	-- Extract quaternions from matrices (simplified approach)
	-- For production use, a proper quaternion implementation would be better
	local qa = Euler._matrix_to_quaternion(matrix_a)
	local qb = Euler._matrix_to_quaternion(matrix_b)

	-- SLERP quaternions
	local qr = Euler._quaternion_slerp(qa, qb, t)

	-- Convert back to Euler
	return Euler._quaternion_to_euler(qr)
end

self.slerp = Euler.slerp

--- Normalize all angles to proper ranges
---@param t math.euler
---@return math.euler
function Euler.normalize(t)
	if not iseuler(t) then
		return error("Euler.normalize requires Euler angles", 2)
	end

	return Euler_new(t[1], t[2], t[3])
end

self.normalize = Euler.normalize

--- Check if two Euler angles are approximately equal (within epsilon)
---@param a math.euler First Euler angles
---@param b math.euler Second Euler angles
---@param epsilon? number Optional epsilon in radians, defaults to 1e-6
---@return boolean
function Euler.is_near(a, b, epsilon)
	if not iseuler(a) or not iseuler(b) then
		return error("Euler.is_near requires two Euler angles", 2)
	end
	epsilon = epsilon or 1e-6

	return math_abs(a[1] - b[1]) < epsilon and
		math_abs(a[2] - b[2]) < epsilon and
		math_abs(a[3] - b[3]) < epsilon
end

self.is_near = Euler.is_near

--- Clamp Euler angles to ranges
---@param t math.euler Euler angles to clamp
---@param min_pitch number Minimum pitch in radians
---@param max_pitch number Maximum pitch in radians
---@param min_yaw number Minimum yaw in radians
---@param max_yaw number Maximum yaw in radians
---@param min_roll number Minimum roll in radians
---@param max_roll number Maximum roll in radians
---@return math.euler
function Euler.clamp(t, min_pitch, max_pitch, min_yaw, max_yaw, min_roll, max_roll)
	if not iseuler(t) then
		return error("Euler.clamp requires Euler angles", 2)
	end

	local clamped_pitch = math_max(tonumber(min_pitch) or -math_pi * 0.5,
		math_min(tonumber(max_pitch) or math_pi * 0.5, t[1]))
	local clamped_yaw = math_max(tonumber(min_yaw) or -math_pi, math_min(tonumber(max_yaw) or math_pi, t[2]))
	local clamped_roll = math_max(tonumber(min_roll) or -math_pi, math_min(tonumber(max_roll) or math_pi, t[3]))

	return Euler_new(clamped_pitch, clamped_yaw, clamped_roll)
end

self.clamp = Euler.clamp

--- Convert Euler angles to table
---@param t math.euler
---@return {pitch: number, yaw: number, roll: number}
function Euler.to_table(t)
	if not iseuler(t) then
		return error("Euler.to_table requires Euler angles", 2)
	end
	return {
		pitch = t[1],
		yaw = t[2],
		roll = t[3]
	}
end

self.to_table = Euler.to_table

--- Create Euler angles from table
---@param tbl table Table with pitch, yaw, roll keys
---@return math.euler
function Euler.from_table(tbl)
	if type(tbl) ~= "table" then
		return error("Euler.from_table requires a table", 2)
	end

	return Euler_new(
		tbl.pitch or 0,
		tbl.yaw or 0,
		tbl.roll or 0
	)
end

self.from_table = Euler.from_table

----------------------------------------------------------------------
-- Internal helper functions for quaternion operations
----------------------------------------------------------------------

--- Convert rotation matrix to quaternion (simplified)
---@param matrix math.matrix4x4
---@return {w: number, x: number, y: number, z: number}
function Euler._matrix_to_quaternion(matrix)
	local m11, m12, m13 = matrix[1], matrix[2], matrix[3]
	local m21, m22, m23 = matrix[5], matrix[6], matrix[7]
	local m31, m32, m33 = matrix[9], matrix[10], matrix[11]

	local trace = m11 + m22 + m33

	if trace > 0 then
		local s = math_sqrt(trace + 1) * 2
		return {
			w = 0.25 * s,
			x = (m32 - m23) / s,
			y = (m13 - m31) / s,
			z = (m21 - m12) / s
		}
	end
	if m11 > m22 and m11 > m33 then
		local s = math_sqrt(1 + m11 - m22 - m33) * 2
		return {
			w = (m32 - m23) / s,
			x = 0.25 * s,
			y = (m12 + m21) / s,
			z = (m13 + m31) / s
		}
	end
	if m22 > m33 then
		local s = math_sqrt(1 + m22 - m11 - m33) * 2
		return {
			w = (m13 - m31) / s,
			x = (m12 + m21) / s,
			y = 0.25 * s,
			z = (m23 + m32) / s
		}
	end

	local s = math_sqrt(1 + m33 - m11 - m22) * 2
	return {
		w = (m21 - m12) / s,
		x = (m13 + m31) / s,
		y = (m23 + m32) / s,
		z = 0.25 * s
	}
end

--- Convert quaternion to Euler angles
---@param q {w: number, x: number, y: number, z: number}
---@return math.euler
function Euler._quaternion_to_euler(q)
	local w, x, y, z = q.w, q.x, q.y, q.z

	-- Roll (x-axis rotation)
	local sinr_cosp = 2 * (w * x + y * z)
	local cosr_cosp = 1 - 2 * (x * x + y * y)
	local roll = math_atan2(sinr_cosp, cosr_cosp)

	-- Pitch (y-axis rotation)
	local sinp = 2 * (w * y - z * x)
	local pitch
	if math_abs(sinp) >= 1 then
		pitch = math_copysign(math_pi * 0.5, sinp) -- Use 90 degrees if out of range
	else
		pitch = math_asin(sinp)
	end

	-- Yaw (z-axis rotation)
	local siny_cosp = 2 * (w * z + x * y)
	local cosy_cosp = 1 - 2 * (y * y + z * z)
	local yaw = math_atan2(siny_cosp, cosy_cosp)

	return Euler_new(pitch, yaw, roll)
end

--- Spherical linear interpolation between quaternions
---@param q1 table First quaternion
---@param q2 table Second quaternion
---@param t number Interpolation factor
---@return table quat Interpolated quaternion
function Euler._quaternion_slerp(q1, q2, t)
	-- Calculate dot product
	local dot = q1.w * q2.w + q1.x * q2.x + q1.y * q2.y + q1.z * q2.z

	-- If quaternions are very close, use linear interpolation
	if math_abs(dot) > 0.9995 then
		return {
			w = q1.w + (q2.w - q1.w) * t,
			x = q1.x + (q2.x - q1.x) * t,
			y = q1.y + (q2.y - q1.y) * t,
			z = q1.z + (q2.z - q1.z) * t
		}
	end

	-- Calculate angle between quaternions
	local theta = math_acos(math_abs(dot))
	local sin_theta = math_sin(theta)

	-- Calculate interpolation weights
	local weight1 = math_sin((1 - t) * theta) / sin_theta
	local weight2 = math_sin(t * theta) / sin_theta

	-- Adjust for shortest path
	if dot < 0 then
		weight2 = -weight2
	end

	return {
		w = q1.w * weight1 + q2.w * weight2,
		x = q1.x * weight1 + q2.x * weight2,
		y = q1.y * weight1 + q2.y * weight2,
		z = q1.z * weight1 + q2.z * weight2
	}
end

-- Export
return setmetatable(self, {
	__call = function(_, ...)
		return Euler_new(...)
	end
})
