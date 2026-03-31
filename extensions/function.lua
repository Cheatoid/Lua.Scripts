-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Function extensions.

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

FUNCTION.decompile = function(self, options)
	-- TODO
	return error("decompile: not implemented")
end

FUNCTION.pretty_print = function(self, options)
	-- TODO
	return error("pretty_print: not implemented")
end

--FUNCTION.__tostring = function(self)
--	-- TODO
--	return error("__tostring: not implemented")
--end

return FUNCTION
