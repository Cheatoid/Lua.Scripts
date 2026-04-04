-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Localized global functions for better performance
local select = select
-- Compatibility fallback for table.unpack/unpack
local table_unpack = table.unpack or unpack

local HASH = "#"

--- Curries a binary function into a partially applicable function.
--- @generic R
--- @param func fun(...: any): R The function to curry.
--- @param arity integer|nil The number of arguments required (default: 2).
--- @return fun(...: any): R|fun(...: any): fun(...: any): R # A curried version of the input function.
--- @usage <br>
--- ```
--- local add = function(a, b) return a + b end
--- local curriedAdd = curry(add, 2)
--- local add5 = curriedAdd(5) -- returns a function
--- local result = add5(3) -- returns 8
--- ```
local function curry(func, arity)
	arity = arity or 2
	if arity == 1 then
		return func -- No point currying single-argument functions
	end
	return function(...)
		local argc = select(HASH, ...)
		if argc >= arity then
			return func(...)
		end
		local args = { ... }
		return function(...)
			return curry(func, arity)(table_unpack(args, 1, argc), ...)
		end
	end
end

-- Export
return curry
