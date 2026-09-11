-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

local luameta = _G.luameta or {
	config = { registerGlobally = true },
	registry = { classes = {}, traits = {}, namespaces = {} },
}

_G.luameta = luameta

luameta.trait = require "trait"
luameta.namespace = require "namespace"
luameta.class = require "class"

-- Stack for pushGlobal/popGlobal
luameta._globalStack = {}

--- Save the current registerGlobally value onto a stack, then set it to a new value.
--- Call popGlobal() to restore the previous value. Supports nesting.
---@param newValue boolean The value to set registerGlobally to.
function luameta.pushGlobal(newValue)
	luameta._globalStack[#luameta._globalStack + 1] = luameta.config.registerGlobally
	luameta.config.registerGlobally = newValue
end

--- Restore registerGlobally to the value saved by the most recent pushGlobal call.
function luameta.popGlobal()
	if #luameta._globalStack > 0 then
		luameta.config.registerGlobally = luameta._globalStack[#luameta._globalStack]
		luameta._globalStack[#luameta._globalStack] = nil
	end
end

-- Deprecated aliases (naming standard: snake_case). Kept for compatibility.
luameta.push_global = luameta.pushGlobal
luameta.pop_global = luameta.popGlobal

-- Export
return luameta
