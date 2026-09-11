-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for pattern.lua.
-- Run from this directory:
--   lua pattern.lua
--   luajit pattern.lua

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
				clean .. ".lua",
					root .. clean .. "/init.lua" }
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
local lib = require "pattern"
-- Bridging: file-locals used by tests mapped to module exports.
local M = lib
-- TODO(manual): the following were file-locals with no direct export;
-- verify and export or inline as needed: first, letter, out, start, upper

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
	print("[pattern] testing...")

	----------------------------------------------------------------------
	-- find: basic literal matching
	----------------------------------------------------------------------
	test("find literal substring", function()
		local st, en = M.find("hello world", "world")
		assert(st == 7 and en == 11)
	end)

	test("find literal at start", function()
		local st, en = M.find("hello", "hel")
		assert(st == 1 and en == 3)
	end)

	test("find literal at end", function()
		local st, en = M.find("hello", "llo")
		assert(st == 3 and en == 5)
	end)

	test("find literal no match", function()
		local st, en = M.find("hello", "xyz")
		assert(st == nil and en == nil)
	end)

	test("find empty pattern", function()
		local st, en = M.find("hello", "")
		assert(st == 1 and en == 0)
	end)

	test("find empty string in empty string", function()
		local st, en = M.find("", "")
		assert(st == 1 and en == 0)
	end)

	test("find pattern longer than string", function()
		local st, en = M.find("hi", "hello")
		assert(st == nil)
	end)

	----------------------------------------------------------------------
	-- find: plain mode
	----------------------------------------------------------------------
	test("find plain mode ignores magic chars", function()
		local st, en = M.find("a.b", "%.", nil, true)
		assert(st == nil)
	end)

	test("find plain mode finds literal dot", function()
		local st, en = M.find("a.b", ".", nil, true)
		assert(st == 2 and en == 2)
	end)

	test("find plain mode with init", function()
		local st, en = M.find("abcabc", "abc", 4, true)
		assert(st == 4 and en == 6)
	end)

	----------------------------------------------------------------------
	-- find: init parameter
	----------------------------------------------------------------------
	test("find with init parameter", function()
		local st, en = M.find("hello", "l", 4)
		assert(st == 4 and en == 4)
	end)

	test("find with init past match", function()
		local st, en = M.find("hello", "hel", 2)
		assert(st == nil)
	end)

	test("find with negative init", function()
		local st, en = M.find("hello", "o", -1)
		assert(st == 5 and en == 5)
	end)

	test("find with init beyond string", function()
		local st, en = M.find("hello", "o", 100)
		assert(st == nil)
	end)

	----------------------------------------------------------------------
	-- find: character classes
	----------------------------------------------------------------------
	test("find dot (any character)", function()
		local st, en = M.find("aXb", ".")
		assert(st == 1 and en == 1)
	end)

	test("find %a (letter)", function()
		local st, en = M.find("123abc456", "%a+")
		assert(st == 4 and en == 6)
	end)

	test("find %d (digit)", function()
		local st, en = M.find("abc123def", "%d+")
		assert(st == 4 and en == 6)
	end)

	test("find %s (whitespace)", function()
		local st, en = M.find("a b\tc", "%s+")
		assert(st == 2 and en == 2)
	end)

	test("find %w (alphanumeric)", function()
		local st, en = M.find("  hello  ", "%w+")
		assert(st == 3 and en == 7)
	end)

	test("find %l (lowercase)", function()
		local st, en = M.find("ABCabc", "%l+")
		assert(st == 4 and en == 6)
	end)

	test("find %u (uppercase)", function()
		local st, en = M.find("ABCabc", "%u+")
		assert(st == 1 and en == 3)
	end)

	test("find %x (hex digit)", function()
		local st, en = M.find("g0gFF", "%x+")
		assert(st == 2 and en == 2)
	end)

	test("find %A (non-letter)", function()
		local st, en = M.find("a1b2", "%A+")
		assert(st == 2 and en == 2)
	end)

	test("find %D (non-digit)", function()
		local st, en = M.find("1abc2", "%D+")
		assert(st == 2 and en == 4)
	end)

	----------------------------------------------------------------------
	-- find: character sets
	----------------------------------------------------------------------
	test("find character set", function()
		local st, en = M.find("axbyc", "[abc]")
		assert(st == 1 and en == 1)
	end)

	test("find negated character set", function()
		local st, en = M.find("axbyc", "[^abc]+")
		assert(st == 2 and en == 2)
	end)

	test("find character range", function()
		local st, en = M.find("hello123", "[0-9]+")
		assert(st == 6 and en == 8)
	end)

	test("find letter range", function()
		local st, en = M.find("123abc456", "[a-z]+")
		assert(st == 4 and en == 6)
	end)

	test("find set with class inside", function()
		local st, en = M.find("1a 2", "[%d%a]+")
		assert(st == 1 and en == 2)
	end)

	----------------------------------------------------------------------
	-- find: quantifiers
	----------------------------------------------------------------------
	test("find star (zero or more, greedy)", function()
		local st, en = M.find("aaa", "a*")
		assert(st == 1 and en == 3)
	end)

	test("find plus (one or more, greedy)", function()
		local st, en = M.find("aaa", "a+")
		assert(st == 1 and en == 3)
	end)

	test("find minus (zero or more, lazy)", function()
		local st, en = M.find("aaa", "a-")
		assert(st == 1 and en == 0)
	end)

	test("find question (zero or one)", function()
		local st, en = M.find("abc", "a?")
		assert(st == 1 and en == 1)
	end)

	test("find plus on no match", function()
		local st, en = M.find("bcd", "a+")
		assert(st == nil)
	end)

	test("find star on no match", function()
		local st, en = M.find("bcd", "a*")
		assert(st == 1 and en == 0)
	end)

	----------------------------------------------------------------------
	-- find: anchors
	----------------------------------------------------------------------
	test("find anchor start", function()
		local st, en = M.find("hello", "^hel")
		assert(st == 1 and en == 3)
	end)

	test("find anchor start no match", function()
		local st, en = M.find("hello", "^ell")
		assert(st == nil)
	end)

	test("find anchor end", function()
		local st, en = M.find("hello", "llo$")
		assert(st == 3 and en == 5)
	end)

	test("find anchor end no match", function()
		local st, en = M.find("hello", "ell$")
		assert(st == nil)
	end)

	test("find anchor both", function()
		local st, en = M.find("hello", "^hello$")
		assert(st == 1 and en == 5)
	end)

	test("find anchor both no match", function()
		local st, en = M.find("hello world", "^hello$")
		assert(st == nil)
	end)

	----------------------------------------------------------------------
	-- find: captures
	----------------------------------------------------------------------
	test("find single capture", function()
		local st, en, cap1 = M.find("hello123world", "(%d+)")
		assert(st == 6 and en == 8)
		assert(cap1 == "123")
	end)

	test("find multiple captures", function()
		local st, en, c1, c2 = M.find("John:30 Jane:25", "(%a+):(%d+)")
		assert(st == 1 and en == 7)
		assert(c1 == "John")
		assert(c2 == "30")
	end)

	test("find capture with surrounding text", function()
		local st, en, c1 = M.find("abc123def", "(%d+)")
		assert(st == 4 and en == 6)
		assert(c1 == "123")
	end)

	test("find position capture", function()
		local st, en, pos = M.find("abc123def", "()%d+")
		assert(st == 4 and en == 6)
		assert(pos == 4)
	end)

	test("find capture returning empty string", function()
		local st, en, c1 = M.find("abc", "()b()")
		assert(st == 2 and en == 2)
		assert(c1 == 2)
	end)

	test("find no captures returns no extra values", function()
		local result = { M.find("hello", "ell") }
		assert(#result == 2)
		assert(result[1] == 2 and result[2] == 4)
	end)

	----------------------------------------------------------------------
	-- find: backreferences
	----------------------------------------------------------------------
	test("find backreference", function()
		local st, en, c1 = M.find("abc abc", "(%a+)%s+%1")
		assert(st == 1 and en == 7)
		assert(c1 == "abc")
	end)

	test("find backreference no match", function()
		local st, en = M.find("abc xyz", "(%a+)%s+%1")
		assert(st == nil)
	end)

	----------------------------------------------------------------------
	-- find: balanced matches (%b)
	----------------------------------------------------------------------
	test("find balanced match", function()
		local st, en = M.find("a(b(c)d)e", "%b()")
		assert(st == 2 and en == 8)
	end)

	test("find balanced match nested", function()
		local st, en = M.find("a(b(c))d", "%b()")
		assert(st == 2 and en == 7)
	end)

	----------------------------------------------------------------------
	-- find: frontier patterns (%f)
	----------------------------------------------------------------------
	test("find frontier pattern", function()
		local st, en = M.find(" hello ", "%f[%w]hel")
		assert(st == 2 and en == 4)
	end)

	----------------------------------------------------------------------
	-- match: basic
	----------------------------------------------------------------------
	test("match returns full match", function()
		local result = M.match("hello123world", "%d+")
		assert(result == "123")
	end)

	test("match returns captures", function()
		local c1, c2 = M.match("John:30 Jane:25", "(%a+):(%d+)")
		assert(c1 == "John")
		assert(c2 == "30")
	end)

	test("match no captures returns substring", function()
		local result = M.match("hello world", "world")
		assert(result == "world")
	end)

	test("match no match returns nil", function()
		local result = M.match("hello", "xyz")
		assert(result == nil)
	end)

	test("match with init", function()
		local result = M.match("abcabc", "abc", 4)
		assert(result == "abc")
	end)

	test("match anchored at start", function()
		local result = M.match("hello", "^hello")
		assert(result == "hello")
	end)

	test("match anchored at start no match", function()
		local result = M.match("world", "^hello")
		assert(result == nil)
	end)

	----------------------------------------------------------------------
	-- gmatch: basic
	----------------------------------------------------------------------
	test("gmatch iterates all matches", function()
		local results = {}
		for m in M.gmatch("one two three", "%a+") do
			results[#results + 1] = m
		end
		assert(#results == 3)
		assert(results[1] == "one")
		assert(results[2] == "two")
		assert(results[3] == "three")
	end)

	test("gmatch with captures", function()
		local results = {}
		for c1, c2 in M.gmatch("a1b2c3", "(%a)(%d)") do
			results[#results + 1] = c1 .. c2
		end
		assert(#results == 3)
		assert(results[1] == "a1")
		assert(results[2] == "b2")
		assert(results[3] == "c3")
	end)

	test("gmatch no matches", function()
		local count = 0
		for m in M.gmatch("12345", "%a+") do
			count = count + 1
		end
		assert(count == 0)
	end)

	test("gmatch empty string", function()
		local count = 0
		for m in M.gmatch("", ".") do
			count = count + 1
		end
		assert(count == 0)
	end)

	test("gmatch anchored pattern yields one match", function()
		local count = 0
		for m in M.gmatch("abcabc", "^abc") do
			count = count + 1
		end
		assert(count == 1)
	end)

	----------------------------------------------------------------------
	-- gsub: basic
	----------------------------------------------------------------------
	test("gsub replaces all occurrences", function()
		local result, count = M.gsub("aabaabaa", "a", "x")
		assert(result == "xxbxxbxx")
		assert(count == 6)
	end)

	test("gsub with limit", function()
		local result, count = M.gsub("aabaabaa", "a", "x", 2)
		assert(result == "xxbaabaa")
		assert(count == 2)
	end)

	test("gsub with zero limit", function()
		local result, count = M.gsub("aaa", "a", "b", 0)
		assert(result == "aaa")
		assert(count == 0)
	end)

	test("gsub with no matches", function()
		local result, count = M.gsub("hello", "xyz", "abc")
		assert(result == "hello")
		assert(count == 0)
	end)

	test("gsub with capture in replacement", function()
		local result = M.gsub("hello world", "(%a+)", "[%1]")
		assert(result == "[hello] [world]")
	end)

	test("gsub with %%0 in replacement", function()
		local result = M.gsub("abc", "(%a+)", "[%0]")
		assert(result == "[abc]")
	end)

	test("gsub with %% literal", function()
		local result = M.gsub("abc", "a", "%%")
		assert(result == "%bc")
	end)

	test("gsub with function replacement", function()
		local result = M.gsub("abc", "%a", function(c)
			return c:upper()
		end)
		assert(result == "ABC")
	end)

	test("gsub with table replacement", function()
		local t = { a = "X", b = "Y", c = "Z" }
		local result = M.gsub("abc", "%a", t)
		assert(result == "XYZ")
	end)

	test("gsub with table replacement using first capture", function()
		local t = { one = "1", two = "2" }
		local result = M.gsub("one two one", "(%a+)", t)
		assert(result == "1 2 1")
	end)

	----------------------------------------------------------------------
	-- Error handling
	----------------------------------------------------------------------
	test("error on malformed pattern (ends with %)", function()
		expect_error(function()
			M.find("abc", "%")
		end, "malformed pattern")
	end)

	test("error on unfinished capture", function()
		expect_error(function()
			M.find("abc", "(abc")
		end, "unfinished capture")
	end)

	test("error on invalid capture index %0", function()
		expect_error(function()
			M.find("abc", "%0")
		end, "invalid capture index")
	end)

	test("error on invalid capture paren", function()
		expect_error(function()
			M.find("abc", "a)b")
		end, "invalid pattern capture")
	end)

	test("error on missing ] in set", function()
		expect_error(function()
			M.find("abc", "[abc")
		end, "malformed pattern")
	end)

	test("error on range out of order", function()
		expect_error(function()
			M.find("abc", "[z-a]")
		end, "range out of order")
	end)

	test("error on missing [ after %f", function()
		expect_error(function()
			M.find("abc", "%fa")
		end, "missing")
	end)

	test("error on missing arguments to %b", function()
		expect_error(function()
			M.find("abc", "%b")
		end, "missing arguments")
	end)

	----------------------------------------------------------------------
	-- Edge cases
	----------------------------------------------------------------------
	test("find in empty string", function()
		local st, en = M.find("", "a")
		assert(st == nil)
	end)

	test("match in empty string", function()
		local result = M.match("", "")
		assert(result == "")
	end)

	test("gsub on empty string", function()
		local result = M.gsub("", "a", "b")
		assert(result == "")
	end)

	test("find multiple quantifiers", function()
		local st, en = M.find("aaaa", "a+a+")
		assert(st == 1 and en == 4)
	end)

	test("find lazy quantifier stops early", function()
		local st, en, c1 = M.find("aababc", "a.-b")
		assert(st == 1 and en == 3)
		assert(c1 == nil)
	end)

	test("find greedy quantifier goes long", function()
		local st, en = M.find("aababc", "a.*b")
		assert(st == 1 and en == 5)
	end)

	test("find nested captures", function()
		local st, en, c1, c2 = M.find("abc123def", "((%a+)(%d+))")
		assert(st == 1 and en == 6)
		assert(c1 == "abc123")
		assert(c2 == "abc")
		assert(c1 ~= nil)
	end)

	test("find capture with quantifier", function()
		local st, en, c1 = M.find("aaa123", "(%a+)")
		assert(st == 1 and en == 3)
		assert(c1 == "aaa")
	end)

	test("gsub with captures in pattern", function()
		local result = M.gsub("hello world", "(%a+)(%s+)(%a+)", "%3%2%1")
		assert(result == "world hello")
	end)

	test("gsub function receives captures", function()
		local result = M.gsub("a1 b2 c3", "(%a)(%d)", function(a, b)
			return b .. a
		end)
		assert(result == "1a 2b 3c")
	end)

	test("find balanced match with nested", function()
		local st, en = M.find("a(b(c)d)e", "%b()")
		assert(st == 2 and en == 8)
	end)

	test("match with complex pattern", function()
		local c1, c2 = M.match("Date: 2024-01-15", "(%d+)-(%d+)-(%d+)")
		assert(c1 == "2024")
		assert(c2 == "01")
	end)

	print(string_format("[pattern] %d/%d tests passed (%d failed)", passed, total, failed))
	assert(failed == 0, string_format("%d test(s) failed", failed))
end
