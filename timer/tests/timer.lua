-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for timer.lua.
-- Run from this directory:
--   lua timer.lua
--   luajit timer.lua

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
local lib = require "timer"
-- Bridging: file-locals used by tests mapped to module exports.
local timer = lib
local Manager = lib.Manager
-- TODO(manual): the following were file-locals with no direct export;
-- verify and export or inline as needed: args, autostart

if true then
	-- Deterministic mock clock: tests never touch os.clock.
	local now = 0
	local function clock()
		return now
	end
	local function advance(manager, dt)
		now = now + dt
		return manager:tick(now)
	end

	-- Basic create / tick / repetitions.
	do
		local m = Manager.new(clock)
		local calls = 0
		m:create("a", 1, 2, function() calls = calls + 1 end)
		assert(m:exists("a"), "timer should exist after create")
		assert(m:reps_left("a") == 2, "reps_left should be 2 initially")
		assert(advance(m, 0.5) == 0, "should not fire before delay")
		assert(calls == 0, "callback should not run early")
		assert(advance(m, 0.5) == 1, "should fire at t=1")
		assert(calls == 1, "callback should run once")
		assert(m:reps_left("a") == 1, "reps_left should decrement")
		assert(advance(m, 1) == 1, "should fire second time at t=2")
		assert(calls == 2, "callback should run twice")
		assert(not m:exists("a") or m:get("a"):is_finished(), "named timer should finish (kept) after reps")
		assert(advance(m, 5) == 0, "finished timer should not fire again")
	end

	-- Infinite repetitions and args forwarding.
	do
		now = 0
		local m = Manager.new(clock)
		local got = {}
		m:create("inf", 0.5, 0, function(a, b) got[#got + 1] = a + b end, 2, 3)
		assert(advance(m, 0.5) == 1 and got[1] == 5, "infinite timer should fire with args")
		assert(advance(m, 0.5) == 1 and #got == 2, "infinite timer should keep firing")
		assert(m:reps_left("inf") == 0, "infinite reps_left stays 0")
	end

	-- Simple auto-removes after one fire.
	do
		now = 0
		local m = Manager.new(clock)
		local n = 0
		local t = m:simple(1, function() n = n + 1 end)
		assert(t:is_running(), "simple should autostart")
		assert(advance(m, 1) == 1 and n == 1, "simple should fire once")
		assert(not m:exists(t:get_id()), "simple should auto-remove")
		assert(advance(m, 10) == 0 and n == 1, "simple should not fire twice")
	end

	-- Pause / resume freezes remaining; stop keeps reps; start restarts.
	do
		now = 0
		local m = Manager.new(clock)
		local n = 0
		m:create("p", 10, 1, function() n = n + 1 end)
		now = 4
		m:tick(now)
		assert(m:time_left("p") == 6, "time_left should be 6 at t=4")
		m:pause("p")
		now = 100
		m:tick(now)
		assert(n == 0, "paused timer should not fire")
		assert(m:time_left("p") == 6, "paused time_left should stay frozen")
		m:unpause("p")
		assert(m:time_left("p") == 6, "resumed time_left should continue from frozen value")
		assert(advance(m, 6) == 1 and n == 1, "should fire 6s after resume")
		now = 0
		local m2 = Manager.new(clock)
		local c = 0
		m2:create("s", 5, 3, function() c = c + 1 end)
		advance(m2, 5)
		assert(c == 1, "should fire once")
		m2:stop("s")
		advance(m2, 50)
		assert(c == 1, "stopped timer should not fire")
		m2:start("s")
		advance(m2, 5)
		assert(c == 2, "start should re-arm a stopped timer")
	end

	-- Adjust + toggle + remove + clear + delay 0 fires every tick.
	do
		now = 0
		local m = Manager.new(clock)
		local n = 0
		m:create("adj", 10, 5, function() n = n + 1 end)
		m:adjust("adj", 1, 2)
		assert(m:get("adj"):get_delay() == 1, "adjust should change delay")
		assert(m:reps_left("adj") == 2, "adjust should reset reps")
		assert(advance(m, 1) == 1 and n == 1, "adjusted timer should fire on new delay")
		m:toggle("adj")
		assert(m:get("adj"):is_paused(), "toggle should pause a running timer")
		m:toggle("adj")
		assert(m:get("adj"):is_running(), "toggle should resume a paused timer")
		assert(m:remove("adj") == true, "remove should return true")
		assert(not m:exists("adj"), "timer should be gone after remove")
		assert(m:remove("adj") == false, "second remove should return false")
		assert(m:time_left("missing") == nil, "time_left of missing should be nil")
		assert(m:reps_left("missing") == nil, "reps_left of missing should be nil")
		m:create("z", 0, 0, function() n = n + 1 end)
		local before = n
		now = now + 0
		m:tick(now)
		m:tick(now)
		assert(n == before + 2, "delay 0 should fire every tick")
		m:clear()
		assert(m:count() == 0, "clear should empty the registry")
	end

	-- Callback removing itself + error sink isolation.
	do
		now = 0
		local m = Manager.new(clock)
		local order = {}
		m:create("self", 1, 5, function()
			order[#order + 1] = "self"
			m:remove("self")
		end)
		m:create("other", 1, 1, function() order[#order + 1] = "other" end)
		now = 1
		m:tick(now)
		assert(#order == 2, "both timers due at same tick should fire despite self-remove")
		assert(not m:exists("self"), "self-removed timer should be gone")
		local errs = {}
		local m2 = Manager.new(clock)
		m2:set_error_handler(function(err) errs[#errs + 1] = err end)
		local ok2 = false
		m2:create("bad", 1, 1, function() error("boom") end)
		m2:create("good", 1, 1, function() ok2 = true end)
		now = now + 10
		m2:tick(now)
		assert(ok2, "good timer should still fire when bad timer errors with handler")
		assert(#errs == 1, "error handler should capture callback error")
	end

	print("All tests passed")
end
