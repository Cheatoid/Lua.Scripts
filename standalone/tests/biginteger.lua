-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for biginteger.lua.
-- Run from this directory:
--   lua biginteger.lua
--   luajit biginteger.lua

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
				clean .. ".lua",
					root .. clean .. "/init.lua" }
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
