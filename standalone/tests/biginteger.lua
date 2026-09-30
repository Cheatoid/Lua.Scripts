-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for biginteger.lua.
-- Run from this directory:
--   lua biginteger.lua
--   luajit biginteger.lua

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
local lib = require "biginteger"
-- Bridging: file-locals used by tests mapped to module exports.
local BigInt_from_any = lib.new
local BigInteger_eval = lib.eval
-- TODO(manual): the following were file-locals with no direct export;
-- verify and export or inline as needed: n

if true then
	_G.bigint = _G.bigint or BigInt_from_any
	print("--- Testing BigInteger Core ---")
	print(bigint "845398498491984798879546897527456087516548987461" + 1)
	local a = bigint "123456789123456789123456789"
	local b = bigint "987654321987654321"
	print("A: " .. (a))
	print("B: " .. (b))
	print("A + B: " .. (a + b))
	print("A - B: " .. (a - b))
	print("A * B: " .. (a * b))
	print("A / B: " .. (a / b))
	print("A ^ 23: " .. (a ^ 23))
	print("\n--- Testing String Expression Parser ---")
	local expr1 = "100 + 200 * 300" -- 60,100
	local res1 = BigInteger_eval(expr1)
	print(expr1 .. " = " .. res1)
	local expr2 = "(10000000000 + 2222222222) * -5" -- -61,111,111,110
	local res2 = BigInteger_eval(expr2)
	print(expr2 .. " = " .. res2)
	local expr3 = "-50 + 150" -- 100
	local res3 = BigInteger_eval(expr3)
	print(expr3 .. " = " .. res3)
	local huge = "-12345678901234567890 * -(98765432109876543210 * -1)"
	local resHuge = BigInteger_eval(huge)
	print(huge .. " = " .. resHuge)
end
