-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Library-wide defaults (edit or override per-instance)

--- Define the Config module<br>
--- Library-wide defaults for benchmark configuration.
--- Modify this table or override per-instance.
---@class benchmark.Config
---@field time_func benchmark.TimerFunc The default timing function. Swap for high-resolution alternatives:<br>
--- LuaJIT: `require("jit").os.clock` or `require("jit.profile").start` stubs;<br>
--- Linux: `(require("benchmark.hires"))()` -- your own ffi-based clock_gettime
---@field default_iterations integer Default number of iterations for fixed-iteration benchmarks.
---@field default_warmup integer Default number of warmup iterations before measurement.
---@field default_timeout number Default timeout in seconds (wall-clock safety cap).
---@field precision integer Decimal places in formatted output.
---@field remove_outliers boolean Whether to remove outliers by default.
---@field outlier_method string Outlier detection method: "sd" (standard deviation) or "iqr" (Tukey's fence).
---@field outlier_threshold number Standard deviation threshold for "sd" method.
---@field outlier_k number IQR multiplier for "iqr" method.
---@field show_percentiles integer[]|nil Array of percentiles to compute (e.g. `{ 50, 90, 95, 99 }`).
---@field include_ci boolean Include 95% Gaussian CI for the mean.
local Config = {
	time_func = os.clock,
	default_iterations = 1000,
	default_warmup = 50,
	default_timeout = 30,
	precision = 3,
	remove_outliers = true,
	outlier_method = "sd",
	outlier_threshold = 2.0,
	outlier_k = 1.5,
	show_percentiles = { 50, 90, 95, 99 },
	include_ci = false,
}

-- Export
return Config
