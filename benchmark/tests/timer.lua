-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for timer.lua.
-- Run from this directory:
--   lua timer.lua
--   luajit timer.lua

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
local lib = require "timer"
-- Bridging: file-locals used by tests mapped to module exports.
local Timer = lib
-- TODO(manual): the following were file-locals with no direct export;
-- verify and export or inline as needed: result

if true then
	-- Test basic timing
	local timer = Timer.new()
	assert(not timer.started, "Timer should not be started initially")
	timer:start()
	assert(timer.started, "Timer should be started after start()")
	local elapsed = timer:stop()
	assert(timer.stopped, "Timer should be stopped after stop()")
	assert(elapsed >= 0, "Elapsed should be non-negative")

	-- Test reset
	timer:reset()
	assert(not timer.started, "Timer should not be started after reset")
	assert(not timer.stopped, "Timer should not be stopped after reset")

	-- Test lap functionality
	timer:start()
	local lap1 = timer:lap("first")
	assert(lap1 >= 0, "Lap time should be non-negative")
	assert(#timer.laps == 1, "Should have one lap recorded")
	assert(timer.laps[1].name == "first", "Lap should have correct name")
	timer:stop()

	-- Test static measure
	local meas_elapsed, meas_result = Timer.measure(function() return 42 end)
	assert(meas_elapsed >= 0, "Measured elapsed should be non-negative")
	assert(meas_result == 42, "Measure should return function result")

	print("All tests passed")
end
