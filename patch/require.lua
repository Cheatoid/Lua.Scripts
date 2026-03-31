-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Patch global require function to add .lua extension when missing

local string_match, string_sub = string.match, string.sub
local old_require = _G.require
function require(name, ...)
	if type(name) == "string" then
		-- If the name does not end with .lua, append it
		if not string_match(string_sub(name, -4), "^%.[Ll][Uu][Aa]$") then
			name = name .. ".lua"
		end
	end
	return old_require(name, ...)
end

-- Export
_G.require = require
return require
