-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Read-only table utilities

-- Localized global functions for better performance
--local getmetatable = getmetatable --debug.getmetatable
local setmetatable = setmetatable

local readonly_newindex
do
	local error = error
	readonly_newindex = function()
		return error("attempt to modify a read-only table", 2)
	end
end

-- readonly* { ... }
-- NOTE: This version ignores metatable
_G.readonly = setmetatable({}, {
	__mul = function(_, t)
		--local real_mt = getmetatable(t)
		return setmetatable({}, {
			__index = setmetatable(t),
			--__metatable = real_mt,
			__newindex = readonly_newindex,
		})
	end
})

-- NOTE: This version respects metatable
return function(t)
	--local real_mt = getmetatable(t)
	return setmetatable({}, {
		__index = t,
		--__metatable = real_mt,
		__newindex = readonly_newindex,
	})
end
