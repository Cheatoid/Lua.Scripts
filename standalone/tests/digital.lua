-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for digital.lua.
-- Run from this directory:
--   lua digital.lua
--   luajit digital.lua

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
local lib = require "digital"
-- Bridging: file-locals used by tests mapped to module exports.
local HIGH = lib.HIGH
local LOW = lib.LOW
local binary_to_decimal = lib.binary_to_decimal
local binary_to_number = lib.binary_to_number
local bits_to_number = lib.bits_to_number
local decimal_to_binary = lib.decimal_to_binary
local full_adder = lib.full_adder
local half_adder = lib.half_adder
local number_to_binary = lib.number_to_binary
local number_to_bits = lib.number_to_bits
local ripple_carry_adder = lib.ripple_carry_adder
local NOT = lib.NOT
local AND = lib.AND
local OR = lib.OR
local XOR = lib.XOR
local NAND = lib.NAND
local NOR = lib.NOR
local NXOR = lib.NXOR

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
	local function returns(t, ...)
		if #t ~= select("#", ...) then
			return false
		end
		for i = 1, #t do
			if t[i] ~= select(i, ...) then
				return false
			end
		end
		return true
	end
	print("[digital] testing...")

	-- binary_to_decimal
	test("binary_to_decimal basic", function()
		assert(binary_to_decimal(1, 0, 1) == 5)
	end)

	test("binary_to_decimal single bit", function()
		assert(binary_to_decimal(1) == 1)
	end)

	test("binary_to_decimal all zeros", function()
		assert(binary_to_decimal(0, 0, 0) == 0)
	end)

	-- bits_to_number
	test("bits_to_number basic", function()
		assert(bits_to_number({ 1, 0, 1 }) == 5)
	end)

	test("bits_to_number empty table", function()
		assert(bits_to_number({}) == 0)
	end)

	test("bits_to_number single bit", function()
		assert(bits_to_number({ 1 }) == 1)
	end)

	-- binary_to_number (uses bitwise ops)
	test("binary_to_number basic", function()
		assert(binary_to_number({ 1, 0, 1 }) == 5)
	end)

	test("binary_to_number all ones", function()
		assert(binary_to_number({ 1, 1, 1, 1 }) == 15)
	end)

	-- decimal_to_binary
	test("decimal_to_binary basic", function()
		assert(returns({ decimal_to_binary(5) }, 1, 0, 1))
	end)

	test("decimal_to_binary zero", function()
		assert(decimal_to_binary(0) == 0)
	end)

	test("decimal_to_binary powers of two", function()
		assert(returns({ decimal_to_binary(8) }, 0, 0, 0, 1))
	end)

	-- number_to_bits
	test("number_to_bits basic", function()
		local t = number_to_bits(5)
		assert(#t == 3)
		assert(t[1] == 1 and t[2] == 0 and t[3] == 1)
	end)

	test("number_to_bits zero", function()
		local t = number_to_bits(0)
		assert(#t == 0)
	end)

	-- number_to_binary (uses bitwise ops)
	test("number_to_binary basic", function()
		assert(returns({ number_to_binary(5) }, 1, 0, 1))
	end)

	test("number_to_binary zero", function()
		assert(number_to_binary(0) == 0)
	end)

	-- Basic gates
	test("NOT gate", function()
		assert(NOT(0) == 1)
		assert(NOT(1) == 0)
		assert(NOT(5) == 0)
	end)

	test("AND gate", function()
		assert(AND(0, 0) == 0)
		assert(AND(0, 1) == 0)
		assert(AND(1, 0) == 0)
		assert(AND(1, 1) == 1)
	end)

	test("OR gate", function()
		assert(OR(0, 0) == 0)
		assert(OR(0, 1) == 1)
		assert(OR(1, 0) == 1)
		assert(OR(1, 1) == 1)
	end)

	test("XOR gate", function()
		assert(XOR(0, 0) == 0)
		assert(XOR(0, 1) == 1)
		assert(XOR(1, 0) == 1)
		assert(XOR(1, 1) == 0)
	end)

	test("NAND gate", function()
		assert(NAND(0, 0) == 1)
		assert(NAND(0, 1) == 1)
		assert(NAND(1, 0) == 1)
		assert(NAND(1, 1) == 0)
	end)

	test("NOR gate", function()
		assert(NOR(0, 0) == 1)
		assert(NOR(0, 1) == 0)
		assert(NOR(1, 0) == 0)
		assert(NOR(1, 1) == 0)
	end)

	test("NXOR gate", function()
		assert(NXOR(0, 0) == 1)
		assert(NXOR(0, 1) == 0)
		assert(NXOR(1, 0) == 0)
		assert(NXOR(1, 1) == 1)
	end)

	-- half_adder
	test("half_adder basic", function()
		assert(returns({ half_adder(0, 0) }, 0, 0))
		assert(returns({ half_adder(0, 1) }, 1, 0))
		assert(returns({ half_adder(1, 0) }, 1, 0))
		assert(returns({ half_adder(1, 1) }, 0, 1))
	end)

	-- full_adder
	test("full_adder all combinations", function()
		assert(returns({ full_adder(0, 0, 0) }, 0, 0))
		assert(returns({ full_adder(0, 0, 1) }, 1, 0))
		assert(returns({ full_adder(0, 1, 0) }, 1, 0))
		assert(returns({ full_adder(0, 1, 1) }, 0, 1))
		assert(returns({ full_adder(1, 0, 0) }, 1, 0))
		assert(returns({ full_adder(1, 0, 1) }, 0, 1))
		assert(returns({ full_adder(1, 1, 0) }, 0, 1))
		assert(returns({ full_adder(1, 1, 1) }, 1, 1))
	end)

	-- ripple_carry_adder
	test("ripple_carry_adder 5 + 3 + 6 = 14", function()
		assert(bits_to_number(ripple_carry_adder(5, 3, 6)) == 14)
	end)

	test("ripple_carry_adder 1 + 1 = 2", function()
		assert(bits_to_number(ripple_carry_adder(1, 1)) == 2)
	end)

	test("ripple_carry_adder 0 + 0 = 0", function()
		assert(bits_to_number(ripple_carry_adder(0, 0)) == 0)
	end)

	-- constants
	test("constants LOW and HIGH", function()
		assert(LOW == 0)
		assert(HIGH == 1)
	end)

	print(string_format("[digital] %d/%d tests passed (%d failed)", passed, total, failed))
	assert(failed == 0, string_format("%d test(s) failed", failed))
end
