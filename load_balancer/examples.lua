--- Usage examples for the Load Balancer & Matchmaking library
--- Demonstrates load balancing, matchmaking, and integrated system usage

local LoadBalancerLib = require "index"
local SystemFactory = LoadBalancerLib.SystemFactory
local LoadBalancer = LoadBalancerLib.LoadBalancer
local RoundRobinStrategy = LoadBalancerLib.RoundRobinStrategy
local Matchmaker = LoadBalancerLib.Matchmaker
local MatchmakingPlayer = LoadBalancerLib.MatchmakingPlayer
local SkillBasedStrategy = LoadBalancerLib.SkillBasedStrategy
local LatencyAwareStrategy = LoadBalancerLib.LatencyAwareStrategy
local RoleBasedStrategy = LoadBalancerLib.RoleBasedStrategy
local CompositeStrategy = LoadBalancerLib.CompositeStrategy

--- Example demonstrating load balancer usage.<br>
--- Creates a load balancer with adaptive strategy, simulates requests,
--- switches strategies, and displays statistics.
local function exampleLoadBalancer()
	print("\n" .. string.rep("=", 60))
	print("LOAD BALANCER EXAMPLE")
	print(string.rep("=", 60))

	-- Create load balancer with adaptive strategy
	local lb = SystemFactory.createLoadBalancer({
		strategy = "adaptive",
		backends = {
			{ id = "server_1", host = "10.0.0.1", port = 8080, weight = 3, maxConnections = 100 },
			{ id = "server_2", host = "10.0.0.2", port = 8080, weight = 2, maxConnections = 100 },
			{ id = "server_3", host = "10.0.0.3", port = 8080, weight = 1, maxConnections = 50 },
			{ id = "server_4", host = "10.0.0.4", port = 8080, weight = 2, maxConnections = 100 },
		}
	})

	-- Simulate requests
	print("\n--- Simulating 20 requests ---")
	for i = 1, 20 do
		local result, backend = lb:handleRequest(
			{ userId = "user_" .. i, sessionId = "sess_" .. math.random(1000) },
			function(b)
				-- Simulate processing
				local processingTime = 10 + math.random(90)
				if math.random() < 0.05 then -- 5% failure rate
					return
				end
				return { processed = true, time = processingTime }
			end
		)

		if result then
			print(string.format("Request %d: %s (time: %.1fms)",
				i, backend:getAddress(), result.time))
		else
			print(string.format("Request %d: FAILED on %s", i,
				backend and backend:getAddress() or "none"))
		end
	end

	-- Switch strategy
	print("\n--- Switching to Round Robin ---")
	lb:setStrategy(RoundRobinStrategy.new())

	for i = 21, 25 do
		local result, backend = lb:handleRequest(
			{ userId = "user_" .. i },
			function(b) return { processed = true } end
		)
		if result then
			print(string.format("Request %d: %s", i, backend:getAddress()))
		end
	end

	-- Show stats
	print("\n--- Load Balancer Stats ---")
	local stats = lb:getStats()
	print(string.format("Total Requests: %d", stats.totalRequests))
	print(string.format("Success Rate: %.2f%%", stats.successRate * 100))
	print(string.format("Strategy: %s", stats.strategy))
	print("\nBackend Status:")
	for i = 1, #stats.pool.backends do
		local backend = stats.pool.backends[i]
		print(string.format("  %s: %s, conn=%d/%d, util=%.1f%%, avg=%.1fms",
			backend.id, backend.status,
			backend.activeConnections, backend.maxConnections,
			backend.utilization * 100,
			backend.avgResponseTime))
	end

	if stats.metrics.responseTime then
		local rt = stats.metrics.responseTime
		print(string.format("\nResponse Time: p50=%.1fms, p95=%.1fms, p99=%.1fms",
			rt.p50, rt.p95, rt.p99))
	end
end

--- Example demonstrating matchmaking usage.<br>
--- Creates a matchmaker with skill-based and composite queues,
--- queues players, runs matchmaking ticks, and displays statistics.
local function exampleMatchmaker()
	print("\n" .. string.rep("=", 60))
	print("MATCHMAKING EXAMPLE")
	print(string.rep("=", 60))

	-- Create matchmaker with skill-based queue
	local mm = SystemFactory.createMatchmaker({
		queues = {
			{
				id = "ranked_5v5",
				name = "Ranked 5v5",
				type = "ranked",
				teamSize = 5,
				teamCount = 2,
				strategy = "skill_based",
				skillConfig = { baseTolerance = 100, expansionRate = 50 },
				maxWaitTime = 120,
				expansionInterval = 5
			},
			{
				id = "casual_5v5",
				name = "Casual 5v5",
				type = "casual",
				teamSize = 5,
				teamCount = 2,
				strategy = "composite",
				compositeConfig = {
					strategies = {
						SkillBasedStrategy.new({ baseTolerance = 200, expansionRate = 75 }),
						LatencyAwareStrategy.new({ maxLatency = 200 })
					},
					weights = { 0.6, 0.4 }
				},
				maxWaitTime = 60,
				expansionInterval = 3,
				minMatchScore = 20
			}
		}
	})

	-- Create players with various skill levels
	local function createPlayer(id, skill, region, roles)
		local latencies = {
			us_east = math.random(10, 50),
			us_west = math.random(30, 80),
			eu_west = math.random(80, 150),
			asia = math.random(100, 200)
		}
		-- Add some variance based on region
		if region then
			latencies[region] = math.random(5, 30)
		end

		return MatchmakingPlayer.new({
			id = id,
			name = id,
			skill = skill + math.random(-25, 25),
			region = region or "us_east",
			preferredRoles = roles or {},
			latencies = latencies
		})
	end

	-- Queue players for ranked
	print("\n--- Queueing 12 players for Ranked 5v5 ---")
	local rankedPlayers = {
		createPlayer("p1", 1500, "us_east"),
		createPlayer("p2", 1450, "us_east"),
		createPlayer("p3", 1550, "us_west"),
		createPlayer("p4", 1480, "us_east"),
		createPlayer("p5", 1520, "us_west"),
		createPlayer("p6", 1490, "us_east"),
		createPlayer("p7", 1510, "us_east"),
		createPlayer("p8", 1460, "us_west"),
		createPlayer("p9", 1540, "us_east"),
		createPlayer("p10", 1470, "us_west"),
		createPlayer("p11", 1530, "us_east"),
		createPlayer("p12", 1500, "us_east"),
	}

	local tickets = {}
	for i = 1, #rankedPlayers do
		local player = rankedPlayers[i]
		local ticket = mm:joinQueue("ranked_5v5", player)
		if ticket then
			tickets[player.id] = ticket
			print(string.format("  %s queued (skill: %.0f)", player.id, player.skill))
		end
	end

	-- Run matchmaking ticks
	print("\n--- Running matchmaking ---")
	for tick = 1, 5 do
		print(string.format("\nTick %d:", tick))
		local matches = mm:tick()

		if #matches > 0 then
			for i = 1, #matches do
				local match = matches[i]
				print(string.format("  MATCH FOUND: %s", match.id))
				print(string.format("    Players: %d, Balance: %.2f",
					match:getPlayerCount(), match:getSkillBalance()))
				print(string.format("    Score: %.1f, Region: %s",
					match.metadata.matchScore, match.region))

				-- Start and complete match
				mm:startMatch(match.id)

				-- Simulate match duration
				local duration = 300 + math.random(600)
				mm:completeMatch(match.id, { duration = duration })
			end
		else
			local queue = mm:getQueue("ranked_5v5")
			print(string.format("  No matches (queued: %d players)",
				queue:getPlayerCount()))
		end
	end

	-- Show stats
	print("\n--- Matchmaker Stats ---")
	local stats = mm:getStats()
	for id, queueStats in pairs(stats.queues) do
		print(string.format("Queue '%s': %d players, %d tickets",
			queueStats.name, queueStats.playerCount, queueStats.ticketCount))
	end
	print(string.format("Active Matches: %d", stats.activeMatches))
	print(string.format("Completed Matches: %d", stats.completedMatches))
end

--- Example demonstrating integrated load balancer and matchmaking system.<br>
--- Creates an integrated system with server assignment,
--- queues players, runs system ticks, and displays statistics.
local function exampleIntegrated()
	print("\n" .. string.rep("=", 60))
	print("INTEGRATED SYSTEM EXAMPLE")
	print(string.rep("=", 60))

	-- Create integrated system
	local system = SystemFactory.createIntegratedSystem({
		lbStrategy = "weighted",
		backends = {
			{ id = "game_server_1", host = "192.168.1.10", port = 7777, weight = 3, maxConnections = 50 },
			{ id = "game_server_2", host = "192.168.1.11", port = 7777, weight = 2, maxConnections = 50 },
			{ id = "game_server_3", host = "192.168.1.12", port = 7777, weight = 1, maxConnections = 30 },
		},
		queues = {
			{
				id = "quickplay",
				name = "Quick Play",
				type = "quickplay",
				teamSize = 3,
				teamCount = 2,
				strategy = "skill_based",
				skillConfig = { baseTolerance = 150, expansionRate = 75 },
				maxWaitTime = 60,
				expansionInterval = 5,
				minMatchScore = 20
			}
		}
	})

	-- Create and queue players
	print("\n--- Creating players ---")
	local players = {}
	for i = 1, 6 do
		local skill = 1000 + (i * 100) + math.random(-50, 50)
		players[i] = MatchmakingPlayer.new({
			id = "player_" .. i,
			skill = skill,
			region = i <= 3 and "us_east" or "us_west",
			latencies = { us_east = 20 + math.random(30), us_west = 50 + math.random(40) }
		})
		system.matchmaker:joinQueue("quickplay", players[i])
		print(string.format("  %s: skill=%.0f, region=%s",
			players[i].id, players[i].skill, players[i].region))
	end

	-- Run system tick
	print("\n--- System tick ---")
	local matches = system.tick()

	for i = 1, #matches do
		local match = matches[i]
		print(string.format("Match %s created:", match.id))
		print(string.format("  Server: %s",
			match.server and match.server:getAddress() or "none"))
		print(string.format("  Players: %d, Teams: %d",
			match:getPlayerCount(), match:getTeamCount()))

		-- Complete the match
		system.matchmaker:startMatch(match.id)
		system.matchmaker:completeMatch(match.id, { duration = 180 })
	end

	-- Final stats
	print("\n--- System Stats ---")
	local stats = system.getStats()
	print(string.format("Load Balancer: %d requests, %.1f%% success",
		stats.loadBalancer.totalRequests,
		stats.loadBalancer.successRate * 100))
	print(string.format("Matchmaker: %d matches completed",
		stats.matchmaker.completedMatches))
end

--- Example demonstrating role-based matchmaking.<br>
--- Creates a matchmaker with role requirements, queues players with roles,
--- runs matchmaking, and displays team composition.
local function exampleRoleBasedMatchmaking()
	print("\n" .. string.rep("=", 60))
	print("ROLE-BASED MATCHMAKING EXAMPLE")
	print(string.rep("=", 60))

	local mm = SystemFactory.createMatchmaker({
		queues = {
			{
				id = "role_queue",
				name = "Role Queue",
				type = "role_based",
				teamSize = 5,
				teamCount = 2,
				strategy = "role_based",
				roleConfig = {
					requiredRoles = { tank = 1, healer = 1, dps = 3 }
				},
				skillTolerance = 200,
				maxWaitTime = 90,
				expansionInterval = 5,
				minMatchScore = 25
			}
		}
	})

	-- Create players with roles
	local function createRolePlayer(id, skill, roles)
		return MatchmakingPlayer.new({
			id = id,
			skill = skill,
			region = "us_east",
			preferredRoles = roles,
			latencies = { us_east = 20 }
		})
	end

	print("\n--- Queueing players with roles ---")
	local rolePlayers = {
		createRolePlayer("tank1", 1500, { "tank" }),
		createRolePlayer("tank2", 1450, { "tank" }),
		createRolePlayer("heal1", 1480, { "healer" }),
		createRolePlayer("heal2", 1520, { "healer" }),
		createRolePlayer("dps1", 1490, { "dps" }),
		createRolePlayer("dps2", 1510, { "dps" }),
		createRolePlayer("dps3", 1470, { "dps" }),
		createRolePlayer("dps4", 1530, { "dps", "tank" }), -- Flex player
		createRolePlayer("dps5", 1540, { "dps" }),
		createRolePlayer("dps6", 1460, { "dps", "healer" }), -- Flex player
	}

	for i = 1, #rolePlayers do
		local player = rolePlayers[i]
		mm:joinQueue("role_queue", player)
		print(string.format("  %s: skill=%.0f, roles=[%s]",
			player.id, player.skill, table.concat(player.preferredRoles, ", ")))
	end

	-- Run matchmaking
	print("\n--- Running matchmaking ---")
	for tick = 1, 3 do
		local matches = mm:tick()
		if #matches > 0 then
			for i = 1, #matches do
				local match = matches[i]
				print(string.format("\nMatch %s found (score: %.1f):",
					match.id, match.metadata.matchScore))
				for j = 1, #match.teams do
					local team = match.teams[j]
					print(string.format("  Team %d:", j))
					for k = 1, #team do
						print(string.format("    %s (skill=%.0f, roles=[%s])",
							team[k].id, team[k].skill, table.concat(team[k].preferredRoles, ", ")))
					end
				end
				mm:startMatch(match.id)
				mm:completeMatch(match.id, { duration = 600 })
			end
		else
			print(string.format("  Tick %d: No matches yet", tick))
		end
	end
end

-- Export
return {
	exampleLoadBalancer = exampleLoadBalancer,
	exampleMatchmaker = exampleMatchmaker,
	exampleIntegrated = exampleIntegrated,
	exampleRoleBasedMatchmaking = exampleRoleBasedMatchmaking
}
