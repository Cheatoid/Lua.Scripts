-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for suite.lua.
-- Run from this directory:
--   lua suite.lua
--   luajit suite.lua

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
