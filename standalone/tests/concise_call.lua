-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for concise_call.lua.
-- Run from this directory:
--   lua concise_call.lua
--   luajit concise_call.lua

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
local lib = require "concise_call"
-- Bridging: file-locals used by tests mapped to module exports.
local M = lib
local NULL = lib.NULL
-- TODO(manual): the following were file-locals with no direct export;
-- verify and export or inline as needed: allow_extra_positional, call_style, optional, params, s, strict_unknown, validator, value

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
	print("[concise_call] testing...")

	-- M.register basic
	test("register wraps a function", function()
		local add = M.register(function(a, b)
			return a + b
		end, {
			{ "a", "number" },
			{ "b", "number" },
		})
		assert(type(add) == "table")
		assert(M.is_wrapper(add))
	end)

	-- positional call
	test("positional call", function()
		local add = M.register(function(a, b)
			return a + b
		end, {
			{ "a", "number" },
			{ "b", "number" },
		})
		assert(add(2, 3) == 5)
	end)

	-- named call via __call
	test("named call via __call", function()
		local add = M.register(function(a, b)
			return a + b
		end, {
			{ "a", "number" },
			{ "b", "number" },
		})
		assert(add({ a = 2, b = 3 }) == 5)
	end)

	-- explicit .named() method
	test("explicit .named() method", function()
		local add = M.register(function(a, b)
			return a + b
		end, {
			{ "a", "number" },
			{ "b", "number" },
		})
		assert(add.named({ a = 10, b = 20 }) == 30)
	end)

	-- explicit .positional() method
	test("explicit .positional() method", function()
		local add = M.register(function(a, b)
			return a + b
		end, {
			{ "a", "number" },
			{ "b", "number" },
		})
		assert(add.positional(10, 20) == 30)
	end)

	-- .call() method (auto-detect)
	test(".call() method auto-detect", function()
		local add = M.register(function(a, b)
			return a + b
		end, {
			{ "a", "number" },
			{ "b", "number" },
		})
		assert(add.call(2, 3) == 5)
		assert(add.call({ a = 2, b = 3 }) == 5)
	end)

	-- type validation: correct type passes
	test("correct type passes", function()
		local fn = M.register(function(x)
			return x
		end, { { "x", "string" } })
		assert(fn("hello") == "hello")
	end)

	-- type validation: wrong type errors
	test("wrong type errors", function()
		local fn = M.register(function(x)
			return x
		end, { { "x", "string" } })
		expect_error(function()
			fn(123)
		end, "expected string")
	end)

	-- type validation: nil for required errors
	test("nil for required errors", function()
		local fn = M.register(function(x)
			return x
		end, { { "x", "string" } })
		expect_error(function()
			fn()
		end, "missing")
	end)

	-- optional parameter
	test("optional parameter", function()
		local fn = M.register(function(a, b)
			return a + (b or 0)
		end, {
			{ "a", "number" },
			{ "b", "number", true },
		})
		assert(fn(5) == 5)
		assert(fn(5, 3) == 8)
	end)

	-- optional named parameter
	test("optional named parameter", function()
		local fn = M.register(function(a, b)
			return a + (b or 0)
		end, {
			{ "a", "number" },
			{ "b", "number", true },
		})
		assert(fn({ a = 5 }) == 5)
		assert(fn({ a = 5, b = 3 }) == 8)
	end)

	-- default value
	test("default value", function()
		local fn = M.register(function(a, b)
			return a + b
		end, {
			{ "a", "number" },
			{ "b", "number", false, 10 },
		})
		assert(fn(5) == 15)
		assert(fn(5, 3) == 8)
	end)

	-- default value with named call
	test("default value with named call", function()
		local fn = M.register(function(a, b)
			return a + b
		end, {
			{ "a", "number" },
			{ "b", "number", false, 10 },
		})
		assert(fn({ a = 5 }) == 15)
	end)

	-- M.NULL sentinel for explicit nil
	test("M.NULL sentinel for explicit nil", function()
		local fn = M.register(function(a, b)
			return a, b
		end, {
			{ "a", "number" },
			{ "b", "number", true },
		})
		local x, y = fn({ a = 1, b = M.NULL })
		assert(x == 1)
		assert(y == nil)
	end)

	-- union type spec (table of types)
	test("union type spec", function()
		local fn = M.register(function(x)
			return type(x)
		end, { { "x", { "string", "number" } } })
		assert(fn("hello") == "string")
		assert(fn(42) == "number")
		expect_error(function()
			fn(true)
		end, "expected")
	end)

	-- custom validator
	test("custom validator", function()
		local fn = M.register(function(x)
			return x
		end, {
			{
				"x",
				"number",
				validator = function(v)
					return v > 0
				end,
			},
		})
		assert(fn(5) == 5)
		expect_error(function()
			fn(-1)
		end, "validator")
	end)

	-- call_style "named" forces named mode
	test("call_style 'named' forces named mode", function()
		local fn = M.register(function(a, b)
			return a + b
		end, {
			{ "a", "number" },
			{ "b", "number" },
		}, { call_style = "named" })
		assert(fn({ a = 2, b = 3 }) == 5)
		expect_error(function()
			fn(2, 3)
		end, "named call expects")
	end)

	-- call_style "positional" forces positional mode
	test("call_style 'positional' forces positional mode", function()
		local fn = M.register(function(a, b)
			return a + b
		end, {
			{ "a", "number" },
			{ "b", "number" },
		}, { call_style = "positional" })
		assert(fn(2, 3) == 5)
		expect_error(function()
			fn({ a = 2, b = 3 })
		end, "expected number")
	end)

	-- strict_unknown rejects unknown named args
	test("strict_unknown rejects unknown named args", function()
		local fn = M.register(function(a)
			return a
		end, {
			{ "a", "number" },
		}, { strict_unknown = true })
		expect_error(function()
			fn({ a = 1, z = 99 })
		end, "unknown named argument")
	end)

	-- strict_unknown = false allows unknown named args
	test("strict_unknown = false allows unknown named args", function()
		local fn = M.register(function(a)
			return a
		end, {
			{ "a", "number" },
		}, { strict_unknown = false })
		assert(fn({ a = 1, z = 99 }) == 1)
	end)

	-- allow_extra_positional
	test("allow_extra_positional", function()
		local args = {}
		local fn = M.register(function(a, b)
			args.a = a
			args.b = b
		end, {
			{ "a", "number" },
			{ "b", "number" },
		}, { allow_extra_positional = true })
		fn(1, 2, 3, 4)
		assert(args.a == 1)
		assert(args.b == 2)
	end)

	-- too many positional args without allow_extra_positional
	test("too many positional args without allow_extra_positional", function()
		local fn = M.register(function(a, b)
			return a + b
		end, {
			{ "a", "number" },
			{ "b", "number" },
		})
		expect_error(function()
			fn(1, 2, 3)
		end, "too many positional arguments")
	end)

	-- empty signature (no params)
	test("empty signature (no params)", function()
		local fn = M.register(function()
			return 42
		end)
		assert(fn() == 42)
		assert(fn({}) == 42)
	end)

	-- object-style signature entries
	test("object-style signature entries", function()
		local fn = M.register(function(x)
			return x * 2
		end, {
			{ name = "x", type = "number" },
		})
		assert(fn(5) == 10)
		assert(fn({ x = 5 }) == 10)
	end)

	-- M.signature_of retrieves signature
	test("M.signature_of retrieves signature", function()
		local fn = M.register(function(a, b)
			return a + b
		end, {
			{ "a", "number" },
			{ "b", "number" },
		})
		local sig = M.signature_of(fn)
		assert(type(sig) == "table")
		assert(#sig == 2)
		assert(sig[1].name == "a")
		assert(sig[2].name == "b")
	end)

	-- M.is_wrapper returns false for non-wrappers
	test("M.is_wrapper returns false for non-wrappers", function()
		assert(M.is_wrapper(function() end) == false)
		assert(M.is_wrapper({}) == false)
		assert(M.is_wrapper(42) == false)
		assert(M.is_wrapper(nil) == false)
	end)

	-- __concise_original stores original function
	test("__concise_original stores original function", function()
		local function add(a, b) return a + b end
		local w = M.register(add, {
			{ "a", "number" },
			{ "b", "number" },
		})
		assert(w.__concise_original == add)
	end)

	-- __concise_name stores name
	test("__concise_name stores name", function()
		local w = M.register(function() end, {}, { name = "my_func" })
		assert(w.__concise_name == "my_func")
	end)

	-- opts.name validation
	test("opts.name must be non-empty string", function()
		expect_error(function()
			M.register(function() end, {}, { name = "" })
		end, "non-empty string")
		expect_error(function()
			M.register(function() end, {}, { name = 123 })
		end, "non-empty string")
	end)

	-- register validates fn is a function
	test("register validates fn is a function", function()
		expect_error(function()
			M.register("not a function")
		end, "first argument must be a function")
	end)

	-- register validates signature is a table
	test("register validates signature is a table", function()
		expect_error(function()
			M.register(function() end, "bad")
		end, "signature must be a table or nil")
	end)

	-- register validates opts is a table
	test("register validates opts is a table", function()
		expect_error(function()
			M.register(function() end, {}, "bad")
		end, "opts must be a table")
	end)

	-- duplicate parameter names error
	test("duplicate parameter names error", function()
		expect_error(function()
			M.register(function() end, {
				{ "x", "number" },
				{ "x", "string" },
			})
		end, "duplicate parameter name")
	end)

	-- named call with non-table errors
	test("named call with non-table errors", function()
		local fn = M.register(function(a)
			return a
		end, { { "a", "number" } })
		expect_error(function()
			fn.named("bad")
		end, "named arguments must be a table")
	end)

	-- named call with 2+ args errors in auto mode
	test("named call with 2+ args errors in auto mode", function()
		local fn = M.register(function(a)
			return a
		end, { { "a", "number" } })
		expect_error(function()
			fn(1, 2)
		end, "too many positional arguments")
	end)

	-- error messages include function name
	test("error messages include function name", function()
		local fn = M.register(function(x)
			return x
		end, { { "x", "number" } }, { name = "my_func" })
		expect_error(function()
			fn("bad")
		end, "my_func")
	end)

	-- string type spec "integer"
	test("integer type spec", function()
		local fn = M.register(function(x)
			return x
		end, { { "x", "integer" } })
		assert(fn(5) == 5)
		assert(fn(5.0) == 5)
		expect_error(function()
			fn(5.5)
		end, "expected integer")
	end)

	print(string_format("[concise_call] %d/%d tests passed (%d failed)", passed, total, failed))
	assert(failed == 0, string_format("%d test(s) failed", failed))
end
