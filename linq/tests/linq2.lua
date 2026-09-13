-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for linq2.lua (v2, PascalCase, coroutine-backed).
-- Run from this directory:
--   lua linq2.lua
--   luajit linq2.lua

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
local lib = require "linq2"
local Linq = lib

local function eq_array(a, b, msg)
	assert(type(a) == "table" and type(b) == "table", (msg or "eq_array") .. " (not tables)")
	assert(#a == #b, string.format("%s (length %d vs %d)", msg or "eq_array", #a, #b))
	for i = 1, #a do
		assert(a[i] == b[i],
			string.format("%s (index %d: expected %s, got %s)", msg or "eq_array", i, tostring(b[i]), tostring(a[i])))
	end
end

if true then
	-- Construction ------------------------------------------------------
	do
		eq_array(Linq.new({ 1, 2, 3 }):ToTable(), { 1, 2, 3 }, "new(table)")
		eq_array(Linq.new(nil):ToTable(), {}, "new(nil) empty")
		eq_array(Linq.new():ToTable(), {}, "new() empty")
		eq_array(Linq({ 1, 2 }):ToTable(), { 1, 2 }, "__call constructor")
		eq_array(Linq.Empty():ToTable(), {}, "Empty")
		eq_array(Linq.Range(1, 3):ToTable(), { 1, 2, 3 }, "Range")
		eq_array(Linq.Range(5, 0):ToTable(), {}, "Range zero count")
		eq_array(Linq.Repeat("x", 3):ToTable(), { "x", "x", "x" }, "Repeat")
		eq_array(Linq.Repeat("x", 0):ToTable(), {}, "Repeat zero")
		local ok = pcall(function() Linq.new(123) end)
		assert(not ok, "new(number) should error")
		ok = pcall(function() Linq.Range(1, -1) end)
		assert(not ok, "Range negative should error")
		ok = pcall(function() Linq.Repeat("x", -1) end)
		assert(not ok, "Repeat negative should error")
		-- ToTable returns a copy: mutating it must not affect the query.
		local e = Linq.new({ 1, 2, 3 })
		local t = e:ToTable()
		t[1] = 99
		eq_array(e:ToTable(), { 1, 2, 3 }, "ToTable copy semantics")
		eq_array(e:ToList(), { 1, 2, 3 }, "ToList")
		eq_array(e:ToArray(), { 1, 2, 3 }, "ToArray")
	end

	-- README example ----------------------------------------------------
	do
		local result = Linq({ 1, 2, 3, 4, 5 })
			:Where(function(x) return x > 2 end)
			:Select(function(x) return x * 2 end)
			:ToArray()
		eq_array(result, { 6, 8, 10 }, "README Where+Select")
	end

	-- iter ----------------------------------------------------------------
	do
		local it = Linq.new({ 1, 2, 3 }):iter()
		assert(it() == 1 and it() == 2 and it() == 3 and it() == nil, "iter sequence")
		eq_array(Linq.new({}):iter()() == nil and {} or Linq.new({}):ToTable(), {}, "iter empty")
	end

	-- Where / Select / SelectMany ----------------------------------------
	do
		eq_array(Linq.new({ 1, 2, 3, 4 }):Where(function(x) return x % 2 == 0 end):ToTable(), { 2, 4 }, "Where")
		local ok = pcall(function() Linq.new({ 1 }):Where("not-fn") end)
		assert(not ok, "Where non-function should error")
		eq_array(Linq.new({ 1, 2, 3 }):Select(function(x) return x * 2 end):ToTable(), { 2, 4, 6 }, "Select")
		ok = pcall(function() Linq.new({ 1 }):Select(nil) end)
		assert(not ok, "Select non-function should error")
		-- SelectMany without resultSelector flattens.
		eq_array(Linq.new({ { 1, 2 }, { 3 } }):SelectMany(function(x) return x end):ToTable(), { 1, 2, 3 },
			"SelectMany flatten")
		-- SelectMany with resultSelector.
		eq_array(
			Linq.new({ { v = 1 }, { v = 2 } }):SelectMany(function(x) return { 10, 20 } end,
				function(outer, inner) return outer.v + inner end):ToTable(),
			{ 11, 21, 12, 22 }, "SelectMany resultSelector")
		ok = pcall(function() Linq.new({ 1 }):SelectMany("x") end)
		assert(not ok, "SelectMany non-function should error")
	end

	-- Ordering ------------------------------------------------------------
	do
		eq_array(Linq.new({ 3, 1, 2 }):OrderBy(function(x) return x end):ToTable(), { 1, 2, 3 }, "OrderBy")
		eq_array(Linq.new({ 1, 2, 3 }):OrderByDescending(function(x) return x end):ToTable(), { 3, 2, 1 },
			"OrderByDescending")
		-- OrderedEnumerable still exposes base methods (regression: inherited from Linq).
		local ordered = Linq.new({ 3, 1, 2 }):OrderBy(function(x) return x end)
		assert(ordered.ToTable ~= nil and ordered.ToArray ~= nil and ordered.Where ~= nil,
			"OrderedEnumerable inherits Enumerable")
		eq_array(ordered:Where(function(x) return x > 1 end):ToTable(), { 2, 3 }, "Ordered Where chain")
		-- ThenBy multi-key.
		local t = Linq.new({ { a = 1, b = 2 }, { a = 1, b = 1 }, { a = 0, b = 9 } })
			:OrderBy(function(x) return x.a end):ThenBy(function(x) return x.b end):ToTable()
		assert(t[1].b == 9 and t[2].b == 1 and t[3].b == 2, "ThenBy")
		local td = Linq.new({ { a = 1, b = 1 }, { a = 1, b = 2 } })
			:OrderBy(function(x) return x.a end):ThenByDescending(function(x) return x.b end):ToTable()
		assert(td[1].b == 2 and td[2].b == 1, "ThenByDescending")
		-- Custom comparer.
		eq_array(
			Linq.new({ "a", "ccc", "bb" }):OrderBy(function(x) return x end, function(a, b) return #a < #b end)
			:ToTable(),
			{ "a", "bb", "ccc" }, "OrderBy comparer")
		local ok = pcall(function() Linq.new({ 1 }):OrderBy("x") end)
		assert(not ok, "OrderBy non-function should error")
		-- Reverse does not mutate source.
		local r = Linq.new({ 1, 2, 3 })
		eq_array(r:Reverse():ToTable(), { 3, 2, 1 }, "Reverse")
		eq_array(r:ToTable(), { 1, 2, 3 }, "Reverse no mutate")
	end

	-- Partitioning ---------------------------------------------------------
	do
		eq_array(Linq.new({ 1, 2, 3, 4, 5 }):Take(2):ToTable(), { 1, 2 }, "Take")
		eq_array(Linq.new({ 1, 2, 3, 4, 5 }):Skip(2):ToTable(), { 3, 4, 5 }, "Skip")
		eq_array(Linq.new({ 1, 2 }):Skip(5):ToTable(), {}, "Skip beyond")
		-- Skip is lazy: creating it must not consume the source.
		local src = Linq.new({ 1, 2, 3 })
		local skipped = src:Skip(1)
		eq_array(src:ToTable(), { 1, 2, 3 }, "Skip lazy (source intact)")
		eq_array(skipped:ToTable(), { 2, 3 }, "Skip result")
		eq_array(Linq.new({ 1, 2, 3, 1 }):TakeWhile(function(x) return x < 3 end):ToTable(), { 1, 2 },
			"TakeWhile")
		eq_array(Linq.new({ 1, 2, 3, 1 }):SkipWhile(function(x) return x < 3 end):ToTable(), { 3, 1 },
			"SkipWhile")
		local ok = pcall(function() Linq.new({ 1 }):TakeWhile(nil) end)
		assert(not ok, "TakeWhile non-function should error")
	end

	-- Set operations -------------------------------------------------------
	do
		eq_array(Linq.new({ 1, 2, 2, 3 }):Distinct():ToTable(), { 1, 2, 3 }, "Distinct")
		eq_array(
			Linq.new({ "a", "A", "b" }):Distinct(function(a, b) return string.lower(a) == string.lower(b) end)
			:ToTable(),
			{ "a", "b" }, "Distinct comparer")
		eq_array(Linq.new({ 1, 2 }):Union({ 2, 3 }):ToTable(), { 1, 2, 3 }, "Union")
		eq_array(Linq.new({ 1, 2, 3 }):Intersect({ 2, 3, 4 }):ToTable(), { 2, 3 }, "Intersect")
		eq_array(Linq.new({ 1, 2, 3 }):Except({ 2 }):ToTable(), { 1, 3 }, "Except")
		local ok = pcall(function() Linq.new({ 1 }):Union(nil) end)
		assert(not ok, "Union nil should error")
	end

	-- Join / GroupBy / Lookup ----------------------------------------------
	do
		local outer = { { id = 1, n = "a" }, { id = 2, n = "b" } }
		local inner = { { id = 1, v = "x" }, { id = 1, v = "y" } }
		eq_array(Linq.new(outer):Join(inner,
			function(o) return o.id end, function(i) return i.id end,
			function(o, i) return o.n .. i.v end):ToTable(), { "ax", "ay" }, "Join")
		local groups = Linq.new({ 1, 2, 3, 4 }):GroupBy(function(x) return x % 2 end):ToTable()
		assert(#groups == 2, "GroupBy count")
		-- elementSelector + resultSelector.
		local gr = Linq.new({ 1, 2, 3, 4 }):GroupBy(
			function(x) return x % 2 end, function(x) return x * 10 end,
			function(k, g) return { key = k, sum = g:Sum() } end):ToTable()
		assert(#gr == 2, "GroupBy resultSelector count")
		local lookup = Linq.new({ 1, 2, 3, 4 }):ToLookup(function(x) return x % 2 end)
		assert(#lookup[1] == 2 and #lookup[0] == 2, "ToLookup")
		local dict = Linq.new({ { k = "a", v = 1 } }):ToDictionary(
			function(x) return x.k end, function(x) return x.v end)
		assert(dict.a == 1, "ToDictionary")
		local ok = pcall(function()
			Linq.new({ 1, 1 }):ToDictionary(function(x) return x end)
		end)
		assert(not ok, "ToDictionary duplicate should error")
	end

	-- Element operators ----------------------------------------------------
	do
		assert(Linq.new({ 1, 2, 3 }):First() == 1, "First")
		assert(Linq.new({ 1, 2, 3 }):First(function(x) return x > 1 end) == 2, "First pred")
		assert(Linq.new({}):FirstOrDefault("d") == "d", "FirstOrDefault empty")
		assert(Linq.new({ 1 }):FirstOrDefault("d") == 1, "FirstOrDefault found")
		local ok = pcall(function() Linq.new({}):First() end)
		assert(not ok, "First empty should error")
		assert(Linq.new({ 1, 2, 3 }):Last() == 3, "Last")
		assert(Linq.new({ 1, 2, 3 }):Last(function(x) return x < 3 end) == 2, "Last pred")
		assert(Linq.new({}):LastOrDefault("d") == "d", "LastOrDefault")
		assert(Linq.new({ 1, 2, 3 }):ElementAt(2) == 2, "ElementAt")
		assert(Linq.new({ 1 }):ElementAtOrDefault(5, "d") == "d", "ElementAtOrDefault")
		ok = pcall(function() Linq.new({ 1 }):ElementAt(5) end)
		assert(not ok, "ElementAt OOR should error")
		assert(Linq.new({ 5 }):Single() == 5, "Single")
		assert(Linq.new({}):SingleOrDefault("d") == "d", "SingleOrDefault empty")
		assert(Linq.new({ 5 }):SingleOrDefault("d") == 5, "SingleOrDefault one")
		ok = pcall(function() Linq.new({ 1, 2 }):Single() end)
		assert(not ok, "Single multiple should error")
		ok = pcall(function() Linq.new({ 1, 2 }):SingleOrDefault("d") end)
		assert(not ok, "SingleOrDefault multiple should error")
	end

	-- Quantifiers ----------------------------------------------------------
	do
		assert(Linq.new({ 1 }):Any() == true, "Any non-empty")
		assert(Linq.new({}):Any() == false, "Any empty")
		assert(Linq.new({ 1, 2 }):Any(function(x) return x > 1 end) == true, "Any pred")
		assert(Linq.new({ 2, 4 }):All(function(x) return x % 2 == 0 end) == true, "All true")
		assert(Linq.new({ 2, 3 }):All(function(x) return x % 2 == 0 end) == false, "All false")
		assert(Linq.new({ 1, 2 }):Contains(2) == true, "Contains")
		assert(Linq.new({ 1, 2 }):Contains(9) == false, "Contains missing")
	end

	-- Aggregation ----------------------------------------------------------
	do
		assert(Linq.new({ 1, 2, 3 }):Sum() == 6, "Sum")
		assert(Linq.new({ 1, 2, 3 }):Count() == 3, "Count")
		assert(Linq.new({ 1, 2, 3, 4 }):Count(function(x) return x % 2 == 0 end) == 2, "Count pred")
		assert(Linq.new({ 1, 2, 3 }):Average() == 2, "Average")
		assert(Linq.new({ 3, 1, 2 }):Max() == 3, "Max")
		assert(Linq.new({ 3, 1, 2 }):Min() == 1, "Min")
		assert(Linq.new({}):Max() == nil, "Max empty nil")
		assert(Linq.new({ 1, 2, 3 }):Aggregate(10, function(a, v) return a + v end) == 16, "Aggregate")
		local ok = pcall(function() Linq.new({ 1, "x" }):Sum() end)
		assert(not ok, "Sum non-numeric should error")
		ok = pcall(function() Linq.new({}):Average() end)
		assert(not ok, "Average empty should error")
	end

	-- Conversion -----------------------------------------------------------
	do
		-- Concat does not mutate either input.
		local a = Linq.new({ 1, 2 })
		local c = a:Concat({ 3, 4 })
		eq_array(c:ToTable(), { 1, 2, 3, 4 }, "Concat")
		eq_array(a:ToTable(), { 1, 2 }, "Concat no mutate")
		eq_array(Linq.new({ 1, 2 }):Zip({ 10, 20 }, function(x, y) return x + y end):ToTable(), { 11, 22 }, "Zip")
		local ok = pcall(function() Linq.new({ 1 }):Zip({ 1 }) end)
		assert(not ok, "Zip without selector should error")
		eq_array(Linq.new({}):DefaultIfEmpty(7):ToTable(), { 7 }, "DefaultIfEmpty empty")
		eq_array(Linq.new({ 1 }):DefaultIfEmpty(7):ToTable(), { 1 }, "DefaultIfEmpty non-empty")
		assert(Linq.new({ 1, 2, 3 }):ToString(",") == "1,2,3", "ToString")
		assert(Linq.new({ 1, 2 }):ToString("-", function(x) return "n" .. x end) == "n1-n2", "ToString selector")
	end

	-- Where/Select index + SelectMany Enumerable/edge -------------------------
	do
		local widx = {}
		Linq.new({ 10, 20, 30 }):Where(function(v, i)
			widx[#widx + 1] = i
			return true
		end):ToTable()
		eq_array(widx, { 1, 2, 3 }, "Where index")
		eq_array(Linq.new({ 10, 20 }):Select(function(v, i) return i end):ToTable(), { 1, 2 },
			"Select index")
		-- SelectMany with Enumerable inner (regression: was treated as empty).
		eq_array(Linq.new({ 1, 2 }):SelectMany(function(x) return Linq.new({ x, x * 10 }) end):ToTable(),
			{ 1, 10, 2, 20 }, "SelectMany Enumerable inner")
		-- SelectMany empty inner / empty outer.
		eq_array(Linq.new({ 1, 2 }):SelectMany(function() return {} end):ToTable(), {},
			"SelectMany empty inner")
		eq_array(Linq.new({}):SelectMany(function(x) return { x } end):ToTable(), {},
			"SelectMany empty outer")
		-- SelectMany non-table inner errors on iteration.
		local ok = pcall(function()
			Linq.new({ 1 }):SelectMany(function() return 123 end):ToTable()
		end)
		assert(not ok, "SelectMany number inner should error")
	end

	-- Ordering edge: comparers, 3-level, stability, empty -----------------------
	do
		-- ThenBy/ThenByDescending with custom comparer (length).
		local bylen = function(a, b) return #a < #b end
		local tb = Linq.new({ { a = 1, s = "ccc" }, { a = 1, s = "a" }, { a = 0, s = "zzzz" } })
			:OrderBy(function(x) return x.a end):ThenBy(function(x) return x.s end, bylen):ToTable()
		assert(tb[1].s == "zzzz" and tb[2].s == "a" and tb[3].s == "ccc", "ThenBy comparer")
		eq_array(
			Linq.new({ "a", "ccc", "bb" }):OrderByDescending(function(x) return x end, function(a, b) return #a < #b end)
			:ToTable(),
			{ "ccc", "bb", "a" }, "OrderByDescending comparer")
		-- Three-level chain.
		local t3 = Linq.new({
				{ a = 1, b = 1, c = 2 }, { a = 1, b = 1, c = 1 }, { a = 1, b = 0, c = 9 }, { a = 0, b = 9, c = 9 },
			}):OrderBy(function(x) return x.a end):ThenBy(function(x) return x.b end):ThenBy(function(x) return x.c end)
			:ToTable()
		assert(t3[1].a == 0 and t3[2].c == 9 and t3[3].c == 1 and t3[4].c == 2, "ThenBy 3-level")
		-- Stability on equal keys.
		local st = Linq.new({ { k = 1, id = "a" }, { k = 1, id = "b" }, { k = 0, id = "c" } })
			:OrderBy(function(x) return x.k end):ToTable()
		assert(st[1].id == "c" and st[2].id == "a" and st[3].id == "b", "OrderBy stable")
		-- Empty / single.
		eq_array(Linq.new({}):OrderBy(function(x) return x end):ToTable(), {}, "OrderBy empty")
		eq_array(Linq.new({ 1 }):OrderByDescending(function(x) return x end):ToTable(), { 1 },
			"OrderByDescending single")
		-- Reverse empty / single.
		eq_array(Linq.new({}):Reverse():ToTable(), {}, "Reverse empty")
		eq_array(Linq.new({ 1 }):Reverse():ToTable(), { 1 }, "Reverse single")
	end

	-- Partitioning edge ------------------------------------------------------------
	do
		eq_array(Linq.new({ 1, 2, 3 }):Take(0):ToTable(), {}, "Take 0")
		eq_array(Linq.new({ 1, 2, 3 }):Skip(0):ToTable(), { 1, 2, 3 }, "Skip 0")
		eq_array(Linq.new({ 1, 2 }):Take(5):ToTable(), { 1, 2 }, "Take beyond")
		eq_array(Linq.new({}):Take(2):ToTable(), {}, "Take on empty")
		eq_array(Linq.new({}):Skip(2):ToTable(), {}, "Skip on empty")
		eq_array(Linq.new({ 1, 2, 3 }):TakeWhile(function() return true end):ToTable(), { 1, 2, 3 },
			"TakeWhile all")
		eq_array(Linq.new({ 1, 2, 3 }):TakeWhile(function() return false end):ToTable(), {},
			"TakeWhile none")
		eq_array(Linq.new({ 1, 2, 3 }):SkipWhile(function() return true end):ToTable(), {},
			"SkipWhile all")
		eq_array(Linq.new({ 1, 2, 3 }):SkipWhile(function() return false end):ToTable(), { 1, 2, 3 },
			"SkipWhile none")
		eq_array(Linq.new({}):TakeWhile(function() return true end):ToTable(), {}, "TakeWhile empty")
		eq_array(Linq.new({}):SkipWhile(function() return true end):ToTable(), {}, "SkipWhile empty")
		local ok = pcall(function() Linq.new({ 1 }):SkipWhile(nil) end)
		assert(not ok, "SkipWhile non-function should error")
	end

	-- Set ops with Enumerable second + comparer + empty ------------------------------
	do
		eq_array(Linq.new({ 1, 2 }):Union(Linq.new({ 2, 3 })):ToTable(), { 1, 2, 3 },
			"Union Enumerable second")
		eq_array(Linq.new({ 1, 2, 3 }):Intersect(Linq.new({ 2, 3 })):ToTable(), { 2, 3 },
			"Intersect Enumerable second")
		eq_array(Linq.new({ 1, 2, 3 }):Except(Linq.new({ 2 })):ToTable(), { 1, 3 },
			"Except Enumerable second")
		eq_array(Linq.new({}):Union({ 1 }):ToTable(), { 1 }, "Union empty first")
		eq_array(Linq.new({ 1 }):Union({}):ToTable(), { 1 }, "Union empty second")
		eq_array(Linq.new({}):Intersect({ 1 }):ToTable(), {}, "Intersect empty first")
		eq_array(Linq.new({ 1 }):Except({}):ToTable(), { 1 }, "Except empty second")
		-- Comparer (case-insensitive).
		local ci = function(a, b) return string.lower(a) == string.lower(b) end
		eq_array(Linq.new({ "a", "b" }):Union({ "A", "c" }, ci):ToTable(), { "a", "b", "c" },
			"Union comparer")
		eq_array(Linq.new({ "a", "b" }):Intersect({ "A" }, ci):ToTable(), { "a" },
			"Intersect comparer")
		eq_array(Linq.new({ "a", "b" }):Except({ "A" }, ci):ToTable(), { "b" },
			"Except comparer")
		local ok = pcall(function() Linq.new({ 1 }):Intersect(nil) end)
		assert(not ok, "Intersect nil should error")
		ok = pcall(function() Linq.new({ 1 }):Except(nil) end)
		assert(not ok, "Except nil should error")
	end

	-- Join / GroupBy / Lookup edge ------------------------------------------------------
	do
		local outer = { { id = 1, n = "a" }, { id = 2, n = "b" } }
		-- Join empty inner / empty outer.
		eq_array(Linq.new(outer):Join({}, function(o) return o.id end, function(i) return i end,
			function(o, i) return o end):ToTable(), {}, "Join empty inner")
		eq_array(Linq.new({}):Join({ { id = 1 } }, function(o) return o end, function(i) return i.id end,
			function(o, i) return o end):ToTable(), {}, "Join empty outer")
		-- Join error cases.
		local ok = pcall(function()
			Linq.new(outer):Join(nil, function(o) return o.id end, function(i) return i end,
				function(o, i) return o end):ToTable()
		end)
		assert(not ok, "Join nil inner should error")
		ok = pcall(function()
			Linq.new(outer):Join({}, "not-fn", function(i) return i end, function(o, i) return o end):ToTable()
		end)
		assert(not ok, "Join non-function outerKeySel should error")
		-- GroupBy default shape: values is Enumerable.
		local g = Linq.new({ 1, 2, 3, 4 }):GroupBy(function(x) return x % 2 end):ToTable()
		assert(#g == 2, "GroupBy default count")
		for _, grp in ipairs(g) do
			assert(grp.key ~= nil and grp.values ~= nil and type(grp.values.ToTable) == "function",
				"GroupBy default values is Enumerable")
		end
		-- GroupBy elementSelector only.
		local ge = Linq.new({ 1, 2, 3, 4 }):GroupBy(
			function(x) return x % 2 end, function(x) return x * 10 end):ToTable()
		assert(#ge == 2, "GroupBy elementSelector count")
		-- GroupBy empty.
		eq_array(Linq.new({}):GroupBy(function(x) return x end):ToTable(), {}, "GroupBy empty")
		local ok2 = pcall(function() Linq.new({ 1 }):GroupBy("x") end)
		assert(not ok2, "GroupBy non-function should error")
		-- ToLookup with elementSelector + empty.
		local lk = Linq.new({ { k = "a", v = 1 }, { k = "a", v = 2 } })
			:ToLookup(function(x) return x.k end, function(x) return x.v end)
		eq_array(lk["a"], { 1, 2 }, "ToLookup elementSelector")
		assert(next(Linq.new({}):ToLookup(function(x) return x end)) == nil, "ToLookup empty")
		-- ToDictionary only-key + empty.
		local dk = Linq.new({ 1, 2 }):ToDictionary(function(x) return "k" .. x end)
		assert(dk.k1 == 1 and dk.k2 == 2, "ToDictionary key-only")
		assert(next(Linq.new({}):ToDictionary(function(x) return x end)) == nil, "ToDictionary empty")
	end

	-- Element ops edge ---------------------------------------------------------------------
	do
		-- FirstOrDefault / LastOrDefault with predicate.
		assert(Linq.new({ 1, 2, 3 }):FirstOrDefault("d", function(x) return x > 1 end) == 2,
			"FirstOrDefault pred found")
		assert(Linq.new({ 1, 2 }):FirstOrDefault("d", function(x) return x > 5 end) == "d",
			"FirstOrDefault pred missing")
		assert(Linq.new({ 1, 2, 3 }):LastOrDefault("d", function(x) return x < 3 end) == 2,
			"LastOrDefault pred")
		assert(Linq.new({ 1 }):LastOrDefault("d", function(x) return x > 5 end) == "d",
			"LastOrDefault pred missing")
		local ok = pcall(function() Linq.new({ 1, 2 }):Last(function(x) return x > 5 end) end)
		assert(not ok, "Last pred no match should error")
		-- ElementAt valid default path + 0/negative.
		assert(Linq.new({ 1, 2, 3 }):ElementAtOrDefault(2, "d") == 2, "ElementAtOrDefault found")
		assert(Linq.new({ 1 }):ElementAtOrDefault(0, "d") == "d", "ElementAtOrDefault 0")
		ok = pcall(function() Linq.new({ 1 }):ElementAt(0) end)
		assert(not ok, "ElementAt 0 should error")
		ok = pcall(function() Linq.new({ 1 }):ElementAt(-1) end)
		assert(not ok, "ElementAt negative should error")
		-- Single with predicate variants.
		assert(Linq.new({ 1, 2, 3 }):Single(function(x) return x == 2 end) == 2, "Single pred")
		ok = pcall(function() Linq.new({ 1, 2 }):Single(function(x) return x > 5 end) end)
		assert(not ok, "Single pred zero should error")
		ok = pcall(function() Linq.new({ 1, 2, 3 }):Single(function(x) return x > 1 end) end)
		assert(not ok, "Single pred multi should error")
		assert(Linq.new({ 1, 2, 3 }):SingleOrDefault("d", function(x) return x == 2 end) == 2,
			"SingleOrDefault pred found")
		assert(Linq.new({ 1 }):SingleOrDefault("d", function(x) return x > 5 end) == "d",
			"SingleOrDefault pred zero")
	end

	-- Quantifiers + Contains comparer + Aggregation edge ---------------------------------------
	do
		assert(Linq.new({}):Any(function(x) return true end) == false, "Any pred on empty")
		assert(Linq.new({}):All(function(x) return false end) == true, "All on empty vacuous")
		local ok = pcall(function() Linq.new({ 1 }):All(nil) end)
		assert(not ok, "All(nil) should error")
		assert(
			Linq.new({ "a", "B" }):Contains("b", function(a, b) return string.lower(a) == string.lower(b) end) == true,
			"Contains comparer")
		assert(Linq.new({}):Contains(1) == false, "Contains on empty")
		-- Sum/Average/Min/Max with selector + empty.
		assert(Linq.new({ { v = 1 }, { v = 2 } }):Sum(function(x) return x.v end) == 3, "Sum selector")
		assert(Linq.new({}):Sum() == 0, "Sum empty")
		assert(Linq.new({ { v = 2 }, { v = 4 } }):Average(function(x) return x.v end) == 3, "Average selector")
		assert(Linq.new({ { v = 3 }, { v = 1 } }):Min(function(x) return x.v end) == 1, "Min selector")
		assert(Linq.new({ { v = 3 }, { v = 1 } }):Max(function(x) return x.v end) == 3, "Max selector")
		assert(Linq.new({}):Count(function() return true end) == 0, "Count pred on empty")
		assert(Linq.new({ "b", "a" }):Min() == "a", "Min strings")
		ok = pcall(function() Linq.new({ 1 }):Aggregate(nil, nil) end)
		assert(not ok, "Aggregate nil func should error")
	end

	-- Conversion edge: Concat/Zip/ToString/DefaultIfEmpty/iter ------------------------------------
	do
		eq_array(Linq.new({ 1, 2 }):Concat(Linq.new({ 3, 4 })):ToTable(), { 1, 2, 3, 4 },
			"Concat Enumerable second")
		eq_array(Linq.new({}):Concat({ 1 }):ToTable(), { 1 }, "Concat empty first")
		eq_array(Linq.new({ 1 }):Concat({}):ToTable(), { 1 }, "Concat empty second")
		eq_array(Linq.new({ 1, 2 }):Zip(Linq.new({ 10, 20 }), function(a, b) return a + b end):ToTable(),
			{ 11, 22 }, "Zip Enumerable second")
		eq_array(Linq.new({}):Zip({ 1 }, function(a, b) return a end):ToTable(), {}, "Zip empty first")
		eq_array(Linq.new({ 1 }):Zip({}, function(a, b) return a end):ToTable(), {}, "Zip empty second")
		assert(Linq.new({}):ToString(",") == "", "ToString empty")
		assert(Linq.new({ 1, 2 }):ToString() == "1, 2", "ToString default delimiter")
		-- iter on lazy query materializes.
		local it = Linq.new({ 1, 2, 3, 4 }):Where(function(x) return x % 2 == 0 end):iter()
		assert(it() == 2 and it() == 4 and it() == nil, "iter on Where")
		-- Range / Repeat / Empty edge + chaining.
		eq_array(Linq.Range(5, 1):ToTable(), { 5 }, "Range single")
		eq_array(Linq.Range(-2, 3):ToTable(), { -2, -1, 0 }, "Range negative start")
		eq_array(Linq.Empty():Where(function() return true end):ToTable(), {}, "Empty chain")
		eq_array(Linq.Range(1, 3):Where(function(x) return x > 1 end):ToTable(), { 2, 3 }, "Range chain")
	end

	-- Complex chains -------------------------------------------------------------------------------
	do
		-- Where -> OrderBy -> Take -> Select -> Sum.
		local s = Linq.new({ 5, 3, 1, 4, 2, 6 }):Where(function(x) return x % 2 == 0 end)
			:OrderBy(function(x) return x end):Take(2):Select(function(x) return x * 10 end):Sum()
		assert(s == 60, "chain Where+OrderBy+Take+Select+Sum")
		-- Concat -> Distinct -> OrderBy.
		eq_array(Linq.new({ 1, 2 }):Concat({ 2, 3 }):Distinct():OrderBy(function(x) return x end):ToTable(),
			{ 1, 2, 3 }, "chain Concat+Distinct+OrderBy")
		-- GroupBy -> ToLookup consistency.
		local lk = Linq.new({ 1, 2, 3, 4 }):ToLookup(function(x) return x % 2 end)
		assert(#lk[0] == 2 and #lk[1] == 2, "ToLookup counts")
	end

	print("All tests passed")
end
