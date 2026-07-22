-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

local collectTraitMethods
local collectTraitStatics
local collectTraitMetas
local traitMatches
local resolveFromNamespaces

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
