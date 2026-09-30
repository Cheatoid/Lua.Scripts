-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Simple Lua scanner/lexer/tokenizer for:
-- * Lua 5.1, 5.2, 5.3, 5.4
-- * Garry's Mod Lua (LuaJIT-based) extensions via feature switches
--
-- This module tokenizes source text into a stream of tokens with ranges.
-- It is a lexer (scanner/lexer/tokenizer), not a full AST parser.
--
-- Public API:
--   local Lexer = require('lua_lexer')
--   local lex = Lexer.new(source, { luaVersion = "5.4" })
--   for tok in lex:tokens() do print(tok.type, tok.value) end
--
-- Tokens:
--   tok = {
--     type  = string, -- e.g. 'Identifier','Keyword','Number','String','LongString','Op','Punct','Comment','Whitespace','Newline','EOF','Error','InvalidEscape'
--     id    = number, -- integer token type ID (see Lexer.TOKEN)
--     value = string, -- raw lexeme
--     line  = number, -- 1-based start line
--     col   = number, -- 1-based start column
--     i     = number, -- 1-based start index (byte offset)
--     j     = number, -- 1-based end index (inclusive)
--     line2 = number, -- 1-based end line
--     col2  = number, -- 1-based end column
--   }
--
-- Token type IDs (Lexer.TOKEN):
--   EOF=0, Identifier=1, Keyword=2, Number=3, String=4, LongString=5,
--   Op=6, Punct=7, Comment=8, Whitespace=9, Newline=10, Error=11, InvalidEscape=12
--
-- Options (defaults inferred from luaVersion):
-- - luaVersion: "5.1"|"5.2"|"5.3"|"5.4" (default: "5.1")
-- - includeComments: boolean (default: false)
-- - includeWhitespace: boolean (default: false)
-- - normalizeCOps: boolean (default: false) -- map &&,||,! and != to Lua equivalents (and/or/not/~=)
-- - enableGoto: boolean (default: luaVersion >= 5.2)
-- - enableContinue: boolean (default: false) -- GMod extension
-- - enableBitwiseOps: boolean (default: luaVersion >= 5.3) -- &,|,~,<<,>>
-- - enableFloorDiv: boolean (default: luaVersion >= 5.3) -- //
-- - enableCComments: boolean (default: false) -- // and /* */
-- - slashSlashMeansComment?: boolean -- if nil, defaults to (enableCComments and not enableFloorDiv)
-- - enableCOps: boolean (default: false) -- !=, &&, ||, !
-- - allowNonAsciiIdentifiers: boolean (default: false) -- non-ASCII bytes as identifier letters (validates UTF-8)
-- - allowUtf8Identifiers?: boolean -- DEPRECATED alias for allowNonAsciiIdentifiers
--
-- EOF behavior:
--   Once the source is exhausted, nextToken() returns an EOF token forever.
--   This is intentional: parsers typically need to inspect the final token,
--   and returning EOF consistently avoids nil-checks in parser loops.
--
-- Notes:
-- * Long bracket strings/comments [=[ ... ]=] fully supported.
-- * Numeric literals include decimal + hex + hex-floats.
-- * Designed to be fast, streaming, and to produce useful diagnostics.
-- * Invalid escape sequences in strings emit InvalidEscape tokens.
-- * Non-ASCII bytes are grouped into a single Error token when UTF-8 identifiers are disabled.
-- * UTF-8 sequences are validated when allowNonAsciiIdentifiers is enabled.

--- Lua lexer/tokenizer class for parsing Lua source code.<br>
--- Supports Lua 5.1-5.4 and Garry's Mod extensions.
---@class lua_lexer.LuaLexer
---@field opts lua_lexer.LuaLexerOptions Normalized configuration options
---@field s string Source text being lexed
---@field n integer Length of source text
---@field i integer Current position (1-based)
---@field line integer Current line number (1-based)
---@field col integer Current column number (1-based)
---@field _emittedEOF boolean Whether EOF token has been emitted
---@field _kw table Set of keywords for current configuration
---@field _punct table Set of punctuation tokens
---@field _vnum integer Numeric Lua version (e.g. 501, 502, 503, 504)
---@field _pushback? table Pushed-back token for peek/pushBack
local Lexer = {}
Lexer.__index = Lexer

--- Integer token type IDs for fast comparison.<br>
--- Use as: tok.id == Lexer.TOKEN.Identifier
Lexer.TOKEN = {
	EOF = 0,
	Identifier = 1,
	Keyword = 2,
	Number = 3,
	String = 4,
	LongString = 5,
	Op = 6,
	Punct = 7,
	Comment = 8,
	Whitespace = 9,
	Newline = 10,
	Error = 11,
	InvalidEscape = 12,
}

---@class lua_lexer.LuaLexerOptions
---@field luaVersion? string Lua version string: "5.1"|"5.2"|"5.3"|"5.4" (default: "5.1")
---@field includeComments? boolean Include comment tokens (default: false)
---@field includeWhitespace? boolean Include whitespace tokens (default: false)
---@field normalizeCOps? boolean Map &&,||,! and != to Lua equivalents (default: false)
---@field enableGoto? boolean Enable goto/label (default: luaVersion >= 5.2)
---@field enableContinue? boolean Enable continue keyword, GMod extension (default: false)
---@field enableBitwiseOps? boolean Enable &,|,~,<<,>> (default: luaVersion >= 5.3)
---@field enableFloorDiv? boolean Enable // floor division (default: luaVersion >= 5.3)
---@field enableCComments? boolean Enable // and /* */ comments (default: false)
---@field enableCOps? boolean Enable !=, &&, ||, ! (default: false)
---@field allowNonAsciiIdentifiers? boolean Non-ASCII bytes as identifier letters, validates UTF-8 (default: false)
---@field allowUtf8Identifiers? boolean DEPRECATED alias for allowNonAsciiIdentifiers
---@field slashSlashMeansComment? boolean If nil, defaults to enableCComments and not enableFloorDiv

-- Localized global functions for better performance
local assert = assert
local error = error
local next = next
local pairs = pairs
local setmetatable = setmetatable
local type = type
local string_byte = string.byte
local string_char = string.char
local string_find = string.find
local string_match = string.match
local string_sub = string.sub

-- Helpers

local function _assert(cond, msg)
	if not cond then
		return error(msg, 2)
	end
end

local function _optBool(v, default)
	if v == nil then
		return default
	end
	return not not v
end

local function _isDigit(b)
	return b and b >= 48 and b <= 57
end
local function _isAlpha(b)
	return b and ((b >= 65 and b <= 90) or (b >= 97 and b <= 122))
end
local function _isIdentStart(b, allowUtf8)
	if not b then return false end
	if _isAlpha(b) or b == 95 then return true end
	if allowUtf8 and b >= 0xC2 and b <= 0xF4 then return true end
	return false
end
local function _isSpaceNoNL(b)
	-- space, tab, vertical tab, form feed
	return b == 32 or b == 9 or b == 11 or b == 12
end
local function _isNewline(b)
	return b == 10 or b == 13
end

--- Returns the byte length of a UTF-8 sequence starting with byte b, or nil if b is not a valid start byte.
local function _utf8SeqLen(b)
	if b >= 0xC2 and b <= 0xDF then
		return 2
	end
	if b >= 0xE0 and b <= 0xEF then
		return 3
	end
	if b >= 0xF0 and b <= 0xF4 then
		return 4
	end
	return nil
end

--- Returns true if b is a valid UTF-8 continuation byte (0x80-0xBF).
local function _isUtf8Cont(b)
	return b >= 0x80 and b <= 0xBF
end

--- Set of valid escape character bytes for short string scanning.
local VALID_ESCAPES = {
	[97] = true, -- a
	[98] = true, -- b
	[102] = true, -- f
	[110] = true, -- n
	[114] = true, -- r
	[116] = true, -- t
	[118] = true, -- v
	[92] = true, -- backslash
	[34] = true, -- double quote
	[39] = true, -- single quote
	[91] = true, -- [
	[93] = true, -- ]
}

local function _trim(s)
	return string_match(s, "^([^%s]+)(.-)%s*$") or ""
end

local function _versionToNum(v)
	if type(v) == "string" then
		v = _trim(v)
	end

	if v == "5.1" then
		return 501
	end
	if v == "5.2" then
		return 502
	end
	if v == "5.3" then
		return 503
	end
	if v == "5.4" then
		return 504
	end

	return 501
end

local BASE_KEYWORDS = {
	["and"] = true,
	["break"] = true,
	["do"] = true,
	["else"] = true,
	["elseif"] = true,
	["end"] = true,
	["false"] = true,
	["for"] = true,
	["function"] = true,
	["if"] = true,
	["in"] = true,
	["local"] = true,
	["nil"] = true,
	["not"] = true,
	["or"] = true,
	["repeat"] = true,
	["return"] = true,
	["then"] = true,
	["true"] = true,
	["until"] = true,
	["while"] = true,
}

local function _shallowCopy(t)
	local copy = {}
	for k, v in pairs(t) do
		copy[k] = v
	end
	return copy
end

local function _makeKeywordSet(opts)
	local kw = _shallowCopy(BASE_KEYWORDS)
	if opts.enableGoto then
		kw["goto"] = true
	end
	if opts.enableContinue then
		kw["continue"] = true
	end
	return kw
end

local PUNCT = {
	["("] = true,
	[")"] = true,
	["{"] = true,
	["}"] = true,
	["["] = true,
	["]"] = true,
	[","] = true,
	[";"] = true,
	[":"] = true,
	["::"] = true,
	["."] = true,
	[".."] = true,
	["..."] = true,
}

--- Create a token object.
local function _token(t)
	t.id = Lexer.TOKEN[t.type] or -1
	return t
end

--- Creates a new Lexer instance.
---@param source string The Lua source code to tokenize.
---@param opts? lua_lexer.LuaLexerOptions Configuration options (see module documentation).
---@return lua_lexer.LuaLexer lexer New lexer instance.
function Lexer.new(source, opts)
	_assert(type(source) == "string", "Lexer.new(source, opts): source must be a string")
	opts = opts or {}

	local vnum = _versionToNum(opts.luaVersion or "5.1")

	local versionName = {
		[501] = "5.1",
		[502] = "5.2",
		[503] = "5.3",
		[504] = "5.4",
	}

	-- allowNonAsciiIdentifiers is the canonical name; allowUtf8Identifiers is a deprecated alias.
	local allowNonAscii = opts.allowNonAsciiIdentifiers
	if allowNonAscii == nil then
		allowNonAscii = opts.allowUtf8Identifiers
	end

	local normalized = {
		luaVersion = versionName[vnum],

		includeComments = _optBool(opts.includeComments, false),
		includeWhitespace = _optBool(opts.includeWhitespace, false),
		normalizeCOps = _optBool(opts.normalizeCOps, false),

		enableGoto = _optBool(opts.enableGoto, vnum >= 502),
		enableContinue = _optBool(opts.enableContinue, false),
		enableBitwiseOps = _optBool(opts.enableBitwiseOps, vnum >= 503),
		enableFloorDiv = _optBool(opts.enableFloorDiv, vnum >= 503),

		enableCComments = _optBool(opts.enableCComments, false),
		enableCOps = _optBool(opts.enableCOps, false),
		allowNonAsciiIdentifiers = _optBool(allowNonAscii, false),

		slashSlashMeansComment = opts.slashSlashMeansComment,
	}

	if normalized.slashSlashMeansComment == nil then
		normalized.slashSlashMeansComment = normalized.enableCComments and (not normalized.enableFloorDiv)
	else
		normalized.slashSlashMeansComment = not not normalized.slashSlashMeansComment
	end

	local self = setmetatable({
		opts = normalized,
		_kw = _makeKeywordSet(normalized),
		_punct = PUNCT,
		_vnum = vnum,
		--_pushback = nil,
	}, Lexer)
	self:reset(source)
	return self
end

--- Resets the lexer with new source text.
---@param source string The new Lua source code to tokenize
---@return lua_lexer.LuaLexer self Self for method chaining
function Lexer.reset(self, source)
	_assert(type(source) == "string", "Lexer:reset(source): source must be a string")
	self.s = source
	self.n = #source
	self.i = 1
	self.line = 1
	self.col = 1
	self._emittedEOF = false
	self._pushback = nil
	return self
end

-- Low-level helpers

--- Check whether the cursor has advanced past the source.
---@return boolean done True when there are no bytes left.
function Lexer._atEnd(self)
	return self.i > self.n
end

--- Read the raw byte at a given position.
---@param pos integer Position to read.
---@return integer? byte Byte value, or nil when out of range.
function Lexer._byte(self, pos)
	return string_byte(self.s, pos)
end

--- Peek at a byte a fixed offset ahead of the cursor.
---@param off? integer Offset from the current position (default: 0).
---@return integer? byte Byte value, or nil when out of range.
function Lexer._peek(self, off)
	off = off or 0
	local p = self.i + off
	if p < 1 or p > self.n then
		return nil
	end
	return string_byte(self.s, p)
end

--- Extract the source text spanning the given range.
---@param a integer First position (inclusive).
---@param b integer Last position (inclusive).
---@return string text Extracted substring.
function Lexer._slice(self, a, b)
	return string_sub(self.s, a, b)
end

--- Advances the internal cursor from current self.i to endIndex (inclusive).<br>
--- Returns endLine,endCol (position of the last consumed byte).
function Lexer._advanceTo(self, endIndex)
	if endIndex > self.n then
		endIndex = self.n
	end

	local s = self.s
	local byte = string_byte
	local p = self.i
	local line = self.line
	local col = self.col
	local lastLine, lastCol = line, col

	while p <= endIndex do
		local b = byte(s, p)

		if b == 10 then
			lastLine, lastCol = line, col
			line = line + 1
			col = 1
			p = p + 1
		elseif b == 13 then
			if p + 1 <= endIndex and byte(s, p + 1) == 10 then
				-- CRLF: the final consumed byte is LF, one column after CR.
				lastLine, lastCol = line, col + 1
				p = p + 2
			else
				lastLine, lastCol = line, col
				p = p + 1
			end

			line = line + 1
			col = 1
		else
			lastLine, lastCol = line, col
			col = col + 1
			p = p + 1
		end
	end

	self.i = endIndex + 1
	self.line = line
	self.col = col

	return lastLine, lastCol
end

--- Build a token spanning a source range and advance the cursor.<br>
--- Extra table entries are merged into the token when provided.
---@param ttype string Token type name.
---@param a integer Start position (inclusive).
---@param b integer End position (inclusive).
---@param line1 integer Start line number.
---@param col1 integer Start column number.
---@param extra? table Additional fields copied onto the token.
---@return table token Finished token.
function Lexer._makeToken(self, ttype, a, b, line1, col1, extra)
	local line2, col2 = self:_advanceTo(b)
	local tok = {
		type = ttype,
		value = self:_slice(a, b),
		line = line1,
		col = col1,
		i = a,
		j = b,
		line2 = line2,
		col2 = col2,
	}
	if extra then
		for k, v in next, extra do
			tok[k] = v
		end
	end
	return _token(tok)
end

--- Consume a newline token starting at current position.
function Lexer._scanNewline(self)
	local a = self.i
	local line1, col1 = self.line, self.col
	local b = a
	local b1 = self:_byte(a)
	if b1 == 13 and a + 1 <= self.n and self:_byte(a + 1) == 10 then
		b = a + 1
	end
	return self:_makeToken("Newline", a, b, line1, col1)
end

--- Consume run of non-newline whitespace.
function Lexer._scanWhitespace(self)
	local a = self.i
	local line1, col1 = self.line, self.col
	local p = a
	while p <= self.n do
		local b = self:_byte(p)
		if _isSpaceNoNL(b) then
			p = p + 1
		else
			break
		end
	end
	return self:_makeToken("Whitespace", a, p - 1, line1, col1)
end

--- Scan an identifier or keyword, properly handling UTF-8 multi-byte sequences.
function Lexer._scanIdentifierOrKeyword(self)
	local a = self.i
	local line1, col1 = self.line, self.col
	local allowUtf8 = self.opts.allowNonAsciiIdentifiers
	local s = self.s
	local byte = string_byte
	local n = self.n

	local p = a
	while p <= n do
		local b = byte(s, p)
		if _isAlpha(b) or _isDigit(b) or b == 95 then
			p = p + 1
		elseif allowUtf8 and b >= 0xC2 and b <= 0xF4 then
			local slen = _utf8SeqLen(b)
			if slen and p + slen - 1 <= n then
				local valid = true
				for k = 1, slen - 1 do
					if not _isUtf8Cont(byte(s, p + k)) then
						valid = false
						break
					end
				end
				if valid then
					p = p + slen
				else
					break
				end
			else
				break
			end
		else
			break
		end
	end

	local text = self:_slice(a, p - 1)
	local ttype = self._kw[text] and "Keyword" or "Identifier"
	return self:_makeToken(ttype, a, p - 1, line1, col1)
end

--- Tries to read a long bracket opener at position 'a'.<br>
--- Returns (level, openEnd) or nil.
function Lexer._tryLongBracketOpen(self, a)
	if self:_byte(a) ~= 91 then
		return nil
	end -- '['
	local p = a + 1
	while p <= self.n and self:_byte(p) == 61 do
		-- '='
		p = p + 1
	end
	if p <= self.n and self:_byte(p) == 91 then
		local level = (p - (a + 1))
		return level, p
	end
	return nil
end

--- Find the matching long bracket close without allocating a delimiter string.<br>
--- Scans manually: find ']', count '=', compare level, check ']'.<br>
--- Returns the position of the final ']' or nil.
---@param startPos integer Position to start scanning from.
---@param level integer Number of '=' in the long bracket.
---@return integer? pos Position of the final ']' or nil.
function Lexer._findLongBracketClose(self, startPos, level)
	local s = self.s
	local n = self.n
	local p = startPos

	while p <= n do
		local pos = string_find(s, "]", p, true)
		if not pos then
			return nil
		end

		local eqCount = 0
		local q = pos + 1
		while q <= n and string_byte(s, q) == 61 do -- '='
			eqCount = eqCount + 1
			q = q + 1
		end

		if eqCount == level and q <= n and string_byte(s, q) == 93 then -- ']'
			return q
		end

		p = pos + 1
	end

	return nil
end

--- Scan a long-bracket string or comment body.<br>
--- Returns an Error token when the long bracket is unterminated.
---@param kind string Token type to produce ("String" or "Comment").
---@param openPos? integer Position of the opening bracket (defaults to cursor).
---@param tokenStart? integer Position where the token begins (defaults to openPos).
---@return table? token Token, or nil when no long bracket opener follows.
function Lexer._scanLongStringOrComment(self, kind, openPos, tokenStart)
	openPos = openPos or self.i
	tokenStart = tokenStart or openPos

	local line1, col1 = self.line, self.col

	local level, openEnd = self:_tryLongBracketOpen(openPos)
	if not level then
		return nil
	end

	-- Opening delimiter ends at openEnd, the second '['.
	local contentStart = openEnd + 1

	-- Lua ignores a single first newline in long strings/comments.
	if contentStart <= self.n then
		local b = self:_byte(contentStart)

		if b == 10 then
			contentStart = contentStart + 1
		elseif b == 13 then
			if contentStart + 1 <= self.n and self:_byte(contentStart + 1) == 10 then
				contentStart = contentStart + 2
			else
				contentStart = contentStart + 1
			end
		end
	end

	local closeEnd = self:_findLongBracketClose(contentStart, level)
	if not closeEnd then
		local tok = self:_makeToken("Error", tokenStart, self.n, line1, col1, {
			message = "Unterminated long bracket " .. (kind == "Comment" and "comment" or "string"),
			errorKind = "UnterminatedLongBracket",
		})
		tok.subtype = kind
		return tok
	end

	return self:_makeToken(kind, tokenStart, closeEnd, line1, col1)
end

--- Scan a single-line comment up to (but excluding) the newline.
---@param prefixLen integer Length of the comment prefix ("--" or "//").
---@return table token Comment token.
function Lexer._scanLineComment(self, prefixLen)
	local a = self.i
	local line1, col1 = self.line, self.col
	local p = a + prefixLen
	while p <= self.n do
		local b = self:_byte(p)
		if _isNewline(b) then
			break
		end
		p = p + 1
	end
	return self:_makeToken("Comment", a, p - 1, line1, col1)
end

--- Scan a Lua comment, preferring a long bracket when '[' follows.
---@return table token Comment token.
function Lexer._scanLuaComment(self)
	local a = self.i
	local after = a + 2

	if after <= self.n and self:_byte(after) == 91 then
		local tok = self:_scanLongStringOrComment("Comment", after, a)
		if tok then
			return tok
		end
	end

	return self:_scanLineComment(2)
end

--- Scan a C-style comment when the C comments option is enabled.<br>
--- Returns nil when disabled or when the '/' is not a comment start.
---@return table? token Comment token, or nil when not a C comment.
function Lexer._scanCCommentOrOp(self)
	-- assumes current byte is '/'
	local a = self.i
	local line1, col1 = self.line, self.col
	local b2 = self:_peek(1)

	if not self.opts.enableCComments then
		return nil
	end

	if b2 == 47 and self.opts.slashSlashMeansComment then
		return self:_scanLineComment(2) -- //...
	end

	if b2 == 42 then
		-- /* block */
		local p = a + 2
		while p <= self.n - 1 do
			if self:_byte(p) == 42 and self:_byte(p + 1) == 47 then
				return self:_makeToken("Comment", a, p + 1, line1, col1)
			end
			p = p + 1
		end
		-- unterminated
		return self:_makeToken("Error", a, self.n, line1, col1, {
			message = "Unterminated C block comment",
			errorKind = "UnterminatedCComment",
		})
	end

	return nil
end

--- Scan a quoted short string with its escape sequences.<br>
--- Yields Error or InvalidEscape tokens for malformed input.
---@return table token String or error token.
function Lexer._scanShortString(self)
	local a = self.i
	local line1, col1 = self.line, self.col
	local quote = self:_byte(a)

	local p = a + 1
	while p <= self.n do
		local b = self:_byte(p)
		if b == quote then
			return self:_makeToken("String", a, p, line1, col1)
		end
		if _isNewline(b) then
			return self:_makeToken("Error", a, p - 1, line1, col1, {
				message = "Unterminated string literal",
				errorKind = "UnterminatedString",
			})
		end
		if b == 92 then
			-- backslash escape
			local nb = self:_byte(p + 1)
			if not nb then
				return self:_makeToken("Error", a, p, line1, col1, {
					message = "Unterminated string escape",
					errorKind = "UnterminatedStringEscape",
				})
			end
			if nb == 122 and self._vnum >= 502 then
				-- \z: skip following whitespace including newlines
				p = p + 2
				while p <= self.n do
					local wb = self:_byte(p)
					if _isSpaceNoNL(wb) then
						p = p + 1
					elseif wb == 10 then
						p = p + 1
					elseif wb == 13 then
						if p + 1 <= self.n and self:_byte(p + 1) == 10 then
							p = p + 2
						else
							p = p + 1
						end
					else
						break
					end
				end
			elseif nb >= 48 and nb <= 57 then
				-- \ddd: decimal escape (1-3 digits)
				p = p + 2
				local digitCount = 1
				while digitCount < 3 and p <= self.n do
					local db = self:_byte(p)
					if db >= 48 and db <= 57 then
						p = p + 1
						digitCount = digitCount + 1
					else
						break
					end
				end
			elseif nb == 120 and self._vnum >= 502 then
				-- \xhh: hex escape (Lua 5.2+)
				p = p + 2
				local hexCount = 0
				while hexCount < 2 and p <= self.n do
					local hb = self:_byte(p)
					if (hb >= 48 and hb <= 57) or (hb >= 65 and hb <= 70) or (hb >= 97 and hb <= 102) then
						p = p + 1
						hexCount = hexCount + 1
					else
						break
					end
				end
				if hexCount == 0 then
					-- \x with no hex digits: invalid escape
					local escChar = string_char(nb)
					return self:_makeToken("InvalidEscape", a, p - 1, line1, col1, {
						message = "Invalid escape sequence: \\" .. escChar,
						errorKind = "InvalidEscape",
					})
				end
			elseif VALID_ESCAPES[nb] then
				-- Valid simple escape; consume backslash + next char.
				p = p + 2

				-- If the escaped character was CR and it is followed by LF,
				-- consume the LF too so CRLF counts as one escaped newline.
				if nb == 13 and p <= self.n and self:_byte(p) == 10 then
					p = p + 1
				end
			else
				-- Invalid escape sequence
				local escChar = string_char(nb)
				return self:_makeToken("InvalidEscape", a, p + 1, line1, col1, {
					message = "Invalid escape sequence: \\" .. escChar,
					errorKind = "InvalidEscape",
				})
			end
		else
			p = p + 1
		end
	end

	return self:_makeToken("Error", a, self.n, line1, col1, {
		message = "Unterminated string literal",
		errorKind = "UnterminatedString",
	})
end

--- Scan an exponent suffix (e/E for decimal, p/P for hex).<br>
--- Assumes the exponent letter has been peeked but NOT yet consumed.<br>
--- On success, returns the new position past all exponent digits.<br>
--- On failure (no digits after optional sign), returns nil.
---@param p number current position (the letter is at p)
---@return number? newP New position on success, nil on failure
function Lexer._scanExponent(self, p)
	local s = self.s
	local n = self.n
	local byte = string_byte

	-- Consume the exponent letter
	p = p + 1

	-- Optional sign
	if p <= n then
		local sg = byte(s, p)
		if sg == 43 or sg == 45 then -- + or -
			p = p + 1
		end
	end

	-- Must have at least one digit
	local expStart = p
	while p <= n and _isDigit(byte(s, p)) do
		p = p + 1
	end

	if p == expStart then
		return nil
	end

	return p
end

--- Scan a numeric literal in decimal, hex, or exponent notation.<br>
--- Yields an Error token when the literal is malformed.
---@return table token Number or error token.
function Lexer._scanNumber(self)
	local a = self.i
	local line1, col1 = self.line, self.col
	local p = a
	local s = self.s
	local n = self.n
	local byte = string_byte

	local function peek(k)
		local pos = p + (k or 0)
		if pos > n then
			return nil
		end
		return byte(s, pos)
	end

	local function consume()
		p = p + 1
	end

	local function consumeWhile(pred)
		while p <= n and pred(byte(s, p)) do
			p = p + 1
		end
	end

	local function invalidNumber()
		local b = p - 1
		if b < a then
			b = a
		end

		return self:_makeToken("Error", a, b, line1, col1, {
			message = "Invalid number literal",
			errorKind = "InvalidNumber",
		})
	end

	local b0 = peek(0)

	-- Leading '.' decimal float: .123
	if b0 == 46 then
		consume() -- '.'

		consumeWhile(_isDigit)

		local e = peek(0)
		if e == 101 or e == 69 then
			local newP = self:_scanExponent(p)
			if not newP then
				return invalidNumber()
			end
			p = newP
		end

		local nextByte = peek(0)
		if _isIdentStart(nextByte, self.opts.allowNonAsciiIdentifiers) then
			return invalidNumber()
		end

		return self:_makeToken("Number", a, p - 1, line1, col1)
	end

	-- Hexadecimal: 0x... / 0X...
	if b0 == 48 and (peek(1) == 120 or peek(1) == 88) then
		consume() -- '0'
		consume() -- 'x' or 'X'

		local function isHex(b)
			return b and (
				_isDigit(b)
				or (b >= 65 and b <= 70)
				or (b >= 97 and b <= 102)
			)
		end

		local intStart = p
		consumeWhile(isHex)
		local hasInt = p > intStart

		local hasFrac = false

		-- Avoid consuming '.' when followed by another '.', so 0x1..2
		-- can lex as 0x1 .. 2.
		if peek(0) == 46 and peek(1) ~= 46 then
			consume() -- '.'

			local fracStart = p
			consumeWhile(isHex)
			hasFrac = p > fracStart
		end

		if not hasInt and not hasFrac then
			return invalidNumber()
		end

		local e = peek(0)
		if e == 112 or e == 80 then
			consume() -- 'p' or 'P'

			local sgn = peek(0)
			if sgn == 43 or sgn == 45 then
				consume()
			end

			local expStart = p
			consumeWhile(_isDigit)

			if p == expStart then
				return invalidNumber()
			end
		end

		local nextByte = peek(0)
		if _isIdentStart(nextByte, self.opts.allowNonAsciiIdentifiers) then
			return invalidNumber()
		end

		return self:_makeToken("Number", a, p - 1, line1, col1)
	end

	-- Decimal integer/float
	local intStart = p
	consumeWhile(_isDigit)
	local hasInt = p > intStart

	if not hasInt then
		return invalidNumber()
	end

	-- Avoid consuming '.' when followed by another '.', so 1..2
	-- can lex as 1 .. 2.
	if peek(0) == 46 and peek(1) ~= 46 then
		consume() -- '.'
		consumeWhile(_isDigit)
	end

	local e = peek(0)
	if e == 101 or e == 69 then
		local newP = self:_scanExponent(p)
		if not newP then
			return invalidNumber()
		end
		p = newP
	end

	local nextByte = peek(0)
	if _isIdentStart(nextByte, self.opts.allowNonAsciiIdentifiers) then
		return invalidNumber()
	end

	return self:_makeToken("Number", a, p - 1, line1, col1)
end

--- Consume a UTF-8 BOM when present at the start of the source.
---@return boolean? consumed True when skipped, false when absent, nil when not at start.
function Lexer._scanBOM(self)
	if self.i ~= 1 then
		return nil
	end
	if self.n >= 3 and self:_byte(1) == 0xEF and self:_byte(2) == 0xBB and self:_byte(3) == 0xBF then
		-- Skip BOM bytes by advancing position
		self.i = 4
		self.col = 1
		return true
	end
	return false
end

--- Scan a leading '#!' shebang line as a comment token.
---@return table? token Shebang comment token, or nil when not a shebang.
function Lexer._scanShebang(self)
	-- Check if we're at the start (after possible BOM)
	if self.i > 4 then
		return nil
	end
	local actual_pos = self.i
	if self.n >= actual_pos + 1 and self:_slice(actual_pos, actual_pos + 1) == "#!" then
		-- read until newline
		local a = actual_pos
		local line1, col1 = self.line, self.col
		local p = actual_pos
		while p <= self.n do
			local b = self:_byte(p)
			if _isNewline(b) then
				break
			end
			p = p + 1
		end
		return self:_makeToken("Comment", a, p - 1, line1, col1, { subtype = "Shebang" })
	end
	return nil
end

--- Scan an operator or punctuation token at the cursor.<br>
--- Unknown characters produce an Error token instead of failing.
---@return table token Operator, punct, or error token.
function Lexer._scanOpOrPunct(self)
	local a = self.i
	local line1, col1 = self.line, self.col

	local b1 = self:_peek(0)
	local b2 = self:_peek(1)
	local b3 = self:_peek(2)
	local normalize = self.opts.normalizeCOps

	local function emitText(text, ttype, extra)
		local b = a + #text - 1
		return self:_makeToken(ttype, a, b, line1, col1, extra)
	end

	local function isEnabledBitwise()
		return self.opts.enableBitwiseOps
	end

	-- Multi-char first (max length 3)
	if b1 == 46 and b2 == 46 and b3 == 46 then
		return emitText("...", "Punct")
	end
	if b1 == 46 and b2 == 46 then
		return emitText("..", "Punct")
	end
	if b1 == 58 and b2 == 58 then
		return emitText("::", "Punct")
	end

	if b1 == 61 and b2 == 61 then
		local extra
		if normalize then
			extra = { canonical = "==" }
		end
		return emitText("==", "Op", extra)
	end
	if b1 == 126 and b2 == 61 then
		local extra
		if normalize then
			extra = { canonical = "~=" }
		end
		return emitText("~=", "Op", extra)
	end
	if b1 == 60 and b2 == 61 then
		local extra
		if normalize then
			extra = { canonical = "<=" }
		end
		return emitText("<=", "Op", extra)
	end
	if b1 == 62 and b2 == 61 then
		local extra
		if normalize then
			extra = { canonical = ">=" }
		end
		return emitText(">=", "Op", extra)
	end

	if b1 == 47 and b2 == 47 then
		if self.opts.slashSlashMeansComment then
			return self:_scanLineComment(2)
		end

		if self.opts.enableFloorDiv then
			local extra = { op = "floordiv" }
			if normalize then extra.canonical = "//" end
			return emitText("//", "Op", extra)
		end

		return emitText("/", "Op")
	end

	if b1 == 60 and b2 == 60 then
		if not isEnabledBitwise() then
			return emitText("<<", "Error", { message = "Bitwise operators disabled", errorKind = "DisabledFeature" })
		end
		local extra = { op = "shl" }
		if normalize then extra.canonical = "<<" end
		return emitText("<<", "Op", extra)
	end
	if b1 == 62 and b2 == 62 then
		if not isEnabledBitwise() then
			return emitText(">>", "Error", { message = "Bitwise operators disabled", errorKind = "DisabledFeature" })
		end
		local extra = { op = "shr" }
		if normalize then extra.canonical = ">>" end
		return emitText(">>", "Op", extra)
	end
	if b1 == 38 and b2 == 38 then
		if not self.opts.enableCOps then
			return emitText("&&", "Error", { message = "C operators disabled", errorKind = "DisabledFeature" })
		end
		if normalize then
			return emitText("&&", "Keyword", { normalized = "and", canonical = "and" })
		end
		return emitText("&&", "Op", { op = "cand" })
	end
	if b1 == 124 and b2 == 124 then
		if not self.opts.enableCOps then
			return emitText("||", "Error", { message = "C operators disabled", errorKind = "DisabledFeature" })
		end
		if normalize then
			return emitText("||", "Keyword", { normalized = "or", canonical = "or" })
		end
		return emitText("||", "Op", { op = "cor" })
	end
	if b1 == 33 and b2 == 61 then
		if not self.opts.enableCOps then
			return emitText("!=", "Error", { message = "C operators disabled", errorKind = "DisabledFeature" })
		end
		if normalize then
			return emitText("!=", "Op", { normalized = "~=", canonical = "~=" })
		end
		return emitText("!=", "Op", { op = "cneq" })
	end

	-- single char tokens
	-- b1 is non-nil here: _nextRawToken returns EOF before dispatching,
	-- so reaching this point implies a byte is available.
	assert(b1 ~= nil, "Lexer:_scanOpOrPunct called at EOF")
	---@cast b1 integer
	local ch = string_char(b1)

	-- validate some optional single-char ops
	if ch == "&" or ch == "|" then
		if not isEnabledBitwise() then
			return emitText(ch, "Error", { message = "Bitwise operators disabled", errorKind = "DisabledFeature" })
		end
		local extra
		if normalize then
			extra = { canonical = ch }
		end
		return emitText(ch, "Op", extra)
	end
	if ch == "~" then
		if self.opts.enableBitwiseOps then
			local extra
			if normalize then
				extra = { canonical = "~" }
			end
			return emitText("~", "Op", extra)
		end
		-- In non-bitwise Lua versions, lone '~' is invalid.
		return emitText("~", "Error", { message = "Unexpected '~'", errorKind = "UnexpectedChar" })
	end
	if ch == "!" then
		if not self.opts.enableCOps then
			return emitText("!", "Error", { message = "C operators disabled", errorKind = "DisabledFeature" })
		end
		if normalize then
			return emitText("!", "Keyword", { normalized = "not", canonical = "not" })
		end
		return emitText("!", "Op", { op = "cnot" })
	end

	if self._punct[ch] then
		return emitText(ch, "Punct")
	end

	-- Default: any other single char is treated as Op if it is a common Lua symbol.
	-- Otherwise produce Error.
	if ch == "+" or ch == "-" or ch == "*" or ch == "/" or ch == "%" or ch == "^" or ch == "#" or
		ch == "=" or ch == "<" or ch == ">" then
		local extra
		if normalize then
			extra = { canonical = ch }
		end
		return emitText(ch, "Op", extra)
	end

	return emitText(ch, "Error", { message = "Unexpected character: " .. ch, errorKind = "UnexpectedChar" })
end

--- Produces the next token including whitespace/comments.
function Lexer._nextRawToken(self)
	if self._emittedEOF then
		return _token({
			type = "EOF",
			value = "",
			line = self.line,
			col = self.col,
			i = self.i,
			j = self.i,
			line2 = self.line,
			col2 = self.col
		})
	end

	if self:_atEnd() then
		self._emittedEOF = true
		return _token({
			type = "EOF",
			value = "",
			line = self.line,
			col = self.col,
			i = self.n + 1,
			j = self.n + 1,
			line2 = self.line,
			col2 = self.col
		})
	end

	-- BOM (only at file start)
	if self:_scanBOM() then
		-- BOM was found and skipped, continue with next token
		return self:_nextRawToken()
	end

	-- Shebang (only at file start)
	local sb = self:_scanShebang()
	if sb then
		return sb
	end

	local b = self:_peek(0)

	-- Newline
	if _isNewline(b) then
		return self:_scanNewline()
	end

	-- Whitespace
	if _isSpaceNoNL(b) then
		return self:_scanWhitespace()
	end

	-- Lua comment
	if b == 45 and self:_peek(1) == 45 then
		return self:_scanLuaComment()
	end

	-- C comments
	if b == 47 then
		local cc = self:_scanCCommentOrOp()
		if cc then
			return cc
		end
	end

	-- Long string
	if b == 91 then
		local tok = self:_scanLongStringOrComment("LongString", self.i, self.i)
		if tok then
			return tok
		end
		-- not a long string, fallthrough to punct/op scanner
	end

	-- Short string
	if b == 34 or b == 39 then
		return self:_scanShortString()
	end

	-- Number (digit or . followed by non-dot, to handle .5 valid and .e10 invalid)
	if _isDigit(b) or (b == 46 and _isDigit(self:_peek(1))) then
		return self:_scanNumber()
	end

	-- Identifier/Keyword
	if _isIdentStart(b, self.opts.allowNonAsciiIdentifiers) then
		return self:_scanIdentifierOrKeyword()
	end

	-- Non-ASCII bytes: group consecutive bytes into a single Error token
	if b >= 0x80 then
		local p = self.i + 1
		while p <= self.n do
			local nb = string_byte(self.s, p)
			if nb >= 0x80 then
				p = p + 1
			else
				break
			end
		end
		return self:_makeToken("Error", self.i, p - 1, self.line, self.col, {
			message = "Unexpected non-ASCII character",
			errorKind = "InvalidCharacter",
		})
	end

	-- Operators / punctuation
	return self:_scanOpOrPunct()
end

---@diagnostic disable-next-line: missing-return
--- Gets the next token, respecting includeWhitespace/includeComments options.<br>
--- Once EOF is reached, returns EOF tokens forever (see module docs for rationale).
---@return table token Token object with type, value, and position fields
function Lexer.nextToken(self)
	if self._pushback then
		local tok = self._pushback
		self._pushback = nil
		return tok
	end

	while true do
		local old = self.i
		local tok = self:_nextRawToken()

		assert(
			tok.type == "EOF" or self.i > old,
			"Lexer produced zero-length token at position " .. old
		)

		if tok.type == "Whitespace" or tok.type == "Newline" then
			if self.opts.includeWhitespace then
				return tok
			end
		elseif tok.type == "Comment" then
			if self.opts.includeComments then
				return tok
			end
		else
			return tok
		end
	end
end

--- Returns the next token without consuming it.<br>
--- Calling nextToken() again will return the same token.
---@return table token The next token
function Lexer.peekToken(self)
	if self._pushback then
		return self._pushback
	end
	local tok = self:nextToken()
	self._pushback = tok
	return tok
end

--- Pushes a token back so it will be returned by the next nextToken() call.<br>
--- Only one level of pushback is supported.
---@param tok table The token to push back
function Lexer.pushBack(self, tok)
	self._pushback = tok
end

--- Saves the current lexer state for later restoration.
---@return table state Opaque state object
function Lexer.save(self)
	return {
		i = self.i,
		line = self.line,
		col = self.col,
		_emittedEOF = self._emittedEOF,
		_pushback = self._pushback,
	}
end

--- Restores the lexer to a previously saved state.
---@param state table State object returned by save()
function Lexer.restore(self, state)
	self.i = state.i
	self.line = state.line
	self.col = state.col
	self._emittedEOF = state._emittedEOF
	self._pushback = state._pushback
end

--- Creates a clone of this lexer at the same position with the same options.
---@return lua_lexer.LuaLexer clone New lexer sharing the same source string
function Lexer.clone(self)
	local copy = setmetatable({}, Lexer)
	copy.opts = self.opts
	copy.s = self.s
	copy.n = self.n
	copy.i = self.i
	copy.line = self.line
	copy.col = self.col
	copy._emittedEOF = self._emittedEOF
	copy._kw = self._kw
	copy._punct = self._punct
	copy._vnum = self._vnum
	copy._pushback = self._pushback
	return copy
end

--- Returns an iterator that yields tokens until EOF.
---@return function iterator Iterator function that returns next token or nil at EOF
function Lexer.tokens(self)
	return function()
		local tok = self:nextToken()
		if tok.type == "EOF" then
			return nil
		end
		return tok
	end
end

--- Returns an iterator that yields all tokens including the final EOF token.
---@return function iterator Iterator function that returns next token (including EOF)
function Lexer.tokensIncludingEOF(self)
	local done = false

	return function()
		if done then
			return nil
		end

		local tok = self:nextToken()

		if tok.type == "EOF" then
			done = true
		end

		return tok
	end
end

--- Tokenizes the entire source and returns all tokens.
---@return table array Array of all tokens including EOF
function Lexer.tokenize(self)
	local out = {}
	while true do
		local tok = self:nextToken()
		out[#out + 1] = tok
		if tok.type == "EOF" then
			break
		end
	end
	return out
end

-- Deprecated aliases (naming standard: snake_case). Kept for compatibility.
Lexer.next_token = Lexer.nextToken
Lexer.peek_token = Lexer.peekToken
Lexer.push_back = Lexer.pushBack
Lexer.tokens_including_eof = Lexer.tokensIncludingEOF

-- Export
return Lexer
