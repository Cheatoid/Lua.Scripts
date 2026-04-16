-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Localized global functions for better performance
local next = next
local setmetatable = setmetatable
local type = type
local math_min = math.min
local string_lower = string.lower
local string_sub = string.sub
local string_find = string.find
local table_insert = table.insert
local table_sort = table.sort

---@class autocompleter.TrieNode
---@field children table<string, autocompleter.TrieNode> Character to child node mapping
---@field isEndOfWord boolean True if this node marks the end of a word
---@field word string|nil The full word stored at this node (if isEndOfWord)

---@class autocompleter.Options
---@field prefix boolean|nil Enable prefix matching (default: true)
---@field shorthand boolean|nil Enable shorthand/acronym matching (default: false)
---@field substring boolean|nil Enable substring matching (default: false)
---@field fuzzy boolean|nil Enable fuzzy/edit-distance matching (default: false)
---@field max_edit_distance number|nil Max Levenshtein distance for fuzzy matches (default: 2)
---@field max_results number|nil Maximum number of results to return (default: 10)

---@class autocompleter.Instance
---@field root autocompleter.TrieNode Root node of the Trie
---@field all_words string[] Array of all inserted words
---@field word_set table<string, boolean> Set for O(1) word existence checks
---@field insert fun(autocompleter.Instance, word: string): boolean Insert a word into the autocompleter
---@field get_completions fun(autocompleter.Instance, input_str: string, options: autocompleter.Options?): string[] Get completion suggestions

local M = {}
M.__index = M

--- Create a new Trie node.
---@return autocompleter.TrieNode node
local function create_node()
	return { children = {}, isEndOfWord = false, word = nil }
end

--- Create a new autocompleter instance.
---@return autocompleter.Instance instance
local function new()
	return setmetatable({
		root = create_node(),
		all_words = {}, -- to store all unique words for non-prefix searches
		word_set = {}, -- to quickly check for uniqueness before adding to all_words
	}, M)
end

M.new = new

--- Insert a word into the autocompleter.<br>
--- Words are stored in a Trie for efficient prefix matching,
--- and also tracked in all_words for other match types.
---@param self autocompleter.Instance
---@param word string The word to insert
---@return boolean success True if insertion succeeded
local function insert(self, word)
	if type(word) ~= "string" or word == "" then
		return false -- handle non-string or empty input
	end

	-- Trie insertion (case-sensitive for prefix matching)
	---@type autocompleter.TrieNode
	local node = self.root
	for i = 1, #word do
		local char = string_sub(word, i, i)
		if not node.children[char] then
			node.children[char] = create_node()
		end
		node = node.children[char]
	end
	node.isEndOfWord = true
	node.word = word -- store the original cased word

	-- Add to all_words list if it's a new word (maintains original casing)
	if not self.word_set[word] then
		table_insert(self.all_words, word)
		self.word_set[word] = true
	end
	return true
end

M.insert = insert

--- Recursively collect all words from a given node downwards.<br>
--- Used for prefix matching in the Trie.
---@param node autocompleter.TrieNode Current node to collect from
---@param completions_table string[] Table to append found words to
local function collect_words(node, completions_table)
	if node.isEndOfWord and node.word then
		completions_table[#completions_table + 1] = node.word
	end

	local sorted_child_chars = {}
	for char_key, _ in next, node.children do
		sorted_child_chars[#sorted_child_chars + 1] = char_key
	end
	table_sort(sorted_child_chars)

	for i = 1, #sorted_child_chars do
		collect_words(node.children[sorted_child_chars[i]], completions_table)
	end
end

--- Check if shorthand matches a word (case-insensitive acronym matching).<br>
--- For example, "fb" matches "fooBar" because f matches first f, b matches B.
---@param shorthand string The shorthand/acronym pattern to match
---@param word_to_check string The word to check against
---@return boolean matches True if shorthand matches the word
local function is_shorthand_match(shorthand, word_to_check)
	if shorthand == "" then return true end -- empty shorthand could be seen as matching
	if #shorthand > #word_to_check then return false end

	local s_idx = 1
	local w_idx = 1
	local lower_shorthand = string_lower(shorthand)
	local lower_word = string_lower(word_to_check)

	while s_idx <= #lower_shorthand and w_idx <= #lower_word do
		if string_sub(lower_shorthand, s_idx, s_idx) == string_sub(lower_word, w_idx, w_idx) then
			s_idx = s_idx + 1
		end
		w_idx = w_idx + 1
	end
	return s_idx > #lower_shorthand -- true if all shorthand chars were found
end

--- Calculate Levenshtein edit distance between two strings (case-insensitive).<br>
--- Used for fuzzy matching to find words similar to input.
---@param s1 string First string
---@param s2 string Second string
---@return number distance The edit distance (0 = identical)
local function calculate_levenshtein_distance(s1, s2)
	s1, s2 = string_lower(s1), string_lower(s2) -- make it case-insensitive
	local len1, len2 = #s1, #s2
	if len1 == 0 then return len2 end
	if len2 == 0 then return len1 end

	local matrix = {}
	for i = 0, len1 do
		matrix[i] = {}
		matrix[i][0] = i
	end
	for j = 0, len2 do matrix[0][j] = j end

	for i = 1, len1 do
		for j = 1, len2 do
			local cost = (string_sub(s1, i, i) == string_sub(s2, j, j)) and 0 or 1
			matrix[i][j] = math_min(
				matrix[i - 1][j] + 1, -- deletion
				matrix[i][j - 1] + 1, -- insertion
				matrix[i - 1][j - 1] + cost -- substitution
			)
		end
	end
	return matrix[len1][len2]
end

--- Get completion suggestions for an input string.<br>
--- Matching priority (highest to lowest):
--- 1. Exact match (case-sensitive)
--- 2. Prefix match (Trie-based, case-sensitive)
--- 3. Shorthand/acronym match (case-insensitive, if enabled)
--- 4. Substring match (case-insensitive, if enabled)
--- 5. Fuzzy match (edit distance, if enabled)
---@param self autocompleter.Instance
---@param input_str string The input string to get completions for
---@param options autocompleter.Options|nil Matching options
---@return string[] completions Array of matching words (up to max_results)
local function get_completions(self, input_str, options)
	if type(input_str) ~= "string" then
		return {} -- handle non-string input
	end

	options = options or {}
	local do_prefix = options.prefix ~= false -- default true
	local do_shorthand = options.shorthand == true
	local do_substring = options.substring == true
	local do_fuzzy = options.fuzzy == true
	local max_edit_distance = options.max_edit_distance or 2 -- default for fuzzy
	local max_results = options.max_results or 10         -- default max results

	local results_set = {}                                -- use a set to store unique results (original casing)
	local final_completions = {}

	local function add_completion(comp)
		if not results_set[comp] then
			results_set[comp] = true
			final_completions[#final_completions + 1] = comp
			return true -- added
		end
		return false -- already exists
	end

	-- 0. Exact match (highest priority)
	-- Check if the input_str itself is a word in the dictionary (case-sensitive)
	if input_str ~= "" and self.word_set[input_str] then
		add_completion(input_str)
	end

	-- 1. Prefix matching (using Trie, case-sensitive)
	if do_prefix and #final_completions < max_results then
		local current_node = self.root
		local prefix_path_exists = true
		if input_str ~= "" then -- only traverse if input_str is not empty
			for i = 1, #input_str do
				local char = string_sub(input_str, i, i)
				if not current_node.children[char] then
					prefix_path_exists = false
					break
				end
				current_node = current_node.children[char]
			end
		end
		-- If input_str is empty, current_node remains self.root
		if prefix_path_exists then
			local prefix_completions_temp = {}
			collect_words(current_node, prefix_completions_temp)
			for i = 1, #prefix_completions_temp do
				if #final_completions < max_results then
					add_completion(prefix_completions_temp[i])
				else
					break
				end
			end
		end
	end

	-- 2. Shorthand matching (case-insensitive)
	if do_shorthand and input_str ~= "" and #final_completions < max_results then
		for i = 1, #self.all_words do
			if is_shorthand_match(input_str, self.all_words[i]) then
				if #final_completions < max_results then
					add_completion(self.all_words[i])
				else
					break
				end
			end
		end
	end

	-- 3. Substring matching (case-insensitive)
	if do_substring and input_str ~= "" and #final_completions < max_results then
		local lower_input = string_lower(input_str)
		for i = 1, #self.all_words do
			if string_find(string_lower(self.all_words[i]), lower_input, nil, true) then -- 'true' for plain find
				if #final_completions < max_results then
					add_completion(self.all_words[i])
				else
					break
				end
			end
		end
	end

	-- 4. Fuzzy matching
	if do_fuzzy and input_str ~= "" and #final_completions < max_results then
		for i = 1, #self.all_words do
			local distance = calculate_levenshtein_distance(input_str, self.all_words[i])
			if distance <= max_edit_distance then
				if #final_completions < max_results then
					-- Could add sorting by distance here if multiple fuzzy matches are found
					add_completion(self.all_words[i])
				else
					break
				end
			end
		end
		-- NOTE: Fuzzy matches are added last. If specific ordering for fuzzy matches (e.g., by distance)
		-- is needed and they might displace other match types, a more complex scoring/sorting
		-- system across all match types would be required. For now, they are added if space allows.
	end

	return final_completions
end

M.get_completions = get_completions

-- Export
return M
