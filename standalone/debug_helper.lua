-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Lua debugger and utilities for inspecting:
-- * parameters
-- * varargs
-- * locals (with kind classification)
-- * upvalues
-- * stack frames
local M = {}

local debug = assert(_G.debug, "debug library is missing")

-- Localized global functions for better performance
local next, debug_getinfo, debug_getlocal, debug_getupvalue, debug_setupvalue, debug_sethook, string_gsub, string_match, _setfenv, _getfenv =
	next, debug.getinfo, debug.getlocal, debug.getupvalue, debug.setupvalue, debug.sethook, string.gsub, string.match,
	setfenv, getfenv
local table_insert, table_sort = table.insert, table.sort

local VARARG_TEMP = "(*vararg)"
local LOCAL_PARAM, LOCAL_VARARG, LOCAL_LOCAL = "param", "vararg", "local"
local GETINFO_ALL, GETINFO_PARAMS, GETINFO_NAME = "nSltufrL", "u", "n"
local EVENT_CALL, EVENT_LINE, EVENT_RETURN = "call", "line", "return"
local HOOK_MASK_DEFAULT = "clr"
local BREAKPOINT_REASON = "breakpoint"
local ENV_UPVALUE_NAME = "_ENV"

--- Get the current stack depth by counting all available stack frames.<br>
--- Useful for determining how deep the call stack is at a given point.<br>
--- Counts from the current function (level 0) to the bottom of the stack.
---@return integer depth The total number of stack frames in the call stack.
---@usage <br>
--- ```
--- local depth = debug_helper.get_stack_depth()
--- print("Call stack depth:", depth)
--- ```
local function get_stack_depth()
	local i = 0
	while debug_getinfo(i) do
		i = i + 1
	end
	return i
end

M.get_stack_depth = get_stack_depth

--- Get the function object at a given stack level.<br>
--- Returns the actual Lua function object for the specified stack frame.<br>
--- Can accept either a function or a stack level integer.
---@param func_level function|integer The function -or- stack frame level to inspect (1 = current function, 2 = caller, etc.).
---@return function|nil func The function object at the specified level, or nil if not found.
---@usage <br>
--- ```
--- local func = debug_helper.get_function(2)
--- if func then print(func) end
--- ```
local function get_function(func_level)
	local info = debug_getinfo(func_level, "f")
	if info then
		return info.func
	end
end

M.get_function = get_function

--- Get the prefix of the source path up to the first slash.<br>
--- Extracts the directory/module name from the source path of a function.<br>
--- Useful for determining which module a function belongs to.
---@param func_level function|integer The function -or- stack frame level to inspect.
---@return string|nil prefix The extracted prefix (e.g., "@cheatoid" from "@cheatoid/module.lua"), or nil if unavailable.
---@usage <br>
--- ```
--- local prefix = debug_helper.get_source_prefix(2)
--- if prefix then print("Module:", prefix) end
--- ```
local function get_source_prefix(func_level)
	local info = debug_getinfo(func_level, "S")
	if info then
		return (string_match(string_gsub(info.source, "^[@=]", ""), "^([^/]+)"))
	end
end

M.get_source_prefix = get_source_prefix

--- Get all locals at a given stack level, with classification.<br>
--- Returns an array of local variables with their names, values, and kind classification.<br>
--- Each entry: `{ name = string, value = any, kind = "param" | "vararg" | "local" }`<br>
--- Kind classification helps distinguish between function parameters, varargs, and regular local variables.
---@param level integer The stack frame level to inspect (1 = current function, 2 = caller, etc.).
---@return table|nil array Array of local entries with name, value, and kind fields, or nil if level is invalid.
---@usage <br>
--- ```
--- local locals = debug_helper.get_locals(2)
--- for i, entry in next, locals do
---   print(entry.name, "=", entry.value, "(" .. entry.kind .. ")")
--- end
--- ```
local function get_locals(level)
	local info = debug_getinfo(level, GETINFO_PARAMS)
	if not info then
		return
	end

	local locals = {}
	local param_count = info.nparams
	local is_vararg = info.isvararg

	local i = 1
	while true do
		local name, value = debug_getlocal(level, i)
		if not name then
			break
		end

		local kind
		if i <= param_count then
			kind = LOCAL_PARAM
		elseif is_vararg and name == VARARG_TEMP then
			kind = LOCAL_VARARG
		else
			kind = LOCAL_LOCAL
		end

		locals[i] = {
			name = name,
			value = value,
			kind = kind,
		}

		i = i + 1
	end

	return locals
end

M.get_locals = get_locals

--- Get locals grouped by kind.<br>
--- Returns a table with three arrays: params, varargs, and locals.<br>
--- Each entry has the same shape as in get_locals(): `{ name, value, kind }`.<br>
--- Useful for processing different types of locals separately.
---@param level integer The stack frame level to inspect (1 = current function, 2 = caller, etc.).
---@return table|nil table Table with params, varargs, and locals arrays, or nil if level is invalid.
---@usage <br>
--- ```
--- local grouped = debug_helper.get_locals_by_kind(2)
--- for i, param in next, grouped.params do
---   print("Param:", param.name, "=", param.value)
--- end
--- ```
local function get_locals_by_kind(level)
	local all = get_locals(level)
	if not all then
		return
	end

	local out = {
		params = {},
		varargs = {},
		locals = {},
	}

	local params = out.params
	local varargs = out.varargs
	local locals = out.locals

	for _, entry in next, all do
		local kind = entry.kind
		if kind == LOCAL_PARAM then
			params[#params + 1] = entry
		elseif kind == LOCAL_VARARG then
			varargs[#varargs + 1] = entry
		else
			locals[#locals + 1] = entry
		end
	end

	return out
end

M.get_locals_by_kind = get_locals_by_kind

--- Get only declared parameters at a given stack level.<br>
--- Returns an array of function parameters with their names and values.<br>
--- Each entry: `{ name = string, value = any }`.<br>
--- Only includes explicitly declared parameters, not varargs or local variables.
---@param level integer The stack frame level to inspect (1 = current function, 2 = caller, etc.).
---@return table|nil array Array of { name, value } entries, or nil if level is invalid.
---@usage <br>
--- ```
--- local params = debug_helper.get_parameters(2)
--- for i, param in next, params do
---   print(i, param.name, "=", param.value)
--- end
--- ```
local function get_parameters(level)
	local info = debug_getinfo(level, GETINFO_PARAMS)
	if not info then
		return
	end

	local params = {}
	for i = 1, info.nparams do
		local name, value = debug_getlocal(level, i)
		params[i] = { name = name, value = value }
	end

	return params
end

M.get_parameters = get_parameters

--- Check if the function at a given level is vararg.<br>
--- Returns true if the function accepts variable arguments (has ... in its signature).<br>
--- Can accept either a function or a stack level integer.
---@param level function|integer The function -or- stack frame level to inspect.
---@return boolean boolean Whether the function is variadic.
---@usage <br>
--- ```
--- if debug_helper.is_vararg(2) then
---   print("Caller function is variadic")
--- end
--- ```
local function is_vararg(level)
	local info = debug_getinfo(level, GETINFO_PARAMS)
	if info then
		return info.isvararg
	end

	return false
end

M.is_vararg = is_vararg

--- Extract ONLY true varargs from a given stack level.<br>
--- Lua marks varargs with the name "(*vararg)" internally.<br>
--- Returns an array of vararg values and the total count.<br>
--- Only returns varargs, not function parameters or local variables.
---@param level integer The stack frame level to inspect (1 = current function, 2 = caller, etc.).
---@return table|nil array Array of vararg values, or nil if not variadic or level is invalid.
---@return integer|nil integer Total amount of vararg values, or nil if not variadic or level is invalid.
---@usage <br>
--- ```
--- local varargs, count = debug_helper.get_varargs(2)
--- if varargs then
---   print("Vararg count:", count)
---   for i, v in next, varargs do print(i, v) end
--- end
--- ```
local function get_varargs(level)
	local info = debug_getinfo(level, GETINFO_PARAMS)
	if not info or not info.isvararg then
		return
	end

	local varargs = {}

	local index = info.nparams + 1
	local i = 0

	while true do
		local name, value = debug_getlocal(level, index)
		if not name then
			break
		end

		if name == VARARG_TEMP then
			i = i + 1
			varargs[i] = value
		else
			break
		end

		index = index + 1
	end

	return varargs, i
end

M.get_varargs = get_varargs

--- Count varargs at a given level.<br>
--- Returns the number of variable arguments passed to the function.<br>
--- Convenience function that returns only the count, not the values themselves.
---@param level integer The stack frame level to inspect (1 = current function, 2 = caller, etc.).
---@return integer integer Amount of varargs passed to the function.
---@usage <br>
--- ```
--- local count = debug_helper.count_varargs(2)
--- print("Function received", count, "varargs")
--- ```
local function count_varargs(level)
	return #get_varargs(level)
end

M.count_varargs = count_varargs

--- Gets a list of parameter names for the function at the given stack level.<br>
--- Returns only the names, not the values.<br>
--- Iterates strictly from 1 to nparams to avoid reading internal locals.
---@param level integer The stack frame level to inspect (1 = current function, 2 = caller, etc.).
---@return table|nil array A list of strings representing the parameter names, or nil if out of bounds.
---@usage <br>
--- ```
--- local param_names = debug_helper.get_param_names(2)
--- for i, name in next, param_names do
---   print("Param", i, ":", name)
--- end
--- ```
local function get_param_names(level)
	-- Get info about the function at this level.
	-- "u" includes: 'nparams' (number of parameters) and 'isvararg'
	local info = debug_getinfo(level, GETINFO_PARAMS)
	if not info then
		return -- Invalid level, or not found
	end

	local params = {}

	-- Iterate strictly from 1 to nparams.
	-- This prevents reading internal locals defined in the function body.
	for i = 1, info.nparams do
		params[i] = (debug_getlocal(level, i))
	end

	return params
end

M.get_param_names = get_param_names

--- Get the name of a parameter by index.<br>
--- Returns the name of the parameter at the specified index (1-based).<br>
--- Returns nil if the index is out of bounds.
---@param level integer The stack frame level to inspect (1 = current function, 2 = caller, etc.).
---@param index integer The argument index (1-based).
---@return string|nil name Parameter name, or nil if not found.
---@usage <br>
--- ```
--- local name = debug_helper.get_param_name(2, 1)
--- if name then print("First param name:", name) end
--- ```
local function get_param_name(level, index)
	--local info = debug_getinfo(level, "u")
	--if info and 1 <= index and index <= info.nparams then
	-- debug.getlocal returns the name as the first return value
	return (debug_getlocal(level, index))
	--end
end

M.get_param_name = get_param_name

--- Get the value of a parameter by index.<br>
--- Returns the value of the parameter at the specified index (1-based).<br>
--- Returns nil if the index is out of bounds.
---@param level integer The stack frame level to inspect (1 = current function, 2 = caller, etc.).
---@param index integer The argument index (1-based).
---@return any any Parameter value.
---@usage <br>
--- ```
--- local value = debug_helper.get_param_value(2, 1)
--- print("First param value:", value)
--- ```
local function get_param_value(level, index)
	local _, value = debug_getlocal(level, index)
	return value
end

M.get_param_value = get_param_value

--- Get upvalues of the function at a given level.<br>
--- Returns an array of upvalue entries with name and value.<br>
--- Each entry: `{ name = string, value = any }`<br>
--- Upvalues are external variables captured by the function's closure.
---@param func_level function|integer The function -or- stack frame level to inspect (1 = current function, 2 = caller, etc.).
---@return table|nil array Array of { name, value } entries, or nil if level is invalid.
---@usage <br>
--- ```
--- local ups = debug_helper.get_upvalues(2)
--- for i, up in next, ups do
---   print(up.name, "=", up.value)
--- end
--- ```
local function get_upvalues(func_level)
	local func = get_function(func_level)
	if not func then
		return
	end

	local ups = {}
	local i = 1

	while true do
		local name, value = debug_getupvalue(func, i)
		if not name then
			break
		end
		ups[i] = { name = name, value = value }
		i = i + 1
	end

	return ups
end

M.get_upvalues = get_upvalues

--- Get an upvalue of a function by name.<br>
--- Searches through all upvalues of a function and returns the value of the one with the specified name.<br>
--- Returns nil if the upvalue with the given name is not found.
---@param f function Function to get upvalue from.
---@param name string Name of the upvalue to retrieve.
---@return any value Value of the upvalue, or nil if not found.
---@return integer|nil index Index of the upvalue, or nil if not found.
---@usage <br>
--- ```
--- local value, index = debug_helper.get_upvalue(myfunction, "_ENV")
--- if value then print(value) end
--- ```
local function get_upvalue(f, name)
	local i = 1
	while true do
		local n, v = debug_getupvalue(f, i)
		if not n then break end
		if n == name then return v, i end
		i = i + 1
	end
	return nil, nil
end

M.get_upvalue = get_upvalue

--- Set an upvalue of a function by name.<br>
--- Searches through all upvalues of a function and sets the value of the one with the specified name.<br>
--- Returns true if the upvalue was found and set, false otherwise.
---@param f function Function to set upvalue for.
---@param name string Name of the upvalue to set.
---@param value any New value for the upvalue.
---@return boolean success True if upvalue was found and set, false otherwise.
---@return integer|nil index Index of the upvalue that was set, or nil if not found.
---@usage <br>
--- ```
--- local success, index = debug_helper.setupvalue(myfunction, "_ENV", myenv)
--- if success then print("Set _ENV at index:", index) end
--- ```
local function setupvalue(f, name, value)
	local i = 1
	while true do
		local n = debug_getupvalue(f, i)
		if not n then break end
		if n == name then
			debug_setupvalue(f, i, value)
			return true, i
		end
		i = i + 1
	end
	return false, nil
end

M.setupvalue = setupvalue

--- Set the environment of a function (compatibility shim).<br>
--- Provides setfenv functionality for Lua 5.2+ using debug.setupvalue.<br>
--- In Lua 5.1, uses the native setfenv function if available.<br>
--- In Lua 5.2+, uses debug.getupvalue/debug.setupvalue to modify the _ENV upvalue.
---@param f function Function whose environment to set.
---@param env table Environment table to set.
---@return function function The function f (unchanged or modified).
---@usage <br>
--- ```
--- local myenv = { x = 10 }
--- debug_helper.setfenv(myfunction, myenv)
--- ```
local function setfenv(f, env)
	if _setfenv then
		-- Lua 5.1: use native setfenv if available
		_setfenv(f, env)
	else
		-- Lua 5.2+: use debug.setupvalue to set _ENV upvalue
		setupvalue(f, ENV_UPVALUE_NAME, env)
	end
	return f
end

M.setfenv = setfenv

--- Get the environment of a function (compatibility shim).<br>
--- Provides getfenv functionality for Lua 5.2+ using debug.getupvalue.<br>
--- In Lua 5.1, uses the native getfenv function if available.<br>
--- In Lua 5.2+, uses debug.getupvalue to retrieve the _ENV upvalue.
---@param f function Function whose environment to get.
---@return table|nil env Environment table, or nil if not found.
---@usage <br>
--- ```
--- local env = debug_helper.getfenv(myfunction)
--- if env then print(env.x) end
--- ```
local function getfenv(f)
	-- Lua 5.1: use native getfenv if available
	if _getfenv then
		return _getfenv(f)
	end
	-- Lua 5.2+: use debug.getupvalue to get _ENV upvalue
	return (get_upvalue(f, ENV_UPVALUE_NAME))
end

M.getfenv = getfenv

--- List all upvalues of a function.<br>
--- Returns a table mapping upvalue names to their values.
---@param f function Function to list upvalues for.
---@return table upvalues Table of upvalue names to values.
---@usage <br>
--- ```
--- local upvalues = debug_helper.list_upvalues(myfunction)
--- for name, value in next, upvalues do
---   print(name, "=", value)
--- end
--- ```
local function list_upvalues(f)
	local upvalues = {}
	local i = 1
	while true do
		local n, v = debug_getupvalue(f, i)
		if not n then break end
		upvalues[n] = v
		i = i + 1
	end
	return upvalues
end

M.list_upvalues = list_upvalues

--- Get a structured stack trace (table, not string).<br>
--- Returns an array of debug.getinfo tables for all stack frames.<br>
--- Each table contains information like source, name, namewhat, currentline, etc.<br>
--- Useful for programmatic stack inspection instead of debug.traceback string.
---@return table array Array of `debug.getinfo` tables with full debug information.
---@usage <br>
--- ```
--- local stack = debug_helper.get_stack()
--- for i, frame in next, stack do
---   print(i, frame.name, "at", frame.source .. ":" .. frame.currentline)
--- end
--- ```
local function get_stack()
	local frames = {}
	local level = 1

	while true do
		local info = debug_getinfo(level, GETINFO_ALL)
		if not info then
			break
		end
		frames[level] = info
		level = level + 1
	end

	return frames
end

M.get_stack = get_stack

--- Get the name of the caller function.<br>
--- Returns the name of the function at the specified stack level.<br>
--- Defaults to level 2 (the function calling this one) if not specified.
---@param level integer|nil The stack frame level to inspect (default: 2).
---@return string|nil name The function name, or nil if not found.
---@usage <br>
--- ```
--- local caller = debug_helper.get_caller_name(2)
--- if caller then print("Called by:", caller) end
--- ```
local function get_caller_name(level)
	local info = debug_getinfo(level or 2, GETINFO_NAME)
	if info then
		return info.name
	end
end

M.get_caller_name = get_caller_name

--- Dump a full frame snapshot.<br>
--- Returns a comprehensive snapshot of a stack frame including:<br>
--- - parameters (array of { name, value })<br>
--- - varargs (array of vararg values)<br>
--- - locals (array with kind classification)<br>
--- - upvalues (array of { name, value })<br>
--- - info (full debug.getinfo table)<br>
--- Useful for debugging and introspection.
---@param level integer|nil The stack frame level to inspect (default: 2).
---@return table snapshot Complete frame snapshot with all available information.
---@usage <br>
--- ```
--- local frame = debug_helper.dump_frame(2)
--- print("Parameters:", frame.parameters)
--- print("Locals:", frame.locals)
--- print("Upvalues:", frame.upvalues)
--- ```
local function dump_frame(level)
	level = level or 2
	return {
		parameters = get_parameters(level),
		varargs = get_varargs(level),
		locals = get_locals(level),
		upvalues = get_upvalues(level),
		info = debug_getinfo(level, GETINFO_ALL),
	}
end

M.dump_frame = dump_frame

---@class DebuggerState
---@field enabled boolean Whether the debugger is active
---@field paused boolean Whether execution is paused
---@field stepping_mode integer|nil One of STEPPING_MODES, or nil
---@field current_level integer Current stack depth
---@field target_level integer Target stack depth for stepping
---@field breakpoints table<string, table<integer, boolean>> Breakpoint source files and line numbers
---@field on_break function|nil Called when execution pauses
---@field on_line function|nil Called on each line event
---@field on_call function|nil Called on each function call
---@field on_return function|nil Called on each function return

local debugger = {
	-- Debugger state
	enabled = false,
	paused = false,
	stepping_mode = nil,
	current_level = 0,
	target_level = 0,
	breakpoints = {},

	-- Optional callbacks for consumer to implement
	on_break = nil,
	on_line = nil,
	on_call = nil,
	on_return = nil,
}

---@class SteppingModes
---@field STEP_OVER integer Step over to next line in current function
---@field STEP_IN integer Step into function calls
---@field STEP_OUT integer Step out of current function

local STEPPING_MODES = {
	-- @formatter:off
	[1]       = "STEP_OVER",
	[2]       = "STEP_IN",
	[3]       = "STEP_OUT",
	STEP_OVER = 1,
	STEP_IN   = 2,
	STEP_OUT  = 3,
	-- @formatter:on
}

-- Internal hook function called by `debug.sethook`
local function debugger_hook(event, line)
	if not debugger.enabled then
		return
	end

	local info = debug_getinfo(2, GETINFO_ALL)

	-- Handle stepping modes
	if debugger.paused or debugger.stepping_mode then
		if event == EVENT_LINE then
			if debugger.stepping_mode == 1 then -- STEPPING_MODES.STEP_OVER
				-- Step over: only pause if we're in the same function or shallower
				if debugger.current_level <= debugger.target_level then
					debugger.paused = true
					debugger.stepping_mode = nil
					if debugger.on_break then
						debugger.on_break(info, line, event)
					end
				end
			elseif debugger.stepping_mode == 2 then -- STEPPING_MODES.STEP_IN
				-- Step in: pause on every line
				debugger.paused = true
				debugger.stepping_mode = nil
				if debugger.on_break then
					debugger.on_break(info, line, event)
				end
			elseif debugger.stepping_mode == 3 then -- STEPPING_MODES.STEP_OUT
				-- Step out: only pause when we return to a shallower level
				if debugger.current_level < debugger.target_level then
					debugger.paused = true
					debugger.stepping_mode = nil
					if debugger.on_break then
						debugger.on_break(info, line, event)
					end
				end
			elseif debugger.paused then
				-- Already paused, just notify
				if debugger.on_break then
					debugger.on_break(info, line, event)
				end
			end
		elseif event == EVENT_RETURN then
			debugger.current_level = debugger.current_level - 1
		elseif event == EVENT_CALL then
			debugger.current_level = debugger.current_level + 1
		end
	end

	-- Check breakpoints
	if event == EVENT_LINE and debugger.breakpoints[info.source] then
		local bp_lines = debugger.breakpoints[info.source]
		if bp_lines[line] then
			debugger.paused = true
			if debugger.on_break then
				debugger.on_break(info, line, event, BREAKPOINT_REASON)
			end
		end
	end

	-- Call event callbacks
	if event == EVENT_LINE and debugger.on_line then
		debugger.on_line(info, line)
	elseif event == EVENT_CALL and debugger.on_call then
		debugger.on_call(info, line)
	elseif event == EVENT_RETURN and debugger.on_return then
		debugger.on_return(info, line)
	end
end

--- Enable the debugger and install the debug hook.<br>
--- This activates the debugger and begins intercepting execution events.
---@param mask string|nil Hook mask ("clr" for call/line/return, default: "clr").
---@param count integer|nil Hook count (default: 0, meaning call on every event).
---@usage <br>
--- ```
--- debug_helper.debugger_enable("clr", 0)
--- ```
local function debugger_enable(mask, count)
	mask = mask or HOOK_MASK_DEFAULT
	count = count or 0
	debug_sethook(debugger_hook, mask, count)
	debugger.enabled = true
end

--- Disable the debugger and remove the debug hook.<br>
--- This deactivates the debugger and stops intercepting execution events.
---@usage <br>
--- ```
--- debug_helper.debugger_disable()
--- ```
local function debugger_disable()
	debug_sethook()
	debugger.enabled = false
	debugger.paused = false
	debugger.stepping_mode = nil
end

--- Pause execution at the next opportunity.<br>
--- Sets the paused flag, causing the debugger to break on the next line event.
---@usage <br>
--- ```
--- debug_helper.debugger_pause()
--- ```
local function debugger_pause()
	debugger.paused = true
end

--- Resume execution after a pause.<br>
--- Clears the paused flag and continues execution.
---@usage <br>
--- ```
--- debug_helper.debugger_resume()
--- ```
local function debugger_resume()
	debugger.paused = false
	debugger.stepping_mode = nil
end

--- Step over to the next line in the current function.<br>
--- Executes the next line but doesn't enter function calls.
---@usage <br>
--- ```
--- debug_helper.debugger_step_over()
--- ```
local function debugger_step_over()
	debugger.paused = false
	debugger.stepping_mode = 1 -- STEPPING_MODES.STEP_OVER
	debugger.target_level = debugger.current_level
end

--- Step into the next function call.<br>
--- Enters function calls to debug them.
---@usage <br>
--- ```
--- debug_helper.debugger_step_in()
--- ```
local function debugger_step_in()
	debugger.paused = false
	debugger.stepping_mode = 2 -- STEPPING_MODES.STEP_IN
end

--- Step out of the current function.<br>
--- Continues execution until returning from the current function.
---@usage <br>
--- ```
--- debug_helper.debugger_step_out()
--- ```
local function debugger_step_out()
	debugger.paused = false
	debugger.stepping_mode = 3 -- STEPPING_MODES.STEP_OUT
	debugger.target_level = debugger.current_level
end

--- Set a breakpoint at a specific source file and line.<br>
--- Execution will pause when reaching this line.
---@param source string Source file path (e.g., "@myfile.lua" or "myfile.lua").
---@param line integer Line number to break at.
---@usage <br>
--- ```
--- debug_helper.debugger_set_breakpoint("@myfile.lua", 42)
--- ```
local function debugger_set_breakpoint(source, line)
	if not debugger.breakpoints[source] then
		debugger.breakpoints[source] = {}
	end
	debugger.breakpoints[source][line] = true
end

--- Clear a breakpoint at a specific source file and line.<br>
--- Removes the breakpoint if it exists.
---@param source string Source file path.
---@param line integer Line number to clear.
---@usage <br>
--- ```
--- debug_helper.debugger_clear_breakpoint("@myfile.lua", 42)
--- ```
local function debugger_clear_breakpoint(source, line)
	if debugger.breakpoints[source] then
		debugger.breakpoints[source][line] = nil
	end
end

--- Clear all breakpoints.<br>
--- Removes all breakpoints from all source files.
---@usage <br>
--- ```
--- debug_helper.debugger_clear_all_breakpoints()
--- ```
local function debugger_clear_all_breakpoints()
	debugger.breakpoints = {}
end

--- List all breakpoints.<br>
--- Returns a table of all breakpoints organized by source file.
---@return table breakpoints Table mapping source files to line numbers.
---@usage <br>
--- ```
--- local bps = debug_helper.debugger_list_breakpoints()
--- for source, lines in next, bps do
---   print(source, ":", table.concat(lines, ", "))
--- end
--- ```
local function debugger_list_breakpoints()
	local result = {}
	for source, lines in next, debugger.breakpoints do
		local t = {}
		result[source] = t
		for line in next, lines do
			table_insert(t, line)
		end
		table_sort(result[source])
	end
	return result
end

---@class DebugInfo
---@field name string|nil Function name
---@field namewhat string|nil Type of name ("global", "local", "method", "field", etc.)
---@field source string Source file
---@field short_src string Shortened source
---@field linedefined integer Line where function was defined
---@field lastlinedefined integer Last line of function definition
---@field what string Function type ("Lua", "C", "main")
---@field currentline integer Current line number
---@field istailcall boolean Whether this is a tail call
---@field nparams integer Number of parameters
---@field isvararg boolean Whether function accepts varargs
---@field func function The function object
---@field activelines table|nil Active line numbers
---@field nups integer Number of upvalues

---@alias BreakCallback fun(info: DebugInfo, line: integer, event: string, reason: string|nil): nil
---@alias LineCallback fun(info: DebugInfo, line: integer): nil
---@alias CallCallback fun(info: DebugInfo, line: integer): nil
---@alias ReturnCallback fun(info: DebugInfo, line: integer): nil

--- Set the callback for when execution pauses.<br>
--- The callback receives (info, line, event, reason) parameters.
---@param callback BreakCallback|nil Callback function or nil to clear.
---@usage <br>
--- ```
--- debug_helper.debugger_on_break(function(info, line, event, reason)
---   print("Paused at", info.source, "line", line, "reason:", reason)
--- end)
--- ```
local function debugger_on_break(callback)
	debugger.on_break = callback
end

--- Set the callback for line events.<br>
--- The callback receives (info, line) parameters.
---@param callback LineCallback|nil Callback function or nil to clear.
---@usage <br>
--- ```
--- debug_helper.debugger.on_line(function(info, line)
---   print("Line", line, "in", info.source)
--- end)
--- ```
local function debugger_on_line(callback)
	debugger.on_line = callback
end

--- Set the callback for function call events.<br>
--- The callback receives (info, line) parameters.
---@param callback CallCallback|nil Callback function or nil to clear.
---@usage <br>
--- ```
--- debug_helper.debugger.on_call(function(info, line)
---   print("Called", info.name or "anonymous", "at", line)
--- end)
--- ```
local function debugger_on_call(callback)
	debugger.on_call = callback
end

--- Set the callback for function return events.<br>
--- The callback receives (info, line) parameters.
---@param callback ReturnCallback|nil Callback function or nil to clear.
---@usage <br>
--- ```
--- debug_helper.debugger.on_return(function(info, line)
---   print("Returned from", info.name or "anonymous", "at", line)
--- end)
--- ```
local function debugger_on_return(callback)
	debugger.on_return = callback
end

---@alias DebugEvent "call"|"line"|"return"
---@alias DebugHookCallback fun(info: DebugInfo, line: integer, event: DebugEvent): nil

--- Set a single callback for all debug hook events (call, line, return).<br>
--- This is a convenience function that sets up all three event handlers with one callback.<br>
--- The callback receives (info, line, event) parameters where event is "call", "line", or "return".
---@param callback DebugHookCallback|nil Callback function or nil to clear all handlers.
---@usage <br>
--- ```
--- debug_helper.debugger.on_hook(function(info, line, event)
---   print("Event:", event, "at", info.source .. ":" .. line)
--- end)
--- ```
local function debugger_on_hook(callback)
	if callback then
		debugger.on_call = function(info, line)
			callback(info, line or info.currentline, EVENT_CALL)
		end
		debugger.on_line = function(info, line)
			callback(info, line, EVENT_LINE)
		end
		debugger.on_return = function(info, line)
			callback(info, line or info.currentline, EVENT_RETURN)
		end
	else
		debugger.on_call = nil
		debugger.on_line = nil
		debugger.on_return = nil
	end
end

--- Get the current debugger state.<br>
--- Returns a table with the current state of the debugger.
---@return table state Debugger state table with enabled, paused, stepping_mode, etc.
---@usage <br>
--- ```
--- local state = debug_helper.debugger.get_state()
--- print("Enabled:", state.enabled, "Paused:", state.paused)
--- ```
local function debugger_get_state()
	return {
		enabled = debugger.enabled,
		paused = debugger.paused,
		stepping_mode = debugger.stepping_mode,
		current_level = debugger.current_level,
		target_level = debugger.target_level,
		breakpoints = debugger_list_breakpoints(),
	}
end

-- Debugger API
--
-- A modular debugger using builtin `debug.sethook` for stepping and breakpoints.
--
-- Users can implement their own debugger interface by providing callbacks.
M.debugger = {
	enable = debugger_enable,
	disable = debugger_disable,
	pause = debugger_pause,
	resume = debugger_resume,
	step_over = debugger_step_over,
	step_in = debugger_step_in,
	step_out = debugger_step_out,
	set_breakpoint = debugger_set_breakpoint,
	clear_breakpoint = debugger_clear_breakpoint,
	clear_all_breakpoints = debugger_clear_all_breakpoints,
	list_breakpoints = debugger_list_breakpoints,
	on_break = debugger_on_break,
	on_line = debugger_on_line,
	on_call = debugger_on_call,
	on_return = debugger_on_return,
	on_hook = debugger_on_hook,
	get_state = debugger_get_state,
	STEPPING_MODES = STEPPING_MODES,
}

-- Export
return M
