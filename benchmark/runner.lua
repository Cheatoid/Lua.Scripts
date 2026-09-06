-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Localized global functions for better performance
local error = error
local pcall = pcall
local setmetatable = setmetatable
local tostring = tostring

--- Per-benchmark override options for `Runner.run`.
---@class benchmark.RunOptions
---@field iterations? integer Override iteration count.
---@field warmup? integer Override warmup iterations.
---@field timeout? number Override timeout in seconds.
---@field silent? boolean Whether to suppress output.

--- Executes benchmarks with warm-up, iteration control, and timeout handling.
---@class benchmark.Runner
---@field time_func benchmark.TimerFunc Timing function
---@field iterations integer Default iteration count
---@field warmup integer Default warmup iterations
---@field timeout number Wall-clock timeout in seconds
---@field precision integer Output precision
---@field outlier_threshold number Outlier threshold (SD method)
---@field outlier_method string Outlier method ("sd" or "iqr")
---@field outlier_k number IQR multiplier
---@field remove_outliers boolean Whether to remove outliers
---@field show_percentiles? integer[] Percentiles to show
---@field include_ci boolean Whether to include confidence interval
---@field silent boolean Whether to suppress output
---@field on_iteration? function Callback for each iteration
---@field catch_errors boolean Whether to catch errors during benchmark
local Runner = {}
Runner.__index = Runner

-- Import dependencies
local Timer = require "timer"
local Stats = require "stats"
local Config = require "config"

--- Create a new Runner instance.<br>
--- Configures benchmark execution parameters.
---@param opts? table Options table overriding Config defaults.
---@return benchmark.Runner runner New Runner instance.
---@usage <br>
--- ```
--- local runner = Runner.new({ iterations = 500, warmup = 20 })
--- ```
function Runner.new(opts)
	opts = opts or {}
	local self = setmetatable({
		time_func = opts.time_func or Config.time_func,
		iterations = opts.iterations or Config.default_iterations,
		warmup = opts.warmup or Config.default_warmup,
		timeout = opts.timeout or Config.default_timeout,
		precision = opts.precision or Config.precision,
		outlier_threshold = opts.outlier_threshold or Config.outlier_threshold,
		outlier_method = opts.outlier_method or Config.outlier_method,
		outlier_k = opts.outlier_k or Config.outlier_k,
		remove_outliers = opts.remove_outliers,
		show_percentiles = opts.show_percentiles or Config.show_percentiles,
		include_ci = opts.include_ci or Config.include_ci,
		silent = opts.silent or false,
		on_iteration = opts.on_iteration,    -- function(i, elapsed)
		catch_errors = opts.catch_errors ~= false, -- default true
	}, Runner)
	if self.remove_outliers == nil then
		self.remove_outliers = Config.remove_outliers
	end
	return self
end

Runner.__call = Runner.new

--- Run a fixed-iteration benchmark.<br>
--- Executes warmup iterations, then measures the function over the specified iterations.
---@param self benchmark.Runner The Runner instance.
---@param func function The code to measure.
---@param name? string Optional benchmark name.
---@param opts? benchmark.RunOptions Per-benchmark overrides.
---@return table result { name, times, summary, config, error }.
---@usage <br>
--- ```
--- local runner = Runner.new()
--- local result = runner:run(function()
---   for i = 1, 1000 do math.sqrt(i) end
--- end, "sqrt loop")
--- ```
function Runner.run(self, func, name, opts)
	opts = opts or {}
	name = name or tostring(func)

	local iters = opts.iterations or self.iterations
	local warmup = opts.warmup or self.warmup
	local timeout = opts.timeout or self.timeout

	-- warmup
	for _ = 1, warmup do
		local ok, err = pcall(func)
		if not ok then
			return { name = name, times = {}, summary = {}, config = {}, error = err }
		end
	end

	-- measure
	local times = {}
	local wall_start = self.time_func()
	local timer = Timer.new(self.time_func)

	for i = 1, iters do
		timer:start()
		local ok, err = pcall(func)
		timer:stop()

		if not ok then
			if self.catch_errors then
				return {
					name = name,
					times = times,
					summary = Stats.summarize(times, self:_statsOpts()),
					config = { iterations = #times, warmup = warmup, timeout = timeout },
					error = err,
				}
			else
				return error(err, 2)
			end
		end

		times[i] = timer.elapsed

		if self.on_iteration then
			self.on_iteration(i, timer.elapsed)
		end

		if timeout > 0 and (self.time_func() - wall_start) > timeout then
			break
		end
	end

	local summary = Stats.summarize(times, self:_statsOpts())
	summary.name = name

	return {
		name = name,
		times = times,
		summary = summary,
		config = { iterations = #times, warmup = warmup, timeout = timeout },
	}
end

--- Run for a target wall-clock duration.<br>
--- Auto-determines iteration count to achieve the target time.
---@param self benchmark.Runner The Runner instance.
---@param func function The code to measure.
---@param name? string Optional benchmark name.
---@param opts? benchmark.RunOptions Per-benchmark overrides (supports target_time, min_iterations).
---@return table result { name, times, summary, config }.
---@usage <br>
--- ```
--- local runner = Runner.new()
--- local result = runner:runForTime(function()
---   math.sqrt(12345)
--- end, "sqrt", { target_time = 1.0 })
--- ```
function Runner.runForTime(self, func, name, opts)
	opts = opts or {}
	name = name or tostring(func)

	local target = opts.target_time or 1.0
	local warmup = opts.warmup or self.warmup
	local min_iters = opts.min_iterations or 10

	-- warmup
	for _ = 1, warmup do
		local ok, _ = pcall(func)
		if not ok then
			return { name = name, times = {}, summary = {}, config = {}, error = "warmup error" }
		end
	end

	local times = {}
	local wall_start = self.time_func()
	local timer = Timer.new(self.time_func)

	repeat
		timer:start()
		local ok, err = pcall(func)
		timer:stop()

		if not ok then
			if self.catch_errors then
				return {
					name = name,
					times = times,
					summary = Stats.summarize(times, self:_statsOpts()),
					config = { target_time = target, warmup = warmup },
					error = err,
				}
			end
			return error(err, 2)
		end

		times[#times + 1] = timer.elapsed
		if self.on_iteration then
			self.on_iteration(#times, timer.elapsed)
		end
	until #times >= min_iters and (self.time_func() - wall_start) >= target

	local summary = Stats.summarize(times, self:_statsOpts())
	summary.name = name

	return {
		name = name,
		times = times,
		summary = summary,
		config = { iterations = #times, target_time = target, warmup = warmup },
	}
end

--- Private: Build stats options from runner configuration.
---@param self benchmark.Runner The Runner instance.
---@return benchmark.StatsOptions opts Options for `Stats.summarize`.
function Runner._statsOpts(self)
	return {
		remove_outliers = self.remove_outliers,
		outlier_method = self.outlier_method,
		outlier_threshold = self.outlier_threshold,
		outlier_k = self.outlier_k,
		percentiles = self.show_percentiles,
		include_ci = self.include_ci,
	}
end

--[[ Quick tests
if true then
	-- Test runner creation
	local runner = Runner.new({ iterations = 100, warmup = 5 })
	assert(runner.iterations == 100, "Should set custom iterations")
	assert(runner.warmup == 5, "Should set custom warmup")

	-- Test fixed iteration run
	local result = runner:run(function()
		local x = 0
		for i = 1, 100 do
			x = x + i
		end
		return x
	end, "sum loop")
	assert(result.name == "sum loop", "Should set result name")
	assert(result.times and #result.times > 0, "Should record times")
	assert(result.summary, "Should include summary")

	-- Test time-based run
	local time_result = runner:runForTime(function()
		for i = 1, 1000 do
			math.sqrt(i)
		end
	end, "sqrt loop", { target_time = 0.1, min_iterations = 5 })
	assert(time_result.times and #time_result.times >= 5, "Should run min_iterations")

	print("All tests passed")
end
--]]

-- Export
return Runner
