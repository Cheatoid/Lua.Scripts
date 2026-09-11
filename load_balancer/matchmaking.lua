-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Import dependencies
local CoreUtilities = require "core"
local EventEmitter = CoreUtilities.EventEmitter
local MetricsCollector = CoreUtilities.MetricsCollector
local Logger = CoreUtilities.Logger

----------------------------------------------------------------------
-- Player Abstraction
----------------------------------------------------------------------

--- Player abstraction for matchmaking.<br>
--- Represents a player with skill, region, role preferences, and latency data.
---@class load_balancer.MatchmakingPlayer
---@field id string Unique player identifier.
---@field name string Player display name.
---@field skill number Player skill rating (default: 1000).
---@field skillUncertainty number Skill uncertainty for TrueSkill-like systems (default: 100).
---@field level number Player level (default: 1).
---@field region string Player's preferred region (default: global).
---@field preferredRoles string[] Roles the player prefers to fill.
---@field requiredRoles string[] Roles the player must fill.
---@field latencies table<string, number> Map of regions to latency in milliseconds.
---@field metadata table Additional player metadata.
---@field _inQueue boolean Whether the player is currently in a queue.
---@field _queueEntryTime number Timestamp when player entered the queue.
---@field _currentMatch? load_balancer.Match The match the player is currently in.
---@field _queueExpansions number Number of queue expansions the player has experienced.
---@field _priority number Player priority for matching (higher = more important).
local MatchmakingPlayer = {}
MatchmakingPlayer.__index = MatchmakingPlayer

--- Configuration table for MatchmakingPlayer.<br>
--- Contains player properties for matchmaking.
---@class load_balancer.MatchmakingPlayerConfig
---@field id? string Optional unique identifier (auto-generated if not provided).
---@field name? string Optional display name (defaults to id).
---@field skill? number Skill rating (default: 1000).
---@field skillUncertainty? number Skill uncertainty for TrueSkill (default: 100).
---@field level? number Player level (default: 1).
---@field region? string Preferred region (default: global).
---@field preferredRoles? string[] Optional preferred roles.
---@field requiredRoles? string[] Optional required roles.
---@field latencies? table<string, number> Optional region latency map.
---@field metadata? table Optional additional metadata.
---@field priority? number Matching priority (default: 0).

--- Create a new MatchmakingPlayer instance.<br>
--- Initializes player with skill, region, role preferences, and latency data.
---@param config load_balancer.MatchmakingPlayerConfig Configuration table.
---@return load_balancer.MatchmakingPlayer instance New MatchmakingPlayer instance.
function MatchmakingPlayer.new(config)
	local self = setmetatable({}, MatchmakingPlayer)
	self.id = config.id or ("player_" .. tostring(math.random(100000)))
	self.name = config.name or self.id
	self.skill = config.skill or 1000
	self.skillUncertainty = config.skillUncertainty or 100 -- For TrueSkill-like systems
	self.level = config.level or 1
	self.region = config.region or "global"
	self.preferredRoles = config.preferredRoles or {}
	self.requiredRoles = config.requiredRoles or {}
	self.latencies = config.latencies or {} -- region -> ms
	self.metadata = config.metadata or {}

	-- Queue state
	self._inQueue = false
	self._queueEntryTime = 0
	self._currentMatch = nil
	self._queueExpansions = 0
	self._priority = config.priority or 0 -- Higher = more important

	return self
end

--- Get the player's unique identifier.
---@param self load_balancer.MatchmakingPlayer The MatchmakingPlayer instance.
---@return string id The player's unique identifier.
function MatchmakingPlayer.getId(self)
	return self.id
end

--- Get the player's skill range with uncertainty.<br>
--- Returns min, max, center, and uncertainty values.
---@param self load_balancer.MatchmakingPlayer The MatchmakingPlayer instance.
---@return table skillRange Skill range information.
function MatchmakingPlayer.getSkillRange(self)
	return {
		min = self.skill - self.skillUncertainty,
		max = self.skill + self.skillUncertainty,
		center = self.skill,
		uncertainty = self.skillUncertainty
	}
end

--- Get the player's latency to a specific region.<br>
--- Falls back to global latency or default 100ms.
---@param self load_balancer.MatchmakingPlayer The MatchmakingPlayer instance.
---@param region string The region to check latency for.
---@return number latency Latency in milliseconds.
function MatchmakingPlayer.getLatency(self, region)
	return self.latencies[region] or self.latencies["global"] or 100
end

--- Get the player's best region based on lowest latency.
---@param self load_balancer.MatchmakingPlayer The MatchmakingPlayer instance.
---@return string region Best region or global if no latency data.
function MatchmakingPlayer.getBestRegion(self)
	local best
	local bestLatency = math.huge
	for region, latency in pairs(self.latencies) do
		if latency < bestLatency then
			bestLatency = latency
			best = region
		end
	end
	return best or "global"
end

--- Check if the player can fill a preferred role.<br>
--- Returns true if no preferred roles or role is in preferred list.
---@param self load_balancer.MatchmakingPlayer The MatchmakingPlayer instance.
---@param role string The role to check.
---@return boolean canFill True if player can fill the role.
function MatchmakingPlayer.canFillRole(self, role)
	if #self.preferredRoles == 0 then return true end
	for i = 1, #self.preferredRoles do
		if self.preferredRoles[i] == role then return true end
	end
	return false
end

--- Check if the player must fill a specific role.<br>
--- Returns true if role is in required roles list.
---@param self load_balancer.MatchmakingPlayer The MatchmakingPlayer instance.
---@param role string The role to check.
---@return boolean mustFill True if player must fill the role.
function MatchmakingPlayer.mustFillRole(self, role)
	if #self.requiredRoles == 0 then return false end
	for i = 1, #self.requiredRoles do
		if self.requiredRoles[i] == role then return true end
	end
	return false
end

--- Mark the player as entering a queue.<br>
--- Records entry time and resets expansion counter.
---@param self load_balancer.MatchmakingPlayer The MatchmakingPlayer instance.
function MatchmakingPlayer.enterQueue(self)
	self._inQueue = true
	self._queueEntryTime = os.time()
	self._queueExpansions = 0
end

--- Mark the player as leaving a queue.<br>
--- Resets queue state and expansion counter.
---@param self load_balancer.MatchmakingPlayer The MatchmakingPlayer instance.
function MatchmakingPlayer.leaveQueue(self)
	self._inQueue = false
	self._queueEntryTime = 0
	self._queueExpansions = 0
end

--- Check if the player is currently in a queue.
---@param self load_balancer.MatchmakingPlayer The MatchmakingPlayer instance.
---@return boolean inQueue True if player is in a queue.
function MatchmakingPlayer.isInQueue(self)
	return self._inQueue
end

--- Get the time the player has been in queue.
---@param self load_balancer.MatchmakingPlayer The MatchmakingPlayer instance.
---@return number seconds Time in queue in seconds (0 if not in queue).
function MatchmakingPlayer.getQueueTime(self)
	if not self._inQueue then return 0 end
	return os.time() - self._queueEntryTime
end

--- Increment the search expansion counter.<br>
--- Called when matchmaking expands search criteria.
---@param self load_balancer.MatchmakingPlayer The MatchmakingPlayer instance.
---@return number expansionLevel The new expansion level.
function MatchmakingPlayer.expandSearch(self)
	self._queueExpansions = self._queueExpansions + 1
	return self._queueExpansions
end

--- Get the current search expansion level.
---@param self load_balancer.MatchmakingPlayer The MatchmakingPlayer instance.
---@return number expansionLevel Current expansion level.
function MatchmakingPlayer.getSearchExpansion(self)
	return self._queueExpansions
end

--- Get comprehensive player statistics.<br>
--- Returns skill, level, region, queue status, and expansion info.
---@param self load_balancer.MatchmakingPlayer The MatchmakingPlayer instance.
---@return table stats Player statistics table.
function MatchmakingPlayer.getStats(self)
	return {
		id = self.id,
		name = self.name,
		skill = self.skill,
		level = self.level,
		region = self.region,
		inQueue = self._inQueue,
		queueTime = self:getQueueTime(),
		searchExpansion = self._queueExpansions,
		bestRegion = self:getBestRegion()
	}
end

----------------------------------------------------------------------
-- Match Ticket
----------------------------------------------------------------------

--- Match ticket for matchmaking requests.<br>
--- Represents a group of players looking for a match.<br>
--- Tracks skill, regions, and expansion state.
---@class load_balancer.MatchTicket
---@field id string Unique ticket identifier.
---@field players load_balancer.MatchmakingPlayer[] Players in the ticket.
---@field teamSize number Desired team size.
---@field requiredTeamSize number Minimum players required for a match.
---@field queueType string Type of queue (e.g. "ranked", "casual").
---@field criteria table Additional matching criteria.
---@field creationTime number Timestamp when ticket was created.
---@field expansionLevel number Current search expansion level.
---@field maxExpansion number Maximum expansion level allowed.
---@field _cancelled boolean Whether the ticket has been cancelled.
---@field _matched boolean Whether the ticket has been matched.
local MatchTicket = {}
MatchTicket.__index = MatchTicket

--- Configuration table for MatchTicket.<br>
--- Contains ticket properties for matchmaking.
---@class load_balancer.MatchTicketConfig
---@field id? string Optional unique identifier (auto-generated if not provided).
---@field players? load_balancer.MatchmakingPlayer[] Players in the ticket.
---@field teamSize? number Desired team size (default: 1).
---@field requiredTeamSize? number Minimum players required (default: teamSize).
---@field queueType? string Queue type (default: "default").
---@field criteria? table Optional additional matching criteria.
---@field maxExpansion? number Maximum expansion level (default: 10).

--- Create a new MatchTicket instance.<br>
--- Represents a group of players looking for a match.
---@param config load_balancer.MatchTicketConfig Configuration table.
---@return load_balancer.MatchTicket instance New MatchTicket instance.
function MatchTicket.new(config)
	local self = setmetatable({}, MatchTicket)
	self.id = config.id or ("ticket_" .. tostring(math.random(100000)))
	self.players = config.players or {}
	self.teamSize = config.teamSize or 1
	self.requiredTeamSize = config.requiredTeamSize or config.teamSize or 1
	self.queueType = config.queueType or "default"
	self.criteria = config.criteria or {}
	self.creationTime = os.time()
	self.expansionLevel = 0
	self.maxExpansion = config.maxExpansion or 10
	self._cancelled = false
	self._matched = false
	return self
end

--- Get the ticket's unique identifier.
---@param self load_balancer.MatchTicket The MatchTicket instance.
---@return string id The ticket's unique identifier.
function MatchTicket.getId(self)
	return self.id
end

--- Get the average skill of the team.
---@param self load_balancer.MatchTicket The MatchTicket instance.
---@return number skill Average skill rating.
function MatchTicket.getTeamSkill(self)
	if #self.players == 0 then return 0 end
	local sum = 0
	for i = 1, #self.players do
		sum = sum + self.players[i].skill
	end
	return sum / #self.players
end

--- Get the team's skill range with uncertainty.<br>
--- Returns min, max, center, and uncertainty values.
---@param self load_balancer.MatchTicket The MatchTicket instance.
---@return table skillRange Skill range information.
function MatchTicket.getTeamSkillRange(self)
	if #self.players == 0 then
		return { min = 0, max = 0, center = 0, uncertainty = 0 }
	end
	local sumSkill = 0
	local sumUncertainty = 0
	for i = 1, #self.players do
		local range = self.players[i]:getSkillRange()
		sumSkill = sumSkill + range.center
		sumUncertainty = sumUncertainty + range.uncertainty
	end
	local avgSkill = sumSkill / #self.players
	local avgUncertainty = sumUncertainty / #self.players
	return {
		min = avgSkill - avgUncertainty,
		max = avgSkill + avgUncertainty,
		center = avgSkill,
		uncertainty = avgUncertainty
	}
end

--- Get all regions represented by players in the ticket.
---@param self load_balancer.MatchTicket The MatchTicket instance.
---@return string[] regions Array of region names.
function MatchTicket.getRegions(self)
	local regions = {}
	for i = 1, #self.players do
		regions[self.players[i].region] = true
	end
	local result = {}
	for r, _ in pairs(regions) do
		table.insert(result, r)
	end
	return result
end

--- Get the number of additional players needed.
---@param self load_balancer.MatchTicket The MatchTicket instance.
---@return number needed Number of players needed to reach requiredTeamSize.
function MatchTicket.needsPlayers(self)
	return #self.players < self.requiredTeamSize
end

--- Get the number of remaining slots in the team.
---@param self load_balancer.MatchTicket The MatchTicket instance.
---@return number slots Remaining slots (never negative).
function MatchTicket.remainingSlots(self)
	return math.max(0, self.requiredTeamSize - #self.players)
end

--- Check if the ticket can expand search criteria.
---@param self load_balancer.MatchTicket The MatchTicket instance.
---@return boolean canExpand True if expansion is still possible.
function MatchTicket.canExpand(self)
	return self.expansionLevel < self.maxExpansion
end

--- Expand the search criteria for this ticket.<br>
--- Increments expansion level and expands all players.
---@param self load_balancer.MatchTicket The MatchTicket instance.
---@return boolean success True if expansion was performed.
function MatchTicket.expand(self)
	if not self:canExpand() then return false end
	self.expansionLevel = self.expansionLevel + 1
	for i = 1, #self.players do
		self.players[i]:expandSearch()
	end
	return true
end

--- Get the time the ticket has been waiting in queue.
---@param self load_balancer.MatchTicket The MatchTicket instance.
---@return number seconds Wait time in seconds.
function MatchTicket.getWaitTime(self)
	return os.time() - self.creationTime
end

--- Cancel the match ticket.<br>
--- Marks ticket as cancelled and removes all players from queue.
---@param self load_balancer.MatchTicket The MatchTicket instance.
function MatchTicket.cancel(self)
	self._cancelled = true
	for i = 1, #self.players do
		self.players[i]:leaveQueue()
	end
end

--- Check if the ticket has been cancelled.
---@param self load_balancer.MatchTicket The MatchTicket instance.
---@return boolean cancelled True if ticket is cancelled.
function MatchTicket.isCancelled(self)
	return self._cancelled
end

--- Mark the ticket as matched.<br>
--- Removes all players from queue state.
---@param self load_balancer.MatchTicket The MatchTicket instance.
function MatchTicket.setMatched(self)
	self._matched = true
	for i = 1, #self.players do
		self.players[i]._inQueue = false
	end
end

--- Check if the ticket has been matched.
---@param self load_balancer.MatchTicket The MatchTicket instance.
---@return boolean matched True if ticket is matched.
function MatchTicket.isMatched(self)
	return self._matched
end

--- Get comprehensive ticket statistics.<br>
--- Returns player count, skill, wait time, and status info.
---@param self load_balancer.MatchTicket The MatchTicket instance.
---@return table stats Ticket statistics table.
function MatchTicket.getStats(self)
	return {
		id = self.id,
		queueType = self.queueType,
		playerCount = #self.players,
		requiredTeamSize = self.requiredTeamSize,
		remainingSlots = self:remainingSlots(),
		teamSkill = self:getTeamSkill(),
		waitTime = self:getWaitTime(),
		expansionLevel = self.expansionLevel,
		cancelled = self._cancelled,
		matched = self._matched
	}
end

----------------------------------------------------------------------
-- Match Abstraction
----------------------------------------------------------------------

--- Match lifecycle states.<br>
--- Used to track the progression of a match from creation to completion.
---@class MATCH_STATES
---@field PENDING string Match is being formed.
---@field READY string Match is ready to start.
---@field ACTIVE string Match is currently in progress.
---@field COMPLETED string Match has finished normally.
---@field CANCELLED string Match was cancelled.
local MATCH_STATES = {
	PENDING = "pending",
	READY = "ready",
	ACTIVE = "active",
	COMPLETED = "completed",
	CANCELLED = "cancelled"
}

--- Match abstraction for a game match.<br>
--- Represents a formed match with teams, region, and lifecycle state.
---@class load_balancer.Match
---@field id string Unique match identifier.
---@field teams load_balancer.MatchmakingPlayer[][] Array of teams (each team is an array of players).
---@field matchType string Type of match (e.g. "ranked", "casual").
---@field region string Match region.
---@field server? table Assigned server information.
---@field creationTime number Timestamp when match was created.
---@field state string Current match state (MATCH_STATES).
---@field metadata table Additional match metadata.
---@field _players table<string, load_balancer.MatchmakingPlayer> Map of player IDs to MatchmakingPlayer instances.
local Match = {}
Match.__index = Match

--- Configuration table for Match.<br>
--- Contains match properties for matchmaking.
---@class load_balancer.MatchConfig
---@field id? string Optional unique identifier (auto-generated if not provided).
---@field teams? load_balancer.MatchmakingPlayer[][] Array of teams (each team is an array of players).
---@field matchType? string Type of match (default: "default").
---@field region? string Match region (default: "global").
---@field server? table Optional assigned server information.
---@field metadata? table Optional additional metadata.

--- Create a new Match instance.<br>
--- Initializes match with teams, region, and metadata.<br>
--- Links all players to the match.
---@param config load_balancer.MatchConfig Configuration table.
---@return load_balancer.Match instance New Match instance.
function Match.new(config)
	config = config or {}
	local self = setmetatable({}, Match)
	self.id = config.id or ("match_" .. tostring(math.random(100000)))
	self.teams = config.teams or {} -- Array of player arrays
	self.matchType = config.matchType or "default"
	self.region = config.region or "global"
	self.server = config.server
	self.creationTime = os.time()
	self.state = MATCH_STATES.PENDING
	self.metadata = config.metadata or {}

	-- Players index for quick lookup
	self._players = {}
	for i = 1, #self.teams do
		local team = self.teams[i]
		for j = 1, #team do
			local player = team[j]
			self._players[player.id] = player
			player._currentMatch = self.id
		end
	end

	return self
end

--- Get the match's unique identifier.
---@param self load_balancer.Match The Match instance.
---@return string id The match's unique identifier.
function Match.getId(self)
	return self.id
end

--- Get the current match state.
---@param self load_balancer.Match The Match instance.
---@return string state Current match state (MATCH_STATES).
function Match.getState(self)
	return self.state
end

--- Get a player by ID.
---@param self load_balancer.Match The Match instance.
---@param playerId string The player ID to retrieve.
---@return load_balancer.MatchmakingPlayer|nil player The player instance, or nil if not found.
function Match.getPlayer(self, playerId)
	return self._players[playerId]
end

--- Get all players in the match.
---@param self load_balancer.Match The Match instance.
---@return load_balancer.MatchmakingPlayer[] players Array of all players in the match.
function Match.getAllPlayers(self)
	local result = {}
	for _, p in pairs(self._players) do
		table.insert(result, p)
	end
	return result
end

--- Get the total number of players in the match.
---@param self load_balancer.Match The Match instance.
---@return number count Total player count.
function Match.getPlayerCount(self)
	local count = 0
	for _ in pairs(self._players) do count = count + 1 end
	return count
end

--- Get the number of teams in the match.
---@param self load_balancer.Match The Match instance.
---@return number count Number of teams.
function Match.getTeamCount(self)
	return #self.teams
end

--- Get the size of each team.<br>
--- Assumes all teams have equal size.
---@param self load_balancer.Match The Match instance.
---@return number size Team size (0 if no teams).
function Match.getTeamSize(self)
	return #self.teams > 0 and #self.teams[1] or 0
end

--- Get the average skill of all players in the match.
---@param self load_balancer.Match The Match instance.
---@return number skill Average skill rating.
function Match.getAverageSkill(self)
	local sum = 0
	local count = 0
	for _, p in pairs(self._players) do
		sum = sum + p.skill
		count = count + 1
	end
	return count > 0 and (sum / count) or 0
end

--- Get the skill balance score between teams (0-1).<br>
--- 1 means perfectly balanced, 0 means highly imbalanced.
---@param self load_balancer.Match The Match instance.
---@return number balance Balance score (0-1).
function Match.getSkillBalance(self)
	if #self.teams < 2 then return 1 end

	local teamSkills = {}
	for i = 1, #self.teams do
		local team = self.teams[i]
		local skill = 0
		for j = 1, #team do
			skill = skill + team[j].skill
		end
		table.insert(teamSkills, skill)
	end

	local maxSkill = math.max(unpack(teamSkills))
	local minSkill = math.min(unpack(teamSkills))

	if maxSkill == 0 then return 1 end
	return 1 - ((maxSkill - minSkill) / maxSkill)
end

--- Transition the match to a new state.<br>
--- Validates that the transition is allowed.
---@param self load_balancer.Match The Match instance.
---@param newState string The new state to transition to.
---@return boolean success True if transition succeeded.
---@return string? error Error message if transition failed.
function Match.transitionTo(self, newState)
	local validTransitions = {
		[MATCH_STATES.PENDING] = { MATCH_STATES.READY, MATCH_STATES.CANCELLED },
		[MATCH_STATES.READY] = { MATCH_STATES.ACTIVE, MATCH_STATES.CANCELLED },
		[MATCH_STATES.ACTIVE] = { MATCH_STATES.COMPLETED },
	}

	local allowed = validTransitions[self.state]
	if not allowed then return false, "No valid transitions from " .. self.state end

	for i = 1, #allowed do
		if allowed[i] == newState then
			self.state = newState
			return true
		end
	end

	return false, "Invalid transition from " .. self.state .. " to " .. newState
end

--- Complete the match with results.<br>
--- Transitions to COMPLETED state and records results and duration.<br>
--- Releases all players from the match.
---@param self load_balancer.Match The Match instance.
---@param results table Match results to record.
---@return boolean success True if completion succeeded.
---@return string? error Error message if completion failed.
function Match.complete(self, results)
	local ok, err = self:transitionTo(MATCH_STATES.COMPLETED)
	if not ok then return false, err end

	self.metadata.results = results
	self.metadata.completionTime = os.time()
	self.metadata.duration = self.metadata.completionTime - self.creationTime

	-- Release players
	for _, p in pairs(self._players) do
		p._currentMatch = nil
	end

	return true
end

--- Cancel the match.<br>
--- Transitions to CANCELLED state and releases all players.
---@param self load_balancer.Match The Match instance.
---@return boolean success True if cancellation succeeded.
---@return string? error Error message if cancellation failed.
function Match.cancel(self)
	local ok, err = self:transitionTo(MATCH_STATES.CANCELLED)
	if not ok then return false, err end

	for _, p in pairs(self._players) do
		p._currentMatch = nil
	end

	return true
end

--- Get comprehensive match statistics.<br>
--- Returns state, team info, skill balance, and wait time.
---@param self load_balancer.Match The Match instance.
---@return table stats Match statistics table.
function Match.getStats(self)
	return {
		id = self.id,
		state = self.state,
		matchType = self.matchType,
		region = self.region,
		teamCount = #self.teams,
		playerCount = self:getPlayerCount(),
		teamSize = self:getTeamSize(),
		averageSkill = self:getAverageSkill(),
		skillBalance = self:getSkillBalance(),
		waitTime = os.time() - self.creationTime
	}
end

----------------------------------------------------------------------
-- Matchmaking Strategies
----------------------------------------------------------------------

--- Base interface for matchmaking strategies.<br>
--- All strategies must implement canMatch, scoreMatch, and selectBest methods.
---@class load_balancer.MatchStrategy
---@field name string Name of the strategy.
local MatchStrategy = {}
MatchStrategy.__index = MatchStrategy

--- Create a new MatchStrategy instance.
---@param name string Name of the strategy.
---@return load_balancer.MatchStrategy instance New strategy instance.
function MatchStrategy.new(name)
	return setmetatable({ name = name }, MatchStrategy)
end

--- Check if a ticket can match with candidates.<br>
--- Must be implemented by subclasses.
---@param self load_balancer.MatchStrategy The strategy instance.
---@param ticket load_balancer.MatchTicket The ticket to match.
---@param candidates load_balancer.MatchmakingPlayer[] Array of candidate players.
---@param context table Matchmaking context (expansion level, etc.).
---@return boolean canMatch True if matching is possible.
function MatchStrategy.canMatch(self, ticket, candidates, context)
	return error("MatchStrategy:canMatch() must be implemented", 2)
end

--- Score the quality of a potential match.<br>
--- Must be implemented by subclasses.
---@param self load_balancer.MatchStrategy The strategy instance.
---@param ticket load_balancer.MatchTicket The ticket being matched.
---@param selectedPlayers load_balancer.MatchmakingPlayer[] Players selected for the match.
---@param context table Matchmaking context.
---@return number score Match quality score (higher is better).
function MatchStrategy.scoreMatch(self, ticket, selectedPlayers, context)
	return error("MatchStrategy:scoreMatch() must be implemented", 2)
end

--- Select the best candidates from a pool.<br>
--- Must be implemented by subclasses.
---@param self load_balancer.MatchStrategy The strategy instance.
---@param candidates load_balancer.MatchmakingPlayer[] Array of candidate players.
---@param context table Matchmaking context.
---@return load_balancer.MatchmakingPlayer[] selected Best candidates for the match.
function MatchStrategy.selectBest(self, candidates, context)
	return error("MatchStrategy:selectBest() must be implemented", 2)
end

--- Skill-based matchmaking strategy.<br>
--- Matches players based on skill rating with configurable tolerance.<br>
--- Tolerance increases with queue expansion level.
---@class load_balancer.SkillBasedStrategy : load_balancer.MatchStrategy
---@field _baseTolerance number Base skill tolerance (default: 100).
---@field _expansionRate number Additional tolerance per expansion (default: 50).
---@field _maxTolerance number Maximum tolerance cap (default: 500).
local SkillBasedStrategy = setmetatable({}, { __index = MatchStrategy })
SkillBasedStrategy.__index = SkillBasedStrategy

--- Configuration table for SkillBasedStrategy.<br>
--- Contains skill-based matchmaking parameters.
---@class load_balancer.SkillBasedStrategyConfig
---@field baseTolerance? number Base skill tolerance (default: 100).
---@field expansionRate? number Additional tolerance per expansion (default: 50).
---@field maxTolerance? number Maximum tolerance cap (default: 500).

--- Create a new SkillBasedStrategy instance.
---@param config load_balancer.SkillBasedStrategyConfig Configuration table.
---@return load_balancer.SkillBasedStrategy instance New SkillBasedStrategy instance.
function SkillBasedStrategy.new(config)
	config = config or {}
	local self = setmetatable(MatchStrategy.new("skill_based"), SkillBasedStrategy)
	self._baseTolerance = config.baseTolerance or 100
	self._expansionRate = config.expansionRate or 50 -- Additional tolerance per expansion
	self._maxTolerance = config.maxTolerance or 500
	return self
end

--- Calculate skill tolerance based on expansion level.
---@param self load_balancer.SkillBasedStrategy The strategy instance.
---@param expansionLevel number Current expansion level.
---@return number tolerance Calculated tolerance value.
function SkillBasedStrategy._getTolerance(self, expansionLevel)
	return math.min(self._maxTolerance,
		self._baseTolerance + (expansionLevel * self._expansionRate))
end

--- Check if ticket can match with candidates based on skill.
---@param self load_balancer.SkillBasedStrategy The strategy instance.
---@param ticket load_balancer.MatchTicket The ticket to match.
---@param candidates load_balancer.MatchmakingPlayer[] Array of candidate players.
---@param context table Matchmaking context with expansion level.
---@return boolean canMatch True if skill difference is within tolerance.
function SkillBasedStrategy.canMatch(self, ticket, candidates, context)
	if #candidates < ticket:remainingSlots() then
		return false, "Not enough candidates"
	end

	local teamSkill = ticket:getTeamSkill()
	local tolerance = self:_getTolerance(ticket.expansionLevel)

	for i = 1, #candidates do
		if math.abs(candidates[i].skill - teamSkill) > tolerance then
			return false, "Skill gap too large: " ..
				math.abs(candidates[i].skill - teamSkill) .. " > " .. tolerance
		end
	end

	return true
end

--- Score the quality of a skill-based match.<br>
--- Higher score for closer skill match and lower expansion level.
---@param self load_balancer.SkillBasedStrategy The strategy instance.
---@param ticket load_balancer.MatchTicket The ticket being matched.
---@param selectedPlayers load_balancer.MatchmakingPlayer[] Players selected for the match.
---@param context table Matchmaking context.
---@return number score Match quality score (0-100).
function SkillBasedStrategy.scoreMatch(self, ticket, selectedPlayers, context)
	local teamSkill = ticket:getTeamSkill()
	local score = 100 -- Base score

	-- Penalize skill difference
	for i = 1, #selectedPlayers do
		local diff = math.abs(selectedPlayers[i].skill - teamSkill)
		score = score - (diff / self._maxTolerance) * 50
	end

	-- Bonus for low expansion
	score = score - (ticket.expansionLevel * 3)

	-- Bonus for priority players
	for i = 1, #selectedPlayers do
		score = score + (selectedPlayers[i]._priority * 2)
	end

	return math.max(0, score)
end

--- Select the best candidates based on skill proximity.<br>
--- Filters by tolerance and selects closest skill matches.
---@param self load_balancer.SkillBasedStrategy The strategy instance.
---@param candidates load_balancer.MatchmakingPlayer[] Array of candidate players.
---@param context table Matchmaking context with ticket.
---@return load_balancer.MatchmakingPlayer[] selected Best candidates for the match.
function SkillBasedStrategy.selectBest(self, candidates, context)
	local ticket = context.ticket
	local teamSkill = ticket:getTeamSkill()
	local tolerance = self:_getTolerance(ticket.expansionLevel)
	local slots = ticket:remainingSlots()

	-- Filter candidates within tolerance
	local valid = {}
	for i = 1, #candidates do
		if math.abs(candidates[i].skill - teamSkill) <= tolerance then
			table.insert(valid, candidates[i])
		end
	end

	if #valid < slots then return {} end

	-- Sort by skill proximity
	table.sort(valid, function(a, b)
		return math.abs(a.skill - teamSkill) < math.abs(b.skill - teamSkill)
	end)

	-- Select top N
	local selected = {}
	for i = 1, slots do
		table.insert(selected, valid[i])
	end

	return selected
end

--- Latency-aware matchmaking strategy.<br>
--- Considers both skill and latency for matching.<br>
--- Prioritizes low-latency matches while maintaining skill balance.
---@class load_balancer.LatencyAwareStrategy : load_balancer.MatchStrategy
---@field _maxLatency number Maximum acceptable latency in ms (default: 150).
---@field _expansionLatency number Additional latency per expansion (default: 25).
---@field _skillWeight number Weight for skill factor (default: 0.4).
---@field _latencyWeight number Weight for latency factor (default: 0.6).
local LatencyAwareStrategy = setmetatable({}, { __index = MatchStrategy })
LatencyAwareStrategy.__index = LatencyAwareStrategy

--- Configuration table for LatencyAwareStrategy.<br>
--- Contains latency-aware matchmaking parameters.
---@class load_balancer.LatencyAwareStrategyConfig
---@field maxLatency? number Maximum latency in ms (default: 150).
---@field expansionLatency? number Additional latency per expansion (default: 25).
---@field skillWeight? number Weight for skill (default: 0.4).
---@field latencyWeight? number Weight for latency (default: 0.6).

--- Create a new LatencyAwareStrategy instance.
---@param config load_balancer.LatencyAwareStrategyConfig Configuration table.
---@return load_balancer.LatencyAwareStrategy instance New LatencyAwareStrategy instance.
function LatencyAwareStrategy.new(config)
	config = config or {}
	local self = setmetatable(MatchStrategy.new("latency_aware"), LatencyAwareStrategy)
	self._maxLatency = config.maxLatency or 150
	self._expansionLatency = config.expansionLatency or 25
	self._skillWeight = config.skillWeight or 0.4
	self._latencyWeight = config.latencyWeight or 0.6
	return self
end

--- Calculate maximum latency based on expansion level.
---@param self load_balancer.LatencyAwareStrategy The strategy instance.
---@param expansionLevel number Current expansion level.
---@return number maxLatency Calculated max latency in ms.
function LatencyAwareStrategy._getMaxLatency(self, expansionLevel)
	return self._maxLatency + (expansionLevel * self._expansionLatency)
end

--- Get the most common region among players.
---@param self load_balancer.LatencyAwareStrategy The strategy instance.
---@param players load_balancer.MatchmakingPlayer[] Array of players.
---@return string region Most common region or global.
function LatencyAwareStrategy._getCommonRegion(self, players)
	local regionCounts = {}
	for i = 1, #players do
		regionCounts[players[i].region] = (regionCounts[players[i].region] or 0) + 1
	end
	local best
	local bestCount = 0
	for region, count in pairs(regionCounts) do
		if count > bestCount then
			bestCount = count
			best = region
		end
	end
	return best or "global"
end

--- Check if ticket can match based on latency and skill.
---@param self load_balancer.LatencyAwareStrategy The strategy instance.
---@param ticket load_balancer.MatchTicket The ticket to match.
---@param candidates load_balancer.MatchmakingPlayer[] Array of candidate players.
---@param context table Matchmaking context.
---@return boolean canMatch True if matching is possible.
function LatencyAwareStrategy.canMatch(self, ticket, candidates, context)
	if #candidates < ticket:remainingSlots() then
		return false, "Not enough candidates"
	end

	local allPlayers = {}
	for i = 1, #ticket.players do table.insert(allPlayers, ticket.players[i]) end
	for i = 1, #candidates do table.insert(allPlayers, candidates[i]) end

	local commonRegion = self:_getCommonRegion(allPlayers)
	local maxLatency = self:_getMaxLatency(ticket.expansionLevel)

	for i = 1, #candidates do
		local latency = candidates[i]:getLatency(commonRegion)
		if latency > maxLatency then
			return false, "Latency too high for " .. candidates[i].id ..
				": " .. latency .. "ms > " .. maxLatency .. "ms"
		end
	end

	return true
end

--- Score the quality of a latency-aware match.<br>
--- Considers both latency and skill balance.
---@param self load_balancer.LatencyAwareStrategy The strategy instance.
---@param ticket load_balancer.MatchTicket The ticket being matched.
---@param selectedPlayers load_balancer.MatchmakingPlayer[] Players selected for the match.
---@param context table Matchmaking context.
---@return number score Match quality score (0-100).
function LatencyAwareStrategy.scoreMatch(self, ticket, selectedPlayers, context)
	local allPlayers = {}
	for i = 1, #ticket.players do table.insert(allPlayers, ticket.players[i]) end
	for i = 1, #selectedPlayers do table.insert(allPlayers, selectedPlayers[i]) end

	local commonRegion = self:_getCommonRegion(allPlayers)
	local teamSkill = ticket:getTeamSkill()
	local score = 100

	-- Latency score
	local totalLatency = 0
	for i = 1, #allPlayers do
		totalLatency = totalLatency + allPlayers[i]:getLatency(commonRegion)
	end
	local avgLatency = totalLatency / #allPlayers
	score = score - (avgLatency / 300) * 40 * self._latencyWeight

	-- Skill balance score
	for i = 1, #selectedPlayers do
		local diff = math.abs(selectedPlayers[i].skill - teamSkill)
		score = score - (diff / 500) * 40 * self._skillWeight
	end

	-- Expansion penalty
	score = score - (ticket.expansionLevel * 3)

	return math.max(0, score)
end

--- Select the best candidates based on latency and skill.<br>
--- Filters by latency and sorts by composite score.
---@param self load_balancer.LatencyAwareStrategy The strategy instance.
---@param candidates load_balancer.MatchmakingPlayer[] Array of candidate players.
---@param context table Matchmaking context with ticket.
---@return load_balancer.MatchmakingPlayer[] selected Best candidates for the match.
function LatencyAwareStrategy.selectBest(self, candidates, context)
	local ticket = context.ticket
	local allPlayers = {}
	for i = 1, #ticket.players do table.insert(allPlayers, ticket.players[i]) end
	for i = 1, #candidates do table.insert(allPlayers, candidates[i]) end

	local commonRegion = self:_getCommonRegion(allPlayers)
	local maxLatency = self:_getMaxLatency(ticket.expansionLevel)
	local slots = ticket:remainingSlots()

	-- Filter by latency
	local valid = {}
	for i = 1, #candidates do
		if candidates[i]:getLatency(commonRegion) <= maxLatency then
			table.insert(valid, candidates[i])
		end
	end

	if #valid < slots then return {} end

	-- Sort by composite score
	local teamSkill = ticket:getTeamSkill()
	table.sort(valid, function(a, b)
		local aScore = (a:getLatency(commonRegion) * self._latencyWeight) +
			(math.abs(a.skill - teamSkill) * self._skillWeight)
		local bScore = (b:getLatency(commonRegion) * self._latencyWeight) +
			(math.abs(b.skill - teamSkill) * self._skillWeight)
		return aScore < bScore
	end)

	local selected = {}
	for i = 1, slots do
		table.insert(selected, valid[i])
	end

	return selected
end

--- Role-based matchmaking strategy.<br>
--- Matches players based on required and preferred roles.<br>
--- Ensures all required roles are filled in the match.
---@class load_balancer.RoleBasedStrategy : load_balancer.MatchStrategy
---@field _requiredRoles string[] Roles that must be filled.
---@field _preferredRoles string[] Preferred roles for matching.
local RoleBasedStrategy = setmetatable({}, { __index = MatchStrategy })
RoleBasedStrategy.__index = RoleBasedStrategy

--- Configuration table for RoleBasedStrategy.<br>
--- Contains role-based matchmaking parameters.
---@class load_balancer.RoleBasedStrategyConfig
---@field requiredRoles? table<string, number> Map of roles to required counts.
---@field skillTolerance? number Skill tolerance for matching (default: 150).

--- Create a new RoleBasedStrategy instance.
---@param config load_balancer.RoleBasedStrategyConfig Configuration table.
---@return load_balancer.RoleBasedStrategy instance New RoleBasedStrategy instance.
function RoleBasedStrategy.new(config)
	config = config or {}
	local self = setmetatable(MatchStrategy.new("role_based"), RoleBasedStrategy)
	self._requiredRoles = config.requiredRoles or {}
	self._skillTolerance = config.skillTolerance or 150
	return self
end

--- Get the missing required roles for a ticket.
---@param self load_balancer.RoleBasedStrategy The strategy instance.
---@param ticket load_balancer.MatchTicket The ticket to check.
---@return string[] missing Array of missing role names.
function RoleBasedStrategy._getMissingRoles(self, ticket)
	local filledRoles = {}
	for i = 1, #ticket.players do
		local p = ticket.players[i]
		for j = 1, #p.preferredRoles do
			filledRoles[p.preferredRoles[j]] = (filledRoles[p.preferredRoles[j]] or 0) + 1
		end
	end

	local missing = {}
	for role, count in pairs(self._requiredRoles) do
		local filled = filledRoles[role] or 0
		for i = 1, (count - filled) do
			table.insert(missing, role)
		end
	end
	return missing
end

--- Check if ticket can match based on role requirements.
---@param self load_balancer.RoleBasedStrategy The strategy instance.
---@param ticket load_balancer.MatchTicket The ticket to match.
---@param candidates load_balancer.MatchmakingPlayer[] Array of candidate players.
---@param context table Matchmaking context.
---@return boolean canMatch True if all required roles can be filled.
---@return string? errorMessage
function RoleBasedStrategy.canMatch(self, ticket, candidates, context)
	if #candidates < ticket:remainingSlots() then
		return false, "Not enough candidates"
	end

	local missingRoles = self:_getMissingRoles(ticket)

	-- Check if candidates can fill required roles
	local candidateRoles = {}
	for i = 1, #candidates do
		local c = candidates[i]
		for j = 1, #c.preferredRoles do
			candidateRoles[c.preferredRoles[j]] = (candidateRoles[c.preferredRoles[j]] or 0) + 1
		end
	end

	for i = 1, #missingRoles do
		local role = missingRoles[i]
		if not candidateRoles[role] or candidateRoles[role] <= 0 then
			return false, "Missing required role: " .. role
		end
		candidateRoles[role] = candidateRoles[role] - 1
	end

	return true
end

--- Score the quality of a role-based match.<br>
--- Bonus for filling required roles, penalty for skill imbalance.
---@param self load_balancer.RoleBasedStrategy The strategy instance.
---@param ticket load_balancer.MatchTicket The ticket being matched.
---@param selectedPlayers load_balancer.MatchmakingPlayer[] Players selected for the match.
---@param context table Matchmaking context.
---@return number score Match quality score (0-100).
function RoleBasedStrategy.scoreMatch(self, ticket, selectedPlayers, context)
	local score = 100
	local missingRoles = self:_getMissingRoles(ticket)

	-- Bonus for filling required roles
	local filledRoles = {}
	for i = 1, #selectedPlayers do
		local p = selectedPlayers[i]
		for j = 1, #p.preferredRoles do
			if filledRoles[p.preferredRoles[j]] == nil then filledRoles[p.preferredRoles[j]] = 0 end
			filledRoles[p.preferredRoles[j]] = filledRoles[p.preferredRoles[j]] + 1
		end
	end

	for i = 1, #missingRoles do
		local role = missingRoles[i]
		if filledRoles[role] and filledRoles[role] > 0 then
			score = score + 20
			filledRoles[role] = filledRoles[role] - 1
		else
			score = score - 30
		end
	end

	-- Skill balance
	local teamSkill = ticket:getTeamSkill()
	for i = 1, #selectedPlayers do
		local diff = math.abs(selectedPlayers[i].skill - teamSkill)
		score = score - (diff / self._skillTolerance) * 20
	end

	return math.max(0, score)
end

--- Select the best candidates based on role requirements.<br>
--- Prioritizes filling required roles first.
---@param self load_balancer.RoleBasedStrategy The strategy instance.
---@param candidates load_balancer.MatchmakingPlayer[] Array of candidate players.
---@param context table Matchmaking context with ticket.
---@return load_balancer.MatchmakingPlayer[] selected Best candidates for the match.
function RoleBasedStrategy.selectBest(self, candidates, context)
	local ticket = context.ticket
	local slots = ticket:remainingSlots()
	local missingRoles = self:_getMissingRoles(ticket)

	if #candidates < slots then return {} end

	local selected = {}
	local usedIndices = {}

	-- First fill required roles
	for i = 1, #missingRoles do
		local role = missingRoles[i]
		for j = 1, #candidates do
			if not usedIndices[j] and candidates[j]:canFillRole(role) then
				table.insert(selected, candidates[j])
				usedIndices[j] = true
				break
			end
		end
	end

	-- Fill remaining slots with best available
	local remaining = slots - #selected
	if remaining > 0 then
		local teamSkill = ticket:getTeamSkill()
		local available = {}
		for i = 1, #candidates do
			if not usedIndices[i] then
				table.insert(available, { index = i, player = candidates[i] })
			end
		end

		table.sort(available, function(a, b)
			return math.abs(a.player.skill - teamSkill) <
				math.abs(b.player.skill - teamSkill)
		end)

		for i = 1, remaining do
			if available[i] then
				table.insert(selected, available[i].player)
			end
		end
	end

	if #selected < slots then return {} end
	return selected
end

-- Composite Strategy (combines multiple strategies)
--- Composite matchmaking strategy combining multiple strategies.<br>
--- All strategies must agree for a match to be valid.<br>
--- Scores are weighted average of all strategy scores.
---@class load_balancer.CompositeStrategy : load_balancer.MatchStrategy
---@field _strategies load_balancer.MatchStrategy[] Array of strategies to combine.
---@field _weights number[] Weights for each strategy.
---@field _minimumScore number Minimum score threshold (default: 30).
local CompositeStrategy = setmetatable({}, { __index = MatchStrategy })
CompositeStrategy.__index = CompositeStrategy

--- Configuration table for CompositeStrategy.<br>
--- Contains composite matchmaking parameters.
---@class load_balancer.CompositeStrategyConfig
---@field strategies? load_balancer.MatchStrategy[] Array of strategies to combine.
---@field weights? number[] Weights for each strategy.
---@field minimumScore? number Minimum score threshold (default: 30).

--- Create a new CompositeStrategy instance.<br>
--- Combines multiple strategies with weighted scoring.
---@param config load_balancer.CompositeStrategyConfig Configuration table.
---@return load_balancer.CompositeStrategy instance New CompositeStrategy instance.
function CompositeStrategy.new(config)
	config = config or {}
	local self = setmetatable(MatchStrategy.new("composite"), CompositeStrategy)
	self._strategies = config.strategies or {}
	self._weights = config.weights or {}
	self._minimumScore = config.minimumScore or 30
	return self
end

--- Add a strategy to the composite.
---@param self load_balancer.CompositeStrategy The strategy instance.
---@param strategy load_balancer.MatchStrategy Strategy to add.
---@param weight number Weight for the strategy (default: 1).
---@return load_balancer.CompositeStrategy instance The strategy instance for chaining.
function CompositeStrategy.addStrategy(self, strategy, weight)
	table.insert(self._strategies, strategy)
	table.insert(self._weights, weight or 1)
	return self
end

--- Check if ticket can match based on all strategies.<br>
--- All strategies must agree for a valid match.
---@param self load_balancer.CompositeStrategy The strategy instance.
---@param ticket load_balancer.MatchTicket The ticket to match.
---@param candidates load_balancer.MatchmakingPlayer[] Array of candidate players.
---@param context table Matchmaking context.
---@return boolean canMatch True if all strategies agree.
---@return string? reason Reason why matching failed.
function CompositeStrategy.canMatch(self, ticket, candidates, context)
	-- All strategies must agree
	for i = 1, #self._strategies do
		local canMatch, reason = self._strategies[i]:canMatch(ticket, candidates, context)
		if not canMatch then
			return false, self._strategies[i].name .. ": " .. reason
		end
	end
	return true
end

--- Score the match using weighted average of all strategies.
---@param self load_balancer.CompositeStrategy The strategy instance.
---@param ticket load_balancer.MatchTicket The ticket being matched.
---@param selectedPlayers load_balancer.MatchmakingPlayer[] Players selected for the match.
---@param context table Matchmaking context.
---@return number score Weighted average score (0-100).
function CompositeStrategy.scoreMatch(self, ticket, selectedPlayers, context)
	local totalScore = 0
	local totalWeight = 0

	for i = 1, #self._strategies do
		local weight = self._weights[i] or 1
		local score = self._strategies[i]:scoreMatch(ticket, selectedPlayers, context)
		totalScore = totalScore + (score * weight)
		totalWeight = totalWeight + weight
	end

	return totalWeight > 0 and (totalScore / totalWeight) or 0
end

--- Select the best candidates using the first strategy.<br>
--- Validates selection with all other strategies.
---@param self load_balancer.CompositeStrategy The strategy instance.
---@param candidates load_balancer.MatchmakingPlayer[] Array of candidate players.
---@param context table Matchmaking context.
---@return load_balancer.MatchmakingPlayer[] selected Best candidates for the match.
function CompositeStrategy.selectBest(self, candidates, context)
	-- Use first strategy's selection as base, then validate with others
	if #self._strategies == 0 then return {} end

	local selected = self._strategies[1]:selectBest(candidates, context)
	if #selected == 0 then return {} end

	-- Validate with other strategies
	for i = 2, #self._strategies do
		local canMatch, _ = self._strategies[i]:canMatch(context.ticket, selected, context)
		if not canMatch then
			-- Try to find alternatives (simplified: just return empty)
			return {}
		end
	end

	return selected
end

----------------------------------------------------------------------
-- Match Queue
----------------------------------------------------------------------

--- Match queue for managing matchmaking tickets.<br>
--- Handles ticket enqueueing, dequeueing, and matching with configurable strategy.
---@class load_balancer.MatchQueue
---@field id string Unique queue identifier.
---@field name string Queue display name.
---@field queueType string Type of queue (e.g. "ranked", "casual").
---@field teamSize number Players per team.
---@field teamCount number Number of teams per match.
---@field strategy load_balancer.MatchStrategy Matchmaking strategy to use.
---@field minPlayersToStart number Minimum players required to start matching.
---@field maxWaitTime number Maximum wait time before forced match (default: 300s).
---@field expansionInterval number Seconds between queue expansions (default: 10s).
---@field minMatchScore number Minimum match quality score (default: 25).
---@field _tickets table<string, load_balancer.MatchTicket> Map of ticket IDs to tickets.
---@field _events load_balancer.EventEmitter Event emitter for queue events.
---@field _logger load_balancer.Logger Logger instance for queue logs.
---@field _metrics load_balancer.MetricsCollector Metrics collector for queue metrics.
local MatchQueue = {}
MatchQueue.__index = MatchQueue

--- Configuration table for MatchQueue.<br>
--- Contains queue properties for matchmaking.
---@class load_balancer.MatchQueueConfig
---@field id? string Optional unique identifier (auto-generated if not provided).
---@field name? string Optional display name (defaults to id).
---@field queueType? string Queue type (default: "default").
---@field teamSize? number Players per team (default: 5).
---@field teamCount? number Number of teams per match (default: 2).
---@field strategy? load_balancer.MatchStrategy Matchmaking strategy (default: SkillBased).
---@field minPlayersToStart? number Minimum players to start matching (default: teamSize * teamCount).
---@field maxWaitTime? number Maximum wait time in seconds (default: 300).
---@field expansionInterval? number Seconds between expansions (default: 10).
---@field minMatchScore? number Minimum match quality score (default: 25).
---@field logger? load_balancer.Logger Optional logger instance.
---@field metrics? load_balancer.MetricsCollector Optional metrics collector.

--- Create a new MatchQueue instance.<br>
--- Initializes queue with configuration for matchmaking.
---@param config load_balancer.MatchQueueConfig Configuration table.
---@return load_balancer.MatchQueue instance New MatchQueue instance.
function MatchQueue.new(config)
	config = config or {}
	local self = setmetatable({}, MatchQueue)
	self.id = config.id or ("queue_" .. tostring(math.random(100000)))
	self.name = config.name or self.id
	self.queueType = config.queueType or "default"
	self.teamSize = config.teamSize or 5
	self.teamCount = config.teamCount or 2
	self.strategy = config.strategy or SkillBasedStrategy.new()
	self.minPlayersToStart = config.minPlayersToStart or (self.teamSize * self.teamCount)
	self.maxWaitTime = config.maxWaitTime or 300         -- seconds
	self.expansionInterval = config.expansionInterval or 10 -- seconds
	self.minMatchScore = config.minMatchScore or 25

	self._tickets = {}
	self._events = EventEmitter.new()
	self._logger = config.logger or Logger.new("INFO")
	self._metrics = config.metrics or MetricsCollector.new()

	return self
end

--- Get the event emitter for queue events.<br>
--- Events: ticketEnqueued, ticketDequeued, matchFound.
---@param self load_balancer.MatchQueue The MatchQueue instance.
---@return load_balancer.EventEmitter events Event emitter instance.
function MatchQueue.getEvents(self)
	return self._events
end

--- Get the queue's unique identifier.
---@param self load_balancer.MatchQueue The MatchQueue instance.
---@return string id The queue's unique identifier.
function MatchQueue.getId(self)
	return self.id
end

--- Get the number of tickets in the queue.
---@param self load_balancer.MatchQueue The MatchQueue instance.
---@return number count Number of tickets in the queue.
function MatchQueue.size(self)
	local count = 0
	for _ in pairs(self._tickets) do count = count + 1 end
	return count
end

--- Get the total number of players in the queue.
---@param self load_balancer.MatchQueue The MatchQueue instance.
---@return number count Total player count.
function MatchQueue.getPlayerCount(self)
	local count = 0
	for _, ticket in pairs(self._tickets) do
		count = count + #ticket.players
	end
	return count
end

--- Add a ticket to the queue.<br>
--- Validates queue type and marks players as in queue.
---@param self load_balancer.MatchQueue The MatchQueue instance.
---@param ticket load_balancer.MatchTicket The ticket to enqueue.
---@return boolean success True if enqueued successfully.
---@return string? error Error message if enqueue failed.
function MatchQueue.enqueue(self, ticket)
	if ticket.queueType ~= self.queueType then
		return false, "Wrong queue type"
	end

	for i = 1, #ticket.players do
		ticket.players[i]:enterQueue()
	end

	self._tickets[ticket.id] = ticket
	self._events:emit("ticketEnqueued", ticket)
	self._logger:debug("Ticket enqueued", {
		ticket = ticket.id,
		players = #ticket.players
	})

	return true
end

--- Remove a ticket from the queue.<br>
--- Cancels the ticket and removes it from the queue.
---@param self load_balancer.MatchQueue The MatchQueue instance.
---@param ticketId string The ID of the ticket to remove.
---@return boolean success True if dequeued successfully.
---@return string? error Error message if dequeue failed.
function MatchQueue.dequeue(self, ticketId)
	local ticket = self._tickets[ticketId]
	if not ticket then
		return false, "Ticket not found"
	end

	ticket:cancel()
	self._tickets[ticketId] = nil
	self._events:emit("ticketDequeued", ticket)

	return true
end

--- Get all tickets in the queue.
---@param self load_balancer.MatchQueue The MatchQueue instance.
---@return load_balancer.MatchTicket[] tickets Array of all tickets in the queue.
function MatchQueue.getTickets(self)
	local result = {}
	for _, ticket in pairs(self._tickets) do
		if not ticket:isCancelled() and not ticket:isMatched() then
			table.insert(result, ticket)
		end
	end

	-- Sort by wait time (longer wait = higher priority)
	table.sort(result, function(a, b)
		return a:getWaitTime() > b:getWaitTime()
	end)

	return result
end

--- Get the pool of available players from all tickets.<br>
--- Excludes players from a specific ticket.
---@param self load_balancer.MatchQueue The MatchQueue instance.
---@param excludeTicket string Ticket ID to exclude from pool.
---@return load_balancer.MatchmakingPlayer[] players Array of available players.
function MatchQueue.getPlayerPool(self, excludeTicket)
	local players = {}
	for _, ticket in pairs(self._tickets) do
		if ticket.id ~= excludeTicket and
			not ticket:isCancelled() and
			not ticket:isMatched() then
			for j = 1, #ticket.players do
				table.insert(players, ticket.players[j])
			end
		end
	end
	return players
end

--- Attempt to find a match for a specific ticket.<br>
--- Uses the queue's strategy to select and validate matches.
---@param self load_balancer.MatchQueue The MatchQueue instance.
---@param ticket load_balancer.MatchTicket The ticket to match.
---@return table? matchData Match data with players and score, or nil if no match.
function MatchQueue._tryMatchTicket(self, ticket)
	if ticket:isCancelled() or ticket:isMatched() then
		return
	end

	local slots = ticket:remainingSlots()
	if slots == 0 then
		-- Ticket is already full, try to match with other full tickets
		return self:_tryMatchFullTickets(ticket)
	end

	-- Get candidate players from other tickets
	local candidates = self:getPlayerPool(ticket.id)
	if #candidates < slots then
		return
	end

	local context = { queue = self, ticket = ticket }

	-- Try to select best players
	local selected = self.strategy:selectBest(candidates, context)
	if #selected < slots then
		return
	end

	-- Validate match
	local canMatch, reason = self.strategy:canMatch(ticket, selected, context)
	if not canMatch then
		return
	end

	-- Score the match
	local score = self.strategy:scoreMatch(ticket, selected, context)
	if score < self.minMatchScore then
		return
	end

	-- Create match
	local allPlayers = {}
	for i = 1, #ticket.players do
		table.insert(allPlayers, ticket.players[i])
	end
	for i = 1, #selected do
		table.insert(allPlayers, selected[i])
	end

	-- Remove selected players from their tickets
	for i = 1, #selected do
		local player = selected[i]
		for tid, t in pairs(self._tickets) do
			if tid ~= ticket.id then
				for j = #t.players, 1, -1 do
					if t.players[j].id == player.id then
						table.remove(t.players, j)
						break
					end
				end
				-- Remove empty tickets
				if #t.players == 0 then
					self._tickets[tid] = nil
				end
			end
		end
	end

	-- Add selected players to ticket
	for i = 1, #selected do
		table.insert(ticket.players, selected[i])
	end

	return {
		players = allPlayers,
		score = score,
		strategy = self.strategy.name
	}
end

--- Attempt to match a full ticket with other full tickets.<br>
--- Creates multi-team matches with skill balance check.
---@param self load_balancer.MatchQueue The MatchQueue instance.
---@param ticket load_balancer.MatchTicket The full ticket to match.
---@return table? matchData Match data with players, teams, and score, or nil if no match.
function MatchQueue._tryMatchFullTickets(self, ticket)
	-- Find other full tickets to create multi-team match
	local fullTickets = {}
	for _, t in pairs(self._tickets) do
		if t.id ~= ticket.id and
			not t:isCancelled() and
			not t:isMatched() and
			#t.players == t.requiredTeamSize then
			table.insert(fullTickets, t)
		end
	end

	local neededTeams = self.teamCount - 1
	if #fullTickets < neededTeams then
		return
	end

	-- Check skill compatibility
	local teams = { ticket.players }
	for i = 1, neededTeams do
		table.insert(teams, fullTickets[i].players)
	end

	-- Simple skill balance check
	local teamSkills = {}
	for i = 1, #teams do
		local team = teams[i]
		local skill = 0
		for j = 1, #team do skill = skill + team[j].skill end
		table.insert(teamSkills, skill)
	end

	local maxSkill = math.max(unpack(teamSkills))
	local minSkill = math.min(unpack(teamSkills))
	local imbalance = (maxSkill - minSkill) / maxSkill

	if imbalance > 0.3 then -- 30% max imbalance
		return
	end

	-- Collect all players and remove tickets
	local allPlayers = {}
	for i = 1, #teams do
		local team = teams[i]
		for j = 1, #team do
			table.insert(allPlayers, team[j])
		end
	end

	-- Remove matched tickets
	for i = 1, neededTeams do
		fullTickets[i]:setMatched()
		self._tickets[fullTickets[i].id] = nil
	end

	ticket:setMatched()
	self._tickets[ticket.id] = nil

	local score = math.max(0, 100 - (imbalance * 200))

	return {
		players = allPlayers,
		teams = teams,
		score = score,
		strategy = "full_ticket_match"
	}
end

--- Find all possible matches in the queue.<br>
--- Iterates through tickets and attempts to find matches.
---@param self load_balancer.MatchQueue The MatchQueue instance.
---@return table[] matches Array of match data tables.
function MatchQueue.findMatches(self)
	local matches = {}
	local processed = {}

	local tickets = self:getTickets()

	for i = 1, #tickets do
		local ticket = tickets[i]
		if not processed[ticket.id] then
			local matchData = self:_tryMatchTicket(ticket)
			if matchData then
				table.insert(matches, matchData)

				-- Mark related tickets as processed
				for j = 1, #matchData.players do
					local p = matchData.players[j]
					for tid, t in pairs(self._tickets) do
						for k = 1, #t.players do
							if t.players[k].id == p.id then
								processed[tid] = true
							end
						end
					end
				end
			end
		end
	end

	return matches
end

--- Expand search criteria for tickets that have waited long enough.<br>
--- Increases expansion level for tickets exceeding expansion interval.
---@param self load_balancer.MatchQueue The MatchQueue instance.
function MatchQueue.expandSearches(self)
	for _, ticket in pairs(self._tickets) do
		if not ticket:isCancelled() and not ticket:isMatched() then
			if ticket:getWaitTime() > (ticket.expansionLevel + 1) * self.expansionInterval then
				if ticket:expand() then
					self._logger:debug("Search expanded", {
						ticket = ticket.id,
						level = ticket.expansionLevel
					})
					self._events:emit("searchExpanded", ticket)
				end
			end
		end
	end
end

--- Remove tickets that have exceeded max wait time.<br>
--- Cancels expired tickets and removes them from the queue.
---@param self load_balancer.MatchQueue The MatchQueue instance.
---@return number expired Number of expired tickets removed.
function MatchQueue.cleanupExpired(self)
	local expired = {}
	for id, ticket in pairs(self._tickets) do
		if ticket:getWaitTime() > self.maxWaitTime then
			table.insert(expired, id)
		end
	end

	for i = 1, #expired do
		self._tickets[expired[i]]:cancel()
		self._tickets[expired[i]] = nil
		self._events:emit("ticketExpired", self._tickets[expired[i]])
		self._logger:info("Ticket expired", { ticket = expired[i] })
		self._metrics:incrementCounter("queue_expired")
	end

	return #expired
end

--- Tick function for queue processing.<br>
--- Expands searches, finds matches, and cleans up expired tickets.
---@param self load_balancer.MatchQueue The MatchQueue instance.
---@return table[] matches Array of matches found during this tick.
function MatchQueue.tick(self)
	self:expandSearches()
	local matches = self:findMatches()
	self:cleanupExpired()
	return matches
end

--- Get comprehensive queue statistics.<br>
--- Returns ticket count, player count, strategy, and team info.
---@param self load_balancer.MatchQueue The MatchQueue instance.
---@return table stats Queue statistics table.
function MatchQueue.getStats(self)
	return {
		id = self.id,
		name = self.name,
		queueType = self.queueType,
		ticketCount = self:size(),
		playerCount = self:getPlayerCount(),
		strategy = self.strategy.name,
		teamSize = self.teamSize,
		teamCount = self.teamCount
	}
end

----------------------------------------------------------------------
-- Main Matchmaker
----------------------------------------------------------------------

--- Main matchmaker class coordinating multiple queues.<br>
--- Manages matchmaking queues, match lifecycle, and server assignment.
---@class load_balancer.Matchmaker
---@field _queues table<string, load_balancer.MatchQueue> Map of queue IDs to queues.
---@field _activeMatches table<string, load_balancer.Match> Map of active match IDs to matches.
---@field _completedMatches table<string, load_balancer.Match> Map of completed match IDs to matches.
---@field _events load_balancer.EventEmitter Event emitter for matchmaker events.
---@field _logger load_balancer.Logger Logger instance for matchmaker logs.
---@field _metrics load_balancer.MetricsCollector Metrics collector for matchmaker metrics.
---@field _matchIdCounter number Counter for generating unique match IDs.
---@field _autoAssignServer boolean Whether to auto-assign servers to matches.
---@field _readyTimeout? number Timeout for match ready state (default: 30s).
local Matchmaker = {}
Matchmaker.__index = Matchmaker

--- Configuration table for Matchmaker.<br>
--- Contains matchmaker initialization parameters.
---@class load_balancer.MatchmakerConfig
---@field logger? load_balancer.Logger Optional logger instance (default: INFO level).
---@field metrics? load_balancer.MetricsCollector Optional metrics collector.
---@field autoAssignServer? boolean Whether to auto-assign servers (default: false).
---@field readyTimeout? number Ready timeout in seconds (default: 30).
---@field matchTimeout? number Match timeout in seconds (default: 3600).

--- Create a new Matchmaker instance.<br>
--- Initializes matchmaker with queues and match management.
---@param config load_balancer.MatchmakerConfig Configuration table.
---@return load_balancer.Matchmaker instance New Matchmaker instance.
function Matchmaker.new(config)
	config = config or {}
	local self = setmetatable({}, Matchmaker)

	self._queues = {}
	self._activeMatches = {}
	self._completedMatches = {}
	self._events = EventEmitter.new()
	self._logger = config.logger or Logger.new("INFO")
	self._metrics = config.metrics or MetricsCollector.new()
	self._matchIdCounter = 0

	-- Configuration
	self._autoAssignServer = config.autoAssignServer or false
	self._readyTimeout = config.readyTimeout or 30
	self._matchTimeout = config.matchTimeout or 3600

	return self
end

--- Get the event emitter for matchmaker events.<br>
--- Events: playerQueued, queueExpired, matchCreated, matchCompleted.
---@param self load_balancer.Matchmaker The Matchmaker instance.
---@return load_balancer.EventEmitter events Event emitter instance.
function Matchmaker.getEvents(self)
	return self._events
end

--- Configuration table for creating a matchmaking queue.<br>
--- Contains queue initialization parameters.
---@class load_balancer.MatchmakerQueueConfig
---@field id string Queue identifier.
---@field name string Queue display name.
---@field queueType string Queue type.
---@field teamSize number Players per team.
---@field teamCount number Number of teams.
---@field strategy load_balancer.MatchStrategy Matchmaking strategy.
---@field minPlayersToStart? number Minimum players to start matching.
---@field maxWaitTime? number Maximum wait time in seconds.
---@field expansionInterval? number Expansion interval in seconds.
---@field minMatchScore? number Minimum match quality score.

--- Create a new matchmaking queue.<br>
--- Registers the queue and forwards its events to the matchmaker.
---@param self load_balancer.Matchmaker The Matchmaker instance.
---@param config load_balancer.MatchmakerQueueConfig Queue configuration.
---@return load_balancer.MatchQueue queue The created queue instance.
function Matchmaker.createQueue(self, config)
	local queue = MatchQueue.new({
		id = config.id,
		name = config.name,
		queueType = config.queueType,
		teamSize = config.teamSize,
		teamCount = config.teamCount,
		strategy = config.strategy,
		minPlayersToStart = config.minPlayersToStart,
		maxWaitTime = config.maxWaitTime,
		expansionInterval = config.expansionInterval,
		minMatchScore = config.minMatchScore,
		logger = self._logger,
		metrics = self._metrics
	})

	self._queues[queue.id] = queue

	-- Forward queue events
	queue:getEvents():on("ticketEnqueued", function(ticket)
		self._events:emit("playerQueued", ticket)
	end)

	queue:getEvents():on("ticketExpired", function(ticket)
		self._events:emit("queueExpired", ticket)
	end)

	self._logger:info("Queue created", {
		id = queue.id,
		name = queue.name,
		type = queue.queueType
	})

	return queue
end

--- Get a queue by ID.
---@param self load_balancer.Matchmaker The Matchmaker instance.
---@param queueId string The queue ID to retrieve.
---@return load_balancer.MatchQueue? queue The queue instance, or nil if not found.
function Matchmaker.getQueue(self, queueId)
	return self._queues[queueId]
end

--- Remove a queue by ID.<br>
--- Cancels all tickets in the queue before removal.
---@param self load_balancer.Matchmaker The Matchmaker instance.
---@param queueId string The ID of the queue to remove.
---@return boolean success True if queue was removed.
function Matchmaker.removeQueue(self, queueId)
	local queue = self._queues[queueId]
	if not queue then return false end

	-- Cancel all tickets
	for id, ticket in pairs(queue._tickets) do
		ticket:cancel()
	end

	self._queues[queueId] = nil
	self._logger:info("Queue removed", { id = queueId })
	return true
end

--- Join a queue as a single player.<br>
--- Creates a ticket and enqueues it in the specified queue.
---@param self load_balancer.Matchmaker The Matchmaker instance.
---@param queueId string The ID of the queue to join.
---@param player load_balancer.MatchmakingPlayer The player joining the queue.
---@return load_balancer.MatchTicket? ticket The created ticket, or nil if failed.
---@return string? error Error message if join failed.
function Matchmaker.joinQueue(self, queueId, player)
	local queue = self._queues[queueId]
	if not queue then
		return nil, "Queue not found"
	end

	local ticket = MatchTicket.new({
		players = { player },
		teamSize = queue.teamSize,
		requiredTeamSize = queue.teamSize,
		queueType = queue.queueType
	})

	local success, err = queue:enqueue(ticket)
	if not success then
		return nil, err
	end

	self._metrics:incrementCounter("mm_joins_total")
	return ticket
end

--- Join a queue as a team.<br>
--- Creates a ticket for multiple players and enqueues it.
---@param self load_balancer.Matchmaker The Matchmaker instance.
---@param queueId string The ID of the queue to join.
---@param players load_balancer.MatchmakingPlayer[] The players joining as a team.
---@return load_balancer.MatchTicket? ticket The created ticket, or nil if failed.
---@return string? error Error message if join failed.
function Matchmaker.joinQueueAsTeam(self, queueId, players)
	local queue = self._queues[queueId]
	if not queue then
		return nil, "Queue not found"
	end

	if #players > queue.teamSize then
		return nil, "Team size exceeds queue team size"
	end

	local ticket = MatchTicket.new({
		players = players,
		teamSize = queue.teamSize,
		requiredTeamSize = queue.teamSize,
		queueType = queue.queueType
	})

	local success, err = queue:enqueue(ticket)
	if not success then
		return nil, err
	end

	self._metrics:incrementCounter("mm_team_joins_total")
	return ticket
end

--- Leave a queue by ticket ID.<br>
--- Searches all queues for the ticket and removes it.
---@param self load_balancer.Matchmaker The Matchmaker instance.
---@param ticketId string The ticket ID to remove.
---@return boolean success True if ticket was removed.
function Matchmaker.leaveQueue(self, ticketId)
	for _, queue in pairs(self._queues) do
		local success = queue:dequeue(ticketId)
		if success then
			self._metrics:incrementCounter("mm_leaves_total")
			return true
		end
	end
	return false
end

--- Create a match from match data.<br>
--- Builds teams, determines region, and initializes the match.
---@param self load_balancer.Matchmaker The Matchmaker instance.
---@param matchData table Match data with players and score.
---@param queue load_balancer.MatchQueue The queue that generated the match.
---@return load_balancer.Match match The created match instance.
function Matchmaker._createMatch(self, matchData, queue)
	self._matchIdCounter = self._matchIdCounter + 1
	local matchId = "match_" .. self._matchIdCounter

	-- Build teams
	local teams = matchData.teams or { {} }
	if not matchData.teams then
		-- Single team for partial matches (will be expanded later)
		teams = { matchData.players }
	end

	-- Determine region
	local regionCounts = {}
	for i = 1, #matchData.players do
		regionCounts[matchData.players[i].region] = (regionCounts[matchData.players[i].region] or 0) + 1
	end
	local bestRegion = "global"
	local bestCount = 0
	for region, count in pairs(regionCounts) do
		if count > bestCount then
			bestCount = count
			bestRegion = region
		end
	end

	local match = Match.new({
		id = matchId,
		teams = teams,
		matchType = queue.queueType,
		region = bestRegion,
		metadata = {
			matchScore = matchData.score,
			matchStrategy = matchData.strategy,
			sourceQueue = queue.id
		}
	})

	-- Transition to ready state
	match:transitionTo(MATCH_STATES.READY)

	self._activeMatches[match.id] = match

	self._events:emit("matchFound", match)
	self._logger:info("Match found", {
		match = match.id,
		players = match:getPlayerCount(),
		teams = #teams,
		score = matchData.score,
		region = bestRegion
	})

	self._metrics:incrementCounter("mm_matches_total")
	self._metrics:recordHistogram("mm_match_score", matchData.score)

	return match
end

--- Tick function for matchmaker processing.<br>
--- Ticks all queues and creates matches from match data.
---@param self load_balancer.Matchmaker The Matchmaker instance.
---@return load_balancer.Match[] matches Array of matches created during this tick.
function Matchmaker.tick(self)
	local allMatches = {}

	for _, queue in pairs(self._queues) do
		local matches = queue:tick()
		for i = 1, #matches do
			local match = self:_createMatch(matches[i], queue)
			table.insert(allMatches, match)
		end
	end

	return allMatches
end

--- Start a match by transitioning it to ACTIVE state.
---@param self load_balancer.Matchmaker The Matchmaker instance.
---@param matchId string The ID of the match to start.
---@return boolean success True if match started successfully.
---@return string? error Error message if start failed.
function Matchmaker.startMatch(self, matchId)
	local match = self._activeMatches[matchId]
	if not match then
		return false, "Match not found"
	end

	local ok, err = match:transitionTo(MATCH_STATES.ACTIVE)
	if not ok then
		return false, err
	end

	self._events:emit("matchStarted", match)
	self._logger:info("Match started", { match = matchId })
	self._metrics:incrementCounter("mm_matches_started")

	return true
end

--- Complete a match with results.<br>
--- Transitions to COMPLETED state and records results.
---@param self load_balancer.Matchmaker The Matchmaker instance.
---@param matchId string The ID of the match to complete.
---@param results table Match results to record.
---@return boolean success True if match completed successfully.
---@return string? error Error message if completion failed.
function Matchmaker.completeMatch(self, matchId, results)
	local match = self._activeMatches[matchId]
	if not match then
		return false, "Match not found"
	end

	local ok, err = match:complete(results)
	if not ok then
		return false, err
	end

	-- Move to completed
	self._completedMatches[match.id] = match
	self._activeMatches[match.id] = nil

	self._events:emit("matchCompleted", match, results)
	self._logger:info("Match completed", {
		match = matchId,
		duration = match.metadata.duration
	})
	self._metrics:incrementCounter("mm_matches_completed")
	self._metrics:recordHistogram("mm_match_duration", match.metadata.duration)

	return true
end

--- Cancel a match.<br>
--- Transitions to CANCELLED state and removes from active matches.
---@param self load_balancer.Matchmaker The Matchmaker instance.
---@param matchId string The ID of the match to cancel.
---@param reason string Reason for cancellation.
---@return boolean success True if match cancelled successfully.
---@return string? error Error message if cancellation failed.
function Matchmaker.cancelMatch(self, matchId, reason)
	local match = self._activeMatches[matchId]
	if not match then
		return false, "Match not found"
	end

	local ok, err = match:cancel()
	if not ok then
		return false, err
	end

	self._activeMatches[match.id] = nil

	self._events:emit("matchCancelled", match, reason)
	self._logger:info("Match cancelled", { match = matchId, reason = reason })
	self._metrics:incrementCounter("mm_matches_cancelled")

	return true
end

--- Get a match by ID (active or completed).
---@param self load_balancer.Matchmaker The Matchmaker instance.
---@param matchId string The ID of the match to retrieve.
---@return load_balancer.Match? match The match instance, or nil if not found.
function Matchmaker.getMatch(self, matchId)
	return self._activeMatches[matchId] or self._completedMatches[matchId]
end

--- Get the active match for a specific player.
---@param self load_balancer.Matchmaker The Matchmaker instance.
---@param playerId string The ID of the player.
---@return load_balancer.Match? match The match the player is in, or nil if not found.
function Matchmaker.getPlayerMatch(self, playerId)
	for _, match in pairs(self._activeMatches) do
		if match:getPlayer(playerId) then
			return match
		end
	end
end

--- Get comprehensive matchmaker statistics.<br>
--- Returns queue stats, active match stats, and completion stats.
---@param self load_balancer.Matchmaker The Matchmaker instance.
---@return table stats Matchmaker statistics table.
function Matchmaker.getStats(self)
	local queueStats = {}
	local totalQueued = 0

	for id, queue in pairs(self._queues) do
		local stats = queue:getStats()
		queueStats[id] = stats
		totalQueued = totalQueued + stats.playerCount
	end

	local activeMatchStats = {}
	for id, match in pairs(self._activeMatches) do
		table.insert(activeMatchStats, match:getStats())
	end

	return {
		queues = queueStats,
		totalQueuedPlayers = totalQueued,
		activeMatches = #activeMatchStats,
		completedMatches = self._metrics:getCounter("mm_matches_completed"),
		metrics = {
			matchScore = self._metrics:getHistogramStats("mm_match_score"),
			matchDuration = self._metrics:getHistogramStats("mm_match_duration")
		}
	}
end

-- Deprecated aliases (naming standard: snake_case). Kept for compatibility.
MatchmakingPlayer.get_id = MatchmakingPlayer.getId
MatchmakingPlayer.get_skill_range = MatchmakingPlayer.getSkillRange
MatchmakingPlayer.get_latency = MatchmakingPlayer.getLatency
MatchmakingPlayer.get_best_region = MatchmakingPlayer.getBestRegion
MatchmakingPlayer.can_fill_role = MatchmakingPlayer.canFillRole
MatchmakingPlayer.must_fill_role = MatchmakingPlayer.mustFillRole
MatchmakingPlayer.enter_queue = MatchmakingPlayer.enterQueue
MatchmakingPlayer.leave_queue = MatchmakingPlayer.leaveQueue
MatchmakingPlayer.is_in_queue = MatchmakingPlayer.isInQueue
MatchmakingPlayer.get_queue_time = MatchmakingPlayer.getQueueTime
MatchmakingPlayer.expand_search = MatchmakingPlayer.expandSearch
MatchmakingPlayer.get_search_expansion = MatchmakingPlayer.getSearchExpansion
MatchmakingPlayer.get_stats = MatchmakingPlayer.getStats
MatchTicket.get_team_skill = MatchTicket.getTeamSkill
MatchTicket.get_team_skill_range = MatchTicket.getTeamSkillRange
MatchTicket.get_regions = MatchTicket.getRegions
MatchTicket.needs_players = MatchTicket.needsPlayers
MatchTicket.remaining_slots = MatchTicket.remainingSlots
MatchTicket.can_expand = MatchTicket.canExpand
MatchTicket.get_wait_time = MatchTicket.getWaitTime
MatchTicket.is_cancelled = MatchTicket.isCancelled
MatchTicket.set_matched = MatchTicket.setMatched
MatchTicket.is_matched = MatchTicket.isMatched
Match.get_state = Match.getState
Match.get_player = Match.getPlayer
Match.get_all_players = Match.getAllPlayers
Match.get_player_count = Match.getPlayerCount
Match.get_team_count = Match.getTeamCount
Match.get_team_size = Match.getTeamSize
Match.get_average_skill = Match.getAverageSkill
Match.get_skill_balance = Match.getSkillBalance
Match.transition_to = Match.transitionTo
MatchStrategy.can_match = MatchStrategy.canMatch
MatchStrategy.score_match = MatchStrategy.scoreMatch
MatchStrategy.select_best = MatchStrategy.selectBest
CompositeStrategy.add_strategy = CompositeStrategy.addStrategy
MatchQueue.get_events = MatchQueue.getEvents
MatchQueue.get_tickets = MatchQueue.getTickets
MatchQueue.get_player_pool = MatchQueue.getPlayerPool
MatchQueue.find_matches = MatchQueue.findMatches
MatchQueue.expand_searches = MatchQueue.expandSearches
MatchQueue.cleanup_expired = MatchQueue.cleanupExpired
Matchmaker.create_queue = Matchmaker.createQueue
Matchmaker.get_queue = Matchmaker.getQueue
Matchmaker.remove_queue = Matchmaker.removeQueue
Matchmaker.join_queue = Matchmaker.joinQueue
Matchmaker.join_queue_as_team = Matchmaker.joinQueueAsTeam
Matchmaker.start_match = Matchmaker.startMatch
Matchmaker.complete_match = Matchmaker.completeMatch
Matchmaker.cancel_match = Matchmaker.cancelMatch
Matchmaker.get_match = Matchmaker.getMatch
Matchmaker.get_player_match = Matchmaker.getPlayerMatch

return {
	MatchmakingPlayer = MatchmakingPlayer,
	MatchTicket = MatchTicket,
	Match = Match,
	MATCH_STATES = MATCH_STATES,
	MatchStrategy = MatchStrategy,
	SkillBasedStrategy = SkillBasedStrategy,
	LatencyAwareStrategy = LatencyAwareStrategy,
	RoleBasedStrategy = RoleBasedStrategy,
	CompositeStrategy = CompositeStrategy,
	MatchQueue = MatchQueue,
	Matchmaker = Matchmaker
}
