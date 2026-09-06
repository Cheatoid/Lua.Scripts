-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Built-in heuristic helpers.
--
-- IMPORTANT: the A* core is representation-agnostic, so heuristics are just
-- `h(node, goal) -> number` functions. The built-ins below come in three
-- flavours:
--
--   1. Coordinate-table heuristics: expect nodes to be tables with numeric
--      `x`, `y` (and optionally `z`) fields.
--   2. Grid-id heuristics (factories): expect nodes to be integer ids into a
--      row-major grid of a known width (see grid2d.lua / grid3d.lua).
--   3. Trivial helpers: zero / constant.
--
-- For any other node representation, write your own h(node, goal).
--
-- Heuristic theory, in short:
--
--   * ADMISSIBLE:  h(n) <= true remaining cost. Guarantees A* returns an
--     optimal path (with non-negative edge costs).
--   * CONSISTENT:  h(n) <= cost(n, m) + h(m) for every edge. Guarantees the
--     first time a node is popped it has its final optimal g-score, which
--     lets the search skip closed nodes (this library's default).
--   * Every consistent heuristic is admissible; not vice versa. If your
--     heuristic is admissible but inconsistent, enable `reopen_closed = true`
--     in the pathfinder config to preserve optimality.
--   * Non-admissible heuristics (e.g. euclidean_squared, or weighted A*) are
--     faster but the returned path may be suboptimal.
--
-- All built-in grid heuristics are consistent for unit (or larger) costs.

-- Localized global functions for better performance
local math_sqrt = math.sqrt
local math_abs = math.abs

local SQRT2 = math_sqrt(2)
local SQRT3 = math_sqrt(3)
local SQRT2M1 = SQRT2 - 1

--- Built-in heuristic helpers collection.<br>
--- Heuristics are `h(node, goal) -> number` functions consumed by the A* core.<br>
--- Built-ins come in three flavours: coordinate-table heuristics, integer-grid-id factories, and trivial helpers.
---@class astar.heuristics
local M = {}

--- Dijkstra mode: h = 0. Admissible and consistent for any graph.<br>
-- (Tip: mode = "dijkstra" on the pathfinder skips the h call entirely.)
---@param _node any The current node (ignored).
---@param _goal any The goal node (ignored).
---@return number zero Always returns 0.
function M.zero(_node, _goal)
	return 0
end

--- Returns a heuristic with a constant value (useful for weighted A*-style speed/quality tradeoffs; NOT admissible unless c = 0).<br>
--- The returned function ignores both node and goal.
---@param c number Constant value to return.
---@return function h A heuristic function that always returns `c`.
---@usage <br>
--- ```
--- local h = astar.heuristics.constant(5)
--- print(h(0, 100)) -- 5
--- ```
function M.constant(c)
	return function(_node, _goal)
		return c
	end
end

----------------------------------------------------------------------
-- 2D heuristics for nodes that are tables with .x and .y fields
----------------------------------------------------------------------

--- Manhattan distance. Consistent on 4-connected grids with cost >= 1.<br>
--- Expects nodes to be tables with numeric `x` and `y` fields.
---@param a table Node A with `.x` and `.y` fields.
---@param b table Node B with `.x` and `.y` fields.
---@return number dist |a.x - b.x| + |a.y - b.y|.
function M.manhattan(a, b)
	return math_abs(a.x - b.x) + math_abs(a.y - b.y)
end

--- Euclidean distance. Consistent when single moves cost at least the straight-line distance they cover.<br>
--- Expects nodes to be tables with numeric `x` and `y` fields.
---@param a table Node A with `.x` and `.y` fields.
---@param b table Node B with `.x` and `.y` fields.
---@return number dist sqrt((a.x-b.x)^2 + (a.y-b.y)^2).
function M.euclidean(a, b)
	local dx, dy = a.x - b.x, a.y - b.y
	return math_sqrt(dx * dx + dy * dy)
end

--- Squared Euclidean. NOT admissible (it overestimates distances > 1), so it does not guarantee optimal paths; it is a cheap, strongly-guiding heuristic for when speed matters more than optimality.<br>
--- Expects nodes to be tables with numeric `x` and `y` fields.
---@param a table Node A with `.x` and `.y` fields.
---@param b table Node B with `.x` and `.y` fields.
---@return number dist (a.x-b.x)^2 + (a.y-b.y)^2.
function M.euclidean_squared(a, b)
	local dx, dy = a.x - b.x, a.y - b.y
	return dx * dx + dy * dy
end

--- Chebyshev distance (king moves with cost 1, including diagonals).<br>
--- Consistent on 8-connected grids where diagonals cost 1.<br>
--- Expects nodes to be tables with numeric `x` and `y` fields.
---@param a table Node A with `.x` and `.y` fields.
---@param b table Node B with `.x` and `.y` fields.
---@return number dist max(|a.x - b.x|, |a.y - b.y|).
function M.chebyshev(a, b)
	local dx, dy = math_abs(a.x - b.x), math_abs(a.y - b.y)
	if dx < dy then return dy end
	return dx
end

--- Octile distance (straight = 1, diagonal = sqrt(2)).<br>
--- Consistent on 8-connected grids with diagonal cost sqrt(2).<br>
--- Expects nodes to be tables with numeric `x` and `y` fields.
---@param a table Node A with `.x` and `.y` fields.
---@param b table Node B with `.x` and `.y` fields.
---@return number dist max(dx, dy) + (sqrt(2) - 1) * min(dx, dy).
function M.octile(a, b)
	local dx, dy = math_abs(a.x - b.x), math_abs(a.y - b.y)
	if dx < dy then dx, dy = dy, dx end -- dx = max, dy = min
	return dx + SQRT2M1 * dy
end

----------------------------------------------------------------------
-- 3D heuristics for nodes that are tables with .x/.y/.z fields
----------------------------------------------------------------------

--- 3D Manhattan distance. Consistent on 6-connected grids with cost >= 1.<br>
--- Expects nodes to be tables with numeric `x`, `y`, and `z` fields.
---@param a table Node A with `.x`, `.y`, `.z` fields.
---@param b table Node B with `.x`, `.y`, `.z` fields.
---@return number dist |a.x-b.x| + |a.y-b.y| + |a.z-b.z|.
function M.manhattan3(a, b)
	return math_abs(a.x - b.x) + math_abs(a.y - b.y) + math_abs(a.z - b.z)
end

--- 3D Euclidean distance. Consistent when moves cost at least the straight-line distance.<br>
--- Expects nodes to be tables with numeric `x`, `y`, and `z` fields.
---@param a table Node A with `.x`, `.y`, `.z` fields.
---@param b table Node B with `.x`, `.y`, `.z` fields.
---@return number dist sqrt((a.x-b.x)^2 + (a.y-b.y)^2 + (a.z-b.z)^2).
function M.euclidean3(a, b)
	local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
	return math_sqrt(dx * dx + dy * dy + dz * dz)
end

--- 3D Chebyshev distance (26-connected king moves).<br>
--- Consistent on 26-connected grids where every step costs 1.<br>
--- Expects nodes to be tables with numeric `x`, `y`, and `z` fields.
---@param a table Node A with `.x`, `.y`, `.z` fields.
---@param b table Node B with `.x`, `.y`, `.z` fields.
---@return number dist max(|a.x-b.x|, |a.y-b.y|, |a.z-b.z|).
function M.chebyshev3(a, b)
	local dx, dy, dz = math_abs(a.x - b.x), math_abs(a.y - b.y), math_abs(a.z - b.z)
	local m = dx
	if dy > m then m = dy end
	if dz > m then m = dz end
	return m
end

----------------------------------------------------------------------
-- Factories for integer grid ids (row-major: id = x + width * (y - 1))
----------------------------------------------------------------------

--- Manhattan heuristic over row-major integer ids of a grid with `width` columns.<br>
--- (grid2d.lua already provides a tuned default; this factory is for custom grid implementations.)<br>
--- Returns a function `h(a, b)` where `a` and `b` are integer ids.
---@param width integer Number of columns in the grid.
---@return function h Heuristic function for integer grid ids.
---@usage <br>
--- ```
--- local h = astar.heuristics.grid_manhattan(64)
--- print(h(1, 64)) -- 63
--- ```
function M.grid_manhattan(width)
	local w = width
	return function(a, b)
		local ax = (a - 1) % w
		local bx = (b - 1) % w
		local dx = ax - bx
		if dx < 0 then dx = -dx end
		local dy = ((a - 1 - ax) - (b - 1 - bx)) / w
		if dy < 0 then dy = -dy end
		return dx + dy
	end
end

--- Euclidean heuristic over row-major integer ids of a grid with `width` columns.<br>
--- Useful for grid adapters whose diagonal moves cost their euclidean length, and for any 4/8-connected grid as a (more expensive, looser) admissible estimate.<br>
--- Returns a function `h(a, b)` where `a` and `b` are integer ids.
---@param width integer Number of columns in the grid.
---@return function h Heuristic function for integer grid ids.
---@usage <br>
--- ```
--- local h = astar.heuristics.grid_euclidean(64)
--- print(h(1, 64)) -- 63
--- ```
function M.grid_euclidean(width)
	local w = width
	local sqrt = math_sqrt
	return function(a, b)
		local ax = (a - 1) % w
		local bx = (b - 1) % w
		local dx = ax - bx
		local dy = ((a - 1 - ax) - (b - 1 - bx)) / w
		return math_sqrt(dx * dx + dy * dy)
	end
end

--- Octile heuristic over row-major integer ids of a grid with `width` columns (8-connected grids).<br>
--- Returns a function `h(a, b)` where `a` and `b` are integer ids.
---@param width integer Number of columns in the grid.
---@return function h Heuristic function for integer grid ids.
---@usage <br>
--- ```
--- local h = astar.heuristics.grid_octile(64)
--- print(h(1, 64)) -- 63
--- ```
function M.grid_octile(width)
	local w = width
	return function(a, b)
		local ax = (a - 1) % w
		local bx = (b - 1) % w
		local dx = ax - bx
		if dx < 0 then dx = -dx end
		local dy = ((a - 1 - ax) - (b - 1 - bx)) / w
		if dy < 0 then dy = -dy end
		if dx < dy then dx, dy = dy, dx end
		return dx + SQRT2M1 * dy
	end
end

M.SQRT2 = SQRT2
M.SQRT3 = SQRT3

-- Export
return M
