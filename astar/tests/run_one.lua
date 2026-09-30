-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- tests/run_one.lua -- run a single test file (debugging aid)
-- usage: luajit tests/run_one.lua test_basic
-- Bootstrap: shared test bootstrap (see ../../.tools/bootstrap.lua).
local here
do
	local src = debug.getinfo(1, "S").source
	local dir = src:match("^@(.+/)[^/]+$") or "./"
	here = dir:gsub("[/\\]$", "")
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

local name = arg[1] or "test_basic"
local util = dofile(here .. "/util.lua")

local T = {
	AStar = require "../init",
	OpenSet = require "../open_set",
	util = util,
}
local tests = {}
function T.test(n, fn) tests[#tests + 1] = { n = n, fn = fn } end

function T.ok(c, m) if not c then return error(m or "assertion failed", 0) end end

function T.eq(a, e, m)
	if a ~= e then
		return error((m or "eq failed") .. string.format(" (expected %s, got %s)", tostring(e), tostring(a)), 0)
	end
end

function T.near(a, e, eps, m)
	eps = eps or 1e-9
	local d = a - e
	if d < 0 then d = -d end
	if d > eps then
		return error((m or "near failed") .. string.format(" (expected ~%s, got %s)", tostring(e), tostring(a)), 0)
	end
end

function T.fail(m) return error(m or "assertion failed", 0) end

local chunk = assert(loadfile(here .. "/" .. name .. ".lua"))
chunk()(T)

local passed, failed = 0, 0
for _, t in ipairs(tests) do
	io.write("RUN " .. t.n .. "\n")
	io.stdout:flush()
	local ok, err = pcall(t.fn)
	if ok then
		passed = passed + 1
		io.write("[PASS] " .. t.n .. "\n")
	else
		failed = failed + 1
		io.write("[FAIL] " .. t.n .. ": " .. tostring(err) .. "\n")
	end
	io.stdout:flush()
end
io.write(string.format("\n%s: %d passed, %d failed\n", name, passed, failed))
if failed > 0 then os.exit(1) end
