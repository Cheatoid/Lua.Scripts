-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for lzmad.lua.
-- Run from this directory:
--   lua lzmad.lua
--   luajit lzmad.lua

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
local lib = require "lzmad"
-- Bridging: file-locals used by tests mapped to module exports.
local decompress = lib.decompress
local string_char = string.char
local table_concat = table.concat

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

	-- Test LZMA decompression
	test("decompress valid LZMA data", function()
		local byte_str =
		"93 0 0 1 0 62 0 0 0 0 0 0 0 0 32 144 132 118 186 138 117 207 180 13 178 232 159 19 135 248 5 87 125 236 173 238 116 120 0 242 66 235 152 102 11 21 21 45 203 35 190 212 185 154 198 32 127 124 106 189 38 245 64 115 240 253 165 25 16 99 62 172 104 197 147 89 42 148"
		local compressed_data = {}
		for byte in byte_str:gmatch("%d+") do
			compressed_data[#compressed_data + 1] = string_char(tonumber(byte))
		end
		compressed_data = table_concat(compressed_data)
		local decompressed = decompress(compressed_data)
		assert(#decompressed == 62)
		assert(decompressed == "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")
	end)

	test("decompress empty data", function()
		assert(decompress("") == "")
	end)

	test("decompress too short data", function()
		assert(decompress("short") == "")
	end)

	print(string.format("[lzmad] %d/%d tests passed (%d failed)", passed, total, failed))
	assert(failed == 0, string.format("%d test(s) failed", failed))
end
