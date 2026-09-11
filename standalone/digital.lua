-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Binary/Digital logic for LuaJIT/5.1+ and later

-- Localized global functions for better performance
local math_floor = math.floor
local math_max = math.max
local table_insert = table.insert
local table_unpack = table.unpack or unpack

-- Load bits module for bit operations (standalone compatible)
local bits = require "bits"
local band, bor, lshift, rshift = bits.band, bits.bor, bits.lshift, bits.rshift

----------------------------------------------------------------------
-- Convert Bits to Number
----------------------------------------------------------------------

--- Convert bits (vararg, LSB first) to a number
---@param ... integer Input bits (0 or 1), least significant bit first
---@return integer number Numeric value represented by the bits
local function binary_to_decimal(...)
	local t = { ... }
	local num = 0
	for i = 1, #t do
		-- LSB first
		num = num + t[i] * (2 ^ (i - 1))
	end
	return num
end

--- Convert a table of bits (LSB first) to a number
---@param t table Array of bits (0 or 1), index 1 = LSB
---@return integer number Numeric value represented by the bits
local function bits_to_number(t)
	local num = 0
	for i = 1, #t do
		num = num + t[i] * (2 ^ (i - 1))
	end
	return num
end

--- Convert a table of bits to a number using bitwise operations
---@param t table Array of bits (0 or 1), index 1 = LSB
---@return integer number Numeric value represented by the bits
local function binary_to_number(t)
	local num = 0
	for i = 1, #t do
		num = bor(num, lshift(t[i], i - 1))
	end
	return num
end

----------------------------------------------------------------------
-- Convert Number to Bits
----------------------------------------------------------------------

--- Convert a number to its binary representation as multiple return values (LSB first)
---@param n integer Non-negative integer to convert
---@return ... integer Bit values (0 or 1), least significant bit first
local function decimal_to_binary(n)
	if n == 0 then return 0 end -- Edge case for zero
	local t = {}
	while n > 0 do
		table_insert(t, n % 2) -- Captures the remainder (0 or 1)
		n = math_floor(n * 0.5) -- Shifts the number right by dividing by 2
	end
	return table_unpack(t) -- Returns multiple values (e.g. 1, 0, 1)
end

--- Convert a number to a table of bits (LSB first)
---@param n integer Non-negative integer to convert
---@return table bits Array of bits (0 or 1), index 1 = LSB
local function number_to_bits(n)
	local t = {}
	while n > 0 do
		t[#t + 1] = n % 2 -- LSB first
		n = math_floor(n * 0.5) -- Shifts the number right by dividing by 2
	end
	return t
end

--- Convert a number to its binary representation using bitwise operations (LSB first)
---@param n integer Non-negative integer to convert
---@return ... integer Bit values (0 or 1), least significant bit first
local function number_to_binary(n)
	if n == 0 then return 0 end -- Edge case for zero
	local t = {}
	while n > 0 do
		t[#t + 1] = band(n, 1) -- Extract least significant bit (LSB)
		n = rshift(n, 1) -- Shift bits right by 1 (divide by 2)
	end
	return table_unpack(t)
end

----------------------------------------------------------------------
-- Basic Gates (inputs/outputs: 0 or 1)
----------------------------------------------------------------------

---@type integer LOW constant (0)
local LOW = 0

---@type integer HIGH constant (1)
local HIGH = 1

local NOT, AND, OR, XOR, NAND, NOR, NXOR

--- Invert the input signal (inverter)
---@param a integer Input bit (0 or non-zero)
---@return integer number 1 if input is 0, otherwise 0
function NOT(a)
	return (a == 0) and 1 or 0
end

if true then
	--- AND gate. Outputs HIGH only if both inputs are non-zero
	---@param a integer First input bit
	---@param b integer Second input bit
	---@return integer number 1 if both inputs are active, otherwise 0
	function AND(a, b) return (a ~= 0 and b ~= 0) and 1 or 0 end

	--- OR gate. Outputs HIGH if at least one input is non-zero
	---@param a integer First input bit
	---@param b integer Second input bit
	---@return integer number 1 if either input is active, otherwise 0
	function OR(a, b) return (a ~= 0 or b ~= 0) and 1 or 0 end

	--- XOR gate (exclusive OR). Outputs HIGH if the inputs are different
	---@param a integer First input bit
	---@param b integer Second input bit
	---@return integer number 1 if inputs differ, 0 if they match
	function XOR(a, b)
		--return ((a & 1) + (b & 1)) & 1
		--return ((a % 2) + (b % 2)) % 2
		return (a ~= b) and 1 or 0
	end

	--- NAND gate (inverted AND). Universal gate capable of replicating any other gate logic
	---@param a integer First input bit
	---@param b integer Second input bit
	---@return integer number 0 if both inputs are active, otherwise 1
	function NAND(a, b) return NOT(AND(a, b)) end

	--- NOR gate (inverted OR). Outputs HIGH only when all inputs are 0
	---@param a integer First input bit
	---@param b integer Second input bit
	---@return integer number 1 if both inputs are 0, otherwise 0
	function NOR(a, b) return NOT(OR(a, b)) end

	--- NXOR gate (equivalence). Outputs HIGH if the inputs are identical
	---@param a integer First input bit
	---@param b integer Second input bit
	---@return integer number 1 if inputs match, 0 if they differ
	function NXOR(a, b) return NOT(XOR(a, b)) end
else
	local select, HASH = select, "#"

	--- AND gate (variadic). Outputs HIGH only if all inputs are non-zero
	---@param ... integer Input bits (0 or non-zero)
	---@return integer number 1 if all inputs are active, otherwise 0
	function AND(...)
		local n = select(HASH, ...)
		if n == 0 then return 0 end
		for i = 1, n do
			if select(i, ...) == 0 then
				return 0
			end
		end
		return 1
	end

	--- OR gate (variadic). Outputs HIGH if at least one input is non-zero
	---@param ... integer Input bits (0 or non-zero)
	---@return integer number 1 if any input is active, otherwise 0
	function OR(...)
		for i = 1, select(HASH, ...) do
			if select(i, ...) ~= 0 then
				return 1
			end
		end
		return 0
	end

	--- XOR gate (variadic/parity). Outputs HIGH if an odd number of inputs are non-zero
	---@param ... integer Input bits (0 or non-zero)
	---@return integer number 1 if an odd number of inputs are active, otherwise 0
	function XOR(...)
		local activeCount = 0
		for i = 1, select(HASH, ...) do
			if select(i, ...) ~= 0 then
				activeCount = activeCount + 1
			end
		end
		return (activeCount % 2 == 1) and 1 or 0
	end

	--- NAND gate (variadic/inverted AND). Universal gate capable of replicating any other gate logic
	---@param ... integer Input bits (0 or non-zero)
	---@return integer number 0 if all inputs are active, otherwise 1
	function NAND(...)
		return NOT(AND(...))
	end

	--- NOR gate (variadic/inverted OR). Outputs HIGH only when all inputs are 0
	---@param ... integer Input bits (0 or non-zero)
	---@return integer number 1 if all inputs are 0, otherwise 0
	function NOR(...)
		return NOT(OR(...))
	end

	--- NXOR gate (variadic/equivalence). Outputs HIGH if an even number of inputs are active
	---@param ... integer Input bits (0 or non-zero)
	---@return integer number 1 if an even number of inputs are active, otherwise 0
	function NXOR(...)
		return NOT(XOR(...))
	end
end

--- Half adder. Adds two bits and returns sum and carry
---@param a integer First input bit (0 or 1)
---@param b integer Second input bit (0 or 1)
---@return integer sum Sum bit (a XOR b)
---@return integer carry Carry-out bit (a AND b)
local function half_adder(a, b)
	return XOR(a, b), AND(a, b)
end

--- Full adder using basic logic gates (gate-level implementation)<br>
--- Computes sum and carry-out from two input bits plus a carry-in using 5 gates
---@param a integer First input bit (0 or 1)
---@param b integer Second input bit (0 or 1)
---@param carry_in integer Incoming carry bit (0 or 1)
---@return integer sum Sum bit (a XOR b XOR carry_in)
---@return integer carry_out Carry-out bit ((a AND b) OR (a XOR b AND carry_in))
---@usage <br>
--- ```
--- full_adder(0, 0, 0) -- 0, 0
--- full_adder(1, 0, 0) -- 1, 0
--- full_adder(1, 1, 0) -- 0, 1
--- full_adder(1, 1, 1) -- 1, 1
--- ```
local function full_adder(a, b, carry_in)
	-- 5 gates
	local xor = XOR(a, b)
	local sum = XOR(xor, carry_in)
	local carry_out = OR(AND(a, b), AND(xor, carry_in))
	return sum, carry_out
end

--- Full adder composed from two half adders<br>
--- Equivalent to the gate-level implementation but built by chaining half_adder units
---@param a integer First input bit (0 or 1)
---@param b integer Second input bit (0 or 1)
---@param carry_in integer Incoming carry bit (0 or 1)
---@return integer sum Sum bit (a XOR b XOR carry_in)
---@return integer carry_out Carry-out bit
---@usage <br>
--- ```
--- full_adder(0, 0, 0) -- 0, 0
--- full_adder(1, 0, 0) -- 1, 0
--- full_adder(1, 1, 0) -- 0, 1
--- full_adder(1, 1, 1) -- 1, 1
--- ```
local function full_adder(a, b, carry_in)
	-- 5 gates
	local sum1, cout1 = half_adder(a, b)
	local sum2, cout2 = half_adder(sum1, carry_in)
	local carry_out = OR(cout1, cout2)
	return sum2, carry_out
end

--- Ripple-carry adder for adding multiple numbers<br>
--- Converts each number to bit tables and chains full adders to produce the sum
---@param ... integer Numbers to add together (at least 2)
---@return table bits Bit table of the result (LSB first)
local function ripple_carry_adder(...)
	local numbers = { ... }
	if #numbers < 2 then
		return numbers[1] or {}
	end
	-- Convert all numbers to bit tables
	local bit_tables = {}
	for i = 1, #numbers do
		local num = numbers[i]
		bit_tables[i] = number_to_bits(num)
	end
	-- Start with the first number's bits
	local result = bit_tables[1]
	for i = 2, #bit_tables do
		local carry = 0
		local new_result = {}
		local max_len = math_max(#result, #bit_tables[i])
		for j = 1, max_len do
			local a = result[j] or 0
			local b = bit_tables[i][j] or 0
			local sum, new_carry = full_adder(a, b, carry)
			new_result[j] = sum
			carry = new_carry
		end
		if carry > 0 then
			table_insert(new_result, carry)
		end
		result = new_result
	end
	return result
end

-- Export
return {
	-- Conversion: bits <=> number
	binary_to_decimal  = binary_to_decimal, -- takes vararg bits, LSB first
	bits_to_number     = bits_to_number, -- table version of above
	binary_to_number   = binary_to_number,
	decimal_to_binary  = decimal_to_binary, -- returns multiple values (LSB first), 0 -> 0
	number_to_bits     = number_to_bits,
	number_to_binary   = number_to_binary,

	-- Basic gates
	NOT                = NOT,
	AND                = AND,
	OR                 = OR,
	XOR                = XOR,
	NAND               = NAND,
	NOR                = NOR,
	NXOR               = NXOR,

	-- Half and full adders
	half_adder         = half_adder,
	full_adder         = full_adder, -- uses half_adder internally

	-- Multi-bit adder
	ripple_carry_adder = ripple_carry_adder,

	-- Constants
	LOW                = LOW,
	HIGH               = HIGH,
}
