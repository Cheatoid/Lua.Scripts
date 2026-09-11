-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- basic cases, lifecycle, error handling

return function(T)
	local AStar, util = T.AStar, T.util
	local test, eq, ok, near = T.test, T.eq, T.ok, T.near

	local function chain_cfg(edges, symmetric)
		local cfg = util.waypoint_graph and nil
		local g = require "../graph"
		return (g.from_edges(edges, symmetric))
	end

	test("basic: start == goal returns trivial path", function()
		local pf = AStar.new(chain_cfg({ { 1, 2, 1 }, { 2, 3, 1 } }, true))
		local path, info = pf:find(2, 2)
		ok(path, "path expected")
		eq(#path, 1)
		eq(path[1], 2)
		eq(info.found, true)
		eq(info.path_cost, 0)
		eq(info.expanded, 0)
		eq(info.discovered, 0)
		eq(info.iterations, 0)
	end)

	test("basic: direct path along a chain", function()
		local pf = AStar.new(chain_cfg({ { 1, 2, 1 }, { 2, 3, 1 }, { 3, 4, 1 } }, true))
		local path, info = pf:find(1, 4)
		ok(path)
		eq(#path, 4)
		eq(path[1], 1)
		eq(path[4], 4)
		eq(info.path_cost, 3)
		eq(info.found, true)
	end)

	test("basic: path is ordered start -> goal", function()
		local pf = AStar.new(chain_cfg({ { 1, 2, 1 }, { 2, 3, 1 }, { 3, 4, 1 } }, true))
		local path = pf:find(4, 1)
		eq(path[1], 4)
		eq(path[2], 3)
		eq(path[3], 2)
		eq(path[4], 1)
	end)

	test("basic: blocked path (missing edge) is unreachable", function()
		-- symmetric chain 1-2 only: node 3 exists in the config space but
		-- has no edges, so 1 -> 3 must be unreachable.
		local pf = AStar.new(chain_cfg({ { 1, 2, 1 } }, true))
		local path, info = pf:find(1, 3)
		eq(path, nil)
		eq(info.found, false)
		eq(info.budget_exhausted, nil)
		ok(info.expanded > 0)
	end)

	test("basic: disconnected components", function()
		local pf = AStar.new(chain_cfg({
			{ 1,  2,  1 }, { 2, 3, 1 }, -- component A
			{ 10, 11, 1 },     -- component B
		}, true))
		local path, info = pf:find(1, 11)
		eq(path, nil)
		eq(info.found, false)
	end)

	test("basic: single-node graph", function()
		local pf = AStar.new(require("../graph").from_adjacency({ [1] = {} }))
		local path = pf:find(1, 1)
		ok(path)
		eq(#path, 1)
		local path2, info2 = pf:find(1, 2)
		eq(path2, nil)
		eq(info2.found, false)
	end)

	test("basic: empty graph", function()
		local pf = AStar.new(require("../graph").from_adjacency({}))
		local path = pf:find(7, 7)
		ok(path)
		local path2 = pf:find(7, 8)
		eq(path2, nil)
	end)

	test("basic: nil start/goal raise errors", function()
		local pf = AStar.new(chain_cfg({ { 1, 2, 1 } }, true))
		local ok1, err1 = pcall(pf.find, pf, nil, 2)
		ok(not ok1, "nil start should error")
		local ok2, err2 = pcall(pf.find, pf, 1, nil)
		ok(not ok2, "nil goal should error")
		local s = pf:create_search()
		local ok3 = pcall(s.reset, s, nil, 2)
		ok(not ok3, "reset with nil start should error")
	end)

	test("basic: missing neighbor provider errors at construction", function()
		local ok1, err = pcall(AStar.new, { heuristic = function() return 0 end })
		ok(not ok1, "no provider should error")
		ok(tostring(err):find("neighbors_buffer", 1, true), "error mentions providers")
	end)

	test("basic: both providers error", function()
		local ok1 = pcall(AStar.new, {
			neighbors = function() end,
			neighbors_buffer = function() return 0 end,
		})
		ok(not ok1, "both providers should error")
	end)

	test("basic: invalid mode errors", function()
		local ok1 = pcall(AStar.new, { neighbors = function() end, mode = "bellman_ford" })
		ok(not ok1, "bad mode should error")
	end)

	test("basic: non-function config values error", function()
		local ok1 = pcall(AStar.new, { neighbors = function() end, heuristic = 42 })
		ok(not ok1, "non-function heuristic should error")
	end)

	test("basic: walkable blocked endpoints fail fast", function()
		local pf = AStar.new({
			neighbors_buffer = function(node, nbuf, cbuf) return 0 end,
			walkable = function(node) return node ~= 1 end,
		})
		local path, info = pf:find(1, 2)
		eq(path, nil)
		eq(info.found, false)
		eq(info.endpoint_blocked, "start")
		eq(info.expanded, 0)
		local path2, info2 = pf:find(2, 1)
		eq(info2.endpoint_blocked, "goal")
	end)

	test("basic: search status lifecycle", function()
		local pf = AStar.new(chain_cfg({ { 1, 2, 1 }, { 2, 3, 1 } }, true))
		local s = pf:create_search()
		eq(s.status, "idle")
		ok(s:finished(), "idle counts as finished (cannot be stepped)")
		s:reset(1, 3)
		eq(s.status, "running")
		ok(not s:finished())
		s:run()
		eq(s.status, "success")
		ok(s:finished())
		ok(s:done())
	end)

	test("basic: string-keyed nodes", function()
		local pf = AStar.new(chain_cfg({
			{ "home", "shop", 2 },
			{ "shop", "work", 3 },
		}, false))
		local path, info = pf:find("home", "work")
		ok(path)
		eq(#path, 3)
		eq(path[1], "home")
		eq(path[3], "work")
		eq(info.path_cost, 5)
	end)

	test("basic: table-identity-keyed nodes", function()
		local a, b, c = { name = "a" }, { name = "b" }, { name = "c" }
		local pf = AStar.new(chain_cfg({ { a, b, 1 }, { b, c, 1 } }, false))
		local path = pf:find(a, c)
		ok(path)
		eq(path[1], a)
		eq(path[2], b)
		eq(path[3], c)
	end)

	test("basic: path output buffer reuse", function()
		local pf = AStar.new(chain_cfg({ { 1, 2, 1 }, { 2, 3, 1 }, { 3, 4, 1 } }, false))
		local buf = { "stale", "junk", "data", 5, 6, 7 }
		local s = pf:start(1, 4)
		s:run()
		local p2 = s:path(buf)
		eq(#p2, 4)
		eq(p2[1], 1)
		eq(p2[4], 4)
		eq(p2[5], nil, "stale tail trimmed")
		eq(#buf, 4, "#buffer correct after reuse")

		-- shorter path into the same buffer trims again
		local s2 = pf:create_search()
		s2:reset(1, 2)
		s2:run()
		local p3 = s2:path(p2)
		eq(#p3, 2)
		eq(#buf, 2)
	end)
end
