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
local table_unpack = table.unpack or unpack

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
---@field permission? fun(ctx: table, args: table): (boolean, string) Permission check function
---@field validate? fun(schema: chat_commander.CommandSchema): (boolean, string) Custom validation during registration
---@field pre_validate? fun(ctx: table, args: table): (boolean, string) Custom validation before handler execution
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

	-- Return schema for later modification (e.g. setting handler)
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
		local success, err = pcall(handler, ctx, parsed.args, table_unpack(parsed.args._rest))
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

	-- No suggestions (e.g. past the last arg)
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
