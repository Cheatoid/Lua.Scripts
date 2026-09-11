-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Predicate / filter combinators for LuaJIT/5.1+ and later

-- Localized global functions for better performance
local next = next
local setmetatable = setmetatable

----------------------------------------------------------------------
-- Types
----------------------------------------------------------------------

---@class filter Filter object with a predicate method
---@field filter fun(self: filter, item: any): boolean Test an item, called with colon syntax (`f:filter(item)`)

---@class FilterCombinators Fluent filter wrapper (see `new`)
---@field filter fun(self: FilterCombinators, item: any): boolean Test an item
---@field And fun(self: FilterCombinators, other: filter): FilterCombinators Combine with another filter (both must match)
---@field Or fun(self: FilterCombinators, other: filter): FilterCombinators Combine with another filter (either may match)
---@field Not fun(self: FilterCombinators): FilterCombinators Negate this filter
---@field All fun(self: FilterCombinators, ...: filter): FilterCombinators Match only if this and all extra filters match
---@field Any fun(self: FilterCombinators, ...: filter): FilterCombinators Match if this or any extra filter matches
---@field Some fun(self: FilterCombinators, ...: filter): FilterCombinators Alias of `Any`
---@field OneOf fun(self: FilterCombinators, ...: filter): FilterCombinators Match only if exactly one filter matches
---@field NoneOf fun(self: FilterCombinators, ...: filter): FilterCombinators Match only if no filter matches

----------------------------------------------------------------------
-- Core combinators (return plain filter objects)
----------------------------------------------------------------------

--- AND combinator. Outputs true only if both filters match
---@param a filter First filter object
---@param b filter Second filter object
---@return filter f New filter matching only items that pass both `a` and `b`
---@usage <br>
--- ```
--- local f = And(is_admin, is_active)
--- f:filter(user) -- true only if both match
--- ```
local function And(a, b)
	return {
		filter = function(self, item)
			return a:filter(item) and b:filter(item)
		end
	}
end

--- OR combinator. Outputs true if at least one filter matches
---@param a filter First filter object
---@param b filter Second filter object
---@return filter f New filter matching items that pass either `a` or `b`
---@usage <br>
--- ```
--- local f = Or(is_admin, is_moderator)
--- f:filter(user) -- true if either matches
--- ```
local function Or(a, b)
	return {
		filter = function(self, item)
			return a:filter(item) or b:filter(item)
		end
	}
end

--- NOT combinator (inverter)
---@param f filter Filter object to negate
---@return filter inv New filter matching items that do not pass `f`
---@usage <br>
--- ```
--- local f = Not(is_banned)
--- f:filter(user) -- true if user is not banned
--- ```
local function Not(f)
	return {
		filter = function(self, item)
			return not f:filter(item)
		end
	}
end

--- ALL combinator. Outputs true if every filter matches
---@param ... filter Filter objects (at least one)
---@return filter f New filter matching only items that pass all given filters
---@usage <br>
--- ```
--- local f = All(is_admin, is_active, has_email)
--- f:filter(user) -- true only if all three match
--- ```
local function All(...)
	local filters = { ... }
	return {
		filter = function(self, item)
			for i = 1, #filters do
				local f = filters[i]
				if not f:filter(item) then
					return false
				end
			end
			return true
		end
	}
end

--- ANY combinator. Outputs true if at least one filter matches
---@param ... filter Filter objects (at least one)
---@return filter f New filter matching items that pass any of the given filters
---@usage <br>
--- ```
--- local f = Any(is_admin, is_moderator, is_owner)
--- f:filter(user) -- true if any of them matches
--- ```
local function Any(...)
	local filters = { ... }
	return {
		filter = function(self, item)
			for i = 1, #filters do
				local f = filters[i]
				if f:filter(item) then
					return true
				end
			end
			return false
		end
	}
end

--- ONE-OF combinator (exclusive match). Outputs true if exactly one filter matches
---@param ... filter Filter objects (at least one)
---@return filter f New filter matching only items that pass exactly one given filter
---@usage <br>
--- ```
--- local f = OneOf(is_admin, is_guest)
--- f:filter(user) -- true if exactly one matches, false if both or neither match
--- ```
local function OneOf(...)
	local filters = { ... }
	return {
		filter = function(self, item)
			local first = false
			for i = 1, #filters do
				local f = filters[i]
				if f:filter(item) then
					if first then
						return false
					end
					first = true
				end
			end
			return first
		end
	}
end

--- NONE-OF combinator (inverted ANY). Outputs true only when no filter matches
---@param ... filter Filter objects (at least one)
---@return filter f New filter matching only items rejected by all given filters
---@usage <br>
--- ```
--- local f = NoneOf(is_banned, is_muted)
--- f:filter(user) -- true only if neither matches
--- ```
local function NoneOf(...)
	local filters = { ... }
	return {
		filter = function(self, item)
			for i = 1, #filters do
				local f = filters[i]
				if f:filter(item) then
					return false
				end
			end
			return true
		end
	}
end

----------------------------------------------------------------------
-- Fluent wrapper
----------------------------------------------------------------------

-- Variadic combinators - define them all in one loop.
-- Each fluent method receives `self` plus any extra filters,
-- and passes them directly to the corresponding core combinator.
local methods = {
	All = All,
	Any = Any,
	Some = Any, -- alias
	OneOf = OneOf,
	NoneOf = NoneOf,
}

--- Create a fluent filter wrapper around a plain filter object<br>
--- The wrapper keeps the original `filter` behaviour and adds chainable
--- `And` / `Or` / `Not` / `All` / `Any` / `Some` / `OneOf` / `NoneOf` methods.
--- Each chained call returns a new wrapped filter, so chains can continue.
---@param f filter Plain filter object exposing `f:filter(item)`
---@return FilterCombinators obj New fluent wrapper around `f`
---@usage <br>
--- ```
--- local f = new(is_admin):And(is_active):Not()
--- f:filter(user) -- true if user is not (admin and active)
---
--- local g = new(is_admin):Any(is_moderator, is_owner)
--- g:filter(user) -- true if admin, moderator or owner
--- ```
local function new(f)
	local obj = {
		-- Original filter behaviour
		filter = function(self, item)
			return f:filter(item)
		end,

		-- Binary combinators (special: take exactly one other filter)
		And = function(self, other)
			return new(And(self, other))
		end,
		Or = function(self, other)
			return new(Or(self, other))
		end,
		Not = function(self)
			return new(Not(self))
		end,
	}

	for name, combinator in next, methods do
		obj[name] = function(self, ...)
			-- Call the core combinator with self as first filter plus all extras
			return new(combinator(self, ...))
		end
	end

	-- Enable colon syntax: obj:method(...) works like obj.method(obj, ...)
	return setmetatable(obj, { __index = obj })
end

-- Export
return {
	-- Core combinators (return plain filter objects)
	And    = And,   -- both filters must match
	Or     = Or,    -- either filter may match
	Not    = Not,   -- negates a filter
	All    = All,   -- every filter must match
	Any    = Any,   -- at least one filter must match
	Some   = Any,   -- alias of Any
	OneOf  = OneOf, -- exactly one filter must match
	NoneOf = NoneOf, -- no filter may match

	-- Fluent wrapper
	new    = new, -- wrap a filter for chainable And/Or/Not/All/Any/Some/OneOf/NoneOf
}
