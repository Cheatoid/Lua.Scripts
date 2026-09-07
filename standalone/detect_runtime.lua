-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Lua runtime/version detector

-- Localized global functions for better performance
local pcall, type, tostring, tonumber, error = pcall, type, tostring, tonumber, error
local string_match, string_format = string.match, string.format

local function safe_pcall(...)
	local ok, res = pcall(...)
	return ok, res
end

local function safe_load(loader, ...)
	local ok, res = safe_pcall(loader or loadstring or load, ...)
	if ok and type(res) == "function" then
		return safe_pcall(res)
	end
end

-- Sandboxed hosts (e.g. nanos-world without '--enable_unsafe_libs') replace
-- unsafe functions such as os.getenv with stubs that throw
-- "Called a disabled unsafe function." when invoked. Field access is safe,
-- but *calling* them is not, so every OS/env probe below is pcall-guarded
-- and never invoked directly.
local function safe_os_getenv(name)
	local ok, res = safe_pcall(function()
		if os and os.getenv then return os.getenv(name) end
	end)
	if ok then return res end
end

local function safe_package_sep()
	local ok, res = safe_pcall(function()
		if package and package.config then return string.sub(package.config, 1, 1) end
	end)
	if ok then return res end
end

local function safe_jit_os()
	local ok, res = safe_pcall(function()
		if jit and jit.os then return jit.os end
	end)
	if ok then return res end
end

local function detect_is_windows()
	if safe_package_sep() == "\\" then return true end
	if safe_os_getenv("OS") == "Windows_NT" then return true end
	if safe_jit_os() == "Windows" then return true end
	return false
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
		capabilities = nil,

		-- Misc
		spoofed = false,
		-- Hack instead of parsing string.dump bytecode for different runtimes
		is_64 = (jit and jit.arch == "x64") or #tostring {} > #"table: 0x11223344" or false,
		-- Resolved safely below via detect_is_windows() (pcall-guarded, see above).
		-- Never call os.getenv / io.popen etc. directly here: they throw
		-- "Called a disabled unsafe function." on sandboxed hosts (nanos-world).
		is_windows = false,
	}

	-- Detect platform without ever calling a disabled unsafe function directly
	info.is_windows = detect_is_windows()

	-- Parse declared _VERSION string
	do
		local dmaj, dmin = string_match(tostring(info.declared), "Lua%s*(%d+)%.(%d+)")
		info.declared_major = tonumber(dmaj) or 0
		info.declared_minor = tonumber(dmin) or 0
	end

	-- Detect LuaJIT and metadata
	if type(jit) == "table" then -- or pcall(require, "jit")
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
	local load = load
	info.has_load = (type(load) == "function")
	info.has_loadstring = (type(loadstring) == "function")
	info.loader = info.has_load and load or loadstring

	-- Check whether load accepts the 4th env parameter (Lua 5.2+ signature)
	if info.has_load then
		local ok = safe_pcall(function()
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
	local can_load = function(chunk)
		if not info.loader then return false end
		-- If load accepts env, call with env to avoid polluting globals
		local ok, res
		if info.load_accepts_env then
			ok, res = safe_pcall(function() return load(chunk, "detect_runtime", "t", {}) end)
		else
			-- loadstring or load without env
			ok, res = safe_pcall(function() return info.loader(chunk) end)
		end
		-- load() returns nil, errmsg on syntax errors (not a pcall error),
		-- so we must verify the result is an actual function
		return ok and type(res) == "function"
	end

	-- Feature detection to infer actual major/minor
	local table, math, _G = table, math, _G
	local has_warn = (type(_G.warn) == "function")
	local has_const_attr = can_load("local x <const> = 1")
	local has_close_attr = can_load("local f <close> = function() end")
	local has_bitwise = can_load("return 1 >> 1, ~0") --or (type(bit32) == "table")
	local has_goto = can_load("::L:: goto L")
	local has_continue = can_load("while false do continue end")
	local has_compound_assignment = can_load("local i = 1;i += i")
	local has_binary_literal = can_load("return 0b1 == 1")
	local has_unicode_escape = can_load("return #'\u{25CF}' == 3")
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
	if has_const_attr or has_close_attr or has_table_create or has_warn then
		info.actual_major, info.actual_minor = 5, 4
	elseif has_bitwise or has_integer_subtype then
		info.actual_major, info.actual_minor = 5, 3
	elseif (has_goto and not info.is_luajit) or has_env_table or type(bit32) == "table" then
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
		bitwise = has_bitwise or (info.actual_major > 5) or (info.actual_major == 5 and info.actual_minor >= 3),
		integers = has_integer_subtype,
		attributes = has_const_attr or has_close_attr,
		warn = has_warn,
		goto_stmt = has_goto or info.is_luajit,
		continue_stmt = has_continue,
		compound_assignment = has_compound_assignment,
		binary_literal = has_binary_literal,
		unicode_escape = has_unicode_escape,
		env_system = has_env_table or (info.actual_major > 5) or (info.actual_major == 5 and info.actual_minor >= 2),
		table_create = has_table_create,
		math_type = has_math_type,
		has_load = info.has_load,
		has_loadstring = info.has_loadstring,
		load_accepts_env = info.load_accepts_env,
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

	-- Fix for StarfallEx (Garry's Mod scriptable entity)
	if info.spoofed and _VERSION == nil and type(bit) == "table" and type(net) == "table" and type(chip) == "function"
		and type(concmd) == "function" and type(loadstring) == "function" then
		info.is_64 = info.is_64 and info.capabilities.binary_literal and
			safe_load(info.loader, "return 0b1 == 1 and #'\u{25CF}' == 3") or false
		info.spoofed = false
		info.actual_major, info.actual_minor = 5, 1
		info.is_luajit = true
		info.engine = "LuaJIT"
		info.engine_version = info.is_64 and "LuaJIT 2.1.0-beta3" or "LuaJIT 2.0.4"
		info.variant = "StarfallEx"
		info.luajit_version_num = info.is_64 and 20100 or 20004
	end

	return info
end

-- Export
return detect_runtime -- TODO/CONS: cache it - invoke here?
