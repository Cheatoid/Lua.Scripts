-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Optimized 3D voxel grid adapter (same contract as grid2d.lua: the instance
-- doubles as an AStar.new() configuration).
--
-- Node representation: integer ids, row-major over (x, y, z), 1-based:
--
--     id = x + width * (y - 1) + width * height * (z - 1)
--
-- Traversal model:
--   * `blocked[id] = true` -> impassable; `terrain[id] <= 0` -> impassable
--   * straight move cost  -> terrain[id] or 1
--   * face diagonal (2D step)     -> sqrt(2) * terrain
--   * space diagonal (3D step)    -> sqrt(3) * terrain
--   * connectivity: 6 (default, face moves) or 26 (all neighbors; every step
--     costs its euclidean length, which keeps the default euclidean heuristic
--     consistent).
--
-- Note: grid3d uses a precomputed direction table instead of full unrolling
-- (26 directions would be unwieldy); grid2d.lua is the fully unrolled hot
-- path for planar movement.

-- Localized global functions for better performance
local math_floor = math.floor
local math_sqrt = math.sqrt
local setmetatable = setmetatable
local type = type
local error = error

local SQRT2 = math_sqrt(2)
local SQRT3 = math_sqrt(3)

--- 3D voxel grid adapter that doubles as a valid AStar.new() configuration.<br>
--- Exposes `neighbors_buffer`, `heuristic`, and `walkable` as pre-bound plain functions.<br>
--- Node ids are row-major integers: `id = x + width * (y - 1) + width * height * (z - 1)`.
---@class astar.Grid3D
---@field width integer Grid width in columns.
---@field height integer Grid height in rows.
---@field depth integer Grid depth in layers.
---@field count integer Total number of cells (`width * height * depth`).
---@field diagonal boolean 26-connectivity when true, 6-connectivity when false.
---@field blocked table Set of impassable cell ids: `blocked[id] = true`.
---@field terrain table Cost per cell id: `terrain[id] = cost`; `<= 0` means impassable.
---@field heuristic function Heuristic function bound to this grid's geometry.
---@field walkable function Passability predicate.
---@field passable function Internal passability predicate (also exposed for convenience).
local Grid3D = {}
Grid3D.__index = Grid3D

--- Configuration options for `Grid3D.new`.<br>
--- All dimensions must be positive integers.
---@class astar.Grid3DOptions
---@field width integer Required: grid width in columns.
---@field height integer Required: grid height in rows.
---@field depth integer Required: grid depth in layers.
---@field diagonal? boolean 26-connectivity when true (default: false = 6-conn).
---@field blocked? table Optional set of impassable ids: `{ [id] = true, ... }`.
---@field terrain? table Optional cost table: `{ [id] = cost, ... }`.

--- Create a new Grid3D instance.<br>
--- The returned object is a valid `AStar.new(cfg)` input.
---@param opts? table Configuration options (see `astar.Grid3DOptions`).
---@return astar.Grid3D grid Configured grid instance.
---@usage <br>
--- ```
--- local grid = astar.Grid3D.new({ width = 8, height = 8, depth = 8, diagonal = true })
--- local pf = astar.new(grid)
--- ```
function Grid3D.new(opts)
	opts = opts or {}
	local w = opts.width
	local h = opts.height
	local d = opts.depth
	if type(w) ~= "number" or w < 1 or math_floor(w) ~= w then
		return error("astar.grid3d: opts.width must be a positive integer", 2)
	end
	if type(h) ~= "number" or h < 1 or math_floor(h) ~= h then
		return error("astar.grid3d: opts.height must be a positive integer", 2)
	end
	if type(d) ~= "number" or d < 1 or math_floor(d) ~= d then
		return error("astar.grid3d: opts.depth must be a positive integer", 2)
	end

	local diagonal = opts.diagonal == true

	local self = {
		width = w,
		height = h,
		depth = d,
		count = w * h * d,
		diagonal = diagonal,
		blocked = opts.blocked or {},
		terrain = opts.terrain or {},
	}

	local B = self.blocked
	local T = self.terrain
	local wh = w * h

	local function passable(id)
		local t = T[id]
		if t and t <= 0 then return false end
		return not B[id]
	end
	self.passable = passable

	-- Precompute the direction table: { offset, cost, dx, dy, dz }.
	local DIR_COST = { [1] = 1, [2] = SQRT2, [3] = SQRT3 }
	local dirs = {}
	local ndirs = 0
	for dz = -1, 1 do
		for dy = -1, 1 do
			for dx = -1, 1 do
				local steps = (dx ~= 0 and 1 or 0) + (dy ~= 0 and 1 or 0) + (dz ~= 0 and 1 or 0)
				if steps > 0 and (diagonal or steps == 1) then
					ndirs = ndirs + 1
					dirs[ndirs] = {
						off = dx + w * dy + wh * dz,
						cost = DIR_COST[steps],
						dx = dx,
						dy = dy,
						dz = dz,
					}
				end
			end
		end
	end

	local W, H, D = w, h, d
	local NDIRS = ndirs

	self.neighbors_buffer = function(node, nbuf, cbuf)
		local n = 0
		local m = node - 1
		local x0 = m % W  -- 0-based
		local t = (m - x0) / W -- t = y0 + H * z0 (exact)
		local y0 = t % H
		local z0 = (t - y0) / H -- exact integer division

		for i = 1, NDIRS do
			local dir = dirs[i]
			local dx, dy, dz = dir.dx, dir.dy, dir.dz
			-- Per-axis bounds check.
			if (dx >= 0 or x0 > 0) and (dx <= 0 or x0 < W - 1)
			and (dy >= 0 or y0 > 0) and (dy <= 0 or y0 < H - 1)
			and (dz >= 0 or z0 > 0) and (dz <= 0 or z0 < D - 1) then
				local nb = node + dir.off
				local c = T[nb] or 1
				if c > 0 and not B[nb] then
					n = n + 1
					nbuf[n] = nb
					cbuf[n] = c * dir.cost
				end
			end
		end
		return n
	end

	-- Default heuristic: manhattan (6-conn) or euclidean (26-conn, consistent
	-- with per-step euclidean move costs).
	if diagonal then
		self.heuristic = function(a, b)
			local ma = a - 1
			local mb = b - 1
			local ax = ma % W
			local bx = mb % W
			local dx = ax - bx
			if dx < 0 then dx = -dx end
			local ta = (ma - ax) / W
			local tb = (mb - bx) / W
			local ay = ta % H
			local by = tb % H
			local dy = ay - by
			if dy < 0 then dy = -dy end
			local dz = (ta - ay) / H - (tb - by) / H
			if dz < 0 then dz = -dz end
			return math_sqrt(dx * dx + dy * dy + dz * dz)
		end
	else
		self.heuristic = function(a, b)
			local ma = a - 1
			local mb = b - 1
			local ax = ma % W
			local bx = mb % W
			local dx = ax - bx
			if dx < 0 then dx = -dx end
			local ta = (ma - ax) / W
			local tb = (mb - bx) / W
			local ay = ta % H
			local by = tb % H
			local dy = ay - by
			if dy < 0 then dy = -dy end
			local dz = (ta - ay) / H - (tb - by) / H
			if dz < 0 then dz = -dz end
			return dx + dy + dz
		end
	end

	self.walkable = function(id)
		return passable(id)
	end

	return setmetatable(self, Grid3D)
end

----------------------------------------------------------------------
-- Coordinate helpers
----------------------------------------------------------------------

--- Compute the row-major integer id for (x, y, z).<br>
--- `id = x + width * (y - 1) + width * height * (z - 1)`.<br>
--- All coordinates are 1-based.
---@param self astar.Grid3D The grid instance.
---@param x integer Column (1-based).
---@param y integer Row (1-based).
---@param z integer Layer (1-based).
---@return integer id Row-major cell id.
function Grid3D:id(x, y, z)
	return x + self.width * (y - 1) + self.width * self.height * (z - 1)
end

--- Return x, y, z (all 1-based) for a node id.<br>
--- Inverse of `Grid3D:id(x, y, z)`.
---@param self astar.Grid3D The grid instance.
---@param id integer Row-major cell id.
---@return integer x Column (1-based).
---@return integer y Row (1-based).
---@return integer z Layer (1-based).
function Grid3D:coords(id)
	local m = id - 1
	local x0 = m % self.width
	local t = (m - x0) / self.width -- t = y0 + H * z0
	local y0 = t % self.height
	local z0 = (t - y0) / self.height
	return x0 + 1, y0 + 1, z0 + 1
end

--- Check whether (x, y, z) is within grid bounds.<br>
--- All coordinates are 1-based.
---@param self astar.Grid3D The grid instance.
---@param x integer Column (1-based).
---@param y integer Row (1-based).
---@param z integer Layer (1-based).
---@return boolean inside `true` when inside the grid.
function Grid3D:in_bounds(x, y, z)
	return x >= 1 and x <= self.width
	  and y >= 1 and y <= self.height
	  and z >= 1 and z <= self.depth
end

--- Mark a cell as impassable.<br>
--- Alias for `grid.blocked[grid:id(x, y, z)] = true`.
---@param self astar.Grid3D The grid instance.
---@param x integer Column (1-based).
---@param y integer Row (1-based).
---@param z integer Layer (1-based).
function Grid3D:block(x, y, z)
	self.blocked[self:id(x, y, z)] = true
end

--- Unmark a cell (make it passable again).<br>
--- Alias for `grid.blocked[grid:id(x, y, z)] = nil`.
---@param self astar.Grid3D The grid instance.
---@param x integer Column (1-based).
---@param y integer Row (1-based).
---@param z integer Layer (1-based).
function Grid3D:unblock(x, y, z)
	self.blocked[self:id(x, y, z)] = nil
end

--- Set terrain cost for a cell.<br>
--- A cost <= 0 makes the cell impassable.
---@param self astar.Grid3D The grid instance.
---@param x integer Column (1-based).
---@param y integer Row (1-based).
---@param z integer Layer (1-based).
---@param cost number Edge cost for this cell; <= 0 means impassable.
function Grid3D:set_terrain(x, y, z, cost)
	self.terrain[self:id(x, y, z)] = cost
end

-- Export
return Grid3D
