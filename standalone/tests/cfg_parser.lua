-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for cfg_parser.lua.
-- Run from this directory:
--   lua cfg_parser.lua
--   luajit cfg_parser.lua

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
local lib = require "cfg_parser"
-- Bridging: file-locals used by tests mapped to module exports.
local M = lib
-- TODO(manual): the following were file-locals with no direct export;
-- verify and export or inline as needed: entries, parse, whitespace

if true then
	local testCaseList = {
		-- Basic delimiter tests
		{
			name = "Multiple semicolons",
			content = ";;;;;;",
			expectedCount = 0,
			expectError = false,
		},
		{ name = "Spaced semicolons",                    content = "; ; ; ; ;",                                                                                                                                                                                                                                                                                                                                                                                                           expectedCount = 0, expectError = false },
		{ name = "Multiple newlines",                    content = "\n\n\n\n",                                                                                                                                                                                                                                                                                                                                                                                                            expectedCount = 0, expectError = false },
		{ name = "Mixed delimiters",                     content = "; ; \n ; ;",                                                                                                                                                                                                                                                                                                                                                                                                          expectedCount = 0, expectError = false },
		{ name = "Key without value (semicolon)",        content = "\"key\" ;",                                                                                                                                                                                                                                                                                                                                                                                                           expectedCount = 0, expectError = false },
		{ name = "Key without value (newline)",          content = "\"key\" \n",                                                                                                                                                                                                                                                                                                                                                                                                          expectedCount = 0, expectError = false },
		{ name = "Leading/trailing delimiters",          content = "; \"key\" \"value\" ;",                                                                                                                                                                                                                                                                                                                                                                                               expectedCount = 1, expectError = false },
		{ name = "Basic key-value pairs",                content = "\"key1\" \"value1\"\n\"key2\" \"value2\"",                                                                                                                                                                                                                                                                                                                                                                            expectedCount = 2, expectError = false },
		{ name = "Semicolon delimiters",                 content = "\"key1\" \"value1\"; \"key2\" \"value2\"",                                                                                                                                                                                                                                                                                                                                                                            expectedCount = 2, expectError = false },
		{ name = "Mixed delimiters with values",         content = "\"key1\" \"value1\"; \"key2\" \"value2\"\n\"key3\" \"value3\"",                                                                                                                                                                                                                                                                                                                                                       expectedCount = 3, expectError = false },

		-- Block tests
		{ name = "Simple block",                         content = "\"blockname\" {\n  \"inner_key\" \"inner_value\"\n}",                                                                                                                                                                                                                                                                                                                                                                 expectedCount = 1, expectError = false },
		{ name = "Nested blocks",                        content = "\"outer\" {\n  \"inner\" {\n    \"deep_key\" \"deep_value\"\n  }\n}",                                                                                                                                                                                                                                                                                                                                                 expectedCount = 1, expectError = false },
		{ name = "Multiple blocks",                      content = "\"block1\" { \"key1\" \"val1\" }\n\"block2\" { \"key2\" \"val2\" }",                                                                                                                                                                                                                                                                                                                                                  expectedCount = 2, expectError = false },
		{ name = "Block with semicolon delimiter",       content = "\"block\" { \"key\" \"value\" }; \"other\" \"data\"",                                                                                                                                                                                                                                                                                                                                                                 expectedCount = 2, expectError = false },

		-- Comment tests
		{ name = "Line comments",                        content = "// This is a comment\n\"key\" \"value\" // Another comment",                                                                                                                                                                                                                                                                                                                                                          expectedCount = 1, expectError = false },
		{ name = "Block comments",                       content = "/* Block comment */\"key\" \"value\"",                                                                                                                                                                                                                                                                                                                                                                                expectedCount = 1, expectError = false },
		{ name = "Multiline block comments",             content = "/* Comment\n spanning\n multiple lines */\"key\" \"value\"",                                                                                                                                                                                                                                                                                                                                                          expectedCount = 1, expectError = false },
		{ name = "Comments only",                        content = "// Line comment\n/* Block comment */",                                                                                                                                                                                                                                                                                                                                                                                expectedCount = 0, expectError = false },
		{ name = "Comments with delimiters",             content = "; // comment after semicolon\n",                                                                                                                                                                                                                                                                                                                                                                                      expectedCount = 0, expectError = false },

		-- Number tests
		{ name = "Integer numbers",                      content = "\"int_key\" 42\n\"neg_int\" -17",                                                                                                                                                                                                                                                                                                                                                                                     expectedCount = 2, expectError = false },
		{ name = "Float numbers",                        content = "\"float_key\" 3.14159\n\"neg_float\" -2.5",                                                                                                                                                                                                                                                                                                                                                                           expectedCount = 2, expectError = false },
		{ name = "Mixed numbers and strings",            content = "\"num\" 123; \"str\" \"hello\"",                                                                                                                                                                                                                                                                                                                                                                                      expectedCount = 2, expectError = false },
		{ name = "Zero and negative zero",               content = "\"zero\" 0\n\"neg_zero\" -0",                                                                                                                                                                                                                                                                                                                                                                                         expectedCount = 2, expectError = false },

		-- Escape sequence tests
		{ name = "Escaped newlines",                     content = "\"key\" \"value\\nwith\\nnewlines\"",                                                                                                                                                                                                                                                                                                                                                                                 expectedCount = 1, expectError = false },
		{ name = "Escaped tabs",                         content = "\"key\" \"value\\twith\\ttabs\"",                                                                                                                                                                                                                                                                                                                                                                                     expectedCount = 1, expectError = false },
		{ name = "Escaped quotes",                       content = "\"key\" \"value\\\"with\\\"quotes\"",                                                                                                                                                                                                                                                                                                                                                                                 expectedCount = 1, expectError = false },
		{ name = "Escaped backslashes",                  content = "\"key\" \"value\\\\with\\\\backslashes\"",                                                                                                                                                                                                                                                                                                                                                                            expectedCount = 1, expectError = false },
		{ name = "Mixed escape sequences",               content = "\"key\" \"\\n\\t\\\"\\\\\"",                                                                                                                                                                                                                                                                                                                                                                                          expectedCount = 1, expectError = false },

		-- Whitespace tests
		{ name = "Tabs and spaces",                      content = "\t\"key\"\t\"value\"\t  \"other\"\t\"data\"",                                                                                                                                                                                                                                                                                                                                                                         expectedCount = 2, expectError = false },
		{ name = "Trailing whitespace",                  content = "\"key\" \"value\"   \n  \t",                                                                                                                                                                                                                                                                                                                                                                                          expectedCount = 1, expectError = false },
		{ name = "Empty lines with whitespace",          content = "  \t  \n\"key\" \"value\"\n  \t  ",                                                                                                                                                                                                                                                                                                                                                                                   expectedCount = 1, expectError = false },

		-- Complex mixed tests
		{ name = "Complex CFG with blocks and comments", content = "// Server config\n\"hostname\" \"My Server\"\n\"maxplayers\" 32\n/* Game settings */\n\"gamemode\" \"sandbox\"\n\"map\" \"gm_construct\"\n\"groups\" {\n  \"admin\" {\n    \"inherit\" \"superadmin\"\n    \"can_target\" \"%admin%\"\n  }\n  \"vip\" {\n    \"inherit\" \"user\"\n    \"can_target\" \"!%admin%\"\n  }\n}\n\"commands\" {\n  \"kick\" \"admin\"\n  \"ban\" \"superadmin\"\n  \"slap\" \"admin\"\n}", expectedCount = 6, expectError = false },

		-- Edge case tests
		{ name = "Empty string",                         content = "",                                                                                                                                                                                                                                                                                                                                                                                                                    expectedCount = 0, expectError = false },
		{ name = "Only whitespace",                      content = "   \t\n  \t  ",                                                                                                                                                                                                                                                                                                                                                                                                       expectedCount = 0, expectError = false },
		{ name = "Single quotes (should fail)",          content = "'key' 'value'",                                                                                                                                                                                                                                                                                                                                                                                                       expectedCount = 0, expectError = true },
		{ name = "Unmatched quotes",                     content = "\"key\" \"value",                                                                                                                                                                                                                                                                                                                                                                                                     expectedCount = 0, expectError = true },
		{ name = "Invalid characters",                   content = "\"key\" \"value$@#%^&*()\"",                                                                                                                                                                                                                                                                                                                                                                                          expectedCount = 1, expectError = false },
		{
			name = "Very long values",
			content = "\"key\" \"" .. string.rep("a", 1000) .. "\"",
			expectedCount = 1,
			expectError = false,
		},
		{ name = "Unicode characters",         content = "\"unicode\" \"héllo wörld\"",                                                                                                                                                                                                                       expectedCount = 1, expectError = false },

		-- Real-world game config examples
		{ name = "Source engine style config", content = "// Counter-Strike config\n\"name\" \"Player\"\n\"cl_righthand\" \"1\"\n\"sensitivity\" \"2.5\"\n\"volume\" \"0.8\"\n\"fps_max\" \"0\"\n\"net_graph\" \"1\"\n\"cl_showfps\" \"1\"",                                                                  expectedCount = 7, expectError = false },
		{ name = "GMod style config",          content = "// Garry's Mod server config\n  hostname  \"My GMod Server\" \n sv_password \" \"\n\"rcon_password\" \"admin123\"\n\"sv_loadingurl\" \"http://example.com/loading.html\"\n\"gamemode\" \"terrortown\"\n\"map\" \"ttt_clue_se\"\n\"maxplayers\" 16", expectedCount = 7, expectError = false },
	}

	local passed = 0
	local failed = 0
	print("=== CFG Parser Tests ===\n")
	for _, testCase in next, testCaseList do
		local parseResult = M.parse(testCase.content)
		if parseResult.ok and parseResult.value then
			local actualCount = #parseResult.value.entries
			if actualCount == testCase.expectedCount then
				if not testCase.expectError then
					passed = passed + 1
				else
					-- This test was expected to fail but passed - count as failure
					print("Testing: " .. testCase.name)
					print("Content: " .. testCase.content)
					print("UNEXPECTED PASS: Test was expected to fail but it passed!")
					print("---")
					failed = failed + 1
				end
			else
				if testCase.expectError then
					-- This test was expected to fail and did fail - count as passed
					passed = passed + 1
				else
					print("Testing: " .. testCase.name)
					print("Content: " .. testCase.content)
					print("FAIL: Expected " .. testCase.expectedCount .. ", got " .. actualCount)
					if #parseResult.value.entries > 0 then
						print("Entries: " .. tostring(#parseResult.value.entries) .. " entries")
					end
					print("---")
					failed = failed + 1
				end
			end
		else
			if testCase.expectError then
				-- This test was expected to fail and did fail - count as passed
				passed = passed + 1
			else
				print("Testing: " .. testCase.name)
				print("Content: " .. testCase.content)
				print("ERROR: " .. parseResult.error)
				print("---")
				failed = failed + 1
			end
		end
	end
	print("\n=== Results ===")
	print("Passed: " .. tostring(passed))
	print("Failed: " .. tostring(failed))
	print("Total: " .. tostring(passed + failed))
end
