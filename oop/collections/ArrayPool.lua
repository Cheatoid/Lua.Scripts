-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Shared array pool library
--
-- This library provides a pool-based mechanism for creating/reusing Lua arrays (tables)
-- to reduce garbage collection pressure and improve performance for operations that
-- frequently allocate and discard arrays of similar sizes.
--
-- Usage:
--   local pool = ArrayPool.shared()
--   local arr = pool:rent(100)  -- Rent an array with at least 100 elements
--   -- Use the array
--   arr[1] = "value"
--   arr[2] = "another"
--   -- When done, return to pool (or let GC collect it)
--   pool:release(arr)

-- Localized global functions for better performance
local collectgarbage = collectgarbage
local pcall = pcall
local type = type
local setmetatable = setmetatable
local table_insert = table.insert
local table_remove = table.remove

local oop = require "../oop"

---@class ArrayPool
---@field _stats table
---@field _buckets table
local ArrayPool = oop.class("ArrayPool")

-- Constants for pool configuration
local MAX_ARRAY_LENGTH = 1024 * 1024 -- TODO: 1M elements max per array
local BUCKET_COUNT = 16

--- Calculate bucket index for a given array length.
local function getBucketIndex(minLength)
	-- Use power-of-2 buckets: 1, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, ...
	local bucketSize = 1
	local bucketIndex = 0

	if minLength <= 0 then
		return 0
	end

	while bucketSize < minLength and bucketIndex < BUCKET_COUNT - 1 do
		bucketSize = bucketSize * 2
		bucketIndex = bucketIndex + 1
	end

	return bucketIndex
end

--- Calculate the array length for a given bucket.
local function getBucketLength(bucketIndex)
	return 2 ^ bucketIndex
end

--- Initialize the pool with buckets.
function ArrayPool:constructor()
	-- Create weak tables for each bucket (allow GC to collect arrays if needed)
	-- Using weak values so arrays can be collected if pool pressure is high
	self._buckets = {}

	for i = 0, BUCKET_COUNT - 1 do
		self._buckets[i] = oop.weakValues()
	end

	-- Statistics
	self._stats = {
		rentCount = 0,
		releaseCount = 0,
		createdCount = 0,
		reusedCount = 0
	}
end

--- Rent an array with at least minLength elements.
---@param minLength number|nil The minimum number of elements the array should hold (default: 1)
---@param clearArray boolean|nil Optional: whether to clear the array before renting (default: false)
---@return table array The rented array.
function ArrayPool:rent(minLength, clearArray)
	if not minLength or minLength <= 0 then
		minLength = 1
	end

	self._stats.rentCount = self._stats.rentCount + 1

	local bucketIndex = getBucketIndex(minLength)
	local bucket = self._buckets[bucketIndex]

	-- Try to get an array from the bucket
	local arr
	if bucket and #bucket > 0 then
		arr = table_remove(bucket)
		self._stats.reusedCount = self._stats.reusedCount + 1
	end

	-- If no array available, create a new one
	if not arr then
		arr = {}
		local arrayLength = getBucketLength(bucketIndex)
		for i = 1, arrayLength do
			arr[i] = nil -- Pre-allocate with nil values
		end
		self._stats.createdCount = self._stats.createdCount + 1
	end

	-- Clear the array if requested
	if clearArray then
		for i = 1, #arr do
			arr[i] = nil
		end
	end

	-- Mark as rented (optional metadata)
	arr.__arrayPool = {
		pool = self,
		bucketIndex = bucketIndex
	}

	return arr
end

--- Release an array back to the pool.
---@param arr table The array to release.
---@param clearArray boolean|nil Optional: whether to clear the array before releasing (default: false).
---@return boolean success A boolean indicating success.
function ArrayPool:release(arr, clearArray)
	if not arr or type(arr) ~= "table" then
		return false
	end

	-- Check if this array was rented from this pool
	if not arr.__arrayPool or arr.__arrayPool.pool ~= self then
		return false
	end

	self._stats.releaseCount = self._stats.releaseCount + 1

	-- Clear the array if requested
	if clearArray then
		for i = 1, #arr do
			arr[i] = nil
		end
	end

	-- Release to appropriate bucket
	local bucketIndex = arr.__arrayPool.bucketIndex
	local bucket = self._buckets[bucketIndex]

	if bucket then
		table_insert(bucket, arr)
	end

	-- Remove pool metadata
	arr.__arrayPool = nil

	return true
end

--- Clear all arrays in the pool.
function ArrayPool:clear()
	for i = 0, BUCKET_COUNT - 1 do
		self._buckets[i] = setmetatable({}, { __mode = "v" })
	end
end

--- Force garbage collection to clean up unreferenced arrays.
function ArrayPool:gc()
	collectgarbage("collect")
end

--- Get pool statistics.
---@return table stats Table with fields: rentCount, releaseCount, createdCount, reusedCount
function ArrayPool:getStats()
	local stats = {
		rentCount = self._stats.rentCount,
		releaseCount = self._stats.releaseCount,
		createdCount = self._stats.createdCount,
		reusedCount = self._stats.reusedCount,
		currentArrays = 0
	}

	-- Count current arrays in all buckets
	for i = 0, BUCKET_COUNT - 1 do
		local bucket = self._buckets[i]
		if bucket then
			stats.currentArrays = stats.currentArrays + #bucket
		end
	end

	return stats
end

--- Reset statistics.
function ArrayPool:resetStats()
	self._stats = {
		rentCount = 0,
		releaseCount = 0,
		createdCount = 0,
		reusedCount = 0
	}
end

--- Helper function: rent array and use it in a function.<br>
--- Automatically releases the array after the function completes.
---@param minLength number Minimum array length.
---@param fn function Function to execute with the array.
---@return any value Function's return value.
function ArrayPool:use(minLength, fn)
	if type(fn) ~= "function" then
		return error("second argument must be a function", 2)
	end

	local arr = self:rent(minLength, false)

	-- Use pcall to ensure we release array even on error
	local success, result = pcall(fn, arr)

	-- Release array back to pool
	self:release(arr, false)

	if not success then
		return error(result, 2)
	end

	return result
end

--- Get bucket information (for debugging).
---@return table table Table with bucket sizes and array counts.
function ArrayPool:getBucketInfo()
	local info = {}

	for i = 0, BUCKET_COUNT - 1 do
		local bucket = self._buckets[i]
		if bucket then
			info[i] = {
				size = getBucketLength(i),
				count = #bucket
			}
		end
	end

	return info
end

do
	-- Static instance for singleton pattern
	local _sharedInstance

	--- Get shared instance (singleton pattern).
	---@return ArrayPool instance The shared ArrayPool instance.
	function ArrayPool.getInstance()
		if not _sharedInstance then
			_sharedInstance = ArrayPool:new()
		end
		return _sharedInstance
	end
end

-- Alias for getInstance (more idiomatic for pools)
ArrayPool.shared = ArrayPool.getInstance

-- Export
return ArrayPool
