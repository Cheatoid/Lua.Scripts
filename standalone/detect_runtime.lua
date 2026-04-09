-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Lua runtime/version detector

-- Localized global functions for better performance
local pcall, type, tostring, tonumber, error = pcall, type, tostring, tonumber, error
local string_match, string_format = string.match, string.format

local function safe_pcall(fn, ...)
	local ok, res = pcall(fn, ...)
	return ok, res
end

local function detect_runtime()
	local info = {
		-- Raw declarations
		declared = _VERSION or "unknown",
		declared_major = 0,
		declared_minor = 0,

		-- Engine / variant
		is_luajit = false,
		engine = "PUC-Rio Lua",
		engine_version = nil,
		variant = nil,

		-- Parsed / inferred "actual" version from feature detection
		actual_major = 0,
		actual_minor = 0,

		-- Loader info and capability table
		loader = nil,
		has_load = false,
		has_loadstring = false,
		load_accepts_env = false,
		capabilities = {},

		-- Misc
		spoofed = false,
	}

	-- Parse declared _VERSION string
	do
		local dmaj, dmin = string_match(tostring(info.declared), "Lua%s*(%d+)%.(%d+)")
		info.declared_major = tonumber(dmaj) or 0
		info.declared_minor = tonumber(dmin) or 0
	end

	-- Detect LuaJIT and metadata
	if type(jit) == "table" then
		info.is_luajit = true
		info.engine = "LuaJIT"
		info.engine_version = jit.version
		info.variant = "LuaJIT"
		info.luajit_version_num = jit.version_num
	end

	-- Detect known environments/forks
	if _G.ngx and type(_G.ngx) == "table" and _G.ngx.config then
		info.variant = info.variant or "OpenResty"
	elseif _G.tarantool then
		info.variant = info.variant or "Tarantool"
	end

	-- Determine loader availability: prefer load, fallback to loadstring
	info.has_load = (type(load) == "function")
	info.has_loadstring = (type(loadstring) == "function")
	info.loader = load or loadstring

	-- Check whether load accepts the 4th env parameter (Lua 5.2+ signature)
	local pcall, load, error, type = pcall, load, error, type
	if info.has_load then
		local ok = pcall(function()
			-- try to load a trivial chunk and pass an env table as 4th arg
			local f = load("return 42", "detect_runtime_test", "t", {})
			if type(f) ~= "function" then return error("no function") end
			local v = f()
			if v ~= 42 then return error("bad return") end
		end)
		info.load_accepts_env = ok
	else
		info.load_accepts_env = false
	end

	-- Helper to attempt loading code using the available loader in a safe way
	local can_load
	local pcall, load = pcall, load
	can_load = function(chunk)
		if not info.loader then return false end
		-- If load accepts env, call with env to avoid polluting globals
		if info.load_accepts_env then
			return pcall(function() return load(chunk, "detect_runtime", "t", {}) end)
		end
		-- loadstring or load without env
		return pcall(function() return info.loader(chunk) end)
	end

	-- Feature detection to infer actual major/minor
	local type, table, math, bit32, _G, string = type, table, math, bit32, _G, string
	local has_warn = (type(_G.warn) == "function")
	local has_const_attr = can_load("local x <const> = 1")
	local has_close_attr = can_load("local f <close> = function() end")
	local has_bitwise = can_load("return 1 >> 1") or (type(bit32) == "table")
	local has_goto = can_load("::L:: goto L")
	local has_env_table = false
	do
		local ok, t = safe_pcall(function() return type(_ENV) end)
		if ok and t == "table" then has_env_table = true end
	end
	local has_table_create = (type(table) == "table" and type(table.create) == "function")
	local has_math_type = (type(math) == "table" and type(math.type) == "function")
	local has_integer_subtype = false
	if has_math_type then
		local ok, mtype = safe_pcall(math.type, 1)
		if ok and mtype == "integer" then has_integer_subtype = true end
	end

	-- Determine actual version by feature set
	if has_warn or has_const_attr or has_close_attr or has_table_create then
		info.actual_major, info.actual_minor = 5, 4
	elseif has_bitwise or has_integer_subtype then
		info.actual_major, info.actual_minor = 5, 3
	elseif has_goto or has_env_table or type(bit32) == "table" then
		info.actual_major, info.actual_minor = 5, 2
	else
		info.actual_major, info.actual_minor = 5, 1
	end

	-- Compute numeric representation for actual version
	if info.actual_major > 0 then
		info.actual_version_num = info.actual_major * 100 + (info.actual_minor * 10)
	end

	-- Populate capabilities table
	info.capabilities = {
		luajit = info.is_luajit,
		luajit_version = info.engine_version,
		variant = info.variant or info.engine,
		bitwise = (has_bitwise or (info.actual_major > 5) or (info.actual_major == 5 and info.actual_minor >= 3)),
		integers = has_integer_subtype,
		attributes = has_const_attr or has_close_attr,
		warn = has_warn,
		goto_stmt = has_goto or info.is_luajit,
		env_system = has_env_table or (info.actual_major > 5) or (info.actual_major == 5 and info.actual_minor >= 2),
		table_create = has_table_create,
		math_type = has_math_type,
		has_load = info.has_load,
		has_loadstring = info.has_loadstring,
		load_accepts_env = info.load_accepts_env
	}

	-- Engine string and variant labeling
	if info.is_luajit then
		if _G.ngx and _G.ngx.config then
			info.variant = "OpenResty (LuaJIT)"
		elseif _G.tarantool then
			info.variant = "Tarantool (LuaJIT)"
		else
			info.variant = info.variant or ("LuaJIT" .. (info.engine_version and (" " .. info.engine_version) or ""))
		end
		info.engine = "LuaJIT"
		info.engine_version = info.engine_version or (jit and jit.version)
	else
		if _G.ngx and _G.ngx.config then
			info.variant = info.variant or "OpenResty"
			info.engine = info.engine or "OpenResty"
		elseif _G.tarantool then
			info.variant = info.variant or "Tarantool"
			info.engine = info.engine or "Tarantool"
		else
			info.variant = info.variant or "PUC-Rio Lua"
			info.engine = info.engine or "PUC-Rio Lua"
		end
	end

	-- Spoof detection and convenience strings
	info.spoofed = (info.declared_major ~= info.actual_major) or (info.declared_minor ~= info.actual_minor)
	info.declared_version = info.declared
	info.actual_version = string_format("Lua %d.%d", info.actual_major, info.actual_minor)

	return info
end

-- Export
return detect_runtime -- TODO/CONS: cache it - invoke here?
