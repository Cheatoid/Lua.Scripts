-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Localized global functions for better performance
local assert = assert
local setmetatable = setmetatable
local string_format = string.format

-- Import Heap
local Heap = require "Heap"

--- Define the PriorityQueue class.<br>
--- A queue backed by a heap where items are retrieved by priority. Items with higher priority are dequeued first.<br>
--- Perfect for task scheduling, event systems, or any scenario where processing order matters.
---@class PriorityQueue
---@field [1] Heap Internal heap for priority ordering
local PriorityQueue = {}
PriorityQueue.__index = PriorityQueue

--- Max-heap comparison function for priority queue.<br>
--- Higher priority values will be at the top.
---@param a table First priority-item pair `{priority, item}`.
---@param b table Second priority-item pair `{priority, item}`.
---@return boolean result `true` if a should be above b in the heap.
function PriorityQueue.MaxHeapComparer(a, b) return a[1] > b[1] end

--- Min-heap comparison function for priority queue.<br>
--- Lower priority values will be at the top.
---@param a table First priority-item pair `{priority, item}`.
---@param b table Second priority-item pair `{priority, item}`.
---@return boolean result `true` if a should be above b in the heap.
function PriorityQueue.MinHeapComparer(a, b) return a[1] < b[1] end

--- Create a new PriorityQueue instance.<br>
--- A priority queue backed by a heap, items are retrieved by priority.
---@param comp? function Comparison function (default: min-heap by priority).
---@return PriorityQueue queue New PriorityQueue instance.
---@usage <br>
--- ```
--- local queue = PriorityQueue.new()
--- queue:push(3, "low")
--- queue:push(1, "high")
--- queue:push(2, "medium")
--- print(queue:pop()) -- "high" (priority 1)
--- ```
function PriorityQueue.new(comp)
	return setmetatable({
		Heap.new(comp or PriorityQueue.MinHeapComparer),
	}, PriorityQueue)
end

PriorityQueue.__call = PriorityQueue.new

--- Get the number of items using `#` operator.<br>
--- Allows using `#queue` instead of `queue:count()`.
---@param self PriorityQueue The priority queue instance.
---@return integer count Number of items in the queue.
---@usage <br>
--- ```
--- local queue = PriorityQueue.new()
--- queue:push(1, "item1")
--- queue:push(2, "item2")
--- print(#queue) -- 2
--- ```
function PriorityQueue.__len(self)
	return #self[1][1]
end

function PriorityQueue._iter_pairs(self, index)
	index = index + 1
	local array = self[1][1]
	if index <= #array then
		return index, array[index][2]
	end
end

--- Iterate over priority queue items using `pairs()`.<br>
--- Yields index and value (item) for each item (heap array order, 1-based).
---@param self PriorityQueue The priority queue instance.
---@return function iterator Iterator that yields index and value pairs.
---@return table state The priority queue instance used as iterator state.
---@return integer initial Initial control variable.
---@usage <br>
--- ```
--- local queue = PriorityQueue.new()
--- queue:push(1, "item1")
--- queue:push(2, "item2")
--- for index, value in pairs(queue) do
---   print(index, value)
--- end
--- ```
function PriorityQueue.__pairs(self)
	return PriorityQueue._iter_pairs, self, 0
end

--- Iterate over priority queue items using `ipairs()`.<br>
--- Yields index and value (item) for each item (heap array order, 1-based).
---@param self PriorityQueue The priority queue instance.
---@return function iterator Iterator that yields index and value pairs.
---@return table state The priority queue instance used as iterator state.
---@return integer initial Initial control variable.
function PriorityQueue.__ipairs(self)
	return PriorityQueue._iter_pairs, self, 0
end

--- Get string representation of the priority queue.<br>
--- Returns a string showing the count.
---@param self PriorityQueue The priority queue instance.
---@return string string String representation of the priority queue.
---@usage <br>
--- ```
--- local queue = PriorityQueue.new()
--- queue:push(1, "item1")
--- queue:push(2, "item2")
--- print(tostring(queue)) -- "PriorityQueue(count=2)"
--- ```
function PriorityQueue.__tostring(self)
	return string_format("PriorityQueue(count=%d)", #self[1][1])
end

--- Get the number of items in the priority queue.
---@param self PriorityQueue The priority queue instance.
---@return integer count Number of items in the queue.
---@usage <br>
--- ```
--- local queue = PriorityQueue.new()
--- queue:push(1, "item1")
--- queue:push(2, "item2")
--- print(queue:count()) -- 2
--- ```
function PriorityQueue.count(self)
	return #self[1][1]
end

--- Check if the priority queue is empty.
---@param self PriorityQueue The priority queue instance.
---@return boolean empty `true` if the queue is empty, `false` otherwise.
---@usage <br>
--- ```
--- local queue = PriorityQueue.new()
--- print(queue:isEmpty()) -- true
--- queue:push(1, "item1")
--- print(queue:isEmpty()) -- false
--- ```
function PriorityQueue.isEmpty(self)
	return #self[1][1] == 0
end

--- Clear all items from the priority queue.
---@param self PriorityQueue The priority queue instance.
---@usage <br>
--- ```
--- local queue = PriorityQueue.new()
--- queue:push(1, "item1")
--- queue:push(2, "item2")
--- queue:clear()
--- print(queue:isEmpty()) -- true
--- ```
function PriorityQueue.clear(self)
	Heap.clear(self[1])
end

--- Add an item with a given priority to the queue.<br>
--- Lower priority values are retrieved first (by default).
---@param self PriorityQueue The priority queue instance.
---@param priority number Priority value (lower = higher priority by default).
---@param item any The item to add (cannot be `nil`).
---@usage <br>
--- ```
--- local queue = PriorityQueue.new()
--- queue:push(3, "low priority")
--- queue:push(1, "high priority")
--- print(queue:pop()) -- "high priority"
--- ```
function PriorityQueue.push(self, priority, item)
	assert(item ~= nil, "cannot add a nil value to the priority queue")
	Heap.push(self[1], { priority, item })
end

--- Remove and return the item with the highest priority.<br>
--- Returns `nil` if the queue is empty.
---@param self PriorityQueue The priority queue instance.
---@return any item The item with highest priority, or `nil` if empty.
---@usage <br>
--- ```
--- local queue = PriorityQueue.new()
--- queue:push(3, "low")
--- queue:push(1, "high")
--- local item = queue:pop()
--- print(item) -- "high"
--- ```
function PriorityQueue.pop(self)
	if PriorityQueue.isEmpty(self) then
		return
	end
	return Heap.pop(self[1])[2]
end

--- Return the item with the highest priority without removing it.<br>
--- Returns `nil` if the queue is empty.
---@param self PriorityQueue The priority queue instance.
---@return any item The item with highest priority, or `nil` if empty.
---@usage <br>
--- ```
--- local queue = PriorityQueue.new()
--- queue:push(3, "low")
--- queue:push(1, "high")
--- print(queue:peek()) -- "high"
--- print(queue:count()) -- 2 (still has both items)
--- ```
function PriorityQueue.peek(self)
	if PriorityQueue.isEmpty(self) then
		return
	end
	return self[1][1][1][2]
end

function PriorityQueue._iter_values(self, index)
	index = index + 1
	local array = self[1][1]
	if index <= #array then
		return array[index][2]
	end
end

--- Return an iterator over the priority queue items.<br>
--- Yields each item (not the priority-item pair) in heap array order.
---@param self PriorityQueue The priority queue instance.
---@return function iterator Iterator that yields each item.
---@return table state The priority queue instance used as iterator state.
---@return integer initial Initial control variable.
---@usage <br>
--- ```
--- local queue = PriorityQueue.new()
--- queue:push(1, "a")
--- queue:push(2, "b")
--- queue:push(3, "c")
--- for item in queue:iterator() do
---   print(item)
--- end
--- ```
function PriorityQueue.iterator(self)
	return PriorityQueue._iter_values, self, 0
end

-- Deprecated aliases (naming standard: snake_case). Kept for compatibility.
PriorityQueue.is_empty = PriorityQueue.isEmpty

-- Export
return PriorityQueue
