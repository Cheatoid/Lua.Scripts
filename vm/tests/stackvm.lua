-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for StackVM.
-- Run from this directory:
--   lua stackvm.lua
--   luajit stackvm.lua

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
local lib = require "stackvm"
local StackVM = lib
local bitwise = require "bitwise"
local string_find = string.find

if true then
	local L = StackVM.new(256)

	-- Test 1: Basic arithmetic operations
	do
		local a = StackVM.asm()
		a:emit("PUSHN", 2)
		a:emit("PUSHN", 3)
		a:emit("ADD")
		a:emit("PUSHN", 4)
		a:emit("MUL")
		a:emit("HALT")
		local proto = a:proto()
		local ok, err = StackVM.run(L, proto, { protected = true })
		assert(ok, "Test 1 failed: " .. tostring(err))
		assert(L:gettop() == 1, "Test 1 failed: stack top should be 1")
		assert(L:checknumber(-1) == 20, "Test 1 failed: result should be 20")
		L:pop(1)
	end

	-- Test 2: Subtraction and division
	do
		local a = StackVM.asm()
		a:emit("PUSHN", 10)
		a:emit("PUSHN", 2)
		a:emit("SUB")
		a:emit("PUSHN", 4)
		a:emit("DIV")
		a:emit("HALT")
		local proto = a:proto()
		local ok, err = StackVM.run(L, proto, { protected = true })
		assert(ok, "Test 2 failed: " .. tostring(err))
		assert(L:checknumber(-1) == 2, "Test 2 failed: result should be 2")
		L:pop(1)
	end

	-- Test 3: Modulo and power
	do
		local a = StackVM.asm()
		a:emit("PUSHN", 17)
		a:emit("PUSHN", 5)
		a:emit("MOD")
		a:emit("PUSHN", 2)
		a:emit("POW")
		a:emit("HALT")
		local proto = a:proto()
		local ok, err = StackVM.run(L, proto, { protected = true })
		assert(ok, "Test 3 failed: " .. tostring(err))
		assert(L:checknumber(-1) == 4, "Test 3 failed: result should be 4")
		L:pop(1)
	end

	-- Test 4: Comparison operations (EQ)
	do
		local a = StackVM.asm()
		a:emit("PUSHN", 5)
		a:emit("PUSHN", 5)
		a:emit("EQ")
		a:emit("HALT")
		local proto = a:proto()
		local ok, err = StackVM.run(L, proto, { protected = true })
		assert(ok, "Test 4 failed: " .. tostring(err))
		assert(L:checkboolean(-1) == true, "Test 4 failed: result should be true")
		L:pop(1)
	end

	-- Test 5: Comparison operations (LT)
	do
		local a = StackVM.asm()
		a:emit("PUSHN", 3)
		a:emit("PUSHN", 5)
		a:emit("LT")
		a:emit("HALT")
		local proto = a:proto()
		local ok, err = StackVM.run(L, proto, { protected = true })
		assert(ok, "Test 5 failed: " .. tostring(err))
		assert(L:checkboolean(-1) == true, "Test 5 failed: result should be true")
		L:pop(1)
	end

	-- Test 6: Logical NOT
	do
		local a = StackVM.asm()
		a:emit("PUSHB", 1)
		a:emit("NOT")
		a:emit("HALT")
		local proto = a:proto()
		local ok, err = StackVM.run(L, proto, { protected = true })
		assert(ok, "Test 6 failed: " .. tostring(err))
		assert(L:checkboolean(-1) == false, "Test 6 failed: result should be false")
		L:pop(1)
	end

	-- Test 7: Bitwise operations (BAND)
	do
		local a = StackVM.asm()
		a:emit("PUSHN", 12)
		a:emit("PUSHN", 10)
		a:emit("BAND")
		a:emit("HALT")
		local proto = a:proto()
		local ok, err = StackVM.run(L, proto, { protected = true })
		assert(ok, "Test 7 failed: " .. tostring(err))
		assert(L:checknumber(-1) == 8, "Test 7 failed: result should be 8")
		L:pop(1)
	end

	-- Test 8: Bitwise operations (BOR)
	do
		local a = StackVM.asm()
		a:emit("PUSHN", 12)
		a:emit("PUSHN", 10)
		a:emit("BOR")
		a:emit("HALT")
		local proto = a:proto()
		local ok, err = StackVM.run(L, proto, { protected = true })
		assert(ok, "Test 8 failed: " .. tostring(err))
		assert(L:checknumber(-1) == 14, "Test 8 failed: result should be 14")
		L:pop(1)
	end

	-- Test 9: Bitwise operations (BXOR)
	do
		local a = StackVM.asm()
		a:emit("PUSHN", 12)
		a:emit("PUSHN", 10)
		a:emit("BXOR")
		a:emit("HALT")
		local proto = a:proto()
		local ok, err = StackVM.run(L, proto, { protected = true })
		assert(ok, "Test 9 failed: " .. tostring(err))
		assert(L:checknumber(-1) == 6, "Test 9 failed: result should be 6")
		L:pop(1)
	end

	-- Test 10: Bitwise operations (BNOT)
	do
		local a = StackVM.asm()
		a:emit("PUSHN", 5)
		a:emit("BNOT")
		a:emit("HALT")
		local proto = a:proto()
		local ok, err = StackVM.run(L, proto, { protected = true })
		assert(ok, "Test 10 failed: " .. tostring(err))
		local result = L:checknumber(-1)
		assert(result == 4294967290, "Test 10 failed: result should be 4294967290")
		assert(bitwise.toint(result) == -6, "Test 10 failed: signed result should be -6")
		L:pop(1)
	end

	-- Test 11: Bitwise shift left (BSHL)
	do
		local a = StackVM.asm()
		a:emit("PUSHN", 5)
		a:emit("PUSHN", 2)
		a:emit("BSHL")
		a:emit("HALT")
		local proto = a:proto()
		local ok, err = StackVM.run(L, proto, { protected = true })
		assert(ok, "Test 11 failed: " .. tostring(err))
		assert(L:checknumber(-1) == 20, "Test 11 failed: result should be 20")
		L:pop(1)
	end

	-- Test 12: Bitwise shift right (BSHR)
	do
		local a = StackVM.asm()
		a:emit("PUSHN", 20)
		a:emit("PUSHN", 2)
		a:emit("BSHR")
		a:emit("HALT")
		local proto = a:proto()
		local ok, err = StackVM.run(L, proto, { protected = true })
		assert(ok, "Test 12 failed: " .. tostring(err))
		assert(L:checknumber(-1) == 5, "Test 12 failed: result should be 5")
		L:pop(1)
	end

	-- Test 13: Jump operations (JMP)
	do
		local a = StackVM.asm()
		a:emit("PUSHN", 1)
		a:emit("JMP", "skip")
		a:emit("PUSHN", 2)
		a:emit("HALT")
		a:label("skip")
		a:emit("PUSHN", 3)
		a:emit("HALT")
		local proto = a:proto()
		local ok, err = StackVM.run(L, proto, { protected = true })
		assert(ok, "Test 13 failed: " .. tostring(err))
		assert(L:checknumber(-1) == 3, "Test 13 failed: result should be 3")
		L:pop(1)
	end

	-- Test 14: Conditional jump (JMPT)
	do
		local a = StackVM.asm()
		a:emit("PUSHB", 1)
		a:emit("JMPT", "skip")
		a:emit("PUSHN", 2)
		a:emit("HALT")
		a:label("skip")
		a:emit("PUSHN", 3)
		a:emit("HALT")
		local proto = a:proto()
		local ok, err = StackVM.run(L, proto, { protected = true })
		assert(ok, "Test 14 failed: " .. tostring(err))
		assert(L:checknumber(-1) == 3, "Test 14 failed: result should be 3")
		L:pop(1)
	end

	-- Test 15: Conditional jump false (JMPF)
	do
		local a = StackVM.asm()
		a:emit("PUSHB", 0)
		a:emit("JMPF", "skip")
		a:emit("PUSHN", 2)
		a:emit("HALT")
		a:label("skip")
		a:emit("PUSHN", 3)
		a:emit("HALT")
		local proto = a:proto()
		local ok, err = StackVM.run(L, proto, { protected = true })
		assert(ok, "Test 15 failed: " .. tostring(err))
		assert(L:checknumber(-1) == 3, "Test 15 failed: result should be 3")
		L:pop(1)
	end

	-- Test 16: Global variable operations
	do
		local a = StackVM.asm()
		local K_X = a:const("x")
		local K_Y = a:const("y")
		a:emit("PUSHN", 42)
		a:emit("SETG", K_X)
		a:emit("GETG", K_X)
		a:emit("HALT")
		local proto = a:proto()
		local ok, err = StackVM.run(L, proto, { protected = true })
		assert(ok, "Test 16 failed: " .. tostring(err))
		assert(L:checknumber(-1) == 42, "Test 16 failed: result should be 42")
		assert(L.globals.x == 42, "Test 16 failed: global x should be 42")
		L:pop(1)
	end

	-- Test 17: Stack operations (DUP)
	do
		local a = StackVM.asm()
		a:emit("PUSHN", 5)
		a:emit("DUP", 0)
		a:emit("ADD")
		a:emit("HALT")
		local proto = a:proto()
		local ok, err = StackVM.run(L, proto, { protected = true })
		assert(ok, "Test 17 failed: " .. tostring(err))
		assert(L:checknumber(-1) == 10, "Test 17 failed: result should be 10")
		L:pop(1)
	end

	-- Test 18: Stack operations (SWAP)
	do
		local a = StackVM.asm()
		a:emit("PUSHN", 1)
		a:emit("PUSHN", 2)
		a:emit("SWAP")
		a:emit("POP", 1)
		a:emit("HALT")
		local proto = a:proto()
		local ok, err = StackVM.run(L, proto, { protected = true })
		assert(ok, "Test 18 failed: " .. tostring(err))
		assert(L:checknumber(-1) == 2, "Test 18 failed: result should be 2")
		L:pop(1)
	end

	-- Test 19: Call host function
	do
		local called = false
		L:register("testfn", function(n)
			called = true
			return n * 2
		end)
		local a = StackVM.asm()
		local K_FN = a:const("testfn")
		a:emit("GETG", K_FN)
		a:emit("PUSHN", 5)
		a:emit("CALL", 1, 1)
		a:emit("HALT")
		local proto = a:proto()
		local ok, err = StackVM.run(L, proto, { protected = true })
		assert(ok, "Test 19 failed: " .. tostring(err))
		assert(called, "Test 19 failed: function should have been called")
		assert(L:checknumber(-1) == 10, "Test 19 failed: result should be 10")
		L:pop(1)
	end

	-- Test 20: Hook functionality
	do
		local hook_called = false
		L:sethook(function(event)
			hook_called = true
		end, "crl", 1)
		local a = StackVM.asm()
		a:emit("PUSHN", 1)
		a:emit("HALT")
		local proto = a:proto()
		local ok, err = StackVM.run(L, proto, { protected = true })
		assert(ok, "Test 20 failed: " .. tostring(err))
		assert(hook_called, "Test 20 failed: hook should have been called")
		L:sethook(nil, "", 0)
		L:pop(1)
	end

	-- Test 21: DEBUG opcode
	do
		local debug_hook_called = false
		L:sethook(function(event)
			if event == "debug" then
				debug_hook_called = true
			end
		end, "", 0)
		local a = StackVM.asm()
		a:emit("PUSHN", 1)
		a:emit("DEBUG")
		a:emit("HALT")
		local proto = a:proto()
		local ok, err = StackVM.run(L, proto, { protected = true })
		assert(ok, "Test 21 failed: " .. tostring(err))
		assert(debug_hook_called, "Test 21 failed: debug hook should have been called")
		L:sethook(nil, "", 0)
		L:pop(1)
	end

	-- Test 22: Constant folding optimization
	do
		local a = StackVM.asm()
		a:emit("PUSHN", 2)
		a:emit("PUSHN", 3)
		a:emit("ADD")
		a:emit("PUSHN", 4)
		a:emit("MUL")
		a:emit("HALT")
		local proto = a:proto()
		local optimized = StackVM.optimize(proto, { constant_folding = true })
		local ok, err = StackVM.run(L, optimized, { protected = true })
		assert(ok, "Test 22 failed: " .. tostring(err))
		assert(L:checknumber(-1) == 20, "Test 22 failed: result should be 20")
		L:pop(1)
	end

	-- Test 23: NEG operation
	do
		local a = StackVM.asm()
		a:emit("PUSHN", 5)
		a:emit("NEG")
		a:emit("HALT")
		local proto = a:proto()
		local ok, err = StackVM.run(L, proto, { protected = true })
		assert(ok, "Test 23 failed: " .. tostring(err))
		assert(L:checknumber(-1) == -5, "Test 23 failed: result should be -5")
		L:pop(1)
	end

	-- Test 24: LE comparison
	do
		local a = StackVM.asm()
		a:emit("PUSHN", 3)
		a:emit("PUSHN", 5)
		a:emit("LE")
		a:emit("HALT")
		local proto = a:proto()
		local ok, err = StackVM.run(L, proto, { protected = true })
		assert(ok, "Test 24 failed: " .. tostring(err))
		assert(L:checkboolean(-1) == true, "Test 24 failed: result should be true")
		L:pop(1)
	end

	-- Test 25: PUSHB (boolean true)
	do
		local a = StackVM.asm()
		a:emit("PUSHB", 1)
		a:emit("HALT")
		local proto = a:proto()
		local ok, err = StackVM.run(L, proto, { protected = true })
		assert(ok, "Test 25 failed: " .. tostring(err))
		assert(L:checkboolean(-1) == true, "Test 25 failed: result should be true")
		L:pop(1)
	end

	-- Test 26: PUSHB (boolean false)
	do
		local a = StackVM.asm()
		a:emit("PUSHB", 0)
		a:emit("HALT")
		local proto = a:proto()
		local ok, err = StackVM.run(L, proto, { protected = true })
		assert(ok, "Test 26 failed: " .. tostring(err))
		assert(L:checkboolean(-1) == false, "Test 26 failed: result should be false")
		L:pop(1)
	end

	-- Test 27: PUSHNIL
	do
		local a = StackVM.asm()
		a:emit("PUSHNIL")
		a:emit("HALT")
		local proto = a:proto()
		local ok, err = StackVM.run(L, proto, { protected = true })
		assert(ok, "Test 27 failed: " .. tostring(err))
		assert(L:isnil(-1), "Test 27 failed: result should be nil")
		L:pop(1)
	end

	-- Test 28: DUP with different indices
	do
		local a = StackVM.asm()
		a:emit("PUSHN", 1)
		a:emit("PUSHN", 2)
		a:emit("PUSHN", 3)
		a:emit("DUP", 1)
		a:emit("ADD")
		a:emit("HALT")
		local proto = a:proto()
		local ok, err = StackVM.run(L, proto, { protected = true })
		assert(ok, "Test 28 failed: " .. tostring(err))
		assert(L:checknumber(-1) == 5, "Test 28 failed: result should be 5")
		L:pop(1)
	end

	-- Test 29: Multiple global variables
	do
		local a = StackVM.asm()
		local K_X = a:const("x")
		local K_Y = a:const("y")
		a:emit("PUSHN", 10)
		a:emit("SETG", K_X)
		a:emit("PUSHN", 20)
		a:emit("SETG", K_Y)
		a:emit("GETG", K_X)
		a:emit("GETG", K_Y)
		a:emit("ADD")
		a:emit("HALT")
		local proto = a:proto()
		local ok, err = StackVM.run(L, proto, { protected = true })
		assert(ok, "Test 29 failed: " .. tostring(err))
		assert(L:checknumber(-1) == 30, "Test 29 failed: result should be 30")
		L:pop(1)
	end

	-- Test 30: Nested jumps
	do
		local a = StackVM.asm()
		a:emit("PUSHN", 1)
		a:emit("JMP", "outer")
		a:label("inner")
		a:emit("PUSHN", 99)
		a:emit("HALT")
		a:label("outer")
		a:emit("PUSHN", 2)
		a:emit("JMP", "end")
		a:emit("PUSHN", 3)
		a:emit("JMP", "inner")
		a:label("end")
		a:emit("HALT")
		local proto = a:proto()
		local ok, err = StackVM.run(L, proto, { protected = true })
		assert(ok, "Test 30 failed: " .. tostring(err))
		assert(L:checknumber(-1) == 2, "Test 30 failed: result should be 2")
		L:pop(1)
	end

	-- Test 31: CALL with multiple arguments
	do
		local call_count = 0
		local result_sum = 0
		L:register("multargs", function(a, b, c)
			call_count = call_count + 1
			result_sum = a + b + c
			return result_sum
		end)
		local a = StackVM.asm()
		local K_FN = a:const("multargs")
		a:emit("GETG", K_FN)
		a:emit("PUSHN", 1)
		a:emit("PUSHN", 2)
		a:emit("PUSHN", 3)
		a:emit("CALL", 3, 1)
		a:emit("HALT")
		local proto = a:proto()
		local ok, err = StackVM.run(L, proto, { protected = true })
		assert(ok, "Test 31 failed: " .. tostring(err))
		assert(call_count == 1, "Test 31 failed: function should have been called once")
		assert(L:checknumber(-1) == 6, "Test 31 failed: result should be 6")
		L:pop(1)
	end

	-- Test 32: Complex arithmetic chain
	do
		local a = StackVM.asm()
		a:emit("PUSHN", 2)
		a:emit("PUSHN", 3)
		a:emit("MUL")
		a:emit("PUSHN", 4)
		a:emit("ADD")
		a:emit("PUSHN", 5)
		a:emit("SUB")
		a:emit("HALT")
		local proto = a:proto()
		local ok, err = StackVM.run(L, proto, { protected = true })
		assert(ok, "Test 32 failed: " .. tostring(err))
		assert(L:checknumber(-1) == 5, "Test 32 failed: result should be 5")
		L:pop(1)
	end

	-- Test 33: Bitwise operations chain
	do
		local a = StackVM.asm()
		a:emit("PUSHN", 15)
		a:emit("PUSHN", 7)
		a:emit("BAND")
		a:emit("PUSHN", 8)
		a:emit("BOR")
		a:emit("HALT")
		local proto = a:proto()
		local ok, err = StackVM.run(L, proto, { protected = true })
		assert(ok, "Test 33 failed: " .. tostring(err))
		assert(L:checknumber(-1) == 15, "Test 33 failed: result should be 15")
		L:pop(1)
	end

	-- Test 34: Comparison chain
	do
		local a = StackVM.asm()
		a:emit("PUSHN", 5)
		a:emit("PUSHN", 5)
		a:emit("EQ")
		a:emit("PUSHN", 10)
		a:emit("EQ")
		a:emit("HALT")
		local proto = a:proto()
		local ok, err = StackVM.run(L, proto, { protected = true })
		assert(ok, "Test 34 failed: " .. tostring(err))
		assert(L:checkboolean(-1) == false, "Test 34 failed: result should be false")
		L:pop(1)
	end

	-- Test 35: POP multiple elements
	do
		local a = StackVM.asm()
		a:emit("PUSHN", 1)
		a:emit("PUSHN", 2)
		a:emit("PUSHN", 3)
		a:emit("POP", 2)
		a:emit("HALT")
		local proto = a:proto()
		local ok, err = StackVM.run(L, proto, { protected = true })
		assert(ok, "Test 35 failed: " .. tostring(err))
		assert(L:checknumber(-1) == 1, "Test 35 failed: result should be 1")
		L:pop(1)
	end

	-- Test 36: Conditional jump with false condition
	do
		local a = StackVM.asm()
		a:emit("PUSHB", 0)
		a:emit("JMPT", "skip")
		a:emit("PUSHN", 1)
		a:emit("HALT")
		a:label("skip")
		a:emit("PUSHN", 2)
		a:emit("HALT")
		local proto = a:proto()
		local ok, err = StackVM.run(L, proto, { protected = true })
		assert(ok, "Test 36 failed: " .. tostring(err))
		assert(L:checknumber(-1) == 1, "Test 36 failed: result should be 1")
		L:pop(1)
	end

	-- Test 37: Conditional jump false with true condition
	do
		local a = StackVM.asm()
		a:emit("PUSHB", 1)
		a:emit("JMPF", "skip")
		a:emit("PUSHN", 1)
		a:emit("HALT")
		a:label("skip")
		a:emit("PUSHN", 2)
		a:emit("HALT")
		local proto = a:proto()
		local ok, err = StackVM.run(L, proto, { protected = true })
		assert(ok, "Test 37 failed: " .. tostring(err))
		assert(L:checknumber(-1) == 1, "Test 37 failed: result should be 1")
		L:pop(1)
	end

	-- Test 38: Power operation with zero exponent
	do
		local a = StackVM.asm()
		a:emit("PUSHN", 5)
		a:emit("PUSHN", 0)
		a:emit("POW")
		a:emit("HALT")
		local proto = a:proto()
		local ok, err = StackVM.run(L, proto, { protected = true })
		assert(ok, "Test 38 failed: " .. tostring(err))
		assert(L:checknumber(-1) == 1, "Test 38 failed: result should be 1")
		L:pop(1)
	end

	-- Test 39: Modulo operation with same values
	do
		local a = StackVM.asm()
		a:emit("PUSHN", 10)
		a:emit("PUSHN", 5)
		a:emit("MOD")
		a:emit("HALT")
		local proto = a:proto()
		local ok, err = StackVM.run(L, proto, { protected = true })
		assert(ok, "Test 39 failed: " .. tostring(err))
		assert(L:checknumber(-1) == 0, "Test 39 failed: result should be 0")
		L:pop(1)
	end

	-- Test 40: BSHL with zero shift
	do
		local a = StackVM.asm()
		a:emit("PUSHN", 5)
		a:emit("PUSHN", 0)
		a:emit("BSHL")
		a:emit("HALT")
		local proto = a:proto()
		local ok, err = StackVM.run(L, proto, { protected = true })
		assert(ok, "Test 40 failed: " .. tostring(err))
		assert(L:checknumber(-1) == 5, "Test 40 failed: result should be 5")
		L:pop(1)
	end

	-- Test 41: BSHR with zero shift
	do
		local a = StackVM.asm()
		a:emit("PUSHN", 5)
		a:emit("PUSHN", 0)
		a:emit("BSHR")
		a:emit("HALT")
		local proto = a:proto()
		local ok, err = StackVM.run(L, proto, { protected = true })
		assert(ok, "Test 41 failed: " .. tostring(err))
		assert(L:checknumber(-1) == 5, "Test 41 failed: result should be 5")
		L:pop(1)
	end

	-- Test 42: Multiple SWAP operations
	do
		local a = StackVM.asm()
		a:emit("PUSHN", 1)
		a:emit("PUSHN", 2)
		a:emit("PUSHN", 3)
		a:emit("SWAP")
		a:emit("SWAP")
		a:emit("POP", 1)
		a:emit("HALT")
		local proto = a:proto()
		local ok, err = StackVM.run(L, proto, { protected = true })
		assert(ok, "Test 42 failed: " .. tostring(err))
		assert(L:checknumber(-1) == 2, "Test 42 failed: result should be 2")
		L:pop(1)
	end

	-- Test 43: XOR with same values
	do
		local a = StackVM.asm()
		a:emit("PUSHN", 10)
		a:emit("PUSHN", 10)
		a:emit("BXOR")
		a:emit("HALT")
		local proto = a:proto()
		local ok, err = StackVM.run(L, proto, { protected = true })
		assert(ok, "Test 43 failed: " .. tostring(err))
		assert(L:checknumber(-1) == 0, "Test 43 failed: result should be 0")
		L:pop(1)
	end

	-- Test 44: Global variable overwrite
	do
		local a = StackVM.asm()
		local K_X = a:const("z")
		a:emit("PUSHN", 10)
		a:emit("SETG", K_X)
		a:emit("PUSHN", 20)
		a:emit("SETG", K_X)
		a:emit("GETG", K_X)
		a:emit("HALT")
		local proto = a:proto()
		local ok, err = StackVM.run(L, proto, { protected = true })
		assert(ok, "Test 44 failed: " .. tostring(err))
		assert(L:checknumber(-1) == 20, "Test 44 failed: result should be 20")
		L:pop(1)
	end

	-- Test 45: Empty stack operations
	do
		local a = StackVM.asm()
		a:emit("PUSHN", 42)
		a:emit("POP", 1)
		a:emit("PUSHN", 100)
		a:emit("HALT")
		local proto = a:proto()
		local ok, err = StackVM.run(L, proto, { protected = true })
		assert(ok, "Test 45 failed: " .. tostring(err))
		assert(L:checknumber(-1) == 100, "Test 45 failed: result should be 100")
		L:pop(1)
	end

	-- Test 46: Comparison with equal values (LE)
	do
		local a = StackVM.asm()
		a:emit("PUSHN", 5)
		a:emit("PUSHN", 5)
		a:emit("LE")
		a:emit("HALT")
		local proto = a:proto()
		local ok, err = StackVM.run(L, proto, { protected = true })
		assert(ok, "Test 46 failed: " .. tostring(err))
		assert(L:checkboolean(-1) == true, "Test 46 failed: result should be true")
		L:pop(1)
	end

	-- Test 47: Division resulting in fraction
	do
		local a = StackVM.asm()
		a:emit("PUSHN", 10)
		a:emit("PUSHN", 4)
		a:emit("DIV")
		a:emit("HALT")
		local proto = a:proto()
		local ok, err = StackVM.run(L, proto, { protected = true })
		assert(ok, "Test 47 failed: " .. tostring(err))
		assert(L:checknumber(-1) == 2.5, "Test 47 failed: result should be 2.5")
		L:pop(1)
	end

	-- Test 48: Disassembler basic test
	do
		local a = StackVM.asm()
		a:emit("PUSHN", 42)
		a:emit("HALT")
		local proto = a:proto()
		local disasm = StackVM.disassemble(proto)
		assert(type(disasm) == "string", "Test 48 failed: disassemble should return string")
		assert(string_find(disasm, "PUSHN") ~= nil, "Test 48 failed: disassembly should contain PUSHN")
		assert(string_find(disasm, "HALT") ~= nil, "Test 48 failed: disassembly should contain HALT")
	end

	-- Test 49: Disassembler with operands
	do
		local a = StackVM.asm()
		a:emit("PUSHN", 10)
		a:emit("PUSHN", 20)
		a:emit("ADD")
		a:emit("HALT")
		local proto = a:proto()
		local disasm = StackVM.disassemble(proto)
		assert(string_find(disasm, "10") ~= nil, "Test 49 failed: disassembly should contain operand")
		assert(string_find(disasm, "ADD") ~= nil, "Test 49 failed: disassembly should contain ADD")
	end

	-- Test 50: Edge case - negative numbers
	do
		local a = StackVM.asm()
		a:emit("PUSHN", -10)
		a:emit("PUSHN", -5)
		a:emit("ADD")
		a:emit("HALT")
		local proto = a:proto()
		local ok, err = StackVM.run(L, proto, { protected = true })
		assert(ok, "Test 50 failed: " .. tostring(err))
		assert(L:checknumber(-1) == -15, "Test 50 failed: result should be -15")
		L:pop(1)
	end

	-- Test 51: Edge case - large numbers
	do
		local a = StackVM.asm()
		a:emit("PUSHN", 1000000)
		a:emit("PUSHN", 2000000)
		a:emit("ADD")
		a:emit("HALT")
		local proto = a:proto()
		local ok, err = StackVM.run(L, proto, { protected = true })
		assert(ok, "Test 51 failed: " .. tostring(err))
		assert(L:checknumber(-1) == 3000000, "Test 51 failed: result should be 3000000")
		L:pop(1)
	end

	-- Test 52: Edge case - single instruction
	do
		local a = StackVM.asm()
		a:emit("PUSHN", 999)
		a:emit("HALT")
		local proto = a:proto()
		local ok, err = StackVM.run(L, proto, { protected = true })
		assert(ok, "Test 52 failed: " .. tostring(err))
		assert(L:checknumber(-1) == 999, "Test 52 failed: result should be 999")
		L:pop(1)
	end

	-- Test 53: Edge case - multiple NOT operations
	do
		local a = StackVM.asm()
		a:emit("PUSHB", 1)
		a:emit("NOT")
		a:emit("NOT")
		a:emit("NOT")
		a:emit("HALT")
		local proto = a:proto()
		local ok, err = StackVM.run(L, proto, { protected = true })
		assert(ok, "Test 53 failed: " .. tostring(err))
		assert(L:checkboolean(-1) == false, "Test 53 failed: result should be false")
		L:pop(1)
	end

	-- Test 54: Edge case - NEG on negative number
	do
		local a = StackVM.asm()
		a:emit("PUSHN", -5)
		a:emit("NEG")
		a:emit("HALT")
		local proto = a:proto()
		local ok, err = StackVM.run(L, proto, { protected = true })
		assert(ok, "Test 54 failed: " .. tostring(err))
		assert(L:checknumber(-1) == 5, "Test 54 failed: result should be 5")
		L:pop(1)
	end

	-- Test 55: Edge case - BNOT on zero
	do
		local a = StackVM.asm()
		a:emit("PUSHN", 0)
		a:emit("BNOT")
		a:emit("HALT")
		local proto = a:proto()
		local ok, err = StackVM.run(L, proto, { protected = true })
		assert(ok, "Test 55 failed: " .. tostring(err))
		local result = L:checknumber(-1)
		assert(result == 4294967295, "Test 55 failed: result should be 4294967295")
		L:pop(1)
	end

	-- Test 56: Edge case - comparison with negative numbers
	do
		local a = StackVM.asm()
		a:emit("PUSHN", -10)
		a:emit("PUSHN", -5)
		a:emit("LT")
		a:emit("HALT")
		local proto = a:proto()
		local ok, err = StackVM.run(L, proto, { protected = true })
		assert(ok, "Test 56 failed: " .. tostring(err))
		assert(L:checkboolean(-1) == true, "Test 56 failed: result should be true")
		L:pop(1)
	end

	-- Test 57: Edge case - XOR with zero
	do
		local a = StackVM.asm()
		a:emit("PUSHN", 10)
		a:emit("PUSHN", 0)
		a:emit("BXOR")
		a:emit("HALT")
		local proto = a:proto()
		local ok, err = StackVM.run(L, proto, { protected = true })
		assert(ok, "Test 57 failed: " .. tostring(err))
		assert(L:checknumber(-1) == 10, "Test 57 failed: result should be 10")
		L:pop(1)
	end

	-- Test 58: Edge case - OR with zero
	do
		local a = StackVM.asm()
		a:emit("PUSHN", 10)
		a:emit("PUSHN", 0)
		a:emit("BOR")
		a:emit("HALT")
		local proto = a:proto()
		local ok, err = StackVM.run(L, proto, { protected = true })
		assert(ok, "Test 58 failed: " .. tostring(err))
		assert(L:checknumber(-1) == 10, "Test 58 failed: result should be 10")
		L:pop(1)
	end

	-- Test 59: Edge case - AND with all ones
	do
		local a = StackVM.asm()
		a:emit("PUSHN", 0xFFFFFFFF)
		a:emit("PUSHN", 10)
		a:emit("BAND")
		a:emit("HALT")
		local proto = a:proto()
		local ok, err = StackVM.run(L, proto, { protected = true })
		assert(ok, "Test 59 failed: " .. tostring(err))
		assert(L:checknumber(-1) == 10, "Test 59 failed: result should be 10")
		L:pop(1)
	end

	-- Test 60: Edge case - power with negative exponent
	do
		local a = StackVM.asm()
		a:emit("PUSHN", 2)
		a:emit("PUSHN", -1)
		a:emit("POW")
		a:emit("HALT")
		local proto = a:proto()
		local ok, err = StackVM.run(L, proto, { protected = true })
		assert(ok, "Test 60 failed: " .. tostring(err))
		assert(L:checknumber(-1) == 0.5, "Test 60 failed: result should be 0.5")
		L:pop(1)
	end

	-- Test 61: Edge case - modulo with negative numbers
	do
		local a = StackVM.asm()
		a:emit("PUSHN", -10)
		a:emit("PUSHN", 3)
		a:emit("MOD")
		a:emit("HALT")
		local proto = a:proto()
		local ok, err = StackVM.run(L, proto, { protected = true })
		assert(ok, "Test 61 failed: " .. tostring(err))
		local result = L:checknumber(-1)
		assert(result == 2, "Test 61 failed: result should be 2")
		L:pop(1)
	end

	-- Test 62: Disassembler with jumps
	do
		local a = StackVM.asm()
		a:emit("PUSHN", 1)
		a:emit("JMP", "skip")
		a:emit("PUSHN", 99)
		a:emit("HALT")
		a:label("skip")
		a:emit("PUSHN", 2)
		a:emit("HALT")
		local proto = a:proto()
		local disasm = StackVM.disassemble(proto)
		assert(string_find(disasm, "JMP") ~= nil, "Test 62 failed: disassembly should contain JMP")
		assert(string_find(disasm, "->") ~= nil, "Test 62 failed: disassembly should show jump target")
	end

	-- Test 63: Disassembler with constants
	do
		local a = StackVM.asm()
		local K_X = a:const("test_var")
		a:emit("GETG", K_X)
		a:emit("HALT")
		local proto = a:proto()
		local disasm = StackVM.disassemble(proto)
		assert(string_find(disasm, "GETG") ~= nil, "Test 63 failed: disassembly should contain GETG")
		assert(string_find(disasm, "test_var") ~= nil, "Test 63 failed: disassembly should contain constant name")
	end

	-- Test 64: Edge case - empty program (just HALT)
	do
		local a = StackVM.asm()
		a:emit("HALT")
		local proto = a:proto()
		local ok, err = StackVM.run(L, proto, { protected = true })
		assert(ok, "Test 64 failed: " .. tostring(err))
	end

	-- Test 65: Edge case - multiplication by zero
	do
		local a = StackVM.asm()
		a:emit("PUSHN", 42)
		a:emit("PUSHN", 0)
		a:emit("MUL")
		a:emit("HALT")
		local proto = a:proto()
		local ok, err = StackVM.run(L, proto, { protected = true })
		assert(ok, "Test 65 failed: " .. tostring(err))
		assert(L:checknumber(-1) == 0, "Test 65 failed: result should be 0")
		L:pop(1)
	end

	-- Test 66: Edge case - division by one
	do
		local a = StackVM.asm()
		a:emit("PUSHN", 42)
		a:emit("PUSHN", 1)
		a:emit("DIV")
		a:emit("HALT")
		local proto = a:proto()
		local ok, err = StackVM.run(L, proto, { protected = true })
		assert(ok, "Test 66 failed: " .. tostring(err))
		assert(L:checknumber(-1) == 42, "Test 66 failed: result should be 42")
		L:pop(1)
	end

	-- Test 67: Edge case - power of one
	do
		local a = StackVM.asm()
		a:emit("PUSHN", 42)
		a:emit("PUSHN", 1)
		a:emit("POW")
		a:emit("HALT")
		local proto = a:proto()
		local ok, err = StackVM.run(L, proto, { protected = true })
		assert(ok, "Test 67 failed: " .. tostring(err))
		assert(L:checknumber(-1) == 42, "Test 67 failed: result should be 42")
		L:pop(1)
	end

	-- Test 68: Edge case - shift by zero (BSHL)
	do
		local a = StackVM.asm()
		a:emit("PUSHN", 42)
		a:emit("PUSHN", 0)
		a:emit("BSHL")
		a:emit("HALT")
		local proto = a:proto()
		local ok, err = StackVM.run(L, proto, { protected = true })
		assert(ok, "Test 68 failed: " .. tostring(err))
		assert(L:checknumber(-1) == 42, "Test 68 failed: result should be 42")
		L:pop(1)
	end

	-- Test 69: Edge case - shift by zero (BSHR)
	do
		local a = StackVM.asm()
		a:emit("PUSHN", 42)
		a:emit("PUSHN", 0)
		a:emit("BSHR")
		a:emit("HALT")
		local proto = a:proto()
		local ok, err = StackVM.run(L, proto, { protected = true })
		assert(ok, "Test 69 failed: " .. tostring(err))
		assert(L:checknumber(-1) == 42, "Test 69 failed: result should be 42")
		L:pop(1)
	end

	-- Test 70: Edge case - SWAP same values
	do
		local a = StackVM.asm()
		a:emit("PUSHN", 5)
		a:emit("PUSHN", 5)
		a:emit("SWAP")
		a:emit("POP", 1)
		a:emit("HALT")
		local proto = a:proto()
		local ok, err = StackVM.run(L, proto, { protected = true })
		assert(ok, "Test 70 failed: " .. tostring(err))
		assert(L:checknumber(-1) == 5, "Test 70 failed: result should be 5")
		L:pop(1)
	end

	print("All tests passed!")
end
