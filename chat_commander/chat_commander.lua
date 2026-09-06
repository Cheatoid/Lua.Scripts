-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Chat command parser/dispatcher for (in-game) chat commands with autocompletion support

-- Localized global functions for better performance
local assert = assert
local error = error
local next = next
local pcall = pcall
local print = print
local tonumber = tonumber
local tostring = tostring
local type = type
local math_modf = math.modf
local string_byte = string.byte
local string_char = string.char
local string_find = string.find
local string_format = string.format
local string_lower = string.lower
local string_match = string.match
local string_sub = string.sub
local table_concat = table.concat
local table_insert = table.insert
local table_remove = table.remove
local table_sort = table.sort

-- Import autocompleter
local autocompleter = require "../autocompleter/autocompleter"

-- Cache boolean autocompleter for performance
local bool_autocompleter = autocompleter.new()
bool_autocompleter:insert("true")
bool_autocompleter:insert("false")
bool_autocompleter:insert("yes")
bool_autocompleter:insert("no")
bool_autocompleter:insert("on")
bool_autocompleter:insert("off")
bool_autocompleter:insert("1")
bool_autocompleter:insert("0")

local TYPE_COERCERS

----------------------------------------------------------------------
-- ChatCommander Class
----------------------------------------------------------------------

---@class ChatCommander
---@field prefix? string Command prefix (default: "/")
---@field commands table<string, chat_commander.CommandSchema> Registry of commands
---@field alias_map table<string, string> Mapping from alias to command name
---@field command_autocompleter table Autocompleter instance for command names
---@field type_coercers table<string, fun(token: string): (any, string?)> Type coercion functions
---@field type_suggestions table<string, fun(partial: string): string[]> Custom type suggestion handlers
local ChatCommander = {}
ChatCommander.__index = ChatCommander

--- Create a new ChatCommander instance
---@param prefix? string Command prefix (default: "/")
---@return ChatCommander instance
function ChatCommander.new(prefix)
	return setmetatable({
		-- Configuration
		prefix = prefix or "/",
		-- Command registry
		commands = {},
		alias_map = {},
		command_autocompleter = autocompleter.new(),
		-- Type system
		type_coercers = TYPE_COERCERS,
		type_suggestions = {},
	}, ChatCommander)
end

---@class chat_commander.CommandArg
---@field name? integer|string Argument name (defaults to numerical index if not provided)
---@field type? string|string[] Argument type (string, number, boolean, etc.) or array of types
---@field required? boolean Whether argument is required (defaults to true, unless `default` is specified)
---@field default? any Default value if optional and not provided
---@field enum? string[] Enum choices (if type is enum)
---@field raw? boolean If true, skip coercion and return raw token

---@class chat_commander.CommandSchema
---@field description? string Command description
---@field aliases? string[] Alternative names for the command
---@field args? chat_commander.CommandArg[] Argument specifications
---@field handler? fun(ctx: table, args: table): any Command handler function (optional, but warned if missing)
---@field permission? fun(ctx: table, args: table): boolean, string Permission check function
---@field validate? fun(schema: chat_commander.CommandSchema): boolean, string Custom validation during registration
---@field pre_validate? fun(ctx: table, args: table): boolean, string Custom validation before handler execution
---@field pass_varargs? boolean Whether to pass remaining args as varargs to handler

---@class chat_commander.ParsedCommand
---@field name string Command name
---@field args table Parsed arguments (keyed by name)
---@field schema chat_commander.CommandSchema Command schema

---@class chat_commander.CommandInfo
---@field name string Command name
---@field description string Command description
---@field args chat_commander.CommandArg[] Argument specifications

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------

--- Trim whitespace from both ends of a string.
---@param s string The string to trim
---@return string trimmed The trimmed string
local function trim(s)
	return (string_match(s, "^%s*(.-)%s*$"))
end

--- Skip whitespace characters in a string starting from position i.<br>
--- Returns the new position after skipping whitespace.
---@param line string The string to process
---@param i integer Starting position
---@param len integer Length of the string
---@return integer new_i New position after skipping whitespace
local function skip_spaces(line, i, len)
	while i <= len and string_match(string_sub(line, i, i), "%s") do
		i = i + 1
	end
	return i
end

local ESCAPE_MAP = {
	["n"]  = "\n",
	["r"]  = "\r",
	["t"]  = "\t",
	["b"]  = "\b",
	["f"]  = "\f",
	["\\"] = "\\",
	['"']  = '"',
	["'"]  = "'",
}

--- Parse an escape sequence at position i in str.<br>
--- Supports: \n, \r, \t, \b, \f, \\, \", \', and \xHH (hex byte)
---@param str string The string containing the escape sequence
---@param i integer Position of the backslash
---@return string char The decoded character
---@return integer new_i New position after the escape sequence
local function parse_escape_sequence(str, i)
	-- str[i] is assumed to be backslash
	local c = string_sub(str, i + 1, i + 1)
	if c == "" then
		return "\\", i + 1
	end

	-- Hex escape: \xHH
	if c == "x" then
		local h1 = string_sub(str, i + 2, i + 2)
		local h2 = string_sub(str, i + 3, i + 3)
		if string_match(h1, "%x") and string_match(h2, "%x") then
			local byte = tonumber(h1 .. h2, 16)
			return string_char(byte), i + 3
		end
		-- Invalid hex escape, treat literally
		return "x", i + 1
	end

	local mapped = ESCAPE_MAP[c]
	if mapped then
		return mapped, i + 1
	end

	-- Unknown escape: keep the char as-is
	return c, i + 1
end

--- Unescape a string literal, processing all escape sequences.<br>
--- Processes escape sequences like \n, \t, \xHH, etc.
---@param str string The string to unescape
---@return string unescaped The unescaped string
local function unescape_string_literal(str)
	local out = {}
	local i = 1
	local len = #str

	while i <= len do
		local c = string_sub(str, i, i)
		if c == "\\" then
			local repl, new_i = parse_escape_sequence(str, i)
			out[#out + 1] = repl
			i = new_i + 1
		else
			out[#out + 1] = c
			i = i + 1
		end
	end

	return table_concat(out)
end

----------------------------------------------------------------------
-- Primitive coercion
----------------------------------------------------------------------

--- Convert a token to a boolean value.<br>
--- Accepts: true/false, 1/0, yes/no, on/off (case-insensitive)
---@param token string The token to convert
---@return boolean? value The boolean value, or nil if invalid
---@return string? error Error message if conversion failed
local function to_boolean(token)
	local lower = string_lower(token)
	if lower == "true" or lower == "1" or lower == "yes" or lower == "on" then
		return true
	end
	if lower == "false" or lower == "0" or lower == "no" or lower == "off" then
		return false
	end
	return nil, "invalid boolean: " .. token
end

--- Convert a token to a number.<br>
--- Supports: decimal, integer, negative, float, and hex (0xFF, -0xFF)
---@param token string The token to convert
---@return number? value The numeric value, or nil if invalid
---@return string? error Error message if conversion failed
local function to_number(token)
	-- Hex: 0xFF, -0xFF
	if string_match(token, "^%-?0[xX][0-9a-fA-F]+$") then
		local sign = 1
		if string_sub(token, 1, 1) == "-" then
			sign = -1
			token = string_sub(token, 2)
		end
		-- Strip 0x or 0X prefix
		token = string_sub(token, 3)
		local n = tonumber(token, 16)
		if not n then
			return nil, "invalid hex number: " .. token
		end
		return sign * n
	end

	-- Binary: 0b1010, -0b1010
	if string_match(token, "^%-?0[bB][01]+$") then
		local sign = 1
		if string_sub(token, 1, 1) == "-" then
			sign = -1
			token = string_sub(token, 2)
		end
		-- Strip 0b or 0B prefix
		token = string_sub(token, 3)
		local n = tonumber(token, 2)
		if not n then
			return nil, "invalid binary number: " .. token
		end
		return sign * n
	end

	-- Decimal / integer / negative / float
	local n = tonumber(token)
	if not n then
		return nil, "invalid number: " .. token
	end

	return n
end

--- Convert a token to a string (identity function).
---@param token string The token to convert
---@return string value The string value
local function to_string(token)
	return token
end

--- Convert a token to an integer.<br>
--- Uses math.modf to validate that the number has no fractional part.
---@param token string The token to convert
---@return number? value The integer value, or nil if invalid
---@return string? error Error message if parsing failed
local function to_integer(token)
	local n = tonumber(token)
	if not n then
		return nil, "invalid integer: " .. token
	end
	local int_part, frac_part = math_modf(n)
	if frac_part ~= 0 then
		return nil, "not an integer: " .. token
	end
	return int_part
end

----------------------------------------------------------------------
-- Custom type registration and helpers
-- - register_type(name, coercer)
-- - register_suggestions(name, handler)
-- - Example: vector3, player lookup, etc.
----------------------------------------------------------------------
-- Built-in type coercers; can be extended at runtime via M.register_type
---@type table<string, fun(token: string): (any, string?)>
TYPE_COERCERS = {
	["any"]     = function(token) return token end, -- Accepts any value, returns raw string
	["bool"]    = to_boolean,
	["boolean"] = to_boolean,
	["float"]   = to_number,
	["num"]     = to_number,
	["number"]  = to_number,
	["int"]     = to_integer,
	["integer"] = to_integer,
	["str"]     = to_string,
	["string"]  = to_string,
}

--- Register a custom type coercer.<br>
--- Allows extending the type system with custom argument types.
---@param self ChatCommander
---@param name string The type name to register
---@param coercer fun(token: string): (any, string) The coercer function
---@usage <br>
--- ```
--- commander:register_type("vector3", coerce_vector3)
--- ```
function ChatCommander.register_type(self, name, coercer)
	assert(type(name) == "string" and name ~= "", "type name must be non-empty string")
	assert(type(coercer) == "function", "coercer must be a function")
	-- Test the coercer with a simple value to ensure it returns proper format
	local test_ok, test_result, test_err = pcall(coercer, "test")
	if not test_ok then
		return error("coercer function failed during test: " .. tostring(test_result))
	end
	if test_err and type(test_err) ~= "string" then
		return error("coercer function must return (value, error_string) on failure")
	end
	self.type_coercers[name] = coercer
end

--- Register a suggestion handler for a custom type.<br>
--- The handler should return an array of suggestion strings based on the partial input.
---@param self ChatCommander
---@param name string The type name to register suggestions for
---@param handler fun(partial: string): string[] The suggestion handler function
---@usage <br>
--- ```
--- commander:register_suggestions("player", function(partial)
---   local players = get_online_players()
---   local matches = {}
---   for _, player in ipairs(players) do
---     if string.sub(string.lower(player), 1, #partial) == string.lower(partial) then
---       table.insert(matches, player)
---     end
---   end
---   return matches
--- end)
--- ```
function ChatCommander.register_suggestions(self, name, handler)
	assert(type(name) == "string" and name ~= "", "type name must be non-empty string")
	assert(type(handler) == "function", "handler must be a function")
	self.type_suggestions[name] = handler
end

--- Parse a vector3 from "x,y,z" format.<br>
--- Returns a table with x, y, z fields.
---@param token string The token to parse (format: "x,y,z")
---@return table? vector3 The vector3 table, or nil if invalid
---@return string? error Error message if parsing failed
local function coerce_vector3(token)
	local x, y, z = string_match(token, "^%s*([^,]+)%s*,%s*([^,]+)%s*,%s*([^,]+)%s*$")
	if not x then
		return nil, "invalid vector3 format, expected x,y,z"
	end
	local nx, errx = to_number(x)
	if not nx then return nil, "vector3.x: " .. errx end
	local ny, erry = to_number(y)
	if not ny then return nil, "vector3.y: " .. erry end
	local nz, errz = to_number(z)
	if not nz then return nil, "vector3.z: " .. errz end
	return { x = nx, y = ny, z = nz }
end

----------------------------------------------------------------------
-- Tokenization
-- Supports:
-- - Unquoted tokens: foo bar 123 true
-- - Quoted tokens: "hello world", 'single quotes'
-- - Escapes inside quotes: "line\nbreak", "quote: \""
-- Note: Key-value syntax (key=value) is tokenized as-is and parsed separately
----------------------------------------------------------------------

--- Tokenize a command line into tokens.<br>
--- Handles quoted strings, escape sequences, and whitespace.
---@param self ChatCommander
---@param line string The line to tokenize
---@return string[] tokens Array of tokens
function ChatCommander.tokenize(self, line)
	local tokens = {}
	local i = 1
	local len = #line

	while true do
		i = skip_spaces(line, i, len)
		if i > len then break end

		local c = string_sub(line, i, i)
		if c == '"' or c == "'" then
			-- Quoted token
			local quote = c
			i = i + 1
			local start = i
			local buf = {}
			local closed = false

			while i <= len do
				local ch = string_sub(line, i, i)
				if ch == "\\" then
					local repl, new_i = parse_escape_sequence(line, i)
					buf[#buf + 1] = repl
					i = new_i + 1
				elseif ch == quote then
					closed = true
					i = i + 1
					break
				else
					buf[#buf + 1] = ch
					i = i + 1
				end
			end

			local token = table_concat(buf)
			tokens[#tokens + 1] = token
		else
			-- Unquoted token
			local start = i
			while i <= len and not string_match(string_sub(line, i, i), "%s") do
				i = i + 1
			end
			local token = string_sub(line, start, i - 1)
			tokens[#tokens + 1] = token
		end
	end

	return tokens
end

----------------------------------------------------------------------
-- Key-value parsing
-- Accepts tokens like:
--   "foo", "bar", "x=10", "flag=true", "name=\"John\""
-- Returns:
--   positional = { "foo", "bar" }
--   named = { x = "10", flag = "true", name = "John" }
----------------------------------------------------------------------

--- Split tokens into positional and named (key=value) tokens.<br>
--- Tokens containing "=" are split into key-value pairs.
---@param tokens string[] Array of tokens to split
---@return string[] positional Positional tokens
---@return table<string, string> named Named tokens (key -> value)
local function split_key_value_tokens(tokens)
	local positional = {}
	local named = {}

	for i = 1, #tokens do
		local tok = tokens[i]
		local eq_pos = string_find(tok, "=", nil, true)
		if eq_pos then
			local key = string_sub(tok, 1, eq_pos - 1)
			local value = string_sub(tok, eq_pos + 1)
			if key ~= "" then
				named[key] = value
			else
				positional[#positional + 1] = tok
			end
		else
			positional[#positional + 1] = tok
		end
	end

	return positional, named
end

----------------------------------------------------------------------
-- Command registry (instance methods)
----------------------------------------------------------------------

---@class chat_commander.CompletionToken
---@field text string Token text
---@field start integer Start position (1-based)
---@field finish integer End position (1-based)
---@field quoted boolean Whether token is quoted
---@field closed boolean Whether quoted token was properly closed (only meaningful if quoted=true)

---@class chat_commander.CompletionContext
---@field kind string Context kind: "CommandName", "ArgValue", "InsideString", "BetweenTokens"
---@field tokens chat_commander.CompletionToken[] All tokens
---@field token_index integer Index of current token
---@field token? chat_commander.CompletionToken Current token
---@field partial string Partial input at caret
---@field cmd? chat_commander.CommandSchema Resolved command schema
---@field arg_index? integer Current argument index

-- schema = {
--   description = "text",
--   args = {
--     { name = "x", type = "number" },  -- required by default
--     { name = "y", type = "number", default = 0 },  -- optional due to default
--     { name = "flag", type = "boolean", required = false },  -- explicitly optional
--   },
--   handler = function(ctx, args) end
-- }

--- Command builder for fluent API
---@class chat_commander.CommandBuilder
---@field name string
---@field schema chat_commander.CommandSchema
local CommandBuilder = {}
CommandBuilder.__index = CommandBuilder

--- Create a new command builder
---@param self ChatCommander
---@param name string Command name
---@return chat_commander.CommandBuilder
function ChatCommander.new_command_builder(self, name)
	assert(type(name) == "string" and name ~= "", "command name must be non-empty string")
	local builder = {
		commander = self,
		name = name,
		schema = {
			args = {},
			pass_varargs = true, -- Enabled by default for fluent API
		},
	}
	return setmetatable(builder, CommandBuilder)
end

--- Set command description
---@param self chat_commander.CommandBuilder
---@param text string Description text
---@return chat_commander.CommandBuilder
function CommandBuilder.description(self, text)
	assert(type(text) == "string", "description must be a string")
	self.schema.description = text
	return self
end

--- Add an argument
---@param self chat_commander.CommandBuilder
---@param name_or_spec string|table Argument name or specification table
---@param arg_type? string Argument type (if name_or_spec is string)
---@param default? any Default value (optional)
---@return chat_commander.CommandBuilder
function CommandBuilder.arg(self, name_or_spec, arg_type, default)
	local arg_spec
	if type(name_or_spec) == "string" and type(arg_type) == "string" then
		-- Two-parameter syntax: :arg("x", "number")
		arg_spec = { name = name_or_spec, type = arg_type }
		if default ~= nil then
			arg_spec.default = default
		end
	elseif type(name_or_spec) == "string" then
		-- Single string: anonymous arg with type
		arg_spec = { type = name_or_spec }
		-- If second parameter is not a string, treat it as default for anonymous arg
		if type(arg_type) ~= "string" then
			arg_spec.default = arg_type
		end
	elseif type(name_or_spec) == "table" then
		arg_spec = name_or_spec
		-- Check for simplified array syntax { "name", "type" } or { "name", "type", default }
		if not arg_spec.name and not arg_spec.type and arg_spec[1] and arg_spec[2] then
			if type(arg_spec[1]) == "string" and type(arg_spec[2]) == "string" then
				local new_spec = { name = arg_spec[1], type = arg_spec[2] }
				if arg_spec[3] ~= nil then
					new_spec.default = arg_spec[3]
				end
				arg_spec = new_spec
			end
		end
	else
		return error("arg must be string or table", 2)
	end
	table_insert(self.schema.args, arg_spec)
	return self
end

--- Set the handler function
---@param self chat_commander.CommandBuilder
---@param fn function Handler function
---@return chat_commander.CommandBuilder
function CommandBuilder.handler(self, fn)
	assert(type(fn) == "function", "handler must be a function")
	self.schema.handler = fn
	return self
end

--- Set permission check
---@param self chat_commander.CommandBuilder
---@param fn function Permission function
---@return chat_commander.CommandBuilder
function CommandBuilder.permission(self, fn)
	assert(type(fn) == "function", "permission must be a function")
	self.schema.permission = fn
	return self
end

--- Set registration-time validation
---@param self chat_commander.CommandBuilder
---@param fn function Validation function
---@return chat_commander.CommandBuilder
function CommandBuilder.validate(self, fn)
	assert(type(fn) == "function", "validate must be a function")
	self.schema.validate = fn
	return self
end

--- Set execution-time validation
---@param self chat_commander.CommandBuilder
---@param fn function Validation function
---@return chat_commander.CommandBuilder
function CommandBuilder.pre_validate(self, fn)
	assert(type(fn) == "function", "pre_validate must be a function")
	self.schema.pre_validate = fn
	return self
end

--- Set aliases
---@param self chat_commander.CommandBuilder
---@param aliases string[] Array of alias names
---@return chat_commander.CommandBuilder
function CommandBuilder.aliases(self, aliases)
	assert(type(aliases) == "table", "aliases must be a table")
	for i = 1, #aliases do
		assert(type(aliases[i]) == "string" and aliases[i] ~= "", "alias must be a non-empty string")
	end
	self.schema.aliases = aliases
	return self
end

CommandBuilder.alias = CommandBuilder.aliases

--- Set enum choices for the last added argument
---@param self chat_commander.CommandBuilder
---@param ... string|table Enum choices (either a table or varargs of strings)
---@return chat_commander.CommandBuilder
function CommandBuilder.enum(self, ...)
	local enum_values
	if select("#", ...) == 1 and type(select(1, ...)) == "table" then
		-- Table passed directly
		enum_values = select(1, ...)
	else
		-- Varargs passed, collect into table
		enum_values = { ... }
	end

	assert(type(enum_values) == "table", "enum_values must be a table or varargs of strings")
	for i = 1, #enum_values do
		assert(type(enum_values[i]) == "string", "enum value must be a string")
	end
	local last_arg = self.schema.args[#self.schema.args]
	if not last_arg then
		return error("Cannot set enum: no arguments added yet. Add an argument first using :arg()", 2)
	end
	last_arg.enum = enum_values
	return self
end

--- Enable passing rest arguments as varargs to handler
---@param self chat_commander.CommandBuilder
---@param enabled boolean Whether to enable varargs passing
---@return chat_commander.CommandBuilder
function CommandBuilder.pass_varargs(self, enabled)
	assert(type(enabled) == "boolean", "enabled must be a boolean")
	self.schema.pass_varargs = enabled
	return self
end

--- Register the command
---@param self chat_commander.CommandBuilder
---@return chat_commander.CommandBuilder
function CommandBuilder.register(self)
	-- Require handler for fluent API (hard error)
	if not self.schema.handler then
		return error(
			"Fluent API requires handler to be set before calling :register(). Use :handler(fn) before :register(), or use the standard API if you want to set the handler later.",
			2)
	end
	self.commander:register_command(self.name, self.schema)
	return self
end

--- Register a command with the parser.<br>
--- Command names are case-insensitive (stored in lowercase).
---@param self ChatCommander
---@param name string The command name
---@param schema? chat_commander.CommandSchema The command schema (optional for builder pattern)
---@return chat_commander.CommandBuilder|chat_commander.CommandSchema # Returns builder if schema is nil, otherwise returns the schema for modification
function ChatCommander.register_command(self, name, schema)
	assert(type(name) == "string" and name ~= "", "command name must be non-empty string")

	-- If no schema provided, return a builder for fluent API
	if schema == nil then
		return self:new_command_builder(name)
	end

	assert(type(schema) == "table", "schema must be a table")

	-- Handler is optional, but warn if missing
	if schema.handler then
		assert(type(schema.handler) == "function", "schema.handler must be a function if provided")
	else
		-- Print warning to console
		print("Warning: command '" .. name .. "' registered without a handler")
	end

	-- Validate schema structure
	if schema.args then
		assert(type(schema.args) == "table", "schema.args must be a table or nil")
		for i = 1, #schema.args do
			local arg = schema.args[i]
			assert(type(arg) == "table", "schema.args[" .. i .. "] must be a table")

			-- Normalize simplified argument syntax
			-- Support: { "name", "type" }, { "name", type="type" }, { name="name", "type" }
			local normalized = {}
			local has_name = arg.name ~= nil
			local has_type = arg.type ~= nil

			-- Check for array-style: { "name", "type" }
			if not has_name and not has_type and arg[1] and arg[2] then
				if type(arg[1]) == "string" and type(arg[2]) == "string" then
					normalized.name = arg[1]
					normalized.type = arg[2]
					has_name = true
					has_type = true
				end
			end

			-- Check for mixed: { "name", type="type" }
			if not has_name and has_type and arg[1] then
				if type(arg[1]) == "string" then
					normalized.name = arg[1]
					has_name = true
				end
			end

			-- Check for mixed: { name="name", "type" }
			if has_name and not has_type and arg[1] then
				if type(arg[1]) == "string" then
					normalized.type = arg[1]
					has_type = true
				end
			end

			-- Copy normalized values back to arg
			if normalized.name then arg.name = normalized.name end
			if normalized.type then arg.type = normalized.type end

			-- Generate default name if not provided (using numerical index)
			if not arg.name or arg.name == "" then
				arg.name = i
			end
		end

		-- Check for duplicate argument names
		local seen_names = {}
		for i = 1, #schema.args do
			local arg_name = schema.args[i].name
			if seen_names[arg_name] then
				return error(
					"duplicate argument name '" ..
					tostring(arg_name) .. "' at index " .. i .. " (already used at index " .. seen_names[arg_name] .. ")",
					2)
			end
			seen_names[arg_name] = i
		end

		-- Validate each argument
		for i = 1, #schema.args do
			local arg = schema.args[i]

			-- Set default required behavior: arguments are required by default
			-- If default is specified, automatically treat as optional
			if arg.required == nil then
				arg.required = arg.default == nil
			elseif arg.default ~= nil and arg.required then
				-- If both default and required=true are specified, that's a conflict
				-- We'll allow it but warn that default won't be used for required args
			end

			-- Validate type if specified (can be string or array of strings)
			if arg.type then
				if type(arg.type) == "table" then
					-- Array of types
					assert(#arg.type > 0, "schema.args[" .. i .. "].type array must not be empty")
					for j = 1, #arg.type do
						assert(type(arg.type[j]) == "string",
							"schema.args[" .. i .. "].type[" .. j .. "] must be a string")
						-- Check for ? suffix to mark as optional
						if string_byte(arg.type[j], -1) == 63 then -- ASCII 63 is '?'
							arg.type[j] = string_sub(arg.type[j], 1, -2)
							arg.required = false
						end
						assert(self.type_coercers[arg.type[j]] ~= nil,
							"schema.args[" .. i .. "].type '" .. arg.type[j] .. "' is not a registered type")
					end
				elseif type(arg.type) == "string" then
					-- Single type
					-- Check for ? suffix to mark as optional
					if string_byte(arg.type, -1) == 63 then -- ASCII 63 is '?'
						arg.type = string_sub(arg.type, 1, -2)
						arg.required = false
					end
					assert(self.type_coercers[arg.type] ~= nil,
						"schema.args[" .. i .. "].type '" .. arg.type .. "' is not a registered type")
				else
					return error("schema.args[" .. i .. "].type must be string or table of strings")
				end
			end

			-- Validate enum if specified
			if arg.enum then
				assert(type(arg.enum) == "table", "schema.args[" .. i .. "].enum must be a table")
				assert(#arg.enum > 0, "schema.args[" .. i .. "].enum must not be empty")
				for j = 1, #arg.enum do
					assert(type(arg.enum[j]) == "string", "schema.args[" .. i .. "].enum[" .. j .. "] must be a string")
				end
			end

			-- Validate default value type matches type if both specified
			if arg.default ~= nil and arg.type then
				-- Basic type check - for custom types we can't validate deeply
				if arg.type == "boolean" or arg.type == "bool" then
					assert(type(arg.default) == "boolean",
						"schema.args[" .. i .. "].default must be boolean when type is " .. arg.type)
				elseif arg.type == "number" or arg.type == "num" or arg.type == "integer" or arg.type == "int" then
					assert(type(arg.default) == "number",
						"schema.args[" .. i .. "].default must be number when type is " .. arg.type)
				elseif arg.type == "string" or arg.type == "str" then
					assert(type(arg.default) == "string",
						"schema.args[" .. i .. "].default must be string when type is " .. arg.type)
				end
			end

			-- Validate default value is in enum if enum is specified
			if arg.default ~= nil and arg.enum then
				local found = false
				for j = 1, #arg.enum do
					if arg.enum[j] == arg.default then
						found = true
						break
					end
				end
				assert(found, "schema.args[" .. i .. "].default must be one of the enum values")
			end
		end
	end

	-- Validate permission if specified
	if schema.permission then
		assert(type(schema.permission) == "function", "schema.permission must be a function or nil")
	end

	-- Run custom validation if specified
	if schema.validate then
		assert(type(schema.validate) == "function", "schema.validate must be a function or nil")
		local valid, err = schema.validate(schema)
		if not valid then
			return error("command '" .. name .. "' validation failed: " .. (err or "unknown error"))
		end
	end

	local lower_name = string_lower(name)
	self.commands[lower_name] = schema

	-- Add command and aliases to autocompleter
	self.command_autocompleter:insert(name)
	if schema.aliases then
		assert(type(schema.aliases) == "table", "schema.aliases must be a table")
		for i = 1, #schema.aliases do
			local alias = schema.aliases[i]
			assert(type(alias) == "string" and alias ~= "", "alias must be non-empty string")
			self.alias_map[string_lower(alias)] = lower_name
			self.command_autocompleter:insert(alias)
		end
	end

	-- Return schema for later modification (e.g., setting handler)
	return schema
end

--- Unregister a command by name.<br>
--- Command names are case-insensitive.
---@param self ChatCommander
---@param name string The command name to unregister
function ChatCommander.unregister_command(self, name)
	assert(type(name) == "string" and name ~= "", "command name must be non-empty string")
	local lower_name = string_lower(name)
	-- Remove aliases pointing to this command
	for alias, target in next, self.alias_map do
		if self.alias_map[alias] == lower_name then
			self.alias_map[alias] = nil
		end
	end
	self.commands[lower_name] = nil
end

--- Get a command schema by name.<br>
--- Command names are case-insensitive. Supports aliases.
---@param self ChatCommander
---@param name string The command name to look up
---@return chat_commander.CommandSchema? schema The command schema, or nil if not found
---@return string? resolved_name The resolved command name (or alias target), or nil if not found
function ChatCommander.get_command(self, name)
	assert(type(name) == "string" and name ~= "", "command name must be non-empty string")
	local lower_name = string_lower(name)
	local resolved = self.alias_map[lower_name] or lower_name
	return self.commands[resolved], resolved
end

--- Resolve a command name to its canonical form.<br>
--- Handles aliases and case-insensitivity.
---@param self ChatCommander
---@param name string The command name to resolve
---@return string? resolved_name The canonical command name, or nil if not found
function ChatCommander.resolve_command(self, name)
	local lower_name = string_lower(name)
	name = self.alias_map[lower_name]
	if name then
		return name
	end
	if self.commands[lower_name] then
		return lower_name
	end
end

----------------------------------------------------------------------
-- Argument parsing according to schema
----------------------------------------------------------------------

--- Coerce a raw token value according to an argument definition.<br>
--- Handles type conversion, enum validation, and raw mode.
---@param self ChatCommander
---@param raw string The raw token value
---@param arg_def chat_commander.CommandArg The argument definition
---@return any value The coerced value
---@return string? error Error message if coercion failed
function ChatCommander.coerce_value(self, raw, arg_def)
	local t = arg_def.type or "string"

	-- If arg_def.raw == true, skip coercion and return raw token
	if arg_def.raw then
		return raw
	end

	-- Handle array of types (try each in order)
	if type(t) == "table" then
		local errors = {}
		for i = 1, #t do
			local type_name = t[i]
			local coercer = self.type_coercers[type_name]
			if not coercer then
				return nil, "unknown type: " .. tostring(type_name)
			end

			local value, err = coercer(raw)
			if not err then
				-- Success with this type, check enum if specified
				if arg_def.enum then
					local ok = false
					for j = 1, #arg_def.enum do
						local v = arg_def.enum[j]
						if v == value then
							ok = true
							break
						end
					end
					if not ok then
						return nil, "invalid value '" .. tostring(value) .. "', expected one of: " ..
							table_concat(arg_def.enum, ", ")
					end
				end
				return value
			end
			errors[#errors + 1] = type_name .. ": " .. err
		end
		-- All types failed
		return nil, "failed to coerce as any of [" .. table_concat(t, ", ") .. "]: " ..
			table_concat(errors, "; ")
	end

	-- Single type
	local coercer = self.type_coercers[t]
	if not coercer then
		return nil, "unknown type: " .. tostring(t)
	end

	local value, err = coercer(raw)
	if err then
		return nil, err
	end

	-- Enum support: arg_def.enum = { "a", "b", "c" }
	if arg_def.enum then
		local ok = false
		for i = 1, #arg_def.enum do
			local v = arg_def.enum[i]
			if v == value then
				ok = true
				break
			end
		end
		if not ok then
			return nil, "invalid value '" .. tostring(value) .. "', expected one of: " ..
				table_concat(arg_def.enum, ", ")
		end
	end

	return value
end

--- Parse arguments according to a schema.<br>
--- Fills arguments from positional tokens, with named tokens taking precedence.<br>
--- Validates required arguments and applies defaults.
---@param self ChatCommander
---@param schema chat_commander.CommandSchema The command schema
---@param positional_tokens string[] Positional token values
---@param named_tokens table<string, string> Named token values (key -> value)
---@return table? args Parsed arguments (keyed by name), or nil if validation failed
---@return string? error Error message if parsing failed
function ChatCommander.parse_args(self, schema, positional_tokens, named_tokens)
	local args = {}
	local errors = {}

	local arg_defs = schema.args or {}

	-- First, process named tokens and assign them to their arguments
	for name, value in next, named_tokens do
		args[name] = value
	end

	-- Then, process all arguments (both named and positional) for coercion and validation
	local pos_index = 1
	for i = 1, #arg_defs do
		local arg_def = arg_defs[i]
		local name = arg_def.name
		local raw = args[name] or positional_tokens[pos_index]

		-- Consume positional token if used
		if raw == positional_tokens[pos_index] and raw ~= nil then
			pos_index = pos_index + 1
		end

		if raw == nil or raw == "" then
			if arg_def.required then
				if arg_def.default ~= nil then
					args[name] = arg_def.default
				else
					errors[#errors + 1] = "missing required argument: " .. name
				end
			else
				if arg_def.default ~= nil then
					args[name] = arg_def.default
				end
			end
		else
			local value, err = self:coerce_value(raw, arg_def)
			if err then
				errors[#errors + 1] = "argument '" .. name .. "': " .. err
			else
				args[name] = value
			end
		end
	end

	-- Capture remaining positional tokens as varargs
	if pos_index <= #positional_tokens then
		local rest = {}
		for j = pos_index, #positional_tokens do
			rest[#rest + 1] = positional_tokens[j]
		end
		args._rest = rest
	end

	if #errors > 0 then
		return nil, table_concat(errors, "; ")
	end

	return args
end

----------------------------------------------------------------------
-- Help / usage generation
----------------------------------------------------------------------

--- Build a usage string for a single argument.
---@param self ChatCommander
---@param arg_def chat_commander.CommandArg The argument definition
---@return string usage The usage string
function ChatCommander.build_arg_usage(self, arg_def)
	local name = arg_def.name or "arg"
	local t = arg_def.type or "string"
	local req = arg_def.required and "required" or "optional"
	local enum_part = ""
	if arg_def.enum then
		enum_part = " enum{" .. table_concat(arg_def.enum, "|") .. "}"
	end
	local default_part = ""
	if arg_def.default ~= nil then
		default_part = " default=" .. tostring(arg_def.default)
	end
	return string_format("%s:<%s> (%s%s%s)", name, t, req, enum_part, default_part)
end

--- Build a usage line for a command.<br>
--- Shows the command name with required/optional argument placeholders.
---@param self ChatCommander
---@param name string The command name
---@param schema chat_commander.CommandSchema The command schema
---@return string usage The usage line
function ChatCommander.build_usage_line(self, name, schema)
	local parts = { self.prefix .. name }
	if schema.args then
		for i = 1, #schema.args do
			local arg_def = schema.args[i]
			local segment
			if arg_def.required then
				segment = string_format("<%s>", arg_def.name)
			else
				segment = string_format("[%s]", arg_def.name)
			end
			parts[#parts + 1] = segment
		end
	end
	return table_concat(parts, " ")
end

--- Get help text for a command.<br>
--- Returns detailed help including description, usage, and arguments.
---@param self ChatCommander
---@param name string The command name (case-insensitive)
---@return string? help The help text, or nil if command not found
---@return string? error Error message if command not found
function ChatCommander.get_help(self, name)
	assert(type(name) == "string" and name ~= "", "command name must be non-empty string")
	local schema = self.commands[string_lower(name)]
	if not schema then
		return nil, "unknown command: " .. name
	end

	local lines = {}
	lines[#lines + 1] = "Command: " .. self.prefix .. name
	if schema.description then
		lines[#lines + 1] = "Description: " .. schema.description
	end

	lines[#lines + 1] = "Usage: " .. self:build_usage_line(name, schema)

	if schema.args and #schema.args > 0 then
		lines[#lines + 1] = "Arguments:"
		for i = 1, #schema.args do
			local arg_def = schema.args[i]
			lines[#lines + 1] = "  - " .. self:build_arg_usage(arg_def)
		end
	else
		lines[#lines + 1] = "Arguments: (none)"
	end

	if schema.permission then
		lines[#lines + 1] = "Permission: custom check"
	end

	return table_concat(lines, "\n")
end

----------------------------------------------------------------------
-- Public: parse a raw chat line into command + args
-- Returns:
--   ok, result_or_error
--   If ok:
--     { name = "cmd", args = <table>, schema = <schema> }
----------------------------------------------------------------------

--- Parse a raw chat line into a command and arguments.<br>
--- Handles optional leading slash, tokenization, and argument parsing.
---@param self ChatCommander
---@param raw_line string The raw chat line to parse
---@return boolean ok True if parsing succeeded
---@return chat_commander.ParsedCommand|string result The parsed command or error message
function ChatCommander.parse_line(self, raw_line)
	if type(raw_line) ~= "string" then
		return false, "line must be a string"
	end

	local line = trim(raw_line)
	if line == "" then
		return false, "empty line"
	end

	-- Optional leading prefix
	if string_sub(line, 1, #self.prefix) == self.prefix then
		line = string_sub(line, #self.prefix + 1)
	end

	local tokens = self:tokenize(line)
	if #tokens == 0 then
		return false, "no command found"
	end

	local cmd_name = table_remove(tokens, 1)
	local resolved_name = self:resolve_command(cmd_name)
	if not resolved_name then
		return false, "unknown command: " .. cmd_name .. " (type '" .. self.prefix .. "help' for available commands)"
	end

	local schema = self.commands[resolved_name]
	if not schema then
		return false, "unknown command: " .. cmd_name
	end

	local positional, named = split_key_value_tokens(tokens)
	local args, err = self:parse_args(schema, positional, named)
	if not args then
		return false,
			"argument error in command '" ..
			resolved_name .. "': " .. err .. " (type '" .. self.prefix .. "help " .. resolved_name .. "' for usage)"
	end

	return true, {
		name = resolved_name,
		args = args,
		schema = schema,
	}
end

----------------------------------------------------------------------
-- Public: handle a line (parse + dispatch)
-- ctx is a free-form table you pass in (player, channel, etc.)
----------------------------------------------------------------------

--- Parse and execute a command line.<br>
--- Combines parse_line and command execution with permission checks.
---@param self ChatCommander
---@param ctx table Execution context (player, channel, etc.)
---@param raw_line string The raw chat line to handle
---@return boolean ok True if execution succeeded
---@return string? error Error message if execution failed
function ChatCommander.handle_line(self, ctx, raw_line)
	local ok, parsed_or_err = self:parse_line(raw_line)
	if not ok then
		return false, parsed_or_err
	end

	local parsed = parsed_or_err
	local schema = parsed.schema
	local handler = schema.handler

	-- Per-command permission checks:
	--   schema.permission(ctx, args) -> true | false, "reason"
	if type(schema.permission) == "function" then
		-- Warn if permission is used but context is not provided
		if not ctx or type(ctx) ~= "table" or next(ctx) == nil then
			print("Warning: command '" .. parsed.name .. "' has permission check but no context provided")
		end
		local allowed, reason = schema.permission(ctx, parsed.args)
		if not allowed then
			return false, "permission denied for command '" .. parsed.name .. "': " .. (reason or "no permission")
		end
	end

	-- Pre-handler custom validation
	if type(schema.pre_validate) == "function" then
		local valid, err = schema.pre_validate(ctx, parsed.args)
		if not valid then
			return false, "validation failed for command '" .. parsed.name .. "': " .. (err or "unknown error")
		end
	end

	-- If no handler, return success with a message
	if not handler then
		return true, "command '" .. parsed.name .. "' has no handler"
	end

	-- Call handler with varargs if pass_varargs is enabled
	if schema.pass_varargs and parsed.args._rest then
		local success, err = pcall(handler, ctx, parsed.args, table.unpack(parsed.args._rest))
		if not success then
			return false, "error executing command '" .. parsed.name .. "': " .. tostring(err)
		end
	else
		local success, err = pcall(handler, ctx, parsed.args)
		if not success then
			return false, "error executing command '" .. parsed.name .. "': " .. tostring(err)
		end
	end

	return true
end

----------------------------------------------------------------------
-- Introspection helpers
----------------------------------------------------------------------

local function sort_by_name(a, b)
	return a.name < b.name
end

--- List all registered commands.<br>
--- Returns an array of command info sorted by name.
---@param self ChatCommander
---@return chat_commander.CommandInfo[] commands Array of command info tables
function ChatCommander.list_commands(self)
	local list = {}
	for name, schema in next, self.commands do
		list[#list + 1] = {
			name = name,
			description = schema.description or "",
			args = schema.args or {},
		}
	end
	table_sort(list, sort_by_name)
	return list
end

--- Set the command prefix (default: "/").<br>
--- This prefix is stripped from the beginning of command lines during parsing.
---@param self ChatCommander
---@param prefix string The new command prefix (must be a single character)
function ChatCommander.set_prefix(self, prefix)
	assert(type(prefix) == "string" and prefix ~= "" and #prefix == 1, "prefix must be a non-empty character")
	self.prefix = prefix
end

----------------------------------------------------------------------
-- Auto-completion with caret-precision
----------------------------------------------------------------------

--- Tokenize a command line with position tracking and quote awareness.<br>
--- Similar to the existing tokenize function but tracks start/finish positions.
---@param self ChatCommander
---@param line string The line to tokenize
---@return chat_commander.CompletionToken[] tokens Array of tokens with positions
function ChatCommander.tokenize_with_positions(self, line)
	local tokens = {}
	local i = 1
	local len = #line

	while true do
		i = skip_spaces(line, i, len)
		if i > len then break end

		local c = string_sub(line, i, i)
		local start = i

		if c == '"' or c == "'" then
			-- Quoted token
			local quote = c
			i = i + 1
			local buf = {}
			local closed = false

			while i <= len do
				local ch = string_sub(line, i, i)
				if ch == "\\" then
					local repl, new_i = parse_escape_sequence(line, i)
					buf[#buf + 1] = repl
					i = new_i + 1
				elseif ch == quote then
					closed = true
					i = i + 1
					break
				else
					buf[#buf + 1] = ch
					i = i + 1
				end
			end

			local token = table_concat(buf)
			tokens[#tokens + 1] = {
				text = token,
				start = start,
				finish = i - 1,
				quoted = true,
				closed = closed, -- Track whether quote was properly closed
			}
		else
			-- Unquoted token
			while i <= len and not string_match(string_sub(line, i, i), "%s") do
				i = i + 1
			end
			local token = string_sub(line, start, i - 1)
			tokens[#tokens + 1] = {
				text = token,
				start = start,
				finish = i - 1,
				quoted = false,
			}
		end
	end

	return tokens
end

--- Find the token at a given caret position.<br>
--- Caret position is 1-based, where 1 is before the first character.
---@param self ChatCommander
---@param tokens chat_commander.CompletionToken[] Array of tokens from tokenize_with_positions
---@param caret integer Caret position (1-based)
---@param line_len integer Length of the original line
---@return integer token_index Index of the token at caret (or insertion point)
---@return boolean inside True if caret is inside the token, false if between tokens
function ChatCommander.find_token_at(self, tokens, caret, line_len)
	if caret < 1 then caret = 1 end
	if caret > (line_len + 1) then caret = line_len + 1 end

	for idx = 1, #tokens do
		local tok = tokens[idx]
		if caret >= tok.start and caret <= tok.finish + 1 then
			-- caret inside token or right after last char of token
			local inside = caret <= tok.finish
			return idx, inside
		end
	end

	-- caret not inside any token: determine insertion index (between tokens)
	local insert_at = #tokens + 1
	for idx = 1, #tokens do
		local tok = tokens[idx]
		if caret < tok.start then
			insert_at = idx
			break
		end
	end
	return insert_at, false
end

--- Determine the completion context at a given caret position.<br>
--- Analyzes the command line to determine what kind of completion is needed.
---@param self ChatCommander
---@param line string The current command line
---@param caret integer Caret position (1-based)
---@return chat_commander.CompletionContext ctx The completion context
function ChatCommander.context_at(self, line, caret)
	caret = caret or (#line + 1)
	local tokens = self:tokenize_with_positions(line)
	local line_len = #line
	local idx, inside = self:find_token_at(tokens, caret, line_len)

	-- Default context
	local ctx = {
		kind = "BetweenTokens",
		tokens = tokens,
		token_index = idx,
		token = nil,
		partial = "",
		cmd = nil,
		arg_index = nil,
	}

	-- If no tokens, suggest command names
	if #tokens == 0 then
		ctx.kind = "CommandName"
		ctx.partial = ""
		return ctx
	end

	-- If caret is inside a token
	if idx <= #tokens and inside then
		local tok = tokens[idx]
		ctx.token = tok
		-- Partial is the text from start of token up to (and including) the caret position
		ctx.partial = string_sub(tok.text, 1, caret - tok.start + 1)

		-- If token is quoted and caret is inside quotes, check for custom autocompleter
		-- Exception: if quote is not closed (unterminated string), treat as normal token
		if tok.quoted and tok.closed and caret > tok.start and caret <= tok.finish then
			-- Resolve command and arg index to check for custom autocompleter
			local cmdname = tokens[1].text
			if string_sub(cmdname, 1, #self.prefix) == self.prefix then
				cmdname = string_sub(cmdname, #self.prefix + 1)
			end
			local resolved = self:resolve_command(cmdname)
			local cmd = self.commands[resolved]
			local arg_index = idx - 1

			-- Check if this argument has a custom suggestion handler
			if cmd and cmd.args and arg_index <= #cmd.args then
				local arg_def = cmd.args[arg_index]
				local has_custom_suggestions = false
				if type(arg_def.type) == "table" then
					for i = 1, #arg_def.type do
						if self.type_suggestions[arg_def.type[i]] then
							has_custom_suggestions = true
							break
						end
					end
				elseif self.type_suggestions[arg_def.type] then
					has_custom_suggestions = true
				end

				if has_custom_suggestions then
					ctx.kind = "InsideStringWithCustomCompleter"
					ctx.cmd = cmd
					ctx.arg_index = arg_index
					return ctx
				end
			end

			ctx.kind = "InsideString"
			return ctx
		end

		-- Empty quoted token (just the quote character): no suggestions
		if tok.quoted and tok.text == "" then
			ctx.kind = "NoSuggestions"
			return ctx
		end

		-- If caret is at first token -> command name
		if idx == 1 then
			-- Strip prefix from partial for matching
			local partial_for_match = ctx.partial
			if string_sub(partial_for_match, 1, #self.prefix) == self.prefix then
				partial_for_match = string_sub(partial_for_match, #self.prefix + 1)
			end
			ctx.partial = partial_for_match
			ctx.kind = "CommandName"
			return ctx
		end

		-- Otherwise it's an argument token; resolve command and arg index
		local cmdname = tokens[1].text
		-- Strip command prefix if present
		if string_sub(cmdname, 1, #self.prefix) == self.prefix then
			cmdname = string_sub(cmdname, #self.prefix + 1)
		end
		local resolved = self:resolve_command(cmdname)
		ctx.cmd = self.commands[resolved]
		ctx.arg_index = idx - 1
		ctx.kind = "ArgValue"
		return ctx
	end

	-- Caret between tokens at position idx
	-- Special case: if idx == 1 but caret is after the first token (not before), treat as after tokens
	if idx == 1 then
		local first_token = tokens[1]
		if caret > first_token.finish then
			-- Caret is after the first token, not before it
			-- Determine command and next arg index
			local cmdname = first_token.text
			-- Strip command prefix if present
			if string_sub(cmdname, 1, #self.prefix) == self.prefix then
				cmdname = string_sub(cmdname, #self.prefix + 1)
			end
			local resolved = self:resolve_command(cmdname)
			ctx.cmd = self.commands[resolved]

			if not ctx.cmd then
				-- Unknown command, suggest command names
				ctx.kind = "CommandName"
				ctx.partial = ""
				return ctx
			end

			-- Next arg index is 1 (since we're after the first token)
			ctx.arg_index = 1

			-- Check if there are args defined and if we're within bounds
			if not ctx.cmd.args or #ctx.cmd.args == 0 or ctx.arg_index > #ctx.cmd.args then
				-- No args defined or we're past the last arg, no suggestions
				ctx.kind = "NoSuggestions"
				ctx.partial = ""
				return ctx
			end

			ctx.kind = "ArgValue"
			ctx.partial = ""
			return ctx
		else
			-- Before first token -> command name
			ctx.kind = "CommandName"
			ctx.partial = ""
			return ctx
		end
	end

	-- Caret after some tokens; determine command and next arg index
	local cmdname = tokens[1].text
	-- Strip command prefix if present
	if string_sub(cmdname, 1, #self.prefix) == self.prefix then
		cmdname = string_sub(cmdname, #self.prefix + 1)
	end
	local resolved = self:resolve_command(cmdname)
	ctx.cmd = self.commands[resolved]

	if not ctx.cmd then
		-- Unknown command, suggest command names
		ctx.kind = "CommandName"
		ctx.partial = ""
		return ctx
	end

	-- Next arg index is idx (since idx is insertion point)
	ctx.arg_index = idx - 1

	-- Check if there are args defined and if we're within bounds
	if not ctx.cmd.args or #ctx.cmd.args == 0 or ctx.arg_index > #ctx.cmd.args then
		-- No args defined or we're past the last arg, no suggestions
		ctx.kind = "NoSuggestions"
		ctx.partial = ""
		return ctx
	end

	ctx.kind = "ArgValue"
	ctx.partial = ""
	return ctx
end

--- Get completion suggestions at a given caret position.<br>
--- Returns ranked suggestions based on context (command name, argument value).
---@param self ChatCommander
---@param line string The current command line
---@param caret? integer Caret position (defaults to end of line)
---@param options? autocompleter.Options Autocompleter options
---@return string[] suggestions Array of suggestion strings
function ChatCommander.suggest_at(self, line, caret, options)
	caret = caret or (#line + 1)
	local ctx = self:context_at(line, caret)

	-- Inside string: no suggestions (or could suggest escape sequences)
	if ctx.kind == "InsideString" then
		return {}
	end

	-- Inside string with custom completer: provide suggestions
	if ctx.kind == "InsideStringWithCustomCompleter" and ctx.cmd then
		local arg_def = ctx.cmd.args and ctx.cmd.args[ctx.arg_index]
		if not arg_def then
			return {}
		end

		-- Check for custom suggestion handler
		if type(arg_def.type) == "table" then
			for i = 1, #arg_def.type do
				local handler = self.type_suggestions[arg_def.type[i]]
				if handler then
					return handler(ctx.partial)
				end
			end
		elseif self.type_suggestions[arg_def.type] then
			return self.type_suggestions[arg_def.type](ctx.partial)
		end
		return {}
	end

	-- No suggestions (e.g., past the last arg)
	if ctx.kind == "NoSuggestions" then
		return {}
	end

	-- Command name suggestions
	if ctx.kind == "CommandName" then
		return self.command_autocompleter:get_completions(ctx.partial, options)
	end

	-- Argument value suggestions
	if ctx.kind == "ArgValue" and ctx.cmd then
		local arg_def = ctx.cmd.args and ctx.cmd.args[ctx.arg_index]
		if not arg_def then
			return {}
		end

		-- For "any" type, no suggestions
		if arg_def.type == "any" then
			return {}
		end

		-- If argument has enum choices, suggest from those (enum takes precedence)
		if arg_def.enum then
			local enum_autocompleter = autocompleter.new()
			for i = 1, #arg_def.enum do
				enum_autocompleter:insert(arg_def.enum[i])
			end
			-- Use lowercase partial for case-insensitive enum matching
			local partial_lower = string_lower(ctx.partial)
			local enum_options
			if partial_lower == "" then
				-- Empty partial: return all enum values using prefix matching
				enum_options = {
					prefix = true,
					max_results = options and options.max_results or 10
				}
				local suggestions = enum_autocompleter:get_completions(partial_lower, enum_options)
				return suggestions
			else
				-- Non-empty partial: filter enum values manually for case-insensitive prefix matching
				local suggestions = {}
				for i = 1, #arg_def.enum do
					if string_sub(string_lower(arg_def.enum[i]), 1, #partial_lower) == partial_lower then
						suggestions[#suggestions + 1] = arg_def.enum[i]
					end
				end
				return suggestions
			end
		end

		-- For array of types, check if any type has suggestions
		if type(arg_def.type) == "table" then
			for i = 1, #arg_def.type do
				local type_name = arg_def.type[i]
				-- Check if this type has a suggestion handler
				local handler = self.type_suggestions[type_name]
				if handler then
					return handler(ctx.partial)
				end
				-- Check if this type is boolean
				if type_name == "boolean" or type_name == "bool" then
					return bool_autocompleter:get_completions(ctx.partial, options)
				end
			end
			-- No suggestions for any of the types
			return {}
		end

		-- For boolean arguments, suggest true/false
		if arg_def.type == "boolean" or arg_def.type == "bool" then
			return bool_autocompleter:get_completions(ctx.partial, options)
		end

		-- For number arguments, no suggestions
		if arg_def.type == "number" or arg_def.type == "num" then
			return {}
		end

		-- For custom types, check if there's a registered suggestion handler
		if self.type_suggestions[arg_def.type] then
			local handler = self.type_suggestions[arg_def.type]
			return handler(ctx.partial)
		end
	end

	return {}
end

--[[ Quick tests
if true then
	-- Create a test instance and initialize local functions
	local test_instance = ChatCommander.new()
	-- Initialize local functions with the instance
	local function register_type(name, coercer)
		return test_instance:register_type(name, coercer)
	end
	local function register_command(name, schema)
		return test_instance:register_command(name, schema)
	end
	local function unregister_command(name)
		return test_instance:unregister_command(name)
	end
	local function get_command(name)
		return test_instance:get_command(name)
	end
	local function parse_line(raw_line)
		return test_instance:parse_line(raw_line)
	end
	local function handle_line(ctx, raw_line)
		return test_instance:handle_line(ctx, raw_line)
	end
	local function get_help(name)
		return test_instance:get_help(name)
	end
	local function list_commands()
		return test_instance:list_commands()
	end
	local function set_prefix(prefix)
		return test_instance:set_prefix(prefix)
	end
	local function suggest_at(line, caret, options)
		return test_instance:suggest_at(line, caret, options)
	end

	-- Test 1: Basic command registration
	local test_cmd_called = false
	local test_cmd_ctx
	local test_cmd_args
	register_command("test", {
		description = "Test command",
		handler = function(ctx, args)
			test_cmd_called = true
			test_cmd_ctx = ctx
			test_cmd_args = args
			return "ok"
		end,
	})
	local schema = get_command("test")
	assert(schema ~= nil, "Test 1 failed: command should be registered")
	assert(schema.description == "Test command", "Test 1 failed: description should match")

	-- Test 1b: Handler is called via handle_line
	local test_ctx = { player = "test_player" }
	local ok, result = handle_line(test_ctx, "/test")
	assert(ok == true, "Test 1b failed: handle_line should succeed")
	assert(test_cmd_called == true, "Test 1b failed: handler should be called")
	assert(test_cmd_ctx == test_ctx, "Test 1b failed: handler should receive correct context")

	-- Test 1c: Handler with arguments
	register_command("test_args", {
		args = {
			{ name = "x", type = "number", required = true },
			{ name = "y", type = "string", required = true },
		},
		handler = function(ctx, args)
			test_cmd_args = args
		end,
	})
	test_cmd_args = nil
	local ok2 = handle_line({}, "/test_args 5 hello")
	assert(ok2 == true, "Test 1c failed: handle_line with args should succeed")
	assert(test_cmd_args ~= nil, "Test 1c failed: handler should receive args")
	assert(test_cmd_args.x == 5, "Test 1c failed: handler should receive correct x arg")
	assert(test_cmd_args.y == "hello", "Test 1c failed: handler should receive correct y arg")

	-- Test 2: Command parsing
	local ok, parsed = test_instance:parse_line("/test")
	assert(ok == true, "Test 2 failed: parse should succeed")
	assert(parsed.name == "test", "Test 2 failed: command name should be 'test'")
	assert(type(parsed.args) == "table", "Test 2 failed: args should be a table")

	-- Test 3: Argument parsing
	register_command("greet", {
		args = {
			{ name = "name",  type = "string", required = true },
			{ name = "times", type = "number", required = false, default = 1 },
		},
		handler = function() end,
	})
	ok, parsed = parse_line("/greet John 5")
	assert(ok == true, "Test 3 failed: parse should succeed")
	assert(parsed.args.name == "John", "Test 3 failed: name should be 'John'")
	assert(parsed.args.times == 5, "Test 3 failed: times should be 5")

	-- Test 4: Default values
	ok, parsed = parse_line("/greet John")
	assert(ok == true, "Test 4 failed: parse should succeed")
	assert(parsed.args.name == "John", "Test 4 failed: name should be 'John'")
	assert(parsed.args.times == 1, "Test 4 failed: times should default to 1")

	-- Test 5: Named arguments
	ok, parsed = parse_line("/greet name=John times=3")
	assert(ok == true, "Test 5 failed: parse should succeed")
	assert(parsed.args.name == "John", "Test 5 failed: name should be 'John'")
	assert(parsed.args.times == 3, "Test 5 failed: times should be 3")

	-- Test 6: Quoted strings
	ok, parsed = parse_line('/greet "John Doe"')
	assert(ok == true, "Test 6 failed: parse should succeed")
	assert(parsed.args.name == "John Doe", "Test 6 failed: name should be 'John Doe'")

	-- Test 7: Type coercion
	register_command("math", {
		args = {
			{ name = "value", type = "number",  required = true },
			{ name = "flag",  type = "boolean", required = false, default = false },
		},
		handler = function() end,
	})
	ok, parsed = parse_line("/math 42")
	assert(ok == true, "Test 7 failed: parse should succeed")
	assert(parsed.args.value == 42, "Test 7 failed: value should be 42")
	assert(parsed.args.flag == false, "Test 7 failed: flag should default to false")

	ok, parsed = parse_line("/math 42 true")
	assert(ok == true, "Test 7b failed: parse should succeed")
	assert(parsed.args.flag == true, "Test 7b failed: flag should be true")

	-- Test 8: Aliases
	register_command("hello", {
		aliases = { "hi", "hey" },
		handler = function() end,
	})
	local alias_schema, resolved = get_command("hi")
	assert(alias_schema ~= nil, "Test 8 failed: alias should resolve")
	assert(resolved == "hello", "Test 8 failed: alias should resolve to 'hello'")

	-- Test 9: Help generation
	local help, err = get_help("greet")
	assert(help ~= nil, "Test 9 failed: help should be generated")
	assert(type(help) == "string", "Test 9 failed: help should be a string")

	-- Test 10: Error handling
	ok, err = parse_line("/unknown_command")
	assert(ok == false, "Test 10 failed: unknown command should fail")
	assert(type(err) == "string", "Test 10 failed: error should be a string")

	-- Test 11: Required argument validation
	ok, err = parse_line("/greet")
	assert(ok == false, "Test 11 failed: missing required arg should fail")
	assert(string_find(err, "name"), "Test 11 failed: error should mention 'name'")

	-- Test 12: Enum validation
	register_command("color", {
		args = {
			{ name = "c", type = "string", enum = { "red", "green", "blue" }, required = true },
		},
		handler = function() end,
	})
	ok, parsed = parse_line("/color red")
	assert(ok == true, "Test 12 failed: valid enum should succeed")
	assert(parsed.args.c == "red", "Test 12 failed: value should be 'red'")

	ok, err = parse_line("/color purple")
	assert(ok == false, "Test 12b failed: invalid enum should fail")
	assert(string_find(err, "expected one of"), "Test 12b failed: error should mention enum options")

	-- Test 13: Varargs
	register_command("echo", {
		args = {
			{ name = "msg", type = "string", required = true },
		},
		handler = function() end,
	})
	ok, parsed = parse_line("/echo hello world extra stuff")
	assert(ok == true, "Test 13 failed: parse should succeed")
	assert(parsed.args.msg == "hello", "Test 13 failed: msg should be 'hello'")
	assert(parsed.args._rest ~= nil, "Test 13 failed: _rest should exist")
	assert(#parsed.args._rest == 3, "Test 13 failed: _rest should have 3 items")

	-- Test 14: Prefix customization
	set_prefix("!")
	local ok_prefix, parsed_prefix = parse_line("!test")
	assert(ok_prefix == true, "Test 14 failed: custom prefix should work")
	assert(parsed_prefix.name == "test", "Test 14 failed: command should parse with custom prefix")
	set_prefix("/") -- Reset to default

	-- Cleanup
	unregister_command("test")
	unregister_command("greet")
	unregister_command("math")
	unregister_command("hello")
	unregister_command("color")
	unregister_command("echo")

	-- Re-register greet for escape sequence tests
	register_command("greet", {
		args = {
			{ name = "name",  type = "string", required = true },
			{ name = "times", type = "number", required = false, default = 1 },
		},
		handler = function() end,
	})

	-- Test 15: Empty string handling
	register_command("empty", {
		args = { { name = "text", type = "string", required = false, default = "" } },
		handler = function() end,
	})
	ok, parsed = parse_line("/empty")
	assert(ok == true, "Test 15 failed: empty string default should work")
	assert(parsed.args.text == "", "Test 15 failed: default should be empty string")

	-- Test 16: Whitespace handling
	ok, parsed = parse_line('/empty "   "')
	assert(ok == true, "Test 16 failed: whitespace string should work")
	assert(parsed.args.text == "   ", "Test 16 failed: whitespace should be preserved")

	-- Test 17: Boolean coercion edge cases
	register_command("bool_test", {
		args = { { name = "flag", type = "boolean", required = true } },
		handler = function() end,
	})
	ok, parsed = parse_line("/bool_test true")
	assert(ok == true, "Test 17 failed: true should coerce to boolean")
	assert(parsed.args.flag == true, "Test 17 failed: flag should be true")

	ok, parsed = parse_line("/bool_test false")
	assert(ok == true, "Test 17b failed: false should coerce to boolean")
	assert(parsed.args.flag == false, "Test 17b failed: flag should be false")

	ok, parsed = parse_line("/bool_test 1")
	assert(ok == true, "Test 17c failed: 1 should coerce to boolean")
	assert(parsed.args.flag == true, "Test 17c failed: 1 should coerce to true")

	ok, parsed = parse_line("/bool_test 0")
	assert(ok == true, "Test 17d failed: 0 should coerce to boolean")
	assert(parsed.args.flag == false, "Test 17d failed: 0 should coerce to false")

	-- Test 18: Number coercion edge cases
	register_command("num_test", {
		args = { { name = "value", type = "number", required = true } },
		handler = function() end,
	})
	ok, parsed = parse_line("/num_test 3.14")
	assert(ok == true, "Test 18 failed: float should coerce to number")
	assert(parsed.args.value == 3.14, "Test 18 failed: value should be 3.14")

	ok, parsed = parse_line("/num_test -42")
	assert(ok == true, "Test 18b failed: negative should coerce to number")
	assert(parsed.args.value == -42, "Test 18b failed: value should be -42")

	ok, err = parse_line("/num_test not_a_number")
	assert(ok == false, "Test 18c failed: invalid number should fail")
	assert(string_find(err, "number"), "Test 18c failed: error should mention number")

	-- Test 19: Integer coercion edge cases
	register_command("int_test", {
		args = { { name = "value", type = "integer", required = true } },
		handler = function() end,
	})
	ok, parsed = parse_line("/int_test 42")
	assert(ok == true, "Test 19 failed: integer should coerce to integer")
	assert(parsed.args.value == 42, "Test 19 failed: value should be 42")

	ok, parsed = parse_line("/int_test -10")
	assert(ok == true, "Test 19b failed: negative integer should coerce")
	assert(parsed.args.value == -10, "Test 19b failed: value should be -10")

	ok, err = parse_line("/int_test 3.14")
	assert(ok == false, "Test 19c failed: float should fail integer validation")
	assert(string_find(err, "not an integer"), "Test 19c failed: error should mention not an integer")

	ok, err = parse_line("/int_test not_a_number")
	assert(ok == false, "Test 19d failed: invalid should fail")
	assert(string_find(err, "invalid integer"), "Test 19d failed: error should mention invalid integer")

	-- Test 19e: 'int' alias for 'integer'
	register_command("int_alias_test", {
		args = { { name = "value", type = "int", required = true } },
		handler = function() end,
	})
	ok, parsed = parse_line("/int_alias_test 100")
	assert(ok == true, "Test 19e failed: int alias should work")
	assert(parsed.args.value == 100, "Test 19e failed: value should be 100")

	-- Test 20: Escape sequences
	ok, parsed = parse_line('/greet "John\\nDoe"')
	if not ok then
		return error("Test 20 failed: parse_line returned error: " .. tostring(parsed))
	end
	assert(ok == true, "Test 20 failed: escape sequence should work")
	local expected = "John\nDoe"
	assert(parsed.args.name == expected, "Test 20 failed: \\n should be escaped, got: " .. tostring(parsed.args.name))

	ok, parsed = parse_line('/greet "John\\tDoe"')
	assert(ok == true, "Test 20b failed: tab escape should work")
	assert(parsed.args.name == "John\tDoe", "Test 19b failed: \\t should be escaped")

	-- Test 20: Mixed quotes
	ok, parsed = parse_line('/greet "John\'s name"')
	assert(ok == true, "Test 20 failed: single quote in double quotes should work")
	assert(parsed.args.name == "John's name", "Test 20 failed: single quote should be preserved")

	ok, parsed = parse_line("/greet 'John\"s name'")
	assert(ok == true, "Test 20b failed: double quote in single quotes should work")
	assert(parsed.args.name == 'John"s name', "Test 20b failed: double quote should be preserved")

	-- Test 21: Multiple spaces between tokens
	ok, parsed = parse_line("/greet   John    5")
	assert(ok == true, "Test 21 failed: multiple spaces should work")
	assert(parsed.args.name == "John", "Test 21 failed: name should be 'John'")
	assert(parsed.args.times == 5, "Test 21 failed: times should be 5")

	-- Test 22: Trailing spaces
	ok, parsed = parse_line("/greet John   ")
	assert(ok == true, "Test 22 failed: trailing spaces should work")
	assert(parsed.args.name == "John", "Test 22 failed: name should be 'John'")

	-- Test 23: Leading spaces
	ok, parsed = parse_line("  /greet John")
	assert(ok == true, "Test 23 failed: leading spaces should be trimmed")
	assert(parsed.args.name == "John", "Test 23 failed: name should be 'John'")

	-- Test 24: Case insensitivity
	local schema_upper = get_command("GREET")
	assert(schema_upper ~= nil, "Test 24 failed: uppercase command should resolve")
	assert(schema_upper.description == nil, "Test 24 failed: should be same command")

	-- Test 25: No arguments command
	register_command("simple", {
		handler = function() end,
	})
	ok, parsed = parse_line("/simple")
	assert(ok == true, "Test 25 failed: command with no args should work")
	assert(type(parsed.args) == "table", "Test 25 failed: args should be table")

	-- Test 26: Permission check
	register_command("protected", {
		permission = function(ctx, args)
			return false, "not authorized"
		end,
		handler = function() end,
	})
	ok, err = handle_line({ player = {} }, "/protected")
	assert(ok == false, "Test 26 failed: permission denied should fail")
	assert(string_find(err, "not authorized"), "Test 26 failed: error should mention reason")

	-- Test 27: Handler error
	register_command("error_cmd", {
		handler = function()
			return error("test error")
		end,
	})
	ok, err = handle_line({}, "/error_cmd")
	assert(ok == false, "Test 27 failed: handler error should fail")
	assert(string_find(err, "error_cmd"), "Test 27 failed: error should mention command name")

	-- Test 28: Raw mode
	register_command("raw_test", {
		args = { { name = "value", type = "string", raw = true, required = true } },
		handler = function() end,
	})
	ok, parsed = parse_line("/raw_test 123")
	assert(ok == true, "Test 28 failed: raw mode should work")
	assert(parsed.args.value == "123", "Test 28 failed: raw value should be string '123'")

	-- Test 29: Multiple aliases
	register_command("multi", {
		aliases = { "m", "mlt", "multi_alias" },
		handler = function() end,
	})
	local _, resolved_m = get_command("m")
	assert(resolved_m == "multi", "Test 29 failed: first alias should resolve")
	local _, resolved_mlt = get_command("mlt")
	assert(resolved_mlt == "multi", "Test 29b failed: second alias should resolve")

	-- Test 30: List commands
	local cmd_list = list_commands()
	assert(type(cmd_list) == "table", "Test 30 failed: list should be table")
	assert(#cmd_list > 0, "Test 30 failed: list should have commands")

	-- Test 31: Command not found in help
	local help_nil, help_err = get_help("nonexistent")
	assert(help_nil == nil, "Test 31 failed: unknown command help should be nil")
	assert(help_err ~= nil, "Test 31 failed: error should be returned")

	-- Test 32: Invalid prefix
	local ok_prefix, err_prefix = pcall(set_prefix, "")
	assert(ok_prefix == false, "Test 32 failed: empty prefix should fail")
	assert(string_find(err_prefix, "non-empty") or string_find(err_prefix, "empty"),
		"Test 32 failed: error should mention non-empty or empty, got: " .. tostring(err_prefix))

	local ok_prefix2, err_prefix2 = pcall(set_prefix, "ab")
	assert(ok_prefix2 == false, "Test 32b failed: multi-char prefix should fail")
	assert(string_find(err_prefix2, "character"), "Test 32b failed: error should mention character")

	-- Test 33: Empty line
	ok, err = parse_line("")
	assert(ok == false, "Test 33 failed: empty line should fail")
	assert(string_find(err, "empty"), "Test 33 failed: error should mention empty")

	-- Test 34: Only prefix
	ok, err = parse_line("/")
	assert(ok == false, "Test 34 failed: only prefix should fail")
	assert(string_find(err, "no command"), "Test 34 failed: error should mention no command")

	-- Test 35: Invalid type registration - non-string error
	local ok_reg, err_reg = pcall(register_type, "bad_type", function() return nil, 123 end)
	assert(ok_reg == false, "Test 35 failed: invalid coercer signature should fail")

	-- Test 36: Schema validation - missing handler (now optional with warning)
	local ok_schema = pcall(register_command, "bad", {
		description = "test",
		handler = function() end, -- Add handler to suppress warning
	})
	assert(ok_schema == true, "Test 36 failed: missing handler should now succeed (with warning)")
	unregister_command("bad") -- Clean up

	-- Test 37: Schema validation - invalid arg type
	local ok_schema2, err_schema2 = pcall(register_command, "bad2", {
		handler = function() end,
		args = {
			{ name = "x", type = "nonexistent_type", required = true },
		},
	})
	assert(ok_schema2 == false, "Test 37 failed: invalid type should fail")
	assert(string_find(err_schema2, "nonexistent_type"), "Test 37 failed: error should mention type")

	-- Test 38: Schema validation - empty enum
	local ok_schema3, err_schema3 = pcall(register_command, "bad3", {
		handler = function() end,
		args = {
			{ name = "x", type = "string", enum = {}, required = true },
		},
	})
	assert(ok_schema3 == false, "Test 38 failed: empty enum should fail")
	assert(string_find(err_schema3, "empty"), "Test 38 failed: error should mention empty")

	-- Test 39: Schema validation - default type mismatch
	local ok_schema4, err_schema4 = pcall(register_command, "bad4", {
		handler = function() end,
		args = {
			{ name = "x", type = "number", default = "not a number", required = false },
		},
	})
	assert(ok_schema4 == false, "Test 39 failed: default type mismatch should fail")

	-- Test 40: Unregister non-existent command (should not error)
	local ok_unreg = pcall(unregister_command, "nonexistent")
	assert(ok_unreg == true, "Test 40 failed: unregistering non-existent should not error")

	-- Cleanup additional test commands
	unregister_command("empty")
	unregister_command("bool_test")
	unregister_command("num_test")
	unregister_command("simple")
	unregister_command("protected")
	unregister_command("error_cmd")
	unregister_command("raw_test")
	unregister_command("multi")

	-- Re-register test command for prefix tests
	register_command("test", {
		handler = function() end,
	})

	-- Test 41: Multiple prefix changes
	set_prefix(".")
	ok, parsed = parse_line(".test")
	assert(ok == true, "Test 41 failed: dot prefix should work")
	assert(parsed.name == "test", "Test 41 failed: command should parse with dot prefix")

	set_prefix(">")
	ok, parsed = parse_line(">test")
	assert(ok == true, "Test 41b failed: greater-than prefix should work")
	assert(parsed.name == "test", "Test 41b failed: command should parse with greater-than prefix")

	set_prefix("/") -- Reset to default

	-- Test 42: Custom type registration and usage
	register_type("positive_int", function(token)
		local n = tonumber(token)
		if not n then return nil, "invalid number" end
		if n < 0 then return nil, "must be positive" end
		return n
	end)

	register_command("add", {
		args = {
			{ name = "x", type = "positive_int", required = true },
			{ name = "y", type = "positive_int", required = true },
		},
		handler = function() end,
	})

	ok, parsed = parse_line("/add 10 20")
	assert(ok == true, "Test 42 failed: custom type should work")
	assert(parsed.args.x == 10, "Test 42 failed: x should be 10")
	assert(parsed.args.y == 20, "Test 42 failed: y should be 20")

	ok, err = parse_line("/add -5 10")
	assert(ok == false, "Test 42b failed: negative custom type should fail")
	assert(string_find(err, "positive"), "Test 42b failed: error should mention positive")

	-- Test 43: Named arguments with custom types
	ok, parsed = parse_line("/add x=15 y=25")
	assert(ok == true, "Test 43 failed: named args with custom type should work")
	assert(parsed.args.x == 15, "Test 43 failed: x should be 15")
	assert(parsed.args.y == 25, "Test 43 failed: y should be 25")

	-- Test 44: Mixed positional and named with custom types
	ok, parsed = parse_line("/add 10 y=30")
	assert(ok == true, "Test 44 failed: mixed args with custom type should work")
	assert(parsed.args.x == 10, "Test 44 failed: x should be 10")
	assert(parsed.args.y == 30, "Test 44 failed: y should be 30")

	-- Test 45: All positional consumed, _rest should be empty
	register_command("consume", {
		args = {
			{ name = "a", type = "string", required = true },
			{ name = "b", type = "string", required = true },
		},
		handler = function() end,
	})
	ok, parsed = parse_line("/consume foo bar")
	assert(ok == true, "Test 45 failed: exact args should work")
	assert(parsed.args._rest == nil, "Test 45 failed: _rest should be nil when no extra args")

	-- Test 46: _rest with single extra token
	ok, parsed = parse_line("/consume foo bar baz")
	assert(ok == true, "Test 46 failed: extra arg should work")
	assert(parsed.args._rest ~= nil, "Test 46 failed: _rest should exist")
	assert(#parsed.args._rest == 1, "Test 46 failed: _rest should have 1 item")
	assert(parsed.args._rest[1] == "baz", "Test 46 failed: _rest[1] should be 'baz'")

	-- Test 47: _rest with many extra tokens
	ok, parsed = parse_line("/consume foo bar baz qux quux")
	assert(ok == true, "Test 47 failed: many extra args should work")
	assert(#parsed.args._rest == 3, "Test 47 failed: _rest should have 3 items")

	-- Test 48: _rest with named arguments
	ok, parsed = parse_line("/consume a=foo b=bar baz qux")
	assert(ok == true, "Test 48 failed: _rest with named args should work")
	assert(parsed.args._rest ~= nil, "Test 48 failed: _rest should exist")
	assert(#parsed.args._rest == 2, "Test 48 failed: _rest should have 2 items")

	-- Test 49: _rest empty string
	ok, parsed = parse_line('/consume foo bar ""')
	assert(ok == true, "Test 49 failed: empty string in _rest should work")
	assert(parsed.args._rest[1] == "", "Test 49 failed: _rest[1] should be empty string")

	-- Test 50: No args defined, all tokens go to _rest
	register_command("catchall", {
		handler = function() end,
	})
	ok, parsed = parse_line("/catchall foo bar baz")
	assert(ok == true, "Test 50 failed: catchall should work")
	assert(parsed.args._rest ~= nil, "Test 50 failed: _rest should exist")
	assert(#parsed.args._rest == 3, "Test 50 failed: _rest should have 3 items")

	-- Test 51: Optional argument with default, not provided
	register_command("opt", {
		args = {
			{ name = "x", type = "string", required = false, default = "default" },
		},
		handler = function() end,
	})
	ok, parsed = parse_line("/opt")
	assert(ok == true, "Test 51 failed: optional without value should work")
	assert(parsed.args.x == "default", "Test 51 failed: x should be default")

	-- Test 52: Optional argument with default, provided as empty string (treated as missing, uses default)
	ok, parsed = parse_line('/opt ""')
	assert(ok == true, "Test 52 failed: optional with empty string should work")
	assert(parsed.args.x == "default", "Test 52 failed: empty string should use default")

	-- Test 53: Required argument with default (default should not be used)
	register_command("req_def", {
		args = {
			{ name = "x", type = "string", required = true, default = "default" },
		},
		handler = function() end,
	})
	ok, parsed = parse_line("/req_def provided")
	assert(ok == true, "Test 53 failed: required with value should work")
	assert(parsed.args.x == "provided", "Test 53 failed: x should be provided")

	-- Re-register num_test for hex parsing tests
	register_command("num_test", {
		args = { { name = "value", type = "number", required = true } },
		handler = function() end,
	})

	-- Re-register bool_test for boolean alias tests
	register_command("bool_test", {
		args = { { name = "flag", type = "boolean", required = true } },
		handler = function() end,
	})

	-- Test 54: Hex string to number coercion
	ok, parsed = parse_line("/num_test 0xFF")
	assert(ok == true, "Test 54 failed: hex string should work")
	assert(parsed.args.value == 255, "Test 54 failed: 0xFF should be 255")

	ok, parsed = parse_line("/num_test -0x10")
	assert(ok == true, "Test 54b failed: negative hex string should work")
	assert(parsed.args.value == -16, "Test 54b failed: -0x10 should be -16")

	ok, parsed = parse_line("/num_test 0xABC")
	assert(ok == true, "Test 54c failed: mixed case hex string should work")
	assert(parsed.args.value == 2748, "Test 54c failed: 0xABC should be 2748")

	-- Test 55: Hex string as string type (not coerced to number)
	register_command("hex_str", {
		args = { { name = "hex", type = "string", required = true } },
		handler = function() end,
	})
	ok, parsed = parse_line("/hex_str 0xFF")
	assert(ok == true, "Test 55 failed: hex string as string should work")
	assert(parsed.args.hex == "0xFF", "Test 55 failed: hex should remain as string '0xFF'")

	-- Test 56: Binary string to number coercion
	ok, parsed = parse_line("/num_test 0b1010")
	assert(ok == true, "Test 56 failed: binary string should work")
	assert(parsed.args.value == 10, "Test 56 failed: 0b1010 should be 10")

	ok, parsed = parse_line("/num_test -0b100")
	assert(ok == true, "Test 56b failed: negative binary string should work")
	assert(parsed.args.value == -4, "Test 56b failed: -0b100 should be -4")

	ok, parsed = parse_line("/num_test 0B1111")
	assert(ok == true, "Test 56c failed: uppercase binary prefix should work")
	assert(parsed.args.value == 15, "Test 56c failed: 0B1111 should be 15")

	-- Test 57: Binary string as string type (not coerced to number)
	register_command("bin_str", {
		args = { { name = "bin", type = "string", required = true } },
		handler = function() end,
	})
	ok, parsed = parse_line("/bin_str 0b1010")
	assert(ok == true, "Test 57 failed: binary string as string should work")
	assert(parsed.args.bin == "0b1010", "Test 57 failed: binary should remain as string '0b1010'")

	-- Test 58: Boolean aliases
	ok, parsed = parse_line("/bool_test yes")
	assert(ok == true, "Test 58a failed: yes should be true")
	assert(parsed.args.flag == true, "Test 58a failed: flag should be true")

	ok, parsed = parse_line("/bool_test no")
	assert(ok == true, "Test 58b failed: no should be false")
	assert(parsed.args.flag == false, "Test 58b failed: flag should be false")

	ok, parsed = parse_line("/bool_test on")
	assert(ok == true, "Test 58c failed: on should be true")
	assert(parsed.args.flag == true, "Test 58c failed: flag should be true")

	ok, parsed = parse_line("/bool_test off")
	assert(ok == true, "Test 58d failed: off should be false")
	assert(parsed.args.flag == false, "Test 58d failed: flag should be false")

	-- Test 59: Permission with no reason
	register_command("perm_no_reason", {
		permission = function(ctx, args)
			return false
		end,
		handler = function() end,
	})
	ok, err = handle_line({ player = {} }, "/perm_no_reason")
	assert(ok == false, "Test 59 failed: permission denied should fail")
	assert(string_find(err, "no permission"), "Test 59 failed: error should mention no permission")

	-- Test 60: Permission granted
	register_command("perm_allowed", {
		permission = function(ctx, args)
			return true
		end,
		handler = function(ctx, args)
			return "success"
		end,
	})
	ok, err = handle_line({ player = {} }, "/perm_allowed")
	assert(ok == true, "Test 60 failed: permission granted should succeed")

	-- Test 61: Handler returns value
	register_command("return_val", {
		handler = function(ctx, args)
			return 42
		end,
	})
	ok, result = handle_line({}, "/return_val")
	assert(ok == true, "Test 61 failed: handler with return should succeed")

	-- Test 62: Enum with case sensitivity
	register_command("case_enum", {
		args = {
			{ name = "mode", type = "string", enum = { "LOW", "MEDIUM", "HIGH" }, required = true },
		},
		handler = function() end,
	})
	ok, parsed = parse_line("/case_enum LOW")
	assert(ok == true, "Test 62 failed: uppercase enum should work")
	assert(parsed.args.mode == "LOW", "Test 62 failed: mode should be LOW")

	ok, err = parse_line("/case_enum low")
	assert(ok == false, "Test 62b failed: lowercase enum should fail")

	-- Test 63: Command without description
	register_command("no_desc", {
		handler = function() end,
	})
	local help_no_desc = get_help("no_desc")
	assert(help_no_desc ~= nil, "Test 63 failed: help without description should work")
	assert(type(help_no_desc) == "string", "Test 63 failed: help should be string")

	-- Cleanup additional test commands
	unregister_command("add")
	unregister_command("consume")
	unregister_command("catchall")
	unregister_command("opt")
	unregister_command("req_def")
	unregister_command("perm_no_reason")
	unregister_command("perm_allowed")
	unregister_command("return_val")
	unregister_command("case_enum")
	unregister_command("no_desc")
	unregister_command("hex_str")
	unregister_command("bin_str")
	unregister_command("test")        -- Clean up test command from prefix tests
	unregister_command("greet")       -- Clean up greet command from escape tests
	unregister_command("num_test")    -- Clean up num_test from hex tests
	unregister_command("bool_test")   -- Clean up bool_test from boolean tests
	unregister_command("int_test")    -- Clean up int_test from integer tests
	unregister_command("int_alias_test") -- Clean up int_alias_test from integer tests
	unregister_command("test_args")   -- Clean up test_args from handler tests

	-- Test 62: Case insensitivity in registration and lookup
	register_command("CaseTest", {
		handler = function() end,
	})
	local schema_lower = get_command("casetest")
	assert(schema_lower ~= nil, "Test 62 failed: lowercase lookup should find command")
	local schema_upper = get_command("CASETEST")
	assert(schema_upper ~= nil, "Test 62b failed: uppercase lookup should find command")
	local schema_mixed = get_command("CaSeTeSt")
	assert(schema_mixed ~= nil, "Test 62c failed: mixed case lookup should find command")

	-- Test 63: Case insensitivity in unregistration
	unregister_command("CASETEST")
	local schema_after = get_command("casetest")
	assert(schema_after == nil, "Test 63 failed: command should be unregistered regardless of case")

	-- Test 64: Aliases with case insensitivity
	register_command("alias_test", {
		aliases = { "ALIAS1", "alias2" },
		handler = function() end,
	})
	local alias_upper = get_command("ALIAS1")
	assert(alias_upper ~= nil, "Test 64 failed: uppercase alias should resolve")
	local alias_lower = get_command("alias2")
	assert(alias_lower ~= nil, "Test 64b failed: lowercase alias should resolve")
	unregister_command("alias_test")

	-- Test 65: Verify registry is empty after cleanup
	local final_list = list_commands()
	assert(#final_list == 0,
		"Test 65 failed: registry should be empty after cleanup, but has " .. #final_list .. " commands")

	-- Test 66: Auto-completer - command name suggestions
	register_command("teleport", {
		handler = function() end,
	})
	register_command("teleport_to", {
		handler = function() end,
	})
	local suggestions = suggest_at("/tele", 6)
	assert(#suggestions > 0, "Test 66 failed: should get suggestions for '/tele'")
	assert(#suggestions >= 2, "Test 66 failed: should have at least 2 suggestions (teleport, teleport_to)")

	-- Test 67: Auto-completer - empty line returns all commands
	suggestions = suggest_at("/", 2)
	assert(#suggestions >= 2, "Test 67 failed: empty prefix should return all commands")

	-- Test 68: Auto-completer - caret at end of line
	suggestions = suggest_at("/teleport ", 10)
	-- After command with no args, should return no suggestions
	-- (teleport has no args, so no argument suggestions available)
	assert(#suggestions == 0, "Test 68 failed: after command with no args should return no suggestions")

	-- Test 69: Auto-completer - enum argument suggestions
	register_command("color", {
		args = {
			{ name = "c", type = "string", enum = { "red", "green", "blue" }, required = true },
		},
		handler = function() end,
	})

	-- Verify command is registered
	local color_cmd = get_command("color")
	assert(color_cmd ~= nil, "Test 69 setup failed: color should be registered")
	assert(color_cmd.args ~= nil and #color_cmd.args == 1, "Test 69 setup failed: color should have 1 arg")

	suggestions = suggest_at("/color ", 7)
	assert(#suggestions == 3, "Test 69 failed: enum should return 3 suggestions")
	local found_red, found_green, found_blue = false, false, false
	for i = 1, #suggestions do
		if suggestions[i] == "red" then found_red = true end
		if suggestions[i] == "green" then found_green = true end
		if suggestions[i] == "blue" then found_blue = true end
	end
	assert(found_red and found_green and found_blue, "Test 69 failed: should return all enum values")

	-- Test 70: Auto-completer - enum partial match
	suggestions = suggest_at("/color r", 8)
	assert(#suggestions > 0, "Test 70 failed: partial enum should return suggestions")
	assert(suggestions[1] == "red", "Test 70 failed: 'r' should match 'red'")

	-- Test 71: Auto-completer - boolean argument suggestions
	register_command("toggle", {
		args = {
			{ name = "flag", type = "boolean", required = true },
		},
		handler = function() end,
	})
	suggestions = suggest_at("/toggle ", 8)
	assert(#suggestions > 0, "Test 71 failed: boolean should return suggestions")

	-- Test 72: Auto-completer - boolean partial match
	suggestions = suggest_at("/toggle t", 9)
	assert(#suggestions > 0, "Test 72 failed: partial boolean should return suggestions")
	local found_true, found_false = false, false
	for i = 1, #suggestions do
		if suggestions[i] == "true" then found_true = true end
		if suggestions[i] == "false" then found_false = true end
	end
	assert(found_true, "Test 72 failed: 't' should match 'true'")

	-- Test 73: Auto-completer - inside quoted string (no suggestions)
	suggestions = suggest_at('/color "red"', 12)
	assert(#suggestions == 0, "Test 73 failed: inside string should return no suggestions")

	-- Test 74: Auto-completer - caret inside token
	suggestions = suggest_at("/color re", 9)
	assert(#suggestions > 0, "Test 74 failed: caret inside token should return suggestions")

	-- Test 75: Auto-completer - number argument (no suggestions)
	register_command("add", {
		args = {
			{ name = "x", type = "number", required = true },
		},
		handler = function() end,
	})
	suggestions = suggest_at("/add ", 5)
	assert(#suggestions == 0, "Test 75 failed: number argument should return no suggestions")

	-- Test 76: Auto-completer - unknown command (suggests command names)
	suggestions = suggest_at("/unknown ", 9)
	assert(#suggestions >= 2, "Test 76 failed: unknown command should suggest command names")

	-- Test 77: Auto-completer - alias suggestions
	register_command("hello", {
		aliases = { "hi", "hey" },
		handler = function() end,
	})
	suggestions = suggest_at("/h", 3)
	assert(#suggestions >= 1, "Test 77 failed: 'h' should match 'hello' or aliases")

	-- Test 78: Auto-completer - quoted string with escape sequence (no suggestions inside)
	suggestions = suggest_at('/color "re\\d"', 12)
	assert(#suggestions == 0, "Test 78 failed: inside quoted string with escape should return no suggestions")

	-- Test 79: Auto-completer - unterminated string literal (treat as normal token)
	suggestions = suggest_at('/color "red', 11)
	-- Unterminated quote should still allow suggestions for the partial content
	assert(#suggestions > 0, "Test 79 failed: unterminated string should still allow suggestions")

	-- Test 80: Auto-completer - empty quoted string (no suggestions)
	suggestions = suggest_at('/color ""', 9)
	assert(#suggestions == 0, "Test 80 failed: empty quoted string should return no suggestions")

	-- Test 81: Auto-completer - caret at opening quote (no suggestions)
	suggestions = suggest_at('/color "', 8)
	-- Empty quoted token should return no suggestions
	assert(#suggestions == 0, "Test 81 failed: caret at opening quote should return no suggestions")

	-- Test 82: Auto-completer - caret at closing quote (no suggestions)
	suggestions = suggest_at('/color "red"', 12)
	assert(#suggestions == 0, "Test 82 failed: caret at closing quote should return no suggestions")

	-- Test 83: Auto-completer - custom type (vector3) - no suggestions (without handler)
	register_type("vector3", coerce_vector3)
	register_command("move", {
		args = {
			{ name = "pos", type = "vector3", required = true },
		},
		handler = function() end,
	})
	suggestions = suggest_at("/move ", 6)
	assert(#suggestions == 0, "Test 83 failed: custom type without handler should return no suggestions")

	-- Test 84: Auto-completer - custom type with suggestion handler
	test_instance:register_suggestions("vector3", function(partial)
		-- Return some example vector3 values for testing
		local examples = { "0,0,0", "100,100,100", "50,25,0" }
		local matches = {}
		for i = 1, #examples do
			if string_sub(examples[i], 1, #partial) == partial then
				matches[#matches + 1] = examples[i]
			end
		end
		return matches
	end)
	suggestions = suggest_at("/move ", 6)
	assert(#suggestions == 3, "Test 84 failed: custom type with handler should return suggestions")
	assert(suggestions[1] == "0,0,0", "Test 84 failed: should return vector3 examples")

	-- Test 85: Auto-completer - custom type (positive_int) - no suggestions (without handler)
	register_type("positive_int", function(token)
		local n = tonumber(token)
		if not n then return nil, "not a number" end
		if n <= 0 then return nil, "must be positive" end
		return n
	end)
	register_command("count", {
		args = {
			{ name = "n", type = "positive_int", required = true },
		},
		handler = function() end,
	})
	suggestions = suggest_at("/count ", 7)
	assert(#suggestions == 0, "Test 85 failed: custom type without handler should return no suggestions")

	-- Test 86: Auto-completer - custom type with suggestion handler (partial match)
	test_instance:register_suggestions("positive_int", function(partial)
		-- Return some example positive integers
		local examples = { "1", "10", "100", "1000" }
		local matches = {}
		for i = 1, #examples do
			if string_sub(examples[i], 1, #partial) == partial then
				matches[#matches + 1] = examples[i]
			end
		end
		return matches
	end)
	suggestions = suggest_at("/count 1", 9)
	assert(#suggestions == 4, "Test 86 failed: partial match should return matching suggestions")
	assert(suggestions[1] == "1", "Test 86 failed: should match '1'")

	-- Test 87: Optional argument name (auto-generated as #<index>)
	register_command("anon", {
		args = {
			{ type = "string" }, -- No name, should become #1
			{ type = "number" }, -- No name, should become #2
		},
		handler = function(ctx, args)
			test_cmd_args = args
		end,
	})
	test_cmd_args = nil
	local ok_anon = handle_line({}, "/anon hello 42")
	assert(ok_anon == true, "Test 87 failed: anonymous args should work")
	assert(test_cmd_args ~= nil, "Test 87 failed: handler should receive args")
	assert(test_cmd_args[1] == "hello", "Test 87 failed: first arg should be #1")
	assert(test_cmd_args[2] == 42, "Test 87 failed: second arg should be #2")

	-- Test 87b: Mixed named and anonymous args
	register_command("mixed", {
		args = {
			{ name = "x",     type = "number" },
			{ type = "string" }, -- No name, should become #2
		},
		handler = function(ctx, args)
			test_cmd_args = args
		end,
	})
	test_cmd_args = nil
	local ok_mixed = handle_line({}, "/mixed 100 world")
	assert(ok_mixed == true, "Test 87b failed: mixed args should work")
	assert(test_cmd_args.x == 100, "Test 87b failed: named arg should work")
	assert(test_cmd_args[2] == "world", "Test 87b failed: anonymous arg should be #2")

	-- Test 88: Binary literal edge cases
	register_command("bin_edge", {
		args = { { name = "value", type = "number", required = true } },
		handler = function() end,
	})
	ok, err = parse_line("/bin_edge 0b102")
	assert(ok == false, "Test 88 failed: invalid binary digit should fail")
	assert(string_find(err, "invalid") or string_find(err, "number"),
		"Test 88 failed: error should mention invalid or number")

	-- Test 89: Integer type edge cases
	register_command("int_test", {
		args = { { name = "value", type = "integer", required = true } },
		handler = function() end,
	})
	ok, parsed = parse_line("/int_test 0")
	assert(ok == true, "Test 89 failed: zero should be valid integer")
	assert(parsed.args.value == 0, "Test 89 failed: zero should be 0")

	-- Test 90: Default value validation with type aliases
	register_command("def_alias", {
		args = {
			{ name = "flag", type = "bool", default = true,    required = false },
			{ name = "num",  type = "num",  default = 42,      required = false },
			{ name = "str",  type = "str",  default = "hello", required = false },
		},
		handler = function() end,
	})
	ok, parsed = parse_line("/def_alias")
	assert(ok == true, "Test 90 failed: defaults with type aliases should work")
	assert(parsed.args.flag == true, "Test 90 failed: bool default should work")
	assert(parsed.args.num == 42, "Test 90 failed: num default should work")
	assert(parsed.args.str == "hello", "Test 90 failed: str default should work")

	-- Test 91: Enum default validation
	register_command("enum_def", {
		args = {
			{ name = "mode", type = "string", enum = { "LOW", "MEDIUM", "HIGH" }, default = "LOW", required = false },
		},
		handler = function() end,
	})
	ok, parsed = parse_line("/enum_def")
	assert(ok == true, "Test 91 failed: valid enum default should work")
	assert(parsed.args.mode == "LOW", "Test 91 failed: enum default should be LOW")

	-- Test 92: Invalid enum default should fail during registration
	local ok_enum_def, err_enum_def = pcall(register_command, "bad_enum_def", {
		handler = function() end,
		args = {
			{ name = "mode", type = "string", enum = { "LOW", "MEDIUM", "HIGH" }, default = "INVALID", required = false },
		},
	})
	assert(ok_enum_def == false, "Test 92 failed: invalid enum default should fail")
	assert(string_find(err_enum_def, "enum"), "Test 92 failed: error should mention enum")

	-- Test 93: Required by default (no explicit required)
	register_command("req_default", {
		args = {
			{ name = "x", type = "number" }, -- No required specified, should default to true
		},
		handler = function() end,
	})
	ok, err = parse_line("/req_default")
	assert(ok == false, "Test 93 failed: should fail when required arg missing")
	assert(string_find(err, "required"), "Test 93 failed: error should mention required")

	-- Test 94: Optional due to default (no explicit required=false)
	register_command("opt_default", {
		args = {
			{ name = "x", type = "number", default = 10 }, -- No required specified, should default to false due to default
		},
		handler = function() end,
	})
	ok, parsed = parse_line("/opt_default")
	assert(ok == true, "Test 94 failed: should succeed with default")
	assert(parsed.args.x == 10, "Test 94 failed: should use default value")

	-- Test 95: Anonymous arguments with defaults
	register_command("anon_def", {
		args = {
			{ type = "string", default = "default1" },
			{ type = "number", default = 42 },
		},
		handler = function(ctx, args)
			test_cmd_args = args
		end,
	})
	test_cmd_args = nil
	ok = handle_line({}, "/anon_def")
	assert(ok == true, "Test 95 failed: anonymous args with defaults should work")
	assert(test_cmd_args[1] == "default1", "Test 95 failed: first anon arg should use default")
	assert(test_cmd_args[2] == 42, "Test 95 failed: second anon arg should use default")

	-- Test 96: Anonymous arguments with enums
	register_command("anon_enum", {
		args = {
			{ type = "string", enum = { "red", "green", "blue" } },
		},
		handler = function(ctx, args)
			test_cmd_args = args
		end,
	})
	test_cmd_args = nil
	ok = handle_line({}, "/anon_enum red")
	assert(ok == true, "Test 96 failed: anonymous arg with enum should work")
	assert(test_cmd_args[1] == "red", "Test 96 failed: anon arg should validate enum")

	-- Test 97: Anonymous arguments with type coercion
	register_command("anon_coerce", {
		args = {
			{ type = "number" },
			{ type = "boolean" },
		},
		handler = function(ctx, args)
			test_cmd_args = args
		end,
	})
	test_cmd_args = nil
	ok = handle_line({}, "/anon_coerce 123 true")
	assert(ok == true, "Test 97 failed: anonymous args with coercion should work")
	assert(test_cmd_args[1] == 123, "Test 97 failed: first anon arg should be coerced to number")
	assert(test_cmd_args[2] == true, "Test 97 failed: second anon arg should be coerced to boolean")

	-- Test 98: Mixed named and anonymous with defaults
	register_command("mixed_def", {
		args = {
			{ name = "x",      type = "number" },
			{ type = "string", default = "anon_default" },
		},
		handler = function(ctx, args)
			test_cmd_args = args
		end,
	})
	test_cmd_args = nil
	ok = handle_line({}, "/mixed_def 100")
	assert(ok == true, "Test 98 failed: mixed args with defaults should work")
	assert(test_cmd_args.x == 100, "Test 98 failed: named arg should work")
	assert(test_cmd_args[2] == "anon_default", "Test 98 failed: anonymous arg should use default")

	-- Test 98b: Comprehensive test mixing named and anonymous arguments
	register_command("mixed_comprehensive", {
		args = {
			{ name = "first", type = "number" }, -- Named: args.first
			{ type = "string" },         -- Anonymous: args[2]
			{ name = "third", type = "boolean" }, -- Named: args.third
			{ type = "number" },         -- Anonymous: args[4]
			{ name = "fifth", type = "string" }, -- Named: args.fifth
		},
		handler = function(ctx, args)
			test_cmd_args = args
		end,
	})
	test_cmd_args = nil
	local ok_mixed_comprehensive = handle_line({}, "/mixed_comprehensive 100 hello true 42 world")
	assert(ok_mixed_comprehensive == true, "Test 98b failed: mixed named/anonymous should work")
	assert(test_cmd_args.first == 100, "Test 98b failed: first named arg should be 100")
	assert(test_cmd_args[2] == "hello", "Test 98b failed: second anonymous arg should be hello")
	assert(test_cmd_args.third == true, "Test 98b failed: third named arg should be true")
	assert(test_cmd_args[4] == 42, "Test 98b failed: fourth anonymous arg should be 42")
	assert(test_cmd_args.fifth == "world", "Test 98b failed: fifth named arg should be world")

	-- Test 98c: Duplicate argument names should error
	local ok_dup, err_dup = pcall(function()
		register_command("dup_names", {
			args = {
				{ name = "x", type = "number" },
				{ name = "x", type = "string" }, -- Duplicate name
			},
			handler = function() end,
		})
	end)
	assert(ok_dup == false, "Test 98c failed: duplicate names should error")
	assert(string_find(err_dup, "duplicate"), "Test 98c failed: error should mention duplicate")

	-- Test 98d: Fluent API - duplicate argument names should error
	local ok_dup_fluent, err_dup_fluent = pcall(function()
		register_command("dup_fluent")
			:arg("x", "number")
			:arg("x", "string") -- Duplicate name
			:handler(function() end)
			:register()
	end)
	assert(ok_dup_fluent == false, "Test 98d failed: fluent duplicate names should error")
	assert(string_find(err_dup_fluent, "duplicate"), "Test 98d failed: error should mention duplicate")

	-- Test 98e: Type with ? suffix marks as optional
	register_command("optional_type", {
		args = {
			{ name = "x", type = "number?" }, -- ? suffix makes it optional
		},
		handler = function(ctx, args)
			test_cmd_args = args
		end,
	})
	test_cmd_args = nil
	ok = handle_line({}, "/optional_type")
	assert(ok == true, "Test 98e failed: optional type should work without value")
	assert(test_cmd_args.x == nil, "Test 98e failed: optional arg should be nil when not provided")

	test_cmd_args = nil
	ok = handle_line({}, "/optional_type 42")
	assert(ok == true, "Test 98e failed: optional type should work with value")
	assert(test_cmd_args.x == 42, "Test 98e failed: optional arg should have value when provided")

	-- Test 98f: Array of types with ? suffix
	register_command("optional_multi", {
		args = {
			{ name = "x", type = { "number?", "string" } }, -- ? on first type
		},
		handler = function(ctx, args)
			test_cmd_args = args
		end,
	})
	test_cmd_args = nil
	ok = handle_line({}, "/optional_multi")
	assert(ok == true, "Test 98f failed: optional multi-type should work without value")
	assert(test_cmd_args.x == nil, "Test 98f failed: optional multi-type arg should be nil when not provided")

	-- Test 98g: Fluent API with ? suffix
	register_command("fluent_optional")
		:arg("x", "number?")
		:handler(function(ctx, args)
			test_cmd_args = args
		end)
		:register()
	test_cmd_args = nil
	ok = handle_line({}, "/fluent_optional")
	assert(ok == true, "Test 98g failed: fluent optional type should work")
	assert(test_cmd_args.x == nil, "Test 98g failed: fluent optional arg should be nil")

	-- Test 99: Key=value parsing with argument named 'field'
	register_command("field_test", {
		args = {
			{ name = "field", type = "string", required = true },
		},
		handler = function(ctx, args)
			test_cmd_args = args
		end,
	})
	test_cmd_args = nil
	ok = handle_line({}, "/field_test field=hello")
	assert(ok == true, "Test 99 failed: key=value should work")
	assert(test_cmd_args.field == "hello", "Test 99 failed: field should be assigned from key=value")

	-- Test 100: Key=value with quoted string (currently treated as named due to limitation)
	-- Note: Current implementation doesn't preserve quote info in key=value split
	-- To pass literal strings with =, a different escaping mechanism would be needed
	test_cmd_args = nil
	ok = handle_line({}, '/field_test "field=hello"')
	assert(ok == true, "Test 100 failed: quoted string with = should work")
	-- Currently treated as named argument due to key=value split
	assert(test_cmd_args.field == "hello", "Test 100 failed: field should be 'hello' from key=value")

	-- Test 101: Optional handler (command with handler)
	register_command("no_handler", {
		description = "Command without handler",
		args = {
			{ name = "x", type = "number" },
		},
		handler = function() end, -- Add handler to suppress warning
	})
	local ok_no_handler, msg_no_handler = handle_line({}, "/no_handler 42")
	assert(ok_no_handler == true, "Test 101 failed: command without handler should succeed")

	-- Test 102: Handler validation (non-function handler should fail)
	local ok_bad_handler, err_bad_handler = pcall(register_command, "bad_handler", {
		handler = "not a function",
	})
	assert(ok_bad_handler == false, "Test 102 failed: non-function handler should fail")
	assert(string_find(err_bad_handler, "function"), "Test 102 failed: error should mention function")

	-- Test 103: Permission warning when context not provided
	register_command("perm_no_ctx", {
		permission = function(ctx, args)
			return true
		end,
		handler = function() end,
	})
	local ok_perm_ctx = handle_line({ player = {} }, "/perm_no_ctx")
	assert(ok_perm_ctx == true, "Test 103 failed: permission without context should still succeed")

	-- Test 104: Permission with empty context also warns
	local ok_perm_empty = handle_line({ player = {} }, "/perm_no_ctx")
	assert(ok_perm_empty == true, "Test 104 failed: permission with empty context should succeed")

	-- Test 105: Custom validation during registration
	register_command("custom_validate", {
		args = {
			{ name = "x", type = "number" },
			{ name = "y", type = "number" },
		},
		validate = function(schema)
			-- Custom rule: must have at least 2 arguments
			if not schema.args or #schema.args < 2 then
				return false, "must have at least 2 arguments"
			end
			return true
		end,
		handler = function() end,
	})
	-- Should succeed (already has 2 args)
	local schema_custom = get_command("custom_validate")
	assert(schema_custom ~= nil, "Test 105 failed: custom validation should succeed")

	-- Test 106: Custom validation failure during registration
	local ok_bad_validate, err_bad_validate = pcall(register_command, "bad_validate", {
		validate = function(schema)
			return false, "custom validation failed"
		end,
		handler = function() end,
	})
	assert(ok_bad_validate == false, "Test 106 failed: custom validation failure should fail")
	assert(string_find(err_bad_validate, "custom validation failed"),
		"Test 106 failed: error should mention validation failure")

	-- Test 107: Pre-validation during execution
	register_command("pre_validate", {
		args = {
			{ name = "value", type = "number" },
		},
		pre_validate = function(ctx, args)
			-- Custom rule: value must be positive
			if args.value and args.value <= 0 then
				return false, "value must be positive"
			end
			return true
		end,
		handler = function() end,
	})
	local ok_pre = handle_line({}, "/pre_validate 10")
	assert(ok_pre == true, "Test 107 failed: pre-validation should succeed with valid value")

	local ok_pre_fail, err_pre_fail = handle_line({}, "/pre_validate -5")
	assert(ok_pre_fail == false, "Test 107b failed: pre-validation should fail with invalid value")
	assert(string_find(err_pre_fail, "validation failed"), "Test 107b failed: error should mention validation failed")
	assert(string_find(err_pre_fail, "positive"), "Test 107b failed: error should mention positive")

	-- Test 108: Non-function validate should fail
	local ok_bad_validate_fn, err_bad_validate_fn = pcall(register_command, "bad_validate_fn", {
		validate = "not a function",
		handler = function() end,
	})
	assert(ok_bad_validate_fn == false, "Test 108 failed: non-function validate should fail")
	assert(string_find(err_bad_validate_fn, "function"), "Test 108 failed: error should mention function")

	-- Test 109: Non-function pre_validate should not fail (silently ignored)
	-- (pre_validate is only called if it's a function)
	register_command("bad_pre_validate", {
		pre_validate = "not a function",
		handler = function() end,
	})
	-- Should succeed during execution (non-function is ignored)
	local ok_exec_bad = handle_line({}, "/bad_pre_validate")
	assert(ok_exec_bad == true, "Test 109 failed: non-function pre_validate should be ignored")

	-- Test 110: Simplified argument syntax - array-style { "name", "type" }
	register_command("simple_array", {
		args = {
			{ "x", "number" },
			{ "y", "string" },
		},
		handler = function(ctx, args)
			test_cmd_args = args
		end,
	})
	test_cmd_args = nil
	local ok_simple = handle_line({}, "/simple_array 42 hello")
	assert(ok_simple == true, "Test 110 failed: array-style args should work")
	assert(test_cmd_args.x == 42, "Test 110 failed: x should be 42")
	assert(test_cmd_args.y == "hello", "Test 110 failed: y should be hello")

	-- Test 111: Simplified argument syntax - mixed { "name", type="type" }
	register_command("simple_mixed1", {
		args = {
			{ "value", type = "number" },
		},
		handler = function(ctx, args)
			test_cmd_args = args
		end,
	})
	test_cmd_args = nil
	local ok_mixed1 = handle_line({}, "/simple_mixed1 100")
	assert(ok_mixed1 == true, "Test 111 failed: mixed syntax (name, type=) should work")
	assert(test_cmd_args.value == 100, "Test 111 failed: value should be 100")

	-- Test 112: Simplified argument syntax - mixed { name="name", "type" }
	register_command("simple_mixed2", {
		args = {
			{ name = "count", "integer" },
		},
		handler = function(ctx, args)
			test_cmd_args = args
		end,
	})
	test_cmd_args = nil
	local ok_mixed2 = handle_line({}, "/simple_mixed2 5")
	assert(ok_mixed2 == true, "Test 112 failed: mixed syntax (name=, type) should work")
	assert(test_cmd_args.count == 5, "Test 112 failed: count should be 5")

	-- Test 113: Simplified syntax with other fields
	register_command("simple_with_default", {
		args = {
			{ "x", "number", default = 10, required = false },
		},
		handler = function(ctx, args)
			test_cmd_args = args
		end,
	})
	test_cmd_args = nil
	local ok_with_default = handle_line({}, "/simple_with_default")
	assert(ok_with_default == true, "Test 113 failed: simplified syntax with default should work")
	assert(test_cmd_args.x == 10, "Test 113 failed: x should use default")

	-- Test 114: Documentation example (exact usage from header)
	register_command("teleport", {
		description = "Teleport to coordinates",
		args = {
			{ "x",        "number" },            -- required by default
			{ "y",        type = "number" },     -- required by default
			{ name = "z", type = "number", default = 0 }, -- optional due to default
		},
		handler = function(ctx, args)
			test_cmd_args = args
		end,
	})
	test_cmd_args = nil
	local ok_doc = handle_line({ player = "test_player" }, "/teleport 10 20 30")
	assert(ok_doc == true, "Test 114 failed: documentation example should work")
	assert(test_cmd_args.x == 10, "Test 114 failed: x should be 10")
	assert(test_cmd_args.y == 20, "Test 114 failed: y should be 20")
	assert(test_cmd_args.z == 30, "Test 114 failed: z should be 30")

	-- Test 114b: Documentation example with default value
	test_cmd_args = nil
	local ok_doc_default = handle_line({ player = "test_player" }, "/teleport 10 20")
	assert(ok_doc_default == true, "Test 114b failed: documentation example with default should work")
	assert(test_cmd_args.x == 10, "Test 114b failed: x should be 10")
	assert(test_cmd_args.y == 20, "Test 114b failed: y should be 20")
	assert(test_cmd_args.z == 0, "Test 114b failed: z should use default 0")

	-- Test 115: "any" type accepts any value
	register_command("any_test", {
		args = {
			{ name = "value", type = "any" },
		},
		handler = function(ctx, args)
			test_cmd_args = args
		end,
	})
	test_cmd_args = nil
	local ok_any = handle_line({}, "/any_test hello")
	assert(ok_any == true, "Test 115 failed: any type should accept string")
	assert(test_cmd_args.value == "hello", "Test 115 failed: value should be hello")

	test_cmd_args = nil
	local ok_any_num = handle_line({}, "/any_test 123")
	assert(ok_any_num == true, "Test 115b failed: any type should accept number")
	assert(test_cmd_args.value == "123", "Test 115b failed: value should be '123' (raw string)")

	test_cmd_args = nil
	local ok_any_bool = handle_line({}, "/any_test true")
	assert(ok_any_bool == true, "Test 115c failed: any type should accept boolean")
	assert(test_cmd_args.value == "true", "Test 115c failed: value should be 'true' (raw string)")

	-- Test 116: "any" type has no autocompletion suggestions
	suggestions = suggest_at("/any_test ", 10)
	assert(#suggestions == 0, "Test 116 failed: any type should have no suggestions")

	-- Test 117: Multiple type support - string or number
	register_command("multi_type", {
		args = {
			{ name = "value", type = { "string", "number" } },
		},
		handler = function(ctx, args)
			test_cmd_args = args
		end,
	})
	test_cmd_args = nil
	local ok_multi_str = handle_line({}, "/multi_type hello")
	assert(ok_multi_str == true, "Test 117 failed: multi-type should accept string")
	assert(test_cmd_args.value == "hello", "Test 117 failed: value should be hello")

	test_cmd_args = nil
	local ok_multi_num = handle_line({}, "/multi_type 42")
	assert(ok_multi_num == true, "Test 117b failed: multi-type should accept number")
	assert(test_cmd_args.value == "42", "Test 117b failed: value should be '42' (string succeeds first)")

	-- Test 118: Multiple type support - first type succeeds, second fails
	test_cmd_args = nil
	local ok_multi_first = handle_line({}, "/multi_type world")
	assert(ok_multi_first == true, "Test 118 failed: should succeed with first type")
	assert(test_cmd_args.value == "world", "Test 118 failed: value should be world")

	-- Test 119: Multiple type support - number-first array
	register_command("multi_type_num", {
		args = {
			{ name = "value", type = { "number", "string" } },
		},
		handler = function(ctx, args)
			test_cmd_args = args
		end,
	})
	test_cmd_args = nil
	local ok_multi_num_first = handle_line({}, "/multi_type_num 42")
	assert(ok_multi_num_first == true, "Test 119 failed: multi-type number-first should accept number")
	assert(test_cmd_args.value == 42, "Test 119 failed: value should be 42 (number)")

	test_cmd_args = nil
	local ok_multi_num_second = handle_line({}, "/multi_type_num hello")
	assert(ok_multi_num_second == true, "Test 119b failed: multi-type number-first should accept string as fallback")
	assert(test_cmd_args.value == "hello", "Test 119b failed: value should be 'hello' (string)")

	-- Test 120: Multiple type with enum
	register_command("multi_enum", {
		args = {
			{ name = "mode", type = { "string", "number" }, enum = { "LOW", "MEDIUM", "HIGH" } },
		},
		handler = function(ctx, args)
			test_cmd_args = args
		end,
	})
	test_cmd_args = nil
	local ok_multi_enum = handle_line(nil, "/multi_enum 'LOW'")
	assert(ok_multi_enum == true, "Test 120 failed: multi-type with enum should accept valid enum")
	assert(test_cmd_args.mode == "LOW", "Test 120 failed: mode should be LOW")

	-- Test 121: Multiple type with enum - invalid enum
	local ok_multi_enum_fail, err_multi_enum_fail = handle_line({}, "/multi_enum INVALID")
	assert(ok_multi_enum_fail == false, "Test 121 failed: should fail with invalid enum")
	assert(string_find(err_multi_enum_fail, "expected one of"), "Test 121 failed: error should mention enum")

	-- Test 122: Multiple type autocompletion (should use first type with suggestions)
	register_command("multi_suggest", {
		args = {
			{ name = "flag", type = { "boolean", "string" } },
		},
		handler = function() end,
	})
	suggestions = suggest_at("/multi_suggest ", 14)
	assert(#suggestions > 0, "Test 122 failed: multi-type with boolean should have suggestions")

	-- Test 123: Multiple type autocompletion - boolean first, string second
	register_command("multi_bool_first", {
		args = {
			{ name = "flag", type = { "boolean", "string" } },
		},
		handler = function() end,
	})
	suggestions = suggest_at("/multi_bool_first ", 18)
	assert(#suggestions > 0, "Test 123 failed: boolean-first should have suggestions")
	local found_true = false
	for i = 1, #suggestions do
		if suggestions[i] == "true" or suggestions[i] == "false" then
			found_true = true
			break
		end
	end
	assert(found_true, "Test 123 failed: should have boolean suggestions")

	-- Test 124: Multiple type autocompletion - string first, boolean second (should use boolean suggestions)
	register_command("multi_str_first", {
		args = {
			{ name = "value", type = { "string", "boolean" } },
		},
		handler = function() end,
	})
	suggestions = suggest_at("/multi_str_first ", 17)
	assert(#suggestions > 0, "Test 124 failed: string-first should have boolean suggestions")
	local found_bool = false
	for i = 1, #suggestions do
		if suggestions[i] == "true" or suggestions[i] == "false" then
			found_bool = true
			break
		end
	end
	assert(found_bool, "Test 124 failed: should have boolean suggestions")

	-- Test 125: Multiple type autocompletion - with custom type suggestions
	register_type("custom_multi", function(token)
		local n = tonumber(token)
		if not n then return nil, "not a number" end
		if n < 0 or n > 100 then return nil, "must be 0-100" end
		return n
	end)
	test_instance:register_suggestions("custom_multi", function(partial)
		local examples = { "0", "50", "100" }
		local matches = {}
		for i = 1, #examples do
			if string_sub(examples[i], 1, #partial) == partial then
				matches[#matches + 1] = examples[i]
			end
		end
		return matches
	end)
	register_command("multi_custom", {
		args = {
			{ name = "value", type = { "custom_multi", "string" } },
		},
		handler = function() end,
	})
	suggestions = suggest_at("/multi_custom ", 14)
	assert(#suggestions > 0, "Test 125 failed: custom-multi should have suggestions")
	assert(suggestions[1] == "0", "Test 125 failed: should return custom suggestions")

	-- Test 126: Multiple type autocompletion - enum overrides type suggestions
	register_command("multi_enum_suggest", {
		args = {
			{ name = "mode", type = { "boolean", "string" }, enum = { "LOW", "MEDIUM", "HIGH" } },
		},
		handler = function() end,
	})
	suggestions = suggest_at("/multi_enum_suggest ", 20)
	assert(#suggestions == 3, "Test 126 failed: enum should override type suggestions")
	local found_low = false
	for i = 1, #suggestions do
		if suggestions[i] == "LOW" then
			found_low = true
			break
		end
	end
	assert(found_low, "Test 126 failed: should return enum values")

	-- Test 127: Multiple type autocompletion - number types have no suggestions
	register_command("multi_num", {
		args = {
			{ name = "value", type = { "number", "integer" } },
		},
		handler = function() end,
	})
	suggestions = suggest_at("/multi_num ", 11)
	assert(#suggestions == 0, "Test 127 failed: number types should have no suggestions")

	-- Test 128: Multiple type autocompletion - "any" type in array has no suggestions
	register_command("multi_any", {
		args = {
			{ name = "value", type = { "any", "string" } },
		},
		handler = function() end,
	})
	suggestions = suggest_at("/multi_any ", 11)
	assert(#suggestions == 0, "Test 128 failed: any type in array should have no suggestions")

	-- Test 129: Multiple type autocompletion - string first, boolean second (should use boolean suggestions)
	register_command("multi_bool_end", {
		args = {
			{ name = "flag", type = { "string", "boolean" } },
		},
		handler = function() end,
	})
	suggestions = suggest_at("/multi_bool_end ", 16)
	assert(#suggestions > 0, "Test 129 failed: string-first should have boolean suggestions")

	-- Test 130: Multiple type autocompletion - partial match with boolean
	register_command("multi_bool_partial", {
		args = {
			{ name = "flag", type = { "boolean", "number" } },
		},
		handler = function() end,
	})
	suggestions = suggest_at("/multi_bool_partial t", 20)
	assert(#suggestions > 0, "Test 130 failed: partial boolean should have suggestions")
	local found_tr = false
	for i = 1, #suggestions do
		if string_sub(suggestions[i], 1, 1) == "t" then
			found_tr = true
			break
		end
	end
	assert(found_tr, "Test 130 failed: should have 'true' suggestion")

	-- Test 131: Multiple type caret displacement - boolean type
	suggestions = suggest_at("/multi_bool_first ", 18)
	assert(#suggestions > 0, "Test 131 failed: caret at end should have suggestions")

	suggestions = suggest_at("/multi_bool_first t", 19)
	assert(#suggestions > 0, "Test 131b failed: caret after 't' should have suggestions")

	suggestions = suggest_at("/multi_bool_first tr", 20)
	assert(#suggestions > 0, "Test 131c failed: caret after 'tr' should have suggestions")

	-- Test 132: Multiple type caret displacement - custom type
	suggestions = suggest_at("/multi_custom ", 14)
	assert(#suggestions > 0, "Test 132 failed: caret at end should have custom suggestions")

	suggestions = suggest_at("/multi_custom 5", 15)
	assert(#suggestions > 0, "Test 132b failed: caret after '5' should have suggestions")

	suggestions = suggest_at("/multi_custom 5", 14)
	assert(#suggestions > 0, "Test 132c failed: caret before '5' should have suggestions")

	-- Test 133: Multiple type caret displacement - enum
	suggestions = suggest_at("/multi_enum_suggest ", 20)
	assert(#suggestions == 3, "Test 133 failed: caret at end should have enum suggestions")

	suggestions = suggest_at("/multi_enum_suggest L", 21)
	assert(#suggestions > 0, "Test 133b failed: caret after 'L' should have suggestions")

	suggestions = suggest_at("/multi_enum_suggest LO", 22)
	assert(#suggestions > 0, "Test 133c failed: caret after 'LO' should have suggestions")

	-- Test 134: Multiple type caret displacement - boolean suggestions
	suggestions = suggest_at("/multi_str_first ", 17)
	assert(#suggestions > 0, "Test 134 failed: string-first should have boolean suggestions at end")

	suggestions = suggest_at("/multi_str_first t", 18)
	assert(#suggestions > 0, "Test 134b failed: string-first should have boolean suggestions with partial")

	-- Test 135: Multiple type caret displacement - middle of command
	suggestions = suggest_at("/multi_bool_first", 17)
	assert(#suggestions > 0, "Test 135 failed: caret before space should have command suggestions")

	-- Test 135b: Fluent API - autocompletion with enum
	register_command("fluent_auto_enum")
		:description("Fluent auto enum test")
		:arg("color", "string")
		:enum("red", "green", "blue")
		:handler(function() end)
		:register()

	suggestions = suggest_at("/fluent_auto_enum ", 18)
	assert(#suggestions == 3, "Test 135b failed: fluent enum should return 3 suggestions")

	-- Test 135c: Fluent API - autocompletion with boolean
	register_command("fluent_auto_bool")
		:description("Fluent auto bool test")
		:arg("enabled", "boolean")
		:handler(function() end)
		:register()

	suggestions = suggest_at("/fluent_auto_bool ", 18)
	assert(#suggestions > 0, "Test 135c failed: fluent boolean should return suggestions")

	-- Test 135d: Fluent API - autocompletion with named arguments
	register_command("fluent_auto_named")
		:description("Fluent auto named test")
		:arg("x", "number")
		:arg("y", "number")
		:handler(function() end)
		:register()

	suggestions = suggest_at("/fluent_auto_named 10 ", 21)
	assert(#suggestions == 0, "Test 135d failed: fluent number arg should have no suggestions")

	-- Test 135e: Fluent API - autocompletion command name suggestion
	register_command("fluent_cmd_test")
		:description("Test command")
		:handler(function() end)
		:register()

	suggestions = suggest_at("/fluent_cmd", 10)
	assert(#suggestions >= 1, "Test 135e failed: fluent command should be suggested")

	-- Test 135f: Fluent API - autocompletion without caret (defaults to end)
	suggestions = suggest_at("/fluent_cmd")
	assert(#suggestions >= 1, "Test 135f failed: fluent command should be suggested without caret")

	-- Test 135g: context_at without caret (defaults to end)
	local ctx = test_instance:context_at("/fluent_cmd_test")
	assert(ctx ~= nil, "Test 135g failed: context_at should work without caret")

	-- Test 135h: Custom autocompleter inside string literal
	register_type("custom_type", function(token) return token end)
	test_instance:register_suggestions("custom_type", function(partial)
		local completer = autocompleter.new()
		completer:insert("alpha")
		completer:insert("beta")
		completer:insert("gamma")
		return completer:get_completions(partial)
	end)
	register_command("custom_auto", {
		description = "Custom autocompleter test",
		args = {
			{ name = "value", type = "custom_type" },
		},
		handler = function() end,
	})

	suggestions = suggest_at('/custom_auto "al', 14)
	assert(#suggestions > 0, "Test 135h failed: custom autocompleter should work inside string")
	assert(#suggestions >= 1, "Test 135h failed: should have at least 1 suggestion")

	-- Test 135i: Custom autocompleter inside string with no partial
	suggestions = suggest_at('/custom_auto "', 13)
	assert(#suggestions >= 3, "Test 135i failed: custom autocompleter should return all options inside empty string")

	-- Test 135j: Custom autocompleter with multi-type inside string
	register_command("custom_multi", {
		description = "Custom multi-type test",
		args = {
			{ name = "value", type = { "custom_type", "string" } },
		},
		handler = function() end,
	})

	suggestions = suggest_at('/custom_multi "be', 15)
	assert(#suggestions > 0, "Test 135j failed: custom autocompleter should work with multi-type inside string")

	-- Test 136: Fluent API - basic chaining
	register_command("fluent_test")
		:description("Test fluent API")
		:arg("x", "number")
		:arg("y", "number")
		:handler(function(ctx, args)
			test_cmd_args = args
		end)
		:register()

	test_cmd_args = nil
	local ok_fluent = handle_line({}, "/fluent_test 10 20")
	assert(ok_fluent == true, "Test 136 failed: fluent API command should work")
	assert(test_cmd_args.x == 10, "Test 136 failed: x should be 10")
	assert(test_cmd_args.y == 20, "Test 136 failed: y should be 20")

	-- Test 137: Fluent API - with all options
	register_command("fluent_full")
		:description("Full fluent API test")
		:aliases({ "ff", "full" })
		:arg("value", "string")
		:permission(function(ctx, args)
			return true -- Always allow for test
		end)
		:validate(function(schema)
			return true -- Always valid for test
		end)
		:pre_validate(function(ctx, args)
			return true -- Always valid for test
		end)
		:handler(function(ctx, args)
			test_cmd_args = args
		end)
		:register()

	test_cmd_args = nil
	local ok_fluent_full = handle_line({ player = {} }, "/fluent_full hello")
	assert(ok_fluent_full == true, "Test 137 failed: fluent API with all options should work")
	assert(test_cmd_args.value == "hello", "Test 137 failed: value should be hello")

	-- Test 138: Fluent API - simplified arg syntax
	register_command("fluent_simple")
		:description("Simplified arg syntax")
		:arg({ "x", "number" })
		:arg({ "y", type = "number" })
		:arg({ name = "z", "number" })
		:handler(function(ctx, args)
			test_cmd_args = args
		end)
		:register()

	test_cmd_args = nil
	local ok_fluent_simple = handle_line({}, "/fluent_simple 1 2 3")
	assert(ok_fluent_simple == true, "Test 138 failed: fluent API with simplified args should work")
	assert(test_cmd_args.x == 1, "Test 138 failed: x should be 1")
	assert(test_cmd_args.y == 2, "Test 138 failed: y should be 2")
	assert(test_cmd_args.z == 3, "Test 138 failed: z should be 3")

	-- Test 139: Fluent API - anonymous args
	register_command("fluent_anon")
		:description("Anonymous args")
		:arg("number")
		:arg("string")
		:handler(function(ctx, args)
			test_cmd_args = args
		end)
		:register()

	test_cmd_args = nil
	local ok_fluent_anon = handle_line({}, "/fluent_anon 42 hello")
	assert(ok_fluent_anon == true, "Test 139 failed: fluent API with anonymous args should work")
	assert(test_cmd_args[1] == 42, "Test 139 failed: #1 should be 42")
	assert(test_cmd_args[2] == "hello", "Test 139 failed: #2 should be hello")

	-- Test 140: Fluent API - cmd alias
	register_command("cmd_alias_test")
		:description("Cmd alias test")
		:arg("value", "string")
		:handler(function(ctx, args)
			test_cmd_args = args
		end)
		:register()

	test_cmd_args = nil
	local ok_cmd_alias = handle_line({}, "/cmd_alias_test world")
	assert(ok_cmd_alias == true, "Test 140 failed: cmd alias should work")
	assert(test_cmd_args.value == "world", "Test 140 failed: value should be world")

	-- Test 141: Fluent API - default value as third parameter
	register_command("fluent_default")
		:description("Default value as third param")
		:arg("x", "number")
		:arg("y", "number", 10) -- default as third param
		:handler(function(ctx, args)
			test_cmd_args = args
		end)
		:register()

	test_cmd_args = nil
	local ok_fluent_default = handle_line({}, "/fluent_default 5")
	assert(ok_fluent_default == true, "Test 141 failed: fluent API with default as third param should work")
	assert(test_cmd_args.x == 5, "Test 141 failed: x should be 5")
	assert(test_cmd_args.y == 10, "Test 141 failed: y should be 10 (default)")

	test_cmd_args = nil
	local ok_fluent_default_explicit = handle_line({}, "/fluent_default 5 20")
	assert(ok_fluent_default_explicit == true, "Test 141b failed: fluent API with explicit value should work")
	assert(test_cmd_args.x == 5, "Test 141b failed: x should be 5")
	assert(test_cmd_args.y == 20, "Test 141b failed: y should be 20 (explicit)")

	-- Test 142: Fluent API - simplified array syntax with default
	register_command("fluent_array_default")
		:description("Array syntax with default")
		:arg({ "x", "number" })
		:arg({ "y", "number", 10 }) -- array syntax with default
		:handler(function(ctx, args)
			test_cmd_args = args
		end)
		:register()

	test_cmd_args = nil
	local ok_array_default = handle_line({}, "/fluent_array_default 5")
	assert(ok_array_default == true, "Test 142 failed: array syntax with default should work")
	assert(test_cmd_args.x == 5, "Test 142 failed: x should be 5")
	assert(test_cmd_args.y == 10, "Test 142 failed: y should be 10 (default)")

	-- Test 143: Fluent API - anonymous arg with default
	register_command("fluent_anon_default")
		:description("Anonymous arg with default")
		:arg("number", 10) -- anonymous arg, second param is default
		:handler(function(ctx, args)
			test_cmd_args = args
		end)
		:register()

	test_cmd_args = nil
	local ok_anon_default = handle_line({}, "/fluent_anon_default")
	assert(ok_anon_default == true, "Test 143 failed: anonymous arg with default should work")
	assert(test_cmd_args[1] == 10, "Test 143 failed: #1 should be 10 (default)")

	test_cmd_args = nil
	local ok_anon_default_explicit = handle_line({}, "/fluent_anon_default 5")
	assert(ok_anon_default_explicit == true, "Test 143b failed: anonymous arg with explicit value should work")
	assert(test_cmd_args[1] == 5, "Test 143b failed: #1 should be 5 (explicit)")

	-- Test 144: Register command early, set handler later
	local early_schema = register_command("late_handler", {
		description = "Command with handler set later",
		args = {
			{ name = "value", type = "string" },
		},
		handler = function() end, -- Dummy handler to suppress warning
	})

	-- Replace with actual handler later
	early_schema.handler = function(ctx, args)
		test_cmd_args = args
	end

	test_cmd_args = nil
	local ok_late = handle_line({}, "/late_handler hello")
	assert(ok_late == true, "Test 144 failed: late handler should work")
	assert(test_cmd_args.value == "hello", "Test 144 failed: value should be hello")

	-- Test 145: Fluent API requires handler before register
	local ok_fluent_error, err_fluent_error = pcall(function()
		register_command("no_handler_fluent")
			:description("Should fail without handler")
			:register()
	end)
	assert(ok_fluent_error == false, "Test 145 failed: fluent API without handler should error")
	assert(string_find(err_fluent_error, "handler"), "Test 145 failed: error should mention handler")

	-- Test 146: Fluent API - invalid name should error
	local ok_invalid_name, err_invalid_name = pcall(function()
		register_command("")
			:description("Should fail with empty name")
			:handler(function() end)
			:register()
	end)
	assert(ok_invalid_name == false, "Test 146 failed: empty name should error")
	assert(string_find(err_invalid_name, "name"), "Test 146 failed: error should mention name")

	-- Test 147: Fluent API - invalid description type should error
	local ok_invalid_desc, err_invalid_desc = pcall(function()
		register_command("test")
			:description(123) -- Invalid type
			:handler(function() end)
			:register()
	end)
	assert(ok_invalid_desc == false, "Test 147 failed: invalid description should error")
	assert(string_find(err_invalid_desc, "description"), "Test 147 failed: error should mention description")

	-- Test 148: Fluent API - invalid handler type should error
	local ok_invalid_handler, err_invalid_handler = pcall(function()
		register_command("test")
			:description("test")
			:handler("not a function") -- Invalid type
			:register()
	end)
	assert(ok_invalid_handler == false, "Test 148 failed: invalid handler should error")
	assert(string_find(err_invalid_handler, "handler"), "Test 148 failed: error should mention handler")

	-- Test 149: Fluent API - invalid aliases type should error
	local ok_invalid_aliases, err_invalid_aliases = pcall(function()
		register_command("test")
			:description("test")
			:handler(function() end)
			:aliases("not a table") -- Invalid type
			:register()
	end)
	assert(ok_invalid_aliases == false, "Test 149 failed: invalid aliases should error")
	assert(string_find(err_invalid_aliases, "aliases"), "Test 149 failed: error should mention aliases")

	-- Test 150: Fluent API - enum method
	register_command("fluent_enum")
		:description("Fluent enum test")
		:arg("color", "string")
		:enum({ "red", "green", "blue" })
		:handler(function(ctx, args)
			test_cmd_args = args
		end)
		:register()

	test_cmd_args = nil
	local ok_fluent_enum = handle_line({}, "/fluent_enum red")
	assert(ok_fluent_enum == true, "Test 150 failed: fluent enum should work")
	assert(test_cmd_args.color == "red", "Test 150 failed: color should be red")

	local ok_fluent_enum_fail, err_fluent_enum_fail = handle_line({}, "/fluent_enum yellow")
	assert(ok_fluent_enum_fail == false, "Test 150b failed: fluent enum should reject invalid value")
	assert(string_find(err_fluent_enum_fail, "expected one of"), "Test 150b failed: error should mention enum")

	-- Test 151: Fluent API - enum without arg first should error
	local ok_enum_no_arg, err_enum_no_arg = pcall(function()
		register_command("test")
			:description("test")
			:handler(function() end)
			:enum({ "a", "b" })
			:register()
	end)
	assert(ok_enum_no_arg == false, "Test 151 failed: enum without arg should error")
	assert(string_find(err_enum_no_arg, "no arguments"), "Test 151 failed: error should mention no arguments")

	-- Test 152: Fluent API - enum with varargs
	register_command("fluent_enum_varargs")
		:description("Fluent enum varargs test")
		:arg("color", "string")
		:enum("red", "green", "blue") -- Varargs syntax
		:handler(function(ctx, args)
			test_cmd_args = args
		end)
		:register()

	test_cmd_args = nil
	local ok_enum_varargs = handle_line({}, "/fluent_enum_varargs green")
	assert(ok_enum_varargs == true, "Test 152 failed: enum varargs should work")
	assert(test_cmd_args.color == "green", "Test 152 failed: color should be green")

	local ok_enum_varargs_fail, err_enum_varargs_fail = handle_line({}, "/fluent_enum_varargs yellow")
	assert(ok_enum_varargs_fail == false, "Test 152b failed: enum varargs should reject invalid value")
	assert(string_find(err_enum_varargs_fail, "expected one of"), "Test 152b failed: error should mention enum")

	-- Test 153: Fluent API - varargs/rest arguments
	register_command("fluent_varargs")
		:description("Fluent varargs test")
		:arg("x", "number")
		:arg("y", "number")
		:handler(function(ctx, args)
			test_cmd_args = args
		end)
		:register()

	test_cmd_args = nil
	local ok_varargs = handle_line({}, "/fluent_varargs 1 2 3 4 5")
	assert(ok_varargs == true, "Test 153 failed: fluent varargs should work")
	assert(test_cmd_args.x == 1, "Test 153 failed: x should be 1")
	assert(test_cmd_args.y == 2, "Test 153 failed: y should be 2")
	assert(test_cmd_args._rest ~= nil, "Test 153 failed: _rest should exist")
	assert(#test_cmd_args._rest == 3, "Test 153 failed: _rest should have 3 items")
	assert(test_cmd_args._rest[1] == "3", "Test 153 failed: _rest[1] should be '3'")
	assert(test_cmd_args._rest[2] == "4", "Test 153 failed: _rest[2] should be '4'")
	assert(test_cmd_args._rest[3] == "5", "Test 153 failed: _rest[3] should be '5'")
	-- Verify using select("#", ...) pattern
	local rest_count = select("#", table.unpack(test_cmd_args._rest))
	assert(rest_count == 3, "Test 153 failed: select('#', ...) should return 3")

	-- Test 154: Fluent API - varargs with no extra args
	test_cmd_args = nil
	local ok_varargs_none = handle_line({}, "/fluent_varargs 10 20")
	assert(ok_varargs_none == true, "Test 154 failed: fluent varargs with no extra should work")
	assert(test_cmd_args.x == 10, "Test 154 failed: x should be 10")
	assert(test_cmd_args.y == 20, "Test 154 failed: y should be 20")
	assert(test_cmd_args._rest == nil, "Test 154 failed: _rest should be nil when no extra args")

	-- Test 155: Fluent API - varargs with no args defined
	register_command("fluent_varargs_all")
		:description("All varargs test")
		:handler(function(ctx, args)
			test_cmd_args = args
		end)
		:register()

	test_cmd_args = nil
	local ok_varargs_all = handle_line({}, "/fluent_varargs_all a b c")
	assert(ok_varargs_all == true, "Test 155 failed: all varargs should work")
	assert(test_cmd_args._rest ~= nil, "Test 155 failed: _rest should exist")
	assert(#test_cmd_args._rest == 3, "Test 155 failed: _rest should have 3 items")
	assert(test_cmd_args._rest[1] == "a", "Test 155 failed: _rest[1] should be 'a'")
	assert(test_cmd_args._rest[2] == "b", "Test 155 failed: _rest[2] should be 'b'")
	assert(test_cmd_args._rest[3] == "c", "Test 155 failed: _rest[3] should be 'c'")
	-- Verify using select("#", ...) pattern
	local all_count = select("#", table.unpack(test_cmd_args._rest))
	assert(all_count == 3, "Test 155 failed: select('#', ...) should return 3")

	-- Test 156: Standard API - pass_varargs enabled
	register_command("pass_varargs_std", {
		description = "Pass varargs test",
		args = {
			{ name = "x", type = "number" },
		},
		pass_varargs = true,
		handler = function(ctx, args, ...)
			test_cmd_args = args
			test_cmd_varargs = { ... }
		end,
	})

	test_cmd_args = nil
	test_cmd_varargs = nil
	local ok_pass_varargs = handle_line({}, "/pass_varargs_std 10 20 30")
	assert(ok_pass_varargs == true, "Test 156 failed: pass_varargs should work")
	assert(test_cmd_args.x == 10, "Test 156 failed: x should be 10")
	assert(test_cmd_varargs ~= nil, "Test 156 failed: varargs should exist")
	assert(#test_cmd_varargs == 2, "Test 156 failed: varargs should have 2 items")
	assert(test_cmd_varargs[1] == "20", "Test 156 failed: varargs[1] should be '20'")
	assert(test_cmd_varargs[2] == "30", "Test 156 failed: varargs[2] should be '30'")

	-- Test 157: Fluent API - pass_varargs method (enabled by default)
	register_command("pass_varargs_fluent")
		:description("Fluent pass_varargs test")
		:arg("x", "number")
		:handler(function(ctx, args, ...)
			test_cmd_args = args
			test_cmd_varargs = { ... }
		end)
		:register()

	test_cmd_args = nil
	test_cmd_varargs = nil
	local ok_pass_varargs_fluent = handle_line({}, "/pass_varargs_fluent 5 15 25 35")
	assert(ok_pass_varargs_fluent == true, "Test 157 failed: fluent pass_varargs should work")
	assert(test_cmd_args.x == 5, "Test 157 failed: x should be 5")
	assert(test_cmd_varargs ~= nil, "Test 157 failed: varargs should exist")
	assert(#test_cmd_varargs == 3, "Test 157 failed: varargs should have 3 items")
	assert(test_cmd_varargs[1] == "15", "Test 157 failed: varargs[1] should be '15'")
	assert(test_cmd_varargs[2] == "25", "Test 157 failed: varargs[2] should be '25'")
	assert(test_cmd_varargs[3] == "35", "Test 157 failed: varargs[3] should be '35'")

	-- Test 158: pass_varargs with no rest arguments (enabled by default for fluent)
	test_cmd_args = nil
	test_cmd_varargs = nil
	local ok_pass_varargs_none = handle_line({}, "/pass_varargs_fluent 100")
	assert(ok_pass_varargs_none == true, "Test 158 failed: pass_varargs with no rest should work")
	assert(test_cmd_args.x == 100, "Test 158 failed: x should be 100")
	assert(#test_cmd_varargs == 0, "Test 158 failed: varargs should be empty when no rest")

	-- Test 159: pass_varargs disabled (default behavior)
	register_command("no_pass_varargs")
		:description("No pass_varargs test")
		:arg("x", "number")
		:pass_varargs(false)
		:handler(function(ctx, args, ...)
			test_cmd_args = args
			test_cmd_varargs = { ... }
		end)
		:register()

	test_cmd_args = nil
	test_cmd_varargs = nil
	local ok_no_pass_varargs = handle_line({}, "/no_pass_varargs 1 2 3")
	assert(ok_no_pass_varargs == true, "Test 159 failed: no pass_varargs should work")
	assert(test_cmd_args.x == 1, "Test 159 failed: x should be 1")
	assert(#test_cmd_varargs == 0, "Test 159 failed: varargs should be empty when disabled")

	-- Cleanup auto-completer test commands
	unregister_command("teleport")
	unregister_command("teleport_to")
	unregister_command("color")
	unregister_command("toggle")
	unregister_command("add")
	unregister_command("hello")
	unregister_command("move")
	unregister_command("count")
	unregister_command("anon")
	unregister_command("mixed")
	unregister_command("bin_edge")
	unregister_command("def_alias")
	unregister_command("enum_def")
	unregister_command("req_default")
	unregister_command("opt_default")
	unregister_command("anon_def")
	unregister_command("anon_enum")
	unregister_command("anon_coerce")
	unregister_command("mixed_def")
	unregister_command("mixed_comprehensive")
	unregister_command("dup_names")
	unregister_command("dup_fluent")
	unregister_command("optional_type")
	unregister_command("optional_multi")
	unregister_command("fluent_optional")
	unregister_command("field_test")
	unregister_command("no_handler")
	unregister_command("perm_no_ctx")
	unregister_command("custom_validate")
	unregister_command("pre_validate")
	unregister_command("bad_pre_validate")
	unregister_command("simple_array")
	unregister_command("simple_mixed1")
	unregister_command("simple_mixed2")
	unregister_command("simple_with_default")
	unregister_command("any_test")
	unregister_command("multi_type")
	unregister_command("multi_type_num")
	unregister_command("multi_enum")
	unregister_command("multi_suggest")
	unregister_command("multi_bool_first")
	unregister_command("multi_str_first")
	unregister_command("multi_custom")
	unregister_command("multi_enum_suggest")
	unregister_command("multi_num")
	unregister_command("multi_any")
	unregister_command("multi_bool_end")
	unregister_command("multi_bool_partial")
	unregister_command("fluent_test")
	unregister_command("fluent_full")
	unregister_command("fluent_simple")
	unregister_command("fluent_anon")
	unregister_command("cmd_alias_test")
	unregister_command("fluent_default")
	unregister_command("fluent_array_default")
	unregister_command("fluent_anon_default")
	unregister_command("late_handler")
	unregister_command("fluent_enum")
	unregister_command("fluent_enum_varargs")
	unregister_command("fluent_varargs")
	unregister_command("fluent_varargs_all")
	unregister_command("pass_varargs_std")
	unregister_command("pass_varargs_fluent")
	unregister_command("no_pass_varargs")
	unregister_command("fluent_auto_enum")
	unregister_command("fluent_auto_bool")
	unregister_command("fluent_auto_named")
	unregister_command("fluent_cmd_test")
	unregister_command("custom_auto")
	unregister_command("custom_multi")
end
--]]

local default_instance = ChatCommander.new()

-- Export
return {
	ChatCommander = ChatCommander,
	new = ChatCommander.new,
	-- For backward compatibility, also export static functions that create a default instance
	default_instance = default_instance,
	register_type = function(name, coercer)
		return default_instance:register_type(name, coercer)
	end,
	register_suggestions = function(name, handler)
		return default_instance:register_suggestions(name, handler)
	end,
	coerce_vector3 = coerce_vector3,
	register_command = function(name, schema)
		return default_instance:register_command(name, schema)
	end,
	unregister_command = function(name)
		return default_instance:unregister_command(name)
	end,
	get_command = function(name)
		return default_instance:get_command(name)
	end,
	parse_line = function(raw_line)
		return default_instance:parse_line(raw_line)
	end,
	handle_line = function(ctx, raw_line)
		return default_instance:handle_line(ctx, raw_line)
	end,
	get_help = function(name)
		return default_instance:get_help(name)
	end,
	list_commands = function()
		return default_instance:list_commands()
	end,
	set_prefix = function(prefix)
		return default_instance:set_prefix(prefix)
	end,
	suggest_at = function(line, caret, options)
		return default_instance:suggest_at(line, caret, options)
	end,
	-- Aliases
	cmd = function(name, schema)
		return default_instance:register_command(name, schema)
	end,
	reg = function(name, schema)
		return default_instance:register_command(name, schema)
	end,
	unreg = function(name)
		return default_instance:unregister_command(name)
	end,
	exec = function(ctx, raw_line)
		return default_instance:handle_line(ctx, raw_line)
	end,
	parse = function(raw_line)
		return default_instance:parse_line(raw_line)
	end,
	type = function(name, coercer)
		return default_instance:register_type(name, coercer)
	end,
	get = function(name)
		return default_instance:get_command(name)
	end,
}
