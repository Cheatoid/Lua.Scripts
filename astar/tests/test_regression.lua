-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Every bug found during development becomes a test here.
-- Each entry cites the failure mode it guards against.

return function(T)
	local AStar, util = T.AStar, T.util
	local test, eq, ok, near = T.test, T.eq, T.ok, T.near
	local graph = require "../graph"

	-- REGRESSION 1: stamp-collision across generations.
	-- Encoding states as generation*K+code only works if the code spacing
	-- exceeds the number of states; a stale "closed" stamp from generation N
	-- once collided with "open" in generation N+1, making untouched nodes
	-- look open and corrupting parent chains on search reuse.
	test("regression: stale closed stamps never look open after reuse", function()
		local grid = AStar.Grid2D.new({ width = 12, height = 12 })
		local pf = AStar.new(grid)
		local s = pf:create_search()
		for i = 1, 6 do
			s:reset(1, 144)
			s:run()
			local p, info = s:path()
			ok(info.found, "iteration " .. i)
			near(info.path_cost, 11 + 11, 1e-9)
			eq(p[1], 1)
			eq(p[#p], 144)
		end
	end)

	-- REGRESSION 2: path buffer tail trimming. Reusing a caller buffer that
	-- previously held a LONGER path must produce a correct #length (a nil
	-- hole at n+1 is not enough; every stale slot must be cleared).
	test("regression: reused path buffer trims every stale slot", function()
		local grid = AStar.Grid2D.new({ width = 20, height = 20 })
		local pf = AStar.new(grid)
		local s = pf:create_search()
		local buf = {}
		s:reset(1, 400) -- long-ish path
		s:run()
		s:path(buf)
		local long_len = #buf
		ok(long_len > 5, "setup: need a path longer than 5")
		s:reset(1, 2) -- short path into the same buffer
		s:run()
		local p = s:path(buf)
		eq(#p, 2)
		eq(#buf, 2, "stale slots 3.." .. long_len .. " must be cleared")
		for i = 3, long_len do
			eq(buf[i], nil, "slot " .. i)
		end
	end)

	-- REGRESSION 3: goal == start inside a normal (non short-circuit) flow
	-- after a previous longer search on the same object.
	test("regression: start == goal after a real search on the same object", function()
		local grid = AStar.Grid2D.new({ width = 8, height = 8 })
		local pf = AStar.new(grid)
		local s = pf:create_search()
		s:reset(1, 64)
		s:run()
		ok(s.found)
		s:reset(64, 64) -- trivial case, same object
		local p = s:result()
		ok(p, "trivial path must still reconstruct")
		eq(#p, 1)
		eq(p[1], 64)
		eq(s.path_cost, 0)
	end)

	-- REGRESSION 4: reset() must clear stale budget options (an omitted
	-- option in a later reset must not inherit the previous search's cap).
	test("regression: budget options do not leak into the next reset", function()
		local grid = AStar.Grid2D.new({ width = 12, height = 12 })
		local pf = AStar.new(grid)
		local s = pf:create_search()
		s:reset(1, 144, { max_iterations = 3 })
		s:run()
		eq(s.status, "failure")
		s:reset(1, 144) -- no budgets this time
		s:run()
		eq(s.status, "success", "old budget must not apply")
		local p, info = s:path()
		near(info.path_cost, 22, 1e-9)
	end)

	-- REGRESSION 5: stale duplicate entry after an open-node improvement.
	-- X is discovered via the expensive edge (f=5) and later improved via M
	-- (f=3). The old heap entry must be discarded as stale when popped, and
	-- the parent chain must reflect the improved route.
	test("regression: stale duplicate entry after open-node improvement", function()
		local pf = AStar.new(graph.from_edges({
			{ "S", "X", 5 },
			{ "S", "M", 1 }, { "M", "X", 2 },
			{ "X", "G", 3 },
		}, true))
		local p, info = pf:find("S", "G")
		ok(info.found)
		near(info.path_cost, 6, 1e-9, "S -> M -> X -> G = 1 + 2 + 3")
		eq(p[2], "M", "parent chain used the improved route")
		ok(info.stale_pops >= 1, "outdated (f=5) entry for X must be popped and discarded")
	end)

	-- REGRESSION 6: early_exit must not corrupt the state for subsequent
	-- searches on the same object (halt happened mid-expansion).
	test("regression: search reusable after early_exit halt", function()
		local pf = AStar.new(graph.from_edges({
			{ 1, 2, 1 }, { 2, 3, 1 }, { 1, 3, 3 }, { 3, 4, 1 },
		}, true))
		local p1, i1 = pf:find(1, 3, { early_exit = true })
		ok(i1.found)
		local p2, i2 = pf:find(1, 4)
		ok(i2.found, "search after early-exit must work")
		near(i2.path_cost, 3, 1e-9, "1->2->3->4 = 3")
	end)

	-- REGRESSION 7: invalid cost sentinel 0 without a cost fn must be
	-- counted, not crash, and must not produce a zero-cost path.
	test("regression: zero-cost sentinel without cost fn is invalid", function()
		local pf = AStar.new({
			neighbors_buffer = function(node, nbuf, cbuf)
				if node == 1 then
					nbuf[1] = 2
					cbuf[1] = 0
					return 1
				end
				return 0
			end,
		})
		local p, info = pf:find(1, 2)
		eq(p, nil)
		eq(info.found, false)
		ok(info.invalid_edges >= 1)
	end)

	-- REGRESSION 8: goal pop must report path_cost = g[goal], not f or h.
	test("regression: path_cost equals g-score of the goal", function()
		local pf = AStar.new(graph.from_edges({
			{ 1, 2, 1.5 }, { 2, 3, 2.5 }, { 3, 4, 0.5 },
		}, true))
		local p, info = pf:find(1, 4)
		near(info.path_cost, 4.5, 1e-9)
		near(info.path_cost, (1.5 + 2.5 + 0.5), 1e-12)
	end)

	-- REGRESSION 9: popping the goal must occur BEFORE expanding it (a goal
	-- with neighbors that would error must never be expanded).
	test("regression: goal is terminated on pop, never expanded", function()
		local expanded_goal = false
		local pf = AStar.new({
			neighbors_buffer = function(node, nbuf, cbuf)
				if node == 3 then
					expanded_goal = true -- must never happen
					return 0
				end
				if node == 1 then
					nbuf[1] = 2; cbuf[1] = 1
					return 1
				end
				if node == 2 then
					nbuf[1] = 3; cbuf[1] = 1
					return 1
				end
				return 0
			end,
		})
		local p, info = pf:find(1, 3)
		ok(info.found)
		eq(expanded_goal, false, "goal must not be expanded")
	end)

	-- REGRESSION 10: neighbors_buffer returning 0 for everything (isolated
	-- graph) must end in clean "failure", never an infinite loop.
	test("regression: empty neighbor enumeration terminates", function()
		local pf = AStar.new({
			neighbors_buffer = function() return 0 end,
		})
		local p, info = pf:find(1, 2)
		eq(p, nil)
		eq(info.status, "failure")
		eq(info.expanded, 1, "start expanded once, then open drains")
	end)

	-- REGRESSION 11: walkable() must be consulted for endpoints and for each
	-- node's FIRST discovery only; the blocked stamp must then suppress all
	-- repeat consultations within the same search (perf contract).
	test("regression: walkable applies to every first discovery", function()
		local seen = {}
		local grid = AStar.Grid2D.new({ width = 6, height = 6 })
		local blocked_cell = grid:id(3, 1)
		local pf = AStar.new({
			neighbors_buffer = grid.neighbors_buffer,
			walkable = function(id)
				seen[id] = (seen[id] or 0) + 1
				return id ~= blocked_cell
			end,
		})
		local p, info = pf:find(grid:id(1, 1), grid:id(6, 1))
		ok(info.found, "detour around the single blocked cell exists")
		near(info.path_cost, 7, 1e-9, "down 1, across 5, up 1, plus corner cell")
		for i = 1, #p do
			ok(p[i] ~= blocked_cell, "blocked cell avoided")
		end
		eq(seen[blocked_cell], 1, "blocked cell consulted exactly once")
	end)

	-- REGRESSION 12: dijkstra mode with a heuristic configured must IGNORE
	-- the heuristic entirely (same results as without).
	test("regression: dijkstra ignores configured heuristic", function()
		local grid = AStar.Grid2D.new({ width = 10, height = 10 })
		local pf_with = AStar.new({
			neighbors_buffer = grid.neighbors_buffer,
			heuristic = function() return error("heuristic must not be called in dijkstra mode") end,
			mode = "dijkstra",
		})
		local p, info = pf_with:find(1, 100)
		ok(info.found)
		near(info.path_cost, 18, 1e-9)
	end)

	-- REGRESSION 13: find() must not share state between two calls (the
	-- second find must be unaffected by the first).
	test("regression: consecutive find() calls are independent", function()
		local grid = AStar.Grid2D.new({ width = 10, height = 10 })
		local pf = AStar.new(grid)
		local p1, i1 = pf:find(1, 100)
		ok(i1.found)
		local p2, i2 = pf:find(100, 1)
		ok(i2.found)
		near(i1.path_cost, 18, 1e-9)
		near(i2.path_cost, 18, 1e-9)
		eq(p1[1], 1)
		eq(p2[1], 100)
		eq(p1[#p1], 100)
		eq(p2[#p2], 1)
	end)

	-- REGRESSION 14 (found during development): the internal path-length
	-- counter walked parents until nil. On a REUSED Search object the start
	-- node can carry a STALE parent from a previous generation, so the walk
	-- ran away and hung the search. Length must be counted only up to start.
	test("regression: path length stops at start on reused searches", function()
		local grid = AStar.Grid2D.new({ width = 16, height = 16 })
		local pf = AStar.new(grid)
		local s = pf:create_search()
		-- generation 1: long search touches (and assigns parents to) many nodes,
		-- including the future start node
		s:reset(1, 256)
		s:run()
		ok(s.found)
		-- generation 2: start from a node that had a parent in generation 1
		s:reset(30, 256)
		s:run()
		ok(s.found, "search on reused object must terminate")
		local p, info = s:path()
		ok(info.found)
		eq(#p, info.path_length, "reconstructed length matches computed length")
		eq(p[1], 30)
		eq(p[#p], 256)
	end)
end
