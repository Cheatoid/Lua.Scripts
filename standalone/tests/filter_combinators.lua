-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for filter_combinators.lua.
-- Run from this directory:
--   lua filter_combinators.lua
--   luajit filter_combinators.lua

-- Bootstrap: shared test bootstrap (see ../../.tools/bootstrap.lua).
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
	local boot
	for _, c in ipairs({
		dir .. "../../.tools/bootstrap.lua",
		dir .. "../.tools/bootstrap.lua",
		dir .. "../../../.tools/bootstrap.lua",
		"./.tools/bootstrap.lua",
		"../.tools/bootstrap.lua",
		"../../.tools/bootstrap.lua",
	}) do
		if isfile(c) then
			boot = c
			break
		end
	end
	assert(boot, "cheatoid test bootstrap not found (.tools/bootstrap.lua)")
	assert(dofile(boot))(dir)
end
local lib = require "filter_combinators"
-- Bridging: file-locals used by tests mapped to module exports.
local All = lib.All
local And = lib.And
local Any = lib.Any
local NoneOf = lib.NoneOf
local Not = lib.Not
local OneOf = lib.OneOf
local Or = lib.Or
local new = lib.new

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
	local function is_even()
		return {
			filter = function(self, item)
				return item % 2 == 0
			end
		}
	end
	local function is_positive()
		return {
			filter = function(self, item)
				return item > 0
			end
		}
	end
	local function is_small()
		return {
			filter = function(self, item)
				return item < 10
			end
		}
	end
	print("[filter_combinators] testing...")

	-- And
	test("And basic", function()
		local f = And(is_even(), is_positive())
		assert(f:filter(4) == true)
		assert(f:filter(-4) == false)
		assert(f:filter(3) == false)
	end)

	-- Or
	test("Or basic", function()
		local f = Or(is_even(), is_positive())
		assert(f:filter(4) == true)
		assert(f:filter(3) == true)
		assert(f:filter(-4) == true)
		assert(f:filter(-3) == false)
	end)

	-- Not
	test("Not basic", function()
		local f = Not(is_even())
		assert(f:filter(3) == true)
		assert(f:filter(4) == false)
	end)

	-- All
	test("All basic", function()
		local f = All(is_even(), is_positive(), is_small())
		assert(f:filter(4) == true)
		assert(f:filter(12) == false)
		assert(f:filter(-4) == false)
		assert(f:filter(3) == false)
	end)

	-- Any / Some
	test("Any basic", function()
		local f = Any(is_even(), is_positive())
		assert(f:filter(4) == true)
		assert(f:filter(3) == true)
		assert(f:filter(-3) == false)
	end)

	test("Some is alias of Any", function()
		local f = new(is_even()):Some(is_positive())
		assert(f:filter(3) == true)
		assert(f:filter(-3) == false)
	end)

	-- OneOf
	test("OneOf basic", function()
		local f = OneOf(is_even(), is_small())
		assert(f:filter(4) == false) -- both match
		assert(f:filter(3) == true) -- only is_small matches
		assert(f:filter(12) == true) -- only is_even matches
		assert(f:filter(11) == false) -- neither matches
	end)

	-- NoneOf
	test("NoneOf basic", function()
		local f = NoneOf(is_even(), is_positive())
		assert(f:filter(-3) == true)
		assert(f:filter(4) == false)
		assert(f:filter(3) == false)
	end)

	-- Fluent wrapper
	test("fluent And/Or/Not chaining", function()
		local f = new(is_even()):And(is_positive())
		assert(f:filter(4) == true)
		assert(f:filter(-4) == false)
		local g = new(is_even()):Or(is_positive())
		assert(g:filter(-3) == false)
		assert(g:filter(3) == true)
		local h = new(is_even()):Not()
		assert(h:filter(3) == true)
		assert(h:filter(4) == false)
	end)

	test("fluent variadic All/Any/OneOf/NoneOf", function()
		assert(new(is_even()):All(is_positive(), is_small()):filter(4) == true)
		assert(new(is_even()):All(is_positive(), is_small()):filter(12) == false)
		assert(new(is_even()):Any(is_positive()):filter(3) == true)
		assert(new(is_even()):OneOf(is_small()):filter(4) == false)
		assert(new(is_even()):NoneOf(is_positive()):filter(-3) == true)
	end)

	test("fluent chains return new wrappers", function()
		local base = new(is_even())
		local chained = base:And(is_positive())
		assert(chained ~= base)
		assert(chained:filter(4) == true)
		assert(base:filter(3) == false) -- base is unchanged
	end)

	print(string_format("[filter_combinators] %d/%d tests passed (%d failed)", passed, total, failed))
	assert(failed == 0, string_format("%d test(s) failed", failed))
end
