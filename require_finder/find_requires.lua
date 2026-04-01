#!/usr/bin/env lua

-- Standalone script to find require expressions in Lua files
-- Usage: lua find_requires.lua <filename.lua> [filename2.lua] ...

-- Add current directory to package path
package.path = "./?.lua;" .. package.path

local RequireFinder = require("require_finder")

-- Helper function to read file content
local function readFile(filename)
	local file = io.open(filename, "r")
	if not file then
		return error("Cannot open file: " .. filename)
	end
	local content = file:read("*all")
	file:close()
	return content
end

-- Helper function to check if file exists
local function fileExists(filename)
	local file = io.open(filename, "r")
	if file then
		file:close()
		return true
	end
	return false
end

-- Main function
local function main(args)
	if #args == 0 then
		print("Usage: lua find_requires.lua <filename.lua> [filename2.lua] ...")
		print("Finds all require('...') expressions in Lua source files")
		return
	end

	for _, filename in ipairs(args) do
		if not fileExists(filename) then
			print("Error: File not found: " .. filename)
			goto continue
		end

		print(string.format("\n=== %s ===", filename))

		local success, source = pcall(readFile, filename)
		if not success then
			print("Error reading file: " .. source)
			goto continue
		end

		local requires = RequireFinder.findRequiresWithContext(source)

		if #requires == 0 then
			print("No require expressions found.")
		else
			print(RequireFinder.formatResults(requires))
		end

		::continue::
	end
end

-- Run main function with command line arguments
main(arg)
