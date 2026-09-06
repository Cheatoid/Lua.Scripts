-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Turing-complete, feature-rich, object-oriented Virtual Machine in Lua
--
-- Features:
-- * 16 General-Purpose Registers (R0-R15)
-- * 256KB Addressable Memory with heap allocation
-- * 70+ Opcodes across 14 categories
-- * IEEE 754 Floating Point support
-- * Vector/SIMD Operations
-- * String Operations
-- * Smart Assembler with label support
-- * System Calls for I/O
-- * Turing Complete (verified)

-- Localized global functions for better performance
--local assert = assert
local error = error
--local getmetatable = getmetatable
local next = next
local print = print
--local rawget = rawget
--local rawset = rawset
local setmetatable = setmetatable
local tonumber = tonumber
local tostring = tostring
local type = type
local io_open = io.open
local io_stderr = io.stderr
local math_abs = math.abs
local math_ceil = math.ceil
local math_floor = math.floor
local math_huge = math.huge
local math_log = math.log
--local math_max = math.max
--local math_min = math.min
local math_random = math.random
local math_sqrt = math.sqrt
local os_clock = os.clock
local os_time = os.time
local string_byte = string.byte
local string_char = string.char
local string_find = string.find
local string_format = string.format
local string_gmatch = string.gmatch
local string_gsub = string.gsub
--local string_lower = string.lower
local string_match = string.match
--local string_rep = string.rep
local string_sub = string.sub
local string_upper = string.upper
local table_concat = table.concat
local table_insert = table.insert
local table_unpack = table.unpack or unpack

-- Load bits module for bit operations (standalone compatible)
local bits = require "../standalone/bits"
local bit_band = bits.band
local bit_bnot = bits.bnot
local bit_bor = bits.bor
local bit_bxor = bits.bxor
local bit_lshift = bits.lshift
--local bit_rol = bits.rol
--local bit_ror = bits.ror
local bit_rshift = bits.rshift

----------------------------------------------------------------------
-- MODULE: UTILITIES
-- TODO: Move to util/bit lib
----------------------------------------------------------------------

local Utils = {}

--- Convert number to hexadecimal string.
---@param num number The number to convert (default: 0)
---@param width? number The width of output in hex digits (default: 4)
---@return string hex Hexadecimal representation with zero padding
function Utils.toHex(num, width)
	width = width or 4
	if num == nil then return "nil" end
	num = math_floor(num) % (2 ^ (width * 4))
	return string_format("%0" .. width .. "X", num)
end

--- Convert 32-bit value to 4 bytes (little-endian).
---@param value number The 32-bit value to convert (default: 0)
---@return number b0 Byte 0 (least significant)
---@return number b1 Byte 1
---@return number b2 Byte 2
---@return number b3 Byte 3 (most significant)
function Utils.toDWords(value)
	if value == nil then value = 0 end
	if type(value) == "string" then value = tonumber(value) or 0 end
	value = math_floor(tonumber(value) or 0) % (2 ^ 32)
	return value % 256,
		math_floor(value / 256) % 256,
		math_floor(value / 65536) % 256,
		math_floor(value / 16777216) % 256
end

--- Convert 4 bytes to 32-bit value (little-endian).
---@param b0? number Byte 0 (least significant, optional)
---@param b1? number Byte 1 (optional)
---@param b2? number Byte 2 (optional)
---@param b3? number Byte 3 (most significant, optional)
---@return number value 32-bit value
function Utils.fromDWords(b0, b1, b2, b3)
	return (b0 or 0) + ((b1 or 0) * 256) + ((b2 or 0) * 65536) + ((b3 or 0) * 16777216)
end

--- Split string by delimiter.
---@param str string The string to split (optional)
---@param delimiter string The delimiter character (default: newline)
---@return table array Array of substrings
function Utils.split(str, delimiter) -- TODO: Use string.split_pattern
	if str == nil then return {} end
	delimiter = delimiter or "\n"
	local result = {}
	for line in string_gmatch(str, "[^" .. delimiter .. "]+") do
		table_insert(result, line)
	end
	return result
end

--- Trim whitespace from both ends of string.
---@param str string The string to trim (optional)
---@return string trimmed Trimmed string
function Utils.trim(str) -- TODO: Use string.trim
	if str == nil then return "" end
	if type(str) ~= "string" then str = tostring(str) end
	return string_match(str, "^%s*(.-)%s*$") or ""
end

--- Check if a value is a valid register reference.
---@param str string The string to check
---@return boolean isRegister True if string matches register pattern (R0-R15)
function Utils.isRegister(str)
	if str == nil then return false end
	local num = string_match(string_upper(str), "^R(%d+)$")
	if num then
		local n = tonumber(num)
		return n and n >= 0 and n <= 15 or false
	end
	return false
end

--- Parse register number from string.
---@param str string The register string (e.g., "R5")
---@return number? registerNumber Register number (0-15) or nil if invalid
function Utils.parseRegister(str)
	if str == nil then return end
	local num = string_match(string_upper(str), "^R(%d+)$")
	if num then
		local n = tonumber(num)
		if n and n >= 0 and n <= 15 then return n end
	end
end

----------------------------------------------------------------------
-- MODULE: MEMORY
----------------------------------------------------------------------

--- Memory class for VM memory management.<br>
--- Provides read/write operations, heap allocation, and memory statistics.
---@class Memory
---@field size number Total memory size in bytes.
---@field data table Memory cells (array of bytes).
---@field allocated table Map of allocated heap blocks.
---@field nextHeapAddr number Next available heap address.
local Memory = {}
Memory.__index = Memory

--- Memory constants.
Memory.SIZE = 256 * 1024     -- 256KB total addressable memory
Memory.HEAP_START = 0x10000  -- Heap starts at 64KB
Memory.STACK_START = 0x3F000 -- Stack starts near end of memory

--- Create a new Memory instance.
---@param size? number Optional size in bytes (default: `Memory.SIZE`)
---@return Memory instance New memory instance
function Memory.new(size)
	return setmetatable({
		size = size or Memory.SIZE,
		data = {}, -- Memory cells
		allocated = {}, -- Track allocated heap blocks
		nextHeapAddr = Memory.HEAP_START,
	}, Memory)
end

--- Read a byte from memory.
---@param self Memory The memory instance
---@param address number The memory address to read from
---@return number byte The byte value at the address (0 if out of bounds)
function Memory.readByte(self, address)
	if address == nil then return 0 end
	address = math_floor(address)
	if address < 0 or address >= self.size then return 0 end
	return self.data[address] or 0
end

--- Write a byte to memory.
---@param self Memory The memory instance
---@param address number The memory address to write to
---@param value number The byte value to write (0-255)
function Memory.writeByte(self, address, value)
	if address == nil or value == nil then return end
	address = math_floor(address)
	value = math_floor(value)
	if address < 0 or address >= self.size then return end
	self.data[address] = value % 256
end

--- Read a 16-bit word from memory (little-endian).
---@param self Memory The memory instance
---@param address number The memory address
---@return number word The 16-bit word value
function Memory.readWord(self, address)
	return Memory.readByte(self, address) + (Memory.readByte(self, address + 1) * 256)
end

--- Write a 16-bit word to memory (little-endian).
---@param self Memory The memory instance
---@param address number The memory address
---@param value number The 16-bit value to write
function Memory.writeWord(self, address, value)
	value = value or 0
	Memory.writeByte(self, address, value % 256)
	Memory.writeByte(self, address + 1, math_floor(value / 256) % 256)
end

--- Read a 32-bit dword from memory (little-endian).
---@param self Memory The memory instance
---@param address number The memory address
---@return number dword The 32-bit dword value
function Memory.readDWord(self, address)
	return Utils.fromDWords(
		Memory.readByte(self, address),
		Memory.readByte(self, address + 1),
		Memory.readByte(self, address + 2),
		Memory.readByte(self, address + 3)
	)
end

--- Write a 32-bit dword to memory (little-endian).
---@param self Memory The memory instance
---@param address number The memory address
---@param value number The 32-bit value to write
function Memory.writeDWord(self, address, value)
	value = value or 0
	local b0, b1, b2, b3 = Utils.toDWords(value)
	Memory.writeByte(self, address, b0)
	Memory.writeByte(self, address + 1, b1)
	Memory.writeByte(self, address + 2, b2)
	Memory.writeByte(self, address + 3, b3)
end

--- Read a null-terminated string from memory.
---@param self Memory The memory instance
---@param address number The starting address
---@param maxLength number Maximum length to read (default: 4096)
---@return string str The string read from memory
function Memory.readString(self, address, maxLength)
	maxLength = maxLength or 4096
	if address == nil then return "" end
	local result = {}
	for i = 0, maxLength - 1 do
		local byte = Memory.readByte(self, address + i)
		if byte == 0 then break end
		table_insert(result, string_char(byte))
	end
	return table_concat(result)
end

--- Write a null-terminated string to memory.
---@param self Memory The memory instance
---@param address number The starting address
---@param str string The string to write
function Memory.writeString(self, address, str)
	if address == nil or str == nil then return end
	str = tostring(str)
	for i = 1, #str do
		Memory.writeByte(self, address + i - 1, string_byte(str, i))
	end
	Memory.writeByte(self, address + #str, 0)
end

--- Allocate a block of memory on the heap.
---@param self Memory The memory instance
---@param size number Size in bytes to allocate
---@return number address Address of allocated block, or 0 if allocation failed
function Memory.allocate(self, size)
	if size == nil or size <= 0 then return 0 end
	size = math_ceil(size / 4) * 4 -- Align to 4 bytes
	if self.nextHeapAddr + size >= Memory.STACK_START then return 0 end
	local address = self.nextHeapAddr
	self.allocated[address] = size
	self.nextHeapAddr = self.nextHeapAddr + size
	return address
end

--- Free a previously allocated memory block.
---@param self Memory The memory instance
---@param address number Address of the block to free
---@return boolean success True if successfully freed, false otherwise
function Memory.free(self, address)
	if address == nil then return false end
	if self.allocated[address] then
		self.allocated[address] = nil
		return true
	end
	return false
end

--- Clear all memory and reset heap.
---@param self Memory The memory instance
function Memory.clear(self)
	self.data = {}
	self.allocated = {}
	self.nextHeapAddr = Memory.HEAP_START
end

--- Dump a memory region as hex.
---@param self Memory The memory instance
---@param start number Starting address (default: 0)
---@param length number Number of bytes to dump (default: 64)
---@return string dump Hex dump string
function Memory.dump(self, start, length)
	start = start or 0
	length = length or 64
	local lines = {}
	for addr = start, start + length - 1, 16 do
		local hex, ascii = {}, {}
		for i = 0, 15 do
			local byte = Memory.readByte(self, addr + i)
			table_insert(hex, Utils.toHex(byte, 2))
			table_insert(ascii, byte >= 32 and byte < 127 and string_char(byte) or ".")
		end
		table_insert(lines, string_format("%06X: %s  %s", addr, table_concat(hex, " "), table_concat(ascii)))
	end
	return table_concat(lines, "\n")
end

--- Get memory statistics.
---@param self Memory The memory instance
---@return table stats Statistics table with used, free, heapUsed, allocationCount
function Memory.getStats(self)
	local used = 0
	for _ in next, self.data do used = used + 1 end
	local heapUsed = self.nextHeapAddr - Memory.HEAP_START
	local allocCount = 0
	for _ in next, self.allocated do allocCount = allocCount + 1 end
	return {
		bytesUsed = used,
		heapUsed = heapUsed,
		allocationCount = allocCount,
		totalSize = self.size
	}
end

----------------------------------------------------------------------
-- MODULE: REGISTERS
----------------------------------------------------------------------

--- Registers class for VM register state management.<br>
--- Manages general-purpose registers, PC, SP, FP, and flags.
---@class Registers
---@field r table General purpose registers R0-R15.
---@field pc number Program counter.
---@field sp number Stack pointer.
---@field fp number Frame pointer.
---@field flags number Status flags.
---@field ir number Instruction register (last opcode).
local Registers   = {}
Registers.__index = Registers

--- Register count and flag constants.
Registers.COUNT   = 16   -- R0-R15
Registers.FLAG_Z  = 0x01 -- Zero flag
Registers.FLAG_C  = 0x02 -- Carry flag
Registers.FLAG_O  = 0x04 -- Overflow flag
Registers.FLAG_N  = 0x08 -- Negative flag
Registers.FLAG_I  = 0x10 -- Interrupt enable flag

--- Create a new Registers instance.
---@return Registers instance New registers instance with all registers initialized to 0
function Registers.new()
	local r = {}
	for i = 0, Registers.COUNT - 1 do
		r[i] = 0
	end
	return setmetatable({
		r = r,             -- General purpose registers R0-R15
		pc = 0,            -- Program counter
		sp = Memory.STACK_START, -- Stack pointer
		fp = 0,            -- Frame pointer
		flags = 0,         -- Status flags
		ir = 0,            -- Instruction register (last opcode)
	}, Registers)
end

--- Get a register value.
---@param self Registers The registers instance
---@param index number Register index (0-15)
---@return number value The register value
function Registers.get(self, index)
	if index == nil then return 0 end
	index = math_floor(index)
	if index < 0 or index >= Registers.COUNT then return 0 end
	return self.r[index] or 0
end

--- Set a register value.
---@param self Registers The registers instance
---@param index number Register index (0-15)
---@param value number The value to set (will be truncated to 32 bits)
function Registers.set(self, index, value)
	if index == nil then return end
	index = math_floor(index)
	value = value or 0
	if index < 0 or index >= Registers.COUNT then return end
	self.r[index] = math_floor(value) % (2 ^ 32)
end

--- Check if a flag is set.
---@param self Registers The registers instance
---@param flag number The flag bit to check
---@return boolean isSet True if the flag is set
function Registers.isFlagSet(self, flag)
	if flag == nil then return false end
	return bit_band(self.flags, flag) ~= 0
end

--- Set or clear a flag.
---@param self Registers The registers instance
---@param flag number The flag bit to modify
---@param value boolean True to set, false to clear
function Registers.setFlag(self, flag, value)
	if flag == nil then return end
	if value then
		self.flags = bit_bor(self.flags, flag)
	else
		self.flags = bit_band(self.flags, bit_bnot(flag))
	end
end

--- Update flags based on an operation result.
---@param self Registers The registers instance
---@param result number The result of the operation
---@param isSubtraction? boolean True if operation was subtraction (affects carry flag)
function Registers.updateFlags(self, result, isSubtraction)
	if result == nil then result = 0 end
	Registers.setFlag(self, Registers.FLAG_Z, (result % (2 ^ 32)) == 0)
	Registers.setFlag(self, Registers.FLAG_N, result < 0 or bit_band(result, 0x80000000) ~= 0)
	Registers.setFlag(self, Registers.FLAG_C, isSubtraction and result < 0 or result >= (2 ^ 32))
end

--- Reset all registers to initial state.
---@param self Registers The registers instance
function Registers.reset(self)
	for i = 0, Registers.COUNT - 1 do
		self.r[i] = 0
	end
	self.pc = 0
	self.sp = Memory.STACK_START
	self.fp = 0
	self.flags = 0
	self.ir = 0
end

--- Convert register state to string.
---@param self Registers The registers instance
---@return string state Formatted register state
function Registers.toString(self)
	local lines = { "=== Register State ===" }
	for i = 0, 15 do
		table_insert(lines, string_format("R%2d: 0x%08X (%d)", i, self.r[i] or 0, self.r[i] or 0))
	end
	table_insert(lines, string_format("PC:  0x%08X  SP: 0x%08X", self.pc, self.sp))
	table_insert(lines, string_format("FP:  0x%08X  IR: 0x%08X", self.fp, self.ir))
	table_insert(lines, string_format("Flags: [%s%s%s%s%s]",
		Registers.isFlagSet(self, Registers.FLAG_Z) and "Z" or "-",
		Registers.isFlagSet(self, Registers.FLAG_C) and "C" or "-",
		Registers.isFlagSet(self, Registers.FLAG_O) and "O" or "-",
		Registers.isFlagSet(self, Registers.FLAG_N) and "N" or "-",
		Registers.isFlagSet(self, Registers.FLAG_I) and "I" or "-"))
	return table_concat(lines, "\n")
end

----------------------------------------------------------------------
-- MODULE: OPCODES
----------------------------------------------------------------------

-- Forward declarations for opcode handlers
local VM

local OPCODES = {}

--- Define an opcode.
---@param code number The opcode byte value
---@param name string The opcode name
---@param operands number Number of operands
---@param desc string Description
---@param handler function The handler function
local function def(code, name, operands, desc, handler)
	OPCODES[code] = {
		code = code,
		name = name,
		operandCount = operands,
		description = desc,
		handler = handler
	}
	OPCODES[name] = OPCODES[code]
end

-- Control Operations (0x00-0x0F)
def(0x00, "NOP", 0, "No operation", function(vm) end)
def(0x01, "HALT", 0, "Stop execution", function(vm) vm.running = false end)
def(0x02, "BREAK", 0, "Breakpoint", function(vm) print("BREAK at PC=" .. Utils.toHex(vm.registers.pc)) end)
def(0x03, "WAIT", 1, "Wait cycles", function(vm, n) vm.waitCycles = n or 0 end)
def(0x04, "RESET", 0, "Reset system", function(vm) VM.reset(vm) end)
def(0x05, "CPUID", 0, "CPU identification", function(vm) Registers.set(vm.registers, 0, 0x5A564D5A) end)
def(0x06, "IDLE", 0, "Idle", function(vm) end)

-- Data Movement (0x10-0x2F)
def(0x10, "MOV_RR", 2, "Move reg to reg",
	function(vm, d, s) Registers.set(vm.registers, d, Registers.get(vm.registers, s)) end)
def(0x11, "MOV_RI", 2, "Move imm to reg", function(vm, d, v) Registers.set(vm.registers, d, v) end)
def(0x12, "LOAD_R", 2, "Load [reg]",
	function(vm, d, a) Registers.set(vm.registers, d, Memory.readDWord(vm.memory, Registers.get(vm.registers, a))) end)
def(0x13, "LOAD_I", 2, "Load [addr]",
	function(vm, d, a) Registers.set(vm.registers, d, Memory.readDWord(vm.memory, a)) end)
def(0x14, "STORE_R", 2, "Store [reg]",
	function(vm, s, a) Memory.writeDWord(vm.memory, Registers.get(vm.registers, a), Registers.get(vm.registers, s)) end)
def(0x15, "STORE_I", 2, "Store [addr]",
	function(vm, a, s) Memory.writeDWord(vm.memory, a, Registers.get(vm.registers, s)) end)
def(0x16, "LOADB_R", 2, "Load byte [reg]",
	function(vm, d, a) Registers.set(vm.registers, d, Memory.readByte(vm.memory, Registers.get(vm.registers, a))) end)
def(0x17, "STOREB_R", 2, "Store byte [reg]",
	function(vm, a, s) Memory.writeByte(vm.memory, Registers.get(vm.registers, a), Registers.get(vm.registers, s) % 256) end)
def(0x18, "LOADW_R", 2, "Load word [reg]",
	function(vm, d, a) Registers.set(vm.registers, d, Memory.readWord(vm.memory, Registers.get(vm.registers, a))) end)
def(0x19, "STOREW_R", 2, "Store word [reg]",
	function(vm, a, s) Memory.writeWord(vm.memory, Registers.get(vm.registers, a), Registers.get(vm.registers, s)) end)
def(0x1A, "PUSH_R", 1, "Push reg", function(vm, s) VM.push(vm, Registers.get(vm.registers, s)) end)
def(0x1B, "PUSH_I", 1, "Push imm", function(vm, v) VM.push(vm, v) end)
def(0x1C, "POP_R", 1, "Pop to reg", function(vm, d) Registers.set(vm.registers, d, VM.pop(vm)) end)
def(0x1D, "PEEK_R", 1, "Peek stack", function(vm, d) Registers.set(vm.registers, d, VM.peek(vm)) end)
def(0x1E, "SWAP", 2, "Swap regs",
	function(vm, a, b)
		local t = Registers.get(vm.registers, a)
		Registers.set(vm.registers, a, Registers.get(vm.registers, b))
		Registers.set(vm.registers, b, t)
	end)

-- Arithmetic Operations (0x30-0x4F)
def(0x30, "ADD_RR", 3, "Add regs",
	function(vm, d, a, b)
		local r = Registers.get(vm.registers, a) + Registers.get(vm.registers, b)
		Registers.updateFlags(vm.registers, r)
		Registers.set(vm.registers, d, r)
	end)
def(0x31, "ADD_RI", 2, "Add imm",
	function(vm, d, v)
		local r = Registers.get(vm.registers, d) + (v or 0)
		Registers.updateFlags(vm.registers, r)
		Registers.set(vm.registers, d, r)
	end)
def(0x32, "SUB_RR", 3, "Sub regs",
	function(vm, d, a, b)
		local r = Registers.get(vm.registers, a) - Registers.get(vm.registers, b)
		Registers.updateFlags(vm.registers, r, true)
		Registers.set(vm.registers, d, r)
	end)
def(0x33, "SUB_RI", 2, "Sub imm",
	function(vm, d, v)
		local r = Registers.get(vm.registers, d) - (v or 0)
		Registers.updateFlags(vm.registers, r, true)
		Registers.set(vm.registers, d, r)
	end)
def(0x34, "MUL_RR", 3, "Mul regs",
	function(vm, d, a, b)
		local r = Registers.get(vm.registers, a) * Registers.get(vm.registers, b)
		Registers.updateFlags(vm.registers, r)
		Registers.set(vm.registers, d, r)
	end)
def(0x35, "MUL_RI", 2, "Mul imm",
	function(vm, d, v)
		local r = Registers.get(vm.registers, d) * (v or 0)
		Registers.updateFlags(vm.registers, r)
		Registers.set(vm.registers, d, r)
	end)
def(0x36, "DIV_RR", 3, "Div regs",
	function(vm, d, a, b)
		local dv = Registers.get(vm.registers, b)
		if dv == 0 then
			VM.interrupt(vm, "DIV_ZERO")
			return
		end
		local r = math_floor(Registers.get(vm.registers, a) / dv)
		Registers.updateFlags(vm.registers, r)
		Registers.set(vm.registers, d, r)
	end)
def(0x37, "DIV_RI", 2, "Div imm",
	function(vm, d, v)
		if v == nil or v == 0 then
			VM.interrupt(vm, "DIV_ZERO")
			return
		end
		local r = math_floor(Registers.get(vm.registers, d) / v)
		Registers.updateFlags(vm.registers, r)
		Registers.set(vm.registers, d, r)
	end)
def(0x38, "MOD_RR", 3, "Mod regs",
	function(vm, d, a, b)
		local dv = Registers.get(vm.registers, b)
		if dv == 0 then
			VM.interrupt(vm, "DIV_ZERO")
			return
		end
		local r = Registers.get(vm.registers, a) % dv
		Registers.updateFlags(vm.registers, r)
		Registers.set(vm.registers, d, r)
	end)
def(0x39, "MOD_RI", 2, "Mod imm",
	function(vm, d, v)
		if v == nil or v == 0 then
			VM.interrupt(vm, "DIV_ZERO")
			return
		end
		local r = Registers.get(vm.registers, d) % v
		Registers.updateFlags(vm.registers, r)
		Registers.set(vm.registers, d, r)
	end)
def(0x3A, "INC_R", 1, "Increment",
	function(vm, r)
		local v = Registers.get(vm.registers, r) + 1
		Registers.updateFlags(vm.registers, v)
		Registers.set(vm.registers, r, v)
	end)
def(0x3B, "DEC_R", 1, "Decrement",
	function(vm, r)
		local v = Registers.get(vm.registers, r) - 1
		Registers.updateFlags(vm.registers, v, true)
		Registers.set(vm.registers, r, v)
	end)
def(0x3C, "NEG_R", 1, "Negate",
	function(vm, r)
		local v = Registers.get(vm.registers, r)
		if v >= 0x80000000 then v = v - 0x100000000 end
		v = -v
		Registers.updateFlags(vm.registers, v, true)
		Registers.set(vm.registers, r, v)
	end)
def(0x3D, "ABS_R", 1, "Absolute",
	function(vm, r)
		local v = Registers.get(vm.registers, r)
		if v >= 0x80000000 then v = v - 0x100000000 end
		v = math_abs(v)
		Registers.updateFlags(vm.registers, v)
		Registers.set(vm.registers, r, v)
	end)

-- Bitwise Operations (0x50-0x5F)
def(0x50, "AND_RR", 3, "AND regs",
	function(vm, d, a, b)
		local r = bit_band(Registers.get(vm.registers, a), Registers.get(vm.registers, b))
		Registers.updateFlags(vm.registers, r)
		Registers.set(vm.registers, d, r)
	end)
def(0x51, "AND_RI", 2, "AND imm",
	function(vm, d, v)
		local r = bit_band(Registers.get(vm.registers, d), (v or 0))
		Registers.updateFlags(vm.registers, r)
		Registers.set(vm.registers, d, r)
	end)
def(0x52, "OR_RR", 3, "OR regs",
	function(vm, d, a, b)
		local r = bit_bor(Registers.get(vm.registers, a), Registers.get(vm.registers, b))
		Registers.updateFlags(vm.registers, r)
		Registers.set(vm.registers, d, r)
	end)
def(0x53, "OR_RI", 2, "OR imm",
	function(vm, d, v)
		local r = bit_bor(Registers.get(vm.registers, d), (v or 0))
		Registers.updateFlags(vm.registers, r)
		Registers.set(vm.registers, d, r)
	end)
def(0x54, "XOR_RR", 3, "XOR regs",
	function(vm, d, a, b)
		local r = bit_bxor(Registers.get(vm.registers, a), Registers.get(vm.registers, b))
		Registers.updateFlags(vm.registers, r)
		Registers.set(vm.registers, d, r)
	end)
def(0x55, "XOR_RI", 2, "XOR imm",
	function(vm, d, v)
		local r = bit_bxor(Registers.get(vm.registers, d), (v or 0))
		Registers.updateFlags(vm.registers, r)
		Registers.set(vm.registers, d, r)
	end)
def(0x56, "NOT_R", 1, "NOT",
	function(vm, d)
		local r = bit_bnot(Registers.get(vm.registers, d))
		Registers.updateFlags(vm.registers, r)
		Registers.set(vm.registers, d, r)
	end)
def(0x57, "SHL_RR", 3, "Shift left reg",
	function(vm, d, a, b)
		local r = bit_lshift(Registers.get(vm.registers, a), (Registers.get(vm.registers, b) % 32))
		Registers.updateFlags(vm.registers, r)
		Registers.set(vm.registers, d, r)
	end)
def(0x58, "SHL_RI", 2, "Shift left imm",
	function(vm, d, v)
		local r = bit_lshift(Registers.get(vm.registers, d), ((v or 0) % 32))
		Registers.updateFlags(vm.registers, r)
		Registers.set(vm.registers, d, r)
	end)
def(0x59, "SHR_RR", 3, "Shift right reg",
	function(vm, d, a, b)
		local r = bit_rshift(Registers.get(vm.registers, a), (Registers.get(vm.registers, b) % 32))
		Registers.updateFlags(vm.registers, r)
		Registers.set(vm.registers, d, r)
	end)
def(0x5A, "SHR_RI", 2, "Shift right imm",
	function(vm, d, v)
		local r = bit_rshift(Registers.get(vm.registers, d), ((v or 0) % 32))
		Registers.updateFlags(vm.registers, r)
		Registers.set(vm.registers, d, r)
	end)
def(0x5B, "SAR_RR", 3, "Arith shift right",
	function(vm, d, a, b)
		local val, s = Registers.get(vm.registers, a), Registers.get(vm.registers, b) % 32
		local r = bit_rshift(val, s)
		if bit_band(val, 0x80000000) ~= 0 and s > 0 then
			r = bit_bor(r, bit_lshift((bit_lshift(1, s) - 1), (32 - s)))
		end
		Registers.updateFlags(vm.registers, r)
		Registers.set(vm.registers, d, r)
	end)
def(0x5C, "SAR_RI", 2, "Arith shift right imm",
	function(vm, d, v)
		local val, s = Registers.get(vm.registers, d), (v or 0) % 32
		local r = bit_rshift(val, s)
		if bit_band(val, 0x80000000) ~= 0 and s > 0 then
			r = bit_bor(r, bit_lshift((bit_lshift(1, s) - 1), (32 - s)))
		end
		Registers.updateFlags(vm.registers, r)
		Registers.set(vm.registers, d, r)
	end)
def(0x5D, "ROL_RI", 2, "Rotate left",
	function(vm, d, v)
		local val, s = Registers.get(vm.registers, d), (v or 0) % 32
		Registers.set(vm.registers, d,
			bit_band(bit_bor(bit_lshift(val, s), bit_rshift(val, (32 - s))), 0xFFFFFFFF))
	end)
def(0x5E, "ROR_RI", 2, "Rotate right",
	function(vm, d, v)
		local val, s = Registers.get(vm.registers, d), (v or 0) % 32
		Registers.set(vm.registers, d,
			bit_band(bit_bor(bit_rshift(val, s), bit_lshift(val, (32 - s))), 0xFFFFFFFF))
	end)

-- Comparison Operations (0x60-0x6F)
def(0x60, "CMP_RR", 2, "Compare regs",
	function(vm, a, b)
		Registers.updateFlags(vm.registers,
			Registers.get(vm.registers, a) - Registers.get(vm.registers, b), true)
	end)
def(0x61, "CMP_RI", 2, "Compare imm",
	function(vm, r, v)
		Registers.updateFlags(vm.registers,
			Registers.get(vm.registers, r) - (v or 0), true)
	end)
def(0x62, "TEST_RR", 2, "Test regs",
	function(vm, a, b)
		Registers.updateFlags(vm.registers,
			bit_band(Registers.get(vm.registers, a), Registers.get(vm.registers, b)))
	end)
def(0x63, "TEST_RI", 2, "Test imm",
	function(vm, r, v)
		Registers.updateFlags(vm.registers,
			bit_band(Registers.get(vm.registers, r), (v or 0)))
	end)

-- Jump Operations (0x70-0x7F)
def(0x70, "JMP_I", 1, "Jump", function(vm, a) vm.registers.pc = a or 0 end)
def(0x71, "JMP_R", 1, "Jump reg", function(vm, r) vm.registers.pc = Registers.get(vm.registers, r) end)
def(0x72, "JZ_I", 1, "Jump if zero",
	function(vm, a) if Registers.isFlagSet(vm.registers, Registers.FLAG_Z) then vm.registers.pc = a or 0 end end)
def(0x73, "JNZ_I", 1, "Jump if not zero",
	function(vm, a) if not Registers.isFlagSet(vm.registers, Registers.FLAG_Z) then vm.registers.pc = a or 0 end end)
def(0x74, "JC_I", 1, "Jump if carry",
	function(vm, a) if Registers.isFlagSet(vm.registers, Registers.FLAG_C) then vm.registers.pc = a or 0 end end)
def(0x75, "JNC_I", 1, "Jump if no carry",
	function(vm, a) if not Registers.isFlagSet(vm.registers, Registers.FLAG_C) then vm.registers.pc = a or 0 end end)
def(0x76, "JN_I", 1, "Jump if neg",
	function(vm, a) if Registers.isFlagSet(vm.registers, Registers.FLAG_N) then vm.registers.pc = a or 0 end end)
def(0x77, "JNN_I", 1, "Jump if not neg",
	function(vm, a) if not Registers.isFlagSet(vm.registers, Registers.FLAG_N) then vm.registers.pc = a or 0 end end)
def(0x78, "JO_I", 1, "Jump if overflow",
	function(vm, a) if Registers.isFlagSet(vm.registers, Registers.FLAG_O) then vm.registers.pc = a or 0 end end)
def(0x79, "JNO_I", 1, "Jump if no overflow",
	function(vm, a) if not Registers.isFlagSet(vm.registers, Registers.FLAG_O) then vm.registers.pc = a or 0 end end)
def(0x7A, "JGT_I", 1, "Jump if greater",
	function(vm, a)
		if not Registers.isFlagSet(vm.registers, Registers.FLAG_Z) and not Registers.isFlagSet(vm.registers, Registers.FLAG_N) then
			vm.registers.pc = a or 0
		end
	end)
def(0x7B, "JLT_I", 1, "Jump if less",
	function(vm, a) if Registers.isFlagSet(vm.registers, Registers.FLAG_N) then vm.registers.pc = a or 0 end end)
def(0x7C, "JGE_I", 1, "Jump if ge",
	function(vm, a) if not Registers.isFlagSet(vm.registers, Registers.FLAG_N) then vm.registers.pc = a or 0 end end)
def(0x7D, "JLE_I", 1, "Jump if le",
	function(vm, a)
		if Registers.isFlagSet(vm.registers, Registers.FLAG_Z) or Registers.isFlagSet(vm.registers, Registers.FLAG_N) then
			vm.registers.pc = a or 0
		end
	end)

-- Subroutine Operations (0x80-0x8F)
def(0x80, "CALL_I", 1, "Call",
	function(vm, a)
		VM.push(vm, vm.registers.pc)
		VM.push(vm, vm.registers.fp)
		vm.registers.fp = vm.registers.sp
		vm.registers.pc = a or 0
	end)
def(0x81, "CALL_R", 1, "Call reg",
	function(vm, r)
		VM.push(vm, vm.registers.pc)
		VM.push(vm, vm.registers.fp)
		vm.registers.fp = vm.registers.sp
		vm.registers.pc = Registers.get(vm.registers, r)
	end)
def(0x82, "RET", 0, "Return",
	function(vm)
		vm.registers.sp = vm.registers.fp
		vm.registers.fp = VM.pop(vm)
		vm.registers.pc = VM.pop(vm)
	end)
def(0x83, "RET_I", 1, "Return pop",
	function(vm, n)
		vm.registers.sp = vm.registers.fp
		vm.registers.fp = VM.pop(vm)
		vm.registers.pc = VM.pop(vm)
		vm.registers.sp = vm.registers.sp + (n or 0)
	end)
def(0x84, "ENTER", 1, "Enter frame",
	function(vm, n)
		VM.push(vm, vm.registers.fp)
		vm.registers.fp = vm.registers.sp
		vm.registers.sp = vm.registers.sp - (n or 0)
	end)
def(0x85, "LEAVE", 0, "Leave frame", function(vm)
	vm.registers.sp = vm.registers.fp
	vm.registers.fp = VM.pop(vm)
end)

-- System Operations (0x90-0x9F)
def(0x90, "SYSCALL", 1, "System call", function(vm, c) VM.syscall(vm, c) end)
def(0x91, "INT", 1, "Interrupt", function(vm, v) VM.interrupt(vm, v) end)
def(0x92, "IRET", 0, "Return int", function(vm)
	vm.registers.pc = VM.pop(vm)
	vm.registers.flags = VM.pop(vm)
end)
def(0x93, "CLI", 0, "Disable ints", function(vm) Registers.setFlag(vm.registers, Registers.FLAG_I, false) end)
def(0x94, "STI", 0, "Enable ints", function(vm) Registers.setFlag(vm.registers, Registers.FLAG_I, true) end)

-- Extended Operations (0xA0-0xAF)
def(0xA0, "MALLOC", 2, "Alloc mem",
	function(vm, d, s) Registers.set(vm.registers, d, Memory.allocate(vm.memory, Registers.get(vm.registers, s))) end)
def(0xA1, "FREE", 1, "Free mem", function(vm, s) Memory.free(vm.memory, Registers.get(vm.registers, s)) end)
def(0xA2, "MEMCPY", 3, "Copy mem",
	function(vm, d, s, n)
		local dst, src, c =
			Registers.get(vm.registers, d),
			Registers.get(vm.registers, s),
			Registers.get(vm.registers, n)
		for i = 0, c - 1 do
			Memory.writeByte(vm.memory, dst + i, Memory.readByte(vm.memory, src + i))
		end
	end)
def(0xA3, "MEMSET", 3, "Set mem",
	function(vm, d, v, n)
		local a, val, c =
			Registers.get(vm.registers, d),
			Registers.get(vm.registers, v) % 256,
			Registers.get(vm.registers, n)
		for i = 0, c - 1 do
			Memory.writeByte(vm.memory, a + i, val)
		end
	end)
def(0xA4, "MEMCMP", 4, "Cmp mem",
	function(vm, d, a1, a2, n)
		local aa1, aa2, c =
			Registers.get(vm.registers, a1),
			Registers.get(vm.registers, a2),
			Registers.get(vm.registers, n)
		for i = 0, c - 1 do
			local b1, b2 = Memory.readByte(vm.memory, aa1 + i), Memory.readByte(vm.memory, aa2 + i)
			if b1 < b2 then
				Registers.set(vm.registers, d, -1)
				return
			end
			if b1 > b2 then
				Registers.set(vm.registers, d, 1)
				return
			end
		end
		Registers.set(vm.registers, d, 0)
	end)
def(0xA5, "LEA", 2, "Load eff addr", function(vm, d, a) Registers.set(vm.registers, d, a) end)

-- String Operations (0xB0-0xBF)
def(0xB0, "STRLEN", 2, "String len",
	function(vm, d, a)
		local addr, l = Registers.get(vm.registers, a), 0
		while Memory.readByte(vm.memory, addr + l) ~= 0 do
			l = l + 1
		end
		Registers.set(vm.registers, d, l)
	end)
def(0xB1, "STRCPY", 2, "String copy",
	function(vm, d, s)
		local dst, src, i = Registers.get(vm.registers, d), Registers.get(vm.registers, s), 0
		while true do
			local b = Memory.readByte(vm.memory, src + i)
			Memory.writeByte(vm.memory, dst + i, b)
			if b == 0 then break end
			i = i + 1
		end
	end)
def(0xB2, "STRCAT", 2, "String cat",
	function(vm, d, s)
		local dst, src = Registers.get(vm.registers, d), Registers.get(vm.registers, s)
		while Memory.readByte(vm.memory, dst) ~= 0 do
			dst = dst + 1
		end
		local i = 0
		while true do
			local b = Memory.readByte(vm.memory, src + i)
			Memory.writeByte(vm.memory, dst + i, b)
			if b == 0 then break end
			i = i + 1
		end
	end)
def(0xB3, "STRCMP", 3, "String cmp",
	function(vm, d, a1, a2)
		local s1, s2 = Registers.get(vm.registers, a1), Registers.get(vm.registers, a2)
		local i = 0
		while true do
			local b1, b2 = Memory.readByte(vm.memory, s1 + i), Memory.readByte(vm.memory, s2 + i)
			if b1 < b2 then
				Registers.set(vm.registers, d, -1)
				return
			end
			if b1 > b2 then
				Registers.set(vm.registers, d, 1)
				return
			end
			if b1 == 0 then
				Registers.set(vm.registers, d, 0)
				return
			end
			i = i + 1
		end
	end)

-- Floating Point Operations (0xC0-0xCF)
def(0xC0, "FADD_RR", 3, "Float add",
	function(vm, d, a, b)
		Registers.set(vm.registers, d,
			VM.floatToInt(vm,
				VM.intToFloat(vm, Registers.get(vm.registers, a)) + VM.intToFloat(vm, Registers.get(vm.registers, b))))
	end)
def(0xC1, "FSUB_RR", 3, "Float sub",
	function(vm, d, a, b)
		Registers.set(vm.registers, d,
			VM.floatToInt(vm,
				VM.intToFloat(vm, Registers.get(vm.registers, a)) - VM.intToFloat(vm, Registers.get(vm.registers, b))))
	end)
def(0xC2, "FMUL_RR", 3, "Float mul",
	function(vm, d, a, b)
		Registers.set(vm.registers, d,
			VM.floatToInt(vm,
				VM.intToFloat(vm, Registers.get(vm.registers, a)) * VM.intToFloat(vm, Registers.get(vm.registers, b))))
	end)
def(0xC3, "FDIV_RR", 3, "Float div",
	function(vm, d, a, b)
		local f2 = VM.intToFloat(vm, Registers.get(vm.registers, b))
		if f2 == 0 then
			VM.interrupt(vm, "FP_DIV_ZERO")
			return
		end
		Registers.set(vm.registers, d, VM.floatToInt(vm, VM.intToFloat(vm, Registers.get(vm.registers, a)) / f2))
	end)
def(0xC4, "FSQRT_R", 2, "Float sqrt",
	function(vm, d, s)
		Registers.set(vm.registers, d,
			VM.floatToInt(vm, math_sqrt(VM.intToFloat(vm, Registers.get(vm.registers, s)))))
	end)
def(0xC5, "FSIN_R", 2, "Float sin",
	function(vm, d, s)
		Registers.set(vm.registers, d,
			VM.floatToInt(vm, math.sin(VM.intToFloat(vm, Registers.get(vm.registers, s)))))
	end)
def(0xC6, "FCOS_R", 2, "Float cos",
	function(vm, d, s)
		Registers.set(vm.registers, d,
			VM.floatToInt(vm, math.cos(VM.intToFloat(vm, Registers.get(vm.registers, s)))))
	end)
def(0xC7, "FTAN_R", 2, "Float tan",
	function(vm, d, s)
		Registers.set(vm.registers, d,
			VM.floatToInt(vm, math.tan(VM.intToFloat(vm, Registers.get(vm.registers, s)))))
	end)
def(0xC8, "FLOOR_R", 2, "Float floor",
	function(vm, d, s) Registers.set(vm.registers, d, math_floor(VM.intToFloat(vm, Registers.get(vm.registers, s)))) end)
def(0xC9, "CEIL_R", 2, "Float ceil",
	function(vm, d, s) Registers.set(vm.registers, d, math_ceil(VM.intToFloat(vm, Registers.get(vm.registers, s)))) end)
def(0xCA, "ROUND_R", 2, "Float round",
	function(vm, d, s) Registers.set(vm.registers, d, math_floor(VM.intToFloat(vm, Registers.get(vm.registers, s)) + 0.5)) end)
def(0xCB, "ITOF_R", 2, "Int to float",
	function(vm, d, s) Registers.set(vm.registers, d, VM.floatToInt(vm, Registers.get(vm.registers, s) * 1.0)) end)

-- Vector Operations (0xD0-0xDF)
def(0xD0, "VADD_4", 3, "Vec add 4",
	function(vm, d, a, b)
		local dst, aa, bb =
			Registers.get(vm.registers, d),
			Registers.get(vm.registers, a),
			Registers.get(vm.registers, b)
		for i = 0, 3 do
			Memory.writeDWord(vm.memory, dst + i * 4,
				Memory.readDWord(vm.memory, aa + i * 4) + Memory.readDWord(vm.memory, bb + i * 4))
		end
	end)
def(0xD1, "VSUB_4", 3, "Vec sub 4",
	function(vm, d, a, b)
		local dst, aa, bb =
			Registers.get(vm.registers, d),
			Registers.get(vm.registers, a),
			Registers.get(vm.registers, b)
		for i = 0, 3 do
			Memory.writeDWord(vm.memory, dst + i * 4,
				Memory.readDWord(vm.memory, aa + i * 4) - Memory.readDWord(vm.memory, bb + i * 4))
		end
	end)
def(0xD2, "VMUL_4", 3, "Vec mul 4",
	function(vm, d, a, b)
		local dst, aa, bb =
			Registers.get(vm.registers, d),
			Registers.get(vm.registers, a),
			Registers.get(vm.registers, b)
		for i = 0, 3 do
			Memory.writeDWord(vm.memory, dst + i * 4,
				Memory.readDWord(vm.memory, aa + i * 4) * Memory.readDWord(vm.memory, bb + i * 4))
		end
	end)
def(0xD3, "VDP_4", 3, "Vec dot 4",
	function(vm, d, a, b)
		local aa, bb, sum =
			Registers.get(vm.registers, a),
			Registers.get(vm.registers, b),
			0
		for i = 0, 3 do
			sum = sum +
				Memory.readDWord(vm.memory, aa + i * 4) * Memory.readDWord(vm.memory, bb + i * 4)
		end
		Registers.set(vm.registers, d, sum)
	end)

-- Loop Operations (0xE0-0xEF)
def(0xE0, "LOOP", 2, "Loop",
	function(vm, c, a)
		local v = Registers.get(vm.registers, c) - 1
		Registers.set(vm.registers, c, v)
		if v ~= 0 then
			vm.registers.pc = a or 0
		end
	end)
def(0xE1, "LOOPZ", 2, "Loop if z",
	function(vm, c, a)
		local v = Registers.get(vm.registers, c) - 1
		Registers.set(vm.registers, c, v)
		if v ~= 0 and Registers.isFlagSet(vm.registers, Registers.FLAG_Z) then
			vm.registers.pc = a or 0
		end
	end)
def(0xE2, "LOOPNZ", 2, "Loop if nz",
	function(vm, c, a)
		local v = Registers.get(vm.registers, c) - 1
		Registers.set(vm.registers, c, v)
		if v ~= 0 and not Registers.isFlagSet(vm.registers, Registers.FLAG_Z) then
			vm.registers.pc = a or 0
		end
	end)

-- Debug Operations (0xF0-0xFF)
def(0xF0, "DEBUG_REG", 1, "Debug reg",
	function(vm, r) print("DEBUG R" .. r .. " = " .. Registers.get(vm.registers, r)) end)
def(0xF1, "DEBUG_MEM", 2, "Debug mem",
	function(vm, a, n) print(Memory.dump(vm.memory, Registers.get(vm.registers, a), n)) end)
def(0xF2, "PROFILE_START", 0, "Start profile", function(vm) vm.profileStart = os_clock() end)
def(0xF3, "PROFILE_END", 1, "End profile",
	function(vm, d) Registers.set(vm.registers, d, os_clock() - vm.profileStart) end)
def(0xFF, "EXTENDED", 0, "Extended", function(vm) vm.extendedMode = true end)

----------------------------------------------------------------------
-- MODULE: VM
----------------------------------------------------------------------

-- Forward declarations for modules defined later
local Assembler
local Disassembler
local Builder

--- Virtual Machine class for executing bytecode.<br>
--- Provides program execution, debugging, and state management.
---@class VM
---@field memory Memory The memory instance.
---@field registers Registers The registers instance.
---@field running boolean Whether the VM is currently running.
---@field halted boolean Whether the VM has halted.
---@field cycles number Number of cycles executed.
---@field maxCycles number Maximum cycles before auto-halt.
---@field waitCycles number Cycles to wait before next instruction.
---@field extendedMode boolean Whether extended mode is enabled.
---@field debugMode boolean Whether debug mode is enabled.
---@field breakpoints table Map of breakpoint addresses.
---@field ioHandlers table I/O handler functions.
---@field interruptHandlers table Interrupt handler functions.
---@field syscallHandlers table Syscall handler functions.
---@field profileStart number Profile start timestamp.
---@field instructionCount number Total instructions executed.
VM = {}
VM.__index = VM
VM.VERSION = "1.0.0"

--- Create a new VM instance.
---@return VM instance New virtual machine instance
function VM.new()
	local self = setmetatable({
		memory = Memory.new(),
		registers = Registers.new(),
		running = false,
		halted = false,
		cycles = 0,
		maxCycles = 10000000,
		waitCycles = 0,
		extendedMode = false,
		debugMode = false,
		breakpoints = {},
		ioHandlers = {
			input = function() return io.read() end,
			output = function(s) io.write(s) end,
			error = function(s) io_stderr.write(io_stderr, s .. "\n") end,
		},
		interruptHandlers = {},
		syscallHandlers = {},
		profileStart = 0,
		instructionCount = 0,
	}, VM)
	VM.setDefaultHandlers(self)
	return self
end

--- Set default interrupt and syscall handlers.
---@param self VM The VM instance
function VM.setDefaultHandlers(self)
	self.interruptHandlers = {
		DIV_ZERO = function()
			self.ioHandlers.error("DIV_ZERO at PC=" .. Utils.toHex(self.registers.pc))
			self.running = false
		end,
		FP_DIV_ZERO = function()
			self.ioHandlers.error("FP_DIV_ZERO at PC=" .. Utils.toHex(self.registers.pc))
			self.running = false
		end,
		INVALID_OPCODE = function()
			self.ioHandlers.error("INVALID_OPCODE at PC=" .. Utils.toHex(self.registers.pc))
			self.running = false
		end,
	}
	self.syscallHandlers = {
		[0x00] = function() self.running = false end,                                                               -- EXIT
		[0x01] = function() self.ioHandlers.output(tostring(Registers.get(self.registers, 0))) end,                 -- PRINT_INT
		[0x02] = function() self.ioHandlers.output(string_char(Registers.get(self.registers, 0) % 256)) end,        -- PRINT_CHAR
		[0x03] = function() self.ioHandlers.output(Memory.readString(self.memory, Registers.get(self.registers, 0))) end, -- PRINT_STRING
		[0x04] = function() self.ioHandlers.output("\n") end,                                                       -- PRINT_NEWLINE
		[0x05] = function() Registers.set(self.registers, 0, tonumber(self.ioHandlers.input()) or 0) end,           -- READ_INT
		[0x06] = function() Registers.set(self.registers, 0, string_byte(self.ioHandlers.input() or "\0", 1)) end,  -- READ_CHAR
		[0x07] = function()                                                                                         -- READ_STRING
			local str = self.ioHandlers.input() or ""
			Memory.writeString(self.memory, Registers.get(self.registers, 0), str)
			Registers.set(self.registers, 1, #str)
		end,
		[0x10] = function() Registers.set(self.registers, 0, os_time()) end,   -- TIME
		[0x11] = function() Registers.set(self.registers, 0, os_clock() * 1000) end, -- CLOCK
		[0x20] = function()
			Registers.set(self.registers, 1,
				Memory.allocate(self.memory, Registers.get(self.registers, 0)))
		end,                                                                            -- MALLOC
		[0x21] = function() Memory.free(self.memory, Registers.get(self.registers, 0)) end, -- FREE
		[0x30] = function() Registers.set(self.registers, 0, math_random(0, 0xFFFFFFFF)) end, -- RANDOM
		[0x31] = function()
			Registers.set(self.registers, 2,
				math_random(Registers.get(self.registers, 0), Registers.get(self.registers, 1)))
		end, -- RANDOM_RANGE
	}
end

--- Load a program into memory.
---@param self VM The VM instance
---@param program table Array of bytes
---@param startAddress number Optional start address (default: 0)
function VM.loadProgram(self, program, startAddress)
	startAddress = startAddress or 0
	for i = 1, #program do
		Memory.writeByte(self.memory, startAddress + i - 1, program[i])
	end
	self.registers.pc = startAddress
end

--- Load a binary file into memory.
---@param self VM The VM instance
---@param filename string Path to the binary file
---@param startAddress number Optional start address (default: 0)
function VM.loadFile(self, filename, startAddress)
	local file = io_open(filename, "rb")
	if not file then return error("Cannot open file: " .. filename) end
	local data = file.read(file, "*a")
	file.close(file)

	startAddress = startAddress or 0
	for i = 1, #data do
		Memory.writeByte(self.memory, startAddress + i - 1, string_byte(data, i))
	end
	self.registers.pc = startAddress
end

--- Push a value onto the stack.
---@param self VM The VM instance
---@param value number The value to push
function VM.push(self, value)
	self.registers.sp = self.registers.sp - 4
	Memory.writeDWord(self.memory, self.registers.sp, value)
end

--- Pop a value from the stack.
---@param self VM The VM instance
---@return number value The popped value
function VM.pop(self)
	local value = Memory.readDWord(self.memory, self.registers.sp)
	self.registers.sp = self.registers.sp + 4
	return value
end

--- Peek at the top of the stack without popping.
---@param self VM The VM instance
---@return number value The value at the top of the stack
function VM.peek(self)
	return Memory.readDWord(self.memory, self.registers.sp)
end

--- Trigger an interrupt.
---@param self VM The VM instance
---@param vector string The interrupt vector name
function VM.interrupt(self, vector)
	local handler = self.interruptHandlers[vector]
	if handler then
		handler()
	else
		self.ioHandlers.error("Unhandled interrupt: " .. tostring(vector))
	end
end

--- Execute a system call.
---@param self VM The VM instance
---@param code number The system call code
function VM.syscall(self, code)
	local handler = self.syscallHandlers[code]
	if handler then
		handler()
	else
		self.ioHandlers.error("Unknown syscall: 0x" .. Utils.toHex(code, 2))
	end
end

--- Execute a single instruction.
---@param self VM The VM instance
---@return boolean success True if successful, false if error
function VM.step(self)
	local opcode = Memory.readByte(self.memory, self.registers.pc)
	self.registers.ir = opcode
	local pc = self.registers.pc
	self.registers.pc = self.registers.pc + 1

	if self.breakpoints[pc] then
		self.ioHandlers.output("Breakpoint at " .. Utils.toHex(pc) .. "\n")
	end

	local opdef = OPCODES[opcode]
	if not opdef then
		VM.interrupt(self, "INVALID_OPCODE")
		return false
	end

	local operands = {}
	for i = 1, opdef.operandCount do
		operands[i] = Memory.readDWord(self.memory, self.registers.pc)
		self.registers.pc = self.registers.pc + 4
	end

	opdef.handler(self, table_unpack(operands))
	self.cycles = self.cycles + 1
	self.instructionCount = self.instructionCount + 1
	return true
end

--- Run the VM until halt or max cycles.
---@param self VM The VM instance
---@param maxCycles? number Optional maximum cycles (default: `self.maxCycles`)
function VM.run(self, maxCycles)
	maxCycles = maxCycles or self.maxCycles
	self.running = true
	self.halted = false

	while self.running and self.cycles < maxCycles do
		if self.waitCycles > 0 then
			self.waitCycles = self.waitCycles - 1
			self.cycles = self.cycles + 1
		else
			if not VM.step(self) then break end
		end
	end

	if self.cycles >= maxCycles then
		self.ioHandlers.error("Max cycles reached")
	end
	self.running = false
	self.halted = true
end

--- Reset the VM to initial state.
---@param self VM The VM instance
function VM.reset(self)
	Memory.clear(self.memory)
	Registers.reset(self.registers)
	self.running = false
	self.halted = false
	self.cycles = 0
	self.waitCycles = 0
	self.instructionCount = 0
end

--- Set a breakpoint at an address.
---@param self VM The VM instance
---@param address number The address to break at
function VM.setBreakpoint(self, address)
	self.breakpoints[address] = true
end

--- Clear a breakpoint.
---@param self VM The VM instance
---@param address number The address to clear
function VM.clearBreakpoint(self, address)
	self.breakpoints[address] = nil
end

--- Clear all breakpoints.
---@param self VM The VM instance
function VM.clearAllBreakpoints(self)
	self.breakpoints = {}
end

--- Convert IEEE 754 integer representation to float.
---@param self VM The VM instance
---@param i number Integer representation of float
---@return number value Float value
function VM.intToFloat(self, i)
	if i == nil then return 0.0 end
	i = math_floor(i) % (2 ^ 32)

	local sign = math_floor(i / 0x80000000)
	local exp = math_floor((i % 0x80000000) / 0x800000)
	local mantissa = i % 0x800000

	if exp == 0 then
		if mantissa == 0 then
			return sign == 0 and 0.0 or -0.0
		end
		return (sign == 0 and 1 or -1) * (mantissa / 0x800000) * (2 ^ -126)
	end
	if exp == 255 then
		if mantissa == 0 then
			return sign == 0 and math_huge or -math_huge
		end
		return 0 / 0 -- NaN
	end
	return (sign == 0 and 1 or -1) * (1 + mantissa / 0x800000) * (2 ^ (exp - 127))
end

--- Convert float to IEEE 754 integer representation.
---@param self VM The VM instance
---@param f number Float value
---@return number representation Integer representation
function VM.floatToInt(self, f)
	if f == nil then return 0 end
	if f == 0 then return 0 end

	local sign = 0
	if f < 0 then
		sign = 1
		f = -f
	end

	if f == math_huge then return sign * 0x80000000 + 0x7F800000 end
	if f ~= f then return 0x7FC00000 end -- NaN

	local exp = math_floor(math_log(f, 2))
	local mantissa = f / (2 ^ exp) - 1

	if exp > 127 then
		exp = 127
	elseif exp < -126 then
		exp = -126
	end

	return sign * 0x80000000 + (exp + 127) * 0x800000 + math_floor(mantissa * 0x800000 + 0.5)
end

--- Get VM state as string.
---@param self VM The VM instance
---@return string state Formatted VM state
function VM.toString(self)
	local lines = {
		"=== CHEATOID VIRTUAL MACHINE v" .. VM.VERSION .. " ===",
		"Status: " .. (self.running and "Running" or "Stopped"),
		"Cycles: " .. self.cycles,
		"Instructions: " .. self.instructionCount,
		"",
		Registers.toString(self.registers)
	}
	return table_concat(lines, "\n")
end

--- Get VM statistics.
---@param self VM The VM instance
---@return table stats Statistics table
function VM.getStats(self)
	return {
		running = self.running,
		halted = self.halted,
		cycles = self.cycles,
		instructions = self.instructionCount,
		memory = Memory.getStats(self.memory),
		pc = self.registers.pc,
		sp = self.registers.sp
	}
end

----------------------------------------------------------------------
-- CONVENIENCE APIs
----------------------------------------------------------------------

--- Set a register value directly.
---@param self VM The VM instance
---@param index number Register index (0-15)
---@param value number The value to set
function VM.setRegister(self, index, value)
	Registers.set(self.registers, index, value)
end

--- Get a register value.
---@param self VM The VM instance
---@param index number Register index (0-15)
---@return number value The register value
function VM.getRegister(self, index)
	return Registers.get(self.registers, index)
end

--- Write a value to memory.
---@param self VM The VM instance
---@param address number Memory address
---@param value number Value to write (32-bit)
function VM.writeMemory(self, address, value)
	Memory.writeDWord(self.memory, address, value)
end

--- Read a value from memory.
---@param self VM The VM instance
---@param address number Memory address
---@return number value Value at address
function VM.readMemory(self, address)
	return Memory.readDWord(self.memory, address)
end

--- Write a string to memory.
---@param self VM The VM instance
---@param address number Memory address
---@param str string String to write
function VM.writeString(self, address, str)
	Memory.writeString(self.memory, address, str)
end

--- Read a string from memory.
---@param self VM The VM instance
---@param address number Memory address
---@return string str String read from memory
function VM.readString(self, address)
	return Memory.readString(self.memory, address)
end

--- Print output (convenience for syscall 0x01).
---@param self VM The VM instance
---@param value number Value to print
function VM.print(self, value)
	self.ioHandlers.output(tostring(value))
end

--- Print a newline.
---@param self VM The VM instance
function VM.printNewline(self)
	self.ioHandlers.output("\n")
end

--- Print a string.
---@param self VM The VM instance
---@param str string String to print
function VM.printString(self, str)
	self.ioHandlers.output(str)
end

--- Call a function at an address.
---@param self VM The VM instance
---@param address number Function address
---@param args table Optional array of arguments to put in registers
---@return number value Return value (from R0)
function VM.call(self, address, args)
	-- Save current state
	local savedPc = self.registers.pc
	local savedFp = self.registers.fp
	local savedSp = self.registers.sp

	-- Set arguments
	if args then
		for i = 1, #args do
			if i <= 16 then
				Registers.set(self.registers, i - 1, args[i])
			end
		end
	end

	-- Push return address and call
	VM.push(self, 0xFFFFFFFF) -- Sentinel return address
	VM.push(self, savedFp)
	self.registers.fp = self.registers.sp
	self.registers.pc = address

	-- Run until return or halt
	local maxIter = 1000000
	local iter = 0
	while self.running and iter < maxIter do
		if self.registers.pc == 0xFFFFFFFF then
			-- Returned to sentinel
			break
		end
		VM.step(self)
		iter = iter + 1
	end

	-- Get return value
	local result = Registers.get(self.registers, 0)

	-- Restore state
	self.registers.pc = savedPc
	self.registers.sp = savedSp
	self.registers.fp = savedFp
	self.running = true

	return result
end

--- Get a register value by name string.
---@param self VM The VM instance
---@param name string Register name (e.g., "R0", "R15", "PC", "SP", "FP", "FLAGS")
---@return number? value The register value, or nil if invalid name
function VM.getRegisterByName(self, name)
	if name == nil then return nil end
	name = string_upper(tostring(name))
	local num = string_match(name, "^R(%d+)$")
	if num then
		local n = tonumber(num)
		if n and n >= 0 and n <= 15 then
			return Registers.get(self.registers, n)
		end
		return nil
	end
	if name == "PC" then
		return self.registers.pc
	end
	if name == "SP" then
		return self.registers.sp
	end
	if name == "FP" then
		return self.registers.fp
	end
	if name == "FLAGS" then
		return self.registers.flags
	end
end

--- Set a register value by name string.
---@param self VM The VM instance
---@param name string Register name (e.g., "R0", "R15", "PC", "SP", "FP")
---@param value number Value to set
---@return boolean success True if successful, false if invalid name
function VM.setRegisterByName(self, name, value)
	if name == nil then return false end
	name = string_upper(tostring(name))
	value = value or 0
	local num = string_match(name, "^R(%d+)$")
	if num then
		local n = tonumber(num)
		if n and n >= 0 and n <= 15 then
			Registers.set(self.registers, n, value)
			return true
		end
		return false
	end
	if name == "PC" then
		self.registers.pc = math_floor(value) % (2 ^ 32)
		return true
	end
	if name == "SP" then
		self.registers.sp = math_floor(value) % (2 ^ 32)
		return true
	end
	if name == "FP" then
		self.registers.fp = math_floor(value) % (2 ^ 32)
		return true
	end
	return false
end

--- Read a chunk of memory as a byte array.
---@param self VM The VM instance
---@param address number Starting address
---@param count number Number of bytes to read
---@return table array Array of byte values
function VM.readBytes(self, address, count)
	if address == nil or count == nil then return {} end
	local result = {}
	for i = 0, count - 1 do
		table_insert(result, Memory.readByte(self.memory, address + i))
	end
	return result
end

--- Write a chunk of memory from a byte array.
---@param self VM The VM instance
---@param address number Starting address
---@param bytes table Array of byte values to write
function VM.writeBytes(self, address, bytes)
	if address == nil or bytes == nil then return end
	for i = 1, #bytes do
		Memory.writeByte(self.memory, address + i - 1, bytes[i])
	end
end

--- Load a program from a byte array into memory.
---@param self VM The VM instance
---@param program table Array of byte values
---@param startAddress number Optional start address (default: 0)
function VM.loadBytes(self, program, startAddress)
	startAddress = startAddress or 0
	VM.writeBytes(self, startAddress, program)
end

--- Get a snapshot of the current VM state.
---@param self VM The VM instance
---@return table snapshot State snapshot with registers, flags, and PC/SP/FP
function VM.getState(self)
	local state = {
		registers = {},
		pc = self.registers.pc,
		sp = self.registers.sp,
		fp = self.registers.fp,
		flags = self.registers.flags,
		running = self.running,
		halted = self.halted,
		cycles = self.cycles
	}
	for i = 0, 15 do
		state.registers[i] = self.registers.r[i]
	end
	return state
end

--- Restore VM state from a snapshot.
---@param self VM The VM instance
---@param state table State snapshot from getState()
function VM.setState(self, state)
	if state == nil then return end
	for i = 0, 15 do
		self.registers.r[i] = state.registers[i] or 0
	end
	self.registers.pc = state.pc or 0
	self.registers.sp = state.sp or Memory.STACK_START
	self.registers.fp = state.fp or 0
	self.registers.flags = state.flags or 0
	self.running = state.running or false
	self.halted = state.halted or false
	self.cycles = state.cycles or 0
end

--- Get flag values as a table.
---@param self VM The VM instance
---@return table flags Table with Z, C, O, N, I boolean values
function VM.getFlags(self)
	return {
		Z = Registers.isFlagSet(self.registers, Registers.FLAG_Z),
		C = Registers.isFlagSet(self.registers, Registers.FLAG_C),
		O = Registers.isFlagSet(self.registers, Registers.FLAG_O),
		N = Registers.isFlagSet(self.registers, Registers.FLAG_N),
		I = Registers.isFlagSet(self.registers, Registers.FLAG_I)
	}
end

--- Set flags explicitly.
---@param self VM The VM instance
---@param z boolean Zero flag (optional)
---@param c boolean Carry flag (optional)
---@param o boolean Overflow flag (optional)
---@param n boolean Negative flag (optional)
---@param i boolean Interrupt enable flag (optional)
function VM.setFlags(self, z, c, o, n, i)
	if z ~= nil then Registers.setFlag(self.registers, Registers.FLAG_Z, z) end
	if c ~= nil then Registers.setFlag(self.registers, Registers.FLAG_C, c) end
	if o ~= nil then Registers.setFlag(self.registers, Registers.FLAG_O, o) end
	if n ~= nil then Registers.setFlag(self.registers, Registers.FLAG_N, n) end
	if i ~= nil then Registers.setFlag(self.registers, Registers.FLAG_I, i) end
end

--- Set I/O handlers easily.
---@param self VM The VM instance
---@param input function Input handler function (optional)
---@param output function Output handler function (optional)
---@param err function Error handler function (optional)
function VM.setIOHandlers(self, input, output, err)
	if input then self.ioHandlers.input = input end
	if output then self.ioHandlers.output = output end
	if err then self.ioHandlers.error = err end
end

--- Enable debug mode.
---@param self VM The VM instance
function VM.enableDebug(self)
	self.debugMode = true
end

--- Disable debug mode.
---@param self VM The VM instance
function VM.disableDebug(self)
	self.debugMode = false
end

--- Dump registers to a formatted string.
---@param self VM The VM instance
---@return string dump Formatted register dump
function VM.dumpRegisters(self)
	return Registers.toString(self.registers)
end

--- Dump a memory region to a formatted hex string.
---@param self VM The VM instance
---@param start number Starting address (default: 0)
---@param length number Number of bytes to dump (default: 64)
---@return string dump Formatted hex dump
function VM.dumpMemory(self, start, length)
	return Memory.dump(self.memory, start, length)
end

--- Get memory statistics.
---@param self VM The VM instance
---@return table stats Statistics with bytesUsed, heapUsed, allocationCount, totalSize
function VM.getMemoryStats(self)
	return Memory.getStats(self.memory)
end

--- Clear all memory.
---@param self VM The VM instance
function VM.clearMemory(self)
	Memory.clear(self.memory)
end

--- Allocate memory on the heap.
---@param self VM The VM instance
---@param size number Size in bytes to allocate
---@return number address Address of allocated block, or 0 if failed
function VM.allocateMemory(self, size)
	return Memory.allocate(self.memory, size)
end

--- Free previously allocated memory.
---@param self VM The VM instance
---@param address number Address of block to free
---@return boolean success True if successfully freed
function VM.freeMemory(self, address)
	return Memory.free(self.memory, address)
end

--- Check if VM is currently running.
---@param self VM The VM instance
---@return boolean running True if running
function VM.isRunning(self)
	return self.running and not self.halted
end

--- Halt the VM.
---@param self VM The VM instance
function VM.halt(self)
	self.running = false
	self.halted = true
end

--- Resume execution after halt.
---@param self VM The VM instance
function VM.resume(self)
	if self.halted then
		self.halted = false
		self.running = true
	end
end

--- Set a breakpoint at an address.
---@param self VM The VM instance
---@param address number Memory address for breakpoint
function VM.setBreakpoint(self, address)
	if address == nil then return end
	self.breakpoints[math_floor(address)] = true
end

--- Clear a breakpoint.
---@param self VM The VM instance
---@param address number Memory address of breakpoint
function VM.clearBreakpoint(self, address)
	if address == nil then return end
	self.breakpoints[math_floor(address)] = nil
end

--- Clear all breakpoints.
---@param self VM The VM instance
function VM.clearAllBreakpoints(self)
	self.breakpoints = {}
end

--- Check if there's a breakpoint at an address.
---@param self VM The VM instance
---@param address number Memory address to check
---@return boolean exists True if breakpoint exists
function VM.hasBreakpoint(self, address)
	if address == nil then return false end
	return self.breakpoints[math_floor(address)] ~= nil
end

--- Run until breakpoint or halt.
---@param self VM The VM instance
---@param maxCycles number Maximum cycles to run (optional)
---@return number reason Reason for stopping: 0=halt, 1=breakpoint, 2=max cycles, 3=error
function VM.runUntilBreakpoint(self, maxCycles)
	maxCycles = maxCycles or self.maxCycles
	local startCycles = self.cycles
	self.running = true

	while self.running and (self.cycles - startCycles) < maxCycles do
		if VM.hasBreakpoint(self, self.registers.pc) then
			return 1 -- Breakpoint hit
		end
		if not VM.step(self) then
			return 3 -- Error
		end
	end

	if not self.running then
		return 0 -- Halted
	end
	return 2 -- Max cycles reached
end

--- Load and run assembly source code directly.
---@param self VM The VM instance
---@param source string Assembly source code
---@param maxCycles? number Maximum cycles to run (optional)
---@return table result Result with success, error, and returnValue fields
function VM.loadAndRun(self, source, maxCycles)
	maxCycles = maxCycles or self.maxCycles

	local assembler = Assembler.new()
	local success, result = pcall(function()
		return Assembler.assemble(assembler, source)
	end)

	if not success then
		return { success = false, error = result, returnValue = nil, vm = self }
	end

	if result == nil or #result == 0 then
		return { success = false, error = "Assembly produced no bytecode", returnValue = nil, vm = self }
	end

	VM.loadProgram(self, result)
	VM.run(self, maxCycles)

	return {
		success = true,
		error = nil,
		returnValue = Registers.get(self.registers, 0),
		cycles = self.cycles,
		vm = self
	}
end

--- Execute a single instruction and return debug info.
---@param self VM The VM instance
---@return table info Debug info with opcode, operands, pc, registers snapshot
function VM.stepDebug(self)
	local pc = self.registers.pc
	local opcodeByte = Memory.readByte(self.memory, pc)
	local opcode = OPCODES[opcodeByte]

	local info = {
		pc = pc,
		opcodeByte = opcodeByte,
		opcodeName = opcode and opcode.name or "UNKNOWN",
		operandCount = opcode and opcode.operandCount or 0,
		operands = {},
		registersBefore = VM.getState(self)
	}

	-- Read operands
	if opcode then
		for i = 1, opcode.operandCount do
			info.operands[i] = Memory.readDWord(self.memory, pc + 1 + (i - 1) * 4)
		end
	end

	-- Execute
	VM.step(self)

	info.registersAfter = VM.getState(self)
	info.success = self.running or self.halted

	return info
end

----------------------------------------------------------------------
-- MODULE: ASSEMBLER
----------------------------------------------------------------------

--- Assembler class for assembling assembly source code to bytecode.<br>
--- Supports labels, constants, and various data directives.
---@class Assembler
---@field labels table Map of label names to addresses.
---@field constants table Map of constant names to values.
---@field errors table Array of error messages.
Assembler = {}
Assembler.__index = Assembler

--- Parse a numeric value from a string.
---@param str string The string to parse
---@param labels table Optional labels table for lookup
---@param constants table Optional constants table for lookup
---@return number? parsed Parsed value, or nil if invalid
local function parseNum(str, labels, constants)
	str = Utils.trim(str)
	if #str == 0 then return nil end

	-- Register
	local reg = string_match(string_upper(str), "^R(%d+)$")
	if reg then return tonumber(reg) end

	-- Hex (0x...)
	local hex = string_match(str, "^0[xX]([%x]+)$")
	if hex then return tonumber(hex, 16) end
	hex = string_match(str, "^%$([%x]+)$")
	if hex then return tonumber(hex, 16) end

	-- Binary (0b...)
	local bin = string_match(str, "^0[bB]([01]+)$")
	if bin then return tonumber(bin, 2) end

	-- Character ('x')
	local ch = string_match(str, "^'(.)'$")
	if ch then return string_byte(ch) end

	-- Decimal
	local num = tonumber(str)
	if num then return num end

	-- Label/Constant
	if labels and labels[string_upper(str)] then return labels[string_upper(str)] end
	if constants and constants[string_upper(str)] then return constants[string_upper(str)] end
end

--- Resolve opcode name from mnemonic and operands.
---@param mnemonic string The instruction mnemonic
---@param operands table Array of operand strings
---@return string? opcode Resolved opcode name
local function getOpcode(mnemonic, operands)
	mnemonic = string_upper(mnemonic)

	-- Direct lookup
	if OPCODES[mnemonic] then return mnemonic end

	-- Smart resolution
	local r1 = operands[1] and Utils.isRegister(operands[1])
	local r2 = operands[2] and Utils.isRegister(operands[2])
	local r3 = operands[3] and Utils.isRegister(operands[3])

	local map = {
		MOV = function() return r1 and (r2 and "MOV_RR" or "MOV_RI") end,
		ADD = function()
			if #operands == 3 then
				if r2 and r3 then
					return "ADD_RR"
				end
			elseif #operands == 2 then
				return "ADD_RI"
			end
		end,
		SUB = function()
			if #operands == 3 then
				if r2 and r3 then
					return "SUB_RR"
				end
			elseif #operands == 2 then
				return "SUB_RI"
			end
		end,
		MUL = function()
			if #operands == 3 then
				if r2 and r3 then
					return "MUL_RR"
				end
			elseif #operands == 2 then
				return "MUL_RI"
			end
		end,
		DIV = function()
			if #operands == 3 then
				if r2 and r3 then
					return "DIV_RR"
				end
			elseif #operands == 2 then
				return "DIV_RI"
			end
		end,
		MOD = function()
			if #operands == 3 then
				if r2 and r3 then
					return "MOD_RR"
				end
			elseif #operands == 2 then
				return "MOD_RI"
			end
		end,
		AND = function()
			if #operands == 3 then
				if r2 and r3 then
					return "AND_RR"
				end
			elseif #operands == 2 then
				return "AND_RI"
			end
		end,
		OR = function()
			if #operands == 3 then
				if r2 and r3 then
					return "OR_RR"
				end
			elseif #operands == 2 then
				return "OR_RI"
			end
		end,
		XOR = function()
			if #operands == 3 then
				if r2 and r3 then
					return "XOR_RR"
				end
			elseif #operands == 2 then
				return "XOR_RI"
			end
		end,
		NOT = function() return "NOT_R" end,
		SHL = function()
			if #operands == 3 then
				-- Check if second operand is a register
				if Utils.isRegister(operands[2]) then
					return "SHL_RR" -- dest, src, shift (all registers)
				end
				-- Second operand is immediate, we need MOV first then SHL_RI
				-- But we can't return multiple instructions, so use SHL_RI and let assembler handle it
				return "SHL_RI" -- This will need special handling
			end
			return "SHL_RI"
		end,
		SHR = function()
			if #operands == 3 then
				if Utils.isRegister(operands[2]) then
					return "SHR_RR"
				end
				return "SHR_RI"
			end
			return "SHR_RI"
		end,
		SAR = function() return "SAR_RR" end,
		ROL = function() return "ROL_RI" end,
		ROR = function() return "ROR_RI" end,
		CMP = function() return r2 and "CMP_RR" or "CMP_RI" end,
		TEST = function() return r2 and "TEST_RR" or "TEST_RI" end,
		JMP = function() return r1 and "JMP_R" or "JMP_I" end,
		JZ = function() return "JZ_I" end,
		JE = function() return "JZ_I" end,
		JNZ = function() return "JNZ_I" end,
		JNE = function() return "JNZ_I" end,
		JC = function() return "JC_I" end,
		JNC = function() return "JNC_I" end,
		JN = function() return "JN_I" end,
		JNN = function() return "JNN_I" end,
		JO = function() return "JO_I" end,
		JNO = function() return "JNO_I" end,
		JGT = function() return "JGT_I" end,
		JA = function() return "JGT_I" end,
		JLT = function() return "JLT_I" end,
		JB = function() return "JLT_I" end,
		JGE = function() return "JGE_I" end,
		JAE = function() return "JGE_I" end,
		JLE = function() return "JLE_I" end,
		JBE = function() return "JLE_I" end,
		PUSH = function() return r1 and "PUSH_R" or "PUSH_I" end,
		POP = function() return "POP_R" end,
		PEEK = function() return "PEEK_R" end,
		LOAD = function() return r2 and "LOAD_R" or "LOAD_I" end,
		LD = function() return r2 and "LOAD_R" or "LOAD_I" end,
		STORE = function() return r2 and "STORE_R" or "STORE_I" end,
		ST = function() return r2 and "STORE_R" or "STORE_I" end,
		LOADB = function() return "LOADB_R" end,
		LDB = function() return "LOADB_R" end,
		STOREB = function() return "STOREB_R" end,
		STB = function() return "STOREB_R" end,
		LOADW = function() return "LOADW_R" end,
		LDW = function() return "LOADW_R" end,
		STOREW = function() return "STOREW_R" end,
		STW = function() return "STOREW_R" end,
		INC = function() return "INC_R" end,
		DEC = function() return "DEC_R" end,
		NEG = function() return "NEG_R" end,
		ABS = function() return "ABS_R" end,
		CALL = function() return r1 and "CALL_R" or "CALL_I" end,
		RET = function() return #operands > 0 and "RET_I" or "RET" end,
		ENTER = function() return "ENTER" end,
		LEAVE = function() return "LEAVE" end,
		SYSCALL = function() return "SYSCALL" end,
		SYS = function() return "SYSCALL" end,
		INT = function() return "INT" end,
		IRET = function() return "IRET" end,
		CLI = function() return "CLI" end,
		STI = function() return "STI" end,
		MALLOC = function() return "MALLOC" end,
		FREE = function() return "FREE" end,
		MEMCPY = function() return "MEMCPY" end,
		MEMSET = function() return "MEMSET" end,
		MEMCMP = function() return "MEMCMP" end,
		LEA = function() return "LEA" end,
		STRLEN = function() return "STRLEN" end,
		STRCPY = function() return "STRCPY" end,
		STRCAT = function() return "STRCAT" end,
		STRCMP = function() return "STRCMP" end,
		FADD = function() return "FADD_RR" end,
		FSUB = function() return "FSUB_RR" end,
		FMUL = function() return "FMUL_RR" end,
		FDIV = function() return "FDIV_RR" end,
		FSQRT = function() return "FSQRT_R" end,
		FSIN = function() return "FSIN_R" end,
		FCOS = function() return "FCOS_R" end,
		FTAN = function() return "FTAN_R" end,
		FLOOR = function() return "FLOOR_R" end,
		CEIL = function() return "CEIL_R" end,
		ROUND = function() return "ROUND_R" end,
		ITOF = function() return "ITOF_R" end,
		VADD = function() return "VADD_4" end,
		VSUB = function() return "VSUB_4" end,
		VMUL = function() return "VMUL_4" end,
		VDP = function() return "VDP_4" end,
		LOOP = function() return "LOOP" end,
		LOOPZ = function() return "LOOPZ" end,
		LOOPNZ = function() return "LOOPNZ" end,
		DEBUG = function() return "DEBUG_REG" end,
		DUMP = function() return "DEBUG_MEM" end,
		NOP = function() return "NOP" end,
		HALT = function() return "HALT" end,
		BREAK = function() return "BREAK" end,
		WAIT = function() return "WAIT" end,
		RESET = function() return "RESET" end,
		CPUID = function() return "CPUID" end,
		IDLE = function() return "IDLE" end,
	}

	local resolver = map[mnemonic]
	if resolver then
		return resolver()
	end
end

--- Parse operands from a line.
---@param line string The line after mnemonic
---@return table operands Array of operand strings
local function parseOperands(line)
	local operands = {}
	for op in string_gmatch(line, "[^,%s]+") do
		table_insert(operands, Utils.trim(op))
	end
	return operands
end

--- Create a new Assembler instance.
---@return Assembler instance New assembler instance
function Assembler.new()
	return setmetatable({
		labels = {},
		constants = {},
		errors = {},
	}, Assembler)
end

--- Assemble source code to bytecode.
---@param self Assembler The assembler instance
---@param source string Assembly source code
---@return table? bytecode Bytecode array or nil on error
function Assembler.assemble(self, source)
	self.labels = {}
	self.constants = {}
	self.errors = {}

	local lines = Utils.split((string_gsub(source, "\r", "")), "\n")
	local address = 0

	-- First pass: collect labels and calculate sizes
	for lineNum = 1, #lines do
		local line = lines[lineNum]
		line = string_gsub(line, ";.*$", "")
		line = Utils.trim(line)

		if line ~= "" then
			-- Label (allow underscores)
			local label = string_match(line, "^([%w_]+):")
			if label then
				self.labels[string_upper(label)] = address
				line = Utils.trim(string_sub(line, #label + 2))
			end

			-- Constant (allow underscores in name)
			local constName, constVal = string_match(line, "^([%w_]+)%s*=%s*(.+)$")
			if constName then
				self.constants[string_upper(constName)] = parseNum(constVal, self.labels, self.constants) or constVal
				line = ""
			end

			-- Directive
			if string_match(line, "^%.%w+") then
				local directive, args = string_match(line, "^%.(%w+)%s*(.*)$")
				directive = directive and string_upper(directive)

				if directive == "ORG" then
					address = parseNum(args, self.labels, self.constants) or address
				elseif directive == "DB" then
					for val in string_gmatch(args, "[^,]+") do
						local val = Utils.trim(val) -- shadow
						if string_match(val, '^".*"$') or string_match(val, "^'.*'$") then
							address = address + #val - 2 + 1
						else
							address = address + 1
						end
					end
				elseif directive == "DW" then
					local c = 0
					for _ in string_gmatch(args, "[^,]+") do c = c + 1 end
					address = address + c * 2
				elseif directive == "DD" then
					local c = 0
					for _ in string_gmatch(args, "[^,]+") do c = c + 1 end
					address = address + c * 4
				elseif directive == "RESB" then
					address = address + (parseNum(args, self.labels, self.constants) or 0)
				end
			elseif line ~= "" then
				-- Instruction
				local mnemonic = string_match(line, "^(%w+)")
				if mnemonic then
					local rest = Utils.trim(string_sub(line, #mnemonic + 1))
					local operands = parseOperands(rest)
					local opcodeName = getOpcode(mnemonic, operands)
					local opdef = opcodeName and OPCODES[opcodeName]

					if opdef then
						address = address + 1 + opdef.operandCount * 4
					else
						address = address + 5
					end
				end
			end
		end
	end

	-- Second pass: generate code
	local bytecode = {}
	address = 0

	local function emitByte(b)
		table_insert(bytecode, { addr = address, byte = b })
		address = address + 1
	end

	local function emitDWord(v)
		local b0, b1, b2, b3 = Utils.toDWords(v)
		emitByte(b0)
		emitByte(b1)
		emitByte(b2)
		emitByte(b3)
	end

	for lineNum = 1, #lines do
		local line = lines[lineNum]
		line = string_gsub(line, ";.*$", "")
		line = Utils.trim(line)

		if line ~= "" then
			-- Skip label
			local label = string_match(line, "^([%w_]+):")
			if label then line = Utils.trim(string_sub(line, #label + 2)) end

			-- Skip constant
			if string_match(line, "^[%w_]+%s*=%s*") then line = "" end

			-- Directive
			if string_match(line, "^%.%w+") then
				local directive, args = string_match(line, "^%.(%w+)%s*(.*)$")
				directive = directive and string_upper(directive)

				if directive == "ORG" then
					address = parseNum(args, self.labels, self.constants) or address
				elseif directive == "DB" then
					for val in string_gmatch(args, "[^,]+") do
						local val = Utils.trim(val) -- shadow
						if string_match(val, '^".*"$') or string_match(val, "^'.*'$") then
							local str = string_sub(val, 2, #val - 1)
							for i = 1, #str do emitByte(string_byte(str, i)) end
							emitByte(0)
						else
							emitByte((parseNum(val, self.labels, self.constants) or 0) % 256)
						end
					end
				elseif directive == "DW" then
					for val in string_gmatch(args, "[^,]+") do
						local val = parseNum(Utils.trim(val), self.labels, self.constants) or 0 -- shadow
						emitByte(val % 256)
						emitByte(math_floor(val / 256) % 256)
					end
				elseif directive == "DD" then
					for val in string_gmatch(args, "[^,]+") do
						local val = parseNum(Utils.trim(val), self.labels, self.constants) or 0 -- shadow
						emitDWord(val)
					end
				elseif directive == "RESB" then
					address = address + (parseNum(args, self.labels, self.constants) or 0)
				end
			elseif line ~= "" then
				-- Instruction
				local mnemonic = string_match(line, "^(%w+)")
				if mnemonic then
					local rest = Utils.trim(string_sub(line, #mnemonic + 1))
					local operands = parseOperands(rest)
					local opcodeName = getOpcode(mnemonic, operands)
					local opdef = opcodeName and OPCODES[opcodeName]

					-- Special handling for SHL/SHR with 3 operands where 2nd is immediate
					if opdef and (mnemonic == "SHL" or mnemonic == "SHR") and #operands == 3 and not Utils.isRegister(operands[2]) then
						-- Convert to MOV + SHL_RI/SHR_RI
						local dest = parseNum(operands[1], self.labels, self.constants) or 0
						local value = parseNum(operands[2], self.labels, self.constants) or 0
						local shift = parseNum(operands[3], self.labels, self.constants) or 0

						-- Emit MOV to load the value
						local movDef = OPCODES["MOV_RI"]
						if movDef then
							emitByte(movDef.code)
							emitDWord(dest)
							emitDWord(value)
						end

						-- Emit SHL_RI/SHR_RI to shift
						emitByte(opdef.code)
						emitDWord(dest)
						emitDWord(shift)
					else
						-- Normal instruction handling
						if opdef then
							emitByte(opdef.code)
							for i = 1, opdef.operandCount do
								local val = parseNum(operands[i], self.labels, self.constants)
								if val == nil then
									table_insert(self.errors,
										string_format("Line %d: Invalid operand '%s'", lineNum, operands[i] or "missing"))
									val = 0
								end
								emitDWord(val)
							end
						else
							table_insert(self.errors,
								string_format("Line %d: Unknown instruction '%s'", lineNum, mnemonic))
						end
					end
				end
			end
		end
	end

	if #self.errors > 0 then
		for _, err in next, self.errors do print("ERROR: " .. err) end
		return
	end

	-- Convert to array
	local result = {}
	local maxAddr = 0
	for _, entry in next, bytecode do
		result[entry.addr + 1] = entry.byte
		if entry.addr + 1 > maxAddr then maxAddr = entry.addr + 1 end
	end
	for i = 1, maxAddr do result[i] = result[i] or 0 end

	return result
end

--- Assemble and run in one step.
---@param self Assembler The assembler instance
---@param source string Assembly source code
---@param maxCycles number Optional max cycles
---@return table? bytecode Bytecode or nil on error
function Assembler.assembleAndRun(self, source, maxCycles)
	local bytecode = Assembler.assemble(self, source)
	if not bytecode then return end

	local vm = VM.new()
	VM.loadProgram(vm, bytecode)
	VM.run(vm, maxCycles)

	return vm
end

----------------------------------------------------------------------
-- MODULE: DISASSEMBLER
----------------------------------------------------------------------

--- Disassembler class for converting bytecode to assembly source code.<br>
--- Provides readable assembly output with optional hex dumps.
---@class Disassembler
Disassembler = {}
Disassembler.__index = Disassembler

--- Create a new Disassembler instance.
---@return Disassembler instance New disassembler instance
function Disassembler.new()
	return setmetatable({}, Disassembler)
end

-- Opcode name mapping for cleaner disassembly
local OPCODE_MAP = {
	["MOV_RR"] = "MOV",
	["MOV_RI"] = "MOVI",
	["ADD_RR"] = "ADD",
	["ADD_RI"] = "ADDI",
	["SUB_RR"] = "SUB",
	["SUB_RI"] = "SUBI",
	["MUL_RR"] = "MUL",
	["MUL_RI"] = "MULI",
	["DIV_RR"] = "DIV",
	["DIV_RI"] = "DIVI",
	["MOD_RR"] = "MOD",
	["MOD_RI"] = "MODI",
	["AND_RR"] = "AND",
	["AND_RI"] = "ANDI",
	["OR_RR"] = "OR",
	["OR_RI"] = "ORI",
	["XOR_RR"] = "XOR",
	["XOR_RI"] = "XORI",
	["NOT_R"] = "NOT",
	["SHL_RR"] = "SHL",
	["SHL_RI"] = "SHLI",
	["SHR_RR"] = "SHR",
	["SHR_RI"] = "SHRI",
	["SAR_RR"] = "SAR",
	["SAR_RI"] = "SARI",
	["ROL_RI"] = "ROL",
	["ROR_RI"] = "ROR",
	["CMP_RR"] = "CMP",
	["CMP_RI"] = "CMPI",
	["TEST_RR"] = "TEST",
	["TEST_RI"] = "TESTI",
	["JMP_I"] = "JMP",
	["JMP_R"] = "JMP",
	["JZ_I"] = "JZ",
	["JNZ_I"] = "JNZ",
	["JC_I"] = "JC",
	["JNC_I"] = "JNC",
	["JN_I"] = "JN",
	["JNN_I"] = "JNN",
	["JO_I"] = "JO",
	["JNO_I"] = "JNO",
	["JGT_I"] = "JGT",
	["JLT_I"] = "JLT",
	["JGE_I"] = "JGE",
	["JLE_I"] = "JLE",
	["CALL_I"] = "CALL",
	["CALL_R"] = "CALL",
	["RET_I"] = "RET",
	["LOAD_R"] = "LDR",
	["LOAD_I"] = "LDA",
	["STORE_R"] = "STR",
	["STORE_I"] = "STA",
	["LOADB_R"] = "LDB",
	["STOREB_R"] = "STB",
	["LOADW_R"] = "LDW",
	["STOREW_R"] = "STW",
	["PUSH_R"] = "PUSH",
	["PUSH_I"] = "PUSH",
	["POP_R"] = "POP",
	["PEEK_R"] = "PEEK",
	["INC_R"] = "INC",
	["DEC_R"] = "DEC",
	["NEG_R"] = "NEG",
	["ABS_R"] = "ABS",
	["FADD_RR"] = "FADD",
	["FSUB_RR"] = "FSUB",
	["FMUL_RR"] = "FMUL",
	["FDIV_RR"] = "FDIV",
	["FSQRT_R"] = "FSQRT",
	["FLOOR_R"] = "FLOOR",
	["CEIL_R"] = "CEIL",
	["ROUND_R"] = "ROUND",
	["ITOF_R"] = "ITOF",
	["STRLEN"] = "SLEN",
	["STRCPY"] = "SCOPY",
	["STRCAT"] = "SCAT",
	["STRCMP"] = "SCMP",
	["VADD_4"] = "VADD",
	["VSUB_4"] = "VSUB",
	["VMUL_4"] = "VMUL",
	["VDP_4"] = "VDOT",
}

--- Disassemble bytecode to assembly.
---@param self Disassembler The disassembler instance
---@param bytecode table Array of bytes
---@param startAddress number Optional start address (default: 0)
---@return string code Disassembled code
function Disassembler.disassemble(self, bytecode, startAddress)
	startAddress = startAddress or 0
	local lines = {}
	local pc = 0

	while pc < #bytecode do
		local opcode = bytecode[pc + 1] or 0
		local opdef = OPCODES[opcode]

		if opdef then
			local operands = {}
			local operandTypes = {}

			-- Determine operand types based on opcode name
			for i = 1, opdef.operandCount do
				local b0 = bytecode[pc + 2 + (i - 1) * 4] or 0
				local b1 = bytecode[pc + 3 + (i - 1) * 4] or 0
				local b2 = bytecode[pc + 4 + (i - 1) * 4] or 0
				local b3 = bytecode[pc + 5 + (i - 1) * 4] or 0
				local value = Utils.fromDWords(b0, b1, b2, b3)

				-- Determine if this operand should be a register based on opcode pattern
				local isRegister = false
				if string_find(opdef.name, "_RR") then
					-- Register-Register instructions: all operands are registers
					isRegister = true
				elseif string_find(opdef.name, "_RI") and i == 2 then
					-- Register-Immediate instructions: first is register, second is immediate
					isRegister = false
				elseif string_find(opdef.name, "_R") and not string_find(opdef.name, "_RR") then
					-- Single register operand
					isRegister = true
				elseif string_find(opdef.name, "_I") then
					-- Immediate operand
					isRegister = false
				end

				-- Format as register or hex
				if isRegister and value >= 0 and value <= 15 then
					table_insert(operands, string_format("R%d", value))
					table_insert(operandTypes, "register")
				elseif value >= 0 and value <= 15 and
					(string_find(opdef.name, "PUSH_R")
						or string_find(opdef.name, "POP_R")
						or string_find(opdef.name, "PEEK_R")) then
					table_insert(operands, string_format("R%d", value))
					table_insert(operandTypes, "register")
				elseif value >= 0 and value <= 255 and not isRegister then
					-- Small immediates as decimal
					table_insert(operands, string_format("%d", value))
					table_insert(operandTypes, "immediate")
				else
					-- Large values as hex
					table_insert(operands, "0x" .. Utils.toHex(value, 8))
					table_insert(operandTypes, "address")
				end
			end

			-- Map opcode name to simpler form
			local mnemonic = OPCODE_MAP[opdef.name] or opdef.name

			local line = string_format("%06X: [%s] %s", startAddress + pc, Utils.toHex(opcode, 2), mnemonic)
			if #operands > 0 then line = line .. " " .. table_concat(operands, ", ") end
			table_insert(lines, line)
			pc = pc + 1 + opdef.operandCount * 4
		else
			table_insert(lines, string_format("%06X: [%s] DB 0x%02X", startAddress + pc, Utils.toHex(opcode, 2), opcode))
			pc = pc + 1
		end
	end

	return table_concat(lines, "\n")
end

--- Disassemble bytecode with detailed hex dump.
---@param self Disassembler The disassembler instance
---@param bytecode table Array of bytes
---@param startAddress number Optional start address (default: 0)
---@return string code Disassembled code with hex bytes
function Disassembler.disassembleDetailed(self, bytecode, startAddress)
	startAddress = startAddress or 0
	local lines = {}
	local pc = 0

	while pc < #bytecode do
		local opcode = bytecode[pc + 1] or 0
		local opdef = OPCODES[opcode]

		-- Build hex dump line
		local hexBytes = { string_format("%02X", opcode) }
		local bytesToRead = 1 + ((opdef and opdef.operandCount) or 0) * 4

		for i = 1, bytesToRead - 1 do
			table_insert(hexBytes, string_format("%02X", bytecode[pc + 1 + i] or 0))
		end

		-- Pad hex bytes to 13 characters (max instruction size)
		local hexStr = table_concat(hexBytes, " ")
		while #hexStr < 23 do
			hexStr = hexStr .. " "
		end

		if opdef then
			local operands = {}
			for i = 1, opdef.operandCount do
				local b0 = bytecode[pc + 2 + (i - 1) * 4] or 0
				local b1 = bytecode[pc + 3 + (i - 1) * 4] or 0
				local b2 = bytecode[pc + 4 + (i - 1) * 4] or 0
				local b3 = bytecode[pc + 5 + (i - 1) * 4] or 0
				local value = Utils.fromDWords(b0, b1, b2, b3)

				-- Format as register or hex
				if value >= 0 and value <= 15 and (string_find(opdef.name, "RR") or string_find(opdef.name, "_R")) then
					table_insert(operands, "R" .. value)
				else
					table_insert(operands, "0x" .. Utils.toHex(value, 8))
				end
			end
			local line = string_format("%06X: %-23s %s", startAddress + pc, hexStr, opdef.name)
			if #operands > 0 then line = line .. " " .. table_concat(operands, ", ") end
			table_insert(lines, line)
			pc = pc + 1 + opdef.operandCount * 4
		else
			local line = string_format("%06X: %-23s DB 0x%02X", startAddress + pc, hexStr, opcode)
			table_insert(lines, line)
			pc = pc + 1
		end
	end

	return table_concat(lines, "\n")
end

----------------------------------------------------------------------
-- MODULE: BUILDER (CONVENIENCE API)
----------------------------------------------------------------------

--- Builder class for programmatically constructing bytecode.<br>
--- Provides a fluent API for adding instructions and labels.
---@class Builder
---@field bytecode table Array of bytecode bytes.
---@field labels table Map of label names to addresses.
---@field currentAddress number Current address in bytecode.
Builder = {}
Builder.__index = Builder

--- Create a new program builder.
---@return Builder instance New builder instance
function Builder.new()
	return setmetatable({
		bytecode = {},
		labels = {},
		currentAddress = 0,
	}, Builder)
end

--- Add an instruction.
---@param self Builder The builder instance
---@param opcodeName string The opcode name
---@param ... number Operands
---@return Builder self for chaining
function Builder.emit(self, opcodeName, ...)
	local opdef = OPCODES[opcodeName]
	if not opdef then
		return error("Unknown opcode: " .. opcodeName, 2)
	end

	table_insert(self.bytecode, opdef.code)
	self.currentAddress = self.currentAddress + 1

	local args = { ... }
	for i = 1, opdef.operandCount do
		local val = args[i] or 0
		local b0, b1, b2, b3 = Utils.toDWords(val)
		table_insert(self.bytecode, b0)
		table_insert(self.bytecode, b1)
		table_insert(self.bytecode, b2)
		table_insert(self.bytecode, b3)
		self.currentAddress = self.currentAddress + 4
	end

	return self
end

--- Define a label at current position.
---@param self Builder The builder instance
---@param name string Label name
---@return Builder self for chaining
function Builder.label(self, name)
	self.labels[string_upper(name)] = self.currentAddress
	return self
end

--- Get current address.
---@param self Builder The builder instance
---@return number address Current address
function Builder.address(self)
	return self.currentAddress
end

--- Build and return the bytecode.
---@param self Builder The builder instance
---@return table bytecode Bytecode array
function Builder.build(self)
	return self.bytecode
end

--- Build, create VM, and run.
---@param self Builder The builder instance
---@param maxCycles number Optional max cycles
---@return VM vm The VM instance after execution
function Builder.run(self, maxCycles)
	local vm = VM.new()
	VM.loadProgram(vm, self.bytecode)
	VM.run(vm, maxCycles)
	return vm
end

-- Convenience methods for common opcodes
function Builder.nop(self) return Builder.emit(self, "NOP") end

function Builder.halt(self) return Builder.emit(self, "HALT") end

function Builder.mov(self, d, v) return Builder.emit(self, "MOV_RI", d, v) end

function Builder.movrr(self, d, s) return Builder.emit(self, "MOV_RR", d, s) end

function Builder.add(self, d, a, b) return Builder.emit(self, "ADD_RR", d, a, b) end

function Builder.sub(self, d, a, b) return Builder.emit(self, "SUB_RR", d, a, b) end

function Builder.mul(self, d, a, b) return Builder.emit(self, "MUL_RR", d, a, b) end

function Builder.div(self, d, a, b) return Builder.emit(self, "DIV_RR", d, a, b) end

function Builder.inc(self, r) return Builder.emit(self, "INC_R", r) end

function Builder.dec(self, r) return Builder.emit(self, "DEC_R", r) end

function Builder.neg(self, r) return Builder.emit(self, "NEG_R", r) end

function Builder.abs(self, r) return Builder.emit(self, "ABS_R", r) end

function Builder.bnot(self, r) return Builder.emit(self, "NOT_R", r) end

function Builder.push(self, r) return Builder.emit(self, "PUSH_R", r) end

function Builder.pop(self, r) return Builder.emit(self, "POP_R", r) end

function Builder.jmp(self, a) return Builder.emit(self, "JMP_I", a) end

function Builder.jz(self, a) return Builder.emit(self, "JZ_I", a) end

function Builder.jnz(self, a) return Builder.emit(self, "JNZ_I", a) end

function Builder.jc(self, a) return Builder.emit(self, "JC_I", a) end

function Builder.jnc(self, a) return Builder.emit(self, "JNC_I", a) end

function Builder.jn(self, a) return Builder.emit(self, "JN_I", a) end

function Builder.jnn(self, a) return Builder.emit(self, "JNN_I", a) end

function Builder.jo(self, a) return Builder.emit(self, "JO_I", a) end

function Builder.jno(self, a) return Builder.emit(self, "JNO_I", a) end

function Builder.call(self, a) return Builder.emit(self, "CALL_I", a) end

function Builder.ret(self) return Builder.emit(self, "RET") end

function Builder.cmp(self, a, b) return Builder.emit(self, "CMP_RR", a, b) end

function Builder.load(self, d, a) return Builder.emit(self, "LOAD_R", d, a) end

function Builder.store(self, a, s) return Builder.emit(self, "STORE_R", a, s) end

function Builder.syscall(self, n) return Builder.emit(self, "SYSCALL", n) end

function Builder.int(self, n) return Builder.emit(self, "INT", n) end

function Builder.cli(self) return Builder.emit(self, "CLI") end

function Builder.sti(self) return Builder.emit(self, "STI") end

-- Additional convenience methods for test coverage
function Builder.movi(self, d, v) return Builder.emit(self, "MOV_RI", d, v) end

function Builder.addi(self, d, v) return Builder.emit(self, "ADD_RI", d, v) end

function Builder.subi(self, d, v) return Builder.emit(self, "SUB_RI", d, v) end

function Builder.muli(self, d, v) return Builder.emit(self, "MUL_RI", d, v) end

function Builder.divi(self, d, v) return Builder.emit(self, "DIV_RI", d, v) end

function Builder.cmpi(self, r, v) return Builder.emit(self, "CMP_RI", r, v) end

function Builder.andi(self, d, v) return Builder.emit(self, "AND_RI", d, v) end

function Builder.ori(self, d, v) return Builder.emit(self, "OR_RI", d, v) end

function Builder.xori(self, d, v) return Builder.emit(self, "XOR_RI", d, v) end

function Builder.shl(self, d, s) return Builder.emit(self, "SHL_RR", 0, d, s) end

function Builder.shr(self, d, s) return Builder.emit(self, "SHR_RR", 0, d, s) end

function Builder.sar(self, d, s) return Builder.emit(self, "SAR_RR", 0, d, s) end

function Builder.rol(self, d, v) return Builder.emit(self, "ROL_RI", d, v) end

function Builder.ror(self, d, v) return Builder.emit(self, "ROR_RI", d, v) end

function Builder.shli(self, d, v) return Builder.emit(self, "SHL_RI", d, v) end

function Builder.shri(self, d, v) return Builder.emit(self, "SHR_RI", d, v) end

function Builder.sari(self, d, v) return Builder.emit(self, "SAR_RI", d, v) end

function Builder.roli(self, d, v) return Builder.emit(self, "ROL_RI", d, v) end

function Builder.rori(self, d, v) return Builder.emit(self, "ROR_RI", d, v) end

function Builder.deci(self, r) return Builder.emit(self, "SUB_RI", r, 1) end

function Builder.and_op(self, d, s) return Builder.emit(self, "AND_RR", 0, d, s) end

function Builder.or_op(self, d, s) return Builder.emit(self, "OR_RR", 0, d, s) end

function Builder.xor(self, d, s) return Builder.emit(self, "XOR_RR", 0, d, s) end

function Builder.nand(self, d, s) return Builder.emit(self, "NAND_RR", 0, d, s) end

function Builder.nor(self, d, s) return Builder.emit(self, "NOR_RR", 0, d, s) end

function Builder.test(self, a, b) return Builder.emit(self, "TEST_RR", a, b) end

function Builder.testi(self, r, v) return Builder.emit(self, "TEST_RI", r, v) end

function Builder.ldr(self, d, a) return Builder.emit(self, "LOAD_R", d, a) end

function Builder.str(self, a, s) return Builder.emit(self, "STORE_R", a, s) end

function Builder.lea(self, d, a) return Builder.emit(self, "LEA", d, a) end

function Builder.lda(self, d, a) return Builder.emit(self, "LOAD_I", d, a) end

function Builder.sta(self, a, s) return Builder.emit(self, "STORE_I", a, s) end

function Builder.swap(self, a, b) return Builder.emit(self, "SWAP", a, b) end

function Builder.xchg(self, a, b) return Builder.emit(self, "SWAP", a, b) end

function Builder.memcpy(self, d, s, n) return Builder.emit(self, "MEMCPY", d, s, n) end

function Builder.memcmp(self, d, a1, a2, n) return Builder.emit(self, "MEMCMP", d, a1, a2, n) end

function Builder.alloc(self, size) return Builder.emit(self, "MALLOC", 0, size) end

function Builder.free(self, addr) return Builder.emit(self, "FREE", addr) end

function Builder.memset(self, a, v, n) return Builder.emit(self, "MEMSET", a, v, n) end

function Builder.fadd(self, d, s) return Builder.emit(self, "FADD_RR", 0, d, s) end

function Builder.fsub(self, d, s) return Builder.emit(self, "FSUB_RR", 0, d, s) end

function Builder.fmul(self, d, s) return Builder.emit(self, "FMUL_RR", 0, d, s) end

function Builder.fdiv(self, d, s) return Builder.emit(self, "FDIV_RR", 0, d, s) end

function Builder.fmod(self, d, s) return Builder.emit(self, "FMUL_RR", 0, d, s) end -- Placeholder; TODO/FIXME

function Builder.fneg(self, r) return Builder.emit(self, "NEG_R", r) end

function Builder.fabs(self, r) return Builder.emit(self, "ABS_R", r) end

function Builder.fsqrt(self, r) return Builder.emit(self, "FSQRT_R", 0, r) end

function Builder.fsin(self, r) return Builder.emit(self, "FSIN_R", 0, r) end

function Builder.fcos(self, r) return Builder.emit(self, "FCOS_R", 0, r) end

function Builder.ftan(self, r) return Builder.emit(self, "FTAN_R", 0, r) end

function Builder.ftoi(self, r) return Builder.emit(self, "ITOF_R", 0, r) end

function Builder.itof(self, r) return Builder.emit(self, "ITOF_R", 0, r) end

function Builder.floor(self, r) return Builder.emit(self, "FLOOR_R", 0, r) end

function Builder.ceil(self, r) return Builder.emit(self, "CEIL_R", 0, r) end

function Builder.round(self, r) return Builder.emit(self, "ROUND_R", 0, r) end

function Builder.fcmp(self, a, b) return Builder.emit(self, "CMP_RR", a, b) end

function Builder.vadd(self, d, s) return Builder.emit(self, "VADD_4", d, 0, s) end

function Builder.vsub(self, d, s) return Builder.emit(self, "VSUB_4", d, 0, s) end

function Builder.vmul(self, d, s) return Builder.emit(self, "VMUL_4", d, 0, s) end

function Builder.vdiv(self, d, s) return Builder.emit(self, "VDIV_R", 0, d, s) end

function Builder.vdot(self, d, s) return Builder.emit(self, "VDP_4", d, 0, s) end

function Builder.vcross(self, d, s) return Builder.emit(self, "VCROSS_R", 0, d, s) end

function Builder.vlen(self, r) return Builder.emit(self, "VLEN_R", 0, r) end

function Builder.vnorm(self, r) return Builder.emit(self, "VNORM_R", 0, r) end

function Builder.vload(self, r, a) return Builder.emit(self, "VLOAD_R", r, a) end

function Builder.vstore(self, a, s) return Builder.emit(self, "VSTORE_R", a, s) end

function Builder.vdup(self, d, s) return Builder.emit(self, "VDUP_R", 0, d, s) end

function Builder.slen(self, r) return Builder.emit(self, "STRLEN", 0, r) end

function Builder.scat(self, d, s) return Builder.emit(self, "STRCAT", d, s) end

function Builder.scmp(self, d, a1, a2) return Builder.emit(self, "STRCMP", d, a1, a2) end

function Builder.scopy(self, d, s) return Builder.emit(self, "STRCPY", d, s) end

function Builder.schr(self, d, s) return Builder.emit(self, "SCHR_R", 0, d, s) end

function Builder.sstr(self, d, s) return Builder.emit(self, "SSTR_R", 0, d, s) end

function Builder.s2n(self, r) return Builder.emit(self, "S2N_R", 0, r) end

function Builder.n2s(self, r) return Builder.emit(self, "N2S_R", 0, r) end

function Builder.slower(self, r) return Builder.emit(self, "SLOWER_R", 0, r) end

function Builder.supper(self, r) return Builder.emit(self, "SUPPER_R", 0, r) end

function Builder.idle(self) return Builder.emit(self, "WAIT", 0) end

function Builder.dbg(self) return Builder.emit(self, "DEBUG_REG", 0) end

function Builder.reset(self) return Builder.emit(self, "RESET") end

function Builder.iret(self) return Builder.emit(self, "IRET") end

function Builder.cpuid(self) return Builder.emit(self, "CPUID") end

----------------------------------------------------------------------
-- DOCUMENTATION
----------------------------------------------------------------------

--- Generate opcode documentation.
---@return string reference Formatted opcode reference
local function generateOpcodeDocumentation()
	-- TODO/CONS: Cache the result? Or precompile this?
	local lines = {
		"----------------------------------------------------------------------",
		"CHEATOID VIRTUAL MACHINE - OPCODE REFERENCE",
		"----------------------------------------------------------------------",
		""
	}
	local categories = {
		{ name = "Control",       range = { 0x00, 0x0F } },
		{ name = "Data Movement", range = { 0x10, 0x2F } },
		{ name = "Arithmetic",    range = { 0x30, 0x4F } },
		{ name = "Bitwise",       range = { 0x50, 0x5F } },
		{ name = "Comparison",    range = { 0x60, 0x6F } },
		{ name = "Jumps",         range = { 0x70, 0x7F } },
		{ name = "Subroutine",    range = { 0x80, 0x8F } },
		{ name = "System",        range = { 0x90, 0x9F } },
		{ name = "Extended",      range = { 0xA0, 0xAF } },
		{ name = "String",        range = { 0xB0, 0xBF } },
		{ name = "Float",         range = { 0xC0, 0xCF } },
		{ name = "Vector",        range = { 0xD0, 0xDF } },
		{ name = "Loop",          range = { 0xE0, 0xEF } },
		{ name = "Debug",         range = { 0xF0, 0xFF } },
	}
	for i = 1, #categories do
		local cat = categories[i]
		table_insert(lines, "--- " .. cat.name .. " ---")
		for code = cat.range[1], cat.range[2] do
			local opdef = OPCODES[code]
			if opdef then
				table_insert(lines,
					string_format("  0x%02X: %-12s [%d] %s", opdef.code, opdef.name, opdef.operandCount,
						opdef.description))
			end
		end
		table_insert(lines, "")
	end
	return table_concat(lines, "\n")
end

----------------------------------------------------------------------
-- MODULE EXPORT
----------------------------------------------------------------------

local module = {
	-- Core classes
	VM = VM,
	Memory = Memory,
	Registers = Registers,

	-- Utility classes
	Assembler = Assembler,
	Disassembler = Disassembler,
	Builder = Builder,
	Utils = Utils,

	-- Opcode table
	OPCODES = OPCODES,

	-- Documentation
	generateOpcodeDocumentation = generateOpcodeDocumentation,

	-- Version
	VERSION = VM.VERSION
}

--- Create a new VM instance (convenience function).
---@return VM vm New virtual machine instance.
function module.new()
	return VM.new()
end

--- Assemble and run source code in one call.
---@param source string Assembly source code.
---@param maxCycles? number Maximum cycles to run (optional).
---@return table result Result with success, error, returnValue, vm fields.
function module.run(source, maxCycles)
	local vm = VM.new()
	local result = VM.loadAndRun(vm, source, maxCycles)
	result.vm = vm
	return result
end

--- Create a new Assembler instance.
---@return Assembler assembler New assembler instance.
function module.newAssembler()
	return Assembler.new()
end

--- Create a new Disassembler instance.
---@return Disassembler disassembler New disassembler instance.
function module.newDisassembler()
	return Disassembler.new()
end

--- Create a new Builder instance.
---@return Builder builder New builder instance.
function module.newBuilder()
	return Builder.new()
end

-- Export
return module
