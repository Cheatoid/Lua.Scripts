-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for physics2d.lua.
-- Run from this directory:
--   lua physics2d.lua
--   luajit physics2d.lua

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
local lib = require "physics2d"
-- Bridging: file-locals used by tests mapped to module exports.
local physics = lib
local SHAPE_AABB = lib.SHAPE_AABB
local SHAPE_CIRCLE = lib.SHAPE_CIRCLE
local SHAPE_OBB = lib.SHAPE_OBB
local Vector2 = require("vector").new
local apply_acceleration = lib.apply_acceleration
local apply_force = lib.apply_force
local body = lib.body
local check_collision = lib.check_collision
local closest_point_on_segment = lib.closest_point_on_segment
local integrate = lib.integrate
local overlaps = lib.overlaps
local ray_vs_aabb = lib.ray_vs_aabb
local ray_vs_circle = lib.ray_vs_circle
local ray_vs_obb = lib.ray_vs_obb
local ray_vs_segment = lib.ray_vs_segment
local set_gravity = lib.set_gravity
local set_shape = lib.set_shape
local step = lib.step
local update_shape = lib.update_shape
-- TODO(manual): the following were file-locals with no direct export;
-- verify and export or inline as needed: acceleration, angle, gravity, position, radius, velocity, vertices

if true then
	local function near(a, b, eps)
		eps = eps or 1e-6
		return math.abs(a - b) <= eps
	end

	local function make_body(x, y, shape)
		local b = physics.body(x, y)
		if shape ~= nil then
			physics.set_shape(b, shape)
		end
		return b
	end

	-- Bodies / shape constructors / constants.
	do
		assert(physics.SHAPE_CIRCLE == 1, "SHAPE_CIRCLE should be 1")
		assert(physics.SHAPE_AABB == 2, "SHAPE_AABB should be 2")
		assert(physics.SHAPE_OBB == 3, "SHAPE_OBB should be 3")

		local b = physics.body(1, 2)
		assert(b.position[1] == 1 and b.position[2] == 2, "body should store position")
		assert(b.velocity[1] == 0 and b.velocity[2] == 0, "body velocity should start at 0")
		assert(b.acceleration[1] == 0 and b.acceleration[2] == 0, "body acceleration should start at 0")
		assert(b.gravity[1] == 0 and b.gravity[2] == 0, "body gravity should start at 0")
		assert(b.dynamic == true, "body should be dynamic by default")
		assert(b.shape_type == SHAPE_CIRCLE, "body default shape_type should be circle")
		assert(b.shape.type == SHAPE_CIRCLE, "body default shape should be circle")

		local c = physics.circle(5)
		assert(c.type == SHAPE_CIRCLE and c.radius == 5, "circle should store radius")

		local a = physics.aabb(4, 6)
		assert(a.type == SHAPE_AABB and a.width == 4 and a.height == 6, "aabb should store extents")

		local o = physics.obb(4, 2)
		assert(o.type == SHAPE_OBB, "obb should have obb type")
		assert(o.width == 4 and o.height == 2, "obb should store extents")
		assert(o.angle == 0, "obb angle should default to 0")
		assert(o.axis_x1 == 1 and o.axis_x2 == 0, "obb default X axis should be (1, 0)")
		assert(o.axis_y1 == 0 and o.axis_y2 == 1, "obb default Y axis should be (0, 1)")

		local angled = physics.obb(4, 2, math.pi)
		assert(angled.angle == math.pi, "obb should store explicit angle")
	end

	-- Forces / gravity / integration / step.
	do
		local b = physics.body(0, 0)
		physics.apply_acceleration(b, Vector2(1, 2))
		assert(b.acceleration[1] == 1 and b.acceleration[2] == 2, "apply_acceleration should accumulate")
		physics.apply_acceleration(b, Vector2(1, 1))
		assert(b.acceleration[1] == 2 and b.acceleration[2] == 3, "apply_acceleration should keep accumulating")
		physics.integrate(b, 1)
		assert(b.velocity[1] == 2 and b.velocity[2] == 3, "integrate should fold acceleration into velocity")
		assert(b.position[1] == 2 and b.position[2] == 3, "integrate should move by new velocity")
		assert(b.acceleration[1] == 0 and b.acceleration[2] == 0, "integrate should clear per-step acceleration")
		physics.integrate(b, 1)
		assert(b.velocity[1] == 2 and b.velocity[2] == 3, "velocity should persist without input")
		assert(b.position[1] == 4 and b.position[2] == 6, "position should keep advancing on velocity")

		local f = physics.body(0, 0)
		physics.apply_force(f, Vector2(0, 5))
		physics.integrate(f, 2)
		assert(f.velocity[1] == 0 and f.velocity[2] == 10, "apply_force should behave like acceleration (no mass)")
		assert(f.position[1] == 0 and f.position[2] == 20, "apply_force should move the body")

		local g = physics.body(0, 0)
		physics.set_gravity(g, Vector2(0, -10))
		assert(g.gravity[1] == 0 and g.gravity[2] == -10, "set_gravity should store gravity")
		physics.integrate(g, 1)
		assert(g.velocity[2] == -10 and g.position[2] == -10, "gravity should accelerate the body")

		local cancel = physics.body(0, 0)
		physics.set_gravity(cancel, Vector2(0, -10))
		physics.apply_acceleration(cancel, Vector2(0, 10))
		physics.integrate(cancel, 1)
		assert(cancel.velocity[1] == 0 and cancel.velocity[2] == 0, "opposing accel + gravity should cancel")
		assert(cancel.position[1] == 0 and cancel.position[2] == 0, "cancelled forces should not move the body")

		local s = physics.body(0, 0)
		s.velocity[1] = 4
		physics.step(s, 0.5)
		assert(s.position[1] == 2 and s.position[2] == 0, "step should integrate like integrate")

		local frozen = physics.body(1, 2)
		frozen.dynamic = false
		physics.apply_acceleration(frozen, Vector2(5, 5))
		physics.step(frozen, 1)
		assert(frozen.position[1] == 1 and frozen.position[2] == 2, "static body should not integrate")
		assert(frozen.acceleration[1] == 5 and frozen.acceleration[2] == 5,
			"static body should keep accumulated acceleration")
	end

	-- set_shape / update_shape OBB cache.
	do
		local b = physics.body(10, 20)
		physics.set_shape(b, physics.aabb(4, 2))
		assert(b.shape_type == SHAPE_AABB, "set_shape should update shape_type")
		assert(b.shape.width == 4 and b.shape.height == 2, "set_shape should assign the shape")

		-- Axis-aligned OBB cache: 4x2 centered on (10, 20).
		local o = physics.body(10, 20)
		physics.set_shape(o, physics.obb(4, 2, 0))
		local v = o.shape.vertices
		assert(near(v[1], 8) and near(v[2], 19), "obb (-X,-Y) vertex mismatch")
		assert(near(v[3], 12) and near(v[4], 19), "obb (+X,-Y) vertex mismatch")
		assert(near(v[5], 12) and near(v[6], 21), "obb (+X,+Y) vertex mismatch")
		assert(near(v[7], 8) and near(v[8], 21), "obb (-X,+Y) vertex mismatch")
		assert(near(o.shape.axis_x1, 1) and near(o.shape.axis_x2, 0), "obb X axis mismatch at angle 0")
		assert(near(o.shape.axis_y1, 0) and near(o.shape.axis_y2, 1), "obb Y axis mismatch at angle 0")

		-- 90-degree rotation swaps extents: 4x2 becomes tall.
		local r = physics.body(0, 0)
		physics.set_shape(r, physics.obb(4, 2, math.pi * 0.5))
		local rv = r.shape.vertices
		assert(near(r.shape.axis_x1, 0) and near(r.shape.axis_x2, 1), "obb X axis mismatch at 90deg")
		assert(near(r.shape.axis_y1, -1) and near(r.shape.axis_y2, 0), "obb Y axis mismatch at 90deg")
		assert(near(rv[1], 1) and near(rv[2], -2), "rotated obb (-X,-Y) mismatch")
		assert(near(rv[3], 1) and near(rv[4], 2), "rotated obb (+X,-Y) mismatch")
		assert(near(rv[5], -1) and near(rv[6], 2), "rotated obb (+X,+Y) mismatch")
		assert(near(rv[7], -1) and near(rv[8], -2), "rotated obb (-X,+Y) mismatch")

		-- Moving the body requires an explicit cache refresh.
		local m = physics.body(0, 0)
		physics.set_shape(m, physics.obb(2, 2, 0))
		m.position[1] = 5
		m.position[2] = -3
		physics.update_shape(m)
		local mv = m.shape.vertices
		assert(near(mv[1], 4) and near(mv[2], -4), "moved obb should refresh vertices")
		assert(near(mv[5], 6) and near(mv[6], -2), "moved obb opposite vertex mismatch")

		-- update_shape is a no-op for non-OBB shapes (should not error).
		local plain = physics.body(0, 0)
		physics.set_shape(plain, physics.aabb(2, 2))
		physics.update_shape(plain)
		assert(plain.shape_type == SHAPE_AABB, "update_shape should leave AABB alone")
	end

	-- overlaps: circle/circle, aabb/aabb, circle/aabb + alias.
	do
		local c1 = make_body(0, 0, physics.circle(1))
		local c2 = make_body(1, 0, physics.circle(1))
		local c3 = make_body(3, 0, physics.circle(1))
		local touching = make_body(2, 0, physics.circle(1))
		assert(physics.overlaps(c1, c2) == true, "overlapping circles should collide")
		assert(physics.overlaps(c1, c3) == false, "separated circles should not collide")
		assert(physics.overlaps(c1, touching) == true, "touching circles should count as overlap")

		local q1 = make_body(0, 0, physics.aabb(2, 2))
		local q2 = make_body(1.5, 0, physics.aabb(2, 2))
		local q3 = make_body(3, 0, physics.aabb(2, 2))
		local qedge = make_body(2, 0, physics.aabb(2, 2))
		local qabove = make_body(0, 3, physics.aabb(2, 2))
		assert(physics.overlaps(q1, q2) == true, "overlapping aabbs should collide")
		assert(physics.overlaps(q1, q3) == false, "separated aabbs should not collide")
		assert(physics.overlaps(q1, qedge) == true, "touching aabbs should count as overlap")
		assert(physics.overlaps(q1, qabove) == false, "aabbs separated on Y should not collide")

		local circle = make_body(0, 0, physics.circle(1))
		local box = make_body(0, 0, physics.aabb(2, 2))
		local far_circle = make_body(5, 0, physics.circle(1))
		local edge_circle = make_body(2, 0, physics.circle(1))
		assert(physics.overlaps(circle, box) == true, "circle inside aabb should collide")
		assert(physics.overlaps(box, circle) == true, "aabb vs circle dispatch should match")
		assert(physics.overlaps(far_circle, box) == false, "distant circle should miss aabb")
		assert(physics.overlaps(box, far_circle) == false, "reversed distant circle should miss aabb")
		assert(physics.overlaps(edge_circle, box) == true, "circle touching aabb edge should collide")
		assert(physics.overlaps(box, edge_circle) == true, "reversed edge circle should collide")

		assert(physics.check_collision == physics.overlaps, "check_collision should alias overlaps")
		assert(physics.check_collision(c1, c2) == true, "alias should report overlaps")

		local bogus_a = physics.body(0, 0)
		bogus_a.shape_type = 99
		local bogus_b = physics.body(0, 0)
		bogus_b.shape_type = 99
		assert(physics.overlaps(bogus_a, bogus_b) == false, "unknown shape ids should not collide")
	end

	-- overlaps: OBB combinations.
	do
		local obb = make_body(0, 0, physics.obb(2, 2, 0))
		local circle_in = make_body(0, 0, physics.circle(1))
		local circle_out = make_body(5, 0, physics.circle(1))
		local circle_edge = make_body(2, 0, physics.circle(1))
		assert(physics.overlaps(circle_in, obb) == true, "circle inside obb should collide")
		assert(physics.overlaps(obb, circle_in) == true, "obb vs circle dispatch should match")
		assert(physics.overlaps(circle_out, obb) == false, "distant circle should miss obb")
		assert(physics.overlaps(obb, circle_out) == false, "reversed distant circle should miss obb")
		assert(physics.overlaps(circle_edge, obb) == true, "circle touching obb edge should collide")
		assert(physics.overlaps(obb, circle_edge) == true, "reversed edge circle should collide")

		local o1 = make_body(0, 0, physics.obb(2, 2, 0))
		local o2 = make_body(0, 0, physics.obb(2, 2, 0))
		local o3 = make_body(10, 0, physics.obb(2, 2, 0))
		local o_rot = make_body(0, 0, physics.obb(2, 2, math.pi * 0.25))
		local o_touch = make_body(2, 0, physics.obb(2, 2, 0))
		local o_gap = make_body(2.5, 0, physics.obb(2, 2, 0))
		assert(physics.overlaps(o1, o2) == true, "coincident obbs should collide")
		assert(physics.overlaps(o1, o3) == false, "separated obbs should not collide")
		assert(physics.overlaps(o1, o_rot) == true, "centered rotated obb should collide")
		assert(physics.overlaps(o1, o_touch) == true, "touching obbs should count as overlap")
		assert(physics.overlaps(o1, o_gap) == false, "obbs beyond summed extents should not collide")

		local aabb = make_body(0, 0, physics.aabb(2, 2))
		local obb_same = make_body(0, 0, physics.obb(2, 2, 0))
		local obb_far = make_body(10, 0, physics.obb(2, 2, 0))
		local obb_spun = make_body(0, 0, physics.obb(2, 2, math.pi * 0.25))
		local obb_touch = make_body(2, 0, physics.obb(2, 2, 0))
		local obb_gap = make_body(3, 0, physics.obb(2, 2, 0))
		assert(physics.overlaps(aabb, obb_same) == true, "coincident aabb/obb should collide")
		assert(physics.overlaps(obb_same, aabb) == true, "obb/aabb dispatch should match")
		assert(physics.overlaps(aabb, obb_far) == false, "separated aabb/obb should not collide")
		assert(physics.overlaps(obb_far, aabb) == false, "reversed separated aabb/obb should not collide")
		assert(physics.overlaps(aabb, obb_spun) == true, "centered rotated obb should hit aabb")
		assert(physics.overlaps(aabb, obb_touch) == true, "touching aabb/obb should collide")
		assert(physics.overlaps(aabb, obb_gap) == false, "gapped aabb/obb should not collide")
	end

	-- Rays + closest point.
	do
		local r = physics.ray(Vector2(1, 2), Vector2(0, 4))
		assert(r.origin[1] == 1 and r.origin[2] == 2, "ray should store origin")
		assert(near(r.direction[1], 0) and near(r.direction[2], 1), "ray should normalize direction")
		assert(r.max_distance == math.huge, "ray max_distance should default to huge")
		local limited = physics.ray(Vector2(0, 0), Vector2(1, 0), 10)
		assert(limited.max_distance == 10, "ray should store custom max_distance")
		assert(near(limited.direction[1], 1) and near(limited.direction[2], 0), "unit ray direction should stay unit")

		-- ray_vs_circle.
		do
			local target = make_body(5, 0, physics.circle(1))
			local forward = physics.ray(Vector2(0, 0), Vector2(1, 0))
			local t, hit = physics.ray_vs_circle(forward, target)
			assert(t ~= nil and hit ~= nil, "ray should hit circle")
			assert(near(t, 4), "circle hit distance should be 4")
			assert(near(hit[1], 4) and near(hit[2], 0), "circle hit point should be (4, 0)")

			local up = physics.ray(Vector2(0, 0), Vector2(0, 1))
			assert(physics.ray_vs_circle(up, target) == nil, "ray pointing away should miss circle")

			local behind = physics.ray(Vector2(0, 0), Vector2(-1, 0))
			assert(physics.ray_vs_circle(behind, target) == nil, "ray facing away should miss circle behind origin")

			local inside = physics.ray(Vector2(5, 0), Vector2(1, 0))
			local ti, hiti = physics.ray_vs_circle(inside, target)
			assert(ti ~= nil and near(ti, 1), "ray inside circle should report exit distance")
			assert(near(hiti[1], 6) and near(hiti[2], 0), "inside-circle exit point mismatch")

			local short = physics.ray(Vector2(0, 0), Vector2(1, 0), 2)
			assert(physics.ray_vs_circle(short, target) == nil, "circle hit beyond max_distance should miss")

			local ok = pcall(physics.ray_vs_circle, nil, target)
			assert(ok == false, "ray_vs_circle should error on bad ray")
			ok = pcall(physics.ray_vs_circle, forward, nil)
			assert(ok == false, "ray_vs_circle should error on bad body")
		end

		-- ray_vs_aabb.
		do
			local box = make_body(5, 0, physics.aabb(2, 2))
			local forward = physics.ray(Vector2(0, 0), Vector2(1, 0))
			local t, hit = physics.ray_vs_aabb(forward, box)
			assert(t ~= nil and near(t, 4), "aabb hit distance should be 4")
			assert(near(hit[1], 4) and near(hit[2], 0), "aabb hit point should be (4, 0)")

			local high = physics.ray(Vector2(0, 5), Vector2(1, 0))
			assert(physics.ray_vs_aabb(high, box) == nil, "ray above aabb should miss")

			local inside = physics.ray(Vector2(5, 0), Vector2(1, 0))
			local ti, hiti = physics.ray_vs_aabb(inside, box)
			assert(ti ~= nil and near(ti, 0), "ray inside aabb should report t=0")
			assert(near(hiti[1], 5) and near(hiti[2], 0), "inside-aabb hit should equal origin")

			local back = physics.ray(Vector2(10, 0), Vector2(-1, 0))
			local tb, hitb = physics.ray_vs_aabb(back, box)
			assert(tb ~= nil and near(tb, 4), "negative-direction ray should hit aabb")
			assert(near(hitb[1], 6) and near(hitb[2], 0), "negative-direction hit point mismatch")

			local short = physics.ray(Vector2(0, 0), Vector2(1, 0), 2)
			assert(physics.ray_vs_aabb(short, box) == nil, "aabb hit beyond max_distance should miss")

			local ok = pcall(physics.ray_vs_aabb, nil, box)
			assert(ok == false, "ray_vs_aabb should error on bad ray")
		end

		-- ray_vs_segment.
		do
			local ray = physics.ray(Vector2(0, 0), Vector2(1, 0))
			local t, hit = physics.ray_vs_segment(ray, Vector2(5, -1), Vector2(5, 1))
			assert(t ~= nil and near(t, 5), "segment hit distance should be 5")
			assert(near(hit[1], 5) and near(hit[2], 0), "segment hit point should be (5, 0)")

			assert(physics.ray_vs_segment(ray, Vector2(0, 1), Vector2(5, 1)) == nil, "parallel segment should miss")
			assert(physics.ray_vs_segment(ray, Vector2(-5, -1), Vector2(-5, 1)) == nil, "segment behind ray should miss")
			assert(physics.ray_vs_segment(ray, Vector2(5, 1), Vector2(5, 2)) == nil,
				"segment off the ray line should miss")

			local ok = pcall(physics.ray_vs_segment, nil, Vector2(0, 0), Vector2(1, 1))
			assert(ok == false, "ray_vs_segment should error on bad ray")
		end

		-- ray_vs_obb.
		do
			local aligned = make_body(5, 0, physics.obb(2, 2, 0))
			local ray = physics.ray(Vector2(0, 0), Vector2(1, 0))
			local t, hit = physics.ray_vs_obb(ray, aligned)
			assert(t ~= nil and near(t, 4), "aligned obb hit should match aabb")
			assert(near(hit[1], 4) and near(hit[2], 0), "aligned obb hit point mismatch")

			local up = physics.ray(Vector2(0, 0), Vector2(0, 1))
			assert(physics.ray_vs_obb(up, aligned) == nil, "ray pointing away should miss obb")

			-- 2x2 square rotated 45deg: x-extent is sqrt(2).
			local spun = make_body(5, 0, physics.obb(2, 2, math.pi * 0.25))
			local ts, hits = physics.ray_vs_obb(ray, spun)
			assert(ts ~= nil and hits ~= nil, "ray should hit rotated obb")
			assert(near(ts, 5 - math.sqrt(2)), "rotated obb hit distance mismatch")
			assert(near(hits[1], 5 - math.sqrt(2)) and near(hits[2], 0), "rotated obb hit point mismatch")

			local short = physics.ray(Vector2(0, 0), Vector2(1, 0), 2)
			assert(physics.ray_vs_obb(short, aligned) == nil, "obb hit beyond max_distance should miss")

			local ok = pcall(physics.ray_vs_obb, nil, aligned)
			assert(ok == false, "ray_vs_obb should error on bad ray")
		end

		-- closest_point_on_segment.
		do
			local mid = physics.closest_point_on_segment(Vector2(2, 5), Vector2(0, 0), Vector2(4, 0))
			assert(near(mid[1], 2) and near(mid[2], 0), "closest point should project to (2, 0)")

			local before = physics.closest_point_on_segment(Vector2(0, 0), Vector2(1, 0), Vector2(3, 0))
			assert(near(before[1], 1) and near(before[2], 0), "point before segment should clamp to start")

			local after = physics.closest_point_on_segment(Vector2(10, 0), Vector2(1, 0), Vector2(3, 0))
			assert(near(after[1], 3) and near(after[2], 0), "point past segment should clamp to end")

			local degenerate = physics.closest_point_on_segment(Vector2(0, 0), Vector2(7, 8), Vector2(7, 8))
			assert(near(degenerate[1], 7) and near(degenerate[2], 8), "degenerate segment should return its point")
		end
	end

	print("All tests passed")
end
