-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Localized global functions for better performance
local setmetatable = setmetatable
local type = type

-- Import dependencies
local Config = require "config"
local Timer = require "timer"
local Stats = require "stats"
local Formatter = require "formatter"
local Runner = require "runner"
local Suite = require "suite"

--- The benchmark module.<br>
--- Main entry point for the benchmark library.
---@class benchmark
local benchmark = {}

---@alias benchmark.TimerFunc fun(): number A timing function that returns elapsed seconds.

-- Sub-modules (exposed for power users)
benchmark.config = Config
benchmark.timer = Timer
benchmark.stats = Stats
benchmark.formatter = Formatter
benchmark.runner = Runner
benchmark.suite = Suite

----------------------------------------------------------------------
-- GLOBAL CONFIG SHORTCUTS
----------------------------------------------------------------------

--- Set the global time function.<br>
--- Used by all new Runners/Timers unless overridden.
---@param fn benchmark.TimerFunc The timing function (should return seconds).
function benchmark.setTimeFunc(fn)
	Config.time_func = fn
end

--- Get the current global time function.
---@return benchmark.TimerFunc fn The current timing function.
function benchmark.getTimeFunc()
	return Config.time_func
end

----------------------------------------------------------------------
-- CONVENIENCE API
----------------------------------------------------------------------

--- Run a benchmark and print + return the result.<br>
--- Syntax: benchmark.run(func [, name [, opts]]) or benchmark.run(func [, opts])
---@param func function The code to benchmark.
---@param name_or_opts? string|benchmark.RunOptions Optional name string or options table.
---@param opts? benchmark.RunOptions Optional options if name was provided as second arg.
---@return table result Benchmark result with name, times, summary, config.
---@usage <br>
--- ```
--- local result = benchmark.run(function()
---   for i = 1, 1000 do math.sqrt(i) end
--- end, "sqrt loop", { iterations = 100 })
--- ```
function benchmark.run(func, name_or_opts, opts)
	local name, o
	if type(name_or_opts) == "string" then
		name, o = name_or_opts, opts
	else
		name, o = nil, name_or_opts
	end
	o = o or {}
	local r = Runner.new(o):run(func, name, o)
	if not o.silent then
		print(Formatter.benchmark(name or "anonymous", r.summary, o))
	end
	return r
end

--- Time a single function call.<br>
--- Returns elapsed time + function results.
---@param func function The function to time.
---@param time_func? benchmark.TimerFunc Optional custom timing function.
---@param ... any Arguments forwarded to func.
---@return number elapsed Elapsed time in seconds.
---@return ... Results from func.
function benchmark.time(func, time_func, ...)
	return Timer.measure(func, time_func, ...)
end

--- Create a Suite for grouping benchmarks.
---@param opts? table Suite/Runner options.
---@return benchmark.Suite suite New Suite instance.
function benchmark.createSuite(opts)
	return Suite.new(opts)
end

--- Create a Runner for repeated custom use.
---@param opts? table Runner options.
---@return benchmark.Runner runner New Runner instance.
function benchmark.createRunner(opts)
	return Runner.new(opts)
end

--- Create a standalone Timer.
---@param time_func? benchmark.TimerFunc Optional custom timing function.
---@return benchmark.Timer timer New Timer instance.
function benchmark.createTimer(time_func)
	return Timer.new(time_func)
end

-- Allow benchmark(func) as sugar for benchmark.run(func)
setmetatable(benchmark, {
	__call = function(_, ...)
		return benchmark.run(...)
	end,
})

-- Deprecated aliases (naming standard: snake_case). Kept for compatibility.
benchmark.set_time_func = benchmark.setTimeFunc
benchmark.get_time_func = benchmark.getTimeFunc
benchmark.create_suite = benchmark.createSuite
benchmark.create_runner = benchmark.createRunner
benchmark.create_timer = benchmark.createTimer

-- Export
return benchmark
