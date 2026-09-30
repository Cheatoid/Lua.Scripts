-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Test script for require_finder utility

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
local RequireFinder = require "require_finder"

-- Test Lua source code with various require patterns
local testCode = [=[
-- Simple library require
local json = require("json")

-- Relative require
local utils = require(".utils")
local helper = require("..helper")

-- Absolute require
local config = require("/config/settings")

-- Require with spaces
local module = require( "my.module" )

-- Long string require
local path = require([[very.long.module.path]])

-- Nested requires in function
function loadModule(name)
	local mod = require("dynamic." .. name)
	return mod
end

-- Multiple requires on same line
local a, b = require("a"), require("b")

-- Not a require (different function)
local result = some_function("not_a_require")

-- Comments with require text
-- local fake = require("fake_comment")
]=]

print("=== Testing RequireFinder Utility ===\n")

-- Test basic finding
print("1. Basic require finding:")
local requires = RequireFinder.findRequires(testCode)
for i, req in ipairs(requires) do
	print(string.format("%d. %s -> %s (line %d)", i, req.expression, req.moduleName, req.line))
end

print("\n2. With context:")
local requiresWithContext = RequireFinder.findRequiresWithContext(testCode)
for i, req in ipairs(requiresWithContext) do
	print(string.format("%d. %s", i, req.expression))
	print(string.format("   Module: %s", req.moduleName))
	print(string.format("   Type: %s", req.requireType))
	print(string.format("   Position: line %d, col %d", req.line, req.col))
	print()
end

print("3. Formatted output:")
print(RequireFinder.formatResults(requiresWithContext))

-- Test with empty code
print("\n4. Empty code test:")
local emptyRequires = RequireFinder.findRequires("")
print(string.format("Found %d requires in empty code", #emptyRequires))
