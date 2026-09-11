-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for zip.lua.
-- Run from this directory:
--   lua zip.lua
--   luajit zip.lua

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
local lib = require "zip"
-- Bridging: file-locals used by tests mapped to module exports.
local Zip = lib
local string_format = string.format
local dump_tree = lib.dump_tree
local new_writer = lib.new_writer
local read = lib.read
local read_data = lib.read_data
local read_data_from_string = lib.read_data_from_string
local read_from_string = lib.read_from_string
local read_string_to_nested_table = lib.read_string_to_nested_table
local read_to_nested_table = lib.read_to_nested_table
local write_from_nested_table = lib.write_from_nested_table
local write_from_table = lib.write_from_table
local write_nested_to_string = lib.write_nested_to_string
local write_to_string = lib.write_to_string
-- TODO(manual): the following were file-locals with no direct export;
-- verify and export or inline as needed: comp_size, deterministic, dump_tree, entries, lfh, lfh_offset, max_file_size, method, n, name, s, size, start

if true then
	print("[zip] test start")
	do
		local writer, err = Zip.new_writer("test_stream.zip")
		if not writer then
			print("new_writer failed:", err)
			return
		end

		local entry, err = writer:add("hello.txt", 0)
		if not entry then
			print("add failed:", err)
			return
		end

		entry:write("Hello standalone Lua!\n")
		entry:write("Bitwise packers and CRC.\n")
		entry:close()

		writer:close()
		print("[zip] wrote test_stream.zip")

		local zip, err = Zip.read("test_stream.zip")
		if not zip then
			print("read failed:", err)
			return
		end
		print("[zip] entries:", #zip.files)
		for i = 1, #zip.files do
			local e = zip.files[i]
			print(string_format("entry %d: %s method=%d comp=%d size=%d lfh=%d", i, e.name, e.method, e.comp_size, e
				.size, e.lfh_offset))
		end

		local data, err = Zip.read_data("test_stream.zip", zip.files[1])
		if not data then
			print("read_data failed:", err)
			return
		end
		print("[zip] first entry data:\n" .. data)
	end

	do
		-- Example table with nested folders and files
		local files = {
			["assets/"] = nil, -- explicit empty directory
			["assets/images/"] = nil, -- nested directory
			["assets/images/logo.txt"] = "Logo text\nLine 2\n",
			["docs/manual/readme.txt"] = "This is the readme.\n",
			["docs/manual/notes.txt"] = "Notes go here.\n",
			["rootfile.txt"] = "Top-level file\n",
		}
		-- Write the archive (overwrite existing entries inside archive if present)
		local created, err = Zip.write_from_table("example_nested.zip", files, { overwrite = true })
		if not created then
			print("Failed to write zip:", err)
		else
			print("Wrote archive example_nested.zip with entries:")
			for i = 1, #created do print(" -", created[i]) end
		end
	end

	do
		local tree = {
			["assets"] = {
				["images"] = {
					["logo.txt"] = "Logo text\nBinary ok: \0\1\2",
				},
				["readme.txt"] = "Assets readme\n"
			},
			["docs"] = {
				["manual"] = {
					["readme.txt"] = "Manual readme\n",
				}
			},
			["rootfile.txt"] = "Top-level file\n",
			["emptydir"] = {} -- empty table becomes an explicit directory "emptydir/"
		}
		local ok, err = Zip.write_from_nested_table("nested_from_table.zip", tree, { overwrite = true })
		if not ok then
			print("Failed to write zip:", err)
		else
			print("Wrote nested_from_table.zip")
		end
	end

	do
		-- Read a zip into a nested table
		local tree, err = Zip.read_to_nested_table("nested_from_table.zip", {
			max_file_size = 10 * 1024 * 1024,
			deterministic = true
		})
		if not tree then
			print("read_to_nested_table failed:", err)
		else
			-- Access a file
			if tree.assets and tree.assets.images and tree.assets.images["logo.txt"] then
				local logo_data = tree.assets.images["logo.txt"]
				print("logo.txt size:", #logo_data)
			end
			-- Dump a tree
			dump_tree(tree)
		end
	end

	-- In-memory ZIP tests
	do
		print("[zip] memory test start")

		-- Test 1: Write to string from flat table
		local files = {
			["file1.txt"] = "Content 1\n",
			["file2.txt"] = "Content 2\n",
			["dir/"] = true,
		}
		local zip_data, err = Zip.write_to_string(files)
		if not zip_data then
			print("write_to_string failed:", err)
			return
		end
		print("[zip] write_to_string success, size:", #zip_data)

		-- Test 2: Read from string
		local meta, err = Zip.read_from_string(zip_data)
		if not meta then
			print("read_from_string failed:", err)
			return
		end
		print("[zip] read_from_string success, entries:", #meta.files)
		for i = 1, #meta.files do
			print(string_format("  entry %d: %s", i, meta.files[i].name))
		end

		-- Test 3: Read entry data from string
		local data, err = Zip.read_data_from_string(zip_data, meta.files[1])
		if not data then
			print("read_data_from_string failed:", err)
			return
		end
		print("[zip] read_data_from_string success, content:", data)

		-- Test 4: Write to string from nested table
		local tree = {
			["folder"] = {
				["nested.txt"] = "Nested content\n",
			},
			["root.txt"] = "Root content\n",
		}
		local zip_data2, err = Zip.write_nested_to_string(tree)
		if not zip_data2 then
			print("write_nested_to_string failed:", err)
			return
		end
		print("[zip] write_nested_to_string success, size:", #zip_data2)

		-- Test 5: Read from string to nested table
		local tree2, err = Zip.read_string_to_nested_table(zip_data2)
		if not tree2 then
			print("read_string_to_nested_table failed:", err)
			return
		end
		print("[zip] read_string_to_nested_table success")
		dump_tree(tree2)

		print("[zip] memory test complete")
	end
end
