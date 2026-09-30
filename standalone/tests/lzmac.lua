-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for lzmac.lua.
-- Run from this directory:
--   lua lzmac.lua
--   luajit lzmac.lua

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
local lib = require "lzmac"
-- Bridging: file-locals used by tests mapped to module exports.
local compress = lib.compress
local string_char = string.char
local table_concat = table.concat
-- TODO(manual): the following were file-locals with no direct export;
-- verify and export or inline as needed: d

if true then
	local total, passed, failed = 0, 0, 0
	local function test(name, fn)
		total = total + 1
		local ok, err = pcall(fn)
		if ok then
			passed = passed + 1
		else
			failed = failed + 1
			print(string.format("  FAIL  %s: %s", name, tostring(err)))
		end
	end

	-- Test LZMA compression
	test("compress valid LZMA data", function()
		local byte_str =
		"93 0 0 1 0 62 0 0 0 0 0 0 0 0 32 144 132 118 186 138 117 207 180 13 178 232 159 19 135 248 5 87 125 236 173 238 116 120 0 242 66 235 152 102 11 21 21 45 203 35 190 212 185 154 198 32 127 124 106 189 38 245 64 115 240 253 165 25 16 99 62 172 104 197 155 37 255 219 0 254 63 136 0"
		local expected = {}
		for byte in byte_str:gmatch("%d+") do
			expected[#expected + 1] = string_char(tonumber(byte))
		end
		expected = table_concat(expected)
		local compressed = compress("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")
		assert(#compressed == #expected)
		assert(compressed == expected)
	end)

	test("compress empty data", function()
		assert(compress("") == "")
	end)

	test("compress short data", function()
		local compressed = compress("a")
		assert(#compressed > 0)
	end)

	print(string.format("[lzmac] %d/%d tests passed (%d failed)", passed, total, failed))
	assert(failed == 0, string.format("%d test(s) failed", failed))
end
