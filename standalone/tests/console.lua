-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for console.lua.
-- Run from this directory:
--   lua console.lua
--   luajit console.lua

-- Bootstrap: make requires work from tests/ subdir with plain lua/luajit.
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
	local root
	for _, c in ipairs({ dir, dir .. "../", dir .. "../..//", dir .. "../../..//", "./", "../", "../../" }) do
		if isfile(c .. "standalone/bits.lua") then
			root = c
			break
		end
	end
	root = root or dir .. "../"
	if package then
		package.path = dir ..
			"../?.lua;" ..
			dir ..
			"../?/init.lua;" ..
			dir ..
			"?.lua;" ..
			dir ..
			"?/init.lua;" ..
			root ..
			"?.lua;" ..
			root ..
			"?/init.lua;" ..
			root ..
			"standalone/?.lua;" ..
			root ..
			"math/?.lua;" ..
			root ..
			"collections/?.lua;" ..
			root ..
			"benchmark/?.lua;" ..
			root ..
			"timer/?.lua;" ..
			root ..
			"autocompleter/?.lua;" ..
			root ..
			"permission/?.lua;" ..
			root ..
			"chat_commander/?.lua;" ..
			root .. "vm/?.lua;" .. root .. "require_finder/?.lua;" .. root .. "inventory/?.lua;" .. package.path
	end
	local searchers = package.searchers or package.loaders
	if searchers then
		table.insert(searchers, 2, function(mod)
			if mod:sub(1, 3) == "../" or mod:sub(1, 2) == "./" then
				local clean = mod:gsub("^%./", ""):gsub("^%.%.%/", ""):gsub("^%.%.%/", "")
				local tries = { dir .. "../" .. clean .. ".lua", dir .. "../" .. clean .. "/init.lua", root ..
				clean .. ".lua", root .. clean .. "/init.lua" }
				for _, f in ipairs(tries) do
					if isfile(f) then
						local chunk, err = loadfile(f)
						if chunk then return chunk, f end
					end
				end
			end
			return nil
		end)
	end
end
local lib = require "console"
-- Bridging: file-locals used by tests mapped to module exports.
local Console = lib.Console
local IntelliSense = lib.IntelliSense
local tokenize_line = lib.tokenize_line
local parse_arg_value = lib.parse_arg_value
local string_find = string.find
local string_format = string.format
local string_sub = string.sub
local string_lower = string.lower
-- TODO(manual): the following were file-locals with no direct export;
-- verify and export or inline as needed: a, aliases, b, c, choices, cmd, limit, name, parse_arg_value, s, text, tokenize_line

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
		handler = function() return error("test error") end
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

print("All tests passed")
