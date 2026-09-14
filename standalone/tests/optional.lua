-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for optional.lua.
-- Run from this directory:
--   lua optional.lua
--   luajit optional.lua

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
local Optional = require "optional"

if true then
	local string_format = string.format
	local total, passed, failed = 0, 0, 0
	local function test(name, fn)
		total = total + 1
		local ok, err = pcall(fn)
		if ok then
			passed = passed + 1
		else
			failed = failed + 1
			print(string_format("  FAIL  %s: %s", name, tostring(err)))
		end
	end
	local function expect_error(fn, pattern)
		local ok, err = pcall(fn)
		assert(not ok, "expected error but got success: " .. tostring(err))
		if pattern then
			assert(tostring(err):find(pattern, 1, true),
				"error message does not contain '" .. pattern .. "': " .. tostring(err))
		end
	end
	print("[optional] testing...")

	-- constructors
	test("some wraps a value", function()
		local o = Optional.some(10)
		assert(o:isSome() == true)
		assert(o:get() == 10)
	end)

	test("some rejects nil", function()
		expect_error(function() Optional.some(nil) end, "cannot be nil")
	end)

	test("of wraps a value and rejects nil", function()
		assert(Optional.of("x"):get() == "x")
		expect_error(function() Optional.of(nil) end, "cannot be nil")
	end)

	test("ofNullable maps nil to None", function()
		assert(Optional.ofNullable(nil):isNone() == true)
		assert(Optional.ofNullable(0):get() == 0)
		assert(Optional.ofNullable(false):get() == false)
	end)

	test("none/empty share one singleton", function()
		assert(Optional.none():isNone() == true)
		assert(Optional.empty():isNone() == true)
		assert(Optional.none() == Optional.empty())
		assert(Optional.none() == Optional.NONE)
	end)

	test("from without predicate behaves like ofNullable", function()
		assert(Optional.from(5):get() == 5)
		assert(Optional.from(nil):isNone() == true)
	end)

	test("from with predicate", function()
		assert(Optional.from(5, function(v) return v > 3 end):get() == 5)
		assert(Optional.from(2, function(v) return v > 3 end):isNone() == true)
		assert(Optional.from(nil, function() return true end):isNone() == true)
		expect_error(function() Optional.from(1, "x") end, "expected function")
	end)

	test("try captures success and failure", function()
		assert(Optional.try(function(a, b) return a + b end, 2, 3):get() == 5)
		assert(Optional.try(function() error("boom") end):isNone() == true)
		assert(Optional.try(function() return nil end):isNone() == true)
		expect_error(function() Optional.try(42) end, "expected function")
	end)

	test("isOptional recognizes instances only", function()
		assert(Optional.isOptional(Optional.some(1)) == true)
		assert(Optional.isOptional(Optional.none()) == true)
		assert(Optional.isOptional(nil) == false)
		assert(Optional.isOptional({}) == false)
		assert(Optional.isOptional(42) == false)
		assert(Optional.isOptional("x") == false)
	end)

	test("valueOf and coalesce alias ofNullable", function()
		assert(Optional.valueOf(4):get() == 4)
		assert(Optional.valueOf(nil):isNone() == true)
		assert(Optional.coalesce(4):get() == 4)
		assert(Optional.coalesce(nil):isNone() == true)
	end)

	test("calling the module equals ofNullable", function()
		assert(Optional("hi"):get() == "hi")
		assert(Optional(nil):isNone() == true)
	end)

	-- basic state
	test("state predicates agree", function()
		local s, n = Optional.some(1), Optional.none()
		assert(s:isSome() and s:isPresent())
		assert(not s:isNone() and not s:isEmpty())
		assert(n:isNone() and n:isEmpty())
		assert(not n:isSome() and not n:isPresent())
	end)

	test("isTruthy is always true", function()
		assert(Optional.some(1):isTruthy() == true)
		assert(Optional.none():isTruthy() == true)
	end)

	-- extraction
	test("get and unwrap return the value", function()
		assert(Optional.some("v"):get() == "v")
		assert(Optional.some("v"):unwrap() == "v")
		expect_error(function() Optional.none():get() end, "from None")
		expect_error(function() Optional.none():unwrap() end, "unwrap None")
	end)

	test("expect uses the custom message", function()
		assert(Optional.some(1):expect("nope") == 1)
		expect_error(function() Optional.none():expect("custom msg") end, "custom msg")
	end)

	test("getOrElse and unwrapOr fall back", function()
		assert(Optional.some(1):getOrElse(0) == 1)
		assert(Optional.none():getOrElse(0) == 0)
		assert(Optional.some(1):unwrapOr(0) == 1)
		assert(Optional.none():unwrapOr(0) == 0)
	end)

	test("lazy fallbacks run only for None", function()
		local calls = 0
		local function fb()
			calls = calls + 1
			return 9
		end
		assert(Optional.some(1):getOrElseLazy(fb) == 1)
		assert(Optional.some(1):unwrapOrElse(fb) == 1)
		assert(calls == 0)
		assert(Optional.none():getOrElseLazy(fb) == 9)
		assert(Optional.none():unwrapOrElse(fb) == 9)
		assert(calls == 2)
		expect_error(function() Optional.none():getOrElseLazy(1) end, "expected function")
		expect_error(function() Optional.none():unwrapOrElse(1) end, "expected function")
	end)

	-- functional transformations
	test("map transforms Some and skips None", function()
		local calls = 0
		assert(Optional.some(10):map(function(x) return x * 2 end):get() == 20)
		local r = Optional.none():map(function(x)
			calls = calls + 1
			return x
		end)
		assert(r:isNone() == true)
		assert(calls == 0)
		assert(Optional.some(1):map(function() return nil end):isNone() == true)
		expect_error(function() Optional.some(1):map(1) end, "expected function")
	end)

	test("mapOr returns a raw value", function()
		assert(Optional.some(3):mapOr(0, function(v) return v + 1 end) == 4)
		assert(Optional.none():mapOr(0, function(v) return v + 1 end) == 0)
		expect_error(function() Optional.some(1):mapOr(0, 1) end, "expected function")
	end)

	test("mapOrElse picks the live branch only", function()
		local d, f = 0, 0
		assert(Optional.some(3):mapOrElse(function()
			d = d + 1
			return 0
		end, function(v)
			f = f + 1
			return v + 1
		end) == 4)
		assert(d == 0 and f == 1)
		assert(Optional.none():mapOrElse(function()
			d = d + 1
			return 7
		end, function(v)
			f = f + 1
			return v
		end) == 7)
		assert(d == 1 and f == 1)
		expect_error(function() Optional.some(1):mapOrElse(1, function(v) return v end) end, "expected function")
	end)

	test("flatMap chains fallible operations", function()
		local r = Optional.some(2):flatMap(function(v) return Optional.some(v * 10) end)
		assert(r:get() == 20)
		local calls = 0
		assert(Optional.none():flatMap(function(v)
			calls = calls + 1
			return Optional.some(v)
		end):isNone() == true)
		assert(calls == 0)
		expect_error(function() Optional.some(1):flatMap(function() return 1 end) end, "must return an Optional")
		expect_error(function() Optional.some(1):flatMap(1) end, "expected function")
	end)

	test("andThen aliases flatMap", function()
		assert(Optional.some(2):andThen(function(v) return Optional.some(v + 1) end):get() == 3)
	end)

	test("flatten unwraps nesting", function()
		local inner = Optional.some("x")
		assert(Optional.some(inner):flatten() == inner)
		assert(Optional.some(Optional.none()):flatten():isNone() == true)
		local plain = Optional.some(1)
		assert(plain:flatten() == plain)
		assert(Optional.none():flatten():isNone() == true)
	end)

	test("filter keeps on true only", function()
		assert(Optional.some(1):filter(function(v) return v == 1 end):get() == 1)
		assert(Optional.some(1):filter(function() return false end):isNone() == true)
		local calls = 0
		assert(Optional.none():filter(function()
			calls = calls + 1
			return true
		end):isNone() == true)
		assert(calls == 0)
		expect_error(function() Optional.some(1):filter(1) end, "expected function")
	end)

	-- optional composition
	test("and_ keeps the right side only when both present", function()
		local a, b = Optional.some(1), Optional.some(2)
		assert(a:and_(b) == b)
		assert(a:and_(Optional.none()):isNone() == true)
		assert(Optional.none():and_(b):isNone() == true)
		expect_error(function() a:and_({}) end, "expected Optional")
	end)

	test("or_ falls back to the other", function()
		local a, b = Optional.some(1), Optional.some(2)
		assert(a:or_(b) == a)
		assert(Optional.none():or_(b) == b)
		expect_error(function() a:or_({}) end, "expected Optional")
	end)

	test("keyword and/or bracket access", function()
		local a, b = Optional.some(1), Optional.some(2)
		assert(a["and"](a, b) == b)
		assert(a["or"](a, b) == a)
		assert(a.And == a.and_)
		assert(a.Or == a.or_)
	end)

	test("orElse produces lazily", function()
		local calls = 0
		local a = Optional.some(1)
		assert(a:orElse(function()
			calls = calls + 1
			return Optional.some(2)
		end) == a)
		assert(calls == 0)
		assert(Optional.none():orElse(function() return Optional.some(2) end):get() == 2)
		expect_error(function() Optional.none():orElse(function() return 2 end) end, "must return an Optional")
		expect_error(function() a:orElse(1) end, "expected function")
	end)

	test("xor picks exactly one present side", function()
		local a = Optional.some(1)
		assert(a:xor(Optional.none()) == a)
		local n = Optional.none()
		assert(n:xor(a) == a)
		assert(a:xor(Optional.some(2)):isNone() == true)
		assert(n:xor(Optional.none()):isNone() == true)
		expect_error(function() a:xor({}) end, "expected Optional")
	end)

	test("zip pairs values", function()
		local p = Optional.some(1):zip(Optional.some(2)):get()
		assert(p[1] == 1 and p[2] == 2)
		assert(Optional.some(1):zip(Optional.none()):isNone() == true)
		assert(Optional.none():zip(Optional.some(1)):isNone() == true)
		expect_error(function() Optional.some(1):zip({}) end, "expected Optional")
	end)

	test("zipWith combines via callback", function()
		assert(Optional.some(1):zipWith(Optional.some(2), function(a, b) return a + b end):get() == 3)
		assert(Optional.some(1):zipWith(Optional.none(), function(a, b) return a + b end):isNone() == true)
		assert(Optional.some(1):zipWith(Optional.some(2), function() return nil end):isNone() == true)
		expect_error(function() Optional.some(1):zipWith(Optional.some(2), 1) end, "expected function")
	end)

	-- inspection / branching
	test("tap runs on Some and returns self", function()
		local seen
		local s = Optional.some(4)
		assert(s:tap(function(v) seen = v end) == s)
		assert(seen == 4)
		local n = Optional.none()
		assert(n:tap(function() error("must not run") end) == n)
		expect_error(function() s:tap(1) end, "expected function")
	end)

	test("tapNone runs on None and returns self", function()
		local fired = 0
		local n = Optional.none()
		assert(n:tapNone(function() fired = fired + 1 end) == n)
		assert(fired == 1)
		local s = Optional.some(1)
		assert(s:tapNone(function() error("must not run") end) == s)
		expect_error(function() n:tapNone(1) end, "expected function")
	end)

	test("match invokes exactly one branch", function()
		local s_calls, n_calls = 0, 0
		assert(Optional.some(5):match(function(v)
			s_calls = s_calls + 1
			return v * 2
		end, function()
			n_calls = n_calls + 1
			return 0
		end) == 10)
		assert(s_calls == 1 and n_calls == 0)
		assert(Optional.none():match(function()
			s_calls = s_calls + 1
			return 1
		end, function()
			n_calls = n_calls + 1
			return 0
		end) == 0)
		assert(s_calls == 1 and n_calls == 1)
		expect_error(function() Optional.some(1):match(1, function() end) end, "expected function")
		expect_error(function() Optional.some(1):match(function() end, 1) end, "expected function")
	end)

	test("fold reduces to a single value", function()
		assert(Optional.some(5):fold(function(v) return v + 1 end, 0) == 6)
		assert(Optional.none():fold(function(v) return v + 1 end, 0) == 0)
		expect_error(function() Optional.some(1):fold(1, 0) end, "expected function")
	end)

	-- containment / equality
	test("contains uses ==", function()
		assert(Optional.some(1):contains(1) == true)
		assert(Optional.some(1):contains(2) == false)
		assert(Optional.none():contains(1) == false)
	end)

	test("containsBy normalizes truthy results", function()
		assert(Optional.some(2):containsBy(function(v) return v % 2 == 0 end) == true)
		assert(Optional.some(3):containsBy(function(v) return v % 2 == 0 end) == false)
		local calls = 0
		assert(Optional.none():containsBy(function()
			calls = calls + 1
			return true
		end) == false)
		assert(calls == 0)
		assert(Optional.some(1):containsBy(function() return 1 end) == true)
		expect_error(function() Optional.some(1):containsBy(1) end, "expected function")
	end)

	test("equals compares optionals", function()
		assert(Optional.none():equals(Optional.none()) == true)
		assert(Optional.some(1):equals(Optional.some(1)) == true)
		assert(Optional.some(1):equals(Optional.some(2)) == false)
		assert(Optional.some(1):equals(Optional.none()) == false)
		assert(Optional.none():equals(Optional.some(1)) == false)
		assert(Optional.some(1):equals({}) == false)
		assert(Optional.some(1):equals(1) == false)
	end)

	-- iteration
	test("iter yields once then ends", function()
		local seen = {}
		for v in Optional.some(42):iter() do seen[#seen + 1] = v end
		assert(#seen == 1 and seen[1] == 42)
		local none_seen = 0
		for _ in Optional.none():iter() do none_seen = none_seen + 1 end
		assert(none_seen == 0)
	end)

	test("values matches iter", function()
		local seen = {}
		for v in Optional.some(7):values() do seen[#seen + 1] = v end
		assert(#seen == 1 and seen[1] == 7)
	end)

	-- conversion
	test("toNullable converts back", function()
		assert(Optional.some(5):toNullable() == 5)
		assert(Optional.none():toNullable() == nil)
	end)

	test("toTable builds fresh representations", function()
		local st = Optional.some(5):toTable()
		assert(st.has_value == true and st.value == 5)
		local nt = Optional.none():toTable()
		assert(nt.has_value == false and nt.value == nil)
		assert(Optional.some(5):toTable() ~= st)
	end)

	test("toString and tostring agree", function()
		assert(Optional.some(1):toString() == "Some(1)")
		assert(Optional.none():toString() == "None")
		assert(tostring(Optional.some(1)) == "Some(1)")
		assert(tostring(Optional.none()) == "None")
	end)

	test("equality operator", function()
		assert(Optional.some(1) == Optional.some(1))
		assert(not (Optional.some(1) == Optional.some(2)))
		assert(Optional.none() == Optional.none())
		assert(not (Optional.some(1) == Optional.none()))
		assert(not (Optional.some(1) == {}))
	end)

	test("length operator where supported", function()
		local probe = setmetatable({}, { __len = function() return 7 end })
		if #probe ~= 7 then return end -- plain 5.1: __len on tables unsupported
		assert(#Optional.some(1) == 1)
		assert(#Optional.none() == 0)
	end)

	-- metatable protection
	test("metatable is hidden and protected", function()
		assert(getmetatable(Optional.some(1)) == "Optional")
		expect_error(function() setmetatable(Optional.some(1), {}) end, "protected metatable")
	end)

	-- constants and helpers
	test("NONE constant and getMetatable", function()
		assert(Optional.NONE == Optional.none())
		local mt = Optional.getMetatable()
		assert(type(mt) == "table")
		assert(mt.__index == mt)
	end)

	-- variadic combinators
	test("zipAll collects or short-circuits", function()
		local vals = Optional.zipAll(Optional.some(1), Optional.some(2), Optional.some(3)):get()
		assert(vals[1] == 1 and vals[2] == 2 and vals[3] == 3)
		assert(Optional.zipAll(Optional.some(1), Optional.none()):isNone() == true)
		local empty = Optional.zipAll():get()
		assert(type(empty) == "table" and #empty == 0)
		expect_error(function() Optional.zipAll(Optional.some(1), {}) end, "expected Optional")
	end)

	test("firstSome returns first present", function()
		local b = Optional.some(7)
		assert(Optional.firstSome(Optional.none(), b) == b)
		assert(Optional.firstSome(Optional.none(), Optional.none()):isNone() == true)
		assert(Optional.firstSome():isNone() == true)
		expect_error(function() Optional.firstSome({}) end, "expected Optional")
	end)

	-- snake_case aliases
	test("snake_case aliases match primaries", function()
		assert(Optional.of_nullable == Optional.ofNullable)
		assert(Optional.is_optional == Optional.isOptional)
		assert(Optional.value_of == Optional.valueOf)
		assert(Optional.zip_all == Optional.zipAll)
		assert(Optional.first_some == Optional.firstSome)
		assert(Optional.get_metatable == Optional.getMetatable)
		local m = Optional.some(5)
		local pairs_list = {
			{ "is_some",    "isSome" }, { "is_none", "isNone" },
			{ "is_present", "isPresent" }, { "is_empty", "isEmpty" },
			{ "is_truthy",        "isTruthy" }, { "get_or_else", "getOrElse" },
			{ "get_or_else_lazy", "getOrElseLazy" }, { "unwrap_or", "unwrapOr" },
			{ "unwrap_or_else", "unwrapOrElse" }, { "map_or", "mapOr" },
			{ "map_or_else",    "mapOrElse" }, { "flat_map", "flatMap" },
			{ "and_then", "andThen" }, { "or_else", "orElse" },
			{ "zip_with", "zipWith" }, { "tap_none", "tapNone" },
			{ "contains_by", "containsBy" }, { "to_nullable", "toNullable" },
			{ "to_table",    "toTable" }, { "to_string", "toString" },
		}
		for _, p in ipairs(pairs_list) do
			assert(m[p[1]] == m[p[2]], "alias mismatch: " .. p[1])
		end
	end)

	test("snake_case aliases behave identically", function()
		assert(Optional.of_nullable(1):get() == 1)
		assert(Optional.of_nullable(nil):is_none())
		assert(Optional.is_optional(Optional.some(1)))
		local m = Optional.some(5)
		assert(m:is_some() and not m:is_none())
		assert(m:get_or_else(0) == 5)
		assert(m:map_or(0, function(v) return v * 2 end) == 10)
		assert(m:flat_map(function(v) return Optional.some(v + 1) end):get() == 6)
		assert(m:and_then(function(v) return Optional.some(v + 1) end):get() == 6)
		assert(m:zip_with(Optional.some(2), function(a, b) return a + b end):get() == 7)
		assert(m:contains_by(function(v) return v == 5 end))
		assert(m:to_nullable() == 5 and m:to_string() == "Some(5)")
		assert(Optional.zip_all(Optional.some(1)):get()[1] == 1)
		assert(Optional.first_some(Optional.none(), m) == m)
		assert(Optional.get_metatable() == Optional.getMetatable())
	end)

	print(string_format("[optional] %d/%d tests passed (%d failed)", passed, total, failed))
	assert(failed == 0, string_format("%d test(s) failed", failed))
end
