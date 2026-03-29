-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Pretty-print a function with safe attach/detach and metatable compatibility.

local debug_getinfo = debug.getinfo
local debug_getupvalue = debug.getupvalue
local debug_setmetatable = debug.setmetatable
local debug_getmetatable = debug.getmetatable
local pcall = pcall
local tostring = tostring
local type = type
local io_open = io and io.open or false
local string_dump = string.dump
local string_format = string.format
local table_concat = table.concat
local math_max = math.max

local M = {}

-- Internal state to track what we changed so detach can be safe
local state = {
	attached = false,
	-- original metatable snapshot (not necessarily complete; used only as reference)
	orig_mt = nil,
	-- if original __index was a table, we store previous value of prettyPrint (if any)
	orig_index_table_prev = nil,
	-- if we wrapped an original __index function, store it and wrapper
	orig_index_fn = nil,
	wrapper_index_fn = nil,
	-- marker for our inserted prettyPrint function (so we only remove our function)
	our_pretty_fn = nil,
}

-- Safe tostring for values
local function safe_tostring(v)
	local ok, s = pcall(tostring, v)
	if ok then return s end
	return "<unprintable:" .. type(v) .. ">"
end

-- Print helper (default)
local out_print = print

-- Core pretty-print implementation for a function
local function function_pretty_print(fn, opts)
	opts = opts or {}
	local show_source = (opts.show_source == nil) and true or not not opts.show_source
	local show_upvalues = (opts.show_upvalues == nil) and true or not not opts.show_upvalues
	local show_bytecode = not not opts.show_bytecode
	local max_source_lines = tonumber(opts.max_source_lines) or 40
	local print_fn = opts.print_fn or out_print

	if type(fn) ~= "function" then
		print_fn("prettyPrint: not a function (" .. tostring(type(fn)) .. ")")
		return
	end

	local info = debug_getinfo(fn, "Slnu")
	local header = {}
	header[#header + 1] = string_format("Function: %s", safe_tostring(info.name or "<anonymous>"))
	header[#header + 1] = string_format("Type: %s", info.what or "unknown")
	if info.what == "C" then
		header[#header + 1] = "(C function)"
	else
		local src = info.source or "?"
		local ld = info.linedefined or -1
		local last = info.lastlinedefined or -1
		header[#header + 1] = string_format("Source: %s", src)
		header[#header + 1] = string_format("Defined at: lines %d - %d", ld, last)
	end
	header[#header + 1] = string_format("Upvalues: %d", info.nups or 0)
	header[#header + 1] = string_format("Is vararg: %s", info.isvararg and "yes" or "no")
	header[#header + 1] = string_format("Number of params: %s", tostring(info.nparams or "unknown"))
	print_fn(table_concat(header, " | "))

	-- Source snippet (if available and readable)
	if show_source and info.what ~= "C" and type(info.source) == "string" then
		local src = info.source
		if src:sub(1, 1) == "@" and io_open then
			local filename = src:sub(2)
			local ok, f = pcall(io_open, filename, "r")
			if ok and f then
				local lines = {}
				local start_line = math_max(1, (info.linedefined or 1) - 3)
				local end_line = (info.lastlinedefined or start_line) + 3
				local cur = 0
				for line in f:lines() do
					cur = cur + 1
					if cur >= start_line and cur <= end_line then
						lines[#lines + 1] = string_format("%5d | %s", cur, line)
						if #lines >= max_source_lines then break end
					end
					if cur > end_line then break end
				end
				f:close()
				if #lines > 0 then
					print_fn("Source snippet:")
					for i = 1, #lines do print_fn(lines[i]) end
				else
					print_fn("Source file available but snippet could not be read or is empty.")
				end
			else
				print_fn("Source file not readable: " .. tostring(filename))
			end
		else
			print_fn("Source: " .. tostring(src))
		end
	end

	-- Upvalues
	if show_upvalues and (info.nups or 0) > 0 then
		print_fn("Upvalues:")
		for i = 1, (info.nups or 0) do
			local name, val = debug_getupvalue(fn, i)
			if name then
				print_fn(string_format("  %d: %s = %s", i, tostring(name), safe_tostring(val)))
			else
				print_fn(string_format("  %d: <no name>", i))
			end
		end
	end

	-- Bytecode size (if requested)
	if show_bytecode and string_dump then
		local ok, dumped = pcall(string_dump, fn)
		if ok and type(dumped) == "string" then
			print_fn(string_format("Bytecode size: %d bytes", #dumped))
		else
			print_fn("Bytecode: unavailable")
		end
	end
end

-- Our prettyPrint function (the one we will insert)
local function make_pretty_fn()
	return function(self, opts)
		-- allow calling as f:prettyPrint() or prettyPrint(f)
		if type(self) ~= "function" then
			-- support calling as prettyPrint(fn) if user calls the function directly
			if type(opts) == "function" then
				function_pretty_print(opts, {})
				return
			end
			print("prettyPrint: receiver is not a function")
			return
		end
		function_pretty_print(self, opts)
	end
end

-- Attach: install prettyPrint into function metatable safely
function M.attach()
	if state.attached then return true end
	if type(debug_getmetatable) ~= "function" or type(debug_setmetatable) ~= "function" then
		return false, "debug.getmetatable / debug.setmetatable not available"
	end

	-- get current function metatable (may be nil)
	local ok, cur_mt = pcall(debug_getmetatable, function() end)
	if not ok then cur_mt = nil end
	state.orig_mt = cur_mt

	-- prepare our pretty function and record it
	local pretty_fn = make_pretty_fn()
	state.our_pretty_fn = pretty_fn

	-- If no metatable, create one with __index table
	if not cur_mt then
		local new_index = { prettyPrint = pretty_fn }
		local new_mt = { __index = new_index }
		local ok2, err = pcall(debug_setmetatable, function() end, new_mt)
		if not ok2 then return false, "failed to set metatable: " .. tostring(err) end
		-- record that original had no mt and we created it
		state.attached = true
		state.orig_index_table_prev = nil
		state.orig_index_fn = nil
		state.wrapper_index_fn = nil
		return true
	end

	-- If __index is a table, insert prettyPrint key if not present
	local idx = cur_mt.__index
	if type(idx) == "table" then
		-- store previous value (could be nil or something else)
		state.orig_index_table_prev = idx.prettyPrint
		-- only set if not present or different
		if idx.prettyPrint ~= pretty_fn then
			idx.prettyPrint = pretty_fn
		end
		state.attached = true
		return true
	end

	-- If __index is a function, wrap it with a proxy that handles our key and delegates
	if type(idx) == "function" then
		-- store original function
		state.orig_index_fn = idx
		-- create wrapper
		local function wrapper(obj, key)
			if key == "prettyPrint" then
				return state.our_pretty_fn
			end
			-- delegate to original
			return state.orig_index_fn(obj, key)
		end
		state.wrapper_index_fn = wrapper
		-- set new metatable that reuses other fields but replaces __index
		local new_mt = {}
		for k, v in pairs(cur_mt) do new_mt[k] = v end
		new_mt.__index = wrapper
		local ok2, err = pcall(debug_setmetatable, function() end, new_mt)
		if not ok2 then return false, "failed to set metatable wrapper: " .. tostring(err) end
		state.attached = true
		return true
	end

	-- If __index is something else (userdata, etc.), we avoid clobbering it.
	return false, "unsupported __index type in existing function metatable"
end

-- Detach: undo only what we changed, safely
function M.detach()
	if not state.attached then return true end
	if type(debug_getmetatable) ~= "function" or type(debug_setmetatable) ~= "function" then
		return false, "debug.getmetatable / debug.setmetatable not available"
	end

	local ok, cur_mt = pcall(debug_getmetatable, function() end)
	if not ok then cur_mt = nil end

	-- Case: we created the metatable originally (orig_mt == nil)
	if state.orig_mt == nil then
		-- Only remove if current metatable still matches what we set (best-effort)
		if cur_mt and type(cur_mt.__index) == "table" and cur_mt.__index.prettyPrint == state.our_pretty_fn then
			-- remove the key and if table becomes empty, remove metatable
			cur_mt.__index.prettyPrint = nil
			-- if table has no keys, clear metatable
			local empty = true
			for k, _ in pairs(cur_mt.__index) do
				empty = false; break
			end
			if empty then
				pcall(debug_setmetatable, function() end, nil)
			else
				pcall(debug_setmetatable, function() end, cur_mt)
			end
		end
		-- clear state
		state.attached = false
		state.orig_mt = nil
		state.orig_index_table_prev = nil
		state.orig_index_fn = nil
		state.wrapper_index_fn = nil
		state.our_pretty_fn = nil
		return true
	end

	-- If original __index was a table: restore previous prettyPrint value (could be nil)
	if state.orig_index_table_prev ~= nil or (state.orig_index_table_prev == nil and cur_mt and type(cur_mt.__index) == "table") then
		if cur_mt and type(cur_mt.__index) == "table" then
			-- only remove if our function is still present
			if cur_mt.__index.prettyPrint == state.our_pretty_fn then
				cur_mt.__index.prettyPrint = state.orig_index_table_prev
				pcall(debug_setmetatable, function() end, cur_mt)
			end
		end
		state.attached = false
		state.orig_mt = nil
		state.orig_index_table_prev = nil
		state.orig_index_fn = nil
		state.wrapper_index_fn = nil
		state.our_pretty_fn = nil
		return true
	end

	-- If we wrapped an original __index function, try to restore it only if wrapper is still present
	if state.orig_index_fn and state.wrapper_index_fn then
		if cur_mt and cur_mt.__index == state.wrapper_index_fn then
			local new_mt = {}
			for k, v in pairs(cur_mt) do new_mt[k] = v end
			new_mt.__index = state.orig_index_fn
			pcall(debug_setmetatable, function() end, new_mt)
			state.attached = false
			state.orig_mt = nil
			state.orig_index_table_prev = nil
			state.orig_index_fn = nil
			state.wrapper_index_fn = nil
			state.our_pretty_fn = nil
			return true
		else
			-- Someone else replaced __index after we wrapped it; do not clobber their change.
			-- Best-effort: if current __index is a table and contains our function, remove it.
			if cur_mt and type(cur_mt.__index) == "table" and cur_mt.__index.prettyPrint == state.our_pretty_fn then
				cur_mt.__index.prettyPrint = nil
				pcall(debug_setmetatable, function() end, cur_mt)
			end
			state.attached = false
			state.orig_mt = nil
			state.orig_index_table_prev = nil
			state.orig_index_fn = nil
			state.wrapper_index_fn = nil
			state.our_pretty_fn = nil
			return true
		end
	end

	-- Fallback: nothing we can safely restore; clear state
	state.attached = false
	state.orig_mt = nil
	state.orig_index_table_prev = nil
	state.orig_index_fn = nil
	state.wrapper_index_fn = nil
	state.our_pretty_fn = nil
	return true
end

-- Convenience: check attached state
function M.is_attached()
	return state.attached
end

-- Expose prettyPrintFunction for direct use
M.prettyPrintFunction = function_pretty_print

-- Auto-attach on require.
pcall(M.attach)

return M
