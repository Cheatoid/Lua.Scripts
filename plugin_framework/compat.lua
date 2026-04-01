-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Plugin compatibility layer and polyfills for Lua runtime (LuaJIT/5.1+).

local _ENV = _ENV or _G

local compat = {}

-- load/loadstring: prefer built-in load; fallback to loadstring for 5.1
local _load = _G.load or _G.loadstring
compat.load = function(chunk, name, mode, env)
	-- Lua 5.2+ load accepts env; 5.1 loadstring doesn't, so wrap
	if env and (load and debug and debug.getupvalue) then
		local f, err = _load(chunk, name)
		if not f then return nil, err end
		-- Try setfenv if available
		if setfenv then
			setfenv(f, env)
		else
			-- Lua 5.2+: create wrapper that sets local _ENV
			local wrapper = load("return function(plugin, ...) local _ENV = ... return (" .. chunk .. ") end", name, mode)
			return wrapper(env)
		end
		return f
	end
	return _load(chunk, name)
end

-- setfenv shim for 5.2+: uses debug.setupvalue when available
compat.setfenv = setfenv or function(f, env)
	local debug = debug
	if not debug then return error("no debug available for setfenv", 2) end
	local i = 1
	while true do
		local n = debug.getupvalue(f, i)
		if not n then break end
		if n == "_ENV" then
			debug.setupvalue(f, i, env)
			return f
		end
		i = i + 1
	end
	return f
end

-- Export
return compat
