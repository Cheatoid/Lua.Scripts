-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for linq.lua (v1, PascalCase).
-- Run from this directory:
--   lua linq.lua
--   luajit linq.lua

-- Bootstrap: make requires work from tests/ subdir with plain lua/luajit.
do
	local src = debug.getinfo(1, "S").source
	local dir = src:match("^@(.+/)[^/]+$") or "./"
	local function isfile(p)
		local f = io.open(p, "r")
		if f then
			f:close()
			return true
		end
		return false
	end
	local root
	for _, c in ipairs({ dir, dir .. "../", dir .. "../..//", dir .. "../../..//", "./", "../", "../../" }) do
		if isfile(c .. "standalone/bits.lua") then
			root = c
			break
		end
	end
	root = root or dir .. "../"
	if package then
		package.path = dir ..
			"../?.lua;" ..
			dir ..
			"../?/init.lua;" ..
			dir ..
			"?.lua;" ..
			dir ..
			"?/init.lua;" ..
			root ..
			"?.lua;" ..
			root ..
			"?/init.lua;" ..
			root ..
			"standalone/?.lua;" ..
			root ..
			"math/?.lua;" ..
			root ..
			"collections/?.lua;" ..
			root ..
			"benchmark/?.lua;" ..
			root ..
			"timer/?.lua;" ..
			root ..
			"autocompleter/?.lua;" ..
			root ..
			"permission/?.lua;" ..
			root ..
			"chat_commander/?.lua;" ..
			root ..
			"linq/?.lua;" ..
			root .. "vm/?.lua;" .. root .. "require_finder/?.lua;" .. root .. "inventory/?.lua;" .. package.path
	end
	local searchers = package.searchers or package.loaders
	if searchers then
		table.insert(searchers, 2, function(mod)
			if mod:sub(1, 3) == "../" or mod:sub(1, 2) == "./" then
				local clean = mod:gsub("^%./", ""):gsub("^%.%.%/", ""):gsub("^%.%.%/", "")
				local tries = { dir .. "../" .. clean .. ".lua", dir .. "../" .. clean .. "/init.lua", root ..
				clean .. ".lua", root .. clean .. "/init.lua" }
				for _, f in ipairs(tries) do
					if isfile(f) then
						local chunk, err = loadfile(f)
						if chunk then return chunk, f end
					end
				end
			end
			return nil
		end)
	end
end
local lib = require "linq"
local Linq = lib

-- Helpers ---------------------------------------------------------------
local function eq_array(a, b, msg)
	assert(type(a) == "table" and type(b) == "table", (msg or "eq_array") .. " (not tables)")
	assert(#a == #b, string.format("%s (length %d vs %d)", msg or "eq_array", #a, #b))
	for i = 1, #a do
		assert(a[i] == b[i],
			string.format("%s (index %d: expected %s, got %s)", msg or "eq_array", i, tostring(b[i]), tostring(a[i])))
	end
end

local function sorted_copy(t)
	local out = {}
	for i = 1, #t do out[i] = t[i] end
	table.sort(out, function(a, b) return tostring(a) < tostring(b) end)
	return out
end

if true then
	-- Construction ------------------------------------------------------
	do
		local q = Linq.new({ 1, 2, 3 })
		eq_array(q:ToTable(), { 1, 2, 3 }, "new(table)")
		local q2 = Linq.From({ 1, 2, 3 })
		eq_array(q2:ToTable(), { 1, 2, 3 }, "From alias")
		assert(Linq.new == Linq.From, "From should alias new")
		-- Iterator source.
		local i = 0
		local function gen()
			i = i + 1
			if i <= 3 then return i, i * 10 end
		end
		eq_array(Linq.new(gen):ToTable(), { 10, 20, 30 }, "new(iterator)")
		-- ToArray alias.
		eq_array(Linq.new({ 1, 2 }):ToArray(), { 1, 2 }, "ToArray alias")
		-- Errors.
		local ok = pcall(function() Linq.new(123) end)
		assert(not ok, "new(number) should error")
		ok = pcall(function() Linq.new(nil) end)
		assert(not ok, "new(nil) should error")
		ok = pcall(function() Linq.new("x") end)
		assert(not ok, "new(string) should error")
	end

	-- README example ----------------------------------------------------
	do
		local result = Linq.From({ 1, 2, 3, 4, 5 })
			:Where(function(x) return x > 2 end)
			:Select(function(x) return x * 2 end)
			:ToTable()
		eq_array(result, { 6, 8, 10 }, "README Where+Select")
	end

	-- Where -------------------------------------------------------------
	do
		eq_array(Linq.new({ 1, 2, 3, 4 }):Where(function(v) return v % 2 == 0 end):ToTable(), { 2, 4 }, "Where evens")
		eq_array(Linq.new({ 1, 2, 3 }):Where(function(v) return v > 10 end):ToTable(), {}, "Where empty")
		eq_array(Linq.new({}):Where(function(v) return true end):ToTable(), {}, "Where on empty")
		-- Predicate receives (value, key); key is 1-based source index.
		local seen_keys = {}
		Linq.new({ 10, 20, 30 }):Where(function(v, k)
			seen_keys[#seen_keys + 1] = k
			return true
		end):ToTable()
		eq_array(seen_keys, { 1, 2, 3 }, "Where predicate keys")
		-- Chained Where stays dense (regression: ToTable used out[i]=v).
		eq_array(
			Linq.new({ 1, 2, 3, 4, 5, 6 }):Where(function(v) return v % 2 == 0 end)
			:Where(function(v) return v > 2 end):ToTable(),
			{ 4, 6 }, "Where chain dense")
	end

	-- Select ------------------------------------------------------------
	do
		eq_array(Linq.new({ 1, 2, 3 }):Select(function(v) return v * 2 end):ToTable(), { 2, 4, 6 }, "Select double")
		eq_array(Linq.new({ 1, 2 }):Select(function(v, k) return k end):ToTable(), { 1, 2 }, "Select index")
		eq_array(Linq.new({}):Select(function(v) return v end):ToTable(), {}, "Select empty")
	end

	-- SelectMany --------------------------------------------------------
	do
		eq_array(Linq.new({ { 1, 2 }, { 3, 4 } }):SelectMany(function(x) return x end):ToTable(), { 1, 2, 3, 4 },
			"SelectMany flatten")
		eq_array(Linq.new({ 1, 2, 3 }):SelectMany(function(x) return { x, x * 10 } end):ToTable(),
			{ 1, 10, 2, 20, 3, 30 }, "SelectMany project")
		eq_array(Linq.new({ { 1 }, {}, { 2, 3 } }):SelectMany(function(x) return x end):ToTable(), { 1, 2, 3 },
			"SelectMany skips empty inner")
		-- Linq inner.
		eq_array(Linq.new({ 1, 2 }):SelectMany(function(x) return Linq.new({ x, -x }) end):ToTable(),
			{ 1, -1, 2, -2 }, "SelectMany Linq inner")
		-- Iterator inner.
		eq_array(Linq.new({ 1, 2 }):SelectMany(function(x)
			local done = false
			return function()
				if not done then
					done = true
					return 1, x * 100
				end
			end
		end):ToTable(), { 100, 200 }, "SelectMany iterator inner")
	end

	-- OrderBy / ThenBy --------------------------------------------------
	do
		eq_array(Linq.new({ 3, 1, 2 }):OrderBy(function(x) return x end):ToTable(), { 1, 2, 3 }, "OrderBy asc")
		eq_array(Linq.new({ 1, 2, 3 }):OrderBy(function(x) return x end, true):ToTable(), { 3, 2, 1 },
			"OrderBy desc flag")
		eq_array(Linq.new({ 3, 1, 2 }):OrderByDescending(function(x) return x end):ToTable(), { 3, 2, 1 },
			"OrderByDescending")
		-- Stability: equal keys keep original order.
		local st = Linq.new({ { k = 1, id = "a" }, { k = 1, id = "b" }, { k = 0, id = "c" } })
			:OrderBy(function(x) return x.k end):ToTable()
		assert(st[1].id == "c" and st[2].id == "a" and st[3].id == "b", "OrderBy stable")
		-- Multi-key.
		local t = Linq.new({ { a = 1, b = 2 }, { a = 1, b = 1 }, { a = 0, b = 9 } })
			:OrderBy(function(x) return x.a end):ThenBy(function(x) return x.b end):ToTable()
		assert(t[1].b == 9 and t[2].b == 1 and t[3].b == 2, "OrderBy+ThenBy")
		local td = Linq.new({ { a = 1, b = 1 }, { a = 1, b = 2 } })
			:OrderBy(function(x) return x.a end):ThenByDescending(function(x) return x.b end):ToTable()
		assert(td[1].b == 2 and td[2].b == 1, "ThenByDescending")
		-- ThenBy on unordered behaves like OrderBy.
		eq_array(Linq.new({ 3, 1, 2 }):ThenBy(function(x) return x end):ToTable(), { 1, 2, 3 }, "ThenBy unordered")
		-- Descending first key + ascending second.
		local m = Linq.new({ { a = 1, b = 1 }, { a = 2, b = 0 }, { a = 1, b = 0 } })
			:OrderByDescending(function(x) return x.a end):ThenBy(function(x) return x.b end):ToTable()
		assert(m[1].a == 2 and m[2].b == 0 and m[3].b == 1, "OrderByDescending+ThenBy")
	end

	-- GroupBy -----------------------------------------------------------
	do
		local groups = Linq.new({ 1, 2, 3, 4 }):GroupBy(function(v) return v % 2 end):ToTable()
		assert(#groups == 2, "GroupBy count")
		-- First-seen order: key 1 (from 1) before key 0 (from 2).
		assert(groups[1].key == 1 and groups[2].key == 0, "GroupBy first-seen order")
		eq_array(sorted_copy(groups[1].values), { 1, 3 }, "GroupBy odd")
		eq_array(sorted_copy(groups[2].values), { 2, 4 }, "GroupBy even")
		eq_array(Linq.new({}):GroupBy(function(v) return v end):ToTable(), {}, "GroupBy empty")
	end

	-- Join / GroupJoin --------------------------------------------------
	do
		local outer = { { id = 1, n = "a" }, { id = 2, n = "b" } }
		local inner = { { id = 1, v = "x" }, { id = 1, v = "y" }, { id = 9, v = "z" } }
		local j = Linq.new(outer):Join(inner,
			function(o) return o.id end, function(i) return i.id end,
			function(o, i) return o.n .. i.v end):ToTable()
		eq_array(j, { "ax", "ay" }, "Join")
		eq_array(Linq.new(outer):Join({}, function(o) return o.id end, function(i) return i end,
			function(o, i) return o end):ToTable(), {}, "Join no matches")
		-- Linq inner.
		local jl = Linq.new(outer):Join(Linq.new(inner),
			function(o) return o.id end, function(i) return i.id end,
			function(o, i) return i.v end):ToTable()
		eq_array(jl, { "x", "y" }, "Join Linq inner")
		-- GroupJoin.
		local gj = Linq.new(outer):GroupJoin(inner,
			function(o) return o.id end, function(i) return i.id end,
			function(o, g) return { n = o.n, n_group = #g } end):ToTable()
		assert(#gj == 2 and gj[1].n_group == 2 and gj[2].n_group == 0, "GroupJoin counts")
	end

	-- Distinct ----------------------------------------------------------
	do
		eq_array(Linq.new({ 1, 2, 2, 3, 1 }):Distinct():ToTable(), { 1, 2, 3 }, "Distinct")
		eq_array(Linq.new({ "a", "bb", "c", "dd" }):Distinct(function(s) return #s end):ToTable(), { "a", "bb" },
			"Distinct by key")
		eq_array(Linq.new({}):Distinct():ToTable(), {}, "Distinct empty")
	end

	-- Skip / Take -------------------------------------------------------
	do
		eq_array(Linq.new({ 1, 2, 3, 4, 5 }):Skip(2):ToTable(), { 3, 4, 5 }, "Skip")
		eq_array(Linq.new({ 1, 2, 3 }):Skip(0):ToTable(), { 1, 2, 3 }, "Skip 0")
		eq_array(Linq.new({ 1, 2 }):Skip(5):ToTable(), {}, "Skip beyond")
		eq_array(Linq.new({ 1, 2, 3, 4, 5 }):Take(2):ToTable(), { 1, 2 }, "Take")
		eq_array(Linq.new({ 1, 2 }):Take(5):ToTable(), { 1, 2 }, "Take beyond")
		eq_array(Linq.new({ 1, 2, 3 }):Take(0):ToTable(), {}, "Take 0")
		-- Pagination: Skip+Take stays dense.
		eq_array(Linq.new({ 1, 2, 3, 4, 5 }):Skip(1):Take(3):ToTable(), { 2, 3, 4 }, "Skip+Take")
	end

	-- Zip ---------------------------------------------------------------
	do
		local z = Linq.new({ 1, 2, 3 }):Zip({ "a", "b" }, function(a, b) return a .. b end):ToTable()
		eq_array(z, { "1a", "2b" }, "Zip stops at shorter")
		local zd = Linq.new({ 1, 2 }):Zip({ 10, 20 }):ToTable()
		assert(#zd == 2 and zd[1][1] == 1 and zd[1][2] == 10 and zd[2][1] == 2 and zd[2][2] == 20, "Zip default")
		local zl = Linq.new({ 1, 2 }):Zip(Linq.new({ 5, 6 }), function(a, b) return a + b end):ToTable()
		eq_array(zl, { 6, 8 }, "Zip Linq")
		local ok = pcall(function() Linq.new({ 1 }):Zip(123) end)
		assert(not ok, "Zip invalid second arg should error")
	end

	-- ToDictionary ------------------------------------------------------
	do
		local d = Linq.new({ { k = "a", v = 1 }, { k = "b", v = 2 } }):ToDictionary(
			function(x) return x.k end, function(x) return x.v end)
		assert(d.a == 1 and d.b == 2, "ToDictionary")
		local d2 = Linq.new({ 1, 2 }):ToDictionary(function(x) return "k" .. x end)
		assert(d2.k1 == 1 and d2.k2 == 2, "ToDictionary identity value")
		local ok = pcall(function()
			Linq.new({ 1, 1 }):ToDictionary(function(x) return x end)
		end)
		assert(not ok, "ToDictionary duplicate should error")
		local d3 = Linq.new({ 1, 1 }):ToDictionary(function(x) return x end, nil, true)
		assert(d3[1] == 1, "ToDictionary allowOverwrite")
	end

	-- Aggregations ------------------------------------------------------
	do
		assert(Linq.new({ 1, 2, 3 }):Count() == 3, "Count")
		assert(Linq.new({ 1, 2, 3, 4 }):Count(function(v) return v % 2 == 0 end) == 2, "Count pred")
		assert(Linq.new({}):Count() == 0, "Count empty")
		assert(Linq.new({ 1, 2, 3 }):Sum() == 6, "Sum")
		assert(Linq.new({ { v = 1 }, { v = 2 } }):Sum(function(x) return x.v end) == 3, "Sum sel")
		assert(Linq.new({}):Sum() == 0, "Sum empty")
		assert(Linq.new({ 1, 2, 3 }):Average() == 2, "Average")
		assert(Linq.new({ { v = 2 }, { v = 4 } }):Average(function(x) return x.v end) == 3, "Average sel")
		assert(Linq.new({}):Average() == nil, "Average empty nil")
		assert(Linq.new({ 3, 1, 2 }):Min() == 1, "Min")
		assert(Linq.new({ 3, 1, 2 }):Max() == 3, "Max")
		assert(Linq.new({}):Min() == nil, "Min empty nil")
		assert(Linq.new({}):Max() == nil, "Max empty nil")
		assert(Linq.new({ { v = 3 }, { v = 1 } }):Min(function(x) return x.v end) == 1, "Min sel")
		assert(Linq.new({ { v = 3 }, { v = 1 } }):Max(function(x) return x.v end) == 3, "Max sel")
		assert(Linq.new({ 1, 2 }):Any() == true, "Any non-empty")
		assert(Linq.new({}):Any() == false, "Any empty")
		assert(Linq.new({ 1, 2 }):Any(function(v) return v > 1 end) == true, "Any pred true")
		assert(Linq.new({ 1, 2 }):Any(function(v) return v > 5 end) == false, "Any pred false")
		assert(Linq.new({ 2, 4 }):All(function(v) return v % 2 == 0 end) == true, "All true")
		assert(Linq.new({ 2, 3 }):All(function(v) return v % 2 == 0 end) == false, "All false")
		assert(Linq.new({}):All(function(v) return false end) == true, "All vacuous true")
		assert(Linq.new({ 1, 2, 3 }):First() == 1, "First")
		assert(Linq.new({ 1, 2, 3 }):First(function(v) return v > 1 end) == 2, "First pred")
		assert(Linq.new({}):First() == nil, "First empty nil")
		assert(Linq.new({ 1 }):Single() == 1, "Single")
		assert(Linq.new({ 1, 2, 3 }):Single(function(v) return v == 2 end) == 2, "Single pred")
		local ok, err = pcall(function() Linq.new({}):Single() end)
		assert(not ok and string.find(tostring(err), "No elements"), "Single empty error")
		ok, err = pcall(function() Linq.new({ 1, 2 }):Single() end)
		assert(not ok and string.find(tostring(err), "More than one"), "Single multiple error")
		assert(Linq.new({ 1, 2, 3 }):Aggregate(0, function(a, v) return a + v end) == 6, "Aggregate sum")
		assert(Linq.new({ "a", "b" }):Aggregate("", function(a, v) return a .. v end) == "ab", "Aggregate concat")
	end

	-- Chaining ----------------------------------------------------------
	do
		local r = Linq.new({ 5, 3, 1, 4, 2, 6 })
			:Where(function(x) return x % 2 == 0 end)
			:OrderBy(function(x) return x end)
			:Select(function(x) return x * 10 end)
			:Take(2)
			:ToTable()
		eq_array(r, { 20, 40 }, "chain Where+OrderBy+Select+Take")
	end

	-- SelectMany edge / errors -------------------------------------------
	do
		-- nil inner is skipped.
		eq_array(Linq.new({ 1, 2 }):SelectMany(function() return nil end):ToTable(), {},
			"SelectMany nil inner")
		-- Invalid inner type errors on iteration.
		local ok = pcall(function()
			Linq.new({ 1 }):SelectMany(function() return 123 end):ToTable()
		end)
		assert(not ok, "SelectMany number inner should error")
		-- Empty outer -> empty.
		eq_array(Linq.new({}):SelectMany(function(x) return { x } end):ToTable(), {},
			"SelectMany empty outer")
	end

	-- OrderBy edge cases ---------------------------------------------------
	do
		eq_array(Linq.new({}):OrderBy(function(x) return x end):ToTable(), {},
			"OrderBy empty")
		eq_array(Linq.new({ 1 }):OrderBy(function(x) return x end):ToTable(), { 1 },
			"OrderBy single")
		-- Strings.
		eq_array(Linq.new({ "b", "a", "c" }):OrderBy(function(x) return x end):ToTable(),
			{ "a", "b", "c" }, "OrderBy strings")
		-- Three-level ThenBy.
		local t = Linq.new({
				{ a = 1, b = 1, c = 2 }, { a = 1, b = 1, c = 1 }, { a = 1, b = 0, c = 9 }, { a = 0, b = 9, c = 9 },
			}):OrderBy(function(x) return x.a end)
			:ThenBy(function(x) return x.b end)
			:ThenBy(function(x) return x.c end):ToTable()
		assert(t[1].a == 0 and t[2].c == 9 and t[3].c == 1 and t[4].c == 2, "ThenBy 3-level")
		-- ThenByDescending on unordered behaves like OrderByDescending.
		eq_array(Linq.new({ 2, 3, 1 }):ThenByDescending(function(x) return x end):ToTable(),
			{ 3, 2, 1 }, "ThenByDescending unordered")
		-- Descending + descending.
		local dd = Linq.new({ { a = 1, b = 1 }, { a = 1, b = 2 }, { a = 0, b = 9 } })
			:OrderByDescending(function(x) return x.a end)
			:ThenByDescending(function(x) return x.b end):ToTable()
		assert(dd[1].b == 2 and dd[2].b == 1 and dd[3].b == 9, "OrderByDescending+ThenByDescending")
	end

	-- GroupBy strings / single group ---------------------------------------
	do
		local g = Linq.new({ "apple", "apricot", "banana" }):GroupBy(function(s) return s:sub(1, 1) end):ToTable()
		assert(#g == 2 and g[1].key == "a" and #g[1].values == 2 and g[2].key == "b",
			"GroupBy strings")
		local single = Linq.new({ 1, 2, 3 }):GroupBy(function() return "all" end):ToTable()
		assert(#single == 1 and single[1].key == "all" and #single[1].values == 3, "GroupBy single")
	end

	-- Join / GroupJoin with iterator + duplicates ---------------------------
	do
		-- Function iterator as inner.
		local function inner_iter()
			local data = { { id = 1, v = "x" }, { id = 2, v = "y" } }
			local i = 0
			return function()
				i = i + 1
				if i <= #data then return i, data[i] end
			end
		end
		local j = Linq.new({ { id = 1 }, { id = 2 }, { id = 9 } }):Join(inner_iter(),
			function(o) return o.id end, function(i) return i.id end,
			function(o, i) return i.v end):ToTable()
		eq_array(j, { "x", "y" }, "Join function inner")
		-- Invalid inner type errors.
		local ok = pcall(function()
			Linq.new({ { id = 1 } }):Join(123,
				function(o) return o.id end, function(i) return i end, function(o, i) return o end):ToTable()
		end)
		assert(not ok, "Join number inner should error")
		-- Duplicate outer keys fan out.
		local dup = Linq.new({ { id = 1 }, { id = 1 } }):Join({ { id = 1, v = "z" } },
			function(o) return o.id end, function(i) return i.id end,
			function(o, i) return i.v end):ToTable()
		eq_array(dup, { "z", "z" }, "Join duplicate outer")
		-- GroupJoin with function inner and empty inner.
		local gjf = Linq.new({ { id = 1 } }):GroupJoin(inner_iter(),
			function(o) return o.id end, function(i) return i.id end,
			function(o, g) return #g end):ToTable()
		eq_array(gjf, { 1 }, "GroupJoin function inner")
		local gje = Linq.new({ { id = 1 }, { id = 2 } }):GroupJoin({},
			function(o) return o.id end, function(i) return i end,
			function(o, g) return #g end):ToTable()
		eq_array(gje, { 0, 0 }, "GroupJoin empty inner")
		-- GroupJoin preserves group contents.
		local gjc = Linq.new({ { id = 1, n = "a" } }):GroupJoin({ { id = 1, v = 10 }, { id = 1, v = 20 } },
			function(o) return o.id end, function(i) return i.id end,
			function(o, g) return g[1].v + g[2].v end):ToTable()
		eq_array(gjc, { 30 }, "GroupJoin contents")
	end

	-- Distinct edge ----------------------------------------------------------
	do
		eq_array(Linq.new({ 1, 1, 1 }):Distinct():ToTable(), { 1 }, "Distinct all same")
		-- Distinct by key preserves first occurrence.
		local dd = Linq.new({ { id = 1, v = "a" }, { id = 1, v = "b" }, { id = 2, v = "c" } })
			:Distinct(function(x) return x.id end):ToTable()
		assert(#dd == 2 and dd[1].v == "a" and dd[2].v == "c", "Distinct first wins values")
	end

	-- Skip / Take edge --------------------------------------------------------
	do
		eq_array(Linq.new({ 1, 2, 3 }):Skip(-1):ToTable(), { 1, 2, 3 }, "Skip negative ~ Skip(0)")
		eq_array(Linq.new({ 1, 2, 3 }):Take(-1):ToTable(), {}, "Take negative empty")
		eq_array(Linq.new({}):Skip(2):ToTable(), {}, "Skip on empty")
		eq_array(Linq.new({}):Take(2):ToTable(), {}, "Take on empty")
		eq_array(Linq.new({ 1, 2, 3 }):Skip(3):ToTable(), {}, "Skip all")
		eq_array(Linq.new({ 1, 2, 3 }):Take(3):ToTable(), { 1, 2, 3 }, "Take all")
		-- Take after Where stays dense.
		eq_array(Linq.new({ 1, 2, 3, 4 }):Where(function(v) return v % 2 == 1 end):Take(1):ToTable(),
			{ 1 }, "Where+Take dense")
	end

	-- Zip edge ------------------------------------------------------------------
	do
		-- Index param.
		eq_array(Linq.new({ 10, 20 }):Zip({ 1, 2 }, function(a, b, i) return a + b + i end):ToTable(),
			{ 12, 24 }, "Zip index")
		-- Empty either side.
		assert(#Linq.new({}):Zip({ 1, 2 }):ToTable() == 0, "Zip empty outer")
		assert(#Linq.new({ 1 }):Zip({}):ToTable() == 0, "Zip empty inner")
		-- Function second arg.
		local function gen()
			local i = 0
			return function()
				i = i + 1
				if i <= 2 then return i, i * 5 end
			end
		end
		eq_array(Linq.new({ 1, 2 }):Zip(gen(), function(a, b) return a + b end):ToTable(),
			{ 6, 12 }, "Zip function inner")
		-- Default selector element shape.
		local z = Linq.new({}):Zip({}):ToTable()
		assert(#z == 0, "Zip both empty")
	end

	-- ToDictionary edge ------------------------------------------------------------
	do
		assert(next(Linq.new({}):ToDictionary(function(x) return x end)) == nil, "ToDictionary empty")
		-- allowOverwrite=false explicitly still errors.
		local ok = pcall(function()
			Linq.new({ 1, 1 }):ToDictionary(function(x) return x end, nil, false)
		end)
		assert(not ok, "ToDictionary allowOverwrite=false duplicate should error")
		-- valueSel transforms.
		local d = Linq.new({ "a", "bb" }):ToDictionary(function(x) return x end, function(x) return #x end)
		assert(d.a == 1 and d.bb == 2, "ToDictionary valueSel")
	end

	-- Aggregation edge -----------------------------------------------------------------
	do
		assert(Linq.new({ 1, 2, 3, 4 }):Count(function() return true end) == 4, "Count all true")
		assert(Linq.new({ 1, 2 }):Count(function() return false end) == 0, "Count all false")
		-- Sum with nil-returning selector treats nil as 0.
		assert(Linq.new({ { v = 1 }, { v = nil } }):Sum(function(x) return x.v end) == 1, "Sum nil sel")
		assert(Linq.new({ { v = 1 }, { v = nil } }):Average(function(x) return x.v end) == 0.5, "Average nil sel")
		-- Min/Max strings.
		assert(Linq.new({ "b", "a", "c" }):Min() == "a", "Min strings")
		assert(Linq.new({ "b", "a", "c" }):Max() == "c", "Max strings")
		-- Any on Where chain.
		assert(Linq.new({ 1, 2, 3 }):Where(function(v) return v > 5 end):Any() == false, "Any on empty Where")
		-- All with nil predicate errors (pred required).
		local ok = pcall(function() Linq.new({ 1 }):All(nil) end)
		assert(not ok, "All(nil) should error")
		-- First pred no match -> nil (not error).
		assert(Linq.new({ 1, 2 }):First(function(x) return x > 5 end) == nil, "First pred no match nil")
		assert(Linq.new({}):First(function(x) return true end) == nil, "First pred on empty nil")
		-- Single pred zero / multi.
		ok = pcall(function() Linq.new({ 1, 2 }):Single(function(x) return x > 5 end) end)
		assert(not ok, "Single pred zero should error")
		ok = pcall(function() Linq.new({ 1, 2, 3 }):Single(function(x) return x > 1 end) end)
		assert(not ok, "Single pred multi should error")
		-- Aggregate on empty returns seed.
		assert(Linq.new({}):Aggregate(42, function(a, v) return a + v end) == 42, "Aggregate empty seed")
		assert(Linq.new({ 5 }):Aggregate(10, function(a, v) return a * v end) == 50, "Aggregate single")
	end

	-- Iterator source chaining ------------------------------------------------------------
	do
		local i = 0
		local function gen()
			i = i + 1
			if i <= 5 then return i, i end
		end
		eq_array(Linq.new(gen):Where(function(v) return v % 2 == 0 end):Select(function(v) return v * 10 end):ToTable(),
			{ 20, 40 }, "iterator source chain")
		-- Count/Sum/Any on iterator source.
		local j = 0
		local function gen2()
			j = j + 1
			if j <= 3 then return j, j end
		end
		assert(Linq.new(gen2):Count() == 3, "Count iterator source")
	end

	-- Complex chains -------------------------------------------------------------------------
	do
		-- GroupBy -> Select -> OrderBy.
		local g = Linq.new({ 1, 2, 3, 4, 5, 6 }):GroupBy(function(v) return v % 2 end)
			:Select(function(grp) return { key = grp.key, n = #grp.values } end)
			:OrderBy(function(x) return x.key end):ToTable()
		assert(#g == 2 and g[1].key == 0 and g[1].n == 3 and g[2].key == 1, "GroupBy+Select+OrderBy")
		-- Join -> Where -> Select.
		local outer = { { id = 1, v = 5 }, { id = 2, v = 15 } }
		local inner = { { id = 1, m = 2 }, { id = 2, m = 3 } }
		local r = Linq.new(outer):Join(inner,
				function(o) return o.id end, function(ii) return ii.id end,
				function(o, ii) return o.v * ii.m end)
			:Where(function(x) return x > 10 end):ToTable()
		eq_array(r, { 45 }, "Join+Where")
		-- Distinct -> Skip -> Take.
		eq_array(Linq.new({ 3, 1, 2, 1, 3 }):Distinct():OrderBy(function(x) return x end):Skip(1):Take(1):ToTable(),
			{ 2 }, "Distinct+OrderBy+Skip+Take")
	end

	print("All tests passed")
end
