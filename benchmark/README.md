# Benchmark Library

A Lua micro-benchmarking library: one-shot timing, repeated runs with
warmup, outlier removal, statistics (mean/median/stddev/percentiles/95% CI,
ops/sec), formatted reports, suite comparison, mockable clocks and
time-based runs. Each file is standalone; `init.lua` wires them together.

## Files

| File            | Purpose                                                                                                                                      | Status |
| --------------- | -------------------------------------------------------------------------------------------------------------------------------------------- | ------ |
| `init.lua`      | Main entry point: `run`, `time`, `createSuite`, `createRunner`, `createTimer`, global clock, `__call` shorthand                              | Stable |
| `timer.lua`     | Stopwatch: `start`/`stop`/`lap`/`reset`, `time(func, ...)` returning elapsed plus results, `measure`                                         | Stable |
| `runner.lua`    | Repeated measurement: fixed-iteration `run` and duration-targeted `runForTime`, warmup, timeout cap, error capture                           | Stable |
| `stats.lua`     | Statistics over sample arrays: `summarize` (count/sum/mean/median/stddev/min/max/range/ops_sec/CI/percentiles), outlier removal (`sd`/`iqr`) | Stable |
| `formatter.lua` | Human-readable output: `time`, `number`, `benchmark`, `comparison`, `summary`                                                                | Stable |
| `suite.lua`     | Named benchmark groups: `add`, `run`, `compare`, `reset`, `clear`                                                                            | Stable |
| `config.lua`    | Library-wide defaults (`Config` table): clock, iterations, warmup, precision, outlier handling, percentiles                                  | Stable |
| `example.lua`   | Demo / quick-start covering one-shot timing, suites, comparison, mock clocks, time-based runs (run: `lua example.lua`)                       | Stable |

## Naming Convention

Canonical API names use `camelCase`. Deprecated `snake_case` aliases are kept
for compatibility and delegate to the `camelCase` implementation
(`benchmark.create_suite`, `Stats.remove_outliers`, ...). New code should use
`camelCase`.

LuaLS annotation types are namespaced per module: `benchmark.Timer`,
`benchmark.Runner`, `benchmark.Suite`, `benchmark.Config`,
`benchmark.RunOptions`, `benchmark.TimerFunc`, and sibling `Options` classes
(`benchmark.FormatOptions`, `benchmark.SuiteOptions`, ...).

## Features

- One-shot timing returning elapsed seconds plus the function's own results.
- Repeated runs with warmup iterations, timeout safety cap and per-iteration
  hook (`on_iteration`).
- Outlier removal by standard deviation or Tukey IQR fence (configurable).
- Full summaries: count, sum, mean, median, stddev, stderr, min, max, range,
  ops/sec, optional 95% Gaussian CI and percentiles.
- Formatted single-benchmark reports and multi-benchmark comparison tables.
- Suites grouping named benchmarks with `run` + `compare`.
- Mockable clock (`benchmark.setTimeFunc`, per-run `time_func`, `Timer.new`)
  for deterministic tests - e.g. LuaJIT `os.clock` or an ffi `clock_gettime`.
- Time-based runs (`runForTime`) auto-sizing iteration counts to a target
  wall-clock duration.
- Silent mode returning raw `times` + `summary` for programmatic use.

## Installation

Require from the `benchmark/` directory (add it to `package.path`, e.g.
`"benchmark/?.lua"`). Sub-modules can be required individually by file name
(`config`, `timer`, `stats`, `formatter`, `runner`, `suite`); `init.lua`
re-exports them on the `benchmark` table for power users.

```lua
local bench = require "init"
```

## Architecture

`init.lua` is a thin facade: `benchmark.run` builds a `Runner`, measures,
prints via `Formatter` (unless `silent`), and returns the result table
`{ name, times, summary, config }`. `Timer` supplies raw elapsed times from
a swappable clock (`Config.time_func`, default `os.clock`). `Runner` owns
repetition (warmup, timeout, error capture). `Stats.summarize` reduces the
sample array. `Suite` maps names to `{ func, opts }` registrations and
formats a comparison via `Formatter.comparison`.

## Usage

### Quick Start (one-shot + suite)

```lua
local bench = require "init"

local elapsed = bench.time(function()
    local x = 0
    for i = 1, 1e6 do x = x + i end
    return x
end)
print("One-shot: " .. bench.formatter.time(elapsed))

local suite = bench.createSuite({ iterations = 500, warmup = 20 })
suite:add("table.insert", function()
    local t = {}
    for i = 1, 5000 do t[#t + 1] = i end
end)
suite:add("pre-allocated", function()
    local t = {}
    for i = 1, 5000 do t[i] = i end
end)
suite:run()
suite:compare()
```

### Silent programmatic use with mock clock

```lua
local bench = require "init"

local t = 0
local function mock_clock()
    t = t + 0.001
    return t
end

local r = bench.run(function() end, "mocked", {
    time_func = mock_clock,
    iterations = 100,
    silent = true,
})
print("Mock mean: " .. bench.formatter.time(r.summary.mean))
print("ops/sec: " .. bench.formatter.number(r.summary.ops_sec))
```

## API Reference

### Entry point (`init.lua`)

| Function                                      | Description                                                                                       |
| --------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| `benchmark.run(func, name?, opts?)`           | Run and print (unless `silent`), return result table; callable directly as `benchmark(func, ...)` |
| `benchmark.time(func, time_func?, ...)`       | Elapsed seconds plus `func` results                                                               |
| `benchmark.createSuite(opts?)`                | New `Suite`                                                                                       |
| `benchmark.createRunner(opts?)`               | New reusable `Runner`                                                                             |
| `benchmark.createTimer(time_func?)`           | New standalone `Timer`                                                                            |
| `benchmark.setTimeFunc(fn)` / `getTimeFunc()` | Global clock override / query                                                                     |

### `Runner` / `Timer`

| Function                                                                                                               | Description                                |
| ---------------------------------------------------------------------------------------------------------------------- | ------------------------------------------ |
| `Runner.new(opts?)`, `Runner:run(func, name?, opts?)`, `Runner:runForTime(func, name?, opts?)`                         | Fixed-iteration and duration-targeted runs |
| `Timer.new(time_func?)`, `Timer:start/stop/lap/reset`, `Timer:time(func, ...)`, `Timer.measure(func, time_func?, ...)` | Stopwatch primitives                       |

### `Suite` / `Stats` / `Formatter` / `Config`

| Function                                                                                                                                                                                       | Description                                                                                                                                                                     |
| ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Suite.new(opts?)`, `Suite:add(name, func, opts?)`, `Suite:run()`, `Suite:compare()`, `Suite:reset()`, `Suite:clear()`                                                                         | Benchmark groups                                                                                                                                                                |
| `Stats.summarize(times, opts?)`, `Stats.mean/median/stddev/percentile`, `Stats.removeOutliers(Iqr)`, `Stats.confidenceInterval95`, `Stats.opsPerSecond`                                        | Sample statistics                                                                                                                                                               |
| `Formatter.time(sec, precision?)`, `Formatter.number(n, precision?)`, `Formatter.benchmark(name, summary, opts?)`, `Formatter.comparison(results, opts?)`, `Formatter.summary(summary, opts?)` | Human-readable output                                                                                                                                                           |
| `Config` fields                                                                                                                                                                                | `time_func`, `default_iterations` (1000), `default_warmup` (50), `default_timeout` (30), `precision` (3), `remove_outliers`, `outlier_method`, `show_percentiles`, `include_ci` |

Common per-run options (`benchmark.RunOptions`): `iterations`, `warmup`,
`silent`, `time_func`, `target_time`, `min_iterations`, `timeout`,
`precision`, `include_ci`, `show_percentiles`, `on_iteration`.

## Tests

Each module has a suite under `tests/` (`init`, `timer`, `runner`, `stats`,
`formatter`, `suite`), runnable with plain `lua` or `luajit` from the
`tests/` directory (each file bootstraps its own `package.path`). See
`example.lua` for an end-to-end demo (run: `lua example.lua`).
