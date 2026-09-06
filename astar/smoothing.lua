-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Optional post-processing for A* output paths. Deliberately SEPARATE from
-- the search core: the core knows nothing about geometry or line of sight.
--
-- Greedy string pulling: repeatedly replace the current anchor with the
-- farthest path node visible from it, according to a user-supplied predicate:
--
--     line_of_sight(a, b) -> boolean
--
-- Properties:
--   * deterministic (scan order is fixed: farthest-first)
--   * O(n^2) LOS calls in the worst case (n = path length); fine for typical
--     game paths, potentially slow for very long ones
--   * never returns an invalid path: it only removes nodes, and it always
--     keeps at least consecutive-visible steps (if even adjacent nodes fail
--     the LOS test, the original node is kept)

--- Post-processing for A* output paths via greedy string pulling.<br>
--- Repeatedly replaces the current anchor with the farthest path node visible from it, according to `line_of_sight`.<br>
--- Deliberately separate from the search core: the core knows nothing about geometry or line of sight.
---@class astar.smoothing
local M = {}

--- Smooth a path using greedy string pulling.<br>
--- Never returns an invalid path: it only removes nodes, and always keeps at least consecutive-visible steps.<br>
--- Deterministic (farthest-first scan order). O(n^2) LOS calls in the worst case.
---@param line_of_sight fun(a: any, b: any): boolean Predicate returning true when the straight line between `a` and `b` is unobstructed.
---@param path table Array of path nodes from start to goal.
---@param out? table Optional output table to reuse (avoids allocation).
---@return table out Smoothed path (start -> goal).
---@usage <br>
--- ```
--- local function los(a, b) return true end -- always clear
--- local smoothed = astar.smoothing.smooth(los, {1,2,3,4,5})
--- ```
function M.smooth(line_of_sight, path, out)
	local n = #path
	out = out or {}

	if n == 0 then
		return out
	end
	if n <= 2 then
		local old_n = #out
		out[1] = path[1]
		if n == 2 then out[2] = path[2] end
		for i = n + 1, old_n do out[i] = nil end
		return out
	end

	local old_n = #out
	local m = 1
	out[1] = path[1]

	local anchor = 1
	while anchor < n do
		-- Farthest node visible from the anchor (deterministic scan).
		local best = anchor + 1
		for j = n, anchor + 2, -1 do
			if line_of_sight(path[anchor], path[j]) then
				best = j
				break
			end
		end
		m = m + 1
		out[m] = path[best]
		anchor = best
	end

	for i = m + 1, old_n do
		out[i] = nil
	end
	return out
end

-- Export
return M
