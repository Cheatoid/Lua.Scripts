-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for matrix4x4.lua.
-- Run from this directory:
--   lua matrix4x4.lua
--   luajit matrix4x4.lua

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

local Matrix4x4 = require "matrix4x4"
local Vector = require "vector"
local AABB = require "aabb"

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

local function mat_near(a, b, eps)
	eps = eps or 1e-6
	return Matrix4x4.is_near(a, b, eps)
end

local function test_new()
	print("\n=== new Tests ===")
	local ident = Matrix4x4.new()
	check("new() identity diag", ident[1] == 1 and ident[6] == 1 and ident[11] == 1 and ident[16] == 1)
	check("new() identity off-diag", ident[2] == 0 and ident[5] == 0 and ident[13] == 0)
	check("new() is matrix", Matrix4x4.is(ident))
	check("call shorthand is matrix", Matrix4x4()._ == nil or Matrix4x4.is(Matrix4x4()))
	local m16 = Matrix4x4(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16)
	check("new 16 args first", m16[1] == 1)
	check("new 16 args last", m16[16] == 16)
	check("new 16 args middle", m16[6] == 6 and m16[11] == 11)
	local mtbl = Matrix4x4.new({ 5, 6, 7 })
	check("new table values", mtbl[1] == 5 and mtbl[2] == 6 and mtbl[3] == 7)
	check("new table pads zero", mtbl[4] == 0 and mtbl[16] == 0)
	check("new table is matrix", Matrix4x4.is(mtbl))
	local bad2 = Matrix4x4.new(1, 2)
	check("new invalid 2 args falls back to identity", Matrix4x4.is_identity(bad2))
	local bad3 = Matrix4x4.new(1, 2, 3)
	check("new invalid 3 args falls back to identity", Matrix4x4.is_identity(bad3))
	check("identity export is matrix", Matrix4x4.is(Matrix4x4.identity))
	check("identity export is identity", Matrix4x4.is_identity(Matrix4x4.identity))
end

local function test_is()
	print("\n=== is Tests ===")
	check("is true for new", Matrix4x4.is(Matrix4x4.new()))
	check("is false for plain table", Matrix4x4.is({}) == false)
	check("is false for nil", Matrix4x4.is(nil) == false)
	check("is false for number", Matrix4x4.is(42) == false)
end

local function test_arithmetic()
	print("\n=== Arithmetic Tests ===")
	local a = Matrix4x4.new(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16)
	local b = Matrix4x4.new(16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1)
	local s = a + b
	check("add first", s[1] == 17)
	check("add last", s[16] == 17)
	check("add middle", s[8] == 17)
	check("add result is matrix", Matrix4x4.is(s))
	local d = a - b
	check("sub first", d[1] == -15)
	check("sub last", d[16] == 15)
	check("sub errors on scalar", pcall(function() return a + 1 end) == false)
	check("sub errors on plain table", pcall(function() return a - {} end) == false)
	local ident = Matrix4x4.new()
	check("mat*mat identity left", mat_near(ident * a, a))
	check("mat*mat identity right", mat_near(a * ident, a))
	local sc2 = Matrix4x4.scale(2, 2, 2)
	local sc3 = Matrix4x4.scale(3, 3, 3)
	local prod = sc2 * sc3
	check("mat*mat scale diag", near(prod[1], 6) and near(prod[6], 6) and near(prod[11], 6))
	check("mat*scalar", (a * 2)[1] == 2 and (a * 2)[16] == 32)
	check("scalar*mat", (2 * a)[1] == 2 and (2 * a)[16] == 32)
	check("mul errors on two non-matrices", pcall(function() return Matrix4x4.new() * {} end) == false)
	local h = a / 2
	check("div first", near(h[1], 0.5))
	check("div last", near(h[16], 8))
	check("div by zero errors", pcall(function() return a / 0 end) == false)
	check("div by string errors", pcall(function() return a / "x" end) == false)
	check("div non-matrix errors", pcall(function() return Matrix4x4.get({}, 1, 1) end) == false)
	local n = -ident
	check("unm diag", n[1] == -1 and n[6] == -1 and n[16] == -1)
	check("unm off-diag zero", n[2] == 0 and n[5] == 0)
	local same = Matrix4x4.new(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16)
	check("eq true", a == same)
	check("eq false", not (a == b))
	check("eq vs plain table false", (a == {}) == false)
	local str = tostring(ident)
	check("tostring contains tag", string.find(str, "Matrix4x4", 1, true) ~= nil)
	check("tostring contains 1", string.find(str, "1", 1, true) ~= nil)
end

local function test_clone_transpose()
	print("\n=== clone/transpose Tests ===")
	local a = Matrix4x4.new(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16)
	local c = Matrix4x4.clone(a)
	check("clone equal", c == a)
	check("clone distinct table", not rawequal(c, a))
	check("clone errors on non-matrix", pcall(Matrix4x4.clone, {}) == false)
	local t = Matrix4x4.transpose(a)
	check("transpose swaps", t[2] == a[5] and t[5] == a[2] and t[4] == a[13])
	check("transpose diag same", t[1] == a[1] and t[6] == a[6])
	check("double transpose roundtrip", Matrix4x4.transpose(t) == a)
	check("transpose errors on non-matrix", pcall(Matrix4x4.transpose, {}) == false)
end

local function test_determinant_inverse()
	print("\n=== determinant/inverse Tests ===")
	check("determinant identity is 1", near(Matrix4x4.determinant(Matrix4x4.new()), 1))
	local singular = Matrix4x4.new(1, 2, 3, 4, 1, 2, 3, 4, 1, 2, 3, 4, 1, 2, 3, 4)
	check("determinant singular is 0", Matrix4x4.determinant(singular) == 0)
	check("determinant scale 2,3,4 is 24", near(Matrix4x4.determinant(Matrix4x4.scale(2, 3, 4)), 24))
	check("determinant errors on non-matrix", pcall(Matrix4x4.determinant, {}) == false)
	local inv_ident = Matrix4x4.inverse(Matrix4x4.new())
	check("inverse identity diag", near(inv_ident[1], 1) and near(inv_ident[16], 1))
	local sc = Matrix4x4.scale(2, 4, 8)
	local inv = Matrix4x4.inverse(sc)
	check("inverse scale x", near(inv[1], 0.5))
	check("inverse scale y", near(inv[6], 0.25))
	check("inverse scale z", near(inv[11], 0.125))
	local roundtrip = sc * inv
	check("inverse roundtrip near identity", mat_near(roundtrip, Matrix4x4.new(), 1e-6))
	local a = Matrix4x4.new(2, 0, 0, 0, 0, 3, 0, 0, 0, 0, 4, 0, 5, 6, 7, 1)
	local back = a * Matrix4x4.inverse(a)
	check("inverse general roundtrip", mat_near(back, Matrix4x4.new(), 1e-5))
	check("inverse singular errors", pcall(Matrix4x4.inverse, Matrix4x4.new(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)) == false)
	check("inverse errors on non-matrix", pcall(Matrix4x4.inverse, {}) == false)
end

local function test_constructors()
	print("\n=== translation/scale/rotation Tests ===")
	local tr = Matrix4x4.translation(5, 6, 7)
	check("translation stores x", tr[13] == 5)
	check("translation stores y", tr[14] == 6)
	check("translation stores z", tr[15] == 7)
	check("translation diag", tr[1] == 1 and tr[16] == 1)
	local sc = Matrix4x4.scale(2, 3, 4)
	check("scale diag", sc[1] == 2 and sc[6] == 3 and sc[11] == 4 and sc[16] == 1)
	check("scale off-diag zero", sc[2] == 0 and sc[5] == 0)
	local rx0 = Matrix4x4.rotation_x(0)
	check("rotation_x(0) identity", mat_near(rx0, Matrix4x4.new(), 1e-9))
	local ry0 = Matrix4x4.rotation_y(0)
	check("rotation_y(0) identity", mat_near(ry0, Matrix4x4.new(), 1e-9))
	local rz0 = Matrix4x4.rotation_z(0)
	check("rotation_z(0) identity", mat_near(rz0, Matrix4x4.new(), 1e-9))
	local rx = Matrix4x4.rotation_x(math.pi * 0.5)
	check("rotation_x 90deg cos", near(rx[6], 0, 1e-6) and near(rx[7], 1, 1e-6))
	local ry = Matrix4x4.rotation_y(math.pi * 0.5)
	check("rotation_y 90deg", near(ry[1], 0, 1e-6) and near(ry[3], -1, 1e-6))
	local rz = Matrix4x4.rotation_z(math.pi * 0.5)
	check("rotation_z 90deg", near(rz[1], 0, 1e-6) and near(rz[2], 1, 1e-6))
	local re0 = Matrix4x4.rotation_euler(0, 0, 0)
	check("rotation_euler zero identity", mat_near(re0, Matrix4x4.new(), 1e-9))
	local re = Matrix4x4.rotation_euler(0.1, 0.2, 0.3)
	check("rotation_euler is matrix", Matrix4x4.is(re))
end

local function test_projections()
	print("\n=== Projection Tests ===")
	check("perspective ok", pcall(Matrix4x4.perspective, 1, 1.33, 0.1, 100) == true)
	check("perspective near zero errors", pcall(Matrix4x4.perspective, 1, 1.33, 0, 100) == false)
	check("perspective far<=near errors", pcall(Matrix4x4.perspective, 1, 1.33, 100, 0.1) == false)
	check("perspective aspect zero errors", pcall(Matrix4x4.perspective, 1, 0, 0.1, 100) == false)
	check("perspective_lrbt ok", pcall(Matrix4x4.perspective_lrbt, -1, 1, -1, 1, 0.1, 100) == true)
	check("perspective_lrbt bad near errors", pcall(Matrix4x4.perspective_lrbt, -1, 1, -1, 1, 0, 100) == false)
	check("perspective_lrbt left==right errors", pcall(Matrix4x4.perspective_lrbt, 1, 1, -1, 1, 0.1, 100) == false)
	check("perspective_lrbt bottom==top errors", pcall(Matrix4x4.perspective_lrbt, -1, 1, 1, 1, 0.1, 100) == false)
	check("orthographic ok", pcall(Matrix4x4.orthographic, -1, 1, -1, 1, 0.1, 100) == true)
	check("orthographic left==right errors", pcall(Matrix4x4.orthographic, 1, 1, -1, 1, 0.1, 100) == false)
	check("orthographic bottom==top errors", pcall(Matrix4x4.orthographic, -1, 1, 2, 2, 0.1, 100) == false)
	check("orthographic near==far errors", pcall(Matrix4x4.orthographic, -1, 1, -1, 1, 5, 5) == false)
end

local function test_look_at()
	print("\n=== look_at Tests ===")
	local la = Matrix4x4.look_at(Vector(0, 0, 5), Vector(0, 0, 0))
	check("look_at returns matrix", Matrix4x4.is(la))
	check("look_at forward axis", near(la[1], 1) and la[16] == 1)
	local with_tbl = Matrix4x4.look_at({ x = 0, y = 0, z = 5 }, { x = 0, y = 0, z = 0 })
	check("look_at accepts plain tables", Matrix4x4.is(with_tbl))
	local with_default_up = Matrix4x4.look_at(Vector(0, 0, 5), Vector(0, 0, 0), nil)
	check("look_at default up works", Matrix4x4.is(with_default_up))
	check("look_at eye==target errors", pcall(Matrix4x4.look_at, Vector(0, 0, 0), Vector(0, 0, 0)) == false)
	check("look_at parallel up errors", pcall(Matrix4x4.look_at, Vector(0, 0, 0), Vector(0, 1, 0), Vector(0, 1, 0)) == false)
	check("look_at bad args errors", pcall(Matrix4x4.look_at, nil, Vector(0, 0, 0)) == false)
end

local function test_frustum()
	print("\n=== Frustum Tests ===")
	local frustum = Matrix4x4.extract_frustum(Matrix4x4.new())
	check("extract_frustum returns 6 planes", type(frustum) == "table" and #frustum == 6)
	check("extract_frustum errors on non-matrix", pcall(Matrix4x4.extract_frustum, {}) == false)
	check("point inside identity frustum", Matrix4x4.point_in_frustum(Vector(0, 0, 0), frustum) == true)
	check("point outside identity frustum", Matrix4x4.point_in_frustum(Vector(2, 0, 0), frustum) == false)
	check("point far z outside", Matrix4x4.point_in_frustum(Vector(0, 0, 2), frustum) == false)
	check("point_in_frustum errors on bad frustum", pcall(Matrix4x4.point_in_frustum, Vector(0, 0, 0), {}) == false)
	check("point_in_frustum errors on bad point", pcall(Matrix4x4.point_in_frustum, nil, frustum) == false)
	local inside_box = AABB(Vector(-0.5, -0.5, -0.5), Vector(0.5, 0.5, 0.5))
	local outside_box = AABB(Vector(5, 5, 5), Vector(6, 6, 6))
	check("aabb inside frustum", Matrix4x4.aabb_in_frustum(inside_box, frustum) == true)
	check("aabb outside frustum", Matrix4x4.aabb_in_frustum(outside_box, frustum) == false)
	check("aabb_in_frustum errors on bad frustum", pcall(Matrix4x4.aabb_in_frustum, inside_box, {}) == false)
	check("sphere inside frustum", Matrix4x4.sphere_in_frustum(Vector(0, 0, 0), 0.5, frustum) == true)
	check("sphere outside frustum", Matrix4x4.sphere_in_frustum(Vector(5, 5, 5), 0.5, frustum) == false)
	check("sphere edge intersects", Matrix4x4.sphere_in_frustum(Vector(1, 0, 0), 0.5, frustum) == true)
	check("sphere_in_frustum errors on bad frustum", pcall(Matrix4x4.sphere_in_frustum, Vector(0, 0, 0), 1, {}) == false)
end

local function test_table_access()
	print("\n=== to_table/get/set Tests ===")
	local a = Matrix4x4.new(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16)
	local tbl = Matrix4x4.to_table(a)
	check("to_table first", tbl[1] == 1)
	check("to_table last", tbl[16] == 16)
	check("to_table length", #tbl == 16)
	check("to_table errors on non-matrix", pcall(Matrix4x4.to_table, {}) == false)
	local back = Matrix4x4.from_table(tbl)
	check("from_table roundtrip", back == a)
	local partial = Matrix4x4.from_table({ 1, 2, 3 })
	check("from_table partial pads zero", partial[1] == 1 and partial[4] == 0 and partial[16] == 0)
	check("from_table errors on non-table", pcall(Matrix4x4.from_table, 123) == false)
	check("get (2,3) is 7", Matrix4x4.get(a, 2, 3) == 7)
	check("get (1,1) is 1", Matrix4x4.get(a, 1, 1) == 1)
	check("get (4,4) is 16", Matrix4x4.get(a, 4, 4) == 16)
	check("get row out of bounds errors", pcall(Matrix4x4.get, a, 5, 1) == false)
	check("get col out of bounds errors", pcall(Matrix4x4.get, a, 1, 0) == false)
	check("get errors on non-matrix", pcall(Matrix4x4.get, {}, 1, 1) == false)
	local m = Matrix4x4.clone(a)
	Matrix4x4.set(m, 1, 1, 99)
	check("set stores value", m[1] == 99)
	check("set errors row bounds", pcall(Matrix4x4.set, a, 5, 1, 1) == false)
	check("set errors col bounds", pcall(Matrix4x4.set, a, 1, 5, 1) == false)
	check("set errors on non-matrix", pcall(Matrix4x4.set, {}, 1, 1, 1) == false)
	local row = Matrix4x4.get_row(a, 2)
	check("get_row values", row[1] == 5 and row[2] == 6 and row[3] == 7 and row[4] == 8)
	check("get_row errors bounds", pcall(Matrix4x4.get_row, a, 5) == false)
	check("get_row errors on non-matrix", pcall(Matrix4x4.get_row, {}, 1) == false)
	local col = Matrix4x4.get_column(a, 2)
	check("get_column values", col[1] == 2 and col[2] == 6 and col[3] == 10 and col[4] == 14)
	check("get_column errors bounds", pcall(Matrix4x4.get_column, a, 5) == false)
	check("get_column errors on non-matrix", pcall(Matrix4x4.get_column, {}, 1) == false)
end

local function test_multiply_vector()
	print("\n=== multiply_vector Tests ===")
	local ident = Matrix4x4.new()
	local v = Matrix4x4.multiply_vector(ident, Vector(1, 2, 3))
	check("multiply identity preserves", v[1] == 1 and v[2] == 2 and v[3] == 3)
	local sc = Matrix4x4.scale(2, 3, 4)
	local sv = Matrix4x4.multiply_vector(sc, Vector(1, 1, 1))
	check("multiply scale", sv[1] == 2 and sv[2] == 3 and sv[3] == 4)
	check("multiply_vector errors on non-vector", pcall(Matrix4x4.multiply_vector, ident, { x = 1 }) == false)
	check("multiply_vector errors on plain table", pcall(Matrix4x4.multiply_vector, ident, {}) == false)
	check("multiply_vector errors on non-matrix", pcall(Matrix4x4.multiply_vector, {}, Vector(0, 0, 0)) == false)
end

local function test_predicates_distances()
	print("\n=== is_identity/is_near/distance Tests ===")
	check("is_identity true", Matrix4x4.is_identity(Matrix4x4.new()) == true)
	check("is_identity false", Matrix4x4.is_identity(Matrix4x4.new(2, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)) == false)
	check("is_identity custom epsilon", Matrix4x4.is_identity(Matrix4x4.new(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1.00001), 0.001) == true)
	check("is_identity errors on non-matrix", pcall(Matrix4x4.is_identity, {}) == false)
	check("is_near identical", Matrix4x4.is_near(Matrix4x4.new(), Matrix4x4.clone(Matrix4x4.new())) == true)
	check("is_near different", Matrix4x4.is_near(Matrix4x4.new(), Matrix4x4.scale(2, 2, 2)) == false)
	check("is_near errors on bad args", pcall(Matrix4x4.is_near, Matrix4x4.new(), {}) == false)
	local ident = Matrix4x4.new()
	check("distance identical is 0", Matrix4x4.distance(ident, ident) == 0)
	check("distance_squared identical is 0", Matrix4x4.distance_squared(ident, ident) == 0)
	check("distance_manhattan identical is 0", Matrix4x4.distance_manhattan(ident, ident) == 0)
	check("distance_chebyshev identical is 0", Matrix4x4.distance_chebyshev(ident, ident) == 0)
	local other = Matrix4x4.new(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 2)
	check("distance single diff is 1", near(Matrix4x4.distance(ident, other), 1))
	check("distance_squared single diff is 1", near(Matrix4x4.distance_squared(ident, other), 1))
	check("distance_manhattan single diff is 1", near(Matrix4x4.distance_manhattan(ident, other), 1))
	check("distance_chebyshev single diff is 1", near(Matrix4x4.distance_chebyshev(ident, other), 1))
	check("distance errors on bad args", pcall(Matrix4x4.distance, ident, {}) == false)
	check("distance_squared errors on bad args", pcall(Matrix4x4.distance_squared, ident, {}) == false)
	check("distance_manhattan errors on bad args", pcall(Matrix4x4.distance_manhattan, ident, {}) == false)
	check("distance_chebyshev errors on bad args", pcall(Matrix4x4.distance_chebyshev, ident, {}) == false)
	local a = Matrix4x4.new(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16)
	local b = Matrix4x4.new(16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1)
	check("minkowski p<1 errors", pcall(Matrix4x4.distance_minkowski, ident, ident, 0.5) == false)
	check("minkowski p=1 matches manhattan", near(Matrix4x4.distance_minkowski(ident, a, 1), Matrix4x4.distance_manhattan(ident, a)))
	check("minkowski p=2 matches euclidean", near(Matrix4x4.distance_minkowski(ident, a, 2), Matrix4x4.distance(ident, a)))
	check("minkowski inf matches chebyshev", near(Matrix4x4.distance_minkowski(ident, a, math.huge), Matrix4x4.distance_chebyshev(ident, a)))
	check("minkowski custom p=3 single diff is 1", near(Matrix4x4.distance_minkowski(ident, other, 3), 1))
	check("minkowski default is euclidean", near(Matrix4x4.distance_minkowski(ident, a), Matrix4x4.distance(ident, a)))
	check("minkowski errors on bad args", pcall(Matrix4x4.distance_minkowski, ident, {}) == false)
	check("minkowski cross-check b", near(Matrix4x4.distance_minkowski(a, b, 1), Matrix4x4.distance_manhattan(a, b)))
end

local function run_all()
	print("=== Matrix4x4 Test Suite ===")
	pass_count = 0
	fail_count = 0
	test_new()
	test_is()
	test_arithmetic()
	test_clone_transpose()
	test_determinant_inverse()
	test_constructors()
	test_projections()
	test_look_at()
	test_frustum()
	test_table_access()
	test_multiply_vector()
	test_predicates_distances()
	print(string.format("\nTests finished: %d passed, %d failed", pass_count, fail_count))
	if fail_count > 0 then
		os.exit(1)
	end
end

if arg and arg[0] and arg[0]:match("matrix4x4%.lua$") then
	run_all()
end

return { run_all = run_all }
