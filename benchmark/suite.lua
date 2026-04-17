-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Localized global functions for better performance
local next = next
local print = print
local setmetatable = setmetatable

--- Define the SuiteOptions class<br>
--- Options for Suite constructor and per-benchmark configuration.
---@class benchmark.SuiteOptions
---@field time_func benchmark.TimerFunc|nil Custom timing function (default: os.clock).
---@field iterations integer|nil Number of iterations (default: 1000).
---@field warmup integer|nil Warmup iterations (default: 50).
---@field timeout number|nil Wall-clock timeout in seconds (default: 30).
---@field precision integer|nil Decimal places in output (default: 3).
---@field remove_outliers boolean|nil Whether to remove outliers (default: true).
---@field outlier_method string|nil Outlier method "sd" or "iqr" (default: "sd").
---@field outlier_threshold number|nil SD threshold (default: 2.0).
---@field outlier_k number|nil IQR multiplier (default: 1.5).
---@field show_percentiles integer[]|nil Percentiles to compute (default: {50, 90, 95, 99}).
---@field include_ci boolean|nil Include 95% CI (default: false).
---@field silent boolean|nil Suppress output (default: false).

--- Define the Suite class<br>
--- Group and compare multiple benchmarks.
---@class benchmark.Suite
---@field runner benchmark.Runner The internal Runner instance.
---@field benchmarks {name: string, func: function, opts: benchmark.SuiteOptions|nil}[] Ordered list of benchmark registrations.
---@field results table<string, table> name -> result mapping.
---@field opts benchmark.SuiteOptions Suite options.
local Suite = {}
Suite.__index = Suite

-- Import dependencies
local Runner = require "runner"
local Formatter = require "formatter"
local Config = require "config"

--- Create a new Suite instance.<br>
--- Groups multiple benchmarks for sequential execution and comparison.
---@param opts benchmark.SuiteOptions|nil Options passed to Runner and formatting.
---@return benchmark.Suite suite New Suite instance.
---@usage <br>
--- ```
--- local suite = Suite.new({ iterations = 500, precision = 3 })
--- suite:add("method1", function() ... end)
--- suite:add("method2", function() ... end)
--- suite:run()
--- suite:compare()
--- ```
function Suite.new(opts)
	opts = opts or {}
	local self = setmetatable({
		benchmarks = {}, -- ordered list of {name, func, opts}
		results = {}, -- name -> result
		opts = opts,
	}, Suite)
	self.runner = Runner.new(opts)
	return self
end

Suite.__call = Suite.new

--- Register a benchmark.<br>
--- Adds a named function to the suite for later execution.
---@param self benchmark.Suite The Suite instance.
---@param name string Benchmark name.
---@param func function The function to benchmark.
---@param opts benchmark.RunOptions|nil Runner overrides for this benchmark.
---@return benchmark.Suite self The Suite instance for chaining.
---@usage <br>
--- ```
--- suite:add("table insert", function()
---     local t = {}
---     for i = 1, 1000 do t[i] = i end
--- end)
--- ```
function Suite.add(self, name, func, opts)
	self.benchmarks[#self.benchmarks + 1] = {
		name = name,
		func = func,
		opts = opts,
	}
	return self
end

--- Run all registered benchmarks sequentially.<br>
--- Executes each benchmark and stores results. Prints output unless silent.
---@param self benchmark.Suite The Suite instance.
---@return table results name -> result mapping.
function Suite.run(self)
	self.results = {}
	local benchmarks = self.benchmarks
	for i = 1, #benchmarks do
		local b = benchmarks[i]
		local r = self.runner:run(b.func, b.name, b.opts)
		self.results[b.name] = r
		if not self.opts.silent then
			print(Formatter.benchmark(b.name, r.summary, self.opts))
			print()
		end
	end
	return self.results
end

--- Print a comparison table (runs first if needed).<br>
--- Shows relative performance of all benchmarks.
---@param self benchmark.Suite The Suite instance.
---@return table results name -> result mapping.
---@return string output The formatted comparison table.
function Suite.compare(self)
	if not next(self.results) then
		self:run()
	end
	local output = Formatter.comparison(self.results, self.opts)
	if not self.opts.silent then
		print(output)
	end
	return self.results, output
end

--- Clear results (keeps registrations).<br>
--- Removes results but keeps benchmark registrations for re-running.
---@param self benchmark.Suite The Suite instance.
---@return benchmark.Suite self The Suite instance for chaining.
function Suite.reset(self)
	self.results = {}
	return self
end

--- Remove all registrations and results.<br>
--- Completely clears the suite.
---@param self benchmark.Suite The Suite instance.
---@return benchmark.Suite self The Suite instance for chaining.
function Suite.clear(self)
	self.benchmarks = {}
	self.results = {}
	return self
end

--[[ Quick tests
if true then
	-- Test suite creation
	local suite = Suite.new({ iterations = 10, warmup = 2, silent = true })
	assert(#suite.benchmarks == 0, "Suite should start empty")

	-- Test add
	suite:add("test1", function()
		local x = 0
		for i = 1, 100 do
			x = x + i
		end
	end)
	suite:add("test2", function()
		local t = {}
		for i = 1, 100 do
			t[i] = i
		end
	end)
	assert(#suite.benchmarks == 2, "Should have 2 benchmarks")

	-- Test run
	local results = suite:run()
	assert(results["test1"], "Should have test1 result")
	assert(results["test2"], "Should have test2 result")
	assert(results["test1"].summary, "Should have summary")

	-- Test reset
	suite:reset()
	assert(not next(suite.results), "Should clear results")
	assert(#suite.benchmarks == 2, "Should keep registrations")

	-- Test clear
	suite:clear()
	assert(#suite.benchmarks == 0, "Should clear registrations")

	print("All Suite tests passed ✔")
end
--]]

-- Export
return Suite
