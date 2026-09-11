-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Dynamic Lua code execution across different Lua versions (LuaJIT/5.1+ and later)

-- Localized globals for better performance
local pcall = pcall
local setmetatable = setmetatable
local type = type
local loadstring, setfenv = type(_G.load) == "function" and _G.load or _G.loadstring, _G.setfenv

-- Detect LuaJIT/5.1 runtime
-- TODO: Use detect_runtime for realiability
-- local detected_runtime = require("detect_runtime")()
-- detected_runtime.capabilities.load_accepts_env
local IS_LEGACY = (_VERSION == "Lua 5.1" or _G.jit) and
	(type(setfenv) == "function" and type(loadstring) == "function")

local set_env
if IS_LEGACY then
	-- LuaJIT/5.1 uses the original setfenv
	set_env = debug and type(debug.setfenv) == "function" and debug.setfenv or setfenv
else
	local debug = assert(_G.debug, "debug library is missing")
	local ENV = "_ENV"
	local debug_getupvalue = debug.getupvalue
	local debug_setupvalue = debug.setupvalue
	set_env = function(fn, env) -- TODO: use debug_helper.setupvalue
		-- 5.2+ uses the _ENV upvalue mechanism
		local i = 1
		repeat
			local name = debug_getupvalue(fn, i)
			if name == ENV then
				debug_setupvalue(fn, i, env)
				break
			end
			i = i + 1
		until not name
		return fn
	end
end

local load_string
if IS_LEGACY then
	load_string = function(code, chunk_name, mode, env)
		-- 5.1 loadstring doesn't support mode and env arguments
		local chunk, err = loadstring(code, chunk_name)
		if chunk then setfenv(chunk, env) end
		return chunk, err
	end
else
	load_string = function(code, chunk_name, mode, env)
		-- 5.2+ load supports the env argument directly
		-- "t" mode allows text only (prevents binary bytecode exploits)
		return loadstring(code, chunk_name or "=(loadstring)", mode or "bt", env or _G)
	end
end

--- Executes user code (string or function) in an isolated environment with sandboxing.<br>
--- This function provides a secure way to execute arbitrary Lua code while controlling the global environment it has access to.<br>
--- Compatible with LuaJIT, Lua 5.1 and later.<br>
--- NOTE:
--- - When `input` is a function, modifying its environment affects it globally.
--- - The sandbox environment prevents pollution of the global namespace.
--- - Uses `pcall` internally to catch runtime errors safely.
--- - In Lua 5.2+, mode "t" prevents binary bytecode execution for security.
---@param input string|function The code to execute - either a Lua code string, or a function object. Can be either:
--- - **string**: Lua source code that will be compiled and executed.
--- - **function**: A function that will have its environment modified (note: this affects the function globally).
---@param sandbox_env? table Optional sandbox environment table. If nil, creates a secure environment that proxies to `_G` via metatable.<br>
--- The sandbox allows controlled access to global functions while preventing pollution of the global namespace.
---@param chunk_name? string Optional name for error reporting and debugging. Defaults to Lua's loadstring default.
---@param mode? string Optional loading mode. In Lua 5.2+, "t" allows text only (prevents binary bytecode exploits).<br>
--- Defaults to "bt" (binary and text) in Lua 5.2+, ignored in LuaJIT and Lua 5.1.
---@return boolean success True if execution completed without errors, false otherwise.
---@return any ...
--- - On success: the return values from the executed code.<br>
--- - On failure: an error message string describing the failure.<br>
--- Common errors include syntax errors, runtime errors, or type validation failures.
---@usage <br>
--- ```
--- -- Execute code with custom sandbox
--- local sandbox = { safe_var = 42 }
--- setmetatable(sandbox, { __index = _G })  -- Allow global access
--- local ok, result = run_isolated("return safe_var * 2", sandbox)
--- if ok then print(result) else print("Error:", result) end
---
--- -- Execute function with isolation
--- local func = function() return math.sqrt(16) end
--- local ok, result = run_isolated(func)
--- ```
local function run_isolated(input, sandbox_env, chunk_name, mode)
	-- Create a default environment if none provided
	-- Using a metatable allows access to _G without polluting it
	local env = sandbox_env or setmetatable({}, { __index = _G }) -- TODO/CONS: perhaps use `__index = _ENV or _G`?

	local compiled_func, err

	if type(input) == "string" then
		compiled_func, err = load_string(input, chunk_name, mode, env)
	elseif type(input) == "function" then
		-- We must be careful: modifying a function's env affects it globally unless we're working with a fresh closure
		compiled_func = set_env(input, env)
	else
		return false, "input must be a string or function"
	end

	if not compiled_func then
		return false, "load error: " .. tostring(err)
	end

	-- Run in protected mode to catch runtime errors
	return pcall(compiled_func)
end

--- Executes user code (string or function) in the global environment.
---@param input string|function The string of code -or- the function object.
---@return boolean success Success indicator.
---@return any ... Return values or error message.
local function run(input)
	return run_isolated(input, _G)
end

-- Export
return {
	set_env = set_env,
	load_string = load_string,
	run_isolated = run_isolated,
	run = run,
}
