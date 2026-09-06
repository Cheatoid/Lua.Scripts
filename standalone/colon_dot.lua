-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

local M = {}

--- Takes a table of *plain functions* (no self) and returns a proxy that can be used with ':'
function M.to_colon(t)
	if type(t) ~= "table" then
		return error("to_colon expects a table", 2)
	end

	return setmetatable({}, {
		__index = function(_, key)
			local value = t[key]

			if type(value) == "function" then
				-- Discard the automatic 'self' so plain functions work with :
				return function(self, ...)
					return value(...)
				end
			end

			return value
		end,

		__newindex = function(_, key, value)
			t[key] = value
		end,

		__pairs = function()
			return pairs(t)
		end,
	})
end

--- Takes a table of *methods* (expect self) and returns a proxy usable with '.' syntax
--- (caller must still pass self manually)
function M.to_dot(t)
	if type(t) ~= "table" then
		return error("to_dot expects a table", 2)
	end

	return setmetatable({}, {
		__index = function(_, key)
			local value = t[key]

			if type(value) == "function" then
				return value -- raw method, caller passes self
			end

			return value
		end,

		__newindex = function(_, key, value)
			t[key] = value
		end,

		__pairs = function()
			return pairs(t)
		end,
	})
end

--- Takes an *instance* and returns a proxy where every method is already bound to that instance.<br>
--- You can call methods with plain '.' and without passing self.
function M.bind_dot(obj)
	if type(obj) ~= "table" then
		return error("bind_dot expects a table (object)", 2)
	end

	return setmetatable({}, {
		__index = function(_, key)
			local value = obj[key]

			if type(value) == "function" then
				-- Automatically bind self
				return function(...)
					return value(obj, ...)
				end
			end

			-- Non-function fields are returned as-is
			return value
		end,

		__newindex = function(_, key, value)
			obj[key] = value
		end,

		__pairs = function()
			return pairs(obj)
		end,
	})
end

--- Bind a single method to an instance.
function M.bind(obj, method_name)
	local method = obj[method_name]
	if type(method) ~= "function" then
		return error("bind: '" .. tostring(method_name) .. "' is not a function", 2)
	end
	return function(...)
		return method(obj, ...)
	end
end

-- Export
return M
