-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

local luameta = assert(luameta, "require the init file instead")
local trait = require "trait"
local isTrait = trait.is

local mt = {}

--- Include the members of `t` into this namespace.<br>
--- Classes, traits and nested namespaces are stored under their own name and repointed
--- to this namespace; every other key is copied over unchanged.<br>
--- Errors when a member already belongs to another namespace.
---@param t table Table of members to include.
---@return table namespace The namespace, for chaining.
local function include(self, t)
	assert(type(t) == "table", "include: expected a table.")
	for k, v in next, t do
		if type(k) == "number" and type(v) == "table" and v.name then
			if v.class or v.origin then -- Class descriptor or class table
				local desc = v.origin or v
				if desc.namespace and desc.namespace ~= self then
					return error(string.format("include: '%s' is already assigned to namespace '%s'", v.name,
						desc.namespace.name))
				end
				self[v.name] = desc.class or v
				if luameta.config.registerGlobally then _G[v.name] = nil end
				desc.namespace = self
			elseif isTrait(v) then -- Trait
				if v.namespace and v.namespace ~= self then
					return error(string.format("include: trait '%s' is already assigned to namespace '%s'", v.name,
						v.namespace.name))
				end
				self[v.name] = v
				if luameta.config.registerGlobally then _G[v.name] = nil end
				v.namespace = self
			elseif getmetatable(v) == mt then -- Nested namespace
				if v.namespace and v.namespace ~= self then
					return error(string.format("include: namespace '%s' is already assigned to namespace '%s'", v.name,
						v.namespace.name))
				end
				self[v.name] = v
				if luameta.config.registerGlobally then _G[v.name] = nil end
				v.namespace = self
			else
				self[v.name] = v
			end
		elseif k ~= "name" then
			self[k] = v
		end
	end
	return self
end

--- Declare a new namespace and register it under `name`.<br>
--- Also stored as a global when `registerGlobally` is enabled.
---@param name string Namespace name; must be unique.
---@return table namespace The new namespace table.
local function newNamespace(_, name)
	assert(type(name) == "string", "namespace name must be a string.")
	assert(not _G[name] or not luameta.config.registerGlobally, "global \"" .. name .. "\" is already declared.")
	assert(not luameta.registry.namespaces[name], "namespace \"" .. name .. "\" is already registered.")

	local new = setmetatable({
		name = name,
	}, mt)

	if luameta.config.registerGlobally then _G[name] = new end
	luameta.registry.namespaces[name] = new

	return new
end

local function namespaceFullPath(ns)
	local parts = {}
	local current = ns
	while current do
		parts[#parts + 1] = current.name
		current = current.namespace
	end
	local reversed = {}
	for i = #parts, 1, -1 do
		reversed[#reversed + 1] = parts[i]
	end
	return table.concat(reversed, ".")
end

--- Create (or walk into) a nested namespace addressed by a dotted `path`.<br>
--- Missing segments are created on demand and registered under their full dotted path.
---@param path string Dotted path such as `"Config.Database"`.
---@return table namespace The innermost namespace in the path.
local function nested(self, path)
	assert(type(path) == "string", "nested: path must be a string.")
	local current = self
	for part in path:gmatch("[^.]+") do
		if not current[part] then
			local child = setmetatable({}, mt)
			child.name = part
			child.namespace = current
			current[part] = child
			luameta.registry.namespaces[namespaceFullPath(child)] = child
		end
		current = current[part]
	end
	return current
end

--- Check whether a value is a namespace declared by this module.
---@param t any Value to test.
---@return boolean is_namespace True when `t` is a namespace table.
local function isNamespace(t)
	return type(t) == "table" and getmetatable(t) == mt
end

--- Namespace module: call it as `namespace("Name")` to declare a namespace.<br>
--- Call it with a table to include that table's members instead.
local namespace = setmetatable({}, mt)

--- Declare a new namespace when called with a name, or include a members table when called with a table.
mt.__call = function(self, arg1, ...)
	if type(arg1) == "string" then
		return newNamespace(self, arg1)
	elseif type(arg1) == "table" then
		return include(self, arg1)
	end
end
mt.__index = {
	include = include,
	nested = nested,
}

--- Look up a registered namespace by name (nested namespaces use their full dotted path).
---@param name string The registered namespace name.
---@return table? namespace The namespace table, or nil when the name is unknown.
namespace.get = function(name) return luameta.registry.namespaces[name] end
namespace.isNamespace = isNamespace

-- Export
return namespace
