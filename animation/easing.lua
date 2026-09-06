-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Localized global functions for better performance
local math_asin = math.asin
local math_cos = math.cos
local math_sin = math.sin
local math_sqrt = math.sqrt
local math_pi = math.pi

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------

--- Clamp a number to the [0, 1] range.
---@param t number Value to clamp.
---@return number clamped Clamped value in [0, 1].
local function clamp01(t)
	return t < 0 and 0 or (t > 1 and 1 or t)
end

----------------------------------------------------------------------
-- Easing Functions
----------------------------------------------------------------------

---@class animation.Easing Table of easing functions.
local easing = {}

----------------------------------------------------------------------
-- Quad
----------------------------------------------------------------------

--- Quadratic ease-in.
---@param t number Progress in [0, 1].
---@return number eased Eased value.
function easing.InQuad(t)
	t = clamp01(t)
	return t * t
end

--- Quadratic ease-out.
---@param t number Progress in [0, 1].
---@return number eased Eased value.
function easing.OutQuad(t)
	t = clamp01(t)
	return t * (2 - t)
end

--- Quadratic ease-in-out.
---@param t number Progress in [0, 1].
---@return number eased Eased value.
function easing.InOutQuad(t)
	t = clamp01(t)
	return t < 0.5 and 2 * t * t or -1 + (4 - 2 * t) * t
end

----------------------------------------------------------------------
-- Cubic
----------------------------------------------------------------------

--- Cubic ease-in.
---@param t number Progress in [0, 1].
---@return number eased Eased value.
function easing.InCubic(t)
	t = clamp01(t)
	return t * t * t
end

--- Cubic ease-out.
---@param t number Progress in [0, 1].
---@return number eased Eased value.
function easing.OutCubic(t)
	local t1 = clamp01(t) - 1
	return t1 * t1 * t1 + 1
end

--- Cubic ease-in-out.
---@param t number Progress in [0, 1].
---@return number eased Eased value.
function easing.InOutCubic(t)
	t = clamp01(t)
	return t < 0.5 and 4 * t * t * t or (t - 1) * (2 * t - 2) * (2 * t - 2) + 1
end

----------------------------------------------------------------------
-- Quart
----------------------------------------------------------------------

--- Quartic ease-in.
---@param t number Progress in [0, 1].
---@return number eased Eased value.
function easing.InQuart(t)
	t = clamp01(t)
	return t * t * t * t
end

--- Quartic ease-out.
---@param t number Progress in [0, 1].
---@return number eased Eased value.
function easing.OutQuart(t)
	local t1 = clamp01(t) - 1
	return 1 - t1 * t1 * t1 * t1
end

--- Quartic ease-in-out.
---@param t number Progress in [0, 1].
---@return number eased Eased value.
function easing.InOutQuart(t)
	t = clamp01(t)
	return t < 0.5 and 8 * t * t * t * t or 1 - 8 * (t - 1) * (t - 1) * (t - 1) * (t - 1)
end

----------------------------------------------------------------------
-- Quint
----------------------------------------------------------------------

--- Quintic ease-in.
---@param t number Progress in [0, 1].
---@return number eased Eased value.
function easing.InQuint(t)
	t = clamp01(t)
	return t * t * t * t * t
end

--- Quintic ease-out.
---@param t number Progress in [0, 1].
---@return number eased Eased value.
function easing.OutQuint(t)
	local t1 = clamp01(t) - 1
	return 1 + t1 * t1 * t1 * t1 * t1
end

--- Quintic ease-in-out.
---@param t number Progress in [0, 1].
---@return number eased Eased value.
function easing.InOutQuint(t)
	t = clamp01(t)
	return t < 0.5 and 16 * t * t * t * t * t or 1 + 16 * (t - 1) * (t - 1) * (t - 1) * (t - 1) * (t - 1)
end

----------------------------------------------------------------------
-- Sine
----------------------------------------------------------------------

--- Sine ease-in.
---@param t number Progress in [0, 1].
---@return number eased Eased value.
function easing.InSine(t)
	return 1 - math_cos(clamp01(t) * math_pi * 0.5)
end

--- Sine ease-out.
---@param t number Progress in [0, 1].
---@return number eased Eased value.
function easing.OutSine(t)
	return math_sin(clamp01(t) * math_pi * 0.5)
end

--- Sine ease-in-out.
---@param t number Progress in [0, 1].
---@return number eased Eased value.
function easing.InOutSine(t)
	return (1 - math_cos(clamp01(t) * math_pi)) * 0.5
end

----------------------------------------------------------------------
-- Expo
----------------------------------------------------------------------

--- Exponential ease-in.
---@param t number Progress in [0, 1].
---@return number eased Eased value.
function easing.InExpo(t)
	t = clamp01(t)
	return t == 0 and 0 or 2 ^ (10 * (t - 1))
end

--- Exponential ease-out.
---@param t number Progress in [0, 1].
---@return number eased Eased value.
function easing.OutExpo(t)
	t = clamp01(t)
	return t == 1 and 1 or 1 - 2 ^ (-10 * t)
end

--- Exponential ease-in-out.
---@param t number Progress in [0, 1].
---@return number eased Eased value.
function easing.InOutExpo(t)
	t = clamp01(t)
	if t == 0 then return 0 end
	if t == 1 then return 1 end
	if t < 0.5 then
		return 2 ^ (20 * t - 10) * 0.5
	end
	return 1 - 2 ^ (-20 * t + 10) * 0.5
end

----------------------------------------------------------------------
-- Circ
----------------------------------------------------------------------

--- Circular ease-in.
---@param t number Progress in [0, 1].
---@return number eased Eased value.
function easing.InCirc(t)
	t = clamp01(t)
	return 1 - math_sqrt(1 - t * t)
end

--- Circular ease-out.
---@param t number Progress in [0, 1].
---@return number eased Eased value.
function easing.OutCirc(t)
	t = clamp01(t)
	return math_sqrt(1 - (t - 1) * (t - 1))
end

--- Circular ease-in-out.
---@param t number Progress in [0, 1].
---@return number eased Eased value.
function easing.InOutCirc(t)
	t = clamp01(t)
	if t < 0.5 then
		return (1 - math_sqrt(1 - 4 * t * t)) * 0.5
	end
	return (math_sqrt(1 - 4 * (t - 1) * (t - 1)) + 1) * 0.5
end

----------------------------------------------------------------------
-- Back
----------------------------------------------------------------------

--- Back overshoot helper.
---@param t number Progress in [0, 1].
---@param c? number Overshoot amount (default: 1.70158).
---@return number result The overshoot value.
local function back_overshoot(t, c)
	c = c or 1.70158
	return t * t * ((c + 1) * t - c)
end

--- Back ease-in.
---@param t number Progress in [0, 1].
---@return number eased Eased value.
function easing.InBack(t)
	return back_overshoot(clamp01(t))
end

--- Back ease-out.
---@param t number Progress in [0, 1].
---@return number eased Eased value.
function easing.OutBack(t)
	local t1 = clamp01(t) - 1
	return 1 + t1 * t1 * ((1.70158 + 1) * t1 + 1.70158)
end

--- Back ease-in-out.
---@param t number Progress in [0, 1].
---@return number eased Eased value.
function easing.InOutBack(t)
	t = clamp01(t)
	local c = 1.70158 * 1.525
	if t < 0.5 then
		return back_overshoot(2 * t, c) * 0.5
	end
	return 1 + back_overshoot(2 * t - 2, c) * 0.5
end

----------------------------------------------------------------------
-- Elastic
----------------------------------------------------------------------

--- Elastic ease-in.
---@param t number Progress in [0, 1].
---@return number eased Eased value.
function easing.InElastic(t)
	t = clamp01(t)
	if t == 0 or t == 1 then return t end
	local a = 1
	local p = 0.3
	local s = p / (2 * math_pi) * math_asin(1 / a)
	return -(a * 2 ^ (-10 * t) * math_sin((t - s) * (2 * math_pi) / p))
end

--- Elastic ease-out.
---@param t number Progress in [0, 1].
---@return number eased Eased value.
function easing.OutElastic(t)
	t = clamp01(t)
	if t == 0 or t == 1 then return t end
	local a = 1
	local p = 0.3
	local s = p / (2 * math_pi) * math_asin(1 / a)
	return a * 2 ^ (-10 * t) * math_sin((t - s) * (2 * math_pi) / p) + 1
end

--- Elastic ease-in-out.
---@param t number Progress in [0, 1].
---@return number eased Eased value.
function easing.InOutElastic(t)
	t = clamp01(t)
	if t == 0 or t == 1 then return t end
	local a = 1
	local p = 0.3
	local s = p / (2 * math_pi) * math_asin(1 / a)
	if t < 0.5 then
		return -0.5 * (a * 2 ^ (-20 * t) * math_sin((2 * t - s) * (2 * math_pi) / p))
	end
	return 0.5 * (a * 2 ^ (-20 * t) * math_sin((2 * t - s) * (2 * math_pi) / p)) + 1
end

----------------------------------------------------------------------
-- Bounce
----------------------------------------------------------------------

--- Bounce helper function.
---@param t number Progress in [0, 1].
---@return number result The bounce value.
local function bounce(t)
	if t < 1 / 2.75 then
		return 7.5625 * t * t
	end
	if t < 2 / 2.75 then
		local t1 = t - 1.5 / 2.75
		return 7.5625 * t1 * t1 + 0.75
	end
	if t < 2.5 / 2.75 then
		local t1 = t - 2.25 / 2.75
		return 7.5625 * t1 * t1 + 0.9375
	end
	local t1 = t - 2.625 / 2.75
	return 7.5625 * t1 * t1 + 0.984375
end

--- Bounce ease-in.
---@param t number Progress in [0, 1].
---@return number eased Eased value.
function easing.InBounce(t)
	return 1 - bounce(1 - clamp01(t))
end

--- Bounce ease-out.
---@param t number Progress in [0, 1].
---@return number eased Eased value.
function easing.OutBounce(t)
	return bounce(clamp01(t))
end

--- Bounce ease-in-out.
---@param t number Progress in [0, 1].
---@return number eased Eased value.
function easing.InOutBounce(t)
	t = clamp01(t)
	if t < 0.5 then
		return (1 - bounce(1 - 2 * t)) * 0.5
	end
	return (1 + bounce(2 * t - 1)) * 0.5
end

-- Export
return easing
