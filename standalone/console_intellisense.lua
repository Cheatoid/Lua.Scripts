-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

local fuzzy = require "fuzzy"

-- Localized global functions for better performance
local setmetatable = setmetatable
local math_max = math.max
local math_min = math.min
local string_match = string.match
local string_sub = string.sub
local table_concat = table.concat
local table_insert = table.insert

---@class ConsoleIntelliSenseOptions
---@field suggestion_limit integer|nil
---@field case_sensitive boolean|nil
---@field file_suggest_hook fun(prefix: string): table|nil

---@class ConsoleIntelliSenseToken
---@field text string
---@field start integer
---@field finish integer
---@field quoted boolean
---@field quote_char string|nil

---@class ConsoleIntelliSenseContext
---@field kind "CommandName"|"ArgValue"|"Flag"|"InsideString"|"BetweenTokens"
---@field tokens ConsoleIntelliSenseToken[]
---@field token_index integer
---@field token ConsoleIntelliSenseToken|nil
---@field partial string
---@field cmd table|nil
---@field arg_index integer|nil

---@class ConsoleIntelliSenseSuggestion
---@field key string
---@field label string
---@field score number
---@field meta table|nil

---@class ConsoleIntelliSense
---@field console table
---@field opts ConsoleIntelliSenseOptions

local M = {}
M.__index = M

-- Create new IntelliSense bound to a console instance
---@param console table
---@param opts ConsoleIntelliSenseOptions|nil
---@return ConsoleIntelliSense
local function new(console, opts)
	opts = opts or {}
	return setmetatable({
		console = console,
		opts = {
			suggestion_limit = opts.suggestion_limit or 8,
			case_sensitive = opts.case_sensitive, -- nil = smart-case
			file_suggest_hook = opts.file_suggest_hook, -- function(prefix) -> { {key=path}, ... }
		}
	}, M)
end

M.new = new

-- Tokenize with positions and quote awareness
-- Returns list of tokens: {text, start, finish, quoted, quote_char}
---@param line string
---@return ConsoleIntelliSenseToken[]
local function tokenize_with_positions(line)
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
					table_insert(buf, c)
					escaped = false
					j = j + 1
				elseif c == "\\" then
					escaped = true
					j = j + 1
				elseif c == quote then
					break
				else
					table_insert(buf, c)
					j = j + 1
				end
			end
			local text = table_concat(buf)
			local finish = math_min(n, j) -- finish points at closing quote index or end
			table_insert(tokens, { text = text, start = i, finish = finish, quoted = true, quote_char = quote })
			i = finish + 1
		else
			local j = i
			while j <= n and not string_match(string_sub(line, j, j), "%s") do j = j + 1 end
			local text = string_sub(line, i, j - 1)
			table_insert(tokens, { text = text, start = i, finish = j - 1, quoted = false })
			i = j
		end
	end
	return tokens
end

M.tokenize_with_positions = tokenize_with_positions

-- Find token index and whether caret is inside token or between tokens
-- caret is 1-based index where 1 means before first char, n+1 means after last char
---@param tokens ConsoleIntelliSenseToken[]
---@param caret integer
---@param line_len integer
---@return integer token_index
---@return boolean inside
local function find_token_at(tokens, caret, line_len)
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

M.find_token_at = find_token_at

-- Determine context at caret
-- returns { kind = "CommandName"|"ArgValue"|"Flag"|"InsideString"|"BetweenTokens", cmd = cmd or nil, arg_index = n or nil, token = token or nil, partial = string }
---@param self ConsoleIntelliSense
---@param line string
---@param caret integer
---@return ConsoleIntelliSenseContext
local function context_at(self, line, caret)
	local tokens = tokenize_with_positions(line)
	local line_len = #line
	local idx, inside = find_token_at(tokens, caret, line_len)
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
	local next_arg_index = (#tokens >= 1) and (#tokens - 1) + 1 or 1
	-- but if caret is between tokens and directly after command, next_arg_index = 1
	ctx.arg_index = next_arg_index
	ctx.kind = "ArgValue"
	ctx.partial = ""
	return ctx
end

M.context_at = context_at

-- Suggestion helpers for types
---@param limit integer
---@param partial string
---@return table[] items
local function suggest_booleans(limit, partial)
	local items = { { key = "true" }, { key = "false" } }
	if partial == "" then return items end
	return fuzzy.suggest(items, partial, { limit = limit })
end

---@param choices string[]
---@param limit integer
---@param partial string
---@return table[] items
local function suggest_enum(choices, limit, partial)
	local items = {}
	for i = 1, #choices do
		local c = choices[i]
		table_insert(items, { key = c })
	end
	return fuzzy.suggest(items, partial, { limit = limit })
end

-- Main suggestion function at caret
-- returns array of suggestions: {key=string, label=string, score=number, meta={type=...,desc=...}, highlight=string}
---@param self ConsoleIntelliSense
---@param line string
---@param caret integer|nil
---@return ConsoleIntelliSenseSuggestion[]
local function suggest_at(self, line, caret)
	caret = caret or (#line + 1)
	local ctx = context_at(self, line, caret)
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
			items[#items + 1] = { key = name, meta = { desc = cmd.desc } }
			if cmd.aliases then
				local aliases = cmd.aliases
				for i = 1, #aliases do
					local a = aliases[i]
					items[#items + 1] = { key = a, meta = { desc = "(alias for " .. name .. ")" } }
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
		local tok = ctx.token and ctx.token.text or ""
		local cmd = self.console.commands
			[(self.console:resolve_name((self.console.token and self.console.token.text) or "") or "")]
		-- gather flags from cmd.args that have flag property
		local flags = {}
		if ctx.cmd and ctx.cmd.args then
			local args = ctx.cmd.args
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
			return suggest_at(self, line, 1)
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
				out[#out + 1] = { key = r.item.key or r.key, label = r.item and r.item.key or r.key, score = r.score or
				1.0, meta = { type = "bool" } }
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
		-- global fallback: suggest nothing or suggest command names if first arg
		if arg_index == 1 and partial == "" then
			-- suggest subcommands or common verbs
			return {}
		end
		-- last fallback: fuzzy match against all registered commands and their keys to help user
		local items = {}
		for name, cmd2 in next, self.console.commands do items[#items + 1] = { key = name } end
		local results = fuzzy.suggest(items, partial, { limit = limit })
		for i = 1, #results do
			local r = results[i]
			out[#out + 1] = { key = r.item.key, label = r.item.key, score = r.score, meta = { type = "command" } }
		end
		return out
	end

	return {}
end

M.suggest_at = suggest_at

-- Convenience: return best completion string for Tab at caret
---@param self ConsoleIntelliSense
---@param line string
---@param caret integer|nil
---@return string|nil completion
local function complete_at(self, line, caret)
	local suggestions = suggest_at(self, line, caret)
	if #suggestions == 0 then return nil end
	-- if exact match exists, return it
	for i = 1, #suggestions do
		local s = suggestions[i]
		if s.key == (context_at(self, line, caret).partial or "") then return s.key end
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
	local partial = context_at(self, line, caret).partial or ""
	if #cp > #partial then return cp end
	return suggestions[1].key
end

M.complete_at = complete_at

-- Export
return M
