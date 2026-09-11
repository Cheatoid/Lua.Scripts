-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- GIF encoder/decoder library
--
-- QUICK API
-- gif.setIO{ read = function(path) -> string end,
--            write = function(path, data) end }        -- inject file IO
-- local img = gif.load("anim.gif")                     -- img.frames[i].data = palette indices
-- local img = gif.decode(binstring, { max_pixels = ... })
-- local bin = gif.encode({ width = w, height = h, data = rgb },
--                        { quantize = "median", loop = 0, local_palettes = false })
-- gif.save("out.gif", anim, opts)
-- gif.info(bin)                -- cheap header/frame parse (no LZW decode)
-- gif.render(img, n)           -- composite frames 1..n -> RGBA8 canvas string
-- gif.frame(img, i)            -- one frame -> { width, height, data = RGB }
-- gif.getPixel(image, x, y)    -- 1-based; RGB -> r,g,b | RGBA -> r,g,b,a
-- gif.selftest()               -- roundtrip sanity checks
--
-- Decode opts: { max_pixels=16777216 }
-- Encode opts: { quantize="median"|"uniform", palette=, local_palettes=,
--                loop=, background=, interlace=, comments= }
--
-- Encode input: { width, height, background=, loop=, frames = { frame... } }
--   A bare image table (with .data) is auto-wrapped as a single frame.
--   frame = { data = RGB | RGBA | indexed byte string (or byte table),
--             width=, height=, left=, top=, delay= (1/100s), disposal=0..3,
--             interlace=, user_input=,
--             transparent = index | {r,g,b} | "rgb",  palette = "RGB..." }
--   data size selects the mode: w*h*4 = RGBA, w*h*3 = RGB, w*h = indexed.

-- Localized global functions for better performance
local assert                = assert
local error                 = error
local ipairs                = ipairs
local pairs                 = pairs
local setmetatable          = setmetatable
local tostring              = tostring
local type                  = type
local math_abs              = math.abs
local math_floor            = math.floor
local math_huge             = math.huge
local math_max              = math.max
local math_min              = math.min
local string_byte           = string.byte
local string_char           = string.char
local string_format         = string.format
local string_rep            = string.rep
local string_sub            = string.sub
local table_concat          = table.concat
local table_sort            = table.sort
local table_unpack          = table.unpack or unpack

-- Import dependencies
local bits                  = require "bits"
local band, bor, bnot, bxor = bits.band, bits.bor, bits.bnot, bits.bxor
local lshift, rshift        = bits.lshift, bits.rshift

-- Some bit backends (native Lua 5.3+ ops) accept only 2 operands per call;
-- fold multi-arg ORs so the encoder works identically everywhere.
local raw_bor               = bor
bor                         = function(a, b, ...)
	local r = raw_bor(a, b)
	for i = 1, select("#", ...) do
		r = raw_bor(r, select(i, ...))
	end
	return r
end

local M                     = {}

local function fail(fmt, ...)
	return error(string_format("[gif] " .. fmt, ...), 2)
end

----------------------------------------------------------------------
-- SECTION: small utilities
----------------------------------------------------------------------

local function le16(s, pos)
	return string_byte(s, pos) + string_byte(s, pos + 1) * 256
end

local function le16str(v)
	return string_char(band(v, 255), band(rshift(v, 8), 255))
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

local function rgb_key(r, g, b)
	return r * 65536 + g * 256 + b
end

local function key_rgb(k)
	return math_floor(k / 65536), math_floor(k / 256) % 256, k % 256
end

----------------------------------------------------------------------
-- SECTION: BitReader (LSB-first, GIF bit packing order)
----------------------------------------------------------------------

local BR = {}
BR.__index = BR

function BR.new(s)
	return setmetatable({ s = s, p = 1, stop = #s, buf = 0, n = 0 }, BR)
end

function BR:read(nbits)
	local buf, n, s, p = self.buf, self.n, self.s, self.p
	while n < nbits do
		if p > self.stop then return fail("unexpected end of LZW stream") end
		buf = bor(buf, lshift(string_byte(s, p), n))
		p = p + 1
		n = n + 8
	end
	local v = band(buf, lshift(1, nbits) - 1)
	self.buf, self.n, self.p = rshift(buf, nbits), n - nbits, p
	return v
end

----------------------------------------------------------------------
-- SECTION: BitWriter (LSB-first)
----------------------------------------------------------------------

local BW = {}
BW.__index = BW

function BW.new()
	return setmetatable({ buf = 0, n = 0, parts = {}, np = 0 }, BW)
end

function BW:code(val, nbits)
	local buf = bor(self.buf, lshift(val, self.n))
	local n = self.n + nbits
	local parts, np = self.parts, self.np
	while n >= 8 do
		np = np + 1
		parts[np] = string_char(band(buf, 255))
		buf = rshift(buf, 8)
		n = n - 8
	end
	self.buf, self.n, self.np = buf, n, np
end

function BW:finish()
	if self.n > 0 then
		self.np = self.np + 1
		self.parts[self.np] = string_char(band(self.buf, 255))
		self.buf, self.n = 0, 0
	end
	return table_concat(self.parts)
end

----------------------------------------------------------------------
-- SECTION: GIF sub-blocks (DRY: shared by extensions and image data)
----------------------------------------------------------------------

local function read_subblocks(data, pos)
	local parts, np, n = {}, 0, #data
	while true do
		if pos > n then return fail("truncated sub-block stream") end
		local sz = string_byte(data, pos)
		pos = pos + 1
		if sz == 0 then break end
		if pos + sz - 1 > n then return fail("truncated sub-block") end
		np = np + 1
		parts[np] = string_sub(data, pos, pos + sz - 1)
		pos = pos + sz
	end
	return table_concat(parts), pos
end

local function skip_subblocks(data, pos)
	local total, n = 0, #data
	while true do
		if pos > n then return fail("truncated sub-block stream") end
		local sz = string_byte(data, pos)
		pos = pos + 1
		if sz == 0 then return pos, total end
		if pos + sz - 1 > n then return fail("truncated sub-block") end
		pos = pos + sz
		total = total + sz
	end
end

local function wrap_subblocks(data)
	local parts, np, pos, n = {}, 0, 1, #data
	while pos <= n do
		local stop = math_min(pos + 254, n)
		np = np + 1
		parts[np] = string_char(stop - pos + 1)
		np = np + 1
		parts[np] = string_sub(data, pos, stop)
		pos = stop + 1
	end
	np = np + 1
	parts[np] = "\000"
	return table_concat(parts)
end

----------------------------------------------------------------------
-- SECTION: LZW decoder (GIF variant of RFC-style LZW, 12-bit dictionary)
----------------------------------------------------------------------

local LZW_MAXCODES = 4096

local function lzw_decode(minbits, stream, expected)
	local clear = lshift(1, minbits)
	local eoi = clear + 1
	local prefix, suffix, firstb, len = {}, {}, {}, {}
	for c = 0, clear - 1 do
		firstb[c] = c
		len[c] = 1
	end
	local br = BR.new(stream)
	local out, outn = {}, 0
	local cs = minbits + 1
	local nextc = clear + 2
	local prev = -1

	local function emit(code)
		local n = outn + len[code]
		local p = n
		local c = code
		while c >= clear do
			out[p] = suffix[c]
			p = p - 1
			c = prefix[c]
		end
		out[p] = c
		outn = n
	end

	local function add(p, b)
		if nextc >= LZW_MAXCODES then return end
		prefix[nextc] = p
		suffix[nextc] = b
		firstb[nextc] = firstb[p]
		len[nextc] = len[p] + 1
		nextc = nextc + 1
		if nextc == lshift(1, cs) and cs < 12 then cs = cs + 1 end
	end

	while true do
		local code = br:read(cs)
		if code == eoi then
			break
		elseif code == clear then
			cs = minbits + 1
			nextc = clear + 2
			prev = -1
		elseif prev < 0 then
			if code >= clear then return fail("invalid first LZW code after CLEAR") end
			outn = outn + 1
			out[outn] = code
			prev = code
		elseif code < nextc then
			emit(code)
			add(prev, firstb[code])
			prev = code
		elseif code == nextc then
			-- special KwKwK case: entry = prev + first(prev)
			local b = firstb[prev]
			local n = outn + len[prev] + 1
			local p = n
			out[p] = b
			p = p - 1
			local c = prev
			while c >= clear do
				out[p] = suffix[c]
				p = p - 1
				c = prefix[c]
			end
			out[p] = c
			outn = n
			add(prev, b)
			prev = code
		else
			return fail("invalid LZW code %d (next free = %d)", code, nextc)
		end
	end

	if expected then
		if outn < expected then
			return fail("LZW output too short (%d < %d)", outn, expected)
		end
		if outn > expected then outn = expected end -- tolerate trailing junk
	end
	return table_to_string(out, 1, outn)
end

----------------------------------------------------------------------
-- SECTION: LZW encoder (open-addressing hash + lazy dictionary resets)
----------------------------------------------------------------------

local HT_SIZE = 16384
local HT_MASK = HT_SIZE - 1
local HASH_MUL = 2654435761 -- Knuth multiplicative hash

local function lzw_encode(idx, minbits)
	local bw = BW.new()
	local clear = lshift(1, minbits)
	local eoi = clear + 1
	local hkey, hcode, hgen = {}, {}, {}
	local gen, nextc, cs = 0, 0, 0

	local function reset()
		gen = gen + 1 -- lazy table clear via generation stamp
		nextc = clear + 2
		cs = minbits + 1
	end

	local function probe(k)
		local h = band(k * HASH_MUL, HT_MASK)
		while true do
			if hgen[h] ~= gen or hkey[h] == k then return h end
			h = band(h + 1, HT_MASK)
		end
	end

	reset()
	bw:code(clear, cs)
	local n = #idx
	if n == 0 then
		bw:code(eoi, cs)
		return bw:finish()
	end
	local prefix = string_byte(idx, 1)
	for i = 2, n do
		local b = string_byte(idx, i)
		local h = probe(prefix * 256 + b)
		if hgen[h] == gen then
			prefix = hcode[h]
		else
			bw:code(prefix, cs)
			if nextc < LZW_MAXCODES then
				hgen[h] = gen
				hkey[h] = prefix * 256 + b
				hcode[h] = nextc
				nextc = nextc + 1
				-- the decoder adds its entries one code late for the first literal,
				-- so the code-size bump must track nextc - 1 to stay bit-synchronized
				if nextc - 1 == lshift(1, cs) and cs < 12 then cs = cs + 1 end
			else
				bw:code(clear, cs)
				reset()
			end
			prefix = b
		end
	end
	bw:code(prefix, cs)
	-- decoder adds an entry for the final code too, so it may bump cs for EOI;
	-- nextc is in sync with the decoder here (encoder stopped mid-stream).
	if nextc == lshift(1, cs) and cs < 12 then cs = cs + 1 end
	bw:code(eoi, cs)
	return bw:finish()
end

----------------------------------------------------------------------
-- SECTION: palette utilities & quantization
----------------------------------------------------------------------

local QUANT_SAMPLE = 131072 -- max pixels sampled per quantization
local QUANT_UNIQUE = 16384  -- max distinct colors tracked
local QUANT_CACHE  = 65536  -- rgb -> index memo cap

local function palette_bits_for(count)
	local b, entries = 1, 2
	while entries < count do
		entries = entries * 2
		b = b + 1
	end
	if b > 8 then return nil end
	return b, entries
end

local function pad_palette(pal, entries)
	local need = entries * 3
	if #pal >= need then return string_sub(pal, 1, need) end
	return pal .. string_rep("\000", need - #pal)
end

local function chunk_palette(pal)
	local entries, n = {}, 0
	for p = 1, #pal - 2, 3 do
		n = n + 1
		entries[n] = string_sub(pal, p, p + 2)
	end
	return entries, n
end

-- sources: { { data = rgbString, pixels = n, alpha = alphaStringOrNil } }
local function collect_freq(sources)
	local freq, uniq = {}, 0
	for s = 1, #sources do
		local src = sources[s]
		local data, alpha, n = src.data, src.alpha, src.pixels
		-- Full scan until the palette is provably >256 colors; only then start
		-- sampling. A fixed step from pixel 1 aliases periodic patterns and can
		-- silently drop colors, so we keep step=1 while we can still be exact.
		local step = 1
		local i = 1
		while i <= n do
			if not alpha or string_byte(alpha, i) >= 128 then
				local off = i * 3 - 2
				local k = rgb_key(string_byte(data, off, off + 2))
				local c = freq[k]
				if c then
					freq[k] = c + 1
				elseif uniq < QUANT_UNIQUE then
					uniq = uniq + 1
					freq[k] = 1
					if uniq >= 256 and step == 1 then
						-- cannot be exact anymore; sample the rest cheaply
						step = math_max(1, math_floor(n / QUANT_SAMPLE))
					end
				end
			end
			i = i + step
		end
	end
	return freq, uniq
end

-- channel comparators built once (DRY across all slice sorts)
local CH_COMP = {
	function(a, b) return a[1] < b[1] end,
	function(a, b) return a[2] < b[2] end,
	function(a, b) return a[3] < b[3] end,
}

local function sort_range(arr, lo, hi, ch)
	local tmp, m = {}, 0
	for i = lo, hi do
		m = m + 1
		tmp[m] = arr[i]
	end
	table_sort(tmp, CH_COMP[ch])
	for i = lo, hi do
		arr[i] = tmp[i - lo + 1]
	end
end

local function box_span(items, lo, hi)
	local rmin, rmax = 255, 0
	local gmin, gmax = 255, 0
	local bmin, bmax = 255, 0
	for j = lo, hi do
		local e = items[j]
		if e[1] < rmin then rmin = e[1] end
		if e[1] > rmax then rmax = e[1] end
		if e[2] < gmin then gmin = e[2] end
		if e[2] > gmax then gmax = e[2] end
		if e[3] < bmin then bmin = e[3] end
		if e[3] > bmax then bmax = e[3] end
	end
	local dr, dg, db = rmax - rmin, gmax - gmin, bmax - bmin
	local ch, range = 1, dr
	if dg > range then ch, range = 2, dg end
	if db > range then ch, range = 3, db end
	return ch, range
end

-- Median-cut quantizer: returns entries (3-char strings), count, memo cache
local function quantize_median(freq, max_boxes)
	max_boxes = max_boxes or 256
	local items, n, total = {}, 0, 0
	for k, c in pairs(freq) do
		local r, g, b = key_rgb(k)
		n = n + 1
		items[n] = { r, g, b, c, k }
		total = total + c
	end

	-- exact palette fast path (lossless)
	if n <= max_boxes then
		local entries, cache = {}, {}
		for i = 1, n do
			local e = items[i]
			entries[i] = string_char(e[1], e[2], e[3])
			cache[e[5]] = i - 1
		end
		return entries, n, cache
	end

	local ch0, range0 = box_span(items, 1, n)
	local boxes = { { lo = 1, hi = n, count = total, ch = ch0, range = range0 } }
	while #boxes < max_boxes do
		-- pick splittable box holding the most pixels
		local bi, best = nil, -1
		for i = 1, #boxes do
			local b = boxes[i]
			if b.range > 0 and b.count > best then
				bi, best = i, b.count
			end
		end
		if not bi then break end
		local b = boxes[bi]
		sort_range(items, b.lo, b.hi, b.ch)
		local half, acc, m = b.count / 2, 0, b.hi - 1
		for j = b.lo, b.hi - 1 do
			acc = acc + items[j][4]
			if acc >= half then
				m = j
				break
			end
		end
		local cnt1 = 0
		for j = b.lo, m do cnt1 = cnt1 + items[j][4] end
		local ch1, r1 = box_span(items, b.lo, m)
		local ch2, r2 = box_span(items, m + 1, b.hi)
		boxes[bi] = { lo = b.lo, hi = m, count = cnt1, ch = ch1, range = r1 }
		boxes[#boxes + 1] = { lo = m + 1, hi = b.hi, count = b.count - cnt1, ch = ch2, range = r2 }
	end

	local entries, cache = {}, {}
	for i = 1, #boxes do
		local b = boxes[i]
		local sr, sg, sb, sc = 0, 0, 0, 0
		for j = b.lo, b.hi do
			local e = items[j]
			sr = sr + e[1] * e[4]
			sg = sg + e[2] * e[4]
			sb = sb + e[3] * e[4]
			sc = sc + e[4]
			cache[e[5]] = i - 1
		end
		entries[i] = string_char(
			math_floor(sr / sc + 0.5),
			math_floor(sg / sc + 0.5),
			math_floor(sb / sc + 0.5)
		)
	end
	return entries, #boxes, cache
end

-- Naive uniform 3-3-2 binning quantizer (fast, O(1) mapping)
local function quantize_uniform(freq)
	local sums = {}
	for k, c in pairs(freq) do
		local r, g, b = key_rgb(k)
		local bin = bor(lshift(rshift(r, 5), 5), lshift(rshift(g, 5), 2), rshift(b, 6))
		local s = sums[bin]
		if not s then
			s = { 0, 0, 0, 0 }
			sums[bin] = s
		end
		s[1] = s[1] + r * c
		s[2] = s[2] + g * c
		s[3] = s[3] + b * c
		s[4] = s[4] + c
	end
	local function entry_for(bin)
		local s = sums[bin]
		return s and string_char(
			math_floor(s[1] / s[4] + 0.5),
			math_floor(s[2] / s[4] + 0.5),
			math_floor(s[3] / s[4] + 0.5)
		) or string_char(
			bor(lshift(rshift(bin, 5), 5), 16),
			bor(lshift(band(rshift(bin, 2), 7), 5), 16),
			bor(lshift(band(bin, 3), 6), 32)
		)
	end
	local entries = {}
	for bin = 0, 255 do
		entries[bin + 1] = entry_for(bin)
	end
	return entries, 256, nil
end

-- deterministic default palette entry for an empty uniform bin
local function quantize_uniform_entry(bin)
	return string_char(
		bor(lshift(rshift(bin, 5), 5), 16),
		bor(lshift(band(rshift(bin, 2), 7), 5), 16),
		bor(lshift(band(bin, 3), 6), 32)
	)
end

local function nearest_index(entries, n, r, g, b, exclude)
	local best, bestd = 0, math_huge
	for i = 1, n do
		if i - 1 ~= exclude then
			local e = entries[i]
			local dr = string_byte(e, 1) - r
			local dg = string_byte(e, 2) - g
			local db = string_byte(e, 3) - b
			local d = 2 * dr * dr + 4 * dg * dg + 3 * db * db
			if d < bestd then
				bestd, best = d, i - 1
			end
		end
	end
	return best
end

local function make_mapper(entries, n, cache, exclude)
	local memo = cache or {}
	local cnt = 0
	return function(r, g, b)
		local k = rgb_key(r, g, b)
		local v = memo[k]
		if v and v ~= exclude then return v end
		v = nearest_index(entries, n, r, g, b, exclude)
		if cnt < QUANT_CACHE then
			memo[k] = v
			cnt = cnt + 1
		end
		return v
	end
end

local function uniform_map(r, g, b)
	return bor(lshift(rshift(r, 5), 5), lshift(rshift(g, 5), 2), rshift(b, 6))
end

-- Strategy dispatch (Open/Closed: register your own quantizer here)
local QUANTIZERS = {}

QUANTIZERS.median = function(freq, max_boxes)
	local entries, n, cache = quantize_median(freq, max_boxes)
	return entries, n, make_mapper(entries, n, cache, nil)
end

QUANTIZERS.uniform = function(freq, max_boxes)
	max_boxes = max_boxes or 256
	local entries, n = quantize_uniform(freq)
	if max_boxes < 256 then
		-- drop the top bins; the mapping clamps into the kept range
		entries, n = {}, max_boxes
		for i = 1, max_boxes do entries[i] = quantize_uniform_entry(i - 1) end
		return entries, n, function(r, g, b)
			local bin = uniform_map(r, g, b)
			return bin < max_boxes and bin or (max_boxes - 1)
		end
	end
	return entries, n, uniform_map
end

local function quantize(sources, method, max_boxes)
	local freq, uniq = collect_freq(sources)
	if uniq == 0 then
		-- fully-transparent input: dummy 1-color palette
		local e = { "\000\000\000" }
		return e, 1, function() return 0 end
	end
	local q = QUANTIZERS[method or "median"]
	if not q then return fail("unknown quantizer '%s'", tostring(method)) end
	return q(freq, max_boxes)
end

local function reserve_slot(entries, n)
	if n >= 256 then return nil end
	entries[n + 1] = "\000\000\000"
	return n -- 0-based index of reserved slot
end

----------------------------------------------------------------------
-- SECTION: interlacing (shared by encoder + decoder)
----------------------------------------------------------------------

local INTERLACE_PASSES = { { 0, 8 }, { 4, 8 }, { 2, 4 }, { 1, 2 } }

local function deinterlace(idx, w, h)
	if #idx < w * h then return fail("truncated interlaced data") end
	local rows = {}
	local src = 1
	for p = 1, 4 do
		local start, step = INTERLACE_PASSES[p][1], INTERLACE_PASSES[p][2]
		local y = start
		while y < h do
			rows[y + 1] = string_sub(idx, src, src + w - 1)
			src = src + w
			y = y + step
		end
	end
	return table_concat(rows)
end

local function interlace_indices(idx, w, h)
	local parts, np = {}, 0
	for p = 1, 4 do
		local start, step = INTERLACE_PASSES[p][1], INTERLACE_PASSES[p][2]
		local y = start
		while y < h do
			np = np + 1
			parts[np] = string_sub(idx, y * w + 1, (y + 1) * w)
			y = y + step
		end
	end
	return table_concat(parts)
end

----------------------------------------------------------------------
-- SECTION: decoder (header, screen descriptor, tables, extensions, LZW)
----------------------------------------------------------------------

local function parse_gif(data, want_pixels, max_pixels)
	if #data < 13 or string_sub(data, 1, 3) ~= "GIF" then
		return fail("invalid GIF signature")
	end
	local version = string_sub(data, 4, 6)
	if version ~= "87a" and version ~= "89a" then
		return fail("unsupported GIF version '%s'", version)
	end
	local width, height = le16(data, 7), le16(data, 9)
	if width < 1 or height < 1 then return fail("invalid image dimensions") end
	if width * height > max_pixels then
		return fail("image exceeds max_pixels (%d); raise opts.max_pixels", max_pixels)
	end
	local packed = string_byte(data, 11)
	local n = #data
	local pos = 14
	local gct
	if band(packed, 0x80) ~= 0 then
		local cnt = lshift(1, band(packed, 7) + 1)
		if pos + 3 * cnt - 1 > n then return fail("truncated global color table") end
		gct = string_sub(data, pos, pos + 3 * cnt - 1)
		pos = pos + 3 * cnt
	end

	local g = {
		width = width,
		height = height,
		version = version,
		background = string_byte(data, 12),
		aspect = string_byte(data, 13),
		has_global_palette = gct ~= nil,
		global_palette = gct,
		loop = nil,
		data_size = 0,
		frames = {},
		meta = { comments = {}, apps = {}, texts = {}, unknown = {} },
	}
	local pending -- GCE awaiting its image

	while pos <= n do
		local b = string_byte(data, pos)
		pos = pos + 1
		if b == 0x3B then
			break
		elseif b == 0x2C then
			-- image descriptor
			if pos + 8 > n then return fail("truncated image descriptor") end
			local left, top = le16(data, pos), le16(data, pos + 2)
			local fw, fh = le16(data, pos + 4), le16(data, pos + 6)
			local fp = string_byte(data, pos + 8)
			pos = pos + 9
			if fw < 1 or fh < 1 then return fail("invalid frame dimensions") end
			if fw * fh > max_pixels then
				return fail("frame exceeds max_pixels (%d)", max_pixels)
			end
			if left + fw > width or top + fh > height then
				return fail("frame exceeds logical screen")
			end
			local lct
			if band(fp, 0x80) ~= 0 then
				local cnt = lshift(1, band(fp, 7) + 1)
				if pos + 3 * cnt - 1 > n then return fail("truncated local color table") end
				lct = string_sub(data, pos, pos + 3 * cnt - 1)
				pos = pos + 3 * cnt
			end
			if pos > n then return fail("missing LZW minimum code size") end
			local minbits = string_byte(data, pos)
			pos = pos + 1
			if minbits < 2 or minbits > 8 then return fail("invalid LZW minimum code size %d", minbits) end
			local f = {
				left = left,
				top = top,
				width = fw,
				height = fh,
				interlaced = band(fp, 0x40) ~= 0,
				has_local_palette = lct ~= nil,
				palette = lct or gct,
				delay = 0,
				disposal = 0,
				user_input = false,
				transparent = nil,
			}
			if not f.palette then return fail("frame %d has no color table", #g.frames + 1) end
			if pending then
				f.delay, f.disposal, f.user_input, f.transparent =
					pending.delay, pending.disposal, pending.user_input, pending.trans
				pending = nil
			end
			if want_pixels then
				local payload
				payload, pos = read_subblocks(data, pos)
				f.data_size = #payload
				local idx = lzw_decode(minbits, payload, fw * fh)
				if f.interlaced then idx = deinterlace(idx, fw, fh) end
				f.data = idx
			else
				local dsize
				pos, dsize = skip_subblocks(data, pos)
				f.data_size = dsize
			end
			g.data_size = g.data_size + f.data_size
			g.frames[#g.frames + 1] = f
		elseif b == 0x21 then
			-- extension introducer
			if pos > n then return fail("truncated extension") end
			local label = string_byte(data, pos)
			pos = pos + 1
			if label == 0xF9 then
				-- graphics control extension
				if pos > n or string_byte(data, pos) ~= 4 then return fail("bad GCE block size") end
				if pos + 4 > n then return fail("truncated GCE") end
				local gp = string_byte(data, pos + 1)
				pending = {
					disposal = band(rshift(gp, 2), 7),
					user_input = band(gp, 2) ~= 0,
					delay = le16(data, pos + 2),
					trans = band(gp, 1) ~= 0 and string_byte(data, pos + 4) or nil,
				}
				pos = pos + 5
				if pos > n or string_byte(data, pos) ~= 0 then return fail("bad GCE terminator") end
				pos = pos + 1
			elseif label == 0xFF then
				-- application extension
				if pos > n or string_byte(data, pos) ~= 11 then return fail("bad application extension") end
				if pos + 11 > n then return fail("truncated application extension") end
				local appid = string_sub(data, pos + 1, pos + 8)
				local auth = string_sub(data, pos + 9, pos + 11)
				pos = pos + 12
				local payload
				payload, pos = read_subblocks(data, pos)
				if appid == "NETSCAPE" and auth == "2.0"
					and #payload >= 3 and string_byte(payload, 1) == 1 then
					g.loop = le16(payload, 2)
				end
				local apps = g.meta.apps
				apps[#apps + 1] = { id = appid, auth = auth, data = payload }
			elseif label == 0xFE then
				-- comment extension
				local payload
				payload, pos = read_subblocks(data, pos)
				local comments = g.meta.comments
				comments[#comments + 1] = payload
			elseif label == 0x01 then
				-- plain text extension
				if pos > n or string_byte(data, pos) ~= 13 then return fail("bad plain text extension") end
				if pos + 13 > n then return fail("truncated plain text extension") end
				local grid = {
					left = le16(data, pos + 1),
					top = le16(data, pos + 3),
					width = le16(data, pos + 5),
					height = le16(data, pos + 7),
					cell_w = string_byte(data, pos + 9),
					cell_h = string_byte(data, pos + 10),
					fg = string_byte(data, pos + 11),
					bg = string_byte(data, pos + 12),
				}
				pos = pos + 14
				local payload
				payload, pos = read_subblocks(data, pos)
				grid.text = payload
				local texts = g.meta.texts
				texts[#texts + 1] = grid
			else
				-- unknown extension: skip leniently
				pos = skip_subblocks(data, pos)
				local unknown = g.meta.unknown
				unknown[#unknown + 1] = label
			end
		else
			return fail("unknown block type 0x%02X", b)
		end
	end
	return g
end

function M.decode(data, opts)
	opts = opts or {}
	if type(data) ~= "string" then return fail("decode expects a binary string") end
	return parse_gif(data, true, opts.max_pixels or 16777216)
end

function M.info(data)
	if type(data) ~= "string" then return fail("info expects a binary string") end
	return parse_gif(data, false, math_huge)
end

----------------------------------------------------------------------
-- SECTION: rendering (disposal-aware frame composition -> RGBA canvas)
----------------------------------------------------------------------

local function compose_row(row, seg, left, lut, trans)
	local fw = #seg
	local parts, np = {}, 0
	if not trans then
		for i = 1, fw do
			np = np + 1
			parts[np] = lut[string_byte(seg, i)]
		end
	else
		local base = string_sub(row, left * 4 + 1, (left + fw) * 4)
		for i = 1, fw do
			local c = string_byte(seg, i)
			np = np + 1
			if c == trans then
				parts[np] = string_sub(base, i * 4 - 3, i * 4)
			else
				parts[np] = lut[c]
			end
		end
	end
	return string_sub(row, 1, left * 4) .. table_concat(parts)
		.. string_sub(row, (left + fw) * 4 + 1)
end

local function draw_frame(canvas, f, lut, blank)
	local w = f.width
	for j = 0, f.height - 1 do
		local y = f.top + j + 1
		local s = j * w + 1
		local seg = string_sub(f.data, s, s + w - 1)
		canvas[y] = compose_row(canvas[y] or blank, seg, f.left, lut, f.transparent)
	end
end

local Renderer = {}
Renderer.__index = Renderer

function M.renderer(g)
	return setmetatable({
		g = g,
		idx = 0,
		rows = {},
		saved = nil,
		pending = nil,
		blank = string_rep("\000\000\000\000", g.width),
		lut_cache = {},
	}, Renderer)
end

function Renderer:lut(palette)
	local t = self.lut_cache[palette]
	if t then return t end
	t = {}
	local plen = #palette
	for i = 0, 255 do
		local p = i * 3 + 1
		if p + 2 <= plen then
			t[i] = string_sub(palette, p, p + 2) .. "\255"
		else
			t[i] = "\000\000\000\255"
		end
	end
	self.lut_cache[palette] = t
	return t
end

function Renderer:step()
	local i = self.idx + 1
	local f = self.g.frames[i]
	if not f then return nil end
	if not f.data then return fail("frame has no pixel data (decoded with gif.info?)") end

	-- apply previous frame's disposal method
	local p = self.pending
	if p then
		if p.disposal == 2 then
			for y = p.top + 1, p.top + p.height do self.rows[y] = nil end
		elseif p.disposal == 3 and self.saved then
			for j = 1, p.height do self.rows[p.top + j] = self.saved[j] end
		end
		self.pending, self.saved = nil, nil
	end

	-- save canvas region if this frame wants "restore to previous"
	if f.disposal == 3 then
		local saved = {}
		for j = 1, f.height do
			saved[j] = self.rows[f.top + j] or self.blank
		end
		self.saved = saved
	end

	draw_frame(self.rows, f, self:lut(f.palette), self.blank)
	self.pending = { disposal = f.disposal, top = f.top, height = f.height }
	self.idx = i
	return self.rows
end

function Renderer:canvas()
	local parts = {}
	for y = 1, self.g.height do
		parts[y] = self.rows[y] or self.blank
	end
	return table_concat(parts)
end

function M.render(g, n)
	local r = M.renderer(g)
	n = n or #g.frames
	for _ = 1, n do
		if not r:step() then break end
	end
	return r:canvas()
end

-- single frame as a standalone RGB image (transparent pixels -> background color)
function M.frame(g, i)
	local f = g.frames[i or 0]
	if not f then return fail("frame %s out of range", tostring(i)) end
	if not f.data then return fail("frame has no pixel data (decoded with gif.info?)") end
	local bg = "\000\000\000"
	if g.global_palette then
		local off = g.background * 3 + 1
		if off + 2 <= #g.global_palette then
			bg = string_sub(g.global_palette, off, off + 2)
		end
	end
	local pal, trans = f.palette, f.transparent
	local plen, parts, np = #pal, {}, 0
	for p = 1, #f.data do
		local c = string_byte(f.data, p)
		np = np + 1
		if c == trans then
			parts[np] = bg
		else
			local off = c * 3 + 1
			if off + 2 <= plen then
				parts[np] = string_sub(pal, off, off + 2)
			else
				parts[np] = "\000\000\000"
			end
		end
	end
	return { width = f.width, height = f.height, data = table_concat(parts) }
end

----------------------------------------------------------------------
-- SECTION: metadata / helpers
----------------------------------------------------------------------

function M.isGIF(data)
	return type(data) == "string" and #data >= 6 and string_sub(data, 1, 3) == "GIF"
end

function M.getPixel(image, x, y)
	if type(x) ~= "number" or type(y) ~= "number"
		or x < 1 or x > image.width or y < 1 or y > image.height then
		return fail("pixel out of range")
	end
	local npx = image.width * image.height
	local ch = math_floor(#image.data / npx)
	if ch ~= 3 and ch ~= 4 then return fail("image must be RGB or RGBA") end
	local i = ((y - 1) * image.width + (x - 1)) * ch + 1
	local r, g, b = string_byte(image.data, i, i + 2)
	if ch == 4 then return r, g, b, string_byte(image.data, i + 3) end
	return r, g, b
end

----------------------------------------------------------------------
-- SECTION: encoder (normalize -> quantize -> map -> LZW -> blocks)
----------------------------------------------------------------------

local function frame_source(f)
	return { data = f.rgb, pixels = f.width * f.height, alpha = f.alpha }
end

local function normalize_input(input, opts)
	local w, h = input.width, input.height
	if type(w) ~= "number" or type(h) ~= "number"
		or w < 1 or h < 1 or w % 1 ~= 0 or h % 1 ~= 0 then
		return fail("image needs positive integer width/height")
	end
	local raw = input.frames or { input }
	local frames = {}
	for i = 1, #raw do
		local f = raw[i]
		local fw, fh = f.width or w, f.height or h
		if type(fw) ~= "number" or type(fh) ~= "number"
			or fw < 1 or fh < 1 or fw % 1 ~= 0 or fh % 1 ~= 0 then
			return fail("frame %d needs positive integer width/height", i)
		end
		local left, top = f.left or 0, f.top or 0
		if left % 1 ~= 0 or top % 1 ~= 0 or left < 0 or top < 0
			or left + fw > w or top + fh > h then
			return fail("frame %d exceeds logical screen", i)
		end
		local data = f.data
		if type(data) == "table" then data = table_to_string(data, 1, #data) end
		if type(data) ~= "string" then return fail("frame %d: data must be a string or byte table", i) end
		local npx = fw * fh
		local nf = {
			left = left,
			top = top,
			width = fw,
			height = fh,
			delay = math_floor(f.delay or 0),
			disposal = math_floor(f.disposal or 0),
			interlace = (f.interlace or opts.interlace) and true or false,
			user_input = f.user_input and true or false,
			trans_spec = nil,
		}
		if nf.delay < 0 then return fail("frame %d: delay must be >= 0", i) end
		if nf.disposal < 0 or nf.disposal > 7 then return fail("frame %d: disposal must be 0..7", i) end

		if #data == npx * 4 then
			-- RGBA: split into RGB + alpha plane
			local rgb, alpha, rn, an = {}, {}, 0, 0
			local has_alpha = false
			for p = 1, #data, 4 do
				local r, g, b, a = string_byte(data, p, p + 3)
				rgb[rn + 1] = r
				rgb[rn + 2] = g
				rgb[rn + 3] = b
				rn = rn + 3
				an = an + 1
				alpha[an] = a
				if a < 128 then has_alpha = true end
			end
			nf.rgb = table_to_string(rgb, 1, rn)
			if has_alpha then nf.alpha = table_to_string(alpha, 1, an) end
		elseif #data == npx * 3 then
			nf.rgb = data
		elseif #data == npx and (f.palette or input.palette or opts.palette) then
			local pal = f.palette or input.palette or opts.palette
			if type(pal) ~= "string" or #pal == 0 or #pal % 3 ~= 0 then
				return fail("frame %d: indexed data needs an RGB palette string", i)
			end
			if #pal / 3 > 256 then return fail("palette too large") end
			nf.data = data
			nf.palette = pal
		else
			return fail("frame %d: data size mismatch (expected %d, %d or %d bytes, got %d)",
				i, npx * 4, npx * 3, npx, #data)
		end

		local tr = f.transparent
		if tr == nil and i == 1 and (#raw == 1 or opts.transparent ~= nil) then
			tr = input.transparent or opts.transparent
		end
		if type(tr) == "number" then
			nf.transparent = math_floor(tr)
		elseif type(tr) == "table" then
			nf.trans_spec = tr
		elseif type(tr) == "string" and #tr == 3 then
			nf.trans_spec = tr
		end
		frames[i] = nf
	end

	local loop = opts.loop
	if loop == nil then loop = input.loop end
	if loop == nil and #frames > 1 then loop = 0 end -- animations loop by default
	if loop == false then loop = nil end

	return {
		width = w,
		height = h,
		background = math_floor(input.background or opts.background or 0),
		aspect = math_floor(input.aspect or 0),
		loop = loop,
		frames = frames,
	}
end

local function map_frame(f, mapfn, trans_idx)
	local npx, t, rgb, alpha = f.width * f.height, {}, f.rgb, f.alpha
	if alpha then
		for p = 1, npx do
			if string_byte(alpha, p) < 128 then
				t[p] = trans_idx
			else
				local off = p * 3 - 2
				t[p] = mapfn(string_byte(rgb, off, off + 2))
			end
		end
	else
		for p = 1, npx do
			local off = p * 3 - 2
			t[p] = mapfn(string_byte(rgb, off, off + 2))
		end
	end
	return table_to_string(t, 1, npx)
end

local function spec_rgb(spec)
	if type(spec) == "string" then return string_byte(spec, 1, 3) end
	return spec[1] or spec.r or 0, spec[2] or spec.g or 0, spec[3] or spec.b or 0
end

local function build_palettes(im, opts)
	local frames, method = im.frames, opts.quantize or "median"

	-- does any frame need a 1-bit transparency slot in the global palette?
	local need_trans = false
	if not opts.local_palettes then
		for i = 1, #frames do
			if frames[i].alpha then
				need_trans = true
				break
			end
		end
	end
	local max_global = need_trans and 255 or 256

	-- decide global palette (explicit > quantized union > none)
	if opts.palette then
		if type(opts.palette) ~= "string" or #opts.palette == 0 or #opts.palette % 3 ~= 0 then
			return fail("opts.palette must be a non-empty RGB byte string")
		end
		if #opts.palette / 3 > max_global then return fail("palette too large") end
		im.g_entries, im.g_n = chunk_palette(opts.palette)
	elseif not opts.local_palettes then
		local sources = {}
		for i = 1, #frames do
			if frames[i].rgb then sources[#sources + 1] = frame_source(frames[i]) end
		end
		if #sources > 0 then
			local entries, n, mapfn = quantize(sources, method, max_global)
			im.g_entries, im.g_n, im.g_map = entries, n, mapfn
		end
	end

	-- reserve one palette slot for 1-bit transparency (RGBA inputs)
	if im.g_entries then
		local need = false
		for i = 1, #frames do
			if frames[i].alpha then
				need = true
				break
			end
		end
		if need then
			local slot = reserve_slot(im.g_entries, im.g_n)
			if slot == nil then
				return fail("palette is full (256 colors); cannot reserve a transparency slot")
			end
			im.g_trans = slot
		end
		im.global_palette = table_concat(im.g_entries)
		if not im.g_map then
			im.g_map = make_mapper(im.g_entries, im.g_n, {}, im.g_trans)
		end
	end

	-- per-frame palette assignment + RGB -> index mapping
	for i = 1, #frames do
		local f = frames[i]
		if f.rgb then
			local entries, mapfn, trans_idx
			if opts.local_palettes then
				local e, n, m = quantize({ frame_source(f) }, method, f.alpha and 255 or 256)
				if f.alpha then
					local slot = reserve_slot(e, n)
					if slot == nil then
						return fail("frame %d: palette full; cannot reserve transparency slot", i)
					end
					trans_idx = slot
				end
				entries, mapfn = e, m
			else
				mapfn = im.g_map
				if f.alpha then trans_idx = im.g_trans end
			end
			if f.trans_spec then
				trans_idx = mapfn(spec_rgb(f.trans_spec))
			end
			f.data = map_frame(f, mapfn, trans_idx)
			if trans_idx ~= nil then f.transparent = trans_idx end
			if opts.local_palettes then
				f.palette = table_concat(entries)
				f.local_pal = true
			end
			f.rgb, f.alpha = nil, nil
		else
			local entries = math_floor(#f.palette / 3)
			if f.transparent ~= nil and (f.transparent < 0 or f.transparent >= entries) then
				return fail("frame %d: transparent index out of range", i)
			end
			f.local_pal = not (im.global_palette and f.palette == im.global_palette)
		end
	end
end

function M.encode(input, opts)
	opts = opts or {}
	local im = normalize_input(input, opts)
	build_palettes(im, opts)

	-- global color table (dummy 2-entry table keeps pickers happy when absent)
	local gpal, gbits, gentries
	if im.global_palette then
		local cnt = math_floor(#im.global_palette / 3)
		gbits, gentries = palette_bits_for(cnt)
		if not gbits then return fail("global palette too large") end
		gpal = pad_palette(im.global_palette, gentries)
	else
		gbits, gentries, gpal = 1, 2, "\000\000\000\255\255\255"
	end
	local bg = im.background
	if bg < 0 or bg >= gentries then bg = 0 end

	-- version: 89a is required for any extension block
	local ncomments = opts.comments and #opts.comments or 0
	local needs89 = im.loop ~= nil or ncomments > 0 or #im.frames > 1
	for i = 1, #im.frames do
		local f = im.frames[i]
		if f.transparent ~= nil or f.delay > 0 or f.disposal > 0 or f.user_input then
			needs89 = true
			break
		end
	end

	local out, n = {}, 0
	local function put(s)
		n = n + 1
		out[n] = s
	end

	put(needs89 and "GIF89a" or "GIF87a")
	local spack = bor(0x80, 0x70, gbits - 1) -- GCT flag + 8-bit color resolution
	put(le16str(im.width) .. le16str(im.height) .. string_char(spack, bg, im.aspect))
	put(gpal)

	if im.loop ~= nil then
		put("\033\255\011NETSCAPE2.0\003\001" .. le16str(im.loop) .. "\000")
	end
	if opts.comments then
		for i = 1, #opts.comments do
			put("\033\254" .. wrap_subblocks(tostring(opts.comments[i])))
		end
	end

	for i = 1, #im.frames do
		local f = im.frames[i]
		-- graphics control extension
		if f.transparent ~= nil or f.delay > 0 or f.disposal > 0 or f.user_input or #im.frames > 1 then
			local gpacked = lshift(band(f.disposal, 7), 2)
			if f.user_input then gpacked = bor(gpacked, 2) end
			if f.transparent ~= nil then gpacked = bor(gpacked, 1) end
			put("\033\249\004" .. string_char(gpacked)
				.. le16str(f.delay) .. string_char(f.transparent or 0) .. "\000")
		end
		-- image descriptor (+ optional local color table)
		local lpal, lbits = nil, nil
		local ipacked = 0
		if f.interlace then ipacked = bor(ipacked, 0x40) end
		if f.local_pal then
			local cnt = math_floor(#f.palette / 3)
			lbits, lentries = palette_bits_for(cnt)
			if not lbits then return fail("frame %d: local palette too large", i) end
			lpal = pad_palette(f.palette, lentries)
			ipacked = bor(ipacked, 0x80, lbits - 1)
		end
		put("\044" .. le16str(f.left) .. le16str(f.top)
			.. le16str(f.width) .. le16str(f.height) .. string_char(ipacked))
		if lpal then put(lpal) end
		-- image data: LZW minimum code size + sub-blocked code stream
		local minbits = math_max(2, f.local_pal and lbits or gbits)
		local idxdata = f.data
		if f.interlace then idxdata = interlace_indices(idxdata, f.width, f.height) end
		put(string_char(minbits) .. wrap_subblocks(lzw_encode(idxdata, minbits)))
	end

	put("\059") -- trailer
	return table_concat(out)
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
		return fail("no io handler injected - call gif.setIO{ read = ..., write = ... }")
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
	-- 1. raw LZW codec roundtrips (patterns + long runs force clears & KwKwK cases)
	for _, minbits in ipairs({ 2, 8 }) do
		local t = {}
		for i = 1, 4096 do
			t[i] = string_char((i * 7 + math_floor(i / 50)) % lshift(1, minbits))
		end
		local idx = table_concat(t)
		local z = M.internal.lzw_encode(idx, minbits)
		assert(M.internal.lzw_decode(minbits, z, #idx) == idx,
			string_format("selftest: LZW roundtrip (minbits=%d)", minbits))
	end
	local same = string_rep("\007", 10000)
	assert(M.internal.lzw_decode(8, M.internal.lzw_encode(same, 8), #same) == same,
		"selftest: LZW run roundtrip")

	-- 2. exact-palette single-frame roundtrip
	local w, h = 24, 16
	local colors = { "\255\000\000", "\000\255\000", "\000\000\255", "\255\255\000" }
	local px = {}
	for y = 1, h do
		for x = 1, w do
			px[#px + 1] = colors[((x + y * 3) % 4) + 1]
		end
	end
	local rgb = table_concat(px)
	local enc = M.encode({ width = w, height = h, data = rgb })
	local dec = M.decode(enc)
	assert(dec.width == w and dec.height == h and #dec.frames == 1, "selftest: dimensions")
	assert(M.frame(dec, 1).data == rgb, "selftest: RGB roundtrip")
	local canvas = M.render(dec)
	assert(#canvas == w * h * 4, "selftest: canvas size")
	local r0, g0, b0, a0 = M.getPixel({ width = w, height = h, data = canvas }, 1, 1)
	assert(r0 == 255 and g0 == 0 and b0 == 0 and a0 == 255, "selftest: render pixel")

	-- 3. 1-bit transparency via explicit transparent color
	local enc_t = M.encode({ width = w, height = h, data = rgb }, { transparent = { 255, 0, 0 } })
	local dec_t = M.decode(enc_t)
	assert(dec_t.frames[1].transparent ~= nil, "selftest: transparent index")
	local ct = M.render(dec_t)
	local _, _, _, at1 = M.getPixel({ width = w, height = h, data = ct }, 1, 1)
	local _, _, _, at2 = M.getPixel({ width = w, height = h, data = ct }, 2, 1)
	assert(at1 == 0 and at2 == 255, "selftest: transparency alpha")

	-- 4. animation: delays, NETSCAPE loop, disposal method 2
	local enc_a = M.encode({
		width = 8,
		height = 8,
		frames = {
			{ data = string_rep("\255\000\000", 64), delay = 10 },
			{ data = string_rep("\000\255\000", 64), delay = 20, disposal = 2 },
			{
				data = string_rep("\000\000\255", 16),
				delay = 30,
				width = 4,
				height = 4,
				left = 2,
				top = 2
			},
		},
	}, { loop = 5 })
	local dec_a = M.decode(enc_a)
	assert(#dec_a.frames == 3 and dec_a.loop == 5, "selftest: animation meta")
	assert(dec_a.frames[1].delay == 10 and dec_a.frames[2].delay == 20
		and dec_a.frames[3].delay == 30, "selftest: delays")
	assert(dec_a.frames[2].disposal == 2, "selftest: disposal meta")
	local rend = M.renderer(dec_a)
	rend:step(); rend:step(); rend:step()
	local c3 = rend:canvas()
	local _, _, _, a3 = M.getPixel({ width = 8, height = 8, data = c3 }, 1, 1)
	assert(a3 == 0, "selftest: disposal restore-to-background")
	local rb, gb, bb, ab = M.getPixel({ width = 8, height = 8, data = c3 }, 3, 3)
	assert(ab == 255 and rb == 0 and gb == 0 and bb == 255, "selftest: frame3 pixel")

	-- 5. interlaced roundtrip
	local enc_i = M.encode({ width = w, height = h, data = rgb }, { interlace = true })
	local dec_i = M.decode(enc_i)
	assert(dec_i.frames[1].interlaced, "selftest: interlace flag")
	assert(M.frame(dec_i, 1).data == rgb, "selftest: interlaced roundtrip")

	-- 6. per-frame local color tables
	local enc_l = M.encode({
		width = 8,
		height = 8,
		frames = {
			{ data = string_rep("\255\000\000", 64) },
			{ data = string_rep("\000\255\000", 64) },
		},
	}, { local_palettes = true })
	local dec_l = M.decode(enc_l)
	assert(M.frame(dec_l, 1).data == string_rep("\255\000\000", 64), "selftest: local palette f1")
	assert(M.frame(dec_l, 2).data == string_rep("\000\255\000", 64), "selftest: local palette f2")

	-- 7. RGBA input with alpha -> 1-bit transparency
	local rgba = {}
	for i = 1, 64 do
		rgba[#rgba + 1] = (i % 2 == 0) and "\255\128\000\255" or "\000\000\255\000"
	end
	local dec_r = M.decode(M.encode({ width = 8, height = 8, data = table_concat(rgba) }))
	local cr = M.render(dec_r)
	local _, _, _, ar1 = M.getPixel({ width = 8, height = 8, data = cr }, 1, 1)
	local _, _, _, ar2 = M.getPixel({ width = 8, height = 8, data = cr }, 2, 1)
	assert(ar1 == 0 and ar2 == 255, "selftest: RGBA alpha roundtrip")

	-- 8. continuous-tone gradient (forces real quantization) via both strategies
	local gw, gh = 32, 32
	local gpx = {}
	for y = 1, gh do
		for x = 1, gw do
			gpx[#gpx + 1] = string_char(band(x * 8, 255), band(y * 8, 255), band(x + y, 255))
		end
	end
	local grad = table_concat(gpx)
	for _, q in ipairs({ "median", "uniform" }) do
		local decg = M.decode(M.encode({ width = gw, height = gh, data = grad }, { quantize = q }))
		assert(decg.width == gw and decg.height == gh, "selftest: gradient dims (" .. q .. ")")
		local fr = M.frame(decg, 1)
		assert(#fr.data == gw * gh * 3, "selftest: gradient size (" .. q .. ")")
		local r1, g1, b1 = M.getPixel(fr, 16, 16)
		local po = (15 * gw + 15) * 3 + 1
		local er, eg, eb = string_byte(grad, po, po + 2)
		assert(math_abs(r1 - er) <= 20 and math_abs(g1 - eg) <= 20 and math_abs(b1 - eb) <= 20,
			"selftest: gradient accuracy (" .. q .. ")")
	end

	-- 9. info(): cheap parse, no pixel decode
	local inf = M.info(enc_a)
	assert(inf.width == 8 and inf.height == 8 and #inf.frames == 3 and inf.loop == 5,
		"selftest: info")
	assert(inf.frames[1].data == nil, "selftest: info skips pixels")

	-- 10. injectable IO roundtrip
	local fs = {}
	M.setIO({
		read = function(p) return fs[p] end,
		write = function(p, d) fs[p] = d end,
	})
	M.save("test.gif", { width = w, height = h, data = rgb })
	assert(M.frame(M.load("test.gif"), 1).data == rgb, "selftest: IO roundtrip")

	return true
end

-- advanced/testing access to internals
M.internal = {
	lzw_encode = lzw_encode,
	lzw_decode = lzw_decode,
	quantize = quantize,
}

--M.selftest()

-- Deprecated aliases (naming standard: snake_case). Kept for compatibility.
M.get_pixel = M.getPixel
M.is_gif = M.isGIF
M.set_io = M.setIO

-- Export
return M
