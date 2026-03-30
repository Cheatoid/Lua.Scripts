-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Pretty print a tree structure (table or filesystem) with visual hierarchy
--[[
Usage example:

-- For Garry's Mod (compatibility wrapper):
local gmod_fs_provider = {
  find = function(pattern, pathid)
    return file.Find(pattern, pathid or "DATA")
  end
}
print(pretty_print_structure("myfolder", {
  root = "gmod-data/",
  fs_provider = gmod_fs_provider,
  base_path = "DATA"
}))

-- For standard Lua with luaFileSystem:
local lfs = require("lfs")
local lfs_provider = {
  find = function(pattern, base_path)
    local files, dirs = {}, {}
    base_path = base_path or "."
    local full_pattern = base_path .. "/" .. pattern

    for file in lfs.dir(base_path) do
      if file ~= "." and file ~= ".." then
        local full_path = base_path .. "/" .. file
        local attr = lfs.attributes(full_path)
        if attr then
          if attr.mode == "directory" then
            table.insert(dirs, file)
          else
            table.insert(files, file)
          end
        end
      end
    end
    return files, dirs
  end
}
print(pretty_print_structure("src", {
  root = "project/",
  fs_provider = lfs_provider,
  base_path = "."
}))

-- For table data (no file system needed):
local my_tree = {
  "file1.txt",
  "file2.lua",
  folder = {
    "nested.txt",
    subfolder = {
      "deep.txt"
    }
  }
}
print(pretty_print_structure(my_tree, { root = "example/" }))
]]

-- Localize global functions for better performance
local tostring     = tostring
local type         = type
local next         = next
local table_insert = table.insert
local table_concat = table.concat
local table_sort   = table.sort
local string_gsub  = string.gsub
local isnumber     = function(v) return type(v) == "number" end
local isstring     = function(v) return type(v) == "string" end
local istable      = function(v) return type(v) == "table" end

-- Normalize a table node into an ordered list of {name=..., node=...}
local function normalize_table_node(tbl)
	local entries = {}
	if not istable(tbl) then
		return entries
	end

	-- numeric (array) entries first, preserving order
	local i = 1
	while tbl[i] do
		local v = tbl[i]
		if istable(v) then
			table_insert(entries, { name = tostring(i), node = v })
		else
			table_insert(entries, { name = tostring(v), node = v })
		end
		i = i + 1
	end

	-- named keys next, collect non-consecutive numeric keys and string keys, then sort for stable output
	local named = {}
	for k, v in next, tbl do
		if not isnumber(k) or k < 1 or k >= i then
			table_insert(named, { k = k, v = v })
		end
	end

	if #named > 0 then
		table_sort(named, function(a, b) return tostring(a.k) < tostring(b.k) end)
		for j = 1, #named do
			local kv = named[j]
			table_insert(entries, { name = kv.k, node = kv.v })
		end
	end

	return entries
end

-- Build lines recursively from a table node
local function build_lines_from_table(node, prefixParts)
	local lines = {}
	local entries = normalize_table_node(node)

	for idx = 1, #entries do
		local entry = entries[idx]
		local name = entry.name
		local child = entry.node
		local last = (idx == #entries)

		local prefix = table_concat(prefixParts)
		local branch = last and "+-- " or "+-- "
		local suffix = istable(child) and "/" or ""
		table_insert(lines, prefix .. branch .. name .. suffix)

		if istable(child) then
			local nextPrefixParts = {}
			for p = 1, #prefixParts do nextPrefixParts[p] = prefixParts[p] end
			nextPrefixParts[#nextPrefixParts + 1] = last and "    " or "|   "
			local childLines = build_lines_from_table(child, nextPrefixParts)
			for k = 1, #childLines do table_insert(lines, childLines[k]) end
		end
	end

	return lines
end

local function walk(p, fs_provider, base_path)
	local node = {}

	local pattern = (p == "" and "*" or (p .. "/*"))
	local files, dirs = fs_provider.find(pattern, base_path)

	if files and #files > 0 then
		table_sort(files)
		--for i = 1, #files do table_insert(node, files[i]) end
		node = files
	end

	if dirs and #dirs > 0 then
		table_sort(dirs)
		for i = 1, #dirs do
			local d = dirs[i]
			local childPath = (p == "" and d or (p .. "/" .. d))
			node[d] = walk(childPath, fs_provider, base_path)
		end
	end

	return node
end

-- Build a table representation of a filesystem tree using a file system provider
-- path: string path relative to the chosen base path (no trailing slash)
-- fs_provider: object with find(pattern, base_path) method
-- base_path: string base path for the file system operations
local function build_table_from_path(path, fs_provider, base_path)
	local base = path or ""
	base = string_gsub(base, "/+$", "")
	return walk(base, fs_provider, base_path)
end

--- Pretty print a tree structure (table or filesystem) with visual hierarchy
--- @param input table|string The input data - either a table representing a tree structure or a string path to scan
--- @param opts table|nil Optional configuration table
--- - `root` string: Root label for the tree (default: "root/")
--- - `show_root` boolean: Whether to show the root label and initial branch (default: true)
--- - `fs_provider` table: Object with find(pattern, base_path) method (required when input is a path)
--- - `base_path` string: Base path for file system operations (when input is a path)
--- @return string string formatted tree structure with visual hierarchy using ASCII characters
local function pretty_print_structure(input, opts)
	opts = opts or {}
	local root_label = opts.root or "root/"
	local show_root = opts.show_root
	if show_root == nil then show_root = true end

	local tree
	if isstring(input) then
		if not opts.fs_provider then
			return error("fs_provider is required when input is a path")
		end
		tree = build_table_from_path(input, opts.fs_provider, opts.base_path)
	elseif istable(input) then
		tree = input
	else
		return error("input must be a table or a string path")
	end

	local lines = {}
	if show_root then
		table_insert(lines, root_label)
		table_insert(lines, "|")
	end

	local bodyLines = build_lines_from_table(tree, {})
	for i = 1, #bodyLines do table_insert(lines, bodyLines[i]) end

	return table_concat(lines, "\n") .. "\n"
end

-- Export
return pretty_print_structure
