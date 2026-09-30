-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- LINQ API for Lua tables and iterables

-- Localized global functions for better performance
local error = error
local getmetatable = getmetatable
local ipairs = ipairs
local rawget = rawget
local setmetatable = setmetatable
local tostring = tostring
local type = type
local math_max = math.max
local table_insert = table.insert
local table_sort = table.sort

---@class linq.Linq
---@field _type "table"|"iter" Source kind: a table was passed to `Linq.new`, or an iterator function
---@field _data table? Backing array-like table, set only when `_type == "table"`
---@field _iter_fn fun():(k: integer, v: any)? Backing iterator function, set only when `_type == "iter"`
---@field _sort_meta linq.SortMeta? Present on queries produced by OrderBy/ThenBy
local Linq = {}
Linq.__index = Linq

--- One ordering step: a key selector plus its direction.
---@class linq.SortKeySelector
---@field sel fun(v: any): any Key extraction function applied to a value.
---@field desc boolean `true` for descending order on this key.

--- Sort metadata retained on queries produced by OrderBy/ThenBy.
---@class linq.SortMeta
---@field keySelectors linq.SortKeySelector[] Ordered list of key selectors.

--- Internal sortable record produced by `build_sort_array`.
---@class linq.SortEntry
---@field value any Original value, unwrapped after sorting.
---@field __pos integer Original 1-based position, used as stable tie-break.
---@field __keys any[] Precomputed keys, parallel to the owning SortMeta.keySelectors.
---@field __desc boolean[] Precomputed desc flags, parallel to `__keys`.

--- Create a Linq query from a table or iterator.
---@param src table|fun():(k: integer, v: any) Source table or iterator function returning (index, value).
---@return linq.Linq
local function Linq_new(src)
	local self = setmetatable({}, Linq)
	if type(src) == "table" then
		self._type = "table"
		self._data = src
	elseif type(src) == "function" then
		self._type = "iter"
		-- NOTE: stored as _iter_fn (not _iter) to avoid shadowing the Linq:_iter() method
		-- via __index. Previously self._iter collided with the method name, causing
		-- self._iter to resolve to the method itself for table-backed queries.
		self._iter_fn = src
	else
		return error("Linq.new expects table or iterator", 2)
	end
	return self
end

Linq.new = Linq_new
Linq.From = Linq_new

--- Internal helper: ipairs-style iterator for array-like tables
local function ipairs_iter(tbl)
	local i, n = 0, #tbl
	return function()
		i = i + 1
		if i <= n then return i, tbl[i] end
	end
end

--- Internal: get iterator over query
---@return fun(): (integer, any) iterator
function Linq._iter(self)
	-- Use rawget so the method itself (found via __index) is not mistaken for stored state.
	---@type fun(): (integer, any)?
	local fn = rawget(self, "_iter_fn")
	if fn then return fn end
	local data = rawget(self, "_data")
	if data == nil then
		return error("Linq: query has no source data or iterator", 2)
	end
	return ipairs_iter(data)
end

--- Materialize to array-like table
---@return table array
function Linq.ToTable(self)
	local out = {}
	-- Append instead of out[i] = v: lazy iterators preserve source keys (e.g. Where
	-- keeps original indices, SelectMany reuses inner indices), so direct indexing
	-- would produce sparse/overwritten results. Appending always yields a dense array.
	for _, v in self:_iter() do table_insert(out, v) end
	return out
end

Linq.ToArray = Linq.ToTable -- alias

--- Where: filter elements by predicate
---@param pred fun(value: any, k: integer): boolean Predicate
---@return linq.Linq
function Linq:Where(pred)
	local src = self:_iter()
	local function iter()
		while true do
			local k, v = src()
			if k == nil then return end
			if pred(v, k) then return k, v end
		end
	end
	return Linq_new(iter)
end

--- Select: project each element
---@param proj fun(value: any, k: integer): any
---@return linq.Linq
function Linq:Select(proj)
	local src = self:_iter()
	local function iter()
		local k, v = src()
		if k == nil then return end
		return k, proj(v, k)
	end
	return Linq_new(iter)
end

--- SelectMany: flatten sequences
---@param proj fun(value: any, k: integer): (table|linq.Linq|fun(): (k: integer, v: any))
---@return linq.Linq
function Linq:SelectMany(proj)
	local outer = self:_iter()
	local inner
	local function iter()
		while true do
			if inner then
				local k, v = inner()
				if k ~= nil then return k, v end
				inner = nil
			end
			local ok, ov = outer()
			if ok == nil then return end
			local res = proj(ov, ok)
			if res == nil then
				inner = nil
			elseif getmetatable(res) == Linq then
				inner = res:_iter()
			elseif type(res) == "table" then
				inner = ipairs_iter(res)
			elseif type(res) == "function" then
				inner = res
			else
				return error("SelectMany selector must return table, Linq, or iterator", 2)
			end
		end
	end
	return Linq_new(iter)
end

--- Internal: build sortable array with key selectors applied
---@param values any[] Array of values
---@param keySelectors linq.SortKeySelector[] Array of { sel=function(v)->key, desc=boolean }
---@return linq.SortEntry[] array Array of sortable records (see linq.SortEntry)
local function build_sort_array(values, keySelectors)
	local arr = {}
	for i = 1, #values do
		local v, keys, desc = values[i], {}, {}
		-- Store desc flags separately for comparison
		for j, ks in ipairs(keySelectors) do
			table_insert(keys, ks.sel(v))
			table_insert(desc, ks.desc)
		end
		---@type linq.SortEntry
		local entry = { value = v, __pos = i, __keys = keys, __desc = desc }
		arr[i] = entry
	end
	return arr
end

--- Internal: lexicographic compare using precomputed keys and desc flags
---@param a linq.SortEntry
---@param b linq.SortEntry
---@return boolean (a < b)
local function lex_compare(a, b)
	local ak = a.__keys
	local bk = b.__keys
	local ad = a.__desc
	local len = math_max(#ak, #bk)
	for i = 1, len do
		local av = ak[i]
		local bv = bk[i]
		if av ~= bv then
			local desc_flag = ad[i] or false
			if desc_flag then
				return av > bv
			end
			return av < bv
		end
	end
	-- Stable fallback by original index
	return a.__pos < b.__pos
end

--- OrderBy: returns a Linq whose elements are sorted by keySel (stable).<br>
--- Stores key selector functions in sort_meta so ThenBy can append selectors without recomputing earlier keys.
---@param self linq.Linq
---@param keySel fun(v: any): any
---@param desc? boolean Optional flag for descending order (default: false)
---@return linq.Linq
function Linq:OrderBy(keySel, desc)
	local values = self:ToTable()
	local keySelectors = { { sel = keySel, desc = desc == true } }
	local arr = build_sort_array(values, keySelectors)
	table_sort(arr, lex_compare)
	-- Unwrap values
	local out = {}
	for i, e in ipairs(arr) do table_insert(out, e.value) end
	local q = Linq_new(out)
	-- Store key selector functions and desc flags for future ThenBy calls
	q._sort_meta = { keySelectors = keySelectors }
	return q
end

--- OrderByDescending: convenience alias for OrderBy with descending order
---@param self linq.Linq
---@param keySel fun(v: any): any
---@return linq.Linq
function Linq:OrderByDescending(keySel)
	return self:OrderBy(keySel, true)
end

--- ThenBy: add a secondary (or tertiary...) ordering to a previously ordered Linq.<br>
--- Uses stored key selector functions in sort_meta to perform a stable multi-key sort without recomputing earlier keys.<br>
--- If called on an unordered sequence, behaves like OrderBy.
---@param self linq.Linq
---@param keySel fun(v: any): any
---@param desc? boolean Optional flag for descending order (default: false)
---@return linq.Linq
function Linq:ThenBy(keySel, desc)
	desc = desc == true
	-- If the sequence was not produced by OrderBy, just call OrderBy on current sequence
	if not self._sort_meta or not self._sort_meta.keySelectors then
		return self:OrderBy(keySel, desc)
	end
	-- Extend keySelectors
	local keySelectors = {}
	for _, ks in ipairs(self._sort_meta.keySelectors) do
		table_insert(keySelectors, { sel = ks.sel, desc = ks.desc })
	end
	table_insert(keySelectors, { sel = keySel, desc = desc })
	-- Materialize current values and build new sort array using all selectors
	local values = self:ToTable()
	local arr = build_sort_array(values, keySelectors)
	table_sort(arr, lex_compare)
	local out = {}
	for _, e in ipairs(arr) do table_insert(out, e.value) end
	local q = Linq_new(out)
	q._sort_meta = { keySelectors = keySelectors }
	return q
end

--- ThenByDescending: convenience alias for ThenBy with descending order
---@param self linq.Linq
---@param keySel fun(v: any): any
---@return linq.Linq
function Linq:ThenByDescending(keySel)
	return self:ThenBy(keySel, true)
end

--- Internal: materialize an inner sequence (Linq|table|iterator) into a dense array.
---@param inner linq.Linq|table|function
---@return table array
local function materialize_inner(inner)
	if getmetatable(inner) == Linq then
		return inner:ToTable()
	end
	if type(inner) == "table" then
		-- Assume array-like; copy to a dense array to avoid mutating caller data.
		local out = {}
		for i = 1, #inner do out[i] = inner[i] end
		return out
	end
	if type(inner) == "function" then
		local out = {}
		for _, v in inner do table_insert(out, v) end
		return out
	end
	return error("Join inner must be Linq, table, or iterator", 2)
end

--- GroupBy: groups into { key=..., values={...} } preserving first-seen key order.
---@param keySel fun(v: any): any
---@return linq.Linq
function Linq:GroupBy(keySel)
	local map = {}
	local order = {}
	for _, v in self:_iter() do
		local k = keySel(v)
		if map[k] == nil then
			map[k] = {}
			table_insert(order, k)
		end
		table_insert(map[k], v)
	end
	local out = {}
	for _, k in ipairs(order) do table_insert(out, { key = k, values = map[k] }) end
	return Linq_new(out)
end

--- Join: inner join two sequences
---@param inner linq.Linq|table|function Second sequence (Linq, array-like table, or iterator)
---@param outerKeySel fun(outerValue: any): any
---@param innerKeySel fun(innerValue: any): any
---@param resultSel fun(o: any, i: any): any
---@return linq.Linq
function Linq:Join(inner, outerKeySel, innerKeySel, resultSel)
	local innerSeq = materialize_inner(inner)
	local map = {}
	for _, v in ipairs(innerSeq) do
		local k = innerKeySel(v)
		map[k] = map[k] or {}
		table_insert(map[k], v)
	end
	local out = {}
	for _, v in self:_iter() do
		local k = outerKeySel(v)
		local matches = map[k] or {}
		for _, m in ipairs(matches) do table_insert(out, resultSel(v, m)) end
	end
	return Linq_new(out)
end

--- GroupJoin: correlates elements of two sequences and groups matches.<br>
--- For each element in the outer sequence, produces a result that includes the outer element and a sequence (table) of matching inner elements.
---@param inner linq.Linq|table|function Second sequence (Linq, array-like table, or iterator)
---@param outerKeySel fun(outerValue: any): any
---@param innerKeySel fun(innerValue: any): any
---@param resultSel fun(outerValue: any, innerGroup: any): any
---@return linq.Linq
function Linq:GroupJoin(inner, outerKeySel, innerKeySel, resultSel)
	local innerSeq = materialize_inner(inner)
	local map = {}
	for _, v in ipairs(innerSeq) do
		local k = innerKeySel(v)
		map[k] = map[k] or {}
		table_insert(map[k], v)
	end
	local out = {}
	for _, o in self:_iter() do
		local k = outerKeySel(o)
		local group = map[k] or {}
		table_insert(out, resultSel(o, group))
	end
	return Linq_new(out)
end

--- Distinct: unique by optional key selector
---@param keySel? fun(value: any): any
---@return linq.Linq
function Linq:Distinct(keySel)
	keySel = keySel or function(x) return x end
	local seen = {}
	local out = {}
	for _, v in self:_iter() do
		local k = keySel(v)
		if not seen[k] then
			seen[k] = true
			table_insert(out, v)
		end
	end
	return Linq_new(out)
end

--- Skip the first n elements of the sequence
---@param n number Number of elements to skip
---@return linq.Linq linq New LINQ sequence with first n elements skipped
function Linq.Skip(self, n)
	local src = self:_iter()
	local skipped = 0
	local function iter()
		while true do
			local k, v = src()
			if k == nil then return end
			skipped = skipped + 1
			if skipped > n then return k, v end
		end
	end
	return Linq_new(iter)
end

--- Take the first n elements of the sequence
---@param n number Number of elements to take
---@return linq.Linq linq New LINQ sequence containing only the first n elements
function Linq.Take(self, n)
	local src = self:_iter()
	local taken = 0
	local function iter()
		taken = taken + 1
		if taken > n then return end
		return src()
	end
	return Linq_new(iter)
end

--- Zip: combine two sequences element-wise using resultSel.<br>
--- Stops when either sequence ends.
---@param other linq.Linq|table|function Second sequence
---@param resultSel? fun(a: any, b: any, index: integer): any (default: `{a, b}`)
---@return linq.Linq
function Linq:Zip(other, resultSel)
	local aiter = self:_iter()
	local biter
	if getmetatable(other) == Linq then
		biter = other:_iter()
	elseif type(other) == "table" then
		biter = ipairs_iter(other)
	elseif type(other) == "function" then
		biter = other
	else
		return error("Zip expects Linq, table, or iterator as second argument", 2)
	end
	resultSel = resultSel or function(a, b, idx) return { a, b } end
	local idx = 0
	local function iter()
		local ka, va = aiter()
		local kb, vb = biter()
		if ka == nil or kb == nil then return end
		idx = idx + 1
		return idx, resultSel(va, vb, idx)
	end
	return Linq_new(iter)
end

--- ToDictionary: create a dictionary (table) keyed by keySel.<br>
--- If duplicate keys are encountered, behavior depends on allowOverwrite:
--- - `allowOverwrite = true`: later values overwrite earlier ones
--- - `allowOverwrite = false` (default): error on duplicate key
---@param keySel fun(value: any): any
---@param valueSel? fun(value: any): any
---@param allowOverwrite? boolean
---@return table
function Linq:ToDictionary(keySel, valueSel, allowOverwrite)
	valueSel = valueSel or function(x) return x end
	local dict = {}
	local exists = {}
	for _, v in self:_iter() do
		local k = keySel(v)
		if exists[k] and not allowOverwrite then
			return error("ToDictionary: duplicate key encountered: " .. tostring(k), 2)
		end
		dict[k] = valueSel(v)
		exists[k] = true
	end
	return dict
end

----------------------------------------------------------------------
-- Aggregations
----------------------------------------------------------------------

--- Count elements in the sequence
---@param pred? fun(v: any): boolean Optional predicate function to filter elements
---@return number count The count of elements
function Linq:Count(pred)
	local c = 0
	for _, v in self:_iter() do if not pred or pred(v) then c = c + 1 end end
	return c
end

--- Sum elements in the sequence
---@param sel? fun(v: any): number Optional selector function to transform elements before summing
---@return number sum The sum of elements
function Linq:Sum(sel)
	sel = sel or function(x) return x end
	local s = 0
	for _, v in self:_iter() do s = s + (sel(v) or 0) end
	return s
end

--- Average of elements in the sequence
---@param sel? fun(v: any): number Optional selector function to transform elements before averaging
---@return number? average The average of elements, or nil if sequence is empty
function Linq:Average(sel)
	sel = sel or function(x) return x end
	local c, s = 0, 0
	for _, v in self:_iter() do
		s, c = s + (sel(v) or 0), c + 1
	end
	if c == 0 then return end
	return s / c
end

--- Minimum element in the sequence
---@param sel? fun(v: any): any Optional selector function to transform elements before comparison
---@return any minimum The minimum element, or nil if sequence is empty
function Linq:Min(sel)
	sel = sel or function(x) return x end
	local first, m = true, nil
	for _, v in self:_iter() do
		local val = sel(v)
		if first or val < m then
			m, first = val, false
		end
	end
	return m
end

--- Maximum element in the sequence
---@param sel? fun(v: any): any Optional selector function to transform elements before comparison
---@return any maximum The maximum element, or nil if sequence is empty
function Linq:Max(sel)
	sel = sel or function(x) return x end
	local first, m = true, nil
	for _, v in self:_iter() do
		local val = sel(v)
		if first or val > m then
			first, m = false, val
		end
	end
	return m
end

--- Check if any element satisfies the predicate
---@param pred? fun(v: any): boolean Optional predicate function to test elements
---@return boolean any True if any element satisfies the predicate, false otherwise
function Linq:Any(pred)
	for _, v in self:_iter() do
		if not pred or pred(v) then return true end
	end
	return false
end

--- Check if all elements satisfy the predicate
---@param pred function Predicate function to test elements
---@return boolean all True if all elements satisfy the predicate, false otherwise
function Linq:All(pred)
	for _, v in self:_iter() do
		if not pred(v) then return false end
	end
	return true
end

--- Get the first element that satisfies the predicate
---@param pred? function Optional predicate function to filter elements
---@return any first The first matching element, or nil if no match found
function Linq:First(pred)
	for _, v in self:_iter() do
		if not pred or pred(v) then return v end
	end
end

--- Get the single element that satisfies the predicate
---@param pred? function Optional predicate function to filter elements
---@return any single The single matching element
---@error "No elements" if no elements match
---@error "More than one element" if more than one element matches
function Linq:Single(pred)
	local count, found = 0, nil
	for _, v in self:_iter() do
		if not pred or pred(v) then
			found, count = v, count + 1
		end
	end
	if count == 1 then
		return found
	end
	if count == 0 then
		return error("No elements", 2)
	end
	return error("More than one element", 2)
end

--- Aggregate: reduce with accumulator
---@param seed any Initial accumulator
---@param func fun(acc: any, value: any): any
---@return any
function Linq:Aggregate(seed, func)
	local acc = seed
	for _, v in self:_iter() do acc = func(acc, v) end
	return acc
end

-- Export
return Linq
