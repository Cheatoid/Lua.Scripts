-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for runner.lua.
-- Run from this directory:
--   lua runner.lua
--   luajit runner.lua

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
local lib = require "runner"
-- Bridging: file-locals used by tests mapped to module exports.
local Runner = lib
-- TODO(manual): the following were file-locals with no direct export;
-- verify and export or inline as needed: summary, times, warmup

if true then
	-- Test runner creation
	local runner = Runner.new({ iterations = 100, warmup = 5 })
	assert(runner.iterations == 100, "Should set custom iterations")
	assert(runner.warmup == 5, "Should set custom warmup")

	-- Test fixed iteration run
	local result = runner:run(function()
		local x = 0
		for i = 1, 100 do
			x = x + i
		end
		return x
	end, "sum loop")
	assert(result.name == "sum loop", "Should set result name")
	assert(result.times and #result.times > 0, "Should record times")
	assert(result.summary, "Should include summary")

	-- Test time-based run
	local time_result = runner:runForTime(function()
		for i = 1, 1000 do
			math.sqrt(i)
		end
	end, "sqrt loop", { target_time = 0.1, min_iterations = 5 })
	assert(time_result.times and #time_result.times >= 5, "Should run min_iterations")

	print("All tests passed")
end
