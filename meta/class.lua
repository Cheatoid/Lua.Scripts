-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

local luameta = assert(luameta, "require the init file instead")
local trait = require "trait"
local traitUtils = require "trait_utils"
local isTrait = trait.is
local table_unpack = table.unpack or unpack

-- nil-safe pack: stores value count in .n so unpack with explicit bounds
-- preserves nil values across the Lua 5.1/LuaJIT table-length gap
local table_pack = table.pack or function(...) return { n = select("#", ...), ... } end

local privateStore = setmetatable({}, { __mode = "k" })
local function privateFn(self)
	local store = privateStore[self]
	if store then
		return store
	end
	store = {}
	privateStore[self] = store
	return store
end

local mt = {}
local isInstance
local __clone
local __isA

local function runConstructors(classDescriptor, instance, ...)
	local chain = {}
	local current = classDescriptor
	while current do
		chain[#chain + 1] = current
		current = rawget(current, "parent")
	end
	for i = #chain, 1, -1 do
		local constructors = rawget(chain[i], "constructors") or {}
		for j = 1, #constructors do
			constructors[j](instance, ...)
		end
	end
end

__clone = function(inst)
	local copy = setmetatable({}, getmetatable(inst))
	for k, v in next, inst do
		if k ~= "__super_host__" then copy[k] = v end
	end
	local origPrivate = privateStore[inst]
	if origPrivate then
		local newPrivate = {}
		for k, v in next, origPrivate do newPrivate[k] = v end
		privateStore[copy] = newPrivate
	end
	return copy
end

__isA = function(self, target)
	return isInstance(self, target)
end

local newIndexProtected = { __class__ = true, __super_host__ = true }
local classFieldProtected = { origin = true, name = true }

local function createNewIndexResolver(descriptor)
	return function(tbl, key, value)
		if newIndexProtected[key] then
			return error("cannot set protected field '" .. tostring(key) .. "'", 2)
		end
		if rawget(tbl, "origin") and classFieldProtected[key] then
			return error("cannot set protected class field '" .. tostring(key) .. "'", 2)
		end
		local current = descriptor
		while current do
			local prop = rawget(current, "properties")
			if prop and prop[key] and prop[key].set then
				return prop[key].set(tbl, value)
			end
			current = rawget(current, "parent")
		end
		rawset(tbl, key, value)
	end
end

local function createIndexResolver(descriptor)
	return function(tbl, key)
		local value = rawget(tbl, key)
		if value ~= nil then return value end
		local origin = rawget(tbl, "origin")
		if origin then
			local current = descriptor
			while current do
				value = rawget(current.class, key)
				if value ~= nil then return value end
				current = rawget(current, "parent")
			end
		else
			local current = descriptor
			while current do
				local v = rawget(current.methods, key)
				if v ~= nil then return v end
				current = rawget(current, "parent")
			end
			current = descriptor
			while current do
				local prop = rawget(current, "properties")
				if prop and prop[key] and prop[key].get then
					return prop[key].get(tbl)
				end
				current = rawget(current, "parent")
			end
			if key == "clone" then
				return __clone
			end
			if key == "class" then
				return rawget(descriptor, "class")
			end
			if key == "isA" then
				return __isA
			end
			if key == "super" then
				local function makeProxy(desc)
					local parent = rawget(desc, "parent")
					if not parent then return nil end
					return setmetatable({}, {
						__index = function(proxy, method_name)
							local cached = rawget(proxy, method_name)
							if cached ~= nil then return cached end
							if method_name == "super" then
								local sub = function()
									return makeProxy(parent)
								end
								rawset(proxy, "super", sub)
								return sub
							end
							local curr = parent
							while curr do
								local m = rawget(curr.methods, method_name)
								if m ~= nil then
									local wrapper = function(_, ...)
										local saved = rawget(tbl, "__super_host__")
										rawset(tbl, "__super_host__", curr)
										local results = table_pack(pcall(m, tbl, ...))
										rawset(tbl, "__super_host__", saved)
										if not results[1] then return error(results[2], 0) end
										return table_unpack(results, 2, results.n)
									end
									rawset(proxy, method_name, wrapper)
									return wrapper
								end
								local s = rawget(curr.class, method_name)
								if s ~= nil then
									local wrapper = function(_, ...)
										local saved = rawget(tbl, "__super_host__")
										rawset(tbl, "__super_host__", curr)
										local results = table_pack(pcall(s, tbl, ...))
										rawset(tbl, "__super_host__", saved)
										if not results[1] then return error(results[2], 0) end
										return table_unpack(results, 2, results.n)
									end
									rawset(proxy, method_name, wrapper)
									return wrapper
								end
								curr = rawget(curr, "parent")
							end
							return error("super: method '" .. tostring(method_name) .. "' not found in parent chain", 0)
						end,
					})
				end
				return function()
					local host = rawget(tbl, "__super_host__")
					local desc = host or descriptor
					local cached = rawget(tbl, "__super_proxy")
					if cached and rawget(cached, "__desc__") == desc then
						return cached
					end
					local proxy = makeProxy(desc)
					if proxy then
						rawset(proxy, "__desc__", desc)
						rawset(tbl, "__super_proxy", proxy)
					end
					return proxy
				end
			end
			if key == "private" then
				return privateFn
			end
		end
		return nil
	end
end

local function checkAbstracts(desc)
	if not desc.hasAbstracts then return end
	if desc.explicitAbstract then
		if not desc.abstractMethods or not next(desc.abstractMethods) then
			return
		end
	end
	local current = desc
	while current do
		if current.abstractMethods then
			for k in next, current.abstractMethods do
				local checker = desc
				local found = false
				while checker do
					if rawget(checker.methods, k) ~= nil then
						found = true
						break
					end
					checker = rawget(checker, "parent")
				end
				if not found then
					return
				end
			end
		end
		current = rawget(current, "parent")
	end
	desc.hasAbstracts = false
	desc.abstractMethods = nil
	desc.explicitAbstract = nil
end

local anonCounter = 0

local function newClass(_, name)
	local isAnonymous = false
	if not name or name == "" then
		isAnonymous = true
		repeat
			anonCounter = anonCounter + 1
			name = "__anon__" .. anonCounter
		until not luameta.registry.classes[name]
	else
		assert(type(name) == "string", "class name \"" .. name .. "\" is not valid.")
		assert(not _G[name] or not luameta.config.registerGlobally, "global \"" .. name .. "\" is already declared.")
		assert(not luameta.registry.classes[name], "class \"" .. name .. "\" is already registered.")
	end
	-- the class variable and the class metatable
	-- separated for the sake of accessing the __call meta
	local c = {}
	local cmt = {}
	setmetatable(c, cmt)
	-- for the syntactic sugar
	local new = {
		name = name,
		class = c,
		metatable = cmt,
		methods = {},
		parent = false,
		traits = {},
		hasAbstracts = false,
		abstractMethods = false,
		explicitAbstract = false,
		isFinal = false,
		finalMethods = {},
		inherited = false,
		properties = false,
		namespace = false,
		constructors = {},
		instantiated = false,
	}
	c.origin = new
	c.name = name
	cmt.__classdesc = new
	setmetatable(new, mt)
	-- declare the class globally (skip anonymous classes)
	if luameta.config.registerGlobally and not isAnonymous then _G[name] = c end
	luameta.registry.classes[name] = new
	local function inst_tostring(inst)
		return string.format("<%s: %p>", name, inst)
	end
	cmt.__tostring = inst_tostring
	cmt.__newindex = createNewIndexResolver(new)
	cmt.__call = function(this, ...)
		checkAbstracts(new)
		if new.hasAbstracts then
			return error("cannot instantiate abstract class \"" .. new.name .. "\"")
		end
		local instance = setmetatable({}, cmt)
		new.instantiated = true
		runConstructors(new, instance, ...)
		return instance
	end
	cmt.__index = createIndexResolver(new)
	return new
end

local function constructor(self, fn)
	assert(type(fn) == "function", "\"fn\" is not a function.")
	-- append the function
	self.constructors[#self.constructors + 1] = fn
	return self
end

local function extends(self, name)
	if self.instantiated then
		return error("extends: cannot extend class \"" .. self.name .. "\" after instances have been created.")
	end
	if self.inherited then
		return error("extends: class \"" .. self.name .. "\" has already inherited from a parent.")
	end
	local t
	if type(name) == "string" and name ~= self.name then
		local current = self.namespace
		while current do
			if current[name] then
				t = current[name]
				break
			end
			current = current.namespace
		end
		if not t then
			t = _G[name]
		end
		if not t then
			t = traitUtils.resolveFromNamespaces(name, nil, luameta.registry.namespaces)
		end
		if not t then
			local desc = luameta.registry.classes[name]
			if desc then t = desc.class end
		end
	elseif type(name) == "table" and name ~= self.class then
		t = name
		if not rawget(t, "origin") and rawget(t, "class") then
			t = rawget(t, "class")
		end
	end
	assert(t and rawget(t, "origin"), "extends: \"" .. tostring(name) .. "\" is not a valid class.")
	local po = rawget(t, "origin")
	local current = po
	while current do
		if current == self then
			return error("extends: circular inheritance detected: class \"" ..
				self.name .. "\" is already in the ancestry of \"" .. po.name .. "\".")
		end
		current = rawget(current, "parent")
	end
	if rawget(po, "isFinal") then
		return error("extends: cannot inherit from final class \"" .. po.name .. "\"")
	end
	self.parent = po
	po.children = po.children or {}
	po.children[self] = true
	if po.hasAbstracts then
		self.hasAbstracts = true
	end
	local c = self.class
	local cmt = self.metatable
	local pmt = po.metatable
	local nmt = {}
	nmt.__index = createIndexResolver(self)
	nmt.__classdesc = self
	for k, v in next, pmt do
		if k ~= "__index" and k ~= "__call" and k ~= "__newindex" then
			nmt[k] = v
		end
	end
	for k, v in next, cmt do
		if k ~= "__index" and k ~= "__call" and k ~= "__newindex" and k ~= "__tostring" then
			nmt[k] = v
		end
	end
	nmt.__newindex = createNewIndexResolver(self)
	nmt.__call = function(this, ...)
		checkAbstracts(self)
		if self.hasAbstracts then
			return error("cannot instantiate abstract class \"" .. self.name .. "\"")
		end
		local instance = {}
		setmetatable(instance, nmt)
		self.instantiated = true
		runConstructors(self, instance, ...)
		return instance
	end
	setmetatable(c, nmt)
	self.metatable = nmt
	self.inherited = true
	return self
end

local staticReserved = {
	origin = true,
	name = true,
	class = true,
	metatable = true,
	parent = true,
	methods = true,
	traits = true,
	hasAbstracts = true,
	abstractMethods = true,
	isFinal = true,
	finalMethods = true,
	inherited = true,
	properties = true,
	namespace = true,
	constructors = true,
}
local function static(self, t)
	assert(type(t) == "table", "\"t\" is not a table.")
	local c = self.class
	for k, v in next, t do
		if staticReserved[k] then
			return error("static: cannot override reserved field \"" .. k .. "\".")
		end
		rawset(c, k, v)
	end
	return self
end

local function method(self, t)
	assert(type(t) == "table", "\"t\" is not a table.")
	local methods = self.methods
	-- copy all elements to the methods map
	for k, v in next, t do
		local current = rawget(self, "parent")
		while current do
			if rawget(current, "finalMethods") and rawget(current, "finalMethods")[k] then
				return error("method: cannot override final method \"" .. k .. "\"")
			end
			current = rawget(current, "parent")
		end
		methods[k] = v
	end
	return self
end

local metaReserved = {
	__index = true,
	__newindex = true,
	__call = true,
	__gc = true,
	__classdesc = true,
	__metatable = true,
	__mode = true,
}
local function meta(self, t)
	assert(type(t) == "table", "meta: \"t\" is not a table.")
	local cmt = self.metatable
	for k, v in next, t do
		if metaReserved[k] then
			return error("meta: cannot redeclare \"" .. k .. "\".")
		end
		cmt[k] = v
	end
	return self
end

local function implements(self, spec)
	local function methodExists(desc, methodName)
		local curr = desc
		while curr do
			if rawget(curr.methods, methodName) ~= nil then return true end
			curr = rawget(curr, "parent")
		end
		return false
	end
	local t
	if type(spec) == "table" and isTrait(spec) then
		t = spec
	elseif type(spec) == "table" and spec.trait then
		t = spec.trait
	elseif type(spec) == "string" then
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
	if t and isTrait(t) then
		if traitUtils.traitMatches(t, self) then
			return error("implements: circular trait dependency detected for \"" .. t.name .. "\".")
		end
		table.insert(self.traits, t)
		local c = self.class
		local cmt = self.metatable
		local except = (type(spec) == "table" and spec.except) or {}
		local only = (type(spec) == "table" and spec.only)
		local alias = (type(spec) == "table" and spec.alias) or {}

		local function allowed(k)
			if only then
				for i = 1, #only do if only[i] == k then return true end end
				return false
			end
			for i = 1, #except do if except[i] == k then return false end end
			return true
		end
		local allStatics = traitUtils.collectTraitStatics(t)
		for k, v in next, allStatics do
			if allowed(k) then
				if c[k] ~= nil then return error(string.format("implements: static conflict '%s' from trait '%s'", k, t.name)) end
				rawset(c, k, v)
			end
		end
		local allMethods = traitUtils.collectTraitMethods(t)
		for k, v in next, allMethods do
			if allowed(k) then
				local dest = alias[k] or k
				if self.finalMethods[dest] then
					return error(string.format("implements: cannot override final method '%s' from trait '%s'", dest, t.name))
				end
				if self.methods[dest] ~= nil or methodExists(self, dest) then
					return error(string.format(
						"implements: method conflict '%s' from trait '%s'", dest, t.name))
				end
				self.methods[dest] = v
			end
		end
		local allMetas = traitUtils.collectTraitMetas(t)
		for k, v in next, allMetas do
			if allowed(k) and k ~= "__index" and k ~= "__newindex" then
				if cmt[k] ~= nil then return error(string.format("implements: meta conflict '%s' from trait '%s'", k, t.name)) end
				cmt[k] = v
			end
		end
	elseif spec ~= nil then
		return error("implements: \"" .. tostring(spec) .. "\" is not a trait.")
	end
	return self
end

local function propagateAbstracts(desc)
	if not desc.children then return end
	for child in next, desc.children do
		child.hasAbstracts = true
		propagateAbstracts(child)
	end
end

local function abstract(self, t)
	self.hasAbstracts = true
	if type(t) == "table" then
		self.abstractMethods = self.abstractMethods or {}
		for k, v in next, t do
			local methodName = (type(k) == "number") and v or k
			self.abstractMethods[methodName] = true
		end
		if not next(self.abstractMethods) then
			self.explicitAbstract = true
		end
	else
		self.explicitAbstract = true
	end
	propagateAbstracts(self)
	return self
end

local function final(self)
	rawset(self, "isFinal", true)
	return self
end

local function finalMethod(self, t)
	assert(type(t) == "table", "\"t\" is not a table.")
	for k, v in next, t do
		if self.finalMethods[k] then
			return error("finalMethod: cannot override final method \"" .. k .. "\"")
		end
		local current = rawget(self, "parent")
		while current do
			if rawget(current, "finalMethods") and rawget(current, "finalMethods")[k] then
				return error("finalMethod: cannot override final method \"" .. k .. "\"")
			end
			current = rawget(current, "parent")
		end
		self.finalMethods[k] = true
		self.methods[k] = v
	end
	return self
end

local function destructor(self, fn)
	assert(type(fn) == "function", "destructor: fn must be a function.")
	if self.instantiated then
		return error("destructor: cannot set destructor after instances have been created (Lua 5.4 semantics).")
	end
	self.metatable.__gc = fn
	return self
end

local function property(self, t)
	assert(type(t) == "table", "property: expected a table.")
	self.properties = self.properties or {}
	for k, spec in next, t do
		assert(type(spec) == "table", string.format("property: spec for '%s' must be a table", k))
		assert(spec.get or spec.set, string.format("property: spec for '%s' must have 'get' and/or 'set'", k))
		self.properties[k] = spec
	end
	return self
end

isInstance = function(obj, target)
	if type(obj) ~= "table" then return false end
	if rawget(obj, "origin") then return false end
	local mt = getmetatable(obj)
	if not mt then return false end
	local origin = rawget(mt, "__classdesc")
	if not origin then return false end
	local current = origin
	while current do
		if current == target or current.class == target or current.name == target then return true end
		local clist = current.traits or {}
		for i = 1, #clist do
			local trt = clist[i]
			if traitUtils.traitMatches(trt, target) then return true end
		end
		current = rawget(current, "parent")
	end
	return false
end

local builders = {
	constructor = constructor,
	extends = extends,
	static = static,
	method = method,
	meta = meta,
	implements = implements,
	abstract = abstract,
	final = final,
	finalMethod = finalMethod,
	destructor = destructor,
	property = property,
}

local class = setmetatable({}, mt)
mt.__call = function(self, ...)
	local c = rawget(self, "class")
	if c then
		return c(...)
	end
	return newClass(self, ...)
end
mt.__index = function(tbl, key)
	local b = rawget(builders, key)
	if b then return b end
	local c = rawget(tbl, "class")
	if c then
		local v = rawget(c, key)
		if v ~= nil then return v end
	end
	return nil
end
mt.__newindex = function(tbl, key, value)
	if classFieldProtected[key] then
		return error("cannot set protected field '" .. tostring(key) .. "'", 2)
	end
	local c = rawget(tbl, "class")
	if c then
		rawset(c, key, value)
	else
		rawset(tbl, key, value)
	end
end

class.is = isInstance
class.get = function(name) return luameta.registry.classes[name] end
class.isClass = function(t)
	if type(t) ~= "table" then return false end
	local o = rawget(t, "origin")
	return type(o) == "table" and getmetatable(o) == mt
end

-- Export
return class
