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

--- Return an iterator over the grid cells (row by row, left to right).<br>
--- Yields index, x, y, value for each cell that has a non-nil value.
---@param self GridMap The grid instance.
---@return function iterator Iterator that yields index, x, y, value.
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
	local data = self[1]
	local width = self[3]
	local total = width * self[4]
	local currentIndex = 0
	return function(state, index)
		while currentIndex < total do
			currentIndex = currentIndex + 1
			local value = data[currentIndex]
			if value ~= nil then
				index = index + 1
				local x = ((currentIndex - 1) % width) + 1
				local y = math_floor((currentIndex - 1) / width) + 1
				return index, x, y, value
			end
		end
	end, nil, 0
end

--[[ Test the GridMap class
if true then
	-- Create a new GridMap with 3x3 dimensions
	local grid = GridMap.new(3, 3)
	-- Test that the grid is initially empty
	assert(grid:count() == 0, "Grid should be empty initially")
	assert(#grid == 0, "Grid # operator should return 0 initially")
	-- Test inBounds
	assert(grid:inBounds(1, 1) == true, "1,1 should be in bounds")
	assert(grid:inBounds(3, 3) == true, "3,3 should be in bounds")
	assert(grid:inBounds(0, 1) == false, "0,1 should be out of bounds")
	assert(grid:inBounds(4, 1) == false, "4,1 should be out of bounds")
	-- Test set and get
	grid:set(1, 1, "A")
	assert(grid:get(1, 1) == "A", "Cell 1,1 should be 'A'")
	assert(grid:count() == 1, "Grid should have 1 item after first set")
	grid:set(2, 2, "B")
	assert(grid:get(2, 2) == "B", "Cell 2,2 should be 'B'")
	assert(grid:count() == 2, "Grid should have 2 items after second set")
	-- Test default value
	assert(grid:get(3, 3) == nil, "Unset cell should return nil default")
	local grid2 = GridMap.new(2, 2, 0)
	assert(grid2:get(1, 1) == 0, "Unset cell should return default value 0")
	grid2:set(1, 1, 5)
	assert(grid2:get(1, 1) == 5, "Set cell should return the set value")
	-- Test has
	assert(grid:has(1, 1) == true, "Cell 1,1 should have a value")
	assert(grid:has(3, 3) == false, "Cell 3,3 should not have a value")
	assert(grid:has(4, 4) == false, "Out of bounds should return false for has")
	-- Test overwrite
	grid:set(1, 1, "C")
	assert(grid:get(1, 1) == "C", "Cell 1,1 should be overwritten to 'C'")
	assert(grid:count() == 2, "Count should remain 2 after overwrite")
	-- Test set out of bounds (should be ignored)
	grid:set(0, 1, "X")
	assert(grid:count() == 2, "Out of bounds set should be ignored")
	-- Test set to nil (removes the value)
	grid:set(1, 1, nil)
	assert(grid:has(1, 1) == false, "Cell 1,1 should not have a value after nil set")
	assert(grid:count() == 1, "Count should decrease after nil set")
	-- Test remove
	grid:set(3, 3, "D")
	local removed = grid:remove(3, 3)
	assert(removed == "D", "Removed value should be 'D'")
	assert(grid:count() == 1, "Count should be 1 after remove")
	assert(grid:has(3, 3) == false, "Cell 3,3 should be empty after remove")
	-- Test remove on empty cell
	local removed2 = grid:remove(3, 3)
	assert(removed2 == nil, "Removing empty cell should return nil")
	-- Test remove out of bounds
	local removed3 = grid:remove(0, 0)
	assert(removed3 == nil, "Removing out of bounds should return nil")
	-- Test clear
	grid:set(1, 1, "A")
	grid:set(2, 2, "B")
	grid:set(3, 3, "C")
	assert(grid:count() == 3, "Grid should have 3 items before clear")
	grid:clear()
	assert(grid:count() == 0, "Grid should be empty after clear")
	assert(grid:get(1, 1) == nil, "Cell 1,1 should be nil after clear")
	-- Test fill
	grid:fill(7)
	assert(grid:count() == 9, "Grid should have 9 items after fill")
	assert(grid:get(1, 1) == 7, "Cell 1,1 should be 7 after fill")
	assert(grid:get(3, 3) == 7, "Cell 3,3 should be 7 after fill")
	-- Test fill with nil
	grid:fill(nil)
	assert(grid:count() == 0, "Grid should have 0 items after nil fill")
	-- Test iterator
	grid:clear()
	grid:set(1, 1, "A")
	grid:set(3, 2, "B")
	grid:set(2, 3, "C")
	local iterated_items = {}
	for i, x, y, value in grid:iterator() do
		iterated_items[i] = { x = x, y = y, value = value }
	end
	assert(
		iterated_items[1].x == 1 and iterated_items[1].y == 1 and iterated_items[1].value == "A",
		"First item should be 1,1,'A'"
	)
	assert(
		iterated_items[2].x == 3 and iterated_items[2].y == 2 and iterated_items[2].value == "B",
		"Second item should be 3,2,'B'"
	)
	assert(
		iterated_items[3].x == 2 and iterated_items[3].y == 3 and iterated_items[3].value == "C",
		"Third item should be 2,3,'C'"
	)
	-- Test pairs
	local pairs_count = 0
	for i, x, y, value in pairs(grid) do
		pairs_count = pairs_count + 1
	end
	assert(pairs_count == 3, "pairs should iterate over 3 items")
	-- Test tostring
	local grid3 = GridMap.new(4, 5)
	grid3:set(1, 1, "X")
	assert(tostring(grid3) == "GridMap(4x5, count=1)", "tostring should format correctly")
	-- Test with different data types
	grid:clear()
	grid:set(1, 1, { test = "table" })
	grid:set(2, 2, function () return "function" end)
	grid:set(3, 3, "string")
	grid:set(1, 2, 42)
	grid:set(2, 1, true)
	assert(grid:count() == 5, "Grid should handle different data types")
	print("All tests passed ✔")
end
--]]

-- Export
return GridMap
