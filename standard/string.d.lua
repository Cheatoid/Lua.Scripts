-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

---@meta

---@class string
local string = {}

--- Check if a character is uppercase.
---@param c string Single character to check.
---@return boolean boolean True if uppercase, false otherwise.
---@usage <br>
--- ```
--- string.is_upper("A") -- true
--- string.is_upper("a") -- false
--- ```
local string_is_upper = function(c) end

string.is_upper = string_is_upper
string.isUpper = string_is_upper
string.IsUpper = string_is_upper

--- Check if a character is lowercase.
---@param c string Single character to check.
---@return boolean boolean True if lowercase, false otherwise.
---@usage <br>
--- ```
--- string.is_lower("a") -- true
--- string.is_lower("A") -- false
--- ```
local string_is_lower = function(c) end

string.is_lower = string_is_lower
string.isLower = string_is_lower
string.IsLower = string_is_lower

--- Check if a character is alphabetic.
---@param c string Single character to check.
---@return boolean boolean True if alphabetic, false otherwise.
---@usage <br>
--- ```
--- string.is_alpha("a") -- true
--- string.is_alpha("1") -- false
--- ```
local string_is_alpha = function(c) end

string.is_alpha = string_is_alpha
string.isAlpha = string_is_alpha
string.IsAlpha = string_is_alpha

--- Check if a character is a digit.
---@param c string Single character to check.
---@return boolean boolean True if digit, false otherwise.
---@usage <br>
--- ```
--- string.is_digit("1") -- true
--- string.is_digit("a") -- false
--- ```
local string_is_digit = function(c) end

string.is_digit = string_is_digit
string.isDigit = string_is_digit
string.IsDigit = string_is_digit

--- Check if a character is whitespace.
---@param c string Single character to check.
---@return boolean boolean True if whitespace, false otherwise.
---@usage <br>
--- ```
--- string.is_space(" ")  -- true
--- string.is_space("\n") -- true
--- string.is_space("a")  -- false
--- ```
local string_is_space = function(c) end

string.is_space = string_is_space
string.isSpace = string_is_space
string.IsSpace = string_is_space

--- Check if a character is alphanumeric.
---@param c string Single character to check.
---@return boolean boolean True if alphanumeric, false otherwise.
---@usage <br>
--- ```
--- string.is_alphanum("a") -- true
--- string.is_alphanum("1") -- true
--- string.is_alphanum(" ") -- false
--- ```
local string_is_alphanum = function(c) end

string.is_alphanum = string_is_alphanum
string.isAlphaNum = string_is_alphanum
string.IsAlphaNum = string_is_alphanum

--- Check if a character is a control character.
---@param c string Single character to check.
---@return boolean boolean True if control character, false otherwise.
---@usage <br>
--- ```
--- string.is_control("\n") -- true
--- string.is_control("a") -- false
--- ```
local string_is_control = function(c) end

string.is_control = string_is_control
string.isControl = string_is_control
string.IsControl = string_is_control

--- Check if a character is punctuation.
---@param c string Single character to check.
---@return boolean boolean True if punctuation, false otherwise.
---@usage <br>
--- ```
--- string.is_punct(".") -- true
--- string.is_punct("a") -- false
--- ```
local string_is_punct = function(c) end

string.is_punct = string_is_punct
string.isPunct = string_is_punct
string.IsPunct = string_is_punct

--- Iterate over lines in a string using an iterator.<br>
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

--- Split a string into lines and return them as a table.<br>
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

--- Split a string using a plain separator and return an iterator.<br>
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

--- Split a string using a Lua pattern as separator and return an iterator.<br>
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

--- Split a string into fixed-size chunks and return them as a table.<br>
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

--- Concatenate multiple values into a single string.<br>
--- If the native string.concat is available, it will be used; otherwise, a fallback implementation using table.concat is provided.
---@param ... any Values to concatenate (will be converted to strings).
---@return string string Concatenated string.
---@usage <br>
--- ```
--- string.concat("hello", " ", "world") -- "hello world"
--- string.concat("a", "b", "c") -- "abc"
--- ```
local string_concat = function(...) end

string.concat = string_concat
string.Concat = string_concat

--- Convert a string to a table of individual characters.<br>
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

--- Split a string into parts using a separator and return as a table.<br>
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

--- Split a string by a delimiter (UTF-8 aware if available).<br>
--- Supports both pattern and plain text separators. Handles empty delimiters by splitting into characters.
---@param str string String to split.
---@param delimiter string|nil Delimiter to split on (default: whitespace pattern "%s+").
---@param max_splits number|nil Maximum number of splits (default: infinity).
---@return table array Array of split parts.
---@usage <br>
--- ```
--- string.split("a,b,c", ",") -- {"a", "b", "c"}
--- string.split("hello world") -- {"hello", "world"}
--- string.split("hello", "") -- {"h", "e", "l", "l", "o"}
--- string.split("a,b,c,d", ",", 2) -- {"a", "b", "c,d"}
--- ```
local string_split = function(str, delimiter, max_splits) end

string.split = string_split

--- Replace all occurrences of a search value with a replacement value.<br>
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
---@param self string The string to pad.
---@param total_width integer The target width of the padded string.
---@param char string|nil The character to use for padding (default: space " ").
---@return string padded The left-padded string.
local string_padl = function(self, total_width, char) end

string.padl = string_padl
string.padL = string_padl
string.PadL = string_padl

--- Pads a string on the right side to reach the specified total width.
---@param self string The string to pad.
---@param total_width integer The target width of the padded string.
---@param char string|nil The character to use for padding (default: space " ").
---@return string padded The right-padded string.
local string_padr = function(self, total_width, char) end

string.padr = string_padr
string.padR = string_padr
string.PadR = string_padr

--- Centers a string within the specified total width by padding on both sides.
---@param self string The string to center.
---@param total_width integer The target width of the centered string.
---@param char string|nil The character to use for padding (default: space " ").
---@return string padded The centered string.
local string_pad_center = function(self, total_width, char) end

string.pad_center = string_pad_center
string.padcenter = string_pad_center
string.PadCenter = string_pad_center

--- Converts a Lua string to a JavaScript-safe string literal.<br>
--- Escapes special characters including backslashes, quotes, newlines, etc.<br>
--- The backslash is escaped last to avoid corrupting other escape sequences.
--- @param self string The string to escape.
--- @param quote string|nil The quote character to use ('"') or ("'"). If nil, returns escaped string without quotes.
--- @return string string The escaped string, optionally wrapped in quotes.
--- @usage <br>
--- ```
--- string.to_safe_string('hello\nworld') -- returns '"hello\\nworld"'
--- string.to_safe_string('hello\nworld', "'") -- returns "'hello\\nworld'"
--- string.to_safe_string('hello\nworld', nil) -- returns 'hello\\nworld'
--- ```
local string_to_safe_string = function(self, quote) end

string.to_safe_string = string_to_safe_string
string.toSafeString = string_to_safe_string
string.ToSafeString = string_to_safe_string

--- Escape a string for safe inclusion in JavaScript.<br>
--- Escapes backslashes, quotes, control characters, template literals, dollar signs, braces,
--- and Unicode line separators (U+2028, U+2029).
---@param self string Input string to escape.
---@return string string JavaScript-safe escaped string.
---@usage <br>
--- ```
--- 'hello "world"':javascript_safe() -- "hello \\\"world\\\""
--- "line1\nline2":javascript_safe() -- "line1\\nline2"
--- ```
local string_javascript_safe = function(self) end

string.javascript_safe = string_javascript_safe
string.javascriptSafe = string_javascript_safe
string.JavascriptSafe = string_javascript_safe

--- Escape special Lua pattern characters in a string using lookup table.<br>
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

--- Escape special Lua pattern characters in a string.<br>
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

--- Reverse a string (UTF-8 aware if available).<br>
--- Returns a new string with characters in reverse order.
---@param self string Input string to reverse.
---@return string string Reversed string.
---@usage <br>
--- ```
--- "hello":reverse() -- "olleh"
--- "héllo":reverse() -- "olléh" (if UTF-8 available)
--- ```
local string_reverse = function(self) end

string.reverse = string_reverse
string.Reverse = string_reverse

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

--- Generate a random UUID (v4) string.<br>
--- Returns a string in the format "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx" where x is a random hex digit
--- and y is one of 8, 9, a, or b (as per the UUID v4 specification).
---@return string uuid A randomly generated UUID v4 string.
---@usage <br>
--- ```
--- local id = string.uuid()
--- -- Returns something like: "a3bb189e-8bf9-4888-9912-ace4e6543002"
--- ```
string.uuid = function() end

--- Convert a string to its hexadecimal representation.<br>
--- Each byte of the input string is encoded as two hex characters.
---@param self string Input string to encode.
---@param uppercase boolean|nil If true, uses uppercase hex characters (default: false, lowercase).
---@return string hex Hexadecimal encoded string.
---@usage <br>
--- ```
--- "Hello":to_hex() -- "48656c6c6f"
--- "Hello":to_hex(true) -- "48656C6C6F"
--- "\0\255":to_hex() -- "00ff"
--- ```
local string_to_hex = function(self, uppercase) end

string.to_hex = string_to_hex
string.ToHex = string_to_hex

--- Decode a hexadecimal string back to its binary representation.<br>
--- Each pair of hex characters is decoded into a single byte.
---@param self string Hexadecimal string to decode (must have even length).
---@return string binary Decoded binary string.
---@usage <br>
--- ```
--- "48656c6c6f":from_hex() -- "Hello"
--- "00ff":from_hex() -- "\0\255"
--- ```
local string_from_hex = function(self) end

string.from_hex = string_from_hex
string.FromHex = string_from_hex

--- Splits a dot-separated path into its component parts.
---@param key string The dot-separated path string to split.
---@return table array Array of path components.
---@usage <br>
--- ```
--- local parts = string.split_path("module.submodule.value")
--- -- Returns {"module", "submodule", "value"}
--- ```
local string_split_path = function(key) end

string.split_path = string_split_path
string.SplitPath = string_split_path

--- Normalize path separators to the specified format.<br>
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

--- Normalize a file path by resolving parent directory references and removing redundant separators.<br>
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

--- Join multiple path components into a single path.<br>
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

--- Check if a path is relative.
---@param self string Input path to check.
---@return boolean boolean True if path is relative, false otherwise.
---@usage <br>
--- ```
--- "folder/file":is_relative_path() -- true
--- "../file":is_relative_path() -- true
--- "/folder/file":is_relative_path() -- false
--- "C:\\folder\\file":is_relative_path() -- false
--- ```
local string_is_relative_path = function(self) end

string.is_relative_path = string_is_relative_path
string.isRelativePath = string_is_relative_path
string.IsRelativePath = string_is_relative_path

--- Get a relative path from a base path to a target path.
---@param self string Target path to make relative.
---@param base_path string Base directory path.
---@return string string Relative path from base to target.
---@usage <br>
--- ```
--- "/a/b/c":path_relative("/a/b") -- "c"
--- "/a/b/c":path_relative("/a") -- "b/c"
--- "/a/b/c":path_relative("/x/y") -- "/a/b/c" (no common ancestor)
--- ```
local string_path_relative = function(self, base_path) end

string.path_relative = string_path_relative
string.pathRelative = string_path_relative
string.PathRelative = string_path_relative

--- Split a path into directory and file components.
---@param self string Input file path.
---@return string dir Directory path.
---@return string file Filename.
---@usage <br>
--- ```
--- "folder/file.txt":path_split() -- "folder", "file.txt"
--- "file.txt":path_split() -- "", "file.txt"
--- ```
local string_path_split = function(self) end

string.path_split = string_path_split
string.pathSplit = string_path_split
string.PathSplit = string_path_split

--- Split a filename into name and extension components.
---@param self string Input file path or filename.
---@return string name Filename without extension.
---@return string ext Extension (without dot).
---@usage <br>
--- ```
--- "file.txt":path_split_ext() -- "file", "txt"
--- "folder/file.tar.gz":path_split_ext() -- "file.tar", "gz"
--- "file":path_split_ext() -- "file", ""
--- ```
local string_path_split_ext = function(self) end

string.path_split_ext = string_path_split_ext
string.pathSplitExt = string_path_split_ext
string.PathSplitExt = string_path_split_ext

--- Check if a path has a file extension.
---@param self string Input file path.
---@return boolean boolean True if path has an extension, false otherwise.
---@usage <br>
--- ```
--- "file.txt":path_has_extension() -- true
--- "file":path_has_extension() -- false
--- "folder/.hidden":path_has_extension() -- false
--- ```
local string_path_has_extension = function(self) end

string.path_has_extension = string_path_has_extension
string.pathHasExtension = string_path_has_extension
string.PathHasExtension = string_path_has_extension

--- Change the file extension of a path.
---@param self string Input file path.
---@param new_ext string New extension (with or without dot).
---@return string string Path with changed extension.
---@usage <br>
--- ```
--- "file.txt":path_change_extension("md") -- "file.md"
--- "file.txt":path_change_extension(".lua") -- "file.lua"
--- "file":path_change_extension("txt") -- "file.txt"
--- ```
local string_path_change_extension = function(self, new_ext) end

string.path_change_extension = string_path_change_extension
string.pathChangeExtension = string_path_change_extension
string.PathChangeExtension = string_path_change_extension

--- Add an extension to a path if it doesn't already have one.
---@param self string Input file path.
---@param ext string Extension to add (with or without dot).
---@return string string Path with extension added (if needed).
---@usage <br>
--- ```
--- "file":path_add_extension("txt") -- "file.txt"
--- "file.txt":path_add_extension("txt") -- "file.txt" (no change)
--- ```
local string_path_add_extension = function(self, ext) end

string.path_add_extension = string_path_add_extension
string.pathAddExtension = string_path_add_extension
string.PathAddExtension = string_path_add_extension

--- Remove the file extension from a path.
---@param self string Input file path.
---@return string string Path without extension.
---@usage <br>
--- ```
--- "file.txt":path_remove_extension() -- "file"
--- "folder/file.tar.gz":path_remove_extension() -- "folder/file.tar"
--- "file":path_remove_extension() -- "file"
--- ```
local string_path_remove_extension = function(self) end

string.path_remove_extension = string_path_remove_extension
string.pathRemoveExtension = string_path_remove_extension
string.PathRemoveExtension = string_path_remove_extension

--- Get the common prefix of two paths.
---@param self string First path.
---@param other string Second path.
---@return string string Common prefix path.
---@usage <br>
--- ```
--- "/a/b/c":path_common_prefix("/a/b/d") -- "a/b"
--- "/a/b/c":path_common_prefix("/x/y/z") -- ""
--- ```
local string_path_common_prefix = function(self, other) end

string.path_common_prefix = string_path_common_prefix
string.pathCommonPrefix = string_path_common_prefix
string.PathCommonPrefix = string_path_common_prefix

--- Get all path components as an array.
---@param self string Input path.
---@return table array Array of path components.
---@usage <br>
--- ```
--- "a/b/c":path_components() -- {"a", "b", "c"}
--- "/a/b/c":path_components() -- {"a", "b", "c"}
--- ```
local string_path_components = function(self) end

string.path_components = string_path_components
string.pathComponents = string_path_components
string.PathComponents = string_path_components

--- Build a path from an array of components.
---@param components table Array of path components.
---@param separator string|nil Separator to use (default: "/").
---@return string string Built path.
---@usage <br>
--- ```
--- string.path_from_components({"a", "b", "c"}) -- "a/b/c"
--- string.path_from_components({"a", "b", "c"}, "\\") -- "a\\b\\c"
--- ```
local string_path_from_components = function(components, separator) end

string.path_from_components = string_path_from_components
string.pathFromComponents = string_path_from_components
string.PathFromComponents = string_path_from_components

--- Remove trailing separator(s) from a path.
---@param self string Input path.
---@param separator string|nil Separator to trim (default: "/").
---@return string string Path without trailing separator.
---@usage <br>
--- ```
--- "folder/":path_trim_trailing_separator() -- "folder"
--- "folder///":path_trim_trailing_separator() -- "folder"
--- "folder":path_trim_trailing_separator() -- "folder"
--- ```
local string_path_trim_trailing_separator = function(self, separator) end

string.path_trim_trailing_separator = string_path_trim_trailing_separator
string.pathTrimTrailingSeparator = string_path_trim_trailing_separator
string.PathTrimTrailingSeparator = string_path_trim_trailing_separator

--- Check if a path has a trailing separator.
---@param self string Input path.
---@param separator string|nil Separator to check for (default: "/").
---@return boolean boolean True if path has trailing separator, false otherwise.
---@usage <br>
--- ```
--- "folder/":path_has_trailing_separator() -- true
--- "folder":path_has_trailing_separator() -- false
--- ```
local string_path_has_trailing_separator = function(self, separator) end

string.path_has_trailing_separator = string_path_has_trailing_separator
string.pathHasTrailingSeparator = string_path_has_trailing_separator
string.PathHasTrailingSeparator = string_path_has_trailing_separator

--- Remove leading separator(s) from a path.
---@param self string Input path.
---@param separator string|nil Separator to trim (default: "/").
---@return string string Path without leading separator.
---@usage <br>
--- ```
--- "/folder":path_trim_leading_separator() -- "folder"
--- "///folder":path_trim_leading_separator() -- "folder"
--- "folder":path_trim_leading_separator() -- "folder"
--- ```
local string_path_trim_leading_separator = function(self, separator) end

string.path_trim_leading_separator = string_path_trim_leading_separator
string.pathTrimLeadingSeparator = string_path_trim_leading_separator
string.PathTrimLeadingSeparator = string_path_trim_leading_separator

--- Check if a path has a leading separator.
---@param self string Input path.
---@param separator string|nil Separator to check for (default: "/").
---@return boolean boolean True if path has leading separator, false otherwise.
---@usage <br>
--- ```
--- "/folder":path_has_leading_separator() -- true
--- "folder":path_has_leading_separator() -- false
--- ```
local string_path_has_leading_separator = function(self, separator) end

string.path_has_leading_separator = string_path_has_leading_separator
string.pathHasLeadingSeparator = string_path_has_leading_separator
string.PathHasLeadingSeparator = string_path_has_leading_separator

--- Check if two paths refer to the same location (normalized).
---@param self string First path.
---@param other string Second path.
---@return boolean boolean True if paths are the same, false otherwise.
---@usage <br>
--- ```
--- "a/b/c":path_is_same("a//b/./c") -- true
--- "/a/b":path_is_same("/a/b") -- true
--- "a/b":path_is_same("c/d") -- false
--- ```
local string_path_is_same = function(self, other) end

string.path_is_same = string_path_is_same
string.pathIsSame = string_path_is_same
string.PathIsSame = string_path_is_same

--- Get the Windows drive letter from a path.
---@param self string Input path.
---@return string string Drive letter (e.g., "C:") or empty string.
---@usage <br>
--- ```
--- "C:\\folder\\file":path_get_drive() -- "C:"
--- "folder/file":path_get_drive() -- ""
--- ```
local string_path_get_drive = function(self) end

string.path_get_drive = string_path_get_drive
string.pathGetDrive = string_path_get_drive
string.PathGetDrive = string_path_get_drive

--- Remove the Windows drive letter from a path.
---@param self string Input path.
---@return string string Path without drive letter.
---@usage <br>
--- ```
--- "C:\\folder\\file":path_without_drive() -- "\\folder\\file"
--- "folder/file":path_without_drive() -- "folder/file"
--- ```
local string_path_without_drive = function(self) end

string.path_without_drive = string_path_without_drive
string.pathWithoutDrive = string_path_without_drive
string.PathWithoutDrive = string_path_without_drive

--- Get the root portion of a path.
---@param self string Input path.
---@return string string Root path (e.g., "/" or "C:\").
---@usage <br>
--- ```
--- "/folder/file":path_get_root() -- "/"
--- "C:\\folder\\file":path_get_root() -- "C:\\"
--- "folder/file":path_get_root() -- ""
--- ```
local string_path_get_root = function(self) end

string.path_get_root = string_path_get_root
string.pathGetRoot = string_path_get_root
string.PathGetRoot = string_path_get_root

--- Check if a path is a root path.
---@param self string Input path.
---@return boolean boolean True if path is a root, false otherwise.
---@usage <br>
--- ```
--- "/":path_is_root() -- true
--- "C:\\":path_is_root() -- true
--- "/folder":path_is_root() -- false
--- ```
local string_path_is_root = function(self) end

string.path_is_root = string_path_is_root
string.pathIsRoot = string_path_is_root
string.PathIsRoot = string_path_is_root

--- Check if one path is an ancestor of another path.
---@param self string Potential descendant path.
---@param potential_ancestor string Potential ancestor path.
---@return boolean boolean True if ancestor is ancestor of self, false otherwise.
---@usage <br>
--- ```
--- "/a/b/c":path_ancestor("/a/b") -- true
--- "/a/b/c":path_ancestor("/a") -- true
--- "/a/b/c":path_ancestor("/x") -- false
--- ```
local string_path_ancestor = function(self, potential_ancestor) end

string.path_ancestor = string_path_ancestor
string.pathAncestor = string_path_ancestor
string.PathAncestor = string_path_ancestor

--- Clean a path by normalizing separators and removing redundant slashes.<br>
--- Replaces backslashes with forward slashes, collapses multiple slashes into one,<br>
--- and removes trailing slash unless it's the root. Does not resolve ".." or "." components.
---@param self string Input path.
---@return string string Cleaned path.
---@usage <br>
--- ```
--- "folder\\subfolder/file":path_clean() -- "folder/subfolder/file"
--- "folder//subfolder/":path_clean() -- "folder/subfolder"
--- "/":path_clean() -- "/"
--- ```
local string_path_clean = function(self) end

string.path_clean = string_path_clean
string.pathClean = string_path_clean
string.PathClean = string_path_clean

--- Get the parent directory of a path.<br>
--- Returns "." if the path is already at the root or has no parent.
---@param self string Input path.
---@return string string Parent directory path.
---@usage <br>
--- ```
--- "folder/file":path_parent() -- "folder"
--- "folder/subfolder/file":path_parent() -- "folder/subfolder"
--- "file":path_parent() -- "."
--- "/":path_parent() -- "."
--- ```
local string_path_parent = function(self) end

string.path_parent = string_path_parent
string.pathParent = string_path_parent
string.PathParent = string_path_parent

--- Check if a path has a parent directory.<br>
--- Returns false if the path is at the root or has no parent.
---@param self string Input path.
---@return boolean boolean True if path has a parent, false otherwise.
---@usage <br>
--- ```
--- "folder/file":path_has_parent() -- true
--- "file":path_has_parent() -- false
--- "/":path_has_parent() -- false
--- ```
local string_path_has_parent = function(self) end

string.path_has_parent = string_path_has_parent
string.pathHasParent = string_path_has_parent
string.PathHasParent = string_path_has_parent

--- Get the depth of a path (number of components).
---@param self string Input path.
---@return integer number Number of path components.
---@usage <br>
--- ```
--- "a/b/c":path_depth() -- 3
--- "file":path_depth() -- 1
--- "/a/b":path_depth() -- 2
--- ```
local string_path_depth = function(self) end

string.path_depth = string_path_depth
string.pathDepth = string_path_depth
string.PathDepth = string_path_depth

--- Check if a path is a child of another path.
---@param self string Potential child path.
---@param parent string Potential parent path.
---@return boolean boolean True if self is a child of parent, false otherwise.
---@usage <br>
--- ```
--- "a/b/c":path_is_child("a/b") -- true
--- "a/b/c":path_is_child("a") -- true
--- "a/b/c":path_is_child("x") -- false
--- ```
local string_path_is_child = function(self, parent) end

string.path_is_child = string_path_is_child
string.pathIsChild = string_path_is_child
string.PathIsChild = string_path_is_child

--- Sanitize a path by removing invalid filesystem characters.<br>
--- Removes control characters and Windows-invalid characters (<>:"|?*).
---@param self string Input path to sanitize.
---@return string string Sanitized path.
---@usage <br>
--- ```
--- "folder<>file":path_sanitize() -- "folderfile"
--- "test|file":path_sanitize() -- "testfile"
--- "  folder  ":path_sanitize() -- "folder"
--- ```
local string_path_sanitize = function(self) end

string.path_sanitize = string_path_sanitize
string.pathSanitize = string_path_sanitize
string.PathSanitize = string_path_sanitize

--- Convert a relative path to an absolute path (alias for to_absolute_path).<br>
---@param self string Relative path to convert.
---@param base_path string Base directory path (default: current directory).
---@return string string Absolute path.
---@usage <br>
--- ```
--- "file.txt":path_make_absolute("/base/folder") -- "/base/folder/file.txt"
--- "../file.txt":path_make_absolute("/base/folder") -- "/base/file.txt"
--- ```
local string_path_make_absolute = function(self, base_path) end

string.path_make_absolute = string_path_make_absolute
string.pathMakeAbsolute = string_path_make_absolute
string.PathMakeAbsolute = string_path_make_absolute

--- Get a relative path from a base path to a target path (alias for path_relative).<br>
---@param self string Target path to make relative.
---@param base_path string Base directory path.
---@return string string Relative path from base to target.
---@usage <br>
--- ```
--- "/a/b/c":path_make_relative("/a/b") -- "c"
--- "/a/b/c":path_make_relative("/a") -- "b/c"
--- "/a/b/c":path_make_relative("/x/y") -- "/a/b/c" (no common ancestor)
--- ```
local string_path_make_relative = function(self, base_path) end

string.path_make_relative = string_path_make_relative
string.pathMakeRelative = string_path_make_relative
string.PathMakeRelative = string_path_make_relative

--- Detect the casing style of an identifier.<br>
--- Analyzes the string to determine its naming convention based on separators and letter casing.
---@param self string Input string to analyze.
---@return "camelCase" | "PascalCase" | "snake_case" | "SCREAMING_SNAKE_CASE" | "kebab-case" | "space_case" | "UPPER_SPACE_CASE" | "lowercase" | "UPPERCASE" | "unknown" string Detected casing style name.
---@usage <br>
--- ```
--- "helloWorld":detect_casing_style() -- "camelCase"
--- "HelloWorld":detect_casing_style() -- "PascalCase"
--- "hello_world":detect_casing_style() -- "snake_case"
--- "HELLO_WORLD":detect_casing_style() -- "SCREAMING_SNAKE_CASE"
--- "hello-world":detect_casing_style() -- "kebab-case"
--- "hello world":detect_casing_style() -- "space_case"
--- "HELLO WORLD":detect_casing_style() -- "UPPER_SPACE_CASE"
--- "hello":detect_casing_style() -- "lowercase"
--- "HELLO":detect_casing_style() -- "UPPERCASE"
--- "":detect_casing_style() -- "unknown"
--- ```
local string_detect_casing_style = function(self) end

string.detect_casing_style = string_detect_casing_style
string.detectCasingStyle = string_detect_casing_style
string.DetectCasingStyle = string_detect_casing_style

--- Convert a string to snake_case.<br>
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

--- Convert a string to camelCase.<br>
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

--- Convert a string to PascalCase.<br>
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

--- Resolve a range (start_index, end_index) to absolute indices within a given length.<br>
--- Handles negative indices (count from end), zero, and clamps to valid range [1, len].
---@param len integer The length of the string/table.
---@param start_index integer|nil Starting index (default: 1). Negative indices count from end.
---@param end_index integer|nil Ending index (default: len). Negative indices count from end.
---@return integer start_index Resolved absolute start index (clamped to [1, len]).
---@return integer end_index Resolved absolute end index (clamped to [1, len]).
---@return boolean is_empty True if the resulting range is empty (start > end).
local resolve_absolute_range = function(len, start_index, end_index) end

string.resolve_absolute_range = resolve_absolute_range
string.resolveAbsoluteRange = resolve_absolute_range
string.ResolveAbsoluteRange = resolve_absolute_range

--- Check if the specified string value represents a printable ASCII string.<br>
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
local string_is_printable = function(self, start_index, end_index) end

string.is_printable = string_is_printable
string.isPrintable = string_is_printable
string.IsPrintable = string_is_printable

--- URL-encode a string using percent encoding.<br>
--- Encodes characters that are not unreserved (A-Z, a-z, 0-9, hyphen, period, underscore, tilde).
---@param self string Input string to encode.
---@return string string URL-encoded string.
---@usage <br>
--- ```
--- "hello world":url_encode() -- "hello%20world"
--- "user@email.com":url_encode() -- "user%40email.com"
--- "test/data":url_encode() -- "test%2Fdata"
--- ```
local string_url_encode = function(self) end

string.url_encode = string_url_encode
string.urlEncode = string_url_encode
string.UrlEncode = string_url_encode

--- URL-decode a percent-encoded string.<br>
--- Converts percent-encoded characters back to their original form and converts + to space.
---@param self string Input string to decode.
---@return string string URL-decoded string.
---@usage <br>
--- ```
--- "hello%20world":url_decode() -- "hello world"
--- "user%40email.com":url_decode() -- "user@email.com"
--- "test%2Fdata":url_decode() -- "test/data"
--- "hello+world":url_decode() -- "hello world"
--- ```
local string_url_decode = function(self) end

string.url_decode = string_url_decode
string.urlDecode = string_url_decode
string.UrlDecode = string_url_decode

--- Parse a query string into a table.<br>
--- Handles duplicate keys by converting values to arrays.
---@param self string Query string to parse.
---@return table table Table of key-value pairs (decoded).
---@usage <br>
--- ```
--- "key1=value1&key2=value2":parse_query() -- { key1 = "value1", key2 = "value2" }
--- "name=John&name=Jane":parse_query() -- { name = { "John", "Jane" } }
--- "key1&key2=value":parse_query() -- { key1 = "", key2 = "value" }
--- ```
local string_parse_query = function(self) end

string.parse_query = string_parse_query
string.parseQuery = string_parse_query
string.ParseQuery = string_parse_query

--- Build a query string from a table.<br>
--- URL-encodes keys and values. Handles array values for duplicate keys.
---@param tbl table Table of key-value pairs to encode.
---@param sep string|nil Separator to use between pairs (default: "&").
---@return string string Built query string.
---@usage <br>
--- ```
--- string.build_query({ key1 = "value1", key2 = "value2" }) -- "key1=value1&key2=value2"
--- string.build_query({ name = { "John", "Jane" } }) -- "name=John&name=Jane"
--- string.build_query({ key = "test" }, ";") -- "key=test"
--- ```
local string_build_query = function(tbl, sep) end

string.build_query = string_build_query
string.buildQuery = string_build_query
string.BuildQuery = string_build_query

--- Parse a URL into its components.<br>
--- Returns a table with scheme, username, password, host, port, path, query, fragment, and authority.
---@param self string URL string to parse.
---@return table parsed Table with URL components.
---@usage <br>
--- ```
--- local url = "https://user:pass@example.com:8080/path?query=value#fragment"
--- local parsed = url:parse_url()
--- -- parsed.scheme = "https"
--- -- parsed.username = "user"
--- -- parsed.password = "pass"
--- -- parsed.host = "example.com"
--- -- parsed.port = "8080"
--- -- parsed.path = "/path"
--- -- parsed.query = "query=value"
--- -- parsed.fragment = "fragment"
--- -- parsed.authority = "user:pass@example.com:8080"
--- ```
local string_parse_url = function(self) end

string.parse_url = string_parse_url
string.parseUrl = string_parse_url
string.ParseUrl = string_parse_url

--- Extract the scheme (protocol) from a URL.
---@param self string URL string.
---@return string string URL scheme (e.g., "https", "http").
---@usage <br>
--- ```
--- "https://example.com":url_scheme() -- "https"
--- "http://test.com":url_scheme() -- "http"
--- ```
local string_url_scheme = function(self) end

string.url_scheme = string_url_scheme
string.urlScheme = string_url_scheme
string.UrlScheme = string_url_scheme

--- Extract the host from a URL.
---@param self string URL string.
---@return string string URL host (e.g., "example.com").
---@usage <br>
--- ```
--- "https://example.com":url_host() -- "example.com"
--- "http://test.com:8080":url_host() -- "test.com"
--- ```
local string_url_host = function(self) end

string.url_host = string_url_host
string.urlHost = string_url_host
string.UrlHost = string_url_host

--- Extract the port from a URL.
---@param self string URL string.
---@return string string URL port (empty string if not specified).
---@usage <br>
--- ```
--- "https://example.com:8080":url_port() -- "8080"
--- "https://example.com":url_port() -- ""
--- ```
local string_url_port = function(self) end

string.url_port = string_url_port
string.urlPort = string_url_port
string.UrlPort = string_url_port

--- Extract the path from a URL.
---@param self string URL string.
---@return string string URL path.
---@usage <br>
--- ```
--- "https://example.com/path/to/file":url_path() -- "/path/to/file"
--- "https://example.com":url_path() -- "/"
--- ```
local string_url_path = function(self) end

string.url_path = string_url_path
string.urlPath = string_url_path
string.UrlPath = string_url_path

--- Extract the query string from a URL.
---@param self string URL string.
---@return string string URL query string (without the "?").
---@usage <br>
--- ```
--- "https://example.com?key=value":url_query() -- "key=value"
--- "https://example.com":url_query() -- ""
--- ```
local string_url_query = function(self) end

string.url_query = string_url_query
string.urlQuery = string_url_query
string.UrlQuery = string_url_query

--- Extract the fragment from a URL.
---@param self string URL string.
---@return string string URL fragment (without the "#").
---@usage <br>
--- ```
--- "https://example.com#section":url_fragment() -- "section"
--- "https://example.com":url_fragment() -- ""
--- ```
local string_url_fragment = function(self) end

string.url_fragment = string_url_fragment
string.urlFragment = string_url_fragment
string.UrlFragment = string_url_fragment

--- Extract the username from a URL.
---@param self string URL string.
---@return string string URL username (empty string if not specified).
---@usage <br>
--- ```
--- "https://user@example.com":url_username() -- "user"
--- "https://example.com":url_username() -- ""
--- ```
local string_url_username = function(self) end

string.url_username = string_url_username
string.urlUsername = string_url_username
string.UrlUsername = string_url_username

--- Extract the password from a URL.
---@param self string URL string.
---@return string string URL password (empty string if not specified).
---@usage <br>
--- ```
--- "https://user:pass@example.com":url_password() -- "pass"
--- "https://user@example.com":url_password() -- ""
--- ```
local string_url_password = function(self) end

string.url_password = string_url_password
string.urlPassword = string_url_password
string.UrlPassword = string_url_password

--- Extract the authority from a URL.
--- Authority includes userinfo and host:port.
---@param self string URL string.
---@return string string URL authority.
---@usage <br>
--- ```
--- "https://user:pass@example.com:8080":url_authority() -- "user:pass@example.com:8080"
--- "https://example.com":url_authority() -- "example.com"
--- ```
local string_url_authority = function(self) end

string.url_authority = string_url_authority
string.urlAuthority = string_url_authority
string.UrlAuthority = string_url_authority

--- Check if a URL is absolute (has a scheme).
---@param self string URL string.
---@return boolean boolean True if URL has a scheme, false otherwise.
---@usage <br>
--- ```
--- "https://example.com":is_absolute_url() -- true
--- "/path/to/file":is_absolute_url() -- false
--- "//example.com":is_absolute_url() -- false
--- ```
local string_is_absolute_url = function(self) end

string.is_absolute_url = string_is_absolute_url
string.isAbsoluteUrl = string_is_absolute_url
string.IsAbsoluteUrl = string_is_absolute_url

--- Resolve a relative URL against a base URL.
--- Handles absolute relative URLs, path-relative URLs, and normalizes the result.
---@param relative string Relative URL to resolve.
---@param base string Base URL to resolve against.
---@return string string Resolved absolute URL.
---@usage <br>
--- ```
--- string.resolve_url("/path", "https://example.com/base/") -- "https://example.com/path"
--- string.resolve_url("../other", "https://example.com/a/b/") -- "https://example.com/a/other"
--- string.resolve_url("https://other.com", "https://example.com") -- "https://other.com"
--- ```
local string_resolve_url = function(relative, base) end

string.resolve_url = string_resolve_url
string.resolveUrl = string_resolve_url
string.ResolveUrl = string_resolve_url

--- Split a URL into base URL (scheme + authority) and endpoint (path + query + fragment).<br>
--- Useful for HTTP libraries that require separate base URL and endpoint parameters.<br>
--- The returned base_url never ends with "/" and the endpoint always begins with "/".
---@param full_url string Full URL string to split.
---@return string base_url Base URL consisting of scheme and authority, never ending with "/" (e.g., "https://example.com").
---@return string endpoint Endpoint consisting of path, query, and fragment, always beginning with "/" (e.g., "/path?key=value#section").
---@usage <br>
--- ```
--- local base_url, endpoint = string.split_url("https://example.com/path?key=value#section")
--- -- base_url = "https://example.com"
--- -- endpoint = "/path?key=value#section"
---
--- local base_url, endpoint = string.split_url("https://example.com")
--- -- base_url = "https://example.com"
--- -- endpoint = "/"
---
--- local base_url, endpoint = string.split_url("https://example.com/")
--- -- base_url = "https://example.com"
--- -- endpoint = "/"
--- ```
local string_split_url = function(full_url) end

string.split_url = string_split_url
string.splitUrl = string_split_url
string.SplitUrl = string_split_url

---@class string.BoxOptions
---@field style string|nil Box style: "single", "double", "round", "bold", or "ascii" (default: "single").
---@field padding number|nil Number of spaces inside the box (default: 1).
---@field margin number|nil Number of blank lines above and below the box (default: 0).
---@field title string|nil Optional title string to place in the top border.
---@field align string|nil Text alignment inside the box: "left", "center", or "right" (default: "left").
---@field width number|nil Optional fixed inner width (visual). If nil, computed from content.

--- Draw a box around text (multi-line).<br>
--- Supports various box styles and customizable padding, margin, title, and alignment.
---@param str string Text to box (can contain newlines for multiple lines).
---@param options string.BoxOptions|nil Options table for box appearance.
---@return string string Boxed text with borders.
---@usage <br>
--- ```
--- local boxed = string.box("Hello World", {
---   style = "double",
---   title = "Title",
---   padding = 2,
---   align = "center"
--- })
--- print(boxed)
--- ```
local string_box = function(str, options) end

string.box = string_box
string.Box = string_box

--- Align a string to a specified width with padding.<br>
--- Simple alignment that does not account for ANSI escape sequences.
---@param str string String to align.
---@param alignment string Alignment: "left", "right", or "center".
---@param width number Target width in characters.
---@param pad_char string|nil Padding character (default: " ").
---@return string string Aligned string.
---@usage <br>
--- ```
--- string.align("hello", "left", 10)   -- "hello     "
--- string.align("hello", "right", 10)  -- "     hello"
--- string.align("hello", "center", 10) -- "  hello   "
--- ```
local string_align = function(str, alignment, width, pad_char) end

string.align = string_align
string.Align = string_align

--- Align a string to a specified width with padding, accounting for ANSI escape sequences.<br>
--- Preserves ANSI sequences (like colors) and operates on visible character length.
---@param str string String to align (may contain ANSI escape sequences).
---@param alignment string Alignment: "left", "right", or "center".
---@param width number Target visual width (ignoring ANSI sequences).
---@param pad_char string|nil Padding character (default: " ").
---@return string string Aligned string with ANSI sequences preserved.
---@usage <br>
--- ```
--- local colored = "\27[31mhello\27[0m"
--- string.align_ansi(colored, "center", 20) -- centers "hello" with colors preserved
--- ```
local string_align_ansi = function(str, alignment, width, pad_char) end

string.align_ansi = string_align_ansi
string.alignAnsi = string_align_ansi
string.AlignAnsi = string_align_ansi

---@class string.ProgressBarOptions
---@field width number|nil Visual width of the bar (default: 30).
---@field fill string|nil Character for filled portion (default: "█").
---@field empty string|nil Character for empty portion (default: "░").
---@field show_percent boolean|nil Show percentage after bar (default: true).
---@field caps boolean|nil Show [ ] around the bar (default: true).
---@field unicode_fraction boolean|nil Use partial block characters for fractional fill (default: true).
---@field left_label string|nil Optional label to show before the bar.
---@field right_label string|nil Optional label to show after the bar.

--- Create a visual progress bar.<br>
--- Supports Unicode block characters for fractional fill and optional labels.
---@param current number Current progress value.
---@param total number Total value (maximum).
---@param width number|nil Visual width of the bar (default: 30, or options.width).
---@param options string.ProgressBarOptions|nil Options table for bar appearance.
---@return string string Progress bar string.
---@usage <br>
--- ```
--- print(string.progress_bar(50, 100, 30))
--- -- "[████████████░░░░░░░░░░░░]  50%"
---
--- print(string.progress_bar(75, 100, 20, {
---   fill = "=",
---   empty = "-",
---   caps = false,
---   show_percent = false
--- }))
--- -- "===================="
---
--- print(string.progress_bar(30, 100, 30, {
---   left_label = "Loading:",
---   right_label = "30/100",
---   show_percent = false
--- }))
--- -- "Loading: [███░░░░░░░░░░░░░░░░░░] 30/100"
--- ```
local string_progress_bar = function(current, total, width, options) end

string.progress_bar = string_progress_bar
string.progressBar = string_progress_bar
string.ProgressBar = string_progress_bar

---@class string.TruncateOptions
---@field ellipsis string|nil Ellipsis character to use (default: "...").

--- Truncate a string at the end with an ellipsis (byte-based).<br>
--- If the string is already shorter than the target width, it is returned unchanged.
---@param s string String to truncate.
---@param width number Target byte width.
---@param opts string.TruncateOptions|nil Options table.
---@return string string Truncated string with ellipsis.
---@usage <br>
--- ```
--- string.truncate("Hello World", 8) -- "Hello..."
--- string.truncate("Hello World", 8, { ellipsis = ".." }) -- "Hello.."
--- ```
local string_truncate = function(s, width, opts) end

string.truncate = string_truncate
string.Truncate = string_truncate

--- Truncate a string in the middle, keeping start and end with an ellipsis (byte-based).
---@param s string String to truncate.
---@param width number Target byte width.
---@param opts string.TruncateOptions|nil Options table.
---@return string string Truncated string with middle ellipsis.
---@usage <br>
--- ```
--- string.truncate_middle("Hello World", 8) -- "He...ld"
--- string.truncate_middle("Hello World", 8, { ellipsis = ".." }) -- "He..ld"
--- ```
local string_truncate_middle = function(s, width, opts) end

string.truncate_middle = string_truncate_middle
string.truncateMiddle = string_truncate_middle
string.TruncateMiddle = string_truncate_middle

---@class string.AbbreviateOptions
---@field mode string|nil Abbreviation mode: "initials" or "compact" (default: "initials").
---@field ellipsis string|nil Ellipsis character to use (default: "...").

--- Intelligently abbreviate a phrase by taking initials or compacting words.<br>
--- If the string contains separators (space, -, _), produces an abbreviation of words.<br>
--- Falls back to truncate_middle if no separators are found.
---@param s string String to abbreviate.
---@param max_len number Desired maximum visual length.
---@param opts string.AbbreviateOptions|nil Options table.
---@return string string Abbreviated string.
---@usage <br>
--- ```
--- string.abbreviate("Hello World", 5) -- "HW"
--- string.abbreviate("Hello World", 10, { mode = "compact" }) -- "HelWor"
--- ```
local string_abbreviate = function(s, max_len, opts) end

string.abbreviate = string_abbreviate
string.Abbreviate = string_abbreviate

--- Indent each line of text with a prefix repeated count times.
---@param text string Text to indent (can contain newlines).
---@param prefix string|nil Prefix string to use (default: " ").
---@param count number|nil Number of prefix repeats (default: 2).
---@return string string Indented text.
---@usage <br>
--- ```
--- string.indent("Hello\nWorld", "  ", 1) -- "  Hello\n  World"
--- string.indent("Hello\nWorld", "\t", 2) -- "\t\tHello\n\t\tWorld"
--- ```
local string_indent = function(text, prefix, count) end

string.indent = string_indent
string.Indent = string_indent

--- Dedent text by removing leading spaces or a specific prefix.<br>
--- If count_or_prefix is a number: removes up to that many leading spaces.<br>
--- If count_or_prefix is a string: removes that exact prefix if present.<br>
--- If count_or_prefix is nil: removes common indentation across all non-empty lines.
---@param text string Text to dedent (can contain newlines).
---@param count_or_prefix number|string|nil Number of spaces to remove, or exact prefix string, or nil for auto-dedent.
---@return string string Dedented text.
---@usage <br>
--- ```
--- string.dedent("  Hello\n  World", 2) -- "Hello\nWorld"
--- string.dedent(">>Hello\n>>World", ">>") -- "Hello\nWorld"
--- string.dedent("  Hello\n    World") -- "Hello\n  World" (auto-dedent)
--- ```
local string_dedent = function(text, count_or_prefix) end

string.dedent = string_dedent
string.Dedent = string_dedent

---@class string.TemplateOptions
---@field escape function|nil Custom escape function for variables (default: no escaping).

--- Compile a mustache-like template string into a renderer function.<br>
--- Features: {{key}} escaped, {{{key}}} raw, {{#section}}...{{/section}} iterate/render, {{^section}}...{{/section}} inverted.<br>
--- Supports dot-path lookup (a.b.c) and simple filters ({{name|upper}}).
---@param tpl string Template string.
---@return function renderer Function that takes (context, opts) and returns rendered string.
---@usage <br>
--- ```
--- local renderer = string.compile_template("Hello {{name}}!")
--- print(renderer({ name = "World" })) -- "Hello World!"
---
--- local tpl = "{{#items}}- {{.}}\n{{/items}}"
--- local renderer = string.compile_template(tpl)
--- print(renderer({ items = { "a", "b", "c" } }))
--- -- "- a\n- b\n- c\n"
--- ```
local string_compile_template = function(tpl) end

string.compile_template = string_compile_template
string.compileTemplate = string_compile_template
string.CompileTemplate = string_compile_template

--- Render a mustache-like template string with the given context (convenience function).<br>
--- Compiles the template (cached) and renders it in one call.
---@param tpl string Template string.
---@param ctx table Context table with values to substitute.
---@param opts string.TemplateOptions|nil Options table.
---@return string string Rendered template.
---@usage <br>
--- ```
--- print(string.template("Hello {{name}}!", { name = "World" })) -- "Hello World!"
--- print(string.template("Count: {{count|upper}}", { count = 42 })) -- "Count: 42"
--- ```
local string_template = function(tpl, ctx, opts) end

string.template = string_template
string.Template = string_template

--- Interpolates placeholders in a string using a lookup table.<br>
--- Placeholders are specified as `{name}` where `name` matches the pattern `[_%a][_%%w]*`.
---@param self string The string containing placeholders.
---@param lookup table A table mapping placeholder names to replacement values.
---@return string string The string with placeholders replaced.
---@usage <br>
--- ```
--- "Hello, {name}!":interpolate({ name = "World" }) -- "Hello, World!"
--- "x={x}, y={y}":interpolate({ x = 1, y = 2 }) -- "x=1, y=2"
--- ```
local string_interpolate = function(self, lookup) end

string.interpolate = string_interpolate
string.Interpolate = string_interpolate

--- Get the UTF-8 character length of a string (or byte length if UTF-8 unavailable).<br>
--- Returns the number of characters in the string, accounting for UTF-8 multi-byte sequences if available.
---@param s string Input string.
---@return number length Character count (UTF-8) or byte count.
---@usage <br>
--- ```
--- string.ulen("hello") -- 5
--- string.ulen("héllo") -- 5 (if UTF-8 available)
--- ```
local string_ulen = function(s) end

string.ulen = string_ulen

--- Get the visible length of a string ignoring ANSI escape sequences (UTF-8 aware).<br>
--- Strips ANSI escape codes before calculating character length.
---@param s string Input string.
---@return number length Visible character count (ANSI stripped).
---@usage <br>
--- ```
--- string.visible_length("\27[31mhello\27[0m") -- 5 (ANSI codes stripped)
--- ```
local visible_length = function(s) end

string.visible_length = visible_length
string.visibleLength = visible_length
string.VisibleLength = visible_length

--- UTF-8 safe substring by character indices (1-based inclusive).<br>
--- If UTF-8 is unavailable, falls back to byte-based substring.
---@param s string Input string.
---@param i number Start index (1-based, supports negative).
---@param j number|nil End index (inclusive, supports negative, default: -1).
---@return string string Substring.
---@usage <br>
--- ```
--- string.substring("hello", 1, 3) -- "hel"
--- string.substring("hello", -2) -- "lo"
--- ```
local substring = function(s, i, j) end

string.substring = substring
string.Substring = substring

--- Strip ANSI escape sequences from a string.<br>
--- Removes all ANSI CSI/SGR escape codes from the input string.
---@param s string Input string.
---@return string string String with ANSI sequences removed.
---@usage <br>
--- ```
--- string.strip_ansi("\27[31mhello\27[0m") -- "hello"
--- ```
local strip_ansi = function(s) end

string.strip_ansi = strip_ansi
string.stripAnsi = strip_ansi
string.StripAnsi = strip_ansi

--- Safe tostring that returns empty string for nil.<br>
--- Converts value to string, returning "" for nil instead of "nil".
---@param v any Value to convert.
---@return string string String representation, or "" if nil.
---@usage <br>
--- ```
--- string.safe(nil) -- ""
--- string.safe(42) -- "42"
--- string.safe("hello") -- "hello"
--- ```
local safe_tostring = function(v) end

string.safe = safe_tostring
string.Safe = safe_tostring

--- Check if a string is empty.<br>
--- Returns true if the string has zero length.
---@param self string Input string.
---@return boolean empty True if string is empty, false otherwise.
---@usage <br>
--- ```
--- "":is_empty() -- true
--- "hello":is_empty() -- false
--- ```
local string_is_empty = function(self) end

string.is_empty = string_is_empty
string.isEmpty = string_is_empty
string.IsEmpty = string_is_empty

--- Escape HTML special characters in a string.<br>
--- Replaces &, <, >, ", ', / with their HTML entity equivalents.
---@param str string Input string.
---@return string string HTML-escaped string.
---@usage <br>
--- ```
--- string.escape_html("<script>alert('XSS')</script>") -- "&lt;script&gt;alert(&#39;XSS&#39;)&lt;/script&gt;"
--- ```
local string_escape_html = function(str) end

string.escape_html = string_escape_html
string.escapeHTML = string_escape_html
string.EscapeHTML = string_escape_html

--- Unescape HTML entities in a string.<br>
--- Replaces HTML entities (named and numeric) with their character equivalents.<br>
--- Supports UTF-8 code points if UTF-8 library is available.
---@param str string Input string with HTML entities.
---@return string string Unescaped string.
---@usage <br>
--- ```
--- string.unescape_html("&lt;div&gt;Hello&lt;/div&gt;") -- "<div>Hello</div>"
--- string.unescape_html("&#65;&#66;&#67;") -- "ABC"
--- ```
local string_unescape_html = function(str) end

string.unescape_html = string_unescape_html
string.unescapeHTML = string_unescape_html
string.UnescapeHTML = string_unescape_html

--- XOR cipher encryption/decryption.<br>
--- Encrypts or decrypts a string using XOR cipher with the provided key.<br>
--- The key is cycled through the string for encryption/decryption.
---@param s string Input string to encrypt or decrypt.
---@param k string|table Key string (or table converted to string) for XOR cipher.
---@return string string Encrypted or decrypted string.
---@usage <br>
--- ```
--- local encrypted = string.xor_cipher("hello", "key")
--- local decrypted = string.xor_cipher(encrypted, "key") -- "hello"
--- ```
local string_xor_cipher = function(s, k) end

string.xor_cipher = string_xor_cipher
string.xorCipher = string_xor_cipher
string.XorCipher = string_xor_cipher

--- Surround a string with a wrapper on both sides.
---@param self string Input string to surround.
---@param wrapper string|nil Wrapper string (default: "").
---@return string string Surrounded string.
---@usage <br>
--- ```
--- "hello":surround("*") -- "*hello*"
--- "test":surround("[]") -- "[]test[]"
--- ```
local string_surround = function(self, wrapper) end

string.surround = string_surround
string.Surround = string_surround

--- Extract the first occurrence of text between two delimiters.
---@param self string Input string to search within.
---@param open string Opening delimiter.
---@param close string Closing delimiter.
---@return string|nil string Extracted text between delimiters, or nil if not found.
---@usage <br>
--- ```
--- "a [b] c":between("[", "]") -- "b"
--- "start<value>end":between("<", ">") -- "value"
--- "no delimiters":between("[", "]") -- nil
--- ```
local string_between = function(self, open, close) end

string.between = string_between
string.Between = string_between

--- Remove ASCII control characters (0-31, 127) from a string.
---@param self string Input string to clean.
---@return string string String with control characters removed.
---@usage <br>
--- ```
--- "hello\nworld":remove_non_printable() -- "helloworld"
--- "text\twith\rcodes":remove_non_printable() -- "textwithcodes"
--- ```
local string_remove_non_printable = function(self) end

string.remove_non_printable = string_remove_non_printable
string.removeNonPrintable = string_remove_non_printable
string.RemoveNonPrintable = string_remove_non_printable

--- Remove non-ASCII characters, keeping only ASCII 0-127.
---@param self string Input string to clean.
---@return string string String with only ASCII characters.
---@usage <br>
--- ```
--- "héllo":remove_non_ascii() -- "hllo"
--- "café":remove_non_ascii() -- "caf"
--- "日本語":remove_non_ascii() -- ""
--- ```
local string_remove_non_ascii = function(self) end

string.remove_non_ascii = string_remove_non_ascii
string.removeNonASCII = string_remove_non_ascii
string.RemoveNonASCII = string_remove_non_ascii

--- Truncate a string to a maximum number of words.
---@param self string Input string to truncate.
---@param max_words number Maximum number of words to keep (default: 0 returns empty string).
---@param suffix string|nil Suffix to append when truncated (default: "~").
---@return string string Truncated string with suffix if needed.
---@usage <br>
--- ```
--- "a b c d":truncate_words(2) -- "a b~"
--- "one two three":truncate_words(5) -- "one two three"
--- "hello world":truncate_words(1, "...") -- "hello..."
--- ```
local string_truncate_words = function(self, max_words, suffix) end

string.truncate_words = string_truncate_words
string.truncateWords = string_truncate_words
string.TruncateWords = string_truncate_words

--- Append a suffix to a string only if the string is empty.
---@param self string Input string.
---@param suffix string|nil Suffix to append (default: "").
---@return string string Original string with suffix appended if empty.
---@usage <br>
--- ```
--- "":append_if_empty("default") -- "default"
--- "hello":append_if_empty("default") -- "hello"
--- ```
local string_append_if_empty = function(self, suffix) end

string.append_if_empty = string_append_if_empty
string.appendIfEmpty = string_append_if_empty
string.AppendIfEmpty = string_append_if_empty

--- Prepend a prefix to a string only if the string is empty.
---@param self string Input string.
---@param prefix string|nil Prefix to prepend (default: "").
---@return string string Original string with prefix prepended if empty.
---@usage <br>
--- ```
--- "":prepend_if_empty("default") -- "default"
--- "hello":prepend_if_empty("default") -- "hello"
--- ```
local string_prepend_if_empty = function(self, prefix) end

string.prepend_if_empty = string_prepend_if_empty
string.prependIfEmpty = string_prepend_if_empty
string.PrependIfEmpty = string_prepend_if_empty

--- Append a suffix to a string only if the string is not empty.
---@param self string Input string.
---@param suffix string|nil Suffix to append (default: "").
---@return string string Original string with suffix appended if not empty.
---@usage <br>
--- ```
--- "hello":append_if_not_empty("!") -- "hello!"
--- "":append_if_not_empty("!") -- ""
--- ```
local string_append_if_not_empty = function(self, suffix) end

string.append_if_not_empty = string_append_if_not_empty
string.appendIfNotEmpty = string_append_if_not_empty
string.AppendIfNotEmpty = string_append_if_not_empty

--- Prepend a prefix to a string only if the string is not empty.
---@param self string Input string.
---@param prefix string|nil Prefix to prepend (default: "").
---@return string string Original string with prefix prepended if not empty.
---@usage <br>
--- ```
--- "hello":prepend_if_not_empty("> ") -- "> hello"
--- "":prepend_if_not_empty("> ") -- ""
--- ```
local string_prepend_if_not_empty = function(self, prefix) end

string.prepend_if_not_empty = string_prepend_if_not_empty
string.prependIfNotEmpty = string_prepend_if_not_empty
string.PrependIfNotEmpty = string_prepend_if_not_empty

--- Count non-overlapping occurrences of a pattern in a string.
---@param self string Input string to search within.
---@param pattern string Lua pattern to search for.
---@param plain boolean|nil If true, treat pattern as plain text (default: false, uses Lua patterns).
---@return number count Number of occurrences found.
---@usage <br>
--- ```
--- "banana":count("a") -- 3
--- "hello world":count("l") -- 3
--- "test":count("z") -- 0
--- "banana":count("a", true) -- 3 (plain text search)
--- "test.test":count(".", true) -- 1 (plain text, not pattern)
--- ```
local string_count = function(self, pattern, plain) end

string.count = string_count
string.Count = string_count

--- JS-like splice operation for strings: delete and insert at a position.
---@param self string Input string to modify.
---@param start number Starting position (1-based, clamped to valid range).
---@param deleteCount number Number of characters to delete (default: 0).
---@param insert string|nil String to insert at the position (default: "").
---@return string string Modified string.
---@usage <br>
--- ```
--- "abcdef":splice(3, 2, "XY") -- "abXYef"
--- "abcdef":splice(3, 0, "XYZ") -- "abXYZcdef"
--- "abcdef":splice(1, 2, "") -- "cdef"
--- ```
local string_splice = function(self, start, deleteCount, insert) end

string.splice = string_splice
string.Splice = string_splice

--- Convert a word to its plural form based on count.<br>
--- Returns singular if count is 1, otherwise applies pluralization rules.<br>
--- Supports common irregular plurals and regular pluralization patterns.
---@param self string Word to pluralize.
---@param count number|nil Count to check for singular/plural (default: 0).
---@return string string Pluralized word (or singular if count == 1).
---@usage <br>
--- ```
--- "cat":plural(1) -- "cat"
--- "cat":plural(2) -- "cats"
--- "person":plural(5) -- "people"
--- "child":plural(3) -- "children"
--- "box":plural(2) -- "boxes"
--- "city":plural(2) -- "cities"
--- "knife":plural(2) -- "knives"
--- ```
local string_plural = function(self, count) end

string.plural = string_plural
string.Plural = string_plural

--- Parse a Lua string literal from the current string.<br>
--- Uses skip-ahead scanning for short strings and long bracket strings.<br>
--- Returns a result table with consistent structure:
--- - Success: { ok = true, value = ..., next_index = ..., raw = ..., kind = ... }
--- - Failure: { ok = false, error = ..., error_pos = ... }
---@param self string Input text to parse.
---@param i integer|nil Index where string literal starts (default: 1).
---@param opts parse_string.Options|nil Optional behaviour overrides.
---@return table result Result table with ok, value, next_index, raw, kind on success; or ok, error, error_pos on failure.
---@usage <br>
--- ```
--- local result = "'hello world'":parse()
--- if result.ok then
---   print(result.value) -- "hello world"
--- end
--- ```
local string_parse = function(self, i, opts) end

string.parse = string_parse
string.Parse = string_parse

return string
