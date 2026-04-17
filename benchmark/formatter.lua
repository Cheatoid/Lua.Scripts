-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Localized global functions for better performance
local next = next
local math_huge = math.huge
local string_format = string.format
local table_concat = table.concat
local table_sort = table.sort

--- Define the FormatOptions class<br>
--- Options for formatting benchmark output.
---@class benchmark.FormatOptions
---@field precision integer|nil Decimal places in output (default: 3).
---@field show_percentiles integer[]|nil Percentiles to display (default: {50, 90, 95, 99}).
---@field silent boolean|nil Suppress output (default: false).

--- Define the Formatter module<br>
--- Human-readable output helpers for benchmark results.
---@class benchmark.Formatter
local Formatter = {}

----------------------------------------------------------------------
-- TIME SCALING
----------------------------------------------------------------------

---@type table[] Time scale configurations.
local SCALES = {
	{ limit = 1e-6,  unit = "ns", factor = 1e9 },
	{ limit = 1e-3,  unit = "us", factor = 1e6 },
	{ limit = 1,     unit = "ms", factor = 1e3 },
	{ limit = 1e3,   unit = "s",  factor = 1 },
	-- fallback
	{ limit = 1 / 0, unit = "ks", factor = 1e-3 },
}

--- Format seconds into a human-readable string.<br>
--- Automatically selects appropriate unit (ns, us, ms, s, ks).
--- Returns "N/A" if sec is nil.
---@param sec number|nil Time in seconds.
---@param precision number|nil Decimal places (default 3).
---@return string formatted Formatted time string (e.g., "1.234 ms") or "N/A".
---@usage <br>
--- ```
--- print(Formatter.time(0.001234)) -- "1.234 ms"
--- ```
function Formatter.time(sec, precision)
	if sec == nil then
		return "N/A"
	end
	precision = precision or 3
	for i = 1, #SCALES do
		local s = SCALES[i]
		if sec < s.limit then
			return string_format("%." .. precision .. "f %s", sec * s.factor, s.unit)
		end
	end
	return string_format("%." .. precision .. "f s", sec)
end

----------------------------------------------------------------------
-- NUMBER SCALING
----------------------------------------------------------------------

---@type table[] Number scale configurations.
local NUM_SCALES = {
	{ limit = 1e6, suffix = "M" },
	{ limit = 1e3, suffix = "K" },
	{ limit = 0,   suffix = "" },
}

--- Format a number with appropriate scale suffix.<br>
--- Uses K for thousands, M for millions.
---@param n number The number to format.
---@param precision number|nil Decimal places (default 2).
---@return string formatted Formatted number string.
function Formatter.number(n, precision)
	precision = precision or 2
	for i = 1, #NUM_SCALES do
		local s = NUM_SCALES[i]
		if n >= s.limit then
			return string_format("%." .. precision .. "f%s", n / s.limit, s.suffix)
		end
	end
	return string_format("%." .. precision .. "f", n)
end

----------------------------------------------------------------------
-- SINGLE BENCHMARK
----------------------------------------------------------------------

--- Format a single benchmark result as human-readable text.<br>
--- Includes iterations, timing stats, ops/sec, and optional CI/percentiles.
---@param name string Benchmark name.
---@param summary table Summary statistics from Stats.summarize().
---@param opts benchmark.FormatOptions|nil Options for formatting.
---@return string formatted Formatted benchmark output.
function Formatter.benchmark(name, summary, opts)
	opts = opts or {}
	local p = opts.precision or 3
	local L = {}

	L[#L + 1] = string_format("Benchmark: %s", name)
	L[#L + 1] = string_format("  Iterations: %d", summary.count)
	if summary.raw_count ~= summary.count then
		L[#L + 1] = string_format("    (removed %d outliers from %d raw samples)", summary.raw_count - summary.count,
			summary.raw_count)
	end
	L[#L + 1] = string_format("  Min:      %s", Formatter.time(summary.min, p))
	L[#L + 1] = string_format("  Max:      %s", Formatter.time(summary.max, p))
	L[#L + 1] = string_format("  Mean:     %s", Formatter.time(summary.mean, p))
	L[#L + 1] = string_format("  Median:   %s", Formatter.time(summary.median, p))
	L[#L + 1] = string_format("  StdDev:   %s", Formatter.time(summary.stddev, p))
	L[#L + 1] = string_format("  Ops/sec:  %s", Formatter.number(summary.ops_sec, 2))

	if summary.ci_lo then
		L[#L + 1] = string_format("  95%% CI:   [%s, %s]", Formatter.time(summary.ci_lo, p),
			Formatter.time(summary.ci_hi, p))
	end

	if summary.percentiles then
		local order = opts.show_percentiles or { 50, 90, 95, 99 }
		for i = 1, #order do
			local pct = order[i]
			if summary.percentiles[pct] then
				L[#L + 1] = string_format("  P%02d:      %s", pct, Formatter.time(summary.percentiles[pct], p))
			end
		end
	end

	return table_concat(L, "\n")
end

----------------------------------------------------------------------
-- COMPARISON TABLE
----------------------------------------------------------------------

--- Format a comparison table for multiple benchmark results.<br>
--- Sorts by median time, shows ratios relative to fastest.
---@param results table Table of name -> { summary = {...} }.
---@param opts benchmark.FormatOptions|nil Options for formatting.
---@return string formatted Formatted comparison table.
function Formatter.comparison(results, opts)
	opts = opts or {}
	local p = opts.precision or 3

	-- find fastest (by median)
	local fastest_val, fastest_key = math_huge
	for k, r in next, results do
		if r.summary.median < fastest_val then
			fastest_val = r.summary.median
			fastest_key = k
		end
	end

	-- sort entries by median ascending
	local sorted = {}
	for k, r in next, results do
		sorted[#sorted + 1] = { key = k, r = r }
	end
	table_sort(sorted, function(a, b)
		if a.r.summary.median == b.r.summary.median then
			return a.key < b.key -- stable sort by name
		end
		return a.r.summary.median < b.r.summary.median
	end)

	-- column widths
	local name_w = 0
	for i = 1, #sorted do
		local e = sorted[i]
		if #e.key > name_w then
			name_w = #e.key
		end
	end
	name_w = name_w + 2
	local col_w = 16

	local bar = string.rep("-", name_w + col_w * 3 + 14)
	local hdr = string_format("%-" .. name_w .. "s %%-" .. col_w .. "s %%-" .. col_w .. "s %%-" .. col_w .. "s %-10s",
		"Name", "Median", "Mean", "StdDev", "Ratio")
	local L = { bar, hdr, bar }

	for i = 1, #sorted do
		local e = sorted[i]
		local s = e.r.summary
		local ratio = s.median / fastest_val
		local ratio_str
		if e.key == fastest_key then
			ratio_str = "(fastest)"
		else
			ratio_str = string_format("%.2fx", ratio)
		end
		L[#L + 1] = string_format(
			"%-" .. name_w .. "s %%-" .. col_w .. "s %%-" .. col_w .. "s %%-" .. col_w .. "s %-10s",
			e.key,
			Formatter.time(s.median, p),
			Formatter.time(s.mean, p),
			Formatter.time(s.stddev, p),
			ratio_str
		)
	end
	L[#L + 1] = bar
	return table_concat(L, "\n")
end

----------------------------------------------------------------------
-- PLAIN SUMMARY
----------------------------------------------------------------------

--- Format a summary table (alias for benchmark).
---@param summary table Summary statistics.
---@param opts benchmark.FormatOptions|nil Options for formatting.
---@return string formatted Formatted summary.
function Formatter.summary(summary, opts)
	return Formatter.benchmark(summary.name or "unnamed", summary, opts)
end

--[[ Quick tests
if true then
	-- Test time formatting
	assert(Formatter.time(1e-9):match("ns"), "Should format nanoseconds")
	assert(Formatter.time(1e-6):match("us"), "Should format microseconds")
	assert(Formatter.time(0.001):match("ms"), "Should format milliseconds")
	assert(Formatter.time(1):match("s"), "Should format seconds")

	-- Test number formatting
	assert(Formatter.number(1500000):match("M"), "Should format millions")
	assert(Formatter.number(1500):match("K"), "Should format thousands")

	-- Test benchmark formatting
	local test_summary = {
		name = "test",
		raw_count = 100,
		count = 95,
		min = 0.001,
		max = 0.005,
		mean = 0.002,
		median = 0.002,
		stddev = 0.0005,
		ops_sec = 500,
	}
	local output = Formatter.benchmark("test", test_summary)
	assert(output:match("Benchmark: test"), "Should include benchmark name")
	assert(output:match("Iterations:"), "Should include iterations")

	print("All Formatter tests passed ✔")
end
--]]

-- Export
return Formatter
