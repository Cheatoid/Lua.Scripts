-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Simple object-oriented 3D Axis-Aligned Bounding Box (AABB) struct

-- Features:
-- * Fast numeric storage (aabb.min, aabb.max); no hashing, raw lookup
-- * Convenient field access via min/max properties
-- * Shorthand constructor; AABB(min, max) instead of AABB.new(min, max)
-- * Collision detection, size calculations, and spatial operations

-- Distance Functions:
-- AABB.distance(a, b) - Euclidean distance between AABBs (alias for distance_to_aabb)
-- AABB.distance_squared(a, b) - Squared Euclidean distance between AABBs (faster, avoids sqrt)
-- AABB.distance_to_point(aabb, point) - Euclidean distance to point
-- AABB.distance_to_aabb(aabb1, aabb2) - Euclidean distance between AABBs
-- AABB.distance_manhattan_to_point(aabb, point) - Manhattan distance (L1 norm) to point
-- AABB.distance_manhattan_to_aabb(aabb1, aabb2) - Manhattan distance (L1 norm) between AABBs
-- AABB.distance_chebyshev_to_point(aabb, point) - Chebyshev distance (L∞ norm) to point
-- AABB.distance_chebyshev_to_aabb(aabb1, aabb2) - Chebyshev distance (L∞ norm) between AABBs
-- AABB.distance_minkowski_to_point(aabb, point, p) - Minkowski distance (Lp norm, p >= 1) to point
-- AABB.distance_minkowski_to_aabb(aabb1, aabb2, p) - Minkowski distance (Lp norm, p >= 1) between AABBs
--  - p=1: Manhattan, p=2: Euclidean, p=∞: Chebyshev

-- Localized global functions for better performance
local error, getmetatable, setmetatable, tonumber, tostring, type =
	error, getmetatable, setmetatable, tonumber, tostring, type
local math_abs, math_max, math_min, math_sqrt =
	math.abs, math.max, math.min, math.sqrt
local string_format = string.format

local self = {} -- module
local AABB = {} -- method table

---@class math.aabb
---@field min table {x, y, z} Minimum corner of the box
---@field max table {x, y, z} Maximum corner of the box

--- Create a new AABB from min and max points
---@param min? table Minimum corner {x, y, z}, defaults to {0, 0, 0}
---@param max? table Maximum corner {x, y, z}, defaults to {0, 0, 0}
---@return math.aabb aabb A new AABB object
local function AABB_new(min, max)
	min = min or { x = 0, y = 0, z = 0 }
	max = max or { x = 0, y = 0, z = 0 }

	-- Ensure min and max are valid tables
	if type(min) ~= "table" then
		min = { x = 0, y = 0, z = 0 }
	end
	if type(max) ~= "table" then
		max = { x = 0, y = 0, z = 0 }
	end

	-- Extract values from either x/y/z keys or numeric indices
	local min_x = tonumber(min.x or min[1]) or 0
	local min_y = tonumber(min.y or min[2]) or 0
	local min_z = tonumber(min.z or min[3]) or 0
	local max_x = tonumber(max.x or max[1]) or 0
	local max_y = tonumber(max.y or max[2]) or 0
	local max_z = tonumber(max.z or max[3]) or 0

	-- Ensure min <= max for each component
	if min_x > max_x then min_x, max_x = max_x, min_x end
	if min_y > max_y then min_y, max_y = max_y, min_y end
	if min_z > max_z then min_z, max_z = max_z, min_z end

	return setmetatable({
		min = { x = min_x, y = min_y, z = min_z },
		max = { x = max_x, y = max_y, z = max_z }
	}, AABB)
end

self.new = AABB_new

--- Test whether an object is an AABB (by its metatable)
---@param obj any
---@return boolean
local function is_aabb(obj)
	return getmetatable(obj) == AABB
end

self.is = is_aabb

AABB.__index = AABB

----------------------------------------------------------------------
-- AABB arithmetic metamethods
----------------------------------------------------------------------

--- Addition: aabb + vector (translates the box)
function AABB.__add(a, b)
	if is_aabb(a) and type(b) == "table" then
		local dx = tonumber(b.x or b[1]) or 0
		local dy = tonumber(b.y or b[2]) or 0
		local dz = tonumber(b.z or b[3]) or 0
		return AABB_new(
			{ x = a.min.x + dx, y = a.min.y + dy, z = a.min.z + dz },
			{ x = a.max.x + dx, y = a.max.y + dy, z = a.max.z + dz }
		)
	end
	return error("AABB addition requires an AABB and a vector/table", 2)
end

--- Subtraction: aabb - vector (translates the box)
function AABB.__sub(a, b)
	if is_aabb(a) and type(b) == "table" then
		local dx = tonumber(b.x or b[1]) or 0
		local dy = tonumber(b.y or b[2]) or 0
		local dz = tonumber(b.z or b[3]) or 0
		return AABB_new(
			{ x = a.min.x - dx, y = a.min.y - dy, z = a.min.z - dz },
			{ x = a.max.x - dx, y = a.max.y - dy, z = a.max.z - dz }
		)
	end
	return error("AABB subtraction requires an AABB and a vector/table", 2)
end

--- Equality check: a == b
function AABB.__eq(a, b)
	if not is_aabb(a) or not is_aabb(b) then
		return false
	end
	return a.min.x == b.min.x and a.min.y == b.min.y and a.min.z == b.min.z and
		a.max.x == b.max.x and a.max.y == b.max.y and a.max.z == b.max.z
end

--- Readable string representation
function AABB.__tostring(t)
	if not is_aabb(t) then
		return tostring(t)
	end
	return string_format("AABB(min: (%.6g, %.6g, %.6g), max: (%.6g, %.6g, %.6g))",
		t.min.x, t.min.y, t.min.z,
		t.max.x, t.max.y, t.max.z
	)
end

----------------------------------------------------------------------
-- AABB utility functions
----------------------------------------------------------------------

--- Create a shallow copy
---@param t math.aabb
---@return math.aabb
function AABB.clone(t)
	if not is_aabb(t) then
		return error("AABB.clone requires an AABB", 2)
	end
	return AABB_new(
		{ x = t.min.x, y = t.min.y, z = t.min.z },
		{ x = t.max.x, y = t.max.y, z = t.max.z }
	)
end

self.clone = AABB.clone

--- Get width (size along X axis)
---@param t math.aabb
---@return number
function AABB.width(t)
	if not is_aabb(t) then
		return error("AABB.width requires an AABB", 2)
	end
	return t.max.x - t.min.x
end

self.width = AABB.width

--- Get height (size along Y axis)
---@param t math.aabb
---@return number
function AABB.height(t)
	if not is_aabb(t) then
		return error("AABB.height requires an AABB", 2)
	end
	return t.max.y - t.min.y
end

self.height = AABB.height

--- Get depth (size along Z axis)
---@param t math.aabb
---@return number
function AABB.depth(t)
	if not is_aabb(t) then
		return error("AABB.depth requires an AABB", 2)
	end
	return t.max.z - t.min.z
end

self.depth = AABB.depth

--- Get size as a vector {width, height, depth}
---@param t math.aabb
---@return table
function AABB.size(t)
	if not is_aabb(t) then
		return error("AABB.size requires an AABB", 2)
	end
	return {
		x = t.max.x - t.min.x,
		y = t.max.y - t.min.y,
		z = t.max.z - t.min.z
	}
end

self.size = AABB.size

--- Get center point of the AABB
---@param t math.aabb
---@return table
function AABB.center(t)
	if not is_aabb(t) then
		return error("AABB.center requires an AABB", 2)
	end
	return {
		x = (t.min.x + t.max.x) * 0.5,
		y = (t.min.y + t.max.y) * 0.5,
		z = (t.min.z + t.max.z) * 0.5
	}
end

self.center = AABB.center

--- Get volume of the AABB
---@param t math.aabb
---@return number
function AABB.volume(t)
	if not is_aabb(t) then
		return error("AABB.volume requires an AABB", 2)
	end
	return (t.max.x - t.min.x) * (t.max.y - t.min.y) * (t.max.z - t.min.z)
end

self.volume = AABB.volume

--- Get surface area of the AABB
---@param t math.aabb
---@return number
function AABB.surface_area(t)
	if not is_aabb(t) then
		return error("AABB.surface_area requires an AABB", 2)
	end
	local w = t.max.x - t.min.x
	local h = t.max.y - t.min.y
	local d = t.max.z - t.min.z
	return 2 * (w * h + h * d + d * w)
end

self.surface_area = AABB.surface_area

--- Check if point is inside the AABB
---@param t math.aabb
---@param point table Point {x, y, z}
---@return boolean
function AABB.contains_point(t, point)
	if not is_aabb(t) then
		return error("AABB.contains_point requires an AABB", 2)
	end
	if type(point) ~= "table" then
		return false
	end
	local x = tonumber(point.x or point[1]) or 0
	local y = tonumber(point.y or point[2]) or 0
	local z = tonumber(point.z or point[3]) or 0
	return x >= t.min.x and x <= t.max.x and
		y >= t.min.y and y <= t.max.y and
		z >= t.min.z and z <= t.max.z
end

self.contains_point = AABB.contains_point

--- Check if AABB contains another AABB
---@param t math.aabb
---@param other math.aabb
---@return boolean
function AABB.contains(t, other)
	if not is_aabb(t) or not is_aabb(other) then
		return error("AABB.contains requires two AABBs", 2)
	end
	return other.min.x >= t.min.x and other.max.x <= t.max.x and
		other.min.y >= t.min.y and other.max.y <= t.max.y and
		other.min.z >= t.min.z and other.max.z <= t.max.z
end

self.contains = AABB.contains

--- Check if AABB intersects with another AABB
---@param t math.aabb
---@param other math.aabb
---@return boolean
function AABB.intersects(t, other)
	if not is_aabb(t) or not is_aabb(other) then
		return error("AABB.intersects requires two AABBs", 2)
	end
	return t.min.x <= other.max.x and t.max.x >= other.min.x and
		t.min.y <= other.max.y and t.max.y >= other.min.y and
		t.min.z <= other.max.z and t.max.z >= other.min.z
end

self.intersects = AABB.intersects

--- Expand AABB by a given amount on all sides
---@param t math.aabb
---@param amount number Amount to expand
---@return math.aabb
function AABB.expand(t, amount)
	if not is_aabb(t) then
		return error("AABB.expand requires an AABB", 2)
	end
	amount = tonumber(amount) or 0
	return AABB_new(
		{ x = t.min.x - amount, y = t.min.y - amount, z = t.min.z - amount },
		{ x = t.max.x + amount, y = t.max.y + amount, z = t.max.z + amount }
	)
end

self.expand = AABB.expand

--- Expand AABB by different amounts on each axis
---@param t math.aabb
---@param amount_x number Amount to expand on X
---@param amount_y number Amount to expand on Y
---@param amount_z number Amount to expand on Z
---@return math.aabb
function AABB.expand_xyz(t, amount_x, amount_y, amount_z)
	if not is_aabb(t) then
		return error("AABB.expand_xyz requires an AABB", 2)
	end
	amount_x = tonumber(amount_x) or 0
	amount_y = tonumber(amount_y) or 0
	amount_z = tonumber(amount_z) or 0
	return AABB_new(
		{ x = t.min.x - amount_x, y = t.min.y - amount_y, z = t.min.z - amount_z },
		{ x = t.max.x + amount_x, y = t.max.y + amount_y, z = t.max.z + amount_z }
	)
end

self.expand_xyz = AABB.expand_xyz

--- Contract AABB by a given amount on all sides
---@param t math.aabb
---@param amount number Amount to contract
---@return math.aabb
function AABB.contract(t, amount)
	if not is_aabb(t) then
		return error("AABB.contract requires an AABB", 2)
	end
	return AABB.expand(t, -(tonumber(amount) or 0))
end

self.contract = AABB.contract

--- Contract AABB by different amounts on each axis
---@param t math.aabb
---@param amount_x number Amount to contract on X
---@param amount_y number Amount to contract on Y
---@param amount_z number Amount to contract on Z
---@return math.aabb
function AABB.contract_xyz(t, amount_x, amount_y, amount_z)
	if not is_aabb(t) then
		return error("AABB.contract_xyz requires an AABB", 2)
	end
	return AABB.expand_xyz(t, -(tonumber(amount_x) or 0), -(tonumber(amount_y) or 0), -(tonumber(amount_z) or 0))
end

self.contract_xyz = AABB.contract_xyz

--- Get union of two AABBs (smallest AABB containing both)
---@param a math.aabb
---@param b math.aabb
---@return math.aabb
function AABB.union(a, b)
	if not is_aabb(a) or not is_aabb(b) then
		return error("AABB.union requires two AABBs", 2)
	end
	return AABB_new(
		{ x = math_min(a.min.x, b.min.x), y = math_min(a.min.y, b.min.y), z = math_min(a.min.z, b.min.z) },
		{ x = math_max(a.max.x, b.max.x), y = math_max(a.max.y, b.max.y), z = math_max(a.max.z, b.max.z) }
	)
end

self.union = AABB.union

--- Get intersection of two AABBs
---@param a math.aabb
---@param b math.aabb
---@return math.aabb|nil Returns nil if they don't intersect
function AABB.intersection(a, b)
	if not is_aabb(a) or not is_aabb(b) then
		return error("AABB.intersection requires two AABBs", 2)
	end
	if not AABB.intersects(a, b) then
		return nil
	end
	return AABB_new(
		{ x = math_max(a.min.x, b.min.x), y = math_max(a.min.y, b.min.y), z = math_max(a.min.z, b.min.z) },
		{ x = math_min(a.max.x, b.max.x), y = math_min(a.max.y, b.max.y), z = math_min(a.max.z, b.max.z) }
	)
end

self.intersection = AABB.intersection

--- Get all 8 corners of the AABB
---@param t math.aabb
---@return table array Array of 8 corner points
function AABB.corners(t)
	if not is_aabb(t) then
		return error("AABB.corners requires an AABB", 2)
	end
	return {
		{ x = t.min.x, y = t.min.y, z = t.min.z }, -- 0: min, min, min
		{ x = t.max.x, y = t.min.y, z = t.min.z }, -- 1: max, min, min
		{ x = t.min.x, y = t.max.y, z = t.min.z }, -- 2: min, max, min
		{ x = t.max.x, y = t.max.y, z = t.min.z }, -- 3: max, max, min
		{ x = t.min.x, y = t.min.y, z = t.max.z }, -- 4: min, min, max
		{ x = t.max.x, y = t.min.y, z = t.max.z }, -- 5: max, min, max
		{ x = t.min.x, y = t.max.y, z = t.max.z }, -- 6: min, max, max
		{ x = t.max.x, y = t.max.y, z = t.max.z } -- 7: max, max, max
	}
end

self.corners = AABB.corners

--- Convert AABB to table
---@param t math.aabb
---@return table
function AABB.to_table(t)
	if not is_aabb(t) then
		return error("AABB.to_table requires an AABB", 2)
	end
	return {
		min = { x = t.min.x, y = t.min.y, z = t.min.z },
		max = { x = t.max.x, y = t.max.y, z = t.max.z }
	}
end

self.to_table = AABB.to_table

--- Create AABB from table
---@param tbl table Table with min and max keys
---@return math.aabb
function AABB.from_table(tbl)
	if type(tbl) ~= "table" then
		return error("AABB.from_table requires a table", 2)
	end
	return AABB_new(tbl.min, tbl.max)
end

self.from_table = AABB.from_table

--- Encapsulate a point into the AABB (expands to include it)
---@param t math.aabb
---@param point table Point {x, y, z}
---@return math.aabb
function AABB.encapsulate(t, point)
	if not is_aabb(t) then
		return error("AABB.encapsulate requires an AABB", 2)
	end
	if type(point) ~= "table" then
		return AABB.clone(t)
	end
	local x = tonumber(point.x or point[1]) or 0
	local y = tonumber(point.y or point[2]) or 0
	local z = tonumber(point.z or point[3]) or 0
	return AABB_new(
		{ x = math_min(t.min.x, x), y = math_min(t.min.y, y), z = math_min(t.min.z, z) },
		{ x = math_max(t.max.x, x), y = math_max(t.max.y, y), z = math_max(t.max.z, z) }
	)
end

self.encapsulate = AABB.encapsulate

--- Encapsulate another AABB into this AABB (expands to include it)
---@param t math.aabb
---@param other math.aabb
---@return math.aabb
function AABB.encapsulate_aabb(t, other)
	if not is_aabb(t) or not is_aabb(other) then
		return error("AABB.encapsulate_aabb requires two AABBs", 2)
	end
	return AABB_new(
		{ x = math_min(t.min.x, other.min.x), y = math_min(t.min.y, other.min.y), z = math_min(t.min.z, other.min.z) },
		{ x = math_max(t.max.x, other.max.x), y = math_max(t.max.y, other.max.y), z = math_max(t.max.z, other.max.z) }
	)
end

self.encapsulate_aabb = AABB.encapsulate_aabb

--- Get distance from AABB to a point
---@param t math.aabb
---@param point table Point {x, y, z}
---@return number
function AABB.distance_to_point(t, point)
	if not is_aabb(t) then
		return error("AABB.distance_to_point requires an AABB", 2)
	end
	if type(point) ~= "table" then
		return error("AABB.distance_to_point requires a point", 2)
	end
	local x = tonumber(point.x or point[1]) or 0
	local y = tonumber(point.y or point[2]) or 0
	local z = tonumber(point.z or point[3]) or 0

	local dx = 0
	local dy = 0
	local dz = 0

	if x < t.min.x then
		dx = t.min.x - x
	elseif x > t.max.x then
		dx = x - t.max.x
	end

	if y < t.min.y then
		dy = t.min.y - y
	elseif y > t.max.y then
		dy = y - t.max.y
	end

	if z < t.min.z then
		dz = t.min.z - z
	elseif z > t.max.z then
		dz = z - t.max.z
	end

	return math_sqrt(dx * dx + dy * dy + dz * dz)
end

self.distance_to_point = AABB.distance_to_point

--- Get distance from AABB to another AABB
---@param t math.aabb
---@param other math.aabb
---@return number
function AABB.distance_to_aabb(t, other)
	if not is_aabb(t) or not is_aabb(other) then
		return error("AABB.distance_to_aabb requires two AABBs", 2)
	end
	if AABB.intersects(t, other) then
		return 0
	end

	local dx = 0
	local dy = 0
	local dz = 0

	if t.max.x < other.min.x then
		dx = other.min.x - t.max.x
	elseif t.min.x > other.max.x then
		dx = t.min.x - other.max.x
	end

	if t.max.y < other.min.y then
		dy = other.min.y - t.max.y
	elseif t.min.y > other.max.y then
		dy = t.min.y - other.max.y
	end

	if t.max.z < other.min.z then
		dz = other.min.z - t.max.z
	elseif t.min.z > other.max.z then
		dz = t.min.z - other.max.z
	end

	return math_sqrt(dx * dx + dy * dy + dz * dz)
end

self.distance_to_aabb = AABB.distance_to_aabb

--- Distance between two AABBs (alias for distance_to_aabb)
---@param t math.aabb
---@param other math.aabb
---@return number
function AABB.distance(t, other)
	return AABB.distance_to_aabb(t, other)
end

self.distance = AABB.distance

--- Squared distance between two AABBs (faster, avoids sqrt)
---@param t math.aabb
---@param other math.aabb
---@return number
function AABB.distance_squared(t, other)
	if not is_aabb(t) or not is_aabb(other) then
		return error("AABB.distance_squared requires two AABBs", 2)
	end
	if AABB.intersects(t, other) then
		return 0
	end

	local dx = 0
	local dy = 0
	local dz = 0

	if t.max.x < other.min.x then
		dx = other.min.x - t.max.x
	elseif t.min.x > other.max.x then
		dx = t.min.x - other.max.x
	end

	if t.max.y < other.min.y then
		dy = other.min.y - t.max.y
	elseif t.min.y > other.max.y then
		dy = t.min.y - other.max.y
	end

	if t.max.z < other.min.z then
		dz = other.min.z - t.max.z
	elseif t.min.z > other.max.z then
		dz = t.min.z - other.max.z
	end

	return dx * dx + dy * dy + dz * dz
end

self.distance_squared = AABB.distance_squared

--- Manhattan distance (L1 norm) from AABB to a point
---@param t math.aabb
---@param point table Point {x, y, z}
---@return number
function AABB.distance_manhattan_to_point(t, point)
	if not is_aabb(t) then
		return error("AABB.distance_manhattan_to_point requires an AABB", 2)
	end
	if type(point) ~= "table" then
		return error("AABB.distance_manhattan_to_point requires a point", 2)
	end
	local x = tonumber(point.x or point[1]) or 0
	local y = tonumber(point.y or point[2]) or 0
	local z = tonumber(point.z or point[3]) or 0

	local dx = 0
	local dy = 0
	local dz = 0

	if x < t.min.x then
		dx = t.min.x - x
	elseif x > t.max.x then
		dx = x - t.max.x
	end

	if y < t.min.y then
		dy = t.min.y - y
	elseif y > t.max.y then
		dy = y - t.max.y
	end

	if z < t.min.z then
		dz = t.min.z - z
	elseif z > t.max.z then
		dz = z - t.max.z
	end

	return math_abs(dx) + math_abs(dy) + math_abs(dz)
end

self.distance_manhattan_to_point = AABB.distance_manhattan_to_point

--- Manhattan distance (L1 norm) from AABB to another AABB
---@param t math.aabb
---@param other math.aabb
---@return number
function AABB.distance_manhattan_to_aabb(t, other)
	if not is_aabb(t) or not is_aabb(other) then
		return error("AABB.distance_manhattan_to_aabb requires two AABBs", 2)
	end
	if AABB.intersects(t, other) then
		return 0
	end

	local dx = 0
	local dy = 0
	local dz = 0

	if t.max.x < other.min.x then
		dx = other.min.x - t.max.x
	elseif t.min.x > other.max.x then
		dx = t.min.x - other.max.x
	end

	if t.max.y < other.min.y then
		dy = other.min.y - t.max.y
	elseif t.min.y > other.max.y then
		dy = t.min.y - other.max.y
	end

	if t.max.z < other.min.z then
		dz = other.min.z - t.max.z
	elseif t.min.z > other.max.z then
		dz = t.min.z - other.max.z
	end

	return math_abs(dx) + math_abs(dy) + math_abs(dz)
end

self.distance_manhattan_to_aabb = AABB.distance_manhattan_to_aabb

--- Chebyshev distance (L∞ norm) from AABB to a point
---@param t math.aabb
---@param point table Point {x, y, z}
---@return number
function AABB.distance_chebyshev_to_point(t, point)
	if not is_aabb(t) then
		return error("AABB.distance_chebyshev_to_point requires an AABB", 2)
	end
	if type(point) ~= "table" then
		return error("AABB.distance_chebyshev_to_point requires a point", 2)
	end
	local x = tonumber(point.x or point[1]) or 0
	local y = tonumber(point.y or point[2]) or 0
	local z = tonumber(point.z or point[3]) or 0

	local dx = 0
	local dy = 0
	local dz = 0

	if x < t.min.x then
		dx = t.min.x - x
	elseif x > t.max.x then
		dx = x - t.max.x
	end

	if y < t.min.y then
		dy = t.min.y - y
	elseif y > t.max.y then
		dy = y - t.max.y
	end

	if z < t.min.z then
		dz = t.min.z - z
	elseif z > t.max.z then
		dz = z - t.max.z
	end

	return math_max(math_abs(dx), math_max(math_abs(dy), math_abs(dz)))
end

self.distance_chebyshev_to_point = AABB.distance_chebyshev_to_point

--- Chebyshev distance (L∞ norm) from AABB to another AABB
---@param t math.aabb
---@param other math.aabb
---@return number
function AABB.distance_chebyshev_to_aabb(t, other)
	if not is_aabb(t) or not is_aabb(other) then
		return error("AABB.distance_chebyshev_to_aabb requires two AABBs", 2)
	end
	if AABB.intersects(t, other) then
		return 0
	end

	local dx = 0
	local dy = 0
	local dz = 0

	if t.max.x < other.min.x then
		dx = other.min.x - t.max.x
	elseif t.min.x > other.max.x then
		dx = t.min.x - other.max.x
	end

	if t.max.y < other.min.y then
		dy = other.min.y - t.max.y
	elseif t.min.y > other.max.y then
		dy = t.min.y - other.max.y
	end

	if t.max.z < other.min.z then
		dz = other.min.z - t.max.z
	elseif t.min.z > other.max.z then
		dz = t.min.z - other.max.z
	end

	return math_max(math_abs(dx), math_max(math_abs(dy), math_abs(dz)))
end

self.distance_chebyshev_to_aabb = AABB.distance_chebyshev_to_aabb

--- Minkowski distance (Lp norm) from AABB to a point
---@param t math.aabb
---@param point table Point {x, y, z}
---@param p number Order parameter (p >= 1), defaults to 2 (Euclidean)
---@return number
function AABB.distance_minkowski_to_point(t, point, p)
	if not is_aabb(t) then
		return error("AABB.distance_minkowski_to_point requires an AABB", 2)
	end
	if type(point) ~= "table" then
		return error("AABB.distance_minkowski_to_point requires a point", 2)
	end
	p = tonumber(p) or 2
	if p < 1 then
		return error("Minkowski distance requires p >= 1", 2)
	end

	local x = tonumber(point.x or point[1]) or 0
	local y = tonumber(point.y or point[2]) or 0
	local z = tonumber(point.z or point[3]) or 0

	local dx = 0
	local dy = 0
	local dz = 0

	if x < t.min.x then
		dx = t.min.x - x
	elseif x > t.max.x then
		dx = x - t.max.x
	end

	if y < t.min.y then
		dy = t.min.y - y
	elseif y > t.max.y then
		dy = y - t.max.y
	end

	if z < t.min.z then
		dz = t.min.z - z
	elseif z > t.max.z then
		dz = z - t.max.z
	end

	dx = math_abs(dx)
	dy = math_abs(dy)
	dz = math_abs(dz)

	if p == 1 then
		return dx + dy + dz                     -- Manhattan
	elseif p == 2 then
		return math_sqrt(dx * dx + dy * dy + dz * dz) -- Euclidean
	elseif p == math.huge or p == 1 / 0 then
		return math_max(dx, math_max(dy, dz))   -- Chebyshev
	else
		return (dx ^ p + dy ^ p + dz ^ p) ^ (1 / p)
	end
end

self.distance_minkowski_to_point = AABB.distance_minkowski_to_point

--- Minkowski distance (Lp norm) from AABB to another AABB
---@param t math.aabb
---@param other math.aabb
---@param p number Order parameter (p >= 1), defaults to 2 (Euclidean)
---@return number
function AABB.distance_minkowski_to_aabb(t, other, p)
	if not is_aabb(t) or not is_aabb(other) then
		return error("AABB.distance_minkowski_to_aabb requires two AABBs", 2)
	end
	p = tonumber(p) or 2
	if p < 1 then
		return error("Minkowski distance requires p >= 1", 2)
	end
	if AABB.intersects(t, other) then
		return 0
	end

	local dx = 0
	local dy = 0
	local dz = 0

	if t.max.x < other.min.x then
		dx = other.min.x - t.max.x
	elseif t.min.x > other.max.x then
		dx = t.min.x - other.max.x
	end

	if t.max.y < other.min.y then
		dy = other.min.y - t.max.y
	elseif t.min.y > other.max.y then
		dy = t.min.y - other.max.y
	end

	if t.max.z < other.min.z then
		dz = other.min.z - t.max.z
	elseif t.min.z > other.max.z then
		dz = t.min.z - other.max.z
	end

	dx = math_abs(dx)
	dy = math_abs(dy)
	dz = math_abs(dz)

	if p == 1 then
		return dx + dy + dz                     -- Manhattan
	elseif p == 2 then
		return math_sqrt(dx * dx + dy * dy + dz * dz) -- Euclidean
	elseif p == math.huge or p == 1 / 0 then
		return math_max(dx, math_max(dy, dz))   -- Chebyshev
	else
		return (dx ^ p + dy ^ p + dz ^ p) ^ (1 / p)
	end
end

self.distance_minkowski_to_aabb = AABB.distance_minkowski_to_aabb

--- Check if AABB is empty (has zero or negative volume)
---@param t math.aabb
---@return boolean
function AABB.is_empty(t)
	if not is_aabb(t) then
		return error("AABB.is_empty requires an AABB", 2)
	end
	return t.min.x >= t.max.x or t.min.y >= t.max.y or t.min.z >= t.max.z
end

self.is_empty = AABB.is_empty

--- Check if two AABBs are approximately equal (within epsilon)
---@param a math.aabb
---@param b math.aabb
---@param epsilon? number Optional epsilon, defaults to 1e-6
---@return boolean
function AABB.is_near(a, b, epsilon)
	if not is_aabb(a) or not is_aabb(b) then
		return error("AABB.is_near requires two AABBs", 2)
	end
	epsilon = epsilon or 1e-6
	return math_abs(a.min.x - b.min.x) < epsilon and
		math_abs(a.min.y - b.min.y) < epsilon and
		math_abs(a.min.z - b.min.z) < epsilon and
		math_abs(a.max.x - b.max.x) < epsilon and
		math_abs(a.max.y - b.max.y) < epsilon and
		math_abs(a.max.z - b.max.z) < epsilon
end

self.is_near = AABB.is_near

-- Export
return setmetatable(self, {
	__call = function(_, ...)
		return AABB_new(...)
	end
})
