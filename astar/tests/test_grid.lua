-- Grid2D / Grid3D adapter tests

return function(T)
	local AStar, util = T.AStar, T.util
	local test, eq, ok, near = T.test, T.eq, T.ok, T.near

	local SQRT2 = math.sqrt(2)

	test("grid2d: id/coords roundtrip", function()
		local g = AStar.Grid2D.new({ width = 7, height = 5 })
		eq(g:id(1, 1), 1)
		eq(g:id(7, 1), 7)
		eq(g:id(1, 2), 8)
		eq(g:id(7, 5), 35)
		for id = 1, 35 do
			local x, y = g:coords(id)
			eq(g:id(x, y), id, "roundtrip " .. id)
		end
		ok(g:in_bounds(1, 1))
		ok(not g:in_bounds(0, 1))
		ok(not g:in_bounds(8, 1))
		ok(not g:in_bounds(1, 6))
	end)

	test("grid2d: 4-conn open grid corner-to-corner optimal", function()
		local w, h = 16, 16
		local g = AStar.Grid2D.new({ width = w, height = h })
		local pf = AStar.new(g)
		local p, info = pf:find(1, w * h)
		ok(info.found)
		near(info.path_cost, (w - 1) + (h - 1), 1e-9)
		eq(#p, (w - 1) + (h - 1) + 1)
		eq(p[1], 1)
		eq(p[#p], w * h)
		ok(g:validate_path(p))
	end)

	test("grid2d: 8-conn open grid corner-to-corner optimal", function()
		local w, h = 10, 10
		local g = AStar.Grid2D.new({ width = w, height = h, diagonal = true })
		local pf = AStar.new(g)
		local p, info = pf:find(1, w * h)
		ok(info.found)
		near(info.path_cost, 9 * SQRT2, 1e-9, "pure diagonal path")
		eq(#p, 10)
		ok(g:validate_path(p))
	end)

	test("grid2d: terrain cost steers around mud", function()
		-- 3x3, center cell cost 10. 4-conn corner->corner must avoid center.
		local g = AStar.Grid2D.new({ width = 3, height = 3 })
		g:set_terrain(2, 2, 10)
		local pf = AStar.new(g)
		local p, info = pf:find(g:id(1, 1), g:id(3, 3))
		ok(info.found)
		near(info.path_cost, 4, 1e-9)
		for i = 1, #p do
			ok(p[i] ~= g:id(2, 2), "center avoided")
		end
		-- 8-conn variant: cheapest avoiding path is 2 orth + 1 diag
		local g8 = AStar.Grid2D.new({ width = 3, height = 3, diagonal = true })
		g8:set_terrain(2, 2, 10)
		local pf8 = AStar.new(g8)
		local p8, info8 = pf8:find(g8:id(1, 1), g8:id(3, 3))
		ok(info8.found)
		near(info8.path_cost, 2 + SQRT2, 1e-9)
		for i = 1, #p8 do
			ok(p8[i] ~= g8:id(2, 2), "center avoided")
		end
	end)

	test("grid2d: terrain <= 0 blocks the cell", function()
		local g = AStar.Grid2D.new({ width = 3, height = 3 })
		-- wall the entire middle column via terrain
		g:set_terrain(2, 1, 0)
		g:set_terrain(2, 2, -1)
		g:set_terrain(2, 3, 0)
		local pf = AStar.new(g)
		local p, info = pf:find(g:id(1, 1), g:id(3, 1))
		eq(info.found, false)
		eq(info.endpoint_blocked, nil) -- endpoints themselves are fine
	end)

	test("grid2d: corner cutting disabled forbids diagonal squeeze", function()
		local g = AStar.Grid2D.new({ width = 3, height = 3, diagonal = true })
		g:block(2, 1)
		g:block(1, 2)
		-- (1,1) -> (2,2) would cut both corners; must be unreachable because
		-- the only other exits of (1,1) are blocked.
		local pf = AStar.new(g)
		local p, info = pf:find(g:id(1, 1), g:id(2, 2))
		eq(info.found, false)
	end)

	test("grid2d: corner cutting allowed passes the squeeze", function()
		local g = AStar.Grid2D.new({ width = 3, height = 3, diagonal = true, allow_corner_cutting = true })
		g:block(2, 1)
		g:block(1, 2)
		local pf = AStar.new(g)
		local p, info = pf:find(g:id(1, 1), g:id(2, 2))
		ok(info.found)
		near(info.path_cost, SQRT2, 1e-9)
	end)

	test("grid2d: no path enters blocked cells (random maps)", function()
		local rng = util.lcg(9001)
		for trial = 1, 5 do
			local w, h = 24, 24
			local g = AStar.Grid2D.new({
				width = w,
				height = h,
				diagonal = true,
				blocked = util.random_blocked(w, h, rng, 0.3),
			})
			local pf = AStar.new(g)
			local p, info = pf:find(1, w * h)
			if info.found then
				ok(g:validate_path(p), "invalid path on trial " .. trial)
			end
		end
	end)

	test("grid2d: unblocked mutation after construction is visible", function()
		local g = AStar.Grid2D.new({ width = 5, height = 5 })
		-- wall the full middle column
		for y = 1, 5 do g:block(3, y) end
		local pf = AStar.new(g)
		local p1, i1 = pf:find(g:id(1, 3), g:id(5, 3))
		eq(i1.found, false, "full column wall")
		g:unblock(3, 3)
		local p2, i2 = pf:find(g:id(1, 3), g:id(5, 3))
		ok(i2.found, "gap opened")
		near(i2.path_cost, 4, 1e-9)
	end)

	test("grid2d: long serpentine path (no recursion in reconstruction)", function()
		local w, h = 40, 40
		local g = AStar.Grid2D.new({ width = w, height = h, blocked = util.serpentine_blocked(w, h) })
		local pf = AStar.new(g)
		-- the last row's connector is on the left edge (x = 1)
		local goal = g:id(1, h)
		local p, info = pf:find(1, goal)
		ok(info.found, "serpentine must be solvable")
		-- the corridor is unique and visits every PASSABLE cell:
		-- ceil(h/2) full rows + floor(h/2) connector cells
		local expected = math.ceil(h / 2) * w + math.floor(h / 2)
		eq(#p, expected, "path visits every passable cell")
		near(info.path_cost, expected - 1, 1e-9)
		ok(info.expanded > 500, "search had to work for it")
	end)

	test("grid2d: custom heuristic override", function()
		local w, h = 8, 8
		local g = AStar.Grid2D.new({ width = w, height = h })
		local pf = AStar.new({
			neighbors_buffer = g.neighbors_buffer,
			walkable = g.walkable,
			heuristic = require("../heuristics").zero,
		})
		local p, info = pf:find(1, w * h)
		near(info.path_cost, (w - 1) + (h - 1), 1e-9)
		ok(info.expanded > 20, "zero heuristic expands much more than manhattan would")
	end)

	test("grid3d: id/coords roundtrip", function()
		local g = AStar.Grid3D.new({ width = 4, height = 3, depth = 2 })
		eq(g:id(1, 1, 1), 1)
		eq(g:id(4, 1, 1), 4)
		eq(g:id(1, 2, 1), 5)
		eq(g:id(1, 1, 2), 13)
		eq(g:id(4, 3, 2), 24)
		for id = 1, 24 do
			local x, y, z = g:coords(id)
			eq(g:id(x, y, z), id, "roundtrip " .. id)
		end
	end)

	test("grid3d: 6-conn straight line", function()
		local g = AStar.Grid3D.new({ width = 5, height = 5, depth = 5 })
		local pf = AStar.new(g)
		local p, info = pf:find(g:id(1, 1, 1), g:id(5, 1, 1))
		ok(info.found)
		near(info.path_cost, 4, 1e-9)
		eq(#p, 5)
	end)

	test("grid3d: 6-conn manhattan detour around blocked pillar", function()
		local g = AStar.Grid3D.new({ width = 5, height = 5, depth = 5 })
		g:block(3, 1, 1)
		g:block(3, 2, 1)
		local pf = AStar.new(g)
		local p, info = pf:find(g:id(1, 1, 1), g:id(5, 1, 1))
		ok(info.found)
		-- must detour: shortest 4-conn path avoids the two blocked cells
		local manhattan = 4
		ok(info.path_cost >= manhattan, "cost >= manhattan")
		for i = 1, #p do
			local x, y, z = g:coords(p[i])
			ok(not ((x == 3 and y == 1 and z == 1) or (x == 3 and y == 2 and z == 1)), "pillar avoided")
		end
		-- cross-check optimality with dijkstra
		local pf2 = AStar.new({ neighbors_buffer = g.neighbors_buffer, walkable = g.walkable, mode = "dijkstra" })
		local _, info2 = pf2:find(g:id(1, 1, 1), g:id(5, 1, 1))
		near(info.path_cost, info2.path_cost, 1e-9)
	end)

	test("grid3d: 26-conn space diagonal costs sqrt(3)", function()
		local g = AStar.Grid3D.new({ width = 4, height = 4, depth = 4, diagonal = true })
		local pf = AStar.new(g)
		local p, info = pf:find(g:id(1, 1, 1), g:id(4, 4, 4))
		ok(info.found)
		near(info.path_cost, 3 * math.sqrt(3), 1e-9)
		eq(#p, 4)
	end)

	test("grid3d: blocked layer forces detour (6-conn)", function()
		local g = AStar.Grid3D.new({ width = 4, height = 4, depth = 3 })
		-- wall the entire z=2 layer except one doorway
		for y = 1, 4 do
			for x = 1, 4 do
				if not (x == 2 and y == 2) then
					g:block(x, y, 2)
				end
			end
		end
		local pf = AStar.new(g)
		local p, info = pf:find(g:id(1, 1, 1), g:id(1, 1, 3))
		ok(info.found)
		near(info.path_cost, 6, 1e-9) -- 1->2 (xy), 2 layers of z, back
		for i = 1, #p do
			local x, y, z = g:coords(p[i])
			if z == 2 then
				eq(x, 2); eq(y, 2)
			end
		end
	end)

	test("grid3d: heuristic admissible + consistent spot checks", function()
		local g6 = AStar.Grid3D.new({ width = 5, height = 5, depth = 5 })
		local h6 = g6.heuristic
		-- consistency over every 6-conn edge: h(u) <= 1 + h(v)
		for id = 1, 125 do
			local nb, cb = {}, {}
			local n = g6.neighbors_buffer(id, nb, cb)
			for i = 1, n do
				local hu = h6(id, 125)
				local hv = h6(nb[i], 125)
				ok(hu <= cb[i] + hv + 1e-9, "consistency violated " .. id .. "->" .. nb[i])
			end
		end
		local g26 = AStar.Grid3D.new({ width = 5, height = 5, depth = 5, diagonal = true })
		local h26 = g26.heuristic
		for id = 1, 125 do
			local nb, cb = {}, {}
			local n = g26.neighbors_buffer(id, nb, cb)
			for i = 1, n do
				local hu = h26(id, 125)
				local hv = h26(nb[i], 125)
				ok(hu <= cb[i] + hv + 1e-9, "26-conn consistency violated " .. id .. "->" .. nb[i])
			end
		end
	end)
end
