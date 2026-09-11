-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for MonoStack.lua.
-- Run from this directory:
--   lua MonoStack.lua
--   luajit MonoStack.lua

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
