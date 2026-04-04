-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

--- @meta

--- @class mathlib
local math = {}

--- Tau constant (2 * pi).<br>
--- Represents a full circle in radians (approximately 6.283185...).
--- @type number
math.tau = 2 * math.pi

--- Degrees to radians conversion factor.<br>
--- Multiply degrees by this value to convert to radians.
--- @type number
math.deg2rad = math.pi / 180

--- Radians to degrees conversion factor.<br>
--- Multiply radians by this value to convert to degrees.
--- @type number
math.rad2deg = 180 / math.pi

--- Check if a number is infinite.<br>
--- Returns true if the number is positive or negative infinity.
--- @param n number Input number to check.
--- @return boolean boolean True if the number is infinite.
--- @usage <br>
--- ```
--- math.isinf(1/0)  -- true
--- math.isinf(-1/0) -- true
--- math.isinf(3.14) -- false
--- math.isinf(0)    -- false
--- ```
function math.isinf(n) end

--- Check if a number is NaN (Not a Number).<br>
--- Returns true if the number is NaN using the IEEE 754 standard check.
--- @param n number Input number to check.
--- @return boolean boolean True if the number is NaN.
--- @usage <br>
--- ```
--- math.isnan(0/0)           -- true
--- math.isnan(math.sqrt(-1)) -- true (if supported)
--- math.isnan(3.14)          -- false
--- math.isnan(0)             -- false
--- ```
function math.isnan(n) end

--- Check if a number is finite.<br>
--- Returns true if the number is neither infinite nor NaN.
--- @param n number Input number to check.
--- @return boolean boolean True if the number is finite.
--- @usage <br>
--- ```
--- math.isfinite(3.14) -- true
--- math.isfinite(0)    -- true
--- math.isfinite(1/0)  -- false
--- math.isfinite(0/0)  -- false
--- ```
function math.isfinite(n) end

--- Get the absolute value of a number (replicating math.abs, but without C call overhead).<br>
--- Returns the non-negative value of the input.
--- @param n number Input number.
--- @return number number Absolute value.
--- @usage <br>
--- ```
--- math.absolute(-5)   -- 5
--- math.absolute(3.14) -- 3.14
--- math.absolute(0)    -- 0
--- ```
function math.absolute(n) end

--- Calculate the absolute difference between two numbers.<br>
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
function math.difference(x, y) end

--- Check if a number is approximately equal to another within a tolerance.<br>
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
function math.approx(a, b, epsilon) end

--- Clamp a number between minimum and maximum values (replicating min(max(n,low),high), but without C call overhead).
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
function math.clamp(n, min, max) end

--- Clamp a number between 0 and 1 (replicating min(max(n,0),1), but without C call overhead).<br>
--- Convenience function for normalizing values to 0-1 range.
--- @param n number Input number to normalize.
--- @return number number Normalized value between 0 and 1.
--- @usage <br>
--- ```
--- math.clamp01(-0.5) -- 0
--- math.clamp01(0.5)  -- 0.5
--- math.clamp01(1.5)  -- 1
--- ```
function math.clamp01(n) end

--- Get the fractional part of a number.<br>
--- Returns only the fractional component of a number (everything after the decimal point).
--- @param n number Input number to extract fractional part from.
--- @return number number Fractional part of the number.
--- @usage <br>
--- ```
--- math.fractional(3.14) -- 0.14
--- math.fractional(-2.7) -- -0.7
--- math.fractional(5.0)  -- 0.0
--- ```
function math.fractional(n) end

math.frac = math.fractional

--- Returns the maximum of two numbers (replicating math.max, but without C call overhead).
--- @param a number First number.
--- @param b number Second number.
--- @return number max The larger of a and b.
--- @usage <br>
--- math.maximum(5, 3) --> 5<br>
--- math.maximum(-2, 7) --> 7<br>
--- math.maximum(0, 0) --> 0
function math.maximum(a, b) end

--- Returns the minimum of two numbers (replicating math.min, but without C call overhead).
--- @param a number First number.
--- @param b number Second number.
--- @return number min The smaller of a and b.
--- @usage <br>
--- math.minimum(5, 3) --> 3<br>
--- math.minimum(-2, 7) --> -2<br>
--- math.minimum(0, 0) --> 0
function math.minimum(a, b) end

--- Convert a number to an integer by removing the fractional part.<br>
--- Equivalent to math.modf, but returns only the integer component.
--- @param n number Input number to convert.
--- @return integer integer Integer part of the number.
--- @usage <br>
--- ```
--- math.toint(3.14) -- 3
--- math.toint(-2.7) -- -2
--- math.toint(5.0)  -- 5
--- ```
function math.toint(n) end

--- Alias for math.toint.
--- @see math.toint
function math.tointeger(n) end

--- Round a number to the nearest integer (towards zero) or to specified decimal places.<br>
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
function math.round(n, digits) end

--- Convert a float to integer with rounding towards zero.
--- @param n number Input number to convert.
--- @return integer integer Integer value using floor with rounding.
--- @usage <br>
--- ```
--- math.trunc(3.14) -- 3
--- math.trunc(-2.7) -- -2
--- math.trunc(5.9)  -- 5
--- math.trunc(-5.1) -- -5
--- ```
function math.trunc(n) end

--- Get both sine and cosine values for an angle.<br>
--- Returns both sin and cos values in a single call for efficiency.
--- @param n number Angle in radians.
--- @return number sin Sine value of the angle.
--- @return number cos Cosine value of the angle.
--- @usage <br>
--- ```
--- local sin_val, cos_val = math.sincos(math.pi / 4)
--- -- sin_val ≈ 0.7071, cos_val ≈ 0.7071
--- ```
function math.sincos(n) end

--- Get the sign of a number.<br>
--- Returns -1 for negative numbers, 1 for positive numbers, and 0 for zero.
--- @param n number Input number.
--- @return number number Sign value (-1, 0, or 1).
--- @usage <br>
--- ```
--- math.sign(-5)   -- -1
--- math.sign(3.14) -- 1
--- math.sign(0)    -- 0
--- ```
function math.sign(n) end

--- Map a value from one range to another.<br>
--- Converts a value from [in_min,in_max] range to [out_min,out_max] range.
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
function math.map(n, in_min, in_max, out_min, out_max) end

--- Remap a value from one range to another without clamping.<br>
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
function math.remap(n, in_min, in_max, out_min, out_max) end

--- Calculate the progress of a value within a range.<br>
--- Returns the normalized position [0,1+] of a value within [min,max] range without clamping.
--- @param n number Input value.
--- @param min number Range minimum.
--- @param max number Range maximum.
--- @return number number Progress value (may be outside [0..1] range).
--- @usage <br>
--- ```
--- math.progress(5, 0, 10)  -- 0.5
--- math.progress(15, 0, 10) -- 1.5 (not clamped)
--- math.progress(-5, 0, 10) -- -0.5 (not clamped)
--- ```
function math.progress(n, min, max) end

--- Get the percentage of a value within a range.<br>
--- Returns what percentage [0..1] value is of the range [min,max].
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
function math.percent(n, min, max) end

--- Wrap a number within a range.<br>
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
function math.wrap(n, min, max) end

--- Calculate the greatest common divisor of two numbers.<br>
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
function math.gcd(a, b) end

--- Perform floor division of two numbers.<br>
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
function math.floordiv(a, b) end

--- Perform integer division with truncation toward zero.<br>
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
function math.intdiv(a, b) end

--- Truncate a number to an integer or specified decimal places.<br>
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
function math.truncate(n, idp) end

--- Scale a number from [0..1] range to [min,max] range.<br>
--- Linearly scales a normalized value (0-1) to the specified range.
--- @param n number Input number in [0..1] range.
--- @param min number Target range minimum.
--- @param max number Target range maximum.
--- @return number number Scaled value in [min,max] range.
--- @usage <br>
--- ```
--- math.scale(0.5, 0, 10)    -- 5
--- math.scale(0.25, -5, 5)   -- -2.5
--- math.scale(1.0, 100, 200) -- 200
--- ```
function math.scale(n, min, max) end

--- Generate a random number in a specified range.<br>
--- Returns a random float between min and max (inclusive of min, exclusive of max).
--- @param min number Minimum value.
--- @param max number Maximum value.
--- @return number number Random number in [min,max) range.
--- @usage <br>
--- ```
--- math.rand(0, 10)    -- Random number between 0 and 10
--- math.rand(-5, 5)    -- Random number between -5 and 5
--- math.rand(100, 200) -- Random number between 100 and 200
--- ```
function math.rand(min, max) end

--- Check if a number is within a specified range.<br>
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
function math.inrange(n, min, max) end

--- Snap a number to the nearest multiple of a step value.<br>
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
function math.snapto(n, step) end

--- Move a value toward a target by a maximum step amount.<br>
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
function math.approach(current, target, step) end

--- Linear interpolation between two values.<br>
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
function math.lerp(t, from, to) end

--- Linear interpolation between two values with clamping.<br>
--- Returns a value interpolated between start and end based on t (0-1, clamped).
--- @param t number Interpolation factor (0 = start, 1 = end, clamped to 0-1).
--- @param from number Starting value.
--- @param to number Ending value.
--- @return number number Interpolated value.
--- @usage <br>
--- ```
--- math.lerp_clamp(0.5, 0, 10)   -- 5
--- math.lerp_clamp(0.25, 10, 20) -- 12.5
--- math.lerp_clamp(1.5, 0, 100)  -- 100 (clamped)
--- ```
function math.lerp_clamp(t, from, to) end

--- Performs inverse linear interpolation (unlerp).<br>
--- Returns the interpolation parameter t that would produce the given value when lerping between from and to.<br>
--- Essentially finds what percentage (0-1) the value is between from and to.
--- @param value number The value to find the interpolation parameter for.
--- @param from number The start value of the interpolation range.
--- @param to number The end value of the interpolation range.
--- @return number value The interpolation parameter (0-1 range, can be outside if value is outside range).
--- @usage <br>
--- ```
--- local t = math.unlerp(25, 0, 100)   -- Returns 0.25 (25% of the way from 0 to 100)
--- local t2 = math.unlerp(150, 0, 100) -- Returns 1.5 (50% beyond the end)
--- ```
function math.unlerp(value, from, to) end

return math
