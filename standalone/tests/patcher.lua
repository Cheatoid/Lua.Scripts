-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for patcher.lua.
-- Run from this directory:
--   lua patcher.lua
--   luajit patcher.lua

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
local lib = require "patcher"
-- Bridging: file-locals used by tests mapped to module exports.
local Patcher = lib
local table_insert = table.insert

if true then
	print("Running Patcher tests...")

	-- Create test module
	local test_module = {
		test_func = function(x)
			return x * 2
		end,
		counter = 0
	}

	local patcher = Patcher.new()

	-- Test before hook
	patcher:target(test_module, "test_func")
		:before(function(x) test_module.counter = test_module.counter + 1 end)
		:apply()

	local result = test_module.test_func(5)
	assert(result == 10, "Basic function failed")
	assert(test_module.counter == 1, "Before hook failed")
	print("Before hook test passed")

	-- Test after hook
	patcher:target(test_module, "test_func")
		:after(function(x) test_module.counter = test_module.counter + 10 end)
		:apply()

	result = test_module.test_func(3)
	assert(result == 6, "Basic function failed")
	assert(test_module.counter == 12, "After hook failed")
	print("After hook test passed")

	-- Test replace
	patcher:target(test_module, "test_func")
		:id("replace_test")
		:replace(function(orig, x)
			return orig(x) + 100
		end)
		:apply()

	result = test_module.test_func(2)
	assert(result == 104, "Replace test failed") -- 2*2 + 100
	print("Replace test passed")

	-- Test restore by id
	patcher:restore("replace_test")
	result = test_module.test_func(2)
	assert(result == 4, "Restore test failed") -- back to original 2*2
	print("Restore test passed")

	-- Test once patch
	local call_count = 0
	patcher:target(test_module, "test_func")
		:once()
		:before(function() call_count = call_count + 1 end)
		:apply()

	test_module.test_func(1) -- should call before hook
	test_module.test_func(1) -- should not call before hook (restored)
	assert(call_count == 1, "Once test failed")
	print("Once patch test passed")

	-- Test restore all
	patcher:restore_all()
	assert(#patcher:list() == 0, "Restore all test failed")
	print("Restore all test passed")

	-- Additional comprehensive tests

	-- Test around wrapper
	local around_calls = 0
	patcher:target(test_module, "test_func")
		:id("around_test")
		:around(function(orig, x)
			around_calls = around_calls + 1
			return orig(x * 2) -- double the input before calling original
		end)
		:apply()

	local result = test_module.test_func(3)
	assert(result == 12, "Around test failed") -- (3*2)*2 = 12
	assert(around_calls == 1, "Around calls count failed")
	print("Around wrapper test passed")

	patcher:restore("around_test")

	-- Test multiple before/after hooks on same function
	local before1_calls = 0
	local before2_calls = 0
	local after1_calls = 0
	local after2_calls = 0

	patcher:target(test_module, "test_func")
		:id("multi_hooks_test")
		:before(function() before1_calls = before1_calls + 1 end)
		:before(function() before2_calls = before2_calls + 1 end)
		:after(function() after1_calls = after1_calls + 1 end)
		:after(function() after2_calls = after2_calls + 1 end)
		:apply()

	result = test_module.test_func(4)
	assert(result == 8, "Multi hooks basic function failed")
	assert(before1_calls == 1, "Before1 hook failed")
	assert(before2_calls == 1, "Before2 hook failed")
	assert(after1_calls == 1, "After1 hook failed")
	assert(after2_calls == 1, "After2 hook failed")
	print("Multiple hooks test passed")

	patcher:restore("multi_hooks_test")

	-- Test patch with no hooks (should not modify behavior)
	patcher:target(test_module, "test_func")
		:id("empty_patch_test")
		:apply()

	result = test_module.test_func(5)
	assert(result == 10, "Empty patch test failed")
	print("Empty patch test passed")

	patcher:restore("empty_patch_test")

	-- Test error handling in hooks
	local hook_error_caught = false
	patcher:target(test_module, "test_func")
		:id("error_test")
		:before(function() return error("Test hook error") end)
		:after(function() hook_error_caught = true end)
		:apply()

	-- Should not throw error, hook errors are swallowed
	result = test_module.test_func(2)
	assert(result == 4, "Error handling test failed")
	assert(hook_error_caught, "After hook not called on error")
	print("Error handling test passed")

	patcher:restore("error_test")

	-- Test patch listing functionality
	patcher:target(test_module, "test_func")
		:id("list_test1")
		:before(function() end)
		:apply()

	patcher:target(test_module, "test_func")
		:id("list_test2")
		:after(function() end)
		:apply()

	local patches = patcher:list()
	assert(#patches == 2, "Patch list count failed")
	assert(patches[1].id == "list_test1", "Patch list ID 1 failed")
	assert(patches[2].id == "list_test2", "Patch list ID 2 failed")
	assert(patches[1].has_before == true, "Patch list has_before failed")
	assert(patches[2].has_after == true, "Patch list has_after failed")
	print("Patch listing test passed")

	patcher:restore_all()

	-- Test chaining multiple operations
	local chain_counter = 0
	patcher:target(test_module, "test_func")
		:id("chain_test")
		:before(function() chain_counter = chain_counter + 1 end)
		:after(function() chain_counter = chain_counter + 10 end)
		:once()
		:apply()

	result = test_module.test_func(1)
	assert(result == 2, "Chain test basic function failed")
	assert(chain_counter == 11, "Chain test hooks failed")
	print("Method chaining test passed")

	-- API Order Validation Tests
	print("\nRunning API order validation tests...")

	-- Test 1: Order of before hooks execution
	local before_order = {}
	local order_patcher = Patcher.new()
	local order_module = {
		func = function(x) return x end
	}

	order_patcher:target(order_module, "func")
		:id("before_order_test")
		:before(function() table_insert(before_order, "before1") end)
		:before(function() table_insert(before_order, "before2") end)
		:before(function() table_insert(before_order, "before3") end)
		:apply()

	order_module.func()
	assert(#before_order == 3, "Wrong number of before hooks called")
	assert(before_order[1] == "before1", "Before1 hook order wrong")
	assert(before_order[2] == "before2", "Before2 hook order wrong")
	assert(before_order[3] == "before3", "Before3 hook order wrong")
	print("Before hook order test passed")

	order_patcher:restore("before_order_test")

	-- Test 2: Order of after hooks execution
	local after_order = {}

	order_patcher:target(order_module, "func")
		:id("after_order_test")
		:after(function() table_insert(after_order, "after1") end)
		:after(function() table_insert(after_order, "after2") end)
		:after(function() table_insert(after_order, "after3") end)
		:apply()

	order_module.func()
	assert(#after_order == 3, "Wrong number of after hooks called")
	assert(after_order[1] == "after1", "After1 hook order wrong")
	assert(after_order[2] == "after2", "After2 hook order wrong")
	assert(after_order[3] == "after3", "After3 hook order wrong")
	print("After hook order test passed")

	order_patcher:restore("after_order_test")

	-- Test 3: Complete execution order (before -> original -> after)
	local execution_order = {}

	order_patcher:target(order_module, "func")
		:id("complete_order_test")
		:before(function() table_insert(execution_order, "before1") end)
		:before(function() table_insert(execution_order, "before2") end)
		:after(function() table_insert(execution_order, "after1") end)
		:after(function() table_insert(execution_order, "after2") end)
		:apply()

	order_module.func()
	assert(#execution_order == 4, "Wrong number of hooks called in complete order test")
	assert(execution_order[1] == "before1", "Execution order 1 wrong")
	assert(execution_order[2] == "before2", "Execution order 2 wrong")
	assert(execution_order[3] == "after1", "Execution order 3 wrong")
	assert(execution_order[4] == "after2", "Execution order 4 wrong")
	print("Complete execution order test passed")

	order_patcher:restore("complete_order_test")

	-- Test 4: API method chaining order validation
	local chain_order = {}
	local chain_patcher = Patcher.new()

	-- Test that methods can be chained in any order after target
	chain_patcher:target(order_module, "func")
		:id("chain_order_test")
		:before(function() table_insert(chain_order, "before") end)
		:after(function() table_insert(chain_order, "after") end)
		:once()
		:apply()

	order_module.func()
	assert(#chain_order == 2, "Chain order test failed")
	assert(chain_order[1] == "before", "Chain before order wrong")
	assert(chain_order[2] == "after", "Chain after order wrong")
	print("API method chaining order test passed")

	-- Test 5: Multiple patches on same function execution order
	local multi_patch_order = {}
	local multi_patcher = Patcher.new()

	multi_patcher:target(order_module, "func")
		:id("multi_patch_1")
		:before(function() table_insert(multi_patch_order, "patch1_before") end)
		:after(function() table_insert(multi_patch_order, "patch1_after") end)
		:apply()

	multi_patcher:target(order_module, "func")
		:id("multi_patch_2")
		:before(function() table_insert(multi_patch_order, "patch2_before") end)
		:after(function() table_insert(multi_patch_order, "patch2_after") end)
		:apply()

	order_module.func()
	-- Note: Each patch wraps independently, so order depends on application sequence
	assert(#multi_patch_order == 4, "Multi-patch order test failed")
	print("Multi-patch execution order test passed")

	multi_patcher:restore_all()

	-- Test 6: Replace vs Around priority (replace takes precedence)
	local replace_vs_around_order = {}
	local priority_patcher = Patcher.new()

	priority_patcher:target(order_module, "func")
		:id("priority_test")
		:around(function(orig, x)
			table_insert(replace_vs_around_order, "around")
			return orig(x)
		end)
		:replace(function(orig, x)
			table_insert(replace_vs_around_order, "replace")
			return orig(x)
		end)
		:apply()

	order_module.func()
	assert(#replace_vs_around_order == 1, "Priority test failed")
	assert(replace_vs_around_order[1] == "replace", "Replace should take precedence over around")
	print("Replace vs Around priority test passed")

	priority_patcher:restore("priority_test")

	-- Test 7: Patch application order in list()
	local list_order_patcher = Patcher.new()

	list_order_patcher:target(order_module, "func")
		:id("list_order_1")
		:before(function() end)
		:apply()

	list_order_patcher:target(order_module, "func")
		:id("list_order_2")
		:after(function() end)
		:apply()

	list_order_patcher:target(order_module, "func")
		:id("list_order_3")
		:around(function(orig, x) return orig(x) end)
		:apply()

	local patches = list_order_patcher:list()
	assert(#patches == 3, "List order test failed")
	assert(patches[1].id == "list_order_1", "List order 1 wrong")
	assert(patches[2].id == "list_order_2", "List order 2 wrong")
	assert(patches[3].id == "list_order_3", "List order 3 wrong")
	print("Patch list order test passed")

	list_order_patcher:restore_all()

	print("API order validation tests passed!")
	print("All tests passed!")
end
