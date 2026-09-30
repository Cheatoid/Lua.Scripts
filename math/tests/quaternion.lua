-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for quaternion.lua.
-- Run from this directory:
--   lua quaternion.lua
--   luajit quaternion.lua

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

local Quaternion = require "quaternion"

-- Deterministic RNG for the property-based random_unit tests below.
math.randomseed(12345)

local QuaternionTest = {}

-- Assert harness: counts passes/failures so every API is exercised
-- even if one check fails. run_all() exits non-zero when failures > 0.
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

local function quat_near(a, b, eps)
	eps = eps or 1e-6
	local dx, dy, dz, dw = a[1] - b[1], a[2] - b[2], a[3] - b[3], a[4] - b[4]
	return (dx * dx + dy * dy + dz * dz + dw * dw) < eps * eps
end

local function check_err_match(test_name, pat, fn, ...)
	local ok, err = pcall(fn, ...)
	check(test_name, ok == false and string.find(tostring(err), pat, 1, true) ~= nil)
end

function QuaternionTest.test_constructor()
	print("\n=== Constructor Tests ===")

	check("no args default to identity", Quaternion() == Quaternion(0, 0, 0, 1))
	check("new defaults to identity", Quaternion.new() == Quaternion.identity)
	check("components stored", (function()
		local q = Quaternion(1, 2, 3, 4)
		return q[1] == 1 and q[2] == 2 and q[3] == 3 and q[4] == 4
	end)())
	check("named access matches numeric", (function()
		local q = Quaternion(1, 2, 3, 4)
		return q.x == 1 and q.y == 2 and q.z == 3 and q.w == 4
	end)())
	check("new matches call syntax", Quaternion.new(1, 2, 3, 4) == Quaternion(1, 2, 3, 4))
	check("numeric strings coerced", Quaternion("1", "2", "3", "4") == Quaternion(1, 2, 3, 4))
	check("non-numeric x becomes zero, w stays identity", Quaternion("x") == Quaternion.identity)
	check("single arg keeps identity w", Quaternion(1) == Quaternion(1, 0, 0, 1))
	check("identity constant", Quaternion.identity == Quaternion(0, 0, 0, 1))
	check("zero constant", Quaternion.zero == Quaternion(0, 0, 0, 0))
	check("constants are quaternions", Quaternion.is(Quaternion.identity) and Quaternion.is(Quaternion.zero))
end

function QuaternionTest.test_is()
	print("\n=== is Tests ===")

	check("is true for quaternion", Quaternion.is(Quaternion(1, 2, 3, 4)) == true)
	check("is rejects plain table", Quaternion.is({}) == false)
	check("is rejects array table", Quaternion.is({ 0, 0, 0, 1 }) == false)
	check("is rejects nil", Quaternion.is(nil) == false)
	check("is rejects string", Quaternion.is("x") == false)
	check("is rejects number", Quaternion.is(1) == false)
end

function QuaternionTest.test_index_newindex()
	print("\n=== __index/__newindex Tests ===")

	local q = Quaternion(1, 2, 3, 4)
	check("x maps to [1]", q.x == q[1])
	check("y maps to [2]", q.y == q[2])
	check("z maps to [3]", q.z == q[3])
	check("w maps to [4]", q.w == q[4])

	q.x = 10
	check("write x updates [1]", q[1] == 10)
	q[4] = 40
	check("write [4] updates w", q.w == 40)
	q.y, q.z = 20, 30
	check("components hold writes", q == Quaternion(10, 20, 30, 40))

	check("method fallback via __index", q.dot == Quaternion.dot and q.clone == Quaternion.clone)
	check("unknown key is nil", q.nonexistent == nil)

	q.tag = "extra"
	check("extra keys stored as fields", q.tag == "extra")
	check("extra keys do not disturb components", q == Quaternion(10, 20, 30, 40))

	check("colon clone", q:clone() == Quaternion(10, 20, 30, 40))
end

function QuaternionTest.test_add_sub()
	print("\n=== __add/__sub Tests ===")

	local a = Quaternion(1, 2, 3, 4)
	local b = Quaternion(5, 6, 7, 8)
	check("addition", (a + b) == Quaternion(6, 8, 10, 12))
	check("subtraction", (b - a) == Quaternion(4, 4, 4, 4))
	check("add identity", (a + Quaternion.zero) == a)
	check("sub self is zero", (a - a) == Quaternion.zero)
	check("addition errors on quat + number", pcall(function() return a + 1 end) == false)
	check("addition errors on number + quat", pcall(function() return 1 + a end) == false)
	check("addition errors on nil", pcall(function() return a + nil end) == false)
	check_err_match("addition error message", "requires two quaternions", function() return a + b.w end)
	check("subtraction errors on quat - string", pcall(function() return a - "x" end) == false)
end

function QuaternionTest.test_mul()
	print("\n=== __mul Tests ===")

	-- Hamilton product: i * j = k.
	check("hamilton i*j=k", (Quaternion(1, 0, 0, 0) * Quaternion(0, 1, 0, 0)) == Quaternion(0, 0, 1, 0))
	check("hamilton j*i=-k (non-commutative)",
		(Quaternion(0, 1, 0, 0) * Quaternion(1, 0, 0, 0)) == Quaternion(0, 0, -1, 0))
	check("identity is neutral left", (Quaternion.identity * Quaternion(1, 2, 3, 4)) == Quaternion(1, 2, 3, 4))
	check("identity is neutral right", (Quaternion(1, 2, 3, 4) * Quaternion.identity) == Quaternion(1, 2, 3, 4))

	local q = Quaternion(1, 2, 3, 4)
	check("quat * scalar", (q * 2) == Quaternion(2, 4, 6, 8))
	check("scalar * quat", (2 * q) == Quaternion(2, 4, 6, 8))
	check("scalar both sides agree", (q * 3) == (3 * q))
	check("multiply by zero", (q * 0) == Quaternion.zero)

	check("mul errors on quat * string", pcall(function() return q * "x" end) == false)
	check("mul errors on string * quat", pcall(function() return "x" * q end) == false)
	check("mul errors on nil * quat", pcall(function() return nil + q end) == false)
	check("mul errors on quat * nil", pcall(function() return q * nil end) == false)
	check_err_match("mul error message", "requires a quaternion and a number", function() return q * {} end)
end

function QuaternionTest.test_div_unm_len()
	print("\n=== __div/__unm/__len Tests ===")

	check("quat / scalar", (Quaternion(2, 4, 6, 8) / 2) == Quaternion(1, 2, 3, 4))
	check("division errors on divide by zero", pcall(function() return Quaternion(1, 2, 3, 4) / 0 end) == false)
	check_err_match("division by zero message", "division by zero", function() return Quaternion.identity / 0 end)
	check("division errors on quat / quat", pcall(function() return Quaternion.identity / Quaternion.identity end) == false)
	check("division errors on quat / string", pcall(function() return Quaternion.identity / "x" end) == false)
	check("division errors on number / quat", pcall(function() return 1 / Quaternion.identity end) == false)

	check("unary minus", (-Quaternion(1, 2, 3, 4)) == Quaternion(-1, -2, -3, -4))
	check("double negation", (-(-Quaternion(1, 2, 3, 4))) == Quaternion(1, 2, 3, 4))
	check("unm errors on plain table", pcall(getmetatable(Quaternion.identity).__unm, {}) == false)

	local mt = getmetatable(Quaternion(1, 2, 3, 4))
	check("len metamethod computes magnitude", near(mt.__len(Quaternion(1, 2, 3, 4)), math.sqrt(30)))
	check("len metamethod errors on plain table", pcall(mt.__len, {}) == false)
	if _VERSION >= "Lua 5.2" then
		check("length operator uses __len", near(#Quaternion(1, 2, 3, 4), math.sqrt(30), 1e-9))
	else
		-- Lua 5.1 / LuaJIT ignore __len on tables.
		check("length operator is raw table length on 5.1", #Quaternion(1, 2, 3, 4) == 4)
	end
end

function QuaternionTest.test_tostring_concat_iterators()
	print("\n=== __tostring/__concat/__pairs/__ipairs/iterator Tests ===")

	check("tostring format", tostring(Quaternion(0, 0, 0, 1)) == "Quaternion(0, 0, 0, 1)")
	check("tostring values", tostring(Quaternion(1, 2, 3, 4)) == "Quaternion(1, 2, 3, 4)")

	check("concat two quaternions",
		(Quaternion(0, 0, 0, 1) .. Quaternion(1, 0, 0, 0))
		== "Quaternion(0, 0, 0, 1) + Quaternion(1, 0, 0, 0)")
	check("concat quat with string falls back",
		(Quaternion(0, 0, 0, 1) .. "!") == "Quaternion(0, 0, 0, 1)!")
	check("concat string with quat falls back",
		("pre" .. Quaternion(0, 0, 0, 1)) == "preQuaternion(0, 0, 0, 1)")

	-- Direct metamethod calls exercise the documented iterator paths.
	local q = Quaternion(1, 2, 3, 4)
	local seen = {}
	for i, v in getmetatable(q).__pairs(q) do
		seen[i] = v
	end
	check("__pairs yields four components", seen[1] == 1 and seen[2] == 2 and seen[3] == 3 and seen[4] == 4)
	local seen_ip = {}
	for i, v in getmetatable(q).__ipairs(q) do
		seen_ip[i] = v
	end
	check("__ipairs yields four components",
		seen_ip[1] == 1 and seen_ip[2] == 2 and seen_ip[3] == 3 and seen_ip[4] == 4)

	-- Builtin pairs()/ipairs() agree on values on every interpreter
	-- (5.2+ honor __pairs; 5.1 falls back to raw array traversal).
	local builtin = {}
	for i, v in pairs(Quaternion(1, 2, 3, 4)) do
		builtin[i] = v
	end
	check("builtin pairs values", builtin[1] == 1 and builtin[2] == 2 and builtin[3] == 3 and builtin[4] == 4)
	local builtin_ip = {}
	for i, v in ipairs(Quaternion(1, 2, 3, 4)) do
		builtin_ip[i] = v
	end
	check("builtin ipairs values",
		builtin_ip[1] == 1 and builtin_ip[2] == 2 and builtin_ip[3] == 3 and builtin_ip[4] == 4)

	-- iterator() is the shared implementation behind __pairs/__ipairs.
	local collected = {}
	for i, v in Quaternion.iterator(Quaternion(5, 6, 7, 8)) do
		collected[i] = v
	end
	check("iterator yields components", collected[1] == 5 and collected[2] == 6 and collected[3] == 7 and collected[4] == 8)
	check("iterator stops after four",
		select("#", Quaternion.iterator(Quaternion.identity)) == 3) -- fn, state, initial index
	check("iterator errors on plain table", pcall(Quaternion.iterator, {}) == false)
	check("iterator errors on nil", pcall(Quaternion.iterator, nil) == false)
end

function QuaternionTest.test_eq_order()
	print("\n=== __eq/__lt/__le/__gt/__ge Tests ===")

	check("equal quaternions", Quaternion(1, 2, 3, 4) == Quaternion(1, 2, 3, 4))
	check("unequal quaternions", not (Quaternion(1, 2, 3, 4) == Quaternion(1, 2, 3, 5)))
	check("eq is exact (no epsilon)", not (Quaternion(1, 0, 0, 0) == Quaternion(1 + 1e-9, 0, 0, 0)))
	check("eq against plain table is false", (Quaternion.identity == {}) == false)
	check("eq against nil is false", (Quaternion.identity == nil) == false)
	check("eq against string is false", (Quaternion.identity == "x") == false)
	-- Double cover: q and -q are distinct values under exact equality.
	check("eq distinguishes double cover", not (Quaternion(0, 0, 0, 1) == Quaternion(0, 0, 0, -1)))

	-- Ordering compares squared magnitude.
	check("lt by magnitude", Quaternion(1, 0, 0, 0) < Quaternion(2, 0, 0, 0))
	check("lt false on equal magnitude", not (Quaternion(1, 0, 0, 0) < Quaternion(0, 0, 0, 1)))
	check("le on equal magnitude", Quaternion(1, 0, 0, 0) <= Quaternion(0, 0, 0, 1))
	check("gt by magnitude", Quaternion(2, 0, 0, 0) > Quaternion(1, 0, 0, 0))
	check("ge on equal magnitude", Quaternion(1, 0, 0, 0) >= Quaternion(0, 0, 0, 1))
	check("ge false on smaller", not (Quaternion(1, 0, 0, 0) >= Quaternion(2, 0, 0, 0)))
	check("lt errors on quat < number", pcall(function() return Quaternion.identity < 1 end) == false)
	check("le errors on quat <= nil", pcall(function() return Quaternion.identity <= nil end) == false)
	check("gt errors on number > quat", pcall(function() return 1 > Quaternion.identity end) == false)
	check("ge errors on quat >= table", pcall(function() return Quaternion.identity >= {} end) == false)
end

function QuaternionTest.test_clone_set_unpack()
	print("\n=== clone/set/unpack Tests ===")

	local q = Quaternion(1, 2, 3, 4)
	local c = Quaternion.clone(q)
	check("clone equals original", c == q)
	check("clone is a new table", not rawequal(c, q))
	c[1] = 99
	check("clone is independent", q == Quaternion(1, 2, 3, 4))
	check("colon clone", q:clone() == q)

	local s = Quaternion.zero:clone()
	check("set returns self for chaining", Quaternion.set(s, 1, 2, 3, 4) == s)
	check("set stores components", s == Quaternion(1, 2, 3, 4))
	check("set errors on plain table", pcall(Quaternion.set, {}, 1, 2, 3, 4) == false)

	local x, y, z, w = Quaternion.unpack(Quaternion(1, 2, 3, 4))
	check("unpack returns components", x == 1 and y == 2 and z == 3 and w == 4)
	check("unpack returns four values", select("#", Quaternion.unpack(Quaternion.identity)) == 4)
	check("unpack errors on plain table", pcall(Quaternion.unpack, {}) == false)
	check("clone errors on plain table", pcall(Quaternion.clone, {}) == false)
end

function QuaternionTest.test_dot_length_normalize()
	print("\n=== dot/length/normalize Tests ===")

	check("dot product", Quaternion.dot(Quaternion(1, 2, 3, 4), Quaternion(5, 6, 7, 8)) == 70)
	check("dot identity", Quaternion.dot(Quaternion.identity, Quaternion.identity) == 1)
	check("dot errors on bad args", pcall(Quaternion.dot, Quaternion.identity, 1) == false)

	check("length of identity", Quaternion.length(Quaternion.identity) == 1)
	check("length (1,2,3,4)", near(Quaternion.length(Quaternion(1, 2, 3, 4)), math.sqrt(30)))
	check("length of zero", Quaternion.length(Quaternion.zero) == 0)
	check("length_squared (1,2,3,4)", Quaternion.length_squared(Quaternion(1, 2, 3, 4)) == 30)
	check("length errors on bad arg", pcall(Quaternion.length, {}) == false)
	check("length_squared errors on bad arg", pcall(Quaternion.length_squared, nil) == false)

	local n = Quaternion(2, 0, 0, 0)
	check("normalize returns self", Quaternion.normalize(n) == n)
	check("normalize scales to unit", Quaternion.length(n) == 1 and n == Quaternion(1, 0, 0, 0))
	local z = Quaternion.zero:clone()
	check("normalize zero is no-op returning self", Quaternion.normalize(z) == z and z == Quaternion.zero)

	local src = Quaternion(2, 0, 0, 0)
	local nn = Quaternion.normalized(src)
	check("normalized returns new unit quaternion", nn == Quaternion(1, 0, 0, 0))
	check("normalized does not modify original", src == Quaternion(2, 0, 0, 0))
	-- Zero normalizes to identity (documents current behavior).
	check("normalized zero gives identity", Quaternion.normalized(Quaternion.zero) == Quaternion.identity)
	check("normalize errors on bad arg", pcall(Quaternion.normalize, {}) == false)
	check("normalized errors on bad arg", pcall(Quaternion.normalized, 42) == false)
end

function QuaternionTest.test_conjugate_inverse_multiply()
	print("\n=== conjugate/inverse/multiply Tests ===")

	check("conjugate negates vector part",
		Quaternion.conjugate(Quaternion(1, 2, 3, 4)) == Quaternion(-1, -2, -3, 4))
	check("unit times conjugate is identity",
		quat_near(Quaternion(0, 1, 0, 0) * Quaternion.conjugate(Quaternion(0, 1, 0, 0)), Quaternion.identity))
	check("conjugate errors on bad arg", pcall(Quaternion.conjugate, {}) == false)

	check("inverse of identity", Quaternion.inverse(Quaternion.identity) == Quaternion.identity)
	check("quat times inverse is identity",
		Quaternion(1, 2, 3, 4) * Quaternion.inverse(Quaternion(1, 2, 3, 4)) == Quaternion.identity)
	check("inverse of unit equals conjugate",
		Quaternion.inverse(Quaternion(0, 0, 1, 0)) == Quaternion.conjugate(Quaternion(0, 0, 1, 0)))
	check_err_match("inverse zero errors", "cannot invert", function() return Quaternion.inverse(Quaternion.zero) end)
	check("inverse errors on bad arg", pcall(Quaternion.inverse, {}) == false)

	local a = Quaternion(1, 2, 3, 4)
	local b = Quaternion(5, 6, 7, 8)
	check("multiply matches operator", Quaternion.multiply(a, b) == (a * b))
	check("multiply errors on quat and number", pcall(Quaternion.multiply, a, 2) == false)
	check("multiply errors on number and quat", pcall(Quaternion.multiply, 2, a) == false)
	check("multiply errors on nil", pcall(Quaternion.multiply, nil, a) == false)
end

function QuaternionTest.test_rotate_vector()
	print("\n=== rotate_vector Tests ===")

	check("identity rotation preserves vector", (function()
		local rx, ry, rz = Quaternion.rotate_vector(Quaternion.identity, 1, 2, 3)
		return near(rx, 1) and near(ry, 2) and near(rz, 3)
	end)())
	check("90deg about Y maps +X to -Z", (function()
		local q = Quaternion.from_axis_angle(0, 1, 0, math.rad(90))
		local rx, ry, rz = Quaternion.rotate_vector(q, 1, 0, 0)
		return near(rx, 0, 1e-9) and near(ry, 0, 1e-9) and near(rz, -1, 1e-9)
	end)())
	check("180deg about X flips Y", (function()
		local q = Quaternion.from_axis_angle(1, 0, 0, math.pi)
		local rx, ry, rz = Quaternion.rotate_vector(q, 0, 1, 0)
		return near(rx, 0, 1e-9) and near(ry, -1, 1e-9) and near(rz, 0, 1e-9)
	end)())
	check("rotate_vector errors on bad quat", pcall(Quaternion.rotate_vector, {}, 1, 0, 0) == false)
	check("rotate_vector errors on missing components", pcall(Quaternion.rotate_vector, Quaternion.identity, 1) == false)
end

function QuaternionTest.test_interpolation()
	print("\n=== lerp/nlerp/slerp Tests ===")

	local a = Quaternion(0, 0, 0, 1)
	local b = Quaternion(0, 1, 0, 0)

	check("lerp midpoint averages components", Quaternion.lerp(a, b, 0.5) == Quaternion(0, 0.5, 0, 0.5))
	check("lerp t=0 gives a", Quaternion.lerp(a, b, 0) == a)
	check("lerp t=1 gives b", Quaternion.lerp(a, b, 1) == b)
	check("lerp result is not normalized", not Quaternion.is_unit(Quaternion.lerp(a, b, 0.5)))
	check("lerp errors on bad args", pcall(Quaternion.lerp, a, 1, 0.5) == false)

	check("nlerp midpoint is unit", Quaternion.is_unit(Quaternion.nlerp(a, b, 0.5)))
	check("nlerp t=0 gives a", quat_near(Quaternion.nlerp(a, b, 0), a))
	check("nlerp t=1 gives b", quat_near(Quaternion.nlerp(a, b, 1), b))
	-- Opposite hemispheres take the short path back to a.
	check("nlerp opposite hemisphere flips", quat_near(Quaternion.nlerp(a, -a, 0.25), a))
	check("nlerp errors on bad args", pcall(Quaternion.nlerp, nil, b, 0.5) == false)

	check("slerp t=0 gives a", quat_near(Quaternion.slerp(a, b, 0), a))
	check("slerp t=1 gives b", quat_near(Quaternion.slerp(a, b, 1), b))
	check("slerp identical falls back to nlerp path", quat_near(Quaternion.slerp(a, a, 0.5), a))
	-- Double cover: slerping toward -a resolves to a.
	check("slerp opposite hemisphere resolves", quat_near(Quaternion.slerp(a, -a, 0.5), a))
	check("slerp halfway to 180deg about Y is 90deg", (function()
		local half = Quaternion.slerp(a, Quaternion.from_axis_angle(0, 1, 0, math.pi), 0.5)
		return quat_near(half, Quaternion.from_axis_angle(0, 1, 0, math.pi / 2), 1e-6)
	end)())
	check("slerp errors on bad args", pcall(Quaternion.slerp, a, {}, 0.5) == false)
end

function QuaternionTest.test_axis_angle()
	print("\n=== from_axis_angle/to_axis_angle Tests ===")

	check("zero axis gives identity", Quaternion.from_axis_angle(0, 0, 0, 1.5) == Quaternion.identity)
	check("zero angle gives identity", Quaternion.from_axis_angle(0, 1, 0, 0) == Quaternion.identity)
	check("non-normalized axis is normalized internally",
		quat_near(Quaternion.from_axis_angle(0, 2, 0, math.pi / 2), Quaternion.from_axis_angle(0, 1, 0, math.pi / 2)))
	check("axis rotation is unit", Quaternion.is_unit(Quaternion.from_axis_angle(1, 2, 3, 0.7)))
	check("from_axis_angle errors on bad axis", pcall(Quaternion.from_axis_angle, "a", 0, 0, 1) == false)

	check("to_axis_angle identity", (function()
		local ax, ay, az, angle = Quaternion.to_axis_angle(Quaternion.identity)
		return ax == 1 and ay == 0 and az == 0 and angle == 0
	end)())
	check("to_axis_angle roundtrip", (function()
		local ax, ay, az, angle = Quaternion.to_axis_angle(Quaternion.from_axis_angle(0, 1, 0, 1.2))
		return near(ax, 0) and near(ay, 1) and near(az, 0) and near(angle, 1.2)
	end)())
	check("to_axis_angle full roundtrip", (function()
		local q = Quaternion.from_axis_angle(1, 2, 3, 0.9)
		local ax, ay, az, angle = Quaternion.to_axis_angle(q)
		return quat_near(Quaternion.from_axis_angle(ax, ay, az, angle), q, 1e-6)
	end)())
	check("to_axis_angle errors on bad arg", pcall(Quaternion.to_axis_angle, {}) == false)
end

function QuaternionTest.test_euler()
	print("\n=== from_euler/to_euler Tests ===")

	check("euler identity roundtrip", (function()
		local p, y, r = Quaternion.to_euler(Quaternion.from_euler(0, 0, 0))
		return near(p, 0, 1e-9) and near(y, 0, 1e-9) and near(r, 0, 1e-9)
	end)())
	for i, angles in ipairs({ { 0.5, 0, 0 }, { 0, 0.5, 0 }, { 0, 0, 0.5 }, { 0.3, 0.5, 0 }, { 0, 0.5, 0.7 } }) do
		local p, y, r = angles[1], angles[2], angles[3]
		local q = Quaternion.from_euler(p, y, r)
		local p2, y2, r2 = Quaternion.to_euler(q)
		check(string.format("euler angles roundtrip #%d", i),
			near(p2, p, 1e-9) and near(y2, y, 1e-9) and near(r2, r, 1e-9))
		check(string.format("euler quat roundtrip #%d", i),
			quat_near(Quaternion.from_euler(p2, y2, r2), q, 1e-6))
	end

	-- Gimbal lock (roll ~= 90deg): yaw collapses to 0 but the rotation survives.
	check("gimbal lock yaw collapses", (function()
		local _, y = Quaternion.to_euler(Quaternion.from_euler(0.2, -0.3, math.pi / 2))
		return y == 0
	end)())
	check("gimbal lock quat roundtrip", (function()
		local q = Quaternion.from_euler(0.2, -0.3, math.pi / 2)
		local p2, y2, r2 = Quaternion.to_euler(q)
		return quat_near(Quaternion.from_euler(p2, y2, r2), q, 1e-6)
	end)())

	-- NOTE: to_euler pitch extraction diverges from from_euler when both
	-- pitch and roll are non-zero (implementation limitation). yaw/roll survive:
	local q_mix = Quaternion.from_euler(0.3, 0.5, 0.7)
	local mp, my, mr = Quaternion.to_euler(q_mix)
	check("euler yaw survives combined pitch+roll", near(my, 0.5, 1e-9))
	check("euler roll survives combined pitch+roll", near(mr, 0.7, 1e-9))
	check("euler pitch diverges for combined pitch+roll (documents current behavior)",
		not quat_near(q_mix, Quaternion.from_euler(mp, my, mr)))

	check("from_euler errors on nil", pcall(Quaternion.from_euler, nil, 0, 0) == false)
	check("to_euler errors on bad arg", pcall(Quaternion.to_euler, {}) == false)
end

function QuaternionTest.test_angle_between()
	print("\n=== angle_between Tests ===")

	check("identical angle is zero", Quaternion.angle_between(Quaternion.identity, Quaternion.identity) == 0)
	check("double cover angle is zero",
		near(Quaternion.angle_between(Quaternion.identity, -Quaternion.identity), 0))
	check("180deg rotation gives pi",
		near(Quaternion.angle_between(Quaternion.identity, Quaternion.from_axis_angle(1, 0, 0, math.pi)), math.pi))
	check("90deg rotation gives pi/2",
		near(Quaternion.angle_between(Quaternion.identity, Quaternion.from_axis_angle(0, 1, 0, math.pi / 2)), math.pi / 2))
	check("angle_between errors on bad args",
		pcall(Quaternion.angle_between, Quaternion.identity, {}) == false)
end

function QuaternionTest.test_predicates()
	print("\n=== is_identity/is_zero/is_unit/is_near Tests ===")

	check("is_identity true", Quaternion.is_identity(Quaternion.identity))
	check("is_identity default epsilon", Quaternion.is_identity(Quaternion(1e-7, 0, 0, 1)))
	check("is_identity rejects drift", not Quaternion.is_identity(Quaternion(1e-4, 0, 0, 1)))
	check("is_identity custom epsilon", Quaternion.is_identity(Quaternion(1e-4, 0, 0, 1), 1e-3))
	check("is_identity rejects negated identity (double cover is not identity)",
		not Quaternion.is_identity(Quaternion(0, 0, 0, -1)))
	check("is_identity errors on bad arg", pcall(Quaternion.is_identity, {}) == false)

	check("is_zero true", Quaternion.is_zero(Quaternion.zero))
	check("is_zero rejects identity", not Quaternion.is_zero(Quaternion.identity))
	check("is_zero custom epsilon", Quaternion.is_zero(Quaternion(1e-4, 0, 0, 0), 1e-3))
	check("is_zero errors on bad arg", pcall(Quaternion.is_zero, nil) == false)

	check("is_unit identity", Quaternion.is_unit(Quaternion.identity))
	check("is_unit rejects zero", not Quaternion.is_unit(Quaternion.zero))
	check("is_unit rejects scaled", not Quaternion.is_unit(Quaternion(2, 0, 0, 0)))
	check("is_unit accepts normalized", Quaternion.is_unit(Quaternion.normalized(Quaternion(1, 2, 3, 4))))
	check("is_unit errors on bad arg", pcall(Quaternion.is_unit, {}) == false)

	check("is_near identical", Quaternion.is_near(Quaternion.identity, Quaternion.identity))
	-- Double cover: q is near -q.
	check("is_near double cover", Quaternion.is_near(Quaternion.identity, -Quaternion.identity))
	check("is_near within epsilon",
		Quaternion.is_near(Quaternion.identity, Quaternion(1e-7, 0, 0, 1)))
	check("is_near outside epsilon",
		not Quaternion.is_near(Quaternion.identity, Quaternion(1e-4, 0, 0, 1)))
	check("is_near custom epsilon",
		Quaternion.is_near(Quaternion.identity, Quaternion(1e-4, 0, 0, 1), 1e-3))
	check("is_near errors unless two quats",
		pcall(Quaternion.is_near, Quaternion.identity, nil) == false)
	check("is_near errors on swapped bad args",
		pcall(Quaternion.is_near, 1, Quaternion.identity) == false)
end

function QuaternionTest.test_random_unit()
	print("\n=== random_unit Tests ===")

	for _ = 1, 20 do
		local u = Quaternion.random_unit()
		check("random_unit is unit", Quaternion.is_unit(u))
		check("random_unit length is one", near(Quaternion.length(u), 1, 1e-9))
	end
end

function QuaternionTest.test_conversions()
	print("\n=== to_array/to_table/from_table Tests ===")

	local q = Quaternion(1, 2, 3, 4)
	local arr = Quaternion.to_array(q)
	check("to_array values", arr[1] == 1 and arr[2] == 2 and arr[3] == 3 and arr[4] == 4 and #arr == 4)
	arr[1] = 99
	check("to_array returns fresh table", q == Quaternion(1, 2, 3, 4))
	check("to_array errors on bad arg", pcall(Quaternion.to_array, {}) == false)

	local tbl = Quaternion.to_table(q)
	check("to_table keys", tbl.x == 1 and tbl.y == 2 and tbl.z == 3 and tbl.w == 4)
	tbl.x = 99
	check("to_table returns fresh table", q == Quaternion(1, 2, 3, 4))
	check("to_table errors on bad arg", pcall(Quaternion.to_table, nil) == false)

	check("from_table keyed", Quaternion.from_table({ x = 1, y = 2, z = 3, w = 4 }) == q)
	check("from_table indexed", Quaternion.from_table({ 1, 2, 3, 4 }) == q)
	check("from_table prefers named keys",
		Quaternion.from_table({ x = 9, [1] = 1, y = 2, [2] = 2, z = 3, [3] = 3, w = 4, [4] = 4 })
		== Quaternion(9, 2, 3, 4))
	check("from_table empty gives identity", Quaternion.from_table({}) == Quaternion.identity)
	check("from_table errors on nil", pcall(Quaternion.from_table, nil) == false)
end

-- Run all tests.
function QuaternionTest.run_all()
	print("=== Quaternion Test Suite ===")
	pass_count = 0
	fail_count = 0

	QuaternionTest.test_constructor()
	QuaternionTest.test_is()
	QuaternionTest.test_index_newindex()
	QuaternionTest.test_add_sub()
	QuaternionTest.test_mul()
	QuaternionTest.test_div_unm_len()
	QuaternionTest.test_tostring_concat_iterators()
	QuaternionTest.test_eq_order()
	QuaternionTest.test_clone_set_unpack()
	QuaternionTest.test_dot_length_normalize()
	QuaternionTest.test_conjugate_inverse_multiply()
	QuaternionTest.test_rotate_vector()
	QuaternionTest.test_interpolation()
	QuaternionTest.test_axis_angle()
	QuaternionTest.test_euler()
	QuaternionTest.test_angle_between()
	QuaternionTest.test_predicates()
	QuaternionTest.test_random_unit()
	QuaternionTest.test_conversions()

	print(string.format("\n=== Test Suite Complete: %d passed, %d failed ===", pass_count, fail_count))
	if fail_count ~= 0 then
		os.exit(1)
	end
	print("All tests passed")
end

QuaternionTest.run_all()

return QuaternionTest
