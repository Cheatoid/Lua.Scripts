-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for FastDeque.lua.
-- Run from this directory:
--   lua FastDeque.lua
--   luajit FastDeque.lua

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
local lib = require "FastDeque"
local FastDeque = lib

if true then
	-- Create a new unbounded FastDeque
	local deque = FastDeque.new()
	-- Test that the deque is initially empty
	assert(deque:count() == 0, "FastDeque should be empty initially")

	-- Test pushRight operations
	deque:pushRight(1)
	assert(deque:count() == 1, "FastDeque should have 1 item after first pushRight")
	deque:pushRight(2)
	assert(deque:count() == 2, "FastDeque should have 2 items after second pushRight")

	-- Test pushLeft operations
	deque:pushLeft(3)
	assert(deque:count() == 3, "FastDeque should have 3 items after pushLeft")

	-- Test get operation (left to right)
	local items, count = deque:get()
	assert(count == 3, "Get should return count of 3")
	assert(items[1] == 3, "First item should be 3 (leftmost)")
	assert(items[2] == 1, "Second item should be 1")
	assert(items[3] == 2, "Third item should be 2 (rightmost)")

	-- Test peek operations
	assert(deque:peekLeft() == 3, "PeekLeft should return 3")
	assert(deque:peekRight() == 2, "PeekRight should return 2")

	-- Test popLeft operation
	local popped = deque:popLeft()
	assert(popped == 3, "PopLeft should return 3")
	assert(deque:count() == 2, "FastDeque should have 2 items after popLeft")

	-- Test popRight operation
	popped = deque:popRight()
	assert(popped == 2, "PopRight should return 2")
	assert(deque:count() == 1, "FastDeque should have 1 item after popRight")

	-- Test pop on empty deque
	deque:popLeft()
	assert(deque:count() == 0, "FastDeque should be empty after removing all items")
	popped = deque:popLeft()
	assert(popped == nil, "PopLeft on empty deque should return nil")
	popped = deque:popRight()
	assert(popped == nil, "PopRight on empty deque should return nil")
	assert(deque:peekLeft() == nil, "PeekLeft on empty deque should return nil")
	assert(deque:peekRight() == nil, "PeekRight on empty deque should return nil")

	-- Test bounded FastDeque
	local bDeque = FastDeque.new(3)
	bDeque:pushRight(1)
	bDeque:pushRight(2)
	bDeque:pushRight(3)
	assert(bDeque:count() == 3, "Bounded deque should have 3 items")

	-- Test bounded overflow on pushRight
	bDeque:pushRight(4)
	assert(bDeque:count() == 3, "Bounded deque count should remain 3 after overflow pushRight")
	items = bDeque:get()
	assert(items[1] == 2 and items[2] == 3 and items[3] == 4, "PushRight overflow should discard leftmost item")

	-- Test bounded overflow on pushLeft
	bDeque:pushLeft(5)
	assert(bDeque:count() == 3, "Bounded deque count should remain 3 after overflow pushLeft")
	items = bDeque:get()
	assert(items[1] == 5 and items[2] == 2 and items[3] == 3, "PushLeft overflow should discard rightmost item")

	-- Test iterator
	local iterated_items = {}
	for index, value in bDeque:iterator() do
		iterated_items[index] = value
	end
	assert(iterated_items[1] == 5, "Iterator should return 5 first")
	assert(iterated_items[2] == 2, "Iterator should return 2 second")
	assert(iterated_items[3] == 3, "Iterator should return 3 third")

	-- Test with different data types
	bDeque:popLeft()
	bDeque:popLeft()
	bDeque:popLeft()
	bDeque:pushLeft({ test = "table" })
	bDeque:pushLeft(function() return "function" end)
	bDeque:pushLeft("string")
	assert(bDeque:count() == 3, "FastDeque should handle different data types")

	print("All tests passed")
end
