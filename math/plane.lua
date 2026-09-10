-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Simple object-oriented Plane struct (normal, distance)

-- Features:
-- Fast numeric storage (plane[1] = normal.x, plane[2] = normal.y, plane[3] = normal.z, plane[4] = distance)
-- Convenient field access (plane.normal, plane.distance)
-- Shorthand constructor; Plane(normal, distance) instead of Plane.new(normal, distance)
-- Automatic normalization of normal vector
-- Built-in plane operations and utilities

-- Plane Functions:
-- Plane.from_point_normal(point, normal) - Create from point and normal
-- Plane.from_three_points(a, b, c) - Create from three points
-- Plane.normalize(plane) - Normalize the plane
-- Plane.distance_to_point(plane, point) - Get signed distance to point
-- Plane.project_point(plane, point) - Project point onto plane
-- Plane.intersects_ray(plane, ray) - Test ray intersection
-- Plane.intersects_sphere(plane, sphere) - Test sphere intersection

-- Localized global functions for better performance
local error, getmetatable, rawget, rawset, setmetatable, tonumber, tostring, type =
	error, getmetatable, rawget, rawset, setmetatable, tonumber, tostring, type
local math_abs, math_sqrt =
	math.abs, math.sqrt
local string_format = string.format

-- Import dependencies
local Vector = require "vector"

local self = {}  -- module
local Plane = {} -- method table

---@class math.plane
---@field [1] number Normal X component
---@field [2] number Normal Y component
---@field [3] number Normal Z component
---@field [4] number Distance from origin
---@field normal math.vector Plane normal (field access)
---@field distance number Distance from origin (field access)

--- Create new plane from normal and distance
---@param normal math.vector|{ x: number, y: number, z: number }|{ [1]: number, [2]: number, [3]: number } Plane normal (should be normalized)
---@param distance number Distance from origin along normal
---@return math.plane
local function Plane_new(normal, distance)
	local normal_vec = Vector.is(normal) and normal or Vector(
		tonumber(normal.x or normal[1]) or 0,
		tonumber(normal.y or normal[2]) or 0,
		tonumber(normal.z or normal[3]) or 0
	)

	-- Normalize the normal
	local len = Vector.length(normal_vec)
	if len > 0 then
		normal_vec = normal_vec / len
	else
		normal_vec = Vector(0, 1, 0) -- Default up for degenerate normal
	end

	return setmetatable({
		normal_vec[1], normal_vec[2], normal_vec[3],
		tonumber(distance) or 0
	}, Plane)
end

self.new = Plane_new

--- Test whether an object is a Plane (by its metatable)
---@param obj any
---@return boolean
local function isplane(obj)
	return getmetatable(obj) == Plane
end

self.is = isplane

function Plane.__index(t, k)
	if k == 1 then
		return rawget(t, 1)
	end
	if k == 2 then
		return rawget(t, 2)
	end
	if k == 3 then
		return rawget(t, 3)
	end
	if k == 4 or k == "distance" then
		return rawget(t, 4)
	end
	if k == "normal" then
		return Vector(rawget(t, 1), rawget(t, 2), rawget(t, 3))
	end
	return rawget(Plane, k)
end

function Plane.__newindex(t, k, v)
	if k == 1 then
		rawset(t, 1, tonumber(v) or 0)
	elseif k == 2 then
		rawset(t, 2, tonumber(v) or 0)
	elseif k == 3 then
		rawset(t, 3, tonumber(v) or 0)
	elseif k == 4 or k == "distance" then
		rawset(t, 4, tonumber(v) or 0)
	elseif k == "normal" then
		local normal_vec = Vector.is(v) and v or Vector(
			tonumber(v.x or v[1]) or 0,
			tonumber(v.y or v[2]) or 0,
			tonumber(v.z or v[3]) or 0
		)
		-- Normalize the normal
		local len = Vector.length(normal_vec)
		if len > 0 then
			normal_vec = normal_vec / len
		else
			normal_vec = Vector(0, 1, 0)
		end
		rawset(t, 1, normal_vec[1])
		rawset(t, 2, normal_vec[2])
		rawset(t, 3, normal_vec[3])
	else
		return error("Plane only supports 'normal' and 'distance' field assignment", 2)
	end
end

----------------------------------------------------------------------
-- Plane arithmetic metamethods
----------------------------------------------------------------------

--- Equality check: a == b
function Plane.__eq(a, b)
	if not isplane(a) or not isplane(b) then
		return false
	end
	return a[1] == b[1] and a[2] == b[2] and a[3] == b[3] and a[4] == b[4]
end

--- Readable string representation
function Plane.__tostring(t)
	if not isplane(t) then
		return tostring(t)
	end
	return string_format("Plane(normal: (%.6g, %.6g, %.6g), distance: %.6g)", t[1], t[2], t[3], t[4])
end

----------------------------------------------------------------------
-- Plane utility functions
----------------------------------------------------------------------

--- Create a shallow copy
---@param t math.plane
---@return math.plane
function Plane.clone(t)
	if not isplane(t) then
		return error("Plane.clone requires a plane", 2)
	end
	return Plane_new(t.normal, t[4])
end

self.clone = Plane.clone

--- Create a plane from a point and normal
---@param point math.vector|{ x: number, y: number, z: number }|{ [1]: number, [2]: number, [3]: number } Point on the plane
---@param normal math.vector|{ x: number, y: number, z: number }|{ [1]: number, [2]: number, [3]: number } Plane normal
---@return math.plane
function Plane.from_point_normal(point, normal)
	local point_vec = Vector.is(point) and point or Vector(
		tonumber(point.x or point[1]) or 0,
		tonumber(point.y or point[2]) or 0,
		tonumber(point.z or point[3]) or 0
	)

	local normal_vec = Vector.is(normal) and normal or Vector(
		tonumber(normal.x or normal[1]) or 0,
		tonumber(normal.y or normal[2]) or 0,
		tonumber(normal.z or normal[3]) or 0
	)

	-- Normalize the normal
	local len = Vector.length(normal_vec)
	if len > 0 then
		normal_vec = normal_vec / len
	else
		normal_vec = Vector(0, 1, 0)
	end

	-- Calculate distance: d = -normal · point
	local distance = -Vector.dot(normal_vec, point_vec)

	return Plane_new(normal_vec, distance)
end

self.from_point_normal = Plane.from_point_normal

--- Create a plane from three points
---@param a math.vector|{ x: number, y: number, z: number }|{ [1]: number, [2]: number, [3]: number } First point
---@param b math.vector|{ x: number, y: number, z: number }|{ [1]: number, [2]: number, [3]: number } Second point
---@param c math.vector|{ x: number, y: number, z: number }|{ [1]: number, [2]: number, [3]: number } Third point
---@return math.plane
function Plane.from_three_points(a, b, c)
	local a_vec = Vector.is(a) and a or Vector(
		tonumber(a.x or a[1]) or 0,
		tonumber(a.y or a[2]) or 0,
		tonumber(a.z or a[3]) or 0
	)

	local b_vec = Vector.is(b) and b or Vector(
		tonumber(b.x or b[1]) or 0,
		tonumber(b.y or b[2]) or 0,
		tonumber(b.z or b[3]) or 0
	)

	local c_vec = Vector.is(c) and c or Vector(
		tonumber(c.x or c[1]) or 0,
		tonumber(c.y or c[2]) or 0,
		tonumber(c.z or c[3]) or 0
	)

	-- Calculate normal using cross product
	local edge1 = b_vec - a_vec
	local edge2 = c_vec - a_vec
	local normal = Vector.cross(edge1, edge2)

	-- Normalize the normal
	local len = Vector.length(normal)
	if len > 0 then
		normal = normal / len
	else
		normal = Vector(0, 1, 0)
	end

	-- Calculate distance: d = -normal · a
	local distance = -Vector.dot(normal, a_vec)

	return Plane_new(normal, distance)
end

self.from_three_points = Plane.from_three_points

--- Normalize the plane (ensure normal is unit length)
---@param t math.plane
---@return math.plane
function Plane.normalize(t)
	if not isplane(t) then
		return error("Plane.normalize requires a plane", 2)
	end

	local len = math_sqrt(t[1] * t[1] + t[2] * t[2] + t[3] * t[3])
	if len > 0 then
		return Plane_new(Vector(t[1] / len, t[2] / len, t[3] / len), t[4] / len)
	end
	return Plane_new(Vector(0, 1, 0), 0)
end

self.normalize = Plane.normalize

--- Get signed distance from point to plane
---@param t math.plane
---@param point math.vector|{ x: number, y: number, z: number }|{ [1]: number, [2]: number, [3]: number } Point to test
---@return number dist Signed distance (positive if point is in normal direction)
function Plane.distance_to_point(t, point)
	if not isplane(t) then
		return error("Plane.distance_to_point requires a plane", 2)
	end

	local point_vec = Vector.is(point) and point or Vector(
		tonumber(point.x or point[1]) or 0,
		tonumber(point.y or point[2]) or 0,
		tonumber(point.z or point[3]) or 0
	)

	return t[1] * point_vec[1] + t[2] * point_vec[2] + t[3] * point_vec[3] + t[4]
end

self.distance_to_point = Plane.distance_to_point

--- Project a point onto the plane
---@param t math.plane
---@param point math.vector|{ x: number, y: number, z: number }|{ [1]: number, [2]: number, [3]: number } Point to project
---@return math.vector point Projected point
function Plane.project_point(t, point)
	if not isplane(t) then
		return error("Plane.project_point requires a plane", 2)
	end

	local point_vec = Vector.is(point) and point or Vector(
		tonumber(point.x or point[1]) or 0,
		tonumber(point.y or point[2]) or 0,
		tonumber(point.z or point[3]) or 0
	)

	local distance = t[1] * point_vec[1] + t[2] * point_vec[2] + t[3] * point_vec[3] + t[4]
	return point_vec - Vector(t[1], t[2], t[3]) * distance
end

self.project_point = Plane.project_point

--- Test if ray intersects plane
---@param t math.plane
---@param ray math.collision.ray Ray to test
---@return number? dist Distance to intersection, nil if no intersection
---@return math.vector? point Intersection point, nil if no intersection
function Plane.intersects_ray(t, ray)
	if not isplane(t) or type(ray) ~= "table" then
		return error("Plane.intersects_ray requires a plane and ray", 2)
	end

	local origin = ray.origin
	local dir = ray.direction

	-- Calculate denominator
	local denom = t[1] * dir[1] + t[2] * dir[2] + t[3] * dir[3]

	-- Check if ray is parallel to plane
	if math_abs(denom) < 1e-6 then
		return nil, nil
	end

	-- Calculate intersection distance
	local t_dist = -(t[1] * origin[1] + t[2] * origin[2] + t[3] * origin[3] + t[4]) / denom

	-- Check if intersection is within ray bounds
	if t_dist >= 0 and t_dist <= ray.max_distance then
		return t_dist, origin + dir * t_dist
	end
	return nil, nil
end

self.intersects_ray = Plane.intersects_ray

--- Test if sphere intersects plane
---@param t math.plane
---@param sphere math.collision.sphere Sphere to test
---@return boolean intersecting True if intersecting
---@return number? depth Penetration depth if intersecting
function Plane.intersects_sphere(t, sphere)
	if not isplane(t) or type(sphere) ~= "table" then
		return error("Plane.intersects_sphere requires a plane and sphere", 2)
	end

	local center = sphere.center
	local radius = sphere.radius

	-- Calculate signed distance from sphere center to plane
	local signed_distance = t[1] * center[1] + t[2] * center[2] + t[3] * center[3] + t[4]

	-- Check if sphere intersects plane
	if math_abs(signed_distance) <= radius then
		local penetration = radius - math_abs(signed_distance)
		return true, penetration
	end
	return false
end

self.intersects_sphere = Plane.intersects_sphere

--- Check if point is on plane (within epsilon)
---@param t math.plane
---@param point math.vector|{ x: number, y: number, z: number }|{ [1]: number, [2]: number, [3]: number } Point to test
---@param epsilon? number Tolerance, defaults to 1e-6
---@return boolean test True if point is on plane
function Plane.point_on_plane(t, point, epsilon)
	local distance = Plane.distance_to_point(t, point)
	epsilon = epsilon or 1e-6
	return math_abs(distance) < epsilon
end

self.point_on_plane = Plane.point_on_plane

--- Check if two planes are approximately equal (within epsilon)
---@param a math.plane First plane
---@param b math.plane Second plane
---@param epsilon? number Optional epsilon (default: 1e-6)
---@return boolean
function Plane.is_near(a, b, epsilon)
	if not isplane(a) or not isplane(b) then
		return error("Plane.is_near requires two planes", 2)
	end
	epsilon = epsilon or 1e-6

	return math_abs(a[1] - b[1]) < epsilon and
		math_abs(a[2] - b[2]) < epsilon and
		math_abs(a[3] - b[3]) < epsilon and
		math_abs(a[4] - b[4]) < epsilon
end

self.is_near = Plane.is_near

--- Convert plane to table
---@param t math.plane
---@return {normal: math.vector, distance: number}
function Plane.to_table(t)
	if not isplane(t) then
		return error("Plane.to_table requires a plane", 2)
	end
	return {
		normal = Vector(t[1], t[2], t[3]),
		distance = t[4]
	}
end

self.to_table = Plane.to_table

--- Create plane from table
---@param tbl {normal?: math.vector, distance?: number} Table with normal and distance keys
---@return math.plane
function Plane.from_table(tbl)
	if type(tbl) ~= "table" then
		return error("Plane.from_table requires a table", 2)
	end

	return Plane_new(
		tbl.normal or Vector(0, 1, 0),
		tbl.distance or 0
	)
end

self.from_table = Plane.from_table

-- Export
return setmetatable(self, {
	__call = function(_, ...)
		return Plane_new(...)
	end
})
