-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Standalone utility/helper functions which doesn't belong anywhere else

-- Import dependencies
local string = require "../standard/string"
local table = require "../standard/table"
local shallow_copy = table.shallow_copy

-- Localized global functions for better performance
local error = error
local getmetatable = getmetatable
local pcall = pcall
local select = select
local setmetatable = setmetatable
local type = type
local tonumber = tonumber
local tostring = tostring
local table_insert = table.insert
local table_pack = table.pack or function(...) return { n = select("#", ...), ... } end
local table_unpack = table.unpack or unpack

--- Return the first non-nil/false value, similar to C#'s ?? operator.<br>
--- Returns the first argument if it's truthy, otherwise returns the default value.<br>
--- This is useful when you can't use Lua's `or`; in Lua, a value is truthy if it is not `nil` nor `false`.
---@param v any The primary value to check.
---@param default any The default value to return if v is nil or false.
---@return any v if truthy, otherwise default.
---@usage <br>
--- ```
--- coalesce(nil, "default")     -- "default"
--- coalesce(false, "default")   -- "default"
--- coalesce("value", "default") -- "value"
--- coalesce(0, "default")       -- 0
--- coalesce("", "default")      -- ""
--- ```
local function coalesce(v, default)
	--if v == nil then return default end return v
	if v then return v end
	return default
end

--- Immediate-if (ternary) function, similar to C's ?: operator.<br>
--- Returns the second argument if the condition is truthy, otherwise returns the third argument.<br>
--- This is useful when you can't use Lua's (`and`/`or`) ternary trick; in Lua, only `false` and `nil` are falsy.
---@param v any The condition to evaluate (truthy/falsy).
---@param t any The value to return if condition is truthy.
---@param f any The value to return if condition is falsy.
---@return any t if v is truthy, otherwise f.
---@usage <br>
--- ```
--- iff(nil, "exists", "null") -- "null"
--- iff(false, "yes", "no")    -- "no"
--- iff(true, "yes", "no")     -- "yes"
--- iff(0, "yes", "no")        -- "yes"
--- iff("", "yes", "no")       -- "yes"
--- ```
local function iff(v, t, f)
	--return v and t or f
	if v then return t end
	return f
end

--- Applies a function to arguments and returns the first argument for chaining.
---@param func function The function to execute.
---@param a any The first argument (will be returned).
---@param ... any Additional arguments to pass to the function.
---@return any a The first argument `a` for method chaining.
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

	--- Generic helper function for supporting both dot and colon invocation.<br>
	--- Creates a function that can handle both obj.method(arg) and obj:method(arg) patterns.<br>
	--- Detects calling convention by checking if first argument is a table/userdata (self) or regular parameter.
	---@param func function The implementation function that takes (self, arg1, arg2, ...).
	---@param self_obj table|userdata The object to use as 'self' for dot calls.
	---@return function wrapper A function that supports both calling conventions.
	---@usage <br>
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

--- Wrap a function in a simple wrapper that forwards all arguments.<br>
--- Creates a wrapper function that calls the original function with all arguments unchanged.
---@param func function The function to wrap.
---@return function wrapper A wrapper function that forwards all arguments to the original function.
---@usage <br>
--- ```
--- local func = forward_call(my_func)
--- func(a, b, c) -- Calls my_func(a, b, c)
--- ```
local function forward_call(func)
	return function(...)
		return func(...)
	end
end

--- Creates a wrapper function that ignores the first argument and forwards the rest.
---@param func function The function to forward calls to.
---@return function wrapper A wrapper function that takes (_, ...) and calls func(...).
local function forward_call_static(func)
	return function(_, ...)
		return func(...)
	end
end

--- Generic helper function for forwarding calls with N skipped arguments.<br>
--- Creates a wrapper function that ignores the first N arguments and forwards the rest.
---@param func function The function to forward calls to.
---@param skip_count integer Number of arguments to skip (default: 1).
---@return function wrapper A wrapper function that takes (arg1, arg2, ..., argN, ...) and calls func(...).
---@usage <br>
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
		--local args = { ... }
		--local argc = select("#", ...) -- NOTE: using this to preserve trailing nils instead of #args
		local args = table_pack(...)
		local n = args.n - skip_count -- argc - skip_count
		local result = {}
		for i = 1, n do
			result[i] = args[skip_count + i]
		end
		return func(table_unpack(result, 1, n))
	end
end

--- Generic type-based dispatch helper.<br>
--- Creates a function that dispatches to type-specific handlers.
---@param handlers table A table mapping type names to handler functions.
---@param default_handler? function Optional default handler for unknown types.
---@return function dispatcher The dispatch function that takes a value and returns the handler result.
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

--- Safely calls a function if it exists.<br>
--- Checks if the provided value is a function before calling it with the given arguments.
---@param func function The function to call.
---@param ... any Arguments to pass to the function.
---@return any result The result of the function call if func is a function, otherwise nil.
local function safe_call(func, ...)
	if type(func) == "function" then
		return func(...)
	end
end

--- Safely calls a function if it exists, catching errors with pcall.<br>
--- Checks if the provided value is a function before calling it with the given arguments.<br>
--- Returns success flag and result/error, similar to pcall behavior.
---@param func function The function to call.
---@param ... any Arguments to pass to the function.
---@return boolean success True if the function was called successfully, false otherwise.
---@return any result The result of the function call if successful, or error message if not.
local function safe_pcall(func, ...)
	if type(func) == "function" then
		return pcall(func, ...)
	end
	return false, "not a function"
end

--- Safely dispatches to a handler function if it exists.
---@param key any The key to look up the handler (typically a type or other identifier).
---@param handlers table A table mapping keys to handler functions.
---@param ... any Additional arguments to pass to the handler function.
---@return any result The result of the handler function if found, otherwise nil.
local function safe_dispatch(key, handlers, ...)
	local handler = handlers[key]
	if handler then
		return handler(...)
	end
end

--- Makes a table callable by setting up a `__call` metatable with multiple handlers.<br>
--- Creates a dispatcher that tries each handler in order until one returns a non-nil value.<br>
--- If no handler returns a value, an error is raised.
---@param t table The table to make callable.
---@param ... function Variadic call handler functions. Each takes (self, ...) and should return a value if it handles the call, or nil to pass to the next handler.
---@return table t The same table with the `__call` metamethod installed.
---@usage <br>
--- ```
--- local obj = callable({},
---   function(self, x) if type(x) == "number" then return x * 2 end end,
---   function(self, x) if type(x) == "string" then return x:upper() end end
--- )
--- local num = obj(5)    -- Returns: 10 (number handler)
--- local str = obj("hi") -- Returns: "HI" (string handler)
--- ```
local function callable(t, ...)
	local mt = getmetatable(t)

	-- clone existing metatable if present
	mt = mt and shallow_copy(mt) or {}

	-- collect all call handlers
	local handlers = { ... }

	-- merge with existing __call if present
	if mt.__call then
		table_insert(handlers, 1, mt.__call)
	end

	-- unified dispatcher
	mt.__call = function(self, ...)
		for i = 1, #handlers do
			local func = handlers[i]
			local result = func(self, ...)
			if result ~= nil then
				return result
			end
		end
		return error("no __call handler accepted the arguments", 2)
	end

	return setmetatable(t, mt)
end

--- Makes a table callable with result caching - the first successful call result is cached forever.<br>
--- Wraps a function in a `__call` metatable that caches the result after the first successful call.<br>
--- If a previous `__call` exists on the table's metatable, it is tried first before calling func.
---@param t table The table to make callable.
---@param func function The fallback function to call if previous `__call` returns nil. Takes (self, ...) and should return value(s) to cache.
---@return table t The same table with the caching `__call` metamethod installed.
---@usage <br>
--- ```
--- local counter = 0
--- local obj = cached_callable({}, function(self) counter = counter + 1 return counter end)
--- print(obj()) -- Returns: 1, counter is now 1
--- print(obj()) -- Returns: 1 (cached, counter still 1)
--- print(obj()) -- Returns: 1 (cached, counter still 1)
--- ```
local function cached_callable(t, func)
	local mt = getmetatable(t)

	-- clone existing metatable if present
	mt = mt and shallow_copy(mt) or {}

	-- preserve existing __call if present
	local previous_call = mt.__call

	-- cache storage
	local cached, cached_values

	mt.__call = function(self, ...)
		-- fast path: return cached values
		if cached then
			return table_unpack(cached_values)
		end

		-- slow path: compute value
		local result

		if previous_call then
			result = { previous_call(self, ...) }
			if result[1] ~= nil then
				cached = true
				cached_values = result
				return table_unpack(result)
			end
		end

		result = { func(self, ...) }
		if result[1] ~= nil then
			cached = true
			cached_values = result
			return table_unpack(result)
		end

		--return nil
	end

	return setmetatable(t, mt)
end

local tobool
do
	local math_modf, string_upper = math.modf, string.upper
	local TOBOOL_STRING_LOOKUP = {
		["1"] = true,
		["ON"] = true,
		["TRUE"] = true,
		["YES"] = true,
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
	---@param value any The value to convert.
	---@return boolean boolean The boolean representation.
	--- - If value is boolean, returns it as-is.
	--- - If value is number, returns true if not zero, false if zero.
	--- - Otherwise, returns true if not nil, false if nil.
	function tobool(value)
		return tobool_dispatcher(value)
	end
end

--- Wraps a value in a function that returns it.<br>
--- Creates a closure that captures the value and returns it when called.
---@param value any The value to wrap.
---@return function function A function that returns the wrapped value.
local function wrap(value)
	local value = value               -- shadow
	return function() return value end -- upvalue
end

local get_path, set_path
do
	local string_split_path = string.split_path

	--- Get a value from a nested table using a dot-separated path or array of keys.<br>
	--- Traverses the table structure and returns the value at the specified path.<br>
	--- Returns nil if any intermediate path is not a table.
	---@param obj table The table to traverse.
	---@param path string|string[] Dot-separated path string (e.g. "config.database.host") or array of keys.
	---@return any value The value at the specified path, or nil if path doesn't exist.
	---@usage <br>
	--- ```
	--- local data = {config = {database = {host = "localhost"}}}
	--- local host = get_path(data, "config.database.host") -- Returns "localhost"
	--- local host2 = get_path(data, {"config", "database", "host"}) -- Also returns "localhost"
	--- ```
	function get_path(obj, path)
		local parts = type(path) == "table" and path or string_split_path(path)
		local cur = obj
		for i = 1, #parts do
			if type(cur) ~= "table" then return nil end
			cur = cur[parts[i]]
		end
		return cur
	end

	--- Set a value in a nested table using a dot-separated path or array of keys.<br>
	--- Creates intermediate tables as needed to ensure the full path exists.
	---@param obj table The table to modify.
	---@param path string|string[] Dot-separated path string (e.g. "config.database.host") or array of keys.
	---@param value any The value to set at the specified path.
	---@usage <br>
	--- ```
	--- local data = {}
	--- set_path(data, "config.database.host", "localhost")
	--- -- data is now {config = {database = {host = "localhost"}}}
	--- set_path(data, {"config", "port"}, 5432)
	--- -- data.port is now 5432
	--- ```
	function set_path(obj, path, value)
		local parts = type(path) == "table" and path or string_split_path(path)
		local cur = obj
		for i = 1, #parts - 1 do
			local p = parts[i]
			if type(cur[p]) ~= "table" then
				cur[p] = {}
			end
			cur = cur[p]
		end
		cur[parts[#parts]] = value
	end
end

--- Coerces a value to a number.<br>
--- Returns the value as-is if it's already a number, converts it using tonumber(), or returns 0 if conversion fails.
---@param v any The value to coerce.
---@return number? number The number representation, or nil if input is nil.
---@usage <br>
--- ```
--- coerce_number(42)    -- 42
--- coerce_number("123") -- 123
--- coerce_number("abc") -- 0
--- coerce_number(nil)   -- nil
--- ```
local function coerce_number(v)
	if v == nil then return end -- implicit nil
	if type(v) == "number" then return v end
	return tonumber(v) or 0
end

--- Coerces a value to a string.<br>
--- Returns the value as-is if it's already a string, converts it using `tostring`.
---@param v any The value to coerce.
---@return string? string The string representation, or nil if input is nil.
---@usage <br>
--- ```
--- coerce_string("hello") -- "hello"
--- coerce_string(42)      -- "42"
--- coerce_string(true)    -- "true"
--- coerce_string(nil)     -- nil
--- ```
local function coerce_string(v)
	if v == nil then return end -- implicit nil
	if type(v) == "string" then return v end
	return tostring(v)
end

--- Resolve a range (start_index, end_index) to absolute indices within a given length.<br>
--- Handles negative indices (count from end), zero, and clamps to valid range [1, len].
---@param len integer The total length.
---@param start_index? integer Starting index (default: 1). Negative indices count from end.
---@param end_index? integer Ending index (default: len). Negative indices count from end.
---@return integer start_index Resolved absolute start index (clamped to [1, len]).
---@return integer end_index Resolved absolute end index (clamped to [1, len]).
---@return boolean is_empty True if the resulting range is empty (start > end).
local function resolve_absolute_range(len, start_index, end_index)
	-- Default range is the entire string
	start_index = tonumber(start_index) or 1
	end_index = tonumber(end_index) or len

	-- Handle negative indices (count from end)
	if start_index < 0 then
		start_index = len + start_index + 1
	elseif start_index == 0 then
		start_index = 1
	end

	if end_index < 0 then
		end_index = len + end_index + 1
	elseif end_index == 0 then
		end_index = 1
	end

	-- Clamp indices to valid range
	if start_index < 1 then start_index = 1 end
	if end_index > len then end_index = len end

	return start_index, end_index, start_index > end_index
end

local range
do
	local math_floor, math_ceil, math_max = math.floor, math.ceil, math.max

	-- Shared metatable for all range objects
	local range_mt = {
		-- Count of values; the single formula handles both positive and negative
		-- steps, clamped at 0 for empty ranges.
		__len = function(self)
			return math_max(0, math_ceil((self.stop - self.start) / self.step))
		end,
		-- 1-based index access: r[1] is start, r[#r] is the last value.
		__index = function(self, key)
			if type(key) == "number" and key >= 1 and key <= #self then
				return self.start + (key - 1) * self.step
			end
		end,
		-- Make the object itself act as the iterator function.
		-- Lua's generic for calls f(state, control); control holds the previous
		-- value (nil on the first call).
		__call = function(self, _, current)
			if current == nil then
				current = self.start
			else
				current = current + self.step
			end

			-- Check bounds based on step direction
			if self.step > 0 then
				if current < self.stop then
					return current
				end
			elseif current > self.stop then
				return current
			end
			-- Implicit nil return stops iteration
		end,
	}

	--- Implements a Python-compatible range() as an iterable object.<br>
	--- Works directly with Lua's generic for loop, and also supports `#r`,
	--- 1-based indexing `r[i]`, and the `contains`, `to_table`, and `reverse`
	--- methods.<br>
	--- Supports positive and negative steps; a step of zero raises an error.
	---@param start_or_stop number If only arg, this is stop. If 2+ args, this is start.
	---@param stop_or_step? number If 2 args, this is stop. If 3 args, this is step.
	---@param step? number The increment/decrement value (default: 1).
	---@return table range_obj Iterable range object with fields `start`, `stop`, `step`.
	---@usage <br>
	--- ```
	--- for i in range(4) do print(i) end          -- 0 1 2 3
	--- for i in range(1, 5) do print(i) end       -- 1 2 3 4
	--- for i in range(0, -10, -3) do print(i) end -- 0 -3 -6 -9
	--- local r = range(5)
	--- print(#r)             -- 5
	--- print(r[3])           -- 2
	--- print(r:contains(2))  -- true
	--- table.concat(r:to_table()) -- "01234"
	--- for i in r:reverse() do print(i) end -- 4 3 2 1 0
	--- ```
	function range(start_or_stop, stop_or_step, step)
		local start, stop, s

		-- Parse arguments to match Python's range() signature
		if stop_or_step == nil then
			-- range(stop)
			start, stop, s = 0, start_or_stop, 1
		elseif step == nil then
			-- range(start, stop)
			start, stop, s = start_or_stop, stop_or_step, 1
		else
			-- range(start, stop, step)
			start, stop, s = start_or_stop, stop_or_step, step
		end

		-- Validate step (Python raises ValueError for step == 0)
		if s == 0 then
			return error("range() step argument must not be zero", 2)
		end

		-- Ensure all values are integers (truncate toward zero like Python)
		start = math_floor(start)
		stop  = math_floor(stop)
		s     = (s > 0) and math_floor(s) or math_ceil(s)

		-- Methods live on the object itself so __index only resolves plain
		-- numeric indexes; the object returns itself as its own iterator.
		return setmetatable({
			start = start,
			stop = stop,
			step = s,
			--- Get a stateless iterator usable in a generic for loop.
			---@return function iterator, any state, any control Iterable triple.
			iter = function(self)
				return self, nil, nil
			end,
			--- Test membership in O(1) via arithmetic.<br>
			--- Returns true if value is in the range without iterating.
			---@param value any The value to test.
			---@return boolean in_range True if value is a number contained in the range.
			contains = function(self, value)
				if type(value) ~= "number" then return false end
				if self.step > 0 then
					return value >= self.start and value < self.stop
							and (value - self.start) % self.step == 0
				else
					return value <= self.start and value > self.stop
							and (self.start - value) % (-self.step) == 0
				end
			end,
			--- Materialize the range into a Lua array table.
			---@return number[] values Array containing every value in the range.
			to_table = function(self)
				local t = {}
				for v in self:iter() do
					t[#t + 1] = v
				end
				return t
			end,
			--- Return a new range with reversed order (no allocation).
			---@return table reversed Reversed range object.
			reverse = function(self)
				local len = #self
				if len == 0 then return range(0) end
				local new_start = self.start + (len - 1) * self.step
				return range(new_start, self.start - self.step, -self.step)
			end,
		}, range_mt)
	end
end

-- Export
return {
	--apply = chain, -- ~~alias for backward compatibility~~
	bool = tobool, -- alias
	cached_callable = cached_callable,
	callable = callable,
	chain = chain,
	coalesce = coalesce,
	coerce_number = coerce_number,
	coerce_string = coerce_string,
	create_type_dispatcher = create_type_dispatcher,
	dual_call = dual_call,
	either = iff, -- alias
	forward_call = forward_call,
	forward_call_skip = forward_call_skip,
	forward_call_static = forward_call_static,
	get_path = get_path,
	iif = iff,
	range = range,
	resolve_absolute_range = resolve_absolute_range,
	safe_call = safe_call,
	safe_dispatch = safe_dispatch,
	safe_pcall = safe_pcall,
	set_path = set_path,
	tobool = tobool,
	wrap = wrap,
}
