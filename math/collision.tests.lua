-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Collision utilities test suite
-- Demonstrates usage of the collision detection functions

-- Import required modules
local Collision = require "collision"
local Vector = require "vector"
local AABB = require "aabb"
local Matrix4x4 = require "matrix4x4"

local CollisionTest = {}

-- Helper function to print test results
local function print_test_result(test_name, result, expected)
	local status = result == expected and "PASS" or "FAIL"
	print(string.format("[%s] %s: %s", status, test_name, tostring(result)))
end

-- Test ray casting functions
function CollisionTest.test_ray_collisions()
	print("\n=== Ray Collision Tests ===")

	-- Test ray vs AABB
	local ray = Collision.ray(Vector(0, 0, -5), Vector(0, 0, 1), 10)
	local aabb = AABB(Vector(-1, -1, -1), Vector(1, 1, 1))
	local distance, point = Collision.ray_vs_aabb(ray, aabb)
	print_test_result("Ray vs AABB", distance ~= nil, true)
	if distance then
		print(string.format("  Distance: %.3f, Point: (%.3f, %.3f, %.3f)", distance, point.x, point.y, point.z))
	end

	-- Test ray vs Sphere
	local sphere = Collision.sphere(Vector(0, 0, 0), 2)
	local distance2, point2 = Collision.ray_vs_sphere(ray, sphere)
	print_test_result("Ray vs Sphere", distance2 ~= nil, true)
	if distance2 then
		print(string.format("  Distance: %.3f, Point: (%.3f, %.3f, %.3f)", distance2, point2.x, point2.y, point2.z))
	end

	-- Test ray vs Plane
	local plane = Collision.plane_from_point_normal(Vector(0, 0, 0), Vector(0, 0, 1))
	local distance3, point3 = Collision.ray_vs_plane(ray, plane)
	print_test_result("Ray vs Plane", distance3 ~= nil, true)
	if distance3 then
		print(string.format("  Distance: %.3f, Point: (%.3f, %.3f, %.3f)", distance3, point3.x, point3.y, point3.z))
	end

	-- Test ray vs Triangle
	local triangle = Collision.triangle(Vector(-1, -1, 0), Vector(1, -1, 0), Vector(0, 1, 0))
	local distance4, point4 = Collision.ray_vs_triangle(ray, triangle)
	print_test_result("Ray vs Triangle", distance4 ~= nil, true)
	if distance4 then
		print(string.format("  Distance: %.3f, Point: (%.3f, %.3f, %.3f)", distance4, point4.x, point4.y, point4.z))
	end

	-- Test ray vs OBB
	local obb = Collision.obb(Vector(0, 0, 0), Vector(1, 1, 1), Matrix4x4.identity)
	local distance5, point5 = Collision.ray_vs_obb(ray, obb)
	print_test_result("Ray vs OBB", distance5 ~= nil, true)
	if distance5 then
		print(string.format("  Distance: %.3f, Point: (%.3f, %.3f, %.3f)", distance5, point5.x, point5.y, point5.z))
	end
end

-- Test sphere collision functions
function CollisionTest.test_sphere_collisions()
	print("\n=== Sphere Collision Tests ===")

	local sphere1 = Collision.sphere(Vector(0, 0, 0), 2)
	local sphere2 = Collision.sphere(Vector(3, 0, 0), 2)
	local sphere3 = Collision.sphere(Vector(10, 0, 0), 2)

	-- Test sphere vs sphere (intersecting)
	local intersecting, penetration, separation = Collision.sphere_vs_sphere(sphere1, sphere2)
	print_test_result("Sphere vs Sphere (intersecting)", intersecting, true)
	if intersecting then
		print(string.format("  Penetration: %.3f, Separation: (%.3f, %.3f, %.3f)",
			penetration, separation.x, separation.y, separation.z))
	end

	-- Test sphere vs sphere (non-intersecting)
	local intersecting2 = Collision.sphere_vs_sphere(sphere1, sphere3)
	print_test_result("Sphere vs Sphere (non-intersecting)", intersecting2, false)

	-- Test sphere vs AABB
	local aabb = AABB(Vector(-1, -1, -1), Vector(1, 1, 1))
	local intersecting3 = Collision.sphere_vs_aabb(sphere1, aabb)
	print_test_result("Sphere vs AABB", intersecting3, true)

	-- Test sphere vs Plane
	local plane = Collision.plane_from_point_normal(Vector(0, 0, 0), Vector(0, 1, 0))
	local intersecting4 = Collision.sphere_vs_plane(sphere1, plane)
	print_test_result("Sphere vs Plane", intersecting4, true)

	-- Test sphere vs Triangle
	local triangle = Collision.triangle(Vector(-1, 0, -1), Vector(1, 0, -1), Vector(0, 0, 1))
	local intersecting5 = Collision.sphere_vs_triangle(sphere1, triangle)
	print_test_result("Sphere vs Triangle", intersecting5, true)
end

-- Test plane collision functions
function CollisionTest.test_plane_collisions()
	print("\n=== Plane Collision Tests ===")

	local plane = Collision.plane_from_point_normal(Vector(0, 0, 0), Vector(0, 1, 0))

	-- Test point vs plane
	local point1 = Vector(0, 5, 0)
	local point2 = Vector(0, -3, 0)
	local point3 = Vector(0, 0, 0)

	local distance1 = Collision.point_vs_plane(point1, plane)
	local distance2 = Collision.point_vs_plane(point2, plane)
	local distance3 = Collision.point_vs_plane(point3, plane)

	print_test_result("Point vs Plane (above)", distance1 > 0, true)
	print_test_result("Point vs Plane (below)", distance2 < 0, true)
	print_test_result("Point vs Plane (on)", math.abs(distance3) < 1e-6, true)

	print(string.format("  Distances: %.3f, %.3f, %.3f", distance1, distance2, distance3))

	-- Test point on plane
	local on_plane = Collision.point_on_plane(point3, plane)
	print_test_result("Point on Plane", on_plane, true)

	-- Test project point on plane
	local projected = Collision.project_point_on_plane(point1, plane)
	print_test_result("Project Point on Plane", math.abs(projected.y) < 1e-6, true)
	print(string.format("  Projected: (%.3f, %.3f, %.3f)", projected.x, projected.y, projected.z))
end

-- Test triangle collision functions
function CollisionTest.test_triangle_collisions()
	print("\n=== Triangle Collision Tests ===")

	local triangle = Collision.triangle(Vector(0, 0, 0), Vector(1, 0, 0), Vector(0.5, 1, 0))

	-- Test triangle normal
	local normal = Collision.triangle_normal(triangle)
	print_test_result("Triangle Normal", math.abs(normal.z + 1) < 1e-6, true)
	print(string.format("  Normal: (%.3f, %.3f, %.3f)", normal.x, normal.y, normal.z))

	-- Test triangle area
	local area = Collision.triangle_area(triangle)
	print_test_result("Triangle Area", math.abs(area - 0.5) < 1e-6, true)
	print(string.format("  Area: %.3f", area))

	-- Test closest point on triangle
	local point1 = Vector(0.5, 0.5, 0) -- Inside triangle
	local point2 = Vector(2, 0, 0) -- Outside triangle

	local closest1 = Collision.closest_point_on_triangle(point1, triangle)
	local closest2 = Collision.closest_point_on_triangle(point2, triangle)

	print_test_result("Closest Point (inside)", Vector.distance(point1, closest1) < 1e-6, true)
	print_test_result("Closest Point (outside)", Vector.distance(closest2, Vector(1, 0, 0)) < 1e-6, true)
end

-- Test OBB collision functions
function CollisionTest.test_obb_collisions()
	print("\n=== OBB Collision Tests ===")

	-- Create OBBs
	local obb1 = Collision.obb(Vector(0, 0, 0), Vector(1, 1, 1), Matrix4x4.identity)
	local obb2 = Collision.obb(Vector(1.5, 0, 0), Vector(1, 1, 1), Matrix4x4.identity)
	local obb3 = Collision.obb(Vector(3, 0, 0), Vector(1, 1, 1), Matrix4x4.identity)

	-- Test OBB vs point
	local point_inside = Vector(0, 0, 0)
	local point_outside = Vector(2, 2, 2)

	local inside = Collision.obb_vs_point(obb1, point_inside)
	local outside = Collision.obb_vs_point(obb1, point_outside)

	print_test_result("OBB vs Point (inside)", inside, true)
	print_test_result("OBB vs Point (outside)", outside, false)

	-- Test OBB vs OBB
	local intersecting1 = Collision.obb_vs_obb(obb1, obb2) -- Should intersect
	local intersecting2 = Collision.obb_vs_obb(obb1, obb3) -- Should not intersect

	print_test_result("OBB vs OBB (intersecting)", intersecting1, true)
	print_test_result("OBB vs OBB (non-intersecting)", intersecting2, false)
end

-- Test distance functions
function CollisionTest.test_distance_functions()
	print("\n=== Distance Function Tests ===")

	local point = Vector(2, 2, 2)
	local aabb = AABB(Vector(0, 0, 0), Vector(1, 1, 1))
	local sphere = Collision.sphere(Vector(0, 0, 0), 1)
	local plane = Collision.plane_from_point_normal(Vector(0, 0, 0), Vector(0, 1, 0))

	-- Test distance to AABB
	local dist_aabb, closest_aabb = Collision.distance_point_to_aabb(point, aabb)
	print_test_result("Distance to AABB", dist_aabb > 0, true)
	print(string.format("  Distance: %.3f, Closest: (%.3f, %.3f, %.3f)",
		dist_aabb, closest_aabb.x, closest_aabb.y, closest_aabb.z))

	-- Test distance to sphere
	local dist_sphere, closest_sphere = Collision.distance_point_to_sphere(point, sphere)
	print_test_result("Distance to Sphere", dist_sphere > 0, true)
	print(string.format("  Distance: %.3f, Closest: (%.3f, %.3f, %.3f)",
		dist_sphere, closest_sphere.x, closest_sphere.y, closest_sphere.z))

	-- Test distance to plane
	local dist_plane, closest_plane = Collision.distance_point_to_plane(point, plane)
	print_test_result("Distance to Plane", dist_plane > 0, true)
	print(string.format("  Distance: %.3f, Closest: (%.3f, %.3f, %.3f)",
		dist_plane, closest_plane.x, closest_plane.y, closest_plane.z))
end

-- Test spatial partitioning
function CollisionTest.test_spatial_partitioning()
	print("\n=== Spatial Partitioning Tests ===")

	-- Test 3D Grid
	local bounds = AABB(Vector(-10, -10, -10), Vector(10, 10, 10))
	local grid = Collision.grid(2, bounds)

	-- Insert some objects
	local obj1 = { id = 1, name = "Object1" }
	local obj2 = { id = 2, name = "Object2" }
	local obj3 = { id = 3, name = "Object3" }

	Collision.insert_into_grid(grid, obj1, AABB(Vector(-1, -1, -1), Vector(1, 1, 1)))
	Collision.insert_into_grid(grid, obj2, AABB(Vector(2, 2, 2), Vector(4, 4, 4)))
	Collision.insert_into_grid(grid, obj3, AABB(Vector(5, 5, 5), Vector(7, 7, 7)))

	-- Query objects in region
	local query_region = AABB(Vector(0, 0, 0), Vector(3, 3, 3))
	local objects = Collision.get_objects_in_aabb(grid, query_region)

	print_test_result("Grid Query", #objects >= 2, true)
	print(string.format("  Found %d objects in query region", #objects))

	-- Test Spatial Hash
	local hash = Collision.spatial_hash(2)
	Collision.insert_into_hash(hash, obj1, Vector(0, 0, 0))
	Collision.insert_into_hash(hash, obj2, Vector(1, 1, 1))
	Collision.insert_into_hash(hash, obj3, Vector(5, 5, 5))

	-- Query near position
	local nearby = Collision.query_hash(hash, Vector(0, 0, 0), 3)
	print_test_result("Spatial Hash Query", #nearby >= 2, true)
	print(string.format("  Found %d objects near query position", #nearby))
end

-- Performance benchmark
function CollisionTest.benchmark_performance()
	print("\n=== Performance Benchmark ===")

	local iterations = 10000
	local start_time = os.clock()

	-- Benchmark ray vs AABB
	local ray = Collision.ray(Vector(0, 0, -5), Vector(0, 0, 1), 10)
	local aabb = AABB(Vector(-1, -1, -1), Vector(1, 1, 1))

	for i = 1, iterations do
		Collision.ray_vs_aabb(ray, aabb)
	end

	local ray_aabb_time = os.clock() - start_time

	-- Benchmark sphere vs sphere
	start_time = os.clock()
	local sphere1 = Collision.sphere(Vector(0, 0, 0), 2)
	local sphere2 = Collision.sphere(Vector(1, 0, 0), 2)

	for i = 1, iterations do
		Collision.sphere_vs_sphere(sphere1, sphere2)
	end

	local sphere_sphere_time = os.clock() - start_time

	-- Benchmark OBB vs OBB
	start_time = os.clock()
	local obb1 = Collision.obb(Vector(0, 0, 0), Vector(1, 1, 1), Matrix4x4.identity)
	local obb2 = Collision.obb(Vector(1, 0, 0), Vector(1, 1, 1), Matrix4x4.identity)

	for i = 1, iterations do
		Collision.obb_vs_obb(obb1, obb2)
	end

	local obb_obb_time = os.clock() - start_time

	print(string.format("Ray vs AABB:      %.6f seconds (%.0f ops/sec)", ray_aabb_time, iterations / ray_aabb_time))
	print(string.format("Sphere vs Sphere: %.6f seconds (%.0f ops/sec)", sphere_sphere_time, iterations / sphere_sphere_time))
	print(string.format("OBB vs OBB:       %.6f seconds (%.0f ops/sec)", obb_obb_time, iterations / obb_obb_time))
end

-- Run all tests
function CollisionTest.run_all()
	print("=== Collision Utilities Test Suite ===")
	print("Testing comprehensive collision detection functionality...")

	CollisionTest.test_ray_collisions()
	CollisionTest.test_sphere_collisions()
	CollisionTest.test_plane_collisions()
	CollisionTest.test_triangle_collisions()
	CollisionTest.test_obb_collisions()
	CollisionTest.test_distance_functions()
	CollisionTest.test_spatial_partitioning()
	CollisionTest.benchmark_performance()

	print("\n=== Test Suite Complete ===")
end

-- Example usage demonstration
function CollisionTest.example_usage()
	print("\n=== Example Usage ===")

	-- Example 1: Ray casting for picking
	print("Example 1: Ray Casting for Object Picking")
	local camera_pos = Vector(0, 0, -10)
	local mouse_dir = Vector(0, 0, 1) -- Normalized direction
	local pick_ray = Collision.ray(camera_pos, mouse_dir, 100)

	local object_aabb = AABB(Vector(-2, -2, -2), Vector(2, 2, 2))
	local distance, hit_point = Collision.ray_vs_aabb(pick_ray, object_aabb)

	if distance then
		print(string.format("  Object hit at distance %.3f, point (%.3f, %.3f, %.3f)",
			distance, hit_point.x, hit_point.y, hit_point.z))
	else
		print("  No object hit")
	end

	-- Example 2: Sphere collision for physics
	print("\nExample 2: Sphere Collision for Physics")
	local player_sphere = Collision.sphere(Vector(0, 0, 0), 1)
	local obstacle_sphere = Collision.sphere(Vector(1.5, 0, 0), 1)

	local colliding, penetration, normal = Collision.sphere_vs_sphere(player_sphere, obstacle_sphere)

	if colliding then
		print(string.format("  Collision detected! Penetration: %.3f", penetration))
		print(string.format("  Separation normal: (%.3f, %.3f, %.3f)", normal.x, normal.y, normal.z))
		-- Apply separation: player_sphere.center += normal * penetration
	else
		print("  No collision")
	end

	-- Example 3: Spatial partitioning for optimization
	print("\nExample 3: Spatial Partitioning for Optimization")
	local world_bounds = AABB(Vector(-50, -50, -50), Vector(50, 50, 50))
	local spatial_grid = Collision.grid(5, world_bounds)

	-- Insert many objects
	for i = 1, 100 do
		local pos = Vector(
			math.random(-40, 40),
			math.random(-40, 40),
			math.random(-40, 40)
		)
		local size = Vector(2, 2, 2)
		local obj_aabb = AABB(pos - size, pos + size)
		local obj = { id = i, position = pos }
		Collision.insert_into_grid(spatial_grid, obj, obj_aabb)
	end

	-- Query for nearby objects
	local query_pos = Vector(0, 0, 0)
	local query_radius = 10
	local nearby_objects = Collision.get_objects_in_aabb(spatial_grid,
		AABB(query_pos - Vector(query_radius, query_radius, query_radius),
			 query_pos + Vector(query_radius, query_radius, query_radius)))

	print(string.format("  Found %d objects near position (%.1f, %.1f, %.1f)",
		#nearby_objects, query_pos.x, query_pos.y, query_pos.z))

	print("\n=== Examples Complete ===")
end

return CollisionTest
