-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- LINQ API for Lua tables and iterables.

local error = error
local setmetatable = setmetatable
local type = type

---@class Linq
local Linq = {}
Linq.__index = Linq

--- Create a Linq query from a table or iterator.
---@param src table|function Source table or iterator function returning (index, value).
---@return Linq
local function Linq_new(src)
	local self = setmetatable({}, Linq)
	if type(src) == "table" then
		self._type = "table"; self._data = src
	elseif type(src) == "function" then
		self._type = "iter"; self._iter = src
	else
		return error("Linq.new expects table or iterator", 2)
	end
	return self
end

Linq.new = Linq_new
Linq.From = Linq_new

-- Internal helper: ipairs-style iterator for array-like tables
local function ipairs_iter(tbl)
	local i = 0
	local n = #tbl
	return function()
		i = i + 1
		if i <= n then return i, tbl[i] end
	end
end

--- Internal: get iterator over query
---@return function() -> (k, v)
function Linq:_iter()
	if self._iter then return self._iter end
	return ipairs_iter(self._data)
end

--- Materialize to array-like table
---@return table array
function Linq:ToTable()
	local out = {}
	for _, v in self:_iter() do table.insert(out, v) end
	return out
end

--- Where: filter elements by predicate
---@param pred function(value, index) -> boolean
---@return Linq
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
---@param proj function(value, index) -> any
---@return Linq
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
---@param proj function(value) -> table|iterator
---@return Linq
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
			if type(res) == "table" then inner = ipairs_iter(res) else inner = res end
		end
	end
	return Linq_new(iter)
end

--- Internal: build sortable array with key selectors applied
---@param keySelectors table list of { sel=function(v)->key, desc=boolean }
---@return table array Array of { value = v, __index = originalIndex, __keys = {key1, key2, ...} }
local function build_sort_array(values, keySelectors)
	local arr = {}
	for i = 1, #values do
		local v, keys = values[i]
		local entry = { value = v, __index = i, __keys = keys }
		for j, ks in ipairs(keySelectors) do
			table.insert(keys, ks.sel(v))
		end
		-- Store desc flags separately for comparison
		local desc = {}
		entry.__desc = desc
		for j, ks in ipairs(keySelectors) do
			table.insert(desc, ks.desc)
		end
		arr[i] = entry
	end
	return arr
end

--- Internal: lexicographic compare using precomputed keys and desc flags
---@param a table entry
---@param b table entry
---@return boolean (a < b)
local function lex_compare(a, b)
	local ak = a.__keys
	local bk = b.__keys
	local ad = a.__desc
	local len = math.max(#ak, #bk)
	for i = 1, len do
		local av = ak[i]
		local bv = bk[i]
		if av ~= bv then
			local desc_flag = ad[i] or false
			if desc_flag then
				return av > bv
			else
				return av < bv
			end
		end
	end
	-- Stable fallback by original index
	return a.__index < b.__index
end

--- OrderBy: returns a Linq whose elements are sorted by keySel (stable).<br>
-- Stores key selector functions in sort_meta so ThenBy can append selectors without recomputing earlier keys.
---@param keySel function(value) -> comparable
---@param desc boolean (optional) true for descending
---@return Linq
function Linq:OrderBy(keySel, desc)
	desc = desc == true
	local values = self:ToTable()
	local keySelectors = { { sel = keySel, desc = desc } }
	local arr = build_sort_array(values, keySelectors)
	table.sort(arr, lex_compare)
	-- Unwrap values
	local out = {}
	for i, e in ipairs(arr) do table.insert(out, e.value) end
	local q = Linq_new(out)
	-- Store key selector functions and desc flags for future ThenBy calls
	q._sort_meta = { keySelectors = keySelectors }
	return q
end

--- OrderByDescending: convenience alias for OrderBy with descending order
---@param keySel function(value) -> comparable
---@return Linq
function Linq:OrderByDescending(keySel)
	return self:OrderBy(keySel, true)
end

--- ThenBy: add a secondary (or tertiary...) ordering to a previously ordered Linq<br>
-- Uses stored key selector functions in sort_meta to perform a stable multi-key sort without recomputing earlier keys.<br>
-- If called on an unordered sequence, behaves like OrderBy.
---@param keySel function(value) -> comparable
---@param desc boolean (optional) true for descending
---@return Linq
function Linq:ThenBy(keySel, desc)
	desc = desc == true
	-- If the sequence was not produced by OrderBy, just call OrderBy on current sequence
	if not self._sort_meta or not self._sort_meta.keySelectors then
		return self:OrderBy(keySel, desc)
	end
	-- Extend keySelectors
	local keySelectors = {}
	for _, ks in ipairs(self._sort_meta.keySelectors) do
		table.insert(keySelectors, { sel = ks.sel, desc = ks.desc })
	end
	table.insert(keySelectors, { sel = keySel, desc = desc })
	-- Materialize current values and build new sort array using all selectors
	local values = self:ToTable()
	local arr = build_sort_array(values, keySelectors)
	table.sort(arr, lex_compare)
	local out = {}
	for _, e in ipairs(arr) do table.insert(out, e.value) end
	local q = Linq_new(out)
	q._sort_meta = { keySelectors = keySelectors }
	return q
end

--- ThenByDescending: convenience alias for ThenBy with descending order
---@param keySel function(value) -> comparable
---@return Linq
function Linq:ThenByDescending(keySel)
	return self:ThenBy(keySel, true)
end

--- GroupBy: groups into { key=..., values={...} }
---@param keySel function(value) -> key
---@return Linq
function Linq:GroupBy(keySel)
	local map = {}
	for _, v in self:_iter() do
		local k = keySel(v)
		map[k] = map[k] or {}
		table.insert(map[k], v)
	end
	local out = {}
	for k, vals in next, map do table.insert(out, { key = k, values = vals }) end
	return Linq_new(out)
end

--- Join: inner join two sequences
---@param inner Linq|table iterator or Linq
---@param outerKeySel function(o) -> key
---@param innerKeySel function(i) -> key
---@param resultSel function(o, i) -> any
---@return Linq
function Linq:Join(inner, outerKeySel, innerKeySel, resultSel)
	local innerSeq = (getmetatable(inner) == Linq) and inner:ToTable() or inner
	local map = {}
	for _, v in ipairs(innerSeq) do
		local k = innerKeySel(v)
		map[k] = map[k] or {}
		table.insert(map[k], v)
	end
	local out = {}
	for _, v in self:_iter() do
		local k = outerKeySel(v)
		local matches = map[k] or {}
		for _, m in ipairs(matches) do table.insert(out, resultSel(v, m)) end
	end
	return Linq_new(out)
end

--- GroupJoin: correlates elements of two sequences and groups matches<br>
-- For each element in the outer sequence, produces a result that includes the outer element<br>
-- and a sequence (table) of matching inner elements.
---@param inner Linq|table iterator or Linq
---@param outerKeySel function(o) -> key
---@param innerKeySel function(i) -> key
---@param resultSel function(o, innerGroup) -> any
---@return Linq
function Linq:GroupJoin(inner, outerKeySel, innerKeySel, resultSel)
	local innerSeq = (getmetatable(inner) == Linq) and inner:ToTable() or inner
	local map = {}
	for _, v in ipairs(innerSeq) do
		local k = innerKeySel(v)
		map[k] = map[k] or {}
		table.insert(map[k], v)
	end
	local out = {}
	for _, o in self:_iter() do
		local k = outerKeySel(o)
		local group = map[k] or {}
		table.insert(out, resultSel(o, group))
	end
	return Linq_new(out)
end

--- Distinct: unique by optional key selector
---@param keySel function(value) -> key (optional)
---@return Linq
function Linq:Distinct(keySel)
	keySel = keySel or function(x) return x end
	local seen = {}
	local out = {}
	for _, v in self:_iter() do
		local k = keySel(v)
		if not seen[k] then
			seen[k] = true; table.insert(out, v)
		end
	end
	return Linq_new(out)
end

--- Skip the first n elements of the sequence
---@param n number Number of elements to skip
---@return Linq linq New LINQ sequence with first n elements skipped
function Linq:Skip(n)
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
---@return Linq linq New LINQ sequence containing only the first n elements
function Linq:Take(n)
	local src = self:_iter()
	local taken = 0
	local function iter()
		taken = taken + 1
		if taken > n then return end
		return src()
	end
	return Linq_new(iter)
end

--- Zip: combine two sequences element-wise using resultSel<br>
-- Stops when either sequence ends.
---@param other Linq|table|function second sequence
---@param resultSel function(a, b, index) -> any (optional). Default returns {a, b}
---@return Linq
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

--- ToDictionary: create a dictionary (table) keyed by keySel<br>
--- If duplicate keys are encountered, behavior depends on allowOverwrite:<br>
--- - `allowOverwrite = true`: later values overwrite earlier ones
--- - `allowOverwrite = false` (default): error on duplicate key
---@param keySel function(value) -> key
---@param valueSel function(value) -> value (optional)
---@param allowOverwrite boolean (optional)
---@return table
function Linq:ToDictionary(keySel, valueSel, allowOverwrite)
	valueSel = valueSel or function(x) return x end
	local dict = {}
	for _, v in self:_iter() do
		local k = keySel(v)
		if dict[k] ~= nil and not allowOverwrite then
			return error("ToDictionary: duplicate key encountered: " .. tostring(k), 2)
		end
		dict[k] = valueSel(v)
	end
	return dict
end

----------------------------------------------------------------------
-- Aggregations
----------------------------------------------------------------------

--- Count elements in the sequence
---@param pred function|nil Optional predicate function to filter elements
---@return number The count of elements
function Linq:Count(pred)
	local c = 0
	for _, v in self:_iter() do if not pred or pred(v) then c = c + 1 end end
	return c
end

--- Sum elements in the sequence
---@param sel function|nil Optional selector function to transform elements before summing
---@return number The sum of elements
function Linq:Sum(sel)
	sel = sel or function(x) return x end
	local s = 0
	for _, v in self:_iter() do s = s + (sel(v) or 0) end
	return s
end

--- Average of elements in the sequence
---@param sel function|nil Optional selector function to transform elements before averaging
---@return number|nil The average of elements, or nil if sequence is empty
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
---@param sel function|nil Optional selector function to transform elements before comparison
---@return any The minimum element, or nil if sequence is empty
function Linq:Min(sel)
	sel = sel or function(x) return x end
	local first, m = true
	for _, v in self:_iter() do
		local val = sel(v)
		if first or val < m then
			m, first = val, false
		end
	end
	return m
end

--- Maximum element in the sequence
---@param sel function|nil Optional selector function to transform elements before comparison
---@return any The maximum element, or nil if sequence is empty
function Linq:Max(sel)
	sel = sel or function(x) return x end
	local first, m = true
	for _, v in self:_iter() do
		local val = sel(v)
		if first or val > m then
			first, m = false, val
		end
	end
	return m
end

--- Check if any element satisfies the predicate
---@param pred function|nil Optional predicate function to test elements
---@return boolean True if any element satisfies the predicate, false otherwise
function Linq:Any(pred)
	for _, v in self:_iter() do
		if not pred or pred(v) then return true end
	end
	return false
end

--- Check if all elements satisfy the predicate
---@param pred function Predicate function to test elements
---@return boolean True if all elements satisfy the predicate, false otherwise
function Linq:All(pred)
	for _, v in self:_iter() do
		if not pred(v) then return false end
	end
	return true
end

--- Get the first element that satisfies the predicate
---@param pred function|nil Optional predicate function to filter elements
---@return any|nil The first matching element, or nil if no match found
function Linq:First(pred)
	for _, v in self:_iter() do
		if not pred or pred(v) then return v end
	end
end

--- Get the single element that satisfies the predicate
---@param pred function|nil Optional predicate function to filter elements
---@return any The single matching element
---@error "No elements" if no elements match
---@error "More than one element" if more than one element matches
function Linq:Single(pred)
	local count, found = 0
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
---@param seed any initial accumulator
---@param func function(acc, value) -> acc
---@return any
function Linq:Aggregate(seed, func)
	local acc = seed
	for _, v in self:_iter() do acc = func(acc, v) end
	return acc
end

--- ToTable alias
Linq.ToArray = Linq.ToTable

return Linq
