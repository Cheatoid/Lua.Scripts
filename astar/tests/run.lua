-- Test runner. Usage (from anywhere):
--     luajit tests/run.lua              (or: python3 tools/luajit.py tests/run.lua)
--
-- Each tests/test_*.lua file returns a function(T); T carries assertion
-- helpers, fixtures and the library itself. Failures are collected and
-- reported; the process exits non-zero if anything failed.

-- Bootstrap for standalone LuaJIT: mimic the game loader where require is
-- file-relative and uses "/" (siblings by plain name, parent via "../").
-- Full library is "../init" (unambiguous); "../astar" is the core file.
-- In game, no bootstrap is needed.
local here = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]*$") or "."
package.path = here .. "/?.lua;" .. here .. "/../?.lua;" .. package.path

local util = require "util"

local T = {
	AStar = require "../init",
	OpenSet = require "../open_set",
	util = util,
	-- assertion helpers
	test = nil,
	eq = nil,
	near = nil,
	ok = nil,
	fail = nil,
}

local tests = {}
local current_file = "?"

function T.test(name, fn)
	tests[#tests + 1] = { name = name, fn = fn, file = current_file }
end

function T.ok(cond, msg)
	if not cond then
		return error(msg or "assertion failed", 0)
	end
end

function T.eq(actual, expected, msg)
	if actual ~= expected then
		return error((msg or "eq failed") .. string.format(" (expected %s, got %s)",
			tostring(expected), tostring(actual)), 0)
	end
end

function T.near(actual, expected, eps, msg)
	eps = eps or 1e-9
	local d = actual - expected
	if d < 0 then d = -d end
	if d > eps then
		return error((msg or "near failed") .. string.format(" (expected ~%s, got %s)",
			tostring(expected), tostring(actual)), 0)
	end
end

function T.fail(msg) return error(msg or "assertion failed", 0) end

local files = {
	"test_open_set",
	"test_basic",
	"test_correctness",
	"test_grid",
	"test_incremental",
	"test_regression",
}

local passed, failed = 0, 0
local failures = {}

for _, name in ipairs(files) do
	current_file = name
	local chunk, err = loadfile(here .. "/" .. name .. ".lua")
	if not chunk then
		io.stderr:write("cannot load " .. name .. ".lua: " .. tostring(err) .. "\n")
		os.exit(1)
	end
	local ok_load, fn = pcall(chunk)
	if not ok_load then
		io.stderr:write("error loading " .. name .. ".lua: " .. tostring(fn) .. "\n")
		os.exit(1)
	end
	fn(T)
end

for _, t in ipairs(tests) do
	local ok, err = pcall(t.fn)
	if ok then
		passed = passed + 1
		io.write(string.format("[PASS] %s :: %s\n", t.file, t.name))
	else
		failed = failed + 1
		failures[#failures + 1] = string.format("[FAIL] %s :: %s\n       %s", t.file, t.name, tostring(err))
		io.write(string.format("[FAIL] %s :: %s\n", t.file, t.name))
	end
end

io.write(string.format("\n%d passed, %d failed (total %d)\n", passed, failed, passed + failed))
if failed > 0 then
	io.write("\nFailures:\n")
	for _, f in ipairs(failures) do
		io.write(f .. "\n")
	end
	os.exit(1)
end
os.exit(0)
