-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Binary min-heap priority queue for the A* open set.
--
-- Design notes (LuaJIT-specific):
--
--   * Four PARALLEL integer-indexed arrays (node, f, h, seq) instead of one
--     array of entry tables. This avoids one table allocation per push and
--     keeps every slot in the array part of each table, which LuaJIT traces
--     into cheap loads/stores.
--
--   * LAZY DELETION instead of decrease-key: when a node's score improves we
--     simply push a new entry and let the old one become stale. The search
--     core detects stale entries on pop via its node-state stamps, which is
--     cheaper than maintaining heap positions per node (decrease-key needs an
--     extra position table plus sift-up/sift-down on every improvement; with
--     admissible heuristics, duplicate pushes are rare, so lazy deletion wins
--     in practice and the code is much harder to get wrong).
--
--   * Deterministic ordering: entries compare lexicographically by
--     (f, h, seq) where `seq` is a monotonically increasing insertion
--     counter. Equal-score entries therefore pop in insertion order, which
--     makes the whole search deterministic given a deterministic graph.
--
--   * No bit operators, no goto, no integer division: Lua 5.1 / LuaJIT
--     compatible source.

-- Localized global functions for better performance
local setmetatable = setmetatable
local math_floor = math.floor

--- Open set backed by a binary min-heap with lazy deletion.<br>
--- Uses four parallel arrays (node, f, h, seq) instead of per-entry tables to avoid allocations per push.<br>
--- Stale entries are discarded on pop; new better entries simply get pushed (lazy deletion).
---@class astar.OpenSet
---@field n integer Number of live heap entries.
---@field high integer High-water mark of n (used by free() to clear slots).
---@field node table node id at heap slot i
---@field f table f-score at heap slot i (at push time)
---@field h table h-score at heap slot i (at push time)
---@field seq table insertion sequence at heap slot i (tie-breaker)
local OpenSet = {}
OpenSet.__index = OpenSet

--- Create a new empty OpenSet.<br>
--- Initialises the heap arrays and counters.
---@return astar.OpenSet os Fresh OpenSet instance.
---@usage <br>
--- ```
--- local os = OpenSet.new()
--- os:push(node, f, h, seq)
--- local node, f, h, seq = os:pop()
--- ```
function OpenSet.new()
	return setmetatable({
		n = 0, -- number of live entries; slots 1..n are the heap
		high = 0, -- high-water mark of n (used by free() to clear slots)
		node = {}, -- node id at heap slot i
		f = {}, -- f-score at heap slot i (at push time)
		h = {}, -- h-score at heap slot i (at push time)
		seq = {}, -- insertion sequence at heap slot i (tie-breaker)
	}, OpenSet)
end

-- Compare (f1,h1,s1) < (f2,h2,s2) lexicographically. Inlined manually at the
-- two hot call sites below to avoid function-call overhead in sift loops.
-- local function less(f1,h1,s1,f2,h2,s2)
--     if f1 ~= f2 then return f1 < f2 end
--     if h1 ~= h2 then return h1 < h2 end
--     return s1 < s2
-- end

--- Push a new entry (node, f, h, seq) into the heap.<br>
--- Sifts the entry up using the "hole" technique to minimise stores.<br>
--- Duplicate entries for the same node are allowed (lazy deletion); stale entries are discarded on pop.
---@param self astar.OpenSet The OpenSet instance.
---@param node any Node identifier.
---@param f number f-score at push time.
---@param h number h-score at push time.
---@param seq number Insertion sequence (tie-breaker).
function OpenSet.push(self, node, f, h, seq)
	local n = self.n + 1
	self.n = n
	if n > self.high then self.high = n end

	local nodes, fs, hs, seqs = self.node, self.f, self.h, self.seq
	nodes[n] = node
	fs[n] = f
	hs[n] = h
	seqs[n] = seq

	-- Sift up using the "hole" technique: the new entry lives in registers
	-- while parents shift down; 4 stores per level instead of 8.
	while n > 1 do
		local p = math_floor(n * 0.5) -- parent index (no // operator: Lua 5.1)
		local pf = fs[p]
		if f < pf or (f == pf and (h < hs[p] or (h == hs[p] and seq < seqs[p]))) then
			nodes[n] = nodes[p]
			fs[n] = pf
			hs[n] = hs[p]
			seqs[n] = seqs[p]
			n = p
		else
			break
		end
	end
	nodes[n] = node
	fs[n] = f
	hs[n] = h
	seqs[n] = seq
end

--- Remove and return the minimum node (or nil when empty).<br>
--- Stale heap entries are detected and discarded via the search's generation stamps.<br>
--- Does not touch the underlying arrays beyond the popped slot.
---@param self astar.OpenSet The OpenSet instance.
---@return any? node The minimum node, or nil if the heap is empty.
---@usage <br>
--- ```
--- local node = os:pop()
--- ```
function OpenSet.pop(self)
	local n = self.n
	if n == 0 then
		return nil
	end

	local nodes, fs, hs, seqs = self.node, self.f, self.h, self.seq
	local top = nodes[1]

	if n == 1 then
		self.n = 0
		nodes[1] = nil
		fs[1] = nil
		hs[1] = nil
		seqs[1] = nil
		return top
	end

	-- Take the last element to re-insert, then sift the hole down.
	local last_node, last_f, last_h, last_seq = nodes[n], fs[n], hs[n], seqs[n]
	nodes[n] = nil
	fs[n] = nil
	hs[n] = nil
	seqs[n] = nil
	self.n = n - 1

	local size = n - 1
	local i = 1
	while true do
		local c = i + i -- left child
		if c > size then break end
		local cf = fs[c]
		local rc = c + 1
		if rc <= size then
			-- pick the smaller child (full tuple compare keeps this deterministic)
			local rf = fs[rc]
			if rf < cf or (rf == cf and (hs[rc] < hs[c] or (hs[rc] == hs[c] and seqs[rc] < seqs[c]))) then
				c = rc
				cf = rf
			end
		end
		if last_f < cf or (last_f == cf and (last_h < hs[c] or (last_h == hs[c] and last_seq < seqs[c]))) then
			break
		end
		nodes[i] = nodes[c]
		fs[i] = cf
		hs[i] = hs[c]
		seqs[i] = seqs[c]
		i = c
	end
	nodes[i] = last_node
	fs[i] = last_f
	hs[i] = last_h
	seqs[i] = last_seq

	return top
end

--- Return the minimum node without removing it.<br>
--- Returns the f, h, and seq values alongside the node for convenience.
---@param self astar.OpenSet The OpenSet instance.
---@return any? node The minimum node, or nil if empty.
---@return number? f f-score at heap slot 1.
---@return number? h h-score at heap slot 1.
---@return number? seq Insertion sequence at heap slot 1.
function OpenSet.peek(self)
	if self.n == 0 then
		return nil
	end
	return self.node[1], self.f[1], self.h[1], self.seq[1]
end

--- Cheap reset: the heap logically empties (n = 0).<br>
--- Slots keep references until overwritten; bounded by the previous high-water mark.<br>
--- Use free() when you actually want the memory back.
---@param self astar.OpenSet The OpenSet instance.
function OpenSet.reset(self)
	self.n = 0
end

--- Full reset: clears all slots so stale node references can be collected.<br>
--- O(high-water mark); intended for search:free(), not per-search use.
---@param self astar.OpenSet The OpenSet instance.
function OpenSet.free(self)
	local n = self.high
	local nodes, fs, hs, seqs = self.node, self.f, self.h, self.seq
	for i = 1, n do
		nodes[i] = nil
		fs[i] = nil
		hs[i] = nil
		seqs[i] = nil
	end
	self.n = 0
	self.high = 0
end

-- Export
return OpenSet
