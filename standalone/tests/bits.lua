-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for bits.lua.
-- Run from this directory:
--   lua bits.lua
--   luajit bits.lua

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
local lib = require "bits"
-- Bridging: file-locals used by tests mapped to module exports.
local bits = lib
local string_format = string.format
local string_sub = string.sub
local bin64_to_double = lib.bin64_to_double
local bit = lib.bit
local double_to_bin64 = lib.double_to_bin64
local double_to_int32_high_fast = lib.double_to_int32_high_fast
local double_to_int32_low_fast = lib.double_to_int32_low_fast
local double_to_uint32_high = lib.double_to_uint32_high
local double_to_uint32_low = lib.double_to_uint32_low
local get_required_bits = lib.get_required_bits
local hex32 = lib.hex32
local pretty_double_bin = lib.pretty_double_bin
local to_u32_fast = lib.to_u32_fast
local bit_tobit = lib.tobit
local bit_band = lib.band
local bit_bor = lib.bor
local bit_lshift = lib.lshift
local bit_rshift = lib.rshift
local bit_bnot = lib.bnot
local bit_bxor = lib.bxor
-- TODO(manual): the following were file-locals with no direct export;
-- verify and export or inline as needed: bin64_to_double, double_to_bin64, double_to_int32_high_fast, double_to_int32_low_fast, double_to_uint32_high, double_to_uint32_low, hex32, pretty_double_bin, to_u32_fast

if true then
	local U32MASK = 0xFFFFFFFF
	local TWO51 = 2 ^ 51
	-- Example round-trip using the pretty printer
	print("real pi", math.pi) -- 3.1415926535898
	local b = pretty_double_bin(3.141592)
	local x = bin64_to_double(b)
	print("pret pi", b, x)
	local expb = "0 10000000000 1001001000011111101011111100100010110000000001111010"
	print("expe b", expb, b == expb)
	assert(string_sub(tostring(x), 1, 7) == "3.14159", "comp pi")

	local tmp
	-- Quick self-test (without pretty_double_bin): known bit pattern for 1.0
	tmp = bin64_to_double("0 01111111111 0000000000000000000000000000000000000000000000000000")
	print("tmp:", tmp)
	assert(tmp == 1.0)

	-- Signed zero test
	tmp = string.gsub(tostring(bin64_to_double("1 00000000000 0000000000000000000000000000000000000000000000000000")),
		"%.0$", "", 1)
	print("tmp:", tmp)
	assert(tmp == "-0")
	-- Infinity test
	tmp = tostring(bin64_to_double("0 11111111111 0000000000000000000000000000000000000000000000000000"))
	print("tmp:", tmp)
	assert(tmp == "inf")
	tmp = tostring(bin64_to_double("1 11111111111 0000000000000000000000000000000000000000000000000000"))
	print("tmp:", tmp)
	assert(tmp == "-inf")
	-- NaN test
	tmp = bin64_to_double("0 11111111111 1000000000000000000000000000000000000000000000000000")
	print("tmp:", tmp)
	assert(tmp ~= tmp, "expected NaN")

	-- Examples
	for _, v in next, { 3.141592653589793, 1.0, -0.0, 0.0, math.huge, -math.huge, 1e-320, 0 / 0 } do
		print(string_format("%g -> %s", v, pretty_double_bin(v)))
	end

	-- Single-call example returning raw 64-bit string
	local raw = double_to_bin64(3.141592653589793)
	print("raw:", raw)
	assert(raw == "0100000000001001001000011111101101010100010001000010110100011000")
	print(double_to_bin64(math.pi))
	print(double_to_int32_high_fast(math.pi))
	print(double_to_int32_low_fast(math.pi))

	-- Demo / quick tests
	for _, v in next, {
		3.141592653589793,
		1.0,
		-0.0,
		0.0,
		math.huge,
		-math.huge,
		1e-320, -- subnormal example
		1e-308, -- normal small
		0 / 0 -- NaN
	} do
		local hi = double_to_uint32_high(v)
		local lo = double_to_uint32_low(v)
		print(string_format("%g -> high=%s low=%s", v, hex32(hi), hex32(lo)))
	end

	-- Demonstrate faster normalization vs modulo
	local s = bit_tobit(bit_lshift(1, 31)) -- normalize to signed 32-bit
	assert(s == -2147483648)            -- signed shift
	assert(to_u32_fast(s) == 2147483648) -- unsigned normalized (fast)
	assert(to_u32_fast(-1) == 4294967295) -- unsigned -1

	local nan = 0 / 0
	local inf = 1 / 0
	assert(0 == bits.get_required_bits(-1))       --> 0
	--assert(-inf == bits.get_required_bits2(-1))     --> -inf
	assert(1 == bits.get_required_bits(0))        --> 1
	assert(1 == bits.get_required_bits(1))        --> 1
	assert(2 == bits.get_required_bits(2))        --> 2
	assert(3 == bits.get_required_bits(5))        --> 3 (binary: 101)
	assert(8 == bits.get_required_bits(255))      --> 8
	assert(9 == bits.get_required_bits(511))      --> 9
	assert(10 == bits.get_required_bits(512))     --> 10
	assert(0 == bits.get_required_bits(-2147483648)) --> 0
	--assert(nan == bits.get_required_bits2(-2147483648))--> nan
	assert(31 == bits.get_required_bits(2147483647)) --> 31
	--assert(bits.get_required_bits2(2147483647))    --> 30 <-- buggy: should be 31
	assert(32 == bits.get_required_bits(2147483648)) --> 32
	--assert(32 == bits.get_required_bits2(2147483648))--> 32
	assert(32 == bits.get_required_bits(U32MASK)) --> 32
	--assert(bits.get_required_bits2(U32MASK))        --> 31 <-- buggy: should be 32
	assert(bits.get_required_bits(U32MASK + 1))   --> 33
	--assert(bits.get_required_bits2(U32MASK + 1))    --> 33
	assert(bits.get_required_bits(TWO51 - 1))     --> 51
	--assert(bits.get_required_bits2(TWO51 - 1))      --> 51
	assert(52 == bits.get_required_bits(TWO51))   --> 52
	--assert(52 == bits.get_required_bits2(TWO51))    --> 52
end
