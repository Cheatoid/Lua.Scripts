-- Minimal Test Harness
local Test = {
	passed = 0,
	failed = 0,
	errors = {},
	current_suite = "",
}

function Test.suite(name)
	Test.current_suite = name
	print(string.format("\n== %s ==", name))
end

function Test.assert(condition, msg)
	if condition then
		Test.passed = Test.passed + 1
	else
		Test.failed = Test.failed + 1
		local err = string.format("  FAIL [%s]: %s", Test.current_suite, msg or "assertion failed")
		table.insert(Test.errors, err)
		print(err)
	end
end

function Test.equal(actual, expected, msg)
	if actual == expected then
		Test.passed = Test.passed + 1
	else
		Test.failed = Test.failed + 1
		local detail = string.format("%s (expected: %s, got: %s)",
			msg or "values not equal", tostring(expected), tostring(actual))
		local err = string.format("  FAIL [%s]: %s", Test.current_suite, detail)
		table.insert(Test.errors, err)
		print(err)
	end
end

function Test.deep_equal(actual, expected, msg)
	local seen = {}
	if actual == expected then
		Test.assert(true, msg)
		return
	end
	if type(actual) ~= type(expected) then
		Test.assert(false, (msg or "") .. string.format(" (type mismatch: %s vs %s)", type(actual), type(expected)))
		return
	end
	if type(actual) ~= "table" then
		Test.assert(false, (msg or "") .. string.format(" (expected: %s, got: %s)", tostring(expected), tostring(actual)))
		return
	end
	if seen[actual] then
		Test.assert(true, msg)
		return
	end -- cycle guard
	seen[actual] = true
	for k, v in pairs(actual) do
		if not Test._deep_eq(v, expected[k], seen) then
			Test.assert(false, (msg or "") .. string.format(" (key %s differs)", tostring(k)))
			return
		end
	end
	for k, _ in pairs(expected) do
		if actual[k] == nil then
			Test.assert(false, (msg or "") .. string.format(" (extra key %s in expected)", tostring(k)))
			return
		end
	end
	Test.assert(true, msg)
end

function Test._deep_eq(a, b, seen)
	if a == b then return true end
	if type(a) ~= type(b) then return false end
	if type(a) ~= "table" then return false end
	if seen[a] then return true end
	seen[a] = true
	for k, v in pairs(a) do
		if not Test._deep_eq(v, b[k], seen) then return false end
	end
	for k, _ in pairs(b) do
		if a[k] == nil then return false end
	end
	return true
end

function Test.approx(actual, expected, epsilon, msg)
	epsilon = epsilon or 1e-6
	local cond = math.abs(actual - expected) <= epsilon
	if not cond then
		msg = string.format("%s (expected: ~%s, got: %s)", msg or "approx equality failed", tostring(expected),
			tostring(actual))
	end
	Test.assert(cond, msg)
end

function Test.nil_val(actual, msg)
	Test.assert(actual == nil, msg or "expected nil value")
end

function Test.summary()
	print(string.format("\n========================================"))
	print(string.format("Results: %d passed, %d failed", Test.passed, Test.failed))
	if #Test.errors > 0 then
		print("\nFailures:")
		for _, e in ipairs(Test.errors) do
			print(e)
		end
	end
	print("========================================")
	return Test.failed == 0
end

----------------------------------------------------------------------
-- Load the library under test
----------------------------------------------------------------------
local lib = require "../string"

----------------------------------------------------------------------
-- Character Classification
----------------------------------------------------------------------
Test.suite("Character Classification")

Test.equal(string.is_upper("A"), true, "is_upper('A')")
Test.equal(string.is_upper("a"), false, "is_upper('a')")
Test.equal(string.is_upper("1"), false, "is_upper('1')")
Test.equal(string.IsUpper("Z"), true, "IsUpper alias")

Test.equal(string.is_lower("a"), true, "is_lower('a')")
Test.equal(string.is_lower("A"), false, "is_lower('A')")
Test.equal(string.IsLower("z"), true, "IsLower alias")

Test.equal(string.is_alpha("a"), true, "is_alpha('a')")
Test.equal(string.is_alpha("Z"), true, "is_alpha('Z')")
Test.equal(string.is_alpha("1"), false, "is_alpha('1')")
Test.equal(string.is_alpha(" "), false, "is_alpha(' ')")

Test.equal(string.is_digit("0"), true, "is_digit('0')")
Test.equal(string.is_digit("9"), true, "is_digit('9')")
Test.equal(string.is_digit("a"), false, "is_digit('a')")

Test.equal(string.is_space(" "), true, "is_space(' ')")
Test.equal(string.is_space("\t"), true, "is_space('\\t')")
Test.equal(string.is_space("\n"), true, "is_space('\\n')")
Test.equal(string.is_space("a"), false, "is_space('a')")

Test.equal(string.is_alphanum("a"), true, "is_alphanum('a')")
Test.equal(string.is_alphanum("1"), true, "is_alphanum('1')")
Test.equal(string.is_alphanum(" "), false, "is_alphanum(' ')")
Test.equal(string.isAlphaNum("Z"), true, "isAlphaNum alias")

Test.equal(string.is_control("\0"), true, "is_control('\\0')")
Test.equal(string.is_control("\n"), true, "is_control('\\n')")
Test.equal(string.is_control("a"), false, "is_control('a')")

Test.equal(string.is_punct("."), true, "is_punct('.')")
Test.equal(string.is_punct("!"), true, "is_punct('!')")
Test.equal(string.is_punct("a"), false, "is_punct('a')")
Test.equal(string.is_punct("1"), false, "is_punct('1')")

----------------------------------------------------------------------
-- is_empty
----------------------------------------------------------------------
Test.suite("is_empty")

Test.equal(string.is_empty(""), true, "empty string")
Test.equal(string.is_empty("a"), false, "non-empty string")
Test.equal(string.isEmpty(""), true, "isEmpty alias")
Test.equal(string.IsEmpty("x"), false, "IsEmpty alias")

----------------------------------------------------------------------
-- Line Iteration & Splitting
----------------------------------------------------------------------
Test.suite("Line Operations")

-- iterate_linefeed
do
	local parts = {}
	for line in string.iterate_linefeed("a\nb\nc") do
		parts[#parts + 1] = line
	end
	Test.deep_equal(parts, { "a", "b", "c" }, "iterate_linefeed basic")
end

-- iterate_lines (handles \r\n)
do
	local parts = {}
	for line in string.iterate_lines("line1\r\nline2\nline3") do
		parts[#parts + 1] = line
	end
	Test.deep_equal(parts, { "line1", "line2", "line3" }, "iterate_lines CRLF+LF")
end

-- lines (returns table)
do
	local result = string.lines("a\nb\r\nc")
	Test.deep_equal(result, { "a", "b", "c" }, "lines() mixed endings")
end

-- lines edge cases
Test.deep_equal(string.lines(""), {}, "lines empty string")
Test.deep_equal(string.lines("single"), { "single" }, "lines no newline")
Test.deep_equal(string.lines("a\n"), { "a" }, "lines trailing newline")

----------------------------------------------------------------------
-- Explode / Split Iterators
----------------------------------------------------------------------
Test.suite("Explode & Chunk Iterators")

-- iter_explode
do
	local parts = {}
	for p in string.iter_explode("a,b,,c,", ",") do
		parts[#parts + 1] = p
	end
	Test.deep_equal(parts, { "a", "b", "", "c", "" }, "iter_explode with trailing empty")
end

-- iter_explode_pattern
do
	local parts = {}
	for p in string.iter_explode_pattern("a1b22c", "%d+") do
		parts[#parts + 1] = p
	end
	Test.deep_equal(parts, { "a", "b", "c" }, "iter_explode_pattern digits")
end

-- iter_chunk_split
do
	local chunks = {}
	for c in string.iter_chunk_split("abcdefg", 3) do
		chunks[#chunks + 1] = c
	end
	Test.deep_equal(chunks, { "abc", "def", "g" }, "iter_chunk_split(3)")
end

-- chunks (table version)
Test.deep_equal(string.chunks("abcdefg", 3), { "abc", "def", "g" }, "chunks(3)")
Test.deep_equal(string.chunk("abcdef", 2), { "ab", "cd", "ef" }, "chunk(2)")

----------------------------------------------------------------------
-- concat / to_table
----------------------------------------------------------------------
Test.suite("Concat & ToTable")

Test.equal(string.concat("a", "b", "c"), "abc", "concat basic")
Test.equal(string.Concat("hello", " ", "world"), "hello world", "Concat alias")
Test.deep_equal(string.to_table("hello"), { "h", "e", "l", "l", "o" }, "to_table")
Test.deep_equal(string.ToTable(""), {}, "ToTable empty")

----------------------------------------------------------------------
-- explode
----------------------------------------------------------------------
Test.suite("explode")

Test.deep_equal(string.explode("a,b,c", ","), { "a", "b", "c" }, "explode plain")
Test.deep_equal(string.explode("a1b2c", "%d", true), { "a", "b", "c" }, "explode pattern")
Test.deep_equal(string.explode("hello", ""), { "h", "e", "l", "l", "o" }, "explode empty sep")
Test.deep_equal(string.explode("no-sep-here", ","), { "no-sep-here" }, "explode no match")

----------------------------------------------------------------------
-- split
----------------------------------------------------------------------
Test.suite("split")

Test.deep_equal(string.split("a,b,c", ","), { "a", "b", "c" }, "split comma")
Test.deep_equal(string.split("hello world"), { "hello", "world" }, "split default whitespace")
Test.deep_equal(string.split("hello", ""), { "h", "e", "l", "l", "o" }, "split empty delimiter")
Test.deep_equal(string.split("a,b,c,d", ",", 2), { "a", "b", "c,d" }, "split max_splits")
Test.deep_equal(string.split("", ","), {}, "split empty string")

----------------------------------------------------------------------
-- split_pattern
----------------------------------------------------------------------
Test.suite("split_pattern")

Test.deep_equal(string.split_pattern("a\nb\nc", "\n"), { "a", "b", "c" }, "split_pattern newlines")
Test.deep_equal(string.split_pattern("aXbXc", "X", 2), { "a", "b", "c" }, "split_pattern max")

----------------------------------------------------------------------
-- replace
----------------------------------------------------------------------
Test.suite("replace")

Test.equal(string.replace("Hi there! Hi!", "Hi", "Hello"), "Hello there! Hello!", "replace multiple")
Test.equal(string.replace("a,b,c", ",", "-"), "a-b-c", "replace single char")
Test.equal(string.replace("hello", "x", "y"), "hello", "replace no match")
Test.equal(string.Replace("aaa", "a", "b"), "bbb", "Replace alias")

----------------------------------------------------------------------
-- starts_with / ends_with
----------------------------------------------------------------------
Test.suite("starts_with & ends_with")

Test.equal(string.starts_with("hello world", "hello"), true, "starts_with true")
Test.equal(string.starts_with("hello world", "world"), false, "starts_with false")
Test.equal(string.StartsWith("abc", ""), true, "starts_with empty prefix")

Test.equal(string.ends_with("hello world", "world"), true, "ends_with true")
Test.equal(string.ends_with("hello world", "hello"), false, "ends_with false")
Test.equal(string.EndsWith("abc", ""), true, "ends_with empty suffix")

----------------------------------------------------------------------
-- left / right
----------------------------------------------------------------------
Test.suite("left & right")

Test.equal(string.left("hello", 3), "hel", "left(3)")
Test.equal(string.left("hi", 10), "hi", "left overflow")
Test.equal(string.left("hi", 0), "", "left(0)")
Test.equal(string.left("hi", -1), "", "left negative")

Test.equal(string.right("hello", 3), "llo", "right(3)")
Test.equal(string.right("hi", 10), "hi", "right overflow")
Test.equal(string.right("hi", 0), "", "right(0)")

----------------------------------------------------------------------
-- Padding
----------------------------------------------------------------------
Test.suite("Padding")

Test.equal(string.pad_left("hi", 5), "   hi", "pad_left spaces")
Test.equal(string.pad_left("hi", 5, "x"), "xxxhi", "pad_left custom char")
Test.equal(string.pad_left("hello", 3), "hello", "pad_left already wider")

Test.equal(string.pad_right("hi", 5), "hi   ", "pad_right spaces")
Test.equal(string.pad_right("hi", 5, "x"), "hixxx", "pad_right custom char")

Test.equal(string.pad_center("hi", 6), "  hi  ", "pad_center even")
Test.equal(string.pad_center("hi", 7), "  hi   ", "pad_center odd")
Test.equal(string.pad_center("hello", 3), "hello", "pad_center already wider")

-- Aliases
Test.equal(string.padl("ab", 4), "  ab", "padl alias")
Test.equal(string.padr("ab", 4), "ab  ", "padr alias")
Test.equal(string.PadL("x", 3, "0"), "00x", "PadL alias")
Test.equal(string.PadR("x", 3, "0"), "x00", "PadR alias")
Test.equal(string.PadCenter("x", 5, "-"), "--x--", "PadCenter alias")

----------------------------------------------------------------------
-- Safe String / Escaping
----------------------------------------------------------------------
Test.suite("Escaping")

-- to_safe_string
do
	local s = string.to_safe_string("hello\nworld")
	Test.equal(s, '"hello\\nworld"', "to_safe_string double quote")
	local s2 = string.to_safe_string("it's", "'")
	Test.equal(s2, "'it\\'s'", "to_safe_string single quote")
end

-- javascript_safe
do
	local s = string.javascript_safe('he said "hi"\nand `bye`')
	Test.assert(not s:find("\n", 1, true), "javascript_safe escapes newline")
	Test.assert(s:find("\\`", 1, true), "javascript_safe escapes backtick")
end

-- pattern_safe_zero
Test.equal(string.pattern_safe_zero("a+b"), "a%+b", "pattern_safe_zero plus")
Test.equal(string.pattern_safe_zero("[x]"), "%[x%]", "pattern_safe_zero brackets")

-- pattern_safe
Test.equal(string.pattern_safe("a.b"), "a%.b", "pattern_safe dot")
Test.equal(string.pattern_safe("(test)"), "%(test%)", "pattern_safe parens")

-- escape_html
Test.equal(string.escape_html("<b>\"&'</b>"), "&lt;b&gt;&quot;&amp;&#39;&lt;/b&gt;", "escape_html")
Test.equal(string.escape_html(nil), "", "escape_html nil")

-- unescape_html
Test.equal(string.unescape_html("&lt;div&gt;"), "<div>", "unescape_html named")
Test.equal(string.unescape_html("&#65;&#66;"), "AB", "unescape_html decimal")
Test.equal(string.unescape_html("&#x41;&#x42;"), "AB", "unescape_html hex")
Test.equal(string.unescape_html(nil), "", "unescape_html nil")

----------------------------------------------------------------------
-- Trim
----------------------------------------------------------------------
Test.suite("Trim")

Test.equal(string.trim("  hello  "), "hello", "trim whitespace")
Test.equal(string.trim("xxhelloxx", "x"), "hello", "trim custom char")
Test.equal(string.trim_left("  hi  "), "hi  ", "trim_left")
Test.equal(string.trim_right("  hi  "), "  hi", "trim_right")
Test.equal(string.Trim(" abc "), "abc", "Trim alias")
Test.equal(string.TrimLeft(" abc"), "abc", "TrimLeft alias")
Test.equal(string.TrimRight("abc "), "abc", "TrimRight alias")

----------------------------------------------------------------------
-- Rotate
----------------------------------------------------------------------
Test.suite("Rotate")

Test.equal(string.rotate_left("hello", 2), "llohe", "rotate_left(2)")
Test.equal(string.rotate_right("hello", 2), "lohel", "rotate_right(2)")
Test.equal(string.rotate("hello", 2), "lohel", "rotate positive = right")
Test.equal(string.rotate("hello", -2), "llohe", "rotate negative = left")
Test.equal(string.rotate_left("hello", 0), "hello", "rotate_left(0)")
Test.equal(string.rotate_right("hello", 0), "hello", "rotate_right(0)")
Test.equal(string.RotateLeft("abc", 1), "bca", "RotateLeft alias")
Test.equal(string.RotateRight("abc", 1), "cab", "RotateRight alias")

----------------------------------------------------------------------
-- contains / index_of / last_index_of
----------------------------------------------------------------------
Test.suite("Search Functions")

Test.equal(string.contains("hello world", "world"), true, "contains found")
Test.equal(string.contains("hello world", "xyz"), false, "contains not found")
Test.equal(string.Contains("abc", "b"), true, "Contains alias")

Test.equal(string.index_of("hello world", "world"), 7, "index_of found")
Test.equal(string.index_of("hello world", "xyz"), nil, "index_of not found")
Test.equal(string.IndexOf("banana", "na"), 3, "IndexOf first occurrence")

Test.equal(string.last_index_of("hello world hello", "hello"), 13, "last_index_of")
Test.equal(string.last_index_of("hello world", "xyz"), nil, "last_index_of not found")
Test.equal(string.LastIndexOf("banana", "na"), 5, "LastIndexOf alias")
Test.equal(string.last_index_of("abc", ""), 4, "last_index_of empty substring")

----------------------------------------------------------------------
-- reverse
----------------------------------------------------------------------
Test.suite("Reverse")

Test.equal(string.reverse("hello"), "olleh", "reverse basic")
Test.equal(string.Reverse(""), "", "Reverse empty")
Test.equal(string.reverse("a"), "a", "reverse single char")

----------------------------------------------------------------------
-- random / uuid
----------------------------------------------------------------------
Test.suite("Random & UUID")

do
	local r = string.random(10)
	Test.equal(#r, 10, "random length 10")
	local r2 = string.random(5, 65, 90)
	Test.equal(#r2, 5, "random length 5 A-Z")
	for i = 1, #r2 do
		local b = string.byte(r2, i)
		Test.assert(b >= 65 and b <= 90, "random chars in range A-Z")
	end
	Test.equal(string.random(0), "", "random length 0")
end

do
	local u = string.uuid()
	Test.equal(#u, 36, "uuid length 36")
	Test.assert(u:match("^%x%x%x%x%x%x%x%x%-%x%x%x%x%-4%x%x%x%-[89ab]%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$") ~= nil,
		"uuid v4 format")
	-- Two UUIDs should differ
	local u2 = string.uuid()
	Test.assert(u ~= u2, "uuid uniqueness")
end

----------------------------------------------------------------------
-- Hex encoding
----------------------------------------------------------------------
Test.suite("Hex Encoding")

Test.equal(string.to_hex("Hello"), "48656c6c6f", "to_hex lowercase")
Test.equal(string.to_hex("Hello", true), "48656C6C6F", "to_hex uppercase")
Test.equal(string.from_hex("48656c6c6f"), "Hello", "from_hex")
Test.equal(string.from_hex("00ff"), "\0\255", "from_hex null+ff")
Test.equal(string.ToHex("AB"), "4142", "ToHex alias")
Test.equal(string.FromHex("4142"), "AB", "FromHex alias")

----------------------------------------------------------------------
-- Path Operations
----------------------------------------------------------------------
Test.suite("Path Operations")

-- split_path
Test.deep_equal(string.split_path("a.b.c"), { "a", "b", "c" }, "split_path")

-- normalize_path_separators
Test.equal(string.normalize_path_separators("a\\b/c"), "a/b/c", "normalize to unix")
Test.equal(string.normalize_path_separators("a\\b/c", "\\"), "a\\b\\c", "normalize to windows")

-- to_unix_path / to_windows_path
Test.equal(string.to_unix_path("a\\b\\c"), "a/b/c", "to_unix_path")
Test.equal(string.to_windows_path("a/b/c"), "a\\b\\c", "to_windows_path")

-- normalize_path
Test.equal(string.normalize_path("a/b/../c"), "a/c", "normalize_path resolve ..")
Test.equal(string.normalize_path("a/./b"), "a/b", "normalize_path resolve .")
Test.equal(string.normalize_path("/a/b/../c"), "/a/c", "normalize_path absolute")
Test.equal(string.normalize_path("a//b///c"), "a/b/c", "normalize_path collapse slashes")

-- path_dir / path_file / path_ext / path_name
Test.equal(string.path_dir("folder/sub/file.txt"), "folder/sub", "path_dir")
Test.equal(string.path_dir("file.txt"), "", "path_dir no dir")
Test.equal(string.path_file("folder/sub/file.txt"), "file.txt", "path_file")
Test.equal(string.path_ext("file.tar.gz"), "gz", "path_ext")
Test.equal(string.path_ext("file"), "", "path_ext none")
Test.equal(string.path_name("file.tar.gz"), "file.tar", "path_name")
Test.equal(string.path_name("file"), "file", "path_name no ext")

-- aliases
Test.equal(string.dirname("a/b/c.txt"), "a/b", "dirname alias")
Test.equal(string.basename("a/b/c.txt"), "c.txt", "basename alias")
Test.equal(string.extension("a.txt"), "txt", "extension alias")
Test.equal(string.name_without_ext("a.txt"), "a", "name_without_ext alias")

-- path_join
Test.equal(string.path_join("a", "b", "c"), "a/b/c", "path_join basic")
Test.equal(string.path_join("a/", "/b/", "c"), "a/b/c", "path_join normalize")
Test.equal(string.PathJoin("x", "y"), "x/y", "PathJoin alias")

-- is_absolute_path / is_relative_path
Test.equal(string.is_absolute_path("/foo"), true, "is_absolute unix")
Test.equal(string.is_absolute_path("C:\\foo"), true, "is_absolute windows")
Test.equal(string.is_absolute_path("foo/bar"), false, "is_absolute relative")
Test.equal(string.is_relative_path("foo"), true, "is_relative")
Test.equal(string.is_relative_path("/foo"), false, "is_relative absolute")

-- to_absolute_path
Test.equal(string.to_absolute_path("file.txt", "/base"), "/base/file.txt", "to_absolute_path")
Test.equal(string.to_absolute_path("/abs", "/base"), "/abs", "to_absolute_path already abs")

-- path_relative
Test.equal(string.path_relative("/a/b/c", "/a/b"), "c", "path_relative child")
Test.equal(string.path_relative("/a/b/c", "/a/x"), "../b/c", "path_relative sibling")

-- path_split / path_split_ext
do
	local dir, file = string.path_split("folder/file.txt")
	Test.equal(dir, "folder", "path_split dir")
	Test.equal(file, "file.txt", "path_split file")
end
do
	local name, ext = string.path_split_ext("file.txt")
	Test.equal(name, "file", "path_split_ext name")
	Test.equal(ext, "txt", "path_split_ext ext")
end

-- path_has_extension
Test.equal(string.path_has_extension("file.txt"), true, "path_has_extension true")
Test.equal(string.path_has_extension("file"), false, "path_has_extension false")

-- path_change_extension / add / remove
Test.equal(string.path_change_extension("file.txt", "md"), "file.md", "path_change_extension")
Test.equal(string.path_change_extension("file.txt", ".lua"), "file.lua", "path_change_extension with dot")
Test.equal(string.path_add_extension("file", "txt"), "file.txt", "path_add_extension")
Test.equal(string.path_add_extension("file.txt", "md"), "file.txt", "path_add_extension existing")
Test.equal(string.path_remove_extension("file.txt"), "file", "path_remove_extension")

-- path_common_prefix
Test.equal(string.path_common_prefix("/a/b/c", "/a/b/d"), "/a/b", "path_common_prefix")
Test.equal(string.path_common_prefix("/a/b", "/x/y"), "/", "path_common_prefix root only")

-- path_components / path_from_components
Test.deep_equal(string.path_components("a/b/c"), { "a", "b", "c" }, "path_components")
Test.equal(string.path_from_components({ "a", "b", "c" }), "a/b/c", "path_from_components")
Test.equal(string.path_from_components({ "a", "b" }, "\\"), "a\\b", "path_from_components win")

-- trailing/leading separator
Test.equal(string.path_trim_trailing_separator("folder/"), "folder", "trim trailing")
Test.equal(string.path_has_trailing_separator("folder/"), true, "has trailing true")
Test.equal(string.path_has_trailing_separator("folder"), false, "has trailing false")
Test.equal(string.path_trim_leading_separator("/folder"), "folder", "trim leading")
Test.equal(string.path_has_leading_separator("/folder"), true, "has leading true")
Test.equal(string.path_has_leading_separator("folder"), false, "has leading false")

-- path_is_same
Test.equal(string.path_is_same("a/b/c", "a//b/./c"), true, "path_is_same normalized")
Test.equal(string.path_is_same("a/b", "c/d"), false, "path_is_same different")

-- drive operations
Test.equal(string.path_get_drive("C:\\folder"), "C:", "path_get_drive")
Test.equal(string.path_get_drive("/unix"), "", "path_get_drive unix")
Test.equal(string.path_without_drive("C:\\folder"), "\\folder", "path_without_drive")
Test.equal(string.path_without_drive("/unix"), "/unix", "path_without_drive unix")

-- root operations
Test.equal(string.path_get_root("/foo"), "/", "path_get_root unix")
Test.equal(string.path_get_root("C:\\foo"), "C:\\", "path_get_root windows")
Test.equal(string.path_is_root("/"), true, "path_is_root unix")
Test.equal(string.path_is_root("/foo"), false, "path_is_root not root")

-- ancestor / child
Test.equal(string.path_ancestor("/a/b/c", "/a/b"), true, "path_ancestor true")
Test.equal(string.path_ancestor("/a/b/c", "/x"), false, "path_ancestor false")
Test.equal(string.path_is_child("/a/b/c", "/a/b"), true, "path_is_child true")
Test.equal(string.path_is_child("/a/b/c", "/x"), false, "path_is_child false")

-- path_clean
Test.equal(string.path_clean("a\\b//c/"), "a/b/c", "path_clean")
Test.equal(string.path_clean("/"), "/", "path_clean root")

-- path_parent / has_parent / depth
Test.equal(string.path_parent("a/b/c"), "a/b", "path_parent")
Test.equal(string.path_parent("file"), ".", "path_parent no parent")
Test.equal(string.path_has_parent("a/b"), true, "path_has_parent true")
Test.equal(string.path_has_parent("file"), false, "path_has_parent false")
Test.equal(string.path_depth("a/b/c"), 3, "path_depth")
Test.equal(string.path_depth("file"), 1, "path_depth single")

-- path_sanitize
Test.equal(string.path_sanitize("file<>name"), "filename", "path_sanitize invalid chars")
Test.equal(string.path_sanitize("  spaced  "), "spaced", "path_sanitize trim")

-- path_make_absolute / path_make_relative (aliases)
Test.equal(string.path_make_absolute("f.txt", "/base"), "/base/f.txt", "path_make_absolute")
Test.equal(string.path_make_relative("/a/b/c", "/a/b"), "c", "path_make_relative")

----------------------------------------------------------------------
-- Casing Detection & Conversion
----------------------------------------------------------------------
Test.suite("Casing")

Test.equal(string.detect_casing_style("helloWorld"), "camelCase", "detect camelCase")
Test.equal(string.detect_casing_style("HelloWorld"), "PascalCase", "detect PascalCase")
Test.equal(string.detect_casing_style("hello_world"), "snake_case", "detect snake_case")
Test.equal(string.detect_casing_style("HELLO_WORLD"), "SCREAMING_SNAKE_CASE", "detect SCREAMING")
Test.equal(string.detect_casing_style("hello-world"), "kebab-case", "detect kebab-case")
Test.equal(string.detect_casing_style("hello world"), "space_case", "detect space_case")
Test.equal(string.detect_casing_style("HELLO WORLD"), "UPPER_SPACE_CASE", "detect UPPER_SPACE")
Test.equal(string.detect_casing_style("hello"), "lowercase", "detect lowercase")
Test.equal(string.detect_casing_style("HELLO"), "UPPERCASE", "detect UPPERCASE")
Test.equal(string.detect_casing_style(""), "unknown", "detect empty")
Test.equal(string.DetectCasingStyle("fooBar"), "camelCase", "DetectCasingStyle alias")

Test.equal(string.to_snake_case("HelloWorld"), "hello_world", "to_snake_case PascalCase")
Test.equal(string.to_snake_case("helloWorld"), "hello_world", "to_snake_case camelCase")
Test.equal(string.to_snake_case("hello-world"), "hello_world", "to_snake_case kebab")
Test.equal(string.to_snake_case("Hello World"), "hello_world", "to_snake_case space")
Test.equal(string.ToSnakeCase("ABCDef"), "a_b_c_def", "ToSnakeCase alias")

Test.equal(string.to_camel_case("hello_world"), "helloWorld", "to_camel_case snake")
Test.equal(string.to_camel_case("hello-world"), "helloWorld", "to_camel_case kebab")
Test.equal(string.to_camel_case("HelloWorld"), "helloWorld", "to_camel_case PascalCase")
Test.equal(string.ToCamelCase("foo_bar_baz"), "fooBarBaz", "ToCamelCase alias")

Test.equal(string.to_pascal_case("hello_world"), "HelloWorld", "to_pascal_case snake")
Test.equal(string.to_pascal_case("hello-world"), "HelloWorld", "to_pascal_case kebab")
Test.equal(string.to_pascal_case("helloWorld"), "HelloWorld", "to_pascal_case camelCase")
Test.equal(string.ToPascalCase("foo_bar"), "FooBar", "ToPascalCase alias")

----------------------------------------------------------------------
-- resolve_absolute_range / is_printable
----------------------------------------------------------------------
Test.suite("Range & Printable")

do
	local s, e, empty = string.resolve_absolute_range(10, 2, 5)
	Test.equal(s, 2, "resolve start")
	Test.equal(e, 5, "resolve end")
	Test.equal(empty, false, "resolve not empty")
end
do
	local s, e, empty = string.resolve_absolute_range(10, -3, -1)
	Test.equal(s, 8, "resolve negative start")
	Test.equal(e, 10, "resolve negative end")
	Test.equal(empty, false, "resolve negative not empty")
end
do
	local _, _, empty = string.resolve_absolute_range(5, 4, 2)
	Test.equal(empty, true, "resolve inverted range empty")
end

Test.equal(string.is_printable("Hello World!"), true, "is_printable ascii")
Test.equal(string.is_printable("Hello\nWorld"), false, "is_printable newline")
Test.equal(string.is_printable(""), true, "is_printable empty")
Test.equal(string.is_printable("abc", 1, 1), true, "is_printable range")
Test.equal(string.IsPrintable("\t"), false, "IsPrintable tab")

----------------------------------------------------------------------
-- URL Encode / Decode
----------------------------------------------------------------------
Test.suite("URL Encode/Decode")

Test.equal(string.url_encode("hello world"), "hello%20world", "url_encode space")
Test.equal(string.url_encode("user@email.com"), "user%40email.com", "url_encode @")
Test.equal(string.url_encode("a-b_c.d~e"), "a-b_c.d~e", "url_encode unreserved")

Test.equal(string.url_decode("hello%20world"), "hello world", "url_decode space")
Test.equal(string.url_decode("hello+world"), "hello world", "url_decode plus")
Test.equal(string.url_decode("user%40email.com"), "user@email.com", "url_decode @")

Test.equal(string.UrlEncode("test"), "test", "UrlEncode alias")
Test.equal(string.UrlDecode("test"), "test", "UrlDecode alias")

----------------------------------------------------------------------
-- Query String Parse / Build
----------------------------------------------------------------------
Test.suite("Query String")

do
	local q = string.parse_query("key1=value1&key2=value2")
	Test.equal(q.key1, "value1", "parse_query key1")
	Test.equal(q.key2, "value2", "parse_query key2")
end
do
	local q = string.parse_query("name=John&name=Jane")
	Test.assert(type(q.name) == "table", "parse_query duplicate keys -> table")
	Test.equal(q.name[1], "John", "parse_query dup first")
	Test.equal(q.name[2], "Jane", "parse_query dup second")
end
do
	local q = string.parse_query("")
	Test.deep_equal(q, {}, "parse_query empty")
end

do
	local s = string.build_query({ key1 = "value1", key2 = "value2" })
	Test.assert(s:find("key1=value1", 1, true), "build_query contains key1")
	Test.assert(s:find("key2=value2", 1, true), "build_query contains key2")
	Test.assert(s:find("&", 1, true), "build_query has separator")
end
do
	local s = string.build_query({ name = { "John", "Jane" } })
	Test.assert(s:find("name=John", 1, true), "build_query array first")
	Test.assert(s:find("name=Jane", 1, true), "build_query array second")
end

----------------------------------------------------------------------
-- URL Parse / Components
----------------------------------------------------------------------
Test.suite("URL Parsing")

do
	local url = "https://user:pass@example.com:8080/path?query=value#fragment"
	local p = string.parse_url(url)
	Test.equal(p.scheme, "https", "parse_url scheme")
	Test.equal(p.username, "user", "parse_url username")
	Test.equal(p.password, "pass", "parse_url password")
	Test.equal(p.host, "example.com", "parse_url host")
	Test.equal(p.port, "8080", "parse_url port")
	Test.equal(p.path, "/path", "parse_url path")
	Test.equal(p.query, "query=value", "parse_url query")
	Test.equal(p.fragment, "fragment", "parse_url fragment")
	Test.equal(p.authority, "user:pass@example.com:8080", "parse_url authority")
end

-- Component extractors
do
	local url = "https://user:pass@example.com:8080/path?q=1#frag"
	Test.equal(string.url_scheme(url), "https", "url_scheme")
	Test.equal(string.url_host(url), "example.com", "url_host")
	Test.equal(string.url_port(url), "8080", "url_port")
	Test.equal(string.url_path(url), "/path", "url_path")
	Test.equal(string.url_query(url), "q=1", "url_query")
	Test.equal(string.url_fragment(url), "frag", "url_fragment")
	Test.equal(string.url_username(url), "user", "url_username")
	Test.equal(string.url_password(url), "pass", "url_password")
	Test.equal(string.url_authority(url), "user:pass@example.com:8080", "url_authority")
end

-- Aliases
Test.equal(string.UrlScheme("http://x"), "http", "UrlScheme alias")
Test.equal(string.UrlHost("http://x"), "x", "UrlHost alias")

-- is_absolute_url
Test.equal(string.is_absolute_url("https://example.com"), true, "is_absolute_url true")
Test.equal(string.is_absolute_url("/path"), false, "is_absolute_url false")
Test.equal(string.IsAbsoluteUrl("ftp://x"), true, "IsAbsoluteUrl alias")

-- resolve_url
Test.equal(string.resolve_url("/path", "https://example.com/base/"),
	"https://example.com/path", "resolve_url absolute path")
Test.equal(string.resolve_url("../other", "https://example.com/a/b/"),
	"https://example.com/a/other", "resolve_url relative ..")
Test.equal(string.resolve_url("https://other.com", "https://example.com"),
	"https://other.com", "resolve_url absolute relative")
Test.equal(string.resolve_url("//cdn.example.com/lib", "https://example.com"),
	"https://cdn.example.com/lib", "resolve_url protocol-relative")

-- split_url
do
	local base, endpoint = string.split_url("https://example.com/path?key=value#section")
	Test.equal(base, "https://example.com", "split_url base")
	Test.equal(endpoint, "/path?key=value#section", "split_url endpoint")
end
do
	local base, endpoint = string.split_url("https://example.com")
	Test.equal(base, "https://example.com", "split_url base no path")
	Test.equal(endpoint, "/", "split_url endpoint defaults to /")
end

----------------------------------------------------------------------
-- ANSI / Visual Length / Strip
----------------------------------------------------------------------
Test.suite("ANSI & Visual Length")

Test.equal(string.strip_ansi("\27[31mhello\27[0m"), "hello", "strip_ansi")
Test.equal(string.StripAnsi("plain"), "plain", "StripAnsi no codes")

Test.equal(string.visible_length("\27[31mhello\27[0m"), 5, "visible_length colored")
Test.equal(string.visible_length("hello"), 5, "visible_length plain")
Test.equal(string.VisibleLength(""), 0, "VisibleLength empty")

-- ulen
Test.equal(string.ulen("hello"), 5, "ulen ascii")

-- substring (UTF-8 safe fallback)
Test.equal(string.substring("hello", 1, 3), "hel", "substring basic")
Test.equal(string.substring("hello", -2), "lo", "substring negative")
Test.equal(string.Substring("abcdef", 2, 4), "bcd", "Substring alias")

----------------------------------------------------------------------
-- Truncate / Abbreviate
----------------------------------------------------------------------
Test.suite("Truncate & Abbreviate")

Test.equal(string.truncate("Hello World", 8), "Hello...", "truncate basic")
Test.equal(string.truncate("Hi", 10), "Hi", "truncate short string")
Test.equal(string.truncate("Hello World", 8, { ellipsis = ".." }), "Hello ..", "truncate custom ellipsis")
Test.equal(string.Truncate("abcdef", 4), "a...", "Truncate alias")

Test.equal(string.truncate_middle("Hello World", 8), "Hel...ld", "truncate_middle basic")
Test.equal(string.truncate_middle("Hi", 10), "Hi", "truncate_middle short")
Test.equal(string.TruncateMiddle("abcdefgh", 6), "ab...gh", "TruncateMiddle alias")

Test.equal(string.abbreviate("Hello World", 5), "HW", "abbreviate initials")
Test.equal(string.abbreviate("Hello World", 10, { mode = "compact" }), "HelWor", "abbreviate compact")
Test.equal(string.Abbreviate("Foo Bar Baz", 3), "FBB", "Abbreviate alias")

----------------------------------------------------------------------
-- Indent / Dedent
----------------------------------------------------------------------
Test.suite("Indent & Dedent")

Test.equal(string.indent("Hello\nWorld", " ", 2), "  Hello\n  World", "indent spaces")
Test.equal(string.indent("A\nB", "\t", 1), "\tA\n\tB", "indent tab")
Test.equal(string.Indent("x", ">>", 1), ">>x", "Indent alias")

Test.equal(string.dedent("  Hello\n  World", 2), "Hello\nWorld", "dedent count")
Test.equal(string.dedent(">>Hello\n>>World", ">>"), "Hello\nWorld", "dedent prefix")
do
	-- Auto-dedent: find minimum common indent
	local result = string.dedent("    A\n    B")
	Test.equal(result, "A\nB", "dedent auto")
end
Test.equal(string.Dedent("  x", 2), "x", "Dedent alias")

----------------------------------------------------------------------
-- Template Engine
----------------------------------------------------------------------
Test.suite("Template Engine")

do
	local r = string.template("Hello {{name}}!", { name = "World" })
	Test.equal(r, "Hello World!", "template basic var")
end
do
	local r = string.template("{{{raw}}}", { raw = "<b>bold</b>" })
	Test.equal(r, "<b>bold</b>", "template raw triple brace")
end
do
	local r = string.template("{{val|upper}}", { val = "hello" })
	Test.equal(r, "HELLO", "template filter upper")
end
do
	local r = string.template("{{val|lower}}", { val = "HELLO" })
	Test.equal(r, "hello", "template filter lower")
end
do
	local tpl = "{{#items}}- {{.}}\n{{/items}}"
	local r = string.template(tpl, { items = { "a", "b", "c" } })
	Test.equal(r, "- a\n- b\n- c\n", "template section array")
end
do
	local r = string.template("{{^missing}}default{{/missing}}", {})
	Test.equal(r, "default", "template inverted section")
end
do
	local r = string.template("{{^present}}hidden{{/present}}", { present = true })
	Test.equal(r, "", "template inverted section hidden when truthy")
end

-- compile_template caching
do
	local fn1 = string.compile_template("cached {{x}}")
	local fn2 = string.compile_template("cached {{x}}")
	Test.equal(fn1, fn2, "compile_template cache hit")
	Test.equal(fn1({ x = "ok" }), "cached ok", "compiled renderer works")
end

Test.equal(string.Template("{{a}}", { a = "1" }), "1", "Template alias")
Test.equal(string.CompileTemplate("test")({}), "test", "CompileTemplate alias")

----------------------------------------------------------------------
-- Interpolate
----------------------------------------------------------------------
Test.suite("Interpolate")

Test.equal(string.interpolate("Hello, {name}!", { name = "World" }), "Hello, World!", "interpolate basic")
Test.equal(string.interpolate("{x}+{y}", { x = 1, y = 2 }), "1+2", "interpolate multiple")
Test.equal(string.interpolate("{missing}", {}), "{missing}", "interpolate missing key preserved")
Test.equal(string.Interpolate("{a}", { a = "b" }), "b", "Interpolate alias")

----------------------------------------------------------------------
-- Align / AlignAnsi
----------------------------------------------------------------------
Test.suite("Alignment")

Test.equal(string.align("hi", "left", 6), "hi    ", "align left")
Test.equal(string.align("hi", "right", 6), "    hi", "align right")
Test.equal(string.align("hi", "center", 6), "  hi  ", "align center")
Test.equal(string.Align("x", "left", 3), "x  ", "Align alias")

-- align_ansi preserves ANSI codes
do
	local colored = "\27[31mhi\27[0m"
	local result = string.align_ansi(colored, "left", 6)
	Test.assert(result:find("\27[31m", 1, true), "align_ansi preserves ANSI start")
	Test.assert(result:find("\27[0m", 1, true), "align_ansi preserves ANSI end")
	Test.equal(string.visible_length(result), 6, "align_ansi visual width correct")
end
Test.equal(string.AlignAnsi("x", "right", 4), "   x", "AlignAnsi alias")

----------------------------------------------------------------------
-- Box Drawing
----------------------------------------------------------------------
Test.suite("Box Drawing")

do
	local b = string.box("Hi", { style = "ascii", padding = 0 })
	Test.assert(b:find("+--+", 1, true), "box ascii top border")
	Test.assert(b:find("|Hi|", 1, true), "box ascii content")
end
do
	local b = string.box("Test", { style = "single", title = "T" })
	Test.assert(b:find("┌", 1, true), "box single top-left corner")
	Test.assert(b:find("T", 1, true), "box title present")
end
Test.equal(type(string.Box("x")), "string", "Box alias returns string")

----------------------------------------------------------------------
-- Progress Bar / Loaders
----------------------------------------------------------------------
Test.suite("Progress Bar & Loaders")

do
	local bar = string.progress_bar(50, 100, 20)
	Test.assert(bar:find("50%%", 1, true), "progress_bar shows 50%")
	Test.assert(bar:find("%[", 1, true), "progress_bar has opening cap")
	Test.assert(bar:find("%]", 1, true), "progress_bar has closing cap")
end
do
	local bar = string.progress_bar(0, 100, 10, { caps = false, show_percent = false })
	Test.assert(not bar:find("%[", 1, true), "progress_bar no caps")
	Test.assert(not bar:find("%%", 1, true), "progress_bar no percent")
end
Test.equal(type(string.ProgressBar(1, 2)), "string", "ProgressBar alias")

-- ASCII loader cycles through 4 frames
do
	local frames_seen = {}
	for i = 1, 8 do
		frames_seen[string.ascii_loader(i)] = true
	end
	Test.assert(frames_seen["|"], "ascii_loader has |")
	Test.assert(frames_seen["/"], "ascii_loader has /")
	Test.assert(frames_seen["-"], "ascii_loader has -")
	Test.assert(frames_seen["\\"], "ascii_loader has \\")
end
Test.equal(type(string.ASCIILoader(1)), "string", "ASCIILoader alias")

-- Braille loader cycles through 10 frames
do
	local f1 = string.braille_loader(1)
	local f11 = string.braille_loader(11)
	Test.equal(f1, f11, "braille_loader wraps at 10")
	Test.assert(type(f1) == "string" and #f1 > 0, "braille_loader returns non-empty")
end
Test.equal(type(string.BrailleLoader(1)), "string", "BrailleLoader alias")

----------------------------------------------------------------------
-- XOR Cipher
----------------------------------------------------------------------
Test.suite("XOR Cipher")

do
	local encrypted = string.xor_cipher("hello", "key")
	Test.assert(encrypted ~= "hello", "xor_cipher encrypts")
	local decrypted = string.xor_cipher(encrypted, "key")
	Test.equal(decrypted, "hello", "xor_cipher roundtrip")
end
do
	-- Empty key should error
	local ok_err = pcall(string.xor_cipher, "test", "")
	Test.equal(ok_err, false, "xor_cipher empty key errors")
end
Test.equal(type(string.XorCipher("a", "k")), "string", "XorCipher alias")

----------------------------------------------------------------------
-- Surround / Between
----------------------------------------------------------------------
Test.suite("Surround & Between")

Test.equal(string.surround("hello", "*"), "*hello*", "surround basic")
Test.equal(string.surround("test", "[]"), "[]test[]", "surround multi-char")
Test.equal(string.Surround("x", ""), "x", "Surround empty wrapper")

Test.equal(string.between("a [b] c", "[", "]"), "b", "between basic")
Test.equal(string.between("start<value>end", "<", ">"), "value", "between angle")
Test.equal(string.between("no delimiters", "[", "]"), nil, "between not found")
Test.equal(string.Between("(x)", "(", ")"), "x", "Between alias")

----------------------------------------------------------------------
-- Remove Non-Printable / Non-ASCII
----------------------------------------------------------------------
Test.suite("Remove Characters")

Test.equal(string.remove_non_printable("hello\nworld"), "helloworld", "remove_non_printable")
Test.equal(string.remove_non_printable("text\twith\rcodes"), "textwithcodes", "remove_non_printable control")
Test.equal(string.RemoveNonPrintable("a\0b"), "ab", "RemoveNonPrintable alias")

Test.equal(string.remove_non_ascii("héllo"), "hllo", "remove_non_ascii accented")
Test.equal(string.remove_non_ascii("café"), "caf", "remove_non_ascii café")
Test.equal(string.remove_non_ascii("hello"), "hello", "remove_non_ascii pure ascii")
Test.equal(string.RemoveNonASCII("abc"), "abc", "RemoveNonASCII alias")

----------------------------------------------------------------------
-- Truncate Words
----------------------------------------------------------------------
Test.suite("Truncate Words")

Test.equal(string.truncate_words("a b c d", 2), "a b~", "truncate_words basic")
Test.equal(string.truncate_words("one two three", 5), "one two three", "truncate_words under limit")
Test.equal(string.truncate_words("hello world", 1, "..."), "hello...", "truncate_words custom suffix")
Test.equal(string.TruncateWords("x y z", 2), "x y~", "TruncateWords alias")

----------------------------------------------------------------------
-- Append/Prepend If Empty/NotEmpty
----------------------------------------------------------------------
Test.suite("Conditional Append/Prepend")

Test.equal(string.append_if_empty("", "default"), "default", "append_if_empty on empty")
Test.equal(string.append_if_empty("hello", "default"), "hello", "append_if_empty on non-empty")
Test.equal(string.AppendIfEmpty("", "x"), "x", "AppendIfEmpty alias")

Test.equal(string.prepend_if_empty("", "default"), "default", "prepend_if_empty on empty")
Test.equal(string.prepend_if_empty("hello", "default"), "hello", "prepend_if_empty on non-empty")
Test.equal(string.PrependIfEmpty("", "x"), "x", "PrependIfEmpty alias")

Test.equal(string.append_if_not_empty("hello", "!"), "hello!", "append_if_not_empty on non-empty")
Test.equal(string.append_if_not_empty("", "!"), "", "append_if_not_empty on empty")
Test.equal(string.AppendIfNotEmpty("x", "!"), "x!", "AppendIfNotEmpty alias")

Test.equal(string.prepend_if_not_empty("hello", "> "), "> hello", "prepend_if_not_empty on non-empty")
Test.equal(string.prepend_if_not_empty("", "> "), "", "prepend_if_not_empty on empty")
Test.equal(string.PrependIfNotEmpty("x", ">"), ">x", "PrependIfNotEmpty alias")

----------------------------------------------------------------------
-- Count
----------------------------------------------------------------------
Test.suite("Count")

Test.equal(string.count("banana", "a"), 3, "count pattern")
Test.equal(string.count("hello world", "l"), 3, "count letter")
Test.equal(string.count("test", "z"), 0, "count no match")
Test.equal(string.count("banana", "a", true), 3, "count plain")
Test.equal(string.count("test.test", ".", true), 1, "count plain dot")
Test.equal(string.Count("aaa", "a"), 3, "Count alias")

----------------------------------------------------------------------
-- Splice
----------------------------------------------------------------------
Test.suite("Splice")

Test.equal(string.splice("abcdef", 3, 2, "XY"), "abXYef", "splice delete+insert")
Test.equal(string.splice("abcdef", 3, 0, "XYZ"), "abXYZcdef", "splice insert only")
Test.equal(string.splice("abcdef", 1, 2, ""), "cdef", "splice delete only")
Test.equal(string.Splice("abcd", 2, 1, "X"), "aXcd", "Splice alias")

----------------------------------------------------------------------
-- Plural
----------------------------------------------------------------------
Test.suite("Plural")

Test.equal(string.plural("cat", 1), "cat", "plural singular")
Test.equal(string.plural("cat", 2), "cats", "plural regular")
Test.equal(string.plural("person", 5), "people", "plural irregular person")
Test.equal(string.plural("child", 3), "children", "plural irregular child")
Test.equal(string.plural("box", 2), "boxes", "plural -es rule")
Test.equal(string.plural("city", 2), "cities", "plural -ies rule")
Test.equal(string.plural("knife", 2), "knives", "plural -ves rule (fe)")
Test.equal(string.plural("wolf", 2), "wolves", "plural -ves rule (f)")
Test.equal(string.Plural("dog", 3), "dogs", "Plural alias")

----------------------------------------------------------------------
-- safe tostring
----------------------------------------------------------------------
Test.suite("Safe ToString")

Test.equal(string.safe(nil), "", "safe nil")
Test.equal(string.safe(42), "42", "safe number")
Test.equal(string.safe("hello"), "hello", "safe string")
Test.equal(string.Safe(nil), "", "Safe alias")

----------------------------------------------------------------------
-- parse (Lua string literal parser)
----------------------------------------------------------------------
Test.suite("Parse String Literal")

do
	local result = string.parse("'hello world'")
	Test.equal(result.ok, true, "parse simple quoted ok")
	Test.equal(result.value, "hello world", "parse simple quoted value")
end
do
	local result = string.parse('"escaped\\nnewline"')
	Test.equal(result.ok, true, "parse escaped ok")
	Test.equal(result.value, "escaped\nnewline", "parse escaped value")
end
do
	local result = string.parse("[[long bracket]]")
	Test.equal(result.ok, true, "parse long bracket ok")
	Test.equal(result.value, "long bracket", "parse long bracket value")
end
do
	local result = string.parse("'unterminated")
	Test.equal(result.ok, false, "parse unterminated fails")
end
Test.equal(type(string.Parse), "function", "Parse alias exists")

----------------------------------------------------------------------
-- Run Summary
----------------------------------------------------------------------
local all_passed = Test.summary()
os.exit(all_passed and 0 or 1)
