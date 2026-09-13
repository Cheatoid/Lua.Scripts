-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for linq3.lua (v3, camelCase, factory-backed / re-iterable).
-- Run from this directory:
--   lua linq3.lua
--   luajit linq3.lua

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
local lib = require "linq3"
local Enumerable = lib

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
		eq_array(Enumerable.from({ 1, 2, 3 }):toTable(), { 1, 2, 3 }, "from(table)")
		eq_array(Enumerable.empty():toTable(), {}, "empty")
		eq_array(Enumerable.of(1, 2, 3):toTable(), { 1, 2, 3 }, "of")
		eq_array(Enumerable.of():toTable(), {}, "of empty")
		eq_array(Enumerable.range(1, 3):toTable(), { 1, 2, 3 }, "range")
		eq_array(Enumerable.range(5, 0):toTable(), {}, "range zero")
		eq_array(Enumerable.range(1, 3, 2):toTable(), { 1, 3, 5 }, "range step")
		eq_array(Enumerable.repeatValue("x", 3):toTable(), { "x", "x", "x" }, "repeatValue")
		-- from(Enumerable) shares the factory (re-iterable).
		local e = Enumerable.from({ 1, 2 })
		eq_array(Enumerable.from(e):toTable(), { 1, 2 }, "from(Enumerable)")
		-- from(factory).
		eq_array(Enumerable.from(function()
			local i = 0
			return function()
				i = i + 1
				if i <= 2 then return i * 10 end
			end
		end):toTable(), { 10, 20 }, "from(factory)")
		local ok = pcall(function() Enumerable.from(123) end)
		assert(not ok, "from(number) should error")
	end

	-- README example ----------------------------------------------------
	do
		local result = Enumerable.from({ 1, 2, 3, 4, 5 })
			:where(function(x) return x > 2 end)
			:select(function(x) return x * 2 end)
			:toTable()
		eq_array(result, { 6, 8, 10 }, "README where+select")
	end

	-- Re-iterable (factory) ----------------------------------------------
	do
		local q = Enumerable.from({ 1, 2, 3, 4 }):where(function(x) return x % 2 == 0 end)
		eq_array(q:toTable(), { 2, 4 }, "re-iter first")
		eq_array(q:toTable(), { 2, 4 }, "re-iter second (factory, not single-use)")
	end

	-- Core iteration ------------------------------------------------------
	do
		local it = Enumerable.from({ 1, 2, 3 }):iter()
		assert(it() == 1 and it() == 2 and it() == 3 and it() == nil, "iter")
		local acc = {}
		Enumerable.from({ 1, 2 }):forEach(function(v, i) acc[i] = v * 2 end)
		eq_array(acc, { 2, 4 }, "forEach")
	end

	-- Projection / filtering ----------------------------------------------
	do
		eq_array(Enumerable.from({ 1, 2, 3, 4 }):where(function(x) return x % 2 == 0 end):toTable(), { 2, 4 }, "where")
		eq_array(Enumerable.from({ 1, 2, 3 }):select(function(x) return x * 2 end):toTable(), { 2, 4, 6 }, "select")
		-- where/select indices are sequential.
		local idxs = {}
		Enumerable.from({ 10, 20, 30 }):select(function(v, i)
			idxs[#idxs + 1] = i
			return v
		end):toTable()
		eq_array(idxs, { 1, 2, 3 }, "select index")
		eq_array(Enumerable.from({ { 1, 2 }, { 3 } }):selectMany(function(x) return x end):toTable(), { 1, 2, 3 },
			"selectMany")
		eq_array(Enumerable.from({ 1, 2 }):selectMany(function(x) return Enumerable.of(x, -x) end):toTable(),
			{ 1, -1, 2, -2 }, "selectMany Enumerable")
		eq_array(Enumerable.from({ 1, 2, 3, 4, 5 }):skip(2):toTable(), { 3, 4, 5 }, "skip")
		eq_array(Enumerable.from({ 1, 2, 3 }):take(2):toTable(), { 1, 2 }, "take")
		eq_array(Enumerable.from({ 1, 2 }):take(5):toTable(), { 1, 2 }, "take beyond")
		eq_array(Enumerable.from({ 1, 2, 3 }):append(4):toTable(), { 1, 2, 3, 4 }, "append")
		eq_array(Enumerable.from({ 2, 3 }):prepend(1):toTable(), { 1, 2, 3 }, "prepend")
		eq_array(Enumerable.from({ 1, 2 }):concat({ 3, 4 }):toTable(), { 1, 2, 3, 4 }, "concat")
		eq_array(Enumerable.from({ 1, 2 }):concat(Enumerable.of(3, 4)):toTable(), { 1, 2, 3, 4 }, "concat Enumerable")
		eq_array(Enumerable.from({ 1, 2, 3 }):reverse():toTable(), { 3, 2, 1 }, "reverse")
		-- reverse does not mutate source.
		local src = Enumerable.from({ 1, 2, 3 })
		src:reverse():toTable()
		eq_array(src:toTable(), { 1, 2, 3 }, "reverse no mutate")
	end

	-- Quantifiers / elements ------------------------------------------------
	do
		assert(Enumerable.from({ 1, 2, 3 }):count() == 3, "count")
		assert(Enumerable.from({ 1, 2, 3, 4 }):count(function(x) return x % 2 == 0 end) == 2, "count pred")
		assert(Enumerable.from({ 1 }):any() == true, "any")
		assert(Enumerable.from({}):any() == false, "any empty")
		assert(Enumerable.from({ 1, 2 }):any(function(x) return x > 1 end) == true, "any pred")
		assert(Enumerable.from({ 2, 4 }):all(function(x) return x % 2 == 0 end) == true, "all")
		assert(Enumerable.from({ 2, 3 }):all(function(x) return x % 2 == 0 end) == false, "all false")
		assert(Enumerable.from({ 1, 2, 3 }):first() == 1, "first")
		assert(Enumerable.from({ 1, 2, 3 }):first(function(x) return x > 1 end) == 2, "first pred")
		assert(Enumerable.from({}):firstOrDefault("d") == "d", "firstOrDefault empty")
		assert(Enumerable.from({ 1 }):firstOrDefault("d") == 1, "firstOrDefault")
		local ok = pcall(function() Enumerable.from({}):first() end)
		assert(not ok, "first empty should error")
		assert(Enumerable.from({ 1, 2, 3 }):last() == 3, "last")
		assert(Enumerable.from({}):lastOrDefault("d") == "d", "lastOrDefault")
		assert(Enumerable.from({ 5 }):single() == 5, "single")
		assert(Enumerable.from({}):singleOrDefault("d") == "d", "singleOrDefault empty")
		ok = pcall(function() Enumerable.from({ 1, 2 }):single() end)
		assert(not ok, "single multiple should error")
		ok = pcall(function() Enumerable.from({ 1, 2 }):singleOrDefault("d") end)
		assert(not ok, "singleOrDefault multiple should error")
		assert(Enumerable.from({ 1, 2 }):contains(2) == true, "contains")
		assert(Enumerable.from({ 1, 2 }):contains(9) == false, "contains missing")
		assert(
			Enumerable.from({ "a", "B" }):contains("b", function(a, b) return string.lower(a) == string.lower(b) end) ==
			true,
			"contains comparer")
	end

	-- Aggregation ------------------------------------------------------------
	do
		assert(Enumerable.from({ 1, 2, 3 }):sum() == 6, "sum")
		assert(Enumerable.from({ { v = 1 }, { v = 2 } }):sum(function(x) return x.v end) == 3, "sum sel")
		assert(Enumerable.from({ 1, 2, 3 }):average() == 2, "average")
		local ok = pcall(function() Enumerable.from({}):average() end)
		assert(not ok, "average empty should error")
		assert(Enumerable.from({ 3, 1, 2 }):min() == 1, "min")
		assert(Enumerable.from({ 3, 1, 2 }):max() == 3, "max")
		assert(Enumerable.from({ { v = 1 }, { v = 5 } }):min(function(x) return x.v end) == 1, "min sel")
		assert(Enumerable.from({ { v = 1 }, { v = 5 } }):max(function(x) return x.v end) == 5, "max sel")
		ok = pcall(function() Enumerable.from({}):min() end)
		assert(not ok, "min empty should error")
		-- aggregate overloads.
		assert(Enumerable.from({ 1, 2, 3 }):aggregate(10, function(a, v) return a + v end) == 16, "aggregate seed")
		assert(Enumerable.from({ 1, 2, 3 }):aggregate(function(a, v) return a + v end) == 6, "aggregate no seed")
		assert(
			Enumerable.from({ 1, 2 }):aggregate(0, function(a, v) return a + v end, function(r) return r * 2 end) == 6,
			"aggregate resultSelector")
	end

	-- Materialization ---------------------------------------------------------
	do
		eq_array(Enumerable.from({ 1, 2 }):toTable(), { 1, 2 }, "toTable")
		local d = Enumerable.from({ { k = "a", v = 1 } }):toDictionary(
			function(x) return x.k end, function(x) return x.v end)
		assert(d.a == 1, "toDictionary")
		local ok = pcall(function()
			Enumerable.from({ 1, 1 }):toDictionary(function(x) return x end)
		end)
		assert(not ok, "toDictionary duplicate should error")
	end

	-- Distinct / sets -----------------------------------------------------------
	do
		eq_array(Enumerable.from({ 1, 2, 2, 3 }):distinct():toTable(), { 1, 2, 3 }, "distinct")
		eq_array(Enumerable.from({ "a", "bb", "c" }):distinct(function(x) return #x end):toTable(), { "a", "bb" },
			"distinct key")
		eq_array(Enumerable.from({ 1, 2 }):union({ 2, 3 }):toTable(), { 1, 2, 3 }, "union")
		eq_array(Enumerable.from({ 1, 2, 3 }):intersect({ 2, 3, 4 }):toTable(), { 2, 3 }, "intersect")
		eq_array(Enumerable.from({ 1, 2, 3 }):except({ 2 }):toTable(), { 1, 3 }, "except")
	end

	-- Grouping --------------------------------------------------------------------
	do
		local groups = Enumerable.from({ 1, 2, 3, 4 }):groupBy(function(x) return x % 2 end):toTable()
		assert(#groups == 2, "groupBy count")
		assert(groups[1].key == 1 and groups[2].key == 0, "groupBy first-seen order")
		eq_array(groups[1].values, { 1, 3 }, "groupBy values")
		local lookup = Enumerable.from({ 1, 2, 3, 4 }):toLookup(function(x) return x % 2 end)
		assert(#lookup[1] == 2 and #lookup[0] == 2, "toLookup")
	end

	-- Ordering ----------------------------------------------------------------------
	do
		eq_array(Enumerable.from({ 3, 1, 2 }):orderBy():toTable(), { 1, 2, 3 }, "orderBy identity")
		eq_array(Enumerable.from({ 3, 1, 2 }):orderBy(function(x) return x end):toTable(), { 1, 2, 3 }, "orderBy")
		eq_array(Enumerable.from({ 1, 2, 3 }):orderByDescending(function(x) return x end):toTable(), { 3, 2, 1 },
			"orderByDescending")
		local t = Enumerable.from({ { a = 1, b = 2 }, { a = 1, b = 1 }, { a = 0, b = 9 } })
			:orderBy(function(x) return x.a end):thenBy(function(x) return x.b end):toTable()
		assert(t[1].b == 9 and t[2].b == 1 and t[3].b == 2, "thenBy")
		local td = Enumerable.from({ { a = 1, b = 1 }, { a = 1, b = 2 } })
			:orderBy(function(x) return x.a end):thenByDescending(function(x) return x.b end):toTable()
		assert(td[1].b == 2, "thenByDescending")
		-- thenBy does not mutate the original ordered query.
		local base = Enumerable.from({ { a = 1, b = 2 }, { a = 1, b = 1 } }):orderBy(function(x) return x.a end)
		local extended = base:thenBy(function(x) return x.b end)
		eq_array(base:toTable()[1] and { base:toTable()[1].b, base:toTable()[2].b } or {}, { 2, 1 },
			"thenBy no mutate base")
		eq_array({ extended:toTable()[1].b, extended:toTable()[2].b }, { 1, 2 }, "thenBy extended")
	end

	-- Joins ---------------------------------------------------------------------------
	do
		local outer = { { id = 1, n = "a" }, { id = 2, n = "b" } }
		local inner = { { id = 1, v = "x" }, { id = 1, v = "y" } }
		eq_array(Enumerable.from(outer):join(inner,
			function(o) return o.id end, function(i) return i.id end,
			function(o, i) return o.n .. i.v end):toTable(), { "ax", "ay" }, "join")
		-- Empty outer terminates (regression: infinite loop).
		eq_array(Enumerable.from({}):join(inner,
			function(o) return o end, function(i) return i.id end,
			function(o, i) return o end):toTable(), {}, "join empty outer")
		-- No matches -> empty (also exercises termination).
		eq_array(Enumerable.from({ { id = 9 } }):join(inner,
			function(o) return o.id end, function(i) return i.id end,
			function(o, i) return o end):toTable(), {}, "join no matches")
		-- groupJoin.
		local gj = Enumerable.from(outer):groupJoin(inner,
			function(o) return o.id end, function(i) return i.id end,
			function(o, g) return { n = o.n, c = g:count() } end):toTable()
		assert(#gj == 2 and gj[1].c == 2 and gj[2].c == 0, "groupJoin")
	end

	-- Construction edge ------------------------------------------------------------
	do
		local ok = pcall(function() Enumerable.from(nil) end)
		assert(not ok, "from(nil) should error")
		ok = pcall(function() Enumerable.from("x") end)
		assert(not ok, "from(string) should error")
		-- empty chaining stays empty.
		eq_array(Enumerable.empty():where(function() return true end):toTable(), {}, "empty+where")
		eq_array(Enumerable.empty():select(function(x) return x end):toTable(), {}, "empty+select")
		eq_array(Enumerable.empty():orderBy():toTable(), {}, "empty+orderBy")
		-- of single / of empty already covered; of multiple.
		eq_array(Enumerable.of(42):toTable(), { 42 }, "of single")
		-- range edge: negative step, zero step, zero count, negative start.
		eq_array(Enumerable.range(5, 3, -1):toTable(), { 5, 4, 3 }, "range negative step")
		eq_array(Enumerable.range(1, 3, 0):toTable(), { 1, 1, 1 }, "range zero step")
		eq_array(Enumerable.range(-2, 3):toTable(), { -2, -1, 0 }, "range negative start")
		eq_array(Enumerable.range(1, 0):toTable(), {}, "range zero count")
		-- repeatValue edge.
		eq_array(Enumerable.repeatValue("x", 0):toTable(), {}, "repeatValue zero")
		eq_array(Enumerable.repeatValue("y", 1):toTable(), { "y" }, "repeatValue single")
		-- range/repeat chaining.
		eq_array(Enumerable.range(1, 5):where(function(x) return x % 2 == 0 end):toTable(), { 2, 4 },
			"range chain")
	end

	-- forEach / iter edge ---------------------------------------------------------------
	do
		-- forEach on empty calls nothing.
		local n = 0
		Enumerable.from({}):forEach(function() n = n + 1 end)
		assert(n == 0, "forEach empty")
		-- forEach index.
		local idxs = {}
		Enumerable.from({ 10, 20 }):forEach(function(v, i) idxs[#idxs + 1] = i end)
		eq_array(idxs, { 1, 2 }, "forEach index")
		local ok = pcall(function() Enumerable.from({ 1 }):forEach(nil) end)
		assert(not ok, "forEach(nil) should error")
		ok = pcall(function() Enumerable.from({ 1 }):where(nil) end)
		assert(not ok, "where(nil) should error")
		ok = pcall(function() Enumerable.from({ 1 }):select(nil) end)
		assert(not ok, "select(nil) should error")
	end

	-- Projection edge: where/select index, selectMany factory/empty --------------------------
	do
		local widx = {}
		Enumerable.from({ 10, 20, 30 }):where(function(v, i)
			widx[#widx + 1] = i
			return true
		end):toTable()
		eq_array(widx, { 1, 2, 3 }, "where index")
		-- selectMany with factory-function inner.
		eq_array(Enumerable.from({ 1, 2 }):selectMany(function(x)
			return function()
				local i = 0
				return function()
					i = i + 1
					if i == 1 then return x * 10 end
				end
			end
		end):toTable(), { 10, 20 }, "selectMany factory inner")
		-- selectMany empty outer / empty inner.
		eq_array(Enumerable.from({}):selectMany(function(x) return { x } end):toTable(), {},
			"selectMany empty outer")
		eq_array(Enumerable.from({ 1, 2 }):selectMany(function() return {} end):toTable(), {},
			"selectMany empty inner")
		-- skip/take edge.
		eq_array(Enumerable.from({ 1, 2, 3 }):skip(0):toTable(), { 1, 2, 3 }, "skip 0")
		eq_array(Enumerable.from({ 1, 2, 3 }):take(0):toTable(), {}, "take 0")
		eq_array(Enumerable.from({ 1, 2 }):skip(5):toTable(), {}, "skip beyond")
		eq_array(Enumerable.from({}):skip(1):toTable(), {}, "skip on empty")
		eq_array(Enumerable.from({}):take(1):toTable(), {}, "take on empty")
		-- append/prepend chain + empty.
		eq_array(Enumerable.from({}):append(1):toTable(), { 1 }, "append to empty")
		eq_array(Enumerable.from({}):prepend(1):toTable(), { 1 }, "prepend to empty")
		eq_array(Enumerable.from({ 1 }):append(2):prepend(0):toTable(), { 0, 1, 2 },
			"append+prepend chain")
		-- concat edge: empty both, factory second.
		eq_array(Enumerable.from({}):concat({}):toTable(), {}, "concat both empty")
		eq_array(Enumerable.from({ 1 }):concat({}):toTable(), { 1 }, "concat empty second")
		eq_array(Enumerable.from({}):concat({ 1 }):toTable(), { 1 }, "concat empty first")
		eq_array(Enumerable.from({ 1, 2 }):concat(function()
			local i = 0
			return function()
				i = i + 1
				if i <= 2 then return i + 10 end
			end
		end):toTable(), { 1, 2, 11, 12 }, "concat factory second")
		-- reverse edge: empty / single / double.
		eq_array(Enumerable.from({}):reverse():toTable(), {}, "reverse empty")
		eq_array(Enumerable.from({ 1 }):reverse():toTable(), { 1 }, "reverse single")
		eq_array(Enumerable.from({ 1, 2, 3 }):reverse():reverse():toTable(), { 1, 2, 3 },
			"double reverse")
	end

	-- Quantifiers / elements edge ---------------------------------------------------------------
	do
		assert(Enumerable.from({}):count() == 0, "count empty")
		assert(Enumerable.from({}):count(function() return true end) == 0, "count pred empty")
		assert(Enumerable.from({}):all(function() return false end) == true, "all vacuous empty")
		assert(Enumerable.from({}):any(function() return true end) == false, "any pred empty")
		local ok = pcall(function() Enumerable.from({ 1 }):all(nil) end)
		assert(not ok, "all(nil) should error")
		-- first/last/single with predicate variants.
		assert(Enumerable.from({ 1, 2, 3 }):firstOrDefault("d", function(x) return x > 1 end) == 2,
			"firstOrDefault pred found")
		assert(Enumerable.from({ 1, 2 }):firstOrDefault("d", function(x) return x > 5 end) == "d",
			"firstOrDefault pred missing")
		assert(Enumerable.from({ 1, 2, 3 }):last(function(x) return x < 3 end) == 2, "last pred")
		assert(Enumerable.from({ 1, 2, 3 }):lastOrDefault("d", function(x) return x < 3 end) == 2,
			"lastOrDefault pred found")
		assert(Enumerable.from({ 1 }):lastOrDefault("d", function(x) return x > 5 end) == "d",
			"lastOrDefault pred missing")
		ok = pcall(function() Enumerable.from({ 1, 2 }):last(function(x) return x > 5 end) end)
		assert(not ok, "last pred no match should error")
		assert(Enumerable.from({ 1, 2, 3 }):single(function(x) return x == 2 end) == 2, "single pred")
		assert(Enumerable.from({ 1, 2, 3 }):singleOrDefault("d", function(x) return x == 2 end) == 2,
			"singleOrDefault pred found")
		assert(Enumerable.from({ 1 }):singleOrDefault("d", function(x) return x > 5 end) == "d",
			"singleOrDefault pred zero")
		ok = pcall(function() Enumerable.from({}):single() end)
		assert(not ok, "single empty should error")
		assert(Enumerable.from({}):contains(1) == false, "contains on empty")
		assert(Enumerable.from({ 1, 1, 2 }):contains(1) == true, "contains duplicate")
	end

	-- Aggregation edge ---------------------------------------------------------------------------------
	do
		assert(Enumerable.from({}):sum() == 0, "sum empty")
		assert(Enumerable.from({ { v = 1 }, { v = 2 } }):sum(function(x, i) return x.v end) == 3,
			"sum selector")
		assert(Enumerable.from({ { v = 2 }, { v = 4 } }):average(function(x) return x.v end) == 3,
			"average selector")
		local ok = pcall(function() Enumerable.from({}):max() end)
		assert(not ok, "max empty should error")
		assert(Enumerable.from({ "b", "a" }):min() == "a", "min strings")
		assert(Enumerable.from({ "b", "a" }):max() == "b", "max strings")
		-- aggregate overloads on empty.
		assert(Enumerable.from({}):aggregate(42, function(a, v) return a + v end) == 42,
			"aggregate seed on empty")
		ok = pcall(function() Enumerable.from({}):aggregate(function(a, v) return a + v end) end)
		assert(not ok, "aggregate no-seed on empty should error")
		-- aggregate with index? selector receives index; verify sum via aggregate.
		assert(Enumerable.from({ 1, 2, 3 }):aggregate(0, function(a, v) return a + v end,
			function(r) return r * 2 end) == 12, "aggregate seed+resultSelector")
	end

	-- Materialization edge ----------------------------------------------------------------------------------
	do
		eq_array(Enumerable.from({}):toTable(), {}, "toTable empty")
		local d = Enumerable.from({ "a", "bb" }):toDictionary(
			function(x) return x end, function(x) return #x end)
		assert(d.a == 1 and d.bb == 2, "toDictionary valueSelector")
		local dk = Enumerable.from({ 1, 2 }):toDictionary(function(x) return "k" .. x end)
		assert(dk.k1 == 1, "toDictionary key-only")
		assert(next(Enumerable.from({}):toDictionary(function(x) return x end)) == nil,
			"toDictionary empty")
	end

	-- Distinct / sets edge ---------------------------------------------------------------------------------------
	do
		eq_array(Enumerable.from({}):distinct():toTable(), {}, "distinct empty")
		eq_array(Enumerable.from({ 1, 1, 1 }):distinct():toTable(), { 1 }, "distinct all same")
		eq_array(Enumerable.from({}):union({ 1 }):toTable(), { 1 }, "union empty first")
		eq_array(Enumerable.from({ 1 }):union({}):toTable(), { 1 }, "union empty second")
		eq_array(Enumerable.from({}):intersect({ 1 }):toTable(), {}, "intersect empty first")
		eq_array(Enumerable.from({ 1 }):except({}):toTable(), { 1 }, "except empty second")
		eq_array(Enumerable.from({ 1 }):except({ 1 }):toTable(), {}, "except all removed")
		-- keySelector variants.
		eq_array(Enumerable.from({ "a", "A", "b" }):union({ "c" }, function(x) return string.lower(x) end):toTable(),
			{ "a", "b", "c" }, "union keySelector")
		eq_array(Enumerable.from({ 1, 2, 3 }):intersect(Enumerable.of(2, 3)):toTable(), { 2, 3 },
			"intersect Enumerable second")
		eq_array(Enumerable.from({ 1, 2, 3 }):except(function()
			local i = 0
			return function()
				i = i + 1
				if i == 1 then return 2 end
			end
		end):toTable(), { 1, 3 }, "except factory second")
	end

	-- Grouping edge -------------------------------------------------------------------------------------------------
	do
		eq_array(Enumerable.from({}):groupBy(function(x) return x end):toTable(), {},
			"groupBy empty")
		local single = Enumerable.from({ 1, 2, 3 }):groupBy(function() return "all" end):toTable()
		assert(#single == 1 and single[1].key == "all" and #single[1].values == 3, "groupBy single")
		-- elementSelector.
		local ge = Enumerable.from({ 1, 2, 3, 4 })
			:groupBy(function(x) return x % 2 end, function(x) return x * 10 end):toTable()
		assert(#ge == 2, "groupBy elementSelector count")
		-- groupBy index param.
		local gidx = Enumerable.from({ 10, 20 }):groupBy(function(v, i) return i end):toTable()
		assert(#gidx == 2 and gidx[1].key == 1 and gidx[2].key == 2, "groupBy index")
		-- toLookup with elementSelector + empty.
		local lk = Enumerable.from({ { k = "a", v = 1 }, { k = "a", v = 2 } })
			:toLookup(function(x) return x.k end, function(x) return x.v end)
		eq_array(lk["a"], { 1, 2 }, "toLookup elementSelector")
		assert(next(Enumerable.from({}):toLookup(function(x) return x end)) == nil, "toLookup empty")
	end

	-- Ordering edge ------------------------------------------------------------------------------------------------------
	do
		eq_array(Enumerable.from({}):orderBy():toTable(), {}, "orderBy empty")
		eq_array(Enumerable.from({ 1 }):orderByDescending():toTable(), { 1 }, "orderByDescending single")
		eq_array(Enumerable.from({ "b", "a", "c" }):orderBy(function(x) return x end):toTable(),
			{ "a", "b", "c" }, "orderBy strings")
		-- Stability.
		local st = Enumerable.from({ { k = 1, id = "a" }, { k = 1, id = "b" }, { k = 0, id = "c" } })
			:orderBy(function(x) return x.k end):toTable()
		assert(st[1].id == "c" and st[2].id == "a" and st[3].id == "b", "orderBy stable")
		-- Three-level thenBy.
		local t3 = Enumerable.from({
				{ a = 1, b = 1, c = 2 }, { a = 1, b = 1, c = 1 }, { a = 1, b = 0, c = 9 }, { a = 0, b = 9, c = 9 },
			}):orderBy(function(x) return x.a end):thenBy(function(x) return x.b end):thenBy(function(x) return x.c end)
			:toTable()
		assert(t3[1].a == 0 and t3[2].c == 9 and t3[3].c == 1 and t3[4].c == 2, "thenBy 3-level")
	end

	-- Joins edge: empty inner, Enumerable/factory inner, duplicates -----------------------------------------------
	do
		local outer = { { id = 1, n = "a" } }
		-- Empty inner -> empty.
		eq_array(Enumerable.from(outer):join({},
			function(o) return o.id end, function(i) return i end,
			function(o, i) return o end):toTable(), {}, "join empty inner")
		-- Enumerable inner.
		eq_array(Enumerable.from(outer):join(Enumerable.of({ id = 1, v = "z" }),
			function(o) return o.id end, function(i) return i.id end,
			function(o, i) return i.v end):toTable(), { "z" }, "join Enumerable inner")
		-- Factory inner.
		eq_array(Enumerable.from(outer):join(function()
				local done = false
				return function()
					if not done then
						done = true
						return { id = 1, v = "f" }
					end
				end
			end,
			function(o) return o.id end, function(i) return i.id end,
			function(o, i) return i.v end):toTable(), { "f" }, "join factory inner")
		-- Duplicate outer fan-out.
		eq_array(Enumerable.from({ { id = 1 }, { id = 1 } }):join({ { id = 1, v = "z" } },
			function(o) return o.id end, function(i) return i.id end,
			function(o, i) return i.v end):toTable(), { "z", "z" }, "join duplicate outer")
		-- groupJoin empty outer / empty inner.
		eq_array(Enumerable.from({}):groupJoin({ { id = 1 } },
			function(o) return o end, function(i) return i.id end,
			function(o, g) return o end):toTable(), {}, "groupJoin empty outer")
		local gje = Enumerable.from(outer):groupJoin({},
			function(o) return o.id end, function(i) return i end,
			function(o, g) return g:count() end):toTable()
		eq_array(gje, { 0 }, "groupJoin empty inner")
		-- groupJoin Enumerable inner preserves contents.
		local gjc = Enumerable.from(outer):groupJoin(Enumerable.of({ id = 1, v = 10 }, { id = 1, v = 20 }),
			function(o) return o.id end, function(i) return i.id end,
			function(o, g) return g:sum(function(x) return x.v end) end):toTable()
		eq_array(gjc, { 30 }, "groupJoin Enumerable contents")
	end

	-- Metamethods + complex chains ----------------------------------------------------------------------------------------------
	do
		assert(tostring(Enumerable.from({ 1 })) == "Enumerable", "__tostring Enumerable")
		assert(tostring(Enumerable.from({ 1 }):orderBy()) == "Enumerable", "__tostring Ordered")
		-- where+orderBy+select+take.
		eq_array(Enumerable.from({ 5, 3, 1, 4, 2, 6 }):where(function(x) return x % 2 == 0 end)
			:orderBy(function(x) return x end):select(function(x) return x * 10 end):take(2):toTable(),
			{ 20, 40 }, "chain where+orderBy+select+take")
		-- groupBy+select+orderBy.
		local g = Enumerable.from({ 1, 2, 3, 4, 5, 6 }):groupBy(function(v) return v % 2 end)
			:select(function(grp) return { key = grp.key, n = #grp.values } end)
			:orderBy(function(x) return x.key end):toTable()
		assert(#g == 2 and g[1].key == 0 and g[1].n == 3, "chain groupBy+select+orderBy")
		-- concat+distinct+orderBy.
		eq_array(Enumerable.from({ 1, 2 }):concat({ 2, 3 }):distinct():orderBy():toTable(),
			{ 1, 2, 3 }, "chain concat+distinct+orderBy")
		-- join+where.
		local jw = Enumerable.from({ { id = 1, v = 5 }, { id = 2, v = 15 } })
			:join({ { id = 1, m = 2 }, { id = 2, m = 3 } },
				function(o) return o.id end, function(i) return i.id end,
				function(o, i) return o.v * i.m end)
			:where(function(x) return x > 10 end):toTable()
		eq_array(jw, { 45 }, "chain join+where")
	end

	print("All tests passed")
end
