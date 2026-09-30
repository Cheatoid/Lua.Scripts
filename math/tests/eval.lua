-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for eval.lua.
-- Run from this directory:
--   lua eval.lua
--   luajit eval.lua

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
local lib = require "eval"
local eval = lib.eval or lib

if true then
	local passed, failed = 0, 0

	local function test(expr, expected, strategy)
		strategy = strategy or "shunting_yard"
		local ok, result = pcall(eval, expr, strategy)
		if not ok then
			print(string.format("FAIL %q [%s]: error %s", expr, strategy, result))
			failed = failed + 1
			return
		end
		if math.abs(result - expected) > 1e-9 then
			print(string.format("FAIL %q [%s]: expected %.10g, got %.10g", expr, strategy, expected, result))
			failed = failed + 1
		else
			passed = passed + 1
		end
	end

	local function test_err(expr, expected_pat, strategy)
		strategy = strategy or "shunting_yard"
		local ok, err = pcall(eval, expr, strategy)
		if ok then
			print(string.format("FAIL %q [%s]: expected error, got %.10g", expr, strategy, err))
			failed = failed + 1
		elseif not string.match(err, expected_pat) then
			print(string.format("FAIL %q [%s]: error did not match %q: %s", expr, strategy, expected_pat, err))
			failed = failed + 1
		else
			passed = passed + 1
		end
	end

	-- Basic arithmetic
	test("1 + 2", 3)
	test("2 * 3 + 4", 10)
	test("2 * (3 + 4)", 14)
	test("10 - 3 - 2", 5)
	test("100 / 10 / 2", 5)

	-- Unary operators
	test("-5", -5)
	test("+5", 5)
	test("3 + -2", 1)
	test("3 * -2", -6)
	test("-2^2", -4)
	test("(-2)^2", 4)
	test("2^-2", 0.25)
	test("-(0)", -0)

	-- Right-associative exponentiation
	test("2^3^2", 512) -- 2^(3^2) = 2^9 = 512

	-- Floor division
	test("10 // 3", 3)
	test("10 // -3", -4) -- math.floor(-3.33...) = -4

	-- Constants
	test("pi", math.pi)
	test("huge", math.huge)

	-- Functions
	test("sin(pi / 2)", 1)
	test("abs(-42)", 42)
	test("sqrt(16)", 4)
	test("max(1, 2, 3)", 3)
	test("min(1, 2, 3)", 1)
	test("log(100, 10)", 2)

	-- Number formats
	test("5.", 5)  -- trailing dot
	test(".5", 0.5) -- leading dot
	test("1e3", 1000) -- scientific
	test("1.5e2", 150)
	test(".5e2", 50) -- leading dot + sci
	test("5.e2", 500) -- trailing dot + sci
	test("1.5e-2", 0.015)

	-- Pratt parity
	test("1 + 2", 3, "pratt")
	test("2 * (3 + 4)", 14, "pratt")
	test("-2^2", -4, "pratt")
	test("2^3^2", 512, "pratt")
	test("10 // 3", 3, "pratt")
	test("sin(pi / 2)", 1, "pratt")
	test("max(1, 2, 3)", 3, "pratt")
	test("5.", 5, "pratt")
	test(".5e2", 50, "pratt")

	-- Error cases
	test_err("1 + )", "Mismatched")
	test_err("unknown", "Unknown identifier")
	test_err("abs()", "expects")
	test_err("(1 + 2", "Mismatched")
	test_err("1 + * 2", "prefix position", "pratt")

	print(string.format("\nTests finished: %d passed, %d failed", passed, failed))
end
