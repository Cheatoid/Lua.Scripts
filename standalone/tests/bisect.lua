-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for bisect.lua.
-- Run from this directory:
--   lua bisect.lua
--   luajit bisect.lua

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
local lib = require "bisect"
-- Bridging: file-locals used by tests mapped to module exports.
local bisect_left = lib.left
local bisect_right = lib.right
local insort_left = lib.insort_left
local insort_right = lib.insort_right

if true then
	local string_format = string.format
	local total, passed, failed = 0, 0, 0
	local function test(name, fn)
		total = total + 1
		local ok, err = pcall(fn)
		if ok then
			passed = passed + 1
		else
			failed = failed + 1
			print(string_format("  FAIL  %s: %s", name, tostring(err)))
		end
	end
	print("[bisect] testing...")

	-- bisect_left
	test("bisect_left basic", function()
		local arr = { 1, 2, 3, 3, 3, 4, 5 }
		assert(bisect_left(arr, 3) == 3)
		assert(bisect_left(arr, 1) == 1)
		assert(bisect_left(arr, 5) == 7)
		assert(bisect_left(arr, 0) == 1)
		assert(bisect_left(arr, 6) == 8)
	end)

	test("bisect_left with sub-range", function()
		local arr = { 1, 2, 3, 3, 3, 4, 5 }
		assert(bisect_left(arr, 3, 4, 7) == 4)
	end)

	test("bisect_left empty table", function()
		assert(bisect_left({}, 1) == 1)
	end)

	-- bisect_right
	test("bisect_right basic", function()
		local arr = { 1, 2, 3, 3, 3, 4, 5 }
		assert(bisect_right(arr, 3) == 6)
		assert(bisect_right(arr, 1) == 2)
		assert(bisect_right(arr, 5) == 8)
		assert(bisect_right(arr, 0) == 1)
		assert(bisect_right(arr, 6) == 8)
	end)

	test("bisect_right with sub-range", function()
		local arr = { 1, 2, 3, 3, 3, 4, 5 }
		assert(bisect_right(arr, 3, 4, 7) == 6)
	end)

	test("bisect_right empty table", function()
		assert(bisect_right({}, 1) == 1)
	end)

	-- insort_left
	test("insort_left basic", function()
		local arr = { 1, 2, 4, 5 }
		local idx = insort_left(arr, 3)
		assert(idx == 3)
		assert(#arr == 5)
		assert(arr[1] == 1 and arr[2] == 2 and arr[3] == 3 and arr[4] == 4 and arr[5] == 5)
	end)

	test("insort_left duplicate inserts leftmost", function()
		local arr = { 1, 3, 3, 5 }
		local idx = insort_left(arr, 3)
		assert(idx == 2)
		assert(#arr == 5)
		assert(arr[2] == 3 and arr[3] == 3)
	end)

	test("insort_left into empty table", function()
		local arr = {}
		insort_left(arr, 42)
		assert(#arr == 1)
		assert(arr[1] == 42)
	end)

	-- insort_right
	test("insort_right basic", function()
		local arr = { 1, 2, 4, 5 }
		local idx = insort_right(arr, 3)
		assert(idx == 3)
		assert(#arr == 5)
		assert(arr[1] == 1 and arr[2] == 2 and arr[3] == 3 and arr[4] == 4 and arr[5] == 5)
	end)

	test("insort_right duplicate inserts rightmost", function()
		local arr = { 1, 3, 3, 5 }
		local idx = insort_right(arr, 3)
		assert(idx == 4)
		assert(#arr == 5)
		assert(arr[3] == 3 and arr[4] == 3)
	end)

	test("insort_right into empty table", function()
		local arr = {}
		insort_right(arr, 42)
		assert(#arr == 1)
		assert(arr[1] == 42)
	end)

	-- aliases
	test("aliases work", function()
		local M = { bisect = bisect_right, insort = insort_right }
		assert(M.bisect == bisect_right)
		assert(M.insort == insort_right)
	end)

	print(string_format("[bisect] %d/%d passed", passed, total))
	if failed > 0 then
		print(string_format("[bisect] %d FAILED", failed))
	end
end
