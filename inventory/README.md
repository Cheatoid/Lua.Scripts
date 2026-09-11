# Inventory Systems

A collection of Lua inventory implementations providing slot-based, weight-bounded game inventory management with stacking, transactions, persistence, networking, and event-driven UI.

## Files

| File                     | Purpose                                                                                                              | Status |
| ------------------------ | -------------------------------------------------------------------------------------------------------------------- | ------ |
| `advanced_inventory.lua` | Performance-oriented implementation with categorized pools, string serialization, and client/server sync demo        | Stable |
| `inventory.lua`          | Full reference implementation with pooled slots, deep serialization, coalesced events, and deterministic fuzz tests  | Stable |
| `inv.lua`                | Legacy standalone implementation (no exports). Metatable-based OOP, simpler serialization, subscribe/unsubscribe API | Legacy |

All three files share the same architectural shape: `Utils` -> `Contracts` -> `ItemFactory` -> `StackManager` -> `EventDispatcher` -> `InventoryCore` -> `TransactionManager` -> `StorageAdapters` -> `UIAdapterExample` -> `Tests` -> `ExampleUsage`.

## Naming Convention

Canonical API names use `camelCase`. Deprecated `snake_case` aliases are kept for
compatibility and delegate to the `camelCase` implementation. New code should use
`camelCase`; examples below use canonical names.

Module-level aliases (end of each file):

- `advanced_inventory.lua`: `Utils.shallow_copy` / `copy_meta` / `new_id_generator`,
  `ItemFactory.register_behavior`, `StackManager.find_stackable` / `find_empty`,
  per-instance `adapter.compute_diff` / `apply_diff` / `merge_conflict`
  (set inside `StorageAdapters.NetworkSyncAdapter()`; the stray file-scope
  `adapter.*` assignments are guarded with `if type(adapter) == "table"` so a
  missing global no longer breaks load).
- `inventory.lua`: `Utils.shallow_copy` / `deep_copy` / `new_id` / `assert_arg` /
  `new_pool` / `new_rng`, `Contracts.check_item` / `check_inventory` /
  `check_storage_adapter` / `check_ui_adapter` / `check_event_dispatcher`,
  `EventDispatcher.emit_coalesced` / `begin_batch` / `end_batch`,
  `ItemFactory.register_behavior` / `to_table` / `from_table` / `use_item`,
  `StackManager.can_stack` / `find_partial_slots` / `find_empty_slot`,
  `InventoryCore.notify_slot` / `get_slot` / `list_items` / `recompute_weight` /
  `to_state` / `apply_state`, `TransactionManager.atomic_add` / `atomic_remove`,
  `StorageAdapters.new_in_memory_adapter` / `new_save_load_adapter` /
  `new_network_sync_adapter`, `Tests.run_all`.
- `inv.lua` (legacy, locals only): `Contracts.validate_item`, `Utils.gen_id` /
  `shallow_copy` / `acquire_table` / `release_table` / `release_list`,
  `ItemFactory.register_behavior` / `get_behavior`,
  `StackManager.find_stackable_slot` / `find_empty_slot` / `merge_into`,
  `EventDispatcher.begin_batch` / `end_batch`, `InventoryCore.get_slot` /
  `list_items` / `get_weight` / `get_capacity` / `remove_by_type` / `load_snapshot`,
  `TransactionManager.atomic_add`, `Tests.run_unit` / `run_integration` / `run_fuzz` /
  `run_all`.

Per-instance aliases (set on the created object, not the module table):

- `advanced_inventory.lua` `EventDispatcher` instance: `begin_batch`, `end_batch`.
- `advanced_inventory.lua` `InventoryCore` instance: `get_slot`, `list_items`,
  `release_list`, `set_suppress`, `total_weight`.
- `advanced_inventory.lua` `TransactionManager` instance: `atomic_add`,
  `atomic_remove` (both defined before `return self`; previously `atomic_remove`
  was a stray line after `end` and broke load with `index nil (global 'self')`).
- `advanced_inventory.lua` `NetworkSyncAdapter()` instance: `compute_diff`,
  `apply_diff`, `merge_conflict`.

## Features

- **Slot & Weight Capacity**: Configurable slot count and total weight limit
- **Stacking / Splitting / Merging**: Automatic stack filling, stack splitting to empty slots, and stack merging
- **Transactions**: Atomic multi-step operations with snapshot-based rollback
- **Event System**: Pub/sub with batching and coalescing to reduce event noise during bulk operations
- **Pluggable Persistence**: In-memory, string serialize/deserialize, and network sync adapters
- **Item Behaviors**: Register `onUse`/`onEquip` callbacks per item type (Open/Closed principle)
- **UI Adapter**: Event-driven text renderer; core modules perform zero I/O
- **Test Suite**: Unit tests, integration tests, and deterministic fuzz tests with invariant checking

## Installation

```lua
-- Pick one of the two exported implementations:
local inv = require "inventory"           -- reference impl
local inv = require "advanced_inventory"  -- advanced impl
-- NOTE: inv.lua is a standalone legacy file that does NOT export any API.
-- Its modules are local-only; see inv.lua section for internal usage.
```

## Architecture

```
+-------------------------------------------------+
|               UIAdapterExample                  |  <- presentation only
+-------------------------------------------------+
|              TransactionManager                 |  <- atomic ops + rollback
+-------------------------------------------------+
|                InventoryCore                    |  <- slot/weight state + ops
+--------------+--------------+-------------------+
| StackManager | ItemFactory  |  EventDispatcher  |  <- pure logic / factory / events
+--------------+--------------+-------------------+
|     StorageAdapters (InMemory / SaveLoad / Net) |  <- persistence
+-------------------------------------------------+
|               Utils + Contracts                 |  <- foundation
+-------------------------------------------------+
```

## Usage

### Quick Start (`advanced_inventory.lua`)

```lua
local inv = require "advanced_inventory"

local inventory = inv.InventoryCore.new({
    capacity  = 20,
    maxWeight = 100,
})

local potion = inv.ItemFactory.create({
    id = "potion", type = "consumable", stackable = true,
    maxStack = 8, weight = 0.3,
})

local added = inventory.add(potion, 5)  -- note: closure, uses . not :
print("Added " .. added .. " potions")

local items = inventory.listItems()
for _, entry in ipairs(items) do
    print(entry.item.id .. " x" .. entry.qty)
end
inventory.releaseList(items)  -- required: return to pool
```

### Quick Start (`inventory.lua`)

```lua
local inv = require "inventory"

local dispatcher = inv.EventDispatcher.new()
local inventory = inv.InventoryCore.new({
    capacity   = 20,
    maxWeight  = 100,
    dispatcher = dispatcher,  -- optional: enables events
})

local potion = inv.ItemFactory.create({
    id = "potion", type = "consumable", stackable = true,
    maxStack = 8, weight = 1, attrs = { heal = 25 },
})
local sword = inv.ItemFactory.create({
    id = "sword", type = "equippable", stackable = false,
    weight = 5, attrs = { slot = "hand" },
})

local added = inventory:add(potion, 5)
print("Added " .. added .. " potions")

local items = inventory:listItems()
for i = 1, items.n do
    print(items[i].id .. " x" .. items[i].count)
end
```

### Quick Start (`inv.lua`)

`inv.lua` does not export anything. The modules are local. This is how the
internal `ExampleUsage.run()` uses them:

```lua
-- These are local variables inside inv.lua -- not accessible via require.
local events    = EventDispatcher.new()
local inventory = InventoryCore.new({
    maxSlots  = 20,
    maxWeight = 100,
    events    = events,
})

local potion = ItemFactory.create({
    type = "potion", maxStack = 8, weight = 0.3, qty = 1,
})

inventory:add(potion, 5)  -- returns true/false, err (not quantity)

local list = inventory:listItems()
for _, item in ipairs(list) do
    print(item.type .. " x" .. item.qty)
end
Utils.releaseList(list)  -- required: return to pool
```

### Transactions

#### `advanced_inventory.lua`

```lua
local inv = require "advanced_inventory"
local tx = inv.TransactionManager.new(inventory)

tx.begin()
local added = inventory.add(potion, 3)
if added < 3 then
    tx.rollback()
else
    tx.commit()
end
```

#### `inventory.lua`

```lua
local inv = require "inventory"
local tx = inv.TransactionManager.new(inventory)

local ok, err = tx:atomicAdd({
    { item = potion, qty = 3 },
    { item = sword, qty = 1 },
})
if not ok then
    print("Transaction failed: " .. tostring(err))
end
```

#### `inv.lua`

Internal usage (local variables within `inv.lua`):

```lua
local tx = TransactionManager.new(inventory)

local ok, err = tx:atomicAdd({
    { type = "potion", maxStack = 5, weight = 0.3, qty = 3 },
    { type = "sword", stackable = false, maxStack = 1, weight = 3.0, qty = 1 },
})
```

### Storage Adapters

#### `advanced_inventory.lua`

```lua
local inv = require "advanced_inventory"

local mem = inv.StorageAdapters.InMemoryAdapter()
mem.save("slot1", inventory)
mem.load("slot1", inventory)

local saver = inv.StorageAdapters.SaveLoadAdapter()
local data = saver.save(inventory)  -- returns serialized string
saver.load(inventory, data)

local net = inv.StorageAdapters.NetworkSyncAdapter()
local localSnap = inventory.snapshot()
local remoteSnap = otherInventory.snapshot()
local diff = net.computeDiff(localSnap, remoteSnap)
local merged = net.mergeConflict(localSnap, remoteSnap, "server")
```

#### `inventory.lua`

```lua
local inv = require "inventory"

local mem = inv.StorageAdapters.newInMemoryAdapter()
inv.StorageAdapters.persist(mem, inventory)
inv.StorageAdapters.restore(mem, inventory)

local saver = inv.StorageAdapters.newSaveLoadAdapter()
local ok = inv.StorageAdapters.persist(saver, inventory)
inv.StorageAdapters.restore(saver, inventory)
```

#### `inv.lua`

Internal usage (local variables within `inv.lua`):

```lua
-- In-memory
local mem = StorageAdapters.InMemoryAdapter()
mem.save(inventory:snapshot())
local loaded = mem.load()

-- String-based persistence
local saver = StorageAdapters.SaveLoadAdapter()
saver.save(inventory:snapshot())
saver.saveExact(inventory:snapshot())  -- exact round-trip
local state = saver.load()

-- Network sync
local net = StorageAdapters.NetworkSyncAdapter()
local diff = net.computeDiff(oldState, newState)
local applied = net.applyDiff(oldState, diff)
local merged = net.mergeConflict(localState, remoteState, "server_authoritative")
```

### Event-Driven UI

#### `advanced_inventory.lua`

```lua
local inv = require "advanced_inventory"

local ui = inv.UIAdapterExample.new(inventory)
print(ui.render())  -- returns string, does not print directly
```

#### `inventory.lua`

```lua
local inv = require "inventory"

local ui = inv.UIAdapterExample.new(inventory, print)
ui:attach()
ui:render()

inventory:add(potion, 1)

ui:detach()
```

### Item Behaviors

#### `advanced_inventory.lua`

```lua
local inv = require "advanced_inventory"

inv.ItemFactory.registerBehavior("consumable", {
    onUse = function(item, ctx)
        return "Drank " .. item.id .. " (" .. (ctx and ctx.who or "?") .. ")"
    end,
})

local result = inv.ItemFactory.invoke(potion, "onUse", { who = "Hero" })
print(result)
```

#### `inventory.lua`

```lua
local inv = require "inventory"

inv.ItemFactory.registerBehavior("consumable", {
    onUse = function(inv, slot, context)
        local heal = slot.item.attrs.heal or 0
        print("Healed " .. (context and context.target or "?") .. " for " .. heal .. " HP")
        return true
    end,
})

inv.ItemFactory.useItem(inventory, slotIndex, { target = "Hero" })
```

## API Reference

> API tables are organized per implementation in order: `advanced_inventory.lua`, `inventory.lua`, `inv.lua`.

---

### `advanced_inventory.lua`

Methods on `InventoryCore` are closures (use `.` not `:`).

#### InventoryCore

| Method        | Signature                             | Description                                          |
| ------------- | ------------------------------------- | ---------------------------------------------------- |
| `new`         | `(opts) -> inv`                       | Create inventory (`capacity`, `maxWeight`, `events`) |
| `add`         | `(item, qty?) -> added`               | Returns quantity actually added                      |
| `remove`      | `(itemId, qty?) -> removed`           | Returns quantity actually removed                    |
| `move`        | `(slotFrom, slotTo) -> ok`            | Swap slots (always returns `true`)                   |
| `split`       | `(slot, qty) -> ok`                   | Split qty to an empty slot                           |
| `merge`       | `(slotA, slotB) -> moved`             | Returns quantity moved                               |
| `getSlot`     | `(index) -> {slot, item, qty} or nil` | Returns copy of slot data                            |
| `listItems`   | `() -> table`                         | Returns pooled array; **must call `releaseList`**    |
| `releaseList` | `(list)`                              | Return list and entries to pool                      |
| `snapshot`    | `() -> snap`                          | Take snapshot for rollback                           |
| `restore`     | `(snap)`                              | Restore from snapshot                                |
| `setSuppress` | `(flag)`                              | Suppress event emission (used by TransactionManager) |
| `totalWeight` | `() -> weight`                        | Get total weight                                     |

Instance aliases: `get_slot`, `list_items`, `release_list`, `set_suppress`, `total_weight`.

**Not available**: `toState`, `applyState`, `recomputeWeight`, `recycle`, `notifySlot`

#### TransactionManager

| Method         | Signature         | Description                     |
| -------------- | ----------------- | ------------------------------- |
| `new`          | `(core) -> tx`    | Wrap inventory for transactions |
| `begin`        | `() -> self`      | Take snapshot, suppress events  |
| `commit`       | `() -> true`      | Accept changes                  |
| `rollback`     | `() -> false`     | Revert to snapshot              |
| `atomicAdd`    | `(pairs) -> bool` | Atomic multi-add                |
| `atomicRemove` | `(pairs) -> bool` | Atomic multi-remove             |

Instance aliases: `atomic_add`, `atomic_remove`.

#### EventDispatcher

| Method        | Signature                      | Description                       |
| ------------- | ------------------------------ | --------------------------------- |
| `subscribe`   | `(event, handler) -> unsub fn` | Subscribe; returns unsubscribe fn |
| `unsubscribe` | `(event, handler)`             | Remove handler                    |
| `emit`        | `(event, payload)`             | Deliver to all handlers           |
| `beginBatch`  | `()`                           | Start batching (nesting-safe)     |
| `endBatch`    | `()`                           | Flush queued events               |

Coalescing: per event name within batch.

Instance aliases: `begin_batch`, `end_batch`.

#### ItemFactory

| Method             | Signature                       | Description                     |
| ------------------ | ------------------------------- | ------------------------------- |
| `create`           | `(spec) -> item`                | Create item from definition     |
| `clone`            | `(item) -> item`                | Clone with new uid              |
| `serialize`        | `(item) -> string`              | Serialize to pipe-delimited     |
| `deserialize`      | `(str) -> item`                 | Deserialize from string         |
| `registerBehavior` | `(typeName, behaviorTable)`     | Register onUse/validate         |
| `invoke`           | `(item, action, ctx) -> result` | Dispatch to registered behavior |

**Not available**: `toTable`, `fromTable`, `useItem`, `getBehavior`

#### StackManager

| Function        | Signature                        | Description              |
| --------------- | -------------------------------- | ------------------------ |
| `findStackable` | `(slots, item, capacity) -> idx` | Find slot that can stack |
| `findEmpty`     | `(slots, capacity) -> idx`       | Find first empty slot    |
| `merge`         | `(slotA, slotB) -> moved`        | Merge B into A           |
| `split`         | `(slot, qty) -> slot`            | Split qty to new slot    |

**Not available**: `canStack`, `findPartialSlots`, `transfer`

#### StorageAdapters

| Adapter              | Signature                               | Description                                 |
| -------------------- | --------------------------------------- | ------------------------------------------- |
| `InMemoryAdapter`    | `()` -> adapter                         | Key-based in-memory backend                 |
| `InMemory.save`      | `adapter.save(key, core)`               | Save inventory state                        |
| `InMemory.load`      | `adapter.load(key, core)`               | Load inventory state                        |
| `SaveLoadAdapter`    | `()` -> adapter                         | String serialize/deserialize                |
| `SaveLoad.save`      | `adapter.save(core) -> string`          | Serialize and return string                 |
| `SaveLoad.load`      | `adapter.load(core, str)`               | Deserialize from string                     |
| `NetworkSyncAdapter` | `()` -> adapter                         | Network sync backend                        |
| `Net.computeDiff`    | `adapter.computeDiff(old, new) -> diff` | Slot-level diff                             |
| `Net.applyDiff`      | `adapter.applyDiff(state, diff) -> out` | Apply diff to state                         |
| `Net.mergeConflict`  | `adapter.mergeConflict(l, r, strategy)` | Conflict resolution (`"server"` \| `"lww"`) |

Snake_case instance aliases: `compute_diff`, `apply_diff`, `merge_conflict`.

#### UIAdapterExample

| Feature     | Signature          | Description                              |
| ----------- | ------------------ | ---------------------------------------- |
| Constructor | `(core)`           | Auto-subscribes to events on creation    |
| `render`    | `() -> string`     | Returns textual inventory representation |
| `onEvent`   | `(event, payload)` | Internal event handler                   |

---

### `inventory.lua`

#### InventoryCore

| Method            | Signature                   | Description                                                              |
| ----------------- | --------------------------- | ------------------------------------------------------------------------ |
| `new`             | `(config) -> inv`           | Create inventory (`capacity`, `maxWeight`, `dispatcher`, `stackManager`) |
| `add`             | `(item, qty?) -> added`     | Add items; returns quantity actually added                               |
| `remove`          | `(itemId, qty?) -> removed` | Remove by item id; returns quantity removed                              |
| `move`            | `(slotFrom, slotTo) -> ok`  | Swap or stack-transfer between slots                                     |
| `split`           | `(slotIndex, qty) -> ok`    | Split qty from a stack to an empty slot                                  |
| `merge`           | `(slotA, slotB) -> ok`      | Merge slotB into slotA (stackable only)                                  |
| `getSlot`         | `(index) -> slot`           | Read-only access to a slot                                               |
| `listItems`       | `(out?) -> table`           | List occupied slots with `{slot, id, count, item}`; has `.n` field       |
| `toState`         | `() -> state`               | Plain-state snapshot for persistence/networking                          |
| `applyState`      | `(state) -> ok`             | Restore from a plain-state snapshot                                      |
| `recomputeWeight` | `() -> weight`              | Recalculate total weight from slots                                      |
| `recycle`         | `()`                        | Return all slot tables to the pool                                       |

#### TransactionManager

| Method         | Signature               | Description                      |
| -------------- | ----------------------- | -------------------------------- |
| `new`          | `(inv) -> tx`           | Wrap inventory for txns          |
| `begin`        | `() -> true`            | Take snapshot                    |
| `commit`       | `() -> true`            | Discard snapshot                 |
| `rollback`     | `() -> true`            | Restore snapshot                 |
| `atomic`       | `(fn) -> ok, err`       | Run fn(inv) all-or-nothing       |
| `atomicAdd`    | `(entries) -> ok, err`  | Add multiple items atomically    |
| `atomicRemove` | `(requests) -> ok, err` | Remove multiple items atomically |

#### EventDispatcher

| Method          | Signature               | Description                         |
| --------------- | ----------------------- | ----------------------------------- |
| `on`            | `(event, fn) -> handle` | Subscribe; returns handle for `off` |
| `off`           | `(handle) -> ok`        | Unsubscribe (safe mid-emit)         |
| `emit`          | `(event, payload)`      | Deliver to all handlers             |
| `emitCoalesced` | `(event, key, payload)` | Queue with dedup by key             |
| `beginBatch`    | `()`                    | Start batching (nesting-safe)       |
| `endBatch`      | `()`                    | Flush queued events                 |

Coalescing: per key within batch.

#### ItemFactory

| Method             | Signature                     | Description                     |
| ------------------ | ----------------------------- | ------------------------------- |
| `create`           | `(def, count?) -> item`       | Create item from definition     |
| `clone`            | `(item, keepUid?) -> item`    | Clone with new uid (or same)    |
| `serialize`        | `(item) -> string`            | Serialize item to string        |
| `deserialize`      | `(str) -> item`               | Deserialize item from string    |
| `toTable`          | `(item) -> table`             | Serialize item to plain table   |
| `fromTable`        | `(t) -> item`                 | Deserialize item from table     |
| `registerBehavior` | `(type, behavior)`            | Register onUse/validate         |
| `useItem`          | `(inv, slotIndex, ctx) -> ok` | Dispatch to registered behavior |

**Not available**: `invoke`, `getBehavior`

#### StackManager

| Function           | Signature                  | Description                     |
| ------------------ | -------------------------- | ------------------------------- |
| `canStack`         | `(a, b) -> bool`           | Check if two items can stack    |
| `findPartialSlots` | `(inv, item, out) -> out`  | Find slots that can absorb item |
| `findEmptySlot`    | `(inv) -> idx`             | Find first empty slot index     |
| `transfer`         | `(inv, from, to) -> moved` | Move units between slots (O(1)) |

**Not available**: `findStackable`, `findEmpty`, `merge`, `split`

#### StorageAdapters

| Adapter                 | Signature                                    | Description                         |
| ----------------------- | -------------------------------------------- | ----------------------------------- |
| `persist`               | `(adapter, inv) -> ok, err`                  | Save inventory state via adapter    |
| `restore`               | `(adapter, inv) -> ok, err`                  | Restore inventory state via adapter |
| `newInMemoryAdapter`    | `(backend?) -> adapter`                      | In-memory backend                   |
| `InMemory.save`         | `adapter:save(state)`                        | Save state to memory                |
| `InMemory.load`         | `adapter:load()`                             | Load state from memory              |
| `newSaveLoadAdapter`    | `(initialBlob?) -> adapter`                  | String serialize/deserialize        |
| `SaveLoad.save`         | `adapter:save(state)`                        | Serialize state to string           |
| `SaveLoad.load`         | `adapter:load()`                             | Deserialize state from string       |
| `newNetworkSyncAdapter` | `() -> adapter`                              | Network sync backend                |
| `Net.computeDiff`       | `NetworkSync.computeDiff(old, new) -> diff`  | Slot-level diff                     |
| `Net.mergeConflict`     | `NetworkSync.mergeConflict(l, r, mode) -> m` | Conflict resolution                 |

#### UIAdapterExample

| Feature     | Signature         | Description                             |
| ----------- | ----------------- | --------------------------------------- |
| Constructor | `(inv, writeFn?)` | Optional write function (default print) |
| `attach`    | `()`              | Subscribe to slotChanged, txRolledBack  |
| `detach`    | `()`              | Unsubscribe from events                 |
| `render`    | `()`              | Print inventory via writeFn             |

---

### `inv.lua` (internal -- not exported)

Methods on `InventoryCore` use metatable `:` syntax. Uses `maxSlots` not `capacity`.
All modules are local to the file. This section documents the internal API for reference.

#### InventoryCore

| Method         | Signature                     | Description                                            |
| -------------- | ----------------------------- | ------------------------------------------------------ |
| `new`          | `(opts) -> inv`               | Create inventory (`maxSlots`, `maxWeight`, `events`)   |
| `add`          | `(item, qty?) -> ok, err`     | Returns boolean + error string on failure              |
| `remove`       | `(itemId, qty?) -> ok, err`   | Returns boolean + error string                         |
| `removeByType` | `(typeName, qty?) -> ok, err` | Remove by item type                                    |
| `move`         | `(from, to) -> ok, err`       | Swap or merge                                          |
| `split`        | `(slotIdx, qty) -> ok, err`   | Split to empty slot                                    |
| `merge`        | `(slotA, slotB) -> ok, err`   | Merge stacks                                           |
| `getSlot`      | `(index) -> item or nil`      | Returns raw item in slot                               |
| `listItems`    | `() -> list`                  | Returns pooled list; **must call `Utils.releaseList`** |
| `getWeight`    | `() -> number`                | Get current weight                                     |
| `getCapacity`  | `() -> maxSlots, maxWeight`   | Get capacity info                                      |
| `snapshot`     | `() -> snap`                  | Take snapshot                                          |
| `loadSnapshot` | `(snap)`                      | Restore from snapshot                                  |

**Not available**: `toState`, `applyState`, `recomputeWeight`, `recycle`, `remove` (by id returning qty)

#### TransactionManager

| Method      | Signature            | Description                  |
| ----------- | -------------------- | ---------------------------- |
| `new`       | `(inv) -> tx`        | Wrap inventory for txns      |
| `begin`     | `()`                 | Take snapshot + begin batch  |
| `commit`    | `() -> true`         | Discard snapshot + end batch |
| `rollback`  | `() -> true`         | Restore snapshot + end batch |
| `atomicAdd` | `(items) -> ok, err` | Atomic multi-add             |

**Not available**: `atomic`, `atomicRemove`

#### EventDispatcher

| Method        | Signature                    | Description                   |
| ------------- | ---------------------------- | ----------------------------- |
| `subscribe`   | `(eventType, handler) -> id` | Subscribe; returns numeric id |
| `unsubscribe` | `(id)`                       | Remove by id                  |
| `emit`        | `(eventType, payload)`       | Deliver to all handlers       |
| `beginBatch`  | `()`                         | Start batching (nesting-safe) |
| `endBatch`    | `()`                         | Flush queued events           |

Coalescing: per event type within batch.

#### ItemFactory

| Method             | Signature                      | Description                 |
| ------------------ | ------------------------------ | --------------------------- |
| `create`           | `(opts) -> item`               | Create item from definition |
| `clone`            | `(item, qtyOverride?) -> item` | Clone with optional qty     |
| `serialize`        | `(item) -> table`              | Serialize item to Lua table |
| `deserialize`      | `(data) -> item`               | Deserialize item from table |
| `registerBehavior` | `(typeName, behaviorTable)`    | Register onUse/validate     |
| `getBehavior`      | `(typeName) -> behavior`       | Look up registered behavior |

**Not available**: `toTable`, `fromTable`, `useItem`, `invoke`

#### StackManager

| Function            | Signature                        | Description              |
| ------------------- | -------------------------------- | ------------------------ |
| `findStackableSlot` | `(slots, item, maxSlots) -> idx` | Find slot that can stack |
| `findEmptySlot`     | `(slots, maxSlots) -> idx`       | Find first empty slot    |
| `mergeInto`         | `(dst, src) -> moved`            | Merge src into dst       |
| `split`             | `(item, qty) -> item`            | Split qty to new item    |

**Not available**: `canStack`, `findPartialSlots`, `transfer`

#### StorageAdapters

| Adapter              | Signature                                    | Description                  |
| -------------------- | -------------------------------------------- | ---------------------------- |
| `InMemoryAdapter`    | `()` -> adapter                              | In-memory backend            |
| `InMemory.save`      | `adapter.save(state)`                        | Save snapshot to memory      |
| `InMemory.load`      | `adapter.load()`                             | Load snapshot from memory    |
| `SaveLoadAdapter`    | `()` -> adapter                              | String serialize/deserialize |
| `SaveLoad.save`      | `adapter.save(state)`                        | Serialize state              |
| `SaveLoad.saveExact` | `adapter.saveExact(state)`                   | Exact round-trip serialize   |
| `SaveLoad.load`      | `adapter.load()`                             | Deserialize state            |
| `NetworkSyncAdapter` | `()` -> adapter                              | Network sync backend         |
| `Net.computeDiff`    | `adapter.computeDiff(old, new) -> diff`      | Slot-level diff              |
| `Net.applyDiff`      | `adapter.applyDiff(state, diff) -> state`    | Apply diff to state          |
| `Net.mergeConflict`  | `adapter.mergeConflict(l, r, strategy) -> m` | Conflict resolution          |

#### UIAdapterExample

| Feature     | Signature     | Description                    |
| ----------- | ------------- | ------------------------------ |
| Constructor | `(inventory)` | Subscribes to events on create |
| `render`    | `()`          | Print inventory via print      |

---

## Item Contract

```lua
{
    id        = string,        -- unique item type identifier
    type      = string,        -- category (e.g. "consumable", "weapon")
    stackable = boolean,       -- whether items stack
    maxStack  = number,        -- max quantity per slot (>= 1)
    weight    = number,        -- weight per unit (>= 0)
    attrs     = table,         -- arbitrary metadata

    -- inventory.lua only:
    uid       = string,        -- unique instance id
    count     = number,        -- current stack count

    -- inv.lua / advanced_inventory.lua:
    qty       = number,        -- current stack count (inv.lua: set at creation)
}
```

## Slot Contract

```lua
-- inventory.lua
{ index = number, item = Item|nil, count = number, rev = number }

-- advanced_inventory.lua
{ item = Item|nil, qty = number }

-- inv.lua
-- Slots are raw item tables directly in the slots array (no wrapper)
```

## Performance Notes

- **Object pooling**: Slots and scratch lists are pooled to minimize GC pressure on hot paths
- **Weight checks**: O(1) capacity gate before scanning slots
- **add()**: O(S) scan for partial stacks + O(K) fills; one `ItemFactory.clone` per new stack
- **remove()**: O(S) single scan; zero allocations
- **move()**: O(1) direct swap or stack transfer; zero allocations
- **split()**: O(S) empty-slot scan; one clone for the new stack
- **merge()**: O(1); zero allocations
- **Events**: Coalesced per slot index -- multi-step ops produce at most one event per touched slot (`inventory.lua`)

## Differences Between Implementations

| Feature              | `advanced_inventory.lua`        | `inventory.lua`             | `inv.lua`                   |
| -------------------- | ------------------------------- | --------------------------- | --------------------------- |
| Call syntax          | `.` (closures)                  | `:` (self param)            | `:` (self param)            |
| Slot capacity key    | `capacity`                      | `capacity`                  | `maxSlots`                  |
| Event injection key  | `events`                        | `dispatcher`                | `events`                    |
| Slot fields          | `item`, `qty`                   | `item`, `count`, `rev`      | item table directly         |
| Pooling              | `Pool` with categories          | `Utils.newPool()`           | Global pool                 |
| Serialization        | Pipe-delimited string           | Recursive Lua literal       | Simple key=value            |
| Event API            | `subscribe`/`unsubscribe`       | `on`/`off`/`emitCoalesced`  | `subscribe`/`unsubscribe`   |
| Transaction rollback | `restore` snapshot              | Slot-level snapshot/restore | `loadSnapshot` on inventory |
| Network sync         | Diff by slot comparison         | Diff by slot signature      | Diff by item id/qty/type    |
| `add` returns        | `number` (qty added)            | `number` (qty added)        | `boolean, string?`          |
| `remove` returns     | `number` (qty removed)          | `number` (qty removed)      | `boolean, string?`          |
| `merge` returns      | `number` (qty moved)            | `boolean`                   | `boolean`                   |
| `listItems`          | Returns pooled list             | Returns table with `.n`     | Returns pooled list         |
| Export               | Returns `InventorySystem` table | Returns API table           | Returns `{}` (TODO)         |
| Lua compatibility    | Lua 5.1+                        | Lua 5.1+                    | Lua 5.1+                    |

## Running Tests

Each file contains an embedded test suite:

```lua
-- advanced_inventory.lua
local sys = require "advanced_inventory"
sys.Tests.run()
sys.ExampleUsage.run()

-- inventory.lua
-- Tests run automatically when file is executed (call main() to run)

-- inv.lua
-- Standalone legacy file: run directly with Lua to execute tests.
-- All modules are local; no exports available.
lua inv.lua
```

## License

MIT License
