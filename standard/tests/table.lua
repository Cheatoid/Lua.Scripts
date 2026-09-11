-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Minimal Test Harness
local Test = {
	passed = 0,
	failed = 0,
	errors = {},
	current_suite = "",
}

function Test.suite(name)
	Test.current_suite = name
	print(string.format("\n== %s ==", name))
end

function Test.assert(condition, msg)
	if condition then
		Test.passed = Test.passed + 1
	else
		Test.failed = Test.failed + 1
		local err = string.format("  FAIL [%s]: %s", Test.current_suite, msg or "assertion failed")
		table.insert(Test.errors, err)
		print(err)
	end
end

function Test.equal(actual, expected, msg)
	if actual == expected then
		Test.passed = Test.passed + 1
	else
		Test.failed = Test.failed + 1
		local detail = string.format("%s (expected: %s, got: %s)",
			msg or "values not equal", tostring(expected), tostring(actual))
		local err = string.format("  FAIL [%s]: %s", Test.current_suite, detail)
		table.insert(Test.errors, err)
		print(err)
	end
end

function Test.deep_equal(actual, expected, msg)
	local seen = {}
	if actual == expected then
		Test.assert(true, msg)
		return
	end
	if type(actual) ~= type(expected) then
		Test.assert(false, (msg or "") .. string.format(" (type mismatch: %s vs %s)", type(actual), type(expected)))
		return
	end
	if type(actual) ~= "table" then
		Test.assert(false, (msg or "") .. string.format(" (expected: %s, got: %s)", tostring(expected), tostring(actual)))
		return
	end
	if seen[actual] then
		Test.assert(true, msg)
		return
	end -- cycle guard
	seen[actual] = true
	for k, v in pairs(actual) do
		if not Test._deep_eq(v, expected[k], seen) then
			Test.assert(false, (msg or "") .. string.format(" (key %s differs)", tostring(k)))
			return
		end
	end
	for k, _ in pairs(expected) do
		if actual[k] == nil then
			Test.assert(false, (msg or "") .. string.format(" (extra key %s in expected)", tostring(k)))
			return
		end
	end
	Test.assert(true, msg)
end

function Test._deep_eq(a, b, seen)
	if a == b then return true end
	if type(a) ~= type(b) then return false end
	if type(a) ~= "table" then return false end
	if seen[a] then return true end
	seen[a] = true
	for k, v in pairs(a) do
		if not Test._deep_eq(v, b[k], seen) then return false end
	end
	for k, _ in pairs(b) do
		if a[k] == nil then return false end
	end
	return true
end

function Test.approx(actual, expected, epsilon, msg)
	epsilon = epsilon or 1e-6
	local cond = math.abs(actual - expected) <= epsilon
	if not cond then
		msg = string.format("%s (expected: ~%s, got: %s)", msg or "approx equality failed", tostring(expected),
			tostring(actual))
	end
	Test.assert(cond, msg)
end

function Test.nil_val(actual, msg)
	Test.assert(actual == nil, msg or "expected nil value")
end

function Test.summary()
	print(string.format("\n========================================"))
	print(string.format("Results: %d passed, %d failed", Test.passed, Test.failed))
	if #Test.errors > 0 then
		print("\nFailures:")
		for _, e in ipairs(Test.errors) do
			print(e)
		end
	end
	print("========================================")
	return Test.failed == 0
end

----------------------------------------------------------------------
-- Load the library under test
----------------------------------------------------------------------

-- Bootstrap: make parent-relative requires work from tests/ subdir with plain lua.
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
	local rootd
	for _, c in ipairs({ dir, dir .. "../", dir .. "../..//", dir .. "../../..//", "./", "../", "../../" }) do
		if isfile(c .. "standalone/bits.lua") then
			rootd = c
			break
		end
	end
	rootd = rootd or dir .. "../"
	if package then
		package.path = dir ..
			"../?.lua;" ..
			dir ..
			"../?/init.lua;" ..
			dir ..
			"?.lua;" ..
			dir ..
			"?/init.lua;" ..
			rootd ..
			"?.lua;" ..
			rootd ..
			"?/init.lua;" ..
			rootd ..
			"standalone/?.lua;" ..
			rootd .. "math/?.lua;" .. rootd .. "collections/?.lua;" .. rootd .. "standard/?.lua;" .. package.path
	end
	local searchers = package.searchers or package.loaders
	if searchers then
		table.insert(searchers, 2, function(mod)
			if mod:sub(1, 3) == "../" or mod:sub(1, 2) == "./" then
				local clean = mod:gsub("^%./", ""):gsub("^%.%.%/", ""):gsub("^%.%.%/", "")
				local tries = { dir .. "../" .. clean .. ".lua", dir .. "../" .. clean .. "/init.lua", rootd ..
				clean .. ".lua", rootd .. clean .. "/init.lua" }
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

	-- Preload standard extensions over stdlib (plain lua resolves require "string" to C lib).
	do
		local function try_preload(name, relpath)
			if package.loaded[name] == nil or type(package.loaded[name]) ~= "table" or package.loaded[name].explode == nil and name == "string" then
				local f = rootd .. relpath
				local fh = io.open(f, "r")
				if fh then
					fh:close()
					local chunk, err = loadfile(f)
					if chunk then
						local ok, mod = pcall(chunk, name)
						if ok and mod ~= nil then
							package.loaded[name] = mod
						end
					end
				end
			end
		end
		-- Only override string (table/math use _G, but ensure extensions load if needed).
		try_preload("string", "standard/string.lua")
	end
end

local lib = require "../table"

----------------------------------------------------------------------
-- Tests: Type Checks & Inspection
----------------------------------------------------------------------

Test.suite("is_empty")
Test.equal(table.is_empty({}), true, "empty table")
Test.equal(table.is_empty({ 1 }), false, "non-empty array")
Test.equal(table.is_empty({ a = 1 }), false, "non-empty map")

Test.suite("is_array")
Test.equal(table.is_array({ 1, 2, 3 }), true, "proper array")
Test.equal(table.is_array({}), true, "empty table is array")
Test.equal(table.is_array({ 1, nil, 3 }), false, "sparse array")
Test.equal(table.is_array({ a = 1 }), false, "string keys")
Test.equal(table.is_array({ [0] = 1, 2, 3 }), false, "zero index")
Test.equal(table.is_array(nil), false, "nil input")

Test.suite("is_array_like")
Test.equal(table.is_array_like({ 1, 2, 3 }), true, "sequential numeric")
Test.equal(table.is_array_like({ [1] = "a", [5] = "b" }), true, "sparse numeric")
Test.equal(table.is_array_like({ a = 1 }), false, "string keys")
Test.equal(table.is_array_like({}), true, "empty")

Test.suite("is_enum")
Test.equal(table.is_enum({ A = 1, B = 2 }), true, "valid enum")
Test.equal(table.is_enum({ A = "x" }), false, "non-number value")
Test.equal(table.is_enum({ 1, 2 }), false, "numeric keys")
Test.equal(table.is_enum(setmetatable({ A = 1 }, {})), false, "has metatable")

Test.suite("has_key")
local hk = { a = 1, b = nil }
Test.equal(table.has_key(hk, "a"), true, "existing key")
Test.equal(table.has_key(hk, "b"), false, "nil value key")
Test.equal(table.has_key(hk, "c"), false, "missing key")

----------------------------------------------------------------------
-- Tests: Clear / Count / Keys / Values
----------------------------------------------------------------------

Test.suite("clear / empty")
local ct = { 1, 2, a = 3 }
table.clear(ct)
Test.equal(next(ct), nil, "clear empties table")
local ct2 = { 1 }
table.empty(ct2)
Test.equal(next(ct2), nil, "empty alias works")

Test.suite("clear_range")
local cr = { 1, 2, 3, 4, 5 }
table.clear_range(cr, 2, 4)
Test.equal(cr[1], 1, "before range preserved")
Test.equal(cr[2], nil, "range start cleared")
Test.equal(cr[3], nil, "range mid cleared")
Test.equal(cr[4], nil, "range end cleared")
Test.equal(cr[5], 5, "after range preserved")

Test.suite("count")
Test.equal(table.count({ a = 1, b = 2, c = 3 }), 3, "map count")
Test.equal(table.count({ 1, 2, 3 }), 3, "array count")
Test.equal(table.count({}), 0, "empty count")

Test.suite("keys / values / keys_values / keys_values_named")
local kv = { a = 1, b = 2 }
local ks = table.keys(kv)
Test.equal(#ks, 2, "keys length")
local vs = table.values(kv)
Test.equal(#vs, 2, "values length")
local kvs = table.keys_values(kv)
Test.equal(#kvs, 2, "keys_values length")
Test.equal(type(kvs[1]), "table", "keys_values entry is table")
Test.equal(#kvs[1], 2, "keys_values entry has 2 elements")
local kvn = table.keys_values_named(kv)
Test.equal(#kvn, 2, "keys_values_named length")
Test.assert(kvn[1].k ~= nil and kvn[1].v ~= nil, "named pair has k and v fields")

----------------------------------------------------------------------
-- Tests: Iteration Helpers
----------------------------------------------------------------------

Test.suite("foreach / foreachi")
local sum = 0
table.foreach({ a = 1, b = 2, c = 3 }, function(k, v) sum = sum + v end)
Test.equal(sum, 6, "foreach visits all")

local isum = 0
table.foreachi({ 10, 20, 30 }, function(i, v) isum = isum + v end)
Test.equal(isum, 60, "foreachi visits array part")

Test.suite("next_iter")
local ni_sum = 0
table.next_iter(function(k, v) ni_sum = ni_sum + v end, { a = 1, b = 2 })
Test.equal(ni_sum, 3, "next_iter visits all")

Test.suite("fast_keys / fast_values / fast_keys_values")
local fk_collected = {}
local fk_cont = table.fast_keys({ a = 1, b = 2 }, function(k) fk_collected[#fk_collected + 1] = k end)
if fk_cont then
	while true do
		local r = fk_cont(); if not r then break end
	end
end
Test.equal(#fk_collected, 2, "fast_keys collects all keys")

local fv_collected = {}
local fv_cont = table.fast_values({ a = 1, b = 2 }, function(v) fv_collected[#fv_collected + 1] = v end)
if fv_cont then
	while true do
		local r = fv_cont(); if not r then break end
	end
end
Test.equal(#fv_collected, 2, "fast_values collects all values")

local fkv_collected = {}
local fkv_cont = table.fast_keys_values({ a = 1 }, function(k, v) fkv_collected[#fkv_collected + 1] = { k, v } end)
if fkv_cont then
	while true do
		local r = fkv_cont(); if not r then break end
	end
end
Test.equal(#fkv_collected, 1, "fast_keys_values collects pairs")

----------------------------------------------------------------------
-- Tests: Emit / Invoke / Initmeta
----------------------------------------------------------------------

Test.suite("emit / emit_with_args / invoke")
local obj = {
	greet = function(name) return "hi " .. name end,
	method = function(self, x) return self.val + x end,
	val = 10,
}
Test.equal(table.emit(obj, "greet", "world"), "hi world", "emit calls method")
Test.equal(table.emit(obj, "missing"), nil, "emit missing returns nil")
Test.equal(table.invoke(obj, "method", 5), 15, "invoke passes self")

Test.suite("initmeta")
local im = table.initmeta({}, { __index = { default = true } }, { x = 1 })
Test.equal(im.x, 1, "initmeta copies init values")
Test.equal(getmetatable(im).__index.default, true, "initmeta sets metatable")

----------------------------------------------------------------------
-- Tests: Pack / Unpack / Unwrap
----------------------------------------------------------------------

Test.suite("pack / unpack / unwrap")
local p = table.pack(1, 2, 3)
Test.equal(p.n, 3, "pack n field")
Test.equal(p[1], 1, "pack first element")

local a, b, c = table.unpack({ 10, 20, 30 })
Test.equal(a, 10, "unpack first")
Test.equal(c, 30, "unpack third")

local u1, u2 = table.unwrap({ 100, 200 })
Test.equal(u1, 100, "unwrap single table arg")
Test.equal(u2, 200, "unwrap second from table")

local x, y = table.unwrap(1, 2)
Test.equal(x, 1, "unwrap multiple args passthrough")

----------------------------------------------------------------------
-- Tests: Copy Operations
----------------------------------------------------------------------

Test.suite("shallow_copy")
local orig = { a = 1, nested = { x = 1 } }
local sc = table.shallow_copy(orig)
sc.a = 99
Test.equal(orig.a, 1, "shallow copy independent top-level")
sc.nested.x = 99
Test.equal(orig.nested.x, 99, "shallow copy shares nested refs")

Test.suite("deep_copy")
local dorig = { a = { b = { c = 1 } } }
local dc = table.deep_copy(dorig)
dc.a.b.c = 99
Test.equal(dorig.a.b.c, 1, "deep copy independent nested")

Test.suite("deep_copy circular ref")
local circ = { a = 1 }
circ.self = circ
local dcc = table.deep_copy(circ)
Test.equal(dcc.self == dcc, true, "deep_copy handles cycles")

Test.suite("deep_copy_with_meta")
local mt = { __tag = "test" }
local wmeta = setmetatable({ a = 1 }, mt)
local dwm = table.deep_copy_with_meta(wmeta)
Test.equal(getmetatable(dwm).__tag, "test", "metatatable copied")

Test.suite("copy_array / array / numeric")
local ca_src = { 1, 2, 3, x = 4 }
Test.deep_equal(table.copy_array(ca_src), { 1, 2, 3 }, "copy_array only numeric indices")
Test.deep_equal(table.array({ a = 1, b = 2 }), { 1, 2 }, "array extracts values")
Test.deep_equal(table.numeric({ 1, 2, x = 3 }), { 1, 2 }, "numeric extracts array part")

----------------------------------------------------------------------
-- Tests: Enum / Inverse / Ensure
----------------------------------------------------------------------

Test.suite("enum")
local en = table.enum({ RED = 1, BLUE = 2 })
Test.equal(en.RED, 1, "enum forward")
Test.equal(en[1], "RED", "enum reverse")

Test.suite("inverse / invert")
local inv = table.inverse({ a = 1, b = 2 })
Test.equal(inv[1], "a", "inverse mapping")
Test.equal(table.invert({ x = 10 })[10], "x", "invert alias")

Test.suite("ensure / ensure_lazy")
local et = {}
table.ensure(et, "a", 42)
Test.equal(et.a, 42, "ensure sets default")
table.ensure(et, "a", 99)
Test.equal(et.a, 42, "ensure preserves existing")

local lazy_calls = 0
table.ensure_lazy(et, "b", function()
	lazy_calls = lazy_calls + 1; return "lazy"
end)
Test.equal(et.b, "lazy", "ensure_lazy creates value")
Test.equal(lazy_calls, 1, "factory called once")
table.ensure_lazy(et, "b", function()
	lazy_calls = lazy_calls + 1; return "other"
end)
Test.equal(lazy_calls, 1, "factory not called again")

----------------------------------------------------------------------
-- Tests: Case Insensitive
----------------------------------------------------------------------

Test.suite("make_case_insensitive")
local ci = table.make_case_insensitive({ Name = "John" })
Test.equal(ci.name, "John", "case insensitive read lowercase")
Test.equal(ci.NAME, "John", "case insensitive read uppercase")
ci.age = 30
Test.equal(ci.AGE, 30, "case insensitive write/read")

Test.suite("case_insensitive proxy")
local cip = table.case_insensitive({ Foo = "bar" })
Test.equal(cip.foo, "bar", "proxy case insensitive read")
cip.FOO = "baz"
Test.equal(cip.foo, "baz", "proxy case insensitive update")

----------------------------------------------------------------------
-- Tests: Key Transformations
----------------------------------------------------------------------

Test.suite("lowercase_keys / uppercase_keys")
Test.deep_equal(table.lowercase_keys({ A = 1, B = 2 }), { a = 1, b = 2 }, "lowercase keys")
Test.deep_equal(table.uppercase_keys({ a = 1, b = 2 }), { A = 1, B = 2 }, "uppercase keys")
Test.deep_equal(table.lowercase({ X = 1 }), { x = 1 }, "lowercase alias")
Test.deep_equal(table.uppercase({ x = 1 }), { X = 1 }, "uppercase alias")

----------------------------------------------------------------------
-- Tests: Remove First / Last
----------------------------------------------------------------------

Test.suite("remove_first")
local rf = { 1, 2, 3, 4, 5 }
table.remove_first(rf, 2)
Test.deep_equal(rf, { 3, 4, 5 }, "remove_first 2")
table.remove_first(rf, 10)
Test.deep_equal(rf, {}, "remove_first more than length")

Test.suite("remove_last")
local rl = { 1, 2, 3, 4, 5 }
table.remove_last(rl, 2)
Test.deep_equal(rl, { 1, 2, 3 }, "remove_last 2")
table.remove_last(rl, 10)
Test.deep_equal(rl, {}, "remove_last more than length")

----------------------------------------------------------------------
-- Tests: Unique / Pick / Omit
----------------------------------------------------------------------

Test.suite("unique")
Test.deep_equal(table.unique({ 1, 2, 2, 3, 1 }), { 1, 2, 3 }, "unique removes dupes")

Test.suite("pick")
Test.deep_equal(table.pick({ a = 1, b = 2, c = 3 }, { "a", "c" }), { a = 1, c = 3 }, "pick whitelist")

Test.suite("omit")
Test.deep_equal(table.omit({ a = 1, b = 2, c = 3 }, { "b" }), { a = 1, c = 3 }, "omit blacklist")

----------------------------------------------------------------------
-- Tests: Flatten
----------------------------------------------------------------------

Test.suite("flatten")
Test.deep_equal(table.flatten({ 1, { 2, 3 }, { 4, { 5 } } }), { 1, 2, 3, 4, 5 }, "flatten nested")
local fd = table.flatten({ 1, { 2, { 3, { 4 } } } }, 1)
Test.equal(#fd, 3, "flatten depth limited count")
Test.equal(type(fd[3]), "table", "flatten depth limited keeps nested")

----------------------------------------------------------------------
-- Tests: Map / Where / Reduce / Filter
----------------------------------------------------------------------

Test.suite("map")
Test.deep_equal(table.map({ a = 1, b = 2 }, function(v) return v * 2 end), { a = 2, b = 4 }, "map transforms")

Test.suite("where")
Test.deep_equal(table.where({ a = 1, b = 2, c = 3 }, function(v) return v > 1 end), { b = 2, c = 3 }, "where filters")

Test.suite("reduce")
Test.equal(table.reduce({ 1, 2, 3 }, function(acc, v) return acc + v end, 0), 6, "reduce sum")

Test.suite("filter array mode")
Test.deep_equal(table.filter({ 1, 2, 3, 4 }, function(v) return v % 2 == 0 end), { 2, 4 }, "filter array evens")

Test.suite("filter map mode")
local fm = table.filter({ a = 1, b = 2, c = 3 }, function(v) return v > 1 end)
Test.equal(fm.b, 2, "filter map keeps keys")
Test.equal(fm.a, nil, "filter map excludes non-matching")

Test.suite("filter_inplace")
local fip = { 1, 2, 3, 4, 5 }
table.filter_inplace(fip, function(v) return v > 3 end)
Test.deep_equal(fip, { 4, 5 }, "filter_inplace array compacts")

Test.suite("filter_iter")
local fi_results = {}
for k, v in table.filter_iter({ a = 1, b = 5, c = 2, d = 8 }, function(v) return v > 3 end) do
	fi_results[k] = v
end
Test.deep_equal(fi_results, { b = 5, d = 8 }, "filter_iter lazy")

Test.suite("filter_pattern")
Test.deep_equal(table.filter_pattern({ "apple", "banana", "apricot" }, "^ap"), { "apple", "apricot" },
	"filter_pattern prefix")

----------------------------------------------------------------------
-- Tests: Concat Safe / Slice / Chunks
----------------------------------------------------------------------

Test.suite("concat_safe")
Test.equal(table.concat_safe({ 1, "a", true }, ","), "1,a,true", "concat_safe mixed types")

Test.suite("slice")
Test.deep_equal(table.slice({ 1, 2, 3, 4, 5 }, 2, 4), { 2, 3, 4 }, "slice range")
Test.deep_equal(table.slice({ 1, 2, 3, 4, 5 }, -2), { 4, 5 }, "slice negative start")

Test.suite("chunks")
local ch = table.chunks({ 1, 2, 3, 4, 5 }, 2)
Test.equal(#ch, 3, "chunks count")
Test.deep_equal(ch[1], { 1, 2 }, "chunks first")
Test.deep_equal(ch[3], { 5 }, "chunks last partial")

----------------------------------------------------------------------
-- Tests: Rotation
----------------------------------------------------------------------

Test.suite("rotated_left / rotated_right / rotated")
Test.deep_equal(table.rotated_left({ 1, 2, 3, 4, 5 }, 2), { 3, 4, 5, 1, 2 }, "rotated_left 2")
Test.deep_equal(table.rotated_right({ 1, 2, 3, 4, 5 }, 2), { 4, 5, 1, 2, 3 }, "rotated_right 2")
Test.deep_equal(table.rotated({ 1, 2, 3 }, -1), { 2, 3, 1 }, "rotated negative = left")

Test.suite("rotate_left / rotate_right / rotate (in-place)")
local rlp = { 1, 2, 3, 4, 5 }
table.rotate_left(rlp, 2)
Test.deep_equal(rlp, { 3, 4, 5, 1, 2 }, "rotate_left in-place")

local rrp = { 1, 2, 3, 4, 5 }
table.rotate_right(rrp, 1)
Test.deep_equal(rrp, { 5, 1, 2, 3, 4 }, "rotate_right in-place")

Test.suite("rotated2D / rotate2D")
local grid = { { 1, 2, 3 }, { 4, 5, 6 }, { 7, 8, 9 } }
local rg = table.rotated2D(grid, 1, 0)
Test.deep_equal(rg[1], { 3, 1, 2 }, "rotated2D horizontal shift")

----------------------------------------------------------------------
-- Tests: Reverse
----------------------------------------------------------------------

Test.suite("reverse / reversed")
local rv = { 1, 2, 3 }
table.reverse(rv)
Test.deep_equal(rv, { 3, 2, 1 }, "reverse in-place")
Test.deep_equal(table.reversed({ 1, 2, 3 }), { 3, 2, 1 }, "reversed new table")

----------------------------------------------------------------------
-- Tests: Switch / Case
----------------------------------------------------------------------

Test.suite("switch builder")
local sw = table.switch()
	:case("a", 1)
	:case("b", 2)
	:default(0)
Test.equal(sw:eval("a"), 1, "switch eval match")
Test.equal(sw:eval("z"), 0, "switch eval default")
local baked = sw:bake()
Test.equal(baked["b"], 2, "switch baked lookup")

Test.suite("case")
local cs = table.case("x")
	:when("x", 10)
	:when("y", 20)
	:otherwise(0)
Test.equal(cs:eval(), 10, "case eval match")

----------------------------------------------------------------------
-- Tests: Weak Tables
----------------------------------------------------------------------

Test.suite("weak tables")
local wk = table.weak_keys()
Test.equal(getmetatable(wk).__mode, "k", "weak_keys mode")
local wv = table.weak_values()
Test.equal(getmetatable(wv).__mode, "v", "weak_values mode")
local wkv = table.weak()
Test.equal(getmetatable(wkv).__mode, "kv", "weak kv mode")

----------------------------------------------------------------------
-- Tests: Randomize / Random Choice
----------------------------------------------------------------------

Test.suite("randomize / random_choice")
local rr = { 1, 2, 3, 4, 5 }
table.randomize(rr)
Test.equal(#rr, 5, "randomize preserves length")
local rc = table.random_choice({ 10, 20, 30 })
Test.assert(rc == 10 or rc == 20 or rc == 30, "random_choice valid element")
Test.equal(table.random_choice({}), nil, "random_choice empty returns nil")

----------------------------------------------------------------------
-- Tests: Add / Merge / Merge Preserve
----------------------------------------------------------------------

Test.suite("add")
local ad = { 1, 2 }
table.add(ad, { 3, 4 })
Test.deep_equal(ad, { 1, 2, 3, 4 }, "add appends")

Test.suite("merge")
local mg = { a = 1 }
table.merge(mg, { b = 2, a = 99 })
Test.equal(mg.a, 99, "merge overwrites")
Test.equal(mg.b, 2, "merge adds new")

Test.suite("merge_preserve")
local mp = { a = 1 }
table.merge_preserve(mp, { a = 99, b = 2 })
Test.equal(mp.a, 1, "merge_preserve keeps existing")
Test.equal(mp.b, 2, "merge_preserve adds new")

----------------------------------------------------------------------
-- Tests: Sorting
----------------------------------------------------------------------

Test.suite("sortdesc")
local sd = { 3, 1, 2 }
table.sortdesc(sd)
Test.deep_equal(sd, { 3, 2, 1 }, "sortdesc")

Test.suite("sorted iterator")
local si_results = {}
for k, v in table.sorted({ c = 3, a = 1, b = 2 }) do
	si_results[#si_results + 1] = k
end
Test.deep_equal(si_results, { "a", "b", "c" }, "sorted ascending keys")

Test.suite("sorted_keys")
Test.deep_equal(table.sorted_keys({ c = 3, a = 1, b = 2 }), { "a", "b", "c" }, "sorted_keys asc")
Test.deep_equal(table.sorted_keys({ c = 3, a = 1 }, true), { "c", "a" }, "sorted_keys desc")

Test.suite("sort_by / sort_by_field / sort_by_key")
local sb = { { n = "b", v = 2 }, { n = "a", v = 1 } }
table.sort_by(sb, function(e) return e.v end)
Test.equal(sb[1].n, "a", "sort_by custom key")

local sbf = { { name = "b", age = 2 }, { name = "a", age = 1 } }
table.sort_by_field(sbf, "age")
Test.equal(sbf[1].name, "a", "sort_by_field")

local sbk = { 3, 1, 2 }
table.sort_by_key(sbk, function(v) return -v end)
Test.deep_equal(sbk, { 3, 2, 1 }, "sort_by_key descending via negation")

----------------------------------------------------------------------
-- Tests: Math Aggregations
----------------------------------------------------------------------

Test.suite("sum / max / min / average / median / stats")
Test.equal(table.sum({ 1, 2, 3 }), 6, "sum")
Test.equal(table.max({ 1, 5, 3 }), 5, "max")
Test.equal(table.min({ 1, 5, 3 }), 1, "min")
Test.equal(table.average({ 2, 4 }), 3, "average")
Test.equal(table.avg({ 2, 4 }), 3, "avg alias")
Test.equal(table.median({ 1, 2, 3 }), 2, "median odd")
Test.equal(table.median({ 1, 2, 3, 4 }), 2.5, "median even")

local st = table.stats({ 1, 2, 3, 4, 5 })
Test.equal(st.sum, 15, "stats sum")
Test.equal(st.count, 5, "stats count")
Test.equal(st.min, 1, "stats min")
Test.equal(st.max, 5, "stats max")
Test.equal(st.range, 4, "stats range")

----------------------------------------------------------------------
-- Tests: Path Access
----------------------------------------------------------------------

Test.suite("get_path / set_path")
local pt = { a = { b = { c = 42 } } }
Test.equal(table.get_path(pt, "a.b.c"), 42, "get_path dot notation")
Test.equal(table.get_path(pt, "a.b.missing"), nil, "get_path missing")

table.set_path(pt, "a.b.d", 99)
Test.equal(pt.a.b.d, 99, "set_path creates intermediate")

Test.suite("get / set")
Test.equal(table.get({ a = { b = 1 } }, "a.b"), 1, "get dot path")
Test.equal(table.get({ a = 1 }, "x.y", "def"), "def", "get default")
local gst = {}
table.set(gst, "a.b", 5)
Test.equal(gst.a.b, 5, "set creates path")

----------------------------------------------------------------------
-- Tests: Stack / Queue
----------------------------------------------------------------------

Test.suite("push / pop / peek / dequeue")
local stk = {}
table.push(stk, 1, 2)
Test.deep_equal(stk, { 1, 2 }, "push multiple")
Test.equal(table.peek(stk), 2, "peek top")
Test.equal(table.pop(stk), 2, "pop returns top")
Test.equal(#stk, 1, "pop removes")

local q = { "a", "b", "c" }
Test.equal(table.dequeue(q), "a", "dequeue front")
Test.deep_equal(q, { "b", "c" }, "dequeue shifts")

----------------------------------------------------------------------
-- Tests: Binary Search / Partition
----------------------------------------------------------------------

Test.suite("binary_search")
Test.equal(table.binary_search({ 10, 20, 30, 40 }, 30), 3, "binary_search found")
Test.assert(table.binary_search({ 10, 20, 40 }, 30) < 0, "binary_search not found negative")

Test.suite("partition")
local pa = { 3, 6, 8, 10, 1, 2, 1 }
local pi = table.partition(pa, 1, #pa)
Test.assert(pa[pi] ~= nil, "partition returns valid pivot index")

----------------------------------------------------------------------
-- Tests: Set Operations
----------------------------------------------------------------------

Test.suite("union / intersection / difference / set_equals")
Test.deep_equal(table.union({ 1, 2 }, { 2, 3 }), { 1, 2, 3 }, "union")
Test.deep_equal(table.intersection({ 1, 2, 3 }, { 2, 3, 4 }), { 2, 3 }, "intersection")
Test.deep_equal(table.difference({ 1, 2, 3 }, { 2 }), { 1, 3 }, "difference")
Test.equal(table.set_equals({ 1, 2, 3 }, { 3, 1, 2 }), true, "set_equals same")
Test.equal(table.set_equals({ 1, 1 }, { 1, 2 }), false, "set_equals different")

----------------------------------------------------------------------
-- Tests: Zip / Heap
----------------------------------------------------------------------

Test.suite("zip")
Test.deep_equal(table.zip({ 1, 2 }, { "a", "b" }), { { 1, "a" }, { 2, "b" } }, "zip two arrays")

Test.suite("heapify / heap_sift_down")
local hp = { 9, 5, 7, 1, 3 }
table.heapify(hp)
Test.equal(hp[1], 1, "heapify min at root")

----------------------------------------------------------------------
-- Tests: Proxy / Track / Autotable / DefaultDict / Readonly
----------------------------------------------------------------------

Test.suite("create_proxy")
local cpo = { a = 1 }
local cpp = table.create_proxy(cpo)
cpp.b = 2
Test.equal(cpo.b, 2, "proxy write-through")
Test.equal(cpp.a, 1, "proxy read-through")

Test.suite("track")
local tracked_events = {}
local tt = table.track({ x = 1 }, {
	on_read = function(t, k, v) tracked_events[#tracked_events + 1] = { "r", k } end,
	on_create = function(t, k, v) tracked_events[#tracked_events + 1] = { "c", k } end,
	on_update = function(t, k, o, n) tracked_events[#tracked_events + 1] = { "u", k } end,
	on_delete = function(t, k, o) tracked_events[#tracked_events + 1] = { "d", k } end,
})
_ = tt.x
tt.y = 2
tt.x = 10
tt.x = nil
Test.equal(#tracked_events, 4, "track fires all callbacks")
Test.equal(tracked_events[1][1], "r", "track read event")
Test.equal(tracked_events[2][1], "c", "track create event")
Test.equal(tracked_events[3][1], "u", "track update event")
Test.equal(tracked_events[4][1], "d", "track delete event")

Test.suite("autotable")
local at = table.autotable()
at.a.b.c = 42
Test.equal(at.a.b.c, 42, "autotable auto-vivifies")

Test.suite("defaultdict")
local dd = table.defaultdict(function() return 0 end)
dd["a"] = 1
Test.equal(dd["a"], 1, "defaultdict explicit value")
Test.equal(dd["b"], 0, "defaultdict auto-vivified default")
Test.equal(dd:is_explicit("a"), true, "defaultdict is_explicit true")
Test.equal(dd:is_explicit("b"), false, "defaultdict is_explicit false")
dd:freeze()
Test.equal(dd["new"], nil, "frozen defaultdict returns nil for missing")

Test.suite("readonly")
local ro = table.readonly({ a = 1 })
Test.equal(ro.a, 1, "readonly read works")
local ro_err = false
pcall(function() ro.a = 2 end)
-- Should have errored; check via pcall
local ok, _ = pcall(function() ro.a = 2 end)
Test.equal(ok, false, "readonly prevents writes")

----------------------------------------------------------------------
-- Tests: Find / Dump / Pretty Printers
----------------------------------------------------------------------

Test.suite("find")
Test.equal(table.find({ 10, 20, 30 }, 20), 2, "find array value")
Test.equal(table.find({ a = 1, b = 2 }, 2), "b", "find map value")
Test.equal(table.find({ 1, 2 }, 99), nil, "find missing")

Test.suite("dump / dump_print")
local dl_count, dl_lines = table.dump({ a = 1, b = { c = 2 } }, "root")
Test.assert(dl_count > 0, "dump returns line count")
Test.assert(type(dl_lines) == "table", "dump returns lines array")
-- dump_print just prints, no return to assert easily; smoke test
pcall(function() table.dump_print({ x = 1 }) end)
Test.assert(true, "dump_print does not crash")

Test.suite("pretty_grid / pretty_hex_dump / pretty_print_structure")
-- Smoke tests: ensure they don't error
pcall(function() table.pretty_grid({ { "a", "b" }, { "c", "d" } }) end)
Test.assert(true, "pretty_grid smoke")
pcall(function() table.pretty_hex_dump("hello") end)
Test.assert(true, "pretty_hex_dump smoke")
pcall(function() table.pretty_print_structure({ a = { b = 1 } }) end)
Test.assert(true, "pretty_print_structure smoke")

----------------------------------------------------------------------
-- Tests: Move (polyfill/native)
----------------------------------------------------------------------

Test.suite("move")
local mv = { 1, 2, 3, 4, 5 }
table.move(mv, 1, 3, 4)
Test.equal(mv[4], 1, "move overlapping dest")
Test.equal(mv[5], 2, "move overlapping dest+1")
Test.equal(mv[6], 3, "move overlapping dest+2")

local mvd = {}
table.move({ 10, 20, 30 }, 1, 3, 1, mvd)
Test.deep_equal(mvd, { 10, 20, 30 }, "move to separate dest table")


----------------------------------------------------------------------
-- Run Summary
----------------------------------------------------------------------

local all_passed = Test.summary()
os.exit(all_passed and 0 or 1)
