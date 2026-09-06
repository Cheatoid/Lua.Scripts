-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- LuaJIT / 5.1+ compatibility library for loading/running code at runtime.
-- Provides sandboxed environment execution and version-agnostic utilities.
--
-- Features:
-- * loadstring shim for 5.2+ environments
-- * Sandboxed environment execution
-- * getfenv/setfenv shims for 5.2+
--
-- Usage example:
-- ```
-- local isolated = require "isolated"
--
-- -- loadstring works everywhere
-- local f = isolated.loadstring("return 1 + 1")
--
-- -- Run code in sandbox
-- local ok, result = isolated.safe_run("return 2 * 3")
--
-- -- Custom sandbox environment
-- local env = isolated.create_env({
--   inject = { foo = 42 },
--   allow = { "coroutine" },
--   deny  = { "math" }
-- })
-- isolated.run_string("return foo * 2", env)
-- ```
local M                = {}

-- Localized globals for better performance
local error            = error
local type             = type
local xpcall           = xpcall
local loadstring       = _G.loadstring
local setfenv          = _G.setfenv
local getfenv          = _G.getfenv
local jit              = _G.jit
local debug_getinfo    = debug.getinfo
local debug_getupvalue = debug.getupvalue
local debug_setupvalue = debug.setupvalue

----------------------------------------------------------------------
-- Feature detection (more reliable than version strings)
----------------------------------------------------------------------

local HAS_LOADSTRING   = loadstring ~= nil
local HAS_SETFENV      = setfenv ~= nil
local IS_LUAJIT        = jit ~= nil

----------------------------------------------------------------------
-- loadstring shim - Provides 5.1-style loadstring for all Lua versions
-- 5.1: loadstring(str [, chunkname]) -> func | nil, err
-- 5.2+: load(str [, chunkname [, mode [, env]]]) -> func | nil, err
----------------------------------------------------------------------

if HAS_LOADSTRING then
	M.loadstring = loadstring
else
	--- Load a string as a Lua chunk (5.2+ compatibility shim).
	---@param str string String containing Lua code
	---@param chunkname? string Name of the chunk for error messages
	---@return function? function Loaded function or nil if error
	---@return string? error Error message if loading failed
	M.loadstring = function(str, chunkname)
		if type(str) ~= "string" then
			str = tostring(str)
		end
		-- 5.1 defaults chunkname to the string itself
		chunkname = chunkname or str
		-- Pass _ENV to mimic 5.1's "inherits caller's environment" behavior
		return load(str, chunkname, "bt", _ENV or _G)
	end
end

----------------------------------------------------------------------
-- getfenv / setfenv shims (for Lua 5.2+)
----------------------------------------------------------------------

local _getfenv, _setfenv = getfenv, setfenv

if not _getfenv then
	_getfenv = function(f)
		if f == nil then f = 1 end
		if type(f) == "number" then
			local info = debug_getinfo(f + 1, "f")
			if not info then return nil end
			f = info.func
		end
		if type(f) ~= "function" then return nil end
		-- Search for _ENV upvalue (5.2+ environment mechanism)
		local i = 1
		repeat
			local name, val = debug_getupvalue(f, i)
			if name == "_ENV" then return val end
			i = i + 1
		until not name
		return _G
	end
end

if not _setfenv then
	_setfenv = function(f, env)
		if type(f) == "number" then
			local info = debug_getinfo(f + 1, "f")
			if not info then
				return error("invalid function or stack level", 2)
			end
			f = info.func
		end
		if type(f) ~= "function" then
			return error("bad argument #1 to 'setfenv' (function expected)", 2)
		end
		local i = 1
		repeat
			local name = debug_getupvalue(f, i)
			if name == "_ENV" then
				debug_setupvalue(f, i, env)
				return f
			end
			i = i + 1
		until not name
		-- No _ENV found (C function, etc.) - silently succeed per 5.1 behavior
		return f
	end
end

M.getfenv = _getfenv
M.setfenv = _setfenv

--- Internal: set function environment (version-agnostic).
---@param func function Function to set environment for
---@param env table Environment table to set
---@return function func Function with environment set
local function set_func_env(func, env)
	if HAS_SETFENV then
		_setfenv(func, env)
		return func
	end
	-- Lua 5.2+: manipulate _ENV upvalue directly
	local i = 1
	repeat
		local name = debug_getupvalue(func, i)
		if name == "_ENV" then
			debug_setupvalue(func, i, env)
			return func
		end
		i = i + 1
	until not name
	return func
end

-- Internal: safe default list of whitelisted globals<br>
-- These globals are considered safe for sandboxed execution
local DEFAULT_SAFE = {
	-- Type & conversion
	type     = true,
	tostring = true,
	tonumber = true,
	select   = true,

	-- Raw access (no metamethods)
	rawget   = true,
	rawset   = true,
	rawequal = true,
	rawlen   = true,

	-- Iteration
	pairs    = true,
	ipairs   = true,
	next     = true,

	-- Safe libraries
	table    = true,
	string   = true,
	math     = true,

	-- Error handling
	error    = true,
	pcall    = true,
	xpcall   = true,

	-- Misc
	assert   = true,
	print    = true,

	-- Version-specific (nil-safe: won't copy if missing)
	unpack   = true, -- 5.1 only
	bit32    = true, -- 5.2 only
	utf8     = true, -- 5.3+ only
}

M.DEFAULT_SAFE = DEFAULT_SAFE

--- Create a sandboxed environment table with configurable access control.
---@param options? table Optional configuration options:
--- - `parent` (table, default: `_G`): Parent environment
--- - `allow` (table): Array of additional global names to allow
--- - `deny` (table): Array of global names to deny
--- - `inject` (table): Table of values to inject into environment
---@return table env Configured sandboxed environment
---@usage <br>
--- ```
--- -- Allow only specific libraries
--- local env = isolated.create_env({
---   allow = {"string", "math"},
---   deny = {"os", "io"}
--- })
---
--- -- Inject custom values
--- local env = isolated.create_env({
---   inject = { PI = 3.14159, helper = my_helper_func }
--- })
--- ```
function M.create_env(options)
	options = options or {}
	local parent = options.parent or _G

	-- Build allowed set from defaults
	local allowed = {}
	for name in next, DEFAULT_SAFE do
		allowed[name] = true
	end

	-- Merge extra allowed names
	if options.allow then
		for _, name in next, options.allow do
			allowed[name] = true
		end
	end

	-- Remove denied names
	if options.deny then
		for _, name in next, options.deny do
			allowed[name] = nil
		end
	end

	-- Populate environment
	local env = {}
	for name in next, allowed do
		if parent[name] ~= nil then
			env[name] = parent[name]
		end
	end

	-- Polyfills for missing functions

	-- unpack (5.2+ uses table.unpack)
	if not env.unpack and table.unpack then
		env.unpack = table.unpack
	end

	-- rawlen (5.1 lacks it; # doesn't invoke __len in 5.1)
	if not env.rawlen then
		env.rawlen = function(v)
			local t = type(v)
			if t == "string" then
				return #v
			end
			if t == "table" then
				return #v -- safe in 5.1 (no __len metamethod)
			end
			return error("bad argument #1 to 'rawlen' (table or string expected)", 2)
		end
	end

	-- LuaJIT: expose 'bit' as 'bit32' for 5.2 compat
	if not env.bit32 and IS_LUAJIT and bit then
		env.bit32 = bit
	end

	-- _VERSION
	env._VERSION = _VERSION

	-- Inject user values
	if options.inject then
		for k, v in next, options.inject do
			env[k] = v
		end
	end

	return env
end

--- Execute function or string in an isolated environment.
---@param func function|string Function to execute or string containing Lua code
---@param env? table Environment to execute in (default: creates safe env)
---@param ... any Arguments to pass to the function
---@return any result Return value of function, or nil if error
---@return string? error Error message if execution failed
---@usage <br>
--- ```
--- -- Execute a function
--- local result = isolated.run(my_func, env, arg1, arg2)
---
--- -- Execute a string
--- local result = isolated.run("return x * 2", { x = 10 })
--- ```
function M.run(func, env, ...)
	-- Accept string input
	if type(func) == "string" then
		local f, err = M.loadstring(func)
		if not f then return nil, err end
		func = f
	end

	if type(func) ~= "function" then
		return error("bad argument #1 to 'run' (function or string expected)", 2)
	end

	env = env or M.create_env()
	set_func_env(func, env)
	return func(...)
end

--- Convenience wrapper for string-only code execution.
---@param code string String containing Lua code to execute
---@param env? table Environment to execute in (default: creates safe env)
---@param ... any Arguments to pass to the loaded function
---@return any result Return value of code or nil if error
---@return string? error Error message if execution failed
---@usage <br>
--- ```
--- local result, err = isolated.run_string("return math.sqrt(16)")
--- -- result = 4.0
--- ```
function M.run_string(code, env, ...)
	local func, err = M.loadstring(code)
	if not func then
		return nil, err
	end
	return M.run(func, env, ...)
end

--- Run code with automatic pcall and enhanced error messages.
---@param func function|string Function to execute or string containing Lua code
---@param env? table Environment to execute in (default: creates safe env)
---@param ... any Arguments to pass to the function
---@return boolean success True if execution succeeded, false otherwise
---@return any result Return value if success, or error message if failed
---@usage <br>
--- ```
--- local ok, result = isolated.safe_run("return 1 / 0")
--- -- ok = false, result contains enhanced error message
--- ```
function M.safe_run(func, env, ...)
	-- Accept string input
	if type(func) == "string" then
		local f, err = M.loadstring(func)
		if not f then return false, err end
		func = f
	end

	if type(func) ~= "function" then
		return false, "bad argument #1 (function or string expected)"
	end

	env = env or M.create_env()
	set_func_env(func, env)

	local function handler(err)
		if type(err) == "string" then
			local info = debug_getinfo(func, "Sl")
			if info then
				return string.format(
					"%s\n  (sandboxed code at %s:%d)",
					err,
					info.short_src or "?",
					info.currentline or 0
				)
			end
		end
		return err
	end

	return xpcall(func, handler, ...)
end

--- Convenience wrapper for safe string execution.
---@param code string String containing Lua code to execute
---@param env? table Environment to execute in (default: creates safe env)
---@param ... any Arguments to pass to the loaded function
---@return boolean success True if execution succeeded, false otherwise
---@return any result Return value if success, or error message if failed
---@usage <br>
--- ```
--- local ok, result = isolated.safe_run_string("return 2 + 2")
--- -- ok = true, result = 4
--- ```
function M.safe_run_string(code, env, ...)
	local func, err = M.loadstring(code)
	if not func then return false, err end
	return M.safe_run(func, env, ...)
end

--- Load a string directly into a target environment.<br>
--- Avoids the two-step load-then-setfenv pattern for better performance.
---@param str string String containing Lua code to load
---@param env? table Target environment (default: _ENV or _G)
---@param chunkname? string Name of the chunk for error messages
---@return function? func Loaded function with environment set
---@return string? error Error message if loading failed
---@usage <br>
--- ```
--- local func = isolated.loadstring_env("return x", { x = 42 })
--- local result = func() -- result = 42
--- ```
function M.loadstring_env(str, env, chunkname)
	if type(str) ~= "string" then
		str = tostring(str)
	end
	chunkname = chunkname or str
	env = env or _ENV or _G

	if HAS_LOADSTRING then
		-- 5.1 / LuaJIT: load then setfenv
		local func, err = loadstring(str, chunkname)
		if func and env then
			set_func_env(func, env)
		end
		return func, err
	end

	-- 5.2+: pass env directly to load (sets _ENV upvalue)
	return load(str, chunkname, "bt", env)
end

-- Export
return M
