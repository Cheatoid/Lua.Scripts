-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

--[[
Inventory system

PURPOSE
	A complete, single-file reference implementation of a game inventory:
	slot + weight capacity, stacking/splitting/merging, transactions with
	rollback, coalesced events, pluggable persistence (in-memory / string
	save-load / network-sync stub), a text UI adapter, item behaviors
	(consumable / equippable), and a full deterministic test suite.

INTEGRATION (inside a game)
	local invsys = require "inventory"
	local dispatcher = invsys.EventDispatcher.new()
	local inv = invsys.InventoryCore.new({
		capacity   = 20,
		maxWeight  = 100,
		dispatcher = dispatcher,
	})
	local ui = invsys.UIAdapterExample.new(inv):attach() -- or write your own UIAdapter
	local potion = invsys.ItemFactory.create({
		id = "potion", type = "consumable", stackable = true,
		maxStack = 8, weight = 1, attrs = { heal = 25 },
	})
	inv:add(potion, 5)

EXTENSION POINTS (open/closed)
	* ItemFactory.registerBehavior(itemType, { onUse = function(inv, slot, ctx) ... end })
	* New StorageAdapter: ANY table with save(self, state) / load(self) works with
		StorageAdapters.persist / StorageAdapters.restore (Liskov-substitutable).
	* Custom stacking rules: pass config.stackManager to InventoryCore.new.
	* UI/engine hooks: subscribe to events "slotChanged" and "txRolledBack".

FLAGS
	DEBUG (below):
		true  = runtime contract checks + verbose assertions.
		false = release mode, checks compiled out of hot paths.

DESIGN
	* SOLID + DRY rationale is annotated inline in every module section.
	* Core modules are PURE: no print / no I/O. Only adapters, Tests and
		ExampleUsage perform I/O.
	* Lua 5.1+ compatible: no external libraries, no engine APIs, no __index
		metamethods, no globals (the file returns an API table).
]]

local DEBUG = true -- flip to false for release: disables contract checks

----------------------------------------------------------------------
-- SECTION 1: Structure - map of internal modules (documentation artifact)
----------------------------------------------------------------------

local Structure = {
	{ name = "Utils",              purpose = "pools, copies, ids, seeded rng, serialization (shared foundation, DRY)" },
	{ name = "Contracts",          purpose = "runtime-validated table contracts: Item/Inventory/StorageAdapter/UIAdapter/EventDispatcher" },
	{ name = "EventDispatcher",    purpose = "pub/sub with batching + coalescing (SRP: message routing only)" },
	{ name = "ItemFactory",        purpose = "item creation/clone/serialize + behavior registry (OCP extension point)" },
	{ name = "StackManager",       purpose = "pure stacking rules: canStack / find / transfer (SRP, reused by core)" },
	{ name = "InventoryCore",      purpose = "inventory state + add/remove/move/split/merge (slot & weight capacity)" },
	{ name = "TransactionManager", purpose = "begin/commit/rollback + atomic multi-step helpers" },
	{ name = "StorageAdapters",    purpose = "InMemory / SaveLoad(string) / NetworkSync(diff) - LSP-substitutable" },
	{ name = "UIAdapterExample",   purpose = "text UI fed by events; the only module that prints inventory views" },
	{ name = "Tests",              purpose = "unit + integration + deterministic (seeded) fuzz tests" },
	{ name = "ExampleUsage",       purpose = "guided runnable scenario incl. simulated client/server sync" },
}

----------------------------------------------------------------------
-- SECTION 2: Utils - pooling, copies, ids, rng, serialization
----------------------------------------------------------------------
-- SOLID:
--  S: one module, one job - generic low-level helpers used everywhere.
--  O: new pool kinds can be added via newPool() without editing existing code.
--  L/I: n/a (helpers, not interfaces).
--  D: higher modules depend on these stable abstractions, not ad-hoc logic.
-- DRY: every other module reuses these helpers instead of re-implementing them.
-- GC: pools cap retained tables (max). Beyond the cap, tables are dropped for
--     the GC. Tune max to peak concurrent usage: tempLists ~= max nested hot
--     operations per frame; slotPool ~= total slots across live inventories.
----------------------------------------------------------------------

local Utils = {}

Utils.EMPTY = {} -- shared empty table; treat as read-only

function Utils.shallowCopy(t)
	local out = {}
	for k, v in next, t do out[k] = v end
	return out
end

-- Deep copy for plain data tables (no cycles, no metatables in our data model).
function Utils.deepCopy(t)
	if type(t) ~= "table" then return t end
	local out = {}
	for k, v in next, t do
		out[k] = (type(v) == "table") and Utils.deepCopy(v) or v
	end
	return out
end

local idCounter = 0
function Utils.newId(prefix)
	idCounter = idCounter + 1
	return (prefix or "id") .. "_" .. idCounter
end

function Utils.assertArg(cond, msg)
	if not cond then return error(msg, 2) end
end

----------------------------------------------------------------------
-- Object pool: reuses frequently created tables (slots, scratch lists).
-- Minimizes allocations on hot paths; bounded memory via `max`.
----------------------------------------------------------------------
local PoolMethods = {}

function PoolMethods.acquire(self)
	if self.size > 0 then
		local t = self.free[self.size]
		self.free[self.size] = nil
		self.size = self.size - 1
		return t
	end
	self.made = self.made + 1
	return self.factory()
end

function PoolMethods.release(self, t)
	if t == nil then return end
	if self.reset then self.reset(t) end
	if self.size < self.max then
		self.size = self.size + 1
		self.free[self.size] = t
	end
	-- else: drop reference, let GC reclaim it (bounds pool memory footprint)
end

function Utils.newPool(opts)
	Utils.assertArg(type(opts) == "table" and type(opts.factory) == "function",
		"newPool requires { factory = function, reset = function?, max = number? }")
	local pool = {
		factory = opts.factory,
		reset   = opts.reset,
		max     = opts.max or 32,
		free    = {},
		size    = 0,
		made    = 0, -- total tables ever created (pool diagnostics)
	}
	pool.acquire = PoolMethods.acquire
	pool.release = PoolMethods.release
	return pool
end

-- Scratch lists used by hot paths (e.g. InventoryCore.add candidate scan).
-- Shape: { n = <logical length>, [1..n] = entries }.
Utils.tempLists = Utils.newPool({
	factory = function() return { n = 0 } end,
	reset   = function(t)
		for i = 1, #t do t[i] = nil end
		t.n = 0
	end,
	max     = 16, -- threshold: max nested scratch-list users per frame
})

-- Slot tables are pooled so inventories can be created/destroyed cheaply.
Utils.slotPool = Utils.newPool({
	factory = function() return {} end,
	reset   = function(t)
		t.item = nil; t.count = nil; t.rev = nil; t.index = nil
	end,
	max     = 256, -- threshold: total slots across all live inventories
})

----------------------------------------------------------------------
-- Deterministic PRNG (Park-Miller minstd). Products stay < 2^53, so results
-- are exact and identical on every platform - required for reproducible fuzz.
----------------------------------------------------------------------
function Utils.newRng(seed)
	local s = (seed or 8866) % 2147483647
	if s <= 0 then s = s + 2147483646 end
	return function()
		s = (s * 16807) % 2147483647
		return s / 2147483647
	end
end

----------------------------------------------------------------------
-- Lightweight serializer for plain data tables (strings/numbers/bools/tables).
-- Output is a Lua literal; deserialize via loadstring/load. We only ever
-- deserialize strings produced here (trusted data). On 5.1 we sandbox the
-- chunk with setfenv; on 5.2+ the generated literal contains no identifiers.
----------------------------------------------------------------------
local function serializeValue(v, depth, out)
	local tv = type(v)
	if tv == "number" then
		Utils.assertArg(v == v, "NaN is not serializable")
		Utils.assertArg(v ~= math.huge and v ~= -math.huge,
			"infinite numbers are not serializable (use finite maxWeight for persistence)")
		out[#out + 1] = string.format("%.17g", v)
	elseif tv == "string" then
		out[#out + 1] = string.format("%q", v)
	elseif tv == "boolean" then
		out[#out + 1] = v and "true" or "false"
	elseif tv == "table" then
		Utils.assertArg(depth < 24, "serialization nesting too deep")
		out[#out + 1] = "{"
		local first = true
		local n = #v
		for i = 1, n do
			if not first then out[#out + 1] = "," end
			first = false
			serializeValue(v[i], depth + 1, out)
		end
		for k, val in pairs(v) do
			local kt = type(k)
			local isArrayKey = (kt == "number" and k >= 1 and k <= n and k % 1 == 0)
			if not isArrayKey then
				Utils.assertArg(kt == "string" or kt == "number",
					"unsupported key type: " .. kt)
				if not first then out[#out + 1] = "," end
				first = false
				if kt == "string" then
					out[#out + 1] = "[" .. string.format("%q", k) .. "]="
				else
					out[#out + 1] = "[" .. string.format("%.17g", k) .. "]="
				end
				serializeValue(val, depth + 1, out)
			end
		end
		out[#out + 1] = "}"
	else
		return error("unsupported type for serialization: " .. tv, 2)
	end
end

function Utils.serialize(value)
	local out = {}
	serializeValue(value, 0, out)
	return table.concat(out)
end

function Utils.deserialize(str)
	if type(str) ~= "string" then return nil, "expected string" end
	local loadFn = loadstring or load
	local fn, err = loadFn("return " .. str)
	if not fn then return nil, err end
	if setfenv then setfenv(fn, {}) end -- Lua 5.1: empty environment sandbox
	local ok, result = pcall(fn)
	if not ok then return nil, result end
	if type(result) ~= "table" then return nil, "deserialized value is not a table" end
	return result
end

----------------------------------------------------------------------
-- SECTION 3: Contracts - explicit table shapes, validated at runtime (DEBUG)
----------------------------------------------------------------------
-- SOLID:
--  I: each contract is small and role-specific (Interface Segregation) -
--     consumers depend only on the narrow shape they need.
--  D: modules depend on these abstractions (duck-typed table contracts),
--     never on concrete classes; any conforming table is substitutable.
--  L: contract checkers define the substitutability rule used by adapters.
--
-- Contract shapes (required keys / signatures):
--   Item = {
--     id: string, type: string, stackable: boolean, maxStack: number >= 1,
--     weight: number >= 0, attrs: table, uid: string, count: number >= 1,
--   }
--   Slot = { index: number, item: Item|nil, count: number, rev: number }
--   Inventory = {
--     capacity: number, maxWeight: number, currentWeight: number, slots: Slot[],
--     add(self, item: Item, qty?: number)      -> added: number,
--     remove(self, itemId: string, qty?: number) -> removed: number,
--     move(self, slotFrom, slotTo)             -> ok: boolean,
--     split(self, slotIndex, qty)              -> ok: boolean,
--     merge(self, slotA, slotB)                -> ok: boolean,
--     getSlot(self, index)                     -> Slot|nil,
--     listItems(self, out?: table)             -> table (out reused if given),
--   }
--   StorageAdapter = {
--     name: string,
--     save(self, state: table) -> ok: boolean, err?: string,
--     load(self)               -> state: table|nil, err?: string,
--   }
--   UIAdapter = {
--     render(self),  attach(self)?,  detach(self)?,
--   }
--   EventDispatcher = {
--     on(self, event: string, fn: function)            -> handle,
--     off(self, handle)                                -> boolean,
--     emit(self, event: string, payload: table),
--     emitCoalesced(self, event: string, key, payload),
--     beginBatch(self), endBatch(self),
--   }
----------------------------------------------------------------------

local Contracts = {}

function Contracts.checkItem(t)
	if type(t) ~= "table" then return false, "item must be a table" end
	if type(t.id) ~= "string" then return false, "item.id must be string" end
	if type(t.type) ~= "string" then return false, "item.type must be string" end
	if type(t.stackable) ~= "boolean" then return false, "item.stackable must be boolean" end
	if type(t.maxStack) ~= "number" or t.maxStack < 1 then return false, "item.maxStack must be number >= 1" end
	if type(t.weight) ~= "number" or t.weight < 0 then return false, "item.weight must be number >= 0" end
	if type(t.attrs) ~= "table" then return false, "item.attrs must be table" end
	return true
end

function Contracts.checkInventory(t)
	if type(t) ~= "table" then return false, "inventory must be a table" end
	if type(t.capacity) ~= "number" then return false, "capacity must be number" end
	if type(t.maxWeight) ~= "number" then return false, "maxWeight must be number" end
	if type(t.currentWeight) ~= "number" then return false, "currentWeight must be number" end
	if type(t.slots) ~= "table" then return false, "slots must be table" end
	local methods = { "add", "remove", "move", "split", "merge", "getSlot", "listItems" }
	for i = 1, #methods do
		if type(t[methods[i]]) ~= "function" then
			return false, "missing method: " .. methods[i]
		end
	end
	return true
end

function Contracts.checkStorageAdapter(t)
	if type(t) ~= "table" then return false, "adapter must be a table" end
	if type(t.name) ~= "string" then return false, "adapter.name must be string" end
	if type(t.save) ~= "function" then return false, "adapter.save must be function" end
	if type(t.load) ~= "function" then return false, "adapter.load must be function" end
	return true
end

function Contracts.checkUIAdapter(t)
	if type(t) ~= "table" then return false, "ui adapter must be a table" end
	if type(t.render) ~= "function" then return false, "ui.render must be function" end
	return true
end

function Contracts.checkEventDispatcher(t)
	if type(t) ~= "table" then return false, "dispatcher must be a table" end
	local methods = { "on", "off", "emit", "emitCoalesced", "beginBatch", "endBatch" }
	for i = 1, #methods do
		if type(t[methods[i]]) ~= "function" then
			return false, "missing method: " .. methods[i]
		end
	end
	return true
end

-- require* variants: assert in DEBUG mode, zero-cost no-op otherwise.
local function makeRequire(checkFn, label)
	return function(t)
		if not DEBUG then return end
		local ok, err = checkFn(t)
		if not ok then
			return error(label .. " contract violation: " .. (err or "?"), 2)
		end
	end
end

Contracts.requireItem            = makeRequire(Contracts.checkItem, "Item")
Contracts.requireInventory       = makeRequire(Contracts.checkInventory, "Inventory")
Contracts.requireStorageAdapter  = makeRequire(Contracts.checkStorageAdapter, "StorageAdapter")
Contracts.requireUIAdapter       = makeRequire(Contracts.checkUIAdapter, "UIAdapter")
Contracts.requireEventDispatcher = makeRequire(Contracts.checkEventDispatcher, "EventDispatcher")

----------------------------------------------------------------------
-- SECTION 4: EventDispatcher - pub/sub with batching and coalescing
----------------------------------------------------------------------
-- SOLID:
--  S: only routes messages; knows nothing about items, slots, or I/O.
--  O: new event names can be introduced by emitters without changing this module.
--  L/I: implements the narrow EventDispatcher contract; consumers depend on it.
--  D: InventoryCore receives a dispatcher by injection (optional dependency).
-- DRY: single deliver/flush implementation shared by emit and emitCoalesced.
-- PERF: off() marks handles inactive (lazy compaction on next subscribe) so
--       delivery never allocates and is safe even if a handler unsubscribes
--       during emission. Batching reuses its queue tables across flushes.
----------------------------------------------------------------------

local EventDispatcher            = {}

local function deliver(self, event, payload)
	local list = self.handlers[event]
	if not list then return end
	local n = #list
	for i = 1, n do
		local h = list[i]
		if h and h.active then h.fn(payload, event) end
	end
end

local function compact(list)
	local w = 1
	for i = 1, #list do
		local h = list[i]
		if h.active then
			list[w] = h
			w = w + 1
		end
	end
	for i = w, #list do list[i] = nil end
end

function EventDispatcher.on(self, event, fn)
	Utils.assertArg(type(event) == "string" and type(fn) == "function",
		"on(event: string, fn: function)")
	local list = self.handlers[event]
	if not list then
		list = {}
		self.handlers[event] = list
	else
		compact(list) -- lazy GC of off()'d handles (DRY: one sweep point)
	end
	local handle = { event = event, fn = fn, active = true }
	list[#list + 1] = handle
	return handle
end

function EventDispatcher.off(self, handle)
	if type(handle) ~= "table" or not handle.active then return false end
	handle.active = false -- lazy removal: safe mid-emit, zero shifting
	return true
end

function EventDispatcher.emit(self, event, payload)
	if self.depth > 0 then
		self.queue[#self.queue + 1] = { event = event, payload = payload }
	else
		deliver(self, event, payload)
	end
end

-- Coalesced emit: within a batch, repeated (event,key) pairs collapse into a
-- single delivery carrying the LATEST payload. Ideal for "slotChanged".
function EventDispatcher.emitCoalesced(self, event, key, payload)
	if self.depth > 0 then
		local k = event .. "\0" .. tostring(key)
		if not self.coalMap[k] then
			self.coalKeys[#self.coalKeys + 1] = k -- preserve first-seen order
		end
		self.coalMap[k] = { event = event, payload = payload }
	else
		deliver(self, event, payload)
	end
end

function EventDispatcher.beginBatch(self)
	self.depth = self.depth + 1 -- nesting-safe depth counter
end

function EventDispatcher.endBatch(self)
	Utils.assertArg(self.depth > 0, "endBatch without beginBatch")
	self.depth = self.depth - 1
	if self.depth == 0 then
		-- Flush: plain queued events first (arrival order), then coalesced events
		-- (first-seen key order). Tables are cleared in place and reused.
		local q = self.queue
		for i = 1, #q do
			local e = q[i]; q[i] = nil
			deliver(self, e.event, e.payload)
		end
		local keys = self.coalKeys
		for i = 1, #keys do
			local k = keys[i]; keys[i] = nil
			local e = self.coalMap[k]; self.coalMap[k] = nil
			deliver(self, e.event, e.payload)
		end
	end
end

function EventDispatcher.new()
	local self         = {
		handlers = {}, -- event -> list of handles
		depth    = 0, -- batch nesting depth
		queue    = {}, -- batched plain emits
		coalKeys = {}, -- batched coalesced keys, in order
		coalMap  = {}, -- key -> { event, payload } (latest payload wins)
	}
	self.on            = EventDispatcher.on
	self.off           = EventDispatcher.off
	self.emit          = EventDispatcher.emit
	self.emitCoalesced = EventDispatcher.emitCoalesced
	self.beginBatch    = EventDispatcher.beginBatch
	self.endBatch      = EventDispatcher.endBatch
	if DEBUG then Contracts.requireEventDispatcher(self) end
	return self
end

----------------------------------------------------------------------
-- SECTION 5: ItemFactory - creation, cloning, serialization, behaviors
----------------------------------------------------------------------
-- SOLID:
--  S: the only place that knows how to build/clone/serialize Item tables.
--  O: new item BEHAVIORS are registered at runtime (registerBehavior) and
--     dispatched by type - core code is never modified (Open/Closed).
--  L/I: produced tables satisfy Contracts.Item; behaviors satisfy a tiny
--     { onUse = fn } contract (Interface Segregation).
--  D: behaviors are injected tables; the factory depends on the abstraction.
-- DRY: toTable/fromTable are the single source of truth for item shape.
----------------------------------------------------------------------

local ItemFactory = {}

ItemFactory.behaviors = {} -- itemType -> behavior table

-- Extension point: behavior = { onUse = function(inv, slot, ctx) -> ok, ... ,
--                               validate = function(inv, slot, ctx)? -> bool }
function ItemFactory.registerBehavior(itemType, behavior)
	Utils.assertArg(type(itemType) == "string" and #itemType > 0, "itemType required")
	Utils.assertArg(type(behavior) == "table" and type(behavior.onUse) == "function",
		"behavior must be { onUse = function(inv, slot, ctx) }")
	Utils.assertArg(ItemFactory.behaviors[itemType] == nil,
		"behavior already registered for type: " .. itemType)
	ItemFactory.behaviors[itemType] = behavior
end

function ItemFactory.create(def, count)
	Utils.assertArg(type(def) == "table", "create(def: table, count?: number)")
	Utils.assertArg(type(def.id) == "string" and #def.id > 0, "def.id required")
	Utils.assertArg(type(def.type) == "string" and #def.type > 0, "def.type required")
	local stackable = def.stackable and true or false
	local maxStack = def.maxStack or 1
	Utils.assertArg(type(maxStack) == "number" and maxStack >= 1 and maxStack % 1 == 0,
		"def.maxStack must be an integer >= 1")
	Utils.assertArg((not stackable) or maxStack >= 2,
		"stackable items require maxStack >= 2")
	local weight = def.weight or 0
	Utils.assertArg(type(weight) == "number" and weight >= 0, "def.weight must be >= 0")
	count = count or 1
	Utils.assertArg(type(count) == "number" and count >= 1 and count % 1 == 0,
		"count must be a positive integer")
	local item = {
		id        = def.id,
		type      = def.type,
		stackable = stackable,
		maxStack  = maxStack,
		weight    = weight,
		attrs     = Utils.deepCopy(def.attrs or Utils.EMPTY),
		uid       = Utils.newId("it"),
		count     = count,
	}
	if DEBUG then Contracts.requireItem(item) end
	return item
end

-- Clone = new stack instance (new uid) unless keepUid is set (snapshots).
function ItemFactory.clone(item, keepUid)
	if DEBUG then Contracts.requireItem(item) end
	return {
		id        = item.id,
		type      = item.type,
		stackable = item.stackable,
		maxStack  = item.maxStack,
		weight    = item.weight,
		attrs     = Utils.deepCopy(item.attrs),
		uid       = keepUid and item.uid or Utils.newId("it"),
		count     = item.count,
	}
end

function ItemFactory.toTable(item)
	if DEBUG then Contracts.requireItem(item) end
	return {
		id = item.id,
		type = item.type,
		stackable = item.stackable,
		maxStack = item.maxStack,
		weight = item.weight,
		attrs = Utils.deepCopy(item.attrs),
		uid = item.uid,
		count = item.count,
	}
end

function ItemFactory.fromTable(t)
	Utils.assertArg(type(t) == "table", "fromTable(t: table)")
	local item = {
		id        = t.id,
		type      = t.type,
		stackable = t.stackable and true or false,
		maxStack  = t.maxStack or 1,
		weight    = t.weight or 0,
		attrs     = Utils.deepCopy(t.attrs or Utils.EMPTY),
		uid       = t.uid or Utils.newId("it"),
		count     = t.count or 1,
	}
	if DEBUG then Contracts.requireItem(item) end
	return item
end

function ItemFactory.serialize(item)
	return Utils.serialize(ItemFactory.toTable(item))
end

function ItemFactory.deserialize(str)
	local t, err = Utils.deserialize(str)
	if not t then return nil, err end
	return ItemFactory.fromTable(t)
end

-- Behavior dispatch: core never switches on item type itself (OCP).
function ItemFactory.useItem(inv, slotIndex, context)
	local slot = inv:getSlot(slotIndex)
	if not slot or not slot.item then return false, "empty slot" end
	local behavior = ItemFactory.behaviors[slot.item.type]
	if not behavior then return false, "no behavior for type: " .. slot.item.type end
	context = context or {}
	if behavior.validate and not behavior.validate(inv, slot, context) then
		return false, "behavior validation failed"
	end
	return behavior.onUse(inv, slot, context)
end

----------------------------------------------------------------------
-- SECTION 6: StackManager - pure stacking rules (no state of its own)
----------------------------------------------------------------------
-- SOLID:
--  S: encapsulates ONLY stack rules; InventoryCore delegates to it (DRY).
--  O: alternative rules can be injected via InventoryCore.new({stackManager=...}).
--  L: any table exposing canStack/findPartialSlots/findEmptySlot/transfer is
--     substitutable for the default manager.
--  I: tiny function surface; callers take only what they need.
--  D: depends on inventory fields, not on InventoryCore's implementation.
-- PERF: findPartialSlots fills a caller-provided POOLED list (zero alloc in
--       hot paths); transfer is O(1).
----------------------------------------------------------------------

local StackManager = {}

function StackManager.canStack(itemA, itemB)
	return itemA ~= nil and itemB ~= nil
		and itemA.stackable and itemB.stackable
		and itemA.id == itemB.id
		and itemA.maxStack > 1 and itemB.maxStack > 1
end

-- Fills `out` (pooled list shape { n = ... }) with slots that can absorb `item`.
function StackManager.findPartialSlots(inv, item, out)
	out.n = 0
	if not item.stackable then return out end
	for i = 1, inv.capacity do
		local s = inv.slots[i]
		if s.item and StackManager.canStack(s.item, item) and s.count < s.item.maxStack then
			out.n = out.n + 1
			out[out.n] = s
		end
	end
	return out
end

function StackManager.findEmptySlot(inv)
	for i = 1, inv.capacity do
		if not inv.slots[i].item then return i end
	end
	return nil
	-- NOTE: O(S) scan. A free-index stack would make this O(1) at the cost of
	-- bookkeeping on every fill/empty; for typical capacities (<= 100) the scan
	-- is cache-friendly and simpler. Swap in a custom manager if needed (OCP).
end

-- Move as many units as possible from slot `fromIndex` into `toIndex`.
-- O(1), zero allocations. Returns units moved. Weight is unchanged (internal).
function StackManager.transfer(inv, fromIndex, toIndex)
	local a = inv.slots[fromIndex]
	local b = inv.slots[toIndex]
	if not a or not b or not a.item or not b.item then return 0 end
	if not StackManager.canStack(a.item, b.item) then return 0 end
	local space = b.item.maxStack - b.count
	if space <= 0 then return 0 end
	local moved = a.count < space and a.count or space
	a.count = a.count - moved
	b.count = b.count + moved
	a.rev = a.rev + 1
	b.rev = b.rev + 1
	if a.count == 0 then a.item = nil end
	return moved
end

----------------------------------------------------------------------
-- SECTION 7: InventoryCore - state + operations (slot & weight capacity)
----------------------------------------------------------------------
-- SOLID:
--  S: owns inventory state and the six core operations - nothing else.
--  O: stacking rules and dispatchers are injected; new event consumers can be
--     added without touching this module.
--  L: instances satisfy Contracts.Inventory and are substitutable anywhere
--     that contract is expected (transactions, adapters, UI).
--  I: getSlot/listItems expose read views; mutations go through methods.
--  D: depends on abstractions (StackManager, EventDispatcher) via injection.
-- DRY: all stack math delegated to StackManager; notifySlot is the single
--      event-emission point; batchBegin/batchEnd wrap every mutation.
--
-- PERFORMANCE & GC NOTES
--   add(item, qty)     : average O(S) scan (S = capacity) + O(K) partial fills;
--                        exactly ONE ItemFactory.clone per newly created stack;
--                        candidate list comes from Utils.tempLists pool.
--   remove(itemId,qty) : O(S) single scan; zero allocations.
--   move(a, b)         : O(1) direct swap / stack transfer; zero allocations.
--   split(i, qty)      : O(S) empty-slot scan; one clone for the new stack.
--   merge(a, b)        : O(1); zero allocations.
--   Slots themselves come from Utils.slotPool (see recycle()).
----------------------------------------------------------------------

local InventoryCore = {}

local EPS = 1e-9 -- tolerance for float weight comparisons

local function batchBegin(inv)
	local d = inv.dispatcher
	if d then d:beginBatch() end
end

local function batchEnd(inv)
	local d = inv.dispatcher
	if d then d:endBatch() end
end

-- Single emission point for slot changes (DRY); coalesced per slot index so a
-- multi-step operation produces at most one event per touched slot.
function InventoryCore.notifySlot(self, index)
	local d = self.dispatcher
	if not d then return end
	local s = self.slots[index]
	local item_id
	if s.item then
		item_id = s.item.id
	end
	d:emitCoalesced("slotChanged", "slot:" .. index, {
		index = index,
		rev   = s.rev,
		count = s.count,
		id    = item_id,
	})
end

function InventoryCore.add(self, item, qty)
	if DEBUG then Contracts.requireItem(item) end
	qty = qty or 1
	Utils.assertArg(type(qty) == "number" and qty >= 1 and qty % 1 == 0,
		"qty must be a positive integer")

	-- Weight capacity gate, O(1). (math.huge maxWeight works naturally.)
	if item.weight > 0 then
		local room = math.floor((self.maxWeight - self.currentWeight) / item.weight + EPS)
		if room < 1 then return 0 end
		if room < qty then qty = room end
	end

	batchBegin(self)
	local remaining = qty

	-- 1) Top up existing compatible stacks (pooled scratch list, no alloc).
	if item.stackable then
		local partial = Utils.tempLists:acquire()
		self.stackManager.findPartialSlots(self, item, partial)
		for i = 1, partial.n do
			if remaining == 0 then break end
			local slot = partial[i]
			local space = slot.item.maxStack - slot.count
			if space > 0 then
				local put = space < remaining and space or remaining
				slot.count = slot.count + put
				slot.rev = slot.rev + 1
				self.currentWeight = self.currentWeight + put * item.weight
				remaining = remaining - put
				self:notifySlot(slot.index)
			end
		end
		Utils.tempLists:release(partial)
	end

	-- 2) Fill empty slots with fresh stacks (one clone per new stack).
	while remaining > 0 do
		local idx = self.stackManager.findEmptySlot(self)
		if not idx then break end
		local slot = self.slots[idx]
		local put = 1
		if item.stackable then
			put = item.maxStack < remaining and item.maxStack or remaining
		end
		slot.item = ItemFactory.clone(item) -- inventory owns its copy; caller
		slot.count = put              -- may freely mutate the prototype
		slot.rev = slot.rev + 1
		self.currentWeight = self.currentWeight + put * item.weight
		remaining = remaining - put
		self:notifySlot(idx)
	end

	batchEnd(self)
	return qty - remaining
end

function InventoryCore.remove(self, itemId, qty)
	Utils.assertArg(type(itemId) == "string", "itemId must be a string")
	qty = qty or 1
	Utils.assertArg(type(qty) == "number" and qty >= 1 and qty % 1 == 0,
		"qty must be a positive integer")
	batchBegin(self)
	local removed = 0
	local remaining = qty
	for i = 1, self.capacity do
		if remaining == 0 then break end
		local slot = self.slots[i]
		if slot.item and slot.item.id == itemId then
			local take = slot.count < remaining and slot.count or remaining
			slot.count = slot.count - take
			remaining = remaining - take
			removed = removed + take
			self.currentWeight = self.currentWeight - take * slot.item.weight
			slot.rev = slot.rev + 1
			if slot.count == 0 then slot.item = nil end
			self:notifySlot(i)
		end
	end
	batchEnd(self)
	return removed
end

function InventoryCore.move(self, slotFrom, slotTo)
	local a = self:getSlot(slotFrom)
	local b = self:getSlot(slotTo)
	if not a or not b then return false end
	if slotFrom == slotTo then return true end
	if not a.item then return false end
	batchBegin(self)
	if not b.item then
		-- O(1) direct move
		b.item, b.count = a.item, a.count
		a.item, a.count = nil, 0
		a.rev, b.rev = a.rev + 1, b.rev + 1
	elseif self.stackManager.canStack(a.item, b.item) then
		-- O(1) merge attempt (moves 0 if target stack is full)
		self.stackManager.transfer(self, slotFrom, slotTo)
	else
		-- O(1) swap of two occupied, non-stackable-compatible slots
		a.item, b.item = b.item, a.item
		a.count, b.count = b.count, a.count
		a.rev, b.rev = a.rev + 1, b.rev + 1
	end
	self:notifySlot(slotFrom)
	self:notifySlot(slotTo)
	batchEnd(self)
	return true
end

function InventoryCore.split(self, slotIndex, qty)
	local s = self:getSlot(slotIndex)
	if not s or not s.item then return false end
	if type(qty) ~= "number" or qty < 1 or qty % 1 ~= 0 or qty >= s.count then
		return false
	end
	local targetIndex = self.stackManager.findEmptySlot(self)
	if not targetIndex then return false end
	batchBegin(self)
	local t = self.slots[targetIndex]
	t.item = ItemFactory.clone(s.item)
	t.count = qty
	t.rev = t.rev + 1
	s.count = s.count - qty
	s.rev = s.rev + 1
	self:notifySlot(slotIndex)
	self:notifySlot(targetIndex)
	batchEnd(self)
	return true
end

-- Merge slotB INTO slotA (slotA is the merge target).
function InventoryCore.merge(self, slotA, slotB)
	if slotA == slotB then return false end
	local a = self:getSlot(slotA)
	local b = self:getSlot(slotB)
	if not a or not b or not a.item or not b.item then return false end
	if not self.stackManager.canStack(a.item, b.item) then return false end
	batchBegin(self)
	local moved = self.stackManager.transfer(self, slotB, slotA)
	if moved > 0 then
		self:notifySlot(slotA)
		self:notifySlot(slotB)
	end
	batchEnd(self)
	return moved > 0
end

function InventoryCore.getSlot(self, index)
	if type(index) ~= "number" or index < 1 or index > self.capacity then
		return nil
	end
	return self.slots[index] -- internal table: callers must treat as read-only
end

-- Fills/REUSES `out` (pool-friendly, e.g. Utils.tempLists). Entry tables are
-- also reused when the same `out` is passed again - zero alloc on repeat calls.
function InventoryCore.listItems(self, out)
	out = out or {}
	local n = 0
	for i = 1, self.capacity do
		local s = self.slots[i]
		if s.item then
			n = n + 1
			local e = out[n] or {}
			e.slot, e.id, e.count, e.item = i, s.item.id, s.count, s.item
			out[n] = e
		end
	end
	for i = n + 1, #out do out[i] = nil end -- clear stale entries from reuse
	out.n = n
	return out
end

function InventoryCore.recomputeWeight(self)
	local w = 0
	for i = 1, self.capacity do
		local s = self.slots[i]
		if s.item then w = w + s.item.weight * s.count end
	end
	return w
end

-- Plain-state projection used by persistence and networking (DRY: one shape
-- for save files, network snapshots, and diffs).
function InventoryCore.toState(self)
	local st = {
		capacity = self.capacity,
		maxWeight = self.maxWeight,
		currentWeight = self.currentWeight,
		slots = {},
	}
	for i = 1, self.capacity do
		local s = self.slots[i]
		local item_table
		if s.item then
			item_table = ItemFactory.toTable(s.item)
		end
		st.slots[i] = {
			item = item_table,
			count = s.count,
			rev = s.rev,
		}
	end
	return st
end

function InventoryCore.applyState(self, st)
	Utils.assertArg(type(st) == "table" and st.capacity == self.capacity,
		"applyState: capacity mismatch")
	self.maxWeight = st.maxWeight or self.maxWeight
	batchBegin(self)
	for i = 1, self.capacity do
		local src = st.slots[i]
		local s = self.slots[i]
		if src and src.item then
			s.item = ItemFactory.fromTable(src.item) -- keeps uid for diff stability
			s.count = src.count or 1
		else
			s.item = nil
			s.count = 0
		end
		s.rev = (src and src.rev or 0) + 1 -- bump: observers/diffs see the change
		self:notifySlot(i)
	end
	self.currentWeight = self:recomputeWeight()
	batchEnd(self)
	return true
end

-- Return slot tables to the pool (memory reuse across inventory lifetimes).
function InventoryCore.recycle(self)
	for i = 1, self.capacity do
		local s = self.slots[i]
		s.item = nil; s.count = 0; s.rev = 0; s.index = nil
		Utils.slotPool:release(s)
		self.slots[i] = nil
	end
	self.slots = nil
end

function InventoryCore.new(config)
	config = config or {}
	local capacity = config.capacity
	Utils.assertArg(type(capacity) == "number" and capacity >= 1 and capacity % 1 == 0,
		"config.capacity must be a positive integer")
	local maxWeight = config.maxWeight or math.huge
	Utils.assertArg(type(maxWeight) == "number" and maxWeight >= 0,
		"config.maxWeight must be a number >= 0")
	local self = {
		capacity      = capacity,
		maxWeight     = maxWeight,
		currentWeight = 0,
		slots         = {},
		dispatcher    = config.dispatcher,             -- injected (DIP)
		stackManager  = config.stackManager or StackManager, -- injected (DIP/OCP)
	}
	for i = 1, capacity do
		local s = Utils.slotPool:acquire() -- pooled slots: no per-inventory GC churn
		s.index = i
		s.item = nil
		s.count = 0
		s.rev = 0
		self.slots[i] = s
	end
	self.add             = InventoryCore.add
	self.remove          = InventoryCore.remove
	self.move            = InventoryCore.move
	self.split           = InventoryCore.split
	self.merge           = InventoryCore.merge
	self.getSlot         = InventoryCore.getSlot
	self.listItems       = InventoryCore.listItems
	self.notifySlot      = InventoryCore.notifySlot
	self.recomputeWeight = InventoryCore.recomputeWeight
	self.toState         = InventoryCore.toState
	self.applyState      = InventoryCore.applyState
	self.recycle         = InventoryCore.recycle
	if DEBUG then Contracts.requireInventory(self) end
	if DEBUG and self.dispatcher then Contracts.requireEventDispatcher(self.dispatcher) end
	return self
end

----------------------------------------------------------------------
-- SECTION 8: TransactionManager - begin/commit/rollback + atomic helpers
----------------------------------------------------------------------
-- SOLID:
--  S: only transactionality (snapshot/restore); no item or stack logic.
--  O: atomic helpers are additive; new multi-step ops can be built on atomic().
--  L: works with ANY Contracts.Inventory-conforming object.
--  I: small surface: begin/commit/rollback/atomic/atomicAdd/atomicRemove.
--  D: depends on the inventory abstraction passed at construction.
-- DRY: snapshot/restore are single implementations reused by nesting stack.
-- NOTE: snapshots clone items (keepUid) so in-flight behavior mutations of
--       attrs cannot corrupt the rollback image. Restore transfers ownership
--       of the snapshot's clones back to the inventory (snapshot is discarded).
----------------------------------------------------------------------

local TransactionManager = {}

local function snapshot(inv)
	local snap = { currentWeight = inv.currentWeight, slots = {} }
	for i = 1, inv.capacity do
		local s = inv.slots[i]
		local cloned_item
		if s.item then
			cloned_item = ItemFactory.clone(s.item, true)
		end
		snap.slots[i] = {
			item = cloned_item,
			count = s.count,
			rev = s.rev,
		}
	end
	return snap
end

local function restore(inv, snap)
	local d = inv.dispatcher
	if d then d:beginBatch() end
	for i = 1, inv.capacity do
		local s, p = inv.slots[i], snap.slots[i]
		s.item = p.item
		s.count = p.count
		s.rev = p.rev + 1                      -- state changed via rollback: bump for diffs/observers
		if inv.notifySlot then inv:notifySlot(i) end -- optional (ISP)
	end
	inv.currentWeight = snap.currentWeight
	if d then
		d:emit("txRolledBack", {})
		d:endBatch()
	end
end

function TransactionManager.begin(self)
	self.stack[#self.stack + 1] = snapshot(self.inv) -- nesting supported
	return true
end

function TransactionManager.commit(self)
	Utils.assertArg(#self.stack > 0, "commit without begin")
	self.stack[#self.stack] = nil -- discard snapshot
	return true
end

function TransactionManager.rollback(self)
	Utils.assertArg(#self.stack > 0, "rollback without begin")
	local snap = self.stack[#self.stack]
	self.stack[#self.stack] = nil
	restore(self.inv, snap)
	return true
end

-- Run fn(inv) all-or-nothing. Returns ok, err (errors are NOT rethrown).
function TransactionManager.atomic(self, fn)
	self:begin()
	local ok, err = pcall(fn, self.inv)
	if ok then self:commit() else self:rollback() end
	return ok, err
end

-- entries = { { item = Item, qty = number }, ... } - all must fully fit.
function TransactionManager.atomicAdd(self, entries)
	return self:atomic(function(inv)
		for i = 1, #entries do
			local e = entries[i]
			local want = e.qty or 1
			local added = inv:add(e.item, want)
			if added ~= want then
				return error("atomicAdd: insufficient capacity for " .. tostring(e.item.id), 0)
			end
		end
	end)
end

-- requests = { { itemId = string, qty = number }, ... } - all must fully exist.
function TransactionManager.atomicRemove(self, requests)
	return self:atomic(function(inv)
		for i = 1, #requests do
			local r = requests[i]
			local want = r.qty or 1
			local removed = inv:remove(r.itemId, want)
			if removed ~= want then
				return error("atomicRemove: not enough " .. tostring(r.itemId), 0)
			end
		end
	end)
end

function TransactionManager.depth(self)
	return #self.stack
end

function TransactionManager.new(inv)
	if DEBUG then Contracts.requireInventory(inv) end
	local self        = { inv = inv, stack = {} }
	self.begin        = TransactionManager.begin
	self.commit       = TransactionManager.commit
	self.rollback     = TransactionManager.rollback
	self.atomic       = TransactionManager.atomic
	self.atomicAdd    = TransactionManager.atomicAdd
	self.atomicRemove = TransactionManager.atomicRemove
	self.depth        = TransactionManager.depth
	return self
end

----------------------------------------------------------------------
-- SECTION 9: StorageAdapters - InMemory / SaveLoad / NetworkSync
----------------------------------------------------------------------
-- SOLID:
--  L: all three adapters satisfy Contracts.StorageAdapter and are freely
--     substitutable in StorageAdapters.persist/restore (proven in tests).
--  O: add a new backend by writing save/load - no core changes required.
--  I: persist/restore depend only on the narrow StorageAdapter contract.
--  D: high-level save/load policy depends on the adapter abstraction;
--     InMemoryAdapter additionally accepts an injected backend table.
-- DRY: state shape comes from InventoryCore.toState; serialization from Utils.
--
-- NETWORKING NOTES (NetworkSync stub)
--   snapshot(inv)                     -> plain state table
--   computeDiff(oldState, newState)   -> { slots = { {index, data}, ... } }
--   applyDiff(state, diff)            -> mutates state, recomputes weight
--   mergeConflict(local, remote, mode):
--       mode = "server" : server-authoritative - remote wins every conflict.
--       mode = "lww"    : last-write-wins by per-slot rev; ties go to remote
--                         (server as deterministic tie-breaker).
--   Real systems would add sequence numbers, acks, and per-field CRDTs; this
--   stub shows the reconciliation shape with slot-level granularity.
----------------------------------------------------------------------

local StorageAdapters = {}

----------------------------------------------------------------------
-- Generic helpers working with ANY StorageAdapter (LSP demonstration).
----------------------------------------------------------------------
function StorageAdapters.persist(adapter, inv)
	if DEBUG then Contracts.requireStorageAdapter(adapter) end
	return adapter:save(inv:toState())
end

function StorageAdapters.restore(adapter, inv)
	if DEBUG then Contracts.requireStorageAdapter(adapter) end
	local state, err = adapter:load()
	if not state then return false, err end
	inv:applyState(state)
	return true
end

----------------------------------------------------------------------
-- InMemoryAdapter: save/load against an injectable backend table.
----------------------------------------------------------------------
local InMemoryIO = {}

function InMemoryIO.save(self, state)
	self.store.state = Utils.deepCopy(state) -- defensive copy both ways
	return true
end

function InMemoryIO.load(self)
	if self.store.state == nil then return nil, "no saved data" end
	return Utils.deepCopy(self.store.state)
end

function StorageAdapters.newInMemoryAdapter(backend)
	local self = {
		name  = "InMemoryAdapter",
		store = backend or {},
		save  = InMemoryIO.save,
		load  = InMemoryIO.load,
	}
	if DEBUG then Contracts.requireStorageAdapter(self) end
	return self
end

----------------------------------------------------------------------
-- SaveLoadAdapter: serialize state to a string (simulated persistent save).
----------------------------------------------------------------------
local SaveLoadIO = {}

function SaveLoadIO.save(self, state)
	local ok, result = pcall(Utils.serialize, state)
	if not ok then return false, result end
	self.blob = result
	return true
end

function SaveLoadIO.load(self)
	if type(self.blob) ~= "string" then return nil, "no saved data" end
	return Utils.deserialize(self.blob)
end

function StorageAdapters.newSaveLoadAdapter(initialBlob)
	local self = {
		name = "SaveLoadAdapter",
		blob = initialBlob,
		save = SaveLoadIO.save,
		load = SaveLoadIO.load,
	}
	if DEBUG then Contracts.requireStorageAdapter(self) end
	return self
end

----------------------------------------------------------------------
-- NetworkSyncAdapter: snapshot/diff/apply/merge stub + StorageAdapter face.
----------------------------------------------------------------------
local function netStateWeight(state)
	local w = 0
	for i = 1, #state.slots do
		local s = state.slots[i]
		if s and s.item then
			w = w + (s.item.weight or 0) * (s.count or 0)
		end
	end
	return w
end

local function slotSignature(entry)
	if not entry or not entry.item then return "empty" end
	local it = entry.item
	return tostring(it.id) .. "|" .. tostring(entry.count) .. "|"
		.. tostring(entry.rev) .. "|" .. tostring(it.uid or "")
end

local function netSnapshot(inv)
	return inv:toState()
end

local function netComputeDiff(oldState, newState)
	local diff = { slots = {} }
	local n = math.max(oldState.capacity or 0, newState.capacity or 0)
	for i = 1, n do
		if slotSignature(oldState.slots[i]) ~= slotSignature(newState.slots[i]) then
			diff.slots[#diff.slots + 1] = {
				index = i,
				data = Utils.deepCopy(newState.slots[i]),
			}
		end
	end
	return diff
end

local function netApplyDiff(state, diff)
	for i = 1, #diff.slots do
		local op = diff.slots[i]
		state.slots[op.index] = op.data and Utils.deepCopy(op.data) or { count = 0, rev = 0 }
	end
	state.currentWeight = netStateWeight(state) -- recompute: never trust the wire
	return state
end

local function netMergeConflict(localState, remoteState, mode)
	mode = mode or "server"
	local merged = {
		capacity  = remoteState.capacity,
		maxWeight = remoteState.maxWeight,
		slots     = {},
	}
	for i = 1, merged.capacity do
		local l, r = localState.slots[i], remoteState.slots[i]
		local choice
		if slotSignature(l) == slotSignature(r) then
			choice = r            -- no conflict
		elseif mode == "server" then
			choice = r            -- server authoritative
		else
			local lr = (l and l.rev) or -1 -- last-write-wins by rev
			local rr = (r and r.rev) or -1
			choice = (rr >= lr) and r or l -- tie -> server side
		end
		merged.slots[i] = Utils.deepCopy(choice) or { count = 0, rev = 0 }
	end
	merged.currentWeight = netStateWeight(merged)
	return merged
end

local NetSyncIO = {}

function NetSyncIO.save(self, state)
	self.remote = Utils.deepCopy(state)
	return true
end

function NetSyncIO.load(self)
	if self.remote == nil then return nil, "no remote state" end
	return Utils.deepCopy(self.remote)
end

function StorageAdapters.newNetworkSyncAdapter()
	local self = {
		name   = "NetworkSyncAdapter",
		remote = nil,
		save   = NetSyncIO.save,
		load   = NetSyncIO.load,
	}
	if DEBUG then Contracts.requireStorageAdapter(self) end
	return self
end

StorageAdapters.NetworkSync = {
	snapshot      = netSnapshot,
	computeDiff   = netComputeDiff,
	applyDiff     = netApplyDiff,
	mergeConflict = netMergeConflict,
	stateWeight   = netStateWeight,
}

----------------------------------------------------------------------
-- SECTION 10: UIAdapterExample - event-driven textual inventory view
----------------------------------------------------------------------
-- SOLID:
--  D: core modules NEVER print; this adapter owns I/O and depends on the
--     EventDispatcher + Inventory abstractions (Dependency Inversion).
--  I: satisfies the minimal UIAdapter contract { render, attach?, detach? }.
--  S: only presentation. Swap in a graphical adapter without touching core.
-- The write function is injectable (default: print) for testability.
----------------------------------------------------------------------

local UIAdapterExample = {}

function UIAdapterExample.render(self)
	local inv = self.inv
	local lines = {}
	lines[#lines + 1] = string.format("Inventory | slots %d | weight %.1f / %.1f",
		inv.capacity, inv.currentWeight, inv.maxWeight)
	for i = 1, inv.capacity do
		local s = inv:getSlot(i)
		if s.item then
			lines[#lines + 1] = string.format("  [%d] %s x%d  (type=%s, total weight %.1f)",
				i, s.item.id, s.count, s.item.type, s.item.weight * s.count)
		else
			lines[#lines + 1] = string.format("  [%d] <empty>", i)
		end
	end
	self.write(table.concat(lines, "\n"))
end

function UIAdapterExample.attach(self)
	local d = self.inv.dispatcher
	if not d then return self end
	self.subs[#self.subs + 1] = d:on("slotChanged", function(p)
		self.write(string.format("  [event] slot %d -> %s x%s",
			p.index, tostring(p.id or "<empty>"), tostring(p.count)))
	end)
	self.subs[#self.subs + 1] = d:on("txRolledBack", function()
		self.write("  [event] transaction rolled back; view restored")
	end)
	return self
end

function UIAdapterExample.detach(self)
	local d = self.inv.dispatcher
	if not d then return end
	for i = 1, #self.subs do d:off(self.subs[i]) end
	self.subs = {}
end

function UIAdapterExample.new(inv, writeFn)
	local self = {
		inv   = inv,
		write = writeFn or print,
		subs  = {},
	}
	self.render = UIAdapterExample.render
	self.attach = UIAdapterExample.attach
	self.detach = UIAdapterExample.detach
	if DEBUG then Contracts.requireUIAdapter(self) end
	return self
end

----------------------------------------------------------------------
-- SECTION 11: Shared demo item definitions (DRY: used by Tests + ExampleUsage)
----------------------------------------------------------------------

local ItemDefs = {
	potion  = { id = "potion", type = "consumable", stackable = true, maxStack = 8, weight = 1, attrs = { heal = 25 } },
	ore     = { id = "ore", type = "material", stackable = true, maxStack = 16, weight = 2 },
	sword   = { id = "sword", type = "equippable", stackable = false, weight = 5, attrs = { slot = "hand" } },
	feather = { id = "feather", type = "material", stackable = true, maxStack = 32, weight = 0 },
}

----------------------------------------------------------------------
-- SECTION 12: Tests - unit, integration, deterministic fuzz
----------------------------------------------------------------------

local Tests = {}

local results = { passed = 0, failed = 0, failures = {} }

local function check(cond, name)
	if cond then
		results.passed = results.passed + 1
	else
		results.failed = results.failed + 1
		results.failures[#results.failures + 1] = name
		print("  FAIL: " .. name)
	end
end

local function checkEq(got, want, name)
	check(got == want, string.format("%s (got %s, want %s)", name, tostring(got), tostring(want)))
end

local function checkApprox(got, want, name)
	check(math.abs(got - want) < 1e-6,
		string.format("%s (got %s, want ~%s)", name, tostring(got), tostring(want)))
end

local function makeInv(capacity, maxWeight)
	return InventoryCore.new({ capacity = capacity, maxWeight = maxWeight })
end

-- Compact comparable signature of inventory contents.
local function stateSig(inv)
	local parts = {}
	for i = 1, inv.capacity do
		local s = inv.slots[i]
		parts[#parts + 1] = s.item and (s.item.id .. "x" .. s.count) or "-"
	end
	parts[#parts + 1] = ("w=%.4f"):format(inv.currentWeight)
	return table.concat(parts, "|")
end

----------------------------------------------------------------------
local function testUtils()
	print("-- unit: Utils")
	local o = { x = 1, inner = { 1 } }
	local sc = Utils.shallowCopy(o)
	sc.x = 5
	checkEq(o.x, 1, "shallowCopy top level independent")
	check(sc.inner == o.inner, "shallowCopy shares nested refs")

	local orig = { a = 1, b = { c = 2 } }
	local dc = Utils.deepCopy(orig)
	dc.b.c = 99
	checkEq(orig.b.c, 2, "deepCopy fully independent")

	local idA, idB = Utils.newId("t"), Utils.newId("t")
	check(idA ~= idB, "newId unique")
	check(idA:find("t_") == 1, "newId prefix")

	check(not pcall(Utils.assertArg, false, "boom"), "assertArg raises on false")

	local p = Utils.newPool({ factory = function() return {} end, max = 2 })
	local pa = p:acquire()
	p:acquire()
	checkEq(p.made, 2, "pool creates on demand")
	p:release(pa)
	local pc = p:acquire()
	checkEq(p.made, 2, "pool reuses released table (no new alloc)")
	check(pc == pa, "pool returns same table")

	local r1, r2 = Utils.newRng(1234), Utils.newRng(1234)
	local same, inRange = true, true
	for _ = 1, 20 do
		local a, b = r1(), r2()
		if a ~= b then same = false end
		if a < 0 or a >= 1 then inRange = false end
	end
	check(same, "rng deterministic for identical seed")
	check(inRange, "rng values in [0,1)")

	local src = {
		name = 'he said "hi"\nback\\slash',
		n = -3.25,
		big = 123456789.5,
		flag = true,
		list = { 10, 20, 30 },
		nested = { x = 1, deep = { y = "z" } },
	}
	local back, err = Utils.deserialize(Utils.serialize(src))
	check(back ~= nil, "serialize/deserialize roundtrip ok: " .. tostring(err))
	if back then
		checkEq(back.name, src.name, "string with quotes/newline roundtrip")
		checkEq(back.n, -3.25, "negative fraction roundtrip")
		checkEq(back.big, 123456789.5, "large number roundtrip")
		checkEq(back.flag, true, "boolean roundtrip")
		checkEq(back.list[3], 30, "array roundtrip")
		checkEq(back.nested.deep.y, "z", "nested hash roundtrip")
	end
	local _, err2 = Utils.deserialize("this is not lua )(")
	check(err2 ~= nil, "garbage input rejected")
	local _, err3 = Utils.deserialize("42")
	check(err3 ~= nil, "non-table payload rejected")
end

----------------------------------------------------------------------
local function testContracts()
	print("-- unit: Contracts")
	check(Contracts.checkItem(ItemFactory.create(ItemDefs.potion)), "good item passes")
	check(not Contracts.checkItem({ id = 1, type = "x", stackable = false, maxStack = 1, weight = 0, attrs = {} }),
		"bad item.id rejected")
	check(not Contracts.checkItem(nil), "nil item rejected")
	check(Contracts.checkEventDispatcher(EventDispatcher.new()), "dispatcher contract")
	check(Contracts.checkUIAdapter(UIAdapterExample.new(makeInv(1, 1), function() end)), "ui contract")
	check(Contracts.checkStorageAdapter(StorageAdapters.newInMemoryAdapter()), "adapter contract")
	local inv = makeInv(2, 5)
	check(Contracts.checkInventory(inv), "inventory contract")
	inv:recycle()
end

----------------------------------------------------------------------
local function testItemFactory()
	print("-- unit: ItemFactory")
	local potion = ItemFactory.create(ItemDefs.potion)
	check(Contracts.checkItem(potion), "created item passes contract")
	checkEq(potion.stackable, true, "stackable flag")
	checkEq(potion.maxStack, 8, "maxStack from def")
	checkEq(potion.count, 1, "default count 1")
	check(not pcall(ItemFactory.create, {}), "create rejects empty def")
	check(not pcall(ItemFactory.create, { id = "x", type = "y", stackable = true, maxStack = 1 }),
		"stackable requires maxStack >= 2")

	potion.attrs.heal = 25
	local clone = ItemFactory.clone(potion)
	clone.attrs.heal = 999
	checkEq(potion.attrs.heal, 25, "clone attrs independent")
	check(clone.uid ~= potion.uid, "clone gets fresh uid")
	checkEq(ItemFactory.clone(potion, true).uid, potion.uid, "clone keepUid preserves uid")

	local back = ItemFactory.deserialize(ItemFactory.serialize(potion))
	check(back ~= nil, "item deserialize ok")
	if back then
		checkEq(back.id, potion.id, "serialized id")
		checkEq(back.attrs.heal, 25, "serialized attrs")
		checkEq(back.uid, potion.uid, "uid preserved through serialization")
	end

	ItemFactory.registerBehavior("test_probe", {
		onUse = function(inv, slot, ctx)
			ctx.probed = slot.count
			return true
		end,
	})
	check(not pcall(ItemFactory.registerBehavior, "test_probe", { onUse = function() end }),
		"duplicate behavior registration rejected")

	local bInv = makeInv(2, 10)
	bInv:add(ItemFactory.create({ id = "probe", type = "test_probe", stackable = true, maxStack = 4, weight = 1 }), 3)
	local ctx = {}
	check(ItemFactory.useItem(bInv, 1, ctx), "useItem dispatches registered behavior")
	checkEq(ctx.probed, 3, "behavior observed slot state")
	local emptyUse = ItemFactory.useItem(bInv, 2, ctx)
	check(emptyUse == false, "useItem on empty slot fails")
	bInv:add(ItemFactory.create(ItemDefs.ore), 1)
	local noBehavior = ItemFactory.useItem(bInv, 2, ctx)
	check(noBehavior == false, "useItem without behavior fails cleanly")
	bInv:recycle()
end

----------------------------------------------------------------------
local function testStackManager()
	print("-- unit: StackManager")
	local inv = makeInv(4, 100)
	inv:add(ItemFactory.create(ItemDefs.potion), 3)
	inv:add(ItemFactory.create(ItemDefs.sword), 1)

	local out = Utils.tempLists:acquire()
	StackManager.findPartialSlots(inv, ItemFactory.create(ItemDefs.potion), out)
	checkEq(out.n, 1, "one partial potion stack found")
	checkEq(out[1].index, 1, "partial stack slot index")
	StackManager.findPartialSlots(inv, ItemFactory.create(ItemDefs.sword), out)
	checkEq(out.n, 0, "non-stackable yields no partials")
	Utils.tempLists:release(out)

	check(StackManager.canStack(ItemFactory.create(ItemDefs.potion), ItemFactory.create(ItemDefs.potion)),
		"canStack: same stackable id")
	check(not StackManager.canStack(ItemFactory.create(ItemDefs.potion), ItemFactory.create(ItemDefs.ore)),
		"canStack: different ids")
	check(not StackManager.canStack(ItemFactory.create(ItemDefs.sword), ItemFactory.create(ItemDefs.sword)),
		"canStack: non-stackable never stacks")

	-- Transfer tests: reset, then build a deterministic layout
	-- (slot1 potion x8, slot2 sword, slot3 potion x6)
	inv:remove("potion", 99)                     -- clear potions from earlier asserts
	inv:remove("sword", 99)                      -- clear sword from earlier asserts
	inv:add(ItemFactory.create(ItemDefs.potion), 8) -- slot1 -> x8 (full)
	inv:add(ItemFactory.create(ItemDefs.sword), 1) -- slot2 -> sword (blocks spillover)
	inv:add(ItemFactory.create(ItemDefs.potion), 6) -- slot3 -> x6
	checkEq(StackManager.transfer(inv, 3, 1), 0, "transfer into full stack moves 0")
	inv:remove("potion", 4)                      -- slot1 -> x4 (room for 4)
	checkEq(StackManager.transfer(inv, 3, 1), 4, "transfer fills target to maxStack")
	checkEq(inv:getSlot(1).count, 8, "transfer target count")
	checkEq(inv:getSlot(3).count, 2, "transfer source remainder")
	checkEq(StackManager.transfer(inv, 3, 1), 0, "transfer into refilled full stack moves 0")
	inv:recycle()
end

----------------------------------------------------------------------
local function testInventoryCore()
	print("-- unit: InventoryCore")
	local inv = makeInv(4, 100)
	check(Contracts.checkInventory(inv), "inventory satisfies contract")

	checkEq(inv:add(ItemFactory.create(ItemDefs.potion), 5), 5, "add returns added count")
	checkEq(inv:getSlot(1).count, 5, "first stack holds 5")
	checkEq(inv:add(ItemFactory.create(ItemDefs.potion), 6), 6, "stacking add accepted")
	checkEq(inv:getSlot(1).count, 8, "stack capped at maxStack")
	checkEq(inv:getSlot(2).count, 3, "spillover into next slot")

	checkEq(inv:remove("potion", 11), 11, "remove across stacks")
	checkEq(inv:getSlot(1).item, nil, "slot cleared at zero count")
	checkEq(inv:remove("potion", 1), 0, "remove from empty returns 0")

	local wInv = makeInv(4, 10)
	checkEq(wInv:add(ItemFactory.create(ItemDefs.ore), 6), 5, "add limited by weight capacity")
	checkApprox(wInv.currentWeight, 10, "weight exactly at cap")
	checkEq(wInv:add(ItemFactory.create(ItemDefs.ore), 1), 0, "no room left by weight")
	wInv:recycle()

	local sInv = makeInv(2, 1000)
	checkEq(sInv:add(ItemFactory.create(ItemDefs.sword), 3), 2, "add limited by slot capacity")
	sInv:recycle()

	-- move: to empty / swap / merge / merge-when-full
	local mInv = makeInv(4, 100)
	mInv:add(ItemFactory.create(ItemDefs.sword), 1)
	check(mInv:move(1, 2), "move to empty ok")
	checkEq(mInv:getSlot(1).item, nil, "move source emptied")
	checkEq(mInv:getSlot(2).item.id, "sword", "move target filled")
	mInv:add(ItemFactory.create(ItemDefs.sword), 1)                                  -- slot1
	mInv:add(ItemFactory.create({ id = "shield", type = "equippable", weight = 4 }), 1) -- slot3
	check(mInv:move(1, 3), "move swap ok")
	checkEq(mInv:getSlot(1).item.id, "shield", "swap: shield to slot1")
	checkEq(mInv:getSlot(3).item.id, "sword", "swap: sword to slot3")
	mInv:recycle()

	local gInv = makeInv(4, 100)
	gInv:add(ItemFactory.create(ItemDefs.potion), 8) -- slot1 full
	gInv:add(ItemFactory.create(ItemDefs.potion), 3) -- slot2 x3
	check(gInv:move(2, 1), "move same-item into full stack ok (no-op merge)")
	checkEq(gInv:getSlot(1).count, 8, "full stack unchanged")
	checkEq(gInv:getSlot(2).count, 3, "source unchanged when target full")
	gInv:remove("potion", 4) -- slot1 -> x4
	check(gInv:move(2, 1), "merge-move ok")
	checkEq(gInv:getSlot(1).count, 7, "merge-move filled target")
	checkEq(gInv:getSlot(2).item, nil, "merge-move emptied source")
	gInv:recycle()

	local spInv = makeInv(3, 100)
	spInv:add(ItemFactory.create(ItemDefs.potion), 8)
	check(spInv:split(1, 3), "split ok")
	checkEq(spInv:getSlot(1).count, 5, "split source reduced")
	checkEq(spInv:getSlot(2).count, 3, "split target filled")
	check(not spInv:split(1, 9), "split more than count fails")
	check(not spInv:split(1, 0), "split zero fails")
	spInv:add(ItemFactory.create(ItemDefs.sword), 1) -- fills slot3
	check(not spInv:split(1, 2), "split without empty slot fails")
	spInv:recycle()

	local mgInv = makeInv(3, 100)
	mgInv:add(ItemFactory.create(ItemDefs.potion), 8)
	mgInv:add(ItemFactory.create(ItemDefs.potion), 6) -- slot2 x6
	check(not mgInv:merge(1, 2), "merge into full target fails")
	check(mgInv:merge(2, 1), "merge into partial target ok")
	checkEq(mgInv:getSlot(2).count, 8, "merge filled target")
	checkEq(mgInv:getSlot(1).count, 6, "merge drained source")
	check(not mgInv:merge(2, 1), "merge into now-full target fails")
	check(not mgInv:merge(1, 3), "merge with empty slot fails")

	local out = Utils.tempLists:acquire()
	mgInv:listItems(out)
	checkEq(out.n, 2, "listItems entry count")
	checkEq(out[1].count + out[2].count, 14, "listItems totals")
	mgInv:listItems(out)
	checkEq(out.n, 2, "listItems out-table reuse works")
	Utils.tempLists:release(out)

	checkEq(mgInv:getSlot(0), nil, "getSlot low bound")
	checkEq(mgInv:getSlot(mgInv.capacity + 1), nil, "getSlot high bound")
	checkApprox(mgInv.currentWeight, mgInv:recomputeWeight(), "tracked weight matches recompute")
	mgInv:recycle()

	-- isolation: inventory clones on add; mutating the prototype must not leak
	local iso = makeInv(2, 50)
	local proto = ItemFactory.create(ItemDefs.potion)
	iso:add(proto, 2)
	proto.attrs.heal = 0
	proto.weight = 99
	checkEq(iso:getSlot(1).item.attrs.heal, 25, "inventory isolated from prototype attrs mutation")
	checkApprox(iso.currentWeight, 2, "inventory weight isolated from prototype mutation")
	iso:recycle()

	-- pooling: recycled slots are reused, no new allocations
	local rInv = makeInv(4, 10)
	local madeAfterCreate = Utils.slotPool.made
	rInv:add(ItemFactory.create(ItemDefs.potion), 2)
	rInv:recycle()
	local rInv2 = makeInv(4, 10)
	checkEq(Utils.slotPool.made, madeAfterCreate, "slot pool reused after recycle (no new allocs)")
	rInv2:recycle()
end

----------------------------------------------------------------------
local function testEvents()
	print("-- unit: EventDispatcher")
	local d = EventDispatcher.new()
	local total = 0
	local h = d:on("x", function(p) total = total + (p.n or 1) end)
	d:emit("x", { n = 2 })
	checkEq(total, 2, "emit delivers payload")
	check(d:off(h), "off returns true")
	d:emit("x", { n = 5 })
	checkEq(total, 2, "off stops delivery")

	local order = {}
	local d2 = EventDispatcher.new()
	d2:on("t", function(p) order[#order + 1] = p.tag end)
	d2:beginBatch()
	d2:emit("t", { tag = "a" })
	d2:emit("t", { tag = "b" })
	checkEq(#order, 0, "batch holds events until endBatch")
	d2:endBatch()
	check(#order == 2 and order[1] == "a" and order[2] == "b", "batch preserves order")

	local got = {}
	local d3 = EventDispatcher.new()
	d3:on("slot", function(p) got[#got + 1] = p end)
	d3:beginBatch()
	d3:emitCoalesced("slot", "k1", { v = 1 })
	d3:emitCoalesced("slot", "k1", { v = 2 })
	d3:emitCoalesced("slot", "k2", { v = 3 })
	checkEq(#got, 0, "coalesced events held until endBatch")
	d3:endBatch()
	checkEq(#got, 2, "coalescing: one delivery per key")
	checkEq(got[1].v, 2, "coalescing: latest payload wins")
	checkEq(got[2].v, 3, "coalescing: second key delivered")

	local nested = 0
	local d4 = EventDispatcher.new()
	d4:on("n", function() nested = nested + 1 end)
	d4:beginBatch()
	d4:beginBatch()
	d4:emit("n", {})
	d4:endBatch()
	checkEq(nested, 0, "nested batch not flushed early")
	d4:endBatch()
	checkEq(nested, 1, "nested batch flushed at outer end")
end

----------------------------------------------------------------------
local function testTransactions()
	print("-- unit: TransactionManager")
	local inv = makeInv(4, 20)
	local tx = TransactionManager.new(inv)

	local ok = tx:atomicAdd({
		{ item = ItemFactory.create(ItemDefs.potion), qty = 5 },
		{ item = ItemFactory.create(ItemDefs.ore),    qty = 4 },
	})
	check(ok, "atomicAdd success commits")
	checkEq(inv:getSlot(1).count, 5, "atomicAdd potion placed")
	checkEq(inv:getSlot(2).count, 4, "atomicAdd ore placed")
	local sigOk = stateSig(inv)

	local ok2, err2 = tx:atomicAdd({
		{ item = ItemFactory.create(ItemDefs.sword), qty = 1 },
		{ item = ItemFactory.create(ItemDefs.sword), qty = 1 },
		{ item = ItemFactory.create(ItemDefs.sword), qty = 1 },
	})
	check(not ok2 and type(err2) == "string", "atomicAdd failure reports error")
	checkEq(stateSig(inv), sigOk, "failed atomicAdd fully rolled back")

	local ok3 = tx:atomicRemove({ { itemId = "potion", qty = 99 } })
	check(not ok3, "atomicRemove failure rolls back")
	checkEq(inv:getSlot(1).count, 5, "potion count restored after failed remove")

	tx:begin()
	inv:add(ItemFactory.create(ItemDefs.potion), 2) -- slot1 -> x7
	tx:begin()
	inv:add(ItemFactory.create(ItemDefs.ore), 2) -- slot2 -> x6
	checkEq(tx:depth(), 2, "nested transaction depth")
	tx:rollback()
	checkEq(inv:getSlot(2).count, 4, "inner rollback undoes inner change only")
	tx:commit()
	checkEq(inv:getSlot(1).count, 7, "outer commit keeps outer change")
	check(not pcall(function() tx:commit() end), "commit without begin errors")
	inv:recycle()
end

----------------------------------------------------------------------
local function testStorage()
	print("-- unit: StorageAdapters (InMemory / SaveLoad / LSP substitution)")
	local adapters = {
		StorageAdapters.newInMemoryAdapter(),
		StorageAdapters.newSaveLoadAdapter(),
		StorageAdapters.newNetworkSyncAdapter(),
	}
	for i = 1, #adapters do
		local a = adapters[i]
		check(Contracts.checkStorageAdapter(a), a.name .. ": satisfies contract")
		local src = makeInv(3, 30)
		src:add(ItemFactory.create(ItemDefs.potion), 4)
		src:add(ItemFactory.create(ItemDefs.sword), 1)
		local sig = stateSig(src)
		check(StorageAdapters.persist(a, src), a.name .. ": persist")
		local dst = InventoryCore.new({ capacity = 3, maxWeight = 30 })
		check(StorageAdapters.restore(a, dst), a.name .. ": restore")
		checkEq(stateSig(dst), sig, a.name .. ": roundtrip state equality (LSP)")
		src:recycle(); dst:recycle()
	end

	local sl = StorageAdapters.newSaveLoadAdapter()
	local src = makeInv(2, 10)
	src:add(ItemFactory.create(ItemDefs.potion), 2)
	StorageAdapters.persist(sl, src)
	check(type(sl.blob) == "string" and #sl.blob > 0, "SaveLoad produces string blob")
	sl.blob = "corrupted )("
	local dst = InventoryCore.new({ capacity = 2, maxWeight = 10 })
	local ok, err = StorageAdapters.restore(sl, dst)
	check(not ok and type(err) == "string", "corrupted blob rejected with error")

	local backend = {}
	local im = StorageAdapters.newInMemoryAdapter(backend)
	StorageAdapters.persist(im, src)
	check(backend.state ~= nil, "InMemory writes into injected backend")
	src:recycle(); dst:recycle()
end

----------------------------------------------------------------------
local function testNetworkSync()
	print("-- unit: NetworkSyncAdapter (diff / apply / merge)")
	local NetSync = StorageAdapters.NetworkSync
	local inv = makeInv(4, 50)
	inv:add(ItemFactory.create(ItemDefs.potion), 4)
	local s0 = NetSync.snapshot(inv)
	inv:add(ItemFactory.create(ItemDefs.potion), 2)
	local s1 = NetSync.snapshot(inv)

	local diff = NetSync.computeDiff(s0, s1)
	checkEq(#diff.slots, 1, "diff touches exactly one slot")
	checkEq(diff.slots[1].index, 1, "diff targets slot 1")
	local rebuilt = Utils.deepCopy(s0)
	NetSync.applyDiff(rebuilt, diff)
	checkEq(rebuilt.slots[1].count, 6, "applyDiff updates count")
	checkApprox(rebuilt.currentWeight, s1.currentWeight, "applyDiff recomputes weight")

	local function slot(count, rev, uid)
		return {
			item = {
				id = "potion",
				type = "consumable",
				stackable = true,
				maxStack = 8,
				weight = 1,
				attrs = {},
				uid = uid
			},
			count = count,
			rev = rev,
		}
	end
	local L    = { capacity = 1, maxWeight = 10, slots = { slot(5, 5, "u1") }, currentWeight = 5 }
	local Rlow = { capacity = 1, maxWeight = 10, slots = { slot(3, 4, "u1") }, currentWeight = 3 }
	local Rhi  = { capacity = 1, maxWeight = 10, slots = { slot(3, 7, "u1") }, currentWeight = 3 }
	checkEq(NetSync.mergeConflict(L, Rlow, "server").slots[1].count, 3,
		"server mode: remote always wins")
	checkEq(NetSync.mergeConflict(L, Rlow, "lww").slots[1].count, 5,
		"lww: local rev 5 beats remote rev 4")
	checkEq(NetSync.mergeConflict(L, Rhi, "lww").slots[1].count, 3,
		"lww: remote rev 7 beats local rev 5")

	local net = StorageAdapters.newNetworkSyncAdapter()
	check(net:save(s1), "network adapter save (StorageAdapter face)")
	local loaded = net:load()
	check(loaded ~= nil and loaded.slots[1].count == 6, "network adapter load")
end

----------------------------------------------------------------------
local function testIntegration()
	print("-- integration: events + transactions + persistence")
	local d = EventDispatcher.new()
	local inv = InventoryCore.new({ capacity = 4, maxWeight = 50, dispatcher = d })
	local events = 0
	d:on("slotChanged", function() events = events + 1 end)
	inv:add(ItemFactory.create(ItemDefs.potion), 10) -- spans 2 slots
	checkEq(events, 2, "coalesced events: exactly one per touched slot")

	local tx = TransactionManager.new(inv)
	tx:atomicAdd({ { item = ItemFactory.create(ItemDefs.sword), qty = 1 } })
	local sigAfterOk = stateSig(inv)
	local ok = tx:atomicAdd({
		{ item = ItemFactory.create(ItemDefs.sword), qty = 1 },
		{ item = ItemFactory.create(ItemDefs.ore),   qty = 999 }, -- cannot fit (weight)
	})
	check(not ok, "mixed atomic add fails")
	checkEq(stateSig(inv), sigAfterOk, "rollback restored exact prior state")

	local adapter = StorageAdapters.newSaveLoadAdapter()
	check(StorageAdapters.persist(adapter, inv), "persist after transaction")
	inv:remove("potion", 100)
	inv:remove("sword", 100)
	local inv2 = InventoryCore.new({ capacity = 4, maxWeight = 50 })
	check(StorageAdapters.restore(adapter, inv2), "restore into fresh inventory")
	checkEq(stateSig(inv2), sigAfterOk, "restored state matches saved state")
	inv:recycle(); inv2:recycle()
end

----------------------------------------------------------------------
local function validateInvariants(inv)
	local seen = {}
	local w = 0
	for i = 1, inv.capacity do
		local s = inv.slots[i]
		if seen[s] then return false, "duplicate slot table at index " .. i end
		seen[s] = true
		if s.item then
			if s.count < 1 then return false, "non-positive count at " .. i end
			if s.count % 1 ~= 0 then return false, "fractional count at " .. i end
			if s.count > s.item.maxStack then return false, "overfull stack at " .. i end
			if (not s.item.stackable) and s.count ~= 1 then
				return false, "non-stackable count ~= 1 at " .. i
			end
			w = w + s.item.weight * s.count
		else
			if s.count ~= 0 then return false, "empty slot with nonzero count at " .. i end
		end
	end
	if math.abs(w - inv.currentWeight) > 1e-6 then return false, "weight drift" end
	if inv.currentWeight > inv.maxWeight + 1e-6 then return false, "over weight capacity" end
	return true
end

local function testFuzz()
	print("-- fuzz: 400 seeded random operations with invariant checks")
	local rng = Utils.newRng(20260802) -- fixed seed => deterministic run
	local inv = makeInv(8, 50)
	local defs = { ItemDefs.potion, ItemDefs.ore, ItemDefs.sword, ItemDefs.feather }
	local counts = { add = 0, remove = 0, move = 0, split = 0, merge = 0 }
	local aborted = false
	for step = 1, 400 do
		local r = rng()
		local ok, err = pcall(function()
			if r < 0.35 then
				local def = defs[1 + math.floor(rng() * #defs)]
				inv:add(ItemFactory.create(def), 1 + math.floor(rng() * 12))
				counts.add = counts.add + 1
			elseif r < 0.60 then
				local def = defs[1 + math.floor(rng() * #defs)]
				inv:remove(def.id, 1 + math.floor(rng() * 10))
				counts.remove = counts.remove + 1
			elseif r < 0.75 then
				inv:move(1 + math.floor(rng() * inv.capacity), 1 + math.floor(rng() * inv.capacity))
				counts.move = counts.move + 1
			elseif r < 0.88 then
				inv:split(1 + math.floor(rng() * inv.capacity), 1 + math.floor(rng() * 5))
				counts.split = counts.split + 1
			else
				inv:merge(1 + math.floor(rng() * inv.capacity), 1 + math.floor(rng() * inv.capacity))
				counts.merge = counts.merge + 1
			end
		end)
		if not ok then
			check(false, "fuzz step " .. step .. " raised: " .. tostring(err))
			aborted = true
			break
		end
		local vok, verr = validateInvariants(inv)
		if not vok then
			check(false, "fuzz step " .. step .. " invariant broken: " .. tostring(verr))
			aborted = true
			break
		end
	end
	if not aborted then
		check(true, "fuzz completed: no errors, invariants held for all 400 steps")
	end
	print(string.format("   fuzz op mix: add=%d remove=%d move=%d split=%d merge=%d",
		counts.add, counts.remove, counts.move, counts.split, counts.merge))
	inv:recycle()
end

----------------------------------------------------------------------
function Tests.runAll()
	print("\n----------------------------------------------------------------------")
	print(" TEST SUITE (unit + integration + fuzz)")
	print("----------------------------------------------------------------------")
	testUtils()
	testContracts()
	testItemFactory()
	testStackManager()
	testInventoryCore()
	testEvents()
	testTransactions()
	testStorage()
	testNetworkSync()
	testIntegration()
	testFuzz()
end

function Tests.summary()
	print(string.rep("-", 70))
	print(string.format(" TESTS: %d passed, %d failed", results.passed, results.failed))
	for i = 1, #results.failures do
		print("   failed: " .. results.failures[i])
	end
	print(string.rep("-", 70))
	return results.failed == 0
end

----------------------------------------------------------------------
-- SECTION 13: ExampleUsage - guided runnable scenario
----------------------------------------------------------------------

local ExampleUsage = {}

local function banner(title)
	print("\n-- Example: " .. title)
end

function ExampleUsage.run()
	print("\n----------------------------------------------------------------------")
	print("-- ExampleUsage - guided scenario")
	print("----------------------------------------------------------------------")

	banner("module map (Structure)")
	for i = 1, #Structure do
		print(string.format("  %-18s - %s", Structure[i].name, Structure[i].purpose))
	end

	banner("setup: dispatcher + inventory + text UI (events attached)")
	local dispatcher = EventDispatcher.new()
	local inv = InventoryCore.new({ capacity = 6, maxWeight = 40, dispatcher = dispatcher })
	local ui = UIAdapterExample.new(inv)
	ui:attach()

	banner("create items, add with stacking")
	inv:add(ItemFactory.create(ItemDefs.potion), 5)
	inv:add(ItemFactory.create(ItemDefs.potion), 6) -- fills slot 1, spills 3
	inv:add(ItemFactory.create(ItemDefs.ore), 10)
	inv:add(ItemFactory.create(ItemDefs.sword), 1)
	ui:render()

	banner("split, then merge back via move")
	inv:split(1, 3)
	inv:move(5, 2)
	ui:render()

	banner("remove")
	inv:remove("ore", 4)
	ui:render()

	banner("transaction: atomic multi-slot add (success)")
	local tx = TransactionManager.new(inv)
	local ok = tx:atomicAdd({
		{ item = ItemFactory.create(ItemDefs.potion), qty = 2 },
		{ item = ItemFactory.create(ItemDefs.ore),    qty = 5 },
	})
	print("atomicAdd ok =", ok)
	ui:render()

	banner("transaction: atomic add that cannot fit (rollback)")
	local ok2, err2 = tx:atomicAdd({
		{ item = ItemFactory.create(ItemDefs.sword), qty = 1 },
		{ item = ItemFactory.create(ItemDefs.sword), qty = 1 },
		{ item = ItemFactory.create(ItemDefs.sword), qty = 1 },
	})
	print("atomicAdd ok =", ok2, "| err =", tostring(err2))
	ui:render()

	banner("item behaviors: consumable + equippable (registered, not hardcoded)")
	-- Open/Closed: these behaviors live HERE, not in core. useItem dispatches.
	ItemFactory.registerBehavior("consumable", {
		onUse = function(inv2, slot, context)
			local item = slot.item
			slot.count = slot.count - 1
			inv2.currentWeight = inv2.currentWeight - item.weight
			slot.rev = slot.rev + 1
			if slot.count == 0 then slot.item = nil end
			inv2:notifySlot(slot.index)
			context.effects = context.effects or {}
			context.effects[#context.effects + 1] = { kind = "heal", amount = item.attrs.heal or 0 }
			return true
		end,
	})
	ItemFactory.registerBehavior("equippable", {
		onUse = function(inv2, slot, context)
			local item = slot.item
			item.attrs.equipped = not item.attrs.equipped
			slot.rev = slot.rev + 1
			inv2:notifySlot(slot.index)
			context.lastToggle = { id = item.id, equipped = item.attrs.equipped }
			return true
		end,
	})
	local context = {}
	print("use potion (slot 1):", ItemFactory.useItem(inv, 1, context))
	print("use sword  (slot 4):", ItemFactory.useItem(inv, 4, context))
	print("effect:", context.effects[1].kind, context.effects[1].amount,
		"| sword equipped:", tostring(context.lastToggle.equipped))
	ui:render()

	banner("save/load simulation via SaveLoadAdapter (string persistence)")
	local saveAdapter = StorageAdapters.newSaveLoadAdapter()
	StorageAdapters.persist(saveAdapter, inv)
	print(("save blob (%d chars): %s..."):format(#saveAdapter.blob, saveAdapter.blob:sub(1, 64)))
	inv:remove("potion", 99) -- simulate play-after-save
	print("after wiping potions:")
	ui:render()
	StorageAdapters.restore(saveAdapter, inv)
	print("after restore:")
	ui:render()

	banner("network sync: simulated authoritative server + client")
	local NetSync = StorageAdapters.NetworkSync
	local serverInv = InventoryCore.new({ capacity = 6, maxWeight = 40 })
	serverInv:add(ItemFactory.create(ItemDefs.potion), 4)
	serverInv:add(ItemFactory.create(ItemDefs.sword), 1)

	local clientInv = InventoryCore.new({ capacity = 6, maxWeight = 40 })
	clientInv:applyState(serverInv:toState()) -- client boots as server replica
	local baseline = NetSync.snapshot(clientInv)

	clientInv:add(ItemFactory.create(ItemDefs.potion), 2) -- client-side edit
	local delta = NetSync.computeDiff(baseline, NetSync.snapshot(clientInv))
	print(("client delta touches %d slot(s); sent to server"):format(#delta.slots))
	serverInv:applyState(NetSync.applyDiff(serverInv:toState(), delta))

	-- Concurrent conflicting edits on the SAME slot (slot 1):
	serverInv:remove("potion", 3)                      -- server edit
	clientInv:add(ItemFactory.create(ItemDefs.potion), 1) -- client edit
	local clientState = clientInv:toState()
	local serverState = serverInv:toState()
	print(("conflict on slot 1: client x%d vs server x%d"):format(
		clientState.slots[1].count, serverState.slots[1].count))

	local mergedServer = NetSync.mergeConflict(clientState, serverState, "server")
	clientInv:applyState(mergedServer) -- reconciliation
	print("server-authoritative merge -> client slot 1 x" .. clientInv:getSlot(1).count .. " (server wins)")

	local mergedLww = NetSync.mergeConflict(clientState, serverState, "lww")
	print("lww merge would pick slot 1 x" .. mergedLww.slots[1].count .. " (higher rev wins; tie -> server)")

	serverInv:recycle()
	clientInv:recycle()
	inv:recycle()
	print("\n-- Example complete.")
end

----------------------------------------------------------------------
-- SECTION 14: entry point + public API
----------------------------------------------------------------------

local Api = {
	Structure          = Structure,
	Utils              = Utils,
	Contracts          = Contracts,
	EventDispatcher    = EventDispatcher,
	ItemFactory        = ItemFactory,
	StackManager       = StackManager,
	InventoryCore      = InventoryCore,
	TransactionManager = TransactionManager,
	StorageAdapters    = StorageAdapters,
	UIAdapterExample   = UIAdapterExample,
	ItemDefs           = ItemDefs,
	setDebug           = function(v) DEBUG = v == true end,
}

--[[
do
	local function main(args)
		local runTests, runExample = true, true
		if type(args) == "table" then
			for i = 1, #args do
				if args[i] == "--no-tests" then
					runTests = false
				elseif args[i] == "--no-example" then
					runExample = false
				end
			end
		end
		print("Inventory system (DEBUG=" .. tostring(DEBUG) .. ")")
		local allOk = true
		if runTests then
			Tests.runAll()
			allOk = Tests.summary()
		end
		if runExample then
			ExampleUsage.run()
		end
		if allOk then
			print("\nRESULT: OK")
			pcall(os.exit, 0) -- best effort; plain Lua 5.1 may ignore the code
		else
			print("\nRESULT: FAIL")
			local exited = pcall(os.exit, 1)
			if not exited then return error("test suite failed", 0) end
		end
	end

	-- Auto-run only when executed directly (`lua inventory.lua`), not when loaded
	-- as a module via require/dofile from a game. Falls back to running if the
	-- host provides no `arg` table at all.
	local globalArg = rawget(_G, "arg")
	local directRun = false
	if type(globalArg) ~= "table" then
		directRun = true
	elseif type(globalArg[0]) == "string" and globalArg[0]:lower():find("inventory", 1, true) then
		directRun = true
	end

	if directRun then
		main(globalArg)
	end
end
--]]

-- Export
return Api
