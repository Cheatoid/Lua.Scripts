-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Advanced inventory system

-- Localized global functions for better performance
local error = error
local next = next
local pcall = pcall
local tonumber = tonumber
local tostring = tostring
local type = type
local math_abs = math.abs
local math_floor = math.floor
local math_huge = math.huge
local math_max = math.max
local math_min = math.min
local math_random = math.random
local string_format = string.format
local string_gmatch = string.gmatch
local string_match = string.match
local string_sub = string.sub
local table_concat = table.concat
local table_insert = table.insert
local table_remove = table.remove
local table_sort = table.sort

-- Flag enabling runtime contract checks and verbose assertions.
local DEBUG = true

-- Top-level structure overview (documentation table).
local Structure = {
	Utils              = "pooling, copies, id generator, assertions",
	Contracts          = "table-shape contracts + runtime validation",
	ItemFactory        = "item creation, cloning, serialization, behaviors",
	StackManager       = "pure stacking algorithms shared by core (DRY)",
	InventoryCore      = "slot/weight bounded inventory state & ops",
	TransactionManager = "atomic multi-step ops with snapshot rollback",
	EventDispatcher    = "subscribe/emit with batching and coalescing",
	StorageAdapters    = "InMemory, SaveLoad(string), NetworkSync stubs",
	UIAdapterExample   = "textual view adapter (no core I/O)",
	Tests              = "unit + integration + deterministic fuzz tests",
	ExampleUsage       = "end-to-end demo with sync reconciliation",
}

----------------------------------------------------------------------
-- Utils
----------------------------------------------------------------------
local Utils = {}

---@param cond boolean The condition to check.
---@param msg? string Optional error message (default: "assertion failed").
---@return boolean boolean The condition value (if truthy).
---@usage <br>
--- ```
--- Utils.assert(1 == 1, "should not error") -- returns true
--- Utils.assert(false, "will error") -- raises error
--- ```
function Utils.assert(cond, msg)
	if not cond then
		return error("[Inventory Assert] " .. (msg or "assertion failed"), 2)
	end
	return cond
end

---@param t table The table to shallow copy.
---@return table table A new table with the same key-value pairs.
---@usage <br>
--- ```
--- local original = { a = 1, b = 2 }
--- local copy = Utils.shallowCopy(original)
--- copy.a = 99
--- print(original.a) -- 1 (unchanged)
--- ```
function Utils.shallowCopy(t)
	local out = {}
	for k, v in next, t do out[k] = v end
	return out
end

---@param t table The table to copy (table values are shallow copied).
---@return table table A new table with table values shallow copied.
---@usage <br>
--- ```
--- local original = { a = 1, b = { c = 2 } }
--- local copy = Utils.copyMeta(original)
--- copy.b.c = 99
--- print(original.b.c) -- 2 (unchanged)
--- ```
function Utils.copyMeta(t)
	local out = {}
	for k, v in next, t do
		if type(v) == "table" then
			out[k] = Utils.shallowCopy(v)
		else
			out[k] = v
		end
	end
	return out
end

---@param start? number Starting ID value (default: 1).
---@return function generator A function that returns the next ID on each call.
---@usage <br>
--- ```
--- local nextId = Utils.newIdGenerator(100)
--- print(nextId()) -- 100
--- print(nextId()) -- 101
--- ```
function Utils.newIdGenerator(start)
	local n = start or 1
	return function()
		local id = n
		n = n + 1
		return id
	end
end

-- Object pool: reuse frequently allocated tables to reduce GC
local Pool      = {}
Pool.__index    = nil

Pool.categories = {}
Pool.config     = {}
Pool.defaultMax = 32

---@param category string The pool category name.
---@param max number Maximum number of tables to keep in the pool.
---@usage <br>
--- ```
--- Pool.configure("custom", 100) -- set max 100 for "custom" pool
--- ```
function Pool.configure(category, max)
	Pool.config[category] = max
	Pool.categories[category] = Pool.categories[category] or {}
end

-- Acquire a table from pool, or create a new one
---@param category string The pool category to acquire from.
---@return table table A table from the pool (or a new empty table).
---@usage <br>
--- ```
--- local t = Pool.acquire("slot")
--- t.item = someItem
--- t.qty = 1
--- ```
function Pool.acquire(category)
	local list = Pool.categories[category]
	if list and #list > 0 then
		return table_remove(list, #list)
	end
	return {}
end

-- Release a table back to its pool after clearing it
---@param category string The pool category to release to.
---@param t? table The table to release (cleared before returning to pool).
---@usage <br>
--- ```
--- local t = Pool.acquire("slot")
--- -- ... use t ...
--- Pool.release("slot", t) -- t is cleared and returned to pool
--- ```
function Pool.release(category, t)
	if t == nil then return end
	for k in next, t do t[k] = nil end
	local list = Pool.categories[category]
	if not list then
		list = {}
		Pool.categories[category] = list
	end
	local max = Pool.config[category] or Pool.defaultMax
	if #list < max then
		list[#list + 1] = t
	end
end

Utils.pool = Pool

Pool.configure("slot", 64)
Pool.configure("templist", 32)
Pool.configure("snapshot", 16)

----------------------------------------------------------------------
-- Contracts
----------------------------------------------------------------------
local Contracts = {}

Contracts.Item = {
	required = { "id", "type", "stackable", "maxStack", "weight" },
}

Contracts.Inventory = {
	methods = {
		"add", "remove", "move", "split", "merge",
		"getSlot", "listItems", "snapshot", "restore",
	},
}

Contracts.StorageAdapter = {
	methods = { "save", "load" },
}

Contracts.UIAdapter = {
	methods = { "render", "onEvent" },
}

Contracts.EventDispatcher = {
	methods = { "subscribe", "unsubscribe", "emit", "beginBatch", "endBatch" },
}

---@param name string The contract name to validate against.
---@param obj table The object to validate.
---@return boolean boolean True if validation passes (or DEBUG is false).
---@usage <br>
--- ```
--- Contracts.validate("Item", { id = "sword", type = "weapon" })
--- ```
function Contracts.validate(name, obj)
	if not DEBUG then return true end
	Utils.assert(obj ~= nil, "Contract '" .. name .. "' validation: nil object")
	local c = Contracts[name]
	Utils.assert(c ~= nil, "Unknown contract: " .. tostring(name))
	if c.required then
		for i = 1, #c.required do
			local k = c.required[i]
			Utils.assert(obj[k] ~= nil,
				"Contract '" .. name .. "' missing field: " .. tostring(k))
		end
	end
	if c.methods then
		for i = 1, #c.methods do
			local m = c.methods[i]
			Utils.assert(type(obj[m]) == "function",
				"Contract '" .. name .. "' missing method: " .. tostring(m))
		end
	end
	return true
end

----------------------------------------------------------------------
-- ItemFactory
----------------------------------------------------------------------
local ItemFactory = {}

local behaviors = {}

--- Register a behavior table for an item type
---@param typeName string The item type identifier
---@param behaviorTable table Table containing behavior functions (e.g. onUse, onAdd)
function ItemFactory.registerBehavior(typeName, behaviorTable)
	Utils.assert(type(typeName) == "string", "registerBehavior: typeName string")
	Utils.assert(type(behaviorTable) == "table", "registerBehavior: table")
	behaviors[typeName] = behaviorTable
end

--- Invoke a behavior action if registered for item.type
---@param item table The item instance
---@param action string The action name to invoke (e.g. "onUse")
---@param ctx table Optional context table passed to the behavior function
---@return any value Return value from behavior function, or nil if not registered
function ItemFactory.invoke(item, action, ctx)
	local b = behaviors[item and item.type]
	if b and type(b[action]) == "function" then
		return b[action](item, ctx)
	end
	return nil
end

--- Create a new item
---@param spec table Item specification with fields: id, type, stackable, maxStack, weight, attrs
---@return table item The created item instance
function ItemFactory.create(spec)
	Utils.assert(type(spec) == "table", "ItemFactory.create: spec table required")
	Utils.assert(spec.id ~= nil, "ItemFactory.create: id required")
	local item = {
		id        = spec.id,
		type      = spec.type or "generic",
		stackable = spec.stackable == true,
		maxStack  = spec.maxStack or (spec.stackable and 1 or 1),
		weight    = spec.weight or 0,
		attrs     = spec.attrs and Utils.shallowCopy(spec.attrs) or {},
	}
	if DEBUG then Contracts.validate("Item", item) end
	return item
end

--- Clone an item
---@param item table The item to clone
---@return table item A new item instance with copied attributes
function ItemFactory.clone(item)
	return {
		id        = item.id,
		type      = item.type,
		stackable = item.stackable,
		maxStack  = item.maxStack,
		weight    = item.weight,
		attrs     = item.attrs and Utils.shallowCopy(item.attrs) or {},
	}
end

--- Lightweight serialization to a flat string
---@param item table The item to serialize
---@return string serialized Serialized item data
function ItemFactory.serialize(item)
	local attrs = {}
	for k, v in next, item.attrs or {} do
		attrs[#attrs + 1] = tostring(k) .. "=" .. tostring(v)
	end
	table_sort(attrs)
	return string_format("%s|%s|%s|%d|%g|%s",
		tostring(item.id), tostring(item.type),
		tostring(item.stackable), tonumber(item.maxStack) or 1,
		tonumber(item.weight) or 0, table_concat(attrs, ";"))
end

--- Deserialize a string produced by serialize
---@param s string The serialized item string
---@return table deserialized The deserialized item instance
function ItemFactory.deserialize(s)
	local parts = {}
	s = s .. "|"
	for p in string_gmatch(s, "([^|]*)|") do parts[#parts + 1] = p end
	Utils.assert(#parts >= 6, "deserialize: bad encoding")
	local attrs = {}
	if #parts[6] > 0 then
		for kv in string_gmatch(parts[6], "[^;]+") do
			local k, v = string_match(kv, "([^=]+)=([^=]+)")
			if k then attrs[k] = v end
		end
	end
	return ItemFactory.create({
		id        = parts[1],
		type      = parts[2],
		stackable = parts[3] == "true",
		maxStack  = tonumber(parts[4]) or 1,
		weight    = tonumber(parts[5]) or 0,
		attrs     = attrs,
	})
end

----------------------------------------------------------------------
-- StackManager
----------------------------------------------------------------------
local StackManager = {}

---@param slots table Array of slot tables to search.
---@param item table The item to find a stackable slot for.
---@param capacity number The number of slots to search.
---@return number? number Index of the first stackable slot, or nil if none found.
---@usage <br>
--- ```
--- local idx = StackManager.findStackable(slots, item, 10)
--- if idx then print("Found stackable slot: " .. idx) end
--- ```
function StackManager.findStackable(slots, item, capacity)
	for i = 1, capacity do
		local s = slots[i]
		if s and s.item and s.item.id == item.id
			and s.item.stackable and s.qty < s.item.maxStack then
			return i
		end
	end
	return nil
end

---@param slots table Array of slot tables to search.
---@param capacity number The number of slots to search.
---@return number? number Index of the first empty slot, or nil if none found.
---@usage <br>
--- ```
--- local idx = StackManager.findEmpty(slots, 10)
--- if idx then print("Found empty slot: " .. idx) end
--- ```
function StackManager.findEmpty(slots, capacity)
	for i = 1, capacity do
		local s = slots[i]
		if s == nil or s.item == nil then
			return i
		end
	end
	return nil
end

---@param slotA table The destination slot.
---@param slotB table The source slot to merge from.
---@return number number Quantity of items merged.
---@usage <br>
--- ```
--- local merged = StackManager.merge(slotA, slotB)
--- print("Merged " .. merged .. " items")
--- ```
function StackManager.merge(slotA, slotB)
	if not slotA or not slotB then return 0 end
	if not slotA.item or not slotB.item then return 0 end
	if slotA.item.id ~= slotB.item.id then return 0 end
	if not slotA.item.stackable then return 0 end
	local room = slotA.item.maxStack - slotA.qty
	if room <= 0 then return 0 end
	local moveQty = math_min(room, slotB.qty)
	slotA.qty = slotA.qty + moveQty
	slotB.qty = slotB.qty - moveQty
	if slotB.qty <= 0 then slotB.item = nil end
	return moveQty
end

---@param slot table The source slot to split from.
---@param qty number Quantity of items to split off.
---@return table? table A new slot table with the split items, or nil if invalid.
---@usage <br>
--- ```
--- local newSlot = StackManager.split(srcSlot, 5)
--- if newSlot then print("Split off " .. newSlot.qty .. " items") end
--- ```
function StackManager.split(slot, qty)
	if not slot or not slot.item then return nil end
	if qty <= 0 or qty >= slot.qty then return nil end
	local out = Utils.pool.acquire("slot")
	out.item  = ItemFactory.clone(slot.item)
	out.qty   = qty
	slot.qty  = slot.qty - qty
	return out
end

----------------------------------------------------------------------
-- EventDispatcher
----------------------------------------------------------------------
local EventDispatcher = {}

---@return table table Event dispatcher instance.
---@usage <br>
--- ```
--- local events = EventDispatcher.new()
--- ```
function EventDispatcher.new()
	local self = {
		subscribers = {},
		batchQueue  = nil,
		coalesce    = {},
	}

	---@param event string The event name.
	---@param handler function The handler function.
	---@return function unsubscribe Function to unsubscribe from the event.
	---@usage <br>
	--- ```
	--- local unsub = events.subscribe("inventoryChanged", function(evt, payload)
	---   print("Event: " .. evt)
	--- end)
	--- unsub() -- unsubscribe
	--- ```
	function self.subscribe(event, handler)
		Utils.assert(type(event) == "string", "subscribe: event string")
		Utils.assert(type(handler) == "function", "subscribe: handler fn")
		self.subscribers[event] = self.subscribers[event] or {}
		table_insert(self.subscribers[event], handler)
		return function() self.unsubscribe(event, handler) end
	end

	---@param event string The event name.
	---@param handler function The handler function to remove.
	---@usage <br>
	--- ```
	--- events.unsubscribe("inventoryChanged", myHandler)
	--- ```
	function self.unsubscribe(event, handler)
		local list = self.subscribers[event]
		if not list then return end
		for i = #list, 1, -1 do
			if list[i] == handler then table_remove(list, i) end
		end
	end

	---@param event string The event name.
	---@param payload any The event payload data.
	---@usage <br>
	--- ```
	--- events.emit("inventoryChanged", { action = "add", itemId = "sword" })
	--- ```
	function self.emit(event, payload)
		if self.batchQueue then
			self.coalesce[event] = payload
			self.batchQueue[event] = true
			return
		end
		local list = self.subscribers[event]
		if not list then return end
		for i = 1, #list do
			list[i](event, payload)
		end
	end

	---@usage <br>
	--- ```
	--- events.beginBatch()
	--- events.emit("inventoryChanged", { action = "add" }) -- deferred
	--- events.emit("inventoryChanged", { action = "remove" }) -- coalesced
	--- events.endBatch() -- emits once per unique event
	--- ```
	function self.beginBatch()
		self.batchQueue = {}
		self.coalesce   = {}
	end

	---@usage <br>
	--- ```
	--- events.beginBatch()
	--- events.emit("inventoryChanged", { action = "add" })
	--- events.endBatch() -- emits queued events
	--- ```
	function self.endBatch()
		local queued    = self.batchQueue
		local coal      = self.coalesce
		self.batchQueue = nil
		self.coalesce   = {}
		if not queued then return end
		for event, _ in next, queued do
			local list = self.subscribers[event]
			local payload = coal[event]
			if list then
				for i = 1, #list do
					list[i](event, payload)
				end
			end
		end
	end

	return self
end

----------------------------------------------------------------------
-- InventoryCore
----------------------------------------------------------------------
local InventoryCore = {}

---@param opts? table Optional options:
--- - `capacity` (number, default: 16): Inventory capacity.
--- - `maxWeight` (number, default: `math.huge`): Maximum weight of items in the inventory.
--- - `events` (EventDispatcher, default: `EventDispatcher.new()`): Event dispatcher instance.
---@return table table Inventory instance with methods for item manipulation.
---@usage <br>
--- ```
--- local inv = InventoryCore.new({ capacity = 20, maxWeight = 500 })
--- ```
function InventoryCore.new(opts)
	opts            = opts or {}
	local capacity  = opts.capacity or 16
	local maxWeight = opts.maxWeight or math_huge
	Utils.assert(capacity > 0, "capacity must be > 0")

	local self = {
		capacity  = capacity,
		maxWeight = maxWeight,
		weight    = 0,
		slots     = {},
		events    = opts.events or EventDispatcher.new(),
		_suppress = false,
	}
	for i = 1, capacity do
		self.slots[i]      = Utils.pool.acquire("slot")
		self.slots[i].item = nil
		self.slots[i].qty  = 0
	end

	local function emit(event, payload)
		if not self._suppress then self.events.emit(event, payload) end
	end

	---@param item table The item to add.
	---@param qty? number Quantity to add (default: 1).
	---@return number number Quantity actually added.
	---@usage <br>
	--- ```
	--- local added = inv.add(sword, 1)
	--- print("Added " .. added .. " swords")
	--- ```
	function self.add(item, qty)
		Utils.assert(item and item.id, "add: valid item required")
		qty = qty or 1
		Utils.assert(qty > 0, "add: qty must be > 0")
		local remaining = qty
		while remaining > 0 do
			local idx = StackManager.findStackable(self.slots, item, self.capacity)
			if not idx then break end
			local s = self.slots[idx]
			local room = s.item.maxStack - s.qty
			local toAdd = math_min(room, remaining)
			if self.weight + item.weight * toAdd > self.maxWeight then
				local affordable = math_floor((self.maxWeight - self.weight) / item.weight)
				if affordable <= 0 then break end
				toAdd = math_min(toAdd, affordable)
			end
			s.qty = s.qty + toAdd
			self.weight = self.weight + item.weight * toAdd
			remaining = remaining - toAdd
			emit("slotChanged", { slot = idx, action = "stack" })
		end
		while remaining > 0 do
			local idx = StackManager.findEmpty(self.slots, self.capacity)
			if not idx then break end
			local toAdd = math_min(item.maxStack, remaining)
			if self.weight + item.weight * toAdd > self.maxWeight then
				local affordable = math_floor((self.maxWeight - self.weight) / item.weight)
				if affordable <= 0 then break end
				toAdd = math_min(toAdd, affordable)
			end
			local s     = self.slots[idx]
			s.item      = ItemFactory.clone(item)
			s.qty       = toAdd
			self.weight = self.weight + item.weight * toAdd
			remaining   = remaining - toAdd
			emit("slotChanged", { slot = idx, action = "place" })
		end
		if remaining < qty then
			emit("inventoryChanged", {
				action = "add",
				itemId = item.id,
				added = qty - remaining
			})
		end
		return qty - remaining
	end

	---@param itemId string The item id to remove.
	---@param qty? number Quantity to remove (default: 1).
	---@return number number Quantity actually removed.
	---@usage <br>
	--- ```
	--- local removed = inv.remove("sword", 1)
	--- print("Removed " .. removed .. " swords")
	--- ```
	function self.remove(itemId, qty)
		Utils.assert(itemId ~= nil, "remove: itemId required")
		qty = qty or 1
		Utils.assert(qty > 0, "remove: qty > 0")
		local remaining = qty
		for i = 1, self.capacity do
			if remaining <= 0 then break end
			local s = self.slots[i]
			if s and s.item and s.item.id == itemId then
				local take = math_min(s.qty, remaining)
				s.qty = s.qty - take
				self.weight = self.weight - s.item.weight * take
				remaining = remaining - take
				if s.qty <= 0 then
					s.item = nil
					s.qty  = 0
				end
				emit("slotChanged", { slot = i, action = "remove" })
			end
		end
		if remaining < qty then
			emit("inventoryChanged", {
				action = "remove",
				itemId = itemId,
				removed = qty - remaining
			})
		end
		return qty - remaining
	end

	---@param slotFrom number Source slot index (1-based).
	---@param slotTo number Destination slot index (1-based).
	---@return boolean boolean True on success.
	---@usage <br>
	--- ```
	--- inv.move(1, 5) -- swap slot 1 and slot 5
	--- ```
	function self.move(slotFrom, slotTo)
		Utils.assert(slotFrom >= 1 and slotFrom <= self.capacity, "move: bad from")
		Utils.assert(slotTo >= 1 and slotTo <= self.capacity, "move: bad to")
		local a = self.slots[slotFrom]
		local b = self.slots[slotTo]
		self.slots[slotFrom], self.slots[slotTo] = b, a
		emit("slotChanged", { slot = slotFrom, action = "move" })
		emit("slotChanged", { slot = slotTo, action = "move" })
		return true
	end

	---@param slot number Source slot index (1-based).
	---@param qty number Quantity to split off.
	---@return boolean boolean True on success.
	---@usage <br>
	--- ```
	--- inv.split(1, 5) -- split 5 items from slot 1 to an empty slot
	--- ```
	function self.split(slot, qty)
		Utils.assert(slot >= 1 and slot <= self.capacity, "split: bad slot")
		local src = self.slots[slot]
		if not src or not src.item then return false end
		if qty <= 0 or qty >= src.qty then return false end
		local dstIdx = StackManager.findEmpty(self.slots, self.capacity)
		if not dstIdx then return false end
		local newSlot = StackManager.split(src, qty)
		if not newSlot then return false end
		local dst = self.slots[dstIdx]
		dst.item  = newSlot.item
		dst.qty   = newSlot.qty
		Utils.pool.release("slot", newSlot)
		emit("slotChanged", { slot = slot, action = "split-src" })
		emit("slotChanged", { slot = dstIdx, action = "split-dst" })
		return true
	end

	---@param slotA number Destination slot index (1-based).
	---@param slotB number Source slot index (1-based).
	---@return number number Quantity merged.
	---@usage <br>
	--- ```
	--- local merged = inv.merge(2, 1)
	--- print("Merged " .. merged .. " items")
	--- ```
	function self.merge(slotA, slotB)
		Utils.assert(slotA >= 1 and slotA <= self.capacity, "merge: bad A")
		Utils.assert(slotB >= 1 and slotB <= self.capacity, "merge: bad B")
		local a = self.slots[slotA]
		local b = self.slots[slotB]
		local moved = StackManager.merge(a, b)
		if moved > 0 then
			emit("slotChanged", { slot = slotA, action = "merge-A" })
			emit("slotChanged", { slot = slotB, action = "merge-B" })
		end
		return moved
	end

	---@param index number Slot index (1-based).
	---@return table? table Slot data {slot, item, qty} or nil if empty/invalid.
	---@usage <br>
	--- ```
	--- local slot = inv.getSlot(1)
	--- if slot then print("Slot 1 has " .. slot.qty .. " " .. slot.item.id) end
	--- ```
	function self.getSlot(index)
		if index < 1 or index > self.capacity then return nil end
		local s = self.slots[index]
		if not s or not s.item then return nil end
		return { slot = index, item = s.item, qty = s.qty }
	end

	---@return table table Array of slot entries (must be released with releaseList).
	---@usage <br>
	--- ```
	--- local items = inv.listItems()
	--- for i, entry in ipairs(items) do
	---   print(entry.slot .. ": " .. entry.item.id .. " x" .. entry.qty)
	--- end
	--- inv.releaseList(items)
	--- ```
	function self.listItems()
		local out = Utils.pool.acquire("templist")
		for i = 1, self.capacity do
			local s = self.slots[i]
			if s and s.item then
				local e       = Utils.pool.acquire("slot")
				e.slot        = i
				e.item        = s.item
				e.qty         = s.qty
				out[#out + 1] = e
			end
		end
		return out
	end

	---@param list table The list to release.
	---@usage <br>
	--- ```
	--- local items = inv.listItems()
	--- -- ... use items ...
	--- inv.releaseList(items) -- release back to pool
	--- ```
	function self.releaseList(list)
		if not list then return end
		for i = 1, #list do Utils.pool.release("slot", list[i]) end
		Utils.pool.release("templist", list)
	end

	---@return table table Snapshot data (must be released after use).
	---@usage <br>
	--- ```
	--- local snap = inv.snapshot()
	--- -- ... make changes ...
	--- inv.restore(snap) -- rollback to snapshot
	--- ```
	function self.snapshot()
		local snap  = Utils.pool.acquire("snapshot")
		snap.weight = self.weight
		snap.slots  = {}
		for i = 1, self.capacity do
			local s = self.slots[i]
			snap.slots[i] = { item = s.item, qty = s.qty }
		end
		return snap
	end

	---@param snap table Snapshot data from snapshot().
	---@usage <br>
	--- ```
	--- local snap = inv.snapshot()
	--- -- ... make changes ...
	--- inv.restore(snap) -- rollback to snapshot
	--- ```
	function self.restore(snap)
		self.weight = snap.weight
		for i = 1, self.capacity do
			local src = snap.slots[i]
			local s   = self.slots[i]
			s.item    = src.item
			s.qty     = src.qty
		end
		Utils.pool.release("snapshot", snap)
		if not self._suppress then
			self.events.emit("inventoryChanged", { action = "restore" })
		end
	end

	---@param flag boolean Whether to suppress event emission.
	---@usage <br>
	--- ```
	--- inv.setSuppress(true)  -- disable events
	--- inv.setSuppress(false) -- enable events
	--- ```
	function self.setSuppress(flag)
		self._suppress = flag == true
	end

	---@return number number Total weight.
	---@usage <br>
	--- ```
	--- print("Total weight: " .. inv.totalWeight())
	--- ```
	function self.totalWeight()
		return self.weight
	end

	if DEBUG then Contracts.validate("Inventory", self) end
	return self
end

----------------------------------------------------------------------
-- TransactionManager
----------------------------------------------------------------------
local TransactionManager = {}

---@param core table The InventoryCore instance to manage.
---@return table table Transaction manager instance.
---@usage <br>
--- ```
--- local tx = TransactionManager.new(inv)
--- ```
function TransactionManager.new(core)
	local self = { core = core, snapshot = nil, active = false }
	---@return table table Self for chaining.
	---@usage <br>
	--- ```
	--- tx.begin()
	--- -- ... make changes ...
	--- tx.commit() or tx.rollback()
	--- ```
	function self.begin()
		Utils.assert(not self.active, "txn already active")
		self.snapshot = core.snapshot()
		self.active   = true
		core.setSuppress(true)
		return self
	end

	---@return boolean boolean True on success.
	---@usage <br>
	--- ```
	--- tx.begin()
	--- -- ... make changes ...
	--- tx.commit() -- accept changes
	--- ```
	function self.commit()
		Utils.assert(self.active, "commit without begin")
		core.setSuppress(false)
		self.active   = false
		self.snapshot = nil
		core.events.emit("transactionCommitted", {})
		return true
	end

	---@return boolean boolean False (indicates rollback).
	---@usage <br>
	--- ```
	--- tx.begin()
	--- -- ... make changes ...
	--- tx.rollback() -- revert to snapshot
	--- ```
	function self.rollback()
		Utils.assert(self.active, "rollback without begin")
		core.setSuppress(false)
		if self.snapshot then
			core.restore(self.snapshot)
			self.snapshot = nil
		end
		self.active = false
		core.events.emit("transactionRolledBack", {})
		return false
	end

	---@param pairs table Array of {item, qty} tables.
	---@return boolean boolean True if committed, false if rolled back.
	---@usage <br>
	--- ```
	--- local ok = tx.atomicAdd({
	---   { item = sword, qty = 1 },
	---   { item = shield, qty = 1 },
	--- })
	--- print("Transaction " .. (ok and "committed" or "rolled back"))
	--- ```
	function self.atomicAdd(pairs)
		Utils.assert(type(pairs) == "table", "atomicAdd: pairs table")
		self.begin()
		local ok = true
		for i = 1, #pairs do
			local p = pairs[i]
			local added = core.add(p.item, p.qty)
			if added < p.qty then
				ok = false
				break
			end
		end
		if ok then return self.commit() else return self.rollback() end
	end

	---@param pairs table Array of {itemId, qty} tables.
	---@return boolean boolean True if committed, false if rolled back.
	---@usage <br>
	--- ```
	--- local ok = tx.atomicRemove({
	---   { itemId = "sword", qty = 1 },
	---   { itemId = "shield", qty = 1 },
	--- })
	--- print("Transaction " .. (ok and "committed" or "rolled back"))
	--- ```
	function self.atomicRemove(pairs)
		Utils.assert(type(pairs) == "table", "atomicRemove: pairs table")
		self.begin()
		local ok = true
		for i = 1, #pairs do
			local p = pairs[i]
			local removed = core.remove(p.itemId, p.qty)
			if removed < p.qty then
				ok = false
				break
			end
		end
		if ok then return self.commit() else return self.rollback() end
	end

	return self
end

----------------------------------------------------------------------
-- StorageAdapters
----------------------------------------------------------------------
local StorageAdapters = {}

---@return table table Storage adapter instance.
---@usage <br>
--- ```
--- local mem = StorageAdapters.InMemoryAdapter()
--- mem.save("slot1", inv)
--- mem.load("slot1", inv2)
--- ```
function StorageAdapters.InMemoryAdapter()
	local store = {}
	local adapter = {}
	---@param key string The storage key.
	---@param core table The InventoryCore instance.
	---@return boolean boolean True on success.
	---@usage <br>
	--- ```
	--- mem.save("save1", inv)
	--- ```
	function adapter.save(key, core)
		local snap = core.snapshot()
		store[key] = snap
		local copy = { weight = snap.weight, slots = {} }
		for i = 1, #snap.slots do
			copy.slots[i] = { item = snap.slots[i].item, qty = snap.slots[i].qty }
		end
		store[key] = copy
		Utils.pool.release("snapshot", snap)
		return true
	end

	---@param key string The storage key.
	---@param core table The InventoryCore instance.
	---@return boolean boolean True on success, false if key not found.
	---@usage <br>
	--- ```
	--- local ok = mem.load("save1", inv)
	--- print("Loaded: " .. tostring(ok))
	--- ```
	function adapter.load(key, core)
		local snap = store[key]
		if not snap then return false end
		local s = { weight = snap.weight, slots = {} }
		for i = 1, #snap.slots do
			s.slots[i] = { item = snap.slots[i].item, qty = snap.slots[i].qty }
		end
		core.setSuppress(true)
		core.restore(s)
		core.setSuppress(false)
		return true
	end

	if DEBUG then Contracts.validate("StorageAdapter", adapter) end
	return adapter
end

---@return table table Storage adapter instance.
---@usage <br>
--- ```
--- local saver = StorageAdapters.SaveLoadAdapter()
--- local data = saver.save(inv)
--- saver.load(inv2, data)
--- ```
function StorageAdapters.SaveLoadAdapter()
	local adapter = {}
	---@param core table The InventoryCore instance.
	---@return string string Serialized inventory data.
	---@usage <br>
	--- ```
	--- local data = saver.save(inv)
	--- print(data) -- serialized inventory string
	--- ```
	function adapter.save(core)
		local snap = core.snapshot()
		local lines = {}
		lines[#lines + 1] = tostring(snap.weight)
		for i = 1, #snap.slots do
			local s = snap.slots[i]
			if s.item then
				lines[#lines + 1] = i .. ":" .. s.qty .. ":" .. ItemFactory.serialize(s.item)
			end
		end
		Utils.pool.release("snapshot", snap)
		return table_concat(lines, "\n")
	end

	---@param core table The InventoryCore instance.
	---@param str string The serialized inventory data.
	---@return boolean boolean True on success, false if invalid.
	---@usage <br>
	--- ```
	--- local ok = saver.load(inv, data)
	--- print("Loaded: " .. tostring(ok))
	--- ```
	function adapter.load(core, str)
		if not str then return false end
		local lines = {}
		for ln in string_gmatch(str, "[^\n]+") do lines[#lines + 1] = ln end
		local weight = tonumber(lines[1]) or 0
		local snap = { weight = weight, slots = {} }
		for i = 1, core.capacity do snap.slots[i] = { item = nil, qty = 0 } end
		for i = 2, #lines do
			local idx, qty, itemStr = string_match(lines[i], "^(%d+):(%d+):(.*)$")
			if idx then
				snap.slots[tonumber(idx)] = {
					item = ItemFactory.deserialize(itemStr),
					qty  = tonumber(qty)
				}
			end
		end
		core.setSuppress(true)
		core.restore(snap)
		core.setSuppress(false)
		return true
	end

	return adapter
end

---@return table table Storage adapter instance.
---@usage <br>
--- ```
--- local net = StorageAdapters.NetworkSyncAdapter()
--- local diff = net.computeDiff(oldState, newState)
--- ```
function StorageAdapters.NetworkSyncAdapter()
	local adapter = {}

	---@param oldState table The old inventory state.
	---@param newState table The new inventory state.
	---@return table table Diff with added, removed, changed fields.
	---@usage <br>
	--- ```
	--- local diff = net.computeDiff(localSnap, remoteSnap)
	--- print("Added: " .. #diff.added .. " slots")
	--- ```
	function adapter.computeDiff(oldState, newState)
		Utils.assert(type(oldState) == "table" and type(newState) == "table",
			"computeDiff: two states required")
		local diff = { added = {}, removed = {}, changed = {} }
		local maxN = math_max(#oldState.slots, #newState.slots)
		for i = 1, maxN do
			local a = oldState.slots[i]
			local b = newState.slots[i]
			if a and not b then
				if a.item then diff.removed[i] = true end
			elseif not a and b and b.item then
				diff.added[i] = { item = b.item, qty = b.qty }
			elseif a and b then
				if not a.item and b.item then
					diff.added[i] = { item = b.item, qty = b.qty }
				elseif a.item and not b.item then
					diff.removed[i] = true
				elseif a.item and b.item then
					if a.item.id ~= b.item.id or a.qty ~= b.qty then
						diff.changed[i] = { item = b.item, qty = b.qty }
					end
				end
			end
		end
		return diff
	end

	---@param state table The base state.
	---@param diff table The diff to apply.
	---@return table table The resulting state.
	---@usage <br>
	--- ```
	--- local newState = net.applyDiff(oldState, diff)
	--- ```
	function adapter.applyDiff(state, diff)
		local out = { weight = state.weight, slots = {} }
		for i = 1, #state.slots do
			local s = state.slots[i]
			out.slots[i] = { item = s.item, qty = s.qty }
		end
		for i, entry in next, diff.added do
			out.slots[i] = { item = entry.item, qty = entry.qty }
		end
		for i, entry in next, diff.changed do
			out.slots[i] = { item = entry.item, qty = entry.qty }
		end
		for i, _ in next, diff.removed do
			out.slots[i] = { item = nil, qty = 0 }
		end
		local w = 0
		for i = 1, #out.slots do
			local s = out.slots[i]
			if s.item then w = w + s.item.weight * s.qty end
		end
		out.weight = w
		return out
	end

	---@param localState table The local inventory state.
	---@param remoteState table The remote inventory state.
	---@param strategy? string "server" or "lww" (default: "server").
	---@return table table The merged state.
	---@usage <br>
	--- ```
	--- local merged = net.mergeConflict(localSnap, remoteSnap, "server")
	--- ```
	function adapter.mergeConflict(localState, remoteState, strategy)
		strategy = strategy or "server"
		if strategy == "server" then
			local out = { weight = remoteState.weight, slots = {} }
			for i = 1, #remoteState.slots do
				local s = remoteState.slots[i]
				out.slots[i] = { item = s.item, qty = s.qty }
			end
			return out
		elseif strategy == "lww" then
			local out = { weight = 0, slots = {} }
			local maxN = math_max(#localState.slots, #remoteState.slots)
			for i = 1, maxN do
				local l = localState.slots[i]
				local r = remoteState.slots[i]
				if r and r.item then
					out.slots[i] = { item = r.item, qty = r.qty }
				elseif l and l.item then
					out.slots[i] = { item = l.item, qty = l.qty }
				else
					out.slots[i] = { item = nil, qty = 0 }
				end
			end
			local w = 0
			for i = 1, #out.slots do
				local s = out.slots[i]
				if s.item then w = w + s.item.weight * s.qty end
			end
			out.weight = w
			return out
		end
		return error("Unknown merge strategy: " .. tostring(strategy), 2)
	end

	return adapter
end

----------------------------------------------------------------------
-- UIAdapterExample
----------------------------------------------------------------------
local UIAdapterExample = {}

---@param core table The InventoryCore instance.
---@return table table UI adapter instance.
---@usage <br>
--- ```
--- local ui = UIAdapterExample.new(inv)
--- print(ui.render())
--- ```
function UIAdapterExample.new(core)
	local self = { core = core }
	---@return string string Textual representation of inventory.
	---@usage <br>
	--- ```
	--- print(ui.render())
	--- -- Output:
	--- -- Inventory (weight 5.00/100):
	--- --   [01] sword        x1  w=5.00
	--- --   [02] (empty)
	--- ```
	function self.render()
		local lines = {}
		lines[#lines + 1] = string_format("Inventory (weight %.2f/%s):",
			core.weight, tostring(core.maxWeight))
		for i = 1, core.capacity do
			local s = core.slots[i]
			if s and s.item then
				lines[#lines + 1] = string_format("  [%02d] %-12s x%d  w=%.2f",
					i, tostring(s.item.id), s.qty, s.item.weight * s.qty)
			else
				lines[#lines + 1] = string_format("  [%02d] (empty)", i)
			end
		end
		return table_concat(lines, "\n")
	end

	---@param event string The event name.
	---@param payload any The event payload.
	---@usage <br>
	--- ```
	--- ui.onEvent("inventoryChanged", { action = "add", itemId = "sword" })
	--- ```
	function self.onEvent(event, payload)
		-- In a real UI, we'd invalidate/redraw only affected slots
		if event == "inventoryChanged" or event == "transactionCommitted"
			or event == "transactionRolledBack" then
		end
	end

	core.events.subscribe("inventoryChanged", self.onEvent)
	core.events.subscribe("transactionCommitted", self.onEvent)
	core.events.subscribe("transactionRolledBack", self.onEvent)
	if DEBUG then Contracts.validate("UIAdapter", self) end
	return self
end

----------------------------------------------------------------------
-- Tests
----------------------------------------------------------------------
local Tests = {}
do
	local passCount, failCount = 0, 0
	local failures = {}

	---@param name string The test name.
	---@param cond boolean The condition to check.
	local function check(name, cond)
		if cond then
			passCount = passCount + 1
		else
			failCount = failCount + 1
			failures[#failures + 1] = name
			print("  FAIL: " .. name)
		end
	end

	---@param name string The suite name.
	---@param fn function The test function to run.
	local function suite(name, fn)
		local ok, err = pcall(fn)
		if not ok then
			failCount = failCount + 1
			failures[#failures + 1] = name .. " (error)"
			print("  SUITE ERROR in " .. name .. ": " .. tostring(err))
		end
	end

	---@return boolean boolean True if all tests passed.
	---@usage <br>
	--- ```
	--- local ok = Tests.run()
	--- if not ok then os.exit(1) end
	--- ```
	function Tests.run()
		suite("Utils", function()
			local t = { a = 1, b = 2 }
			local c = Utils.shallowCopy(t)
			check("shallowCopy_equal", c.a == 1 and c.b == 2)
			c.a = 99
			check("shallowCopy_independent", t.a == 1)
			local id = Utils.newIdGenerator(100)
			check("idGen_monotonic", id() == 100 and id() == 101)
			local p = Utils.pool.acquire("templist")
			p[1] = "x"
			p[2] = "y"
			Utils.pool.release("templist", p)
			local p2 = Utils.pool.acquire("templist")
			check("pool_reuse_cleared", p2[1] == nil and p2[2] == nil)
		end)

		suite("ItemFactory", function()
			local it = ItemFactory.create({
				id = "sword",
				type = "weapon",
				weight = 5,
				stackable = false
			})
			check("item_fields", it.id == "sword" and it.weight == 5
				and it.stackable == false and it.maxStack == 1)
			local cl = ItemFactory.clone(it)
			check("item_clone", cl.id == "sword" and cl ~= it)
			cl.attrs.foo = "bar"
			check("item_clone_attrs_independent", it.attrs.foo == nil)
			local s = ItemFactory.serialize(it)
			local it2 = ItemFactory.deserialize(s)
			check("item_serialize_roundtrip",
				it2.id == it.id and it2.weight == it.weight and it2.type == it.type)
			ItemFactory.registerBehavior("consumable", {
				onUse = function(item, ctx) return "used " .. item.id end
			})
			local pot = ItemFactory.create({
				id = "potion",
				type = "consumable",
				weight = 0.5,
				stackable = true,
				maxStack = 10
			})
			check("behavior_invoke", ItemFactory.invoke(pot, "onUse", {}) == "used potion")
			check("behavior_missing_returns_nil",
				ItemFactory.invoke(it, "onUse", {}) == nil)
		end)

		suite("StackManager", function()
			local slots = {
				{ item = { id = "a", stackable = true, maxStack = 5 }, qty = 3 },
				{ item = nil,                                          qty = 0 },
			}
			check("findStackable", StackManager.findStackable(slots,
				{ id = "a", stackable = true }, 2) == 1)
			check("findEmpty", StackManager.findEmpty(slots, 2) == 2)
			local mv = StackManager.merge(slots[1], { item = slots[1].item, qty = 2 })
			check("merge_partial", mv == 2 and slots[1].qty == 5)
			local sp = StackManager.split(slots[1], 2)
			check("split_ok", sp ~= nil and sp.qty == 2 and slots[1].qty == 3)
		end)

		suite("EventDispatcher", function()
			local d = EventDispatcher.new()
			local got = 0
			local unsub = d.subscribe("e", function() got = got + 1 end)
			d.emit("e")
			check("event_emit", got == 1)
			unsub()
			d.emit("e")
			check("event_unsubscribe", got == 1)
			local b = 0
			d.subscribe("batch", function() b = b + 1 end)
			d.beginBatch()
			d.emit("batch", { n = 1 })
			d.emit("batch", { n = 2 })
			d.emit("batch", { n = 3 })
			check("event_batch_deferred", b == 0)
			d.endBatch()
			check("event_batch_coalesced", b == 1)
		end)

		suite("InventoryCore", function()
			local core = InventoryCore.new({ capacity = 5, maxWeight = 50 })
			local arrow = ItemFactory.create({
				id = "arrow",
				type = "ammo",
				stackable = true,
				maxStack = 10,
				weight = 0.1
			})
			check("add_returns_qty", core.add(arrow, 25) == 25)
			check("add_stacks_across_slots", core.slots[1].qty == 10
				and core.slots[2].qty == 10
				and core.slots[3].qty == 5)
			check("add_weight_tracked", math.abs(core.weight - 2.5) < 1e-9)
			check("remove_qty", core.remove("arrow", 7) == 7)
			check("remove_from_first_stack", core.slots[1].qty == 3)
			core.move(1, 5)
			check("move_swaps", core.slots[5].item ~= nil
				and core.slots[1].item == nil)
			core.split(2, 4)
			check("split_creates_new_stack",
				core.slots[2].qty == 6 and core.slots[1].qty == 4)
			local moved = core.merge(2, 1)
			check("merge_fills_stack", moved == 4 and core.slots[2].qty == 10
				and core.slots[1].item == nil)
			local heavy = ItemFactory.create({
				id = "boulder",
				type = "obstacle",
				stackable = false,
				weight = 60
			})
			check("add_respects_weight_cap", core.add(heavy, 1) == 0)
		end)

		suite("TransactionManager", function()
			local core = InventoryCore.new({ capacity = 10, maxWeight = 1000 })
			local tx = TransactionManager.new(core)
			local a = ItemFactory.create({ id = "a", stackable = true, maxStack = 5, weight = 1 })
			local b = ItemFactory.create({ id = "b", stackable = true, maxStack = 5, weight = 1 })
			local ok = tx.atomicAdd({ { item = a, qty = 3 }, { item = b, qty = 2 } })
			check("txn_atomicAdd_ok", ok == true)
			check("txn_state_after_commit", core.slots[1].qty == 3 and core.slots[2].qty == 2)
			-- Failing atomic add: try to add 100 of 'a', should roll back
			local ok2 = tx.atomicAdd({ { item = a, qty = 100 } })
			check("txn_atomicAdd_rollback", ok2 == false)
			check("txn_state_after_rollback",
				core.slots[1].qty == 3 and core.slots[2].qty == 2)
		end)

		suite("SaveLoadAdapter", function()
			local core = InventoryCore.new({ capacity = 6, maxWeight = 100 })
			local x = ItemFactory.create({
				id = "gem",
				type = "valuable",
				stackable = true,
				maxStack = 10,
				weight = 0.5
			})
			core.add(x, 7)
			local saver = StorageAdapters.SaveLoadAdapter()
			local s = saver.save(core)
			local core2 = InventoryCore.new({ capacity = 6, maxWeight = 100 })
			saver.load(core2, s)
			check("saveload_roundtrip_weight",
				math.abs(core2.weight - core.weight) < 1e-9)
			check("saveload_roundtrip_slot1",
				core2.slots[1].item ~= nil and core2.slots[1].item.id == "gem"
				and core2.slots[1].qty == 7)
			check("saveload_roundtrip_slot2",
				core2.slots[2].item ~= nil and core2.slots[2].qty == 0
				or (core2.slots[2].item == nil))
		end)

		suite("InMemoryAdapter", function()
			local core = InventoryCore.new({ capacity = 4, maxWeight = 50 })
			local it = ItemFactory.create({
				id = "ring",
				type = "accessory",
				stackable = false,
				weight = 0.1
			})
			core.add(it, 1)
			local mem = StorageAdapters.InMemoryAdapter()
			mem.save("slot1", core)
			local core2 = InventoryCore.new({ capacity = 4, maxWeight = 50 })
			mem.load("slot1", core2)
			check("inmemory_roundtrip",
				core2.slots[1].item ~= nil and core2.slots[1].item.id == "ring")
		end)

		suite("NetworkSyncAdapter", function()
			local net = StorageAdapters.NetworkSyncAdapter()
			local oldS = {
				weight = 1,
				slots = {
					{ item = { id = "a", weight = 1 }, qty = 1 },
					{ item = nil,                      qty = 0 },
				}
			}
			local newS = {
				weight = 2,
				slots = {
					{ item = { id = "a", weight = 1 }, qty = 2 }, -- changed
					{ item = { id = "b", weight = 1 }, qty = 1 }, -- added
				}
			}
			local diff = net.computeDiff(oldS, newS)
			check("diff_changed", diff.changed[1] ~= nil)
			check("diff_added", diff.added[2] ~= nil)
			local applied = net.applyDiff(oldS, diff)
			check("apply_restores_qty", applied.slots[1].qty == 2)
			check("apply_added", applied.slots[2].item.id == "b")
			local localS  = { weight = 1, slots = { { item = { id = "L", weight = 1 }, qty = 1 } } }
			local remoteS = { weight = 1, slots = { { item = { id = "R", weight = 1 }, qty = 1 } } }
			local merged  = net.mergeConflict(localS, remoteS, "server")
			check("merge_server_authoritative", merged.slots[1].item.id == "R")
			local merged2 = net.mergeConflict(localS, remoteS, "lww")
			check("merge_lww", merged2.slots[1].item.id == "R")
		end)

		suite("Fuzz", function()
			math.randomseed(12345)
			local core = InventoryCore.new({ capacity = 8, maxWeight = 200 })
			local items = {
				ItemFactory.create({ id = "coin", stackable = true, maxStack = 20, weight = 0.1 }),
				ItemFactory.create({ id = "apple", stackable = true, maxStack = 5, weight = 0.5 }),
				ItemFactory.create({ id = "sword", stackable = false, maxStack = 1, weight = 5 }),
				ItemFactory.create({ id = "shield", stackable = false, maxStack = 1, weight = 8 }),
			}
			local function invariant()
				for i = 1, core.capacity do
					local s = core.slots[i]
					if s then
						Utils.assert(s.qty >= 0, "negative qty at " .. i)
						if s.qty == 0 then
							Utils.assert(s.item == nil, "item with 0 qty at " .. i)
						end
						if s.item then
							Utils.assert(s.qty <= s.item.maxStack, "over-max stack at " .. i)
						end
					end
				end
				local w = 0
				for i = 1, core.capacity do
					local s = core.slots[i]
					if s and s.item then w = w + s.item.weight * s.qty end
				end
				Utils.assert(math.abs(w - core.weight) < 1e-6,
					"weight mismatch: " .. w .. " vs " .. core.weight)
				Utils.assert(core.weight <= core.maxWeight + 1e-6, "weight over cap")
				-- Slot uniqueness: same item id can appear in multiple slots (stacks),
				-- but a single slot must have a unique (slot index) identity. The
				-- invariant we enforce is that no slot has item with qty 0.
			end
			for iter = 1, 500 do
				local op = math.random(1, 4)
				local it = items[math.random(1, #items)]
				if op == 1 then
					core.add(it, math.random(1, 6))
				elseif op == 2 then
					core.remove(it.id, math.random(1, 6))
				elseif op == 3 then
					local i = math.random(1, core.capacity)
					local j = math.random(1, core.capacity)
					core.move(i, j)
				elseif op == 4 then
					local i = math.random(1, core.capacity)
					core.split(i, math.random(1, 3))
				end
				invariant()
			end
			check("fuzz_completed_invariants", true)
		end)

		-- Final summary
		print(string_format("\n[Tests] passed=%d failed=%d", passCount, failCount))
		if failCount > 0 then
			print("[Tests] FAILURES:")
			for i = 1, #failures do print("  - " .. failures[i]) end
		end
		return failCount == 0
	end
end

----------------------------------------------------------------------
-- ExampleUsage
----------------------------------------------------------------------
local ExampleUsage = {}

---@usage <br>
--- ```
--- ExampleUsage.run() -- prints inventory operations demo
--- ```
function ExampleUsage.run()
	print("\n-- ExampleUsage begin")

	-- 1. Item creation with custom behaviors (Open/Closed).
	ItemFactory.registerBehavior("consumable", {
		onUse = function(item, ctx)
			return "Drank " .. item.id .. " (" .. (ctx and ctx.who or "?") .. ")"
		end,
	})
	ItemFactory.registerBehavior("equippable", {
		onUse = function(item, ctx)
			return "Equipped " .. item.id .. " on " .. (ctx and ctx.who or "?")
		end,
	})

	local potion     = ItemFactory.create({
		id = "potion",
		type = "consumable",
		stackable = true,
		maxStack = 5,
		weight = 0.3
	})
	local helmet     = ItemFactory.create({
		id = "helmet",
		type = "equippable",
		stackable = false,
		weight = 2
	})
	local arrow      = ItemFactory.create({
		id = "arrow",
		type = "ammo",
		stackable = true,
		maxStack = 20,
		weight = 0.1
	})
	local sword      = ItemFactory.create({
		id = "sword",
		type = "weapon",
		stackable = false,
		weight = 5
	})

	-- 2. Build inventories (client & server simulation).
	local clientCore = InventoryCore.new({ capacity = 8, maxWeight = 100 })
	local serverCore = InventoryCore.new({ capacity = 8, maxWeight = 100 })
	local ui         = UIAdapterExample.new(clientCore)

	-- 3. Add/remove/stack/split on the client.
	clientCore.add(potion, 3)
	clientCore.add(arrow, 45) -- spans 3 slots (20 + 20 + 5)
	clientCore.add(sword, 1)
	clientCore.split(1, 1) -- split potion stack
	clientCore.remove("arrow", 5)

	print("-- Client inventory after ops")
	print(ui.render())

	-- 4. Behavior invocation (Open/Closed demonstration).
	print("\n-- Behavior invocations")
	print(ItemFactory.invoke(potion, "onUse", { who = "Hero" }))
	print(ItemFactory.invoke(helmet, "onUse", { who = "Hero" }))

	-- 5. Transactional multi-slot operation.
	local tx = TransactionManager.new(clientCore)
	local ok = tx.atomicAdd({
		{ item = arrow,  qty = 10 },
		{ item = helmet, qty = 1 },
	})
	print("\n-- Transactional atomicAdd result: " .. tostring(ok))
	print(ui.render())

	-- 6. Simulated save/load roundtrip.
	local saver = StorageAdapters.SaveLoadAdapter()
	local saved = saver.save(clientCore)
	local restoredCore = InventoryCore.new({ capacity = 8, maxWeight = 100 })
	saver.load(restoredCore, saved)
	print("\n-- Restored inventory (SaveLoad)")
	print(UIAdapterExample.new(restoredCore):render())

	-- 7. Simulated client/server sync with conflict resolution.
	-- Server starts in the same state as the client's pre-save snapshot.
	saver.load(serverCore, saver.save(clientCore))
	-- Now both diverge:
	--   Client: removes 1 potion, adds 1 sword.
	--   Server: adds 5 arrows (server authoritative).
	clientCore.remove("potion", 1)
	clientCore.add(sword, 1)

	serverCore.add(arrow, 5)

	local net        = StorageAdapters.NetworkSyncAdapter()
	local localSnap  = clientCore.snapshot()
	local remoteSnap = serverCore.snapshot()
	-- For demo, we manually fix snapshot slots count to capacity (snapshot
	-- already has all slots 1..capacity).
	print("\n-- Sync reconciliation (server-authoritative)")
	local merged = net.mergeConflict(localSnap, remoteSnap, "server")
	-- Apply merged state back to client.
	clientCore.setSuppress(true)
	clientCore.restore({ weight = merged.weight, slots = merged.slots })
	clientCore.setSuppress(false)
	print(ui.render())

	-- 8. Diff demonstration.
	local diff = net.computeDiff(localSnap, merged)
	local diffCount = 0
	for _ in next, diff.added do diffCount = diffCount + 1 end
	for _ in next, diff.changed do diffCount = diffCount + 1 end
	for _ in next, diff.removed do diffCount = diffCount + 1 end
	print(string_format("Diff entries between local and merged: %d", diffCount))

	-- release snapshots to pools
	Utils.pool.release("snapshot", localSnap)
	Utils.pool.release("snapshot", remoteSnap)

	print("-- ExampleUsage complete\n")
end

----------------------------------------------------------------------
-- Public API
----------------------------------------------------------------------

--- Advanced inventory system with modular, robust in-game inventory management
---@class InventorySystem
---@field Structure table Module structure documentation
---@field Utils table Utility functions (assert, shallowCopy, copyMeta, newIdGenerator, pool)
---@field Contracts table Contract definitions and validation
---@field ItemFactory table Item creation, cloning, serialization, and behavior management
---@field StackManager table Stack operations (findStackable, findEmpty, merge, split)
---@field InventoryCore table Core inventory instance factory
---@field TransactionManager table Transaction management for atomic operations
---@field EventDispatcher table Event pub/sub system with batching support
---@field StorageAdapters table Storage adapters (InMemory, SaveLoad, NetworkSync)
---@field UIAdapterExample table Example textual UI adapter
---@field Tests table Test suite
---@field ExampleUsage table Example usage demonstration
---@field DEBUG boolean Debug flag for validation
local InventorySystem = {
	Structure          = Structure,
	Utils              = Utils,
	Contracts          = Contracts,
	ItemFactory        = ItemFactory,
	StackManager       = StackManager,
	InventoryCore      = InventoryCore,
	TransactionManager = TransactionManager,
	EventDispatcher    = EventDispatcher,
	StorageAdapters    = StorageAdapters,
	UIAdapterExample   = UIAdapterExample,
	Tests              = Tests,
	ExampleUsage       = ExampleUsage,
	DEBUG              = DEBUG,
}

local function main()
	local ok = Tests.run()
	ExampleUsage.run()
	if not ok and os and os.exit then
		os.exit(1)
	end
	return InventorySystem
end

--main()

-- Export
return InventorySystem
