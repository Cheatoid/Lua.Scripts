-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for hash.lua.
-- Run from this directory:
--   lua hash.lua
--   luajit hash.lua

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
local lib = require "hash"
-- Bridging: file-locals used by tests mapped to module exports.
local M = lib
-- TODO(manual): the following were file-locals with no direct export;
-- verify and export or inline as needed: func, len

if true then
	local tests = {
		{
			name = "FNV-1a32",
			func = M.fnv1a32,
			cases = {
				{ input = "",              expect = 0x811c9dc5 },
				{ input = "a",             expect = 0xe40c292c },
				{ input = "hello",         expect = 0x4f9f2cab },
				{ input = "Hello, World!", expect = 0x5aecf734 },
			},
		},
		{
			name = "Murmur3-32",
			func = M.murmur3_32,
			cases = {
				{ input = "",              expect = 0x00000000 },
				{ input = "hello",         expect = 0x248bfa47 },
				{ input = "Hello, World!", expect = 0x2352d5c7 },
			},
		},
		{
			name = "xxHash32",
			func = M.xxh32,
			cases = {
				{ input = "",              expect = 0x02cc5d05 },
				{ input = "hello",         expect = 0xfb0077f9 },
				{ input = "Hello, World!", expect = 0x4007de50 },
			},
		},
		{
			name = "CRC32",
			func = M.crc32,
			cases = {
				{ input = "",              expect = 0x00000000 },
				{ input = "hello",         expect = 0x3610a686 },
				{ input = "Hello, World!", expect = 0xec4ac3d0 },
			},
		},
	}

	local passed = 0
	local total = 0

	for _, test in next, tests do
		print(string.format("\nTesting %s:", test.name))

		for _, case in next, test.cases do
			total = total + 1
			local result = test.func(case.input)

			if result == case.expect then
				print(string.format("  '%s' -> 0x%08x", case.input, result))
				passed = passed + 1
			else
				print(string.format(
					"  '%s' -> got 0x%08x, expected 0x%08x",
					case.input,
					result,
					case.expect
				))
			end
		end
	end

	print(string.format("\nUnit tests completed: %d/%d passed", passed, total))
	print(passed == total and "All tests passed!" or "Some tests failed!")
	assert(passed == total, "Some tests failed!")

	-- Benchmarks
	local clock = os.clock

	local bench_algos = {
		{ name = "FNV-1a32",   func = M.fnv1a32 },
		{ name = "Murmur3-32", func = M.murmur3_32 },
		{ name = "xxHash32",   func = M.xxh32 },
		{ name = "CRC32",      func = M.crc32 },
	}

	local bench_sizes = {
		{ label = "32 B",  len = 32 },
		{ label = "256 B", len = 256 },
		{ label = "1 KB",  len = 1024 },
	}

	local ITERATIONS = 200

	print("\n--- Benchmarks ---")
	print(string.format("  iterations per size: %d", ITERATIONS))

	for _, algo in next, bench_algos do
		print(string.format("\n  %s:", algo.name))

		for _, sz in next, bench_sizes do
			local str = string.rep("A", sz.len)

			local t0 = clock()
			for _ = 1, ITERATIONS do
				algo.func(str)
			end
			local elapsed = clock() - t0

			local total_bytes = sz.len * ITERATIONS
			local throughput_mb = total_bytes / elapsed / (1024 * 1024)
			local ops_per_sec = ITERATIONS / elapsed

			print(string.format(
				"    %-6s  %0.4fs  %0.1f MB/s  %.0f ops/s",
				sz.label, elapsed, throughput_mb, ops_per_sec
			))
		end
	end

	print("\nBenchmarks completed.")
end
