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
--     type  = string, -- e.g. 'Identifier','Keyword','Number','String','LongString','Op','Punct','Comment','Whitespace','Newline','EOF','Error'
--     value = string, -- raw lexeme
--     line  = number, -- 1-based start line
--     col   = number, -- 1-based start column
--     i     = number, -- 1-based start index (byte offset)
--     j     = number, -- 1-based end index (inclusive)
--     line2 = number, -- 1-based end line
--     col2  = number, -- 1-based end column
--   }
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
-- - allowUtf8Identifiers: boolean (default false) -- non-ASCII bytes treated as identifier letters (best-effort)
--
-- Notes:
-- * Long bracket strings/comments [=[ ... ]=] fully supported.
-- * Numeric literals include decimal + hex + hex-floats.
-- * Designed to be fast, streaming, and to produce useful diagnostics.

---@class Lexer
--- Lua lexer/tokenizer class for parsing Lua source code.
--- Supports Lua 5.1-5.4 and Garry's Mod extensions.
---@field opts table Configuration options
---@field s string Source text being lexed
---@field n integer Length of source text
---@field i integer Current position (1-based)
---@field line integer Current line number (1-based)
---@field col integer Current column number (1-based)
---@field _kw table Set of keywords for current configuration
---@field _punct table Set of punctuation tokens
local Lexer = {}
Lexer.__index = Lexer

-- Localized global functions for better performance
local type = type
local error = error
local pcall = pcall
local tonumber = tonumber
local setmetatable = setmetatable
local string_byte = string.byte
local string_char = string.char
local string_sub = string.sub

-- Implementation

local function _assert(cond, msg)
	if not cond then return error(msg, 2) end
end

local function _tonumberSafe(s)
	local ok, v = pcall(function() return tonumber(s) end)
	if ok then return v end
	return nil
end

local function _isDigit(b) return b and b >= 48 and b <= 57 end
local function _isAlpha(b)
	return b and ((b >= 65 and b <= 90) or (b >= 97 and b <= 122))
end
local function _isIdentStart(b, allowUtf8)
	return b and (_isAlpha(b) or b == 95 or (allowUtf8 and b >= 128))
end
local function _isIdentPart(b, allowUtf8)
	return b and (_isAlpha(b) or _isDigit(b) or b == 95 or (allowUtf8 and b >= 128))
end
local function _isSpaceNoNL(b)
	-- space, tab, vertical tab, form feed
	return b == 32 or b == 9 or b == 11 or b == 12
end
local function _isNewline(b) return b == 10 or b == 13 end

local function _versionToNum(v)
	if v == "5.1" then return 501 end
	if v == "5.2" then return 502 end
	if v == "5.3" then return 503 end
	if v == "5.4" then return 504 end
	return 501
end

local function _makeKeywordSet(opts)
	local kw = {
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
	if opts.enableGoto then kw["goto"] = true end
	if opts.enableContinue then kw["continue"] = true end
	return kw
end

local function _punctSet()
	return {
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
end

--- Create a token object.
local function _token(t)
	return t
end

--- Creates a new Lexer instance.
---@param source string The Lua source code to tokenize.
---@param opts table|nil Configuration options (see module documentation).
---@return Lexer lexer New lexer instance.
function Lexer.new(source, opts)
	_assert(type(source) == "string", "Lexer.new(source, opts): source must be a string")
	opts = opts or {}

	local vnum = _versionToNum(opts.luaVersion or "5.1")

	local normalized = {
		luaVersion = opts.luaVersion or "5.1",
		includeComments = not not opts.includeComments,
		includeWhitespace = not not opts.includeWhitespace,
		normalizeCOps = not not opts.normalizeCOps,

		enableGoto = (opts.enableGoto ~= nil) and (not not opts.enableGoto) or (vnum >= 502),
		enableContinue = not not opts.enableContinue,
		enableBitwiseOps = (opts.enableBitwiseOps ~= nil) and (not not opts.enableBitwiseOps) or (vnum >= 503),
		enableFloorDiv = (opts.enableFloorDiv ~= nil) and (not not opts.enableFloorDiv) or (vnum >= 503),

		enableCComments = not not opts.enableCComments,
		enableCOps = not not opts.enableCOps,

		allowUtf8Identifiers = not not opts.allowUtf8Identifiers,

		-- If nil: prefer Lua meaning when floor division enabled.
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
	self._punct = _punctSet()
	self:reset(source)
	return self
end

--- Resets the lexer with new source text.
---@param source string The new Lua source code to tokenize
---@return Lexer self Self for method chaining
function Lexer:reset(source)
	_assert(type(source) == "string", "Lexer:reset(source): source must be a string")
	self.s = source
	self.n = #source
	self.i = 1
	self.line = 1
	self.col = 1
	self._emittedEOF = false
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
	if p < 1 or p > self.n then return nil end
	return string_byte(self.s, p)
end

function Lexer:_slice(a, b)
	return string_sub(self.s, a, b)
end

--- Advances the internal cursor from current self.i to endIndex (inclusive).
--- Returns endLine,endCol (position of the last consumed byte).
function Lexer:_advanceTo(endIndex)
	local p = self.i
	local line = self.line
	local col = self.col

	local lastLine, lastCol = line, col

	while p <= endIndex do
		local b = string_byte(self.s, p)
		lastLine, lastCol = line, col

		if b == 10 then
			line = line + 1
			col = 1
			p = p + 1
		elseif b == 13 then
			-- CR or CRLF
			line = line + 1
			col = 1
			if p + 1 <= endIndex and string_byte(self.s, p + 1) == 10 then
				p = p + 2
			else
				p = p + 1
			end
		else
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
		for k, v in next, extra do tok[k] = v end
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

function Lexer:_scanIdentifierOrKeyword()
	local a = self.i
	local line1, col1 = self.line, self.col
	local allowUtf8 = self.opts.allowUtf8Identifiers

	local p = a
	while p <= self.n and _isIdentPart(self:_byte(p), allowUtf8) do
		p = p + 1
	end

	local text = self:_slice(a, p - 1)
	local ttype = self._kw[text] and "Keyword" or "Identifier"
	return self:_makeToken(ttype, a, p - 1, line1, col1)
end

--- Tries to read a long bracket opener at position 'a'.
--- Returns (level, openEnd) or nil.
function Lexer:_tryLongBracketOpen(a)
	if self:_byte(a) ~= 91 then return nil end  -- '['
	local p = a + 1
	while p <= self.n and self:_byte(p) == 61 do -- '='
		p = p + 1
	end
	if p <= self.n and self:_byte(p) == 91 then
		local level = (p - (a + 1))
		return level, p
	end
	return nil
end

function Lexer:_findLongBracketClose(startPos, level)
	-- searches for ]=*=] with exact level, starting at startPos
	local s = self.s
	local n = self.n
	local p = startPos
	while p <= n do
		if string_byte(s, p) == 93 then -- ']'
			local q = p + 1
			local eq = 0
			while q <= n and string_byte(s, q) == 61 do
				eq = eq + 1
				q = q + 1
			end
			if eq == level and q <= n and string_byte(s, q) == 93 then
				return q -- index of final ']'
			end
		end
		p = p + 1
	end
	return nil
end

function Lexer:_scanLongStringOrComment(kind)
	-- kind: "LongString" or "Comment" (already positioned at '[' for string, or at '[' after '--' for comment)
	local a = self.i
	local line1, col1 = self.line, self.col
	local level, openEnd = self:_tryLongBracketOpen(a)
	if not level then
		return nil
	end

	-- Opening delimiter ends at openEnd (the second '[').
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
		-- Unterminated long bracket
		-- consume to end
		local tok = self:_makeToken("Error", a, self.n, line1, col1, {
			message = "Unterminated long bracket " .. (kind == "Comment" and "comment" or "string"),
			errorKind = "UnterminatedLongBracket",
		})
		tok.subtype = kind
		return tok
	end

	return self:_makeToken(kind, a, closeEnd, line1, col1)
end

function Lexer:_scanLineComment(prefixLen)
	local a = self.i
	local line1, col1 = self.line, self.col
	local p = a + prefixLen
	while p <= self.n do
		local b = self:_byte(p)
		if _isNewline(b) then break end
		p = p + 1
	end
	return self:_makeToken("Comment", a, p - 1, line1, col1)
end

function Lexer:_scanLuaComment()
	local a = self.i
	--local line1, col1 = self.line, self.col
	-- starts with --
	local after = a + 2
	if after <= self.n and self:_byte(after) == 91 then
		-- possible long comment
		self.i = after
		local tok = self:_scanLongStringOrComment("Comment")
		if tok then
			return tok
		end
		-- not a long bracket; reset and treat as line comment
		self.i = a
	end
	return self:_scanLineComment(2)
end

function Lexer:_scanCCommentOrOp()
	-- assumes current byte is '/'
	local a = self.i
	local line1, col1 = self.line, self.col
	local b1 = self:_peek(0)
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
			if nb == 122 then
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
			else
				-- simple escape; consume backslash + next char
				p = p + 2
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

function Lexer:_scanNumber()
	local a = self.i
	local line1, col1 = self.line, self.col
	local p = a

	local function peek(k)
		local pos = p + (k or 0)
		if pos > self.n then return nil end
		return self:_byte(pos)
	end

	local function consume()
		p = p + 1
	end

	local function consumeWhile(pred)
		while p <= self.n and pred(self:_byte(p)) do
			p = p + 1
		end
	end

	local b0 = peek(0)
	if b0 == 46 then
		-- leading '.' already confirmed next is digit
		consume() -- '.'
		consumeWhile(_isDigit)
		-- exponent part
		local e = peek(0)
		if e == 101 or e == 69 then
			consume()
			local sgn = peek(0)
			if sgn == 43 or sgn == 45 then consume() end
			consumeWhile(_isDigit)
		end
		return self:_makeToken("Number", a, p - 1, line1, col1)
	end

	if b0 == 48 and (peek(1) == 120 or peek(1) == 88) then
		-- hex
		consume(); consume() -- 0x
		local function isHex(b)
			return b and (_isDigit(b) or (b >= 65 and b <= 70) or (b >= 97 and b <= 102))
		end
		consumeWhile(isHex)
		if peek(0) == 46 then
			consume()
			consumeWhile(isHex)
		end
		local e = peek(0)
		if e == 112 or e == 80 then
			consume()
			local sgn = peek(0)
			if sgn == 43 or sgn == 45 then consume() end
			consumeWhile(_isDigit)
		end
		return self:_makeToken("Number", a, p - 1, line1, col1)
	end

	-- decimal
	consumeWhile(_isDigit)
	if peek(0) == 46 and peek(1) ~= 46 then
		consume()
		consumeWhile(_isDigit)
	end
	local e = peek(0)
	if e == 101 or e == 69 then
		consume()
		local sgn = peek(0)
		if sgn == 43 or sgn == 45 then consume() end
		consumeWhile(_isDigit)
	end

	return self:_makeToken("Number", a, p - 1, line1, col1)
end

function Lexer:_scanBOM()
	if self.i ~= 1 then return nil end
	if self.n >= 3 and self:_byte(1) == 0xEF and self:_byte(2) == 0xBB and self:_byte(3) == 0xBF then
		-- Skip BOM bytes by advancing position
		self.i = 4
		self.col = 4
		return true
	end
	return false
end

function Lexer:_scanShebang()
	-- Check if we're at the start (after possible BOM)
	if self.i > 4 then return nil end
	local actual_pos = self.i
	if self.n >= actual_pos + 1 and self:_slice(actual_pos, actual_pos + 1) == "#!" then
		-- read until newline
		local a = actual_pos
		local line1, col1 = self.line, self.col
		local p = actual_pos
		while p <= self.n do
			local b = self:_byte(p)
			if _isNewline(b) then break end
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
		return emitText("==", "Op")
	end
	if b1 == 126 and b2 == 61 then
		return emitText("~=", "Op")
	end
	if b1 == 60 and b2 == 61 then
		return emitText("<=", "Op")
	end
	if b1 == 62 and b2 == 61 then
		return emitText(">=", "Op")
	end

	if b1 == 47 and b2 == 47 then
		if self.opts.enableFloorDiv and (not self.opts.slashSlashMeansComment) then
			return emitText("//", "Op", { op = "floordiv" })
		end
		-- if slashSlashMeansComment, it will be handled earlier by C comment scanner.
		-- otherwise treat as two '/' ops (emit one now)
		return emitText("/", "Op")
	end

	if b1 == 60 and b2 == 60 then
		if not isEnabledBitwise() then
			return emitText("<<", "Error", { message = "Bitwise operators disabled", errorKind = "DisabledFeature" })
		end
		return emitText("<<", "Op", { op = "shl" })
	end
	if b1 == 62 and b2 == 62 then
		if not isEnabledBitwise() then
			return emitText(">>", "Error", { message = "Bitwise operators disabled", errorKind = "DisabledFeature" })
		end
		return emitText(">>", "Op", { op = "shr" })
	end
	if b1 == 38 and b2 == 38 then
		if not self.opts.enableCOps then
			return emitText("&&", "Error", { message = "C operators disabled", errorKind = "DisabledFeature" })
		end
		if self.opts.normalizeCOps then
			return emitText("&&", "Keyword", { normalized = "and" })
		end
		return emitText("&&", "Op", { op = "cand" })
	end
	if b1 == 124 and b2 == 124 then
		if not self.opts.enableCOps then
			return emitText("||", "Error", { message = "C operators disabled", errorKind = "DisabledFeature" })
		end
		if self.opts.normalizeCOps then
			return emitText("||", "Keyword", { normalized = "or" })
		end
		return emitText("||", "Op", { op = "cor" })
	end
	if b1 == 33 and b2 == 61 then
		if not self.opts.enableCOps then
			return emitText("!=", "Error", { message = "C operators disabled", errorKind = "DisabledFeature" })
		end
		if self.opts.normalizeCOps then
			return emitText("!=", "Op", { normalized = "~=" })
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
		return emitText(ch, "Op")
	end
	if ch == "~" then
		if self.opts.enableBitwiseOps then
			return emitText("~", "Op")
		end
		-- In non-bitwise Lua versions, lone '~' is invalid.
		return emitText("~", "Error", { message = "Unexpected '~'", errorKind = "UnexpectedChar" })
	end
	if ch == "!" then
		if not self.opts.enableCOps then
			return emitText("!", "Error", { message = "C operators disabled", errorKind = "DisabledFeature" })
		end
		if self.opts.normalizeCOps then
			return emitText("!", "Keyword", { normalized = "not" })
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
		return emitText(ch, "Op")
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
			line2 = self
					.line,
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
			line2 =
					self.line,
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
	if sb then return sb end

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
		if cc then return cc end
	end

	-- Long string
	if b == 91 then
		--local line1, col1 = self.line, self.col
		local tok = self:_scanLongStringOrComment("LongString")
		if tok then
			return tok
		end
		-- not a long string, fallthrough to punct/op scanner
	end

	-- Short string
	if b == 34 or b == 39 then
		return self:_scanShortString()
	end

	-- Number (digit or .digit)
	if _isDigit(b) or (b == 46 and _isDigit(self:_peek(1))) then
		return self:_scanNumber()
	end

	-- Identifier/Keyword
	if _isIdentStart(b, self.opts.allowUtf8Identifiers) then
		return self:_scanIdentifierOrKeyword()
	end

	-- Operators / punctuation
	return self:_scanOpOrPunct()
end

---@diagnostic disable-next-line: missing-return
--- Gets the next token, respecting includeWhitespace/includeComments options.
---@return table token Token object with type, value, and position fields
function Lexer:nextToken()
	while true do
		local tok = self:_nextRawToken()

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

--- Returns an iterator that yields tokens until EOF.
---@return function iterator Iterator function that returns next token or nil at EOF
function Lexer:tokens()
	return function()
		local tok = self:nextToken()
		if tok.type == "EOF" then return nil end
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
		if tok.type == "EOF" then break end
	end
	return out
end

return Lexer
