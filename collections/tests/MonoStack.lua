-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for MonoStack.lua.
-- Run from this directory:
--   lua MonoStack.lua
--   luajit MonoStack.lua

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
local lib = require "MonoStack"
local Stack = lib

if true then
	-- Create a new Stack
	local stack = Stack.new()
	-- Test that the stack is initially empty
	assert(stack:count() == 0, "Stack should be empty initially")
	-- Test push operations
	stack:push(1)
	assert(stack:count() == 1, "Stack should have 1 item after first push")
	stack:push(2)
	assert(stack:count() == 2, "Stack should have 2 items after second push")
	stack:push(3)
	assert(stack:count() == 3, "Stack should have 3 items after third push")
	-- Test get operation
	local items, count = stack:get()
	assert(count == 3, "Get should return count of 3")
	assert(items[1] == 3, "First item should be 3 (most recent)")
	assert(items[2] == 2, "Second item should be 2")
	assert(items[3] == 1, "Third item should be 1 (oldest)")
	-- Test pop operation
	local popped = stack:pop()
	assert(popped == 3, "Popped item should be 3 (most recent)")
	assert(stack:count() == 2, "Stack should have 2 items after pop")
	-- Test peek operation
	local peeked = stack:peek()
	assert(peeked == 2, "Peeked item should be 2 (new top)")
	-- Test pop on empty stack
	stack:pop()
	stack:pop()
	assert(stack:count() == 0, "Stack should be empty after removing all items")
	popped = stack:pop()
	assert(popped == nil, "Pop on empty stack should return nil")
	assert(stack:peek() == nil, "Peek on empty stack should return nil")
	-- Test iterator
	stack:push("a")
	stack:push("b")
	stack:push("c")
	local iterated_items = {}
	for index, value in stack:iterator() do
		iterated_items[index] = value
	end
	assert(iterated_items[1] == "c", "Iterator should return 'c' first")
	assert(iterated_items[2] == "b", "Iterator should return 'b' second")
	assert(iterated_items[3] == "a", "Iterator should return 'a' third")
	-- Test with different data types
	stack:pop()
	stack:pop()
	stack:pop()
	stack:push({ test = "table" })
	stack:push(function() return "function" end)
	stack:push("string")
	assert(stack:count() == 3, "Stack should handle different data types")
	print("All tests passed")
end
