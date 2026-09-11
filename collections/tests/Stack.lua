-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for Stack.lua.
-- Run from this directory:
--   lua Stack.lua
--   luajit Stack.lua

-- Bootstrap: make requires work from tests/ subdir with plain lua/luajit.
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
	local root
	for _, c in ipairs({ dir, dir .. "../", dir .. "../..//", dir .. "../../..//", "./", "../", "../../" }) do
		if isfile(c .. "standalone/bits.lua") then
			root = c
			break
		end
	end
	root = root or dir .. "../"
	if package then
		package.path = dir ..
			"../?.lua;" ..
			dir ..
			"../?/init.lua;" ..
			dir ..
			"?.lua;" ..
			dir ..
			"?/init.lua;" ..
			root ..
			"?.lua;" ..
			root ..
			"?/init.lua;" ..
			root ..
			"standalone/?.lua;" ..
			root ..
			"math/?.lua;" ..
			root ..
			"collections/?.lua;" ..
			root ..
			"benchmark/?.lua;" ..
			root ..
			"timer/?.lua;" ..
			root ..
			"autocompleter/?.lua;" ..
			root ..
			"permission/?.lua;" ..
			root ..
			"chat_commander/?.lua;" ..
			root .. "vm/?.lua;" .. root .. "require_finder/?.lua;" .. root .. "inventory/?.lua;" .. package.path
	end
	local searchers = package.searchers or package.loaders
	if searchers then
		table.insert(searchers, 2, function(mod)
			if mod:sub(1, 3) == "../" or mod:sub(1, 2) == "./" then
				local clean = mod:gsub("^%./", ""):gsub("^%.%.%/", ""):gsub("^%.%.%/", "")
				local tries = { dir .. "../" .. clean .. ".lua", dir .. "../" .. clean .. "/init.lua", root ..
				clean .. ".lua", root .. clean .. "/init.lua" }
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
local lib = require "Stack"
local Stack = lib

if true then
	-- Create a new Stack
	local stack = Stack.new()
	-- Test that a new stack is empty
	assert(stack:isEmpty(), "New stack should be empty")
	-- Test that the count of a new stack is 0
	assert(stack:count() == 0, "New stack should have count 0")
	-- Push a value onto the stack
	stack:push(1)
	-- Test that the stack is not empty
	assert(not stack:isEmpty(), "Stack should not be empty after push")
	-- Test that the count of the stack is 1
	assert(stack:count() == 1, "Stack should have count 1 after push")
	-- Test that the top value of the stack is the pushed value
	assert(stack:peek() == 1, "Top value of stack should be the pushed value")
	-- Pop a value from the stack
	local poppedValue = stack:pop()
	-- Test that the popped value is the pushed value
	assert(poppedValue == 1, "Popped value should be the pushed value")
	-- Test that the stack is empty after pop
	assert(stack:isEmpty(), "Stack should be empty after pop")
	-- Test that the count of the stack is 0 after pop
	assert(stack:count() == 0, "Stack should have count 0 after pop")
	-- Test that the top value of the stack is nil after pop
	assert(stack:peek() == nil, "Top value of stack should be nil after pop")
	-- Test that the iterator of an empty stack returns nil
	do
		local _f, _s, _i = stack:iterator()
		assert(_f(_s, _i) == nil, "Iterator of empty stack should return nil")
	end
	-- Test pushing nil onto the stack
	local status, err = pcall(function() stack:push(nil) end)
	assert(not status and string.find(err, "cannot add a nil value to the stack"), "Pushing nil should throw an error")
	-- Test popping from an empty stack
	local poppedValue = stack:pop()
	assert(poppedValue == nil, "Popping from an empty stack should return nil")
	-- Test peeking at an empty stack
	local peekedValue = stack:peek()
	assert(peekedValue == nil, "Peeking at an empty stack should return nil")
	-- Test pushing multiple values onto the stack
	for i = 1, 10 do
		stack:push(i)
	end
	-- Test that the count of the stack is 10
	assert(stack:count() == 10, "Stack should have count 10 after pushing 10 values")
	-- Test that the top value of the stack is 10
	assert(stack:peek() == 10, "Top value of stack should be 10 after pushing 10 values")
	-- Test the iterator with multiple values
	local i = 10
	for value in stack:iterator() do
		assert(value == i, "Iterator should return values in LIFO order")
		i = i - 1
	end
	-- Test the clear method
	for i = 1, 10 do
		stack:push(i)
	end
	stack:clear()
	assert(stack:isEmpty(), "Stack should be empty after clear")
	assert(stack:count() == 0, "Stack should have count 0 after clear")
	assert(stack:pop() == nil, "Pop operation should return nil after clear")
	assert(stack:peek() == nil, "Peek operation should return nil after clear")
	do
		local _f, _s, _i = stack:iterator()
		assert(_f(_s, _i) == nil, "Iterator of cleared stack should return nil")
	end
	-- Test pushing and popping multiple items
	for i = 1, 10 do
		stack:push(i)
	end
	for i = 10, 1, -1 do
		assert(stack:pop() == i, "Stack should maintain LIFO order of items")
	end
	-- Test clearing the stack and then pushing more items
	for i = 1, 10 do
		stack:push(i)
	end
	stack:clear()
	for i = 11, 20 do
		stack:push(i)
	end
	for i = 20, 11, -1 do
		assert(stack:pop() == i, "Stack should maintain LIFO order after clear")
	end
	-- Test pushing a large number of items
	for i = 1, 10000 do
		stack:push(i)
	end
	assert(stack:count() == 10000, "Stack should handle a large number of items")
	-- Test pushing different types of values
	stack:clear()
	local t = { 1, 2, 3 }
	stack:push("test")
	stack:push(t)
	stack:push(true)
	assert(stack:pop() == true, "Stack should handle boolean values")
	assert(stack:pop() == t, "Stack should handle table values")
	assert(stack:pop() == "test", "Stack should handle string values")
	-- Test __ipairs iteration
	stack:clear()
	for i = 1, 5 do
		stack:push(i)
	end
	local ipairs_count = 0
	for index, value in stack:__ipairs() do
		ipairs_count = ipairs_count + 1
		assert(index == value, "__ipairs() should return index and value in stack order")
	end
	assert(ipairs_count == 5, "__ipairs() should iterate over all 5 items")
	print("All tests passed")
end
