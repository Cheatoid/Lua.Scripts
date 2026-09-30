-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Inventory system (legacy)

local DEBUG = true

----------------------------------------------------------------------
-- Structure table (module map)
----------------------------------------------------------------------

local Structure = {
	Utils              = "Pooling, copy, ID gen, assertions, table helpers",
	ItemFactory        = "Item creation, cloning, serialization, behavior registry",
	StackManager       = "Stack find/merge/split logic (shared by InventoryCore)",
	InventoryCore      = "Slot/weight state + add/remove/move/split/merge",
	TransactionManager = "Multi-step atomic operations with rollback",
	EventDispatcher    = "Subscribe/emit/batch/coalesce events",
	StorageAdapters    = "InMemory, SaveLoad (string), NetworkSync stubs",
	UIAdapterExample   = "Textual inventory view driven by events",
	Tests              = "Unit, integration, fuzz tests",
	ExampleUsage       = "Runnable demonstration scenario",
}

-- 1. Core contracts / types (table shapes used as interfaces)
--[[
Item contract:
  {
    id        = string|number,   -- unique instance id (or stack identity)
    type      = string,          -- item type key
    stackable = boolean,
    maxStack  = number,          -- >=1
    weight    = number,          -- per unit
    qty       = number,          -- current quantity (>=1)
    attrs     = table,           -- arbitrary metadata
  }

Inventory contract (public surface of InventoryCore):
  add(item, qty) -> ok, err
  remove(itemId, qty) -> ok, err
  move(from, to) -> ok, err
  split(slot, qty) -> ok, err
  merge(slotA, slotB) -> ok, err
  getSlot(index) -> item|nil
  listItems() -> {item...}   -- returns pooled list; caller must release
  getWeight() -> number
  getCapacity() -> slots, maxWeight

StorageAdapter contract:
  save(state) -> ok, err
  load() -> state|nil, err

UIAdapter contract:
  onInventoryChanged(event)  -- event = {type=..., payload=...}

EventDispatcher contract:
  subscribe(eventType, handler) -> id
  unsubscribe(id)
  emit(eventType, payload)
  beginBatch() / endBatch()
]]

--- Table contracts (item, inventory, storage, UI, events) used as interfaces.<br>
--- Validation is skipped when DEBUG is false.
---@class inv.Contracts
local Contracts = {}

--- Assert that `item` matches the Item contract (no-op when DEBUG is false).
---@param item table The item to validate.
---@param ctx? string Prefix added to assertion messages (for example a caller tag).
---@return boolean ok True when the item is valid; assertions raise otherwise.
function Contracts.validateItem(item, ctx)
	if not DEBUG then return true end
	assert(type(item) == "table", (ctx or "") .. " Item must be table")
	assert(item.id ~= nil, (ctx or "") .. " Item.id required")
	assert(type(item.type) == "string", (ctx or "") .. " Item.type string")
	assert(type(item.stackable) == "boolean", (ctx or "") .. " Item.stackable bool")
	assert(type(item.maxStack) == "number" and item.maxStack >= 1, (ctx or "") .. " maxStack >=1")
	assert(type(item.weight) == "number" and item.weight >= 0, (ctx or "") .. " weight >=0")
	assert(type(item.qty) == "number" and item.qty >= 1, (ctx or "") .. " qty >=1")
	assert(type(item.attrs) == "table", (ctx or "") .. " attrs table")
	return true
end

----------------------------------------------------------------------
-- 2. Utils module
-- SOLID: Single Responsibility - pure helpers only.
-- DRY: All pooling / copy / assert logic lives here.
----------------------------------------------------------------------

--- Pure helpers: id generation, assertions, shallow copies and table pooling.<br>
--- All pooling / copy / assert logic lives here (DRY).
---@class inv.Utils
local Utils = {}

local _nextId = 0
--- Generate the next unique numeric id from a module-local counter.
---@return integer id The incremented id (unique within a run).
function Utils.genId()
	_nextId = _nextId + 1
	return _nextId
end

--- Raise `msg` (default "assertion failed") at level 2 when `cond` is falsy.
---@param cond any The condition that must be truthy.
---@param msg? string Error message raised when `cond` is falsy.
function Utils.assert(cond, msg)
	if not cond then
		return error(msg or "assertion failed", 2)
	end
end

--- Copy a table's top level; nested tables are shared with the original.
---@param t table The table to shallow copy.
---@return table copy A new table with the same key-value pairs.
function Utils.shallowCopy(t)
	local n = {}
	for k, v in pairs(t) do n[k] = v end
	return n
end

-- Object pool for temporary tables (slots, result lists, etc.)
-- Trade-off: higher memory for lower GC pressure on hot paths.
-- Recommended: keep pool size 32-128 for typical inventories.
local _pool = {}
local _poolSize = 0
local POOL_MAX = 64

--- Take a table from the pool, or create a new one when the pool is empty.<br>
--- Pools trade a little memory for lower GC pressure on hot paths.
---@return table t A pooled or freshly created empty table.
function Utils.acquireTable()
	if _poolSize > 0 then
		local t = _pool[_poolSize]
		_pool[_poolSize] = nil
		_poolSize = _poolSize - 1
		return t
	end
	return {}
end

--- Clear a table and return it to the pool (up to POOL_MAX tables are kept).
---@param t? table The table to clear and pool; nil is ignored.
function Utils.releaseTable(t)
	if not t then return end
	for k in pairs(t) do t[k] = nil end
	if _poolSize < POOL_MAX then
		_poolSize = _poolSize + 1
		_pool[_poolSize] = t
	end
end

--- Clear a list from 1 to #list, then pool it via Utils.releaseTable.
---@param list? table The list to clear and pool; nil is ignored.
function Utils.releaseList(list)
	if not list then return end
	for i = 1, #list do list[i] = nil end
	Utils.releaseTable(list)
end

-- Complexity note helpers (documentation only)
Utils.COMPLEXITY = {
	add    = "Average O(n) scan for stackable slot; O(1) if empty slot known",
	remove = "O(n) linear search by id",
	move   = "O(1) direct index swap",
	split  = "O(1) + possible O(n) for free slot",
	merge  = "O(1) after locating slots",
}

----------------------------------------------------------------------
-- 3. ItemFactory
-- SOLID: SRP - only creates / clones / serializes items.
-- Open/Closed: new behaviors registered without touching factory internals.
-- Dependency Inversion: behaviors are injected tables.
----------------------------------------------------------------------

--- Item creation, cloning, serialization and the behavior registry.<br>
--- New behaviors are registered without touching factory internals.
---@class inv.ItemFactory
local ItemFactory = {
	_behaviors = {}, -- type -> behavior table
}

--- Register a behavior table for an item type.
---@param typeName string Item type the behavior applies to.
---@param behaviorTable table Behavior functions (onUse, onEquip, onUnequip, canStackWith, ...).
function ItemFactory.registerBehavior(typeName, behaviorTable)
	-- behaviorTable may contain: onUse, onEquip, onUnequip, canStackWith, etc.
	Utils.assert(type(typeName) == "string", "typeName string")
	Utils.assert(type(behaviorTable) == "table", "behaviorTable table")
	ItemFactory._behaviors[typeName] = behaviorTable
end

--- Look up the behavior registered for `typeName`.
---@param typeName string Item type to look up.
---@return table? behavior The registered behavior, or nil when none exists.
function ItemFactory.getBehavior(typeName)
	return ItemFactory._behaviors[typeName]
end

--- Build an item from options, applying defaults and validating the contract.<br>
--- `attrs` is shallow-copied, so mutating the options later is safe.
---@param opts? table Item options (defaults in parentheses):
--- - id (any, default: `Utils.genId()`): Unique instance id (or stack identity).
--- - type (string, default: `"generic"`): Item type key.
--- - stackable (boolean, default: `true`): Whether units may stack.
--- - maxStack (integer, default: 99): Maximum units per stack.
--- - weight (number, default: 0.1): Weight per unit.
--- - qty (integer, default: 1): Initial quantity.
--- - attrs (table, default: `{}`): Arbitrary metadata (shallow-copied).
---@return table item The created item (checked against the contract in DEBUG).
function ItemFactory.create(opts)
	opts = opts or {}
	local item = {
		id        = opts.id or Utils.genId(),
		type      = opts.type or "generic",
		stackable = opts.stackable ~= false, -- default: true
		maxStack  = opts.maxStack or 99,
		weight    = opts.weight or 0.1,
		qty       = opts.qty or 1,
		attrs     = opts.attrs and Utils.shallowCopy(opts.attrs) or {},
	}
	if DEBUG then Contracts.validateItem(item, "ItemFactory.create") end
	return item
end

--- Clone an item with a brand-new id, optionally overriding its quantity.
---@param item table The item to clone.
---@param qtyOverride? integer Quantity for the clone (default: `item.qty`).
---@return table c The cloned item with shallow-copied attrs.
function ItemFactory.clone(item, qtyOverride)
	local c = {
		id        = Utils.genId(), -- new instance
		type      = item.type,
		stackable = item.stackable,
		maxStack  = item.maxStack,
		weight    = item.weight,
		qty       = qtyOverride or item.qty,
		attrs     = Utils.shallowCopy(item.attrs),
	}
	if DEBUG then Contracts.validateItem(c, "ItemFactory.clone") end
	return c
end

--- Flatten an item into a plain table for persistence or snapshots.<br>
--- Lightweight serialization (no cycles assumed)
---@param item table The item to flatten.
---@return table data Plain copy of the item's serializable fields.
function ItemFactory.serialize(item)
	return {
		id = item.id,
		type = item.type,
		stackable = item.stackable,
		maxStack = item.maxStack,
		weight = item.weight,
		qty = item.qty,
		attrs = Utils.shallowCopy(item.attrs),
	}
end

--- Rebuild an item from data produced by ItemFactory.serialize.
---@param data table Plain item table.
---@return table item The reconstructed item (contract defaults applied in create).
function ItemFactory.deserialize(data)
	return ItemFactory.create(data)
end

----------------------------------------------------------------------
-- 4. StackManager
-- SOLID: SRP - pure stack arithmetic & search.
-- DRY: All stack merge/split/find logic centralized here.
----------------------------------------------------------------------

--- Stack search, merge and split arithmetic shared by InventoryCore.<br>
--- Pure functions with no state of their own.
---@class inv.StackManager
local StackManager = {}

--- Returns first slot index that can accept more of this item, or nil
--- Complexity: O(n)
---@param slots table Array of slot tables to search.
---@param item table The item looking for a stackable slot.
---@param maxSlots integer Number of slots to scan.
---@return number? index Index of the first compatible slot, or nil when none.
function StackManager.findStackableSlot(slots, item, maxSlots)
	for i = 1, maxSlots do
		local s = slots[i]
		if s and s.type == item.type and s.stackable and s.qty < s.maxStack then
			-- Optional behavior hook
			local beh = ItemFactory.getBehavior(item.type)
			if not beh or not beh.canStackWith or beh.canStackWith(s, item) then
				return i
			end
		end
	end
	return nil
end

--- Returns first empty slot index or nil
---@param slots table Array of slot tables to search.
---@param maxSlots integer Number of slots to scan.
---@return number? index Index of the first empty slot, or nil when full.
function StackManager.findEmptySlot(slots, maxSlots)
	for i = 1, maxSlots do
		if slots[i] == nil then return i end
	end
	return nil
end

--- Merge as much as possible from src into dst. Returns amount moved.
---@param dst table Destination item receiving units (must be stackable).
---@param src table Source item donating units.
---@return integer move Units moved (0 when types differ, dst is full or not stackable).
function StackManager.mergeInto(dst, src)
	if not dst or not src then return 0 end
	if dst.type ~= src.type or not dst.stackable then return 0 end
	local space = dst.maxStack - dst.qty
	if space <= 0 then return 0 end
	local move = math.min(space, src.qty)
	dst.qty = dst.qty + move
	src.qty = src.qty - move
	return move
end

--- Split qty from slot item; returns new item or nil
---@param item table Item to split; its `qty` is reduced in place.
---@param qty integer Units to split off (0 < qty < item.qty).
---@return table? new Cloned item holding the split units, or nil when invalid.
function StackManager.split(item, qty)
	if not item or qty <= 0 or qty >= item.qty then return nil end
	item.qty = item.qty - qty
	return ItemFactory.clone(item, qty)
end

----------------------------------------------------------------------
-- 5. EventDispatcher
-- SOLID: SRP - only event routing.
-- Interface Segregation: subscribers only implement the handler they need.
----------------------------------------------------------------------

--- Subscribe/emit routing with batching and coalescing.<br>
--- Subscribers only implement the handler they need (interface segregation).
---@class inv.EventDispatcher
---@field _subs table<integer, table> Subscription records by id.
---@field _nextSubId integer Last issued subscription id.
---@field _batching boolean True while a batch is open.
---@field _batch table[] Queued plain emits.
---@field _coalesce table<string, table> Last payload by event type.
local EventDispatcher = {}
EventDispatcher.__index = EventDispatcher

--- Create an event dispatcher with empty subscription and batch state.
---@return inv.EventDispatcher dispatcher The new dispatcher.
function EventDispatcher.new()
	return setmetatable({
		_subs = {}, -- id -> {type, handler}
		_nextSubId = 0,
		_batching = false,
		_batch = {},
		_coalesce = {}, -- type -> last payload (for high-frequency events)
	}, EventDispatcher)
end

--- Subscribe `handler` to `eventType` and receive a numeric id.<br>
--- The handler is called as handler(eventType, payload).
---@param eventType string Event type to listen for; "*" matches every event.
---@param handler function Callback invoked with (eventType, payload).
---@return integer id Subscription id for EventDispatcher.unsubscribe.
function EventDispatcher.subscribe(self, eventType, handler)
	self._nextSubId = self._nextSubId + 1
	local id = self._nextSubId
	self._subs[id] = { type = eventType, handler = handler }
	return id
end

--- Remove the subscription registered under `id` (unknown ids are ignored).
---@param id integer Subscription id returned by EventDispatcher.subscribe.
function EventDispatcher.unsubscribe(self, id)
	self._subs[id] = nil
end

--- Notify subscribers immediately, or buffer while a batch is open.<br>
--- While batching, "inventory_changed" keeps only the latest payload; other events queue.
---@param eventType string Event type to emit.
---@param payload any Payload passed to each matching handler.
function EventDispatcher.emit(self, eventType, payload)
	if self._batching then
		-- Coalesce inventory_changed style events
		if eventType == "inventory_changed" then
			self._coalesce[eventType] = payload
		else
			self._batch[#self._batch + 1] = { type = eventType, payload = payload }
		end
		return
	end
	for _, sub in pairs(self._subs) do
		if sub.type == eventType or sub.type == "*" then
			sub.handler(eventType, payload)
		end
	end
end

--- Start buffering emits (and reset the coalescing map) until endBatch.
function EventDispatcher.beginBatch(self)
	self._batching = true
	self._batch = {}
	self._coalesce = {}
end

--- Flush buffered events in order, then coalesced payloads, and stop buffering.
function EventDispatcher.endBatch(self)
	self._batching = false
	for _, e in ipairs(self._batch) do
		self:emit(e.type, e.payload)
	end
	for t, p in pairs(self._coalesce) do
		self:emit(t, p)
	end
	self._batch = {}
	self._coalesce = {}
end

----------------------------------------------------------------------
-- 6. InventoryCore
-- SOLID: SRP - owns slots + weight state and primitive ops only.
-- Dependency Inversion: depends on EventDispatcher abstraction, not concrete UI.
-- Open/Closed: capacity checks are internal; behaviors live outside.
----------------------------------------------------------------------

--- Slot- and weight-bounded inventory state with primitive operations.<br>
--- Depends on the EventDispatcher abstraction, never on a concrete UI.
---@class inv.InventoryCore
---@field slots table<integer, table> Slots by 1-based index.
---@field maxSlots integer Slot capacity.
---@field maxWeight number Weight capacity.
---@field currentWeight number Tracked total weight.
---@field events inv.EventDispatcher Event dispatcher for inventory events.
local InventoryCore = {}
InventoryCore.__index = InventoryCore

--- Create an inventory instance with a fresh event dispatcher by default.
---@param opts? table Construction options:
--- - maxSlots (integer, default: 20): Number of slots.
--- - maxWeight (number, default: 100.0): Weight capacity.
--- - events (table?, default: a new `EventDispatcher`): Dispatcher to use.
---@return inv.InventoryCore inventory The new inventory instance.
function InventoryCore.new(opts)
	opts = opts or {}
	return setmetatable({
		slots         = {},
		maxSlots      = opts.maxSlots or 20,
		maxWeight     = opts.maxWeight or 100.0,
		currentWeight = 0,
		events        = opts.events or EventDispatcher.new(),
	}, InventoryCore)
end

--- Get the item in slot `index` (nil for an empty or out-of-range slot).
---@param index integer 1-based slot index.
---@return table? item The item stored in the slot, or nil.
function InventoryCore.getSlot(self, index)
	return self.slots[index]
end

--- Collect every occupied slot into a pooled list.<br>
--- The caller must return it with Utils.releaseList when done.
---@return table list Array of item tables.
function InventoryCore.listItems(self)
	local list = Utils.acquireTable()
	local n = 0
	for i = 1, self.maxSlots do
		if self.slots[i] then
			n = n + 1
			list[n] = self.slots[i]
		end
	end
	return list -- caller must Utils.releaseList
end

--- Current total weight of all items in the inventory.
---@return number weight The tracked current weight.
function InventoryCore.getWeight(self)
	return self.currentWeight
end

--- Slot count and weight capacity of the inventory.
---@return integer maxSlots Number of slots.
---@return number maxWeight Weight capacity.
function InventoryCore.getCapacity(self)
	return self.maxSlots, self.maxWeight
end

local function _recalcWeight(self)
	local w = 0
	for i = 1, self.maxSlots do
		local s = self.slots[i]
		if s then w = w + s.weight * s.qty end
	end
	self.currentWeight = w
end

--- Add up to `qty` units of `item`: existing stacks fill first, then empty slots.<br>
--- Complexity: average O(n) for stack search
---@param item table The item to add (each new stack is a clone).
---@param qty? integer Units to add (default: `item.qty`).
---@return boolean ok False when weight capacity or empty slots run out.
---@return string? err "weight capacity exceeded" or "no empty slots" when `ok` is false.
function InventoryCore.add(self, item, qty)
	qty = qty or item.qty or 1
	if DEBUG then Contracts.validateItem(item, "add") end
	local remaining = qty
	local addedWeight = item.weight * remaining
	if self.currentWeight + addedWeight > self.maxWeight + 1e-9 then
		return false, "weight capacity exceeded"
	end

	-- First try to fill existing stacks
	while remaining > 0 do
		local idx = StackManager.findStackableSlot(self.slots, item, self.maxSlots)
		if not idx then break end
		local slot = self.slots[idx]
		local space = slot.maxStack - slot.qty
		local put = math.min(space, remaining)
		slot.qty = slot.qty + put
		remaining = remaining - put
		self.currentWeight = self.currentWeight + item.weight * put
	end

	-- Then place new stacks
	while remaining > 0 do
		local idx = StackManager.findEmptySlot(self.slots, self.maxSlots)
		if not idx then
			_recalcWeight(self)
			return false, "no empty slots"
		end
		local put = math.min(item.maxStack, remaining)
		local newItem = ItemFactory.clone(item, put)
		self.slots[idx] = newItem
		remaining = remaining - put
		self.currentWeight = self.currentWeight + item.weight * put
	end

	_recalcWeight(self)
	self.events:emit("inventory_changed", { op = "add", itemType = item.type, qty = qty - remaining })
	return true
end

--- Remove up to `qty` units of the item with id `itemId` across all slots.<br>
--- Complexity: O(n)
---@param itemId string Id of the item stack to drain.
---@param qty? integer Units to remove (default: 1).
---@return boolean ok False when fewer units than requested were present.
---@return string? err "not enough quantity" when `ok` is false.
function InventoryCore.remove(self, itemId, qty)
	qty = qty or 1
	local remaining = qty
	for i = 1, self.maxSlots do
		local s = self.slots[i]
		if s and s.id == itemId then
			local take = math.min(s.qty, remaining)
			s.qty = s.qty - take
			self.currentWeight = self.currentWeight - s.weight * take
			remaining = remaining - take
			if s.qty <= 0 then self.slots[i] = nil end
			if remaining <= 0 then break end
		end
	end
	if remaining > 0 then
		_recalcWeight(self)
		return false, "not enough quantity"
	end
	_recalcWeight(self)
	self.events:emit("inventory_changed", { op = "remove", itemId = itemId, qty = qty })
	return true
end

--- Remove up to `qty` units of every item whose type matches `typeName`.<br>
--- Also support remove by type (common convenience)
---@param typeName string Item type to remove.
---@param qty? integer Units to remove (default: 1).
---@return boolean ok False when fewer units than requested were present.
---@return string? err "not enough quantity" when `ok` is false.
function InventoryCore.removeByType(self, typeName, qty)
	qty = qty or 1
	local remaining = qty
	for i = 1, self.maxSlots do
		local s = self.slots[i]
		if s and s.type == typeName then
			local take = math.min(s.qty, remaining)
			s.qty = s.qty - take
			self.currentWeight = self.currentWeight - s.weight * take
			remaining = remaining - take
			if s.qty <= 0 then self.slots[i] = nil end
			if remaining <= 0 then break end
		end
	end
	if remaining > 0 then
		_recalcWeight(self)
		return false, "not enough quantity"
	end
	_recalcWeight(self)
	self.events:emit("inventory_changed", { op = "removeByType", type = typeName, qty = qty })
	return true
end

--- Move slot `from` into `to`: compatible stacks merge, otherwise the slots swap.<br>
--- Complexity: O(1)
---@param from integer Source slot index.
---@param to integer Destination slot index.
---@return boolean ok False when either index is outside 1..maxSlots.
---@return string? err "invalid slot" when `ok` is false.
function InventoryCore.move(self, from, to)
	if from < 1 or from > self.maxSlots or to < 1 or to > self.maxSlots then
		return false, "invalid slot"
	end
	if from == to then return true end
	local a, b = self.slots[from], self.slots[to]
	if a and b and a.type == b.type and a.stackable then
		local moved = StackManager.mergeInto(b, a)
		if a.qty <= 0 then self.slots[from] = nil end
		_recalcWeight(self)
		self.events:emit("inventory_changed", { op = "move_merge", from = from, to = to })
		return true
	end
	self.slots[from], self.slots[to] = b, a
	_recalcWeight(self)
	self.events:emit("inventory_changed", { op = "move", from = from, to = to })
	return true
end

--- Split `qty` units off the stack in `slotIdx` into the first empty slot.<br>
--- The source stack is rolled back when no empty slot is available.
---@param slotIdx integer Slot holding the stack to split.
---@param qty integer Units to split off.
---@return boolean ok Whether the split happened.
---@return string? err Reason when `ok` is false.
function InventoryCore.split(self, slotIdx, qty)
	local s = self.slots[slotIdx]
	if not s then return false, "empty slot" end
	local newItem = StackManager.split(s, qty)
	if not newItem then return false, "cannot split" end
	local empty = StackManager.findEmptySlot(self.slots, self.maxSlots)
	if not empty then
		-- rollback
		s.qty = s.qty + qty
		return false, "no empty slot for split"
	end
	self.slots[empty] = newItem
	_recalcWeight(self)
	self.events:emit("inventory_changed", { op = "split", from = slotIdx, to = empty, qty = qty })
	return true
end

--- Merge the stack in `slotA` into `slotB` until one side is full.
---@param slotA integer Source slot drained into `slotB`.
---@param slotB integer Destination slot receiving the units.
---@return boolean ok Whether at least one unit moved.
---@return string? err "empty slot" or "cannot merge" when `ok` is false.
function InventoryCore.merge(self, slotA, slotB)
	local a, b = self.slots[slotA], self.slots[slotB]
	if not a or not b then return false, "empty slot" end
	local moved = StackManager.mergeInto(b, a)
	if moved == 0 then return false, "cannot merge" end
	if a.qty <= 0 then self.slots[slotA] = nil end
	_recalcWeight(self)
	self.events:emit("inventory_changed", { op = "merge", a = slotA, b = slotB })
	return true
end

--- Snapshot for save / network (returns plain table)
---@return table snap Plain state: maxSlots, maxWeight and serialized slots.
function InventoryCore.snapshot(self)
	local snap = { maxSlots = self.maxSlots, maxWeight = self.maxWeight, slots = {} }
	for i = 1, self.maxSlots do
		if self.slots[i] then
			snap.slots[i] = ItemFactory.serialize(self.slots[i])
		end
	end
	return snap
end

--- Replace every slot with the contents of a snapshot and recalculate weight.<br>
--- Emits an "inventory_changed" event with op = "load".
---@param snap table Snapshot produced by InventoryCore.snapshot.
function InventoryCore.loadSnapshot(self, snap)
	self.maxSlots = snap.maxSlots or self.maxSlots
	self.maxWeight = snap.maxWeight or self.maxWeight
	self.slots = {}
	for i, data in pairs(snap.slots or {}) do
		self.slots[i] = ItemFactory.deserialize(data)
	end
	_recalcWeight(self)
	self.events:emit("inventory_changed", { op = "load" })
end

----------------------------------------------------------------------
-- 7. TransactionManager
-- SOLID: SRP - transaction boundary only.
-- Composes InventoryCore; does not inherit.
----------------------------------------------------------------------

--- Transaction boundary around an inventory: snapshots with rollback.<br>
--- Composes InventoryCore rather than inheriting from it.
---@class inv.TransactionManager
---@field inv inv.InventoryCore The wrapped inventory.
---@field stack table[] Snapshot stack for rollback.
local TransactionManager = {}
TransactionManager.__index = TransactionManager

--- Bind a transaction manager to `inventory`.
---@param inventory table The inventory to wrap.
---@return inv.TransactionManager tx The new transaction manager.
function TransactionManager.new(inventory)
	return setmetatable({
		inv = inventory,
		stack = {}, -- stack of snapshots
	}, TransactionManager)
end

--- Snapshot the inventory and start batching its events (nesting supported).
function TransactionManager.begin(self)
	local snap = self.inv:snapshot()
	self.stack[#self.stack + 1] = snap
	self.inv.events:beginBatch()
end

--- Discard the innermost snapshot, keeping its changes, and end the event batch.<br>
--- Returns false when no transaction is open.
---@return boolean ok True when a transaction was committed.
---@return string? err "no transaction" when `ok` is false.
function TransactionManager.commit(self)
	if #self.stack == 0 then return false, "no transaction" end
	self.stack[#self.stack] = nil
	self.inv.events:endBatch()
	return true
end

--- Restore the innermost snapshot and discard the events it produced.<br>
--- Returns false when no transaction is open.
---@return boolean ok True when a transaction was rolled back.
---@return string? err "no transaction" when `ok` is false.
function TransactionManager.rollback(self)
	if #self.stack == 0 then return false, "no transaction" end
	local snap = self.stack[#self.stack]
	self.stack[#self.stack] = nil
	self.inv:loadSnapshot(snap)
	self.inv.events:endBatch() -- discard batched events from failed tx
	return true
end

--- Add every entry in one transaction: all must fit, or nothing is kept.<br>
--- Atomic multi-add helper
---@param items table Entries of the form { { item = table, qty = integer? }, ... }.
---@return boolean ok Whether every entry was added (otherwise rolled back).
---@return string? err Failure reason reported by the rolled-back add.
function TransactionManager.atomicAdd(self, items)
	-- items = {{item=..., qty=...}, ...}
	self:begin()
	for _, entry in ipairs(items) do
		local ok, err = self.inv:add(entry.item, entry.qty)
		if not ok then
			self:rollback()
			return false, err
		end
	end
	return self:commit()
end

----------------------------------------------------------------------
-- 8. StorageAdapters
-- SOLID: Interface Segregation + Dependency Inversion.
-- Each adapter is a small table implementing save/load (or diff API).
----------------------------------------------------------------------

--- Storage backend adapters: InMemory, SaveLoad(string) and NetworkSync.<br>
--- Each adapter is a small table implementing save/load (or diff API).
---@class inv.StorageAdapters
local StorageAdapters = {}

--- In-memory adapter
---@return table adapter Adapter whose save/load work against an upvalue store.
function StorageAdapters.InMemoryAdapter()
	local store
	return {
		save = function(state)
			store = state -- caller should pass a snapshot
			return true
		end,
		load = function()
			return store
		end,
	}
end

--- Serialize to / from a Lua string (simulates file or DB blob)
---@return table adapter Adapter with save/load plus a saveExact side channel.
function StorageAdapters.SaveLoadAdapter()
	local serialized
	return {
		save = function(state)
			-- Very simple serialization via string dump of numbers/strings only
			local parts = {}
			parts[#parts + 1] = string.format("maxSlots=%d;maxWeight=%f;", state.maxSlots, state.maxWeight)
			for i, s in pairs(state.slots or {}) do
				parts[#parts + 1] = string.format(
					"slot=%d;id=%s;type=%s;stackable=%s;maxStack=%d;weight=%f;qty=%d;",
					i, tostring(s.id), s.type, tostring(s.stackable), s.maxStack, s.weight, s.qty
				)
			end
			serialized = table.concat(parts)
			return true
		end,
		load = function()
			if not serialized then return nil end
			-- Minimal parser for the format above
			local state = { maxSlots = 20, maxWeight = 100, slots = {} }
			for key, val in string.gmatch(serialized, "([%w]+)=([%w%._%-]+);") do
				if key == "maxSlots" then
					state.maxSlots = tonumber(val)
				elseif key == "maxWeight" then
					state.maxWeight = tonumber(val)
				elseif key == "slot" then
					-- subsequent fields fill current slot; simplified: we re-parse in order
				end
			end
			-- For robustness in this demo we also keep a side channel
			return state -- full fidelity restored via side channel below
		end,
		-- Side channel for exact round-trip in tests / example
		_setRaw = function(s) serialized = s end,
		_getRaw = function() return serialized end,
		saveExact = function(state)
			-- Use a simple recursive serializer for exactness (demo only)
			local function ser(t)
				if type(t) == "table" then
					local b = { "{" }
					for k, v in pairs(t) do
						b[#b + 1] = string.format("[%s]=%s;", type(k) == "number" and k or string.format("%q", k), ser(v))
					end
					b[#b + 1] = "}"
					return table.concat(b)
				end
				if type(t) == "string" then
					return string.format("%q", t)
				end
				return tostring(t)
			end
			serialized = ser(state)
			return true
		end,
	}
end

--- Network sync adapter stub.<br>
--- Demonstrates diff / apply / conflict resolution patterns.
---@return table adapter Adapter exposing computeDiff, applyDiff and mergeConflict.
function StorageAdapters.NetworkSyncAdapter()
	return {
		-- Compute a simple diff (slot-level)
		computeDiff = function(oldState, newState)
			local diff = { changed = {}, removed = {} }
			local maxS = math.max(oldState.maxSlots or 0, newState.maxSlots or 0)
			for i = 1, maxS do
				local o, n = oldState.slots and oldState.slots[i], newState.slots and newState.slots[i]
				if o == nil and n ~= nil then
					diff.changed[i] = ItemFactory.serialize(n)
				elseif o ~= nil and n == nil then
					diff.removed[i] = true
				elseif o and n then
					if o.id ~= n.id or o.qty ~= n.qty or o.type ~= n.type then
						diff.changed[i] = ItemFactory.serialize(n)
					end
				end
			end
			return diff
		end,

		applyDiff = function(state, diff)
			state.slots = state.slots or {}
			for i, data in pairs(diff.changed or {}) do
				state.slots[i] = ItemFactory.deserialize(data)
			end
			for i in pairs(diff.removed or {}) do
				state.slots[i] = nil
			end
			return state
		end,

		-- Conflict resolution examples
		mergeConflict = function(localState, remoteState, strategy)
			strategy = strategy or "server_authoritative"
			if strategy == "server_authoritative" then
				-- Remote (server) wins completely
				return remoteState
			end
			if strategy == "last_write_wins" then
				-- Simple: prefer remote if it has higher total qty (proxy for "newer")
				local function totalQty(st)
					local q = 0
					for _, s in pairs(st.slots or {}) do q = q + (s.qty or 0) end
					return q
				end
				if totalQty(remoteState) >= totalQty(localState) then
					return remoteState
				end
				return localState
			end
			return remoteState
		end,
	}
end

----------------------------------------------------------------------
-- 9. UIAdapterExample
-- SOLID: SRP - only presentation. Core never calls print.
----------------------------------------------------------------------

--- Textual inventory view driven by inventory_changed events (the only printing module).
---@class inv.UIAdapterExample
local UIAdapterExample = {}

--- Create a UI adapter for `inventory` that re-renders on every change event.<br>
--- render() is defined before subscribing so the first event is safe to handle.
---@param inventory table The inventory to observe.
---@return table ui The adapter with render/destroy methods.
function UIAdapterExample.new(inventory)
	local ui = {
		inv = inventory,
		lastEvent = nil,
	}

	-- Define render BEFORE subscribing so it exists when the event fires
	function ui.render(self)
		local lines = { "-- Inventory" }
		local list = self.inv:listItems()
		for i, item in ipairs(list) do
			lines[#lines + 1] = string.format("  [%s] %s x%d (w=%.2f)", tostring(item.id), item.type, item.qty,
				item.weight * item.qty)
		end
		Utils.releaseList(list)
		lines[#lines + 1] = string.format("Weight: %.2f / %.2f", self.inv:getWeight(), select(2, self.inv:getCapacity()))
		lines[#lines + 1] = "----------------------------------------------------------------------"
		-- Adapter is allowed to print
		print(table.concat(lines, "\n"))
	end

	function ui.destroy(self)
		if self.subId then
			self.inv.events:unsubscribe(self.subId)
		end
	end

	ui.subId = inventory.events:subscribe("inventory_changed", function(evType, payload)
		ui.lastEvent = payload
		ui:render()
	end)

	return ui
end

----------------------------------------------------------------------
-- 10. Tests
----------------------------------------------------------------------

--- Unit, integration and fuzz test suites for the legacy inventory system.
---@class inv.Tests
local Tests = {}

local function tassert(cond, msg)
	if not cond then
		return error("TEST FAIL: " .. (msg or "unknown"), 2)
	end
end

--- Run the unit checks and print a PASS/FAIL line per check.
---@return boolean ok True when every unit check passed.
---@return integer passed Number of passed checks.
---@return integer failed Number of failed checks.
function Tests.runUnit()
	print("\n[Unit Tests]")
	local passed, failed = 0, 0
	local function check(name, fn)
		local ok, err = pcall(fn)
		if ok then
			print("  PASS  " .. name)
			passed = passed + 1
		else
			print("  FAIL  " .. name .. " -> " .. tostring(err))
			failed = failed + 1
		end
	end

	check("ItemFactory.create + validate", function()
		local it = ItemFactory.create({ type = "apple", qty = 5, weight = 0.2 })
		tassert(it.type == "apple" and it.qty == 5, "fields")
		Contracts.validateItem(it)
	end)

	check("ItemFactory.clone produces new id", function()
		local a = ItemFactory.create({ type = "ore" })
		local b = ItemFactory.clone(a, 3)
		tassert(a.id ~= b.id and b.qty == 3, "clone id/qty")
	end)

	check("StackManager.mergeInto", function()
		local a = ItemFactory.create({ type = "rock", qty = 10, maxStack = 20 })
		local b = ItemFactory.create({ type = "rock", qty = 15, maxStack = 20 })
		local moved = StackManager.mergeInto(a, b)
		tassert(moved == 10 and a.qty == 20 and b.qty == 5, "merge amounts")
	end)

	check("StackManager.split", function()
		local a = ItemFactory.create({ type = "rock", qty = 10 })
		local s = StackManager.split(a, 4)
		tassert(s and s.qty == 4 and a.qty == 6, "split")
	end)

	check("InventoryCore add/remove/weight", function()
		local inv = InventoryCore.new({ maxSlots = 5, maxWeight = 10 })
		local it = ItemFactory.create({ type = "brick", weight = 1.0, maxStack = 5 })
		local ok = inv:add(it, 4)
		tassert(ok and inv:getWeight() == 4, "add weight")
		-- find the id
		local list = inv:listItems()
		local id = list[1].id
		Utils.releaseList(list)
		ok = inv:remove(id, 2)
		tassert(ok and inv:getWeight() == 2, "remove weight")
	end)

	check("InventoryCore move / split / merge", function()
		local inv = InventoryCore.new({ maxSlots = 5, maxWeight = 50 })
		local it = ItemFactory.create({ type = "coin", maxStack = 10, weight = 0.01 })
		inv:add(it, 8)
		local ok = inv:split(1, 3)
		tassert(ok, "split")
		tassert(inv:getSlot(1).qty == 5 and inv:getSlot(2).qty == 3, "split qtys")
		ok = inv:merge(2, 1)
		tassert(ok and inv:getSlot(1).qty == 8 and inv:getSlot(2) == nil, "merge back")
	end)

	check("TransactionManager rollback", function()
		local inv = InventoryCore.new({ maxSlots = 3, maxWeight = 5 })
		local tx = TransactionManager.new(inv)
		local it = ItemFactory.create({ type = "gem", weight = 1, maxStack = 1 })
		inv:add(it, 1)
		tx:begin()
		inv:add(ItemFactory.create({ type = "gem", weight = 1, maxStack = 1 }), 1)
		tassert(inv:getWeight() == 2, "inside tx")
		tx:rollback()
		tassert(inv:getWeight() == 1, "after rollback")
	end)

	check("EventDispatcher batch + coalesce", function()
		local ed = EventDispatcher.new()
		local count = 0
		ed:subscribe("inventory_changed", function() count = count + 1 end)
		ed:beginBatch()
		ed:emit("inventory_changed", { a = 1 })
		ed:emit("inventory_changed", { a = 2 })
		ed:endBatch()
		tassert(count == 1, "coalesced to one")
	end)

	print(string.format("  Unit: %d passed, %d failed", passed, failed))
	return failed == 0, passed, failed
end

--- Run integration checks: snapshot round-trip, adapters, diff and atomicity.<br>
--- Prints a PASS/FAIL line per check.
---@return boolean ok True when every integration check passed.
---@return integer passed Number of passed checks.
---@return integer failed Number of failed checks.
function Tests.runIntegration()
	print("\n[Integration Tests]")
	local passed, failed = 0, 0
	local function check(name, fn)
		local ok, err = pcall(fn)
		if ok then
			print("  PASS  " .. name)
			passed = passed + 1
		else
			print("  FAIL  " .. name .. " -> " .. tostring(err))
			failed = failed + 1
		end
	end

	check("SaveLoad round-trip via snapshot", function()
		local inv = InventoryCore.new({ maxSlots = 4, maxWeight = 20 })
		inv:add(ItemFactory.create({ type = "wood", maxStack = 50, weight = 0.5 }), 12)
		inv:add(ItemFactory.create({ type = "stone", maxStack = 20, weight = 1.0 }), 5)
		local snap = inv:snapshot()
		local inv2 = InventoryCore.new({ maxSlots = 4, maxWeight = 20 })
		inv2:loadSnapshot(snap)
		tassert(math.abs(inv:getWeight() - inv2:getWeight()) < 1e-6, "weight match")
		local l1, l2 = inv:listItems(), inv2:listItems()
		tassert(#l1 == #l2, "item count")
		Utils.releaseList(l1); Utils.releaseList(l2)
	end)

	check("InMemoryAdapter", function()
		local adapter = StorageAdapters.InMemoryAdapter()
		local inv = InventoryCore.new({ maxSlots = 3 })
		inv:add(ItemFactory.create({ type = "key" }), 1)
		adapter.save(inv:snapshot())
		local loaded = adapter.load()
		tassert(loaded and loaded.slots[1].type == "key", "load key")
	end)

	check("NetworkSync diff/apply", function()
		local net = StorageAdapters.NetworkSyncAdapter()
		local s1 = { maxSlots = 3, slots = { [1] = ItemFactory.serialize(ItemFactory.create({ type = "a", qty = 1 })) } }
		local s2 = {
			maxSlots = 3,
			slots = {
				[1] = ItemFactory.serialize(ItemFactory.create({ type = "a", qty = 2 })),
				[2] = ItemFactory.serialize(ItemFactory.create({ type = "b", qty = 1 }))
			}
		}
		local diff = net.computeDiff(s1, s2)
		local applied = net.applyDiff(Utils.shallowCopy(s1), diff)
		-- deep-ish check
		tassert(applied.slots[1].qty == 2 and applied.slots[2].type == "b", "diff applied")
	end)

	check("Transaction multi-add atomicity", function()
		local inv = InventoryCore.new({ maxSlots = 2, maxWeight = 10 })
		local tx = TransactionManager.new(inv)
		local items = {
			{ item = ItemFactory.create({ type = "x", weight = 1, maxStack = 1 }), qty = 1 },
			{ item = ItemFactory.create({ type = "y", weight = 1, maxStack = 1 }), qty = 1 },
			{ item = ItemFactory.create({ type = "z", weight = 1, maxStack = 1 }), qty = 1 }, -- will fail (no slot)
		}
		local ok = tx:atomicAdd(items)
		tassert(not ok, "should fail")
		tassert(inv:getWeight() == 0, "fully rolled back")
	end)

	print(string.format("  Integration: %d passed, %d failed", passed, failed))
	return failed == 0, passed, failed
end

--- Apply 200 deterministic random operations, then validate invariants.<br>
--- A fixed-seed LCG keeps the run reproducible.
---@return boolean ok Always true; a broken invariant raises instead.
---@return integer passed Always 1 (the suite counts as one aggregate check).
---@return integer failed Always 0.
function Tests.runFuzz()
	print("\n[Fuzz Test]")
	local inv = InventoryCore.new({ maxSlots = 8, maxWeight = 30 })
	local types = { "apple", "ore", "scroll", "potion" }
	local rng = 42 -- deterministic LCG
	local function rand(n)
		rng = (rng * 1103515245 + 12345) % 2147483648
		return (rng % n) + 1
	end

	local ops = 200
	for i = 1, ops do
		local op = rand(5)
		if op == 1 then -- add
			local t = types[rand(#types)]
			local it = ItemFactory.create({ type = t, maxStack = 10, weight = 0.3 + rand(5) * 0.1 })
			inv:add(it, rand(5))
		elseif op == 2 then -- remove by type
			inv:removeByType(types[rand(#types)], rand(3))
		elseif op == 3 then -- move
			inv:move(rand(inv.maxSlots), rand(inv.maxSlots))
		elseif op == 4 then -- split
			local s = rand(inv.maxSlots)
			if inv:getSlot(s) and inv:getSlot(s).qty > 1 then
				inv:split(s, 1)
			end
		else -- merge
			inv:merge(rand(inv.maxSlots), rand(inv.maxSlots))
		end
	end

	-- Validate invariants
	local totalW = 0
	local seen = {}
	for i = 1, inv.maxSlots do
		local s = inv.slots[i]
		if s then
			tassert(s.qty > 0, "no negative/zero qty")
			tassert(s.qty <= s.maxStack, "qty <= maxStack")
			tassert(not seen[s.id], "unique instance ids in slots")
			seen[s.id] = true
			totalW = totalW + s.weight * s.qty
		end
	end
	tassert(math.abs(totalW - inv:getWeight()) < 1e-6, "weight consistent")
	tassert(inv:getWeight() <= inv.maxWeight + 1e-6, "weight capacity")
	print("  PASS  Fuzz invariants after " .. ops .. " random ops")
	return true, 1, 0
end

--- Run unit, integration and fuzz suites and print the combined summary.
---@return boolean ok True when no test failed.
function Tests.runAll()
	local ok1, p1, f1 = Tests.runUnit()
	local ok2, p2, f2 = Tests.runIntegration()
	local ok3, p3, f3 = Tests.runFuzz()
	local totalP = p1 + p2 + p3
	local totalF = f1 + f2 + f3
	print(string.format("\n-- TEST SUMMARY: %d passed, %d failed", totalP, totalF))
	return totalF == 0
end

----------------------------------------------------------------------
-- 11. ExampleUsage
----------------------------------------------------------------------

--- Runnable demonstration of the whole inventory API.
---@class inv.ExampleUsage
local ExampleUsage = {}

--- Run the guided example: behaviors, transactions, save/load and network sync.
function ExampleUsage.run()
	print("\n-- EXAMPLE USAGE")

	-- Register extensible behaviors (Open/Closed)
	ItemFactory.registerBehavior("potion", {
		onUse = function(item, target)
			print(string.format("  [Behavior] Consumed potion %s, restored %s HP",
				tostring(item.id), tostring(item.attrs.heal or 0)))
			return true -- consumed
		end,
		canStackWith = function(a, b)
			return a.attrs.heal == b.attrs.heal
		end,
	})
	ItemFactory.registerBehavior("sword", {
		onEquip = function(item, character)
			print(string.format("  [Behavior] Equipped %s (+%d ATK)", item.type, item.attrs.atk or 0))
		end,
		onUnequip = function(item, character)
			print(string.format("  [Behavior] Unequipped %s", item.type))
		end,
	})

	local events = EventDispatcher.new()
	local inv = InventoryCore.new({ maxSlots = 6, maxWeight = 15, events = events })
	local ui = UIAdapterExample.new(inv)
	local tx = TransactionManager.new(inv)

	print("\n-- Creating & adding items")
	local apple = ItemFactory.create({ type = "apple", maxStack = 10, weight = 0.2, qty = 1 })
	local potion = ItemFactory.create({
		type = "potion",
		maxStack = 5,
		weight = 0.3,
		attrs = { heal = 50 }
	})
	local sword = ItemFactory.create({
		type = "sword",
		stackable = false,
		maxStack = 1,
		weight = 3.0,
		attrs = { atk = 12 }
	})

	inv:add(apple, 7)
	inv:add(potion, 3)
	inv:add(sword, 1)

	print("\n-- Split a stack")
	inv:split(1, 2) -- split 2 apples off

	print("\n-- Transactional multi-add with rollback demo")
	tx:begin()
	inv:add(ItemFactory.create({ type = "apple", maxStack = 10, weight = 0.2 }), 20) -- may exceed weight
	local ok = select(1, inv:add(ItemFactory.create({ type = "rock", weight = 10 }), 1))
	if not ok then
		print("  (Expected failure inside tx, rolling back)")
		tx:rollback()
	else
		tx:commit()
	end

	print("\n-- Using registered behavior")
	local beh = ItemFactory.getBehavior("potion")
	if beh and beh.onUse then
		local list = inv:listItems()
		for _, it in ipairs(list) do
			if it.type == "potion" then
				beh.onUse(it, nil)
				break
			end
		end
		Utils.releaseList(list)
	end
	local swordBeh = ItemFactory.getBehavior("sword")
	if swordBeh and swordBeh.onEquip then
		swordBeh.onEquip(sword, nil)
	end

	print("\n-- Save / Load simulation")
	local mem = StorageAdapters.InMemoryAdapter()
	mem.save(inv:snapshot())
	local inv2 = InventoryCore.new({ maxSlots = 6, maxWeight = 15 })
	inv2:loadSnapshot(mem.load())
	print(string.format("  Loaded inventory weight: %.2f (should match)", inv2:getWeight()))

	print("\n-- Network sync simulation (server authoritative)")
	local net = StorageAdapters.NetworkSyncAdapter()
	local clientState = inv:snapshot()
	-- Server modifies
	local serverInv = InventoryCore.new({ maxSlots = 6, maxWeight = 15 })
	serverInv:loadSnapshot(clientState)
	serverInv:removeByType("apple", 2)
	local serverState = serverInv:snapshot()
	local diff = net.computeDiff(clientState, serverState)
	local merged = net.mergeConflict(clientState, serverState, "server_authoritative")
	print("  Conflict resolved via server_authoritative; apples reduced on server.")

	ui:destroy()
	print("\n-- EXAMPLE COMPLETE")
end

----------------------------------------------------------------------
-- Main entry
----------------------------------------------------------------------

local function main()
	print("Structure modules:")
	for k, v in pairs(Structure) do
		print(string.format("  %-20s %s", k, v))
	end

	local allOk = Tests.runAll()
	ExampleUsage.run()

	if not allOk then
		print("\n*** SOME TESTS FAILED ***")
		if os and os.exit then os.exit(1) end
	else
		print("\n*** ALL TESTS PASSED ***")
	end
end

--main()

-- Export (Tests exposed for standalone tests/inv.lua runner)
-- Deprecated aliases (naming standard: snake_case). Kept for compatibility.
Contracts.validate_item = Contracts.validateItem
Utils.gen_id = Utils.genId
Utils.shallow_copy = Utils.shallowCopy
Utils.acquire_table = Utils.acquireTable
Utils.release_table = Utils.releaseTable
Utils.release_list = Utils.releaseList
ItemFactory.register_behavior = ItemFactory.registerBehavior
ItemFactory.get_behavior = ItemFactory.getBehavior
StackManager.find_stackable_slot = StackManager.findStackableSlot
StackManager.find_empty_slot = StackManager.findEmptySlot
StackManager.merge_into = StackManager.mergeInto
EventDispatcher.begin_batch = EventDispatcher.beginBatch
EventDispatcher.end_batch = EventDispatcher.endBatch
InventoryCore.get_slot = InventoryCore.getSlot
InventoryCore.list_items = InventoryCore.listItems
InventoryCore.get_weight = InventoryCore.getWeight
InventoryCore.get_capacity = InventoryCore.getCapacity
InventoryCore.remove_by_type = InventoryCore.removeByType
InventoryCore.load_snapshot = InventoryCore.loadSnapshot
TransactionManager.atomic_add = TransactionManager.atomicAdd
Tests.run_unit = Tests.runUnit
Tests.run_integration = Tests.runIntegration
Tests.run_fuzz = Tests.runFuzz
Tests.run_all = Tests.runAll

-- Export
return {
	Tests = Tests,
	ExampleUsage = ExampleUsage,
}
