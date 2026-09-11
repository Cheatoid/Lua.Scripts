-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Minimal Test Harness
local Test = {
	passed = 0,
	failed = 0,
	errors = {},
	current_suite = "",
}

function Test.suite(name)
	Test.current_suite = name
	print(string.format("\n== %s ==", name))
end

function Test.assert(condition, msg)
	if condition then
		Test.passed = Test.passed + 1
	else
		Test.failed = Test.failed + 1
		local err = string.format("  FAIL [%s]: %s", Test.current_suite, msg or "assertion failed")
		table.insert(Test.errors, err)
		print(err)
	end
end

function Test.equal(actual, expected, msg)
	if actual == expected then
		Test.passed = Test.passed + 1
	else
		Test.failed = Test.failed + 1
		local detail = string.format("%s (expected: %s, got: %s)",
			msg or "values not equal", tostring(expected), tostring(actual))
		local err = string.format("  FAIL [%s]: %s", Test.current_suite, detail)
		table.insert(Test.errors, err)
		print(err)
	end
end

function Test.deep_equal(actual, expected, msg)
	local seen = {}
	if actual == expected then
		Test.assert(true, msg)
		return
	end
	if type(actual) ~= type(expected) then
		Test.assert(false, (msg or "") .. string.format(" (type mismatch: %s vs %s)", type(actual), type(expected)))
		return
	end
	if type(actual) ~= "table" then
		Test.assert(false, (msg or "") .. string.format(" (expected: %s, got: %s)", tostring(expected), tostring(actual)))
		return
	end
	if seen[actual] then
		Test.assert(true, msg)
		return
	end -- cycle guard
	seen[actual] = true
	for k, v in pairs(actual) do
		if not Test._deep_eq(v, expected[k], seen) then
			Test.assert(false, (msg or "") .. string.format(" (key %s differs)", tostring(k)))
			return
		end
	end
	for k, _ in pairs(expected) do
		if actual[k] == nil then
			Test.assert(false, (msg or "") .. string.format(" (extra key %s in expected)", tostring(k)))
			return
		end
	end
	Test.assert(true, msg)
end

function Test._deep_eq(a, b, seen)
	if a == b then return true end
	if type(a) ~= type(b) then return false end
	if type(a) ~= "table" then return false end
	if seen[a] then return true end
	seen[a] = true
	for k, v in pairs(a) do
		if not Test._deep_eq(v, b[k], seen) then return false end
	end
	for k, _ in pairs(b) do
		if a[k] == nil then return false end
	end
	return true
end

function Test.approx(actual, expected, epsilon, msg)
	epsilon = epsilon or 1e-6
	local cond = math.abs(actual - expected) <= epsilon
	if not cond then
		msg = string.format("%s (expected: ~%s, got: %s)", msg or "approx equality failed", tostring(expected),
			tostring(actual))
	end
	Test.assert(cond, msg)
end

function Test.nil_val(actual, msg)
	Test.assert(actual == nil, msg or "expected nil value")
end

function Test.summary()
	print(string.format("\n========================================"))
	print(string.format("Results: %d passed, %d failed", Test.passed, Test.failed))
	if #Test.errors > 0 then
		print("\nFailures:")
		for _, e in ipairs(Test.errors) do
			print(e)
		end
	end
	print("========================================")
	return Test.failed == 0
end

----------------------------------------------------------------------
-- Load the library under test
----------------------------------------------------------------------

-- Bootstrap: make parent-relative requires work from tests/ subdir with plain lua.
do
  local src = debug.getinfo(1, "S").source
  local dir = src:match("^@(.+/)[^/]+$") or "./"
  local function isfile(p)
    local f = io.open(p, "r")
    if f then f:close() return true end
    return false
  end
  local rootd
  for _, c in ipairs({ dir, dir .. "../", dir .. "../..//", dir .. "../../..//", "./", "../", "../../" }) do
    if isfile(c .. "standalone/bits.lua") then rootd = c break end
  end
  rootd = rootd or dir .. "../"
  if package then
    package.path = dir .. "../?.lua;" .. dir .. "../?/init.lua;" .. dir .. "?.lua;" .. dir .. "?/init.lua;" .. rootd .. "?.lua;" .. rootd .. "?/init.lua;" .. rootd .. "standalone/?.lua;" .. rootd .. "math/?.lua;" .. rootd .. "collections/?.lua;" .. rootd .. "standard/?.lua;" .. package.path
  end
  local searchers = package.searchers or package.loaders
  if searchers then
    table.insert(searchers, 2, function(mod)
      if mod:sub(1, 3) == "../" or mod:sub(1, 2) == "./" then
        local clean = mod:gsub("^%./", ""):gsub("^%.%.%/", ""):gsub("^%.%.%/", "")
        local tries = { dir .. "../" .. clean .. ".lua", dir .. "../" .. clean .. "/init.lua", rootd .. clean .. ".lua", rootd .. clean .. "/init.lua" }
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

  -- Preload standard extensions over stdlib (plain lua resolves require "string" to C lib).
  do
    local function try_preload(name, relpath)
      if package.loaded[name] == nil or type(package.loaded[name]) ~= "table" or package.loaded[name].explode == nil and name == "string" then
        local f = rootd .. relpath
        local fh = io.open(f, "r")
        if fh then
          fh:close()
          local chunk, err = loadfile(f)
          if chunk then
            local ok, mod = pcall(chunk, name)
            if ok and mod ~= nil then
              package.loaded[name] = mod
            end
          end
        end
      end
    end
    -- Only override string (table/math use _G, but ensure extensions load if needed).
    try_preload("string", "standard/string.lua")
  end
end

local lib = require "../math"

----------------------------------------------------------------------
-- Constants & Helpers
----------------------------------------------------------------------

local EPSILON = 1e-6
local INF = math.huge
local NAN = 0 / 0

----------------------------------------------------------------------
-- Test Suites
----------------------------------------------------------------------

Test.suite("Constants")
Test.approx(math.tau, 2 * math.pi, EPSILON, "math.tau")
Test.approx(math.deg2rad, math.pi / 180, EPSILON, "math.deg2rad")
Test.approx(math.rad2deg, 180 / math.pi, EPSILON, "math.rad2deg")

Test.suite("Float Inspection")
Test.assert(math.isinf(INF), "isinf(INF)")
Test.assert(math.isinf(-INF), "isinf(-INF)")
Test.assert(not math.isinf(0), "not isinf(0)")
Test.assert(not math.isinf(NAN), "not isinf(NAN)")

Test.assert(math.isnan(NAN), "isnan(NAN)")
Test.assert(not math.isnan(0), "not isnan(0)")
Test.assert(not math.isnan(INF), "not isnan(INF)")

Test.assert(math.isfinite(0), "isfinite(0)")
Test.assert(math.isfinite(3.14), "isfinite(3.14)")
Test.assert(not math.isfinite(INF), "not isfinite(INF)")
Test.assert(not math.isfinite(-INF), "not isfinite(-INF)")
Test.assert(not math.isfinite(NAN), "not isfinite(NAN)")

Test.suite("Basic Arithmetic & Absolute")
Test.equal(math.absolute(-5), 5, "absolute(-5)")
Test.equal(math.absolute(5), 5, "absolute(5)")
Test.equal(math.absolute(0), 0, "absolute(0)")

Test.equal(math.difference(10, 3), 7, "difference(10,3)")
Test.equal(math.difference(3, 10), 7, "difference(3,10)")
Test.equal(math.difference(-5, -2), 3, "difference(-5,-2)")

Test.assert(math.approx(0.1 + 0.2, 0.3), "approx(0.1+0.2, 0.3)")
Test.assert(math.approx(1.0, 1.0000001), "approx default epsilon")
Test.assert(not math.approx(1.0, 1.1, 0.05), "not approx with tight epsilon")

Test.suite("Min / Max / Clamp")
Test.equal(math.maximum(5, 3), 5, "maximum(5,3)")
Test.equal(math.maximum(-2, 7), 7, "maximum(-2,7)")
Test.equal(math.minimum(5, 3), 3, "minimum(5,3)")
Test.equal(math.minimum(-2, 7), -2, "minimum(-2,7)")

Test.equal(math.clamp(15, 0, 10), 10, "clamp above")
Test.equal(math.clamp(-5, 0, 10), 0, "clamp below")
Test.equal(math.clamp(5, 0, 10), 5, "clamp within")

Test.equal(math.clamp01(-0.5), 0, "clamp01 below")
Test.equal(math.clamp01(1.5), 1, "clamp01 above")
Test.equal(math.clamp01(0.5), 0.5, "clamp01 within")

Test.suite("Rounding & Truncation")
Test.equal(math.round(3.14), 3, "round(3.14)")
Test.equal(math.round(3.5), 4, "round(3.5)")
Test.equal(math.round(-2.7), -3, "round(-2.7)")
Test.equal(math.round(-2.5), -2,
	"round(-2.5) uses floor(n+0.5) for consistent round-half-up behavior")

Test.approx(math.round(3.14159, 2), 3.14, EPSILON, "round digits")
Test.approx(math.round(2.675, 2), 2.68, EPSILON, "round digits up")

Test.equal(math.trunc(3.14), 3, "trunc pos")
Test.equal(math.trunc(-2.7), -2, "trunc neg")

Test.equal(math.toint(3.14), 3, "toint pos")
Test.equal(math.toint(-2.7), -2, "toint neg")

Test.equal(math.tointeger(3.7), 3, "tointeger pos")
Test.equal(math.tointeger(-3.7), -3, "tointeger neg")
Test.nil_val(math.tointeger(NAN), "tointeger NaN")
Test.nil_val(math.tointeger(INF), "tointeger INF")
Test.nil_val(math.tointeger("string"), "tointeger string")

Test.equal(math.truncate(3.14), 3, "truncate int")
Test.equal(math.truncate(-2.7), -2, "truncate neg")
Test.approx(math.truncate(3.14159, 2), 3.14, EPSILON, "truncate decimals")
Test.approx(math.truncate(-2.675, 2), -2.67, EPSILON, "truncate neg decimals")

Test.suite("Fractional & Sign")
Test.approx(math.fractional(3.14), 0.14, EPSILON, "fractional pos")
Test.approx(math.frac(3.14), 0.14, EPSILON, "frac alias")
-- Note: modf(-2.7) returns -2, -0.7. So fractional part is -0.7
Test.approx(math.fractional(-2.7), -0.7, EPSILON, "fractional neg")

Test.equal(math.sign(-5), -1, "sign neg")
Test.equal(math.sign(3.14), 1, "sign pos")
Test.equal(math.sign(0), 0, "sign zero")

Test.equal(math.copysign(3.14, -1), -3.14, "copysign pos->neg")
Test.equal(math.copysign(-5, 1), 5, "copysign neg->pos")
Test.equal(math.copysign(-5, -1), -5, "copysign neg->neg")

Test.suite("Bitwise / Power-of-2 Decomposition")
Test.equal(math.ldexp(1.5, 3), 12.0, "ldexp basic")
Test.equal(math.ldexp(0.5, -1), 0.25, "ldexp neg exp")

do
	local m, e = math.frexp(12.0)
	Test.approx(m, 0.75, EPSILON, "frexp 12 mantissa")
	Test.equal(e, 4, "frexp 12 exponent")
end
do
	local m, e = math.frexp(0)
	Test.equal(m, 0.0, "frexp 0 mantissa")
	Test.equal(e, 0, "frexp 0 exponent")
end
do
	local m, e = math.frexp(-6.0)
	Test.approx(m, -0.75, EPSILON, "frexp -6 mantissa")
	Test.equal(e, 3, "frexp -6 exponent")
end

Test.equal(math.pow(2, 3), 8, "pow")
Test.equal(math.cbrt(8), 2, "cbrt pos")
Test.equal(math.cbrt(-8), -2, "cbrt neg")
Test.equal(math.cube_root(27), 3, "cube_root alias")

Test.suite("Mapping & Interpolation")
Test.equal(math.map(5, 0, 10, 0, 100), 50, "map mid")
Test.equal(math.map(0, 0, 10, -1, 1), -1, "map min")
Test.equal(math.remap(15, 0, 10, 0, 100), 150, "remap unclamped")
Test.equal(math.progress(5, 0, 10), 0.5, "progress mid")
Test.equal(math.progress(15, 0, 10), 1.5, "progress unclamped")
Test.equal(math.percent(5, 0, 10), 0.5, "percent mid")
Test.equal(math.percent(15, 0, 10), 1.0, "percent clamped high")
Test.equal(math.percent(-5, 0, 10), 0.0, "percent clamped low")

Test.equal(math.lerp(0.5, 0, 10), 5, "lerp mid")
Test.equal(math.lerp(0, 10, 20), 10, "lerp start")
Test.equal(math.lerp(1, 10, 20), 20, "lerp end")
Test.equal(math.lerp_clamp(1.5, 0, 10), 10, "lerp_clamp over")
Test.equal(math.lerp_clamp(-0.5, 0, 10), 0, "lerp_clamp under")

Test.approx(math.unlerp(25, 0, 100), 0.25, EPSILON, "unlerp")
Test.approx(math.inverse_lerp(5, 0, 10), 0.5, EPSILON, "inverse_lerp alias")

Test.suite("Wrapping & Oscillation")
Test.equal(math.wrap(7, 0, 5), 2, "wrap pos")
Test.equal(math.wrap(-1, 0, 5), 4, "wrap neg")
Test.equal(math.rep(5, 3), 2, "rep")
Test.equal(math.rep(-1, 5), 4, "rep neg")

Test.equal(math.pingpong(0.0, 1), 0, "pingpong 0")
Test.equal(math.pingpong(0.5, 1), 0.5, "pingpong 0.5")
Test.equal(math.pingpong(1.0, 1), 1, "pingpong 1")
Test.equal(math.pingpong(1.5, 1), 0.5, "pingpong 1.5")
Test.equal(math.pingpong(2.0, 1), 0, "pingpong 2")

Test.approx(math.bounce(0, 0, 10), 0, EPSILON, "bounce 0")
Test.approx(math.bounce(math.pi / 2, 0, 10), 10, EPSILON, "bounce pi/2")
Test.approx(math.bounce(math.pi, 0, 10), 0, EPSILON, "bounce pi")

Test.suite("Thresholds & Snapping")
Test.equal(math.soft_threshold(5, 2), 3, "soft_thresh pos")
Test.equal(math.soft_threshold(-5, 2), -3, "soft_thresh neg")
Test.equal(math.soft_threshold(1, 2), 0, "soft_thresh within")

Test.assert(math.threshold(5, 0, 10), "threshold within")
Test.assert(math.threshold(-1, 0, 10, 2), "threshold with tolerance")
Test.assert(not math.threshold(15, 0, 10), "threshold outside")

Test.equal(math.snapto(7, 5), 5, "snapto down")
Test.equal(math.snapto(13, 5), 15, "snapto up")
Test.approx(math.snapto(2.7, 0.5), 2.5, EPSILON, "snapto float")

Test.suite("Movement & Damping")
Test.equal(math.approach(10, 20, 3), 13, "approach up")
Test.equal(math.approach(10, 5, 2), 8, "approach down")
Test.equal(math.approach(10, 15, 10), 15, "approach reach")

Test.equal(math.move_towards(10, 20, 3), 13, "move_towards up")
Test.equal(math.move_towards(10, 5, 2), 8, "move_towards down")
Test.equal(math.move_towards(10, 12, 5), 12, "move_towards reach")

-- Damp is time-dependent, just verify it moves towards target
local damped = math.damp(10, 20, 0.5, 1.0)
Test.assert(damped > 10 and damped <= 20, "damp moves towards target")

Test.suite("Angle Utilities")
Test.approx(math.deg_to_rad(180), math.pi, EPSILON, "deg_to_rad")
Test.approx(math.degtorad(90), math.pi / 2, EPSILON, "degtorad alias")
Test.approx(math.rad_to_deg(math.pi), 180, EPSILON, "rad_to_deg")
Test.approx(math.radtodeg(math.pi / 2), 90, EPSILON, "radtodeg alias")

Test.equal(math.normalize_angle(190), -170, "normalize_angle 190")
Test.equal(math.normalize_angle(-200), 160, "normalize_angle -200")
Test.equal(math.normalize_angle_360(-90), 270, "normalize_angle_360 -90")
Test.equal(math.normalize_angle_360(450), 90, "normalize_angle_360 450")

Test.equal(math.angle_diff(0, 90), 90, "angle_diff 0->90")
Test.equal(math.angle_diff(0, 270), -90, "angle_diff 0->270 shortest")
Test.equal(math.angle_diff(350, 10), 20, "angle_diff wrap")

-- lerp_angle should take shortest path
Test.approx(math.lerp_angle(0, 270, 0.5), -45, EPSILON, "lerp_angle shortest path")
Test.approx(math.lerp_angle(350, 10, 0.5), 0, EPSILON, "lerp_angle wrap")

do
	local s, c = math.sincos(math.pi / 4)
	Test.approx(s, 0.70710678, EPSILON, "sincos sin")
	Test.approx(c, 0.70710678, EPSILON, "sincos cos")
end

Test.suite("Distance")
Test.equal(math.distance(0, 0, 3, 4), 5, "distance 2d")
Test.equal(math.dist(0, 0, 3, 4), 5, "dist alias")
Test.equal(math.distance_squared(0, 0, 3, 4), 25, "distance_squared 2d")
Test.equal(math.dist_sq(0, 0, 3, 4), 25, "dist_sq alias")

Test.equal(math.distance_3d(0, 0, 0, 1, 2, 2), 3, "distance 3d")
Test.equal(math.distance_3d_squared(0, 0, 0, 1, 2, 2), 9, "distance_squared 3d")

Test.suite("Statistics")
Test.equal(math.average(1, 2, 3, 4, 5), 3, "average")
Test.equal(math.mean(10, 20), 15, "mean alias")
Test.equal(math.sum(1, 2, 3, 4, 5), 15, "sum")
Test.equal(math.range(0, 10), 10, "range")
Test.equal(math.mid(0, 10), 5, "mid")

Test.suite("Safe Math")
Test.equal(math.sqrt_safe(9), 3, "sqrt_safe pos")
Test.equal(math.sqrt_safe(-1), 0, "sqrt_safe neg")
Test.approx(math.log_safe(100), 2, EPSILON, "log_safe base10")
Test.approx(math.log_safe(100, 2), 6.643856, 1e-4, "log_safe base2")
Test.equal(math.log_safe(0), 0, "log_safe zero")
Test.equal(math.log_safe(-1), 0, "log_safe neg")

Test.suite("Integer Division & GCD")
Test.equal(math.gcd(48, 18), 6, "gcd")
Test.equal(math.gcd(17, 23), 1, "gcd prime")
Test.equal(math.floordiv(7, 3), 2, "floordiv pos")
Test.equal(math.floordiv(-7, 3), -3, "floordiv neg dividend")
Test.equal(math.intdiv(7, 3), 2, "intdiv pos")
Test.equal(math.intdiv(-7, 3), -2, "intdiv neg trunc toward zero")

Test.suite("Easing Functions")
Test.equal(math.ease_in_quad(0), 0, "ease_in_quad 0")
Test.equal(math.ease_in_quad(1), 1, "ease_in_quad 1")
Test.equal(math.sqr(0.5), 0.25, "sqr alias")

Test.equal(math.ease_out_quad(0), 0, "ease_out_quad 0")
Test.equal(math.ease_out_quad(1), 1, "ease_out_quad 1")

Test.equal(math.ease_in_out_quad(0), 0, "ease_in_out_quad 0")
Test.equal(math.ease_in_out_quad(1), 1, "ease_in_out_quad 1")

Test.equal(math.ease_in_cubic(0), 0, "ease_in_cubic 0")
Test.equal(math.ease_in_cubic(1), 1, "ease_in_cubic 1")

Test.equal(math.ease_out_cubic(0), 0, "ease_out_cubic 0")
Test.equal(math.ease_out_cubic(1), 1, "ease_out_cubic 1")

Test.equal(math.ease_in_out_cubic(0), 0, "ease_in_out_cubic 0")
Test.equal(math.ease_in_out_cubic(1), 1, "ease_in_out_cubic 1")

Test.equal(math.smoothstep(0), 0, "smoothstep 0")
Test.equal(math.smoothstep(1), 1, "smoothstep 1")
Test.equal(math.smoothstep(0.5), 0.5, "smoothstep 0.5")

Test.equal(math.smootherstep(0), 0, "smootherstep 0")
Test.equal(math.smootherstep(1), 1, "smootherstep 1")
Test.equal(math.smootherstep(0.5), 0.5, "smootherstep 0.5")

Test.suite("Random Utilities")
-- Random tests are probabilistic; we test bounds and type
do
	local r = math.rand(0, 10)
	Test.assert(r >= 0 and r < 10, "rand in range [0,10)")
end
do
	local ri = math.random_range_int(1, 10)
	Test.assert(ri >= 1 and ri <= 10 and ri == math.floor(ri), "random_range_int bounds & type")
	-- Test rand_int separately (cannot compare two random calls for equality)
	local ri2 = math.rand_int(1, 10)
	Test.assert(ri2 >= 1 and ri2 <= 10 and ri2 == math.floor(ri2), "rand_int bounds & type")
end

do
	local rs = math.random_sign()
	Test.assert(rs == 1 or rs == -1, "random_sign")
end

do
	local rb = math.random_bool()
	Test.assert(rb == true or rb == false, "random_bool")
end

do
	local rc = math.random_choice("a", "b", "c")
	Test.assert(rc == "a" or rc == "b" or rc == "c", "random_choice")
end

do
	local rw = math.random_weighted({ 10, 20, 30 })
	Test.assert(rw >= 1 and rw <= 3, "random_weighted index bounds")
end

Test.suite("Fibonacci")
Test.equal(math.fibonacci(0), 0, "fib 0")
Test.equal(math.fibonacci(1), 1, "fib 1")
Test.equal(math.fibonacci(2), 1, "fib 2")
Test.equal(math.fibonacci(6), 8, "fib 6")
Test.equal(math.fibonacci(10), 55, "fib 10")
Test.equal(math.fibonacci(-5), 0, "fib neg")

Test.suite("Scale & InRange")
Test.equal(math.scale(0.5, 0, 10), 5, "scale mid")
Test.equal(math.scale(0, -5, 5), -5, "scale min")
Test.equal(math.scale(1, -5, 5), 5, "scale max")

Test.assert(math.inrange(5, 0, 10), "inrange within")
Test.assert(math.inrange(0, 0, 10), "inrange min bound")
Test.assert(math.inrange(10, 0, 10), "inrange max bound")
Test.assert(not math.inrange(15, 0, 10), "inrange outside")

----------------------------------------------------------------------
-- Run Summary
----------------------------------------------------------------------

local all_passed = Test.summary()
os.exit(all_passed and 0 or 1)
