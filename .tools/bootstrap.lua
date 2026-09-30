-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Shared test bootstrap for standalone lua/luajit runs.
-- Locates the @cheatoid root and wires package.path plus a
-- parent-relative require searcher, so every tests/*.lua entry
-- point runs from its own directory without inlining this logic.
-- Replaces the former 69-line inline block (plus linq/standard
-- variants) previously copied into each test file.
--
-- Usage (at the top of a tests/*.lua file):
--   do
--     local src = debug.getinfo(1, "S").source
--     local dir = src:match("^@(.+/)[^/]+$") or "./"
--     ... locate .tools/bootstrap.lua relative to dir ...
--     assert(dofile(boot))(dir)
--   end
-- Tests shadowing C libraries (standard/tests/*.lua) pass
-- `{ preload_stdlib = true }` as second argument.
-- In game, no bootstrap is needed; this file is plain-lua only.

local io_open = io.open
local string_gsub = string.gsub
local string_sub = string.sub

---@class bootstrap.SetupOptions
---@field preload_stdlib? boolean Preload standard extensions over C libs.

--- Check file existence without raising.
---@param p string Location to probe.
---@return boolean present True when readable.
local function isfile(p)
	local f = io_open(p, "r")
	if f then
		f:close()
		return true
	end
	return false
end

--- Preload a standard extension over the C library of the same name.
---@param root string Detected root with trailing slash.
---@param name string Module name shadowing a C lib.
---@param relpath string Location relative to root.
local function try_preload(root, name, relpath)
	if package.loaded[name] == nil or type(package.loaded[name]) ~= "table" or package.loaded[name].explode == nil and name == "string" then
		local f = root .. relpath
		local fh = io_open(f, "r")
		if fh then
			fh:close()
			local chunk = loadfile(f)
			if chunk then
				local ok, mod = pcall(chunk, name)
				if ok and mod ~= nil then
					package.loaded[name] = mod
				end
			end
		end
	end
end

--- Wire package.path and parent-relative requires for a test file.
---@param caller_dir string Test file directory with trailing slash.
---@param opts? bootstrap.SetupOptions Optional setup flags.
---@return string root Detected @cheatoid root with trailing slash.
local function setup(caller_dir, opts)
	local dir = caller_dir
	local root
	local tmp = {
		dir .. "../",
		dir .. "../../",
		dir .. "../../../",
		dir .. "../../../../",
		dir .. "../../../../../",
	}
	for i = 1, #tmp do
		local c = tmp[i]
		if isfile(c .. "standalone/bits.lua") then
			root = c
			break
		end
	end
	root = root or dir .. "../"
	if package then
		package.path = dir ..
			"../?.lua;" ..
			dir ..
			"../?/init.lua;" ..
			dir ..
			"?.lua;" ..
			dir ..
			"?/init.lua;" ..
			root ..
			"?.lua;" ..
			root ..
			"?/init.lua;" ..
			root ..
			"standalone/?.lua;" ..
			root ..
			"math/?.lua;" ..
			root ..
			"collections/?.lua;" ..
			root ..
			"benchmark/?.lua;" ..
			root ..
			"timer/?.lua;" ..
			root ..
			"autocompleter/?.lua;" ..
			root ..
			"permission/?.lua;" ..
			root ..
			"chat_commander/?.lua;" ..
			root ..
			"vm/?.lua;" ..
			root ..
			"require_finder/?.lua;" ..
			root ..
			"inventory/?.lua;" ..
			root ..
			"linq/?.lua;" ..
			root ..
			"standard/?.lua;" ..
			root ..
			"animation/?.lua;" ..
			root ..
			"logger/?.lua;" ..
			root ..
			"meta/?.lua;" ..
			root ..
			"ref/?.lua;" ..
			root ..
			"astar/?.lua;" ..
			package.path
	end
	local searchers = package.searchers or package.loaders
	if searchers then
		table.insert(searchers, 2, function(mod)
			if string_sub(mod, 1, 3) == "../" or string_sub(mod, 1, 2) == "./" then
				local clean = string_gsub((string_gsub((string_gsub(mod, "^%./", "")), "^%.%.%/", "")), "^%.%.%/", "")
				local tries = {
					dir .. "../" .. clean .. ".lua",
					dir .. "../" .. clean .. "/init.lua",
					root .. clean .. ".lua",
					root .. clean .. "/init.lua",
				}
				for i = 1, #tries do
					local f = tries[i]
					if isfile(f) then
						local chunk = loadfile(f)
						if chunk then return chunk, f end
					end
				end
			end
			return nil
		end)
	end
	if opts and opts.preload_stdlib then
		try_preload(root, "string", "standard/string.lua")
	end
	return root
end

return setup
