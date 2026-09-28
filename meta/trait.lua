-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

local luameta = assert(luameta, "require the init file instead")
local traitUtils = require "trait_utils"

local mt = {}

--- Declare a new trait and register it under `name`.<br>
--- Also stored as a global when `registerGlobally` is enabled.
---@param name string Trait name; must be unique.
---@return table trait The new trait table.
local function newTrait(_, name)
	assert(type(name) == "string", "trait name must be a string.")
	assert(not _G[name] or not luameta.config.registerGlobally, "global \"" .. name .. "\" is already declared.")
	assert(not luameta.registry.traits[name], "trait \"" .. name .. "\" is already registered.")

	local new = setmetatable({
		statics = {},
		methods = {},
		metas = {},
		traits = {},
		name = name,
	}, mt)

	if luameta.config.registerGlobally then _G[name] = new end
	luameta.registry.traits[name] = new

	return new
end

--- Check whether a value is a trait declared by this module.
---@param t any Value to test.
---@return boolean is_trait True when `t` is a trait table.
local function isTrait(t)
	return type(t) == "table" and getmetatable(t) == mt
end

--- Compose another trait into this one, copying its statics, methods and metamethods.<br>
--- The trait may be a trait table, a wrapper table with `trait`, `only`, `except` and `alias`
--- fields, or a name resolved through enclosing namespaces, globals, the namespaces registry
--- and the trait registry.<br>
--- Errors on circular trait dependencies and on member conflicts.
---@param spec? table|string Trait table, wrapper table, or trait name; nil is a no-op.
---@return table trait The trait table, for chaining.
local function implements(self, spec)
	local t
	if type(spec) == "table" and isTrait(spec) then
		t = spec
	elseif type(spec) == "table" and spec.trait then
		t = spec.trait
	elseif type(spec) == "string" and spec ~= self.name then
		local current = self.namespace
		while current do
			if current[spec] and isTrait(current[spec]) then
				t = current[spec]
				break
			end
			current = current.namespace
		end
		if not t then t = _G[spec] end
		if not t then
			t = traitUtils.resolveFromNamespaces(spec, isTrait, luameta.registry.namespaces)
		end
		if not t then t = luameta.registry.traits[spec] end
	end

	if isTrait(t) then
		if traitUtils.traitMatches(t, self) then
			return error("implements: circular trait dependency detected for \"" .. t.name .. "\".")
		end
		local except = (type(spec) == "table" and spec.except) or {}
		local only = (type(spec) == "table" and spec.only)
		local alias = (type(spec) == "table" and spec.alias) or {}

		local function methodExists(trait, methodName, seen)
			seen = seen or {}
			if seen[trait] then return false end
			seen[trait] = true
			if rawget(trait.methods, methodName) ~= nil then return true end
			local mx = trait.traits or {}
			for i = 1, #mx do
				local composed = mx[i]
				if methodExists(composed, methodName, seen) then return true end
			end
			return false
		end

		local function allowed(k)
			if only then
				for i = 1, #only do if only[i] == k then return true end end
				return false
			end
			for i = 1, #except do if except[i] == k then return false end end
			return true
		end

		local allStatics = traitUtils.collectTraitStatics(t)
		local statics = self.statics
		for k, v in next, allStatics do
			if allowed(k) then
				if statics[k] ~= nil then
					return error(string.format("implements: static conflict '%s' from trait '%s'", k, t.name))
				end
				statics[k] = v
			end
		end

		local allMethods = traitUtils.collectTraitMethods(t)
		local methods = self.methods
		for k, v in next, allMethods do
			if allowed(k) then
				local dest = alias[k] or k
				if methodExists(self, dest) then
					return error(string.format("implements: method conflict '%s' from trait '%s'", dest, t.name))
				end
				methods[dest] = v
			end
		end

		local allMetas = traitUtils.collectTraitMetas(t)
		local metas = self.metas
		for k, v in next, allMetas do
			if allowed(k) then
				if metas[k] ~= nil then
					return error(string.format("implements: meta conflict '%s' from trait '%s'", k, t.name))
				end
				metas[k] = v
			end
		end

		table.insert(self.traits, t)
	elseif spec ~= nil then
		return error("implements: \"" .. tostring(spec) .. "\" is not a trait.")
	end
	return self
end

--- Copy static fields from `t` into this trait's statics map.<br>
--- They are copied onto the class table of every class that implements this trait.
---@param t table Static fields to add, keyed by name.
---@return table trait The trait table, for chaining.
local function static(self, t)
	assert(type(t) == "table", "\"t\" is not a table.")
	local statics = self.statics
	for k, v in next, t do
		statics[k] = v
	end
	return self
end

--- Copy methods from `t` into this trait's method map.<br>
--- They are merged into the method map of every class that implements this trait.
---@param t table Methods to add, keyed by name.
---@return table trait The trait table, for chaining.
local function method(self, t)
	assert(type(t) == "table", "\"t\" is not a table.")
	local methods = self.methods
	for k, v in next, t do
		methods[k] = v
	end
	return self
end

--- Copy metamethods from `t` into this trait's metas map.<br>
--- They are merged into the metatable of every class that implements this trait.
---@param t table Metamethods to add, keyed by name.
---@return table trait The trait table, for chaining.
local function meta(self, t)
	assert(type(t) == "table", "meta: \"t\" is not a table.")
	local metas = self.metas
	for k, v in next, t do
		metas[k] = v
	end
	return self
end

local trait = setmetatable({}, mt)

mt.__call = newTrait
--- Serve the chainable builders first, then fall back to the trait's statics.
mt.__index = function(self, key)
	if key == "implements" then return implements end
	if key == "static" then return static end
	if key == "method" then return method end
	if key == "meta" then return meta end
	return rawget(self, "statics") and rawget(self, "statics")[key]
end

trait.is = isTrait
--- Look up a registered trait by name.
---@param name string The registered trait name.
---@return table? trait The trait table, or nil when the name is unknown.
trait.get = function(name) return luameta.registry.traits[name] end

-- Export
return trait
