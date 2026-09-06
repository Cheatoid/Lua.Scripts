-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Simple ZIP reader/writer
local Zip = {}

-- Localized global functions for better performance
local error = error
local next = next
local print = print
local setmetatable = setmetatable
local tostring = tostring
local type = type
local math_min = math.min
local string_byte = string.byte
local string_char = string.char
local string_find = string.find
local string_format = string.format
local string_gmatch = string.gmatch
local string_match = string.match
local string_sub = string.sub
local table_concat = table.concat

-- IO configuration - can be overridden for custom IO backends
local _io_open = io and io.open or (file and file.Open or (File or false))

-- Load bits module for bit operations (standalone compatible)
local bits = require "bits"
local bit_band = bits.band
local bit_bxor = bits.bxor
local bit_rshift = bits.rshift

-- Signatures
local LFH_SIG = "PK\003\004"
local CDFH_SIG = "PK\001\002"
local EOCD_SIG = "PK\005\006"
local DATA_DESC_SIG = "PK\007\008"

-- Constants
local U16 = 0xFFFF
local U32 = 0xFFFFFFFF

-- TODO: Make a proper Binary reader/writer class...

--- Standalone file I/O wrapper
---@class FileWrapper
---@field _file? file|File The underlying file handle.
local FileWrapper = {}
FileWrapper.__index = FileWrapper

--- Read unsigned short (2 bytes, little-endian).
---@return integer? value The value, or nil on error.
function FileWrapper:read_ushort()
	local data = self._file:read(2)
	if not data or #data < 2 then return end
	local b1, b2 = string_byte(data, 1, 2)
	return b1 + (b2 * 256)
end

--- Read unsigned long (4 bytes, little-endian).
---@return integer? value The value, or nil on error.
function FileWrapper:read_ulong()
	local data = self._file:read(4)
	if not data or #data < 4 then return end
	local b1, b2, b3, b4 = string_byte(data, 1, 4)
	return b1 + (b2 * 256) + (b3 * 65536) + (b4 * 16777216)
end

--- Read n bytes from the file.
---@param n integer Number of bytes to read.
---@return string? data The data, or nil on error.
function FileWrapper:read(n)
	return self._file:read(n)
end

--- Write data to the file.
---@param data string The data to write.
---@return boolean? success True on success, nil on error.
function FileWrapper:write(data)
	return self._file:write(data)
end

--- Seek to position (always absolute from start).
---@param pos integer The position to seek to.
---@return boolean? success True on success, nil on error.
function FileWrapper:seek(pos)
	return self._file:seek("set", pos)
end

--- Get current position in the file.
---@return integer position The current position.
function FileWrapper:tell()
	return self._file:seek("cur")
end

--- Get file size.
---@return integer size The file size in bytes.
function FileWrapper:size()
	local cur = self._file:seek("cur")
	local size = self._file:seek("end")
	self._file:seek("set", cur)
	return size
end

--- Skip n bytes.
---@param n integer Number of bytes to skip.
---@return boolean? success True on success, nil on error.
function FileWrapper:skip(n)
	local pos = self._file:seek("cur") or 0
	return self._file:seek("set", pos + n)
end

--- Close the file.
---@return boolean? success True on success, nil on error.
function FileWrapper:close()
	return self._file:close()
end

----------------------------------------------------------------------
-- Memory Wrapper (in-memory string buffer)
----------------------------------------------------------------------

--- In-memory string buffer wrapper.<br>
--- Implements the same interface as FileWrapper but operates on a string buffer.
---@class MemoryWrapper
---@field _buffer string The string buffer.
---@field _pos integer Current read/write position.
---@field _mode string Mode: "rb" for read, "wb" for write.
local MemoryWrapper = {}
MemoryWrapper.__index = MemoryWrapper

--- Create a new memory wrapper.
---@param data? string Initial buffer data (for read mode).
---@param mode string The mode ("rb" = read, "wb" = write).
---@return MemoryWrapper wrapper The memory wrapper instance.
local function memory_open(data, mode)
	return setmetatable({ _buffer = data or "", _pos = 1, _mode = mode }, MemoryWrapper)
end

--- Read unsigned short (2 bytes, little-endian).
---@return integer? value The value, or nil on error.
function MemoryWrapper:read_ushort()
	if self._mode ~= "rb" then return nil end
	local data = self:read(2)
	if not data or #data < 2 then return end
	local b1, b2 = string_byte(data, 1, 2)
	return b1 + (b2 * 256)
end

--- Read unsigned long (4 bytes, little-endian).
---@return integer? value The value, or nil on error.
function MemoryWrapper:read_ulong()
	if self._mode ~= "rb" then return nil end
	local data = self:read(4)
	if not data or #data < 4 then return end
	local b1, b2, b3, b4 = string_byte(data, 1, 4)
	return b1 + (b2 * 256) + (b3 * 65536) + (b4 * 16777216)
end

--- Read n bytes from the buffer.
---@param n integer Number of bytes to read.
---@return string? data The data, or nil on error.
function MemoryWrapper:read(n)
	if self._mode ~= "rb" then return nil end
	if self._pos + n - 1 > #self._buffer then return nil end
	local data = string_sub(self._buffer, self._pos, self._pos + n - 1)
	self._pos = self._pos + n
	return data
end

--- Write data to the buffer.
---@param data string The data to write.
---@return boolean? success True on success, nil on error.
function MemoryWrapper:write(data)
	if self._mode ~= "wb" then return nil end
	local before = string_sub(self._buffer, 1, self._pos - 1)
	local after = string_sub(self._buffer, self._pos + #data)
	self._buffer = before .. data .. after
	self._pos = self._pos + #data
	return true
end

--- Check if a file object is a MemoryWrapper.
---@param f table|FileWrapper|MemoryWrapper The file object to check.
---@return boolean is_memory True if it's a MemoryWrapper.
local function is_memory_wrapper(f)
	return getmetatable(f) == MemoryWrapper
end

--- Seek to position (always absolute from start).
---@param pos integer The position to seek to.
---@return boolean? success True on success, nil on error.
function MemoryWrapper:seek(pos)
	if pos < 1 or pos > #self._buffer + 1 then return nil end
	self._pos = pos
	return true
end

--- Get current position in the buffer.
---@return integer position The current position.
function MemoryWrapper:tell()
	return self._pos
end

--- Get buffer size.
---@return integer size The buffer size in bytes.
function MemoryWrapper:size()
	return #self._buffer
end

--- Skip n bytes.
---@param n integer Number of bytes to skip.
---@return boolean? success True on success, nil on error.
function MemoryWrapper:skip(n)
	return self:seek(self._pos + n)
end

--- Close the buffer (no-op for memory).
---@return boolean success Always returns true.
function MemoryWrapper:close()
	return true
end

--- Get the buffer contents.
---@return string data The buffer contents.
function MemoryWrapper:get_buffer()
	return self._buffer
end

-- Localized file methods for fast dispatch
local F_Read = FileWrapper.read
local F_Write = FileWrapper.write
local F_Seek = FileWrapper.seek
local F_Size = FileWrapper.size
local F_Close = FileWrapper.close
local F_ReadUShort = FileWrapper.read_ushort
local F_ReadULong = FileWrapper.read_ulong
local F_Skip = FileWrapper.skip
local F_Tell = FileWrapper.tell

--- Open file wrapper.
---@param path string The file path.
---@param mode string The mode ("rb" = read binary, "wb" = write binary).
---@return FileWrapper? wrapper The file wrapper, or nil on error.
---@return string? err Error message if failed.
local function _file_open(path, mode)
	if not _io_open then return nil, "File I/O not available" end
	local f, err = _io_open(path, mode)
	if not f then return nil, err end
	return setmetatable({ _file = f }, FileWrapper)
end

--- Set custom file open function for modular usage.<br>
--- Allows complete control over file opening logic for custom backends.<br>
--- The custom function should accept (path, mode) and return a FileWrapper or `nil, error message`.
---@param open_fn fun(path: string, mode: string): (FileWrapper?, string?) The custom file open function.
function Zip.set_file_open(open_fn)
	_file_open = open_fn
end

--- Set custom IO open function for modular usage.<br>
--- Allows using custom IO backends when standard io library is unavailable.<br>
--- The custom function should accept (path, mode) and return a file handle or `nil, error message`.
---@param open_fn fun(path: string, mode: string): (FileWrapper?, string?) The custom IO open function.
function Zip.set_io_open(open_fn)
	_io_open = open_fn
end

--- Set custom FileWrapper class for modular usage.<br>
--- Allows using custom file handle implementations with different backends.<br>
--- The custom FileWrapper should implement the same interface as the default FileWrapper.
---@param wrapper_class FileWrapper The custom FileWrapper class/metatable.
function Zip.set_file_wrapper(wrapper_class)
	FileWrapper = wrapper_class
	-- Update localized file methods to use new wrapper
	F_Read = FileWrapper.read
	F_Write = FileWrapper.write
	F_Seek = FileWrapper.seek
	F_Size = FileWrapper.size
	F_Close = FileWrapper.close
	F_ReadUShort = FileWrapper.read_ushort
	F_ReadULong = FileWrapper.read_ulong
	F_Skip = FileWrapper.skip
	F_Tell = FileWrapper.tell
end

--- Reset IO handlers to default (auto-detect io library).
function Zip.reset_io_handlers()
	_io_open = io and io.open or (file and file.open or (File or false))
end

--- CRC32 table generation using bit ops.
---@return table crc_table The CRC32 lookup table.
local function make_crc_table()
	local t = {}
	for i = 0, 255 do
		local c = i
		for _ = 1, 8 do
			if bit_band(c, 1) ~= 0 then
				-- c = 0xEDB88320 ~ (c >> 1)
				c = bit_bxor(0xEDB88320, bit_rshift(c, 1))
			else
				c = bit_rshift(c, 1)
			end
		end
		t[i] = bit_band(c, U32)
	end
	return t
end
local crc_table = make_crc_table()

--- Incremental CRC32 update using bit ops (returns final-style CRC).
---@param prev_final? integer Previous CRC value, or nil for initial.
---@param chunk string The data chunk to process.
---@return integer crc The updated CRC value.
local function crc32_update(prev_final, chunk)
	local crc
	if not prev_final then
		crc = 0xFFFFFFFF
	else
		crc = bit_bxor(prev_final, 0xFFFFFFFF)
	end
	for i = 1, #chunk do
		local b = string_byte(chunk, i)
		local idx = bit_band(bit_bxor(crc, b), 0xFF)
		crc = bit_bxor(bit_rshift(crc, 8), crc_table[idx])
	end
	return bit_band(bit_bxor(crc, 0xFFFFFFFF), U32)
end

--- Pack unsigned 16-bit integer to little-endian string.
---@param n integer The value to pack.
---@return string packed The packed 2-byte string.
local function pack_u16(n)
	n = bit_band(n, U16)
	return string_char(bit_band(n, 0xFF), bit_band(bit_rshift(n, 8), 0xFF))
end

--- Pack unsigned 32-bit integer to little-endian string.
---@param n integer The value to pack.
---@return string packed The packed 4-byte string.
local function pack_u32(n)
	n = bit_band(n, U32)
	return string_char(
		bit_band(n, 0xFF),
		bit_band(bit_rshift(n, 8), 0xFF),
		bit_band(bit_rshift(n, 16), 0xFF),
		bit_band(bit_rshift(n, 24), 0xFF)
	)
end

--- Find EOCD in tail using forward `string.find` loop.
---@param tail string The tail data to search.
---@return integer? position The position of EOCD, or nil if not found.
local function find_eocd_in_tail(tail)
	local last
	local start = 1
	while true do
		local s = string_find(tail, EOCD_SIG, start, true)
		if not s then break end
		last = s
		start = s + 1
	end
	return last
end

--- Streaming writer.
---@class Writer
---@field _file FileWrapper The file wrapper handle.
---@field _entries table Array of entry metadata.
---@field _offset integer Current write offset.
---@field _closed boolean Whether the writer is closed.
---@field _created_dirs? table Set of created directory paths.
local Writer = {}
Writer.__index = Writer

--- Internal helper: write a directory LFH and record it immediately.
---@param self Writer The writer instance.
---@param dirname string The directory name (must end with '/').
---@return boolean success True on success.
local function writer_write_dir(self, dirname)
	-- dirname must end with '/'
	if not string_match(dirname, "/$") then dirname = dirname .. "/" end
	if self._created_dirs and self._created_dirs[dirname] then return true end

	local lfh_offset = self._offset
	local lfh = {
		LFH_SIG,
		pack_u16(20), -- version needed
		pack_u16(0), -- gp flags (no data descriptor)
		pack_u16(0), -- method (stored)
		pack_u32(0), -- modtime/date
		pack_u32(0), -- crc32
		pack_u32(0), -- comp size
		pack_u32(0), -- uncomp size
		pack_u16(#dirname),
		pack_u16(0),
		dirname
	}
	local lfh_str = table_concat(lfh)
	self._file:write(lfh_str)
	self._offset = self._offset + #lfh_str

	-- Record central-directory metadata for the directory entry now
	self._entries[#self._entries + 1] = {
		name = dirname,
		method = 0,
		crc32 = 0,
		comp_size = 0,
		size = 0,
		lfh_offset = lfh_offset,
		_is_dir = true
	}

	self._created_dirs = self._created_dirs or {}
	self._created_dirs[dirname] = true
	return true
end

--- Add an entry to the writer (streaming). Supports auto-creating parent directories.
---@param name? string The entry name (path within zip).
---@param method? integer The compression method (0 = stored, 8 = deflate).
---@param opts? { overwrite?: boolean } Optional options.
---@return table? entry The entry object, or nil on error.
---@return string? err Error message if failed.
function Writer:add(name, method, opts)
	if self._closed then return nil, "writer already closed" end
	if name == nil then name = "" elseif type(name) ~= "string" then name = tostring(name) end
	if string_find(name, "\0", 1, true) then return nil, "entry name contains NUL byte" end
	if #name > 65535 then return nil, "entry name too long (>65535 bytes)" end

	opts = opts or {}
	method = method or 0
	if method ~= 0 and method ~= 8 then return nil, "unsupported compression method (only 0 and 8 allowed)" end

	-- If this is a directory entry (trailing slash), create it directly and return a closed entry
	if string_sub(name, -1) == "/" then
		-- If overwrite requested, remove any existing entry with same name
		if opts.overwrite then
			for i = 1, #self._entries do
				local e = self._entries[i]
				if e and e.name == name and not e._removed then e._removed = true end
			end
			self._created_dirs = self._created_dirs or {}
			self._created_dirs[name] = nil
		else
			-- If already created, return success (idempotent)
			if self._created_dirs and self._created_dirs[name] then
				return {
					_writer = self,
					_file = self._file,
					_name = name,
					_method = 0,
					_lfh_offset = nil,
					_crc_final = 0,
					_comp_size = 0,
					_size_uncomp = 0,
					_closed = true,
					write = function() return nil, "directory entry is not writable" end,
					close = function() return true end
				}
			end
		end

		-- write directory LFH and record it
		local ok, err = writer_write_dir(self, name)
		if not ok then return nil, err end
		-- return a dummy closed entry
		return {
			_writer = self,
			_file = self._file,
			_name = name,
			_method = 0,
			_lfh_offset = nil,
			_crc_final = 0,
			_comp_size = 0,
			_size_uncomp = 0,
			_closed = true,
			write = function() return nil, "directory entry is not writable" end,
			close = function() return true end
		}
	end

	-- Ensure parent directories exist (auto-create)
	do
		local prefix = ""
		for part in string_gmatch(name, "([^/]+)") do
			prefix = prefix .. part .. "/"
			-- stop before the final part if name does not end with '/'
			if prefix ~= name .. "/" then
				self._created_dirs = self._created_dirs or {}
				if not self._created_dirs[prefix] then
					local ok, err = writer_write_dir(self, prefix)
					if not ok then return nil, err end
				end
			end
		end
	end

	-- Overwrite handling: if an entry with same name exists
	if opts.overwrite then
		for i = 1, #self._entries do
			local e = self._entries[i]
			if e and e.name == name and not e._removed then
				e._removed = true
			end
		end
	else
		for i = 1, #self._entries do
			local e = self._entries[i]
			if e and e.name == name and not e._removed then
				return nil, string_format("entry already exists: %s", name)
			end
		end
	end

	-- Prepare LFH offset and write LFH with data-descriptor GP flag (0x08) for streaming entries
	local lfh_offset = self._offset
	local gp_flag = 8 -- we use data descriptor for streaming entries
	local lfh = {
		LFH_SIG,
		pack_u16(20),
		pack_u16(gp_flag), -- general purpose bit flag (bit 3 set for data descriptor)
		pack_u16(method),
		pack_u32(0), -- modtime/date
		pack_u32(0), -- crc placeholder
		pack_u32(0), -- comp size placeholder
		pack_u32(0), -- uncomp size placeholder
		pack_u16(#name),
		pack_u16(0),
		name
	}
	local lfh_str = table_concat(lfh)
	self._file:write(lfh_str)
	self._offset = self._offset + #lfh_str

	-- Entry state
	local entry = {
		_writer = self,
		_file = self._file,
		_name = name,
		_method = method,
		_lfh_offset = lfh_offset,
		_crc_final = nil,
		_comp_size = 0,
		_size_uncomp = 0,
		_closed = false
	}

	function entry:write(chunk)
		if self._closed then return nil, "entry already closed" end
		if type(chunk) ~= "string" then return nil, "chunk must be a string" end

		self._comp_size = self._comp_size + #chunk
		if self._method == 0 then self._size_uncomp = self._size_uncomp + #chunk end

		if not self._crc_final then
			self._crc_final = crc32_update(nil, chunk)
		else
			self._crc_final = crc32_update(self._crc_final, chunk)
		end

		self._file:write(chunk)
		self._writer._offset = self._writer._offset + #chunk
		return true
	end

	function entry:set_uncompressed_size(n)
		if self._closed then return nil, "entry already closed" end
		if type(n) ~= "number" or n < 0 or n >= 4294967296 then
			return nil, "uncompressed size must be a 32-bit number"
		end
		self._size_uncomp = n
		return true
	end

	-- entry:close with LFH patching (use same open File object)
	function entry:close()
		if self._closed then return nil, "entry already closed" end
		self._closed = true

		-- Ensure CRC exists
		if not self._crc_final then
			self._crc_final = crc32_update(nil, "")
		end

		-- For stored method, uncompressed size equals comp_size
		if self._method == 0 then
			self._size_uncomp = self._comp_size
		end

		-- Validate sizes fit 32-bit
		if self._comp_size >= 4294967296 or self._size_uncomp >= 4294967296 then
			return nil, "entry sizes exceed 32-bit; ZIP64 not supported by this writer"
		end

		-- Write data descriptor (signature + crc + comp_size + size)
		local dd = {
			DATA_DESC_SIG,
			pack_u32(self._crc_final),
			pack_u32(self._comp_size),
			pack_u32(self._size_uncomp)
		}
		local dd_str = table_concat(dd)
		self._file:write(dd_str)
		self._writer._offset = self._writer._offset + #dd_str

		-- Patch LFH in-place using the same open File object
		-- LFH layout offsets (from LFH start):
		-- 0..3   signature
		-- 4..5   version needed
		-- 6..7   gp_flags
		-- 8..9   method
		-- 10..11 mod time
		-- 12..13 mod date
		-- 14..17 crc32
		-- 18..21 compressed size
		-- 22..25 uncompressed size
		local f = self._file
		local curpos = f:tell() -- remember current write position
		local is_mem = is_memory_wrapper(f)
		local offset_adjust = is_mem and 1 or 0

		-- Write CRC and sizes at LFH offsets
		-- Seek to CRC position (lfh_offset + 14)
		f:seek(self._lfh_offset + 14 + offset_adjust)
		f:write(pack_u32(self._crc_final))
		f:write(pack_u32(self._comp_size))
		f:write(pack_u32(self._size_uncomp))

		-- Clear GP flag in LFH (set to 0) at offset (lfh_offset + 6)
		f:seek(self._lfh_offset + 6 + offset_adjust)
		f:write(pack_u16(0))

		-- Restore file position to continue writing (seek to previous end)
		f:seek(curpos)

		-- Mark entry as patched so central directory uses gp_flag = 0
		self._patched = true

		-- Record central directory metadata for this file
		self._writer._entries[#self._writer._entries + 1] = {
			name = self._name,
			method = self._method,
			crc32 = self._crc_final,
			comp_size = self._comp_size,
			size = self._size_uncomp,
			lfh_offset = self._lfh_offset,
			_patched = true
		}

		return true
	end

	return entry
end

--- Close the writer and finalize the ZIP file.<br>
--- Writes central directory and EOCD records.
---@return boolean? success True on success, nil on error.
---@return string? err Error message if failed.
function Writer:close()
	if self._closed then return nil, "writer already closed" end
	self._closed = true

	-- use numeric loop and respect e._patched to set gp flag
	local cdfh_parts = {}
	local cd_offset = self._offset

	for i = 1, #self._entries do
		local e = self._entries[i]
		if e and not e._removed then
			local name = e.name or ""
			-- choose gp flag: 0 if LFH was patched, otherwise 8 (data descriptor)
			local gp_flag = e._patched and 0 or 8

			local cdfh = {
				CDFH_SIG,
				pack_u16(20), -- version made by
				pack_u16(20), -- version needed
				pack_u16(gp_flag), -- general purpose bit flag
				pack_u16(e.method or 0), -- compression method
				pack_u16(0), -- mod time
				pack_u16(0), -- mod date
				pack_u32(e.crc32 or 0),
				pack_u32(e.comp_size or 0),
				pack_u32(e.size or 0),
				pack_u16(#name),
				pack_u16(0), -- extra len
				pack_u16(0), -- comment len
				pack_u16(0), -- disk start
				pack_u16(0), -- internal attr
				pack_u32(0), -- external attr
				pack_u32(e.lfh_offset or 0),
				name
			}
			cdfh_parts[#cdfh_parts + 1] = table_concat(cdfh)
		end
	end

	local central_dir = table_concat(cdfh_parts)
	local cd_size = #central_dir

	-- write central_dir and EOCD as before
	self._file:write(central_dir)
	self._offset = self._offset + cd_size

	local eocd = {
		EOCD_SIG,
		pack_u16(0),
		pack_u16(0),
		pack_u16(#self._entries), -- you may want to compute actual count if needed
		pack_u16(#self._entries),
		pack_u32(cd_size),
		pack_u32(cd_offset),
		pack_u16(0)
	}
	self._file:write(table_concat(eocd))

	self._file:close()
	return true
end

--- Create a new ZIP writer.
---@param path string The output file path.
---@return Writer? writer The writer instance, or nil on error.
---@return string? err Error message if failed.
function Zip.new_writer(path)
	if type(path) ~= "string" then return nil, "path must be string" end
	local f, err = _file_open(path, "wb")
	if not f then return nil, "file.Open failed: " .. tostring(err) end
	return setmetatable({ _file = f, _entries = {}, _closed = false, _offset = 0 }, Writer)
end

----------------------------------------------------------------------
-- Reader
----------------------------------------------------------------------

--- Read a ZIP file and return metadata about its contents.
---@param path string The path to the ZIP file.
---@return table? metadata Table with `{ files = {}, cd_offset, cd_size }`, or nil on error.
---@return string? err Error message if failed.
function Zip.read(path)
	if type(path) ~= "string" then return nil, "path must be string" end
	local f, err = _file_open(path, "rb")
	if not f then return nil, "file.Open failed: " .. tostring(err) end

	local size = F_Size(f)
	if size < 22 then
		F_Close(f)
		return nil, "file too small"
	end

	local tail_read = math_min(size, 65536 + 22)
	F_Seek(f, size - tail_read)
	local tail = F_Read(f, tail_read)
	local eocd_pos = find_eocd_in_tail(tail)
	if not eocd_pos then
		F_Close(f)
		return nil, "EOCD not found"
	end

	local eocd_abs = (size - tail_read) + (eocd_pos - 1)
	F_Seek(f, eocd_abs)
	local sig = F_Read(f, 4)
	if sig ~= EOCD_SIG then
		F_Close(f)
		return nil, "EOCD mismatch"
	end

	F_ReadUShort(f) -- disk
	F_ReadUShort(f) -- cd disk
	local entries_on_disk = F_ReadUShort(f)
	local total_entries = F_ReadUShort(f)
	local cd_size = F_ReadULong(f)
	local cd_offset = F_ReadULong(f)
	local comment_len = F_ReadUShort(f)
	if comment_len > 0 then F_Skip(f, comment_len) end

	if cd_offset + cd_size > size then
		F_Close(f)
		return nil, "CD out of bounds"
	end

	local files = {}
	F_Seek(f, cd_offset)
	for i = 1, total_entries do
		local cdfh = F_Read(f, 4)
		if cdfh ~= CDFH_SIG then
			F_Close(f)
			return nil, "CDFH mismatch"
		end

		-- FIX: skip 4 bytes (version_made + version_needed), not 6
		F_Skip(f, 4)
		local gp = F_ReadUShort(f)
		local method = F_ReadUShort(f)
		F_Skip(f, 4) -- modtime/date
		local crc = F_ReadULong(f)
		local comp_size = F_ReadULong(f)
		local uncomp_size = F_ReadULong(f)
		local name_len = F_ReadUShort(f)
		local extra_len = F_ReadUShort(f)
		local comment_len2 = F_ReadUShort(f)
		F_Skip(f, 2) -- disk start
		F_Skip(f, 2) -- internal attr
		F_Skip(f, 4) -- external attr
		local lfh_rel = F_ReadULong(f)

		local name = ""
		if name_len > 0 then name = F_Read(f, name_len) end
		if extra_len > 0 then F_Skip(f, extra_len) end
		if comment_len2 > 0 then F_Skip(f, comment_len2) end

		files[#files + 1] = {
			name = name,
			method = method,
			crc32 = crc,
			comp_size = comp_size,
			size = uncomp_size,
			lfh_offset = lfh_rel
		}
	end

	F_Close(f)
	return { files = files, cd_offset = cd_offset, cd_size = cd_size }
end

--- Read data from a specific entry in a ZIP file.
---@param path string The path to the ZIP file.
---@param entry table The entry table from `Zip.read` containing lfh_offset, comp_size, etc.
---@return string? data The file data or nil on error.
---@return string? err Error message if failed.
function Zip.read_data(path, entry)
	if type(path) ~= "string" then return nil, "path must be string" end
	if type(entry) ~= "table" then return nil, "entry must be table" end

	local f, err = _file_open(path, "rb")
	if not f then return nil, "file.Open failed: " .. tostring(err) end

	local size = F_Size(f)
	-- basic bounds check for lfh_offset
	if entry.lfh_offset < 0 or entry.lfh_offset + 4 > size then
		F_Close(f)
		return nil, "LFH offset out of bounds"
	end

	-- Seek to LFH and parse header
	F_Seek(f, entry.lfh_offset)
	local sig = F_Read(f, 4)
	if sig ~= "PK\003\004" then
		F_Close(f)
		return nil, "LFH missing"
	end

	-- Skip version_needed (2), gp_flags (2), method (2), modtime (2), moddate (2)
	F_Skip(f, 2 + 2 + 2 + 2 + 2)

	local l_crc = F_ReadULong(f)
	local l_comp = F_ReadULong(f)
	local l_uncomp = F_ReadULong(f)
	local name_len = F_ReadUShort(f)
	local extra_len = F_ReadUShort(f)

	-- compute data start
	F_Skip(f, name_len + extra_len)
	local data_start = F_Tell(f)

	-- If LFH compressed size is zero (data-descriptor case), fall back to central-dir value
	local comp_size = l_comp
	if comp_size == 0 and entry.comp_size and entry.comp_size > 0 then
		comp_size = entry.comp_size
	end

	-- If still zero, nothing to read
	if comp_size == 0 then
		F_Close(f)
		return "", nil
	end

	-- Bounds check before reading
	if data_start + comp_size > size then
		F_Close(f)
		return nil, "compressed data out of bounds"
	end

	F_Seek(f, data_start)
	local data = F_Read(f, comp_size)
	F_Close(f)
	return data
end

--- Write a ZIP file from a flat table of files.<br>
--- Files table keys are paths, values are content strings.<br>
--- Use value = true for directory entries (path must end with '/').
---@param zip_path string The output ZIP file path.
---@param files table The files table: `{ ["path/to/file.txt"] = "content", ["dir/"] = true }`
---@param opts? { overwrite?: boolean } Optional options.
---@return table? created Array of created paths or nil on error.
---@return string? err Error message if failed.
function Zip.write_from_table(zip_path, files, opts)
	if type(zip_path) ~= "string" then return error("zip_path must be string") end
	if type(files) ~= "table" then return error("files must be table") end
	opts = opts or {}

	local writer, err = Zip.new_writer(zip_path)
	if not writer then return nil, "new_writer failed: " .. tostring(err) end

	local created = {}
	local keys = {}
	for k in next, files do keys[#keys + 1] = k end
	table.sort(keys) -- deterministic order

	for i = 1, #keys do
		local path = keys[i]
		local val = files[path]

		-- Normalize path
		if type(path) ~= "string" then
			writer:close()
			return nil, string_format("invalid path key: %s", tostring(path))
		end

		-- Directory marker: value == true OR path ends with '/'
		local is_dir = (val == true) or (string_sub(path, -1) == "/")

		-- If value == true but path doesn't end with '/', append '/'
		if val == true and string_sub(path, -1) ~= "/" then
			path = path .. "/"
			is_dir = true
		end

		-- For files: ensure content is a string (allow empty string)
		local content
		if not is_dir then
			if type(val) == "string" then
				content = val
			elseif val == nil then
				-- absent value can't happen in literal table, but handle defensively
				content = ""
			else
				writer:close()
				return nil, string_format("invalid value for file %s: expected string", path)
			end
		end

		-- Add entry (writer:add auto-creates parent dirs)
		local entry, aerr = writer:add(path, 0, { overwrite = opts.overwrite })
		if not entry then
			writer:close()
			return nil, string_format("add failed for %s: %s", path, tostring(aerr))
		end

		if not is_dir then
			local ok, werr = entry:write(content)
			if not ok then
				writer:close()
				return nil, string_format("write failed for %s: %s", path, tostring(werr))
			end
			local ok2, cerr = entry:close()
			if not ok2 then
				writer:close()
				return nil, string_format("close failed for %s: %s", path, tostring(cerr))
			end
		else
			-- directory entry returned as closed dummy; nothing to write
		end

		created[#created + 1] = path
	end

	local ok, cerr = writer:close()
	if not ok then return nil, "writer:close failed: " .. tostring(cerr) end
	return created
end

--- Write a ZIP file from a nested Lua table.
---@param zip_path string The output ZIP file path.
---@param tree table The nested tree table: `{ ["dir"] = { ["file.txt"] = "data" }, ["root.txt"] = "hi" }`
---@param opts? { overwrite?: boolean } Optional options.
---@return boolean? success True on success, nil on error.
---@return string? err Error message if failed.
function Zip.write_from_nested_table(zip_path, tree, opts)
	if type(zip_path) ~= "string" then return nil, "zip_path must be a string" end
	if type(tree) ~= "table" then return nil, "tree must be a table" end
	opts = opts or {}

	local writer, err = Zip.new_writer(zip_path)
	if not writer then return nil, "new_writer failed: " .. tostring(err) end

	local function walk(prefix, node)
		-- prefix always ends with "" or "some/path/"
		for name, val in next, node do
			if type(name) ~= "string" then
				writer:close()
				return nil, string_format("invalid key type in tree: %s", tostring(name))
			end

			local path = prefix .. name

			if type(val) == "table" then
				-- directory: ensure trailing slash
				if string_sub(path, -1) ~= "/" then path = path .. "/" end

				-- Add directory entry (writer:add will be idempotent for existing dirs)
				local dir_entry, derr = writer:add(path, 0, { overwrite = opts.overwrite })
				if not dir_entry then
					return nil, string_format("add dir failed: %s -> %s", path, tostring(derr))
				end
				-- dir_entry is a closed dummy; ensure close called (safe even if dummy)
				local ok, cerr = dir_entry:close()
				if not ok then
					writer:close()
					return nil, string_format("close dir failed: %s -> %s", path, tostring(cerr))
				end

				-- Recurse into directory
				local ok2, rerr = walk(path, val)
				if not ok2 then return nil, rerr end
			elseif type(val) == "string" then
				-- file: add and write content (binary-safe)
				local file_entry, ferr = writer:add(path, 0, { overwrite = opts.overwrite })
				if not file_entry then
					writer:close()
					return nil, string_format("add file failed: %s -> %s", path, tostring(ferr))
				end

				local okw, werr = file_entry:write(val)
				if not okw then
					writer:close()
					return nil, string_format("write failed: %s -> %s", path, tostring(werr))
				end

				local okc, cerr = file_entry:close()
				if not okc then
					writer:close()
					return nil, string_format("close file failed: %s -> %s", path, tostring(cerr))
				end
			else
				writer:close()
				return nil, string_format("invalid value for path %s: expected table or string, got %s", path, type(val))
			end
		end
		return true
	end

	local ok, rerr = walk("", tree)
	if not ok then return nil, rerr end

	local closed, cerr = writer:close()
	if not closed then return nil, "writer:close failed: " .. tostring(cerr) end
	return true
end

--- Read a ZIP file into a nested Lua table.
---@param zip_path string.ProgressBarOptions The path to the ZIP file.
---@param opts? { max_file_size?: number, deterministic?: boolean } Optional options.
---@return table? tree The nested table or nil on error.
---@return string? err Error message if failed.
function Zip.read_to_nested_table(zip_path, opts)
	if type(zip_path) ~= "string" then return nil, "zip_path must be a string" end
	opts = opts or {}
	local max_file_size = opts.max_file_size
	local deterministic = opts.deterministic -- if true, iterate entries in sorted order

	local meta, err = Zip.read(zip_path)
	if not meta then return nil, "Zip.read failed: " .. tostring(err) end

	local tree = {}

	-- Ensure parent tables exist and return (parent_table, final_key)
	-- parts: array of path components (no trailing slash)
	local function ensure_parent_for_parts(root, parts)
		local cur = root
		local n = #parts
		-- walk up to the parent of the final component (i = 1 .. n-1)
		for i = 1, (n - 1) do
			local p = parts[i]
			if p ~= "" then
				if cur[p] == nil then
					cur[p] = {}
				elseif type(cur[p]) ~= "table" then
					-- conflict: a file exists where a directory is needed; replace with directory
					cur[p] = {}
				end
				cur = cur[p]
			end
		end
		local final_key = parts[n]
		return cur, final_key
	end

	-- Build an index of entries to iterate deterministically if requested
	local entries = meta.files
	local order = {}
	if deterministic then
		for i = 1, #entries do
			local e = entries[i]
			if e and e.name then order[#order + 1] = e.name end
		end
		table.sort(order)
	end

	local function process_entry(e)
		if not e or type(e.name) ~= "string" then return true end
		local name = e.name
		if string_sub(name, 1, 2) == "./" then name = string_sub(name, 3) end

		local is_dir = (string_sub(name, -1) == "/")
		-- split into parts (no empty components)
		local parts = {}
		for part in string_gmatch(name, "[^/]+") do parts[#parts + 1] = part end
		if #parts == 0 then return true end

		if is_dir then
			-- directory: ensure parent exists, then set parent[final_key] = {} (if not already)
			local parent, key = ensure_parent_for_parts(tree, parts)
			if parent[key] == nil or type(parent[key]) ~= "table" then
				parent[key] = {}
			end
		else
			-- file: ensure parent exists, then read data and set parent[final_key] = data
			local parent, key = ensure_parent_for_parts(tree, parts)

			-- optional size guard
			if max_file_size then
				local size_check = e.comp_size or e.size or 0
				if size_check > max_file_size then
					return nil, string_format("file %s exceeds max_file_size (%d > %d)", name, size_check, max_file_size)
				end
			end

			local data, rerr = Zip.read_data(zip_path, e)
			if data == nil and rerr then
				return nil, string_format("failed to read %s: %s", name, tostring(rerr))
			end
			parent[key] = data or ""
		end

		return true
	end

	if deterministic then
		for i = 1, #order do
			local nm = order[i]
			-- find the entry by name (meta.files is small; if large, build a map first)
			local found
			for j = 1, #meta.files do
				if meta.files[j] and meta.files[j].name == nm then
					found = meta.files[j]
					break
				end
			end
			if found then
				local ok, rerr = process_entry(found)
				if not ok then return nil, rerr end
			end
		end
	else
		for i = 1, #meta.files do
			local e = meta.files[i]
			local ok, rerr = process_entry(e)
			if not ok then return nil, rerr end
		end
	end

	return tree
end

----------------------------------------------------------------------
-- In-memory ZIP API
----------------------------------------------------------------------

--- Read a ZIP from a string buffer (in-memory).
---@param zip_data string The ZIP file data as a string.
---@return table? metadata Table with `{ files = {}, cd_offset, cd_size }`, or nil on error.
---@return string? err Error message if failed.
function Zip.read_from_string(zip_data)
	if type(zip_data) ~= "string" then return nil, "zip_data must be string" end

	local f = memory_open(zip_data, "rb")
	local size = f:size()
	if size < 22 then
		return nil, "data too small"
	end

	local tail_read = math_min(size, 65536 + 22)
	f:seek(size - tail_read + 1)
	local tail = f:read(tail_read)
	local eocd_pos = find_eocd_in_tail(tail)
	if not eocd_pos then
		return nil, "EOCD not found"
	end

	local eocd_abs = (size - tail_read) + (eocd_pos - 1)
	f:seek(eocd_abs + 1)
	local sig = f:read(4)
	if sig ~= EOCD_SIG then
		return nil, "EOCD mismatch"
	end

	f:read_ushort() -- disk
	f:read_ushort() -- cd disk
	local entries_on_disk = f:read_ushort()
	local total_entries = f:read_ushort()
	local cd_size = f:read_ulong()
	local cd_offset = f:read_ulong()
	local comment_len = f:read_ushort()
	if comment_len > 0 then f:skip(comment_len) end

	if cd_offset + 1 + cd_size > size then
		return nil, "CD out of bounds"
	end

	local files = {}
	f:seek(cd_offset + 1)
	for i = 1, total_entries do
		local cdfh = f:read(4)
		if cdfh ~= CDFH_SIG then
			return nil, "CDFH mismatch"
		end

		f:skip(4)
		local gp = f:read_ushort()
		local method = f:read_ushort()
		f:skip(4)
		local crc = f:read_ulong()
		local comp_size = f:read_ulong()
		local uncomp_size = f:read_ulong()
		local name_len = f:read_ushort()
		local extra_len = f:read_ushort()
		local comment_len2 = f:read_ushort()
		f:skip(2)
		f:skip(2)
		f:skip(4)
		local lfh_rel = f:read_ulong()

		local name = ""
		if name_len > 0 then name = f:read(name_len) end
		if extra_len > 0 then f:skip(extra_len) end
		if comment_len2 > 0 then f:skip(comment_len2) end

		files[#files + 1] = {
			name = name,
			method = method,
			crc32 = crc,
			comp_size = comp_size,
			size = uncomp_size,
			lfh_offset = lfh_rel
		}
	end

	return { files = files, cd_offset = cd_offset, cd_size = cd_size }
end

--- Read entry data from a ZIP string buffer (in-memory).
---@param zip_data string The ZIP file data as a string.
---@param entry table The entry table from `Zip.read_from_string` containing lfh_offset, comp_size, etc.
---@return string? data The file data or nil on error.
---@return string? err Error message if failed.
function Zip.read_data_from_string(zip_data, entry)
	if type(zip_data) ~= "string" then return nil, "zip_data must be string" end
	if type(entry) ~= "table" then return nil, "entry must be table" end

	local f = memory_open(zip_data, "rb")
	local size = f:size()

	if entry.lfh_offset < 0 or entry.lfh_offset + 1 + 4 > size then
		return nil, "LFH offset out of bounds"
	end

	f:seek(entry.lfh_offset + 1)
	local sig = f:read(4)
	if sig ~= "PK\003\004" then
		return nil, "LFH missing"
	end

	f:skip(2 + 2 + 2 + 2 + 2)

	local l_crc = f:read_ulong()
	local l_comp = f:read_ulong()
	local l_uncomp = f:read_ulong()
	local name_len = f:read_ushort()
	local extra_len = f:read_ushort()

	f:skip(name_len + extra_len)
	local data_start = f:tell()

	local comp_size = l_comp
	if comp_size == 0 and entry.comp_size and entry.comp_size > 0 then
		comp_size = entry.comp_size
	end

	if comp_size == 0 then
		return "", nil
	end

	if data_start + comp_size - 1 > size then
		return nil, "compressed data out of bounds"
	end

	f:seek(data_start)
	local data = f:read(comp_size)
	return data
end

--- Create a new in-memory ZIP writer.
---@return Writer? writer The writer instance, or nil on error.
---@return string? err Error message if failed.
function Zip.new_memory_writer()
	local f = memory_open("", "wb")
	return setmetatable({ _file = f, _entries = {}, _closed = false, _offset = 0 }, Writer)
end

--- Write a ZIP to a string buffer from a flat table of files.
---@param files table The files table: `{ ["path/to/file.txt"] = "content", ["dir/"] = true }`
---@param opts? { overwrite?: boolean } Optional options.
---@return string? zip_data The ZIP data as a string or nil on error.
---@return string? err Error message if failed.
function Zip.write_to_string(files, opts)
	if type(files) ~= "table" then return nil, "files must be table" end
	opts = opts or {}

	local writer, err = Zip.new_memory_writer()
	if not writer then return nil, "new_memory_writer failed: " .. tostring(err) end

	local created = {}
	local keys = {}
	for k in next, files do keys[#keys + 1] = k end
	table.sort(keys)

	for i = 1, #keys do
		local path = keys[i]
		local val = files[path]

		if type(path) ~= "string" then
			writer:close()
			return nil, string_format("invalid path key: %s", tostring(path))
		end

		local is_dir = (val == true) or (string_sub(path, -1) == "/")

		if val == true and string_sub(path, -1) ~= "/" then
			path = path .. "/"
			is_dir = true
		end

		local content
		if not is_dir then
			if type(val) == "string" then
				content = val
			elseif val == nil then
				content = ""
			else
				writer:close()
				return nil, string_format("invalid value for file %s: expected string", path)
			end
		end

		local entry, aerr = writer:add(path, 0, { overwrite = opts.overwrite })
		if not entry then
			writer:close()
			return nil, string_format("add failed for %s: %s", path, tostring(aerr))
		end

		if not is_dir then
			local ok, werr = entry:write(content)
			if not ok then
				writer:close()
				return nil, string_format("write failed for %s: %s", path, tostring(werr))
			end
			local ok2, cerr = entry:close()
			if not ok2 then
				writer:close()
				return nil, string_format("close failed for %s: %s", path, tostring(cerr))
			end
		end

		created[#created + 1] = path
	end

	local ok, cerr = writer:close()
	if not ok then return nil, "writer:close failed: " .. tostring(cerr) end

	return writer._file:get_buffer()
end

--- Write a ZIP to a string buffer from a nested Lua table.
---@param tree table The nested tree table: `{ ["dir"] = { ["file.txt"] = "data" }, ["root.txt"] = "hi" }`
---@param opts? { overwrite?: boolean } Optional options.
---@return string? zip_data The ZIP data as a string, or nil on error.
---@return string? err Error message if failed.
function Zip.write_nested_to_string(tree, opts)
	if type(tree) ~= "table" then return nil, "tree must be a table" end
	opts = opts or {}

	local writer, err = Zip.new_memory_writer()
	if not writer then return nil, "new_memory_writer failed: " .. tostring(err) end

	local function walk(prefix, node)
		for name, val in next, node do
			if type(name) ~= "string" then
				writer:close()
				return nil, string_format("invalid key type in tree: %s", tostring(name))
			end

			local path = prefix .. name

			if type(val) == "table" then
				if string_sub(path, -1) ~= "/" then path = path .. "/" end

				local dir_entry, derr = writer:add(path, 0, { overwrite = opts.overwrite })
				if not dir_entry then
					return nil, string_format("add dir failed: %s -> %s", path, tostring(derr))
				end
				local ok, cerr = dir_entry:close()
				if not ok then
					writer:close()
					return nil, string_format("close dir failed: %s -> %s", path, tostring(cerr))
				end

				local ok2, rerr = walk(path, val)
				if not ok2 then return nil, rerr end
			elseif type(val) == "string" then
				local file_entry, ferr = writer:add(path, 0, { overwrite = opts.overwrite })
				if not file_entry then
					writer:close()
					return nil, string_format("add file failed: %s -> %s", path, tostring(ferr))
				end

				local okw, werr = file_entry:write(val)
				if not okw then
					writer:close()
					return nil, string_format("write failed: %s -> %s", path, tostring(werr))
				end

				local okc, cerr = file_entry:close()
				if not okc then
					writer:close()
					return nil, string_format("close file failed: %s -> %s", path, tostring(cerr))
				end
			else
				writer:close()
				return nil, string_format("invalid value for path %s: expected table or string, got %s", path, type(val))
			end
		end
		return true
	end

	local ok, rerr = walk("", tree)
	if not ok then return nil, rerr end

	local closed, cerr = writer:close()
	if not closed then return nil, "writer:close failed: " .. tostring(cerr) end

	return writer._file:get_buffer()
end

--- Read a ZIP from a string buffer into a nested Lua table.
---@param zip_data string The ZIP file data as a string.
---@param opts? { max_file_size?: number, deterministic?: true|false } Optional options.
---@return table? tree The nested table or nil on error.
---@return string? err Error message if failed.
function Zip.read_string_to_nested_table(zip_data, opts)
	if type(zip_data) ~= "string" then return nil, "zip_data must be a string" end
	opts = opts or {}
	local max_file_size = opts.max_file_size
	local deterministic = opts.deterministic

	local meta, err = Zip.read_from_string(zip_data)
	if not meta then return nil, "Zip.read_from_string failed: " .. tostring(err) end

	local tree = {}

	local function ensure_parent_for_parts(root, parts)
		local cur = root
		local n = #parts
		for i = 1, (n - 1) do
			local p = parts[i]
			if p ~= "" then
				if cur[p] == nil then
					cur[p] = {}
				elseif type(cur[p]) ~= "table" then
					cur[p] = {}
				end
				cur = cur[p]
			end
		end
		local final_key = parts[n]
		return cur, final_key
	end

	local entries = meta.files
	local order = {}
	if deterministic then
		for i = 1, #entries do
			local e = entries[i]
			if e and e.name then order[#order + 1] = e.name end
		end
		table.sort(order)
	end

	local function process_entry(e)
		if not e or type(e.name) ~= "string" then return true end
		local name = e.name
		if string_sub(name, 1, 2) == "./" then name = string_sub(name, 3) end

		local is_dir = (string_sub(name, -1) == "/")
		local parts = {}
		for part in string_gmatch(name, "[^/]+") do parts[#parts + 1] = part end
		if #parts == 0 then return true end

		if is_dir then
			local parent, key = ensure_parent_for_parts(tree, parts)
			if parent[key] == nil or type(parent[key]) ~= "table" then
				parent[key] = {}
			end
		else
			local parent, key = ensure_parent_for_parts(tree, parts)

			if max_file_size then
				local size_check = e.comp_size or e.size or 0
				if size_check > max_file_size then
					return nil, string_format("file %s exceeds max_file_size (%d > %d)", name, size_check, max_file_size)
				end
			end

			local data, rerr = Zip.read_data_from_string(zip_data, e)
			if data == nil and rerr then
				return nil, string_format("failed to read %s: %s", name, tostring(rerr))
			end
			parent[key] = data or ""
		end

		return true
	end

	if deterministic then
		for i = 1, #order do
			local nm = order[i]
			local found
			for j = 1, #meta.files do
				if meta.files[j] and meta.files[j].name == nm then
					found = meta.files[j]
					break
				end
			end
			if found then
				local ok, rerr = process_entry(found)
				if not ok then return nil, rerr end
			end
		end
	else
		for i = 1, #meta.files do
			local e = meta.files[i]
			local ok, rerr = process_entry(e)
			if not ok then return nil, rerr end
		end
	end

	return tree
end

--- Pretty-print a nested table (for debugging).
---@param node table The node to print.
---@param prefix? string The prefix for indentation (default: "").
local function dump_tree(node, prefix)
	prefix = prefix or ""
	for k, v in next, node do
		if type(v) == "table" then
			print(prefix .. k .. "/")
			dump_tree(v, prefix .. k .. "/")
		else
			print(prefix .. k .. "  (" .. tostring(#v) .. " bytes)")
		end
	end
end

Zip.dump_tree = dump_tree

--[[ Quick tests
if true then
	print("[zip] test start")
	do
		local writer, err = Zip.new_writer("test_stream.zip")
		if not writer then
			print("new_writer failed:", err)
			return
		end

		local entry, err = writer:add("hello.txt", 0)
		if not entry then
			print("add failed:", err)
			return
		end

		entry:write("Hello standalone Lua!\n")
		entry:write("Bitwise packers and CRC.\n")
		entry:close()

		writer:close()
		print("[zip] wrote test_stream.zip")

		local zip, err = Zip.read("test_stream.zip")
		if not zip then
			print("read failed:", err)
			return
		end
		print("[zip] entries:", #zip.files)
		for i = 1, #zip.files do
			local e = zip.files[i]
			print(string_format("entry %d: %s method=%d comp=%d size=%d lfh=%d", i, e.name, e.method, e.comp_size, e
				.size, e.lfh_offset))
		end

		local data, err = Zip.read_data("test_stream.zip", zip.files[1])
		if not data then
			print("read_data failed:", err)
			return
		end
		print("[zip] first entry data:\n" .. data)
	end

	do
		-- Example table with nested folders and files
		local files = {
			["assets/"] = nil, -- explicit empty directory
			["assets/images/"] = nil, -- nested directory
			["assets/images/logo.txt"] = "Logo text\nLine 2\n",
			["docs/manual/readme.txt"] = "This is the readme.\n",
			["docs/manual/notes.txt"] = "Notes go here.\n",
			["rootfile.txt"] = "Top-level file\n",
		}
		-- Write the archive (overwrite existing entries inside archive if present)
		local created, err = Zip.write_from_table("example_nested.zip", files, { overwrite = true })
		if not created then
			print("Failed to write zip:", err)
		else
			print("Wrote archive example_nested.zip with entries:")
			for i = 1, #created do print(" -", created[i]) end
		end
	end

	do
		local tree = {
			["assets"] = {
				["images"] = {
					["logo.txt"] = "Logo text\nBinary ok: \0\1\2",
				},
				["readme.txt"] = "Assets readme\n"
			},
			["docs"] = {
				["manual"] = {
					["readme.txt"] = "Manual readme\n",
				}
			},
			["rootfile.txt"] = "Top-level file\n",
			["emptydir"] = {} -- empty table becomes an explicit directory "emptydir/"
		}
		local ok, err = Zip.write_from_nested_table("nested_from_table.zip", tree, { overwrite = true })
		if not ok then
			print("Failed to write zip:", err)
		else
			print("Wrote nested_from_table.zip")
		end
	end

	do
		-- Read a zip into a nested table
		local tree, err = Zip.read_to_nested_table("nested_from_table.zip", {
			max_file_size = 10 * 1024 * 1024,
			deterministic = true
		})
		if not tree then
			print("read_to_nested_table failed:", err)
		else
			-- Access a file
			if tree.assets and tree.assets.images and tree.assets.images["logo.txt"] then
				local logo_data = tree.assets.images["logo.txt"]
				print("logo.txt size:", #logo_data)
			end
			-- Dump a tree
			dump_tree(tree)
		end
	end

	-- In-memory ZIP tests
	do
		print("[zip] memory test start")

		-- Test 1: Write to string from flat table
		local files = {
			["file1.txt"] = "Content 1\n",
			["file2.txt"] = "Content 2\n",
			["dir/"] = true,
		}
		local zip_data, err = Zip.write_to_string(files)
		if not zip_data then
			print("write_to_string failed:", err)
			return
		end
		print("[zip] write_to_string success, size:", #zip_data)

		-- Test 2: Read from string
		local meta, err = Zip.read_from_string(zip_data)
		if not meta then
			print("read_from_string failed:", err)
			return
		end
		print("[zip] read_from_string success, entries:", #meta.files)
		for i = 1, #meta.files do
			print(string_format("  entry %d: %s", i, meta.files[i].name))
		end

		-- Test 3: Read entry data from string
		local data, err = Zip.read_data_from_string(zip_data, meta.files[1])
		if not data then
			print("read_data_from_string failed:", err)
			return
		end
		print("[zip] read_data_from_string success, content:", data)

		-- Test 4: Write to string from nested table
		local tree = {
			["folder"] = {
				["nested.txt"] = "Nested content\n",
			},
			["root.txt"] = "Root content\n",
		}
		local zip_data2, err = Zip.write_nested_to_string(tree)
		if not zip_data2 then
			print("write_nested_to_string failed:", err)
			return
		end
		print("[zip] write_nested_to_string success, size:", #zip_data2)

		-- Test 5: Read from string to nested table
		local tree2, err = Zip.read_string_to_nested_table(zip_data2)
		if not tree2 then
			print("read_string_to_nested_table failed:", err)
			return
		end
		print("[zip] read_string_to_nested_table success")
		dump_tree(tree2)

		print("[zip] memory test complete")
	end
end
--]]

-- Export
return Zip
