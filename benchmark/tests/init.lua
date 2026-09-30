-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for benchmark.
-- Run from this directory:
--   lua init.lua
--   luajit init.lua

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
local lib = require "init"
-- Bridging: file-locals used by tests mapped to module exports.
local benchmark = lib

if true then
	-- Test that all submodules are loaded
	assert(benchmark.config, "Should have config submodule")
	assert(benchmark.timer, "Should have timer submodule")
	assert(benchmark.stats, "Should have stats submodule")
	assert(benchmark.formatter, "Should have formatter submodule")
	assert(benchmark.runner, "Should have runner submodule")
	assert(benchmark.suite, "Should have suite submodule")

	-- Test time shortcut
	local elapsed, result = benchmark.time(function(x)
		return x * 2
	end, nil, 21)
	assert(elapsed >= 0, "Elapsed should be non-negative")
	assert(result == 42, "Should return function result")

	-- Test factory functions
	local suite = benchmark.createSuite({ silent = true })
	assert(suite, "Should create suite")
	local runner = benchmark.createRunner({ silent = true })
	assert(runner, "Should create runner")
	local timer = benchmark.createTimer()
	assert(timer, "Should create timer")

	-- Test set/get time func
	local orig = benchmark.getTimeFunc()
	local called = false
	benchmark.setTimeFunc(function()
		called = true
		return 0
	end)
	assert(benchmark.getTimeFunc() ~= orig, "Should set new time func")
	benchmark.setTimeFunc(orig) -- restore

	print("All tests passed")
end
