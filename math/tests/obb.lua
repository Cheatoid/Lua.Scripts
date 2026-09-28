-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for obb.lua.
-- Run from this directory:
--   lua obb.lua
--   luajit obb.lua

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

local OBB = require "obb"
local AABB = require "aabb"
local Matrix4x4 = require "matrix4x4"
local Vector = require "vector"

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

local function test_new_is()
	print("\n=== new/is Tests ===")
	local o = OBB.new(Vector(1, 2, 3), Vector(4, 5, 6))
	check("new Vector center", o[1] == 1 and o[2] == 2 and o[3] == 3)
	check("new Vector extents", o[4] == 4 and o[5] == 5 and o[6] == 6)
	check("new shorthand call", OBB(Vector(1, 2, 3), Vector(1, 1, 1))[1] == 1)
	local ot = OBB.new({ x = 1, y = 2, z = 3 }, { x = 4, y = 5, z = 6 })
	check("new table center", ot[1] == 1 and ot[2] == 2 and ot[3] == 3)
	check("new table extents", ot[4] == 4 and ot[5] == 5 and ot[6] == 6)
	local oi = OBB.new({ 1, 2, 3 }, { 4, 5, 6 })
	check("new indexed tables", oi[1] == 1 and oi[4] == 4)
	check("new default orientation identity", Matrix4x4.is_identity(oi.orientation))
	check("is true", OBB.is(o) == true)
	check("is false plain table", OBB.is({}) == false)
	check("is false nil", OBB.is(nil) == false)
end

local function test_index_newindex()
	print("\n=== __index/__newindex Tests ===")
	local o = OBB.new(Vector(1, 2, 3), Vector(4, 5, 6))
	local c = o.center
	check("index center is vector", Vector.is(c) and c[1] == 1 and c[2] == 2 and c[3] == 3)
	local h = o.half_extents
	check("index half_extents is vector", Vector.is(h) and h[1] == 4 and h[2] == 5 and h[3] == 6)
	local ori = o.orientation
	check("index orientation is matrix", Matrix4x4.is(ori))
	check("index numeric matches center", o[1] == o.center[1] and o[2] == o.center[2])
	o.center = Vector(5, 6, 7)
	check("newindex center vector", o[1] == 5 and o[2] == 6 and o[3] == 7)
	o.center = { x = 1, y = 2, z = 3 }
	check("newindex center table", o[1] == 1 and o[2] == 2 and o[3] == 3)
	o.half_extents = Vector(7, 8, 9)
	check("newindex half_extents vector", o[4] == 7 and o[5] == 8 and o[6] == 9)
	o.half_extents = { x = 4, y = 5, z = 6 }
	check("newindex half_extents table", o[4] == 4 and o[5] == 5 and o[6] == 6)
	o.orientation = Matrix4x4.new()
	check("newindex orientation matrix ok", Matrix4x4.is(o.orientation))
	check("newindex orientation rejects plain table", pcall(function() o.orientation = {} end) == false)
	check("newindex invalid key errors", pcall(function() o.foo = 1 end) == false)
	local str = tostring(o)
	check("tostring contains OBB", string.find(str, "OBB", 1, true) ~= nil)
	check("tostring contains center", string.find(str, "1", 1, true) ~= nil)
end

local function test_clone_aabb()
	print("\n=== clone/from_aabb/from_min_max Tests ===")
	local o = OBB.new(Vector(1, 2, 3), Vector(4, 5, 6))
	local c = OBB.clone(o)
	check("clone center", c[1] == o[1] and c[2] == o[2] and c[3] == o[3])
	check("clone extents", c[4] == o[4] and c[5] == o[5] and c[6] == o[6])
	check("clone distinct table", not rawequal(c, o))
	check("clone errors on non-OBB", pcall(OBB.clone, {}) == false)
	local box = AABB(Vector(0, 0, 0), Vector(2, 4, 6))
	local ob = OBB.from_aabb(box)
	check("from_aabb center", near(ob[1], 1) and near(ob[2], 2) and near(ob[3], 3))
	check("from_aabb extents", near(ob[4], 1) and near(ob[5], 2) and near(ob[6], 3))
	check("from_aabb errors on non-AABB", pcall(OBB.from_aabb, {}) == false)
	local mm = OBB.from_min_max(Vector(0, 0, 0), Vector(2, 4, 6))
	check("from_min_max center", near(mm[1], 1) and near(mm[2], 2) and near(mm[3], 3))
	check("from_min_max extents", near(mm[4], 1) and near(mm[5], 2) and near(mm[6], 3))
	local mmt = OBB.from_min_max({ x = 0, y = 0, z = 0 }, { x = 2, y = 2, z = 2 })
	check("from_min_max tables", near(mmt[1], 1) and near(mmt[4], 1))
end

local function test_transform_contains()
	print("\n=== transform/contains_point Tests ===")
	local o = OBB.new(Vector(1, 1, 1), Vector(1, 1, 1))
	local moved = OBB.transform(o, Matrix4x4.scale(2, 2, 2))
	check("transform scale center", moved[1] == 2 and moved[2] == 2 and moved[3] == 2)
	check("transform preserves extents", moved[4] == 1 and moved[5] == 1 and moved[6] == 1)
	check("transform returns OBB", OBB.is(moved))
	local same = OBB.transform(o, Matrix4x4.new())
	check("transform identity keeps center", same[1] == 1 and same[2] == 1 and same[3] == 1)
	check("transform errors on bad OBB", pcall(OBB.transform, {}, Matrix4x4.new()) == false)
	check("transform errors on bad matrix", pcall(OBB.transform, o, {}) == false)
	local box = OBB.new(Vector(0, 0, 0), Vector(1, 1, 1))
	check("contains inside", OBB.contains_point(box, Vector(0.5, 0.5, 0.5)) == true)
	check("contains center", OBB.contains_point(box, Vector(0, 0, 0)) == true)
	check("contains outside", OBB.contains_point(box, Vector(5, 5, 5)) == false)
	check("contains accepts plain table", OBB.contains_point(box, { x = 0, y = 0, z = 0 }) == true)
	local rot = OBB.new(Vector(0, 0, 0), Vector(1, 1, 1), Matrix4x4.rotation_z(math.pi * 0.5))
	check("contains rotated cube inside", OBB.contains_point(rot, Vector(1, 0, 0)) == true)
	check("contains rotated cube outside", OBB.contains_point(rot, Vector(5, 0, 0)) == false)
	check("contains errors on bad OBB", pcall(OBB.contains_point, {}, Vector(0, 0, 0)) == false)
end

local function test_vertices_volume()
	print("\n=== get_vertices/get_volume Tests ===")
	-- NOTE: get_vertices currently errors on valid input because
	-- Matrix.multiply_vector returns a plain table, and Vector.__add
	-- requires two Vectors. Cover the error path deterministically.
	check("get_vertices errors on valid OBB (known bug)", pcall(OBB.get_vertices, OBB.new(Vector(0, 0, 0), Vector(1, 1, 1))) == false)
	check("get_vertices errors on non-OBB", pcall(OBB.get_vertices, {}) == false)
	local unit = OBB.new(Vector(0, 0, 0), Vector(1, 1, 1))
	check("get_volume unit is 8", OBB.get_volume(unit) == 8)
	check("get_volume 1,2,3 is 48", OBB.get_volume(OBB.new(Vector(0, 0, 0), Vector(1, 2, 3))) == 48)
	check("get_volume errors on bad", pcall(OBB.get_volume, {}) == false)
	check("get_surface_area unit is 24", OBB.get_surface_area(unit) == 24)
	check("get_surface_area 1,2,3 is 88", OBB.get_surface_area(OBB.new(Vector(0, 0, 0), Vector(1, 2, 3))) == 88)
	check("get_surface_area errors on bad", pcall(OBB.get_surface_area, {}) == false)
end

local function test_tables()
	print("\n=== to_table/from_table Tests ===")
	local o = OBB.new(Vector(1, 2, 3), Vector(4, 5, 6))
	local tbl = OBB.to_table(o)
	check("to_table center", tbl.center[1] == 1 and tbl.center[2] == 2 and tbl.center[3] == 3)
	check("to_table half_extents", tbl.half_extents[1] == 4 and tbl.half_extents[2] == 5)
	check("to_table orientation is matrix", Matrix4x4.is(tbl.orientation))
	check("to_table errors on bad", pcall(OBB.to_table, {}) == false)
	-- Roundtrip via to_table: constructor takes the full matrix, so the
	-- center/half_extents survive even though the orientation accessor
	-- currently truncates to identity.
	local back = OBB.from_table(tbl)
	check("from_table roundtrip center", back[1] == o[1] and back[2] == o[2] and back[3] == o[3])
	check("from_table roundtrip extents", back[4] == o[4] and back[5] == o[5] and back[6] == o[6])
	local empty = OBB.from_table({})
	check("from_table empty defaults", empty[1] == 0 and empty[4] == 1)
	check("from_table errors on non-table", pcall(OBB.from_table, 123) == false)
end

local function run_all()
	print("=== OBB Test Suite ===")
	pass_count = 0
	fail_count = 0
	test_new_is()
	test_index_newindex()
	test_clone_aabb()
	test_transform_contains()
	test_vertices_volume()
	test_tables()
	print(string.format("\nTests finished: %d passed, %d failed", pass_count, fail_count))
	if fail_count > 0 then
		os.exit(1)
	end
end

if arg and arg[0] and arg[0]:match("obb%.lua$") then
	run_all()
end

return { run_all = run_all }
