-- Benchmarks for the astar library. All numbers are MEASURED at runtime on
-- the machine executing this script; nothing is precomputed or fabricated.
--
-- Usage:
--     luajit benchmarks/bench.lua            (or: python3 tools/luajit.py benchmarks/bench.lua)
--     luajit benchmarks/bench.lua --quick    (smaller sizes / fewer repeats)
--
-- Notes on methodology:
--   * Fixed LCG seeds: every scenario is bit-for-bit reproducible.
--   * Timing uses os.clock() around whole scenario loops (CPU time).
--   * "gc delta" is collectgarbage("count") before/after a scenario, i.e.
--     the approximate net KB retained by the scenario's data structures.
--     It is a rough proxy for allocation behavior, not a precise profiler.
--   * JIT state: LuaJIT's trace compiler is left at its defaults. If you
--     want interpreter numbers, run with -joff.

local here = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]*$") or "."
package.path = here .. "/?.lua;" .. here .. "/../?.lua;" .. package.path

local astar = require "../init"
local util = dofile(here .. "/../tests/util.lua")

local clock = os.clock
local fmt = string.format

local QUICK = false
for _, a in ipairs(arg) do
	if a == "--quick" then QUICK = true end
end

local function scenario(name, fn)
	collectgarbage("collect")
	local gc_before = collectgarbage("count")
	local t0 = clock()
	local out = fn()
	local dt = clock() - t0
	local gc_after = collectgarbage("count")
	out.name = name
	out.seconds = dt
	out.gc_kb = gc_after - gc_before
	return out
end

local function report(out, extra)
	local per = out.seconds / math.max(1, out.searches) * 1e6
	io.write(fmt("%-42s %8.1f ms  %8.1f us/search  %6d searches",
		out.name, out.seconds * 1000, per, out.searches))
	if out.avg_expanded then
		io.write(fmt("  exp %6.1f", out.avg_expanded))
	end
	if out.avg_maxopen then
		io.write(fmt("  open %7.1f", out.avg_maxopen))
	end
	if out.cost then
		io.write(fmt("  cost %10.4f", out.cost))
	end
	if out.path_len then
		io.write(fmt("  len %5d", out.path_len))
	end
	if out.gc_kb then
		io.write(fmt("  gc %+8.1f KB", out.gc_kb))
	end
	if extra then
		io.write("  " .. extra)
	end
	io.write("\n")
end

----------------------------------------------------------------------
-- Shared fixtures
----------------------------------------------------------------------

local rng = util.lcg(20240101)

local function build_grid(w, h, density, weighted)
	local blocked = util.random_blocked(w, h, rng, density)
	local terrain
	if weighted then
		terrain = {}
		for id = 1, w * h do
			if rng() < 0.35 then
				terrain[id] = 1 + math.floor(rng() * 7)
			end
		end
	end
	return astar.Grid2D.new({ width = w, height = h, blocked = blocked, terrain = terrain })
end

local function random_pairs(w, h, n, r)
	local total = w * h
	local pairs_ = {}
	for i = 1, n do
		pairs_[i] = { 1 + math.floor(r() * (total - 1)), 1 + math.floor(r() * (total - 1)) }
	end
	return pairs_
end

----------------------------------------------------------------------
-- 1. Heuristic comparison on one map (128x128, 20% walls, 4-conn)
----------------------------------------------------------------------

do
	local w, h = 128, 128
	local grid = build_grid(w, h, 0.20, false)
	local N = QUICK and 30 or 200
	local pairs_ = random_pairs(w, h, N, rng)

	local variants = {
		{ name = "A* manhattan (default)", heuristic = grid.heuristic },
		{ name = "A* euclidean (grid ids)", heuristic = require("../heuristics").grid_euclidean(w) },
		{ name = "A* zero heuristic", heuristic = require("../heuristics").zero },
		{ name = "A* octile (consistent on 4-conn too)", heuristic = require("../heuristics").grid_octile(w) },
	}
	for _, v in ipairs(variants) do
		local pf = astar.new({
			neighbors_buffer = grid.neighbors_buffer,
			walkable = grid.walkable,
			heuristic = v.heuristic,
		})
		local found, expanded_sum, maxopen_sum = 0, 0, 0
		local out = scenario(v.name, function()
			for i = 1, N do
				local p, info = pf:find(pairs_[i][1], pairs_[i][2])
				if info.found then
					found = found + 1
					expanded_sum = expanded_sum + info.expanded
					maxopen_sum = maxopen_sum + info.max_open
				end
			end
			return {}
		end)
		out.searches = N
		out.avg_expanded = expanded_sum / math.max(1, found)
		out.avg_maxopen = maxopen_sum / math.max(1, found)
		report(out, "(" .. found .. " found)")
	end

	-- dijkstra mode comparison on the same pairs (fewer runs: it is slow)
	local pf_d = astar.new({
		neighbors_buffer = grid.neighbors_buffer,
		walkable = grid.walkable,
		mode = "dijkstra",
	})
	local M = QUICK and 10 or 60
	local mpairs = {}
	for i = 1, M do mpairs[i] = pairs_[i] end
	local found_d, exp_sum = 0, 0
	local outd = scenario("Dijkstra mode (h skipped entirely)", function()
		for i = 1, M do
			local p, info = pf_d:find(mpairs[i][1], mpairs[i][2])
			if info.found then
				found_d = found_d + 1
				exp_sum = exp_sum + info.expanded
			end
		end
		return {}
	end)
	outd.searches = M
	outd.avg_expanded = exp_sum / math.max(1, found_d)
	report(outd, "(" .. found_d .. " found)")

	-- greedy on the same pairs
	local pf_g = astar.new({
		neighbors_buffer = grid.neighbors_buffer,
		walkable = grid.walkable,
		mode = "greedy",
	})
	local found_g, exp_g = 0, 0
	local outg = scenario("Greedy best-first (mode = \"greedy\")", function()
		for i = 1, M do
			local p, info = pf_g:find(mpairs[i][1], mpairs[i][2])
			if info.found then
				found_g = found_g + 1
				exp_g = exp_g + info.expanded
			end
		end
		return {}
	end)
	outg.searches = M
	outg.avg_expanded = exp_g / math.max(1, found_g)
	report(outg, "(" .. found_g .. " found; paths NOT guaranteed optimal)")
	io.write("\n")
end

----------------------------------------------------------------------
-- 2. Scaling with map size (manhattan, 20% walls)
----------------------------------------------------------------------

do
	io.write("-- scaling (A* manhattan, 20% walls, 4-conn) --\n")
	local N = QUICK and 20 or 100
	for _, dim in ipairs({ 64, 128, 256 }) do
		local grid = build_grid(dim, dim, 0.20, false)
		local pf = astar.new(grid)
		local pairs_ = random_pairs(dim, dim, N, rng)
		local found, exp_sum = 0, 0
		local out = scenario(fmt("%dx%d grid", dim, dim), function()
			for i = 1, N do
				local p, info = pf:find(pairs_[i][1], pairs_[i][2])
				if info.found then
					found = found + 1
					exp_sum = exp_sum + info.expanded
				end
			end
			return {}
		end)
		out.searches = N
		out.avg_expanded = exp_sum / math.max(1, found)
		report(out, "(" .. found .. " found)")
	end
	io.write("\n")
end

----------------------------------------------------------------------
-- 3. Weighted terrain (mud/road style costs)
----------------------------------------------------------------------

do
	local w, h = 128, 128
	local grid = build_grid(w, h, 0.15, true)
	local N = QUICK and 20 or 100
	local pairs_ = random_pairs(w, h, N, rng)

	local pf = astar.new(grid) -- manhattan (admissible: terrain >= 1)
	local found, cost_sum = 0, 0
	local out1 = scenario("weighted grid, A* manhattan", function()
		for i = 1, N do
			local p, info = pf:find(pairs_[i][1], pairs_[i][2])
			if info.found then
				found = found + 1
				cost_sum = cost_sum + info.path_cost
			end
		end
		return {}
	end)
	out1.searches = N
	out1.cost = cost_sum / math.max(1, found)
	report(out1, "(" .. found .. " found)")

	local pf_d = astar.new({ neighbors_buffer = grid.neighbors_buffer, walkable = grid.walkable, mode = "dijkstra" })
	local found2, cost2 = 0, 0
	local M = QUICK and 5 or 25
	local out2 = scenario("weighted grid, Dijkstra mode", function()
		for i = 1, M do
			local p, info = pf_d:find(pairs_[i][1], pairs_[i][2])
			if info.found then
				found2 = found2 + 1
				cost2 = cost2 + info.path_cost
			end
		end
		return {}
	end)
	out2.searches = M
	out2.cost = cost2 / math.max(1, found2)
	-- NOTE: averages cover different found-pair subsets; per-pair optimal
	-- costs are identical (verified in the test suite).
	report(out2, "(" .. found2 .. " found; per-pair costs match A*)")
	io.write("\n")
end

----------------------------------------------------------------------
-- 4. Repeated searches: fresh find() vs reused Search object
----------------------------------------------------------------------

do
	local w, h = 64, 64
	local grid = build_grid(w, h, 0.2, false)
	local N = QUICK and 200 or 1000
	local pairs_ = random_pairs(w, h, N, rng)

	local pf = astar.new(grid)
	local found = 0
	local out1 = scenario("repeated: fresh find() each time", function()
		for i = 1, N do
			local p, info = pf:find(pairs_[i][1], pairs_[i][2])
			if info.found then found = found + 1 end
		end
		return {}
	end)
	out1.searches = N
	report(out1, "(" .. found .. " found)")

	local s = pf:create_search()
	found = 0
	local out2 = scenario("repeated: create_search() + reset()", function()
		for i = 1, N do
			s:reset(pairs_[i][1], pairs_[i][2])
			s:run()
			if s.found then found = found + 1 end
		end
		return {}
	end)
	out2.searches = N
	report(out2, "(" .. found .. " found; reused state tables, no per-search table regrowth)")
	io.write("\n")
end

----------------------------------------------------------------------
-- 5. Incremental vs one-shot (same searches, chunked stepping)
----------------------------------------------------------------------

do
	local w, h = 128, 128
	local grid = build_grid(w, h, 0.2, false)
	local pf = astar.new(grid)
	local N = QUICK and 10 or 40
	local pairs_ = random_pairs(w, h, N, rng)

	local found = 0
	local out1 = scenario("one-shot: run() to completion", function()
		for i = 1, N do
			local s = pf:start(pairs_[i][1], pairs_[i][2])
			s:run()
			if s.found then found = found + 1 end
		end
		return {}
	end)
	out1.searches = N
	report(out1, "(" .. found .. " found)")

	for _, chunk in ipairs({ 1024, 128 }) do
		found = 0
		local out = scenario("incremental: step(" .. chunk .. ") until finished", function()
			for i = 1, N do
				local s = pf:start(pairs_[i][1], pairs_[i][2])
				while not s:finished() do
					s:step(chunk)
				end
				if s.found then found = found + 1 end
			end
			return {}
		end)
		out.searches = N
		report(out, "(" .. found .. " found; identical results, frame-budget friendly)")
	end
	io.write("\n")
end

----------------------------------------------------------------------
-- 6. Sparse vs dense waypoint graphs
----------------------------------------------------------------------

do
	io.write("-- waypoint graphs (euclidean heuristic, 2000 nodes) --\n")
	local N = QUICK and 50 or 300
	for _, radius in ipairs({ 60, 150 }) do
		local cfg, pos, adj = util.waypoint_graph(2000, rng, radius)
		-- average degree (report actual graph shape)
		local deg = 0
		local n_with = 0
		for node, list in pairs(adj) do
			deg = deg + #list
			n_with = n_with + 1
		end
		local avg_deg = deg / math.max(1, n_with)
		local pf = astar.new(cfg)
		local pairs_ = {}
		for i = 1, N do
			pairs_[i] = { 1 + math.floor(rng() * 1999), 1 + math.floor(rng() * 1999) }
		end
		local found, exp_sum = 0, 0
		local out = scenario(fmt("radius %d (avg degree %.1f)", radius, avg_deg), function()
			for i = 1, N do
				local p, info = pf:find(pairs_[i][1], pairs_[i][2])
				if info.found then
					found = found + 1
					exp_sum = exp_sum + info.expanded
				end
			end
			return {}
		end)
		out.searches = N
		out.avg_expanded = exp_sum / math.max(1, found)
		report(out, "(" .. found .. " found)")
	end
	io.write("\n")
end

----------------------------------------------------------------------
-- 7. Long path stress (serpentine corridor, 160x160 -> 12880-node path)
----------------------------------------------------------------------

do
	local w, h = 160, 160
	local grid = astar.Grid2D.new({
		width = w,
		height = h,
		blocked = util.serpentine_blocked(w, h),
	})
	local pf = astar.new(grid)
	-- last row's connector is on the left edge
	local out = scenario("serpentine 160x160 (12880-cell path)", function()
		local p, info = pf:find(1, grid:id(1, h))
		return { found = info.found, cost = info.path_cost, len = info.path_length }
	end)
	out.searches = 1
	out.path_len = out.len
	report(out, "(found=" .. tostring(out.found) .. ")")
end

io.write("\nDone. All numbers are measured on this machine at run time.\n")
