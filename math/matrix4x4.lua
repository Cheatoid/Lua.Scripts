-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Simple object-oriented 4x4 Matrix struct

-- Features:
-- * Fast numeric storage (mat[1] to mat[16]); no hashing, raw lookup
-- * Convenient field access via indexing
-- * Shorthand constructor; Matrix4x4(...) instead of Matrix4x4.new(...)
-- * Row-major order by default (consistent with most graphics APIs)

-- Distance Functions:
-- Matrix.distance(a, b) - Euclidean distance (Frobenius norm, L2 norm)
-- Matrix.distance_squared(a, b) - Squared Euclidean distance (faster, avoids sqrt)
-- Matrix.distance_manhattan(a, b) - Manhattan distance (L1 norm)
-- Matrix.distance_chebyshev(a, b) - Chebyshev distance (L∞ norm)
-- Matrix.distance_minkowski(a, b, p) - Minkowski distance (Lp norm, p >= 1)
--  - p=1: Manhattan, p=2: Euclidean, p=∞: Chebyshev

-- Projection Matrix Functions:
-- Matrix.perspective(fov_y, aspect, near_z, far_z) - Perspective projection matrix
-- Matrix.perspective_lrbt(left, right, bottom, top, near_z, far_z) - Perspective with explicit planes
-- Matrix.orthographic(left, right, bottom, top, near_z, far_z) - Orthographic projection matrix
-- Matrix.look_at(eye, target, up) - View matrix for camera positioning

-- Frustum Functions:
-- Matrix.extract_frustum(view_proj) - Extract 6 frustum planes from view-projection matrix
-- Matrix.point_in_frustum(point, frustum) - Test if point is inside frustum
-- Matrix.aabb_in_frustum(aabb, frustum) - Test if AABB intersects frustum
-- Matrix.sphere_in_frustum(center, radius, frustum) - Test if sphere intersects frustum

-- Localized global functions for better performance
local error, getmetatable, setmetatable, tonumber, tostring, type =
	error, getmetatable, setmetatable, tonumber, tostring, type
local math_abs, math_cos, math_sin, math_sqrt, math_tan =
	math.abs, math.cos, math.sin, math.sqrt, math.tan
local string_format = string.format

-- Import dependencies
local Plane = require "plane"
local Vector = require "vector"
local Plane_new = Plane.new

local self = {}   -- module
local Matrix = {} -- method table

local identity_table = { 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1 }

---@class math.matrix4x4
---@field [1] number m11
---@field [2] number m12
---@field [3] number m13
---@field [4] number m14
---@field [5] number m21
---@field [6] number m22
---@field [7] number m23
---@field [8] number m24
---@field [9] number m31
---@field [10] number m32
---@field [11] number m33
---@field [12] number m34
---@field [13] number m41
---@field [14] number m42
---@field [15] number m43
---@field [16] number m44

--- Create a new 4x4 matrix
---@return math.matrix4x4 matrix A new 4x4 matrix object
local function Matrix_new(...)
	local args = { ... }
	local n = #args

	-- If no arguments, return identity matrix
	if n == 0 then
		return setmetatable({
			1, 0, 0, 0,
			0, 1, 0, 0,
			0, 0, 1, 0,
			0, 0, 0, 1
		}, Matrix)
	end

	-- If 16 arguments, use them directly
	if n == 16 then
		local result = {}
		for i = 1, 16 do
			result[i] = tonumber(args[i]) or 0
		end
		return setmetatable(result, Matrix)
	end

	-- If 1 argument that's a table/array, try to extract values
	if n == 1 and type(args[1]) == "table" then
		local tbl = args[1]
		local result = {}
		for i = 1, 16 do
			result[i] = tonumber(tbl[i]) or 0
		end
		return setmetatable(result, Matrix)
	end

	-- Otherwise, return identity
	return setmetatable({
		1, 0, 0, 0,
		0, 1, 0, 0,
		0, 0, 1, 0,
		0, 0, 0, 1
	}, Matrix)
end

self.new = Matrix_new

self.identity = Matrix_new()

--- Test whether an object is a Matrix4x4 (by its metatable)
---@param obj any
---@return boolean
local function ismatrix(obj)
	return getmetatable(obj) == Matrix
end

self.is = ismatrix

Matrix.__index = Matrix

----------------------------------------------------------------------
-- Matrix arithmetic metamethods
----------------------------------------------------------------------

--- Addition: a + b
function Matrix.__add(a, b)
	if not ismatrix(a) or not ismatrix(b) then
		return error("Matrix addition requires two matrices", 2)
	end
	return Matrix_new(
		a[1] + b[1], a[2] + b[2], a[3] + b[3], a[4] + b[4],
		a[5] + b[5], a[6] + b[6], a[7] + b[7], a[8] + b[8],
		a[9] + b[9], a[10] + b[10], a[11] + b[11], a[12] + b[12],
		a[13] + b[13], a[14] + b[14], a[15] + b[15], a[16] + b[16]
	)
end

--- Subtraction: a - b
function Matrix.__sub(a, b)
	if not ismatrix(a) or not ismatrix(b) then
		return error("Matrix subtraction requires two matrices", 2)
	end
	return Matrix_new(
		a[1] - b[1], a[2] - b[2], a[3] - b[3], a[4] - b[4],
		a[5] - b[5], a[6] - b[6], a[7] - b[7], a[8] - b[8],
		a[9] - b[9], a[10] - b[10], a[11] - b[11], a[12] - b[12],
		a[13] - b[13], a[14] - b[14], a[15] - b[15], a[16] - b[16]
	)
end

--- Scalar multiplication: mat * scalar or scalar * mat
function Matrix.__mul(a, b)
	-- Matrix * Matrix multiplication
	if ismatrix(a) and ismatrix(b) then
		return Matrix_new(
			a[1] * b[1] + a[2] * b[5] + a[3] * b[9] + a[4] * b[13],
			a[1] * b[2] + a[2] * b[6] + a[3] * b[10] + a[4] * b[14],
			a[1] * b[3] + a[2] * b[7] + a[3] * b[11] + a[4] * b[15],
			a[1] * b[4] + a[2] * b[8] + a[3] * b[12] + a[4] * b[16],
			a[5] * b[1] + a[6] * b[5] + a[7] * b[9] + a[8] * b[13],
			a[5] * b[2] + a[6] * b[6] + a[7] * b[10] + a[8] * b[14],
			a[5] * b[3] + a[6] * b[7] + a[7] * b[11] + a[8] * b[15],
			a[5] * b[4] + a[6] * b[8] + a[7] * b[12] + a[8] * b[16],
			a[9] * b[1] + a[10] * b[5] + a[11] * b[9] + a[12] * b[13],
			a[9] * b[2] + a[10] * b[6] + a[11] * b[10] + a[12] * b[14],
			a[9] * b[3] + a[10] * b[7] + a[11] * b[11] + a[12] * b[15],
			a[9] * b[4] + a[10] * b[8] + a[11] * b[12] + a[12] * b[16],
			a[13] * b[1] + a[14] * b[5] + a[15] * b[9] + a[16] * b[13],
			a[13] * b[2] + a[14] * b[6] + a[15] * b[10] + a[16] * b[14],
			a[13] * b[3] + a[14] * b[7] + a[15] * b[11] + a[16] * b[15],
			a[13] * b[4] + a[14] * b[8] + a[15] * b[12] + a[16] * b[16]
		)
	end

	-- Matrix * scalar
	if ismatrix(a) and type(b) == "number" then
		return Matrix_new(
			a[1] * b, a[2] * b, a[3] * b, a[4] * b,
			a[5] * b, a[6] * b, a[7] * b, a[8] * b,
			a[9] * b, a[10] * b, a[11] * b, a[12] * b,
			a[13] * b, a[14] * b, a[15] * b, a[16] * b
		)
	end

	-- scalar * Matrix
	if type(a) == "number" and ismatrix(b) then
		return Matrix_new(
			b[1] * a, b[2] * a, b[3] * a, b[4] * a,
			b[5] * a, b[6] * a, b[7] * a, b[8] * a,
			b[9] * a, b[10] * a, b[11] * a, b[12] * a,
			b[13] * a, b[14] * a, b[15] * a, b[16] * a
		)
	end

	return error("Matrix multiplication requires a matrix and a number or two matrices", 2)
end

--- Scalar division: mat / scalar
function Matrix.__div(a, b)
	if not ismatrix(a) then
		return error("Matrix division requires a matrix", 2)
	end
	if type(b) ~= "number" then
		return error("Matrix division requires a number", 2)
	end
	if b == 0 then
		return error("Matrix division by zero", 2)
	end
	return Matrix_new(
		a[1] / b, a[2] / b, a[3] / b, a[4] / b,
		a[5] / b, a[6] / b, a[7] / b, a[8] / b,
		a[9] / b, a[10] / b, a[11] / b, a[12] / b,
		a[13] / b, a[14] / b, a[15] / b, a[16] / b
	)
end

--- Negation: -mat
function Matrix.__unm(a)
	if not ismatrix(a) then
		return error("Matrix negation requires a matrix", 2)
	end
	return Matrix_new(
		-a[1], -a[2], -a[3], -a[4],
		-a[5], -a[6], -a[7], -a[8],
		-a[9], -a[10], -a[11], -a[12],
		-a[13], -a[14], -a[15], -a[16]
	)
end

--- Readable string representation
function Matrix.__tostring(t)
	if not ismatrix(t) then
		return tostring(t)
	end
	return string_format(
		"Matrix4x4(\n  %.6g, %.6g, %.6g, %.6g\n  %.6g, %.6g, %.6g, %.6g\n  %.6g, %.6g, %.6g, %.6g\n  %.6g, %.6g, %.6g, %.6g\n)",
		t[1], t[2], t[3], t[4],
		t[5], t[6], t[7], t[8],
		t[9], t[10], t[11], t[12],
		t[13], t[14], t[15], t[16]
	)
end

--- Equality check: a == b
function Matrix.__eq(a, b)
	if not ismatrix(a) or not ismatrix(b) then
		return false
	end
	for i = 1, 16 do
		if a[i] ~= b[i] then
			return false
		end
	end
	return true
end

----------------------------------------------------------------------
-- Matrix utility functions
----------------------------------------------------------------------

--- Create a shallow copy
---@param t math.matrix4x4
---@return math.matrix4x4
function Matrix.clone(t)
	if not ismatrix(t) then
		return error("Matrix.clone requires a matrix", 2)
	end
	return Matrix_new(
		t[1], t[2], t[3], t[4],
		t[5], t[6], t[7], t[8],
		t[9], t[10], t[11], t[12],
		t[13], t[14], t[15], t[16]
	)
end

self.clone = Matrix.clone

--- Transpose matrix
---@param t math.matrix4x4
---@return math.matrix4x4
function Matrix.transpose(t)
	if not ismatrix(t) then
		return error("Matrix.transpose requires a matrix", 2)
	end
	return Matrix_new(
		t[1], t[5], t[9], t[13],
		t[2], t[6], t[10], t[14],
		t[3], t[7], t[11], t[15],
		t[4], t[8], t[12], t[16]
	)
end

self.transpose = Matrix.transpose

--- Get determinant of matrix
---@param t math.matrix4x4
---@return number
function Matrix.determinant(t)
	if not ismatrix(t) then
		return error("Matrix.determinant requires a matrix", 2)
	end
	-- 4x4 determinant calculation
	local a = t[1]
	local b = t[2]
	local c = t[3]
	local d = t[4]
	local e = t[5]
	local f = t[6]
	local g = t[7]
	local h = t[8]
	local i = t[9]
	local j = t[10]
	local k = t[11]
	local l = t[12]
	local m = t[13]
	local n = t[14]
	local o = t[15]
	local p = t[16]

	return
		a * (f * (k * p - l * o) - g * (j * p - l * n) + h * (j * o - k * n)) -
		b * (e * (k * p - l * o) - g * (i * p - l * m) + h * (i * o - k * m)) +
		c * (e * (j * p - l * n) - f * (i * p - l * m) + h * (i * n - j * m)) -
		d * (e * (j * o - k * n) - f * (i * o - k * m) + g * (i * n - j * m))
end

self.determinant = Matrix.determinant

--- Invert matrix
---@param t math.matrix4x4
---@return math.matrix4x4
function Matrix.inverse(t)
	if not ismatrix(t) then
		return error("Matrix.inverse requires a matrix", 2)
	end

	local det = Matrix.determinant(t)
	if det == 0 then
		return error("Matrix is singular and cannot be inverted", 2)
	end

	local a = t[1]
	local b = t[2]
	local c = t[3]
	local d = t[4]
	local e = t[5]
	local f = t[6]
	local g = t[7]
	local h = t[8]
	local i = t[9]
	local j = t[10]
	local k = t[11]
	local l = t[12]
	local m = t[13]
	local n = t[14]
	local o = t[15]
	local p = t[16]

	local inv_det = 1 / det

	return Matrix_new(
		inv_det * (f * (k * p - l * o) - g * (j * p - l * n) + h * (j * o - k * n)),
		inv_det * (-b * (k * p - l * o) + c * (j * p - l * n) - d * (j * o - k * n)),
		inv_det * (b * (g * p - h * o) - c * (f * p - h * n) + d * (f * o - g * n)),
		inv_det * (-b * (g * l - h * k) + c * (f * l - h * j) - d * (f * k - g * j)),
		inv_det * (-e * (k * p - l * o) + g * (i * p - l * m) - h * (i * o - k * m)),
		inv_det * (a * (k * p - l * o) - c * (i * p - l * m) + d * (i * o - k * m)),
		inv_det * (-a * (g * p - h * o) + c * (e * p - h * m) - d * (e * o - g * m)),
		inv_det * (a * (g * l - h * k) - c * (e * l - h * i) + d * (e * k - g * i)),
		inv_det * (e * (j * p - l * n) - f * (i * p - l * m) + h * (i * n - j * m)),
		inv_det * (-a * (j * p - l * n) + b * (i * p - l * m) - d * (i * n - j * m)),
		inv_det * (a * (f * p - h * n) - b * (e * p - h * m) + d * (e * n - f * m)),
		inv_det * (-a * (f * l - h * j) + b * (e * l - h * i) - d * (e * j - f * i)),
		inv_det * (-e * (j * o - k * n) + f * (i * o - k * m) - g * (i * n - j * m)),
		inv_det * (a * (j * o - k * n) - b * (i * o - k * m) + c * (i * n - j * m)),
		inv_det * (-a * (f * o - g * n) + b * (e * o - g * m) - c * (e * n - f * m)),
		inv_det * (a * (f * k - g * j) - b * (e * k - g * i) + c * (e * j - f * i))
	)
end

self.inverse = Matrix.inverse

--- Create translation matrix
---@param x number
---@param y number
---@param z number
---@return math.matrix4x4
function Matrix.translation(x, y, z)
	return Matrix_new(
		1, 0, 0, 0,
		0, 1, 0, 0,
		0, 0, 1, 0,
		x, y, z, 1
	)
end

self.translation = Matrix.translation

--- Create scale matrix
---@param x number
---@param y number
---@param z number
---@return math.matrix4x4
function Matrix.scale(x, y, z)
	return Matrix_new(
		x, 0, 0, 0,
		0, y, 0, 0,
		0, 0, z, 0,
		0, 0, 0, 1
	)
end

self.scale = Matrix.scale

--- Create rotation matrix around X axis (in radians)
---@param angle number Rotation angle in radians
---@return math.matrix4x4
function Matrix.rotation_x(angle)
	local c, s = math_cos(angle), math_sin(angle)
	return Matrix_new(
		1, 0, 0, 0,
		0, c, s, 0,
		0, -s, c, 0,
		0, 0, 0, 1
	)
end

self.rotation_x = Matrix.rotation_x

--- Create rotation matrix around Y axis (in radians)
---@param angle number Rotation angle in radians
---@return math.matrix4x4
function Matrix.rotation_y(angle)
	local c, s = math_cos(angle), math_sin(angle)
	return Matrix_new(
		c, 0, -s, 0,
		0, 1, 0, 0,
		s, 0, c, 0,
		0, 0, 0, 1
	)
end

self.rotation_y = Matrix.rotation_y

--- Create rotation matrix around Z axis (in radians)
---@param angle number Rotation angle in radians
---@return math.matrix4x4
function Matrix.rotation_z(angle)
	local c, s = math_cos(angle), math_sin(angle)
	return Matrix_new(
		c, s, 0, 0,
		-s, c, 0, 0,
		0, 0, 1, 0,
		0, 0, 0, 1
	)
end

self.rotation_z = Matrix.rotation_z

--- Create rotation matrix from Euler angles (in radians)
---@param x number Rotation around X axis
---@param y number Rotation around Y axis
---@param z number Rotation around Z axis
---@return math.matrix4x4
function Matrix.rotation_euler(x, y, z)
	local cx, sx = math_cos(x), math_sin(x)
	local cy, sy = math_cos(y), math_sin(y)
	local cz, sz = math_cos(z), math_sin(z)
	return Matrix_new(
		cy * cz, sx * sy * cz + cx * sz, -cx * sy * cz + sx * sz, 0,
		-cy * sz, -sx * sy * sz + cx * cz, cx * sy * sz + sx * cz, 0,
		sy, -sx * cy, cx * cy, 0,
		0, 0, 0, 1
	)
end

self.rotation_euler = Matrix.rotation_euler

--- Create perspective projection matrix
---@param fov_y number Field of view in Y direction (in radians)
---@param aspect number Aspect ratio (width/height)
---@param near_z number Near plane distance
---@param far_z number Far plane distance
---@return math.matrix4x4
function Matrix.perspective(fov_y, aspect, near_z, far_z)
	if near_z <= 0 or far_z <= 0 or near_z >= far_z then
		return error("Invalid near/far plane distances for perspective matrix", 2)
	end
	if aspect <= 0 then
		return error("Invalid aspect ratio for perspective matrix", 2)
	end

	local f = 1 / math_tan(fov_y * 0.5)
	local range_inv = 1 / (near_z - far_z)

	return Matrix_new(
		f / aspect, 0, 0, 0,
		0, f, 0, 0,
		0, 0, (near_z + far_z) * range_inv, -1,
		0, 0, near_z * far_z * range_inv * 2, 0
	)
end

self.perspective = Matrix.perspective

--- Create perspective projection matrix with left/right/bottom/top parameters
---@param left number Left plane
---@param right number Right plane
---@param bottom number Bottom plane
---@param top number Top plane
---@param near_z number Near plane distance
---@param far_z number Far plane distance
---@return math.matrix4x4
function Matrix.perspective_lrbt(left, right, bottom, top, near_z, far_z)
	if near_z <= 0 or far_z <= 0 or near_z >= far_z then
		return error("Invalid near/far plane distances for perspective matrix", 2)
	end
	if left == right or bottom == top then
		return error("Invalid left/right or bottom/top values for perspective matrix", 2)
	end

	local tx = (right + left) / (right - left)
	local ty = (top + bottom) / (top - bottom)
	local tz = (far_z + near_z) / (far_z - near_z)

	return Matrix_new(
		2 * near_z / (right - left), 0, 0, 0,
		0, 2 * near_z / (top - bottom), 0, 0,
		tx, ty, tz, 1,
		0, 0, -2 * near_z * far_z / (far_z - near_z), 0
	)
end

self.perspective_lrbt = Matrix.perspective_lrbt

--- Create orthographic projection matrix
---@param left number Left plane
---@param right number Right plane
---@param bottom number Bottom plane
---@param top number Top plane
---@param near_z number Near plane distance
---@param far_z number Far plane distance
---@return math.matrix4x4
function Matrix.orthographic(left, right, bottom, top, near_z, far_z)
	if left == right or bottom == top or near_z == far_z then
		return error("Invalid parameters for orthographic matrix", 2)
	end

	local tx = -(right + left) / (right - left)
	local ty = -(top + bottom) / (top - bottom)
	local tz = -(far_z + near_z) / (far_z - near_z)

	return Matrix_new(
		2 / (right - left), 0, 0, 0,
		0, 2 / (top - bottom), 0, 0,
		0, 0, 2 / (far_z - near_z), 0,
		tx, ty, tz, 1
	)
end

self.orthographic = Matrix.orthographic

--- Create look-at view matrix
---@param eye table Camera position {x, y, z}
---@param target table Target position {x, y, z}
---@param up table Up vector {x, y, z}, defaults to {0, 1, 0}
---@return math.matrix4x4
function Matrix.look_at(eye, target, up)
	if type(eye) ~= "table" or type(target) ~= "table" then
		return error("Matrix.look_at requires eye and target as tables", 2)
	end

	-- Default up vector
	if not up or type(up) ~= "table" then
		up = { x = 0, y = 1, z = 0 }
	end

	-- Extract positions
	local eye_x = tonumber(eye.x or eye[1]) or 0
	local eye_y = tonumber(eye.y or eye[2]) or 0
	local eye_z = tonumber(eye.z or eye[3]) or 0

	local target_x = tonumber(target.x or target[1]) or 0
	local target_y = tonumber(target.y or target[2]) or 0
	local target_z = tonumber(target.z or target[3]) or 0

	local up_x = tonumber(up.x or up[1]) or 0
	local up_y = tonumber(up.y or up[2]) or 0
	local up_z = tonumber(up.z or up[3]) or 0

	-- Calculate forward vector (z-axis)
	local forward_x = eye_x - target_x
	local forward_y = eye_y - target_y
	local forward_z = eye_z - target_z

	-- Normalize forward vector
	local forward_len = math_sqrt(forward_x * forward_x + forward_y * forward_y + forward_z * forward_z)
	if forward_len == 0 then
		return error("Eye and target positions cannot be the same", 2)
	end
	forward_x = forward_x / forward_len
	forward_y = forward_y / forward_len
	forward_z = forward_z / forward_len

	-- Calculate right vector (x-axis) = up × forward
	local right_x = up_y * forward_z - up_z * forward_y
	local right_y = up_z * forward_x - up_x * forward_z
	local right_z = up_x * forward_y - up_y * forward_x

	-- Normalize right vector
	local right_len = math_sqrt(right_x * right_x + right_y * right_y + right_z * right_z)
	if right_len == 0 then
		return error("Up vector cannot be parallel to view direction", 2)
	end
	right_x = right_x / right_len
	right_y = right_y / right_len
	right_z = right_z / right_len

	-- Calculate true up vector (y-axis) = forward × right
	local true_up_x = forward_y * right_z - forward_z * right_y
	local true_up_y = forward_z * right_x - forward_x * right_z
	local true_up_z = forward_x * right_y - forward_y * right_x

	-- Create look-at matrix
	return Matrix_new(
		right_x, true_up_x, forward_x, 0,
		right_y, true_up_y, forward_y, 0,
		right_z, true_up_z, forward_z, 0,
		-(right_x * eye_x + right_y * eye_y + right_z * eye_z),
		-(true_up_x * eye_x + true_up_y * eye_y + true_up_z * eye_z),
		-(forward_x * eye_x + forward_y * eye_y + forward_z * eye_z),
		1
	)
end

self.look_at = Matrix.look_at

--- Extract frustum planes from a view-projection matrix
---@param view_proj math.matrix4x4 Combined view-projection matrix
---@return table array Array of 6 frustum planes {normal, distance}
function Matrix.extract_frustum(view_proj)
	if not ismatrix(view_proj) then
		return error("Matrix.extract_frustum requires a matrix", 2)
	end

	-- Extract frustum planes from the matrix
	-- Each plane is stored as {normal = {x, y, z}, distance = d}
	local planes = {}

	-- Left plane: row4 + row1
	planes[1] = Plane_new(
		Vector(view_proj[1] + view_proj[4], view_proj[5] + view_proj[8], view_proj[9] + view_proj[12]),
		view_proj[13] + view_proj[16]
	)

	-- Right plane: row4 - row1
	planes[2] = Plane_new(
		Vector(view_proj[4] - view_proj[1], view_proj[8] - view_proj[5], view_proj[12] - view_proj[9]),
		view_proj[16] - view_proj[13]
	)

	-- Bottom plane: row4 + row2
	planes[3] = Plane_new(
		Vector(view_proj[2] + view_proj[4], view_proj[6] + view_proj[8], view_proj[10] + view_proj[12]),
		view_proj[14] + view_proj[16]
	)

	-- Top plane: row4 - row2
	planes[4] = Plane_new(
		Vector(view_proj[4] - view_proj[2], view_proj[8] - view_proj[6], view_proj[12] - view_proj[10]),
		view_proj[16] - view_proj[14]
	)

	-- Near plane: row3
	planes[5] = Plane_new(
		Vector(view_proj[3], view_proj[7], view_proj[11]),
		view_proj[15]
	)

	-- Far plane: row4 - row3
	planes[6] = Plane_new(
		Vector(view_proj[4] - view_proj[3], view_proj[8] - view_proj[7], view_proj[12] - view_proj[11]),
		view_proj[16] - view_proj[15]
	)

	-- Normalize all planes
	for i = 1, 6 do
		local plane = planes[i]
		planes[i] = Plane.normalize(plane)
	end

	return planes
end

self.extract_frustum = Matrix.extract_frustum

--- Test if a point is inside a frustum
---@param point table Point {x, y, z}
---@param frustum table Array of 6 frustum planes from extract_frustum
---@return boolean
function Matrix.point_in_frustum(point, frustum)
	if type(point) ~= "table" or type(frustum) ~= "table" or #frustum ~= 6 then
		return error("Matrix.point_in_frustum requires a point and 6 frustum planes", 2)
	end

	local x = tonumber(point.x or point[1]) or 0
	local y = tonumber(point.y or point[2]) or 0
	local z = tonumber(point.z or point[3]) or 0

	for i = 1, 6 do
		local plane = frustum[i]
		if Plane.distance_to_point(plane, { x = x, y = y, z = z }) < 0 then
			return false
		end
	end

	return true
end

self.point_in_frustum = Matrix.point_in_frustum

--- Test if an AABB is inside or intersecting a frustum
---@param aabb table AABB with min and max vectors {min = {x, y, z}, max = {x, y, z}}
---@param frustum table Array of 6 frustum planes from extract_frustum
---@return boolean
function Matrix.aabb_in_frustum(aabb, frustum)
	if type(aabb) ~= "table" or type(frustum) ~= "table" or #frustum ~= 6 then
		return error("Matrix.aabb_in_frustum requires an AABB and 6 frustum planes", 2)
	end

	local min_x = tonumber(aabb.min.x or aabb.min[1]) or 0
	local min_y = tonumber(aabb.min.y or aabb.min[2]) or 0
	local min_z = tonumber(aabb.min.z or aabb.min[3]) or 0
	local max_x = tonumber(aabb.max.x or aabb.max[1]) or 0
	local max_y = tonumber(aabb.max.y or aabb.max[2]) or 0
	local max_z = tonumber(aabb.max.z or aabb.max[3]) or 0

	for i = 1, 6 do
		local plane = frustum[i]

		-- Find the most positive vertex for this plane
		local vx = plane[1] >= 0 and max_x or min_x
		local vy = plane[2] >= 0 and max_y or min_y
		local vz = plane[3] >= 0 and max_z or min_z

		-- Test if the positive vertex is outside the plane
		if Plane.distance_to_point(plane, { x = vx, y = vy, z = vz }) < 0 then
			return false
		end
	end

	return true
end

self.aabb_in_frustum = Matrix.aabb_in_frustum

--- Test if a sphere is inside or intersecting a frustum
---@param center table Sphere center {x, y, z}
---@param radius number Sphere radius
---@param frustum table Array of 6 frustum planes from extract_frustum
---@return boolean
function Matrix.sphere_in_frustum(center, radius, frustum)
	if type(center) ~= "table" or type(frustum) ~= "table" or #frustum ~= 6 then
		return error("Matrix.sphere_in_frustum requires a center, radius, and 6 frustum planes", 2)
	end

	local x = tonumber(center.x or center[1]) or 0
	local y = tonumber(center.y or center[2]) or 0
	local z = tonumber(center.z or center[3]) or 0
	radius = tonumber(radius) or 0

	for i = 1, 6 do
		local plane = frustum[i]
		if Plane.distance_to_point(plane, { x = x, y = y, z = z }) < -radius then
			return false
		end
	end

	return true
end

self.sphere_in_frustum = Matrix.sphere_in_frustum

--- Convert matrix to table
---@param t math.matrix4x4
---@return table
function Matrix.to_table(t)
	if not ismatrix(t) then
		return error("Matrix.to_table requires a matrix", 2)
	end
	return {
		t[1], t[2], t[3], t[4],
		t[5], t[6], t[7], t[8],
		t[9], t[10], t[11], t[12],
		t[13], t[14], t[15], t[16]
	}
end

self.to_table = Matrix.to_table

--- Create matrix from table
---@param tbl table Table with 16 numeric values
---@return math.matrix4x4
function Matrix.from_table(tbl)
	if type(tbl) ~= "table" then
		return error("Matrix.from_table requires a table", 2)
	end
	return Matrix_new(
		tbl[1] or 0, tbl[2] or 0, tbl[3] or 0, tbl[4] or 0,
		tbl[5] or 0, tbl[6] or 0, tbl[7] or 0, tbl[8] or 0,
		tbl[9] or 0, tbl[10] or 0, tbl[11] or 0, tbl[12] or 0,
		tbl[13] or 0, tbl[14] or 0, tbl[15] or 0, tbl[16] or 0
	)
end

self.from_table = Matrix.from_table

--- Get element at row, column
---@param t math.matrix4x4
---@param row number Row index (1-4)
---@param col number Column index (1-4)
---@return number
function Matrix.get(t, row, col)
	if not ismatrix(t) then
		return error("Matrix.get requires a matrix", 2)
	end
	if row < 1 or row > 4 or col < 1 or col > 4 then
		return error("Matrix indices must be between 1 and 4", 2)
	end
	return t[(row - 1) * 4 + col]
end

self.get = Matrix.get

--- Set element at row, column
---@param t math.matrix4x4
---@param row number Row index (1-4)
---@param col number Column index (1-4)
---@param value number Value to set
---@return math.matrix4x4
function Matrix.set(t, row, col, value)
	if not ismatrix(t) then
		return error("Matrix.set requires a matrix", 2)
	end
	if row < 1 or row > 4 or col < 1 or col > 4 then
		return error("Matrix indices must be between 1 and 4", 2)
	end
	t[(row - 1) * 4 + col] = value
	return t
end

self.set = Matrix.set

--- Get row as table
---@param t math.matrix4x4
---@param row number Row index (1-4)
---@return table
function Matrix.get_row(t, row)
	if not ismatrix(t) then
		return error("Matrix.get_row requires a matrix", 2)
	end
	if row < 1 or row > 4 then
		return error("Row index must be between 1 and 4", 2)
	end
	local offset = (row - 1) * 4
	return { t[offset + 1], t[offset + 2], t[offset + 3], t[offset + 4] }
end

self.get_row = Matrix.get_row

--- Get column as table
---@param t math.matrix4x4
---@param col number Column index (1-4)
---@return table
function Matrix.get_column(t, col)
	if not ismatrix(t) then
		return error("Matrix.get_column requires a matrix", 2)
	end
	if col < 1 or col > 4 then
		return error("Column index must be between 1 and 4", 2)
	end
	return { t[col], t[col + 4], t[col + 8], t[col + 12] }
end

self.get_column = Matrix.get_column

--- Multiply matrix by 3D vector (treats vector as [x, y, z, 1])
---@param mat math.matrix4x4
---@param vec math.vector
---@return math.vector
function Matrix.multiply_vector(mat, vec)
	if not ismatrix(mat) then
		return error("Matrix.multiply_vector requires a matrix", 2)
	end
	if type(vec) ~= "table" or (not Vector and #vec < 3) or (Vector and not Vector.is(vec)) then
		return error("Matrix.multiply_vector requires a vector", 2)
	end
	local x, y, z = vec[1], vec[2], vec[3]
	return {
		mat[1] * x + mat[2] * y + mat[3] * z + mat[4],
		mat[5] * x + mat[6] * y + mat[7] * z + mat[8],
		mat[9] * x + mat[10] * y + mat[11] * z + mat[12]
	}
end

self.multiply_vector = Matrix.multiply_vector

--- Check if matrix is approximately identity (within epsilon)
---@param t math.matrix4x4
---@param epsilon? number Optional epsilon, defaults to 1e-6
---@return boolean
function Matrix.is_identity(t, epsilon)
	if not ismatrix(t) then
		return error("Matrix.is_identity requires a matrix", 2)
	end
	epsilon = epsilon or 1e-6

	for i = 1, 16 do
		if math_abs(t[i] - identity_table[i]) > epsilon then
			return false
		end
	end
	return true
end

self.is_identity = Matrix.is_identity

--- Check if two matrices are approximately equal (within epsilon)
---@param a math.matrix4x4
---@param b math.matrix4x4
---@param epsilon? number Optional epsilon, defaults to 1e-6
---@return boolean
function Matrix.is_near(a, b, epsilon)
	if not ismatrix(a) or not ismatrix(b) then
		return error("Matrix.is_near requires two matrices", 2)
	end
	epsilon = epsilon or 1e-6
	for i = 1, 16 do
		if math_abs(a[i] - b[i]) > epsilon then
			return false
		end
	end
	return true
end

self.is_near = Matrix.is_near

--- Euclidean distance (Frobenius norm) between two matrices
---@param a math.matrix4x4
---@param b math.matrix4x4
---@return number
function Matrix.distance(a, b)
	if not ismatrix(a) or not ismatrix(b) then
		return error("Matrix.distance requires two matrices", 2)
	end
	local sum = 0
	for i = 1, 16 do
		local diff = a[i] - b[i]
		sum = sum + diff * diff
	end
	return math_sqrt(sum)
end

self.distance = Matrix.distance

--- Squared Euclidean distance between two matrices (faster, avoids sqrt)
---@param a math.matrix4x4
---@param b math.matrix4x4
---@return number
function Matrix.distance_squared(a, b)
	if not ismatrix(a) or not ismatrix(b) then
		return error("Matrix.distance_squared requires two matrices", 2)
	end
	local sum = 0
	for i = 1, 16 do
		local diff = a[i] - b[i]
		sum = sum + diff * diff
	end
	return sum
end

self.distance_squared = Matrix.distance_squared

--- Manhattan distance (L1 norm) between two matrices
---@param a math.matrix4x4
---@param b math.matrix4x4
---@return number
function Matrix.distance_manhattan(a, b)
	if not ismatrix(a) or not ismatrix(b) then
		return error("Matrix.distance_manhattan requires two matrices", 2)
	end
	local sum = 0
	for i = 1, 16 do
		sum = sum + math_abs(a[i] - b[i])
	end
	return sum
end

self.distance_manhattan = Matrix.distance_manhattan

--- Chebyshev distance (L∞ norm) between two matrices
---@param a math.matrix4x4
---@param b math.matrix4x4
---@return number
function Matrix.distance_chebyshev(a, b)
	if not ismatrix(a) or not ismatrix(b) then
		return error("Matrix.distance_chebyshev requires two matrices", 2)
	end
	local max_diff = 0
	for i = 1, 16 do
		local diff = math_abs(a[i] - b[i])
		if diff > max_diff then
			max_diff = diff
		end
	end
	return max_diff
end

self.distance_chebyshev = Matrix.distance_chebyshev

--- Minkowski distance (Lp norm) between two matrices
---@param a math.matrix4x4
---@param b math.matrix4x4
---@param p number Order parameter (p >= 1), defaults to 2 (Euclidean)
---@return number
function Matrix.distance_minkowski(a, b, p)
	if not ismatrix(a) or not ismatrix(b) then
		return error("Matrix.distance_minkowski requires two matrices", 2)
	end
	p = tonumber(p) or 2
	if p < 1 then
		return error("Minkowski distance requires p >= 1", 2)
	end

	if p == 1 then
		local sum = 0
		for i = 1, 16 do
			sum = sum + math_abs(a[i] - b[i])
		end
		return sum -- Manhattan
	elseif p == 2 then
		local sum = 0
		for i = 1, 16 do
			local diff = a[i] - b[i]
			sum = sum + diff * diff
		end
		return math_sqrt(sum) -- Euclidean
	elseif p == math.huge or p == 1 / 0 then
		local max_diff = 0
		for i = 1, 16 do
			local diff = math_abs(a[i] - b[i])
			if diff > max_diff then
				max_diff = diff
			end
		end
		return max_diff -- Chebyshev
	else
		local sum = 0
		for i = 1, 16 do
			sum = sum + (math_abs(a[i] - b[i])) ^ p
		end
		return sum ^ (1 / p)
	end
end

self.distance_minkowski = Matrix.distance_minkowski

-- Export
return setmetatable(self, {
	__call = function(_, ...)
		return Matrix_new(...)
	end
})
