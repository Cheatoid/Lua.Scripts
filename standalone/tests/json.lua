-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for json.lua.
-- Run from this directory:
--   lua json.lua
--   luajit json.lua

-- Bootstrap: make requires work from tests/ subdir with plain lua/luajit.
do
  local src = debug.getinfo(1, "S").source
  local dir = src:match("^@(.+/)[^/]+$") or "./"
  local function isfile(p)
    local f = io.open(p, "r")
    if f then f:close() return true end
    return false
  end
  local root
  for _, c in ipairs({ dir, dir .. "../", dir .. "../..//", dir .. "../../..//", "./", "../", "../../" }) do
    if isfile(c .. "standalone/bits.lua") then root = c break end
  end
  root = root or dir .. "../"
  if package then
    package.path = dir .. "../?.lua;" .. dir .. "../?/init.lua;" .. dir .. "?.lua;" .. dir .. "?/init.lua;" .. root .. "?.lua;" .. root .. "?/init.lua;" .. root .. "standalone/?.lua;" .. root .. "math/?.lua;" .. root .. "collections/?.lua;" .. root .. "benchmark/?.lua;" .. root .. "timer/?.lua;" .. root .. "autocompleter/?.lua;" .. root .. "permission/?.lua;" .. root .. "chat_commander/?.lua;" .. root .. "vm/?.lua;" .. root .. "require_finder/?.lua;" .. root .. "inventory/?.lua;" .. package.path
  end
  local searchers = package.searchers or package.loaders
  if searchers then
    table.insert(searchers, 2, function(mod)
      if mod:sub(1, 3) == "../" or mod:sub(1, 2) == "./" then
        local clean = mod:gsub("^%./", ""):gsub("^%.%.%/", ""):gsub("^%.%.%/", "")
        local tries = { dir .. "../" .. clean .. ".lua", dir .. "../" .. clean .. "/init.lua", root .. clean .. ".lua", root .. clean .. "/init.lua" }
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
local lib = require "json"
-- Bridging: file-locals used by tests mapped to module exports.
local json = lib
local Json = lib.Json
local string_char = string.char
local string_format = string.format
-- TODO(manual): the following were file-locals with no direct export;
-- verify and export or inline as needed: allow_comments, c, e, key, keys, max, max_depth, n, null, pretty, sort_keys, tag, tb

if true then
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
	local function deep_equal(a, b)
		if a == b then return true end
		if type(a) ~= "table" or type(b) ~= "table" then return false end
		for k, v in next, a do
			if not deep_equal(v, b[k]) then return false end
		end
		for k, v in next, b do
			if a[k] == nil then return false end
		end
		return true
	end
	print("[json] testing...")

	-- Primitives
	test("encode/decode nil", function()
		local enc = Json.new()
		assert(enc:decode(enc:encode(nil)) == json.null)
		assert(enc:encode(nil) == "null")
		assert(enc:decode("null") == json.null)
	end)

	test("encode/decode true", function()
		local enc = Json.new()
		assert(enc:decode(enc:encode(true)) == true)
		assert(enc:encode(true) == "true")
	end)

	test("encode/decode false", function()
		local enc = Json.new()
		assert(enc:decode(enc:encode(false)) == false)
		assert(enc:encode(false) == "false")
	end)

	test("encode/decode integer", function()
		local enc = Json.new()
		assert(enc:decode(enc:encode(42)) == 42)
		assert(enc:encode(42) == "42")
	end)

	test("encode/decode negative integer", function()
		local enc = Json.new()
		assert(enc:decode(enc:encode(-7)) == -7)
		assert(enc:encode(-7) == "-7")
	end)

	test("encode/decode zero", function()
		local enc = Json.new()
		assert(enc:decode(enc:encode(0)) == 0)
		assert(enc:encode(0) == "0")
	end)

	test("encode/decode float", function()
		local enc = Json.new()
		local v = enc:decode(enc:encode(3.14))
		assert(math.abs(v - 3.14) < 1e-15)
	end)

	test("encode/decode scientific notation number", function()
		local enc = Json.new()
		assert(enc:decode(enc:encode(1e10)) == 1e10)
		assert(enc:decode(enc:encode(1.5e-3)) == 1.5e-3)
	end)

	test("encode/decode empty string", function()
		local enc = Json.new()
		assert(enc:decode(enc:encode("")) == "")
		assert(enc:encode("") == '""')
	end)

	test("encode/decode string", function()
		local enc = Json.new()
		assert(enc:decode(enc:encode("hello")) == "hello")
		assert(enc:encode("hello") == '"hello"')
	end)

	-- String escaping
	test("escape backslash", function()
		local enc = Json.new()
		assert(enc:encode("a\\b") == '"a\\\\b"')
		assert(enc:decode('"a\\\\b"') == "a\\b")
	end)

	test("escape quotes", function()
		local enc = Json.new()
		assert(enc:encode('say "hi"') == '"say \\"hi\\""')
		assert(enc:decode('"say \\"hi\\""') == 'say "hi"')
	end)

	test("escape newline", function()
		local enc = Json.new()
		assert(enc:encode("a\nb") == '"a\\nb"')
		assert(enc:decode('"a\\nb"') == "a\nb")
	end)

	test("escape tab", function()
		local enc = Json.new()
		assert(enc:encode("a\tb") == '"a\\tb"')
		assert(enc:decode('"a\\tb"') == "a\tb")
	end)

	test("escape carriage return", function()
		local enc = Json.new()
		assert(enc:encode("a\rb") == '"a\\rb"')
		assert(enc:decode('"a\\rb"') == "a\rb")
	end)

	test("escape backspace", function()
		local enc = Json.new()
		assert(enc:encode("a\bb") == '"a\\bb"')
		assert(enc:decode('"a\\bb"') == "a\bb")
	end)

	test("escape form feed", function()
		local enc = Json.new()
		assert(enc:encode("a\fb") == '"a\\fb"')
		assert(enc:decode('"a\\fb"') == "a\fb")
	end)

	test("escape control character via \\u", function()
		local enc = Json.new()
		-- 0x01 is a control character, encoded as \u0001
		assert(enc:encode(string_char(1)) == '"\\u0001"')
		assert(enc:decode('"\\u0001"') == string_char(1))
	end)

	test("decode unicode \\u escape (ASCII range)", function()
		local enc = Json.new()
		assert(enc:decode('"\\u0041"') == "A")
	end)

	test("decode unicode \\u escape (2-byte UTF-8)", function()
		local enc = Json.new()
		-- U+00E9 = e-acute, encoded as \u00e9
		assert(enc:decode('"\\u00e9"') == "\xc3\xa9")
	end)

	test("decode unicode \\u escape (3-byte UTF-8)", function()
		local enc = Json.new()
		-- U+4E16 = CJK character, encoded as \u4e16
		assert(enc:decode('"\\u4e16"') == "\xe4\xb8\x96")
	end)

	test("decode surrogate pair", function()
		local enc = Json.new()
		-- U+1F600 (grinning face) encoded as surrogate pair
		assert(enc:decode('"\\uD83D\\uDE00"') == "\xf0\x9f\x98\x80")
	end)

	test("decode solidus escape", function()
		local enc = Json.new()
		assert(enc:decode('"a\\/b"') == "a/b")
	end)

	-- Empty containers
	test("encode/decode empty object", function()
		local enc = Json.new()
		local r = enc:decode(enc:encode({}))
		assert(type(r) == "table")
		assert(next(r) == nil)
	end)

	test("encode/decode empty array", function()
		local enc = Json.new()
		local r = enc:decode(enc:encode({}))
		assert(type(r) == "table")
		assert(next(r) == nil)
	end)

	-- Objects
	test("encode/decode flat object", function()
		local enc = Json.new()
		local r = enc:decode(enc:encode({ a = 1, b = "two" }))
		assert(r.a == 1)
		assert(r.b == "two")
	end)

	test("encode/decode nested object", function()
		local enc = Json.new()
		local r = enc:decode(enc:encode({ a = { b = { c = 42 } } }))
		assert(r.a.b.c == 42)
	end)

	-- Arrays
	test("encode/decode flat array", function()
		local enc = Json.new()
		local r = enc:decode(enc:encode({ 1, 2, 3 }))
		assert(#r == 3)
		assert(r[1] == 1 and r[2] == 2 and r[3] == 3)
	end)

	test("encode/decode nested array", function()
		local enc = Json.new()
		local r = enc:decode(enc:encode({ { 1, 2 }, { 3, 4 } }))
		assert(r[1][1] == 1 and r[1][2] == 2)
		assert(r[2][1] == 3 and r[2][2] == 4)
	end)

	test("encode/decode mixed object and array", function()
		local enc = Json.new()
		local r = enc:decode(enc:encode({ list = { 10, 20 }, name = "test" }))
		assert(r.name == "test")
		assert(#r.list == 2 and r.list[1] == 10 and r.list[2] == 20)
	end)

	-- Pretty printing
	test("pretty print compact", function()
		local enc = Json.new({ pretty = false })
		local s = enc:encode({ a = 1 })
		assert(s == '{"a":1}')
	end)

	test("pretty print enabled", function()
		local enc = Json.new({ pretty = true })
		local s = enc:encode({ a = 1 })
		assert(s:find("\n"))
		assert(s:find("  ")) -- default indent
	end)

	test("pretty print custom indent", function()
		local enc = Json.new({ pretty = true, indent = "\t" })
		local s = enc:encode({ a = 1 })
		assert(s:find("\t"))
	end)

	-- Sorted keys
	test("sorted keys", function()
		local enc = Json.new({ sort_keys = true })
		local s = enc:encode({ c = 3, a = 1, b = 2 })
		assert(s == '{"a":1,"b":2,"c":3}')
	end)

	-- Allow comments
	test("decode with line comments", function()
		local enc = Json.new({ allow_comments = true })
		local r = enc:decode('{\n// comment\n"a": 1\n}')
		assert(r.a == 1)
	end)

	test("decode with block comments", function()
		local enc = Json.new({ allow_comments = true })
		local r = enc:decode('{"a": /* inline */ 1}')
		assert(r.a == 1)
	end)

	test("decode rejects comments by default", function()
		local enc = Json.new()
		expect_error(function() enc:decode('{"a": // bad\n1}') end, "unexpected byte")
	end)

	-- NaN
	test("encode NaN as null (default)", function()
		local enc = Json.new()
		assert(enc:encode(0 / 0) == "null")
	end)

	test("decode NaN-encoded null is json.null", function()
		local enc = Json.new()
		assert(enc:decode("null") == json.null)
	end)

	test("encode NaN throws when encode_nan_as_null is false", function()
		local enc = Json.new({ encode_nan_as_null = false })
		expect_error(function() enc:encode(0 / 0) end, "NaN")
	end)

	-- Infinity
	test("encode Infinity as 1e999 (default)", function()
		local enc = Json.new()
		assert(enc:encode(math.huge) == "1e999")
		assert(enc:encode(-math.huge) == "-1e999")
	end)

	test("encode Infinity as string", function()
		local enc = Json.new({ encode_inf_as_str = true })
		assert(enc:encode(math.huge) == '"Infinity"')
		assert(enc:encode(-math.huge) == '"-Infinity"')
	end)

	-- max_depth encoding
	test("max_depth encode success within limit", function()
		local enc = Json.new({ max_depth = 3 })
		enc:encode({ a = { b = { c = 1 } } })
	end)

	test("max_depth encode failure exceeds limit", function()
		local enc = Json.new({ max_depth = 2 })
		expect_error(function() enc:encode({ a = { b = { c = 1 } } }) end, "max depth 2 exceeded")
	end)

	test("max_depth encode failure on depth 1 with max_depth 1", function()
		local enc = Json.new({ max_depth = 1 })
		expect_error(function() enc:encode({ a = { b = 1 } }) end, "max depth 1 exceeded")
	end)

	test("max_depth encode success for empty nested at limit", function()
		local enc = Json.new({ max_depth = 2 })
		enc:encode({ a = {}, b = {} })
	end)

	test("max_depth encode arrays", function()
		local enc = Json.new({ max_depth = 2 })
		enc:encode({ { 1, 2 } })
		expect_error(function() enc:encode({ { { 1 } } }) end, "max depth 2 exceeded")
	end)

	-- max_depth decoding
	test("max_depth decode success within limit", function()
		local enc = Json.new({ max_depth = 3 })
		enc:decode('{"a":{"b":{"c":1}}}')
	end)

	test("max_depth decode failure exceeds limit", function()
		local enc = Json.new({ max_depth = 2 })
		expect_error(function() enc:decode('{"a":{"b":{"c":1}}}') end, "max depth 2 exceeded")
	end)

	test("max_depth decode arrays", function()
		local enc = Json.new({ max_depth = 2 })
		enc:decode("[[1,2]]")
		expect_error(function() enc:decode("[[[1]]]") end, "max depth 2 exceeded")
	end)

	test("max_depth decode mixed containers", function()
		local enc = Json.new({ max_depth = 2 })
		enc:decode('{"a":[1,2]}')
		expect_error(function() enc:decode('{"a":[{"b":1}]}') end, "max depth 2 exceeded")
	end)

	-- max_depth with no limit
	test("no max_depth allows deep nesting", function()
		local enc = Json.new()
		local deep = { a = { b = { c = { d = { e = { f = 1 } } } } } }
		local r = enc:decode(enc:encode(deep))
		assert(r.a.b.c.d.e.f == 1)
	end)

	-- Convenience functions
	test("convenience encode/decode", function()
		local r = json.decode(json.encode({ x = 10 }))
		assert(r.x == 10)
	end)

	test("convenience encode with options", function()
		local r = json.decode(json.encode({ x = 1 }, { sort_keys = true }), { sort_keys = true })
		assert(r.x == 1)
	end)

	test("convenience decode with options", function()
		local r = json.decode('{"a":// comment\n1}', { allow_comments = true })
		assert(r.a == 1)
	end)

	-- Custom converters
	test("custom converter with tag roundtrip", function()
		local j = Json.new()
		local Point = {}
		Point.__index = Point
		function Point.new(x, y) return setmetatable({ x = x, y = y }, Point) end

		j:add_converter({
			name       = "Point",
			tag        = "Point",
			priority   = 60,
			can_encode = function(_, v) return getmetatable(v) == Point end,
			encode     = function(_, v) return { x = v.x, y = v.y } end,
			decode     = function(_, obj) return Point.new(obj.value.x, obj.value.y) end,
		})
		local p = Point.new(3, 4)
		local r = j:decode(j:encode(p))
		assert(getmetatable(r) == Point)
		assert(r.x == 3 and r.y == 4)
	end)

	test("custom converter without tag", function()
		local j = Json.new()
		j:add_converter({
			name       = "binary",
			priority   = 60,
			can_encode = function(_, v) return type(v) == "string" and v:byte(1) == 0 end,
			encode     = function(_, v) return #v end,
		})
		-- Binary string encodes to its length as a number
		assert(j:encode(string_char(0, 1, 2)) == "3")
	end)

	test("remove_converter", function()
		local j = Json.new()
		j:add_converter({ name = "test_conv", can_encode = function() return false end })
		assert(j:remove_converter("test_conv") == true)
		assert(j:remove_converter("nonexistent") == false)
	end)

	-- __jsontype metatable
	test("__jsontype array hint", function()
		local t = setmetatable({ [1] = "a", [2] = "b", foo = "c" }, { __jsontype = "array" })
		local enc = Json.new()
		-- Should be treated as array, only integer keys 1..2 are serialized
		local r = enc:decode(enc:encode(t))
		assert(#r == 2)
		assert(r[1] == "a" and r[2] == "b")
	end)

	test("__jsontype object hint", function()
		local t = setmetatable({ [1] = "a", [2] = "b" }, { __jsontype = "object" })
		local enc = Json.new()
		local s = enc:encode(t)
		assert(s:find('"1"'))
		assert(s:find('"2"'))
	end)

	-- Number encoding edge cases
	test("encode large integer without scientific notation", function()
		local enc = Json.new()
		local s = enc:encode(999999999999)
		assert(s == "999999999999")
	end)

	test("encode small integer zero", function()
		local enc = Json.new()
		assert(enc:encode(0) == "0")
	end)

	test("encode negative zero", function()
		local enc = Json.new()
		-- -0 in Lua is 0, encodes as 0
		assert(enc:encode(-0) == "0")
	end)

	-- Decoder error cases
	test("decode trailing characters", function()
		local enc = Json.new()
		expect_error(function() enc:decode('1 extra') end, "trailing characters")
	end)

	test("decode unterminated string", function()
		local enc = Json.new()
		expect_error(function() enc:decode('"unterminated') end, "unterminated string")
	end)

	test("decode invalid escape", function()
		local enc = Json.new()
		expect_error(function() enc:decode('"\\x"') end, "invalid escape")
	end)

	test("decode unterminated block comment", function()
		local enc = Json.new({ allow_comments = true })
		expect_error(function() enc:decode('/* unterminated') end, "unterminated block comment")
	end)

	test("decode unexpected byte", function()
		local enc = Json.new()
		expect_error(function() enc:decode('}') end, "unexpected byte")
	end)

	test("decode expected colon", function()
		local enc = Json.new()
		expect_error(function() enc:decode('{"a" 1}') end, "expected ':'")
	end)

	test("decode expected string key", function()
		local enc = Json.new()
		expect_error(function() enc:decode('{1: 1}') end, "expected string key")
	end)

	test("decode unterminated array", function()
		local enc = Json.new()
		expect_error(function() enc:decode('[1') end, "unterminated array")
	end)

	test("decode unterminated object", function()
		local enc = Json.new()
		expect_error(function() enc:decode('{"a":1') end, "unterminated object")
	end)

	test("decode invalid number", function()
		local enc = Json.new()
		expect_error(function() enc:decode('.') end, "unexpected byte")
	end)

	test("decode expects string", function()
		local enc = Json.new()
		expect_error(function() enc:decode(123) end, "expects a string")
	end)

	-- Encoder error cases
	test("encode function errors", function()
		local enc = Json.new()
		expect_error(function() enc:encode(function() end) end, "no converter")
	end)

	test("encode thread errors", function()
		local enc = Json.new()
		expect_error(function() enc:encode(coroutine.create(function() end)) end, "no converter")
	end)

	-- Deep equal helper and complex roundtrip
	test("complex nested structure roundtrip", function()
		local enc = Json.new({ sort_keys = true })
		local data = {
			name = "test",
			numbers = { 1, 2, 3 },
			nested = {
				flag = true,
				nothing = nil,
				list = { "a", "b" },
			},
		}
		local r = enc:decode(enc:encode(data))
		assert(r.name == "test")
		assert(#r.numbers == 3 and r.numbers[1] == 1)
		assert(r.nested.flag == true)
		assert(r.nested.nothing == nil)
		assert(#r.nested.list == 2 and r.nested.list[1] == "a")
	end)

	test("all values roundtrip via deep_equal", function()
		local enc = Json.new()
		local data = {
			[1] = 1,
			[2] = "two",
			[3] = true,
			[4] = false,
			[5] = { 10, 20, { 30 } },
			[6] = { x = 1, y = { z = "deep" } },
		}
		local r = enc:decode(enc:encode(data))
		assert(deep_equal(data, r))
	end)

	-- Multiple encode/decode cycles (stability)
	test("double roundtrip stability", function()
		local enc = Json.new()
		local data = { a = { b = { c = 1 } }, d = { 2, 3 } }
		local s1 = enc:encode(data)
		local r1 = enc:decode(s1)
		local s2 = enc:encode(r1)
		local r2 = enc:decode(s2)
		assert(deep_equal(r1, r2))
		assert(s1 == s2)
	end)

	print(string_format("[json] %d/%d tests passed (%d failed)", passed, total, failed))
	assert(failed == 0, string_format("%d test(s) failed", failed))
end
