-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Standalone utility/helper functions which doesn't belong anywhere else.

--local select = select
local type = type
local table_unpack = table.unpack or unpack

--- Applies a function to arguments and returns the first argument for chaining.
--- @param func function The function to execute.
--- @param a any The first argument (will be returned).
--- @param ... any Additional arguments to pass to the function.
--- @return any a The first argument `a` for method chaining.
local function chain(func, a, ...)
	func(a, ...)
	return a
end

local dual_call
do
	-- Type lookup tables for performance
	local DUAL_CALL_SELF_TYPES = {
		table = true,
		userdata = true,
	}

	--- Generic helper function for supporting both dot and colon invocation.
	--- Creates a function that can handle both obj.method(arg) and obj:method(arg) patterns.
	--- Detects calling convention by checking if first argument is a table/userdata (self) or regular parameter.
	--- @param func function The implementation function that takes (self, arg1, arg2, ...).
	--- @param self_obj table|userdata The object to use as 'self' for dot calls.
	--- @return function wrapper A function that supports both calling conventions.
	--- @usage <br>
	--- ```
	--- -- Implementation function that expects (self, item) as parameters
	--- local function add_item_impl(self, item)
	---   table.insert(self.items, item)
	---   print("Added", item, "to", self.name)
	--- end
	---
	--- local collection = {name = "MyList", items = {}}
	--- local item1 = "apple"
	--- local item2 = "banana"
	---
	--- -- Create dual-call method
	--- collection.add = dual_call(add_item_impl, collection)
	---
	--- -- Both calling conventions work:
	--- collection.add(item1) -- Dot call: "Added apple to MyList"
	--- collection:add(item2) -- Colon call: "Added banana to MyList"
	--- ```
	function dual_call(func, self_obj)
		return function(a, b, ...)
			if DUAL_CALL_SELF_TYPES[type(a)] then
				-- Called as obj:method(a, b, ...) - treat 'a' as self, 'b' as first argument
				return func(a, b, ...)
			end
			-- Called as obj.method(a, b, ...) - treat self_obj as self, 'a' as first argument
			return func(self_obj, a, b, ...)
		end
	end
end

--- Wrap a function in a simple wrapper that forwards all arguments.
--- Creates a wrapper function that calls the original function with all arguments unchanged.
--- @param func function The function to wrap.
--- @return function wrapper A wrapper function that forwards all arguments to the original function.
--- @usage <br>
--- ```
--- local func = forward_call(my_func)
--- func(a, b, c)  -- Calls my_func(a, b, c)
--- ```
local function forward_call(func)
	return function(...)
		return func(...)
	end
end

--- Creates a wrapper function that ignores the first argument and forwards the rest.
--- @param func function The function to forward calls to.
--- @return function wrapper A wrapper function that takes (_, ...) and calls func(...).
local function forward_call_static(func)
	return function(_, ...)
		return func(...)
	end
end

--- Generic helper function for forwarding calls with N skipped arguments.
--- Creates a wrapper function that ignores the first N arguments and forwards the rest.
--- @param func function The function to forward calls to.
--- @param skip_count integer Number of arguments to skip (default: 1).
--- @return function wrapper A wrapper function that takes (arg1, arg2, ..., argN, ...) and calls func(...).
--- @usage <br>
--- ```
--- local func = forward_call_skip(my_func, 2) -- Skip first 2 arguments
--- func(a, b, c, d) -- Calls my_func(c, d)
---
--- local func2 = forward_call_skip(my_func, 0) -- Don't skip any arguments
--- func2(a, b) -- Calls my_func(a, b)
--- ```
local function forward_call_skip(func, skip_count)
	skip_count = skip_count or 1
	return function(...)
		local args = { ... }
		local argc = #args -- select("#", ...)
		local result = {}
		for i = skip_count + 1, argc do
			result[#result + 1] = args[i]
		end
		return func(table_unpack(result))
	end
end

--- Generic type-based dispatch helper.
--- Creates a function that dispatches to type-specific handlers.
--- @param handlers table A table mapping type names to handler functions.
--- @param default_handler function|nil Optional default handler for unknown types.
--- @return function dispatcher The dispatch function that takes a value and returns the handler result.
local function create_type_dispatcher(handlers, default_handler)
	return function(value)
		local handler = handlers[type(value)]
		if handler then
			return handler(value)
		end
		if default_handler then
			return default_handler(value)
		end
	end
end

--- Safely dispatches to a handler function if it exists.
--- @param key any The key to look up the handler (typically a type or other identifier).
--- @param handlers table A table mapping keys to handler functions.
--- @param ... any Additional arguments to pass to the handler function.
--- @return any result The result of the handler function if found, otherwise nil.
local function safe_dispatch(key, handlers, ...)
	local handler = handlers[key]
	if handler then
		return handler(...)
	end
end

local tobool
do
	local math_modf, string_upper = math.modf, string.upper
	local TOBOOL_STRING_LOOKUP = {
		["1"] = true,
		["ON"] = true,
		["TRUE"] = true,
	}
	-- Type-based dispatch table for performance
	local TOBOOL_TYPE_HANDLERS = {
		boolean = function(value) return value end,
		number = function(value) return (math_modf(value)) ~= 0 end,
		string = function(value) return TOBOOL_STRING_LOOKUP[string_upper(value)] or false end,
	}

	-- Create the dispatcher with a default handler for unknown types
	local tobool_dispatcher = create_type_dispatcher(TOBOOL_TYPE_HANDLERS, function(value) return value ~= nil end)

	--- Converts a value to a boolean.
	--- @param value any The value to convert.
	--- @return boolean boolean The boolean representation.
	--- - If value is boolean, returns it as-is.
	--- - If value is number, returns true if not zero, false if zero.
	--- - Otherwise, returns true if not nil, false if nil.
	function tobool(value)
		return tobool_dispatcher(value)
	end
end

--- Wraps a value in a function that returns it.
--- Creates a closure that captures the value and returns it when called.
--- @param value any The value to wrap.
--- @return function function A function that returns the wrapped value.
local function wrap(value)
	local value = value               -- shadow
	return function() return value end -- upvalue
end

-- Export
return {
	--apply = chain, -- ~~alias for backward compatibility~~
	bool = tobool, -- alias
	chain = chain,
	create_type_dispatcher = create_type_dispatcher,
	dual_call = dual_call,
	forward_call = forward_call,
	forward_call_skip = forward_call_skip,
	forward_call_static = forward_call_static,
	safe_dispatch = safe_dispatch,
	tobool = tobool,
	wrap = wrap,
}
