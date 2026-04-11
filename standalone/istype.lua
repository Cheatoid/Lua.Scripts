-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Simple type-checking functions for convenience

-- Localized type function for better performance
local type = type

-- Export
---@class istype
return {
	--- Checks if no arguments were passed
	---@field none fun(...:any):boolean # True if no arguments were passed
	["none"] = (function()
		local select, HASH = select, "#"
		return function(...) return 0 == select(HASH, ...) end
	end)(),
	--- Checks if a value is callable (function or has __call metamethod)
	---@field callable fun(v:any):boolean # True if the value is callable
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
	--- Checks if a value is an integer (whole number)
	---@field integer fun(v:any):boolean # True if the value is an integer
	["integer"] = (function()
		local math_modf, num = math.modf, "number"
		return function(v)
			return type(v) == num and v == (math_modf(v))
		end
	end)(),
	--- Checks if a value is nil
	---@field nil fun(v:any):boolean # True if the value is nil
	["nil"] = function(v) return type(v) == "nil" end,
	--- Checks if a value is a boolean
	---@field boolean fun(v:any):boolean # True if the value is a boolean
	["boolean"] = function(v) return type(v) == "boolean" end,
	--- Checks if a value is a number
	---@field number fun(v:any):boolean # True if the value is a number
	["number"] = function(v) return type(v) == "number" end,
	--- Checks if a value is a string
	---@field string fun(v:any):boolean # True if the value is a string
	["string"] = function(v) return type(v) == "string" end,
	--- Checks if a value is a table
	---@field table fun(v:any):boolean # True if the value is a table
	["table"] = function(v) return type(v) == "table" end,
	--- Checks if a value is a function
	---@field function fun(v:any):boolean # True if the value is a function
	["function"] = function(v) return type(v) == "function" end,
	--- Checks if a value is a thread
	---@field thread fun(v:any):boolean # True if the value is a thread
	["thread"] = function(v) return type(v) == "thread" end,
	--- Checks if a value is userdata
	---@field userdata fun(v:any):boolean # True if the value is userdata
	["userdata"] = function(v) return type(v) == "userdata" end,
}
