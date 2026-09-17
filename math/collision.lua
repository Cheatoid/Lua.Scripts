-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Comprehensive collision detection utilities for 3D space
-- Built on top of the existing math library (Vector, Matrix4x4, AABB, etc.)

-- Features:
-- Ray casting and intersection tests
-- Line segment intersection tests (finite rays)
-- 2D line segment intersection (parametric / Cramer's rule, XY plane)
-- Sphere collision detection
-- Plane collision utilities
-- Oriented Bounding Box (OBB) collision detection
-- Triangle collision detection
-- Spatial partitioning helpers
-- Distance queries and closest point calculations

-- Collision Functions:
-- Ray vs AABB, Sphere, Plane, Triangle, OBB, Point, Ray, Segment
-- Line vs AABB, Sphere, Plane, Triangle, OBB, Point, Line, Ray
-- Segment vs Segment (2D), Line vs Line (2D), Ray vs Segment (2D)
-- Segment vs Circle/AABB/OBB (2D)
-- Sphere vs AABB, Sphere, Plane, Triangle, OBB, Point, Ray, Line
-- AABB vs AABB, Sphere, Plane, Triangle, OBB, Point, Ray, Line
-- Plane vs Point, Ray, Sphere, AABB, Triangle, OBB, Plane
-- Triangle vs Point, Ray, Line, Sphere, AABB, Triangle, OBB, Plane
-- OBB vs Point, Ray, Line, Sphere, AABB, Triangle, OBB, Plane
-- Point vs Point, AABB, Sphere, Triangle, OBB
-- Distance: Point to AABB, Sphere, Plane, Line, Segment, Ray, OBB, Triangle
-- Closest point on AABB, OBB, Plane, Sphere, Ray, Segment, Triangle

-- Localized global functions for better performance.
local error, setmetatable, tonumber, type =
	error, setmetatable, tonumber, type
local math_abs, math_ceil, math_floor, math_max, math_min, math_sqrt =
	math.abs, math.ceil, math.floor, math.max, math.min, math.sqrt
local string_format = string.format

-- Import dependencies
local Vector = require "vector"
local Matrix4x4 = require "matrix4x4"
local AABB = require "aabb"
local OBB = require "obb"

local self = {}      -- module
local Collision = {} -- method table

---@class math.collision.ray
---@field origin math.vector Ray origin point
---@field direction math.vector Ray direction (should be normalized)
---@field max_distance number Maximum ray distance, defaults to infinity

---@class math.collision.line
---@field start math.vector Line start point
---@field finish math.vector Line end point (`finish` is used instead of `end` which is a Lua keyword)
---@field direction math.vector Line direction (normalized)
---@field length number Line length (distance from start to finish)

---@class math.collision.sphere
---@field center math.vector Sphere center
---@field radius number Sphere radius

---@class math.collision.plane
---@field normal math.vector Plane normal (should be normalized)
---@field distance number Distance from origin along normal

---@class math.collision.triangle
---@field a math.vector First vertex
---@field b math.vector Second vertex
---@field c math.vector Third vertex

----------------------------------------------------------------------
-- Shared Local Helpers (not exported)
----------------------------------------------------------------------

-- Convert a point-like table to a Vector without mutating the input.
local function to_vec(p)
	if Vector.is(p) then
		return p
	end
	return Vector(
		tonumber(p.x or p[1]) or 0,
		tonumber(p.y or p[2]) or 0,
		tonumber(p.z or p[3]) or 0
	)
end

-- Project a triangle onto an axis, returns min/max scalar projections.
local function project_triangle_onto_axis(triangle, axis)
	local d1 = Vector.dot(triangle.a, axis)
	local d2 = Vector.dot(triangle.b, axis)
	local d3 = Vector.dot(triangle.c, axis)
	return math_min(d1, math_min(d2, d3)), math_max(d1, math_max(d2, d3))
end

-- Project an AABB onto an arbitrary axis, returns min/max scalars.
-- NOTE: AABB min/max are plain {x, y, z} tables (not Vectors).
local function project_aabb_onto_axis(aabb, axis)
	local cx = (aabb.min.x + aabb.max.x) * 0.5
	local cy = (aabb.min.y + aabb.max.y) * 0.5
	local cz = (aabb.min.z + aabb.max.z) * 0.5
	local hx = (aabb.max.x - aabb.min.x) * 0.5
	local hy = (aabb.max.y - aabb.min.y) * 0.5
	local hz = (aabb.max.z - aabb.min.z) * 0.5
	local center_proj = cx * axis[1] + cy * axis[2] + cz * axis[3]
	local radius = math_abs(axis[1]) * hx
		+ math_abs(axis[2]) * hy
		+ math_abs(axis[3]) * hz
	return center_proj - radius, center_proj + radius
end

-- World-space axes of an OBB as three Vectors.
local function obb_axes(obb)
	local c1 = Matrix4x4.get_column(obb.orientation, 1)
	local c2 = Matrix4x4.get_column(obb.orientation, 2)
	local c3 = Matrix4x4.get_column(obb.orientation, 3)
	return Vector(c1[1], c1[2], c1[3]),
		Vector(c2[1], c2[2], c2[3]),
		Vector(c3[1], c3[2], c3[3])
end

----------------------------------------------------------------------
-- Ray Collision Functions
----------------------------------------------------------------------

--- Create a new ray
---@param origin math.vector|{ x: number, y: number, z: number }|{ [1]: number, [2]: number, [3]: number } Ray origin {x, y, z}
---@param direction math.vector|{ x: number, y: number, z: number }|{ [1]: number, [2]: number, [3]: number } Ray direction {x, y, z}
---@param max_distance? number Maximum distance (default: `math.huge`)
---@return math.collision.ray
local function Ray_new(origin, direction, max_distance)
	-- Convert origin to Vector if needed
	local origin_vec = Vector.is(origin) and origin or Vector(
		tonumber(origin.x or origin[1]) or 0,
		tonumber(origin.y or origin[2]) or 0,
		tonumber(origin.z or origin[3]) or 0
	)

	-- Convert direction to Vector if needed
	local dir_vec = Vector.is(direction) and direction or Vector(
		tonumber(direction.x or direction[1]) or 0,
		tonumber(direction.y or direction[2]) or 0,
		tonumber(direction.z or direction[3]) or 0
	)

	-- Normalize direction
	local dir_length = Vector.length(dir_vec)
	if dir_length > 0 then
		dir_vec = dir_vec / dir_length
	end

	return {
		origin = origin_vec,
		direction = dir_vec,
		max_distance = max_distance or math.huge
	}
end

self.ray = Ray_new

--- Test ray vs AABB intersection
---@param ray math.collision.ray
---@param aabb math.aabb
---@return number? dist Distance to intersection, nil if no intersection
---@return math.vector? intersection Intersection point, nil if no intersection
function Collision.ray_vs_aabb(ray, aabb)
	if type(ray) ~= "table" or not AABB.is(aabb) then
		return error("Collision.ray_vs_aabb requires a ray and AABB", 2)
	end

	local origin = ray.origin
	local dir = ray.direction
	local min_dist = 0
	local max_dist = ray.max_distance

	-- X axis
	local dir_component = dir[1]
	local origin_component = origin[1]
	if math_abs(dir_component) < 1e-6 then
		if origin_component < aabb.min.x or origin_component > aabb.max.x then
			return nil, nil
		end
	else
		local t1 = (aabb.min.x - origin_component) / dir_component
		local t2 = (aabb.max.x - origin_component) / dir_component
		if t1 > t2 then t1, t2 = t2, t1 end
		min_dist = math_max(min_dist, t1)
		max_dist = math_min(max_dist, t2)
		if min_dist > max_dist or max_dist < 0 then return nil, nil end
	end

	-- Y axis
	dir_component = dir[2]
	origin_component = origin[2]
	if math_abs(dir_component) < 1e-6 then
		if origin_component < aabb.min.y or origin_component > aabb.max.y then
			return nil, nil
		end
	else
		local t1 = (aabb.min.y - origin_component) / dir_component
		local t2 = (aabb.max.y - origin_component) / dir_component
		if t1 > t2 then t1, t2 = t2, t1 end
		min_dist = math_max(min_dist, t1)
		max_dist = math_min(max_dist, t2)
		if min_dist > max_dist or max_dist < 0 then return nil, nil end
	end

	-- Z axis
	dir_component = dir[3]
	origin_component = origin[3]
	if math_abs(dir_component) < 1e-6 then
		if origin_component < aabb.min.z or origin_component > aabb.max.z then
			return nil, nil
		end
	else
		local t1 = (aabb.min.z - origin_component) / dir_component
		local t2 = (aabb.max.z - origin_component) / dir_component
		if t1 > t2 then t1, t2 = t2, t1 end
		min_dist = math_max(min_dist, t1)
		max_dist = math_min(max_dist, t2)
		if min_dist > max_dist or max_dist < 0 then return nil, nil end
	end

	-- Return the closest positive intersection
	if min_dist >= 0 then
		return min_dist, origin + dir * min_dist
	end
	if max_dist >= 0 then
		return 0, origin
	end
	return nil, nil
end

self.ray_vs_aabb = Collision.ray_vs_aabb

--- Test ray vs sphere intersection
---@param ray math.collision.ray
---@param sphere math.collision.sphere
---@return number? distance Distance to intersection, nil if no intersection
---@return math.vector? intersection Intersection point, nil if no intersection
function Collision.ray_vs_sphere(ray, sphere)
	if type(ray) ~= "table" or type(sphere) ~= "table" then
		return error("Collision.ray_vs_sphere requires a ray and sphere", 2)
	end

	local origin = ray.origin
	local dir = ray.direction
	local center = sphere.center
	local radius = sphere.radius

	-- Vector from ray origin to sphere center
	local oc = origin - center

	-- Quadratic formula coefficients
	local a = Vector.dot(dir, dir)
	local b = 2.0 * Vector.dot(oc, dir)
	local c = Vector.dot(oc, oc) - radius * radius

	-- Calculate discriminant
	local discriminant = b * b - 4 * a * c

	if discriminant < 0 then
		return nil, nil -- No intersection
	end

	local sqrt_discriminant = math_sqrt(discriminant)

	-- Calculate both intersection distances
	local t1 = (-b - sqrt_discriminant) / (2 * a)
	local t2 = (-b + sqrt_discriminant) / (2 * a)

	-- Find the closest positive intersection within max distance
	local closest_t

	if t1 >= 0 and t1 <= ray.max_distance then
		closest_t = t1
	elseif t2 >= 0 and t2 <= ray.max_distance then
		closest_t = t2
	end

	if closest_t then
		return closest_t, origin + dir * closest_t
	end
	return nil, nil
end

self.ray_vs_sphere = Collision.ray_vs_sphere

--- Create a plane from normal and distance
---@param normal math.vector|{ x: number, y: number, z: number }|{ [1]: number, [2]: number, [3]: number } Plane normal (should be normalized)
---@param distance? number Distance from origin along normal (default: 0)
---@return math.collision.plane
local function Plane_new(normal, distance)
	local normal_vec = Vector.is(normal) and normal or Vector(
		tonumber(normal.x or normal[1]) or 0,
		tonumber(normal.y or normal[2]) or 0,
		tonumber(normal.z or normal[3]) or 0
	)

	-- Normalize the normal
	local normal_length = Vector.length(normal_vec)
	if normal_length > 0 then
		normal_vec = normal_vec / normal_length
	end

	return {
		normal = normal_vec,
		distance = tonumber(distance) or 0
	}
end

self.plane = Plane_new

--- Create a plane from point and normal
---@param point math.vector|{ x: number, y: number, z: number }|{ [1]: number, [2]: number, [3]: number } Point on the plane
---@param normal math.vector|{ x: number, y: number, z: number }|{ [1]: number, [2]: number, [3]: number } Plane normal
---@return math.collision.plane
function Collision.plane_from_point_normal(point, normal)
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
	local normal_length = Vector.length(normal_vec)
	if normal_length > 0 then
		normal_vec = normal_vec / normal_length
	end

	-- Calculate distance: d = -normal · point
	local distance = -Vector.dot(normal_vec, point_vec)

	return Plane_new(normal_vec, distance)
end

self.plane_from_point_normal = Collision.plane_from_point_normal

--- Test ray vs plane intersection
---@param ray math.collision.ray
---@param plane math.collision.plane
---@return number? distance Distance to intersection, nil if no intersection
---@return math.vector? intersection Intersection point, nil if no intersection
function Collision.ray_vs_plane(ray, plane)
	if type(ray) ~= "table" or type(plane) ~= "table" then
		return error("Collision.ray_vs_plane requires a ray and plane", 2)
	end

	local origin = ray.origin
	local dir = ray.direction
	local normal = plane.normal
	local distance = plane.distance

	-- Calculate denominator
	local denom = Vector.dot(normal, dir)

	-- Check if ray is parallel to plane
	if math_abs(denom) < 1e-6 then
		return nil, nil
	end

	-- Calculate intersection distance
	local t = -(Vector.dot(normal, origin) + distance) / denom

	-- Check if intersection is within ray bounds
	if t >= 0 and t <= ray.max_distance then
		return t, origin + dir * t
	end
	return nil, nil
end

self.ray_vs_plane = Collision.ray_vs_plane

--- Create a triangle from three vertices
---@param a math.vector|{ x: number, y: number, z: number }|{ [1]: number, [2]: number, [3]: number } First vertex
---@param b math.vector|{ x: number, y: number, z: number }|{ [1]: number, [2]: number, [3]: number } Second vertex
---@param c math.vector|{ x: number, y: number, z: number }|{ [1]: number, [2]: number, [3]: number } Third vertex
---@return math.collision.triangle
local function Triangle_new(a, b, c)
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

	return {
		a = a_vec,
		b = b_vec,
		c = c_vec
	}
end

self.triangle = Triangle_new

--- Test ray vs triangle intersection using Möller-Trumbore algorithm
---@param ray math.collision.ray
---@param triangle math.collision.triangle
---@return number? dist Distance to intersection, nil if no intersection
---@return math.vector? point Intersection point, nil if no intersection
function Collision.ray_vs_triangle(ray, triangle)
	if type(ray) ~= "table" or type(triangle) ~= "table" then
		return error("Collision.ray_vs_triangle requires a ray and triangle", 2)
	end

	local origin = ray.origin
	local dir = ray.direction
	local a = triangle.a
	local b = triangle.b
	local c = triangle.c

	-- Calculate edges
	local edge1 = b - a
	local edge2 = c - a

	-- Calculate determinant
	local h = Vector.cross(dir, edge2)
	local det = Vector.dot(edge1, h)

	-- Check if ray is parallel to triangle
	if math_abs(det) < 1e-6 then
		return nil, nil
	end

	local inv_det = 1.0 / det

	-- Calculate distance from vertex 0 to ray origin
	local s = origin - a
	local u = inv_det * Vector.dot(s, h)

	-- Check if intersection is outside triangle
	if u < 0 or u > 1 then
		return nil, nil
	end

	-- Prepare to test V parameter
	local q = Vector.cross(s, edge1)
	local v = inv_det * Vector.dot(dir, q)

	-- Check if intersection is outside triangle
	if v < 0 or u + v > 1 then
		return nil, nil
	end

	-- Calculate intersection distance
	local t = inv_det * Vector.dot(edge2, q)

	-- Check if intersection is within ray bounds
	if t > 1e-6 and t <= ray.max_distance then
		return t, origin + dir * t
	end
	return nil, nil
end

self.ray_vs_triangle = Collision.ray_vs_triangle

--- Test ray vs OBB intersection
---@param ray math.collision.ray
---@param obb math.collision.obb
---@return number? distance Distance to intersection, nil if no intersection
---@return math.vector? intersection Intersection point, nil if no intersection
function Collision.ray_vs_obb(ray, obb)
	if type(ray) ~= "table" or not OBB.is(obb) then
		return error("Collision.ray_vs_obb requires a ray and OBB", 2)
	end

	local origin = ray.origin
	local dir = ray.direction
	local center = obb.center
	local half_extents = obb.half_extents
	local orientation = obb.orientation

	-- Transform ray to OBB local space
	local inv_orientation = Matrix4x4.inverse(orientation)
	local local_origin_table = Matrix4x4.multiply_vector(inv_orientation, origin - center)
	local local_dir_table = Matrix4x4.multiply_vector(inv_orientation, dir)
	local local_origin = Vector(local_origin_table[1], local_origin_table[2], local_origin_table[3])
	local local_dir = Vector(local_dir_table[1], local_dir_table[2], local_dir_table[3])

	-- Perform slab intersection in local space (treat OBB as AABB)
	local t_min = 0
	local t_max = ray.max_distance

	-- Check each axis
	for i = 1, 3 do
		local axis_component = local_dir[i]
		local origin_component = local_origin[i]
		local half_extent = half_extents[i]

		if math_abs(axis_component) < 1e-6 then
			-- Ray is parallel to this slab
			if origin_component < -half_extent or origin_component > half_extent then
				return nil, nil -- Ray misses OBB
			end
		else
			-- Calculate intersection times with slab
			local t1 = (-half_extent - origin_component) / axis_component
			local t2 = (half_extent - origin_component) / axis_component

			if t1 > t2 then t1, t2 = t2, t1 end
			t_min = math_max(t_min, t1)
			t_max = math_min(t_max, t2)

			if t_min > t_max or t_max < 0 then
				return nil, nil -- No intersection
			end
		end
	end

	-- Find closest intersection
	if t_min >= 0 then
		local local_hit = local_origin + local_dir * t_min
		-- Transform hit point back to world space
		local world_hit_table = Matrix4x4.multiply_vector(orientation, local_hit)
		local world_hit = Vector(world_hit_table[1], world_hit_table[2], world_hit_table[3]) + center
		return t_min, world_hit
	end
	if t_max >= 0 then
		local local_hit = local_origin + local_dir * t_max
		-- Transform hit point back to world space
		local world_hit_table = Matrix4x4.multiply_vector(orientation, local_hit)
		local world_hit = Vector(world_hit_table[1], world_hit_table[2], world_hit_table[3]) + center
		return 0, world_hit
	end
	return nil, nil
end

self.ray_vs_obb = Collision.ray_vs_obb

--- Test ray vs point (checks if point is on the ray within tolerance)
---@param ray math.collision.ray
---@param point math.vector|{ x: number, y: number, z: number }|{ [1]: number, [2]: number, [3]: number } Point to test
---@param epsilon? number Tolerance (default: 1e-6)
---@return number? dist Distance from ray origin to closest point, nil if point is not on the ray
---@return math.vector? point Closest point on the ray, nil if point is not on the ray
function Collision.ray_vs_point(ray, point, epsilon)
	if type(ray) ~= "table" or type(point) ~= "table" then
		return error("Collision.ray_vs_point requires a ray and point", 2)
	end

	local point_vec = to_vec(point)
	epsilon = epsilon == nil and 1e-6 or tonumber(epsilon) or 1e-6

	local w = point_vec - ray.origin
	local t = Vector.dot(w, ray.direction)
	if t < 0 or t > ray.max_distance then
		return nil, nil
	end

	local closest = ray.origin + ray.direction * t
	if Vector.distance(point_vec, closest) <= epsilon then
		return t, closest
	end
	return nil, nil
end

self.ray_vs_point = Collision.ray_vs_point

--- Find the closest points between two rays
---@param ray1 math.collision.ray
---@param ray2 math.collision.ray
---@return number dist Distance between the rays
---@return math.vector point1 Closest point on the first ray
---@return math.vector point2 Closest point on the second ray
function Collision.ray_vs_ray(ray1, ray2)
	if type(ray1) ~= "table" or type(ray2) ~= "table" then
		return error("Collision.ray_vs_ray requires two rays", 2)
	end

	local max1 = ray1.max_distance or math.huge
	local max2 = ray2.max_distance or math.huge
	local p1 = ray1.origin
	local d1 = ray1.direction
	local p2 = ray2.origin
	local d2 = ray2.direction
	local r = p1 - p2

	local a = Vector.dot(d1, d1)
	local e = Vector.dot(d2, d2)
	local f = Vector.dot(d2, r)
	local c = Vector.dot(d1, r)
	local b = Vector.dot(d1, d2)
	local eps = 1e-9

	if a <= eps and e <= eps then
		return Vector.distance(p1, p2), p1, p2
	end

	if a <= eps then
		local t = math_max(0, math_min(max2, f / e))
		local c2 = p2 + d2 * t
		return Vector.distance(p1, c2), p1, c2
	end

	if e <= eps then
		local s = math_max(0, math_min(max1, -c / a))
		local c1 = p1 + d1 * s
		return Vector.distance(c1, p2), c1, p2
	end

	local denom = a * e - b * b
	local s = denom > eps and (b * f - c * e) / denom or 0
	s = math_max(0, math_min(max1, s))
	local t = (b * s + f) / e

	if t < 0 then
		t = 0
		s = math_max(0, math_min(max1, -c / a))
	elseif t > max2 then
		t = max2
		s = math_max(0, math_min(max1, (b * t - c) / a))
	end

	local c1 = p1 + d1 * s
	local c2 = p2 + d2 * t
	return Vector.distance(c1, c2), c1, c2
end

self.ray_vs_ray = Collision.ray_vs_ray

--- Find the closest points between a ray and a 3D segment given as two points
---@param ray math.collision.ray
---@param a math.vector|{ x: number, y: number, z: number }|{ [1]: number, [2]: number, [3]: number } Segment start
---@param b math.vector|{ x: number, y: number, z: number }|{ [1]: number, [2]: number, [3]: number } Segment finish
---@return number dist Distance between the ray and the segment
---@return math.vector ray_point Closest point on the ray
---@return math.vector seg_point Closest point on the segment
function Collision.ray_vs_segment(ray, a, b)
	if type(ray) ~= "table" or type(a) ~= "table" or type(b) ~= "table" then
		return error("Collision.ray_vs_segment requires a ray and two points", 2)
	end

	local a_vec = to_vec(a)
	local b_vec = to_vec(b)
	local delta = b_vec - a_vec
	local seg_len = Vector.length(delta)
	local seg_dir = seg_len > 0 and (delta / seg_len) or Vector(0, 0, 0)
	local seg = { start = a_vec, finish = b_vec, direction = seg_dir, length = seg_len }
	local dist, seg_point, ray_point = Collision.line_vs_ray(seg, ray)
	return dist, ray_point, seg_point
end

self.ray_vs_segment = Collision.ray_vs_segment

----------------------------------------------------------------------
-- Line Collision Functions
----------------------------------------------------------------------

-- A line is a finite ray: a segment from `start` to `finish`.
-- `finish` is used instead of `end` because `end` is a Lua keyword
-- and cannot be used as a field name (`t.end` is a syntax error).
-- All `line_vs_*` shape tests convert the line to a limited ray
-- (`origin = start`, `max_distance = length`) and reuse `ray_vs_*`.

--- Create a new line segment from start to finish
---@param start math.vector|{ x: number, y: number, z: number }|{ [1]: number, [2]: number, [3]: number } Line start {x, y, z}
---@param finish math.vector|{ x: number, y: number, z: number }|{ [1]: number, [2]: number, [3]: number } Line end {x, y, z}
---@return math.collision.line line New line segment
local function Line_new(start, finish)
	local start_vec = Vector.is(start) and start or Vector(
		tonumber(start.x or start[1]) or 0,
		tonumber(start.y or start[2]) or 0,
		tonumber(start.z or start[3]) or 0
	)

	local finish_vec = Vector.is(finish) and finish or Vector(
		tonumber(finish.x or finish[1]) or 0,
		tonumber(finish.y or finish[2]) or 0,
		tonumber(finish.z or finish[3]) or 0
	)

	local delta = finish_vec - start_vec
	local length = Vector.length(delta)
	local direction = length > 0 and (delta / length) or Vector(0, 0, 0)

	return {
		start = start_vec,
		finish = finish_vec,
		direction = direction,
		length = length
	}
end

self.line = Line_new

--- Test whether a value is a line segment
---@param value any Value to test
---@return boolean is_line True if value looks like a line
function Collision.is_line(value)
	return type(value) == "table"
		and Vector.is(value.start)
		and Vector.is(value.finish)
		and Vector.is(value.direction)
		and type(value.length) == "number"
end

self.is_line = Collision.is_line

--- Test whether a value is a ray
---@param value any Value to test
---@return boolean is_ray True if value looks like a ray
function Collision.is_ray(value)
	return type(value) == "table"
		and type(value.origin) == "table"
		and type(value.direction) == "table"
		and type(value.max_distance) == "number"
end

self.is_ray = Collision.is_ray

--- Test whether a value is a sphere
---@param value any Value to test
---@return boolean is_sphere True if value looks like a sphere
function Collision.is_sphere(value)
	return type(value) == "table"
		and type(value.center) == "table"
		and type(value.radius) == "number"
end

self.is_sphere = Collision.is_sphere

--- Test whether a value is a triangle
---@param value any Value to test
---@return boolean is_triangle True if value looks like a triangle
function Collision.is_triangle(value)
	return type(value) == "table"
		and type(value.a) == "table"
		and type(value.b) == "table"
		and type(value.c) == "table"
end

self.is_triangle = Collision.is_triangle

--- Test whether a value is a plane
---@param value any Value to test
---@return boolean is_plane True if value looks like a plane
function Collision.is_plane(value)
	return type(value) == "table"
		and type(value.normal) == "table"
		and type(value.distance) == "number"
end

self.is_plane = Collision.is_plane

--- Test whether a value is an AABB
---@param value any Value to test
---@return boolean is_aabb True if value is an AABB
function Collision.is_aabb(value)
	return AABB.is(value)
end

self.is_aabb = Collision.is_aabb

--- Test whether a value is an OBB
---@param value any Value to test
---@return boolean is_obb True if value is an OBB
function Collision.is_obb(value)
	return OBB.is(value)
end

self.is_obb = Collision.is_obb

--- Convert a line segment to a limited ray
---@param line math.collision.line
---@return math.collision.ray ray Ray with origin at start and max_distance set to line length
function Collision.line_to_ray(line)
	if not Collision.is_line(line) then
		return error("Collision.line_to_ray requires a line", 2)
	end

	return {
		origin = line.start,
		direction = line.direction,
		max_distance = line.length
	}
end

self.line_to_ray = Collision.line_to_ray

--- Create a line segment from a ray and a length
---@param ray math.collision.ray
---@param length? number Line length, defaults to ray max_distance (must be finite)
---@return math.collision.line line New line segment
function Collision.line_from_ray(ray, length)
	if type(ray) ~= "table" or type(ray.origin) ~= "table" or type(ray.direction) ~= "table" then
		return error("Collision.line_from_ray requires a ray", 2)
	end

	local line_length = tonumber(length) or ray.max_distance
	if not line_length or line_length == math.huge then
		return error("Collision.line_from_ray requires a finite length", 2)
	end

	local origin_vec = Vector.is(ray.origin) and ray.origin or Vector(
		tonumber(ray.origin.x or ray.origin[1]) or 0,
		tonumber(ray.origin.y or ray.origin[2]) or 0,
		tonumber(ray.origin.z or ray.origin[3]) or 0
	)

	local dir_vec = Vector.is(ray.direction) and ray.direction or Vector(
		tonumber(ray.direction.x or ray.direction[1]) or 0,
		tonumber(ray.direction.y or ray.direction[2]) or 0,
		tonumber(ray.direction.z or ray.direction[3]) or 0
	)

	return Line_new(origin_vec, origin_vec + dir_vec * line_length)
end

self.line_from_ray = Collision.line_from_ray

--- Get the length of a line segment
---@param line math.collision.line
---@return number length Line length
function Collision.line_length(line)
	if not Collision.is_line(line) then
		return error("Collision.line_length requires a line", 2)
	end

	return line.length
end

self.line_length = Collision.line_length

--- Get a point at a distance along a line from its start
---@param line math.collision.line
---@param distance? number Distance from start, clamped to [0, length] (default: 0)
---@return math.vector point Point on the line
function Collision.line_point_at(line, distance)
	if not Collision.is_line(line) then
		return error("Collision.line_point_at requires a line", 2)
	end

	distance = tonumber(distance) or 0
	distance = math_max(0, math_min(line.length, distance))

	return line.start + line.direction * distance
end

self.line_point_at = Collision.line_point_at

--- Find the closest point on a line segment to a given point
---@param line math.collision.line
---@param point math.vector|{ x: number, y: number, z: number }|{ [1]: number, [2]: number, [3]: number } Point to test
---@return math.vector point Closest point on the line
function Collision.line_closest_point(line, point)
	if not Collision.is_line(line) or type(point) ~= "table" then
		return error("Collision.line_closest_point requires a line and point", 2)
	end

	local point_vec = Vector.is(point) and point or Vector(
		tonumber(point.x or point[1]) or 0,
		tonumber(point.y or point[2]) or 0,
		tonumber(point.z or point[3]) or 0
	)

	return Collision.closest_point_on_segment(point_vec, line.start, line.finish)
end

self.line_closest_point = Collision.line_closest_point

--- Get distance between a point and a line segment
---@param point math.vector|{ x: number, y: number, z: number }|{ [1]: number, [2]: number, [3]: number } Point
---@param line math.collision.line
---@return number dist Distance
---@return math.vector point Closest point on the line
function Collision.distance_point_to_line(point, line)
	if type(point) ~= "table" or not Collision.is_line(line) then
		return error("Collision.distance_point_to_line requires a point and line", 2)
	end

	local point_vec = Vector.is(point) and point or Vector(
		tonumber(point.x or point[1]) or 0,
		tonumber(point.y or point[2]) or 0,
		tonumber(point.z or point[3]) or 0
	)

	local closest = Collision.closest_point_on_segment(point_vec, line.start, line.finish)
	return Vector.distance(point_vec, closest), closest
end

self.distance_point_to_line = Collision.distance_point_to_line

--- Test line vs AABB intersection
---@param line math.collision.line
---@param aabb math.aabb
---@return number? dist Distance from line start to intersection, nil if no intersection
---@return math.vector? intersection Intersection point, nil if no intersection
function Collision.line_vs_aabb(line, aabb)
	if not Collision.is_line(line) or not AABB.is(aabb) then
		return error("Collision.line_vs_aabb requires a line and AABB", 2)
	end

	-- Degenerate line behaves as a point
	if line.length < 1e-9 then
		if AABB.contains_point(aabb, line.start) then
			return 0, line.start
		end
		return nil, nil
	end

	return Collision.ray_vs_aabb({
		origin = line.start,
		direction = line.direction,
		max_distance = line.length
	}, aabb)
end

self.line_vs_aabb = Collision.line_vs_aabb

--- Test line vs sphere intersection
---@param line math.collision.line
---@param sphere math.collision.sphere
---@return number? dist Distance from line start to intersection, nil if no intersection
---@return math.vector? intersection Intersection point, nil if no intersection
function Collision.line_vs_sphere(line, sphere)
	if not Collision.is_line(line) or type(sphere) ~= "table" then
		return error("Collision.line_vs_sphere requires a line and sphere", 2)
	end

	-- Degenerate line behaves as a point
	if line.length < 1e-9 then
		if Vector.distance(line.start, sphere.center) <= sphere.radius then
			return 0, line.start
		end
		return nil, nil
	end

	return Collision.ray_vs_sphere({
		origin = line.start,
		direction = line.direction,
		max_distance = line.length
	}, sphere)
end

self.line_vs_sphere = Collision.line_vs_sphere

--- Test line vs plane intersection
---@param line math.collision.line
---@param plane math.collision.plane
---@return number? dist Distance from line start to intersection, nil if no intersection
---@return math.vector? intersection Intersection point, nil if no intersection
function Collision.line_vs_plane(line, plane)
	if not Collision.is_line(line) or type(plane) ~= "table" then
		return error("Collision.line_vs_plane requires a line and plane", 2)
	end

	-- Degenerate line behaves as a point
	if line.length < 1e-9 then
		if math_abs(Collision.point_vs_plane(line.start, plane)) < 1e-6 then
			return 0, line.start
		end
		return nil, nil
	end

	return Collision.ray_vs_plane({
		origin = line.start,
		direction = line.direction,
		max_distance = line.length
	}, plane)
end

self.line_vs_plane = Collision.line_vs_plane

--- Test line vs triangle intersection
---@param line math.collision.line
---@param triangle math.collision.triangle
---@return number? dist Distance from line start to intersection, nil if no intersection
---@return math.vector? point Intersection point, nil if no intersection
function Collision.line_vs_triangle(line, triangle)
	if not Collision.is_line(line) or type(triangle) ~= "table" then
		return error("Collision.line_vs_triangle requires a line and triangle", 2)
	end

	-- Degenerate line behaves as a point
	if line.length < 1e-9 then
		local closest = Collision.closest_point_on_triangle(line.start, triangle)
		if Vector.distance(line.start, closest) < 1e-6 then
			return 0, line.start
		end
		return nil, nil
	end

	return Collision.ray_vs_triangle({
		origin = line.start,
		direction = line.direction,
		max_distance = line.length
	}, triangle)
end

self.line_vs_triangle = Collision.line_vs_triangle

--- Test line vs OBB intersection
---@param line math.collision.line
---@param obb math.collision.obb
---@return number? dist Distance from line start to intersection, nil if no intersection
---@return math.vector? intersection Intersection point, nil if no intersection
function Collision.line_vs_obb(line, obb)
	if not Collision.is_line(line) or not OBB.is(obb) then
		return error("Collision.line_vs_obb requires a line and OBB", 2)
	end

	-- Degenerate line behaves as a point
	if line.length < 1e-9 then
		if Collision.obb_vs_point(obb, line.start) then
			return 0, line.start
		end
		return nil, nil
	end

	return Collision.ray_vs_obb({
		origin = line.start,
		direction = line.direction,
		max_distance = line.length
	}, obb)
end

self.line_vs_obb = Collision.line_vs_obb

--- Test line vs point (checks if point is on the line within tolerance)
---@param line math.collision.line
---@param point math.vector|{ x: number, y: number, z: number }|{ [1]: number, [2]: number, [3]: number } Point to test
---@param epsilon? number Tolerance (default: 1e-6)
---@return number? dist Distance from line start to closest point, nil if point is not on the line
---@return math.vector? point Closest point on the line, nil if point is not on the line
function Collision.line_vs_point(line, point, epsilon)
	if not Collision.is_line(line) or type(point) ~= "table" then
		return error("Collision.line_vs_point requires a line and point", 2)
	end

	local point_vec = Vector.is(point) and point or Vector(
		tonumber(point.x or point[1]) or 0,
		tonumber(point.y or point[2]) or 0,
		tonumber(point.z or point[3]) or 0
	)

	epsilon = epsilon == nil and 1e-6 or tonumber(epsilon) or 1e-6

	local closest = Collision.closest_point_on_segment(point_vec, line.start, line.finish)
	if Vector.distance(point_vec, closest) <= epsilon then
		return Vector.distance(line.start, closest), closest
	end
	return nil, nil
end

self.line_vs_point = Collision.line_vs_point

--- Find the closest points between two line segments
---@param line1 math.collision.line
---@param line2 math.collision.line
---@return number dist Distance between the lines
---@return math.vector point1 Closest point on the first line
---@return math.vector point2 Closest point on the second line
function Collision.line_vs_line(line1, line2)
	if not Collision.is_line(line1) or not Collision.is_line(line2) then
		return error("Collision.line_vs_line requires two lines", 2)
	end

	local p1 = line1.start
	local p2 = line2.start
	local d1 = line1.finish - line1.start
	local d2 = line2.finish - line2.start
	local r = p1 - p2

	local a = Vector.dot(d1, d1)
	local e = Vector.dot(d2, d2)
	local f = Vector.dot(d2, r)
	local eps = 1e-9

	-- Both lines are degenerate points
	if a <= eps and e <= eps then
		return Vector.distance(p1, p2), p1, p2
	end

	-- First line is a point
	if a <= eps then
		local t = math_max(0, math_min(1, f / e))
		local c2 = p2 + d2 * t
		return Vector.distance(p1, c2), p1, c2
	end

	-- Second line is a point
	if e <= eps then
		local c = Vector.dot(d1, r)
		local s = math_max(0, math_min(1, -c / a))
		local c1 = p1 + d1 * s
		return Vector.distance(c1, p2), c1, p2
	end

	local c = Vector.dot(d1, r)
	local b = Vector.dot(d1, d2)
	local denom = a * e - b * b

	local s = denom > eps and math_max(0, math_min(1, (b * f - c * e) / denom)) or 0
	local t = (b * s + f) / e

	if t < 0 then
		t = 0
		s = math_max(0, math_min(1, -c / a))
	elseif t > 1 then
		t = 1
		s = math_max(0, math_min(1, (b - c) / a))
	end

	local c1 = p1 + d1 * s
	local c2 = p2 + d2 * t
	return Vector.distance(c1, c2), c1, c2
end

self.line_vs_line = Collision.line_vs_line

--- Find the closest points between a line segment and a ray
---@param line math.collision.line
---@param ray math.collision.ray
---@return number dist Distance between the line and the ray
---@return math.vector line_point Closest point on the line
---@return math.vector ray_point Closest point on the ray
function Collision.line_vs_ray(line, ray)
	if not Collision.is_line(line) or type(ray) ~= "table" or type(ray.origin) ~= "table" or type(ray.direction) ~= "table" then
		return error("Collision.line_vs_ray requires a line and ray", 2)
	end

	local max_t = ray.max_distance or math.huge
	local p1 = line.start
	local d1 = line.finish - line.start
	local p2 = ray.origin
	local d2 = ray.direction
	local r = p1 - p2

	local a = Vector.dot(d1, d1)
	local e = Vector.dot(d2, d2)
	local f = Vector.dot(d2, r)
	local c = Vector.dot(d1, r)
	local b = Vector.dot(d1, d2)
	local eps = 1e-9

	-- Degenerate line behaves as a point vs ray
	if a <= eps then
		local t = e > eps and f / e or 0
		t = math_max(0, math_min(max_t, t))
		local c2 = p2 + d2 * t
		return Vector.distance(p1, c2), p1, c2
	end

	-- Degenerate ray direction behaves as a point vs line
	if e <= eps then
		local closest = Collision.closest_point_on_segment(p2, line.start, line.finish)
		return Vector.distance(closest, p2), closest, p2
	end

	local denom = a * e - b * b
	local s = denom > eps and math_max(0, math_min(1, (b * f - c * e) / denom)) or 0
	local t = (b * s + f) / e

	if t < 0 then
		t = 0
		s = math_max(0, math_min(1, -c / a))
	elseif t > max_t then
		t = max_t
		s = math_max(0, math_min(1, (b * t - c) / a))
	end

	local c1 = p1 + d1 * s
	local c2 = p2 + d2 * t
	return Vector.distance(c1, c2), c1, c2
end

self.line_vs_ray = Collision.line_vs_ray

--- Find the closest points between a ray and a line segment
---@param ray math.collision.ray
---@param line math.collision.line
---@return number dist Distance between the ray and the line
---@return math.vector ray_point Closest point on the ray
---@return math.vector line_point Closest point on the line
function Collision.ray_vs_line(ray, line)
	if type(ray) ~= "table" or not Collision.is_line(line) then
		return error("Collision.ray_vs_line requires a ray and line", 2)
	end

	local dist, line_point, ray_point = Collision.line_vs_ray(line, ray)
	return dist, ray_point, line_point
end

self.ray_vs_line = Collision.ray_vs_line

----------------------------------------------------------------------
-- 2D Segment Intersection Functions
----------------------------------------------------------------------

-- 2D segments are tested in the XY plane with the parametric /
-- Cramer's rule method: the shared denominator is the cross product
-- of the two direction vectors.
-- Endpoint touches count as hits (`ua`/`ub` of 0 or 1).
-- Parallel and collinear segments return nil (infinitely many points, no single answer).

--- Test two 2D line segments for intersection (parametric / Cramer's rule).<br>
--- Endpoint touches count as hits.<br>
--- Parallel and collinear segments return nil.
---@param x1 number First segment start X
---@param y1 number First segment start Y
---@param x2 number First segment finish X
---@param y2 number First segment finish Y
---@param x3 number Second segment start X
---@param y3 number Second segment start Y
---@param x4 number Second segment finish X
---@param y4 number Second segment finish Y
---@param eps? number Parallel tolerance (default: 1e-9, pass 0 for exact arithmetic)
---@return number? x Intersection X, nil if segments miss or are parallel
---@return number? y Intersection Y, nil if segments miss or are parallel
---@return number? ua Parametric position on first segment, nil if no hit
---@return number? ub Parametric position on second segment, nil if no hit
function Collision.segment_intersection_2d(x1, y1, x2, y2, x3, y3, x4, y4, eps)
	x1 = tonumber(x1)
	y1 = tonumber(y1)
	x2 = tonumber(x2)
	y2 = tonumber(y2)
	x3 = tonumber(x3)
	y3 = tonumber(y3)
	x4 = tonumber(x4)
	y4 = tonumber(y4)
	if not x1 or not y1 or not x2 or not y2 or not x3 or not y3 or not x4 or not y4 then
		return error("Collision.segment_intersection_2d requires eight numbers", 2)
	end

	eps = eps and tonumber(eps) or 1e-9

	-- Shared denominator: cross product of the two direction vectors.
	-- |denom| ~ 0 means the segments are parallel (or collinear).
	-- The explicit denom == 0 check keeps eps = 0 exact, since 0 is truthy in Lua
	-- and math_abs(denom) < 0 is never true.
	local denom = (y4 - y3) * (x2 - x1) - (x4 - x3) * (y2 - y1)
	if denom == 0 or math_abs(denom) < eps then
		return nil
	end

	local ua = ((x4 - x3) * (y1 - y3) - (y4 - y3) * (x1 - x3)) / denom
	local ub = ((x2 - x1) * (y1 - y3) - (y2 - y1) * (x1 - x3)) / denom

	-- 0 <= ua <= 1 and 0 <= ub <= 1 means the segments actually touch.
	if ua >= -eps and ua <= 1 + eps and ub >= -eps and ub <= 1 + eps then
		return x1 + ua * (x2 - x1),
			y1 + ua * (y2 - y1),
			ua, ub
	end

	-- Infinite lines cross, but outside one or both segments.
	return nil
end

self.segment_intersection_2d = Collision.segment_intersection_2d

--- Test two 2D line segments given as points for intersection.<br>
--- Only the XY components are used.<br>
--- Endpoint touches count as hits.
---@param a math.vector|{ x: number, y: number }|{ [1]: number, [2]: number } First segment start, XY used
---@param b math.vector|{ x: number, y: number }|{ [1]: number, [2]: number } First segment finish, XY used
---@param c math.vector|{ x: number, y: number }|{ [1]: number, [2]: number } Second segment start, XY used
---@param d math.vector|{ x: number, y: number }|{ [1]: number, [2]: number } Second segment finish, XY used
---@param eps? number Parallel tolerance (default: 1e-9, pass 0 for exact arithmetic)
---@return math.vector? point Intersection point with Z set to 0, nil if no hit
---@return number? ua Parametric position on first segment, nil if no hit
---@return number? ub Parametric position on second segment, nil if no hit
function Collision.segment_vs_segment_2d(a, b, c, d, eps)
	if type(a) ~= "table" or type(b) ~= "table" or type(c) ~= "table" or type(d) ~= "table" then
		return error("Collision.segment_vs_segment_2d requires four points", 2)
	end

	local x1 = tonumber(a.x or a[1]) or 0
	local y1 = tonumber(a.y or a[2]) or 0
	local x2 = tonumber(b.x or b[1]) or 0
	local y2 = tonumber(b.y or b[2]) or 0
	local x3 = tonumber(c.x or c[1]) or 0
	local y3 = tonumber(c.y or c[2]) or 0
	local x4 = tonumber(d.x or d[1]) or 0
	local y4 = tonumber(d.y or d[2]) or 0

	local x, y, ua, ub = Collision.segment_intersection_2d(x1, y1, x2, y2, x3, y3, x4, y4, eps)
	if x then
		return Vector(x, y, 0), ua, ub
	end
	return nil
end

self.segment_vs_segment_2d = Collision.segment_vs_segment_2d

--- Test two line segments (3D lines projected to XY) for 2D intersection.<br>
--- Only the XY components of start and finish are used.<br>
--- Endpoint touches count as hits.
---@param line1 math.collision.line First line segment
---@param line2 math.collision.line Second line segment
---@param eps? number Parallel tolerance (default: 1e-9, pass 0 for exact arithmetic)
---@return math.vector? point Intersection point with Z set to 0, nil if no hit
---@return number? ua Parametric position on first line, nil if no hit
---@return number? ub Parametric position on second line, nil if no hit
function Collision.line_vs_line_2d(line1, line2, eps)
	if not Collision.is_line(line1) or not Collision.is_line(line2) then
		return error("Collision.line_vs_line_2d requires two lines", 2)
	end

	local x, y, ua, ub = Collision.segment_intersection_2d(
		line1.start[1], line1.start[2], line1.finish[1], line1.finish[2],
		line2.start[1], line2.start[2], line2.finish[1], line2.finish[2],
		eps
	)
	if x then
		return Vector(x, y, 0), ua, ub
	end
	return nil
end

self.line_vs_line_2d = Collision.line_vs_line_2d

--- Test a 2D ray against a 2D segment in the XY plane
---@param ray math.collision.ray Ray, only XY used
---@param a math.vector|{ x: number, y: number }|{ [1]: number, [2]: number } Segment start, XY used
---@param b math.vector|{ x: number, y: number }|{ [1]: number, [2]: number } Segment finish, XY used
---@param eps? number Parallel tolerance (default: 1e-9)
---@return number? dist Distance from ray origin, nil if no hit
---@return math.vector? point Hit point with Z set to 0, nil if no hit
function Collision.ray_vs_segment_2d(ray, a, b, eps)
	if type(ray) ~= "table" or type(a) ~= "table" or type(b) ~= "table" then
		return error("Collision.ray_vs_segment_2d requires a ray and two points", 2)
	end

	eps = eps and tonumber(eps) or 1e-9
	local ox = tonumber(ray.origin.x or ray.origin[1]) or 0
	local oy = tonumber(ray.origin.y or ray.origin[2]) or 0
	local dx = tonumber(ray.direction.x or ray.direction[1]) or 0
	local dy = tonumber(ray.direction.y or ray.direction[2]) or 0
	local x1 = tonumber(a.x or a[1]) or 0
	local y1 = tonumber(a.y or a[2]) or 0
	local x2 = tonumber(b.x or b[1]) or 0
	local y2 = tonumber(b.y or b[2]) or 0

	local sx = x2 - x1
	local sy = y2 - y1
	local denom = dx * sy - dy * sx
	if denom == 0 or math_abs(denom) < eps then
		return nil
	end

	local qx = x1 - ox
	local qy = y1 - oy
	local t = (qx * sy - qy * sx) / denom
	local s = (qx * dy - qy * dx) / denom
	local max_dist = ray.max_distance or math.huge

	if t >= 0 and t <= max_dist and s >= -eps and s <= 1 + eps then
		return t, Vector(ox + dx * t, oy + dy * t, 0)
	end
	return nil
end

self.ray_vs_segment_2d = Collision.ray_vs_segment_2d

--- Test a 2D segment against a circle in the XY plane
---@param a math.vector|{ x: number, y: number }|{ [1]: number, [2]: number } Segment start, XY used
---@param b math.vector|{ x: number, y: number }|{ [1]: number, [2]: number } Segment finish, XY used
---@param circle math.collision.sphere Circle, only XY and radius used
---@return number? dist Distance from segment start to entry, nil if no hit
---@return math.vector? point Entry point with Z set to 0, nil if no hit
function Collision.segment_vs_circle_2d(a, b, circle)
	if type(a) ~= "table" or type(b) ~= "table" or type(circle) ~= "table" then
		return error("Collision.segment_vs_circle_2d requires two points and a circle", 2)
	end

	local x1 = tonumber(a.x or a[1]) or 0
	local y1 = tonumber(a.y or a[2]) or 0
	local x2 = tonumber(b.x or b[1]) or 0
	local y2 = tonumber(b.y or b[2]) or 0
	local cx = tonumber(circle.center.x or circle.center[1]) or 0
	local cy = tonumber(circle.center.y or circle.center[2]) or 0
	local r = tonumber(circle.radius) or 0

	local dx = x2 - x1
	local dy = y2 - y1
	local len_sq = dx * dx + dy * dy
	if len_sq < 1e-12 then
		local dist_sq = (x1 - cx) * (x1 - cx) + (y1 - cy) * (y1 - cy)
		if dist_sq <= r * r then
			return 0, Vector(x1, y1, 0)
		end
		return nil
	end

	local len = math_sqrt(len_sq)
	local nx = dx / len
	local ny = dy / len
	local vx = cx - x1
	local vy = cy - y1
	local tp = vx * nx + vy * ny
	local v_sq = vx * vx + vy * vy
	local d_sq = v_sq - tp * tp
	local r_sq = r * r
	if d_sq > r_sq then
		return nil
	end

	local tc = math_sqrt(math_max(0, r_sq - d_sq))
	local t1 = tp - tc
	local t2 = tp + tc
	local t
	if t1 >= 0 and t1 <= len then
		t = t1
	elseif t2 >= 0 and t2 <= len then
		t = t2
	elseif tp >= 0 and tp <= len and v_sq <= r_sq then
		t = 0
	else
		return nil
	end

	return t, Vector(x1 + nx * t, y1 + ny * t, 0)
end

self.segment_vs_circle_2d = Collision.segment_vs_circle_2d

--- Test a 2D segment against an AABB in the XY plane
---@param a math.vector|{ x: number, y: number }|{ [1]: number, [2]: number } Segment start, XY used
---@param b math.vector|{ x: number, y: number }|{ [1]: number, [2]: number } Segment finish, XY used
---@param aabb math.aabb Box, only XY bounds used
---@return number? dist Distance from segment start to entry, nil if no hit
---@return math.vector? point Entry point with Z set to 0, nil if no hit
function Collision.segment_vs_aabb_2d(a, b, aabb)
	if type(a) ~= "table" or type(b) ~= "table" or not AABB.is(aabb) then
		return error("Collision.segment_vs_aabb_2d requires two points and an AABB", 2)
	end

	local x1 = tonumber(a.x or a[1]) or 0
	local y1 = tonumber(a.y or a[2]) or 0
	local x2 = tonumber(b.x or b[1]) or 0
	local y2 = tonumber(b.y or b[2]) or 0
	local dx = x2 - x1
	local dy = y2 - y1
	local len = math_sqrt(dx * dx + dy * dy)
	if len < 1e-12 then
		if x1 >= aabb.min.x and x1 <= aabb.max.x and y1 >= aabb.min.y and y1 <= aabb.max.y then
			return 0, Vector(x1, y1, 0)
		end
		return nil
	end

	local nx = dx / len
	local ny = dy / len
	local tmin = 0
	local tmax = len

	if math_abs(nx) < 1e-9 then
		if x1 < aabb.min.x or x1 > aabb.max.x then
			return nil
		end
	else
		local inv = 1 / nx
		local ta = (aabb.min.x - x1) * inv
		local tb = (aabb.max.x - x1) * inv
		if ta > tb then ta, tb = tb, ta end
		tmin = math_max(tmin, ta)
		tmax = math_min(tmax, tb)
		if tmin > tmax then
			return nil
		end
	end

	if math_abs(ny) < 1e-9 then
		if y1 < aabb.min.y or y1 > aabb.max.y then
			return nil
		end
	else
		local inv = 1 / ny
		local ta = (aabb.min.y - y1) * inv
		local tb = (aabb.max.y - y1) * inv
		if ta > tb then ta, tb = tb, ta end
		tmin = math_max(tmin, ta)
		tmax = math_min(tmax, tb)
		if tmin > tmax then
			return nil
		end
	end

	return tmin, Vector(x1 + nx * tmin, y1 + ny * tmin, 0)
end

self.segment_vs_aabb_2d = Collision.segment_vs_aabb_2d

--- Test a 2D segment against a 2D OBB in the XY plane
---@param a math.vector|{ x: number, y: number }|{ [1]: number, [2]: number } Segment start, XY used
---@param b math.vector|{ x: number, y: number }|{ [1]: number, [2]: number } Segment finish, XY used
---@param center math.vector|{ x: number, y: number }|{ [1]: number, [2]: number } Box center, XY used
---@param half_extents math.vector|{ x: number, y: number }|{ [1]: number, [2]: number } Half extents, XY used
---@param angle? number Rotation in radians (default: 0)
---@return number? dist Distance from segment start to entry, nil if no hit
---@return math.vector? point Entry point with Z set to 0, nil if no hit
function Collision.segment_vs_obb_2d(a, b, center, half_extents, angle)
	if type(a) ~= "table" or type(b) ~= "table" or type(center) ~= "table" or type(half_extents) ~= "table" then
		return error("Collision.segment_vs_obb_2d requires two points, a center, and half extents", 2)
	end

	angle = tonumber(angle) or 0
	local x1 = tonumber(a.x or a[1]) or 0
	local y1 = tonumber(a.y or a[2]) or 0
	local x2 = tonumber(b.x or b[1]) or 0
	local y2 = tonumber(b.y or b[2]) or 0
	local cx = tonumber(center.x or center[1]) or 0
	local cy = tonumber(center.y or center[2]) or 0
	local hx = tonumber(half_extents.x or half_extents[1]) or 0
	local hy = tonumber(half_extents.y or half_extents[2]) or 0

	local cos_a = math.cos(-angle)
	local sin_a = math.sin(-angle)
	local lx1 = (x1 - cx) * cos_a - (y1 - cy) * sin_a
	local ly1 = (x1 - cx) * sin_a + (y1 - cy) * cos_a
	local lx2 = (x2 - cx) * cos_a - (y2 - cy) * sin_a
	local ly2 = (x2 - cx) * sin_a + (y2 - cy) * cos_a

	local dx = lx2 - lx1
	local dy = ly2 - ly1
	local len = math_sqrt(dx * dx + dy * dy)
	if len < 1e-12 then
		if math_abs(lx1) <= hx and math_abs(ly1) <= hy then
			return 0, Vector(x1, y1, 0)
		end
		return nil
	end

	local nx = dx / len
	local ny = dy / len
	local tmin = 0
	local tmax = len

	if math_abs(nx) < 1e-9 then
		if lx1 < -hx or lx1 > hx then
			return nil
		end
	else
		local inv = 1 / nx
		local ta = (-hx - lx1) * inv
		local tb = (hx - lx1) * inv
		if ta > tb then ta, tb = tb, ta end
		tmin = math_max(tmin, ta)
		tmax = math_min(tmax, tb)
		if tmin > tmax then
			return nil
		end
	end

	if math_abs(ny) < 1e-9 then
		if ly1 < -hy or ly1 > hy then
			return nil
		end
	else
		local inv = 1 / ny
		local ta = (-hy - ly1) * inv
		local tb = (hy - ly1) * inv
		if ta > tb then ta, tb = tb, ta end
		tmin = math_max(tmin, ta)
		tmax = math_min(tmax, tb)
		if tmin > tmax then
			return nil
		end
	end

	local hit_lx = lx1 + nx * tmin
	local hit_ly = ly1 + ny * tmin
	local cos_w = math.cos(angle)
	local sin_w = math.sin(angle)
	return tmin, Vector(cx + hit_lx * cos_w - hit_ly * sin_w, cy + hit_lx * sin_w + hit_ly * cos_w, 0)
end

self.segment_vs_obb_2d = Collision.segment_vs_obb_2d

----------------------------------------------------------------------
-- Sphere Collision Functions
----------------------------------------------------------------------

--- Create a sphere
---@param center math.vector|{ x: number, y: number, z: number }|{ [1]: number, [2]: number, [3]: number } Sphere center
---@param radius? number Sphere radius (default: 1)
---@return math.collision.sphere
local function Sphere_new(center, radius)
	local center_vec = Vector.is(center) and center or Vector(
		tonumber(center.x or center[1]) or 0,
		tonumber(center.y or center[2]) or 0,
		tonumber(center.z or center[3]) or 0
	)

	return {
		center = center_vec,
		radius = tonumber(radius) or 1
	}
end

self.sphere = Sphere_new

--- Test sphere vs sphere intersection
---@param sphere1 math.collision.sphere
---@param sphere2 math.collision.sphere
---@return boolean intersecting True if intersecting
---@return number? depth Penetration depth if intersecting
---@return math.vector? separation Separation direction if intersecting
function Collision.sphere_vs_sphere(sphere1, sphere2)
	if type(sphere1) ~= "table" or type(sphere2) ~= "table" then
		return error("Collision.sphere_vs_sphere requires two spheres", 2)
	end

	local center1 = sphere1.center
	local center2 = sphere2.center
	local radius1 = sphere1.radius
	local radius2 = sphere2.radius

	-- Calculate distance between centers
	local diff = center2 - center1
	local distance = Vector.length(diff)
	local combined_radius = radius1 + radius2

	if distance <= combined_radius then
		-- Calculate penetration depth and separation direction
		local penetration = combined_radius - distance
		local separation = distance > 0 and (diff / distance) or Vector(1, 0, 0)
		return true, penetration, separation
	end
	return false
end

self.sphere_vs_sphere = Collision.sphere_vs_sphere

--- Test sphere vs AABB intersection
---@param sphere math.collision.sphere
---@param aabb math.aabb
---@return boolean intersecting True if intersecting
---@return number? depth Penetration depth if intersecting
---@return math.vector? separation Separation direction if intersecting
function Collision.sphere_vs_aabb(sphere, aabb)
	if type(sphere) ~= "table" or not AABB.is(aabb) then
		return error("Collision.sphere_vs_aabb requires a sphere and AABB", 2)
	end

	local center = sphere.center
	local radius = sphere.radius

	-- Find closest point on AABB to sphere center
	local closest = Vector(
		math_max(aabb.min.x, math_min(center[1], aabb.max.x)),
		math_max(aabb.min.y, math_min(center[2], aabb.max.y)),
		math_max(aabb.min.z, math_min(center[3], aabb.max.z))
	)

	-- Calculate distance from sphere center to closest point
	local diff = center - closest
	local distance = Vector.length(diff)

	if distance <= radius then
		-- Calculate penetration depth and separation direction
		local penetration = radius - distance
		local separation = distance > 0 and (diff / distance) or Vector(1, 0, 0)
		return true, penetration, separation
	end
	return false
end

self.sphere_vs_aabb = Collision.sphere_vs_aabb

--- Test sphere vs plane intersection
---@param sphere math.collision.sphere
---@param plane math.collision.plane
---@return boolean intersecting True if intersecting
---@return number? depth Penetration depth if intersecting
function Collision.sphere_vs_plane(sphere, plane)
	if type(sphere) ~= "table" or type(plane) ~= "table" then
		return error("Collision.sphere_vs_plane requires a sphere and plane", 2)
	end

	local center = sphere.center
	local radius = sphere.radius
	local normal = plane.normal
	local distance = plane.distance

	-- Calculate signed distance from sphere center to plane
	local signed_distance = Vector.dot(normal, center) + distance

	-- Check if sphere intersects plane
	if math_abs(signed_distance) <= radius then
		local penetration = radius - math_abs(signed_distance)
		return true, penetration
	end
	return false
end

self.sphere_vs_plane = Collision.sphere_vs_plane

--- Test sphere vs triangle intersection
---@param sphere math.collision.sphere
---@param triangle math.collision.triangle
---@return boolean intersecting True if intersecting
---@return number? depth Penetration depth if intersecting
---@return math.vector? separation Separation direction if intersecting
function Collision.sphere_vs_triangle(sphere, triangle)
	if type(sphere) ~= "table" or type(triangle) ~= "table" then
		return error("Collision.sphere_vs_triangle requires a sphere and triangle", 2)
	end

	local center = sphere.center
	local radius = sphere.radius
	local a = triangle.a
	local b = triangle.b
	local c = triangle.c

	-- Calculate triangle normal
	local edge1 = b - a
	local edge2 = c - a
	local normal = Vector.cross(edge1, edge2)
	local normal_length = Vector.length(normal)

	if normal_length == 0 then
		return false -- Degenerate triangle
	end

	normal = normal / normal_length

	-- Calculate distance from sphere center to triangle plane
	local plane_distance = Vector.dot(normal, center - a)

	-- Check if sphere is too far from triangle plane
	if math_abs(plane_distance) > radius then
		return false
	end

	-- Project sphere center onto triangle plane
	local projected_center = center - normal * plane_distance

	-- Check if projected point is inside triangle using barycentric coordinates
	local v0 = c - a
	local v1 = b - a
	local v2 = projected_center - a

	local dot00 = Vector.dot(v0, v0)
	local dot01 = Vector.dot(v0, v1)
	local dot02 = Vector.dot(v0, v2)
	local dot11 = Vector.dot(v1, v1)
	local dot12 = Vector.dot(v1, v2)

	local inv_denom = 1 / (dot00 * dot11 - dot01 * dot01)
	local u = (dot11 * dot02 - dot01 * dot12) * inv_denom
	local v = (dot00 * dot12 - dot01 * dot02) * inv_denom

	if u >= 0 and v >= 0 and u + v <= 1 then
		-- Sphere center projects inside triangle
		local penetration = radius - math_abs(plane_distance)
		local separation = plane_distance >= 0 and normal or -normal
		return true, penetration, separation
	end

	-- Need to check distance to triangle edges
	local closest_point = Collision.closest_point_on_triangle(projected_center, triangle)
	local diff = center - closest_point
	local distance = Vector.length(diff)

	if distance <= radius then
		local penetration = radius - distance
		local separation = distance > 0 and (diff / distance) or Vector(1, 0, 0)
		return true, penetration, separation
	end
	return false
end

self.sphere_vs_triangle = Collision.sphere_vs_triangle

--- Test sphere vs OBB intersection
---@param sphere math.collision.sphere
---@param obb math.collision.obb
---@return boolean intersecting True if intersecting
---@return number? depth Penetration depth if intersecting
---@return math.vector? separation Separation direction in world space if intersecting
function Collision.sphere_vs_obb(sphere, obb)
	if type(sphere) ~= "table" or not OBB.is(obb) then
		return error("Collision.sphere_vs_obb requires a sphere and OBB", 2)
	end

	local center = sphere.center
	local radius = sphere.radius
	local obb_center = obb.center
	local half = obb.half_extents

	local inv = Matrix4x4.inverse(obb.orientation)
	local local_center_t = Matrix4x4.multiply_vector(inv, center - obb_center)
	local local_center = Vector(local_center_t[1], local_center_t[2], local_center_t[3])

	local local_closest = Vector(
		math_max(-half[1], math_min(local_center[1], half[1])),
		math_max(-half[2], math_min(local_center[2], half[2])),
		math_max(-half[3], math_min(local_center[3], half[3]))
	)

	local diff = local_center - local_closest
	local distance = Vector.length(diff)

	if distance <= radius then
		local penetration = radius - distance
		local local_sep = distance > 1e-9 and (diff / distance) or Vector(1, 0, 0)
		local world_sep_t = Matrix4x4.multiply_vector(obb.orientation, local_sep)
		local world_sep = Vector(world_sep_t[1], world_sep_t[2], world_sep_t[3])
		return true, penetration, world_sep
	end
	return false
end

self.sphere_vs_obb = Collision.sphere_vs_obb

--- Test sphere vs point intersection
---@param sphere math.collision.sphere
---@param point math.vector|{ x: number, y: number, z: number }|{ [1]: number, [2]: number, [3]: number } Point to test
---@return boolean intersecting True if point is inside or on the sphere
---@return number? depth Penetration depth if intersecting
---@return math.vector? separation Separation direction from center to point if intersecting
function Collision.sphere_vs_point(sphere, point)
	if type(sphere) ~= "table" or type(point) ~= "table" then
		return error("Collision.sphere_vs_point requires a sphere and point", 2)
	end

	local point_vec = to_vec(point)
	local diff = point_vec - sphere.center
	local distance = Vector.length(diff)

	if distance <= sphere.radius then
		local penetration = sphere.radius - distance
		local separation = distance > 1e-9 and (diff / distance) or Vector(1, 0, 0)
		return true, penetration, separation
	end
	return false
end

self.sphere_vs_point = Collision.sphere_vs_point

--- Test point vs sphere intersection
---@param point math.vector|{ x: number, y: number, z: number }|{ [1]: number, [2]: number, [3]: number } Point to test
---@param sphere math.collision.sphere
---@return boolean intersecting True if point is inside or on the sphere
---@return number? depth Penetration depth if intersecting
---@return math.vector? separation Separation direction from center to point if intersecting
function Collision.point_vs_sphere(point, sphere)
	if type(point) ~= "table" or type(sphere) ~= "table" then
		return error("Collision.point_vs_sphere requires a point and sphere", 2)
	end

	return Collision.sphere_vs_point(sphere, point)
end

self.point_vs_sphere = Collision.point_vs_sphere

--- Test sphere vs ray intersection
---@param sphere math.collision.sphere
---@param ray math.collision.ray
---@return number? distance Distance to intersection, nil if no intersection
---@return math.vector? intersection Intersection point, nil if no intersection
function Collision.sphere_vs_ray(sphere, ray)
	if type(sphere) ~= "table" or type(ray) ~= "table" then
		return error("Collision.sphere_vs_ray requires a sphere and ray", 2)
	end

	return Collision.ray_vs_sphere(ray, sphere)
end

self.sphere_vs_ray = Collision.sphere_vs_ray

--- Test sphere vs line segment intersection
---@param sphere math.collision.sphere
---@param line math.collision.line
---@return number? dist Distance from line start to intersection, nil if no intersection
---@return math.vector? intersection Intersection point, nil if no intersection
function Collision.sphere_vs_line(sphere, line)
	if type(sphere) ~= "table" or not Collision.is_line(line) then
		return error("Collision.sphere_vs_line requires a sphere and line", 2)
	end

	return Collision.line_vs_sphere(line, sphere)
end

self.sphere_vs_line = Collision.sphere_vs_line

----------------------------------------------------------------------
-- AABB Collision Functions
----------------------------------------------------------------------

--- Test AABB vs point intersection
---@param aabb math.aabb
---@param point math.vector|{ x: number, y: number, z: number }|{ [1]: number, [2]: number, [3]: number } Point to test
---@return boolean inside True if point is inside or on the AABB
function Collision.aabb_vs_point(aabb, point)
	if not AABB.is(aabb) or type(point) ~= "table" then
		return error("Collision.aabb_vs_point requires an AABB and point", 2)
	end

	return AABB.contains_point(aabb, to_vec(point))
end

self.aabb_vs_point = Collision.aabb_vs_point

--- Test point vs AABB intersection
---@param point math.vector|{ x: number, y: number, z: number }|{ [1]: number, [2]: number, [3]: number } Point to test
---@param aabb math.aabb
---@return boolean inside True if point is inside or on the AABB
function Collision.point_vs_aabb(point, aabb)
	if type(point) ~= "table" or not AABB.is(aabb) then
		return error("Collision.point_vs_aabb requires a point and AABB", 2)
	end

	return AABB.contains_point(aabb, to_vec(point))
end

self.point_vs_aabb = Collision.point_vs_aabb

--- Test AABB vs AABB intersection
---@param a math.aabb
---@param b math.aabb
---@return boolean intersecting True if intersecting
---@return number? depth Penetration depth along the minimum axis if intersecting
---@return math.vector? separation Minimum translation direction from A to B if intersecting
function Collision.aabb_vs_aabb(a, b)
	if not AABB.is(a) or not AABB.is(b) then
		return error("Collision.aabb_vs_aabb requires two AABBs", 2)
	end

	local ox = math_min(a.max.x, b.max.x) - math_max(a.min.x, b.min.x)
	if ox < 0 then
		return false
	end
	local oy = math_min(a.max.y, b.max.y) - math_max(a.min.y, b.min.y)
	if oy < 0 then
		return false
	end
	local oz = math_min(a.max.z, b.max.z) - math_max(a.min.z, b.min.z)
	if oz < 0 then
		return false
	end

	local cax = (a.min.x + a.max.x) * 0.5
	local cbx = (b.min.x + b.max.x) * 0.5
	local cay = (a.min.y + a.max.y) * 0.5
	local cby = (b.min.y + b.max.y) * 0.5
	local caz = (a.min.z + a.max.z) * 0.5
	local cbz = (b.min.z + b.max.z) * 0.5

	if ox <= oy and ox <= oz then
		local sign = cbx >= cax and 1 or -1
		return true, ox, Vector(sign, 0, 0)
	end
	if oy <= oz then
		local sign = cby >= cay and 1 or -1
		return true, oy, Vector(0, sign, 0)
	end
	local sign = cbz >= caz and 1 or -1
	return true, oz, Vector(0, 0, sign)
end

self.aabb_vs_aabb = Collision.aabb_vs_aabb

--- Test AABB vs sphere intersection
---@param aabb math.aabb
---@param sphere math.collision.sphere
---@return boolean intersecting True if intersecting
---@return number? depth Penetration depth if intersecting
---@return math.vector? separation Separation direction if intersecting
function Collision.aabb_vs_sphere(aabb, sphere)
	if not AABB.is(aabb) or type(sphere) ~= "table" then
		return error("Collision.aabb_vs_sphere requires an AABB and sphere", 2)
	end

	return Collision.sphere_vs_aabb(sphere, aabb)
end

self.aabb_vs_sphere = Collision.aabb_vs_sphere

--- Test AABB vs plane intersection
---@param aabb math.aabb
---@param plane math.collision.plane
---@return boolean intersecting True if intersecting
---@return number? depth Penetration depth if intersecting
function Collision.aabb_vs_plane(aabb, plane)
	if not AABB.is(aabb) or type(plane) ~= "table" then
		return error("Collision.aabb_vs_plane requires an AABB and plane", 2)
	end

	local center = Vector(
		(aabb.min.x + aabb.max.x) * 0.5,
		(aabb.min.y + aabb.max.y) * 0.5,
		(aabb.min.z + aabb.max.z) * 0.5
	)
	local hx = (aabb.max.x - aabb.min.x) * 0.5
	local hy = (aabb.max.y - aabb.min.y) * 0.5
	local hz = (aabb.max.z - aabb.min.z) * 0.5
	local n = plane.normal
	local dist = Vector.dot(n, center) + plane.distance
	local radius = math_abs(n[1]) * hx
		+ math_abs(n[2]) * hy
		+ math_abs(n[3]) * hz

	if math_abs(dist) <= radius then
		return true, radius - math_abs(dist)
	end
	return false
end

self.aabb_vs_plane = Collision.aabb_vs_plane

--- Test AABB vs triangle intersection using SAT
---@param aabb math.aabb
---@param triangle math.collision.triangle
---@return boolean intersecting True if intersecting
function Collision.aabb_vs_triangle(aabb, triangle)
	if not AABB.is(aabb) or type(triangle) ~= "table" then
		return error("Collision.aabb_vs_triangle requires an AABB and triangle", 2)
	end

	local tri_min_x = math_min(triangle.a[1], math_min(triangle.b[1], triangle.c[1]))
	local tri_max_x = math_max(triangle.a[1], math_max(triangle.b[1], triangle.c[1]))
	if tri_max_x < aabb.min.x or tri_min_x > aabb.max.x then
		return false
	end
	local tri_min_y = math_min(triangle.a[2], math_min(triangle.b[2], triangle.c[2]))
	local tri_max_y = math_max(triangle.a[2], math_max(triangle.b[2], triangle.c[2]))
	if tri_max_y < aabb.min.y or tri_min_y > aabb.max.y then
		return false
	end
	local tri_min_z = math_min(triangle.a[3], math_min(triangle.b[3], triangle.c[3]))
	local tri_max_z = math_max(triangle.a[3], math_max(triangle.b[3], triangle.c[3]))
	if tri_max_z < aabb.min.z or tri_min_z > aabb.max.z then
		return false
	end

	local normal = Collision.triangle_normal(triangle)
	local aabb_center = Vector(
		(aabb.min.x + aabb.max.x) * 0.5,
		(aabb.min.y + aabb.max.y) * 0.5,
		(aabb.min.z + aabb.max.z) * 0.5
	)
	local hx = (aabb.max.x - aabb.min.x) * 0.5
	local hy = (aabb.max.y - aabb.min.y) * 0.5
	local hz = (aabb.max.z - aabb.min.z) * 0.5
	local tri_dist = Vector.dot(normal, triangle.a)
	local center_dist = Vector.dot(normal, aabb_center)
	local radius = math_abs(normal[1]) * hx
		+ math_abs(normal[2]) * hy
		+ math_abs(normal[3]) * hz
	if math_abs(center_dist - tri_dist) > radius then
		return false
	end

	local edges = {
		triangle.b - triangle.a,
		triangle.c - triangle.b,
		triangle.a - triangle.c,
	}
	local box_axes = { Vector(1, 0, 0), Vector(0, 1, 0), Vector(0, 0, 1) }
	for i = 1, 3 do
		local edge = edges[i]
		for j = 1, 3 do
			local axis = box_axes[j]
			local test_axis = Vector.cross(edge, axis)
			if Vector.length_squared(test_axis) > 1e-12 then
				local len = Vector.length(test_axis)
				test_axis = test_axis / len
				local t_min, t_max = project_triangle_onto_axis(triangle, test_axis)
				local b_min, b_max = project_aabb_onto_axis(aabb, test_axis)
				if t_max < b_min or b_max < t_min then
					return false
				end
			end
		end
	end

	return true
end

self.aabb_vs_triangle = Collision.aabb_vs_triangle

--- Test AABB vs OBB intersection
---@param aabb math.aabb
---@param obb math.collision.obb
---@return boolean intersecting True if intersecting
function Collision.aabb_vs_obb(aabb, obb)
	if not AABB.is(aabb) or not OBB.is(obb) then
		return error("Collision.aabb_vs_obb requires an AABB and OBB", 2)
	end

	local center = Vector(
		(aabb.min.x + aabb.max.x) * 0.5,
		(aabb.min.y + aabb.max.y) * 0.5,
		(aabb.min.z + aabb.max.z) * 0.5
	)
	local half = Vector(
		(aabb.max.x - aabb.min.x) * 0.5,
		(aabb.max.y - aabb.min.y) * 0.5,
		(aabb.max.z - aabb.min.z) * 0.5
	)
	local box_as_obb = OBB(center, half, Matrix4x4.identity)
	return Collision.obb_vs_obb(box_as_obb, obb)
end

self.aabb_vs_obb = Collision.aabb_vs_obb

--- Test AABB vs ray intersection
---@param aabb math.aabb
---@param ray math.collision.ray
---@return number? dist Distance to intersection, nil if no intersection
---@return math.vector? intersection Intersection point, nil if no intersection
function Collision.aabb_vs_ray(aabb, ray)
	if not AABB.is(aabb) or type(ray) ~= "table" then
		return error("Collision.aabb_vs_ray requires an AABB and ray", 2)
	end

	return Collision.ray_vs_aabb(ray, aabb)
end

self.aabb_vs_ray = Collision.aabb_vs_ray

--- Test AABB vs line segment intersection
---@param aabb math.aabb
---@param line math.collision.line
---@return number? dist Distance from line start to intersection, nil if no intersection
---@return math.vector? intersection Intersection point, nil if no intersection
function Collision.aabb_vs_line(aabb, line)
	if not AABB.is(aabb) or not Collision.is_line(line) then
		return error("Collision.aabb_vs_line requires an AABB and line", 2)
	end

	return Collision.line_vs_aabb(line, aabb)
end

self.aabb_vs_line = Collision.aabb_vs_line

----------------------------------------------------------------------
-- Plane Collision Functions
----------------------------------------------------------------------

--- Test point vs plane
---@param point math.vector|{ x: number, y: number, z: number }|{ [1]: number, [2]: number, [3]: number } Point to test
---@param plane math.collision.plane
---@return number dist Signed distance from point to plane
function Collision.point_vs_plane(point, plane)
	if type(point) ~= "table" or type(plane) ~= "table" then
		return error("Collision.point_vs_plane requires a point and plane", 2)
	end

	local point_vec = Vector.is(point) and point or Vector(
		tonumber(point.x or point[1]) or 0,
		tonumber(point.y or point[2]) or 0,
		tonumber(point.z or point[3]) or 0
	)

	return Vector.dot(plane.normal, point_vec) + plane.distance
end

self.point_vs_plane = Collision.point_vs_plane

--- Test if point is on plane (within epsilon)
---@param point math.vector|{ x: number, y: number, z: number }|{ [1]: number, [2]: number, [3]: number } Point to test
---@param plane math.collision.plane
---@param epsilon? number Tolerance (default: 1e-6)
---@return boolean test True if point is on plane
function Collision.point_on_plane(point, plane, epsilon)
	local distance = Collision.point_vs_plane(point, plane)
	epsilon = epsilon or 1e-6
	return math_abs(distance) < epsilon
end

self.point_on_plane = Collision.point_on_plane

--- Project point onto plane
---@param point math.vector|{ x: number, y: number, z: number }|{ [1]: number, [2]: number, [3]: number } Point to project
---@param plane math.collision.plane
---@return math.vector point Projected point
function Collision.project_point_on_plane(point, plane)
	if type(point) ~= "table" or type(plane) ~= "table" then
		return error("Collision.project_point_on_plane requires a point and plane", 2)
	end

	local point_vec = Vector.is(point) and point or Vector(
		tonumber(point.x or point[1]) or 0,
		tonumber(point.y or point[2]) or 0,
		tonumber(point.z or point[3]) or 0
	)

	local distance = Vector.dot(plane.normal, point_vec) + plane.distance
	return point_vec - plane.normal * distance
end

self.project_point_on_plane = Collision.project_point_on_plane

--- Test plane vs point, returns signed distance
---@param plane math.collision.plane
---@param point math.vector|{ x: number, y: number, z: number }|{ [1]: number, [2]: number, [3]: number } Point to test
---@return number dist Signed distance from point to plane
function Collision.plane_vs_point(plane, point)
	if type(plane) ~= "table" or type(point) ~= "table" then
		return error("Collision.plane_vs_point requires a plane and point", 2)
	end

	return Collision.point_vs_plane(point, plane)
end

self.plane_vs_point = Collision.plane_vs_point

--- Test plane vs ray intersection
---@param plane math.collision.plane
---@param ray math.collision.ray
---@return number? distance Distance to intersection, nil if no intersection
---@return math.vector? intersection Intersection point, nil if no intersection
function Collision.plane_vs_ray(plane, ray)
	if type(plane) ~= "table" or type(ray) ~= "table" then
		return error("Collision.plane_vs_ray requires a plane and ray", 2)
	end

	return Collision.ray_vs_plane(ray, plane)
end

self.plane_vs_ray = Collision.plane_vs_ray

--- Test plane vs sphere intersection
---@param plane math.collision.plane
---@param sphere math.collision.sphere
---@return boolean intersecting True if intersecting
---@return number? depth Penetration depth if intersecting
function Collision.plane_vs_sphere(plane, sphere)
	if type(plane) ~= "table" or type(sphere) ~= "table" then
		return error("Collision.plane_vs_sphere requires a plane and sphere", 2)
	end

	return Collision.sphere_vs_plane(sphere, plane)
end

self.plane_vs_sphere = Collision.plane_vs_sphere

--- Test plane vs AABB intersection
---@param plane math.collision.plane
---@param aabb math.aabb
---@return boolean intersecting True if intersecting
---@return number? depth Penetration depth if intersecting
function Collision.plane_vs_aabb(plane, aabb)
	if type(plane) ~= "table" or not AABB.is(aabb) then
		return error("Collision.plane_vs_aabb requires a plane and AABB", 2)
	end

	return Collision.aabb_vs_plane(aabb, plane)
end

self.plane_vs_aabb = Collision.plane_vs_aabb

--- Test plane vs triangle intersection (straddle test)
---@param plane math.collision.plane
---@param triangle math.collision.triangle
---@param epsilon? number Tolerance (default: 1e-6)
---@return boolean intersecting True if triangle straddles or touches the plane
function Collision.plane_vs_triangle(plane, triangle, epsilon)
	if type(plane) ~= "table" or type(triangle) ~= "table" then
		return error("Collision.plane_vs_triangle requires a plane and triangle", 2)
	end

	epsilon = epsilon == nil and 1e-6 or tonumber(epsilon) or 1e-6
	local d1 = Collision.point_vs_plane(triangle.a, plane)
	local d2 = Collision.point_vs_plane(triangle.b, plane)
	local d3 = Collision.point_vs_plane(triangle.c, plane)

	if d1 > epsilon and d2 > epsilon and d3 > epsilon then
		return false
	end
	if d1 < -epsilon and d2 < -epsilon and d3 < -epsilon then
		return false
	end
	return true
end

self.plane_vs_triangle = Collision.plane_vs_triangle

--- Test plane vs OBB intersection
---@param plane math.collision.plane
---@param obb math.collision.obb
---@return boolean intersecting True if intersecting
---@return number? depth Penetration depth if intersecting
function Collision.plane_vs_obb(plane, obb)
	if type(plane) ~= "table" or not OBB.is(obb) then
		return error("Collision.plane_vs_obb requires a plane and OBB", 2)
	end

	local dist = Vector.dot(plane.normal, obb.center) + plane.distance
	local ax1, ax2, ax3 = obb_axes(obb)
	local radius = math_abs(Vector.dot(ax1, plane.normal)) * obb.half_extents[1]
		+ math_abs(Vector.dot(ax2, plane.normal)) * obb.half_extents[2]
		+ math_abs(Vector.dot(ax3, plane.normal)) * obb.half_extents[3]

	if math_abs(dist) <= radius then
		return true, radius - math_abs(dist)
	end
	return false
end

self.plane_vs_obb = Collision.plane_vs_obb

--- Test plane vs plane intersection
---@param plane1 math.collision.plane
---@param plane2 math.collision.plane
---@param epsilon? number Tolerance (default: 1e-6)
---@return boolean intersecting True if planes intersect or are coincident
function Collision.plane_vs_plane(plane1, plane2, epsilon)
	if type(plane1) ~= "table" or type(plane2) ~= "table" then
		return error("Collision.plane_vs_plane requires two planes", 2)
	end

	epsilon = epsilon == nil and 1e-6 or tonumber(epsilon) or 1e-6
	local dot = Vector.dot(plane1.normal, plane2.normal)

	if math_abs(math_abs(dot) - 1) <= epsilon then
		if dot > 0 then
			return math_abs(plane1.distance - plane2.distance) <= epsilon
		else
			return math_abs(plane1.distance + plane2.distance) <= epsilon
		end
	end
	return true
end

self.plane_vs_plane = Collision.plane_vs_plane

----------------------------------------------------------------------
-- Triangle Collision Functions
----------------------------------------------------------------------

--- Get triangle normal
---@param triangle math.collision.triangle
---@return math.vector normal Triangle normal (normalized)
function Collision.triangle_normal(triangle)
	if type(triangle) ~= "table" then
		return error("Collision.triangle_normal requires a triangle", 2)
	end

	local a = triangle.a
	local b = triangle.b
	local c = triangle.c

	local edge1 = b - a
	local edge2 = c - a
	local normal = Vector.cross(edge1, edge2)

	local length = Vector.length(normal)
	if length > 0 then
		return normal / length
	end
	return Vector(0, 1, 0) -- Default up for degenerate triangle
end

self.triangle_normal = Collision.triangle_normal

--- Get triangle area
---@param triangle math.collision.triangle
---@return number area Triangle area
function Collision.triangle_area(triangle)
	if type(triangle) ~= "table" then
		return error("Collision.triangle_area requires a triangle", 2)
	end

	local a = triangle.a
	local b = triangle.b
	local c = triangle.c

	local edge1 = b - a
	local edge2 = c - a
	local cross = Vector.cross(edge1, edge2)

	return Vector.length(cross) * 0.5
end

self.triangle_area = Collision.triangle_area

--- Find closest point on triangle to a given point
---@param point math.vector|{ x: number, y: number, z: number }|{ [1]: number, [2]: number, [3]: number } Point to find closest point for
---@param triangle math.collision.triangle
---@return math.vector point Closest point on triangle
function Collision.closest_point_on_triangle(point, triangle)
	if type(point) ~= "table" or type(triangle) ~= "table" then
		return error("Collision.closest_point_on_triangle requires a point and triangle", 2)
	end

	local point_vec = Vector.is(point) and point or Vector(
		tonumber(point.x or point[1]) or 0,
		tonumber(point.y or point[2]) or 0,
		tonumber(point.z or point[3]) or 0
	)

	local a = triangle.a
	local b = triangle.b
	local c = triangle.c

	-- Check if point is in vertex region outside A
	local ab = b - a
	local ac = c - a
	local ap = point_vec - a

	local dot1 = Vector.dot(ab, ab)
	local dot2 = Vector.dot(ac, ap)
	local dot3 = Vector.dot(ab, ap)
	local dot4 = Vector.dot(ac, ac)
	local dot5 = Vector.dot(ab, ac)

	local vc = dot1 * dot4 - dot5 * dot5
	if vc <= 1e-6 then
		return a -- Degenerate triangle
	end

	local v = (dot4 * dot3 - dot5 * dot2) / vc
	local w = (dot1 * dot2 - dot5 * dot3) / vc

	if v >= 0 and w >= 0 and v + w <= 1 then
		-- Inside triangle
		return a + ab * v + ac * w
	end

	-- Check vertex regions
	local closest = a
	local min_dist = Vector.length_squared(point_vec - a)

	local dist_b = Vector.length_squared(point_vec - b)
	if dist_b < min_dist then
		closest = b
		min_dist = dist_b
	end

	local dist_c = Vector.length_squared(point_vec - c)
	if dist_c < min_dist then
		closest = c
	end

	-- Check edge regions
	local edge_closest = Collision.closest_point_on_segment(point_vec, a, b)
	local dist_edge = Vector.length_squared(point_vec - edge_closest)
	if dist_edge < min_dist then
		closest = edge_closest
		min_dist = dist_edge
	end

	edge_closest = Collision.closest_point_on_segment(point_vec, b, c)
	dist_edge = Vector.length_squared(point_vec - edge_closest)
	if dist_edge < min_dist then
		closest = edge_closest
		min_dist = dist_edge
	end

	edge_closest = Collision.closest_point_on_segment(point_vec, c, a)
	dist_edge = Vector.length_squared(point_vec - edge_closest)
	if dist_edge < min_dist then
		closest = edge_closest
	end

	return closest
end

self.closest_point_on_triangle = Collision.closest_point_on_triangle

--- Find closest point on line segment to a given point
---@param point math.vector Point to find closest point for
---@param segment_start math.vector Segment start point
---@param segment_end math.vector Segment end point
---@return math.vector point Closest point on segment
function Collision.closest_point_on_segment(point, segment_start, segment_end)
	local ab = segment_end - segment_start
	local ap = point - segment_start
	local ab_length_sq = Vector.length_squared(ab)

	if ab_length_sq == 0 then
		return segment_start -- Degenerate segment
	end

	local t = Vector.dot(ap, ab) / ab_length_sq
	t = math_max(0, math_min(1, t)) -- Clamp to [0, 1]

	return segment_start + ab * t
end

self.closest_point_on_segment = Collision.closest_point_on_segment

--- Test triangle vs point (point on triangle within tolerance)
---@param triangle math.collision.triangle
---@param point math.vector|{ x: number, y: number, z: number }|{ [1]: number, [2]: number, [3]: number } Point to test
---@param epsilon? number Tolerance (default: 1e-6)
---@return boolean inside True if point lies on the triangle
function Collision.triangle_vs_point(triangle, point, epsilon)
	if type(triangle) ~= "table" or type(point) ~= "table" then
		return error("Collision.triangle_vs_point requires a triangle and point", 2)
	end

	epsilon = epsilon == nil and 1e-6 or tonumber(epsilon) or 1e-6
	local point_vec = to_vec(point)
	local closest = Collision.closest_point_on_triangle(point_vec, triangle)
	return Vector.distance(point_vec, closest) <= epsilon
end

self.triangle_vs_point = Collision.triangle_vs_point

--- Test point vs triangle (point on triangle within tolerance)
---@param point math.vector|{ x: number, y: number, z: number }|{ [1]: number, [2]: number, [3]: number } Point to test
---@param triangle math.collision.triangle
---@param epsilon? number Tolerance (default: 1e-6)
---@return boolean inside True if point lies on the triangle
function Collision.point_vs_triangle(point, triangle, epsilon)
	if type(point) ~= "table" or type(triangle) ~= "table" then
		return error("Collision.point_vs_triangle requires a point and triangle", 2)
	end

	return Collision.triangle_vs_point(triangle, point, epsilon)
end

self.point_vs_triangle = Collision.point_vs_triangle

--- Test triangle vs ray intersection
---@param triangle math.collision.triangle
---@param ray math.collision.ray
---@return number? dist Distance to intersection, nil if no intersection
---@return math.vector? point Intersection point, nil if no intersection
function Collision.triangle_vs_ray(triangle, ray)
	if type(triangle) ~= "table" or type(ray) ~= "table" then
		return error("Collision.triangle_vs_ray requires a triangle and ray", 2)
	end

	return Collision.ray_vs_triangle(ray, triangle)
end

self.triangle_vs_ray = Collision.triangle_vs_ray

--- Test triangle vs line segment intersection
---@param triangle math.collision.triangle
---@param line math.collision.line
---@return number? dist Distance from line start to intersection, nil if no intersection
---@return math.vector? point Intersection point, nil if no intersection
function Collision.triangle_vs_line(triangle, line)
	if type(triangle) ~= "table" or not Collision.is_line(line) then
		return error("Collision.triangle_vs_line requires a triangle and line", 2)
	end

	return Collision.line_vs_triangle(line, triangle)
end

self.triangle_vs_line = Collision.triangle_vs_line

--- Test triangle vs sphere intersection
---@param triangle math.collision.triangle
---@param sphere math.collision.sphere
---@return boolean intersecting True if intersecting
---@return number? depth Penetration depth if intersecting
---@return math.vector? separation Separation direction if intersecting
function Collision.triangle_vs_sphere(triangle, sphere)
	if type(triangle) ~= "table" or type(sphere) ~= "table" then
		return error("Collision.triangle_vs_sphere requires a triangle and sphere", 2)
	end

	return Collision.sphere_vs_triangle(sphere, triangle)
end

self.triangle_vs_sphere = Collision.triangle_vs_sphere

--- Test triangle vs AABB intersection
---@param triangle math.collision.triangle
---@param aabb math.aabb
---@return boolean intersecting True if intersecting
function Collision.triangle_vs_aabb(triangle, aabb)
	if type(triangle) ~= "table" or not AABB.is(aabb) then
		return error("Collision.triangle_vs_aabb requires a triangle and AABB", 2)
	end

	return Collision.aabb_vs_triangle(aabb, triangle)
end

self.triangle_vs_aabb = Collision.triangle_vs_aabb

--- Test triangle vs plane intersection
---@param triangle math.collision.triangle
---@param plane math.collision.plane
---@param epsilon? number Tolerance (default: 1e-6)
---@return boolean intersecting True if triangle straddles or touches the plane
function Collision.triangle_vs_plane(triangle, plane, epsilon)
	if type(triangle) ~= "table" or type(plane) ~= "table" then
		return error("Collision.triangle_vs_plane requires a triangle and plane", 2)
	end

	return Collision.plane_vs_triangle(plane, triangle, epsilon)
end

self.triangle_vs_plane = Collision.triangle_vs_plane

--- Test triangle vs triangle intersection using SAT
---@param t1 math.collision.triangle
---@param t2 math.collision.triangle
---@param epsilon? number Tolerance (default: 1e-6)
---@return boolean intersecting True if intersecting
function Collision.triangle_vs_triangle(t1, t2, epsilon)
	if type(t1) ~= "table" or type(t2) ~= "table" then
		return error("Collision.triangle_vs_triangle requires two triangles", 2)
	end

	epsilon = epsilon == nil and 1e-6 or tonumber(epsilon) or 1e-6

	local n1 = Collision.triangle_normal(t1)
	local n2 = Collision.triangle_normal(t2)

	local d1 = Vector.dot(n1, t1.a)
	local min2, max2 = project_triangle_onto_axis(t2, n1)
	if d1 < min2 - epsilon or d1 > max2 + epsilon then
		local closest = Collision.closest_point_on_triangle(t1.a, t2)
		if Vector.distance(t1.a, closest) > epsilon then
			return false
		end
	end

	local d2 = Vector.dot(n2, t2.a)
	local min1, max1 = project_triangle_onto_axis(t1, n2)
	if d2 < min1 - epsilon or d2 > max1 + epsilon then
		local closest = Collision.closest_point_on_triangle(t2.a, t1)
		if Vector.distance(t2.a, closest) > epsilon then
			return false
		end
	end

	local edges1 = { t1.b - t1.a, t1.c - t1.b, t1.a - t1.c }
	local edges2 = { t2.b - t2.a, t2.c - t2.b, t2.a - t2.c }
	for i = 1, #edges1 do
		local e1 = edges1[i]
		for j = 1, #edges2 do
			local e2 = edges2[j]
			local axis = Vector.cross(e1, e2)
			if Vector.length_squared(axis) > 1e-12 then
				axis = axis / Vector.length(axis)
				local a_min, a_max = project_triangle_onto_axis(t1, axis)
				local b_min, b_max = project_triangle_onto_axis(t2, axis)
				if a_max < b_min - epsilon or b_max < a_min - epsilon then
					return false
				end
			end
		end
	end

	if math_abs(Vector.dot(n1, n2)) > 1 - epsilon then
		return not (d1 < min2 - epsilon or d1 > max2 + epsilon)
	end
	return true
end

self.triangle_vs_triangle = Collision.triangle_vs_triangle

--- Test triangle vs OBB intersection using SAT
---@param triangle math.collision.triangle
---@param obb math.collision.obb
---@return boolean intersecting True if intersecting
function Collision.triangle_vs_obb(triangle, obb)
	if type(triangle) ~= "table" or not OBB.is(obb) then
		return error("Collision.triangle_vs_obb requires a triangle and OBB", 2)
	end

	local ax1, ax2, ax3 = obb_axes(obb)
	local obb_axes_list = { ax1, ax2, ax3 }

	for i = 1, #obb_axes_list do
		local axis = obb_axes_list[i]
		local t_min, t_max = project_triangle_onto_axis(triangle, axis)
		local o_min, o_max = Collision.project_obb_onto_axis(obb, axis)
		if t_max < o_min or o_max < t_min then
			return false
		end
	end

	local normal = Collision.triangle_normal(triangle)
	local t_dist = Vector.dot(normal, triangle.a)
	local o_min, o_max = Collision.project_obb_onto_axis(obb, normal)
	if t_dist < o_min or t_dist > o_max then
		return false -- Box misses the triangle plane: separating axis found
	end

	local edges = {
		triangle.b - triangle.a,
		triangle.c - triangle.b,
		triangle.a - triangle.c,
	}
	for i = 1, #edges do
		local edge = edges[i]
		for j = 1, #obb_axes_list do
			local axis = obb_axes_list[j]
			local test_axis = Vector.cross(edge, axis)
			if Vector.length_squared(test_axis) > 1e-12 then
				test_axis = test_axis / Vector.length(test_axis)
				local t_min, t_max = project_triangle_onto_axis(triangle, test_axis)
				local oo_min, oo_max = Collision.project_obb_onto_axis(obb, test_axis)
				if t_max < oo_min or oo_max < t_min then
					return false
				end
			end
		end
	end

	return true
end

self.triangle_vs_obb = Collision.triangle_vs_obb

----------------------------------------------------------------------
-- Oriented Bounding Box (OBB) Functions
----------------------------------------------------------------------

--- Create an OBB
---@param center math.vector|{ x: number, y: number, z: number }|{ [1]: number, [2]: number, [3]: number } OBB center
---@param half_extents math.vector|{ x: number, y: number, z: number }|{ [1]: number, [2]: number, [3]: number } Half-extents along local axes
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

	return OBB(center_vec, extents_vec, orientation_matrix)
end

self.obb = OBB_new

--- Test OBB vs point intersection
---@param obb math.collision.obb
---@param point math.vector|{ x: number, y: number, z: number }|{ [1]: number, [2]: number, [3]: number } Point to test
---@return boolean inside True if point is inside OBB
function Collision.obb_vs_point(obb, point)
	if not OBB.is(obb) or type(point) ~= "table" then
		return error("Collision.obb_vs_point requires an OBB and point", 2)
	end

	local point_vec = Vector.is(point) and point or Vector(
		tonumber(point.x or point[1]) or 0,
		tonumber(point.y or point[2]) or 0,
		tonumber(point.z or point[3]) or 0
	)

	-- Use OBB's built-in contains_point function
	return OBB.contains_point(obb, point_vec)
end

self.obb_vs_point = Collision.obb_vs_point

--- Test OBB vs OBB intersection using Separating Axis Theorem
---@param obb1 math.collision.obb
---@param obb2 math.collision.obb
---@return boolean intersecting True if intersecting
function Collision.obb_vs_obb(obb1, obb2)
	if not OBB.is(obb1) or not OBB.is(obb2) then
		return error("Collision.obb_vs_obb requires two OBBs", 2)
	end

	-- Get OBB axes (convert to Vector since Matrix4x4.get_column returns plain tables)
	local col1 = Matrix4x4.get_column(obb1.orientation, 1)
	local col2 = Matrix4x4.get_column(obb1.orientation, 2)
	local col3 = Matrix4x4.get_column(obb1.orientation, 3)
	local axes1 = {
		Vector(col1[1], col1[2], col1[3]),
		Vector(col2[1], col2[2], col2[3]),
		Vector(col3[1], col3[2], col3[3])
	}

	local col4 = Matrix4x4.get_column(obb2.orientation, 1)
	local col5 = Matrix4x4.get_column(obb2.orientation, 2)
	local col6 = Matrix4x4.get_column(obb2.orientation, 3)
	local axes2 = {
		Vector(col4[1], col4[2], col4[3]),
		Vector(col5[1], col5[2], col5[3]),
		Vector(col6[1], col6[2], col6[3])
	}

	-- Test all 15 separating axes
	local test_axes = {}

	-- Add OBB1 axes
	for i = 1, 3 do
		test_axes[#test_axes + 1] = axes1[i]
	end

	-- Add OBB2 axes
	for i = 1, 3 do
		test_axes[#test_axes + 1] = axes2[i]
	end

	-- Add cross products of axes
	for i = 1, 3 do
		for j = 1, 3 do
			local cross = Vector.cross(axes1[i], axes2[j])
			local cross_length = Vector.length(cross)
			if cross_length > 1e-6 then
				test_axes[#test_axes + 1] = cross / cross_length
			end
		end
	end

	-- Test each separating axis
	for i = 1, #test_axes do
		local axis = test_axes[i]
		-- Project both OBBs onto the axis
		local proj1_min, proj1_max = Collision.project_obb_onto_axis(obb1, axis)
		local proj2_min, proj2_max = Collision.project_obb_onto_axis(obb2, axis)

		-- Check for separation
		if proj1_max < proj2_min or proj2_max < proj1_min then
			return false -- Separating axis found
		end
	end

	return true -- No separating axis found, OBBs intersect
end

self.obb_vs_obb = Collision.obb_vs_obb

--- Project OBB onto an axis
---@param obb math.collision.obb
---@param axis math.vector Projection axis (should be normalized)
---@return number min Minimum projection value
---@return number max Maximum projection value
function Collision.project_obb_onto_axis(obb, axis)
	if not OBB.is(obb) or type(axis) ~= "table" then
		return error("Collision.project_obb_onto_axis requires an OBB and axis", 2)
	end

	-- Get OBB axes in world space (convert to Vector since Matrix4x4.get_column returns plain tables)
	local col1 = Matrix4x4.get_column(obb.orientation, 1)
	local col2 = Matrix4x4.get_column(obb.orientation, 2)
	local col3 = Matrix4x4.get_column(obb.orientation, 3)
	local axes = {
		Vector(col1[1], col1[2], col1[3]),
		Vector(col2[1], col2[2], col2[3]),
		Vector(col3[1], col3[2], col3[3])
	}

	-- Project center onto axis
	local center_proj = Vector.dot(obb.center, axis)

	-- Calculate radius of projection
	local radius = 0
	for i = 1, 3 do
		radius = radius + math_abs(Vector.dot(axes[i], axis)) * obb.half_extents[i]
	end

	return center_proj - radius, center_proj + radius
end

self.project_obb_onto_axis = Collision.project_obb_onto_axis

--- Test OBB vs AABB intersection
---@param obb math.collision.obb
---@param aabb math.aabb
---@return boolean intersecting True if intersecting
function Collision.obb_vs_aabb(obb, aabb)
	if not OBB.is(obb) or not AABB.is(aabb) then
		return error("Collision.obb_vs_aabb requires an OBB and AABB", 2)
	end

	return Collision.aabb_vs_obb(aabb, obb)
end

self.obb_vs_aabb = Collision.obb_vs_aabb

--- Test OBB vs sphere intersection
---@param obb math.collision.obb
---@param sphere math.collision.sphere
---@return boolean intersecting True if intersecting
---@return number? depth Penetration depth if intersecting
---@return math.vector? separation Separation direction in world space if intersecting
function Collision.obb_vs_sphere(obb, sphere)
	if not OBB.is(obb) or type(sphere) ~= "table" then
		return error("Collision.obb_vs_sphere requires an OBB and sphere", 2)
	end

	return Collision.sphere_vs_obb(sphere, obb)
end

self.obb_vs_sphere = Collision.obb_vs_sphere

--- Test OBB vs plane intersection
---@param obb math.collision.obb
---@param plane math.collision.plane
---@return boolean intersecting True if intersecting
---@return number? depth Penetration depth if intersecting
function Collision.obb_vs_plane(obb, plane)
	if not OBB.is(obb) or type(plane) ~= "table" then
		return error("Collision.obb_vs_plane requires an OBB and plane", 2)
	end

	return Collision.plane_vs_obb(plane, obb)
end

self.obb_vs_plane = Collision.obb_vs_plane

--- Test OBB vs triangle intersection
---@param obb math.collision.obb
---@param triangle math.collision.triangle
---@return boolean intersecting True if intersecting
function Collision.obb_vs_triangle(obb, triangle)
	if not OBB.is(obb) or type(triangle) ~= "table" then
		return error("Collision.obb_vs_triangle requires an OBB and triangle", 2)
	end

	return Collision.triangle_vs_obb(triangle, obb)
end

self.obb_vs_triangle = Collision.obb_vs_triangle

--- Test OBB vs ray intersection
---@param obb math.collision.obb
---@param ray math.collision.ray
---@return number? distance Distance to intersection, nil if no intersection
---@return math.vector? intersection Intersection point, nil if no intersection
function Collision.obb_vs_ray(obb, ray)
	if not OBB.is(obb) or type(ray) ~= "table" then
		return error("Collision.obb_vs_ray requires an OBB and ray", 2)
	end

	return Collision.ray_vs_obb(ray, obb)
end

self.obb_vs_ray = Collision.obb_vs_ray

--- Test OBB vs line segment intersection
---@param obb math.collision.obb
---@param line math.collision.line
---@return number? dist Distance from line start to intersection, nil if no intersection
---@return math.vector? intersection Intersection point, nil if no intersection
function Collision.obb_vs_line(obb, line)
	if not OBB.is(obb) or not Collision.is_line(line) then
		return error("Collision.obb_vs_line requires an OBB and line", 2)
	end

	return Collision.line_vs_obb(line, obb)
end

self.obb_vs_line = Collision.obb_vs_line

--- Test point vs OBB intersection
---@param point math.vector|{ x: number, y: number, z: number }|{ [1]: number, [2]: number, [3]: number } Point to test
---@param obb math.collision.obb
---@return boolean inside True if point is inside OBB
function Collision.point_vs_obb(point, obb)
	if type(point) ~= "table" or not OBB.is(obb) then
		return error("Collision.point_vs_obb requires a point and OBB", 2)
	end

	return Collision.obb_vs_point(obb, point)
end

self.point_vs_obb = Collision.point_vs_obb

----------------------------------------------------------------------
-- Distance and Closest Point Utilities
----------------------------------------------------------------------

--- Get distance between point and AABB
---@param point math.vector|{ x: number, y: number, z: number }|{ [1]: number, [2]: number, [3]: number } Point
---@param aabb math.aabb
---@return number dist Distance
---@return math.vector point Closest point on AABB
function Collision.distance_point_to_aabb(point, aabb)
	if type(point) ~= "table" or not AABB.is(aabb) then
		return error("Collision.distance_point_to_aabb requires a point and AABB", 2)
	end

	local point_vec = Vector.is(point) and point or Vector(
		tonumber(point.x or point[1]) or 0,
		tonumber(point.y or point[2]) or 0,
		tonumber(point.z or point[3]) or 0
	)

	-- Find closest point on AABB
	local closest = Vector(
		math_max(aabb.min.x, math_min(point_vec[1], aabb.max.x)),
		math_max(aabb.min.y, math_min(point_vec[2], aabb.max.y)),
		math_max(aabb.min.z, math_min(point_vec[3], aabb.max.z))
	)

	-- Calculate distance
	local diff = point_vec - closest
	local distance = Vector.length(diff)

	return distance, closest
end

self.distance_point_to_aabb = Collision.distance_point_to_aabb

--- Get distance between point and sphere
---@param point math.vector|{ x: number, y: number, z: number }|{ [1]: number, [2]: number, [3]: number } Point
---@param sphere math.collision.sphere
---@return number dist Distance
---@return math.vector point Closest point on sphere surface
function Collision.distance_point_to_sphere(point, sphere)
	if type(point) ~= "table" or type(sphere) ~= "table" then
		return error("Collision.distance_point_to_sphere requires a point and sphere", 2)
	end

	local point_vec = Vector.is(point) and point or Vector(
		tonumber(point.x or point[1]) or 0,
		tonumber(point.y or point[2]) or 0,
		tonumber(point.z or point[3]) or 0
	)

	local diff = point_vec - sphere.center
	local distance = Vector.length(diff)

	if distance <= sphere.radius then
		-- Point is inside or on sphere
		return 0, sphere.center
	end
	-- Point is outside sphere
	local closest = sphere.center + (diff / distance) * sphere.radius
	return distance - sphere.radius, closest
end

self.distance_point_to_sphere = Collision.distance_point_to_sphere

--- Get distance between point and plane
---@param point math.vector|{ x: number, y: number, z: number }|{ [1]: number, [2]: number, [3]: number } Point
---@param plane math.collision.plane
---@return number dist Signed distance (positive if point is in normal direction)
---@return math.vector point Closest point on plane
function Collision.distance_point_to_plane(point, plane)
	if type(point) ~= "table" or type(plane) ~= "table" then
		return error("Collision.distance_point_to_plane requires a point and plane", 2)
	end

	local point_vec = Vector.is(point) and point or Vector(
		tonumber(point.x or point[1]) or 0,
		tonumber(point.y or point[2]) or 0,
		tonumber(point.z or point[3]) or 0
	)

	local distance = Vector.dot(plane.normal, point_vec) + plane.distance
	local closest = point_vec - plane.normal * distance

	return distance, closest
end

self.distance_point_to_plane = Collision.distance_point_to_plane

--- Get distance between point and OBB
---@param point math.vector|{ x: number, y: number, z: number }|{ [1]: number, [2]: number, [3]: number } Point
---@param obb math.collision.obb
---@return number dist Distance
---@return math.vector point Closest point on OBB
function Collision.distance_point_to_obb(point, obb)
	if type(point) ~= "table" or not OBB.is(obb) then
		return error("Collision.distance_point_to_obb requires a point and OBB", 2)
	end

	local closest = Collision.closest_point_on_obb(point, obb)
	return Vector.distance(to_vec(point), closest), closest
end

self.distance_point_to_obb = Collision.distance_point_to_obb

--- Get distance between point and triangle
---@param point math.vector|{ x: number, y: number, z: number }|{ [1]: number, [2]: number, [3]: number } Point
---@param triangle math.collision.triangle
---@return number dist Distance
---@return math.vector point Closest point on triangle
function Collision.distance_point_to_triangle(point, triangle)
	if type(point) ~= "table" or type(triangle) ~= "table" then
		return error("Collision.distance_point_to_triangle requires a point and triangle", 2)
	end

	local point_vec = to_vec(point)
	local closest = Collision.closest_point_on_triangle(point_vec, triangle)
	return Vector.distance(point_vec, closest), closest
end

self.distance_point_to_triangle = Collision.distance_point_to_triangle

--- Get distance between point and segment given as two points
---@param point math.vector|{ x: number, y: number, z: number }|{ [1]: number, [2]: number, [3]: number } Point
---@param a math.vector|{ x: number, y: number, z: number }|{ [1]: number, [2]: number, [3]: number } Segment start
---@param b math.vector|{ x: number, y: number, z: number }|{ [1]: number, [2]: number, [3]: number } Segment finish
---@return number dist Distance
---@return math.vector point Closest point on segment
function Collision.distance_point_to_segment(point, a, b)
	if type(point) ~= "table" or type(a) ~= "table" or type(b) ~= "table" then
		return error("Collision.distance_point_to_segment requires a point and two segment endpoints", 2)
	end

	local point_vec = to_vec(point)
	local closest = Collision.closest_point_on_segment(point_vec, to_vec(a), to_vec(b))
	return Vector.distance(point_vec, closest), closest
end

self.distance_point_to_segment = Collision.distance_point_to_segment

--- Get distance between point and ray
---@param point math.vector|{ x: number, y: number, z: number }|{ [1]: number, [2]: number, [3]: number } Point
---@param ray math.collision.ray
---@return number dist Distance
---@return math.vector point Closest point on ray
function Collision.distance_point_to_ray(point, ray)
	if type(point) ~= "table" or type(ray) ~= "table" then
		return error("Collision.distance_point_to_ray requires a point and ray", 2)
	end

	local point_vec = to_vec(point)
	local closest = Collision.closest_point_on_ray(point_vec, ray)
	return Vector.distance(point_vec, closest), closest
end

self.distance_point_to_ray = Collision.distance_point_to_ray

--- Get distance between two points
---@param a math.vector|{ x: number, y: number, z: number }|{ [1]: number, [2]: number, [3]: number } First point
---@param b math.vector|{ x: number, y: number, z: number }|{ [1]: number, [2]: number, [3]: number } Second point
---@return number dist Distance
function Collision.distance_point_to_point(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then
		return error("Collision.distance_point_to_point requires two points", 2)
	end

	return Vector.distance(to_vec(a), to_vec(b))
end

self.distance_point_to_point = Collision.distance_point_to_point

--- Test point vs point (equality within tolerance)
---@param a math.vector|{ x: number, y: number, z: number }|{ [1]: number, [2]: number, [3]: number } First point
---@param b math.vector|{ x: number, y: number, z: number }|{ [1]: number, [2]: number, [3]: number } Second point
---@param epsilon? number Tolerance (default: 1e-6)
---@return boolean equal True if points are within tolerance
function Collision.point_vs_point(a, b, epsilon)
	if type(a) ~= "table" or type(b) ~= "table" then
		return error("Collision.point_vs_point requires two points", 2)
	end

	epsilon = epsilon == nil and 1e-6 or tonumber(epsilon) or 1e-6
	return Vector.distance(to_vec(a), to_vec(b)) <= epsilon
end

self.point_vs_point = Collision.point_vs_point

--- Find closest point on AABB to a given point
---@param point math.vector|{ x: number, y: number, z: number }|{ [1]: number, [2]: number, [3]: number } Point to find closest point for
---@param aabb math.aabb
---@return math.vector point Closest point on AABB
function Collision.closest_point_on_aabb(point, aabb)
	if type(point) ~= "table" or not AABB.is(aabb) then
		return error("Collision.closest_point_on_aabb requires a point and AABB", 2)
	end

	local point_vec = to_vec(point)
	return Vector(
		math_max(aabb.min.x, math_min(point_vec[1], aabb.max.x)),
		math_max(aabb.min.y, math_min(point_vec[2], aabb.max.y)),
		math_max(aabb.min.z, math_min(point_vec[3], aabb.max.z))
	)
end

self.closest_point_on_aabb = Collision.closest_point_on_aabb

--- Find closest point on OBB to a given point
---@param point math.vector|{ x: number, y: number, z: number }|{ [1]: number, [2]: number, [3]: number } Point to find closest point for
---@param obb math.collision.obb
---@return math.vector point Closest point on OBB
function Collision.closest_point_on_obb(point, obb)
	if type(point) ~= "table" or not OBB.is(obb) then
		return error("Collision.closest_point_on_obb requires a point and OBB", 2)
	end

	local point_vec = to_vec(point)
	local inv = Matrix4x4.inverse(obb.orientation)
	local local_t = Matrix4x4.multiply_vector(inv, point_vec - obb.center)
	local local_p = Vector(local_t[1], local_t[2], local_t[3])
	local half = obb.half_extents
	local clamped = Vector(
		math_max(-half[1], math_min(local_p[1], half[1])),
		math_max(-half[2], math_min(local_p[2], half[2])),
		math_max(-half[3], math_min(local_p[3], half[3]))
	)
	local world_t = Matrix4x4.multiply_vector(obb.orientation, clamped)
	return Vector(world_t[1], world_t[2], world_t[3]) + obb.center
end

self.closest_point_on_obb = Collision.closest_point_on_obb

--- Find closest point on plane to a given point
---@param point math.vector|{ x: number, y: number, z: number }|{ [1]: number, [2]: number, [3]: number } Point to find closest point for
---@param plane math.collision.plane
---@return math.vector point Closest point on plane
function Collision.closest_point_on_plane(point, plane)
	if type(point) ~= "table" or type(plane) ~= "table" then
		return error("Collision.closest_point_on_plane requires a point and plane", 2)
	end

	return Collision.project_point_on_plane(point, plane)
end

self.closest_point_on_plane = Collision.closest_point_on_plane

--- Find closest point on sphere surface to a given point
---@param point math.vector|{ x: number, y: number, z: number }|{ [1]: number, [2]: number, [3]: number } Point to find closest point for
---@param sphere math.collision.sphere
---@return math.vector point Closest point on sphere surface
function Collision.closest_point_on_sphere(point, sphere)
	if type(point) ~= "table" or type(sphere) ~= "table" then
		return error("Collision.closest_point_on_sphere requires a point and sphere", 2)
	end

	local point_vec = to_vec(point)
	local diff = point_vec - sphere.center
	local distance = Vector.length(diff)
	if distance > 1e-9 then
		return sphere.center + (diff / distance) * sphere.radius
	end
	return sphere.center + Vector(1, 0, 0) * sphere.radius
end

self.closest_point_on_sphere = Collision.closest_point_on_sphere

--- Find closest point on ray to a given point
---@param point math.vector|{ x: number, y: number, z: number }|{ [1]: number, [2]: number, [3]: number } Point to find closest point for
---@param ray math.collision.ray
---@return math.vector point Closest point on ray
function Collision.closest_point_on_ray(point, ray)
	if type(point) ~= "table" or type(ray) ~= "table" then
		return error("Collision.closest_point_on_ray requires a point and ray", 2)
	end

	local point_vec = to_vec(point)
	local t = Vector.dot(point_vec - ray.origin, ray.direction)
	t = math_max(0, math_min(ray.max_distance or math.huge, t))
	return ray.origin + ray.direction * t
end

self.closest_point_on_ray = Collision.closest_point_on_ray

----------------------------------------------------------------------
-- Spatial Partitioning Helpers
----------------------------------------------------------------------

--- Simple 3D grid for spatial partitioning
---@class math.collision.grid
---@field cell_size number Size of each grid cell
---@field bounds math.aabb Grid boundaries
---@field cells table 3D array of cell contents
---@field cells_x integer Cell count along X
---@field cells_y integer Cell count along Y
---@field cells_z integer Cell count along Z

--- Create a 3D spatial grid
---@param cell_size? number Size of each grid cell (default: 1)
---@param bounds math.aabb Grid boundaries
---@return math.collision.grid
local function Grid_new(cell_size, bounds)
	cell_size = tonumber(cell_size) or 1
	if not AABB.is(bounds) then
		return error("Grid_new requires an AABB for bounds", 2)
	end

	-- Calculate grid dimensions
	local size = AABB.size(bounds)
	local cells_x = math_ceil(size.x / cell_size)
	local cells_y = math_ceil(size.y / cell_size)
	local cells_z = math_ceil(size.z / cell_size)

	-- Initialize empty 3D grid
	local cells = {}
	for x = 1, cells_x do
		cells[x] = {}
		for y = 1, cells_y do
			cells[x][y] = {}
			for z = 1, cells_z do
				cells[x][y][z] = {}
			end
		end
	end

	return {
		cell_size = cell_size,
		bounds = bounds,
		cells = cells,
		cells_x = cells_x,
		cells_y = cells_y,
		cells_z = cells_z
	}
end

self.grid = Grid_new

--- Convert world position to grid cell coordinates
---@param grid math.collision.grid
---@param position math.vector|{ x: number, y: number, z: number }|{ [1]: number, [2]: number, [3]: number } World position
---@return number? x Cell X coordinate
---@return number? y Cell Y coordinate
---@return number? z Cell Z coordinate
function Collision.world_to_cell(grid, position)
	if type(grid) ~= "table" or type(position) ~= "table" then
		return error("Collision.world_to_cell requires a grid and position", 2)
	end

	local pos_vec = Vector.is(position) and position or Vector(
		tonumber(position.x or position[1]) or 0,
		tonumber(position.y or position[2]) or 0,
		tonumber(position.z or position[3]) or 0
	)

	-- Check if position is within grid bounds
	if not AABB.contains_point(grid.bounds, pos_vec) then
		return nil, nil, nil
	end

	-- Calculate cell coordinates
	local local_pos = pos_vec - Vector(grid.bounds.min.x, grid.bounds.min.y, grid.bounds.min.z)
	local cell_x = math_floor(local_pos[1] / grid.cell_size) + 1
	local cell_y = math_floor(local_pos[2] / grid.cell_size) + 1
	local cell_z = math_floor(local_pos[3] / grid.cell_size) + 1

	-- Clamp to valid range
	cell_x = math_max(1, math_min(grid.cells_x, cell_x))
	cell_y = math_max(1, math_min(grid.cells_y, cell_y))
	cell_z = math_max(1, math_min(grid.cells_z, cell_z))

	return cell_x, cell_y, cell_z
end

self.world_to_cell = Collision.world_to_cell

--- Get objects in cells that intersect with a given AABB
---@param grid math.collision.grid
---@param aabb math.aabb Query region
---@return table array Array of objects in intersecting cells
function Collision.get_objects_in_aabb(grid, aabb)
	if type(grid) ~= "table" or not AABB.is(aabb) then
		return error("Collision.get_objects_in_aabb requires a grid and AABB", 2)
	end

	local objects = {}
	local processed = {}

	-- Get cell range for AABB
	local min_cell_x, min_cell_y, min_cell_z = Collision.world_to_cell(grid, aabb.min)
	local max_cell_x, max_cell_y, max_cell_z = Collision.world_to_cell(grid, aabb.max)

	-- Check all cells in range
	for x = (min_cell_x or 1), (max_cell_x or grid.cells_x) do
		for y = (min_cell_y or 1), (max_cell_y or grid.cells_y) do
			for z = (min_cell_z or 1), (max_cell_z or grid.cells_z) do
				local cell = grid.cells[x][y][z]
				for i = 1, #cell do
					local obj = cell[i]
					if not processed[obj] then
						processed[obj] = true
						objects[#objects + 1] = obj
					end
				end
			end
		end
	end

	return objects
end

self.get_objects_in_aabb = Collision.get_objects_in_aabb

--- Insert an object into the grid
---@param grid math.collision.grid
---@param object any Object to insert
---@param aabb math.aabb Object's bounding box
function Collision.insert_into_grid(grid, object, aabb)
	if type(grid) ~= "table" or not AABB.is(aabb) then
		return error("Collision.insert_into_grid requires a grid, object, and AABB", 2)
	end

	-- Get cells that intersect with object's AABB
	local min_cell_x, min_cell_y, min_cell_z = Collision.world_to_cell(grid, aabb.min)
	local max_cell_x, max_cell_y, max_cell_z = Collision.world_to_cell(grid, aabb.max)

	-- Insert object into all intersecting cells
	for x = (min_cell_x or 1), (max_cell_x or grid.cells_x) do
		for y = (min_cell_y or 1), (max_cell_y or grid.cells_y) do
			for z = (min_cell_z or 1), (max_cell_z or grid.cells_z) do
				local cell = grid.cells[x][y][z]
				cell[#cell + 1] = object
			end
		end
	end
end

self.insert_into_grid = Collision.insert_into_grid

--- Remove an object from the grid
---@param grid math.collision.grid
---@param object any Object to remove
function Collision.remove_from_grid(grid, object)
	if type(grid) ~= "table" then
		return error("Collision.remove_from_grid requires a grid and object", 2)
	end

	-- Search all cells and remove the object
	for x = 1, grid.cells_x do
		for y = 1, grid.cells_y do
			for z = 1, grid.cells_z do
				local cell = grid.cells[x][y][z]
				for i = #cell, 1, -1 do
					if cell[i] == object then
						table.remove(cell, i)
					end
				end
			end
		end
	end
end

self.remove_from_grid = Collision.remove_from_grid

----------------------------------------------------------------------
-- Broad Phase Collision Detection
----------------------------------------------------------------------

--- Simple broad-phase collision detection using spatial hashing
---@class math.collision.spatial_hash
---@field cell_size number Size of each hash cell
---@field table table Hash table of cell contents

--- Create a spatial hash for broad-phase collision detection
---@param cell_size? number Size of each hash cell (default: 1)
---@return math.collision.spatial_hash
local function SpatialHash_new(cell_size)
	return {
		cell_size = tonumber(cell_size) or 1,
		table = {}
	}
end

self.spatial_hash = SpatialHash_new

--- Hash a position to a cell key
---@param hash math.collision.spatial_hash
---@param position math.vector|{ x: number, y: number, z: number }|{ [1]: number, [2]: number, [3]: number } Position to hash
---@return string key Cell key
function Collision.hash_position(hash, position)
	if type(hash) ~= "table" or type(position) ~= "table" then
		return error("Collision.hash_position requires a hash and position", 2)
	end

	local pos_vec = Vector.is(position) and position or Vector(
		tonumber(position.x or position[1]) or 0,
		tonumber(position.y or position[2]) or 0,
		tonumber(position.z or position[3]) or 0
	)

	local cell_x = math_floor(pos_vec[1] / hash.cell_size)
	local cell_y = math_floor(pos_vec[2] / hash.cell_size)
	local cell_z = math_floor(pos_vec[3] / hash.cell_size)

	return string_format("%d,%d,%d", cell_x, cell_y, cell_z)
end

self.hash_position = Collision.hash_position

--- Insert an object into the spatial hash
---@param hash math.collision.spatial_hash
---@param object any Object to insert
---@param position math.vector|{ x: number, y: number, z: number }|{ [1]: number, [2]: number, [3]: number } Object's position
function Collision.insert_into_hash(hash, object, position)
	if type(hash) ~= "table" or type(position) ~= "table" then
		return error("Collision.insert_into_hash requires a hash, object, and position", 2)
	end

	local key = Collision.hash_position(hash, position)
	local cell = hash.table[key]
	if not cell then
		cell = {}
		hash.table[key] = cell
	end
	cell[#cell + 1] = object
end

self.insert_into_hash = Collision.insert_into_hash

--- Query for potential collisions near a position
---@param hash math.collision.spatial_hash
---@param position math.vector|{ x: number, y: number, z: number }|{ [1]: number, [2]: number, [3]: number } Query position
---@param radius? number Query radius (default: 0)
---@return table array Array of potentially colliding objects
function Collision.query_hash(hash, position, radius)
	if type(hash) ~= "table" or type(position) ~= "table" then
		return error("Collision.query_hash requires a hash and position", 2)
	end

	radius = tonumber(radius) or 0
	local objects = {}
	local processed = {}

	-- Calculate cell range based on radius
	local pos_vec = Vector.is(position) and position or Vector(
		tonumber(position.x or position[1]) or 0,
		tonumber(position.y or position[2]) or 0,
		tonumber(position.z or position[3]) or 0
	)

	local cell_radius = math_ceil(radius / hash.cell_size)
	local center_x = math_floor(pos_vec[1] / hash.cell_size)
	local center_y = math_floor(pos_vec[2] / hash.cell_size)
	local center_z = math_floor(pos_vec[3] / hash.cell_size)

	-- Check all cells in range
	for dx = -cell_radius, cell_radius do
		for dy = -cell_radius, cell_radius do
			for dz = -cell_radius, cell_radius do
				local key = string_format("%d,%d,%d", center_x + dx, center_y + dy, center_z + dz)
				local cell = hash.table[key]
				if cell then
					for i = 1, #cell do
						local obj = cell[i]
						if not processed[obj] then
							processed[obj] = true
							objects[#objects + 1] = obj
						end
					end
				end
			end
		end
	end

	return objects
end

self.query_hash = Collision.query_hash

-- Export module
return setmetatable(self, {
	__call = function(_)
		return Collision
	end
})
