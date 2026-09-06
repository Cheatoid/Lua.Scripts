-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Localized global functions for better performance
local math_abs = math.abs
local math_ceil = math.ceil
local math_floor = math.floor
local math_sqrt = math.sqrt
local table_sort = table.sort

--- Define the StatsOptions class<br>
--- Options for Stats.summarize and statistical calculations.
---@class benchmark.StatsOptions
---@field remove_outliers? boolean Whether to remove outliers (default: true).
---@field outlier_method "sd"|"iqr" Outlier detection method (default: "sd").
---@field outlier_threshold? number SD threshold for "sd" method (default: 2.0).
---@field outlier_k? number IQR multiplier for "iqr" method (default: 1.5).
---@field percentiles? integer[] Percentiles to compute (default: {50, 90, 95, 99}).
---@field include_ci? boolean Include 95% confidence interval (default: false).

--- Define the Stats module<br>
--- Pure statistical helpers for benchmark analysis (no I/O, no deps).
---@class benchmark.Stats
local Stats = {}

----------------------------------------------------------------------
-- HELPERS
----------------------------------------------------------------------

--- Clone a numeric array.
---@param t number[] The array to clone.
---@return number[] out Cloned array.
local function clone(t)
	local out = {}
	for i = 1, #t do
		out[i] = t[i]
	end
	return out
end

--- Return a sorted copy of an array.
---@param t number[] The array to sort.
---@return number[] s Sorted copy.
local function sorted(t)
	local s = clone(t)
	table_sort(s, function(a, b) return a < b end)
	return s
end

----------------------------------------------------------------------
-- BASIC MEASURES
----------------------------------------------------------------------

--- Count the number of elements in an array.
---@param v number[] The array.
---@return integer count Number of elements.
function Stats.count(v)
	return #v
end

--- Sum all elements in an array.
---@param v number[] The array.
---@return number sum Sum of all elements.
function Stats.sum(v)
	local s = 0
	for i = 1, #v do
		s = s + v[i]
	end
	return s
end

--- Calculate the arithmetic mean of an array.
---@param v number[] The array.
---@return number mean Arithmetic mean (0 if empty).
function Stats.mean(v)
	local n = #v
	if n == 0 then
		return 0
	end
	return Stats.sum(v) / n
end

--- Calculate the median of an array.
---@param v number[] The array.
---@return number median Median value (0 if empty).
function Stats.median(v)
	local n = #v
	if n == 0 then
		return 0
	end
	local s = sorted(v)
	local mid = (n + 1) / 2
	local lo = math_floor(mid)
	local hi = math_ceil(mid)
	if lo == hi then
		return s[lo]
	end
	return (s[lo] + s[hi]) / 2
end

--- Calculate the mode (most frequent value) of an array.
---@param v number[] The array.
---@return number mode Most frequent value (0 if empty).
function Stats.mode(v)
	local n = #v
	if n == 0 then
		return 0
	end
	local freq, best, best_n = {}, v[1], 0
	for i = 1, n do
		local val = v[i]
		freq[val] = (freq[val] or 0) + 1
		if freq[val] > best_n then
			best_n = freq[val]
			best = val
		end
	end
	return best
end

--- Find the minimum value in an array.
---@param v number[] The array.
---@return number min Minimum value (0 if empty).
function Stats.min(v)
	if #v == 0 then
		return 0
	end
	local m = v[1]
	for i = 2, #v do
		if v[i] < m then
			m = v[i]
		end
	end
	return m
end

--- Find the maximum value in an array.
---@param v number[] The array.
---@return number max Maximum value (0 if empty).
function Stats.max(v)
	if #v == 0 then
		return 0
	end
	local m = v[1]
	for i = 2, #v do
		if v[i] > m then
			m = v[i]
		end
	end
	return m
end

--- Calculate the range (max - min) of an array.
---@param v number[] The array.
---@return number range Range of values.
function Stats.range(v)
	return Stats.max(v) - Stats.min(v)
end

----------------------------------------------------------------------
-- VARIANCE / STDDEV / STDERR
----------------------------------------------------------------------

--- Calculate the variance of an array.
---@param v number[] The array.
---@param sample? boolean If true, use sample variance (n-1); otherwise population (n).
---@return number variance Variance value.
function Stats.variance(v, sample)
	local n = #v
	if n < (sample and 2 or 1) then
		return 0
	end
	local m = Stats.mean(v)
	local ss = 0
	for i = 1, n do
		ss = ss + (v[i] - m) ^ 2
	end
	return ss / (n - (sample and 1 or 0))
end

--- Calculate the standard deviation of an array.
---@param v number[] The array.
---@param sample? boolean If true, use sample stddev; otherwise population.
---@return number stddev Standard deviation.
function Stats.stddev(v, sample)
	return math_sqrt(Stats.variance(v, sample ~= false))
end

--- Calculate the standard error of the mean.
---@param v number[] The array.
---@return number stderr Standard error (0 if fewer than 2 samples).
function Stats.stderr(v)
	local n = #v
	if n < 2 then
		return 0
	end
	return Stats.stddev(v, true) / math_sqrt(n)
end

----------------------------------------------------------------------
-- PERCENTILES / IQR
----------------------------------------------------------------------

--- Linear-interpolation percentile (matches numpy "method='linear'").
---@param v number[] The array.
---@param p number Percentile to calculate (0-100).
---@return number percentile The p-th percentile value.
function Stats.percentile(v, p)
	local n = #v
	if n == 0 then
		return 0
	end
	if n == 1 then
		return v[1]
	end
	local s = sorted(v)
	local k = (p / 100) * (n - 1) + 1
	local lo = math_floor(k)
	local hi = math_ceil(k)
	if lo == hi then
		return s[lo]
	end
	return s[lo] * (hi - k) + s[hi] * (k - lo)
end

--- Calculate the interquartile range (IQR).
---@param v number[] The array.
---@return number iqr The IQR value (P75 - P25).
function Stats.iqr(v)
	return Stats.percentile(v, 75) - Stats.percentile(v, 25)
end

----------------------------------------------------------------------
-- OUTLIER FILTERING
----------------------------------------------------------------------

--- Remove values outside `threshold` standard deviations of the mean.<br>
--- Uses standard deviation method for outlier detection.
---@param v number[] Raw samples.
---@param threshold? number Standard deviation threshold (default: 2).
---@return number[] filtered Filtered array (returns clone if everything removed).
function Stats.removeOutliers(v, threshold)
	threshold = threshold or 2.0
	if #v < 3 then
		return clone(v)
	end
	local m = Stats.mean(v)
	local sd = Stats.stddev(v)
	local out, kept = {}, 0
	for i = 1, #v do
		if math_abs(v[i] - m) <= threshold * sd then
			kept = kept + 1
			out[kept] = v[i]
		end
	end
	return kept > 0 and out or clone(v)
end

--- IQR-based outlier filter (Tukey's fence, 1.5x IQR).
---@param v number[] Raw samples.
---@param k? number IQR multiplier (default: 1.5).
---@return number[] filtered Filtered array.
function Stats.removeOutliersIqr(v, k)
	k = k or 1.5
	if #v < 4 then
		return clone(v)
	end
	local q1 = Stats.percentile(v, 25)
	local q3 = Stats.percentile(v, 75)
	local lo = q1 - k * (q3 - q1)
	local hi = q3 + k * (q3 - q1)
	local out, kept = {}, 0
	for i = 1, #v do
		if v[i] >= lo and v[i] <= hi then
			kept = kept + 1
			out[kept] = v[i]
		end
	end
	return kept > 0 and out or clone(v)
end

----------------------------------------------------------------------
-- CONFIDENCE
----------------------------------------------------------------------

--- Calculate 95% confidence interval for the mean (Gaussian approximation).
---@param v number[] The array.
---@return number lo Lower bound of CI.
---@return number hi Upper bound of CI.
function Stats.confidenceInterval95(v)
	local n = #v
	if n < 2 then
		return Stats.mean(v), Stats.mean(v)
	end
	local m = Stats.mean(v)
	local se = Stats.stderr(v)
	local z = 1.96
	return m - z * se, m + z * se
end

----------------------------------------------------------------------
-- THROUGHPUT
----------------------------------------------------------------------

--- Calculate operations per second given per-call timings.
---@param v number[] Array of per-call timings in seconds.
---@return number ops_sec Operations per second.
function Stats.opsPerSecond(v)
	local m = Stats.mean(v)
	if m <= 0 then
		return 0
	end
	return 1 / m
end

----------------------------------------------------------------------
-- SUMMARIZE
----------------------------------------------------------------------

--- Produce a summary table from raw timings.<br>
--- Computes comprehensive statistics including optional outlier removal and percentiles.
---@param v number[] Raw timing samples.
---@param opts? benchmark.StatsOptions Options for summarization.
---@return table summary Summary table with all statistics.
function Stats.summarize(v, opts)
	opts = opts or {}
	local filtered = v

	if opts.remove_outliers ~= false then
		if opts.outlier_method == "iqr" then
			filtered = Stats.removeOutliersIqr(v, opts.outlier_k)
		else
			filtered = Stats.removeOutliers(v, opts.outlier_threshold)
		end
	end

	local n = #filtered
	local summary = {
		raw_count = #v,
		count = n,
		sum = Stats.sum(filtered),
		mean = Stats.mean(filtered),
		median = Stats.median(filtered),
		stddev = Stats.stddev(filtered, true),
		stderr = Stats.stderr(filtered),
		min = Stats.min(filtered),
		max = Stats.max(filtered),
		range = Stats.range(filtered),
		ops_sec = Stats.opsPerSecond(filtered),
	}

	if opts.include_ci then
		summary.ci_lo, summary.ci_hi = Stats.confidenceInterval95(filtered)
	end

	if opts.percentiles and #opts.percentiles > 0 then
		summary.percentiles = {}
		local percentiles = opts.percentiles
		for i = 1, #percentiles do
			local p = percentiles[i]
			summary.percentiles[p] = Stats.percentile(filtered, p)
		end
	end

	return summary
end

--[[ Quick tests
if true then
	-- Test basic statistics
	local data = { 1, 2, 3, 4, 5 }
	assert(Stats.count(data) == 5, "Count should be 5")
	assert(Stats.sum(data) == 15, "Sum should be 15")
	assert(Stats.mean(data) == 3, "Mean should be 3")
	assert(Stats.median(data) == 3, "Median should be 3")
	assert(Stats.min(data) == 1, "Min should be 1")
	assert(Stats.max(data) == 5, "Max should be 5")
	assert(Stats.range(data) == 4, "Range should be 4")

	-- Test mode
	local mode_data = { 1, 2, 2, 3, 3, 3 }
	assert(Stats.mode(mode_data) == 3, "Mode should be 3")

	-- Test percentiles
	assert(Stats.percentile(data, 50) == 3, "P50 should be 3")

	-- Test outlier removal
	local outlier_data = { 1, 2, 3, 4, 5, 100 }
	local filtered = Stats.removeOutliers(outlier_data, 2.0)
	assert(#filtered < #outlier_data, "Should remove outliers")

	-- Test summarize
	local summary = Stats.summarize(data, { include_ci = true, percentiles = { 50, 90 } })
	assert(summary.count == 5, "Summary count should be 5")
	assert(summary.mean == 3, "Summary mean should be 3")
	assert(summary.ci_lo ~= nil, "Should include CI when requested")
	assert(summary.percentiles ~= nil, "Should include percentiles when requested")

	print("All tests passed")
end
--]]

-- Export
return Stats
