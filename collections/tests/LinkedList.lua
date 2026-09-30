-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for LinkedList.lua.
-- Run from this directory:
--   lua LinkedList.lua
--   luajit LinkedList.lua

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
local lib = require "LinkedList"
local LinkedList = lib

if true then
	local list = LinkedList.new()
	assert(list:isEmpty(), "LinkedList should be empty initially")
	list:addFirst(1)
	assert(list:count() == 1, "LinkedList should have 1 item after addFirst")
	list:addLast(2)
	assert(list:count() == 2, "LinkedList should have 2 items after addLast")
	assert(list:removeFirst() == 1, "removeFirst should return the first item in the LinkedList")
	assert(list:count() == 1, "LinkedList should have 1 item after removeFirst")
	assert(list:removeLast() == 2, "removeLast should return the last item in the LinkedList")
	assert(list:isEmpty(), "LinkedList should be empty after removeLast")
	local status, err = pcall(function() list:addFirst(nil) end)
	assert(not status and string.find(err, "cannot add a nil value to the linked list"),
		"addFirst operation should fail when trying to add nil")
	status, err = pcall(function() list:addLast(nil) end)
	assert(not status and string.find(err, "cannot add a nil value to the linked list"),
		"addLast operation should fail when trying to add nil")
	assert(list:removeFirst() == nil, "removeFirst operation should return nil when the LinkedList is empty")
	assert(list:removeLast() == nil, "removeLast operation should return nil when the LinkedList is empty")
	for i = 1, 10 do
		list:addFirst(i)
	end
	assert(list:count() == 10, "LinkedList should have 10 items after adding multiple values")
	for i = 10, 1, -1 do
		assert(list:removeFirst() == i, "removeFirst should return the correct value")
	end
	assert(list:isEmpty(), "LinkedList should be empty after removing all items")
	-- Test clear operation
	list:addFirst(1)
	list:addLast(2)
	list:clear()
	assert(list:isEmpty() and list:count() == 0, "LinkedList should be empty after clear")
	-- Test with different types of values
	local t = { 1, 2, 3 }
	local f = function() return 4 end
	list:addFirst("test")
	list:addLast(t)
	list:addFirst(f)
	assert(list:count() == 3, "LinkedList should have 3 items after adding different types of values")
	assert(list:removeFirst() == f, "removeFirst should return the function")
	assert(list:removeLast() == t, "removeLast should return the table")
	assert(list:removeFirst() == "test", "removeFirst should return the string")
	-- Test with multiple values
	for i = 1, 10 do
		list:addFirst(i)
	end
	assert(list:count() == 10, "LinkedList should have 10 items after adding multiple values")
	for i = 10, 1, -1 do
		assert(list:removeFirst() == i, "removeFirst should return the correct value")
	end
	assert(list:isEmpty(), "LinkedList should be empty after removing all items")
	-- Test iterator operation on empty list
	local count = 0
	for _ in list:iterator() do
		count = count + 1
	end
	assert(count == 0, "Iterator operation should not return any items when the LinkedList is empty")
	-- Test iterator operation on non-empty list
	for i = 1, 5 do
		list:addLast(i)
	end
	local expected = 1
	for value in list:iterator() do
		assert(value == expected, "Iterator operation should return the correct value")
		expected = expected + 1
	end
	-- Test __ipairs iteration
	list:clear()
	for i = 1, 5 do
		list:addLast(i)
	end
	local ipairs_count = 0
	for index, value in list:__ipairs() do
		ipairs_count = ipairs_count + 1
		assert(index == value, "__ipairs() should return index and value in linked list order")
	end
	assert(ipairs_count == 5, "__ipairs() should iterate over all 5 items")
	print("All tests passed")
end
