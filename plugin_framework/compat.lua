-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Plugin compatibility layer and polyfills for Lua runtime (LuaJIT/5.1+)

local _ENV = _ENV or _G

local compat = {}

---@diagnostic disable-next-line: deprecated
local load, loadstring, setfenv = load, loadstring, setfenv
local _load = load or loadstring

-- Import debug_helper for upvalue manipulation
local debug_helper = require "../standalone/debug_helper"

compat.setfenv = setfenv or debug_helper.setfenv

--- Load a Lua chunk with environment support across Lua versions.<br>
--- Provides compatibility between Lua 5.1 (loadstring) and Lua 5.2+ (load).<br>
--- When env is provided, attempts to set the chunk's environment using setfenv (5.1) or debug.setupvalue (5.2+).
---@param chunk string|function Lua chunk string or function to load.
---@param chunkname? string Name for the chunk (for error messages, default: "=(load)").
---@param mode? string Mode string ("t" for text, "b" for binary, "bt" for both, default: "bt").
---@param env? table Environment table to set for the loaded chunk.
---@return function? function Loaded function, or nil on failure.
---@return string? error Error message if loading failed.
---@usage <br>
--- ```
--- local f, err = compat.load("print('hello')", "mychunk", "t", _ENV)
--- if f then f() end
--- ```
compat.load = function(chunk, chunkname, mode, env)
	-- Lua 5.2+ load accepts env as 4th argument
	if env and load and not loadstring then
		return load(chunk, chunkname, mode, env)
	end
	-- Lua 5.1/LuaJIT: load chunk first, then set environment
	if env then
		local f, err = _load(chunk, chunkname, mode)
		if not f then return nil, err end
		-- Try setfenv if available (Lua 5.1/LuaJIT)
		if setfenv then
			setfenv(f, env)
		elseif compat.setfenv then
			-- Fallback: use debug.setupvalue via compat.setfenv
			compat.setfenv(f, env)
		end
		return f
	end
	-- No env requested: use the appropriate load function
	return _load(chunk, chunkname, mode)
end

-- Export
return compat
