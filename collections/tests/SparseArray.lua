-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for SparseArray.lua.
-- Run from this directory:
--   lua SparseArray.lua
--   luajit SparseArray.lua

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
local lib = require "SparseArray"
-- Bridging: file-locals used by tests mapped to module exports.
local SparseArray = lib

if true then
	-- Create a new SparseArray
	local sparsearray = SparseArray.new()
	-- Test that the sparsearray is initially empty
	assert(#sparsearray == 0, "SparseArray should be empty initially")
	-- Test add operation
	local id1 = sparsearray:add("Apple")
	assert(#sparsearray == 1, "SparseArray should have 1 item after add")
	assert(sparsearray:contains(id1), "SparseArray should contain the added value")
	-- Test add multiple values
	local id2 = sparsearray:add("Banana")
	local id3 = sparsearray:add("Cherry")
	assert(#sparsearray == 3, "SparseArray should have 3 items after adding multiple values")
	-- Test remove operation to create a hole
	sparsearray:remove(id2)
	assert(#sparsearray == 2, "SparseArray should have 2 items after remove")
	assert(not sparsearray:contains(id2), "SparseArray should not contain removed value")
	-- Test __pairs metamethod (unordered iteration)
	local pairs_count = 0
	for index, value in pairs(sparsearray) do
		pairs_count = pairs_count + 1
	end
	assert(pairs_count == 2, "pairs() should iterate over 2 items")
	-- Test __ipairs metamethod (ordered iteration, skips holes)
	local ipairs_count = 0
	local previous_index = 0
	for index, value in sparsearray:__ipairs() do
		ipairs_count = ipairs_count + 1
		assert(index > previous_index, "__ipairs() should return indices in ascending order")
		previous_index = index
	end
	assert(ipairs_count == 2, "__ipairs() should iterate over 2 items")
	-- Test iterator
	local iterator_count = 0
	for value in sparsearray:iterator() do
		iterator_count = iterator_count + 1
	end
	assert(iterator_count == 2, "iterator() should iterate over 2 items")
	-- Test clear operation
	sparsearray:clear()
	assert(#sparsearray == 0, "SparseArray should be empty after clear")
	print("All tests passed")
end
