-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

--- Load Balancer & Matchmaking library.<br>
--- Useful for load balancing and matchmaking systems.<br>
--- Provides load balancing strategies, health checking, circuit breaking,
--- matchmaking with various strategies, and integrated system factory.
---
--- @usage <br>
--- ```
--- local library = require "load_balancer/index"
--- local system = library.SystemFactory.createIntegratedSystem({
---   backends = {{ id = "server1", address = "192.168.1.1" }},
---   queues = {{ id = "ranked", teamSize = 5, teamCount = 2 }}
--- })
--- ```
local Factory = require "factory"

-- Re-export all modules for easy access
return {
	-- Factory for creating systems
	SystemFactory = Factory.SystemFactory,

	-- Core Utilities
	EventEmitter = Factory.EventEmitter,
	MetricsCollector = Factory.MetricsCollector,
	Logger = Factory.Logger,

	-- Load Balancer Components
	Backend = Factory.Backend,
	RoundRobinStrategy = Factory.RoundRobinStrategy,
	LeastConnectionsStrategy = Factory.LeastConnectionsStrategy,
	WeightedStrategy = Factory.WeightedStrategy,
	ConsistentHashStrategy = Factory.ConsistentHashStrategy,
	AdaptiveStrategy = Factory.AdaptiveStrategy,
	PowerOfTwoStrategy = Factory.PowerOfTwoStrategy,
	LoadBalancer = Factory.LoadBalancer,

	-- Matchmaking Components
	MatchmakingPlayer = Factory.MatchmakingPlayer,
	MatchTicket = Factory.MatchTicket,
	Match = Factory.Match,
	MATCH_STATES = Factory.MATCH_STATES,
	SkillBasedStrategy = Factory.SkillBasedStrategy,
	LatencyAwareStrategy = Factory.LatencyAwareStrategy,
	RoleBasedStrategy = Factory.RoleBasedStrategy,
	CompositeStrategy = Factory.CompositeStrategy,
	Matchmaker = Factory.Matchmaker
}
