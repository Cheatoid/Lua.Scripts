-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Import dependencies
local CoreUtilities = require "core"
local EventEmitter = CoreUtilities.EventEmitter
local MetricsCollector = CoreUtilities.MetricsCollector
local Logger = CoreUtilities.Logger

----------------------------------------------------------------------
-- Backend Server Abstraction
----------------------------------------------------------------------

--- Backend server abstraction.<br>
--- Represents a single backend server in the load balancer pool.<br>
--- Tracks health, connections, and performance metrics.
---@class load_balancer.Backend
---@field id string Unique identifier for the backend.
---@field host string Backend host address.
---@field port number Backend port number.
---@field weight? number Weight for weighted load balancing (default: 1).
---@field maxConnections number Maximum concurrent connections allowed.
---@field metadata table Additional metadata for the backend.
---@field _activeConnections number Current number of active connections.
---@field _status string Current status (healthy, unhealthy, draining, offline).
---@field _totalRequests number Total requests handled by this backend.
---@field _failedRequests number Total failed requests.
---@field _lastHealthCheck number Timestamp of last health check.
---@field _consecutiveFailures number Count of consecutive failures.
---@field _avgResponseTime number Average response time in milliseconds.
---@field _responseTimes number[] Array of recent response times (max 100).
local Backend = {}
Backend.__index = Backend

--- Configuration table for Backend.<br>
--- Contains backend initialization parameters.
---@class load_balancer.BackendConfig
---@field id? string Optional unique identifier (auto-generated if not provided).
---@field host string Backend host address.
---@field port number Backend port number.
---@field weight? number Optional weight for load balancing (default: 1).
---@field maxConnections? number Optional max concurrent connections (default: 1000).
---@field metadata? table Optional additional metadata.

--- Create a new Backend instance.<br>
--- Initializes backend with configuration and runtime state.
---@param config load_balancer.BackendConfig Configuration table.
---@return load_balancer.Backend instance New Backend instance.
function Backend.new(config)
	return setmetatable({
		id = config.id or ("backend_" .. tostring(math.random(100000))),
		host = config.host,
		port = config.port,
		weight = config.weight or 1,
		maxConnections = config.maxConnections or 1000,
		metadata = config.metadata or {},
		-- Runtime state
		_activeConnections = 0,
		_status = "healthy", -- healthy, unhealthy, draining, offline
		_totalRequests = 0,
		_failedRequests = 0,
		_lastHealthCheck = 0,
		_consecutiveFailures = 0,
		_avgResponseTime = 0,
		_responseTimes = {},
	}, Backend)
end

--- Get the backend's unique identifier.
---@param self load_balancer.Backend The Backend instance.
---@return string id The backend's unique identifier.
function Backend.getId(self)
	return self.id
end

--- Get the backend's address in host:port format.
---@param self load_balancer.Backend The Backend instance.
---@return string address The backend's address.
function Backend.getAddress(self)
	return self.host .. ":" .. tostring(self.port)
end

--- Get the backend's current status.
---@param self load_balancer.Backend The Backend instance.
---@return string status Current status (healthy, unhealthy, draining, offline).
function Backend.getStatus(self)
	return self._status
end

--- Set the backend's status.
---@param self load_balancer.Backend The Backend instance.
---@param status string New status (healthy, unhealthy, draining, offline).
---@return boolean changed True if status changed, false otherwise.
function Backend.setStatus(self, status)
	local oldStatus = self._status
	self._status = status
	if oldStatus ~= status then
		return true -- Status changed
	end
	return false
end

--- Check if the backend is healthy.
---@param self load_balancer.Backend The Backend instance.
---@return boolean healthy True if status is healthy.
function Backend.isHealthy(self)
	return self._status == "healthy"
end

--- Check if the backend is available for requests.<br>
--- Backend is available if healthy and under max connections.
---@param self load_balancer.Backend The Backend instance.
---@return boolean available True if available for requests.
function Backend.isAvailable(self)
	return self._status == "healthy" and
		self._activeConnections < self.maxConnections
end

--- Get the current number of active connections.
---@param self load_balancer.Backend The Backend instance.
---@return number count Current active connection count.
function Backend.getActiveConnections(self)
	return self._activeConnections
end

--- Get the number of available connection slots.
---@param self load_balancer.Backend The Backend instance.
---@return number slots Available connection slots (never negative).
function Backend.getAvailableSlots(self)
	return math.max(0, self.maxConnections - self._activeConnections)
end

--- Get the current utilization ratio (0-1).<br>
--- Ratio of active connections to max connections.
---@param self load_balancer.Backend The Backend instance.
---@return number utilization Utilization ratio (0-1).
function Backend.getUtilization(self)
	if self.maxConnections == 0 then return 1 end
	return self._activeConnections / self.maxConnections
end

--- Increment the active connection count.<br>
--- Also increments total request counter.
---@param self load_balancer.Backend The Backend instance.
---@return number count New active connection count.
function Backend.incrementConnections(self)
	self._activeConnections = self._activeConnections + 1
	self._totalRequests = self._totalRequests + 1
	return self._activeConnections
end

--- Decrement the active connection count.<br>
--- Ensures count never goes below zero.
---@param self load_balancer.Backend The Backend instance.
---@return number count New active connection count.
function Backend.decrementConnections(self)
	self._activeConnections = math.max(0, self._activeConnections - 1)
	return self._activeConnections
end

--- Record a response time and success status.<br>
--- Updates response time tracking and failure counters.<br>
--- Keeps only the last 100 response times.
---@param self load_balancer.Backend The Backend instance.
---@param timeMs number Response time in milliseconds.
---@param success boolean Whether the request succeeded.
function Backend.recordResponse(self, timeMs, success)
	table.insert(self._responseTimes, timeMs)
	if #self._responseTimes > 100 then
		table.remove(self._responseTimes, 1)
	end

	-- Calculate moving average
	local sum = 0
	for i = 1, #self._responseTimes do
		sum = sum + self._responseTimes[i]
	end
	self._avgResponseTime = sum / #self._responseTimes

	if success then
		self._consecutiveFailures = 0
	else
		self._failedRequests = self._failedRequests + 1
		self._consecutiveFailures = self._consecutiveFailures + 1
	end
end

--- Get the average response time in milliseconds.
---@param self load_balancer.Backend The Backend instance.
---@return number avgResponseTime Average response time.
function Backend.getAvgResponseTime(self)
	return self._avgResponseTime
end

--- Get the success rate (0-1).<br>
--- Ratio of successful requests to total requests.
---@param self load_balancer.Backend The Backend instance.
---@return number successRate Success rate (0-1).
function Backend.getSuccessRate(self)
	if self._totalRequests == 0 then return 1 end
	return (self._totalRequests - self._failedRequests) / self._totalRequests
end

--- Get the count of consecutive failures.
---@param self load_balancer.Backend The Backend instance.
---@return number failures Count of consecutive failures.
function Backend.getConsecutiveFailures(self)
	return self._consecutiveFailures
end

--- Get comprehensive backend statistics.<br>
--- Returns a table with all backend metrics.
---@param self load_balancer.Backend The Backend instance.
---@return table stats Backend statistics table.
function Backend.getStats(self)
	return {
		id = self.id,
		address = self:getAddress(),
		status = self._status,
		weight = self.weight,
		activeConnections = self._activeConnections,
		maxConnections = self.maxConnections,
		utilization = self:getUtilization(),
		totalRequests = self._totalRequests,
		failedRequests = self._failedRequests,
		successRate = self:getSuccessRate(),
		avgResponseTime = self._avgResponseTime,
		consecutiveFailures = self._consecutiveFailures
	}
end

--- Reset all runtime statistics.<br>
--- Clears connection counts, request counters, and response times.
---@param self load_balancer.Backend The Backend instance.
function Backend.reset(self)
	self._activeConnections = 0
	self._totalRequests = 0
	self._failedRequests = 0
	self._consecutiveFailures = 0
	self._avgResponseTime = 0
	self._responseTimes = {}
end

----------------------------------------------------------------------
-- Backend Pool
----------------------------------------------------------------------

--- Backend pool for managing multiple backend servers.<br>
--- Provides CRUD operations and event emission for backend changes.
---@class load_balancer.BackendPool
---@field _backends table<string, load_balancer.Backend> Map of backend IDs to Backend instances.
---@field _events load_balancer.EventEmitter Event emitter for backend lifecycle events.
local BackendPool = {}
BackendPool.__index = BackendPool

--- Create a new BackendPool instance.<br>
--- Initializes empty backend map and event emitter.
---@return load_balancer.BackendPool instance New BackendPool instance.
function BackendPool.new()
	return setmetatable({
		_backends = {},
		_events = EventEmitter.new(),
	}, BackendPool)
end

--- Get the event emitter for backend lifecycle events.<br>
--- Events: backendAdded, backendRemoved.
---@param self load_balancer.BackendPool The BackendPool instance.
---@return load_balancer.EventEmitter events Event emitter instance.
function BackendPool.getEvents(self)
	return self._events
end

--- Add a backend to the pool.<br>
--- Emits backendAdded event on success.
---@param self load_balancer.BackendPool The BackendPool instance.
---@param backend load_balancer.Backend The backend instance to add.
---@return boolean success True if added successfully.
---@return string? error Error message if addition failed.
function BackendPool.add(self, backend)
	if self._backends[backend.id] then
		return false, "Backend already exists"
	end
	self._backends[backend.id] = backend
	self._events:emit("backendAdded", backend)
	return true
end

--- Remove a backend from the pool.<br>
--- Emits backendRemoved event on success.
---@param self load_balancer.BackendPool The BackendPool instance.
---@param backendId string The ID of the backend to remove.
---@return boolean success True if removed successfully.
---@return string? error Error message if removal failed.
function BackendPool.remove(self, backendId)
	local backend = self._backends[backendId]
	if not backend then
		return false, "Backend not found"
	end
	self._backends[backendId] = nil
	self._events:emit("backendRemoved", backend)
	return true
end

--- Get a backend by ID.
---@param self load_balancer.BackendPool The BackendPool instance.
---@param backendId string The backend ID to retrieve.
---@return load_balancer.Backend|nil backend The backend instance, or nil if not found.
function BackendPool.get(self, backendId)
	return self._backends[backendId]
end

--- Get all backends in the pool.
---@param self load_balancer.BackendPool The BackendPool instance.
---@return load_balancer.Backend[] backends Array of all backend instances.
function BackendPool.getAll(self)
	local result = {}
	for _, backend in pairs(self._backends) do
		table.insert(result, backend)
	end
	return result
end

--- Get all healthy backends in the pool.
---@param self load_balancer.BackendPool The BackendPool instance.
---@return load_balancer.Backend[] backends Array of healthy backend instances.
function BackendPool.getHealthy(self)
	local result = {}
	for _, backend in pairs(self._backends) do
		if backend:isHealthy() then
			table.insert(result, backend)
		end
	end
	return result
end

--- Get all available backends in the pool.<br>
--- Available backends are healthy and under max connections.
---@param self load_balancer.BackendPool The BackendPool instance.
---@return load_balancer.Backend[] backends Array of available backend instances.
function BackendPool.getAvailable(self)
	local result = {}
	for _, backend in pairs(self._backends) do
		if backend:isAvailable() then
			table.insert(result, backend)
		end
	end
	return result
end

--- Get the total number of backends in the pool.
---@param self load_balancer.BackendPool The BackendPool instance.
---@return number count Total backend count.
function BackendPool.size(self)
	local count = 0
	for _ in pairs(self._backends) do count = count + 1 end
	return count
end

--- Get the count of healthy backends in the pool.
---@param self load_balancer.BackendPool The BackendPool instance.
---@return number count Healthy backend count.
function BackendPool.healthyCount(self)
	local count = 0
	for _, backend in pairs(self._backends) do
		if backend:isHealthy() then count = count + 1 end
	end
	return count
end

--- Get comprehensive pool statistics.<br>
--- Returns total counts by status and individual backend stats.
---@param self load_balancer.BackendPool The BackendPool instance.
---@return table stats Pool statistics table.
function BackendPool.getStats(self)
	local stats = {
		total = self:size(),
		healthy = self:healthyCount(),
		unhealthy = 0,
		draining = 0,
		backends = {}
	}

	for _, backend in pairs(self._backends) do
		local s = backend._status
		if s == "unhealthy" then
			stats.unhealthy = stats.unhealthy + 1
		elseif s == "draining" then
			stats.draining = stats.draining + 1
		end
		table.insert(stats.backends, backend:getStats())
	end

	return stats
end

----------------------------------------------------------------------
-- Health Checker
----------------------------------------------------------------------

--- Health checker for monitoring backend availability.<br>
--- Performs periodic health checks and updates backend status based on thresholds.
---@class load_balancer.HealthChecker
---@field _pool load_balancer.BackendPool The backend pool to monitor.
---@field _events load_balancer.EventEmitter Event emitter for health check events.
---@field _logger load_balancer.Logger Logger instance for health check logs.
---@field _metrics load_balancer.MetricsCollector Metrics collector for health check metrics.
---@field _checkInterval number Seconds between health checks (default: 10).
---@field _timeout number Timeout for health check requests (default: 5).
---@field _unhealthyThreshold number Consecutive failures to mark unhealthy (default: 3).
---@field _healthyThreshold number Consecutive successes to mark healthy (default: 2).
---@field _failureCounts table<string, number> Per-backend failure counters.
---@field _successCounts table<string, number> Per-backend success counters.
---@field _running boolean Whether the health checker is running.
---@field _checkTimer number Timer for periodic checks.
local HealthChecker = {}
HealthChecker.__index = HealthChecker

--- Configuration table for HealthChecker.<br>
--- Contains health checker initialization parameters.
---@class load_balancer.HealthCheckerConfig
---@field pool load_balancer.BackendPool The backend pool to monitor.
---@field logger? load_balancer.Logger Optional logger instance (default: WARN level).
---@field metrics? load_balancer.MetricsCollector Optional metrics collector.
---@field checkInterval? number Seconds between health checks (default: 10).
---@field timeout? number Health check timeout in seconds (default: 5).
---@field unhealthyThreshold? number Consecutive failures to mark unhealthy (default: 3).
---@field healthyThreshold? number Consecutive successes to mark healthy (default: 2).

--- Create a new HealthChecker instance.<br>
--- Initializes health checker with configuration for monitoring backends.
---@param config load_balancer.HealthCheckerConfig Configuration table.
---@return load_balancer.HealthChecker instance New HealthChecker instance.
function HealthChecker.new(config)
	config = config or {}
	local self = setmetatable({}, HealthChecker)
	self._pool = config.pool
	self._events = EventEmitter.new()
	self._logger = config.logger or Logger.new("WARN")
	self._metrics = config.metrics or MetricsCollector.new()

	-- Configuration
	self._checkInterval = config.checkInterval or 10 -- seconds
	self._timeout = config.timeout or 5           -- seconds
	self._unhealthyThreshold = config.unhealthyThreshold or 3
	self._healthyThreshold = config.healthyThreshold or 2
	self._failureCounts = {}
	self._successCounts = {}

	self._running = false
	self._checkTimer = nil

	return self
end

--- Get the event emitter for health check events.<br>
--- Events: backendUnhealthy, backendHealthy.
---@param self load_balancer.HealthChecker The HealthChecker instance.
---@return load_balancer.EventEmitter events Event emitter instance.
function HealthChecker.getEvents(self)
	return self._events
end

--- Simulate a health check for a backend.<br>
--- In production, this would make actual HTTP/TCP requests.<br>
--- Simulates success rate based on backend state.
---@param self load_balancer.HealthChecker The HealthChecker instance.
---@param backend load_balancer.Backend The backend to check.
---@return boolean success Whether the health check passed.
---@return number responseTime Response time in milliseconds.
function HealthChecker._simulateHealthCheck(self, backend)
	-- Abstract: In real implementation, this would make actual HTTP/TCP request
	-- Returns: success (bool), responseTime (ms)

	-- Simulate based on backend state
	local baseSuccessRate = 0.95
	if backend:getConsecutiveFailures() > 5 then
		baseSuccessRate = 0.3
	elseif backend:getUtilization() > 0.9 then
		baseSuccessRate = 0.85
	end

	local success = math.random() < baseSuccessRate
	local responseTime = 10 + math.random(50) + (backend:getUtilization() * 100)

	return success, responseTime
end

--- Perform a health check on a single backend.<br>
--- Updates backend status based on success/failure thresholds.
---@param self load_balancer.HealthChecker The HealthChecker instance.
---@param backend load_balancer.Backend The backend to check.
---@return boolean success Whether the health check passed.
---@return number responseTime Response time in milliseconds.
function HealthChecker.checkBackend(self, backend)
	local success, responseTime = self:_simulateHealthCheck(backend)
	local backendId = backend.id

	self._metrics:startTimer("health_check_" .. backendId)

	if success then
		self._failureCounts[backendId] = 0
		self._successCounts[backendId] = (self._successCounts[backendId] or 0) + 1

		-- Mark healthy if threshold reached
		if self._successCounts[backendId] >= self._healthyThreshold then
			if backend:getStatus() ~= "healthy" then
				local changed = backend:setStatus("healthy")
				if changed then
					self._events:emit("backendHealthy", backend)
					self._logger:info("Backend healthy", {
						backend = backend.id,
						address = backend:getAddress()
					})
				end
			end
		end
	else
		self._successCounts[backendId] = 0
		self._failureCounts[backendId] = (self._failureCounts[backendId] or 0) + 1

		-- Mark unhealthy if threshold reached
		if self._failureCounts[backendId] >= self._unhealthyThreshold then
			if backend:getStatus() ~= "unhealthy" then
				local changed = backend:setStatus("unhealthy")
				if changed then
					self._events:emit("backendUnhealthy", backend)
					self._logger:warn("Backend unhealthy", {
						backend = backend.id,
						address = backend:getAddress(),
						failures = self._failureCounts[backendId]
					})
				end
			end
		end
	end

	local elapsed = self._metrics:endTimer("health_check_" .. backendId)
	if elapsed then
		self._metrics:recordHistogram("health_check_time", elapsed * 1000)
	end

	return success, responseTime
end

--- Perform health checks on all backends in the pool.<br>
--- Updates last health check timestamp for each backend.
---@param self load_balancer.HealthChecker The HealthChecker instance.
---@return table results Map of backend IDs to check results.
function HealthChecker.checkAll(self)
	local backends = self._pool:getAll()
	local results = {}

	for i = 1, #backends do
		local backend = backends[i]
		results[backend.id] = self:checkBackend(backend)
		backend._lastHealthCheck = os.time()
	end

	self._metrics:incrementCounter("health_checks_total", #backends)
	return results
end

--- Start the health checker.<br>
--- Begins periodic health checks on all backends.
---@param self load_balancer.HealthChecker The HealthChecker instance.
function HealthChecker.start(self)
	if self._running then return end
	self._running = true
	self._logger:info("Health checker started")
	self:checkAll()
end

--- Stop the health checker.<br>
--- Stops periodic health checks.
---@param self load_balancer.HealthChecker The HealthChecker instance.
function HealthChecker.stop(self)
	self._running = false
	self._logger:info("Health checker stopped")
end

--- Tick function for timer-based health checks.<br>
--- Should be called periodically to perform health checks if running.
---@param self load_balancer.HealthChecker The HealthChecker instance.
function HealthChecker.tick(self)
	if not self._running then return end
	-- In real implementation, use actual timer
	-- This is a tick-based simulation
	self:checkAll()
end

----------------------------------------------------------------------
-- Circuit Breaker
----------------------------------------------------------------------

--- Circuit breaker pattern for preventing cascading failures.<br>
--- Opens circuit on consecutive failures, closes after recovery period.
---@class load_balancer.CircuitBreaker
---@field _failureThreshold number Consecutive failures to open circuit (default: 5).
---@field _recoveryTimeout number Seconds to wait before attempting recovery (default: 60).
---@field _halfOpenMaxCalls number Max calls in half-open state (default: 3).
---@field _failureCounts table<string, number> Per-backend failure counters.
---@field _lastFailureTime table<string, number> Per-backend last failure timestamps.
---@field _states table<string, string> Per-backend circuit states (closed, open, half-open).
---@field _halfOpenCounts table<string, number> Per-backend half-open call counters.
---@field _events load_balancer.EventEmitter Event emitter for circuit state changes.
local CircuitBreaker = {}
CircuitBreaker.__index = CircuitBreaker

--- Circuit breaker state constants.<br>
--- Used to track circuit state for each backend.
---@class CB_STATES
---@field CLOSED string Circuit is closed (normal operation).
---@field OPEN string Circuit is open (blocking requests).
---@field HALF_OPEN string Circuit is half-open (testing recovery).
local CB_STATES = { CLOSED = "closed", OPEN = "open", HALF_OPEN = "half_open" }

--- Configuration table for CircuitBreaker.<br>
--- Contains circuit breaker initialization parameters.
---@class load_balancer.CircuitBreakerConfig
---@field logger? load_balancer.Logger Optional logger instance (default: WARN level).
---@field metrics? load_balancer.MetricsCollector Optional metrics collector.
---@field failureThreshold? number Consecutive failures to open circuit (default: 5).
---@field recoveryTimeout? number Seconds to wait before recovery attempt (default: 30).
---@field halfOpenMaxCalls? number Max calls in half-open state (default: 3).

--- Create a new CircuitBreaker instance.<br>
--- Initializes circuit breaker with failure thresholds and recovery settings.
---@param config load_balancer.CircuitBreakerConfig Configuration table.
---@return load_balancer.CircuitBreaker instance New CircuitBreaker instance.
function CircuitBreaker.new(config)
	config = config or {}
	local self = setmetatable({}, CircuitBreaker)
	self._events = EventEmitter.new()
	self._logger = config.logger or Logger.new("WARN")
	self._metrics = config.metrics or MetricsCollector.new()

	self._failureThreshold = config.failureThreshold or 5
	self._recoveryTimeout = config.recoveryTimeout or 30 -- seconds
	self._halfOpenMaxCalls = config.halfOpenMaxCalls or 3

	-- Per-backend state
	self._states = {}     -- backend_id -> CB_STATES
	self._failures = {}   -- backend_id -> count
	self._lastFailure = {} -- backend_id -> timestamp
	self._halfOpenCalls = {} -- backend_id -> count

	return self
end

--- Get the event emitter for circuit state changes.<br>
--- Events: circuitOpened, circuitClosed, circuitHalfOpen.
---@param self load_balancer.CircuitBreaker The CircuitBreaker instance.
---@return load_balancer.EventEmitter events Event emitter instance.
function CircuitBreaker.getEvents(self)
	return self._events
end

--- Get the current circuit state for a backend.
---@param self load_balancer.CircuitBreaker The CircuitBreaker instance.
---@param backendId string The backend ID to check.
---@return string state Current circuit state (closed, open, or half_open).
function CircuitBreaker.getState(self, backendId)
	return self._states[backendId] or CB_STATES.CLOSED
end

--- Check if a request is allowed through the circuit breaker.<br>
--- Manages state transitions based on recovery timeout and half-open call limits.
---@param self load_balancer.CircuitBreaker The CircuitBreaker instance.
---@param backend load_balancer.Backend The backend to check.
---@return boolean allowed True if request is allowed, false if circuit is open.
function CircuitBreaker.allowRequest(self, backend)
	local state = self:getState(backend.id)
	local now = os.time()

	if state == CB_STATES.CLOSED then
		return true
	elseif state == CB_STATES.OPEN then
		-- Check if recovery timeout has passed
		local lastFail = self._lastFailure[backend.id] or 0
		if now - lastFail >= self._recoveryTimeout then
			self._states[backend.id] = CB_STATES.HALF_OPEN
			self._halfOpenCalls[backend.id] = 0
			self._events:emit("circuitHalfOpen", backend)
			self._logger:info("Circuit breaker half-open", { backend = backend.id })
			return true
		end
		return false
	elseif state == CB_STATES.HALF_OPEN then
		if (self._halfOpenCalls[backend.id] or 0) < self._halfOpenMaxCalls then
			self._halfOpenCalls[backend.id] = (self._halfOpenCalls[backend.id] or 0) + 1
			return true
		end
		return false
	end

	return false
end

--- Record a successful request for a backend.<br>
--- May transition circuit from half-open to closed.
---@param self load_balancer.CircuitBreaker The CircuitBreaker instance.
---@param backend load_balancer.Backend The backend that succeeded.
function CircuitBreaker.recordSuccess(self, backend)
	if self:getState(backend.id) == CB_STATES.HALF_OPEN then
		self._states[backend.id] = CB_STATES.CLOSED
		self._failures[backend.id] = 0
		self._events:emit("circuitClosed", backend)
		self._logger:info("Circuit breaker closed", { backend = backend.id })
	end
	self._failures[backend.id] = math.max(0, (self._failures[backend.id] or 0) - 1)
end

--- Record a failed request for a backend.<br>
--- May transition circuit to open based on failure threshold.
---@param self load_balancer.CircuitBreaker The CircuitBreaker instance.
---@param backend load_balancer.Backend The backend that failed.
function CircuitBreaker.recordFailure(self, backend)
	self._failures[backend.id] = (self._failures[backend.id] or 0) + 1
	self._lastFailure[backend.id] = os.time()

	local state = self:getState(backend.id)

	if state == CB_STATES.HALF_OPEN then
		self._states[backend.id] = CB_STATES.OPEN
		self._events:emit("circuitOpened", backend)
		self._logger:warn("Circuit breaker opened from half-open", { backend = backend.id })
	elseif state == CB_STATES.CLOSED then
		if self._failures[backend.id] >= self._failureThreshold then
			self._states[backend.id] = CB_STATES.OPEN
			self._events:emit("circuitOpened", backend)
			self._logger:warn("Circuit breaker opened", {
				backend = backend.id,
				failures = self._failures[backend.id]
			})
		end
	end

	self._metrics:incrementCounter("circuit_breaker_failures")
end

--- Reset the circuit breaker for a specific backend.<br>
--- Forces the circuit to closed state and clears counters.
---@param self load_balancer.CircuitBreaker The CircuitBreaker instance.
---@param backendId string The backend ID to reset.
function CircuitBreaker.reset(self, backendId)
	self._states[backendId] = CB_STATES.CLOSED
	self._failures[backendId] = 0
	self._lastFailure[backendId] = 0
	self._halfOpenCalls[backendId] = 0
end

----------------------------------------------------------------------
-- Load Balancing Strategies
----------------------------------------------------------------------

--- Base interface for load balancing strategies.<br>
--- All strategies must implement the select method.
---@class load_balancer.LoadBalanceStrategy
---@field name string Name of the strategy.
local LoadBalanceStrategy = {}
LoadBalanceStrategy.__index = LoadBalanceStrategy

--- Create a new LoadBalanceStrategy instance.
---@param name string Name of the strategy.
---@return load_balancer.LoadBalanceStrategy instance New strategy instance.
function LoadBalanceStrategy.new(name)
	return setmetatable({
		name = name,
	}, LoadBalanceStrategy)
end

--- Select a backend from the available pool.<br>
--- Must be implemented by subclasses.
---@param self load_balancer.LoadBalanceStrategy The strategy instance.
---@param backends load_balancer.Backend[] Array of available backends.
---@param requestContext? table Optional context about the request.
---@return load_balancer.Backend|nil backend Selected backend, or nil if none available.
function LoadBalanceStrategy.select(self, backends, requestContext)
	return error("Strategy:select() must be implemented by subclass", 2)
end

--- Round Robin load balancing strategy.<br>
--- Distributes requests evenly across all backends in rotation.
---@class load_balancer.RoundRobinStrategy : load_balancer.LoadBalanceStrategy
---@field _currentIndex number Current index in the rotation.
local RoundRobinStrategy = setmetatable({}, { __index = LoadBalanceStrategy })
RoundRobinStrategy.__index = RoundRobinStrategy

--- Create a new RoundRobinStrategy instance.
---@return load_balancer.LoadBalanceStrategy instance New RoundRobinStrategy instance.
function RoundRobinStrategy.new()
	local self = setmetatable(LoadBalanceStrategy.new("round_robin"), RoundRobinStrategy)
	self._currentIndex = 0
	return self
end

--- Select the next backend in round-robin rotation.<br>
--- Skips unavailable backends and continues to the next.
---@param self load_balancer.RoundRobinStrategy The strategy instance.
---@param backends load_balancer.Backend[] Array of available backends.
---@param requestContext? table Optional context about the request.
---@return load_balancer.Backend|nil backend Selected backend, or nil if none available.
function RoundRobinStrategy.select(self, backends, requestContext)
	if #backends == 0 then return end

	-- Find next available backend
	for _ = 1, #backends do
		self._currentIndex = (self._currentIndex % #backends) + 1
		local backend = backends[self._currentIndex]
		if backend and backend:isAvailable() then
			return backend
		end
	end
end

--- Least Connections load balancing strategy.<br>
--- Selects the backend with the fewest active connections.<br>
--- Uses utilization as a tie-breaker.
---@class load_balancer.LeastConnectionsStrategy : load_balancer.LoadBalanceStrategy
local LeastConnectionsStrategy = setmetatable({}, { __index = LoadBalanceStrategy })
LeastConnectionsStrategy.__index = LeastConnectionsStrategy

--- Create a new LeastConnectionsStrategy instance.
---@return load_balancer.LoadBalanceStrategy instance New LeastConnectionsStrategy instance.
function LeastConnectionsStrategy.new()
	return setmetatable(LoadBalanceStrategy.new("least_connections"), LeastConnectionsStrategy)
end

--- Select the backend with the fewest active connections.<br>
--- Uses utilization as a tie-breaker when connections are equal.
---@param self load_balancer.LeastConnectionsStrategy The strategy instance.
---@param backends load_balancer.Backend[] Array of available backends.
---@param requestContext? table Optional context about the request.
---@return load_balancer.Backend|nil backend Selected backend, or nil if none available.
function LeastConnectionsStrategy.select(self, backends, requestContext)
	if #backends == 0 then return end

	local selected
	local minConnections = math.huge

	for i = 1, #backends do
		local backend = backends[i]
		if backend:isAvailable() then
			local conn = backend:getActiveConnections()
			-- Tie-break by utilization
			if conn < minConnections or
				(conn == minConnections and backend:getUtilization() < (selected and selected:getUtilization() or 1)) then
				minConnections = conn
				selected = backend
			end
		end
	end

	return selected
end

--- Weighted load balancing strategy.<br>
--- Selects backends based on their weight configuration.<br>
--- Adjusts weight based on current utilization.
---@class load_balancer.WeightedStrategy : load_balancer.LoadBalanceStrategy
---@field _currentWeights table<string, number> Current effective weights.
local WeightedStrategy = setmetatable({}, { __index = LoadBalanceStrategy })
WeightedStrategy.__index = WeightedStrategy

--- Create a new WeightedStrategy instance.
---@return load_balancer.LoadBalanceStrategy instance New WeightedStrategy instance.
function WeightedStrategy.new()
	local self = setmetatable(LoadBalanceStrategy.new("weighted"), WeightedStrategy)
	self._currentWeights = {}
	return self
end

--- Select a backend based on weighted probability.<br>
--- Adjusts weights based on backend utilization.
---@param self load_balancer.WeightedStrategy The strategy instance.
---@param backends load_balancer.Backend[] Array of available backends.
---@param requestContext? table Optional context about the request.
---@return load_balancer.Backend|nil backend Selected backend, or nil if none available.
function WeightedStrategy.select(self, backends, requestContext)
	if #backends == 0 then return end

	local available = {}
	for i = 1, #backends do
		local backend = backends[i]
		if backend:isAvailable() then
			local weight = backend.weight
			-- Adjust weight based on utilization
			local utilization = backend:getUtilization()
			weight = weight * (1 - utilization * 0.8) -- Reduce weight for busy servers
			weight = math.max(0.1, weight)
			table.insert(available, { backend = backend, effectiveWeight = weight })
		end
	end

	if #available == 0 then return end

	-- Weighted random selection
	local totalWeight = 0
	for i = 1, #available do
		totalWeight = totalWeight + available[i].effectiveWeight
	end

	local random = math.random() * totalWeight
	local cumulative = 0

	for i = 1, #available do
		cumulative = cumulative + available[i].effectiveWeight
		if random <= cumulative then
			return available[i].backend
		end
	end

	return available[#available].backend
end

--- Consistent Hashing load balancing strategy.<br>
--- Maps requests to backends using a hash ring for sticky sessions.<br>
--- Uses virtual nodes for better distribution.
---@class load_balancer.ConsistentHashStrategy : load_balancer.LoadBalanceStrategy
---@field _virtualNodes number Number of virtual nodes per backend (default: 150).
---@field _ring table<number, load_balancer.Backend> Hash ring mapping hash values to backends.
---@field _sortedKeys number[] Sorted hash keys for binary search.
local ConsistentHashStrategy = setmetatable({}, { __index = LoadBalanceStrategy })
ConsistentHashStrategy.__index = ConsistentHashStrategy

--- Configuration table for ConsistentHashStrategy.<br>
--- Contains consistent hash strategy initialization parameters.
---@class load_balancer.ConsistentHashStrategyConfig
---@field virtualNodes? number Number of virtual nodes per backend (default: 150).

--- Create a new ConsistentHashStrategy instance.
---@param config load_balancer.ConsistentHashStrategyConfig Configuration table.
---@return load_balancer.LoadBalanceStrategy instance New ConsistentHashStrategy instance.
function ConsistentHashStrategy.new(config)
	config = config or {}
	local self = setmetatable(LoadBalanceStrategy.new("consistent_hash"), ConsistentHashStrategy)
	self._virtualNodes = config.virtualNodes or 150
	self._ring = {}
	self._sortedKeys = {}
	return self
end

--- Hash a key to a numeric value.<br>
--- Simple hash function for demonstration.
---@param self load_balancer.ConsistentHashStrategy The strategy instance.
---@param key string The key to hash.
---@return number hash The hash value.
function ConsistentHashStrategy._hash(self, key)
	-- Simple hash function (use better hash in production)
	local hash = 0
	for i = 1, #key do
		hash = (hash * 31 + string.byte(key, i)) % 2147483647
	end
	return hash
end

--- Add a backend to the hash ring with virtual nodes.
---@param self load_balancer.ConsistentHashStrategy The strategy instance.
---@param backend load_balancer.Backend The backend to add.
function ConsistentHashStrategy._addNode(self, backend)
	for i = 1, self._virtualNodes do
		local key = backend.id .. ":" .. i
		local hash = self:_hash(key)
		self._ring[hash] = backend
		table.insert(self._sortedKeys, hash)
	end
	table.sort(self._sortedKeys)
end

--- Remove a backend from the hash ring.
---@param self load_balancer.ConsistentHashStrategy The strategy instance.
---@param backend load_balancer.Backend The backend to remove.
function ConsistentHashStrategy._removeNode(self, backend)
	for i = 1, self._virtualNodes do
		local key = backend.id .. ":" .. i
		local hash = self:_hash(key)
		self._ring[hash] = nil
		for j = 1, #self._sortedKeys do
			if self._sortedKeys[j] == hash then
				table.remove(self._sortedKeys, j)
				break
			end
		end
	end
end

--- Rebuild the hash ring with current backends.
---@param self load_balancer.ConsistentHashStrategy The strategy instance.
---@param backends load_balancer.Backend[] Array of backends to add to the ring.
function ConsistentHashStrategy.updateRing(self, backends)
	self._ring = {}
	self._sortedKeys = {}
	for i = 1, #backends do
		self:_addNode(backends[i])
	end
end

--- Select a backend based on consistent hash of request context.<br>
--- Uses sessionId or userId from context for sticky sessions.
---@param self load_balancer.ConsistentHashStrategy The strategy instance.
---@param backends load_balancer.Backend[] Array of available backends.
---@param requestContext? table Optional context with sessionId or userId.
---@return load_balancer.Backend|nil backend Selected backend, or nil if none available.
function ConsistentHashStrategy.select(self, backends, requestContext)
	if #backends == 0 then return end

	-- Update ring if needed
	if #self._sortedKeys == 0 then
		self:updateRing(backends)
	end

	-- Get hash key from request context
	local hashKey = (requestContext and requestContext.sessionId) or
		(requestContext and requestContext.userId) or
		tostring(os.time())

	local hash = self:_hash(hashKey)

	-- Binary search for first node >= hash
	local low, high = 1, #self._sortedKeys
	while low <= high do
		local mid = math.floor((low + high) / 2)
		if self._sortedKeys[mid] >= hash then
			high = mid - 1
		else
			low = mid + 1
		end
	end

	-- Find next available backend (wrap around if necessary)
	for i = low, #self._sortedKeys do
		local backend = self._ring[self._sortedKeys[i]]
		if backend and backend:isAvailable() then
			return backend
		end
	end

	-- Wrap around
	for i = 1, low - 1 do
		local backend = self._ring[self._sortedKeys[i]]
		if backend and backend:isAvailable() then
			return backend
		end
	end
end

--- Adaptive load balancing strategy.<br>
--- Combines multiple metrics (response time, connections, utilization, success rate).<br>
--- Selects backend with the best composite score.
---@class load_balancer.AdaptiveStrategy : load_balancer.LoadBalanceStrategy
---@field _responseTimeWeight number Weight for response time factor (default: 0.4).
---@field _connectionWeight number Weight for connection factor (default: 0.3).
---@field _utilizationWeight number Weight for utilization factor (default: 0.2).
---@field _successRateWeight number Weight for success rate factor (default: 0.1).
local AdaptiveStrategy = setmetatable({}, { __index = LoadBalanceStrategy })
AdaptiveStrategy.__index = AdaptiveStrategy

--- Configuration table for AdaptiveStrategy.<br>
--- Contains adaptive strategy initialization parameters.
---@class load_balancer.AdaptiveStrategyConfig
---@field responseTimeWeight? number Weight for response time (default: 0.4).
---@field connectionWeight? number Weight for connections (default: 0.3).
---@field utilizationWeight? number Weight for utilization (default: 0.2).
---@field successRateWeight? number Weight for success rate (default: 0.1).

--- Create a new AdaptiveStrategy instance.
---@param config load_balancer.AdaptiveStrategyConfig Configuration table.
---@return load_balancer.LoadBalanceStrategy instance New AdaptiveStrategy instance.
function AdaptiveStrategy.new(config)
	config = config or {}
	local self = setmetatable(LoadBalanceStrategy.new("adaptive"), AdaptiveStrategy)
	self._responseTimeWeight = config.responseTimeWeight or 0.4
	self._connectionWeight = config.connectionWeight or 0.3
	self._utilizationWeight = config.utilizationWeight or 0.2
	self._successRateWeight = config.successRateWeight or 0.1
	return self
end

--- Calculate a composite score for a backend.<br>
--- Lower score indicates better performance.
---@param self load_balancer.AdaptiveStrategy The strategy instance.
---@param backend load_balancer.Backend The backend to score.
---@return number score Composite score (lower is better).
function AdaptiveStrategy._calculateScore(self, backend)
	-- Lower score is better

	-- Response time factor (normalize to 0-1, assume 1000ms max)
	local responseFactor = math.min(1, (backend:getAvgResponseTime() or 0) / 1000)

	-- Connection factor
	local connectionFactor = backend:getUtilization()

	-- Utilization factor
	local utilizationFactor = backend:getUtilization()

	-- Success rate factor (invert: 1 - successRate)
	local successFactor = 1 - backend:getSuccessRate()

	local score = (responseFactor * self._responseTimeWeight) +
		(connectionFactor * self._connectionWeight) +
		(utilizationFactor * self._utilizationWeight) +
		(successFactor * self._successRateWeight)

	return score
end

--- Select the backend with the best composite score.<br>
--- Uses weighted combination of response time, connections, utilization, and success rate.
---@param self load_balancer.AdaptiveStrategy The strategy instance.
---@param backends load_balancer.Backend[] Array of available backends.
---@param requestContext? table Optional context about the request.
---@return load_balancer.Backend|nil backend Selected backend, or nil if none available.
function AdaptiveStrategy.select(self, backends, requestContext)
	if #backends == 0 then return end

	local best
	local bestScore = math.huge

	for i = 1, #backends do
		local backend = backends[i]
		if backend:isAvailable() then
			local score = self:_calculateScore(backend)
			if score < bestScore then
				bestScore = score
				best = backend
			end
		end
	end

	return best
end

--- Power of Two Choices load balancing strategy.<br>
--- Randomly selects two backends and picks the one with fewer connections.<br>
--- Provides better load distribution than pure random.
---@class load_balancer.PowerOfTwoStrategy : load_balancer.LoadBalanceStrategy
local PowerOfTwoStrategy = setmetatable({}, { __index = LoadBalanceStrategy })
PowerOfTwoStrategy.__index = PowerOfTwoStrategy

--- Create a new PowerOfTwoStrategy instance.
---@return load_balancer.LoadBalanceStrategy instance New PowerOfTwoStrategy instance.
function PowerOfTwoStrategy.new()
	return setmetatable(LoadBalanceStrategy.new("power_of_two"), PowerOfTwoStrategy)
end

--- Select a backend using the power of two choices algorithm.<br>
--- Randomly picks two backends and selects the one with fewer connections.
---@param self load_balancer.PowerOfTwoStrategy The strategy instance.
---@param backends load_balancer.Backend[] Array of available backends.
---@param requestContext? table Optional context about the request.
---@return load_balancer.Backend|nil backend Selected backend, or nil if none available.
function PowerOfTwoStrategy.select(self, backends, requestContext)
	if #backends == 0 then return end

	local available = {}
	for i = 1, #backends do
		local b = backends[i]
		if b:isAvailable() then
			available[#available + 1] = b
		end
	end

	if #available == 0 then return end
	if #available == 1 then return available[1] end

	-- Pick two random backends
	local idx1 = math.random(#available)
	local idx2 = math.random(#available)
	while idx2 == idx1 do
		idx2 = math.random(#available)
	end

	local b1 = available[idx1]
	local b2 = available[idx2]

	-- Choose the one with fewer connections
	if b1:getActiveConnections() <= b2:getActiveConnections() then
		return b1
	end
	return b2
end

----------------------------------------------------------------------
-- Main Load Balancer
----------------------------------------------------------------------

--- Main load balancer class coordinating all components.<br>
--- Integrates backend pool, health checking, circuit breaker, and load balancing strategies.
---@class load_balancer.LoadBalancer
---@field _pool load_balancer.BackendPool Backend pool managing all backends.
---@field _healthChecker load_balancer.HealthChecker Health checker for monitoring backends.
---@field _circuitBreaker load_balancer.CircuitBreaker Circuit breaker for preventing cascading failures.
---@field _strategy load_balancer.LoadBalanceStrategy Primary load balancing strategy.
---@field _fallbackStrategy load_balancer.LoadBalanceStrategy Fallback strategy when primary fails.
---@field _events load_balancer.EventEmitter Event emitter for load balancer events.
---@field _logger load_balancer.Logger Logger instance for load balancer logs.
---@field _metrics load_balancer.MetricsCollector Metrics collector for load balancer metrics.
---@field _totalRequests number Total requests handled.
---@field _failedRequests number Total failed requests.
local LoadBalancer = {}
LoadBalancer.__index = LoadBalancer

--- Configuration table for LoadBalancer.<br>
--- Contains load balancer initialization parameters.
---@class load_balancer.LoadBalancerConfig
---@field logger? load_balancer.Logger Optional logger instance (default: INFO level).
---@field metrics? load_balancer.MetricsCollector Optional metrics collector.
---@field strategy? load_balancer.LoadBalanceStrategy Primary load balancing strategy (default: RoundRobin).
---@field fallbackStrategy? load_balancer.LoadBalanceStrategy Fallback strategy (default: LeastConnections).
---@field healthCheckInterval? number Health check interval in seconds (default: 10).
---@field unhealthyThreshold? number Consecutive failures to mark unhealthy (default: 3).
---@field healthyThreshold? number Consecutive successes to mark healthy (default: 2).
---@field circuitBreakerThreshold? number Circuit breaker failure threshold (default: 5).
---@field circuitBreakerRecovery? number Circuit breaker recovery timeout in seconds (default: 30).

--- Create a new LoadBalancer instance.<br>
--- Initializes backend pool, health checker, circuit breaker, and load balancing strategies.
---@param config load_balancer.LoadBalancerConfig Configuration table.
---@return load_balancer.LoadBalancer instance New LoadBalancer instance.
function LoadBalancer.new(config)
	config = config or {}
	local self = setmetatable({
		_pool = BackendPool.new(),
		_logger = config.logger or Logger.new("INFO"),
		_metrics = config.metrics or MetricsCollector.new(),
		_events = EventEmitter.new(),
	}, LoadBalancer)

	-- Health checking
	self._healthChecker = HealthChecker.new({
		pool = self._pool,
		logger = self._logger,
		metrics = self._metrics,
		checkInterval = config.healthCheckInterval or 10,
		unhealthyThreshold = config.unhealthyThreshold or 3,
		healthyThreshold = config.healthyThreshold or 2
	})

	-- Circuit breaker
	self._circuitBreaker = CircuitBreaker.new({
		logger = self._logger,
		metrics = self._metrics,
		failureThreshold = config.circuitBreakerThreshold or 5,
		recoveryTimeout = config.circuitBreakerRecovery or 30
	})

	-- Strategy
	self._strategy = config.strategy or RoundRobinStrategy.new()
	self._fallbackStrategy = config.fallbackStrategy or LeastConnectionsStrategy.new()

	-- Connect events
	self._healthChecker:getEvents():on("backendHealthy", function(backend)
		self._events:emit("backendHealthy", backend)
	end)
	self._healthChecker:getEvents():on("backendUnhealthy", function(backend)
		self._events:emit("backendUnhealthy", backend)
	end)
	self._circuitBreaker:getEvents():on("circuitOpened", function(backend)
		self._events:emit("circuitOpened", backend)
	end)
	self._circuitBreaker:getEvents():on("circuitClosed", function(backend)
		self._events:emit("circuitClosed", backend)
	end)

	-- Statistics
	self._totalRequests = 0
	self._failedRequests = 0

	return self
end

--- Get the event emitter for load balancer events.<br>
--- Events: backendHealthy, backendUnhealthy, circuitOpened, circuitClosed.
---@param self load_balancer.LoadBalancer The LoadBalancer instance.
---@return load_balancer.EventEmitter events Event emitter instance.
function LoadBalancer.getEvents(self)
	return self._events
end

--- Get the backend pool.
---@param self load_balancer.LoadBalancer The LoadBalancer instance.
---@return load_balancer.BackendPool pool The backend pool instance.
function LoadBalancer.getPool(self)
	return self._pool
end

--- Get the health checker instance.
---@param self load_balancer.LoadBalancer The LoadBalancer instance.
---@return load_balancer.HealthChecker healthChecker The health checker instance.
function LoadBalancer.getHealthChecker(self)
	return self._healthChecker
end

--- Get the circuit breaker instance.
---@param self load_balancer.LoadBalancer The LoadBalancer instance.
---@return load_balancer.CircuitBreaker circuitBreaker The circuit breaker instance.
function LoadBalancer.getCircuitBreaker(self)
	return self._circuitBreaker
end

--- Set the primary load balancing strategy.
---@param self load_balancer.LoadBalancer The LoadBalancer instance.
---@param strategy load_balancer.LoadBalanceStrategy The new strategy to use.
---@return load_balancer.LoadBalancer instance The LoadBalancer instance for chaining.
function LoadBalancer.setStrategy(self, strategy)
	self._strategy = strategy
	self._logger:info("Strategy changed", { strategy = strategy.name })
	return self
end

--- Set the fallback load balancing strategy.<br>
--- Used when primary strategy fails to select a backend.
---@param self load_balancer.LoadBalancer The LoadBalancer instance.
---@param strategy load_balancer.LoadBalanceStrategy The fallback strategy to use.
---@return load_balancer.LoadBalancer instance The LoadBalancer instance for chaining.
function LoadBalancer.setFallbackStrategy(self, strategy)
	self._fallbackStrategy = strategy
	return self
end

--- Add a backend to the load balancer.
---@param self load_balancer.LoadBalancer The LoadBalancer instance.
---@param config load_balancer.BackendConfig Backend configuration.
---@return load_balancer.Backend backend The created backend instance.
function LoadBalancer.addBackend(self, config)
	local backend = Backend.new(config)
	self._pool:add(backend)
	self._logger:info("Backend added", {
		id = backend.id,
		address = backend:getAddress(),
		weight = backend.weight
	})
	return backend
end

--- Remove a backend from the load balancer.<br>
--- Also resets the circuit breaker for the backend.
---@param self load_balancer.LoadBalancer The LoadBalancer instance.
---@param backendId string The ID of the backend to remove.
---@return boolean success True if removed successfully.
function LoadBalancer.removeBackend(self, backendId)
	local success = self._pool:remove(backendId)
	if success then
		self._circuitBreaker:reset(backendId)
		self._logger:info("Backend removed", { id = backendId })
	end
	return success
end

--- Select a backend for a request.<br>
--- Filters by circuit breaker, applies primary strategy, then fallback strategy.<br>
--- Increments connection count on the selected backend.
---@param self load_balancer.LoadBalancer The LoadBalancer instance.
---@param requestContext? table Optional context about the request (e.g. sessionId, userId).
---@return load_balancer.Backend? backend Selected backend, or nil if none available.
function LoadBalancer.selectBackend(self, requestContext)
	requestContext = requestContext or {}
	local available = self._pool:getAvailable()

	-- Filter by circuit breaker
	local circuitApproved = {}
	for i = 1, #available do
		local backend = available[i]
		if self._circuitBreaker:allowRequest(backend) then
			table.insert(circuitApproved, backend)
		end
	end

	-- Try primary strategy
	local selected = self._strategy:select(circuitApproved, requestContext)

	-- Fallback to secondary strategy
	if not selected then
		selected = self._fallbackStrategy:select(circuitApproved, requestContext)
	end

	-- Last resort: try any healthy backend
	if not selected then
		local healthy = self._pool:getHealthy()
		for i = 1, #healthy do
			local backend = healthy[i]
			if backend:isAvailable() then
				selected = backend
				break
			end
		end
	end

	if selected then
		selected:incrementConnections()
		self._metrics:incrementCounter("lb_requests_total")
		self._metrics:setGauge("lb_active_connections_" .. selected.id,
			selected:getActiveConnections())
	else
		self._metrics:incrementCounter("lb_no_backend_available")
		self._logger:warn("No backend available for request")
	end

	self._totalRequests = self._totalRequests + 1
	return selected
end

--- Release a backend after request completion.<br>
--- Decrements connection count and records response metrics.<br>
--- Updates circuit breaker state based on success/failure.
---@param self load_balancer.LoadBalancer The LoadBalancer instance.
---@param backend load_balancer.Backend The backend to release.
---@param responseTime number Response time in milliseconds.
---@param success boolean Whether the request succeeded.
function LoadBalancer.releaseBackend(self, backend, responseTime, success)
	if not backend then return end

	backend:decrementConnections()
	backend:recordResponse(responseTime or 0, success ~= false)

	if success == false then
		self._failedRequests = self._failedRequests + 1
		self._circuitBreaker:recordFailure(backend)
		self._metrics:incrementCounter("lb_failed_requests")
	else
		self._circuitBreaker:recordSuccess(backend)
	end

	self._metrics:recordHistogram("lb_response_time", responseTime or 0)
	self._metrics:setGauge("lb_active_connections_" .. backend.id, backend:getActiveConnections())
end

--- Handle a request using the load balancer.<br>
--- Selects a backend, processes the request, and releases the backend.<br>
--- Handles errors and records metrics automatically.
---@param self load_balancer.LoadBalancer The LoadBalancer instance.
---@param requestContext? table Optional context about the request.
---@param processFn fun(backend: load_balancer.Backend): any Function to process the request with the selected backend.
---@return any result The result from processFn, or nil if failed.
---@return string? error Error message if request failed.
---@return load_balancer.Backend? backend The backend used for the request (on error).
function LoadBalancer.handleRequest(self, requestContext, processFn)
	local backend = self:selectBackend(requestContext)
	if not backend then
		return nil, "No backend available"
	end

	local startTime = os.clock()
	local success, result = true, nil

	-- Call the processing function with backend info
	local ok, err = pcall(processFn, backend)

	if not ok then
		success = false
		result = err
	elseif result == nil then
		success = false
		result = "Processing failed"
	end

	local responseTime = (os.clock() - startTime) * 1000
	self:releaseBackend(backend, responseTime, success)

	if success then
		return result, backend
	end
	return nil, result, backend
end

--- Tick function for periodic health checks.<br>
--- Should be called periodically to perform health checks.
---@param self load_balancer.LoadBalancer The LoadBalancer instance.
function LoadBalancer.tick(self)
	self._healthChecker:tick()
end

--- Get comprehensive load balancer statistics.<br>
--- Returns request counts, success rate, and pool statistics.
---@param self load_balancer.LoadBalancer The LoadBalancer instance.
---@return table stats Load balancer statistics table.
function LoadBalancer.getStats(self)
	local poolStats = self._pool:getStats()
	return {
		totalRequests = self._totalRequests,
		failedRequests = self._failedRequests,
		successRate = self._totalRequests > 0 and
			(1 - self._failedRequests / self._totalRequests) or 1,
		strategy = self._strategy.name,
		fallbackStrategy = self._fallbackStrategy.name,
		pool = poolStats,
		metrics = {
			responseTime = self._metrics:getHistogramStats("lb_response_time"),
			healthCheckTime = self._metrics:getHistogramStats("health_check_time")
		}
	}
end

-- Export
return {
	Backend = Backend,
	BackendPool = BackendPool,
	HealthChecker = HealthChecker,
	CircuitBreaker = CircuitBreaker,
	LoadBalanceStrategy = LoadBalanceStrategy,
	RoundRobinStrategy = RoundRobinStrategy,
	LeastConnectionsStrategy = LeastConnectionsStrategy,
	WeightedStrategy = WeightedStrategy,
	ConsistentHashStrategy = ConsistentHashStrategy,
	AdaptiveStrategy = AdaptiveStrategy,
	PowerOfTwoStrategy = PowerOfTwoStrategy,
	LoadBalancer = LoadBalancer
}
