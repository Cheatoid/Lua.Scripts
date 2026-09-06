-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Wraps a table in a proxy whose field accesses forward directly to the target:
-- Every write becomes rawset(target, ...)
-- Every read becomes rawget(target, ...)
-- Metamethods on the target itself are bypassed.
--
-- Usage example:
-- ```
-- local proxy = require "proxy"
--
-- local original = { x = 10 }
-- local p = proxy.create(original)
--
-- print(p.x) -- 10
-- p.y = 20
-- print(original.y) -- 20
-- ```

-- Localized global functions for better performance
local assert = assert
local getmetatable = getmetatable
local next = next
local rawget = rawget
local rawset = rawset
local setmetatable = setmetatable
local type = type

--- Create a proxy over `target`.<br>
--- Every write becomes `rawset(target, ...)` and every read becomes `rawget(target, ...)`.<br>
--- Metamethods on the target itself are bypassed. The proxy also forwards `__pairs` and `__len`.
---@param target table The table to wrap. Must be a table.
---@return table proxy Empty proxy that forwards directly to `target`.
---@usage <br>
--- ```
--- local proxy = require "proxy"
--- local original = { x = 10 }
--- local p = proxy.create(original)
--- print(p.x) -- 10
--- p.y = 20
--- print(original.y) -- 20
--- ```
local create = function(target)
	assert(type(target) == "table", "expected table, got " .. type(target))
	return setmetatable({}, {
		__index = function(_, k) -- `_` = the proxy itself (unused)
			return rawget(target, k) -- no fallback to target's __index
		end,

		__newindex = function(_, k, v)
			rawset(target, k, v) -- no hooks/validation on the target
		end,

		__pairs = function(_) -- Lua >= 5.2; ignored on 5.1/LuaJIT
			return next, target, nil
		end,

		__len = function(_) -- Lua >= 5.2; 5.1 ignores __len
			return #target
		end,

		__target = target, -- lets `backing` recover it
	})
end

--- Return the table a proxy forwards to (nil if `p` is not a proxy).<br>
--- Inspects the proxy metatable for the hidden `__target` field.
---@param p any Value to test.
---@return table? target The backing table, or nil if `p` is not a proxy.
---@usage <br>
--- ```
--- local proxy = require "proxy"
--- local t = {}
--- local p = proxy.create(t)
--- assert(proxy.backing(p) == t)
--- assert(proxy.backing({}) == nil)
--- ```
local backing = function(p)
	if type(p) == "table" then
		local mt = getmetatable(p)
		if mt and mt.__target then
			return mt.__target
		end
	end
end

-- Export
return {
	create = create,
	backing = backing,
}
