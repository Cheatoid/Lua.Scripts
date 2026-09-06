# Timer

Timer library.

Pure Lua, zero dependencies, LuaJIT/5.1+ compatible. No engine bindings: you supply time through a time function and pump timers by calling `tick`/`update` from your own tick/update loop.

Naming follows the codebase convention: `lower_case_snake`. `PascalCase` aliases (`Create`, `Simple`, `TimeLeft`, ...) are kept for GMod-familiarity and delegate to the snake_case implementation.

## Features

- **GMod-familiar API**: `create`, `simple`, `exists`, `remove`, `start`, `stop`, `pause`, `unpause`, `toggle`, `adjust`, `time_left`, `reps_left`, `tick`
- **Object-oriented**: every timer is a `Timer` object with `:start()`, `:stop()`, `:pause()`, `:resume()`, `:toggle()`, `:adjust()`, `:time_left()`, `:reps_left()`
- **Engine-agnostic**: inject any clock with `set_time_function` / `Manager.new(clock)` and drive with `tick(now)` from any engine loop
- **Isolated registries**: default singleton for simple scripts, `timer.new()` managers for tests, minigames, per-player scopes
- **Safe tick**: snapshot iteration (create/remove inside callbacks is safe), at most once per timer per tick, hitch snap-forward instead of burst catch-up
- **Full lifecycle**: `running` / `paused` / `stopped` / `finished` / `removed`, `auto_remove` for one-shots, varargs forwarding, options-table creation
- **Type-safe**: LuaCATS annotations for IDE support

## Installation

Copy the `timer/` directory into your project:

```lua
local timer = require "timer"
-- isolated file layout some loaders use:
-- local timer = require "timer/timer"
```

Single file: `timer/timer.lua`. No build step, no FFI.

## Quick start

### Default singleton

```lua
local timer = require "timer"

-- Repeat forever every 1s
timer.create("heartbeat", 1, 0, function()
    print("tick")
end)

-- One-shot after 1.5s with arguments
timer.simple(1.5, function(ply, msg)
    print(ply, msg)
end, "P1", "hi")

-- Pump from your engine loop (see Wiring below)
-- timer.tick()
```

### Isolated manager (tests, minigames)

```lua
local timer = require "timer"

local now = 0
local tm = timer.new(function() return now end)

tm:create("respawn", 5, 1, spawn_player, ply)

-- advance time manually
now = 5
tm:tick(now) -- or tm:tick() reads the injected clock
```

### Object-oriented handles

```lua
local t = timer.create("blink", 0.5, 0, toggle_light)
print(t:get_id(), t:get_delay(), t:reps_left())

t:pause()
print(t:time_left()) -- frozen
t:resume()

t:adjust(0.25, 10) -- faster, 10 total fires
t:stop()
t:start() -- re-arm from full delay
t:remove()
```

## Wiring: time function + tick/update

The library never creates threads or hooks itself. You provide both inputs:

1. **Time function**: `fun(): number` returning seconds. Default is `os.clock`.
2. **Tick call**: invoke `timer.tick(now?)` (alias `timer.update(now?)`) every frame/tick. When `now` is omitted the time function is read.

```lua
-- Choose your clock once
timer.set_time_function(os.clock) -- default, CPU time
-- timer.set_time_function(CurTime) -- GMod
-- timer.set_time_function(os.time) -- coarse wall time (rarely what you want)
```

### nanos-world (Server)

```lua
local timer = require "timer"

Server.Subscribe("Tick", function(_dt)
    timer.tick()
end)

-- Or pass engine time explicitly if you track it:
-- local t = 0
-- Server.Subscribe("Tick", function(dt)
--     t = t + dt
--     timer.tick(t)
-- end)
```

### Garry's Mod

```lua
local timerx = require "timer"
timerx.set_time_function(CurTime)
hook.Add("Tick", "MyTimers", function()
    timerx.tick()
end)
```

### LÖVE

```lua
local timer = require "timer"
local now = 0
function love.update(dt)
    now = now + dt
    timer.tick(now)
end
```

### Plain Lua loop / tests

```lua
local timer = require "timer"
local now = 0
local tm = timer.new(function() return now end)
tm:create("a", 1, 2, print, "fire")
for _ = 1, 5 do
    now = now + 0.5
    tm:tick(now)
end
```

If your engine only gives `dt`, accumulate your own `now` and pass it in. This keeps replays/tests deterministic.

## Concepts

### Delay and repetitions

- `delay >= 0` seconds between fires. `0` fires every `tick`.
- `repetitions >= 0` integer total fires. `0` means infinite.
- `create(id, delay, reps, fn, ...)` autostarts by default. `simple(delay, fn, ...)` is `reps = 1` + `auto_remove = true` with a generated id.

Options-table form:

```lua
timer.create("blink", {
    delay = 0.5,
    repetitions = 0, -- or reps = 0
    callback = toggle, -- or fn = toggle
    args = { light },
    autostart = true,
    auto_remove = false,
})
```

### Pause vs stop vs remove

| Call                       | Registry                                 | Firing                        | Resume path                                      |
| -------------------------- | ---------------------------------------- | ----------------------------- | ------------------------------------------------ |
| `pause`                    | kept                                     | frozen, `time_left` preserved | `resume` / `unpause` continues from frozen value |
| `stop`                     | kept                                     | halted, `time_left` = 0       | `start` re-arms from full delay                  |
| `remove`                   | gone                                     | never                         | must `create` again                              |
| Exhausted (`reps` reached) | kept as `finished`, unless `auto_remove` | halted                        | `start` resets `reps_left` and re-arms           |

`toggle`: running -> paused, paused -> resumed, stopped/finished -> started.

### Tick semantics

- Absolute-time comparison: fires when `now >= next_fire`.
- At most one fire per timer per `tick` call.
- Cadence-preserving (`next_fire + delay`), but hitches snap to `now + delay` instead of bursting N catch-up fires in one frame.
- Snapshot iteration: `create`/`remove`/`pause` inside a callback applies immediately and is safe; timers created mid-`tick` fire on the next `tick`, not the current one.
- A callback that `stop`/`pause`/`adjust`s itself wins: `tick` does not overwrite a `next_fire` changed by the callback.

### Missing timers

`time_left` / `reps_left` return `nil` for unknown identifiers. Object methods return `0` when not armed. `remove` / `start` / `stop` / `pause` / `unpause` / `toggle` / `adjust` on missing identifiers return `false`.

### Errors

Default is fail-fast: callback errors propagate out of `tick` (remaining timers that tick are skipped). For isolation, set a sink:

```lua
tm:set_error_handler(function(err, t)
    print("timer failed:", t:get_id(), err)
end)
```

With a handler, `tick` uses `pcall`, routes failures to the handler, and continues with other timers.

## API Reference

### Manager (`timer.new(clock)` / `timer.Manager`)

Registry + clock + pump. The module singleton delegates to one shared instance.

| Method                                                                               | Description                                                            |
| ------------------------------------------------------------------------------------ | ---------------------------------------------------------------------- |
| `new(clock?)`                                                                        | Isolated manager. `clock` defaults to `os.clock`.                      |
| `set_time_source(fn)` / `set_time_function(fn)`                                      | Replace clock.                                                         |
| `get_time_source()` / `get_time_function()`                                          | Current clock.                                                         |
| `now()`                                                                              | `clock()` reading.                                                     |
| `set_error_handler(fn\|nil)`                                                         | Error sink, `nil` = propagate.                                         |
| `create(id, delay, reps, fn, ...)` / `create(id, opts)`                              | Named timer, replaces same id, autostarts by default. Returns `Timer`. |
| `simple(delay, fn, ...)`                                                             | Anonymous one-shot, auto-removed. Returns `Timer`.                     |
| `get(id)` / `exists(id)`                                                             | Lookup / presence.                                                     |
| `remove(id)`                                                                         | Detach, returns `boolean`.                                             |
| `remove_all()` / `clear()`                                                           | Empty registry.                                                        |
| `count()` / `list()`                                                                 | Size / array of ids.                                                   |
| `start(id)` / `stop(id)` / `pause(id)` / `unpause(id)` / `resume(id)` / `toggle(id)` | Lifecycle by id, returns `boolean` (`false` when missing).             |
| `adjust(id, delay?, reps?, fn?, ...)`                                                | In-place edit, returns `boolean`.                                      |
| `time_left(id)`                                                                      | Seconds left or `nil` when missing.                                    |
| `reps_left(id)`                                                                      | Fires left (`0` = infinite/exhausted) or `nil` when missing.           |
| `pause_all()` / `resume_all()` / `unpause_all()` / `stop_all()`                      | Bulk lifecycle.                                                        |
| `tick(now?)` / `update(now?)`                                                        | Fire due timers, returns `fired` count.                                |

### Timer object

Returned by `create` / `simple` / `get`.

| Method                                                            | Description                                                       |
| ----------------------------------------------------------------- | ----------------------------------------------------------------- |
| `start()` / `restart()`                                           | Arm from full delay, reset `reps_left` when exhausted. Chainable. |
| `stop()`                                                          | Halt, keep `reps_left`. Chainable.                                |
| `pause()`                                                         | Freeze `time_left`. Chainable.                                    |
| `resume()` / `unpause()`                                          | Continue from frozen value. Chainable.                            |
| `toggle()`                                                        | Pause / resume / start by status. Chainable.                      |
| `remove()` / `destroy()`                                          | Detach from manager, returns `boolean`.                           |
| `adjust(delay?, reps?, fn?, ...)`                                 | Edit in place, re-arms when running. Chainable.                   |
| `set_delay(d)` / `set_repetitions(r)` / `set_callback(fn, ...)`   | Focused edits. Chainable.                                         |
| `time_left()`                                                     | Seconds left (`0` when not armed, frozen when paused).            |
| `reps_left()`                                                     | Fires left.                                                       |
| `elapsed()`                                                       | Progress in current interval.                                     |
| `get_id()` / `get_delay()` / `get_repetitions()` / `get_status()` | Inspectors.                                                       |
| `is_running()` / `is_paused()` / `is_stopped()` / `is_finished()` | Status predicates.                                                |

### Module singleton

Same names as Manager but without `self`: `timer.create`, `timer.simple`, `timer.exists`, `timer.get`, `timer.remove`, `timer.remove_all` / `timer.clear`, `timer.count`, `timer.list`, `timer.start`, `timer.stop`, `timer.pause`, `timer.unpause` / `timer.resume`, `timer.toggle`, `timer.adjust`, `timer.time_left`, `timer.reps_left`, `timer.tick` / `timer.update`, `timer.set_time_function`, `timer.get_time_function`, `timer.now`, `timer.set_error_handler`. Plus `timer.new`, `timer.Timer`, `timer.Manager`, `timer.default`.

## GMod mapping

GMod uses `PascalCase`; this library uses `snake_case` with aliases, so both spellings work:

| GMod `timer.*`                                                                                               | This library (primary)                                                                                         | Notes                                                             |
| ------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------- |
| `Create(id, delay, reps, fn)`                                                                                | `timer.create(id, delay, reps, fn, ...)`                                                                       | Adds varargs + options table, returns `Timer` handle.             |
| `Simple(delay, fn)`                                                                                          | `timer.simple(delay, fn, ...)`                                                                                 | Returns auto-removed `Timer` instead of nothing.                  |
| `Exists` / `Remove` / `Start` / `Stop` / `Pause` / `UnPause` / `Toggle` / `Adjust` / `TimeLeft` / `RepsLeft` | `exists` / `remove` / `start` / `stop` / `pause` / `unpause` / `toggle` / `adjust` / `time_left` / `reps_left` | `adjust` also accepts new args; missing ids return `false`/`nil`. |
| `Tick` (internal)                                                                                            | `timer.tick(now?)`                                                                                             | You call it from your loop; `now` defaults to the time function.  |

## Testing

`timer/timer.lua` ends with a commented `--[[ Quick tests ... --]]` block using a mock clock (no `os.clock` flakiness). It covers create/repeat, infinite + args, `simple` auto-remove, pause/resume, stop/start, adjust/toggle/remove, `delay = 0`, self-removal in callbacks, and error-handler isolation.

## License

MIT License
