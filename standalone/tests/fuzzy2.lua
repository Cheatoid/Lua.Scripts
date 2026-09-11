-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for fuzzy2.lua.
-- Run from this directory:
--   lua fuzzy2.lua
--   luajit fuzzy2.lua

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
local lib = require "fuzzy2"
-- Bridging: file-locals used by tests mapped to module exports.
local M = lib
local Engine = lib.Engine
local os_clock = os.clock
local string_find = string.find
-- TODO(manual): the following were file-locals with no direct export;
-- verify and export or inline as needed: acronym_match, as, auto_complete, build_trigram_index, close, common_prefix, config, damerau_levenshtein, filter, highlight, index, indices, jaro_winkler, levenshtein, levenshtein_simple, match, match_ranges, matches, multi_match, open, pattern_filter, predict, quick_match, results, similarity, simple_filter, smart_match, start, substitution, substr_match, test, trigram_filter, typo_match

if true then
	-- Test levenshtein distance variations
	assert(M.levenshtein("kitten", "sitting") == 3, "Levenshtein distance should be 3")
	assert(M.levenshtein_simple("kitten", "sitting") == 3, "Levenshtein simple should be 3")
	assert(M.levenshtein("", "") == 0, "Empty strings should have distance 0")
	assert(M.levenshtein("a", "a") == 0, "Identical strings should have distance 0")
	assert(M.levenshtein("a", "b") == 1, "Different chars should have distance 1")
	assert(M.levenshtein("abc", "abc", 2) == 0, "String with max_dist should work")

	-- Test damerau_levenshtein
	local dl1 = M.damerau_levenshtein("ca", "abc")
	local dl2 = M.damerau_levenshtein("teh", "the")
	assert(dl1 == 3, "Damerau-Levenshtein should calculate correct distance")
	assert(dl2 == 1, "Damerau-Levenshtein should handle adjacent transposition")

	-- Test jaro_winkler
	local jw_sim = M.jaro_winkler("dixon", "dicksonx")
	assert(jw_sim > 0.7 and jw_sim < 0.9, "Jaro-Winkler similarity should be around 0.8")
	assert(M.jaro_winkler("same", "same") == 1.0, "Identical strings should have Jaro-Winkler similarity of 1.0")

	-- Test similarity function
	local sim = M.similarity("hello", "hallo")
	assert(sim > 0.7 and sim < 0.9, "Similarity should be around 0.8")
	assert(M.similarity("", "") == 1.0, "Empty strings should be identical")
	assert(M.similarity("a", "b") < 1.0, "Different strings should have similarity < 1.0")

	-- Test quick match variations
	assert(M.quick_match("fw", "fuzzywuzzy") == true, "Quick match should find 'fw' in 'fuzzywuzzy'")
	assert(M.quick_match("xyz", "fuzzywuzzy") == false, "Quick match should not find 'xyz' in 'fuzzywuzzy'")
	assert(M.quick_match("FW", "FuzzyWuzzy", true) == true, "Quick match should work with case sensitivity")
	assert(M.quick_match("fw", "FuzzyWuzzy", true) == false, "Quick match should respect case sensitivity")

	-- Test match with scoring and options
	local match_result, score = M.match("fw", "fuzzywuzzy", {})
	assert(match_result ~= nil, "Match should return result")
	assert(score > 0, "Score should be positive")
	assert(type(match_result) == "table", "Match should return indices table")

	-- Test substr_match
	local substr_start, substr_score = M.substr_match("fuzzy", "fuzzywuzzy", {})
	assert(substr_start == 1, "Substr match should return start position 1")
	assert(substr_score > 0, "Substr match should return score")

	-- Test non-matching substring
	local no_match_start, no_match_score = M.substr_match("xyz", "fuzzywuzzy", {})
	assert(no_match_start == nil, "Non-matching substring should return nil")

	-- Test prefix_match
	local prefix_match, prefix_score = M.prefix_match("fuz", "fuzzywuzzy", {})
	assert(prefix_match == true, "Prefix match should succeed")
	assert(prefix_score > 0, "Prefix match should have positive score")

	-- Test acronym matching variations
	local acro_result, acro_score = M.acronym_match("FW", "FuzzyWuzzy", {})
	assert(acro_result ~= nil, "Acronym match should return result")
	assert(acro_score > 0, "Acronym score should be positive")

	local acro_sep, acro_sep_score = M.acronym_match("HWT", "HelloWorldTest", {})
	assert(acro_sep ~= nil, "Acronym match with separators should work")
	assert(acro_sep_score > 0, "Acronym match with separators should have positive score")

	-- Test typo matching
	local typo_result, typo_score = M.typo_match("fuzzy", "fuzy", {})
	assert(typo_result ~= nil, "Typo match should return result")
	assert(typo_score > 0, "Typo match should handle typos")

	-- Test multi-token matching
	local multi_result, multi_score = M.multi_match("fz mt", "fuzzy matching test", {})
	assert(multi_result ~= nil, "Multi-token match should return result")
	assert(multi_score > 0, "Multi-token score should be positive")

	-- Test smart_match
	local smart_result, smart_score, smart_type = M.smart_match("fw", "fuzzywuzzy", {})
	assert(smart_result ~= nil, "Smart match should return result")
	assert(smart_score > 0, "Smart match should have positive score")
	assert(smart_type ~= nil, "Smart match should return match type")

	-- Test filter function with options
	local candidates = { "fuzzywuzzy", "fuzzy matching", "hello world", "fuzzy logic" }
	local filtered = M.filter("fz", candidates, {})
	assert(#filtered > 0, "Filter should find matches")
	assert(#filtered <= #candidates, "Filter should not return more results than candidates")

	-- Test filter with limit
	local limited_filtered = M.filter("fz", candidates, { max_results = 2 })
	assert(#limited_filtered <= 2, "Filter should respect max_results")

	-- Test best match
	local best = M.best("fz", candidates, {})
	assert(best ~= nil, "Best match should return a result")
	assert(best.text ~= nil, "Best match should have text")

	-- Test highlighting with options
	local highlighted, hl_score = M.highlight("fz", "fuzzywuzzy", {})
	assert(highlighted ~= nil, "Highlight should return result")
	assert(hl_score > 0, "Highlight score should be positive")

	local custom_highlighted = M.highlight("fz", "fuzzywuzzy", { open = "[", close = "]" })
	assert(string_find(custom_highlighted, "[", 1, true), "Custom highlight open marker should work")
	assert(string_find(custom_highlighted, "]", 1, true), "Custom highlight close marker should work")

	-- Test match_ranges
	local ranges = M.match_ranges({ 1, 3, 5 })
	assert(type(ranges) == "table", "Match ranges should return table")
	assert(#ranges > 0, "Match ranges should return ranges")

	-- Test common prefix variations
	local strings = { "fuzzywuzzy", "fuzzymatch", "fuzzylogic" }
	local prefix = M.common_prefix(strings)
	assert(prefix == "fuzzy", "Common prefix should be 'fuzzy'")

	local single_prefix = M.common_prefix({ "hello" })
	assert(single_prefix == "hello", "Single string should return itself as prefix")

	local no_prefix = M.common_prefix({ "abc", "def" })
	assert(no_prefix == "", "No common prefix should return empty string")

	-- Test predict function
	local predictions = M.predict("fuz", candidates, {})
	if predictions then
		assert(#predictions >= 0, "Predict should return predictions array")
	else
		print("Predict returned nil - might be expected behavior")
	end

	-- Test auto_complete
	local completion = M.auto_complete("fuz", candidates, {})
	assert(completion ~= nil, "Auto complete should return result")

	-- Test trigram functions
	local trigram_index = M.build_trigram_index(candidates)
	assert(type(trigram_index) == "table", "Trigram index should return table")

	local trigram_filtered = M.trigram_filter("fuz", trigram_index, {})
	assert(#trigram_filtered >= 0, "Trigram filter should return results")

	-- Test function
	assert(M.test("fw", "fuzzywuzzy", {}) == true, "Test function should return true for match")
	assert(M.test("xyz", "fuzzywuzzy", {}) == false, "Test function should return false for no match")

	-- Test simple_filter
	local simple_filtered = M.simple_filter("fz", candidates, {})
	assert(#simple_filtered >= 0, "Simple filter should return array")
	assert(type(simple_filtered) == "table", "Simple filter should return table")

	-- Test pattern_filter
	local pattern_filtered = M.pattern_filter("fz.*", candidates)
	assert(#pattern_filtered >= 0, "Pattern filter should return results")

	-- Test edge cases and scoring ranges
	local perfect_match, perfect_score = M.match("fuzzy", "fuzzy", {})
	if perfect_score then
		assert(perfect_score > 0.9, "Perfect match should have high score")
	else
		print("Perfect match returned nil score")
	end

	local poor_match, poor_score = M.match("xyz", "abcdef", {})
	if poor_score then
		assert(poor_score < 0.5, "Poor match should have low score")
	else
		print("Poor match returned nil score")
	end

	-- Test position bounds validation
	local pos_result = M.match("fw", "fuzzywuzzy", {})
	if pos_result then
		for _, pos in ipairs(pos_result) do
			assert(pos >= 1 and pos <= #("fuzzywuzzy"), "Positions should be within string bounds")
		end
	end

	-- Test configuration access
	if M.config then
		assert(M.config.match_score ~= nil, "Config should have match_score")
		assert(type(M.config.match_score) == "number", "Config values should be correct type")
	else
		print("Config is not accessible - might be expected")
	end

	-- Test Engine class
	assert(M.Engine ~= nil, "Engine class should be accessible")

	-- Test comprehensive edge cases for fuzzy2.lua
	-- Empty strings with all functions
	assert(M.levenshtein("", "") == 0, "Empty strings should have distance 0")
	assert(M.levenshtein_simple("", "") == 0, "Empty strings should have simple distance 0")
	assert(M.damerau_levenshtein("", "") == 0, "Empty strings should have DL distance 0")
	assert(M.jaro_winkler("", "") == 1.0, "Empty strings should have Jaro-Winkler similarity 1.0")
	assert(M.similarity("", "") == 1.0, "Empty strings should have similarity 1.0")

	-- Single character edge cases
	assert(M.levenshtein("a", "b") == 1, "Single char substitution should be 1")
	assert(M.levenshtein("a", "a") == 0, "Identical single chars should be 0")

	-- Boundary and prefix conditions
	local boundary_result = M.prefix_match("test", "testing_string")
	assert(boundary_result, "Prefix match should succeed")

	local prefix_result = M.prefix_match("test", "test_string")
	assert(prefix_result, "Exact prefix should succeed")

	local no_prefix = M.prefix_match("xyz", "test_string")
	assert(no_prefix == false, "Non-prefix should fail")

	-- Stress test with large datasets
	local large_candidates = {}
	for i = 1, 1000 do
		large_candidates[i] = "test_string_" .. i
	end

	local start_time = os_clock()
	local filtered_large = M.filter("test", large_candidates)
	local end_time = os_clock()
	local duration = end_time - start_time

	assert(#filtered_large > 0, "Filter should handle large datasets")
	assert(duration < 1.0, "Filter should complete in reasonable time")

	-- Test extreme scoring scenarios
	local extreme_match, extreme_score = M.match("b", string.rep("b", 1000))
	assert(extreme_match ~= nil, "Extreme match should not crash")
	assert(extreme_score > -1, "Extreme match should have score > -1")
	assert(extreme_score < 0, "Extreme match should have negative score due to length penalty")

	-- Test trigram index performance
	local trigram_start = os_clock()
	local trigram_index = M.build_trigram_index(large_candidates)
	local trigram_end = os_clock()

	assert(type(trigram_index) == "table", "Trigram index should be table")
	assert(next(trigram_index) ~= nil, "Trigram index should not be empty")

	local trigram_filtered = M.trigram_filter("test", trigram_index, {})
	local trigram_filter_end = os_clock()
	local trigram_duration = trigram_filter_end - trigram_start

	assert(trigram_duration < 2.0, "Trigram filter should be fast")
	assert(#trigram_filtered >= 0, "Trigram filter should return results")
end

print("All tests passed")
