-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Function extensions.

local error = error

-- Hijack function metatable 😎
local FUNCTION
if debug and debug.getmetatable then
	local func = function() end
	FUNCTION = debug.getmetatable(func) or {}
	FUNCTION.__index = FUNCTION.__index or FUNCTION
	if debug.setmetatable then
		debug.setmetatable(func, FUNCTION)
	end
else
	FUNCTION = {}
end

local function decompile(self, options)
	-- TODO
	return error("decompile: not implemented", 2)
end

FUNCTION.decompile = decompile

local function pretty_print(self, options)
	-- TODO
	return error("pretty_print: not implemented", 2)
end

FUNCTION.pretty_print = pretty_print

--FUNCTION.__tostring = function(self)
--	-- TODO
--	return error("__tostring: not implemented", 2)
--end

return FUNCTION
