-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for Deque.lua.
-- Run from this directory:
--   lua Deque.lua
--   luajit Deque.lua

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
local lib = require "Deque"
local Deque = lib

if true then
	-- Create a new Deque
	local deque = Deque.new()
	-- Test that the deque is initially empty
	assert(deque:isEmpty(), "Deque should be empty initially")
	-- Test pushFront operation
	deque:pushFront(1)
	assert(deque:count() == 1, "Deque should have 1 item after pushFront")
	assert(deque:peekFront() == 1, "peekFront should return the first item in the deque")
	assert(deque:peekBack() == 1, "peekBack should return the last item in the deque")
	-- Test pushBack operation
	deque:pushBack(2)
	assert(deque:count() == 2, "Deque should have 2 items after pushBack")
	assert(deque:peekFront() == 1, "peekFront should return the first item in the deque")
	assert(deque:peekBack() == 2, "peekBack should return the last item in the deque")
	-- Test popFront operation
	local item = deque:popFront()
	assert(item == 1, "popFront should return the first item in the deque")
	assert(deque:count() == 1, "Deque should have 1 item after popFront")
	assert(deque:peekFront() == 2, "peekFront should return the first item in the deque")
	assert(deque:peekBack() == 2, "peekBack should return the last item in the deque")
	-- Test popBack operation
	item = deque:popBack()
	assert(item == 2, "popBack should return the last item in the deque")
	assert(deque:isEmpty(), "Deque should be empty after popBack")
	-- Test iterator operation on empty deque
	local count = 0
	for _ in deque:iterator() do
		count = count + 1
	end
	assert(count == 0, "Iterator operation should not return any items when the deque is empty")
	-- Test pushFront and pushBack operations with nil
	local status, err = pcall(function() deque:pushFront(nil) end)
	assert(not status and string.find(err, "cannot add a nil value to the deque"),
		"pushFront operation should fail when trying to add nil")
	status, err = pcall(function() deque:pushBack(nil) end)
	assert(not status and string.find(err, "cannot add a nil value to the deque"),
		"pushBack operation should fail when trying to add nil")
	-- Test popFront and popBack operations on empty deque
	item = deque:popFront()
	assert(item == nil, "popFront operation should return nil when the deque is empty")
	item = deque:popBack()
	assert(item == nil, "popBack operation should return nil when the deque is empty")
	-- Test peekFront and peekBack operations on empty deque
	item = deque:peekFront()
	assert(item == nil, "peekFront operation should return nil when the deque is empty")
	item = deque:peekBack()
	assert(item == nil, "peekBack operation should return nil when the deque is empty")
	-- Test clear operation
	deque:pushFront(1)
	deque:pushBack(2)
	deque:clear()
	assert(deque:isEmpty() and deque:count() == 0, "Deque should be empty after clear")
	-- Test with different types of values
	local t = { 1, 2, 3 }
	local f = function() return 4 end
	deque:pushFront("test")
	deque:pushBack(t)
	deque:pushFront(f)
	assert(deque:count() == 3, "Deque should have 3 items after adding different types of values")
	assert(deque:popFront() == f, "popFront should return the function")
	assert(deque:popBack() == t, "popBack should return the table")
	assert(deque:popFront() == "test", "popFront should return the string")
	-- Test with multiple values
	for i = 1, 10 do
		deque:pushFront(i)
	end
	assert(deque:count() == 10, "Deque should have 10 items after adding multiple values")
	for i = 10, 1, -1 do
		assert(deque:popFront() == i, "popFront should return the correct value")
	end
	assert(deque:isEmpty(), "Deque should be empty after removing all items")
	-- Test __ipairs iteration
	deque:clear()
	deque:pushBack(1)
	deque:pushBack(2)
	deque:pushBack(3)
	local ipairs_count = 0
	for index, value in deque:__ipairs() do
		ipairs_count = ipairs_count + 1
		assert(index == value, "__ipairs() should return index and value in deque order")
	end
	assert(ipairs_count == 3, "__ipairs() should iterate over all 3 items")
	print("All tests passed")
end
