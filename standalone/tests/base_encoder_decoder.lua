-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for base_encoder_decoder.lua.
-- Run from this directory:
--   lua base_encoder_decoder.lua
--   luajit base_encoder_decoder.lua

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
local lib = require "base_encoder_decoder"
-- Bridging: file-locals used by tests mapped to module exports.
local Base = lib

if true then
	-- 1. Functional API usage (Simple)
	local hex_data = Base.encode("Hello World!", Base.BASE16)
	print("Hex Encoded:", hex_data) -- Output: 48656C6C6F20576F726C6421
	local decoded_hex = Base.decode(hex_data, Base.BASE16)
	print("Hex Decoded:", decoded_hex) -- Output: Hello World!
	-- 2. Object-Oriented API (Performant for repeated calls)
	local b58 = Base.new(Base.BASE58)
	local addr = b58.encode("\0\0SomeData")
	print("Base58 Encoded:", addr)  -- Output: 11SomeData (leading zeros become '1')
	local original = b58.decode(addr)
	print("Base58 Decoded:", original) -- Output: \0\0SomeData
	-- 3. Arbitrary Base (e.g. Base 5)
	local b5 = Base.new("01234")
	print("Base5:", b5.encode("A")) -- 'A' is 65. 65 = 2*25 + 3*5 + 0.
	-- Logic:
	-- 65 / 5 = 13 r 0
	-- 13 / 5 = 2 r 3
	-- 2  / 5 = 0 r 2
	-- Result: "230"
end
