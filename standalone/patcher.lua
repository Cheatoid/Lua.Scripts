-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Monkey patching (hooking library) for Lua

-- TODO: Optimize...

-- Localized global functions for better performance
local assert = assert
local error = error
local ipairs = ipairs
local pcall = pcall
local select = select
local setmetatable = setmetatable
local type = type
local table_insert = table.insert
local table_pack = table.pack or function(...) return { n = select("#", ...), ... } end
local table_remove = table.remove
local table_unpack = table.unpack or unpack

---@class Patcher
---@field patches table Array of patch contexts.
---@field _current? table Current patch context being built.
local Patcher = {}
Patcher.__index = Patcher

--- Create a new Patcher manager.
---@return Patcher instance A new Patcher instance.
function Patcher.new()
	return setmetatable({ patches = {} }, Patcher)
end

--- Select a function to patch on a table (or module).<br>
--- This begins a fluent chain. Must call :apply() to install.
---@param tbl table The table or module containing the function.
---@param key string The key name of the function to patch.
---@return Patcher self Self for chaining.
function Patcher:target(tbl, key)
	assert(type(tbl) == "table" or type(tbl) == "userdata", "target must be table/userdata")
	local orig = tbl[key]
	assert(type(orig) == "function", "target must be a function")
	---@class PatchContext
	---@field tbl table The target table containing the function.
	---@field key string The key name of the function.
	---@field orig function The original function.
	---@field befores table Array of before hook functions.
	---@field afters table Array of after hook functions.
	---@field around? function Around wrapper function.
	---@field replace? function Replacement function.
	---@field once boolean Whether patch applies only once.
	---@field id? string Optional identifier for grouping.
	---@field applied boolean Whether patch has been applied.
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
		applied = false,
	}
	table_insert(self.patches, ctx)
	self._current = ctx
	return self
end

--- Label the current patch for grouped restore.
---@param name string Identifier for grouping patches
---@return Patcher self
function Patcher:id(name)
	assert(self._current, "no current patch; call :target first")
	self._current.id = name
	return self
end

--- Add a before hook. Called with the same args as the original.
---@param fn function
---@return Patcher self
function Patcher:before(fn)
	assert(self._current, "no current patch; call :target first")
	assert(type(fn) == "function", "before expects a function")
	table_insert(self._current.befores, fn)
	return self
end

--- Add an after hook. Called with the same args as the original.
---@param fn function
---@return Patcher self
function Patcher:after(fn)
	assert(self._current, "no current patch; call :target first")
	assert(type(fn) == "function", "after expects a function")
	table_insert(self._current.afters, fn)
	return self
end

--- Provide an around wrapper. Signature: around(orig, ...).<br>
--- The around function is responsible for calling orig(...) if desired.
---@param fn function
---@return Patcher self
function Patcher:around(fn)
	assert(self._current, "no current patch; call :target first")
	assert(type(fn) == "function", "around expects a function")
	self._current.around = fn
	return self
end

--- Replace the original with a replacement. Signature: replace(orig, ...).<br>
--- Replacement receives the original as first arg so it can delegate.
---@param fn function
---@return Patcher self
function Patcher:replace(fn)
	assert(self._current, "no current patch; call :target first")
	assert(type(fn) == "function", "replace expects a function")
	self._current.replace = fn
	return self
end

--- Make the patch apply only once; after the first call the original is restored.
---@return Patcher self
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

--- Apply all configured patches (install wrappers).<br>
--- Idempotent: re-applying an already applied patch does nothing.
---@return Patcher self
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
---@param id? string Optional identifier to restore a group.
---@return Patcher self
function Patcher:restore(id)
	for i = #self.patches, 1, -1 do -- important: reverse iteration due to table.remove
		local ctx = self.patches[i]
		if not id or ctx.id == id then
			-- restore original function
			ctx.tbl[ctx.key] = ctx.orig
			table_remove(self.patches, i)
		end
	end
	return self
end

--- Restore all patches and clear manager.
---@return Patcher self
function Patcher:restore_all()
	for i = #self.patches, 1, -1 do -- important: reverse iteration due to table.remove
		local ctx = self.patches[i]
		ctx.tbl[ctx.key] = ctx.orig
		table_remove(self.patches, i)
	end
	return self
end

--- Return a shallow copy of current patch descriptors (for introspection).
---@return table array Array of patch descriptors.
function Patcher:list()
	local out = {}
	local patches = self.patches
	for i = 1, #patches do
		local ctx = patches[i]
		out[i] = {
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

-- Export
return Patcher
