--local args = { ... }
--print("args:", unpack(args))

local EXP_BIAS = 1023
local MIN_NORMAL = 2 ^ -1022
local MANT_BITS = 52
local U32 = 2 ^ 32
local U32MASK = 0xFFFFFFFF
local TWO51 = 2 ^ 51

local bit = assert(bit32 or bit or require("bit"))
local bit_tobit = bit.tobit
local bit_band = bit.band
local bit_bor = bit.bor
local bit_lshift = bit.lshift
--local bit_rshift = bit.rshift
local math_huge = math.huge
--local math_abs = math.abs
--local math_ceil = math.ceil
local math_floor = math.floor
local math_log = math.log
-- ldexp fallback
local function ldexp(m, e)
  return m * (2.0 ^ e)
end
-- frexp fallback: returns mantissa m in [0.5,1) (or 0) and integer exponent e such that x = m * 2^e
local function frexp(x)
  if x == 0 then return 0.0, 0 end
  if x ~= x then return 0 / 0, 0 end     -- NaN
  if x == math_huge or x == -math_huge then
    return (x < 0) and -0.5 or 0.5, 1024 -- Sentinel exponent for infinities
  end
  local sign = 1
  if x < 0 then
    sign, x = -1, -x
  end
  -- Estimate exponent
  local e = math_floor(math_log(x) / math_log(2)) + 1
  local m = x / (2 ^ e)
  -- Adjust to ensure m in [0.5, 1)
  if m < 0.5 then
    e = e - 1
    m = m * 2
  elseif m >= 1.0 then
    e = e + 1
    m = m / 2
  end
  return sign * m, e
end
local math_frexp = math.frexp or frexp
local math_ldexp = math.ldexp or ldexp
local string_byte = string.byte
local string_format = string.format
local string_gsub = string.gsub
local string_sub = string.sub
local table_concat = table.concat

-- Normalize any Lua number into unsigned 32-bit range 0..2^32-1
function to_u32(x)
  -- return tonumber(string_format("%u", x))
  return x % U32
end

-- Fast unsigned normalization: convert signed 32-bit to unsigned 0..2^32-1
function to_u32_fast(x)
  -- bit.tobit ensures a 32-bit signed representation
  local s = bit_tobit(x)
  -- If negative, add 2^32 to get unsigned value
  return s < 0 and s + U32 or s
end

-- If bit.tobit isn't available for some reason, fallback to bit.band + branch:
--function to_u32_fast(x)
--  local s = bit_band(x, U32MASK)  -- still may be negative signed 32-bit
--  if s < 0 then return s + U32 else return s end
--end

local function canonical_nan_mantissa()
  -- Choose a representable mantissa for NaN payload (cannot recover arbitrary payloads numerically)
  return TWO51
end

-- Return signed 32-bit low-word of the IEEE-754 binary64 bit pattern
function double_to_int32_low_fast(n)
  if n == 0 then
    return 0
  end
  if n >= MIN_NORMAL then
    -- n = m * 2^e, m in [0.5,1)
    -- Low 32 bits of the 52-bit mantissa are the low 32 bits of the double bit pattern
    return math_floor((2 * (math_frexp(n)) - 1) * 2 ^ MANT_BITS + 0.5)
  end
  -- Subnormal: mantissa = round(n * 0.5^-1074)
  -- Subnormal: value = mantissa * 2^-1074, where mantissa is integer in [1, 2^52-1]
  -- Compute integer mantissa by scaling
  return math_floor(n * 0.5 ^ -1074 + 0.5)
end

-- Return unsigned 32-bit low-word of the IEEE-754 binary64 bit pattern
function double_to_uint32_low(n)
  -- Handle NaN
  if n ~= n then
    --return to_u32_fast(TWO51)
    return 0xFFFFFFFF
  end
  -- Handle positive/negative infinity and (signed) zero
  if n == math_huge or n == -math_huge or n == 0 then
    -- For IEEE inf: exponent all ones, mantissa zero -> low 32 bits are 0
    return 0
  end
  if n >= MIN_NORMAL then
    -- n = m * 2^e, m in [0.5,1)
    -- Low 32 bits of the 52-bit mantissa are the low 32 bits of the double bit pattern
    return to_u32_fast(math_floor((2 * (math_frexp(n)) - 1) * 2 ^ MANT_BITS + 0.5))
  end
  -- Subnormal: mantissa = round(n * 0.5^-1074)
  -- Subnormal: value = mantissa * 2^-1074, where mantissa is integer in [1, 2^52-1]
  -- Compute integer mantissa by scaling
  return to_u32_fast(math_floor(n * 0.5 ^ -1074 + 0.5))
end

-- Return signed 32-bit high-word of the IEEE-754 binary64 bit pattern
function double_to_int32_high_fast(n)
  if n == 0 then
    return 0
  end
  local sign = 0
  if n < 0 then
    sign, n = 1, -n
  end
  if n >= MIN_NORMAL then
    local m, e = math_frexp(n) -- n = m * 2^e
    return bit_bor(bit_lshift(sign, 31), bit_lshift(e + (EXP_BIAS - 1), 20),
      math_floor(math_floor((2 * m - 1) * 2 ^ MANT_BITS + 0.5) / U32))
  end
  -- Subnormal: exponent field zero, mantissa scaled
  return bit_bor(bit_lshift(sign, 31), 0, math_floor(math_floor(n * 0.5 ^ -1074 + 0.5) / U32))
end

-- Return unsigned 32-bit high-word of the IEEE-754 binary64 bit pattern
function double_to_uint32_high(n)
  -- Handle NaN
  if n ~= n then
    -- Exponent all ones and choose mantissa with top mantissa bits set
    --return to_u32_fast(bit_bor(bit_lshift(0, 31), bit_lshift(2047, 20), math_floor(TWO51 / U32)))
    return 0x7FF80000
  end
  -- Handle positive and negative infinity
  if n == math_huge then
    --return to_u32_fast(bit_bor(bit_lshift(0, 31), bit_lshift(2047, 20), 0))
    return 0x7FF00000
  end
  if n == -math_huge then
    --return to_u32_fast(bit_bor(bit_lshift(1, 31), bit_lshift(2047, 20), 0))
    return 0xFFF00000
  end
  -- Handle (signed) zero
  if n == 0 then
    --return to_u32_fast(bit_lshift((1 / n == -math_huge) and 1 or 0, 31))
    return 1 / n == -math_huge and 0x80000000 or 0
  end
  local sign = 0
  if n < 0 then
    sign = 1
    n = -n
  end
  if n >= MIN_NORMAL then
    local m, e = math_frexp(n) -- n = m * 2^e
    return to_u32_fast(bit_bor(bit_lshift(sign, 31), bit_lshift(e + (EXP_BIAS - 1), 20),
      math_floor(math_floor((2 * m - 1) * 2 ^ MANT_BITS + 0.5) / U32)))
  end
  -- Subnormal: exponent field zero, mantissa scaled
  return to_u32_fast(bit_bor(bit_lshift(sign, 31), 0, math_floor(math_floor(n * 0.5 ^ -1074 + 0.5) / U32)))
end

-- Helper for hexadecimal formatting (0xXXXXXXXX)
function hex32(x) return string_format("0x%08X", to_u32_fast(x)) end

--print("nan test: " .. hex32(double_to_uint32_high(0 / 0)))
--print("inf test:", double_to_uint32_high(math.huge))
--print("-inf test:", double_to_uint32_high(-math.huge))
--print("positive zero test:", double_to_uint32_high(0))
--print("negative zero test:", double_to_uint32_high(-0))

-- Convert unsigned 32-bit value to 32-character binary string (big-endian bit order)
local u32_to_bin32_buffer = {} -- Avoid table allocation overhead
function u32_to_bin32(u)
  u = to_u32_fast(u)
  for i = 31, 0, -1 do
    u32_to_bin32_buffer[32 - i] = (bit_band(u, bit_lshift(1, i)) ~= 0) and "1" or "0"
  end
  return table_concat(u32_to_bin32_buffer)
end

-- Return 64-bit binary string "s eeeeeeeeeee mmmmm...".
function double_to_bin64(n)
  -- hi contains sign(1)|exp(11)|mant_top20 ; lo contains mant_low32
  return u32_to_bin32(double_to_uint32_high(n)) .. u32_to_bin32(double_to_uint32_low(n))
end

-- Pretty printer: "s eeeeeeeeeee mmmmm... (with spaces)"
function pretty_double_bin(n)
  local bin64 = double_to_bin64(n)
  return string_format("%s %s %s", string_sub(bin64, 1, 1), string_sub(bin64, 2, 12), string_sub(bin64, 13, 64))
end

-- Convert a binary substring like "10101" to an integer (exact for up to 52 bits)
function bin_to_uint(bin)
  local v = 0
  for i = 1, #bin do
    local c = string_byte(bin, i)
    -- Assume valid '0'/'1'
    v = (v * 2) + (c - 48)
  end
  return v
end

-- Returns a Lua number (double), including -0.0, math.huge, -math.huge, or 0/0 for NaN.
local function bin64_to_double(bin64)
  -- Strip spaces
  bin64 = string_gsub(bin64, "%s+", "")
  if #bin64 ~= 64 then
    return error("bin64_to_double: input must be 64 bits (spaces allowed)")
  end
  local sign_bit  = string_sub(bin64, 1, 1)
  local exp_bits  = string_sub(bin64, 2, 12)  -- 11 bits
  local mant_bits = string_sub(bin64, 13, 64) -- 52 bits
  local s         = (sign_bit == "1") and 1 or 0
  local E         = bin_to_uint(exp_bits)
  local mant      = bin_to_uint(mant_bits)
  -- Special cases
  if E == 2047 then
    if mant == 0 then
      return s == 1 and -math_huge or math_huge
    end
    return 0 / 0 -- NaN (we cannot reconstruct payload semantics beyond returning NaN)
  end
  if E == 0 then
    if mant == 0 then
      -- Signed zero
      if s == 1 then
        return -0.0
      end
      return 0.0
    end
    -- Subnormal: value = (-1)^s * mant * 2^-1074
    local v = math_ldexp(mant, -1074)
    return s == 1 and -v or v
  end
  -- Normalized: value = (-1)^s * (1 + mant/2^52) * 2^(E - bias)
  local v = math_ldexp(1 + mant / (2 ^ MANT_BITS), E - EXP_BIAS)
  return s == 1 and -v or v
end

-- Example round-trip using the pretty printer from earlier (pretty_double_bin)
-- (Assumes pretty_double_bin exists and returns "s eeeeeeeeeee mmmmm..." strings.)
--local b = pretty_double_bin(3.141592653589793)
--local x = bin64_to_double(b)
--print(b)
--print(x) -- Should print 3.141592653589793

-- Quick self-test (without pretty_double_bin): known bit pattern for 1.0
local one_bits = "0 01111111111 0000000000000000000000000000000000000000000000000000"
print(bin64_to_double(one_bits)) -- prints 1.0

-- Signed zero test
print(bin64_to_double("1 00000000000 0000000000000000000000000000000000000000000000000000")) -- -0.0
-- Infinity test
print(bin64_to_double("0 11111111111 0000000000000000000000000000000000000000000000000000")) -- +inf
print(bin64_to_double("1 11111111111 0000000000000000000000000000000000000000000000000000")) -- -inf
-- NaN test
print(bin64_to_double("0 11111111111 1000000000000000000000000000000000000000000000000000")) -- nan

-- Examples
for _, v in next, { 3.141592653589793, 1.0, -0.0, 0.0, math.huge, -math.huge, 1e-320, 0 / 0 } do
  print(string_format("%g -> %s", v, pretty_double_bin(v)))
end

-- Single-call example returning raw 64-bit string
local raw = double_to_bin64(3.141592653589793)
assert(raw == "0100000000001001001000011111101110101010001000100001011010001100")
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
  0 / 0   -- NaN
} do
  local hi = double_to_uint32_high(v)
  local lo = double_to_uint32_low(v)
  print(string_format("%g -> high=%s low=%s", v, hex32(hi), hex32(lo)))
end

-- Demonstrate faster normalization vs modulo
local s = bit_lshift(1, 31)                          -- signed -2147483648
print("signed shift:", s)                            -- -2147483648
print("unsigned normalized (fast):", to_u32_fast(s)) -- 2147483648
print("unsigned -1:", to_u32_fast(-1))               -- 4294967295

-- This is the best/correct implementation (handles all 52 bits properly)
function get_required_bits(n)
  -- 0 is a special case: It requires 1 bit to represent (value 0)
  if n == 0 then return 1 end
  local bits = 0
  while n > 0 do
    bits = bits + 1
    --n = bit_rshift(n, 1) -- Limited up to 2^31
    n = math_floor(n * 0.5) -- Shift right by 1 bit (n becomes n/2; n>>1)
  end
  return bits
end

-- Buggy, do not use this
function get_required_bits2(n)
  -- If n is 0, return 1. Otherwise, calculate log base 2 and round up.
  --return n == 0 and 1 or math_ceil(math_log(n + 1, 2))
  if n == 0 then return 1 end
  local k = math_floor(math_log(n, 2))
  return 2 ^ k == n and k + 1 or k -- Explicit power-of-two branch avoids rounding traps
end

-- More examples
print(get_required_bits(-1))           --> 0
print(get_required_bits2(-1))          --> -inf
print(get_required_bits(0))            --> 1
print(get_required_bits(1))            --> 1
print(get_required_bits(2))            --> 2
print(get_required_bits(5))            --> 3 (binary: 101)
print(get_required_bits(255))          --> 8
print(get_required_bits(511))          --> 9
print(get_required_bits(512))          --> 10
print(get_required_bits(-2147483648))  --> 0
print(get_required_bits2(-2147483648)) --> nan
print(get_required_bits(2147483647))   --> 31
print(get_required_bits2(2147483647))  --> 30 <-- buggy: should be 31
print(get_required_bits(2147483648))   --> 32
print(get_required_bits2(2147483648))  --> 32
print(get_required_bits(U32MASK))      --> 32
print(get_required_bits2(U32MASK))     --> 31 <-- buggy: should be 32
print(get_required_bits(U32MASK + 1))  --> 33
print(get_required_bits2(U32MASK + 1)) --> 33
print(get_required_bits(TWO51 - 1))    --> 51
print(get_required_bits2(TWO51 - 1))   --> 51
print(get_required_bits(TWO51))        --> 52
print(get_required_bits2(TWO51))       --> 52
