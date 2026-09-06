-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- LZMA compressor compatible with Garry's Mod `util.Compress`

-- Localized global functions for better performance
local setmetatable = setmetatable
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
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

---@class RangeEncoder
local RangeEncoder = {}
RangeEncoder.__index = RangeEncoder

--- Create a new RangeEncoder.
---@param outStream table The output stream table.
---@return RangeEncoder instance The new RangeEncoder instance.
function RangeEncoder:new(outStream)
	return setmetatable({
		outStream = outStream,
		Low = 0,
		Range = 4294967295,
		Cache = 0,
		CacheSize = 1
	}, self)
end

--- Write a single byte to the output stream.
---@param b number The byte to write.
function RangeEncoder:writeByte(b)
	self.outStream[#self.outStream + 1] = string_char(b % 256)
end

--- Shift the low range and write bytes as needed.
function RangeEncoder:shiftLow()
	-- Check if the lower 32 bits have overflowed or are in the carry zone
	if self.Low >= 0xFFFFFFFF then
		local carry = math_floor(self.Low / 0x100000000)
		local temp = self.Cache
		repeat
			self:writeByte((temp + carry) % 256)
			temp = 255
			self.CacheSize = self.CacheSize - 1
		until self.CacheSize == 0
		self.Cache = math_floor((self.Low % 0x100000000) / 0x1000000) % 256
		self.CacheSize = 1
	elseif self.Low < 0xFF000000 then
		local temp = self.Cache
		repeat
			self:writeByte(temp)
			temp = 0
			self.CacheSize = self.CacheSize - 1
		until self.CacheSize == 0
		self.Cache = math_floor(self.Low / 0x1000000) % 256
		self.CacheSize = 1
	else
		self.CacheSize = self.CacheSize + 1
	end

	-- Maintain only 32-bit precision for the lower bits to match LZMA SDK C++ behavior
	self.Low = (self.Low % 0x100000000) * 256 % 0x100000000
end

--- Normalize the range encoder state.
function RangeEncoder:normalize()
	if self.Range < 16777216 then
		self.Range = self.Range * 256
		self:shiftLow()
	end
end

--- Encode a single bit using probability.
---@param prob number The probability value.
---@param bit number The bit to encode (0 or 1).
---@return number new_prob The updated probability.
function RangeEncoder:encodeBit(prob, bit)
	self:normalize()
	local bound = math_floor(self.Range / 2048) * prob
	if bit == 0 then
		self.Range = bound
		return prob + math_floor((2048 - prob) / 32)
	end
	self.Low = self.Low + bound
	self.Range = self.Range - bound
	return prob - math_floor(prob / 32)
end

--- Encode direct bits (without probability modeling).
---@param value number The value to encode.
---@param numBits number The number of bits to encode.
function RangeEncoder:encodeDirectBits(value, numBits)
	for i = 1, numBits do
		self:normalize()
		self.Range = math_floor(self.Range / 2)
		local bit = bit_band(bit_rshift(value, numBits - i), 1)
		if bit ~= 0 then
			self.Low = self.Low + self.Range
		end
	end
end

--- Flush the range encoder state.
function RangeEncoder:flush()
	for i = 1, 5 do
		self:shiftLow()
	end
end

--- Encode a symbol into a bit tree.
---@param rd RangeEncoder The range encoder.
---@param probs table The probability table.
---@param numBits number The number of bits.
---@param symbol number The symbol to encode.
---@param probOffset number The offset in the probability table.
local function BitTreeEncode(rd, probs, numBits, symbol, probOffset)
	local m = 1
	for i = 1, numBits do
		local bit = bit_band(bit_rshift(symbol, numBits - i), 1)
		probs[probOffset + m] = rd:encodeBit(probs[probOffset + m], bit)
		m = m * 2 + bit
	end
end

--- Encode a symbol into a reverse bit tree.
---@param rd RangeEncoder The range encoder.
---@param probs table The probability table.
---@param numBits number The number of bits.
---@param symbol number The symbol to encode.
---@param probOffset number The offset in the probability table.
local function ReverseBitTreeEncode(rd, probs, numBits, symbol, probOffset)
	local m = 1
	for i = 1, numBits do
		local bit = bit_band(symbol, 1)
		symbol = bit_rshift(symbol, 1)
		probs[probOffset + m] = rd:encodeBit(probs[probOffset + m], bit)
		m = m * 2 + bit
	end
end

---@class LenEncoder
local LenEncoder = {}
LenEncoder.__index = LenEncoder

--- Create a new LenEncoder.
---@return LenEncoder instance The new LenEncoder instance.
function LenEncoder:new()
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

--- Encode a length value.
---@param rd RangeEncoder The range encoder.
---@param len number The length to encode.
---@param posState number The position state.
function LenEncoder:encode(rd, len, posState)
	if len < 8 then
		self.Choice = rd:encodeBit(self.Choice, 0)
		BitTreeEncode(rd, self.Low, 3, len, posState * 8 + 1)
	elseif len < 16 then
		self.Choice = rd:encodeBit(self.Choice, 1)
		self.Choice2 = rd:encodeBit(self.Choice2, 0)
		BitTreeEncode(rd, self.Mid, 3, len - 8, posState * 8 + 1)
	else
		self.Choice = rd:encodeBit(self.Choice, 1)
		self.Choice2 = rd:encodeBit(self.Choice2, 1)
		BitTreeEncode(rd, self.High, 8, len - 16, 1)
	end
end

---@class LZMAEncoder
local LZMAEncoder = {}
LZMAEncoder.__index = LZMAEncoder

--- Create a new LZMAEncoder.
---@param props number The properties byte.
---@return LZMAEncoder instance The new LZMAEncoder instance.
function LZMAEncoder:new(props)
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
		LenEncoder = LenEncoder:new(),
		RepLenEncoder = LenEncoder:new(),
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

--- Encode a literal byte.
---@param rd RangeEncoder The range encoder.
---@param data string The input data.
---@param byte number The byte to encode.
---@param prevByte number The previous byte.
---@param pos number The current position.
---@param state number The current state.
---@param rep0 number The most recent distance.
function LZMAEncoder:encodeLiteral(rd, data, byte, prevByte, pos, state, rep0)
	local litState = bit_bor(bit_lshift(bit_band(pos, bit_lshift(1, self.lp) - 1), self.lc),
		bit_rshift(prevByte, 8 - self.lc))
	local probIdx = litState * 0x300 + 1

	if state < 7 then
		local m = 1
		for i = 1, 8 do
			local bit = bit_band(bit_rshift(byte, 7), 1)
			byte = bit_lshift(byte, 1) % 256
			self.LiteralProbs[probIdx + m - 1] = rd:encodeBit(self.LiteralProbs[probIdx + m - 1], bit)
			m = m * 2 + bit
		end
	else
		local matchByte = string_byte(data, pos - rep0) or 0
		local m = 1
		while m < 0x100 do
			local matchBit = bit_band(bit_rshift(matchByte, 7), 1)
			matchByte = bit_lshift(matchByte, 1) % 256
			local bit = bit_band(bit_rshift(byte, 7), 1)
			byte = bit_lshift(byte, 1) % 256
			local probIdx2 = probIdx + m + matchBit * 0x100 - 1
			self.LiteralProbs[probIdx2] = rd:encodeBit(self.LiteralProbs[probIdx2], bit)
			m = m * 2 + bit
			if matchBit ~= bit then
				while m < 0x100 do
					local bit2 = bit_band(bit_rshift(byte, 7), 1)
					byte = bit_lshift(byte, 1) % 256
					self.LiteralProbs[probIdx + m - 1] = rd:encodeBit(self.LiteralProbs[probIdx + m - 1], bit2)
					m = m * 2 + bit2
				end
				break
			end
		end
	end
end

--- Encode a distance value.
---@param rd RangeEncoder The range encoder.
---@param dist number The distance to encode.
---@param len number The length.
function LZMAEncoder:encodeDistance(rd, dist, len)
	local lenState = len
	if lenState > 3 then lenState = 3 end

	local posSlot
	if dist < 4 then
		posSlot = dist
	else
		local k = 1
		local d = dist
		while d >= 4 do
			d = math_floor(d / 2)
			k = k + 1
		end
		posSlot = bit_lshift(k, 1) + bit_band(bit_rshift(dist, k - 1), 1)
	end

	BitTreeEncode(rd, self.PosSlotDecoder[lenState + 1].probs, 6, posSlot, 1)

	if posSlot >= kStartPosModelIndex then
		local numDirectBits = bit_rshift(posSlot, 1) - 1
		local base = bit_lshift(bit_bor(2, bit_band(posSlot, 1)), numDirectBits)

		if posSlot < kEndPosModelIndex then
			ReverseBitTreeEncode(rd, self.SpecPos, numDirectBits, dist - base, base - posSlot)
		else
			local dist2 = dist - base
			rd:encodeDirectBits(bit_rshift(dist2, kNumAlignBits), numDirectBits - kNumAlignBits)
			ReverseBitTreeEncode(rd, self.Align, kNumAlignBits, bit_band(dist2, 15), 1)
		end
	end
end

--- Find the best match in the look-behind window.
---@param data string The input data.
---@param pos number The current position.
---@return number len The length of the match.
---@return number dist The distance of the match.
local function FindMatch(data, pos)
	if pos + 2 > #data then return 0, 0 end
	local maxLen = math_min(273, #data - pos + 1)
	if maxLen < 2 then return 0, 0 end

	local bestLen = 0
	local bestDist = 0
	local startByte = string_byte(data, pos)

	-- Very basic look-behind window
	local windowStart = math_max(1, pos - 65535)
	for p = pos - 1, windowStart, -1 do
		if string_byte(data, p) == startByte then
			local len = 1
			while len < maxLen and string_byte(data, p + len) == string_byte(data, pos + len) do
				len = len + 1
			end
			if len > bestLen then
				bestLen = len
				bestDist = pos - p
				if len >= maxLen then break end
			end
		end
	end

	if bestLen >= 2 then
		return bestLen, bestDist
	end
	return 0, 0
end

--- Compress data using LZMA.
---@param data string The data to compress.
---@return string compressed The compressed data.
local function compress(data)
	if #data == 0 then return "" end

	local outStream = {}

	-- Write LZMA header (props=93, dictSize=65536, uncompressedSize=#data)
	outStream[1] = string_char(93)      -- lc=3, lp=0, pb=2 -> (2*5+0)*9+3 = 93
	outStream[2] = string_char(0, 0, 1, 0) -- dictSize = 65536 (0x10000)

	local s1 = #data
	outStream[3] = string_char(
		bit_band(s1, 255),
		bit_band(bit_rshift(s1, 8), 255),
		bit_band(bit_rshift(s1, 16), 255),
		bit_band(bit_rshift(s1, 24), 255),
		0, 0, 0, 0
	)

	local rd = RangeEncoder:new(outStream)
	local encoder = LZMAEncoder:new(93)

	local pos = 1
	local state = 0
	local rep0, rep1, rep2, rep3 = 0, 0, 0, 0
	local pbMask = bit_lshift(1, encoder.pb) - 1

	while pos <= #data do
		local posState = bit_band(pos - 1, pbMask)
		local probOffset = state * 16 + posState + 1

		local len, dist = FindMatch(data, pos)

		if len >= 2 then
			encoder.IsMatch[probOffset] = rd:encodeBit(encoder.IsMatch[probOffset], 1)
			encoder.IsRep[state + 1] = rd:encodeBit(encoder.IsRep[state + 1], 0)

			rep3 = rep2
			rep2 = rep1
			rep1 = rep0
			rep0 = dist - 1

			len = len - kMatchMinLen
			encoder.LenEncoder:encode(rd, len, posState)
			encoder:encodeDistance(rd, rep0, len)

			state = stateMatch[state + 1]
			pos = pos + len + kMatchMinLen
		else
			encoder.IsMatch[probOffset] = rd:encodeBit(encoder.IsMatch[probOffset], 0)
			local byte = string_byte(data, pos)
			local prevByte = (pos > 1) and string_byte(data, pos - 1) or 0
			encoder:encodeLiteral(rd, data, byte, prevByte, pos - 1, state, rep0)
			state = stateInitLiteral[state + 1]
			pos = pos + 1
		end
	end

	-- End marker
	local posState = bit_band(pos - 1, pbMask)
	local probOffset = state * 16 + posState + 1
	encoder.IsMatch[probOffset] = rd:encodeBit(encoder.IsMatch[probOffset], 1)
	encoder.IsRep[state + 1] = rd:encodeBit(encoder.IsRep[state + 1], 0)
	encoder.LenEncoder:encode(rd, 0, posState)
	BitTreeEncode(rd, encoder.PosSlotDecoder[1].probs, 6, 63, 1)
	rd:encodeDirectBits(0xFFFFFFFF, 30)

	rd:flush()

	return table_concat(outStream)
end

--[=[ Quick tests
if true then
	local total, passed, failed = 0, 0, 0
	local function test(name, fn)
		total = total + 1
		local ok, err = pcall(fn)
		if ok then
			passed = passed + 1
		else
			failed = failed + 1
			print(string.format("  FAIL  %s: %s", name, tostring(err)))
		end
	end

	-- Test LZMA compression
	test("compress valid LZMA data", function()
		local byte_str =
		"93 0 0 1 0 62 0 0 0 0 0 0 0 0 32 144 132 118 186 138 117 207 180 13 178 232 159 19 135 248 5 87 125 236 173 238 116 120 0 242 66 235 152 102 11 21 21 45 203 35 190 212 185 154 198 32 127 124 106 189 38 245 64 115 240 253 165 25 16 99 62 172 104 197 155 37 255 219 0 254 63 136 0"
		local expected = {}
		for byte in byte_str:gmatch("%d+") do
			expected[#expected + 1] = string_char(tonumber(byte))
		end
		expected = table_concat(expected)
		local compressed = compress("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")
		assert(#compressed == #expected)
		assert(compressed == expected)
	end)

	test("compress empty data", function()
		assert(compress("") == "")
	end)

	test("compress short data", function()
		local compressed = compress("a")
		assert(#compressed > 0)
	end)

	print(string.format("[lzmac] %d/%d tests passed (%d failed)", passed, total, failed))
	assert(failed == 0, string.format("%d test(s) failed", failed))
end
--]=]

-- Export
return {
	RangeEncoder = RangeEncoder,
	LenEncoder = LenEncoder,
	LZMAEncoder = LZMAEncoder,
	compress = compress,
}
