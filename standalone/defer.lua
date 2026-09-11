-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

--- Deferred-cleanup helper.
---
--- Lua 5.4+: use the returned handle in a to-be-closed local:
--- ```
--- local cleanup <close> = Defer.defer(fn, arg)
--- ```
---
--- Older Lua versions cannot portably create a finalizable userdata from pure Lua.
--- This module uses `newproxy` when the host provides it; otherwise handles are
--- manual-only and must be completed with `run_now` or `cancel`.
local Defer = {}

-- Localized global functions for better performance
local assert = assert
local collectgarbage = collectgarbage
local getmetatable = getmetatable
local load = load
local loadstring = loadstring
local newproxy = newproxy
local type = type
local table_unpack = table.unpack or unpack

local table_pack = table.pack or function(...)
	return { n = select("#", ...), ... }
end

----------------------------------------------------------------------
-- Detect Lua 5.4 <close> support
----------------------------------------------------------------------

--- Detect Lua 5.4 to-be-closed support by trial compilation.<br>
--- Attempts to compile `<close>` syntax with available loader.
---@return boolean supported True when `<close>` is supported.
---@return string? err Loader error when unsupported.
local function detect_close_support()
	local loader = load or loadstring
	if type(loader) ~= "function" then
		return false
	end

	-- The correct Lua 5.4 syntax is `local name <close> = value`.
	local chunk, err = loader("local value <close> = {}\nreturn value")
	return chunk ~= nil, err
end

local HAS_CLOSE = detect_close_support()

----------------------------------------------------------------------
-- Forward declarations
----------------------------------------------------------------------

local close_mt
local gc_mt
local manual_mt

-- Weak table for proxy -> state mapping
local proxy_states = setmetatable({}, { __mode = "k" })

--- Opaque cleanup token completed by scope exit, GC, or manually.
---@class Defer.Handle
---@field _state table State table holding callback and flags.
---@field _mode "close"|"gc"|"manual" Backend mode selecting finalizer.
---@field _tag? string Optional diagnostic tag.
---@field _proxy? userdata GC anchor when mode is `gc`.

--- Assert handle was created by Defer and return state.<br>
--- Errors when table or metatable is invalid.
---@param handle table handle The handle to validate.
---@param operation string operation The operation name for errors.
---@return table state The handle internal state table.
local function assert_handle(handle, operation)
	assert(type(handle) == "table", operation .. ": invalid handle")
	local mt = getmetatable(handle)
	assert(mt == close_mt or mt == gc_mt or mt == manual_mt,
		operation .. ": handle was not created by Defer")
	return handle._state
end

----------------------------------------------------------------------
-- State management
----------------------------------------------------------------------

--- Invoke callback once and clear state.<br>
--- Marks state done before calling function.
---@param state table state The internal state table.
---@return any result Callback return value, if any.
local function release(state)
	local fn = state.fn
	local args = state.args
	state.done = true
	state.fn = nil
	state.args = nil

	if fn ~= nil then
		return fn(table_unpack(args, 1, args.n))
	end
end

--- Mark state done without invoking callback.<br>
--- Clears function and arguments.
---@param state table state The internal state table.
local function cancel_state(state)
	state.done = true
	state.fn = nil
	state.args = nil
end

--- Run cleanup once unless already done.<br>
--- Delegates to release when state is pending.
---@param state table state The internal state table.
---@return any result Callback return value, if any.
local function finalize(state)
	if not state.done then
		return release(state)
	end
end

----------------------------------------------------------------------
-- Finalizers
----------------------------------------------------------------------

--- To-be-closed finalizer invoking pending cleanup.<br>
--- Returns original error for `__close` propagation.
---@param self Defer.Handle handle The handle being closed.
---@param err any error The close error value.
---@return any error The original error value.
local function close_finalizer(self, err)
	local state = self._state
	if state ~= nil then
		finalize(state)
	end
	return err
end

--- Garbage-collection finalizer invoking pending cleanup.<br>
--- Clears proxy mapping before finalizing state.
---@param proxy userdata proxy The collected proxy object.
local function gc_finalizer(proxy)
	local state = proxy_states[proxy]
	if state ~= nil then
		proxy_states[proxy] = nil
		finalize(state)
	end
end

--- Create fresh internal state table.<br>
--- Initializes done flag as false.
---@param fn function callback The cleanup function.
---@param args table args Packed callback arguments.
---@param tag? string tag Optional diagnostic tag.
---@return table state New internal state table.
local function make_state(fn, args, tag)
	return { fn = fn, args = args, tag = tag, done = false }
end

----------------------------------------------------------------------
-- Handle methods
----------------------------------------------------------------------

local methods = {}

--- Run cleanup now and return result.<br>
--- Safe to call once; finalizer becomes no-op after.
---@return any result Callback return value, if any.
function methods:run_now()
	local state = assert_handle(self, "Defer.Handle:run_now")
	return finalize(state)
end

--- Cancel cleanup without invoking callback.<br>
--- Marks handle done and clears function.
function methods:cancel()
	local state = assert_handle(self, "Defer.Handle:cancel")
	cancel_state(state)
end

--- Check whether handle already ran or was cancelled.
---@return boolean done True when run or cancelled.
function methods:is_done()
	local state = assert_handle(self, "Defer.Handle:is_done")
	return state.done
end

--- Get handle diagnostic tag.
---@return string? tag Optional tag, or nil when untagged.
function methods:tag()
	local state = assert_handle(self, "Defer.Handle:tag")
	return state.tag
end

----------------------------------------------------------------------
-- Backend metatables
----------------------------------------------------------------------

close_mt  = { __index = methods, __close = close_finalizer }
gc_mt     = { __index = methods }
manual_mt = { __index = methods }

----------------------------------------------------------------------
-- Handle constructor
----------------------------------------------------------------------

--- Create handle using best available backend.<br>
--- Prefers `<close>`, then `newproxy` GC, then manual.
---@param fn function callback The cleanup function.
---@param args table args Packed callback arguments.
---@param tag? string tag Optional diagnostic tag.
---@return Defer.Handle handle New handle table.
local function new_handle(fn, args, tag)
	local state = make_state(fn, args, tag)

	if HAS_CLOSE then
		return setmetatable({ _state = state, _mode = "close", _tag = tag }, close_mt)
	end

	if type(newproxy) == "function" then
		local proxy = newproxy(true)
		local proxy_metatable = getmetatable(proxy)
		proxy_metatable.__gc = gc_finalizer
		proxy_states[proxy] = state
		return setmetatable({ _state = state, _proxy = proxy, _mode = "gc", _tag = tag }, gc_mt)
	end

	return setmetatable({ _state = state, _mode = "manual", _tag = tag }, manual_mt)
end

----------------------------------------------------------------------
-- Public API
----------------------------------------------------------------------

--- Create a deferred cleanup action.<br>
--- Use with to-be-closed local on Lua 5.4; manual otherwise.<br>
--- Runs callback once on scope exit, `run_now`, or GC.
---@param fn fun(...: any) callback The cleanup function.
---@param ... any args Additional callback arguments.
---@return Defer.Handle handle New handle table.
---@usage <br>
--- ```
--- local cleanup <close> = Defer.defer(fn, arg)
--- ```
function Defer.defer(fn, ...)
	assert(type(fn) == "function", "Defer.defer: fn must be a function")
	return new_handle(fn, table_pack(...), nil)
end

--- Create a tagged deferred cleanup action.<br>
--- Tag aids debugging; behavior matches `defer`.
---@param tag string tag Diagnostic tag string.
---@param fn fun(...: any) callback The cleanup function.
---@param ... any args Additional callback arguments.
---@return Defer.Handle handle New handle table.
---@usage <br>
--- ```
--- local cleanup <close> = Defer.defer_tagged("conn", fn, arg)
--- ```
function Defer.defer_tagged(tag, fn, ...)
	assert(type(tag) == "string", "Defer.defer_tagged: tag must be a string")
	assert(type(fn) == "function", "Defer.defer_tagged: fn must be a function")
	return new_handle(fn, table_pack(...), tag)
end

--- Run cleanup exactly once and return result.<br>
--- Finalizer becomes no-op after manual run.
---@param handle Defer.Handle handle The handle to run.
---@return any result Callback return value, if any.
function Defer.run_now(handle)
	return methods.run_now(handle)
end

--- Cancel cleanup without invoking callback.<br>
--- Marks handle done and clears function.
---@param handle Defer.Handle handle The handle to cancel.
function Defer.cancel(handle)
	return methods.cancel(handle)
end

--- Check whether handle already ran or was cancelled.
---@param handle Defer.Handle handle The handle to check.
---@return boolean done True when run or cancelled.
function Defer.is_done(handle)
	return methods.is_done(handle)
end

--- Get handle diagnostic tag.
---@param handle Defer.Handle handle The handle to inspect.
---@return string? tag Optional tag, or nil when untagged.
function Defer.get_tag(handle)
	return methods.tag(handle)
end

--- Force a full garbage-collection cycle.<br>
--- Only useful for `gc` backend testing.
---@return any result Collector result, if any.
function Defer.collect()
	return collectgarbage("collect"), collectgarbage("collect")
end

--- Check Lua to-be-closed local support.
---@return boolean supported True when `<close>` is supported.
function Defer.has_close()
	return HAS_CLOSE
end

--- Get handle backend mode.<br>
--- Returns `close`, `gc`, or `manual`.
---@param handle Defer.Handle handle The handle to inspect.
---@return "close"|"gc"|"manual" mode Backend mode string.
function Defer.mode(handle)
	local state = assert_handle(handle, "Defer.mode")
	return state and handle._mode
end

-- Export
return Defer
