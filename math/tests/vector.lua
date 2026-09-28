-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for vector.lua.
-- Run from this directory:
--   lua vector.lua
--   luajit vector.lua

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

local Vector = require "vector"

-- Deterministic RNG for the property-based random tests below.
math.randomseed(12345)

local VectorTest = {}

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

local function vec_near(a, b, eps)
	eps = eps or 1e-6
	return Vector.distance(a, b) <= eps
end

local function check_err_match(test_name, pat, fn, ...)
	local ok, err = pcall(fn, ...)
	check(test_name, ok == false and string.find(tostring(err), pat, 1, true) ~= nil)
end

function VectorTest.test_constructor()
	print("\n=== Constructor Tests ===")

	local v0 = Vector()
	check("no args default to zero", v0[1] == 0 and v0[2] == 0 and v0[3] == 0)
	check("no args is vector", Vector.is(v0))

	local v1 = Vector(5)
	check("single arg broadcasts to all components", v1[1] == 5 and v1[2] == 5 and v1[3] == 5)

	local v2 = Vector(1, 2)
	check("two args broadcast x into z", v2[1] == 1 and v2[2] == 2 and v2[3] == 1)

	local v3 = Vector(1, 2, 3)
	check("three args stored", v3[1] == 1 and v3[2] == 2 and v3[3] == 3)
	check("named access matches numeric", v3.x == 1 and v3.y == 2 and v3.z == 3)

	check("new matches call syntax", Vector.new(1, 2, 3) == Vector(1, 2, 3))

	local vs = Vector("1", "2", "3")
	check("numeric strings coerced", vs == Vector(1, 2, 3))
	check("non-numeric strings become zero", Vector("x") == Vector(0, 0, 0))
	check("nil args become zero", Vector(nil, nil, nil) == Vector(0, 0, 0))

	local vn = Vector(-1.5, 0, 1e150)
	check("negative and large values stored", vn.x == -1.5 and vn.y == 0 and vn.z == 1e150)
end

function VectorTest.test_constants()
	print("\n=== Constant Tests ===")

	check("zero constant", Vector.zero == Vector(0, 0, 0))
	check("one constant", Vector.one == Vector(1, 1, 1))
	check("unit_x constant", Vector.unit_x == Vector(1, 0, 0))
	check("unit_y constant", Vector.unit_y == Vector(0, 1, 0))
	check("unit_z constant", Vector.unit_z == Vector(0, 0, 1))
	check("constants are vectors",
		Vector.is(Vector.zero) and Vector.is(Vector.one)
		and Vector.is(Vector.unit_x) and Vector.is(Vector.unit_y) and Vector.is(Vector.unit_z))

	-- Default coordinate system is unreal: forward=+X, up=+Z.
	check("default forward", Vector.forward == Vector(1, 0, 0))
	check("default back", Vector.back == Vector(-1, 0, 0))
	check("default up", Vector.up == Vector(0, 0, 1))
	check("default down", Vector.down == Vector(0, 0, -1))
	check("default right (left-handed cross)", Vector.right == Vector(0, 1, 0))
	check("default left", Vector.left == Vector(0, -1, 0))
end

function VectorTest.test_is()
	print("\n=== is Tests ===")

	check("is true for vector", Vector.is(Vector(1, 2, 3)) == true)
	check("is rejects plain table", Vector.is({}) == false)
	check("is rejects array table", Vector.is({ 1, 2, 3 }) == false)
	check("is rejects nil", Vector.is(nil) == false)
	check("is rejects string", Vector.is("x") == false)
	check("is rejects number", Vector.is(42) == false)
end

function VectorTest.test_index_newindex()
	print("\n=== __index/__newindex Tests ===")

	local v = Vector(1, 2, 3)
	check("x maps to [1]", v.x == v[1])
	check("y maps to [2]", v.y == v[2])
	check("z maps to [3]", v.z == v[3])

	v.x = 10
	check("write x updates [1]", v[1] == 10)
	v[2] = 20
	check("write [2] updates y", v.y == 20)
	v.z = 30
	check("write z updates [3]", v[3] == 30)
	check("components hold writes", v == Vector(10, 20, 30))

	check("method fallback via __index", v.dot == Vector.dot and v.clone == Vector.clone)
	check("unknown key is nil", v.nonexistent == nil)

	v.tag = "extra"
	check("extra keys stored as fields", v.tag == "extra")
	check("extra keys do not disturb components", v == Vector(10, 20, 30))

	-- Colon-call dispatch goes through __index as well.
	check("colon clone", v:clone() == Vector(10, 20, 30))
end

function VectorTest.test_arithmetic()
	print("\n=== Arithmetic Metamethod Tests ===")

	local a = Vector(1, 2, 3)
	local b = Vector(4, 5, 6)

	check("addition", (a + b) == Vector(5, 7, 9))
	check("subtraction", (b - a) == Vector(3, 3, 3))
	check("add zero identity", (a + Vector.zero) == a)
	check("sub self is zero", (a - a) == Vector.zero)
	check("addition errors on vector + number", pcall(function() return a + 1 end) == false)
	check("addition errors on number + vector", pcall(function() return 1 + a end) == false)
	check("addition errors on nil", pcall(function() return a + nil end) == false)
	check_err_match("addition error message", "requires two vectors", function() return a + b.z end)

	check("vector * scalar", (a * 2) == Vector(2, 4, 6))
	check("scalar * vector", (2 * a) == Vector(2, 4, 6))
	check("multiply by zero", (a * 0) == Vector.zero)
	check("multiply by negative", (a * -1) == Vector(-1, -2, -3))
	check("multiplication errors on vector * vector", pcall(function() return a * b end) == false)
	check("multiplication errors on vector * string", pcall(function() return a * "x" end) == false)
	check("multiplication errors on string * vector", pcall(function() return "x" * a end) == false)
	check("multiplication errors on nil * vector", pcall(function() return nil + a end) == false)

	check("vector / scalar", (Vector(2, 4, 6) / 2) == Vector(1, 2, 3))
	check("division errors on divide by zero", pcall(function() return a / 0 end) == false)
	check_err_match("division by zero message", "division by zero", function() return a / 0 end)
	check("division errors on vector / vector", pcall(function() return a / b end) == false)
	check("division errors on vector / string", pcall(function() return a / "x" end) == false)
	check("division errors on number / vector", pcall(function() return 1 / a end) == false)

	check("unary minus", (-a) == Vector(-1, -2, -3))
	check("double negation", (-(-a)) == a)
	check("unm errors on plain table", pcall(getmetatable(a).__unm, {}) == false)
end

function VectorTest.test_len_tostring_concat()
	print("\n=== __len/__tostring/__concat Tests ===")

	local mt = getmetatable(Vector(3, 4, 0))
	check("len metamethod computes magnitude", near(mt.__len(Vector(3, 4, 0)), 5))
	check("len metamethod errors on plain table", pcall(mt.__len, {}) == false)
	if _VERSION >= "Lua 5.2" then
		check("length operator uses __len", near(#Vector(3, 4, 0), 5, 1e-9))
	else
		-- Lua 5.1 / LuaJIT ignore __len on tables.
		check("length operator is raw table length on 5.1", #Vector(3, 4, 0) == 3)
	end

	check("tostring format", tostring(Vector(1, 2, 3)) == "Vector(1, 2, 3)")
	check("tostring negative and float", tostring(Vector(-1, 2.5, 0)) == "Vector(-1, 2.5, 0)")

	check("concat two vectors",
		(Vector(1, 2, 3) .. Vector(4, 5, 6)) == "Vector(1, 2, 3) + Vector(4, 5, 6)")
	check("concat vector with string falls back", (Vector(1, 2, 3) .. "!") == "Vector(1, 2, 3)!")
	check("concat string with vector falls back", ("pre" .. Vector(1, 2, 3)) == "preVector(1, 2, 3)")
end

function VectorTest.test_eq_order()
	print("\n=== __eq/__lt/__le/__gt/__ge Tests ===")

	check("equal vectors", Vector(1, 2, 3) == Vector(1, 2, 3))
	check("unequal vectors", not (Vector(1, 2, 3) == Vector(1, 2, 4)))
	check("eq against plain table is false", (Vector(1, 2, 3) == {}) == false)
	check("eq against nil is false", (Vector(1, 2, 3) == nil) == false)

	-- Ordering compares squared magnitude.
	check("lt by magnitude", Vector(1, 0, 0) < Vector(0, 2, 0))
	check("lt false on larger", not (Vector(0, 2, 0) < Vector(1, 0, 0)))
	check("le on equal magnitude", Vector(1, 0, 0) <= Vector(0, 1, 0))
	check("le false on larger", not (Vector(0, 2, 0) <= Vector(1, 0, 0)))
	check("gt by magnitude", Vector(0, 2, 0) > Vector(1, 0, 0))
	check("ge on equal magnitude", Vector(1, 0, 0) >= Vector(0, 1, 0))
	check("ge false on smaller", not (Vector(1, 0, 0) >= Vector(0, 2, 0)))
	check("lt errors on vector < number", pcall(function() return Vector(1, 0, 0) < 1 end) == false)
	check("le errors on vector <= nil", pcall(function() return Vector(1, 0, 0) <= nil end) == false)
	check("gt errors on number > vector", pcall(function() return 1 > Vector(1, 0, 0) end) == false)
	check("ge errors on vector >= table", pcall(function() return Vector(1, 0, 0) >= {} end) == false)
end

function VectorTest.test_clone_set_unpack()
	print("\n=== clone/set/unpack Tests ===")

	local v = Vector(1, 2, 3)
	local c = Vector.clone(v)
	check("clone equals original", c == v)
	check("clone is a new table", not rawequal(c, v))
	c[1] = 99
	check("clone is independent", v == Vector(1, 2, 3))
	check("colon clone", v:clone() == v)

	local s = Vector(0, 0, 0)
	check("set returns self for chaining", Vector.set(s, 4, 5, 6) == s)
	check("set stores components", s == Vector(4, 5, 6))
	check("set errors on plain table", pcall(Vector.set, {}, 1, 2, 3) == false)

	local x, y, z = Vector.unpack(Vector(7, 8, 9))
	check("unpack returns components", x == 7 and y == 8 and z == 9)
	check("unpack returns three values", select("#", Vector.unpack(Vector(7, 8, 9))) == 3)
	check("unpack errors on plain table", pcall(Vector.unpack, {}) == false)
	check("clone errors on plain table", pcall(Vector.clone, {}) == false)
end

function VectorTest.test_dot_length_normalize()
	print("\n=== dot/length/normalize Tests ===")

	check("dot product", Vector.dot(Vector(1, 2, 3), Vector(4, 5, 6)) == 32)
	check("dot orthogonal is zero", Vector.dot(Vector.unit_x, Vector.unit_y) == 0)
	check("dot errors on bad args", pcall(Vector.dot, Vector.unit_x, 1) == false)
	check("dot errors on nil", pcall(Vector.dot, nil, Vector.unit_x) == false)

	check("length 3-4-5", near(Vector.length(Vector(3, 4, 0)), 5))
	check("length of zero", Vector.length(Vector.zero) == 0)
	check("length_squared avoids sqrt", Vector.length_squared(Vector(3, 4, 0)) == 25)
	check("length_squared (1,2,2)", Vector.length_squared(Vector(1, 2, 2)) == 9)
	check("length errors on bad arg", pcall(Vector.length, {}) == false)
	check("length_squared errors on bad arg", pcall(Vector.length_squared, nil) == false)

	local n = Vector(3, 4, 0)
	check("normalize returns self", Vector.normalize(n) == n)
	check("normalize scales to unit", vec_near(n, Vector(0.6, 0.8, 0)))
	local z = Vector.zero:clone()
	check("normalize zero is no-op returning self", Vector.normalize(z) == z and z == Vector.zero)

	local src = Vector(3, 4, 0)
	local nn = Vector.normalized(src)
	check("normalized returns new unit vector", vec_near(nn, Vector(0.6, 0.8, 0)))
	check("normalized does not modify original", src == Vector(3, 4, 0))
	check("normalized zero gives zero", Vector.normalized(Vector.zero) == Vector.zero)
	check("normalize errors on bad arg", pcall(Vector.normalize, {}) == false)
	check("normalized errors on bad arg", pcall(Vector.normalized, 42) == false)
end

function VectorTest.test_distances()
	print("\n=== Distance Tests ===")

	local a = Vector(0, 0, 0)
	local b = Vector(1, 2, 2)
	check("euclidean distance", near(Vector.distance(a, b), 3))
	check("distance to self is zero", Vector.distance(a, a) == 0)
	check("distance_squared", Vector.distance_squared(a, b) == 9)
	check("manhattan distance", Vector.distance_manhattan(a, b) == 5)
	check("manhattan with negatives", Vector.distance_manhattan(Vector(-1, -2, -3), Vector(1, 2, 3)) == 12)
	check("chebyshev distance", Vector.distance_chebyshev(a, b) == 2)
	check("chebyshev picks max axis", Vector.distance_chebyshev(Vector(0, 0, 0), Vector(1, 5, 3)) == 5)
	check("minkowski defaults to euclidean", near(Vector.distance_minkowski(a, b), 3))
	check("minkowski p=1 is manhattan", Vector.distance_minkowski(a, b, 1) == 5)
	check("minkowski p=2 is euclidean", near(Vector.distance_minkowski(a, b, 2), 3))
	check("minkowski p=huge is chebyshev", Vector.distance_minkowski(a, b, math.huge) == 2)
	check("minkowski p=3 general case", near(Vector.distance_minkowski(a, b, 3), 17 ^ (1 / 3)))
	check("minkowski errors on p < 1", pcall(Vector.distance_minkowski, a, b, 0) == false)
	check("minkowski errors on fractional p < 1", pcall(Vector.distance_minkowski, a, b, 0.5) == false)
	check("distance errors on bad args", pcall(Vector.distance, a, {}) == false)
	check("distance_squared errors on bad args", pcall(Vector.distance_squared, nil, b) == false)
	check("distance_manhattan errors on bad args", pcall(Vector.distance_manhattan, a, "x") == false)
	check("distance_chebyshev errors on bad args", pcall(Vector.distance_chebyshev, {}, b) == false)
end

function VectorTest.test_angle()
	print("\n=== angle Tests ===")

	check("orthogonal angle is pi/2", near(Vector.angle(Vector.unit_x, Vector.unit_y), math.pi / 2))
	check("parallel angle is zero", near(Vector.angle(Vector.unit_x, Vector(2, 0, 0)), 0))
	check("opposite angle is pi", near(Vector.angle(Vector.unit_x, Vector(-3, 0, 0)), math.pi))
	check("zero vector angle is zero", Vector.angle(Vector.zero, Vector.unit_x) == 0)
	check("near-parallel clamps without nan",
		near(Vector.angle(Vector(1, 0, 0), Vector(1.0000001, 0, 0)), 0))
	check("45 degree angle", near(Vector.angle(Vector(1, 0, 0), Vector(1, 1, 0)), math.pi / 4))
	check("angle errors on bad args", pcall(Vector.angle, Vector.unit_x, {}) == false)
end

function VectorTest.test_interpolation()
	print("\n=== lerp/mix/slerp/smoothstep/move_towards Tests ===")

	local a = Vector(0, 0, 0)
	local b = Vector(10, 20, 30)
	check("lerp midpoint", Vector.lerp(a, b, 0.5) == Vector(5, 10, 15))
	check("lerp t=0 gives a", Vector.lerp(a, b, 0) == a)
	check("lerp t=1 gives b", Vector.lerp(a, b, 1) == b)
	check("lerp extrapolates", Vector.lerp(a, b, 2) == Vector(20, 40, 60))
	check("lerp errors on bad args", pcall(Vector.lerp, a, {}, 0.5) == false)

	check("mix matches lerp", Vector.mix(a, b, 0.3) == Vector.lerp(a, b, 0.3))
	check("mix errors on bad args", pcall(Vector.mix, nil, b, 0.5) == false)

	check("slerp identical vectors", vec_near(Vector.slerp(Vector.unit_x, Vector.unit_x, 0.5), Vector.unit_x))
	check("slerp t=0 gives a", vec_near(Vector.slerp(Vector.unit_x, Vector.unit_y, 0), Vector.unit_x))
	-- Opposite vectors hit the lerp fallback and collapse to zero.
	check("slerp opposite vectors collapse (fallback path)",
		Vector.slerp(Vector.unit_x, -Vector.unit_x, 0.5) == Vector.zero)
	check("slerp errors on bad args", pcall(Vector.slerp, a, 1, 0.5) == false)

	check("smoothstep endpoints",
		Vector.smoothstep(a, b, 0) == a and Vector.smoothstep(a, b, 1) == b)
	check("smoothstep clamps low", Vector.smoothstep(a, b, -1) == a)
	check("smoothstep clamps high", Vector.smoothstep(a, b, 2) == b)
	check("smoothstep midpoint equals lerp midpoint",
		Vector.smoothstep(a, b, 0.5) == Vector.lerp(a, b, 0.5))
	check("smoothstep errors on bad args", pcall(Vector.smoothstep, a, nil, 0.5) == false)

	check("move_towards steps", Vector.move_towards(Vector.zero, Vector(10, 0, 0), 3) == Vector(3, 0, 0))
	check("move_towards snaps when in range",
		Vector.move_towards(Vector.zero, Vector(10, 0, 0), 20) == Vector(10, 0, 0))
	local stepped = Vector.move_towards(Vector.zero, Vector(10, 0, 0), 0)
	check("move_towards zero delta stays (copy)", stepped == Vector.zero)
	check("move_towards coincident gives target",
		Vector.move_towards(Vector(1, 1, 1), Vector(1, 1, 1), 5) == Vector(1, 1, 1))
	check("move_towards errors on bad args", pcall(Vector.move_towards, {}, b, 1) == false)
end

function VectorTest.test_clamp_family()
	print("\n=== clamp/min/max/floor/ceil/round/abs Tests ===")

	check("clamp component-wise",
		Vector.clamp(Vector(5, -5, 0.5), Vector.zero, Vector.one) == Vector(1, 0, 0.5))
	check("clamp inside passes through",
		Vector.clamp(Vector(0.5, 0.5, 0.5), Vector.zero, Vector.one) == Vector(0.5, 0.5, 0.5))
	check("clamp errors unless three vectors", pcall(Vector.clamp, Vector.zero, Vector.zero) == false)

	local long = Vector(3, 4, 0)
	check("clamp_length within returns equal copy",
		Vector.clamp_length(long, 5) == long and Vector.clamp_length(long, 10) == long)
	check("clamp_length scales down", Vector.clamp_length(long, 2.5) == Vector(1.5, 2, 0))
	check("clamp_length zero stays zero", Vector.clamp_length(Vector.zero, 5) == Vector.zero)
	check("clamp_length negative max gives zero", Vector.clamp_length(long, -2) == Vector.zero)

	check("min component-wise", Vector.min(Vector(1, 5, 3), Vector(4, 2, 6)) == Vector(1, 2, 3))
	check("max component-wise", Vector.max(Vector(1, 5, 3), Vector(4, 2, 6)) == Vector(4, 5, 6))
	check("min errors on bad args", pcall(Vector.min, Vector.zero, nil) == false)
	check("max errors on bad args", pcall(Vector.max, 1, Vector.zero) == false)

	check("floor components", Vector.floor(Vector(1.2, 2.7, -1.2)) == Vector(1, 2, -2))
	check("ceil components", Vector.ceil(Vector(1.2, 2.7, -1.2)) == Vector(2, 3, -1))
	check("round components", Vector.round(Vector(1.2, 2.7, -1.2)) == Vector(1, 3, -1))
	check("round half up", Vector.round(Vector(2.5, -2.5, 0.5)) == Vector(3, -2, 1))
	check("abs components", Vector.abs(Vector(-1, -2.5, 3)) == Vector(1, 2.5, 3))
	check("floor errors on bad arg", pcall(Vector.floor, {}) == false)
	check("ceil errors on bad arg", pcall(Vector.ceil, {}) == false)
	check("round errors on bad arg", pcall(Vector.round, {}) == false)
	check("abs errors on bad arg", pcall(Vector.abs, {}) == false)
end

function VectorTest.test_cross_project_reject_reflect()
	print("\n=== cross/project/reject/reflect Tests ===")

	-- Default (unreal, left-handed): x cross y = -z.
	check("left-handed cross", Vector.cross(Vector.unit_x, Vector.unit_y) == Vector(0, 0, -1))
	check("cross anti-commutes", Vector.cross(Vector.unit_x, Vector.unit_y) == -Vector.cross(Vector.unit_y, Vector.unit_x))
	check("cross parallel is zero", Vector.cross(Vector.unit_x, Vector(2, 0, 0)) == Vector.zero)
	check("module cross matches method cross", Vector.cross == Vector(1, 0, 0).cross)

	check("project onto axis", Vector.project(Vector(2, 3, 0), Vector.unit_x) == Vector(2, 0, 0))
	check("project onto zero gives zero", Vector.project(Vector(1, 2, 3), Vector.zero) == Vector.zero)
	check("project errors on bad args", pcall(Vector.project, Vector.unit_x, 1) == false)

	check("reject perpendicular part", Vector.reject(Vector(2, 3, 0), Vector.unit_x) == Vector(0, 3, 0))
	check("project plus reject reconstructs",
		vec_near(Vector.project(Vector(2, 3, 4), Vector(1, 1, 1))
			+ Vector.reject(Vector(2, 3, 4), Vector(1, 1, 1)), Vector(2, 3, 4)))
	-- Zero divisor returns a fresh zero vector (documents current behavior).
	check("reject onto zero gives zero", Vector.reject(Vector(1, 2, 3), Vector.zero) == Vector.zero)
	check("reject errors on bad args", pcall(Vector.reject, nil, Vector.unit_x) == false)

	check("reflect across normal", Vector.reflect(Vector(1, -1, 0), Vector.unit_y) == Vector(1, 1, 0))
	check("reflect across self negates unit", Vector.reflect(Vector.unit_z, Vector.unit_z) == -Vector.unit_z)
	check("reflect errors on bad args", pcall(Vector.reflect, Vector.unit_x, {}) == false)
end

function VectorTest.test_orthogonal_perpendicular()
	print("\n=== orthogonal_to/perpendicular_2d Tests ===")

	for i, v in ipairs({ Vector(1, 0, 0), Vector(0, 1, 0), Vector(0, 0, 1), Vector(1, 2, 3), Vector(-4, 0.5, 7) }) do
		local o = Vector.orthogonal_to(v)
		check(string.format("orthogonal_to #%d is perpendicular", i), near(Vector.dot(o, v), 0, 1e-9))
		check(string.format("orthogonal_to #%d is non-zero", i), Vector.length_squared(o) > 0)
	end
	check("orthogonal_to zero gives unit_x", Vector.orthogonal_to(Vector.zero) == Vector.unit_x)

	check("perpendicular_2d rotates XY", Vector.perpendicular_2d(Vector(3, 4, 5)) == Vector(-4, 3, 0))
	check("perpendicular_2d drops z", Vector.perpendicular_2d(Vector(3, 4, 5)).z == 0)
	check("perpendicular_2d zero gives zero", Vector.perpendicular_2d(Vector.zero) == Vector.zero)
	check("perpendicular_2d errors on bad arg", pcall(Vector.perpendicular_2d, {}) == false)
end

function VectorTest.test_rotations()
	print("\n=== rotate_x/rotate_y/rotate_z/rotate_around Tests ===")

	local half_pi = math.pi / 2
	check("rotate_x 90deg", vec_near(Vector.rotate_x(Vector(0, 1, 0), half_pi), Vector(0, 0, 1)))
	check("rotate_x 180deg", vec_near(Vector.rotate_x(Vector(0, 1, 0), math.pi), Vector(0, -1, 0)))
	check("rotate_y 90deg", vec_near(Vector.rotate_y(Vector(1, 0, 0), half_pi), Vector(0, 0, -1)))
	check("rotate_z 90deg", vec_near(Vector.rotate_z(Vector(1, 0, 0), half_pi), Vector(0, 1, 0)))
	check("rotate_x zero angle is identity",
		vec_near(Vector.rotate_x(Vector(1, 2, 3), 0), Vector(1, 2, 3)))
	check("rotate_y full turn is identity",
		vec_near(Vector.rotate_y(Vector(1, 2, 3), math.pi * 2), Vector(1, 2, 3), 1e-9))
	check("rotate_x errors on bad arg", pcall(Vector.rotate_x, {}, 1) == false)
	check("rotate_y errors on bad arg", pcall(Vector.rotate_y, nil, 1) == false)
	check("rotate_z errors on bad arg", pcall(Vector.rotate_z, "x", 1) == false)

	check("rotate_around z 90deg",
		vec_near(Vector.rotate_around(Vector(1, 0, 0), Vector.unit_z, half_pi), Vector(0, 1, 0)))
	check("rotate_around own axis is identity",
		vec_near(Vector.rotate_around(Vector(1, 2, 3), Vector.normalized(Vector(1, 2, 3)), 1.3), Vector(1, 2, 3)))
	check("rotate_around zero angle is identity",
		vec_near(Vector.rotate_around(Vector(1, 0, 0), Vector.unit_y, 0), Vector(1, 0, 0)))
	check("rotate_around errors on bad vec", pcall(Vector.rotate_around, {}, Vector.unit_z, 1) == false)
	check("rotate_around errors on bad axis", pcall(Vector.rotate_around, Vector.unit_x, {}, 1) == false)
end

function VectorTest.test_look_at_spherical()
	print("\n=== look_at/from_spherical/to_spherical Tests ===")

	check("look_at axis aligned", Vector.look_at(Vector.zero, Vector(0, 0, 5)) == Vector(0, 0, 1))
	local dir = Vector.look_at(Vector.zero, Vector(1, 1, 1))
	check("look_at is normalized", near(Vector.length(dir), 1))
	check("look_at points at target", vec_near(dir, Vector.normalized(Vector(1, 1, 1))))
	check("look_at coincident gives +z", Vector.look_at(Vector(1, 1, 1), Vector(1, 1, 1)) == Vector(0, 0, 1))
	check("look_at errors on bad args", pcall(Vector.look_at, Vector.zero, {}) == false)

	check("from_spherical equator", vec_near(Vector.from_spherical(1, 0, math.pi / 2), Vector(1, 0, 0)))
	check("from_spherical pole", vec_near(Vector.from_spherical(2, 7, 0), Vector(0, 0, 2)))
	check("to_spherical +z", (function()
		local r, theta, phi = Vector.to_spherical(Vector.unit_z)
		return near(r, 1) and near(theta, 0) and near(phi, 0)
	end)())
	check("to_spherical zero gives zeros", (function()
		local r, theta, phi = Vector.to_spherical(Vector.zero)
		return r == 0 and theta == 0 and phi == 0
	end)())
	for i, v in ipairs({ Vector(1, 2, 3), Vector(0, 0, -5), Vector(-1, -2, -3) }) do
		local r, theta, phi = Vector.to_spherical(v)
		check(string.format("spherical roundtrip #%d", i), vec_near(Vector.from_spherical(r, theta, phi), v))
	end
	check("to_spherical errors on bad arg", pcall(Vector.to_spherical, {}) == false)
end

function VectorTest.test_random()
	print("\n=== random/random_unit Tests ===")

	for _ = 1, 5 do
		local r = Vector.random(0, 10)
		check("random components in range",
			r.x >= 0 and r.x <= 10 and r.y >= 0 and r.y <= 10 and r.z >= 0 and r.z <= 10)
	end
	local rn = Vector.random(-5, 5)
	check("random negative range", rn.x >= -5 and rn.x <= 5 and rn.y >= -5 and rn.y <= 5 and rn.z >= -5 and rn.z <= 5)
	check("random equal bounds gives constant", Vector.random(3, 3) == Vector(3, 3, 3))
	for _ = 1, 5 do
		local u = Vector.random_unit()
		check("random_unit has unit length", near(Vector.length(u), 1, 1e-9))
		check("random_unit passes is_near unit check",
			Vector.is_near(u, Vector.normalized(u), 1e-9) or near(Vector.length_squared(u), 1, 1e-9))
	end
end

function VectorTest.test_is_zero_is_near()
	print("\n=== is_zero/is_near Tests ===")

	check("is_zero true for zero", Vector.is_zero(Vector.zero))
	check("is_zero within default epsilon", Vector.is_zero(Vector(1e-7, 0, 0)))
	check("is_zero outside default epsilon", not Vector.is_zero(Vector(1e-5, 0, 0)))
	check("is_zero custom epsilon", Vector.is_zero(Vector(1e-5, 0, 0), 1e-4))
	check("is_zero rejects unit", not Vector.is_zero(Vector.unit_x))
	check("is_zero errors on bad arg", pcall(Vector.is_zero, {}) == false)

	check("is_near identical", Vector.is_near(Vector(1, 2, 3), Vector(1, 2, 3)))
	check("is_near within default epsilon", Vector.is_near(Vector.zero, Vector(1e-7, 0, 0)))
	check("is_near outside default epsilon", not Vector.is_near(Vector.zero, Vector(1e-5, 0, 0)))
	check("is_near custom epsilon", Vector.is_near(Vector.zero, Vector(1e-5, 0, 0), 1e-4))
	check("is_near errors unless two vectors", pcall(Vector.is_near, Vector.zero, nil) == false)
	check("is_near errors on swapped bad args", pcall(Vector.is_near, 1, Vector.zero) == false)
end

function VectorTest.test_conversions()
	print("\n=== to_array/to_table/from_table Tests ===")

	local v = Vector(1, 2, 3)
	local arr = Vector.to_array(v)
	check("to_array values", arr[1] == 1 and arr[2] == 2 and arr[3] == 3 and #arr == 3)
	arr[1] = 99
	check("to_array returns fresh table", v == Vector(1, 2, 3))
	check("to_array errors on bad arg", pcall(Vector.to_array, {}) == false)

	local tbl = Vector.to_table(v)
	check("to_table keys", tbl.x == 1 and tbl.y == 2 and tbl.z == 3)
	tbl.x = 99
	check("to_table returns fresh table", v == Vector(1, 2, 3))
	check("to_table errors on bad arg", pcall(Vector.to_table, nil) == false)

	check("from_table keyed", Vector.from_table({ x = 1, y = 2, z = 3 }) == v)
	check("from_table indexed", Vector.from_table({ 1, 2, 3 }) == v)
	check("from_table prefers named keys", Vector.from_table({ x = 9, [1] = 1, y = 2, [2] = 2, z = 3, [3] = 3 }) == Vector(9, 2, 3))
	check("from_table empty gives zero", Vector.from_table({}) == Vector.zero)
	check("from_table errors on nil", pcall(Vector.from_table, nil) == false)
end

function VectorTest.test_coordinate_systems()
	print("\n=== Coordinate System Tests ===")

	check("default system is unreal", Vector.get_coordinate_system().name == "unreal")
	check("default handedness is left", Vector.get_coordinate_system().handedness == "left")

	local systems = Vector.get_available_coordinate_systems()
	local found = {}
	for _, name in ipairs(systems) do
		found[name] = true
	end
	check("all five systems available",
		found.unreal and found.source and found.unity and found.godot and found.blender)
	check("available count is five", #systems == 5)

	-- Same-system transform returns an equal but independent clone.
	local src = Vector(1, 2, 3)
	local same = Vector.transform_coordinate_system(src, "unreal", "unreal")
	check("same-system transform clones", same == src and not rawequal(same, src))

	-- Axis remap unreal -> unity plus handedness is unchanged (both left).
	check("transform unreal->unity remaps axes",
		Vector.transform_coordinate_system(Vector(1, 2, 3), "unreal", "unity") == Vector(3, 2, 3))
	-- unreal -> godot additionally flips x for the handedness change.
	check("transform unreal->godot flips x",
		Vector.transform_coordinate_system(Vector(1, 2, 3), "unreal", "godot") == Vector(-3, 2, 3))
	check("transform accepts system tables",
		Vector.transform_coordinate_system(src, Vector.get_coordinate_system(), "unity")
		== Vector.transform_coordinate_system(src, "unreal", "unity"))
	-- NOTE: unknown string names do NOT error; the lookup falls back to the
	-- raw string, whose nil handedness mismatches and negates x. Only nil
	-- (or otherwise falsy-resolved) systems hit the error branch.
	check("transform tolerates unknown from system (documents current behavior)",
		Vector.transform_coordinate_system(Vector(1, 2, 3), "nope", "unreal") == Vector(-1, 2, 3))
	check("transform tolerates unknown to system (documents current behavior)",
		Vector.transform_coordinate_system(Vector(1, 2, 3), "unreal", "nope") == Vector(-1, 2, 3))
	check("transform errors on nil systems",
		pcall(Vector.transform_coordinate_system, src, nil, nil) == false)

	-- Switch to a right-handed system and verify cross flips.
	Vector.set_coordinate_system("godot")
	check("godot system selected", Vector.get_coordinate_system().name == "godot")
	check("godot is right-handed", Vector.get_coordinate_system().handedness == "right")
	check("right-handed cross", Vector.cross(Vector.unit_x, Vector.unit_y) == Vector(0, 0, 1))
	check("godot forward/up", Vector.forward == Vector(0, 0, 1) and Vector.up == Vector(0, 1, 0))
	check("godot right/left", Vector.right == Vector(-1, 0, 0) and Vector.left == Vector(1, 0, 0))
	check("instances see handedness-aware cross", Vector(1, 0, 0).cross == Vector.cross)

	-- Custom table configuration takes effect.
	Vector.set_coordinate_system({ handedness = "right", up_axis = "y", forward_axis = "z", name = "custom" })
	check("custom system selected", Vector.get_coordinate_system().name == "custom")
	check("custom system is right-handed", Vector.cross(Vector.unit_x, Vector.unit_y) == Vector(0, 0, 1))

	check("set errors on unknown name", pcall(Vector.set_coordinate_system, "nope") == false)

	-- Restore defaults so later suites observe the stock configuration.
	Vector.set_coordinate_system("unreal")
	check("restored to unreal", Vector.get_coordinate_system().name == "unreal")
	check("cross restored to left-handed", Vector.cross(Vector.unit_x, Vector.unit_y) == Vector(0, 0, -1))
	check("directions restored", Vector.forward == Vector(1, 0, 0) and Vector.up == Vector(0, 0, 1))
end

-- Run all tests.
function VectorTest.run_all()
	print("=== Vector Test Suite ===")
	pass_count = 0
	fail_count = 0

	VectorTest.test_constructor()
	VectorTest.test_constants()
	VectorTest.test_is()
	VectorTest.test_index_newindex()
	VectorTest.test_arithmetic()
	VectorTest.test_len_tostring_concat()
	VectorTest.test_eq_order()
	VectorTest.test_clone_set_unpack()
	VectorTest.test_dot_length_normalize()
	VectorTest.test_distances()
	VectorTest.test_angle()
	VectorTest.test_interpolation()
	VectorTest.test_clamp_family()
	VectorTest.test_cross_project_reject_reflect()
	VectorTest.test_orthogonal_perpendicular()
	VectorTest.test_rotations()
	VectorTest.test_look_at_spherical()
	VectorTest.test_random()
	VectorTest.test_is_zero_is_near()
	VectorTest.test_conversions()
	VectorTest.test_coordinate_systems()

	print(string.format("\n=== Test Suite Complete: %d passed, %d failed ===", pass_count, fail_count))
	if fail_count ~= 0 then
		os.exit(1)
	end
	print("All tests passed")
end

VectorTest.run_all()

return VectorTest
