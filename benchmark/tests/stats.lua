-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for stats.lua.
-- Run from this directory:
--   lua stats.lua
--   luajit stats.lua

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
local lib = require "stats"
-- Bridging: file-locals used by tests mapped to module exports.
local Stats = lib
-- TODO(manual): the following were file-locals with no direct export;
-- verify and export or inline as needed: percentiles

if true then
	-- Test basic statistics
	local data = { 1, 2, 3, 4, 5 }
	assert(Stats.count(data) == 5, "Count should be 5")
	assert(Stats.sum(data) == 15, "Sum should be 15")
	assert(Stats.mean(data) == 3, "Mean should be 3")
	assert(Stats.median(data) == 3, "Median should be 3")
	assert(Stats.min(data) == 1, "Min should be 1")
	assert(Stats.max(data) == 5, "Max should be 5")
	assert(Stats.range(data) == 4, "Range should be 4")

	-- Test mode
	local mode_data = { 1, 2, 2, 3, 3, 3 }
	assert(Stats.mode(mode_data) == 3, "Mode should be 3")

	-- Test percentiles
	assert(Stats.percentile(data, 50) == 3, "P50 should be 3")

	-- Test outlier removal
	local outlier_data = { 1, 2, 3, 4, 5, 100 }
	local filtered = Stats.removeOutliers(outlier_data, 2.0)
	assert(#filtered < #outlier_data, "Should remove outliers")

	-- Test summarize
	local summary = Stats.summarize(data, { include_ci = true, percentiles = { 50, 90 } })
	assert(summary.count == 5, "Summary count should be 5")
	assert(summary.mean == 3, "Summary mean should be 3")
	assert(summary.ci_lo ~= nil, "Should include CI when requested")
	assert(summary.percentiles ~= nil, "Should include percentiles when requested")

	print("All tests passed")
end
