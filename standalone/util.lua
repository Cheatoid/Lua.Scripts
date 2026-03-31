-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Standalone utility/helper functions which doesn't belong anywhere else.

local type = type

--- Applies a function to arguments and returns the first argument.
--- @param func function The function to apply.
--- @param a any The first argument (will be returned).
--- @param ... any Additional arguments to pass to the function.
--- @return any a The first argument `a`.
local function apply(func, a, ...)
	func(a, ...)
	return a
end

--- Generic helper function for forwarding calls.
--- Creates a wrapper function that ignores the first argument and forwards the rest.
--- @param func function The function to forward calls to.
--- @return function wrapper A wrapper function that takes (_, ...) and calls func(...).
local function forward_call(func)
	return function(_, ...)
		return func(...)
	end
end

--- Converts a value to a boolean.
--- @param value any The value to convert.
--- @return boolean boolean The boolean representation.
--- - If value is boolean, returns it as-is.
--- - If value is number, returns true if not zero, false if zero.
--- - Otherwise, returns true if not nil, false if nil.
local function tobool(value)
	if type(value) == "boolean" then return value end
	if type(value) == "number" then return value ~= 0 end
	--return not not value
	return value ~= nil
end

--- Wraps a value in a function that returns it.
--- Creates a closure that captures the value and returns it when called.
--- @param value any The value to wrap.
--- @return function function A function that returns the wrapped value.
local function wrap(value)
	local v = value -- upvalue
	return function() return v end
end

-- Export
return {
	apply = apply,
	forward_call = forward_call,
	tobool = tobool,
	wrap = wrap,
}
