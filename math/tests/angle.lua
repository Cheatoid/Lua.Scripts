-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for angle.lua.
-- Run from this directory:
--   lua angle.lua
--   luajit angle.lua

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
local Angle = require "angle"

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

print("=== Angle constructor / normalization ===")

do
	check("new default zero", Angle.new()[1] == 0)
	check("new nil zero", Angle.new(nil)[1] == 0)
	check("callable shorthand", Angle(1.5)[1] == Angle.new(1.5)[1])
	check("new zero", near(Angle.new(0)[1], 0))
	check("new pi stays pi", near(Angle.new(math.pi)[1], math.pi))
	check("new 2pi wraps zero", near(Angle.new(2 * math.pi)[1], 0))
	check("new 3pi wraps pi", near(Angle.new(3 * math.pi)[1], math.pi))
	check("new -2pi wraps zero", near(Angle.new(-2 * math.pi)[1], 0))
	check("new neg pi becomes pi", near(Angle.new(-math.pi)[1], math.pi))
	check("new 4pi wraps zero", near(Angle.new(4 * math.pi)[1], 0))
	check("new large wraps range", (function()
		local v = Angle.new(100)[1]
		return v >= -math.pi and v <= math.pi
	end)())
	check("new large negative wraps", (function()
		local v = Angle.new(-100)[1]
		return v >= -math.pi and v <= math.pi
	end)())
	check("new string coerced", near(Angle.new("1.5")[1], 1.5))
	check("new bad string zero", Angle.new("abc")[1] == 0)
	check("new bool zero", Angle.new(true)[1] == 0)
	check("normalize 0", near(Angle.normalize(0), 0))
	check("normalize pi", near(Angle.normalize(math.pi), math.pi))
	check("normalize 2pi zero", near(Angle.normalize(2 * math.pi), 0))
	check("normalize 3pi pi", near(Angle.normalize(3 * math.pi), math.pi))
	check("normalize nil zero", Angle.normalize(nil) == 0)
	check("normalize string", near(Angle.normalize("1.0"), 1.0))
	check("normalize matches new", near(Angle.normalize(5.5), Angle.new(5.5)[1]))
	check("from_rad alias", near(Angle.from_rad(1.2)[1], Angle.new(1.2)[1]))
	check("from_rad nil zero", Angle.from_rad(nil)[1] == 0)
	check("from_deg 180 pi", near(Angle.from_deg(180)[1], math.pi))
	check("from_deg 90 half pi", near(Angle.from_deg(90)[1], math.pi / 2))
	check("from_deg 0 zero", Angle.from_deg(0)[1] == 0)
	check("from_deg 360 zero", near(Angle.from_deg(360)[1], 0))
	check("from_deg -180 pi", near(Angle.from_deg(-180)[1], math.pi))
	check("from_deg nil zero", Angle.from_deg(nil)[1] == 0)
	check("from_deg string", near(Angle.from_deg("90")[1], math.pi / 2))
	check("is true", Angle.is(Angle.new(0)) == true)
	check("is rejects plain", Angle.is({}) == false)
	check("is rejects nil", Angle.is(nil) == false)
	check("is rejects number", Angle.is(1.5) == false)
end

print("=== Angle index / newindex ===")

do
	local a = Angle.new(1.0)
	check("index 1", near(a[1], 1.0))
	check("index rad", near(a.rad, 1.0))
	check("index deg", near(a.deg, 1.0 * 180 / math.pi))
	check("index 90deg", near(Angle.from_deg(90).deg, 90))
	check("index 180deg", near(Angle.from_deg(180).deg, 180, 1e-5))
	check("method fallback sin", a.sin == Angle.sin)
	check("method fallback clone", a.clone == Angle.clone)
	check("unknown key nil", a.nonexistent == nil)
	local b = Angle.new(0)
	b.rad = math.pi / 2
	check("newindex rad", near(b[1], math.pi / 2))
	b[1] = 1.0
	check("newindex 1", near(b.rad, 1.0))
	b.deg = 180
	check("newindex deg 180 pi", near(b[1], math.pi))
	b.deg = 90
	check("newindex deg 90", near(b[1], math.pi / 2))
	b.deg = 360
	check("newindex deg 360 zero", near(b[1], 0))
	b.rad = 3 * math.pi
	check("newindex rad normalizes", near(b[1], math.pi))
	b.rad = nil
	check("newindex rad nil zero", b[1] == 0)
	b.deg = nil
	check("newindex deg nil zero", b[1] == 0)
	b.rad = "1.0"
	check("newindex rad string", near(b[1], 1.0))
	check("newindex bad key errors", pcall(function() b.foo = 1 end) == false)
	check("newindex bad key direct", pcall(getmetatable(Angle.new(0)).__newindex, Angle.new(0), "bad", 1) == false)
end

print("=== Angle arithmetic metamethods ===")

do
	local half = Angle.new(math.pi / 2)
	local quarter = Angle.new(math.pi / 4)
	local mt = getmetatable(half)
	check("add angle angle", near((quarter + quarter)[1], math.pi / 2))
	check("add angle number", near((quarter + math.pi / 4)[1], math.pi / 2))
	check("add number angle", near((math.pi / 4 + quarter)[1], math.pi / 2))
	check("add wraps pi+pi zero", near((Angle.new(math.pi) + Angle.new(math.pi))[1], 0))
	check("add errors angle string", pcall(mt.__add, quarter, "x") == false)
	check("add errors nil", pcall(mt.__add, nil, quarter) == false)
	check("add errors two numbers", pcall(mt.__add, 1, 2) == false)
	check("add operator errors", pcall(function() return quarter + "x" end) == false)
	check("sub angle angle", near((half - quarter)[1], math.pi / 4))
	check("sub angle number", near((half - math.pi / 4)[1], math.pi / 4))
	check("sub number angle", near((mt.__sub(math.pi / 2, quarter))[1], math.pi / 4))
	check("sub self zero", near((half - half)[1], 0))
	check("sub errors", pcall(mt.__sub, half, {}) == false)
	check("sub operator errors", pcall(function() return half - {} end) == false)
	check("mul angle number", near((half * 2)[1], math.pi))
	check("mul number angle", near((2 * quarter)[1], math.pi / 2))
	check("mul zero", (half * 0)[1] == 0)
	check("mul negative", near((quarter * -1)[1], -math.pi / 4))
	check("mul errors angle angle", pcall(mt.__mul, half, half) == false)
	check("mul errors angle string", pcall(mt.__mul, half, "x") == false)
	check("div angle number", near((half / 2)[1], math.pi / 4))
	check("div number angle", near((mt.__div(math.pi, half))[1], 2))
	check("div by zero errors", pcall(mt.__div, half, 0) == false)
	check("div number by zero-angle errors", pcall(mt.__div, 1, Angle.new(0)) == false)
	check("div errors angle angle", pcall(mt.__div, half, half) == false)
	check("div errors angle string", pcall(mt.__div, half, "x") == false)
	check("div operator zero errors", pcall(function() return half / 0 end) == false)
	local neg = -half
	check("unm", near(neg[1], -math.pi / 2))
	check("unm zero", (-Angle.new(0))[1] == 0)
	check("unm errors", pcall(mt.__unm, {}) == false)
	check("eq true", (Angle.new(1.0) == Angle.new(1.0)) == true)
	check("eq false", (Angle.new(1.0) == Angle.new(2.0)) == false)
	check("eq vs plain false", (half == {}) == false)
	check("eq vs nil false", (half == nil) == false)
	check("eq direct non-angle false", mt.__eq(half, {}) == false)
	check("lt true", (quarter < half) == true)
	check("lt false reverse", (half < quarter) == false)
	check("lt equal false", (half < Angle.new(math.pi / 2)) == false)
	check("lt errors non-angle", pcall(mt.__lt, half, {}) == false)
	check("le true less", (quarter <= half) == true)
	check("le true equal", (half <= Angle.new(math.pi / 2)) == true)
	check("le false", (half <= quarter) == false)
	check("le errors", pcall(mt.__le, {}, half) == false)
	local s = tostring(half)
	check("tostring contains Angle", string.find(s, "Angle", 1, true) ~= nil)
	check("tostring contains rad", string.find(s, "rad", 1, true) ~= nil)
	check("tostring zero", string.find(tostring(Angle.new(0)), "Angle", 1, true) ~= nil)
end

print("=== Angle clone / trig ===")

do
	local a = Angle.new(1.25)
	local c = Angle.clone(a)
	check("clone equal", c == a)
	check("clone value", near(c[1], 1.25))
	check("clone not rawequal", rawequal(c, a) == false)
	c.rad = 0
	check("clone independent", near(a[1], 1.25) and c[1] == 0)
	check("clone errors", pcall(Angle.clone, {}) == false)
	check("clone errors nil", pcall(Angle.clone, nil) == false)
	check("sin zero", near(Angle.sin(Angle.new(0)), 0))
	check("sin half pi one", near(Angle.sin(Angle.new(math.pi / 2)), 1))
	check("sin pi zero", near(Angle.sin(Angle.new(math.pi)), 0, 1e-6))
	check("sin errors", pcall(Angle.sin, {}) == false)
	check("cos zero one", near(Angle.cos(Angle.new(0)), 1))
	check("cos half pi zero", near(Angle.cos(Angle.new(math.pi / 2)), 0, 1e-6))
	check("cos pi neg one", near(Angle.cos(Angle.new(math.pi)), -1))
	check("cos errors", pcall(Angle.cos, nil) == false)
	check("tan zero", near(Angle.tan(Angle.new(0)), 0))
	check("tan pi/4 one", near(Angle.tan(Angle.new(math.pi / 4)), 1))
	check("tan errors", pcall(Angle.tan, {}) == false)
	check("asin zero", near(Angle.asin(0)[1], 0))
	check("asin one half pi", near(Angle.asin(1)[1], math.pi / 2))
	check("asin neg one", near(Angle.asin(-1)[1], -math.pi / 2))
	check("asin half", near(Angle.asin(0.5)[1], math.asin(0.5)))
	check("asin out of range errors", pcall(Angle.asin, 2) == false)
	check("asin neg out errors", pcall(Angle.asin, -1.5) == false)
	check("asin nil defaults zero", near(Angle.asin(nil)[1], 0))
	check("acos one zero", near(Angle.acos(1)[1], 0))
	check("acos zero half pi", near(Angle.acos(0)[1], math.pi / 2))
	check("acos neg one pi", near(Angle.acos(-1)[1], math.pi))
	check("acos out errors", pcall(Angle.acos, 5) == false)
	check("acos neg out errors", pcall(Angle.acos, -2) == false)
	check("acos nil pi/2", near(Angle.acos(nil)[1], math.pi / 2))
	check("atan zero", near(Angle.atan(0)[1], 0))
	check("atan one pi/4", near(Angle.atan(1)[1], math.pi / 4))
	check("atan nil zero", Angle.atan(nil)[1] == 0)
	check("atan2 1 1 pi/4", near(Angle.atan2(1, 1)[1], math.pi / 4))
	check("atan2 0 1 zero", near(Angle.atan2(0, 1)[1], 0))
	check("atan2 1 0 half pi", near(Angle.atan2(1, 0)[1], math.pi / 2))
	check("atan2 0 0 zero", Angle.atan2(0, 0)[1] == 0)
	check("atan2 nil nil zero", Angle.atan2(nil, nil)[1] == 0)
end

print("=== Angle lerp / slerp / distance ===")

do
	local a = Angle.new(0)
	local b = Angle.new(math.pi / 2)
	check("lerp t0 is a", near(Angle.lerp(a, b, 0)[1], 0))
	check("lerp t1 is b", near(Angle.lerp(a, b, 1)[1], math.pi / 2))
	check("lerp half", near(Angle.lerp(a, b, 0.5)[1], math.pi / 4))
	check("lerp wrapping shortest", (function()
		local x = Angle.from_deg(170)
		local y = Angle.from_deg(-170)
		local m = Angle.lerp(x, y, 0.5)
		return near(math.abs(m[1]), math.pi, 1e-5)
	end)())
	check("lerp errors bad", pcall(Angle.lerp, a, {}, 0.5) == false)
	check("lerp errors nil", pcall(Angle.lerp, nil, b, 0) == false)
	check("lerp nil t defaults a", near(Angle.lerp(a, b, nil)[1], 0))
	check("slerp t0 is a", near(Angle.slerp(a, b, 0)[1], 0, 1e-5))
	check("slerp t1 is b", near(Angle.slerp(a, b, 1)[1], math.pi / 2, 1e-5))
	check("slerp half", near(Angle.slerp(a, b, 0.5)[1], math.pi / 4, 1e-5))
	check("slerp same returns same", near(Angle.slerp(a, a, 0.5)[1], 0))
	check("slerp errors", pcall(Angle.slerp, a, {}, 0.5) == false)
	check("shortest 0 to half pi", near(Angle.shortest_distance(a, b), math.pi / 2))
	check("shortest same zero", near(Angle.shortest_distance(a, a), 0))
	check("shortest wrap small", (function()
		local x = Angle.from_deg(170)
		local y = Angle.from_deg(-170)
		return near(Angle.shortest_distance(x, y), math.rad(20), 1e-5)
	end)())
	check("shortest reverse negative", near(Angle.shortest_distance(b, a), -math.pi / 2))
	check("shortest errors", pcall(Angle.shortest_distance, a, {}) == false)
	check("difference matches shortest", near(Angle.difference(a, b), Angle.shortest_distance(a, b)))
	check("difference wrap", (function()
		local x = Angle.from_deg(170)
		local y = Angle.from_deg(-170)
		return near(Angle.difference(x, y), math.rad(20), 1e-5)
	end)())
	check("difference errors", pcall(Angle.difference, {}, b) == false)
end

print("=== Angle near / clamp / abs / tables ===")

do
	local a = Angle.new(1.0)
	local b = Angle.new(1.0)
	check("is_near identical true", Angle.is_near(a, b) == true)
	check("is_near tiny true", Angle.is_near(a, Angle.new(1.0 + 1e-7)) == true)
	check("is_near big false", Angle.is_near(a, Angle.new(1.1)) == false)
	check("is_near custom true", Angle.is_near(a, Angle.new(1.05), 0.1) == true)
	check("is_near custom false", Angle.is_near(a, Angle.new(1.05), 0.01) == false)
	check("is_near wrap pi neg pi", Angle.is_near(Angle.new(math.pi), Angle.new(-math.pi)) == true)
	check("is_near errors", pcall(Angle.is_near, a, {}) == false)
	local v = Angle.new(0.5)
	check("clamp inside same", near(Angle.clamp(v, Angle.new(0), Angle.new(1))[1], 0.5))
	check("clamp low", near(Angle.clamp(Angle.new(-1), Angle.new(0), Angle.new(1))[1], 0))
	check("clamp high", near(Angle.clamp(Angle.new(2), Angle.new(0), Angle.new(1))[1], 1))
	check("clamp numbers", near(Angle.clamp(v, 0, 1)[1], 0.5))
	check("clamp number low", near(Angle.clamp(Angle.new(-0.5), 0, 1)[1], 0))
	check("clamp number high wraps", near(Angle.clamp(Angle.new(-5), 0, 1)[1], 1))
	check("clamp defaults", near(Angle.clamp(v, nil, nil)[1], 0.5))
	check("clamp errors bad angle", pcall(Angle.clamp, {}, 0, 1) == false)
	check("abs positive same", near(Angle.abs(Angle.new(1.0))[1], 1.0))
	check("abs negative flips", near(Angle.abs(Angle.new(-1.0))[1], 1.0))
	check("abs zero", Angle.abs(Angle.new(0))[1] == 0)
	check("abs errors", pcall(Angle.abs, {}) == false)
	local t = Angle.to_table(Angle.from_deg(90))
	check("to_table rad", near(t.rad, math.pi / 2))
	check("to_table deg", near(t.deg, 90))
	check("to_table errors", pcall(Angle.to_table, {}) == false)
	check("from_table rad", near(Angle.from_table({ rad = 1.2 })[1], 1.2))
	check("from_table deg", near(Angle.from_table({ deg = 90 })[1], math.pi / 2))
	check("from_table rad wins", near(Angle.from_table({ rad = 1.0, deg = 90 })[1], 1.0))
	check("from_table empty zero", Angle.from_table({})[1] == 0)
	check("from_table errors nil", pcall(Angle.from_table, nil) == false)
	check("from_table errors number", pcall(Angle.from_table, 5) == false)
	check("from_table roundtrip", (function()
		local orig = Angle.new(0.77)
		return near(Angle.from_table(Angle.to_table(orig))[1], 0.77)
	end)())
	check("boundary zero", Angle.new(0)[1] == 0)
	check("boundary one rad", near(Angle.new(1)[1], 1))
	check("boundary negative", near(Angle.new(-1)[1], -1))
	check("boundary large", (function()
		local v2 = Angle.new(1e9)[1]
		return v2 >= -math.pi and v2 <= math.pi
	end)())
end

print(string.format("\nTests finished: %d passed, %d failed", pass_count, fail_count))
assert(fail_count == 0, string.format("%d angle test(s) failed", fail_count))
if arg and arg[0] and arg[0]:match("angle%.lua$") then
	os.exit(fail_count > 0 and 1 or 0)
end
