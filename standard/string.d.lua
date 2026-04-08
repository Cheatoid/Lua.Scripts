-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

---@meta

---@class string
local string = {}

--- Iterate over lines in a string using an iterator.
--- Returns each line (excluding newline characters) as it's encountered.
---@param self string Input string to iterate over.
---@return function iterator Iterator that yields each line as a separate string.
---@usage <br>
--- ```
--- -- Outputs: "line 1", "line 2", "line 3"
--- for line in "line 1\nline 2\nline 3":iterate_lines() do
---   print(line)
--- end
--- ```
local string_iterate_lines = function(self) end

string.iterate_lines = string_iterate_lines
string.iterateLines = string_iterate_lines
string.IterateLines = string_iterate_lines

--- Split a string into lines and return them as a table.
--- Handles both \n and \r\n line endings properly.
---@param self string Input string to split into lines.
---@return table lines Table containing each line as a separate string.
---@usage <br>
--- ```
--- -- Returns: { "line 1", "line 2", "line 3" }
--- "line 1\nline 2\r\nline 3":lines()
--- ```
local string_lines = function(self) end

string.lines = string_lines
string.Lines = string_lines

--- Split a string using a plain separator and return an iterator.
--- The separator is treated as plain text (not a pattern).
---@param self string Input string to split.
---@param sep string Plain separator used to split (default: ",").
---@return function iterator Iterator that yields string parts.
---@usage <br>
--- ```
--- -- Outputs: "a", "b", "", "c", ""
--- for part in "a,b,,c,":iter_explode(",") do
---   print(part)
--- end
--- ```
local string_iter_explode = function(self, sep) end

string.iter_explode = string_iter_explode

--- Split a string using a Lua pattern as separator and return an iterator.
--- The pattern is treated as a Lua string pattern (not plain text).
---@param self string Input string to split.
---@param pat string Lua pattern used as separator (default: ",").
---@return function iterator Iterator that yields string parts.
---@usage <br>
--- ```
--- -- Outputs: "a", "b", "c"
--- for part in "a1b2c":iter_explode_pattern("%d") do
---   print(part)
--- end
--- ```
local string_iter_explode_pattern = function(self, pat) end

string.iter_explode_pattern = string_iter_explode_pattern

--- Split a string into fixed-size chunks and return an iterator.
---@param self string Input string to split into chunks.
---@param size integer Size of each chunk (default: 1, must be > 0).
---@return function iterator Iterator that yields string chunks.
---@usage <br>
--- ```
--- -- Outputs: "abc", "def", "g"
--- for chunk in "abcdefg":iter_chunk_split(3) do
---   print(chunk)
--- end
--- ```
local string_iter_chunk_split = function(self, size) end

string.iter_chunk_split = string_iter_chunk_split

--- Split a string into fixed-size chunks and return them as a table.
---@param self string Input string to split into chunks.
---@param size integer Size of each chunk (default: 1, must be > 0).
---@return table array Table containing each chunk as a separate element.
---@usage <br>
--- ```
--- "abcdefg":chunks(3) -- { "abc", "def", "g" }
--- ```
local string_chunks = function(self, size) end

string.chunks = string_chunks
string.Chunks = string_chunks

--- Split a string into fixed-size chunks and return them as a table.
--- Uses a for loop with step size for chunking.
---@param self string Input string to split into chunks.
---@param size integer Size of each chunk (must be > 0).
---@return table array Table containing each chunk as a separate element.
---@usage <br>
--- ```
--- "abcdefg":chunk(3) -- { "abc", "def", "g" }
--- ```
local string_chunk = function(self, size) end

string.chunk = string_chunk
string.Chunk = string_chunk

--- Convert a string to a table of individual characters.
--- Each character in the string becomes a separate table element.
---@param self string Input string to convert to a table.
---@return table array Array containing each character as a separate element.
---@usage <br>
--- ```
--- "hello":to_table() -- { "h", "e", "l", "l", "o" }
--- ```
local string_to_table = function(self) end

string.to_table = string_to_table
string.ToTable = string_to_table

--- Split a string into parts using a separator and return as a table.
--- Supports both plain text and pattern-based separators.
---@param self string Input string to split.
---@param separator string Separator to split on (can be empty string or pattern).
---@param with_pattern boolean|nil If true, treats separator as Lua pattern; if false, as plain text (default: false).
---@return table array Array containing the split string parts.
---@usage <br>
--- ```
--- -- Plain text separator: returns {"a", "b", "c"}
--- local parts = "a,b,c":explode(",", false)
---
--- -- Pattern separator: returns {"a", "b", "c"}
--- local parts = "a1b2c":explode("%d", true)
---
--- -- Empty separator: returns {"h", "e", "l", "l", "o"}
--- local chars = "hello":explode("", false)
--- ```
local string_explode = function(self, separator, with_pattern) end

string.explode = string_explode
string.split = string_explode

--- Replace all occurrences of a search value with a replacement value.
--- Uses plain text search (not patterns) for maximum performance.
---@param self string Input string to perform replacements on.
---@param search_value string Value to search for (treated as plain text).
---@param replace_value string Value to replace with (treated as plain text).
---@return string string New string with all replacements applied.
---@usage <br>
--- ```
--- "Hi there! Hi there!":replace("Hi", "Hello") -- "Hello there! Hello there!"
--- "a,b,c,d":replace(",", "-") -- "a-b-c-d"
--- "hello":replace("x", "y") -- "hello"
--- ```
local string_replace = function(self, search_value, replace_value) end

string.replace = string_replace
string.Replace = string_replace

--- Check if a string starts with the specified prefix.
---@param self string Input string to check.
---@param start string Prefix to search for at the beginning of the string.
---@return boolean boolean True if the string starts with the prefix, false otherwise.
---@usage <br>
--- ```
--- "hello world":starts_with("hello") -- true
--- "hello world":starts_with("world") -- false
--- ```
local string_starts_with = function(self, start) end

string.starts_with = string_starts_with
string.StartsWith = string_starts_with
string.StartWith = string_starts_with

--- Check if a string ends with the specified suffix.
---@param self string Input string to check.
---@param endStr string Suffix to search for at the end of the string.
---@return boolean boolean True if the string ends with the suffix, false otherwise.
---@usage <br>
--- ```
--- "hello world":ends_with("world") -- true
--- "hello world":ends_with("hello") -- false
--- ```
local string_ends_with = function(self, endStr) end

string.ends_with = string_ends_with
string.EndsWith = string_ends_with

--- Get the leftmost characters from a string.
---@param self string Input string to extract from.
---@param length integer Number of characters to extract from the left.
---@return string string Leftmost characters.
---@usage <br>
--- ```
--- "hello":left(3) -- "hel"
--- ```
local string_left = function(self, length) end

string.left = string_left
string.Left = string_left

--- Get the rightmost characters from a string.
---@param self string Input string to extract from.
---@param length integer Number of characters to extract from the right.
---@return string string Rightmost characters.
---@usage <br>
--- ```
--- "hello":right(3) -- "llo"
--- ```
local string_right = function(self, length) end

string.right = string_right
string.Right = string_right

--- Pad a string on the left to reach the specified total width.
---@param self string Input string to pad.
---@param total_width integer Total width the padded string should reach.
---@param char string|nil Character to use for padding (default: space " ").
---@return string padded Left-padded string.
---@usage <br>
--- ```
--- "hello":pad_left(8) -- "   hello"
---
--- "hello":pad_left(7, "x") -- "xxhello"
--- ```
local string_pad_left = function(self, total_width, char) end

string.pad_left = string_pad_left
string.padleft = string_pad_left
string.PadLeft = string_pad_left

--- Pad a string on the right to reach the specified total width.
---@param self string Input string to pad.
---@param total_width integer Total width the padded string should reach.
---@param char string string|nil Character to use for padding (default: space " ").
---@return string padded Right-padded string.
---@usage <br>
--- ```
--- "hello":pad_right(8) -- "hello   "
--- "hello":pad_right(7, "x") -- "helloxx"
--- ```
local string_pad_right = function(self, total_width, char) end

string.pad_right = string_pad_right
string.padright = string_pad_right
string.PadRight = string_pad_right

--- Pads a string on the left side to reach the specified total width.
---@param self string The string to pad (or nil).
---@param total_width integer The target width of the padded string.
---@param char string|nil The character to use for padding (defaults to space).
---@return string padded The left-padded string.
local function string_padl(self, total_width, char) end

string.padl = string_padl
string.padL = string_padl
string.PadL = string_padl

--- Pads a string on the right side to reach the specified total width.
---@param self string The string to pad (or nil).
---@param total_width integer The target width of the padded string.
---@param char string|nil The character to use for padding (defaults to space).
---@return string padded The right-padded string.
local function string_padr(self, total_width, char) end

string.padr = string_padr
string.padR = string_padr
string.PadR = string_padr

--- Centers a string within the specified total width by padding on both sides.
---@param self string The string to center (or nil).
---@param total_width integer The target width of the centered string.
---@param char string|nil The character to use for padding (defaults to space).
---@return string padded The centered string.
local function string_pad_center(self, total_width, char) end

string.pad_center = string_pad_center
string.padcenter = string_pad_center
string.PadCenter = string_pad_center

--- Escape special Lua pattern characters in a string using lookup table.
--- Makes a string safe to use in Lua pattern matching operations.
---@param str string Input string to escape.
---@return string string Pattern-safe string with special characters escaped.
---@usage <br>
--- ```
--- "hello+world":pattern_safe_zero() -- "hello%+world"
--- "[test]":pattern_safe_zero() -- "%[test%]"
--- "hello\0world":pattern_safe_zero() -- "hello%zworld"
--- ```
local pattern_safe_zero = function(str) end

string.pattern_safe_zero = pattern_safe_zero
string.patternSafeZero = pattern_safe_zero
string.PatternSafeZero = pattern_safe_zero

--- Escape special Lua pattern characters in a string.
--- Makes a string safe to use in Lua pattern matching operations.
---@param str string Input string to escape.
---@return string string Pattern-safe string with special characters escaped.
---@usage <br>
--- ```
--- pattern_safe("hello+world") -- "hello%+world"
--- pattern_safe("[test]") -- "%[test%]"
--- pattern_safe("hello\0world") -- "hello" .. '\0' .. "world"
--- ```
local pattern_safe = function(str) end

string.pattern_safe = pattern_safe
string.patternSafe = pattern_safe
string.PatternSafe = pattern_safe

--- Remove leading and trailing characters from a string.
---@param self string Input string to trim.
---@param char string|nil Character pattern to trim (default: whitespace "%s").
---@return string string Trimmed string.
---@usage <br>
--- ```
--- "  hello  ":trim() -- "hello"
--- "xxhelloxx":trim("x") -- "hello"
--- ```
local string_trim = function(self, char) end

string.trim = string_trim
string.Trim = string_trim

--- Remove leading characters from a string.
---@param self string Input string to trim from the left.
---@param char string|nil Character pattern to trim (default: whitespace "%s").
---@return string string Left-trimmed string.
---@usage <br>
--- ```
--- "  hello  ":trim_left() -- "hello  "
--- "xxhelloxx":trim_left("x") -- "helloxx"
--- ```
local string_trim_left = function(self, char) end

string.trim_left = string_trim_left
string.trimleft = string_trim_left
string.TrimLeft = string_trim_left

--- Remove trailing characters from a string.
---@param self string Input string to trim from the right.
---@param char string|nil Character pattern to trim (default: whitespace "%s").
---@return string string Right-trimmed string.
---@usage <br>
--- ```
--- "  hello  ":trim_right() -- "  hello"
--- "xxhelloxx":trim_right("x") -- "xxhello"
--- ```
local string_trim_right = function(self, char) end

string.trim_right = string_trim_right
string.trimright = string_trim_right
string.TrimRight = string_trim_right

--- Rotate a string left by the specified amount.
---@param self string Input string to rotate.
---@param amount integer Number of characters to rotate left.
---@return string string Left-rotated string.
---@usage <br>
--- ```
--- "hello":rotate_left(2) -- "llohe"
--- ```
local string_rotate_left = function(self, amount) end

string.rotate_left = string_rotate_left
string.rotateleft = string_rotate_left
string.RotateLeft = string_rotate_left

--- Rotate a string right by the specified amount.
---@param self string Input string to rotate.
---@param amount integer Number of characters to rotate right.
---@return string string Right-rotated string.
---@usage <br>
--- ```
--- "hello":rotate_right(2) -- "lohel"
--- ```
local string_rotate_right = function(self, amount) end

string.rotate_right = string_rotate_right
string.rotateright = string_rotate_right
string.RotateRight = string_rotate_right

--- Rotate a string by the specified amount (positive = right, negative = left).
---@param self string Input string to rotate.
---@param rotation integer Number of characters to rotate (negative = left, positive = right).
---@return string string Rotated string.
---@usage <br>
--- ```
--- "hello":rotate(2) -- "lohel" (rotate right 2)
--- "hello":rotate(-2) -- "llohe" (rotate left 2)
--- ```
local string_rotate = function(self, rotation) end

string.rotate = string_rotate
string.Rotate = string_rotate

--- Check if a string contains the specified substring.
---@param self string Input string to search within.
---@param substring string Substring to search for.
---@return boolean boolean True if the substring is found, false otherwise.
---@usage <br>
--- ```
--- "hello world":contains("world") -- true
--- "hello world":contains("test")  -- false
--- ```
local string_contains = function(self, substring) end

string.contains = string_contains
string.Contains = string_contains

--- Find the first occurrence of a substring in a string.
---@param self string Input string to search within.
---@param substring string Substring to search for.
---@return number|nil number Starting position of the substring (1-based), or nil if not found.
---@usage <br>
--- ```
--- "hello world":index_of("world") -- 7
--- "hello world":index_of("test")  -- nil
--- "banana":index_of("na") -- 3
--- ```
local string_index_of = function(self, substring) end

string.index_of = string_index_of
string.indexof = string_index_of
string.IndexOf = string_index_of

--- Find the last occurrence of a substring in a string.
---@param self string Input string to search within.
---@param substring string Substring to search for.
---@return number|nil number Starting position of the last occurrence (1-based), or nil if not found.
---@usage <br>
--- ```
--- "hello world hello":last_index_of("hello") -- 13
--- "hello world":last_index_of("test") -- nil
--- "banana":last_index_of("na") -- 5
--- ```
local string_last_index_of = function(self, substring) end

string.last_index_of = string_last_index_of
string.lastindexof = string_last_index_of
string.LastIndexOf = string_last_index_of

--- Generate a random string of the specified length.
---@param length integer|nil Length of the random string to generate (default: 1).
---@param min integer|nil Minimum character code (default: 0).
---@param max integer|nil Maximum character code (default: 255).
---@return string string Randomly generated string.
---@usage <br>
--- ```
--- -- Generate 10 random characters (default 0-255)
--- local result = string.random(10)
---
--- -- Generate 5 random printable ASCII characters
--- local result = string.random(5, 32, 126)
--- ```
local string_random = function(length, min, max) end

string.random = string_random
string.Random = string_random
string.RandomString = string_random

--- Splits a dot-separated path into its component parts.
---@param key string The dot-separated path string to split.
---@return table array Array of path components.
---@usage <br>
--- ```
--- local parts = string.split_path("module.submodule.value")
--- -- Returns {"module", "submodule", "value"}
--- ```
local function string_split_path(key) end

string.split_path = string_split_path
string.SplitPath = string_split_path

--- Normalize path separators to the specified format.
--- Converts all path separators to either forward slash or backslash.
---@param self string Input path string to normalize.
---@param separator string|nil Target separator (default: "/" for Unix-style).
---@return string string Path with normalized separators.
---@usage <br>
--- ```
--- "folder\\subfolder/file":normalize_path_separators() -- "folder/subfolder/file"
--- "folder/subfolder/file":normalize_path_separators("\\") -- "folder\\subfolder\\file"
--- ```
local string_normalize_path_separators = function(self, separator) end

string.normalize_path_separators = string_normalize_path_separators
string.normalizePathSeparators = string_normalize_path_separators
string.NormalizePathSeparators = string_normalize_path_separators

--- Convert path separators to Unix-style (forward slash).
---@param self string Input path string to convert.
---@return string string Path with Unix-style separators.
---@usage <br>
--- ```
--- "folder\\subfolder\\file":to_unix_path() -- "folder/subfolder/file"
--- ```
local string_to_unix_path = function(self) end

string.to_unix_path = string_to_unix_path
string.toUnixPath = string_to_unix_path
string.ToUnixPath = string_to_unix_path

--- Convert path separators to Windows-style (backslash).
---@param self string Input path string to convert.
---@return string string Path with Windows-style separators.
---@usage <br>
--- ```
--- "folder/subfolder/file":to_windows_path() -- "folder\\subfolder\\file"
--- ```
local string_to_windows_path = function(self) end

string.to_windows_path = string_to_windows_path
string.toWindowsPath = string_to_windows_path
string.ToWindowsPath = string_to_windows_path

--- Normalize a file path by resolving parent directory references and removing redundant separators.
--- Handles ".." and "." components and removes duplicate separators.
---@param self string Input path string to normalize.
---@param separator string|nil Path separator to use in result (default: "/").
---@return string string Normalized path.
---@usage <br>
--- ```
--- "folder/../subfolder/./file":normalize_path() -- "subfolder/file"
--- "folder//subfolder/../file":normalize_path() -- "folder/file"
--- ```
local string_normalize_path = function(self, separator) end

string.normalize_path = string_normalize_path
string.normalizePath = string_normalize_path
string.NormalizePath = string_normalize_path

--- Get the directory portion of a file path.
---@param self string Input file path.
---@return string string Directory path without the filename.
---@usage <br>
--- ```
--- "folder/subfolder/file.txt":path_dir() -- "folder/subfolder"
--- "file.txt":path_dir() -- ""
--- ```
local string_path_dir = function(self) end

string.path_dir = string_path_dir
string.pathDir = string_path_dir
string.dirname = string_path_dir
string.PathDir = string_path_dir
string.DirName = string_path_dir

--- Get the filename portion of a file path.
---@param self string Input file path.
---@return string string Filename without directory path.
---@usage <br>
--- ```
--- "folder/subfolder/file.txt":path_file() -- "file.txt"
--- "file.txt":path_file() -- "file.txt"
--- ```
local string_path_file = function(self) end

string.path_file = string_path_file
string.pathFile = string_path_file
string.basename = string_path_file
string.PathFile = string_path_file
string.BaseName = string_path_file

--- Get the file extension from a file path.
---@param self string Input file path.
---@return string string File extension (without dot), or empty string if no extension.
---@usage <br>
--- ```
--- "file.txt":path_ext() -- "txt"
--- "folder/file.tar.gz":path_ext() -- "gz"
--- "file":path_ext() -- ""
--- ```
local string_path_ext = function(self) end

string.path_ext = string_path_ext
string.pathExt = string_path_ext
string.extension = string_path_ext
string.PathExt = string_path_ext
string.Extension = string_path_ext

--- Get the filename without extension from a file path.
---@param self string Input file path.
---@return string string Filename without extension.
---@usage <br>
--- ```
--- "file.txt":path_name() -- "file"
--- "folder/file.tar.gz":path_name() -- "file.tar"
--- "file":path_name() -- "file"
--- ```
local string_path_name = function(self) end

string.path_name = string_path_name
string.pathName = string_path_name
string.name_without_ext = string_path_name
string.PathName = string_path_name
string.NameWithoutExt = string_path_name

--- Join multiple path components into a single path.
--- Handles separator insertion and normalizes the result.
---@param ... string Path components to join.
---@return string string Joined path.
---@usage <br>
--- ```
--- string.path_join("folder", "subfolder", "file.txt") -- "folder/subfolder/file.txt"
--- string.path_join("folder/", "/subfolder/", "file.txt") -- "folder/subfolder/file.txt"
--- ```
local string_path_join = function(...) end

string.path_join = string_path_join
string.pathJoin = string_path_join
string.PathJoin = string_path_join

--- Check if a path is absolute.
---@param self string Input path to check.
---@return boolean boolean True if path is absolute, false otherwise.
---@usage <br>
--- ```
--- "/folder/file":is_absolute_path() -- true
--- "C:\\folder\\file":is_absolute_path() -- true
--- "folder/file":is_absolute_path() -- false
--- ```
local string_is_absolute_path = function(self) end

string.is_absolute_path = string_is_absolute_path
string.isAbsolutePath = string_is_absolute_path
string.IsAbsolutePath = string_is_absolute_path

--- Convert a relative path to an absolute path based on a base path.
---@param self string Relative path to convert.
---@param base_path string Base directory path (default: current directory).
---@return string string Absolute path.
---@usage <br>
--- ```
--- "file.txt":to_absolute_path("/base/folder") -- "/base/folder/file.txt"
--- "../file.txt":to_absolute_path("/base/folder") -- "/base/file.txt"
--- ```
local string_to_absolute_path = function(self, base_path) end

string.to_absolute_path = string_to_absolute_path
string.toAbsolutePath = string_to_absolute_path
string.ToAbsolutePath = string_to_absolute_path

--- Convert a string to snake_case.
--- Converts spaces, hyphens, camelCase, and PascalCase to lowercase with underscores.
---@param self string Input string to convert.
---@return string string Snake case version of the input.
---@usage <br>
--- ```
--- "Hello World":to_snake_case() -- "hello_world"
--- "helloWorld":to_snake_case() -- "hello_world"
--- "HelloWorld":to_snake_case() -- "hello_world"
--- "hello-world":to_snake_case() -- "hello_world"
--- ```
local string_to_snake_case = function(self) end

string.to_snake_case = string_to_snake_case
string.toSnakeCase = string_to_snake_case
string.ToSnakeCase = string_to_snake_case

--- Convert a string to camelCase.
--- First character is lowercase, subsequent word boundaries are capitalized.
---@param self string Input string to convert.
---@return string string Camel case version of the input.
---@usage <br>
--- ```
--- "hello world":to_camel_case() -- "helloWorld"
--- "hello_world":to_camel_case() -- "helloWorld"
--- "hello-world":to_camel_case() -- "helloWorld"
--- "HelloWorld":to_camel_case() -- "helloWorld"
--- ```
local string_to_camel_case = function(self) end

string.to_camel_case = string_to_camel_case
string.toCamelCase = string_to_camel_case
string.ToCamelCase = string_to_camel_case

--- Convert a string to PascalCase.
--- All words are capitalized and concatenated without separators.
---@param self string Input string to convert.
---@return string string Pascal case version of the input.
---@usage <br>
--- ```
--- "hello world":to_pascal_case() -- "HelloWorld"
--- "hello_world":to_pascal_case() -- "HelloWorld"
--- "hello-world":to_pascal_case() -- "HelloWorld"
--- "helloWorld":to_pascal_case() -- "HelloWorld"
--- ```
local string_to_pascal_case = function(self) end

string.to_pascal_case = string_to_pascal_case
string.toPascalCase = string_to_pascal_case
string.ToPascalCase = string_to_pascal_case

--- Resolve a range (start_index, end_index) to absolute indices within a given length.
--- Handles negative indices (count from end), zero, and clamps to valid range [1, len].
---@param len integer The length of the string/table.
---@param start_index integer|nil Starting index (default: 1). Negative indices count from end.
---@param end_index integer|nil Ending index (default: len). Negative indices count from end.
---@return integer start_index Resolved absolute start index (clamped to [1, len]).
---@return integer end_index Resolved absolute end index (clamped to [1, len]).
---@return boolean is_empty True if the resulting range is empty (start > end).
local function resolve_absolute_range(len, start_index, end_index) end

string.resolve_absolute_range = resolve_absolute_range
string.resolveAbsoluteRange = resolve_absolute_range
string.ResolveAbsoluteRange = resolve_absolute_range

--- Check if the specified string value represents a printable ASCII string.
--- Printable ASCII characters are in the range 32-126 (space through tilde).
---@param self string String value to check.
---@param start_index integer|nil Starting index to check from (default: 1). Negative indices count from end.
---@param end_index integer|nil Ending index to check to (default: #self). Negative indices count from end.
---@return boolean boolean True if all characters in range are printable (32-126), false otherwise.
---@usage <br>
--- ```
--- "Hello World!":is_printable() -- true
--- "Hello\nWorld":is_printable() -- false (newline is not printable)
--- "":is_printable() -- true (empty string is considered printable)
--- "Tab\there":is_printable() -- false (tab is not printable)
--- "":is_printable(1, 0) -- true (empty range)
--- "abc":is_printable(1, 1) -- true (only checks "a")
--- "abc":is_printable(-2) -- true (checks "bc")
--- "abc":is_printable(-3, -2) -- true (checks "ab")
--- "abc":is_printable(-1, -1) -- true (checks only "c")
--- ```
local function string_is_printable(self, start_index, end_index) end

string.is_printable = string_is_printable
string.isPrintable = string_is_printable
string.IsPrintable = string_is_printable

return string
