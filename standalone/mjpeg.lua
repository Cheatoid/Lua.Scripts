-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- MJPEG container on top of jpeg.lua: a sequence of baseline JPEG
-- frames plus basic metadata.
--
-- CONTAINER FORMAT (all integers are little-endian):
--   [4 bytes]  magic "MJPG"
--   [uint32]   width
--   [uint32]   height
--   [uint32]   frame_count
--   [float32]  fps (IEEE-754 single precision)
--   for each frame:
--     [uint32] frame_size
--     [frame_size bytes] JPEG data (encoded by jpeg.lua)
--
-- QUICK API
--   local bytes, err = mjpeg.encode(frames, width, height, fps, options)
--   local frames, width, height, fps, err = mjpeg.decode(bytes)
--   mjpeg.save(path, frames, w, h, fps, options) -> nbytes | nil, err
--   mjpeg.load(path)                             -> frames, w, h, fps | nil, err
--
--   frames  = array of rgb images, same flat RGB representation as jpeg.lua.
--   options = forwarded to jpeg.encode (quality, tables, ...).

local error         = error
local pcall         = pcall
local setmetatable  = setmetatable
local math_abs      = math.abs
local math_floor    = math.floor
local math_frexp    = math.frexp
local string_byte   = string.byte
local string_char   = string.char
local string_format = string.format
local string_sub    = string.sub
local table_concat  = table.concat

local jpeg          = require "jpeg"

local M             = {}

local MAGIC         = "MJPG"

local function merror(fmt, ...)
	return error(string_format("[mjpeg] " .. fmt, ...), 0)
end

----------------------------------------------------------------------
-- little-endian primitives
----------------------------------------------------------------------

local function u32le_str(v)
	return string_char(
		v % 256,
		math_floor(v / 256) % 256,
		math_floor(v / 65536) % 256,
		math_floor(v / 16777216) % 256
	)
end

local function u32le_read(s, pos)
	local b0, b1, b2, b3 = string_byte(s, pos, pos + 3)
	if not b3 then return nil end
	return b0 + b1 * 256 + b2 * 65536 + b3 * 16777216
end

-- IEEE-754 single precision encode/decode (math.frexp based)
local function f32_str(f)
	local sign = 0
	if f < 0 then sign, f = 1, -f end
	local exp, mant
	if f == 0 then
		exp, mant = 0, 0
	elseif f ~= f then -- NaN
		exp, mant = 255, 1
	else
		local m, e = math_frexp(f) -- f = m * 2^e, 0.5 <= m < 1
		local biased = e + 126 -- IEEE exponent = e-1, bias 127
		if biased >= 255 then
			exp, mant = 255, 0 -- overflow -> infinity
		elseif biased <= 0 then
			exp = 0          -- subnormal
			mant = math_floor(f * 2 ^ 149 + 0.5)
		else
			exp = biased
			mant = math_floor((m * 2 - 1) * 2 ^ 23 + 0.5)
		end
	end
	return string_char(
		mant % 256,
		math_floor(mant / 256) % 256,
		math_floor(mant / 65536) % 128 + (exp % 2) * 128,
		math_floor(exp / 2) + sign * 128
	)
end

local function f32_read(s, pos)
	local b0, b1, b2, b3 = string_byte(s, pos, pos + 3)
	if not b3 then return nil end
	local mant = b0 + b1 * 256 + (b2 % 128) * 65536
	local exp = math_floor(b2 / 128) + (b3 % 128) * 2
	local sign = math_floor(b3 / 128)
	local v
	if exp == 0 then
		v = mant * 2 ^ -149              -- subnormal
	elseif exp == 255 then
		v = (mant == 0) and (1 / 0) or (0 / 0) -- inf / nan
	else
		v = (1 + mant / 2 ^ 23) * 2 ^ (exp - 127)
	end
	if sign == 1 then v = -v end
	return v
end

----------------------------------------------------------------------
-- encode / decode
----------------------------------------------------------------------

local function encode_mjpeg(frames, width, height, fps, options)
	if type(frames) ~= "table" or #frames < 1 then
		return merror("frames must be a non-empty array of images")
	end
	if type(width) ~= "number" or type(height) ~= "number"
		or width < 1 or height < 1 or width % 1 ~= 0 or height % 1 ~= 0 then
		return merror("width/height must be positive integers")
	end
	if type(fps) ~= "number" or not (fps > 0) or fps ~= fps then
		return merror("fps must be a positive number")
	end

	-- encode every frame first so dimension/content errors surface early
	local blobs = {}
	for i = 1, #frames do
		local bytes, err = jpeg.encode(frames[i], width, height, options)
		if not bytes then
			return merror("frame %d: %s", i, tostring(err))
		end
		blobs[i] = bytes
	end

	local out = {
		MAGIC,
		u32le_str(width),
		u32le_str(height),
		u32le_str(#frames),
		f32_str(fps),
	}
	local n = 5
	for i = 1, #frames do
		n = n + 1; out[n] = u32le_str(#blobs[i])
		n = n + 1; out[n] = blobs[i]
	end
	return table_concat(out)
end

local function decode_mjpeg(data)
	if type(data) ~= "string" then return merror("expected MJPEG data as a string") end
	if #data < 20 then return merror("data too short for MJPEG header") end
	if string_sub(data, 1, 4) ~= MAGIC then return merror("bad magic (not MJPG)") end

	local width = u32le_read(data, 5)
	local height = u32le_read(data, 9)
	local frame_count = u32le_read(data, 13)
	local fps = f32_read(data, 17)
	if not (width and height and frame_count and fps) then
		return merror("truncated MJPEG header")
	end
	if width < 1 or height < 1 then return merror("invalid dimensions") end
	if 20 + frame_count * 4 > #data then
		return merror("frame count %d does not fit in %d bytes", frame_count, #data)
	end

	local frames = {}
	local pos = 21
	for i = 1, frame_count do
		local size = u32le_read(data, pos)
		if not size then return merror("truncated frame %d header", i) end
		pos = pos + 4
		if pos + size - 1 > #data then return merror("truncated frame %d data", i) end
		local rgb, fw, fh, err = jpeg.decode(string_sub(data, pos, pos + size - 1))
		if not rgb then
			return merror("frame %d: %s", i, tostring(fw)) -- fw holds the error message
		end
		if fw ~= width or fh ~= height then
			return merror("frame %d: dimensions %dx%d do not match container %dx%d",
				i, fw, fh, width, height)
		end
		frames[i] = rgb
		pos = pos + size
	end

	return frames, width, height, fps
end

----------------------------------------------------------------------
-- Public API (nil, err on failure)
----------------------------------------------------------------------

function M.encode(frames, width, height, fps, options)
	local ok, result = pcall(encode_mjpeg, frames, width, height, fps, options)
	if ok then return result end
	return nil, result
end

function M.decode(data)
	local ok, a, b, c, d = pcall(decode_mjpeg, data)
	if ok then return a, b, c, d end
	return nil, a
end

function M.save(path, frames, width, height, fps, options)
	local bytes, err = M.encode(frames, width, height, fps, options)
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
