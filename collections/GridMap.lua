-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Localized global functions for better performance
local setmetatable = setmetatable
local math_floor = math.floor
local string_format = string.format

--- Define the GridMap class.<br>
--- A fixed-size 2D grid that maps (x, y) coordinates to values.<br>
--- Perfect for tile-based maps, game boards, spatial data, or any grid-based computation where you need efficient positional access.
---@class GridMap
---@field [1] table Flat table storing grid values indexed by computed key
---@field [2] integer Current number of cells with non-nil values
---@field [3] integer Width of the grid (number of columns)
---@field [4] integer Height of the grid (number of rows)
---@field [5] any Default value for unset cells
local GridMap = {}
GridMap.__index = GridMap

--- Create a new GridMap instance with fixed dimensions.<br>
--- Coordinates are 1-based: x ranges from 1 to width, y ranges from 1 to height.
---@param width integer Width of the grid (number of columns).
---@param height integer Height of the grid (number of rows).
---@param default? any Default value for unset cells (default: nil).
---@return GridMap map New GridMap instance.
---@usage <br>
--- ```
--- local grid = GridMap.new(3, 3)
--- grid:set(1, 1, "A")
--- grid:set(3, 2, "B")
--- print(grid:get(1, 1)) -- "A"
--- ```
function GridMap.new(width, height, default)
	return setmetatable({
		{},
		0,
		width,
		height,
		default
	}, GridMap)
end

GridMap.__call = GridMap.new

--- Get the number of set cells using `#` operator.<br>
--- Allows using `#grid` instead of `grid:count()`.
---@param self GridMap The grid instance.
---@return integer count Number of cells with non-nil values in the grid.
---@usage <br>
--- ```
--- local grid = GridMap.new(3, 3)
--- grid:set(1, 1, "A")
--- grid:set(2, 2, "B")
--- print(#grid) -- 2
--- ```
function GridMap.__len(self)
	return self[2]
end

--- Iterate over grid cells using `pairs()`.<br>
--- Yields index, x, y, value for each cell with a non-nil value.
---@param self GridMap The grid instance.
---@return function iterator Iterator that yields index, x, y, value.
---@usage <br>
--- ```
--- local grid = GridMap.new(3, 3)
--- grid:set(1, 1, "A")
--- grid:set(2, 3, "B")
--- for i, x, y, value in pairs(grid) do
---   print(i, x, y, value)
--- end
--- ```
function GridMap.__pairs(self)
	return GridMap.iterator(self)
end

--- Iterate over grid cells using `ipairs()`.<br>
--- Same as `pairs()` for GridMap.
---@param self GridMap The grid instance.
---@return function iterator Iterator that yields index, x, y, value.
function GridMap.__ipairs(self)
	return GridMap.iterator(self)
end

--- Get string representation of the grid.<br>
--- Returns a string showing width, height, and count.
---@param self GridMap The grid instance.
---@return string string String representation of the grid.
---@usage <br>
--- ```
--- local grid = GridMap.new(3, 3)
--- grid:set(1, 1, "A")
--- print(tostring(grid)) -- "GridMap(3x3, count=1)"
--- ```
function GridMap.__tostring(self)
	return string_format("GridMap(%dx%d, count=%d)", self[3], self[4], self[2])
end

--- Check if coordinates are within grid bounds.<br>
--- Coordinates are 1-based.
---@param self GridMap The grid instance.
---@param x integer The x coordinate (column).
---@param y integer The y coordinate (row).
---@return boolean inBounds True if the coordinates are within bounds.
---@usage <br>
--- ```
--- local grid = GridMap.new(3, 3)
--- print(grid:inBounds(1, 1)) -- true
--- print(grid:inBounds(4, 1)) -- false
--- ```
function GridMap.inBounds(self, x, y)
	return x >= 1 and x <= self[3] and y >= 1 and y <= self[4]
end

--- Set a value at the given coordinates.<br>
--- If the cell already has a value, it will be overwritten.<br>
--- Coordinates outside the grid bounds are silently ignored.
---@param self GridMap The grid instance.
---@param x integer The x coordinate (column).
---@param y integer The y coordinate (row).
---@param value any The value to set.
---@usage <br>
--- ```
--- local grid = GridMap.new(3, 3)
--- grid:set(1, 1, "A")
--- grid:set(2, 2, "B")
--- ```
function GridMap.set(self, x, y, value)
	if not GridMap.inBounds(self, x, y) then
		return
	end
	local key = (y - 1) * self[3] + x
	local data = self[1]
	if data[key] == nil and value ~= nil then
		self[2] = self[2] + 1
	elseif data[key] ~= nil and value == nil then
		self[2] = self[2] - 1
	end
	data[key] = value
end

--- Get the value at the given coordinates.<br>
--- Returns the default value if the cell is unset or coordinates are out of bounds.
---@param self GridMap The grid instance.
---@param x integer The x coordinate (column).
---@param y integer The y coordinate (row).
---@return any value The value at the coordinates, or default value.
---@usage <br>
--- ```
--- local grid = GridMap.new(3, 3, 0)
--- grid:set(1, 1, 5)
--- print(grid:get(1, 1)) -- 5
--- print(grid:get(2, 2)) -- 0 (default)
--- ```
function GridMap.get(self, x, y)
	if not GridMap.inBounds(self, x, y) then
		return self[5]
	end
	local key = (y - 1) * self[3] + x
	local value = self[1][key]
	if value ~= nil then
		return value
	end
	return self[5]
end

--- Remove and return the value at the given coordinates.<br>
--- Returns `nil` if the cell is empty or coordinates are out of bounds.
---@param self GridMap The grid instance.
---@param x integer The x coordinate (column).
---@param y integer The y coordinate (row).
---@return any value The removed value, or nil if empty.
---@usage <br>
--- ```
--- local grid = GridMap.new(3, 3)
--- grid:set(1, 1, "A")
--- local removed = grid:remove(1, 1)
--- -- removed = "A"
--- ```
function GridMap.remove(self, x, y)
	if not GridMap.inBounds(self, x, y) then
		return
	end
	local key = (y - 1) * self[3] + x
	local data = self[1]
	local value = data[key]
	if value ~= nil then
		data[key] = nil
		self[2] = self[2] - 1
	end
	return value
end

--- Check if a cell at the given coordinates has a non-nil value.<br>
--- Returns `false` if the cell is unset or coordinates are out of bounds.
---@param self GridMap The grid instance.
---@param x integer The x coordinate (column).
---@param y integer The y coordinate (row).
---@return boolean hasValue True if the cell has a non-nil value.
---@usage <br>
--- ```
--- local grid = GridMap.new(3, 3)
--- grid:set(1, 1, "A")
--- print(grid:has(1, 1)) -- true
--- print(grid:has(2, 2)) -- false
--- ```
function GridMap.has(self, x, y)
	if not GridMap.inBounds(self, x, y) then
		return false
	end
	local key = (y - 1) * self[3] + x
	return self[1][key] ~= nil
end

--- Get the number of cells with non-nil values in the grid.
---@param self GridMap The grid instance.
---@return integer count Number of cells with non-nil values.
---@usage <br>
--- ```
--- local grid = GridMap.new(3, 3)
--- grid:set(1, 1, "A")
--- grid:set(2, 2, "B")
--- print(grid:count()) -- 2
--- ```
function GridMap.count(self)
	return self[2]
end

--- Clear all values from the grid.<br>
--- Resets all cells to nil and count to 0.
---@param self GridMap The grid instance.
---@usage <br>
--- ```
--- local grid = GridMap.new(3, 3)
--- grid:set(1, 1, "A")
--- grid:set(2, 2, "B")
--- grid:clear()
--- print(grid:count()) -- 0
--- ```
function GridMap.clear(self)
	self[1] = {}
	self[2] = 0
end

--- Fill the entire grid with a value.<br>
--- Overwrites all cells with the given value.
---@param self GridMap The grid instance.
---@param value any The value to fill the grid with.
---@usage <br>
--- ```
--- local grid = GridMap.new(2, 2)
--- grid:fill(0)
--- print(grid:get(1, 1)) -- 0
--- print(grid:get(2, 2)) -- 0
--- ```
function GridMap.fill(self, value)
	local data = self[1]
	local total = self[3] * self[4]
	for key = 1, total do
		data[key] = value
	end
	self[2] = value ~= nil and total or 0
end

function GridMap._iter(state, index)
	while state[4] < state[3] do
		state[4] = state[4] + 1
		local value = state[1][state[4]]
		if value ~= nil then
			index = index + 1
			local x = ((state[4] - 1) % state[2]) + 1
			local y = math_floor((state[4] - 1) / state[2]) + 1
			return index, x, y, value
		end
	end
end

--- Return an iterator over the grid cells (row by row, left to right).<br>
--- Yields index, x, y, value for each cell that has a non-nil value.
---@param self GridMap The grid instance.
---@return function iterator Iterator that yields index, x, y, value.
---@return table state The iterator state table.
---@return integer initial Initial control variable.
---@usage <br>
--- ```
--- local grid = GridMap.new(3, 3)
--- grid:set(1, 1, "A")
--- grid:set(3, 2, "B")
--- for i, x, y, value in grid:iterator() do
---   print(i, x, y, value)
--- end
--- -- Outputs: 1, 1, 1, "A"
--- --          2, 3, 2, "B"
--- ```
function GridMap.iterator(self)
	return GridMap._iter, {
		self[1],
		self[3],
		self[3] * self[4],
		0,
	}, 0
end

-- Deprecated aliases (naming standard: snake_case). Kept for compatibility.
GridMap.in_bounds = GridMap.inBounds

-- Export
return GridMap
