-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- JSON serializer/deserializer library with support for null, custom type
-- converters, pretty printing, sorted keys, and C-style comment ignoring

-- Localized global functions for better performance
local error         = error
local getmetatable  = getmetatable
local next          = next
local setmetatable  = setmetatable
local tonumber      = tonumber
local type          = type
local math_abs      = math.abs
local math_floor    = math.floor
local math_huge     = math.huge
local string_byte   = string.byte
local string_char   = string.char
local string_format = string.format
local string_rep    = string.rep
local string_sub    = string.sub
local table_concat  = table.concat
local table_insert  = table.insert
local table_sort    = table.sort

-- Unique sentinel for JSON null (overridable via json.null).
local null          = {}

-- Precomputed ASCII byte constants (no string literals in hot paths)
--local B_NUL         = 0
local B_TAB         = 9
local B_LF          = 10
--local B_FF          = 12
local B_CR          = 13
local B_SPACE       = 32
local B_QUOTE       = 34 -- "
local B_STAR        = 42 -- *
local B_PLUS        = 43
local B_COMMA       = 44
local B_MINUS       = 45
local B_DOT         = 46
local B_SLASH       = 47 -- /
local B_0           = 48
local B_1           = 49
local B_9           = 57
local B_COLON       = 58
local B_LBRA        = 91 -- [
local B_BS          = 92 -- backslash
local B_RBRA        = 93 -- ]
local B_A           = 65
local B_E           = 69
local B_F           = 70
local B_a           = 97
--local B_b           = 98
local B_e           = 101
local B_f           = 102
local B_n           = 110
--local B_r           = 114
local B_t           = 116
local B_u           = 117
local B_LCURL       = 123 -- {
local B_RCURL       = 125 -- }

-- Escape table for string encoding
local escape_chars  = {
	[0x08] = '\\b',
	[0x09] = '\\t',
	[0x0A] = '\\n',
	[0x0C] = '\\f',
	[0x0D] = '\\r',
	[0x22] = '\\"',
	--[0x2F] = '\\/', -- optional escape for solidus
	[0x5C] = '\\\\',
}
for byte = 0, 31 do
	if not escape_chars[byte] then
		escape_chars[byte] = string_format("\\u%04x", byte)
	end
end

local unescape_chars = {
	[34] = '"',  -- "
	[92] = '\\', -- \
	[47] = '/',  -- /
	[98] = '\b', -- b
	[102] = '\f', -- f
	[110] = '\n', -- n
	[114] = '\r', -- r
	[116] = '\t', -- t
}

---@class JsonConverterOptions
---@field name string Unique identifier for the converter.
---@field tag? string If set, encoder auto-wraps result as `{$type=tag, value=result}`.
---@field priority? number Higher = checked earlier (default: 50).
---@field can_encode fun(self: JsonConverter, value: any): boolean Checks if converter can encode value.
---@field encode fun(self: JsonConverter, value: any, encoder: JsonEncoder): any Encodes custom type.
---@field decode fun(self: JsonConverter, obj: table, decoder: JsonDecoder): any Decodes custom type.

---@class JsonConverter
---@field name string Unique identifier.
---@field tag? string Type name to match for decoding via `$type` field.
---@field priority number Checks priority.
---@field can_encode fun(self: JsonConverter, value: any): boolean
---@field encode fun(self: JsonConverter, value: any, encoder: JsonEncoder): any
---@field decode fun(self: JsonConverter, obj: table, decoder: JsonDecoder): any
local JsonConverter = {}
JsonConverter.__index = JsonConverter

--- Create a new JsonConverter instance.
---@param options JsonConverterOptions JsonConverter configuration.
---@return JsonConverter instance New JsonConverter instance.
function JsonConverter.new(options)
	options = options or {}
	return setmetatable({
		name       = options.name or "converter",
		tag        = options.tag,
		priority   = options.priority or 50,
		can_encode = options.can_encode or function(_, _) return false end,
		encode     = options.encode or function(_, _, _)
			return error("Converter:encode not implemented for '" ..
				(options.name or "unnamed") .. "'")
		end,
		decode     = options.decode or function(_, v, _) return v end,
	}, JsonConverter)
end

--- Helper: intelligent dense array vs dictionary detection.<br>
--- Respects `__jsontype` metatable field ("array" or "object").
---@param t table The table to check.
---@return boolean is_array True if table should be encoded as JSON array.
local function is_array(t)
	local mt = getmetatable(t)
	if mt then
		if mt.__jsontype == "array" then return true end
		if mt.__jsontype == "object" then return false end
	end
	local count, max = 0, 0
	for k in next, t do
		count = count + 1
		if type(k) == "number" and k >= 1 and math_floor(k) == k then
			if k > max then max = k end
		else
			return false
		end
	end
	return count > 0 and count == max
end

---@class JsonEncoder
---@field json Json Reference to the orchestrator.
---@field buf table Buffer for string building.
---@field n number Current buffer length.
---@field depth number Current nesting depth.
local JsonEncoder = {}
JsonEncoder.__index = JsonEncoder

--- Create a new Encoder instance.
---@param json Json The orchestrator Json instance.
---@return JsonEncoder instance New encoder instance.
function JsonEncoder.new(json)
	return setmetatable({
		json  = json,
		buf   = {},
		n     = 0,
		depth = 0,
	}, JsonEncoder)
end

--- Write a string to the buffer.
---@param self JsonEncoder
---@param s string String to write.
function JsonEncoder:write(s)
	self.n = self.n + 1
	self.buf[self.n] = s
end

--- Write a single byte (as character) to the buffer.
---@param self JsonEncoder
---@param b number Byte value to write.
function JsonEncoder:write_byte(b)
	self.n = self.n + 1
	self.buf[self.n] = string_char(b)
end

--- Get the accumulated buffer as a string.
---@param self JsonEncoder
---@return string result The concatenated buffer content.
function JsonEncoder:result()
	return table_concat(self.buf, nil, 1, self.n)
end

--- Write indentation based on current depth.
---@param self JsonEncoder
function JsonEncoder:_indent()
	self:write(string_rep(self.json.indent, self.depth))
end

--- Encode a Lua number to JSON.<br>
--- Handles NaN, Infinity, integers, and floats.
---@param self JsonEncoder
---@param v number Number to encode.
function JsonEncoder:encode_number(v)
	if v ~= v then
		if self.json.encode_nan_as_null then
			self:write("null")
		else
			return error("json: cannot encode NaN")
		end
		return
	end
	if v == math_huge then
		if self.json.encode_inf_as_str then
			self:write("\"Infinity\"")
		else
			self:write("1e999")
		end
		return
	end
	if v == -math_huge then
		if self.json.encode_inf_as_str then
			self:write("\"-Infinity\"")
		else
			self:write("-1e999")
		end
		return
	end
	if math_floor(v) == v and math_abs(v) < 1e14 then
		self:write(string_format("%d", v))
	else
		self:write(string_format("%.17g", v))
	end
end

--- Encode a Lua string to JSON string with proper escaping.
---@param self JsonEncoder
---@param s string String to encode.
function JsonEncoder:encode_string(s)
	local buf, n = self.buf, self.n
	n = n + 1
	buf[n] = '"'
	local len = #s
	local i = 1
	while i <= len do
		local b = string_byte(s, i)
		local esc = escape_chars[b]
		if esc ~= nil then
			n = n + 1
			buf[n] = esc
			i = i + 1
		else
			local j = i + 1
			while j <= len do
				local c = string_byte(s, j)
				if escape_chars[c] ~= nil then
					break
				end
				j = j + 1
			end
			n = n + 1
			buf[n] = string_sub(s, i, j - 1)
			i = j
		end
	end
	n = n + 1
	buf[n] = '"'
	self.n = n
end

--- Encode a Lua table to JSON (array or object).
---@param self JsonEncoder
---@param t table Table to encode.
function JsonEncoder:encode_table(t)
	local max_depth = self.json.max_depth
	if max_depth and self.depth >= max_depth then
		return error("json: max depth " .. max_depth .. " exceeded during encoding")
	end
	if is_array(t) then
		self:encode_array(t)
	else
		self:encode_object(t)
	end
end

--- Encode a Lua array to JSON array.
---@param self JsonEncoder
---@param t table Array table to encode.
function JsonEncoder:encode_array(t)
	self:write_byte(B_LBRA)
	local n = #t
	if n == 0 then
		self:write_byte(B_RBRA)
		return
	end
	local pretty = self.json.pretty
	self.depth = self.depth + 1
	for i = 1, n do
		if pretty then
			self:write(self.json.line_sep)
			self:_indent()
		end
		self:encode_value(t[i])
		if i < n then self:write_byte(B_COMMA) end
	end
	self.depth = self.depth - 1
	if pretty then
		self:write(self.json.line_sep)
		self:_indent()
	end
	self:write_byte(B_RBRA)
end

--- Sort keys for JSON object encoding.<br>
--- Handles mixed string/number keys by converting numbers to strings.
---@param a any First key.
---@param b any Second key.
---@return boolean less_than True if a < b.
local sort_keys = function(a, b)
	local ta, tb = type(a), type(b)
	if ta == "number" then
		a = string_format("%d", a)
		ta = "string"
	end
	if tb == "number" then
		b = string_format("%d", b)
		tb = "string"
	end
	if ta == tb then return a < b end
	return ta < tb
end

--- Encode a Lua object to JSON object.
---@param self JsonEncoder
---@param t table Object table to encode.
function JsonEncoder:encode_object(t)
	self:write_byte(B_LCURL)
	local keys = {}
	local count = 0
	for k in next, t do
		count = count + 1
		keys[count] = k
	end
	if count == 0 then
		self:write_byte(B_RCURL)
		return
	end

	if self.json.sort_keys then
		table_sort(keys, sort_keys)
	end

	local pretty = self.json.pretty
	self.depth = self.depth + 1
	for i = 1, count do
		local k = keys[i]
		if pretty then
			self:write(self.json.line_sep)
			self:_indent()
		end
		local kt = type(k)
		if kt == "string" then
			self:encode_string(k)
		elseif kt == "number" then
			self:encode_string(string_format("%d", k))
		else
			return error("json: object key must be string or number, got " .. kt)
		end
		self:write_byte(B_COLON)
		if pretty then self:write(" ") end
		self:encode_value(t[k])
		if i < count then self:write_byte(B_COMMA) end
	end
	self.depth = self.depth - 1
	if pretty then
		self:write(self.json.line_sep)
		self:_indent()
	end
	self:write_byte(B_RCURL)
end

--- Encode any Lua value using registered converters.
---@param self JsonEncoder
---@param v any Value to encode.
function JsonEncoder:encode_value(v)
	local conv = self.json:_find_encoder(v)
	if conv then
		local result = conv:encode(v, self)
		if result ~= nil then
			if conv.tag then
				return self:encode_value({ ["$type"] = conv.tag, value = result })
			end
			return self:encode_value(result)
		end
		return
	end
	return error("json: no converter for value of type " .. type(v))
end

---@class JsonDecoder
---@field json Json Reference to the orchestrator.
---@field s string The JSON string being parsed.
---@field len number Length of the string.
---@field i number Current parsing position.
---@field depth number Current nesting depth.
local JsonDecoder = {}
JsonDecoder.__index = JsonDecoder

--- Create a new JsonDecoder instance.
---@param json Json The orchestrator Json instance.
---@param s string The JSON string to parse.
---@return JsonDecoder instance New decoder instance.
function JsonDecoder.new(json, s)
	return setmetatable({
		json  = json,
		s     = s,
		len   = #s,
		i     = 1,
		depth = 0,
	}, JsonDecoder)
end

--- Throw a parsing error with position information.
---@param self JsonDecoder
---@param msg string Error message.
function JsonDecoder:err(msg)
	return error("json: " .. msg .. " at pos " .. self.i)
end

--- Skip whitespace and optionally C-style comments.
---@param self JsonDecoder
function JsonDecoder:skip_ws()
	local s, i, len = self.s, self.i, self.len
	local allow_comments = self.json.allow_comments
	while i <= len do
		local b = string_byte(s, i)
		if b == B_SPACE or b == B_TAB or b == B_LF or b == B_CR then
			i = i + 1
		elseif allow_comments and b == B_SLASH then
			if i + 1 <= len then
				local b2 = string_byte(s, i + 1)
				if b2 == B_SLASH then
					-- Line comment
					i = i + 2
					while i <= len do
						local c = string_byte(s, i)
						if c == B_LF or c == B_CR then
							break
						end
						i = i + 1
					end
				elseif b2 == B_STAR then
					-- Block comment
					i = i + 2
					local closed = false
					while i + 1 <= len do
						if string_byte(s, i) == B_STAR and string_byte(s, i + 1) == B_SLASH then
							i = i + 2
							closed = true
							break
						end
						i = i + 1
					end
					if not closed then
						self.i = i
						self:err("unterminated block comment")
					end
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
	self.i = i
end

--- Parse any JSON value.
---@param self JsonDecoder
---@return any value The parsed Lua value.
function JsonDecoder:parse_value()
	self:skip_ws()
	if self.i > self.len then self:err("unexpected end of input") end
	local b = string_byte(self.s, self.i)
	if b == B_QUOTE then
		return self:parse_string()
	end
	if b == B_LCURL then
		return self:parse_object()
	end
	if b == B_LBRA then
		return self:parse_array()
	end
	if b == B_MINUS or (b >= B_0 and b <= B_9) then
		return self:parse_number()
	end
	if b == B_t then
		return self:parse_literal("true", true)
	end
	if b == B_f then
		return self:parse_literal("false", false)
	end
	if b == B_n then
		return self:parse_literal("null", null)
	end
	self:err("unexpected byte " .. b)
end

--- Parse a JSON literal (true, false, null).
---@param self JsonDecoder
---@param word string The literal string to match.
---@param value any The Lua value to return on match.
---@return any value The parsed value.
function JsonDecoder:parse_literal(word, value)
	local s, i = self.s, self.i
	local wlen = #word
	for k = 1, wlen do
		if string_byte(s, i + k - 1) ~= string_byte(word, k) then
			self:err("invalid literal '" .. word .. "'")
		end
	end
	self.i = i + wlen
	return value
end

--- Parse a JSON number.
---@param self JsonDecoder
---@return number num The parsed number.
function JsonDecoder:parse_number()
	local s, len = self.s, self.len
	local start = self.i
	local i = start
	local b = string_byte(s, i)
	if b == B_MINUS then
		i = i + 1
		if i > len then self:err("invalid number") end
		b = string_byte(s, i)
	end
	if b == B_0 then
		i = i + 1
	elseif b and b >= B_1 and b <= B_9 then
		i = i + 1
		while i <= len do
			b = string_byte(s, i)
			if b >= B_0 and b <= B_9 then
				i = i + 1
			else
				break
			end
		end
	else
		self:err("invalid number")
	end
	if i <= len and string_byte(s, i) == B_DOT then
		i = i + 1
		if i > len then self:err("invalid number fraction") end
		b = string_byte(s, i)
		if not (b >= B_0 and b <= B_9) then self:err("invalid number fraction") end
		i = i + 1
		while i <= len do
			b = string_byte(s, i)
			if b >= B_0 and b <= B_9 then
				i = i + 1
			else
				break
			end
		end
	end
	if i <= len then
		b = string_byte(s, i)
		if b == B_e or b == B_E then
			i = i + 1
			if i <= len then
				b = string_byte(s, i)
				if b == B_PLUS or b == B_MINUS then i = i + 1 end
			end
			if i > len then self:err("invalid number exponent") end
			b = string_byte(s, i)
			if not (b >= B_0 and b <= B_9) then self:err("invalid number exponent") end
			i = i + 1
			while i <= len do
				b = string_byte(s, i)
				if b >= B_0 and b <= B_9 then
					i = i + 1
				else
					break
				end
			end
		end
	end
	local text = string_sub(s, start, i - 1)
	self.i = i
	local num = tonumber(text)
	if not num then self:err("invalid number '" .. text .. "'") end
	return num
end

--- Parse 4 hex digits at position.
---@param self JsonDecoder
---@param pos number Starting position in string.
---@return number code_point The parsed Unicode code point.
function JsonDecoder:_hex4(pos)
	local s = self.s
	local cp = 0
	for k = 0, 3 do
		local b = string_byte(s, pos + k)
		local d
		if b >= B_0 and b <= B_9 then
			d = b - B_0
		elseif b >= B_a and b <= B_f then
			d = b - B_a + 10
		elseif b >= B_A and b <= B_F then
			d = b - B_A + 10
		else
			self:err("invalid hex digit in \\u escape")
		end
		cp = cp * 16 + d
	end
	return cp
end

--- Convert a Unicode code point to UTF-8 string.
---@param self JsonDecoder
---@param cp number Unicode code point.
---@return string utf8 The UTF-8 encoded string.
function JsonDecoder:_utf8(cp)
	if cp <= 0x7F then
		return string_char(cp)
	end
	if cp <= 0x7FF then
		return string_char(
			0xC0 + math_floor(cp / 0x40),
			0x80 + (cp % 0x40)
		)
	end
	if cp <= 0xFFFF then
		return string_char(
			0xE0 + math_floor(cp / 0x1000),
			0x80 + (math_floor(cp / 0x40) % 0x40),
			0x80 + (cp % 0x40)
		)
	end
	if cp <= 0x10FFFF then
		return string_char(
			0xF0 + math_floor(cp / 0x40000),
			0x80 + (math_floor(cp / 0x1000) % 0x40),
			0x80 + (math_floor(cp / 0x40) % 0x40),
			0x80 + (cp % 0x40)
		)
	end
	self:err("invalid code point " .. cp)
end

--- Parse a JSON string.
---@param self JsonDecoder
---@return string str The parsed string.
function JsonDecoder:parse_string()
	local s, len = self.s, self.len
	local i = self.i + 1
	local buf, n = {}, 0
	while true do
		if i > len then self:err("unterminated string") end
		local b = string_byte(s, i)
		if b == B_QUOTE then
			self.i = i + 1
			return table_concat(buf, nil, 1, n)
		elseif b == B_BS then
			i = i + 1
			if i > len then self:err("unterminated escape") end
			local e = string_byte(s, i)
			local unesc = unescape_chars[e]
			if unesc then
				n = n + 1
				buf[n] = unesc
			elseif e == B_u then
				local cp = self:_hex4(i + 1)
				i = i + 4
				if cp >= 0xD800 and cp <= 0xDBFF
						and i + 6 <= len
						and string_byte(s, i + 1) == B_BS
						and string_byte(s, i + 2) == B_u then
					local lo = self:_hex4(i + 3)
					if lo >= 0xDC00 and lo <= 0xDFFF then
						cp = 0x10000 + ((cp - 0xD800) * 0x400) + (lo - 0xDC00)
						i = i + 6
					end
				end
				n = n + 1
				buf[n] = self:_utf8(cp)
			else
				self:err("invalid escape sequence")
			end
			i = i + 1
		elseif b < 0x20 then
			self:err("control character in string")
		else
			local j = i + 1
			while j <= len do
				local c = string_byte(s, j)
				if c == B_QUOTE or c == B_BS or c < 0x20 then
					break
				end
				j = j + 1
			end
			n = n + 1
			buf[n] = string_sub(s, i, j - 1)
			i = j
		end
	end
end

--- Parse a JSON array.
---@param self JsonDecoder
---@return table arr The parsed array table.
function JsonDecoder:parse_array()
	local max_depth = self.json.max_depth
	if max_depth and self.depth >= max_depth then
		return error("json: max depth " .. max_depth .. " exceeded during decoding")
	end
	self.i = self.i + 1
	self.depth = self.depth + 1
	local arr = {}
	local idx = 1
	self:skip_ws()
	if self.i <= self.len and string_byte(self.s, self.i) == B_RBRA then
		self.depth = self.depth - 1
		self.i = self.i + 1
		return arr
	end
	while true do
		local v = self:parse_value()
		arr[idx] = v
		idx = idx + 1
		self:skip_ws()
		if self.i > self.len then self:err("unterminated array") end
		local b = string_byte(self.s, self.i)
		if b == B_COMMA then
			self.i = self.i + 1
		elseif b == B_RBRA then
			self.i = self.i + 1
			break
		else
			self:err("expected ',' or ']' in array")
		end
	end
	self.depth = self.depth - 1
	return arr
end

--- Parse a JSON object.
---@param self JsonDecoder
---@return table obj The parsed object table.
function JsonDecoder:parse_object()
	local max_depth = self.json.max_depth
	if max_depth and self.depth >= max_depth then
		return error("json: max depth " .. max_depth .. " exceeded during decoding")
	end
	self.i = self.i + 1
	self.depth = self.depth + 1
	local obj = {}
	self:skip_ws()
	if self.i <= self.len and string_byte(self.s, self.i) == B_RCURL then
		self.depth = self.depth - 1
		self.i = self.i + 1
		return obj
	end
	while true do
		self:skip_ws()
		if self.i > self.len or string_byte(self.s, self.i) ~= B_QUOTE then
			self:err("expected string key in object")
		end
		local key = self:parse_string()
		self:skip_ws()
		if self.i > self.len or string_byte(self.s, self.i) ~= B_COLON then
			self:err("expected ':' after object key")
		end
		self.i = self.i + 1
		local v = self:parse_value()
		obj[key] = v
		self:skip_ws()
		if self.i > self.len then self:err("unterminated object") end
		local b = string_byte(self.s, self.i)
		if b == B_COMMA then
			self.i = self.i + 1
		elseif b == B_RCURL then
			self.i = self.i + 1
			break
		else
			self:err("expected ',' or '}' in object")
		end
	end
	self.depth = self.depth - 1
	local tag = obj["$type"]
	if tag ~= nil then
		local conv = self.json._decoder_by_tag[tag]
		if conv then
			return conv:decode(obj, self)
		end
	end
	return obj
end

---@class JsonOptions
---@field pretty? boolean Enables pretty printing (default: false).
---@field indent? string Indentation string (default: "  ").
---@field sort_keys? boolean Sorts object keys alphabetically (default: false).
---@field allow_comments? boolean Ignores `//` and `/* */` comments (default: false).
---@field encode_nan_as_null? boolean Encodes NaN as null (default: true).
---@field encode_inf_as_str? boolean Encodes Infinity as string (default: false).
---@field max_depth? number Maximum nesting depth for encode/decode (default: nil = unlimited).

---@class Json
---@field pretty boolean Enables pretty printing.
---@field indent string String used for one level of indentation.
---@field line_sep string Line separator.
---@field sort_keys boolean Sorts object keys alphabetically.
---@field allow_comments boolean Ignores C-style comments.
---@field encode_nan_as_null boolean Encodes NaN as null.
---@field encode_inf_as_str boolean Encodes Inf as string.
---@field max_depth? number Maximum nesting depth (nil = unlimited).
---@field _converters table Array of registered converters.
---@field _decoder_by_tag table Map of tags to converters.
local Json = {}
Json.__index = Json

--- Create a new Json orchestrator instance.
---@param options? JsonOptions Optional configuration table.
---@return Json instance New Json instance.
function Json.new(options)
	options = options or {}
	local pretty = options.pretty == true
	local self = setmetatable({
		pretty             = pretty,
		indent             = options.indent or "  ",
		line_sep           = pretty and "\n" or "",
		sort_keys          = options.sort_keys == true,
		allow_comments     = options.allow_comments == true,
		encode_nan_as_null = options.encode_nan_as_null ~= false,
		encode_inf_as_str  = options.encode_inf_as_str == true,
		max_depth          = options.max_depth,
		_converters        = {},
		_decoder_by_tag    = {},
	}, Json)
	self:_install_default_converters()
	return self
end

--- Install default type converters (null, nil, boolean, number, string, table).
---@param self Json
function Json:_install_default_converters()
	self:add_converter({
		name       = "null",
		priority   = 100,
		can_encode = function(_, v) return v == null end,
		encode     = function(_, _, enc) enc:write("null") end,
	})
	self:add_converter({
		name       = "nil",
		priority   = 10,
		can_encode = function(_, v) return v == nil end,
		encode     = function(_, _, enc) enc:write("null") end,
	})
	self:add_converter({
		name       = "boolean",
		priority   = 10,
		can_encode = function(_, v) return type(v) == "boolean" end,
		encode     = function(_, v, enc) enc:write(v and "true" or "false") end,
	})
	self:add_converter({
		name       = "number",
		priority   = 10,
		can_encode = function(_, v) return type(v) == "number" end,
		encode     = function(_, v, enc) enc:encode_number(v) end,
	})
	self:add_converter({
		name       = "string",
		priority   = 10,
		can_encode = function(_, v) return type(v) == "string" end,
		encode     = function(_, v, enc) enc:encode_string(v) end,
	})
	self:add_converter({
		name       = "table",
		priority   = 5,
		can_encode = function(_, v) return type(v) == "table" end,
		encode     = function(_, v, enc) enc:encode_table(v) end,
	})
end

--- Register a new custom converter.
---@param c JsonConverterOptions|JsonConverter Converter config table or instance.
---@return Json self Returns self for chaining.
function Json:add_converter(c)
	if getmetatable(c) ~= JsonConverter then
		c = JsonConverter.new(c)
	end
	table_insert(self._converters, c)
	local n = #self._converters
	while n > 1 and self._converters[n].priority > self._converters[n - 1].priority do
		self._converters[n], self._converters[n - 1] =
				self._converters[n - 1], self._converters[n]
		n = n - 1
	end
	if c.tag then
		self._decoder_by_tag[c.tag] = c
	end
	return self
end

--- Remove a registered converter by name.
---@param name string The name of the converter.
---@return boolean removed True if removed.
function Json:remove_converter(name)
	for i = 1, #self._converters do
		if self._converters[i].name == name then
			local c = table.remove(self._converters, i)
			if c.tag then self._decoder_by_tag[c.tag] = nil end
			return true
		end
	end
	return false
end

--- Find the appropriate converter for a value.
---@param self Json
---@param v any Value to find converter for.
---@return JsonConverter? converter The matching converter or nil.
function Json:_find_encoder(v)
	for i = 1, #self._converters do
		local c = self._converters[i]
		if c:can_encode(v) then
			return c
		end
	end
	--return nil
end

--- Encode a Lua value into a JSON string.
---@param v any The Lua value to encode.
---@return string json_string The encoded JSON string.
function Json:encode(v)
	local enc = JsonEncoder.new(self)
	enc:encode_value(v)
	return enc:result()
end

--- Decode a JSON string into a Lua value.
---@param s string The JSON string to decode.
---@return any value The decoded Lua value.
function Json:decode(s)
	if type(s) ~= "string" then
		return error("json: decode expects a string", 2)
	end
	local dec = JsonDecoder.new(self, s)
	local v = dec:parse_value()
	dec:skip_ws()
	if dec.i <= dec.len then
		dec:err("trailing characters")
	end
	return v
end

---@class json
local json = {
	Json      = Json,
	Encoder   = JsonEncoder,
	Decoder   = JsonDecoder,
	Converter = JsonConverter,
	new       = Json.new,
	--- Unique sentinel for JSON null (overridable).<br>
	--- Pass this as a value to encode it as JSON `null`; by default, Lua `nil` also encodes as `null`.
	---@type table
	null      = null,
}

local _default = json.new()

--- Encode a Lua value into a JSON string (convenience shortcut).<br>
--- Uses the default singleton instance.
---@param data any The Lua value to encode.
---@param options? JsonOptions Optional encoder configuration.
---@return string json_string The encoded JSON string.
---@usage <br>
--- ```
--- -- Basic encoding
--- local result = json.encode({ name = "Alice", age = 30 })
--- -- result: '{"name":"Alice","age":30}'
--- ```
function json.encode(data, options)
	if options then return Json.new(options):encode(data) end
	return _default:encode(data)
end

--- Decode a JSON string into a Lua value (convenience shortcut).<br>
--- Uses the default singleton instance.
---@param str string The JSON string to decode.
---@param options? JsonOptions Optional decoder configuration.
---@return any value The decoded Lua value.
function json.decode(str, options)
	if options then return Json.new(options):decode(str) end
	return _default:decode(str)
end

--- Register a converter on the default instance (module-level convenience).
---@param c JsonConverterOptions|JsonConverter Converter config table or instance.
---@return json self Returns the module for chaining.
function json.add_converter(c)
	_default:add_converter(c)
	return json
end

-- Export
return json
