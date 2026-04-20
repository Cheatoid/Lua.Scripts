-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

--[[
Generic left-fold utility for vararg operations.

Provides a fold function that applies a binary function cumulatively
to the elements of a vararg, from left to right.

Usage:
	local fold = require "standalone/fold"

	local sum = fold(function(a, b) return a + b end, 1, 2, 3, 4) -- 10
	local product = fold(function(a, b) return a * b end, 2, 3, 4) -- 24
]]

-- Localized select function for performance
local select = select

local HASH = "#"

--- Left-fold a vararg with a binary function.
--- Applies func cumulatively to the elements of ... from left to right.
---@param func function Binary function to apply (takes accumulator and next value).
---@param a any Initial value (first operand).
---@param ... any Additional operands.
---@return any result Folded result.
local function fold(func, a, ...)
	local n = select(HASH, ...)
	if n == 0 then return a end
	for i = 1, n do
		a = func(a, select(i, ...))
	end
	return a
end

-- Export
return fold
