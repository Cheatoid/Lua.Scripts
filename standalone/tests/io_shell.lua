-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for io_shell.lua.
-- Run from this directory:
--   lua io_shell.lua
--   luajit io_shell.lua

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
local lib = require "io_shell"
-- Bridging: file-locals used by tests mapped to module exports.
local io_shell = lib
local os_tmpname = os and os.tmpname
local string_find = string.find
local string_format = string.format
local command_exists = lib.command_exists
local contains = lib.contains
local copy = lib.copy
local count = lib.count
local describe = lib.describe
local execute = lib.execute
local exists = lib.exists
local find_by_pattern = lib.find_by_pattern
local find_files = lib.find_files
local find_lua_files = lib.find_lua_files
local get_capabilities = lib.get_capabilities
local get_os = lib.get_os
local is_directory = lib.is_directory
local is_file = lib.is_file
local is_unix = lib.is_unix
local is_windows = lib.is_windows
local list = lib.list
local list_directories = lib.list_directories
local list_files = lib.list_files
local mkdir = lib.mkdir
local move = lib.move
local quote = lib.quote
local read_file = lib.read_file
local remove = lib.remove
local replace = lib.replace
local replace_all = lib.replace_all
local search = lib.search
local search_lua = lib.search_lua
local search_regex = lib.search_regex
local search_text = lib.search_text
local write_file = lib.write_file
-- TODO(manual): the following were file-locals with no direct export;
-- verify and export or inline as needed: copy, file, line, n, os_tmpname, stderr, stdout, success

if true then
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
	print("[io_shell] testing...")

	local tmp_root = os_tmpname() .. "_io_shell_test"
	io_shell.remove(tmp_root, true)

	test("get_os returns known identifier", function()
		local os_name = io_shell.get_os()
		assert(os_name == "windows" or os_name == "linux" or os_name == "macos" or os_name == "bsd" or os_name == "unix" or
			os_name == "unknown")
	end)

	test("is_windows/is_unix are exclusive booleans", function()
		local w, u = io_shell.is_windows(), io_shell.is_unix()
		assert(type(w) == "boolean" and type(u) == "boolean")
		assert(not (w and u))
	end)

	test("quote wraps value", function()
		local q = io_shell.quote("a b")
		assert(type(q) == "string" and #q > 3)
		assert(string_find(q, "a b", 1, true) ~= nil)
	end)

	test("write_file/read_file roundtrip", function()
		assert(io_shell.mkdir(tmp_root, true))
		local p = tmp_root .. "/hello.txt"
		assert(io_shell.write_file(p, "hello"))
		local content, err = io_shell.read_file(p)
		assert(content == "hello", tostring(err))
	end)

	test("read_file missing returns nil", function()
		local content, err = io_shell.read_file(tmp_root .. "/does_not_exist_xyz.txt")
		assert(content == nil and type(err) == "string")
	end)

	test("execute captures stdout", function()
		local result = io_shell.execute("echo hello")
		assert(type(result) == "table" and type(result.stdout) == "string")
		assert(result.success == true)
		assert(string_find(result.stdout, "hello", 1, true) ~= nil)
	end)

	test("execute failing command reports failure", function()
		local result = io_shell.execute("command_that_does_not_exist_xyz_12345")
		assert(type(result) == "table")
		assert(result.success == false)
	end)

	test("execute raise_on_error raises", function()
		local ok = pcall(io_shell.execute, "command_that_does_not_exist_xyz_12345", { raise_on_error = true })
		assert(ok == false)
	end)

	test("command_exists caches boolean", function()
		local a = io_shell.command_exists("definitely_not_a_real_command_xyz")
		local b = io_shell.command_exists("definitely_not_a_real_command_xyz")
		assert(a == false and b == false)
	end)

	test("exists/is_file/is_directory basics", function()
		local p = tmp_root .. "/hello.txt"
		assert(io_shell.exists(p) == true)
		assert(io_shell.is_file(p) == true)
		assert(type(io_shell.is_directory(tmp_root)) == "boolean")
		assert(io_shell.exists(tmp_root .. "/missing_xyz") == false)
	end)

	test("mkdir nested recursive", function()
		local nested = tmp_root .. "/a/b"
		local ok, result = io_shell.mkdir(nested, true)
		assert(type(ok) == "boolean" and type(result) == "table")
		if ok then
			assert(io_shell.exists(nested) == true)
		end
	end)

	test("list/list_files/list_directories return tables", function()
		local entries, result = io_shell.list(tmp_root)
		assert(type(entries) == "table" and type(result) == "table")
		local files = io_shell.list_files(tmp_root)
		assert(type(files) == "table")
		local dirs = io_shell.list_directories(tmp_root)
		assert(type(dirs) == "table")
	end)

	test("find_files/find_lua_files/find_by_pattern return tables", function()
		assert(io_shell.write_file(tmp_root .. "/sample.lua", "return 1"))
		local files = io_shell.find_files(tmp_root, { pattern = "*.lua" })
		assert(type(files) == "table")
		local lua_files = io_shell.find_lua_files(tmp_root)
		assert(type(lua_files) == "table")
		local by_pat = io_shell.find_by_pattern("*.lua", tmp_root)
		assert(type(by_pat) == "table")
	end)

	test("search/contains/count return tables", function()
		local caps = io_shell.get_capabilities()
		if not (caps.rg or caps.grep) then return end
		assert(io_shell.write_file(tmp_root .. "/search_me.txt", "needle here\nanother line\n"))
		local matches, result = io_shell.search("needle", tmp_root, { fixed_string = true })
		assert(type(matches) == "table" and type(result) == "table")
		assert(#matches >= 1)
		local found = io_shell.contains("needle", tmp_root)
		assert(found == true)
		assert(io_shell.count("needle", tmp_root) >= 1)
	end)

	test("search_text/search_regex/search_lua return tables", function()
		local caps = io_shell.get_capabilities()
		if not (caps.rg or caps.grep) then return end
		assert(type(io_shell.search_text("needle", tmp_root)) == "table")
		assert(type(io_shell.search_regex("nee.dle", tmp_root)) == "table")
		assert(type(io_shell.search_lua("return", tmp_root)) == "table")
	end)

	test("copy/move roundtrip", function()
		local src = tmp_root .. "/hello.txt"
		local dst = tmp_root .. "/copied.txt"
		local moved = tmp_root .. "/moved.txt"
		local ok, res = io_shell.copy(src, dst)
		assert(type(ok) == "boolean" and type(res) == "table")
		if ok then
			assert(io_shell.exists(dst) == true)
			local ok2, res2 = io_shell.move(dst, moved)
			assert(type(ok2) == "boolean" and type(res2) == "table")
			if ok2 then
				assert(io_shell.exists(moved) == true)
			end
		end
	end)

	test("remove file", function()
		local p = tmp_root .. "/to_delete.txt"
		assert(io_shell.write_file(p, "bye"))
		local ok, res = io_shell.remove(p)
		assert(ok == true, "remove failed: " .. tostring(res and res.stdout) .. tostring(res and res.stderr))
		assert(io_shell.exists(p) == false)
	end)

	test("replace/replace_all (when backend available)", function()
		local caps = io_shell.get_capabilities()
		if not (caps.sd or caps.sed) then return end
		if not (caps.rg or caps.grep) then return end
		local p = tmp_root .. "/replace_me.txt"
		assert(io_shell.write_file(p, "foo 123"))
		local ok, res = io_shell.replace("foo", "bar", p)
		assert(type(ok) == "boolean" and type(res) == "table")
		local changed, results = io_shell.replace_all("bar", "baz", tmp_root)
		assert(type(changed) == "number" and type(results) == "table")
	end)

	test("get_capabilities/describe shapes", function()
		local caps = io_shell.get_capabilities()
		assert(type(caps) == "table" and type(caps.rg) == "boolean")
		local desc = io_shell.describe()
		assert(type(desc) == "string" and string_find(desc, "OS:", 1, true) ~= nil)
	end)

	io_shell.remove(tmp_root, true)

	print(string_format("[io_shell] %d/%d tests passed (%d failed)", passed, total, failed))
	assert(failed == 0, string_format("%d test(s) failed", failed))
end
