-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Interpolation functions
---@class animation.Interpolation Table of interpolation functions.
local interpolation = {}

--- Linear interpolation (unclamped).
---@param a number Start value.
---@param b number End value.
---@param t number Interpolation factor.
---@return number result Interpolated value.
---@usage <br>
--- ```
--- local value = interpolation.LerpUnclamped(0, 100, 0.5) -- 50
--- ```
function interpolation.LerpUnclamped(a, b, t)
	return a + (b - a) * t
end

interpolation.Lerp = interpolation.LerpUnclamped -- alias

-- Export
return interpolation
