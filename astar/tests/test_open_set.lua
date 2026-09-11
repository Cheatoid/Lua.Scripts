-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- unit tests for the binary min-heap

return function(T)
	local AStar, OpenSet, util = T.AStar, T.OpenSet, T.util
	local test, eq, ok, near = T.test, T.eq, T.ok, T.near

	test("open set: pop returns nil on empty", function()
		local os = OpenSet.new()
		eq(os:pop(), nil)
		eq(os.n, 0)
	end)

	test("open set: push/pop ordering is lexicographic (f, h, seq)", function()
		local os = OpenSet.new()
		local rng = util.lcg(12345)
		local entries = {}
		for i = 1, 500 do
			local f = math.floor(rng() * 50)
			local h = math.floor(rng() * 50)
			entries[i] = { f = f, h = h, seq = i, node = i }
		end
		-- shuffle deterministically
		for i = #entries, 2, -1 do
			local j = math.floor(rng() * i) + 1
			entries[i], entries[j] = entries[j], entries[i]
		end
		for _, e in ipairs(entries) do
			os:push(e.node, e.f, e.h, e.seq)
		end
		eq(os.n, 500)
		table.sort(entries, function(a, b)
			if a.f ~= b.f then return a.f < b.f end
			if a.h ~= b.h then return a.h < b.h end
			return a.seq < b.seq
		end)
		for i, e in ipairs(entries) do
			eq(os:pop(), e.node, "pop order at " .. i)
		end
		eq(os:pop(), nil)
	end)

	test("open set: duplicate pushes pop in score order", function()
		local os = OpenSet.new()
		os:push("a", 5, 1, 1)
		os:push("b", 3, 1, 2)
		os:push("c", 3, 0, 3)
		os:push("d", 5, 0, 4)
		eq(os:pop(), "c")
		eq(os:pop(), "b")
		eq(os:pop(), "d") -- (5,0) < (5,1)
		eq(os:pop(), "a")
	end)

	test("open set: equal scores pop in insertion (seq) order", function()
		local os = OpenSet.new()
		for i = 1, 10 do
			os:push(i, 7, 7, i)
		end
		for i = 1, 10 do
			eq(os:pop(), i)
		end
	end)

	test("open set: peek does not remove", function()
		local os = OpenSet.new()
		os:push("x", 1, 2, 3)
		local node, f, h, seq = os:peek()
		eq(node, "x")
		eq(f, 1)
		eq(h, 2)
		eq(seq, 3)
		eq(os.n, 1)
		eq(os:pop(), "x")
		eq(os:pop(), nil)
	end)

	test("open set: interleaved push/pop always pops the live minimum", function()
		-- NOTE: with interleaved pushes, the pop sequence is NOT globally
		-- non-decreasing (a smaller key may be inserted after a larger pop).
		-- The correct invariant: every pop returns the minimum of the
		-- currently live entries.
		local os = OpenSet.new()
		local rng = util.lcg(777)
		local live = {}
		local seq = 0
		local function min_of(live)
			local best_node, best_e
			for node, e in pairs(live) do
				if not best_e
				or e.f < best_e.f
				or (e.f == best_e.f and e.h < best_e.h)
				or (e.f == best_e.f and e.h == best_e.h and e.seq < best_e.seq) then
					best_node, best_e = node, e
				end
			end
			return best_node, best_e
		end
		for i = 1, 1000 do
			if os.n > 0 and rng() < 0.5 then
				local node = os:pop()
				local e = live[node]
				ok(e, "popped a live entry")
				local min_node = min_of(live)
				eq(node, min_node, "pop must return the live minimum")
				live[node] = nil
			else
				seq = seq + 1
				local e = { f = math.floor(rng() * 20), h = math.floor(rng() * 20), seq = seq }
				live["n" .. seq] = e
				os:push("n" .. seq, e.f, e.h, e.seq)
			end
		end
	end)

	test("open set: reset empties, free clears references", function()
		local os = OpenSet.new()
		for i = 1, 20 do
			os:push(i, i, i, i)
		end
		os:reset()
		eq(os.n, 0)
		eq(os:pop(), nil)
		for i = 1, 20 do
			os:push(i, i, i, i)
		end
		eq(os.n, 20)
		os:free()
		eq(os.n, 0)
		eq(os.high, 0)
		for i = 1, 20 do
			eq(os.node[i], nil, "slot cleared")
		end
	end)
end
