-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- The greatest type-check library ever made 😎

-- Localized global functions for better performance
local next, type, string_format, string_gmatch =
	next, type, string.format, string.gmatch

-- Debug library functions may not be available in all environments
local debug_getinfo = debug and debug.getinfo
local debug_getlocal = debug and debug.getlocal

-- Import istype (currently unused)
--local istype = require "istype"
-- Import DebugHelper for parameter inspection functions
local get_param_name = require("debug_helper").get_param_name
-- Import forward-call
local forward_call = require("util").forward_call

--- Helper for strict type checking.
---@param val any The value to check.
---@param expected_type string|table The expected Lua type (e.g. "string") or a list of types (e.g. {"string", "number"} or "string|number").
---@param arg_index? integer The argument positional index (1, 2, 3...).
---@param optional? boolean If true, the argument is optional (default: false).
---@param func_level? integer Stack level of the function whose args we describe (default: 1).
---@param error_level? integer Stack level for error reporting (default: 2).
local function type_check(val, expected_type, arg_index, optional, func_level, error_level)
	--assert(type(expected_type) == "string" or (type(expected_type) == "table" and type(next(expected_type)) == "string"))
	--assert(arg_index == nil or type(arg_index) == "number")
	--assert(optional == nil or type(optional) == "boolean")
	--assert(func_level == nil or type(func_level) == "number")
	--assert(error_level == nil or type(error_level) == "number")

	-- If optional is true and value is nil, pass immediately
	if optional and val == nil then
		return
	end

	-- Set default stack level for inspecting arguments.
	func_level = (func_level or 1) + 1

	-- We add 1 to the base level (usually 2) to account for this helper function,
	-- ensuring the error points to the calling library function, not this helper.
	error_level = (error_level or 2) + 1

	-- Normalize expected_type into a list of allowed types
	local allowed_types = {}
	if type(expected_type) == "table" then
		allowed_types = expected_type
	else
		-- Assume string. Check for union syntax "string|number"
		for t in string_gmatch(expected_type, "([^|]+)") do
			allowed_types[#allowed_types + 1] = t
		end
	end

	-- Perform type checking (return early)
	local actual_type = type(val)
	for idx, t in next, allowed_types do
		if actual_type == t or t == "any" or (t == "nil" and val == nil) or (t == "integer" and actual_type == "number") then
			return t, idx
		end
	end

	-- Type mismatch; handle error
	local type_str = ""
	local count = #allowed_types

	for i, t in next, allowed_types do
		if i > 1 then
			type_str = (i == count) and (type_str .. " or ") or (type_str .. ", ")
		end
		type_str = type_str .. t
	end

	local funcName
	if debug_getinfo then
		local funcInfo = debug_getinfo(func_level, "n")
		funcName = (funcInfo and funcInfo.name) or "?"
	else
		funcName = "?"
	end
	local prefix = optional and "optional " or ""
	return error(
		string_format(
			"bad argument #%d%s to '%s' (expected %s%s, got %s)",
			arg_index or "?",
			arg_index and " (" .. (get_param_name(func_level + 1, arg_index) or "?") .. ")" or "",
			funcName,
			prefix,
			type_str,
			actual_type
		),
		error_level
	)
end

--- Performs strict type checking on a function argument by automatically retrieving its value from the caller's stack frame.<br>
--- This is a convenience wrapper around `type_check` that:
--- - Fetches the argument value using `debug.getlocal`
--- - Ensures the argument index is within the function's declared parameters
--- - Forwards all type-checking rules to `type_check`
---
---@param arg_index integer The 1-based positional index of the argument to validate.
---@param expected_type string|table The expected Lua type, or a list/union of types.
---@param optional? boolean If true, `nil` is accepted as a valid value (default: false).
---@param func_level? integer The stack level of the function whose parameters should be inspected (default: 2).
---@param error_level? integer Stack level used for error attribution. Defaults to 2, and is internally incremented by 1 so that errors point to the calling function, not this helper.
local function type_check_arg(arg_index, expected_type, optional, func_level, error_level)
	-- The caller function is at level 2
	func_level = func_level or 2

	-- Default stack level for error reporting
	error_level = error_level or 2

	-- Check if debug library is available
	if not debug_getinfo or not debug_getlocal then
		if optional then
			return
		end

		return error(
			string_format(
				"bad argument #%d to '%s' (debug library not available for automatic argument checking)",
				arg_index or "?",
				"?",
				arg_index
			),
			error_level
		)
	end

	-- Get info about the caller (your function)
	local info = debug_getinfo(func_level, "u")
	local nparams = info and info.nparams or 0

	-- Prevent reading locals beyond declared parameters
	if arg_index < 1 or arg_index > nparams then
		if optional then
			return
		end

		local funcInfo = debug_getinfo(func_level, "n")
		local funcName = funcInfo and funcInfo.name or "?"
		return error(
			string_format(
				"bad argument #%d to '%s' (no such parameter index %d)",
				1,
				funcName,
				arg_index
			),
			error_level
		)
	end

	-- Fetch the argument value (discard the name)
	local _, val = debug_getlocal(func_level, arg_index)

	-- Delegate to type_check
	return type_check(val, expected_type, arg_index, optional, func_level, error_level)
end

-- Quick test
--if true then
--	local function example(a, b, c)
--		type_check(a, "number|boolean", 1)
--		type_check_arg(1, "number|boolean")
--		type_check(b, "string|nil", 2)
--		type_check_arg(2, "string|nil")
--		type_check(c, "table", 3)
--		type_check_arg(3, "table")
--		print(a, b, c)
--	end
--	example(12.34, "foo", { "bar" })
--	example(false, nil, { "bar" })
--	example()
--end

-- Export the API to be accessed by other packages
return setmetatable(
	{
		check = type_check,
		check_arg = type_check_arg,
		opt = function(val, expected_type, arg_index, func_level, error_level)
			return type_check(val, expected_type, arg_index, true, func_level, error_level)
		end,

		check_string = function(arg_index, func_level, error_level)
			return type_check_arg(arg_index, "string", false, func_level, error_level)
		end,
		check_number = function(arg_index, func_level, error_level)
			return type_check_arg(arg_index, "number", false, func_level, error_level)
		end,
		check_integer = function(arg_index, func_level, error_level)
			return type_check_arg(arg_index, "integer", false, func_level, error_level)
		end,
		check_boolean = function(arg_index, func_level, error_level)
			return type_check_arg(arg_index, "boolean", false, func_level, error_level)
		end,
		check_table = function(arg_index, func_level, error_level)
			return type_check_arg(arg_index, "table", false, func_level, error_level)
		end,
		check_function = function(arg_index, func_level, error_level)
			return type_check_arg(arg_index, "function", false, func_level, error_level)
		end,
		check_thread = function(arg_index, func_level, error_level)
			return type_check_arg(arg_index, "thread", false, func_level, error_level)
		end,
		check_userdata = function(arg_index, func_level, error_level)
			return type_check_arg(arg_index, "userdata", false, func_level, error_level)
		end,

		opt_string = function(arg_index, func_level, error_level)
			return type_check_arg(arg_index, "string", true, func_level, error_level)
		end,
		opt_number = function(arg_index, func_level, error_level)
			return type_check_arg(arg_index, "number", true, func_level, error_level)
		end,
		opt_integer = function(arg_index, func_level, error_level)
			return type_check_arg(arg_index, "integer", true, func_level, error_level)
		end,
		opt_boolean = function(arg_index, func_level, error_level)
			return type_check_arg(arg_index, "boolean", true, func_level, error_level)
		end,
		opt_table = function(arg_index, func_level, error_level)
			return type_check_arg(arg_index, "table", true, func_level, error_level)
		end,
		opt_function = function(arg_index, func_level, error_level)
			return type_check_arg(arg_index, "function", true, func_level, error_level)
		end,
		opt_thread = function(arg_index, func_level, error_level)
			return type_check_arg(arg_index, "thread", true, func_level, error_level)
		end,
		opt_userdata = function(arg_index, func_level, error_level)
			return type_check_arg(arg_index, "userdata", true, func_level, error_level)
		end,
	}, {
		__call = forward_call(type_check)
	})
