-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

--- Portable 32-bit bitwise module for LuaJIT/5.1+.<br>
--- Provides bitwise operations on 32-bit unsigned integers with automatic masking.<br>
--- Supports left shift, right shift, arithmetic right shift, bitwise OR/AND/XOR/NOT,<br>
--- rotate left/right, byte swap, and unsigned-to-signed conversion.
---@class bitwise
---@field lshift fun(x: number, n: number): number Left shift.
---@field rshift fun(x: number, n: number): number Right shift (logical).
---@field arshift fun(x: number, n: number): number Arithmetic right shift.
---@field bor fun(a: number, b: number): number Bitwise OR.
---@field band fun(a: number, b: number): number Bitwise AND.
---@field bxor fun(a: number, b: number): number Bitwise XOR.
---@field bnot fun(x: number): number Bitwise NOT.
---@field tobit fun(x: number): number Convert to 32-bit unsigned.
---@field bswap fun(x: number): number Byte swap.
---@field rol fun(x: number, n: number): number Rotate left.
---@field ror fun(x: number, n: number): number Rotate right.
---@field toint fun(n: number): number Convert to signed 32-bit.

-- Portable 32-bit bitwise module for LuaJIT/5.1+

--- Convert unsigned 32-bit to signed 32-bit.<br>
--- Converts a 32-bit unsigned value to its signed equivalent using two's complement.<br>
--- Useful for interpreting bitwise operation results as signed integers.
---@param n integer Unsigned 32-bit integer (0 to 4294967295).
---@return integer signed Signed integer (-2147483648 to 2147483647).
local function toint(n)
	--n = n % 0x100000000
	if n >= 0x80000000 then
		return n - 0x100000000
	end
	return n
end

-- Single compiled chunk for native operators (5.3+ only)
local function try_compile_native()
	local chunk = [[local math_floor = math.floor
return {
	lshift = function(x, n) return (x << n) & 0xFFFFFFFF end,
	rshift = function(x, n) return (x >> n) & 0xFFFFFFFF end,
	arshift = function(x, n)
		x = x & 0xFFFFFFFF
		if (x & 0x80000000) ~= 0 then
			local sx = x - 0x100000000
			local r = math_floor(sx / (2 ^ n))
			return (r & 0xFFFFFFFF)
		end
		return (x >> n) & 0xFFFFFFFF
	end,
	bor = function(a, b) return (a | b) & 0xFFFFFFFF end,
	band = function(a, b) return (a & b) & 0xFFFFFFFF end,
	bxor = function(a, b) return (a ~ b) & 0xFFFFFFFF end,
	bnot = function(x) return (~x) & 0xFFFFFFFF end,
	tobit = function(x) return x & 0xFFFFFFFF end,
	bswap = function(x)
		x = x & 0xFFFFFFFF
		return
			((x & 0xFF) << 24) |
			((x & 0xFF00) << 8) |
			((x >> 8) & 0xFF00) |
			((x >> 24) & 0xFF)
	end,
	rol = function(x, n)
		n = n & 31
		x = x & 0xFFFFFFFF
		return (((x << n) | (x >> (32 - n))) & 0xFFFFFFFF)
	end,
	ror = function(x,n)
		n = n & 31
		x = x & 0xFFFFFFFF
		return (((x >> n) | (x << (32 - n))) & 0xFFFFFFFF)
	end,
}]]
	local ok, loader = pcall(load or loadstring, chunk)
	if not ok or type(loader) ~= "function" then return end
	local ok2, impl = pcall(loader)
	if not ok2 or type(impl) ~= "table" then return end
	return impl
end

-- Try to build impl from builtin libraries (no operator tokens allowed here)
local function try_builtin_lib()
	local math_floor = math.floor
	if type(bit32) == "table" then -- 5.2
		local b_band   = bit32.band
		local b_bor    = bit32.bor
		local b_lshift = bit32.lshift
		local b_rshift = bit32.rshift
		return {
			lshift = b_lshift,
			rshift = b_rshift,
			arshift = function(x, n)
				local x32 = b_band(x, 0xFFFFFFFF)
				if b_band(x32, 0x80000000) ~= 0 then
					local sx = x32 - 0x100000000
					local r = math_floor(sx / (2 ^ n))
					return b_band(r, 0xFFFFFFFF)
				end
				return b_rshift(x32, n)
			end,
			bor = b_bor,
			band = b_band,
			bxor = bit32.bxor,
			bnot = bit32.bnot,
			tobit = bit32.tobit or function(x) return b_band(x, 0xFFFFFFFF) end,
			bswap = function(x)
				x = b_band(x, 0xFFFFFFFF)
				return b_bor(
					b_bor(
						b_lshift(b_band(x, 0xFF), 24),
						b_lshift(b_band(x, 0xFF00), 8)
					),
					b_bor(
						b_rshift(b_band(x, 0xFF0000), 8),
						b_rshift(b_band(x, 0xFF000000), 24)
					)
				)
			end,
			rol = function(x, n)
				n = n % 32
				x = b_band(x, 0xFFFFFFFF)
				return b_band(b_bor(b_lshift(x, n), b_rshift(x, 32 - n)), 0xFFFFFFFF)
			end,
			ror = function(x, n)
				n = n % 32
				x = b_band(x, 0xFFFFFFFF)
				return b_band(b_bor(b_rshift(x, n), b_lshift(x, 32 - n)), 0xFFFFFFFF)
			end,
		}
	end
	if type(bit) == "table" then -- LuaJIT
		local bit_band   = bit.band
		local bit_bor    = bit.bor
		local bit_lshift = bit.lshift
		local bit_rshift = bit.rshift
		return {
			lshift = bit.lshift,
			rshift = bit_rshift,
			arshift = bit.arshift or function(x, n)
				local x32 = bit_band(x, 0xFFFFFFFF)
				if bit_band(x32, 0x80000000) ~= 0 then
					local sx = x32 - 0x100000000
					local r = math_floor(sx / (2 ^ n))
					return bit_band(r, 0xFFFFFFFF)
				end
				return bit_rshift(x32, n)
			end,
			bor = bit.bor,
			band = bit_band,
			bxor = bit.bxor,
			bnot = bit.bnot,
			tobit = bit.tobit or function(x) return bit_band(x, 0xFFFFFFFF) end,
			bswap = function(x)
				x = bit_band(x, 0xFFFFFFFF)
				return bit_bor(
					bit_bor(
						bit_lshift(bit_band(x, 0xFF), 24),
						bit_lshift(bit_band(x, 0xFF00), 8)
					),
					bit_bor(
						bit_rshift(bit_band(x, 0xFF0000), 8),
						bit_rshift(bit_band(x, 0xFF000000), 24)
					)
				)
			end,
			rol = bit.rol,
			ror = bit.ror,
		}
	end
end

-- Pure Lua fallback (no operator tokens allowed here)
local function software_fallback()
	local math_floor = math.floor

	local function tobit(x)
		local n = math_floor(tonumber(x) or 0)
		if n < 0 then n = n % 0x100000000 end
		return n % 0x100000000
	end

	local function lshift(x, n)
		x = tobit(x)
		n = n % 32
		return ((x * (2 ^ n)) % 0x100000000)
	end

	local function rshift(x, n)
		x = tobit(x)
		n = n % 32
		return math_floor(x / (2 ^ n)) % 0x100000000
	end

	local function arshift(x, n)
		x = tobit(x)
		n = n % 32
		if x >= 0x80000000 then
			local sx = x - 0x100000000
			local r = math_floor(sx / (2 ^ n))
			if r < 0 then r = r + 0x100000000 end
			return r % 0x100000000
		end
		return rshift(x, n)
	end

	local function bor(a, b)
		a = tobit(a)
		b = tobit(b)
		local res = 0
		local bit = 1
		while a > 0 or b > 0 do
			if (a % 2) == 1 or (b % 2) == 1 then res = res + bit end
			a = math_floor(a / 2)
			b = math_floor(b / 2)
			bit = bit * 2
		end
		return res % 0x100000000
	end

	local function band(a, b)
		a = tobit(a)
		b = tobit(b)
		local res = 0
		local bit = 1
		while a > 0 and b > 0 do
			if (a % 2) == 1 and (b % 2) == 1 then res = res + bit end
			a = math_floor(a / 2)
			b = math_floor(b / 2)
			bit = bit * 2
		end
		return res % 0x100000000
	end

	local function bxor(a, b)
		a = tobit(a)
		b = tobit(b)
		local res = 0
		local bit = 1
		while a > 0 or b > 0 do
			local abit = a % 2
			local bbit = b % 2
			if (abit + bbit) % 2 == 1 then res = res + bit end
			a = math_floor(a / 2)
			b = math_floor(b / 2)
			bit = bit * 2
		end
		return res % 0x100000000
	end

	local function bnot(x)
		x = tobit(x)
		return (0xFFFFFFFF - x) % 0x100000000
	end

	local function bswap(x)
		x = tobit(x)
		return bor(
			bor(
				lshift(band(x, 0xFF), 24),
				lshift(band(x, 0xFF00), 8)
			),
			bor(
				rshift(band(x, 0xFF0000), 8),
				rshift(band(x, 0xFF000000), 24)
			)
		)
	end

	local function rol(x, n)
		x = tobit(x)
		n = n % 32
		return bor(lshift(x, n), rshift(x, 32 - n)) % 0x100000000
	end

	local function ror(x, n)
		x = tobit(x)
		n = n % 32
		return bor(rshift(x, n), lshift(x, 32 - n)) % 0x100000000
	end

	return {
		lshift  = lshift,
		rshift  = rshift,
		arshift = arshift,
		bor     = bor,
		band    = band,
		bxor    = bxor,
		bnot    = bnot,
		tobit   = tobit,
		bswap   = bswap,
		rol     = rol,
		ror     = ror,
		toint   = toint,
	}
end

-- Build implementation: prefer compiled native chunk, then builtin lib, then fallback
local impl = try_compile_native() or try_builtin_lib() or software_fallback()
impl.toint = impl.toint or toint
if not impl.bnot then
	local tobit_local = impl.tobit
	impl.bnot = function(x) return (0xFFFFFFFF - tobit_local(x)) % 0x100000000 end
end
if not impl.tobit then
	local math_floor = math.floor
	impl.tobit = function(x)
		local n = math_floor(tonumber(x) or 0)
		if n < 0 then n = n % 0x100000000 end
		return n % 0x100000000
	end
end
if not impl.bswap then
	local lshift_local = impl.lshift
	local rshift_local = impl.rshift
	local band_local = impl.band
	local bor_local = impl.bor
	local tobit_local = impl.tobit
	impl.bswap = function(x)
		x = tobit_local(x)
		return bor_local(
			bor_local(
				lshift_local(band_local(x, 0xFF), 24),
				lshift_local(band_local(x, 0xFF00), 8)
			),
			bor_local(
				rshift_local(band_local(x, 0xFF0000), 8),
				rshift_local(band_local(x, 0xFF000000), 24)
			)
		)
	end
end
if not impl.rol then
	local lshift_local = impl.lshift
	local rshift_local = impl.rshift
	local bor_local = impl.bor
	local tobit_local = impl.tobit
	impl.rol = function(x, n)
		n = n % 32
		x = tobit_local(x)
		return (bor_local(lshift_local(x, n), rshift_local(x, 32 - n)) % 0x100000000)
	end
end
if not impl.ror then
	local lshift_local = impl.lshift
	local rshift_local = impl.rshift
	local bor_local = impl.bor
	local tobit_local = impl.tobit
	impl.ror = function(x, n)
		n = n % 32
		x = tobit_local(x)
		return (bor_local(rshift_local(x, n), lshift_local(x, 32 - n)) % 0x100000000)
	end
end

-- Export
---@type bitwise
return {
	lshift  = impl.lshift,
	rshift  = impl.rshift,
	arshift = impl.arshift,
	bor     = impl.bor,
	band    = impl.band,
	bxor    = impl.bxor,
	bnot    = impl.bnot,
	tobit   = impl.tobit,
	bswap   = impl.bswap,
	rol     = impl.rol,
	ror     = impl.ror,
	toint   = toint,
}
