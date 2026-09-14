-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Small composable Optional<T> for LuaJIT/5.1+.
-- Some(value) holds a present value, None marks absence (nil is absence).

-- Localized global functions for better performance
local error = error
local pcall = pcall
local rawget = rawget
local select = select
local setmetatable = setmetatable
local tostring = tostring
local type = type
local string_format = string.format

--- Module namespace for the Optional library.<br>
--- Calling `Optional(value)` equals `Optional.ofNullable(value)`.
---@class Optional
local Optional = {}

--- Annotation aliases for LuaLS; usable from user code as well.
---@alias OptionalSomeFn<T,R> fun(value: T): R Mapping applied to a present value.
---@alias OptionalPredicate<T> fun(value: T): boolean Predicate testing a present value.
---@alias OptionalNoneFn<R> fun(): R Factory producing a fallback value.
---@alias OptionalLazyFn<T> fun(): T Factory producing a lazy fallback value.
---@alias OptionalTapFn<T> fun(value: T) Observer of a present value.
---@alias OptionalValueOrOptional<T> T|OptionalInstance<T> Raw value or Optional wrapper.

--- The shared metatable carries the OptionalInstance class annotation so
--- that LuaLS attaches every method defined on it to real instances; this
--- is what makes completion and type checking of optional:... calls work.
---@class OptionalInstance<T>
---@field _value T Contained value (`nil` for None).
---@field _has_value boolean Presence flag (`true` for Some).
local Optional_mt = {}

----------------------------------------------------------------------
-- Internal helpers
----------------------------------------------------------------------

-- Private identity key carried by every Optional instance.
--
-- The metatable is hidden behind __metatable (see "Metatable setup" below),
-- so getmetatable() returns the string "Optional" instead of the metatable
-- itself, and getmetatable(v) == Optional_mt can never be true. Every
-- instance -- including the None singleton -- therefore carries this key.
-- Because it is a fresh table used as a key, it cannot collide with any
-- string-keyed field.
local OPTIONAL_SENTINEL = {}

local function type_error(function_name, expected, value)
	return error(
		string_format(
			"Optional.%s: expected %s, got %s",
			function_name,
			expected,
			type(value)
		),
		3
	)
end

local function is_optional(value)
	return type(value) == "table"
		and rawget(value, OPTIONAL_SENTINEL) == true
end

local function assert_optional(value, function_name)
	if not is_optional(value) then
		return error(
			string_format(
				"Optional.%s: expected Optional, got %s",
				function_name,
				type(value)
			),
			3
		)
	end

	return value
end

--- Single construction point for every Some instance: it keeps the field layout identical everywhere and guarantees the sentinel key is present.
---@generic T
---@param value T Value to wrap (must be non-nil).
---@return OptionalInstance<T> optional New Some instance.
local function make_some(value)
	return setmetatable({
		_value = value,
		_has_value = true,
		[OPTIONAL_SENTINEL] = true
	}, Optional_mt)
end

----------------------------------------------------------------------
-- None singleton
----------------------------------------------------------------------

--- The singleton carries the sentinel key as well so that is_optional()
--- recognizes it like any other instance.
---@type OptionalInstance<any>
local NONE = {
	_value = nil,
	_has_value = false,
	[OPTIONAL_SENTINEL] = true
}

----------------------------------------------------------------------
-- Constructors
----------------------------------------------------------------------

--- Create a present Optional.<br>
--- Errors on `nil`, use `none` for absence.
---@generic T
---@param value T Value to wrap (must be non-nil).
---@return OptionalInstance<T> optional New Some instance.
function Optional.some(value)
	if value == nil then
		return error("Optional.some: value cannot be nil; use Optional.none() for absence", 2)
	end

	return make_some(value)
end

--- Create a present Optional requiring a non-nil value.<br>
--- Equivalent to `Optional.some`.
---@generic T
---@param value T Value to wrap (must be non-nil).
---@return OptionalInstance<T> optional New Some instance.
function Optional.of(value)
	if value == nil then
		return error("Optional.of: value cannot be nil", 2)
	end

	return make_some(value)
end

--- Create an Optional from a nullable Lua value.<br>
--- `nil` becomes None, any other value becomes Some(value).
---@generic T
---@param value T? Nullable value to wrap.
---@return OptionalInstance<T> optional Some(value) or None.
function Optional.ofNullable(value)
	if value == nil then
		return NONE
	end

	return make_some(value)
end

--- Return the singleton None value.
---@return OptionalInstance<any> none The shared None instance.
function Optional.none()
	return NONE
end

--- Alias for `Optional.none`, following Java's `Optional.empty`.
---@return OptionalInstance<any> none The shared None instance.
function Optional.empty()
	return NONE
end

--- Create an Optional based on a predicate.<br>
--- Without predicate this behaves like `ofNullable`.<br>
--- With predicate, Some(value) on `true`, None otherwise.
---@generic T
---@param value T Nullable value to test.
---@param predicate? fun(value: T): boolean Predicate testing the value.
---@return OptionalInstance<T> optional Some(value) or None.
function Optional.from(value, predicate)
	if value == nil then
		return NONE
	end

	if predicate == nil then
		return make_some(value)
	end

	if type(predicate) ~= "function" then
		return type_error("from", "function", predicate)
	end

	if predicate(value) then
		return make_some(value)
	end

	return NONE
end

--- Call a function and capture any error it raises.<br>
--- Arguments after `fn` are forwarded to the call.<br>
--- Some(first return value) on success with non-nil result, None on raise or `nil`.<br>
--- The raised error itself is discarded, use `pcall` when the reason matters.
---@generic R
---@param fn fun(...): R? Function to call safely.
---@param ... any Arguments forwarded to `fn`.
---@return OptionalInstance<R> optional Some(result) or None.
function Optional.try(fn, ...)
	if type(fn) ~= "function" then
		return type_error("try", "function", fn)
	end

	local ok, result = pcall(fn, ...)

	if ok and result ~= nil then
		return make_some(result)
	end

	return NONE
end

--- Check whether a value is an Optional instance.
---@param value any Value to test.
---@return boolean result `true` when the value is an Optional.
function Optional.isOptional(value)
	return is_optional(value)
end

----------------------------------------------------------------------
-- Basic state
----------------------------------------------------------------------

--- Return true when this Optional contains a value.
---@param self OptionalInstance<T> The optional instance.
---@return boolean present `true` when a value is present.
function Optional_mt:isSome()
	return self._has_value
end

--- Return true when this Optional contains no value.
---@param self OptionalInstance<T> The optional instance.
---@return boolean absent `true` when no value is present.
function Optional_mt:isNone()
	return not self._has_value
end

--- Return true when a value is present.<br>
--- Alias for `isSome`, useful when writing predicates.
---@param self OptionalInstance<T> The optional instance.
---@return boolean present `true` when a value is present.
function Optional_mt:isPresent()
	return self._has_value
end

--- Return true when no value is present.<br>
--- Alias for `isNone`.
---@param self OptionalInstance<T> The optional instance.
---@return boolean absent `true` when no value is present.
function Optional_mt:isEmpty()
	return not self._has_value
end

--- Return whether the Optional is truthy as a container.<br>
--- Always `true` because both Some and None are tables.<br>
--- Use `isSome` when testing whether a value exists.
---@param self OptionalInstance<T> The optional instance.
---@return boolean truthy Always `true`.
function Optional_mt:isTruthy()
	return true
end

----------------------------------------------------------------------
-- Extraction
----------------------------------------------------------------------

--- Return the contained value.<br>
--- Raises an error for None.
---@generic T
---@param self OptionalInstance<T> The optional instance.
---@return T value The contained value.
function Optional_mt:get()
	if not self._has_value then
		return error("Optional.get: attempted to extract a value from None", 2)
	end

	return self._value
end

--- Alias for `get`.<br>
--- Raises an error for None.
---@generic T
---@param self OptionalInstance<T> The optional instance.
---@return T value The contained value.
function Optional_mt:unwrap()
	if not self._has_value then
		return error("Optional.unwrap: attempted to unwrap None", 2)
	end

	return self._value
end

--- Return the value or raise an error with a custom message.
---@generic T
---@param self OptionalInstance<T> The optional instance.
---@param message string Message for the raised error.
---@return T value The contained value.
function Optional_mt:expect(message)
	if not self._has_value then
		return error(message, 2)
	end

	return self._value
end

--- Return the contained value or a fallback value.
---@generic T,U
---@param self OptionalInstance<T> The optional instance.
---@param default U Fallback value for None.
---@return T|U value Contained value or fallback.
function Optional_mt:getOrElse(default)
	if self._has_value then
		return self._value
	end

	return default
end

--- Return the contained value or lazily compute a fallback.<br>
--- The function is only called when the Optional is None.
---@generic T,U
---@param self OptionalInstance<T> The optional instance.
---@param fn fun(): U Factory producing the fallback.
---@return T|U value Contained value or fallback.
function Optional_mt:getOrElseLazy(fn)
	if type(fn) ~= "function" then
		return type_error("getOrElseLazy", "function", fn)
	end

	if self._has_value then
		return self._value
	end

	return fn()
end

--- Alias for `getOrElse`.
---@generic T,U
---@param self OptionalInstance<T> The optional instance.
---@param default U Fallback value for None.
---@return T|U value Contained value or fallback.
function Optional_mt:unwrapOr(default)
	return self:getOrElse(default)
end

--- Return the value or compute a fallback lazily.
---@generic T,U
---@param self OptionalInstance<T> The optional instance.
---@param fn fun(): U Factory producing the fallback.
---@return T|U value Contained value or fallback.
function Optional_mt:unwrapOrElse(fn)
	if type(fn) ~= "function" then
		return type_error("unwrapOrElse", "function", fn)
	end

	if self._has_value then
		return self._value
	end

	return fn()
end

----------------------------------------------------------------------
-- Functional transformations
----------------------------------------------------------------------

--- Transform the contained value.<br>
--- The callback never runs for None.<br>
--- A `nil` callback result becomes None.
---@generic T,R
---@param self OptionalInstance<T> The optional instance.
---@param fn fun(value: T): R? Callback transforming the value.
---@return OptionalInstance<R> optional Mapped Optional or None.
function Optional_mt:map(fn)
	if type(fn) ~= "function" then
		return type_error("map", "function", fn)
	end

	if not self._has_value then
		return NONE
	end

	return Optional.ofNullable(fn(self._value))
end

--- Map the value, returning a normal value instead of an Optional.
---@generic T,R,D
---@param self OptionalInstance<T> The optional instance.
---@param default D Fallback value for None.
---@param fn fun(value: T): R Callback transforming the value.
---@return R|D value Mapped value or fallback.
function Optional_mt:mapOr(default, fn)
	if type(fn) ~= "function" then
		return type_error("mapOr", "function", fn)
	end

	if not self._has_value then
		return default
	end

	return fn(self._value)
end

--- Map the value or lazily generate the missing case.
---@generic T,R,D
---@param self OptionalInstance<T> The optional instance.
---@param default_fn fun(): D Factory producing the fallback.
---@param fn fun(value: T): R Callback transforming the value.
---@return R|D value Mapped value or fallback.
function Optional_mt:mapOrElse(default_fn, fn)
	if type(default_fn) ~= "function" then
		return type_error("mapOrElse", "function", default_fn)
	end

	if type(fn) ~= "function" then
		return type_error("mapOrElse", "function", fn)
	end

	if self._has_value then
		return fn(self._value)
	end

	return default_fn()
end

--- Transform the contained value into another Optional.<br>
--- Useful for chaining operations which can themselves fail.
---@generic T,R
---@param self OptionalInstance<T> The optional instance.
---@param fn fun(value: T): OptionalInstance<R> Callback returning an Optional.
---@return OptionalInstance<R> optional Callback result or None.
function Optional_mt:flatMap(fn)
	if type(fn) ~= "function" then
		return type_error("flatMap", "function", fn)
	end

	if not self._has_value then
		return NONE
	end

	local result = fn(self._value)

	if not is_optional(result) then
		return error(
			"Optional.flatMap: callback must return an Optional",
			2
		)
	end

	return result
end

--- Alias for `flatMap`.
---@generic T,R
---@param self OptionalInstance<T> The optional instance.
---@param fn fun(value: T): OptionalInstance<R> Callback returning an Optional.
---@return OptionalInstance<R> optional Callback result or None.
function Optional_mt:andThen(fn)
	return self:flatMap(fn)
end

--- Flatten a nested Optional.<br>
--- An inner Optional is returned directly, so Some(Some(x)) becomes Some(x) and Some(None) becomes None.<br>
--- Some holding any other value returns unchanged, None stays None.
---@generic T
---@param self OptionalInstance<T> The optional instance.
---@return OptionalInstance<T> optional Flattened Optional.
function Optional_mt:flatten()
	if not self._has_value then
		return NONE
	end

	if is_optional(self._value) then
		return self._value
	end

	return self
end

--- Keep the value only when predicate returns true.<br>
--- The predicate never runs for None.
---@generic T
---@param self OptionalInstance<T> The optional instance.
---@param predicate fun(value: T): boolean Predicate testing the value.
---@return OptionalInstance<T> optional Self on `true`, None otherwise.
function Optional_mt:filter(predicate)
	if type(predicate) ~= "function" then
		return type_error("filter", "function", predicate)
	end

	if not self._has_value then
		return NONE
	end

	if predicate(self._value) then
		return self
	end

	return NONE
end

----------------------------------------------------------------------
-- Optional composition
----------------------------------------------------------------------

--- Return None if either Optional is None.<br>
--- Otherwise returns the other Optional, mirroring a logical AND that keeps its right operand (like Rust's `Option::and`).
---@generic T,U
---@param self OptionalInstance<T> The optional instance.
---@param other OptionalInstance<U> Other Optional to combine with.
---@return OptionalInstance<U> optional `other` when both present, else None.
function Optional_mt:and_(other)
	assert_optional(other, "and")

	if self._has_value and other._has_value then
		return other
	end

	return NONE
end

--- Return this Optional when present, otherwise return another Optional.
---@generic T,U
---@param self OptionalInstance<T> The optional instance.
---@param other OptionalInstance<U> Other Optional to fall back to.
---@return OptionalInstance<T|U> optional Self when present, else `other`.
function Optional_mt:or_(other)
	assert_optional(other, "or")

	if self._has_value then
		return self
	end

	return other
end

-- `and` and `or` are reserved words in Lua, so the colon call syntax `optional:and(other)` is a syntax error.
Optional_mt["and"] = Optional_mt.and_
Optional_mt.And = Optional_mt.and_
Optional_mt["or"] = Optional_mt.or_
Optional_mt.Or = Optional_mt.or_

--- Return this Optional when present, otherwise lazily produce another Optional.
---@generic T,U
---@param self OptionalInstance<T> The optional instance.
---@param fn fun(): OptionalInstance<T|U> Factory producing the fallback Optional.
---@return OptionalInstance<T|U> optional Self when present, else callback result.
function Optional_mt:orElse(fn)
	if type(fn) ~= "function" then
		return type_error("orElse", "function", fn)
	end

	if self._has_value then
		return self
	end

	local result = fn()

	if not is_optional(result) then
		return error(
			"Optional.orElse: callback must return an Optional",
			2
		)
	end

	return result
end

--- Exclusive OR between two Optionals.<br>
--- Returns the present Optional only when exactly one side is present.
---@generic T,U
---@param self OptionalInstance<T> The optional instance.
---@param other OptionalInstance<U> Other Optional to compare with.
---@return OptionalInstance<T|U> optional The sole present side, else None.
function Optional_mt:xor(other)
	assert_optional(other, "xor")

	if self._has_value ~= other._has_value then
		if self._has_value then
			return self
		end

		return other
	end

	return NONE
end

--- Combine two Optionals into an Optional pair.<br>
--- None when either side is None.
---@generic A,B
---@param self OptionalInstance<A> The optional instance.
---@param other OptionalInstance<B> Other Optional to combine with.
---@return OptionalInstance<{ [1]: A, [2]: B }> optional Pair Optional or None.
function Optional_mt:zip(other)
	assert_optional(other, "zip")

	if not self._has_value or not other._has_value then
		return NONE
	end

	return Optional.some({
		self._value,
		other._value
	})
end

--- Combine two Optionals using a callback.<br>
--- None when either side is None.
---@generic A,B,R
---@param self OptionalInstance<A> The optional instance.
---@param other OptionalInstance<B> Other Optional to combine with.
---@param fn fun(a: A, b: B): R? Callback combining both values.
---@return OptionalInstance<R> optional Combined Optional or None.
function Optional_mt:zipWith(other, fn)
	assert_optional(other, "zipWith")

	if type(fn) ~= "function" then
		return type_error("zipWith", "function", fn)
	end

	if not self._has_value or not other._has_value then
		return NONE
	end

	return Optional.ofNullable(
		fn(self._value, other._value)
	)
end

----------------------------------------------------------------------
-- Inspection / branching
----------------------------------------------------------------------

--- Execute a callback when a value is present.<br>
--- Returns self so operations can be chained.
---@generic T
---@param self OptionalInstance<T> The optional instance.
---@param fn fun(value: T) Observer of the present value.
---@return OptionalInstance<T> optional Self for chaining.
function Optional_mt:tap(fn)
	if type(fn) ~= "function" then
		return type_error("tap", "function", fn)
	end

	if self._has_value then
		fn(self._value)
	end

	return self
end

--- Execute a callback when no value is present.<br>
--- Returns self so operations can be chained.
---@generic T
---@param self OptionalInstance<T> The optional instance.
---@param fn fun() Observer of absence.
---@return OptionalInstance<T> optional Self for chaining.
function Optional_mt:tapNone(fn)
	if type(fn) ~= "function" then
		return type_error("tapNone", "function", fn)
	end

	if not self._has_value then
		fn()
	end

	return self
end

--- Pattern-match the Optional.<br>
--- Exactly one callback is invoked.
---@generic T,R
---@param self OptionalInstance<T> The optional instance.
---@param some_fn fun(value: T): R Callback handling the present value.
---@param none_fn fun(): R Callback handling absence.
---@return R result Selected callback result.
function Optional_mt:match(some_fn, none_fn)
	if type(some_fn) ~= "function" then
		return type_error("match", "function", some_fn)
	end

	if type(none_fn) ~= "function" then
		return type_error("match", "function", none_fn)
	end

	if self._has_value then
		return some_fn(self._value)
	end

	return none_fn()
end

--- Fold an Optional into a single value.
---@generic T,R,D
---@param self OptionalInstance<T> The optional instance.
---@param some_fn fun(value: T): R Callback handling the present value.
---@param none_value D Fallback value for None.
---@return R|D result Mapped value or fallback.
function Optional_mt:fold(some_fn, none_value)
	if type(some_fn) ~= "function" then
		return type_error("fold", "function", some_fn)
	end

	if self._has_value then
		return some_fn(self._value)
	end

	return none_value
end

----------------------------------------------------------------------
-- Containment / equality
----------------------------------------------------------------------

--- Check whether the Optional contains a value equal to `value`.<br>
--- Uses Lua `==`.
---@generic T
---@param self OptionalInstance<T> The optional instance.
---@param value T Value to compare against.
---@return boolean equal `true` when the contained value equals `value`.
function Optional_mt:contains(value)
	return self._has_value and self._value == value
end

--- Check whether the contained value satisfies a predicate.
---@generic T
---@param self OptionalInstance<T> The optional instance.
---@param predicate fun(value: T): boolean Predicate testing the value.
---@return boolean matched `true` when present and the predicate passes.
function Optional_mt:containsBy(predicate)
	if type(predicate) ~= "function" then
		return type_error("containsBy", "function", predicate)
	end

	if not self._has_value then
		return false
	end

	-- Normalize the predicate result so that truthy non-boolean returns
	-- cannot leak out of this API.
	return not not predicate(self._value)
end

--- Compare two Optionals.<br>
--- Two None values are equal.<br>
--- Two Some values are equal when their contained values are equal.
---@generic T
---@param self OptionalInstance<T> The optional instance.
---@param other OptionalInstance<T> Other Optional to compare with.
---@return boolean equal `true` when both sides match.
function Optional_mt:equals(other)
	if not is_optional(other) then
		return false
	end

	if self._has_value ~= other._has_value then
		return false
	end

	if not self._has_value then
		return true
	end

	return self._value == other._value
end

----------------------------------------------------------------------
-- Iteration
----------------------------------------------------------------------

--- Return a one-element or empty iterator.<br>
--- This intentionally avoids constructing a table.
---@generic T
---@param self OptionalInstance<T> The optional instance.
---@return fun(): T? iterator Single-shot iterator yielding the value or nothing.
---@usage <br>
--- ```
--- for value in optional:iter() do
---   ...
--- end
--- ```
function Optional_mt:iter()
	local consumed = false

	return function()
		if consumed or not self._has_value then
			return nil
		end

		consumed = true
		return self._value
	end
end

--- Return an iterator suitable for generic for loops.
---@generic T
---@param self OptionalInstance<T> The optional instance.
---@return fun(): T? iterator Single-shot iterator yielding the value or nothing.
function Optional_mt:values()
	return self:iter()
end

----------------------------------------------------------------------
-- Conversion
----------------------------------------------------------------------

--- Return the contained value or nil.<br>
--- This is the idiomatic Lua conversion back to a nullable value.
---@generic T
---@param self OptionalInstance<T> The optional instance.
---@return T? value Contained value or `nil`.
function Optional_mt:toNullable()
	if self._has_value then
		return self._value
	end

	return nil
end

--- Convert to a simple representation table.<br>
--- Some becomes `{ has_value = true, value = ... }`, None becomes `{ has_value = false }`.<br>
--- A fresh table is returned each time.
---@generic T
---@param self OptionalInstance<T> The optional instance.
---@return table representation Fresh representation table.
function Optional_mt:toTable()
	if self._has_value then
		return {
			has_value = true,
			value = self._value
		}
	end

	return {
		has_value = false
	}
end

--- Return a human-readable representation.
---@param self OptionalInstance<T> The optional instance.
---@return string text `"Some(...)"` or `"None"`.
function Optional_mt:toString()
	if not self._has_value then
		return "None"
	end

	return "Some(" .. tostring(self._value) .. ")"
end

----------------------------------------------------------------------
-- Metamethods
----------------------------------------------------------------------

--- Stringify the Optional via `toString`.
---@param self OptionalInstance<any> The optional instance.
---@return string text `"Some(...)"` or `"None"`.
function Optional_mt.__tostring(self)
	return self:toString()
end

--- Compare two Optionals for equality.
---@param a OptionalInstance<any> First optional to compare.
---@param b OptionalInstance<any> Second optional to compare.
---@return boolean equal `true` when both sides match.
function Optional_mt.__eq(a, b)
	if not is_optional(a) or not is_optional(b) then
		return false
	end

	if a._has_value ~= b._has_value then
		return false
	end

	if not a._has_value then
		return true
	end

	return a._value == b._value
end

--- Support the length operator: `#optional` is 1 for Some and 0 for None.<br>
--- Only Lua 5.2+ (and LuaJIT builds honoring `__len` for tables) invoke this metamethod.<br>
--- Plain Lua 5.1 ignores it and non-sequence length is unspecified there, so portable code should prefer `isSome` / `isNone`.
---@param self OptionalInstance<any> The optional instance.
---@return integer count `1` for Some, `0` for None.
function Optional_mt.__len(self)
	if self._has_value then
		return 1
	end

	return 0
end

----------------------------------------------------------------------
-- Metatable setup
----------------------------------------------------------------------

Optional_mt.__index = Optional_mt

-- Hide and protect the metatable.
--
-- getmetatable(optional) returns the string "Optional", and any later
-- setmetatable(optional, ...) raises an error, which keeps the shared
-- method table from being swapped out from under live instances.
--
-- NOTE: because __metatable hides the real metatable, getmetatable() can
-- never be used to recognize instances (it does not return Optional_mt).
-- That is why is_optional() checks the private sentinel key instead; a
-- naive getmetatable comparison would wrongly reject every instance.
--
-- The instance itself is still a normal Lua table, because complete
-- immutability would require closure-backed state and increase per-instance
-- allocation cost substantially.
Optional_mt.__metatable = "Optional"

setmetatable(NONE, Optional_mt)

----------------------------------------------------------------------
-- Callable module
----------------------------------------------------------------------

setmetatable(Optional, {
	--- Calling `Optional(value)` equals `Optional.ofNullable(value)`.
	---@generic T
	---@param value T? Nullable value to wrap.
	---@return OptionalInstance<T> optional Some(value) or None.
	__call = function(_, value)
		return Optional.ofNullable(value)
	end
})

----------------------------------------------------------------------
-- Convenience constructors / aliases
----------------------------------------------------------------------

--- Alias for `Optional.ofNullable`.
---@generic T
---@param value T? Nullable value to wrap.
---@return OptionalInstance<T> optional Some(value) or None.
function Optional.valueOf(value)
	return Optional.ofNullable(value)
end

--- Return Some(value) when `value` is non-nil, otherwise None.
---@generic T
---@param value T? Nullable value to wrap.
---@return OptionalInstance<T> optional Some(value) or None.
function Optional.coalesce(value)
	return Optional.ofNullable(value)
end

----------------------------------------------------------------------
-- Variadic combinators
----------------------------------------------------------------------

--- Combine any number of Optionals into an Optional array of their values.<br>
--- Returns None as soon as any argument is None.<br>
--- Combining zero Optionals yields Some({}), because no side is missing.
---@generic T
---@param ... OptionalInstance<T> Optionals to combine.
---@return OptionalInstance<T[]> combined Optional holding the collected values, None on any absence.
function Optional.zipAll(...)
	local count = select("#", ...)

	if count == 0 then
		return make_some({})
	end

	local values = {}

	for i = 1, count do
		local item = select(i, ...)
		assert_optional(item, "zipAll")

		if not item._has_value then
			return NONE
		end

		values[i] = item._value
	end

	return make_some(values)
end

--- Return the first present Optional among the arguments.<br>
--- When every argument is None (or no arguments are given at all), None is returned.
---@generic T
---@param ... OptionalInstance<T> Candidates in priority order.
---@return OptionalInstance<T> optional First present Optional or None.
function Optional.firstSome(...)
	for i = 1, select("#", ...) do
		local item = select(i, ...)
		assert_optional(item, "firstSome")

		if item._has_value then
			return item
		end
	end

	return NONE
end

----------------------------------------------------------------------
-- Public constants
----------------------------------------------------------------------

--- The singleton None instance.<br>
--- `Optional.none()` is generally clearer, but `Optional.NONE` avoids a function call in very hot code.
---@type OptionalInstance<any>
Optional.NONE = NONE

----------------------------------------------------------------------
-- Public class/metatable helpers
----------------------------------------------------------------------

--- Get the Optional metatable.<br>
--- Primarily useful for advanced integration / type inspection.
---@return table metatable The shared Optional metatable.
function Optional.getMetatable()
	return Optional_mt
end

----------------------------------------------------------------------
-- Snake-case aliases
----------------------------------------------------------------------

Optional.of_nullable = Optional.ofNullable
Optional.is_optional = Optional.isOptional
Optional.value_of = Optional.valueOf
Optional.zip_all = Optional.zipAll
Optional.first_some = Optional.firstSome
Optional.get_metatable = Optional.getMetatable

Optional_mt.is_some = Optional_mt.isSome
Optional_mt.is_none = Optional_mt.isNone
Optional_mt.is_present = Optional_mt.isPresent
Optional_mt.is_empty = Optional_mt.isEmpty
Optional_mt.is_truthy = Optional_mt.isTruthy
Optional_mt.get_or_else = Optional_mt.getOrElse
Optional_mt.get_or_else_lazy = Optional_mt.getOrElseLazy
Optional_mt.unwrap_or = Optional_mt.unwrapOr
Optional_mt.unwrap_or_else = Optional_mt.unwrapOrElse
Optional_mt.map_or = Optional_mt.mapOr
Optional_mt.map_or_else = Optional_mt.mapOrElse
Optional_mt.flat_map = Optional_mt.flatMap
Optional_mt.and_then = Optional_mt.andThen
Optional_mt.or_else = Optional_mt.orElse
Optional_mt.zip_with = Optional_mt.zipWith
Optional_mt.tap_none = Optional_mt.tapNone
Optional_mt.contains_by = Optional_mt.containsBy
Optional_mt.to_nullable = Optional_mt.toNullable
Optional_mt.to_table = Optional_mt.toTable
Optional_mt.to_string = Optional_mt.toString

-- Export
return Optional
