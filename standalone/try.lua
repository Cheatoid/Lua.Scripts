-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Try-Catch-Finally implementation (supports chaining and proper error propagation)

-- Import required dependencies
local istype = require "../standalone/istype"
local table = require "../standard/table"

-- Localized global functions for better performance
local iscallable = istype.callable
local istable = istype.table
local table_pack = table.pack
local table_unpack = table.unpack
local type = type
local error = error
--local pcall = pcall
local setmetatable = setmetatable
local string = string
local string_format = string.format
local os_time = os.time
local tostring = tostring

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

-- Create standardized error objects
local function createError(code, message, context)
	local err = {
		code = code,
		message = message,
		context = context or {},
		timestamp = os_time(),
	}
	setmetatable(err, {
		__tostring = function(self)
			return string_format("[Error %d] %s", self.code, self.message)
		end,
	})
	return err
end

-- Enhanced assertParameter with standardized errors
local function assertParameter(condition, functionName, paramName, expectedType, actualValue, level)
	if not condition then
		local actualType = type(actualValue)
		local message
		if actualValue == nil then
			message = string_format("%s: %s parameter cannot be nil", functionName, paramName)
		else
			message = string_format("%s: %s parameter must be %s, got %s", functionName, paramName, expectedType, actualType)
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

-- Error handler for xpcall - enhances error information
local function error_handler(err)
	-- Preserve the original error but add context
	return {
		original_error = err,
		message = tostring(err),
		traceback = debug and debug.traceback(err, 2) or "no traceback available"
	}
end

-- Production-ready implementation using xpcall for enhanced error handling
local function try(tryFunc)
	assertParameter(iscallable(tryFunc), "try", "tryFunc", "function", tryFunc, 2)

	local handler = {
		_tryFunc = tryFunc,
		_catchFunc = nil,
		_finallyFunc = nil,
		_caught = false,
		_result = nil,
		_error = nil
	}

	-- Catch method for error handling
	function handler:catch(catchFunc)
		assertParameter(iscallable(catchFunc), "catch", "catchFunc", "function", catchFunc, 2)
		self._catchFunc = catchFunc
		return self
	end

	-- Finally method for cleanup (always executed)
	function handler:finally(finallyFunc)
		assertParameter(iscallable(finallyFunc), "finally", "finallyFunc", "function", finallyFunc, 2)
		self._finallyFunc = finallyFunc
		return self
	end

	-- Execute the try-catch-finally chain
	function handler:execute(...)
		local args = table_pack(...)

		-- Execute try block with xpcall for better error handling
		local success, result = xpcall(function()
			return self._tryFunc(table_unpack(args, 1, args.n))
		end, error_handler)

		if success then
			self._result = result
		else
			-- result is now an enhanced error object from error_handler
			self._error = result
			self._caught = true

			-- Execute catch block if available
			if self._catchFunc then
				local catchSuccess, catchResult = xpcall(function()
					return self._catchFunc(result)
				end, error_handler)

				if not catchSuccess then
					-- If catch block throws, combine the errors
					self._error = createError(ERROR_CODES.EVENT_ERROR,
						"Error in catch block: " .. tostring(catchResult.message or catchResult),
						{
							originalError = result,
							catchError = catchResult
						})
				else
					self._result = catchResult
				end
			end
		end

		-- Always execute finally block if available
		if self._finallyFunc then
			local finallySuccess, finallyResult = xpcall(function()
				return self._finallyFunc()
			end, error_handler)

			if not finallySuccess then
				-- Finally block errors should not mask original errors
				local errorMsg = "Error in finally block: " .. tostring(finallyResult.message or finallyResult)
				if self._caught then
					errorMsg = errorMsg .. " (original error: " .. tostring(self._error.message or self._error) .. ")"
				end
				self._error = createError(ERROR_CODES.EVENT_ERROR, errorMsg, {
					originalError = self._caught and self._error or nil,
					finallyError = finallyResult
				})
				self._caught = true
			end
		end

		-- Re-throw error if caught and not handled
		if self._caught and not self._catchFunc then
			return error(self._error)
		end

		-- Return result and error information
		return self._result, self._error, self._caught
	end

	-- Allow direct execution without calling execute explicitly
	return setmetatable(handler, {
		__call = function(self, ...)
			return self:execute(...)
		end
	})
end

-- Convenience function for async-style error handling
local function safe_call(func, errorHandler)
	assertParameter(iscallable(func), "safe_call", "func", "function", func, 2)
	if errorHandler then
		assertParameter(iscallable(errorHandler), "safe_call", "errorHandler", "function", errorHandler, 2)
	end

	return function(...)
		local args = table_pack(...)
		local success, result = xpcall(function()
			return func(table_unpack(args, 1, args.n))
		end, error_handler)

		if success then
			return result, nil
		end
		if errorHandler then
			return errorHandler(result), result
		end
		return nil, result
	end
end

-- Utility for executing multiple functions with error aggregation
local function try_all(funcs, stopOnError)
	assertParameter(istable(funcs), "try_all", "funcs", "table", funcs, 2)
	stopOnError = stopOnError ~= false -- default to true

	local results = {}
	local errors = {}
	local hasErrors = false

	for i, func in next, funcs do
		assertParameter(iscallable(func), "try_all", "func", "function", func, 2)

		local success, result = xpcall(func, error_handler)
		if success then
			results[i] = result
		else
			hasErrors = true
			errors[i] = result
			if stopOnError then
				break
			end
		end
	end

	return results, errors, hasErrors
end

-- Export
return {
	try = try,
	safe_call = safe_call,
	try_all = try_all,
}
