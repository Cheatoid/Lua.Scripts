-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

---@meta

---@class mathlib
local math = {}

--- Tau constant (2 * pi).<br>
--- Represents a full circle in radians (approximately 6.283185...).
---@type number
math.tau = 2 * math.pi

--- Degrees to radians conversion factor.<br>
--- Multiply degrees by this value to convert to radians.
---@type number
math.deg2rad = math.pi / 180

--- Radians to degrees conversion factor.<br>
--- Multiply radians by this value to convert to degrees.
---@type number
math.rad2deg = 180 / math.pi

--- Check if a number is infinite.<br>
--- Returns true if the number is positive or negative infinity.
---@param n number Input number to check.
---@return boolean boolean True if the number is infinite.
---@usage <br>
--- ```
--- math.isinf(1/0)  -- true
--- math.isinf(-1/0) -- true
--- math.isinf(3.14) -- false
--- math.isinf(0)    -- false
--- ```
function math.isinf(n) end

--- Check if a number is NaN (Not a Number).<br>
--- Returns true if the number is NaN using the IEEE 754 standard check.
---@param n number Input number to check.
---@return boolean boolean True if the number is NaN.
---@usage <br>
--- ```
--- math.isnan(0/0)           -- true
--- math.isnan(math.sqrt(-1)) -- true (if supported)
--- math.isnan(3.14)          -- false
--- math.isnan(0)             -- false
--- ```
function math.isnan(n) end

--- Check if a number is finite.<br>
--- Returns true if the number is neither infinite nor NaN.
---@param n number Input number to check.
---@return boolean boolean True if the number is finite.
---@usage <br>
--- ```
--- math.isfinite(3.14) -- true
--- math.isfinite(0)    -- true
--- math.isfinite(1/0)  -- false
--- math.isfinite(0/0)  -- false
--- ```
function math.isfinite(n) end

--- Get the absolute value of a number (replicating math.abs, but without C call overhead).<br>
--- Returns the non-negative value of the input.
---@param n number Input number.
---@return number number Absolute value.
---@usage <br>
--- ```
--- math.absolute(-5)   -- 5
--- math.absolute(3.14) -- 3.14
--- math.absolute(0)    -- 0
--- ```
function math.absolute(n) end

--- Calculate the absolute difference between two numbers.<br>
--- Returns the non-negative difference between x and y.
---@param x number First number.
---@param y number Second number.
---@return number number Absolute difference.
---@usage <br>
--- ```
--- math.difference(10, 3)    -- 7
--- math.difference(3, 10)    -- 7
--- math.difference(-5, -2)   -- 3
--- math.difference(5.5, 2.2) -- 3.3
--- ```
function math.difference(x, y) end

--- Check if a number is approximately equal to another within a tolerance.<br>
--- Useful for floating point comparisons.
---@param a number First number.
---@param b number Second number.
---@param epsilon number|nil Tolerance for comparison (default: 1e-6).
---@return boolean boolean True if numbers are approximately equal.
---@usage <br>
--- ```
--- math.approx(0.1 + 0.2, 0.3) -- true
--- math.approx(1.0, 1.000001)  -- true
--- math.approx(1.0, 1.1, 0.05) -- false
--- ```
function math.approx(a, b, epsilon) end

--- Clamp a number between minimum and maximum values (replicating min(max(n,low),high), but without C call overhead).
---@param n number Input number to clamp.
---@param min number Minimum value (lower bound).
---@param max number Maximum value (upper bound).
---@return number number Clamped value between min and max.
---@usage <br>
--- ```
--- math.clamp(15, 0, 10) -- 10
--- math.clamp(-5, 0, 10) -- 0
--- math.clamp(5, 0, 10)  -- 5
--- ```
function math.clamp(n, min, max) end

--- Clamp a number between 0 and 1 (replicating min(max(n,0),1), but without C call overhead).<br>
--- Convenience function for normalizing values to 0-1 range.
---@param n number Input number to normalize.
---@return number number Normalized value between 0 and 1.
---@usage <br>
--- ```
--- math.clamp01(-0.5) -- 0
--- math.clamp01(0.5)  -- 0.5
--- math.clamp01(1.5)  -- 1
--- ```
function math.clamp01(n) end

--- Get the fractional part of a number.<br>
--- Returns only the fractional component of a number (everything after the decimal point).
---@param n number Input number to extract fractional part from.
---@return number number Fractional part of the number.
---@usage <br>
--- ```
--- math.fractional(3.14) -- 0.14
--- math.fractional(-2.7) -- -0.7
--- math.fractional(5.0)  -- 0.0
--- ```
function math.fractional(n) end

math.frac = math.fractional

--- Returns the maximum of two numbers (replicating math.max, but without C call overhead).
---@param a number First number.
---@param b number Second number.
---@return number max The larger of a and b.
---@usage <br>
--- math.maximum(5, 3) --> 5<br>
--- math.maximum(-2, 7) --> 7<br>
--- math.maximum(0, 0) --> 0
function math.maximum(a, b) end

--- Returns the minimum of two numbers (replicating math.min, but without C call overhead).
---@param a number First number.
---@param b number Second number.
---@return number min The smaller of a and b.
---@usage <br>
--- math.minimum(5, 3) --> 3<br>
--- math.minimum(-2, 7) --> -2<br>
--- math.minimum(0, 0) --> 0
function math.minimum(a, b) end

--- Convert a number to an integer by removing the fractional part.<br>
--- Equivalent to math.modf, but returns only the integer component.
---@param n number Input number to convert.
---@return integer integer Integer part of the number.
---@usage <br>
--- ```
--- math.toint(3.14) -- 3
--- math.toint(-2.7) -- -2
--- math.toint(5.0)  -- 5
--- ```
function math.toint(n) end

--- Alias for math.toint.
---@see math.toint
function math.tointeger(n) end

--- Alias for math.fractional.
---@see math.fractional
function math.frac(n) end

--- Round a number to the nearest integer (towards zero) or to specified decimal places.<br>
--- Rounds to the nearest integer, with .5 rounding up. If digits is provided, rounds to that many decimal places.
---@param n number Input number to round.
---@param digits number|nil Number of decimal places to round to (default: 0 for integer rounding).
---@return number number Rounded number.
---@usage <br>
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
---@param n number Input number to convert.
---@return integer integer Integer value using floor with rounding.
---@usage <br>
--- ```
--- math.trunc(3.14) -- 3
--- math.trunc(-2.7) -- -2
--- math.trunc(5.9)  -- 5
--- math.trunc(-5.1) -- -5
--- ```
function math.trunc(n) end

--- Get both sine and cosine values for an angle.<br>
--- Returns both sin and cos values in a single call for efficiency.
---@param n number Angle in radians.
---@return number sin Sine value of the angle.
---@return number cos Cosine value of the angle.
---@usage <br>
--- ```
--- local sin_val, cos_val = math.sincos(math.pi / 4)
--- -- sin_val ≈ 0.7071, cos_val ≈ 0.7071
--- ```
function math.sincos(n) end

--- Get the sign of a number.<br>
--- Returns -1 for negative numbers, 1 for positive numbers, and 0 for zero.
---@param n number Input number.
---@return number number Sign value (-1, 0, or 1).
---@usage <br>
--- ```
--- math.sign(-5)   -- -1
--- math.sign(3.14) -- 1
--- math.sign(0)    -- 0
--- ```
function math.sign(n) end

--- Map a value from one range to another.<br>
--- Converts a value from [in_min,in_max] range to [out_min,out_max] range.
---@param n number Input value to map.
---@param in_min number Input range minimum.
---@param in_max number Input range maximum.
---@param out_min number Output range minimum.
---@param out_max number Output range maximum.
---@return number number Mapped value.
---@usage <br>
--- ```
--- math.map(5, 0, 10, 0, 100) -- 50
--- math.map(0.5, 0, 1, -1, 1) -- 0
--- math.map(75, 0, 100, 0, 1) -- 0.75
--- ```
function math.map(n, in_min, in_max, out_min, out_max) end

--- Remap a value from one range to another without clamping.<br>
--- Similar to math.map but does not clamp the output to the target range.
---@param n number Input value to remap.
---@param in_min number Input range minimum.
---@param in_max number Input range maximum.
---@param out_min number Output range minimum.
---@param out_max number Output range maximum.
---@return number number Remapped value (may be outside output range).
---@usage <br>
--- ```
--- math.remap(5, 0, 10, 0, 100)  -- 50
--- math.remap(15, 0, 10, 0, 100) -- 150 (not clamped)
--- math.remap(-5, 0, 10, -1, 1)  -- -0.5
--- ```
function math.remap(n, in_min, in_max, out_min, out_max) end

--- Calculate the progress of a value within a range.<br>
--- Returns the normalized position [0,1+] of a value within [min,max] range without clamping.
---@param n number Input value.
---@param min number Range minimum.
---@param max number Range maximum.
---@return number number Progress value (may be outside [0..1] range).
---@usage <br>
--- ```
--- math.progress(5, 0, 10)  -- 0.5
--- math.progress(15, 0, 10) -- 1.5 (not clamped)
--- math.progress(-5, 0, 10) -- -0.5 (not clamped)
--- ```
function math.progress(n, min, max) end

--- Get the percentage of a value within a range.<br>
--- Returns what percentage [0..1] value is of the range [min,max].
---@param n number Input value.
---@param min number Range minimum.
---@param max number Range maximum.
---@return number number Percentage (0-1).
---@usage <br>
--- ```
--- math.percent(5, 0, 10)   -- 0.5
--- math.percent(25, 0, 100) -- 0.25
--- math.percent(15, 10, 20) -- 0.5
--- ```
function math.percent(n, min, max) end

--- Wrap a number within a range.<br>
--- Similar to modulo but works correctly with negative numbers.
---@param n number Input number to wrap.
---@param min number Range minimum.
---@param max number Range maximum.
---@return number number Wrapped value within [min, max).
---@usage <br>
--- ```
--- math.wrap(7, 0, 5)   -- 2
--- math.wrap(-1, 0, 5)  -- 4
--- math.wrap(12, 0, 10) -- 2
--- ```
function math.wrap(n, min, max) end

--- Calculate the greatest common divisor of two numbers.<br>
--- Uses the Euclidean algorithm to find the largest integer that divides both numbers.
---@param a number First number (must be non-negative integer).
---@param b number Second number (must be non-negative integer).
---@return number number Greatest common divisor.
---@usage <br>
--- ```
--- math.gcd(48, 18)  -- 6
--- math.gcd(17, 23)  -- 1
--- math.gcd(100, 25) -- 25
--- ```
function math.gcd(a, b) end

--- Perform floor division of two numbers.<br>
--- Returns the largest integer less than or equal to the exact division result.
---@param a number Dividend.
---@param b number Divisor (must not be zero).
---@return number number Floor division result.
---@usage <br>
--- ```
--- math.floordiv(7, 3)   -- 2
--- math.floordiv(-7, 3)  -- -3
--- math.floordiv(7, -3)  -- -3
--- math.floordiv(-7, -3) -- 2
--- ```
function math.floordiv(a, b) end

--- Perform integer division with truncation toward zero.<br>
--- Returns the integer part of division, truncating toward zero like C-style integer division.
---@param a number Dividend.
---@param b number Divisor (must not be zero).
---@return number number Integer division result.
---@usage <br>
--- ```
--- math.intdiv(7, 3)   -- 2
--- math.intdiv(-7, 3)  -- -2
--- math.intdiv(7, -3)  -- -2
--- math.intdiv(-7, -3) -- 2
--- ```
function math.intdiv(a, b) end

--- Truncate a number to an integer or specified decimal places.<br>
--- Removes fractional part by truncating toward zero. If idp is provided, truncates to that many decimal places.
---@param n number Input number to truncate.
---@param idp number|nil Number of decimal places to truncate to (default: 0 for integer truncation).
---@return number number Truncated number.
---@usage <br>
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
---@param n number Input number in [0..1] range.
---@param min number Target range minimum.
---@param max number Target range maximum.
---@return number number Scaled value in [min,max] range.
---@usage <br>
--- ```
--- math.scale(0.5, 0, 10)    -- 5
--- math.scale(0.25, -5, 5)   -- -2.5
--- math.scale(1.0, 100, 200) -- 200
--- ```
function math.scale(n, min, max) end

--- Generate a random number in a specified range.<br>
--- Returns a random float between min and max (inclusive of min, exclusive of max).
---@param min number Minimum value.
---@param max number Maximum value.
---@return number number Random number in [min,max) range.
---@usage <br>
--- ```
--- math.rand(0, 10)    -- Random number between 0 and 10
--- math.rand(-5, 5)    -- Random number between -5 and 5
--- math.rand(100, 200) -- Random number between 100 and 200
--- ```
function math.rand(min, max) end

--- Check if a number is within a specified range.<br>
--- Returns true if the number is between min and max (inclusive).
---@param n number Number to check.
---@param min number Range minimum.
---@param max number Range maximum.
---@return boolean boolean True if number is within range.
---@usage <br>
--- ```
--- math.inrange(5, 0, 10)  -- true
--- math.inrange(-2, -5, 5) -- true
--- math.inrange(15, 0, 10) -- false
--- math.inrange(0, 0, 10)  -- true
--- ```
function math.inrange(n, min, max) end

--- Snap a number to the nearest multiple of a step value.<br>
--- Rounds the number to the nearest increment of the specified step size.
---@param n number Input number to snap.
---@param step number Step size to snap to.
---@return number number Snapped value.
---@usage <br>
--- ```
--- math.snapto(7, 5)     -- 5
--- math.snapto(13, 5)    -- 15
--- math.snapto(2.7, 0.5) -- 2.5
--- math.snapto(3.14, 1)  -- 3
--- ```
function math.snapto(n, step) end

--- Move a value toward a target by a maximum step amount.<br>
--- Returns a new value that moves closer to the target but doesn't exceed the step size.
---@param current number Current value.
---@param target number Target value to approach.
---@param step number Maximum step size (always treated as positive).
---@return number number New value moved toward target.
---@usage <br>
--- ```
--- math.approach(10, 20, 3)  -- 13
--- math.approach(10, 5, 2)   -- 8
--- math.approach(10, 15, 10) -- 15 (reached target)
--- math.approach(10, 12, 5)  -- 12 (reached target)
--- ```
function math.approach(current, target, step) end

--- Linear interpolation between two values.<br>
--- Returns a value interpolated between start and end based on t (0-1).
---@param t number Interpolation factor (0 = start, 1 = end).
---@param from number Starting value.
---@param to number Ending value.
---@return number number Interpolated value.
---@usage <br>
--- ```
--- math.lerp(0.5, 0, 10)   -- 5
--- math.lerp(0.25, 10, 20) -- 12.5
--- math.lerp(1.5, 0, 100)  -- 150 (not clamped)
--- ```
function math.lerp(t, from, to) end

--- Linear interpolation between two values with clamping.<br>
--- Returns a value interpolated between start and end based on t (0-1, clamped).
---@param t number Interpolation factor (0 = start, 1 = end, clamped to 0-1).
---@param from number Starting value.
---@param to number Ending value.
---@return number number Interpolated value.
---@usage <br>
--- ```
--- math.lerp_clamp(0.5, 0, 10)   -- 5
--- math.lerp_clamp(0.25, 10, 20) -- 12.5
--- math.lerp_clamp(1.5, 0, 100)  -- 100 (clamped)
--- ```
function math.lerp_clamp(t, from, to) end

--- Performs inverse linear interpolation (unlerp).<br>
--- Returns the interpolation parameter t that would produce the given value when lerping between from and to.<br>
--- Essentially finds what percentage (0-1) the value is between from and to.
---@param value number The value to find the interpolation parameter for.
---@param from number The start value of the interpolation range.
---@param to number The end value of the interpolation range.
---@return number value The interpolation parameter (0-1 range, can be outside if value is outside range).
---@usage <br>
--- ```
--- local t = math.unlerp(25, 0, 100)   -- Returns 0.25 (25% of the way from 0 to 100)
--- local t2 = math.unlerp(150, 0, 100) -- Returns 1.5 (50% beyond the end)
--- ```
function math.unlerp(value, from, to) end

--- Alias for math.unlerp.
---@see math.unlerp
function math.inverse_lerp(value, from, to) end

--- Quadratic ease-in easing function.<br>
--- Accelerates from zero velocity (t^2).
---@param t number Interpolation factor (0-1).
---@return number number Eased value.
---@usage <br>
--- ```
--- math.ease_in_quad(0.0) -- 0.0
--- math.ease_in_quad(0.5) -- 0.25
--- math.ease_in_quad(1.0) -- 1.0
--- ```
function math.ease_in_quad(t) end

--- Alias for math.ease_in_quad.
---@see math.ease_in_quad
function math.sqr(t) end

--- Quadratic ease-out easing function.<br>
--- Decelerates to zero velocity (t * (2 - t)).
---@param t number Interpolation factor (0-1).
---@return number number Eased value.
---@usage <br>
--- ```
--- math.ease_out_quad(0.0) -- 0.0
--- math.ease_out_quad(0.5) -- 0.75
--- math.ease_out_quad(1.0) -- 1.0
--- ```
function math.ease_out_quad(t) end

--- Quadratic ease-in-out easing function.<br>
--- Accelerates then decelerates (2t^2 for t<0.5, -1+(4-2t)*t for t>=0.5).
---@param t number Interpolation factor (0-1).
---@return number number Eased value.
---@usage <br>
--- ```
--- math.ease_in_out_quad(0.0) -- 0.0
--- math.ease_in_out_quad(0.5) -- 0.5
--- math.ease_in_out_quad(1.0) -- 1.0
--- ```
function math.ease_in_out_quad(t) end

--- Cubic ease-in easing function.<br>
--- Accelerates from zero velocity (t^3).
---@param t number Interpolation factor (0-1).
---@return number number Eased value.
---@usage <br>
--- ```
--- math.ease_in_cubic(0.0) -- 0.0
--- math.ease_in_cubic(0.5) -- 0.125
--- math.ease_in_cubic(1.0) -- 1.0
--- ```
function math.ease_in_cubic(t) end

--- Cubic ease-out easing function.<br>
--- Decelerates to zero velocity ((t-1)^3 + 1).
---@param t number Interpolation factor (0-1).
---@return number number Eased value.
---@usage <br>
--- ```
--- math.ease_out_cubic(0.0) -- 0.0
--- math.ease_out_cubic(0.5) -- 0.875
--- math.ease_out_cubic(1.0) -- 1.0
--- ```
function math.ease_out_cubic(t) end

--- Cubic ease-in-out easing function.<br>
--- Accelerates then decelerates (4t^3 for t<0.5, (t-1)*(2t-2)*(2t-2)+1 for t>=0.5).
---@param t number Interpolation factor (0-1).
---@return number number Eased value.
---@usage <br>
--- ```
--- math.ease_in_out_cubic(0.0) -- 0.0
--- math.ease_in_out_cubic(0.5) -- 0.5
--- math.ease_in_out_cubic(1.0) -- 1.0
--- ```
function math.ease_in_out_cubic(t) end

--- Smoothstep easing function (Hermite interpolation).<br>
--- Smooth interpolation with zero derivatives at endpoints (t^2 * (3 - 2t)).
---@param t number Interpolation factor (0-1).
---@return number number Smoothed value.
---@usage <br>
--- ```
--- math.smoothstep(0.0) -- 0.0
--- math.smoothstep(0.5) -- 0.5
--- math.smoothstep(1.0) -- 1.0
--- ```
function math.smoothstep(t) end

--- Smootherstep easing function (Perlin's improved smoothstep).<br>
--- Smoother interpolation with zero derivatives at endpoints (t^3 * (t * (6t - 15) + 10)).
---@param t number Interpolation factor (0-1).
---@return number number Smoothed value.
---@usage <br>
--- ```
--- math.smootherstep(0.0) -- 0.0
--- math.smootherstep(0.5) -- 0.5
--- math.smootherstep(1.0) -- 1.0
--- ```
function math.smootherstep(t) end

--- Convert degrees to radians (replicating math.rad, but without C call overhead).<br>
--- Multiplies the degree value by the conversion factor.
---@param deg number Angle in degrees.
---@return number number Angle in radians.
---@usage <br>
--- ```
--- math.deg_to_rad(180) -- 3.14159...
--- math.deg_to_rad(90)  -- 1.57079...
--- math.deg_to_rad(0)   -- 0
--- ```
function math.deg_to_rad(deg) end

--- Alias for math.deg_to_rad (replicating math.rad, but without C call overhead).
---@see math.deg_to_rad
function math.degtorad(deg) end

--- Convert radians to degrees (replicating math.deg, but without C call overhead).<br>
--- Multiplies the radian value by the conversion factor.
---@param rad number Angle in radians.
---@return number number Angle in degrees.
---@usage <br>
--- ```
--- math.rad_to_deg(math.pi) -- 180
--- math.rad_to_deg(math.pi/2) -- 90
--- math.rad_to_deg(0) -- 0
--- ```
function math.rad_to_deg(rad) end

--- Alias for math.rad_to_deg (replicating math.deg, but without C call overhead).
---@see math.rad_to_deg
function math.radtodeg(rad) end

--- Normalize an angle to the range [-180, 180].<br>
--- Wraps the angle to the shortest representation around zero.
---@param angle number Angle in degrees.
---@return number number Normalized angle in [-180, 180] range.
---@usage <br>
--- ```
--- math.normalize_angle(190)  -- -170
--- math.normalize_angle(-200) -- 160
--- math.normalize_angle(90)   -- 90
--- math.normalize_angle(540)  -- 180
--- ```
function math.normalize_angle(angle) end

--- Normalize an angle to the range [0, 360].<br>
--- Wraps the angle to a positive representation.
---@param angle number Angle in degrees.
---@return number number Normalized angle in [0, 360] range.
---@usage <br>
--- ```
--- math.normalize_angle_360(-90) -- 270
--- math.normalize_angle_360(450) -- 90
--- math.normalize_angle_360(180) -- 180
--- math.normalize_angle_360(720) -- 0
--- ```
function math.normalize_angle_360(angle) end

--- Linear interpolation between two angles with wrapping.<br>
--- Interpolates between angles taking the shortest path around the circle.
---@param from number Starting angle in degrees.
---@param to number Target angle in degrees.
---@param t number Interpolation factor (0-1).
---@return number number Interpolated angle in degrees.
---@usage <br>
--- ```
--- math.lerp_angle(0, 270, 0.5) -- -135 (takes shortest path)
--- math.lerp_angle(0, 90, 0.5)  -- 45
--- math.lerp_angle(350, 10, 0.5) -- 0 (wraps around)
--- ```
function math.lerp_angle(from, to, t) end

--- Get the shortest difference between two angles.<br>
--- Returns the signed difference from a to b in the range [-180, 180].
---@param a number First angle in degrees.
---@param b number Second angle in degrees.
---@return number number Difference in degrees [-180, 180].
---@usage <br>
--- ```
--- math.angle_diff(0, 90)   -- 90
--- math.angle_diff(0, 270)  -- -90 (shortest path)
--- math.angle_diff(350, 10) -- 20
--- math.angle_diff(10, 350)  -- -20
--- ```
function math.angle_diff(a, b) end

--- Calculate the Euclidean distance between two 2D points.<br>
--- Returns the straight-line distance between (x1,y1) and (x2,y2).
---@param x1 number X coordinate of first point.
---@param y1 number Y coordinate of first point.
---@param x2 number X coordinate of second point.
---@param y2 number Y coordinate of second point.
---@return number number Euclidean distance.
---@usage <br>
--- ```
--- math.distance(0, 0, 3, 4)    -- 5
--- math.distance(1, 2, 4, 6)    -- 5
--- math.distance(-1, -1, 2, 3) -- 5
--- ```
function math.distance(x1, y1, x2, y2) end

--- Alias for math.distance.
---@see math.distance
function math.dist(x1, y1, x2, y2) end

--- Calculate the squared distance between two 2D points.<br>
--- Faster than distance() when only comparing distances (avoids sqrt).
---@param x1 number X coordinate of first point.
---@param y1 number Y coordinate of first point.
---@param x2 number X coordinate of second point.
---@param y2 number Y coordinate of second point.
---@return number number Squared Euclidean distance.
---@usage <br>
--- ```
--- math.distance_squared(0, 0, 3, 4) -- 25
--- math.distance_squared(1, 1, 4, 5) -- 25
--- ```
function math.distance_squared(x1, y1, x2, y2) end

--- Alias for math.distance_squared.
---@see math.distance_squared
function math.dist_sq(x1, y1, x2, y2) end

--- Calculate the Euclidean distance between two 3D points.<br>
--- Returns the straight-line distance between (x1,y1,z1) and (x2,y2,z2).
---@param x1 number X coordinate of first point.
---@param y1 number Y coordinate of first point.
---@param z1 number Z coordinate of first point.
---@param x2 number X coordinate of second point.
---@param y2 number Y coordinate of second point.
---@param z2 number Z coordinate of second point.
---@return number number Euclidean distance.
---@usage <br>
--- ```
--- math.distance_3d(0, 0, 0, 1, 2, 2) -- 3
--- math.distance_3d(1, 1, 1, 4, 5, 5) -- 6
--- ```
function math.distance_3d(x1, y1, z1, x2, y2, z2) end

--- Calculate the squared distance between two 3D points.<br>
--- Faster than distance_3d() when only comparing distances (avoids sqrt).
---@param x1 number X coordinate of first point.
---@param y1 number Y coordinate of first point.
---@param z1 number Z coordinate of first point.
---@param x2 number X coordinate of second point.
---@param y2 number Y coordinate of second point.
---@param z2 number Z coordinate of second point.
---@return number number Squared Euclidean distance.
---@usage <br>
--- ```
--- math.distance_3d_squared(0, 0, 0, 1, 2, 2) -- 9
--- math.distance_3d_squared(1, 1, 1, 4, 5, 5) -- 36
--- ```
function math.distance_3d_squared(x1, y1, z1, x2, y2, z2) end

--- Oscillate a value back and forth (ping-pong effect).<br>
--- Returns a value that oscillates between 0 and length, bouncing at the edges.
---@param t number Input value (typically time).
---@param length number|nil Length of the oscillation range (default: 1).
---@return number number Oscillating value in [0, length].
---@usage <br>
--- ```
--- math.pingpong(0.0, 1) -- 0
--- math.pingpong(0.5, 1) -- 0.5
--- math.pingpong(1.0, 1) -- 1
--- math.pingpong(1.5, 1) -- 0.5
--- math.pingpong(2.0, 1) -- 0
--- ```
function math.pingpong(t, length) end

--- Bounce a value between min and max using sine wave.<br>
--- Returns a value that oscillates between min and max.
---@param t number Input value (typically time).
---@param min number Minimum value.
---@param max number Maximum value.
---@return number number Bounced value in [min, max].
---@usage <br>
--- ```
--- math.bounce(0, 0, 10) -- 0
--- math.bounce(math.pi/2, 0, 10) -- 10
--- math.bounce(math.pi, 0, 10) -- 0
--- math.bounce(3*math.pi/2, 0, 10) -- 10
--- ```
function math.bounce(t, min, max) end

--- Calculate the average (arithmetic mean) of numbers.<br>
--- Returns the sum of all numbers divided by the count.
---@param ... number Numbers to average.
---@return number number Average value.
---@usage <br>
--- ```
--- math.average(1, 2, 3, 4, 5) -- 3
--- math.average(10, 20) -- 15
--- math.average(-5, 5) -- 0
--- ```
function math.average(...) end

--- Alias for math.average.
---@see math.average
function math.mean(...) end

--- Calculate the sum of numbers.<br>
--- Returns the total of all provided numbers.
---@param ... number Numbers to sum.
---@return number number Sum of all numbers.
---@usage <br>
--- ```
--- math.sum(1, 2, 3, 4, 5) -- 15
--- math.sum(10, 20, 30) -- 60
--- math.sum(-5, 5, 10) -- 10
--- ```
function math.sum(...) end

--- Calculate the range between two numbers.<br>
--- Returns the difference between max and min.
---@param min number Minimum value.
---@param max number Maximum value.
---@return number number Range (max - min).
---@usage <br>
--- ```
--- math.range(0, 10) -- 10
--- math.range(-5, 5) -- 10
--- math.range(100, 200) -- 100
--- ```
function math.range(min, max) end

--- Calculate the midpoint between two numbers.<br>
--- Returns the average of two values.
---@param a number First number.
---@param b number Second number.
---@return number number Midpoint value.
---@usage <br>
--- ```
--- math.mid(0, 10) -- 5
--- math.mid(-5, 5) -- 0
--- math.mid(100, 200) -- 150
--- ```
function math.mid(a, b) end

--- Safe square root that handles negative numbers.<br>
--- Returns 0 for negative inputs instead of NaN.
---@param n number Input number.
---@return number number Square root (0 if n < 0).
---@usage <br>
--- ```
--- math.sqrt_safe(9) -- 3
--- math.sqrt_safe(-1) -- 0 (instead of NaN)
--- math.sqrt_safe(0) -- 0
--- ```
function math.sqrt_safe(n) end

--- Safe logarithm that handles non-positive numbers.<br>
--- Returns 0 for non-positive inputs instead of NaN.
---@param n number Input number.
---@param base number|nil Logarithm base (default: 10).
---@return number number Logarithm (0 if n <= 0).
---@usage <br>
--- ```
--- math.log_safe(100) -- 2 (log base 10)
--- math.log_safe(100, 2) -- ~6.64 (log base 2)
--- math.log_safe(0) -- 0 (instead of -inf)
--- math.log_safe(-1) -- 0 (instead of NaN)
--- ```
function math.log_safe(n, base) end

--- Check if a number is a power of two.<br>
--- Returns true if the number is exactly a power of two.
---@param n number Input number (must be positive integer).
---@return boolean boolean True if n is a power of two.
---@usage <br>
--- ```
--- math.is_power_of_two(1) -- true
--- math.is_power_of_two(2) -- true
--- math.is_power_of_two(4) -- true
--- math.is_power_of_two(8) -- true
--- math.is_power_of_two(6) -- false
--- math.is_power_of_two(0) -- false
--- ```
function math.is_power_of_two(n) end

--- Calculate the next power of two greater than or equal to n.<br>
--- Returns the smallest power of two that is >= n.
---@param n number Input number.
---@return number number Next power of two.
---@usage <br>
--- ```
--- math.next_power_of_two(5) -- 8
--- math.next_power_of_two(16) -- 16
--- math.next_power_of_two(17) -- 32
--- math.next_power_of_two(1) -- 1
--- ```
function math.next_power_of_two(n) end

--- Generate a random integer in a specified range.<br>
--- Returns a random integer between min and max (inclusive).
---@param min number Minimum value.
---@param max number Maximum value.
---@return integer integer Random integer in [min, max].
---@usage <br>
--- ```
--- math.random_range_int(1, 10) -- Random integer 1-10
--- math.random_range_int(0, 5)  -- Random integer 0-5
--- math.random_range_int(-5, 5) -- Random integer -5 to 5
--- ```
function math.random_range_int(min, max) end

--- Alias for math.random_range_int.
---@see math.random_range_int
function math.rand_int(min, max) end

--- Generate a random sign (-1 or 1).<br>
--- Returns either -1 or 1 with equal probability.
---@return number number Random sign (-1 or 1).
---@usage <br>
--- ```
--- math.random_sign() -- -1 or 1
--- ```
function math.random_sign() end

--- Generate a random boolean value.<br>
--- Returns true or false with equal probability.
---@return boolean boolean Random boolean.
---@usage <br>
--- ```
--- math.random_bool() -- true or false
--- ```
function math.random_bool() end

--- Choose a random value from the provided arguments.<br>
--- Returns one of the provided values at random.
---@param ... any Values to choose from.
---@return any any Randomly chosen value.
---@usage <br>
--- ```
--- math.random_choice("a", "b", "c") -- "a", "b", or "c"
--- math.random_choice(1, 2, 3, 4, 5) -- Random number 1-5
--- ```
function math.random_choice(...) end

--- Choose a random index based on weights.<br>
--- Returns an index based on the probability weights provided.
---@param weights table Array of weight values (higher = more likely).
---@return integer integer Randomly chosen index (1-based).
---@usage <br>
--- ```
--- math.random_weighted({1, 2, 3}) -- 1 (10%), 2 (20%), or 3 (30%)
--- math.random_weighted({10, 90}) -- 1 (10%) or 2 (90%)
--- ```
function math.random_weighted(weights) end

--- Move a value toward a target by a maximum delta.<br>
--- Returns a new value that moves closer to target but doesn't exceed max_delta.
---@param current number Current value.
---@param target number Target value.
---@param max_delta number Maximum step size.
---@return number number New value moved toward target.
---@usage <br>
--- ```
--- math.move_towards(10, 20, 3)  -- 13
--- math.move_towards(10, 5, 2)   -- 8
--- math.move_towards(10, 15, 10) -- 15 (reached)
--- math.move_towards(10, 12, 5)  -- 12 (reached)
--- ```
function math.move_towards(current, target, max_delta) end

--- Damp a value toward a target over time.<br>
--- Smoothly interpolates current toward target using smoothing factor and delta time.
---@param current number Current value.
---@param target number Target value.
---@param smoothing number Smoothing factor (0-1).
---@param dt number Delta time.
---@return number number Damped value.
---@usage <br>
--- ```
--- math.damp(10, 20, 0.5, 0.1) -- 10.5
--- math.damp(10, 20, 0.5, 1.0) -- 15
--- ```
function math.damp(current, target, smoothing, dt) end

--- Damp an angle toward a target over time.<br>
--- Smoothly interpolates current angle toward target using shortest path.
---@param current number Current angle in degrees.
---@param target number Target angle in degrees.
---@param smoothing number Smoothing factor (0-1).
---@param dt number Delta time.
---@return number number Damped angle in degrees.
---@usage <br>
--- ```
--- math.damp_angle(0, 270, 0.5, 0.1) -- Moves toward 270 via shortest path
--- math.damp_angle(350, 10, 0.5, 0.1) -- Moves toward 10 via shortest path
--- ```
function math.damp_angle(current, target, smoothing, dt) end

--- Calculate the cube root of a number.<br>
--- Returns the cube root, handling negative numbers correctly.
---@param n number Input number.
---@return number number Cube root.
---@usage <br>
--- ```
--- math.cbrt(8)   -- 2
--- math.cbrt(-8)  -- -2
--- math.cbrt(27)  -- 3
--- math.cbrt(0)   -- 0
--- ```
function math.cbrt(n) end

--- Alias for math.cbrt.
---@see math.cbrt
function math.cube_root(n) end

--- Repeat a value within a range (modulo).<br>
--- Returns the remainder of t divided by length.
---@param t number Input value.
---@param length number Length of the range.
---@return number number Repeated value in [0, length).
---@usage <br>
--- ```
--- math.rep(5, 3) -- 2
--- math.rep(7, 5) -- 2
--- math.rep(10, 3) -- 1
--- math.rep(-1, 5) -- 4
--- ```
function math.rep(t, length) end

return math
