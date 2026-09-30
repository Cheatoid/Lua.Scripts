-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for lua_lexer.lua.
-- Run from this directory:
--   lua lua_lexer.lua
--   luajit lua_lexer.lua

-- Bootstrap: shared test bootstrap (see ../../.tools/bootstrap.lua).
do
	local src = debug.getinfo(1, "S").source
	local dir = src:match("^@(.+/)[^/]+$") or "./"
	local function isfile(p)
		local f = io.open(p, "r")
		if f then
			f:close()
			return true
		end
		return false
	end
	local boot
	for _, c in ipairs({
		dir .. "../../.tools/bootstrap.lua",
		dir .. "../.tools/bootstrap.lua",
		dir .. "../../../.tools/bootstrap.lua",
		"./.tools/bootstrap.lua",
		"../.tools/bootstrap.lua",
		"../../.tools/bootstrap.lua",
	}) do
		if isfile(c) then
			boot = c
			break
		end
	end
	assert(boot, "cheatoid test bootstrap not found (.tools/bootstrap.lua)")
	assert(dofile(boot))(dir)
end
local lib = require "lua_lexer"
-- Bridging: file-locals used by tests mapped to module exports.
local Lexer = lib

if true then
	local function firstToken(src, opts)
		return Lexer.new(src, opts):nextToken()
	end

	local function tokenize(src, opts)
		local lex = Lexer.new(src, opts)
		local toks = {}
		for tok in lex:tokens() do
			table.insert(toks, tok)
		end
		return toks
	end

	local function assertTokenType(src, expectedType, opts)
		local tok = firstToken(src, opts)
		assert(tok.type == expectedType, string.format("Expected %s, got %s for '%s'", expectedType, tok.type, src))
	end

	local function assertTokenValue(src, expectedValue, opts)
		local tok = firstToken(src, opts)
		assert(tok.value == expectedValue,
			string.format("Expected value '%s', got '%s' for '%s'", expectedValue, tok.value, src))
	end

	print("Running comprehensive lexer tests...")

	local toks

	-- ===== Keywords =====
	print("Testing keywords...")
	local keywords = { "and", "break", "do", "else", "elseif", "end", "false", "for", "function", "if", "in", "local",
		"nil", "not", "or", "repeat", "return", "then", "true", "until", "while" }
	for _, kw in ipairs(keywords) do
		assertTokenType(kw, "Keyword")
		assertTokenValue(kw, kw)
	end

	-- Version-specific keywords
	assertTokenType("goto", "Identifier", { luaVersion = "5.1" })
	assertTokenType("goto", "Keyword", { luaVersion = "5.2" })
	assertTokenType("goto", "Identifier", { luaVersion = "5.2", enableGoto = false })

	assertTokenType("continue", "Identifier")
	assertTokenType("continue", "Keyword", { enableContinue = true })
	assertTokenType("continue", "Identifier", { enableContinue = false })

	-- ===== Identifiers =====
	print("Testing identifiers...")
	local identifiers = { "myVar", "_private", "var123", "camelCase", "UPPER_CASE", "_", "__init", "a1b2c3" }
	for _, id in ipairs(identifiers) do
		assertTokenType(id, "Identifier")
		assertTokenValue(id, id)
	end

	-- ===== Numbers =====
	print("Testing numbers...")
	local validNumbers = {
		"123", "0", "1", "999",
		"3.14", "0.5", "1.0", ".5", "0.0",
		"1e10", "1E10", "1e-10", "1E-10", "1e+10", "1E+10",
		"1.5e10", "1.5E10", "1.5e-10", "1.5E-10",
		"0xFF", "0XFF", "0xff", "0Xff", "0xABCDEF", "0x123",
		"0x1.5p10", "0x1.5P10", "0x1.5p-10", "0x1.5P-10",
		"0x1p0", "0x1p1", "0x1p-1",
		"0x.5", "0x.5p10",
	}
	for _, num in ipairs(validNumbers) do
		assertTokenType(num, "Number")
		assertTokenValue(num, num)
	end

	-- Invalid numbers
	local invalidNumbers = {
		"1e", "1E", "1e+", "1E+", "1e-", "1E-",
		"0x", "0X", "0x.", "0X.",
		"0x1p", "0x1P", "0x1p+", "0x1P+", "0x1p-", "0x1P-",
	}
	for _, num in ipairs(invalidNumbers) do
		assertTokenType(num, "Error")
	end

	-- Hex concat should not swallow ..
	local lex = Lexer.new("0x1..2")
	assert(lex:nextToken().type == "Number")
	assert(lex:nextToken().type == "Punct")
	assert(lex:nextToken().type == "Number")

	-- Decimal concat should not swallow ..
	lex = Lexer.new("1..2")
	assert(lex:nextToken().type == "Number")
	assert(lex:nextToken().type == "Punct")
	assert(lex:nextToken().type == "Number")

	-- ===== Strings =====
	print("Testing strings...")
	local shortStrings = {
		{ src = [["hello"]], expected = [["hello"]] },
		{ src = [['world']], expected = [['world']] },
		{ src = [[""]],      expected = [[""]] },
		{ src = [['']],      expected = [['']] },
		{ src = [["a"]],     expected = [["a"]] },
		{ src = [['b']],     expected = [['b']] },
	}
	for _, t in ipairs(shortStrings) do
		assertTokenType(t.src, "String")
		assertTokenValue(t.src, t.expected)
	end

	-- String escapes
	local escapedStrings = {
		{ src = [["escaped \"quote\""]], expected = [[escaped "quote"]] },
		{ src = [["escaped \'quote\'"]], expected = [[escaped 'quote']] },
		{ src = [["backslash\\slash"]],  expected = [[backslash\slash]] },
		{ src = [["newline\n"]],         expected = "newline\n" },
		{ src = [["tab\t"]],             expected = "tab\t" },
		{ src = [["carriage\r"]],        expected = "carriage\r" },
		{ src = [["bell\a"]],            expected = "bell\a" },
		{ src = [["vertical\v"]],        expected = "vertical\v" },
		{ src = [["backspace\b"]],       expected = "backspace\b" },
		{ src = [["formfeed\f"]],        expected = "formfeed\f" },
		{ src = [["null\0"]],            expected = "null\0" },
		{ src = [["line\\n"]],           expected = "line\\n" }, -- escaped escape
	}
	for _, t in ipairs(escapedStrings) do
		assertTokenType(t.src, "String")
	end

	-- Long strings
	local longStrings = {
		{ src = "[[hello]]",                    expected = "[[hello]]" },
		{ src = "[=[hello]=]",                  expected = "[=[hello]=]" },
		{ src = "[==[hello]==]",                expected = "[==[hello]==]" },
		{ src = "[[multi\nline]]",              expected = "[[multi\nline]]" },
		{ src = "[=[nested [=[ brackets ]=]=]", expected = "[=[nested [=[ brackets ]=]=]" },
	}
	for _, t in ipairs(longStrings) do
		assertTokenType(t.src, "LongString")
	end

	-- Escaped CRLF in short string
	assertTokenType([["a\r\nb"]], "String")

	-- Unterminated strings
	local unterminatedStrings = {
		[["unterminated]],
		[['unterminated]],
		[["unterminated\"]],
		[[[=[unterminated]],
	}
	for _, src in ipairs(unterminatedStrings) do
		assertTokenType(src, "Error")
	end

	-- ===== Operators =====
	print("Testing operators...")
	local operators = {
		"+", "-", "*", "/", "%", "^", "#",
		"=", "==", "~=", "<=", ">=", "<", ">",
	}
	for _, op in ipairs(operators) do
		assertTokenType(op, "Op")
		assertTokenValue(op, op)
	end

	-- Version-specific operators
	assertTokenType("//", "Op", { luaVersion = "5.2" })
	assertTokenType("//", "Op", { luaVersion = "5.3" })
	assertTokenType("//", "Op", { luaVersion = "5.3", enableFloorDiv = false })

	assertTokenType("&", "Error", { luaVersion = "5.2" })
	assertTokenType("&", "Op", { luaVersion = "5.3", enableBitwiseOps = true })
	assertTokenType("&", "Error", { luaVersion = "5.3", enableBitwiseOps = false })

	assertTokenType("|", "Error", { luaVersion = "5.2" })
	assertTokenType("|", "Op", { luaVersion = "5.3", enableBitwiseOps = true })
	assertTokenType("|", "Error", { luaVersion = "5.3", enableBitwiseOps = false })

	assertTokenType("~", "Error", { luaVersion = "5.2" })
	assertTokenType("~", "Op", { luaVersion = "5.3", enableBitwiseOps = true })
	assertTokenType("~", "Error", { luaVersion = "5.3", enableBitwiseOps = false })

	assertTokenType("<<", "Error", { luaVersion = "5.2" })
	assertTokenType("<<", "Op", { luaVersion = "5.3", enableBitwiseOps = true })
	assertTokenType("<<", "Error", { luaVersion = "5.3", enableBitwiseOps = false })

	assertTokenType(">>", "Error", { luaVersion = "5.2" })
	assertTokenType(">>", "Op", { luaVersion = "5.3", enableBitwiseOps = true })
	assertTokenType(">>", "Error", { luaVersion = "5.3", enableBitwiseOps = false })

	-- C-style operators
	assertTokenType("&&", "Error")
	assertTokenType("&&", "Op", { enableCOps = true })
	assertTokenType("||", "Error")
	assertTokenType("||", "Op", { enableCOps = true })
	assertTokenType("!=", "Error")
	assertTokenType("!=", "Op", { enableCOps = true })
	assertTokenType("!", "Error")
	assertTokenType("!", "Op", { enableCOps = true })

	-- Normalized C operators
	toks = tokenize("a && b", { enableCOps = true, normalizeCOps = true })
	assert(toks[2].type == "Keyword")
	assert(toks[2].normalized == "and")

	toks = tokenize("a || b", { enableCOps = true, normalizeCOps = true })
	assert(toks[2].type == "Keyword")
	assert(toks[2].normalized == "or")

	toks = tokenize("!a", { enableCOps = true, normalizeCOps = true })
	assert(toks[1].type == "Keyword")
	assert(toks[1].normalized == "not")

	toks = tokenize("a != b", { enableCOps = true, normalizeCOps = true })
	assert(toks[2].type == "Op")
	assert(toks[2].normalized == "~=")

	-- ===== Punctuation =====
	print("Testing punctuation...")
	local punctuations = {
		"(", ")", "{", "}", "[", "]", ",", ";", ":", "::", ".", "...", ".."
	}
	for _, p in ipairs(punctuations) do
		assertTokenType(p, "Punct")
		assertTokenValue(p, p)
	end

	-- ===== Comments =====
	print("Testing comments...")
	local lineComments = {
		"-- comment",
		"--",
		"-- 123",
		"-- !@#$",
	}
	for _, src in ipairs(lineComments) do
		toks = tokenize(src, { includeComments = true })
		assert(toks[1].type == "Comment")
		assert(toks[1].value == src)
	end

	local longComments = {
		{ "--[[comment]]",                    "--[[comment]]" },
		{ "--[[multi\nline]]",                "--[[multi\nline]]" },
		{ "--[=[comment]=]",                  "--[=[comment]=]" },
		{ "--[==[nested [=[ brackets ]=]==]", "--[==[nested [=[ brackets ]=]==]" },
	}
	for _, t in ipairs(longComments) do
		local src, expected = t[1], t[2]
		toks = tokenize(src, { includeComments = true })
		assert(toks[1].type == "Comment")
		assert(toks[1].value == expected)
	end

	-- C-style comments
	toks = tokenize("// C comment", { includeComments = true, enableCComments = true })
	assert(toks[1].type == "Comment")
	assert(toks[1].value == "// C comment")

	toks = tokenize("/* block comment */", { includeComments = true, enableCComments = true })
	assert(toks[1].type == "Comment")
	assert(toks[1].value == "/* block comment */")

	toks = tokenize("/* multi\nline */", { includeComments = true, enableCComments = true })
	assert(toks[1].type == "Comment")

	-- slashSlashMeansComment behavior
	toks = tokenize("// comment", { includeComments = true, enableCComments = false, slashSlashMeansComment = true })
	assert(toks[1].type == "Comment")

	toks = tokenize("// comment", { includeComments = true, enableCComments = false, slashSlashMeansComment = false })
	assert(toks[1].type == "Op") -- single /

	-- Unterminated comments
	local unterminatedComments = {
		"--[[unterminated",
		"--[=[unterminated",
		"/* unterminated",
	}
	for _, src in ipairs(unterminatedComments) do
		local opts = { includeComments = true, enableCComments = true }
		toks = tokenize(src, opts)
		assert(toks[1].type == "Error")
	end

	-- ===== Whitespace =====
	print("Testing whitespace...")
	toks = tokenize("a b", { includeWhitespace = true })
	assert(toks[2].type == "Whitespace")

	toks = tokenize("a  b", { includeWhitespace = true })
	assert(toks[2].type == "Whitespace")

	toks = tokenize("a\tb", { includeWhitespace = true })
	assert(toks[2].type == "Whitespace")

	toks = tokenize("a\nb", { includeWhitespace = true })
	assert(toks[2].type == "Newline")

	toks = tokenize("a\r\nb", { includeWhitespace = true })
	assert(toks[2].type == "Newline")

	toks = tokenize("a\rb", { includeWhitespace = true })
	assert(toks[2].type == "Newline")

	toks = tokenize("a\vb", { includeWhitespace = true })
	assert(toks[2].type == "Whitespace")

	toks = tokenize("a\fb", { includeWhitespace = true })
	assert(toks[2].type == "Whitespace")

	-- CRLF newline end column
	lex = Lexer.new("a\r\nb", { includeWhitespace = true })
	assert(lex:nextToken().type == "Identifier")
	local nl = lex:nextToken()
	assert(nl.type == "Newline")
	assert(nl.line == 1)
	assert(nl.col == 2)
	assert(nl.col2 == 3)

	-- ===== Complex expressions =====
	print("Testing complex expressions...")
	toks = tokenize("local x = 1 + 2 * 3")
	assert(toks[1].type == "Keyword") -- local
	assert(toks[2].type == "Identifier") -- x
	assert(toks[3].type == "Op")      -- =
	assert(toks[4].type == "Number")  -- 1
	assert(toks[5].type == "Op")      -- +
	assert(toks[6].type == "Number")  -- 2
	assert(toks[7].type == "Op")      -- *
	assert(toks[8].type == "Number")  -- 3

	toks = tokenize("function foo(a, b) return a + b end")
	assert(toks[1].type == "Keyword")  -- function
	assert(toks[2].type == "Identifier") -- foo
	assert(toks[3].type == "Punct")    -- (
	assert(toks[4].type == "Identifier") -- a
	assert(toks[5].type == "Punct")    -- ,
	assert(toks[6].type == "Identifier") -- b
	assert(toks[7].type == "Punct")    -- )
	assert(toks[8].type == "Keyword")  -- return
	assert(toks[9].type == "Identifier") -- a
	assert(toks[10].type == "Op")      -- +
	assert(toks[11].type == "Identifier") -- b
	assert(toks[12].type == "Keyword") -- end

	-- ===== Loops =====
	print("Testing loops...")
	toks = tokenize("for i = 1, 10 do print(i) end")
	assert(toks[1].type == "Keyword")  -- for
	assert(toks[2].type == "Identifier") -- i
	assert(toks[3].type == "Op")       -- =
	assert(toks[4].type == "Number")   -- 1
	assert(toks[5].type == "Punct")    -- ,
	assert(toks[6].type == "Number")   -- 10
	assert(toks[7].type == "Keyword")  -- do
	assert(toks[8].type == "Identifier") -- print
	assert(toks[9].type == "Punct")    -- (
	assert(toks[10].type == "Identifier") -- i
	assert(toks[11].type == "Punct")   -- )
	assert(toks[12].type == "Keyword") -- end

	toks = tokenize("for k, v in pairs(t) do print(k, v) end")
	assert(toks[1].type == "Keyword") -- for
	assert(toks[2].type == "Identifier") -- k
	assert(toks[3].type == "Punct")   -- ,
	assert(toks[4].type == "Identifier") -- v
	assert(toks[5].type == "Keyword") -- in
	assert(toks[6].type == "Identifier") -- pairs
	assert(toks[7].type == "Punct")   -- (
	assert(toks[8].type == "Identifier") -- t
	assert(toks[9].type == "Punct")   -- )
	assert(toks[10].type == "Keyword") -- do

	toks = tokenize("while true do break end")
	assert(toks[1].type == "Keyword") -- while
	assert(toks[2].type == "Keyword") -- true
	assert(toks[3].type == "Keyword") -- do
	assert(toks[4].type == "Keyword") -- break
	assert(toks[5].type == "Keyword") -- end

	toks = tokenize("repeat x = x + 1 until x > 10")
	assert(toks[1].type == "Keyword") -- repeat
	assert(toks[2].type == "Identifier") -- x
	assert(toks[3].type == "Op")      -- =
	assert(toks[4].type == "Identifier") -- x
	assert(toks[5].type == "Op")      -- +
	assert(toks[6].type == "Number")  -- 1
	assert(toks[7].type == "Keyword") -- until
	assert(toks[8].type == "Identifier") -- x
	assert(toks[9].type == "Op")      -- >
	assert(toks[10].type == "Number") -- 10

	-- ===== Conditionals =====
	print("Testing conditionals...")
	toks = tokenize("if x then y else z end")
	assert(toks[1].type == "Keyword") -- if
	assert(toks[2].type == "Identifier") -- x
	assert(toks[3].type == "Keyword") -- then
	assert(toks[4].type == "Identifier") -- y
	assert(toks[5].type == "Keyword") -- else
	assert(toks[6].type == "Identifier") -- z
	assert(toks[7].type == "Keyword") -- end

	toks = tokenize("if x then y elseif z then w end")
	assert(toks[1].type == "Keyword") -- if
	assert(toks[3].type == "Keyword") -- then
	assert(toks[5].type == "Keyword") -- elseif

	toks = tokenize("if x then y elseif z then w else v end")
	assert(toks[1].type == "Keyword") -- if
	assert(toks[3].type == "Keyword") -- then
	assert(toks[5].type == "Keyword") -- elseif
	assert(toks[7].type == "Keyword") -- then
	assert(toks[9].type == "Keyword") -- else

	-- ===== Varargs =====
	print("Testing varargs...")
	assertTokenType("...", "Punct")
	toks = tokenize("function(...) return ... end")
	assert(toks[3].type == "Punct") -- ... (toks[2] is '(')
	assert(toks[5].type == "Keyword") -- return (toks[4] is ')')
	assert(toks[6].type == "Punct") -- ...

	toks = tokenize("print(...)")
	assert(toks[3].type == "Punct") -- ... (toks[2] is '(')

	-- ===== Tables =====
	print("Testing tables...")
	toks = tokenize("{a = 1, b = 2}")
	assert(toks[1].type == "Punct")   -- {
	assert(toks[2].type == "Identifier") -- a
	assert(toks[3].type == "Op")      -- =
	assert(toks[4].type == "Number")  -- 1
	assert(toks[5].type == "Punct")   -- ,
	assert(toks[6].type == "Identifier") -- b
	assert(toks[7].type == "Op")      -- =
	assert(toks[8].type == "Number")  -- 2
	assert(toks[9].type == "Punct")   -- }

	toks = tokenize("{[1] = 'a', [2] = 'b'}")
	assert(toks[2].type == "Punct") -- [
	assert(toks[3].type == "Number") -- 1
	assert(toks[4].type == "Punct") -- ]

	toks = tokenize("{'a', 'b', 'c'}")
	assert(toks[2].type == "String") -- 'a'
	assert(toks[3].type == "Punct") -- ,
	assert(toks[4].type == "String") -- 'b'

	toks = tokenize("{x = 1, y = 2, z = 3}")
	assert(#toks == 13) -- {, x, =, 1, ,, y, =, 2, ,, z, =, 3}

	-- ===== Invalid code =====
	print("Testing invalid code...")
	local invalidChars = { "@", "$", "`", "\\", "§", "£", "¢", "€" }
	for _, ch in ipairs(invalidChars) do
		assertTokenType(ch, "Error")
	end

	-- Number followed by punctuation
	toks = tokenize("1..")
	assert(toks[1].type == "Number")
	assert(toks[2].type == "Punct")

	toks = tokenize("1...")
	assert(toks[1].type == "Number")
	assert(toks[2].type == "Punct")

	-- ===== BOM and Shebang =====
	print("Testing BOM and Shebang...")
	toks = tokenize("\xEF\xBB\xBFlocal x = 1")
	assert(toks[1].type == "Keyword") -- local (BOM skipped)

	toks = tokenize("#!/usr/bin/env lua\nlocal x = 1", { includeComments = true })
	assert(toks[1].type == "Comment")
	assert(toks[1].subtype == "Shebang")

	toks = tokenize("#!lua\nlocal x = 1", { includeComments = true })
	assert(toks[1].type == "Comment")
	assert(toks[1].subtype == "Shebang")

	-- ===== Edge cases =====
	print("Testing edge cases...")
	-- Empty string
	toks = tokenize("")
	assert(#toks == 0)
	local tok = Lexer.new(""):nextToken()
	assert(tok.type == "EOF")

	-- Only whitespace
	toks = tokenize("   \n\t  ", { includeWhitespace = true })
	assert(#toks > 1)

	-- Only newlines
	toks = tokenize("\n\n\n", { includeWhitespace = true })
	assert(toks[1].type == "Newline")
	assert(toks[2].type == "Newline")
	assert(toks[3].type == "Newline")

	-- Multiple consecutive operators
	toks = tokenize("1 + + 2")
	assert(toks[2].type == "Op") -- +
	assert(toks[3].type == "Op") -- +

	toks = tokenize("1 - - 2")
	assert(toks[2].type == "Op") -- -
	assert(toks[3].type == "Op") -- -

	-- Mixed whitespace
	toks = tokenize("a \t\n b", { includeWhitespace = true })
	assert(toks[2].type == "Whitespace")
	assert(toks[3].type == "Newline")
	assert(toks[4].type == "Whitespace")

	-- Comment at end of line
	toks = tokenize("x = 1 -- comment", { includeComments = true })
	assert(toks[1].type == "Identifier")
	assert(toks[2].type == "Op")
	assert(toks[3].type == "Number")
	assert(toks[4].type == "Comment")

	-- Multiple statements
	toks = tokenize("x = 1; y = 2; z = 3")
	assert(toks[4].type == "Punct") -- ;
	assert(toks[8].type == "Punct") -- ;

	-- Function call chains
	toks = tokenize("foo.bar.baz()")
	assert(toks[2].type == "Punct") -- .
	assert(toks[4].type == "Punct") -- .
	assert(toks[6].type == "Punct") -- (
	assert(toks[7].type == "Punct") -- )

	-- Method calls
	toks = tokenize("obj:method()")
	assert(toks[2].type == "Punct") -- :
	assert(toks[4].type == "Punct") -- (
	assert(toks[5].type == "Punct") -- )

	-- Labels and goto
	toks = tokenize("::label::", { luaVersion = "5.2" })
	assert(toks[1].type == "Punct")   -- ::
	assert(toks[2].type == "Identifier") -- label
	assert(toks[3].type == "Punct")   -- ::

	toks = tokenize("goto label", { luaVersion = "5.2" })
	assert(toks[1].type == "Keyword") -- goto
	assert(toks[2].type == "Identifier") -- label

	-- Table access with string keys
	toks = tokenize("t[\"key\"]")
	assert(toks[2].type == "Punct") -- [
	assert(toks[3].type == "String") -- "key"
	assert(toks[4].type == "Punct") -- ]

	-- Length operator
	toks = tokenize("#t")
	assert(toks[1].type == "Op")      -- #
	assert(toks[2].type == "Identifier") -- t

	-- Exponentiation
	toks = tokenize("2 ^ 10")
	assert(toks[2].type == "Op") -- ^

	-- Modulo
	toks = tokenize("10 % 3")
	assert(toks[2].type == "Op") -- %

	-- String concatenation
	toks = tokenize("a .. b")
	assert(toks[2].type == "Punct") -- ..

	-- Multiple concatenation
	toks = tokenize("a .. b .. c")
	assert(toks[2].type == "Punct") -- ..
	assert(toks[4].type == "Punct") -- ..

	-- Boolean literals
	assertTokenType("true", "Keyword")
	assertTokenType("false", "Keyword")
	assertTokenType("nil", "Keyword")

	-- Logical operators
	toks = tokenize("a and b or c")
	assert(toks[2].type == "Keyword") -- and
	assert(toks[4].type == "Keyword") -- or

	toks = tokenize("not x")
	assert(toks[1].type == "Keyword") -- not

	-- Comparison operators
	toks = tokenize("a == b")
	assert(toks[2].type == "Op") -- ==

	toks = tokenize("a ~= b")
	assert(toks[2].type == "Op") -- ~=

	toks = tokenize("a < b")
	assert(toks[2].type == "Op") -- <

	toks = tokenize("a > b")
	assert(toks[2].type == "Op") -- >

	toks = tokenize("a <= b")
	assert(toks[2].type == "Op") -- <=

	toks = tokenize("a >= b")
	assert(toks[2].type == "Op") -- >=

	-- Assignment
	toks = tokenize("x = 1")
	assert(toks[2].type == "Op") -- =

	-- Multiple assignment
	toks = tokenize("x, y = 1, 2")
	assert(toks[2].type == "Punct") -- ,
	assert(toks[4].type == "Op") -- =
	assert(toks[6].type == "Punct") -- ,

	-- Local function
	toks = tokenize("local function foo() end")
	assert(toks[1].type == "Keyword") -- local
	assert(toks[2].type == "Keyword") -- function

	-- Anonymous function
	toks = tokenize("function() end")
	assert(toks[1].type == "Keyword") -- function
	assert(toks[2].type == "Punct") -- (

	-- Return statement
	toks = tokenize("return 1, 2, 3")
	assert(toks[1].type == "Keyword") -- return
	assert(toks[3].type == "Punct") -- ,
	assert(toks[5].type == "Punct") -- ,

	-- Return without values
	toks = tokenize("return")
	assert(toks[1].type == "Keyword") -- return

	-- Break statement
	toks = tokenize("break")
	assert(toks[1].type == "Keyword") -- break

	-- Do block
	toks = tokenize("do x = 1 end")
	assert(toks[1].type == "Keyword") -- do
	assert(toks[5].type == "Keyword") -- end

	-- ===== Error handling =====
	print("Testing error handling...")
	-- Unterminated string
	toks = tokenize([["unterminated]])
	assert(toks[1].type == "Error")

	-- Unterminated long string
	toks = tokenize("[[unterminated")
	assert(toks[1].type == "Error")

	-- Unterminated comment
	toks = tokenize("--[[unterminated", { includeComments = true })
	assert(toks[1].type == "Error")

	-- Unterminated C comment
	toks = tokenize("/* unterminated", { includeComments = true, enableCComments = true })
	assert(toks[1].type == "Error")

	-- Unterminated escape
	toks = tokenize([["\"]])
	assert(toks[1].type == "Error")

	-- Disabled feature errors
	toks = tokenize("a << b", { luaVersion = "5.2" })
	assert(toks[2].type == "Error")

	toks = tokenize("a && b", { enableCOps = false })
	assert(toks[2].type == "Error")

	toks = tokenize("a ! b", { enableCOps = false })
	assert(toks[2].type == "Error")

	toks = tokenize("a != b", { enableCOps = false })
	assert(toks[2].type == "Error")

	-- ===== Position tracking =====
	print("Testing position tracking...")
	lex = Lexer.new("x = 1")
	tok = lex:nextToken()
	assert(tok.line == 1)
	assert(tok.col == 1)
	assert(tok.i == 1)
	assert(tok.j == 1)

	tok = lex:nextToken()
	assert(tok.line == 1)
	assert(tok.col == 3)
	assert(tok.i == 3)
	assert(tok.j == 3)

	-- Multi-line position tracking
	lex = Lexer.new("x\n=\n1")
	tok = lex:nextToken()
	assert(tok.line == 1)
	assert(tok.col == 1)

	tok = lex:nextToken()
	assert(tok.line == 2)
	assert(tok.col == 1)

	tok = lex:nextToken()
	assert(tok.line == 3)
	assert(tok.col == 1)

	-- ===== Token ranges (line, col, i, j, line2, col2) =====
	print("Testing token ranges...")

	-- Simple identifier
	local tok3 = firstToken("abc")
	assert(tok3.i == 1)
	assert(tok3.j == 3)
	assert(tok3.line == 1)
	assert(tok3.col == 1)
	assert(tok3.line2 == 1)
	assert(tok3.col2 == 3)

	-- Identifier at offset
	lex = Lexer.new("  abc")
	tok = lex:nextToken()
	assert(tok.i == 3)
	assert(tok.j == 5)
	assert(tok.line == 1)
	assert(tok.col == 3)
	assert(tok.line2 == 1)
	assert(tok.col2 == 5)

	-- CRLF across lines
	lex = Lexer.new("ab\r\ncd", { includeWhitespace = true })
	tok = lex:nextToken() -- ab
	assert(tok.type == "Identifier")
	assert(tok.i == 1)
	assert(tok.j == 2)
	assert(tok.line == 1)
	assert(tok.col == 1)
	assert(tok.line2 == 1)
	assert(tok.col2 == 2)
	tok = lex:nextToken() -- \r\n
	assert(tok.type == "Newline")
	assert(tok.i == 3)
	assert(tok.j == 4)
	assert(tok.line == 1)
	assert(tok.col == 3)
	assert(tok.line2 == 1)
	assert(tok.col2 == 4)
	tok = lex:nextToken() -- cd
	assert(tok.type == "Identifier")
	assert(tok.i == 5)
	assert(tok.j == 6)
	assert(tok.line == 2)
	assert(tok.col == 1)
	assert(tok.line2 == 2)
	assert(tok.col2 == 2)

	-- Long string range
	tok = firstToken("[[hello world]]")
	assert(tok.type == "LongString")
	assert(tok.i == 1)
	assert(tok.j == 15)
	assert(tok.line == 1)
	assert(tok.col == 1)
	assert(tok.line2 == 1)
	assert(tok.col2 == 15)

	-- Long comment range
	lex = Lexer.new("--[[comment]]", { includeComments = true })
	tok = lex:nextToken()
	assert(tok.type == "Comment")
	assert(tok.i == 1)
	assert(tok.j == 13)
	assert(tok.line == 1)
	assert(tok.col == 1)
	assert(tok.line2 == 1)
	assert(tok.col2 == 13)

	-- Number range
	tok = firstToken("42")
	assert(tok.type == "Number")
	assert(tok.i == 1)
	assert(tok.j == 2)
	assert(tok.line == 1)
	assert(tok.col == 1)
	assert(tok.line2 == 1)
	assert(tok.col2 == 2)

	-- Multi-line long string
	lex = Lexer.new("[[\nhello\n]]")
	tok = lex:nextToken()
	assert(tok.type == "LongString")
	assert(tok.i == 1)
	assert(tok.j == 11)
	assert(tok.line == 1)
	assert(tok.col == 1)
	assert(tok.line2 == 3)
	assert(tok.col2 == 2)

	-- Shebang range
	lex = Lexer.new("#!/usr/bin/env lua\nx = 1", { includeComments = true })
	tok = lex:nextToken()
	assert(tok.type == "Comment")
	assert(tok.subtype == "Shebang")
	assert(tok.i == 1)
	assert(tok.j == 18)
	assert(tok.line == 1)
	assert(tok.col == 1)
	assert(tok.line2 == 1)
	assert(tok.col2 == 18)

	-- BOM skipped, first real token at correct position
	lex = Lexer.new("\xEF\xBB\xBFx")
	tok = lex:nextToken()
	assert(tok.type == "Identifier")
	assert(tok.value == "x")
	assert(tok.i == 4)
	assert(tok.j == 4)
	assert(tok.line == 1)
	assert(tok.col == 1)

	-- ===== Number + identifier (patch 2) =====
	print("Testing number followed by identifier...")
	-- 123abc should be an error
	toks = tokenize("123abc")
	assert(toks[1].type == "Error")
	assert(toks[1].errorKind == "InvalidNumber")

	-- 0xFFbar should be an error
	toks = tokenize("0xFFbar")
	assert(toks[1].type == "Error")
	assert(toks[1].errorKind == "InvalidNumber")

	-- 1e2abc should be an error
	toks = tokenize("1e2abc")
	assert(toks[1].type == "Error")
	assert(toks[1].errorKind == "InvalidNumber")

	-- 123.. should still work (number then ..)
	toks = tokenize("123..")
	assert(toks[1].type == "Number")
	assert(toks[1].value == "123")

	-- 123+ should still work (number then +)
	toks = tokenize("123+")
	assert(toks[1].type == "Number")
	assert(toks[1].value == "123")

	-- valid numbers should still work
	assertTokenType("123", "Number")
	assertTokenType("0xFF", "Number")
	assertTokenType("1e2", "Number")
	assertTokenType("1.5e10", "Number")

	-- ===== tokensIncludingEOF (patch 4) =====
	print("Testing tokensIncludingEOF...")
	lex = Lexer.new("a b")
	local eofToks = {}
	for tk in lex:tokensIncludingEOF() do
		eofToks[#eofToks + 1] = tk
	end
	assert(#eofToks == 3) -- a, b, EOF
	assert(eofToks[3].type == "EOF")

	-- empty input should yield just EOF
	lex = Lexer.new("")
	eofToks = {}
	for tk in lex:tokensIncludingEOF() do
		eofToks[#eofToks + 1] = tk
	end
	assert(#eofToks == 1)
	assert(eofToks[1].type == "EOF")

	-- ===== Canonical field on normalized C operators (patch 8) =====
	print("Testing canonical field on normalized C operators...")
	toks = tokenize("a && b", { enableCOps = true, normalizeCOps = true })
	assert(toks[2].canonical == "and")
	assert(toks[2].normalized == "and")

	toks = tokenize("a || b", { enableCOps = true, normalizeCOps = true })
	assert(toks[2].canonical == "or")
	assert(toks[2].normalized == "or")

	toks = tokenize("a ! b", { enableCOps = true, normalizeCOps = true })
	assert(toks[2].canonical == "not")
	assert(toks[2].normalized == "not")

	toks = tokenize("a != b", { enableCOps = true, normalizeCOps = true })
	assert(toks[2].canonical == "~=")
	assert(toks[2].normalized == "~=")

	-- canonical should not exist when normalizeCOps is off
	toks = tokenize("a && b", { enableCOps = true, normalizeCOps = false })
	assert(toks[2].canonical == nil)
	assert(toks[2].normalized == nil)

	-- ===== Invalid number + identifier combinations (comprehensive) =====
	print("Testing invalid number+identifier combinations...")
	-- Basic: number directly followed by alpha
	toks = tokenize("123abc")
	assert(toks[1].type == "Error")
	assert(toks[1].errorKind == "InvalidNumber")
	assert(toks[1].i == 1)
	assert(toks[1].j == 3)

	-- Single digit + identifier
	toks = tokenize("1abc")
	assert(toks[1].type == "Error")
	assert(toks[1].errorKind == "InvalidNumber")
	assert(toks[1].i == 1)
	assert(toks[1].j == 1)

	-- Hex number + identifier (hex chars a-f overlap with identifier chars)
	toks = tokenize("0xFFbar")
	assert(toks[1].type == "Error")
	assert(toks[1].errorKind == "InvalidNumber")
	assert(toks[1].i == 1)
	assert(toks[1].j == 6)
	assert(toks[1].value == "0xFFba")

	-- Scientific notation + identifier
	toks = tokenize("1e2abc")
	assert(toks[1].type == "Error")
	assert(toks[1].errorKind == "InvalidNumber")
	assert(toks[1].i == 1)
	assert(toks[1].j == 3)
	assert(toks[1].value == "1e2")

	-- Decimal + identifier
	toks = tokenize("3.14foo")
	assert(toks[1].type == "Error")
	assert(toks[1].errorKind == "InvalidNumber")
	assert(toks[1].i == 1)
	assert(toks[1].j == 4)
	assert(toks[1].value == "3.14")

	-- Hex float + identifier
	toks = tokenize("0x1p0bar")
	assert(toks[1].type == "Error")
	assert(toks[1].errorKind == "InvalidNumber")
	assert(toks[1].i == 1)
	assert(toks[1].j == 5)
	assert(toks[1].value == "0x1p0")

	-- Number + underscore (underscore starts identifier)
	toks = tokenize("123_abc")
	assert(toks[1].type == "Error")
	assert(toks[1].errorKind == "InvalidNumber")
	assert(toks[1].i == 1)
	assert(toks[1].j == 3)

	-- Number + double underscore
	toks = tokenize("123__end")
	assert(toks[1].type == "Error")
	assert(toks[1].errorKind == "InvalidNumber")
	assert(toks[1].i == 1)
	assert(toks[1].j == 3)

	-- Scientific notation with sign + identifier
	toks = tokenize("1e-2abc")
	assert(toks[1].type == "Error")
	assert(toks[1].errorKind == "InvalidNumber")
	assert(toks[1].i == 1)
	assert(toks[1].j == 4)

	-- Uppercase E + identifier
	toks = tokenize("1E10xyz")
	assert(toks[1].type == "Error")
	assert(toks[1].errorKind == "InvalidNumber")
	assert(toks[1].i == 1)
	assert(toks[1].j == 4)

	-- Hex uppercase X + identifier (hex chars a-f overlap)
	toks = tokenize("0XFFbar")
	assert(toks[1].type == "Error")
	assert(toks[1].errorKind == "InvalidNumber")
	assert(toks[1].i == 1)
	assert(toks[1].j == 6)
	assert(toks[1].value == "0XFFba")

	-- Decimal float + identifier
	toks = tokenize("1.0e10abc")
	assert(toks[1].type == "Error")
	assert(toks[1].errorKind == "InvalidNumber")
	assert(toks[1].i == 1)
	assert(toks[1].j == 6)

	-- After invalid number+identifier, next token should be the identifier part
	toks = tokenize("123abc")
	assert(#toks == 2) -- Error for "123", Identifier for "abc"
	assert(toks[1].type == "Error")
	assert(toks[1].errorKind == "InvalidNumber")
	assert(toks[2].type == "Identifier")
	assert(toks[2].value == "abc")

	toks = tokenize("0xFFbar")
	assert(#toks == 2)
	assert(toks[1].type == "Error")
	assert(toks[2].type == "Identifier")
	assert(toks[2].value == "r")

	-- Valid numbers should NOT be errors
	assertTokenType("123", "Number")
	assertTokenType("0xFF", "Number")
	assertTokenType("1e2", "Number")
	assertTokenType("1.5e10", "Number")
	assertTokenType("3.14", "Number")
	assertTokenType("0x1p10", "Number")

	-- Number followed by operator (valid: two separate tokens)
	toks = tokenize("123..")
	assert(toks[1].type == "Number")
	assert(toks[1].value == "123")
	assert(toks[2].type == "Punct")

	toks = tokenize("123+")
	assert(toks[1].type == "Number")
	assert(toks[1].value == "123")
	assert(toks[2].type == "Op")

	toks = tokenize("123[")
	assert(toks[1].type == "Number")
	assert(toks[1].value == "123")
	assert(toks[2].type == "Punct")

	toks = tokenize("123(")
	assert(toks[1].type == "Number")
	assert(toks[1].value == "123")
	assert(toks[2].type == "Punct")

	-- Number followed by dot-punct (valid: 123 .. 456)
	toks = tokenize("123..456")
	assert(toks[1].type == "Number")
	assert(toks[1].value == "123")
	assert(toks[2].type == "Punct")
	assert(toks[2].value == "..")
	assert(toks[3].type == "Number")
	assert(toks[3].value == "456")

	-- ===== goto / label / continue (comprehensive) =====
	print("Testing goto/label/continue...")

	-- goto is keyword in 5.2+
	assertTokenType("goto", "Keyword", { luaVersion = "5.2" })
	assertTokenType("goto", "Keyword", { luaVersion = "5.3" })
	assertTokenType("goto", "Keyword", { luaVersion = "5.4" })

	-- goto is identifier in 5.1
	assertTokenType("goto", "Identifier", { luaVersion = "5.1" })

	-- goto can be explicitly disabled even in 5.2
	assertTokenType("goto", "Identifier", { luaVersion = "5.2", enableGoto = false })

	-- goto can be explicitly enabled in 5.1
	assertTokenType("goto", "Keyword", { luaVersion = "5.1", enableGoto = true })

	-- goto label statement
	toks = tokenize("goto label", { luaVersion = "5.2" })
	assert(toks[1].type == "Keyword")
	assert(toks[1].value == "goto")
	assert(toks[2].type == "Identifier")
	assert(toks[2].value == "label")

	-- goto with underscore label
	toks = tokenize("goto _start", { luaVersion = "5.2" })
	assert(toks[1].type == "Keyword")
	assert(toks[1].value == "goto")
	assert(toks[2].type == "Identifier")
	assert(toks[2].value == "_start")

	-- goto with numeric-start label (should be identifier if valid Lua identifier)
	toks = tokenize("goto my_label_42", { luaVersion = "5.2" })
	assert(toks[1].type == "Keyword")
	assert(toks[1].value == "goto")
	assert(toks[2].type == "Identifier")
	assert(toks[2].value == "my_label_42")

	-- Label syntax: ::name::
	toks = tokenize("::label::", { luaVersion = "5.2" })
	assert(#toks == 3)
	assert(toks[1].type == "Punct")
	assert(toks[1].value == "::")
	assert(toks[2].type == "Identifier")
	assert(toks[2].value == "label")
	assert(toks[3].type == "Punct")
	assert(toks[3].value == "::")

	-- Label with underscore
	toks = tokenize("::_inner::", { luaVersion = "5.2" })
	assert(#toks == 3)
	assert(toks[1].type == "Punct")
	assert(toks[2].type == "Identifier")
	assert(toks[2].value == "_inner")
	assert(toks[3].type == "Punct")

	-- Label with alphanumeric name
	toks = tokenize("::loop2::", { luaVersion = "5.2" })
	assert(#toks == 3)
	assert(toks[2].type == "Identifier")
	assert(toks[2].value == "loop2")

	-- Multiple labels
	toks = tokenize("::a:: ::b::", { luaVersion = "5.2" })
	assert(#toks == 6) -- :: a :: :: b ::
	assert(toks[1].value == "::")
	assert(toks[2].value == "a")
	assert(toks[3].value == "::")
	assert(toks[4].value == "::")
	assert(toks[5].value == "b")
	assert(toks[6].value == "::")

	-- goto + label in a loop
	toks = tokenize("while true do goto skip end ::skip::", { luaVersion = "5.2" })
	assert(toks[1].type == "Keyword") -- while
	assert(toks[4].type == "Keyword") -- goto
	assert(toks[5].type == "Identifier") -- skip
	assert(toks[6].type == "Keyword") -- end
	assert(toks[7].type == "Punct")   -- ::
	assert(toks[8].type == "Identifier") -- skip
	assert(toks[9].type == "Punct")   -- ::

	-- continue is not a keyword by default
	assertTokenType("continue", "Identifier")
	assertTokenType("continue", "Identifier", { luaVersion = "5.1" })
	assertTokenType("continue", "Identifier", { luaVersion = "5.2" })
	assertTokenType("continue", "Identifier", { luaVersion = "5.4" })

	-- continue enabled explicitly
	assertTokenType("continue", "Keyword", { enableContinue = true })
	assertTokenValue("continue", "continue", { enableContinue = true })

	-- continue disabled explicitly (even if somehow enabled)
	assertTokenType("continue", "Identifier", { enableContinue = false })
	assertTokenType("continue", "Identifier", { enableContinue = true, enableContinue = false })

	-- continue in a loop context
	toks = tokenize("for i = 1, 10 do continue end", { enableContinue = true })
	assert(toks[1].type == "Keyword") -- for
	assert(toks[8].type == "Keyword") -- continue
	assert(toks[9].type == "Keyword") -- end

	toks = tokenize("while true do continue end", { enableContinue = true })
	assert(toks[1].type == "Keyword") -- while
	assert(toks[4].type == "Keyword") -- continue
	assert(toks[5].type == "Keyword") -- end

	toks = tokenize("repeat continue until false", { enableContinue = true })
	assert(toks[1].type == "Keyword") -- repeat
	assert(toks[2].type == "Keyword") -- continue
	assert(toks[3].type == "Keyword") -- until

	-- continue as identifier when disabled (can be used as variable name)
	toks = tokenize("continue = 1")
	assert(toks[1].type == "Identifier")
	assert(toks[1].value == "continue")
	assert(toks[2].type == "Op") -- =
	assert(toks[3].type == "Number")

	-- goto as identifier when disabled in 5.1
	toks = tokenize("goto = 1", { luaVersion = "5.1" })
	assert(toks[1].type == "Identifier")
	assert(toks[1].value == "goto")
	assert(toks[2].type == "Op")
	assert(toks[3].type == "Number")

	-- Labels work regardless of goto being enabled (labels are always punct)
	toks = tokenize("::label::", { luaVersion = "5.1" })
	assert(toks[1].type == "Punct")
	assert(toks[2].type == "Identifier")
	assert(toks[3].type == "Punct")

	toks = tokenize("::label::", { luaVersion = "5.2", enableGoto = false })
	assert(toks[1].type == "Punct")
	assert(toks[2].type == "Identifier")
	assert(toks[3].type == "Punct")

	-- Label position tracking
	lex = Lexer.new("::mylabel::", { luaVersion = "5.2" })
	tok = lex:nextToken() -- ::
	assert(tok.type == "Punct")
	assert(tok.i == 1)
	assert(tok.j == 2)
	assert(tok.line == 1)
	assert(tok.col == 1)
	tok = lex:nextToken() -- mylabel
	assert(tok.type == "Identifier")
	assert(tok.value == "mylabel")
	assert(tok.i == 3)
	assert(tok.j == 9)
	assert(tok.col == 3)
	assert(tok.col2 == 9)
	tok = lex:nextToken() -- ::
	assert(tok.type == "Punct")
	assert(tok.i == 10)
	assert(tok.j == 11)
	assert(tok.col == 10)

	-- goto position tracking
	lex = Lexer.new("goto target", { luaVersion = "5.2" })
	tok = lex:nextToken() -- goto
	assert(tok.type == "Keyword")
	assert(tok.value == "goto")
	assert(tok.i == 1)
	assert(tok.j == 4)
	assert(tok.col == 1)
	assert(tok.col2 == 4)
	tok = lex:nextToken() -- target
	assert(tok.type == "Identifier")
	assert(tok.value == "target")
	assert(tok.i == 6)
	assert(tok.j == 11)
	assert(tok.col == 6)
	assert(tok.col2 == 11)

	-- ===== Token IDs (#12) =====
	print("Testing token IDs...")
	assert(Lexer.TOKEN.EOF == 0)
	assert(Lexer.TOKEN.Identifier == 1)
	assert(Lexer.TOKEN.Keyword == 2)
	assert(Lexer.TOKEN.Number == 3)
	assert(Lexer.TOKEN.String == 4)
	assert(Lexer.TOKEN.LongString == 5)
	assert(Lexer.TOKEN.Op == 6)
	assert(Lexer.TOKEN.Punct == 7)
	assert(Lexer.TOKEN.Comment == 8)
	assert(Lexer.TOKEN.Whitespace == 9)
	assert(Lexer.TOKEN.Newline == 10)
	assert(Lexer.TOKEN.Error == 11)
	assert(Lexer.TOKEN.InvalidEscape == 12)

	tok = firstToken("foo")
	assert(tok.id == Lexer.TOKEN.Identifier)

	tok = firstToken("if")
	assert(tok.id == Lexer.TOKEN.Keyword)

	tok = firstToken("42")
	assert(tok.id == Lexer.TOKEN.Number)

	tok = firstToken([["hello"]])
	assert(tok.id == Lexer.TOKEN.String)

	tok = firstToken("+")
	assert(tok.id == Lexer.TOKEN.Op)

	tok = firstToken("(")
	assert(tok.id == Lexer.TOKEN.Punct)

	lex = Lexer.new("")
	tok = lex:nextToken()
	assert(tok.id == Lexer.TOKEN.EOF)

	-- ===== Numbers immediately before dots =====
	print("Testing numbers before dots...")
	-- 1. should lex as number (1.) - Lua accepts trailing dot
	tok = firstToken("1.")
	assert(tok.type == "Number")
	assert(tok.value == "1.")

	-- 1.e2 should lex as number
	tok = firstToken("1.e2")
	assert(tok.type == "Number")
	assert(tok.value == "1.e2")

	-- 1..2 should lex as number then .. then number
	toks = tokenize("1..2")
	assert(toks[1].type == "Number")
	assert(toks[1].value == "1")
	assert(toks[2].type == "Punct")
	assert(toks[2].value == "..")
	assert(toks[3].type == "Number")
	assert(toks[3].value == "2")

	-- 1...2 should lex as number then ... then number
	toks = tokenize("1...2")
	assert(toks[1].type == "Number")
	assert(toks[1].value == "1")
	assert(toks[2].type == "Punct")
	assert(toks[2].value == "...")
	assert(toks[3].type == "Number")
	assert(toks[3].value == "2")

	-- 0x1. should lex as hex number
	tok = firstToken("0x1.")
	assert(tok.type == "Number")
	assert(tok.value == "0x1.")

	-- 0x1.. should lex as hex number then ..
	toks = tokenize("0x1..")
	assert(toks[1].type == "Number")
	assert(toks[1].value == "0x1")
	assert(toks[2].type == "Punct")
	assert(toks[2].value == "..")

	-- 0x1... should lex as hex number then ...
	toks = tokenize("0x1...")
	assert(toks[1].type == "Number")
	assert(toks[1].value == "0x1")
	assert(toks[2].type == "Punct")
	assert(toks[2].value == "...")

	-- ===== Every legal hexadecimal float =====
	print("Testing hexadecimal floats...")
	local hexFloats = {
		"0x1.p0",
		"0x1.fp10",
		"0x.8p4",
		"0x0.0p0",
		"0x10p-4",
	}
	for _, num in ipairs(hexFloats) do
		assertTokenType(num, "Number")
		assertTokenValue(num, num)
	end

	-- ===== Invalid hexadecimal =====
	print("Testing invalid hexadecimal...")
	local invalidHex = {
		"0xp1",
		"0x.p1",
		"0x1p+",
		"0x1p-",
		"0x1p",
	}
	for _, num in ipairs(invalidHex) do
		assertTokenType(num, "Error")
	end

	-- ===== Non-ASCII error grouping (#14) =====
	print("Testing non-ASCII error grouping...")
	-- Single non-ASCII byte should be one Error
	tok = firstToken("\xC3")
	assert(tok.type == "Error")
	assert(tok.value == "\xC3")
	assert(tok.errorKind == "InvalidCharacter")

	-- Multiple consecutive non-ASCII bytes should be one Error
	tok = firstToken("\xC3\xA9")
	assert(tok.type == "Error")
	assert(tok.value == "\xC3\xA9")
	assert(tok.errorKind == "InvalidCharacter")

	-- Multi-byte UTF-8 sequence (e) should be one Error
	tok = firstToken("\xC3\xA9")
	assert(tok.type == "Error")
	assert(tok.value == "\xC3\xA9")

	-- CJK characters (e.g. ni hao) should group into one Error
	tok = firstToken("\xE4\xBD\xA0\xE5\xA5\xBD")
	assert(tok.type == "Error")
	assert(tok.value == "\xE4\xBD\xA0\xE5\xA5\xBD")

	-- Non-ASCII followed by ASCII should only group non-ASCII
	toks = tokenize("\xC3\xA9x")
	assert(#toks == 2)
	assert(toks[1].type == "Error")
	assert(toks[1].value == "\xC3\xA9")
	assert(toks[2].type == "Identifier")
	assert(toks[2].value == "x")

	-- ===== UTF-8 identifiers (#2) =====
	print("Testing UTF-8 identifiers...")
	-- With allowNonAsciiIdentifiers=true, valid UTF-8 identifiers work
	tok = firstToken("\xCF\x80", { allowNonAsciiIdentifiers = true }) -- pi
	assert(tok.type == "Identifier")
	assert(tok.value == "\xCF\x80")

	tok = firstToken("\xCE\xB1\xCE\xB2\xCE\xB3", { allowNonAsciiIdentifiers = true }) -- alpha beta gamma
	assert(tok.type == "Identifier")
	assert(tok.value == "\xCE\xB1\xCE\xB2\xCE\xB3")

	-- allowUtf8Identifiers still works as deprecated alias
	tok = firstToken("\xCF\x80", { allowUtf8Identifiers = true })
	assert(tok.type == "Identifier")
	assert(tok.value == "\xCF\x80")

	-- Without the flag, non-ASCII bytes are Error tokens
	tok = firstToken("\xCF\x80")
	assert(tok.type == "Error")

	-- ===== Long bracket levels =====
	print("Testing long bracket levels...")
	local longBracketLevels = {
		{ open = "[[",    close = "]]" },
		{ open = "[=[",   close = "]=]" },
		{ open = "[==[",  close = "]==]" },
		{ open = "[===[", close = "]===]" },
	}
	for _, lb in ipairs(longBracketLevels) do
		local src = lb.open .. "content" .. lb.close
		tok = firstToken(src)
		assert(tok.type == "LongString", string.format("Expected LongString for '%s'", src))
		assert(tok.value == src, string.format("Expected value '%s', got '%s'", src, tok.value))
	end

	-- Nested long brackets
	tok = firstToken("[=[ nested [[ ]] nested ]=]")
	assert(tok.type == "LongString")
	assert(tok.value == "[=[ nested [[ ]] nested ]=]")

	-- Empty long brackets at every level
	local emptyLongBrackets = {
		{ open = "[[",    close = "]]" },
		{ open = "[=[",   close = "]=]" },
		{ open = "[==[",  close = "]==]" },
		{ open = "[===[", close = "]===]" },
	}
	for _, lb in ipairs(emptyLongBrackets) do
		local src = lb.open .. lb.close
		tok = firstToken(src)
		assert(tok.type == "LongString", string.format("Expected LongString for '%s'", src))
		assert(tok.value == src, string.format("Expected value '%s', got '%s'", src, tok.value))
	end

	-- Long comment with empty content
	lex = Lexer.new("--[[\n]]", { includeComments = true })
	tok = lex:nextToken()
	assert(tok.type == "Comment")
	assert(tok.value == "--[[\n]]")

	-- ===== Escaped CR sequences =====
	print("Testing escaped CR sequences...")
	-- \\\n (backslash + newline)
	assertTokenType([["\\\n"]], "String")

	-- \\\r (backslash + CR)
	assertTokenType([["\\\r"]], "String")

	-- \\\r\n (backslash + CRLF)
	assertTokenType([["\\\r\n"]], "String")

	-- ===== Invalid escape sequences (#10) =====
	print("Testing invalid escape sequences...")
	tok = firstToken([["\q"]])
	assert(tok.type == "InvalidEscape")
	assert(tok.errorKind == "InvalidEscape")
	assert(tok.value == '"\\q')

	tok = firstToken([["\j"]])
	assert(tok.type == "InvalidEscape")

	tok = firstToken([["\M"]])
	assert(tok.type == "InvalidEscape")

	-- Valid escapes should still be strings
	assertTokenType([["\a"]], "String")
	assertTokenType([["\b"]], "String")
	assertTokenType([["\f"]], "String")
	assertTokenType([["\n"]], "String")
	assertTokenType([["\r"]], "String")
	assertTokenType([["\t"]], "String")
	assertTokenType([["\v"]], "String")
	assertTokenType([["\\"]], "String")
	assertTokenType([["\""]], "String")
	assertTokenType([["\'"]], "String")

	-- Hex escape (Lua 5.2+)
	assertTokenType([["\x41"]], "String", { luaVersion = "5.2" })
	assertTokenType([["\x4F"]], "String", { luaVersion = "5.3" })

	-- Decimal escape
	assertTokenType([["\65"]], "String")
	assertTokenType([["\10"]], "String")

	-- Empty long bracket comment produces empty comment
	lex = Lexer.new("--[[\n]]", { includeComments = true })
	tok = lex:nextToken()
	assert(tok.type == "Comment")
	assert(tok.value == "--[[\n]]")

	-- ===== peekToken / pushBack API (#11) =====
	print("Testing peekToken and pushBack...")
	lex = Lexer.new("a b c")

	-- peekToken returns next without consuming
	tok = lex:peekToken()
	assert(tok.type == "Identifier")
	assert(tok.value == "a")
	-- nextToken returns same token
	tok = lex:nextToken()
	assert(tok.type == "Identifier")
	assert(tok.value == "a")
	-- now next advances
	tok = lex:nextToken()
	assert(tok.type == "Identifier")
	assert(tok.value == "b")

	-- pushBack pushes a token back
	lex:pushBack(tok)
	tok = lex:nextToken()
	assert(tok.type == "Identifier")
	assert(tok.value == "b")
	-- after pushback consumed, next advances normally
	tok = lex:nextToken()
	assert(tok.type == "Identifier")
	assert(tok.value == "c")

	-- ===== save / restore API (#11) =====
	print("Testing save and restore...")
	lex = Lexer.new("a b c")
	lex:nextToken() -- consume 'a'
	local state = lex:save()
	lex:nextToken() -- consume 'b'
	lex:nextToken() -- consume 'c'
	-- Restore to state after 'a'
	lex:restore(state)
	tok = lex:nextToken()
	assert(tok.type == "Identifier")
	assert(tok.value == "b")

	-- ===== clone API (#11) =====
	print("Testing clone...")
	lex = Lexer.new("x y z")
	lex:nextToken() -- consume 'x'
	local copy = lex:clone()
	-- Both should produce same remaining tokens
	tok = lex:nextToken()
	local copyTok = copy:nextToken()
	assert(tok.type == copyTok.type)
	assert(tok.value == copyTok.value)
	-- Modifying clone doesn't affect original
	local lexTok = lex:nextToken()
	copyTok = copy:nextToken()
	assert(lexTok.value == "z")
	assert(copyTok.value == "z")

	-- ===== Canonical field on all operators when normalizeCOps=true (#7) =====
	print("Testing canonical on all operators...")
	-- Standard operators get canonical = themselves when normalizeCOps=true
	toks = tokenize("a + b", { normalizeCOps = true })
	assert(toks[2].canonical == "+")

	toks = tokenize("a * b", { normalizeCOps = true })
	assert(toks[2].canonical == "*")

	toks = tokenize("a == b", { normalizeCOps = true })
	assert(toks[2].canonical == "==")

	toks = tokenize("a ~= b", { normalizeCOps = true })
	assert(toks[2].canonical == "~=")

	toks = tokenize("a < b", { normalizeCOps = true })
	assert(toks[2].canonical == "<")

	toks = tokenize("a <= b", { normalizeCOps = true })
	assert(toks[2].canonical == "<=")

	-- Without normalizeCOps, no canonical field
	toks = tokenize("a + b")
	assert(toks[2].canonical == nil)

	-- ===== EOF behavior documentation (#6) =====
	print("Testing EOF persistence...")
	lex = Lexer.new("x")
	lex:nextToken()    -- x
	tok = lex:nextToken() -- first EOF
	assert(tok.type == "EOF")
	tok = lex:nextToken() -- second EOF
	assert(tok.type == "EOF")
	tok = lex:nextToken() -- third EOF
	assert(tok.type == "EOF")
	-- Value is always empty for EOF
	assert(tok.value == "")

	-- peekToken at EOF returns EOF
	lex = Lexer.new("a")
	lex:nextToken() -- a
	lex:nextToken() -- EOF
	tok = lex:peekToken()
	assert(tok.type == "EOF")
	tok = lex:nextToken()
	assert(tok.type == "EOF")

	print("All tests passed!")
end
