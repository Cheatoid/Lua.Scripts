-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for formatter.lua.
-- Run from this directory:
--   lua formatter.lua
--   luajit formatter.lua

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
