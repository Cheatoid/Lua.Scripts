-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for GridMap.lua.
-- Run from this directory:
--   lua GridMap.lua
--   luajit GridMap.lua

-- Bootstrap: make requires work from tests/ subdir with plain lua/luajit.
do
  local src = debug.getinfo(1, "S").source
  local dir = src:match("^@(.+/)[^/]+$") or "./"
  local function isfile(p)
    local f = io.open(p, "r")
    if f then f:close() return true end
    return false
  end
  local root
  for _, c in ipairs({ dir, dir .. "../", dir .. "../..//", dir .. "../../..//", "./", "../", "../../" }) do
    if isfile(c .. "standalone/bits.lua") then root = c break end
  end
  root = root or dir .. "../"
  if package then
    package.path = dir .. "../?.lua;" .. dir .. "../?/init.lua;" .. dir .. "?.lua;" .. dir .. "?/init.lua;" .. root .. "?.lua;" .. root .. "?/init.lua;" .. root .. "standalone/?.lua;" .. root .. "math/?.lua;" .. root .. "collections/?.lua;" .. root .. "benchmark/?.lua;" .. root .. "timer/?.lua;" .. root .. "autocompleter/?.lua;" .. root .. "permission/?.lua;" .. root .. "chat_commander/?.lua;" .. root .. "vm/?.lua;" .. root .. "require_finder/?.lua;" .. root .. "inventory/?.lua;" .. package.path
  end
  local searchers = package.searchers or package.loaders
  if searchers then
    table.insert(searchers, 2, function(mod)
      if mod:sub(1, 3) == "../" or mod:sub(1, 2) == "./" then
        local clean = mod:gsub("^%./", ""):gsub("^%.%.%/", ""):gsub("^%.%.%/", "")
        local tries = { dir .. "../" .. clean .. ".lua", dir .. "../" .. clean .. "/init.lua", root .. clean .. ".lua", root .. clean .. "/init.lua" }
        for _, f in ipairs(tries) do
          if isfile(f) then
            local chunk, err = loadfile(f)
            if chunk then return chunk, f end
          end
        end
      end
      return nil
    end)
  end
end
local lib = require "GridMap"
local GridMap = lib

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
	print("All tests passed")
end
