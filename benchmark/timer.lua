-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Localized global functions for better performance
local setmetatable = setmetatable
local os_clock = os.clock
local table_unpack = table.unpack or unpack

--- Define the Timer class
---@class benchmark.Timer
---@field time_func benchmark.TimerFunc Function returning elapsed seconds
---@field started boolean Whether the timer has been started
---@field stopped boolean Whether the timer has been stopped
---@field start_ts number Timestamp when timer was started
---@field elapsed number Total elapsed time in seconds
---@field laps table[] Array of lap records
local Timer = {}
Timer.__index = Timer

--- Create a new Timer instance.<br>
--- Low-level stopwatch / timer primitive for precise timing measurements.
---@param time_func? benchmark.TimerFunc Function returning elapsed seconds (default: `os.clock`)
---@return benchmark.Timer timer New Timer instance.
---@usage <br>
--- ```
--- local timer = Timer.new()
--- timer:start()
--- -- ... do work ...
--- local elapsed = timer:stop()
--- ```
function Timer.new(time_func)
	local self = setmetatable({
		time_func = time_func or os_clock
	}, Timer)
	self:_resetState()
	return self
end

Timer.__call = Timer.new

--- Reset the timer's internal state.
---@param self benchmark.Timer The Timer instance.
function Timer._resetState(self)
	self.started = false
	self.stopped = false
	self.start_ts = 0
	self.elapsed = 0
	self.laps = {}
end

--- Start (or restart) the timer.<br>
--- Resets elapsed time and laps if previously started.
---@param self benchmark.Timer The Timer instance.
---@return benchmark.Timer self The Timer instance for chaining.
---@usage <br>
--- ```
--- local timer = Timer.new()
--- timer:start()
--- ```
function Timer.start(self)
	self.start_ts = self.time_func()
	self.started = true
	self.stopped = false
	self.elapsed = 0
	self.laps = {}
	return self
end

--- Stop the timer and return elapsed seconds.<br>
--- If not started or already stopped, returns the cached elapsed time.
---@param self benchmark.Timer The Timer instance.
---@return number elapsed Elapsed seconds (0 if not started).
---@usage <br>
--- ```
--- local timer = Timer.new()
--- timer:start()
--- -- ... do work ...
--- local elapsed = timer:stop()
--- ```
function Timer.stop(self)
	if not self.started or self.stopped then
		return self.elapsed
	end
	self.elapsed = self.time_func() - self.start_ts
	self.stopped = true
	return self.elapsed
end

--- Record a named lap point (does NOT stop the timer).<br>
--- Captures current elapsed time without interrupting measurement.
---@param self benchmark.Timer The Timer instance.
---@param name? string Optional label for this lap.
---@return number total Total elapsed seconds at this lap.
---@usage <br>
--- ```
--- local timer = Timer.new()
--- timer:start()
--- timer:lap("phase1")
--- -- ... more work ...
--- timer:lap("phase2")
--- ```
function Timer.lap(self, name)
	local now = self.time_func()
	local total = now - self.start_ts
	local prev = self.laps[#self.laps] and self.laps[#self.laps].total or 0
	self.laps[#self.laps + 1] = {
		name = name,
		total = total,
		delta = total - prev,
	}
	return total
end

--- Reset to initial state.<br>
--- Clears all timing data but preserves the time function.
---@param self benchmark.Timer The Timer instance.
---@return benchmark.Timer self The Timer instance for chaining.
---@usage <br>
--- ```
--- local timer = Timer.new()
--- timer:start()
--- timer:stop()
--- timer:reset() -- Ready for new measurement
--- ```
function Timer.reset(self)
	self:_resetState()
	return self
end

--- Execute `func(...)` between start/stop and return elapsed + results.<br>
--- Convenience method for timing a single function call.
---@param self benchmark.Timer The Timer instance.
---@param func function The function to time.
---@param ... any Arguments forwarded to func.
---@return number elapsed Elapsed time in seconds.
---@return ... any Results from func.
---@usage <br>
--- ```
--- local timer = Timer.new()
--- local elapsed, result = timer:time(function(x) return x * 2 end, 21)
--- -- elapsed = time taken, result = 42
--- ```
function Timer.time(self, func, ...)
	self:start()
	local results = { func(...) }
	self:stop()
	return self.elapsed, table_unpack(results)
end

--- Static convenience: measure one call without constructing a Timer.<br>
--- Creates a temporary timer, measures the function, and returns results.
---@param func function The function to measure.
---@param time_func? benchmark.TimerFunc Optional timing function.
---@param ... any Arguments forwarded to func.
---@return number elapsed Elapsed time in seconds.
---@return ... any Results from func.
---@usage <br>
--- ```
--- local elapsed, result = Timer.measure(function(x) return x * 2 end, nil, 21)
--- ```
function Timer.measure(func, time_func, ...)
	return Timer.new(time_func):time(func, ...)
end

-- Export
return Timer
