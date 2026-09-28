-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for plane.lua.
-- Run from this directory:
--   lua plane.lua
--   luajit plane.lua

-- Bootstrap: make requires work from tests/ subdir with plain lua/luajit.
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
local Plane = require "plane"
local Vector = require "vector"

local pass_count = 0
local fail_count = 0

local function check(name, cond)
	if cond then
		pass_count = pass_count + 1
		print(string.format("[PASS] %s", name))
	else
		fail_count = fail_count + 1
		print(string.format("[FAIL] %s", name))
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

local function mkray(ox, oy, oz, dx, dy, dz, maxd)
	local dir = Vector(dx, dy, dz)
	local len = Vector.length(dir)
	if len > 0 then
		dir = dir / len
	end
	return { origin = Vector(ox, oy, oz), direction = dir, max_distance = maxd or math.huge }
end

local function mksphere(cx, cy, cz, r)
	return { center = Vector(cx, cy, cz), radius = r }
end

print("=== Plane constructor ===")

do
	local p = Plane.new(Vector(0, 1, 0), 0)
	check("new up zero", near(p[1], 0) and near(p[2], 1) and near(p[3], 0) and near(p[4], 0))
	check("new is plane", Plane.is(p) == true)
	check("callable shorthand", (function()
		local q = Plane(Vector(0, 1, 0), 0)
		return Plane.is(q) and near(q[2], 1)
	end)())
	check("new normalizes non-unit", (function()
		local q = Plane.new(Vector(0, 2, 0), 0)
		return near(q[1], 0) and near(q[2], 1) and near(q[3], 0)
	end)())
	check("new plain named normal", (function()
		local q = Plane.new({ x = 0, y = 0, z = 5 }, 2)
		return near(q[3], 1) and near(q[4], 2)
	end)())
	check("new indexed normal", (function()
		local q = Plane.new({ 0, 0, 10 }, -3)
		return near(q[3], 1) and near(q[4], -3)
	end)())
	check("new degenerate defaults up", (function()
		local q = Plane.new(Vector(0, 0, 0), 5)
		return near(q[1], 0) and near(q[2], 1) and near(q[3], 0) and near(q[4], 5)
	end)())
	check("new zero plain defaults up", (function()
		local q = Plane.new({ x = 0, y = 0, z = 0 }, 0)
		return near(q[2], 1)
	end)())
	check("new nil distance zero", (function()
		local q = Plane.new(Vector(0, 1, 0), nil)
		return q[4] == 0
	end)())
	check("new string distance coerced", (function()
		local q = Plane.new(Vector(0, 1, 0), "2.5")
		return near(q[4], 2.5)
	end)())
	check("new bad distance zero", (function()
		local q = Plane.new(Vector(0, 1, 0), "abc")
		return q[4] == 0
	end)())
	check("new negative distance", near(Plane.new(Vector(0, 1, 0), -7)[4], -7))
	check("new large distance", near(Plane.new(Vector(0, 1, 0), 1e9)[4], 1e9))
	check("is rejects plain", Plane.is({}) == false)
	check("is rejects nil", Plane.is(nil) == false)
	check("is rejects number", Plane.is(5) == false)
end

print("=== Plane index / newindex ===")

do
	local p = Plane.new(Vector(0, 1, 0), 3)
	check("index 1", near(p[1], 0))
	check("index 2", near(p[2], 1))
	check("index 3", near(p[3], 0))
	check("index 4", near(p[4], 3))
	check("index distance", near(p.distance, 3))
	check("index normal vector", vec_near(p.normal, Vector(0, 1, 0)))
	check("index normal components", near(p.normal[1], 0) and near(p.normal[2], 1))
	check("method fallback clone", p.clone == Plane.clone)
	check("unknown key nil", p.nonexistent == nil)
	p[1] = 0.5
	check("newindex 1", near(p[1], 0.5))
	p[2] = 0
	check("newindex 2", near(p[2], 0))
	p[3] = 1
	check("newindex 3", near(p[3], 1))
	p[4] = 9
	check("newindex 4", near(p[4], 9))
	p.distance = 4
	check("newindex distance", near(p[4], 4))
	p.distance = "2"
	check("newindex distance string", near(p[4], 2))
	p.distance = nil
	check("newindex distance nil zero", p[4] == 0)
	p.normal = Vector(0, 0, 5)
	check("newindex normal normalized", near(p[1], 0) and near(p[2], 0) and near(p[3], 1))
	p.normal = { x = 0, y = 4, z = 0 }
	check("newindex normal plain", near(p[2], 1))
	p.normal = { 10, 0, 0 }
	check("newindex normal indexed", near(p[1], 1) and near(p[2], 0))
	p.normal = Vector(0, 0, 0)
	check("newindex normal degenerate up", near(p[1], 0) and near(p[2], 1) and near(p[3], 0))
	check("newindex bad key errors", pcall(function() p.foo = 1 end) == false)
	check("newindex bad key direct", pcall(getmetatable(Plane.new(Vector(0, 1, 0), 0)).__newindex, Plane.new(Vector(0, 1, 0), 0), "bad", 1) == false)
end

print("=== Plane eq / tostring / clone ===")

do
	local a = Plane.new(Vector(0, 1, 0), 0)
	local b = Plane.new(Vector(0, 1, 0), 0)
	local mt_eq = getmetatable(a).__eq
	check("eq true", a == b)
	check("eq false distance", (a == Plane.new(Vector(0, 1, 0), 1)) == false)
	check("eq false normal", (a == Plane.new(Vector(1, 0, 0), 0)) == false)
	check("eq vs plain false", (a == {}) == false)
	check("eq vs nil false", (a == nil) == false)
	check("eq direct non-plane false", mt_eq(a, {}) == false)
	check("eq direct both non-plane false", mt_eq({}, {}) == false)
	local s = tostring(a)
	check("tostring contains Plane", string.find(s, "Plane", 1, true) ~= nil)
	check("tostring contains distance", string.find(s, "distance", 1, true) ~= nil)
	check("tostring exact", s == "Plane(normal: (0, 1, 0), distance: 0)")
	check("tostring offset", string.find(tostring(Plane.new(Vector(1, 0, 0), 5)), "5", 1, true) ~= nil)
	local c = Plane.clone(a)
	check("clone equal", c == a)
	check("clone not rawequal", rawequal(c, a) == false)
	check("clone normal match", near(c[2], 1) and near(c[4], 0))
	c.distance = 9
	check("clone independent", near(a[4], 0) and near(c[4], 9))
	check("clone errors", pcall(Plane.clone, {}) == false)
	check("clone errors nil", pcall(Plane.clone, nil) == false)
end

print("=== Plane from_point_normal / from_three_points ===")

do
	local p = Plane.from_point_normal(Vector(0, 0, 0), Vector(0, 1, 0))
	check("fpn origin distance 0", near(p[4], 0) and near(p[2], 1))
	local p2 = Plane.from_point_normal(Vector(0, 5, 0), Vector(0, 1, 0))
	check("fpn height distance -5", near(p2[4], -5))
	check("fpn point on plane dist 0", near(Plane.distance_to_point(p2, Vector(0, 5, 0)), 0))
	check("fpn non-unit normal", (function()
		local q = Plane.from_point_normal(Vector(0, 0, 0), Vector(0, 4, 0))
		return near(q[2], 1) and near(q[4], 0)
	end)())
	check("fpn degenerate normal up", (function()
		local q = Plane.from_point_normal(Vector(1, 2, 3), Vector(0, 0, 0))
		return near(q[2], 1)
	end)())
	check("fpn plain tables", (function()
		local q = Plane.from_point_normal({ x = 0, y = 5, z = 0 }, { x = 0, y = 1, z = 0 })
		return near(q[4], -5)
	end)())
	check("fpn indexed tables", (function()
		local q = Plane.from_point_normal({ 0, 5, 0 }, { 0, 1, 0 })
		return near(q[4], -5)
	end)())
	check("fpn errors nil point", pcall(Plane.from_point_normal, nil, Vector(0, 1, 0)) == false)
	check("fpn errors nil normal", pcall(Plane.from_point_normal, Vector(0, 0, 0), nil) == false)
	local t = Plane.from_three_points(Vector(0, 0, 0), Vector(1, 0, 0), Vector(0, 1, 0))
	check("ftp normal z", near(math.abs(t[3]), 1))
	check("ftp distance 0", near(t[4], 0))
	check("ftp points on plane", near(Plane.distance_to_point(t, Vector(0, 0, 0)), 0) and near(Plane.distance_to_point(t, Vector(1, 0, 0)), 0))
	check("ftp plain tables", (function()
		local q = Plane.from_three_points({ x = 0, y = 0, z = 0 }, { x = 1, y = 0, z = 0 }, { x = 0, y = 1, z = 0 })
		return near(math.abs(q[3]), 1)
	end)())
	check("ftp degenerate collinear up", (function()
		local q = Plane.from_three_points(Vector(0, 0, 0), Vector(1, 1, 1), Vector(2, 2, 2))
		return near(q[1], 0) and near(q[2], 1) and near(q[3], 0)
	end)())
	check("ftp duplicate points up", (function()
		local q = Plane.from_three_points(Vector(1, 1, 1), Vector(1, 1, 1), Vector(1, 1, 1))
		return near(q[2], 1)
	end)())
	check("ftp errors nil", pcall(Plane.from_three_points, nil, Vector(1, 0, 0), Vector(0, 1, 0)) == false)
end

print("=== Plane normalize / distance / project ===")

do
	local p = Plane.new(Vector(0, 1, 0), 0)
	local n = Plane.normalize(p)
	check("normalize unit same", near(n[2], 1) and near(n[4], 0))
	check("normalize errors bad", pcall(Plane.normalize, {}) == false)
	check("normalize scaled via newindex", (function()
		local q = Plane.new(Vector(0, 1, 0), 4)
		q[1] = 0
		q[2] = 2
		q[3] = 0
		q[4] = 8
		local nn = Plane.normalize(q)
		return near(nn[2], 1) and near(nn[4], 4)
	end)())
	check("normalize degenerate up", (function()
		local q = Plane.new(Vector(0, 1, 0), 0)
		q[1] = 0
		q[2] = 0
		q[3] = 0
		local nn = Plane.normalize(q)
		return near(nn[2], 1) and nn[4] == 0
	end)())
	check("distance above 5", near(Plane.distance_to_point(p, Vector(0, 5, 0)), 5))
	check("distance below -3", near(Plane.distance_to_point(p, Vector(0, -3, 0)), -3))
	check("distance on 0", near(Plane.distance_to_point(p, Vector(0, 0, 0)), 0))
	check("distance plain table", near(Plane.distance_to_point(p, { x = 0, y = 2, z = 0 }), 2))
	check("distance indexed", near(Plane.distance_to_point(p, { 0, 2, 0 }), 2))
	check("distance preserves tangential", near(Plane.distance_to_point(Plane.new(Vector(1, 0, 0), 0), Vector(5, 9, -2)), 5))
	check("distance negative plane", near(Plane.distance_to_point(Plane.new(Vector(0, 1, 0), 5), Vector(0, 0, 0)), 5))
	check("distance errors bad plane", pcall(Plane.distance_to_point, {}, Vector(0, 0, 0)) == false)
	check("distance errors nil point", pcall(Plane.distance_to_point, p, nil) == false)
	local proj = Plane.project_point(p, Vector(2, 5, 3))
	check("project onto y0", vec_near(proj, Vector(2, 0, 3)))
	check("project preserves xz", near(proj[1], 2) and near(proj[3], 3))
	check("project on plane same", vec_near(Plane.project_point(p, Vector(1, 0, 1)), Vector(1, 0, 1)))
	check("project plain table", vec_near(Plane.project_point(p, { x = 0, y = 4, z = 0 }), Vector(0, 0, 0)))
	check("project below", vec_near(Plane.project_point(p, Vector(0, -3, 0)), Vector(0, 0, 0)))
	check("project errors bad plane", pcall(Plane.project_point, {}, Vector(0, 0, 0)) == false)
	check("project errors nil point", pcall(Plane.project_point, p, nil) == false)
end

print("=== Plane intersects_ray / intersects_sphere ===")

do
	local p = Plane.new(Vector(0, 1, 0), 0)
	local d, pt = Plane.intersects_ray(p, mkray(0, -5, 0, 0, 1, 0, 100))
	check("ray hit non-nil", d ~= nil and pt ~= nil)
	check("ray hit distance 5", d ~= nil and near(d, 5))
	check("ray hit point origin", pt ~= nil and vec_near(pt, Vector(0, 0, 0)))
	check("ray parallel nil", Plane.intersects_ray(p, mkray(0, 1, 0, 1, 0, 0, 100)) == nil)
	check("ray parallel returns two nils", (function()
		local a, b = Plane.intersects_ray(p, mkray(0, 1, 0, 1, 0, 0, 100))
		return a == nil and b == nil
	end)())
	check("ray pointing away nil", Plane.intersects_ray(p, mkray(0, 5, 0, 0, 1, 0, 100)) == nil)
	check("ray behind nil", Plane.intersects_ray(p, mkray(0, 5, 0, 0, -1, 0, 1)) == nil)
	check("ray beyond max nil", Plane.intersects_ray(p, mkray(0, -5, 0, 0, 1, 0, 2)) == nil)
	check("ray exact max hits", Plane.intersects_ray(p, mkray(0, -5, 0, 0, 1, 0, 5)) ~= nil)
	check("ray from plane zero", (function()
		local dd = Plane.intersects_ray(p, mkray(0, 0, 0, 0, 1, 0, 10))
		return dd ~= nil and near(dd, 0)
	end)())
	check("ray negative side hits", (function()
		local dd = Plane.intersects_ray(p, mkray(0, 5, 0, 0, -1, 0, 100))
		return dd ~= nil and near(dd, 5)
	end)())
	check("ray errors bad plane", pcall(Plane.intersects_ray, {}, mkray(0, 0, 0, 0, 1, 0, 5)) == false)
	check("ray errors nil ray", pcall(Plane.intersects_ray, p, nil) == false)
	check("ray errors number ray", pcall(Plane.intersects_ray, p, 5) == false)
	local hit, depth = Plane.intersects_sphere(p, mksphere(0, 0, 0, 2))
	check("sphere centered hits", hit == true)
	check("sphere centered depth 2", near(depth, 2))
	local hit2 = Plane.intersects_sphere(p, mksphere(0, 5, 0, 1))
	check("sphere far misses", hit2 == false)
	check("sphere touching hits", Plane.intersects_sphere(p, mksphere(0, 1, 0, 1)) == true)
	check("sphere touching depth 0", (function()
		local h, dd = Plane.intersects_sphere(p, mksphere(0, 1, 0, 1))
		return h == true and near(dd, 0)
	end)())
	check("sphere just off misses", Plane.intersects_sphere(p, mksphere(0, 1.5, 0, 1)) == false)
	check("sphere below hits", Plane.intersects_sphere(p, mksphere(0, -0.5, 0, 1)) == true)
	check("sphere errors bad plane", pcall(Plane.intersects_sphere, {}, mksphere(0, 0, 0, 1)) == false)
	check("sphere errors nil sphere", pcall(Plane.intersects_sphere, p, nil) == false)
end

print("=== Plane point_on_plane / is_near / tables ===")

do
	local p = Plane.new(Vector(0, 1, 0), 0)
	check("point_on true", Plane.point_on_plane(p, Vector(0, 0, 0)) == true)
	check("point_on false", Plane.point_on_plane(p, Vector(0, 5, 0)) == false)
	check("point_on custom eps true", Plane.point_on_plane(p, Vector(0, 0.05, 0), 0.1) == true)
	check("point_on custom eps false", Plane.point_on_plane(p, Vector(0, 0.5, 0), 0.1) == false)
	check("point_on plain table", Plane.point_on_plane(p, { x = 1, y = 0, z = 2 }) == true)
	check("point_on indexed", Plane.point_on_plane(p, { 1, 0, 2 }) == true)
	check("point_on errors bad plane", pcall(Plane.point_on_plane, {}, Vector(0, 0, 0)) == false)
	local a = Plane.new(Vector(0, 1, 0), 0)
	local b = Plane.new(Vector(0, 1, 0), 0)
	check("is_near identical true", Plane.is_near(a, b) == true)
	check("is_near tiny true", Plane.is_near(a, Plane.new(Vector(0, 1, 0), 1e-7)) == true)
	check("is_near big false", Plane.is_near(a, Plane.new(Vector(0, 1, 0), 0.01)) == false)
	check("is_near custom true", Plane.is_near(a, Plane.new(Vector(0, 1, 0), 0.05), 0.1) == true)
	check("is_near custom false", Plane.is_near(a, Plane.new(Vector(0, 1, 0), 0.05), 0.01) == false)
	check("is_near normal diff false", Plane.is_near(a, Plane.new(Vector(1, 0, 0), 0)) == false)
	check("is_near errors", pcall(Plane.is_near, a, {}) == false)
	check("is_near errors nil", pcall(Plane.is_near, nil, nil) == false)
	local t = Plane.to_table(a)
	check("to_table distance", near(t.distance, 0))
	check("to_table normal", vec_near(t.normal, Vector(0, 1, 0)))
	check("to_table errors", pcall(Plane.to_table, {}) == false)
	check("from_table roundtrip", (function()
		local q = Plane.from_table(Plane.to_table(a))
		return Plane.is_near(q, a)
	end)())
	check("from_table explicit", (function()
		local q = Plane.from_table({ normal = Vector(1, 0, 0), distance = 5 })
		return near(q[1], 1) and near(q[4], 5)
	end)())
	check("from_table defaults", (function()
		local q = Plane.from_table({})
		return near(q[2], 1) and q[4] == 0
	end)())
	check("from_table only distance", (function()
		local q = Plane.from_table({ distance = 3 })
		return near(q[2], 1) and near(q[4], 3)
	end)())
	check("from_table errors nil", pcall(Plane.from_table, nil) == false)
	check("from_table errors number", pcall(Plane.from_table, 5) == false)
	check("boundary zero distance", Plane.new(Vector(0, 1, 0), 0)[4] == 0)
	check("boundary negative normal", (function()
		local q = Plane.new(Vector(0, -1, 0), 0)
		return near(q[2], -1)
	end)())
	check("boundary large", near(Plane.new(Vector(0, 1, 0), 1e9)[4], 1e9))
end

print(string.format("\nTests finished: %d passed, %d failed", pass_count, fail_count))
assert(fail_count == 0, string.format("%d plane test(s) failed", fail_count))
if arg and arg[0] and arg[0]:match("plane%.lua$") then
	os.exit(fail_count > 0 and 1 or 0)
end
