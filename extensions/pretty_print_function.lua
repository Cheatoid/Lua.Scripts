-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Modular pretty-print for functions with safe attach/detach and metatable compatibility.
-- Works across different Lua environments and games.

local M = {}

-- Environment detection and configuration
local env = {
	-- Core Lua functions (may be overridden)
	debug_getinfo = nil,
	debug_getupvalue = nil,
	debug_setmetatable = nil,
	debug_getmetatable = nil,
	pcall = pcall,
	tostring = tostring,
	type = type,
	string_dump = string.dump,
	string_format = string.format,
	table_concat = table.concat,
	math_max = math.max,
	
	-- Optional/Environment-specific
	io_open = nil,
	print_fn = print,
	
	-- Environment info
	has_debug = false,
	has_io = false,
	environment_type = "unknown", -- "standard", "restricted", "game", "embedded"
	
	-- Feature flags
	allow_file_access = true,
	allow_metatable_modification = true,
	auto_attach = true,
}

-- Detect environment capabilities
local function detect_environment()
	-- Check for debug library
	if type(debug) == "table" and type(debug.getinfo) == "function" then
		env.debug_getinfo = debug.getinfo
		env.debug_getupvalue = debug.getupvalue
		env.debug_setmetatable = debug.setmetatable
		env.debug_getmetatable = debug.getmetatable
		env.has_debug = true
	end
	
	-- Check for io library
	if type(io) == "table" and type(io.open) == "function" then
		env.io_open = io.open
		env.has_io = true
	end
	
	-- Detect environment type
	if type(_G) == "table" then
		-- Check for common game environments
		if _G.game or _G.love or _G.world or _G.minecraft then
			env.environment_type = "game"
		elseif _G.emscripten or _G.js then
			env.environment_type = "embedded"
		elseif not env.has_debug or not env.has_io then
			env.environment_type = "restricted"
		else
			env.environment_type = "standard"
		end
	end
	
	-- Adjust feature flags based on environment
	if env.environment_type == "restricted" then
		env.allow_file_access = false
		env.auto_attach = false
	elseif env.environment_type == "game" then
		-- Games may have custom print functions
		if _G.print and type(_G.print) == "function" then
			env.print_fn = _G.print
		end
	end
end

-- Configure the module for specific environments
function M.configure(config)
	config = config or {}
	
	-- Override environment functions if provided
	for key, value in pairs(config) do
		if env[key] ~= nil then
			env[key] = value
		end
	end
	
	-- Re-detect if core functions changed
	if config.debug_getinfo or config.debug_getupvalue then
		env.has_debug = not not (env.debug_getinfo and env.debug_getupvalue)
	end
	if config.io_open then
		env.has_io = not not env.io_open
	end
	
	return env
end

-- Get current environment info
function M.get_environment()
	return env
end

-- Initialize environment detection
detect_environment()

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
	local ok, s = env.pcall(env.tostring, v)
	if ok then return s end
	return "<unprintable:" .. env.type(v) .. ">"
end

-- Core pretty-print implementation for a function
local function function_pretty_print(fn, opts)
	opts = opts or {}
	local show_source = (opts.show_source == nil) and true or not not opts.show_source
	local show_upvalues = (opts.show_upvalues == nil) and true or not not opts.show_upvalues
	local show_bytecode = not not opts.show_bytecode
	local max_source_lines = tonumber(opts.max_source_lines) or 40
	local print_fn = opts.print_fn or env.print_fn

	if env.type(fn) ~= "function" then
		print_fn("prettyPrint: not a function (" .. env.tostring(env.type(fn)) .. ")")
		return
	end

	if not env.has_debug then
		print_fn("prettyPrint: debug library not available in this environment")
		return
	end

	local info = env.debug_getinfo(fn, "Slnu")
	local header = {}
	header[#header + 1] = env.string_format("Function: %s", safe_tostring(info.name or "<anonymous>"))
	header[#header + 1] = env.string_format("Type: %s", info.what or "unknown")
	if info.what == "C" then
		header[#header + 1] = "(C function)"
	else
		local src = info.source or "?"
		local ld = info.linedefined or -1
		local last = info.lastlinedefined or -1
		header[#header + 1] = env.string_format("Source: %s", src)
		header[#header + 1] = env.string_format("Defined at: lines %d - %d", ld, last)
	end
	header[#header + 1] = env.string_format("Upvalues: %d", info.nups or 0)
	header[#header + 1] = env.string_format("Is vararg: %s", info.isvararg and "yes" or "no")
	header[#header + 1] = env.string_format("Number of params: %s", env.tostring(info.nparams or "unknown"))
	print_fn(env.table_concat(header, " | "))

	-- Source snippet (if available and readable)
	if show_source and info.what ~= "C" and env.type(info.source) == "string" and env.allow_file_access then
		local src = info.source
		if src:sub(1, 1) == "@" and env.io_open then
			local filename = src:sub(2)
			local ok, f = env.pcall(env.io_open, filename, "r")
			if ok and f then
				local lines = {}
				local start_line = env.math_max(1, (info.linedefined or 1) - 3)
				local end_line = (info.lastlinedefined or start_line) + 3
				local cur = 0
				for line in f:lines() do
					cur = cur + 1
					if cur >= start_line and cur <= end_line then
						lines[#lines + 1] = env.string_format("%5d | %s", cur, line)
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
				print_fn("Source file not readable: " .. env.tostring(filename))
			end
		else
			print_fn("Source: " .. env.tostring(src))
		end
	elseif show_source and info.what ~= "C" then
		print_fn("Source: " .. env.tostring(info.source or "?"))
		if not env.allow_file_access then
			print_fn("(File access disabled in this environment)")
		end
	end

	-- Upvalues
	if show_upvalues and (info.nups or 0) > 0 and env.has_debug then
		print_fn("Upvalues:")
		for i = 1, (info.nups or 0) do
			local name, val = env.debug_getupvalue(fn, i)
			if name then
				print_fn(env.string_format("  %d: %s = %s", i, env.tostring(name), safe_tostring(val)))
			else
				print_fn(env.string_format("  %d: <no name>", i))
			end
		end
	elseif show_upvalues and (info.nups or 0) > 0 then
		print_fn("Upvalues: debug library not available for inspection")
	end

	-- Bytecode size (if requested)
	if show_bytecode and env.string_dump then
		local ok, dumped = env.pcall(env.string_dump, fn)
		if ok and env.type(dumped) == "string" then
			print_fn(env.string_format("Bytecode size: %d bytes", #dumped))
		else
			print_fn("Bytecode: unavailable")
		end
	end
end

-- Our prettyPrint function (the one we will insert)
local function make_pretty_fn()
	return function(self, opts)
		-- allow calling as f:prettyPrint() or prettyPrint(f)
		if env.type(self) ~= "function" then
			-- support calling as prettyPrint(fn) if user calls the function directly
			if env.type(opts) == "function" then
				function_pretty_print(opts, {})
				return
			end
			env.print_fn("prettyPrint: receiver is not a function")
			return
		end
		function_pretty_print(self, opts)
	end
end

-- Attach: install prettyPrint into function metatable safely
function M.attach()
	if state.attached then return true end
	if not env.allow_metatable_modification then
		return false, "metatable modification disabled in this environment"
	end
	if not env.has_debug then
		return false, "debug library not available in this environment"
	end
	if env.type(env.debug_getmetatable) ~= "function" or env.type(env.debug_setmetatable) ~= "function" then
		return false, "debug.getmetatable / debug.setmetatable not available"
	end

	-- get current function metatable (may be nil)
	local ok, cur_mt = env.pcall(env.debug_getmetatable, function() end)
	if not ok then cur_mt = nil end
	state.orig_mt = cur_mt

	-- prepare our pretty function and record it
	local pretty_fn = make_pretty_fn()
	state.our_pretty_fn = pretty_fn

	-- If no metatable, create one with __index table
	if not cur_mt then
		local new_index = { prettyPrint = pretty_fn }
		local new_mt = { __index = new_index }
		local ok2, err = env.pcall(env.debug_setmetatable, function() end, new_mt)
		if not ok2 then return false, "failed to set metatable: " .. env.tostring(err) end
		-- record that original had no mt and we created it
		state.attached = true
		state.orig_index_table_prev = nil
		state.orig_index_fn = nil
		state.wrapper_index_fn = nil
		return true
	end

	-- If __index is a table, insert prettyPrint key if not present
	local idx = cur_mt.__index
	if env.type(idx) == "table" then
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
	if env.type(idx) == "function" then
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
		local ok2, err = env.pcall(env.debug_setmetatable, function() end, new_mt)
		if not ok2 then return false, "failed to set metatable wrapper: " .. env.tostring(err) end
		state.attached = true
		return true
	end

	-- If __index is something else (userdata, etc.), we avoid clobbering it.
	return false, "unsupported __index type in existing function metatable"
end

-- Detach: undo only what we changed, safely
function M.detach()
	if not state.attached then return true end
	if not env.has_debug then
		return false, "debug library not available in this environment"
	end
	if env.type(env.debug_getmetatable) ~= "function" or env.type(env.debug_setmetatable) ~= "function" then
		return false, "debug.getmetatable / debug.setmetatable not available"
	end

	local ok, cur_mt = env.pcall(env.debug_getmetatable, function() end)
	if not ok then cur_mt = nil end

	-- Case: we created the metatable originally (orig_mt == nil)
	if state.orig_mt == nil then
		-- Only remove if current metatable still matches what we set (best-effort)
		if cur_mt and env.type(cur_mt.__index) == "table" and cur_mt.__index.prettyPrint == state.our_pretty_fn then
			-- remove the key and if table becomes empty, remove metatable
			cur_mt.__index.prettyPrint = nil
			-- if table has no keys, clear metatable
			local empty = true
			for k, _ in pairs(cur_mt.__index) do
				empty = false; break
			end
			if empty then
				pcall(env.debug_setmetatable, function() end, nil)
			else
				pcall(env.debug_setmetatable, function() end, cur_mt)
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
	if state.orig_index_table_prev ~= nil or (state.orig_index_table_prev == nil and cur_mt and env.type(cur_mt.__index) == "table") then
		if cur_mt and env.type(cur_mt.__index) == "table" then
			-- only remove if our function is still present
			if cur_mt.__index.prettyPrint == state.our_pretty_fn then
				cur_mt.__index.prettyPrint = state.orig_index_table_prev
				pcall(env.debug_setmetatable, function() end, cur_mt)
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
			pcall(env.debug_setmetatable, function() end, new_mt)
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
			if cur_mt and env.type(cur_mt.__index) == "table" and cur_mt.__index.prettyPrint == state.our_pretty_fn then
				cur_mt.__index.prettyPrint = nil
				pcall(env.debug_setmetatable, function() end, cur_mt)
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

-- Auto-attach if enabled
if env.auto_attach then
	env.pcall(M.attach)
end

return M
