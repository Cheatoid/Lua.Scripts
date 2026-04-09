-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Simple type-checking functions for convenience

-- Localized type function for better performance
local type = type

-- Export
return {
	["none"] = (function()
		local select, HASH = select, "#"
		return function(...) return 0 == select(HASH, ...) end
	end)(),
	["callable"] = (function()
		local getmetatable, func = getmetatable, "function"
		return function(v)
			if type(v) ~= func then
				local mt = getmetatable(v)
				return mt and type(mt.__call) == func
			end
			return true
		end
	end)(),
	["integer"] = (function()
		local math_modf, num = math.modf, "number"
		return function(v)
			return type(v) == num and v == (math_modf(v))
		end
	end)(),
	["nil"] = function(v) return type(v) == "nil" end,
	["boolean"] = function(v) return type(v) == "boolean" end,
	["number"] = function(v) return type(v) == "number" end,
	["string"] = function(v) return type(v) == "string" end,
	["table"] = function(v) return type(v) == "table" end,
	["function"] = function(v) return type(v) == "function" end,
	["thread"] = function(v) return type(v) == "thread" end,
	["userdata"] = function(v) return type(v) == "userdata" end,
}
