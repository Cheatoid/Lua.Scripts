-- weighted graphs, heuristics, determinism,
-- custom node types, cost policies, search modes

return function(T)
	local AStar, util = T.AStar, T.util
	local test, eq, ok, near = T.test, T.eq, T.ok, T.near
	local graph = require "../graph"
	local heuristics = require "../heuristics"

	test("correctness: weighted diamond picks the cheap route", function()
		local pf = AStar.new(graph.from_edges({
			{ 1, 2, 1 }, { 1, 3, 10 }, { 2, 4, 1 }, { 3, 4, 1 },
		}, true))
		local path, info = pf:find(1, 4)
		ok(path)
		eq(info.path_cost, 2)
		eq(#path, 3)
		eq(path[2], 2)
	end)

	test("correctness: weighted graph where greedy detour is optimal", function()
		-- A "fast road" costs 0.5/step: 1 -> 2 -> 3 -> 4 (road) = 1.5
		-- versus direct 1 -> 4 = 10.
		local pf = AStar.new(graph.from_edges({
			{ 1, 2, 0.5 }, { 2, 3, 0.5 }, { 3, 4, 0.5 }, { 1, 4, 10 },
		}, true))
		local path, info = pf:find(1, 4)
		ok(path)
		near(info.path_cost, 1.5, 1e-12)
		eq(#path, 4)
	end)

	test("correctness: zero heuristic == dijkstra mode costs on random weighted maps", function()
		local rng = util.lcg(2024)
		for map_i = 1, 4 do
			local w, h = 24, 24
			local blocked = util.random_blocked(w, h, rng, 0.25)
			local terrain = {}
			for id = 1, w * h do
				if rng() < 0.4 then terrain[id] = 1 + math.floor(rng() * 8) end
			end
			local grid = AStar.Grid2D.new({ width = w, height = h, blocked = blocked, terrain = terrain })

			local pf_astar = AStar.new(grid) -- manhattan default
			local pf_zero = AStar.new({
				neighbors_buffer = grid.neighbors_buffer,
				walkable = grid.walkable,
				heuristic = heuristics.zero,
			})
			local pf_dij = AStar.new({
				neighbors_buffer = grid.neighbors_buffer,
				walkable = grid.walkable,
				mode = "dijkstra",
			})
			local s, g2 = 1, w * h
			local p1, i1 = pf_astar:find(s, g2)
			local p2, i2 = pf_zero:find(s, g2)
			local p3, i3 = pf_dij:find(s, g2)
			if i1.found then
				ok(i2.found, "zero-heuristic should also find it")
				ok(i3.found, "dijkstra should also find it")
				near(i1.path_cost, i2.path_cost, 1e-9, "astar vs zero cost mismatch")
				near(i1.path_cost, i3.path_cost, 1e-9, "astar vs dijkstra cost mismatch")
			else
				eq(i2.found, false, "found agreement")
				eq(i3.found, false, "found agreement")
			end
		end
	end)

	test("correctness: all admissible heuristics agree on optimal cost (4-connected)", function()
		local rng = util.lcg(99)
		local w, h = 20, 20
		local grid4 = AStar.Grid2D.new({
			width = w,
			height = h,
			blocked = util.random_blocked(w, h, rng, 0.2),
		})
		-- manhattan / octile / zero are all admissible + consistent on a
		-- 4-connected grid, so they must agree on the optimal cost.
		-- (id-based factories: grid nodes are integers, not {x,y} tables)
		local hs = {
			grid_manhattan = heuristics.grid_manhattan(w),
			grid_octile = heuristics.grid_octile(w),
			zero = heuristics.zero,
		}
		local ref
		for name, hfn in pairs(hs) do
			local pf = AStar.new({
				neighbors_buffer = grid4.neighbors_buffer,
				walkable = grid4.walkable,
				heuristic = hfn,
			})
			local p, info = pf:find(1, w * h)
			if ref == nil then ref = info.found and info.path_cost or false end
			if info.found then
				ok(ref ~= false, "found agreement")
				near(info.path_cost, ref, 1e-9, name .. " disagrees on optimal cost")
			else
				eq(ref, false, "found agreement")
			end
		end
	end)

	test("correctness: dijkstra explores uniformly (expanded == discovered - 1 + goal)", function()
		local w, h = 10, 10
		local grid = AStar.Grid2D.new({ width = w, height = h })
		local pf = AStar.new({ neighbors_buffer = grid.neighbors_buffer, mode = "dijkstra" })
		local p, info = pf:find(1, w * h)
		ok(info.found)
		near(info.path_cost, (w - 1) + (h - 1), 1e-9)
		eq(info.expanded, w * h - 1, "dijkstra on open grid expands everything before goal")
	end)

	test("correctness: determinism - identical runs give identical paths", function()
		local rng = util.lcg(555)
		local w, h = 32, 32
		local blocked = util.random_blocked(w, h, rng, 0.3)
		local grid = AStar.Grid2D.new({ width = w, height = h, blocked = blocked, diagonal = true })
		local pf = AStar.new(grid)
		local first = pf:find(1, w * h)
		for i = 1, 5 do
			local again = pf:find(1, w * h)
			if first then
				ok(again, "must find again")
				eq(util.list_to_string(again), util.list_to_string(first), "path differs between runs")
			else
				eq(again, nil)
			end
		end
	end)

	test("correctness: tie-breaking picks deterministic shortest path", function()
		-- Open 5x5 grid, 4-conn: many shortest paths exist; the tie-break
		-- (f, h, seq) must always select the same one. Any shortest 4-conn
		-- path from corner to corner has exactly dx+dy+1 nodes.
		local w, h = 5, 5
		local grid = AStar.Grid2D.new({ width = w, height = h })
		local pf = AStar.new(grid)
		local p1, i1 = pf:find(1, w * h)
		ok(p1)
		eq(#p1, (w - 1) + (h - 1) + 1)
		near(i1.path_cost, (w - 1) + (h - 1), 1e-9)
		local p2 = pf:find(1, w * h)
		eq(util.list_to_string(p2), util.list_to_string(p1))
	end)

	test("correctness: callback mode matches buffer mode", function()
		local rng = util.lcg(31337)
		local w, h = 16, 16
		local grid = AStar.Grid2D.new({
			width = w,
			height = h,
			blocked = util.random_blocked(w, h, rng, 0.25),
			terrain = (function()
				local t = {}
				for id = 1, w * h do
					if rng() < 0.3 then t[id] = 1 + math.floor(rng() * 5) end
				end
				return t
			end)(),
		})
		-- callback adapter over the same grid: enumerate then emit.
		-- Same heuristic + walkable as the buffered variant so tie-breaking
		-- must match exactly.
		local pf_cb = AStar.new({
			neighbors = function(node, emit)
				local nb, cb = {}, {}
				local n = grid.neighbors_buffer(node, nb, cb)
				for i = 1, n do emit(nb[i], cb[i]) end
			end,
			walkable = grid.walkable,
			heuristic = grid.heuristic,
		})
		local pf_buf = AStar.new(grid)
		for trial = 1, 8 do
			local s = 1 + math.floor(rng() * (w * h - 1))
			local g = 1 + math.floor(rng() * (w * h - 1))
			local p1, i1 = pf_cb:find(s, g)
			local p2, i2 = pf_buf:find(s, g)
			eq(i1.found, i2.found, "found agreement")
			if i1.found then
				near(i1.path_cost, i2.path_cost, 1e-9)
				eq(util.list_to_string(p1), util.list_to_string(p2))
			end
		end
	end)

	test("correctness: cost(from,to) fallback when enumeration yields no cost", function()
		local pf = AStar.new({
			neighbors = function(node, emit)
				if node == 1 then emit(2) end
				if node == 2 then
					emit(1)
					emit(3)
				end
				if node == 3 then emit(2) end
			end,
			cost = function(from, to)
				-- 1 -> 2 is expensive, everything else costs 1
				if from == 1 and to == 2 then return 5 end
				return 1
			end,
		})
		local p, info = pf:find(1, 3)
		ok(info.found)
		near(info.path_cost, 6, 1e-9)
	end)

	test("correctness: emitted cost takes precedence over cost()", function()
		local pf = AStar.new({
			neighbors = function(node, emit)
				if node == 1 then emit(2, 2) end
				if node == 2 then
					emit(1, 2)
					emit(3, 2)
				end
				if node == 3 then emit(2, 2) end
			end,
			cost = function() return 99 end, -- must be ignored
		})
		local p, info = pf:find(1, 3)
		near(info.path_cost, 4, 1e-9)
	end)

	test("correctness: invalid costs are skipped (negative, zero, NaN)", function()
		local pf = AStar.new({
			neighbors_buffer = function(node, nbuf, cbuf)
				if node == 1 then
					nbuf[1] = 2; cbuf[1] = -3 -- invalid: negative
					nbuf[2] = 3; cbuf[2] = 0 -- sentinel, but no cost fn -> invalid
					nbuf[3] = 4; cbuf[3] = 2 -- valid
					return 3
				elseif node == 4 then
					nbuf[1] = 5; cbuf[1] = 1
					return 1
				elseif node == 5 then
					nbuf[1] = 6; cbuf[1] = 0 / 0 -- NaN: invalid
					nbuf[2] = 7; cbuf[2] = 1 -- valid way out
					return 2
				end
				return 0
			end,
		})
		-- node 5 must be EXPANDED (goal lies beyond it) so its NaN edge is scanned
		local p, info = pf:find(1, 7)
		ok(info.found, "path via the valid edge")
		eq(info.path_cost, 4) -- 1 -> 4 -> 5 -> 7
		eq(info.invalid_edges, 3, "invalid edges counted")
	end)

	test("correctness: cost() returning false removes the edge", function()
		local pf = AStar.new({
			neighbors = function(node, emit)
				if node == 1 then
					emit(2)
					emit(3)
				end
				if node == 3 then emit(4) end
				if node == 4 then emit(2) end
			end,
			cost = function(from, to)
				if from == 1 and to == 2 then return false end -- wall
				return 1
			end,
		})
		local p, info = pf:find(1, 2)
		ok(info.found)
		near(info.path_cost, 3, 1e-9) -- 1 -> 3 -> 4 -> 2 (three edges)
	end)

	test("correctness: walkable predicate filters discovery", function()
		local w, h = 9, 9
		local grid = AStar.Grid2D.new({ width = w, height = h })
		local middle = grid:id(5, 5)
		local forbidden = { [middle] = true }
		local pf = AStar.new({
			neighbors_buffer = grid.neighbors_buffer,
			walkable = function(id) return not forbidden[id] end,
		})
		local p, info = pf:find(grid:id(1, 1), grid:id(9, 9))
		ok(info.found)
		for i = 1, #p do
			ok(p[i] ~= middle, "path must avoid forbidden node")
		end
	end)

	test("correctness: greedy mode finds a (possibly suboptimal) consistent path", function()
		local w, h = 20, 20
		local rng = util.lcg(4)
		local grid = AStar.Grid2D.new({
			width = w,
			height = h,
			blocked = util.random_blocked(w, h, rng, 0.2),
		})
		local pf = AStar.new({ neighbors_buffer = grid.neighbors_buffer, walkable = grid.walkable, mode = "greedy" })
		local p, info = pf:find(1, w * h)
		ok(info.found, "greedy should find the goal on an open-ish grid")
		ok(#p >= 2)
		-- path cost recorded equals the sum of edge costs along the path
		local total = util.grid_path_cost(grid, p)
		near(info.path_cost, total, 1e-9, "greedy path_cost must match walked cost")
	end)

	test("correctness: path cost matches walked edges (parent chain integrity)", function()
		local rng = util.lcg(8080)
		local w, h = 24, 24
		local terrain = {}
		for id = 1, w * h do
			if rng() < 0.5 then terrain[id] = 1 + math.floor(rng() * 6) end
		end
		local grid = AStar.Grid2D.new({
			width = w,
			height = h,
			blocked = util.random_blocked(w, h, rng, 0.25),
			terrain = terrain,
		})
		local pf = AStar.new(grid)
		for trial = 1, 10 do
			local s = 1 + math.floor(rng() * (w * h - 1))
			local g = 1 + math.floor(rng() * (w * h - 1))
			local p, info = pf:find(s, g)
			if info.found then
				local walked = util.grid_path_cost(grid, p)
				near(info.path_cost, walked, 1e-9, "parent chain/heap inconsistency")
			end
		end
	end)

	test("correctness: heuristics module sanity", function()
		local a, b = { x = 0, y = 0 }, { x = 3, y = 4 }
		near(heuristics.manhattan(a, b), 7, 1e-12)
		near(heuristics.euclidean(a, b), 5, 1e-12)
		near(heuristics.chebyshev(a, b), 4, 1e-12)
		near(heuristics.octile(a, b), 4 + (math.sqrt(2) - 1) * 3, 1e-12)
		near(heuristics.euclidean_squared(a, b), 25, 1e-12)
		near(heuristics.zero(a, b), 0, 0)
		near(heuristics.constant(2.5)(a, b), 2.5, 0)
		local c, d = { x = 1, y = 2, z = 3 }, { x = 2, y = 4, z = 6 }
		near(heuristics.manhattan3(c, d), 1 + 2 + 3, 1e-12)
		near(heuristics.euclidean3(c, d), math.sqrt(1 + 4 + 9), 1e-12)
		near(heuristics.chebyshev3(c, d), 3, 1e-12)
		-- grid-id factories
		local gm = heuristics.grid_manhattan(10)
		near(gm(1, 100), 9 + 9, 1e-12) -- (1,1) -> (10,10)
		local go = heuristics.grid_octile(10)
		near(go(1, 100), 9 + (math.sqrt(2) - 1) * 9, 1e-12)
	end)

	test("correctness: graph.from_weighted_adjacency", function()
		local pf = AStar.new(graph.from_weighted_adjacency({
			a = { { node = "b", cost = 1 }, { node = "c", cost = 4 } },
			b = { { node = "c", cost = 1 } },
		}))
		local p, info = pf:find("a", "c")
		near(info.path_cost, 2, 1e-9)
		eq(#p, 3)
	end)

	test("correctness: reopen_closed preserves optimality (flag sanity)", function()
		local rng = util.lcg(1234)
		local w, h = 20, 20
		local grid = AStar.Grid2D.new({
			width = w,
			height = h,
			diagonal = true,
			blocked = util.random_blocked(w, h, rng, 0.25),
		})
		local pf_plain = AStar.new(grid)
		local pf_reopen = AStar.new({
			neighbors_buffer = grid.neighbors_buffer,
			walkable = grid.walkable,
			heuristic = grid.heuristic,
			reopen_closed = true,
		})
		for trial = 1, 6 do
			local s = 1 + math.floor(rng() * (w * h - 1))
			local g = 1 + math.floor(rng() * (w * h - 1))
			local p1, i1 = pf_plain:find(s, g)
			local p2, i2 = pf_reopen:find(s, g)
			eq(i1.found, i2.found)
			if i1.found then
				-- with an admissible heuristic, reopening must not produce a
				-- worse path (and cannot beat the consistent variant)
				ok(i2.path_cost >= i1.path_cost - 1e-9, "reopen found better than optimal?! flag bug")
			end
		end
	end)

	test("correctness: stats=false skips optional bookkeeping but keeps counters", function()
		local w, h = 12, 12
		local grid = AStar.Grid2D.new({ width = w, height = h })
		local pf = AStar.new({ neighbors_buffer = grid.neighbors_buffer, stats = false })
		local p, info = pf:find(1, w * h)
		ok(info.found)
		ok(info.expanded > 0, "expanded always tracked")
		ok(info.discovered > 0, "discovered always tracked")
		ok(info.iterations > 0, "iterations always tracked")
		eq(info.pushes, 0, "pushes skipped when stats disabled")
		eq(info.max_open, 0, "max_open skipped when stats disabled")
		eq(info.stale_pops, 0)
	end)

	test("correctness: stats invariants on a successful search", function()
		local w, h = 10, 10
		local grid = AStar.Grid2D.new({ width = w, height = h })
		local pf = AStar.new(grid)
		local p, info = pf:find(1, w * h)
		ok(info.found)
		-- every cycle pops exactly one entry: iterations = expanded + goal + stale
		eq(info.iterations, info.expanded + 1 + info.stale_pops, "iterations invariant")
		ok(info.expanded <= info.discovered, "expanded <= discovered")
		ok(info.max_open >= 1, "max_open >= 1")
		ok(info.pushes >= info.discovered, "pushes >= discovered")
		near(info.path_cost, (w - 1) + (h - 1), 1e-9)
	end)

	test("correctness: early_exit returns first discovery (may be suboptimal)", function()
		-- S -> A(1), A -> G(1), S -> G(3): direct edge discovered first.
		local pf = AStar.new(graph.from_edges({
			{ 1, 2, 1 }, { 2, 3, 1 }, { 1, 3, 3 },
		}, true))
		local p1, i1 = pf:find(1, 3)
		near(i1.path_cost, 2, 1e-9, "optimal search takes the detour")

		local p2, i2 = pf:find(1, 3, { early_exit = true })
		ok(i2.found)
		near(i2.path_cost, 3, 1e-9, "early exit stops at first discovery")
		eq(#p2, 2)
	end)
end
