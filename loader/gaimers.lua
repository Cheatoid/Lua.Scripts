-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Custom module loader (codename: GAIMERS).
-- As much as I like my custom loader GAIMERS, it is not fully cooperative with LuaLS...
-- So I am rethinking my approach and will use the standard require function instead;
-- Most likely, I will end up making a custom script that will "compile" the dependency graph,
-- use the standard require function to load them, in order to have proper editor navigation...

-- Import dependencies
local tc = require("../standalone/type_check")
local curry = require("../standalone/curry")
local table = require("../standard/table")
local runlua = require("../standalone/runlua")

-- Localized global functions for better performance
local assert = assert
local setmetatable = setmetatable
local type = type
local check_string = tc.check_string
local runlua_isolated = runlua.run_isolated
--local table_pack = table.pack
--local table_unpack = table.unpack
local deep_copy = table.deep_copy
local shallow_copy = table.shallow_copy

----------------------------------------------------------------------
-- G.A.(I.)M.E.R.S.
----------------------------------------------------------------------

-- TODO: Build DSL for dependency graph & automatic loader for loading modules/packages/dependencies...
-- TODO: HTTP require; HTTP/GitHub package importing (for dynamic/zipped modules, etc.)

---@alias ModuleName string
---@alias AnyModule table<string, any>

---@class GAIMERS
---@field g fun(name: string): fun(target: string|table|nil): any
---@field a fun(name: string): fun(alias: string|nil): any
---@field i fun(name: string): AnyModule
---@field m fun(name: string): AnyModule|nil
---@field e fun(name: string, value: any): any
---@field r fun(name: string): AnyModule|any
---@field s fun(name: string, deep: boolean|nil): AnyModule|any
--- Call without args to get GAIMERS functions.
---@operator call: fun(): (fun(name: string): fun(target: string|table|nil): any,fun(name: string): fun(alias: string|nil): any,fun(name: string): AnyModule,fun(name: string): AnyModule|nil,fun(name: string, value: any): any,fun(name: string): AnyModule|any,fun(name: string, deep: boolean|nil): AnyModule|any)
--- Call with a name to globally export and return the module itself.
---@operator call: fun(name: string): GAIMERS
local M = {}

--- Global require: require [target] and export it as global [name].
---@type fun(name: string): fun(target: string|table|nil): any
local g

--- Get global [name] and alias it as [alias].
---@type fun(name: string): fun(alias: string|nil): any
local a

--- Import & export: require [name] and export it as global [name].<br>
--- Equivalent to: `_G[name] = require(name)`
---@type fun(name: string): any
local i

--- Get global [name] and treat it as module (table with functions) that should be exported as globals.<br>
--- Exports all functions from the module as global variables.
---@type fun(name: string): table
local m

--- Export: Export a [value] to global scope with the given [name].<br>
--- Equivalent to: `_G[name] = value`
---@type fun(name: string, value: any): any
local e

--- Require function.
---@type fun(name: string): any
local r

--- Sandboxed require: require a module in an isolated global environment.<br>
--- Creates a copy of _G for the module to run in, preventing it from modifying the real globals.
---@type fun(name: string, deep: boolean|nil): any
local s

r = _G.require -- Package and Package.Require or _G.require

---@generic T
---@param name string
---@param value T
---@return T
e = function(name, value)
	_G[name] = value
	return value
end

---@param name string
---@param target string|table|nil
---@return any
local function g_impl(name, target)
	if not target then
		target = name -- same as i
	elseif type(target) == "table" then
		-- TODO: Implement real module support.
		target = target[1]
	end
	assert(type(target) == "string", "target must be a string or table")
	return e(name, M.r(target))
end

g = curry(g_impl)

---@param name string
---@param alias string|nil
---@return any
local function a_impl(name, alias)
	local v = _G[name]
	if alias and v ~= nil then
		_G[alias] = v
	end
	return v
end

a = curry(a_impl)

--- Get global [name] and treat it as module (table with functions) that should be exported as globals.
---
--- For example: `m"type_check"` will require the `type_check` package and export all its functions as global variables.
function m(name)
	local mod = M.r(name)
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
---
--- For example: `i"type_check"` ==> `_G["type_check"] = <type_check package>`
function i(name)
	check_string(1)
	return e(name, M.r(name))
end

local function require_wrapper(...)
	--return _G.require(...)
	return M.r(...)
end

--- Sandboxed require: require a module in an isolated global environment.
function s(name, deep)
	-- Create isolated environment with safe globals
	local sandbox_env = (deep and deep_copy or shallow_copy)(_G)
	sandbox_env._G = sandbox_env
	return runlua_isolated(
		function() return require_wrapper(name) end,
		setmetatable({}, {
			__index = sandbox_env
		}),
		"sandboxed-require:" .. name
	)
end

---@type GAIMERS
M = setmetatable({ -- require("../standalone/util").callable(...)
	g = g,
	a = a,
	i = i,
	m = m,
	e = e,
	r = r,
	s = s,
}, {
	__call = function(self, name)
		if name then
			--return e(name, self) -- inlined
			_G[name] = self
			return self
		end
		return g, a, i, m, e, r, s
	end
})

-- Export the API to be accessed by other packages
return M
