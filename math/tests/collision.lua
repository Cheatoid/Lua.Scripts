-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Collision utilities test suite
-- Covers every public Collision API, including the Line segment functions.
-- Run from this directory:
--   lua collision.lua
--   luajit collision.lua

-- Bootstrap: make parent-relative requires work with plain lua/luajit.
do
	local src = debug.getinfo(1, "S").source
	local dir = src:match("^@(.+/)[^/]+$") or "./"
	local function isfile(p)
		local f = io.open(p, "r")
		if f then
			f:close()
			return true
		end
		return false
	end
	local root
	for _, c in ipairs({ dir, dir .. "../", dir .. "../..//", dir .. "../../..//", "./", "../", "../../" }) do
		if isfile(c .. "standalone/bits.lua") then
			root = c
			break
		end
	end
	root = root or dir .. "../"
	if package then
		package.path = dir ..
			"../?.lua;" ..
			dir ..
			"../?/init.lua;" ..
			dir ..
			"?.lua;" ..
			dir ..
			"?/init.lua;" ..
			root ..
			"?.lua;" ..
			root ..
			"?/init.lua;" ..
			root ..
			"standalone/?.lua;" ..
			root ..
			"math/?.lua;" ..
			root ..
			"collections/?.lua;" ..
			root ..
			"benchmark/?.lua;" ..
			root ..
			"timer/?.lua;" ..
			root ..
			"autocompleter/?.lua;" ..
			root ..
			"permission/?.lua;" ..
			root ..
			"chat_commander/?.lua;" ..
			root .. "vm/?.lua;" .. root .. "require_finder/?.lua;" .. root .. "inventory/?.lua;" .. package.path
	end
	local searchers = package.searchers or package.loaders
	if searchers then
		table.insert(searchers, 2, function(mod)
			if mod:sub(1, 3) == "../" or mod:sub(1, 2) == "./" then
				local clean = mod:gsub("^%./", ""):gsub("^%.%.%/", ""):gsub("^%.%.%/", "")
				local tries = { dir .. "../" .. clean .. ".lua", dir .. "../" .. clean .. "/init.lua", root ..
				clean .. ".lua", root .. clean .. "/init.lua" }
				for _, f in ipairs(tries) do
					if isfile(f) then
						local chunk, err = loadfile(f)
						if chunk then return chunk, f end
					end
				end
			end
			return nil
		end)
	end
end

-- Import dependencies
local Collision = require "collision"
local Vector = require "vector"
local AABB = require "aabb"
local Matrix4x4 = require "matrix4x4"

local CollisionTest = {}

-- Assert harness: counts passes/failures so every API is exercised
-- even if one check fails. run_all() errors when failures > 0.
local pass_count = 0
local fail_count = 0

local function check(test_name, cond)
	if cond then
		pass_count = pass_count + 1
		print(string.format("[PASS] %s", test_name))
	else
		fail_count = fail_count + 1
		print(string.format("[FAIL] %s", test_name))
	end
end

local function near(a, b, eps)
	eps = eps or 1e-6
	return math.abs(a - b) <= eps
end

local function vec_near(a, b, eps)
	eps = eps or 1e-6
	return Vector.distance(a, b) <= eps
end

-- Keep the old helper name working for backwards compatibility.
local function print_test_result(test_name, result, expected)
	check(test_name, result == expected)
end

-- Test constructors and their defaults
function CollisionTest.test_constructors()
	print("\n=== Constructor Tests ===")

	-- Ray constructor
	local ray = Collision.ray(Vector(0, 0, -5), Vector(0, 0, 1), 10)
	check("Ray origin", vec_near(ray.origin, Vector(0, 0, -5)))
	check("Ray direction normalized", vec_near(ray.direction, Vector(0, 0, 1)))
	check("Ray max_distance", ray.max_distance == 10)

	local ray_default = Collision.ray(Vector(0, 0, 0), Vector(1, 0, 0))
	check("Ray default max_distance is inf", ray_default.max_distance == math.huge)

	local ray_tbl = Collision.ray({ x = 0, y = 0, z = -5 }, { [1] = 0, [2] = 0, [3] = 1 }, 10)
	check("Ray accepts plain tables", vec_near(ray_tbl.origin, Vector(0, 0, -5)))

	-- Plane constructors
	local plane = Collision.plane(Vector(0, 2, 0), 5)
	check("Plane normal normalized", vec_near(plane.normal, Vector(0, 1, 0)))
	check("Plane distance stored", plane.distance == 5)

	local plane2 = Collision.plane_from_point_normal(Vector(0, 0, 0), Vector(0, 1, 0))
	check("Plane from point/normal", vec_near(plane2.normal, Vector(0, 1, 0)) and near(plane2.distance, 0))

	-- Triangle constructor
	local tri = Collision.triangle(Vector(0, 0, 0), Vector(1, 0, 0), Vector(0, 1, 0))
	check("Triangle vertices", vec_near(tri.a, Vector(0, 0, 0)) and vec_near(tri.b, Vector(1, 0, 0)))

	-- Sphere constructor
	local sphere_default = Collision.sphere(Vector(1, 2, 3))
	check("Sphere default radius", sphere_default.radius == 1)
	local sphere = Collision.sphere(Vector(0, 0, 0), 2)
	check("Sphere explicit radius", sphere.radius == 2)

	-- OBB constructor
	local obb = Collision.obb(Vector(0, 0, 0), Vector(1, 1, 1), Matrix4x4.identity)
	check("OBB center", vec_near(obb.center, Vector(0, 0, 0)))
	check("OBB default orientation", obb.orientation ~= nil)

	-- Grid / spatial hash constructors
	local grid = Collision.grid(2, AABB(Vector(-10, -10, -10), Vector(10, 10, 10)))
	check("Grid dimensions", grid.cells_x == 10 and grid.cells_y == 10 and grid.cells_z == 10)
	local hash = Collision.spatial_hash(2)
	check("Spatial hash constructor", hash.cell_size == 2 and type(hash.table) == "table")
end

-- Test ray casting functions
function CollisionTest.test_ray_collisions()
	print("\n=== Ray Collision Tests ===")

	-- Test ray vs AABB
	local ray = Collision.ray(Vector(0, 0, -5), Vector(0, 0, 1), 10)
	local aabb = AABB(Vector(-1, -1, -1), Vector(1, 1, 1))
	local distance, point = Collision.ray_vs_aabb(ray, aabb)
	print_test_result("Ray vs AABB", distance ~= nil, true)
	check("Ray vs AABB distance", distance ~= nil and near(distance, 4, 1e-5))
	check("Ray vs AABB point", point ~= nil and vec_near(point, Vector(0, 0, -1), 1e-5))
	check("Ray vs AABB miss", Collision.ray_vs_aabb(Collision.ray(Vector(5, 5, -5), Vector(0, 0, 1), 10), aabb) == nil)
	check("Ray vs AABB inside starts at 0", (function()
		local d = Collision.ray_vs_aabb(Collision.ray(Vector(0, 0, 0), Vector(0, 0, 1), 10), aabb)
		return d == 0
	end)())
	check("Ray vs AABB beyond max misses", Collision.ray_vs_aabb(Collision.ray(Vector(0, 0, -5), Vector(0, 0, 1), 2), aabb) == nil)
	check("Ray vs AABB errors on bad args", pcall(Collision.ray_vs_aabb, nil, aabb) == false)

	-- Test ray vs Sphere
	local sphere = Collision.sphere(Vector(0, 0, 0), 2)
	local distance2, point2 = Collision.ray_vs_sphere(ray, sphere)
	print_test_result("Ray vs Sphere", distance2 ~= nil, true)
	check("Ray vs Sphere distance", distance2 ~= nil and near(distance2, 3, 1e-5))
	check("Ray vs Sphere point", point2 ~= nil and vec_near(point2, Vector(0, 0, -2), 1e-5))
	check("Ray vs Sphere miss", Collision.ray_vs_sphere(Collision.ray(Vector(0, 0, -5), Vector(0, 1, 0), 10), sphere) == nil)
	check("Ray inside sphere exits", (function()
		local d = Collision.ray_vs_sphere(Collision.ray(Vector(0, 0, 0), Vector(0, 0, 1), 10), sphere)
		return d ~= nil and near(d, 2, 1e-5)
	end)())
	check("Ray vs Sphere errors on bad args", pcall(Collision.ray_vs_sphere, nil, sphere) == false)

	-- Test ray vs Plane
	local plane = Collision.plane_from_point_normal(Vector(0, 0, 0), Vector(0, 0, 1))
	local distance3, point3 = Collision.ray_vs_plane(ray, plane)
	print_test_result("Ray vs Plane", distance3 ~= nil, true)
	check("Ray vs Plane distance", distance3 ~= nil and near(distance3, 5))
	check("Ray vs Plane point", point3 ~= nil and vec_near(point3, Vector(0, 0, 0)))
	check("Ray vs Plane parallel misses", Collision.ray_vs_plane(Collision.ray(Vector(0, 1, 0), Vector(1, 0, 0), 10), plane) == nil)
	check("Ray vs Plane pointing away misses", Collision.ray_vs_plane(Collision.ray(Vector(0, 0, 1), Vector(0, 0, 1), 10), plane) == nil)
	check("Ray vs Plane errors on bad args", pcall(Collision.ray_vs_plane, nil, plane) == false)

	-- Test ray vs Triangle
	local triangle = Collision.triangle(Vector(-1, -1, 0), Vector(1, -1, 0), Vector(0, 1, 0))
	local distance4, point4 = Collision.ray_vs_triangle(ray, triangle)
	print_test_result("Ray vs Triangle", distance4 ~= nil, true)
	check("Ray vs Triangle distance", distance4 ~= nil and near(distance4, 5))
	check("Ray vs Triangle point", point4 ~= nil and vec_near(point4, Vector(0, 0, 0)))
	check("Ray vs Triangle miss", Collision.ray_vs_triangle(Collision.ray(Vector(5, 5, -5), Vector(0, 0, 1), 10), triangle) == nil)
	check("Ray vs Triangle errors on bad args", pcall(Collision.ray_vs_triangle, nil, triangle) == false)

	-- Test ray vs OBB
	local obb = Collision.obb(Vector(0, 0, 0), Vector(1, 1, 1), Matrix4x4.identity)
	local distance5, point5 = Collision.ray_vs_obb(ray, obb)
	print_test_result("Ray vs OBB", distance5 ~= nil, true)
	check("Ray vs OBB distance", distance5 ~= nil and near(distance5, 4, 1e-5))
	check("Ray vs OBB point", point5 ~= nil and vec_near(point5, Vector(0, 0, -1), 1e-5))
	check("Ray vs OBB miss", Collision.ray_vs_obb(Collision.ray(Vector(5, 5, -5), Vector(0, 0, 1), 10), obb) == nil)
	check("Ray vs OBB errors on bad args", pcall(Collision.ray_vs_obb, nil, obb) == false)
end

-- Test line constructors and helpers
function CollisionTest.test_line_helpers()
	print("\n=== Line Helper Tests ===")

	local line = Collision.line(Vector(0, 0, -5), Vector(0, 0, 5))
	check("Line length", near(Collision.line_length(line), 10))
	check("Line direction", vec_near(line.direction, Vector(0, 0, 1)))
	check("Line endpoints", vec_near(line.start, Vector(0, 0, -5)) and vec_near(line.finish, Vector(0, 0, 5)))

	local line_tbl = Collision.line({ x = 0, y = 0, z = 0 }, { [1] = 3, [2] = 4, [3] = 0 })
	check("Line accepts plain tables", near(line_tbl.length, 5))

	local degenerate = Collision.line(Vector(1, 1, 1), Vector(1, 1, 1))
	check("Degenerate line length 0", degenerate.length == 0)
	check("Degenerate line zero direction", vec_near(degenerate.direction, Vector(0, 0, 0)))

	check("is_line true", Collision.is_line(line) == true)
	check("is_line rejects plain table", Collision.is_line({}) == false)
	check("is_line rejects nil", Collision.is_line(nil) == false)

	local as_ray = Collision.line_to_ray(line)
	check("line_to_ray", vec_near(as_ray.origin, line.start) and near(as_ray.max_distance, 10))
	check("line_to_ray errors on bad line", pcall(Collision.line_to_ray, {}) == false)

	local from_ray = Collision.line_from_ray(Collision.ray(Vector(0, 0, 0), Vector(1, 0, 0), 5))
	check("line_from_ray length", near(from_ray.length, 5))
	local from_ray_override = Collision.line_from_ray(Collision.ray(Vector(0, 0, 0), Vector(1, 0, 0), 5), 2)
	check("line_from_ray explicit length", near(from_ray_override.length, 2))
	check("line_from_ray rejects infinite ray", pcall(Collision.line_from_ray, Collision.ray(Vector(0, 0, 0), Vector(1, 0, 0))) == false)
	check("line_from_ray errors on bad ray", pcall(Collision.line_from_ray, {}) == false)

	check("line_point_at middle", vec_near(Collision.line_point_at(line, 5), Vector(0, 0, 0)))
	check("line_point_at clamps low", vec_near(Collision.line_point_at(line, -5), Vector(0, 0, -5)))
	check("line_point_at clamps high", vec_near(Collision.line_point_at(line, 99), Vector(0, 0, 5)))
	check("line_point_at defaults to start", vec_near(Collision.line_point_at(line), Vector(0, 0, -5)))
	check("line_point_at errors on bad line", pcall(Collision.line_point_at, {}) == false)

	check("line_closest_point projects", vec_near(Collision.line_closest_point(line, Vector(5, 3, 2)), Vector(0, 0, 2)))
	check("line_closest_point clamps to start", vec_near(Collision.line_closest_point(line, Vector(0, 0, -99)), Vector(0, 0, -5)))
	check("line_closest_point errors on bad args", pcall(Collision.line_closest_point, {}, Vector(0, 0, 0)) == false)

	local dist, closest = Collision.distance_point_to_line(Vector(5, 0, 0), line)
	check("distance_point_to_line distance", near(dist, 5))
	check("distance_point_to_line closest", vec_near(closest, Vector(0, 0, 0)))
	local dist_on = Collision.distance_point_to_line(Vector(0, 0, 1), line)
	check("distance_point_to_line on line is 0", near(dist_on, 0))
	check("distance_point_to_line errors on bad args", pcall(Collision.distance_point_to_line, Vector(0, 0, 0), {}) == false)
end

-- Test line vs all shapes
function CollisionTest.test_line_collisions()
	print("\n=== Line vs Shape Tests ===")

	local line = Collision.line(Vector(0, 0, -5), Vector(0, 0, 5))
	local short = Collision.line(Vector(0, 0, -5), Vector(0, 0, -4))

	-- Line vs AABB
	local aabb = AABB(Vector(-1, -1, -1), Vector(1, 1, 1))
	local d_aabb, p_aabb = Collision.line_vs_aabb(line, aabb)
	check("Line vs AABB hit", d_aabb ~= nil and near(d_aabb, 4, 1e-5))
	check("Line vs AABB point", p_aabb ~= nil and vec_near(p_aabb, Vector(0, 0, -1), 1e-5))
	check("Line vs AABB too short misses", Collision.line_vs_aabb(short, aabb) == nil)
	check("Line vs AABB offset misses", Collision.line_vs_aabb(Collision.line(Vector(5, 5, -5), Vector(5, 5, 5)), aabb) == nil)
	check("Line vs AABB errors on bad args", pcall(Collision.line_vs_aabb, {}, aabb) == false)

	-- Line vs Sphere
	local sphere = Collision.sphere(Vector(0, 0, 0), 2)
	local d_sph, p_sph = Collision.line_vs_sphere(line, sphere)
	check("Line vs Sphere hit", d_sph ~= nil and near(d_sph, 3, 1e-5))
	check("Line vs Sphere point", p_sph ~= nil and vec_near(p_sph, Vector(0, 0, -2), 1e-5))
	check("Line vs Sphere too short misses", Collision.line_vs_sphere(short, sphere) == nil)
	check("Line vs Sphere errors on bad args", pcall(Collision.line_vs_sphere, {}, sphere) == false)

	-- Line vs Plane
	local plane = Collision.plane_from_point_normal(Vector(0, 0, 0), Vector(0, 0, 1))
	local d_plane, p_plane = Collision.line_vs_plane(line, plane)
	check("Line vs Plane hit", d_plane ~= nil and near(d_plane, 5))
	check("Line vs Plane point", p_plane ~= nil and vec_near(p_plane, Vector(0, 0, 0)))
	check("Line vs Plane fully above misses", Collision.line_vs_plane(Collision.line(Vector(0, 0, 1), Vector(0, 0, 5)), plane) == nil)
	check("Line vs Plane errors on bad args", pcall(Collision.line_vs_plane, {}, plane) == false)

	-- Line vs Triangle
	local triangle = Collision.triangle(Vector(-1, -1, 0), Vector(1, -1, 0), Vector(0, 1, 0))
	local d_tri, p_tri = Collision.line_vs_triangle(line, triangle)
	check("Line vs Triangle hit", d_tri ~= nil and near(d_tri, 5))
	check("Line vs Triangle point", p_tri ~= nil and vec_near(p_tri, Vector(0, 0, 0)))
	check("Line vs Triangle offset misses", Collision.line_vs_triangle(Collision.line(Vector(5, 5, -1), Vector(5, 5, 1)), triangle) == nil)
	check("Line vs Triangle errors on bad args", pcall(Collision.line_vs_triangle, {}, triangle) == false)

	-- Line vs OBB
	local obb = Collision.obb(Vector(0, 0, 0), Vector(1, 1, 1), Matrix4x4.identity)
	local d_obb, p_obb = Collision.line_vs_obb(line, obb)
	check("Line vs OBB hit", d_obb ~= nil and near(d_obb, 4, 1e-5))
	check("Line vs OBB point", p_obb ~= nil and vec_near(p_obb, Vector(0, 0, -1), 1e-5))
	check("Line vs OBB too short misses", Collision.line_vs_obb(short, obb) == nil)
	check("Line vs OBB errors on bad args", pcall(Collision.line_vs_obb, {}, obb) == false)

	-- Degenerate (zero-length) lines behave as points
	local deg_inside = Collision.line(Vector(0, 0, 0), Vector(0, 0, 0))
	local deg_outside = Collision.line(Vector(9, 9, 9), Vector(9, 9, 9))
	check("Degenerate line vs AABB inside", Collision.line_vs_aabb(deg_inside, aabb) == 0)
	check("Degenerate line vs AABB outside", Collision.line_vs_aabb(deg_outside, aabb) == nil)
	check("Degenerate line vs Sphere inside", Collision.line_vs_sphere(deg_inside, sphere) == 0)
	check("Degenerate line vs Sphere outside", Collision.line_vs_sphere(deg_outside, sphere) == nil)
	check("Degenerate line vs Plane on plane", Collision.line_vs_plane(deg_inside, plane) == 0)
	check("Degenerate line vs Plane off plane", Collision.line_vs_plane(deg_outside, plane) == nil)
	check("Degenerate line vs Triangle on", Collision.line_vs_triangle(deg_inside, triangle) == 0)
	check("Degenerate line vs Triangle off", Collision.line_vs_triangle(deg_outside, triangle) == nil)
	check("Degenerate line vs OBB inside", Collision.line_vs_obb(deg_inside, obb) == 0)
	check("Degenerate line vs OBB outside", Collision.line_vs_obb(deg_outside, obb) == nil)
end

-- Test line vs point/line/ray primitives
function CollisionTest.test_line_primitives()
	print("\n=== Line vs Primitive Tests ===")

	local line = Collision.line(Vector(0, 0, -5), Vector(0, 0, 5))

	-- Line vs Point
	local d_on, c_on = Collision.line_vs_point(line, Vector(0, 0, 0))
	check("Line vs Point on line", d_on ~= nil and near(d_on, 5))
	check("Line vs Point closest", c_on ~= nil and vec_near(c_on, Vector(0, 0, 0)))
	check("Line vs Point off line misses", Collision.line_vs_point(line, Vector(5, 0, 0)) == nil)
	check("Line vs Point custom epsilon hits", Collision.line_vs_point(line, Vector(0.01, 0, 0), 0.1) ~= nil)
	check("Line vs Point errors on bad args", pcall(Collision.line_vs_point, {}, Vector(0, 0, 0)) == false)

	-- Line vs Line
	local cross_d, cross_c1, cross_c2 = Collision.line_vs_line(
		Collision.line(Vector(-1, 0, 0), Vector(1, 0, 0)),
		Collision.line(Vector(0, -1, 0), Vector(0, 1, 0)))
	check("Line vs Line crossing distance 0", near(cross_d, 0))
	check("Line vs Line crossing points", vec_near(cross_c1, Vector(0, 0, 0)) and vec_near(cross_c2, Vector(0, 0, 0)))

	local par_d = Collision.line_vs_line(
		Collision.line(Vector(0, 0, 0), Vector(1, 0, 0)),
		Collision.line(Vector(0, 1, 0), Vector(1, 1, 0)))
	check("Line vs Line parallel distance 1", near(par_d, 1))

	local skew_d = Collision.line_vs_line(
		Collision.line(Vector(0, 0, 0), Vector(1, 0, 0)),
		Collision.line(Vector(0, 1, 1), Vector(1, 1, 1)))
	check("Line vs Line skew distance sqrt(2)", near(skew_d, math.sqrt(2)))

	local overlap_d = Collision.line_vs_line(
		Collision.line(Vector(0, 0, 0), Vector(2, 0, 0)),
		Collision.line(Vector(1, 0, 0), Vector(3, 0, 0)))
	check("Line vs Line overlap distance 0", near(overlap_d, 0))

	local gap_d, gap_c1, gap_c2 = Collision.line_vs_line(
		Collision.line(Vector(0, 0, 0), Vector(1, 0, 0)),
		Collision.line(Vector(2, 0, 0), Vector(3, 0, 0)))
	check("Line vs Line disjoint distance 1", near(gap_d, 1))
	check("Line vs Line disjoint endpoints", vec_near(gap_c1, Vector(1, 0, 0)) and vec_near(gap_c2, Vector(2, 0, 0)))

	local pt_d, pt_c1, pt_c2 = Collision.line_vs_line(
		Collision.line(Vector(0, 0, 0), Vector(0, 0, 0)),
		Collision.line(Vector(3, 4, 0), Vector(3, 4, 0)))
	check("Line vs Line point-point distance 5", near(pt_d, 5) and vec_near(pt_c1, Vector(0, 0, 0)) and vec_near(pt_c2, Vector(3, 4, 0)))
	check("Line vs Line errors on bad args", pcall(Collision.line_vs_line, {}, line) == false)

	-- Line vs Ray / Ray vs Line
	local lr_d, lr_lp, lr_rp = Collision.line_vs_ray(
		Collision.line(Vector(-1, 0, 0), Vector(1, 0, 0)),
		Collision.ray(Vector(0, -5, 0), Vector(0, 1, 0), 100))
	check("Line vs Ray crossing distance 0", near(lr_d, 0))
	check("Line vs Ray points meet", vec_near(lr_lp, Vector(0, 0, 0)) and vec_near(lr_rp, Vector(0, 0, 0)))

	local ahead_d = Collision.line_vs_ray(
		Collision.line(Vector(0, 0, 0), Vector(1, 0, 0)),
		Collision.ray(Vector(5, 0, 0), Vector(1, 0, 0)))
	check("Line vs Ray pointing away", near(ahead_d, 4))

	local towards_d = Collision.line_vs_ray(
		Collision.line(Vector(0, 0, 0), Vector(1, 0, 0)),
		Collision.ray(Vector(5, 0, 0), Vector(-1, 0, 0)))
	check("Line vs Ray pointing towards hits", near(towards_d, 0))

	local limited_d = Collision.line_vs_ray(
		Collision.line(Vector(0, 0, 0), Vector(1, 0, 0)),
		Collision.ray(Vector(5, 0, 0), Vector(-1, 0, 0), 2))
	check("Line vs Ray respects max_distance", near(limited_d, 2))
	check("Line vs Ray errors on bad args", pcall(Collision.line_vs_ray, {}, Collision.ray(Vector(0, 0, 0), Vector(1, 0, 0), 1)) == false)

	local rl_d, rl_rp, rl_lp = Collision.ray_vs_line(
		Collision.ray(Vector(0, 0, -5), Vector(0, 0, 1), 100),
		Collision.line(Vector(-1, 0, 0), Vector(1, 0, 0)))
	check("Ray vs Line distance", near(rl_d, 0))
	check("Ray vs Line point order", vec_near(rl_rp, Vector(0, 0, 0)) and vec_near(rl_lp, Vector(0, 0, 0)))
	check("Ray vs Line errors on bad args", pcall(Collision.ray_vs_line, {}, line) == false)
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
	check("Sphere vs Sphere penetration", intersecting and near(penetration, 1))
	check("Sphere vs Sphere separation", intersecting and vec_near(separation, Vector(1, 0, 0)))

	-- Test touching spheres still count as intersecting
	local touching = Collision.sphere_vs_sphere(Collision.sphere(Vector(0, 0, 0), 1), Collision.sphere(Vector(2, 0, 0), 1))
	check("Sphere vs Sphere touching", touching == true)

	-- Test sphere vs sphere (non-intersecting)
	local intersecting2 = Collision.sphere_vs_sphere(sphere1, sphere3)
	print_test_result("Sphere vs Sphere (non-intersecting)", intersecting2, false)
	check("Sphere vs Sphere errors on bad args", pcall(Collision.sphere_vs_sphere, nil, sphere1) == false)

	-- Test sphere vs AABB
	local aabb = AABB(Vector(-1, -1, -1), Vector(1, 1, 1))
	local intersecting3 = Collision.sphere_vs_aabb(sphere1, aabb)
	print_test_result("Sphere vs AABB", intersecting3, true)
	check("Sphere vs AABB outside", Collision.sphere_vs_aabb(Collision.sphere(Vector(5, 5, 5), 1), aabb) == false)
	check("Sphere vs AABB errors on bad args", pcall(Collision.sphere_vs_aabb, nil, aabb) == false)

	-- Test sphere vs Plane
	local plane = Collision.plane_from_point_normal(Vector(0, 0, 0), Vector(0, 1, 0))
	local intersecting4 = Collision.sphere_vs_plane(sphere1, plane)
	print_test_result("Sphere vs Plane", intersecting4, true)
	check("Sphere vs Plane outside", Collision.sphere_vs_plane(Collision.sphere(Vector(0, 5, 0), 1), plane) == false)
	check("Sphere vs Plane errors on bad args", pcall(Collision.sphere_vs_plane, nil, plane) == false)

	-- Test sphere vs Triangle
	local triangle = Collision.triangle(Vector(-1, 0, -1), Vector(1, 0, -1), Vector(0, 0, 1))
	local intersecting5 = Collision.sphere_vs_triangle(sphere1, triangle)
	print_test_result("Sphere vs Triangle", intersecting5, true)
	check("Sphere vs Triangle outside", Collision.sphere_vs_triangle(Collision.sphere(Vector(0, 0, 5), 0.5), triangle) == false)
	check("Sphere vs Triangle errors on bad args", pcall(Collision.sphere_vs_triangle, nil, triangle) == false)
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
	check("Point vs Plane values", near(distance1, 5) and near(distance2, -3) and near(distance3, 0))
	check("Point vs Plane errors on bad args", pcall(Collision.point_vs_plane, nil, plane) == false)

	print(string.format("  Distances: %.3f, %.3f, %.3f", distance1, distance2, distance3))

	-- Test point on plane
	local on_plane = Collision.point_on_plane(point3, plane)
	print_test_result("Point on Plane", on_plane, true)
	check("Point off plane", Collision.point_on_plane(point1, plane) == false)
	check("Point on plane custom epsilon", Collision.point_on_plane(Vector(0, 0.05, 0), plane, 0.1) == true)

	-- Test project point on plane
	local projected = Collision.project_point_on_plane(point1, plane)
	print_test_result("Project Point on Plane", math.abs(projected.y) < 1e-6, true)
	check("Project preserves tangential coords", near(projected.x, 0) and near(projected.z, 0))
	check("Project errors on bad args", pcall(Collision.project_point_on_plane, nil, plane) == false)
	print(string.format("  Projected: (%.3f, %.3f, %.3f)", projected.x, projected.y, projected.z))
end

-- Test triangle collision functions
function CollisionTest.test_triangle_collisions()
	print("\n=== Triangle Collision Tests ===")

	local triangle = Collision.triangle(Vector(0, 0, 0), Vector(1, 0, 0), Vector(0.5, 1, 0))

	-- Test triangle normal
	local normal = Collision.triangle_normal(triangle)
	print_test_result("Triangle Normal", math.abs(normal.z + 1) < 1e-6, true)
	check("Triangle normal unit length", near(Vector.length(normal), 1))
	check("Triangle normal errors on bad args", pcall(Collision.triangle_normal, nil) == false)
	print(string.format("  Normal: (%.3f, %.3f, %.3f)", normal.x, normal.y, normal.z))

	-- Test triangle area
	local area = Collision.triangle_area(triangle)
	print_test_result("Triangle Area", math.abs(area - 0.5) < 1e-6, true)
	check("Right triangle area", near(Collision.triangle_area(Collision.triangle(Vector(0, 0, 0), Vector(1, 0, 0), Vector(0, 1, 0))), 0.5))
	check("Triangle area errors on bad args", pcall(Collision.triangle_area, nil) == false)
	print(string.format("  Area: %.3f", area))

	-- Test closest point on triangle
	local point1 = Vector(0.5, 0.5, 0) -- Inside triangle
	local point2 = Vector(2, 0, 0)  -- Outside triangle

	local closest1 = Collision.closest_point_on_triangle(point1, triangle)
	local closest2 = Collision.closest_point_on_triangle(point2, triangle)

	print_test_result("Closest Point (inside)", Vector.distance(point1, closest1) < 1e-6, true)
	print_test_result("Closest Point (outside)", Vector.distance(closest2, Vector(1, 0, 0)) < 1e-6, true)
	check("Closest Point errors on bad args", pcall(Collision.closest_point_on_triangle, nil, triangle) == false)

	-- Test closest point on segment
	local mid = Collision.closest_point_on_segment(Vector(2, 5, 0), Vector(0, 0, 0), Vector(4, 0, 0))
	check("Closest on segment projects", vec_near(mid, Vector(2, 0, 0)))
	check("Closest on segment clamps to start", vec_near(Collision.closest_point_on_segment(Vector(0, 0, 0), Vector(1, 0, 0), Vector(3, 0, 0)), Vector(1, 0, 0)))
	check("Closest on segment clamps to finish", vec_near(Collision.closest_point_on_segment(Vector(10, 0, 0), Vector(1, 0, 0), Vector(3, 0, 0)), Vector(3, 0, 0)))
	check("Closest on degenerate segment", vec_near(Collision.closest_point_on_segment(Vector(0, 0, 0), Vector(7, 8, 9), Vector(7, 8, 9)), Vector(7, 8, 9)))
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
	check("OBB vs Point errors on bad args", pcall(Collision.obb_vs_point, {}, point_inside) == false)

	-- Test OBB vs OBB
	local intersecting1 = Collision.obb_vs_obb(obb1, obb2) -- Should intersect
	local intersecting2 = Collision.obb_vs_obb(obb1, obb3) -- Should not intersect

	print_test_result("OBB vs OBB (intersecting)", intersecting1, true)
	print_test_result("OBB vs OBB (non-intersecting)", intersecting2, false)
	check("OBB vs OBB errors on bad args", pcall(Collision.obb_vs_obb, {}, obb1) == false)

	-- Test projection helper
	local proj_min, proj_max = Collision.project_obb_onto_axis(obb1, Vector(1, 0, 0))
	check("Project OBB onto axis", near(proj_min, -1) and near(proj_max, 1))
	check("Project OBB errors on bad args", pcall(Collision.project_obb_onto_axis, {}, Vector(1, 0, 0)) == false)
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
	check("Distance to AABB value", near(dist_aabb, math.sqrt(3)))
	check("Distance to AABB closest", vec_near(closest_aabb, Vector(1, 1, 1)))
	local dist_inside = Collision.distance_point_to_aabb(Vector(0.5, 0.5, 0.5), aabb)
	check("Distance to AABB inside is 0", near(dist_inside, 0))
	check("Distance to AABB errors on bad args", pcall(Collision.distance_point_to_aabb, nil, aabb) == false)
	print(string.format("  Distance: %.3f, Closest: (%.3f, %.3f, %.3f)",
		dist_aabb, closest_aabb.x, closest_aabb.y, closest_aabb.z))

	-- Test distance to sphere
	local dist_sphere, closest_sphere = Collision.distance_point_to_sphere(point, sphere)
	print_test_result("Distance to Sphere", dist_sphere > 0, true)
	check("Distance to Sphere inside is 0", (function()
		local d = Collision.distance_point_to_sphere(Vector(0, 0, 0), sphere)
		return near(d, 0)
	end)())
	check("Distance to Sphere errors on bad args", pcall(Collision.distance_point_to_sphere, nil, sphere) == false)
	print(string.format("  Distance: %.3f, Closest: (%.3f, %.3f, %.3f)",
		dist_sphere, closest_sphere.x, closest_sphere.y, closest_sphere.z))

	-- Test distance to plane
	local dist_plane, closest_plane = Collision.distance_point_to_plane(point, plane)
	print_test_result("Distance to Plane", dist_plane > 0, true)
	check("Distance to Plane value", near(dist_plane, 2))
	check("Distance to Plane closest", vec_near(closest_plane, Vector(2, 0, 2)))
	check("Distance to Plane errors on bad args", pcall(Collision.distance_point_to_plane, nil, plane) == false)
	print(string.format("  Distance: %.3f, Closest: (%.3f, %.3f, %.3f)",
		dist_plane, closest_plane.x, closest_plane.y, closest_plane.z))

	-- Test distance to line
	local dist_line, closest_line = Collision.distance_point_to_line(Vector(5, 0, 0), Collision.line(Vector(0, 0, -5), Vector(0, 0, 5)))
	check("Distance to Line", near(dist_line, 5) and vec_near(closest_line, Vector(0, 0, 0)))
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

	-- Cell mapping
	local cx, cy, cz = Collision.world_to_cell(grid, Vector(0, 0, 0))
	check("World to cell center", cx == 6 and cy == 6 and cz == 6)
	check("World to cell outside returns nil", Collision.world_to_cell(grid, Vector(50, 50, 50)) == nil)
	check("World to cell errors on bad args", pcall(Collision.world_to_cell, nil, Vector(0, 0, 0)) == false)
	check("Grid errors on bad bounds", pcall(Collision.grid, 2, {}) == false)
	check("Insert into grid errors on bad args", pcall(Collision.insert_into_grid, grid, obj1, {}) == false)
	check("Get objects errors on bad args", pcall(Collision.get_objects_in_aabb, grid, {}) == false)

	-- Removal
	Collision.remove_from_grid(grid, obj1)
	Collision.remove_from_grid(grid, obj2)
	Collision.remove_from_grid(grid, obj3)
	check("Remove from grid empties query", #Collision.get_objects_in_aabb(grid, query_region) == 0)
	check("Remove from grid errors on bad args", pcall(Collision.remove_from_grid, nil, obj1) == false)

	-- Test Spatial Hash
	local hash = Collision.spatial_hash(2)
	Collision.insert_into_hash(hash, obj1, Vector(0, 0, 0))
	Collision.insert_into_hash(hash, obj2, Vector(1, 1, 1))
	Collision.insert_into_hash(hash, obj3, Vector(5, 5, 5))

	-- Query near position
	local nearby = Collision.query_hash(hash, Vector(0, 0, 0), 3)
	print_test_result("Spatial Hash Query", #nearby >= 2, true)
	print(string.format("  Found %d objects near query position", #nearby))

	check("Hash position format", Collision.hash_position(hash, Vector(3, 4, 5)) == "1,2,2")
	check("Hash position negative", Collision.hash_position(hash, Vector(-1, -1, -1)) == "-1,-1,-1")
	check("Hash query far away empty", #Collision.query_hash(hash, Vector(50, 50, 50), 1) == 0)
	check("Hash position errors on bad args", pcall(Collision.hash_position, nil, Vector(0, 0, 0)) == false)
	check("Insert into hash errors on bad args", pcall(Collision.insert_into_hash, nil, obj1, Vector(0, 0, 0)) == false)
	check("Query hash errors on bad args", pcall(Collision.query_hash, nil, Vector(0, 0, 0)) == false)
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
	print(string.format("Sphere vs Sphere: %.6f seconds (%.0f ops/sec)", sphere_sphere_time,
		iterations / sphere_sphere_time))
	print(string.format("OBB vs OBB:       %.6f seconds (%.0f ops/sec)", obb_obb_time, iterations / obb_obb_time))
end

-- Run all tests
function CollisionTest.run_all()
	print("=== Collision Utilities Test Suite ===")
	print("Testing comprehensive collision detection functionality...")
	pass_count = 0
	fail_count = 0

	CollisionTest.test_constructors()
	CollisionTest.test_ray_collisions()
	CollisionTest.test_line_helpers()
	CollisionTest.test_line_collisions()
	CollisionTest.test_line_primitives()
	CollisionTest.test_sphere_collisions()
	CollisionTest.test_plane_collisions()
	CollisionTest.test_triangle_collisions()
	CollisionTest.test_obb_collisions()
	CollisionTest.test_distance_functions()
	CollisionTest.test_spatial_partitioning()
	CollisionTest.benchmark_performance()

	print(string.format("\n=== Test Suite Complete: %d passed, %d failed ===", pass_count, fail_count))
	assert(fail_count == 0, string.format("%d collision test(s) failed", fail_count))
	print("All tests passed")
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

if arg and arg[0] and arg[0]:match("collision%.lua$") then
	CollisionTest.run_all()
end

return CollisionTest
