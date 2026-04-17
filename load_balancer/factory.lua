-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

----------------------------------------------------------------------
-- INTEGRATION & FACTORY
----------------------------------------------------------------------

--- Factory class for creating integrated load balancer and matchmaking systems.<br>
--- Provides convenience methods for creating loggers, metrics, load balancers,<br>
--- matchmakers, and fully integrated systems with event coordination.
---@class SystemFactory
local SystemFactory = {}

local CoreUtilities = require "core"
local Logger = CoreUtilities.Logger
local MetricsCollector = CoreUtilities.MetricsCollector

local LoadBalancerModule = require "load_balancer"
local Backend = LoadBalancerModule.Backend
local RoundRobinStrategy = LoadBalancerModule.RoundRobinStrategy
local LeastConnectionsStrategy = LoadBalancerModule.LeastConnectionsStrategy
local WeightedStrategy = LoadBalancerModule.WeightedStrategy
local ConsistentHashStrategy = LoadBalancerModule.ConsistentHashStrategy
local AdaptiveStrategy = LoadBalancerModule.AdaptiveStrategy
local PowerOfTwoStrategy = LoadBalancerModule.PowerOfTwoStrategy
local LoadBalancer = LoadBalancerModule.LoadBalancer

local MatchmakingModule = require "matchmaking"
local MatchmakingPlayer = MatchmakingModule.MatchmakingPlayer
local MatchTicket = MatchmakingModule.MatchTicket
local Match = MatchmakingModule.Match
local MATCH_STATES = MatchmakingModule.MATCH_STATES
local SkillBasedStrategy = MatchmakingModule.SkillBasedStrategy
local LatencyAwareStrategy = MatchmakingModule.LatencyAwareStrategy
local RoleBasedStrategy = MatchmakingModule.RoleBasedStrategy
local CompositeStrategy = MatchmakingModule.CompositeStrategy
local Matchmaker = MatchmakingModule.Matchmaker

--- Create a new logger instance with print output.<br>
---@param level string Log level (default: "INFO").
---@return Logger logger Configured logger instance.
function SystemFactory.createLogger(level)
	local logger = Logger.new(level or "INFO")
	logger:addOutput(function(msg) print(msg) end)
	return logger
end

--- Create a new metrics collector instance.<br>
---@return MetricsCollector metrics New metrics collector.
function SystemFactory.createMetrics()
	return MetricsCollector.new()
end

--- Create a configured load balancer instance.<br>
--- Selects strategy based on config and adds backends if provided.<br>
---@param config table Configuration table.
---@param config.strategy string Strategy name (round_robin, least_connections, weighted, consistent_hash, power_of_two, adaptive).
---@param config.consistentHashConfig table Config for consistent hash strategy.
---@param config.logger Logger Optional logger instance.
---@param config.metrics MetricsCollector Optional metrics collector.
---@param config.backends table[] Optional array of backend configs.
---@param config.healthCheckInterval number Health check interval in seconds.
---@param config.unhealthyThreshold number Threshold for marking unhealthy.
---@param config.circuitBreakerThreshold number Circuit breaker threshold.
---@return LoadBalancer loadBalancer Configured load balancer instance.
function SystemFactory.createLoadBalancer(config)
	config = config or {}

	local logger = config.logger or SystemFactory.createLogger()
	local metrics = config.metrics or SystemFactory.createMetrics()

	-- Select strategy
	local strategy
	local strategyName = config.strategy or "adaptive"

	if strategyName == "round_robin" then
		strategy = RoundRobinStrategy.new()
	elseif strategyName == "least_connections" then
		strategy = LeastConnectionsStrategy.new()
	elseif strategyName == "weighted" then
		strategy = WeightedStrategy.new()
	elseif strategyName == "consistent_hash" then
		strategy = ConsistentHashStrategy.new(config.consistentHashConfig)
	elseif strategyName == "power_of_two" then
		strategy = PowerOfTwoStrategy.new()
	else
		strategy = AdaptiveStrategy.new()
	end

	local lb = LoadBalancer.new({
		logger = logger,
		metrics = metrics,
		strategy = strategy,
		fallbackStrategy = LeastConnectionsStrategy.new(),
		healthCheckInterval = config.healthCheckInterval,
		unhealthyThreshold = config.unhealthyThreshold,
		circuitBreakerThreshold = config.circuitBreakerThreshold
	})

	-- Add backends if provided
	if config.backends then
		for i = 1, #config.backends do
			lb:addBackend(config.backends[i])
		end
	end

	return lb
end

--- Create a configured matchmaker instance.<br>
--- Creates queues with strategies if provided in config.<br>
---@param config table Configuration table.
---@param config.logger Logger Optional logger instance.
---@param config.metrics MetricsCollector Optional metrics collector.
---@param config.autoAssignServer boolean Whether to auto-assign servers.
---@param config.readyTimeout number Ready timeout in seconds.
---@param config.queues table[] Array of queue configurations.
---@return Matchmaker matchmaker Configured matchmaker instance.
function SystemFactory.createMatchmaker(config)
	config = config or {}

	local logger = config.logger or SystemFactory.createLogger()
	local metrics = config.metrics or SystemFactory.createMetrics()

	local mm = Matchmaker.new({
		logger = logger,
		metrics = metrics,
		autoAssignServer = config.autoAssignServer,
		readyTimeout = config.readyTimeout
	})

	-- Create queues if provided
	if config.queues then
		for i = 1, #config.queues do
			local queueConfig = config.queues[i]
			local strategy
			local strategyName = queueConfig.strategy or "skill_based"

			if strategyName == "skill_based" then
				strategy = SkillBasedStrategy.new(queueConfig.skillConfig)
			elseif strategyName == "latency_aware" then
				strategy = LatencyAwareStrategy.new(queueConfig.latencyConfig)
			elseif strategyName == "role_based" then
				strategy = RoleBasedStrategy.new(queueConfig.roleConfig)
			elseif strategyName == "composite" then
				strategy = CompositeStrategy.new(queueConfig.compositeConfig)
			else
				strategy = SkillBasedStrategy.new()
			end

			mm:createQueue({
				id = queueConfig.id,
				name = queueConfig.name,
				queueType = queueConfig.type or "default",
				teamSize = queueConfig.teamSize or 5,
				teamCount = queueConfig.teamCount or 2,
				strategy = strategy,
				minMatchScore = queueConfig.minMatchScore,
				maxWaitTime = queueConfig.maxWaitTime,
				expansionInterval = queueConfig.expansionInterval
			})
		end
	end

	return mm
end

--- Create an integrated load balancer and matchmaking system.<br>
--- Connects matchmaker events to load balancer for server assignment.<br>
---@param config table Configuration table.
---@param config.logger Logger Optional logger instance.
---@param config.metrics MetricsCollector Optional metrics collector.
---@param config.lbStrategy string Load balancer strategy name.
---@param config.backends table[] Backend configurations.
---@param config.queues table[] Queue configurations.
---@return table system Integrated system with loadBalancer, matchmaker, logger, metrics, tick, and getStats.
function SystemFactory.createIntegratedSystem(config)
	config = config or {}

	local logger = config.logger or SystemFactory.createLogger()
	local metrics = config.metrics or SystemFactory.createMetrics()

	local lb = SystemFactory.createLoadBalancer({
		logger = logger,
		metrics = metrics,
		strategy = config.lbStrategy,
		backends = config.backends
	})

	local mm = SystemFactory.createMatchmaker({
		logger = logger,
		metrics = metrics,
		queues = config.queues
	})

	-- Connect matchmaker to load balancer
	mm:getEvents():on("matchFound", function(match)
		-- Assign match to a backend server
		local backend = lb:selectBackend({
			matchId = match.id,
			region = match.region,
			players = match:getPlayerCount()
		})

		if backend then
			match.server = backend
			logger:info("Match assigned to server", {
				match = match.id,
				server = backend:getAddress()
			})
		end
	end)

	mm:getEvents():on("matchCompleted", function(match)
		if match.server then
			lb:releaseBackend(match.server,
				match.metadata.duration or 0,
				true)
		end
	end)

	mm:getEvents():on("matchCancelled", function(match)
		if match.server then
			lb:releaseBackend(match.server, 0, false)
		end
	end)

	return {
		loadBalancer = lb,
		matchmaker = mm,
		logger = logger,
		metrics = metrics,
		tick = function()
			lb:tick()
			return mm:tick()
		end,
		getStats = function()
			return {
				loadBalancer = lb:getStats(),
				matchmaker = mm:getStats()
			}
		end
	}
end

return {
	SystemFactory = SystemFactory,

	-- Re-export core utilities
	EventEmitter = CoreUtilities.EventEmitter,
	MetricsCollector = CoreUtilities.MetricsCollector,
	Logger = CoreUtilities.Logger,

	-- Re-export load balancer components
	Backend = Backend,
	RoundRobinStrategy = RoundRobinStrategy,
	LeastConnectionsStrategy = LeastConnectionsStrategy,
	WeightedStrategy = WeightedStrategy,
	ConsistentHashStrategy = ConsistentHashStrategy,
	AdaptiveStrategy = AdaptiveStrategy,
	PowerOfTwoStrategy = PowerOfTwoStrategy,
	LoadBalancer = LoadBalancer,

	-- Re-export matchmaking components
	MatchmakingPlayer = MatchmakingPlayer,
	MatchTicket = MatchTicket,
	Match = Match,
	MATCH_STATES = MATCH_STATES,
	SkillBasedStrategy = SkillBasedStrategy,
	LatencyAwareStrategy = LatencyAwareStrategy,
	RoleBasedStrategy = RoleBasedStrategy,
	CompositeStrategy = CompositeStrategy,
	Matchmaker = Matchmaker
}
