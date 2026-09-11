-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for suite.lua.
-- Run from this directory:
--   lua suite.lua
--   luajit suite.lua

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
local lib = require "suite"
-- Bridging: file-locals used by tests mapped to module exports.
local Suite = lib
-- TODO(manual): the following were file-locals with no direct export;
-- verify and export or inline as needed: benchmarks

if true then
	-- Test suite creation
	local suite = Suite.new({ iterations = 10, warmup = 2, silent = true })
	assert(#suite.benchmarks == 0, "Suite should start empty")

	-- Test add
	suite:add("test1", function()
		local x = 0
		for i = 1, 100 do
			x = x + i
		end
	end)
	suite:add("test2", function()
		local t = {}
		for i = 1, 100 do
			t[i] = i
		end
	end)
	assert(#suite.benchmarks == 2, "Should have 2 benchmarks")

	-- Test run
	local results = suite:run()
	assert(results["test1"], "Should have test1 result")
	assert(results["test2"], "Should have test2 result")
	assert(results["test1"].summary, "Should have summary")

	-- Test reset
	suite:reset()
	assert(not next(suite.results), "Should clear results")
	assert(#suite.benchmarks == 2, "Should keep registrations")

	-- Test clear
	suite:clear()
	assert(#suite.benchmarks == 0, "Should clear registrations")

	print("All tests passed")
end
