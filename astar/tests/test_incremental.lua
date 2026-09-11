-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- incremental stepping, budgets, cancellation, search-object reuse, generation handling

return function(T)
	local AStar, util = T.AStar, T.util
	local test, eq, ok, near = T.test, T.eq, T.ok, T.near
	local graph = require "../graph"

	local function make_map(rng, w, h)
		local terrain = {}
		for id = 1, w * h do
			if rng() < 0.4 then terrain[id] = 1 + math.floor(rng() * 6) end
		end
		return AStar.Grid2D.new({
			width = w,
			height = h,
			blocked = util.random_blocked(w, h, rng, 0.25),
			terrain = terrain,
		})
	end

	test("incremental: stepwise search == one-shot search exactly", function()
		local rng = util.lcg(20241225)
		for map_i = 1, 3 do
			local grid = make_map(rng, 24, 24)
			local pf = AStar.new(grid)
			for _, step_size in ipairs({ 1, 2, 3, 7, 1000 }) do
				local s = pf:start(1, 24 * 24)
				local guard = 0
				while not s:finished() do
					s:step(step_size)
					guard = guard + 1
					ok(guard < 100000, "incremental loop must terminate")
				end
				local p1, i1 = s:path()
				local p2, i2 = pf:find(1, 24 * 24)
				eq(i1.found, i2.found, "found agreement (map " .. map_i .. ", step " .. step_size .. ")")
				if i2.found then
					ok(i1.found, "incremental must find what one-shot finds")
					near(i1.path_cost, i2.path_cost, 1e-9)
					eq(#p1, #p2)
					eq(util.list_to_string(p1), util.list_to_string(p2),
						"identical path (map " .. map_i .. ", step " .. step_size .. ")")
					eq(i1.expanded, i2.expanded, "identical expansions")
					eq(i1.iterations, i2.iterations, "identical iterations")
				end
			end
		end
	end)

	test("incremental: step() default is one expansion", function()
		local grid = AStar.Grid2D.new({ width = 8, height = 8 })
		local pf = AStar.new(grid)
		local s = pf:start(1, 64)
		eq(s:step(), "running")
		eq(s.stats.expanded, 1)
		s:step(10)
		eq(s.stats.expanded, 11)
	end)

	test("incremental: step returns status for loop driving", function()
		local grid = AStar.Grid2D.new({ width = 8, height = 8 })
		local pf = AStar.new(grid)
		local s = pf:start(1, 64)
		while s:step(4) == "running" do end
		eq(s.status, "success")
	end)

	test("cancellation: mid-search cancel leaves well-defined state", function()
		local grid = AStar.Grid2D.new({ width = 60, height = 60 })
		local pf = AStar.new(grid)
		local s = pf:start(1, 60 * 60)
		s:step(30)
		eq(s.status, "running")
		s:cancel()
		eq(s.status, "canceled")
		ok(s:finished())
		ok(s:canceled())
		local p, info = s:path()
		eq(p, nil)
		eq(info.found, false)
		eq(info.canceled, true)
		eq(info.status, "canceled")
		-- further steps are no-ops
		eq(s:step(100), "canceled")
		eq(s:run(), "canceled")
		eq(s.stats.expanded, 30, "no additional expansion after cancel")
	end)

	test("budgets: max_iterations exhausts deterministically", function()
		local grid = AStar.Grid2D.new({ width = 30, height = 30 })
		local pf = AStar.new(grid)
		local p, info = pf:find(1, 30 * 30, { max_iterations = 10 })
		eq(p, nil)
		eq(info.found, false)
		eq(info.budget_exhausted, "iterations")
		eq(info.iterations, 10)
	end)

	test("budgets: max_iterations counts across incremental steps", function()
		local grid = AStar.Grid2D.new({ width = 30, height = 30 })
		local pf = AStar.new(grid)
		local s = pf:start(1, 30 * 30, { max_iterations = 25 })
		for i = 1, 10 do
			if s:finished() then break end
			s:step(5)
		end
		eq(s.status, "failure")
		eq(s.budget_exhausted, "iterations")
		eq(s.stats.iterations, 25)
	end)

	test("budgets: max_iterations = 0 performs no work", function()
		local grid = AStar.Grid2D.new({ width = 5, height = 5 })
		local pf = AStar.new(grid)
		local p, info = pf:find(1, 25, { max_iterations = 0 })
		eq(p, nil)
		eq(info.budget_exhausted, "iterations")
		eq(info.iterations, 0)
	end)

	test("budgets: max_nodes caps discovered nodes", function()
		local grid = AStar.Grid2D.new({ width = 20, height = 20 })
		local pf = AStar.new(grid)
		local p, info = pf:find(1, 20 * 20, { max_nodes = 5 })
		eq(p, nil)
		eq(info.budget_exhausted, "nodes")
		eq(info.discovered, 5, "discovered never exceeds the cap")
	end)

	test("budgets: max_cost prunes expensive routes", function()
		local grid = AStar.Grid2D.new({ width = 20, height = 20 })
		-- drown the whole map in mud so any path exceeds 15
		for id = 1, 20 * 20 do
			grid.terrain[id] = 5
		end
		local pf = AStar.new(grid)
		local p, info = pf:find(1, 20 * 20, { max_cost = 15 })
		eq(p, nil)
		eq(info.found, false)
		eq(info.budget_exhausted, "cost")
		ok(info.cost_pruned > 0)

		-- a generous budget still succeeds
		local p2, info2 = pf:find(1, 20 * 20, { max_cost = 1000 })
		ok(info2.found)
		near(info2.path_cost, 5 * ((20 - 1) + (20 - 1)), 1e-9)
	end)

	test("budgets: budget_seconds (opt-in wall clock) can exhaust", function()
		local grid = AStar.Grid2D.new({ width = 400, height = 400 })
		local pf = AStar.new(grid)
		local p, info = pf:find(1, 400 * 400, { budget_seconds = 0 })
		eq(p, nil)
		eq(info.budget_exhausted, "time")
		eq(info.found, false)
	end)

	test("reuse: reset() reuses the search object cleanly", function()
		local rng = util.lcg(424242)
		local grid = make_map(rng, 32, 32)
		local pf = AStar.new(grid)
		local s = pf:create_search()
		for trial = 1, 15 do
			local start = 1 + math.floor(rng() * (32 * 32 - 1))
			local goal = 1 + math.floor(rng() * (32 * 32 - 1))
			s:reset(start, goal)
			s:run()
			local p1, i1 = s:path()
			local p2, i2 = pf:find(start, goal)
			eq(i1.found, i2.found, "trial " .. trial .. " found agreement")
			if i2.found then
				near(i1.path_cost, i2.path_cost, 1e-9, "trial " .. trial)
				eq(util.list_to_string(p1), util.list_to_string(p2), "trial " .. trial)
			end
		end
	end)

	test("reuse: one search object across two different id spaces", function()
		-- Two grids are mapped into one combined id space (mapId * OFFSET +
		-- cell). The same Search object alternates between them; generation
		-- stamps must keep the two id spaces from interfering.
		local rng = util.lcg(31415)
		local w1, h1 = 16, 16
		local w2, h2 = 31, 20
		local g1 = make_map(rng, w1, h1)
		local g2 = make_map(rng, w2, h2)
		local OFFSET = 100000
		local maps = { [1] = g1, [2] = g2 }
		local counts = { [1] = w1 * h1, [2] = w2 * h2 }
		local pf = AStar.new({
			neighbors_buffer = function(node, nbuf, cbuf)
				local mid = math.floor(node / OFFSET)
				local cell = node - mid * OFFSET
				local n = maps[mid].neighbors_buffer(cell, nbuf, cbuf)
				for i = 1, n do
					nbuf[i] = nbuf[i] + mid * OFFSET
				end
				return n
			end,
			heuristic = function(a, b)
				local ma = math.floor(a / OFFSET)
				local mb = math.floor(b / OFFSET)
				return maps[ma].heuristic(a - ma * OFFSET, b - mb * OFFSET)
			end,
		})
		local s = pf:create_search()
		for trial = 1, 8 do
			local mid = (trial % 2) + 1
			local count = counts[mid]
			s:reset(mid * OFFSET + 1, mid * OFFSET + count)
			s:run()
			local p1, i1 = s:path()
			-- reference: plain search inside the map's own id space
			local pf_ref = AStar.new(maps[mid])
			local p2, i2 = pf_ref:find(1, count)
			eq(i1.found, i2.found, "trial " .. trial .. " found agreement")
			if i2.found then
				near(i1.path_cost, i2.path_cost, 1e-9)
				eq(#p1, #p2)
				for i = 1, #p1 do
					eq(p1[i], p2[i] + mid * OFFSET, "same cells, shifted ids")
				end
			end
		end
	end)

	test("reuse: dynamic walkable between searches (blocked stamps do not leak)", function()
		-- REGRESSION: nodes stamped "blocked" in generation N must be usable
		-- again in generation N+1 when the predicate changes.
		local grid = AStar.Grid2D.new({ width = 5, height = 5 })
		local dynamic_block = {}
		for y = 1, 5 do
			dynamic_block[grid:id(3, y)] = true -- wall the middle column
		end
		local pf = AStar.new({
			neighbors_buffer = grid.neighbors_buffer,
			walkable = function(id) return not dynamic_block[id] end,
		})
		local s = pf:create_search()

		s:reset(grid:id(2, 3), grid:id(4, 3))
		s:run()
		local p1, i1 = s:path()
		eq(i1.found, false, "middle column blocked")

		dynamic_block[grid:id(3, 3)] = nil -- open a gap
		s:reset(grid:id(2, 3), grid:id(4, 3))
		s:run()
		local p2, i2 = s:path()
		ok(i2.found, "gap opened: stamps from previous generation must not leak")
		near(i2.path_cost, 2, 1e-9)
	end)

	test("reuse: generation overflow path stays correct", function()
		local AStarCore = require "../astar"
		local grid = AStar.Grid2D.new({ width = 6, height = 6 })
		local pf = AStar.new(grid)
		local s = pf:create_search()
		-- force the generation counter next to its limit
		s.generation = AStarCore._MAX_GENERATION - 1
		s:reset(1, 36)
		s:run()
		local p, info = s:path()
		ok(info.found, "search works at the generation limit")
		-- counter restarted at 1 after overflow; search again
		s:reset(1, 36)
		s:run()
		local p2, info2 = s:path()
		ok(info2.found)
		near(info2.path_cost, info.path_cost, 1e-9)
		eq(s.generation, 2, "generation restarted")
	end)

	test("free(): releases memory and remains usable", function()
		local grid = AStar.Grid2D.new({ width = 40, height = 40 })
		local pf = AStar.new(grid)
		local s = pf:create_search()
		s:reset(1, 40 * 40)
		s:run()
		ok(s.stats.expanded > 0)
		s:free()
		eq(s.status, "idle")
		eq(s.stats.expanded, 0)
		s:reset(1, 40 * 40)
		s:run()
		local p, info = s:path()
		ok(info.found)
		near(info.path_cost, (40 - 1) + (40 - 1), 1e-9)
	end)

	test("pooled path buffers: caller buffer works across searches", function()
		local grid = AStar.Grid2D.new({ width = 10, height = 10 })
		local pf = AStar.new(grid)
		local s = pf:create_search()
		local buf = {}
		for i = 1, 5 do
			s:reset(i, 100)
			s:run()
			local p = s:path(buf)
			if p then
				eq(p[1], i, "path starts at the start node")
				eq(#buf, #p, "buffer length matches")
			end
		end
	end)

	test("start==goal short-circuit through incremental API", function()
		local grid = AStar.Grid2D.new({ width = 4, height = 4 })
		local pf = AStar.new(grid)
		local s = pf:start(7, 7)
		ok(s:finished())
		eq(s.status, "success")
		local p = s:result()
		ok(p)
		eq(#p, 1)
		eq(p[1], 7)
	end)

	test("pathfinder:start returns running search", function()
		local grid = AStar.Grid2D.new({ width = 4, height = 4 })
		local pf = AStar.new(grid)
		local s = pf:start(1, 16)
		eq(s.status, "running")
		while not s:finished() do s:step(3) end
		ok(s.status == "success")
	end)

	test("large graph: 200x200 random map with guaranteed corridor", function()
		local rng = util.lcg(1)
		local w, h = 200, 200
		local blocked = util.random_blocked(w, h, rng, 0.25)
		-- carve an L-shaped corridor: top row + right column -> (1,1) and
		-- (w,h) are always connected; the L path is exactly the manhattan
		-- lower bound, so the optimal cost is known exactly (4-conn).
		for x = 1, w do blocked[x] = nil end
		for y = 1, h do blocked[w * (y - 1) + w] = nil end
		local grid = AStar.Grid2D.new({ width = w, height = h, blocked = blocked })
		local pf = AStar.new(grid)
		local p, info = pf:find(1, w * h)
		ok(info.found, "corridor guarantees connectivity")
		near(info.path_cost, (w - 1) + (h - 1), 1e-9, "optimal == manhattan lower bound")
		eq(#p, (w - 1) + (h - 1) + 1, "exactly manhattan moves on 4-conn")
	end)
end
