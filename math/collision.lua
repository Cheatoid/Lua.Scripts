-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Comprehensive collision detection utilities for 3D space
-- Built on top of the existing math library (Vector, Matrix4x4, AABB, etc.)

-- Features:
-- Ray casting and intersection tests
-- Sphere collision detection
-- Plane collision utilities
-- Oriented Bounding Box (OBB) collision detection
-- Triangle collision detection
-- Spatial partitioning helpers
-- Distance queries and closest point calculations

-- Collision Functions:
-- Ray vs AABB, Sphere, Plane, Triangle, OBB
-- Sphere vs AABB, Sphere, Plane, Triangle, OBB
-- AABB vs AABB, Sphere, Plane, Triangle, OBB
-- Plane vs Point, Ray, Sphere, AABB, Triangle
-- Triangle vs Point, Ray, Sphere, AABB, Triangle
-- OBB vs Point, Ray, Sphere, AABB, Triangle, OBB

-- Localized global functions for better performance
local error, getmetatable, rawget, rawset, setmetatable, tonumber, tostring, type =
	error, getmetatable, rawget, rawset, setmetatable, tonumber, tostring, type
local math_abs, math_acos, math_asin, math_atan2, math_ceil, math_cos, math_floor, math_max, math_min, math_random, math_sin, math_sqrt, math_tan =
	math.abs, math.acos, math.asin, math.atan2, math.ceil, math.cos, math.floor, math.max, math.min, math.random,
	math.sin, math.sqrt, math.tan
local math_pi = math.pi
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
-- Ray Collision Functions
----------------------------------------------------------------------

--- Create a new ray
---@param origin math.vector|table Ray origin {x, y, z}
---@param direction math.vector|table Ray direction {x, y, z}
---@param max_distance? number Maximum distance, defaults to infinity
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
---@return math.vector|nil Intersection point, nil if no intersection
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
	elseif max_dist >= 0 then
		return 0, origin
	else
		return nil, nil
	end
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
---@param normal math.vector|table Plane normal (should be normalized)
---@param distance number Distance from origin along normal
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
---@param point math.vector|table Point on the plane
---@param normal math.vector|table Plane normal
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
---@param a math.vector|table First vertex
---@param b math.vector|table Second vertex
---@param c math.vector|table Third vertex
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

----------------------------------------------------------------------
-- Sphere Collision Functions
----------------------------------------------------------------------

--- Create a sphere
---@param center math.vector|table Sphere center
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
		math_max(aabb.min.x, math_min(center.x, aabb.max.x)),
		math_max(aabb.min.y, math_min(center.y, aabb.max.y)),
		math_max(aabb.min.z, math_min(center.z, aabb.max.z))
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

----------------------------------------------------------------------
-- Plane Collision Functions
----------------------------------------------------------------------

--- Test point vs plane
---@param point math.vector|table Point to test
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
---@param point math.vector|table Point to test
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
---@param point math.vector|table Point to project
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
---@param point math.vector|table Point to find closest point for
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

----------------------------------------------------------------------
-- Oriented Bounding Box (OBB) Functions
----------------------------------------------------------------------

--- Create an OBB
---@param center math.vector|table OBB center
---@param half_extents math.vector|table Half-extents along local axes
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
---@param point math.vector|table Point to test
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
---@return boolean test True if intersecting
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
	for _, axis in ipairs(test_axes) do
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

----------------------------------------------------------------------
-- Distance and Closest Point Utilities
----------------------------------------------------------------------

--- Get distance between point and AABB
---@param point math.vector|table Point
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
		math_max(aabb.min.x, math_min(point_vec.x, aabb.max.x)),
		math_max(aabb.min.y, math_min(point_vec.y, aabb.max.y)),
		math_max(aabb.min.z, math_min(point_vec.z, aabb.max.z))
	)

	-- Calculate distance
	local diff = point_vec - closest
	local distance = Vector.length(diff)

	return distance, closest
end

self.distance_point_to_aabb = Collision.distance_point_to_aabb

--- Get distance between point and sphere
---@param point math.vector|table Point
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
---@param point math.vector|table Point
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

----------------------------------------------------------------------
-- Spatial Partitioning Helpers
----------------------------------------------------------------------

--- Simple 3D grid for spatial partitioning
---@class math.collision.grid
---@field cell_size number Size of each grid cell
---@field bounds math.aabb Grid boundaries
---@field cells table 3D array of cell contents

--- Create a 3D spatial grid
---@param cell_size number Size of each grid cell
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
---@param position math.vector|table World position
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
	local cell_x = math_floor(local_pos.x / grid.cell_size) + 1
	local cell_y = math_floor(local_pos.y / grid.cell_size) + 1
	local cell_z = math_floor(local_pos.z / grid.cell_size) + 1

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
---@param cell_size number Size of each hash cell
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
---@param position math.vector|table Position to hash
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

	local cell_x = math_floor(pos_vec.x / hash.cell_size)
	local cell_y = math_floor(pos_vec.y / hash.cell_size)
	local cell_z = math_floor(pos_vec.z / hash.cell_size)

	return string_format("%d,%d,%d", cell_x, cell_y, cell_z)
end

self.hash_position = Collision.hash_position

--- Insert an object into the spatial hash
---@param hash math.collision.spatial_hash
---@param object any Object to insert
---@param position math.vector|table Object's position
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
---@param position math.vector|table Query position
---@param radius number Query radius
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
	local center_x = math_floor(pos_vec.x / hash.cell_size)
	local center_y = math_floor(pos_vec.y / hash.cell_size)
	local center_z = math_floor(pos_vec.z / hash.cell_size)

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
	__call = function(_, ...)
		return Collision
	end
})
