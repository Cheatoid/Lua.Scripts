-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Convenience graph adapters that turn common in-memory graph representations
-- into the buffered neighbor interface used by the A* core:
--
--     neighbors_buffer(node, node_buf, cost_buf) -> count
--
-- These are for convenience / prototyping. For maximum performance, write a
-- dedicated adapter (see grid2d.lua) that fills the buffers without going
-- through intermediate tables.

--- Graph adapter helpers for the A* core.<br>
--- Convert common in-memory representations into the `neighbors_buffer` contract.<br>
--- For production use, write a dedicated adapter (e.g. Grid2D) that fills buffers without intermediate tables.
---@class astar.graph
local M = {}

----------------------------------------------------------------------
-- adj[node] = {n1, n2, ...}                (uniform cost 1 per edge)
-- costs[node] = {c1, c2, ...}              (optional, parallel to adj[node])
--
-- Returns a config table suitable for AStar.new(cfg).
----------------------------------------------------------------------

--- Build a buffered-neighbor config from a plain adjacency list.<br>
--- Costs default to 1 when no parallel cost table is provided.<br>
--- The returned config is suitable for `AStar.new(cfg)`.
---@param adj table Adjacency list: `adj[node] = {n1, n2, ...}`.
---@param costs? table Optional parallel cost table: `costs[node] = {c1, c2, ...}`.
---@return table config Configuration table with `neighbors_buffer`.
---@usage <br>
--- ```
--- local cfg = astar.graph.from_adjacency({ a = {"b","c"}, b = {"a"} })
--- ```
function M.from_adjacency(adj, costs)
	if costs then
		return {
			neighbors_buffer = function(node, nbuf, cbuf)
				local ns = adj[node]
				if not ns then return 0 end
				local cs = costs[node]
				local n = #ns
				for i = 1, n do
					nbuf[i] = ns[i]
					cbuf[i] = cs[i]
				end
				return n
			end,
		}
	end
	return {
		neighbors_buffer = function(node, nbuf, cbuf)
			local ns = adj[node]
			if not ns then return 0 end
			local n = #ns
			for i = 1, n do
				nbuf[i] = ns[i]
				cbuf[i] = 1
			end
			return n
		end,
	}
end

----------------------------------------------------------------------
-- adj[node] = { {node = n, cost = c}, {node = n2, cost = c2}, ... }
--
-- Returns a config table suitable for AStar.new(cfg).
----------------------------------------------------------------------

--- Build a buffered-neighbor config from a weighted adjacency list.<br>
--- Each entry must have `node` and `cost` fields.<br>
--- The returned config is suitable for `AStar.new(cfg)`.
---@param adj table Weighted adjacency list: `adj[node] = {{node=n, cost=c}, ...}`.
---@return table config Configuration table with `neighbors_buffer`.
---@usage <br>
--- ```
--- local cfg = astar.graph.from_weighted_adjacency({
---   a = {{node="b", cost=1}, {node="c", cost=5}},
--- })
--- ```
function M.from_weighted_adjacency(adj)
	return {
		neighbors_buffer = function(node, nbuf, cbuf)
			local es = adj[node]
			if not es then return 0 end
			local n = 0
			for i = 1, #es do
				local e = es[i]
				n = n + 1
				nbuf[n] = e.node
				cbuf[n] = e.cost
			end
			return n
		end,
	}
end

----------------------------------------------------------------------
-- Build both a symmetric adjacency structure and a matching config from a
-- list of edges. Useful for small undirected graphs in tests/examples.
--
--   edges = { {a, b, cost}, ... }
--
-- Returns config, adjacency (adjacency may be mutated afterwards).
----------------------------------------------------------------------

--- Build a symmetric adjacency structure and matching config from an edge list.<br>
--- Returns `cfg, adj, costs` where `cfg` is suitable for `AStar.new(cfg)`.<br>
--- The adjacency table may be mutated afterwards.
---@param edges table Edge list: `{{a, b, cost}, ...}`. Cost defaults to 1.
---@param symmetric? boolean When true (default), mirror every edge in both directions.
---@return table cfg Configuration table with `neighbors_buffer`.
---@return table adj Adjacency list: `adj[node] = {n1, n2, ...}`.
---@return table costs Parallel cost table: `costs[node] = {c1, c2, ...}`.
---@usage <br>
--- ```
--- local cfg, adj, costs = astar.graph.from_edges({{1,2,1}, {2,3,5}}, true)
--- ```
function M.from_edges(edges, symmetric)
	local adj = {}
	local costs = {}
	for i = 1, #edges do
		local e = edges[i]
		local a, b, c = e[1], e[2], e[3] or 1
		adj[a] = adj[a] or {}
		costs[a] = costs[a] or {}
		local na = #adj[a] + 1
		adj[a][na] = b
		costs[a][na] = c
		if symmetric then
			adj[b] = adj[b] or {}
			costs[b] = costs[b] or {}
			local nb = #adj[b] + 1
			adj[b][nb] = a
			costs[b][nb] = c
		end
	end
	return M.from_adjacency(adj, costs), adj, costs
end

-- Export
return M
