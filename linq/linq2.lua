-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- LINQ API for Lua tables and iterables.

local table_concat = table.concat

---@class Linq
local Linq = {}

-- ################################################################
-- #                       HELPER CLASSES                         #
-- ################################################################

--- Represents a sorted sequence that supports subsequent sorting (ThenBy).
---@class OrderedEnumerable : Linq
local OrderedEnumerable = {}
OrderedEnumerable.__index = OrderedEnumerable
setmetatable(OrderedEnumerable, { __index = Linq }) -- Inherit from Linq base

-- ################################################################
-- #                       CORE CLASS                             #
-- ################################################################

--- The main LINQ wrapper class.<br>
--- Acts as the container for the data source and all extension methods.
---@class Enumerable
local Enumerable = {}
Enumerable.__index = Enumerable

--- Creates a new Enumerable instance.
---@param source table The table to wrap (can be a map or an array).
---@return Enumerable
local function Linq_new(source)
	local t = type(source)
	if t ~= "table" and t ~= "nil" then
		return error("Linq source must be a table or nil.", 2)
	end

	local self = setmetatable({}, Enumerable)
	self._source = source or {}
	self._iterator = nil -- For lazy evaluation
	return self
end

Linq.new = Linq_new

-- Allows Linq(table) syntax to act as a constructor.
setmetatable(Linq, {
	---@param source table
	---@return Enumerable
	__call = function(_, source)
		return Linq.new(source)
	end
})

-- ################################################################
-- #                   ITERATOR / LAZY LOGIC                      #
-- ################################################################

--- Internal: Creates an iterator for the source.<br>
--- Handles both array and map iterations.
local function getSourceIterator(source)
	local t = type(source)
	if t == "function" then return source end -- Already an iterator

	return coroutine.wrap(function()
		if type(source) == "table" then
			-- Try ipairs first (arrays), then pairs (maps)
			-- LINQ usually treats sources as sequences.
			-- We enforce integer key iteration for ordered operations,
			-- but keep pairs for generic ToDictionary etc.
			--local isSequence = true
			for i = 1, #source do
				coroutine.yield(source[i], i)
			end
		end
	end)
end

--- Internal: Materializes the iterator into a table array.
local function materialize(self)
	if self._iterator then
		self._source = {}
		local i = 0
		for val in self._iterator do
			i = i + 1
			self._source[i] = val
		end
		self._iterator = nil
	end
	return self._source
end

--- Default iterator for `for k, v in enum:iter() do ... end`.
function Enumerable:iter()
	self:materialize()
	local i = 0
	local source = self._source
	return function()
		i = i + 1
		return source[i]
	end
end

-- ################################################################
-- #                 PROJECTION & FILTERING                       #
-- ################################################################

--- Filters a sequence of values based on a predicate.
---@param predicate fun(value: any, index: integer): boolean
---@return Enumerable
function Enumerable:Where(predicate)
	if type(predicate) ~= "function" then return error("Predicate must be a function", 2) end

	local prevIterator = self._iterator or getSourceIterator(self._source)
	local index = 0

	local nextIterator = function()
		while true do
			local val, key = prevIterator() -- key might be index from source
			if val == nil then return nil end
			index = index + 1
			if predicate(val, index) then
				return val
			end
		end
	end

	local newEnum = Linq.new({})
	newEnum._iterator = nextIterator
	return newEnum
end

--- Projects each element of a sequence into a new form.
---@param selector fun(value: any, index: integer): any
---@return Enumerable
function Enumerable:Select(selector)
	if type(selector) ~= "function" then return error("Selector must be a function", 2) end

	local prevIterator = self._iterator or getSourceIterator(self._source)
	local index = 0

	local nextIterator = function()
		local val = prevIterator()
		if val == nil then return nil end
		index = index + 1
		return selector(val, index)
	end

	local newEnum = Linq.new({})
	newEnum._iterator = nextIterator
	return newEnum
end

--- Projects each element of a sequence to an Enumerable and flattens the resulting sequences into one sequence.
---@param collectionSelector fun(value: any, index: integer): table
---@param resultSelector? fun(value: any, collectionValue: any): any
---@return Enumerable
function Enumerable:SelectMany(collectionSelector, resultSelector)
	if type(collectionSelector) ~= "function" then return error("CollectionSelector must be a function", 2) end

	local prevIterator = self._iterator or getSourceIterator(self._source)
	local index = 0
	local currentCollection
	local currentCollectionIndex = 0
	local currentSourceValue

	local nextIterator = function()
		while true do
			-- If we have an active collection, iterate it
			if currentCollection then
				currentCollectionIndex = currentCollectionIndex + 1
				local innerVal = currentCollection[currentCollectionIndex]
				if innerVal ~= nil then
					if resultSelector then
						return resultSelector(currentSourceValue, innerVal)
					end
					return innerVal
				else
					currentCollection = nil -- Exhausted
				end
			end

			-- Get next source item
			local val = prevIterator()
			if val == nil then return nil end
			index = index + 1
			currentSourceValue = val

			-- Get collection for this source item
			local result = collectionSelector(val, index)
			if type(result) ~= "table" then return error("SelectMany selector must return a table", 2) end

			if #result > 0 then
				currentCollection = result
				currentCollectionIndex = 0
				-- Loop back to start iterating this collection
			else
				-- Empty collection, loop to next source item immediately
			end
		end
	end

	local newEnum = Linq.new({})
	newEnum._iterator = nextIterator
	return newEnum
end

-- ################################################################
-- #                    ORDERING                                  #
-- ################################################################

--- Helper to materialize with original index for stable sorting
local function materializeWithIndex(self)
	local data = materialize(self)
	for i = 1, #data do
		data[i] = { value = data[i], index = i }
	end
	return data
end

--- Comparator that uses original index as final tie-breaker for stability
local function createCompositeComparer(criteria)
	return function(a, b)
		for _, c in ipairs(criteria) do
			local va = c.selector(a.value)
			local vb = c.selector(b.value)
			if c.comparer then
				if c.comparer(va, vb) then return not c.desc end
				if c.comparer(vb, va) then return c.desc end
			else
				if va < vb then return not c.desc end
				if va > vb then return c.desc end
			end
		end
		return a.index < b.index
	end
end

local function getSorter(keySelector, comparer, descending)
	return function(a, b)
		local keyA = keySelector(a)
		local keyB = keySelector(b)

		if comparer then
			local result = comparer(keyA, keyB)
			return descending and not result or result
		end

		-- Default Lua comparison
		if descending then
			return keyA > keyB
		end
		return keyA < keyB
	end
end

--- Sorts the elements of a sequence in ascending order according to a key.
---@param keySelector fun(value: any): any
---@param comparer? fun(a: any, b: any): boolean
---@return OrderedEnumerable
function Enumerable:OrderBy(keySelector, comparer)
	if type(keySelector) ~= "function" then return error("KeySelector must be a function", 2) end
	local data = materializeWithIndex(self)
	table.sort(data, createCompositeComparer({ { selector = keySelector, comparer = comparer, desc = false } }))
	local sortedValues = {}
	for i, entry in ipairs(data) do sortedValues[i] = entry.value end

	local ordered = setmetatable(Linq.new(sortedValues), OrderedEnumerable)
	ordered._sortCriteria = { { selector = keySelector, comparer = comparer, desc = false } }
	return ordered
end

--- Sorts the elements of a sequence in descending order according to a key.
---@param keySelector fun(value: any): any
---@param comparer? fun(a: any, b: any): boolean
---@return OrderedEnumerable
function Enumerable:OrderByDescending(keySelector, comparer)
	if type(keySelector) ~= "function" then return error("KeySelector must be a function", 2) end
	local data = materializeWithIndex(self)
	table.sort(data, createCompositeComparer({ { selector = keySelector, comparer = comparer, desc = true } }))
	local sortedValues = {}
	for i, entry in ipairs(data) do sortedValues[i] = entry.value end

	local ordered = setmetatable(Linq.new(sortedValues), OrderedEnumerable)
	ordered._sortCriteria = { { selector = keySelector, comparer = comparer, desc = true } }
	return ordered
end

--- Performs a subsequent ordering of the elements in a sequence in ascending order.
---@param keySelector fun(value: any): any
---@param comparer? fun(a: any, b: any): boolean
---@return OrderedEnumerable
function OrderedEnumerable:ThenBy(keySelector, comparer)
	if type(keySelector) ~= "function" then return error("KeySelector must be a function", 2) end
	local criteria = {}
	for _, v in ipairs(self._sortCriteria) do table.insert(criteria, v) end
	table.insert(criteria, { selector = keySelector, comparer = comparer, desc = false })

	local data = materializeWithIndex(self)
	table.sort(data, createCompositeComparer(criteria))
	local sortedValues = {}
	for i, entry in ipairs(data) do sortedValues[i] = entry.value end
	self._source = sortedValues
	self._sortCriteria = criteria
	return self
end

--- Performs a subsequent ordering of the elements in a sequence in descending order.
---@param keySelector fun(value: any): any
---@param comparer? fun(a: any, b: any): boolean
---@return OrderedEnumerable
function OrderedEnumerable:ThenByDescending(keySelector, comparer)
	if type(keySelector) ~= "function" then return error("KeySelector must be a function", 2) end
	local criteria = {}
	for _, v in ipairs(self._sortCriteria) do table.insert(criteria, v) end
	table.insert(criteria, { selector = keySelector, comparer = comparer, desc = true })

	local data = materializeWithIndex(self)
	table.sort(data, createCompositeComparer(criteria))
	local sortedValues = {}
	for i, entry in ipairs(data) do sortedValues[i] = entry.value end
	self._source = sortedValues
	self._sortCriteria = criteria
	return self
end

--- Reverses the order of the elements in a sequence.
---@return Enumerable
function Enumerable:Reverse()
	local data = materialize(self)
	local n = #data
	local i = 1
	while i < n do
		data[i], data[n] = data[n], data[i]
		i = i + 1
		n = n - 1
	end
	return Linq.new(data)
end

-- ################################################################
-- #                 JOIN & GROUPING                              #
-- ################################################################

--- Correlates the elements of two sequences based on matching keys.
---@param inner table The sequence to join to the first sequence.
---@param outerKeySelector fun(outerValue: any): any
---@param innerKeySelector fun(innerValue: any): any
---@param resultSelector fun(outerValue: any, innerValue: any): any
---@return Enumerable
function Enumerable:Join(inner, outerKeySelector, innerKeySelector, resultSelector)
	if not inner or type(inner) ~= "table" then return error("Inner must be a table", 2) end
	if type(outerKeySelector) ~= "function" or type(innerKeySelector) ~= "function" then
		return error("Selectors must be functions", 2)
	end

	local outerData = materialize(self)
	local innerLookup = Linq.new(inner):ToLookup(innerKeySelector)

	local result = {}

	for _, outerVal in ipairs(outerData) do
		local key = outerKeySelector(outerVal)
		local innerMatches = innerLookup[key]
		if innerMatches then
			for _, innerVal in ipairs(innerMatches) do
				table.insert(result, resultSelector(outerVal, innerVal))
			end
		end
	end

	return Linq.new(result)
end

--- Groups the elements of a sequence according to a specified key selector function.
---@param keySelector fun(value: any): any
---@param elementSelector? fun(value: any): any (optional, defaults to identity)
---@param resultSelector? fun(key: any, group: Enumerable): any (optional)
---@return Enumerable
function Enumerable:GroupBy(keySelector, elementSelector, resultSelector)
	if type(keySelector) ~= "function" then return error("KeySelector must be a function", 2) end

	local data = materialize(self)
	local lookup = {} -- Key -> { elements }

	for _, v in ipairs(data) do
		local key = keySelector(v)
		local element = v
		if elementSelector then element = elementSelector(v) end

		if not lookup[key] then lookup[key] = {} end
		table.insert(lookup[key], element)
	end

	local result = {}
	if resultSelector then
		for k, group in next, lookup do
			table.insert(result, resultSelector(k, Linq.new(group)))
		end
	else
		-- Default returns table with Key and Group fields if we mimic C# IGrouping,
		-- but for Lua simplicity we return a table { key = k, values = group }
		for k, group in next, lookup do
			table.insert(result, { key = k, values = Linq.new(group) })
		end
	end

	return Linq.new(result)
end

-- ################################################################
-- #                 AGGREGATION                                  #
-- ################################################################

--- Applies an accumulator function over a sequence.
---@param seed any The initial accumulator value.
---@param func fun(accumulator: any, value: any): any
---@return any
function Enumerable:Aggregate(seed, func)
	if type(func) ~= "function" then return error("Func must be a function", 2) end
	local data = materialize(self)
	local acc = seed
	for _, v in ipairs(data) do
		acc = func(acc, v)
	end
	return acc
end

--- Computes the sum of the sequence of numeric values.
---@param selector? fun(value: any): number
---@return number
function Enumerable:Sum(selector)
	local sum = 0
	local data = materialize(self)
	for _, v in ipairs(data) do
		local val = selector and selector(v) or v
		if type(val) ~= "number" then return error("Sum requires numeric values", 2) end
		sum = sum + val
	end
	return sum
end

--- Computes the average of a sequence of numeric values.
---@param selector? fun(value: any): number
---@return number
function Enumerable:Average(selector)
	local sum, count = 0, 0
	local data = materialize(self)
	for _, v in ipairs(data) do
		local val = selector and selector(v) or v
		if type(val) ~= "number" then return error("Average requires numeric values", 2) end
		sum = sum + val
		count = count + 1
	end
	if count == 0 then return error("Sequence contains no elements", 2) end
	return sum / count
end

--- Returns the number of elements in a sequence.
---@param predicate? fun(value: any): boolean
---@return number
function Enumerable:Count(predicate)
	local data = materialize(self)
	if not predicate then return #data end

	local count = 0
	for _, v in ipairs(data) do
		if predicate(v) then count = count + 1 end
	end
	return count
end

--- Returns the maximum value in a sequence.
---@param selector? fun(value: any): any
---@return any
function Enumerable:Max(selector)
	local data = materialize(self)
	if #data == 0 then return nil end

	local maxVal = selector and selector(data[1]) or data[1]
	for i = 2, #data do
		local current = selector and selector(data[i]) or data[i]
		if current > maxVal then maxVal = current end
	end
	return maxVal
end

--- Returns the minimum value in a sequence.
---@param selector? fun(value: any): any
---@return any
function Enumerable:Min(selector)
	local data = materialize(self)
	if #data == 0 then return nil end

	local minVal = selector and selector(data[1]) or data[1]
	for i = 2, #data do
		local current = selector and selector(data[i]) or data[i]
		if current < minVal then minVal = current end
	end
	return minVal
end

-- ################################################################
-- #                 ELEMENT OPERATIONS                           #
-- ################################################################

--- Returns the first element of a sequence.
---@param predicate? fun(value: any): boolean
---@return any
function Enumerable:First(predicate)
	local iter = self._iterator or getSourceIterator(self._source)

	if predicate then
		while true do
			local val = iter()
			if val == nil then break end
			if predicate(val) then return val end
		end
	else
		local val = iter()
		if val ~= nil then return val end
	end

	return error("Sequence contains no matching element", 2)
end

--- Returns the first element of a sequence, or a default value if no element is found.
---@param defaultValue any
---@param predicate? fun(value: any): boolean
---@return any
function Enumerable:FirstOrDefault(defaultValue, predicate)
	local ok, val = pcall(self.First, self, predicate)
	if ok then return val end
	return defaultValue
end

--- Returns the last element of a sequence.
---@param predicate? fun(value: any): boolean
---@return any
function Enumerable:Last(predicate)
	local data = materialize(self)
	if predicate then
		local last
		for _, v in ipairs(data) do
			if predicate(v) then last = v end
		end
		if last then return last end
	else
		if #data > 0 then return data[#data] end
	end
	return error("Sequence contains no matching element", 2)
end

--- Returns the last element of a sequence, or a default value if no element is found.
---@param defaultValue any
---@param predicate? fun(value: any): boolean
---@return any
function Enumerable:LastOrDefault(defaultValue, predicate)
	local ok, val = pcall(self.Last, self, predicate)
	if ok then return val end
	return defaultValue
end

--- Returns the element at a specified index in a sequence.
---@param index number
---@return any
function Enumerable:ElementAt(index)
	if index < 1 then return error("Index out of range (Lua indices start at 1)", 2) end
	local iter = self._iterator or getSourceIterator(self._source)
	for i = 1, index do
		local val = iter()
		if val == nil then return error("Index out of range", 2) end
		if i == index then return val end
	end
end

--- Returns the element at a specified index in a sequence or a default value if the index is out of range.
---@param index number
---@param defaultValue any
---@return any
function Enumerable:ElementAtOrDefault(index, defaultValue)
	local ok, val = pcall(self.ElementAt, self, index)
	if ok then return val end
	return defaultValue
end

--- Returns the only element of a sequence, and throws an exception if there is not exactly one element in the sequence.
---@param predicate? fun(value: any): boolean
---@return any
function Enumerable:Single(predicate)
	local found
	local count = 0
	local iter = self._iterator or getSourceIterator(self._source)

	while true do
		local val = iter()
		if val == nil then break end
		if not predicate or predicate(val) then
			found = val
			count = count + 1
		end
	end

	if count == 1 then return found end
	if count == 0 then return error("Sequence contains no matching element", 2) end
	return error("Sequence contains more than one matching element", 2)
end

--- Returns the only element of a sequence, or a default value if the sequence is empty.<br>
--- This method throws an exception if there is more than one element in the sequence.
---@param defaultValue any
---@param predicate? fun(value: any): boolean
---@return any
function Enumerable:SingleOrDefault(defaultValue, predicate)
	local ok, val = pcall(self.Single, self, predicate)
	if ok then return val end
	-- If error was "no matching element", return default. Otherwise rethrow.
	-- For simplicity:
	local found
	local count = 0
	local iter = self._iterator or getSourceIterator(self._source)

	while true do
		local val = iter()
		if val == nil then break end
		if not predicate or predicate(val) then
			found = val
			count = count + 1
		end
	end

	if count == 1 then
		return found
	end
	if count == 0 then
		return defaultValue
	end
	return error("Sequence contains more than one matching element", 2)
end

-- ################################################################
-- #                 QUANTIFIERS                                  #
-- ################################################################

--- Determines whether a sequence contains any elements.
---@param predicate? fun(value: any): boolean
---@return boolean
function Enumerable:Any(predicate)
	local iter = self._iterator or getSourceIterator(self._source)

	if not predicate then
		return iter() ~= nil
	end

	while true do
		local val = iter()
		if val == nil then return false end
		if predicate(val) then return true end
	end
end

--- Determines whether all elements of a sequence satisfy a condition.
---@param predicate? fun(value: any): boolean
---@return boolean
function Enumerable:All(predicate)
	if type(predicate) ~= "function" then return error("Predicate must be a function", 2) end
	local iter = self._iterator or getSourceIterator(self._source)

	while true do
		local val = iter()
		if val == nil then return true end
		if not predicate(val) then return false end
	end
end

--- Determines whether a sequence contains a specified element.
---@param value any The value to locate.
---@param comparer? fun(a: any, b: any): boolean
---@return boolean
function Enumerable:Contains(value, comparer)
	local eq = comparer or function(a, b) return a == b end
	local iter = self._iterator or getSourceIterator(self._source)

	while true do
		local val = iter()
		if val == nil then return false end
		if eq(val, value) then return true end
	end
end

-- ################################################################
-- #                 SET OPERATIONS                               #
-- ################################################################

--- Returns distinct elements from a sequence.
---@param comparer? fun(a: any, b: any): boolean
---@return Enumerable
function Enumerable:Distinct(comparer)
	local data = materialize(self)
	local result = {}

	if not comparer then
		local seen = {}
		for _, v in ipairs(data) do
			if not seen[v] then
				seen[v] = true
				table.insert(result, v)
			end
		end
	else
		local seen = {}
		for _, v in ipairs(data) do
			local found = false
			for _, s in ipairs(seen) do
				if comparer(s, v) then
					found = true
					break
				end
			end
			if not found then
				table.insert(seen, v)
				table.insert(result, v)
			end
		end
	end

	return Linq.new(result)
end

--- Produces the set union of two sequences.
---@param second table
---@param comparer? fun(a: any, b: any): boolean
---@return Enumerable
function Enumerable:Union(second, comparer)
	if not second then return error("Second sequence is required", 2) end
	local combined = {}
	local data1 = materialize(self)
	local data2 = Linq.new(second):ToTable()

	for _, v in ipairs(data1) do table.insert(combined, v) end
	for _, v in ipairs(data2) do table.insert(combined, v) end

	return Linq.new(combined):Distinct(comparer)
end

--- Produces the set intersection of two sequences.
---@param second table
---@param comparer? fun(a: any, b: any): boolean
---@return Enumerable
function Enumerable:Intersect(second, comparer)
	if not second then return error("Second sequence is required", 2) end
	local result = {}
	local data1 = materialize(self)
	local data2 = Linq.new(second):ToTable()
	local eq = comparer or function(a, b) return a == b end

	for _, v1 in ipairs(data1) do
		for _, v2 in ipairs(data2) do
			if eq(v1, v2) then
				-- Check if already in result (to maintain distinctness)
				local exists = false
				for _, r in ipairs(result) do
					if eq(r, v1) then
						exists = true
						break
					end
				end
				if not exists then table.insert(result, v1) end
			end
		end
	end

	return Linq.new(result)
end

--- Produces the set difference of two sequences.
---@param second table
---@param comparer? fun(a: any, b: any): boolean
---@return Enumerable
function Enumerable:Except(second, comparer)
	if not second then return error("Second sequence is required", 2) end
	local result = {}
	local data1 = materialize(self)
	local data2 = Linq.new(second):ToTable()
	local eq = comparer or function(a, b) return a == b end

	for _, v1 in ipairs(data1) do
		local inSecond = false
		for _, v2 in ipairs(data2) do
			if eq(v1, v2) then
				inSecond = true
				break
			end
		end

		if not inSecond then
			local inResult = false
			for _, r in ipairs(result) do
				if eq(r, v1) then
					inResult = true
					break
				end
			end
			if not inResult then table.insert(result, v1) end
		end
	end

	return Linq.new(result)
end

-- ################################################################
-- #                 PARTITIONING                                 #
-- ################################################################

--- Returns a specified number of contiguous elements from the start of a sequence.
---@param count number
---@return Enumerable
function Enumerable:Take(count)
	local index = 0
	local prevIterator = self._iterator or getSourceIterator(self._source)

	local nextIterator = function()
		if index >= count then return nil end
		index = index + 1
		return prevIterator()
	end

	local newEnum = Linq.new({})
	newEnum._iterator = nextIterator
	return newEnum
end

--- Bypasses a specified number of elements in a sequence and then returns the remaining elements.
---@param count number
---@return Enumerable
function Enumerable:Skip(count)
	local skipped = 0
	local prevIterator = self._iterator or getSourceIterator(self._source)

	while skipped < count do
		prevIterator()
		skipped = skipped + 1
	end

	local newEnum = Linq.new({})
	newEnum._iterator = prevIterator
	return newEnum
end

--- Returns elements from a sequence as long as a specified condition is true.
---@param predicate? fun(value: any): boolean
---@return Enumerable
function Enumerable:TakeWhile(predicate)
	if type(predicate) ~= "function" then return error("Predicate must be a function", 2) end
	local prevIterator = self._iterator or getSourceIterator(self._source)
	local running = true

	local nextIterator = function()
		if not running then return nil end
		local val = prevIterator()
		if val == nil then
			running = false
			return nil
		end
		if predicate(val) then
			return val
		end
		running = false
		return nil
	end

	local newEnum = Linq.new({})
	newEnum._iterator = nextIterator
	return newEnum
end

--- Bypasses elements in a sequence as long as a specified condition is true and then returns the remaining elements.
---@param predicate? fun(value: any): boolean
---@return Enumerable
function Enumerable:SkipWhile(predicate)
	if type(predicate) ~= "function" then return error("Predicate must be a function", 2) end
	local prevIterator = self._iterator or getSourceIterator(self._source)
	local yielding = false

	local nextIterator = function()
		while true do
			local val = prevIterator()
			if val == nil then return nil end

			if yielding then return val end

			if not predicate(val) then
				yielding = true
				return val
			end
		end
	end

	local newEnum = Linq.new({})
	newEnum._iterator = nextIterator
	return newEnum
end

-- ################################################################
-- #                 CONVERSION                                   #
-- ################################################################

--- Creates a List/Array from an Enumerable. (Alias to ToArray)
---@return table
function Enumerable:ToList()
	return materialize(self)
end

--- Creates an array from a Enumerable.
---@return table
function Enumerable:ToArray()
	return materialize(self)
end

--- Simple materialization to table.
function Enumerable:ToTable()
	return materialize(self)
end

--- Creates a Dictionary from an Enumerable.
---@param keySelector? fun(value: any): any
---@param elementSelector? fun(value: any): any
---@return table map
function Enumerable:ToDictionary(keySelector, elementSelector)
	if type(keySelector) ~= "function" then return error("KeySelector is required", 2) end
	local data = materialize(self)
	local dict = {}
	local exists = {}

	for _, v in ipairs(data) do
		local key = keySelector(v)
		local val = elementSelector and elementSelector(v) or v
		if exists[key] then
			return error("ToDictionary: duplicate key encountered: " .. tostring(key), 2)
		end
		dict[key] = val
		exists[key] = true
	end

	return dict
end

--- Creates a Lookup from an Enumerable.
---@param keySelector? fun(value: any): any
---@param elementSelector? fun(value: any): any
---@return table map Map of keys to lists
function Enumerable:ToLookup(keySelector, elementSelector)
	return self:GroupBy(keySelector, elementSelector)
		:ToDictionary(function(g) return g.key end, function(g) return g.values:ToTable() end)
end

--- Concatenates two sequences.
---@param second table
---@return Enumerable
function Enumerable:Concat(second)
	if not second then return error("Second sequence is required", 2) end
	local data1 = materialize(self)
	local data2 = Linq.new(second):ToTable()

	for _, v in ipairs(data2) do
		table.insert(data1, v)
	end

	return Linq.new(data1)
end

--- Applies a specified function to the corresponding elements of two sequences, producing a sequence of the results.
---@param second table
---@param resultSelector? fun(first: any, second: any): any
---@return Enumerable
function Enumerable:Zip(second, resultSelector)
	if not second then return error("Second sequence is required", 2) end
	if type(resultSelector) ~= "function" then return error("ResultSelector is required", 2) end

	local data1 = materialize(self)
	local data2 = Linq.new(second):ToTable()
	local result = {}
	local len = math.min(#data1, #data2)

	for i = 1, len do
		table.insert(result, resultSelector(data1[i], data2[i]))
	end

	return Linq.new(result)
end

--- Returns the elements of the specified sequence or the type parameter's default value in a singleton collection if the sequence is empty.
---@param defaultValue any
---@return Enumerable
function Enumerable:DefaultIfEmpty(defaultValue)
	local data = materialize(self)
	if #data == 0 then
		return Linq.new({ defaultValue })
	end
	return Linq.new(data)
end

--- Puts the elements of a sequence into a string separated by a delimiter.
---@param delimiter string (default ",")
---@param selector? fun(value: any): string
---@return string
function Enumerable:ToString(delimiter, selector)
	delimiter = delimiter or ", "
	local data = materialize(self)
	local strs = {}
	for i, v in next, data do
		local val = selector and selector(v) or v
		strs[i] = tostring(val)
	end
	return table_concat(strs, delimiter)
end

-- ################################################################
-- #                   STATIC METHODS                             #
-- ################################################################

--- Generates a sequence of integral numbers within a specified range.
---@param start number
---@param count number
---@return Enumerable
function Linq.Range(start, count)
	if count < 0 then return error("Count cannot be negative", 2) end
	local t = {}
	for i = 1, count do
		table.insert(t, start + i - 1)
	end
	return Linq.new(t)
end

--- Generates a sequence that contains one repeated value.
---@param element any
---@param count number
---@return Enumerable
function Linq.Repeat(element, count)
	if count < 0 then return error("Count cannot be negative", 2) end
	local t = {}
	for i = 1, count do
		t[i] = element
	end
	return Linq.new(t)
end

--- Returns an empty Enumerable.
---@return Enumerable
function Linq.Empty()
	return Linq.new({})
end

-- Export
return Linq
