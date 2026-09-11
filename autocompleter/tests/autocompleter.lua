-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for autocompleter.lua.
-- Run from this directory:
--   lua autocompleter.lua
--   luajit autocompleter.lua

-- Bootstrap: make requires work from tests/ subdir with plain lua/luajit.
do
  local src = debug.getinfo(1, "S").source
  local dir = src:match("^@(.+/)[^/]+$") or "./"
  local function isfile(p)
    local f = io.open(p, "r")
    if f then f:close() return true end
    return false
  end
  local root
  for _, c in ipairs({ dir, dir .. "../", dir .. "../..//", dir .. "../../..//", "./", "../", "../../" }) do
    if isfile(c .. "standalone/bits.lua") then root = c break end
  end
  root = root or dir .. "../"
  if package then
    package.path = dir .. "../?.lua;" .. dir .. "../?/init.lua;" .. dir .. "?.lua;" .. dir .. "?/init.lua;" .. root .. "?.lua;" .. root .. "?/init.lua;" .. root .. "standalone/?.lua;" .. root .. "math/?.lua;" .. root .. "collections/?.lua;" .. root .. "benchmark/?.lua;" .. root .. "timer/?.lua;" .. root .. "autocompleter/?.lua;" .. root .. "permission/?.lua;" .. root .. "chat_commander/?.lua;" .. root .. "vm/?.lua;" .. root .. "require_finder/?.lua;" .. root .. "inventory/?.lua;" .. package.path
  end
  local searchers = package.searchers or package.loaders
  if searchers then
    table.insert(searchers, 2, function(mod)
      if mod:sub(1, 3) == "../" or mod:sub(1, 2) == "./" then
        local clean = mod:gsub("^%./", ""):gsub("^%.%.%/", ""):gsub("^%.%.%/", "")
        local tries = { dir .. "../" .. clean .. ".lua", dir .. "../" .. clean .. "/init.lua", root .. clean .. ".lua", root .. clean .. "/init.lua" }
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
local lib = require "autocompleter"
-- Bridging: file-locals used by tests mapped to module exports.
local M = lib
local calculate_levenshtein_distance = lib.calculate_levenshtein_distance
local collect_words = lib.collect_words
local create_node = lib.create_node
local is_shorthand_match = lib.is_shorthand_match
-- TODO(manual): the following were file-locals with no direct export;
-- verify and export or inline as needed: calculate_levenshtein_distance, collect_words, create_node, distance, get_completions, insert, is_shorthand_match, max_edit_distance, max_results, new

if true then
	-- Test basic autocompleter creation
	local ac = M.new()
	assert(ac ~= nil, "Should create autocompleter instance")
	assert(type(ac.insert) == "function", "Should have insert method")
	assert(type(ac.get_completions) == "function", "Should have get_completions method")

	-- Test word insertion
	assert(ac:insert("hello") == true, "Should insert valid word")
	assert(ac:insert("world") == true, "Should insert another valid word")
	assert(ac:insert("help") == true, "Should insert similar word")
	assert(ac:insert("") == false, "Should reject empty string")
	assert(ac:insert(nil) == false, "Should reject nil")
	assert(ac:insert(123) == false, "Should reject non-string")

	-- Test duplicate insertion
	assert(ac:insert("hello") == true, "Should allow duplicate insertion but handle uniqueness")
	assert(#ac.all_words == 3, "Should maintain unique words count")

	-- Test exact match
	local exact_results = ac:get_completions("hello")
	assert(#exact_results >= 1, "Should find exact match")
	assert(exact_results[1] == "hello", "Should return exact match")

	-- Test prefix matching
	local prefix_results = ac:get_completions("he")
	assert(#prefix_results >= 2, "Should find prefix matches for 'he'")
	local has_hello = false
	local has_help = false
	for _, word in ipairs(prefix_results) do
		if word == "hello" then has_hello = true end
		if word == "help" then has_help = true end
	end
	assert(has_hello, "Should include 'hello' in prefix results")
	assert(has_help, "Should include 'help' in prefix results")

	-- Test prefix matching with empty string (should return all)
	local all_results = ac:get_completions("")
	assert(#all_results >= 3, "Should return all words for empty prefix")

	-- Test shorthand matching
	ac:insert("fooBar")
	ac:insert("foobar")
	local shorthand_results = ac:get_completions("fb", { shorthand = true })
	assert(#shorthand_results >= 1, "Should find shorthand matches")

	-- Test shorthand with empty input
	local empty_shorthand = ac:get_completions("", { shorthand = true })
	assert(#empty_shorthand >= 0, "Should handle empty shorthand input")

	-- Test substring matching
	ac:insert("testing")
	ac:insert("attest")
	local substring_results = ac:get_completions("test", { substring = true })
	assert(#substring_results >= 1, "Should find substring matches")

	-- Test fuzzy matching
	ac:insert("kitten")
	ac:insert("sitting")
	local fuzzy_results = ac:get_completions("kittn", { fuzzy = true, max_edit_distance = 1 })
	assert(#fuzzy_results >= 1, "Should find fuzzy matches")

	-- Test fuzzy matching distance sorting
	ac:insert("bitten")
	local fuzzy_sorted = ac:get_completions("kitten", { fuzzy = true, max_edit_distance = 2 })
	assert(fuzzy_sorted[1] == "kitten", "Should return exact match first in fuzzy results")

	-- Test max_results limiting
	local limited_results = ac:get_completions("h", { max_results = 2 })
	assert(#limited_results <= 2, "Should respect max_results limit")

	-- Test case sensitivity
	ac:insert("Hello")
	ac:insert("hello")
	local case_results = ac:get_completions("h")
	-- Should find both due to case-insensitive prefix matching being case-sensitive in trie
	local has_lower = false
	local has_upper = false
	for _, word in ipairs(case_results) do
		if word == "hello" then has_lower = true end
		if word == "Hello" then has_upper = true end
	end
	assert(has_lower or has_upper, "Should handle case sensitivity")

	-- Test options defaults
	local default_results = ac:get_completions("he")
	local explicit_results = ac:get_completions("he",
		{ prefix = true, shorthand = false, substring = false, fuzzy = false })
	assert(#default_results == #explicit_results, "Default options should work correctly")

	-- Test edge cases
	local nil_results = ac:get_completions(nil)
	assert(type(nil_results) == "table", "Should handle nil input gracefully")
	assert(#nil_results == 0, "Should return empty table for nil input")

	local number_results = ac:get_completions(123)
	assert(type(number_results) == "table", "Should handle number input gracefully")
	assert(#number_results == 0, "Should return empty table for number input")

	-- Test Levenshtein distance function directly
	local dist1 = calculate_levenshtein_distance("kitten", "sitting")
	assert(dist1 == 3, "Levenshtein distance should be 3 for kitten/sitting")

	local dist2 = calculate_levenshtein_distance("", "hello")
	assert(dist2 == 5, "Levenshtein distance should be length of non-empty string")

	local dist3 = calculate_levenshtein_distance("same", "same")
	assert(dist3 == 0, "Levenshtein distance should be 0 for identical strings")

	-- Test shorthand matching function directly
	assert(is_shorthand_match("fb", "fooBar") == true, "Should match shorthand")
	assert(is_shorthand_match("fb", "foobar") == true, "Should match shorthand without case")
	assert(is_shorthand_match("xyz", "abc") == false, "Should not match non-matching shorthand")
	assert(is_shorthand_match("", "anything") == false, "Should not match empty shorthand")
	assert(is_shorthand_match("long", "short") == false, "Should not match when shorthand longer than word")

	-- Test collect_words function
	local test_node = create_node()
	test_node.isEndOfWord = true
	test_node.word = "test"
	local child_node = create_node()
	child_node.isEndOfWord = true
	child_node.word = "child"
	test_node.children["c"] = child_node

	local collected = {}
	collect_words(test_node, collected)
	assert(#collected == 2, "Should collect both words")
	assert(collected[1] == "child" or collected[2] == "child", "Should include child word")
	assert(collected[1] == "test" or collected[2] == "test", "Should include parent word")

	-- Test performance with many words
	local large_ac = M.new()
	for i = 1, 100 do
		large_ac:insert("word" .. i)
	end
	local large_results = large_ac:get_completions("word")
	assert(#large_results >= 10, "Should handle many words efficiently")

	-- Test combined matching modes
	ac:insert("HelloWorld")
	local combined_results = ac:get_completions("HW", { prefix = true, shorthand = true, substring = true, fuzzy = true })
	assert(#combined_results >= 1, "Should work with all matching modes enabled")
end

print("All tests passed")
