-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Patch global require function to add .lua extension when missing

_G.require = _G.require or require

local string_match, string_sub = string.match, string.sub
local old_require = assert(require, "require function is missing")
function require(name, ...)
	if type(name) == "string" then
		-- If the name does not end with .lua, append it
		if not string_match(string_sub(name, -4), "^%.[Ll][Uu][Aa]$") then
			name = name .. ".lua"
		end
		-- If the name starts with ./, add package path
		--if package and package.path and string_sub(name, 1, 2) == "./" then
		--	package.path = "?.lua;" .. package.path -- Windows
		--	--package.path = "?.lua:" .. package.path -- Linux
		--end
	end
	return old_require(name, ...)
end

_G.require = require
if _ENV then
	_ENV.require = require
end

return require
