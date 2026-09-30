-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for runner.lua.
-- Run from this directory:
--   lua runner.lua
--   luajit runner.lua

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
