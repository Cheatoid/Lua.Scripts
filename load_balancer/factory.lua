-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

----------------------------------------------------------------------
-- INTEGRATION & FACTORY
----------------------------------------------------------------------

--- Factory class for creating integrated load balancer and matchmaking systems.<br>
--- Provides convenience methods for creating loggers, metrics, load balancers,
--- matchmakers, and fully integrated systems with event coordination.
---@class load_balancer.SystemFactory
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

--- Create a new logger instance with print output.
---@param level string Log level (default: "INFO").
---@return load_balancer.Logger logger Configured logger instance.
function SystemFactory.createLogger(level)
	local logger = Logger.new(level or "INFO")
	logger:addOutput(function(msg) print(msg) end)
	return logger
end

--- Create a new metrics collector instance.
---@return load_balancer.MetricsCollector metrics New metrics collector.
function SystemFactory.createMetrics()
	return MetricsCollector.new()
end

--- Configuration table for creating a load balancer.<br>
--- Contains load balancer initialization parameters.
---@class load_balancer.LoadBalancerFactoryConfig
---@field strategy? string Strategy name (round_robin, least_connections, weighted, consistent_hash, power_of_two, adaptive).
---@field consistentHashConfig? table Config for consistent hash strategy.
---@field logger? load_balancer.Logger Optional logger instance.
---@field metrics? load_balancer.MetricsCollector Optional metrics collector.
---@field backends? table[] Optional array of backend configs.
---@field healthCheckInterval? number Health check interval in seconds.
---@field unhealthyThreshold? number Threshold for marking unhealthy.
---@field circuitBreakerThreshold? number Circuit breaker threshold.

--- Create a configured load balancer instance.<br>
--- Selects strategy based on config and adds backends if provided.
---@param config load_balancer.LoadBalancerFactoryConfig Configuration table.
---@return load_balancer.LoadBalancer loadBalancer Configured load balancer instance.
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

--- Configuration table for creating a matchmaker.<br>
--- Contains matchmaker initialization parameters.
---@class load_balancer.MatchmakerFactoryConfig
---@field logger? load_balancer.Logger Optional logger instance.
---@field metrics? load_balancer.MetricsCollector Optional metrics collector.
---@field autoAssignServer? boolean Whether to auto-assign servers.
---@field readyTimeout? number Ready timeout in seconds.
---@field queues? table[] Array of queue configurations.

--- Create a configured matchmaker instance.<br>
--- Creates queues with strategies if provided in config.
---@param config load_balancer.MatchmakerFactoryConfig Configuration table.
---@return load_balancer.Matchmaker matchmaker Configured matchmaker instance.
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

--- Configuration table for creating an integrated system.<br>
--- Contains integrated system initialization parameters.
---@class load_balancer.IntegratedSystemConfig
---@field logger? load_balancer.Logger Optional logger instance.
---@field metrics? load_balancer.MetricsCollector Optional metrics collector.
---@field lbStrategy? string Load balancer strategy name.
---@field backends? table[] Backend configurations.
---@field queues? table[] Queue configurations.

--- Create an integrated load balancer and matchmaking system.<br>
--- Connects matchmaker events to load balancer for server assignment.
---@param config load_balancer.IntegratedSystemConfig Configuration table.
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

-- Deprecated aliases (naming standard: snake_case). Kept for compatibility.
SystemFactory.create_logger = SystemFactory.createLogger
SystemFactory.create_metrics = SystemFactory.createMetrics
SystemFactory.create_load_balancer = SystemFactory.createLoadBalancer
SystemFactory.create_matchmaker = SystemFactory.createMatchmaker
SystemFactory.create_integrated_system = SystemFactory.createIntegratedSystem

return {
	SystemFactory = SystemFactory,

	-- Re-export core utilities
	EventEmitter = CoreUtilities.EventEmitter,
	MetricsCollector = MetricsCollector,
	Logger = Logger,

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
