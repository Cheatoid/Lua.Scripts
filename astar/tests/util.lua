-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Deterministic fixtures shared by the test suite and benchmarks.
-- No os.time()/math.random: everything is seeded so tests never flake.

local M = {}

--- Park-Miller LCG. 16807 * s < 2^45, so double arithmetic is exact and the
-- sequence is bit-for-bit identical on every platform/run.
function M.lcg(seed)
	local s = seed or 42
	return function()
		s = (s * 16807) % 2147483647
		return s / 2147483648 -- [0, 1)
	end
end

function M.randint(rng, lo, hi)
	return lo + math.floor(rng() * (hi - lo + 1))
end

--- Random blocked set for a width x height grid; guarantees that the four
-- corner cells stay passable.
function M.random_blocked(w, h, rng, density)
	local blocked = {}
	for id = 1, w * h do
		if rng() < density then
			blocked[id] = true
		end
	end
	blocked[1] = nil
	blocked[w] = nil
	blocked[w * (h - 1) + 1] = nil
	blocked[w * h] = nil
	return blocked
end

--- Serpentine corridor map: every cell is on the single corridor, so the
-- unique 4-connected path from (1,1) to (w,h) visits ALL w*h cells.
function M.serpentine_blocked(w, h)
	local blocked = {}
	-- Even rows (0-based y0 % 2 == 1) are walls except the connector cell.
	for y0 = 0, h - 1 do
		if y0 % 2 == 1 then
			-- connector alternates between x = 1 and x = w
			local cx
			if math.floor(y0 / 2) % 2 == 0 then cx = w else cx = 1 end
			for x0 = 0, w - 1 do
				if x0 ~= cx - 1 then
					blocked[x0 + 1 + w * y0] = true
				end
			end
		end
	end
	return blocked
end

--- Random geometric waypoint graph. Nodes are integer ids with positions;
-- edges connect node pairs within radius `radius`, with euclidean cost.
-- Returns cfg (for AStar.new), positions.
function M.waypoint_graph(n, rng, radius)
	local pos = {}
	for i = 1, n do
		pos[i] = { x = rng() * 1000, y = rng() * 1000 }
	end
	-- Bucket by coarse grid to keep O(n^2) away for big n.
	local cell = radius
	local buckets = {}
	for i = 1, n do
		local bx = math.floor(pos[i].x / cell)
		local by = math.floor(pos[i].y / cell)
		local key = bx * 4096 + by
		buckets[key] = buckets[key] or {}
		local b = buckets[key]
		b[#b + 1] = i
	end
	local adj = {}
	local costs = {}
	local r2 = radius * radius
	local function try_link(a, b)
		local dx = pos[a].x - pos[b].x
		local dy = pos[a].y - pos[b].y
		local d2 = dx * dx + dy * dy
		if d2 <= r2 then
			local c = math.sqrt(d2)
			adj[a] = adj[a] or {}
			costs[a] = costs[a] or {}
			adj[b] = adj[b] or {}
			costs[b] = costs[b] or {}
			local na, nb = #adj[a] + 1, #adj[b] + 1
			adj[a][na] = b
			costs[a][na] = c
			adj[b][nb] = a
			costs[b][nb] = c
		end
	end
	for i = 1, n do
		local bx = math.floor(pos[i].x / cell)
		local by = math.floor(pos[i].y / cell)
		for ox = -1, 1 do
			for oy = -1, 1 do
				local b = buckets[(bx + ox) * 4096 + (by + oy)]
				if b then
					for _, j in ipairs(b) do
						if j > i then try_link(i, j) end
					end
				end
			end
		end
	end
	local graph = require "../graph"
	local cfg = graph.from_adjacency(adj, costs)
	-- euclidean heuristic on positions
	cfg.heuristic = function(a, b)
		local pa, pb = pos[a], pos[b]
		local dx, dy = pa.x - pb.x, pa.y - pb.y
		return math.sqrt(dx * dx + dy * dy)
	end
	return cfg, pos, adj, costs
end

--- Sum of edge costs along a path using a grid's cost model (test oracle).
function M.grid_path_cost(grid, path)
	local total = 0
	for i = 2, #path do
		local a, b = path[i - 1], path[i]
		local ax, ay = grid:coords(a)
		local bx, by = grid:coords(b)
		local dx, dy = bx - ax, by - ay
		local adx, ady = dx < 0 and -dx or dx, dy < 0 and -dy or dy
		local base
		if adx + ady == 2 then
			base = math.sqrt(2)
		elseif adx + ady == 1 then
			base = 1
		else
			return nil, "invalid step at " .. i
		end
		local t = grid.terrain[b]
		total = total + base * (t and t > 0 and t or 1)
	end
	return total
end

function M.list_to_string(path)
	local parts = {}
	for i = 1, #path do parts[i] = tostring(path[i]) end
	return table.concat(parts, ",")
end

-- Export
return M
