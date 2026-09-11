-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for ObjectPool.lua.
-- Run from this directory:
--   lua ObjectPool.lua
--   luajit ObjectPool.lua

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
local lib = require "ObjectPool"
local ObjectPool = lib

if true then
	-- Create a new unbounded ObjectPool
	local pool = ObjectPool.new(function() return { active = false } end, function(obj) obj.active = false end)

	-- Test that the pool is initially empty
	assert(pool:count() == 0, "Pool should be empty initially")

	-- Test fill operation
	pool:fill(3)
	assert(pool:count() == 3, "Pool should have 3 items after fill")

	-- Test get operation
	local obj1 = pool:get()
	assert(obj1.active == false, "Object should be inactive initially")
	obj1.active = true
	assert(pool:count() == 2, "Pool should have 2 items after get")

	-- Test release operation
	pool:release(obj1)
	assert(obj1.active == false, "Object should be reset on release")
	assert(pool:count() == 3, "Pool should have 3 items after release")

	-- Test getting a new object when pool is empty
	pool:get()
	pool:get()
	pool:get()
	assert(pool:count() == 0, "Pool should be empty after getting all items")
	local obj4 = pool:get()
	assert(obj4.active == false, "New object should be created by factory when pool is empty")
	assert(pool:count() == 0, "Pool should remain empty after creating new object")

	-- Test clear operation
	pool:release(obj4)
	assert(pool:count() == 1, "Pool should have 1 item before clear")
	pool:clear()
	assert(pool:count() == 0, "Pool should be empty after clear")

	-- Test bounded ObjectPool with maxSize as second argument
	local bPool = ObjectPool.new(function() return {} end, 2)
	bPool:fill(5) -- Fill more than maxSize
	assert(bPool:count() == 2, "Bounded pool with maxSize as second argument should cap at maxSize")

	local bObj1 = bPool:get()
	local bObj2 = bPool:get()
	local bObj3 = bPool:get()

	bPool:release(bObj1)
	bPool:release(bObj2)
	assert(bPool:count() == 2, "Bounded pool should have 2 items after releases")

	bPool:release(bObj3)
	assert(bPool:count() == 2, "Bounded pool should discard item when full on release")

	-- Test bounded ObjectPool with reset and maxSize
	local bPool2 = ObjectPool.new(function() return { val = 1 } end, function(obj) obj.val = 0 end, 2)
	local bObj4 = bPool2:get()
	bObj4.val = 10
	bPool2:release(bObj4)
	assert(bObj4.val == 0, "Reset function should be called on release even with maxSize")

	-- Test iterator
	local iterated_items = {}
	for index, value in bPool:iterator() do
		iterated_items[index] = value
	end
	assert(iterated_items[1] ~= nil, "Iterator should return items")
	assert(#iterated_items == 2, "Iterator should return 2 items")

	-- Test # operator
	assert(#bPool == 2, "# operator should return count")

	-- Test tostring
	local str = tostring(bPool)
	assert(str == "ObjectPool(available=2, maxSize=2)", "tostring should match format")

	print("All tests passed")
end
