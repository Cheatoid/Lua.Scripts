-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Augment existing standard math library

-- Localized global functions for better performance
--local type = type
--local isnumber = function(v) return type(v) == "number" end
---@diagnostic disable-next-line: unnecessary-assert
local math = assert(_G.math, "math library is missing") ---@type mathlib
local math_ceil = math.ceil
local math_cos = math.cos
local math_floor = math.floor
local math_log = math.log
local math_max = math.max
local math_min = math.min
local math_modf = math.modf
--local math_pow = math.pow -- deprecated: use ^ operator
local math_random = math.random
local math_sin = math.sin
local math_sqrt = math.sqrt

local TAU = 2 * math.pi
math.tau = TAU
local DEG2RAD = math.pi / 180
math.deg2rad = DEG2RAD
local RAD2DEG = 180 / math.pi
math.rad2deg = RAD2DEG

local function math_pow(x, y)
	return x ^ y
end

math.pow = math.pow or math_pow -- polyfill

local function math_isinf(n)
	return n == (1 / 0) or n == (-1 / 0)
end

math.isinf = math_isinf

local function math_isnan(n)
	return n ~= n
end

math.isnan = math_isnan

local function math_isfinite(n)
	--return not (n == (1 / 0) or n == (-1 / 0) or (n ~= n))
	return (n == n) and n ~= (1 / 0) and n ~= (-1 / 0)
end

math.isfinite = math_isfinite

local function math_absolute(n)
	--return math_abs(n)
	--return n < 0 and -n or n
	return n >= 0 and n or -n
end

math.absolute = math_absolute

local function math_difference(x, y)
	return math_absolute(x - y)
end

math.difference = math_difference

local function math_approx(a, b, epsilon)
	epsilon = epsilon or 1e-6
	return math_absolute(a - b) <= epsilon
end

math.approx = math_approx

local function math_clamp(n, min, max)
	return math_min(math_max(n, min), max)
end

math.clamp = math_clamp

local function math_clamp01(n)
	--return math_clamp(n, 0, 1)
	if n < 0 then return 0 end
	if n > 1 then return 1 end
	return n
end

math.clamp01 = math_clamp01

local function math_fractional(n)
	--return n % 1
	local _, f = math_modf(n)
	return f
end

math.fractional = math_fractional
math.frac = math_fractional

local function math_maximum(a, b)
	--return math_max(a, b)
	--return a <= b and b or a
	--return a >= b and a or b
	return a > b and a or b
end

math.maximum = math_maximum

local function math_minimum(a, b)
	--return math_min(a, b)
	--return a <= b and a or b
	return a < b and a or b
end

math.minimum = math_minimum

local function math_toint(n)
	--return n | 0
	return (math_modf(n))
end

math.toint = math_toint
math.tointeger = math.tointeger or math_toint

local function math_round(n, digits)
	if digits then
		local factor = 10 ^ digits               -- math_pow(10, digits)
		return math_floor((n * factor) + 0.5) / factor -- precision round
	end
	--return math_floor(n + 0.5) -- round
	return n >= 0 and math_floor(n + 0.5) or math_ceil(n - 0.5)
end

math.round = math_round

local function math_trunc(n)
	return n >= 0 and math_floor(n) or math_ceil(n) -- round towards zero
end

math.trunc = math_trunc

local function math_sincos(n) -- TODO/CONS: lookup table?
	return math_sin(n), math_cos(n)
end

math.sincos = math_sincos

local function math_sign(n)
	return n > 0 and 1 or n < 0 and -1 or 0
end

math.sign = math_sign

local function math_map(n, in_min, in_max, out_min, out_max)
	if in_max == in_min then return out_min end
	return out_min + (n - in_min) * (out_max - out_min) / (in_max - in_min)
end

math.map = math_map

local function math_remap(n, in_min, in_max, out_min, out_max)
	return out_min + (n - in_min) / (in_max - in_min) * (out_max - out_min)
end

math.remap = math_remap

local function math_progress(n, min, max)
	return (n - min) / (max - min)
end

math.progress = math_progress

local function math_percent(n, min, max)
	if max == min then return 0 end
	return math_clamp((n - min) / (max - min), 0, 1)
end

math.percent = math_percent
--math.fraction = math_percent

local function math_wrap(n, min, max)
	local range = max - min
	if range == 0 then return min end
	return min + ((n - min) % range + range) % range
end

math.wrap = math_wrap

local function math_gcd(a, b)
	return b == 0 and a or math_gcd(b, a % b)
end

math.gcd = math_gcd

local function math_floordiv(a, b)
	return math_floor(a / b)
end

math.floordiv = math_floordiv

local function math_intdiv(a, b)
	--return (a < 0 and math_ceil or math_floor)(a / b)
	return (a >= 0 and math_floor or math_ceil)(a / b)
end

math.intdiv = math_intdiv

local function math_truncate(n, idp)
	local func = n < 0 and math_ceil or math_floor
	if idp then
		local mult = 10 ^ idp -- math_pow(10, idp)
		return func(n * mult) / mult
	end
	return func(n)
end

math.truncate = math_truncate

local function math_scale(n, min, max)
	return n * (max - min) + min
end

math.scale = math_scale

local function math_rand(min, max)
	return math_random() * (max - min) + min
end

math.rand = math.rand or math_rand

local function math_inrange(n, min, max)
	return min <= n and n <= max
end

math.inrange = math_inrange

local function math_snapto(n, step)
	return math_floor((n / step) + 0.5) * step
end

math.snapto = math_snapto

local function math_approach(current, target, step)
	step = step < 0 and -step or step -- math_abs(step)
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

local function math_lerp(t, from, to)
	return from + (to - from) * t
end

math.lerp = math_lerp

local function math_lerp_clamp(t, from, to)
	t = math_clamp(t, 0, 1)
	return from + (to - from) * t
end

math.lerp_clamp = math_lerp_clamp

local function math_unlerp(t, from, to)
	if from == to then
		return 0
	end
	return (t - from) / (to - from)
end

math.unlerp = math_unlerp
math.inverse_lerp = math_unlerp -- alias

----------------------------------------------------------------------
-- Easing functions
----------------------------------------------------------------------

local function math_ease_in_quad(t)
	--return t ^ 2
	return t * t
end

math.ease_in_quad = math_ease_in_quad
math.sqr = math_ease_in_quad -- alias

local function math_ease_out_quad(t)
	return t * (2 - t)
end

math.ease_out_quad = math_ease_out_quad

local function math_ease_in_out_quad(t)
	return t < 0.5 and 2 * t * t or -1 + (4 - 2 * t) * t
end

math.ease_in_out_quad = math_ease_in_out_quad

local function math_ease_in_cubic(t)
	--return t ^ 3
	return t * t * t
end

math.ease_in_cubic = math_ease_in_cubic

local function math_ease_out_cubic(t)
	local t1 = t - 1
	return t1 * t1 * t1 + 1
end

math.ease_out_cubic = math_ease_out_cubic

local function math_ease_in_out_cubic(t)
	return t < 0.5 and 4 * t * t * t or (t - 1) * (2 * t - 2) * (2 * t - 2) + 1
end

math.ease_in_out_cubic = math_ease_in_out_cubic

local function math_smoothstep(t)
	return t * t * (3 - 2 * t)
end

math.smoothstep = math_smoothstep

local function math_smootherstep(t)
	return t * t * t * (t * (t * 6 - 15) + 10)
end

math.smootherstep = math_smootherstep

----------------------------------------------------------------------
-- Angle utilities
----------------------------------------------------------------------

local function math_deg_to_rad(deg)
	--return math_rad(deg)
	return deg * DEG2RAD
end

math.deg_to_rad = math_deg_to_rad
math.degtorad = math_deg_to_rad

local function math_rad_to_deg(rad)
	--return math_deg(rad)
	return rad * RAD2DEG
end

math.rad_to_deg = math_rad_to_deg
math.radtodeg = math_rad_to_deg

local function math_normalize_angle(angle)
	-- Normalize to -180 to 180
	angle = angle % 360
	if angle > 180 then
		angle = angle - 360
	elseif angle < -180 then
		angle = angle + 360
	end
	return angle
end

math.normalize_angle = math_normalize_angle

local function math_normalize_angle_360(angle)
	-- Normalize to 0 to 360
	angle = angle % 360
	if angle < 0 then
		angle = angle + 360
	end
	return angle
end

math.normalize_angle_360 = math_normalize_angle_360

local function math_lerp_angle(from, to, t)
	-- Linear interpolation for angles with wrapping
	local diff = to - from
	while diff > 180 do
		diff = diff - 360
	end
	while diff < -180 do
		diff = diff + 360
	end
	return from + diff * t
end

math.lerp_angle = math_lerp_angle

local function math_angle_diff(a, b)
	-- Get the shortest difference between two angles
	local diff = b - a
	while diff > 180 do
		diff = diff - 360
	end
	while diff < -180 do
		diff = diff + 360
	end
	return diff
end

math.angle_diff = math_angle_diff

----------------------------------------------------------------------
-- Distance calculations
----------------------------------------------------------------------

local function math_distance(x1, y1, x2, y2)
	local dx = x2 - x1
	local dy = y2 - y1
	return math_sqrt(dx * dx + dy * dy)
end

math.distance = math_distance
math.dist = math_distance

local function math_distance_squared(x1, y1, x2, y2)
	local dx = x2 - x1
	local dy = y2 - y1
	return dx * dx + dy * dy
end

math.distance_squared = math_distance_squared
math.dist_sq = math_distance_squared

local function math_distance_3d(x1, y1, z1, x2, y2, z2)
	local dx = x2 - x1
	local dy = y2 - y1
	local dz = z2 - z1
	return math_sqrt(dx * dx + dy * dy + dz * dz)
end

math.distance_3d = math_distance_3d

local function math_distance_3d_squared(x1, y1, z1, x2, y2, z2)
	local dx = x2 - x1
	local dy = y2 - y1
	local dz = z2 - z1
	return dx * dx + dy * dy + dz * dz
end

math.distance_3d_squared = math_distance_3d_squared

----------------------------------------------------------------------
-- Oscillation and wrapping
----------------------------------------------------------------------

local function math_pingpong(t, length)
	length = length or 1
	t = t % (length * 2)
	if t < 0 then
		t = t + length * 2
	end
	return t < length and t or length * 2 - t
end

math.pingpong = math_pingpong

local function math_bounce(t, min, max)
	local range = max - min
	return min + math_absolute(math_sin(t) * range)
end

math.bounce = math_bounce

----------------------------------------------------------------------
-- Statistical functions
----------------------------------------------------------------------

local function math_average(...)
	local args = { ... }
	local sum = 0
	for i = 1, #args do
		sum = sum + args[i]
	end
	return sum / #args
end

math.average = math_average
math.mean = math_average

local function math_sum(...)
	local args = { ... }
	local sum = 0
	for i = 1, #args do
		sum = sum + args[i]
	end
	return sum
end

math.sum = math_sum

local function math_range(min, max)
	return max - min
end

math.range = math_range

local function math_mid(a, b)
	return (a + b) * 0.5
end

math.mid = math_mid

----------------------------------------------------------------------
-- Safe math operations
----------------------------------------------------------------------

local function math_sqrt_safe(n)
	if n < 0 then
		return 0
	end
	return math_sqrt(n)
end

math.sqrt_safe = math_sqrt_safe

local function math_log_safe(n, base)
	base = base or 10
	if n <= 0 then
		return 0
	end
	return math_log(n, base)
end

math.log_safe = math_log_safe

----------------------------------------------------------------------
-- Power of two utilities
-- TODO: Move to Lua lib (bits)
----------------------------------------------------------------------

local function math_is_power_of_two(n)
	return n > 0 and (n & (n - 1)) == 0
end

math.is_power_of_two = math_is_power_of_two

local function math_next_power_of_two(n)
	n = n - 1
	n = n | (n >> 1)
	n = n | (n >> 2)
	n = n | (n >> 4)
	n = n | (n >> 8)
	n = n | (n >> 16)
	return n + 1
end

math.next_power_of_two = math_next_power_of_two

----------------------------------------------------------------------
-- Random utilities
----------------------------------------------------------------------

local function math_random_range_int(min, max)
	return math_floor(math_random() * (max - min + 1)) + min
end

math.random_range_int = math_random_range_int
math.rand_int = math_random_range_int

local function math_random_sign()
	return math_random() < 0.5 and -1 or 1
end

math.random_sign = math_random_sign

local function math_random_bool()
	return math_random() < 0.5
end

math.random_bool = math_random_bool

local function math_random_choice(...)
	local args = { ... }
	return args[math_random_range_int(1, #args)]
end

math.random_choice = math_random_choice

local function math_random_weighted(weights)
	local total = 0
	for i = 1, #weights do
		total = total + weights[i]
	end
	local r = math_random() * total
	local sum = 0
	for i = 1, #weights do
		sum = sum + weights[i]
		if r < sum then
			return i
		end
	end
	return #weights
end

math.random_weighted = math_random_weighted

----------------------------------------------------------------------
-- Movement and damping
----------------------------------------------------------------------

local function math_move_towards(current, target, max_delta)
	local delta = target - current
	if math_absolute(delta) <= max_delta then
		return target
	end
	return current + math_sign(delta) * max_delta
end

math.move_towards = math_move_towards

local function math_damp(current, target, smoothing, dt)
	smoothing = math_clamp(smoothing, 0, 1)
	return current + (target - current) * smoothing * dt
end

math.damp = math_damp

local function math_damp_angle(current, target, smoothing, dt)
	smoothing = math_clamp(smoothing, 0, 1)
	return current + math_angle_diff(current, target) * smoothing * dt
end

math.damp_angle = math_damp_angle

----------------------------------------------------------------------
-- Additional useful functions
----------------------------------------------------------------------

local function math_cube_root(n)
	if n >= 0 then
		return n ^ (1 / 3)
	end
	return -((-n) ^ (1 / 3))
end

math.cbrt = math_cube_root
math.cube_root = math_cube_root

local function math_repeat(t, length)
	return t - math_floor(t / length) * length
end

math.rep = math_repeat

-- Export (for compatibility)
return math
