-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Localized global functions for better performance
local setmetatable = setmetatable
local string_format = string.format

--- Define the RingQueue class.<br>
--- A fixed-size circular queue that rejects new items when full.<br>
--- Unlike CircularBuffer, it preserves all items and never overwrites data.<br>
--- Perfect for bounded buffers where overflow should be prevented.
---@class RingQueue
---@field [1] table Array storing the queue items
---@field [2] integer Current number of items in queue
---@field [3] integer Head index (next to dequeue)
---@field [4] integer Tail index (next insertion index)
---@field [5] integer Maximum capacity of the queue
local RingQueue = {}
RingQueue.__index = RingQueue

--- Create a new RingQueue instance with a fixed size.<br>
--- The queue will not accept new items when full.
---@param size integer Maximum number of items the queue can hold.
---@return RingQueue queue New RingQueue instance.
---@usage <br>
--- ```
--- local queue = RingQueue.new(3)
--- queue:enqueue(1)
--- queue:enqueue(2)
--- queue:enqueue(3)
--- queue:enqueue(4) -- Fails, queue is full
--- ```
function RingQueue.new(size)
	return setmetatable({
		{},
		0,
		1,
		1,
		size,
	}, RingQueue)
end

RingQueue.__call = RingQueue.new

--- Get the number of items using `#` operator.<br>
--- Allows using `#queue` instead of `queue:count()`.
---@param self RingQueue The queue instance.
---@return integer count Number of items in the queue.
---@usage <br>
--- ```
--- local queue = RingQueue.new(5)
--- queue:enqueue(1)
--- queue:enqueue(2)
--- print(#queue) -- 2
--- ```
function RingQueue.__len(self)
	return self[2]
end

--- Iterate over queue items using `pairs()`.<br>
--- Yields index and value for each item (oldest first).
---@param self RingQueue The queue instance.
---@return function iterator Iterator that yields index and value pairs.
---@usage <br>
--- ```
--- local queue = RingQueue.new(3)
--- queue:enqueue(1)
--- queue:enqueue(2)
--- for index, value in pairs(queue) do
---   print(index, value)
--- end
--- ```
function RingQueue.__pairs(self)
	return RingQueue.iterator(self)
end

--- Iterate over queue items using `ipairs()`.<br>
--- Same as `pairs()` for RingQueue.
---@param self RingQueue The queue instance.
---@return function iterator Iterator that yields index and value pairs.
function RingQueue.__ipairs(self)
	return RingQueue.iterator(self)
end

--- Get string representation of the queue.<br>
--- Returns a string showing size and count.
---@param self RingQueue The queue instance.
---@return string string String representation of the queue.
---@usage <br>
--- ```
--- local queue = RingQueue.new(5)
--- queue:enqueue(1)
--- queue:enqueue(2)
--- print(tostring(queue)) -- "RingQueue(size=5, count=2)"
--- ```
function RingQueue.__tostring(self)
	return string_format("RingQueue(size=%d, count=%d)", self[5], self[2])
end

--- Insert an item into the ring queue.<br>
--- Returns `true` if the item was inserted, `false` if the queue is full.
---@param self RingQueue The queue instance.
---@param value any The value to insert.
---@return boolean success True if inserted, false if full.
---@usage <br>
--- ```
--- local queue = RingQueue.new(2)
--- queue:enqueue(1)
--- queue:enqueue(2)
--- local success = queue:enqueue(3) -- Fails, returns false
--- ```
function RingQueue.enqueue(self, value)
	if self[2] == self[5] then
		return false
	end
	self[1][self[4]] = value
	self[4] = (self[4] % self[5]) + 1
	self[2] = self[2] + 1
	return true
end

--- Remove and return the oldest item from the queue.<br>
--- Returns `nil` if the queue is empty.
---@param self RingQueue The queue instance.
---@return any value The removed value, or nil if empty.
---@usage <br>
--- ```
--- local queue = RingQueue.new(3)
--- queue:enqueue(1)
--- queue:enqueue(2)
--- local removed = queue:dequeue()
--- -- removed = 1 (oldest)
--- ```
function RingQueue.dequeue(self)
	if self[2] == 0 then
		return
	end
	local value = self[1][self[3]]
	self[1][self[3]] = nil
	self[3] = (self[3] % self[5]) + 1
	self[2] = self[2] - 1
	return value
end

--- Get the oldest item from the queue without removing it.<br>
--- Returns `nil` if the queue is empty.
---@param self RingQueue The queue instance.
---@return any value The oldest value, or nil if empty.
---@usage <br>
--- ```
--- local queue = RingQueue.new(3)
--- queue:enqueue(1)
--- queue:enqueue(2)
--- local peeked = queue:peek()
--- -- peeked = 1 (oldest)
--- ```
function RingQueue.peek(self)
	if self[2] == 0 then
		return
	end
	return self[1][self[3]]
end

--- Get all items from the queue in order (oldest first).<br>
--- Returns a table containing all items and the total count.
---@param self RingQueue The queue instance.
---@return table array Array of items (oldest first).
---@return integer count Total number of items in the queue.
---@usage <br>
--- ```
--- local queue = RingQueue.new(3)
--- queue:enqueue(1)
--- queue:enqueue(2)
--- queue:enqueue(3)
--- local items, count = queue:get()
--- -- items = {1, 2, 3}, count = 3
--- ```
function RingQueue.get(self)
	local result = {}
	local count = self[2]
	for i = 1, count do
		local index = (self[3] + i - 2 + self[5]) % self[5] + 1
		result[i] = self[1][index]
	end
	return result, count
end

--- Get the number of items currently in the queue.
---@param self RingQueue The queue instance.
---@return integer count Number of items in the queue.
---@usage <br>
--- ```
--- local queue = RingQueue.new(5)
--- queue:enqueue(1)
--- queue:enqueue(2)
--- print(queue:count()) -- 2
--- ```
function RingQueue.count(self)
	return self[2]
end

function RingQueue._iter(state, index)
	index = index + 1
	if index <= state[1] then
		local realIndex = (state[2] + index - 2 + state[3]) % state[3] + 1
		return index, state[4][realIndex]
	end
end

--- Return an iterator over the queue items (oldest first).<br>
--- Yields index and value for each item in the queue.
---@param self RingQueue The queue instance.
---@return function iterator Iterator that yields index and value pairs.
---@return table state The iterator state table.
---@return integer initial Initial control variable.
---@usage <br>
--- ```
--- local queue = RingQueue.new(3)
--- queue:enqueue(1)
--- queue:enqueue(2)
--- queue:enqueue(3)
--- for index, value in queue:iterator() do
---   print(index, value)
--- end
--- -- Outputs: 1, 1  (oldest)
--- --          2, 2
--- --          3, 3  (newest)
--- ```
function RingQueue.iterator(self)
	return RingQueue._iter, {
		RingQueue.count(self),
		self[3],
		self[5],
		self[1],
	}, 0
end

-- Export
return RingQueue
