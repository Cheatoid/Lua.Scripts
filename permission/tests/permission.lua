-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for permission.lua.
-- Run from this directory:
--   lua permission.lua
--   luajit permission.lua

-- Bootstrap: make requires work from tests/ subdir with plain lua/luajit.
do
  local src = debug.getinfo(1, "S").source
  local dir = src:match("^@(.+/)[^/]+$") or "./"
  local function isfile(p)
    local f = io.open(p, "r")
    if f then f:close() return true end
    return false
  end
  local root
  for _, c in ipairs({ dir, dir .. "../", dir .. "../..//", dir .. "../../..//", "./", "../", "../../" }) do
    if isfile(c .. "standalone/bits.lua") then root = c break end
  end
  root = root or dir .. "../"
  if package then
    package.path = dir .. "../?.lua;" .. dir .. "../?/init.lua;" .. dir .. "?.lua;" .. dir .. "?/init.lua;" .. root .. "?.lua;" .. root .. "?/init.lua;" .. root .. "standalone/?.lua;" .. root .. "math/?.lua;" .. root .. "collections/?.lua;" .. root .. "benchmark/?.lua;" .. root .. "timer/?.lua;" .. root .. "autocompleter/?.lua;" .. root .. "permission/?.lua;" .. root .. "chat_commander/?.lua;" .. root .. "vm/?.lua;" .. root .. "require_finder/?.lua;" .. root .. "inventory/?.lua;" .. package.path
  end
  local searchers = package.searchers or package.loaders
  if searchers then
    table.insert(searchers, 2, function(mod)
      if mod:sub(1, 3) == "../" or mod:sub(1, 2) == "./" then
        local clean = mod:gsub("^%./", ""):gsub("^%.%.%/", ""):gsub("^%.%.%/", "")
        local tries = { dir .. "../" .. clean .. ".lua", dir .. "../" .. clean .. "/init.lua", root .. clean .. ".lua", root .. clean .. "/init.lua" }
        for _, f in ipairs(tries) do
          if isfile(f) then
            local chunk, err = loadfile(f)
            if chunk then return chunk, f end
          end
        end
      end
      return nil
    end)
  end
end
local lib = require "permission"
local string_find = string.find
local string_format = string.format
-- Bridging: file-locals used by tests mapped to module exports.
local STATE_ALLOW = lib.STATE_ALLOW
local STATE_DENY = lib.STATE_DENY
local STATE_UNSET = lib.STATE_UNSET
local define_category = lib.define_category
local define_category_on = lib.define_category_on
local deny = lib.deny
local describe_context = lib.describe_context
local each_category = lib.each_category
local each_category_on = lib.each_category_on
local each_permission = lib.each_permission
local freeze_registry = lib.freeze_registry
local from_table = lib.from_table
local from_table_on = lib.from_table_on
local from_wire = lib.from_wire
local from_wire_on = lib.from_wire_on
local get_category = lib.get_category
local get_category_on = lib.get_category_on
local get_category_state = lib.get_category_state
local get_default = lib.get_default
local get_default_on = lib.get_default_on
local get_effective_state = lib.get_effective_state
local get_permission = lib.get_permission
local get_state = lib.get_state
local grant = lib.grant
local grant_category = lib.grant_category
local is_allowed = lib.is_allowed
local is_denied = lib.is_denied
local is_denied_explicit = lib.is_denied_explicit
local is_granted_explicit = lib.is_granted_explicit
local list_permissions = lib.list_permissions
local list_permissions_on = lib.list_permissions_on
local new_context = lib.new_context
local new_context_on = lib.new_context_on
local new_registry = lib.new_registry
local require_permission = lib.require_permission
local reset = lib.reset
local reset_category = lib.reset_category
local set_category_state = lib.set_category_state
local state_name = lib.state_name
local to_table = lib.to_table
local to_wire = lib.to_wire
-- _default is file-local in source; capture default registry via a fresh context.
local _default = new_context().reg
-- TODO(manual): the following were file-locals with no direct export;
-- verify and export or inline as needed: a, category, denied, explicit, granted, name, state

if true then
	-- Test 1: State constants
	assert(STATE_UNSET == 0, "Test 1 failed: STATE_UNSET should be 0")
	assert(STATE_ALLOW == 1, "Test 1 failed: STATE_ALLOW should be 1")
	assert(STATE_DENY == 2, "Test 1 failed: STATE_DENY should be 2")

	-- Test 2: Registry creation
	local reg = new_registry()
	assert(reg.frozen == false, "Test 2 failed: new registry should not be frozen")
	assert(reg.default_state == STATE_DENY, "Test 2 failed: default state should be DENY")

	-- Test 3: Registry with custom default state
	local reg_allow = new_registry(STATE_ALLOW)
	assert(reg_allow.default_state == STATE_ALLOW, "Test 3 failed: custom default state should be ALLOW")

	-- Test 4: Freeze registry
	freeze_registry(reg)
	assert(reg.frozen == true, "Test 4 failed: registry should be frozen after freeze_registry")

	-- Test 5: Define category
	define_category("test", {
		{ name = "read",  default = true, description = "Read access" },
		{ name = "write", default = false },
		"delete"
	})
	local cat = get_category("test")
	assert(cat ~= nil, "Test 5 failed: category should be defined")
	local read_perm = get_permission("test.read")
	assert(read_perm.description == "Read access", "Test 5 failed: permission description should match")

	-- Test 6: Permission IDs
	assert(get_permission("test.read") ~= nil, "Test 6 failed: test.read should exist")
	assert(get_permission("test.write") ~= nil, "Test 6 failed: test.write should exist")
	assert(get_permission("test.delete") ~= nil, "Test 6 failed: test.delete should exist")

	-- Test 7: Context creation
	local ctx = new_context()
	assert(ctx.reg == _default, "Test 7 failed: context should use default registry")

	-- Test 8: Grant permission
	grant(ctx, "test.read")
	assert(is_granted_explicit(ctx, "test.read"), "Test 8 failed: test.read should be explicitly granted")
	assert(is_allowed(ctx, "test.read"), "Test 8 failed: test.read should be allowed")

	-- Test 9: Deny permission
	deny(ctx, "test.write")
	assert(is_denied_explicit(ctx, "test.write"), "Test 9 failed: test.write should be explicitly denied")
	assert(is_denied(ctx, "test.write"), "Test 9 failed: test.write should be denied")

	-- Test 10: Reset permission
	reset(ctx, "test.read")
	assert(get_state(ctx, "test.read") == STATE_UNSET, "Test 10 failed: test.read should be unset after reset")

	-- Test 11: Default allowed state
	assert(is_allowed(ctx, "test.read"), "Test 11 failed: test.read should be allowed by default")

	-- Test 12: Category operations
	grant_category(ctx, "test")
	assert(is_allowed(ctx, "test.delete"), "Test 12 failed: test.delete should be granted via grant_category")

	-- Test 13: Category override
	reset_category(ctx, "test")
	set_category_state(ctx, "test", STATE_DENY)
	assert(is_denied(ctx, "test.read"), "Test 13 failed: test.read should be denied via category override")
	assert(get_category_state(ctx, "test") == STATE_DENY, "Test 13 failed: category state should be DENY")

	-- Test 14: Get effective state
	local eff, exp = get_effective_state(ctx, "test.read")
	assert(eff == STATE_DENY, "Test 14 failed: effective state should be DENY")
	assert(exp == STATE_UNSET, "Test 14 failed: explicit state should be UNSET")

	-- Test 15: List permissions
	local perms = list_permissions()
	assert(#perms >= 3, "Test 15 failed: should list at least 3 permissions")

	-- Test 16: Each permission
	local count = 0
	each_permission("test", function(perm)
		count = count + 1
	end)
	assert(count == 3, "Test 16 failed: should iterate over 3 permissions")

	-- Test 17: Serialization to table
	local data = to_table(ctx)
	assert(type(data.granted) == "table", "Test 17 failed: to_table should return granted array")
	assert(type(data.denied) == "table", "Test 17 failed: to_table should return denied array")

	-- Test 18: Serialization from table
	local ctx2 = from_table(data)
	assert(is_denied(ctx2, "test.delete"), "Test 18 failed: restored context should have test.delete denied")

	-- Test 19: Wire serialization
	local wire = to_wire(ctx)
	assert(type(wire.allow) == "table", "Test 19 failed: to_wire should return allow array")
	assert(type(wire.deny) == "table", "Test 19 failed: to_wire should return deny array")

	-- Test 20: Wire deserialization
	local ctx3 = from_wire(wire)
	assert(is_denied(ctx3, "test.delete"), "Test 20 failed: restored context should have test.delete denied")

	-- Test 21: State name
	assert(state_name(STATE_ALLOW) == "allow", "Test 21 failed: state_name(ALLOW) should be 'allow'")
	assert(state_name(STATE_DENY) == "deny", "Test 21 failed: state_name(DENY) should be 'deny'")
	assert(state_name(STATE_UNSET) == "unset", "Test 21 failed: state_name(UNSET) should be 'unset'")

	-- Test 22: Describe context
	local desc = describe_context(ctx)
	assert(type(desc) == "string", "Test 22 failed: describe_context should return a string")
	assert(string_find(desc, "granted=") ~= nil, "Test 22 failed: description should contain 'granted='")

	-- Test 23: Require function
	local ctx4 = new_context()
	deny(ctx4, "test.read")
	local ok, err = pcall(require_permission, ctx4, "test.read")
	assert(ok == false, "Test 23 failed: require_permission should error when permission denied")

	-- Test 24: Multi-registry scenario
	local reg2 = new_registry(STATE_ALLOW)
	define_category_on(reg2, "admin", {
		{ name = "kick", default = true },
		{ name = "ban",  default = false }
	})
	local ctx_reg2 = new_context_on(reg2)
	assert(is_allowed(ctx_reg2, "admin.kick"), "Test 24 failed: should be allowed by default in reg2")
	assert(is_denied(ctx_reg2, "admin.ban"), "Test 24 failed: should be denied by explicit default")
	deny(ctx_reg2, "admin.kick")
	assert(is_denied(ctx_reg2, "admin.kick"), "Test 24 failed: should be denied after explicit deny")

	-- Test 25: Each category iteration
	local cat_count = 0
	each_category(function(cat)
		cat_count = cat_count + 1
	end)
	assert(cat_count >= 1, "Test 25 failed: should iterate over at least 1 category")

	-- Test 26: Each category on specific registry
	local reg3 = new_registry()
	define_category_on(reg3, "mod", { "mute", "warn" })
	local reg3_cat_count = 0
	each_category_on(reg3, function(cat)
		reg3_cat_count = reg3_cat_count + 1
	end)
	assert(reg3_cat_count == 1, "Test 26 failed: should iterate over 1 category in reg3")

	-- Test 27: Get default on default registry
	assert(get_default("test.read") == true, "Test 27 failed: test.read should default to allowed")
	assert(get_default("test.write") == false, "Test 27 failed: test.write should default to denied")

	-- Test 28: Get default on specific registry
	assert(get_default_on(_default, "test.read") == true, "Test 28 failed: test.read should default to allowed")
	assert(get_default_on(reg2, "admin.kick") == true, "Test 28 failed: admin.kick should default to allowed in reg2")
	assert(get_default_on(reg2, "admin.ban") == false, "Test 28 failed: admin.ban should default to denied in reg2")

	-- Test 29: Get category
	local cat2 = get_category("test")
	assert(cat2 ~= nil, "Test 29 failed: should get category from default registry")
	local cat3 = get_category_on(reg2, "admin")
	assert(cat3 ~= nil, "Test 29 failed: should get category from specific registry")

	-- Test 30: List permissions on specific registry
	local reg2_perms = list_permissions_on(reg2)
	assert(#reg2_perms == 2, "Test 30 failed: should list 2 permissions in reg2")

	-- Test 31: from_table_on with specific registry
	local ctx5 = new_context_on(reg2)
	grant(ctx5, "admin.kick")
	local data2 = to_table(ctx5)
	local ctx6 = from_table_on(reg2, data2)
	assert(is_allowed(ctx6, "admin.kick"), "Test 31 failed: restored context on reg2 should have admin.kick allowed")

	-- Test 32: from_wire_on with specific registry
	local wire2 = to_wire(ctx5)
	local ctx7 = from_wire_on(reg2, wire2)
	assert(is_allowed(ctx7, "admin.kick"),
		"Test 32 failed: restored context from wire on reg2 should have admin.kick allowed")

	-- Test 33: Explicit deny overrides category allow
	local ctx8 = new_context()
	set_category_state(ctx8, "test", STATE_ALLOW)
	deny(ctx8, "test.read")
	assert(is_denied(ctx8, "test.read"), "Test 33 failed: explicit deny should override category allow")

	-- Test 34: Explicit grant overrides category deny
	local ctx9 = new_context()
	set_category_state(ctx9, "test", STATE_DENY)
	grant(ctx9, "test.write")
	assert(is_allowed(ctx9, "test.write"), "Test 34 failed: explicit grant should override category deny")

	-- Test 35: Context with initial granted/denied arrays
	local ctx10 = new_context({
		granted = { "test.read" },
		denied = { "test.write" }
	})
	assert(is_allowed(ctx10, "test.read"), "Test 35 failed: test.read should be granted from initial")
	assert(is_denied(ctx10, "test.write"), "Test 35 failed: test.write should be denied from initial")

	-- Test 36: Context with initial states map
	local ctx11 = new_context({
		states = {
			["test.read"] = STATE_ALLOW,
			["test.write"] = STATE_DENY
		}
	})
	assert(is_allowed(ctx11, "test.read"), "Test 36 failed: test.read should be allowed from initial states")
	assert(is_denied(ctx11, "test.write"), "Test 36 failed: test.write should be denied from initial states")

	-- Test 37: Context with initial category overrides
	local ctx12 = new_context({
		category_overrides = {
			["test"] = STATE_ALLOW
		}
	})
	assert(is_allowed(ctx12, "test.write"), "Test 37 failed: test.write should be allowed from category override")

	-- Test 38: Set state multiple times
	local ctx13 = new_context()
	grant(ctx13, "test.read")
	deny(ctx13, "test.read")
	grant(ctx13, "test.read")
	assert(is_allowed(ctx13, "test.read"), "Test 38 failed: final grant should take effect")

	-- Test 39: Reset category override
	local ctx14 = new_context()
	set_category_state(ctx14, "test", STATE_DENY)
	set_category_state(ctx14, "test", STATE_UNSET)
	assert(get_category_state(ctx14, "test") == STATE_UNSET, "Test 39 failed: category override should be reset")

	-- Test 40: describe_context with category overrides
	local ctx15 = new_context()
	set_category_state(ctx15, "test", STATE_ALLOW)
	local desc2 = describe_context(ctx15)
	assert(string_find(desc2, "categories=") ~= nil, "Test 40 failed: description should show category overrides")

	print("All tests passed!")
end
