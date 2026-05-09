-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Localized global functions for better performance
local assert = assert
local next = next
local pcall = pcall
local setmetatable = setmetatable
local tonumber = tonumber
local tostring = tostring
local type = type
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local string_find = string.find
local string_format = string.format
local string_lower = string.lower
local string_match = string.match
local string_sub = string.sub
local table_concat = table.concat
local table_insert = table.insert
local table_remove = table.remove
local table_sort = table.sort

-- Import fuzzy
local fuzzy = require "fuzzy"

---@class ConsoleOptions
---@field suggestion_limit integer|nil Max suggestions to return (default: 8)
---@field history_limit integer|nil Max history entries (default: 200)
---@field case_sensitive boolean|nil Case sensitivity (nil = smart-case)

---@class ConsoleCommandArg
---@field name string Argument name
---@field type "string"|"number"|"int"|"bool"|"enum"|nil Argument type
---@field optional boolean|nil Whether argument is optional
---@field default any Default value if optional and not provided
---@field desc string|nil Description
---@field choices string[]|nil Enum choices (when type = "enum")
---@field flag string|nil Flag name (e.g., "--verbose")
---@field suggest fun(ctx: table, partial: string): table[]|nil Custom suggest hook

---@class ConsoleCommand
---@field name string Command name
---@field aliases string[]|nil Alternative names
---@field args ConsoleCommandArg[]|nil Argument specifications
---@field desc string|nil Description
---@field handler fun(ctx: table, args: table): any Command handler
---@field context_check fun(ctx: table): boolean, string|nil Permission check
---@field arg_vocab table|nil Vocabulary for argument completion
---@field no_arg_suggest boolean|nil Disable argument autocompletion for this command

---@class ParsedCommand
---@field raw string Original input line
---@field name string Resolved command name
---@field cmd ConsoleCommand|nil Command definition (nil if unknown)
---@field args table Parsed arguments (keyed by name)

---@class Console
---@field opts ConsoleOptions
---@field commands table<string, ConsoleCommand> Registered commands
---@field alias_map table<string, string> Alias -> name mapping
---@field engine table Fuzzy engine instance
---@field history string[] Command history
---@field history_index integer Current history position
---@field time number
local Console = {}
Console.__index = Console

--- Default options
---@type ConsoleOptions
local DEFAULTS = {
	suggestion_limit = 10,
	history_limit = 100,
	case_sensitive = nil, -- nil = smart-case
}

----------------------------------------------------------------------
-- Local helpers
----------------------------------------------------------------------

--- Compare items by frequency for sorting (descending).<br>
--- Higher frequency items come first.
---@param a table First item with _freq field
---@param b table Second item with _freq field
---@return boolean result True if a should come before b
local function compare_by_freq(a, b)
	return (a._freq or 0) > (b._freq or 0)
end

--- Utility: split into tokens but keep quoted strings
---@param line string
---@return string[] tokens
local function tokenize_line(line)
	local tokens = {}
	local i = 1
	local n = #line
	while i <= n do
		-- skip spaces
		while i <= n and string_match(string_sub(line, i, i), "%s") do i = i + 1 end
		if i > n then break end
		local ch = string_sub(line, i, i)
		if ch == '"' or ch == "'" then
			local quote = ch
			local j = i + 1
			local buf = {}
			while j <= n do
				local c = string_sub(line, j, j)
				if c == "\\" and j < n then
					-- escape next char
					buf[#buf + 1] = string_sub(line, j + 1, j + 1)
					j = j + 2
				elseif c == quote then
					break
				else
					buf[#buf + 1] = c
					j = j + 1
				end
			end
			tokens[#tokens + 1] = table_concat(buf)
			i = j + 1
		else
			local j = i
			while j <= n and not string_match(string_sub(line, j, j), "%s") do j = j + 1 end
			tokens[#tokens + 1] = string_sub(line, i, j - 1)
			i = j
		end
	end
	return tokens
end

--- Arg parsing helpers: supports types: "string", "number", "int", "bool", "enum"
---@param spec ConsoleCommandArg|nil
---@param raw string
---@return any value
---@return string|nil error
local function parse_arg_value(spec, raw)
	if spec == nil or spec.type == nil then return raw end
	local t = spec.type
	if t == "string" then
		return raw
	end
	if t == "number" then
		local v = tonumber(raw)
		if not v then return nil, "expected number" end
		return v
	end
	if t == "int" then
		local v = tonumber(raw)
		if not v then return nil, "expected integer" end
		return math_floor(v)
	end
	if t == "bool" then
		local lr = string_lower(raw or "")
		if lr == "true" or lr == "1" or lr == "yes" or lr == "on" then return true end
		if lr == "false" or lr == "0" or lr == "no" or lr == "off" then return false end
		return nil, "expected boolean"
	end
	if t == "enum" then
		if not spec.choices then return nil, "enum missing choices" end
		local choices = spec.choices
		-- Handle function choices
		if type(choices) == "function" then
			choices = choices(raw) -- Call function with current input
		end
		-- Now validate against the choices
		if type(choices) == "table" then
			for i = 1, #choices do
				if choices[i] == raw then return raw end
			end
		end
		return nil, "invalid choice"
	end
	return raw
end

--- Create a new console instance.<br>
--- Initializes a console with command registration, history tracking, and fuzzy search capabilities.<br>
--- Accepts optional configuration for suggestion limit, history limit, and case sensitivity.
---@param opts ConsoleOptions|nil Configuration options (suggestion_limit, history_limit, case_sensitive)
---@return Console console The newly created console instance
---@usage <br>
--- ```
--- local console = Console.new({
---   suggestion_limit = 10,
---   history_limit = 100,
---   case_sensitive = false
--- })
--- ```
function Console.new(opts)
	opts = opts or {}
	local self = setmetatable({
		opts = {},
		commands = {},           -- map name -> cmd
		alias_map = {},          -- alias -> name
		engine = fuzzy.Engine({}, {}), -- fuzzy engine for suggestions
		history = {},
		history_index = 0,
		time = 0,
	}, Console)
	-- Handle all default options including those with nil values
	if opts.suggestion_limit ~= nil then
		self.opts.suggestion_limit = opts.suggestion_limit
	else
		self.opts.suggestion_limit = DEFAULTS.suggestion_limit
	end

	if opts.history_limit ~= nil then
		self.opts.history_limit = opts.history_limit
	else
		self.opts.history_limit = DEFAULTS.history_limit
	end

	if opts.case_sensitive ~= nil then
		self.opts.case_sensitive = opts.case_sensitive
	else
		self.opts.case_sensitive = DEFAULTS.case_sensitive
	end
	return self
end

--- Register a command with the console.<br>
--- Adds the command to the registry, registers it with the fuzzy search engine, and sets up any aliases.
---@param cmd ConsoleCommand Command definition with name, handler, args, desc, and optional aliases
---@usage <br>
--- ```
--- console:register({
---   name = "greet",
---   desc = "Greet the user",
---   args = { { name = "name", type = "string" } },
---   handler = function(_, args) return "Hello, " .. args.name end
--- })
--- ```
function Console:register(cmd)
	assert(cmd and type(cmd.name) == "string", "command must have a name")
	self.commands[cmd.name] = cmd
	self.engine:add(cmd.name, { desc = cmd.desc })
	if cmd.aliases then
		for _, a in next, cmd.aliases do
			self.alias_map[a] = cmd.name
		end
	end
end

--- Resolve a command name to its canonical form.<br>
--- Returns the original name if it's a registered command, otherwise resolves aliases to their target names.<br>
--- Returns nil if the name is not a registered command or alias.
---@param name string Command name or alias to resolve
---@return string|nil resolved_name The canonical command name, or nil if not found
---@usage <br>
--- ```
--- local resolved = console:resolve_name("?") -- returns "help" if "?" is an alias
--- ```
function Console:resolve_name(name)
	if self.commands[name] then return name end
	return self.alias_map[name]
end

--- Parse a command line into command name and arguments.<br>
--- Tokenizes the input line, resolves command aliases, and validates arguments against the command specification.<br>
--- Supports quoted strings, type conversion, and optional arguments.<br>
--- Returns a parsed command object with raw input, resolved name, command definition, and parsed arguments.
---@param line string The command line to parse
---@return ParsedCommand|nil parsed Parsed command object, or nil if parsing failed
---@return string|nil error Error message if parsing failed
---@usage <br>
--- ```
--- local parsed, err = console:parse_line('greet "John Doe"')
--- if parsed then print(parsed.name) end
--- ```
function Console:parse_line(line)
	local tokens = tokenize_line(line)
	if #tokens == 0 then return nil, "empty" end
	local cmdname = tokens[1]
	local resolved = self:resolve_name(cmdname) or cmdname
	local cmd = self.commands[resolved]
	local args = {}
	if not cmd then
		-- treat as raw command if no registered command
		local args = {}
		if #tokens > 1 then
			local rest = {}
			for j = 2, #tokens do
				table_insert(rest, tokens[j])
			end
			args._rest = rest
		end
		return { raw = line, name = cmdname, cmd = nil, args = args }
	end
	-- parse according to cmd.args
	local specs = cmd.args or {}
	local ti = 2
	for i = 1, #specs do
		local spec = specs[i]
		local raw = tokens[ti]
		if raw == nil then
			if spec.optional then
				args[spec.name] = spec.default
			else
				return nil, "missing argument: " .. (spec.name or ("arg" .. i))
			end
		else
			local val, err = parse_arg_value(spec, raw)
			if err then return nil, "arg " .. (spec.name or i) .. ": " .. err end
			args[spec.name or ("arg" .. i)] = val
			ti = ti + 1
		end
	end
	-- remaining tokens as varargs
	if ti <= #tokens then
		local rest = {}
		for j = ti, #tokens do
			table_insert(rest, tokens[j])
		end
		args._rest = rest
	end
	return { raw = line, name = resolved, cmd = cmd, args = args }
end

--- Execute a parsed command.<br>
--- Runs the command handler with the parsed arguments after performing context checks.<br>
--- Records command usage in the fuzzy engine and adds the command to history.<br>
--- Returns the handler result or an error message if execution fails.
---@param parsed ParsedCommand The parsed command to execute
---@param ctx table|nil Execution context passed to the handler (e.g., user permissions, environment)
---@return any result The result from the command handler
---@return string|nil error Error message if execution failed
---@usage <br>
--- ```
--- local parsed, err = console:parse_line('greet "John"')
--- if parsed then
---   local result, err = console:execute_parsed(parsed, { user = "admin" })
--- end
--- ```
function Console:execute_parsed(parsed, ctx)
	ctx = ctx or {}
	if not parsed then return nil, "nothing to execute" end
	if not parsed.cmd then
		return nil, "unknown command: " .. (parsed.name or "<nil>")
	end
	local cmd = parsed.cmd
	-- context check
	if cmd.context_check then
		local ok, reason = cmd.context_check(ctx)
		if not ok then return nil, "context check failed: " .. (reason or "forbidden") end
	end
	-- call handler
	local ok, res_or_err = pcall(function() return cmd.handler(ctx, parsed.args) end)
	if not ok then
		return nil, "handler error: " .. tostring(res_or_err)
	end
	-- record usage for ranking
	self.engine:record_use(cmd.name)
	-- push to history
	table_insert(self.history, 1, parsed.raw)
	if #self.history > self.opts.history_limit then
		for i = #self.history, self.opts.history_limit + 1, -1 do
			table_remove(self.history, i)
		end
	end
	self.history_index = 0
	return res_or_err
end

--- Parse and execute a command line in one step.<br>
--- Convenience function that combines parse_line and execute_parsed for quick command execution.<br>
--- Returns the handler result or an error message if parsing or execution fails.
---@param line string The command line to parse and execute
---@param ctx table|nil Execution context passed to the handler
---@return any result The result from the command handler
---@return string|nil error Error message if parsing or execution failed
---@usage <br>
--- ```
--- local result, err = console:input_line('greet "John"', { user = "admin" })
--- ```
function Console:input_line(line, ctx)
	local parsed, err = self:parse_line(line)
	if not parsed then return nil, err end
	return self:execute_parsed(parsed, ctx)
end

--- Get fuzzy suggestions for commands and optionally argument values.<br>
--- Returns ranked suggestions based on the prefix. If prefix is empty, returns most frequently used commands.<br>
--- If prefix contains a space, attempts to provide argument value suggestions for the resolved command.<br>
--- Otherwise returns fuzzy-matched command names with descriptions and scores.
---@param prefix string|nil The prefix to match suggestions against
---@param limit integer|nil Maximum number of suggestions to return (defaults to suggestion_limit)
---@return table[] suggestions Array of suggestion objects with key, desc, and score
---@usage <br>
--- ```
--- local suggestions = console:suggest("gre", 10)
--- for _, s in ipairs(suggestions) do print(s.key, s.desc) end
--- ```
function Console:suggest(prefix, limit)
	limit = limit or self.opts.suggestion_limit
	prefix = prefix or ""
	-- if prefix empty, return top frequent commands
	if prefix == "" then
		-- sort by freq/recency
		local items = {}
		local engine_items = self.engine.items
		for i = 1, #engine_items do
			items[i] = engine_items[i]
		end
		table_sort(items, compare_by_freq)
		local out = {}
		for i = 1, math_min(limit, #items) do
			out[i] = { key = items[i].key, desc = items[i].meta and items[i].meta.desc }
		end
		return out
	end
	-- if prefix contains space, try argument suggestions for the resolved command
	local tokens = tokenize_line(prefix)
	if #tokens >= 1 then
		local name = tokens[1]
		local resolved = self:resolve_name(name) or name
		local cmd = self.commands[resolved]
		if cmd then
			-- if user is typing an arg, we can provide suggestions based on arg spec
			local arg_index = #tokens -- next token index (1-based)
			local arg_spec
			if cmd.args then
				arg_spec = cmd.args[arg_index - 1]
			end
			if arg_spec and arg_spec.choices then
				-- suggest from enum choices using fuzzy.suggest
				local items = {}
				local choices = arg_spec.choices
				for i = 1, #choices do
					items[i] = { key = choices[i] }
				end
				local results = fuzzy.suggest(items, tokens[#tokens], { limit = limit })
				local out = {}
				for i = 1, #results do
					local r = results[i]
					out[i] = { key = r.item.key, score = r.score }
				end
				return out
			end
		end
	end
	-- otherwise suggest command names
	local items = {}
	for name, _ in next, self.commands do
		items[#items + 1] = { key = name }
	end
	local results = fuzzy.suggest(items, prefix, { limit = limit })
	local out = {}
	for i = 1, #results do
		local r = results[i]
		local cmd = self.commands[r.item.key]
		out[i] = { key = r.item.key, desc = cmd and cmd.desc or "", score = r.score }
	end
	return out
end

-- find common prefix among suggestions
local function common_prefix(a, b)
	local i = 1
	local n = math_min(#a, #b)
	while i <= n and string_sub(a, i, i) == string_sub(b, i, i) do i = i + 1 end
	return string_sub(a, 1, i - 1)
end

--- Tab completion helper that returns the best completion string.<br>
--- Returns the common prefix of all suggestions if multiple matches exist.<br>
--- Returns the exact match if prefix matches a command exactly.<br>
--- Returns the first suggestion if no common prefix is longer than the prefix.<br>
--- Returns nil if no suggestions are available.
---@param prefix string The prefix to complete
---@return string|nil completion The completion string to insert, or nil if no suggestions
---@usage <br>
--- ```
--- local completion = console:complete("gre") -- returns "greet" if it's the only match
--- ```
function Console:complete(prefix)
	local suggestions = self:suggest(prefix, 6)
	if #suggestions == 0 then return end
	-- if exact prefix matches a command, return that
	for i = 1, #suggestions do
		local s = suggestions[i]
		if s.key == prefix then return s.key end
	end
	local cp = suggestions[1].key
	for i = 2, #suggestions do cp = common_prefix(cp, suggestions[i].key) end
	if #cp > #prefix then return cp end
	-- otherwise return first suggestion
	return suggestions[1].key
end

----------------------------------------------------------------------
-- History navigation
----------------------------------------------------------------------

--- Get the previous entry from command history.<br>
--- Increments the history index and returns the corresponding history entry.<br>
--- If history is empty, returns nil.
---@return string|nil entry The previous history entry, or nil if history is empty.
---@usage <br>
--- ```
--- local entry = console:history_prev()
--- if entry then print(entry) end
--- ```
function Console:history_prev()
	if #self.history == 0 then return end
	self.history_index = math_min(#self.history, self.history_index + 1)
	return self.history[self.history_index]
end

--- Get the next entry from command history.<br>
--- Decrements the history index and returns the corresponding history entry.<br>
--- If at the beginning of history, returns an empty string.
---@return string entry The next history entry, or empty string if at the start.
---@usage <br>
--- ```
--- local entry = console:history_next()
--- print(entry) -- prints the next entry or empty string
--- ```
function Console:history_next()
	if self.history_index <= 1 then
		self.history_index = 0
		return ""
	end
	self.history_index = math_max(0, self.history_index - 1)
	return self.history[self.history_index]
end

--- Get help text for a command or list all commands.<br>
--- If cmdname is provided, returns detailed help for that specific command including arguments and aliases.<br>
--- If cmdname is nil or empty, returns a list of all registered commands with their descriptions.
---@param cmdname string|nil Command name to get help for, or nil for all commands
---@return string help_text Formatted help text
---@usage <br>
--- ```
--- print(console:help()) -- lists all commands
--- print(console:help("greet")) -- detailed help for greet command
--- ```
function Console:help(cmdname)
	if not cmdname or cmdname == "" then
		local lines = { "Available commands:" }
		for name, cmd in next, self.commands do
			table_insert(lines, string_format("  %s - %s", name, cmd.desc or ""))
		end
		return table_concat(lines, "\n")
	end
	local resolved = self:resolve_name(cmdname) or cmdname
	local cmd = self.commands[resolved]
	if not cmd then return "No such command: " .. cmdname end
	local lines = {}
	table_insert(lines, string_format("%s - %s", cmd.name, cmd.desc or ""))
	if cmd.aliases and #cmd.aliases > 0 then
		table_insert(lines, "Aliases: " .. table_concat(cmd.aliases, ", "))
	end
	if cmd.args and #cmd.args > 0 then
		table_insert(lines, "Arguments:")
		local args = cmd.args
		for i = 1, #args do
			local a = args[i]
			local opt = a.optional and "(optional)" or ""
			local typ = a.type or "string"
			table_insert(lines, string_format("  %s: %s %s %s", a.name or ("arg" .. i), typ, opt, a.desc or ""))
		end
	end
	return table_concat(lines, "\n")
end

----------------------------------------------------------------------
-- Persistence
----------------------------------------------------------------------

--- Save the console state to a table.<br>
--- Serializes the fuzzy engine state and command history for persistence.<br>
--- Returns a table containing engine state and history that can be passed to load_state.
---@return table state Table containing engine and history state
---@usage <br>
--- ```
--- local state = console:save_state()
--- -- save state to file or database
--- ```
function Console:save_state()
	local state = {
		engine = self.engine:save_state(),
		history = self.history,
	}
	return state
end

--- Load console state from a previously saved table.<br>
--- Restores the fuzzy engine state and command history from a table returned by save_state.<br>
--- Does nothing if state is nil.
---@param state table|nil State table from save_state
---@usage <br>
--- ```
--- local state = load_state_from_file()
--- console:load_state(state)
--- ```
function Console:load_state(state)
	if not state then return end
	if state.engine then self.engine:load_state(state.engine) end
	if state.history then self.history = state.history end
end

--- Register built-in default commands (help and echo).<br>
--- Adds the 'help' command (with alias '?') to display command help.<br>
--- Adds the 'echo' command to print text back to the user.<br>
--- These are convenience commands that most console instances will want.
---@usage <br>
--- ```
--- console:register_defaults()
--- -- now you can use console:input_line("help")
--- ```
function Console:register_defaults()
	self:register {
		name = "help",
		aliases = { "?" },
		desc = "Show help for commands",
		args = {
			{ name = "command", type = "string", optional = true, desc = "Command name" },
		},
		handler = function(_, args)
			if not args.command or args.command == "" then
				return self:help()
			else
				return self:help(args.command)
			end
		end
	}
	self:register {
		name = "echo",
		desc = "Echo text",
		args = {
			{ name = "text", type = "string", optional = true },
		},
		handler = function(_, args)
			local result = args.text or ""
			if args._rest then
				result = result .. " " .. table_concat(args._rest, " ")
			end
			return result
		end
	}
end

----------------------------------------------------------------------
-- IntelliSense module (for command completion and suggestions)
----------------------------------------------------------------------

---@class Console.IntelliSense.Options
---@field suggestion_limit integer|nil
---@field case_sensitive boolean|nil
---@field file_suggest_hook fun(prefix: string): table|nil

---@class Console.IntelliSense.Token
---@field text string
---@field start integer
---@field finish integer
---@field quoted boolean
---@field quote_char string|nil

---@class Console.IntelliSense.Context
---@field kind "CommandName"|"ArgValue"|"Flag"|"InsideString"|"BetweenTokens"
---@field tokens Console.IntelliSense.Token[]
---@field token_index integer
---@field token Console.IntelliSense.Token|nil
---@field partial string
---@field cmd table|nil
---@field arg_index integer|nil

---@class Console.IntelliSense.Suggestion
---@field key string
---@field label string
---@field score number
---@field meta table|nil

---@class Console.IntelliSense
---@field console Console
---@field opts Console.IntelliSense.Options
local IntelliSense = {}
IntelliSense.__index = IntelliSense

--- Create a new IntelliSense instance bound to a console.
---@param console Console The console instance to bind to
---@param opts Console.IntelliSense.Options|nil Configuration options
---@return Console.IntelliSense instance New IntelliSense instance
function IntelliSense.new(console, opts)
	opts = opts or {}
	return setmetatable({
		console = console,
		opts = {
			suggestion_limit = opts.suggestion_limit or 8,
			case_sensitive = opts.case_sensitive,
			file_suggest_hook = opts.file_suggest_hook,
		}
	}, IntelliSense)
end

--- Tokenize a command line with position tracking and quote awareness.<br>
--- Handles quoted strings with escape sequences.
---@param line string The input line to tokenize
---@return Console.IntelliSense.Token[] tokens Array of tokens with position info
function IntelliSense.tokenize_with_positions(line)
	local tokens = {}
	local i = 1
	local n = #line
	while i <= n do
		-- skip spaces
		while i <= n and string_match(string_sub(line, i, i), "%s") do i = i + 1 end
		if i > n then break end
		local ch = string_sub(line, i, i)
		if ch == '"' or ch == "'" then
			local quote = ch
			local j = i + 1
			local buf = {}
			local escaped = false
			while j <= n do
				local c = string_sub(line, j, j)
				if escaped then
					buf[#buf + 1] = c
					escaped = false
					j = j + 1
				elseif c == "\\" then
					escaped = true
					j = j + 1
				elseif c == quote then
					break
				else
					buf[#buf + 1] = c
					j = j + 1
				end
			end
			local text = table_concat(buf)
			local finish = math_min(n, j)
			tokens[#tokens + 1] = { text = text, start = i, finish = finish, quoted = true, quote_char = quote }
			i = finish + 1
		else
			local j = i
			while j <= n and not string_match(string_sub(line, j, j), "%s") do j = j + 1 end
			local text = string_sub(line, i, j - 1)
			tokens[#tokens + 1] = { text = text, start = i, finish = j - 1, quoted = false }
			i = j
		end
	end
	return tokens
end

--- Find the token at a given caret position.
---@param tokens Console.IntelliSense.Token[] Array of tokens from tokenize_with_positions
---@param caret integer Caret position (1-based, where 1 is before first char)
---@param line_len integer Length of the original line
---@return integer token_index Index of the token at caret (or insertion point)
---@return boolean inside True if caret is inside the token, false if between tokens
function IntelliSense.find_token_at(tokens, caret, line_len)
	if caret < 1 then caret = 1 end
	if caret > (line_len + 1) then caret = line_len + 1 end
	for idx = 1, #tokens do
		local tok = tokens[idx]
		if caret >= tok.start and caret <= tok.finish + 1 then
			-- caret inside token or right after last char of token
			local inside = caret <= tok.finish + 1
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

--- Determine the IntelliSense context at a given caret position.<br>
--- Analyzes the command line to determine what kind of completion is needed.
---@param self Console.IntelliSense
---@param line string The current command line
---@param caret integer Caret position (1-based)
---@return Console.IntelliSense.Context ctx The context describing what to complete
function IntelliSense.context_at(self, line, caret)
	local tokens = IntelliSense.tokenize_with_positions(line)
	local line_len = #line
	local idx, inside = IntelliSense.find_token_at(tokens, caret, line_len)
	-- default context
	local ctx = { kind = "BetweenTokens", tokens = tokens, token_index = idx, token = nil, partial = "", cmd = nil, arg_index = nil }
	-- if no tokens, suggest command names
	if #tokens == 0 then
		ctx.kind = "CommandName"
		ctx.partial = ""
		return ctx
	end
	-- if caret is inside a token
	if idx <= #tokens and inside then
		local tok = tokens[idx]
		ctx.token = tok
		ctx.partial = string_sub(tok.text, 1, math_max(0, caret - tok.start))
		-- if token is quoted and caret is inside quotes, mark InsideString
		if tok.quoted and caret > tok.start and caret <= tok.finish then
			ctx.kind = "InsideString"
			return ctx
		end
		-- if token looks like a flag
		if string_match(tok.text, "^%-%-?%w") then
			ctx.kind = "Flag"
			return ctx
		end
		-- if caret is at first token -> command name
		if idx == 1 then
			ctx.kind = "CommandName"
			return ctx
		end
		-- otherwise it's an argument token; resolve command and arg index
		local cmdname = tokens[1].text
		local resolved = self.console:resolve_name(cmdname) or cmdname
		local cmd = self.console.commands[resolved]
		ctx.cmd = cmd
		-- arg index is token position minus 1 (first token is command)
		ctx.arg_index = idx - 1
		ctx.kind = "ArgValue"
		return ctx
	end
	-- caret between tokens at position idx (insertion before tokens[idx])
	-- if idx == 1, caret before first token -> command name
	if idx == 1 then
		ctx.kind = "CommandName"
		ctx.partial = ""
		return ctx
	end
	-- otherwise caret is after some tokens; determine command and next arg index
	local cmdname = tokens[1].text
	local resolved = self.console:resolve_name(cmdname) or cmdname
	local cmd = self.console.commands[resolved]
	ctx.cmd = cmd
	if not cmd then
		ctx.kind = "CommandName"
		ctx.partial = ""
		return ctx
	end
	-- next arg index is number of tokens after command
	local next_arg_index = #tokens - 1
	-- but if caret is between tokens and directly after command, next_arg_index = 1
	if next_arg_index < 1 then next_arg_index = 1 end
	ctx.arg_index = next_arg_index
	ctx.kind = "ArgValue"
	ctx.partial = ""
	return ctx
end

--- Suggest boolean values (true/false) for argument completion.<br>
--- Returns fuzzy-matched boolean suggestions based on the partial input.<br>
--- Accepts common boolean representations like true/false, 1/0, yes/no, on/off.
---@param limit integer Maximum number of suggestions to return
---@param partial string Current partial input to match against
---@return table[] items Array of suggestion items with key and score
local function suggest_booleans(limit, partial)
	local items = { { key = "true" }, { key = "false" } }
	if partial == "" then return items end
	return fuzzy.suggest(items, partial, { limit = limit })
end

--- Suggest from a list of enum choices for argument completion.<br>
--- Returns fuzzy-matched suggestions from the provided choices array.<br>
--- Used for enum-type arguments where the user must select from a predefined set of values.
---@param choices string[] Array of valid enum choices
---@param limit integer Maximum number of suggestions to return
---@param partial string Current partial input to match against
---@return table[] items Array of suggestion items with key and score
local function suggest_enum(choices, limit, partial)
	-- Handle both function and direct array references
	if type(choices) == "function" then
		-- Dynamic function - call it
		choices = choices(partial, limit)
	end
	if type(choices) == "table" then
		-- Direct array reference
		local items = {}
		for i = 1, #choices do
			local c = choices[i]
			items[i] = { key = c }
		end
		return fuzzy.suggest(items, partial, { limit = limit })
	end
	-- Fallback for other types
	return fuzzy.suggest(choices or {}, partial, { limit = limit })
end

--- Get completion suggestions at a given caret position.<br>
--- Returns ranked suggestions based on context (command name, flag, argument value).
---@param self Console.IntelliSense
---@param line string The current command line
---@param caret integer|nil Caret position (defaults to end of line)
---@return Console.IntelliSense.Suggestion[] suggestions Array of ranked suggestions
function IntelliSense.suggest_at(self, line, caret)
	caret = caret or (#line + 1)
	local ctx = IntelliSense.context_at(self, line, caret)
	local limit = self.opts.suggestion_limit
	local out = {}

	-- Inside string: minimal suggestions (escape, closing quote) or none
	if ctx.kind == "InsideString" then
		-- Optionally suggest escape sequences or nothing
		return {}
	end

	-- Command name suggestions
	if ctx.kind == "CommandName" then
		local items = {}
		for name, cmd in next, self.console.commands do
			table_insert(items, { key = name, meta = { desc = cmd.desc } })
			if cmd.aliases then
				local aliases = cmd.aliases
				for i = 1, #aliases do
					local a = aliases[i]
					table_insert(items, { key = a, meta = { desc = "(alias for " .. name .. ")" } })
				end
			end
		end
		local results = fuzzy.suggest(items, ctx.partial or "", { limit = limit })
		for i = 1, #results do
			local r = results[i]
			local highlighted = fuzzy.best_match_and_highlight(ctx.partial or "", r.item.key,
				{ highlight = { open = "<b>", close = "</b>" } }).highlighted
			out[#out + 1] = { key = r.item.key, label = highlighted, score = r.score, meta = r.item.meta }
		end
		return out
	end

	-- Flag suggestions
	if ctx.kind == "Flag" then
		local flags = {}
		if ctx.cmd and ctx.cmd.args then
			local args = ctx.cmd.args
			-- gather flags from cmd.args that have flag property
			for i = 1, #args do
				local a = args[i]
				if a.flag then flags[#flags + 1] = { key = a.flag, meta = { desc = a.desc } } end
			end
		end
		-- fallback: suggest nothing if no flags
		if #flags == 0 then return {} end
		local results = fuzzy.suggest(flags, ctx.partial or "", { limit = limit })
		for i = 1, #results do
			local r = results[i]
			out[#out + 1] = { key = r.item.key, label = r.item.key, score = r.score, meta = r.item.meta }
		end
		return out
	end

	-- Argument value suggestions
	if ctx.kind == "ArgValue" then
		local cmd = ctx.cmd
		local arg_index = ctx.arg_index
		local partial = ctx.partial or ""
		if not cmd then
			-- no command resolved: suggest commands
			return IntelliSense.suggest_at(self, line, 1)
		end
		-- Check if command disables argument autocompletion
		if cmd.no_arg_suggest then
			return {}
		end
		local spec
		if cmd.args then
			spec = cmd.args[arg_index]
		end
		-- if spec has custom suggest hook
		if spec and spec.suggest then
			local items = spec.suggest({ console = self.console, cmd = cmd, arg_index = arg_index }, partial) or {}
			local results = fuzzy.suggest(items, partial, { limit = limit })
			for i = 1, #results do
				local r = results[i]
				local highlighted = fuzzy.best_match_and_highlight(partial, r.item.key,
					{ highlight = { open = "<b>", close = "</b>" } }).highlighted
				out[#out + 1] = { key = r.item.key, label = highlighted, score = r.score, meta = spec }
			end
			return out
		end
		-- type-aware suggestions
		if spec and spec.type == "bool" then
			local results = suggest_booleans(limit, partial)
			for i = 1, #results do
				local r = results[i]
				out[#out + 1] = {
					key = r.item.key,
					label = r.item.key,
					score = r.score or 1.0,
					meta = { type = "bool" }
				}
			end
			return out
		end
		if spec and spec.type == "enum" and spec.choices then
			local results = suggest_enum(spec.choices, limit, partial)
			for i = 1, #results do
				local r = results[i]
				out[#out + 1] = { key = r.item.key, label = r.item.key, score = r.score, meta = spec }
			end
			return out
		end
		-- file path hook
		if spec and spec.type == "path" and self.opts.file_suggest_hook then
			local items = self.opts.file_suggest_hook(partial) or {}
			local results = fuzzy.suggest(items, partial, { limit = limit })
			for i = 1, #results do
				local r = results[i]
				out[#out + 1] = { key = r.item.key, label = r.item.key, score = r.score, meta = { type = "path" } }
			end
			return out
		end
		-- fallback: suggest from command-specific vocabulary if provided
		if cmd and cmd.arg_vocab and cmd.arg_vocab[arg_index] then
			local items = {}
			local vocab = cmd.arg_vocab[arg_index]
			for i = 1, #vocab do
				local v = vocab[i]
				items[#items + 1] = { key = v }
			end
			local results = fuzzy.suggest(items, partial, { limit = limit })
			for i = 1, #results do
				local r = results[i]
				out[#out + 1] = { key = r.item.key, label = r.item.key, score = r.score, meta = { type = "vocab" } }
			end
			return out
		end
		-- global fallback: suggest command names if first arg and there's partial text
		if arg_index == 1 and partial == "" then
			-- For other string-type arguments with no partial text, don't suggest anything
			if spec and spec.type == "string" then
				return {}
			end
			-- For other cases, suggest subcommands or common verbs
			return {}
		end
		-- last fallback: fuzzy match against all registered commands and their keys to help user
		-- Only suggest commands if there's actual partial text to match against
		if partial ~= "" then
			local items = {}
			for name, cmd2 in next, self.console.commands do items[#items + 1] = { key = name } end
			local results = fuzzy.suggest(items, partial, { limit = limit })
			for i = 1, #results do
				local r = results[i]
				out[#out + 1] = { key = r.item.key, label = r.item.key, score = r.score, meta = { type = "command" } }
			end
		end
		return out
	end

	return {}
end

--- Get the best completion string for Tab key at caret position.<br>
--- Returns the common prefix of all suggestions, or the best match.
---@param self Console.IntelliSense
---@param line string The current command line
---@param caret integer|nil Caret position (defaults to end of line)
---@return string|nil completion The completion string to insert, or nil
function IntelliSense.complete_at(self, line, caret)
	local suggestions = IntelliSense.suggest_at(self, line, caret)
	if #suggestions == 0 then return end
	-- if exact match exists, return it
	for i = 1, #suggestions do
		local s = suggestions[i]
		if s.key == (IntelliSense.context_at(self, line, caret).partial or "") then return s.key end
	end
	-- compute common prefix
	local cp = suggestions[1].key
	for i = 2, #suggestions do
		local a, b = cp, suggestions[i].key
		local j = 1
		local n = math_min(#a, #b)
		while j <= n and string_sub(a, j, j) == string_sub(b, j, j) do j = j + 1 end
		cp = string_sub(a, 1, j - 1)
	end
	local partial = IntelliSense.context_at(self, line, caret).partial or ""
	if #cp > #partial then return cp end
	return suggestions[1].key
end

--[[ Quick tests
if true then
	-- Test Console.new
	local console = Console.new({
		suggestion_limit = 5,
		history_limit = 50,
		case_sensitive = false
	})
	assert(console ~= nil, "Console.new should return a console instance")
	assert(console.opts.suggestion_limit == 5, "Console should set suggestion_limit")
	assert(console.opts.history_limit == 50, "Console should set history_limit")
	assert(console.opts.case_sensitive == false, "Console should set case_sensitive")

	-- Test command registration
	local test_cmd_called = false
	console:register({
		name = "test",
		desc = "Test command",
		args = {
			{ name = "arg1", type = "string", desc = "First argument" },
			{ name = "arg2", type = "number", optional = true,        default = 42 }
		},
		handler = function(ctx, args)
			test_cmd_called = true
			return "test result: " .. args.arg1 .. ", " .. tostring(args.arg2)
		end
	})
	assert(console.commands["test"] ~= nil, "Command should be registered")
	assert(console.commands["test"].desc == "Test command", "Command description should be set")

	-- Test command aliases
	console:register({
		name = "aliased",
		aliases = { "alias1", "alias2" },
		desc = "Aliased command",
		handler = function() return "aliased result" end
	})
	assert(console.alias_map["alias1"] == "aliased", "Alias should be mapped")
	assert(console.alias_map["alias2"] == "aliased", "Second alias should be mapped")

	-- Test resolve_name
	assert(console:resolve_name("test") == "test", "resolve_name should return existing command")
	assert(console:resolve_name("alias1") == "aliased", "resolve_name should resolve alias")
	assert(console:resolve_name("nonexistent") == nil, "resolve_name should return nil for unknown command")

	-- Test tokenize_line
	local tokens = tokenize_line('hello "quoted string" world')
	assert(#tokens == 3, "tokenize_line should return 3 tokens")
	assert(tokens[1] == "hello", "First token should be 'hello'")
	assert(tokens[2] == "quoted string", "Second token should be quoted string")
	assert(tokens[3] == "world", "Third token should be 'world'")

	-- Test tokenize_line with escapes
	local escape_tokens = tokenize_line('hello "quoted \\"string\\"" world')
	assert(escape_tokens[2] == 'quoted "string"', "tokenize_line should handle escapes")

	-- Test parse_arg_value
	local string_spec = { type = "string" }
	local number_spec = { type = "number" }
	local int_spec = { type = "int" }
	local bool_spec = { type = "bool" }
	local enum_spec = { type = "enum", choices = { "opt1", "opt2", "opt3" } }

	local val, err = parse_arg_value(string_spec, "test")
	assert(val == "test", "String parsing should return original value")
	assert(err == nil, "String parsing should not error")

	val, err = parse_arg_value(number_spec, "42.5")
	assert(val == 42.5, "Number parsing should convert to number")
	assert(err == nil, "Number parsing should not error")

	val, err = parse_arg_value(number_spec, "invalid")
	assert(val == nil, "Invalid number should return nil")
	assert(err == "expected number", "Invalid number should return error")

	val, err = parse_arg_value(int_spec, "42.7")
	assert(val == 42, "Int parsing should floor")
	assert(err == nil, "Int parsing should not error")

	val, err = parse_arg_value(bool_spec, "true")
	assert(val == true, "Bool parsing should handle 'true'")
	val, err = parse_arg_value(bool_spec, "1")
	assert(val == true, "Bool parsing should handle '1'")
	val, err = parse_arg_value(bool_spec, "false")
	assert(val == false, "Bool parsing should handle 'false'")
	val, err = parse_arg_value(bool_spec, "0")
	assert(val == false, "Bool parsing should handle '0'")

	val, err = parse_arg_value(enum_spec, "opt1")
	assert(val == "opt1", "Enum parsing should return valid choice")
	val, err = parse_arg_value(enum_spec, "invalid")
	assert(val == nil, "Invalid enum choice should return nil")
	assert(err == "invalid choice", "Invalid enum choice should return error")

	-- Test parse_line
	local parsed, err = console:parse_line("test hello")
	assert(parsed ~= nil, "parse_line should parse valid command")
	assert(parsed.name == "test", "parse_line should set command name")
	assert(parsed.args.arg1 == "hello", "parse_line should parse arguments")
	assert(parsed.args.arg2 == 42, "parse_line should use default for optional args")

	parsed, err = console:parse_line("test hello 100")
	assert(parsed.args.arg2 == 100, "parse_line should parse optional args when provided")

	parsed, err = console:parse_line("nonexistent cmd")
	assert(parsed ~= nil, "parse_line should handle unknown commands")
	assert(parsed.cmd == nil, "Unknown command should have nil cmd")
	assert(parsed.args._rest ~= nil, "Unknown command should have _rest args")

	parsed, err = console:parse_line("")
	assert(parsed == nil, "parse_line should return nil for empty input")
	assert(err == "empty", "parse_line should return 'empty' error for empty input")

	-- Test execute_parsed
	local result, error = console:execute_parsed(parsed)
	assert(result == nil, "Executing unknown command should return nil")
	assert(error ~= nil, "Executing unknown command should return error")

	parsed, err = console:parse_line("test hello")
	result, error = console:execute_parsed(parsed)
	assert(result == "test result: hello, 42", "Command should execute correctly")
	assert(test_cmd_called, "Command handler should be called")
	assert(error == nil, "Command execution should not error")

	-- Test input_line (combined parse and execute)
	test_cmd_called = false
	result, error = console:input_line("test world 123")
	assert(result == "test result: world, 123", "input_line should work")
	assert(test_cmd_called, "input_line should call handler")

	-- Test history
	local entry = console:history_prev()
	assert(entry == "test world 123", "history_prev should return last command")
	entry = console:history_next()
	assert(entry == "", "history_next should return empty string at start")

	-- Test suggestions
	local suggestions = console:suggest("te")
	assert(#suggestions > 0, "suggest should return suggestions")
	assert(suggestions[1].key ~= nil, "suggestions should have keys")

	-- Test completion
	local completion = console:complete("te")
	assert(completion ~= nil, "complete should return completion")

	-- Test help
	local help_text = console:help()
	assert(string_find(help_text, "test", 1, true), "help should list commands")

	local specific_help = console:help("test")
	assert(string_find(specific_help, "Test command", 1, true), "help should show command details")

	-- Test IntelliSense
	local intellisense = IntelliSense.new(console, { suggestion_limit = 3 })
	assert(intellisense ~= nil, "IntelliSense.new should return instance")
	assert(intellisense.console == console, "IntelliSense should be bound to console")

	-- Test IntelliSense tokenization
	local tokens = IntelliSense.tokenize_with_positions('test "hello world"')
	assert(#tokens == 2, "tokenize_with_positions should return 2 tokens")
	assert(tokens[1].text == "test", "First token should be 'test'")
	assert(tokens[2].text == "hello world", "Second token should be quoted string")
	assert(tokens[2].quoted == true, "Quoted token should have quoted flag")

	-- Test find_token_at
	local idx, inside = IntelliSense.find_token_at(tokens, 3, #("test"))
	assert(idx == 1, "find_token_at should find first token")
	assert(inside == true, "find_token_at should detect inside token")

	-- Test context_at
	local ctx = IntelliSense.context_at(intellisense, "test he", 6)
	assert(ctx.kind == "ArgValue", "context_at should identify argument context")
	assert(ctx.cmd ~= nil, "context should resolve command")

	-- Test suggest_at
	local suggestions = IntelliSense.suggest_at(intellisense, "test", 4)
	assert(#suggestions > 0, "suggest_at should return suggestions")

	-- Test complete_at
	local completion = IntelliSense.complete_at(intellisense, "te", 2)
	assert(completion ~= nil, "complete_at should return completion")

	-- Test register_defaults
	console:register_defaults()
	assert(console.commands["help"] ~= nil, "register_defaults should register help")
	assert(console.commands["echo"] ~= nil, "register_defaults should register echo")

	-- Test built-in commands
	result, error = console:input_line("echo hello world")
	assert(result == "hello world", "echo command should work")

	result, error = console:input_line("help")
	assert(string_find(result, "Available commands", 1, true), "help should list commands")

	-- Test persistence
	local state = console:save_state()
	assert(state ~= nil, "save_state should return state")
	assert(state.history ~= nil, "state should include history")
	assert(state.engine ~= nil, "state should include engine state")

	local console2 = Console.new()
	console2:load_state(state)
	assert(#console2.history == #console.history, "load_state should restore history")

	-- Test edge cases
	-- Command with no arguments
	console:register({
		name = "noargs",
		desc = "No args command",
		handler = function() return "no args result" end
	})
	result, error = console:input_line("noargs")
	assert(result == "no args result", "Command with no args should work")

	-- Command with context check
	console:register({
		name = "protected",
		desc = "Protected command",
		context_check = function(ctx)
			return ctx.admin == true, "admin required"
		end,
		handler = function() return "protected result" end
	})
	result, error = console:input_line("protected")
	assert(result == nil, "Protected command should fail without context")
	assert(string_find(error, "admin required", 1, true), "Should return context check error")

	result, error = console:input_line("protected", { admin = true })
	assert(result == "protected result", "Protected command should succeed with proper context")

	-- Test error handling in handlers
	console:register({
		name = "errorcmd",
		desc = "Error command",
		handler = function() error("test error") end
	})
	result, error = console:input_line("errorcmd")
	assert(result == nil, "Error command should return nil")
	assert(string_find(error, "handler error", 1, true), "Should return handler error")

	-- Test complex argument parsing
	console:register({
		name = "complex",
		desc = "Complex command",
		args = {
			{ name = "str",    type = "string" },
			{ name = "num",    type = "number" },
			{ name = "flag",   type = "bool",  optional = true },
			{ name = "choice", type = "enum",  choices = { "a", "b", "c" }, optional = true }
		},
		handler = function(ctx, args)
			return string_format("str=%s, num=%s, flag=%s, choice=%s",
				args.str, tostring(args.num), tostring(args.flag), args.choice or "nil")
		end
	})
	result, error = console:input_line('complex "test string" 123 true b')
	assert(result == "str=test string, num=123, flag=true, choice=b", "Complex parsing should work")

	-- Test history limit
	for i = 1, 60 do
		console:input_line("echo " .. tostring(i))
	end
	assert(#console.history <= console.opts.history_limit, "History should respect limit")
end
--]]

-- Export
return {
	Console = Console,
	IntelliSense = IntelliSense,
}
