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
---@param lo? integer Lower bound index (default: 1).
---@param hi? integer Upper bound index (default: `#t + 1`).
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
---@param lo? integer Lower bound index (default: 1).
---@param hi? integer Upper bound index (default: `#t + 1`).
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
---@param lo? integer Lower bound index (default: 1).
---@param hi? integer Upper bound index (default: `#t + 1`).
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
---@param lo? integer Lower bound index (default: 1).
---@param hi? integer Upper bound index (default: `#t + 1`).
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

-- Export
return {
	left = bisect_left,
	right = bisect_right,
	insort_left = insort_left,
	insort_right = insort_right,
	bisect = bisect_right,
	insort = insort_right,
}
