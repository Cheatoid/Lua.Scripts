-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Bit-level reader/writer used by the JPEG codec.
--
-- JPEG-specific behavior:
-- * BitWriter byte-stuffs entropy data: every 0xFF byte is followed by 0x00.
-- * BitReader reverses the stuffing and stops when it sees a real marker
--   (0xFF followed by a non-zero byte), reporting the marker code.
-- * Bits are packed MSB-first, as required by JPEG entropy coding.

-- Localized global functions for better performance
local setmetatable = setmetatable
local math_floor   = math.floor
local string_byte  = string.byte
local string_char  = string.char
local table_concat = table.concat

local M            = {}

-- POW2[i] = 2^i  (precomputed: cheaper and 5.1/5.3-portable vs. 2^i in loops)
local POW2         = {}
for i = 0, 32 do POW2[i] = 2 ^ i end
M.POW2 = POW2

----------------------------------------------------------------------
-- BitWriter: MSB-first bit accumulator with JPEG byte stuffing
----------------------------------------------------------------------
local BitWriter = {}
BitWriter.__index = BitWriter

function BitWriter.new()
	return setmetatable({
		parts = {}, -- finished byte chunks (strings)
		np = 0,
		buffer = 0, -- pending bits, kept MSB-aligned at the top
		nbits = 0, -- number of pending bits in buffer
	}, BitWriter)
end

-- raw byte output (used for headers and markers: never stuffed)
function BitWriter:emit_raw(b)
	self.np = self.np + 1
	self.parts[self.np] = string_char(b)
end

-- entropy byte output: apply JPEG byte stuffing (F.1.2.3)
function BitWriter:emit_entropy_byte(b)
	self:emit_raw(b)
	if b == 0xFF then -- 0xFF could be mistaken for a marker prefix,
		self:emit_raw(0x00) -- so a 0x00 "stuff" byte must follow it
	end
end

-- write `nbits` low bits of `value`, most significant bit first
function BitWriter:write_bits(value, nbits)
	local buffer = self.buffer * POW2[nbits] + value
	local total = self.nbits + nbits
	while total >= 8 do
		local shift = total - 8
		local b = math_floor(buffer / POW2[shift])
		buffer = buffer - b * POW2[shift]
		total = total - 8
		self:emit_entropy_byte(b)
	end
	self.buffer, self.nbits = buffer, total
end

-- pad the last partial byte with 1-bits (JPEG convention), byte-aligning us
function BitWriter:flush_bits()
	if self.nbits > 0 then
		local pad = 8 - self.nbits
		self:write_bits(POW2[pad] - 1, pad)
	end
end

-- finish the current byte (padding with 1s) and emit a marker.
-- markers are raw bytes and are never stuffed.
function BitWriter:write_marker(m)
	self:flush_bits()
	self:emit_raw(0xFF)
	self:emit_raw(m)
end

-- write a prebuilt byte string (headers). caller must be byte-aligned.
function BitWriter:write_string(s)
	if #s > 0 then
		self.np = self.np + 1
		self.parts[self.np] = s
	end
end

function BitWriter:result()
	return table_concat(self.parts)
end

----------------------------------------------------------------------
-- BitReader: MSB-first bit reader with unstuffing + marker detection
----------------------------------------------------------------------
local BitReader = {}
BitReader.__index = BitReader

-- data: full file string, pos: first byte of entropy-coded data
function BitReader.new(data, pos)
	return setmetatable({
		data = data,
		pos = pos or 1,
		buffer = 0,
		nbits = 0,
	}, BitReader)
end

-- read one bit.
-- returns: bit            on success
--          nil, number    when a marker (0xFF xx, xx ~= 0) is hit; number = marker code
--          nil, string    on truncation
function BitReader:read_bit()
	if self.nbits == 0 then
		local data, pos = self.data, self.pos
		local b = string_byte(data, pos)
		if not b then return nil, "unexpected end of data" end
		pos = pos + 1
		if b == 0xFF then
			local b2 = string_byte(data, pos)
			if b2 == 0 then
				-- stuffed byte: 0xFF 0x00 represents a literal 0xFF data byte
				pos = pos + 1
			else
				-- real marker: report it (consume the marker byte as well)
				self.pos = pos + (b2 and 1 or 0)
				return nil, b2 or "unexpected end of data"
			end
		end
		self.pos = pos
		self.buffer, self.nbits = b, 8
	end
	self.nbits = self.nbits - 1
	return math_floor(self.buffer / POW2[self.nbits]) % 2
end

-- read n bits MSB-first as a number
function BitReader:read_bits(n)
	local v = 0
	for _ = 1, n do
		local b, err = self:read_bit()
		if not b then return nil, err end
		v = v * 2 + b
	end
	return v
end

-- discard the remainder of the current byte (byte-align)
function BitReader:align_byte()
	self.buffer, self.nbits = 0, 0
end

-- byte-align, then read the next marker, skipping:
--   * 0xFF fill bytes
--   * stuffed 0xFF 0x00 pairs (happens when the pre-marker pad byte is 0xFF)
-- returns marker code (0x01..0xFE) or nil at EOF.
function BitReader:read_marker()
	self:align_byte()
	local d, p, n = self.data, self.pos, #self.data
	local seen_ff = false
	while p <= n do
		local b = string_byte(d, p)
		p = p + 1
		if b == 0xFF then
			seen_ff = true
		elseif b == 0x00 and seen_ff then
			seen_ff = false -- stuffed zero; keep scanning
		elseif seen_ff then
			self.pos = p
			return b -- marker found
		else
			self.pos = p -- malformed; let the caller complain
			return b
		end
	end
	self.pos = p
	return nil
end

M.BitWriter = BitWriter
M.BitReader = BitReader

-- Export
return M
