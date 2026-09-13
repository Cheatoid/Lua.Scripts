-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- LINQ API for Lua tables and iterables.

local assert, error, select, type = assert, error, select, type

---@alias Iterator fun(): any Iterator returning next item or nil when complete.
---@alias IteratorFactory fun(): Iterator Factory returning fresh iterator.
---@alias EnumerableSource table|Enumerable|IteratorFactory Source sequence input.
---@alias Predicate fun(value: any, index: integer): boolean Predicate testing values.
---@alias Selector fun(value: any, index: integer): any Projection selector.
---@alias KeySelector fun(value: any, index: integer): any Key extraction selector.
---@alias ElementSelector fun(value: any, index: integer): any Element projection selector.
---@alias Comparer fun(a: any, b: any): boolean Equality comparer.
---@alias Accumulator fun(acc: any, value: any): any Accumulation function.
---@alias ResultSelector fun(acc: any): any Result projection selector.

--- LINQ style sequence wrapper for tables and iterables.<br>
--- Created via `Enumerable.from`, `of`, `range`, `repeatValue` or `empty`.
---@class Enumerable
---@field _factory IteratorFactory Iterator factory function.
local Enumerable = {}
Enumerable.__index = Enumerable

----------------------------------------------------------------------
-- Utility Functions
----------------------------------------------------------------------

--- No-operation placeholder callback.
---@return function noop No-operation function.
local function noop() end

--- Returns a factory producing no-operation iterators.
---@return IteratorFactory factory Factory returning empty iterator.
local function nooper() return noop end

--- Returns its input unchanged.
---@param x any x Value to return.
---@return any x Same input value.
local function identity(x)
	return x
end

--- Default equality comparer using `==`.
---@param a any a First value.
---@param b any b Second value.
---@return boolean equal True when values are equal.
local function defaultComparer(a, b)
	return a == b
end

--- Default less-than comparer for sorting.
---@param a any a First value.
---@param b any b Second value.
---@return boolean less True when `a < b`.
local function defaultLess(a, b) -- TODO: actually use this, or not, since table.sort defaults to less-than.
	return a < b
end

--- Default greater-than comparer for sorting.
---@param a any a First value.
---@param b any b Second value.
---@return boolean greater True when `a > b`.
local function defaultGreater(a, b) -- TODO: actually use this.
	return a > b
end

--- Safely copies an array-like table.
---@param t table t Source array table.
---@return table copy Shallow array copy.
local function arrayCopy(t)
	local r = {}
	for i = 1, #t do
		r[i] = t[i]
	end
	return r
end

--- Packs values into an array with count field.
---@param ... any args Values to pack.
---@return table packed Packed array with `n` count.
local pack = table.pack or function(...)
	return { n = select("#", ...), ... }
end

--- Creates a hash key from a selector output.<br>
--- NOTE: for complex tables, you should provide a custom key selector.<br>
--- that returns a primitive/string-safe value if structural equality is desired.
---@param value any value Value to convert.
---@return any key Hashable key value.
local function defaultHash(value)
	return value
end

--- Normalizes a source into an iterator factory.<br>
--- The iterator produced returns one item at a time, or nil when complete.<br>
--- Supported inputs:<br>
--- - Enumerable
--- - array-like table
--- - iterator factory function returning next-item closure
---@overload fun(source: Enumerable): IteratorFactory
---@overload fun(source: table): IteratorFactory
---@overload fun(source: IteratorFactory): IteratorFactory
---@param source EnumerableSource source Source input sequence.
---@return IteratorFactory factory Normalized iterator factory.
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
---@param factory IteratorFactory factory Iterator factory function.
---@return Enumerable enumerable New enumerable instance.
local function newEnumerable(factory)
	return setmetatable({
		_factory = factory
	}, Enumerable)
end

----------------------------------------------------------------------
-- Construction
----------------------------------------------------------------------

--- Creates an Enumerable from a table, Enumerable, or iterator factory.
---@overload fun(source: table): Enumerable
---@overload fun(source: Enumerable): Enumerable
---@overload fun(source: IteratorFactory): Enumerable
---@param source EnumerableSource source Source sequence input.
---@return Enumerable enumerable New enumerable instance.
---@usage <br>
--- ```
--- local q = Enumerable.from({ 1, 2, 3 })
--- ```
function Enumerable.from(source)
	return newEnumerable(toIteratorFactory(source))
end

--- Creates an empty Enumerable.
---@return Enumerable enumerable New empty enumerable.
function Enumerable.empty()
	return newEnumerable(nooper)
end

--- Creates an Enumerable from the given arguments.
---@param ... any args Values to enumerate.
---@return Enumerable enumerable New enumerable instance.
---@usage <br>
--- ```
--- local q = Enumerable.of(1, 2, 3)
--- ```
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
---@param start number start Starting number.
---@param count integer count Number of elements.
---@param step? number step Step amount (default: 1).
---@return Enumerable enumerable New range enumerable.
---@usage <br>
--- ```
--- local q = Enumerable.range(1, 5)
--- ```
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
---@param value any value Value to repeat.
---@param count integer count Repeat count.
---@return Enumerable enumerable New repeating enumerable.
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
---@return Iterator iterator Iterator returning next element or nil.
function Enumerable:iter()
	return self._factory()
end

--- Executes an action for each element.
---@param action fun(value: any, index: integer) action Action invoked per element.
---@usage <br>
--- ```
--- Enumerable.from({ 1, 2 }):forEach(function(v) print(v) end)
--- ```
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
---@param predicate Predicate predicate Filter predicate.
---@return Enumerable enumerable Filtered enumerable.
---@usage <br>
--- ```
--- local evens = Enumerable.from({ 1, 2, 3 }):where(function(v) return v % 2 == 0 end)
--- ```
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
					return nil
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
---@param selector Selector selector Projection selector.
---@return Enumerable enumerable Projected enumerable.
---@usage <br>
--- ```
--- local strs = Enumerable.from({ 1, 2 }):select(function(v) return tostring(v) end)
--- ```
function Enumerable:select(selector)
	assert(type(selector) == "function", "selector must be a function")
	local sourceFactory = self._factory

	return newEnumerable(function()
		local it = sourceFactory()
		local index = 0
		return function()
			local item = it()
			if item == nil then
				return nil
			end
			index = index + 1
			return selector(item, index)
		end
	end)
end

--- Projects each element to a sequence and flattens the resulting sequences.
---@param selector fun(value: any, index: integer): EnumerableSource selector Sequence selector.
---@return Enumerable enumerable Flattened enumerable.
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
					return nil
				end

				outerIndex = outerIndex + 1
				local innerSource = selector(outerItem, outerIndex)
				inner = toIteratorFactory(innerSource)()
			end
		end
	end)
end

--- Skips a number of elements.
---@param count integer count Number of elements to skip.
---@return Enumerable enumerable Remaining enumerable.
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
---@param count integer count Number of elements to take.
---@return Enumerable enumerable Taken enumerable.
function Enumerable:take(count)
	assert(type(count) == "number", "count must be a number")
	local sourceFactory = self._factory

	return newEnumerable(function()
		local it = sourceFactory()
		local taken = 0
		return function()
			if taken >= count then
				return nil
			end
			local item = it()
			if item == nil then
				return nil
			end
			taken = taken + 1
			return item
		end
	end)
end

--- Appends a single element to the end of the sequence.
---@param value any value Value to append.
---@return Enumerable enumerable Extended enumerable.
function Enumerable:append(value)
	return self:concat(Enumerable.of(value))
end

--- Prepends a single element to the beginning of the sequence.
---@param value any value Value to prepend.
---@return Enumerable enumerable Extended enumerable.
function Enumerable:prepend(value)
	return Enumerable.of(value):concat(self)
end

--- Concatenates this sequence with another.
---@overload fun(second: table): Enumerable
---@overload fun(second: Enumerable): Enumerable
---@overload fun(second: IteratorFactory): Enumerable
---@param second EnumerableSource second Second sequence input.
---@return Enumerable enumerable Concatenated enumerable.
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

--- Reverses the sequence.<br>
--- This materializes the sequence first.
---@return Enumerable enumerable Reversed enumerable.
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
---@overload fun(): integer
---@overload fun(predicate: Predicate): integer
---@param predicate? Predicate predicate Optional filter predicate.
---@return integer count Number of matching elements.
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
---@overload fun(): boolean
---@overload fun(predicate: Predicate): boolean
---@param predicate? Predicate predicate Optional filter predicate.
---@return boolean result True when any element matches.
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
---@param predicate Predicate predicate Predicate to test.
---@return boolean result True when all elements match.
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

--- Returns the first element optionally matching a predicate.<br>
--- Throws an error if no matching element is found.
---@overload fun(): any
---@overload fun(predicate: Predicate): any
---@param predicate? Predicate predicate Optional filter predicate.
---@return any value First matching element.
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
---@overload fun(defaultValue: any): any
---@overload fun(defaultValue: any, predicate: Predicate): any
---@param defaultValue any defaultValue Default fallback value.
---@param predicate? Predicate predicate Optional filter predicate.
---@return any value First match or default value.
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

--- Returns the last element optionally matching a predicate.<br>
--- Throws an error if no matching element is found.
---@overload fun(): any
---@overload fun(predicate: Predicate): any
---@param predicate? Predicate predicate Optional filter predicate.
---@return any value Last matching element.
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
---@overload fun(defaultValue: any): any
---@overload fun(defaultValue: any, predicate: Predicate): any
---@param defaultValue any defaultValue Default fallback value.
---@param predicate? Predicate predicate Optional filter predicate.
---@return any value Last match or default value.
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

--- Returns the only element of a sequence, optionally matching a predicate.<br>
--- Throws if zero or more than one matching element exists.
---@overload fun(): any
---@overload fun(predicate: Predicate): any
---@param predicate? Predicate predicate Optional filter predicate.
---@return any value Single matching element.
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

--- Returns the only element of a sequence, or default if none exists.<br>
--- Throws if more than one matching element exists.
---@overload fun(defaultValue: any): any
---@overload fun(defaultValue: any, predicate: Predicate): any
---@param defaultValue any defaultValue Default fallback value.
---@param predicate? Predicate predicate Optional filter predicate.
---@return any value Single match or default value.
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
---@overload fun(value: any): boolean
---@overload fun(value: any, comparer: Comparer): boolean
---@param value any value Value to find.
---@param comparer? Comparer comparer Optional equality comparer.
---@return boolean result True when value is found.
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

--- Aggregates the sequence into a single value.<br>
--- Overloads:<br>
--- aggregate(func)<br>
--- aggregate(seed, func)<br>
--- aggregate(seed, func, resultSelector)
---@overload fun(func: Accumulator): any
---@overload fun(func: Accumulator, resultSelector: ResultSelector): any
---@overload fun(seed: any, func: Accumulator): any
---@overload fun(seed: any, func: Accumulator, resultSelector: ResultSelector): any
---@param a any|Accumulator a Seed value or accumulator function.
---@param b? Accumulator|ResultSelector b Accumulator or result selector.
---@param c? ResultSelector c Optional result selector.
---@return any result Aggregated result value.
---@usage <br>
--- ```
--- local total = Enumerable.from({ 1, 2 }):aggregate(0, function(acc, v) return acc + v end)
--- ```
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
---@overload fun(): number
---@overload fun(selector: fun(value: any, index: integer): number): number
---@param selector? fun(value: any, index: integer): number selector Optional value selector.
---@return number total Summed total value.
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
---@overload fun(): number
---@overload fun(selector: fun(value: any, index: integer): number): number
---@param selector? fun(value: any, index: integer): number selector Optional value selector.
---@return number average Average value.
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
---@overload fun(): any
---@overload fun(selector: fun(value: any, index: integer): any): any
---@param selector? fun(value: any, index: integer): any selector Optional value selector.
---@return any minimum Minimum value or projection.
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
---@overload fun(): any
---@overload fun(selector: fun(value: any, index: integer): any): any
---@param selector? fun(value: any, index: integer): any selector Optional value selector.
---@return any maximum Maximum value or projection.
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
---@return table result Array of sequence items.
---@usage <br>
--- ```
--- local arr = Enumerable.range(1, 3):toTable()
--- ```
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
---@overload fun(keySelector: KeySelector): table
---@overload fun(keySelector: KeySelector, valueSelector: ElementSelector): table
---@param keySelector KeySelector keySelector Key extraction selector.
---@param valueSelector? ElementSelector valueSelector Optional value selector.
---@return table dict Dictionary mapping keys to values.
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
---@overload fun(): Enumerable
---@overload fun(keySelector: KeySelector): Enumerable
---@param keySelector? KeySelector keySelector Optional key selector.
---@return Enumerable enumerable Distinct enumerable.
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
					return nil
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
---@overload fun(second: table): Enumerable
---@overload fun(second: Enumerable): Enumerable
---@overload fun(second: IteratorFactory): Enumerable
---@overload fun(second: EnumerableSource, keySelector: KeySelector): Enumerable
---@param second EnumerableSource second Second sequence input.
---@param keySelector? KeySelector keySelector Optional key selector.
---@return Enumerable enumerable Union enumerable.
function Enumerable:union(second, keySelector)
	return self:concat(second):distinct(keySelector)
end

--- Returns elements present in both sequences.
---@overload fun(second: EnumerableSource): Enumerable
---@overload fun(second: EnumerableSource, keySelector: KeySelector): Enumerable
---@param second EnumerableSource second Second sequence input.
---@param keySelector? KeySelector keySelector Optional key selector.
---@return Enumerable enumerable Intersection enumerable.
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
					return nil
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
---@overload fun(second: EnumerableSource): Enumerable
---@overload fun(second: EnumerableSource, keySelector: KeySelector): Enumerable
---@param second EnumerableSource second Second sequence input.
---@param keySelector? KeySelector keySelector Optional key selector.
---@return Enumerable enumerable Difference enumerable.
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
					return nil
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

---@class EnumerableGroup
---@field key any Group key value.
---@field values table Group values array.

--- Groups the elements of a sequence according to a key selector.<br>
--- Returns an Enumerable of group objects:
--- ```
--- {
---   key = ...,
---   values = { ... }
--- }
--- ```
---@overload fun(keySelector: KeySelector): Enumerable
---@overload fun(keySelector: KeySelector, elementSelector: ElementSelector): Enumerable
---@param keySelector KeySelector keySelector Key extraction selector.
---@param elementSelector? ElementSelector elementSelector Optional element selector.
---@return Enumerable enumerable Enumerable of group objects.
---@usage <br>
--- ```
--- local groups = Enumerable.from({ 1, 2, 3 }):groupBy(function(v) return v % 2 end)
--- ```
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
---@overload fun(keySelector: KeySelector): table
---@overload fun(keySelector: KeySelector, elementSelector: ElementSelector): table
---@param keySelector KeySelector keySelector Key extraction selector.
---@param elementSelector? ElementSelector elementSelector Optional element selector.
---@return table lookup Lookup mapping keys to arrays.
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
---@field _source Enumerable Source sequence input.
---@field _criteria table Sorting criteria array.
---@field _factory IteratorFactory Iterator factory function.
local OrderedEnumerable = {}
OrderedEnumerable.__index = OrderedEnumerable
setmetatable(OrderedEnumerable, { __index = Enumerable })

--- Creates an ordered enumerable.
---@param source Enumerable source Source sequence input.
---@param criteria table criteria Sorting criteria array.
---@return OrderedEnumerable ordered New ordered enumerable.
local function newOrderedEnumerable(source, criteria)
	local self = setmetatable({
		_source = source,
		_criteria = criteria
	}, OrderedEnumerable)
	-- Provide a factory so base Enumerable ops (where/select/skip/take/distinct/
	-- groupBy/concat/join/...) work when chained AFTER orderBy/thenBy.
	-- Without this, self._factory is nil and those methods error with
	-- "attempt to call a nil value". The factory delegates to the sorted iter().
	self._factory = function()
		return self:iter()
	end
	return self
end

--- Builds a comparer from sort criteria.
---@param criteria table criteria Sorting criteria array.
---@return fun(a: table, b: table): boolean comparer Stable sort comparer.
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

--- Returns a fresh sorted iterator for the ordered sequence.
---@return Iterator iterator Iterator returning sorted items.
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

--- Materializes the ordered sequence into a sorted array table.
---@return table result Sorted array of items.
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
---@param keySelector KeySelector keySelector Secondary key selector.
---@return OrderedEnumerable ordered New ordered enumerable.
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
---@param keySelector KeySelector keySelector Secondary key selector.
---@return OrderedEnumerable ordered New ordered enumerable.
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
---@overload fun(): OrderedEnumerable
---@overload fun(keySelector: KeySelector): OrderedEnumerable
---@param keySelector? KeySelector keySelector Optional key selector.
---@return OrderedEnumerable ordered New ordered enumerable.
---@usage <br>
--- ```
--- local sorted = Enumerable.from({ 3, 1, 2 }):orderBy(function(v) return v end)
--- ```
function Enumerable:orderBy(keySelector)
	keySelector = keySelector or identity
	return newOrderedEnumerable(self, {
		{ selector = keySelector, descending = false }
	})
end

--- Orders the sequence in descending order.
---@overload fun(): OrderedEnumerable
---@overload fun(keySelector: KeySelector): OrderedEnumerable
---@param keySelector? KeySelector keySelector Optional key selector.
---@return OrderedEnumerable ordered New ordered enumerable.
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
---@overload fun(inner: table, outerKeySelector: fun(value: any): any, innerKeySelector: fun(value: any): any, resultSelector: fun(outer: any, inner: any): any): Enumerable
---@overload fun(inner: Enumerable, outerKeySelector: fun(value: any): any, innerKeySelector: fun(value: any): any, resultSelector: fun(outer: any, inner: any): any): Enumerable
---@overload fun(inner: IteratorFactory, outerKeySelector: fun(value: any): any, innerKeySelector: fun(value: any): any, resultSelector: fun(outer: any, inner: any): any): Enumerable
---@param inner EnumerableSource inner Inner sequence input.
---@param outerKeySelector fun(value: any): any outerKeySelector Outer key selector.
---@param innerKeySelector fun(value: any): any innerKeySelector Inner key selector.
---@param resultSelector fun(outer: any, inner: any): any resultSelector Result projection selector.
---@return Enumerable enumerable Joined enumerable.
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
				else
					-- Outer exhausted and no pending matches: terminate.
					-- Previously fell through and looped forever on empty/non-matching outers.
					return nil
				end
			end
		end
	end)
end

--- Correlates elements of two sequences and groups the results.
---@overload fun(inner: table, outerKeySelector: fun(value: any): any, innerKeySelector: fun(value: any): any, resultSelector: fun(outer: any, group: Enumerable): any): Enumerable
---@overload fun(inner: Enumerable, outerKeySelector: fun(value: any): any, innerKeySelector: fun(value: any): any, resultSelector: fun(outer: any, group: Enumerable): any): Enumerable
---@overload fun(inner: IteratorFactory, outerKeySelector: fun(value: any): any, innerKeySelector: fun(value: any): any, resultSelector: fun(outer: any, group: Enumerable): any): Enumerable
---@param inner EnumerableSource inner Inner sequence input.
---@param outerKeySelector fun(value: any): any outerKeySelector Outer key selector.
---@param innerKeySelector fun(value: any): any innerKeySelector Inner key selector.
---@param resultSelector fun(outer: any, group: Enumerable): any resultSelector Group result selector.
---@return Enumerable enumerable Group-joined enumerable.
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
---@return string str String representation name.
function Enumerable:__tostring()
	return "Enumerable"
end

OrderedEnumerable.__tostring = Enumerable.__tostring

-- Export
return Enumerable
