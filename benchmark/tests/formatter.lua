-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for formatter.lua.
-- Run from this directory:
--   lua formatter.lua
--   luajit formatter.lua

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
local lib = require "formatter"
-- Bridging: file-locals used by tests mapped to module exports.
local Formatter = lib
-- TODO(manual): the following were file-locals with no direct export;
-- verify and export or inline as needed: s

if true then
	-- Test time formatting
	assert(Formatter.time(1e-9):match("ns"), "Should format nanoseconds")
	assert(Formatter.time(1e-6):match("us"), "Should format microseconds")
	assert(Formatter.time(0.001):match("ms"), "Should format milliseconds")
	assert(Formatter.time(1):match("s"), "Should format seconds")

	-- Test number formatting
	assert(Formatter.number(1500000):match("M"), "Should format millions")
	assert(Formatter.number(1500):match("K"), "Should format thousands")

	-- Test benchmark formatting
	local test_summary = {
		name = "test",
		raw_count = 100,
		count = 95,
		min = 0.001,
		max = 0.005,
		mean = 0.002,
		median = 0.002,
		stddev = 0.0005,
		ops_sec = 500,
	}
	local output = Formatter.benchmark("test", test_summary)
	assert(output:match("Benchmark: test"), "Should include benchmark name")
	assert(output:match("Iterations:"), "Should include iterations")

	print("All tests passed")
end
