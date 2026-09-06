-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Localized global functions for better performance
local error = error
local setmetatable = setmetatable
local math_min = math.min

---@generic T
---@alias ArenaFactory fun(...):T

---@generic T
---@alias ArenaReset fun(obj:T)

---@class ArenaOptions<T>
---@field reset? ArenaReset<T>
---@field reserve? integer
---@field debug? boolean
---@field maintainLookup? boolean

--- A generic arena allocator that pools and reuses objects.<br>
--- Perfect for situations where many short-lived objects are allocated and reset frequently.
---@class Arena<T>
---@field _factory ArenaFactory<T>
---@field _reset ArenaReset<T>
---@field _pool table
---@field _size integer
---@field _capacity integer
---@field _debug boolean
---@field _lookup table|boolean
local Arena = {}
Arena.__index = Arena

--- Create a new Arena instance.<br>
--- Objects are created on demand by `factory` and pooled for reuse.
---@generic T
---@param factory? ArenaFactory<T> Optional factory function that produces a new object.
---@param options? ArenaOptions<T> Optional configuration table.
---@return Arena<T> arena New Arena instance.
---@usage <br>
--- ```
--- local arena = Arena.new(function() return {} end, { reserve = 10 })
--- local obj, created = arena:alloc()
--- ```
function Arena.new(factory, options)
	options = options or {}
	local self = setmetatable({}, Arena)
	self._factory = factory or function() return {} end
	self._reset = options.reset
	self._pool = {}
	self._size = 0
	self._capacity = 0
	self._debug = options.debug == true
	if options.maintainLookup then
		self._lookup = {}
	else
		self._lookup = false
	end
	if options.reserve then
		self:reserve(options.reserve)
	end
	return self
end

Arena.__call = Arena.new

--- Internal assertion helper, only fires when debug mode is enabled.
---@param self Arena The arena instance.
---@param condition boolean Condition to assert.
---@param message string Error message raised on failure.
function Arena._assert(self, condition, message)
	if self._debug and not condition then
		return error(message, 2)
	end
end

--- Allocate (or reuse) a single object from the arena.
---@param self Arena The arena instance.
---@return any object The allocated object.
---@return boolean created True if a new object was created, false if reused.
---@usage <br>
--- ```
--- local obj, created = arena:alloc("arg1", "arg2")
--- ```
function Arena.alloc(self, ...)
	local i = self._size + 1
	self._size = i
	if i <= self._capacity then
		return self._pool[i], false
	end
	local o = self._factory(...)
	self._pool[i] = o
	self._capacity = i
	if self._lookup then
		self._lookup[o] = i
	end
	return o, true
end

--- Allocate multiple objects from the arena in one call.
---@param self Arena The arena instance.
---@param count integer Number of objects to allocate.
---@return table array Array of allocated objects.
---@return integer created Number of newly created (not reused) objects.
function Arena.alloc_many(self, count, ...)
	local t = {}
	local created = 0
	for i = 1, count do
		local o, new = self:alloc(...)
		t[i] = o
		if new then
			created = created + 1
		end
	end
	return t, created
end

--- Release the last `count` items, calling `reset` on each if provided.
---@param self Arena The arena instance.
---@param count? integer Number of items to release (default: 1).
function Arena.release_last(self, count)
	count = count or 1
	count = math_min(count, self._size)
	if self._reset then
		for i = self._size, self._size - count + 1, -1 do
			self._reset(self._pool[i])
		end
	end
	self._size = self._size - count
end

--- Reset all items from `index` to the end of the active region.
---@param self Arena The arena instance.
---@param index integer Starting index (1-based) to reset from.
function Arena.reset_from(self, index)
	self:_assert(index >= 1 and index <= self._size + 1, "invalid index")
	if self._reset then
		for i = index, self._size do
			self._reset(self._pool[i])
		end
	end
	self._size = index - 1
end

--- Capture the current size as a checkpoint for later restoration.
---@param self Arena The arena instance.
---@return integer checkpoint Current arena size.
function Arena.checkpoint(self)
	return self._size
end

--- Restore the arena to a previously captured checkpoint.
---@param self Arena The arena instance.
---@param checkpoint integer Checkpoint value returned by `checkpoint()`.
function Arena.restore(self, checkpoint)
	self:_assert(checkpoint >= 0 and checkpoint <= self._size, "invalid checkpoint")
	if self._reset then
		for i = checkpoint + 1, self._size do
			self._reset(self._pool[i])
		end
	end
	self._size = checkpoint
end

--- Reset the arena completely, restoring all active objects.
---@param self Arena The arena instance.
function Arena.reset(self)
	self:restore(0)
end

--- Pre-allocate objects until the arena has at least `capacity` slots.
---@param self Arena The arena instance.
---@param capacity integer Target capacity.
function Arena.reserve(self, capacity)
	while self._capacity < capacity do
		self._capacity = self._capacity + 1
		local o = self._factory()
		self._pool[self._capacity] = o
		if self._lookup then
			self._lookup[o] = self._capacity
		end
	end
end

--- Alias for `reserve`; pre-populates the pool with `count` objects.
---@param self Arena The arena instance.
---@param count integer Number of objects to pre-allocate.
function Arena.warm(self, count)
	self:reserve(count)
end

--- Iterate over active items, invoking `fn(item, index)` for each.
---@param self Arena The arena instance.
---@param fn function Callback receiving the item and its index.
function Arena.foreach(self, fn)
	for i = 1, self._size do
		fn(self._pool[i], i)
	end
end

--- Check whether an object is currently held by the arena.
---@param self Arena The arena instance.
---@param object any Object to search for.
---@return boolean contains True if the object is active in the arena.
function Arena.contains(self, object)
	return self:index_of(object) ~= nil
end

--- Find the active index of an object.
---@param self Arena The arena instance.
---@param object any Object to locate.
---@return integer? index 1-based index if found, otherwise nil.
function Arena.index_of(self, object)
	if self._lookup then
		local i = self._lookup[object]
		if i and i <= self._size then
			return i
		end
		return
	end
	for i = 1, self._size do
		if self._pool[i] == object then
			return i
		end
	end
end

--- Get the object stored at a 1-based index.
---@param self Arena The arena instance.
---@param index integer Index of the object to retrieve.
---@return any object The object, or nil if the index is out of range.
function Arena.get(self, index)
	if index >= 1 and index <= self._size then
		return self._pool[index]
	end
end

--- Get the most recently allocated object.
---@param self Arena The arena instance.
---@return any object The last object, or nil if empty.
function Arena.last(self)
	return self._pool[self._size]
end

Arena.peek = Arena.last

function Arena._iter(self, index)
	index = index + 1
	if index <= self._size then
		return index, self._pool[index]
	end
end

--- Return an iterator yielding `(index, value)` pairs over active items.
---@param self Arena The arena instance.
---@return function iterator Iterator function for use in `for` loops.
---@return Arena state The arena instance used as iterator state.
---@return integer initial Initial control variable.
---@usage <br>
--- ```
--- for i, obj in arena:iter() do
---   print(i, obj)
--- end
--- ```
function Arena.iter(self)
	return Arena._iter, self, 0
end

--- Get the number of currently active items.
---@param self Arena The arena instance.
---@return integer size Number of active items.
function Arena.size(self)
	return self._size
end

Arena.active = Arena.size

--- Get the total capacity (active + inactive) of the pool.
---@param self Arena The arena instance.
---@return integer capacity Total capacity.
function Arena.capacity(self)
	return self._capacity
end

--- Get the number of inactive (reusable) slots.
---@param self Arena The arena instance.
---@return integer inactive Inactive slot count.
function Arena.inactive(self)
	return self._capacity - self._size
end

--- Get the utilization ratio of the arena.
---@param self Arena The arena instance.
---@return number utilization Active items divided by capacity (0..1).
function Arena.utilization(self)
	return self._capacity == 0 and 0 or self._size / self._capacity
end

--- Check if the arena has no active items.
---@param self Arena The arena instance.
---@return boolean empty True if empty.
function Arena.is_empty(self)
	return self._size == 0
end

--- Check if the arena is at full capacity.
---@param self Arena The arena instance.
---@return boolean full True if `size == capacity`.
function Arena.full(self)
	return self._size == self._capacity
end

--- Get a snapshot of arena statistics.
---@param self Arena The arena instance.
---@return table stats Table with size, capacity, inactive, utilization.
function Arena.stats(self)
	return {
		size = self._size,
		capacity = self._capacity,
		inactive = self:inactive(),
		utilization = self:utilization()
	}
end

--- Remove all inactive slots beyond the current size.
---@param self Arena The arena instance.
function Arena.trim(self)
	for i = self._size + 1, self._capacity do
		self._pool[i] = nil
	end
	self._capacity = self._size
	if self._lookup then
		local n = {}
		for i = 1, self._size do
			n[self._pool[i]] = i
		end
		self._lookup = n
	end
end

Arena.shrink_to_fit = Arena.trim

--- Clear the arena.<br>
--- With `free` omitted or `true`, the underlying pool is also released.
---@param self Arena The arena instance.
---@param free? boolean If false, only the size is reset (default: true).
function Arena.clear(self, free)
	self._size = 0
	if free ~= false then
		self._pool = {}
		self._capacity = 0
		if self._lookup then
			self._lookup = {}
		end
	end
end

--[[ Quick tests
if true then
	-- Basic alloc and reuse
	do
		local arena = Arena.new(function() return { value = 0 } end)
		assert(arena:is_empty(), "Arena should be empty initially")
		assert(arena:size() == 0, "size should be 0 initially")
		assert(arena:active() == 0, "active should be 0 initially")
		assert(arena:capacity() == 0, "capacity should be 0 initially")
		assert(arena:inactive() == 0, "inactive should be 0 initially")
		assert(arena:utilization() == 0, "utilization should be 0 when empty")
		assert(arena:last() == nil, "last should be nil when empty")
		assert(arena:peek() == nil, "peek should be nil when empty")
		assert(arena:get(1) == nil, "get should return nil when empty")
		assert(arena:checkpoint() == 0, "checkpoint should be 0 initially")

		local o1, created1 = arena:alloc()
		assert(created1 == true, "first alloc should create")
		assert(arena:size() == 1, "size should be 1 after first alloc")
		assert(arena:capacity() == 1, "capacity should be 1 after first alloc")
		assert(not arena:is_empty(), "Arena should not be empty after alloc")
		assert(arena:full(), "Arena should be full when size == capacity")
		assert(arena:utilization() == 1, "utilization should be 1 when full")
		assert(arena:get(1) == o1, "get(1) should return first object")
		assert(arena:last() == o1, "last should return first object")
		assert(arena:peek() == o1, "peek should alias last")
		assert(arena:contains(o1), "contains should return true for active object")
		assert(arena:index_of(o1) == 1, "index_of should return 1 for first object")

		local o2, created2 = arena:alloc()
		assert(created2 == true, "second alloc should create")
		assert(arena:size() == 2, "size should be 2 after second alloc")
		assert(arena:capacity() == 2, "capacity should be 2 after second alloc")
		assert(o2 ~= o1, "alloc should produce distinct objects")
		assert(arena:get(2) == o2, "get(2) should return second object")
		assert(arena:last() == o2, "last should return most recent object")
		assert(arena:index_of(o2) == 2, "index_of should return 2 for second object")

		-- Restore truncates and allows reuse without calling factory
		arena:restore(1)
		assert(arena:size() == 1, "size should be 1 after restore(1)")
		assert(arena:capacity() == 2, "restore should keep capacity")
		assert(arena:inactive() == 1, "inactive should be 1 after restore")
		local o2b, created2b = arena:alloc()
		assert(created2b == false, "alloc after restore should reuse")
		assert(o2b == o2, "reused object should be identical")

		-- Reset clears size but keeps capacity for reuse
		arena:reset()
		assert(arena:size() == 0, "size should be 0 after reset")
		assert(arena:capacity() == 2, "reset should keep capacity")
		assert(arena:inactive() == 2, "inactive should equal capacity after reset")
		assert(arena:is_empty(), "Arena should be empty after reset")
		local r1, rc1 = arena:alloc()
		assert(rc1 == false, "alloc after reset should reuse")
		assert(r1 == o1, "first reused object should be identical")
	end
	-- Default factory and factory args
	do
		local def = Arena.new()
		local o, created = def:alloc()
		assert(created == true, "default factory first alloc should create")
		assert(type(o) == "table", "default factory should produce a table")

		local withArgs = Arena.new(function(a, b) return { a = a, b = b } end)
		local v, vc = withArgs:alloc(10, 20)
		assert(vc == true, "alloc with args should create")
		assert(v.a == 10 and v.b == 20, "factory should receive alloc args")
	end
	-- alloc_many
	do
		local arena = Arena.new(function() return {} end)
		local arr, created = arena:alloc_many(3)
		assert(#arr == 3, "alloc_many should return 3 objects")
		assert(created == 3, "alloc_many should report 3 created")
		assert(arena:size() == 3, "size should be 3 after alloc_many(3)")
		assert(arena:get(1) == arr[1], "alloc_many objects should match pool order")
		assert(arena:get(3) == arr[3], "alloc_many objects should match pool order")

		arena:reset()
		local arr2, created2 = arena:alloc_many(3)
		assert(created2 == 0, "alloc_many after reset should reuse")
		assert(arr2[1] == arr[1] and arr2[2] == arr[2] and arr2[3] == arr[3],
			"alloc_many reuse should return identical objects")

		local empty, created0 = arena:alloc_many(0)
		assert(#empty == 0, "alloc_many(0) should return empty array")
		assert(created0 == 0, "alloc_many(0) should report 0 created")
		assert(arena:size() == 3, "alloc_many(0) should not change size")
	end
	-- release_last with reset
	do
		local resetCount = 0
		local arena = Arena.new(function() return { v = 1 } end, {
			reset = function(o)
				o.v = 0
				resetCount = resetCount + 1
			end,
		})
		local o1 = arena:alloc()
		o1.v = 99
		local o2 = arena:alloc()
		o2.v = 100
		arena:release_last()
		assert(resetCount == 1, "release_last should call reset once by default")
		assert(o2.v == 0, "release_last should reset released object")
		assert(arena:size() == 1, "size should be 1 after release_last()")
		arena:release_last(5)
		assert(arena:size() == 0, "release_last should clamp to size")
		assert(o1.v == 0, "release_last should reset all released objects")
		assert(resetCount == 2, "release_last(5) should reset one remaining object")
		-- Releasing from empty arena should be safe
		arena:release_last()
		assert(arena:size() == 0, "release_last on empty arena should stay at 0")
	end
	-- reset_from
	do
		local arena = Arena.new(function() return { v = 0 } end, {
			reset = function(o) o.v = -1 end,
		})
		local a1 = arena:alloc()
		a1.v = 10
		local a2 = arena:alloc()
		a2.v = 20
		local a3 = arena:alloc()
		a3.v = 30
		arena:reset_from(2)
		assert(arena:size() == 1, "size should be 1 after reset_from(2)")
		assert(a2.v == -1 and a3.v == -1, "reset_from should reset from index onward")
		assert(a1.v == 10, "reset_from should preserve objects before index")
		assert(arena:get(1) == a1, "get(1) should still return first object")
		assert(arena:get(2) == nil, "get beyond size should return nil")
		-- reset_from(size + 1) is a valid no-op
		arena:reset_from(2)
		assert(arena:size() == 1, "reset_from(size + 1) should be a no-op")
	end
	-- checkpoint / restore / reset
	do
		local arena = Arena.new(function() return { x = 0 } end, {
			reset = function(o) o.x = 0 end,
		})
		local o1 = arena:alloc()
		o1.x = 5
		local cp = arena:checkpoint()
		assert(cp == 1, "checkpoint should return current size")
		local o2 = arena:alloc()
		o2.x = 7
		assert(arena:size() == 2, "size should be 2 after second alloc")
		arena:restore(cp)
		assert(arena:size() == 1, "restore should truncate to checkpoint")
		assert(o2.x == 0, "restore should reset truncated objects")
		assert(o1.x == 5, "restore should preserve objects at or below checkpoint")
		arena:reset()
		assert(arena:size() == 0, "reset should clear size")
		assert(o1.x == 0, "reset should reset all active objects")
		assert(arena:is_empty(), "Arena should be empty after reset")
	end
	-- reserve and warm
	do
		local count = 0
		local arena = Arena.new(function()
			count = count + 1
			return {}
		end, { reserve = 5 })
		assert(arena:capacity() == 5, "reserve option should pre-allocate")
		assert(arena:size() == 0, "reserve should not change size")
		assert(count == 5, "reserve should call factory for each slot")
		assert(arena:inactive() == 5, "inactive should be 5 after reserve(5)")
		assert(not arena:full(), "Arena should not be full after reserve without alloc")
		local o, created = arena:alloc()
		assert(created == false, "alloc after reserve should reuse")
		assert(count == 5, "reuse should not call factory")
		assert(o == arena:get(1), "reused object should match pool")
		arena:reserve(3)
		assert(arena:capacity() == 5, "reserve with smaller capacity should be a no-op")
		arena:reserve(8)
		assert(arena:capacity() == 8, "reserve should grow capacity")
		assert(count == 8, "reserve growth should call factory")
		arena:warm(10)
		assert(arena:capacity() == 10, "warm should alias reserve")
	end
	-- foreach / iter / get / last / contains / index_of
	do
		local arena = Arena.new(function() return {} end)
		local o1 = arena:alloc()
		local o2 = arena:alloc()
		local o3 = arena:alloc()
		local seen = {}
		arena:foreach(function(item, index)
			seen[index] = item
		end)
		assert(seen[1] == o1 and seen[2] == o2 and seen[3] == o3, "foreach should visit all active items in order")
		local iterCount = 0
		for i, obj in arena:iter() do
			iterCount = iterCount + 1
			assert(i == iterCount, "iter should yield sequential indices")
			assert(obj == arena:get(i), "iter value should match get(i)")
		end
		assert(iterCount == 3, "iter should yield 3 items")
		assert(arena:get(0) == nil, "get(0) should return nil")
		assert(arena:get(-1) == nil, "get(-1) should return nil")
		assert(arena:get(4) == nil, "get beyond size should return nil")
		assert(arena:contains(o1) and arena:contains(o3), "contains should return true for active objects")
		local unknown = {}
		assert(not arena:contains(unknown), "contains should return false for unknown object")
		assert(arena:index_of(unknown) == nil, "index_of should return nil for unknown object")
		arena:restore(1)
		assert(not arena:contains(o3), "contains should return false for truncated object")
		assert(arena:index_of(o3) == nil, "index_of should return nil for truncated object")
	end
	-- size / capacity / stats helpers and aliases
	do
		local arena = Arena.new(function() return {} end)
		arena:reserve(4)
		arena:alloc()
		arena:alloc()
		assert(arena:size() == 2, "size should be 2")
		assert(arena:active() == 2, "active should alias size")
		assert(arena:capacity() == 4, "capacity should be 4")
		assert(arena:inactive() == 2, "inactive should be capacity - size")
		assert(arena:utilization() == 0.5, "utilization should be size / capacity")
		assert(not arena:is_empty(), "is_empty should be false with active items")
		assert(not arena:full(), "full should be false when size < capacity")
		local stats = arena:stats()
		assert(stats.size == 2, "stats.size should match size")
		assert(stats.capacity == 4, "stats.capacity should match capacity")
		assert(stats.inactive == 2, "stats.inactive should match inactive")
		assert(stats.utilization == 0.5, "stats.utilization should match utilization")
		assert(Arena.active == Arena.size, "active should alias size")
		assert(Arena.peek == Arena.last, "peek should alias last")
		assert(Arena.shrink_to_fit == Arena.trim, "shrink_to_fit should alias trim")
	end
	-- trim
	do
		local arena = Arena.new(function() return {} end)
		arena:reserve(10)
		arena:alloc()
		arena:alloc()
		arena:alloc()
		arena:trim()
		assert(arena:capacity() == 3, "trim should drop inactive slots")
		assert(arena:inactive() == 0, "inactive should be 0 after trim")
		assert(arena:full(), "Arena should be full after trim")
		arena:alloc()
		arena:alloc()
		assert(arena:size() == 5 and arena:capacity() == 5, "alloc after trim should grow again")
		arena:restore(2)
		arena:trim()
		assert(arena:capacity() == 2, "trim after restore should shrink to size")
		assert(arena:size() == 2, "trim should preserve size")
	end
	-- clear with and without free
	do
		local arena = Arena.new(function() return {} end)
		arena:alloc()
		arena:alloc()
		arena:alloc()
		arena:clear()
		assert(arena:size() == 0, "clear should reset size")
		assert(arena:capacity() == 0, "clear should free capacity by default")
		assert(arena:is_empty(), "Arena should be empty after clear")
		assert(arena:last() == nil, "last should be nil after clear")
		local o, created = arena:alloc()
		assert(created == true, "alloc after free should create")

		arena:alloc()
		arena:clear(false)
		assert(arena:size() == 0, "clear(false) should reset size")
		assert(arena:capacity() == 2, "clear(false) should keep capacity")
		assert(arena:inactive() == 2, "clear(false) should keep inactive slots")
		local r, rc = arena:alloc()
		assert(rc == false, "alloc after clear(false) should reuse")
		assert(r == o, "reuse after clear(false) should return identical object")
	end
	-- maintainLookup
	do
		local arena = Arena.new(function() return {} end, { maintainLookup = true })
		local o1 = arena:alloc()
		local o2 = arena:alloc()
		assert(arena:index_of(o1) == 1, "lookup index_of should return 1")
		assert(arena:index_of(o2) == 2, "lookup index_of should return 2")
		assert(arena:contains(o2), "lookup contains should return true")
		assert(arena:index_of({}) == nil, "lookup index_of should return nil for unknown object")
		arena:restore(1)
		assert(arena:index_of(o2) == nil, "lookup should hide inactive objects")
		assert(not arena:contains(o2), "lookup contains should be false for inactive object")
		assert(arena:index_of(o1) == 1, "lookup should keep active objects")
		arena:reserve(5)
		arena:trim()
		assert(arena:index_of(o1) == 1, "lookup should survive trim")
		arena:clear()
		assert(arena:index_of(o1) == nil, "lookup should be cleared with arena")
	end
	-- debug assertions
	do
		local arena = Arena.new(nil, { debug = true })
		arena:alloc()
		arena:alloc()
		local ok1 = pcall(function() arena:reset_from(0) end)
		assert(not ok1, "reset_from(0) should error in debug mode")
		local ok2 = pcall(function() arena:reset_from(99) end)
		assert(not ok2, "reset_from out of range should error in debug mode")
		local ok3 = pcall(function() arena:restore(99) end)
		assert(not ok3, "restore out of range should error in debug mode")
		local ok4 = pcall(function() arena:restore(-1) end)
		assert(not ok4, "restore(-1) should error in debug mode")
		-- Valid calls should not error
		arena:reset_from(1)
		arena:restore(0)
		local plain = Arena.new()
		plain:alloc()
		local ok5 = pcall(function() plain:reset_from(99) end)
		assert(ok5, "invalid index should not error without debug mode")
	end
	print("All tests passed")
end
--]]

-- Export
return Arena
