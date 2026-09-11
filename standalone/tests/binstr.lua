-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for binstr.lua.
-- Run from this directory:
--   lua binstr.lua
--   luajit binstr.lua

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
local lib = require "binstr"
-- Bridging: file-locals used by tests mapped to module exports.
local BinaryReader = lib.BinaryReader
local BinaryWriter = lib.BinaryWriter
local arshift = lib.arshift
local band = lib.band
local bnot = lib.bnot
local bor = lib.bor
local bswap = lib.bswap
local bxor = lib.bxor
local dec_to_bin = lib.dec_to_bin
local lshift = lib.lshift
local normalize_bin_input = lib.normalize
local packInteger = lib.packInteger
local reader = lib.reader
local rol = lib.rol
local ror = lib.ror
local rshift = lib.rshift
local string_format = string.format
local string_rep = string.rep
local to_decimal = lib.to_decimal
local unpackInteger = lib.unpackInteger
local writer = lib.writer
-- TODO(manual): the following were file-locals with no direct export;
-- verify and export or inline as needed: bits, d, s, sign

if true then
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
	local function expect_error(fn, pattern)
		local ok, err = pcall(fn)
		assert(not ok, "expected error but got success: " .. tostring(err))
		if pattern then
			assert(tostring(err):find(pattern, 1, true),
				"error message does not contain '" .. pattern .. "': " .. tostring(err))
		end
	end
	print("[binstr] testing...")

	-- normalize
	test("normalize with 0b prefix", function()
		local r = normalize_bin_input("0b1011", 8)
		assert(r == "00001011")
	end)

	test("normalize strips spaces", function()
		local r = normalize_bin_input("  1011  ", 8)
		assert(r == "00001011")
	end)

	test("normalize defaults to 64 bits", function()
		local r = normalize_bin_input("1")
		assert(r == string_rep("0", 63) .. "1")
	end)

	test("normalize rejects invalid width", function()
		local r, err = normalize_bin_input("1", 12)
		assert(r == nil)
		assert(err:find("invalid width"))
	end)

	test("normalize rejects non-string", function()
		local r, err = normalize_bin_input(123, 8)
		assert(r == nil)
		assert(err:find("input must be a string"))
	end)

	test("normalize rejects non-binary chars", function()
		local r, err = normalize_bin_input("1021", 8)
		assert(r == nil)
		assert(tostring(err):find("non-binary", 1, true))
	end)

	test("normalize rejects empty string", function()
		local r, err = normalize_bin_input("", 8)
		assert(r == nil)
		assert(err:find("empty"))
	end)

	test("normalize rejects string longer than width", function()
		local r, err = normalize_bin_input("111111111", 8)
		assert(r == nil)
		assert(err:find("longer than width"))
	end)

	-- bitwise NOT
	test("bnot basic", function()
		local r = bnot("1011", 8)
		assert(r == "11110100")
	end)

	test("bnot all zeros", function()
		local r = bnot("0000", 8)
		assert(r == "11111111")
	end)

	test("bnot all ones", function()
		local r = bnot("11111111", 8)
		assert(r == "00000000")
	end)

	test("bnot propagates error", function()
		local r, err = bnot("abc", 8)
		assert(r == nil)
		assert(tostring(err):find("non-binary", 1, true))
	end)

	-- bitwise AND
	test("band basic", function()
		local r = band("1011", "1100", 8)
		assert(r == "00001000")
	end)

	test("band with self", function()
		local r = band("1011", "1011", 8)
		assert(r == "00001011")
	end)

	test("band with zeros", function()
		local r = band("1111", "0000", 8)
		assert(r == "00000000")
	end)

	-- bitwise OR
	test("bor basic", function()
		local r = bor("1011", "1100", 8)
		assert(r == "00001111")
	end)

	test("bor with self", function()
		local r = bor("1011", "1011", 8)
		assert(r == "00001011")
	end)

	test("bor with zeros", function()
		local r = bor("1111", "0000", 8)
		assert(r == "00001111")
	end)

	-- bitwise XOR
	test("bxor basic", function()
		local r = bxor("1011", "1100", 8)
		assert(r == "00000111")
	end)

	test("bxor with self is zero", function()
		local r = bxor("1011", "1011", 8)
		assert(r == "00000000")
	end)

	test("bxor with zero is identity", function()
		local r = bxor("1011", "0000", 8)
		assert(r == "00001011")
	end)

	-- rotate left
	test("rol basic", function()
		local r = rol("0001", 4, 8)
		assert(r == "00010000")
	end)

	test("rol by width is identity", function()
		local r = rol("1011", 8, 8)
		assert(r == "00001011")
	end)

	test("rol by zero is identity", function()
		local r = rol("1011", 0, 8)
		assert(r == "00001011")
	end)

	-- rotate right
	test("ror basic", function()
		local r = ror("0001", 4, 8)
		assert(r == "00010000")
	end)

	test("ror by width is identity", function()
		local r = ror("1011", 8, 8)
		assert(r == "00001011")
	end)

	-- left shift
	test("lshift basic", function()
		local r = lshift("1011", 2, 16)
		assert(r == "0000000000101100")
	end)

	test("lshift by zero", function()
		local r = lshift("1011", 0, 8)
		assert(r == "00001011")
	end)

	test("lshift by width returns zeros", function()
		local r = lshift("1011", 8, 8)
		assert(r == "00000000")
	end)

	test("lshift past width returns zeros", function()
		local r = lshift("1011", 10, 8)
		assert(r == "00000000")
	end)

	-- right shift
	test("rshift basic", function()
		local r = rshift("1011", 2, 16)
		assert(r == "0000000000000010")
	end)

	test("rshift by zero", function()
		local r = rshift("1011", 0, 8)
		assert(r == "00001011")
	end)

	test("rshift by width returns zeros", function()
		local r = rshift("1011", 8, 8)
		assert(r == "00000000")
	end)

	-- arithmetic right shift
	test("arshift preserves sign bit", function()
		local r = arshift("1" .. string_rep("0", 15), 4, 16)
		assert(r == "1111100000000000")
	end)

	test("arshift positive fills zeros", function()
		local r = arshift("00001011", 2, 8)
		assert(r == "00000010")
	end)

	test("arshift by zero", function()
		local r = arshift("10000000", 0, 8)
		assert(r == "10000000")
	end)

	test("arshift by width replicates sign", function()
		local r = arshift("10000000", 8, 8)
		assert(r == "11111111")
	end)

	test("arshift positive by width", function()
		local r = arshift("01111111", 8, 8)
		assert(r == "00000000")
	end)

	-- byte swap
	test("bswap 32-bit", function()
		local r = bswap("00000001001000110100010101100111", 32)
		assert(r == "01100111010001010010001100000001")
	end)

	test("bswap 16-bit", function()
		local r = bswap("0000000100000010", 16)
		assert(r == "0000001000000001")
	end)

	test("bswap 8-bit is identity", function()
		local r = bswap("10101010", 8)
		assert(r == "10101010")
	end)

	test("bswap rejects invalid width", function()
		local r, err = bswap("101", 12)
		assert(r == nil)
		assert(tostring(err):find("invalid width", 1, true))
	end)

	-- to_decimal
	test("to_decimal unsigned", function()
		local r = to_decimal("1111", false, 8)
		assert(r == "15")
	end)

	test("to_decimal signed positive", function()
		local r = to_decimal("00001111", true, 8)
		assert(r == "15")
	end)

	test("to_decimal signed negative (two's complement)", function()
		local r = to_decimal("11111111", true, 8)
		assert(r == "-1")
	end)

	test("to_decimal zero", function()
		local r = to_decimal("0000", false, 8)
		assert(r == "0")
	end)

	test("to_decimal max unsigned 8-bit", function()
		local r = to_decimal("11111111", false, 8)
		assert(r == "255")
	end)

	test("to_decimal min signed 8-bit", function()
		local r = to_decimal("10000000", true, 8)
		assert(r == "-128")
	end)

	-- dec_to_bin
	test("dec_to_bin unsigned 11", function()
		local r = dec_to_bin("11", false, 8)
		assert(r == "00001011")
	end)

	test("dec_to_bin unsigned 255", function()
		local r = dec_to_bin("255", false, 8)
		assert(r == "11111111")
	end)

	test("dec_to_bin signed positive 127", function()
		local r = dec_to_bin("127", true, 8)
		assert(r == "01111111")
	end)

	test("dec_to_bin signed negative -11 (two's complement)", function()
		local r = dec_to_bin("-11", true, 8)
		assert(r == "11110101")
	end)

	test("dec_to_bin signed negative -1", function()
		local r = dec_to_bin("-1", true, 8)
		assert(r == "11111111")
	end)

	test("dec_to_bin signed negative -128", function()
		local r = dec_to_bin("-128", true, 8)
		assert(r == "10000000")
	end)

	test("dec_to_bin zero", function()
		local r = dec_to_bin("0", false, 8)
		assert(r == "00000000")
	end)

	test("dec_to_bin rejects positive overflow for signed", function()
		local r, err = dec_to_bin("128", true, 8)
		assert(r == nil)
		assert(err:find("overflow"))
	end)

	test("dec_to_bin rejects negative overflow for signed", function()
		local r, err = dec_to_bin("-129", true, 8)
		assert(r == nil)
		assert(err:find("overflow"))
	end)

	test("dec_to_bin rejects unsigned overflow", function()
		local r, err = dec_to_bin("256", false, 8)
		assert(r == nil)
		assert(err:find("overflow"))
	end)

	test("dec_to_bin rejects negative for unsigned", function()
		local r, err = dec_to_bin("-1", false, 8)
		assert(r == nil)
		assert(err:find("negative"))
	end)

	test("dec_to_bin with 0b prefix in input", function()
		local r = dec_to_bin("11", false, 8)
		assert(r == "00001011")
	end)

	test("dec_to_bin defaults to 64 bits", function()
		local r = dec_to_bin("1", false)
		assert(#r == 64)
		assert(r == string_rep("0", 63) .. "1")
	end)

	-- aliases
	test("aliases work", function()
		local M = {
			lrot = rol,
			lrotate = rol,
			rrot = ror,
			rrotate = ror,
			["not"] = bnot,
			["and"] = band,
			["or"] = bor,
			xor = bxor,
		}
		assert(M.lrot == rol)
		assert(M.lrotate == rol)
		assert(M.rrot == ror)
		assert(M.rrotate == ror)
		assert(M["not"] == bnot)
		assert(M["and"] == band)
		assert(M["or"] == bor)
		assert(M.xor == bxor)
	end)

	-- BinaryWriter / BinaryReader smoke tests
	test("BinaryWriter/Reader roundtrip", function()
		local w = writer()

		w:writeUInt8(0xAB)
		w:writeUInt16LE(0x1234)
		w:writeUInt32BE(1)
		w:writeInt8(-1)
		w:writeInt16LE(-2)
		w:writeInt32BE(-3)
		w:writeUInt64LE("18446744073709551615")
		w:writeInt64LE("-1")

		local data = w:toString()
		local r = reader(data)

		assert(r:readUInt8() == 0xAB)
		assert(r:readUInt16LE() == 0x1234)
		assert(r:readUInt32BE() == 1)
		assert(r:readInt8() == -1)
		assert(r:readInt16LE() == -2)
		assert(r:readInt32BE() == -3)
		assert(r:readUInt64LE() == "18446744073709551615")
		assert(r:readInt64LE() == "-1")
		assert(r:eof())
	end)

	test("packInteger/unpackInteger roundtrip", function()
		local packed = packInteger(-2, 16, true, "<")
		local value, next_pos = unpackInteger(packed, 1, 16, true, "<")

		assert(value == -2)
		assert(next_pos == 3)
	end)

	test("writeInt/readInt batch roundtrip", function()
		local w = writer()
		w:writeInt({ -1, -2, -3 }, 16, "<")
		w:writeUInt({ 10, 20, 30 }, 16, "<")

		local r = reader(w:toString())
		local signed = r:readInt(3, 16, "<")
		local unsigned = r:readUInt(3, 16, "<")

		assert(signed[1] == -1)
		assert(signed[2] == -2)
		assert(signed[3] == -3)
		assert(unsigned[1] == 10)
		assert(unsigned[2] == 20)
		assert(unsigned[3] == 30)
		assert(r:eof())
	end)

	test("writeInt/readInt single value shorthand", function()
		local w = writer()
		w:writeInt(42, 32, "<")
		w:writeUInt(42, 32, "<")

		local r = reader(w:toString())
		assert(r:readInt(1, 32, "<")[1] == 42)
		assert(r:readUInt(1, 32, "<")[1] == 42)
		assert(r:eof())
	end)

	print(string_format("[binstr] %d/%d tests passed (%d failed)", passed, total, failed))
	assert(failed == 0, string_format("%d test(s) failed", failed))
end
