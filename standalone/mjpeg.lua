-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- MJPEG container on top of jpeg.lua: a sequence of baseline JPEG frames plus basic metadata.
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
--[[
Usage example:
  local mjpeg = require "mjpeg"

  local bytes, err = mjpeg.encode(frames, width, height, 30, { quality = 80 })
  local frames2, w, h, fps = mjpeg.decode(bytes)

  mjpeg.save("out.mjpg", frames, width, height, 30)
  local frames3, w3, h3, fps3 = mjpeg.load("out.mjpg")
--]]

-- Localized global functions for better performance
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

----------------------------------------------------------------------
-- Module definition
----------------------------------------------------------------------

--- MJPEG container on top of `jpeg`: a sequence of baseline JPEG frames plus metadata.
---@class mjpeg
local M             = {}

--- Container magic prefix ("MJPG").
local MAGIC         = "MJPG"

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------

--- Raise a namespaced container error.
---@param fmt string Format string (without the `[mjpeg] ` prefix).
---@param ... any Format arguments.
---@return nil result Never returns; always raises.
local function merror(fmt, ...)
	return error(string_format("[mjpeg] " .. fmt, ...), 0)
end

----------------------------------------------------------------------
-- Little-endian primitives
----------------------------------------------------------------------

--- Encode an unsigned 32-bit integer as 4 little-endian bytes.
---@param v integer Value to encode.
---@return string bytes 4-byte little-endian representation.
local function u32le_str(v)
	return string_char(
		v % 256,
		math_floor(v / 256) % 256,
		math_floor(v / 65536) % 256,
		math_floor(v / 16777216) % 256
	)
end

--- Read an unsigned 32-bit little-endian integer at byte `pos`.
---@param s string Source string.
---@param pos integer 1-based byte position.
---@return integer? value The decoded value, or nil if truncated.
local function u32le_read(s, pos)
	local b0, b1, b2, b3 = string_byte(s, pos, pos + 3)
	if not b3 then return nil end
	return b0 + b1 * 256 + b2 * 65536 + b3 * 16777216
end

--- Encode a number as 4-byte IEEE-754 single precision (little-endian).<br>
--- Implemented with `math.frexp` so it works without string.pack.
---@param f number Value to encode (NaN/inf map to IEEE NaN/inf).
---@return string bytes 4-byte little-endian float.
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

--- Read an IEEE-754 single precision little-endian float at byte `pos`.
---@param s string Source string.
---@param pos integer 1-based byte position.
---@return number? value The decoded float, or nil if truncated.
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
-- Encode / Decode
----------------------------------------------------------------------

--- Pack `frames` into an MJPG container string (raises on error).<br>
--- Every frame is JPEG-encoded first so dimension/content errors surface early.
---@param frames table[] Array of images in the flat RGB representation of `jpeg`.
---@param width integer Frame width in pixels (positive integer).
---@param height integer Frame height in pixels (positive integer).
---@param fps number Frames per second (positive number).
---@param options? table Encode options forwarded to `jpeg.encode`.
---@return string bytes The encoded MJPG container.
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
		n = n + 1
		out[n] = u32le_str(#blobs[i])
		n = n + 1
		out[n] = blobs[i]
	end
	return table_concat(out)
end

--- Unpack an MJPG container string (raises on error).<br>
--- Validates the magic, header and per-frame dimensions.
---@param data string MJPG container bytes.
---@return table frames Array of decoded flat RGB images.
---@return integer width Container width in pixels.
---@return integer height Container height in pixels.
---@return number fps Frames per second.
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

--- Encode `frames` into an MJPG container string.<br>
--- Never raises; errors are returned as `nil, err`.
---@param frames table[] Array of images in the flat RGB representation of `jpeg`.
---@param width integer Frame width in pixels (positive integer).
---@param height integer Frame height in pixels (positive integer).
---@param fps number Frames per second (positive number).
---@param options? table Encode options forwarded to `jpeg.encode`.
---@return string? bytes MJPG container bytes, or nil on failure.
---@return string? err Error message on failure.
---@usage <br>
--- ```
--- local bytes, err = mjpeg.encode(frames, width, height, 30, { quality = 80 })
--- ```
function M.encode(frames, width, height, fps, options)
	local ok, result = pcall(encode_mjpeg, frames, width, height, fps, options)
	if ok then return result end
	return nil, result
end

--- Decode an MJPG container string into frames.<br>
--- Never raises; errors are returned as `nil, err`.
---@param data string MJPG container bytes.
---@return table? frames Array of flat RGB images, or nil on failure.
---@return integer|string width Frame width, or error message on failure.
---@return integer? height Frame height.
---@return number? fps Frames per second.
---@usage <br>
--- ```
--- local frames, width, height, fps, err = mjpeg.decode(bytes)
--- ```
function M.decode(data)
	local ok, a, b, c, d = pcall(decode_mjpeg, data)
	if ok then return a, b, c, d end
	return nil, a
end

--- Encode `frames` and write the container to `path`.
---@param path string Destination file path.
---@param frames table[] Array of images in the flat RGB representation of `jpeg`.
---@param width integer Frame width in pixels (positive integer).
---@param height integer Frame height in pixels (positive integer).
---@param fps number Frames per second (positive number).
---@param options? table Encode options forwarded to `jpeg.encode`.
---@return integer? nbytes Number of bytes written, or nil on failure.
---@return string? err Error message on failure.
---@usage <br>
--- ```
--- local nbytes, err = mjpeg.save("out.mjpg", frames, width, height, 30)
--- ```
function M.save(path, frames, width, height, fps, options)
	local bytes, err = M.encode(frames, width, height, fps, options)
	if not bytes then return nil, err end
	local f, ferr = io.open(path, "wb")
	if not f then return nil, ferr end
	f:write(bytes)
	f:close()
	return #bytes
end

--- Read an MJPG container from `path` and decode it.
---@param path string Source file path.
---@return table? frames Array of flat RGB images, or nil on failure.
---@return integer|string width Frame width, or error message on failure.
---@return integer? height Frame height.
---@return number? fps Frames per second.
---@usage <br>
--- ```
--- local frames, width, height, fps = mjpeg.load("out.mjpg")
--- ```
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
