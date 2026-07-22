-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

local luameta = assert(luameta, "require the init file instead")
local trait = require "trait"
local isTrait = trait.is

local mt = {}

local function include(self, t)
	assert(type(t) == "table", "include: expected a table.")
	for k, v in next, t do
		if type(k) == "number" and type(v) == "table" and v.name then
			if v.class or v.origin then -- Class descriptor or class table
				local desc = v.origin or v
				if desc.namespace and desc.namespace ~= self then
					error(string.format("include: '%s' is already assigned to namespace '%s'", v.name,
						desc.namespace.name))
				end
				self[v.name] = desc.class or v
				if luameta.config.registerGlobally then _G[v.name] = nil end
				desc.namespace = self
			elseif isTrait(v) then -- Trait
				if v.namespace and v.namespace ~= self then
					error(string.format("include: trait '%s' is already assigned to namespace '%s'", v.name,
						v.namespace.name))
				end
				self[v.name] = v
				if luameta.config.registerGlobally then _G[v.name] = nil end
				v.namespace = self
			elseif getmetatable(v) == mt then -- Nested namespace
				if v.namespace and v.namespace ~= self then
					error(string.format("include: namespace '%s' is already assigned to namespace '%s'", v.name,
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

local function isNamespace(t)
	return type(t) == "table" and getmetatable(t) == mt
end

local namespace = setmetatable({}, mt)

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

namespace.get = function(name) return luameta.registry.namespaces[name] end
namespace.isNamespace = isNamespace

-- Export
return namespace
