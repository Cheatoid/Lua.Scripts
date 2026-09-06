-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- The A* search core: Pathfinder (configuration + entry points) and Search
-- (all mutable per-search state, the engine loop, and path reconstruction).
--
-- The core knows NOTHING about how the world is represented. The host supplies:
--
--     neighbors_buffer(node, node_buf, cost_buf) -> count   -- hot path, or:
--     neighbors(node, visitor)             visitor(node, cost)
--     cost(from, to) -> number|nil|false   -- fallback when no edge cost given
--     heuristic(node, goal) -> number
--     walkable(node) -> boolean            -- optional
--
-- Node ids may be any valid Lua table key except nil and NaN
-- (numbers, strings, tables by identity, ...).
--
-- Correctness invariants:
--
--   * Termination: edges with cost <= 0 (or non-numeric) are ignored, so the
--     effective graph has strictly positive costs and the search terminates.
--   * Optimality: with a CONSISTENT heuristic, a node's g-score is final the
--     first time it is popped, so closed nodes are never re-opened (default).
--     With an admissible-but-inconsistent heuristic, pass
--     `reopen_closed = true` to preserve optimality.
--   * Stale heap entries (lazy deletion) can never corrupt the search: an
--     entry is only acted on if the node is currently OPEN in THIS search,
--     and the authoritative g/parent values always live in the state tables,
--     never in the heap.
--   * One-shot (`find`) and incremental (`start` + `step`) searches share the
--     exact same engine function and pause only at expansion boundaries, so
--     both produce identical results.
--
-- Performance notes (LuaJIT):
--
--   * State is stored in FLAT tables keyed by node (g, h, parent, stamp).
--     For integer node ids these live in the array part of the tables, which
--     traces extremely well. No per-node objects are ever allocated.
--   * A generation-stamp technique avoids clearing state between searches:
--     stamp[node] encodes both the search generation and the node state, so
--     stale data from previous searches is ignored without table clears.
--   * Neighbor enumeration writes into reusable buffers owned by the search
--     object: zero allocations per expansion, zero closures per node (the
--     callback-mode "visitor" IS the search object via __call).
--   * No pairs()/ipairs(), no table.insert/remove, no recursion, no closure
--     creation in the engine loop.
--
-- Complexity (V = touched nodes, E = scanned edges):
--     Time:   O((V + E) log V) with the binary-heap open set
--     Memory: O(V) for scores/parents + O(open-set size) for the heap
--     Per search: O(1) table allocations (state tables grow lazily and are
--                 reused across searches of the same Search object).

-- Localized global functions for better performance
local math_floor = math.floor
local os_clock = os.clock
local setmetatable = setmetatable
local error = error
local type = type
local tostring = tostring

local OpenSet = require "open_set"

-- Search modes.
local MODE_ASTAR = 0
local MODE_DIJKSTRA = 1
local MODE_GREEDY = 2
local MODE_IDS = { astar = MODE_ASTAR, dijkstra = MODE_DIJKSTRA, greedy = MODE_GREEDY }
local MODE_NAMES = { [MODE_ASTAR] = "astar", [MODE_DIJKSTRA] = "dijkstra", [MODE_GREEDY] = "greedy" }

-- Node-state stamping. stamps[node] encodes BOTH the generation and the state in one value:
--
--     untouched (older generation) : stamp <  gen4
--     open     (this generation)   : stamp == gen4 + 1
--     closed   (this generation)   : stamp == gen4 + 2
--     blocked  (this generation)   : stamp == gen4 + 3
--
-- Generation increments by 1 per search, so gen4 advances by 4 and old
-- stamps (max gen4_old + 3 = gen4 - 1) can never collide with new states.
-- All values stay far below 2^53, where doubles are exact. When the
-- generation limit is reached, the stamp table is replaced once and the
-- counter restarts (practically never happens: 2^50 searches).
local MAX_GENERATION = 1125899906842624 -- 2^50

local STEP_RUN_LIMIT = 2147483647

----------------------------------------------------------------------
-- Search
----------------------------------------------------------------------

--- Search object: mutable per-search state, the engine loop, and path reconstruction.<br>
--- Reuses internal tables across searches via generation stamping; zero allocations per expansion.
---@class astar.Search
---@field pf astar.Pathfinder Bound pathfinder configuration.
---@field open astar.OpenSet Binary-heap open set.
---@field stamps table Generation-stamped node-state table keyed by node.
---@field g table g-scores keyed by node.
---@field h table h-scores keyed by node.
---@field parent table Parent chain keyed by node (for path reconstruction).
---@field nbuf table Reusable neighbor-id buffer.
---@field cbuf table Reusable neighbor-cost buffer.
---@field buf_count integer Number of valid entries in nbuf/cbuf.
---@field generation integer Current generation counter.
---@field gen4 integer generation * 4 (stamp math).
---@field seq integer Monotonically increasing insertion sequence.
---@field status string "idle" | "running" | "success" | "failure" | "canceled"
---@field start any Start node.
---@field goal any Goal node.
---@field found boolean Whether a path was found.
---@field path_cost? number Total cost of the found path.
---@field path_length? integer Length of the found path (number of nodes).
---@field budget_exhausted? string Reason the search stopped: "iterations" | "nodes" | "cost" | "time" | nil
---@field endpoint_blocked? string Which endpoint failed the walkable check: "start" | "goal" | nil
---@field max_iterations? integer Step limit (nil = unlimited).
---@field max_nodes? integer Discovery limit (nil = unlimited).
---@field max_cost? number Cost ceiling (nil = unlimited).
---@field budget_seconds? number Wall-clock time limit in seconds (nil = unlimited).
---@field early_exit boolean When true, stop at first goal discovery (non-optimal).
---@field stats table Statistics: expanded, discovered, pushes, stale_pops, invalid_edges, cost_pruned, max_open, iterations
local Search = {}
Search.__index = Search

--- Callback-mode visitor: the search object doubles as the neighbor sink.<br>
--- Graphs that prefer `neighbors(node, emit)` never force the core to allocate a closure.
---@param self astar.Search The search instance.
---@param nb any Neighbor node identifier.
---@param cost number Edge cost from the current node to `nb`.
function Search.__call(self, nb, cost)
	local n = self.buf_count + 1
	self.buf_count = n
	self.nbuf[n] = nb
	self.cbuf[n] = cost
end

--- Create a new Search object bound to a pathfinder.<br>
--- All internal tables are allocated fresh; reuse via `search:reset()` for repeated searches.
---@param pf astar.Pathfinder The pathfinder configuration.
---@return astar.Search search Fresh search instance.
function Search.new(pf)
	return setmetatable({
		pf = pf,
		open = OpenSet.new(),
		-- node-keyed flat state tables (never cleared; gated by stamps)
		stamps = {},
		g = {},
		h = {},
		parent = {},
		-- reusable neighbor buffers
		nbuf = {},
		cbuf = {},
		buf_count = 0,
		-- generation / sequencing
		generation = 0,
		gen4 = 0,
		seq = 0,
		-- lifecycle
		status = "idle", -- idle | running | success | failure | canceled
		start = nil,
		goal = nil,
		found = false,
		path_cost = nil,
		path_length = nil,
		budget_exhausted = nil,
		endpoint_blocked = nil,
		-- budgets (set by reset options)
		max_iterations = nil,
		max_nodes = nil,
		max_cost = nil,
		budget_seconds = nil,
		early_exit = false,
		-- statistics
		stats = {
			expanded = 0,
			discovered = 0,
			pushes = 0,
			stale_pops = 0,
			invalid_edges = 0,
			cost_pruned = 0,
			max_open = 0,
			iterations = 0,
		},
	}, Search)
end

-- Count the path length by walking parents from `node` back to `start`.
-- IMPORTANT: the walk MUST stop at `start`, not at parent[start] == nil:
-- on a reused Search object the start node may carry a stale parent
-- reference from a previous generation (never read by path reconstruction,
-- which breaks at `start`, but this length counter must respect that too).
local function compute_path_length(parent, start, node)
	local n = 0
	local nd = node
	while nd do
		n = n + 1
		if nd == start then
			break
		end
		nd = parent[nd]
	end
	return n
end

--- Prepare (or re-prepare) this search object for a new search.<br>
--- Reuses all internal tables via generation stamping: no clearing of large state, no reallocation.<br>
--- Returns the search object itself so it can be chained: `search:reset(a, b, opts):run()`.
---@param self astar.Search The search instance.
---@param start any Start node (must not be nil).
---@param goal any Goal node.
---@param opts? table Options:
--- - `max_iterations` (integer): step limit
--- - `max_nodes` (integer): discovery limit
--- - `max_cost` (number): cost ceiling
--- - `budget_seconds` (number): wall-clock limit in seconds
--- - `early_exit` (boolean): stop at first goal discovery (non-optimal)
---@return astar.Search self The search instance (for chaining).
function Search.reset(self, start, goal, opts)
	if start == nil then
		return error("astar: start node must not be nil", 2)
	end
	if goal == nil then
		return error("astar: goal node must not be nil", 2)
	end
	opts = opts or {}

	-- Advance the generation (this invalidates all previous stamps).
	local gen = self.generation + 1
	if gen >= MAX_GENERATION then
		-- Overflow-safe path: replace the stamp table, restart counter.
		self.stamps = {}
		gen = 1
	end
	self.generation = gen
	self.gen4 = gen * 4

	self.start = start
	self.goal = goal
	self.seq = 0
	self.buf_count = 0
	self.found = false
	self.path_cost = nil
	self.path_length = nil
	self.budget_exhausted = nil
	self.endpoint_blocked = nil

	-- Budget options (assign explicitly so stale options never survive).
	self.max_iterations = opts.max_iterations
	self.max_nodes = opts.max_nodes
	self.max_cost = opts.max_cost
	self.budget_seconds = opts.budget_seconds
	self.early_exit = opts.early_exit == true

	-- Zero the stats in place (no reallocation).
	local st = self.stats
	st.expanded = 0
	st.discovered = 0
	st.pushes = 0
	st.stale_pops = 0
	st.invalid_edges = 0
	st.cost_pruned = 0
	st.max_open = 0
	st.iterations = 0

	self.open:reset()

	-- Validate endpoints when the host provides a walkable predicate.
	local walkable = self.pf.walkable
	if walkable then
		if not walkable(start) then
			self.status = "failure"
			self.endpoint_blocked = "start"
			return self
		end
		if not walkable(goal) then
			self.status = "failure"
			self.endpoint_blocked = "goal"
			return self
		end
	end

	-- Trivial case: no search needed.
	if start == goal then
		self.status = "success"
		self.found = true
		self.path_cost = 0
		self.path_length = 1
		return self
	end

	-- Seed the start node.
	local gen4 = self.gen4
	local mode = self.pf.mode
	local h0 = 0
	if mode ~= MODE_DIJKSTRA then
		h0 = self.pf.heuristic(start, goal) or 0
	end
	local f0 = 0
	if mode == MODE_ASTAR or mode == MODE_GREEDY then
		f0 = h0 -- g(start) == 0
	end

	local stamps = self.stamps
	stamps[start] = gen4 + 1
	self.g[start] = 0
	self.h[start] = h0
	self.seq = 1
	self.open:push(start, f0, h0, 1)

	local st2 = self.stats
	st2.discovered = 1
	if self.pf.collect_stats then
		st2.pushes = 1
		st2.max_open = 1
	end

	self.status = "running"
	return self
end

--- Engine core. Performs at most `step_limit` node expansions, then returns (status stays "running" if not finished).<br>
--- All budgets apply. Used by both step() (incremental) and run() (one-shot); pause points are only at expansion boundaries.<br>
--- Incremental semantics are exactly one-shot semantics.
---@param self astar.Search The search instance.
---@param step_limit integer Maximum number of heap pops (expansions) to perform.
---@return integer steps Number of expansions actually performed.
function Search._advance(self, step_limit)
	if self.status ~= "running" then
		return 0
	end

	-- Localize everything the loop touches (LuaJIT-friendly upvalues).
	local pf = self.pf
	local open = self.open
	local stamps = self.stamps
	local g = self.g
	local hc = self.h
	local parent = self.parent
	local gen4 = self.gen4
	local goal = self.goal
	local stats = self.stats
	local collect = pf.collect_stats
	local mode = pf.mode
	local heuristic = pf.heuristic
	local cost_fn = pf.cost
	local walkable = pf.walkable
	local reopen = pf.reopen_closed
	local nbuf = self.nbuf
	local cbuf = self.cbuf
	local neighbors = pf.neighbors
	local neighbors_buffer = pf.neighbors_buffer
	local seq = self.seq
	local max_iterations = self.max_iterations
	local max_nodes = self.max_nodes
	local max_cost = self.max_cost
	local early_exit = self.early_exit

	local deadline
	if self.budget_seconds then
		deadline = os_clock() + self.budget_seconds
	end
	local clock_check = 0

	local steps = 0
	local halt -- "goal" | "nodes" (set inside neighbor scan)

	while true do
		if open.n == 0 then
			-- Open set exhausted: no path exists (within max_cost, if set).
			self.status = "failure"
			if max_cost and stats.cost_pruned > 0 then
				self.budget_exhausted = "cost"
			end
			break
		end
		if steps >= step_limit then
			break -- caller-imposed pause; status stays "running"
		end
		if max_iterations and stats.iterations >= max_iterations then
			self.status = "failure"
			self.budget_exhausted = "iterations"
			break
		end
		-- One engine cycle = one heap pop (valid or stale); count it.
		stats.iterations = stats.iterations + 1

		local node = open:pop()
		local stamp = stamps[node] or 0

		if stamp ~= gen4 + 1 then
			-- Stale heap entry: node closed/blocked this generation, or the
			-- entry belongs to an outdated, higher f (a better entry for the
			-- same node was already processed). Safe to discard.
			if collect then
				stats.stale_pops = stats.stale_pops + 1
			end
		else
			if node == goal then
				-- Optimal termination (consistent h): goal popped with its
				-- final g-score.
				self.found = true
				self.path_cost = g[node]
				self.path_length = compute_path_length(parent, self.start, node)
				self.status = "success"
				break
			end

			-- Expand: enumerate neighbors into reusable buffers
			self.buf_count = 0
			local count
			if neighbors_buffer then
				count = neighbors_buffer(node, nbuf, cbuf)
			else
				neighbors(node, self) -- visitor = the search object (__call)
				count = self.buf_count
			end

			local g_cur = g[node]

			for i = 1, count do
				local nb = nbuf[i]
				local c = cbuf[i]

				-- Cost handling:
				-- fast path : c is a positive number
				-- fallback  : c is nil or 0 (sentinel) -> cost(from, to)
				-- invalid   : number <= 0 or NaN -> edge ignored + counted
				-- absent    : nil/false after fallback -> edge ignored
				-- NOTE: a non-number, non-nil cost (e.g. a table) raises a
				-- comparison error on purpose: fail fast on misconfiguration.
				local valid = c and c > 0
				if not valid then
					if c == nil or c == 0 then
						if cost_fn then
							c = cost_fn(node, nb)
						end
						valid = c and c > 0 or false
					end
					if not valid and type(c) == "number" and collect then
						stats.invalid_edges = stats.invalid_edges + 1
					end
				end

				if valid then
					local code = (stamps[nb] or 0) - gen4

					if code == 1 then
						-- Open this generation: relax if improved.
						local tg = g_cur + c
						if tg < g[nb] then
							g[nb] = tg
							parent[nb] = node
							seq = seq + 1
							local h_nb = hc[nb]
							local f
							if mode == MODE_ASTAR then
								f = tg + h_nb
							elseif mode == MODE_GREEDY then
								f = h_nb
							else
								f = tg -- dijkstra
							end
							open:push(nb, f, h_nb, seq)
							if collect then
								stats.pushes = stats.pushes + 1
								if open.n > stats.max_open then stats.max_open = open.n end
							end
						end
					elseif code == 2 then
						-- Closed this generation: only re-openable when the
						-- caller opted into reopen_closed (admissible but
						-- inconsistent heuristics).
						if reopen then
							local tg = g_cur + c
							if tg < g[nb] then
								stamps[nb] = gen4 + 1
								g[nb] = tg
								parent[nb] = node
								seq = seq + 1
								local h_nb = hc[nb]
								local f
								if mode == MODE_ASTAR then
									f = tg + h_nb
								elseif mode == MODE_GREEDY then
									f = h_nb
								else
									f = tg
								end
								open:push(nb, f, h_nb, seq)
								if collect then
									stats.pushes = stats.pushes + 1
									if open.n > stats.max_open then stats.max_open = open.n end
								end
							end
						end
					elseif code ~= 3 then
						-- Untouched this generation: discovery.
						if walkable and not walkable(nb) then
							-- Remember as blocked for THIS search only (the
							-- walkable predicate may change between searches).
							stamps[nb] = gen4 + 3
						else
							local tg = g_cur + c
							if max_cost and tg > max_cost then
								-- Cost-limited search: skip; leave untouched so
								-- a cheaper route can still discover it later.
								stats.cost_pruned = stats.cost_pruned + 1
							else
								if max_nodes and stats.discovered >= max_nodes then
									halt = "nodes"
									break
								end
								stats.discovered = stats.discovered + 1

								local h_nb = 0
								if mode ~= MODE_DIJKSTRA then
									h_nb = heuristic(nb, goal) or 0
								end
								hc[nb] = h_nb
								g[nb] = tg
								parent[nb] = node
								stamps[nb] = gen4 + 1
								seq = seq + 1
								local f
								if mode == MODE_ASTAR then
									f = tg + h_nb
								elseif mode == MODE_GREEDY then
									f = h_nb
								else
									f = tg -- dijkstra
								end
								open:push(nb, f, h_nb, seq)
								if collect then
									stats.pushes = stats.pushes + 1
									if open.n > stats.max_open then stats.max_open = open.n end
								end

								if early_exit and nb == goal then
									-- Non-optimal termination: stop at first
									-- discovery of the goal.
									halt = "goal"
									break
								end
							end
						end
					end
					-- code == 3: blocked this generation -> skip
				end
			end

			if halt == "goal" then
				self.found = true
				self.path_cost = g[goal]
				self.path_length = compute_path_length(parent, self.start, goal)
				self.status = "success"
				break
			elseif halt == "nodes" then
				self.status = "failure"
				self.budget_exhausted = "nodes"
				break
			end

			-- Close the expanded node.
			stamps[node] = gen4 + 2
			stats.expanded = stats.expanded + 1
			steps = steps + 1

			-- Optional, opt-in wall-clock budget, checked every 256
			-- expansions to keep os.clock() out of the hot path.
			if deadline then
				clock_check = clock_check + 1
				if clock_check >= 256 then
					clock_check = 0
					if os_clock() >= deadline then
						self.status = "failure"
						self.budget_exhausted = "time"
						break
					end
				end
			end
		end
	end

	self.seq = seq
	return steps
end

--- Incremental API: perform up to `n` expansions (default 1).<br>
--- Returns the status after stepping ("running" means not finished yet).
---@param self astar.Search The search instance.
---@param n? integer Maximum expansions this step (default: 1).
---@return string status "running" | "success" | "failure" | "canceled".
function Search.step(self, n)
	if n == nil then n = 1 end
	self:_advance(n)
	return self.status
end

--- Run to completion (bounded only by the search's own budgets).<br>
--- Equivalent to `search:step(2^31-1)`.
---@param self astar.Search The search instance.
---@return string status "running" | "success" | "failure" | "canceled".
function Search.run(self)
	self:_advance(STEP_RUN_LIMIT)
	return self.status
end

--- Return true when the search is no longer running.<br>
--- Status is one of "success", "failure", or "canceled".
---@param self astar.Search The search instance.
---@return boolean finished `true` when status is not "running".
function Search.finished(self)
	return self.status ~= "running"
end

Search.done = Search.finished

--- Return true when the search was cancelled via `cancel()`.<br>
--- Does not distinguish between success/failure and canceled.
---@param self astar.Search The search instance.
---@return boolean canceled `true` only when status is "canceled".
function Search.canceled(self)
	return self.status == "canceled"
end

--- Cheap, deterministic cancellation. The object ends in a well-defined<br>
--- state ("canceled"); subsequent step()/run() calls are no-ops.
---@param self astar.Search The search instance.
---@return astar.Search self The search instance (for chaining).
function Search.cancel(self)
	if self.status == "running" then
		self.status = "canceled"
	end
	return self
end

--- Reconstruct the path (start -> ... -> goal), iteratively (no recursion).<br>
--- If `buffer` is given it must be an array (or empty table); it is reused and any stale tail beyond the new path is trimmed, so `#buffer` is always correct afterwards.<br>
--- Returns nil plus an info table when the search has not found a path.
---@param self astar.Search The search instance.
---@param buffer? table Optional output array to reuse (avoids allocation).
---@return table? path Ordered path nodes from start to goal, or nil if not found.
---@return table info Snapshot of result and statistics.
---@usage <br>
--- ```
--- local path, info = pf:find("a", "d")
--- if path then
---   for i, node in next, path do print(i, node) end
---   print("cost:", info.path_cost)
--- end
--- ```
function Search.path(self, buffer)
	if not self.found then
		return nil, self:info()
	end
	local path = buffer or {}
	local old_n = #path

	local parent = self.parent
	local node = self.goal
	local n = 0
	while true do
		n = n + 1
		path[n] = node
		if node == self.start then
			break
		end
		node = parent[node]
		if node == nil then
			return error("astar: parent chain broken (internal invariant violated)", 2)
		end
	end

	-- Reverse in place -> start-first ordering.
	local half = math_floor(n * 0.5)
	for i = 1, half do
		local j = n - i + 1
		path[i], path[j] = path[j], path[i]
	end

	-- Trim stale tail so reused buffers behave like fresh arrays.
	for i = n + 1, old_n do
		path[i] = nil
	end

	self.path_length = n
	return path, self:info()
end

Search.result = Search.path

--- Snapshot of the result and statistics (fresh table each call; safe to keep around).<br>
--- Always O(1) to build.
---@param self astar.Search The search instance.
---@return table info Result and statistics table.
function Search.info(self)
	local st = self.stats
	return {
		found = self.found == true,
		status = self.status,
		canceled = self.status == "canceled",
		budget_exhausted = self.budget_exhausted, -- "iterations"|"nodes"|"cost"|"time"|nil
		endpoint_blocked = self.endpoint_blocked, -- "start"|"goal"|nil
		path_cost = self.path_cost,
		path_length = self.path_length,
		expanded = st.expanded,
		discovered = st.discovered,
		pushes = st.pushes,
		stale_pops = st.stale_pops,
		invalid_edges = st.invalid_edges,
		cost_pruned = st.cost_pruned,
		max_open = st.max_open,
		iterations = st.iterations,
	}
end

--- Release all large internal tables. After free(), reset() may be used again normally.<br>
--- Leaves the search object in the "idle" state.
---@param self astar.Search The search instance.
---@return astar.Search self The search instance.
function Search.free(self)
	self.open:free()
	self.stamps = {}
	self.g = {}
	self.h = {}
	self.parent = {}
	self.nbuf = {}
	self.cbuf = {}
	self.buf_count = 0
	self.generation = 0
	self.gen4 = 0
	self.seq = 0
	self.status = "idle"
	self.start = nil
	self.goal = nil
	self.found = false
	self.path_cost = nil
	self.path_length = nil
	self.budget_exhausted = nil
	self.endpoint_blocked = nil
	local st = self.stats
	st.expanded = 0
	st.discovered = 0
	st.pushes = 0
	st.stale_pops = 0
	st.invalid_edges = 0
	st.cost_pruned = 0
	st.max_open = 0
	st.iterations = 0
	return self
end

----------------------------------------------------------------------
-- Pathfinder (immutable configuration + entry points)
----------------------------------------------------------------------

--- Pathfinder: immutable configuration plus high-level entry points.<br>
--- Created via `Pathfinder.new(cfg)`; the returned table is also a valid `AStar.new(cfg)` input.
---@class astar.Pathfinder
---@field neighbors? function Callback-mode enumeration: `neighbors(node, visitor)`.
---@field neighbors_buffer? function Buffered-mode enumeration: `neighbors_buffer(node, nbuf, cbuf) -> count`.
---@field cost? function Edge-cost fallback: `cost(from, to) -> positive number | nil | false`.
---@field heuristic function Heuristic: `heuristic(node, goal) -> number`.
---@field walkable? function Optional passability predicate: `walkable(node) -> boolean`.
---@field mode integer Search mode (0 = A*, 1 = Dijkstra, 2 = Greedy).
---@field mode_name string Human-readable mode name.
---@field reopen_closed boolean Re-open closed nodes when a better g-score is found.
---@field collect_stats boolean When true, collect push/stale-pop/invalid-edge statistics.
local Pathfinder = {}
Pathfinder.__index = Pathfinder

--- Validate that a config field is a function (or nil).<br>
--- Raises a descriptive error on mismatch.
---@param value any The value to check.
---@param name string Field name for error messages.
local function check_fn(value, name)
	if value ~= nil and type(value) ~= "function" then
		return error("astar: config." .. name .. " must be a function (got " .. type(value) .. ")", 3)
	end
end

--- Create a pathfinder from a configuration table.<br>
--- The returned object can be passed directly to `AStar.new(cfg)`.
---@param cfg? table Configuration table:
--- - `neighbors` (function): callback-mode enumeration `neighbors(node, visitor)`
--- - `neighbors_buffer` (function): buffered-mode `neighbors_buffer(node, nbuf, cbuf) -> count`
--- - `cost` (function): fallback edge cost `cost(from, to) -> number | nil | false`
--- - `heuristic` (function): `heuristic(node, goal) -> number`
--- - `walkable` (function): optional passability predicate
--- - `mode` (string): "astar" (default), "dijkstra", or "greedy"
--- - `reopen_closed` (boolean): re-open closed nodes for admissible-but-inconsistent heuristics
--- - `stats` (boolean): collect push/stale-pop statistics (default: true)
---@return astar.Pathfinder pf Configured pathfinder.
---@usage <br>
--- ```
--- local pf = astar.new({
---   neighbors = function(node, emit) emit("b", 1); emit("c", 2) end,
---   heuristic = function(a, b) return 0 end, -- replace with real heuristic
--- })
--- ```
function Pathfinder.new(cfg)
	cfg = cfg or {}

	local mode_str = cfg.mode or "astar"
	local mode = MODE_IDS[mode_str]
	if not mode then
		return error("astar: unknown mode '" .. tostring(mode_str) .. "' (expected 'astar', 'dijkstra' or 'greedy')", 2)
	end

	local neighbors = cfg.neighbors
	local neighbors_buffer = cfg.neighbors_buffer
	if neighbors ~= nil and neighbors_buffer ~= nil then
		return error("astar: provide only one of config.neighbors or config.neighbors_buffer", 2)
	end
	check_fn(neighbors, "neighbors")
	check_fn(neighbors_buffer, "neighbors_buffer")
	if neighbors == nil and neighbors_buffer == nil then
		return error(
			"astar: configuration must provide 'neighbors' (callback mode) or 'neighbors_buffer' (buffered mode)", 2)
	end

	local heuristic = cfg.heuristic
	check_fn(heuristic, "heuristic")
	local cost = cfg.cost
	check_fn(cost, "cost")
	local walkable = cfg.walkable
	check_fn(walkable, "walkable")

	if mode == MODE_DIJKSTRA then
		-- Dijkstra never calls the heuristic; drop it from the hot path.
		heuristic = nil
	elseif heuristic == nil then
		heuristic = function() return 0 end
	end

	return setmetatable({
		neighbors = neighbors,
		neighbors_buffer = neighbors_buffer,
		cost = cost,
		heuristic = heuristic,
		walkable = walkable,
		mode = mode,
		mode_name = mode_str,
		reopen_closed = cfg.reopen_closed == true,
		collect_stats = cfg.stats ~= false,
	}, Pathfinder)
end

--- One-shot search. Returns path (start -> goal) or nil, plus an info table.<br>
--- Allocates one Search object per call; for repeated searches prefer `create_search()` + `reset()`.
---@param self astar.Pathfinder The pathfinder instance.
---@param start any Start node.
---@param goal any Goal node.
---@param opts? table Same options as `Search:reset()`.
---@return table? path Ordered path nodes from start to goal, or nil if not found.
---@return table info Result and statistics table.
function Pathfinder.find(pf, start, goal, opts)
	local s = Search.new(pf)
	s:reset(start, goal, opts)
	s:run()
	return s:path()
end

--- Begin an incremental search. Returns a Search with status "running"<br>
--- (or already "success"/"failure" for trivial/blocked cases).
---@param self astar.Pathfinder The pathfinder instance.
---@param start any Start node.
---@param goal any Goal node.
---@param opts? table Same options as `Search:reset()`.
---@return astar.Search search Search object in the "running" (or terminal) state.
function Pathfinder.start(pf, start, goal, opts)
	local s = Search.new(pf)
	s:reset(start, goal, opts)
	return s
end

--- Create a reusable, idle Search object bound to this pathfinder.<br>
--- Use `search:reset(start, goal, opts)` to run successive searches.
---@param self astar.Pathfinder The pathfinder instance.
---@return astar.Search search Fresh search object in the "idle" state.
function Pathfinder.create_search(pf)
	return Search.new(pf)
end

-- Export
return {
	new = Pathfinder.new,
	_Pathfinder = Pathfinder,
	_Search = Search,
	_MAX_GENERATION = MAX_GENERATION,
}
