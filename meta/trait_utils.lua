-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

local collectTraitMethods
local collectTraitStatics
local collectTraitMetas
local traitMatches
local resolveFromNamespaces

--- Collect every method defined by a trait and its composed sub-traits.<br>
--- A method already collected wins, so a trait's own methods take precedence
--- over those inherited from the traits it composes.
---@param trait table The trait to collect methods from.
---@param seen? table Visited-trait set used to break recursion cycles.
---@return table methods Collected method map, keyed by method name.
collectTraitMethods = function(trait, seen)
	seen = seen or {}
	if seen[trait] then return {} end
	seen[trait] = true
	local collected = {}
	for k, v in next, trait.methods do
		collected[k] = v
	end
	local tt = trait.traits or {}
	for i = 1, #tt do
		local composed = tt[i]
		local sub = collectTraitMethods(composed, seen)
		for k, v in next, sub do
			if collected[k] == nil then
				collected[k] = v
			end
		end
	end
	return collected
end

--- Collect every static member defined by a trait and its composed sub-traits.<br>
--- A member already collected wins, so a trait's own statics take precedence
--- over those inherited from the traits it composes.
---@param trait table The trait to collect static members from.
---@param seen? table Visited-trait set used to break recursion cycles.
---@return table statics Collected static member map, keyed by name.
collectTraitStatics = function(trait, seen)
	seen = seen or {}
	if seen[trait] then return {} end
	seen[trait] = true
	local collected = {}
	for k, v in next, trait.statics do
		collected[k] = v
	end
	local tt = trait.traits or {}
	for i = 1, #tt do
		local composed = tt[i]
		local sub = collectTraitStatics(composed, seen)
		for k, v in next, sub do
			if collected[k] == nil then
				collected[k] = v
			end
		end
	end
	return collected
end

--- Collect every metamethod defined by a trait and its composed sub-traits.<br>
--- A metamethod already collected wins, so a trait's own metas take precedence
--- over those inherited from the traits it composes.
---@param trait table The trait to collect metamethods from.
---@param seen? table Visited-trait set used to break recursion cycles.
---@return table metas Collected metamethod map, keyed by metamethod name.
collectTraitMetas = function(trait, seen)
	seen = seen or {}
	if seen[trait] then return {} end
	seen[trait] = true
	local collected = {}
	for k, v in next, trait.metas do
		collected[k] = v
	end
	local tt = trait.traits or {}
	for i = 1, #tt do
		local composed = tt[i]
		local sub = collectTraitMetas(composed, seen)
		for k, v in next, sub do
			if collected[k] == nil then
				collected[k] = v
			end
		end
	end
	return collected
end

--- Determine whether a trait, or any trait it composes, matches a target.<br>
--- Cycle-safe: already-visited traits are skipped.
---@param trait table The trait to test.
---@param target table|string A trait table, or a trait name to match against.
---@param seen? table Visited-trait set used to break recursion cycles.
---@return boolean matches True if the trait chain includes the target.
traitMatches = function(trait, target, seen)
	seen = seen or {}
	if seen[trait] then return false end
	seen[trait] = true
	if trait == target or trait.name == target then return true end
	local tlist = trait.traits or {}
	for i = 1, #tlist do
		local composed = tlist[i]
		if traitMatches(composed, target, seen) then return true end
	end
	return false
end

--- Look up a member by name across a set of namespaces, visiting each namespace
--- in sorted key order.<br>
--- Returns the first value found that passes the validator, or `nil` if none do.
---@param name string Member name to look up in each namespace.
---@param validator? fun(value: any): boolean Predicate a candidate value must satisfy.
---@param namespaces table Map of namespace objects to search.
---@return any? value The first matching value, or `nil` if no namespace provided one.
resolveFromNamespaces = function(name, validator, namespaces)
	local keys = {}
	for k in pairs(namespaces) do
		keys[#keys + 1] = k
	end
	table.sort(keys)
	for i = 1, #keys do
		local ns = namespaces[keys[i]]
		local value = ns[name]
		if value and (not validator or validator(value)) then
			return value
		end
	end
	return nil
end

-- Export
return {
	collectTraitMethods = collectTraitMethods,
	collectTraitStatics = collectTraitStatics,
	collectTraitMetas = collectTraitMetas,
	traitMatches = traitMatches,
	resolveFromNamespaces = resolveFromNamespaces,
}
