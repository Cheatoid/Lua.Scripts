-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Simple object-oriented Oriented Bounding Box (OBB) struct

-- Features:
-- * Fast numeric storage (obb[1] to obb[16]); no hashing, raw lookup
-- * Convenient field access via indexing
-- * Shorthand constructor; OBB(center, half_extents, orientation) instead of OBB.new(...)
-- * Built-in collision detection and utility functions
-- * Support for coordinate system transformations

-- OBB Functions:
-- OBB.from_aabb(aabb, orientation) - Create OBB from AABB and orientation
-- OBB.from_min_max(min, max, orientation) - Create OBB from min/max points
-- OBB.transform(obb, matrix) - Transform OBB by matrix
-- OBB.contains_point(obb, point) - Check if point is inside OBB
-- OBB.get_vertices(obb) - Get all 8 vertices of the OBB
-- OBB.get_faces(obb) - Get all 6 faces of the OBB
-- OBB.get_volume(obb) - Calculate OBB volume
-- OBB.get_surface_area(obb) - Calculate OBB surface area

-- Localized global functions for better performance
local error, getmetatable, rawget, rawset, setmetatable, tonumber, tostring, type =
	error, getmetatable, rawget, rawset, setmetatable, tonumber, tostring, type
local math_abs = math.abs
local string_format = string.format

-- Import dependencies
local AABB = require "aabb"
local Matrix4x4 = require "matrix4x4"
local Vector = require "vector"
local bits = bit32 or bit or require "../standalone/bits"
local bit_band = bits.band

local self = {} -- module
local OBB = {}  -- method table

---@class math.collision.obb
---@field center math.vector OBB center
---@field half_extents math.vector Half-extents along local axes
---@field orientation math.matrix4x4 Rotation matrix (or orientation quaternion)
---@field [1] number Center X
---@field [2] number Center Y
---@field [3] number Center Z
---@field [4] number Half-extent X
---@field [5] number Half-extent Y
---@field [6] number Half-extent Z
---@field [7] number Matrix m11
---@field [8] number Matrix m12
---@field [9] number Matrix m13
---@field [10] number Matrix m14
---@field [11] number Matrix m21
---@field [12] number Matrix m22
---@field [13] number Matrix m23
---@field [14] number Matrix m24
---@field [15] number Matrix m31
---@field [16] number Matrix m32
---@field [17] number Matrix m33
---@field [18] number Matrix m34

--- Create new OBB from center, half extents, and orientation
---@param center math.vector|{ x: number, y: number, z: number }|{ [1]: number, [2]: number, [3]: number } OBB center
---@param half_extents math.vector|{ x: number, y: number, z: number }|{ [1]: number, [2]: number, [3]: number } Half extents along local axes
---@param orientation? math.matrix4x4 Rotation matrix, defaults to identity
---@return math.collision.obb
local function OBB_new(center, half_extents, orientation)
	local center_vec = Vector.is(center) and center or Vector(
		tonumber(center.x or center[1]) or 0,
		tonumber(center.y or center[2]) or 0,
		tonumber(center.z or center[3]) or 0
	)

	local extents_vec = Vector.is(half_extents) and half_extents or Vector(
		tonumber(half_extents.x or half_extents[1]) or 1,
		tonumber(half_extents.y or half_extents[2]) or 1,
		tonumber(half_extents.z or half_extents[3]) or 1
	)

	local orientation_matrix = orientation or Matrix4x4.identity

	local obb = {
		center_vec[1], center_vec[2], center_vec[3], -- center
		extents_vec[1], extents_vec[2], extents_vec[3], -- half_extents
		orientation_matrix[1], orientation_matrix[2], orientation_matrix[3], orientation_matrix[4],
		orientation_matrix[5], orientation_matrix[6], orientation_matrix[7], orientation_matrix[8],
		orientation_matrix[9], orientation_matrix[10], orientation_matrix[11], orientation_matrix[12],
		orientation_matrix[13], orientation_matrix[14], orientation_matrix[15], orientation_matrix[16]
	}

	-- Set metatable with field access
	return setmetatable(obb, OBB)
end

self.new = OBB_new

--- Test whether an object is an OBB (by its metatable)
---@param obj any
---@return boolean
local function isobb(obj)
	return getmetatable(obj) == OBB
end

self.is = isobb

function OBB.__index(t, k)
	-- Center access
	if k == 1 or k == "center" then
		return Vector(t[1], t[2], t[3])
	end

	-- Half extents access
	if k == 2 or k == "half_extents" then
		return Vector(t[4], t[5], t[6])
	end

	-- Orientation access
	if k == 3 or k == "orientation" then
		return Matrix4x4.new(
			t[7], t[8], t[9], t[10],
			t[11], t[12], t[13], t[14],
			t[15], t[16], t[17], t[18]
		)
	end

	return rawget(OBB, k)
end

function OBB.__newindex(t, k, v)
	-- Center assignment
	if k == 1 or k == "center" then
		local center_vec = Vector.is(v) and v or Vector(
			tonumber(v.x or v[1]) or 0,
			tonumber(v.y or v[2]) or 0,
			tonumber(v.z or v[3]) or 0
		)
		rawset(t, 1, center_vec[1])
		rawset(t, 2, center_vec[2])
		rawset(t, 3, center_vec[3])
		return
	end

	-- Half extents assignment
	if k == 2 or k == "half_extents" then
		local extents_vec = Vector.is(v) and v or Vector(
			tonumber(v.x or v[1]) or 1,
			tonumber(v.y or v[2]) or 1,
			tonumber(v.z or v[3]) or 1
		)
		rawset(t, 4, extents_vec[1])
		rawset(t, 5, extents_vec[2])
		rawset(t, 6, extents_vec[3])
		return
	end

	-- Orientation assignment
	if k == 3 or k == "orientation" then
		if Matrix4x4.is(v) then
			rawset(t, 7, v[1])
			rawset(t, 8, v[2])
			rawset(t, 9, v[3])
			rawset(t, 10, v[4])
			rawset(t, 11, v[5])
			rawset(t, 12, v[6])
			rawset(t, 13, v[7])
			rawset(t, 14, v[8])
			rawset(t, 15, v[9])
			rawset(t, 16, v[10])
			rawset(t, 17, v[11])
			rawset(t, 18, v[12])
		else
			return error("OBB orientation must be a Matrix4x4", 2)
		end
		return
	end

	return error("OBB only supports 'center', 'half_extents', and 'orientation' field assignment", 2)
end

--- Readable string representation
function OBB.__tostring(t)
	if not isobb(t) then
		return tostring(t)
	end
	return string_format("OBB(center: (%.6g, %.6g, %.6g), half_extents: (%.6g, %.6g, %.6g))",
		t[1], t[2], t[3], t[4], t[5], t[6])
end

----------------------------------------------------------------------
-- OBB utility functions
----------------------------------------------------------------------

--- Create a shallow copy
---@param t math.collision.obb
---@return math.collision.obb
function OBB.clone(t)
	if not isobb(t) then
		return error("OBB.clone requires an OBB", 2)
	end
	return OBB_new(
		Vector(t[1], t[2], t[3]),
		Vector(t[4], t[5], t[6]),
		Matrix4x4.new(t[7], t[8], t[9], t[10], t[11], t[12], t[13], t[14], t[15], t[16])
	)
end

self.clone = OBB.clone

--- Create OBB from AABB and orientation
---@param aabb math.aabb Axis-aligned bounding box
---@param orientation? math.matrix4x4 Rotation matrix, defaults to identity
---@return math.collision.obb
function OBB.from_aabb(aabb, orientation)
	if not AABB.is(aabb) then
		return error("OBB.from_aabb requires an AABB", 2)
	end

	local center = Vector(
		(aabb.min.x + aabb.max.x) * 0.5,
		(aabb.min.y + aabb.max.y) * 0.5,
		(aabb.min.z + aabb.max.z) * 0.5
	)

	local half_extents = Vector(
		(aabb.max.x - aabb.min.x) * 0.5,
		(aabb.max.y - aabb.min.y) * 0.5,
		(aabb.max.z - aabb.min.z) * 0.5
	)

	return OBB_new(center, half_extents, orientation)
end

self.from_aabb = OBB.from_aabb

--- Create OBB from min/max points and orientation
---@param min_point math.vector Minimum point
---@param max_point math.vector Maximum point
---@param orientation? math.matrix4x4 Rotation matrix, defaults to identity
---@return math.collision.obb
function OBB.from_min_max(min_point, max_point, orientation)
	local min_vec = Vector.is(min_point) and min_point or Vector(
		tonumber(min_point.x or min_point[1]) or 0,
		tonumber(min_point.y or min_point[2]) or 0,
		tonumber(min_point.z or min_point[3]) or 0
	)

	local max_vec = Vector.is(max_point) and max_point or Vector(
		tonumber(max_point.x or max_point[1]) or 0,
		tonumber(max_point.y or max_point[2]) or 0,
		tonumber(max_point.z or max_point[3]) or 0
	)

	local center = (min_vec + max_vec) * 0.5
	local half_extents = (max_vec - min_vec) * 0.5

	return OBB_new(center, half_extents, orientation)
end

self.from_min_max = OBB.from_min_max

--- Transform OBB by matrix
---@param t math.collision.obb
---@param matrix math.matrix4x4 Transformation matrix
---@return math.collision.obb
function OBB.transform(t, matrix)
	if not isobb(t) then
		return error("OBB.transform requires an OBB", 2)
	end
	if not Matrix4x4.is(matrix) then
		return error("OBB.transform requires a Matrix4x4", 2)
	end

	local center = Vector(t[1], t[2], t[3])
	local new_center = Matrix4x4.multiply_vector(matrix, center)
	local new_orientation = matrix * t.orientation

	return OBB_new(new_center, Vector(t[4], t[5], t[6]), new_orientation)
end

self.transform = OBB.transform

--- Check if point is inside OBB
---@param t math.collision.obb
---@param point math.vector Point to test
---@return boolean
function OBB.contains_point(t, point)
	if not isobb(t) then
		return error("OBB.contains_point requires an OBB", 2)
	end

	local point_vec = Vector.is(point) and point or Vector(
		tonumber(point.x or point[1]) or 0,
		tonumber(point.y or point[2]) or 0,
		tonumber(point.z or point[3]) or 0
	)

	-- Transform point to OBB local space
	local center = Vector(t[1], t[2], t[3])
	local orientation_matrix = Matrix4x4.new(t[7], t[8], t[9], t[10], t[11], t[12], t[13], t[14], t[15], t[16])
	local local_point = Matrix4x4.multiply_vector(Matrix4x4.inverse(orientation_matrix), point_vec - center)

	-- Check if point is within half extents
	return math_abs(local_point[1]) <= t[4] and
		math_abs(local_point[2]) <= t[5] and
		math_abs(local_point[3]) <= t[6]
end

self.contains_point = OBB.contains_point

--- Get all 8 vertices of the OBB
---@param t math.collision.obb
---@return table array Array of 8 Vector vertices
function OBB.get_vertices(t)
	if not isobb(t) then
		return error("OBB.get_vertices requires an OBB", 2)
	end

	local center = Vector(t[1], t[2], t[3])
	local half_extents = Vector(t[4], t[5], t[6])
	local orientation = Matrix4x4.new(t[7], t[8], t[9], t[10], t[11], t[12], t[13], t[14], t[15], t[16])

	-- Local space corners (LuaJIT/Lua 5.1 compatible via Bits.band)
	local corners = {}
	for i = 0, 7 do
		local x = bit_band(i, 1) == 0 and -half_extents[1] or half_extents[1]
		local y = bit_band(i, 2) == 0 and -half_extents[2] or half_extents[2]
		local z = bit_band(i, 4) == 0 and -half_extents[3] or half_extents[3]
		corners[i + 1] = Vector(x, y, z)
	end

	-- Transform corners to world space
	local vertices = {}
	for i = 1, 8 do
		local world_corner = Matrix4x4.multiply_vector(orientation, corners[i]) + center
		vertices[i] = Vector(world_corner[1], world_corner[2], world_corner[3])
	end

	return vertices
end

self.get_vertices = OBB.get_vertices

--- Get volume of OBB
---@param t math.collision.obb
---@return number
function OBB.get_volume(t)
	if not isobb(t) then
		return error("OBB.get_volume requires an OBB", 2)
	end

	return t[4] * t[5] * t[6] * 8 -- 2 * x * 2 * y * 2 * z = 8 * x * y * z
end

self.get_volume = OBB.get_volume

--- Get surface area of OBB
---@param t math.collision.obb
---@return number
function OBB.get_surface_area(t)
	if not isobb(t) then
		return error("OBB.get_surface_area requires an OBB", 2)
	end

	local x, y, z = t[4], t[5], t[6]
	return 8 * (x * y + y * z + z * x)
end

self.get_surface_area = OBB.get_surface_area

--- Convert OBB to table
---@param t math.collision.obb
---@return table {center, half_extents, orientation}
function OBB.to_table(t)
	if not isobb(t) then
		return error("OBB.to_table requires an OBB", 2)
	end

	return {
		center = Vector(t[1], t[2], t[3]),
		half_extents = Vector(t[4], t[5], t[6]),
		orientation = Matrix4x4.new(t[7], t[8], t[9], t[10], t[11], t[12], t[13], t[14], t[15], t[16])
	}
end

self.to_table = OBB.to_table

--- Create OBB from table
---@param tbl table Table with center, half_extents, orientation keys
---@return math.collision.obb
function OBB.from_table(tbl)
	if type(tbl) ~= "table" then
		return error("OBB.from_table requires a table", 2)
	end

	return OBB_new(
		tbl.center or Vector(0, 0, 0),
		tbl.half_extents or Vector(1, 1, 1),
		tbl.orientation
	)
end

self.from_table = OBB.from_table

-- Export
return setmetatable(self, {
	__call = function(_, ...)
		return OBB_new(...)
	end
})
