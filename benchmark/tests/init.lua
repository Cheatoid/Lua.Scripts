-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for benchmark.
-- Run from this directory:
--   lua init.lua
--   luajit init.lua

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
