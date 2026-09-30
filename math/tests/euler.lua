-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for euler.lua.
-- Run from this directory:
--   lua euler.lua
--   luajit euler.lua

-- Bootstrap: shared test bootstrap (see ../../.tools/bootstrap.lua).
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
	local boot
	for _, c in ipairs({
		dir .. "../../.tools/bootstrap.lua",
		dir .. "../.tools/bootstrap.lua",
		dir .. "../../../.tools/bootstrap.lua",
		"./.tools/bootstrap.lua",
		"../.tools/bootstrap.lua",
		"../../.tools/bootstrap.lua",
	}) do
		if isfile(c) then
			boot = c
			break
		end
	end
	assert(boot, "cheatoid test bootstrap not found (.tools/bootstrap.lua)")
	assert(dofile(boot))(dir)
end

local Euler = require "euler"
local Angle = require "angle"
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

local function test_new()
	print("\n=== new Tests ===")
	local d = Euler.new()
	check("new defaults zero", d[1] == 0 and d[2] == 0 and d[3] == 0)
	check("new shorthand zero", Euler()[1] == 0 and Euler()[3] == 0)
	check("new stores pitch", near(Euler.new(0.1, 0.2, 0.3)[1], 0.1))
	check("new stores yaw", near(Euler.new(0.1, 0.2, 0.3)[2], 0.2))
	check("new stores roll", near(Euler.new(0.1, 0.2, 0.3)[3], 0.3))
	local clamped = Euler.new(100, 0, 0)
	check("new pitch clamps high", near(clamped[1], math.pi * 0.5 - 0.001, 1e-9))
	local clamped_low = Euler.new(-100, 0, 0)
	check("new pitch clamps low", near(clamped_low[1], -math.pi * 0.5 + 0.001, 1e-9))
	local wrapped_yaw = Euler.new(0, math.pi * 3, 0)
	check("new yaw wraps 3pi to pi", near(wrapped_yaw[2], math.pi, 1e-9))
	local wrapped_roll = Euler.new(0, 0, math.pi * 3)
	check("new roll wraps 3pi to pi", near(wrapped_roll[3], math.pi, 1e-9))
	local wrapped_neg = Euler.new(0, -math.pi * 3, 0)
	check("new yaw wraps negative", near(math.abs(wrapped_neg[2]), math.pi, 1e-9))
	check("new is euler", Euler.is(Euler.new(0.1, 0.2, 0.3)))
end

local function test_is_index()
	print("\n=== is/__index/__newindex Tests ===")
	check("is true", Euler.is(Euler.new()))
	check("is false plain table", Euler.is({}) == false)
	check("is false nil", Euler.is(nil) == false)
	local e = Euler.new(0.1, 0.2, 0.3)
	check("__index pitch matches [1]", e.pitch == e[1] and near(e.pitch, 0.1))
	check("__index yaw matches [2]", e.yaw == e[2] and near(e.yaw, 0.2))
	check("__index roll matches [3]", e.roll == e[3] and near(e.roll, 0.3))
	check("__index method fallback", type(e.clone) == "function")
	local w = Euler.new(0, 0, 0)
	w.pitch = 100
	check("__newindex pitch clamps", near(w.pitch, math.pi * 0.5 - 0.001, 1e-9))
	w.pitch = -100
	check("__newindex pitch clamps low", near(w.pitch, -math.pi * 0.5 + 0.001, 1e-9))
	w.yaw = math.pi * 3
	check("__newindex yaw normalizes", near(w.yaw, math.pi, 1e-9))
	w.roll = math.pi * 3
	check("__newindex roll normalizes", near(w.roll, math.pi, 1e-9))
	check("__newindex invalid key errors", pcall(function() w.foo = 1 end) == false)
end

local function test_arithmetic()
	print("\n=== Arithmetic Tests ===")
	local a = Euler.new(0.1, 0.2, 0.3)
	local b = Euler.new(0.4, 0.5, 0.6)
	local s = a + b
	check("add pitch", near(s[1], 0.5))
	check("add yaw", near(s[2], 0.7))
	check("add roll", near(s[3], 0.9))
	check("add errors on scalar", pcall(function() return a + 1 end) == false)
	local d = b - a
	check("sub pitch", near(d[1], 0.3))
	check("sub yaw", near(d[2], 0.3))
	check("sub errors on table", pcall(function() return a - {} end) == false)
	local m = a * 2
	check("mul euler*number", near(m[1], 0.2) and near(m[2], 0.4))
	local m2 = 2 * a
	check("mul number*euler", near(m2[1], 0.2) and near(m2[3], 0.6))
	check("mul errors on euler*euler", pcall(function() return a * b end) == false)
	local q = a / 2
	check("div pitch", near(q[1], 0.05))
	check("div errors div-by-zero", pcall(function() return a / 0 end) == false)
	check("div errors on string", pcall(function() return a / "x" end) == false)
	local n = -a
	check("unm pitch", near(n[1], -0.1))
	check("unm yaw", near(n[2], -0.2))
	check("eq true", (Euler.new(0.1, 0.2, 0.3) == Euler.new(0.1, 0.2, 0.3)) == true)
	check("eq false", (a == b) == false)
	check("eq vs plain table false", (a == {}) == false)
	local str = tostring(a)
	check("tostring contains Euler", string.find(str, "Euler", 1, true) ~= nil)
	check("tostring contains pitch", string.find(str, "pitch", 1, true) ~= nil)
end

local function test_clone_from_angles()
	print("\n=== clone/from_angles Tests ===")
	local a = Euler.new(0.1, 0.2, 0.3)
	local c = Euler.clone(a)
	check("clone equal", c == a)
	check("clone distinct", not rawequal(c, a))
	check("clone errors on non-euler", pcall(Euler.clone, {}) == false)
	local from_nums = Euler.from_angles(0.1, 0.2, 0.3)
	check("from_angles numbers", near(from_nums[1], 0.1) and near(from_nums[2], 0.2) and near(from_nums[3], 0.3))
	local from_objs = Euler.from_angles(Angle(0.5), Angle(0.6), Angle(0.7))
	check("from_angles Angle objects", near(from_objs[1], 0.5, 1e-6) and near(from_objs[2], 0.6, 1e-6))
	local from_mixed = Euler.from_angles(Angle(0.5), 0.2, 0.3)
	check("from_angles mixed", near(from_mixed[1], 0.5, 1e-6) and near(from_mixed[2], 0.2))
	local from_empty = Euler.from_angles()
	check("from_angles defaults zero", from_empty[1] == 0 and from_empty[2] == 0 and from_empty[3] == 0)
end

local function test_matrix_conv()
	print("\n=== from_matrix/to_matrix Tests ===")
	local ident = Euler.from_matrix(Matrix4x4.new())
	check("from_matrix identity zero", near(ident[1], 0, 1e-6) and near(ident[2], 0, 1e-6) and near(ident[3], 0, 1e-6))
	check("from_matrix errors on non-matrix", pcall(Euler.from_matrix, {}) == false)
	local zero = Euler.new(0, 0, 0)
	local zm = Euler.to_matrix(zero)
	check("to_matrix zero is matrix", Matrix4x4.is(zm))
	check("to_matrix zero near identity", Matrix4x4.is_near(zm, Matrix4x4.new(), 1e-6))
	check("to_matrix errors on non-euler", pcall(Euler.to_matrix, {}) == false)
	for _, single in ipairs({ Euler.new(0.3, 0, 0), Euler.new(0, 0.3, 0), Euler.new(0, 0, 0.3) }) do
		local mm = Euler.to_matrix(single)
		local back = Euler.from_matrix(mm)
		check(string.format("roundtrip single (%.1f,%.1f,%.1f)", single[1], single[2], single[3]), Euler.is_near(single, back, 1e-4))
	end
	local zback = Euler.from_matrix(Euler.to_matrix(Euler.new(0, 0, 0)))
	check("roundtrip zero", Euler.is_near(Euler.new(0, 0, 0), zback, 1e-6))
end

local function test_vectors()
	print("\n=== get_forward/get_right/get_up Tests ===")
	local fwd = Euler.get_forward(Euler.new(0, 0, 0))
	check("forward zero is +X", near(fwd[1], 1) and near(fwd[2], 0) and near(fwd[3], 0))
	check("forward is vector", Vector.is(fwd))
	local right = Euler.get_right(Euler.new(0, 0, 0))
	check("right zero is +Z", near(right[1], 0, 1e-6) and near(right[2], 0) and near(right[3], 1, 1e-6))
	check("right is vector", Vector.is(right))
	local up = Euler.get_up(Euler.new(0, 0, 0))
	check("up zero is +Y", near(up[1], 0, 1e-6) and near(up[2], 1, 1e-6) and near(up[3], 0, 1e-6))
	check("up is vector", Vector.is(up))
	check("get_forward errors on bad", pcall(Euler.get_forward, {}) == false)
	check("get_right errors on bad", pcall(Euler.get_right, {}) == false)
	check("get_up errors on bad", pcall(Euler.get_up, {}) == false)
end

local function test_interp_norm()
	print("\n=== lerp/slerp/normalize/is_near/clamp Tests ===")
	local a = Euler.new(0, 0, 0)
	local b = Euler.new(1, 1, 1)
	local mid = Euler.lerp(a, b, 0.5)
	check("lerp midpoint", near(mid[1], 0.5) and near(mid[2], 0.5) and near(mid[3], 0.5))
	check("lerp t=0 is a", Euler.lerp(a, b, 0) == a)
	check("lerp t=1 is b", Euler.lerp(a, b, 1) == b)
	check("lerp errors on bad", pcall(Euler.lerp, {}, b, 0.5) == false)
	local s0 = Euler.slerp(a, Euler.new(0.5, 0.5, 0.5), 0)
	check("slerp t=0 near start", Euler.is_near(s0, a, 1e-6))
	local sz = Euler.slerp(a, a, 0.5)
	check("slerp zero stable", Euler.is_near(sz, a, 1e-6))
	check("slerp returns euler", Euler.is(Euler.slerp(a, b, 0.5)))
	check("slerp errors on bad", pcall(Euler.slerp, {}, b, 0.5) == false)
	local n = Euler.normalize(Euler.new(0.1, 0.2, 0.3))
	check("normalize preserves", near(n[1], 0.1) and near(n[2], 0.2))
	check("normalize errors on bad", pcall(Euler.normalize, {}) == false)
	check("is_near identical", Euler.is_near(a, Euler.new(0, 0, 0)) == true)
	check("is_near different", Euler.is_near(a, b) == false)
	check("is_near custom epsilon", Euler.is_near(Euler.new(0, 0, 0), Euler.new(1e-7, 0, 0), 1e-6) == true)
	check("is_near errors on bad", pcall(Euler.is_near, a, {}) == false)
	local cl = Euler.clamp(Euler.new(0, 0, 0), -0.1, 0.1, -0.2, 0.2, -0.3, 0.3)
	check("clamp inside keeps", near(cl[1], 0) and near(cl[2], 0))
	local cl2 = Euler.clamp(Euler.new(2, 2, 2), -1, 1, -1, 1, -1, 1)
	check("clamp outside caps", near(cl2[1], 1) and near(cl2[2], 1) and near(cl2[3], 1))
	check("clamp errors on bad", pcall(Euler.clamp, {}, -1, 1, -1, 1, -1, 1) == false)
end

local function test_tables()
	print("\n=== to_table/from_table Tests ===")
	local a = Euler.new(0.1, 0.2, 0.3)
	local tbl = Euler.to_table(a)
	check("to_table pitch", near(tbl.pitch, 0.1))
	check("to_table yaw", near(tbl.yaw, 0.2))
	check("to_table roll", near(tbl.roll, 0.3))
	check("to_table errors on bad", pcall(Euler.to_table, {}) == false)
	local back = Euler.from_table(tbl)
	check("from_table roundtrip", back == a)
	local empty = Euler.from_table({})
	check("from_table empty zero", empty[1] == 0 and empty[2] == 0 and empty[3] == 0)
	check("from_table errors on non-table", pcall(Euler.from_table, 123) == false)
end

local function run_all()
	print("=== Euler Test Suite ===")
	pass_count = 0
	fail_count = 0
	test_new()
	test_is_index()
	test_arithmetic()
	test_clone_from_angles()
	test_matrix_conv()
	test_vectors()
	test_interp_norm()
	test_tables()
	print(string.format("\nTests finished: %d passed, %d failed", pass_count, fail_count))
	if fail_count > 0 then
		os.exit(1)
	end
end

if arg and arg[0] and arg[0]:match("euler%.lua$") then
	run_all()
end

return { run_all = run_all }
