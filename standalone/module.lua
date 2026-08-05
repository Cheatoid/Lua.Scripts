-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Lua 5.1 compatibility implementation of module() function
-- Provides module environment management for Lua 5.2+ compatibility

-- Localized global functions for better performance
local _VERSION = _VERSION
local error = error
local select = select
local type = type
local debug_getinfo = debug and debug.getinfo
local debug_getupvalue = debug and debug.getupvalue
local debug_setfenv = debug and debug.setfenv or setfenv
local debug_setupvalue = debug and debug.setupvalue

--- Creates or retrieves a module table and sets the calling function's environment to it.<br>
--- This is a compatibility implementation of Lua 5.1's `module()` function for Lua 5.2+.<br>
--- Supports `package.seeall` and other modifier functions passed as varargs.<br>
--- Works with LuaJIT/5.1+ and later.
---@param string name The module name (must match the `require()` name).
---@param ... function Optional modifier functions (e.g., `package.seeall`) applied to the module table.
---@return table mod The module table that becomes the environment for the calling function.
---@usage <br>
--- ```
--- -- Basic module creation
--- local my_module = module("my_module")
---
--- -- Module is now the environment; all globals become module members
--- function hello()
---   return "Hello from my_module!"
--- end
---
--- -- With package.seeall (access to globals)
--- local my_module2 = module("my_module2", package.seeall)
---
--- -- In a file loaded via require():
--- -- File: my_library.lua
--- local my_lib = module("my_library")
---
--- local internal_value = 42 -- private to module
---
--- function public_func() -- public function
---   return internal_value
--- end
---
--- return my_lib -- Return the module table
--- ```
local function module(name, ...)
	-- Validate name
	if type(name) ~= "string" then
		return error("bad argument #1 to 'module' (string expected, got " .. type(name) .. ")", 2)
	end

	-- Retrieve or create the module table
	local mod
	if package and package.loaded then
		mod = package.loaded[name]
	end
	if type(mod) ~= "table" then
		mod = {}
		if package and package.loaded then
			package.loaded[name] = mod
		end
	end

	-- Apply any modifier functions passed as varargs (e.g., package.seeall)
	for i = 1, select("#", ...) do
		local f = select(i, ...)
		if type(f) == "function" then
			f(mod)
		elseif type(f) ~= "nil" then
			return error("bad argument #" .. (i + 1) .. " to 'module' (function expected, got " .. type(f) .. ")", 2)
		end
	end

	-- Set the environment of the CALLING function to mod
	if _VERSION == "Lua 5.1" or jit or type(debug_setfenv) == "function" then
		-- Lua 5.1 / LuaJIT: use setfenv on the caller (level 2)
		-- debug.setfenv is preferred; global setfenv may not exist in some embedded builds
		if debug_setfenv then
			debug_setfenv(2, mod)
		else
			return error("'module' requires debug.setfenv or setfenv in Lua 5.1/LuaJIT", 2)
		end
	elseif _VERSION >= "Lua 5.2" or debug then
		-- Lua 5.2+: modify the _ENV upvalue of the calling function
		local level = 2
		local info = debug_getinfo(level, "f")
		if not info or not info.func then
			return error("cannot determine calling function for 'module'", 2)
		end

		local idx, found = 1
		while true do
			local n, v = debug_getupvalue(info.func, idx)
			if n == nil then break end
			if n == "_ENV" then
				debug_setupvalue(info.func, idx, mod)
				found = true
				break
			end
			idx = idx + 1
		end

		if not found then
			return error("calling function has no '_ENV' upvalue; cannot set module environment", 2)
		end
	else
		return error("'module' requires debug library in Lua 5.2+", 2)
	end

	return mod
end

-- Export
return module
