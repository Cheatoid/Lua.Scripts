-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Augment existing standard math library.

--local type = type
local math_ceil = math.ceil
local math_cos = math.cos
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local math_modf = math.modf
local math_sin = math.sin
--local isnumber = function(v) return type(v) == "number" end

local math = assert(_G.math, "math library not found")

math.tau = 2 * math.pi
math.deg2rad = math.pi / 180
math.rad2deg = 180 / math.pi

--- Get the absolute value of a number (replicating math.abs, but without C call overhead).
--- Returns the non-negative value of the input.
--- @param n number Input number.
--- @return number number Absolute value.
--- @usage <br>
--- ```
--- math.absolute(-5)   -- 5
--- math.absolute(3.14) -- 3.14
--- math.absolute(0)    -- 0
--- ```
local function math_absolute(n)
	return n >= 0 and n or -n
end

math.absolute = math_absolute

--- Calculate the absolute difference between two numbers.
--- Returns the non-negative difference between x and y.
--- @param x number First number.
--- @param y number Second number.
--- @return number number Absolute difference.
--- @usage <br>
--- ```
--- math.difference(10, 3)    -- 7
--- math.difference(3, 10)    -- 7
--- math.difference(-5, -2)   -- 3
--- math.difference(5.5, 2.2) -- 3.3
--- ```
local function math_difference(x, y)
	return math_absolute(x - y)
end

math.difference = math_difference

--- Check if a number is approximately equal to another within a tolerance.
--- Useful for floating point comparisons.
--- @param a number First number.
--- @param b number Second number.
--- @param epsilon number|nil Tolerance for comparison (default: 1e-6).
--- @return boolean boolean True if numbers are approximately equal.
--- @usage <br>
--- ```
--- math.approx(0.1 + 0.2, 0.3) -- true
--- math.approx(1.0, 1.000001)  -- true
--- math.approx(1.0, 1.1, 0.05) -- false
--- ```
local function math_approx(a, b, epsilon)
	epsilon = epsilon or 1e-6
	return math_absolute(a - b) <= epsilon
end

math.approx = math_approx

--- Clamp a number between minimum and maximum values.
--- @param n number Input number to clamp.
--- @param min number Minimum value (lower bound).
--- @param max number Maximum value (upper bound).
--- @return number number Clamped value between min and max.
--- @usage <br>
--- ```
--- math.clamp(15, 0, 10) -- 10
--- math.clamp(-5, 0, 10) -- 0
--- math.clamp(5, 0, 10)  -- 5
--- ```
local function math_clamp(n, min, max)
	return math_min(math_max(n, min), max)
end

math.clamp = math_clamp

--- Clamp a number between 0 and 1.
--- Convenience function for normalizing values to 0-1 range.
--- @param n number Input number to normalize.
--- @return number number Normalized value between 0 and 1.
--- @usage <br>
--- ```
--- math.clamp01(-0.5) -- 0
--- math.clamp01(0.5)  -- 0.5
--- math.clamp01(1.5)  -- 1
--- ```
local function math_clamp01(n)
	return math_clamp(n, 0, 1)
end

math.clamp01 = math_clamp01

--- Get the fractional part of a number.
--- Returns only the fractional component of a number (everything after the decimal point).
--- @param n number Input number to extract fractional part from.
--- @return number number Fractional part of the number.
--- @usage <br>
--- ```
--- math.fractional(3.14) -- 0.14
--- math.fractional(-2.7) -- -0.7
--- math.fractional(5.0)  -- 0.0
--- ```
local function math_fractional(n)
	--return n % 1
	local _, f = math_modf(n)
	return f
end

math.fractional = math_fractional
math.frac = math_fractional

--- Returns the maximum of two numbers.
--- @param a number First number.
--- @param b number Second number.
--- @return number max The larger of a and b.
local function math_max2(a, b)
	--return a <= b and b or a
	--return a >= b and a or b
	return a > b and a or b
end

--- Returns the minimum of two numbers.
--- @param a number First number.
--- @param b number Second number.
--- @return number min The smaller of a and b.
local function math_min2(a, b)
	--return a <= b and a or b
	return a < b and a or b
end

--- Convert a number to an integer by removing the fractional part.
--- Equivalent to math.modf, but returns only the integer component.
--- @param n number Input number to convert.
--- @return integer integer Integer part of the number.
--- @usage <br>
--- ```
--- math.toint(3.14) -- 3
--- math.toint(-2.7) -- -2
--- math.toint(5.0)  -- 5
--- ```
local function math_toint(n)
	--return n | 0
	return (math_modf(n))
end

math.toint = math_toint
math.tointeger = math.tointeger or math_toint

--- Round a number to the nearest integer (towards zero) or to specified decimal places.
--- Rounds to the nearest integer, with .5 rounding up. If digits is provided, rounds to that many decimal places.
--- @param n number Input number to round.
--- @param digits number|nil Number of decimal places to round to (default: 0 for integer rounding).
--- @return number number Rounded number.
--- @usage <br>
--- ```
--- math.round(3.14)       -- 3
--- math.round(3.5)        -- 4
--- math.round(-2.7)       -- -3
--- math.round(-2.5)       -- -2
--- math.round(3.14159, 2) -- 3.14
--- math.round(2.675, 2)   -- 2.68
--- math.round(-2.675, 2)  -- -2.68
--- ```
local function math_round(n, digits)
	if digits then
		local factor = 10 ^ digits                   -- math.pow(10, digits)
		return math_floor((n * factor) + 0.5) / factor -- precision round
	end
	return n >= 0 and math_floor(n + 0.5) or math_ceil(n - 0.5)
end

math.round = math_round

--- Convert a float to integer using floor with rounding (ftol - float to integer).
--- Rounds numbers with .5 up, equivalent to math.floor(n + 0.5).
--- @param n number Input number to convert.
--- @return integer integer Integer value using floor with rounding.
--- @usage <br>
--- ```
--- math.ftol(3.14) -- 3
--- math.ftol(-2.7) -- -2
--- math.ftol(5.9)  -- 6
--- math.ftol(-5.1) -- -5
--- ```
local function math_ftol(n)
	return math_floor(n + 0.5)
end

math.ftol = math_ftol

--- Get both sine and cosine values for an angle.
--- Returns both sin and cos values in a single call for efficiency.
--- @param n number Angle in radians.
--- @return number sin Sine value of the angle.
--- @return number cos Cosine value of the angle.
--- @usage <br>
--- ```
--- local sin_val, cos_val = math.sincos(math.pi / 4)
--- -- sin_val ≈ 0.7071, cos_val ≈ 0.7071
--- ```
local function math_sincos(n) -- TODO/CONS: lookup table?
	return math_sin(n), math_cos(n)
end

math.sincos = math_sincos

--- Get the sign of a number.
--- Returns -1 for negative numbers, 1 for positive numbers, and 0 for zero.
--- @param n number Input number.
--- @return number number Sign value (-1, 0, or 1).
--- @usage <br>
--- ```
--- math.sign(-5)   -- -1
--- math.sign(3.14) -- 1
--- math.sign(0)    -- 0
--- ```
local function math_sign(n)
	return n > 0 and 1 or n < 0 and -1 or 0
end

math.sign = math_sign

--- Map a value from one range to another.
--- Converts a value from [in_min, in_max] range to [out_min, out_max] range.
--- @param n number Input value to map.
--- @param in_min number Input range minimum.
--- @param in_max number Input range maximum.
--- @param out_min number Output range minimum.
--- @param out_max number Output range maximum.
--- @return number number Mapped value.
--- @usage <br>
--- ```
--- math.map(5, 0, 10, 0, 100) -- 50
--- math.map(0.5, 0, 1, -1, 1) -- 0
--- math.map(75, 0, 100, 0, 1) -- 0.75
--- ```
local function math_map(n, in_min, in_max, out_min, out_max)
	if in_max == in_min then return out_min end
	return out_min + (n - in_min) * (out_max - out_min) / (in_max - in_min)
end

math.map = math_map

--- Remap a value from one range to another without clamping.
--- Similar to math.map but does not clamp the output to the target range.
--- @param n number Input value to remap.
--- @param in_min number Input range minimum.
--- @param in_max number Input range maximum.
--- @param out_min number Output range minimum.
--- @param out_max number Output range maximum.
--- @return number number Remapped value (may be outside output range).
--- @usage <br>
--- ```
--- math.remap(5, 0, 10, 0, 100)  -- 50
--- math.remap(15, 0, 10, 0, 100) -- 150 (not clamped)
--- math.remap(-5, 0, 10, -1, 1)  -- -0.5
--- ```
local function math_remap(n, in_min, in_max, out_min, out_max)
	return out_min + (n - in_min) / (in_max - in_min) * (out_max - out_min)
end

math.remap = math_remap

--- Calculate the progress of a value within a range.
--- Returns the normalized position (0-1+) of a value within [min, max] range without clamping.
--- @param n number Input value.
--- @param min number Range minimum.
--- @param max number Range maximum.
--- @return number number Progress value (may be outside 0-1 range).
--- @usage <br>
--- ```
--- math.progress(5, 0, 10)  -- 0.5
--- math.progress(15, 0, 10) -- 1.5 (not clamped)
--- math.progress(-5, 0, 10) -- -0.5 (not clamped)
--- ```
local function math_progress(n, min, max)
	return (n - min) / (max - min)
end

math.progress = math_progress

--- Get the percentage of a value within a range.
--- Returns what percentage (0-1) value is of the range [min, max].
--- @param n number Input value.
--- @param min number Range minimum.
--- @param max number Range maximum.
--- @return number number Percentage (0-1).
--- @usage <br>
--- ```
--- math.percent(5, 0, 10)   -- 0.5
--- math.percent(25, 0, 100) -- 0.25
--- math.percent(15, 10, 20) -- 0.5
--- ```
local function math_percent(n, min, max)
	if max == min then return 0 end
	return math_clamp((n - min) / (max - min), 0, 1)
end

math.percent = math_percent
--math.fraction = math_percent

--- Wrap a number within a range.
--- Similar to modulo but works correctly with negative numbers.
--- @param n number Input number to wrap.
--- @param min number Range minimum.
--- @param max number Range maximum.
--- @return number number Wrapped value within [min, max).
--- @usage <br>
--- ```
--- math.wrap(7, 0, 5)   -- 2
--- math.wrap(-1, 0, 5)  -- 4
--- math.wrap(12, 0, 10) -- 2
--- ```
local function math_wrap(n, min, max)
	local range = max - min
	if range == 0 then return min end
	return min + ((n - min) % range + range) % range
end

math.wrap = math_wrap

--- Calculate the greatest common divisor of two numbers.
--- Uses the Euclidean algorithm to find the largest integer that divides both numbers.
--- @param a number First number (must be non-negative integer).
--- @param b number Second number (must be non-negative integer).
--- @return number number Greatest common divisor.
--- @usage <br>
--- ```
--- math.gcd(48, 18)  -- 6
--- math.gcd(17, 23)  -- 1
--- math.gcd(100, 25) -- 25
--- ```
local function math_gcd(a, b)
	return b == 0 and a or math_gcd(b, a % b)
end

math.gcd = math_gcd

--- Perform floor division of two numbers.
--- Returns the largest integer less than or equal to the exact division result.
--- @param a number Dividend.
--- @param b number Divisor (must not be zero).
--- @return number number Floor division result.
--- @usage <br>
--- ```
--- math.floordiv(7, 3)   -- 2
--- math.floordiv(-7, 3)  -- -3
--- math.floordiv(7, -3)  -- -3
--- math.floordiv(-7, -3) -- 2
--- ```
local function math_floordiv(a, b)
	return math_floor(a / b)
end

math.floordiv = math_floordiv

--- Perform integer division with truncation toward zero.
--- Returns the integer part of division, truncating toward zero like C-style integer division.
--- @param a number Dividend.
--- @param b number Divisor (must not be zero).
--- @return number number Integer division result.
--- @usage <br>
--- ```
--- math.intdiv(7, 3)   -- 2
--- math.intdiv(-7, 3)  -- -2
--- math.intdiv(7, -3)  -- -2
--- math.intdiv(-7, -3) -- 2
--- ```
local function math_intdiv(a, b)
	return (a >= 0 and math_floor or math_ceil)(a / b)
end

math.intdiv = math_intdiv

--- Truncate a number to an integer or specified decimal places.
--- Removes fractional part by truncating toward zero. If idp is provided, truncates to that many decimal places.
--- @param n number Input number to truncate.
--- @param idp number|nil Number of decimal places to truncate to (default: 0 for integer truncation).
--- @return number number Truncated number.
--- @usage <br>
--- ```
--- math.truncate(3.14)       -- 3
--- math.truncate(-2.7)       -- -2
--- math.truncate(5.9)        -- 5
--- math.truncate(-5.1)       -- -5
--- math.truncate(3.14159, 2) -- 3.14
--- math.truncate(-2.675, 2)  -- -2.67
--- ```
local function math_truncate(n, idp)
	local func = n < 0 and math_ceil or math_floor
	if idp then
		local mult = 10 ^ idp -- math.pow(10, idp)
		return func(n * mult) / mult
	end
	return func(n)
end

math.truncate = math_truncate

--- Scale a number from [0,1] range to [min,max] range.
--- Linearly scales a normalized value (0-1) to the specified range.
--- @param n number Input number in [0,1] range.
--- @param min number Target range minimum.
--- @param max number Target range maximum.
--- @return number number Scaled value in [min,max] range.
--- @usage <br>
--- ```
--- math.scale(0.5, 0, 10)    -- 5
--- math.scale(0.25, -5, 5)   -- -2.5
--- math.scale(1.0, 100, 200) -- 200
--- ```
local function math_scale(n, min, max)
	return n * (max - min) + min
end

math.scale = math_scale

--- Generate a random number in a specified range.
--- Returns a random float between min and max (inclusive of min, exclusive of max).
--- @param min number Minimum value.
--- @param max number Maximum value.
--- @return number number Random number in [min, max) range.
--- @usage <br>
--- ```
--- math.rand(0, 10)    -- Random number between 0 and 10
--- math.rand(-5, 5)    -- Random number between -5 and 5
--- math.rand(100, 200) -- Random number between 100 and 200
--- ```
local function math_rand(min, max)
	return math.random() * (max - min) + min
end

math.rand = math.rand or math_rand

--- Check if a number is within a specified range.
--- Returns true if the number is between min and max (inclusive).
--- @param n number Number to check.
--- @param min number Range minimum.
--- @param max number Range maximum.
--- @return boolean boolean True if number is within range.
--- @usage <br>
--- ```
--- math.inrange(5, 0, 10)  -- true
--- math.inrange(-2, -5, 5) -- true
--- math.inrange(15, 0, 10) -- false
--- math.inrange(0, 0, 10)  -- true
--- ```
local function math_inrange(n, min, max)
	return min <= n and n <= max
end

math.inrange = math_inrange

--- Snap a number to the nearest multiple of a step value.
--- Rounds the number to the nearest increment of the specified step size.
--- @param n number Input number to snap.
--- @param step number Step size to snap to.
--- @return number number Snapped value.
--- @usage <br>
--- ```
--- math.snapto(7, 5)     -- 5
--- math.snapto(13, 5)    -- 15
--- math.snapto(2.7, 0.5) -- 2.5
--- math.snapto(3.14, 1)  -- 3
--- ```
local function math_snapto(n, step)
	return math_floor((n / step) + 0.5) * step
end

math.snapto = math_snapto

--- Move a value toward a target by a maximum step amount.
--- Returns a new value that moves closer to the target but doesn't exceed the step size.
--- @param current number Current value.
--- @param target number Target value to approach.
--- @param step number Maximum step size (always treated as positive).
--- @return number number New value moved toward target.
--- @usage <br>
--- ```
--- math.approach(10, 20, 3)  -- 13
--- math.approach(10, 5, 2)   -- 8
--- math.approach(10, 15, 10) -- 15 (reached target)
--- math.approach(10, 12, 5)  -- 12 (reached target)
--- ```
local function math_approach(current, target, step)
	step = step < 0 and -step or step -- math.abs(step)
	local delta = target - current
	if delta > step then
		return current + step
	end
	if delta < -step then
		return current - step
	end
	return target
end

math.approach = math_approach

--- Linear interpolation between two values.
--- Returns a value interpolated between start and end based on t (0-1).
--- @param t number Interpolation factor (0 = start, 1 = end).
--- @param from number Starting value.
--- @param to number Ending value.
--- @return number number Interpolated value.
--- @usage <br>
--- ```
--- math.lerp(0.5, 0, 10)   -- 5
--- math.lerp(0.25, 10, 20) -- 12.5
--- math.lerp(1.5, 0, 100)  -- 150 (not clamped)
--- ```
local function math_lerp(t, from, to)
	return from + (to - from) * t
end

math.lerp = math_lerp

--- Linear interpolation between two values.
--- Returns a value interpolated between start and end based on t (0-1).
--- @param t number Interpolation factor (0 = start, 1 = end, clamped to 0-1).
--- @param from number Starting value.
--- @param to number Ending value.
--- @return number number Interpolated value.
--- @usage <br>
--- ```
--- math.lerp(0, 10, 0.5)   -- 5
--- math.lerp(10, 20, 0.25) -- 12.5
--- math.lerp(0, 100, 1.5)  -- 100 (clamped)
--- ```
local function math_lerp_clamp(t, from, to)
	t = math_clamp(t, 0, 1)
	return from + (to - from) * t
end

math.lerp_clamp = math_lerp_clamp

-- TODO/CONS: tweening/easing?

return math
