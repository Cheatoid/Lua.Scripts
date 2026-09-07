-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Demo / quick-start (run: lua example.lua)
--package.path = "?.lua;" .. package.path
local bench = require "init"

----------------------------------------------------------------------
-- 1. Simple one-shot timing
----------------------------------------------------------------------

local elapsed = bench.time(function()
	local x = 0
	for i = 1, 1e6 do
		x = x + i
	end
	return x
end)
print(string.format("One-shot: %s\n", bench.formatter.time(elapsed)))

----------------------------------------------------------------------
-- 2. Quick benchmark with default settings
----------------------------------------------------------------------

bench(function()
	local x = 0
	for i = 1, 1e6 do
		x = x + i
	end
end, "loop addition")

----------------------------------------------------------------------
-- 3. Suite with comparison
----------------------------------------------------------------------

local suite = bench.createSuite({
	iterations = 500,
	warmup = 20,
	precision = 3,
	show_percentiles = { 50, 95, 99 },
})

suite:add("table.insert", function()
	local t = {}
	for i = 1, 5000 do
		t[#t + 1] = i
	end
end)

suite:add("table.insert (pre-alloc)", function()
	local t = {}
	for i = 1, 5000 do
		t[i] = i
	end
end)

suite:add("string.concat", function()
	local s = ""
	for i = 1, 1000 do
		s = s .. "x"
	end
end)

suite:add("table.concat", function()
	local t = {}
	for i = 1, 1000 do
		t[i] = "x"
	end
	table.concat(t)
end)

print("=== Individual Results ===\n")
suite:run()

print("=== Comparison ===\n")
suite:compare()

----------------------------------------------------------------------
-- 4. Custom time function (simulate / mock)
----------------------------------------------------------------------

print("\n=== Custom Time Function (mock) ===\n")
local mock_clock
do
	local t = 0
	function mock_clock()
		t = t + 0.001 -- pretend each call takes 1 ms
		return t
	end
end

local r = bench.run(function() end, "mocked", {
	time_func = mock_clock,
	iterations = 100,
	warmup = 5,
})
print(string.format("Mock mean: %s  (ops/sec: %s)", bench.formatter.time(r.summary.mean),
	bench.formatter.number(r.summary.ops_sec)))

----------------------------------------------------------------------
-- 5. Time-based benchmark (run for ~0.5 s)
----------------------------------------------------------------------

print("\n=== Time-Based Benchmark (0.5 s target) ===\n")
local runner = bench.createRunner({ include_ci = true })
local tr = runner:runForTime(function()
	local x = 0
	for i = 1, 1e5 do
		x = x + i
	end
end, "time-based loop", { target_time = 0.5 })

print(bench.formatter.benchmark("time-based loop", tr.summary, {
	precision = 3,
	include_ci = true,
}))

----------------------------------------------------------------------
-- 6. Access raw data programmatically (silent mode)
----------------------------------------------------------------------

print("\n=== Programmatic Access ===\n")
local silent = bench.run(function()
	-- Loop to ensure measurable execution time (>1ms for os.clock resolution)
	local x = 0
	for i = 1, 100000 do
		x = x + math.sqrt(i)
	end
	return x
end, "loop", { silent = true, iterations = 100, include_ci = true })

print(string.format("Raw sample count : %d", #silent.times))
print(string.format("First 5 samples  : %s", table.concat((function()
	local t = {}
	for i = 1, math.min(5, #silent.times) do
		t[i] = string.format("%.9f", silent.times[i])
	end
	return t
end)(), ", ")))
if silent.summary.ci_lo then
	print(string.format("95%% CI           : [%s, %s]", bench.formatter.time(silent.summary.ci_lo, 6),
		bench.formatter.time(silent.summary.ci_hi, 6)))
else
	print("95% CI           : (enable include_ci option to compute confidence interval)")
end

print("\nExample completed")
