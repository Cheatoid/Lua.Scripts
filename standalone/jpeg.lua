-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Baseline (non-progressive, Huffman-coded) JPEG encoder/decoder.
--
-- QUICK API
--   local bytes, err = jpeg.encode(rgb, width, height, options)
--   local rgb, width, height, err = jpeg.decode(bytes)
--   jpeg.save(path, rgb, w, h, options) -> nbytes | nil, err
--   jpeg.load(path)                     -> rgb, w, h | nil, err
--
-- IMAGE REPRESENTATION
--   rgb is a FLAT Lua table of width*height*3 integers 0..255,
--   RGB interleaved, row-major:  rgb[(y*w + x)*3 + 1] = R, +2 = G, +3 = B.
--   (encode() also accepts a binary string of the same layout.)
--
-- ENCODE OPTIONS
--   quality          1..100 (default 75). Scales the quantization tables
--                    using the classic libjpeg formula.
--   quantization     { luminance = {64 ints}, chrominance = {64 ints} }
--                    Custom tables in NATURAL (raster) order, 1..255.
--                    If `quality` is also given, it scales these tables too;
--                    otherwise custom tables are used verbatim.
--   huffman          { dc_luminance = {bits=..., values=...}, ac_luminance=...,
--                      dc_chrominance=..., ac_chrominance=... }
--                    Custom Huffman specs (defaults: JPEG Annex K tables).
--                    bits[i] = number of codes of length i (i = 1..16),
--                    values  = symbols in code order.
--   restart_interval N MCUs between restart markers (default 0 = none).
--
-- SUPPORTED ON DECODE
--   SOI, APPn/COM (skipped), DQT (8/16-bit), SOF0, DHT, DRI, SOS, EOI,
--   restart markers, grayscale + YCbCr with any sampling factors (4:4:4,
--   4:2:0, 4:2:2, ...), nearest-neighbor chroma upsampling.
--
-- NOT SUPPORTED (errors out cleanly)
--   Progressive / lossless / arithmetic coding, 12-bit precision, CMYK,
--   multi-scan files, hierarchical modes.
--
-- JPEG FILE STRUCTURE (produced by this encoder)
--   SOI (FFD8)                       start of image
--   APP0 (FFE0) "JFIF"               application metadata (skipped by decoder)
--   DQT (FFDB) x2                    quantization tables (zig-zag order)
--   SOF0 (FFC0)                      frame: size, precision, components
--   DHT (FFC4) x4                    Huffman tables (DC/AC x luma/chroma)
--   SOS (FFDA)                       scan: component -> table mapping
--   <entropy-coded data>             Huffman + byte stuffed
--   EOI (FFD9)                       end of image
--[[
  local jpeg = require "jpeg"

  -- rgb: flat table (or string) of w*h*3 bytes, RGB interleaved, row-major.
  local bytes, err = jpeg.encode(rgb, w, h, { quality = 90 })
  local rgb2, w2, h2, err = jpeg.decode(bytes)

  jpeg.save("out.jpg", rgb, w, h, { quality = 75 })   -> nbytes | nil, err
  local rgb, w, h = jpeg.load("out.jpg")

  Options for encode():
    quality           1..100, default 75
    quantization      { luminance = t64, chrominance = t64 } natural order,
                      integers 1..255 (scaled by quality if quality is given)
    huffman           custom { bits = {16 ints}, values = {symbols} } specs
                      for dc_luminance / ac_luminance / dc_chrominance /
                      ac_chrominance (defaults: JPEG Annex K tables)
    restart_interval  MCUs between RST markers (default 0 = none)

  Standard tables are exported as jpeg.STD_QUANT, jpeg.STD_HUFF, jpeg.ZIGZAG.

LIMITATIONS
  * Baseline sequential JPEG only (SOF0, 8-bit, Huffman coding).
    Progressive, lossless, arithmetic coding and 12-bit files are rejected.
  * Encoder output is always 4:4:4 YCbCr (no chroma subsampling).
  * Decoder accepts any sampling factors and upsamples with nearest-neighbor.
  * Grayscale (1-component) files decode to R=G=B=Y.
  * APP/COM metadata is skipped, not parsed.
  * Single-scan files only (all baseline files are single-scan).
]]

-- Localized globals (performance + style consistent with sibling modules)
local error         = error
local ipairs        = ipairs
local pairs         = pairs
local pcall         = pcall
local setmetatable  = setmetatable
local string_format = string.format
local math_floor    = math.floor
local math_ceil     = math.ceil
local math_cos      = math.cos
local math_sqrt     = math.sqrt
local math_min      = math.min
local math_pi       = math.pi
local string_byte   = string.byte
local string_char   = string.char
local string_sub    = string.sub
local table_concat  = table.concat

local bitstream     = require "bitstream"

local BitReader     = bitstream.BitReader
local BitWriter     = bitstream.BitWriter
local POW2          = bitstream.POW2

local M             = {}

local MAX_PIXELS    = 64 * 1024 * 1024 -- decode/encode safety cap

local function jerror(fmt, ...)
	return error(string_format("[jpeg] " .. fmt, ...), 0)
end

local function clamp(v, lo, hi)
	if v < lo then return lo elseif v > hi then return hi end
	return v
end

----------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------

-- Marker codes (the byte after 0xFF)
local M_SOI, M_EOI, M_SOF0, M_DHT, M_DQT, M_SOS, M_DRI =
	0xD8, 0xD9, 0xC0, 0xC4, 0xDB, 0xDA, 0xDD

-- Zig-zag order: ZIGZAG[i] = natural (raster) index of the i-th coefficient
-- in scan order (both 1-based). JPEG transmits coefficients in this order
-- because low spatial frequencies come first and are most likely non-zero.
local ZIGZAG = {
	1, 2, 9, 17, 10, 3, 4, 11,
	18, 25, 33, 26, 19, 12, 5, 6,
	13, 20, 27, 34, 41, 49, 42, 35,
	28, 21, 14, 7, 8, 15, 22, 29,
	36, 43, 50, 57, 58, 51, 44, 37,
	30, 23, 16, 24, 31, 38, 45, 52,
	59, 60, 53, 46, 39, 32, 40, 47,
	54, 61, 62, 55, 48, 56, 63, 64,
}

-- Annex K standard quantization tables, NATURAL (raster) order.
-- Luminance (K.1):
local STD_QUANT_LUM = {
	16, 11, 10, 16, 24, 40, 51, 61,
	12, 12, 14, 19, 26, 58, 60, 55,
	14, 13, 16, 24, 40, 57, 69, 56,
	14, 17, 22, 29, 51, 87, 80, 62,
	18, 22, 37, 56, 68, 109, 103, 77,
	24, 35, 55, 64, 81, 104, 113, 92,
	49, 64, 78, 87, 103, 121, 120, 101,
	72, 92, 95, 98, 112, 100, 103, 99,
}
-- Chrominance (K.2):
local STD_QUANT_CHR = {
	17, 18, 24, 47, 99, 99, 99, 99,
	18, 21, 26, 66, 99, 99, 99, 99,
	24, 26, 56, 99, 99, 99, 99, 99,
	47, 66, 99, 99, 99, 99, 99, 99,
	99, 99, 99, 99, 99, 99, 99, 99,
	99, 99, 99, 99, 99, 99, 99, 99,
	99, 99, 99, 99, 99, 99, 99, 99,
	99, 99, 99, 99, 99, 99, 99, 99,
}

-- Annex K standard Huffman tables.
-- bits[i] = how many codes have length i; values = symbols in code order.
local STD_HUFF = {
	dc_luminance = {
		bits   = { 0, 1, 5, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0 },
		values = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 },
	},
	dc_chrominance = {
		bits   = { 0, 3, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0 },
		values = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 },
	},
	ac_luminance = {
		bits = { 0, 2, 1, 3, 3, 2, 4, 3, 5, 5, 4, 4, 0, 0, 1, 0x7D },
		values = {
			0x01, 0x02, 0x03, 0x00, 0x04, 0x11, 0x05, 0x12, 0x21, 0x31, 0x41, 0x06, 0x13, 0x51, 0x61, 0x07,
			0x22, 0x71, 0x14, 0x32, 0x81, 0x91, 0xA1, 0x08, 0x23, 0x42, 0xB1, 0xC1, 0x15, 0x52, 0xD1, 0xF0,
			0x24, 0x33, 0x62, 0x72, 0x82, 0x09, 0x0A, 0x16, 0x17, 0x18, 0x19, 0x1A, 0x25, 0x26, 0x27, 0x28,
			0x29, 0x2A, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3A, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49,
			0x4A, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5A, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69,
			0x6A, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79, 0x7A, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89,
			0x8A, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9A, 0xA2, 0xA3, 0xA4, 0xA5, 0xA6, 0xA7,
			0xA8, 0xA9, 0xAA, 0xB2, 0xB3, 0xB4, 0xB5, 0xB6, 0xB7, 0xB8, 0xB9, 0xBA, 0xC2, 0xC3, 0xC4, 0xC5,
			0xC6, 0xC7, 0xC8, 0xC9, 0xCA, 0xD2, 0xD3, 0xD4, 0xD5, 0xD6, 0xD7, 0xD8, 0xD9, 0xDA, 0xE1, 0xE2,
			0xE3, 0xE4, 0xE5, 0xE6, 0xE7, 0xE8, 0xE9, 0xEA, 0xF1, 0xF2, 0xF3, 0xF4, 0xF5, 0xF6, 0xF7, 0xF8,
			0xF9, 0xFA,
		},
	},
	ac_chrominance = {
		bits = { 0, 2, 1, 2, 4, 4, 3, 4, 7, 5, 4, 4, 0, 1, 2, 0x77 },
		values = {
			0x00, 0x01, 0x02, 0x03, 0x11, 0x04, 0x05, 0x21, 0x31, 0x06, 0x12, 0x41, 0x51, 0x07, 0x61, 0x71,
			0x13, 0x22, 0x32, 0x81, 0x08, 0x14, 0x42, 0x91, 0xA1, 0xB1, 0xC1, 0x09, 0x23, 0x33, 0x52, 0xF0,
			0x15, 0x62, 0x72, 0xD1, 0x0A, 0x16, 0x24, 0x34, 0xE1, 0x25, 0xF1, 0x17, 0x18, 0x19, 0x1A, 0x26,
			0x27, 0x28, 0x29, 0x2A, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3A, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48,
			0x49, 0x4A, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5A, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68,
			0x69, 0x6A, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79, 0x7A, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87,
			0x88, 0x89, 0x8A, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9A, 0xA2, 0xA3, 0xA4, 0xA5,
			0xA6, 0xA7, 0xA8, 0xA9, 0xAA, 0xB2, 0xB3, 0xB4, 0xB5, 0xB6, 0xB7, 0xB8, 0xB9, 0xBA, 0xC2, 0xC3,
			0xC4, 0xC5, 0xC6, 0xC7, 0xC8, 0xC9, 0xCA, 0xD2, 0xD3, 0xD4, 0xD5, 0xD6, 0xD7, 0xD8, 0xD9, 0xDA,
			0xE2, 0xE3, 0xE4, 0xE5, 0xE6, 0xE7, 0xE8, 0xE9, 0xEA, 0xF2, 0xF3, 0xF4, 0xF5, 0xF6, 0xF7, 0xF8,
			0xF9, 0xFA,
		},
	},
}

M.STD_QUANT = { luminance = STD_QUANT_LUM, chrominance = STD_QUANT_CHR }
M.STD_HUFF = STD_HUFF
M.ZIGZAG = ZIGZAG

----------------------------------------------------------------------
-- DCT math
--
-- The JPEG DCT on an 8x8 block f(x,y) is
--   F(u,v) = 1/4 * C(u)*C(v) * sum_x sum_y f(x,y)
--              * cos((2x+1)u*pi/16) * cos((2y+1)v*pi/16)
-- with C(0) = 1/sqrt(2), C(k) = 1 otherwise.
--
-- We precompute the orthonormal basis
--   B[u][x] = C(u)/2 * cos((2x+1)u*pi/16)
-- so that      F(u,v) = sum_x sum_y B[u][x] * B[v][y] * f(x,y)
-- and (because B is orthonormal) the inverse is the transposed operation:
--              f(x,y) = sum_u sum_v B[u][x] * B[v][y] * F(u,v)
-- Each 2D transform is done separably as two passes of 1D transforms
-- (8x8 multiplies each) instead of a brute-force 64x64.
----------------------------------------------------------------------

local BASIS = {}
do
	local inv_sqrt2 = math_sqrt(0.5)
	for u = 0, 7 do
		local cu = (u == 0) and inv_sqrt2 or 1
		local row = {}
		for x = 0, 7 do
			row[x + 1] = cu * 0.5 * math_cos((2 * x + 1) * u * math_pi / 16)
		end
		BASIS[u + 1] = row
	end
end

-- forward DCT: block (flat 64, row-major, level-shifted) -> coefficients
-- output index (v-1)*8 + u matches JPEG natural order (u=horiz, v=vert freq)
local function fdct(block)
	local tmp, out = {}, {}
	-- pass 1: transform each row (x direction)
	for y = 0, 7 do
		local base = y * 8
		for u = 1, 8 do
			local Bu = BASIS[u]
			local s = 0
			for x = 1, 8 do s = s + Bu[x] * block[base + x] end
			tmp[base + u] = s
		end
	end
	-- pass 2: transform each column (y direction)
	for u = 1, 8 do
		for v = 1, 8 do
			local Bv = BASIS[v]
			local s = 0
			for y = 0, 7 do s = s + Bv[y + 1] * tmp[y * 8 + u] end
			out[(v - 1) * 8 + u] = s
		end
	end
	return out
end

-- inverse DCT: coefficients (sparse table, nil == 0) -> samples
local function idct(coef)
	local tmp, out = {}, {}
	-- pass 1: sum over vertical frequencies v
	for u = 1, 8 do
		for y = 1, 8 do
			local s = 0
			for v = 1, 8 do
				local c = coef[(v - 1) * 8 + u]
				if c then s = s + BASIS[v][y] * c end
			end
			tmp[(y - 1) * 8 + u] = s
		end
	end
	-- pass 2: sum over horizontal frequencies u
	for y = 1, 8 do
		local base = (y - 1) * 8
		for x = 1, 8 do
			local s = 0
			for u = 1, 8 do s = s + BASIS[u][x] * tmp[base + u] end
			out[base + x] = s
		end
	end
	return out
end

----------------------------------------------------------------------
-- Color conversion (JFIF formulas, full range)
----------------------------------------------------------------------
local function rgb_to_ycbcr(r, g, b)
	return 0.299 * r + 0.587 * g + 0.114 * b,
		128 - 0.168736 * r - 0.331264 * g + 0.5 * b,
		128 + 0.5 * r - 0.418688 * g - 0.081312 * b
end

local function ycbcr_to_rgb(y, cb, cr)
	return y + 1.402 * cr,
		y - 0.344136 * cb - 0.714136 * cr,
		y + 1.772 * cb
end

----------------------------------------------------------------------
-- Huffman helpers
----------------------------------------------------------------------

-- canonical codes from (bits, values): symbol -> { code, len }
local function build_encode_table(def, name)
	local enc = {}
	local code, k = 0, 1
	for len = 1, 16 do
		local count = def.bits[len]
		if code + count > POW2[len] then
			return jerror("%s: over-subscribed code lengths", name)
		end
		for _ = 1, count do
			enc[def.values[k]] = { code = code, len = len }
			k = k + 1
			code = code + 1
		end
		code = code * 2
	end
	return enc
end

-- decode tree from (bits, values): internal nodes use [0]/[1] children,
-- leaves carry .v
local function build_decode_tree(bits, values)
	local root = {}
	local k, code = 1, 0
	for len = 1, 16 do
		for _ = 1, bits[len] do
			local node = root
			for b = len - 1, 0, -1 do
				local bit = math_floor(code / POW2[b]) % 2
				local nxt = node[bit]
				if type(nxt) ~= "table" then
					nxt = {}
					node[bit] = nxt
				end
				node = nxt
			end
			node.v = values[k]
			k = k + 1
			code = code + 1
		end
		code = code * 2
	end
	return root
end

local function huff_decode(reader, tree)
	local node = tree
	while true do
		local bit, err = reader:read_bit()
		if not bit then return nil, err end
		node = node[bit]
		if type(node) ~= "table" then
			return nil, "invalid huffman code in scan data"
		end
		if node.v ~= nil then return node.v end
	end
end

-- number of bits needed to represent |v| (JPEG "category")
local function bit_size(v)
	if v < 0 then v = -v end
	local n = 0
	while v > 0 do
		n = n + 1
		v = math_floor(v / 2)
	end
	return n
end

-- JPEG amplitude encoding: negative values are stored as (v + 2^cat - 1),
-- i.e. one's complement, so the first bit always tells the sign.
local function amplitude_bits(v, cat)
	if v >= 0 then return v end
	return v + POW2[cat] - 1
end

local function extend_sign(v, cat)
	if cat > 0 and v < POW2[cat - 1] then
		return v - POW2[cat] + 1
	end
	return v
end

local function validate_huff_def(def, name)
	if type(def) ~= "table" or type(def.bits) ~= "table"
		or type(def.values) ~= "table" then
		return jerror("%s: expected { bits = {...16...}, values = {...} }", name)
	end
	if #def.bits ~= 16 then return jerror("%s: bits must have 16 entries", name) end
	local total = 0
	for i = 1, 16 do
		local c = def.bits[i]
		if type(c) ~= "number" or c < 0 or c % 1 ~= 0 then
			return jerror("%s: bits[%d] must be a non-negative integer", name, i)
		end
		total = total + c
	end
	if total ~= #def.values then
		return jerror("%s: sum(bits)=%d but #values=%d", name, total, #def.values)
	end
	if total > 256 then return jerror("%s: more than 256 symbols", name) end
end

----------------------------------------------------------------------
-- Quantization
----------------------------------------------------------------------

-- classic libjpeg quality scaling: quality q maps to a scale percentage,
-- then each table entry is clamp(floor(base*scale/100 + 0.5), 1, 255)
local function scale_quant(base, quality)
	local scale
	if quality < 50 then
		scale = math_floor(5000 / quality) -- q=1 -> 5000%, q=49 -> 102%
	else
		scale = 200 - 2 * quality    -- q=50 -> 100%, q=100 -> 0% (lossless-ish)
	end
	local t = {}
	for i = 1, 64 do
		t[i] = clamp(math_floor((base[i] * scale + 50) / 100), 1, 255)
	end
	return t
end

local function validate_quant(t, name)
	if type(t) ~= "table" or #t ~= 64 then
		return jerror("%s: expected a table of 64 integers", name)
	end
	for i = 1, 64 do
		local v = t[i]
		if type(v) ~= "number" or v < 1 or v > 255 or v % 1 ~= 0 then
			return jerror("%s[%d]: values must be integers in 1..255", name, i)
		end
	end
end

----------------------------------------------------------------------
-- DECODER
----------------------------------------------------------------------

-- Decode one 8x8 block of coefficients (dequantized, natural order).
-- Returns coef, updated_dc_pred   or   nil, nil, err.
local function decode_block(reader, dc_tree, ac_tree, qt, pred)
	local coef = {}

	-- DC coefficient: category + amplitude bits, delta-coded vs. previous DC
	local cat, err = huff_decode(reader, dc_tree)
	if not cat then return nil, nil, err end
	if cat > 11 then return nil, nil, "invalid DC category" end
	local diff = 0
	if cat > 0 then
		diff, err = reader:read_bits(cat)
		if not diff then return nil, nil, err end
		diff = extend_sign(diff, cat)
	end
	pred = pred + diff
	coef[1] = pred * qt[1] -- zig-zag position 1 == natural position 1

	-- AC coefficients in zig-zag order: each symbol is (run<<4)|size
	local k = 2
	while k <= 64 do
		local sym
		sym, err = huff_decode(reader, ac_tree)
		if not sym then return nil, nil, err end
		local run = math_floor(sym / 16)
		local size = sym % 16
		if size == 0 then
			if run == 15 then -- ZRL: skip 16 zeros
				k = k + 16
				if k > 64 then return nil, nil, "ZRL runs past end of block" end
			else -- EOB: rest of block is zero
				break
			end
		else
			k = k + run
			if k > 64 then return nil, nil, "AC run past end of block" end
			local v
			v, err = reader:read_bits(size)
			if not v then return nil, nil, err end
			v = extend_sign(v, size)
			coef[ZIGZAG[k]] = v * qt[k] -- dequantize, place at natural index
			k = k + 1
		end
	end
	return coef, pred
end

-- Entropy-decode the whole scan into per-component sample planes.
local function decode_scan(j, reader)
	local scan = j.scan
	local mcu_w = j.max_h * 8
	local mcu_h = j.max_v * 8
	local mcus_x = math_ceil(j.width / mcu_w)
	local mcus_y = math_ceil(j.height / mcu_h)

	-- allocate component planes (sized in whole MCUs; cropped at the end)
	for ci = 1, #scan do
		local comp = scan[ci].comp
		comp.stride = mcus_x * comp.h * 8
		comp.rows = mcus_y * comp.v * 8
		comp.plane = {}
	end

	local dc_pred = {}
	for ci = 1, #scan do dc_pred[ci] = 0 end

	local rst = j.restart_interval or 0
	local mcu_index = 0

	for my = 0, mcus_y - 1 do
		for mx = 0, mcus_x - 1 do
			-- restart boundary: re-sync the bitstream and zero the DC predictors
			if rst > 0 and mcu_index > 0 and mcu_index % rst == 0 then
				local m = reader:read_marker()
				if not m then return jerror("unexpected end of data (missing restart marker)") end
				if m < 0xD0 or m > 0xD7 then
					return jerror("expected restart marker, got 0x%02X", m)
				end
				for ci = 1, #scan do dc_pred[ci] = 0 end
			end

			-- blocks are ordered component-major, then top-to-bottom, left-to-right
			for ci = 1, #scan do
				local sc = scan[ci]
				local comp = sc.comp
				local dc_t = j.huff_dc[sc.dc]
				local ac_t = j.huff_ac[sc.ac]
				local qt = j.quants[comp.tq]
				for bv = 0, comp.v - 1 do
					for bh = 0, comp.h - 1 do
						local coef, npred, err = decode_block(reader, dc_t, ac_t, qt, dc_pred[ci])
						if not coef then return jerror("%s", tostring(err)) end
						dc_pred[ci] = npred

						-- inverse DCT, level shift (+128), clamp
						local samples = idct(coef)
						local px = (mx * comp.h + bh) * 8
						local py = (my * comp.v + bv) * 8
						local plane, stride = comp.plane, comp.stride
						for y = 0, 7 do
							local row = (py + y) * stride + px
							local sbase = y * 8
							for x = 1, 8 do
								local v = samples[sbase + x] + 128
								v = math_floor(v + 0.5)
								if v < 0 then v = 0 elseif v > 255 then v = 255 end
								plane[row + x] = v
							end
						end
					end
				end
			end
			mcu_index = mcu_index + 1
		end
	end
end

-- Nearest-neighbor chroma upsampling + YCbCr -> RGB into a flat RGB table.
local function assemble_rgb(j)
	local w, h = j.width, j.height
	local comps = j.components
	local rgb = {}
	local n = 0

	if #comps == 1 then
		-- grayscale: replicate Y into all three channels
		local p, stride = comps[1].plane, comps[1].stride
		for y = 0, h - 1 do
			local row = y * stride
			for x = 0, w - 1 do
				local v = p[row + x + 1]
				n = n + 1
				rgb[n] = v
				n = n + 1
				rgb[n] = v
				n = n + 1
				rgb[n] = v
			end
		end
		return rgb
	end

	local yc, cbc, crc = comps[1], comps[2], comps[3]
	for y = 0, h - 1 do
		-- sample row for each component (nearest-neighbor vertical upsampling)
		local yY  = math_floor(y * yc.v / j.max_v) * yc.stride
		local yCb = math_floor(y * cbc.v / j.max_v) * cbc.stride
		local yCr = math_floor(y * crc.v / j.max_v) * crc.stride
		for x = 0, w - 1 do
			local xx_y    = math_floor(x * yc.h / j.max_h)
			local xx_cb   = math_floor(x * cbc.h / j.max_h)
			local xx_cr   = math_floor(x * crc.h / j.max_h)
			local Y       = yc.plane[yY + xx_y + 1]
			local cb      = cbc.plane[yCb + xx_cb + 1] - 128
			local cr      = crc.plane[yCr + xx_cr + 1] - 128
			local r, g, b = ycbcr_to_rgb(Y, cb, cr)
			r             = math_floor(r + 0.5)
			if r < 0 then r = 0 elseif r > 255 then r = 255 end
			g = math_floor(g + 0.5)
			if g < 0 then g = 0 elseif g > 255 then g = 255 end
			b = math_floor(b + 0.5)
			if b < 0 then b = 0 elseif b > 255 then b = 255 end
			n = n + 1
			rgb[n] = r
			n = n + 1
			rgb[n] = g
			n = n + 1
			rgb[n] = b
		end
	end
	return rgb
end

local function decode_jpeg(data)
	if type(data) ~= "string" then return jerror("expected JPEG data as a string") end
	if #data < 4 then return jerror("data too short to be a JPEG") end

	local pos, len_data = 1, #data

	local function rd_byte()
		local b = string_byte(data, pos)
		if not b then return jerror("unexpected end of data") end
		pos = pos + 1
		return b
	end
	local function rd_u16()
		return rd_byte() * 256 + rd_byte()
	end
	-- read a marker, skipping 0xFF fill bytes
	local function rd_marker()
		local b = rd_byte()
		if b ~= 0xFF then return jerror("expected 0xFF marker prefix at byte %d", pos - 1) end
		local m = rd_byte()
		while m == 0xFF do m = rd_byte() end
		if m == 0x00 then return jerror("invalid marker 0xFF00 outside entropy data") end
		return m
	end

	if rd_marker() ~= M_SOI then return jerror("missing SOI marker") end

	local j = {
		quants = {},
		huff_dc = {},
		huff_ac = {},
		components = {},
		comp_by_id = {},
		restart_interval = 0,
	}

	---- header segment loop (everything up to SOS) ----
	local m = rd_marker()
	while m ~= M_SOS do
		if m == M_SOF0 then
			-- Start Of Frame: image size, precision, components + sampling
			local seg_end = pos + rd_u16() - 2
			local precision = rd_byte()
			local height = rd_u16()
			local width = rd_u16()
			local nf = rd_byte()
			if precision ~= 8 then
				return jerror("only 8-bit precision supported (got %d)", precision)
			end
			if width < 1 or height < 1 then return jerror("invalid image dimensions") end
			if width * height > MAX_PIXELS then return jerror("image exceeds pixel limit") end
			if nf ~= 1 and nf ~= 3 then
				return jerror("unsupported component count %d (grayscale or YCbCr only)", nf)
			end
			local max_h, max_v = 1, 1
			for i = 1, nf do
				local id = rd_byte()
				local hv = rd_byte()
				local tq = rd_byte()
				local hh, vv = math_floor(hv / 16), hv % 16
				if hh < 1 or vv < 1 then
					return jerror("invalid sampling factors for component %d", id)
				end
				if j.comp_by_id[id] then return jerror("duplicate component id %d", id) end
				local comp = { id = id, h = hh, v = vv, tq = tq }
				j.components[i] = comp
				j.comp_by_id[id] = comp
				if hh > max_h then max_h = hh end
				if vv > max_v then max_v = vv end
			end
			j.width, j.height, j.max_h, j.max_v = width, height, max_h, max_v
			pos = seg_end
		elseif m == M_DQT then
			-- Define Quantization Table(s); values are stored in ZIG-ZAG order
			local seg_end = pos + rd_u16() - 2
			while pos < seg_end do
				local pq_tq = rd_byte()
				local prec = math_floor(pq_tq / 16) -- 0 = 8-bit, 1 = 16-bit
				local id = pq_tq % 16
				if prec > 1 then return jerror("bad DQT precision %d", prec) end
				if id > 3 then return jerror("bad DQT table id %d", id) end
				local t = {}
				for i = 1, 64 do
					local v
					if prec == 0 then
						v = rd_byte()
					else
						v = rd_byte() * 256 + rd_byte()
					end
					if v == 0 then return jerror("quantization table %d contains zero", id) end
					t[i] = v
				end
				j.quants[id] = t
			end
			pos = seg_end
		elseif m == M_DHT then
			-- Define Huffman Table(s)
			local seg_end = pos + rd_u16() - 2
			while pos < seg_end do
				local tc_th = rd_byte()
				local tc = math_floor(tc_th / 16) -- 0 = DC, 1 = AC
				local th = tc_th % 16
				if tc > 1 or th > 3 then return jerror("bad DHT class/id (%d/%d)", tc, th) end
				local bits, total = {}, 0
				for i = 1, 16 do
					bits[i] = rd_byte()
					total = total + bits[i]
				end
				local values = {}
				for i = 1, total do values[i] = rd_byte() end
				local tree = build_decode_tree(bits, values)
				if tc == 0 then j.huff_dc[th] = tree else j.huff_ac[th] = tree end
			end
			pos = seg_end
		elseif m == M_DRI then
			-- Define Restart Interval
			local seg_end = pos + rd_u16() - 2
			j.restart_interval = rd_u16()
			pos = seg_end
		elseif m == M_EOI then
			return jerror("unexpected EOI before SOS")
		elseif m == 0x01 or (m >= 0xD0 and m <= 0xD7) then
			-- TEM / RST: standalone markers, no payload (shouldn't appear here)
		elseif (m >= 0xE0 and m <= 0xEF) or m == 0xFE then
			-- APPn / COM: skip the payload
			local seg_len = rd_u16()
			if seg_len < 2 then return jerror("bad segment length") end
			pos = pos + seg_len - 2
			if pos > len_data + 1 then return jerror("truncated segment") end
		else
			return jerror("unsupported marker 0x%02X (baseline sequential JPEG only)", m)
		end
		m = rd_marker()
	end

	---- SOS: Start Of Scan ----
	if #j.components == 0 then return jerror("SOS before SOF") end
	local sos_end = pos + rd_u16() - 2
	local ns = rd_byte()
	if ns ~= #j.components then
		return jerror("scan uses %d components but frame has %d", ns, #j.components)
	end
	local scan = {}
	for i = 1, ns do
		local cs = rd_byte()
		local tdta = rd_byte()
		local comp = j.comp_by_id[cs]
		if not comp then return jerror("scan references unknown component %d", cs) end
		scan[i] = { comp = comp, dc = math_floor(tdta / 16), ac = tdta % 16 }
	end
	local ss, se, ahal = rd_byte(), rd_byte(), rd_byte()
	if ss ~= 0 or se ~= 63 or ahal ~= 0 then
		return jerror("not a baseline sequential scan (Ss=%d Se=%d Ah/Al=%d)", ss, se, ahal)
	end
	pos = sos_end

	for i = 1, ns do
		local sc = scan[i]
		if not j.quants[sc.comp.tq] then
			return jerror("missing quantization table %d", sc.comp.tq)
		end
		if not j.huff_dc[sc.dc] then return jerror("missing DC huffman table %d", sc.dc) end
		if not j.huff_ac[sc.ac] then return jerror("missing AC huffman table %d", sc.ac) end
	end
	j.scan = scan

	---- entropy-coded data ----
	local reader = BitReader.new(data, pos)
	decode_scan(j, reader)

	local rgb = assemble_rgb(j)
	return rgb, j.width, j.height
end

----------------------------------------------------------------------
-- ENCODER
----------------------------------------------------------------------

local function be16(v)
	return string_char(math_floor(v / 256) % 256, v % 256)
end

-- DQT segment: table id + 64 values in ZIG-ZAG order
local function dqt_segment(id, qt_natural)
	local vals = {}
	for i = 1, 64 do
		vals[i] = string_char(qt_natural[ZIGZAG[i]])
	end
	return "\255\219" .. be16(67) .. string_char(id) .. table_concat(vals)
end

-- DHT segment: class/id byte, 16 code-count bytes, then symbols
local function dht_segment(tc, th, def)
	local bits = {}
	for i = 1, 16 do bits[i] = string_char(def.bits[i]) end
	local vals = {}
	for i = 1, #def.values do vals[i] = string_char(def.values[i]) end
	local payload = string_char(tc * 16 + th) .. table_concat(bits) .. table_concat(vals)
	return "\255\196" .. be16(#payload + 2) .. payload
end

-- Encode one 8x8 block: extract -> FDCT -> quantize -> zig-zag -> Huffman.
-- Returns the (unquantized) DC coefficient for delta prediction.
local function encode_block(writer, plane, stride, x0, y0, qt,
							dc_enc, ac_enc, pred)
	-- level shift: JPEG's DCT operates on samples centered at 0
	local blk = {}
	for y = 0, 7 do
		local base = (y0 + y) * stride + x0
		local off = y * 8
		for x = 1, 8 do
			blk[off + x] = plane[base + x] - 128
		end
	end

	local f = fdct(blk)

	-- quantize + zig-zag reorder.  zz[i] is the coefficient at zig-zag
	-- position i; its natural index is ZIGZAG[i].
	local zz = {}
	for i = 1, 64 do
		local nat = ZIGZAG[i]
		zz[i] = math_floor(f[nat] / qt[nat] + 0.5)
	end

	-- DC: delta from previous block, category code + amplitude bits
	local dc = zz[1]
	local diff = dc - pred
	local cat = bit_size(diff)
	local hc = dc_enc[cat]
	if not hc then return jerror("DC huffman table has no code for category %d", cat) end
	writer:write_bits(hc.code, hc.len)
	if cat > 0 then
		writer:write_bits(amplitude_bits(diff, cat), cat)
	end

	-- AC: run/size symbols; ZRL for runs >= 16, EOB for trailing zeros
	local last = 64
	while last > 1 and zz[last] == 0 do last = last - 1 end

	local run = 0
	for k = 2, last do
		local v = zz[k]
		if v == 0 then
			run = run + 1
		else
			while run >= 16 do
				local hz = ac_enc[0xF0]
				if not hz then return jerror("AC huffman table has no ZRL code") end
				writer:write_bits(hz.code, hz.len)
				run = run - 16
			end
			local acat = bit_size(v)
			local sym = run * 16 + acat
			local ha = ac_enc[sym]
			if not ha then return jerror("AC huffman table has no code for 0x%02X", sym) end
			writer:write_bits(ha.code, ha.len)
			writer:write_bits(amplitude_bits(v, acat), acat)
			run = 0
		end
	end
	if last < 64 then
		local he = ac_enc[0x00]
		if not he then return jerror("AC huffman table has no EOB code") end
		writer:write_bits(he.code, he.len)
	end

	return dc
end

local function encode_jpeg(rgb, width, height, options)
	if type(width) ~= "number" or type(height) ~= "number"
		or width < 1 or height < 1 or width % 1 ~= 0 or height % 1 ~= 0 then
		return jerror("width/height must be positive integers")
	end
	if width * height > MAX_PIXELS then return jerror("image exceeds pixel limit") end

	options = options or {}
	local need = width * height * 3
	local rtype = type(rgb)
	if rtype ~= "table" and rtype ~= "string" then
		return jerror("rgb must be a flat table or a binary string")
	end
	if #rgb < need then
		return jerror("rgb data too small: need %d values, got %d", need, #rgb)
	end

	-- pixel accessor (clamps/rounds table input; strings are already bytes)
	local getpix
	if rtype == "string" then
		getpix = function(x, y)
			local i = (y * width + x) * 3
			return string_byte(rgb, i + 1, i + 3)
		end
	else
		getpix = function(x, y)
			local i = (y * width + x) * 3
			local r, g, b = rgb[i + 1], rgb[i + 2], rgb[i + 3]
			if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then
				return jerror("missing pixel value at (%d,%d)", x, y)
			end
			r = clamp(math_floor(r + 0.5), 0, 255)
			g = clamp(math_floor(g + 0.5), 0, 255)
			b = clamp(math_floor(b + 0.5), 0, 255)
			return r, g, b
		end
	end

	---- quantization tables ----
	local quality = options.quality
	if quality ~= nil then
		if type(quality) ~= "number" then return jerror("quality must be a number") end
		quality = clamp(math_floor(quality), 1, 100)
	end
	local qspec = options.quantization or {}
	local base_lum = qspec.luminance or STD_QUANT_LUM
	local base_chr = qspec.chrominance or STD_QUANT_CHR
	validate_quant(base_lum, "quantization.luminance")
	validate_quant(base_chr, "quantization.chrominance")
	local qlum, qchr
	if quality ~= nil then
		qlum = scale_quant(base_lum, quality)
		qchr = scale_quant(base_chr, quality)
	elseif options.quantization then
		qlum, qchr = base_lum, base_chr -- custom tables used verbatim
	else
		qlum = scale_quant(base_lum, 75) -- default quality
		qchr = scale_quant(base_chr, 75)
	end

	---- huffman tables ----
	local hspec = options.huffman or {}
	local defs = {
		dc_lum = hspec.dc_luminance or STD_HUFF.dc_luminance,
		ac_lum = hspec.ac_luminance or STD_HUFF.ac_luminance,
		dc_chr = hspec.dc_chrominance or STD_HUFF.dc_chrominance,
		ac_chr = hspec.ac_chrominance or STD_HUFF.ac_chrominance,
	}
	validate_huff_def(defs.dc_lum, "huffman.dc_luminance")
	validate_huff_def(defs.ac_lum, "huffman.ac_luminance")
	validate_huff_def(defs.dc_chr, "huffman.dc_chrominance")
	validate_huff_def(defs.ac_chr, "huffman.ac_chrominance")
	local enc_dc_lum = build_encode_table(defs.dc_lum, "huffman.dc_luminance")
	local enc_ac_lum = build_encode_table(defs.ac_lum, "huffman.ac_luminance")
	local enc_dc_chr = build_encode_table(defs.dc_chr, "huffman.dc_chrominance")
	local enc_ac_chr = build_encode_table(defs.ac_chr, "huffman.ac_chrominance")

	---- restart interval ----
	local restart = options.restart_interval or 0
	if type(restart) ~= "number" or restart < 0 or restart % 1 ~= 0 then
		return jerror("restart_interval must be a non-negative integer")
	end

	---- RGB -> YCbCr planes, padded out to multiples of 8 (edge replicated) ----
	local pw = math_ceil(width / 8) * 8
	local ph = math_ceil(height / 8) * 8
	local Yp, Cbp, Crp = {}, {}, {}
	for y = 0, ph - 1 do
		local sy = math_min(y, height - 1)
		for x = 0, pw - 1 do
			local sx = math_min(x, width - 1)
			local r, g, b = getpix(sx, sy)
			local Y, cb, cr = rgb_to_ycbcr(r, g, b)
			local i = y * pw + x + 1
			Yp[i], Cbp[i], Crp[i] = Y, cb, cr
		end
	end

	---- emit file structure ----
	local writer = BitWriter.new()
	writer:write_string("\255\216")                   -- SOI
	writer:write_string("\255\224" .. be16(16) ..     -- APP0
		"JFIF\000\001\001\000\000\001\000\001\000\000")
	writer:write_string(dqt_segment(0, qlum))         -- DQT lum
	writer:write_string(dqt_segment(1, qchr))         -- DQT chr
	writer:write_string("\255\192" .. be16(17) .. "\008" -- SOF0
		.. be16(height) .. be16(width) .. "\003"
		.. "\001\017\000"                             -- component 1 (Y):  1x1 sampling, qt 0
		.. "\002\017\001"                             -- component 2 (Cb): 1x1 sampling, qt 1
		.. "\003\017\001")                            -- component 3 (Cr): 1x1 sampling, qt 1
	writer:write_string(dht_segment(0, 0, defs.dc_lum)) -- DHT DC lum
	writer:write_string(dht_segment(1, 0, defs.ac_lum)) -- DHT AC lum
	writer:write_string(dht_segment(0, 1, defs.dc_chr)) -- DHT DC chr
	writer:write_string(dht_segment(1, 1, defs.ac_chr)) -- DHT AC chr
	writer:write_string("\255\218" .. be16(12) .. "\003" -- SOS
		.. "\001\000" .. "\002\017" .. "\003\017" .. "\000\063\000")

	---- entropy-coded segment (4:4:4 -> one Y, one Cb, one Cr block per MCU) ----
	local planes = { Yp, Cbp, Crp }
	local qts = { qlum, qchr, qchr }
	local dc_encs = { enc_dc_lum, enc_dc_chr, enc_dc_chr }
	local ac_encs = { enc_ac_lum, enc_ac_chr, enc_ac_chr }
	local dc_pred = { 0, 0, 0 }

	local blocks_x = pw / 8
	local blocks_y = ph / 8
	local total_mcus = blocks_x * blocks_y
	local mcu_count, rst_cycle = 0, 0

	for by = 0, blocks_y - 1 do
		for bx = 0, blocks_x - 1 do
			for ci = 1, 3 do
				dc_pred[ci] = encode_block(writer, planes[ci], pw, bx * 8, by * 8,
					qts[ci], dc_encs[ci], ac_encs[ci], dc_pred[ci])
			end
			mcu_count = mcu_count + 1
			if restart > 0 and mcu_count % restart == 0 and mcu_count < total_mcus then
				writer:write_marker(0xD0 + (rst_cycle % 8)) -- RSTn
				rst_cycle = rst_cycle + 1
				dc_pred[1], dc_pred[2], dc_pred[3] = 0, 0, 0
			end
		end
	end

	writer:write_marker(M_EOI) -- EOI (pads final byte)
	return writer:result()
end

----------------------------------------------------------------------
-- Public API (nil, err on failure)
----------------------------------------------------------------------

function M.encode(rgb, width, height, options)
	local ok, result = pcall(encode_jpeg, rgb, width, height, options)
	if ok then return result end
	return nil, result
end

function M.decode(data)
	local ok, a, b, c = pcall(decode_jpeg, data)
	if ok then return a, b, c end
	return nil, a
end

function M.save(path, rgb, width, height, options)
	local bytes, err = M.encode(rgb, width, height, options)
	if not bytes then return nil, err end
	local f, ferr = io.open(path, "wb")
	if not f then return nil, ferr end
	f:write(bytes)
	f:close()
	return #bytes
end

function M.load(path)
	local f, err = io.open(path, "rb")
	if not f then return nil, err end
	local data = f:read("*a")
	f:close()
	if not data then return nil, "unable to read file: " .. path end
	return M.decode(data)
end

-- Export
return M
