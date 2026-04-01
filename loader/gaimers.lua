-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Custom module loader (codename: GAIMERS).

-- Import dependencies
local curry = require("../standard/curry")
local table = require("../standard/table")
--local table_pack = table.pack
--local table_unpack = table.unpack
local deep_copy = table.deep_copy
local shallow_copy = table.shallow_copy

----------------------------------------------------------------------
-- G.A.(I.)M.E.R.S.
----------------------------------------------------------------------
local g, a, i, m, e, r, s

r = _G.require -- Package and Package.Require or _G.require
e = function(name, value)
	_G[name] = value
	return value
end

--- Global require: require [target] and export it as global [name].
g = curry(
	function(name, target)
		if type(target) == "table" then
			-- TODO: Implement real module support.
			target = target[1]
		end
		assert(type(target) == "string", "target must be a string or table")
		return e(name, r(target))
	end)

--- Get global [name] and alias it as [alias].
a = curry(
	function(name, alias)
		local v = _G[name]
		if alias and v ~= nil then
			_G[alias] = v
		end
		return v
	end)

--- Get global [name] and treat it as module (table with functions) that should be exported as globals.
--- For example: m"TypeCheck" will require the TypeCheck package and export all its functions as global variables.
function m(name)
	local mod = r(name)
	if mod == nil then
		return
	end
	assert(type(mod) == "table", name .. " is not a module")
	for k, v in next, mod do
		if type(v) == "function" then
			_G[k] = v
		end
	end
	return mod
end

--- Import & export: require and export package using the same name.
--- For example: i"TypeCheck" ==> _G["TypeCheck"] = <TypeCheck package>
function i(name)
	return e(name, r(name))
end

-- Lua 5.1/5.2: use setfenv (prefer debug.setfenv, fallback to global setfenv)
local setenv = (debug and debug.setfenv) or _G.setfenv
local function require_wrapper(...)
	--return r(...)
	return _G.require(...)
end

--- Sandboxed require: require a module in an isolated global environment.
function s(name, deep)
	-- Create isolated environment with safe globals
	local sandbox_env = (deep and deep_copy or shallow_copy)(_G)
	sandbox_env._G = sandbox_env
	-- Load the module in isolated environment
	if setenv then
		setenv(require_wrapper, sandbox_env)
	end
	--local module_results = table_pack(require_wrapper(name))
	--local module = module_results[1]
	-- Return module/values as-is (handle multiple returns)
	--if module_results.n > 1 then
	--	return table_unpack(module_results, 1, module_results.n)
	--end
	--return module
	return require_wrapper(name)
end

return {
	g = g,
	a = a,
	i = i,
	m = m,
	e = e,
	r = r,
	s = s,
}
