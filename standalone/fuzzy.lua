-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

---@class FuzzyScoreResult
---@field score number Normalized score [0, 1]
---@field positions integer[] Matched character positions

---@class FuzzySuggestion
---@field item table Original item with key and meta
---@field score number Combined score
---@field raw number Raw fuzzy score

---@class FuzzyBestMatchResult
---@field score number
---@field highlighted string Highlighted string
---@field positions integer[]

---@class FuzzyHighlightOptions
---@field open? string Opening marker (default: "*")
---@field close? string Closing marker (default: "*")

---@class FuzzyScoreOptions
---@field case_sensitive? boolean Auto-detect if nil

---@class FuzzySuggestOptions
---@field limit? integer Max results (default: 10)
---@field case_sensitive? boolean Auto-detect if nil
---@field recency_weight? number Weight for recency scoring (default: 0.5)
---@field frequency_weight? number Weight for frequency scoring (default: 1.0)

---@class FuzzyBestMatchOptions
---@field case_sensitive? boolean Auto-detect if nil
---@field highlight? FuzzyHighlightOptions Highlight markers

---@class FuzzyEngineOptions
---@field decay_rate? number Recency decay rate per tick (default: 0.01)
---@field recency_boost? number Boost amount on use (default: 10)

---@class FuzzyEngineItem
---@field key string
---@field meta any
---@field _freq number Usage frequency
---@field _recency number Recency score

---@class FuzzyModule
---@field split_tokens fun(s: string): string[]
---@field smart_case_sensitive fun(query: string): boolean
---@field levenshtein fun(a: string, b: string): integer
---@field damerau_levenshtein fun(a: string, b: string): integer
---@field jaro_winkler fun(a: string, b: string, prefix_scale: number?): number
---@field fuzzy_score fun(query: string, target: string, opts: FuzzyScoreOptions?): FuzzyScoreResult
---@field acronym_match fun(query: string, target: string, opts: FuzzyScoreOptions?): FuzzyScoreResult
---@field multi_token_score fun(query: string, target: string, opts: FuzzyScoreOptions?): FuzzyScoreResult
---@field typo_tolerant_score fun(query: string, target: string, opts: FuzzyScoreOptions?): FuzzyScoreResult
---@field highlight_positions fun(target: string, positions: integer[], opts: FuzzyHighlightOptions?): string
---@field suggest fun(items: table[], query: string, opts: FuzzySuggestOptions?): FuzzySuggestion[]
---@field best_match_and_highlight fun(query: string, target: string, opts: FuzzyBestMatchOptions?): FuzzyBestMatchResult
local fuzzy = {}

-- Localized global functions for performance
local setmetatable = setmetatable
local type = type
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local string_find = string.find
local string_gmatch = string.gmatch
local string_lower = string.lower
local string_match = string.match
local string_sub = string.sub
local table_concat = table.concat
local table_insert = table.insert
local table_sort = table.sort
local table_unpack = table.unpack

-- Utility helpers
local function is_upper(ch) return string_match(ch, "%u") ~= nil end
local function split_tokens(s)
	local t = {}
	for token in string_gmatch(s, "%S+") do t[#t + 1] = token end
	return t
end

--- Detect if query should use case-sensitive matching
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

--- Levenshtein distance (classic edit distance)
---@param a string
---@param b string
---@return integer distance
local function levenshtein(a, b)
	if a == b then return 0 end
	local la, lb = #a, #b
	if la == 0 then return lb end
	if lb == 0 then return la end
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
			local v = deletion
			if insertion < v then v = insertion end
			if substitution < v then v = substitution end
			cur[j] = v
		end
		prev = cur
	end
	return prev[lb]
end

--- Damerau-Levenshtein distance (with adjacent transpositions)
---@param a string
---@param b string
---@return integer distance
local function damerau_levenshtein(a, b)
	if a == b then return 0 end
	local la, lb = #a, #b
	local INF = la + lb
	local da = {}
	local maxdist = la + lb
	local d = {}
	d[0] = {}
	d[0][0] = maxdist
	for i = 0, la do
		d[i + 1] = d[i + 1] or {}
		d[i + 1][0] = maxdist
		d[i + 1][1] = i
	end
	for j = 0, lb do
		d[1] = d[1] or {}
		d[1][j + 1] = j
	end
	for i = 1, la do
		local db = 0
		for j = 1, lb do
			local i1 = da[string_sub(b, j, j)] or 0
			local j1 = db
			local cost = 1
			if string_sub(a, i, i) == string_sub(b, j, j) then
				cost = 0
				db = j
			end
			local transposition_cost = (d[i1] and d[i1][j1]) and (d[i1][j1] + (i - i1 - 1) + 1 + (j - j1 - 1)) or INF
			d[i + 1][j + 1] = math_min(
				d[i][j] + cost,
				d[i + 1][j] + 1,
				d[i][j + 1] + 1,
				transposition_cost
			)
		end
		da[string_sub(a, i, i)] = i
	end
	return d[la + 1][lb + 1]
end

-- Jaro similarity and Jaro-Winkler
local function jaro(a, b)
	if a == b then return 1.0 end
	local la, lb = #a, #b
	if la == 0 or lb == 0 then return 0.0 end
	local match_distance = math_floor(math_max(la, lb) / 2) - 1
	if match_distance < 0 then match_distance = 0 end
	local a_matches = {}
	local b_matches = {}
	for i = 1, la do a_matches[i] = false end
	for j = 1, lb do b_matches[j] = false end
	local matches = 0
	for i = 1, la do
		local start = math_max(1, i - match_distance)
		local finish = math_min(lb, i + match_distance)
		for j = start, finish do
			if not b_matches[j] and string_sub(a, i, i) == string_sub(b, j, j) then
				a_matches[i] = true
				b_matches[j] = true
				matches = matches + 1
				break
			end
		end
	end
	if matches == 0 then return 0.0 end
	local t = 0
	local k = 1
	for i = 1, la do
		if a_matches[i] then
			while not b_matches[k] do k = k + 1 end
			if string_sub(a, i, i) ~= string_sub(b, k, k) then t = t + 1 end
			k = k + 1
		end
	end
	t = t / 2
	return ((matches / la) + (matches / lb) + ((matches - t) / matches)) / 3
end

--- Jaro-Winkler similarity metric
---@param a string
---@param b string
---@param prefix_scale? number Scale for prefix bonus (default: 0.1)
---@return number similarity Score between 0 and 1
local function jaro_winkler(a, b, prefix_scale)
	prefix_scale = prefix_scale or 0.1
	local j = jaro(a, b)
	local prefix = 0
	for i = 1, math_min(4, #a, #b) do
		if string_sub(a, i, i) == string_sub(b, i, i) then prefix = prefix + 1 else break end
	end
	return j + prefix * prefix_scale * (1 - j)
end

--- Fuzzy subsequence matching with DP scoring
--- Score favors contiguous matches, matches at token boundaries, and earlier matches
---@param query string Search query
---@param target string Target string to match against
---@param opts? FuzzyScoreOptions
---@return FuzzyScoreResult result
local function fuzzy_score(query, target, opts)
	opts = opts or {}
	local case_sensitive = opts.case_sensitive
	if case_sensitive == nil then case_sensitive = smart_case_sensitive(query) end
	local q = case_sensitive and query or string_lower(query)
	local t = case_sensitive and target or string_lower(target)

	local qlen, tlen = #q, #t
	if qlen == 0 or tlen == 0 then return { score = 0.0, positions = {} } end

	-- Check for case-sensitive mismatch: if case_sensitive is true and query chars don't exist in target at all
	if case_sensitive then
		local has_any_match = false
		for i = 1, qlen do
			local qc = string_sub(q, i, i)
			if string_find(t, qc, 1, true) then
				has_any_match = true
				break
			end
		end
		if not has_any_match then
			return
		end
	end

	-- DP arrays: best score ending at target pos for prefix length
	local NEG = -1e9
	local dp_prev = {}
	local dp_cur = {}
	local pos_prev = {}
	local pos_cur = {}

	-- initialize
	for j = 0, tlen do
		dp_prev[j] = 0
		pos_prev[j] = {}
	end

	-- scoring weights
	local match_base = 1.0
	local adjacency_bonus = 0.7
	local boundary_bonus = 0.9
	local start_bonus = 0.6
	local gap_penalty = 0.15

	for i = 1, qlen do
		local qi = string_sub(q, i, i)
		for j = 1, tlen do
			dp_cur[j] = NEG
			pos_cur[j] = nil
			if qi == string_sub(t, j, j) then
				-- find best previous j0 < j
				local best = NEG
				local bestpos
				for j0 = 0, j - 1 do
					local base = dp_prev[j0] or NEG
					if base > NEG then
						local score = base + match_base
						-- adjacency bonus
						if j0 > 0 and pos_prev[j0] and #pos_prev[j0] > 0 then
							local lastpos = pos_prev[j0][#pos_prev[j0]]
							if lastpos == j - 1 then score = score + adjacency_bonus end
						end
						-- boundary bonus (token boundary or camelCase boundary)
						local ch_before = string_sub(t, j - 1, j - 1)
						if j == 1 or string_match(ch_before, "[%W_]") or (string_match(ch_before, "%l") and string_match(string_sub(t, j, j), "%u")) then
							score = score + boundary_bonus
						end
						-- start bonus
						if j == 1 then score = score + start_bonus end
						-- gap penalty proportional to gap length
						local gap = j - ((pos_prev[j0] and pos_prev[j0][#pos_prev[j0]]) or 0) - 1
						if gap > 0 then score = score - gap * gap_penalty end
						if score > best then
							best = score
							bestpos = (pos_prev[j0] and { table_unpack(pos_prev[j0]) }) or {}
							if bestpos then bestpos[#bestpos + 1] = j end
						end
					end
				end
				dp_cur[j] = best
				pos_cur[j] = bestpos
			else
				dp_cur[j] = NEG
				pos_cur[j] = nil
			end
		end
		dp_prev, dp_cur = dp_cur, dp_prev
		pos_prev, pos_cur = pos_cur, pos_prev
	end

	-- find best ending position
	local bestScore = NEG
	local bestPositions = {}
	for j = 1, tlen do
		if dp_prev[j] and dp_prev[j] > bestScore then
			bestScore = dp_prev[j]
			bestPositions = pos_prev[j] or {}
		end
	end

	if bestScore == NEG then
		return { score = 0.0, positions = {} }
	end

	-- normalize score to [0,1] roughly
	local norm = bestScore / (qlen * (match_base + adjacency_bonus))
	if norm < 0 then norm = 0 end
	if norm > 1 then norm = 1 end
	return { score = norm, positions = bestPositions }
end

--- Acronym / initialism matching
---@param query string
---@param target string
---@param opts? FuzzyScoreOptions
---@return FuzzyScoreResult result
local function acronym_match(query, target, opts)
	opts = opts or {}
	local case_sensitive = opts.case_sensitive
	if case_sensitive == nil then case_sensitive = smart_case_sensitive(query) end
	local q = case_sensitive and query or string_lower(query)
	local t = case_sensitive and target or string_lower(target)

	-- build initials from target: uppercase letters, letters after separators, and first letter
	local initials = {}
	local last_was_sep = true
	for i = 1, #t do
		local ch = string_sub(t, i, i)
		if last_was_sep and string_match(ch, "%w") then
			table_insert(initials, ch)
			last_was_sep = false
		elseif string_match(ch, "[%_%-%s]") then
			last_was_sep = true
		elseif string_match(ch, "%u") then
			table_insert(initials, ch)
			last_was_sep = false
		end
	end
	local initials_str = table_concat(initials)
	if string_find(initials_str, q, 1, true) then
		return { score = 0.9, positions = {} }
	end
	-- subsequence match of query against initials
	local i, j = 1, 1
	while i <= #q and j <= #initials_str do
		if string_sub(q, i, i) == string_sub(initials_str, j, j) then i = i + 1 end
		j = j + 1
	end
	if i > #q then
		return { score = 0.85, positions = {} }
	end
	return { score = 0.0, positions = {} }
end

--- Multi-token matching and combined scoring
---@param query string Space-separated query tokens
---@param target string Target string
---@param opts? FuzzyScoreOptions
---@return FuzzyScoreResult result
local function multi_token_score(query, target, opts)
	opts = opts or {}
	local tokens = split_tokens(query)
	if #tokens == 0 then return { score = 0.0, positions = {} } end
	local total_score = 0
	local positions = {}
	for i = 1, #tokens do
		local tok = tokens[i]
		local res = fuzzy_score(tok, target, opts)
		if res.score == 0 then
			-- try acronym
			local acr = acronym_match(tok, target, opts)
			if acr.score == 0 then
				-- try edit distance tolerant fallback
				local case_sensitive = opts.case_sensitive
				if case_sensitive == nil then case_sensitive = smart_case_sensitive(query) end
				local tcmp = case_sensitive and target or string_lower(target)
				local dist = levenshtein(string_lower(tok), string_lower(tcmp))
				local len = math_max(1, #tok)
				local sim = 1 - (dist / len)
				if sim > 0.6 then
					total_score = total_score + sim * 0.6
				else
					return { score = 0.0, positions = {} }
				end
			else
				total_score = total_score + acr.score
			end
		else
			total_score = total_score + res.score
			for j = 1, #res.positions do table_insert(positions, res.positions[j]) end
		end
	end
	local avg = total_score / #tokens
	return { score = avg, positions = positions }
end

--- Typo tolerant matching combining fuzzy subsequence and edit distances
---@param query string
---@param target string
---@param opts? FuzzyScoreOptions
---@return FuzzyScoreResult result
local function typo_tolerant_score(query, target, opts)
	opts = opts or {}
	local case_sensitive = opts.case_sensitive
	if case_sensitive == nil then case_sensitive = smart_case_sensitive(query) end
	local q = case_sensitive and query or string_lower(query)
	local t = case_sensitive and target or string_lower(target)

	-- primary: subsequence score
	local sub = fuzzy_score(q, t, { case_sensitive = case_sensitive })
	if sub.score >= 0.6 then return sub end
	-- if query is empty, all items should match perfectly
	if #q == 0 then
		return { score = 1.0, positions = {} }
	end

	-- fallback: compute edit distances and jaro-winkler
	local lev = levenshtein(q, t)
	local dl = damerau_levenshtein(q, t)
	local jw_score = jaro_winkler(q, t)
	-- normalize distances
	local maxlen = math_max(1, #q, #t)
	local lev_norm = 1 - (lev / maxlen)
	local dl_norm = 1 - (dl / maxlen)
	local score = math_max(sub.score * 0.8, lev_norm * 0.6 + dl_norm * 0.2 + jw_score * 0.2)
	if score < 0 then score = 0 end
	return { score = score, positions = sub.positions }
end

--- Highlight matched positions in a string
---@param target string Original string
---@param positions integer[] Positions to highlight
---@param opts? FuzzyHighlightOptions
---@return string highlighted
local function highlight_positions(target, positions, opts)
	opts = opts or {}
	local open = opts.open or "*"
	local close = opts.close or "*"
	if #positions == 0 then return target end
	local out = {}
	local last = 1
	for i = 1, #positions do
		local p = positions[i]
		local s = p
		local e = p
		-- allow single char positions; if positions are contiguous, they should be adjacent
		if s > last then
			table_insert(out, string_sub(target, last, s - 1))
		end
		table_insert(out, open .. string_sub(target, s, e) .. close)
		last = e + 1
	end
	if last <= #target then table_insert(out, string_sub(target, last)) end
	return table_concat(out)
end

--- Autocomplete suggestion generator
---@param items table[] Array of {key=string, meta=any, _freq?: number, _recency?: number}
---@param query string User input query
---@param opts? FuzzySuggestOptions
---@return FuzzySuggestion[] suggestions
local function suggest(items, query, opts)
	opts = opts or {}
	local limit = opts.limit or 10
	local case_sensitive = opts.case_sensitive
	if case_sensitive == nil then case_sensitive = smart_case_sensitive(query) end
	local results = {}
	for i = 1, #items do
		local item = items[i]
		local key = item.key or item
		local score = typo_tolerant_score(query, key, { case_sensitive = case_sensitive }).score
		-- combine with stored metadata if present
		local freq = (item._freq or 0)
		local recency = (item._recency or 0)
		local combined = score * 0.6 + (freq / (freq + 5)) * (opts.frequency_weight or 1.0) * 0.3 +
			(recency / (recency + 60)) * (opts.recency_weight or 0.5) * 0.1
		table_insert(results, { item = item, score = combined, raw = score })
	end
	table_sort(results, function(a, b) return a.score > b.score end)
	local out = {}
	for i = 1, math_min(limit, #results) do
		table_insert(out, results[i])
	end
	return out
end

-- Stateful IntelliSense engine
---@class FuzzyEngine
---@field items FuzzyEngineItem[]
---@field time number
---@field opts FuzzyEngineOptions
---@field tick fun(self: FuzzyEngine)
---@field record_use fun(self: FuzzyEngine, key: string)
---@field suggest fun(self: FuzzyEngine, query: string, opts: FuzzySuggestOptions?): FuzzySuggestion[]
---@field add fun(self: FuzzyEngine, key: string, meta: any)
---@field save_state fun(self: FuzzyEngine): table[]
---@field load_state fun(self: FuzzyEngine, state: table[]?)
local Engine = {}
Engine.__index = Engine

--- Create a new fuzzy Engine instance
---@param items table[] Initial items as {key=string, meta=any} or strings
---@param opts? FuzzyEngineOptions
---@return FuzzyEngine
function fuzzy.Engine(items, opts)
	opts = opts or {}
	local self = setmetatable({
		time = 0,
		opts = opts,
		items = {},
	}, Engine)
	local items_list = items or {}
	for i = 1, #items_list do
		local it = items_list[i]
		local entry = {}
		if type(it) == "table" then
			entry.key = it.key
			entry.meta = it.meta
			entry._freq = it._freq
			entry._recency = it._recency
		else
			entry.key = it
			entry._freq = 0
			entry._recency = 0
		end
		self.items[#self.items + 1] = entry
	end
	return self
end

--- Advance engine time and decay recency scores
function Engine:tick()
	self.time = self.time + 1
	-- decay recency slowly
	for i = 1, #self.items do
		local it = self.items[i]
		it._recency = math_max(0, it._recency - 0.01)
	end
end

--- Record usage of a key (increments frequency and recency)
---@param key string
function Engine:record_use(key)
	for i = 1, #self.items do
		local it = self.items[i]
		if it.key == key then
			it._freq = it._freq + 1
			it._recency = it._recency + 10
			return
		end
	end
	-- if not found, add
	self.items[#self.items + 1] = { key = key, meta = nil, _freq = 1, _recency = 10 }
end

--- Get suggestions from engine items
---@param query string
---@param opts? FuzzySuggestOptions
---@return FuzzySuggestion[] suggestions
function Engine:suggest(query, opts)
	opts = opts or {}
	local merged = {}
	for i = 1, #self.items do merged[#merged + 1] = self.items[i] end
	return suggest(merged, query, opts)
end

--- Add a new item to the engine
---@param key string
---@param meta any
function Engine:add(key, meta)
	self.items[#self.items + 1] = { key = key, meta = meta, _freq = 0, _recency = 0 }
end

--- Save engine state for persistence
---@return table[] state Array of serializable items
function Engine:save_state()
	-- return a serializable table for persistence
	local out = {}
	for i = 1, #self.items do
		local it = self.items[i]
		out[#out + 1] = { key = it.key, meta = it.meta, _freq = it._freq, _recency = it._recency }
	end
	return out
end

--- Load engine state from persisted data
---@param state? table[]
function Engine:load_state(state)
	---@type FuzzyEngineItem[]
	self.items = {}
	local state_list = state or {}
	for i = 1, #state_list do
		---@type FuzzyEngineItem
		local it = state_list[i]
		self.items[#self.items + 1] = { key = it.key, meta = it.meta, _freq = it._freq or 0, _recency = it._recency or 0 }
	end
end

--- Convenience function for matching and highlighting best match
---@param query string
---@param target string
---@param opts? FuzzyBestMatchOptions
---@return FuzzyBestMatchResult result
local function best_match_and_highlight(query, target, opts)
	opts = opts or {}
	local case_sensitive = opts.case_sensitive
	if case_sensitive == nil then case_sensitive = smart_case_sensitive(query) end
	local res = typo_tolerant_score(query, target, { case_sensitive = case_sensitive })
	local highlighted = target
	if res.positions and #res.positions > 0 then
		highlighted = highlight_positions(target, res.positions, opts.highlight or { open = "[", close = "]" })
	end
	return { score = res.score, highlighted = highlighted, positions = res.positions }
end

-- Expose functions
fuzzy.split_tokens = split_tokens
fuzzy.smart_case_sensitive = smart_case_sensitive
fuzzy.levenshtein = levenshtein
fuzzy.damerau_levenshtein = damerau_levenshtein
fuzzy.jaro_winkler = jaro_winkler
fuzzy.fuzzy_score = fuzzy_score
fuzzy.acronym_match = acronym_match
fuzzy.multi_token_score = multi_token_score
fuzzy.typo_tolerant_score = typo_tolerant_score
fuzzy.highlight_positions = highlight_positions
fuzzy.suggest = suggest
fuzzy.best_match_and_highlight = best_match_and_highlight

--[[ Quick tests
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
--]]

-- Export
return fuzzy
