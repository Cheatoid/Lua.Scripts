-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Binary search utilities for sorted arrays
-- Equivalent to Python's bisect module

-- Localized global functions for better performance
local math_floor = math.floor
local table_insert = table.insert

--- Find leftmost index where value could be inserted to keep sorted order.<br>
--- Equivalent to Python's `bisect.bisect_left`.
---@param t table Sorted table (1-indexed).
---@param value any Value to search for.
---@param lo integer|nil Lower bound index (default: 1).
---@param hi integer|nil Upper bound index (default: #t + 1).
---@return number idx Insertion index in range [lo, hi].
---@usage <br>
--- ```
--- local arr = { 1, 2, 3, 3, 3, 4, 5 }
--- print(bisect.left(arr, 3))       -- 3 (first occurrence of 3)
--- print(bisect.left(arr, 3.5))     -- 6 (would be inserted before index 6)
--- print(bisect.left(arr, 0))       -- 1 (insert at beginning)
--- print(bisect.left(arr, 6))       -- 8 (insert at end)
--- print(bisect.left(arr, 3, 4, 7)) -- 5 (search within sub-range [4, 7))
--- ```
local function bisect_left(t, value, lo, hi)
	lo = lo or 1
	hi = hi or (#t + 1)
	while lo < hi do
		local mid = math_floor((lo + hi) * 0.5)
		if t[mid] < value then
			lo = mid + 1
		else
			hi = mid
		end
	end
	return lo
end

--- Find rightmost index where value could be inserted to keep sorted order.<br>
--- Equivalent to Python's `bisect.bisect_right`.
---@param t table Sorted table (1-indexed).
---@param value any Value to search for.
---@param lo integer|nil Lower bound index (default: 1).
---@param hi integer|nil Upper bound index (default: #t + 1).
---@return number idx Insertion index in range [lo, hi].
---@usage <br>
--- ```
--- local arr = { 1, 2, 3, 3, 3, 4, 5 }
--- print(bisect.right(arr, 3))       -- 6 (after last occurrence of 3)
--- print(bisect.right(arr, 3.5))     -- 6 (would be inserted before index 6)
--- print(bisect.right(arr, 0))       -- 1 (insert at beginning)
--- print(bisect.right(arr, 6))       -- 8 (insert at end)
--- print(bisect.right(arr, 3, 4, 7)) -- 6 (search within sub-range [4, 7))
--- ```
local function bisect_right(t, value, lo, hi)
	lo = lo or 1
	hi = hi or (#t + 1)
	while lo < hi do
		local mid = math_floor((lo + hi) * 0.5)
		if t[mid] <= value then
			lo = mid + 1
		else
			hi = mid
		end
	end
	return lo
end

--- Insert value into sorted table maintaining order (leftmost position).<br>
--- Uses `bisect.left` to find the insertion point, then `table.insert` to shift and insert.
---@param t table Sorted table to insert into (modified in-place).
---@param value any Value to insert.
---@param lo integer|nil Lower bound index (default: 1).
---@param hi integer|nil Upper bound index (default: #t + 1).
---@return number idx The index where the value was inserted.
---@usage <br>
--- ```
--- local arr = { 1, 2, 4, 5 }
--- bisect.insort_left(arr, 3)
--- -- arr is now: { 1, 2, 3, 4, 5 }
---
--- local arr2 = { 1, 3, 3, 5 }
--- bisect.insort_left(arr2, 3)
--- -- arr2 is now: { 1, 3, 3, 3, 5 } (inserted before existing 3s)
--- ```
local function insort_left(t, value, lo, hi)
	local idx = bisect_left(t, value, lo, hi)
	table_insert(t, idx, value)
	return idx
end

--- Insert value into sorted table maintaining order (rightmost position).<br>
--- Uses `bisect.right` to find the insertion point, then `table.insert` to shift and insert.
---@param t table Sorted table to insert into (modified in-place).
---@param value any Value to insert.
---@param lo integer|nil Lower bound index (default: 1).
---@param hi integer|nil Upper bound index (default: #t + 1).
---@return number idx The index where the value was inserted.
---@usage <br>
--- ```
--- local arr = { 1, 2, 4, 5 }
--- bisect.insort_right(arr, 3)
--- -- arr is now: { 1, 2, 3, 4, 5 }
---
--- local arr2 = { 1, 3, 3, 5 }
--- bisect.insort_right(arr2, 3)
--- -- arr2 is now: { 1, 3, 3, 3, 5 } (inserted after existing 3s)
--- ```
local function insort_right(t, value, lo, hi)
	local idx = bisect_right(t, value, lo, hi)
	table_insert(t, idx, value)
	return idx
end

--[[ Quick tests
if true then
	local string_format = string.format
	local total, passed, failed = 0, 0, 0
	local function test(name, fn)
		total = total + 1
		local ok, err = pcall(fn)
		if ok then
			passed = passed + 1
		else
			failed = failed + 1
			print(string_format("  FAIL  %s: %s", name, tostring(err)))
		end
	end
	print("[bisect] testing...")

	-- bisect_left
	test("bisect_left basic", function()
		local arr = { 1, 2, 3, 3, 3, 4, 5 }
		assert(bisect_left(arr, 3) == 3)
		assert(bisect_left(arr, 1) == 1)
		assert(bisect_left(arr, 5) == 7)
		assert(bisect_left(arr, 0) == 1)
		assert(bisect_left(arr, 6) == 8)
	end)

	test("bisect_left with sub-range", function()
		local arr = { 1, 2, 3, 3, 3, 4, 5 }
		assert(bisect_left(arr, 3, 4, 7) == 4)
	end)

	test("bisect_left empty table", function()
		assert(bisect_left({}, 1) == 1)
	end)

	-- bisect_right
	test("bisect_right basic", function()
		local arr = { 1, 2, 3, 3, 3, 4, 5 }
		assert(bisect_right(arr, 3) == 6)
		assert(bisect_right(arr, 1) == 2)
		assert(bisect_right(arr, 5) == 8)
		assert(bisect_right(arr, 0) == 1)
		assert(bisect_right(arr, 6) == 8)
	end)

	test("bisect_right with sub-range", function()
		local arr = { 1, 2, 3, 3, 3, 4, 5 }
		assert(bisect_right(arr, 3, 4, 7) == 6)
	end)

	test("bisect_right empty table", function()
		assert(bisect_right({}, 1) == 1)
	end)

	-- insort_left
	test("insort_left basic", function()
		local arr = { 1, 2, 4, 5 }
		local idx = insort_left(arr, 3)
		assert(idx == 3)
		assert(#arr == 5)
		assert(arr[1] == 1 and arr[2] == 2 and arr[3] == 3 and arr[4] == 4 and arr[5] == 5)
	end)

	test("insort_left duplicate inserts leftmost", function()
		local arr = { 1, 3, 3, 5 }
		local idx = insort_left(arr, 3)
		assert(idx == 2)
		assert(#arr == 5)
		assert(arr[2] == 3 and arr[3] == 3)
	end)

	test("insort_left into empty table", function()
		local arr = {}
		insort_left(arr, 42)
		assert(#arr == 1)
		assert(arr[1] == 42)
	end)

	-- insort_right
	test("insort_right basic", function()
		local arr = { 1, 2, 4, 5 }
		local idx = insort_right(arr, 3)
		assert(idx == 3)
		assert(#arr == 5)
		assert(arr[1] == 1 and arr[2] == 2 and arr[3] == 3 and arr[4] == 4 and arr[5] == 5)
	end)

	test("insort_right duplicate inserts rightmost", function()
		local arr = { 1, 3, 3, 5 }
		local idx = insort_right(arr, 3)
		assert(idx == 4)
		assert(#arr == 5)
		assert(arr[3] == 3 and arr[4] == 3)
	end)

	test("insort_right into empty table", function()
		local arr = {}
		insort_right(arr, 42)
		assert(#arr == 1)
		assert(arr[1] == 42)
	end)

	-- aliases
	test("aliases work", function()
		local M = { bisect = bisect_right, insort = insort_right }
		assert(M.bisect == bisect_right)
		assert(M.insort == insort_right)
	end)

	print(string_format("[bisect] %d/%d passed", passed, total))
	if failed > 0 then
		print(string_format("[bisect] %d FAILED", failed))
	end
end
--]]

-- Export
return {
	left = bisect_left,
	right = bisect_right,
	insort_left = insort_left,
	insort_right = insort_right,
	bisect = bisect_right,
	insort = insort_right,
}
