-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

--[[
	Modular permission system combining simplicity with performance.
	Provides a clean API for managing permissions with bit-packed storage for efficiency.
	Supports category-level overrides, multi-registry support, and freeze concept for immutable registries.

	Features:
	* Clean simple API (grant/deny/reset/is_allowed)
	* STATE_UNSET/ALLOW/DENY enum for UI/advanced use
	* Bit-packed storage for performance
	* Category-level overrides for unset permissions
	* Auto-generated dot IDs (category.action)
	* Human-readable and compact wire serialization
	* Optional multi-registry support
	* Freeze concept for immutable registries
	* LuaJIT/5.1+ compatible

	Simple usage (default registry):
	```
	local perm = require "permission/permission"
	perm.define_category("chat", {
		{ name = "send", default = true, description = "Send messages" },
		{ name = "read", default = true },
		"mute",  -- shorthand: name only, default=false
	})
	local ctx = perm.new_context()
	perm.deny(ctx, "chat.mute")
	if perm.is_allowed(ctx, "chat.send") then
		-- ...
	end
	perm.require(ctx, "chat.send")  -- errors if not allowed
	```

	Multi-registry usage:
	```
	local reg = perm.new_registry(STATE_DENY)
	perm.define_category_on(reg, "admin", { "kick", "ban" })
	local ctx = perm.new_context_on(reg)
	perm.grant(ctx, "admin.kick")
	```
]]

----------------------------------------------------------------------
-- Localized global functions for better performance
----------------------------------------------------------------------

local error = error
local next = next
local tonumber = tonumber
local tostring = tostring
local type = type
local math_floor = math.floor
local table_concat = table.concat
local table_insert = table.insert
local table_sort = table.sort

----------------------------------------------------------------------
-- Forward declarations for local functions
----------------------------------------------------------------------

local define_category
local define_category_on
local deny
local deny_category
local describe_context
local each_category
local each_category_on
local each_permission
local each_permission_on
local freeze_registry
local from_table
local from_table_on
local from_wire
local from_wire_on
local get_category
local get_category_on
local get_category_state
local get_default
local get_default_on
local get_effective_state
local get_permission
local get_permission_on
local get_state
local grant
local grant_category
local is_allowed
local is_denied
local is_denied_explicit
local is_granted_explicit
local list_permissions
local list_permissions_on
local new_context
local new_context_on
local new_registry
local require_permission
local reset
local reset_category
local set_category_state
local set_state
local state_name
local to_table
local to_wire

----------------------------------------------------------------------
-- State constants
----------------------------------------------------------------------

local STATE_UNSET = 0
local STATE_ALLOW = 1
local STATE_DENY = 2

----------------------------------------------------------------------
-- Bit operations (Lua 5.1+ compatible)
----------------------------------------------------------------------

local bit = require "../standalone/bit"
local band = bit.band
local bor = bit.bor
local bnot = bit.bnot
local lshift = bit.lshift

local BITS_PER_CHUNK = 32

-- TODO: Move these to Lua lib (bit)
local bit_get = function(bits, index)
	local chunk = math_floor((index - 1) / BITS_PER_CHUNK) + 1
	local offset = (index - 1) % BITS_PER_CHUNK
	return band(bits[chunk] or 0, lshift(1, offset)) ~= 0
end

local bit_set = function(bits, index, value)
	local chunk = math_floor((index - 1) / BITS_PER_CHUNK) + 1
	local offset = (index - 1) % BITS_PER_CHUNK
	local mask = lshift(1, offset)
	local v = bits[chunk] or 0
	bits[chunk] = value and bor(v, mask) or band(v, bnot(mask))
end

----------------------------------------------------------------------
-- Validation helpers
----------------------------------------------------------------------

local assert_string = function(name, value, lvl)
	if type(value) ~= "string" or value == "" then
		return error(name .. " must be a non-empty string", lvl or 3)
	end
end

local assert_table = function(name, value, lvl)
	if type(value) ~= "table" then
		return error(name .. " must be a table", lvl or 3)
	end
end

local is_state = function(v)
	return v == 0 or v == 1 or v == 2
end

local assert_state = function(name, value, lvl)
	if not is_state(value) then
		return error(name .. " must be STATE_UNSET, STATE_ALLOW, or STATE_DENY", lvl or 3)
	end
end

----------------------------------------------------------------------
-- Default registry (created early for simple API)
----------------------------------------------------------------------

local _default

----------------------------------------------------------------------
-- Registry
----------------------------------------------------------------------

--- Create a new permission registry.<br>
--- Creates a fresh registry for defining categories and managing permissions.<br>
--- Supports custom default state and can be frozen to prevent modifications.
---@param default_state? integer Default state for permissions (default: STATE_DENY).
---@return table registry The new registry instance.
---@usage <br>
--- ```
--- local reg = new_registry(STATE_ALLOW)
--- ```
new_registry = function(default_state)
	default_state = default_state or STATE_DENY
	assert_state("default_state", default_state, 2)

	return {
		frozen = false,
		default_state = default_state,
		categories = {},
		permissions = {},
		perm_index = {},
		perm_by_index = {},
		default_allowed = {},
		_next_index = 0,
	}
end

--- Freeze a registry to prevent further modifications.<br>
--- Marks the registry as immutable, preventing any future category definitions or modifications.<br>
--- Once frozen, no new categories or permissions can be added to the registry.
---@param reg table The registry to freeze.
---@return table reg The frozen registry (same instance).
---@usage <br>
--- ```
--- freeze_registry(reg)
--- ```
freeze_registry = function(reg)
	assert_table("reg", reg, 2)
	reg.frozen = true
	return reg
end

local check_not_frozen = function(reg, lvl)
	if reg.frozen then
		return error("Registry is frozen", lvl or 3)
	end
end

local compute_default_allowed = function(reg, perm)
	local st = perm.default_state
	if st == STATE_UNSET then
		local cat = reg.categories[perm.category]
		local cat_st = cat and cat.default_state or STATE_UNSET
		st = cat_st == STATE_UNSET and reg.default_state or cat_st
	end
	return st == STATE_ALLOW
end

----------------------------------------------------------------------
-- Category & permission definition
----------------------------------------------------------------------

local define_category_impl = function(reg, category_name, permissions_spec, default_state, description)
	check_not_frozen(reg, 3)
	assert_string("category_name", category_name, 3)
	assert_table("permissions_spec", permissions_spec, 3)

	default_state = default_state or STATE_UNSET
	assert_state("category default_state", default_state, 3)

	local category = reg.categories[category_name]
	if not category then
		category = {
			id = category_name,
			description = description,
			default_state = default_state,
			order = {},
			perms = {},
		}
	else
		if description then
			category.description = description
		end
		if default_state ~= STATE_UNSET then
			category.default_state = default_state
		end
	end

	for i = 1, #permissions_spec do
		local spec = permissions_spec[i]
		local perm_name, perm_default, perm_desc

		if type(spec) == "string" then
			perm_name = spec
			perm_default = STATE_UNSET
		elseif type(spec) == "table" then
			perm_name = spec.name or spec.id
			if not perm_name then
				return error("Permission spec missing 'name' field at index " .. i, 2)
			end
			if spec.default ~= nil then
				if type(spec.default) == "boolean" then
					perm_default = spec.default and STATE_ALLOW or STATE_DENY
				else
					perm_default = spec.default
				end
			else
				perm_default = STATE_UNSET
			end
			perm_desc = spec.description
		else
			return error("Invalid permission spec type at index " .. i, 2)
		end

		assert_string("permission name", perm_name, 3)

		if category.perms[perm_name] then
			return error("Duplicate permission in category '" .. category_name .. "': " .. perm_name, 2)
		end

		local full_id = category_name .. "." .. perm_name
		if reg.permissions[full_id] then
			return error("Permission already defined: " .. full_id, 2)
		end

		assert_state("permission default_state", perm_default, 3)

		reg._next_index = reg._next_index + 1
		local idx = reg._next_index

		local perm_def = {
			id = full_id,
			category = category_name,
			name = perm_name,
			default_state = perm_default,
			description = perm_desc,
			index = idx,
		}

		category.perms[perm_name] = perm_def
		category.order[#category.order + 1] = perm_name
		reg.permissions[full_id] = perm_def
		reg.perm_index[full_id] = idx
		reg.perm_by_index[idx] = perm_def
		reg.default_allowed[idx] = compute_default_allowed(reg, perm_def)
	end

	reg.categories[category_name] = category
	return category
end

--- Define a category on the default registry.<br>
--- Creates a new permission category with specified permissions on the default registry.<br>
--- Each permission is assigned a dot-separated ID (category.permission).<br>
--- Permission specs can be strings (shorthand) or tables with name/default/description.
---@param category_name string Unique identifier for the category.
---@param permissions_spec table Array of permission specs (strings or tables with name/default/description).
---@param default_state? integer Default state for permissions in this category (default: STATE_UNSET).
---@param description? string Human-readable description of the category.
---@return table category The category definition.
---@usage <br>
--- ```
--- define_category("chat", {
---   { name = "send", default = true, description = "Send messages" },
---   { name = "read", default = true },
---   "mute"
--- }, STATE_ALLOW, "Chat permissions")
--- ```
define_category = function(category_name, permissions_spec, default_state, description)
	return define_category_impl(_default, category_name, permissions_spec, default_state, description)
end

--- Define a category on a specific registry.<br>
--- Creates a new permission category with specified permissions on the given registry.<br>
--- Each permission is assigned a dot-separated ID (category.permission).<br>
--- Use this for multi-registry scenarios.
---@param reg table The registry to define the category on.
---@param category_name string Unique identifier for the category.
---@param permissions_spec table Array of permission specs (strings or tables with name/default/description).
---@param default_state? integer Default state for permissions in this category (default: STATE_UNSET).
---@param description? string Human-readable description of the category.
---@return table category The category definition.
---@usage <br>
--- ```
--- define_category_on(reg, "admin", { "kick", "ban" })
--- ```
define_category_on = function(reg, category_name, permissions_spec, default_state, description)
	return define_category_impl(reg, category_name, permissions_spec, default_state, description)
end

----------------------------------------------------------------------
-- Context (per-client permission state)
----------------------------------------------------------------------

--- Create a new permission context on the default registry.<br>
--- Creates a fresh context for tracking permission states for a user/entity.<br>
--- Can be initialized with existing permission states in multiple formats.<br>
--- Contexts are independent and can be serialized for storage/transmission.
---@param initial? table Optional initial state (granted/denied arrays, states map, category_overrides).
--- - granted (table): Array of permission IDs to grant.
--- - denied (table): Array of permission IDs to deny.
--- - states (table): Map of permission IDs to states.
--- - category_overrides (table): Map of category IDs to states.
---@return table ctx The new context instance.
---@usage <br>
--- ```
--- local ctx = new_context({
---   granted = { "chat.send" },
---   denied = { "chat.mute" }
--- })
--- ```
new_context = function(initial)
	return new_context_on(_default, initial)
end

--- Create a new permission context on a specific registry.<br>
--- Creates a fresh context for tracking permission states for a user/entity.<br>
--- Can be initialized with existing permission states in multiple formats.<br>
--- Use this for multi-registry scenarios.
---@param reg table The registry to create the context on.
---@param initial? table Optional initial state (granted/denied arrays, states map, category_overrides).
--- - granted (table): Array of permission IDs to grant.
--- - denied (table): Array of permission IDs to deny.
--- - states (table): Map of permission IDs to states.
--- - category_overrides (table): Map of category IDs to states.
---@return table ctx The new context instance.
---@usage <br>
--- ```
--- local ctx = new_context_on(reg)
--- ```
new_context_on = function(reg, initial)
	assert_table("reg", reg, 2)
	if not reg.perm_by_index then
		return error("Invalid registry", 2)
	end

	local ctx = {
		reg = reg,
		allow_bits = {},
		deny_bits = {},
		category_overrides = {},
	}

	if initial then
		assert_table("initial", initial, 2)

		-- File 1 compatible format: { granted = {...}, denied = {...} }
		if initial.granted then
			for i = 1, #initial.granted do
				local id = initial.granted[i]
				grant(ctx, id)
			end
		end
		if initial.denied then
			for i = 1, #initial.denied do
				local id = initial.denied[i]
				deny(ctx, id)
			end
		end

		-- State map format: { states = { ["chat.send"] = STATE_ALLOW } }
		if initial.states then
			for id, state in next, initial.states do
				set_state(ctx, id, state)
			end
		end

		-- Category overrides
		if initial.category_overrides then
			for cat_id, state in next, initial.category_overrides do
				set_category_state(ctx, cat_id, state)
			end
		end
	end

	return ctx
end

----------------------------------------------------------------------
-- Permission state operations
----------------------------------------------------------------------

--- Grant a permission.<br>
--- Sets the permission state to STATE_ALLOW for the given context.<br>
--- Explicit grants take precedence over category overrides and defaults.
---@param ctx table The permission context.
---@param id string The permission ID (category.action format).
---@usage <br>
--- ```
--- grant(ctx, "chat.send")
--- ```
grant = function(ctx, id)
	return set_state(ctx, id, STATE_ALLOW)
end

--- Deny a permission.<br>
--- Sets the permission state to STATE_DENY for the given context.<br>
--- Explicit denies take precedence over category overrides and defaults.
---@param ctx table The permission context.
---@param id string The permission ID (category.action format).
---@usage <br>
--- ```
--- deny(ctx, "chat.mute")
--- ```
deny = function(ctx, id)
	return set_state(ctx, id, STATE_DENY)
end

--- Reset a permission to unset.<br>
--- Sets the permission state to STATE_UNSET for the given context.<br>
--- After reset, the permission will use category override or registry default.
---@param ctx table The permission context.
---@param id string The permission ID (category.action format).
---@usage <br>
--- ```
--- reset(ctx, "chat.send")
--- ```
reset = function(ctx, id)
	return set_state(ctx, id, STATE_UNSET)
end

--- Set the explicit state of a permission.<br>
--- Directly sets the permission state, overriding any previous explicit state.<br>
--- Prefer using grant/deny/reset for clarity.
---@param ctx table The permission context.
---@param id string The permission ID (category.action format).
---@param state integer The state to set (STATE_UNSET, STATE_ALLOW, or STATE_DENY).
---@usage <br>
--- ```
--- set_state(ctx, "chat.send", STATE_ALLOW)
--- ```
set_state = function(ctx, id, state)
	assert_table("ctx", ctx, 2)
	assert_state("state", state, 2)

	local reg = ctx.reg
	local idx = reg.perm_index[id]
	if not idx then
		return error("Unknown permission: " .. tostring(id), 2)
	end

	if state == STATE_ALLOW then
		bit_set(ctx.allow_bits, idx, true)
		bit_set(ctx.deny_bits, idx, false)
	elseif state == STATE_DENY then
		bit_set(ctx.allow_bits, idx, false)
		bit_set(ctx.deny_bits, idx, true)
	else
		bit_set(ctx.allow_bits, idx, false)
		bit_set(ctx.deny_bits, idx, false)
	end
end

--- Get the explicit state of a permission.<br>
--- Returns the explicitly set state (STATE_UNSET if not explicitly set).<br>
--- To get the final effective state (considering overrides/defaults), use get_effective_state.
---@param ctx table The permission context.
---@param id string The permission ID (category.action format).
---@return integer state The explicit state (STATE_UNSET, STATE_ALLOW, or STATE_DENY).
---@usage <br>
--- ```
--- local state = get_state(ctx, "chat.send")
--- ```
get_state = function(ctx, id)
	assert_table("ctx", ctx, 2)
	local reg = ctx.reg
	local idx = reg.perm_index[id]
	if not idx then
		return error("Unknown permission: " .. tostring(id), 2)
	end

	if bit_get(ctx.allow_bits, idx) then return STATE_ALLOW end
	if bit_get(ctx.deny_bits, idx) then return STATE_DENY end
	return STATE_UNSET
end

----------------------------------------------------------------------
-- Category operations
----------------------------------------------------------------------

--- Explicitly grant every permission in a category.<br>
--- Sets STATE_ALLOW for all permissions in the specified category.<br>
--- Useful for bulk operations on related permissions.
---@param ctx table The permission context.
---@param category_name string The category name.
---@usage <br>
--- ```
--- grant_category(ctx, "chat")
--- ```
grant_category = function(ctx, category_name)
	assert_table("ctx", ctx, 2)
	local cat = ctx.reg.categories[category_name]
	if not cat then
		return error("Unknown category: " .. tostring(category_name), 2)
	end
	for i = 1, #cat.order do
		local name = cat.order[i]
		grant(ctx, category_name .. "." .. name)
	end
end

--- Explicitly deny every permission in a category.<br>
--- Sets STATE_DENY for all permissions in the specified category.<br>
--- Useful for bulk operations on related permissions.
---@param ctx table The permission context.
---@param category_name string The category name.
---@usage <br>
--- ```
--- deny_category(ctx, "admin")
--- ```
deny_category = function(ctx, category_name)
	assert_table("ctx", ctx, 2)
	local cat = ctx.reg.categories[category_name]
	if not cat then
		return error("Unknown category: " .. tostring(category_name), 2)
	end
	for i = 1, #cat.order do
		local name = cat.order[i]
		deny(ctx, category_name .. "." .. name)
	end
end

--- Reset every permission in a category to UNSET.<br>
--- Sets STATE_UNSET for all permissions in the specified category.<br>
--- After reset, permissions will use category override or registry default.
---@param ctx table The permission context.
---@param category_name string The category name.
---@usage <br>
--- ```
--- reset_category(ctx, "chat")
--- ```
reset_category = function(ctx, category_name)
	assert_table("ctx", ctx, 2)
	local cat = ctx.reg.categories[category_name]
	if not cat then
		return error("Unknown category: " .. tostring(category_name), 2)
	end
	for i = 1, #cat.order do
		local name = cat.order[i]
		reset(ctx, category_name .. "." .. name)
	end
end

--- Set a category override that affects permissions with STATE_UNSET.<br>
--- Sets a default state for all unset permissions in the category.<br>
--- Category overrides provide a way to set default behavior for a whole category.<br>
--- Set to STATE_UNSET to remove the override.
---@param ctx table The permission context.
---@param category_name string The category name.
---@param state integer The override state (STATE_UNSET, STATE_ALLOW, or STATE_DENY).
---@usage <br>
--- ```
--- set_category_state(ctx, "chat", STATE_DENY)
--- ```
set_category_state = function(ctx, category_name, state)
	assert_table("ctx", ctx, 2)
	assert_string("category_name", category_name, 2)
	assert_state("state", state, 2)

	if not ctx.reg.categories[category_name] then
		return error("Unknown category: " .. tostring(category_name), 2)
	end

	if state == STATE_UNSET then
		ctx.category_overrides[category_name] = nil
	else
		ctx.category_overrides[category_name] = state
	end
end

--- Get the category override state.<br>
--- Returns the override state for the category, or STATE_UNSET if not set.
---@param ctx table The permission context.
---@param category_name string The category name.
---@return integer state The override state (STATE_UNSET, STATE_ALLOW, or STATE_DENY).
get_category_state = function(ctx, category_name)
	assert_table("ctx", ctx, 2)
	return ctx.category_overrides[category_name] or STATE_UNSET
end

----------------------------------------------------------------------
-- Permission queries
----------------------------------------------------------------------

--- Resolve the final allowed state (explicit > category override > default).<br>
--- Returns true if the permission is allowed, considering explicit state, category overrides, and defaults.<br>
--- Resolution order: explicit grant > explicit deny > category override > registry default.
---@param ctx table The permission context.
---@param id string The permission ID (category.action format).
---@return boolean allowed True if permission is allowed.
---@usage <br>
--- ```
--- if is_allowed(ctx, "chat.send") then
---   -- allow action
--- end
--- ```
is_allowed = function(ctx, id)
	assert_table("ctx", ctx, 2)
	local reg = ctx.reg
	local idx = reg.perm_index[id]
	if not idx then
		return error("Unknown permission: " .. tostring(id), 2)
	end

	if bit_get(ctx.allow_bits, idx) then return true end
	if bit_get(ctx.deny_bits, idx) then return false end

	local perm = reg.perm_by_index[idx]
	local cat_state = ctx.category_overrides[perm.category]
	if cat_state == STATE_ALLOW then return true end
	if cat_state == STATE_DENY then return false end

	return reg.default_allowed[idx] == true
end

--- Check if a permission is denied.<br>
--- Returns true if the permission is not allowed.<br>
--- Equivalent to not is_allowed().
---@param ctx table The permission context.
---@param id string The permission ID (category.action format).
---@return boolean denied True if permission is denied.
---@usage <br>
--- ```
--- if is_denied(ctx, "chat.mute") then
---   -- deny action
--- end
--- ```
is_denied = function(ctx, id)
	return not is_allowed(ctx, id)
end

--- Check if a permission is explicitly granted.<br>
--- Returns true only if the permission has explicit STATE_ALLOW.
---@param ctx table The permission context.
---@param id string The permission ID (category.action format).
---@return boolean granted True if permission is explicitly granted.
is_granted_explicit = function(ctx, id)
	return get_state(ctx, id) == STATE_ALLOW
end

--- Check if a permission is explicitly denied.<br>
--- Returns true only if the permission has explicit STATE_DENY.
---@param ctx table The permission context.
---@param id string The permission ID (category.action format).
---@return boolean denied True if permission is explicitly denied.
is_denied_explicit = function(ctx, id)
	return get_state(ctx, id) == STATE_DENY
end

--- Get the effective and explicit states of a permission.<br>
--- Returns both the final effective state and whether it was explicitly set.<br>
--- explicit_state is STATE_UNSET when the result comes from override/default.
---@param ctx table The permission context.
---@param id string The permission ID (category.action format).
---@return integer effective_state The final resolved state.
---@return integer explicit_state The explicitly set state (STATE_UNSET if from override/default).
get_effective_state = function(ctx, id)
	local explicit = get_state(ctx, id)
	if explicit ~= STATE_UNSET then
		return explicit, explicit
	end

	local reg = ctx.reg
	local idx = reg.perm_index[id]
	local perm = reg.perm_by_index[idx]
	local cat_state = ctx.category_overrides[perm.category]

	if cat_state == STATE_ALLOW then
		return STATE_ALLOW, STATE_UNSET
	elseif cat_state == STATE_DENY then
		return STATE_DENY, STATE_UNSET
	end

	if reg.default_allowed[idx] then
		return STATE_ALLOW, STATE_UNSET
	end
	return STATE_DENY, STATE_UNSET
end

--- Get the default allowed state for a permission on the default registry.<br>
--- Returns true if the permission defaults to allowed.
---@param id string The permission ID (category.action format).
---@return boolean default_allowed True if permission defaults to allowed.
get_default = function(id)
	local idx = _default.perm_index[id]
	if not idx then
		return error("Unknown permission: " .. tostring(id), 2)
	end
	return _default.default_allowed[idx]
end

--- Get the default allowed state for a permission on a specific registry.<br>
--- Returns true if the permission defaults to allowed.
---@param reg table The registry to query.
---@param id string The permission ID (category.action format).
---@return boolean default_allowed True if permission defaults to allowed.
get_default_on = function(reg, id)
	local idx = reg.perm_index[id]
	if not idx then
		return error("Unknown permission: " .. tostring(id), 2)
	end
	return reg.default_allowed[idx]
end

--- Require a permission to be allowed; error if not.<br>
--- Throws an error if the permission is not allowed, with an optional custom message.<br>
--- Useful for guard clauses and permission checks.
---@param ctx table The permission context.
---@param id string The permission ID (category.action format).
---@param message? string Optional error message.
---@usage <br>
--- ```
--- require_permission(ctx, "chat.send", "You must have chat permissions")
--- ```
require_permission = function(ctx, id, message)
	if not is_allowed(ctx, id) then
		return error(message or ("Permission denied: " .. tostring(id)), 2)
	end
end

----------------------------------------------------------------------
-- Registry queries
----------------------------------------------------------------------

--- Get a category from the default registry.<br>
--- Returns the category definition or nil if not found.
---@param category_name string The category name.
---@return table? category The category definition, or nil if not found.
get_category = function(category_name)
	return _default.categories[category_name]
end

--- Get a category from a specific registry.<br>
--- Returns the category definition or nil if not found.
---@param reg table The registry to query.
---@param category_name string The category name.
---@return table? category The category definition, or nil if not found.
get_category_on = function(reg, category_name)
	return reg.categories[category_name]
end

--- Get a permission from the default registry.<br>
--- Returns the permission definition or nil if not found.
---@param id string The permission ID (category.action format).
---@return table? permission The permission definition, or nil if not found.
get_permission = function(id)
	return _default.permissions[id]
end

--- Get a permission from a specific registry.<br>
--- Returns the permission definition or nil if not found.
---@param reg table The registry to query.
---@param id string The permission ID (category.action format).
---@return table? permission The permission definition, or nil if not found.
get_permission_on = function(reg, id)
	return reg.permissions[id]
end

--- Iterate over all categories in the default registry.<br>
--- Calls the callback for each category; return false to stop iteration.
---@param callback fun(category: table): boolean? Callback function, return true to continue iteration, false to stop iterations
each_category = function(callback)
	for _, cat in next, _default.categories do
		if callback(cat) == false then break end
	end
end

--- Iterate over all categories in a specific registry.<br>
--- Calls the callback for each category; return false to stop iteration.
---@param reg table The registry to iterate over.
---@param callback fun(category: table): boolean? Callback function, return true to continue iteration, false to stop iterations
each_category_on = function(reg, callback)
	for _, cat in next, reg.categories do
		if callback(cat) == false then break end
	end
end

--- Iterate over all permissions in a category on the default registry.<br>
--- Calls the callback for each permission; return false to stop iteration.
---@param category_name string The category name.
---@param callback fun(permission: table): boolean? Callback function, return true to continue iteration, false to stop iterations
each_permission = function(category_name, callback)
	local cat = _default.categories[category_name]
	if not cat then
		return error("Unknown category: " .. tostring(category_name), 2)
	end
	for i = 1, #cat.order do
		local name = cat.order[i]
		if callback(cat.perms[name]) == false then break end
	end
end

--- Iterate over all permissions in a category on a specific registry.<br>
--- Calls the callback for each permission; return false to stop iteration.
---@param reg table The registry to iterate over.
---@param category_name string The category name.
---@param callback fun(permission: table): boolean? Callback function, return true to continue iteration, false to stop iterations
each_permission_on = function(reg, category_name, callback)
	local cat = reg.categories[category_name]
	if not cat then
		return error("Unknown category: " .. tostring(category_name), 2)
	end
	for i = 1, #cat.order do
		local name = cat.order[i]
		if callback(cat.perms[name]) == false then break end
	end
end

--- List all permission IDs from the default registry, optionally sorted.<br>
--- Returns an array of all permission IDs.
---@param sort? boolean Whether to sort the result (default: true).
---@return table ids Array of permission IDs.
list_permissions = function(sort)
	sort = sort ~= false
	local out = {}
	for id in next, _default.permissions do
		table_insert(out, id)
	end
	if sort then table_sort(out) end
	return out
end

--- List all permission IDs from a specific registry, optionally sorted.<br>
--- Returns an array of all permission IDs.
---@param reg table The registry to list permissions from.
---@param sort? boolean Whether to sort the result (default: true).
---@return table ids Array of permission IDs.
list_permissions_on = function(reg, sort)
	sort = sort ~= false
	local out = {}
	for id in next, reg.permissions do
		table_insert(out, id)
	end
	if sort then table_sort(out) end
	return out
end

----------------------------------------------------------------------
-- Serialization: human-readable table format
----------------------------------------------------------------------

--- Convert a context to a human-readable table format.<br>
--- Returns a table with granted/denied arrays and category overrides.<br>
--- Useful for debugging, logging, or human-readable storage.
---@param ctx table The permission context.
---@return table data Serialized data with granted, denied, and category_overrides fields.
---@usage <br>
--- ```
--- local data = to_table(ctx)
--- print(data.granted[1])
--- ```
to_table = function(ctx)
	assert_table("ctx", ctx, 2)
	local reg = ctx.reg

	local granted, denied = {}, {}
	for id, perm in next, reg.permissions do
		if bit_get(ctx.allow_bits, perm.index) then
			table_insert(granted, id)
		elseif bit_get(ctx.deny_bits, perm.index) then
			table_insert(denied, id)
		end
	end
	table_sort(granted)
	table_sort(denied)

	local result = { granted = granted, denied = denied }

	if next(ctx.category_overrides) then
		local cats = {}
		for k, v in next, ctx.category_overrides do cats[k] = v end
		result.category_overrides = cats
	end

	return result
end

--- Convert a table format to a context on the default registry.<br>
--- Creates a context from serialized table data.<br>
--- Reconstructs a context from human-readable table serialization.
---@param data table Serialized data with granted, denied, and optional category_overrides fields.
---@return table ctx The reconstructed context.
---@usage <br>
--- ```
--- local ctx = from_table({
---   granted = { "chat.send" },
---   denied = { "chat.mute" }
--- })
--- ```
from_table = function(data)
	return from_table_on(_default, data)
end

--- Convert a table format to a context on a specific registry.<br>
--- Creates a context from serialized table data.<br>
--- Use this for multi-registry scenarios.
---@param reg table The registry to create the context on.
---@param data table Serialized data with granted, denied, and optional category_overrides fields.
---@return table ctx The reconstructed context.
---@usage <br>
--- ```
--- local ctx = from_table_on(reg, data)
--- ```
from_table_on = function(reg, data)
	assert_table("reg", reg, 2)
	assert_table("data", data, 2)

	local ctx = new_context_on(reg)

	if data.granted then
		for i = 1, #data.granted do
			local id = data.granted[i]
			grant(ctx, id)
		end
	end
	if data.denied then
		for i = 1, #data.denied do
			local id = data.denied[i]
			deny(ctx, id)
		end
	end
	if data.category_overrides then
		for cat_id, state in next, data.category_overrides do
			if is_state(state) then
				set_category_state(ctx, cat_id, state)
			end
		end
	end

	return ctx
end

----------------------------------------------------------------------
-- Serialization: compact wire format (bit-packed arrays)
----------------------------------------------------------------------

--- Convert a context to compact wire format.<br>
--- Returns bit-packed arrays for efficient network transmission.<br>
--- Use this for network serialization where size matters.
---@param ctx table The permission context.
---@return table data Serialized data with allow, deny, and categories fields.
---@usage <br>
--- ```
--- local wire = to_wire(ctx)
--- Network.SendToPlayer(wire, player)
--- ```
to_wire = function(ctx)
	assert_table("ctx", ctx, 2)

	local a2, d2 = {}, {}
	for i = 1, #ctx.allow_bits do a2[i] = ctx.allow_bits[i] end
	for i = 1, #ctx.deny_bits do d2[i] = ctx.deny_bits[i] end

	local cats = {}
	for k, v in next, ctx.category_overrides do cats[k] = v end

	return { allow = a2, deny = d2, categories = cats }
end

--- Convert wire format to a context on the default registry.<br>
--- Creates a context from compact bit-packed data.<br>
--- Reconstructs a context from network-serialized data.
---@param data table Serialized data with allow, deny, and categories fields.
---@return table ctx The reconstructed context.
---@usage <br>
--- ```
--- local ctx = from_wire(data)
--- ```
from_wire = function(data)
	return from_wire_on(_default, data)
end

--- Convert wire format to a context on a specific registry.<br>
--- Creates a context from compact bit-packed data.<br>
--- Use this for multi-registry scenarios.
---@param reg table The registry to create the context on.
---@param data table Serialized data with allow, deny, and categories fields.
---@return table ctx The reconstructed context.
---@usage <br>
--- ```
--- local ctx = from_wire_on(reg, data)
--- ```
from_wire_on = function(reg, data)
	assert_table("reg", reg, 2)
	assert_table("data", data, 2)

	local ctx = new_context_on(reg)

	local a = data.allow
	if type(a) == "table" then
		for i = 1, #a do ctx.allow_bits[i] = tonumber(a[i]) or 0 end
	end
	local d = data.deny
	if type(d) == "table" then
		for i = 1, #d do ctx.deny_bits[i] = tonumber(d[i]) or 0 end
	end

	local cats = data.categories
	if type(cats) == "table" then
		for k, v in next, cats do
			if reg.categories[k] and is_state(v) and v ~= STATE_UNSET then
				ctx.category_overrides[k] = v
			end
		end
	end

	return ctx
end

----------------------------------------------------------------------
-- Utilities
----------------------------------------------------------------------

--- Get the human-readable name of a state constant.<br>
--- Returns the string representation of a state value.<br>
--- Useful for logging, UI display, or debugging.
---@param state integer The state constant (STATE_UNSET, STATE_ALLOW, or STATE_DENY).
---@return string name The human-readable state name ("unset", "allow", or "deny").
---@usage <br>
--- ```
--- print(state_name(STATE_ALLOW)) -- "allow"
--- ```
state_name = function(state)
	if state == STATE_ALLOW then return "allow" end
	if state == STATE_DENY then return "deny" end
	return "unset"
end

--- Generate a human-readable description of a context.<br>
--- Returns a string showing granted permissions, denied permissions, and category overrides.<br>
--- Useful for debugging and logging permission states.
---@param ctx table The permission context.
---@return string description Human-readable description of the context state.
---@usage <br>
--- ```
--- print(describe_context(ctx))
--- -- Output: granted=[chat.send] denied=[chat.mute] categories=[admin=deny]
--- ```
describe_context = function(ctx)
	assert_table("ctx", ctx, 2)

	local granted, denied = {}, {}
	local reg = ctx.reg

	for id, perm in next, reg.permissions do
		if bit_get(ctx.allow_bits, perm.index) then
			table_insert(granted, id)
		elseif bit_get(ctx.deny_bits, perm.index) then
			table_insert(denied, id)
		end
	end
	table_sort(granted)
	table_sort(denied)

	local result = "granted=[" .. table_concat(granted, ",")
			.. "] denied=[" .. table_concat(denied, ",") .. "]"

	local cats = {}
	for k, v in next, ctx.category_overrides do
		table_insert(cats, k .. "=" .. state_name(v))
	end
	if #cats > 0 then
		table_sort(cats)
		result = result .. " categories=[" .. table_concat(cats, ",") .. "]"
	end

	return result
end

----------------------------------------------------------------------
-- Initialize default registry
----------------------------------------------------------------------

_default = new_registry()

-- Export
return {
	STATE_UNSET = STATE_UNSET,
	STATE_ALLOW = STATE_ALLOW,
	STATE_DENY = STATE_DENY,
	new_registry = new_registry,
	freeze_registry = freeze_registry,
	define_category = define_category,
	define_category_on = define_category_on,
	new_context = new_context,
	new_context_on = new_context_on,
	grant = grant,
	deny = deny,
	reset = reset,
	set_state = set_state,
	get_state = get_state,
	grant_category = grant_category,
	deny_category = deny_category,
	reset_category = reset_category,
	set_category_state = set_category_state,
	get_category_state = get_category_state,
	is_allowed = is_allowed,
	is_denied = is_denied,
	is_granted_explicit = is_granted_explicit,
	is_denied_explicit = is_denied_explicit,
	get_effective_state = get_effective_state,
	get_default = get_default,
	get_default_on = get_default_on,
	require_permission = require_permission,
	get_category = get_category,
	get_category_on = get_category_on,
	get_permission = get_permission,
	get_permission_on = get_permission_on,
	each_category = each_category,
	each_category_on = each_category_on,
	each_permission = each_permission,
	each_permission_on = each_permission_on,
	list_permissions = list_permissions,
	list_permissions_on = list_permissions_on,
	to_table = to_table,
	from_table = from_table,
	from_table_on = from_table_on,
	to_wire = to_wire,
	from_wire = from_wire,
	from_wire_on = from_wire_on,
	state_name = state_name,
	describe_context = describe_context,
}
