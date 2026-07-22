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
-- - luaVersion: "5.1"|"5.2"|"5.3"|"5.4" (default "5.1")
-- - includeComments: boolean (default false)
-- - includeWhitespace: boolean (default false)
-- - normalizeCOps: boolean (default false) -- map &&,||,! and != to Lua equivalents (and/or/not/~=)
-- - enableGoto: boolean (default luaVersion >= 5.2)
-- - enableContinue: boolean (default false) -- GMod extension
-- - enableBitwiseOps: boolean (default luaVersion >= 5.3) -- &,|,~,<<,>>
-- - enableFloorDiv: boolean (default luaVersion >= 5.3) -- //
-- - enableCComments: boolean (default false) -- // and /* */
-- - slashSlashMeansComment: boolean|nil -- if nil, defaults to (enableCComments and not enableFloorDiv)
-- - enableCOps: boolean (default false) -- !=, &&, ||, !
-- - allowNonAsciiIdentifiers: boolean (default false) -- non-ASCII bytes as identifier letters (validates UTF-8)
-- - allowUtf8Identifiers: boolean|nil -- DEPRECATED alias for allowNonAsciiIdentifiers
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
---@class LuaLexer
---@field opts LuaLexerOptions Normalized configuration options
---@field s string Source text being lexed
---@field n integer Length of source text
---@field i integer Current position (1-based)
---@field line integer Current line number (1-based)
---@field col integer Current column number (1-based)
---@field _emittedEOF boolean Whether EOF token has been emitted
---@field _kw table Set of keywords for current configuration
---@field _punct table Set of punctuation tokens
---@field _vnum integer Numeric Lua version (e.g. 501, 502, 503, 504)
---@field _pushback table|nil Pushed-back token for peek/pushBack
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

---@class LuaLexerOptions
---@field luaVersion string Lua version string: "5.1"|"5.2"|"5.3"|"5.4"
---@field includeComments boolean Include comment tokens (default false)
---@field includeWhitespace boolean Include whitespace tokens (default false)
---@field normalizeCOps boolean Map &&,||,! and != to Lua equivalents (default false)
---@field enableGoto boolean Enable goto/label (default luaVersion >= 5.2)
---@field enableContinue boolean Enable continue keyword, GMod extension (default false)
---@field enableBitwiseOps boolean Enable &,|,~,<<,>> (default luaVersion >= 5.3)
---@field enableFloorDiv boolean Enable // floor division (default luaVersion >= 5.3)
---@field enableCComments boolean Enable // and /* */ comments (default false)
---@field enableCOps boolean Enable !=, &&, ||, ! (default false)
---@field allowNonAsciiIdentifiers boolean Non-ASCII bytes as identifier letters, validates UTF-8 (default false)
---@field allowUtf8Identifiers boolean|nil DEPRECATED alias for allowNonAsciiIdentifiers
---@field slashSlashMeansComment boolean|nil If nil, defaults to enableCComments and not enableFloorDiv

-- Localized global functions for better performance
local type = type
local error = error
local setmetatable = setmetatable
local string_byte = string.byte
local string_char = string.char
local string_sub = string.sub
local string_find = string.find

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
	elseif b >= 0xE0 and b <= 0xEF then
		return 3
	elseif b >= 0xF0 and b <= 0xF4 then
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
	return s:match("^([^%s]+)(.-)%s*$") or ""
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
---@param opts table|nil Configuration options (see module documentation).
---@return LuaLexer lexer New lexer instance.
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

	local self = setmetatable({}, Lexer)
	self.opts = normalized
	self._kw = _makeKeywordSet(normalized)
	self._punct = PUNCT
	self._vnum = vnum
	self._pushback = nil
	self:reset(source)
	return self
end

--- Resets the lexer with new source text.
---@param source string The new Lua source code to tokenize
---@return LuaLexer self Self for method chaining
function Lexer:reset(source)
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

function Lexer:_atEnd()
	return self.i > self.n
end

function Lexer:_byte(pos)
	return string_byte(self.s, pos)
end

function Lexer:_peek(off)
	off = off or 0
	local p = self.i + off
	if p < 1 or p > self.n then
		return nil
	end
	return string_byte(self.s, p)
end

function Lexer:_slice(a, b)
	return string_sub(self.s, a, b)
end

--- Advances the internal cursor from current self.i to endIndex (inclusive).<br>
--- Returns endLine,endCol (position of the last consumed byte).
function Lexer:_advanceTo(endIndex)
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

function Lexer:_makeToken(ttype, a, b, line1, col1, extra)
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
function Lexer:_scanNewline()
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
function Lexer:_scanWhitespace()
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
function Lexer:_scanIdentifierOrKeyword()
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
function Lexer:_tryLongBracketOpen(a)
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
function Lexer:_findLongBracketClose(startPos, level)
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

function Lexer:_scanLongStringOrComment(kind, openPos, tokenStart)
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

function Lexer:_scanLineComment(prefixLen)
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

function Lexer:_scanLuaComment()
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

function Lexer:_scanCCommentOrOp()
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

function Lexer:_scanShortString()
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
---@return number|nil newP New position on success, nil on failure
function Lexer:_scanExponent(p)
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

function Lexer:_scanNumber()
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

function Lexer:_scanBOM()
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

function Lexer:_scanShebang()
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

function Lexer:_scanOpOrPunct()
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
		local extra = normalize and { canonical = "==" } or nil
		return emitText("==", "Op", extra)
	end
	if b1 == 126 and b2 == 61 then
		local extra = normalize and { canonical = "~=" } or nil
		return emitText("~=", "Op", extra)
	end
	if b1 == 60 and b2 == 61 then
		local extra = normalize and { canonical = "<=" } or nil
		return emitText("<=", "Op", extra)
	end
	if b1 == 62 and b2 == 61 then
		local extra = normalize and { canonical = ">=" } or nil
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
	local ch = string_char(b1)

	-- validate some optional single-char ops
	if ch == "&" or ch == "|" then
		if not isEnabledBitwise() then
			return emitText(ch, "Error", { message = "Bitwise operators disabled", errorKind = "DisabledFeature" })
		end
		local extra = normalize and { canonical = ch } or nil
		return emitText(ch, "Op", extra)
	end
	if ch == "~" then
		if self.opts.enableBitwiseOps then
			local extra = normalize and { canonical = "~" } or nil
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
		local extra = normalize and { canonical = ch } or nil
		return emitText(ch, "Op", extra)
	end

	return emitText(ch, "Error", { message = "Unexpected character: " .. ch, errorKind = "UnexpectedChar" })
end

--- Produces the next token including whitespace/comments.
function Lexer:_nextRawToken()
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
function Lexer:nextToken()
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
function Lexer:peekToken()
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
function Lexer:pushBack(tok)
	self._pushback = tok
end

--- Saves the current lexer state for later restoration.
---@return table state Opaque state object
function Lexer:save()
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
function Lexer:restore(state)
	self.i = state.i
	self.line = state.line
	self.col = state.col
	self._emittedEOF = state._emittedEOF
	self._pushback = state._pushback
end

--- Creates a clone of this lexer at the same position with the same options.
---@return LuaLexer clone New lexer sharing the same source string
function Lexer:clone()
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
function Lexer:tokens()
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
function Lexer:tokensIncludingEOF()
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
function Lexer:tokenize()
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

--- Comprehensive tests
function Lexer:_runTests()
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

--Lexer:_runTests()

-- Export
return Lexer
