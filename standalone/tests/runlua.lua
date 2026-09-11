-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for runlua.lua.
-- Run from this directory:
--   lua runlua.lua
--   luajit runlua.lua

-- Bootstrap: make requires work from tests/ subdir with plain lua/luajit.
do
	local src = debug.getinfo(1, "S").source
	local dir = src:match("^@(.+/)[^/]+$") or "./"
	local function isfile(p)
		local f = io.open(p, "r")
		if f then
			f:close()
			return true
		end
		return false
	end
	local root
	for _, c in ipairs({ dir, dir .. "../", dir .. "../..//", dir .. "../../..//", "./", "../", "../../" }) do
		if isfile(c .. "standalone/bits.lua") then
			root = c
			break
		end
	end
	root = root or dir .. "../"
	if package then
		package.path = dir ..
			"../?.lua;" ..
			dir ..
			"../?/init.lua;" ..
			dir ..
			"?.lua;" ..
			dir ..
			"?/init.lua;" ..
			root ..
			"?.lua;" ..
			root ..
			"?/init.lua;" ..
			root ..
			"standalone/?.lua;" ..
			root ..
			"math/?.lua;" ..
			root ..
			"collections/?.lua;" ..
			root ..
			"benchmark/?.lua;" ..
			root ..
			"timer/?.lua;" ..
			root ..
			"autocompleter/?.lua;" ..
			root ..
			"permission/?.lua;" ..
			root ..
			"chat_commander/?.lua;" ..
			root .. "vm/?.lua;" .. root .. "require_finder/?.lua;" .. root .. "inventory/?.lua;" .. package.path
	end
	local searchers = package.searchers or package.loaders
	if searchers then
		table.insert(searchers, 2, function(mod)
			if mod:sub(1, 3) == "../" or mod:sub(1, 2) == "./" then
				local clean = mod:gsub("^%./", ""):gsub("^%.%.%/", ""):gsub("^%.%.%/", "")
				local tries = { dir .. "../" .. clean .. ".lua", dir .. "../" .. clean .. "/init.lua", root ..
				clean .. ".lua", root .. clean .. "/init.lua" }
				for _, f in ipairs(tries) do
					if isfile(f) then
						local chunk, err = loadfile(f)
						if chunk then return chunk, f end
					end
				end
			end
			return nil
		end)
	end
end
local lib = require "runlua"
-- Bridging: file-locals used by tests mapped to module exports.
local run_isolated = lib.run_isolated
-- TODO(manual): the following were file-locals with no direct export;
-- verify and export or inline as needed: name

if true then
	-- Test 1: Basic string execution
	print("\n1. Basic string execution:")
	local code_str = "return 'Hello from ' .. _VERSION, my_var * 2"
	local my_env = setmetatable({ my_var = 21 }, { __index = _G })
	local ok, val1, val2 = run_isolated(code_str, my_env)
	assert(ok, "String execution should succeed")
	assert(type(val1) == "string", "First return should be string")
	assert(val2 == 42, "Second return should be 42")
	print("String execution:", ok, val1, val2)

	-- Test 2: Function execution
	print("\n2. Function execution:")
	local function user_func()
		return "Global access check: " .. tostring(print)
	end
	local ok, res = run_isolated(user_func)
	assert(ok, "Function execution should succeed")
	assert(type(res) == "string", "Function should return string")
	print("Function execution:", ok, res)

	-- Test 3: Syntax error handling
	print("\n3. Syntax error handling:")
	local bad_code = "return 1 + + 2" -- Invalid syntax
	local ok, err = run_isolated(bad_code)
	assert(not ok, "Syntax error should fail")
	assert(type(err) == "string", "Error should be string")
	print("Syntax error properly caught:", ok, err)

	-- Test 4: Runtime error handling
	print("\n4. Runtime error handling:")
	local runtime_error_code = "return nil.method()"
	local ok, err = run_isolated(runtime_error_code)
	assert(not ok, "Runtime error should fail")
	assert(type(err) == "string", "Error should be string")
	print("Runtime error properly caught:", ok, err)

	-- Test 5: Invalid input type
	print("\n5. Invalid input type:")
	local ok, err = run_isolated(123) -- Number instead of string/function
	assert(not ok, "Invalid input should fail")
	assert(err == "input must be a string or function", "Should return specific error")
	print("Invalid input properly rejected:", ok, err)

	-- Test 6: Sandbox isolation test
	print("\n6. Sandbox isolation test:")
	local sandbox = { x = 10 }
	setmetatable(sandbox, { __index = _G })
	local isolation_code = "x = x + 5; return x"
	local ok, result = run_isolated(isolation_code, sandbox)
	assert(ok, "Isolation should succeed")
	assert(result == 15, "Should compute x + 5 = 15")
	-- Note: When sandbox is passed directly, it gets modified. This is expected behavior.
	assert(sandbox.x == 15, "Sandbox should be modified when used as environment")
	print("Sandbox isolation working:", ok, result, "sandbox.x:", sandbox.x)

	-- Test 7: No sandbox (default behavior)
	print("\n7. Default sandbox behavior:")
	local default_code = "return _VERSION"
	local ok, result = run_isolated(default_code)
	assert(ok, "Default sandbox should work")
	assert(result == _VERSION, "Should return Lua version")
	print("Default sandbox:", ok, result)

	-- Test 8: Multiple return values
	print("\n8. Multiple return values:")
	local multi_return_code = "return 1, 2, 3, 'four', true"
	local ok, r1, r2, r3, r4, r5 = run_isolated(multi_return_code)
	assert(ok, "Multi-return should succeed")
	assert(r1 == 1 and r2 == 2 and r3 == 3, "Numbers should match")
	assert(r4 == "four", "String should match")
	assert(r5 == true, "Boolean should match")
	print("Multi-return:", ok, r1, r2, r3, r4, r5)

	-- Test 9: Chunk name for error reporting
	print("\n9. Chunk name test:")
	local named_code = "return unknown_variable.method()"
	local ok, err = run_isolated(named_code, nil, "test_chunk")
	assert(not ok, "Unknown variable method call should fail")
	assert(type(err) == "string", "Error should be string")
	print("Chunk name test:", ok, err)

	-- Test 10: Security test (preventing global pollution)
	print("\n10. Security test (global pollution):")
	local security_code = "global_test_var = 'should not pollute'"
	local ok, result = run_isolated(security_code)
	assert(ok, "Assignment should succeed in sandbox")
	assert(_G.global_test_var == nil, "Global should not be polluted")
	print("Security test passed:", ok, result, "global_test_var exists:", _G.global_test_var ~= nil)

	-- Test 11: Function with upvalues
	print("\n11. Function with upvalues:")
	local outer_var = "outer"
	local function closure_func()
		return "Closure: " .. outer_var
	end
	local ok, result = run_isolated(closure_func)
	assert(ok, "Closure execution should succeed")
	assert(result == "Closure: outer", "Should access upvalue")
	print("Closure test:", ok, result)

	-- Test 12: Complex sandbox with restricted access
	print("\n12. Restricted sandbox test:")
	local restricted_env = {
		safe_print = print,
		math = math,
		string = string
	}
	-- No __index metatable, so no access to other globals
	local restricted_code = "return safe_print('Hello'), math.sqrt(9)"
	local ok, result = run_isolated(restricted_code, restricted_env)
	assert(ok, "Restricted execution should succeed")
	print("Restricted test:", ok, result)

	print("\nAll tests passed!")
end
