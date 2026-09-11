-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for defer.lua.
-- Run from this directory:
--   lua defer.lua
--   luajit defer.lua

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
local Defer = require "defer"

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
	local function expect_error(fn, pattern)
		local ok, err = pcall(fn)
		assert(not ok, "expected error but got success: " .. tostring(err))
		if pattern then
			assert(tostring(err):find(pattern, 1, true),
				"error message does not contain '" .. pattern .. "': " .. tostring(err))
		end
	end
	print("[defer] testing...")

	-- has_close / mode consistency
	test("has_close returns boolean", function()
		local v = Defer.has_close()
		assert(type(v) == "boolean")
	end)

	test("defer returns handle with valid mode", function()
		local h = Defer.defer(function() end)
		assert(type(h) == "table")
		local m = Defer.mode(h)
		assert(m == "close" or m == "gc" or m == "manual", "unexpected mode: " .. tostring(m))
		assert(h._mode == m)
		if Defer.has_close() then
			assert(m == "close", "has_close true but mode is " .. tostring(m))
		end
		-- cleanup probe handle so it does not fire later
		Defer.cancel(h)
		assert(Defer.is_done(h) == true)
	end)

	test("handle exposes methods", function()
		local h = Defer.defer(function() end)
		assert(type(h.run_now) == "function")
		assert(type(h.cancel) == "function")
		assert(type(h.is_done) == "function")
		assert(type(h.tag) == "function")
		Defer.cancel(h)
	end)

	-- defer validation
	test("defer requires function", function()
		expect_error(function() Defer.defer(nil) end, "fn must be a function")
		expect_error(function() Defer.defer("x") end, "fn must be a function")
		expect_error(function() Defer.defer(42) end, "fn must be a function")
	end)

	test("defer_tagged requires string tag and function", function()
		expect_error(function() Defer.defer_tagged(nil, function() end) end, "tag must be a string")
		expect_error(function() Defer.defer_tagged(42, function() end) end, "tag must be a string")
		expect_error(function() Defer.defer_tagged("t", nil) end, "fn must be a function")
		expect_error(function() Defer.defer_tagged("t", "x") end, "fn must be a function")
	end)

	-- initial state
	test("fresh handle is not done and untagged", function()
		local h = Defer.defer(function() end)
		assert(Defer.is_done(h) == false)
		assert(h:is_done() == false)
		assert(Defer.get_tag(h) == nil)
		assert(h:tag() == nil)
		Defer.cancel(h)
	end)

	test("defer_tagged stores tag", function()
		local h = Defer.defer_tagged("conn", function() end)
		assert(Defer.get_tag(h) == "conn")
		assert(h:tag() == "conn")
		Defer.cancel(h)
	end)

	-- run_now
	test("run_now invokes callback once with return value", function()
		local calls = 0
		local h = Defer.defer(function()
			calls = calls + 1
			return "ok"
		end)
		local r = Defer.run_now(h)
		assert(r == "ok")
		assert(calls == 1)
		assert(Defer.is_done(h) == true)
		-- second run is a no-op
		local r2 = Defer.run_now(h)
		assert(r2 == nil)
		assert(calls == 1)
		Defer.cancel(h) -- safe after done
	end)

	test("method run_now matches static", function()
		local calls = 0
		local h = Defer.defer(function()
			calls = calls + 1
			return 7
		end)
		assert(h:run_now() == 7)
		assert(calls == 1)
		assert(h:run_now() == nil)
		assert(calls == 1)
	end)

	test("run_now forwards varargs including nils", function()
		local got_n, a, b, c
		local h = Defer.defer(function(x, y, z)
			got_n = select("#", x, y, z)
			a, b, c = x, y, z
		end, 1, nil, 3)
		Defer.run_now(h)
		assert(got_n == 3, "expected 3 args, got " .. tostring(got_n))
		assert(a == 1 and b == nil and c == 3)
	end)

	test("run_now with no extra args", function()
		local ran = false
		local h = Defer.defer(function()
			ran = true
			return 123
		end)
		assert(Defer.run_now(h) == 123)
		assert(ran == true)
	end)

	test("tag survives run_now", function()
		local h = Defer.defer_tagged("keep", function() return 1 end)
		Defer.run_now(h)
		assert(Defer.get_tag(h) == "keep")
		assert(h:tag() == "keep")
	end)

	-- cancel
	test("cancel prevents callback", function()
		local calls = 0
		local h = Defer.defer(function() calls = calls + 1 end)
		Defer.cancel(h)
		assert(calls == 0)
		assert(Defer.is_done(h) == true)
		assert(Defer.run_now(h) == nil)
		assert(calls == 0)
	end)

	test("method cancel matches static", function()
		local calls = 0
		local h = Defer.defer(function() calls = calls + 1 end)
		h:cancel()
		assert(calls == 0)
		assert(h:is_done() == true)
		h:cancel() -- second cancel is safe
		assert(calls == 0)
	end)

	test("tag survives cancel", function()
		local h = Defer.defer_tagged("t2", function() end)
		Defer.cancel(h)
		assert(Defer.get_tag(h) == "t2")
	end)

	-- invalid handles
	test("invalid handles error", function()
		expect_error(function() Defer.run_now(nil) end, "invalid handle")
		expect_error(function() Defer.cancel(nil) end, "invalid handle")
		expect_error(function() Defer.is_done(nil) end, "invalid handle")
		expect_error(function() Defer.get_tag(nil) end, "invalid handle")
		expect_error(function() Defer.mode(nil) end, "invalid handle")
		expect_error(function() Defer.run_now({}) end, "was not created by Defer")
		expect_error(function() Defer.cancel({ _state = {} }) end, "was not created by Defer")
		expect_error(function() Defer.is_done(42) end, "invalid handle")
		expect_error(function() Defer.mode("x") end, "invalid handle")
	end)

	test("foreign table with valid metatable shape still rejected", function()
		local fake = setmetatable({ _state = { done = false } }, { __index = {} })
		expect_error(function() Defer.run_now(fake) end, "was not created by Defer")
	end)

	-- collect
	test("collect runs without error", function()
		local ok, err = pcall(Defer.collect)
		assert(ok, tostring(err))
	end)

	-- gc backend: finalizer runs exactly once via collect
	test("gc finalizer runs pending cleanup on collect (gc backend only)", function()
		local probe = Defer.defer(function() end)
		local m = Defer.mode(probe)
		Defer.cancel(probe)
		if m ~= "gc" then return end -- close/manual backends: nothing to assert here
		local fired = 0
		local function make()
			Defer.defer(function() fired = fired + 1 end)
		end
		make()
		Defer.collect()
		assert(fired == 1, "expected gc to fire once, got " .. tostring(fired))
	end)

	test("gc does not double-run after manual run_now", function()
		local probe = Defer.defer(function() end)
		local m = Defer.mode(probe)
		Defer.cancel(probe)
		if m ~= "gc" then return end
		local fired = 0
		local function make()
			local h = Defer.defer(function() fired = fired + 1 end)
			Defer.run_now(h)
			assert(fired == 1)
		end
		make()
		Defer.collect()
		assert(fired == 1, "run_now handle must not fire again on gc, got " .. tostring(fired))
	end)

	test("gc does not run cancelled handle", function()
		local probe = Defer.defer(function() end)
		local m = Defer.mode(probe)
		Defer.cancel(probe)
		if m ~= "gc" then return end
		local fired = 0
		local function make()
			local h = Defer.defer(function() fired = fired + 1 end)
			Defer.cancel(h)
		end
		make()
		Defer.collect()
		assert(fired == 0, "cancelled handle must not fire on gc, got " .. tostring(fired))
	end)

	-- <close> backend via dynamically compiled chunk (parse-safe on old Lua)
	test("<close> scope exit runs cleanup", function()
		if not Defer.has_close() then return end
		local loader = load or loadstring
		assert(type(loader) == "function")
		local code = table.concat({
			"local Defer = ...",
			"local fired = 0",
			"do",
			"  local c <close> = Defer.defer(function() fired = fired + 1 end)",
			"  assert(Defer.is_done(c) == false)",
			"end",
			"assert(fired == 1, 'close did not fire')",
			"return true",
		}, "\n")
		local chunk, err = loader(code)
		assert(chunk ~= nil, "failed to compile <close> probe: " .. tostring(err))
		assert(chunk(Defer) == true)
	end)

	test("<close> scope exit is no-op after run_now", function()
		if not Defer.has_close() then return end
		local loader = load or loadstring
		local code = table.concat({
			"local Defer = ...",
			"local fired = 0",
			"do",
			"  local c <close> = Defer.defer(function() fired = fired + 1 end)",
			"  Defer.run_now(c)",
			"  assert(fired == 1)",
			"end",
			"assert(fired == 1, 'close double-fired: ' .. tostring(fired))",
			"return true",
		}, "\n")
		local chunk, err = loader(code)
		assert(chunk ~= nil, "failed to compile <close> probe: " .. tostring(err))
		assert(chunk(Defer) == true)
	end)

	test("<close> scope exit skips cancelled handle", function()
		if not Defer.has_close() then return end
		local loader = load or loadstring
		local code = table.concat({
			"local Defer = ...",
			"local fired = 0",
			"do",
			"  local c <close> = Defer.defer(function() fired = fired + 1 end)",
			"  Defer.cancel(c)",
			"end",
			"assert(fired == 0, 'cancelled close fired: ' .. tostring(fired))",
			"return true",
		}, "\n")
		local chunk, err = loader(code)
		assert(chunk ~= nil, "failed to compile <close> probe: " .. tostring(err))
		assert(chunk(Defer) == true)
	end)

	print(string_format("[defer] %d/%d tests passed (%d failed)", passed, total, failed))
	assert(failed == 0, string_format("%d test(s) failed", failed))
end
