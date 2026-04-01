-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Monkey patching for Lua.

-- TODO: Optimize...

-- Localized global functions for better performance
local assert = assert
local error = error
local ipairs = ipairs
local pcall = pcall
local setmetatable = setmetatable
local type = type
local table_insert = table.insert
local table_pack = table.pack or function(...)
	return { n = select("#", ...), ... }
end
local table_remove = table.remove
local table_unpack = table.unpack or unpack

---@class Patcher
---@field patches table Array of patch contexts
---@field _current table|nil Current patch context being built
local Patcher = {}
Patcher.__index = Patcher

--- Create a new Patcher manager.
--- @return Patcher instance A new Patcher instance.
function Patcher.new()
	return setmetatable({ patches = {} }, Patcher)
end

--- Select a function to patch on a table (or module).
--- This begins a fluent chain. Must call :apply() to install.
--- @param tbl table The table or module containing the function.
--- @param key string The key name of the function to patch.
--- @return Patcher self Self for chaining.
function Patcher:target(tbl, key)
	assert(type(tbl) == "table" or type(tbl) == "userdata", "target must be table/userdata")
	local orig = tbl[key]
	assert(type(orig) == "function", "target must be a function")
	---@class PatchContext
	---@field tbl table The target table containing the function
	---@field key string The key name of the function
	---@field orig function The original function
	---@field befores table Array of before hook functions
	---@field afters table Array of after hook functions
	---@field around function|nil Around wrapper function
	---@field replace function|nil Replacement function
	---@field once boolean Whether patch applies only once
	---@field id string|nil Optional identifier for grouping
	---@field applied boolean Whether patch has been applied
	local ctx = {
		tbl = tbl,
		key = key,
		orig = orig,
		befores = {},
		afters = {},
		around = nil,
		replace = nil,
		once = false,
		id = nil,
		applied = false
	}
	table_insert(self.patches, ctx)
	self._current = ctx
	return self
end

--- Label the current patch for grouped restore.
--- @param name string Identifier for grouping patches
--- @return Patcher self
function Patcher:id(name)
	assert(self._current, "no current patch; call :target first")
	self._current.id = name
	return self
end

--- Add a before hook. Called with the same args as the original.
--- @param fn function
--- @return Patcher self
function Patcher:before(fn)
	assert(self._current, "no current patch; call :target first")
	assert(type(fn) == "function", "before expects a function")
	table_insert(self._current.befores, fn)
	return self
end

--- Add an after hook. Called with the same args as the original.
--- @param fn function
--- @return Patcher self
function Patcher:after(fn)
	assert(self._current, "no current patch; call :target first")
	assert(type(fn) == "function", "after expects a function")
	table_insert(self._current.afters, fn)
	return self
end

--- Provide an around wrapper. Signature: around(orig, ...).
--- The around function is responsible for calling orig(...) if desired.
--- @param fn function
--- @return Patcher self
function Patcher:around(fn)
	assert(self._current, "no current patch; call :target first")
	assert(type(fn) == "function", "around expects a function")
	self._current.around = fn
	return self
end

--- Replace the original with a replacement. Signature: replace(orig, ...).
--- Replacement receives the original as first arg so it can delegate.
--- @param fn function
--- @return Patcher self
function Patcher:replace(fn)
	assert(self._current, "no current patch; call :target first")
	assert(type(fn) == "function", "replace expects a function")
	self._current.replace = fn
	return self
end

--- Make the patch apply only once; after the first call the original is restored.
--- @return Patcher self
function Patcher:once()
	assert(self._current, "no current patch; call :target first")
	self._current.once = true
	return self
end

--- Internal helper: call a function and ignore its return values.
local function safe_call_void(f, ...)
	local ok, _ = pcall(f, ...)
	if not ok then
		-- swallow hook errors to avoid breaking the host function; rethrowing is optional
	end
end

--- Internal helper: call a function and return all results or rethrow error.
local function safe_call_return(f, ...)
	local results = table_pack(pcall(f, ...))
	local ok = results[1]
	if not ok then
		return error(results[2])
	end
	-- remove pcall boolean
	results[1] = nil
	return table_unpack(results, 2, results.n)
end

--- Apply all configured patches (install wrappers).
--- Idempotent: re-applying an already applied patch does nothing.
--- @return Patcher self
function Patcher:apply()
	for _, ctx in ipairs(self.patches) do
		if not ctx.applied then
			local wrapper
			if ctx.replace then
				-- replacement receives original as first arg
				wrapper = function(...)
					if ctx.once then
						-- restore original before calling replacement to ensure single-use semantics
						ctx.tbl[ctx.key] = ctx.orig
						ctx.applied = false
					end
					return safe_call_return(ctx.replace, ctx.orig, ...)
				end
			elseif ctx.around then
				wrapper = function(...)
					if ctx.once then
						ctx.tbl[ctx.key] = ctx.orig
						ctx.applied = false
					end
					return safe_call_return(ctx.around, ctx.orig, ...)
				end
			else
				wrapper = function(...)
					-- run befores (errors swallowed)
					for _, b in ipairs(ctx.befores) do
						safe_call_void(b, ...)
					end
					-- call original and capture results or rethrow
					local results = table_pack(pcall(ctx.orig, ...))
					local ok = results[1]
					if not ok then
						-- run afters even on error? we choose not to; rethrow
						return error(results[2])
					end
					-- run afters (errors swallowed)
					for _, a in ipairs(ctx.afters) do
						safe_call_void(a, ...)
					end
					if ctx.once then
						ctx.tbl[ctx.key] = ctx.orig
						ctx.applied = false
					end
					-- return original results (strip pcall boolean)
					return table_unpack(results, 2, results.n)
				end
			end
			ctx.tbl[ctx.key] = wrapper
			ctx.applied = true
		end
	end
	return self
end

--- Restore patches. If id is provided, only patches with that id are restored.
--- @param id string|nil Optional id to restore a group
--- @return Patcher self
function Patcher:restore(id)
	for i = #self.patches, 1, -1 do
		local ctx = self.patches[i]
		if not id or ctx.id == id then
			-- restore original function
			ctx.tbl[ctx.key] = ctx.orig
			table_remove(self.patches, i)
		end
	end
	return self
end

--- Convenience: restore all patches and clear manager.
--- @return Patcher self
function Patcher:restore_all()
	for i = #self.patches, 1, -1 do
		local ctx = self.patches[i]
		ctx.tbl[ctx.key] = ctx.orig
		table_remove(self.patches, i)
	end
	return self
end

--- Return a shallow copy of current patch descriptors (for introspection).
--- @return table array of patch descriptors
function Patcher:list()
	local out = {}
	for _, ctx in ipairs(self.patches) do
		out[#out + 1] = {
			tbl = ctx.tbl,
			key = ctx.key,
			id = ctx.id,
			applied = ctx.applied,
			once = ctx.once,
			has_before = #ctx.befores > 0,
			has_after = #ctx.afters > 0,
			has_around = ctx.around ~= nil,
			has_replace = ctx.replace ~= nil,
		}
	end
	return out
end

-- Quick tests
--if true then
--	print("Running Patcher tests...")
--
--	-- Create test module
--	local test_module = {
--		test_func = function(x)
--			return x * 2
--		end,
--		counter = 0
--	}
--
--	local patcher = Patcher.new()
--
--	-- Test before hook
--	patcher:target(test_module, "test_func")
--			:before(function(x) test_module.counter = test_module.counter + 1 end)
--			:apply()
--
--	local result = test_module.test_func(5)
--	assert(result == 10, "Basic function failed")
--	assert(test_module.counter == 1, "Before hook failed")
--	print("Before hook test passed")
--
--	-- Test after hook
--	patcher:target(test_module, "test_func")
--			:after(function(x) test_module.counter = test_module.counter + 10 end)
--			:apply()
--
--	result = test_module.test_func(3)
--	assert(result == 6, "Basic function failed")
--	assert(test_module.counter == 12, "After hook failed")
--	print("After hook test passed")
--
--	-- Test replace
--	patcher:target(test_module, "test_func")
--			:id("replace_test")
--			:replace(function(orig, x)
--				return orig(x) + 100
--			end)
--			:apply()
--
--	result = test_module.test_func(2)
--	assert(result == 104, "Replace test failed") -- 2*2 + 100
--	print("Replace test passed")
--
--	-- Test restore by id
--	patcher:restore("replace_test")
--	result = test_module.test_func(2)
--	assert(result == 4, "Restore test failed") -- back to original 2*2
--	print("Restore test passed")
--
--	-- Test once patch
--	local call_count = 0
--	patcher:target(test_module, "test_func")
--			:once()
--			:before(function() call_count = call_count + 1 end)
--			:apply()
--
--	test_module.test_func(1) -- should call before hook
--	test_module.test_func(1) -- should not call before hook (restored)
--	assert(call_count == 1, "Once test failed")
--	print("Once patch test passed")
--
--	-- Test restore all
--	patcher:restore_all()
--	assert(#patcher:list() == 0, "Restore all test failed")
--	print("Restore all test passed")
--
--	-- Additional comprehensive tests
--
--	-- Test around wrapper
--	local around_calls = 0
--	patcher:target(test_module, "test_func")
--			:id("around_test")
--			:around(function(orig, x)
--				around_calls = around_calls + 1
--				return orig(x * 2) -- double the input before calling original
--			end)
--			:apply()
--
--	local result = test_module.test_func(3)
--	assert(result == 12, "Around test failed") -- (3*2)*2 = 12
--	assert(around_calls == 1, "Around calls count failed")
--	print("Around wrapper test passed")
--
--	patcher:restore("around_test")
--
--	-- Test multiple before/after hooks on same function
--	local before1_calls = 0
--	local before2_calls = 0
--	local after1_calls = 0
--	local after2_calls = 0
--
--	patcher:target(test_module, "test_func")
--			:id("multi_hooks_test")
--			:before(function() before1_calls = before1_calls + 1 end)
--			:before(function() before2_calls = before2_calls + 1 end)
--			:after(function() after1_calls = after1_calls + 1 end)
--			:after(function() after2_calls = after2_calls + 1 end)
--			:apply()
--
--	result = test_module.test_func(4)
--	assert(result == 8, "Multi hooks basic function failed")
--	assert(before1_calls == 1, "Before1 hook failed")
--	assert(before2_calls == 1, "Before2 hook failed")
--	assert(after1_calls == 1, "After1 hook failed")
--	assert(after2_calls == 1, "After2 hook failed")
--	print("Multiple hooks test passed")
--
--	patcher:restore("multi_hooks_test")
--
--	-- Test patch with no hooks (should not modify behavior)
--	patcher:target(test_module, "test_func")
--			:id("empty_patch_test")
--			:apply()
--
--	result = test_module.test_func(5)
--	assert(result == 10, "Empty patch test failed")
--	print("Empty patch test passed")
--
--	patcher:restore("empty_patch_test")
--
--	-- Test error handling in hooks
--	local hook_error_caught = false
--	patcher:target(test_module, "test_func")
--			:id("error_test")
--			:before(function() error("Test hook error") end)
--			:after(function() hook_error_caught = true end)
--			:apply()
--
--	-- Should not throw error, hook errors are swallowed
--	result = test_module.test_func(2)
--	assert(result == 4, "Error handling test failed")
--	assert(hook_error_caught, "After hook not called on error")
--	print("Error handling test passed")
--
--	patcher:restore("error_test")
--
--	-- Test patch listing functionality
--	patcher:target(test_module, "test_func")
--			:id("list_test1")
--			:before(function() end)
--			:apply()
--
--	patcher:target(test_module, "test_func")
--			:id("list_test2")
--			:after(function() end)
--			:apply()
--
--	local patches = patcher:list()
--	assert(#patches == 2, "Patch list count failed")
--	assert(patches[1].id == "list_test1", "Patch list ID 1 failed")
--	assert(patches[2].id == "list_test2", "Patch list ID 2 failed")
--	assert(patches[1].has_before == true, "Patch list has_before failed")
--	assert(patches[2].has_after == true, "Patch list has_after failed")
--	print("Patch listing test passed")
--
--	patcher:restore_all()
--
--	-- Test chaining multiple operations
--	local chain_counter = 0
--	patcher:target(test_module, "test_func")
--			:id("chain_test")
--			:before(function() chain_counter = chain_counter + 1 end)
--			:after(function() chain_counter = chain_counter + 10 end)
--			:once()
--			:apply()
--
--	result = test_module.test_func(1)
--	assert(result == 2, "Chain test basic function failed")
--	assert(chain_counter == 11, "Chain test hooks failed")
--	print("Method chaining test passed")
--
--	print("All tests passed!")
--end

-- Export
return Patcher
