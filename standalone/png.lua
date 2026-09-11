-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- PNG encoder/decoder library
--
-- QUICK API
-- png.setIO{ read = function(path) -> string end,
--            write = function(path, data) end }      -- inject file IO
-- local img = png.load("player.png")                 -- img.data = RGBA8
-- local img = png.decode(binstring, { raw = true })  -- native samples
-- local bin = png.encode({ width=w, height=h, data=rgba },
--                        { level=6, filter="adaptive", interlace=0 })
-- png.save("out.png", image, opts)
-- png.info(bin)            -- cheap header/metadata parse
-- png.getPixel(img, x, y)  -- 1-based, RGBA images -> r,g,b,a
-- png.selftest()           -- roundtrip sanity checks
--
-- Decode opts: { raw=false, check_crc=true, check_adler=true,
--                max_pixels=16777216 }
-- Encode opts: { colortype, bitdepth=8, level=6 (0..9), filter="adaptive",
--                interlace=0|1, palette=, transparent=, background=,
--                gamma=, srgb=, phys=, time=, texts=, idat_chunk_size= }

-- Localized global functions for better performance
local assert                = assert
local error                 = error
local ipairs                = ipairs
local setmetatable          = setmetatable
local tostring              = tostring
local type                  = type
local math_floor            = math.floor
local math_max              = math.max
local math_min              = math.min
local string_byte           = string.byte
local string_char           = string.char
local string_find           = string.find
local string_format         = string.format
local string_lower          = string.lower
local string_rep            = string.rep
local string_sub            = string.sub
local table_concat          = table.concat
local table_sort            = table.sort
local table_unpack          = table.unpack or unpack
local math_huge             = math.huge

-- Import dependencies
local bits                  = require "bits"
local band, bor, bnot, bxor = bits.band, bits.bor, bits.bnot, bits.bxor
local lshift, rshift        = bits.lshift, bits.rshift

local M                     = {}

local function fail(fmt, ...)
	return error(string_format("[png] " .. fmt, ...), 2)
end

----------------------------------------------------------------------
-- SECTION: small utilities
----------------------------------------------------------------------

local U32 = 4294967296

-- bit ops return signed 32-bit; normalize to unsigned when needed
local function u32(x)
	if x < 0 then return x + U32 end
	return x
end

local function u32be(s, pos)
	local b1, b2, b3, b4 = string_byte(s, pos, pos + 3)
	return b1 * 16777216 + b2 * 65536 + b3 * 256 + b4
end

local function be32str(v)
	return string_char(
		band(rshift(v, 24), 255),
		band(rshift(v, 16), 255),
		band(rshift(v, 8), 255),
		band(v, 255)
	)
end

-- Convert t[from..to] (byte numbers) to a string, respecting unpack() limits.
local function table_to_string(t, from, to)
	local parts, np = {}, 0
	local i = from
	while i <= to do
		local e = i + 4095
		if e > to then e = to end
		np = np + 1
		parts[np] = string_char(table_unpack(t, i, e))
		i = e + 1
	end
	return table_concat(parts)
end

local function str_to_bytes(s)
	local t = {}
	for i = 1, #s do t[i] = string_byte(s, i) end
	return t
end

----------------------------------------------------------------------
-- SECTION: CRC32 / Adler32
----------------------------------------------------------------------

local CRC_TABLE = {}
do
	for n = 0, 255 do
		local c = n
		for _ = 1, 8 do
			if band(c, 1) ~= 0 then
				c = bxor(rshift(c, 1), 0xEDB88320)
			else
				c = rshift(c, 1)
			end
		end
		CRC_TABLE[n] = c
	end
end

-- running CRC state (pre-inverted); pass 0xFFFFFFFF to start
local function crc_update(crc, s, from, to)
	for i = from, to do
		crc = bxor(CRC_TABLE[band(bxor(crc, string_byte(s, i)), 255)], rshift(crc, 8))
	end
	return crc
end

local function crc32(s)
	return u32(bxor(crc_update(0xFFFFFFFF, s, 1, #s), 0xFFFFFFFF))
end

local ADLER_NMAX = 5552
local function adler32(s, from, to)
	from = from or 1
	to = to or #s
	local s1, s2 = 1, 0
	local i = from
	while i <= to do
		local n = to - i + 1
		if n > ADLER_NMAX then n = ADLER_NMAX end
		local j = i + n - 1
		for k = i, j do
			s1 = s1 + string_byte(s, k)
			s2 = s2 + s1
		end
		s1 = s1 % 65521
		s2 = s2 % 65521
		i = j + 1
	end
	return u32(bor(lshift(s2, 16), s1))
end

----------------------------------------------------------------------
-- SECTION: ByteBuilder - windowed byte accumulator (memory-safe for huge
-- streams). `window` keeps the last N logical bytes addressable (needed by
-- inflate's backward copies).
----------------------------------------------------------------------

local ByteBuilder = {}
ByteBuilder.__index = ByteBuilder

function ByteBuilder.new(window)
	return setmetatable({
		t = {},
		n = 0,
		parts = {},
		np = 0,
		flushed = 0,
		window = window or 0
	}, ByteBuilder)
end

function ByteBuilder:flush_to(k)
	local from = self.flushed + 1
	if k < from then return end
	self.np = self.np + 1
	self.parts[self.np] = table_to_string(self.t, from, k)
	local t = self.t
	for j = from, k do t[j] = nil end
	self.flushed = k
end

function ByteBuilder:putb(b)
	local n = self.n + 1
	self.n = n
	self.t[n] = b
	local w = self.window
	if n - self.flushed >= 65536 + w then self:flush_to(n - w) end
end

-- only safe when window == 0 (deflate output), never for inflate output
function ByteBuilder:putstr(s)
	if self.n > self.flushed then self:flush_to(self.n) end
	if #s > 0 then
		self.np = self.np + 1
		self.parts[self.np] = s
	end
	self.n = self.n + #s
	self.flushed = self.n
end

function ByteBuilder:maybe_flush()
	local n, w = self.n, self.window
	if n - self.flushed >= 65536 + w then self:flush_to(n - w) end
end

function ByteBuilder:result()
	if self.n > self.flushed then self:flush_to(self.n) end
	return table_concat(self.parts)
end

----------------------------------------------------------------------
-- SECTION: BitReader
----------------------------------------------------------------------

local BR = {}
BR.__index = BR

function BR.new(s, first, last)
	return setmetatable({
		s = s,
		p = first or 1,
		stop = last or #s,
		buf = 0,
		n = 0
	}, BR)
end

function BR:fill()
	local s, p, stop = self.s, self.p, self.stop
	local buf, n = self.buf, self.n
	while n <= 24 and p <= stop do
		buf = bor(buf, lshift(string_byte(s, p), n))
		p = p + 1
		n = n + 8
	end
	self.buf, self.p, self.n = buf, p, n
end

function BR:read(nbits)
	if self.n < nbits then self:fill() end
	if self.n < nbits then return fail("unexpected end of deflate stream") end
	local v = band(self.buf, lshift(1, nbits) - 1)
	self.buf = rshift(self.buf, nbits)
	self.n = self.n - nbits
	return v
end

function BR:readbit()
	if self.n == 0 then self:fill() end
	if self.n == 0 then return fail("unexpected end of deflate stream") end
	local b = band(self.buf, 1)
	self.buf = rshift(self.buf, 1)
	self.n = self.n - 1
	return b
end

function BR:align_byte()
	if self.n > 0 then
		self.p = self.p - math_floor(self.n / 8)
		self.buf, self.n = 0, 0
	end
end

function BR:byte_aligned()
	if self.p > self.stop then return fail("truncated stored block") end
	local b = string_byte(self.s, self.p)
	self.p = self.p + 1
	return b
end

local BR_readbit = BR.readbit
local BR_read    = BR.read

----------------------------------------------------------------------
-- SECTION: BitWriter
----------------------------------------------------------------------

local BW         = {}
BW.__index       = BW

function BW.new()
	return setmetatable({ bb = ByteBuilder.new(0), buf = 0, nbits = 0 }, BW)
end

-- LSB-first (deflate packing order)
function BW:bits(val, n)
	local nbits = self.nbits + n
	local buf = bor(self.buf, lshift(val, self.nbits))
	local bb = self.bb
	while nbits >= 8 do
		bb:putb(band(buf, 255))
		buf = rshift(buf, 8)
		nbits = nbits - 8
	end
	self.buf, self.nbits = buf, nbits
end

function BW:bit1(b)
	local nbits = self.nbits + 1
	local buf = self.buf
	if b ~= 0 then buf = bor(buf, lshift(1, self.nbits)) end
	if nbits >= 8 then
		self.bb:putb(band(buf, 255))
		buf = rshift(buf, 8)
		nbits = nbits - 8
	end
	self.buf, self.nbits = buf, nbits
end

-- MSB-first (Huffman codes)
function BW:bits_msb(val, n)
	for i = n - 1, 0, -1 do
		self:bit1(band(rshift(val, i), 1))
	end
end

function BW:align_to_byte()
	if self.nbits > 0 then
		self.bb:putb(band(self.buf, 255))
		self.buf, self.nbits = 0, 0
	end
end

function BW:finish()
	self:align_to_byte()
	return self.bb:result()
end

----------------------------------------------------------------------
-- SECTION: Huffman (shared by inflate & deflate)
----------------------------------------------------------------------

-- canonical-code lengths -> decode tree (puff.c style: counts/offsets)
local function make_tree(lengths, nsym)
	local counts, maxlen = {}, 0
	for i = 1, nsym do
		local l = lengths[i] or 0
		if l > 0 then
			counts[l] = (counts[l] or 0) + 1
			if l > maxlen then maxlen = l end
		end
	end
	local left = 1
	for len = 1, maxlen do
		left = left * 2 - (counts[len] or 0)
		if left < 0 then return fail("over-subscribed huffman tree") end
	end
	local offsets, sum = {}, 0
	for len = 1, maxlen do
		offsets[len] = sum
		sum = sum + (counts[len] or 0)
	end
	local symbols = {}
	for sym = 1, nsym do
		local l = lengths[sym] or 0
		if l > 0 then
			symbols[offsets[l] + 1] = sym - 1
			offsets[l] = offsets[l] + 1
		end
	end
	sum = 0
	for len = 1, maxlen do -- recompute (offsets were consumed)
		offsets[len] = sum
		sum = sum + (counts[len] or 0)
	end
	return {
		counts = counts,
		symbols = symbols,
		offsets = offsets,
		maxlen = maxlen,
		empty = (maxlen == 0)
	}
end

local function decode_symbol(br, tree)
	local code, first = 0, 0
	local counts, symbols, offsets = tree.counts, tree.symbols, tree.offsets
	for len = 1, tree.maxlen do
		code = code + BR_readbit(br)
		local count = counts[len] or 0
		if code - first < count then
			return symbols[offsets[len] + (code - first) + 1]
		end
		first = lshift(first + count, 1)
		code = lshift(code, 1)
	end
	return nil
end

-- frequency table -> code lengths (classic Huffman + zlib-style length limit)
local function huffman_lengths(freq, nsym, maxbits)
	local function sortasc(a, b) return freq[a] < freq[b] end
	local syms, m = {}, 0
	for s = 0, nsym - 1 do
		local f = freq[s]
		if f and f > 0 then
			m = m + 1; syms[m] = s
		end
	end
	if m == 0 then return {} end
	if m == 1 then return { [syms[1]] = 1 } end
	table_sort(syms, sortasc)
	-- two-queue Huffman
	local nodes = {}
	for i = 1, m do nodes[i] = { w = freq[syms[i]], s = syms[i] } end
	local h1, h2, t2 = 1, m + 1, m
	local function pop()
		local a, b = h1 <= m, h2 <= t2
		if a and b then
			if nodes[h1].w <= nodes[h2].w then
				h1 = h1 + 1; return nodes[h1 - 1]
			end
			h2 = h2 + 1; return nodes[h2 - 1]
		end
		if a then
			h1 = h1 + 1; return nodes[h1 - 1]
		end
		h2 = h2 + 1; return nodes[h2 - 1]
	end
	for _ = 1, m - 1 do
		local a, b = pop(), pop()
		t2 = t2 + 1
		nodes[t2] = { w = a.w + b.w, l = a, r = b }
	end
	-- depths (iterative walk - no deep recursion)
	local lens = {}
	local stack, top = { { nodes[t2], 0 } }, 1
	while top > 0 do
		local item = stack[top]; stack[top] = nil; top = top - 1
		local node, d = item[1], item[2]
		if node.s ~= nil then
			lens[node.s] = d
		else
			top = top + 1; stack[top] = { node.l, d + 1 }
			top = top + 1; stack[top] = { node.r, d + 1 }
		end
	end
	-- clamp over-long codes (zlib gen_bitlen adjustment)
	local overflow, bl_count = 0, {}
	for i = 1, m do
		local l = lens[syms[i]]
		if l > maxbits then
			l = maxbits; overflow = overflow + 1
		end
		bl_count[l] = (bl_count[l] or 0) + 1
	end
	while overflow > 0 do
		local b = maxbits - 1
		while b > 0 and (bl_count[b] or 0) == 0 do b = b - 1 end
		if b == 0 then return fail("huffman length overflow") end
		bl_count[b] = bl_count[b] - 1
		bl_count[b + 1] = (bl_count[b + 1] or 0) + 2
		bl_count[maxbits] = bl_count[maxbits] - 1
		overflow = overflow - 2
	end
	-- assign: longest codes to lowest frequencies
	local out, idx = {}, 1
	for b = maxbits, 1, -1 do
		for _ = 1, (bl_count[b] or 0) do
			out[syms[idx]] = b
			idx = idx + 1
		end
	end
	return out
end

-- lengths -> canonical codes
local function huffman_codes(lens, n)
	local bl_count, maxl = {}, 0
	for s = 0, n - 1 do
		local l = lens[s] or 0
		if l > 0 then
			bl_count[l] = (bl_count[l] or 0) + 1
			if l > maxl then maxl = l end
		end
	end
	local next_code, code = {}, 0
	for b = 1, maxl do
		code = (code + (bl_count[b - 1] or 0)) * 2
		next_code[b] = code
	end
	local codes = {}
	for s = 0, n - 1 do
		local l = lens[s] or 0
		if l > 0 then
			codes[s] = next_code[l]
			next_code[l] = next_code[l] + 1
		end
	end
	return codes
end

----------------------------------------------------------------------
-- SECTION: Inflate (DEFLATE decompressor, RFC 1951)
----------------------------------------------------------------------

local LEN_BASE = {
	3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258
}
local LEN_EXTRA = {
	0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0
}
local DIST_BASE = {
	1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145,
	8193, 12289, 16385, 24577
}
local DIST_EXTRA = {
	0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13
}

-- encoder lookup tables (built once)
local LENGTH_CODE, LENGTH_BASEOF, LENGTH_EXTRAOF = {}, {}, {}
for c = 1, 29 do
	local base, extra = LEN_BASE[c], LEN_EXTRA[c]
	local top = base
	if extra > 0 then top = base + lshift(1, extra) - 1 end
	for len = base, top do
		LENGTH_CODE[len]    = 256 + c
		LENGTH_BASEOF[len]  = base
		LENGTH_EXTRAOF[len] = extra
	end
end
local DIST_CODE, DIST_BASEOF, DIST_EXTRAOF = {}, {}, {}
for c = 1, 30 do
	local base, extra = DIST_BASE[c], DIST_EXTRA[c]
	local top = base
	if extra > 0 then top = base + lshift(1, extra) - 1 end
	for d = base, top do
		DIST_CODE[d]    = c - 1
		DIST_BASEOF[d]  = base
		DIST_EXTRAOF[d] = extra
	end
end

local FIXED_LLENS_1B, FIXED_LLEN, FIXED_DLENS_1B, FIXED_DLEN = {}, {}, {}, {}
for s = 0, 287 do
	local l
	if s <= 143 then
		l = 8
	elseif s <= 255 then
		l = 9
	elseif s <= 279 then
		l = 7
	else
		l = 8
	end
	FIXED_LLENS_1B[s + 1] = l
	FIXED_LLEN[s] = l
end
for s = 0, 29 do
	FIXED_DLENS_1B[s + 1] = 5; FIXED_DLEN[s] = 5
end
local FIXED_LTREE = make_tree(FIXED_LLENS_1B, 288)
local FIXED_DTREE = make_tree(FIXED_DLENS_1B, 30)

local CL_ORDER = { 16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15 }

local function out_write_str(bb, s, from, to)
	local t, n = bb.t, bb.n
	for i = from, to do
		n = n + 1
		t[n] = string_byte(s, i)
	end
	bb.n = n
end

local function out_copy(bb, dist, len) -- byte-wise: handles overlap
	local t, n = bb.t, bb.n
	for _ = 1, len do
		n = n + 1
		t[n] = t[n - dist]
	end
	bb.n = n
end

local function decode_block(br, out, lt, dt, limit)
	while true do
		local sym = decode_symbol(br, lt)
		if not sym then return fail("invalid literal/length code") end
		if sym < 256 then
			out:putb(sym)
			if limit and out.n > limit then return fail("deflate output exceeds limit") end
		elseif sym == 256 then
			return
		else
			local li = sym - 256
			if li > 29 then return fail("invalid length code") end
			local len = LEN_BASE[li]
			local ex = LEN_EXTRA[li]
			if ex > 0 then len = len + BR_read(br, ex) end
			local dsym = decode_symbol(br, dt)
			if not dsym or dsym > 29 then return fail("invalid distance code") end
			local dist = DIST_BASE[dsym + 1]
			local dex = DIST_EXTRA[dsym + 1]
			if dex > 0 then dist = dist + BR_read(br, dex) end
			if dist > out.n then return fail("invalid distance (copy before start)") end
			out_copy(out, dist, len)
			if limit and out.n > limit then return fail("deflate output exceeds limit") end
			out:maybe_flush()
		end
	end
end

local function read_dynamic_trees(br)
	local hlit  = BR_read(br, 5) + 257
	local hdist = BR_read(br, 5) + 1
	local hclen = BR_read(br, 4) + 4
	if hlit > 286 then return fail("invalid HLIT") end
	if hdist > 30 then return fail("invalid HDIST") end
	local cl_lens = {}
	for i = 1, hclen do cl_lens[CL_ORDER[i] + 1] = BR_read(br, 3) end
	local cl_tree = make_tree(cl_lens, 19)
	if cl_tree.empty then return fail("empty code-length tree") end
	local total = hlit + hdist
	local lengths, i = {}, 1
	while i <= total do
		local sym = decode_symbol(br, cl_tree)
		if not sym then return fail("invalid code-length symbol") end
		if sym < 16 then
			lengths[i] = sym; i = i + 1
		elseif sym == 16 then
			if i == 1 then return fail("repeat with no previous length") end
			local prev = lengths[i - 1]
			local rep = 3 + BR_read(br, 2)
			if i + rep - 1 > total then return fail("code-length repeat overruns") end
			for _ = 1, rep do
				lengths[i] = prev; i = i + 1
			end
		elseif sym == 17 then
			local rep = 3 + BR_read(br, 3)
			if i + rep - 1 > total then return fail("code-length repeat overruns") end
			for _ = 1, rep do
				lengths[i] = 0; i = i + 1
			end
		else
			local rep = 11 + BR_read(br, 7)
			if i + rep - 1 > total then return fail("code-length repeat overruns") end
			for _ = 1, rep do
				lengths[i] = 0; i = i + 1
			end
		end
	end
	local lit_lens, dist_lens = {}, {}
	for s = 1, hlit do lit_lens[s] = lengths[s] end
	for s = 1, hdist do dist_lens[s] = lengths[hlit + s] end
	if (lit_lens[257] or 0) == 0 then return fail("missing end-of-block code") end
	return make_tree(lit_lens, hlit), make_tree(dist_lens, hdist)
end

local function inflate_raw(s, first, last, limit)
	local br = BR.new(s, first, last)
	local out = ByteBuilder.new(33000) -- keep >32768-byte copy window live
	local function cap()
		if limit and out.n > limit then return fail("deflate output exceeds limit") end
	end
	while true do
		local bfinal = BR_readbit(br)
		local btype  = BR_read(br, 2)
		if btype == 0 then
			br:align_byte()
			local len  = br:byte_aligned() + 256 * br:byte_aligned()
			local nlen = br:byte_aligned() + 256 * br:byte_aligned()
			if nlen ~= band(bnot(len), 0xFFFF) then return fail("invalid stored block") end
			if br.p + len - 1 > br.stop then return fail("truncated stored block") end
			out_write_str(out, s, br.p, br.p + len - 1)
			br.p = br.p + len
			cap()
			out:maybe_flush()
		elseif btype == 1 then
			decode_block(br, out, FIXED_LTREE, FIXED_DTREE, limit)
		elseif btype == 2 then
			local lt, dt = read_dynamic_trees(br)
			decode_block(br, out, lt, dt, limit)
		else
			return fail("invalid deflate block type")
		end
		if bfinal == 1 then break end
	end
	return out:result()
end

local function zlib_inflate(data, check_adler, limit)
	if #data < 6 then return fail("zlib stream too short") end
	local cmf, flg = string_byte(data, 1), string_byte(data, 2)
	if band(cmf, 15) ~= 8 then return fail("unsupported zlib compression method") end
	if (cmf * 256 + flg) % 31 ~= 0 then return fail("bad zlib header checksum") end
	if band(flg, 32) ~= 0 then return fail("zlib preset dictionaries not supported") end
	local out = inflate_raw(data, 3, #data - 4, limit)
	if check_adler then
		if adler32(out) ~= u32be(data, #data - 3) then
			return fail("adler32 checksum mismatch")
		end
	end
	return out
end

----------------------------------------------------------------------
-- SECTION: Deflate (DEFLATE compressor, RFC 1951)
----------------------------------------------------------------------

local FIXED_LCODES = huffman_codes(FIXED_LLEN, 288)
local FIXED_DCODES = huffman_codes(FIXED_DLEN, 30)

local WINDOW, WIN_MASK, HASH_MASK, MIN_MATCH = 32768, 32767, 32767, 3
local BLOCK_TOKENS = 16384

-- zlib-style level configuration: good, max_lazy, nice, max_chain
local LEVELS = {
	[1] = { good = 4, lazy = 4, nice = 8, chain = 4 },
	[2] = { good = 4, lazy = 5, nice = 16, chain = 8 },
	[3] = { good = 4, lazy = 6, nice = 32, chain = 32 },
	[4] = { good = 4, lazy = 4, nice = 16, chain = 16 },
	[5] = { good = 8, lazy = 16, nice = 32, chain = 32 },
	[6] = { good = 8, lazy = 16, nice = 128, chain = 128 },
	[7] = { good = 8, lazy = 32, nice = 128, chain = 256 },
	[8] = { good = 32, lazy = 128, nice = 258, chain = 1024 },
	[9] = { good = 32, lazy = 258, nice = 258, chain = 4096 },
}

-- run-length encode code lengths for the dynamic block header
local function rle_code_lengths(getlen, n)
	local out, m, i = {}, 0, 0
	while i < n do
		local v = getlen(i) or 0
		local run = 1
		while i + run < n and run < 138 and (getlen(i + run) or 0) == v do
			run = run + 1
		end
		if v == 0 then
			local r = run
			while r > 0 do
				if r >= 11 then
					local c = math_min(r, 138)
					m = m + 1; out[m] = 18000 + c; r = r - c
				elseif r >= 3 then
					local c = math_min(r, 10)
					m = m + 1; out[m] = 17000 + c; r = r - c
				else
					m = m + 1; out[m] = 0; r = r - 1
				end
			end
		else
			m = m + 1; out[m] = v
			local r = run - 1
			while r > 0 do
				if r >= 3 then
					local c = math_min(r, 6)
					m = m + 1; out[m] = 16000 + c; r = r - c
				else
					m = m + 1; out[m] = v; r = r - 1
				end
			end
		end
		i = i + run
	end
	return out, m
end

local function prepare_dynamic(lf, df)
	local llens = huffman_lengths(lf, 286, 15)
	local dlens = huffman_lengths(df, 30, 15)
	-- strict decoders want >= 2 distance codes when any match exists
	local dn, dfirst = 0, nil
	for s = 0, 29 do
		if dlens[s] then
			dn = dn + 1; if not dfirst then dfirst = s end
		end
	end
	if dn == 0 then
		dlens[0] = 1
	elseif dn == 1 then
		dlens[band(bxor(dfirst, 1), 31)] = 1
	end
	local hlit = 286
	while hlit > 257 and not llens[hlit - 1] do hlit = hlit - 1 end
	local hdist = 30
	while hdist > 1 and not dlens[hdist - 1] do hdist = hdist - 1 end
	local total = hlit + hdist
	local function getlen(i)
		if i < hlit then return llens[i] or 0 end
		return dlens[i - hlit] or 0
	end
	local rle, nrle = rle_code_lengths(getlen, total)
	local cl_freq = {}
	for i = 1, nrle do
		local e = rle[i]
		local s = e < 16 and e or math_floor(e / 1000)
		cl_freq[s] = (cl_freq[s] or 0) + 1
	end
	local cl_lens = huffman_lengths(cl_freq, 19, 7)
	local hclen = 19
	while hclen > 4 and not cl_lens[CL_ORDER[hclen]] do hclen = hclen - 1 end
	local header_bits = 14 + 3 * hclen
	for i = 1, nrle do
		local e = rle[i]
		local s = e < 16 and e or math_floor(e / 1000)
		local b = cl_lens[s] or 0
		if s == 16 then
			b = b + 2
		elseif s == 17 then
			b = b + 3
		elseif s == 18 then
			b = b + 7
		end
		header_bits = header_bits + b
	end
	return {
		llens = llens,
		dlens = dlens,
		lcodes = huffman_codes(llens, 286),
		dcodes = huffman_codes(dlens, 30),
		cl_lens = cl_lens,
		cl_codes = huffman_codes(cl_lens, 19),
		hlit = hlit,
		hdist = hdist,
		hclen = hclen,
		rle = rle,
		nrle = nrle,
		header_bits = header_bits
	}
end

local function emit_tokens(bw, toks, dists, ntoks, lcodes, llens, dcodes, dlens)
	for i = 1, ntoks do
		local t = toks[i]
		if t <= 255 then
			bw:bits_msb(lcodes[t], llens[t])
		else
			local len = t - 256
			local lc = LENGTH_CODE[len]
			bw:bits_msb(lcodes[lc], llens[lc])
			local ex = LENGTH_EXTRAOF[len]
			if ex > 0 then bw:bits(len - LENGTH_BASEOF[len], ex) end
			local d = dists[i]
			local dc = DIST_CODE[d]
			bw:bits_msb(dcodes[dc], dlens[dc])
			local dex = DIST_EXTRAOF[d]
			if dex > 0 then bw:bits(d - DIST_BASEOF[d], dex) end
		end
	end
	bw:bits_msb(lcodes[256], llens[256])
end

local function emit_dynamic(bw, prep, toks, dists, ntoks)
	bw:bits(prep.hlit - 257, 5)
	bw:bits(prep.hdist - 1, 5)
	bw:bits(prep.hclen - 4, 4)
	for i = 1, prep.hclen do
		bw:bits(prep.cl_lens[CL_ORDER[i]] or 0, 3)
	end
	local cl_codes, cl_lens = prep.cl_codes, prep.cl_lens
	for i = 1, prep.nrle do
		local e = prep.rle[i]
		if e < 16 then
			bw:bits_msb(cl_codes[e], cl_lens[e])
		else
			local s = math_floor(e / 1000)
			local c = e - s * 1000
			bw:bits_msb(cl_codes[s], cl_lens[s])
			if s == 16 then
				bw:bits(c - 3, 2)
			elseif s == 17 then
				bw:bits(c - 3, 3)
			else
				bw:bits(c - 11, 7)
			end
		end
	end
	emit_tokens(bw, toks, dists, ntoks, prep.lcodes, prep.llens, prep.dcodes, prep.dlens)
end

local function dynamic_data_bits(toks, dists, ntoks, llens, dlens)
	local sum = llens[256]
	for i = 1, ntoks do
		local t = toks[i]
		if t <= 255 then
			sum = sum + llens[t]
		else
			local len = t - 256
			sum = sum + llens[LENGTH_CODE[len]] + LENGTH_EXTRAOF[len]
			sum = sum + (dlens[DIST_CODE[dists[i]]] or 0) + DIST_EXTRAOF[dists[i]]
		end
	end
	return sum
end

local function fixed_data_bits(toks, dists, ntoks)
	local sum = FIXED_LLEN[256]
	for i = 1, ntoks do
		local t = toks[i]
		if t <= 255 then
			sum = sum + FIXED_LLEN[t]
		else
			local len = t - 256
			sum = sum + FIXED_LLEN[LENGTH_CODE[len]] + LENGTH_EXTRAOF[len] + 5 + DIST_EXTRAOF[dists[i]]
		end
	end
	return sum
end

local function write_block(bw, toks, dists, ntoks, final)
	local fb = final and 1 or 0
	if ntoks == 0 then
		if final then
			bw:bits(1, 1); bw:bits(1, 2)
			bw:bits_msb(FIXED_LCODES[256], FIXED_LLEN[256])
		end
		return
	end
	local lf, df = {}, {}
	lf[256] = 1
	for i = 1, ntoks do
		local t = toks[i]
		if t <= 255 then
			lf[t] = (lf[t] or 0) + 1
		else
			local lc = LENGTH_CODE[t - 256]
			lf[lc] = (lf[lc] or 0) + 1
			local dc = DIST_CODE[dists[i]]
			df[dc] = (df[dc] or 0) + 1
		end
	end
	local prep = prepare_dynamic(lf, df)
	local dyn_bits = prep.header_bits
		+ dynamic_data_bits(toks, dists, ntoks, prep.llens, prep.dlens)
	if fixed_data_bits(toks, dists, ntoks) <= dyn_bits then
		bw:bits(fb, 1); bw:bits(1, 2)
		emit_tokens(bw, toks, dists, ntoks, FIXED_LCODES, FIXED_LLEN, FIXED_DCODES, FIXED_DLEN)
	else
		bw:bits(fb, 1); bw:bits(2, 2)
		emit_dynamic(bw, prep, toks, dists, ntoks)
	end
end

local function deflate_stored(src, bw)
	local n, pos = #src, 1
	while pos <= n do
		local len = math_min(n - pos + 1, 65535)
		local final = (pos + len - 1 >= n) and 1 or 0
		bw:bits(final, 1)
		bw:bits(0, 2)
		bw:align_to_byte()
		local nlen = 65535 - len
		bw.bb:putstr(
			string_char(band(len, 255), band(rshift(len, 8), 255), band(nlen, 255), band(rshift(nlen, 8), 255)) ..
			string_sub(src, pos, pos + len - 1)
		)
		pos = pos + len
	end
	if n == 0 then
		bw:bits(1, 1)
		bw:bits(1, 2)
		bw:bits_msb(FIXED_LCODES[256], FIXED_LLEN[256])
	end
end

-- LZ77 with hash chains + lazy matching (deflate_slow style)
local function deflate_lz(src, level, bw)
	local n = #src
	local P = LEVELS[level]
	local good_len, max_lazy, nice_len, max_chain = P.good, P.lazy, P.nice, P.chain
	if nice_len > 258 then nice_len = 258 end

	local head, prv = {}, {}
	local toks, dists, ntoks = {}, {}, 0
	local function flush_block_if_full()
		if ntoks >= BLOCK_TOKENS then
			write_block(bw, toks, dists, ntoks, false)
			toks, dists, ntoks = {}, {}, 0
		end
	end
	local function emit_lit(b)
		ntoks = ntoks + 1
		toks[ntoks] = b
		flush_block_if_full()
	end
	local function emit_match(len, dist)
		ntoks = ntoks + 1
		toks[ntoks] = 256 + len
		dists[ntoks] = dist
		flush_block_if_full()
	end
	local function hash3(p)
		return band(bxor(lshift(string_byte(src, p), 10),
			lshift(string_byte(src, p + 1), 5),
			string_byte(src, p + 2)), HASH_MASK)
	end
	local function update_hash(p)
		if p + 2 > n then return end
		local h = hash3(p)
		local old = head[h] or 0
		if old >= p then return end
		prv[band(p, WIN_MASK)] = old
		head[h] = p
	end
	local function find_match(pos, chain, min_len)
		local h = hash3(pos)
		local cand = head[h] or 0
		if cand == pos then
			cand = prv[band(pos, WIN_MASK)] or 0
		end
		local limit = pos - WINDOW
		local maxl = n - pos + 1
		if maxl > 258 then maxl = 258 end
		if maxl < min_len then return 0 end
		local best_len, best_pos, probe = min_len - 1, 0, min_len - 1
		while cand > limit and cand > 0 and chain > 0 do
			if string_byte(src, cand + probe) == string_byte(src, pos + probe)
				and string_byte(src, cand) == string_byte(src, pos) then
				local l = 1
				while l < maxl and string_byte(src, cand + l) == string_byte(src, pos + l) do
					l = l + 1
				end
				if l > best_len then
					best_len, best_pos, probe = l, cand, l
					if l >= nice_len then break end
				end
			end
			cand = prv[band(cand, WIN_MASK)] or 0
			chain = chain - 1
		end
		if best_pos == 0 then return 0 end
		return best_len, pos - best_pos
	end

	local plen, pdist = 0, 0
	local pos = 1
	while pos <= n do
		update_hash(pos)
		local mlen, mdist = 0, 0
		if pos + 2 <= n then
			local chain = max_chain
			if plen >= good_len then chain = rshift(chain, 2) end
			local need = MIN_MATCH
			if plen >= MIN_MATCH then
				need = (plen < max_lazy) and (plen + 1) or 0
			end
			if need > 0 then mlen, mdist = find_match(pos, chain, need) end
		end
		if plen >= MIN_MATCH then
			if mlen > plen then
				emit_lit(string_byte(src, pos - 1))
				if mlen >= nice_len then
					emit_match(mlen, mdist)
					local e = pos + mlen
					update_hash(e - 2); update_hash(e - 1)
					pos = e; plen = 0
				else
					plen, pdist = mlen, mdist
					pos = pos + 1
				end
			else
				emit_match(plen, pdist)
				local e = (pos - 1) + plen
				update_hash(e - 2); update_hash(e - 1)
				pos = e; plen = 0
			end
		else
			if mlen >= MIN_MATCH then
				if mlen >= nice_len then
					emit_match(mlen, mdist)
					local e = pos + mlen
					update_hash(e - 2); update_hash(e - 1)
					pos = e
				else
					plen, pdist = mlen, mdist
					pos = pos + 1
				end
			else
				emit_lit(string_byte(src, pos))
				pos = pos + 1
			end
		end
	end
	if plen >= MIN_MATCH then emit_match(plen, pdist) end
	write_block(bw, toks, dists, ntoks, true)
end

local function deflate_raw(src, level, bw)
	if level <= 0 then deflate_stored(src, bw) else deflate_lz(src, level, bw) end
end

local function zlib_deflate(src, level)
	level = level or 6
	local bw = BW.new()
	local flg
	if level <= 1 then
		flg = 0x01
	elseif level < 6 then
		flg = 0x5E
	elseif level == 6 then
		flg = 0x9C
	else
		flg = 0xDA
	end
	bw.bb:putstr(string_char(0x78, flg))
	deflate_raw(src, level, bw)
	return bw:finish() .. be32str(adler32(src))
end

----------------------------------------------------------------------
-- SECTION: PNG constants & filters
----------------------------------------------------------------------

local SIGNATURE    = "\137\080\078\071\013\010\026\010"
local CHANNELS     = { [0] = 1, [2] = 3, [3] = 1, [4] = 2, [6] = 4 }
local VALID_DEPTHS = {
	[0] = { [1] = true, [2] = true, [4] = true, [8] = true, [16] = true },
	[2] = { [8] = true, [16] = true },
	[3] = { [1] = true, [2] = true, [4] = true, [8] = true },
	[4] = { [8] = true, [16] = true },
	[6] = { [8] = true, [16] = true },
}
local ADAM7        = { { 0, 0, 8, 8 }, { 4, 0, 8, 8 }, { 0, 4, 4, 8 }, { 2, 0, 4, 4 },
	{ 0, 2, 2, 4 }, { 1, 0, 2, 2 }, { 0, 1, 1, 2 } }
local TEXT_LIMIT   = 8388608

local function paeth_predictor(a, b, c)
	local p = a + b - c
	local pa = p - a; if pa < 0 then pa = -pa end
	local pb = p - b; if pb < 0 then pb = -pb end
	local pc = p - c; if pc < 0 then pc = -pc end
	if pa <= pb and pa <= pc then
		return a
	elseif pb <= pc then
		return b
	else
		return c
	end
end

-- filter strategies (Open/Closed: add your own and use its numeric mode)
local FILTERS = {}
FILTERS[0] = function(cur, prev, bpp, len)
	local out = {}
	for i = 1, len do out[i] = cur[i] end
	return out
end
FILTERS[1] = function(cur, prev, bpp, len)
	local out = {}
	for i = 1, len do
		local a = i > bpp and cur[i - bpp] or 0
		out[i] = band(cur[i] - a, 255)
	end
	return out
end
FILTERS[2] = function(cur, prev, bpp, len)
	local out = {}
	for i = 1, len do out[i] = band(cur[i] - prev[i], 255) end
	return out
end
FILTERS[3] = function(cur, prev, bpp, len)
	local out = {}
	for i = 1, len do
		local a = i > bpp and cur[i - bpp] or 0
		out[i] = band(cur[i] - rshift(a + prev[i], 1), 255)
	end
	return out
end
FILTERS[4] = function(cur, prev, bpp, len)
	local out = {}
	for i = 1, len do
		local a = i > bpp and cur[i - bpp] or 0
		local b = prev[i]
		local c = i > bpp and prev[i - bpp] or 0
		out[i] = band(cur[i] - paeth_predictor(a, b, c), 255)
	end
	return out
end

-- adaptive: minimum absolute-sum heuristic across all 5 filters
local function filter_row(mode, packed, prev, bpp)
	local len = #packed
	local cur = str_to_bytes(packed)
	local prv = str_to_bytes(prev)
	if mode == 5 then
		local best, bestscore, bestf = nil, math_huge, 0
		for f = 0, 4 do
			local t = FILTERS[f](cur, prv, bpp, len)
			local score = 0
			for i = 1, len do
				local v = t[i]
				score = score + (v < 128 and v or 256 - v)
				if score >= bestscore then break end
			end
			if score < bestscore then best, bestscore, bestf = t, score, f end
		end
		return bestf, table_to_string(best, 1, len)
	end
	local t = FILTERS[mode](cur, prv, bpp, len)
	return mode, table_to_string(t, 1, len)
end

-- decoder-side reconstruction
local function unfilter_row(stream, sp, rowbytes, bpp, ftype, prev, cur)
	if ftype == 0 then
		for i = 1, rowbytes do cur[i] = string_byte(stream, sp + i - 1) end
	elseif ftype == 1 then
		for i = 1, rowbytes do
			local a = i > bpp and cur[i - bpp] or 0
			cur[i] = band(string_byte(stream, sp + i - 1) + a, 255)
		end
	elseif ftype == 2 then
		for i = 1, rowbytes do
			cur[i] = band(string_byte(stream, sp + i - 1) + prev[i], 255)
		end
	elseif ftype == 3 then
		for i = 1, rowbytes do
			local a = i > bpp and cur[i - bpp] or 0
			cur[i] = band(string_byte(stream, sp + i - 1) + rshift(a + prev[i], 1), 255)
		end
	elseif ftype == 4 then
		for i = 1, rowbytes do
			local a = i > bpp and cur[i - bpp] or 0
			local b = prev[i]
			local c = i > bpp and prev[i - bpp] or 0
			cur[i] = band(string_byte(stream, sp + i - 1) + paeth_predictor(a, b, c), 255)
		end
	else
		return fail("invalid PNG filter type %d", ftype)
	end
	return sp + rowbytes
end

----------------------------------------------------------------------
-- SECTION: scanline walking (linear + Adam7), sample expansion
----------------------------------------------------------------------

-- expand packed row bytes -> one byte per sample (16-bit keeps hi,lo bytes)
local function expand_samples(row, rowbytes, depth, nsamples, srow)
	if depth >= 8 then
		for i = 1, rowbytes do srow[i] = row[i] end
	else
		local mask = lshift(1, depth) - 1
		local o, left = 1, nsamples
		for i = 1, rowbytes do
			local v = row[i]
			local shift = 8 - depth
			while shift >= 0 and left > 0 do
				srow[o] = band(rshift(v, shift), mask)
				o = o + 1; left = left - 1; shift = shift - depth
			end
		end
	end
end

-- cb(srow, packed, x0, dx, row, y0, dy, pw, rowbytes)  - buffers are reused,
-- consume them inside the callback.
local function each_scanline(stream, w, h, ch, depth, interlace, cb)
	local sp, slen = 1, #stream
	local function check(need)
		if sp + need - 1 > slen then return fail("truncated scanline data") end
	end
	local bpp = math_max(1, math_floor((ch * depth + 7) / 8))
	if interlace == 0 then
		local rowbytes = math_floor((w * ch * depth + 7) / 8)
		local prev, cur, srow = {}, {}, {}
		for i = 1, rowbytes do prev[i] = 0 end
		for y = 0, h - 1 do
			check(1 + rowbytes)
			local ftype = string_byte(stream, sp); sp = sp + 1
			sp = unfilter_row(stream, sp, rowbytes, bpp, ftype, prev, cur)
			expand_samples(cur, rowbytes, depth, w * ch, srow)
			cb(srow, cur, 0, 1, y, 0, 1, w, rowbytes)
			prev, cur = cur, prev
		end
	else
		for p = 1, 7 do
			local pp = ADAM7[p]
			local x0, y0, dx, dy = pp[1], pp[2], pp[3], pp[4]
			if w > x0 and h > y0 then
				local pw = math_floor((w - x0 - 1) / dx) + 1
				local ph = math_floor((h - y0 - 1) / dy) + 1
				local rowbytes = math_floor((pw * ch * depth + 7) / 8)
				local prev, cur, srow = {}, {}, {}
				for i = 1, rowbytes do prev[i] = 0 end
				for j = 0, ph - 1 do
					check(1 + rowbytes)
					local ftype = string_byte(stream, sp); sp = sp + 1
					sp = unfilter_row(stream, sp, rowbytes, bpp, ftype, prev, cur)
					expand_samples(cur, rowbytes, depth, pw * ch, srow)
					cb(srow, cur, x0, dx, j, y0, dy, pw, rowbytes)
					prev, cur = cur, prev
				end
			end
		end
	end
end

----------------------------------------------------------------------
-- SECTION: pixel conversion (decoded samples -> RGBA8)
----------------------------------------------------------------------

local function make_rgba_converter(ct, depth, palette, trns)
	local bs = depth == 16 and 2 or 1
	if ct == 6 then
		local pstep = 4 * bs
		return function(srow, out, base, stride, npix)
			local o, s = base, 1
			for _ = 1, npix do
				out[o] = srow[s]; out[o + 1] = srow[s + bs]
				out[o + 2] = srow[s + 2 * bs]; out[o + 3] = srow[s + 3 * bs]
				o = o + stride; s = s + pstep
			end
		end
	elseif ct == 4 then
		local pstep = 2 * bs
		return function(srow, out, base, stride, npix)
			local o, s = base, 1
			for _ = 1, npix do
				local g = srow[s]
				out[o] = g; out[o + 1] = g; out[o + 2] = g; out[o + 3] = srow[s + bs]
				o = o + stride; s = s + pstep
			end
		end
	elseif ct == 2 then
		local tr, tg, tb = nil, nil, nil
		if trns and #trns >= 6 then
			tr = string_byte(trns, 1) * 256 + string_byte(trns, 2)
			tg = string_byte(trns, 3) * 256 + string_byte(trns, 4)
			tb = string_byte(trns, 5) * 256 + string_byte(trns, 6)
		end
		local pstep = 3 * bs
		return function(srow, out, base, stride, npix)
			local o, s = base, 1
			for _ = 1, npix do
				local r, g, b = srow[s], srow[s + bs], srow[s + 2 * bs]
				out[o] = r; out[o + 1] = g; out[o + 2] = b
				if tr then
					local rv, gv, bv = r, g, b
					if bs == 2 then
						rv = r * 256 + srow[s + 1]
						gv = g * 256 + srow[s + bs + 1]
						bv = b * 256 + srow[s + 2 * bs + 1]
					end
					out[o + 3] = (rv == tr and gv == tg and bv == tb) and 0 or 255
				else
					out[o + 3] = 255
				end
				o = o + stride; s = s + pstep
			end
		end
	elseif ct == 0 then
		local trg
		if trns and #trns >= 2 then
			trg = string_byte(trns, 1) * 256 + string_byte(trns, 2)
		end
		return function(srow, out, base, stride, npix)
			local o, s = base, 1
			for _ = 1, npix do
				local g = srow[s]
				out[o] = g; out[o + 1] = g; out[o + 2] = g
				if trg then
					local gv = g
					if bs == 2 then gv = g * 256 + srow[s + 1] end
					out[o + 3] = gv == trg and 0 or 255
				else
					out[o + 3] = 255
				end
				o = o + stride; s = s + bs
			end
		end
	else -- ct == 3 (indexed)
		local plen = #palette
		return function(srow, out, base, stride, npix)
			local o = base
			for i = 1, npix do
				local p = srow[i] * 3
				if p + 3 > plen then return fail("palette index out of range") end
				out[o]     = string_byte(palette, p + 1)
				out[o + 1] = string_byte(palette, p + 2)
				out[o + 2] = string_byte(palette, p + 3)
				out[o + 3] = trns and (string_byte(trns, srow[i] + 1) or 255) or 255
				o          = o + stride
			end
		end
	end
end

local function decode_to_rgba(st, stream)
	local conv = make_rgba_converter(st.colortype, st.bitdepth,
		st.palette, st.trns)
	local w, h = st.width, st.height
	if st.interlace == 0 then
		local parts, np, rout = {}, 0, {}
		each_scanline(stream, w, h, st.channels, st.bitdepth, 0,
			function(srow, packed, x0, dx, row, y0, dy, pw)
				conv(srow, rout, 1, 4, pw)
				np = np + 1
				parts[np] = table_to_string(rout, 1, pw * 4)
			end)
		return table_concat(parts)
	end
	local out = {}
	each_scanline(stream, w, h, st.channels, st.bitdepth, 1,
		function(srow, packed, x0, dx, row, y0, dy, pw)
			local y = y0 + row * dy
			local base = ((y * w + x0) * 4) + 1
			conv(srow, out, base, dx * 4, pw)
		end)
	return table_to_string(out, 1, w * h * 4)
end

local function decode_raw(st, stream)
	local w, h, ch, depth = st.width, st.height, st.channels, st.bitdepth
	if st.interlace == 0 then
		local rowbytes = math_floor((w * ch * depth + 7) / 8)
		local parts, np = {}, 0
		each_scanline(stream, w, h, ch, depth, 0,
			function(srow, packed, x0, dx, row, y0, dy, pw, rb)
				np = np + 1
				parts[np] = table_to_string(packed, 1, rb)
			end)
		return table_concat(parts), rowbytes
	end
	local bs = depth == 16 and 2 or 1
	local grid = {}
	each_scanline(stream, w, h, ch, depth, 1,
		function(srow, packed, x0, dx, row, y0, dy, pw)
			local y = y0 + row * dy
			local cps = ch * bs
			for i = 0, pw - 1 do
				local dst = ((y * w + x0 + i * dx) * ch) * bs + 1
				local src = i * cps + 1
				for k = 0, cps - 1 do grid[dst + k] = srow[src + k] end
			end
		end)
	return table_to_string(grid, 1, w * h * ch * bs), nil
end

----------------------------------------------------------------------
-- SECTION: chunk parsing (shared by decode/info - DRY)
----------------------------------------------------------------------

local function valid_chunk_type(t)
	for i = 1, 4 do
		local b = string_byte(t, i)
		if not ((b >= 65 and b <= 90) or (b >= 97 and b <= 122)) then
			return false
		end
	end
	return true
end

local function iterate_chunks(data, cb, check_crc)
	if #data < 8 or string_sub(data, 1, 8) ~= SIGNATURE then
		return fail("invalid PNG signature")
	end
	local pos, n = 9, #data
	while true do
		if pos + 8 > n then return fail("truncated chunk header") end
		local len = u32be(data, pos)
		local ctype = string_sub(data, pos + 4, pos + 7)
		if not valid_chunk_type(ctype) then return fail("invalid chunk type") end
		local dstart = pos + 8
		if dstart + len + 4 - 1 > n then return fail("truncated chunk '%s'", ctype) end
		local payload = string_sub(data, dstart, dstart + len - 1)
		if check_crc then
			local c = crc_update(0xFFFFFFFF, ctype, 1, 4)
			c = crc_update(c, payload, 1, len)
			if u32(bxor(c, 0xFFFFFFFF)) ~= u32be(data, dstart + len) then
				return fail("CRC mismatch in chunk '%s'", ctype)
			end
		end
		if cb(ctype, payload) then break end
		pos = dstart + len + 4
	end
end

local function validate_ihdr(st)
	if st.width < 1 or st.width > 0x7FFFFFFF
		or st.height < 1 or st.height > 0x7FFFFFFF then
		return fail("invalid image dimensions")
	end
	local depths = VALID_DEPTHS[st.colortype]
	if not depths then return fail("invalid color type %d", st.colortype) end
	if not depths[st.bitdepth] then
		return fail("invalid bit depth %d for color type %d", st.bitdepth, st.colortype)
	end
	if st.compression ~= 0 then return fail("unsupported compression method") end
	if st.filter_method ~= 0 then return fail("unsupported filter method") end
	if st.interlace ~= 0 and st.interlace ~= 1 then return fail("invalid interlace") end
end

local function add_text(st, keyword, text, lang, translated)
	local list = st.meta.texts
	list[#list + 1] = {
		keyword = keyword,
		text = text,
		lang = lang,
		translated = translated
	}
end

local function parse_bkgd(ct, p)
	if ct == 3 then return { index = string_byte(p, 1) } end
	if ct == 0 or ct == 4 then
		return { gray = string_byte(p, 1) * 256 + string_byte(p, 2) }
	end
	return {
		r = string_byte(p, 1) * 256 + string_byte(p, 2),
		g = string_byte(p, 3) * 256 + string_byte(p, 4),
		b = string_byte(p, 5) * 256 + string_byte(p, 6)
	}
end

local function collect_png(data, check_crc, check_adler)
	local st = {
		meta = { texts = {}, unknown_chunks = {} },
		idat_parts = {},
		idat_size = 0,
		got_ihdr = false,
		got_idat = false,
		got_iend = false,
		chunk_index = 0
	}
	iterate_chunks(data, function(ctype, payload)
		st.chunk_index = st.chunk_index + 1
		if st.chunk_index == 1 and ctype ~= "IHDR" then
			return fail("first chunk must be IHDR")
		end
		if st.got_iend then return fail("chunk found after IEND") end

		if ctype == "IHDR" then
			if st.got_ihdr then return fail("duplicate IHDR") end
			if #payload ~= 13 then return fail("bad IHDR length") end
			st.width         = u32be(payload, 1)
			st.height        = u32be(payload, 5)
			st.bitdepth      = string_byte(payload, 9)
			st.colortype     = string_byte(payload, 10)
			st.compression   = string_byte(payload, 11)
			st.filter_method = string_byte(payload, 12)
			st.interlace     = string_byte(payload, 13)
			validate_ihdr(st)
			st.channels = CHANNELS[st.colortype]
			st.got_ihdr = true
		elseif ctype == "PLTE" then
			if st.got_idat then return fail("PLTE after IDAT") end
			if #payload == 0 or #payload % 3 ~= 0 or #payload > 768 then
				return fail("bad PLTE chunk")
			end
			st.palette = payload
		elseif ctype == "tRNS" then
			if st.got_idat then return fail("tRNS after IDAT") end
			st.trns = payload
		elseif ctype == "IDAT" then
			st.idat_parts[#st.idat_parts + 1] = payload
			st.idat_size = st.idat_size + #payload
			st.got_idat = true
		elseif ctype == "IEND" then
			st.got_iend = true
			return true
		elseif ctype == "gAMA" then
			if #payload == 4 then st.meta.gamma = u32be(payload, 1) / 100000 end
		elseif ctype == "cHRM" then
			if #payload == 32 then
				local v = {}
				for i = 1, 8 do v[i] = u32be(payload, (i - 1) * 4 + 1) / 100000 end
				st.meta.chroma = {
					white = { v[1], v[2] },
					red = { v[3], v[4] },
					green = { v[5], v[6] },
					blue = { v[7], v[8] }
				}
			end
		elseif ctype == "sRGB" then
			st.meta.srgb = string_byte(payload, 1)
		elseif ctype == "bKGD" then
			if st.got_ihdr then
				local need = (st.colortype == 3 and 1)
					or (st.colortype == 0 or st.colortype == 4) and 2 or 6
				if #payload ~= need then return fail("invalid bKGD chunk length %d", #payload) end
				st.meta.background = parse_bkgd(st.colortype, payload)
			end
		elseif ctype == "pHYs" then
			if #payload == 9 then
				st.meta.phys = {
					x = u32be(payload, 1),
					y = u32be(payload, 5),
					unit = string_byte(payload, 9)
				}
			end
		elseif ctype == "tIME" then
			if #payload == 7 then
				st.meta.time = {
					year = string_byte(payload, 1) * 256 + string_byte(payload, 2),
					month = string_byte(payload, 3),
					day = string_byte(payload, 4),
					hour = string_byte(payload, 5),
					minute = string_byte(payload, 6),
					second = string_byte(payload, 7),
				}
			end
		elseif ctype == "tEXt" then
			local z = string_find(payload, "\000", 1, true)
			if not z then return fail("malformed tEXt") end
			add_text(st, string_sub(payload, 1, z - 1), string_sub(payload, z + 1))
		elseif ctype == "zTXt" then
			local z = string_find(payload, "\000", 1, true)
			if not z or z + 1 > #payload then return fail("malformed zTXt") end
			if string_byte(payload, z + 1) ~= 0 then
				return fail("unsupported zTXt compression method")
			end
			add_text(st, string_sub(payload, 1, z - 1),
				zlib_inflate(string_sub(payload, z + 2), check_adler, TEXT_LIMIT))
		elseif ctype == "iTXt" then
			local z1 = string_find(payload, "\000", 1, true)
			if not z1 then return fail("malformed iTXt") end
			local flag   = string_byte(payload, z1 + 1) or 0
			local method = string_byte(payload, z1 + 2) or 0
			local z2     = string_find(payload, "\000", z1 + 3, true)
			local z3     = z2 and string_find(payload, "\000", z2 + 1, true)
			if not z3 then return fail("malformed iTXt") end
			local text = string_sub(payload, z3 + 1)
			if flag == 1 then
				if method ~= 0 then return fail("unsupported iTXt compression method") end
				text = zlib_inflate(text, check_adler, TEXT_LIMIT)
			end
			add_text(st, string_sub(payload, 1, z1 - 1), text,
				string_sub(payload, z1 + 3, z2 - 1),
				string_sub(payload, z2 + 1, z3 - 1))
		else
			if band(string_byte(ctype, 1), 0x20) == 0 then
				return fail("unknown critical chunk '%s'", ctype)
			end
			local u = st.meta.unknown_chunks
			u[#u + 1] = { type = ctype, data = payload }
		end
	end, check_crc)
	if not st.got_ihdr then return fail("missing IHDR chunk") end
	if not st.got_idat then return fail("missing IDAT chunk") end
	if not st.got_iend then return fail("missing IEND chunk") end
	if st.colortype == 3 and not st.palette then return fail("missing PLTE chunk") end
	return st
end

----------------------------------------------------------------------
-- SECTION: decoder
----------------------------------------------------------------------

function M.decode(data, opts)
	opts = opts or {}
	if type(data) ~= "string" then return fail("decode expects a binary string") end
	local check_crc   = opts.check_crc ~= false
	local check_adler = opts.check_adler ~= false
	local st          = collect_png(data, check_crc, check_adler)
	local max_pixels  = opts.max_pixels or 16777216
	if st.width * st.height > max_pixels then
		return fail("image exceeds max_pixels (%d); raise opts.max_pixels", max_pixels)
	end
	local expected = 0
	if st.interlace == 0 then
		local rowbytes = math_floor((st.width * st.channels * st.bitdepth + 7) / 8)
		expected = st.height * (1 + rowbytes)
	else
		for p = 1, 7 do
			local pp = ADAM7[p]
			local x0, y0, dx, dy = pp[1], pp[2], pp[3], pp[4]
			if st.width > x0 and st.height > y0 then
				local pw = math_floor((st.width - x0 - 1) / dx) + 1
				local ph = math_floor((st.height - y0 - 1) / dy) + 1
				expected = expected + ph
					* (1 + math_floor((pw * st.channels * st.bitdepth + 7) / 8))
			end
		end
	end
	local stream = zlib_inflate(table_concat(st.idat_parts), check_adler, expected)
	local image = {
		width = st.width,
		height = st.height,
		colortype = st.colortype,
		bitdepth = st.bitdepth,
		interlace = st.interlace,
		channels = st.channels,
		palette = st.palette,
		transparent = st.trns,
		meta = st.meta,
	}
	if opts.raw then
		local d, rb = decode_raw(st, stream)
		image.data = d
		image.raw = true
		image.rowbytes = rb
		image.bytes_per_sample = st.bitdepth == 16 and 2 or 1
	else
		image.data = decode_to_rgba(st, stream)
		image.raw = false
	end
	return image
end

----------------------------------------------------------------------
-- SECTION: encoder
----------------------------------------------------------------------

M.FILTER = { NONE = 0, SUB = 1, UP = 2, AVERAGE = 3, PAETH = 4, ADAPTIVE = 5 }
local FILTER_NAMES = {
	none = 0,
	sub = 1,
	up = 2,
	average = 3,
	paeth = 4,
	adaptive = 5,
	auto = 5
}

local function resolve_filter(f)
	if f == nil then return 5 end
	if type(f) == "number" then
		local m = math_floor(f)
		if m < 0 or m > 5 then return fail("filter mode must be 0..5") end
		return m
	end
	local m = FILTER_NAMES[string_lower(tostring(f))]
	if not m then return fail("unknown filter name '%s'", tostring(f)) end
	return m
end

-- pack sample values into PNG row bytes (MSB-first bit packing)
local function pack_vals(vals, vn, depth)
	if depth >= 8 then return table_to_string(vals, 1, vn) end
	local mask = lshift(1, depth) - 1
	local out, on, acc, nbits = {}, 0, 0, 0
	for i = 1, vn do
		acc = bor(lshift(acc, depth), band(vals[i], mask))
		nbits = nbits + depth
		if nbits == 8 then
			on = on + 1; out[on] = acc
			acc, nbits = 0, 0
		end
	end
	if nbits > 0 then
		on = on + 1; out[on] = lshift(acc, 8 - nbits)
	end
	return table_to_string(out, 1, on)
end

local function build_scanlines(w, h, ch, depth, data, interlace, filter_mode)
	local bs = depth == 16 and 2 or 1
	local bpp = math_max(1, math_floor((ch * depth + 7) / 8))
	local parts, np, vals = {}, 0, {}
	local function emit(packed, prev)
		local ftype, filtered = filter_row(filter_mode, packed, prev, bpp)
		np = np + 1; parts[np] = string_char(ftype)
		np = np + 1; parts[np] = filtered
		return packed
	end
	if interlace == 0 then
		local rowbytes = math_floor((w * ch * depth + 7) / 8)
		local prev = string_rep("\000", rowbytes)
		local spr = w * ch
		for y = 0, h - 1 do
			local base = y * w * ch * bs
			local vn = 0
			for i = 1, spr do
				local off = base + (i - 1) * bs + 1
				vn = vn + 1; vals[vn] = string_byte(data, off)
				if bs == 2 then
					vn = vn + 1; vals[vn] = string_byte(data, off + 1)
				end
			end
			prev = emit(pack_vals(vals, vn, depth), prev)
		end
	else
		for p = 1, 7 do
			local pp = ADAM7[p]
			local x0, y0, dx, dy = pp[1], pp[2], pp[3], pp[4]
			if w > x0 and h > y0 then
				local pw = math_floor((w - x0 - 1) / dx) + 1
				local ph = math_floor((h - y0 - 1) / dy) + 1
				local rowbytes = math_floor((pw * ch * depth + 7) / 8)
				local prev = string_rep("\000", rowbytes)
				for j = 0, ph - 1 do
					local y = y0 + j * dy
					local vn = 0
					for i = 0, pw - 1 do
						local base = ((y * w + x0 + i * dx) * ch) * bs + 1
						for c = 0, ch - 1 do
							local off = base + c * bs
							vn = vn + 1; vals[vn] = string_byte(data, off)
							if bs == 2 then
								vn = vn + 1; vals[vn] = string_byte(data, off + 1)
							end
						end
					end
					prev = emit(pack_vals(vals, vn, depth), prev)
				end
			end
		end
	end
	return table_concat(parts)
end

local function chunk_str(ctype, payload)
	local c = crc_update(0xFFFFFFFF, ctype, 1, 4)
	c = crc_update(c, payload, 1, #payload)
	return be32str(#payload) .. ctype .. payload
		.. be32str(u32(bxor(c, 0xFFFFFFFF)))
end

local function trns_payload(ct, t)
	if type(t) == "string" then return t end
	if ct == 3 then
		local p = {}
		for i = 1, #t do p[i] = string_char(t[i]) end
		return table_concat(p)
	end
	if ct == 0 or ct == 4 then
		return string_char(rshift(t, 8), band(t, 255))
	end
	return string_char(rshift(t[1], 8), band(t[1], 255),
		rshift(t[2], 8), band(t[2], 255),
		rshift(t[3], 8), band(t[3], 255))
end

local function bkgd_payload(ct, t)
	if type(t) == "string" then return t end
	if ct == 3 then return string_char(t.index or t[1]) end
	if ct == 0 or ct == 4 then
		local g = t.gray or t[1]
		return string_char(rshift(g, 8), band(g, 255))
	end
	local r, g, b = t.r or t[1], t.g or t[2], t.b or t[3]
	return string_char(rshift(r, 8), band(r, 255),
		rshift(g, 8), band(g, 255),
		rshift(b, 8), band(b, 255))
end

function M.encode(image, opts)
	opts = opts or {}
	local w, h = image.width, image.height
	if type(w) ~= "number" or type(h) ~= "number"
		or w < 1 or h < 1 or w % 1 ~= 0 or h % 1 ~= 0 then
		return fail("image needs positive integer width/height")
	end
	local data = image.data
	if type(data) == "table" then data = table_to_string(data, 1, #data) end
	if type(data) ~= "string" then return fail("image.data must be a string or byte table") end

	local depth = opts.bitdepth or image.bitdepth or 8
	local ct = opts.colortype or image.colortype
	local palette = opts.palette or image.palette
	local bs = depth == 16 and 2 or 1
	if not ct then
		local per = #data / (w * h * bs)
		if palette then
			ct = 3
		elseif per == 4 then
			ct = 6
		elseif per == 3 then
			ct = 2
		elseif per == 2 then
			ct = 4
		elseif per == 1 then
			ct = 0
		else
			return fail("cannot infer color type; pass opts.colortype")
		end
	end
	local ch = CHANNELS[ct]
	if not ch then return fail("invalid color type") end
	local depths = VALID_DEPTHS[ct]
	if not depths or not depths[depth] then
		return fail("invalid bit depth %d for color type %d", depth, ct)
	end
	if #data ~= w * h * ch * bs then
		return fail("data size mismatch: expected %d bytes, got %d", w * h * ch * bs, #data)
	end
	if ct == 3 then
		if type(palette) ~= "string" or #palette == 0 or #palette % 3 ~= 0 then
			return fail("color type 3 requires opts.palette (RGB byte string)")
		end
		if #palette / 3 > 256 then return fail("palette too large") end
		if #palette / 3 > lshift(1, depth) then return fail("palette too large for bit depth") end
	end

	local interlace = opts.interlace and 1 or 0
	if type(opts.interlace) == "number" then interlace = opts.interlace end
	if interlace ~= 0 and interlace ~= 1 then return fail("interlace must be 0 or 1") end
	local level = math_floor(opts.level or 6)
	if level < 0 then level = 0 elseif level > 9 then level = 9 end

	local scanlines = build_scanlines(w, h, ch, depth, data, interlace,
		resolve_filter(opts.filter))
	local zdata = zlib_deflate(scanlines, level)

	local out, n = { SIGNATURE }, 1
	local function add(ctype, payload)
		n = n + 1
		out[n] = chunk_str(ctype, payload)
	end
	add("IHDR", be32str(w) .. be32str(h)
		.. string_char(depth, ct, 0, 0, interlace))
	if opts.gamma then add("gAMA", be32str(math_floor(opts.gamma * 100000 + 0.5))) end
	if opts.srgb then add("sRGB", string_char(opts.srgb)) end
	if opts.phys then
		add("pHYs", be32str(opts.phys.x or opts.phys[1])
			.. be32str(opts.phys.y or opts.phys[2])
			.. string_char(opts.phys.unit or 0))
	end
	if opts.time then
		add("tIME", string_char(rshift(opts.time.year, 8), band(opts.time.year, 255),
			opts.time.month, opts.time.day, opts.time.hour,
			opts.time.minute, opts.time.second))
	end
	if opts.texts then
		for i = 1, #opts.texts do
			local t = opts.texts[i]
			add("tEXt", t.keyword .. "\000" .. t.text)
		end
	end
	if ct == 3 then add("PLTE", palette) end
	if opts.transparent then add("tRNS", trns_payload(ct, opts.transparent)) end
	if opts.background then add("bKGD", bkgd_payload(ct, opts.background)) end

	local chunk_size = opts.idat_chunk_size or 65536
	local pos, zlen = 1, #zdata
	while pos <= zlen do
		local stop = math_min(pos + chunk_size - 1, zlen)
		add("IDAT", string_sub(zdata, pos, stop))
		pos = stop + 1
	end
	add("IEND", "")
	return table_concat(out)
end

----------------------------------------------------------------------
-- SECTION: metadata / helpers
----------------------------------------------------------------------

function M.info(data)
	local st = collect_png(data, false, false)
	return {
		width = st.width,
		height = st.height,
		colortype = st.colortype,
		bitdepth = st.bitdepth,
		interlace = st.interlace,
		channels = st.channels,
		has_palette = st.palette ~= nil,
		idat_size = st.idat_size,
		palette = st.palette,
		transparent = st.trns,
		meta = st.meta,
	}
end

function M.isPNG(data)
	return type(data) == "string" and #data >= 8
		and string_sub(data, 1, 8) == SIGNATURE
end

function M.getPixel(image, x, y)
	if image.raw then return fail("getPixel requires an RGBA image (no opts.raw)") end
	if x < 1 or x > image.width or y < 1 or y > image.height then
		return fail("pixel out of range")
	end
	local i = ((y - 1) * image.width + (x - 1)) * 4 + 1
	return string_byte(image.data, i, i + 3)
end

----------------------------------------------------------------------
-- SECTION: injectable file IO (Dependency Inversion - no io.open here!)
----------------------------------------------------------------------

local injected_io

-- io_impl = { read = function(path) return binaryString end,
--             write = function(path, binaryString) end }
function M.setIO(io_impl)
	if type(io_impl) ~= "table"
		or type(io_impl.read) ~= "function"
		or type(io_impl.write) ~= "function" then
		return fail("setIO expects { read = function(path)->string, write = function(path, data) }")
	end
	injected_io = io_impl
end

local function get_io()
	if not injected_io then
		return fail("no io handler injected - call png.setIO{ read = ..., write = ... }")
	end
	return injected_io
end

function M.load(path, opts)
	return M.decode(get_io().read(path), opts)
end

function M.save(path, image, opts)
	local bytes = M.encode(image, opts)
	get_io().write(path, bytes)
	return #bytes
end

----------------------------------------------------------------------
-- SECTION: selftest (roundtrip sanity)
----------------------------------------------------------------------

function M.selftest()
	local w, h = 19, 11
	local px = {}
	for y = 1, h do
		for x = 1, w do
			px[#px + 1] = string_char(
				band(x * 13, 255),
				band(y * 25, 255),
				band((x + y) * 7, 255),
				band(x * y, 255)
			)
		end
	end
	local rgba = table_concat(px)
	local img0 = { width = w, height = h, data = rgba }
	for filter = 0, 5 do
		for _, level in ipairs({ 0, 1, 5, 9 }) do
			local enc = M.encode(img0, { filter = filter, level = level })
			local dec = M.decode(enc)
			assert(dec.width == w and dec.height == h, "selftest: dimensions")
			assert(dec.data == rgba,
				string_format("selftest: RGBA roundtrip failed (filter=%d level=%d)", filter, level))
		end
	end
	local enc = M.encode(img0, { interlace = 1, filter = 2, level = 7 })
	local dec = M.decode(enc)
	assert(dec.data == rgba, "selftest: interlaced roundtrip failed")

	local palette = string_char(255, 0, 0, 0, 255, 0, 0, 0, 255, 255, 255, 0)
	local idx = {}
	for i = 1, 64 do idx[i] = string_char((i - 1) % 4) end
	enc = M.encode({ width = 8, height = 8, data = table_concat(idx) },
		{
			colortype = 3,
			bitdepth = 2,
			palette = palette,
			filter = 0,
			level = 6
		})
	dec = M.decode(enc)
	local r, g, b, a = M.getPixel(dec, 2, 1)
	assert(r == 0 and g == 255 and b == 0 and a == 255, "selftest: palette")
	local inf = M.info(enc)
	assert(inf.colortype == 3 and inf.bitdepth == 2, "selftest: info")
	return true
end

-- advanced/testing access to internals
M.internal = {
	crc32 = crc32,
	adler32 = adler32,
	inflate = zlib_inflate,
	deflate = zlib_deflate,
	paeth = paeth_predictor,
}

-- Deprecated aliases (naming standard: snake_case). Kept for compatibility.
M.is_png = M.isPNG
M.get_pixel = M.getPixel
M.set_io = M.setIO

--M.selftest()

-- Export
return M
