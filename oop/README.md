# OOP

Feature-rich object-oriented programming library for Lua with classes, inheritance,
interfaces, mixins, properties, events, hooking, AOP, promises via coroutines,
integrated profiler, and more.

Single file: `oop/oop.lua`. No build step.

```lua
local oop = require "../oop" -- from oop/collections/*, e.g. ArrayPool.lua:27
-- or via your loader:
-- local oop = require "@cheatoid/oop/oop"
```

## Naming Convention

Canonical API names use `camelCase`. Deprecated `snake_case` aliases are kept for
compatibility and delegate to the `camelCase` implementation. New code should use
`camelCase`; examples below use canonical names.

`oop.*` aliases are unconditional (safe: `oop` always exists). Aliases for
function-scoped instances (`promise`, `pool`, `stream`, `newClass`, `interface`,
`abstractClass`, `class`, `mixin`, `enum`) are guarded with
`if type(x) == "table"` so a missing global no longer breaks load with
`attempt to index nil (global 'promise')` (`oop.lua:7035`, loaded via
`collections/ArrayPool.lua:27`).

## API Reference (canonical -> deprecated alias)

### Types / introspection

| Canonical             | Deprecated alias        |
| --------------------- | ----------------------- |
| `oop.checkTypes`      | `oop.check_types`       |
| `oop.isClass`         | `oop.is_class`          |
| `oop.isInterface`     | `oop.is_interface`      |
| `oop.isAbstract`      | `oop.is_abstract`       |
| `oop.isInstance`      | `oop.is_instance`       |
| `oop.usesMixin`       | `oop.uses_mixin`        |
| `oop.isMixin`         | `oop.is_mixin`          |
| `oop.getAllInstances` | `oop.get_all_instances` |
| `oop.countInstances`  | `oop.count_instances`   |
| `oop.clearInstances`  | `oop.clear_instances`   |
| `oop.getMethods`      | `oop.get_methods`       |
| `oop.getClassInfo`    | `oop.get_class_info`    |
| `oop.augmentBatch`    | `oop.augment_batch`     |

### Weak tables

| Canonical        | Deprecated alias  |
| ---------------- | ----------------- |
| `oop.weakKeys`   | `oop.weak_keys`   |
| `oop.weakValues` | `oop.weak_values` |
| `oop.weakKV`     | `oop.weak_kv`     |

### Class / mixin definition

| Canonical                    | Deprecated alias                |
| ---------------------------- | ------------------------------- |
| `oop.abstractClass`          | `oop.abstract_class`            |
| `oop.setMixinConflictPolicy` | `oop.set_mixin_conflict_policy` |
| `oop.usesSingle`             | `oop.uses_single`               |
| `oop.privateMethod`          | `oop.private_method`            |
| `oop.protectedMethod`        | `oop.protected_method`          |
| `oop.publicMethod`           | `oop.public_method`             |
| `oop.getMethodVisibility`    | `oop.get_method_visibility`     |
| `oop.getMethodsByVisibility` | `oop.get_methods_by_visibility` |

### Events

| Canonical                  | Deprecated alias             |
| -------------------------- | ---------------------------- |
| `oop.cleanupEvents`        | `oop.cleanup_events`         |
| `oop.forceEventCleanup`    | `oop.force_event_cleanup`    |
| `oop.addEvents`            | `oop.add_events`             |
| `oop.getEvents`            | `oop.get_events`             |
| `oop.getEventNames`        | `oop.get_event_names`        |
| `oop.getListenerCount`     | `oop.get_listener_count`     |
| `oop.getDeclaredEvents`    | `oop.get_declared_events`    |
| `oop.validateEvent`        | `oop.validate_event`         |
| `oop.eventEmitter`         | `oop.event_emitter`          |
| `oop.isEventable`          | `oop.is_eventable`           |
| `oop.isEventEmitter`       | `oop.is_event_emitter`       |
| `oop.createEventValidator` | `oop.create_event_validator` |
| `oop.batchEventOperations` | `oop.batch_event_operations` |
| `oop.getEventStats`        | `oop.get_event_stats`        |

### Enum

| Canonical            | Deprecated alias       |
| -------------------- | ---------------------- |
| `oop.isEnum`         | `oop.is_enum`          |
| `oop.enumFromString` | `oop.enum_from_string` |
| `oop.enumFromArray`  | `oop.enum_from_array`  |
| `oop.enumFlags`      | `oop.enum_flags`       |
| `oop.enumFromTable`  | `oop.enum_from_table`  |

### Profiling / serialization / misc

| Canonical                 | Deprecated alias            |
| ------------------------- | --------------------------- |
| `oop.getMethodSignature`  | `oop.get_method_signature`  |
| `oop.getInheritanceChain` | `oop.get_inheritance_chain` |
| `oop.getDependencies`     | `oop.get_dependencies`      |
| `oop.profileMethod`       | `oop.profile_method`        |
| `oop.toJSON`              | `oop.to_json`               |
| `oop.enableProfiling`     | `oop.enable_profiling`      |
| `oop.disableProfiling`    | `oop.disable_profiling`     |
| `oop.isProfilingEnabled`  | `oop.is_profiling_enabled`  |
| `oop.getProfileData`      | `oop.get_profile_data`      |
| `oop.clearProfileData`    | `oop.clear_profile_data`    |
| `oop.promisifyMethod`     | `oop.promisify_method`      |
| `oop.allSettled`          | `oop.all_settled`           |
| `oop.isFrozen`            | `oop.is_frozen`             |
| `oop.tableInsert`         | `oop.table_insert`          |
| `oop.tableRemove`         | `oop.table_remove`          |

### Hooks

Canonical `oop.hookBefore`, `oop.hookAfter`, `oop.hookReplace`, `oop.hookAround`,
`oop.hookMethod`, `oop.tempHook`, `oop.hookOnce`, `oop.hookOncePerArgs`,
`oop.hookWhen`, `oop.hookUnless`, `oop.hookForArgs`, `oop.hookForTypes`,
`oop.hookTimer`, `oop.hookCounter`, `oop.hookLogger`, `oop.hookValidator`,
`oop.hookTransformer`, `oop.hookCache`, `oop.hookDebouncer`, `oop.hookThrottler`,
`oop.hookRetrier`, `oop.hookMethodOnce`, `oop.hookMethodWhen`,
`oop.hookMethodLogger`, `oop.hookMethodValidator`, `oop.clearAllHooks`,
`oop.deactivateAllHooks`, `oop.reactivateAllHooks`, `oop.clearHooks`,
`oop.deactivateHooks`, `oop.reactivateHooks`, `oop.getGlobalHookStats`,
`oop.getAllHookIds`, `oop.getHooksByName`, `oop.cleanupHookRegistry`,
`oop.setHookEnabled`, `oop.setHooksEnabled`, `oop.getHookInfo`,
`oop.listHookedFunctions`.

Deprecated aliases: `oop.hook_before`, `oop.hook_after`, `oop.hook_replace`,
`oop.hook_around`, `oop.hook_method`, `oop.temp_hook`, `oop.hook_once`,
`oop.hook_once_per_args`, `oop.hook_when`, `oop.hook_unless`, `oop.hook_for_args`,
`oop.hook_for_types`, `oop.hook_timer`, `oop.hook_counter`, `oop.hook_logger`,
`oop.hook_validator`, `oop.hook_transformer`, `oop.hook_cache`,
`oop.hook_debouncer`, `oop.hook_throttler`, `oop.hook_retrier`,
`oop.hook_method_once`, `oop.hook_method_when`, `oop.hook_method_logger`,
`oop.hook_method_validator`, `oop.clear_all_hooks`, `oop.deactivate_all_hooks`,
`oop.reactivate_all_hooks`, `oop.clear_hooks`, `oop.deactivate_hooks`,
`oop.reactivate_hooks`, `oop.get_global_hook_stats`, `oop.get_all_hook_ids`,
`oop.get_hooks_by_name`, `oop.cleanup_hook_registry`, `oop.set_hook_enabled`,
`oop.set_hooks_enabled`, `oop.get_hook_info`, `oop.list_hooked_functions`.

### Guarded instance aliases (function-scoped, skipped when global is missing)

These names are `local` inside factory functions, not globals, so the file-scope
assignments are guarded and normally no-ops:

- `promise.andThen` -> `and_then`, `isCancellable` -> `is_cancellable`,
  `isCancelled` -> `is_cancelled`, `onCancel` -> `on_cancel`, `getType` ->
  `get_type`, `getState` -> `get_state`, `isPending` -> `is_pending`,
  `isFulfilled` -> `is_fulfilled`, `isRejected` -> `is_rejected`
- `pool.availableCount` -> `available_count`, `busyCount` -> `busy_count`,
  `queueCount` -> `queue_count`
- `stream.isClosed` -> `is_closed`
- `newClass.getClassName` -> `get_class_name`, `superCall` -> `super_call`,
  `shallowCopy` -> `shallow_copy`, `getInstance` -> `get_instance`,
  `destroyInstance` -> `destroy_instance`
- `interface.addMethod` -> `add_method`, `addMethods` -> `add_methods`
- `abstractClass.addAbstractMethod` -> `add_abstract_method`,
  `addAbstractMethods` -> `add_abstract_methods`
- `class.safeEmit` -> `safe_emit`, `listenerCount` -> `listener_count`,
  `hasListeners` -> `has_listeners`
- `mixin.addEventListener` -> `add_event_listener`
- `enum.getValue` -> `get_value`, `getName` -> `get_name`, `getValues` ->
  `get_values`, `getNames` -> `get_names`, `forEach` -> `for_each`, `toString` ->
  `to_string`, `hasFlag` -> `has_flag`, `setFlag` -> `set_flag`, `clearFlag` ->
  `clear_flag`, `toggleFlag` -> `toggle_flag`, `getAllFlags` -> `get_all_flags`,
  `getObject` -> `get_object`, `getObjects` -> `get_objects`

Use `oop.promise = Promise` and per-instance methods instead of relying on these
globals.

## Collections

`oop/collections/ArrayPool.lua`:

```lua
local oop = require "../oop"
local pool = ArrayPool.shared() -- alias of ArrayPool.getInstance()
```

Canonical `ArrayPool.getStats`, `ArrayPool.resetStats`, `ArrayPool.getBucketInfo`,
`ArrayPool.getInstance`; deprecated aliases `get_stats`, `reset_stats`,
`get_bucket_info`, `get_instance`.

## License

MIT License
