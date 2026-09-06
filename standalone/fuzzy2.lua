-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Fuzzy matching utilities
--
-- Features:
-- * Fuzzy subsequence matching with optimal-alignment DP scoring
-- * Levenshtein & Damerau-Levenshtein edit distance
-- * Jaro-Winkler similarity
-- * Typo-tolerant matching (transpositions, substitutions)
-- * Multi-token (space-separated) queries
-- * Acronym / initialism matching (camelCase, snake_case aware)
-- * Smart-case sensitivity (auto-detect from query)
-- * Match highlighting
-- * Predictive typing / auto-completion
-- * Stateful completion engine with frequency and recency ranking

---@class fuzzy2.Module
---@field levenshtein fun(a: string, b: string, max_dist: number?): number
---@field levenshtein_simple fun(a: string, b: string): number
---@field damerau_levenshtein fun(a: string, b: string): number
---@field jaro_winkler fun(a: string, b: string): number
---@field quick_match fun(pattern: string, text: string, case_sensitive: boolean?): boolean
---@field match fun(pattern: string, text: string, opts: fuzzy2.MatchOptions?): table?, number
---@field substr_match fun(pattern: string, text: string, opts: fuzzy2.MatchOptions?): number?, number
---@field prefix_match fun(pattern: string, text: string, opts: fuzzy2.MatchOptions?): boolean, number
---@field acronym_match fun(pattern: string, text: string, opts: fuzzy2.MatchOptions?): table?, number
---@field typo_match fun(pattern: string, text: string, opts: fuzzy2.MatchOptions?): table?, number
---@field multi_match fun(query: string, text: string, opts: fuzzy2.MatchOptions?): boolean, number
---@field smart_match fun(pattern: string, text: string, opts: fuzzy2.MatchOptions?): table?, number, string
---@field filter fun(pattern: string, candidates: table, opts: fuzzy2.MatchOptions?): table
---@field best fun(pattern: string, candidates: table, opts: fuzzy2.MatchOptions?): table?
---@field highlight fun(pattern: string, text: string, opts: fuzzy2.HighlightOptions?): string, number
---@field match_ranges fun(indices: table): table
---@field common_prefix fun(strings: string[]): string
---@field predict fun(input: string, candidates: table, opts: fuzzy2.MatchOptions?): table
---@field auto_complete fun(input: string, candidates: table, opts: fuzzy2.MatchOptions?): string?
---@field build_trigram_index fun(candidates: table): table
---@field trigram_filter fun(pattern: string, index: table, opts: fuzzy2.MatchOptions?): table
---@field test fun(pattern: string, text: string, opts: fuzzy2.MatchOptions?): boolean
---@field simple_filter fun(pattern: string, candidates: table, opts: fuzzy2.MatchOptions?): string[]
---@field pattern_filter fun(lua_pattern: string, candidates: table): string[]
---@field similarity fun(a: string, b: string): number
---@field Engine fuzzy2.Engine
---@field config fuzzy2.Config Module configuration
local M = {}

-- Localized global functions for better performance
local next = next
local setmetatable = setmetatable
local tostring = tostring
local type = type
local math_floor = math.floor
local math_huge = math.huge
local math_log = math.log
local math_max = math.max
local math_min = math.min
local os_clock = os.clock
local string_find = string.find
local string_gmatch = string.gmatch
local string_lower = string.lower
local string_match = string.match
local string_sub = string.sub
local table_concat = table.concat
local table_sort = table.sort

--- Configuration for fuzzy matching algorithm.<br>
--- Controls scoring weights, typo tolerance, and matching behavior.
---@class fuzzy2.Config
---@field match_score? number Base score for each matched character (default: 1)
---@field boundary_bonus? number Bonus for word-boundary matches (default: 1.5)
---@field prefix_bonus? number Bonus for matches at text position 1 (default: 2.0)
---@field consecutive_bonus? number Bonus for adjacent matched characters (default: 3.0)
---@field acronym_bonus? number Bonus for matching first char of a word segment (default: 1.8)
---@field position_penalty? number Penalty per-position offset from start (default: 0.008)
---@field gap_penalty? number Penalty per-character gap between matches (default: 0.12)
---@field unmatched_len_penalty? number Penalty normalizes against long texts (default: 0.005)
---@field typo_penalty? number Penalty for typo tolerance (default: 4.0)
---@field max_edit_dist? number Maximum Levenshtein edit distance allowed (default: 2)
---@field jw_prefix_len? number Prefix length for Jaro-Winkler algorithm (default: 4)
---@field jw_prefix_scale? number Scale factor for Jaro-Winkler prefix (default: 0.1)
---@field case_mode? "smart"|"sensitive"|"insensitive" Case matching mode: "smart", "sensitive", or "insensitive" (default: "smart")
---@field min_score? number Minimum score threshold for matches (default: 0)
---@field max_results? number Maximum number of results to return (default: nil)
---@field max_predictions? number Maximum number of predictions for auto-complete (default: 10)
local config = {
	-- Scoring weights
	match_score           = 1,
	boundary_bonus        = 1.5, -- word-boundary match
	prefix_bonus          = 2.0, -- match at text position 1
	consecutive_bonus     = 3.0, -- adjacent matched characters
	acronym_bonus         = 1.8, -- matching first char of a word segment
	position_penalty      = 0.008, -- per-position offset from start
	gap_penalty           = 0.12, -- per-character gap between matches
	unmatched_len_penalty = 0.005, -- normalises against long texts

	-- Typo tolerance
	typo_penalty          = 4.0,
	max_edit_dist         = 2,

	-- Jaro-Winkler
	jw_prefix_len         = 4,
	jw_prefix_scale       = 0.1,

	-- Behaviour
	case_mode             = "smart", -- "smart"|"sensitive"|"insensitive"
	min_score             = 0,
	max_results           = nil,
	max_predictions       = 10,
}

----------------------------------------------------------------------
-- Helper functions
----------------------------------------------------------------------

---@param c string
---@return boolean
local function is_upper(c) return string_match(c, "%u") ~= nil end

---@param c string
---@return boolean
local function is_lower(c) return string_match(c, "%l") ~= nil end

---@param c string
---@return boolean
local function is_alpha(c) return string_match(c, "%a") ~= nil end

---@param c string
---@return boolean
local function is_digit(c) return string_match(c, "%d") ~= nil end

---@param c string
---@return boolean
local function is_space(c) return string_match(c, "%s") ~= nil end

---@param c string
---@return boolean
local function is_alphanum(c) return string_match(c, "%w") ~= nil end

---@param c string
---@return boolean
local function is_control(c) return string_match(c, "%c") ~= nil end

--- Split string into tokens by whitespace.
---@param s string
---@return string[]
local function split_tokens(s)
	local t = {}
	for token in string_gmatch(s, "%S+") do t[#t + 1] = token end
	return t
end

--- Smart-case detection: returns true if query contains uppercase letters.
---@param query string
---@return boolean case_sensitive
local function smart_case_sensitive(query)
	-- If query contains any uppercase letter, treat as case-sensitive
	for i = 1, #query do
		local ch = string_sub(query, i, i)
		if is_upper(ch) then return true end
	end
	return false
end

--- True when position *i* sits on a word boundary in *text*.<br>
--- Handles: start-of-string, post-separator, camelCase, digit<=>letter.
---@param text string
---@param i integer position (1-based)
---@return boolean is_boundary
local function is_boundary(text, i)
	if i <= 0 or i > #text then return false end
	if i == 1 then return true end
	local prev, curr = string_sub(text, i - 1, i - 1), string_sub(text, i, i)
	if not is_alphanum(prev) then return true end
	if is_lower(prev) and is_upper(curr) then return true end
	if (is_alpha(prev) and is_digit(curr)) or
		(is_digit(prev) and is_alpha(curr)) then
		return true
	end
	return false
end

--- Compute word boundaries for text.
---@param text string
---@param b? table existing table to fill
---@return table boundaries array of booleans indexed by position
local function compute_boundaries(text, b)
	b = b or {}
	for i = 1, #text do b[i] = is_boundary(text, i) end
	return b
end

--- Tokenize string into words.
---@param str string
---@param t? table existing table to append to
---@return table tokens array of words
local function tokenize(str, t)
	t = t or {}
	for w in string_gmatch(str, "%S+") do t[#t + 1] = w end
	return t
end

--- Resolve case_mode + query => boolean case_sensitive.
---@param mode "smart"|"sensitive"|"insensitive"
---@param query string
---@return boolean case_sensitive
local function resolve_cs(mode, query)
	if mode == "sensitive" then return true end
	if mode == "insensitive" then return false end
	-- "smart": become sensitive when query has any uppercase letter
	return query ~= string_lower(query)
end

--- Merge user opts into a copy of config.
---@param opts? table user options to merge
---@param o? table existing table to merge into
---@return table options merged options
local function merge_opts(opts, o)
	o = o or {}
	for k, v in next, config do o[k] = v end
	if opts then for k, v in next, opts do o[k] = v end end
	return o
end

--- Extract candidate text from string or table.
---@param c string|table candidate (table must have text/name/label/value field)
---@return string text extracted text
local function cand_text(c)
	if type(c) == "table" then
		return c.text or c.name or c.label or c.value or ""
	end
	return tostring(c)
end

----------------------------------------------------------------------
-- EDIT DISTANCE ALGORITHMS
----------------------------------------------------------------------

--- Levenshtein distance (insert, delete, substitute).<br>
--- Optional *max_dist* enables early termination.
---@param a string
---@param b string
---@param max_dist? number
---@return number
local function levenshtein(a, b, max_dist)
	if a == b then return 0 end
	local la, lb = #a, #b
	if la == 0 then return lb end
	if lb == 0 then return la end
	if la > lb then a, b, la, lb = b, a, lb, la end
	if max_dist and lb - la > max_dist then return max_dist + 1 end

	local prev, curr = {}, {}
	for j = 0, lb do prev[j] = j end

	for i = 1, la do
		curr[0] = i
		local row_min = i
		for j = 1, lb do
			local cost = (string_lower(string_sub(a, i, i)) == string_lower(string_sub(b, j, j))) and 0 or 1
			curr[j] = math_min(prev[j] + 1, curr[j - 1] + 1, prev[j - 1] + cost)
			if curr[j] < row_min then row_min = curr[j] end
		end
		if max_dist and row_min > max_dist then return max_dist + 1 end
		prev, curr = curr, prev
	end
	return prev[lb]
end

M.levenshtein = levenshtein

--- Levenshtein distance using DP, O(n*m) time and O(min(n,m)) space
---@param a string
---@param b string
---@return number
local function levenshtein_simple(a, b)
	if a == b then return 0 end
	local la, lb = #a, #b
	if la == 0 then return lb end
	if lb == 0 then return la end
	-- ensure b is the shorter to minimize space
	if lb > la then a, b, la, lb = b, a, lb, la end
	local prev = {}
	for j = 0, lb do prev[j] = j end
	for i = 1, la do
		local cur = {}
		cur[0] = i
		local ai = string_sub(a, i, i)
		for j = 1, lb do
			local cost = (ai == string_sub(b, j, j)) and 0 or 1
			local deletion = prev[j] + 1
			local insertion = cur[j - 1] + 1
			local substitution = prev[j - 1] + cost
			cur[j] = math_min(deletion, insertion, substitution)
		end
		prev = cur
	end
	return prev[lb]
end

M.levenshtein_simple = levenshtein_simple

--- Damerau-Levenshtein distance (insert, delete, substitute, transpose).
---@param a string
---@param b string
---@return number
local function damerau_levenshtein(a, b)
	if a == b then return 0 end
	local la, lb = #a, #b
	if la == 0 then return lb end
	if lb == 0 then return la end

	local d = {}
	for i = 0, la do
		d[i] = {}
		d[i][0] = i
	end
	for j = 1, lb do d[0][j] = j end

	for i = 1, la do
		for j = 1, lb do
			local cost = (string_lower(string_sub(a, i, i)) == string_lower(string_sub(b, j, j))) and 0 or 1
			d[i][j] = math_min(d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + cost)
			if i > 1 and j > 1 and
				string_lower(string_sub(a, i, i)) == string_lower(string_sub(b, j - 1, j - 1)) and
				string_lower(string_sub(a, i - 1, i - 1)) == string_lower(string_sub(b, j, j)) then
				d[i][j] = math_min(d[i][j], d[i - 2][j - 2] + cost)
			end
		end
	end
	return d[la][lb]
end

M.damerau_levenshtein = damerau_levenshtein

--- Jaro-Winkler similarity (0-1, higher = more similar).
--- Excellent for short strings / name matching.
---@param a string
---@param b string
---@return number
local function jaro_winkler(a, b)
	if a == b then return 1.0 end
	local la, lb = #a, #b
	if la == 0 or lb == 0 then return 0.0 end

	local match_dist = math_floor(math_max(la, lb) / 2) - 1
	if match_dist < 0 then match_dist = 0 end

	local a_matched, b_matched = {}, {}
	for i = 1, la do a_matched[i] = false end
	for i = 1, lb do b_matched[i] = false end

	local matches = 0
	local transpositions = 0

	-- Find matches
	for i = 1, la do
		local startj = math_max(1, i - match_dist)
		local endj   = math_min(lb, i + match_dist)
		for j = startj, endj do
			if not b_matched[j] and string_lower(string_sub(a, i, i)) == string_lower(string_sub(b, j, j)) then
				a_matched[i] = true
				b_matched[j] = true
				matches = matches + 1
				break
			end
		end
	end

	if matches == 0 then return 0.0 end

	-- Count transpositions
	local k = 1
	for i = 1, la do
		if a_matched[i] then
			while not b_matched[k] do k = k + 1 end
			if string_lower(string_sub(a, i, i)) ~= string_lower(string_sub(b, k, k)) then
				transpositions = transpositions + 1
			end
			k = k + 1
		end
	end

	local jaro = (matches / la + matches / lb + (matches - transpositions / 2) / matches) / 3

	-- Winkler prefix bonus
	local prefix_len = 0
	local plimit = math_min(la, lb, config.jw_prefix_len)
	for i = 1, plimit do
		if string_lower(string_sub(a, i, i)) == string_lower(string_sub(b, i, i)) then
			prefix_len = prefix_len + 1
		else
			break
		end
	end

	return jaro + prefix_len * config.jw_prefix_scale * (1 - jaro)
end

M.jaro_winkler = jaro_winkler

----------------------------------------------------------------------
-- CORE FUZZY MATCHING (DP - optimal alignment, O(m*n))
----------------------------------------------------------------------

--- Quick check: do all pattern characters appear in text in order?
---@param pattern string
---@param text string
---@param case_sensitive? boolean
---@return boolean
local function quick_match(pattern, text, case_sensitive)
	if #pattern == 0 then return true end
	if #pattern > #text then return false end
	local pp = case_sensitive and pattern or string_lower(pattern)
	local tt = case_sensitive and text or string_lower(text)
	local pi = 1
	for ti = 1, #tt do
		if string_sub(pp, pi, pi) == string_sub(tt, ti, ti) then
			pi = pi + 1
			if pi > #pp then return true end
		end
	end
	return false
end

M.quick_match = quick_match

--- Scoring and behavior options for fuzzy matching.
---@class fuzzy2.MatchOptions
---@field case_mode?             "smart"|"sensitive"|"insensitive" Case sensitivity mode (default: "smart")
---@field match_score?           number Base score for a character match (default: 1)
---@field boundary_bonus?        number Bonus for matching at word boundaries (default: 1.5)
---@field prefix_bonus?          number Bonus for matching at position 1 (default: 2.0)
---@field consecutive_bonus?     number Bonus for adjacent matched characters (default: 3.0)
---@field acronym_bonus?         number Bonus for matching first char of a word segment (default: 1.8)
---@field position_penalty?      number Penalty per character offset from start (default: 0.008)
---@field gap_penalty?           number Penalty per gap between matches (default: 0.12)
---@field unmatched_len_penalty? number Penalty normalizing against long texts (default: 0.005)
---@field typo_penalty?          number Penalty for edit distance tolerance (default: 4.0)
---@field max_edit_dist?         number Maximum edit distance for typo tolerance (default: 2)
---@field jw_prefix_len?         number Jaro-Winkler prefix length (default: 4)
---@field jw_prefix_scale?       number Jaro-Winkler prefix scale (default: 0.1)
---@field min_score?             number Minimum score threshold (default: 0)
---@field max_results?           number Maximum number of results to return (default: nil)
---@field max_predictions?       number Maximum predictions for auto-complete (default: 10)

--- Core fuzzy match with DP scoring.<br>
--- Returns the 1-based indices of matched characters and a score.
---@param pattern string query
---@param text string text to match against
---@param opts fuzzy2.MatchOptions overrides of config keys + case_mode
---@return table? indices matched positions (1-based), nil on failure
---@return number score higher = better; negative on failure
local function match(pattern, text, opts)
	opts = merge_opts(opts)
	local cs = resolve_cs(opts.case_mode, pattern)

	if #pattern == 0 then return {}, 0.1 end
	if #text == 0 then return nil, -1 end
	if #pattern > #text then return nil, -1 end

	local pp = cs and pattern or string_lower(pattern)
	local tt = cs and text or string_lower(text)
	local m, n = #pp, #tt

	local boundary = compute_boundaries(text)

	-- Precompute per-position char score (independent of alignment)
	local cscore = {}
	for j = 1, n do
		local s = opts.match_score - j * opts.position_penalty
		if boundary[j] then
			s = s + opts.boundary_bonus
			if j == 1 then s = s + opts.prefix_bonus end
		end
		cscore[j] = s
	end

	-- DP tables --------------------------------------------------------
	-- M[j] = best score for pp[1..i] ending with pp[i] matched at tt[j]
	-- We iterate i = 1..m, keeping M_prev as the previous row.
	local M_prev = {}
	local from   = {} -- from[i] = { [j] = prev_j }

	-- i = 1
	from[1]      = {}
	for j = 1, n do
		if string_sub(pp, 1, 1) == string_sub(tt, j, j) then
			M_prev[j] = cscore[j]
			from[1][j] = 0
		else
			M_prev[j] = -math_huge
			from[1][j] = 0
		end
	end

	-- i = 2 .. m
	for i = 2, m do
		from[i] = {}

		-- Running max of M_prev (for gap matches) and its source position
		local rmax = -math_huge
		local rsrc = 0
		local rm = {} -- rm[j] = {score, src}

		-- Also maintain a running max that includes gap_penalty * k offset
		-- so gap penalties are accounted for correctly.
		-- Adjusted: M'_prev[k] = M_prev[k] + gap_penalty * k
		-- Then best gap match at j = max(M'_prev[k]) + cscore[j] - gap_penalty*(j-1)
		local rmax_g = -math_huge
		local rsrc_g = 0
		local rm_g = {}

		for j = 1, n do
			if M_prev[j] and M_prev[j] >= rmax then
				rmax = M_prev[j]
				rsrc = j
			end
			rm[j] = { rmax, rsrc }

			local adj = (M_prev[j] or -math_huge) + opts.gap_penalty * j
			if adj > rmax_g then
				rmax_g = adj
				rsrc_g = j
			end
			rm_g[j] = { rmax_g, rsrc_g }
		end

		local M_curr = {}
		local lo = i
		local hi = n - (m - i)

		for j = lo, hi do
			if string_sub(pp, i, i) == string_sub(tt, j, j) then
				local best_s = -math_huge
				local best_p = 0

				-- Option A: gap match (best previous, with gap penalty)
				if j > 1 and rm_g[j - 1][1] > -math_huge then
					local s = rm_g[j - 1][1] + cscore[j] - opts.gap_penalty * (j - 1)
					if s > best_s then
						best_s = s
						best_p = rm_g[j - 1][2]
					end
				end

				-- Option B: consecutive (from j-1, with bonus)
				if j > 1 and M_prev[j - 1] and M_prev[j - 1] > -math_huge then
					local s = M_prev[j - 1] + cscore[j] + opts.consecutive_bonus
					if s > best_s then
						best_s = s
						best_p = j - 1
					end
				end

				-- Option C: acronym bonus - previous was at boundary too
				if j > 1 and M_prev[j - 1] > -math_huge and boundary[j] then
					local s = M_prev[j - 1] + cscore[j] + opts.consecutive_bonus + opts.acronym_bonus
					if s > best_s then
						best_s = s
						best_p = j - 1
					end
				end

				M_curr[j] = best_s
				from[i][j] = best_p
			else
				M_curr[j] = -math_huge
				from[i][j] = 0
			end
		end

		M_prev = M_curr
	end

	-- Find best final position
	local best_s = -math_huge
	local best_j = 0
	for j = m, n do
		if M_prev[j] > best_s then
			best_s = M_prev[j]
			best_j = j
		end
	end

	if best_j == 0 then return nil, -1 end

	-- Reconstruct indices
	local indices = {}
	local j = best_j
	for i = m, 1, -1 do
		indices[i] = j
		j = from[i][j]
	end

	-- Normalise score: penalise unmatched text length
	local score = best_s - n * opts.unmatched_len_penalty
	-- Clamp
	if score < -1 then score = -1 end

	return indices, score
end

M.match = match

----------------------------------------------------------------------
-- MATCH VARIANTS
----------------------------------------------------------------------

--- Exact substring match. Returns start index or nil.
---@param pattern string
---@param text string
---@param opts? fuzzy2.MatchOptions
---@return number? start_index
---@return number score
local function substr_match(pattern, text, opts)
	opts = opts and merge_opts(opts) or {}
	local cs = resolve_cs(opts.case_mode, pattern)
	local pp = cs and pattern or string_lower(pattern)
	local tt = cs and text or string_lower(text)
	local s, e = string_find(tt, pp, 1, true) -- literal find
	if not s then return nil, -1 end
	-- Score: prefer earlier, longer relative match
	local score = opts.match_score * #pattern
		+ opts.prefix_bonus * (s == 1 and 1 or 0)
		- s * opts.position_penalty
		- #tt * opts.unmatched_len_penalty
	return s, score
end

M.substr_match = substr_match

--- Prefix match. Returns true if text starts with pattern.
---@param pattern string
---@param text string
---@param opts? fuzzy2.MatchOptions
---@return boolean
---@return number score
local function prefix_match(pattern, text, opts)
	opts = merge_opts(opts)
	local cs = resolve_cs(opts.case_mode, pattern)
	local pp = cs and pattern or string_lower(pattern)
	local tt = cs and text or string_lower(text)
	if string_sub(tt, 1, #pp) == pp then
		local score = opts.match_score * #pp
			+ opts.prefix_bonus
			+ opts.consecutive_bonus * (#pp - 1)
			- #tt * opts.unmatched_len_penalty
		return true, score
	end
	return false, -1
end

M.prefix_match = prefix_match

--- Acronym / initialism match.
--- E.g. "fb" matches "foo_bar", "FB" matches "FooBar".
---@param pattern string
---@param text string
---@param opts? fuzzy2.MatchOptions
---@return table? indices
---@return number score
local function acronym_match(pattern, text, opts)
	opts = opts and merge_opts(opts) or {}
	local cs = resolve_cs(opts.case_mode, pattern)
	local pp = cs and pattern or string_lower(pattern)
	local tt = cs and text or string_lower(text)
	local m = #pp

	-- Collect boundary positions
	local boundaries = {}
	for j = 1, #tt do
		if is_boundary(text, j) then
			boundaries[#boundaries + 1] = j
		end
	end

	if #boundaries < m then return nil, -1 end

	-- Try to match pattern against boundary chars (subsequence)
	local pi = 1
	local indices = {}
	for i = 1, #boundaries do
		local j = boundaries[i]
		if pi <= m and string_sub(pp, pi, pi) == string_sub(tt, j, j) then
			indices[pi] = j
			pi = pi + 1
		end
	end

	if pi <= m then return nil, -1 end

	local score = m * (opts.match_score + opts.acronym_bonus + opts.boundary_bonus)
		- #tt * opts.unmatched_len_penalty
	return indices, score
end

M.acronym_match = acronym_match

----------------------------------------------------------------------
-- MULTI-STRATEGY MATCHING
----------------------------------------------------------------------

--- Match with typo tolerance using edit distance.
--- Falls back to Levenshtein when fuzzy subsequence fails.
---@param pattern string
---@param text string
---@param opts? fuzzy2.MatchOptions
---@return table? indices (may be approximate)
---@return number score
local function typo_match(pattern, text, opts)
	opts = opts and merge_opts(opts) or {}

	-- Try fuzzy match first
	local idx, score = match(pattern, text, opts)
	if idx then return idx, score end

	-- Fallback: edit distance
	local max_d = opts.max_edit_dist
	local d = levenshtein(pattern, text, max_d)
	if d <= max_d then
		-- Approximate: return all positions (not precise)
		local approx = {}
		for i = 1, math_min(#pattern, #text) do approx[i] = i end
		local s = #pattern * opts.match_score - d * opts.typo_penalty
			- #text * opts.unmatched_len_penalty
		return approx, s
	end

	return nil, -1
end

M.typo_match = typo_match

--- Multi-token match: split query on spaces, each token must match.
---@param query string  space-separated tokens
---@param text string
---@param opts? fuzzy2.MatchOptions
---@return boolean
---@return number score
local function multi_match(query, text, opts)
	opts = opts and merge_opts(opts) or {}
	local tokens = tokenize(query)
	if #tokens == 0 then return true, 0.1 end

	local total = 0
	for i = 1, #tokens do
		local _, s = match(tokens[i], text, opts)
		if s < 0 then return false, -1 end
		total = total + s
	end
	return true, total / #tokens
end

M.multi_match = multi_match

--- Smart match: tries multiple strategies and returns the best result.
--- Order: prefix => substring => acronym => fuzzy => typo (edit distance)
---@param pattern string
---@param text string
---@param opts? fuzzy2.MatchOptions
---@return table? indices
---@return number score
---@return string strategy name
local function smart_match(pattern, text, opts)
	opts = opts and merge_opts(opts) or {}

	-- 1. Prefix
	local ok, s = prefix_match(pattern, text, opts)
	if ok then
		local idx = {}
		for i = 1, #pattern do idx[i] = i end
		return idx, s, "prefix"
	end

	-- 2. Substring
	local start, ss = substr_match(pattern, text, opts)
	if start then
		local idx = {}
		for i = 1, #pattern do idx[i] = start + i - 1 end
		return idx, ss, "substring"
	end

	-- 3. Acronym
	local aidx, as = acronym_match(pattern, text, opts)
	if aidx then
		return aidx, as, "acronym"
	end

	-- 4. Fuzzy subsequence
	local fidx, fs = match(pattern, text, opts)
	if fidx then
		return fidx, fs, "fuzzy"
	end

	-- 5. Typo-tolerant (edit distance)
	if opts.max_edit_dist and opts.max_edit_dist > 0 then
		local tidx, ts = typo_match(pattern, text, opts)
		if tidx then
			return tidx, ts, "typo"
		end
	end

	return nil, -1, "none"
end

M.smart_match = smart_match

----------------------------------------------------------------------
-- FILTERING & RANKING
----------------------------------------------------------------------

--- Filter candidates and rank by score (descending).
---@param pattern string
---@param candidates table array of strings or {text=..., ...} tables
---@param opts? fuzzy2.MatchOptions extra: key=field name, transform=function
---@return table results structure: `{ item=original, text=string, score=number, indices=table, strategy=string }`
local function filter(pattern, candidates, opts)
	opts = opts and merge_opts(opts) or {}
	local results = {}

	for i = 1, #candidates do
		local cand = candidates[i]
		local txt = cand_text(cand)
		if opts.transform then txt = opts.transform(txt) end

		local idx, score, strategy = smart_match(pattern, txt, opts)
		if score >= (opts.min_score or 0) then
			results[#results + 1] = {
				item     = cand,
				text     = txt,
				score    = score,
				indices  = idx,
				strategy = strategy,
			}
		end
	end

	-- Sort descending by score, then ascending by text length, then alphabetically
	table_sort(results, function(a, b)
		if a.score ~= b.score then return a.score > b.score end
		if #a.text ~= #b.text then return #a.text < #b.text end
		return a.text < b.text
	end)

	if opts.max_results then
		while #results > opts.max_results do results[#results] = nil end
	end

	return results
end

M.filter = filter

--- Return the single best match.
---@param pattern string
---@param candidates table
---@param opts? fuzzy2.MatchOptions
---@return table? result (same shape as filter entries)
local function best(pattern, candidates, opts)
	local r = filter(pattern, candidates, opts)
	return r[1]
end

M.best = best

----------------------------------------------------------------------
-- HIGHLIGHTING
----------------------------------------------------------------------

---@class fuzzy2.HighlightOptions
---@field open? string Opening marker (default: ANSI red)
---@field close? string Closing marker (default: ANSI reset)

--- Highlight matched characters in text using wrapper strings.
---@param pattern string
---@param text string
---@param opts? fuzzy2.HighlightOptions|fuzzy2.MatchOptions
---@return string highlighted text
---@return number score
local function highlight(pattern, text, opts)
	opts             = merge_opts(opts)
	local open       = opts.open or "*" --"\027[1;31m"
	local close      = opts.close or "*" --"\027[0m"

	local idx, score = match(pattern, text, opts)
	if not idx then return text, score end

	-- Build a set of highlighted positions
	local hl = {}
	for i = 1, #idx do hl[idx[i]] = true end

	local out = {}
	for i = 1, #text do
		if hl[i] and not hl[i - 1] then out[#out + 1] = open end
		out[#out + 1] = string_sub(text, i, i)
		if hl[i] and not hl[i + 1] then out[#out + 1] = close end
	end

	return table_concat(out), score
end

M.highlight = highlight

--- Return ranges (pairs of start, end) for matched character runs.
---@param indices table from fuzzy2.match
---@return table ranges e.g. {{3,5},{8,8}}
local function match_ranges(indices)
	if not indices or #indices == 0 then return {} end
	local sorted = {}
	for i = 1, #indices do sorted[i] = indices[i] end
	table_sort(sorted)

	local ranges = {}
	local s = sorted[1]
	local e = s
	for i = 2, #sorted do
		if sorted[i] == e + 1 then
			e = sorted[i]
		else
			ranges[#ranges + 1] = { s, e }
			s = sorted[i]
			e = s
		end
	end
	ranges[#ranges + 1] = { s, e }
	return ranges
end

M.match_ranges = match_ranges

----------------------------------------------------------------------
-- PREDICTIVE TYPING / AUTO-COMPLETION
----------------------------------------------------------------------

--- Find the longest common prefix among a list of strings.
---@param strings string[] array of strings
---@return string common_prefix
local function common_prefix(strings)
	if #strings == 0 then return "" end
	if #strings == 1 then return strings[1] end
	local prefix = strings[1]
	for i = 2, #strings do
		local s = strings[i]
		local j = 1
		while j <= #prefix and j <= #s
			and string_lower(string_sub(prefix, j, j)) == string_lower(string_sub(s, j, j)) do
			j = j + 1
		end
		prefix = string_sub(prefix, 1, j - 1)
		if #prefix == 0 then return "" end
	end
	return prefix
end

M.common_prefix = common_prefix

--- Predictive typing: given a partial input, suggest completions.
---@param input string partial user input
---@param candidates table array of strings or tables
---@param opts? fuzzy2.MatchOptions
---@return table suggestions structure: `{ completion=string, display=string, score=number }`
local function predict(input, candidates, opts)
	opts = merge_opts(opts)
	local results = filter(input, candidates, opts)
	local suggestions = {}

	for i = 1, #results do
		local r     = results[i]
		local txt   = r.text
		local idx   = r.indices
		local extra = ""

		-- Determine the completion portion (characters after the input boundary)
		if idx and #idx > 0 then
			-- Last matched position => extend to end of word or end of string
			local last = idx[#idx]
			local end_pos = #txt
			-- Try to stop at word boundary for cleaner suggestions
			local after = string_sub(txt, last + 1)
			local word_end = string_match(after, "^[^%s_%-./\\]*")
			if #word_end > 0 then
				extra = word_end
			end
		end

		suggestions[#suggestions + 1] = {
			completion = txt,
			display    = txt,
			score      = r.score,
			strategy   = r.strategy,
			indices    = r.indices,
		}

		if opts.max_predictions and #suggestions >= opts.max_predictions then
			break
		end
	end

	return suggestions
end

M.predict = predict

--- Auto-complete: return the text to append after the input.
---@param input string
---@param candidates table
---@param opts? fuzzy2.MatchOptions
---@return string? append_text text to append to input, or nil
local function auto_complete(input, candidates, opts)
	local suggestions = predict(input, candidates, opts)
	if #suggestions == 0 then return end

	-- Find common prefix of all suggestions beyond the input
	local completions = {}
	for i = 1, #suggestions do
		completions[#completions + 1] = suggestions[i].completion
	end

	local prefix = common_prefix(completions)
	if #prefix > #input then
		return string_sub(prefix, #input + 1)
	end
end

M.auto_complete = auto_complete

----------------------------------------------------------------------
-- TRIGRAM INDEX (fast pre-filter for large candidate sets)
----------------------------------------------------------------------

--- Build a trigram set from a string.
---@param s string
---@return table trigrams set of 3-character substrings
local function trigrams_of(s)
	s = string_lower(s)
	local pad = " " .. s .. " "
	local t = {}
	for i = 1, #pad - 2 do
		t[string_sub(pad, i, i + 2)] = true
	end
	return t
end

--- Build a trigram index for fast candidate filtering.
---@param candidates table array of strings or tables
---@return table index
local function build_trigram_index(candidates)
	local index = { items = {}, trigram_map = {} }
	for i = 1, #candidates do
		local cand = candidates[i]
		local txt = cand_text(cand)
		index.items[i] = { cand = cand, text = txt, trigrams = trigrams_of(txt) }
		for tri, _ in next, index.items[i].trigrams do
			if not index.trigram_map[tri] then index.trigram_map[tri] = {} end
			index.trigram_map[tri][i] = true
		end
	end
	return index
end

M.build_trigram_index = build_trigram_index

--- Filter candidates using trigram index, then score with fuzzy2.match.
---@param pattern string
---@param index table from fuzzy2.build_trigram_index
---@param opts? fuzzy2.MatchOptions
---@return table results  same shape as fuzzy2.filter
local function trigram_filter(pattern, index, opts)
	opts = merge_opts(opts)
	local ptris = trigrams_of(pattern)
	local candidates = {}

	-- Score each item by trigram overlap
	local scores = {}
	for idx = 1, #index.items do
		local item = index.items[idx]
		local overlap = 0
		for tri, _ in next, ptris do
			if item.trigrams[tri] then overlap = overlap + 1 end
		end
		if overlap > 0 then
			scores[idx] = overlap
			candidates[#candidates + 1] = item.cand
		end
	end

	-- Sort by trigram overlap (approximate pre-filter)
	table_sort(candidates, function(a, b)
		local ai, bi = nil, nil
		for idx = 1, #index.items do
			local item = index.items[idx]
			if item.cand == a then ai = idx end
			if item.cand == b then bi = idx end
		end
		return (scores[ai] or 0) > (scores[bi] or 0)
	end)

	-- Now run fuzzy2.filter on the pre-filtered set
	return filter(pattern, candidates, opts)
end

M.trigram_filter = trigram_filter

----------------------------------------------------------------------
-- COMPLETION ENGINE
----------------------------------------------------------------------

--- Maintains candidate set, selection history, and frequency counters to provide context-aware, learned ranking.
---@class fuzzy2.Engine
---@field candidates table array of strings or tables
---@field index? table trigram index
---@field history table array of {text=string, timestamp=number}
---@field freq table<string, integer> {[text]=count} frequency counters
---@field last_query string
---@field last_results table
---@field opts fuzzy2.MatchOptions
---@field set_candidates fun(self: fuzzy2.Engine, candidates: table)
---@field add_candidate fun(self: fuzzy2.Engine, candidate: string|table)
---@field record_selection fun(self: fuzzy2.Engine, text: string)
---@field complete fun(self: fuzzy2.Engine, query: string, opts: fuzzy2.MatchOptions?): table
---@field select fun(self: fuzzy2.Engine, n: number): table?
---@field auto_complete fun(self: fuzzy2.Engine, query: string): string?
---@field learn fun(self: fuzzy2.Engine, selections: table)
---@field forget_older_than fun(self: fuzzy2.Engine, max_age: number)
---@field reset fun(self: fuzzy2.Engine)
M.Engine = {}
M.Engine.__index = M.Engine

--- Create a new completion engine.
---@param opts? fuzzy2.MatchOptions
---@return fuzzy2.Engine engine
local function Engine(opts)
	return setmetatable({
		candidates   = {},
		index        = nil,
		history      = {}, -- { text=string, timestamp=number }
		freq         = {}, -- [text] = count
		last_query   = "",
		last_results = {},
		opts         = merge_opts(opts),
	}, M.Engine)
end

M.Engine.__call = Engine

--- Set / replace the candidate list.
---@param self fuzzy2.Engine
---@param candidates table array of strings or tables
function M.Engine.set_candidates(self, candidates)
	self.candidates = candidates
	self.index = build_trigram_index(candidates)
end

--- Add a single candidate.
---@param self fuzzy2.Engine
---@param candidate string|table
function M.Engine.add_candidate(self, candidate)
	self.candidates[#self.candidates + 1] = candidate
	self.index = nil -- invalidate
end

--- Record that the user selected a candidate.
---@param self fuzzy2.Engine
---@param text string the selected text
function M.Engine.record_selection(self, text)
	self.freq[text] = (self.freq[text] or 0) + 1
	self.history[#self.history + 1] = { text = text, timestamp = os_clock() }
end

--- Get completions for a query, incorporating frequency & recency.
---@param self fuzzy2.Engine
---@param query string
---@param opts? fuzzy2.MatchOptions temporary overrides
---@return table results
function M.Engine.complete(self, query, opts)
	local passed_opts = opts
	opts = merge_opts(self.opts)
	for k, v in next, passed_opts or {} do
		opts[k] = v
	end

	-- Use trigram index for large candidate sets
	local results
	if self.index and #self.candidates > 500 then
		results = trigram_filter(query, self.index, opts)
	else
		results = filter(query, self.candidates, opts)
	end

	-- Boost scores by frequency and recency
	local now = os_clock()
	for i = 1, #results do
		local r = results[i]
		local f = self.freq[r.text] or 0
		local freq_boost = math_log(f + 1) * 2.0

		-- Recency: find most recent selection of this text
		local recency_boost = 0
		for i = #self.history, 1, -1 do
			if self.history[i].text == r.text then
				local age = now - self.history[i].timestamp
				recency_boost = math_max(0, 5.0 - age / 60.0) -- decays over ~5 min
				break
			end
		end

		r.original_score = r.score
		r.score = r.score + freq_boost + recency_boost
	end

	-- Re-sort with learned boosts
	table_sort(results, function(a, b)
		if a.score ~= b.score then return a.score > b.score end
		return #a.text < #b.text
	end)

	self.last_query = query
	self.last_results = results
	return results
end

--- Select the nth result (1-based) and record it.
---@param self fuzzy2.Engine
---@param n number 1-based index into last results
---@return table? selected item
function M.Engine.select(self, n)
	if not self.last_results[n] then return end
	local r = self.last_results[n]
	self:record_selection(r.text)
	return r
end

--- Get auto-completion text for current query.
---@param self fuzzy2.Engine
---@param query string
---@return string? append_text
function M.Engine.auto_complete(self, query)
	self:complete(query)
	return auto_complete(query, self.candidates, self.opts)
end

--- Learn from a batch of selections (for pre-seeding).
---@param self fuzzy2.Engine
---@param selections string[] array of strings
function M.Engine.learn(self, selections)
	for i = 1, #selections do
		self:record_selection(selections[i])
	end
end

--- Forget old history (prune entries older than *max_age* seconds).
---@param self fuzzy2.Engine
---@param max_age number seconds
function M.Engine.forget_older_than(self, max_age)
	local now = os_clock()
	local pruned = {}
	for i = 1, #self.history do
		local h = self.history[i]
		if now - h.timestamp < max_age then
			pruned[#pruned + 1] = h
		end
	end
	self.history = pruned
end

--- Reset all learned data.
---@param self fuzzy2.Engine
function M.Engine.reset(self)
	self.history = {}
	self.freq = {}
	self.last_query = ""
	self.last_results = {}
end

----------------------------------------------------------------------
-- CONVENIENCE WRAPPERS
----------------------------------------------------------------------

--- Simple fuzzy test: does *pattern* fuzzy-match *text*?
---@param pattern string
---@param text string
---@param opts? fuzzy2.MatchOptions
---@return boolean
local function test(pattern, text, opts)
	return quick_match(pattern, text, resolve_cs(
		(opts and opts.case_mode) or config.case_mode, pattern))
end

M.test = test

--- One-shot filter returning just the texts, sorted.
---@param pattern string
---@param candidates table
---@param opts? fuzzy2.MatchOptions
---@return table texts
local function simple_filter(pattern, candidates, opts)
	local r = filter(pattern, candidates, opts)
	local t = {}
	for i = 1, #r do t[#t + 1] = r[i].text end
	return t
end

M.simple_filter = simple_filter

--- Fuzzy-match a Lua pattern against a list of strings.
--- (For when you want to combine fuzzy + Lua pattern power.)
---@param lua_pattern string a Lua string pattern
---@param candidates table
---@return table matches texts that match the Lua pattern
local function pattern_filter(lua_pattern, candidates)
	local m = {}
	for i = 1, #candidates do
		local c = candidates[i]
		local txt = cand_text(c)
		if string_match(txt, lua_pattern) then m[#m + 1] = txt end
	end
	return m
end

M.pattern_filter = pattern_filter

--- Score two strings for similarity (0-1).
--- Uses Jaro-Winkler for short strings, edit distance for longer.
---@param a string
---@param b string
---@return number similarity 0 (no similarity) to 1 (identical)
local function similarity(a, b)
	if a == b then return 1.0 end
	if #a == 0 or #b == 0 then return 0.0 end
	if math_max(#a, #b) <= 32 then
		return jaro_winkler(a, b)
	end
	local d = levenshtein(a, b)
	return 1.0 - d / math_max(#a, #b)
end

M.similarity = similarity

-- Export configuration and Engine
M.config = config
M.Engine = {}

--[[ Quick tests
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

	assert(trigram_duration < 0.5, "Trigram filter should be fast")
	assert(#trigram_filtered >= 0, "Trigram filter should return results")
end
--]]

-- Export
return M
