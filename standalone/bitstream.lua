-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Bit-level reader/writer used by the JPEG codec.
--
-- JPEG-specific behavior:
-- * BitWriter byte-stuffs entropy data: every 0xFF byte is followed by 0x00.
-- * BitReader reverses the stuffing and stops when it sees a real marker
--   (0xFF followed by a non-zero byte), reporting the marker code.
-- * Bits are packed MSB-first, as required by JPEG entropy coding.
--
-- Usage example:
-- ```
-- local bitstream = require "bitstream"
--
-- local writer = bitstream.BitWriter.new()
-- writer:write_bits(0xAB, 8)
-- writer:write_marker(0xD9)
-- local bytes = writer:result()
--
-- local reader = bitstream.BitReader.new(bytes, 1)
-- local value = reader:read_bits(8)
-- ```

-- Localized global functions for better performance
local setmetatable = setmetatable
local math_floor   = math.floor
local string_byte  = string.byte
local string_char  = string.char
local table_concat = table.concat

----------------------------------------------------------------------
-- Module definition
----------------------------------------------------------------------

--- Bit-level reader/writer used by the JPEG codec.
---@class bitstream
local M            = {}

--- Precomputed powers of two (POW2[i] = 2^i).<br>
--- Cheaper than `2 ^ i` in loops and portable across Lua 5.1/5.3.
---@type number[]
local POW2         = {}
for i = 0, 32 do POW2[i] = 2 ^ i end
M.POW2 = POW2

----------------------------------------------------------------------
-- BitWriter
----------------------------------------------------------------------

--- MSB-first bit accumulator with JPEG byte stuffing.
---@class BitWriter
---@field parts string[] Finished byte chunks.
---@field np integer Number of chunks in `parts`.
---@field buffer integer Pending bits, kept MSB-aligned at the top.
---@field nbits integer Number of pending bits in `buffer`.
local BitWriter = {}
BitWriter.__index = BitWriter

--- Create a new empty writer.
---@return BitWriter writer A new writer instance.
---@usage <br>
--- ```
--- local writer = bitstream.BitWriter.new()
--- ```
function BitWriter.new()
	return setmetatable({
		parts = {}, -- finished byte chunks (strings)
		np = 0,
		buffer = 0, -- pending bits, kept MSB-aligned at the top
		nbits = 0, -- number of pending bits in buffer
	}, BitWriter)
end

--- Emit one raw byte (headers and markers).<br>
--- Never stuffed, so the caller must be byte-aligned.
---@param b integer Byte value 0..255.
function BitWriter:emit_raw(b)
	self.np = self.np + 1
	self.parts[self.np] = string_char(b)
end

--- Emit one entropy-coded byte, applying JPEG byte stuffing (F.1.2.3).<br>
--- A 0xFF byte is followed by a 0x00 stuff byte so it cannot be
--- mistaken for a marker prefix.
---@param b integer Byte value 0..255.
function BitWriter:emit_entropy_byte(b)
	self:emit_raw(b)
	if b == 0xFF then -- 0xFF could be mistaken for a marker prefix,
		self:emit_raw(0x00) -- so a 0x00 "stuff" byte must follow it
	end
end

--- Write the `nbits` low bits of `value`, most significant bit first.<br>
--- Full bytes are flushed via `emit_entropy_byte` as they accumulate.
---@param value integer Bits to write (only the low `nbits` are used).
---@param nbits integer Number of bits to write.
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

--- Pad the last partial byte with 1-bits (JPEG convention).<br>
--- Byte-aligns the stream; a no-op when already aligned.
function BitWriter:flush_bits()
	if self.nbits > 0 then
		local pad = 8 - self.nbits
		self:write_bits(POW2[pad] - 1, pad)
	end
end

--- Finish the current byte (padding with 1s) and emit a marker.<br>
--- Markers are raw bytes and are never stuffed.
---@param m integer Marker code (the byte after 0xFF, e.g. 0xD9 for EOI).
---@usage <br>
--- ```
--- writer:write_marker(0xD9) -- EOI
--- ```
function BitWriter:write_marker(m)
	self:flush_bits()
	self:emit_raw(0xFF)
	self:emit_raw(m)
end

--- Write a prebuilt byte string (headers).<br>
--- The caller must be byte-aligned.
---@param s string Bytes to append verbatim.
function BitWriter:write_string(s)
	if #s > 0 then
		self.np = self.np + 1
		self.parts[self.np] = s
	end
end

--- Concatenate all emitted chunks into a single string.
---@return string bytes The accumulated output.
function BitWriter:result()
	return table_concat(self.parts)
end

----------------------------------------------------------------------
-- BitReader
----------------------------------------------------------------------

--- MSB-first bit reader with unstuffing and marker detection.
---@class BitReader
---@field data string Full file string being read.
---@field pos integer Next unread byte position in `data`.
---@field buffer integer Current byte being consumed bit by bit.
---@field nbits integer Number of unread bits left in `buffer`.
local BitReader = {}
BitReader.__index = BitReader

--- Create a new reader over `data` starting at byte `pos`.
---@param data string Full file string containing entropy-coded data.
---@param pos? integer First byte of entropy-coded data (default 1).
---@return BitReader reader A new reader instance.
---@usage <br>
--- ```
--- local reader = bitstream.BitReader.new(data, pos)
--- ```
function BitReader.new(data, pos)
	return setmetatable({
		data = data,
		pos = pos or 1,
		buffer = 0,
		nbits = 0,
	}, BitReader)
end

--- Read one bit.<br>
--- Stuffed 0xFF 0x00 pairs are transparent; a real marker ends the read.
---@return integer|nil bit 0 or 1 on success, nil on marker/truncation.
---@return number|string|nil err Marker code when a marker is hit, error message on truncation.
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

--- Read `n` bits MSB-first as a number.
---@param n integer Number of bits to read.
---@return integer|nil value The accumulated bits, or nil on marker/truncation.
---@return number|string|nil err Marker code or error message from `read_bit`.
function BitReader:read_bits(n)
	local v = 0
	for _ = 1, n do
		local b, err = self:read_bit()
		if not b then return nil, err end
		v = v * 2 + b
	end
	return v
end

--- Discard the remainder of the current byte (byte-align).
function BitReader:align_byte()
	self.buffer, self.nbits = 0, 0
end

--- Byte-align, then read the next marker.<br>
--- Skips 0xFF fill bytes and stuffed 0xFF 0x00 pairs (the latter happens
--- when the pre-marker pad byte is 0xFF).
---@return integer|nil marker Marker code (0x01..0xFE), or nil at EOF.
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
