-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Utilities for invoking multiple functions.
-- Provides a set of helpers for executing multiple callbacks or functions
-- sequentially, either in protected mode or with specific result handling.
--
-- Usage example:
-- ```
-- local invoke = require "invoke"
--
-- local fn1 = function() print("1") end
-- local fn2 = function() print("2") end
--
-- invoke.invoke(fn1, fn2) -- prints 1 then 2
--
-- local ok, err = invoke.invoke_gracefully(fn1, function() return error("oops") end)
-- -- ok is false, err is "oops"
-- ```

-- Localized global functions for better performance
local pcall = pcall
local select = select

--- Invokes each function passed as varargs.<br>
--- Functions are called sequentially with no arguments.
---@param ... function The functions to invoke.
---@usage <br>
--- ```
--- invoke.invoke(function() print("A") end, function() print("B") end)
--- ```
local invoke = function(...)
	for i = 1, select("#", ...) do
		local fn = select(i, ...)
		--if type(fn) == "function" then -- NOTE: could be a callable table or a userdata
		fn()
		--end
	end
end

--- Invokes each function in table `t` with the given arguments.<br>
--- Functions are called sequentially, each receiving `...` as arguments.
---@param t table Array of functions to invoke.
---@param ... any Arguments forwarded to each function.
---@usage <br>
--- ```
--- local fns = {function(v) print(v) end, function(v) print(v * 2) end}
--- invoke.invoke_args(fns, 10)
--- -- prints 10 then 20
--- ```
local invoke_args = function(t, ...)
	for i = 1, #t do
		local fn = t[i]
		--if type(fn) == "function" then -- NOTE: could be a callable table or a userdata
		fn(...)
		--end
	end
end

--- Invokes each function passed as varargs in protected mode.<br>
--- Stops at the first failure and returns the error.
---@param ... function The functions to invoke.
---@return boolean success True if every call succeeded.
---@return any err Error message from the failed call, if any.
---@usage <br>
--- ```
--- local ok, err = invoke.invoke_gracefully(fn1, fn2)
--- ```
local invoke_gracefully = function(...)
	local n = select("#", ...)
	if n == 0 then
		return true -- nothing to call; treat as success
	end
	for i = 1, n do
		local fn = select(i, ...)
		--if type(fn) ~= "function" then -- NOTE: could be a callable table or a userdata
		--	return false, string.format("argument #%d is not a function (got %s)", i, type(fn))
		--end
		local ok, err = pcall(fn)
		if not ok then
			return false, err
		end
	end
	return true
end

--- Invokes each function passed as varargs and returns the first non-nil result.<br>
--- Stops iterating once a result is found.
---@param ... function The functions to invoke.
---@return any result The first non-nil result returned by a function, or nil.
---@usage <br>
--- ```
--- local val = invoke.invoke_first_result(fn_that_might_return, fallback_fn)
--- ```
local invoke_first_result = function(...)
	for i = 1, select("#", ...) do
		local fn = select(i, ...)
		--if type(fn) ~= "function" then -- NOTE: could be a callable table or a userdata
		--	return false, string.format("argument #%d is not a function (got %s)", i, type(fn))
		--end
		local result = fn()
		if result ~= nil then
			return result
		end
	end
end

--- Invokes all functions passed as varargs in protected mode.<br>
--- Unlike `invoke_gracefully`, this calls every function regardless of failures.
---@param ... function The functions to invoke.
---@return boolean all_ok True if every single call succeeded.
---@return table results Array of results, where each entry is `{ success, result/err }`.
---@usage <br>
--- ```
--- local ok, results = invoke.invoke_all(fn1, fn2)
--- for i, res in ipairs(results) do
---   print("Call " .. i .. " success: " .. tostring(res[1]))
--- end
--- ```
local invoke_all = function(...)
	local all_ok, results = true, {}
	for i = 1, select("#", ...) do
		local fn = select(i, ...)
		--if type(fn) ~= "function" then -- NOTE: could be a callable table or a userdata
		--	return false, string.format("argument #%d is not a function (got %s)", i, type(fn))
		--end
		results[i] = { pcall(fn) }
		all_ok = all_ok and results[i][1]
	end
	return all_ok, results
end

-- Export
return {
	invoke = invoke,
	invoke_args = invoke_args,
	invoke_gracefully = invoke_gracefully,
	invoke_first_result = invoke_first_result,
	invoke_all = invoke_all,
}
