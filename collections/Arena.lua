-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Localized global functions for better performance
local error = error
local setmetatable = setmetatable
local math_min = math.min

--- Define the Arena class.<br>
--- A generic arena allocator that pools and reuses objects.<br>
--- Perfect for situations where many short-lived objects are allocated and reset frequently.

---@generic T
---@alias ArenaFactory fun(...):T

---@generic T
---@alias ArenaReset fun(obj:T)

---@class ArenaOptions<T>
---@field reset? ArenaReset<T>
---@field reserve? integer
---@field debug? boolean
---@field maintainLookup? boolean

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
---@param factory? ArenaFactory<T> Factory function that produces a new object.
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
---@param count? integer Number of items to release (default 1).
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
---@return integer|nil index 1-based index if found, otherwise nil.
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
---@return any|nil object The object, or nil if the index is out of range.
function Arena.get(self, index)
	if index >= 1 and index <= self._size then
		return self._pool[index]
	end
end

--- Get the most recently allocated object.
---@param self Arena The arena instance.
---@return any|nil object The last object, or nil if empty.
function Arena.last(self)
	return self._pool[self._size]
end

Arena.peek = Arena.last

--- Return an iterator yielding `(index, value)` pairs over active items.
---@param self Arena The arena instance.
---@return function iterator Iterator function for use in `for` loops.
---@usage <br>
--- ```
--- for i, obj in arena:iter() do
---   print(i, obj)
--- end
--- ```
function Arena.iter(self)
	local i = 0
	return function()
		i = i + 1
		if i <= self._size then
			return i, self._pool[i]
		end
	end
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
---@param free? boolean If false, only the size is reset (default true).
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

-- Export
return Arena
