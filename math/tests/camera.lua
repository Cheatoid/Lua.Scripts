-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for camera.lua.
-- Run from this directory:
--   lua camera.lua
--   luajit camera.lua

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
local Camera = require("camera")
local Vector = require("vector")
local Matrix4x4 = require("matrix4x4")
local AABB = require("aabb")

local pass_count = 0
local fail_count = 0

local function check(name, cond)
	if cond then
		pass_count = pass_count + 1
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

local function check_err(name, fn)
	local ok = pcall(fn)
	check(name, ok == false)
end

-- new() defaults and constructor variants.
do
	local c0 = Camera.new()
	check("new defaults pos", c0.position[1] == 0 and c0.position[2] == 0 and c0.position[3] == 0)
	check("new defaults rot", c0.rotation.pitch == 0 and c0.rotation.yaw == 0 and c0.rotation.roll == 0)
	check("new defaults fov", near(c0.fov, math.pi / 3))
	check("new defaults aspect", near(c0.aspect, 16 / 9))
	check("new defaults near", c0.near_z == 0.1)
	check("new defaults far", c0.far_z == 1000)
	check("new defaults speed", c0.move_speed == 5.0)
	check("new defaults sens", c0.mouse_sensitivity == 0.002)
	check("new defaults matrices", Matrix4x4.is(c0.view_matrix) and Matrix4x4.is(c0.projection_matrix))
	check("new defaults vp", Matrix4x4.is(c0.view_projection_matrix))
	check("new defaults frustum", type(c0.frustum) == "table" and #c0.frustum == 6)
	check("new is camera", Camera.is(c0) == true)

	local cv = Camera.new(Vector(1, 2, 3))
	check("new Vector pos", cv.position[1] == 1 and cv.position[2] == 2 and cv.position[3] == 3)
	check("new Vector is Vector", Vector.is(cv.position) == true)

	local ct = Camera.new({ x = 4, y = 5, z = 6 })
	check("new table pos", ct.position[1] == 4 and ct.position[2] == 5 and ct.position[3] == 6)

	local ca = Camera.new({ 7, 8, 9 })
	check("new array pos", ca.position[1] == 7 and ca.position[2] == 8 and ca.position[3] == 9)

	local cn = Camera.new(nil)
	check("new nil pos", cn.position[1] == 0 and cn.position[2] == 0 and cn.position[3] == 0)

	local cr = Camera.new(nil, { pitch = 0.1, yaw = 0.2, roll = 0.3 })
	check("new named rot", near(cr.rotation.pitch, 0.1) and near(cr.rotation.yaw, 0.2) and near(cr.rotation.roll, 0.3))

	local cra = Camera.new(nil, { 0.4, 0.5, 0.6 })
	check("new array rot", near(cra.rotation.pitch, 0.4) and near(cra.rotation.yaw, 0.5) and near(cra.rotation.roll, 0.6))

	local cc = Camera.new(nil, nil, 1.0, 4 / 3, 0.5, 500)
	check("new custom fov", cc.fov == 1.0)
	check("new custom aspect", near(cc.aspect, 4 / 3))
	check("new custom near/far", cc.near_z == 0.5 and cc.far_z == 500)

	local call = Camera(Vector(9, 9, 9))
	check("call creates camera", Camera.is(call) == true and call.position[1] == 9)
end

-- is() validator.
do
	check("is true", Camera.is(Camera.new()) == true)
	check("is rejects table", Camera.is({}) == false)
	check("is rejects nil", Camera.is(nil) == false)
	check("is rejects string", Camera.is("cam") == false)
end

-- update_matrices().
do
	local c = Camera.new()
	local old_vp_1 = c.view_projection_matrix[1]
	Camera.update_matrices(c)
	check("update keeps camera", Camera.is(c) == true)
	check("update frustum len", #c.frustum == 6)
	Camera.set_position(c, Vector(5, 0, 0))
	check("update on move changes vp", c.view_projection_matrix[1] ~= old_vp_1 or c.view_projection_matrix[13] ~= nil)
	check_err("update errors on non-camera", function() Camera.update_matrices({}) end)
	check_err("update errors on nil", function() Camera.update_matrices(nil) end)
end

-- set_position().
do
	local c = Camera.new()
	Camera.set_position(c, Vector(9, 8, 7))
	check("set_position Vector", c.position[1] == 9 and c.position[2] == 8 and c.position[3] == 7)
	Camera.set_position(c, { x = 1, y = 2, z = 3 })
	check("set_position table", c.position[1] == 1 and c.position[2] == 2 and c.position[3] == 3)
	Camera.set_position(c, { 10, 20, 30 })
	check("set_position array", c.position[1] == 10 and c.position[2] == 20 and c.position[3] == 30)
	check_err("set_position errors on number", function() Camera.set_position(c, 123) end)
	check_err("set_position errors on nil", function() Camera.set_position(c, nil) end)
	check_err("set_position errors on string", function() Camera.set_position(c, "bad") end)
	check_err("set_position errors on non-camera", function() Camera.set_position({}, Vector(1, 2, 3)) end)
end

-- set_rotation() incl clamp.
do
	local c = Camera.new()
	Camera.set_rotation(c, { pitch = 0.3, yaw = 0.4, roll = 0.5 })
	check("set_rotation named", near(c.rotation.pitch, 0.3) and near(c.rotation.yaw, 0.4) and near(c.rotation.roll, 0.5))
	Camera.set_rotation(c, { 0.1, 0.2, 0.3 })
	check("set_rotation array", near(c.rotation.pitch, 0.1) and near(c.rotation.yaw, 0.2) and near(c.rotation.roll, 0.3))
	Camera.set_rotation(c, { pitch = 10, yaw = 1, roll = 0 })
	check("set_rotation clamps high", near(c.rotation.pitch, math.pi * 0.5 - 0.01))
	Camera.set_rotation(c, { pitch = -10, yaw = 0, roll = 0 })
	check("set_rotation clamps low", near(c.rotation.pitch, -math.pi * 0.5 + 0.01))
	check_err("set_rotation errors on non-table", function() Camera.set_rotation(c, "bad") end)
	check_err("set_rotation errors on nil rot", function() Camera.set_rotation(c, nil) end)
	check_err("set_rotation errors on non-camera", function() Camera.set_rotation({}, { pitch = 0 }) end)
end

-- move_forward / move_right / move_up.
do
	local m = Camera.new({ x = 0, y = 0, z = 0 }, { pitch = 0, yaw = 0, roll = 0 })
	Camera.move_forward(m, 2)
	check("move_forward +X", near(m.position[1], 2) and near(m.position[2], 0) and near(m.position[3], 0))
	Camera.move_forward(m, -1)
	check("move_forward back", near(m.position[1], 1))
	Camera.move_right(m, 3)
	check("move_right +Z at yaw0", near(m.position[1], 1) and near(m.position[3], 3))
	Camera.move_right(m, -3)
	check("move_right back", near(m.position[3], 0))
	Camera.move_up(m, 4)
	check("move_up", near(m.position[2], 4))
	Camera.move_up(m, -4)
	check("move_up down", near(m.position[2], 0))
	-- pitched forward moves up as well
	local mp = Camera.new({ x = 0, y = 0, z = 0 }, { pitch = math.pi / 6, yaw = 0, roll = 0 })
	Camera.move_forward(mp, 2)
	check("move_forward pitched y", near(mp.position[2], 2 * math.sin(math.pi / 6)))
	check_err("move_forward errors on non-camera", function() Camera.move_forward({}, 1) end)
	check_err("move_right errors on non-camera", function() Camera.move_right({}, 1) end)
	check_err("move_up errors on non-camera", function() Camera.move_up({}, 1) end)
end

-- rotate() incl clamp.
do
	local r = Camera.new()
	Camera.rotate(r, 0.2, 0.3)
	check("rotate adds", near(r.rotation.pitch, 0.2) and near(r.rotation.yaw, 0.3))
	Camera.rotate(r, 10, 0)
	check("rotate clamps pitch", near(r.rotation.pitch, math.pi * 0.5 - 0.01))
	Camera.rotate(r, -10, 0)
	check("rotate clamps low", near(r.rotation.pitch, -math.pi * 0.5 + 0.01))
	check_err("rotate errors on non-camera", function() Camera.rotate({}, 0.1, 0.1) end)
end

-- process_mouse / process_keyboard.
do
	local pm = Camera.new()
	Camera.process_mouse(pm, 100, 50)
	check("process_mouse yaw", near(pm.rotation.yaw, -100 * pm.mouse_sensitivity))
	check("process_mouse pitch", near(pm.rotation.pitch, -50 * pm.mouse_sensitivity))
	check_err("process_mouse errors on non-camera", function() Camera.process_mouse({}, 1, 1) end)

	local pk = Camera.new({ x = 0, y = 0, z = 0 }, { pitch = 0, yaw = 0, roll = 0 })
	pk.move_speed = 5.0
	Camera.process_keyboard(pk, 1, 0, 0, 1.0)
	check("process_keyboard fwd", near(pk.position[1], 5) and near(pk.position[2], 0))
	Camera.process_keyboard(pk, 0, 1, 1, 1.0)
	check("process_keyboard right+up", near(pk.position[3], 5) and near(pk.position[2], 5))
	local pk0 = Camera.new({ x = 1, y = 2, z = 3 }, { pitch = 0, yaw = 0, roll = 0 })
	Camera.process_keyboard(pk0, 0, 0, 0, 0)
	check("process_keyboard zero dt", near(pk0.position[1], 1) and near(pk0.position[2], 2))
	check_err("process_keyboard errors on non-camera", function() Camera.process_keyboard({}, 1, 0, 0, 1) end)
end

-- get_forward / get_right / get_up.
do
	local g = Camera.new(nil, { pitch = 0, yaw = 0, roll = 0 })
	local f = Camera.get_forward(g)
	check("get_forward yaw0", near(f[1], 1) and near(f[2], 0) and near(f[3], 0))
	local rr = Camera.get_right(g)
	check("get_right yaw0", near(rr[1], 0, 1e-6) and near(rr[2], 0) and near(rr[3], 1))
	local u = Camera.get_up(g)
	check("get_up yaw0", near(u[1], 0) and near(u[2], 1) and near(u[3], 0))
	check("forward unit", near(Vector.length(f), 1))
	check("right unit", near(Vector.length(rr), 1))
	check("up unit", near(Vector.length(u), 1, 1e-5))
	check_err("get_forward errors on non-camera", function() Camera.get_forward({}) end)
	check_err("get_right errors on non-camera", function() Camera.get_right({}) end)
	check_err("get_up errors on non-camera", function() Camera.get_up({}) end)
end

-- Visibility using the real frustum (consistency + known outside/inside).
do
	local cam = Camera.new()
	local pts = {
		{ x = 10, y = 0, z = 0 },
		{ x = -10, y = 0, z = 0 },
		{ x = 0, y = 0, z = 0 },
		{ x = 5000, y = 0, z = 0 },
		{ x = 1, y = 1, z = 1 },
	}
	for i, pt in ipairs(pts) do
		local expected = Matrix4x4.point_in_frustum(pt, cam.frustum)
		check("point consistency " .. i, Camera.is_point_visible(cam, pt) == expected)
	end
	check("far point not visible", Camera.is_point_visible(cam, { x = 5000, y = 0, z = 0 }) == false)

	local inside_box = AABB(Vector(0, -1, -1), Vector(2, 1, 0))
	check("aabb matches direct", Camera.is_aabb_visible(cam, inside_box) == Matrix4x4.aabb_in_frustum(inside_box, cam.frustum))
	check("aabb inside true", Camera.is_aabb_visible(cam, inside_box) == true)
	local far_box = AABB(Vector(500, 500, 500), Vector(502, 502, 502))
	check("aabb far false", Camera.is_aabb_visible(cam, far_box) == false)

	local sc = Vector(1, 0, 0)
	check("sphere matches direct", Camera.is_sphere_visible(cam, sc, 2) == Matrix4x4.sphere_in_frustum(sc, 2, cam.frustum))
	check("sphere far false", Camera.is_sphere_visible(cam, Vector(500, 500, 500), 1) == false)

	check_err("is_point_visible errors on non-camera", function() Camera.is_point_visible({}, { x = 0, y = 0, z = 0 }) end)
	check_err("is_aabb_visible errors on non-camera", function() Camera.is_aabb_visible({}, inside_box) end)
	check_err("is_sphere_visible errors on non-camera", function() Camera.is_sphere_visible({}, sc, 1) end)
end

-- set_perspective / clone / __tostring + remaining error paths.
do
	local c = Camera.new()
	Camera.set_perspective(c, 0.8, 1.33, 0.2, 500)
	check("set_perspective", near(c.fov, 0.8) and near(c.aspect, 1.33) and c.near_z == 0.2 and c.far_z == 500)
	local old_fov = c.fov
	Camera.set_perspective(c, nil, nil, nil, nil)
	check("set_perspective nil keeps", c.fov == old_fov)
	check_err("set_perspective errors on non-camera", function() Camera.set_perspective({}, 1, 1, 1, 1) end)

	local cl = Camera.clone(c)
	check("clone is camera", Camera.is(cl) == true)
	check("clone pos", vec_near(cl.position, c.position))
	check("clone rot", cl.rotation.pitch == c.rotation.pitch and cl.rotation.yaw == c.rotation.yaw)
	check("clone proj", cl.fov == c.fov and cl.aspect == c.aspect and cl.near_z == c.near_z and cl.far_z == c.far_z)
	check_err("clone errors on non-camera", function() Camera.clone({}) end)

	local s = tostring(c)
	check("tostring has Camera", s:find("Camera%(pos:") ~= nil)
	check("tostring has fov", s:find("fov:") ~= nil)
	local mt = getmetatable(c)
	local dummy = {}
	check("tostring non-camera passthrough", mt.__tostring(dummy) == tostring(dummy))

	check_err("set_position non-camera2", function() Camera.set_position(nil, Vector(1, 2, 3)) end)
	check_err("move_forward nil", function() Camera.move_forward(nil, 1) end)
	check_err("get_up nil", function() Camera.get_up(nil) end)
end

print(string.format("\nTests finished: %d passed, %d failed", pass_count, fail_count))
if fail_count > 0 then
	os.exit(1)
end
