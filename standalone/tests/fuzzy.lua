-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for fuzzy.lua.
-- Run from this directory:
--   lua fuzzy.lua
--   luajit fuzzy.lua

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
local lib = require "fuzzy"
-- Bridging: file-locals used by tests mapped to module exports.
local fuzzy = lib
local string_find = string.find
-- TODO(manual): the following were file-locals with no direct export;
-- verify and export or inline as needed: acronym_match, best, best_match_and_highlight, case_sensitive, close, damerau_levenshtein, fuzzy_score, initials, item, jaro_winkler, key, levenshtein, limit, matches, multi_token_score, open, positions, results, score, smart_case_sensitive, split_tokens, suggest, typo_tolerant_score

if true then
	-- Test split_tokens
	local tokens = fuzzy.split_tokens("hello world test")
	assert(#tokens == 3, "split_tokens should return 3 tokens")
	assert(tokens[1] == "hello" and tokens[2] == "world" and tokens[3] == "test", "split_tokens should split correctly")

	-- Test smart_case_sensitive
	assert(fuzzy.smart_case_sensitive("hello") == false, "lowercase query should not be case-sensitive")
	assert(fuzzy.smart_case_sensitive("Hello") == true, "uppercase query should be case-sensitive")
	assert(fuzzy.smart_case_sensitive("hEllo") == true, "mixed case query should be case-sensitive")

	-- Test levenshtein distance
	assert(fuzzy.levenshtein("kitten", "sitting") == 3, "Levenshtein distance should be 3")
	assert(fuzzy.levenshtein("", "") == 0, "Empty strings should have distance 0")
	assert(fuzzy.levenshtein("a", "a") == 0, "Identical strings should have distance 0")
	assert(fuzzy.levenshtein("a", "b") == 1, "Different single chars should have distance 1")

	-- Test damerau_levenshtein distance
	assert(fuzzy.damerau_levenshtein("ca", "abc") == 2, "Damerau-Levenshtein should handle transpositions")
	assert(fuzzy.damerau_levenshtein("teh", "the") == 1, "Damerau-Levenshtein should handle adjacent transposition")

	-- Test jaro_winkler similarity
	local jw_sim = fuzzy.jaro_winkler("dixon", "dicksonx")
	assert(jw_sim > 0.7 and jw_sim < 0.9, "Jaro-Winkler similarity should be around 0.8")
	assert(fuzzy.jaro_winkler("same", "same") == 1.0, "Identical strings should have Jaro-Winkler similarity of 1.0")

	-- Test fuzzy_score
	local score_result = fuzzy.fuzzy_score("fw", "fuzzywuzzy")
	assert(score_result ~= nil, "fuzzy_score should return result")
	assert(score_result.score > 0, "fuzzy_score should have positive score")
	assert(type(score_result.positions) == "table", "fuzzy_score should return positions table")
	assert(#score_result.positions > 0, "fuzzy_score should return positions")

	-- Test fuzzy_score with case sensitivity
	local cs_result = fuzzy.fuzzy_score("FW", "FuzzyWuzzy", { case_sensitive = true })
	assert(cs_result ~= nil, "fuzzy_score should work with case-sensitive option")

	-- Test acronym_match
	local acro_result = fuzzy.acronym_match("FW", "FuzzyWuzzy")
	assert(acro_result ~= nil, "acronym_match should return result")
	if acro_result then
		assert(acro_result.score > 0, "acronym_match should have positive score")
	end

	-- Test acronym_match with separators
	local acro_result2 = fuzzy.acronym_match("ht", "hello_world_test")
	assert(acro_result2 ~= nil, "acronym_match should work with separators")
	if acro_result2 then
		assert(acro_result2.score > 0, "acronym_match should find initials with separators")
	end

	-- Test multi_token_score
	local multi_result = fuzzy.multi_token_score("fz wz", "fuzzy wuzzy")
	assert(multi_result ~= nil, "multi_token_score should return result")
	assert(multi_result.score > 0, "multi_token_score should have positive score")

	-- Test typo_tolerant_score
	local typo_result = fuzzy.typo_tolerant_score("fuzzy", "fuzy")
	assert(typo_result ~= nil, "typo_tolerant_score should return result")
	assert(typo_result.score > 0, "typo_tolerant_score should handle typos")

	-- Test highlight_positions
	local highlighted = fuzzy.highlight_positions("fuzzywuzzy", { 1, 2, 3, 4, 5 })
	assert(highlighted ~= nil, "highlight_positions should return result")
	assert(string_find(highlighted, "*", 1, true), "highlight_positions should include default markers")

	-- Test highlight_positions with custom markers
	local custom_highlighted = fuzzy.highlight_positions("fuzzywuzzy", { 1, 2, 3, 4, 5 }, { open = "[", close = "]" })
	assert(string_find(custom_highlighted, "[", 1, true), "highlight_positions should use custom open marker")
	assert(string_find(custom_highlighted, "]", 1, true), "highlight_positions should use custom close marker")

	-- Test suggest function
	local items = {
		{ key = "fuzzywuzzy",  meta = "test1" },
		{ key = "fuzzymatch",  meta = "test2" },
		{ key = "hello world", meta = "test3" }
	}
	local suggestions = fuzzy.suggest(items, "fz")
	assert(#suggestions > 0, "suggest should return suggestions")
	assert(suggestions[1].item ~= nil, "suggestions should have item")
	assert(suggestions[1].score > 0, "suggestions should have score")
	assert(suggestions[1].raw > 0, "suggestions should have raw score")

	-- Test suggest with limit
	local limited_suggestions = fuzzy.suggest(items, "fz", { limit = 2 })
	assert(#limited_suggestions <= 2, "suggest should respect limit option")

	-- Test best_match_and_highlight
	local best_result = fuzzy.best_match_and_highlight("fw", "fuzzywuzzy")
	assert(best_result ~= nil, "best_match_and_highlight should return result")
	assert(best_result.score > 0, "best_match_and_highlight should have positive score")
	assert(best_result.highlighted ~= nil, "best_match_and_highlight should return highlighted text")
	assert(type(best_result.positions) == "table", "best_match_and_highlight should return positions")

	-- Test best_match_and_highlight with custom highlight
	local custom_best = fuzzy.best_match_and_highlight("fw", "fuzzywuzzy", { highlight = { open = "<", close = ">" } })
	assert(string_find(custom_best.highlighted, "<", 1, true),
		"best_match_and_highlight should use custom highlight markers")

	-- Test edge cases
	local empty_query_result = fuzzy.fuzzy_score("", "anything")
	assert(empty_query_result ~= nil, "Empty query should return result")
	assert(empty_query_result.score == 0.0, "Empty query should have score 0.0")
	assert(#empty_query_result.positions == 0, "Empty query should have no positions")

	local empty_target_result = fuzzy.fuzzy_score("query", "")
	assert(empty_target_result ~= nil, "Empty target should return result")
	assert(empty_target_result.score == 0.0, "Empty target should have score 0.0")
	assert(#empty_target_result.positions == 0, "Empty target should have no positions")

	-- Test scoring ranges
	local perfect_match = fuzzy.fuzzy_score("fuzzy", "fuzzy")
	assert(perfect_match.score > 0.9, "Perfect match should have high score")

	local poor_match = fuzzy.fuzzy_score("xyz", "abcdef")
	if poor_match then
		assert(poor_match.score < 0.5, "Poor match should have low score")
	end

	-- Test positions are valid
	local pos_result = fuzzy.fuzzy_score("fw", "fuzzywuzzy")
	if pos_result then
		for _, pos in ipairs(pos_result.positions) do
			assert(pos >= 1 and pos <= #("fuzzywuzzy"), "Positions should be within string bounds")
		end
	end

	-- Test comprehensive edge cases
	-- Empty strings
	local empty_query = fuzzy.fuzzy_score("", "anything")
	assert(empty_query.score == 0.0, "Empty query should return score 0.0")
	assert(#empty_query.positions == 0, "Empty query should return no positions")

	local empty_target = fuzzy.fuzzy_score("query", "")
	if empty_target then
		assert(empty_target.score == 0.0, "Empty target should return score 0.0")
		assert(#empty_target.positions == 0, "Empty target should return no positions")
	else
		assert(empty_target == nil, "Empty target should return nil")
	end

	-- Single character matches
	local single_char = fuzzy.fuzzy_score("a", "a")
	assert(single_char.score > 0.8, "Single character match should be high")

	-- Case sensitivity variations
	local cs_match = fuzzy.fuzzy_score("A", "a", { case_sensitive = true })
	assert(cs_match == nil, "Case-sensitive mismatch should return nil")

	local ci_match = fuzzy.fuzzy_score("A", "a", { case_sensitive = false })
	assert(ci_match ~= nil, "Case-insensitive match should work")

	-- Unicode and special characters
	local unicode_test = fuzzy.fuzzy_score("café", "cafe")
	assert(unicode_test ~= nil, "Unicode characters should be handled")

	-- Long strings stress test
	local long_query = "a"
	local long_target = string.rep("b", 1000)
	local long_result = fuzzy.fuzzy_score(long_query, long_target)
	assert(long_result ~= nil, "Long strings should not crash")
	assert(long_result.score >= 0, "Long strings should return valid score")

	-- Test boundary conditions and special cases
	-- Token boundary detection
	local boundary_test = fuzzy.fuzzy_score("hello", "hello_world")
	assert(boundary_test ~= nil, "Should match across token boundary")

	-- CamelCase detection
	local camel_test = fuzzy.fuzzy_score("HW", "HelloWorld")
	assert(camel_test ~= nil, "Should match CamelCase boundaries")

	-- Multiple occurrences
	local multi_test = fuzzy.fuzzy_score("aa", "baaab")
	assert(multi_test ~= nil, "Should handle multiple character occurrences")

	-- Non-ASCII characters
	local ascii_test = fuzzy.fuzzy_score("café", "cafe")
	assert(ascii_test ~= nil, "Should handle Unicode characters")

	-- Integration tests between functions
	-- Test acronym_match with fuzzy_score
	local acro_query = "FW"
	local acro_target = "FuzzyWuzzy"
	local acro_fuzzy = fuzzy.fuzzy_score(acro_query, acro_target)
	local acro_acro = fuzzy.acronym_match(acro_query, acro_target)
	assert(acro_fuzzy.score > 0, "Acronym match should work")
	assert(acro_acro.score > 0, "Acronym function should work")

	-- Test highlight_positions integration
	local highlight_positions = { 2, 4, 6 }
	local highlighted = fuzzy.highlight_positions("fuzzywuzzy", highlight_positions)
	assert(string.find(highlighted, "*", 1, true), "Highlight should use default markers")

	-- Test suggest integration
	local items = {
		{ key = "fuzzywuzzy", meta = "test1" },
		{ key = "fuzzymatch", meta = "test2" },
		{ key = "hello",      meta = "test3" }
	}
	local suggestions = fuzzy.suggest(items, "fz")
	assert(#suggestions > 0, "Suggest should return results")
	assert(suggestions[1].item.key == "fuzzywuzzy", "Suggest should return best match first")
end

print("All tests passed")
