-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for type_check.lua.
-- Run from this directory:
--   lua type_check.lua
--   luajit type_check.lua

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
local lib = require "type_check"
local type_check = lib.check
local type_check_arg = lib.check_arg

if true then
	local function example(a, b, c)
		type_check(a, "number|boolean", 1)
		type_check_arg(1, "number|boolean")
		type_check(b, "string|nil", 2)
		type_check_arg(2, "string|nil")
		type_check(c, "table", 3)
		type_check_arg(3, "table")
		print(a, b, c)
	end
	example(12.34, "foo", { "bar" })
	example(false, nil, { "bar" })
	-- example() with missing args must fail (original Quick test called it bare and crashed).
	assert(not pcall(example), "example() with no args should fail type check")
end
