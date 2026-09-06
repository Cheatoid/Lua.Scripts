-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Pattern matching engine
--
-- Supports:
--	. %a %A %c %C %d %D %g %G %l %L %p %P %s %S %u %U %w %W %x %X %z %Z
--	[sets], [^sets], ranges, classes inside sets
--	* + - ? quantifiers
--	^ $ anchors
--	() captures, () position captures
--	%1-%9 backreferences
--	%bxy balanced matches
--	%f[set] frontier patterns
--	plain searching in find

-- Localized global functions for better performance
local string_byte = string.byte
local string_char = string.char
local string_sub = string.sub
local table_concat = table.concat
local table_unpack = table.unpack or unpack

local M = {}

----------------------------------------------------------------------
-- Character classes
----------------------------------------------------------------------

--- Create a byte map (0-255) where bytes satisfying the predicate are true.
---@param pred fun(byte: number): boolean Predicate to test each byte value.
---@return table map Byte map with true for matching bytes.
local function make_map(pred)
	local m = {}
	for b = 0, 255 do
		if pred(b) then
			m[b] = true
		end
	end
	return m
end

--- Invert a byte map: true becomes false, false becomes true.
---@param m table Byte map to invert.
---@return table r Inverted byte map.
local function invert_map(m)
	local r = {}
	for b = 0, 255 do
		if not m[b] then
			r[b] = true
		end
	end
	return r
end

-- Character class maps for lowercase class letters (a, c, d, g, l, p, s, u, w, x, z).
-- Each map is a lookup table where true indicates the byte belongs to the class.
local class_maps = {
	a = make_map(function(b) -- %a: letters (A-Z, a-z)
		return (b >= 65 and b <= 90) or (b >= 97 and b <= 122)
	end),

	c = make_map(function(b) -- %c: control characters (0-31, 127)
		return b < 32 or b == 127
	end),

	d = make_map(function(b) -- %d: digits (0-9)
		return b >= 48 and b <= 57
	end),

	g = make_map(function(b) -- %g: printable characters (33-126)
		return b >= 33 and b <= 126
	end),

	l = make_map(function(b) -- %l: lowercase letters (a-z)
		return b >= 97 and b <= 122
	end),

	p = make_map(function(b) -- %p: punctuation characters
		return (b >= 33 and b <= 47)
			or (b >= 58 and b <= 64)
			or (b >= 91 and b <= 96)
			or (b >= 123 and b <= 126)
	end),

	s = make_map(function(b) -- %s: whitespace (space, tab, newline, etc.)
		return b == 32 or (b >= 9 and b <= 13)
	end),

	u = make_map(function(b) -- %u: uppercase letters (A-Z)
		return b >= 65 and b <= 90
	end),

	w = make_map(function(b) -- %w: alphanumeric (0-9, A-Z, a-z)
		return (b >= 48 and b <= 57)
			or (b >= 65 and b <= 90)
			or (b >= 97 and b <= 122)
	end),

	x = make_map(function(b) -- %x: hexadecimal digits (0-9, A-F, a-f)
		return (b >= 48 and b <= 57)
			or (b >= 65 and b <= 70)
			or (b >= 97 and b <= 102)
	end),

	z = make_map(function(b) -- %z: null character (0)
		return b == 0
	end),
}

-- Generate negated character class maps (e.g., %A, %D, etc.)
-- Uppercase class letters map to the inverse of their lowercase counterparts.
local class_not_maps = {}
for k, m in next, class_maps do
	class_not_maps[k] = invert_map(m)
end

--- Check if a byte value represents an ASCII letter (A-Z or a-z).
---@param b number Byte value to check.
---@return boolean is_letter True if byte is an ASCII letter.
local function is_letter_byte(b)
	return (b >= 65 and b <= 90) or (b >= 97 and b <= 122)
end

--- Get the byte map for a character class escape.
---@param b number Byte value of the class letter (e.g., 97 for 'a').
---@return table? map The byte map for the class, or nil if not a valid class.
local function map_for_class_byte(b)
	local upper = (b >= 65 and b <= 90)
	local lc = upper and (b + 32) or b
	local letter = string_char(lc)
	local base = class_maps[letter]
	if not base then
		return nil
	end
	if upper then
		return class_not_maps[letter]
	end
	return base
end

--- Merge all keys from src map into dst map.
---@param dst table Destination byte map.
---@param src table Source byte map.
local function merge_map(dst, src)
	for k in pairs(src) do
		dst[k] = true
	end
end

----------------------------------------------------------------------
-- Parser
----------------------------------------------------------------------

--- Parse [...] starting at the byte index of '['.
---@param p string The pattern string.
---@param i number Current byte index (points to '[').
---@param len number Length of the pattern string.
---@return table map Byte map representing the character set.
---@return number next_i Index after the closing ']'.
local function parse_set(p, i, len)
	i = i + 1 -- skip '['

	local complement = false
	if string_byte(p, i) == 94 then -- '^'
		complement = true
		i = i + 1
	end

	local map = {}
	local first = true

	while i <= len do
		local b = string_byte(p, i)

		-- A ']' closes the set unless it is the first character.
		if b == 93 and not first then
			i = i + 1
			if complement then
				map = invert_map(map)
			end
			return map, i
		end

		first = false

		local lit, added

		if b == 37 then -- '%'
			local eb = string_byte(p, i + 1)
			if eb == nil then
				return error("malformed pattern (ends with '%')")
			end

			if is_letter_byte(eb) then
				local cmap = map_for_class_byte(eb)
				merge_map(map, cmap)
				i = i + 2
				added = true
			else
				lit = eb
				i = i + 2
			end
		else
			lit = b
			i = i + 1
		end

		if not added then
			local nb = string_byte(p, i)

			-- Possible range: lit-X
			if nb == 45 then -- '-'
				local ab = string_byte(p, i + 1)

				if ab ~= nil and ab ~= 93 then
					local hi
					local new_i
					local not_range = false

					if ab == 37 then -- '%'
						local esc = string_byte(p, i + 2)
						if esc == nil then
							return error("malformed pattern (ends with '%')")
						end

						if is_letter_byte(esc) then
							-- %letter inside a set is a class, not a range endpoint.
							not_range = true
						else
							hi = esc
							new_i = i + 3
						end
					else
						hi = ab
						new_i = i + 2
					end

					if not_range then
						map[lit] = true
						-- Leave '-' to be processed as a literal.
					else
						if lit > hi then
							return error("malformed pattern (range out of order)")
						end
						for bb = lit, hi do
							map[bb] = true
						end
						i = new_i
					end
				else
					-- '-' at the end or before ']' is literal.
					map[lit] = true
				end
			else
				map[lit] = true
			end
		end
	end

	return error("malformed pattern (missing ']')")
end

--- Parse a sequence of pattern items into an AST (abstract syntax tree).
---@param p string The pattern string.
---@param i number Current byte index.
---@param len number Length of the pattern string.
---@param stop? number Byte value to stop at (e.g., 41 for ')').
---@param count number Current capture count.
---@return table seq Sequence of AST nodes.
---@return number next_i Index after parsing.
---@return number cap_count Updated capture count.
local function parse_seq(p, i, len, stop, count)
	local seq = {}

	while i <= len do
		local b = string_byte(p, i)

		if stop and b == stop then
			return seq, i, count
		end

		local node

		if b == 40 then                -- '('
			if string_byte(p, i + 1) == 41 then -- '()'
				count = count + 1
				node = {
					type = "poscap",
					id = count,
				}
				i = i + 2
			else
				count = count + 1
				local id = count

				local body, new_i, count2 = parse_seq(p, i + 1, len, 41, count)
				if new_i > len or string_byte(p, new_i) ~= 41 then
					return error("unfinished capture")
				end

				i = new_i + 1
				node = {
					type = "capture",
					id = id,
					body = body,
				}
				count = count2
			end
		elseif b == 41 then -- ')'
			if stop == 41 then
				return seq, i, count
			end
			return error("invalid pattern capture")
		elseif b == 46 then -- '.'
			node = { type = "any" }
			i = i + 1
		elseif b == 37 then -- '%'
			local nb = string_byte(p, i + 1)
			if nb == nil then
				return error("malformed pattern (ends with '%')")
			end

			if nb == 48 then         -- '%0'
				return error("invalid capture index")
			elseif nb >= 49 and nb <= 57 then -- '%1'..'%9'
				node = {
					type = "backref",
					n = nb - 48,
				}
				i = i + 2
			elseif nb == 98 then -- '%b'
				local ob = string_byte(p, i + 2)
				local cb = string_byte(p, i + 3)
				if ob == nil or cb == nil then
					return error("malformed pattern (missing arguments to '%b')")
				end

				node = {
					type = "bal",
					open = ob,
					close = cb,
				}
				i = i + 4
			elseif nb == 102 then       -- '%f'
				if string_byte(p, i + 2) ~= 91 then -- '['
					return error("missing '[' after '%f' in pattern")
				end

				local map, new_i = parse_set(p, i + 2, len)
				node = {
					type = "frontier",
					map = map,
				}
				i = new_i
			else
				local cmap = map_for_class_byte(nb)
				if cmap then
					node = {
						type = "map",
						map = cmap,
					}
				else
					node = {
						type = "lit",
						byte = nb,
					}
				end
				i = i + 2
			end
		elseif b == 91 then -- '['
			local map, new_i = parse_set(p, i, len)
			node = {
				type = "map",
				map = map,
			}
			i = new_i
		else
			node = {
				type = "lit",
				byte = b,
			}
			i = i + 1
		end

		-- Optional quantifier (not for captures).
		if node.type ~= "capture" and node.type ~= "poscap" then
			local qb = string_byte(p, i)
			if qb == 42 or qb == 43 or qb == 45 or qb == 63 then
				-- '*', '+', '-', '?'
				node.quant = string_char(qb)
				i = i + 1
			end
		end

		node.pure = (node.type ~= "capture" and node.type ~= "poscap")

		seq[#seq + 1] = node
	end

	return seq, i, count
end

-- Pattern compilation cache using weak keys to allow garbage collection.
-- Patterns are compiled once and reused for better performance.
local cache = setmetatable({}, { __mode = "k" })

--- Compile a pattern string into an optimized AST.
---@param pattern string|number The pattern string to compile.
---@return table compiled Compiled pattern with seq, anchors, cap_count, and prefix_byte.
local function compile(pattern)
	pattern = tostring(pattern)

	local cached = cache[pattern]
	if cached then
		return cached
	end

	local plen = #pattern
	local anchor_start = false
	local anchor_end = false

	local start_i = 1
	local end_i = plen

	-- Leading '^'
	if plen > 0 and string_byte(pattern, 1) == 94 then
		anchor_start = true
		start_i = 2
	end

	-- Trailing '$', unless escaped by an odd number of '%' characters.
	if end_i >= start_i and string_byte(pattern, end_i) == 36 then
		local percent_count = 0
		local j = end_i - 1
		while j >= start_i and string_byte(pattern, j) == 37 do
			percent_count = percent_count + 1
			j = j - 1
		end

		if percent_count % 2 == 0 then
			anchor_end = true
			end_i = end_i - 1
		end
	end

	local seq, _, cap_count = parse_seq(pattern, start_i, end_i, nil, 0)

	-- Simple first-byte optimization.
	local prefix_byte
	local first = seq[1]
	if first
		and first.type == "lit"
		and first.pure
		and (first.quant == nil or first.quant == "+")
	then
		prefix_byte = first.byte
	end

	local compiled = {
		seq = seq,
		anchor_start = anchor_start,
		anchor_end = anchor_end,
		cap_count = cap_count,
		prefix_byte = prefix_byte,
	}

	cache[pattern] = compiled
	return compiled
end

----------------------------------------------------------------------
-- Matching engine
----------------------------------------------------------------------

--- Match a single "pure" node (no captures) at the given position.
---@param s string The input string.
---@param len number Length of the input string.
---@param node table The AST node to match.
---@param pos number Current position in the string.
---@param caps table Captures table.
---@return number? next_pos New position if match succeeds, nil otherwise.
local function match_single_pure(s, len, node, pos, caps)
	local t = node.type

	if t == "map" then
		if pos > len then
			return nil
		end
		if node.map[string_byte(s, pos)] then
			return pos + 1
		end
	elseif t == "lit" then
		if pos <= len and string_byte(s, pos) == node.byte then
			return pos + 1
		end
	elseif t == "any" then
		if pos <= len then
			return pos + 1
		end
	elseif t == "bal" then
		if pos <= len and string_byte(s, pos) == node.open then
			local depth = 1
			local i = pos + 1
			while i <= len do
				local b = string_byte(s, i)
				if b == node.close then
					depth = depth - 1
					if depth == 0 then
						return i + 1
					end
				elseif b == node.open then
					depth = depth + 1
				end
				i = i + 1
			end
		end
	elseif t == "frontier" then
		local prev_in = false
		if pos > 1 then
			prev_in = node.map[string_byte(s, pos - 1)] or false
		end
		local curr_in = false
		if pos <= len then
			curr_in = node.map[string_byte(s, pos)] or false
		end
		if (not prev_in) and curr_in then
			return pos
		end
	elseif t == "backref" then
		local cap = caps[node.n]
		if type(cap) ~= "string" then
			return error("invalid capture index %" .. node.n .. " in pattern string")
		end
		local clen = #cap
		if clen == 0 then
			return pos
		end
		if pos + clen - 1 <= len and string_sub(s, pos, pos + clen - 1) == cap then
			return pos + clen
		end
	end

	--return nil
end

-- Forward declarations for mutually recursive functions.
local match_seq
local match_node

--- Match a single node (may be impure/capturing) at the given position.
---@param s string The input string.
---@param len number Length of the input string.
---@param node table The AST node to match.
---@param pos number Current position in the string.
---@param caps table Captures table.
---@param cont function Continuation function called on success.
---@return number? result New position if match succeeds, nil otherwise.
local function match_one(s, len, node, pos, caps, cont)
	local t = node.type

	if t == "capture" then
		local old = caps[node.id]
		local r = match_seq(s, len, node.body, 1, pos, caps, function(ep)
			caps[node.id] = string_sub(s, pos, ep - 1)
			return cont(ep)
		end)

		if r == nil then
			caps[node.id] = old
		end
		return r
	elseif t == "poscap" then
		local old = caps[node.id]
		caps[node.id] = pos

		local r = cont(pos)

		if r == nil then
			caps[node.id] = old
		end
		return r
	else
		local np = match_single_pure(s, len, node, pos, caps)
		if np == nil then
			return nil
		end
		return cont(np)
	end
end

--- Match a node with '?' quantifier (zero or one) for pure nodes.
---@param s string The input string.
---@param len number Length of the input string.
---@param node table The AST node to match.
---@param pos number Current position in the string.
---@param caps table Captures table.
---@param cont function Continuation function called on success.
---@return number? result New position if match succeeds, nil otherwise.
local function match_question_pure(s, len, node, pos, caps, cont)
	local np = match_single_pure(s, len, node, pos, caps)
	if np ~= nil then
		local r = cont(np)
		if r ~= nil then
			return r
		end
	end
	return cont(pos)
end

--- Match a node with '*', '+', or '-' quantifier for pure nodes.
---@param s string The input string.
---@param len number Length of the input string.
---@param node table The AST node to match.
---@param pos number Current position in the string.
---@param caps table Captures table.
---@param cont function Continuation function called on success.
---@return number? result New position if match succeeds, nil otherwise.
local function match_quant_pure(s, len, node, pos, caps, cont)
	local q = node.quant
	local positions = { pos }
	local p = pos

	while true do
		local np = match_single_pure(s, len, node, p, caps)
		if np == nil then
			break
		end
		positions[#positions + 1] = np
		if np <= p then
			break
		end
		p = np
	end

	local first = (q == "+") and 2 or 1

	if q == "-" then
		for j = first, #positions do
			local r = cont(positions[j])
			if r ~= nil then
				return r
			end
		end
	else
		for j = #positions, first, -1 do
			local r = cont(positions[j])
			if r ~= nil then
				return r
			end
		end
	end

	--return nil
end

--- Match a node with '?' quantifier (zero or one) for impure nodes.
---@param s string The input string.
---@param len number Length of the input string.
---@param node table The AST node to match.
---@param pos number Current position in the string.
---@param caps table Captures table.
---@param cont function Continuation function called on success.
---@return number? result New position if match succeeds, nil otherwise.
local function match_question_impure(s, len, node, pos, caps, cont)
	local r = match_one(s, len, node, pos, caps, cont)
	if r ~= nil then
		return r
	end
	return cont(pos)
end

--- Match a node with '*', '+', or '-' quantifier for impure nodes.
---@param s string The input string.
---@param len number Length of the input string.
---@param node table The AST node to match.
---@param pos number Current position in the string.
---@param caps table Captures table.
---@param cont function Continuation function called on success.
---@return number? result New position if match succeeds, nil otherwise.
local function match_quant_impure(s, len, node, pos, caps, cont)
	local q = node.quant
	local first = (q == "+") and 2 or 1

	local function try_rep(count, p)
		local function after_one(np)
			if q == "-" then
				if count >= first then
					local r = cont(np)
					if r ~= nil then
						return r
					end
				end
				if np > p then
					return try_rep(count + 1, np)
				end
				return nil
			else
				if np > p then
					local r = try_rep(count + 1, np)
					if r ~= nil then
						return r
					end
				end
				if count >= first then
					return cont(np)
				end
				return nil
			end
		end
		return match_one(s, len, node, p, caps, after_one)
	end

	local r = try_rep(1, pos)
	if r ~= nil then
		return r
	end

	if first == 1 then
		return cont(pos)
	end

	--return nil
end

--- Main node dispatcher: match a node based on its type and quantifier.
---@param s string The input string.
---@param len number Length of the input string.
---@param node table The AST node to match.
---@param pos number Current position in the string.
---@param caps table Captures table.
---@param cont function Continuation function called on success.
---@return number? result New position if match succeeds, nil otherwise.
match_node = function(s, len, node, pos, caps, cont)
	local q = node.quant
	if q == nil then
		if node.pure then
			local np = match_single_pure(s, len, node, pos, caps)
			if np == nil then
				return nil
			end
			return cont(np)
		end
		return match_one(s, len, node, pos, caps, cont)
	end
	if q == "?" then
		if node.pure then
			return match_question_pure(s, len, node, pos, caps, cont)
		end
		return match_question_impure(s, len, node, pos, caps, cont)
	end
	if node.pure then
		return match_quant_pure(s, len, node, pos, caps, cont)
	end
	return match_quant_impure(s, len, node, pos, caps, cont)
end

--- Match a sequence of nodes in order.
---@param s string The input string.
---@param len number Length of the input string.
---@param seq table Sequence of AST nodes.
---@param idx number Current index in the sequence.
---@param pos number Current position in the string.
---@param caps table Captures table.
---@param cont function Continuation function called on success.
---@return number? result New position if match succeeds, nil otherwise.
match_seq = function(s, len, seq, idx, pos, caps, cont)
	if idx > #seq then
		return cont(pos)
	end

	local node = seq[idx]

	return match_node(s, len, node, pos, caps, function(np)
		return match_seq(s, len, seq, idx + 1, np, caps, cont)
	end)
end

----------------------------------------------------------------------
-- Internal search helpers
----------------------------------------------------------------------

--- Normalize the init parameter for string search functions.
---@param len number Length of the input string.
---@param init? number Initial position (default: 1).
---@return number init Normalized init position.
local function normalize_init(len, init)
	init = init or 1

	if init < 0 then
		init = len + init + 1
	end

	if init < 1 then
		init = 1
	end

	return init
end

--- Plain string search (no pattern matching) for use with plain=true in find.
---@param s string The string to search in.
---@param pattern string The literal pattern to search for.
---@param init? number Initial position to start search (default: 1).
---@return number? start Start index of the match, or nil.
---@return number? end End index of the match, or nil.
local function find_plain(s, pattern, init)
	local len = #s
	init = normalize_init(len, init)

	if init > len + 1 then
		return nil
	end

	local plen = #pattern
	if plen == 0 then
		return init, init - 1
	end

	local first = string_byte(pattern, 1)
	local last_start = len - plen + 1

	for i = init, last_start do
		if string_byte(s, i) == first then
			local ok = true

			for j = 2, plen do
				if string_byte(s, i + j - 1) ~= string_byte(pattern, j) then
					ok = false
					break
				end
			end

			if ok then
				return i, i + plen - 1
			end
		end
	end

	--return nil
end

--- Search for a compiled pattern in a string.
---@param s string The string to search in.
---@param pat table Compiled pattern object.
---@param init? number Initial position to start search (default: 1).
---@return number? start Start index of the match, or nil.
---@return number? end End index of the match, or nil.
---@return table? caps Captures table.
---@return number? cap_count Number of captures.
local function find_compiled(s, pat, init)
	local len = #s
	init = normalize_init(len, init)

	if init > len + 1 then
		return nil
	end

	local seq = pat.seq
	local cap_count = pat.cap_count

	local function try_at(start)
		local caps = {}

		local ep = match_seq(s, len, seq, 1, start, caps, function(end_pos)
			if pat.anchor_end and end_pos ~= len + 1 then
				return nil
			end
			return end_pos
		end)

		if ep == nil then
			return nil
		end

		return ep, caps
	end

	if pat.anchor_start then
		local ep, caps = try_at(init)
		if ep == nil then
			return nil
		end
		return init, ep - 1, caps, cap_count
	end

	local prefix = pat.prefix_byte
	local start = init

	while start <= len + 1 do
		if prefix and (start > len or string_byte(s, start) ~= prefix) then
			start = start + 1
		else
			local ep, caps = try_at(start)
			if ep ~= nil then
				return start, ep - 1, caps, cap_count
			end
			start = start + 1
		end
	end

	--return nil
end

----------------------------------------------------------------------
-- Replacement helper for gsub
----------------------------------------------------------------------

--- Expand a replacement string with capture references.
---@param repl string The replacement string pattern.
---@param match_str string The full match string.
---@param caps table Captures table.
---@param cap_count number Number of captures.
---@return string result The expanded replacement string.
local function expand_repl(repl, match_str, caps, cap_count)
	local out = {}
	local i = 1
	local n = #repl

	while i <= n do
		local b = string_byte(repl, i)

		if b == 37 then -- '%'
			i = i + 1
			local nb = string_byte(repl, i)

			if nb == nil then
				return error("invalid replacement string (ends with '%')")
			end

			if nb == 37 then         -- '%%'
				out[#out + 1] = "%"
			elseif nb == 48 then     -- '%0'
				out[#out + 1] = match_str
			elseif nb >= 49 and nb <= 57 then -- '%1'..'%9'
				local idx = nb - 48

				if idx > cap_count then
					return error("invalid capture index in replacement string")
				end

				local cap = caps[idx]
				local ct = type(cap)

				if ct == "string" then
					out[#out + 1] = cap
				elseif ct == "number" then
					out[#out + 1] = tostring(cap)
				else
					return error("invalid capture index in replacement string")
				end
			else
				-- Literal escaped character.
				out[#out + 1] = string_char(nb)
			end

			i = i + 1
		else
			out[#out + 1] = string_char(b)
			i = i + 1
		end
	end

	return table_concat(out)
end

----------------------------------------------------------------------
-- Public API
----------------------------------------------------------------------

--- Find the first occurrence of a pattern in a string.
---@param s string The string to search in.
---@param pattern string The pattern to search for.
---@param init? number Initial position to start search (default: 1).
---@param plain? boolean If true, treat pattern as literal string (no magic characters).
---@return number? start The start index of the match, or nil if no match.
---@return number? end The end index of the match, or nil if no match.
---@return ... captures Additional captured values if pattern contains captures.
---@usage <br>
--- ```
--- local st, en = pattern.find("hello world", "world")
--- -- st = 7, en = 11
---
--- local st, en, cap = pattern.find("hello123", "(%d+)")
--- -- st = 6, en = 8, cap = "123"
--- ```
function M.find(s, pattern, init, plain)
	s = tostring(s)
	pattern = tostring(pattern)

	if plain then
		local st, en = find_plain(s, pattern, init)
		return st, en
	end

	local pat = compile(pattern)
	local st, en, caps, cap_count = find_compiled(s, pat, init)

	if st == nil then
		return nil
	end

	if cap_count > 0 then
		return st, en, table_unpack(caps, 1, cap_count)
	end

	return st, en
end

--- Match a pattern against a string and return captures or the full match.
---@param s string The string to match against.
---@param pattern string The pattern to match.
---@param init? number Initial position to start matching (default: 1).
---@return string? ... Captured values if pattern has captures, or the full match substring, or nil if no match.
---@usage <br>
--- ```
--- local result = pattern.match("hello123world", "%d+")
--- -- result = "123"
---
--- local c1, c2 = pattern.match("John:30", "(%a+):(%d+)")
--- -- c1 = "John", c2 = "30"
--- ```
function M.match(s, pattern, init)
	s = tostring(s)
	pattern = tostring(pattern)

	local pat = compile(pattern)
	local st, en, caps, cap_count = find_compiled(s, pat, init)

	if st == nil then
		return nil
	end

	if cap_count > 0 then
		return table_unpack(caps, 1, cap_count)
	end

	return string_sub(s, st, en)
end

--- Return an iterator function that returns successive matches of a pattern.
---@param s string The string to iterate over.
---@param pattern string The pattern to match.
---@return function iterator An iterator function that returns captures or full match for each match.
---@usage <br>
--- ```
--- for word in pattern.gmatch("one two three", "%a+") do
---   print(word) -- prints "one", "two", "three"
--- end
---
--- for c1, c2 in pattern.gmatch("a1b2c3", "(%a)(%d)") do
---   print(c1, c2) -- prints "a 1", "b 2", "c 3"
--- end
--- ```
function M.gmatch(s, pattern)
	s = tostring(s)
	pattern = tostring(pattern)

	local pat = compile(pattern)
	local len = #s
	local pos = 1
	local done = false

	return function()
		while pos <= len + 1 do
			if done then
				return nil
			end

			local st, en, caps, cap_count = find_compiled(s, pat, pos)
			if st == nil then
				return nil
			end

			-- Anchored gmatch yields at most one match.
			if pat.anchor_start then
				done = true
			end

			if en >= st then
				pos = en + 1
			else
				-- Empty match: advance one character to avoid infinite loop.
				pos = st + 1
			end

			if cap_count > 0 then
				return table_unpack(caps, 1, cap_count)
			end
			return string_sub(s, st, en)
		end
	end
end

--- Replace occurrences of a pattern in a string with a replacement.
---@param s string The string to perform substitution on.
---@param pattern string The pattern to match.
---@param repl string|function|table The replacement: string, function, or lookup table.
---@param n? number Maximum number of replacements (default: all).
---@return string result The string with substitutions applied.
---@return number count The number of substitutions made.
---@usage <br>
--- ```
--- -- String replacement
--- local result = pattern.gsub("hello world", "world", "there")
--- -- result = "hello there"
---
--- -- With captures
--- local result = pattern.gsub("hello", "(%a)", "%1-")
--- -- result = "h-e-l-l-o-"
---
--- -- Function replacement
--- local result = pattern.gsub("abc", "%a", function(c) return c:upper() end)
--- -- result = "ABC"
---
--- -- Table replacement
--- local result = pattern.gsub("abc", "%a", { a = "X", b = "Y", c = "Z" })
--- -- result = "XYZ"
--- ```
function M.gsub(s, pattern, repl, n)
	s = tostring(s)
	pattern = tostring(pattern)

	local pat = compile(pattern)
	local len = #s

	local max = n
	if max == nil then
		max = math.huge
	else
		max = tonumber(max) or 0
	end

	if max < 0 then
		max = 0
	end

	local count = 0
	local out = {}
	local pos = 1
	local last_end = 1

	while pos <= len + 1 and count < max do
		local st, en, caps, cap_count = find_compiled(s, pat, pos)
		if st == nil then
			break
		end

		if st > last_end then
			out[#out + 1] = string_sub(s, last_end, st - 1)
		end

		local match_str = string_sub(s, st, en)
		local replacement

		local rt = type(repl)

		if rt == "string" then
			replacement = expand_repl(repl, match_str, caps, cap_count)
		elseif rt == "function" then
			local v
			if cap_count > 0 then
				v = repl(table_unpack(caps, 1, cap_count))
			else
				v = repl(match_str)
			end

			if v == nil or v == false then
				replacement = match_str
			elseif type(v) == "string" or type(v) == "number" then
				replacement = tostring(v)
			else
				return error("invalid replacement value (a " .. type(v) .. ")")
			end
		elseif rt == "table" then
			local key
			if cap_count > 0 then
				key = caps[1]
			end
			if key == nil then
				key = match_str
			end

			local v = repl[key]

			if v == nil or v == false then
				replacement = match_str
			elseif type(v) == "string" or type(v) == "number" then
				replacement = tostring(v)
			else
				return error("invalid replacement value (a " .. type(v) .. ")")
			end
		else
			return error("bad argument #3 to 'gsub' (string/function/table expected)")
		end

		out[#out + 1] = replacement
		count = count + 1

		local ep = en + 1

		if ep > st then
			pos = ep
			last_end = ep
		else
			-- Empty match: insert replacement, then keep the current character.
			if st <= len then
				out[#out + 1] = string_sub(s, st, st)
				last_end = st + 1
			else
				last_end = st
			end
			pos = st + 1
		end

		-- Anchored gsub performs at most one substitution.
		if pat.anchor_start then
			break
		end
	end

	if last_end <= len then
		out[#out + 1] = string_sub(s, last_end)
	end

	return table_concat(out), count
end

--[=[ Quick tests
if true then
	local string_format = string.format
	local total, passed, failed = 0, 0, 0
	local function test(name, fn)
		total = total + 1
		local ok, err = pcall(fn)
		if ok then
			passed = passed + 1
		else
			failed = failed + 1
			print(string_format("  FAIL  %s: %s", name, tostring(err)))
		end
	end
	local function expect_error(fn, pattern)
		local ok, err = pcall(fn)
		assert(not ok, "expected error but got success: " .. tostring(err))
		if pattern then
			assert(tostring(err):find(pattern, 1, true),
				"error message does not contain '" .. pattern .. "': " .. tostring(err))
		end
	end
	print("[pattern] testing...")

	----------------------------------------------------------------------
	-- find: basic literal matching
	----------------------------------------------------------------------
	test("find literal substring", function()
		local st, en = M.find("hello world", "world")
		assert(st == 7 and en == 11)
	end)

	test("find literal at start", function()
		local st, en = M.find("hello", "hel")
		assert(st == 1 and en == 3)
	end)

	test("find literal at end", function()
		local st, en = M.find("hello", "llo")
		assert(st == 3 and en == 5)
	end)

	test("find literal no match", function()
		local st, en = M.find("hello", "xyz")
		assert(st == nil and en == nil)
	end)

	test("find empty pattern", function()
		local st, en = M.find("hello", "")
		assert(st == 1 and en == 0)
	end)

	test("find empty string in empty string", function()
		local st, en = M.find("", "")
		assert(st == 1 and en == 0)
	end)

	test("find pattern longer than string", function()
		local st, en = M.find("hi", "hello")
		assert(st == nil)
	end)

	----------------------------------------------------------------------
	-- find: plain mode
	----------------------------------------------------------------------
	test("find plain mode ignores magic chars", function()
		local st, en = M.find("a.b", "%.", nil, true)
		assert(st == nil)
	end)

	test("find plain mode finds literal dot", function()
		local st, en = M.find("a.b", ".", nil, true)
		assert(st == 2 and en == 2)
	end)

	test("find plain mode with init", function()
		local st, en = M.find("abcabc", "abc", 4, true)
		assert(st == 4 and en == 6)
	end)

	----------------------------------------------------------------------
	-- find: init parameter
	----------------------------------------------------------------------
	test("find with init parameter", function()
		local st, en = M.find("hello", "l", 4)
		assert(st == 4 and en == 4)
	end)

	test("find with init past match", function()
		local st, en = M.find("hello", "hel", 2)
		assert(st == nil)
	end)

	test("find with negative init", function()
		local st, en = M.find("hello", "o", -1)
		assert(st == 5 and en == 5)
	end)

	test("find with init beyond string", function()
		local st, en = M.find("hello", "o", 100)
		assert(st == nil)
	end)

	----------------------------------------------------------------------
	-- find: character classes
	----------------------------------------------------------------------
	test("find dot (any character)", function()
		local st, en = M.find("aXb", ".")
		assert(st == 1 and en == 1)
	end)

	test("find %a (letter)", function()
		local st, en = M.find("123abc456", "%a+")
		assert(st == 4 and en == 6)
	end)

	test("find %d (digit)", function()
		local st, en = M.find("abc123def", "%d+")
		assert(st == 4 and en == 6)
	end)

	test("find %s (whitespace)", function()
		local st, en = M.find("a b\tc", "%s+")
		assert(st == 2 and en == 2)
	end)

	test("find %w (alphanumeric)", function()
		local st, en = M.find("  hello  ", "%w+")
		assert(st == 3 and en == 7)
	end)

	test("find %l (lowercase)", function()
		local st, en = M.find("ABCabc", "%l+")
		assert(st == 4 and en == 6)
	end)

	test("find %u (uppercase)", function()
		local st, en = M.find("ABCabc", "%u+")
		assert(st == 1 and en == 3)
	end)

	test("find %x (hex digit)", function()
		local st, en = M.find("g0gFF", "%x+")
		assert(st == 2 and en == 2)
	end)

	test("find %A (non-letter)", function()
		local st, en = M.find("a1b2", "%A+")
		assert(st == 2 and en == 2)
	end)

	test("find %D (non-digit)", function()
		local st, en = M.find("1abc2", "%D+")
		assert(st == 2 and en == 4)
	end)

	----------------------------------------------------------------------
	-- find: character sets
	----------------------------------------------------------------------
	test("find character set", function()
		local st, en = M.find("axbyc", "[abc]")
		assert(st == 1 and en == 1)
	end)

	test("find negated character set", function()
		local st, en = M.find("axbyc", "[^abc]+")
		assert(st == 2 and en == 2)
	end)

	test("find character range", function()
		local st, en = M.find("hello123", "[0-9]+")
		assert(st == 6 and en == 8)
	end)

	test("find letter range", function()
		local st, en = M.find("123abc456", "[a-z]+")
		assert(st == 4 and en == 6)
	end)

	test("find set with class inside", function()
		local st, en = M.find("1a 2", "[%d%a]+")
		assert(st == 1 and en == 2)
	end)

	----------------------------------------------------------------------
	-- find: quantifiers
	----------------------------------------------------------------------
	test("find star (zero or more, greedy)", function()
		local st, en = M.find("aaa", "a*")
		assert(st == 1 and en == 3)
	end)

	test("find plus (one or more, greedy)", function()
		local st, en = M.find("aaa", "a+")
		assert(st == 1 and en == 3)
	end)

	test("find minus (zero or more, lazy)", function()
		local st, en = M.find("aaa", "a-")
		assert(st == 1 and en == 0)
	end)

	test("find question (zero or one)", function()
		local st, en = M.find("abc", "a?")
		assert(st == 1 and en == 1)
	end)

	test("find plus on no match", function()
		local st, en = M.find("bcd", "a+")
		assert(st == nil)
	end)

	test("find star on no match", function()
		local st, en = M.find("bcd", "a*")
		assert(st == 1 and en == 0)
	end)

	----------------------------------------------------------------------
	-- find: anchors
	----------------------------------------------------------------------
	test("find anchor start", function()
		local st, en = M.find("hello", "^hel")
		assert(st == 1 and en == 3)
	end)

	test("find anchor start no match", function()
		local st, en = M.find("hello", "^ell")
		assert(st == nil)
	end)

	test("find anchor end", function()
		local st, en = M.find("hello", "llo$")
		assert(st == 3 and en == 5)
	end)

	test("find anchor end no match", function()
		local st, en = M.find("hello", "ell$")
		assert(st == nil)
	end)

	test("find anchor both", function()
		local st, en = M.find("hello", "^hello$")
		assert(st == 1 and en == 5)
	end)

	test("find anchor both no match", function()
		local st, en = M.find("hello world", "^hello$")
		assert(st == nil)
	end)

	----------------------------------------------------------------------
	-- find: captures
	----------------------------------------------------------------------
	test("find single capture", function()
		local st, en, cap1 = M.find("hello123world", "(%d+)")
		assert(st == 6 and en == 8)
		assert(cap1 == "123")
	end)

	test("find multiple captures", function()
		local st, en, c1, c2 = M.find("John:30 Jane:25", "(%a+):(%d+)")
		assert(st == 1 and en == 7)
		assert(c1 == "John")
		assert(c2 == "30")
	end)

	test("find capture with surrounding text", function()
		local st, en, c1 = M.find("abc123def", "(%d+)")
		assert(st == 4 and en == 6)
		assert(c1 == "123")
	end)

	test("find position capture", function()
		local st, en, pos = M.find("abc123def", "()%d+")
		assert(st == 4 and en == 6)
		assert(pos == 4)
	end)

	test("find capture returning empty string", function()
		local st, en, c1 = M.find("abc", "()b()")
		assert(st == 2 and en == 2)
		assert(c1 == 2)
	end)

	test("find no captures returns no extra values", function()
		local result = { M.find("hello", "ell") }
		assert(#result == 2)
		assert(result[1] == 2 and result[2] == 4)
	end)

	----------------------------------------------------------------------
	-- find: backreferences
	----------------------------------------------------------------------
	test("find backreference", function()
		local st, en, c1 = M.find("abc abc", "(%a+)%s+%1")
		assert(st == 1 and en == 7)
		assert(c1 == "abc")
	end)

	test("find backreference no match", function()
		local st, en = M.find("abc xyz", "(%a+)%s+%1")
		assert(st == nil)
	end)

	----------------------------------------------------------------------
	-- find: balanced matches (%b)
	----------------------------------------------------------------------
	test("find balanced match", function()
		local st, en = M.find("a(b(c)d)e", "%b()")
		assert(st == 2 and en == 8)
	end)

	test("find balanced match nested", function()
		local st, en = M.find("a(b(c))d", "%b()")
		assert(st == 2 and en == 7)
	end)

	----------------------------------------------------------------------
	-- find: frontier patterns (%f)
	----------------------------------------------------------------------
	test("find frontier pattern", function()
		local st, en = M.find(" hello ", "%f[%w]hel")
		assert(st == 2 and en == 4)
	end)

	----------------------------------------------------------------------
	-- match: basic
	----------------------------------------------------------------------
	test("match returns full match", function()
		local result = M.match("hello123world", "%d+")
		assert(result == "123")
	end)

	test("match returns captures", function()
		local c1, c2 = M.match("John:30 Jane:25", "(%a+):(%d+)")
		assert(c1 == "John")
		assert(c2 == "30")
	end)

	test("match no captures returns substring", function()
		local result = M.match("hello world", "world")
		assert(result == "world")
	end)

	test("match no match returns nil", function()
		local result = M.match("hello", "xyz")
		assert(result == nil)
	end)

	test("match with init", function()
		local result = M.match("abcabc", "abc", 4)
		assert(result == "abc")
	end)

	test("match anchored at start", function()
		local result = M.match("hello", "^hello")
		assert(result == "hello")
	end)

	test("match anchored at start no match", function()
		local result = M.match("world", "^hello")
		assert(result == nil)
	end)

	----------------------------------------------------------------------
	-- gmatch: basic
	----------------------------------------------------------------------
	test("gmatch iterates all matches", function()
		local results = {}
		for m in M.gmatch("one two three", "%a+") do
			results[#results + 1] = m
		end
		assert(#results == 3)
		assert(results[1] == "one")
		assert(results[2] == "two")
		assert(results[3] == "three")
	end)

	test("gmatch with captures", function()
		local results = {}
		for c1, c2 in M.gmatch("a1b2c3", "(%a)(%d)") do
			results[#results + 1] = c1 .. c2
		end
		assert(#results == 3)
		assert(results[1] == "a1")
		assert(results[2] == "b2")
		assert(results[3] == "c3")
	end)

	test("gmatch no matches", function()
		local count = 0
		for m in M.gmatch("12345", "%a+") do
			count = count + 1
		end
		assert(count == 0)
	end)

	test("gmatch empty string", function()
		local count = 0
		for m in M.gmatch("", ".") do
			count = count + 1
		end
		assert(count == 0)
	end)

	test("gmatch anchored pattern yields one match", function()
		local count = 0
		for m in M.gmatch("abcabc", "^abc") do
			count = count + 1
		end
		assert(count == 1)
	end)

	----------------------------------------------------------------------
	-- gsub: basic
	----------------------------------------------------------------------
	test("gsub replaces all occurrences", function()
		local result, count = M.gsub("aabaabaa", "a", "x")
		assert(result == "xxbxxbxx")
		assert(count == 6)
	end)

	test("gsub with limit", function()
		local result, count = M.gsub("aabaabaa", "a", "x", 2)
		assert(result == "xxbaabaa")
		assert(count == 2)
	end)

	test("gsub with zero limit", function()
		local result, count = M.gsub("aaa", "a", "b", 0)
		assert(result == "aaa")
		assert(count == 0)
	end)

	test("gsub with no matches", function()
		local result, count = M.gsub("hello", "xyz", "abc")
		assert(result == "hello")
		assert(count == 0)
	end)

	test("gsub with capture in replacement", function()
		local result = M.gsub("hello world", "(%a+)", "[%1]")
		assert(result == "[hello] [world]")
	end)

	test("gsub with %%0 in replacement", function()
		local result = M.gsub("abc", "(%a+)", "[%0]")
		assert(result == "[abc]")
	end)

	test("gsub with %% literal", function()
		local result = M.gsub("abc", "a", "%%")
		assert(result == "%bc")
	end)

	test("gsub with function replacement", function()
		local result = M.gsub("abc", "%a", function(c)
			return c:upper()
		end)
		assert(result == "ABC")
	end)

	test("gsub with table replacement", function()
		local t = { a = "X", b = "Y", c = "Z" }
		local result = M.gsub("abc", "%a", t)
		assert(result == "XYZ")
	end)

	test("gsub with table replacement using first capture", function()
		local t = { one = "1", two = "2" }
		local result = M.gsub("one two one", "(%a+)", t)
		assert(result == "1 2 1")
	end)

	----------------------------------------------------------------------
	-- Error handling
	----------------------------------------------------------------------
	test("error on malformed pattern (ends with %)", function()
		expect_error(function()
			M.find("abc", "%")
		end, "malformed pattern")
	end)

	test("error on unfinished capture", function()
		expect_error(function()
			M.find("abc", "(abc")
		end, "unfinished capture")
	end)

	test("error on invalid capture index %0", function()
		expect_error(function()
			M.find("abc", "%0")
		end, "invalid capture index")
	end)

	test("error on invalid capture paren", function()
		expect_error(function()
			M.find("abc", "a)b")
		end, "invalid pattern capture")
	end)

	test("error on missing ] in set", function()
		expect_error(function()
			M.find("abc", "[abc")
		end, "malformed pattern")
	end)

	test("error on range out of order", function()
		expect_error(function()
			M.find("abc", "[z-a]")
		end, "range out of order")
	end)

	test("error on missing [ after %f", function()
		expect_error(function()
			M.find("abc", "%fa")
		end, "missing")
	end)

	test("error on missing arguments to %b", function()
		expect_error(function()
			M.find("abc", "%b")
		end, "missing arguments")
	end)

	----------------------------------------------------------------------
	-- Edge cases
	----------------------------------------------------------------------
	test("find in empty string", function()
		local st, en = M.find("", "a")
		assert(st == nil)
	end)

	test("match in empty string", function()
		local result = M.match("", "")
		assert(result == "")
	end)

	test("gsub on empty string", function()
		local result = M.gsub("", "a", "b")
		assert(result == "")
	end)

	test("find multiple quantifiers", function()
		local st, en = M.find("aaaa", "a+a+")
		assert(st == 1 and en == 4)
	end)

	test("find lazy quantifier stops early", function()
		local st, en, c1 = M.find("aababc", "a.-b")
		assert(st == 1 and en == 3)
		assert(c1 == nil)
	end)

	test("find greedy quantifier goes long", function()
		local st, en = M.find("aababc", "a.*b")
		assert(st == 1 and en == 5)
	end)

	test("find nested captures", function()
		local st, en, c1, c2 = M.find("abc123def", "((%a+)(%d+))")
		assert(st == 1 and en == 6)
		assert(c1 == "abc123")
		assert(c2 == "abc")
		assert(c1 ~= nil)
	end)

	test("find capture with quantifier", function()
		local st, en, c1 = M.find("aaa123", "(%a+)")
		assert(st == 1 and en == 3)
		assert(c1 == "aaa")
	end)

	test("gsub with captures in pattern", function()
		local result = M.gsub("hello world", "(%a+)(%s+)(%a+)", "%3%2%1")
		assert(result == "world hello")
	end)

	test("gsub function receives captures", function()
		local result = M.gsub("a1 b2 c3", "(%a)(%d)", function(a, b)
			return b .. a
		end)
		assert(result == "1a 2b 3c")
	end)

	test("find balanced match with nested", function()
		local st, en = M.find("a(b(c)d)e", "%b()")
		assert(st == 2 and en == 8)
	end)

	test("match with complex pattern", function()
		local c1, c2 = M.match("Date: 2024-01-15", "(%d+)-(%d+)-(%d+)")
		assert(c1 == "2024")
		assert(c2 == "01")
	end)

	print(string_format("[pattern] %d/%d tests passed (%d failed)", passed, total, failed))
	assert(failed == 0, string_format("%d test(s) failed", failed))
end
--]=]

-- Export
return M
