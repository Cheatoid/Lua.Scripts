-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT
-- Standalone test invoking inv built-in Tests entry-point.
-- Run from this directory:
--   lua inv.lua
--   luajit inv.lua
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
local lib = require "inv"

local lib = require "inv"
local Tests = assert(lib.Tests, "inv.Tests not exported")
assert(Tests.runAll(), "inv Tests.runAll failed")
print("All tests passed")
