-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Augment existing standard string library

-- Localized global functions for better performance
local type = type
local tonumber = tonumber
local tostring = tostring
---@diagnostic disable-next-line: unnecessary-assert
local string = assert(_G.string, "string library is missing") ---@type string
local string_char = string.char
local string_find = string.find
local string_gmatch = string.gmatch
local string_gsub = string.gsub
local string_lower = string.lower
local string_match = string.match
local string_rep = string.rep
local string_sub = string.sub
local string_upper = string.upper
local string_byte = string.byte
local string_format = string.format
local math_floor = math.floor
local math_min = math.min
local math_random = math.random
local table_concat = table.concat

do
	local ITERATE_LINES_PATTERN = "[^\n]+"

	local string_iterate_lines = function(self)
		return string_gmatch(self, ITERATE_LINES_PATTERN)
	end

	string.iterate_lines = string_iterate_lines
	string.iterateLines = string_iterate_lines
	string.IterateLines = string_iterate_lines
end

do
	local CARRIAGE_RETURN_CHAR = "\r"
	local NEWLINE_CHAR = "\n"

	local string_lines = function(self)
		local len = #self -- Total length of the input string
		local lines = {}
		local line_counter = 0
		local pos = 1
		while pos <= len do
			-- Look for the next literal newline character starting at pos (plain search, no pattern matching)
			local newline_start, newline_end = string_find(self, NEWLINE_CHAR, pos, true)
			if newline_start then
				local line_end = newline_start - 1
				-- If the character immediately before the newline is a carriage return, adjust lineEnd
				if line_end >= pos and string_sub(self, line_end, line_end) == CARRIAGE_RETURN_CHAR then
					line_end = line_end - 1
				end
				line_counter = line_counter + 1
				lines[line_counter] = string_sub(self, pos, line_end)
				pos = newline_end + 1
			else
				-- No more newline found; capture the rest of the string
				line_counter = line_counter + 1
				lines[line_counter] = string_sub(self, pos)
				break
			end
		end
		return lines
	end

	string.lines = string_lines
	string.Lines = string_lines
end

local string_iter_explode = function(self, sep)
	if type(self) ~= "string" then self = tostring(self or "") end
	sep = sep or ","
	if type(sep) ~= "string" then sep = tostring(sep) end

	local len = #self
	local start = 1
	local pending_trailing_empty = false

	return function()
		-- handle trailing empty produced by separator at end
		if pending_trailing_empty then
			pending_trailing_empty = false
			return ""
		end

		if start > len then
			-- empty input or already exhausted
			if start == len + 1 then
				-- if input was empty and we haven't yielded anything, yield entire empty string once
				start = len + 2
				return ""
			end
			return nil
		end

		local a, b = string_find(self, sep, start, true)
		if not a then
			-- last field (remainder)
			local res = string_sub(self, start, len)
			start = len + 1
			return res
		end

		local res = string_sub(self, start, a - 1)
		start = b + 1
		if start > len then
			-- separator was at the end -> yield res now and then an empty string next call
			pending_trailing_empty = true
		end
		return res
	end
end

string.iter_explode = string_iter_explode

local string_iter_explode_pattern = function(self, pat)
	if type(self) ~= "string" then self = tostring(self or "") end
	pat = pat or ","
	if type(pat) ~= "string" then pat = tostring(pat) end

	local len = #self
	local start = 1
	local pending_trailing_empty = false

	return function()
		if pending_trailing_empty then
			pending_trailing_empty = false
			return ""
		end

		if start > len then
			if start == len + 1 then
				start = len + 2
				return ""
			end
			return nil
		end

		local a, b = string_find(self, pat, start)
		if not a then
			local res = string_sub(self, start, len)
			start = len + 1
			return res
		end

		local res = string_sub(self, start, a - 1)
		start = b + 1
		if start > len then
			pending_trailing_empty = true
		end
		return res
	end
end

string.iter_explode_pattern = string_iter_explode_pattern

local string_iter_chunk_split = function(self, size)
	if type(self) ~= "string" then self = tostring(self or "") end
	size = tonumber(size) or 1
	if size <= 0 then return error("size must be > 0") end

	local len = #self
	local pos = 1

	return function()
		if pos > len then return nil end
		local e = pos + size - 1
		if e > len then e = len end
		local res = string_sub(self, pos, e)
		pos = e + 1
		return res
	end
end

string.iter_chunk_split = string_iter_chunk_split

local string_chunks = function(self, size)
	if type(self) ~= "string" then self = tostring(self or "") end
	size = tonumber(size) or 1
	if size <= 0 then return error("size must be > 0") end

	local len = #self
	local chunks = {}
	local chunk_counter = 0
	local pos = 1

	while pos <= len do
		local e = pos + size - 1
		if e > len then e = len end
		chunk_counter = chunk_counter + 1
		chunks[chunk_counter] = string_sub(self, pos, e)
		pos = e + 1
	end

	return chunks
end

string.chunks = string_chunks
string.Chunks = string_chunks

local string_chunk = function(self, size)
	if type(self) ~= "string" then self = tostring(self or "") end
	size = tonumber(size) or 1
	if size <= 0 then return error("size must be > 0") end

	local len = #self
	local result = {}
	-- Total amount of chunks can be precomputed using: math.ceil(#str / size)
	local c = 1
	for i = 1, len, size do
		result[c - 1] = string_sub(self, i, i + size - 1)
		c = c + 1
	end
	return result
end

string.chunk = string_chunk
string.Chunk = string_chunk

local string_to_table = function(self)
	local tbl = {}
	for i = 1, #self do
		tbl[i] = string_sub(self, i, i)
	end
	return tbl
end

string.to_table = string_to_table
string.ToTable = string_to_table

local string_explode = function(self, separator, with_pattern)
	if #separator == 0 then return string_to_table(self) end
	local ret, current_pos = {}, 1
	for i = 1, #self do
		local start_pos, end_pos = string_find(self, separator, current_pos, not with_pattern)
		if not start_pos then break end
		ret[i] = string_sub(self, current_pos, start_pos - 1)
		current_pos = end_pos + 1
	end
	ret[#ret + 1] = string_sub(self, current_pos)
	return ret
end

string.explode = string_explode
string.split = string_explode

local string_replace = function(self, search_value, replace_value)
	local tbl = string_explode(self, search_value)
	return next(tbl) and table_concat(tbl, replace_value) or self
end

string.replace = string_replace
string.Replace = string_replace

local string_starts_with = function(self, start)
	return string_sub(self, 1, #start) == start
end

string.starts_with = string_starts_with
string.StartsWith = string_starts_with
string.StartWith = string_starts_with

local string_ends_with = function(self, endStr)
	local len = #endStr
	return len == 0 or string_sub(self, -len) == endStr
end

string.ends_with = string_ends_with
string.EndsWith = string_ends_with

local string_left = function(self, length)
	length = tonumber(length) or 0
	if length <= 0 then return "" end
	return string_sub(self, 1, length)
end

string.left = string_left
string.Left = string_left

local string_right = function(self, length)
	length = tonumber(length) or 0
	if length <= 0 then return "" end
	return string_sub(self, -length)
end

string.right = string_right
string.Right = string_right

local string_pad_left = function(self, total_width, char)
	total_width = tonumber(total_width) or 0
	char = char or " "
	if #self >= total_width then return self end
	return string_rep(char, total_width - #self) .. self
end

string.pad_left = string_pad_left
string.padleft = string_pad_left
string.PadLeft = string_pad_left

local string_pad_right = function(self, total_width, char)
	total_width = tonumber(total_width) or 0
	char = char or " "
	if #self >= total_width then return self end
	return self .. string_rep(char, total_width - #self)
end

string.pad_right = string_pad_right
string.padright = string_pad_right
string.PadRight = string_pad_right

local function string_padl(self, total_width, char)
	char = char or " "
	local s = tostring(self or "")
	local slen = #s
	if slen >= total_width then return s end
	return string_rep(char, total_width - slen) .. s
end

string.padl = string_padl
string.padL = string_padl
string.PadL = string_padl

local function string_padr(self, total_width, char)
	char = char or " "
	local s = tostring(self or "")
	local slen = #s
	if slen >= total_width then return s end
	return s .. string_rep(char, total_width - slen)
end

string.padr = string_padr
string.padR = string_padr
string.PadR = string_padr

local function string_pad_center(self, total_width, char)
	char = char or " "
	local s = tostring(self or "")
	local slen = #s
	if slen >= total_width then return s end
	local total_pad = total_width - slen
	local left_pad = math_floor(total_pad * 0.5)
	return string_rep(char, left_pad) .. s .. string_rep(char, total_pad - left_pad)
end

string.pad_center = string_pad_center
string.padcenter = string_pad_center
string.PadCenter = string_pad_center

do
	local PATTERN_SAFE_ESCAPE_REPLACEMENTS = {
		["\0"] = "%z", -- NOTE: using %z instead of \\0, in case the next char is a digit, which would fu** up a Lua string
		["$"] = "%$",
		["%"] = "%%",
		["("] = "%(",
		[")"] = "%)",
		["*"] = "%*",
		["+"] = "%+",
		["-"] = "%-",
		["."] = "%.",
		["?"] = "%?",
		["["] = "%[",
		["]"] = "%]",
		["^"] = "%^",
	}

	local pattern_safe_zero = function(str)
		return (string_gsub(str, ".", PATTERN_SAFE_ESCAPE_REPLACEMENTS))
	end

	string.pattern_safe_zero = pattern_safe_zero
	string.patternSafeZero = pattern_safe_zero
	string.PatternSafeZero = pattern_safe_zero
end

local string_trim
do
	local SAFE_PATTERN = "([%^%$%(%)%%%.%[%]%*%+%-%?])" -- NOTE: This version does not handle NUL
	local SAFE_PATTERN_ESCAPE = "%%%1"

	local pattern_safe = function(str)
		return (string_gsub(str, SAFE_PATTERN, SAFE_PATTERN_ESCAPE))
	end

	string.pattern_safe = pattern_safe
	string.patternSafe = pattern_safe
	string.PatternSafe = pattern_safe

	string_trim = function(self, char)
		char = char and string_gsub(char, SAFE_PATTERN, SAFE_PATTERN_ESCAPE) or "%s"
		return (string_match(self, "^" .. char .. "*(.-)" .. char .. "*$")) or self
	end

	string.trim = string_trim
	string.Trim = string_trim

	local string_trim_left = function(self, char)
		char = char and string_gsub(char, SAFE_PATTERN, SAFE_PATTERN_ESCAPE) or "%s"
		return (string_match(self, "^" .. char .. "*(.+)$")) or self
	end

	string.trim_left = string_trim_left
	string.trimleft = string_trim_left
	string.TrimLeft = string_trim_left

	local string_trim_right = function(self, char)
		char = char and string_gsub(char, SAFE_PATTERN, SAFE_PATTERN_ESCAPE) or "%s"
		return (string_match(self, "^(.-)" .. char .. "*$")) or self
	end

	string.trim_right = string_trim_right
	string.trimright = string_trim_right
	string.TrimRight = string_trim_right
end

local string_rotate_left = function(self, amount)
	amount = tonumber(amount) or 0
	if amount <= 0 then return self end
	if amount >= #self then return self end
	return string_sub(self, amount + 1) .. string_sub(self, 1, amount)
end

string.rotate_left = string_rotate_left
string.rotateleft = string_rotate_left
string.RotateLeft = string_rotate_left

local string_rotate_right = function(self, amount)
	amount = tonumber(amount) or 0
	if amount <= 0 then return self end
	if amount >= #self then return self end
	return string_rotate_left(self, #self - amount)
end

string.rotate_right = string_rotate_right
string.rotateright = string_rotate_right
string.RotateRight = string_rotate_right

local string_rotate = function(self, rotation)
	rotation = tonumber(rotation) or 0
	if rotation < 0 then
		return string_rotate_left(self, -rotation)
	end
	return string_rotate_right(self, rotation)
end

string.rotate = string_rotate
string.Rotate = string_rotate

local string_contains = function(self, substring)
	return string_find(self, substring, 1, true) ~= nil
end

string.contains = string_contains
string.Contains = string_contains

local string_index_of = function(self, substring)
	return (string_find(self, substring, 1, true))
end

string.index_of = string_index_of
string.indexof = string_index_of
string.IndexOf = string_index_of

local string_last_index_of = function(self, substring)
	local last_pos = nil
	local current_pos = 1

	repeat
		local pos = string_find(self, substring, current_pos, true)
		if pos then
			last_pos = pos
			current_pos = pos + 1
		end
	until not pos

	return last_pos
end

string.last_index_of = string_last_index_of
string.lastindexof = string_last_index_of
string.LastIndexOf = string_last_index_of

local string_random = function(length, min, max)
	length = tonumber(length) or 1
	min = tonumber(min) or 0
	max = tonumber(max) or 255
	if length <= 0 then return "" end
	local result = {}
	for i = 1, length do
		result[i] = string_char(math_random(min, max))
	end
	return table_concat(result)
end

string.random = string_random
string.Random = string_random
string.RandomString = string_random

local function string_split_path(key)
	local parts = {}
	for part in string_gmatch(key, "[^%.]+") do
		parts[#parts + 1] = part
	end
	return parts
end

string.split_path = string_split_path
string.SplitPath = string_split_path

-- Path separator constants
local PATH_SEPARATOR_WINDOWS = "\\"
local PATH_SEPARATOR_UNIX = "/"
local CURRENT_DIR = "."
local PARENT_DIR = ".."

local string_normalize_path_separators = function(self, separator)
	separator = separator or PATH_SEPARATOR_UNIX
	if separator ~= PATH_SEPARATOR_WINDOWS and separator ~= PATH_SEPARATOR_UNIX then
		separator = PATH_SEPARATOR_UNIX
	end
	-- Replace both types of separators with the target
	return (string_gsub((string_gsub(self, PATH_SEPARATOR_WINDOWS, separator)), PATH_SEPARATOR_UNIX, separator))
end

string.normalize_path_separators = string_normalize_path_separators
string.normalizePathSeparators = string_normalize_path_separators
string.NormalizePathSeparators = string_normalize_path_separators

local string_to_unix_path = function(self)
	return string_normalize_path_separators(self, PATH_SEPARATOR_UNIX)
end

string.to_unix_path = string_to_unix_path
string.toUnixPath = string_to_unix_path
string.ToUnixPath = string_to_unix_path

local string_to_windows_path = function(self)
	return string_normalize_path_separators(self, PATH_SEPARATOR_WINDOWS)
end

string.to_windows_path = string_to_windows_path
string.toWindowsPath = string_to_windows_path
string.ToWindowsPath = string_to_windows_path

local string_normalize_path = function(self, separator)
	separator = separator or PATH_SEPARATOR_UNIX
	if separator ~= PATH_SEPARATOR_WINDOWS and separator ~= PATH_SEPARATOR_UNIX then
		separator = PATH_SEPARATOR_UNIX
	end

	-- First normalize all separators to a common format
	local path = string_normalize_path_separators(self, PATH_SEPARATOR_UNIX)

	-- Split path into components
	local components = {}
	local start_absolute = false

	-- Handle absolute paths
	if string_sub(path, 1, 1) == PATH_SEPARATOR_UNIX then
		start_absolute = true
		path = string_sub(path, 2)
	end

	-- Split by separator
	for component in string_gmatch(path, "([^" .. PATH_SEPARATOR_UNIX .. "]+)") do
		if component == PARENT_DIR then
			-- Remove the previous component if possible
			if #components > 0 and components[#components] ~= PARENT_DIR then
				components[#components] = nil
			elseif not start_absolute then
				-- Keep leading .. for relative paths
				components[#components + 1] = component
			end
		elseif component ~= CURRENT_DIR then
			-- Add non-current directory components
			components[#components + 1] = component
		end
	end

	-- Reconstruct the path
	local result = ""
	if start_absolute then
		result = PATH_SEPARATOR_UNIX
	end

	if #components > 0 then
		result = result .. table_concat(components, PATH_SEPARATOR_UNIX)
	elseif start_absolute then
		-- Root path
		result = PATH_SEPARATOR_UNIX
	else
		-- Empty relative path
		result = CURRENT_DIR
	end

	-- Convert to requested separator format
	if separator ~= PATH_SEPARATOR_UNIX then
		result = string_gsub(result, PATH_SEPARATOR_UNIX, separator)
	end

	return result
end

string.normalize_path = string_normalize_path
string.normalizePath = string_normalize_path
string.NormalizePath = string_normalize_path

local string_path_dir = function(self)
	-- Normalize separators first
	local path = string_to_unix_path(self)

	-- Find the last separator
	local last_sep = string_find(path, PATH_SEPARATOR_UNIX, -1, true)
	if last_sep then
		return string_sub(path, 1, last_sep - 1)
	end
	return ""
end

string.path_dir = string_path_dir
string.pathDir = string_path_dir
string.dirname = string_path_dir
string.PathDir = string_path_dir
string.DirName = string_path_dir

local string_path_file = function(self)
	-- Normalize separators first
	local path = string_to_unix_path(self)

	-- Find the last separator
	local last_sep = string_find(path, PATH_SEPARATOR_UNIX, -1, true)
	if last_sep then
		return string_sub(path, last_sep + 1)
	end
	return path
end

string.path_file = string_path_file
string.pathFile = string_path_file
string.basename = string_path_file
string.PathFile = string_path_file
string.BaseName = string_path_file

local string_path_ext = function(self)
	local filename = string_path_file(self)

	-- Find the last dot
	local last_dot = string_find(filename, ".", -1, true)
	if last_dot and last_dot > 1 then
		return string_sub(filename, last_dot + 1)
	end
	return ""
end

string.path_ext = string_path_ext
string.pathExt = string_path_ext
string.extension = string_path_ext
string.PathExt = string_path_ext
string.Extension = string_path_ext

local string_path_name = function(self)
	local filename = string_path_file(self)

	-- Find the last dot
	local last_dot = string_find(filename, ".", -1, true)
	if last_dot and last_dot > 1 then
		return string_sub(filename, 1, last_dot - 1)
	end
	return filename
end

string.path_name = string_path_name
string.pathName = string_path_name
string.name_without_ext = string_path_name
string.PathName = string_path_name
string.NameWithoutExt = string_path_name

local string_path_join = function(...)
	local components = {}
	for i = 1, select("#", ...) do
		local component = tostring(select(i, ...))
		if component and component ~= "" then
			components[#components + 1] = component
		end
	end

	if #components == 0 then
		return ""
	end

	-- Join with forward slash first
	local path = table_concat(components, PATH_SEPARATOR_UNIX)

	-- Normalize the result
	return string_normalize_path(path, PATH_SEPARATOR_UNIX)
end

string.path_join = string_path_join
string.pathJoin = string_path_join
string.PathJoin = string_path_join

local string_is_absolute_path = function(self)
	if type(self) ~= "string" or #self == 0 then
		return false
	end

	-- Check for Unix-style absolute path
	if string_sub(self, 1, 1) == PATH_SEPARATOR_UNIX then
		return true
	end

	-- Check for Windows drive letter (e.g., "C:")
	if #self >= 2 and string_match(self, "^[%a%A]:") then
		return true
	end

	return false
end

string.is_absolute_path = string_is_absolute_path
string.isAbsolutePath = string_is_absolute_path
string.IsAbsolutePath = string_is_absolute_path

local string_to_absolute_path = function(self, base_path)
	base_path = base_path or CURRENT_DIR

	-- If self is already absolute, just normalize it
	if string_is_absolute_path(self) then
		return string_normalize_path(self)
	end

	-- Join base path with relative path and normalize
	return string_normalize_path(base_path .. PATH_SEPARATOR_UNIX .. self)
end

string.to_absolute_path = string_to_absolute_path
string.toAbsolutePath = string_to_absolute_path
string.ToAbsolutePath = string_to_absolute_path

local string_is_relative_path = function(self)
	if type(self) ~= "string" or #self == 0 then
		return false
	end
	return not string_is_absolute_path(self)
end

string.is_relative_path = string_is_relative_path
string.isRelativePath = string_is_relative_path
string.IsRelativePath = string_is_relative_path

local string_path_relative = function(self, base_path)
	if type(self) ~= "string" or #self == 0 then return self end
	if type(base_path) ~= "string" or #base_path == 0 then return self end

	-- Normalize both paths
	local target = string_normalize_path(string_to_unix_path(self))
	local base = string_normalize_path(string_to_unix_path(base_path))

	-- If target is absolute but base is relative, return target normalized
	if string_is_absolute_path(target) and not string_is_absolute_path(base) then
		return target
	end

	-- If both are relative, return target normalized
	if not string_is_absolute_path(target) and not string_is_absolute_path(base) then
		return target
	end

	-- Split both paths into components
	local target_parts = {}
	for part in string_gmatch(target, "([^/]+)") do
		target_parts[#target_parts + 1] = part
	end

	local base_parts = {}
	for part in string_gmatch(base, "([^/]+)") do
		base_parts[#base_parts + 1] = part
	end

	-- Find common prefix
	local common_len = 0
	local min_len = math_floor(math_min(#target_parts, #base_parts))
	for i = 1, min_len do
		if target_parts[i] == base_parts[i] then
			common_len = i
		else
			break
		end
	end

	-- Build relative path
	local result = {}

	-- Add .. for remaining base parts
	for i = common_len + 1, #base_parts do
		result[#result + 1] = PARENT_DIR
	end

	-- Add remaining target parts
	for i = common_len + 1, #target_parts do
		result[#result + 1] = target_parts[i]
	end

	if #result == 0 then
		return CURRENT_DIR
	end

	return table_concat(result, PATH_SEPARATOR_UNIX)
end

string.path_relative = string_path_relative
string.pathRelative = string_path_relative
string.PathRelative = string_path_relative

local string_path_split = function(self)
	local path = string_normalize_path(string_to_unix_path(self))
	local dir = string_path_dir(path)
	local file = string_path_file(path)
	return dir, file
end

string.path_split = string_path_split
string.pathSplit = string_path_split
string.PathSplit = string_path_split

local string_path_split_ext = function(self)
	local filename = string_path_file(self)
	local name = string_path_name(filename)
	local ext = string_path_ext(filename)
	return name, ext
end

string.path_split_ext = string_path_split_ext
string.pathSplitExt = string_path_split_ext
string.PathSplitExt = string_path_split_ext

local string_path_has_extension = function(self)
	local ext = string_path_ext(self)
	return ext ~= ""
end

string.path_has_extension = string_path_has_extension
string.pathHasExtension = string_path_has_extension
string.PathHasExtension = string_path_has_extension

local string_path_change_extension = function(self, new_ext)
	local dir = string_path_dir(self)
	local name = string_path_name(self)

	-- Add dot if not present
	if new_ext and #new_ext > 0 and string_sub(new_ext, 1, 1) ~= "." then
		new_ext = "." .. new_ext
	end

	if dir and #dir > 0 then
		return dir .. PATH_SEPARATOR_UNIX .. name .. (new_ext or "")
	end
	return name .. (new_ext or "")
end

string.path_change_extension = string_path_change_extension
string.pathChangeExtension = string_path_change_extension
string.PathChangeExtension = string_path_change_extension

local string_path_add_extension = function(self, ext)
	if string_path_has_extension(self) then
		return self
	end
	return string_path_change_extension(self, ext)
end

string.path_add_extension = string_path_add_extension
string.pathAddExtension = string_path_add_extension
string.PathAddExtension = string_path_add_extension

local string_path_remove_extension = function(self)
	return string_path_change_extension(self, "")
end

string.path_remove_extension = string_path_remove_extension
string.pathRemoveExtension = string_path_remove_extension
string.PathRemoveExtension = string_path_remove_extension

local string_path_common_prefix = function(self, other)
	if type(self) ~= "string" or #self == 0 then return "" end
	if type(other) ~= "string" or #other == 0 then return "" end

	local path1 = string_normalize_path(string_to_unix_path(self))
	local path2 = string_normalize_path(string_to_unix_path(other))

	local parts1 = {}
	for part in string_gmatch(path1, "([^/]+)") do
		parts1[#parts1 + 1] = part
	end

	local parts2 = {}
	for part in string_gmatch(path2, "([^/]+)") do
		parts2[#parts2 + 1] = part
	end

	local common = {}
	local min_len = math_floor(math_min(#parts1, #parts2))
	for i = 1, min_len do
		if parts1[i] == parts2[i] then
			common[#common + 1] = parts1[i]
		else
			break
		end
	end

	if #common == 0 then
		return ""
	end

	return table_concat(common, PATH_SEPARATOR_UNIX)
end

string.path_common_prefix = string_path_common_prefix
string.pathCommonPrefix = string_path_common_prefix
string.PathCommonPrefix = string_path_common_prefix

local string_path_components = function(self)
	local path = string_normalize_path(string_to_unix_path(self))
	local components = {}
	for part in string_gmatch(path, "([^/]+)") do
		components[#components + 1] = part
	end
	return components
end

string.path_components = string_path_components
string.pathComponents = string_path_components
string.PathComponents = string_path_components

local string_path_from_components = function(components, separator)
	separator = separator or PATH_SEPARATOR_UNIX
	if type(components) ~= "table" then return "" end
	return table_concat(components, separator)
end

string.path_from_components = string_path_from_components
string.pathFromComponents = string_path_from_components
string.PathFromComponents = string_path_from_components

local string_path_trim_trailing_separator = function(self, separator)
	separator = separator or PATH_SEPARATOR_UNIX
	local path = self
	while #path > 0 and string_sub(path, -1) == separator do
		path = string_sub(path, 1, -2)
	end
	return path
end

string.path_trim_trailing_separator = string_path_trim_trailing_separator
string.pathTrimTrailingSeparator = string_path_trim_trailing_separator
string.PathTrimTrailingSeparator = string_path_trim_trailing_separator

local string_path_has_trailing_separator = function(self, separator)
	separator = separator or PATH_SEPARATOR_UNIX
	return #self > 0 and string_sub(self, -1) == separator
end

string.path_has_trailing_separator = string_path_has_trailing_separator
string.pathHasTrailingSeparator = string_path_has_trailing_separator
string.PathHasTrailingSeparator = string_path_has_trailing_separator

local string_path_trim_leading_separator = function(self, separator)
	separator = separator or PATH_SEPARATOR_UNIX
	local path = self
	while #path > 0 and string_sub(path, 1, 1) == separator do
		path = string_sub(path, 2)
	end
	return path
end

string.path_trim_leading_separator = string_path_trim_leading_separator
string.pathTrimLeadingSeparator = string_path_trim_leading_separator
string.PathTrimLeadingSeparator = string_path_trim_leading_separator

local string_path_has_leading_separator = function(self, separator)
	separator = separator or PATH_SEPARATOR_UNIX
	return #self > 0 and string_sub(self, 1, 1) == separator
end

string.path_has_leading_separator = string_path_has_leading_separator
string.pathHasLeadingSeparator = string_path_has_leading_separator
string.PathHasLeadingSeparator = string_path_has_leading_separator

local string_path_is_same = function(self, other)
	if type(self) ~= "string" or type(other) ~= "string" then
		return false
	end
	local p1 = string_normalize_path(string_to_unix_path(self))
	local p2 = string_normalize_path(string_to_unix_path(other))
	return p1 == p2
end

string.path_is_same = string_path_is_same
string.pathIsSame = string_path_is_same
string.PathIsSame = string_path_is_same

local string_path_get_drive = function(self)
	if #self >= 2 and string_match(self, "^[%a%A]:") then
		return string_sub(self, 1, 2)
	end
	return ""
end

string.path_get_drive = string_path_get_drive
string.pathGetDrive = string_path_get_drive
string.PathGetDrive = string_path_get_drive

local string_path_without_drive = function(self)
	local drive = string_path_get_drive(self)
	if #drive > 0 then
		return string_sub(self, 3)
	end
	return self
end

string.path_without_drive = string_path_without_drive
string.pathWithoutDrive = string_path_without_drive
string.PathWithoutDrive = string_path_without_drive

local string_path_get_root = function(self)
	local path = string_to_unix_path(self)

	-- Unix root
	if string_sub(path, 1, 1) == PATH_SEPARATOR_UNIX then
		return PATH_SEPARATOR_UNIX
	end

	-- Windows drive root
	local drive = string_path_get_drive(self)
	if #drive > 0 then
		return drive .. PATH_SEPARATOR_WINDOWS
	end

	return ""
end

string.path_get_root = string_path_get_root
string.pathGetRoot = string_path_get_root
string.PathGetRoot = string_path_get_root

local string_path_is_root = function(self)
	local root = string_path_get_root(self)
	local normalized = string_normalize_path(string_to_unix_path(self))
	return normalized == root or normalized == string_to_unix_path(root)
end

string.path_is_root = string_path_is_root
string.pathIsRoot = string_path_is_root
string.PathIsRoot = string_path_is_root

local string_path_ancestor = function(self, potential_ancestor)
	if type(self) ~= "string" or type(potential_ancestor) ~= "string" then
		return false
	end

	local path = string_normalize_path(string_to_unix_path(self))
	local ancestor = string_normalize_path(string_to_unix_path(potential_ancestor))

	-- Ancestor must be a prefix
	if #ancestor >= #path then
		return path == ancestor
	end

	-- Check if ancestor is a prefix and ends with separator or path continues
	local prefix = string_sub(path, 1, #ancestor)
	if prefix ~= ancestor then
		return false
	end

	-- If ancestor doesn't end with separator, the next char in path must be separator
	if string_sub(ancestor, -1) ~= PATH_SEPARATOR_UNIX then
		return string_sub(path, #ancestor + 1, #ancestor + 1) == PATH_SEPARATOR_UNIX
	end

	return true
end

string.path_ancestor = string_path_ancestor
string.pathAncestor = string_path_ancestor
string.PathAncestor = string_path_ancestor

local string_path_clean = function(self)
	-- Replace backslashes with forward slashes
	local path = string_gsub(self, "\\", "/")
	-- Collapse multiple slashes into one
	path = string_gsub(path, "/+", "/")
	-- Remove trailing slash unless it's the root
	if #path > 1 then
		path = string_gsub(path, "/$", "")
	end
	return path
end

string.path_clean = string_path_clean
string.pathClean = string_path_clean
string.PathClean = string_path_clean

local string_path_parent = function(self)
	local path = string_normalize_path(string_to_unix_path(self))
	local dir = string_path_dir(path)
	if #dir == 0 then
		return CURRENT_DIR
	end
	return dir
end

string.path_parent = string_path_parent
string.pathParent = string_path_parent
string.PathParent = string_path_parent

local string_path_has_parent = function(self)
	local path = string_normalize_path(string_to_unix_path(self))
	local dir = string_path_dir(path)
	return #dir > 0 and dir ~= CURRENT_DIR
end

string.path_has_parent = string_path_has_parent
string.pathHasParent = string_path_has_parent
string.PathHasParent = string_path_has_parent

local string_path_depth = function(self)
	local path = string_normalize_path(string_to_unix_path(self))
	local components = string_path_components(path)
	return #components
end

string.path_depth = string_path_depth
string.pathDepth = string_path_depth
string.PathDepth = string_path_depth

local string_path_is_child = function(self, parent)
	if type(self) ~= "string" or type(parent) ~= "string" then
		return false
	end
	return string_path_ancestor(parent, self)
end

string.path_is_child = string_path_is_child
string.pathIsChild = string_path_is_child
string.PathIsChild = string_path_is_child

local string_path_sanitize = function(self)
	-- Remove invalid characters for filesystem paths (Windows/Unix)
	-- Invalid on Windows: <>:"/\|?* and control chars
	-- Invalid on Unix: / and null
	local result = self
	-- Remove control characters (0-31)
	result = string_gsub(result, "[%c]+", "")
	-- Remove Windows-invalid characters: <>:"|?*
	result = string_gsub(result, '[<>:"|?*]', "")
	-- Replace multiple spaces with single space
	result = string_gsub(result, "%s+", " ")
	-- Trim leading/trailing spaces
	result = string_trim(result)
	return result
end

string.path_sanitize = string_path_sanitize
string.pathSanitize = string_path_sanitize
string.PathSanitize = string_path_sanitize

local string_path_make_absolute = function(self, base_path)
	return string_to_absolute_path(self, base_path)
end

string.path_make_absolute = string_path_make_absolute
string.pathMakeAbsolute = string_path_make_absolute
string.PathMakeAbsolute = string_path_make_absolute

local string_path_make_relative = function(self, base_path)
	return string_path_relative(self, base_path)
end

string.path_make_relative = string_path_make_relative
string.pathMakeRelative = string_path_make_relative
string.PathMakeRelative = string_path_make_relative

local function string_detect_casing_style(self)
	if type(self) ~= "string" or #self == 0 then
		return "unknown"
	end

	local has_underscore = string_find(self, "_", 1, true) ~= nil
	local has_hyphen = string_find(self, "-", 1, true) ~= nil
	local has_space = string_find(self, " ", 1, true) ~= nil
	local first_char = string_sub(self, 1, 1)
	local is_first_upper = first_char == string_upper(first_char) and first_char ~= string_lower(first_char)
	local is_first_lower = first_char == string_lower(first_char) and first_char ~= string_upper(first_char)
	local is_all_upper = self == string_upper(self)
	local is_all_lower = self == string_lower(self)

	-- Check for SCREAMING_SNAKE_CASE (all uppercase with underscores)
	if has_underscore and is_all_upper then
		return "SCREAMING_SNAKE_CASE"
	end

	-- Check for snake_case (has underscores, not all uppercase)
	if has_underscore then
		return "snake_case"
	end

	-- Check for kebab-case (has hyphens)
	if has_hyphen then
		return "kebab-case"
	end

	-- Check for space case (has spaces)
	if has_space then
		if is_all_upper then
			return "UPPER_SPACE_CASE"
		end
		return "space_case"
	end

	-- Check for all uppercase without separators
	if is_all_upper and not is_first_lower then
		return "UPPERCASE"
	end

	-- Check for all lowercase without separators
	if is_all_lower then
		return "lowercase"
	end

	-- Check for PascalCase (first letter uppercase, no separators, mixed case)
	if is_first_upper and not has_underscore and not has_hyphen and not has_space then
		return "PascalCase"
	end

	-- Check for camelCase (first letter lowercase, no separators, mixed case)
	if is_first_lower and not has_underscore and not has_hyphen and not has_space then
		return "camelCase"
	end

	return "unknown"
end

string.detect_casing_style = string_detect_casing_style
string.detectCasingStyle = string_detect_casing_style
string.DetectCasingStyle = string_detect_casing_style

local string_to_snake_case = function(self)
	if type(self) ~= "string" then self = tostring(self or "") end

	-- Replace hyphens and spaces with underscores
	local result = string_gsub(self, "[-%s]+", "_")

	-- Insert underscores before uppercase letters (camelCase/PascalCase conversion)
	result = string_gsub(result, "(%l)(%u)", "%1_%2")

	-- Convert multiple underscores to single underscore
	result = string_gsub(result, "_+", "_")

	-- Convert to lowercase
	result = string_gsub(result, "(%u+)", function(upper)
		return (string_gsub(string_lower(upper), "_", ""))
	end)

	-- Remove leading/trailing underscores
	result = string_trim(result, "_")

	return result
end

string.to_snake_case = string_to_snake_case
string.toSnakeCase = string_to_snake_case
string.ToSnakeCase = string_to_snake_case

local string_to_camel_case = function(self)
	if type(self) ~= "string" then self = tostring(self or "") end

	-- Replace hyphens and underscores with spaces
	local result = string_gsub(self, "[-_]+", " ")

	-- Convert to lowercase and capitalize words after the first
	result = string_gsub(result, "(%S+)", function(word, pos)
		return pos == 1 and string_lower(word) or (string_gsub(word, "^%l", string_upper))
	end)

	-- Remove spaces
	result = string_gsub(result, "%s+", "")

	return result
end

string.to_camel_case = string_to_camel_case
string.toCamelCase = string_to_camel_case
string.ToCamelCase = string_to_camel_case

local string_to_pascal_case = function(self)
	if type(self) ~= "string" then self = tostring(self or "") end

	-- Replace hyphens and underscores with spaces
	local result = string_gsub(self, "[-_]+", " ")

	-- Capitalize first letter of each word
	result = string_gsub(result, "(%S+)", function(word)
		return (string_gsub(word, "^%l", string_upper))
	end)

	-- Remove spaces
	result = string_gsub(result, "%s+", "")

	return result
end

string.to_pascal_case = string_to_pascal_case
string.toPascalCase = string_to_pascal_case
string.ToPascalCase = string_to_pascal_case

local function resolve_absolute_range(len, start_index, end_index) -- TODO/FIXME: alias of util.resolve_absolute_range
	-- Default range is the entire string
	start_index = tonumber(start_index) or 1
	end_index = tonumber(end_index) or len

	-- Handle negative indices (count from end)
	if start_index < 0 then
		start_index = len + start_index + 1
	elseif start_index == 0 then
		start_index = 1
	end

	if end_index < 0 then
		end_index = len + end_index + 1
	elseif end_index == 0 then
		end_index = 1
	end

	-- Clamp indices to valid range
	if start_index < 1 then start_index = 1 end
	if end_index > len then end_index = len end

	return start_index, end_index, start_index > end_index
end

string.resolve_absolute_range = resolve_absolute_range
string.resolveAbsoluteRange = resolve_absolute_range
string.ResolveAbsoluteRange = resolve_absolute_range

local function string_is_printable(self, start_index, end_index)
	if type(self) ~= "string" then return false end

	local len = #self
	if len == 0 then return true end

	start_index, end_index = resolve_absolute_range(len, start_index, end_index)

	-- Empty range is considered printable
	if start_index > end_index then return true end

	-- Check each character in the range
	for i = start_index, end_index do
		local b = string_byte(self, i)
		if b < 32 or b > 126 then
			return false
		end
	end

	return true
end

string.is_printable = string_is_printable
string.isPrintable = string_is_printable
string.IsPrintable = string_is_printable

local function string_url_encode(self)
	if type(self) ~= "string" then self = tostring(self or "") end

	local result = {}
	for i = 1, #self do
		local byte = string_byte(self, i)
		-- Encode characters that are not unreserved (A-Z, a-z, 0-9, hyphen, period, underscore, tilde)
		if (byte >= 48 and byte <= 57) or (byte >= 65 and byte <= 90) or (byte >= 97 and byte <= 122) or byte == 45 or byte == 46 or byte == 95 or byte == 126 then
			result[#result + 1] = string_sub(self, i, i)
		else
			result[#result + 1] = string_format("%%%02X", byte)
		end
	end
	return table_concat(result)
end

string.url_encode = string_url_encode
string.urlEncode = string_url_encode
string.UrlEncode = string_url_encode

local function string_url_decode(self)
	if type(self) ~= "string" then self = tostring(self or "") end

	local result = {}
	local i = 1
	while i <= #self do
		local char = string_sub(self, i, i)
		if char == "%" and i + 2 <= #self then
			local hex = string_sub(self, i + 1, i + 2)
			local byte = tonumber(hex, 16)
			if byte then
				result[#result + 1] = string_char(byte)
				i = i + 3
			else
				result[#result + 1] = char
				i = i + 1
			end
		elseif char == "+" then
			result[#result + 1] = " "
			i = i + 1
		else
			result[#result + 1] = char
			i = i + 1
		end
	end
	return table_concat(result)
end

string.url_decode = string_url_decode
string.urlDecode = string_url_decode
string.UrlDecode = string_url_decode

local function string_parse_query(self)
	if type(self) ~= "string" then self = tostring(self or "") end

	local result = {}
	if #self == 0 then return result end

	for pair in string_gmatch(self, "([^&=]+)=?([^&]*)") do
		local key, value = string_match(pair, "^([^=]*)=(.*)$")
		if key then
			key = string_url_decode(key)
			value = value ~= "" and string_url_decode(value) or ""
			if result[key] then
				if type(result[key]) == "table" then
					result[key][#result[key] + 1] = value
				else
					result[key] = { result[key], value }
				end
			else
				result[key] = value
			end
		end
	end

	return result
end

string.parse_query = string_parse_query
string.parseQuery = string_parse_query
string.ParseQuery = string_parse_query

local function string_build_query(tbl, sep)
	if type(tbl) ~= "table" then return "" end
	sep = sep or "&"

	local result = {}
	local function add_pair(key, value)
		local encoded_key = string_url_encode(tostring(key))
		if type(value) == "table" then
			for _, v in next, value do
				result[#result + 1] = encoded_key .. "=" .. string_url_encode(tostring(v))
			end
		else
			result[#result + 1] = encoded_key .. "=" .. string_url_encode(tostring(value))
		end
	end

	for key, value in next, tbl do
		add_pair(key, value)
	end

	return table_concat(result, sep)
end

string.build_query = string_build_query
string.buildQuery = string_build_query
string.BuildQuery = string_build_query

local function string_parse_url(self)
	if type(self) ~= "string" then self = tostring(self or "") end

	local result = {
		scheme = "",
		username = "",
		password = "",
		host = "",
		port = "",
		path = "",
		query = "",
		fragment = "",
		authority = "",
	}

	if #self == 0 then return result end

	-- Extract fragment
	local fragment_start = string_find(self, "#", 1, true)
	if fragment_start then
		result.fragment = string_sub(self, fragment_start + 1)
		self = string_sub(self, 1, fragment_start - 1)
	end

	-- Extract query
	local query_start = string_find(self, "?", 1, true)
	if query_start then
		result.query = string_sub(self, query_start + 1)
		self = string_sub(self, 1, query_start - 1)
	end

	-- Extract scheme
	local scheme_end = string_find(self, "://", 1, true)
	if scheme_end then
		result.scheme = string_sub(self, 1, scheme_end - 1)
		self = string_sub(self, scheme_end + 3)
	end

	-- Extract authority (everything before first / after scheme)
	local path_start = string_find(self, "/", 1, true)
	if not path_start and #self > 0 then
		-- No path, entire string is authority
		result.authority = self
		self = ""
	elseif path_start then
		result.authority = string_sub(self, 1, path_start - 1)
		result.path = string_sub(self, path_start)
		self = ""
	end

	-- Parse authority
	if #result.authority > 0 then
		local auth = result.authority

		-- Extract userinfo (username:password@)
		local userinfo_end = string_find(auth, "@", 1, true)
		if userinfo_end then
			local userinfo = string_sub(auth, 1, userinfo_end - 1)
			auth = string_sub(auth, userinfo_end + 1)

			-- Split username and password
			local pass_start = string_find(userinfo, ":", 1, true)
			if pass_start then
				result.username = string_sub(userinfo, 1, pass_start - 1)
				result.password = string_sub(userinfo, pass_start + 1)
			else
				result.username = userinfo
			end
		end

		-- Extract port
		local port_start = string_find(auth, ":", 1, true)
		if port_start then
			result.host = string_sub(auth, 1, port_start - 1)
			result.port = string_sub(auth, port_start + 1)
		else
			result.host = auth
		end
	end

	-- Default path to "/" if empty and scheme is present
	if #result.path == 0 and #result.scheme > 0 then
		result.path = "/"
	end

	return result
end

string.parse_url = string_parse_url
string.parseUrl = string_parse_url
string.ParseUrl = string_parse_url

local function string_url_scheme(self)
	local parsed = string_parse_url(self)
	return parsed.scheme
end

string.url_scheme = string_url_scheme
string.urlScheme = string_url_scheme
string.UrlScheme = string_url_scheme

local function string_url_host(self)
	local parsed = string_parse_url(self)
	return parsed.host
end

string.url_host = string_url_host
string.urlHost = string_url_host
string.UrlHost = string_url_host

local function string_url_port(self)
	local parsed = string_parse_url(self)
	return parsed.port
end

string.url_port = string_url_port
string.urlPort = string_url_port
string.UrlPort = string_url_port

local function string_url_path(self)
	local parsed = string_parse_url(self)
	return parsed.path
end

string.url_path = string_url_path
string.urlPath = string_url_path
string.UrlPath = string_url_path

local function string_url_query(self)
	local parsed = string_parse_url(self)
	return parsed.query
end

string.url_query = string_url_query
string.urlQuery = string_url_query
string.UrlQuery = string_url_query

local function string_url_fragment(self)
	local parsed = string_parse_url(self)
	return parsed.fragment
end

string.url_fragment = string_url_fragment
string.urlFragment = string_url_fragment
string.UrlFragment = string_url_fragment

local function string_url_username(self)
	local parsed = string_parse_url(self)
	return parsed.username
end

string.url_username = string_url_username
string.urlUsername = string_url_username
string.UrlUsername = string_url_username

local function string_url_password(self)
	local parsed = string_parse_url(self)
	return parsed.password
end

string.url_password = string_url_password
string.urlPassword = string_url_password
string.UrlPassword = string_url_password

local function string_url_authority(self)
	local parsed = string_parse_url(self)
	return parsed.authority
end

string.url_authority = string_url_authority
string.urlAuthority = string_url_authority
string.UrlAuthority = string_url_authority

local function string_is_absolute_url(self)
	local parsed = string_parse_url(self)
	return #parsed.scheme > 0
end

string.is_absolute_url = string_is_absolute_url
string.isAbsoluteUrl = string_is_absolute_url
string.IsAbsoluteUrl = string_is_absolute_url

local function string_resolve_url(relative, base)
	if type(relative) ~= "string" then relative = tostring(relative or "") end
	if type(base) ~= "string" then base = tostring(base or "") end

	-- If relative URL is absolute, return it
	if string_is_absolute_url(relative) then
		return relative
	end

	-- Parse base URL
	local base_parsed = string_parse_url(base)

	-- If base has no scheme, return relative as-is
	if #base_parsed.scheme == 0 then
		return relative
	end

	-- If relative starts with //, use scheme from base
	if string_sub(relative, 1, 2) == "//" then
		return base_parsed.scheme .. ":" .. relative
	end

	-- If relative starts with /, use scheme and authority from base
	if string_sub(relative, 1, 1) == "/" then
		local has_double_slash = string_sub(relative, 1, 2) == "//"
		if has_double_slash then
			return base_parsed.scheme .. ":" .. relative
		else
			local authority = base_parsed.authority
			if #authority > 0 then
				return base_parsed.scheme .. "://" .. authority .. relative
			else
				return base_parsed.scheme .. ":" .. relative
			end
		end
	end

	-- Merge paths
	local base_path = base_parsed.path
	local relative_path = relative

	-- Remove filename from base path
	local last_slash = string_find(base_path, "/", -1, true)
	if last_slash then
		base_path = string_sub(base_path, 1, last_slash)
	else
		base_path = "/"
	end

	-- Combine paths
	local combined_path = base_path .. relative_path

	-- Normalize path (remove . and ..)
	local path_parts = {}
	for part in string_gmatch(combined_path, "([^/]+)") do
		if part == ".." then
			if #path_parts > 0 then
				path_parts[#path_parts] = nil
			end
		elseif part ~= "." then
			path_parts[#path_parts + 1] = part
		end
	end

	local resolved_path = "/" .. table_concat(path_parts, "/")

	-- Reconstruct URL
	local result = base_parsed.scheme .. "://"
	if #base_parsed.username > 0 then
		result = result .. base_parsed.username
		if #base_parsed.password > 0 then
			result = result .. ":" .. base_parsed.password
		end
		result = result .. "@"
	end
	result = result .. base_parsed.host
	if #base_parsed.port > 0 then
		result = result .. ":" .. base_parsed.port
	end
	result = result .. resolved_path

	return result
end

string.resolve_url = string_resolve_url
string.resolveUrl = string_resolve_url
string.ResolveUrl = string_resolve_url

local function string_split_url(full_url)
	if type(full_url) ~= "string" then full_url = tostring(full_url or "") end

	-- Build base URL from scheme + authority
	local scheme = string_url_scheme(full_url)
	local authority = string_url_authority(full_url)
	local base_url = scheme .. "://" .. authority

	-- Remove trailing slash from base_url (47 is the ASCII code for "/")
	if string_byte(base_url, #base_url) == 47 then
		base_url = string_sub(base_url, 1, -2)
	end

	-- Build endpoint from path + query + fragment
	local path = string_url_path(full_url)
	local query = string_url_query(full_url)
	local fragment = string_url_fragment(full_url)

	local endpoint = path
	if #query > 0 then
		endpoint = endpoint .. "?" .. query
	end
	if #fragment > 0 then
		endpoint = endpoint .. "#" .. fragment
	end

	-- Ensure endpoint starts with "/" (ASCII code 47)
	if #endpoint == 0 or string_byte(endpoint, 1) ~= 47 then
		endpoint = "/" .. endpoint
	end

	return base_url, endpoint
end

string.split_url = string_split_url
string.splitUrl = string_split_url
string.SplitUrl = string_split_url

-- Export (for compatibility)
return string
