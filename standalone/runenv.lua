-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Lua code loader across different Lua versions (5.1, 5.2+, LuaJIT).

-- Localized globals for better performance
local type = type
local error = error
local rawget = rawget
local pcall = pcall
local load = _G.load
local loadstring = _G.loadstring
local setfenv = _G.setfenv
local debug = _G.debug

local is51 = _VERSION == "Lua 5.1"
local has_setfenv = type(setfenv) == "function"
local has_debug = type(debug) == "table"
local loadfn = load or loadstring

-- loadstring shim for Lua 5.2+
if not loadstring then
	loadstring = function(code, chunkname)
		if type(code) ~= "string" then
			return nil, "bad argument #1 to 'loadstring' (string expected)"
		end
		return loadfn(code, chunkname or "=(loadstring)")
	end
end

--- Set environment for a function in a version-compatible way.
---
--- This function works across Lua 5.1, 5.2+, and LuaJIT by using the appropriate
--- environment setting mechanism available in each version.
---
--- For Lua 5.1/LuaJIT: Uses `setfenv`
--- For Lua 5.2+: Tries to set `_ENV` upvalue, falls back to wrapping
---
--- @param func function The function to set environment for.
--- @param env table|nil The environment table (uses `_G` or `_ENV` if nil).
--- @return function function The function with environment set (may be wrapped).
local function run_with_env(func, env)
	if type(func) ~= "function" then
		return error("first argument must be a function", 2)
	end

	env = env or (rawget(_G, "_ENV") or _G)

	if is51 or has_setfenv then
		-- Lua 5.1 / LuaJIT: setfenv available
		setfenv(func, env)
		return func
	end

	-- Lua 5.2+: prefer load with env for chunks; for functions try to set _ENV upvalue
	if has_debug and debug.getupvalue and debug.setupvalue then
		local i = 1
		while true do
			local name = debug.getupvalue(func, i)
			if not name then break end
			if name == "_ENV" then
				debug.setupvalue(func, i, env)
				return func
			end
			i = i + 1
		end
	end

	-- Fallback: wrap the function so it runs with env as _ENV
	local wrapper = load(
		"return function(f, _ENV) return function(...) return f(...) end end",
		"=(run_with_env_wrapper)"
	)
	if type(wrapper) == "function" then
		local make = wrapper()
		return make(func, env)
	end

	return error("cannot set environment for function on this Lua build", 2)
end

--- Compile a chunk string or accept a function, and run it with a custom environment.
---
--- This function provides a unified interface for loading and executing Lua code
--- with a specific environment, handling version differences automatically.
---
--- @param source string|function The source code string or function to load.
--- @param env table|nil The environment table (uses `_G` or `_ENV` if nil).
--- @param chunkname string|nil Optional name for error messages (default: "=(load_in_env)").
--- @param mode string|nil Optional mode for load in 5.2+ ("t", "b", "bt", default: "bt").
--- @param run_now boolean|nil If true, calls the chunk and returns results; if false/nil, returns compiled function.
--- @return function|any Compiled function if run_now is false, otherwise the chunk's return values.
local function load_in_env(source, env, chunkname, mode, run_now)
	env = env or (rawget(_G, "_ENV") or _G)
	chunkname = chunkname or "=(load_in_env)"

	if type(source) == "function" then
		local f = run_with_env(source, env)
		if run_now then return f() end
		return f
	end

	if type(source) ~= "string" then
		return error("source must be a string or function", 2)
	end

	-- Lua 5.2+ load accepts env parameter
	if load and not is51 then
		local ok, fn_or_err = pcall(load, source, chunkname, mode or "bt", env)
		if not ok then return error(fn_or_err, 2) end
		local fn = fn_or_err
		if run_now then return fn() end
		return fn
	end

	-- Lua 5.1 / loadstring
	local fn, err = loadfn(source, chunkname)
	if not fn then return error(err, 2) end
	if has_setfenv then
		setfenv(fn, env)
		if run_now then return fn() end
		return fn
	end

	-- try to set _ENV upvalue if possible
	if has_debug and debug.getupvalue and debug.setupvalue then
		local i = 1
		while true do
			local name = debug.getupvalue(fn, i)
			if not name then break end
			if name == "_ENV" then
				debug.setupvalue(fn, i, env)
				if run_now then return fn() end
				return fn
			end
			i = i + 1
		end
	end

	-- fallback wrap
	local wrapper = load(
		"return function(f, _ENV) return function(...) return f(...) end end",
		"=(load_in_env_wrapper)"
	)
	if type(wrapper) == "function" then
		local make = wrapper()
		fn = make(fn, env)
		if run_now then return fn() end
		return fn
	end

	return error("cannot set environment for compiled chunk in this Lua runtime", 2)
end

--- Convenience function to run a string immediately as if loaded where called.
---
--- This is a shortcut for `load_in_env` with run_now set to true.
---
--- @param source string The Lua source code to execute.
--- @param env table|nil The environment table (uses _G or _ENV if nil).
--- @param chunkname string|nil Optional name for error messages (default: "=(load_in_env)").
--- @param mode string|nil Optional mode for load in 5.2+ ("t", "b", "bt", default: "bt").
--- @return any The return values from executing the source code.
local function run_string(source, env, chunkname, mode)
	return load_in_env(source, env, chunkname, mode, true)
end

-- Quick tests
--if true then
--	local test_count = 0
--	local passed = 0
--	local failed = 0
--
--	local function assert_equal(actual, expected, test_name)
--		test_count = test_count + 1
--		if actual == expected then
--			passed = passed + 1
--			return true
--		else
--			failed = failed + 1
--			print(string.format("FAIL: %s - Expected %s, got %s", test_name, tostring(expected), tostring(actual)))
--			return false
--		end
--	end
--
--	local function assert_not_nil(value, test_name)
--		test_count = test_count + 1
--		if value ~= nil then
--			passed = passed + 1
--			return true
--		else
--			failed = failed + 1
--			print(string.format("FAIL: %s - Expected non-nil value", test_name))
--			return false
--		end
--	end
--
--	-- Test 1: run_with_env with a simple function
--	local function test_func()
--		return global_var
--	end
--
--	local test_env = { global_var = "test_value" }
--	local wrapped = run_with_env(test_func, test_env)
--	assert_equal(wrapped(), "test_value", "run_with_env with simple function")
--
--	-- Test 2: load_in_env with string source
--	local source = "return env_var"
--	local loaded_func = load_in_env(source, { env_var = 42 })
--	assert_equal(loaded_func(), 42, "load_in_env with string source")
--
--	-- Test 3: run_string immediate execution
--	local result = run_string("return 2 + 3")
--	assert_equal(result, 5, "run_string immediate execution")
--
--	-- Test 4: run_string with custom environment
--	local result2 = run_string("return custom_var", { custom_var = "hello" })
--	assert_equal(result2, "hello", "run_string with custom environment")
--
--	-- Test 5: load_in_env with function source
--	local function source_func()
--		return from_func
--	end
--	local wrapped_func = load_in_env(source_func, { from_func = "func_result" })
--	assert_equal(wrapped_func(), "func_result", "load_in_env with function source")
--
--	-- Test 6: load_in_env with run_now=true
--	local immediate_result = load_in_env("return 'immediate'", nil, nil, nil, true)
--	assert_equal(immediate_result, "immediate", "load_in_env with run_now=true")
--
--	-- Test 7: loadstring shim exists and works
--	assert_not_nil(loadstring, "loadstring shim exists")
--	local loaded, err = loadstring("return 'loadstring_works'")
--	if loaded then
--		assert_equal(loaded(), "loadstring_works", "loadstring shim functionality")
--	else
--		print("FAIL: loadstring shim - " .. tostring(err))
--		failed = failed + 1
--		test_count = test_count + 1
--	end
--
--	-- Test 8: Error handling for invalid function type
--	local ok, err = pcall(run_with_env, "not a function", {})
--	assert_not_nil(err, "run_with_env error handling for invalid type")
--
--	-- Test 9: Error handling for invalid source type
--	local ok2, err2 = pcall(load_in_env, 123, {})
--	assert_not_nil(err2, "load_in_env error handling for invalid source type")
--
--	-- Test 10: Environment isolation
--	local iso_env = { isolated = true }
--	local iso_func = load_in_env("return isolated", iso_env)
--	assert_equal(iso_func(), true, "Environment isolation")
--
--	-- Test results
--	print(string.format("\nTest Results: %d total, %d passed, %d failed", test_count, passed, failed))
--	if failed == 0 then
--		print("All tests passed!")
--	else
--		print("Some tests failed!")
--	end
--
--	return failed == 0
--end

-- Export
return {
	run_with_env = run_with_env,
	load_in_env = load_in_env,
	run_string = run_string,
}
