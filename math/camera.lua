-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- 3D First-Person Shooter (FPS) Camera implementation
-- Uses Matrix4x4 for view and projection matrices
-- Supports movement, rotation, and frustum culling

-- Localized global functions for better performance
local error, getmetatable, rawget, rawset, setmetatable, tonumber, tostring, type =
	error, getmetatable, rawget, rawset, setmetatable, tonumber, tostring, type
local math_abs, math_acos, math_asin, math_atan2, math_ceil, math_cos, math_floor, math_max, math_min, math_random, math_sin, math_sqrt, math_tan =
	math.abs, math.acos, math.asin, math.atan2, math.ceil, math.cos, math.floor, math.max, math.min, math.random,
	math.sin, math.sqrt, math.tan
local math_pi = math.pi
local string_format = string.format

-- Import required modules
local Matrix4x4 = require "matrix4x4"
local Vector = require "vector"

local self = {}   -- module
local Camera = {} -- method table

---@class math.camera
---@field position math.vector Camera position as Vector
---@field rotation table Camera rotation {pitch, yaw, roll} in radians
---@field fov number Field of view in radians
---@field aspect number Aspect ratio (width/height)
---@field near_z number Near plane distance
---@field far_z number Far plane distance
---@field move_speed number Movement speed
---@field mouse_sensitivity number Mouse sensitivity for rotation
---@field view_matrix math.matrix4x4 Current view matrix
---@field projection_matrix math.matrix4x4 Current projection matrix
---@field view_projection_matrix math.matrix4x4 Combined view-projection matrix
---@field frustum table Extracted frustum planes for culling

--- Create a new FPS camera
---@param position table|math.vector|nil Initial position {x, y, z} or Vector, defaults to {0, 0, 0}
---@param rotation table|nil Initial rotation {pitch, yaw, roll} in radians, defaults to {0, 0, 0}
---@param fov number|nil Field of view in radians, defaults to 60 degrees
---@param aspect number|nil Aspect ratio, defaults to 16/9
---@param near_z number|nil Near plane distance, defaults to 0.1
---@param far_z number|nil Far plane distance, defaults to 1000
---@return math.camera camera A new camera object
local function Camera_new(position, rotation, fov, aspect, near_z, far_z)
	-- Set defaults
	rotation = rotation or { pitch = 0, yaw = 0, roll = 0 }
	fov = tonumber(fov) or (math_pi / 3) -- 60 degrees
	aspect = tonumber(aspect) or (16 / 9)
	near_z = tonumber(near_z) or 0.1
	far_z = tonumber(far_z) or 1000

	-- Handle position - accept Vector or table
	local pos_vector
	if Vector.is and Vector.is(position) then
		-- Already a Vector
		pos_vector = position
	else
		-- Convert table to Vector
		local pos_x = tonumber(position and (position.x or position[1])) or 0
		local pos_y = tonumber(position and (position.y or position[2])) or 0
		local pos_z = tonumber(position and (position.z or position[3])) or 0
		pos_vector = Vector(pos_x, pos_y, pos_z)
	end

	-- Extract rotation values
	local pitch = tonumber(rotation.pitch or rotation[1]) or 0
	local yaw = tonumber(rotation.yaw or rotation[2]) or 0
	local roll = tonumber(rotation.roll or rotation[3]) or 0

	local camera = setmetatable({
		position = pos_vector,
		rotation = { pitch = pitch, yaw = yaw, roll = roll },
		fov = fov,
		aspect = aspect,
		near_z = near_z,
		far_z = far_z,
		move_speed = 5.0,
		mouse_sensitivity = 0.002,
		view_matrix = Matrix4x4.identity,
		projection_matrix = Matrix4x4.identity,
		view_projection_matrix = Matrix4x4.identity,
		frustum = {}
	}, Camera)

	-- Initialize matrices
	Camera.update_matrices(camera)

	return camera
end

self.new = Camera_new

--- Test whether an object is a Camera (by its metatable)
---@param obj any
---@return boolean
local function iscamera(obj)
	return getmetatable(obj) == Camera
end

self.is = iscamera

Camera.__index = Camera

--- Update view and projection matrices based on current camera state
---@param t math.camera
function Camera.update_matrices(t)
	if not iscamera(t) then
		return error("Camera.update_matrices requires a camera", 2)
	end

	-- Calculate forward vector from rotation
	local pitch, yaw = t.rotation.pitch, t.rotation.yaw
	local forward_x = math_cos(yaw) * math_cos(pitch)
	local forward_y = math_sin(pitch)
	local forward_z = math_sin(yaw) * math_cos(pitch)

	-- Calculate target position using Vector
	local target_vector = Vector(
		t.position[1] + forward_x,
		t.position[2] + forward_y,
		t.position[3] + forward_z
	)

	-- Update view matrix
	t.view_matrix = Matrix4x4.look_at(t.position, target_vector, { x = 0, y = 1, z = 0 })

	-- Update projection matrix
	t.projection_matrix = Matrix4x4.perspective(t.fov, t.aspect, t.near_z, t.far_z)

	-- Update combined view-projection matrix
	t.view_projection_matrix = t.projection_matrix * t.view_matrix

	-- Extract frustum planes for culling
	t.frustum = Matrix4x4.extract_frustum(t.view_projection_matrix)
end

self.update_matrices = Camera.update_matrices

--- Set camera position
---@param t math.camera
---@param position table|math.vector New position {x, y, z} or Vector
function Camera.set_position(t, position)
	if not iscamera(t) then
		return error("Camera.set_position requires a camera", 2)
	end
	if type(position) ~= "table" then
		return error("Camera.set_position requires a position table or Vector", 2)
	end

	-- Handle Vector or table input
	if Vector.is and Vector.is(position) then
		-- Already a Vector
		t.position = position
	else
		-- Convert table to Vector
		local pos_x = tonumber(position.x or position[1]) or 0
		local pos_y = tonumber(position.y or position[2]) or 0
		local pos_z = tonumber(position.z or position[3]) or 0
		t.position = Vector(pos_x, pos_y, pos_z)
	end

	Camera.update_matrices(t)
end

self.set_position = Camera.set_position

--- Set camera rotation
---@param t math.camera
---@param rotation table New rotation {pitch, yaw, roll} in radians
function Camera.set_rotation(t, rotation)
	if not iscamera(t) then
		return error("Camera.set_rotation requires a camera", 2)
	end
	if type(rotation) ~= "table" then
		return error("Camera.set_rotation requires a rotation table", 2)
	end

	t.rotation.pitch = tonumber(rotation.pitch or rotation[1]) or 0
	t.rotation.yaw = tonumber(rotation.yaw or rotation[2]) or 0
	t.rotation.roll = tonumber(rotation.roll or rotation[3]) or 0

	-- Clamp pitch to prevent gimbal lock
	t.rotation.pitch = math_max(-math_pi * 0.5 + 0.01, math_min(math_pi * 0.5 - 0.01, t.rotation.pitch))

	Camera.update_matrices(t)
end

self.set_rotation = Camera.set_rotation

--- Move camera forward/backward
---@param t math.camera
---@param distance number Distance to move (positive = forward, negative = backward)
function Camera.move_forward(t, distance)
	if not iscamera(t) then
		return error("Camera.move_forward requires a camera", 2)
	end
	distance = tonumber(distance) or 0

	local pitch, yaw = t.rotation.pitch, t.rotation.yaw
	local forward_vector = Vector(
		math_cos(yaw) * math_cos(pitch),
		math_sin(pitch),
		math_sin(yaw) * math_cos(pitch)
	)

	-- Update position using Vector operations
	t.position = t.position + forward_vector * distance

	Camera.update_matrices(t)
end

self.move_forward = Camera.move_forward

--- Move camera left/right (strafe)
---@param t math.camera
---@param distance number Distance to move (positive = right, negative = left)
function Camera.move_right(t, distance)
	if not iscamera(t) then
		return error("Camera.move_right requires a camera", 2)
	end
	distance = tonumber(distance) or 0

	local yaw = t.rotation.yaw
	local right_vector = Vector(
		math_cos(yaw + math_pi * 0.5),
		0,
		math_sin(yaw + math_pi * 0.5)
	)

	-- Update position using Vector operations
	t.position = t.position + right_vector * distance

	Camera.update_matrices(t)
end

self.move_right = Camera.move_right

--- Move camera up/down
---@param t math.camera
---@param distance number Distance to move (positive = up, negative = down)
function Camera.move_up(t, distance)
	if not iscamera(t) then
		return error("Camera.move_up requires a camera", 2)
	end
	distance = tonumber(distance) or 0

	-- Update position using Vector operations
	local up_vector = Vector(0, distance, 0)
	t.position = t.position + up_vector

	Camera.update_matrices(t)
end

self.move_up = Camera.move_up

--- Rotate camera by pitch and yaw deltas
---@param t math.camera
---@param delta_pitch number Pitch rotation in radians
---@param delta_yaw number Yaw rotation in radians
function Camera.rotate(t, delta_pitch, delta_yaw)
	if not iscamera(t) then
		return error("Camera.rotate requires a camera", 2)
	end
	delta_pitch = tonumber(delta_pitch) or 0
	delta_yaw = tonumber(delta_yaw) or 0

	t.rotation.pitch = t.rotation.pitch + delta_pitch
	t.rotation.yaw = t.rotation.yaw + delta_yaw

	-- Clamp pitch to prevent gimbal lock
	t.rotation.pitch = math_max(-math_pi * 0.5 + 0.01, math_min(math_pi * 0.5 - 0.01, t.rotation.pitch))

	Camera.update_matrices(t)
end

self.rotate = Camera.rotate

--- Process mouse movement for camera rotation
---@param t math.camera
---@param delta_x number Mouse X movement
---@param delta_y number Mouse Y movement
function Camera.process_mouse(t, delta_x, delta_y)
	if not iscamera(t) then
		return error("Camera.process_mouse requires a camera", 2)
	end
	delta_x = tonumber(delta_x) or 0
	delta_y = tonumber(delta_y) or 0

	local delta_yaw = -delta_x * t.mouse_sensitivity
	local delta_pitch = -delta_y * t.mouse_sensitivity

	Camera.rotate(t, delta_pitch, delta_yaw)
end

self.process_mouse = Camera.process_mouse

--- Process keyboard input for camera movement
---@param t math.camera
---@param forward number Forward/backward input (-1 to 1)
---@param right number Left/right input (-1 to 1)
---@param up number Up/down input (-1 to 1)
---@param delta_time number Time since last frame in seconds
function Camera.process_keyboard(t, forward, right, up, delta_time)
	if not iscamera(t) then
		return error("Camera.process_keyboard requires a camera", 2)
	end
	forward = tonumber(forward) or 0
	right = tonumber(right) or 0
	up = tonumber(up) or 0
	delta_time = tonumber(delta_time) or 0

	local distance = t.move_speed * delta_time

	Camera.move_forward(t, forward * distance)
	Camera.move_right(t, right * distance)
	Camera.move_up(t, up * distance)
end

self.process_keyboard = Camera.process_keyboard

--- Get camera's forward vector
---@param t math.camera
---@return math.vector Forward vector
function Camera.get_forward(t)
	if not iscamera(t) then
		return error("Camera.get_forward requires a camera", 2)
	end

	local pitch, yaw = t.rotation.pitch, t.rotation.yaw
	return Vector(
		math_cos(yaw) * math_cos(pitch),
		math_sin(pitch),
		math_sin(yaw) * math_cos(pitch)
	)
end

self.get_forward = Camera.get_forward

--- Get camera's right vector
---@param t math.camera
---@return math.vector Right vector
function Camera.get_right(t)
	if not iscamera(t) then
		return error("Camera.get_right requires a camera", 2)
	end

	local yaw = t.rotation.yaw
	return Vector(
		math_cos(yaw + math_pi * 0.5),
		0,
		math_sin(yaw + math_pi * 0.5)
	)
end

self.get_right = Camera.get_right

--- Get camera's up vector
---@param t math.camera
---@return math.vector Up vector
function Camera.get_up(t)
	if not iscamera(t) then
		return error("Camera.get_up requires a camera", 2)
	end

	local pitch, yaw = t.rotation.pitch, t.rotation.yaw
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

self.get_up = Camera.get_up

--- Test if a point is visible (inside camera frustum)
---@param t math.camera
---@param point table Point {x, y, z}
---@return boolean
function Camera.is_point_visible(t, point)
	if not iscamera(t) then
		return error("Camera.is_point_visible requires a camera", 2)
	end
	return Matrix4x4.point_in_frustum(point, t.frustum)
end

self.is_point_visible = Camera.is_point_visible

--- Test if an AABB is visible (inside or intersecting camera frustum)
---@param t math.camera
---@param aabb table AABB with min and max vectors
---@return boolean
function Camera.is_aabb_visible(t, aabb)
	if not iscamera(t) then
		return error("Camera.is_aabb_visible requires a camera", 2)
	end
	return Matrix4x4.aabb_in_frustum(aabb, t.frustum)
end

self.is_aabb_visible = Camera.is_aabb_visible

--- Test if a sphere is visible (inside or intersecting camera frustum)
---@param t math.camera
---@param center table Sphere center {x, y, z}
---@param radius number Sphere radius
---@return boolean
function Camera.is_sphere_visible(t, center, radius)
	if not iscamera(t) then
		return error("Camera.is_sphere_visible requires a camera", 2)
	end
	return Matrix4x4.sphere_in_frustum(center, radius, t.frustum)
end

self.is_sphere_visible = Camera.is_sphere_visible

--- Set perspective projection parameters
---@param t math.camera
---@param fov number Field of view in radians
---@param aspect number Aspect ratio
---@param near_z number Near plane distance
---@param far_z number Far plane distance
function Camera.set_perspective(t, fov, aspect, near_z, far_z)
	if not iscamera(t) then
		return error("Camera.set_perspective requires a camera", 2)
	end

	t.fov = tonumber(fov) or t.fov
	t.aspect = tonumber(aspect) or t.aspect
	t.near_z = tonumber(near_z) or t.near_z
	t.far_z = tonumber(far_z) or t.far_z

	Camera.update_matrices(t)
end

self.set_perspective = Camera.set_perspective

--- Create a shallow copy of the camera
---@param t math.camera
---@return math.camera
function Camera.clone(t)
	if not iscamera(t) then
		return error("Camera.clone requires a camera", 2)
	end
	return Camera_new(
		t.position, -- Pass the Vector directly
		{ pitch = t.rotation.pitch, yaw = t.rotation.yaw, roll = t.rotation.roll },
		t.fov, t.aspect, t.near_z, t.far_z
	)
end

self.clone = Camera.clone

--- Readable string representation
function Camera.__tostring(t)
	if not iscamera(t) then
		return tostring(t)
	end
	return string_format("Camera(pos: (%.6g, %.6g, %.6g), rot: (%.6g, %.6g, %.6g), fov: %.6g)",
		t.position[1], t.position[2], t.position[3], -- Use Vector indexing
		t.rotation.pitch, t.rotation.yaw, t.rotation.roll,
		t.fov
	)
end

-- Export
return setmetatable(self, {
	__call = function(_, ...)
		return Camera_new(...)
	end
})
