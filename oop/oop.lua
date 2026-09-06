--[[
╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗
║                                                                                                                  ║
║    OOP Class Library for Lua                                                                                     ║
║                                                                                                                  ║
║    A feature-rich object-oriented programming library for Lua with classes, inheritance, interfaces, mixins,     ║
║    properties, events, hooking, AOP, promises via coroutines, integrated profiler, and much more.                ║
║                                                                                                                  ║
║    ~ https://github.com/Cheatoid                                                                 License: MIT    ║
║                                                                                                                  ║
╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝
           ▄            ▄         ▄  ▄▄▄▄▄▄▄▄▄▄▄                 ▄▄▄▄▄▄▄▄▄▄▄  ▄▄▄▄▄▄▄▄▄▄▄  ▄▄▄▄▄▄▄▄▄▄▄
          ▐░▌          ▐░▌       ▐░▌▐░░░░░░░░░░░▌               ▐░░░░░░░░░░░▌▐░░░░░░░░░░░▌▐░░░░░░░░░░░▌
          ▐░▌          ▐░▌       ▐░▌▐░█▀▀▀▀▀▀▀█░▌               ▐░█▀▀▀▀▀▀▀█░▌▐░█▀▀▀▀▀▀▀█░▌▐░█▀▀▀▀▀▀▀█░▌
          ▐░▌          ▐░▌       ▐░▌▐░▌       ▐░▌               ▐░▌       ▐░▌▐░▌       ▐░▌▐░▌       ▐░▌
          ▐░▌          ▐░▌       ▐░▌▐░█▄▄▄▄▄▄▄█░▌               ▐░▌       ▐░▌▐░▌       ▐░▌▐░█▄▄▄▄▄▄▄█░▌
          ▐░▌          ▐░▌       ▐░▌▐░░░░░░░░░░░▌               ▐░▌       ▐░▌▐░▌       ▐░▌▐░░░░░░░░░░░▌
          ▐░▌          ▐░▌       ▐░▌▐░█▀▀▀▀▀▀▀█░▌               ▐░▌       ▐░▌▐░▌       ▐░▌▐░█▀▀▀▀▀▀▀▀▀
          ▐░▌          ▐░▌       ▐░▌▐░▌       ▐░▌               ▐░▌       ▐░▌▐░▌       ▐░▌▐░▌
          ▐░█▄▄▄▄▄▄▄▄▄ ▐░█▄▄▄▄▄▄▄█░▌▐░▌       ▐░▌               ▐░█▄▄▄▄▄▄▄█░▌▐░█▄▄▄▄▄▄▄█░▌▐░▌
          ▐░░░░░░░░░░░▌▐░░░░░░░░░░░▌▐░▌       ▐░▌               ▐░░░░░░░░░░░▌▐░░░░░░░░░░░▌▐░▌
           ▀▀▀▀▀▀▀▀▀▀▀  ▀▀▀▀▀▀▀▀▀▀▀  ▀         ▀                 ▀▀▀▀▀▀▀▀▀▀▀  ▀▀▀▀▀▀▀▀▀▀▀  ▀

      ▄▄▄▄▄▄▄▄▄▄▄  ▄         ▄  ▄▄▄▄▄▄▄▄▄▄▄  ▄▄▄▄▄▄▄▄▄▄▄  ▄▄▄▄▄▄▄▄▄▄▄  ▄▄▄▄▄▄▄▄▄▄▄  ▄▄▄▄▄▄▄▄▄▄▄  ▄▄▄▄▄▄▄▄▄
     ▐░░░░░░░░░░░▌▐░▌       ▐░▌▐░░░░░░░░░░░▌▐░░░░░░░░░░░▌▐░░░░░░░░░░░▌▐░░░░░░░░░░░▌▐░░░░░░░░░░░▌▐░░░░░░░░░▌
     ▐░█▀▀▀▀▀▀▀▀▀ ▐░▌       ▐░▌▐░█▀▀▀▀▀▀▀▀▀ ▐░█▀▀▀▀▀▀▀█░▌ ▀▀▀▀█░█▀▀▀▀ ▐░█▀▀▀▀▀▀▀█░▌ ▀▀▀▀█░█▀▀▀▀ ▐░█▀▀▀▀▀▀█░▌
     ▐░▌          ▐░▌       ▐░▌▐░▌          ▐░▌       ▐░▌     ▐░▌     ▐░▌       ▐░▌     ▐░▌     ▐░▌      ▐░▌
     ▐░▌          ▐░█▄▄▄▄▄▄▄█░▌▐░█▄▄▄▄▄▄▄▄▄ ▐░█▄▄▄▄▄▄▄█░▌     ▐░▌     ▐░▌       ▐░▌     ▐░▌     ▐░▌       █░▌
     ▐░▌          ▐░░░░░░░░░░░▌▐░░░░░░░░░░░▌▐░░░░░░░░░░░▌     ▐░▌     ▐░▌       ▐░▌     ▐░▌     ▐░▌       ▐░▌
     ▐░▌          ▐░█▀▀▀▀▀▀▀█░▌▐░█▀▀▀▀▀▀▀▀▀ ▐░█▀▀▀▀▀▀▀█░▌     ▐░▌     ▐░▌       ▐░▌     ▐░▌     ▐░▌       ▐░▌
     ▐░▌          ▐░▌       ▐░▌▐░▌          ▐░▌       ▐░▌     ▐░▌     ▐░▌       ▐░▌     ▐░▌     ▐░▌       █░▌
     ▐░█▄▄▄▄▄▄▄▄▄ ▐░▌       ▐░▌▐░█▄▄▄▄▄▄▄▄▄ ▐░▌       ▐░▌     ▐░▌     ▐░█▄▄▄▄▄▄▄█░▌ ▄▄▄▄█░█▄▄▄▄ ▐░█▄▄▄▄▄▄█░▌
     ▐░░░░░░░░░░░▌▐░▌       ▐░▌▐░░░░░░░░░░░▌▐░▌       ▐░▌     ▐░▌     ▐░░░░░░░░░░░▌▐░░░░░░░░░░░▌▐░░░░░░░░░▌
      ▀▀▀▀▀▀▀▀▀▀▀  ▀         ▀  ▀▀▀▀▀▀▀▀▀▀▀  ▀         ▀       ▀       ▀▀▀▀▀▀▀▀▀▀▀  ▀▀▀▀▀▀▀▀▀▀▀  ▀▀▀▀▀▀▀▀▀
--]]

-- TODO:
-- [ ] Object serialization/deserialization
-- [ ] Move certain utilities into standalone modules, or under util namespace
-- [ ] Implement sealed class, property, etc (prevent inheritance)
-- [ ] Make promise system stable and modular (for actual integration) and remove the busy loop...
-- [ ] Generate comprehensive Markdown docs, including usage examples
-- [ ] Optimize code via benchmark runner under LuaJIT
-- [ ] Release unit test runner, and make all tests open-source

local oop = {}

-- Localize/Cache frequently used global functions for performance
local error = error
local getmetatable = getmetatable
local rawget = rawget
local rawset = rawset
local select = select
local setmetatable = setmetatable
local tostring = tostring
local type = type
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local math_random = math.random
local os_clock = os.clock
local os_time = os.time
local string_format = string.format
local string_gmatch = string.gmatch
local string_gsub = string.gsub
local string_rep = string.rep
local string_sub = string.sub
local string_upper = string.upper
local table_concat = table.concat
local table_insert = table.insert
local table_remove = table.remove
local table_sort = table.sort
local table_pack = table.pack or function(...) return { ..., n = select("#", ...) } end
local table_unpack = table.unpack or unpack

-- Thread utilities for promise/main thread handling
local function isMainThread()
	-- In most Lua environments, coroutine.running() returns nil on main thread
	return coroutine.running() == nil
end

local function getCurrentCoroutine()
	return coroutine.running()
end

local function ensureInCoroutine(func, errorMsg)
	errorMsg = errorMsg or "This function must be called from within a coroutine"
	return function(...)
		if not getCurrentCoroutine() then
			return error(errorMsg, 2)
		end
		return func(...)
	end
end

local function ensureInMainThread(func, errorMsg)
	errorMsg = errorMsg or "This function must be called from the main thread"
	return function(...)
		if not isMainThread() then
			return error(errorMsg, 2)
		end
		return func(...)
	end
end

-- Lookup tables for performance optimization (avoid repeated string comparisons)
local MIXIN_EXCLUDED_FIELDS = {
	["__name"] = true,
	["__isMixin"] = true,
	["initialize"] = true,
	["requires"] = true,
	["__requiredMethods"] = true,
	["__privateMethods"] = true,
	["__protectedMethods"] = true,
	["__publicMethods"] = true
}

local INHERITANCE_MIXIN_EXCLUDED_FIELDS = {
	["__name"] = true,
	["__isMixin"] = true,
	["initialize"] = true
}

local VALID_VISIBILITIES = {
	["private"] = true,
	["protected"] = true,
	["public"] = true
}

local METHOD_EXCLUSION_FIELDS = {
	["constructor"] = true,
	["new"] = true
}

-- Check if debug library is available at runtime
local function getDebugInfo()
	if debug and debug.getinfo then
		return debug.getinfo
	end
end

----------------------------------------------------------------------
-- Error Handling System
----------------------------------------------------------------------

-- Error codes for consistent error handling
local ERROR_CODES = {
	INVALID_PARAMETER = 1001,
	TYPE_MISMATCH = 1002,
	NIL_VALUE = 1003,
	METHOD_NOT_FOUND = 1004,
	CLASS_NOT_FOUND = 1005,
	INHERITANCE_ERROR = 1006,
	PROPERTY_ERROR = 1007,
	EVENT_ERROR = 1008,
	SERIALIZATION_ERROR = 1009,
	VALIDATION_ERROR = 1010,
	MIXIN_CONFLICT = 1011,
}
oop.ERROR_CODES = ERROR_CODES

-- Create standardized error objects
local function createError(code, message, context)
	return setmetatable({
		code = code,
		message = message,
		context = context or {},
		timestamp = os_time(),
	}, {
		__tostring = function(self)
			return string_format("[OOP Error %d] %s", self.code, self.message)
		end,
	})
end

-- Enhanced assertParameter with standardized errors
local function assertParameter(condition, functionName, paramName, expectedType, actualValue, level)
	if not condition then
		local actualType = type(actualValue)
		local message
		if actualValue == nil then
			message = string_format("%s: %s parameter cannot be nil", functionName, paramName)
		else
			message = string_format(
				"%s: %s parameter must be %s, got %s", functionName, paramName, expectedType, actualType)
		end

		local err = createError(ERROR_CODES.TYPE_MISMATCH, message, {
			functionName = functionName,
			parameter = paramName,
			expectedType = expectedType,
			actualType = actualType,
			actualValue = actualValue,
		})

		return error(tostring(err), level or 2)
	end
end

----------------------------------------------------------------------
-- Helper Functions
----------------------------------------------------------------------

local istype = require "@cheatoid/standalone/istype"
local isCallable = istype.callable
local istable = istype.table

----------------------------------------------------------------------
-- Try-Catch-Finally Utilities
----------------------------------------------------------------------

-- Import standalone try-catch-finally module
local try_module = require "../standalone/try"

-- Import try-catch-finally functions from standalone module
local try = try_module.try
local safe_call = try_module.safe_call
local try_all = try_module.try_all

----------------------------------------------------------------------
-- Async/Await Utilities - Comprehensive Coroutine System
-- TODO: Move to threading namespace
-- TODO: See #3
----------------------------------------------------------------------

-- Coroutine state management
local COROUTINE_STATES = {
	RUNNING = "running",
	SUSPENDED = "suspended",
	NORMAL = "normal",
	DEAD = "dead"
}

-- Async task types
local TASK_TYPES = {
	PROMISE = "promise",
	FUTURE = "future",
	STREAM = "stream"
}

-- Promise states constants
local PROMISE_STATES = {
	PENDING = "pending",
	FULFILLED = "fulfilled",
	REJECTED = "rejected",
	CANCELLED = "cancelled"
}

-- Promise implementation for async operations
local function Promise(executor)
	assertParameter(isCallable(executor), "Promise", "executor", "function", executor, 2)

	local promise = {
		_type = TASK_TYPES.PROMISE,
		_state = PROMISE_STATES.PENDING,
		_value = nil,
		_reason = nil,
		_onFulfilled = {},
		_onRejected = {},
		_onFinally = {},
		_onCancel = {},
		_isCancelled = false
	}

	-- Cancel the promise
	local function cancel(reason)
		if promise._state ~= PROMISE_STATES.PENDING then return false end

		promise._isCancelled = true
		promise._state = PROMISE_STATES.CANCELLED
		promise._reason = reason or "Promise cancelled"

		-- Execute cancel callbacks
		for _, callback in next, promise._onCancel do
			pcall(callback, reason or "Promise cancelled")
		end

		-- Execute finally callbacks
		for _, callback in next, promise._onFinally do
			pcall(callback)
		end

		return true
	end

	-- Resolve the promise
	local function resolve(value)
		if promise._state ~= PROMISE_STATES.PENDING then return end
		promise._state = PROMISE_STATES.FULFILLED
		promise._value = value

		-- Execute fulfilled callbacks
		for _, callback in next, promise._onFulfilled do
			pcall(callback, value)
		end

		-- Execute finally callbacks
		for _, callback in next, promise._onFinally do
			pcall(callback)
		end
	end

	-- Reject the promise
	local function reject(reason)
		if promise._state ~= PROMISE_STATES.PENDING then return end
		promise._state = PROMISE_STATES.REJECTED
		promise._reason = reason

		-- Execute rejected callbacks
		for _, callback in next, promise._onRejected do
			pcall(callback, reason)
		end

		-- Execute finally callbacks
		for _, callback in next, promise._onFinally do
			pcall(callback)
		end
	end

	-- Execute the executor with cancellation support
	local success, err = pcall(executor, resolve, reject, function(reason)
		cancel(reason)
	end)
	if not success then
		reject(err)
	end

	-- AndThen method for chaining (using 'andThen' instead of 'then' to avoid reserved keyword)
	function promise:andThen(onFulfilled, onRejected)
		if onFulfilled and not isCallable(onFulfilled) then
			return error("onFulfilled must be a function", 2)
		end
		if onRejected and not isCallable(onRejected) then
			return error("onRejected must be a function", 2)
		end

		local newPromise = Promise(function(resolve, reject)
			local function handleFulfillment(value)
				if onFulfilled then
					local success, result = pcall(onFulfilled, value)
					if success then
						resolve(result)
					else
						reject(result)
					end
				else
					resolve(value)
				end
			end

			local function handleRejection(reason)
				if onRejected then
					local success, result = pcall(onRejected, reason)
					if success then
						resolve(result)
					else
						reject(result)
					end
				else
					reject(reason)
				end
			end

			if self._state == PROMISE_STATES.FULFILLED then
				handleFulfillment(self._value)
			elseif self._state == PROMISE_STATES.REJECTED then
				handleRejection(self._reason)
			else
				self._onFulfilled[#self._onFulfilled + 1] = handleFulfillment
				self._onRejected[#self._onRejected + 1] = handleRejection
			end
		end)

		return newPromise
	end

	-- Catch method for error handling
	function promise:catch(onRejected)
		return self:andThen(nil, onRejected)
	end

	-- Finally method for cleanup
	function promise:finally(onFinally)
		assertParameter(isCallable(onFinally), "promise:finally", "onFinally", "function", onFinally, 2)

		if promise._state == PROMISE_STATES.PENDING then
			promise._onFinally[#promise._onFinally + 1] = onFinally
		else
			pcall(onFinally)
		end

		return self
	end

	-- Wait for promise resolution (must be called from within a coroutine)
	function promise:await()
		-- Check if we're in a coroutine
		local co = coroutine.running()
		if not co then
			return error("promise:await() must be called from within a coroutine", 2)
		end

		if self._state == PROMISE_STATES.PENDING then
			-- Set up resolution handlers
			self:andThen(function(value)
				local status = coroutine.status(co)
				if status == COROUTINE_STATES.SUSPENDED then
					local ok, err = coroutine.resume(co, value)
					if not ok then
						return error("Failed to resume coroutine: " .. tostring(err), 2)
					end
				end
			end):catch(function(reason)
				local status = coroutine.status(co)
				if status == COROUTINE_STATES.SUSPENDED then
					local ok, err = coroutine.resume(co, nil, reason)
					if not ok then
						return error("Failed to resume coroutine: " .. tostring(err), 2)
					end
				end
			end)

			-- Yield control back to the scheduler
			return coroutine.yield()
		end
		if self._state == PROMISE_STATES.FULFILLED then
			return self._value
		end -- REJECTED or CANCELLED
		return error(self._reason or "Promise was cancelled", 2)
	end

	-- Cancel method for external cancellation
	function promise:cancel(reason)
		return cancel(reason)
	end

	-- Check if promise can be cancelled
	function promise:isCancellable()
		return self._state == PROMISE_STATES.PENDING and not self._isCancelled
	end

	-- Check if promise is cancelled
	function promise:isCancelled()
		return self._state == PROMISE_STATES.CANCELLED
	end

	-- Add cancel callback
	function promise:onCancel(callback)
		assertParameter(isCallable(callback), "promise:onCancel", "callback", "function", callback, 2)

		if self._state == PROMISE_STATES.CANCELLED then
			pcall(callback, self._reason)
		elseif self._state == PROMISE_STATES.PENDING then
			table_insert(self._onCancel, callback)
		end

		return self
	end

	-- Get promise type
	function promise:getType()
		return self._type
	end

	-- Get promise state
	function promise:getState()
		return self._state
	end

	-- Check if promise is pending
	function promise:isPending()
		return self._state == PROMISE_STATES.PENDING
	end

	-- Check if promise is fulfilled
	function promise:isFulfilled()
		return self._state == PROMISE_STATES.FULFILLED
	end

	-- Check if promise is rejected
	function promise:isRejected()
		return self._state == PROMISE_STATES.REJECTED
	end

	-- Check if promise is cancelled
	function promise:isCancelled()
		return self._state == PROMISE_STATES.CANCELLED
	end

	return promise
end

-- Async function wrapper
local function async(func)
	assertParameter(isCallable(func), "oop.async", "func", "function", func, 2)

	return function(...)
		local args = table_pack(...)

		return Promise(function(resolve, reject)
			local co = coroutine.create(function()
				local ok, res = pcall(func, table_unpack(args, 1, args.n)); -- comment/semicolon is required :)
				(ok and resolve or reject)(res)
			end)

			-- Start the coroutine and properly handle the result
			local ok, err = coroutine.resume(co)
			if not ok then
				reject(err)
			end
			-- Note: If the coroutine yields, it will be resumed when the promise it's awaiting resolves
		end)
	end
end

-- Await function for coroutines
local function await(promiseOrValue)
	if type(promiseOrValue) == "table" and promiseOrValue.await and isCallable(promiseOrValue.await) then
		return promiseOrValue:await()
	else
		return promiseOrValue
	end
end

-- Parallel execution of promises
local function parallel(promises, stopOnError)
	assertParameter(istable(promises), "oop.parallel", "promises", "table", promises, 2)
	stopOnError = stopOnError ~= false -- default to true

	return Promise(function(resolve, reject)
		local results = {}
		local completed = 0
		local total = #promises
		local hasError = false

		if total == 0 then
			resolve(results)
			return
		end

		for i, originalPromise in next, promises do
			local promise = originalPromise
			if type(promise) ~= "table" or not promise.andThen or not isCallable(promise.andThen) then
				-- Convert non-promise values to resolved promises
				promise = Promise(function(resolve) resolve(originalPromise) end)
			end

			promise:andThen(function(value)
				if hasError then return end

				results[i] = value
				completed = completed + 1

				if completed == total then
					resolve(results)
				end
			end):catch(function(reason)
				if hasError then return end

				hasError = true
				if stopOnError then
					reject(reason)
				else
					results[i] = nil
					completed = completed + 1
					if completed == total then
						resolve(results)
					end
				end
			end)
		end
	end)
end

-- Sequential execution of promises
local function sequence(promises)
	assertParameter(istable(promises), "oop.sequence", "promises", "table", promises, 2)

	return Promise(function(resolve, reject)
		local results = {}
		local index = 1

		local function executeNext()
			if index > #promises then
				resolve(results)
				return
			end

			local originalPromise = promises[index]
			local promise = originalPromise
			if type(promise) ~= "table" or not promise.andThen or not isCallable(promise.andThen) then
				-- Convert non-promise values to resolved promises
				promise = Promise(function(resolve) resolve(originalPromise) end)
			end

			promise:andThen(function(value)
				results[index] = value
				index = index + 1
				executeNext()
			end):catch(reject)
		end

		executeNext()
	end)
end

-- Race between promises
local function race(promises)
	assertParameter(istable(promises), "oop.race", "promises", "table", promises, 2)

	return Promise(function(resolve, reject)
		local hasCompleted = false

		for i, originalPromise in next, promises do
			local promise = originalPromise
			if type(promise) ~= "table" or not promise.andThen or not isCallable(promise.andThen) then
				-- Convert non-promise values to resolved promises
				promise = Promise(function(resolve) resolve(originalPromise) end)
			end

			promise:andThen(function(value)
				if not hasCompleted then
					hasCompleted = true
					resolve(value)
				end
			end):catch(function(reason)
				if not hasCompleted then
					hasCompleted = true
					reject(reason)
				end
			end)
		end
	end)
end

-- Timeout utility for promises
local function timeout(promise, ms)
	assertParameter(type(promise) == "table" and promise.andThen, "oop.timeout", "promise", "a promise", promise, 2)
	assertParameter(type(ms) == "number" and ms > 0, "oop.timeout", "ms", "a positive number", ms, 2)

	return Promise(function(resolve, reject)
		local completed = false

		-- Set up timeout
		local timeoutTimer = Promise(function(resolve, reject)
			local start = os_clock()
			local targetTime = start + (ms / 1000)

			local function checkTimeout()
				if completed then return end

				local currentTime = os_clock()
				if currentTime >= targetTime then
					if not completed then
						completed = true
						reject("Operation timed out after " .. ms .. "ms")
					end
				else
					-- TODO/FIXME: Small delay to prevent busy waiting
					coroutine.yield()
					checkTimeout()
				end
			end

			-- Start the timeout check in a coroutine
			local co = coroutine.create(checkTimeout)
			coroutine.resume(co)
		end)

		-- Race between original promise and timeout
		race({ promise, timeoutTimer }):andThen(function(value)
			completed = true
			resolve(value)
		end):catch(function(reason)
			completed = true
			reject(reason)
		end)
	end)
end

-- Delay utility
local function delay(ms)
	assertParameter(type(ms) == "number" and ms >= 0, "oop.delay", "ms", "a non-negative number", ms, 2)

	return Promise(function(resolve, reject)
		local start = os_clock()
		local targetTime = start + (ms / 1000)

		-- Use a simple loop with proper timing
		local function checkDelay()
			local currentTime = os_clock()
			if currentTime >= targetTime then
				resolve()
			else
				-- TODO/FIXME: In a real implementation, use proper timers
				--coroutine.yield()

				-- Small delay to prevent busy waiting
				-- Calculate remaining time and yield appropriately
				local remaining = targetTime - currentTime
				if remaining > 0.001 then
					-- Sleep for a short time to prevent busy waiting
					-- This is a simplified implementation - in production, use proper timers
					for i = 1, 20000 do
						-- Small busy wait to achieve timing
					end
				end
				checkDelay()
			end
		end

		-- Start the delay check in a coroutine
		local co = coroutine.create(checkDelay)
		coroutine.resume(co)
	end)
end

-- Task error handling API
local createCoroutinePool
local taskErrorHandler

local function setTaskErrorHandler(handler)
	assertParameter(handler == nil or isCallable(handler), "oop.setTaskErrorHandler", "handler", "nil or function",
		handler, 2)
	taskErrorHandler = handler
end

local function getTaskErrorHandler()
	return taskErrorHandler
end

-- Simple task API for background execution
local function task(func)
	assertParameter(isCallable(func), "oop.task", "func", "function", func, 2)

	-- Get or create default coroutine pool
	local defaultPool = oop._defaultCoroutinePool
	if not defaultPool then
		defaultPool = createCoroutinePool(5) -- Default pool size
		oop._defaultCoroutinePool = defaultPool
	end

	-- Submit task to pool for background execution
	return defaultPool:execute(func)
end

-- Coroutine pool for managing multiple coroutines
function createCoroutinePool(maxSize)
	maxSize = maxSize or 10
	assertParameter(type(maxSize) == "number" and maxSize > 0, "createCoroutinePool", "maxSize", "a positive number",
		maxSize, 2)

	-- Helper function to remove coroutine from available list by value
	local function removeFromAvailable(availableList, co)
		for i, availableCo in next, availableList do
			if availableCo == co then
				table_remove(availableList, i)
				return true
			end
		end
		return false
	end

	-- Helper function to pop available coroutine (stack behavior)
	local function popAvailable(availableList)
		return table_remove(availableList) -- pop last
	end

	-- Atomic helper function to return coroutine to pool (prevents duplicates)
	local function returnToPool(pool, co)
		-- Remove from busy tracking first
		pool.busy[co] = nil

		-- Only add to available if not already there (prevents duplicates)
		local alreadyAvailable = false
		for _, availableCo in next, pool.available do
			if availableCo == co then
				alreadyAvailable = true
				break
			end
		end

		if not alreadyAvailable then
			table_insert(pool.available, co)
		end
	end

	local pool = {
		coroutines = {},
		available = {},
		busy = {},
		queue = {}, -- Task queue for load balancing
		maxSize = maxSize,
		nextId = 1,
		isShutdown = false -- Track shutdown state
	}

	function pool:execute(func, ...)
		assertParameter(isCallable(func), "pool:execute", "func", "function", func, 2)

		if self.isShutdown then
			return error("pool has been shutdown", 2)
		end

		local args = table_pack(...)

		return Promise(function(resolve, reject)
			local task = {
				func = func,
				args = args,
				resolve = resolve,
				reject = reject,
				errorHandler = taskErrorHandler -- Use the module-scoped error handler
			}

			-- Try to get an available coroutine or create new one if under limit
			local co = popAvailable(self.available)
			if not co and #self.coroutines < self.maxSize then
				co = coroutine.create(function()
					while not self.isShutdown do
						local aTask = coroutine.yield()
						if not aTask or self.isShutdown then break end

						local success, result = pcall(aTask.func, table_unpack(aTask.args, 1, aTask.args.n))
						if aTask.resolve then
							if success then
								aTask.resolve(result)
							else
								aTask.reject(result)
							end
						end

						-- Check for task error handler
						if not success and aTask.errorHandler then
							aTask.errorHandler(result)
						end

						-- Return coroutine to pool atomically
						returnToPool(self, co)

						-- Process next queued task if any
						local nextTask = table_remove(self.queue)
						if nextTask then
							-- Remove from available and mark as busy
							removeFromAvailable(self.available, co)
							self.busy[co] = true
							local nextSuccess, nextResult = coroutine.resume(co, nextTask)
							if not nextSuccess then
								if nextResult ~= nil then
									nextTask.reject(nextResult)
								else
									nextTask.reject("Coroutine failed to resume")
								end
								-- Return coroutine to pool on failure atomically
								returnToPool(self, co)
							end
						end
					end
				end)
				table_insert(self.coroutines, co)
			end

			if co then
				-- Execute immediately with available coroutine
				-- Note: co is already removed from available by popAvailable above
				self.busy[co] = true

				local success, result = coroutine.resume(co, task)
				if not success then
					if result ~= nil then
						reject(result)
					else
						reject("Coroutine failed to resume")
					end
					-- Return coroutine to pool on failure atomically
					returnToPool(self, co)
				end
			else
				-- Queue the task if no coroutines available
				table_insert(self.queue, task)
			end
		end)
	end

	function pool:size()
		return #self.coroutines
	end

	function pool:availableCount()
		return #self.available
	end

	function pool:busyCount()
		local count = 0
		for _ in next, self.busy do
			count = count + 1
		end
		return count
	end

	function pool:queueCount()
		return #self.queue
	end

	function pool:shutdown()
		self.isShutdown = true -- Set shutdown flag

		-- Cancel all queued tasks
		for _, task in next, self.queue do
			if task.reject then
				task.reject("pool has been shutdown")
			end
		end
		self.queue = {}

		-- Signal all available coroutines to exit
		for _, co in next, self.available do
			local success = coroutine.resume(co, nil) -- Send nil signal to exit
		end

		-- Wait for busy coroutines to finish
		local maxWaitTime = 1.0 -- Reduced wait time
		local startTime = os_clock()

		for _, co in next, self.coroutines do
			if self.busy[co] then
				local status = coroutine.status(co)
				while status == COROUTINE_STATES.SUSPENDED or status == COROUTINE_STATES.RUNNING do
					if os_clock() - startTime > maxWaitTime then
						break
					end

					-- TODO/FIXME: Small delay to prevent busy waiting
					local waitStart = os_clock()
					while os_clock() - waitStart < 0.01 do end

					status = coroutine.status(co)
				end
			end
		end

		-- Clean up
		self.coroutines = {}
		self.available = {}
		self.busy = {}
	end

	return pool
end

-- Stream processing for async data flows
local function Stream()
	local stream = {
		_data = {},
		_subscribers = {},
		_closed = false,
		_error = nil
	}

	function stream:push(value)
		if self._closed then
			return error("Stream is closed", 2)
		end

		table_insert(self._data, value)

		-- Notify subscribers
		for _, subscriber in next, self._subscribers do
			pcall(subscriber, value)
		end
	end

	function stream:subscribe(callback)
		assertParameter(isCallable(callback), "stream:subscribe", "callback", "function", callback, 2)
		table_insert(self._subscribers, callback)

		-- Send existing data
		for _, value in next, self._data do
			pcall(callback, value)
		end
	end

	function stream:map(transform)
		assertParameter(isCallable(transform), "stream:map", "transform", "function", transform, 2)

		local newStream = Stream()
		self:subscribe(function(value)
			local success, result = pcall(transform, value)
			if success then
				newStream:push(result)
			end
		end)

		return newStream
	end

	function stream:filter(predicate)
		assertParameter(isCallable(predicate), "stream:filter", "predicate", "function", predicate, 2)

		local newStream = Stream()
		self:subscribe(function(value)
			local success, result = pcall(predicate, value)
			if success and result then
				newStream:push(value)
			end
		end)

		return newStream
	end

	function stream:reduce(accumulator, initialValue)
		assertParameter(isCallable(accumulator), "stream:reduce", "accumulator", "function", accumulator, 2)

		local result = initialValue
		local index = 0

		self:subscribe(function(value)
			index = index + 1
			local success, newResult = pcall(accumulator, result, value, index)
			if success then
				result = newResult
			end
		end)

		return result
	end

	function stream:close()
		self._closed = true
	end

	function stream:isClosed()
		return self._closed
	end

	return stream
end

----------------------------------------------------------------------
-- Weak Table Utilities
----------------------------------------------------------------------

--- Create a weak table with weak keys.
---@return table table A table with weak key references.
function oop.weakKeys()
	return setmetatable({}, { __mode = "k" })
end

--- Create a weak table with weak values.
---@return table table A table with weak value references.
function oop.weakValues()
	return setmetatable({}, { __mode = "v" })
end

--- Create a weak table with weak keys and values.
---@return table table A table with weak key and value references.
function oop.weakKV()
	return setmetatable({}, { __mode = "kv" })
end

-- Export weak-table utilities
oop.WeakKeys = oop.weakKeys
oop.WeakValues = oop.weakValues
oop.WeakKV = oop.weakKV
oop.WeakTable = oop.weakKV
oop.weakTable = oop.weakKV

-- Export thread utilities
oop.isMainThread = isMainThread
oop.getCurrentCoroutine = getCurrentCoroutine
oop.ensureInCoroutine = ensureInCoroutine
oop.ensureInMainThread = ensureInMainThread
oop.setTaskErrorHandler = setTaskErrorHandler
oop.getTaskErrorHandler = getTaskErrorHandler
oop.Task = task
oop.task = task

----------------------------------------------------------------------
-- Helper Functions
----------------------------------------------------------------------

-- Enhanced cycle-safe deep clone with metatable strategy
-- Handles complex object graphs with circular references and preserves OOP metatables
local function cycleSafeDeepClone(orig, cloneContext)
	if not cloneContext or next(cloneContext) == nil then
		cloneContext = {
			originals = setmetatable({}, { __mode = "k" }), -- Maps original objects to their clones
			clones = setmetatable({}, { __mode = "v" }), -- Maps original objects to their clones (reverse lookup)
			metatables = {},                       -- Preserves metatable relationships (use strong references)
			processing = setmetatable({}, { __mode = "k" }) -- Tracks objects currently being processed (for cycle detection)
		}
	end

	local origType = type(orig)

	-- Handle non-table types (primitives, functions, etc.)
	if origType ~= "table" then
		if origType == "function" or origType == "userdata" or origType == "thread" then
			-- Return as-is for non-copyable types, but register in context for consistency
			cloneContext.originals[orig] = orig
			return orig
		else
			-- Primitives can be returned directly
			return orig
		end
	end

	-- Check if we've already cloned this object (cycle detection)
	if cloneContext.originals[orig] then
		return cloneContext.originals[orig]
	end

	-- Detect cycles during processing
	if cloneContext.processing[orig] then
		-- We're in a cycle, create a placeholder and return it
		-- The actual object will be filled in later
		local placeholder = {}
		cloneContext.originals[orig] = placeholder
		return placeholder
	end

	-- Mark this object as being processed
	cloneContext.processing[orig] = true

	-- Create the clone
	local clone = {}
	cloneContext.originals[orig] = clone
	cloneContext.clones[clone] = orig

	-- Handle metatable with special strategy for OOP objects
	local origMetatable = getmetatable(orig)
	if origMetatable then
		local cloneMetatable

		-- Check if this is an OOP instance metatable
		if origMetatable.__index and type(origMetatable.__index) == "table" then
			local potentialClass = origMetatable.__index

			-- Check if it's an OOP class by looking for class-specific markers
			if oop.isClass(potentialClass) or potentialClass.__name then
				-- This is an OOP instance, preserve the class reference
				cloneMetatable = {
					__index = potentialClass,
					-- Copy other metatable fields if they exist
					__tostring = origMetatable.__tostring,
					__eq = origMetatable.__eq,
					__lt = origMetatable.__lt,
					__le = origMetatable.__le
				}

				-- Store metatable relationship for proper restoration
				cloneContext.metatables[clone] = cloneMetatable
			else
				-- Regular table with metatable, clone the metatable
				cloneMetatable = cycleSafeDeepClone(origMetatable, cloneContext)
				cloneContext.metatables[clone] = cloneMetatable
			end
		else
			-- Regular metatable, clone it
			cloneMetatable = cycleSafeDeepClone(origMetatable, cloneContext)
			cloneContext.metatables[clone] = cloneMetatable
		end
	end

	-- Copy all key-value pairs
	for key, value in next, orig do
		local clonedKey = cycleSafeDeepClone(key, cloneContext)
		local clonedValue = cycleSafeDeepClone(value, cloneContext)
		clone[clonedKey] = clonedValue
	end

	-- Mark processing as complete
	cloneContext.processing[orig] = nil

	return clone
end

-- Apply metatables after cloning is complete (resolves any remaining cycles)
local function applyMetatables(cloneContext)
	if cloneContext and cloneContext.metatables then
		for clone, metatable in next, cloneContext.metatables do
			if type(clone) == "table" and metatable then
				setmetatable(clone, metatable)
			end
		end
	end
end

local function deepClone(orig, copies)
	copies = copies or {}
	local origType = type(orig)
	local copy

	if origType == "table" then
		-- Check if this is an OOP instance by checking if it has an OOP-style metatable
		local origMetatable = getmetatable(orig)
		local isOopInstance = origMetatable and origMetatable.__index and (
			(type(origMetatable.__index) == "table" and (oop.isClass(origMetatable.__index) or origMetatable.__index.__name)) or
			(type(origMetatable.__index) == "function" and orig.__class and oop.isClass(orig.__class))
		)

		-- Check if we've already copied this table to prevent infinite recursion
		if copies[orig] then
			copy = copies[orig]
		else
			copy = {}
			copies[orig] = copy -- Register before recursing to handle circular references

			if isOopInstance then
				-- For OOP instances, preserve the original metatable but fix __index if it's a function
				-- Copy all key-value pairs
				for orig_key, orig_value in next, orig do
					-- Skip property internal tables - they will be handled specially
					if orig_key ~= "__propertyValues" and orig_key ~= "__propertyExplicitSet" then
						copy[deepClone(orig_key, copies)] = deepClone(orig_value, copies)
					end
				end

				-- Copy property-related tables for OOP instances
				local propertyValues = rawget(orig, "__propertyValues")
				if propertyValues then
					rawset(copy, "__propertyValues", deepClone(propertyValues, copies))
				end

				local explicitSet = rawget(orig, "__propertyExplicitSet")
				if explicitSet then
					rawset(copy, "__propertyExplicitSet", deepClone(explicitSet, copies))
				end

				-- Create appropriate metatable for clone
				local actualClass = orig.__class
				if type(origMetatable.__index) == "function" then
					-- Profiling mode: use the actual class as __index
					actualClass = orig.__class
				else
					-- Normal mode: get class from __index
					actualClass = origMetatable.__index
				end

				if actualClass and oop.isClass(actualClass) then
					-- We need to recreate the property intercept metamethods
					local newMt = {}
					-- Copy all metamethods from original metatable
					for k, v in next, origMetatable or {} do
						newMt[k] = v
					end
					-- Ensure __index points to the actual class
					newMt.__index = actualClass

					-- Recreate property intercept if the class has properties
					if actualClass.__properties and actualClass.__hasPropertyNewIndex then
						newMt.__hasPropertyIntercept = true

						local originalNewindex = origMetatable.__newindex
						local originalIndex = origMetatable.__index

						newMt.__newindex = function(tbl, key, value)
							-- Check if this is a property assignment
							if actualClass.__properties and actualClass.__properties[key] then
								-- Use the property setter
								local setterName = "set" .. string_gsub(key, "^%l", string_upper)
								if tbl[setterName] then
									return tbl[setterName](tbl, value)
								end
							end

							-- Use original __newindex if it exists
							if originalNewindex then
								return originalNewindex(tbl, key, value)
							end
							return rawset(tbl, key, value)
						end

						newMt.__index = function(tbl, key)
							-- Check if this is a property read
							if actualClass.__properties and actualClass.__properties[key] then
								-- Use the property getter
								local getterName = "get" .. string_gsub(key, "^%l", string_upper)
								if tbl[getterName] then
									return tbl[getterName](tbl)
								end
							end

							-- Use original __index if it exists
							if originalIndex then
								if type(originalIndex) == "function" then
									return originalIndex(tbl, key)
								end
								return originalIndex[key]
							end
							return rawget(tbl, key)
						end
					end

					setmetatable(copy, newMt)
				else
					-- Normal mode: preserve the exact same metatable
					setmetatable(copy, origMetatable)
				end
			else
				-- For regular tables, clone recursively
				for orig_key, orig_value in next, orig do
					copy[deepClone(orig_key, copies)] = deepClone(orig_value, copies)
				end
				setmetatable(copy, deepClone(getmetatable(orig), copies))
			end
		end
	else --if origType == "function" or origType == "userdata" or origType == "thread" then
		-- Functions, userdata, and threads cannot be meaningfully copied - return as-is
		-- This prevents mutation issues with shared references
		copy = orig
	end
	return copy
end

local function implementAbstractMethods(class)
	if class.__abstractMethods then
		for methodName in next, class.__abstractMethods do
			class[methodName] = function()
				return error("Abstract method '" .. methodName .. "' must be implemented by subclass", 2)
			end
		end
	end
end

-- Helper function for shallow copying arrays (preserves original references)
local function shallowCopyArray(t)
	local result = {}
	for i = 1, #(t or {}) do
		result[i] = t[i]
	end
	return result
end

----------------------------------------------------------------------
-- Core Class System
----------------------------------------------------------------------

local getAnonClassID
do
	local anonClassID = 0
	getAnonClassID = function()
		anonClassID = anonClassID + 1
		return "~AnonymousClass" .. anonClassID
	end
end
function oop.class(name, super, options)
	-- Validate parameters
	assertParameter(name == nil or type(name) == "string" or type(name) == "table",
		"class", "name", "a string, table, or nil", name)
	assertParameter(super == nil or istable(super),
		"class", "super", "a table or nil", super)
	assertParameter(options == nil or type(options) == "table",
		"class", "options", "a table or nil", options)

	-- Support (super) and (name, options) calling conventions
	if type(name) == "table" and super == nil then
		options = name
		name = nil
		super = nil
	elseif type(super) == "table" and not oop.isClass(super) then
		-- More carefully detect if this is actually an options table
		-- Only treat as options if it has known option keys or no class-like structure
		local hasOptionKeys = false
		local hasClassLikeStructure = false

		-- Check for common option keys
		for key in next, super do
			if key == "inheritStatic" or key == "inheritMixins" or key == "events" or key == "declaredEvents" then
				hasOptionKeys = true
				break
			end
		end

		-- Check for class-like structure (has __name AND methods, not just __name)
		if super.__name and type(super.__name) == "string" then
			-- Look for methods or callable properties
			for key, value in next, super do
				if key ~= "__name" and (type(value) == "function" or (type(value) == "table" and getmetatable(value) and getmetatable(value).__call)) then
					hasClassLikeStructure = true
					break
				end
			end
		end

		-- Only treat as options if it has option keys OR lacks class-like structure
		if hasOptionKeys then
			-- Option keys are explicit indicators of intent to use as options
			options = super
			super = nil
		elseif not hasClassLikeStructure then
			-- No option keys and no class-like structure, assume options
			options = super
			super = nil
		end
		-- If hasClassLikeStructure and no option keys, treat as superclass (don't modify)
	end

	options = options or {}
	local inheritStatic = options.inheritStatic ~= false -- Default: true (backward compatible)
	local inheritMixins = options.inheritMixins ~= false -- Default: true (backward compatible)

	local newClass = {}
	newClass.__name = name or getAnonClassID()
	newClass.__super = super
	newClass.__instances = setmetatable({}, { __mode = "k" })

	-- If inheriting from a class
	if super then
		-- Set up metatable for method inheritance, but only for static property inheritance if enabled
		local metatable = {}

		-- Always allow method inheritance through metatable, but respect inheritMixins setting
		metatable.__index = function(table, key)
			-- First check the class itself
			local value = rawget(table, key)
			if value ~= nil then
				-- Wrap method calls with profiling if enabled
				if oop._profiling.enabled and type(value) == "function" and key ~= "new" then
					local className = rawget(table, "__className") or "Unknown"
					return function(self, ...)
						local startTime = os_clock()
						local results = table_pack(value(self, ...))
						local endTime = os_clock()
						local duration = endTime - startTime

						-- Record the method call
						if not oop._profiling.data.methodCalls[key] then
							oop._profiling.data.methodCalls[key] = {}
						end
						table_insert(oop._profiling.data.methodCalls[key], {
							duration = duration,
							timestamp = startTime,
							className = className,
						})

						return table_unpack(results, 1, results.n)
					end
				end
				return value
			end

			-- Then check the parent class
			if super then
				local parentValue = super[key]
				if parentValue ~= nil then
					-- Wrap method calls with profiling if enabled
					if oop._profiling.enabled and type(parentValue) == "function" and key ~= "new" then
						local className = rawget(super, "__className") or "Unknown"
						return function(self, ...)
							local startTime = os_clock()
							local results = table_pack(parentValue(self, ...))
							local endTime = os_clock()
							local duration = endTime - startTime

							-- Record the method call
							if not oop._profiling.data.methodCalls[key] then
								oop._profiling.data.methodCalls[key] = {}
							end
							table_insert(oop._profiling.data.methodCalls[key], {
								duration = duration,
								timestamp = startTime,
								className = className,
							})

							return table_unpack(results, 1, results.n)
						end
					end

					-- For functions, check if they come from mixins and if mixin inheritance is disabled
					if type(parentValue) == "function" and not inheritMixins then
						-- Check if this method comes from a mixin
						if super.__mixins then
							for _, mixin in next, super.__mixins do
								if rawget(mixin, key) == parentValue then
									return nil -- Don't inherit mixin methods when inheritMixins is false
								end
							end
						end
					end

					-- For non-functions, only return if static inheritance is enabled
					if type(parentValue) ~= "function" then
						if inheritStatic then
							return parentValue
						else
							return nil
						end
					end

					-- For functions that aren't from disabled mixins, return them
					return parentValue
				end
			end

			return nil
		end

		setmetatable(newClass, metatable)

		-- Mixin inheritance (configurable)
		newClass.__mixins = inheritMixins and shallowCopyArray(super.__mixins) or {}

		-- Copy methods from inherited mixins to child class
		if inheritMixins and super.__mixins then
			for _, mixin in next, super.__mixins do
				for k, v in next, mixin do
					if not INHERITANCE_MIXIN_EXCLUDED_FIELDS[k] then
						if rawget(newClass, k) == nil then
							rawset(newClass, k, v)
						end
					end
				end
			end
		end

		-- Static property inheritance (configurable)
		if inheritStatic then
			for k, v in next, super do
				if not rawget(newClass, k) and type(v) ~= "function" and string_sub(k, 1, 2) ~= "__" then
					rawset(newClass, k, deepClone(v))
				end
			end
		end

		-- Implement abstract methods from interface
		if super.__abstractMethods then
			newClass.__abstractMethods = deepClone(super.__abstractMethods)
			implementAbstractMethods(newClass)
		end

		-- Inherit constants from parent class
		if super.__constants then
			newClass.__constants = deepClone(super.__constants)
			newClass.__constantValues = deepClone(super.__constantValues)

			-- Set up constant protection metatable for child class
			-- Only set up if not already set up (prevents multiple overwrites in inheritance chains)
			local currentMetatable = getmetatable(newClass)
			if not currentMetatable or not currentMetatable.__hasConstantProtection then
				local originalIndex = currentMetatable and currentMetatable.__index
				local originalNewindex = currentMetatable and currentMetatable.__newindex

				-- Update the metatable to protect constants
				currentMetatable.__index = function(table, key)
					-- Check if it's a constant in this class
					if rawget(table, "__constants") and rawget(table, "__constants")[key] then
						return rawget(table, "__constantValues")[key]
					end

					-- Walk up the inheritance chain to find constants
					local currentClass = rawget(table, "__super")
					while currentClass do
						if rawget(currentClass, "__constants") and rawget(currentClass, "__constants")[key] then
							return rawget(currentClass, "__constantValues")[key]
						end
						currentClass = rawget(currentClass, "__super")
					end

					-- Use original __index for inheritance
					if originalIndex then
						if type(originalIndex) == "function" then
							return originalIndex(table, key)
						else
							return originalIndex[key]
						end
					end

					-- Fallback to rawget
					return rawget(table, key)
				end

				currentMetatable.__newindex = function(table, key, newValue)
					-- Check if it's a constant in this class
					if rawget(table, "__constants") and rawget(table, "__constants")[key] then
						return error("Cannot modify constant '" .. key .. "' - constants are read-only", 2)
					end

					-- Walk up the inheritance chain to check for inherited constants
					local currentClass = rawget(table, "__super")
					while currentClass do
						if rawget(currentClass, "__constants") and rawget(currentClass, "__constants")[key] then
							return error("Cannot modify constant '" .. key .. "' - constants are read-only", 2)
						end
						currentClass = rawget(currentClass, "__super")
					end

					-- Use original __newindex if it exists
					if originalNewindex then
						return originalNewindex(table, key, newValue)
					else
						return rawset(table, key, newValue)
					end
				end

				-- Mark that constant protection is already set up
				currentMetatable.__hasConstantProtection = true
			end
		end
	else
		newClass.__mixins = {}
	end

	-- Constructor
	function newClass:new(...)
		-- Track instance creation if profiling is enabled
		if oop._profiling.enabled then
			local className = rawget(newClass, "__className") or "Unknown"
			if not oop._profiling.data.classInstances[className] then
				oop._profiling.data.classInstances[className] = {}
			end
			table_insert(oop._profiling.data.classInstances[className], {
				timestamp = os_clock(),
				argsCount = select("#", ...),
			})
		end

		-- Create instance with profiling if enabled
		local instance
		if oop._profiling.enabled then
			local className = rawget(newClass, "__className") or "Unknown"

			instance = setmetatable({}, {
				__index = function(table, key)
					-- Look up the method through the normal inheritance chain
					local value = newClass[key]
					if value ~= nil and type(value) == "function" and key ~= "new" then
						return function(self, ...)
							-- Store the current method name for super() calls (but not for super itself)
							if key ~= "super" then
								local oldMethodName = rawget(self, "__currentMethodName")
								rawset(self, "__currentMethodName", key)

								local startTime = os_clock()
								local results = table_pack(value(self, ...))
								local endTime = os_clock()
								local duration = endTime - startTime

								-- Record the method call
								if not oop._profiling.data.methodCalls[key] then
									oop._profiling.data.methodCalls[key] = {}
								end
								table_insert(oop._profiling.data.methodCalls[key], {
									duration = duration,
									timestamp = startTime,
									className = className,
								})

								-- Restore the previous method name
								if oldMethodName then
									rawset(self, "__currentMethodName", oldMethodName)
								else
									rawset(self, "__currentMethodName", nil)
								end

								return table_unpack(results, 1, results.n)
							else
								-- For super method, just profile without overwriting method name
								local startTime = os_clock()
								local results = table_pack(value(self, ...))
								local endTime = os_clock()
								local duration = endTime - startTime

								-- Record the method call
								if not oop._profiling.data.methodCalls[key] then
									oop._profiling.data.methodCalls[key] = {}
								end
								table_insert(oop._profiling.data.methodCalls[key], {
									duration = duration,
									timestamp = startTime,
									className = className,
								})

								return table_unpack(results, 1, results.n)
							end
						end
					end
					return value
				end,
			})
		else
			instance = setmetatable({}, { __index = newClass })
		end

		-- Store reference to class for clone method (needed when profiling is enabled)
		instance.__class = newClass

		-- Store weak reference to track instances
		newClass.__instances[instance] = true

		-- Call mixin's initialize methods
		if newClass.__mixins then
			for _, mixin in next, newClass.__mixins do
				if mixin.initialize then
					mixin.initialize(instance, ...)
				end
			end
		end

		-- Call constructor if exists
		if instance.constructor then
			instance:constructor(...)
		elseif instance.initialize then
			instance:initialize(...)
		end

		return instance
	end

	-- Type checking
	function newClass:instanceof(class)
		assertParameter(class ~= nil, "instanceof", "class", "non-nil", class)
		assertParameter(istable(class), "instanceof", "class", "a table", class)

		-- Safely get the class from the instance's metatable
		local mt = getmetatable(self)
		local instanceClass = mt and mt.__index

		-- Handle profiling case where __index is a function
		if type(instanceClass) == "function" then
			-- In profiling mode, use the stored class reference
			instanceClass = self.__class
		end

		-- Traverse the inheritance chain
		local current = instanceClass
		while current do
			if current == class then
				return true
			end
			current = current.__super
		end

		-- Check mixins (stored on the instance's class)
		if instanceClass and instanceClass.__mixins then
			for _, mixin in next, instanceClass.__mixins do
				if mixin == class then
					return true
				end
			end
		end

		return false
	end

	-- Get class name
	function newClass:getClassName()
		local mt = getmetatable(self)
		local cls

		if mt then
			-- For instances, mt.__index points to the class
			if mt.__index and type(mt.__index) == "table" then
				cls = mt.__index
			else
				-- For classes with inheritance, mt.__index is a function
				-- In this case, self is already the class we want
				cls = self
			end
		else
			-- For classes without metatable (no inheritance), self is the class
			cls = self
		end

		return rawget(cls, "__name")
	end

	-- Call parent class method with proper self binding
	function newClass:super(methodName, ...)
		-- If no method name provided, try to detect it automatically using debug info
		if not methodName then
			-- First check if we have a stored method name (from profiling wrapper)
			methodName = rawget(self, "__currentMethodName")

			if not methodName then
				-- Check if debug library is available
				local debug_getinfo = getDebugInfo()
				if not debug_getinfo then
					return error(
						"Method name must be specified explicitly when debug library is unavailable: self:super('methodName')",
						2)
				end

				-- Walk up the stack to find the method name
				local found = false
				for level = 2, 8 do
					local info = debug_getinfo(level, "nSl")
					if info and info.name and info.name ~= "" and info.name ~= "super" then
						-- Check if this looks like a method call (has 'self' as first parameter)
						if info.what == "Lua" and info.name ~= "new" then
							methodName = info.name
							found = true
							break
						end
					end
				end

				if not found then
					return error(
						"Cannot automatically detect method name for super call when debug library is unavailable. Please specify method name explicitly: self:super('methodName')",
						2)
				end
			end
		end

		-- Get the class from the instance's metatable
		local mt = getmetatable(self)
		local instanceClass = mt and mt.__index

		-- Handle profiling case where __index is a function
		if type(instanceClass) == "function" then
			-- In profiling mode, use the stored class reference
			instanceClass = self.__class or newClass
		end

		-- Check if we're in a super call context
		local superContext = rawget(self, "__superContext")
		local callingClass

		if superContext then
			-- We're already in a super call, so use the parent class from the context
			callingClass = superContext.currentClass
		else
			-- We're not in a super call, so use the instance's class
			callingClass = instanceClass
		end

		-- Get the parent class
		local parentClass = callingClass and callingClass.__super

		if not parentClass then
			return error("Cannot call super on class '" ..
				(callingClass and callingClass.__name or "unknown") .. "' - no parent class", 2)
		end

		-- Walk up the inheritance chain to find the method
		local method
		local methodClass
		local currentClass = parentClass

		while currentClass do
			method = rawget(currentClass, methodName)
			if method then
				methodClass = currentClass
				break
			end
			currentClass = currentClass.__super
		end

		if not method then
			return error("Method '" .. methodName .. "' not found in inheritance chain starting from class '" ..
				(callingClass and callingClass.__name or "unknown") .. "'", 2)
		end

		-- Set up the super context for the next call
		local shouldCleanup = false
		if superContext then
			-- Push current class onto the stack for nested calls
			if not superContext.stack then
				superContext.stack = {}
			end
			table_insert(superContext.stack, superContext.currentClass)
			superContext.currentClass = methodClass
		else
			rawset(self, "__superContext", { currentClass = methodClass, stack = {} })
			shouldCleanup = true
		end

		-- Call the method with proper error handling and cleanup
		local success, errorMsg = pcall(method, self, ...)

		-- Always clean up the context if this was the initial super call
		if shouldCleanup then
			rawset(self, "__superContext", nil)
		else
			-- Restore previous class from stack for nested calls
			local context = rawget(self, "__superContext")
			if context and context.stack then
				context.currentClass = table_remove(context.stack)
				if #context.stack == 0 then
					context.stack = nil
				end
			end
		end

		-- Re-throw error if method call failed
		if not success then
			return error(errorMsg or "Unknown error in super method call", 2)
		end

		return errorMsg
	end

	-- Helper function for automatic super calls with better ergonomics
	function newClass:superCall(...)
		return self:super(...)
	end

	-- Extend class declaratively with a methods table
	function newClass:extend(className, methods)
		assertParameter(className ~= nil, "extend", "className", "non-nil", className)
		assertParameter(type(className) == "string", "extend", "className", "a string", className)
		assertParameter(methods == nil or type(methods) == "table", "extend", "methods", "a table or nil", methods)

		methods = methods or {}
		local subclass = oop.class(className, self)

		-- Support implicit constructor definition (function at index 1)
		if type(methods[1]) == "function" then
			rawset(subclass, "constructor", methods[1])
		end

		-- Copy all methods from the table to the subclass
		for name, method in next, methods do
			if type(name) == "string" then
				rawset(subclass, name, method)
			end
		end

		return subclass
	end

	-- Mark a method as chainable (returns self for fluent API)
	function newClass:chainable(methodName)
		assertParameter(methodName ~= nil, "chainable", "methodName", "non-nil", methodName)
		assertParameter(type(methodName) == "string", "chainable", "methodName", "a string", methodName)

		local original = self[methodName]
		if not original then
			return error("Method '" .. methodName .. "' not found in class '" .. self.__name .. "'", 2)
		end
		self[methodName] = function(self, ...)
			original(self, ...)
			return self
		end
		return self
	end

	-- Mark multiple methods as chainable
	function newClass:chainables(...)
		local names = { ... }
		for _, name in next, names do
			self:chainable(name)
		end
		return self
	end

	-- Method modifiers for aspect-oriented programming
	function newClass:before(methodName, advice)
		assertParameter(methodName ~= nil, "before", "methodName", "non-nil", methodName)
		assertParameter(type(methodName) == "string", "before", "methodName", "a string", methodName)
		assertParameter(advice ~= nil, "before", "advice", "non-nil", advice)
		assertParameter(isCallable(advice), "before", "advice", "callable", advice)

		local original = self[methodName]
		if not original then
			return error("Method '" .. methodName .. "' not found in class '" .. self.__name .. "'", 2)
		end

		self[methodName] = function(self, ...)
			advice(self, ...)
			return original(self, ...)
		end
		return self
	end

	function newClass:after(methodName, advice)
		assertParameter(methodName ~= nil, "after", "methodName", "non-nil", methodName)
		assertParameter(type(methodName) == "string", "after", "methodName", "a string", methodName)
		assertParameter(advice ~= nil, "after", "advice", "non-nil", advice)
		assertParameter(isCallable(advice), "after", "advice", "callable", advice)

		local original = self[methodName]
		if not original then
			return error("Method '" .. methodName .. "' not found in class '" .. self.__name .. "'", 2)
		end

		self[methodName] = function(self, ...)
			local result = original(self, ...)
			advice(self, ...)
			return result
		end
		return self
	end

	function newClass:around(methodName, advice)
		assertParameter(methodName ~= nil, "around", "methodName", "non-nil", methodName)
		assertParameter(type(methodName) == "string", "around", "methodName", "a string", methodName)
		assertParameter(advice ~= nil, "around", "advice", "non-nil", advice)
		assertParameter(isCallable(advice), "around", "advice", "callable", advice)

		local original = self[methodName]
		if not original then
			return error("Method '" .. methodName .. "' not found in class '" .. self.__name .. "'", 2)
		end

		self[methodName] = function(self, ...)
			return advice(self, original, ...)
		end
		return self
	end

	-- Create method aliases for better API design
	function newClass:alias(newName, oldName)
		assertParameter(newName ~= nil, "alias", "newName", "non-nil", newName)
		assertParameter(type(newName) == "string", "alias", "newName", "a string", newName)
		assertParameter(oldName ~= nil, "alias", "oldName", "non-nil", oldName)
		assertParameter(type(oldName) == "string", "alias", "oldName", "a string", oldName)

		local original = self[oldName]
		if not original then
			return error("Method '" .. oldName .. "' not found in class '" .. self.__name .. "'", 2)
		end

		self[newName] = original
		return self
	end

	-- Apply mixin(s) to this class
	function newClass:uses(...)
		return oop.uses(self, ...)
	end

	-- Check if object implements interface
	function newClass:implements(interface)
		-- Handle nil and non-table inputs with errors
		assertParameter(interface ~= nil, "implements", "interface", "non-nil", interface)
		assertParameter(istable(interface), "implements", "interface", "a table", interface)

		-- Return false for classes (not interfaces) rather than throwing error
		if oop.isClass(interface) then
			return false
		end

		-- Validate that it's actually an interface
		assertParameter(interface.__isInterface, "implements", "interface", "an interface (created with oop.interface)",
			interface)

		if interface.__requiredMethods then
			for methodName in next, interface.__requiredMethods do
				if type(self[methodName]) ~= "function" then
					return false
				end
			end
		end

		return true
	end

	-- Define a read-only class constant
	function newClass:constant(name, value)
		-- Check if this is being called on an instance (not a class)
		local mt = getmetatable(self)
		local isInstance = mt and (
			mt.__index == newClass or
			(type(mt.__index) == "function" and self.__class == newClass)
		)
		if isInstance then
			return error("Cannot define constants on instances - constants are class-level only", 2)
		end

		assertParameter(name ~= nil, "constant", "name", "non-nil", name)
		assertParameter(type(name) == "string", "constant", "name", "a string", name)

		-- Initialize constants tracking if needed
		if not self.__constants then
			self.__constants = {}
		end
		self.__constants[name] = true

		-- Store the constant value in hidden storage (NOT directly on the class)
		if not self.__constantValues then
			self.__constantValues = {}
		end
		self.__constantValues[name] = value

		-- Get the current metatable
		local currentMetatable = getmetatable(self)

		-- If no metatable exists, create one
		if not currentMetatable then
			currentMetatable = {}
			setmetatable(self, currentMetatable)
		end

		-- Store original methods
		local originalIndex = currentMetatable.__index
		local originalNewindex = currentMetatable.__newindex

		-- Update the metatable to protect constants
		currentMetatable.__index = function(table, key)
			-- Check if it's a constant in this class
			if rawget(table, "__constants") and rawget(table, "__constants")[key] then
				return rawget(table, "__constantValues")[key]
			end

			-- Walk up the inheritance chain to find constants
			local currentClass = rawget(table, "__super")
			while currentClass do
				if rawget(currentClass, "__constants") and rawget(currentClass, "__constants")[key] then
					return rawget(currentClass, "__constantValues")[key]
				end
				currentClass = rawget(currentClass, "__super")
			end

			-- Use original __index for inheritance
			if originalIndex then
				if type(originalIndex) == "function" then
					return originalIndex(table, key)
				else
					return originalIndex[key]
				end
			end

			-- Fallback to rawget
			return rawget(table, key)
		end

		currentMetatable.__newindex = function(table, key, newValue)
			-- Check if it's a constant in this class
			if rawget(table, "__constants") and rawget(table, "__constants")[key] then
				return error("Cannot modify constant '" .. key .. "' - constants are read-only", 2)
			end

			-- Walk up the inheritance chain to check for inherited constants
			local currentClass = rawget(table, "__super")
			while currentClass do
				if rawget(currentClass, "__constants") and rawget(currentClass, "__constants")[key] then
					return error("Cannot modify constant '" .. key .. "' - constants are read-only", 2)
				end
				currentClass = rawget(currentClass, "__super")
			end

			-- Use original __newindex if it exists
			if originalNewindex then
				return originalNewindex(table, key, newValue)
			else
				return rawset(table, key, newValue)
			end
		end

		return self
	end

	-- Define a property with getter/setter and validation
	function newClass:property(name, defaultValue, validator)
		-- Check if this is being called on an instance (not a class)
		local mt = getmetatable(self)
		local isInstance = mt and (
			mt.__index == newClass or
			(type(mt.__index) == "function" and self.__class == newClass)
		)
		if isInstance then
			return error("Cannot define properties on instances - properties are class-level only", 2)
		end

		assertParameter(name ~= nil, "property", "name", "non-nil", name)
		assertParameter(type(name) == "string", "property", "name", "a string", name)

		-- Call the global oop.property function with this class
		return oop.property(self, name, defaultValue, validator)
	end

	-- Add static property method for class-level calls
	newClass.property = function(self, name, defaultValue, validator)
		return oop.property(self, name, defaultValue, validator)
	end

	-- Create a cycle-safe deep copy of the instance
	function newClass:clone()
		-- Get the class from the instance's metatable
		local mt = getmetatable(self)
		local instanceClass = mt and mt.__index

		-- Handle profiling case where __index is a function
		if type(instanceClass) == "function" then
			-- In profiling mode, we need to get the actual class
			-- The class should be newClass (the class this method is being called on)
			instanceClass = self.__class or newClass
		end

		-- Ensure this is being called on an instance, not a class
		if not instanceClass or instanceClass == self then
			return error("clone() can only be called on instances, not classes", 2)
		end

		-- Use the legacy deepCopy function which handles metatables correctly
		local copy = deepClone(self)

		-- Only fix metatable if deepCopy didn't create the correct property intercept
		local copyMt = getmetatable(copy)
		if not copyMt then
			-- No metatable at all, create basic one
			local newMt = {}
			newMt.__index = instanceClass
			setmetatable(copy, newMt)
		elseif type(copyMt.__index) == "function" and instanceClass and type(instanceClass) == "table" then
			-- deepCopy created property intercept, but clone method expects table __index
			-- This happens when deepCopy doesn't recognize it needs property intercept
			-- Recreate metatable with proper property intercept
			local newMt = {}
			-- Copy all metamethods from original metatable
			local originalMt = getmetatable(self)
			for k, v in next, originalMt or {} do
				newMt[k] = v
			end
			-- Ensure __index points to the correct class
			newMt.__index = instanceClass

			-- Recreate property intercept if the class has properties
			if instanceClass.__properties and instanceClass.__hasPropertyNewIndex then
				newMt.__hasPropertyIntercept = true

				local originalNewindex = originalMt.__newindex
				local originalIndex = originalMt.__index

				newMt.__newindex = function(tbl, key, value)
					-- Check if this is a property assignment
					if instanceClass.__properties and instanceClass.__properties[key] then
						-- Use the property setter
						local setterName = "set" .. string_gsub(key, "^%l", string_upper)
						if tbl[setterName] then
							return tbl[setterName](tbl, value)
						end
					end

					-- Use original __newindex if it exists
					if originalNewindex then
						return originalNewindex(tbl, key, value)
					else
						return rawset(tbl, key, value)
					end
				end

				newMt.__index = function(tbl, key)
					-- Check if this is a property read
					if instanceClass.__properties and instanceClass.__properties[key] then
						-- Use the property getter
						local getterName = "get" .. string_gsub(key, "^%l", string_upper)
						if tbl[getterName] then
							return tbl[getterName](tbl)
						end
					end

					-- Use original __index if it exists
					if originalIndex then
						if type(originalIndex) == "function" then
							return originalIndex(tbl, key)
						else
							return originalIndex[key]
						end
					else
						return rawget(tbl, key)
					end
				end
			end

			setmetatable(copy, newMt)
		end

		-- Re-register with instances table
		instanceClass.__instances[copy] = true

		return copy
	end

	-- Create a shallow copy of the instance
	function newClass:shallowCopy()
		-- Get the class from the instance's metatable
		local mt = getmetatable(self)
		local instanceClass = mt and mt.__index

		-- Handle profiling case where __index is a function
		if type(instanceClass) == "function" then
			-- In profiling mode, use the stored class reference
			instanceClass = self.__class or newClass
		end

		-- Ensure this is being called on an instance, not a class
		if not instanceClass or instanceClass == self then
			return error("shallowCopy() can only be called on instances, not classes", 2)
		end

		-- Create shallow copy
		local copy = {}

		-- Copy all key-value pairs from the instance
		for k, v in next, self do
			copy[k] = v
		end

		-- Set up proper metatable for the copy
		setmetatable(copy, { __index = instanceClass })

		-- Re-register with instances table
		instanceClass.__instances[copy] = true

		return copy
	end

	-- Create singleton instance with weak reference support
	newClass.getInstance = function(...)
		-- Initialize weak singleton storage if needed
		if rawget(newClass, "__singletonRefs") == nil then
			rawset(newClass, "__singletonRefs", setmetatable({}, { __mode = "v" }))
		end

		local singletonRefs = rawget(newClass, "__singletonRefs")
		local singleton = rawget(newClass, "__singleton")

		-- Check if we need to create a new singleton
		if singleton == nil or not singletonRefs[singleton] then
			singleton = newClass:new(...)
			rawset(newClass, "__singleton", singleton)
			singletonRefs[singleton] = true
		end

		return singleton
	end

	-- Destroy singleton
	newClass.destroyInstance = function()
		local singleton = rawget(newClass, "__singleton")
		if singleton then
			local singletonRefs = rawget(newClass, "__singletonRefs")
			if singletonRefs then
				singletonRefs[singleton] = nil
			end
		end
		rawset(newClass, "__singleton", nil)
	end

	return newClass
end

----------------------------------------------------------------------
-- Interface System
----------------------------------------------------------------------

function oop.interface(name, ...)
	assertParameter(name ~= nil, "interface", "name", "non-nil", name)
	assertParameter(type(name) == "string", "interface", "name", "a string", name)

	local interface = {
		__name = name,
		__isInterface = true,
		__requiredMethods = {},
	}

	function interface:addMethod(methodName)
		self.__requiredMethods[methodName] = true
		return self
	end

	function interface:addMethods(...)
		local names = { ... }
		for _, methodName in next, names do
			self:addMethod(methodName)
		end
		return self
	end

	function interface:extend(otherInterface)
		if otherInterface.__isInterface then
			for methodName in next, otherInterface.__requiredMethods do
				self.__requiredMethods[methodName] = true
			end
		end
		return self
	end

	for _, v in next, { ... } do
		interface:extend(v)
	end

	return interface
end

----------------------------------------------------------------------
-- Abstract Class System
----------------------------------------------------------------------

function oop.abstractClass(name, super)
	assertParameter(name ~= nil, "abstractClass", "name", "non-nil", name)
	assertParameter(type(name) == "string", "abstractClass", "name", "a string", name)
	assertParameter(super == nil or istable(super), "abstractClass", "super", "a table or nil", super)

	local abstractClass = oop.class(name, super)
	abstractClass.__isAbstract = true
	abstractClass.__abstractMethods = {}

	function abstractClass:addAbstractMethod(methodName)
		self.__abstractMethods[methodName] = true
		implementAbstractMethods(self)
		return self
	end

	function abstractClass:addAbstractMethods(...)
		local names = { ... }
		for _, methodName in next, names do
			self:addAbstractMethod(methodName)
		end
		return self
	end

	-- Store the original new method for reference
	local originalNew = abstractClass.new
	abstractClass.__abstractNew = originalNew

	-- Override new to prevent direct instantiation
	-- Checks the entire inheritance chain for abstractness
	function abstractClass:new(...)
		-- self is the class being instantiated (Circle, Shape, etc.)
		-- Check if this class or any parent class is abstract
		local currentClass = self
		while currentClass do
			if rawget(currentClass, "__isAbstract") then
				return error("Cannot instantiate abstract class '" .. rawget(currentClass, "__name") .. "' directly", 2)
			end
			currentClass = rawget(currentClass, "__super")
		end

		-- Otherwise, use the original new method
		return originalNew(self, ...)
	end

	return abstractClass
end

----------------------------------------------------------------------
-- Mixin Conflict Policy System
----------------------------------------------------------------------

-- Mixin conflict policy constants
oop.MIXIN_CONFLICT_POLICY = {
	ERROR = "error",    -- Throw error when conflicts occur
	OVERRIDE = "override", -- Override existing methods with mixin methods
	ALIAS = "alias",    -- Create alias for conflicting methods
}

-- Default conflict policy (can be changed globally)
oop.defaultMixinConflictPolicy = oop.MIXIN_CONFLICT_POLICY.ERROR

-- Set global default conflict policy
function oop.setMixinConflictPolicy(policy)
	assertParameter(policy ~= nil, "setMixinConflictPolicy", "policy", "non-nil", policy)
	assertParameter(type(policy) == "string", "setMixinConflictPolicy", "policy", "a string", policy)

	local validPolicies = {
		[oop.MIXIN_CONFLICT_POLICY.ERROR] = true,
		[oop.MIXIN_CONFLICT_POLICY.OVERRIDE] = true,
		[oop.MIXIN_CONFLICT_POLICY.ALIAS] = true,
	}

	if not validPolicies[policy] then
		return error("Invalid mixin conflict policy: " .. tostring(policy) ..
			". Valid policies are: error, override, alias", 2)
	end

	oop.defaultMixinConflictPolicy = policy
end

-- Helper function to resolve mixin conflicts
local function resolveMixinConflict(class, mixin, methodName, existingValue, mixinValue, policy)
	if policy == oop.MIXIN_CONFLICT_POLICY.ERROR then
		local err = createError(ERROR_CODES.MIXIN_CONFLICT,
			string_format("Mixin conflict: method '%s' already exists in class '%s'. " ..
				"Mixin '%s' also provides this method. " ..
				"Use a different conflict policy to resolve this conflict.",
				methodName, class.__name or "Unknown", mixin.__name or "Unknown"), {
				className = class.__name,
				mixinName = mixin.__name,
				methodName = methodName,
				conflictType = "method_conflict"
			})
		return error(tostring(err), 2)
	elseif policy == oop.MIXIN_CONFLICT_POLICY.OVERRIDE then
		-- Override existing method with mixin method
		rawset(class, methodName, mixinValue)
		return true
	elseif policy == oop.MIXIN_CONFLICT_POLICY.ALIAS then
		-- Create alias for the existing method and use mixin method
		local aliasName = methodName .. "_from_" .. (mixin.__name or "mixin")

		-- Check if alias already exists
		local counter = 1
		while rawget(class, aliasName) ~= nil do
			aliasName = methodName .. "_from_" .. (mixin.__name or "mixin") .. "_" .. counter
			counter = counter + 1
		end

		-- Move existing method to alias
		rawset(class, aliasName, existingValue)
		-- Set mixin method as the main method
		rawset(class, methodName, mixinValue)
		return true
	end

	return false
end

----------------------------------------------------------------------
-- Mixin System
----------------------------------------------------------------------

function oop.mixin(name)
	assertParameter(name ~= nil, "mixin", "name", "non-nil", name)
	assertParameter(type(name) == "string", "mixin", "name", "a string", name)

	local mixin = {
		__name = name,
		__isMixin = true,
	}
	return mixin
end

function oop.uses(class, ...)
	assertParameter(class ~= nil, "uses", "class", "non-nil", class)
	assertParameter(istable(class), "uses", "class", "a table", class)

	local args = { ... }
	local mixins = {}
	local options = {}

	-- Parse arguments: mixins can be followed by an options table
	local foundOptions = false
	for i, arg in next, args do
		if type(arg) == "table" and not arg.__isMixin and not foundOptions and #args > 1 then
			-- This is the options table (only if there are multiple arguments)
			options = arg
			foundOptions = true
		else
			-- This is a mixin
			table_insert(mixins, arg)
		end
	end

	-- Handle single mixin case (backward compatibility)
	if #mixins == 1 then
		local mixin = mixins[1]
		assertParameter(mixin ~= nil, "uses", "mixin", "non-nil", mixin)
		assertParameter(istable(mixin), "uses", "mixin", "a table", mixin)
		assertParameter(mixin.__isMixin, "uses", "mixin", "a mixin (created with oop.mixin)", mixin)

		return oop.usesSingle(class, mixin, options)
	end

	-- Handle multiple mixins
	for i, mixin in next, mixins do
		assertParameter(mixin ~= nil, "uses", "mixin " .. i, "non-nil", mixin)
		assertParameter(istable(mixin), "uses", "mixin " .. i, "a table", mixin)
		assertParameter(mixin.__isMixin, "uses", "mixin " .. i, "a mixin (created with oop.mixin)", mixin)

		oop.usesSingle(class, mixin, options)
	end

	return class
end

-- Helper function to apply a single mixin with conflict policy
function oop.usesSingle(class, mixin, options)
	options = options or {}
	local conflictPolicy = options.conflictPolicy or oop.defaultMixinConflictPolicy

	-- Validate conflict policy
	local validPolicies = {
		[oop.MIXIN_CONFLICT_POLICY.ERROR] = true,
		[oop.MIXIN_CONFLICT_POLICY.OVERRIDE] = true,
		[oop.MIXIN_CONFLICT_POLICY.ALIAS] = true,
	}

	if not validPolicies[conflictPolicy] then
		return error("Invalid mixin conflict policy: " .. tostring(conflictPolicy) ..
			". Valid policies are: error, override, alias", 2)
	end

	if not class.__mixins then
		class.__mixins = {}
	end

	table_insert(class.__mixins, mixin)

	-- Copy mixin methods to class with conflict resolution
	for k, v in next, mixin do
		if not MIXIN_EXCLUDED_FIELDS[k] then
			local existingValue = rawget(class, k)

			if existingValue == nil then
				-- No conflict, just set the method
				rawset(class, k, v)
			else
				-- Conflict detected, resolve according to policy
				resolveMixinConflict(class, mixin, k, existingValue, v, conflictPolicy)
			end
		end
	end

	return class
end

----------------------------------------------------------------------
-- Trait System (Composable Mixins)
----------------------------------------------------------------------

function oop.trait(name)
	assertParameter(name ~= nil, "trait", "name", "non-nil", name)
	assertParameter(type(name) == "string", "trait", "name", "a string", name)

	local trait = oop.mixin(name)
	trait.__requiredMethods = {}

	function trait:requires(...)
		for _, method in next, { ... } do
			self.__requiredMethods[method] = true
		end
		return self
	end

	return trait
end

----------------------------------------------------------------------
-- Properties with Getters/Setters
----------------------------------------------------------------------

function oop.property(class, name, defaultValue, validator)
	assertParameter(class ~= nil, "property", "class", "non-nil", class)
	assertParameter(istable(class), "property", "class", "a table", class)
	assertParameter(name ~= nil, "property", "name", "non-nil", name)
	assertParameter(type(name) == "string", "property", "name", "a string", name)
	if validator ~= nil then
		assertParameter(type(validator) == "function", "property", "validator", "a function or nil", validator)
	end

	if not class.__properties then
		class.__properties = {}
	end

	-- Store property metadata at class level (not the value itself)
	class.__properties[name] = {
		default = defaultValue, -- Don't deep copy yet - do it lazily
		getter = nil,
		setter = nil,
		validator = validator,
		_defaultCopied = false, -- Track if default has been copied
	}

	-- Create getter/setter methods with lazy initialization
	rawset(class, "get" .. string_gsub(name, "^%l", string_upper), function(self)
		-- Ensure instance-level property storage exists
		local instanceValues = rawget(self, "__propertyValues")
		if not instanceValues then
			instanceValues = {}
			rawset(self, "__propertyValues", instanceValues)
		end

		-- Ensure explicit tracking exists
		local explicitSet = rawget(self, "__propertyExplicitSet")
		if not explicitSet then
			explicitSet = {}
			rawset(self, "__propertyExplicitSet", explicitSet)
		end

		-- Lazy default value copying - only copy when first accessed
		if not explicitSet[name] and instanceValues[name] == nil then
			local prop = class.__properties[name]
			if not prop._defaultCopied then
				prop.default = deepClone(prop.default) -- Copy the default value once
				prop._defaultCopied = true
			end
			instanceValues[name] = deepClone(prop.default)
		end

		local value = instanceValues[name]
		local prop = class.__properties[name]
		if prop.getter then
			return prop.getter(self, value)
		end
		return value
	end)

	rawset(class, "set" .. string_gsub(name, "^%l", string_upper), function(self, value)
		-- Initialize instance-level property storage if needed
		local instanceValues = rawget(self, "__propertyValues")
		if not instanceValues then
			instanceValues = {}
			rawset(self, "__propertyValues", instanceValues)
		end

		-- Ensure explicit tracking exists
		local explicitSet = rawget(self, "__propertyExplicitSet")
		if not explicitSet then
			explicitSet = {}
			rawset(self, "__propertyExplicitSet", explicitSet)
		end

		local prop = class.__properties[name]
		local oldValue = instanceValues[name]
		if not explicitSet[name] then
			-- Lazy default value copying for oldValue
			if not prop._defaultCopied then
				prop.default = deepClone(prop.default)
				prop._defaultCopied = true
			end
			oldValue = deepClone(prop.default)
		end

		-- Validate the new value if validator is provided
		if prop.validator then
			local isValid, errorMessage = prop.validator(self, value)
			if not isValid then
				return error(errorMessage or "Property validation failed for '" .. name .. "'", 2)
			end
		end

		if prop.setter then
			local setResult = prop.setter(self, value, oldValue)
			instanceValues[name] = setResult
		else
			instanceValues[name] = value
		end

		-- Mark as explicitly set (even if nil/false)
		explicitSet[name] = true
	end)

	-- Create custom getter
	class["get" .. string_gsub(name, "^%l", string_upper) .. "Getter"] = function(self, getter)
		class.__properties[name].getter = getter
		return self
	end

	-- Create custom setter
	class["set" .. string_gsub(name, "^%l", string_upper) .. "Setter"] = function(self, setter)
		class.__properties[name].setter = setter
		return self
	end

	-- Setup __newindex metamethod to intercept direct property access
	if not class.__hasPropertyNewIndex then
		class.__hasPropertyNewIndex = true

		-- Store the original new method to wrap it
		local originalNew = class.new

		-- Wrap the new method to setup __newindex and __index on instances
		class.new = function(self, ...)
			local instance = originalNew(self, ...)

			-- Setup __newindex and __index on the instance metatable
			local instanceMt = getmetatable(instance)
			if instanceMt and not instanceMt.__hasPropertyIntercept then
				instanceMt.__hasPropertyIntercept = true

				local originalNewindex = instanceMt.__newindex
				local originalIndex = instanceMt.__index

				instanceMt.__newindex = function(tbl, key, value)
					-- Check if this is a property assignment
					if class.__properties and class.__properties[key] then
						-- Use the property setter
						local setterName = "set" .. string_gsub(key, "^%l", string_upper)
						if tbl[setterName] then
							return tbl[setterName](tbl, value)
						end
					end

					-- Use original __newindex if it exists
					if originalNewindex then
						return originalNewindex(tbl, key, value)
					else
						return rawset(tbl, key, value)
					end
				end

				instanceMt.__index = function(tbl, key)
					-- Check if this is a property read
					if class.__properties and class.__properties[key] then
						-- Use the property getter
						local getterName = "get" .. string_gsub(key, "^%l", string_upper)
						if tbl[getterName] then
							return tbl[getterName](tbl)
						end
					end

					-- Use original __index if it exists
					if originalIndex then
						if type(originalIndex) == "function" then
							return originalIndex(tbl, key)
						else
							return originalIndex[key]
						end
					else
						return rawget(tbl, key)
					end
				end
			end

			return instance
		end
	end

	return class
end

----------------------------------------------------------------------
-- Private Members via Closure
----------------------------------------------------------------------

function oop.private()
	local private = setmetatable({}, { __mode = "k" })

	return {
		init = function(self)
			private[self] = {}
			return private[self]
		end,
		get = function(self)
			return private[self]
		end,
	}
end

----------------------------------------------------------------------
-- Method Visibility System
----------------------------------------------------------------------

function oop.privateMethod(class, methodName, fn)
	assertParameter(class ~= nil, "privateMethod", "class", "non-nil", class)
	assertParameter(istable(class), "privateMethod", "class", "a table", class)
	assertParameter(methodName ~= nil, "privateMethod", "methodName", "non-nil", methodName)
	assertParameter(type(methodName) == "string", "privateMethod", "methodName", "a string", methodName)
	assertParameter(fn ~= nil, "privateMethod", "fn", "non-nil", fn)
	assertParameter(isCallable(fn), "privateMethod", "fn", "callable", fn)

	-- Initialize private method storage if not exists or corrupted
	if not class.__privateMethods or type(class.__privateMethods) ~= "table" then
		class.__privateMethods = {}
	end

	-- Remove from other visibility categories if exists
	if class.__protectedMethods and type(class.__protectedMethods) == "table" then
		class.__protectedMethods[methodName] = nil
	end

	-- Store the private method
	class.__privateMethods[methodName] = fn

	-- Create a wrapper that allows calls from within the class hierarchy
	-- Note: True privacy in Lua is challenging, so we provide convention-based access
	class[methodName] = function(self, ...)
		-- For practical purposes, we allow the call but document it as private
		-- In a production environment, you might want stricter access control
		return fn(self, ...)
	end
end

function oop.protectedMethod(class, methodName, fn)
	assertParameter(class ~= nil, "protectedMethod", "class", "non-nil", class)
	assertParameter(istable(class), "protectedMethod", "class", "a table", class)
	assertParameter(methodName ~= nil, "protectedMethod", "methodName", "non-nil", methodName)
	assertParameter(type(methodName) == "string", "protectedMethod", "methodName", "a string", methodName)
	assertParameter(fn ~= nil, "protectedMethod", "fn", "non-nil", fn)
	assertParameter(isCallable(fn), "protectedMethod", "fn", "callable", fn)

	-- Initialize protected method storage if not exists or corrupted
	if not class.__protectedMethods or type(class.__protectedMethods) ~= "table" then
		class.__protectedMethods = {}
	end

	-- Remove from other visibility categories if exists
	if class.__privateMethods and type(class.__privateMethods) == "table" then
		class.__privateMethods[methodName] = nil
	end

	-- Store the protected method
	class.__protectedMethods[methodName] = fn

	-- Create a wrapper that allows calls from within the class hierarchy
	class[methodName] = function(self, ...)
		-- Protected methods are accessible from the class and subclasses
		return fn(self, ...)
	end
end

function oop.publicMethod(class, methodName, fn)
	assertParameter(class ~= nil, "publicMethod", "class", "non-nil", class)
	assertParameter(istable(class), "publicMethod", "class", "a table", class)
	assertParameter(methodName ~= nil, "publicMethod", "methodName", "non-nil", methodName)
	assertParameter(type(methodName) == "string", "publicMethod", "methodName", "a string", methodName)
	assertParameter(fn ~= nil, "publicMethod", "fn", "non-nil", fn)
	assertParameter(isCallable(fn), "publicMethod", "fn", "callable", fn)

	-- Remove from other visibility categories if exists
	if class.__privateMethods and type(class.__privateMethods) == "table" then
		class.__privateMethods[methodName] = nil
	end
	if class.__protectedMethods and type(class.__protectedMethods) == "table" then
		class.__protectedMethods[methodName] = nil
	end

	-- Simply assign the method as public (no access restrictions)
	class[methodName] = fn
end

-- Helper function to check method visibility
function oop.getMethodVisibility(class, methodName)
	assertParameter(class ~= nil, "getMethodVisibility", "class", "non-nil", class)
	assertParameter(istable(class), "getMethodVisibility", "class", "a table", class)
	assertParameter(methodName ~= nil, "getMethodVisibility", "methodName", "non-nil", methodName)
	assertParameter(type(methodName) == "string", "getMethodVisibility", "methodName", "a string", methodName)

	if class.__privateMethods and class.__privateMethods[methodName] then
		return "private"
	elseif class.__protectedMethods and class.__protectedMethods[methodName] then
		return "protected"
	elseif type(class[methodName]) == "function" then
		return "public"
	else
		return nil
	end
end

-- Helper function to get all methods by visibility
function oop.getMethodsByVisibility(class, visibility)
	assertParameter(class ~= nil, "getMethodsByVisibility", "class", "non-nil", class)
	assertParameter(istable(class), "getMethodsByVisibility", "class", "a table", class)
	assertParameter(visibility ~= nil, "getMethodsByVisibility", "visibility", "non-nil", visibility)
	assertParameter(type(visibility) == "string", "getMethodsByVisibility", "visibility", "a string", visibility)

	-- Validate visibility parameter
	if not VALID_VISIBILITIES[visibility] then
		return error("getMethodsByVisibility: visibility parameter must be 'private', 'protected', or 'public'", 2)
	end

	local methods = {}

	if visibility == "private" and class.__privateMethods then
		for name, _ in next, class.__privateMethods do
			methods[name] = class.__privateMethods[name]
		end
	elseif visibility == "protected" and class.__protectedMethods then
		for name, _ in next, class.__protectedMethods do
			methods[name] = class.__protectedMethods[name]
		end
	elseif visibility == "public" then
		for name, method in next, class do
			if type(method) == "function" and
				name ~= "constructor" and
				name ~= "new" and
				not (class.__privateMethods and class.__privateMethods[name]) and
				not (class.__protectedMethods and class.__protectedMethods[name]) then
				methods[name] = method
			end
		end
	end

	return methods
end

----------------------------------------------------------------------
-- Event System
----------------------------------------------------------------------

function oop.eventable(class)
	local type = type
	local isCallable = isCallable

	-- Mark the class as eventable
	class.__eventable = true -- This marks the class as eventable for isEventable check

	-- Helper: ensure per-instance event storage
	local function ensureEvents(self)
		local ev = rawget(self, "__events")
		if not ev then
			ev = {}
			rawset(self, "__events", ev)
			-- Use weak-value table for listenerMap: id -> callback (weak values so callbacks can be GC'd)
			rawset(self, "__listenerMap", setmetatable({}, { __mode = "v" }))
			rawset(self, "__eventIdCounter", 0)
		end
		return ev
	end

	-- Cleanup function to remove GC'd listeners
	local function cleanupEvents(self)
		local cleanedCount = 0
		local events = rawget(self, "__events")
		local listenerMap = rawget(self, "__listenerMap")

		if events and listenerMap then
			for eventName, listeners in next, events do
				local i = 1
				while i <= #listeners do
					local listener = listeners[i]
					local callback = listenerMap[listener.id]

					-- Check if callback has been garbage collected (weak value mode)
					-- In weak value mode, if the callback is GC'd, listenerMap[id] will be nil
					if not callback then
						-- Remove the listener
						table_remove(listeners, i)
						cleanedCount = cleanedCount + 1
					else
						i = i + 1
					end
				end

				-- Remove empty event tables
				if #listeners == 0 then
					events[eventName] = nil
				end
			end
		end

		return cleanedCount
	end

	-- Helper: binary search for insertion position by priority
	local function findInsertionIndex(listeners, priority)
		local left, right = 1, #listeners + 1
		while left < right do
			local mid = math_floor((left + right) * 0.5)
			if listeners[mid].priority < priority then
				right = mid
			else
				left = mid + 1
			end
		end
		return left
	end

	-- Add listener for event
	-- Usage:
	--   on(event, callback, priority)
	--   on(eventTable) where eventTable is {event1 = callback1, event2 = callback2, ...} (priorities default to 0)
	--   on(event1, event2, ..., callback, priority) -> same callback for multiple events with priority
	function class:on(...)
		local args = { ... }
		if #args == 0 then
			return self
		end

		if #args == 1 and type(args[1]) == "table" then
			-- Map of events to callbacks: {event1 = callback1, event2 = callback2, ...}
			for event, callback in next, args[1] do
				self:on(event, callback, 0) -- recursive call with default priority 0
			end
			return self
		end

		-- Determine callback and priority
		local callback = args[#args]
		local priority = 0
		local hasPriority = false

		if type(callback) == "number" then
			priority = callback
			callback = args[#args - 1]
			hasPriority = true
		end

		if not isCallable(callback) then
			return error("Event callback must be callable", 2)
		end

		-- Assign events: all arguments except the last (or last two if priority was given)
		local eventStart = 1
		local eventEnd = hasPriority and #args - 2 or #args - 1

		for i = eventStart, eventEnd do
			local event = args[i]
			if type(event) ~= "string" then
				return error("Event name must be a string", 2)
			end

			local events = ensureEvents(self)
			if not events[event] then
				events[event] = {}
			end

			-- Generate unique listener ID
			local eventIdCounter = rawget(self, "__eventIdCounter")
			eventIdCounter = eventIdCounter + 1
			rawset(self, "__eventIdCounter", eventIdCounter)

			-- Store callback in weak-value table keyed by ID
			local listenerMap = rawget(self, "__listenerMap")
			listenerMap[eventIdCounter] = callback

			local listenerData = {
				id = eventIdCounter,
				priority = priority,
			}

			local listeners = events[event]
			local insertIndex = findInsertionIndex(listeners, priority)
			table_insert(listeners, insertIndex, listenerData)
		end

		return self
	end

	-- Remove listener for event
	-- Usage:
	--   off() -> remove all listeners for all events
	--   off(event) -> remove all listeners for the given event
	--   off(event, callback) -> remove the specific callback for the event
	function class:off(event, callback)
		if event == nil then
			-- Remove all events
			local events = rawget(self, "__events")
			if events then
				rawset(self, "__events", {})
				rawset(self, "__listenerMap", setmetatable({}, { __mode = "v" }))
			end
		elseif callback == nil then
			-- Remove all listeners for the event
			if type(event) ~= "string" then
				return error("Event name must be a string", 2)
			end
			local events = rawget(self, "__events")
			if events then
				local listeners = events[event]
				if listeners then
					-- Clean up listener map entries
					local listenerMap = rawget(self, "__listenerMap")
					if listenerMap then
						for _, listener in next, listeners do
							listenerMap[listener.id] = nil
						end
					end
				end
				events[event] = nil
			end
		else
			-- Remove the specific callback for the event
			if type(event) ~= "string" then
				return error("Event name must be a string", 2)
			end
			if not isCallable(callback) then
				return error("Event callback must be callable", 2)
			end
			local events = rawget(self, "__events")
			if events then
				local listeners = events[event]
				if listeners then
					local listenerMap = rawget(self, "__listenerMap")
					for i = #listeners, 1, -1 do
						local listener = listeners[i]
						local listenerCallback = listenerMap and listenerMap[listener.id]
						if listenerCallback == callback then
							-- Remove from listener map
							if listenerMap then
								listenerMap[listener.id] = nil
							end
							-- Remove from event listeners array
							table_remove(listeners, i)
							-- Break after first match to match original behavior
							break
						end
					end
					-- Remove empty event tables
					if #listeners == 0 then
						events[event] = nil
					end
				end
			end
		end
		return self
	end

	-- Emit event (executes listeners in priority order, highest first)
	function class:emit(event, ...)
		if type(event) ~= "string" then
			return error("Event name must be a string", 2)
		end

		-- Auto-cleanup before emitting to remove GC'd listeners
		cleanupEvents(self)

		local events = rawget(self, "__events")
		local listenerMap = rawget(self, "__listenerMap")
		if events and listenerMap then
			local listeners = events[event]
			if listeners then
				for i = 1, #listeners do
					local listener = listeners[i]
					local callback = listenerMap[listener.id]
					if callback then
						callback(...)
					end
				end
			end
		end
		return self
	end

	-- Safe emit event (collects errors, continues execution)
	function class:safeEmit(event, ...)
		if type(event) ~= "string" then
			return error("Event name must be a string", 2)
		end

		-- Auto-cleanup before emitting to remove GC'd listeners
		cleanupEvents(self)

		local errors = {}
		local events = rawget(self, "__events")
		local listenerMap = rawget(self, "__listenerMap")
		if events and listenerMap then
			local listeners = events[event]
			if listeners then
				for i = 1, #listeners do
					local listener = listeners[i]
					local callback = listenerMap[listener.id]
					if callback then
						local success, err = pcall(callback, ...)
						if not success then
							table_insert(errors, err)
						end
					end
				end
			end
		end

		-- Return errors table only
		return errors
	end

	-- Once listener (triggers only once, with optional priority)
	function class:once(event, callback, priority)
		return self:many(event, 1, callback, priority)
	end

	-- Get a copy of the listeners for the event
	function class:listeners(event)
		if type(event) ~= "string" then
			return error("Event name must be a string", 2)
		end

		-- Auto-cleanup before getting listeners
		cleanupEvents(self)

		local events = rawget(self, "__events")
		local listenerMap = rawget(self, "__listenerMap")
		if events and listenerMap then
			local listeners = events[event]
			if listeners then
				-- Return a shallow copy of callbacks in priority order
				local result = {}
				local resultIndex = 1
				for i = 1, #listeners do
					local callback = listenerMap[listeners[i].id]
					if callback then
						result[resultIndex] = callback
						resultIndex = resultIndex + 1
					end
				end
				return result
			end
		end
		return {} -- empty array if no listeners
	end

	-- Get the number of listeners for the event
	function class:listenerCount(event)
		if type(event) ~= "string" then
			return error("Event name must be a string", 2)
		end

		-- Auto-cleanup before counting
		cleanupEvents(self)

		local events = rawget(self, "__events")
		if events then
			local listeners = events[event]
			if listeners then
				return #listeners
			end
		end
		return 0
	end

	-- Check if there are any listeners for the event
	function class:hasListeners(event)
		if type(event) ~= "string" then
			return error("Event name must be a string", 2)
		end

		-- Auto-cleanup before checking
		cleanupEvents(self)

		local events = rawget(self, "__events")
		if events then
			local listeners = events[event]
			return listeners ~= nil and #listeners > 0
		end
		return false
	end

	-- Listen to the event for a specific number of times (with priority)
	function class:many(event, count, callback, priority)
		priority = priority or 0
		if type(event) ~= "string" then
			return error("Event name must be a string", 2)
		end
		if type(count) ~= "number" or count < 1 then
			return error("Count must be a positive integer", 2)
		end
		if not isCallable(callback) then
			return error("Event callback must be callable", 2)
		end

		local remaining = count
		local wrapper
		wrapper = function(...)
			callback(...)
			remaining = remaining - 1
			if remaining <= 0 then
				self:off(event, wrapper)
			end
		end
		self:on(event, wrapper, priority)
		return self
	end

	-- Apply mixin(s) to this class
	function class:uses(...)
		return oop.uses(self, ...)
	end

	return class
end

----------------------------------------------------------------------
-- Enhanced Event System - Convenience Functions and Class Integration
----------------------------------------------------------------------

-- Manual cleanup function for event systems (call periodically or when needed)
function oop.cleanupEvents(instance)
	if instance then
		local events = rawget(instance, "__events")
		local listenerMap = rawget(instance, "__listenerMap")

		if events and listenerMap then
			local cleanedCount = 0

			for eventName, listeners in next, events do
				local i = 1
				while i <= #listeners do
					local listener = listeners[i]
					local callback = listenerMap[listener.id]

					-- Check if callback has been garbage collected
					if not callback then
						-- Remove the listener
						table_remove(listeners, i)
						cleanedCount = cleanedCount + 1
					else
						i = i + 1
					end
				end

				-- Remove empty event tables
				if #listeners == 0 then
					events[eventName] = nil
				end
			end

			return cleanedCount
		end
	end
	return 0
end

-- Force garbage collection and cleanup (useful for testing)
function oop.forceEventCleanup(class)
	collectgarbage("collect")
	collectgarbage("collect")
	return oop.cleanupEvents(class)
end

-- Make a class eventable during class creation (more convenient)
-- Usage: local MyClass = oop.class("MyClass", nil, {events = true})
--        local MyClass = oop.class("MyClass", ParentClass, {events = true})
local originalClass = oop.class
function oop.class(name, super, options)
	local class = originalClass(name, super, options)

	-- Auto-apply eventable if requested in options
	if options and options.events then
		oop.eventable(class)
	end

	-- Store declared events for documentation/validation
	if options and options.declaredEvents then
		class.__declaredEvents = {}
		for _, eventName in next, options.declaredEvents do
			class.__declaredEvents[eventName] = true
		end
	end

	return class
end

-- Add event system to existing class with convenience options
function oop.addEvents(class, options)
	options = options or {}

	-- Make eventable
	oop.eventable(class)

	-- Add declared events if provided
	if options.declaredEvents then
		class.__declaredEvents = class.__declaredEvents or {}
		for _, eventName in next, options.declaredEvents do
			class.__declaredEvents[eventName] = true
		end
	end

	-- Add event validation if requested
	if options.validateEvents then
		local originalEmit = class.emit
		function class:emit(event, ...)
			if class.__declaredEvents and not class.__declaredEvents[event] then
				return error("Undeclared event: " .. tostring(event), 2)
			end
			return originalEmit(self, event, ...)
		end

		local originalOn = class.on
		function class:on(event, ...)
			if class.__declaredEvents and not class.__declaredEvents[event] then
				return error("Invalid event: " .. tostring(event), 2)
			end
			return originalOn(self, event, ...)
		end

		local originalOnce = class.once
		function class:once(event, ...)
			if class.__declaredEvents and not class.__declaredEvents[event] then
				return error("Invalid event: " .. tostring(event), 2)
			end
			return originalOnce(self, event, ...)
		end

		local originalMany = class.many
		function class:many(event, ...)
			if class.__declaredEvents and not class.__declaredEvents[event] then
				return error("Invalid event: " .. tostring(event), 2)
			end
			return originalMany(self, event, ...)
		end
	end

	return class
end

-- Get all events for a class (static version, no instance needed)
function oop.getEvents(class)
	if not class.__events then
		return {}
	end

	local events = {}
	for eventName, listeners in next, class.__events do
		events[eventName] = {
			listenerCount = #listeners,
			listeners = {},
		}

		-- Copy listener information (without actual callbacks for security)
		for i, listener in next, listeners do
			table_insert(events[eventName].listeners, {
				priority = listener.priority,
				id = listener.id,
			})
		end
	end

	return events
end

-- Get event names for a class
function oop.getEventNames(class)
	if not class.__events then
		return {}
	end

	local names = {}
	for eventName in next, class.__events do
		names[#names + 1] = eventName
	end
	return names
end

-- Get listener count for specific event
function oop.getListenerCount(class, event)
	if not class.__events or not class.__events[event] then
		return 0
	end
	return #class.__events[event]
end

-- Check if class has listeners for event
function oop.hasListeners(class, event)
	return oop.getListenerCount(class, event) > 0
end

-- Get declared events (if any)
function oop.getDeclaredEvents(class)
	if not class.__declaredEvents then
		return {}
	end

	local events = {}
	for eventName in next, class.__declaredEvents do
		events[#events + 1] = eventName
	end
	return events
end

-- Validate event name against declared events
function oop.validateEvent(class, event)
	if not class.__declaredEvents then
		return true -- No validation needed if no declared events
	end
	return class.__declaredEvents[event] == true
end

-- Event emitter mixin for classes that want to be event sources but not full eventable
function oop.eventEmitter()
	local mixin = {
		__isEventEmitter = true,
		__isMixin = true,
	}

	function mixin:emit(event, ...)
		if type(event) ~= "string" then
			return error("Event name must be a string", 2)
		end

		-- Only emit if there are listeners
		if self.__events and self.__events[event] and self.__listenerMap then
			local listeners = self.__events[event]
			local listenerMap = self.__listenerMap
			for i = 1, #listeners do
				local listener = listeners[i]
				local callback = listenerMap[listener.id]
				if callback then
					callback(...)
				end
			end
		end
		return self
	end

	function mixin:safeEmit(event, ...)
		if type(event) ~= "string" then
			return error("Event name must be a string", 2)
		end

		local errors = {}
		-- Only emit if there are listeners
		if self.__events and self.__events[event] and self.__listenerMap then
			local listeners = self.__events[event]
			local listenerMap = self.__listenerMap
			for i = 1, #listeners do
				local listener = listeners[i]
				local callback = listenerMap[listener.id]
				if callback then
					local success, err = pcall(callback, ...)
					if not success then
						table_insert(errors, {
							listenerIndex = i,
							error = err,
							listener = callback
						})
					end
				end
			end
		end

		-- Return self and errors table
		return self, errors
	end

	-- Add event listener (supports multiple calling conventions)
	function mixin:on(...)
		local args = { ... }
		if #args == 0 then
			return self
		end

		-- Handle event table: on({event1 = callback1, event2 = callback2, ...})
		if #args == 1 and type(args[1]) == "table" then
			local eventTable = args[1]
			for event, callback in next, eventTable do
				if type(event) == "string" and isCallable(callback) then
					self:addEventListener(event, callback, 0)
				end
			end
			return self
		end

		-- Handle multiple events with same callback: on(event1, event2, ..., callback, priority)
		local callback, priority
		if isCallable(args[#args]) then
			callback = args[#args]
			priority = 0
			-- Remove callback from args
			table_remove(args)
		elseif isCallable(args[#args - 1]) and type(args[#args]) == "number" then
			callback = args[#args - 1]
			priority = args[#args]
			-- Remove callback and priority from args
			table_remove(args)
			table_remove(args)
		else
			return error("Invalid arguments for on() method", 2)
		end

		-- Add callback to each event
		for _, event in next, args do
			if type(event) == "string" then
				self:addEventListener(event, callback, priority)
			end
		end

		return self
	end

	-- Add event listener with priority
	function mixin:addEventListener(event, callback, priority)
		if type(event) ~= "string" then
			return error("Event name must be a string", 2)
		end
		if not isCallable(callback) then
			return error("Callback must be callable", 2)
		end

		priority = priority or 0

		-- Initialize event storage and listener map if needed
		if not self.__events then
			self.__events = {}
			self.__listenerMap = setmetatable({}, { __mode = "v" })
			self.__eventIdCounter = 0
		end
		if not self.__events[event] then
			self.__events[event] = {}
		end

		-- Generate unique listener ID
		self.__eventIdCounter = self.__eventIdCounter + 1
		local listenerId = self.__eventIdCounter

		-- Store callback in weak-value table keyed by ID
		self.__listenerMap[listenerId] = callback

		-- Insert listener in priority order (highest first)
		local listeners = self.__events[event]
		local listener = {
			id = listenerId,
			priority = priority,
		}

		local insertPos = #listeners + 1
		for i = 1, #listeners do
			if listeners[i].priority < priority then
				insertPos = i
				break
			end
		end

		table_insert(listeners, insertPos, listener)
		return self
	end

	function mixin:hasListeners(event)
		if type(event) ~= "string" then
			return error("Event name must be a string", 2)
		end
		return self.__events and self.__events[event] and #self.__events[event] > 0
	end

	return mixin
end

-- Check if class is eventable
function oop.isEventable(class)
	return class.__eventable == true
end

-- Check if class uses event emitter
function oop.isEventEmitter(class)
	return class.__isEventEmitter == true
end

-- Event validation helper
function oop.createEventValidator(declaredEvents)
	local validator = {}

	function validator:validate(eventName)
		if not declaredEvents[eventName] then
			return error("Invalid event: " .. tostring(eventName) ..
				". Declared events: " .. table_concat(declaredEvents, ", "), 2)
		end
		return true
	end

	function validator:getDeclaredEvents()
		return declaredEvents
	end

	return validator
end

-- Batch event operations
function oop.batchEventOperations(class, operations)
	if not oop.isEventable(class) then
		return error("Class must be eventable", 2)
	end

	local results = {}

	for _, operation in next, operations do
		local opType = operation.type
		local eventName = operation.event
		local callback = operation.callback
		local priority = operation.priority or 0

		if opType == "on" then
			class:on(eventName, callback, priority)
			results[eventName] = "added"
		elseif opType == "off" then
			class:off(eventName, callback)
			results[eventName] = "removed"
		elseif opType == "once" then
			class:once(eventName, callback, priority)
			results[eventName] = "added_once"
		elseif opType == "many" then
			local count = operation.count or 1
			class:many(eventName, count, callback, priority)
			results[eventName] = "added_many"
		else
			return error("Invalid operation type: " .. tostring(opType), 2)
		end
	end

	return results
end

-- Event statistics and debugging
function oop.getEventStats(class)
	if not oop.isEventable(class) then
		return { eventable = false }
	end

	local stats = {
		eventable = true,
		totalEvents = 0,
		totalListeners = 0,
		events = {},
	}

	for eventName, listeners in next, class.__events or {} do
		local listenerCount = #listeners
		stats.totalEvents = stats.totalEvents + 1
		stats.totalListeners = stats.totalListeners + listenerCount

		stats.events[eventName] = {
			listenerCount = listenerCount,
			priorities = {},
		}

		-- Count listeners by priority
		for idx = 1, listenerCount do
			local priority = listeners[idx].priority
			stats.events[eventName].priorities[priority] =
				(stats.events[eventName].priorities[priority] or 0) + 1
		end
	end

	return stats
end

----------------------------------------------------------------------
-- Type Checking and Validation
----------------------------------------------------------------------

function oop.validate(value, expectedType, allowNil)
	if allowNil and value == nil then
		return true
	end

	local actualType = type(value)
	if expectedType == "callable" then
		return isCallable(value)
	end
	if expectedType == "table" then
		return istable(value)
	end

	-- Handle class types (check if value is instance of expectedType class)
	if oop.isClass(expectedType) then
		if istable(value) and value.instanceof and type(value.instanceof) == "function" then
			return value:instanceof(expectedType)
		end
		return false
	end

	-- Handle interface types (check if value implements expectedType interface)
	if oop.isInterface(expectedType) then
		if istable(value) and value.implements and type(value.implements) == "function" then
			return value:implements(expectedType)
		end
		return false
	end

	-- Handle mixin types (check if value uses expectedType mixin)
	if oop.isMixin(expectedType) then
		if istable(value) and value.instanceof and type(value.instanceof) == "function" then
			return value:instanceof(expectedType)
		end
		return false
	end

	return actualType == expectedType
end

function oop.checkTypes(params, expectedTypes)
	for i = 1, #expectedTypes do
		local expectedType = expectedTypes[i]
		if expectedType and not oop.validate(params[i], expectedType, false) then
			-- Get proper type name for error message
			local expectedTypeName = expectedType
			if oop.isClass(expectedType) or oop.isInterface(expectedType) or oop.isMixin(expectedType) then
				expectedTypeName = expectedType.__name or "Unknown"
			end

			-- Get actual type name
			local actualTypeName = type(params[i])
			if istable(params[i]) and params[i].getClassName and type(params[i].getClassName) == "function" then
				actualTypeName = params[i]:getClassName()
			end

			return error(string_format("Parameter %d expected type '%s', got '%s'", i, expectedTypeName, actualTypeName),
				2)
		end
	end
end

----------------------------------------------------------------------
-- Utility Functions
----------------------------------------------------------------------

function oop.isClass(obj)
	return istable(obj) and obj.__name ~= nil and isCallable(obj.new)
end

function oop.isInterface(obj)
	return istable(obj) and obj.__isInterface == true
end

function oop.isAbstract(obj)
	return istable(obj) and obj.__isAbstract == true
end

function oop.isInstance(obj)
	return istable(obj) and obj.instanceof ~= nil and isCallable(obj.instanceof)
end

-- Static inheritance checking (without instances)
function oop.extends(subclass, superclass)
	assertParameter(subclass ~= nil, "extends", "subclass", "non-nil", subclass)
	assertParameter(istable(subclass), "extends", "subclass", "a table", subclass)
	assertParameter(superclass ~= nil, "extends", "superclass", "non-nil", superclass)
	assertParameter(istable(superclass), "extends", "superclass", "a table", superclass)

	-- Both must be classes
	if not oop.isClass(subclass) or not oop.isClass(superclass) then
		return false
	end

	-- Traverse the inheritance chain
	local current = subclass
	while current do
		if current == superclass then
			return true
		end
		current = current.__super
	end

	return false
end

-- Static interface implementation checking (without instances)
function oop.implements(class, interface)
	assertParameter(class ~= nil, "implements", "class", "non-nil", class)
	assertParameter(istable(class), "implements", "class", "a table", class)
	assertParameter(interface ~= nil, "implements", "interface", "non-nil", interface)
	assertParameter(istable(interface), "implements", "interface", "a table", interface)

	-- Class must be a class, interface must be an interface
	if not oop.isClass(class) or not oop.isInterface(interface) then
		return false
	end

	-- Check if class has all required interface methods
	if interface.__requiredMethods then
		for methodName in next, interface.__requiredMethods do
			if type(class[methodName]) ~= "function" then
				return false
			end
		end
	end

	return true
end

-- Check if class uses a specific mixin (static version)
function oop.usesMixin(class, mixin)
	assertParameter(class ~= nil, "usesMixin", "class", "non-nil", class)
	assertParameter(istable(class), "usesMixin", "class", "a table", class)
	assertParameter(mixin ~= nil, "usesMixin", "mixin", "non-nil", mixin)
	assertParameter(istable(mixin), "usesMixin", "mixin", "a table", mixin)

	-- Class must be a class, mixin must be a mixin
	if not oop.isClass(class) or not oop.isMixin(mixin) then
		return false
	end

	-- Check if class has the mixin
	if class.__mixins then
		for _, classMixin in next, class.__mixins do
			if classMixin == mixin then
				return true
			end
		end
	end

	return false
end

-- Helper function to check if object is a mixin
function oop.isMixin(obj)
	return istable(obj) and obj.__isMixin == true
end

function oop.getAllInstances(class)
	assertParameter(class ~= nil, "getAllInstances", "class", "non-nil", class)
	assertParameter(istable(class), "getAllInstances", "class", "a table", class)
	return class.__instances or {}
end

function oop.countInstances(class)
	assertParameter(class ~= nil, "countInstances", "class", "non-nil", class)
	assertParameter(istable(class), "countInstances", "class", "a table", class)
	local count = 0
	for _ in next, class.__instances or {} do
		count = count + 1
	end
	return count
end

function oop.clearInstances(class)
	assertParameter(class ~= nil, "clearInstances", "class", "non-nil", class)
	assertParameter(istable(class), "clearInstances", "class", "a table", class)
	if class.__instances then
		class.__instances = setmetatable({}, { __mode = "k" })
	end
end

-- List of built-in OOP framework methods to exclude when excludeOopMethods is true
local oopMethods = {
	"instanceof", "getClassName", "super", "superCall", "chainable", "chainables",
	"before", "after", "around", "alias", "extend", "implements",
	"getInstance", "destroyInstance", "getMethodVisibility", "getMethodsByVisibility",
	"uses", "constant", "clone", "shallowCopy",
	"on", "off", "emit", "safeEmit", "once", "listeners",
	"listenerCount", "hasListeners", "many", "addEventListener",
	"addAbstractMethod", "addAbstractMethods"
}

-- Get methods table from a class for external extension
function oop.getMethods(class, includeInherited, excludeOopMethods)
	assertParameter(class ~= nil, "getMethods", "class", "non-nil", class)
	assertParameter(istable(class), "getMethods", "class", "a table", class)
	includeInherited = includeInherited ~= false -- Default: true (include inherited methods)
	excludeOopMethods = excludeOopMethods == true -- Default: false (include OOP methods)

	-- Create lookup table for O(1) checking
	local oopMethodSet = {}
	if excludeOopMethods then
		for _, method in next, oopMethods do
			oopMethodSet[method] = true
		end
	end

	local methods = {}

	-- If including inherited methods, traverse inheritance chain
	if includeInherited then
		local current = class
		while current do
			-- Copy methods from current class level
			for key, value in next, current do
				if type(value) == "function" and not METHOD_EXCLUSION_FIELDS[key] then
					-- Exclude OOP methods if requested
					if not excludeOopMethods or not oopMethodSet[key] then
						-- Only add if not already present (child methods override parent)
						if methods[key] == nil then
							methods[key] = value
						end
					end
				end
			end
			current = current.__super
		end
	else
		-- Only get methods from this specific class
		for key, value in next, class do
			if type(value) == "function" and not METHOD_EXCLUSION_FIELDS[key] then
				-- Exclude OOP methods if requested
				if not excludeOopMethods or not oopMethodSet[key] then
					methods[key] = value
				end
			end
		end
	end

	return methods
end

-- Get class metadata information
function oop.getClassInfo(class)
	assertParameter(class ~= nil, "getClassInfo", "class", "non-nil", class)
	assertParameter(istable(class), "getClassInfo", "class", "a table", class)

	local info = {
		name = class.__name or "Unknown",
		isClass = oop.isClass(class),
		isInterface = oop.isInterface(class),
		isAbstract = oop.isAbstract(class),
		hasParent = class.__super ~= nil,
		parent = class.__super,
		hasMixins = class.__mixins ~= nil and #class.__mixins > 0,
		mixins = class.__mixins or {},
		hasProperties = class.__properties ~= nil,
		properties = class.__properties or {},
		instanceCount = oop.countInstances(class),
	}

	return info
end

-- Augment class with method table (convenient helper)
function oop.augment(class, newMethods, options)
	assertParameter(class ~= nil, "augment", "class", "non-nil", class)
	assertParameter(istable(class), "augment", "class", "a table", class)
	assertParameter(newMethods ~= nil, "augment", "newMethods", "non-nil", newMethods)
	assertParameter(istable(newMethods), "augment", "newMethods", "a table", newMethods)

	options = options or {}
	local includeInherited = options.includeInherited ~= false -- Default: true
	local overrideExisting = options.overrideExisting ~= false -- Default: true
	local onlyIfExists = options.onlyIfExists or false      -- Default: false

	-- Get existing methods based on inheritance option
	local existingMethods = oop.getMethods(class, includeInherited)

	-- Apply new methods
	for methodName, newMethod in next, newMethods do
		-- Check if method should be applied
		local shouldApply = true

		if onlyIfExists then
			shouldApply = existingMethods[methodName] ~= nil
		end

		if shouldApply then
			if overrideExisting or existingMethods[methodName] == nil then
				class[methodName] = newMethod
			end
		end
	end

	return class
end

-- Batch augment multiple classes
function oop.augmentBatch(classMap, options)
	assertParameter(classMap ~= nil, "augmentBatch", "classMap", "non-nil", classMap)
	assertParameter(istable(classMap), "augmentBatch", "classMap", "a table", classMap)

	for class, newMethods in next, classMap do
		oop.augment(class, newMethods, options)
	end

	return classMap
end

----------------------------------------------------------------------
-- Enumeration System
----------------------------------------------------------------------

-- Try to load bit library for bitwise operations (optional)
local bit
local success, bitLib = pcall(require, "bit")
if success then
	bit = bitLib
else
	bit = _G.bit or require "../standalone/bits"
end

local bit_band = bit.band
local bit_bor = bit.bor
local bit_bnot = bit.bnot
local bit_bxor = bit.bxor

-- Create an enumeration with optional values and metadata
local function createEnum(name, valuesOrOptions)
	assertParameter(name ~= nil, "enum", "name", "non-nil", name)
	assertParameter(type(name) == "string", "enum", "name", "a string", name)

	local values, options

	if type(valuesOrOptions) == "table" then
		-- Check if this is an options table with a 'values' key or just values
		if valuesOrOptions.values then
			options = valuesOrOptions
			values = options.values
		else
			values = valuesOrOptions
			options = {}
		end
	else
		values = valuesOrOptions
		options = {}
	end

	-- Create the enum object
	local enum = {
		__name = name,
		__isEnum = true,
		__values = {},
		__names = {},
		__metadata = options.metadata or {},
	}

	-- Process values
	if type(values) == "table" then
		-- Table of values (can be array or key-value pairs)
		local index = 0
		for key, value in next, values do
			local enumName, enumValue

			if type(key) == "number" then
				-- Array-style: {"RED", "GREEN", "BLUE"}
				enumName = value
				enumValue = index
				index = index + 1
			else
				-- Key-value style: {RED = 1, GREEN = 2, BLUE = 4}
				enumName = key
				enumValue = value
			end

			-- Add to enum
			enum[enumName] = enumValue
			enum.__values[enumName] = enumValue

			-- Check for duplicate values to prevent __names overwrites
			if enum.__names[enumValue] then
				return error(
					string_format("Enum value %d is already assigned to '%s'. Cannot assign to '%s'. Use unique values.",
						enumValue, enum.__names[enumValue], enumName), 2)
			end
			enum.__names[enumValue] = enumName
		end
	elseif type(values) == "string" then
		-- Comma-separated string: "RED,GREEN,BLUE"
		local index = 0
		for enumName in string_gmatch(values, "[^,%s]+") do
			local enumValue = index
			enum[enumName] = enumValue
			enum.__values[enumName] = enumValue
			enum.__names[enumValue] = enumName
			index = index + 1
		end
	end

	-- Add enum methods
	function enum:has(name)
		return self.__values[name] ~= nil
	end

	function enum:getValue(name)
		return self.__values[name]
	end

	function enum:getName(value)
		return self.__names[value]
	end

	function enum:getValues()
		local values = {}
		for name, value in next, self.__values do
			values[#values + 1] = value
		end
		return values
	end

	function enum:getNames()
		local names = {}
		for name in next, self.__values do
			names[#names + 1] = name
		end
		return names
	end

	function enum:count()
		local count = 0
		for _ in next, self.__values do
			count = count + 1
		end
		return count
	end

	function enum:forEach(callback)
		for name, value in next, self.__values do
			callback(name, value)
		end
	end

	function enum:map(callback)
		local result = {}
		for name, value in next, self.__values do
			result[name] = callback(name, value)
		end
		return result
	end

	function enum:filter(predicate)
		local result = {}
		for name, value in next, self.__values do
			if predicate(name, value) then
				result[name] = value
			end
		end
		return result
	end

	function enum:toString()
		local pairStrings = {}
		for name, value in next, self.__values do
			pairStrings[#pairStrings + 1] = name .. "=" .. tostring(value)
		end
		table_sort(pairStrings)
		return "enum<" .. self.__name .. ">{" .. table_concat(pairStrings, ", ") .. "}"
	end

	-- Override __tostring for better debugging
	enum.__tostring = enum.toString
	enum.__index = enum

	-- Add bit flag operations if specified
	if options.bitFlags then
		function enum:hasFlag(value, flag)
			return bit_band(value, flag) == flag
		end

		function enum:setFlag(value, flag)
			return bit_bor(value, flag)
		end

		function enum:clearFlag(value, flag)
			return bit_band(value, bit_bnot(flag))
		end

		function enum:toggleFlag(value, flag)
			return bit_bxor(value, flag)
		end

		function enum:getAllFlags()
			local flags = {}
			for name, value in next, self.__values do
				if value > 0 and bit_band(value, value - 1) == 0 then
					-- Value is a power of 2, so it's a valid flag
					flags[#flags + 1] = { name = name, value = value }
				end
			end
			return flags
		end
	end

	return enum
end

-- Assign to oop.enum for public access
oop.enum = createEnum

-- Check if object is an enum
function oop.isEnum(obj)
	return istable(obj) and obj.__isEnum == true
end

-- Create enum from string (convenience function)
function oop.enumFromString(name, str, delimiter)
	delimiter = delimiter or ","
	local values = {}
	for item in string_gmatch(str, "[^" .. delimiter .. "%s]+") do
		values[#values + 1] = item
	end
	return createEnum(name, values)
end

-- Create enum from array (convenience function)
function oop.enumFromArray(name, array)
	return createEnum(name, array)
end

-- Create bit flag enum (convenience function)
function oop.enumFlags(name, values)
	local flags = {}
	local power = 1

	if type(values) == "table" then
		for _, name in next, values do
			flags[name] = power
			power = power * 2
		end
	elseif type(values) == "string" then
		for name in string_gmatch(values, "[^,%s]+") do
			flags[name] = power
			power = power * 2
		end
	end

	return createEnum(name, { values = flags, bitFlags = true })
end

-- Create enum from typed table (objects/instances as values)
function oop.enumFromTable(name, objects, options)
	assertParameter(name ~= nil, "enumFromTable", "name", "non-nil", name)
	assertParameter(type(name) == "string", "enumFromTable", "name", "a string", name)
	assertParameter(objects ~= nil, "enumFromTable", "objects", "non-nil", objects)
	assertParameter(type(objects) == "table", "enumFromTable", "objects", "a table", objects)

	options = options or {}

	-- Create the enum object
	local enum = {
		__name = name,
		__isEnum = true,
		__values = {},
		__names = {},
		__objects = {},
		__metadata = options.metadata or {},
	}

	-- Process objects table
	local index = 0

	-- Handle different table formats
	if options.keyProperty then
		-- Extract names from object property
		for _, obj in next, objects do
			if istable(obj) and obj[options.keyProperty] then
				local enumName = obj[options.keyProperty]
				local enumValue = index

				enum[enumName] = obj
				enum.__values[enumName] = obj
				enum.__names[enumValue] = enumName
				enum.__objects[enumName] = obj

				index = index + 1
			end
		end
	elseif options.nameMap then
		-- Use provided name mapping
		for enumName, obj in next, options.nameMap do
			local enumValue = index

			enum[enumName] = obj
			enum.__values[enumName] = obj
			enum.__names[enumValue] = enumName
			enum.__objects[enumName] = obj

			index = index + 1
		end
	else
		-- Auto-generate names from class names or indices
		for key, obj in next, objects do
			local enumName, enumValue

			if type(key) == "string" then
				-- Use the key as the enum name
				enumName = key
				enumValue = index
			else
				-- Auto-generate name from object
				if istable(obj) and obj.name and type(obj.name) == "string" then
					enumName = obj.name
				elseif istable(obj) and obj.__name then
					enumName = obj.__name
				elseif istable(obj) and obj.className then
					enumName = obj.className
				else
					enumName = "ITEM_" .. index
				end
				enumValue = index
			end

			-- Ensure unique names by adding index if needed
			local originalName = enumName
			local counter = 1
			while enum[enumName] ~= nil do
				enumName = originalName .. "_" .. counter
				counter = counter + 1
			end

			enum[enumName] = obj
			enum.__values[enumName] = obj
			enum.__names[enumValue] = enumName
			enum.__objects[enumName] = obj

			index = index + 1
		end
	end

	-- Add enum methods (adapted for object values)
	function enum:has(name)
		return self.__values[name] ~= nil
	end

	function enum:getValue(name)
		return self.__values[name]
	end

	function enum:getName(value)
		-- For object enums, value is the index
		return self.__names[value]
	end

	function enum:getObject(name)
		return self.__objects[name]
	end

	function enum:getNames()
		local names = {}
		for name in next, self.__values do
			names[#names + 1] = name
		end
		return names
	end

	function enum:getObjects()
		local objects = {}
		for name, obj in next, self.__objects do
			objects[#objects + 1] = obj
		end
		return objects
	end

	function enum:count()
		local count = 0
		for _ in next, self.__values do
			count = count + 1
		end
		return count
	end

	function enum:forEach(callback)
		for name, obj in next, self.__values do
			callback(name, obj)
		end
	end

	function enum:map(callback)
		local result = {}
		for name, obj in next, self.__values do
			result[name] = callback(name, obj)
		end
		return result
	end

	function enum:filter(predicate)
		local result = {}
		for name, obj in next, self.__values do
			if predicate(name, obj) then
				result[name] = obj
			end
		end
		return result
	end

	function enum:find(predicate)
		for name, obj in next, self.__values do
			if predicate(name, obj) then
				return name, obj
			end
		end
		return nil, nil
	end

	function enum:toString()
		local pairStrings = {}
		for name, obj in next, self.__values do
			local objDesc = "object"
			if istable(obj) then
				if obj.__name then
					objDesc = obj.__name
				elseif obj.className then
					objDesc = obj.className
				elseif obj.toString then
					objDesc = tostring(obj)
				end
			end
			pairStrings[#pairStrings + 1] = name .. "=" .. objDesc
		end
		table_sort(pairStrings)
		return "enum<" .. self.__name .. ">{" .. table_concat(pairStrings, ", ") .. "}"
	end

	-- Override __tostring for better debugging
	enum.__tostring = enum.toString
	enum.__index = enum

	return enum
end

----------------------------------------------------------------------
-- Reflection API
----------------------------------------------------------------------

-- Get comprehensive information about an object or class
function oop.inspect(obj)
	local result = {
		type = type(obj),
		isClass = false,
		isInstance = false,
		isInterface = false,
		isEnum = false,
		isMixin = false,
		className = nil,
		superClass = nil,
		properties = {},
		methods = {},
		mixins = {},
		events = {},
		constants = {},
	}

	if istable(obj) then
		-- Check if it's a class
		if oop.isClass(obj) then
			result.isClass = true
			result.className = rawget(obj, "__name")
			result.superClass = rawget(obj, "__super")
			result.properties = rawget(obj, "__properties") or {}
			result.mixins = rawget(obj, "__mixins") or {}
			result.constants = rawget(obj, "__constants") or {}

			-- Get all methods (excluding OOP framework methods)
			result.methods = oop.getMethods(obj, true, true)

			-- Check if it's an instance
		elseif obj.instanceof and isCallable(obj.instanceof) then
			result.isInstance = true
			local mt = getmetatable(obj)
			local classRef = mt and mt.__index

			-- Handle profiling case where __index is a function
			if type(classRef) == "function" then
				-- In profiling mode, use the stored class reference
				classRef = obj.__class
			end

			if classRef then
				result.className = rawget(classRef, "__name")
				result.superClass = rawget(classRef, "__super")
				result.properties = rawget(classRef, "__properties") or {}
				result.mixins = rawget(classRef, "__mixins") or {}
				result.constants = rawget(classRef, "__constants") or {}
			end

			-- Get instance-specific properties
			local instanceValues = rawget(obj, "__propertyValues")
			if instanceValues then
				for name, value in next, instanceValues do
					result.properties[name] = {
						value = value,
						isExplicit = rawget(obj, "__propertyExplicitSet") and rawget(obj, "__propertyExplicitSet")[name],
					}
				end
			end

			-- Get instance methods
			result.methods = {}
			for key, value in next, obj do
				if isCallable(value) and string_sub(key, 1, 2) ~= "__" then
					result.methods[key] = value
				end
			end

			-- Check if it's an interface
		elseif oop.isInterface(obj) then
			result.isInterface = true
			result.className = rawget(obj, "__name")
			result.methods = rawget(obj, "__requiredMethods") or {}

			-- Check if it's an enum
		elseif oop.isEnum(obj) then
			result.isEnum = true
			result.className = rawget(obj, "__name")
			result.properties = rawget(obj, "__values") or {}

			-- Check if it's a mixin
		elseif oop.isMixin(obj) then
			result.isMixin = true
			result.className = rawget(obj, "__name")

			-- Get mixin methods
			result.methods = {}
			for key, value in next, obj do
				if isCallable(value) and string_sub(key, 1, 2) ~= "__" then
					result.methods[key] = value
				end
			end
		end
	end

	return result
end

-- Get method signature information
function oop.getMethodSignature(class, methodName)
	assertParameter(class ~= nil, "getMethodSignature", "class", "non-nil", class)
	assertParameter(istable(class), "getMethodSignature", "class", "a table", class)
	assertParameter(methodName ~= nil, "getMethodSignature", "methodName", "non-nil", methodName)
	assertParameter(type(methodName) == "string", "getMethodSignature", "methodName", "a string", methodName)

	local method = class[methodName]
	if not isCallable(method) then
		return nil
	end

	-- Try to get parameter info from debug library if available
	local paramInfo = {}
	if debug and debug.getinfo then
		local info = debug.getinfo(method, "u")
		if info and info.nparams then
			paramInfo.parameterCount = info.nparams
			paramInfo.isVararg = info.isvararg
		end
	end

	-- Get method source location if available
	if debug and debug.getinfo then
		local info = debug.getinfo(method, "Sl")
		if info then
			paramInfo.source = info.source
			paramInfo.line = info.linedefined
			paramInfo.shortSrc = info.short_src
		end
	end

	-- Test method with different argument counts to infer arity
	if not paramInfo.parameterCount then
		local success
		paramInfo.parameterCount = 0
		while paramInfo.parameterCount < 10 do -- Limit to reasonable number
			success = pcall(method, {})
			if success then
				paramInfo.parameterCount = paramInfo.parameterCount + 1
			else
				break
			end
		end
	end

	return {
		name = methodName,
		isCallable = true,
		parameters = paramInfo,
		class = rawget(class, "__name") or "Unknown",
	}
end

-- Get inheritance hierarchy
function oop.getInheritanceChain(obj)
	assertParameter(obj ~= nil, "getInheritanceChain", "obj", "non-nil", obj)
	assertParameter(istable(obj), "getInheritanceChain", "obj", "a table", obj)

	local chain = {}

	-- Get the starting class
	local currentClass
	if oop.isClass(obj) then
		currentClass = obj
	elseif obj.instanceof and isCallable(obj.instanceof) then
		local mt = getmetatable(obj)
		currentClass = mt and mt.__index

		-- Handle profiling case where __index is a function
		if type(currentClass) == "function" then
			-- In profiling mode, use the stored class reference
			currentClass = obj.__class
		end
	end

	-- Walk up the inheritance chain
	while currentClass do
		table_insert(chain, {
			name = rawget(currentClass, "__name") or "Anonymous",
			class = currentClass,
			isAbstract = rawget(currentClass, "__isAbstract") or false,
			isInterface = rawget(currentClass, "__isInterface") or false,
		})
		currentClass = rawget(currentClass, "__super")
	end

	return chain
end

-- Get class dependencies (mixins, interfaces, etc.)
function oop.getDependencies(class)
	assertParameter(class ~= nil, "getDependencies", "class", "non-nil", class)
	assertParameter(istable(class), "getDependencies", "class", "a table", class)

	local deps = {
		mixins = {},
		interfaces = {},
		superClass = nil,
		subClasses = {},
	}

	-- Get mixins
	local mixins = rawget(class, "__mixins")
	if mixins then
		for _, mixin in next, mixins do
			table_insert(deps.mixins, {
				name = rawget(mixin, "__name") or "Unknown",
				mixin = mixin,
			})
		end
	end

	-- Get interfaces (check if class implements any)
	-- This would need to be tracked separately in a real implementation

	-- Get superclass
	deps.superClass = rawget(class, "__super")

	-- Find subclasses (this is expensive - would need global tracking)
	-- For now, return empty

	return deps
end

-- Profile method performance
function oop.profileMethod(class, methodName, iterations)
	assertParameter(class ~= nil, "profileMethod", "class", "non-nil", class)
	assertParameter(istable(class), "profileMethod", "class", "a table", class)
	assertParameter(methodName ~= nil, "profileMethod", "methodName", "non-nil", methodName)
	assertParameter(type(methodName) == "string", "profileMethod", "methodName", "a string", methodName)

	iterations = iterations or 1000

	local method = class[methodName]
	if not isCallable(method) then
		return nil, "Method not found or not callable"
	end

	local instance = class:new()
	local args = {}

	-- Warm up
	for i = 1, 100 do
		pcall(method, instance, table_unpack(args))
	end

	-- Profile
	local startTime = os_clock()
	for i = 1, iterations do
		pcall(method, instance, table_unpack(args))
	end
	local endTime = os_clock()

	return {
		methodName = methodName,
		iterations = iterations,
		totalTime = endTime - startTime,
		averageTime = (endTime - startTime) / iterations,
		callsPerSecond = iterations / (endTime - startTime),
	}
end

----------------------------------------------------------------------
-- Serialization Support
----------------------------------------------------------------------

-- Enhanced deep copy with serialization support for circular references
local function serializeValue(value, context, seen)
	context = context or { refs = {}, objects = {} }
	seen = seen or {}

	local valueType = type(value)

	-- Handle primitive types
	if valueType == "nil" or valueType == "boolean" or valueType == "number" or valueType == "string" then
		return value
	end

	-- Handle functions (usually not serialized, but we'll store reference)
	if valueType == "function" then
		return {
			__type = "function",
			__ref = tostring(value),
		}
	end

	-- Handle tables with circular reference detection
	if valueType == "table" then
		-- Check if we've seen this table before (circular reference)
		if seen[value] then
			return {
				__type = "reference",
				__ref = seen[value],
			}
		end

		-- Mark as seen for circular reference detection
		seen[value] = #context.refs + 1
		table_insert(context.refs, seen[value])

		local result = {}

		-- Check if it's a special OOP object
		if oop.isClass(value) then
			result.__type = "class"
			result.__name = rawget(value, "__name")
			result.__super = rawget(value, "__super") and serializeValue(rawget(value, "__super"), context, seen)
		elseif oop.isInterface(value) then
			result.__type = "interface"
			result.__name = rawget(value, "__name")
		elseif oop.isEnum(value) then
			result.__type = "enum"
			result.__name = rawget(value, "__name")
			result.__values = rawget(value, "__values") and serializeValue(rawget(value, "__values"), context, seen)
		elseif oop.isMixin(value) then
			result.__type = "mixin"
			result.__name = rawget(value, "__name")
		else
			result.__type = "table"
		end

		-- Serialize all key-value pairs
		for k, v in next, value do
			-- Skip private OOP properties
			if type(k) ~= "string" or string_sub(k, 1, 2) ~= "__" then
				result[k] = serializeValue(v, context, seen)
			end
		end

		-- Handle metatable
		local mt = getmetatable(value)
		if mt then
			result.__metatable = serializeValue(mt, context, seen)
		end

		return result
	end

	-- Handle other types (userdata, thread, etc.)
	return {
		__type = valueType,
		__value = tostring(value),
	}
end

-- Serialize an object or class
function oop.serialize(obj, options)
	options = options or {}
	local format = options.format or "table"
	local includePrivate = options.includePrivate or false -- TODO
	local maxDepth = options.maxDepth or 100

	local context = { refs = {}, objects = {}, depth = 0 }

	local function serializeWithDepth(value, depth)
		if depth > maxDepth then
			return { __type = "max_depth_exceeded" }
		end

		context.depth = depth
		return serializeValue(value, context, {})
	end

	local result = serializeWithDepth(obj, 0)

	-- Add serialization metadata
	result.__serialization = {
		format = format,
		timestamp = os.time(),
		version = "1.1",
		maxDepth = maxDepth,
	}
	return result
end

-- Deserialize an object or class
function oop.deserialize(data, options)
	options = options or {}
	local format = options.format or "table" -- TODO: Custom formatter support

	if type(data) ~= "table" or not data.__serialization then
		return nil, createError(ERROR_CODES.SERIALIZATION_ERROR, "Invalid serialized data format")
	end

	local context = { objects = {}, refs = {} }

	local function deserializeValue(value)
		local valueType = type(value)
		if valueType ~= "table" then
			return value
		end

		-- Handle special serialized types
		if value.__type then
			if value.__type == "reference" then
				return context.objects[value.__ref]
			end
			if value.__type == "function" then
				return nil -- Functions cannot be deserialized safely
			end
			if value.__type == "max_depth_exceeded" then
				return nil -- Max depth exceeded
			end
			-- Special OOP object types
			local obj

			if value.__type == "class" then
				-- Would need to reconstruct class - complex and potentially unsafe
				return nil
			end
			if value.__type == "interface" then
				return nil
			end
			if value.__type == "enum" then
				-- TODO/FIXME
				return nil
			end
			if value.__type == "mixin" then
				return nil
			end
			return value
		end

		-- Handle regular tables
		local result = {}
		context.objects[#context.objects + 1] = result

		for k, v in next, value do
			result[k] = deserializeValue(v)
		end

		-- Restore metatable if present
		if value.__metatable then
			setmetatable(result, deserializeValue(value.__metatable))
		end

		return result
	end

	return deserializeValue(data)
end

-- Convert serialized data to JSON string (basic implementation)
local function escapeString(str)
	return string_gsub(
		string_gsub(
			string_gsub(
				string_gsub(
					string_gsub(
						str, "\\", "\\\\"
					), '"', '\\"'
				), "\n", "\\n"
			), "\r", "\\r"
		), "\t", "\\t"
	)
end
local serializeToJSON
local function serializeTableToJSON(value, depth, indent, pretty)
	local indentStr = pretty and string_rep(indent, depth) or ""
	if value.__type then
		-- Handle special serialized types
		return '"{' .. value.__type .. '}"'
	end
	local isArray = true
	local maxIndex = 0
	for k in next, value do
		if type(k) ~= "number" or k < 1 or k > maxIndex or math_floor(k) ~= k then
			isArray = false
			break
		end
		maxIndex = math_max(maxIndex, k)
	end
	if isArray and #value > 0 then
		-- Array format
		local result = {}
		for i = 1, #value do
			table_insert(result, indentStr .. serializeToJSON(value[i], depth + 1))
		end
		return "[\n" .. table_concat(result, ",\n") .. "\n" .. indentStr .. "]"
	end
	-- Object format
	local result = {}
	for k, v in next, value do
		table_insert(result, indentStr .. '"' .. tostring(k) .. '": ' .. serializeToJSON(v, depth + 1))
	end
	return "{\n" .. table_concat(result, ",\n") .. "\n" .. indentStr .. "}"
end

local serializeToJsonTypeHandlers = {
	["nil"] = function(v) return "null" end,
	["boolean"] = function(v) return v and "true" or "false" end,
	["number"] = function(v) return tostring(v) end,
	["string"] = function(v) return '"' .. escapeString(v) .. '"' end,
	["table"] = serializeTableToJSON,
}
function serializeToJSON(value, depth, indent, pretty)
	local handler = serializeToJsonTypeHandlers[type(value)]
	if handler then
		return handler(value, depth, indent, pretty)
	end
	-- Other types (functions, userdata, etc.)
	return '"' .. tostring(value) .. '"'
end

function oop.toJSON(data, options)
	options = options or {}
	local indent = options.indent or 0
	local pretty = options.pretty or false
	return serializeToJSON(data, 0, indent, pretty)
end

----------------------------------------------------------------------
-- Performance Profiling System
----------------------------------------------------------------------

-- Profiling state (accessible through oop table)
oop._profiling = {
	enabled = false,
	data = {
		methodCalls = {},
		memoryUsage = {},
		classInstances = {},
		startTime = 0,
		totalTime = 0,
	},
}

-- Get current memory usage
local function getMemoryUsage()
	collectgarbage("collect")
	return collectgarbage("count")
end

-- Start profiling
function oop.enableProfiling()
	oop._profiling.enabled = true
	oop._profiling.data.methodCalls = {}
	oop._profiling.data.memoryUsage = {}
	oop._profiling.data.classInstances = {}
	oop._profiling.data.startTime = os_clock()
	oop._profiling.data.totalTime = 0
	return true
end

-- Stop profiling
function oop.disableProfiling()
	if oop._profiling.enabled then
		oop._profiling.data.totalTime = os_clock() - oop._profiling.data.startTime
		oop._profiling.enabled = false
	end
	return false
end

-- Check if profiling is enabled
function oop.isProfilingEnabled()
	return oop._profiling.enabled
end

-- Get profile data
function oop.getProfileData()
	if oop._profiling.enabled then
		oop._profiling.data.totalTime = os_clock() - oop._profiling.data.startTime
	end

	-- Calculate statistics
	local stats = {
		totalTime = oop._profiling.data.totalTime,
		totalMethodCalls = 0,
		averageCallTime = 0,
		memoryUsed = getMemoryUsage(),
		classInstanceCounts = {},
		methodCallStats = {},
	}

	-- Count total method calls and calculate averages
	for methodName, calls in next, oop._profiling.data.methodCalls do
		local totalCalls = #calls
		local totalTime = 0
		local minTime = math.huge
		local maxTime = 0

		for i = 1, totalCalls do
			local call = calls[i]
			totalTime = totalTime + call.duration
			if call.duration < minTime then minTime = call.duration end
			if call.duration > maxTime then maxTime = call.duration end
		end

		stats.totalMethodCalls = stats.totalMethodCalls + totalCalls
		stats.methodCallStats[methodName] = {
			callCount = totalCalls,
			totalTime = totalTime,
			averageTime = totalTime / totalCalls,
			minTime = minTime,
			maxTime = maxTime,
		}
	end

	if stats.totalMethodCalls > 0 then
		stats.averageCallTime = oop._profiling.data.totalTime / stats.totalMethodCalls
	end

	-- Count class instances
	for className, instances in next, oop._profiling.data.classInstances do
		stats.classInstanceCounts[className] = #instances
	end

	return stats
end

-- Clear profile data
function oop.clearProfileData()
	oop._profiling.data.methodCalls = {}
	oop._profiling.data.memoryUsage = {}
	oop._profiling.data.classInstances = {}
	oop._profiling.data.startTime = oop._profiling.enabled and os_clock() or 0
	oop._profiling.data.totalTime = 0
end

----------------------------------------------------------------------
-- Async/Await Utilities
----------------------------------------------------------------------

-- Export async/await functions
oop.Promise = Promise
oop.promise = Promise
oop.await = await
oop.parallel = parallel
oop.sequence = sequence
oop.race = race
oop.timeout = timeout
oop.delay = delay
oop.createCoroutinePool = createCoroutinePool
oop.Stream = Stream

-- Async helper utilities
oop.promisify = function(func, self)
	assertParameter(isCallable(func), "oop.promisify", "func", "function", func, 2)

	return function(...)
		local args = table_pack(...)

		return Promise(function(resolve, reject)
			-- Replace the last callback argument with our promise resolver
			local function callback(success, ...)
				if success then
					resolve(table_pack(...))
				else
					reject(...)
				end
			end

			-- Call original function with our callback
			if self then
				func(self, table_unpack(args, 1, args.n - 1), callback)
			else
				func(table_unpack(args, 1, args.n - 1), callback)
			end
		end)
	end
end
oop.Promisify = oop.promisify

oop.promisifyMethod = function(func)
	assertParameter(isCallable(func), "oop.promisifyMethod", "func", "function", func, 2)

	return function(self, ...)
		local args = table_pack(...)

		return Promise(function(resolve, reject)
			-- Replace the last callback argument with our promise resolver
			local function callback(success, ...)
				if success then
					resolve(table_pack(...))
				else
					reject(...)
				end
			end

			-- Call original method with our callback
			func(self, table_unpack(args, 1, args.n - 1), callback)
		end)
	end
end
oop.PromisifyMethod = oop.promisifyMethod

-- Convert a value to a promise if it isn't already
oop.resolve = function(value)
	if type(value) == "table" and value.andThen and isCallable(value.andThen) then
		return value
	end
	return Promise(function(resolve) resolve(value) end)
end

-- Create a rejected promise
oop.reject = function(reason)
	return Promise(function(_, reject) reject(reason) end)
end

-- Wait for all promises to settle (regardless of outcome)
oop.allSettled = function(promises)
	assertParameter(istable(promises), "oop.allSettled", "promises", "table", promises, 2)

	return Promise(function(resolve)
		local results = {}
		local completed = 0
		local total = #promises

		if total == 0 then
			resolve(results)
			return
		end

		for i = 1, total do
			local promise = promises[i]
			if type(promise) ~= "table" or not promise.andThen or not isCallable(promise.andThen) then
				-- Convert non-promise values to resolved promises
				promise = Promise(function(resolve) resolve(promise) end)
			end

			promise:andThen(function(value)
				results[i] = { status = PROMISE_STATES.FULFILLED, value = value }
				completed = completed + 1
				if completed == total then
					resolve(results)
				end
			end):catch(function(reason)
				results[i] = { status = PROMISE_STATES.REJECTED, reason = reason }
				completed = completed + 1
				if completed == total then
					resolve(results)
				end
			end)
		end
	end)
end

----------------------------------------------------------------------
-- Retry Utilities
----------------------------------------------------------------------

-- Retry function with configurable strategies for async operations
local function retry(optionsOrFunc, funcOrMaxRetries, maxRetriesOrNil)
	local options, func, maxRetries

	-- Handle different calling patterns:
	-- 1. retry(func, maxRetries)
	-- 2. retry(options, func)
	-- 3. retry(func) - with default options
	if type(optionsOrFunc) == "table" then
		-- Pattern 2: retry(options, func)
		options = optionsOrFunc
		func = funcOrMaxRetries
		maxRetries = maxRetriesOrNil
	else
		-- Pattern 1 or 3: retry(func, maxRetries?) or retry(func)
		func = optionsOrFunc
		maxRetries = funcOrMaxRetries
		options = {}
	end

	assertParameter(isCallable(func), "oop.retry", "func", "function", func, 2)

	-- Set defaults
	maxRetries = maxRetries or options.maxRetries or 3
	local delay = options.delay or 1000      -- milliseconds
	local backoff = options.backoff or "linear" -- "linear", "exponential", or "fixed"
	local maxDelay = options.maxDelay or 30000 -- 30 seconds max
	local retryCondition = options.retryCondition or function(error) return true end
	local onRetry = options.onRetry or function(attempt, error, delay) end
	local timeout = options.timeout
	local jitter = options.jitter or false

	return Promise(function(resolve, reject)
		local attempt = 0
		local lastError

		local function executeAttempt()
			attempt = attempt + 1

			local promise
			-- Create the operation promise
			if timeout then
				promise = oop.timeout(Promise(function(res, rej)
					local ok, result = pcall(func)
					if ok then
						res(result)
					else
						rej(result)
					end
				end), timeout)
			else
				promise = Promise(function(res, rej)
					local ok, result = pcall(func)
					if ok then
						res(result)
					else
						rej(result)
					end
				end)
			end

			promise:andThen(function(result)
				resolve(result)
			end):catch(function(error)
				lastError = error

				-- Check if we should retry
				local shouldRetry = attempt < maxRetries and retryCondition(error)

				if shouldRetry then
					-- Calculate delay for next attempt
					local nextDelay = delay

					if backoff == "exponential" then
						nextDelay = delay * (2 ^ (attempt - 1))
					elseif backoff == "linear" then
						nextDelay = delay * attempt
					end

					-- Apply max delay limit
					nextDelay = math_min(nextDelay, maxDelay)

					-- Add jitter if enabled (±25% random variation)
					if jitter then
						local jitterAmount = nextDelay * 0.25
						nextDelay = nextDelay + (math_random() * 2 - 1) * jitterAmount
						nextDelay = math_max(0, nextDelay) -- Ensure non-negative
					end

					-- Call retry callback
					onRetry(attempt, error, nextDelay)

					-- Schedule next attempt
					oop.delay(nextDelay):andThen(function()
						executeAttempt()
					end)
				else
					-- No more retries, reject with last error
					reject(lastError)
				end
			end)
		end

		executeAttempt()
	end)
end

-- Convenience retry methods for common patterns
local function retryNTimes(func, maxRetries, delay)
	return retry(func, maxRetries, delay or 1000)
end

local function retryWithBackoff(func, maxRetries, baseDelay, maxDelay)
	return retry({
		maxRetries = maxRetries,
		delay = baseDelay or 1000,
		backoff = "exponential",
		maxDelay = maxDelay or 30000
	}, func)
end

local function retryUntil(func, condition, maxRetries, delay)
	return retry({
		maxRetries = maxRetries or 10,
		delay = delay or 1000,
		retryCondition = condition
	}, func)
end

-- Export retry functions
oop.retry = retry
oop.retryNTimes = retryNTimes
oop.retryWithBackoff = retryWithBackoff
oop.retryUntil = retryUntil

----------------------------------------------------------------------
-- Throttle Utilities
----------------------------------------------------------------------

-- Throttle function to limit execution frequency
local function throttle(func, delay, options)
	assertParameter(isCallable(func), "oop.throttle", "func", "function", func, 2)
	assertParameter(type(delay) == "number" and delay > 0, "oop.throttle", "delay", "positive number", delay, 2)

	options = options or {}
	local leading = options.leading ~= false -- default to true (execute on leading edge)
	local trailing = options.trailing ~= false -- default to true (execute on trailing edge)
	local maxWait = options.maxWait         -- maximum wait time before forced execution

	local lastCallTime = 0
	local lastInvokeTime = 0
	local timerId, lastArgs, lastThis, result

	local function invokeFunc()
		lastInvokeTime = os_clock()
		if lastArgs then
			result = func(table_unpack(lastArgs, 1, lastArgs.n))
			lastArgs = nil
			lastThis = nil
		end
		timerId = nil
	end

	local function shouldWait(currentTime)
		local timeSinceLastCall = currentTime - lastCallTime
		local timeSinceLastInvoke = currentTime - lastInvokeTime

		return timeSinceLastCall < delay and timeSinceLastInvoke > 0
	end

	local function startTimer(pendingFunc, wait)
		if timerId then return end

		timerId = oop.delay(wait):andThen(function()
			pendingFunc()
		end)
	end

	local function trailingEdge(currentTime)
		timerId = nil

		if trailing and lastArgs then
			invokeFunc()
		end
		lastArgs = nil
		lastThis = nil
	end

	local function remainingWait(currentTime)
		local timeSinceLastCall = currentTime - lastCallTime
		local timeSinceLastInvoke = currentTime - lastInvokeTime

		return delay - timeSinceLastCall
	end

	return function(...)
		local currentTime = os_clock()
		local args = table_pack(...)

		lastArgs = args
		lastThis = nil -- No 'this' context in Lua
		lastCallTime = currentTime

		local isInvoking = shouldWait(currentTime)

		if isInvoking then
			if maxWait and not timerId then
				local timeSinceLastInvoke = currentTime - lastInvokeTime
				if timeSinceLastInvoke >= maxWait then
					invokeFunc()
					return result
				end
			end

			if not timerId then
				startTimer(function() trailingEdge(currentTime) end, remainingWait(currentTime))
			end
			return result
		end

		if leading and not timerId then
			startTimer(function() trailingEdge(currentTime) end, delay)
		end

		if leading and not timerId and not trailing then
			invokeFunc()
			return result
		end

		return result
	end
end

-- Debounce function (complementary to throttle)
local function debounce(func, delay, options)
	assertParameter(isCallable(func), "oop.debounce", "func", "function", func, 2)
	assertParameter(type(delay) == "number" and delay > 0, "oop.debounce", "delay", "positive number", delay, 2)

	options = options or {}
	local leading = options.leading == true -- default to false for debounce
	local maxWait = options.maxWait      -- maximum wait time before forced execution

	local lastCallTime = 0
	local lastInvokeTime = 0
	local timerId, lastArgs, lastThis, result

	local function invokeFunc()
		lastInvokeTime = os_clock()
		if lastArgs then
			result = func(table_unpack(lastArgs, 1, lastArgs.n))
			lastArgs = nil
			lastThis = nil
		end
		timerId = nil
	end

	local function shouldWait(currentTime)
		local timeSinceLastCall = currentTime - lastCallTime
		return timeSinceLastCall < delay
	end

	local function startTimer(pendingFunc, wait)
		if timerId then return end
		timerId = oop.delay(wait):andThen(function()
			pendingFunc()
		end)
	end

	local function trailingEdge(currentTime)
		timerId = nil

		if lastArgs then
			invokeFunc()
		end
		lastArgs = nil
		lastThis = nil
	end

	local function leadingEdge(currentTime)
		lastInvokeTime = currentTime
		timerId = nil

		if leading then
			invokeFunc()
		end
	end

	return function(...)
		local currentTime = os_clock()
		local args = table_pack(...)

		lastArgs = args
		lastThis = nil -- No 'this' context in Lua
		lastCallTime = currentTime

		local isInvoking = shouldWait(currentTime)

		if not isInvoking and not timerId then
			leadingEdge(currentTime)
			return result
		end

		if not timerId then
			local wait = delay
			if maxWait then
				local timeSinceLastInvoke = currentTime - lastInvokeTime
				wait = math_min(delay, maxWait - timeSinceLastInvoke)
			end

			startTimer(function() trailingEdge(currentTime) end, wait)
		end

		return result
	end
end

-- Rate limiter for controlling execution frequency
local function rateLimit(func, callsPerSecond, options)
	assertParameter(isCallable(func), "oop.rateLimit", "func", "function", func, 2)
	assertParameter(type(callsPerSecond) == "number" and callsPerSecond > 0, "oop.rateLimit", "callsPerSecond",
		"positive number", callsPerSecond, 2)

	options = options or {}
	local maxQueueSize = options.maxQueueSize or 100
	local dropExcess = options.dropExcess or false

	local interval = 1000 / callsPerSecond -- milliseconds between calls
	local lastExecution = 0
	local queue = {}
	local queueSize = 0

	local function processQueue()
		if queueSize == 0 then return end

		local currentTime = os_clock()
		if currentTime - lastExecution >= interval / 1000 then
			local nextCall = table_remove(queue, 1)
			queueSize = queueSize - 1

			if nextCall then
				lastExecution = currentTime
				local ok, result = pcall(nextCall.func, table_unpack(nextCall.args, 1, nextCall.args.n))
				if nextCall.resolve then
					if ok then
						nextCall.resolve(result)
					else
						nextCall.reject(result)
					end
				end
			end
		end

		if queueSize > 0 then
			oop.delay(interval / 2):andThen(processQueue)
		end
	end

	return function(...)
		local args = table_pack(...)

		if dropExcess and queueSize >= maxQueueSize then
			if options.onDropped then
				options.onDropped(args)
			end
			return nil
		end

		if queueSize >= maxQueueSize then
			return error("Rate limit queue exceeded maximum size of " .. maxQueueSize, 2)
		end

		return Promise(function(resolve, reject)
			table_insert(queue, {
				func = func,
				args = args,
				resolve = resolve,
				reject = reject
			})
			queueSize = queueSize + 1

			if queueSize == 1 then
				processQueue()
			end
		end)
	end
end

-- Export throttle functions
oop.throttle = throttle
oop.debounce = debounce
oop.rateLimit = rateLimit

----------------------------------------------------------------------
-- Try-Catch-Finally Utilities
----------------------------------------------------------------------

-- Export try-catch-finally functions
oop.try = try
oop.async = async
oop.safeCall = safe_call
oop.tryAll = try_all

-- Export copy functions
oop.deepCopy = deepClone

-- Aliases
oop.Class = oop.class
oop.AbstractClass = oop.abstractClass
oop.Property = oop.property
oop.Enum = oop.enum
oop.EnumFlags = oop.enumFlags
oop.EnumFromArray = oop.enumFromArray
oop.EnumFromTable = oop.enumFromTable
oop.Interface = oop.interface
oop.Mixin = oop.mixin
oop.Trait = oop.trait
oop.PrivateMethod = oop.privateMethod
oop.ProtectedMethod = oop.protectedMethod
oop.PublicMethod = oop.publicMethod
oop.EventEmitter = oop.eventEmitter

----------------------------------------------------------------------
-- Freeze/Immutable Table System
----------------------------------------------------------------------

-- Make a table immutable by preventing any modifications after freezing
-- This creates true constants by using metatable __newindex and __index to block changes
function oop.freeze(tbl)
	assertParameter(tbl ~= nil, "freeze", "table", "non-nil", tbl)
	assertParameter(type(tbl) == "table", "freeze", "table", "a table", tbl)

	-- Check if already frozen
	local mt = getmetatable(tbl)
	if mt and mt.__isFrozen then
		return tbl
	end

	-- Store original metatable if it exists
	local originalMetatable = mt or {}
	local originalIndex = originalMetatable.__index

	-- Create new metatable with freeze protection
	local freezeMetatable = {}

	-- Copy all existing metatable fields
	for k, v in next, originalMetatable do
		freezeMetatable[k] = v
	end

	-- Store the original table data in a hidden storage
	local frozenData = {}
	for k, v in next, tbl do
		frozenData[k] = v
	end

	-- Override __index to provide read-only access from frozenData
	freezeMetatable.__index = function(t, key)
		-- Always check frozen data first (this is the authoritative source)
		if frozenData[key] ~= nil then
			return frozenData[key]
		end

		-- Fall back to original __index if it exists
		if originalIndex then
			if type(originalIndex) == "table" then
				return originalIndex[key]
			end
			return originalIndex(t, key)
		end

		return nil
	end

	-- Override __newindex to prevent all modifications
	freezeMetatable.__newindex = function(t, key, value)
		return error(
			"Cannot modify frozen table - attempted to set '" .. tostring(key) .. "' to '" .. tostring(value) .. "'", 2)
	end

	-- Override __pairs to preserve iteration functionality using frozenData
	freezeMetatable.__pairs = function(t)
		return next, frozenData
	end

	-- Override __ipairs for array-style iteration if needed
	freezeMetatable.__ipairs = function(t)
		return ipairs(frozenData)
	end

	-- Mark as frozen
	freezeMetatable.__isFrozen = true
	freezeMetatable.__frozenData = frozenData

	-- Clear the original table completely to ensure all access goes through metatable
	for k in next, tbl do
		rawset(tbl, k, nil)
	end

	-- Set the new metatable
	setmetatable(tbl, freezeMetatable)

	return tbl
end

-- Check if a table is frozen
function oop.isFrozen(table)
	assertParameter(table ~= nil, "isFrozen", "table", "non-nil", table)
	assertParameter(type(table) == "table", "isFrozen", "table", "a table", table)

	local mt = getmetatable(table)
	return mt and mt.__isFrozen == true
end

-- Safe table insert that respects frozen tables
function oop.tableInsert(table, ...)
	assertParameter(table ~= nil, "tableInsert", "table", "non-nil", table)
	assertParameter(type(table) == "table", "tableInsert", "table", "a table", table)

	if oop.isFrozen(table) then
		return error("Cannot modify frozen table - table.insert not allowed", 2)
	end

	return table_insert(table, ...)
end

-- Safe table remove that respects frozen tables
function oop.tableRemove(table, ...)
	assertParameter(table ~= nil, "tableRemove", "table", "non-nil", table)
	assertParameter(type(table) == "table", "tableRemove", "table", "a table", table)

	if oop.isFrozen(table) then
		return error("Cannot modify frozen table - table.remove not allowed", 2)
	end

	return table_remove(table, ...)
end

----------------------------------------------------------------------
-- HOOKING/DETOURING (MONKEY PATCHING) SYSTEM
----------------------------------------------------------------------

-- Hook registry to track all active hooks (using weak references)
local hookRegistry = setmetatable({}, { __mode = "v" }) -- Values are weak
local hookIdCounter = 0
local globalHookList = {}                               -- Global list of all hooks for bulk operations

-- Generate unique hook ID
local function generateHookId()
	hookIdCounter = hookIdCounter + 1
	return "~hook_" .. hookIdCounter
end

-- Hook types
local HOOK_TYPES = {
	BEFORE = "BEFORE", -- Execute before original function
	AFTER = "AFTER",  -- Execute after original function
	REPLACE = "REPLACE", -- Replace original function entirely
	AROUND = "AROUND" -- Wrap original function with custom logic
}

local function HookSort(a, b)
	return a.priority > b.priority
end

-- Hook a function with specified type
function oop.hook(target, hookType, hookFunc, options)
	options = options or {}

	-- Validate parameters
	assertParameter(target ~= nil, "hook", "target", "non-nil", target)
	assertParameter(type(target) == "function", "hook", "target", "a function", target)
	hookType = string_upper(hookType)
	assertParameter(HOOK_TYPES[hookType], "hook", "hookType",
		"valid hook type (before, after, replace, around)",
		hookType)
	assertParameter(type(hookFunc) == "function", "hook", "hookFunc", "a function", hookFunc)

	local hookId = generateHookId()
	local priority = options.priority or 0
	local name = options.name or hookId

	-- Initialize hook registry for this target if needed
	if not hookRegistry[target] then
		hookRegistry[target] = {
			original = target,
			hooks = {
				BEFORE = {},
				AFTER = {},
				REPLACE = {},
				AROUND = {}
			},
			active = true
		}
	end

	-- Register the hook
	local hookInfo = {
		id = hookId,
		func = hookFunc,
		priority = priority,
		name = name,
		active = true,
		target = target,
		hookType = hookType
	}

	table_insert(hookRegistry[target].hooks[hookType], hookInfo)

	-- Add to global hook list for bulk operations
	globalHookList[hookId] = hookInfo

	-- Sort hooks by priority (higher priority first)
	table_sort(hookRegistry[target].hooks[hookType], HookSort)

	-- Create the hooked function if this is the first hook of any type
	local totalHooks = 0
	for _, hooks in next, hookRegistry[target].hooks do
		totalHooks = totalHooks + #hooks
	end

	if totalHooks == 1 then
		oop._createHookedFunction(target)
	end

	return hookId
end

-- Create the actual hooked function that replaces the original
function oop._createHookedFunction(originalFunc)
	local registry = hookRegistry[originalFunc]
	if not registry then return end

	-- Store the original function in the registry
	registry.originalFunction = originalFunc

	-- Create the hooked function
	local hookedFunc = function(...)
		if not registry.active then
			return registry.originalFunction(...)
		end

		local args = table_pack(...)

		-- Execute BEFORE hooks
		local tbl = registry.hooks.BEFORE
		for i = 1, #tbl do
			local hookInfo = tbl[i]
			if hookInfo.active then
				local result = table_pack(hookInfo.func(table_unpack(args, 1, args.n)))
				if result.n > 0 then
					-- If before hook returns values, use them as new arguments
					args = result
				end
			end
		end

		-- Check for REPLACE hooks
		local replaceResult
		tbl = registry.hooks.REPLACE
		for i = 1, #tbl do
			local hookInfo = tbl[i]
			if hookInfo.active then
				replaceResult = table_pack(hookInfo.func(table_unpack(args, 1, args.n)))
				break -- Only use first active replace hook
			end
		end

		local originalResult
		if replaceResult and replaceResult.n > 0 then
			originalResult = replaceResult
		else
			-- Execute AROUND hooks or original function
			local aroundExecuted = false
			tbl = registry.hooks.AROUND
			for i = 1, #tbl do
				local hookInfo = tbl[i]
				if hookInfo.active then
					aroundExecuted = true
					originalResult = table_pack(hookInfo.func(registry.originalFunction, table_unpack(args, 1, args.n)))
					break -- Only use first active around hook
				end
			end

			if not aroundExecuted then
				originalResult = table_pack(registry.originalFunction(table_unpack(args, 1, args.n)))
			end
		end

		-- Execute AFTER hooks
		tbl = registry.hooks.AFTER
		for i = 1, #tbl do
			local hookInfo = tbl[i]
			if hookInfo.active then
				local afterResult = table_pack(hookInfo.func(table_unpack(originalResult, 1, originalResult.n)))
				if afterResult.n > 0 then
					-- If after hook returns values, use them as final result
					originalResult = afterResult
				end
			end
		end

		return table_unpack(originalResult, 1, originalResult.n)
	end

	-- Store the hooked function reference for cleanup
	registry.hookedFunction = hookedFunc

	-- Replace the original function in the global environment
	-- This is a simple approach - in practice, you might want more sophisticated detection
	oop._replaceFunction(originalFunc, hookedFunc)
end

-- Replace a function reference (simplified implementation)
function oop._replaceFunction(oldFunc, newFunc)
	-- Store the mapping for proper restoration
	hookRegistry[oldFunc].replacement = newFunc

	-- Search through global environment for references to oldFunc
	for key, value in next, _G do
		if value == oldFunc then
			_G[key] = newFunc
			hookRegistry[oldFunc].originalLocation = { _G, key }
			return true
		end
	end

	-- Also check common table references
	for _, tbl in next, { string, table, math, os, io, debug, package } do
		if type(tbl) == "table" then
			for key, value in next, tbl do
				if value == oldFunc then
					tbl[key] = newFunc
					hookRegistry[oldFunc].originalLocation = { tbl, key }
					return true
				end
			end
		end
	end

	return false
end

-- Remove a hook
function oop.unhook(target, hookId)
	local registry = hookRegistry[target]
	if not registry then
		return false
	end
	local found = false

	-- Search through all hook types
	for hookType, hooks in next, registry.hooks do
		for i, hookInfo in next, hooks do
			if hookInfo.id == hookId then
				table_remove(hooks, i)
				found = true
				break
			end
		end
		if found then break end
	end

	-- Remove from global hook list
	if found then
		globalHookList[hookId] = nil
	end

	-- If no hooks remain, restore original function
	if found and oop._hasNoHooks(target) then
		oop.restore(target)
	end

	return found
end

-- Check if target has no active hooks
function oop._hasNoHooks(target)
	local registry = hookRegistry[target]
	if not registry then return true end

	for _, hooks in next, registry.hooks do
		if #hooks > 0 then
			return false
		end
	end

	return true
end

-- Restore original function (remove all hooks)
function oop.restore(target)
	local registry = hookRegistry[target]
	if not registry then
		return false
	end

	local originalFunc = registry.original

	-- Remove all hooks from global list
	for _, hooks in next, registry.hooks do
		for _, hookInfo in next, hooks do
			globalHookList[hookInfo.id] = nil
		end
	end

	-- Restore the original function to its original location
	if registry.originalLocation then
		local location = registry.originalLocation
		location[1][location[2]] = originalFunc
	end

	-- Clean up registry
	hookRegistry[target] = nil

	return true
end

-- Enable/disable a specific hook
function oop.setHookEnabled(target, hookId, enabled)
	local registry = hookRegistry[target]
	if not registry then
		return false
	end

	for _, hooks in next, registry.hooks do
		for _, hookInfo in next, hooks do
			if hookInfo.id == hookId then
				hookInfo.active = enabled
				return true
			end
		end
	end

	return false
end

-- Enable/disable all hooks for a target
function oop.setHooksEnabled(target, enabled)
	if not hookRegistry[target] then
		return false
	end

	hookRegistry[target].active = enabled
	return true
end

-- Get information about hooks on a target
function oop.getHookInfo(target)
	local registry = hookRegistry[target]
	if not registry then
		return
	end

	local info = {
		target = target,
		active = registry.active,
		hooks = {}
	}

	for hookType, hooks in next, registry.hooks do
		info.hooks[hookType] = {}
		for _, hookInfo in next, hooks do
			table_insert(info.hooks[hookType], {
				id = hookInfo.id,
				name = hookInfo.name,
				priority = hookInfo.priority,
				active = hookInfo.active
			})
		end
	end

	return info
end

-- List all hooked functions
function oop.listHookedFunctions()
	local hooked = {}

	for target, registry in next, hookRegistry do
		table_insert(hooked, {
			target = target,
			active = registry.active,
			hookCount = oop._getHookCount(target)
		})
	end

	return hooked
end

-- Count total hooks for a target
function oop._getHookCount(target)
	if not hookRegistry[target] then
		return 0
	end

	local count = 0
	for _, hooks in next, hookRegistry[target].hooks do
		count = count + #hooks
	end

	return count
end

-- Convenience methods for common hook types
function oop.hookBefore(target, hookFunc, options)
	return oop.hook(target, "BEFORE", hookFunc, options)
end

function oop.hookAfter(target, hookFunc, options)
	return oop.hook(target, "AFTER", hookFunc, options)
end

function oop.hookReplace(target, hookFunc, options)
	return oop.hook(target, "REPLACE", hookFunc, options)
end

function oop.hookAround(target, hookFunc, options)
	return oop.hook(target, "AROUND", hookFunc, options)
end

-- Hook method on a class or instance
function oop.hookMethod(target, methodName, hookType, hookFunc, options)
	assertParameter(target ~= nil, "hookMethod", "target", "non-nil", target)
	assertParameter(type(methodName) == "string", "hookMethod", "methodName", "a string", methodName)
	hookType = string_upper(hookType)
	assertParameter(HOOK_TYPES[hookType], "hookMethod", "hookType",
		"valid hook type (before, after, replace, around)",
		hookType)
	assertParameter(type(hookFunc) == "function", "hookMethod", "hookFunc", "a function", hookFunc)

	local method = target[methodName]
	if not method or type(method) ~= "function" then
		return error("Target has no method named '" .. methodName .. "'", 2)
	end

	-- Store the original method
	local originalMethod = method

	-- Create the hooked method directly
	local hookedMethod = function(self, ...)
		if not hookRegistry[originalMethod] or not hookRegistry[originalMethod].active then
			return originalMethod(self, ...)
		end

		local args = table_pack(self, ...)

		-- Execute BEFORE hooks
		for _, hookInfo in next, hookRegistry[originalMethod].hooks.BEFORE do
			if hookInfo.active then
				local result = table_pack(hookInfo.func(table_unpack(args, 1, args.n)))
				if result.n > 0 then
					-- If before hook returns values, preserve self as first argument
					if result.n >= 1 then
						args = result
					end
				end
			end
		end

		-- Check for REPLACE hooks
		local replaceResult
		for _, hookInfo in next, hookRegistry[originalMethod].hooks.REPLACE do
			if hookInfo.active then
				replaceResult = table_pack(hookInfo.func(table_unpack(args, 1, args.n)))
				break
			end
		end

		local originalResult
		if replaceResult and replaceResult.n > 0 then
			originalResult = replaceResult
		else
			-- Execute AROUND hooks or original method
			local aroundExecuted = false
			for _, hookInfo in next, hookRegistry[originalMethod].hooks.AROUND do
				if hookInfo.active then
					aroundExecuted = true
					originalResult = table_pack(hookInfo.func(originalMethod, table_unpack(args, 1, args.n)))
					break
				end
			end

			if not aroundExecuted then
				originalResult = table_pack(originalMethod(table_unpack(args, 1, args.n)))
			end
		end

		-- Execute AFTER hooks
		for _, hookInfo in next, hookRegistry[originalMethod].hooks.AFTER do
			if hookInfo.active then
				local afterResult = table_pack(hookInfo.func(table_unpack(originalResult, 1, originalResult.n)))
				if afterResult.n > 0 then
					originalResult = afterResult
				end
			end
		end

		return table_unpack(originalResult, 1, originalResult.n)
	end

	-- Initialize hook registry for this method if needed
	if not hookRegistry[originalMethod] then
		hookRegistry[originalMethod] = {
			original = originalMethod,
			hooks = {
				BEFORE = {},
				AFTER = {},
				REPLACE = {},
				AROUND = {}
			},
			active = true
		}
	end

	-- Register the hook
	local hookId = generateHookId()
	local priority = (options and options.priority) or 0
	local name = (options and options.name) or hookId

	local hookInfo = {
		id = hookId,
		func = hookFunc,
		priority = priority,
		name = name,
		active = true
	}

	table_insert(hookRegistry[originalMethod].hooks[hookType], hookInfo)

	-- Sort hooks by priority
	table_sort(hookRegistry[originalMethod].hooks[hookType], HookSort)

	-- Replace the method with the hooked version
	target[methodName] = hookedMethod

	return hookId
end

-- Create a temporary hook that auto-removes after specified calls
function oop.tempHook(target, hookType, hookFunc, callCount, options)
	options = options or {}
	callCount = callCount or 1

	local remaining = callCount
	local hookId

	local wrapper = function(...)
		remaining = remaining - 1

		local result = hookFunc(...)

		if remaining <= 0 then
			oop.unhook(target, hookId)
		end

		return result
	end

	hookId = oop.hook(target, hookType, wrapper, options)
	return hookId
end

----------------------------------------------------------------------
-- CONVENIENT HOOKING UTILITIES
----------------------------------------------------------------------

-- Hook that executes only once and then auto-removes
function oop.hookOnce(target, hookType, hookFunc, options)
	options = options or {}
	local remaining = 1
	local hookId

	local wrapper = function(...)
		remaining = remaining - 1

		local result = table_pack(hookFunc(...))

		if remaining <= 0 then
			oop.unhook(target, hookId)
		end

		return table_unpack(result, 1, result.n)
	end

	hookId = oop.hook(target, hookType, wrapper, options)
	return hookId
end

-- Hook that executes only once for each unique argument combination
function oop.hookOncePerArgs(target, hookType, hookFunc, options)
	options = options or {}
	local seenArgs = {}
	local hookId

	local wrapper = function(...)
		local args = table_pack(...)
		local key = {}

		-- Create a hashable key from arguments
		for i = 1, args.n do
			local arg = args[i]
			if type(arg) == "table" then
				key[i] = tostring(arg) -- Simplified table hashing
			else
				key[i] = tostring(arg)
			end
		end
		key = table_concat(key, "|")

		if seenArgs[key] then
			return ... -- Already seen these args, pass through
		end

		seenArgs[key] = true

		local result = table_pack(hookFunc(...))

		-- Clean up if we've seen all expected combinations (optional)
		if options.cleanupThreshold and #seenArgs >= options.cleanupThreshold then
			oop.unhook(target, hookId)
		end

		return table_unpack(result, 1, result.n)
	end

	hookId = oop.hook(target, hookType, wrapper, options)
	return hookId
end

-- Hook that executes only when condition is met
function oop.hookWhen(target, hookType, condition, hookFunc, options)
	options = options or {}
	local hookId

	local wrapper = function(...)
		if condition(...) then
			local result = table_pack(hookFunc(...))
			return table_unpack(result, 1, result.n)
		end
		return ... -- Condition not met, pass through
	end

	hookId = oop.hook(target, hookType, wrapper, options)
	return hookId
end

-- Hook that executes only when condition is NOT met
function oop.hookUnless(target, hookType, condition, hookFunc, options)
	options = options or {}
	local hookId

	local wrapper = function(...)
		if not condition(...) then
			local result = table_pack(hookFunc(...))
			return table_unpack(result, 1, result.n)
		else
			return ... -- Condition met, pass through
		end
	end

	hookId = oop.hook(target, hookType, wrapper, options)
	return hookId
end

-- Hook that executes only for specific argument values
function oop.hookForArgs(target, hookType, expectedArgs, hookFunc, options)
	options = options or {}
	local hookId

	local wrapper = function(...)
		local args = table_pack(...)
		local match = true

		if #expectedArgs ~= args.n then
			match = false
		else
			for i = 1, args.n do
				if args[i] ~= expectedArgs[i] then
					match = false
					break
				end
			end
		end

		if match then
			local result = table_pack(hookFunc(...))
			return table_unpack(result, 1, result.n)
		end
		return ... -- Args don't match, pass through
	end

	hookId = oop.hook(target, hookType, wrapper, options)
	return hookId
end

-- Hook that executes only for specific argument types
function oop.hookForTypes(target, hookType, expectedTypes, hookFunc, options)
	options = options or {}
	local hookId

	local wrapper = function(...)
		local args = table_pack(...)
		local match = true

		if #expectedTypes ~= args.n then
			match = false
		else
			for i = 1, args.n do
				if type(args[i]) ~= expectedTypes[i] then
					match = false
					break
				end
			end
		end

		if match then
			local result = table_pack(hookFunc(...))
			return table_unpack(result, 1, result.n)
		end
		return ... -- Types don't match, pass through
	end

	hookId = oop.hook(target, hookType, wrapper, options)
	return hookId
end

-- Hook that measures execution time
function oop.hookTimer(target, hookType, timerFunc, options)
	options = options or {}
	local hookId

	local wrapper = function(...)
		local startTime = os_clock()
		local result = table_pack(...)

		-- Call the timer function with the elapsed time
		local elapsed = os_clock() - startTime
		timerFunc(elapsed, table_unpack(result, 1, result.n))

		return table_unpack(result, 1, result.n)
	end

	hookId = oop.hook(target, hookType, wrapper, options)
	return hookId
end

-- Hook that counts executions
function oop.hookCounter(target, hookType, counterFunc, options)
	options = options or {}
	local count = 0
	local hookId

	local wrapper = function(...)
		count = count + 1
		local result = table_pack(counterFunc(count, ...))
		return table_unpack(result, 1, result.n)
	end

	hookId = oop.hook(target, hookType, wrapper, options)

	-- Store count in registry for external access
	if hookRegistry[target] then
		hookRegistry[target]._counter = count
	end

	return hookId
end

-- Hook that logs function calls
function oop.hookLogger(target, hookType, loggerFunc, options)
	options = options or {}
	local includeResults = options.includeResults or false
	local hookId

	local wrapper = function(...)
		local args = table_pack(...)

		-- Log the call
		loggerFunc("CALL", table_unpack(args, 1, args.n))

		local result = table_pack(...)

		if includeResults then
			loggerFunc("RESULT", table_unpack(result, 1, result.n))
		end

		return table_unpack(result, 1, result.n)
	end

	hookId = oop.hook(target, hookType, wrapper, options)
	return hookId
end

-- Hook that validates inputs
function oop.hookValidator(target, hookType, validatorFunc, options)
	options = options or {}
	local throwError = options.throwError ~= false
	local hookId

	local wrapper = function(...)
		local args = table_pack(...)

		-- Validate inputs
		local isValid, errorMessage = validatorFunc(table_unpack(args, 1, args.n))

		if not isValid then
			if throwError then
				return error("Validation failed: " .. (errorMessage or "Invalid arguments"), 2)
			end
			print("Validation warning: " .. (errorMessage or "Invalid arguments"))
			return ... -- Pass through original arguments
		end

		return ... -- Valid, pass through
	end

	hookId = oop.hook(target, hookType, wrapper, options)
	return hookId
end

-- Hook that transforms inputs
function oop.hookTransformer(target, hookType, transformerFunc, options)
	options = options or {}
	local hookId

	local wrapper = function(...)
		local args = table_pack(...)

		-- Transform inputs
		local transformedArgs = table_pack(transformerFunc(table_unpack(args, 1, args.n)))

		return table_unpack(transformedArgs, 1, transformedArgs.n)
	end

	hookId = oop.hook(target, hookType, wrapper, options)
	return hookId
end

-- Hook that caches results
function oop.hookCache(target, hookType, options)
	options = options or {}
	local cache = {}
	local maxSize = options.maxSize or 100
	local ttl = options.ttl -- Time to live in seconds
	local hookId

	local wrapper = function(...)
		local args = table_pack(...)
		local key = {}

		-- Create cache key from arguments
		for i = 1, args.n do
			local arg = args[i]
			if type(arg) == "table" then
				key[i] = tostring(arg) -- Simplified table hashing
			else
				key[i] = tostring(arg)
			end
		end
		key = table_concat(key, "|")

		-- Check cache
		local cached = cache[key]
		if cached then
			if ttl then
				if os_time() - cached.timestamp <= ttl then
					return table_unpack(cached.result, 1, cached.result.n)
				end
				cache[key] = nil -- Expired
			else
				return table_unpack(cached.result, 1, cached.result.n)
			end
		end

		-- Not in cache, compute and store
		local result = table_pack(...)

		-- Manage cache size
		if #cache >= maxSize then
			-- Simple LRU: remove first entry
			for k in next, cache do
				cache[k] = nil
				break
			end
		end

		cache[key] = {
			result = result,
			timestamp = os_time()
		}

		return table_unpack(result, 1, result.n)
	end

	hookId = oop.hook(target, hookType, wrapper, options)
	return hookId
end

-- Hook that debounces calls (only execute after delay)
function oop.hookDebouncer(target, hookType, delay, hookFunc, options)
	options = options or {}
	local lastCall = 0
	local hookId

	local wrapper = function(...)
		local now = os_clock()

		if now - lastCall >= delay then
			lastCall = now
			local result = table_pack(hookFunc(...))
			return table_unpack(result, 1, result.n)
		end
		return ... -- Debounced, pass through
	end

	hookId = oop.hook(target, hookType, wrapper, options)
	return hookId
end

-- Hook that throttles calls (only execute once per time period)
function oop.hookThrottler(target, hookType, period, hookFunc, options)
	options = options or {}
	local lastExec = 0
	local hookId

	local wrapper = function(...)
		local now = os_clock()

		if now - lastExec >= period then
			lastExec = now
			local result = table_pack(hookFunc(...))
			return table_unpack(result, 1, result.n)
		end
		return ... -- Throttled, pass through
	end

	hookId = oop.hook(target, hookType, wrapper, options)
	return hookId
end

-- Hook that retries failed calls
function oop.hookRetrier(target, hookType, maxRetries, retryDelay, options)
	options = options or {}
	local retryCondition = options.retryCondition or function(success) return not success end
	local hookId

	local wrapper = function(...)
		local args = table_pack(...)
		local attempts = 0
		local success, result

		while attempts <= maxRetries do
			success, result = pcall(function(...)
				return table_pack(...)
			end, table_unpack(args, 1, args.n))

			if not retryCondition(success) then
				return table_unpack(result, 1, result.n)
			end

			attempts = attempts + 1
			if attempts <= maxRetries and retryDelay > 0 then
				-- Simple delay (in a real implementation, you'd use proper async sleep)
				local start = os_clock()
				while os_clock() - start < retryDelay do
					-- TODO/FIXME: Busy wait (not ideal, but works for demonstration)
				end
			end
		end

		-- All retries failed, return last result or error
		if not success then
			return error(result, 2) -- Re-throw the last error
		end

		return table_unpack(result, 1, result.n)
	end

	hookId = oop.hook(target, hookType, wrapper, options)
	return hookId
end

-- Method-specific convenience functions
function oop.hookMethodOnce(target, methodName, hookType, hookFunc, options)
	local method = target[methodName]
	if not method or type(method) ~= "function" then
		return error("Target has no method named '" .. methodName .. "'", 2)
	end

	return oop.hookOnce(method, hookType, hookFunc, options)
end

function oop.hookMethodWhen(target, methodName, hookType, condition, hookFunc, options)
	local method = target[methodName]
	if not method or type(method) ~= "function" then
		return error("Target has no method named '" .. methodName .. "'", 2)
	end

	return oop.hookWhen(method, hookType, condition, hookFunc, options)
end

function oop.hookMethodLogger(target, methodName, loggerFunc, options)
	local method = target[methodName]
	if not method or type(method) ~= "function" then
		return error("Target has no method named '" .. methodName .. "'", 2)
	end

	return oop.hookLogger(method, "BEFORE", loggerFunc, options)
end

function oop.hookMethodValidator(target, methodName, validatorFunc, options)
	local method = target[methodName]
	if not method or type(method) ~= "function" then
		return error("Target has no method named '" .. methodName .. "'", 2)
	end

	return oop.hookValidator(method, "BEFORE", validatorFunc, options)
end

----------------------------------------------------------------------
-- BULK HOOK OPERATIONS
----------------------------------------------------------------------

-- Clear all hooks globally (remove all hooks from all functions)
function oop.clearAllHooks()
	local clearedCount = 0

	-- Get all targets before clearing (since we'll be modifying the registry)
	local targets = {}
	for target, registry in next, hookRegistry do
		table_insert(targets, target)
	end

	-- Restore all targets
	for _, target in next, targets do
		if oop.restore(target) then
			clearedCount = clearedCount + 1
		end
	end

	-- Clear global hook list
	globalHookList = {}

	return clearedCount
end

-- Deactivate all hooks globally (disable without removing)
function oop.deactivateAllHooks()
	local deactivatedCount = 0

	-- Deactivate all registries
	for target, registry in next, hookRegistry do
		if registry.active then
			registry.active = false
			deactivatedCount = deactivatedCount + 1
		end
	end

	-- Deactivate all individual hooks
	for hookId, hookInfo in next, globalHookList do
		if hookInfo.active then
			hookInfo.active = false
			deactivatedCount = deactivatedCount + 1
		end
	end

	return deactivatedCount
end

-- Reactivate all hooks globally (enable all disabled hooks)
function oop.reactivateAllHooks()
	local reactivatedCount = 0

	-- Reactivate all registries
	for target, registry in next, hookRegistry do
		if not registry.active then
			registry.active = true
			reactivatedCount = reactivatedCount + 1
		end
	end

	-- Reactivate all individual hooks
	for hookId, hookInfo in next, globalHookList do
		if not hookInfo.active then
			hookInfo.active = true
			reactivatedCount = reactivatedCount + 1
		end
	end

	return reactivatedCount
end

-- Clear all hooks for a specific target
function oop.clearHooks(target)
	return oop.restore(target)
end

-- Deactivate all hooks for a specific target
function oop.deactivateHooks(target)
	if not hookRegistry[target] then
		return false
	end

	local registry = hookRegistry[target]
	local deactivatedCount = 0

	if registry.active then
		registry.active = false
		deactivatedCount = deactivatedCount + 1
	end

	-- Deactivate all individual hooks for this target
	for hookId, hookInfo in next, globalHookList do
		if hookInfo.target == target and hookInfo.active then
			hookInfo.active = false
			deactivatedCount = deactivatedCount + 1
		end
	end

	return deactivatedCount
end

-- Reactivate all hooks for a specific target
function oop.reactivateHooks(target)
	if not hookRegistry[target] then
		return false
	end

	local registry = hookRegistry[target]
	local reactivatedCount = 0

	if not registry.active then
		registry.active = true
		reactivatedCount = reactivatedCount + 1
	end

	-- Reactivate all individual hooks for this target
	for hookId, hookInfo in next, globalHookList do
		if hookInfo.target == target and not hookInfo.active then
			hookInfo.active = true
			reactivatedCount = reactivatedCount + 1
		end
	end

	return reactivatedCount
end

-- Get global hook statistics
function oop.getGlobalHookStats()
	local stats = {
		totalTargets = 0,
		totalHooks = 0,
		activeTargets = 0,
		activeHooks = 0,
		inactiveTargets = 0,
		inactiveHooks = 0,
		hooksByType = {
			BEFORE = 0,
			AFTER = 0,
			REPLACE = 0,
			AROUND = 0
		}
	}

	-- Count targets and their hooks
	for target, registry in next, hookRegistry do
		stats.totalTargets = stats.totalTargets + 1

		if registry.active then
			stats.activeTargets = stats.activeTargets + 1
		else
			stats.inactiveTargets = stats.inactiveTargets + 1
		end

		-- Count hooks by type
		for hookType, hooks in next, registry.hooks do
			local hookCount = #hooks
			stats.totalHooks = stats.totalHooks + hookCount
			stats.hooksByType[hookType] = stats.hooksByType[hookType] + hookCount

			-- Count active/inactive hooks
			for i = 1, hookCount do
				local hookInfo = hooks[i]
				if hookInfo.active then
					stats.activeHooks = stats.activeHooks + 1
				else
					stats.inactiveHooks = stats.inactiveHooks + 1
				end
			end
		end
	end

	return stats
end

-- Get all active hook IDs
function oop.getAllHookIds()
	local hookIds = {}

	for hookId, hookInfo in next, globalHookList do
		table_insert(hookIds, hookId)
	end

	return hookIds
end

-- Get hooks by name
function oop.getHooksByName(name)
	local matchingHooks = {}

	for hookId, hookInfo in next, globalHookList do
		if hookInfo.name == name then
			matchingHooks[#matchingHooks + 1] = {
				id = hookId,
				target = hookInfo.target,
				hookType = hookInfo.hookType,
				priority = hookInfo.priority,
				active = hookInfo.active
			}
		end
	end

	return matchingHooks
end

-- Force garbage collection to clean up weak references
function oop.cleanupHookRegistry()
	-- Force garbage collection to clean up weak references
	collectgarbage("collect")

	-- Clean up any orphaned hooks in global list
	local orphanedHooks = {}
	for hookId, hookInfo in next, globalHookList do
		if not hookRegistry[hookInfo.target] then
			orphanedHooks[#orphanedHooks + 1] = hookId
		end
	end

	-- Remove orphaned hooks
	for _, hookId in next, orphanedHooks do
		globalHookList[hookId] = nil
	end

	return #orphanedHooks
end

-- Export hooking constants and utilities
oop.HOOK_TYPES = HOOK_TYPES
oop.hookRegistry = hookRegistry     -- For debugging/inspection
oop.globalHookList = globalHookList -- For debugging/inspection

-- Export the library
return oop
