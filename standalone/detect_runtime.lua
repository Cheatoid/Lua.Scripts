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
		is_luau = false,
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
		-- Hack instead of parsing `string.dump` bytecode for different runtimes.
		-- NOTE: is_64 is pointer/address width, NOT lua_Integer width.
		-- See has_int64 / integer_bits below for 64-bit integer support.
		is_64 = (jit and jit.arch == "x64") or #tostring {} > #"table: 0x11223344" or false,
		-- Whether native 64-bit integers (lua_Integer is 64-bit) are available.
		-- Resolved safely below (pcall-guarded, no native bitwise syntax so
		-- this file still parses on 5.1/LuaJIT). Distinct from is_64 above.
		has_int64 = false,
		-- Width of native lua_Integer in bits: 64, 32, or nil (no integers
		-- or undetectable, e.g. float-only 5.1/5.2/LuaJIT/Luau or missing loader).
		integer_bits = nil,
		-- Captured math.maxinteger / math.mininteger when present (5.3+).
		maxinteger = nil,
		mininteger = nil,
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

	-- Detect Luau (derived from Lua 5.1, _VERSION == "Luau").
	-- _VERSION match is primary; typeof+buffer/vector/integer markers cover
	-- embedded hosts that spoof _VERSION. Field access only (no calls),
	-- so this is safe on sandboxed hosts. typeof() is Luau-specific;
	-- PUC-Rio/LuaJIT never define it.
	if tostring(info.declared) == "Luau" then
		info.is_luau = true
	elseif type(_G.typeof) == "function"
		and type(_G.bit32) == "table"
		and type(_G.utf8) == "table"
		and type(_G.buffer) == "table"
		and type(_G.vector) == "table"
		and type(_G.integer) == "table" then
		info.is_luau = true
	end
	if info.is_luau then
		info.engine = "Luau"
		info.variant = info.variant or "Luau"
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
			local f = load("return 67", "detect_runtime_test", "t", {})
			if type(f) ~= "function" then return error("no function") end
			local v = f()
			if v ~= 67 then return error("bad return") end
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

	-- 64-bit integer detection (native lua_Integer width).
	local has_int64 = false
	local integer_bits = nil
	do
		-- Probe 1 (most reliable on PUC-Rio 5.3+): math.maxinteger > 2^31-1.
		-- 2147483647 is exactly representable as a double, so this
		-- comparison is precise on every runtime (no precision loss).
		local ok_max, maxint = safe_pcall(function()
			if math and math.maxinteger then return math.maxinteger end
		end)
		local ok_min, minint = safe_pcall(function()
			if math and math.mininteger then return math.mininteger end
		end)
		if ok_max and type(maxint) == "number" then info.maxinteger = maxint end
		if ok_min and type(minint) == "number" then info.mininteger = minint end
		if ok_max and type(maxint) == "number" then
			if maxint > 2147483647 then
				has_int64 = true
				integer_bits = 64
			else
				-- Any integer subtype narrower than 64-bit is 32-bit
				-- (PUC-Rio only ships LUA_32BITS or default 64-bit).
				has_int64 = false
				integer_bits = has_integer_subtype and 32 or nil
			end
		else
			-- Probe 2: string.packsize("j") reports sizeof(lua_Integer).
			-- math-free, so it still works when the math lib is stripped.
			-- Corroboration with native integer syntax is required: some
			-- float-only runtimes expose pack formats without native
			-- integers (e.g. Luau reports packsize("j") == 4 while having
			-- no integer subtype and no native bitwise ops, only bit32).
			-- NOTE: the bit32 *library* is NOT corroboration (Luau has it
			-- with doubles); only native syntax counts.
			local claimed = false
			local ok_sz, sz = safe_pcall(function()
				if string and string.packsize then return string.packsize("j") end
			end)
			if ok_sz and type(sz) == "number"
				and (has_integer_subtype or has_bitwise) then
				integer_bits = sz * 8
				has_int64 = (sz >= 8)
				claimed = true
			end
			if not claimed then
				-- Probe 3 (math-free, lib-free): integer wrap-around semantics.
				-- On 64-bit integer builds 0x7FFF... + 1 wraps to negative
				-- (math.mininteger); on 32-bit builds it wraps to 0 and on
				-- float-only builds (5.1/5.2/LuaJIT/Luau) it stays a positive
				-- double, so only true 64-bit integers yield true.
				-- Hex literals parse on every version (unlike 0b/<<), and the
				-- chunk uses no bitwise operators, so it loads everywhere.
				-- NOTE: must use safe_load (inherits globals), NOT the
				-- env-isolated can_load() above which hides globals.
				local ok_probe, res_probe = safe_load(info.loader,
					"return (0x7FFFFFFFFFFFFFFF + 1) < 0 and 0x7FFFFFFFFFFFFFFF > 2147483647")
				if ok_probe and res_probe == true then
					has_int64 = true
					integer_bits = 64
				elseif ok_probe and res_probe == false then
					has_int64 = false
					-- Distinguish "definitely 32-bit" from "no integers":
					-- if native bitwise ops exist we have at least 32-bit ints.
					if has_bitwise or has_integer_subtype then
						integer_bits = 32
					end
				end
			end
		end
	end
	info.has_int64 = has_int64
	info.integer_bits = integer_bits

	-- Table metamethod support (__len/__pairs/__ipairs on tables).
	-- NOTE: syntax is identical on every version, so can_load() cannot
	-- distinguish here; the probe must be *executed*, not just parsed.
	-- Must use safe_load() (inherits globals), NOT the env-isolated
	-- can_load() above which hides setmetatable/pairs/ipairs.
	-- Expected matrix:
	--   5.1/LuaJIT: none (5.1 honors __len only on userdata, not tables).
	--   5.2/5.3:    all three.
	--   5.4:        __len + __pairs (__ipairs was removed in 5.4).
	local has_table_len, has_table_pairs, has_table_ipairs = false, false, false
	do
		local ok_len, res_len = safe_load(info.loader,
			"return (#setmetatable({1,2,3}, {__len=function(s) return 99 end}) == 99)")
		if ok_len and res_len == true then has_table_len = true end

		local ok_pairs, res_pairs = safe_load(info.loader,
			"local t = setmetatable({a=1}, {__pairs=function(s) return next, {b=2} end}) " ..
			"local k, v for kk, vv in pairs(t) do k, v = kk, vv break end " ..
			"return k == 'b' and v == 2")
		if ok_pairs and res_pairs == true then has_table_pairs = true end

		local ok_ipairs, res_ipairs = safe_load(info.loader,
			"local t = setmetatable({10,20,30}, {__ipairs=function(s) " ..
			"local i = 0 return function() i = i + 1 if i <= 1 then return i, 42 end end end}) " ..
			"local k, v for kk, vv in ipairs(t) do k, v = kk, vv break end " ..
			"return k == 1 and v == 42")
		if ok_ipairs and res_ipairs == true then has_table_ipairs = true end
	end
	info.has_table_len = has_table_len
	info.has_table_pairs = has_table_pairs
	info.has_table_ipairs = has_table_ipairs

	-- Determine actual version by feature set
	-- Luau is pinned to its 5.1 base (like LuaJIT below): its 5.2+ looking
	-- features (bit32 lib, table.create, continue, +=) are backports, not
	-- PUC-Rio version markers. Without the pin, table.create alone would
	-- misreport Luau as 5.4.
	if info.is_luau then
		info.actual_major, info.actual_minor = 5, 1
	elseif has_const_attr or has_close_attr or has_table_create or has_warn then
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
		luau = info.is_luau,
		variant = info.variant or info.engine,
		bitwise = has_bitwise or (info.actual_major > 5) or (info.actual_major == 5 and info.actual_minor >= 3),
		integers = has_integer_subtype,
		int64 = has_int64,
		integer_bits = integer_bits,
		attributes = has_const_attr or has_close_attr,
		warn = has_warn,
		goto_stmt = has_goto or info.is_luajit,
		continue_stmt = has_continue,
		compound_assignment = has_compound_assignment,
		binary_literal = has_binary_literal,
		unicode_escape = has_unicode_escape,
		env_system = has_env_table or (info.actual_major > 5) or (info.actual_major == 5 and info.actual_minor >= 2),
		table_create = has_table_create,
		table_len = has_table_len,
		table_pairs = has_table_pairs,
		table_ipairs = has_table_ipairs,
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
		if info.is_luau then
			info.variant = info.variant or "Luau"
			info.engine = info.engine or "Luau"
		elseif _G.ngx and _G.ngx.config then
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
	-- "Luau" declares no numbers (declared 0.0 vs base 5.1); that is its
	-- legitimate _VERSION, not spoofing.
	if info.is_luau and tostring(info.declared) == "Luau" then
		info.spoofed = false
	end
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
