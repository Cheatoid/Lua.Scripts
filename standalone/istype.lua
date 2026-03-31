-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Simple type-checking functions.

local type = type
local isnone
do
	local select, HASH = select, "#"
	isnone = function(...) return 0 == select(HASH, ...) end
end

return {
	isnone = isnone,
	isnil = function(v) return type(v) == "nil" end,
	isboolean = function(v) return type(v) == "boolean" end,
	isnumber = function(v) return type(v) == "number" end,
	isstring = function(v) return type(v) == "string" end,
	istable = function(v) return type(v) == "table" end,
	isfunction = function(v) return type(v) == "function" end,
	isthread = function(v) return type(v) == "thread" end,
	isuserdata = function(v) return type(v) == "userdata" end,
}
