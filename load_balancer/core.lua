-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

----------------------------------------------------------------------
-- CORE UTILITIES
----------------------------------------------------------------------

--- EventEmitter - Pub/Sub pattern for system-wide events.<br>
--- Provides publish/subscribe functionality for event-driven architecture.
---@class load_balancer.EventEmitter
---@field _listeners table<string, table<{callback: fun(...): any, priority: number}>> Map of event names to listener arrays.
---@field _onceListeners table<string, table<{callback: fun(...): any}>> Map of event names to one-time listener arrays.
local EventEmitter = {}
EventEmitter.__index = EventEmitter

--- Create a new EventEmitter instance.<br>
--- Initializes empty listener maps.
---@return load_balancer.EventEmitter instance New EventEmitter instance.
function EventEmitter.new()
	local self = setmetatable({}, EventEmitter)
	self._listeners = {}
	self._onceListeners = {}
	return self
end

--- Register a persistent event listener.<br>
--- The listener will be called every time the event is emitted.<br>
--- Listeners can be prioritized; higher priority listeners are called first.
---@param self load_balancer.EventEmitter The EventEmitter instance.
---@param event string The event name to listen for.
---@param callback fun(...): any The callback function to invoke when the event is emitted.
---@param priority number Optional priority level (default: 0). Higher values are called first.
---@return load_balancer.EventEmitter instance The EventEmitter instance for chaining.
function EventEmitter.on(self, event, callback, priority)
	priority = priority or 0
	self._listeners[event] = self._listeners[event] or {}
	table.insert(self._listeners[event], {
		callback = callback,
		priority = priority
	})
	table.sort(self._listeners[event], function(a, b)
		return a.priority > b.priority
	end)
	return self
end

--- Register a one-time event listener.<br>
--- The listener will be called only once when the event is emitted, then automatically removed.
---@param self load_balancer.EventEmitter The EventEmitter instance.
---@param event string The event name to listen for.
---@param callback fun(...): any The callback function to invoke when the event is emitted.
---@return load_balancer.EventEmitter instance The EventEmitter instance for chaining.
function EventEmitter.once(self, event, callback)
	self._onceListeners[event] = self._onceListeners[event] or {}
	table.insert(self._onceListeners[event], { callback = callback })
	return self
end

--- Remove an event listener.<br>
--- Removes the specified callback from both regular and one-time listeners.
---@param self load_balancer.EventEmitter The EventEmitter instance.
---@param event string The event name to remove the listener from.
---@param callback fun(...): any The callback function to remove.
---@return load_balancer.EventEmitter instance The EventEmitter instance for chaining.
function EventEmitter.off(self, event, callback)
	local function removeListener(listeners)
		if not listeners[event] then return end
		for i = #listeners[event], 1, -1 do
			if listeners[event][i].callback == callback then
				table.remove(listeners[event], i)
			end
		end
	end
	removeListener(self._listeners)
	removeListener(self._onceListeners)
	return self
end

--- Emit an event and call all registered listeners.<br>
--- Calls all regular listeners, then all one-time listeners (which are removed after being called).
---@param self load_balancer.EventEmitter The EventEmitter instance.
---@param event string The event name to emit.
---@param ... any Arguments to pass to the listeners.
---@return any[] Array of return values from listeners.
function EventEmitter.emit(self, event, ...)
	local results = {}

	-- Regular listeners
	if self._listeners[event] then
		for _, listener in ipairs(self._listeners[event]) do
			local result = listener.callback(...)
			if result ~= nil then
				table.insert(results, result)
			end
		end
	end

	-- Once listeners
	if self._onceListeners[event] then
		for _, listener in ipairs(self._onceListeners[event]) do
			local result = listener.callback(...)
			if result ~= nil then
				table.insert(results, result)
			end
		end
		self._onceListeners[event] = nil
	end

	return results
end

--- MetricsCollector - Track system performance metrics.<br>
--- Provides counters, gauges, histograms, and timers for monitoring.
---@class load_balancer.MetricsCollector
---@field _counters table<string, number> Counter metrics that only increment.
---@field _gauges table<string, number> Gauge metrics that can go up or down.
---@field _histograms table<string, number[]> Histogram metrics for distribution tracking.
---@field _timers table<string, number> Active timers for duration measurement.
local MetricsCollector = {}
MetricsCollector.__index = MetricsCollector

--- Create a new MetricsCollector instance.<br>
--- Initializes empty metric storage.
---@return load_balancer.MetricsCollector instance New MetricsCollector instance.
function MetricsCollector.new()
	local self = setmetatable({}, MetricsCollector)
	self._counters = {}
	self._gauges = {}
	self._histograms = {}
	self._timers = {}
	return self
end

--- Increment a counter metric.<br>
--- Counters only increase and are useful for counting events.
---@param self load_balancer.MetricsCollector The MetricsCollector instance.
---@param name string The metric name.
---@param value number Optional increment amount (default: 1).
---@return load_balancer.MetricsCollector instance The MetricsCollector instance for chaining.
function MetricsCollector.incrementCounter(self, name, value)
	value = value or 1
	self._counters[name] = (self._counters[name] or 0) + value
	return self
end

--- Get the current value of a counter metric.
---@param self load_balancer.MetricsCollector The MetricsCollector instance.
---@param name string The metric name.
---@return number value The current counter value (0 if not set).
function MetricsCollector.getCounter(self, name)
	return self._counters[name] or 0
end

--- Set a gauge metric to a specific value.<br>
--- Gauges can go up or down and are useful for current state.
---@param self load_balancer.MetricsCollector The MetricsCollector instance.
---@param name string The metric name.
---@param value number The value to set.
---@return load_balancer.MetricsCollector instance The MetricsCollector instance for chaining.
function MetricsCollector.setGauge(self, name, value)
	self._gauges[name] = value
	return self
end

--- Get the current value of a gauge metric.
---@param self load_balancer.MetricsCollector The MetricsCollector instance.
---@param name string The metric name.
---@return number? value The current gauge value (nil if not set).
function MetricsCollector.getGauge(self, name)
	return self._gauges[name]
end

--- Record a value in a histogram metric.<br>
--- Histograms track distribution of values (e.g. response times).<br>
--- Keeps only the last 1000 entries to prevent unbounded growth.
---@param self load_balancer.MetricsCollector The MetricsCollector instance.
---@param name string The metric name.
---@param value number The value to record.
---@return load_balancer.MetricsCollector instance The MetricsCollector instance for chaining.
function MetricsCollector.recordHistogram(self, name, value)
	self._histograms[name] = self._histograms[name] or {}
	table.insert(self._histograms[name], value)

	-- Keep only last 1000 entries
	if #self._histograms[name] > 1000 then
		table.remove(self._histograms[name], 1)
	end
	return self
end

--- Get statistics for a histogram metric.<br>
--- Calculates min, max, avg, and percentiles (p50, p95, p99).
---@param self load_balancer.MetricsCollector The MetricsCollector instance.
---@param name string The metric name.
---@return table? stats Histogram statistics or nil if no data.
function MetricsCollector.getHistogramStats(self, name)
	local data = self._histograms[name]
	if not data or #data == 0 then return end

	table.sort(data)
	local sum = 0
	for i = 1, #data do sum = sum + data[i] end

	return {
		count = #data,
		min = data[1],
		max = data[#data],
		avg = sum / #data,
		p50 = data[math.ceil(#data * 0.50)],
		p95 = data[math.ceil(#data * 0.95)],
		p99 = data[math.ceil(#data * 0.99)]
	}
end

--- Start a timer for measuring duration.<br>
--- Records the current time for later endTimer call.
---@param self load_balancer.MetricsCollector The MetricsCollector instance.
---@param name string The timer name.
---@return load_balancer.MetricsCollector instance The MetricsCollector instance for chaining.
function MetricsCollector.startTimer(self, name)
	self._timers[name] = os.clock()
	return self
end

--- End a timer and return the elapsed time.<br>
--- Calculates time since startTimer was called.
---@param self load_balancer.MetricsCollector The MetricsCollector instance.
---@param name string The timer name.
---@return number? elapsed Elapsed time in seconds, or nil if timer not found.
function MetricsCollector.endTimer(self, name)
	if not self._timers[name] then return end
	local elapsed = os.clock() - self._timers[name]
	self._timers[name] = nil
	return elapsed
end

--- Logger - Simple logging abstraction.<br>
--- Provides leveled logging with configurable output writers.<br>
--- Supports DEBUG, INFO, WARN, and ERROR levels.
---@class load_balancer.Logger
---@field _level number Minimum log level to output (1=DEBUG, 2=INFO, 3=WARN, 4=ERROR).
---@field _outputs fun(message: string)[] Array of output writer functions.
local Logger = {}
Logger.__index = Logger

--- Log level constants.<br>
--- Used to set minimum log level and categorize messages.
---@class load_balancer.LOG_LEVELS
---@field DEBUG number Debug level (1) - most verbose.
---@field INFO number Info level (2) - general information.
---@field WARN number Warn level (3) - warning messages.
---@field ERROR number Error level (4) - error messages only.
local LOG_LEVELS = { DEBUG = 1, INFO = 2, WARN = 3, ERROR = 4 }

--- Create a new Logger instance.<br>
--- Sets the minimum log level and initializes empty outputs.
---@param level? string Minimum log level (default: "INFO").
---@return load_balancer.Logger instance New Logger instance.
function Logger.new(level)
	local self = setmetatable({}, Logger)
	self._level = LOG_LEVELS[level or "INFO"]
	self._outputs = {}
	return self
end

--- Add an output writer function.<br>
--- The writer function will be called with the formatted log message.
---@param self load_balancer.Logger The Logger instance.
---@param writer fun(message: string) Function to write log messages (e.g. `print`).
---@return load_balancer.Logger instance The Logger instance for chaining.
function Logger.addOutput(self, writer)
	table.insert(self._outputs, writer)
	return self
end

--- Internal method to format and output a log message.<br>
--- Formats message with timestamp and optional context, then sends to all outputs.
---@param self load_balancer.Logger The Logger instance.
---@param level number The log level of the message.
---@param levelName string The name of the log level (e.g. "INFO").
---@param message string The log message.
---@param context? table Optional key-value pairs to include in the log.
function Logger._log(self, level, levelName, message, context)
	if level < self._level then return end

	local timestamp = os.date("%Y-%m-%d %H:%M:%S")
	local entry = string.format("[%s] %s: %s", timestamp, levelName, message)

	if context then
		local ctxStr = {}
		for k, v in pairs(context) do
			table.insert(ctxStr, string.format("%s=%s", k, tostring(v)))
		end
		entry = entry .. " | " .. table.concat(ctxStr, ", ")
	end

	for _, writer in ipairs(self._outputs) do
		writer(entry)
	end
end

--- Log a debug message.<br>
--- Only outputs if logger level is DEBUG or lower.
---@param self load_balancer.Logger The Logger instance.
---@param message string The log message.
---@param context? table Optional key-value pairs to include in the log.
function Logger.debug(self, message, context)
	self:_log(LOG_LEVELS.DEBUG, "DEBUG", message, context)
end

--- Log an info message.<br>
--- Only outputs if logger level is INFO or lower.
---@param self load_balancer.Logger The Logger instance.
---@param message string The log message.
---@param context? table Optional key-value pairs to include in the log.
function Logger.info(self, message, context)
	self:_log(LOG_LEVELS.INFO, "INFO", message, context)
end

--- Log a warning message.<br>
--- Only outputs if logger level is WARN or lower.
---@param self load_balancer.Logger The Logger instance.
---@param message string The log message.
---@param context? table Optional key-value pairs to include in the log.
function Logger.warn(self, message, context)
	self:_log(LOG_LEVELS.WARN, "WARN", message, context)
end

--- Log an error message.<br>
--- Always outputs regardless of logger level.
---@param self load_balancer.Logger The Logger instance.
---@param message string The log message.
---@param context? table Optional key-value pairs to include in the log.
function Logger.error(self, message, context)
	self:_log(LOG_LEVELS.ERROR, "ERROR", message, context)
end

-- Export
return {
	EventEmitter = EventEmitter,
	MetricsCollector = MetricsCollector,
	Logger = Logger,
	LOG_LEVELS = LOG_LEVELS
}
