-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for Arena.lua.
-- Run from this directory:
--   lua Arena.lua
--   luajit Arena.lua

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
local lib = require "Arena"
-- Bridging: file-locals used by tests mapped to module exports.
local Arena = lib
-- TODO(manual): the following were file-locals with no direct export;
-- verify and export or inline as needed: new

if true then
	-- Basic alloc and reuse
	do
		local arena = Arena.new(function() return { value = 0 } end)
		assert(arena:is_empty(), "Arena should be empty initially")
		assert(arena:size() == 0, "size should be 0 initially")
		assert(arena:active() == 0, "active should be 0 initially")
		assert(arena:capacity() == 0, "capacity should be 0 initially")
		assert(arena:inactive() == 0, "inactive should be 0 initially")
		assert(arena:utilization() == 0, "utilization should be 0 when empty")
		assert(arena:last() == nil, "last should be nil when empty")
		assert(arena:peek() == nil, "peek should be nil when empty")
		assert(arena:get(1) == nil, "get should return nil when empty")
		assert(arena:checkpoint() == 0, "checkpoint should be 0 initially")

		local o1, created1 = arena:alloc()
		assert(created1 == true, "first alloc should create")
		assert(arena:size() == 1, "size should be 1 after first alloc")
		assert(arena:capacity() == 1, "capacity should be 1 after first alloc")
		assert(not arena:is_empty(), "Arena should not be empty after alloc")
		assert(arena:full(), "Arena should be full when size == capacity")
		assert(arena:utilization() == 1, "utilization should be 1 when full")
		assert(arena:get(1) == o1, "get(1) should return first object")
		assert(arena:last() == o1, "last should return first object")
		assert(arena:peek() == o1, "peek should alias last")
		assert(arena:contains(o1), "contains should return true for active object")
		assert(arena:index_of(o1) == 1, "index_of should return 1 for first object")

		local o2, created2 = arena:alloc()
		assert(created2 == true, "second alloc should create")
		assert(arena:size() == 2, "size should be 2 after second alloc")
		assert(arena:capacity() == 2, "capacity should be 2 after second alloc")
		assert(o2 ~= o1, "alloc should produce distinct objects")
		assert(arena:get(2) == o2, "get(2) should return second object")
		assert(arena:last() == o2, "last should return most recent object")
		assert(arena:index_of(o2) == 2, "index_of should return 2 for second object")

		-- Restore truncates and allows reuse without calling factory
		arena:restore(1)
		assert(arena:size() == 1, "size should be 1 after restore(1)")
		assert(arena:capacity() == 2, "restore should keep capacity")
		assert(arena:inactive() == 1, "inactive should be 1 after restore")
		local o2b, created2b = arena:alloc()
		assert(created2b == false, "alloc after restore should reuse")
		assert(o2b == o2, "reused object should be identical")

		-- Reset clears size but keeps capacity for reuse
		arena:reset()
		assert(arena:size() == 0, "size should be 0 after reset")
		assert(arena:capacity() == 2, "reset should keep capacity")
		assert(arena:inactive() == 2, "inactive should equal capacity after reset")
		assert(arena:is_empty(), "Arena should be empty after reset")
		local r1, rc1 = arena:alloc()
		assert(rc1 == false, "alloc after reset should reuse")
		assert(r1 == o1, "first reused object should be identical")
	end
	-- Default factory and factory args
	do
		local def = Arena.new()
		local o, created = def:alloc()
		assert(created == true, "default factory first alloc should create")
		assert(type(o) == "table", "default factory should produce a table")

		local withArgs = Arena.new(function(a, b) return { a = a, b = b } end)
		local v, vc = withArgs:alloc(10, 20)
		assert(vc == true, "alloc with args should create")
		assert(v.a == 10 and v.b == 20, "factory should receive alloc args")
	end
	-- alloc_many
	do
		local arena = Arena.new(function() return {} end)
		local arr, created = arena:alloc_many(3)
		assert(#arr == 3, "alloc_many should return 3 objects")
		assert(created == 3, "alloc_many should report 3 created")
		assert(arena:size() == 3, "size should be 3 after alloc_many(3)")
		assert(arena:get(1) == arr[1], "alloc_many objects should match pool order")
		assert(arena:get(3) == arr[3], "alloc_many objects should match pool order")

		arena:reset()
		local arr2, created2 = arena:alloc_many(3)
		assert(created2 == 0, "alloc_many after reset should reuse")
		assert(arr2[1] == arr[1] and arr2[2] == arr[2] and arr2[3] == arr[3],
			"alloc_many reuse should return identical objects")

		local empty, created0 = arena:alloc_many(0)
		assert(#empty == 0, "alloc_many(0) should return empty array")
		assert(created0 == 0, "alloc_many(0) should report 0 created")
		assert(arena:size() == 3, "alloc_many(0) should not change size")
	end
	-- release_last with reset
	do
		local resetCount = 0
		local arena = Arena.new(function() return { v = 1 } end, {
			reset = function(o)
				o.v = 0
				resetCount = resetCount + 1
			end,
		})
		local o1 = arena:alloc()
		o1.v = 99
		local o2 = arena:alloc()
		o2.v = 100
		arena:release_last()
		assert(resetCount == 1, "release_last should call reset once by default")
		assert(o2.v == 0, "release_last should reset released object")
		assert(arena:size() == 1, "size should be 1 after release_last()")
		arena:release_last(5)
		assert(arena:size() == 0, "release_last should clamp to size")
		assert(o1.v == 0, "release_last should reset all released objects")
		assert(resetCount == 2, "release_last(5) should reset one remaining object")
		-- Releasing from empty arena should be safe
		arena:release_last()
		assert(arena:size() == 0, "release_last on empty arena should stay at 0")
	end
	-- reset_from
	do
		local arena = Arena.new(function() return { v = 0 } end, {
			reset = function(o) o.v = -1 end,
		})
		local a1 = arena:alloc()
		a1.v = 10
		local a2 = arena:alloc()
		a2.v = 20
		local a3 = arena:alloc()
		a3.v = 30
		arena:reset_from(2)
		assert(arena:size() == 1, "size should be 1 after reset_from(2)")
		assert(a2.v == -1 and a3.v == -1, "reset_from should reset from index onward")
		assert(a1.v == 10, "reset_from should preserve objects before index")
		assert(arena:get(1) == a1, "get(1) should still return first object")
		assert(arena:get(2) == nil, "get beyond size should return nil")
		-- reset_from(size + 1) is a valid no-op
		arena:reset_from(2)
		assert(arena:size() == 1, "reset_from(size + 1) should be a no-op")
	end
	-- checkpoint / restore / reset
	do
		local arena = Arena.new(function() return { x = 0 } end, {
			reset = function(o) o.x = 0 end,
		})
		local o1 = arena:alloc()
		o1.x = 5
		local cp = arena:checkpoint()
		assert(cp == 1, "checkpoint should return current size")
		local o2 = arena:alloc()
		o2.x = 7
		assert(arena:size() == 2, "size should be 2 after second alloc")
		arena:restore(cp)
		assert(arena:size() == 1, "restore should truncate to checkpoint")
		assert(o2.x == 0, "restore should reset truncated objects")
		assert(o1.x == 5, "restore should preserve objects at or below checkpoint")
		arena:reset()
		assert(arena:size() == 0, "reset should clear size")
		assert(o1.x == 0, "reset should reset all active objects")
		assert(arena:is_empty(), "Arena should be empty after reset")
	end
	-- reserve and warm
	do
		local count = 0
		local arena = Arena.new(function()
			count = count + 1
			return {}
		end, { reserve = 5 })
		assert(arena:capacity() == 5, "reserve option should pre-allocate")
		assert(arena:size() == 0, "reserve should not change size")
		assert(count == 5, "reserve should call factory for each slot")
		assert(arena:inactive() == 5, "inactive should be 5 after reserve(5)")
		assert(not arena:full(), "Arena should not be full after reserve without alloc")
		local o, created = arena:alloc()
		assert(created == false, "alloc after reserve should reuse")
		assert(count == 5, "reuse should not call factory")
		assert(o == arena:get(1), "reused object should match pool")
		arena:reserve(3)
		assert(arena:capacity() == 5, "reserve with smaller capacity should be a no-op")
		arena:reserve(8)
		assert(arena:capacity() == 8, "reserve should grow capacity")
		assert(count == 8, "reserve growth should call factory")
		arena:warm(10)
		assert(arena:capacity() == 10, "warm should alias reserve")
	end
	-- foreach / iter / get / last / contains / index_of
	do
		local arena = Arena.new(function() return {} end)
		local o1 = arena:alloc()
		local o2 = arena:alloc()
		local o3 = arena:alloc()
		local seen = {}
		arena:foreach(function(item, index)
			seen[index] = item
		end)
		assert(seen[1] == o1 and seen[2] == o2 and seen[3] == o3, "foreach should visit all active items in order")
		local iterCount = 0
		for i, obj in arena:iter() do
			iterCount = iterCount + 1
			assert(i == iterCount, "iter should yield sequential indices")
			assert(obj == arena:get(i), "iter value should match get(i)")
		end
		assert(iterCount == 3, "iter should yield 3 items")
		assert(arena:get(0) == nil, "get(0) should return nil")
		assert(arena:get(-1) == nil, "get(-1) should return nil")
		assert(arena:get(4) == nil, "get beyond size should return nil")
		assert(arena:contains(o1) and arena:contains(o3), "contains should return true for active objects")
		local unknown = {}
		assert(not arena:contains(unknown), "contains should return false for unknown object")
		assert(arena:index_of(unknown) == nil, "index_of should return nil for unknown object")
		arena:restore(1)
		assert(not arena:contains(o3), "contains should return false for truncated object")
		assert(arena:index_of(o3) == nil, "index_of should return nil for truncated object")
	end
	-- size / capacity / stats helpers and aliases
	do
		local arena = Arena.new(function() return {} end)
		arena:reserve(4)
		arena:alloc()
		arena:alloc()
		assert(arena:size() == 2, "size should be 2")
		assert(arena:active() == 2, "active should alias size")
		assert(arena:capacity() == 4, "capacity should be 4")
		assert(arena:inactive() == 2, "inactive should be capacity - size")
		assert(arena:utilization() == 0.5, "utilization should be size / capacity")
		assert(not arena:is_empty(), "is_empty should be false with active items")
		assert(not arena:full(), "full should be false when size < capacity")
		local stats = arena:stats()
		assert(stats.size == 2, "stats.size should match size")
		assert(stats.capacity == 4, "stats.capacity should match capacity")
		assert(stats.inactive == 2, "stats.inactive should match inactive")
		assert(stats.utilization == 0.5, "stats.utilization should match utilization")
		assert(Arena.active == Arena.size, "active should alias size")
		assert(Arena.peek == Arena.last, "peek should alias last")
		assert(Arena.shrink_to_fit == Arena.trim, "shrink_to_fit should alias trim")
	end
	-- trim
	do
		local arena = Arena.new(function() return {} end)
		arena:reserve(10)
		arena:alloc()
		arena:alloc()
		arena:alloc()
		arena:trim()
		assert(arena:capacity() == 3, "trim should drop inactive slots")
		assert(arena:inactive() == 0, "inactive should be 0 after trim")
		assert(arena:full(), "Arena should be full after trim")
		arena:alloc()
		arena:alloc()
		assert(arena:size() == 5 and arena:capacity() == 5, "alloc after trim should grow again")
		arena:restore(2)
		arena:trim()
		assert(arena:capacity() == 2, "trim after restore should shrink to size")
		assert(arena:size() == 2, "trim should preserve size")
	end
	-- clear with and without free
	do
		local arena = Arena.new(function() return {} end)
		arena:alloc()
		arena:alloc()
		arena:alloc()
		arena:clear()
		assert(arena:size() == 0, "clear should reset size")
		assert(arena:capacity() == 0, "clear should free capacity by default")
		assert(arena:is_empty(), "Arena should be empty after clear")
		assert(arena:last() == nil, "last should be nil after clear")
		local o, created = arena:alloc()
		assert(created == true, "alloc after free should create")

		arena:alloc()
		arena:clear(false)
		assert(arena:size() == 0, "clear(false) should reset size")
		assert(arena:capacity() == 2, "clear(false) should keep capacity")
		assert(arena:inactive() == 2, "clear(false) should keep inactive slots")
		local r, rc = arena:alloc()
		assert(rc == false, "alloc after clear(false) should reuse")
		assert(r == o, "reuse after clear(false) should return identical object")
	end
	-- maintainLookup
	do
		local arena = Arena.new(function() return {} end, { maintainLookup = true })
		local o1 = arena:alloc()
		local o2 = arena:alloc()
		assert(arena:index_of(o1) == 1, "lookup index_of should return 1")
		assert(arena:index_of(o2) == 2, "lookup index_of should return 2")
		assert(arena:contains(o2), "lookup contains should return true")
		assert(arena:index_of({}) == nil, "lookup index_of should return nil for unknown object")
		arena:restore(1)
		assert(arena:index_of(o2) == nil, "lookup should hide inactive objects")
		assert(not arena:contains(o2), "lookup contains should be false for inactive object")
		assert(arena:index_of(o1) == 1, "lookup should keep active objects")
		arena:reserve(5)
		arena:trim()
		assert(arena:index_of(o1) == 1, "lookup should survive trim")
		arena:clear()
		assert(arena:index_of(o1) == nil, "lookup should be cleared with arena")
	end
	-- debug assertions
	do
		local arena = Arena.new(nil, { debug = true })
		arena:alloc()
		arena:alloc()
		local ok1 = pcall(function() arena:reset_from(0) end)
		assert(not ok1, "reset_from(0) should error in debug mode")
		local ok2 = pcall(function() arena:reset_from(99) end)
		assert(not ok2, "reset_from out of range should error in debug mode")
		local ok3 = pcall(function() arena:restore(99) end)
		assert(not ok3, "restore out of range should error in debug mode")
		local ok4 = pcall(function() arena:restore(-1) end)
		assert(not ok4, "restore(-1) should error in debug mode")
		-- Valid calls should not error
		arena:reset_from(1)
		arena:restore(0)
		local plain = Arena.new()
		plain:alloc()
		local ok5 = pcall(function() plain:reset_from(99) end)
		assert(ok5, "invalid index should not error without debug mode")
	end
	print("All tests passed")
end
