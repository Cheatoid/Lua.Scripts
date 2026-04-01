-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Dynamic Lua code execution across different Lua versions (LuaJIT / 5.1+).

-- Localized globals for better performance
local pcall = pcall
local setmetatable = setmetatable
local type = type
local loadstring, setfenv = _G.load or _G.loadstring, _G.setfenv

-- Detect LuaJIT/5.1 runtime
local IS_LEGACY = (_VERSION == "Lua 5.1" or _G.jit) and (setfenv ~= nil and loadstring ~= nil)

local set_env
if IS_LEGACY then
	set_env = function(fn, env)
		-- LuaJIT/5.1 uses the original setfenv
		return setfenv(fn, env)
	end
else
	local debug = assert(debug, "debug library not found")
	local ENV = "_ENV"
	local debug_getupvalue = debug.getupvalue
	local debug_setupvalue = debug.setupvalue
	set_env = function(fn, env)
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
		-- 5.1 loadstring doesn't support env argument
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

--- Executes user code (string or function) in an isolated environment with sandboxing.
--- This function provides a secure way to execute arbitrary Lua code while controlling
--- the global environment it has access to. Compatible with Lua LuaJIT/5.1+.
---
--- @param input string|function The code to execute - either a Lua code string or a function object.
--- - **string**: Lua source code that will be compiled and executed
--- - **function**: A function that will have its environment modified (note: this affects the function globally)
--- @param sandbox_env table|nil Optional sandbox environment table. If nil, creates a secure environment
---   that proxies to _G via metatable. The sandbox allows controlled access to global functions
---   while preventing pollution of the global namespace.
--- @param chunk_name string|nil Optional name for error reporting and debugging. Defaults to Lua's loadstring default.
--- @param mode string|nil Optional loading mode. In Lua 5.2+, "t" allows text only (prevents binary bytecode exploits).
---   Defaults to "bt" (binary and text) in Lua 5.2+, ignored in LuaJIT/5.1+.
---
--- @return boolean success True if execution completed without errors, false otherwise.
--- @return any ... On success: the return values from the executed code.<br>
---                 On failure: an error message string describing the failure.<br>
---                 Common errors include syntax errors, runtime errors, or type validation failures.
---
--- @usage <br>
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
---
--- @note <br>
--- - When input is a function, modifying its environment affects it globally
--- - The sandbox environment prevents pollution of the global namespace
--- - Compatible with LuaJIT, Lua 5.1 and later
--- - Uses pcall internally to catch runtime errors safely
--- - In Lua 5.2+, mode "t" prevents binary bytecode execution for security
local function run_isolated(input, sandbox_env, chunk_name, mode)
	-- Create a default environment if none provided
	-- Using a metatable allows access to _G without polluting it
	local env = sandbox_env or setmetatable({}, { __index = _G })

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
--- @param input string|function The string of code -or- the function object.
--- @return boolean success Success indicator.
--- @return any ... return Return values or error message.
local function run(input)
	return run_isolated(input, _G)
end

-- Quick tests
--if true then
--	-- Test 1: Basic string execution
--	print("\n1. Basic string execution:")
--	local code_str = "return 'Hello from ' .. _VERSION, my_var * 2"
--	local my_env = setmetatable({ my_var = 21 }, { __index = _G })
--	local ok, val1, val2 = run_isolated(code_str, my_env)
--	assert(ok, "String execution should succeed")
--	assert(type(val1) == "string", "First return should be string")
--	assert(val2 == 42, "Second return should be 42")
--	print("String execution:", ok, val1, val2)
--
--	-- Test 2: Function execution
--	print("\n2. Function execution:")
--	local function user_func()
--		return "Global access check: " .. tostring(print)
--	end
--	local ok, res = run_isolated(user_func)
--	assert(ok, "Function execution should succeed")
--	assert(type(res) == "string", "Function should return string")
--	print("Function execution:", ok, res)
--
--	-- Test 3: Syntax error handling
--	print("\n3. Syntax error handling:")
--	local bad_code = "return 1 + + 2" -- Invalid syntax
--	local ok, err = run_isolated(bad_code)
--	assert(not ok, "Syntax error should fail")
--	assert(type(err) == "string", "Error should be string")
--	print("Syntax error properly caught:", ok, err)
--
--	-- Test 4: Runtime error handling
--	print("\n4. Runtime error handling:")
--	local runtime_error_code = "return nil.method()"
--	local ok, err = run_isolated(runtime_error_code)
--	assert(not ok, "Runtime error should fail")
--	assert(type(err) == "string", "Error should be string")
--	print("Runtime error properly caught:", ok, err)
--
--	-- Test 5: Invalid input type
--	print("\n5. Invalid input type:")
--	local ok, err = run_isolated(123) -- Number instead of string/function
--	assert(not ok, "Invalid input should fail")
--	assert(err == "input must be a string or function", "Should return specific error")
--	print("Invalid input properly rejected:", ok, err)
--
--	-- Test 6: Sandbox isolation test
--	print("\n6. Sandbox isolation test:")
--	local sandbox = { x = 10 }
--	setmetatable(sandbox, { __index = _G })
--	local isolation_code = "x = x + 5; return x"
--	local ok, result = run_isolated(isolation_code, sandbox)
--	assert(ok, "Isolation should succeed")
--	assert(result == 15, "Should compute x + 5 = 15")
--	-- Note: When sandbox is passed directly, it gets modified. This is expected behavior.
--	assert(sandbox.x == 15, "Sandbox should be modified when used as environment")
--	print("Sandbox isolation working:", ok, result, "sandbox.x:", sandbox.x)
--
--	-- Test 7: No sandbox (default behavior)
--	print("\n7. Default sandbox behavior:")
--	local default_code = "return _VERSION"
--	local ok, result = run_isolated(default_code)
--	assert(ok, "Default sandbox should work")
--	assert(result == _VERSION, "Should return Lua version")
--	print("Default sandbox:", ok, result)
--
--	-- Test 8: Multiple return values
--	print("\n8. Multiple return values:")
--	local multi_return_code = "return 1, 2, 3, 'four', true"
--	local ok, r1, r2, r3, r4, r5 = run_isolated(multi_return_code)
--	assert(ok, "Multi-return should succeed")
--	assert(r1 == 1 and r2 == 2 and r3 == 3, "Numbers should match")
--	assert(r4 == "four", "String should match")
--	assert(r5 == true, "Boolean should match")
--	print("Multi-return:", ok, r1, r2, r3, r4, r5)
--
--	-- Test 9: Chunk name for error reporting
--	print("\n9. Chunk name test:")
--	local named_code = "return unknown_variable.method()"
--	local ok, err = run_isolated(named_code, nil, "test_chunk")
--	assert(not ok, "Unknown variable method call should fail")
--	assert(type(err) == "string", "Error should be string")
--	print("Chunk name test:", ok, err)
--
--	-- Test 10: Security test (preventing global pollution)
--	print("\n10. Security test (global pollution):")
--	local security_code = "global_test_var = 'should not pollute'"
--	local ok, result = run_isolated(security_code)
--	assert(ok, "Assignment should succeed in sandbox")
--	assert(_G.global_test_var == nil, "Global should not be polluted")
--	print("Security test passed:", ok, result, "global_test_var exists:", _G.global_test_var ~= nil)
--
--	-- Test 11: Function with upvalues
--	print("\n11. Function with upvalues:")
--	local outer_var = "outer"
--	local function closure_func()
--		return "Closure: " .. outer_var
--	end
--	local ok, result = run_isolated(closure_func)
--	assert(ok, "Closure execution should succeed")
--	assert(result == "Closure: outer", "Should access upvalue")
--	print("Closure test:", ok, result)
--
--	-- Test 12: Complex sandbox with restricted access
--	print("\n12. Restricted sandbox test:")
--	local restricted_env = {
--		safe_print = print,
--		math = math,
--		string = string
--	}
--	-- No __index metatable, so no access to other globals
--	local restricted_code = "return safe_print('Hello'), math.sqrt(9)"
--	local ok, result = run_isolated(restricted_code, restricted_env)
--	assert(ok, "Restricted execution should succeed")
--	print("Restricted test:", ok, result)
--
--	print("\n=== All Tests Passed ===")
--end

-- Export
return {
	set_env = set_env,
	load_string = load_string,
	run_isolated = run_isolated,
	run = run,
}
