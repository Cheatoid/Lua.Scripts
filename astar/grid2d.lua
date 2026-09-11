-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Optimized 2D grid adapter. The returned object IS a valid AStar.new()
-- configuration (it exposes `neighbors_buffer`, `heuristic` and `walkable`
-- as pre-bound plain functions), so usage is simply:
--
--     local astar = require "astar/init"
--     local grid  = astar.Grid2D.new({ width = 64, height = 64 })
--     local pf    = astar.new(grid)
--
-- Node representation: integer ids, row-major, 1-based:
--
--     id = x + width * (y - 1)        -- x in [1..width], y in [1..height]
--
-- This avoids allocating coordinate tables in the hot path entirely:
-- neighbor ids are computed with integer arithmetic and bounds are checked
-- from a single (x, y) decode per expansion.
--
-- Traversal model:
--   * `blocked[id] = true`            -> impassable
--   * `terrain[id] <= 0`              -> impassable
--   * straight move cost              -> terrain[id] or 1
--   * diagonal move cost (8-conn)     -> sqrt(2) * terrain[id] or 1
--   * corner cutting is forbidden by default (a diagonal move requires both
--     adjacent orthogonal cells to be passable); enable with
--     `allow_corner_cutting = true`.
--
-- The default heuristic matches the connectivity: manhattan (4-conn) or
-- octile (8-conn) - both admissible and consistent for the cost model above
-- whenever terrain costs are >= 1.

-- Localized global functions for better performance
local math_floor = math.floor
local math_sqrt = math.sqrt
local setmetatable = setmetatable
local type = type
local error = error

local SQRT2 = math_sqrt(2)
local SQRT2M1 = SQRT2 - 1

--- 2D grid adapter that doubles as a valid AStar.new() configuration.<br>
--- Exposes `neighbors_buffer`, `heuristic`, and `walkable` as pre-bound plain functions.<br>
--- Node ids are row-major integers: `id = x + width * (y - 1)`.
---@class astar.Grid2D
---@field width integer Grid width in columns.
---@field height integer Grid height in rows.
---@field count integer Total number of cells (`width * height`).
---@field diagonal boolean 8-connectivity when true, 4-connectivity when false.
---@field allow_corner_cutting boolean Allow diagonal moves past blocked corners.
---@field blocked table Set of impassable cell ids: `blocked[id] = true`.
---@field terrain table Cost per cell id: `terrain[id] = cost`; `<= 0` means impassable.
---@field heuristic function Heuristic function bound to this grid's geometry.
---@field walkable function Passability predicate.
---@field passable function Internal passability predicate (also exposed for convenience).
local Grid2D = {}
Grid2D.__index = Grid2D

--- Configuration options for `Grid2D.new`.<br>
--- All dimensions must be positive integers.
---@class astar.Grid2DOptions
---@field width integer Required: grid width in columns.
---@field height integer Required: grid height in rows.
---@field diagonal? boolean 8-connectivity when true (default: false).
---@field allow_corner_cutting? boolean Allow diagonal moves past blocked corners (default: false).
---@field blocked? table Optional set of impassable ids: `{ [id] = true, ... }`.
---@field terrain? table Optional cost table: `{ [id] = cost, ... }`.

--- Create a new Grid2D instance.<br>
--- The returned object is a valid `AStar.new(cfg)` input.
---@param opts? table Configuration options (see `astar.Grid2DOptions`).
---@return astar.Grid2D grid Configured grid instance.
---@usage <br>
--- ```
--- local grid = astar.Grid2D.new({ width = 64, height = 64, diagonal = true })
--- local pf = astar.new(grid)
--- local path = pf:find(1, 4096)
--- ```
function Grid2D.new(opts)
	opts = opts or {}
	local w = opts.width
	local h = opts.height
	if type(w) ~= "number" or w < 1 or math_floor(w) ~= w then
		return error("astar.grid2d: opts.width must be a positive integer", 2)
	end
	if type(h) ~= "number" or h < 1 or math_floor(h) ~= h then
		return error("astar.grid2d: opts.height must be a positive integer", 2)
	end

	local diagonal = opts.diagonal == true
	local cut_ok = opts.allow_corner_cutting == true

	local self = {
		width = w,
		height = h,
		count = w * h,
		diagonal = diagonal,
		allow_corner_cutting = cut_ok,
		blocked = opts.blocked or {}, -- set of ids
		terrain = opts.terrain or {}, -- cost per id (default 1)
	}

	local B = self.blocked
	local T = self.terrain

	-- Shared passability predicate (used by walkable and corner checks).
	local function passable(id)
		local t = T[id]
		if t and t <= 0 then return false end
		return not B[id]
	end
	self.passable = passable

	local W = w
	local H = h

	if not diagonal then
		------------------------------------------------------------------
		-- 4-connectivity: fully unrolled, zero allocations.
		------------------------------------------------------------------
		self.neighbors_buffer = function(node, nbuf, cbuf)
			local n = 0
			local m = node - 1
			local x0 = m % W -- 0-based column
			local y0 = (m - x0) / W -- 0-based row (exact integer math)

			-- left
			if x0 > 0 then
				local nb = node - 1
				local c = T[nb] or 1
				if c > 0 and not B[nb] then
					n = n + 1
					nbuf[n] = nb
					cbuf[n] = c
				end
			end
			-- right
			if x0 < W - 1 then
				local nb = node + 1
				local c = T[nb] or 1
				if c > 0 and not B[nb] then
					n = n + 1
					nbuf[n] = nb
					cbuf[n] = c
				end
			end
			-- up
			if y0 > 0 then
				local nb = node - W
				local c = T[nb] or 1
				if c > 0 and not B[nb] then
					n = n + 1
					nbuf[n] = nb
					cbuf[n] = c
				end
			end
			-- down
			if y0 < H - 1 then
				local nb = node + W
				local c = T[nb] or 1
				if c > 0 and not B[nb] then
					n = n + 1
					nbuf[n] = nb
					cbuf[n] = c
				end
			end
			return n
		end
	else
		------------------------------------------------------------------
		-- 8-connectivity: unrolled with (optional) corner checks.
		-- Diagonal cost = sqrt(2) * terrain of the destination cell.
		------------------------------------------------------------------
		self.neighbors_buffer = function(node, nbuf, cbuf)
			local n = 0
			local m = node - 1
			local x0 = m % W
			local y0 = (m - x0) / W

			-- left
			if x0 > 0 then
				local nb = node - 1
				local c = T[nb] or 1
				if c > 0 and not B[nb] then
					n = n + 1
					nbuf[n] = nb
					cbuf[n] = c
				end
			end
			-- right
			if x0 < W - 1 then
				local nb = node + 1
				local c = T[nb] or 1
				if c > 0 and not B[nb] then
					n = n + 1
					nbuf[n] = nb
					cbuf[n] = c
				end
			end
			-- up
			if y0 > 0 then
				local nb = node - W
				local c = T[nb] or 1
				if c > 0 and not B[nb] then
					n = n + 1
					nbuf[n] = nb
					cbuf[n] = c
				end
			end
			-- down
			if y0 < H - 1 then
				local nb = node + W
				local c = T[nb] or 1
				if c > 0 and not B[nb] then
					n = n + 1
					nbuf[n] = nb
					cbuf[n] = c
				end
			end

			if cut_ok then
				-- up-left
				if x0 > 0 and y0 > 0 then
					local nb = node - W - 1
					local c = T[nb] or 1
					if c > 0 and not B[nb] then
						n = n + 1
						nbuf[n] = nb
						cbuf[n] = c * SQRT2
					end
				end
				-- up-right
				if x0 < W - 1 and y0 > 0 then
					local nb = node - W + 1
					local c = T[nb] or 1
					if c > 0 and not B[nb] then
						n = n + 1
						nbuf[n] = nb
						cbuf[n] = c * SQRT2
					end
				end
				-- down-left
				if x0 > 0 and y0 < H - 1 then
					local nb = node + W - 1
					local c = T[nb] or 1
					if c > 0 and not B[nb] then
						n = n + 1
						nbuf[n] = nb
						cbuf[n] = c * SQRT2
					end
				end
				-- down-right
				if x0 < W - 1 and y0 < H - 1 then
					local nb = node + W + 1
					local c = T[nb] or 1
					if c > 0 and not B[nb] then
						n = n + 1
						nbuf[n] = nb
						cbuf[n] = c * SQRT2
					end
				end
			else
				-- No corner cutting: both orthogonal cells of a diagonal
				-- must be passable.
				local can_l = x0 > 0
				local can_r = x0 < W - 1
				local can_u = y0 > 0
				local can_d = y0 < H - 1

				if can_u and can_l and passable(node - 1) and passable(node - W) then
					local nb = node - W - 1
					local c = T[nb] or 1
					if c > 0 and not B[nb] then
						n = n + 1
						nbuf[n] = nb
						cbuf[n] = c * SQRT2
					end
				end
				if can_u and can_r and passable(node + 1) and passable(node - W) then
					local nb = node - W + 1
					local c = T[nb] or 1
					if c > 0 and not B[nb] then
						n = n + 1
						nbuf[n] = nb
						cbuf[n] = c * SQRT2
					end
				end
				if can_d and can_l and passable(node - 1) and passable(node + W) then
					local nb = node + W - 1
					local c = T[nb] or 1
					if c > 0 and not B[nb] then
						n = n + 1
						nbuf[n] = nb
						cbuf[n] = c * SQRT2
					end
				end
				if can_d and can_r and passable(node + 1) and passable(node + W) then
					local nb = node + W + 1
					local c = T[nb] or 1
					if c > 0 and not B[nb] then
						n = n + 1
						nbuf[n] = nb
						cbuf[n] = c * SQRT2
					end
				end
			end
			return n
		end
	end

	-- Default heuristic bound to this grid's geometry.
	self.heuristic = Grid2D.make_heuristic(w, diagonal)

	self.walkable = function(id)
		return passable(id)
	end

	return setmetatable(self, Grid2D)
end

--- Build a heuristic function for row-major integer ids.<br>
--- 4-connectivity -> manhattan, 8-connectivity -> octile.<br>
--- Exposed for custom grid implementations.
---@param w integer Grid width in columns.
---@param diagonal boolean True for 8-connectivity (octile), false for 4-connectivity (manhattan).
---@return function h Heuristic function `h(a, b) -> number` for integer grid ids.
---@usage <br>
--- ```
--- local h = astar.Grid2D.make_heuristic(64, true) -- 8-conn
--- print(h(1, 64)) -- 63
--- ```
function Grid2D.make_heuristic(w, diagonal)
	if diagonal then
		return function(a, b)
			local ax = (a - 1) % w
			local bx = (b - 1) % w
			local dx = ax - bx
			if dx < 0 then dx = -dx end
			local dy = ((a - 1 - ax) - (b - 1 - bx)) / w
			if dy < 0 then dy = -dy end
			if dx < dy then dx, dy = dy, dx end -- dx = max, dy = min
			return dx + SQRT2M1 * dy
		end
	end
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

----------------------------------------------------------------------
-- Coordinate helpers (methods, not hot-path fields)
----------------------------------------------------------------------

--- Compute the row-major integer id for (x, y).<br>
--- `id = x + width * (y - 1)`.<br>
--- Both x and y are 1-based.
---@param self astar.Grid2D The grid instance.
---@param x integer Column (1-based).
---@param y integer Row (1-based).
---@return integer id Row-major cell id.
function Grid2D:id(x, y)
	return x + self.width * (y - 1)
end

--- Return x, y (both 1-based) for a node id.<br>
--- Inverse of `Grid2D:id(x, y)`.
---@param self astar.Grid2D The grid instance.
---@param id integer Row-major cell id.
---@return integer x Column (1-based).
---@return integer y Row (1-based).
function Grid2D:coords(id)
	local m = id - 1
	local x0 = m % self.width
	return x0 + 1, (m - x0) / self.width + 1
end

--- Check whether (x, y) is within grid bounds.<br>
--- Both coordinates are 1-based.
---@param self astar.Grid2D The grid instance.
---@param x integer Column (1-based).
---@param y integer Row (1-based).
---@return boolean inside `true` when inside the grid.
function Grid2D:in_bounds(x, y)
	return x >= 1 and x <= self.width and y >= 1 and y <= self.height
end

--- Mark a cell as impassable.<br>
--- Alias for `grid.blocked[grid:id(x, y)] = true`.
---@param self astar.Grid2D The grid instance.
---@param x integer Column (1-based).
---@param y integer Row (1-based).
function Grid2D:block(x, y)
	self.blocked[self:id(x, y)] = true
end

--- Unmark a cell (make it passable again).<br>
--- Alias for `grid.blocked[grid:id(x, y)] = nil`.
---@param self astar.Grid2D The grid instance.
---@param x integer Column (1-based).
---@param y integer Row (1-based).
function Grid2D:unblock(x, y)
	self.blocked[self:id(x, y)] = nil
end

--- Set terrain cost for a cell.<br>
--- A cost <= 0 makes the cell impassable.
---@param self astar.Grid2D The grid instance.
---@param x integer Column (1-based).
---@param y integer Row (1-based).
---@param cost number Edge cost for this cell; <= 0 means impassable.
function Grid2D:set_terrain(x, y, cost)
	self.terrain[self:id(x, y)] = cost
end

--- Get the terrain cost for a cell.<br>
--- Returns nil when no cost has been set (defaults to 1 in the neighbor loop).
---@param self astar.Grid2D The grid instance.
---@param x integer Column (1-based).
---@param y integer Row (1-based).
---@return number? cost Terrain cost, or nil if unset.
function Grid2D:terrain_at(x, y)
	return self.terrain[self:id(x, y)]
end

--- Validate that every step in `path` is grid-adjacent and respects corner-cutting rules.<br>
--- Debug/test helper; not used by the search core.
---@param self astar.Grid2D The grid instance.
---@param path table Array of integer node ids.
---@return boolean ok `true` when the path is valid.
---@return string? err Human-readable reason when invalid.
---@usage <br>
--- ```
--- local ok, err = grid:validate_path(pf:find(1, 64))
--- ```
function Grid2D:validate_path(path)
	local n = #path
	if n == 0 then return false, "empty path" end
	local w = self.width
	for i = 2, n do
		local a, b = path[i - 1], path[i]
		local d = b - a
		local dx, dy
		if d == 1 then
			dx, dy = 1, 0
		elseif d == -1 then
			dx, dy = -1, 0
		elseif d == w then
			dx, dy = 0, 1
		elseif d == -w then
			dx, dy = 0, -1
		elseif self.diagonal then
			if d == w + 1 then
				dx, dy = 1, 1
			elseif d == w - 1 then
				dx, dy = 1, -1
			elseif d == -w + 1 then
				dx, dy = -1, 1
			elseif d == -w - 1 then
				dx, dy = -1, -1
			else
				return false, "non-adjacent step at index " .. i
			end
			if not self.allow_corner_cutting then
				local ax, ay = self:coords(a)
				if not self:passable(self:id(ax + dx, ay)) or
					not self:passable(self:id(ax, ay + dy)) then
					return false, "corner cut at index " .. i
				end
			end
		else
			return false, "non-adjacent step at index " .. i
		end
		if not self:passable(b) then
			return false, "path enters blocked cell at index " .. i
		end
	end
	return true
end

-- Export
return Grid2D
