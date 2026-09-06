-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Function result caching / memoization utilities

-- Localized global functions for better performance
local select = select
local setmetatable = setmetatable
local tostring = tostring
local type = type
local table_concat = table.concat
local table_pack = table.pack or function(...) return { n = select("#", ...), ... } end
local table_unpack = table.unpack or unpack

----------------------------------------------------------------------
-- Types
----------------------------------------------------------------------

---@class cache.options
---@field use_args? integer[] Array of argument indices to include when generating the cache key. When nil or absent, all arguments are used.
---@field serializer? fun(value: any): string

---@class cache.cache
---@field fn function The wrapped function whose return values are cached.
---@field opts cache.options Options controlling key generation and caching behavior.
---@field store table<string, table> Internal map from generated keys to packed return values.
local cache = {}
cache.__index = cache

----------------------------------------------------------------------
-- Public API
----------------------------------------------------------------------

--- Create a new cache instance wrapping a function.<br>
--- The returned object memoizes `fn` return values keyed by stringified arguments.
---@param fn function The function to memoize. Its return values will be cached.
---@param opts? cache.options Options controlling key generation (default: {}).
---@return cache.cache instance The new cache instance wrapping `fn`.
function cache.new(fn, opts)
	return setmetatable({
		fn = fn,
		opts = opts or {},
		store = {},
	}, cache)
end

--- Generates a unique cache key from the given arguments.<br>
--- When `opts.use_args` is an array of indices, only those argument positions are stringified and used; otherwise all arguments are included.<br>
--- Each selected value is converted via `tostring` and concatenated with a null byte (`"\0"`) separator to reduce collisions.<br>
--- An empty argument set yields an empty string key.
---@param self cache.cache
---@param ... any The arguments to derive the cache key from.
---@return string key The generated cache key. Empty string when no relevant arguments are present.
function cache:generate_key(...)
	if self.opts.serializer then
		return self.opts.serializer(...)
	end

	local args = table_pack(...)
	local key_parts = {}

	local use_args = self.opts.use_args
	if type(use_args) == "table" then
		for i = 1, #use_args do
			key_parts[i] = tostring(args[use_args[i]])
		end
	else
		for i = 1, args.n do
			key_parts[i] = tostring(args[i])
		end
	end

	return #key_parts > 0 and table_concat(key_parts, "\0") or ""
end

--- Retrieves the cached result for the given arguments, or computes and caches it on miss.<br>
--- On a cache miss the wrapped function `self.fn` is invoked with `...`, its return values are packed (preserving `nil`s and multiple returns via `n` count) and stored under the generated key.<br>
--- Subsequent calls with the same key return the unpacked cached values.
---@param self cache.cache
---@param ... any Arguments forwarded to the wrapped function and key generator.
---@return ... The (cached or freshly computed) return values of the wrapped function.
function cache:get(...)
	local key = self:generate_key(...)

	if not self.store[key] then
		self.store[key] = table_pack(self.fn(...))
	end

	local res = self.store[key]
	return table_unpack(res, 1, res.n)
end

--- Invalidates cached entries.<br>
--- When called with arguments, only the entry matching the generated key is removed;
--- when called without arguments, the entire cache store is cleared.
---@param self cache.cache
---@param ... any Arguments identifying the entry to invalidate. Omit to clear all entries.
function cache:invalidate(...)
	if select("#", ...) > 0 then
		local key = self:generate_key(...)
		self.store[key] = nil
	else
		self.store = {}
	end
end

----------------------------------------------------------------------
-- Metamethods
----------------------------------------------------------------------

--- Allows the cache instance to be invoked directly as a function.
cache.__call = cache.get

-- Export
return cache
