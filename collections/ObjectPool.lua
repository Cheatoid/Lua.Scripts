-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Localized global functions for better performance
local error = error
local setmetatable = setmetatable
local type = type
local string_format = string.format

--- Define the ObjectPool class.<br>
--- A performance-optimized object pool using array storage and optional maximum capacity.<br>
--- Prevents frequent garbage collection by reusing objects, with O(1) get/release and automatic overflow handling.
---@class ObjectPool
---@field [1] table Array storing the available objects
---@field [2] integer Current number of available objects in pool
---@field [3] function Factory function to create new objects
---@field [4] function|nil Optional reset function to clean up objects before returning to pool
---@field [5] integer Maximum capacity of the pool (0 for unbounded)
local ObjectPool = {}
ObjectPool.__index = ObjectPool

--- Create a new ObjectPool instance.<br>
--- The pool grows dynamically as needed.<br>
--- If `maxSize` is provided and greater than 0, the pool will discard objects when releasing if it is already full.
---@param factory function Factory function to create new objects.
---@param reset? function|integer Optional reset function to clean up objects before returning to pool, or maximum capacity if integer.
---@param maxSize? integer Optional maximum number of objects to keep in the pool. 0 or nil for unbounded.
---@return ObjectPool pool New ObjectPool instance.
---@usage <br>
--- ```
--- local pool = ObjectPool.new(function() return {} end, function(obj) obj.val = nil end, 5)
--- ```
function ObjectPool.new(factory, reset, maxSize)
	if type(factory) ~= "function" then
		return error("ObjectPool requires a factory function", 2)
	end
	if type(reset) == "number" then
		maxSize = reset
		reset = nil
	elseif type(reset) ~= "function" and reset ~= nil then
		return error("ObjectPool reset must be a function or nil", 2)
	end
	return setmetatable({
		{},
		0,
		factory,
		reset,
		maxSize or 0,
	}, ObjectPool)
end

ObjectPool.__call = ObjectPool.new

--- Get the number of available objects using `#` operator.<br>
--- Allows using `#pool` instead of `pool:count()`.
---@param self ObjectPool The pool instance.
---@return integer count Number of available objects in the pool.
---@usage <br>
--- ```
--- local pool = ObjectPool.new(function() return {} end)
--- pool:fill(2)
--- print(#pool) -- 2
--- ```
function ObjectPool.__len(self)
	return self[2]
end

--- Iterate over available objects using `pairs()`.<br>
--- Yields index and value for each available object.
---@param self ObjectPool The pool instance.
---@return function iterator Iterator that yields index and value pairs.
---@usage <br>
--- ```
--- local pool = ObjectPool.new(function() return {} end)
--- pool:fill(2)
--- for index, value in pairs(pool) do
---   print(index, value)
--- end
--- ```
function ObjectPool.__pairs(self)
	return ObjectPool.iterator(self)
end

--- Iterate over available objects using `ipairs()`.<br>
--- Same as `pairs()` for ObjectPool.
---@param self ObjectPool The pool instance.
---@return function iterator Iterator that yields index and value pairs.
function ObjectPool.__ipairs(self)
	return ObjectPool.iterator(self)
end

--- Get string representation of the pool.<br>
--- Returns a string showing available count and maxSize if bounded.
---@param self ObjectPool The pool instance.
---@return string string String representation of the pool.
---@usage <br>
--- ```
--- local pool = ObjectPool.new(function() return {} end, 5)
--- pool:fill(2)
--- print(tostring(pool)) -- "ObjectPool(available=2, maxSize=5)"
--- ```
function ObjectPool.__tostring(self)
	if self[5] > 0 then
		return string_format("ObjectPool(available=%d, maxSize=%d)", self[2], self[5])
	end
	return string_format("ObjectPool(available=%d)", self[2])
end

--- Get an object from the pool.<br>
--- If the pool is empty, a new object will be created using the factory function.
---@param self ObjectPool The pool instance.
---@return any obj The retrieved or newly created object.
---@usage <br>
--- ```
--- local pool = ObjectPool.new(function() return { active = false } end)
--- local obj = pool:get()
--- ```
function ObjectPool.get(self)
	if self[2] > 0 then
		self[2] = self[2] - 1
		local obj = self[1][self[2] + 1]
		self[1][self[2] + 1] = nil
		return obj
	end
	return self[3]()
end

--- Return an object to the pool.<br>
--- If a reset function was provided, it will be called on the object before returning it.<br>
--- If the pool is bounded and full, the object will be discarded (garbage collected).
---@param self ObjectPool The pool instance.
---@param value any The object to return to the pool.
---@usage <br>
--- ```
--- local pool = ObjectPool.new(function() return {} end, function(obj) obj.val = nil end)
--- local obj = pool:get()
--- pool:release(obj)
--- ```
function ObjectPool.release(self, value)
	if self[4] then
		self[4](value)
	end
	if self[5] == 0 or self[2] < self[5] then
		self[2] = self[2] + 1
		self[1][self[2]] = value
	end
end

--- Pre-allocate a specified number of objects into the pool.<br>
--- Objects are created using the factory function.<br>
--- Will not exceed `maxSize` if bounded.
---@param self ObjectPool The pool instance.
---@param count integer Number of objects to pre-allocate.
---@usage <br>
--- ```
--- local pool = ObjectPool.new(function() return {} end, 5)
--- pool:fill(3)
--- ```
function ObjectPool.fill(self, count)
	for _ = 1, count do
		if self[5] > 0 and self[2] >= self[5] then
			break
		end
		self[2] = self[2] + 1
		self[1][self[2]] = self[3]()
	end
end

--- Remove all available objects from the pool.
---@param self ObjectPool The pool instance.
---@usage <br>
--- ```
--- local pool = ObjectPool.new(function() return {} end)
--- pool:fill(3)
--- pool:clear()
--- print(#pool) -- 0
--- ```
function ObjectPool.clear(self)
	self[1] = {}
	self[2] = 0
end

--- Get the number of available objects currently in the pool.
---@param self ObjectPool The pool instance.
---@return integer count Number of available objects in the pool.
---@usage <br>
--- ```
--- local pool = ObjectPool.new(function() return {} end)
--- pool:fill(2)
--- print(pool:count()) -- 2
--- ```
function ObjectPool.count(self)
	return self[2]
end

function ObjectPool._iter(state, index)
	index = index + 1
	if index <= state[1] then
		return index, state[2][index]
	end
end

--- Return an iterator over the available objects in the pool.<br>
--- Yields index and value for each available object.
---@param self ObjectPool The pool instance.
---@return function iterator Iterator that yields index and value pairs.
---@return table state The iterator state table.
---@return integer initial Initial control variable.
---@usage <br>
--- ```
--- local pool = ObjectPool.new(function() return {} end)
--- pool:fill(2)
--- for index, value in pool:iterator() do
---   print(index, value)
--- end
--- ```
function ObjectPool.iterator(self)
	return ObjectPool._iter, {
		self[2],
		self[1],
	}, 0
end

-- Export
return ObjectPool
