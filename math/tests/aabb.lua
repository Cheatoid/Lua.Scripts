-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for aabb.lua.
-- Run from this directory:
--   lua aabb.lua
--   luajit aabb.lua

-- Bootstrap: shared test bootstrap (see ../../.tools/bootstrap.lua).
do
	local src = debug.getinfo(1, "S").source
	local dir = src:match("^@(.+/)[^/]+$") or "./"
	local function isfile(p)
		local f = io.open(p, "r")
		if f then
			f:close()
			return true
		end
		return false
	end
	local boot
	for _, c in ipairs({
		dir .. "../../.tools/bootstrap.lua",
		dir .. "../.tools/bootstrap.lua",
		dir .. "../../../.tools/bootstrap.lua",
		"./.tools/bootstrap.lua",
		"../.tools/bootstrap.lua",
		"../../.tools/bootstrap.lua",
	}) do
		if isfile(c) then
			boot = c
			break
		end
	end
	assert(boot, "cheatoid test bootstrap not found (.tools/bootstrap.lua)")
	assert(dofile(boot))(dir)
end
local AABB = require "aabb"

local pass_count = 0
local fail_count = 0

local function check(name, cond)
	if cond then
		pass_count = pass_count + 1
		print(string.format("[PASS] %s", name))
	else
		fail_count = fail_count + 1
		print(string.format("[FAIL] %s", name))
	end
end

local function near(a, b, eps)
	eps = eps or 1e-6
	return math.abs(a - b) <= eps
end

local function box_near(a, b, eps)
	eps = eps or 1e-6
	return math.abs(a.min.x - b.min.x) <= eps
		and math.abs(a.min.y - b.min.y) <= eps
		and math.abs(a.min.z - b.min.z) <= eps
		and math.abs(a.max.x - b.max.x) <= eps
		and math.abs(a.max.y - b.max.y) <= eps
		and math.abs(a.max.z - b.max.z) <= eps
end

print("=== AABB constructor tests ===")

do
	local d = AABB.new()
	check("new defaults min zero", d.min.x == 0 and d.min.y == 0 and d.min.z == 0)
	check("new defaults max zero", d.max.x == 0 and d.max.y == 0 and d.max.z == 0)
	check("new is aabb", AABB.is(d) == true)
	check("callable shorthand", box_near(AABB({ x = 1, y = 2, z = 3 }, { x = 4, y = 5, z = 6 }), AABB.new({ x = 1, y = 2, z = 3 }, { x = 4, y = 5, z = 6 })))
	check("new nil nil defaults", box_near(AABB.new(nil, nil), AABB.new({ x = 0, y = 0, z = 0 }, { x = 0, y = 0, z = 0 })))
	check("invalid min type defaults", (function()
		local b = AABB.new(123, { x = 1, y = 1, z = 1 })
		return b.min.x == 0 and b.max.x == 1
	end)())
	check("invalid max type defaults", (function()
		local b = AABB.new({ x = 1, y = 1, z = 1 }, "bad")
		return b.min.x == 0 and b.max.x == 1
	end)())
	check("both invalid default zero box", (function()
		local b = AABB.new(5, 6)
		return b.min.x == 0 and b.max.x == 0
	end)())
	check("indexed tables accepted", (function()
		local b = AABB.new({ 1, 2, 3 }, { 4, 5, 6 })
		return b.min.x == 1 and b.min.y == 2 and b.min.z == 3 and b.max.x == 4 and b.max.y == 5 and b.max.z == 6
	end)())
	check("mixed named and indexed", (function()
		local b = AABB.new({ x = 1, y = 2, z = 3 }, { 4, 5, 6 })
		return b.min.x == 1 and b.max.x == 4
	end)())
	check("string numbers coerced", (function()
		local b = AABB.new({ x = "1.5", y = "2", z = "3" }, { x = "4", y = "5", z = "6" })
		return near(b.min.x, 1.5) and near(b.max.x, 4)
	end)())
	check("bad strings become zero", (function()
		local b = AABB.new({ x = "abc" }, { x = "def" })
		return b.min.x == 0 and b.max.x == 0
	end)())
	check("missing components default zero", (function()
		local b = AABB.new({ x = 1 }, { y = 2 })
		return b.min.x == 0 and b.max.x == 1 and b.min.y == 0 and b.max.y == 2 and b.min.z == 0 and b.max.z == 0
	end)())
	check("empty tables default zero", (function()
		local b = AABB.new({}, {})
		return b.min.x == 0 and b.max.x == 0
	end)())
	check("min/max swap x", (function()
		local b = AABB.new({ x = 5, y = 0, z = 0 }, { x = 0, y = 1, z = 1 })
		return b.min.x == 0 and b.max.x == 5
	end)())
	check("min/max swap y", (function()
		local b = AABB.new({ x = 0, y = 9, z = 0 }, { x = 1, y = 2, z = 1 })
		return b.min.y == 2 and b.max.y == 9
	end)())
	check("min/max swap z", (function()
		local b = AABB.new({ x = 0, y = 0, z = 7 }, { x = 1, y = 1, z = -3 })
		return b.min.z == -3 and b.max.z == 7
	end)())
	check("full reverse swap", (function()
		local b = AABB.new({ x = 5, y = 5, z = 5 }, { x = 0, y = 0, z = 0 })
		return b.min.x == 0 and b.max.x == 5 and b.min.y == 0 and b.max.y == 5
	end)())
	check("negative values preserved", (function()
		local b = AABB.new({ x = -5, y = -4, z = -3 }, { x = -1, y = -2, z = -1 })
		return b.min.x == -5 and b.max.x == -1
	end)())
	check("large values preserved", (function()
		local b = AABB.new({ x = -1e9, y = -1e9, z = -1e9 }, { x = 1e9, y = 1e9, z = 1e9 })
		return b.min.x == -1e9 and b.max.x == 1e9
	end)())
	check("is rejects plain table", AABB.is({}) == false)
	check("is rejects nil", AABB.is(nil) == false)
	check("is rejects number", AABB.is(5) == false)
	check("is rejects vector-like", AABB.is({ x = 1, y = 2, z = 3 }) == false)
end

print("=== AABB metamethods ===")

do
	local base = AABB.new({ x = 0, y = 0, z = 0 }, { x = 1, y = 1, z = 1 })
	local moved = base + { x = 1, y = 2, z = 3 }
	check("__add named vector", moved.min.x == 1 and moved.min.y == 2 and moved.min.z == 3 and moved.max.x == 2 and moved.max.y == 3 and moved.max.z == 4)
	local moved2 = base + { 10, 20, 30 }
	check("__add indexed vector", moved2.min.x == 10 and moved2.min.y == 20 and moved2.min.z == 30)
	local moved3 = base + { x = 1 }
	check("__add partial vector defaults zero", moved3.min.x == 1 and moved3.min.y == 0 and moved3.max.y == 1)
	local moved4 = base + {}
	check("__add empty table no move", box_near(moved4, base))
	local back = moved - { x = 1, y = 2, z = 3 }
	check("__sub restores", box_near(back, base))
	local sub2 = base - { 1, 1, 1 }
	check("__sub indexed", sub2.min.x == -1 and sub2.max.x == 0)
	check("__sub empty no move", box_near(base - {}, base))
	local mt_add = getmetatable(base).__add
	local mt_sub = getmetatable(base).__sub
	local mt_eq = getmetatable(base).__eq
	check("__add errors on bad rhs", pcall(mt_add, base, nil) == false)
	check("__add errors on number rhs", pcall(mt_add, base, 5) == false)
	check("__add errors on bad lhs", pcall(mt_add, {}, { x = 1, y = 1, z = 1 }) == false)
	check("__sub errors on bad rhs", pcall(mt_sub, base, nil) == false)
	check("__sub errors on bad lhs", pcall(mt_sub, {}, { x = 1, y = 1, z = 1 }) == false)
	check("__add operator errors", pcall(function() return base + 5 end) == false)
	check("__sub operator errors", pcall(function() return base - nil end) == false)
	local c = AABB.new({ x = 0, y = 0, z = 0 }, { x = 1, y = 1, z = 1 })
	check("__eq true", base == c)
	check("__eq false on diff", (base == AABB.new({ x = 0, y = 0, z = 0 }, { x = 2, y = 2, z = 2 })) == false)
	check("__eq false vs plain", (base == {}) == false)
	check("__eq false vs nil", (base == nil) == false)
	check("__eq direct false on non-aabb", mt_eq(base, {}) == false)
	check("__eq direct false both non-aabb", mt_eq({}, {}) == false)
	local s = tostring(base)
	check("__tostring contains AABB", string.find(s, "AABB", 1, true) ~= nil)
	check("__tostring contains numbers", string.find(s, "0", 1, true) ~= nil and string.find(s, "1", 1, true) ~= nil)
	check("__tostring exact format", s == "AABB(min: (0, 0, 0), max: (1, 1, 1))")
	check("__tostring on large", string.find(tostring(AABB.new({ x = -5, y = 2.5, z = 0 }, { x = 1, y = 1, z = 1 })), "AABB", 1, true) ~= nil)
end

print("=== AABB clone and dims ===")

do
	local base = AABB.new({ x = 0, y = 0, z = 0 }, { x = 2, y = 3, z = 4 })
	local c = AABB.clone(base)
	check("clone equal", c == base)
	check("clone not rawequal", rawequal(c, base) == false)
	check("clone min separate table", rawequal(c.min, base.min) == false)
	check("clone values match", c.min.x == 0 and c.max.z == 4)
	check("clone errors on bad", pcall(AABB.clone, {}) == false)
	check("clone errors on nil", pcall(AABB.clone, nil) == false)
	check("width", AABB.width(base) == 2)
	check("height", AABB.height(base) == 3)
	check("depth", AABB.depth(base) == 4)
	check("width zero box", AABB.width(AABB.new()) == 0)
	check("width negative box after swap positive", AABB.width(AABB.new({ x = 5, y = 0, z = 0 }, { x = 0, y = 0, z = 0 })) == 5)
	check("width large", AABB.width(AABB.new({ x = -1e6, y = 0, z = 0 }, { x = 1e6, y = 0, z = 0 })) == 2e6)
	check("width errors", pcall(AABB.width, {}) == false)
	check("height errors", pcall(AABB.height, nil) == false)
	check("depth errors", pcall(AABB.depth, {}) == false)
	local sz = AABB.size(base)
	check("size xyz", sz.x == 2 and sz.y == 3 and sz.z == 4)
	check("size errors", pcall(AABB.size, {}) == false)
	local ctr = AABB.center(base)
	check("center", near(ctr.x, 1) and near(ctr.y, 1.5) and near(ctr.z, 2))
	local ctr2 = AABB.center(AABB.new({ x = -4, y = -4, z = -4 }, { x = 0, y = 0, z = 0 }))
	check("center negative", near(ctr2.x, -2) and near(ctr2.y, -2) and near(ctr2.z, -2))
	check("center zero box", (function()
		local c0 = AABB.center(AABB.new({ x = 5, y = 5, z = 5 }, { x = 5, y = 5, z = 5 }))
		return near(c0.x, 5) and near(c0.y, 5)
	end)())
	check("center errors", pcall(AABB.center, {}) == false)
	check("volume 24", near(AABB.volume(base), 24))
	check("volume zero", AABB.volume(AABB.new()) == 0)
	check("volume unit", AABB.volume(AABB.new({ x = 0, y = 0, z = 0 }, { x = 1, y = 1, z = 1 })) == 1)
	check("volume errors", pcall(AABB.volume, {}) == false)
	check("surface 52", near(AABB.surface_area(base), 52))
	check("surface unit 6", near(AABB.surface_area(AABB.new({ x = 0, y = 0, z = 0 }, { x = 1, y = 1, z = 1 })), 6))
	check("surface zero 0", AABB.surface_area(AABB.new()) == 0)
	check("surface errors", pcall(AABB.surface_area, nil) == false)
	check("method call via colon width", (function()
		local b = AABB.new({ x = 0, y = 0, z = 0 }, { x = 3, y = 3, z = 3 })
		return b:width() == 3
	end)())
end

print("=== AABB contains / intersects ===")

do
	local box = AABB.new({ x = 0, y = 0, z = 0 }, { x = 2, y = 2, z = 2 })
	check("contains_point inside", AABB.contains_point(box, { x = 1, y = 1, z = 1 }) == true)
	check("contains_point on min boundary", AABB.contains_point(box, { x = 0, y = 0, z = 0 }) == true)
	check("contains_point on max boundary", AABB.contains_point(box, { x = 2, y = 2, z = 2 }) == true)
	check("contains_point outside x", AABB.contains_point(box, { x = 3, y = 1, z = 1 }) == false)
	check("contains_point outside y low", AABB.contains_point(box, { x = 1, y = -1, z = 1 }) == false)
	check("contains_point outside z", AABB.contains_point(box, { x = 1, y = 1, z = 5 }) == false)
	check("contains_point indexed inside", AABB.contains_point(box, { 1, 1, 1 }) == true)
	check("contains_point indexed outside", AABB.contains_point(box, { 9, 9, 9 }) == false)
	check("contains_point non-table false", AABB.contains_point(box, 123) == false)
	check("contains_point nil false", AABB.contains_point(box, nil) == false)
	check("contains_point empty is origin", AABB.contains_point(box, {}) == true)
	check("contains_point empty outside", AABB.contains_point(AABB.new({ x = 5, y = 5, z = 5 }, { x = 6, y = 6, z = 6 }), {}) == false)
	check("contains_point errors on bad box", pcall(AABB.contains_point, {}, { x = 1, y = 1, z = 1 }) == false)
	local outer = AABB.new({ x = 0, y = 0, z = 0 }, { x = 10, y = 10, z = 10 })
	local inner = AABB.new({ x = 2, y = 2, z = 2 }, { x = 5, y = 5, z = 5 })
	check("contains true", AABB.contains(outer, inner) == true)
	check("contains reverse false", AABB.contains(inner, outer) == false)
	check("contains self true", AABB.contains(outer, outer) == true)
	check("contains touching edge true", AABB.contains(outer, AABB.new({ x = 0, y = 0, z = 0 }, { x = 10, y = 10, z = 10 })) == true)
	check("contains partial false", AABB.contains(outer, AABB.new({ x = 5, y = 5, z = 5 }, { x = 15, y = 15, z = 15 })) == false)
	check("contains errors one bad", pcall(AABB.contains, outer, {}) == false)
	check("contains errors both bad", pcall(AABB.contains, {}, {}) == false)
	check("contains errors nil", pcall(AABB.contains, nil, inner) == false)
	check("intersects overlap true", AABB.intersects(outer, inner) == true)
	check("intersects partial true", AABB.intersects(box, AABB.new({ x = 1, y = 1, z = 1 }, { x = 5, y = 5, z = 5 })) == true)
	check("intersects touching true", AABB.intersects(box, AABB.new({ x = 2, y = 0, z = 0 }, { x = 4, y = 2, z = 2 })) == true)
	check("intersects disjoint false", AABB.intersects(box, AABB.new({ x = 5, y = 5, z = 5 }, { x = 6, y = 6, z = 6 })) == false)
	check("intersects errors", pcall(AABB.intersects, box, {}) == false)
end

print("=== AABB expand / contract ===")

do
	local box = AABB.new({ x = 0, y = 0, z = 0 }, { x = 2, y = 2, z = 2 })
	local e = AABB.expand(box, 1)
	check("expand uniform", e.min.x == -1 and e.max.x == 3 and e.min.y == -1 and e.max.y == 3)
	check("expand zero same", box_near(AABB.expand(box, 0), box))
	check("expand nil same", box_near(AABB.expand(box, nil), box))
	check("expand string coerced", (function()
		local ee = AABB.expand(box, "2")
		return ee.min.x == -2 and ee.max.x == 4
	end)())
	check("expand bad string zero", box_near(AABB.expand(box, "abc"), box))
	check("expand negative shrinks", (function()
		local ee = AABB.expand(box, -0.5)
		return near(ee.min.x, 0.5) and near(ee.max.x, 1.5)
	end)())
	check("expand errors on bad box", pcall(AABB.expand, {}, 1) == false)
	local ex = AABB.expand_xyz(box, 1, 2, 3)
	check("expand_xyz", ex.min.x == -1 and ex.max.x == 3 and ex.min.y == -2 and ex.max.y == 4 and ex.min.z == -3 and ex.max.z == 5)
	check("expand_xyz zeros same", box_near(AABB.expand_xyz(box, 0, 0, 0), box))
	check("expand_xyz nils same", box_near(AABB.expand_xyz(box, nil, nil, nil), box))
	check("expand_xyz partial", (function()
		local ee = AABB.expand_xyz(box, 1, nil, 0)
		return ee.min.x == -1 and ee.min.y == 0 and ee.min.z == 0
	end)())
	check("expand_xyz errors", pcall(AABB.expand_xyz, {}, 1, 1, 1) == false)
	local c = AABB.contract(box, 0.5)
	check("contract", near(c.min.x, 0.5) and near(c.max.x, 1.5))
	check("contract zero same", box_near(AABB.contract(box, 0), box))
	check("contract nil same", box_near(AABB.contract(box, nil), box))
	check("contract equals expand negative", box_near(AABB.contract(box, 1), AABB.expand(box, -1)))
	check("contract errors", pcall(AABB.contract, {}, 1) == false)
	local cx = AABB.contract_xyz(box, 0.5, 0.5, 0.5)
	check("contract_xyz", near(cx.min.x, 0.5) and near(cx.max.x, 1.5))
	check("contract_xyz equals expand_xyz negative", box_near(AABB.contract_xyz(box, 1, 2, 3), AABB.expand_xyz(box, -1, -2, -3)))
	check("contract_xyz errors", pcall(AABB.contract_xyz, nil, 1, 1, 1) == false)
end

print("=== AABB union / intersection / corners / tables ===")

do
	local a = AABB.new({ x = 0, y = 0, z = 0 }, { x = 2, y = 2, z = 2 })
	local b = AABB.new({ x = 1, y = 1, z = 1 }, { x = 4, y = 4, z = 4 })
	local u = AABB.union(a, b)
	check("union min", u.min.x == 0 and u.min.y == 0 and u.min.z == 0)
	check("union max", u.max.x == 4 and u.max.y == 4 and u.max.z == 4)
	local u2 = AABB.union(a, AABB.new({ x = 5, y = 5, z = 5 }, { x = 6, y = 6, z = 6 }))
	check("union disjoint spans gap", u2.min.x == 0 and u2.max.x == 6)
	check("union self", box_near(AABB.union(a, a), a))
	check("union errors", pcall(AABB.union, a, {}) == false)
	check("union errors nil", pcall(AABB.union, nil, nil) == false)
	local i = AABB.intersection(a, b)
	check("intersection non-nil", i ~= nil)
	check("intersection values", i.min.x == 1 and i.max.x == 2 and i.min.y == 1 and i.max.y == 2)
	check("intersection disjoint nil", AABB.intersection(a, AABB.new({ x = 5, y = 5, z = 5 }, { x = 6, y = 6, z = 6 })) == nil)
	check("intersection touching non-nil degenerate", (function()
		local t = AABB.intersection(a, AABB.new({ x = 2, y = 0, z = 0 }, { x = 4, y = 2, z = 2 }))
		return t ~= nil and t.min.x == 2 and t.max.x == 2
	end)())
	check("intersection self", box_near(AABB.intersection(a, a), a))
	check("intersection errors", pcall(AABB.intersection, a, {}) == false)
	local corners = AABB.corners(AABB.new({ x = 0, y = 0, z = 0 }, { x = 1, y = 2, z = 3 }))
	check("corners count 8", #corners == 8)
	check("corners first min", corners[1].x == 0 and corners[1].y == 0 and corners[1].z == 0)
	check("corners last max", corners[8].x == 1 and corners[8].y == 2 and corners[8].z == 3)
	check("corners second", corners[2].x == 1 and corners[2].y == 0 and corners[2].z == 0)
	check("corners errors", pcall(AABB.corners, {}) == false)
	local t = AABB.to_table(a)
	check("to_table min", t.min.x == 0 and t.min.y == 0 and t.min.z == 0)
	check("to_table max", t.max.x == 2 and t.max.y == 2 and t.max.z == 2)
	check("to_table separate", rawequal(t.min, a.min) == false)
	check("to_table errors", pcall(AABB.to_table, {}) == false)
	check("from_table roundtrip", box_near(AABB.from_table(AABB.to_table(a)), a))
	check("from_table named", (function()
		local f = AABB.from_table({ min = { x = 1, y = 1, z = 1 }, max = { x = 2, y = 2, z = 2 } })
		return f.min.x == 1 and f.max.x == 2
	end)())
	check("from_table empty defaults", (function()
		local f = AABB.from_table({})
		return f.min.x == 0 and f.max.x == 0
	end)())
	check("from_table only min", (function()
		local f = AABB.from_table({ min = { x = 5, y = 5, z = 5 } })
		return f.min.x == 0 and f.max.x == 5
	end)())
	check("from_table errors nil", pcall(AABB.from_table, nil) == false)
	check("from_table errors number", pcall(AABB.from_table, 5) == false)
	check("from_table errors string", pcall(AABB.from_table, "x") == false)
end

print("=== AABB encapsulate ===")

do
	local box = AABB.new({ x = 0, y = 0, z = 0 }, { x = 1, y = 1, z = 1 })
	check("encapsulate inside same", box_near(AABB.encapsulate(box, { x = 0.5, y = 0.5, z = 0.5 }), box))
	check("encapsulate outside expands", (function()
		local e = AABB.encapsulate(box, { x = 5, y = -2, z = 3 })
		return e.min.x == 0 and e.max.x == 5 and e.min.y == -2 and e.max.y == 1 and e.max.z == 3
	end)())
	check("encapsulate indexed", (function()
		local e = AABB.encapsulate(box, { 2, 2, 2 })
		return e.max.x == 2
	end)())
	check("encapsulate non-table clones", (function()
		local e = AABB.encapsulate(box, 123)
		return box_near(e, box) and rawequal(e, box) == false
	end)())
	check("encapsulate nil clones", (function()
		local e = AABB.encapsulate(box, nil)
		return box_near(e, box)
	end)())
	check("encapsulate empty origin", (function()
		local big = AABB.new({ x = 5, y = 5, z = 5 }, { x = 6, y = 6, z = 6 })
		local e = AABB.encapsulate(big, {})
		return e.min.x == 0 and e.max.x == 6
	end)())
	check("encapsulate errors on bad box", pcall(AABB.encapsulate, {}, { x = 1, y = 1, z = 1 }) == false)
	local c = AABB.encapsulate_aabb(box, AABB.new({ x = -1, y = -1, z = -1 }, { x = 0.5, y = 0.5, z = 0.5 }))
	check("encapsulate_aabb expands", c.min.x == -1 and c.max.x == 1)
	check("encapsulate_aabb disjoint equals union", box_near(
		AABB.encapsulate_aabb(box, AABB.new({ x = 5, y = 5, z = 5 }, { x = 6, y = 6, z = 6 })),
		AABB.union(box, AABB.new({ x = 5, y = 5, z = 5 }, { x = 6, y = 6, z = 6 }))))
	check("encapsulate_aabb self", box_near(AABB.encapsulate_aabb(box, box), box))
	check("encapsulate_aabb errors", pcall(AABB.encapsulate_aabb, box, {}) == false)
	check("encapsulate_aabb errors both", pcall(AABB.encapsulate_aabb, {}, {}) == false)
end

print("=== AABB euclidean distances ===")

do
	local box = AABB.new({ x = 0, y = 0, z = 0 }, { x = 1, y = 1, z = 1 })
	check("distance_to_point inside 0", near(AABB.distance_to_point(box, { x = 0.5, y = 0.5, z = 0.5 }), 0))
	check("distance_to_point on face 0", near(AABB.distance_to_point(box, { x = 1, y = 0.5, z = 0.5 }), 0))
	check("distance_to_point x-only 1", near(AABB.distance_to_point(box, { x = 2, y = 0.5, z = 0.5 }), 1))
	check("distance_to_point y-low 2", near(AABB.distance_to_point(box, { x = 0.5, y = -2, z = 0.5 }), 2))
	check("distance_to_point z-only 3", near(AABB.distance_to_point(box, { x = 0.5, y = 0.5, z = 4 }), 3))
	check("distance_to_point diagonal sqrt3", near(AABB.distance_to_point(box, { x = 2, y = 2, z = 2 }), math.sqrt(3)))
	check("distance_to_point indexed", near(AABB.distance_to_point(box, { 2, 0.5, 0.5 }), 1))
	check("distance_to_point negative side", near(AABB.distance_to_point(box, { x = -3, y = 0.5, z = 0.5 }), 3))
	check("distance_to_point large", near(AABB.distance_to_point(box, { x = 1001, y = 0.5, z = 0.5 }), 1000))
	check("distance_to_point errors bad box", pcall(AABB.distance_to_point, {}, { x = 1, y = 1, z = 1 }) == false)
	check("distance_to_point errors bad point", pcall(AABB.distance_to_point, box, 5) == false)
	check("distance_to_point errors nil point", pcall(AABB.distance_to_point, box, nil) == false)
	local other = AABB.new({ x = 3, y = 0, z = 0 }, { x = 4, y = 1, z = 1 })
	check("distance_to_aabb x gap 2", near(AABB.distance_to_aabb(box, other), 2))
	check("distance_to_aabb symmetric", near(AABB.distance_to_aabb(other, box), AABB.distance_to_aabb(box, other)))
	check("distance_to_aabb overlap 0", AABB.distance_to_aabb(box, box) == 0)
	check("distance_to_aabb touching 0", AABB.distance_to_aabb(box, AABB.new({ x = 1, y = 0, z = 0 }, { x = 2, y = 1, z = 1 })) == 0)
	check("distance_to_aabb diagonal sqrt3", near(AABB.distance_to_aabb(box, AABB.new({ x = 2, y = 2, z = 2 }, { x = 3, y = 3, z = 3 })), math.sqrt(3)))
	check("distance_to_aabb y gap", near(AABB.distance_to_aabb(box, AABB.new({ x = 0, y = 5, z = 0 }, { x = 1, y = 6, z = 1 })), 4))
	check("distance_to_aabb z gap reverse", near(AABB.distance_to_aabb(AABB.new({ x = 0, y = 0, z = 5 }, { x = 1, y = 1, z = 6 }), box), 4))
	check("distance_to_aabb errors", pcall(AABB.distance_to_aabb, box, {}) == false)
	check("distance_to_aabb errors both", pcall(AABB.distance_to_aabb, {}, {}) == false)
	check("distance alias matches", near(AABB.distance(box, other), AABB.distance_to_aabb(box, other)))
	check("distance alias overlap 0", AABB.distance(box, box) == 0)
	check("distance_squared 4", near(AABB.distance_squared(box, other), 4))
	check("distance_squared diagonal 3", near(AABB.distance_squared(box, AABB.new({ x = 2, y = 2, z = 2 }, { x = 3, y = 3, z = 3 })), 3))
	check("distance_squared overlap 0", AABB.distance_squared(box, box) == 0)
	check("distance_squared equals dist squared", (function()
		local d = AABB.distance_to_aabb(box, other)
		return near(AABB.distance_squared(box, other), d * d)
	end)())
	check("distance_squared errors", pcall(AABB.distance_squared, box, {}) == false)
end

print("=== AABB manhattan / chebyshev ===")

do
	local box = AABB.new({ x = 0, y = 0, z = 0 }, { x = 1, y = 1, z = 1 })
	check("manhattan point inside 0", AABB.distance_manhattan_to_point(box, { x = 0.5, y = 0.5, z = 0.5 }) == 0)
	check("manhattan point x 1", near(AABB.distance_manhattan_to_point(box, { x = 2, y = 0.5, z = 0.5 }), 1))
	check("manhattan point diagonal 3", near(AABB.distance_manhattan_to_point(box, { x = 2, y = 2, z = 2 }), 3))
	check("manhattan point negative", near(AABB.distance_manhattan_to_point(box, { x = -1, y = -1, z = -1 }), 3))
	check("manhattan point indexed", near(AABB.distance_manhattan_to_point(box, { 2, 2, 2 }), 3))
	check("manhattan point errors bad box", pcall(AABB.distance_manhattan_to_point, {}, { x = 1, y = 1, z = 1 }) == false)
	check("manhattan point errors bad point", pcall(AABB.distance_manhattan_to_point, box, 7) == false)
	check("manhattan aabb overlap 0", AABB.distance_manhattan_to_aabb(box, box) == 0)
	check("manhattan aabb x gap 2", near(AABB.distance_manhattan_to_aabb(box, AABB.new({ x = 3, y = 0, z = 0 }, { x = 4, y = 1, z = 1 })), 2))
	check("manhattan aabb diagonal 3", near(AABB.distance_manhattan_to_aabb(box, AABB.new({ x = 2, y = 2, z = 2 }, { x = 3, y = 3, z = 3 })), 3))
	check("manhattan aabb errors", pcall(AABB.distance_manhattan_to_aabb, box, {}) == false)
	check("chebyshev point inside 0", AABB.distance_chebyshev_to_point(box, { x = 0.5, y = 0.5, z = 0.5 }) == 0)
	check("chebyshev point x 1", near(AABB.distance_chebyshev_to_point(box, { x = 2, y = 0.5, z = 0.5 }), 1))
	check("chebyshev point diagonal 1", near(AABB.distance_chebyshev_to_point(box, { x = 2, y = 2, z = 2 }), 1))
	check("chebyshev point uneven max", near(AABB.distance_chebyshev_to_point(box, { x = 5, y = 2, z = 1.5 }), 4))
	check("chebyshev point errors", pcall(AABB.distance_chebyshev_to_point, box, nil) == false)
	check("chebyshev point errors bad box", pcall(AABB.distance_chebyshev_to_point, {}, { x = 1, y = 1, z = 1 }) == false)
	check("chebyshev aabb overlap 0", AABB.distance_chebyshev_to_aabb(box, box) == 0)
	check("chebyshev aabb x gap 2", near(AABB.distance_chebyshev_to_aabb(box, AABB.new({ x = 3, y = 0, z = 0 }, { x = 4, y = 1, z = 1 })), 2))
	check("chebyshev aabb diagonal 1", near(AABB.distance_chebyshev_to_aabb(box, AABB.new({ x = 2, y = 2, z = 2 }, { x = 3, y = 3, z = 3 })), 1))
	check("chebyshev aabb uneven", near(AABB.distance_chebyshev_to_aabb(box, AABB.new({ x = 5, y = 2, z = 0 }, { x = 6, y = 3, z = 1 })), 4))
	check("chebyshev aabb errors", pcall(AABB.distance_chebyshev_to_aabb, {}, box) == false)
end

print("=== AABB minkowski ===")

do
	local box = AABB.new({ x = 0, y = 0, z = 0 }, { x = 1, y = 1, z = 1 })
	local pt = { x = 2, y = 2, z = 2 }
	check("minkowski point default euclidean", near(AABB.distance_minkowski_to_point(box, pt), math.sqrt(3)))
	check("minkowski point nil p default", near(AABB.distance_minkowski_to_point(box, pt, nil), math.sqrt(3)))
	check("minkowski point p1 manhattan", near(AABB.distance_minkowski_to_point(box, pt, 1), 3))
	check("minkowski point p2 euclidean", near(AABB.distance_minkowski_to_point(box, pt, 2), math.sqrt(3)))
	check("minkowski point inf chebyshev", near(AABB.distance_minkowski_to_point(box, pt, math.huge), 1))
	check("minkowski point 1div0 chebyshev", near(AABB.distance_minkowski_to_point(box, pt, 1 / 0), 1))
	check("minkowski point p3 custom", near(AABB.distance_minkowski_to_point(box, pt, 3), (1 + 1 + 1) ^ (1 / 3)))
	check("minkowski point p4 custom", near(AABB.distance_minkowski_to_point(box, { x = 3, y = 0.5, z = 0.5 }, 4), 2))
	check("minkowski point inside 0", AABB.distance_minkowski_to_point(box, { x = 0.5, y = 0.5, z = 0.5 }, 3) == 0)
	check("minkowski point p<1 errors", pcall(AABB.distance_minkowski_to_point, box, pt, 0.5) == false)
	check("minkowski point p0 errors", pcall(AABB.distance_minkowski_to_point, box, pt, 0) == false)
	check("minkowski point negative p errors", pcall(AABB.distance_minkowski_to_point, box, pt, -2) == false)
	check("minkowski point string p<1 errors", pcall(AABB.distance_minkowski_to_point, box, pt, "0.5") == false)
	check("minkowski point bad string defaults euclidean", near(AABB.distance_minkowski_to_point(box, pt, "abc"), math.sqrt(3)))
	check("minkowski point errors bad box", pcall(AABB.distance_minkowski_to_point, {}, pt, 2) == false)
	check("minkowski point errors bad point", pcall(AABB.distance_minkowski_to_point, box, 5, 2) == false)
	local other = AABB.new({ x = 2, y = 2, z = 2 }, { x = 3, y = 3, z = 3 })
	check("minkowski aabb default euclidean", near(AABB.distance_minkowski_to_aabb(box, other), math.sqrt(3)))
	check("minkowski aabb p1", near(AABB.distance_minkowski_to_aabb(box, other, 1), 3))
	check("minkowski aabb p2", near(AABB.distance_minkowski_to_aabb(box, other, 2), math.sqrt(3)))
	check("minkowski aabb inf", near(AABB.distance_minkowski_to_aabb(box, other, math.huge), 1))
	check("minkowski aabb 1div0", near(AABB.distance_minkowski_to_aabb(box, other, 1 / 0), 1))
	check("minkowski aabb p3", near(AABB.distance_minkowski_to_aabb(box, other, 3), (3) ^ (1 / 3)))
	check("minkowski aabb overlap 0 any p", AABB.distance_minkowski_to_aabb(box, box, 3) == 0)
	check("minkowski aabb nil p default", near(AABB.distance_minkowski_to_aabb(box, other, nil), math.sqrt(3)))
	check("minkowski aabb p<1 errors", pcall(AABB.distance_minkowski_to_aabb, box, other, 0.9) == false)
	check("minkowski aabb p0 errors", pcall(AABB.distance_minkowski_to_aabb, box, other, 0) == false)
	check("minkowski aabb errors bad", pcall(AABB.distance_minkowski_to_aabb, box, {}, 2) == false)
	check("minkowski p1 matches manhattan point", near(AABB.distance_minkowski_to_point(box, pt, 1), AABB.distance_manhattan_to_point(box, pt)))
	check("minkowski p2 matches euclidean point", near(AABB.distance_minkowski_to_point(box, pt, 2), AABB.distance_to_point(box, pt)))
	check("minkowski inf matches chebyshev point", near(AABB.distance_minkowski_to_point(box, pt, math.huge), AABB.distance_chebyshev_to_point(box, pt)))
	check("minkowski p1 matches manhattan aabb", near(AABB.distance_minkowski_to_aabb(box, other, 1), AABB.distance_manhattan_to_aabb(box, other)))
	check("minkowski p2 matches euclidean aabb", near(AABB.distance_minkowski_to_aabb(box, other, 2), AABB.distance_to_aabb(box, other)))
	check("minkowski inf matches chebyshev aabb", near(AABB.distance_minkowski_to_aabb(box, other, math.huge), AABB.distance_chebyshev_to_aabb(box, other)))
end

print("=== AABB empty / near / boundaries ===")

do
	check("is_empty zero box true", AABB.is_empty(AABB.new()) == true)
	check("is_empty unit false", AABB.is_empty(AABB.new({ x = 0, y = 0, z = 0 }, { x = 1, y = 1, z = 1 })) == false)
	check("is_empty flat x true", AABB.is_empty(AABB.new({ x = 1, y = 0, z = 0 }, { x = 1, y = 2, z = 2 })) == true)
	check("is_empty flat y true", AABB.is_empty(AABB.new({ x = 0, y = 5, z = 0 }, { x = 1, y = 5, z = 1 })) == true)
	check("is_empty flat z true", AABB.is_empty(AABB.new({ x = 0, y = 0, z = 3 }, { x = 1, y = 1, z = 3 })) == true)
	check("is_empty touching intersection true", (function()
		local i = AABB.intersection(
			AABB.new({ x = 0, y = 0, z = 0 }, { x = 1, y = 1, z = 1 }),
			AABB.new({ x = 1, y = 0, z = 0 }, { x = 2, y = 1, z = 1 }))
		return i ~= nil and AABB.is_empty(i) == true
	end)())
	check("is_empty errors", pcall(AABB.is_empty, {}) == false)
	local a = AABB.new({ x = 0, y = 0, z = 0 }, { x = 1, y = 1, z = 1 })
	local b = AABB.new({ x = 0, y = 0, z = 0 }, { x = 1, y = 1, z = 1 })
	check("is_near identical true", AABB.is_near(a, b) == true)
	check("is_near tiny diff true default", AABB.is_near(a, AABB.new({ x = 1e-7, y = 0, z = 0 }, { x = 1, y = 1, z = 1 })) == true)
	check("is_near big diff false", AABB.is_near(a, AABB.new({ x = 0.01, y = 0, z = 0 }, { x = 1, y = 1, z = 1 })) == false)
	check("is_near custom eps true", AABB.is_near(a, AABB.new({ x = 0.05, y = 0, z = 0 }, { x = 1, y = 1, z = 1 }), 0.1) == true)
	check("is_near custom eps false", AABB.is_near(a, AABB.new({ x = 0.05, y = 0, z = 0 }, { x = 1, y = 1, z = 1 }), 0.01) == false)
	check("is_near errors", pcall(AABB.is_near, a, {}) == false)
	check("is_near errors nil", pcall(AABB.is_near, nil, nil) == false)
	check("zero box volume 0", AABB.volume(AABB.new({ x = 3, y = 3, z = 3 }, { x = 3, y = 3, z = 3 })) == 0)
	check("zero box surface 0", AABB.surface_area(AABB.new({ x = 3, y = 3, z = 3 }, { x = 3, y = 3, z = 3 })) == 0)
	check("zero box empty", AABB.is_empty(AABB.new({ x = 3, y = 3, z = 3 }, { x = 3, y = 3, z = 3 })) == true)
	check("negative box dims positive", (function()
		local n = AABB.new({ x = -5, y = -5, z = -5 }, { x = -1, y = -1, z = -1 })
		return AABB.width(n) == 4 and near(AABB.volume(n), 64)
	end)())
	check("large box width", AABB.width(AABB.new({ x = -1e9, y = 0, z = 0 }, { x = 1e9, y = 0, z = 0 })) == 2e9)
	check("one box unit", (function()
		local o = AABB.new({ x = 0, y = 0, z = 0 }, { x = 1, y = 1, z = 1 })
		return AABB.width(o) == 1 and AABB.volume(o) == 1 and AABB.surface_area(o) == 6
	end)())
end

print(string.format("\nTests finished: %d passed, %d failed", pass_count, fail_count))
assert(fail_count == 0, string.format("%d aabb test(s) failed", fail_count))
if arg and arg[0] and arg[0]:match("aabb%.lua$") then
	os.exit(fail_count > 0 and 1 or 0)
end
