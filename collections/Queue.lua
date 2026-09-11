-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Localized global functions for better performance
local assert = assert
local setmetatable = setmetatable
local string_format = string.format
local table_insert = table.insert
local table_remove = table.remove

--- Define the Queue class.<br>
--- A FIFO (First-In-First-Out) queue where items are processed in the order they were added.<br>
--- Perfect for task processing, message passing, or any scenario where order of operations matters.
---@class Queue
---@field [1] table Container table storing the queue items
local Queue = {}
Queue.__index = Queue

--- Create a new Queue instance.<br>
--- A FIFO (First-In-First-Out) queue data structure.
---@return Queue queue New Queue instance.
---@usage <br>
--- ```
--- local queue = Queue.new()
--- queue:enqueue(1)
--- queue:enqueue(2)
--- ```
function Queue.new()
	return setmetatable({ {} }, Queue)
end

Queue.__call = Queue.new

--- Get the number of items using `#` operator.<br>
--- Allows using `#queue` instead of `queue:count()`.
---@param self Queue The queue instance.
---@return integer count Number of items in the queue.
---@usage <br>
--- ```
--- local queue = Queue.new()
--- queue:enqueue(1)
--- queue:enqueue(2)
--- print(#queue) -- 2
--- ```
function Queue.__len(self)
	return #self[1]
end

function Queue._iter_pairs(self, index)
	index = index + 1
	if index <= #self[1] then
		return index, self[1][index]
	end
end

--- Iterate over queue items using `pairs()`.<br>
--- Yields index and value for each item (front to back, 1-based).
---@param self Queue The queue instance.
---@return function iterator Iterator that yields index and value pairs.
---@return table state The queue instance used as iterator state.
---@return integer initial Initial control variable.
---@usage <br>
--- ```
--- local queue = Queue.new()
--- queue:enqueue(1)
--- queue:enqueue(2)
--- for index, value in pairs(queue) do
---   print(index, value)
--- end
--- ```
function Queue.__pairs(self)
	return Queue._iter_pairs, self, 0
end

--- Iterate over queue items using `ipairs()`.<br>
--- Yields index and value for each item (front to back, 1-based).
---@param self Queue The queue instance.
---@return function iterator Iterator that yields index and value pairs.
---@return table state The queue instance used as iterator state.
---@return integer initial Initial control variable.
function Queue.__ipairs(self)
	return Queue._iter_pairs, self, 0
end

--- Get string representation of the queue.<br>
--- Returns a string showing the count.
---@param self Queue The queue instance.
---@return string string String representation of the queue.
---@usage <br>
--- ```
--- local queue = Queue.new()
--- queue:enqueue(1)
--- queue:enqueue(2)
--- print(tostring(queue)) -- "Queue(count=2)"
--- ```
function Queue.__tostring(self)
	return string_format("Queue(count=%d)", #self[1])
end

--- Get the number of items in the queue.
---@param self Queue The queue instance.
---@return integer count Number of items in the queue.
---@usage <br>
--- ```
--- local queue = Queue.new()
--- queue:enqueue(1)
--- queue:enqueue(2)
--- print(queue:count()) -- 2
--- ```
function Queue.count(self)
	return #self[1]
end

--- Check if the queue is empty.
---@param self Queue The queue instance.
---@return boolean empty `true` if the queue is empty, `false` otherwise.
---@usage <br>
--- ```
--- local queue = Queue.new()
--- print(queue:isEmpty()) -- true
--- queue:enqueue(1)
--- print(queue:isEmpty()) -- false
--- ```
function Queue.isEmpty(self)
	return #self[1] == 0
end

--- Clear all items from the queue.
---@param self Queue The queue instance.
---@usage <br>
--- ```
--- local queue = Queue.new()
--- queue:enqueue(1)
--- queue:enqueue(2)
--- queue:clear()
--- print(queue:isEmpty()) -- true
--- ```
function Queue.clear(self)
	self[1] = {}
end

--- Add a value to the back of the queue (enqueue).<br>
--- Items are dequeued in the order they were enqueued (FIFO).
---@param self Queue The queue instance.
---@param value any The value to add (cannot be `nil`).
---@usage <br>
--- ```
--- local queue = Queue.new()
--- queue:enqueue(1)
--- queue:enqueue(2)
--- print(queue:dequeue()) -- 1
--- ```
function Queue.enqueue(self, value)
	assert(value ~= nil, "cannot add a nil value to the queue")
	table_insert(self[1], value)
end

--- Remove and return the first value from the queue (dequeue).<br>
--- Returns `nil` if the queue is empty.
---@param self Queue The queue instance.
---@return any value The dequeued value, or `nil` if empty.
---@usage <br>
--- ```
--- local queue = Queue.new()
--- queue:enqueue(1)
--- queue:enqueue(2)
--- local value = queue:dequeue()
--- print(value) -- 1
--- ```
function Queue.dequeue(self)
	if #self[1] == 0 then
		return
	end
	return table_remove(self[1], 1)
end

--- Return the first value from the queue without removing it (peek).<br>
--- Returns `nil` if the queue is empty.
---@param self Queue The queue instance.
---@return any value The first value, or `nil` if empty.
---@usage <br>
--- ```
--- local queue = Queue.new()
--- queue:enqueue(1)
--- queue:enqueue(2)
--- print(queue:peek()) -- 1
--- print(queue:count()) -- 2 (still has both items)
--- ```
function Queue.peek(self)
	if #self[1] == 0 then
		return
	end
	return self[1][1]
end

function Queue._iter_values(self, index)
	index = index + 1
	if index <= #self[1] then
		return self[1][index]
	end
end

--- Return an iterator over the queue from front to back.<br>
--- Yields each value in the queue in FIFO order.
---@param self Queue The queue instance.
---@return function iterator Iterator that yields each value.
---@return table state The queue instance used as iterator state.
---@return integer initial Initial control variable.
---@usage <br>
--- ```
--- local queue = Queue.new()
--- queue:enqueue(1)
--- queue:enqueue(2)
--- queue:enqueue(3)
--- for value in queue:iterator() do
---   print(value)
--- end
--- -- Outputs: 1, 2, 3
--- ```
function Queue.iterator(self)
	return Queue._iter_values, self, 0
end

-- Deprecated aliases (naming standard: snake_case). Kept for compatibility.
Queue.is_empty = Queue.isEmpty

-- Export
return Queue
