-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for timer.lua.
-- Run from this directory:
--   lua timer.lua
--   luajit timer.lua

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
