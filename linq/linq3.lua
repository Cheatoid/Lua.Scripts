-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- LINQ API for Lua tables and iterables.

local assert, error, select, type = assert, error, select, type

---@class Enumerable
---@field _factory function Iterator factory function
local Enumerable = {}
Enumerable.__index = Enumerable

----------------------------------------------------------------------
-- Utility Functions
----------------------------------------------------------------------

local function noop() end
local function nooper() return noop end

--- Returns an identity function.
---@param x function Identity function.
---@return function x Identity function.
local function identity(x)
	return x
end

--- Default equality comparer.
---@param a any First value.
---@param b any Second value.
---@return boolean equal True if equal.
local function defaultComparer(a, b)
	return a == b
end

--- Default less-than comparer for sorting.
---@param a any First value.
---@param b any Second value.
---@return boolean less True if a < b.
local function defaultLess(a, b) -- TODO: actually use this, or not, since table.sort defaults to less-than.
	return a < b
end

--- Default greater-than comparer for sorting.
---@param a any First value.
---@param b any Second value.
---@return boolean greater True if a > b.
local function defaultGreater(a, b) -- TODO: actually use this.
	return a > b
end

--- Safely copies an array-like table.
---@param t table Source table.
---@return table copy Copy of the table.
local function arrayCopy(t)
	local r = {}
	for i = 1, #t do
		r[i] = t[i]
	end
	return r
end

--- Packs values into an array.
---@param ... any Values.
---@return table packed Packed array.
local pack = table.pack or function(...)
	return { ..., n = select("#", ...) }
end

--- Creates a hash key from a selector output.<br>
-- NOTE: for complex tables, you should provide a custom key selector.<br>
-- that returns a primitive/string-safe value if structural equality is desired.
---@param value any Value to convert.
---@return any value Hashable key.
local function defaultHash(value)
	return value
end

--- Normalizes a source into an iterator factory.<br>
--- The iterator produced returns one item at a time, or nil when complete.<br>
--- Supported inputs:<br>
--- - Enumerable
--- - array-like table
--- - iterator factory function returning next-item closure
---@param source any Source input.
---@return function iterator Iterator factory.
local function toIteratorFactory(source)
	if getmetatable(source) == Enumerable then
		return source._factory
	end

	if type(source) == "table" then
		return function()
			local i = 0
			return function()
				i = i + 1
				if i <= #source then
					return source[i]
				end
				--return nil
			end
		end
	end

	if type(source) == "function" then
		return source
	end

	return error("unsupported source type for Enumerable.from")
end

--- Creates a new Enumerable from an iterator factory.
---@param factory function Iterator factory.
---@return Enumerable enumerable New enumerable.
local function newEnumerable(factory)
	return setmetatable({
		_factory = factory
	}, Enumerable)
end

----------------------------------------------------------------------
-- Construction
----------------------------------------------------------------------

--- Creates an Enumerable from a table, Enumerable, or iterator factory.
--
---@param source table|Enumerable|function Source sequence.
---@return Enumerable
function Enumerable.from(source)
	return newEnumerable(toIteratorFactory(source))
end

--- Creates an empty Enumerable.
---@return Enumerable
function Enumerable.empty()
	return newEnumerable(nooper)
end

--- Creates an Enumerable from the given arguments.
---@param ... any Values.
---@return Enumerable
function Enumerable.of(...)
	local args = pack(...)
	return Enumerable.from(function()
		local i = 0
		return function()
			i = i + 1
			if i <= args.n then
				return args[i]
			end
			--return nil
		end
	end)
end

--- Creates a numeric range.
---@param start number Starting number.
---@param count number Number of elements.
---@param step? number Step amount (default: 1).
---@return Enumerable
function Enumerable.range(start, count, step)
	step = step or 1
	assert(type(start) == "number", "start must be a number")
	assert(type(count) == "number", "count must be a number")
	assert(type(step) == "number", "step must be a number")

	return newEnumerable(function()
		local i = 0
		return function()
			if i < count then
				local value = start + (i * step)
				i = i + 1
				return value
			end
			--return nil
		end
	end)
end

--- Repeats a value count times.
---@param value any Value to repeat.
---@param count number Repeat count.
---@return Enumerable
function Enumerable.repeatValue(value, count)
	assert(type(count) == "number", "count must be a number")
	return newEnumerable(function()
		local i = 0
		return function()
			if i < count then
				i = i + 1
				return value
			end
			--return nil
		end
	end)
end

----------------------------------------------------------------------
-- Core iteration
----------------------------------------------------------------------

--- Returns a fresh iterator for this sequence.
---@return function iterator Iterator closure returning next element or nil.
function Enumerable:iter()
	return self._factory()
end

--- Executes an action for each element.
---@param action fun(value: any, index: integer)
function Enumerable:forEach(action)
	assert(type(action) == "function", "action must be a function")
	local it = self:iter()
	local i = 0
	while true do
		local item = it()
		if item == nil then
			break
		end
		i = i + 1
		action(item, i)
	end
end

----------------------------------------------------------------------
-- Projection / filtering
----------------------------------------------------------------------

--- Filters elements based on a predicate.
---@param predicate fun(value: any, index: integer): boolean
---@return Enumerable
function Enumerable:where(predicate)
	assert(type(predicate) == "function", "predicate must be a function")
	local sourceFactory = self._factory

	return newEnumerable(function()
		local it = sourceFactory()
		local index = 0
		return function()
			while true do
				local item = it()
				if item == nil then
					return --nil
				end
				index = index + 1
				if predicate(item, index) then
					return item
				end
			end
		end
	end)
end

--- Projects each element into a new form.
---@param selector fun(value: any, index: integer): any
---@return Enumerable
function Enumerable:select(selector)
	assert(type(selector) == "function", "selector must be a function")
	local sourceFactory = self._factory

	return newEnumerable(function()
		local it = sourceFactory()
		local index = 0
		return function()
			local item = it()
			if item == nil then
				return --nil
			end
			index = index + 1
			return selector(item, index)
		end
	end)
end

--- Projects each element to a sequence and flattens the resulting sequences.
---@param selector fun(value: any, index: integer): table|Enumerable|function
---@return Enumerable
function Enumerable:selectMany(selector)
	assert(type(selector) == "function", "selector must be a function")
	local sourceFactory = self._factory

	return newEnumerable(function()
		local outer = sourceFactory()
		local outerIndex = 0
		local inner

		return function()
			while true do
				if inner then
					local innerItem = inner()
					if innerItem ~= nil then
						return innerItem
					end
					inner = nil
				end

				local outerItem = outer()
				if outerItem == nil then
					return --nil
				end

				outerIndex = outerIndex + 1
				local innerSource = selector(outerItem, outerIndex)
				inner = toIteratorFactory(innerSource)()
			end
		end
	end)
end

--- Skips a number of elements.
---@param count number Number of elements to skip.
---@return Enumerable
function Enumerable:skip(count)
	assert(type(count) == "number", "count must be a number")
	local sourceFactory = self._factory

	return newEnumerable(function()
		local it = sourceFactory()
		local skipped = false
		return function()
			if not skipped then
				for _ = 1, count do
					if it() == nil then
						return nil
					end
				end
				skipped = true
			end
			return it()
		end
	end)
end

--- Takes a number of elements.
---@param count number Number of elements to take.
---@return Enumerable
function Enumerable:take(count)
	assert(type(count) == "number", "count must be a number")
	local sourceFactory = self._factory

	return newEnumerable(function()
		local it = sourceFactory()
		local taken = 0
		return function()
			if taken >= count then
				return --nil
			end
			local item = it()
			if item == nil then
				return --nil
			end
			taken = taken + 1
			return item
		end
	end)
end

--- Appends a single element to the end of the sequence.
---@param value any Value to append.
---@return Enumerable
function Enumerable:append(value)
	return self:concat(Enumerable.of(value))
end

--- Prepends a single element to the beginning of the sequence.
---@param value any Value to prepend.
---@return Enumerable
function Enumerable:prepend(value)
	return Enumerable.of(value):concat(self)
end

--- Concatenates this sequence with another.
---@param second table|Enumerable|function Second sequence.
---@return Enumerable
function Enumerable:concat(second)
	local firstFactory = self._factory
	local secondFactory = toIteratorFactory(second)

	return newEnumerable(function()
		local first = firstFactory()
		local secondIter
		local usingFirst = true

		return function()
			if usingFirst then
				local item = first()
				if item ~= nil then
					return item
				end
				usingFirst = false
				secondIter = secondFactory()
			end
			return secondIter()
		end
	end)
end

--- Reverses the sequence.
-- This materializes the sequence first.
---@return Enumerable
function Enumerable:reverse()
	local sourceFactory = self._factory
	return newEnumerable(function()
		local items = {}
		local it = sourceFactory()
		while true do
			local item = it()
			if item == nil then break end
			items[#items + 1] = item
		end
		local i = #items + 1
		return function()
			i = i - 1
			if i >= 1 then
				return items[i]
			end
			--return nil
		end
	end)
end

----------------------------------------------------------------------
-- Quantifiers / element operators
----------------------------------------------------------------------

--- Returns the number of elements optionally matching a predicate.
---@param predicate? function Optional predicate(value, index): boolean
---@return number
function Enumerable:count(predicate)
	local c = 0
	local it = self:iter()
	local i = 0

	if predicate == nil then
		while true do
			local item = it()
			if item == nil then break end
			c = c + 1
		end
	else
		assert(type(predicate) == "function", "predicate must be a function")
		while true do
			local item = it()
			if item == nil then break end
			i = i + 1
			if predicate(item, i) then
				c = c + 1
			end
		end
	end

	return c
end

--- Determines whether any element exists or satisfies a predicate.
---@param predicate? function Optional predicate(value, index): boolean
---@return boolean
function Enumerable:any(predicate)
	local it = self:iter()
	local i = 0

	if predicate == nil then
		return it() ~= nil
	end

	assert(type(predicate) == "function", "predicate must be a function")

	while true do
		local item = it()
		if item == nil then break end
		i = i + 1
		if predicate(item, i) then
			return true
		end
	end
	return false
end

--- Determines whether all elements satisfy a predicate.
---@param predicate function Predicate(value, index): boolean
---@return boolean
function Enumerable:all(predicate)
	assert(type(predicate) == "function", "predicate must be a function")
	local it = self:iter()
	local i = 0

	while true do
		local item = it()
		if item == nil then break end
		i = i + 1
		if not predicate(item, i) then
			return false
		end
	end
	return true
end

--- Returns the first element optionally matching a predicate.
-- Throws an error if no matching element is found.
---@param predicate? function Optional predicate.
---@return any
function Enumerable:first(predicate)
	if predicate == nil then
		local it = self:iter()
		local item = it()
		if item == nil then
			return error("sequence contains no elements")
		end
		return item
	end

	return self:where(predicate):first()
end

--- Returns the first element matching a predicate, or a default value.
---@param defaultValue any Default value.
---@param predicate? function Optional predicate.
---@return any
function Enumerable:firstOrDefault(defaultValue, predicate)
	local it
	if predicate == nil then
		it = self:iter()
		local item = it()
		if item == nil then
			return defaultValue
		end
		return item
	end

	it = self:where(predicate):iter()
	local item = it()
	if item == nil then
		return defaultValue
	end
	return item
end

--- Returns the last element optionally matching a predicate.
-- Throws an error if no matching element is found.
---@param predicate? function Optional predicate.
---@return any
function Enumerable:last(predicate)
	if predicate ~= nil then
		return self:where(predicate):last()
	end

	local it = self:iter()
	local found = false
	local lastItem

	while true do
		local item = it()
		if item == nil then break end
		found = true
		lastItem = item
	end

	if not found then
		return error("sequence contains no elements")
	end

	return lastItem
end

--- Returns the last element matching a predicate or a default value.
---@param defaultValue any Default value.
---@param predicate? function Optional predicate.
---@return any
function Enumerable:lastOrDefault(defaultValue, predicate)
	if predicate ~= nil then
		return self:where(predicate):lastOrDefault(defaultValue)
	end

	local it = self:iter()
	local found = false
	local lastItem

	while true do
		local item = it()
		if item == nil then break end
		found = true
		lastItem = item
	end

	if not found then
		return defaultValue
	end

	return lastItem
end

--- Returns the only element of a sequence, optionally matching a predicate.
-- Throws if zero or more than one matching element exists.
---@param predicate? function Optional predicate.
---@return any
function Enumerable:single(predicate)
	if predicate ~= nil then
		return self:where(predicate):single()
	end

	local it = self:iter()
	local first = it()
	if first == nil then
		return error("sequence contains no elements")
	end

	if it() ~= nil then
		return error("sequence contains more than one element")
	end

	return first
end

--- Returns the only element of a sequence, or default if none exists.
-- Throws if more than one matching element exists.
---@param defaultValue any Default value.
---@param predicate? function Optional predicate.
---@return any
function Enumerable:singleOrDefault(defaultValue, predicate)
	if predicate ~= nil then
		return self:where(predicate):singleOrDefault(defaultValue)
	end

	local it = self:iter()
	local first = it()
	if first == nil then
		return defaultValue
	end

	if it() ~= nil then
		return error("sequence contains more than one element")
	end

	return first
end

--- Determines whether a sequence contains a specified value.
---@param value any Value to find.
---@param comparer? function Optional comparer(a, b): boolean
---@return boolean
function Enumerable:contains(value, comparer)
	comparer = comparer or defaultComparer
	assert(type(comparer) == "function", "comparer must be a function")

	local it = self:iter()
	while true do
		local item = it()
		if item == nil then break end
		if comparer(item, value) then
			return true
		end
	end
	return false
end

----------------------------------------------------------------------
-- Aggregation
----------------------------------------------------------------------

--- Aggregates the sequence into a single value.
--
-- Overloads:
--   aggregate(func)
--   aggregate(seed, func)
--   aggregate(seed, func, resultSelector)
--
---@param a any Seed or accumulator function.
---@param b? function Accumulator function.
---@param c? function Result selector.
---@return any
function Enumerable:aggregate(a, b, c)
	local seed, func, resultSelector
	local it = self:iter()

	if type(a) == "function" then
		func = a
		resultSelector = b or identity
		local first = it()
		if first == nil then
			return error("sequence contains no elements")
		end

		local acc = first
		while true do
			local item = it()
			if item == nil then break end
			acc = func(acc, item)
		end

		return resultSelector(acc)
	end

	seed, func, resultSelector = a, b, c or identity
	assert(type(func) == "function", "accumulator must be a function")
	local acc = seed
	while true do
		local item = it()
		if item == nil then break end
		acc = func(acc, item)
	end

	return resultSelector(acc)
end

--- Sums the sequence or projected numeric values.
---@param selector? function Optional selector(value): number
---@return number
function Enumerable:sum(selector)
	selector = selector or identity
	local total = 0
	local it = self:iter()
	local i = 0

	while true do
		local item = it()
		if item == nil then break end
		i = i + 1
		total = total + selector(item, i)
	end

	return total
end

--- Returns the average of the sequence or projected numeric values.
---@param selector? function Optional selector(value): number
---@return number
function Enumerable:average(selector)
	selector = selector or identity
	local total = 0
	local count = 0
	local it = self:iter()
	local i = 0

	while true do
		local item = it()
		if item == nil then break end
		i = i + 1
		total = total + selector(item, i)
		count = count + 1
	end

	if count == 0 then -- avoid divide-by-zero
		return error("sequence contains no elements")
	end

	return total / count
end

--- Returns the minimum value or projected minimum.
---@param selector? function Optional selector(value): comparable
---@return any
function Enumerable:min(selector)
	selector = selector or identity
	local it = self:iter()
	local first = it()
	if first == nil then
		return error("sequence contains no elements")
	end

	local i = 1
	local bestItem = first
	local bestValue = selector(first, i)

	while true do
		local item = it()
		if item == nil then break end
		i = i + 1
		local value = selector(item, i)
		if value < bestValue then
			bestValue = value
			bestItem = item
		end
	end

	return selector == identity and bestItem or bestValue
end

--- Returns the maximum value or projected maximum.
---@param selector? function Optional selector(value): comparable
---@return any
function Enumerable:max(selector)
	selector = selector or identity
	local it = self:iter()
	local first = it()
	if first == nil then
		return error("sequence contains no elements")
	end

	local i = 1
	local bestItem = first
	local bestValue = selector(first, i)

	while true do
		local item = it()
		if item == nil then break end
		i = i + 1
		local value = selector(item, i)
		if value > bestValue then
			bestValue = value
			bestItem = item
		end
	end

	return selector == identity and bestItem or bestValue
end

----------------------------------------------------------------------
-- Materialization
----------------------------------------------------------------------

--- Materializes the sequence into an array table.
---@return table
function Enumerable:toTable()
	local result = {}
	local it = self:iter()
	while true do
		local item = it()
		if item == nil then break end
		result[#result + 1] = item
	end
	return result
end

--- Creates a dictionary table from the sequence.
---@param keySelector fun(value: any, index: integer): any
---@param valueSelector? fun(value: any, index: integer): any
---@return table
function Enumerable:toDictionary(keySelector, valueSelector)
	assert(type(keySelector) == "function", "keySelector must be a function")
	valueSelector = valueSelector or identity

	local dict = {}
	local exists = {}
	local it = self:iter()
	local i = 0
	while true do
		local item = it()
		if item == nil then break end
		i = i + 1
		local key = keySelector(item, i)
		if exists[key] then
			return error("an element with the same key already exists in the dictionary")
		end
		dict[key] = valueSelector(item, i)
		exists[key] = true
	end
	return dict
end

----------------------------------------------------------------------
-- Distinct / Set operations
----------------------------------------------------------------------

--- Returns distinct elements from a sequence.
---@param keySelector? fun(value: any, index: integer): any
---@return Enumerable
function Enumerable:distinct(keySelector)
	keySelector = keySelector or defaultHash
	local sourceFactory = self._factory

	return newEnumerable(function()
		local it = sourceFactory()
		local seen = {}

		return function()
			while true do
				local item = it()
				if item == nil then
					return --nil
				end
				local key = keySelector(item)
				if not seen[key] then
					seen[key] = true
					return item
				end
			end
		end
	end)
end

--- Returns the union of two sequences.
---@param second table|Enumerable|function Second sequence.
---@param keySelector? fun(value: any, index: integer): any
---@return Enumerable
function Enumerable:union(second, keySelector)
	return self:concat(second):distinct(keySelector)
end

--- Returns elements present in both sequences.
---@param second table|Enumerable|function Second sequence.
---@param keySelector? fun(value: any, index: integer): any
---@return Enumerable
function Enumerable:intersect(second, keySelector)
	keySelector = keySelector or defaultHash
	local firstFactory = self._factory
	local secondFactory = toIteratorFactory(second)

	return newEnumerable(function()
		local secondSet = {}
		do
			local it2 = secondFactory()
			while true do
				local item = it2()
				if item == nil then break end
				secondSet[keySelector(item)] = true
			end
		end

		local yielded = {}
		local it1 = firstFactory()

		return function()
			while true do
				local item = it1()
				if item == nil then
					return --nil
				end

				local key = keySelector(item)
				if secondSet[key] and not yielded[key] then
					yielded[key] = true
					return item
				end
			end
		end
	end)
end

--- Returns elements from the first sequence not present in the second.
---@param second table|Enumerable|function Second sequence.
---@param keySelector? fun(value: any, index: integer): any
---@return Enumerable
function Enumerable:except(second, keySelector)
	keySelector = keySelector or defaultHash
	local firstFactory = self._factory
	local secondFactory = toIteratorFactory(second)

	return newEnumerable(function()
		local excluded = {}
		do
			local it2 = secondFactory()
			while true do
				local item = it2()
				if item == nil then break end
				excluded[keySelector(item)] = true
			end
		end

		local yielded = {}
		local it1 = firstFactory()

		return function()
			while true do
				local item = it1()
				if item == nil then
					return --nil
				end

				local key = keySelector(item)
				if not excluded[key] and not yielded[key] then
					yielded[key] = true
					return item
				end
			end
		end
	end)
end

----------------------------------------------------------------------
-- Grouping
----------------------------------------------------------------------

--- Groups the elements of a sequence according to a key selector.<br>
--- Returns an Enumerable of group objects:
--- ```
--- {
---   key = ...,
---   values = { ... }
--- }
--- ```
---@param keySelector fun(value: any, index: integer): any
---@param elementSelector? fun(value: any, index: integer): any
---@return Enumerable
function Enumerable:groupBy(keySelector, elementSelector)
	assert(type(keySelector) == "function", "keySelector must be a function")
	elementSelector = elementSelector or identity
	local sourceFactory = self._factory

	return newEnumerable(function()
		local groups = {}
		local order = {}

		do
			local it = sourceFactory()
			local i = 0
			while true do
				local item = it()
				if item == nil then break end
				i = i + 1
				local key = keySelector(item, i)
				local value = elementSelector(item, i)

				if groups[key] == nil then
					groups[key] = { key = key, values = {} }
					order[#order + 1] = key
				end
				groups[key].values[#groups[key].values + 1] = value
			end
		end

		local idx = 0
		return function()
			idx = idx + 1
			local key = order[idx]
			if key ~= nil then
				return groups[key]
			end
		end
	end)
end

--- Creates a lookup table from a sequence.<br>
--- Result shape:
--- ```
--- lookup[key] = { ...values... }
--- ```
---@param keySelector fun(value: any, index: integer): any
---@param elementSelector? fun(value: any, index: integer): any
---@return table
function Enumerable:toLookup(keySelector, elementSelector)
	assert(type(keySelector) == "function", "keySelector must be a function")
	elementSelector = elementSelector or identity

	local lookup = {}
	local it = self:iter()
	local i = 0
	while true do
		local item = it()
		if item == nil then break end
		i = i + 1
		local key = keySelector(item, i)
		local value = elementSelector(item, i)
		if lookup[key] == nil then
			lookup[key] = {}
		end
		lookup[key][#lookup[key] + 1] = value
	end

	return lookup
end

----------------------------------------------------------------------
-- Ordering
----------------------------------------------------------------------

---@class OrderedEnumerable : Enumerable
---@field _source Enumerable Source sequence
---@field _criteria table Sorting criteria
local OrderedEnumerable = {}
OrderedEnumerable.__index = OrderedEnumerable
setmetatable(OrderedEnumerable, { __index = Enumerable })

--- Creates an ordered enumerable.
---@param source Enumerable Source sequence.
---@param criteria table Sorting criteria.
---@return OrderedEnumerable
local function newOrderedEnumerable(source, criteria)
	return setmetatable({
		_source = source,
		_criteria = criteria
	}, OrderedEnumerable)
end

--- Builds a comparer from sort criteria.
---@param criteria table Sort criteria.
---@return function
local function buildSortComparer(criteria)
	return function(a, b)
		for _, c in ipairs(criteria) do
			local ka = c.selector(a.value)
			local kb = c.selector(b.value)
			if ka ~= kb then
				if c.descending then
					return ka > kb
				end
				return ka < kb
			end
		end
		return a.index < b.index
	end
end

function OrderedEnumerable:iter()
	local items = self._source:toTable()
	for i = 1, #items do
		items[i] = { value = items[i], index = i }
	end
	table.sort(items, buildSortComparer(self._criteria))
	local i = 0
	return function()
		i = i + 1
		local entry = items[i]
		return entry and entry.value
	end
end

function OrderedEnumerable:toTable()
	local items = self._source:toTable()
	for i = 1, #items do
		items[i] = { value = items[i], index = i }
	end
	table.sort(items, buildSortComparer(self._criteria))
	local result = {}
	for i, entry in ipairs(items) do result[i] = entry.value end
	return result
end

--- Adds a secondary ascending ordering.
---@param keySelector fun(value: any, index: integer): any
---@return OrderedEnumerable
function OrderedEnumerable:thenBy(keySelector)
	assert(type(keySelector) == "function", "keySelector must be a function")
	local criteria = arrayCopy(self._criteria)
	criteria[#criteria + 1] = {
		selector = keySelector,
		descending = false
	}
	return newOrderedEnumerable(self._source, criteria)
end

--- Adds a secondary descending ordering.
---@param keySelector fun(value: any, index: integer): any
---@return OrderedEnumerable
function OrderedEnumerable:thenByDescending(keySelector)
	assert(type(keySelector) == "function", "keySelector must be a function")
	local criteria = arrayCopy(self._criteria)
	criteria[#criteria + 1] = {
		selector = keySelector,
		descending = true
	}
	return newOrderedEnumerable(self._source, criteria)
end

--- Orders the sequence in ascending order.
---@param keySelector? fun(value: any, index: integer): any
---@return OrderedEnumerable
function Enumerable:orderBy(keySelector)
	keySelector = keySelector or identity
	return newOrderedEnumerable(self, {
		{ selector = keySelector, descending = false }
	})
end

--- Orders the sequence in descending order.
---@param keySelector? fun(value: any, index: integer): any
---@return OrderedEnumerable
function Enumerable:orderByDescending(keySelector)
	keySelector = keySelector or identity
	return newOrderedEnumerable(self, {
		{ selector = keySelector, descending = true }
	})
end

----------------------------------------------------------------------
-- Joins
----------------------------------------------------------------------

--- Correlates elements of two sequences based on matching keys.
---@param inner table|Enumerable|function Inner sequence.
---@param outerKeySelector fun(value: any, index: integer): any
---@param innerKeySelector fun(value: any, index: integer): any
---@param resultSelector fun(outer: any, inner: any): any
---@return Enumerable
function Enumerable:join(inner, outerKeySelector, innerKeySelector, resultSelector)
	assert(type(outerKeySelector) == "function", "outerKeySelector must be a function")
	assert(type(innerKeySelector) == "function", "innerKeySelector must be a function")
	assert(type(resultSelector) == "function", "resultSelector must be a function")

	local outerFactory = self._factory
	local innerFactory = toIteratorFactory(inner)

	return newEnumerable(function()
		local lookup = {}
		do
			local itInner = innerFactory()
			while true do
				local item = itInner()
				if item == nil then break end
				local key = innerKeySelector(item)
				if lookup[key] == nil then
					lookup[key] = {}
				end
				lookup[key][#lookup[key] + 1] = item
			end
		end

		local outerIt = outerFactory()
		local currentOuter
		local currentMatches
		local matchIndex = 0

		return function()
			while true do
				if currentMatches ~= nil and matchIndex < #currentMatches then
					matchIndex = matchIndex + 1
					return resultSelector(currentOuter, currentMatches[matchIndex])
				end

				currentOuter = outerIt()
				if currentOuter ~= nil then
					currentMatches = lookup[outerKeySelector(currentOuter)] or {}
					matchIndex = 0
				end
			end
		end
	end)
end

--- Correlates elements of two sequences and groups the results.
---@param inner table|Enumerable|function Inner sequence.
---@param outerKeySelector fun(value: any, index: integer): any
---@param innerKeySelector fun(value: any, index: integer): any
---@param resultSelector fun(outer: any, groupEnumerable: Enumerable): any
---@return Enumerable
function Enumerable:groupJoin(inner, outerKeySelector, innerKeySelector, resultSelector)
	assert(type(outerKeySelector) == "function", "outerKeySelector must be a function")
	assert(type(innerKeySelector) == "function", "innerKeySelector must be a function")
	assert(type(resultSelector) == "function", "resultSelector must be a function")

	local outerFactory = self._factory
	local innerFactory = toIteratorFactory(inner)

	return newEnumerable(function()
		local lookup = {}
		do
			local itInner = innerFactory()
			while true do
				local item = itInner()
				if item == nil then break end
				local key = innerKeySelector(item)
				if lookup[key] == nil then
					lookup[key] = {}
				end
				lookup[key][#lookup[key] + 1] = item
			end
		end

		local outerIt = outerFactory()

		return function()
			local outerItem = outerIt()
			if outerItem ~= nil then
				local key = outerKeySelector(outerItem)
				local group = lookup[key] or {}

				return resultSelector(outerItem, Enumerable.from(group))
			end
		end
	end)
end

----------------------------------------------------------------------
-- Metamethod helpers
----------------------------------------------------------------------

--- String representation for debugging.
---@return string
function Enumerable:__tostring()
	return "Enumerable"
end

OrderedEnumerable.__tostring = Enumerable.__tostring

-- Export
return Enumerable
