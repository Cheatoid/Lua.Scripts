-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- LZMA decompressor compatible with Garry's Mod `util.Decompress`

-- Localized global functions for better performance
local setmetatable = setmetatable
local math_floor = math.floor
local string_byte = string.byte
local string_char = string.char
local table_concat = table.concat

-- Load bits module for bit operations (standalone compatible)
local bits = require "bits"
local bit_band, bit_bor, bit_lshift, bit_rshift = bits.band, bits.bor, bits.lshift, bits.rshift

-- LZMA constants
local kNumStates = 12
local kNumLenToPosStates = 4
local kNumAlignBits = 4
local kStartPosModelIndex = 4
local kEndPosModelIndex = 14
local kMatchMinLen = 2

local stateInitLiteral = { 0, 0, 0, 0, 1, 2, 3, 4, 5, 6, 4, 5 }
local stateMatch = { 7, 7, 7, 7, 7, 7, 7, 10, 10, 10, 10, 10 }
local stateRep = { 8, 8, 8, 8, 8, 8, 8, 11, 11, 11, 11, 11 }
local stateShortRep = { 9, 9, 9, 9, 9, 9, 9, 11, 11, 11, 11, 11 }

---@class RangeDecoder
local RangeDecoder = {}
RangeDecoder.__index = RangeDecoder

--- Create a new RangeDecoder.
---@param data string The input data.
---@param pos number The starting position.
---@return RangeDecoder instance The new RangeDecoder instance.
function RangeDecoder:new(data, pos)
	local obj = setmetatable({ data = data, pos = pos, Range = 4294967295, Code = 0 }, self)
	obj:readByte() -- discard first byte
	local b1 = obj:readByte()
	local b2 = obj:readByte()
	local b3 = obj:readByte()
	local b4 = obj:readByte()
	obj.Code = b1 * 16777216 + b2 * 65536 + b3 * 256 + b4
	return obj
end

--- Read a single byte from the data.
---@return number byte The byte read (0 if at end).
function RangeDecoder:readByte()
	local p = self.pos
	local b = string_byte(self.data, p)
	self.pos = p + 1
	return b or 0
end

--- Normalize the range decoder state.
function RangeDecoder:normalize()
	if self.Range < 16777216 then
		self.Range = self.Range * 256
		self.Code = self.Code * 256 + self:readByte()
	end
end

--- Decode a single bit using probability.
---@param prob number The probability value.
---@return number new_prob The updated probability.
---@return number bit The decoded bit (0 or 1).
function RangeDecoder:decodeBit(prob)
	self:normalize()
	local bound = math_floor(self.Range / 2048) * prob
	if self.Code >= bound then
		self.Range = self.Range - bound
		self.Code = self.Code - bound
		local new_prob = prob - math_floor(prob / 32)
		return new_prob, 1
	end
	self.Range = bound
	local new_prob = prob + math_floor((2048 - prob) / 32)
	return new_prob, 0
end

--- Decode direct bits (without probability modeling).
---@param numBits number The number of bits to decode.
---@return number res The decoded value.
function RangeDecoder:decodeDirectBits(numBits)
	local res = 0
	local p = 1
	for i = 1, numBits do
		self:normalize()
		self.Range = math_floor(self.Range / 2)
		local t = self.Code - self.Range
		if t >= 0 then
			self.Code = t
			res = res + p
		end
		p = p * 2
	end
	return res
end

--- Decode a symbol from a bit tree.
---@param rd RangeDecoder The range decoder.
---@param probs table The probability table.
---@param numBits number The number of bits.
---@param probOffset number The offset in the probability table.
---@return number symbol The decoded symbol.
local function BitTreeDecode(rd, probs, numBits, probOffset)
	local m = 1
	for i = 1, numBits do
		local b
		probs[probOffset + m], b = rd:decodeBit(probs[probOffset + m])
		m = m * 2 + b
	end
	return m - bit_lshift(1, numBits)
end

--- Decode a symbol from a reverse bit tree.
---@param rd RangeDecoder The range decoder.
---@param probs table The probability table.
---@param numBits number The number of bits.
---@param probOffset number The offset in the probability table.
---@return number symbol The decoded symbol.
local function ReverseBitTreeDecode(rd, probs, numBits, probOffset)
	local m = 1
	local symbol = 0
	for i = 1, numBits do
		local b
		probs[probOffset + m], b = rd:decodeBit(probs[probOffset + m])
		m = m * 2
		if b ~= 0 then
			m = m + 1
			symbol = symbol + bit_lshift(1, i - 1)
		end
	end
	return symbol
end

---@class LenDecoder
local LenDecoder = {}
LenDecoder.__index = LenDecoder

--- Create a new LenDecoder.
---@return LenDecoder instance The new LenDecoder instance.
function LenDecoder:new()
	local obj = {
		Choice = 1024,
		Choice2 = 1024,
		Low = {},
		Mid = {},
		High = {}
	}
	for i = 1, 128 do obj.Low[i] = 1024 end
	for i = 1, 128 do obj.Mid[i] = 1024 end
	for i = 1, 256 do obj.High[i] = 1024 end
	return setmetatable(obj, self)
end

--- Decode a length value.
---@param rd RangeDecoder The range decoder.
---@param posState number The position state.
---@return number len The decoded length.
function LenDecoder:decode(rd, posState)
	local b
	self.Choice, b = rd:decodeBit(self.Choice)
	if b == 0 then
		return BitTreeDecode(rd, self.Low, 3, posState * 8)
	end
	self.Choice2, b = rd:decodeBit(self.Choice2)
	if b == 0 then
		return 8 + BitTreeDecode(rd, self.Mid, 3, posState * 8)
	end
	return 16 + BitTreeDecode(rd, self.High, 8, 0)
end

---@class LZMADecoder
local LZMADecoder = {}
LZMADecoder.__index = LZMADecoder

--- Create a new LZMADecoder.
---@param props number The properties byte.
---@return LZMADecoder instance The new LZMADecoder instance.
function LZMADecoder:new(props)
	local lc = props % 9
	props = math_floor(props / 9)
	local lp = props % 5
	local pb = math_floor(props / 5)

	local obj = {
		lc = lc,
		lp = lp,
		pb = pb,
		IsMatch = {},
		IsRep = {},
		IsRepG0 = {},
		IsRepG1 = {},
		IsRepG2 = {},
		IsRep0Long = {},
		PosSlotDecoder = {},
		Align = {},
		SpecPos = {},
		LenDecoder = LenDecoder:new(),
		RepLenDecoder = LenDecoder:new(),
		LiteralProbs = {}
	}

	for i = 1, 192 do obj.IsMatch[i] = 1024 end
	for i = 1, 12 do obj.IsRep[i] = 1024 end
	for i = 1, 12 do obj.IsRepG0[i] = 1024 end
	for i = 1, 12 do obj.IsRepG1[i] = 1024 end
	for i = 1, 12 do obj.IsRepG2[i] = 1024 end
	for i = 1, 192 do obj.IsRep0Long[i] = 1024 end
	for i = 1, 16 do obj.Align[i] = 1024 end
	for i = 1, 114 do obj.SpecPos[i] = 1024 end

	for i = 1, 4 do
		obj.PosSlotDecoder[i] = { probs = {} }
		for j = 1, 64 do obj.PosSlotDecoder[i].probs[j] = 1024 end
	end

	local numStates = bit_lshift(1, obj.lc + obj.lp)
	for i = 1, numStates * 0x300 do obj.LiteralProbs[i] = 1024 end

	return setmetatable(obj, self)
end

--- Decode a distance value.
---@param rd RangeDecoder The range decoder.
---@param len number The length.
---@return number distance The decoded distance.
function LZMADecoder:decodeDistance(rd, len)
	local lenState = len
	if lenState > 3 then lenState = 3 end

	local posSlot = BitTreeDecode(rd, self.PosSlotDecoder[lenState + 1].probs, 6, 0)
	if posSlot < kStartPosModelIndex then
		return posSlot
	end

	local numDirectBits = bit_rshift(posSlot, 1) - 1
	local base = bit_lshift(bit_bor(2, bit_band(posSlot, 1)), numDirectBits)

	if posSlot < kEndPosModelIndex then
		return base + ReverseBitTreeDecode(rd, self.SpecPos, numDirectBits, base - posSlot - 1)
	end
	local dist = base + rd:decodeDirectBits(numDirectBits - kNumAlignBits) * 16
	return dist + ReverseBitTreeDecode(rd, self.Align, kNumAlignBits, 0)
end

--- Decompress LZMA data.
---@param data string The compressed data.
---@return string decompressed The decompressed data.
local function decompress(data)
	if #data < 13 then return "" end

	local props = string_byte(data, 1)
	local dictSize = string_byte(data, 2) +
			string_byte(data, 3) * 256 +
			string_byte(data, 4) * 65536 +
			string_byte(data, 5) * 16777216
	local s1 = string_byte(data, 6) +
			string_byte(data, 7) * 256 +
			string_byte(data, 8) * 65536 +
			string_byte(data, 9) * 16777216
	local s2 = string_byte(data, 10) +
			string_byte(data, 11) * 256 +
			string_byte(data, 12) * 65536 +
			string_byte(data, 13) * 16777216
	local outSize = s1 + s2 * 4294967296

	if props >= 225 then return "" end -- invalid properties

	local rd = RangeDecoder:new(data, 14)
	local decoder = LZMADecoder:new(props)

	local outBuffer = {}
	local pos = 0
	local state = 0
	local rep0, rep1, rep2, rep3 = 0, 0, 0, 0

	local pbMask = bit_lshift(1, decoder.pb) - 1
	local lpMask = bit_lshift(1, decoder.lp) - 1
	local lc = decoder.lc

	while pos < outSize do
		local posState = bit_band(pos, pbMask)
		local probOffset = state * 16 + posState

		local b
		decoder.IsMatch[probOffset + 1], b = rd:decodeBit(decoder.IsMatch[probOffset + 1])

		if b == 0 then
			-- Literal
			local prevByte = 0
			if pos > 0 then prevByte = string_byte(outBuffer[pos]) end

			local litState = bit_bor(bit_lshift(bit_band(pos, lpMask), lc), bit_rshift(prevByte, 8 - lc))
			local probIdx = litState * 0x300
			local m = 1

			if state < 7 then
				while m < 0x100 do
					local bit
					decoder.LiteralProbs[probIdx + m], bit = rd:decodeBit(decoder.LiteralProbs[probIdx + m])
					m = m * 2 + bit
				end
			else
				local matchByte = string_byte(outBuffer[pos - rep0] or "\0")
				while m < 0x100 do
					local matchBit = bit_band(bit_rshift(matchByte, 7), 1)
					matchByte = bit_lshift(matchByte, 1)
					local probIdx2 = probIdx + m + matchBit * 0x100
					local bit
					decoder.LiteralProbs[probIdx2], bit = rd:decodeBit(decoder.LiteralProbs[probIdx2])
					m = m * 2 + bit
					if matchBit ~= bit then
						while m < 0x100 do
							local b2
							decoder.LiteralProbs[probIdx + m], b2 = rd:decodeBit(decoder.LiteralProbs[probIdx + m])
							m = m * 2 + b2
						end
						break
					end
				end
			end

			pos = pos + 1
			outBuffer[pos] = string_char(m - 0x100)
			state = stateInitLiteral[state + 1]
		else
			-- Match
			decoder.IsRep[state + 1], b = rd:decodeBit(decoder.IsRep[state + 1])
			local len

			if b == 0 then
				rep3 = rep2
				rep2 = rep1
				rep1 = rep0
				len = decoder.LenDecoder:Decode(rd, posState)
				rep0 = decoder:decodeDistance(rd, len)

				if rep0 == 0xFFFFFFFF then break end -- end marker
				len = len + kMatchMinLen
				state = stateMatch[state + 1]
			else
				decoder.IsRepG0[state + 1], b = rd:decodeBit(decoder.IsRepG0[state + 1])
				if b == 0 then
					local probIdx = state * 16 + posState
					decoder.IsRep0Long[probIdx + 1], b = rd:decodeBit(decoder.IsRep0Long[probIdx + 1])
					if b == 0 then
						state = stateShortRep[state + 1]
						pos = pos + 1
						outBuffer[pos] = outBuffer[pos - rep0 - 1] or "\0"
					else
						len = decoder.RepLenDecoder:decode(rd, posState) + kMatchMinLen
						state = stateRep[state + 1]
					end
				else
					decoder.IsRepG1[state + 1], b = rd:decodeBit(decoder.IsRepG1[state + 1])
					local dist
					if b == 0 then
						dist = rep1
					else
						decoder.IsRepG2[state + 1], b = rd:decodeBit(decoder.IsRepG2[state + 1])
						if b == 0 then
							dist = rep2
						else
							dist = rep3
							rep3 = rep2
						end
						rep2 = rep1
					end
					rep1 = rep0
					rep0 = dist

					len = decoder.RepLenDecoder:decode(rd, posState) + kMatchMinLen
					state = stateRep[state + 1]
				end

				for i = 1, len do
					pos = pos + 1
					outBuffer[pos] = outBuffer[pos - rep0 - 1] or "\0"
				end
			end
		end
	end

	return table_concat(outBuffer, "")
end

-- Deprecated aliases (naming standard: snake_case). Kept for compatibility.
LZMADecoder.decode_distance = LZMADecoder.decodeDistance
RangeDecoder.decode_bit = RangeDecoder.decodeBit
RangeDecoder.decode_direct_bits = RangeDecoder.decodeDirectBits
RangeDecoder.read_byte = RangeDecoder.readByte

-- Export
return {
	RangeDecoder = RangeDecoder,
	LenDecoder = LenDecoder,
	LZMADecoder = LZMADecoder,
	decompress = decompress,
}
