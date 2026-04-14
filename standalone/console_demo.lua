-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- REPL-style terminal demo with caret-aware intellisense
-- Requires: fuzzy.lua, console.lua, console_intellisense.lua
-- Run on POSIX/Bash terminal: lua terminal_demo.lua

-- Import dependencies
local console = require "console"
--local IntelliSense = require "console_intellisense"
local Console = console.Console
local IntelliSense = console.IntelliSense
-- fuzzy is used by those modules; no direct require needed here

-- Terminal control helpers (POSIX)
local function enable_raw_mode()
	os.execute("stty raw -echo -icanon isig")
end
local function disable_raw_mode()
	os.execute("stty sane")
end

local function clear_line()
	io.write("\27[2K\r")
end

local function move_cursor_up(n)
	io.write(string.format("\27[%dA", n))
end
local function move_cursor_down(n)
	io.write(string.format("\27[%dB", n))
end

local function hide_cursor() io.write("\27[?25l") end
local function show_cursor() io.write("\27[?25h") end

-- Simple ANSI highlight helper
local function highlight(text)
	return "\27[1;36m" .. text .. "\27[0m"
end
local function dim(text)
	return "\27[2m" .. text .. "\27[0m"
end

-- Setup console and intellisense
local console = Console.new()
console:register_defaults()

-- Example commands
console:register {
	name = "spawn",
	desc = "Spawn an entity",
	args = {
		{ name = "type",    type = "enum", choices = { "zombie", "skeleton", "npc", "vehicle" }, desc = "entity type" },
		{ name = "count",   type = "int",  optional = true,                                      desc = "how many" },
		{ name = "hostile", type = "bool", optional = true,                                      desc = "is hostile" }
	},
	handler = function(_, args)
		return string.format("spawned %s x%d hostile=%s", args.type or "?", args.count or 1, tostring(args.hostile))
	end
}

console:register {
	name = "loadmap",
	desc = "Load a map file",
	args = {
		{ name = "path", type = "path", desc = "map file path" }
	},
	handler = function(_, args) return "loaded " .. tostring(args.path) end
}

-- Example file suggestion hook
local function file_hook(prefix)
	local list = { "maps/arena.map", "maps/desert.map", "assets/skybox.hdr", "maps/arena_night.map" }
	local out = {}
	for i = 1, #list do out[i] = { key = list[i] } end
	return out
end

local int = IntelliSense.new(console, { file_suggest_hook = file_hook })

-- Input buffer state
local buffer = {}
local caret = 1 -- 1-based index into buffer (position between characters)
local suggestions = {}
local selected_suggestion = 1
local suggestion_count = 0

-- Helpers to convert buffer to string and update suggestions
local function buf_to_string()
	return table.concat(buffer)
end

local function update_suggestions()
	local line = buf_to_string()
	local caret_pos = caret
	suggestions = int:suggest_at(line, caret_pos)
	suggestion_count = #suggestions
	if suggestion_count == 0 then
		selected_suggestion = 1
	else
		if selected_suggestion > suggestion_count then selected_suggestion = suggestion_count end
	end
end

-- Render prompt, buffer, and suggestions
local function render()
	clear_line()
	io.write("> ")
	local s = buf_to_string()
	-- print buffer with caret
	local before = s:sub(1, caret - 1)
	local after = s:sub(caret)
	io.write(before)
	io.write("\27[7m") -- inverse for caret placeholder
	io.write((#after == 0) and " " or after:sub(1, 1))
	io.write("\27[0m")
	io.write(after:sub(2))
	-- suggestions below
	io.write("\n")
	if suggestion_count > 0 then
		local max_show = math.min(6, suggestion_count)
		for i = 1, max_show do
			local sug = suggestions[i]
			local marker = (i == selected_suggestion) and "→" or " "
			local label = sug.label or sug.key
			local meta = sug.meta and (sug.meta.type or sug.meta.desc) or ""
			io.write(string.format("%s %s %s\n", marker, highlight(sug.key), dim(meta or "")))
		end
		if suggestion_count > max_show then
			io.write(dim(string.format("  ... %d more\n", suggestion_count - max_show)))
		end
	else
		io.write(dim("  (no suggestions)\n"))
	end
	-- move cursor back up to input line
	move_cursor_up(1 + (suggestion_count > 0 and math.min(6, suggestion_count) or 1))
	-- reposition cursor to caret
	local prompt_len = 2 -- "> "
	local col = prompt_len + caret - 1
	io.write(string.format("\27[%dG", col))
	io.flush()
end

-- Completion: apply selected suggestion into buffer at caret context
local function apply_completion()
	if suggestion_count == 0 then return end
	local sug = suggestions[selected_suggestion]
	if not sug then return end
	local line = buf_to_string()
	local ctx = int.context_at(line, caret)
	local insert_text = sug.key
	if ctx.kind == "CommandName" then
		-- replace first token (or insert)
		local tokens = IntelliSense.tokenize_with_positions(line)
		if #tokens >= 1 then
			local t = tokens[1]
			-- replace token text in buffer
			for i = t.start, t.finish do buffer[i] = nil end
			-- shift and insert
			local prefix = line:sub(1, t.start - 1)
			local suffix = line:sub(t.finish + 1)
			buffer = {}
			for c in prefix:gmatch(".") do table.insert(buffer, c) end
			for c in insert_text:gmatch(".") do table.insert(buffer, c) end
			for c in suffix:gmatch(".") do table.insert(buffer, c) end
			caret = (prefix:len() + insert_text:len() + 1)
		else
			-- insert at start
			for c in insert_text:gmatch(".") do table.insert(buffer, c) end
			caret = insert_text:len() + 1
		end
	elseif ctx.kind == "ArgValue" then
		-- replace current token or insert at caret
		local tokens = IntelliSense.tokenize_with_positions(line)
		local idx, inside = IntelliSense.find_token_at(tokens, caret, #line)
		if idx <= #tokens and inside then
			local t = tokens[idx]
			-- replace token text
			local prefix = line:sub(1, t.start - 1)
			local suffix = line:sub(t.finish + 1)
			buffer = {}
			for c in prefix:gmatch(".") do table.insert(buffer, c) end
			for c in insert_text:gmatch(".") do table.insert(buffer, c) end
			for c in suffix:gmatch(".") do table.insert(buffer, c) end
			caret = prefix:len() + insert_text:len() + 1
		else
			-- insert at caret position
			for c in insert_text:gmatch(".") do
				table.insert(buffer, caret, c); caret = caret + 1
			end
		end
	else
		-- default: insert at caret
		for c in insert_text:gmatch(".") do
			table.insert(buffer, caret, c); caret = caret + 1
		end
	end
	update_suggestions()
end

-- Key reading loop
local function read_key()
	local ch = io.read(1)
	if not ch then return nil end
	local byte = string.byte(ch)
	if byte == 27 then
		-- escape sequence
		local rest = io.read(2) or ""
		return ch .. rest
	end
	return ch
end

-- Main interactive loop
local function repl()
	enable_raw_mode()
	hide_cursor()
	buffer = {}
	caret = 1
	update_suggestions()
	render()
	while true do
		local key = read_key()
		if not key then break end
		if key == "\r" or key == "\n" then
			-- Enter: execute
			clear_line()
			show_cursor()
			disable_raw_mode()
			io.write("\n")
			local line = buf_to_string()
			if line == "exit" or line == "quit" then
				print("bye")
				return
			end
			local res, err = console:input_line(line, {})
			if err then print("Error:", err) else if res ~= nil then print(res) end end
			-- reset buffer
			enable_raw_mode()
			hide_cursor()
			buffer = {}
			caret = 1
			update_suggestions()
			render()
		elseif key == "\9" then
			-- Tab: complete (apply selected suggestion)
			apply_completion()
			render()
		elseif key == "\127" or key == "\8" then
			-- Backspace
			if caret > 1 then
				table.remove(buffer, caret - 1)
				caret = caret - 1
				update_suggestions()
				render()
			end
		elseif key == "\27[A" then
			-- Up arrow: history prev
			local h = console:history_prev()
			if h then
				buffer = {}
				for c in h:gmatch(".") do table.insert(buffer, c) end
				caret = #buffer + 1
				update_suggestions()
				render()
			end
		elseif key == "\27[B" then
			-- Down arrow: history next
			local h = console:history_next()
			buffer = {}
			for c in h:gmatch(".") do table.insert(buffer, c) end
			caret = #buffer + 1
			update_suggestions()
			render()
		elseif key == "\27[C" then
			-- Right arrow
			if caret <= #buffer then
				caret = caret + 1; render()
			end
		elseif key == "\27[D" then
			-- Left arrow
			if caret > 1 then
				caret = caret - 1; render()
			end
		elseif key == "\27[3~" then
			-- Delete
			if caret <= #buffer then
				table.remove(buffer, caret); update_suggestions(); render()
			end
		elseif key == "\t" then
			-- Tab (alternate)
			apply_completion()
			render()
		elseif key == "\27" then
			-- plain escape: clear buffer
			buffer = {}
			caret = 1
			update_suggestions()
			render()
		elseif key == "\4" then
			-- Ctrl-D: exit
			break
		elseif key == "\18" then
			-- Ctrl-R: refresh suggestions
			update_suggestions()
			render()
		elseif key == "\13" then
			-- CR (handled above)
		elseif key:match("^%C$") or key:match("^.$") then
			-- printable char
			-- insert at caret
			table.insert(buffer, caret, key)
			caret = caret + 1
			update_suggestions()
			render()
		else
			-- ignore other keys
		end
	end
	show_cursor()
	disable_raw_mode()
end

-- Start REPL
--print("Terminal console demo. Type 'help' for commands. Ctrl-D to exit.")
return repl
