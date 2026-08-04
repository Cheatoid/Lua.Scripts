-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

--[[
Package manager library

Example:
	local luapm = require "pm"
	local pm = luapm.new {
		repo = "https://example.com/index.json",       -- single repo (priority 0)
		-- or:
		repos = {
			{ source = "https://primary.example.com/index.json", priority = 10 },
			{ source = "/local/index.json",               priority = 5  },
			{ source = function(name) return ... end,     priority = 1  },
		},
		install_root = "vendor",
		db_path = ".packages",
		cache_dir   = ".luapm-cache",                  -- optional; "" disables caching
		http = { get = function(url) return body_or_nil, err end },
		fs = { ... },
		codec = { decode = function(text) end, encode = function(value) end },
		hooks = { ... }
	}

	assert(pm:install("foo"))
	assert(pm:install("foo", ">=1.2,<2.0"))
	assert(pm:install("foo", nil, { orphans = true }))
	local installed = pm:list_installed()
	local found = pm:search("foo")
	local info = pm:get_installed("foo")
	local outdated = pm:outdated()
	local ok, errs = pm:verify("foo")
	assert(pm:update("foo"))
	assert(pm:remove("foo", { orphans = true }))
--]]

-- Localized global functions for better performance
local error = error
local pcall = pcall
local tonumber = tonumber
local tostring = tostring
local type = type
local math_floor = math.floor
local math_max = math.max
local string_byte = string.byte
local string_char = string.char
local string_find = string.find
local string_format = string.format
local string_gmatch = string.gmatch
local string_gsub = string.gsub
local string_lower = string.lower
local string_match = string.match
local string_rep = string.rep
local string_sub = string.sub
local table_concat = table.concat
local table_remove = table.remove
local table_sort = table.sort
local table_unpack = table.unpack or unpack

local luapm = {}
local Manager = {}
Manager.__index = Manager

-- Platform abstraction layer
-- Users can override these via config.platform or by modifying luapm.platform
luapm.platform = {
	io_open    = io and io.open,
	io_popen   = io and io.popen,
	os_clock   = os and os.clock,
	os_execute = os and os.execute,
	os_remove  = os and os.remove,
	os_rename  = os and os.rename,
	os_time    = os and os.time,
	-- Detect platform safely without requiring package.config
	is_windows =
		(package and package.config and string_sub(package.config, 1, 1) == "\\")
		or (os and os.getenv and os.getenv("OS") == "Windows_NT")
		or (jit and jit.os == "Windows"),
}

-- Helper to get null device based on current platform config
local function get_null_dev()
	return luapm.platform.is_windows and "NUL" or "/dev/null"
end

----------------------------------------------------------------------
-- Utility
----------------------------------------------------------------------
local Util = {}

function Util.trim(s)
	if s == nil then return "" end
	return (string_gsub(string_gsub(tostring(s), "^%s+", ""), "%s+$", ""))
end

function Util.quote(s)
	return '"' .. string_gsub(tostring(s), '"', '\\"') .. '"'
end

function Util.is_url(s)
	return type(s) == "string" and string_match(s, "^https?://") ~= nil
end

function Util.deepcopy(v, seen)
	if type(v) ~= "table" then return v end
	seen = seen or {}
	if seen[v] then return seen[v] end
	local out = {}
	seen[v] = out
	for k, vv in next, v do
		out[Util.deepcopy(k, seen)] = Util.deepcopy(vv, seen)
	end
	return out
end

function Util.split_version(v)
	local out = {}
	for part in string_gmatch(tostring(v or "0"), "[^%._%-]+") do
		out[#out + 1] = tonumber(part) or part
	end
	return out
end

function Util.cmp_version(a, b)
	local aa, bb = Util.split_version(a), Util.split_version(b)
	local maxn = math_max(#aa, #bb)
	for i = 1, maxn do
		local x = aa[i]
		local y = bb[i]
		if x == nil and y ~= nil then return -1 end
		if y == nil and x ~= nil then return 1 end
		if x ~= y then
			if type(x) == "number" and type(y) == "number" then
				return x > y and 1 or -1
			end
			return tostring(x) > tostring(y) and 1 or -1
		end
	end
	return 0
end

function Util.split(s, sep)
	local out, i = {}, 1
	while i <= #s do
		local a, b = string_find(s, sep, i, true)
		if not a then
			out[#out + 1] = string_sub(s, i)
			break
		end
		out[#out + 1] = string_sub(s, i, a - 1)
		i = b + 1
	end
	return out
end

-- Resolves ./, ../, and normalizes separators to /
function Util.normalize_path(p)
	if not p then return nil end
	p = string_gsub(tostring(p), "\\", "/")
	local parts = {}
	for part in string_gmatch(p, "[^/]+") do
		if part == ".." then
			if #parts > 0 and parts[#parts] ~= ".." then
				parts[#parts] = nil
			else
				parts[#parts + 1] = ".."
			end
		elseif part ~= "." then
			parts[#parts + 1] = part
		end
	end
	local result = table_concat(parts, "/")
	if string_sub(p, 1, 1) == "/" then result = "/" .. result end
	if result == "" then result = "." end
	return result
end

-- Safely joins a root path with a relative path, preventing path traversal
function Util.safe_join(root, rel)
	if not root or not rel then return nil, "safe_join requires root and rel" end
	root = string_gsub(tostring(root), "\\", "/")
	rel = string_gsub(tostring(rel), "\\", "/")

	-- Reject absolute paths
	if string_sub(rel, 1, 1) == "/" then return nil, "absolute path not allowed in safe_join" end

	-- Reject Windows drive letters (e.g., C:, D:)
	if string_match(rel, "^[A-Za-a]:") then return nil, "Windows drive letter not allowed in safe_join" end

	-- Reject .. components to prevent traversal
	if string_match(rel, "%.%.") then return nil, "path traversal (..) not allowed in safe_join" end

	local resolved = string_gsub(root, "[/\\]+$", "") .. "/" .. string_gsub(rel, "^[/\\]+", "")
	resolved = Util.normalize_path(resolved)

	-- Final containment check: ensure resolved path starts with root
	local norm_root = Util.normalize_path(root)
	if string_sub(resolved, 1, #norm_root) ~= norm_root then
		return nil, "resolved path escapes root directory"
	end

	return resolved
end

----------------------------------------------------------------------
-- Version constraints
----------------------------------------------------------------------
local VersionConstraint = {}
VersionConstraint.__index = VersionConstraint

local OP_FUNCS = {
	["=="] = function(c) return function(v) return Util.cmp_version(v, c) == 0 end end,
	["!="] = function(c) return function(v) return Util.cmp_version(v, c) ~= 0 end end,
	[">="] = function(c) return function(v) return Util.cmp_version(v, c) >= 0 end end,
	["<="] = function(c) return function(v) return Util.cmp_version(v, c) <= 0 end end,
	[">"] = function(c) return function(v) return Util.cmp_version(v, c) > 0 end end,
	["<"] = function(c) return function(v) return Util.cmp_version(v, c) < 0 end end,
}

function VersionConstraint._parse_clause(text)
	text = Util.trim(text)
	if text == "" or text == "*" or text == "any" then return {} end

	local op, ver = string_match(text, "^(%~%>)%s*(.+)$")
	if op then
		local parts = Util.split_version(ver)
		if #parts < 2 then return nil, "invalid ~> constraint: " .. text end
		local upper = {}
		for j = 1, #parts do upper[#upper + 1] = parts[j] end
		upper[#upper] = (tonumber(upper[#upper]) or 0) + 1
		return {
			{ op = ">=", ver = table_concat(parts, ".") },
			{ op = "<",  ver = table_concat(upper, ".") },
		}
	end

	-- Check multi-char and single-char operators strictly
	local ops = { ">=", "<=", "==", "!=", ">", "<" }
	for i = 1, #ops do
		local o = ops[i]
		if string_sub(text, 1, #o) == o then
			return { { op = o, ver = Util.trim(string_sub(text, #o + 1)) } }
		end
	end

	-- bare version: exact equality
	return { { op = "==", ver = text } }
end

function VersionConstraint.parse(spec)
	if spec == nil then spec = "*" end
	if type(spec) == "table" and spec._is_constraint then return spec end

	local clauses = {}
	local parts = Util.split(tostring(spec), ",")
	for i = 1, #parts do
		local parsed, err = VersionConstraint._parse_clause(parts[i])
		if not parsed then return nil, err end
		for j = 1, #parsed do clauses[#clauses + 1] = parsed[j] end
	end
	return setmetatable({ clauses = clauses, text = tostring(spec) }, VersionConstraint)
end

function VersionConstraint:matches(version)
	if version == nil then return false end
	for i = 1, #self.clauses do
		local c = self.clauses[i]
		local fn = OP_FUNCS[c.op]
		if not fn or not fn(c.ver)(version) then return false end
	end
	return true
end

VersionConstraint._is_constraint = true

function Util.normalize_dependencies(deps)
	local out = {}
	for i = 1, #(deps or {}) do
		local d = deps[i]
		if type(d) == "string" then
			out[#out + 1] = { name = d }
		elseif type(d) == "table" and d.name then
			local entry = { name = d.name }
			if d.version ~= nil then
				if type(d.version) == "table" and d.version._is_constraint then
					entry.version = d.version
				else
					local cons, err = VersionConstraint.parse(d.version)
					if not cons then return nil, "invalid version constraint for '" .. d.name .. "': " .. err end
					entry.version = cons
				end
			end
			out[#out + 1] = entry
		else
			return nil, "invalid dependency entry"
		end
	end
	return out
end

----------------------------------------------------------------------
-- Default filesystem adapter using injected platform
----------------------------------------------------------------------
local DefaultFS = {}

function DefaultFS.read(path)
	local open = luapm.platform.io_open
	if not open then return nil, "io.open not available" end
	local f, err = open(path, "rb")
	if not f then return nil, err end
	local data = f:read("*a")
	f:close()
	return data
end

function DefaultFS.write(path, data)
	local open = luapm.platform.io_open
	if not open then return nil, "io.open not available" end
	local f, err = open(path, "wb")
	if not f then return nil, err end
	f:write(data)
	f:close()
	return true
end

function DefaultFS.remove(path)
	local remove = luapm.platform.os_remove
	if not remove then return nil, "os.remove not available" end
	return remove(path)
end

function DefaultFS.exists(path)
	local open = luapm.platform.io_open
	if not open then return false end
	local f = open(path, "rb")
	if f then
		f:close()
		return true
	end
	return false
end

function DefaultFS.dirname(path)
	return string_match(tostring(path), "^(.*)[/\\][^/\\]+$")
end

function DefaultFS.join(a, b)
	if not a or a == "" then return b end
	if not b or b == "" then return a end
	return string_gsub(tostring(a), "[/\\]+$", "") .. "/" .. string_gsub(tostring(b), "^[/\\]+", "")
end

function DefaultFS.mkdir_p(path)
	if not path or path == "" then return true end
	local execute = luapm.platform.os_execute
	if not execute then return nil, "os.execute not available; provide custom fs.mkdir_p" end
	local null = get_null_dev()
	local cmd
	if luapm.platform.is_windows then
		cmd = "mkdir " .. Util.quote(path) .. " > " .. null .. " 2> " .. null
	else
		cmd = "mkdir -p " .. Util.quote(path) .. " > " .. null .. " 2> " .. null
	end
	if execute(cmd) then
		return true, "unable to create directory: " .. path
	end
	return nil, "unable to create directory: " .. path
end

function DefaultFS.prune_empty_dirs(root, file)
	local remove = luapm.platform.os_remove
	if not remove then return end
	root = string_gsub(tostring(root or ""), "[/\\]+$", "")
	local dir = DefaultFS.dirname(file)
	while dir and dir ~= "" and string_sub(dir, 1, #root) == root do
		if not remove(dir) then break end
		if dir == root then break end
		dir = DefaultFS.dirname(dir)
	end
end

function DefaultFS.list_dir(path)
	local files = {}
	local popen = luapm.platform.io_popen
	if not popen then return files end
	local null = get_null_dev()
	local cmd = luapm.platform.is_windows
		and ("dir /b " .. Util.quote(path) .. " 2>" .. null)
		or ("ls -1 " .. Util.quote(path) .. " 2>" .. null)
	local p = popen(cmd, "r")
	if p then
		for line in p:lines() do
			if line ~= "" then files[#files + 1] = line end
		end
		p:close()
	end
	return files
end

----------------------------------------------------------------------
-- Default transport adapter using injected platform
----------------------------------------------------------------------
local DefaultHTTP = {}

function DefaultHTTP.get(url)
	if type(url) ~= "string" or url == "" then
		return nil, "http.get requires a non-empty URL or path"
	end
	if not Util.is_url(url) then
		return DefaultFS.read(string_gsub(url, "^file://", ""))
	end
	local popen = luapm.platform.io_popen
	if not popen then
		return nil, "HTTP unavailable; provide config.http.get(url)"
	end
	local null = get_null_dev()
	local commands = {
		"curl -fsSL " .. Util.quote(url) .. " 2>" .. null,
		"wget -qO- " .. Util.quote(url) .. " 2>" .. null,
	}
	for i = 1, #commands do
		local p = popen(commands[i], "r")
		if p then
			local data = p:read("*a")
			local ok = p:close()
			if ok and data and data ~= "" then return data end
		end
	end
	return nil, "unable to fetch '" .. url .. "'; provide config.http.get or install curl/wget"
end

----------------------------------------------------------------------
-- Codec: JSON decoder + Lua encoder/decoder for local DB
----------------------------------------------------------------------
local DefaultCodec = {}

function DefaultCodec.encode_lua(v)
	local t = type(v)
	if t == "nil" or t == "number" or t == "boolean" then
		return tostring(t == "nil" and "nil" or v)
	end
	if t == "string" then return string_format("%q", v) end
	if t ~= "table" then error("cannot encode type: " .. t) end
	local out = { "{" }
	for k, vv in next, v do
		local key
		if type(k) == "string" and string_match(k, "^[_%a][_%w]*$") then
			key = k
		else
			key = "[" .. DefaultCodec.encode_lua(k) .. "]"
		end
		out[#out + 1] = key .. "=" .. DefaultCodec.encode_lua(vv) .. ","
	end
	out[#out + 1] = "}"
	return table_concat(out)
end

function DefaultCodec.decode_lua(text, chunk_name)
	local chunk, err
	if loadstring and setfenv then
		-- Lua 5.1: loadstring + setfenv for sandboxing
		local ok, c, e = pcall(loadstring, text, chunk_name or "=(luapm)")
		if not ok then return nil, c end
		chunk, err = c, e
		if chunk then setfenv(chunk, {}) end
	else
		-- Lua 5.2+: load with env parameter for sandboxing
		local ok, c, e = pcall(load, text, chunk_name or "=(luapm)", "t", {})
		if not ok then return nil, c end
		chunk, err = c, e
	end
	if not chunk then return nil, err end
	local ok, result = pcall(chunk)
	if not ok then return nil, result end
	return result
end

function DefaultCodec.decode_json(text)
	local pos, len = 1, #text
	local parse_value

	local function fail(msg) error("json error at " .. pos .. ": " .. msg, 0) end
	local function skip_ws()
		while pos <= len and string_match(string_sub(text, pos, pos), "%s") do pos = pos + 1 end
	end

	local function parse_string()
		if string_sub(text, pos, pos) ~= '"' then fail("expected string") end
		pos = pos + 1
		local out = {}
		while pos <= len do
			local c = string_sub(text, pos, pos)
			if c == '"' then
				pos = pos + 1; return table_concat(out)
			elseif c == "\\" then
				local e = string_sub(text, pos + 1, pos + 1)
				local map = { ['"'] = '"', ["\\"] = "\\", ["/"] = "/", b = "\b", f = "\f", n = "\n", r = "\r", t = "\t" }
				if e == "u" then
					local hex = string_sub(text, pos + 2, pos + 5)
					if not string_match(hex, "^%x%x%x%x$") then fail("bad unicode escape") end
					out[#out + 1] = string_char(tonumber(hex, 16) % 256)
					pos = pos + 6
				elseif map[e] then
					out[#out + 1] = map[e]; pos = pos + 2
				else
					fail("bad escape")
				end
			else
				out[#out + 1] = c; pos = pos + 1
			end
		end
		fail("unterminated string")
	end

	local function parse_number()
		local s = string_match(text, "^-?%d+%.?%d*[eE]?[+-]?%d*", pos)
		if not s then fail("bad number") end
		pos = pos + #s
		return tonumber(s)
	end

	local function parse_array()
		pos = pos + 1; skip_ws()
		local out = {}
		if string_sub(text, pos, pos) == "]" then
			pos = pos + 1; return out
		end
		while true do
			out[#out + 1] = parse_value(); skip_ws()
			local c = string_sub(text, pos, pos)
			if c == "]" then
				pos = pos + 1; return out
			end
			if c ~= "," then fail("expected ',' or ']'") end
			pos = pos + 1; skip_ws()
		end
	end

	local function parse_object()
		pos = pos + 1; skip_ws()
		local out = {}
		if string_sub(text, pos, pos) == "}" then
			pos = pos + 1; return out
		end
		while true do
			local key = parse_string(); skip_ws()
			if string_sub(text, pos, pos) ~= ":" then fail("expected ':'") end
			pos = pos + 1; skip_ws()
			out[key] = parse_value(); skip_ws()
			local c = string_sub(text, pos, pos)
			if c == "}" then
				pos = pos + 1; return out
			end
			if c ~= "," then fail("expected ',' or '}'") end
			pos = pos + 1; skip_ws()
		end
	end

	function parse_value()
		skip_ws()
		local c = string_sub(text, pos, pos)
		if c == '"' then return parse_string() end
		if c == "{" then return parse_object() end
		if c == "[" then return parse_array() end
		if c == "-" or string_match(c, "%d") then return parse_number() end
		if string_sub(text, pos, pos + 3) == "true" then
			pos = pos + 4; return true
		end
		if string_sub(text, pos, pos + 4) == "false" then
			pos = pos + 5; return false
		end
		if string_sub(text, pos, pos + 3) == "null" then
			pos = pos + 4; return nil
		end
		fail("unexpected token")
	end

	local ok, result = pcall(parse_value)
	if not ok then return nil, result end
	skip_ws()
	if pos <= len then return nil, "json error at " .. pos .. ": trailing content" end
	return result
end

function DefaultCodec.decode(text)
	local first = string_match(text, "^%s*(.)")
	if first == "{" or first == "[" then return DefaultCodec.decode_json(text) end
	return DefaultCodec.decode_lua(text, "=(luapm-data)")
end

function DefaultCodec.encode(value)
	return "return " .. DefaultCodec.encode_lua(value) .. "\n"
end

----------------------------------------------------------------------
-- Integrity checking
----------------------------------------------------------------------
local Integrity = {}
local HEX_PATTERN = "^[0-9a-fA-F]+$"

local Sha256 = {}
do
	local K = {
		0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
		0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
		0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
		0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
		0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
		0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
		0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
		0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
	}

	-- Pure math bitwise ops for 32-bit integers (no large tables needed)
	local function bxor32(a, b)
		local res, p = 0, 1
		a = a % 2 ^ 32; b = b % 2 ^ 32
		for _ = 1, 32 do
			if (a % 2) ~= (b % 2) then res = res + p end
			a = math_floor(a / 2); b = math_floor(b / 2)
			p = p * 2
			if a == 0 and b == 0 then break end
		end
		return res
	end

	local function band32(a, b)
		local res, p = 0, 1
		a = a % 2 ^ 32; b = b % 2 ^ 32
		for _ = 1, 32 do
			if a % 2 == 1 and b % 2 == 1 then res = res + p end
			a = math_floor(a / 2); b = math_floor(b / 2)
			p = p * 2
			if a == 0 or b == 0 then break end
		end
		return res
	end

	local function rshift32(x, n) return math_floor((x % 2 ^ 32) / 2 ^ n) end
	local function rrotate32(x, n)
		x = x % 2 ^ 32
		return (rshift32(x, n) + (x % 2 ^ n) * 2 ^ (32 - n)) % 2 ^ 32
	end

	local function tobytes(u32)
		return string_char(
			math_floor(u32 / 0x1000000) % 0x100,
			math_floor(u32 / 0x10000) % 0x100,
			math_floor(u32 / 0x100) % 0x100,
			u32 % 0x100
		)
	end

	function Sha256.hex(data)
		if type(data) ~= "string" then return nil end
		local H = {
			0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
			0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
		}
		local len = #data
		local msg_len = len + 1
		local pad_needed = (64 - ((msg_len + 8) % 64)) % 64
		local msg = data .. "\128" .. string_rep("\0", pad_needed)
		local len_bits = len * 8
		msg = msg .. "\0\0\0\0" .. tobytes(len_bits % 2 ^ 32)

		local W = {}
		local i = 1
		while i <= #msg do
			for j = 1, 16 do
				local s = i + (j - 1) * 4
				W[j] = (string_byte(msg, s) * 0x1000000
					+ string_byte(msg, s + 1) * 0x10000
					+ string_byte(msg, s + 2) * 0x100
					+ string_byte(msg, s + 3)) % 2 ^ 32
			end
			for j = 17, 64 do
				local w15 = W[j - 15]
				local s0 = bxor32(bxor32(rrotate32(w15, 7), rrotate32(w15, 18)), rshift32(w15, 3))
				local w2 = W[j - 2]
				local s1 = bxor32(bxor32(rrotate32(w2, 17), rrotate32(w2, 19)), rshift32(w2, 10))
				W[j] = (W[j - 16] + s0 + W[j - 7] + s1) % 2 ^ 32
			end
			local a, b, c, d, e, f, g, h = H[1], H[2], H[3], H[4], H[5], H[6], H[7], H[8]
			for j = 1, 64 do
				local S1 = bxor32(bxor32(rrotate32(e, 6), rrotate32(e, 11)), rrotate32(e, 25))
				local ch = bxor32(band32(e, f), band32(4294967295 - e, g))
				local t1 = (h + S1 + ch + K[j] + W[j]) % 2 ^ 32
				local S0 = bxor32(bxor32(rrotate32(a, 2), rrotate32(a, 13)), rrotate32(a, 22))
				local maj = bxor32(bxor32(band32(a, b), band32(a, c)), band32(b, c))
				local t2 = (S0 + maj) % 2 ^ 32
				h = g; g = f; f = e; e = (d + t1) % 2 ^ 32
				d = c; c = b; b = a; a = (t1 + t2) % 2 ^ 32
			end
			H[1] = (H[1] + a) % 2 ^ 32; H[2] = (H[2] + b) % 2 ^ 32
			H[3] = (H[3] + c) % 2 ^ 32; H[4] = (H[4] + d) % 2 ^ 32
			H[5] = (H[5] + e) % 2 ^ 32; H[6] = (H[6] + f) % 2 ^ 32
			H[7] = (H[7] + g) % 2 ^ 32; H[8] = (H[8] + h) % 2 ^ 32
			i = i + 64
		end
		local out = {}
		for k = 1, 8 do out[#out + 1] = string_format("%08x", H[k]) end
		return table_concat(out)
	end
end
Integrity.sha256 = Sha256.hex

function Integrity.verify(data, expected)
	if expected == nil or expected == "" then return true end
	if type(expected) ~= "string" then return nil, "invalid hash specification" end

	local algo, hex = string_match(expected, "^([%w%-]+):([0-9a-fA-F]+)$")
	if algo then
		if algo ~= "sha256" then return nil, "unsupported hash algorithm: " .. algo end
	else
		algo, hex = "sha256", expected
	end
	if not string_match(hex, HEX_PATTERN) then return nil, "invalid hash format" end

	local computed = Integrity.sha256(data)
	if not computed then return nil, "hash computation failed" end
	if string_lower(computed) ~= string_lower(hex) then
		return nil, "integrity check failed: expected " .. algo .. ":" .. string_lower(hex) .. ", got " .. computed
	end
	return true
end

----------------------------------------------------------------------
-- Validation & Storage
----------------------------------------------------------------------
local Validator = {}

function Validator.normalize_manifest(m)
	if type(m) ~= "table" then return nil, "manifest must be a table" end
	if m.url and m.path and not m.files then m.files = { { path = m.path, url = m.url } } end
	if not m.name or not m.version then return nil, "package manifest is missing name/version" end
	local deps, err = Util.normalize_dependencies(m.dependencies)
	if not deps then return nil, err end
	m.dependencies = deps
	m.files = m.files or {}
	for i = 1, #m.files do
		local f = m.files[i]
		if type(f) ~= "table" or not f.path or (f.url == nil and f.content == nil) then
			return nil, "invalid file entry for package '" .. tostring(m.name) .. "'"
		end
	end
	return m
end

function Validator.normalize_repo(raw)
	if type(raw) ~= "table" then return nil, "repository must decode to a table" end
	if raw.packages then raw = raw.packages end
	if #raw > 0 then return raw end
	local out = {}
	for k, v in next, raw do
		if type(v) == "table" then
			v.name = v.name or k; out[#out + 1] = v
		end
	end
	return out
end

local Storage = {}
Storage.__index = Storage

function Storage.new(fs, codec, db_path)
	return setmetatable({ fs = fs, codec = codec, db_path = db_path }, Storage)
end

function Storage:load()
	local raw = self.fs.read(self.db_path)
	if not raw or raw == "" then return { packages = {} } end
	local data, err = self.codec.decode(raw)
	if not data then return nil, "invalid package database: " .. err end
	if type(data) ~= "table" then return nil, "invalid package database content" end
	data.packages = data.packages or {}
	return data
end

function Storage:save(db)
	local text = self.codec.encode(db)
	local ok, err = self.fs.write(self.db_path, text)
	if not ok then return nil, "database write failed: " .. err end
	return true
end

----------------------------------------------------------------------
-- Cache & Transport
----------------------------------------------------------------------
local Cache = {}
Cache.__index = Cache

function Cache.new(fs, dir)
	if not dir or dir == "" then return nil end
	return setmetatable({ fs = fs, dir = dir, mem = {}, ready = false }, Cache)
end

function Cache:_ensure()
	if self.ready then return true end
	if self.fs.mkdir_p then
		local ok, err = self.fs.mkdir_p(self.dir)
		if not ok then return nil, err end
	end
	self.ready = true
	return true
end

function Cache:get(key)
	if self.mem[key] ~= nil then return self.mem[key] end
	local ok = self:_ensure()
	if not ok then return nil end
	local path = self.dir .. "/" .. string_gsub(key, "[^%w%.%-]", "_")
	local data = self.fs.read(path)
	if data == nil then return nil end
	self.mem[key] = data
	return data
end

function Cache:put(key, data)
	self.mem[key] = data
	local ok = self:_ensure()
	if not ok then return true end
	local path = self.dir .. "/" .. string_gsub(key, "[^%w%.%-]", "_")
	self.fs.write(path, data)
	return true
end

function Cache:clear()
	self.mem = {}
	if not self.ready then return true end
	if self.fs.list_dir then
		local files = self.fs.list_dir(self.dir)
		for i = 1, #files do
			self.fs.remove(self.dir .. "/" .. files[i])
		end
	end
	return true
end

local CachedHTTP = {}
CachedHTTP.__index = CachedHTTP

function CachedHTTP.new(inner, cache, fs)
	return setmetatable({ inner = inner, cache = cache, fs = fs }, CachedHTTP)
end

function CachedHTTP:get(url)
	local key = "http:" .. url
	if self.cache then
		local hit = self.cache:get(key)
		if hit ~= nil then return hit end
	end
	local data, err = self.inner(url)
	if not data then return nil, err end
	if self.cache then self.cache:put(key, data) end
	return data
end

function CachedHTTP:clear_cache()
	if self.cache then self.cache:clear() end
end

----------------------------------------------------------------------
-- Repositories
----------------------------------------------------------------------
local Repository = {}
Repository.__index = Repository

function Repository.new(repo_source, http, codec, priority)
	return setmetatable({
		source = repo_source, http = http, codec = codec, cache = nil, priority = priority or 0,
	}, Repository)
end

function Repository:clear_cache() self.cache = nil end

function Repository:_read_source(name)
	local source = self.source
	if type(source) == "function" then return source(name) end
	if type(source) == "table" then return source end
	if type(source) ~= "string" or source == "" then return nil, "repository source is not configured" end
	return self.http.get(source)
end

function Repository:_decode_source(raw)
	if type(raw) == "table" then return Validator.normalize_repo(raw) end
	if type(raw) ~= "string" then return nil, "repository source returned unsupported type" end
	local first = string_match(raw, "^%s*(.)")
	if first == "{" or first == "[" then
		local decoded, err = self.codec.decode(raw)
		if not decoded then return nil, err end
		return Validator.normalize_repo(decoded)
	end
	local out = {}
	for line in string_gmatch(raw, "[^\r\n]+") do
		line = Util.trim(line)
		if line ~= "" and string_sub(line, 1, 1) ~= "#" then out[#out + 1] = { manifest_url = line } end
	end
	return out
end

function Repository:load(name)
	if self.cache then return self.cache end
	local raw, err = self:_read_source(name)
	if not raw then return nil, "repository read failed: " .. err end
	local repo, derr = self:_decode_source(raw)
	if not repo then return nil, derr end
	self.cache = repo
	return repo
end

function Repository:hydrate(entry)
	if entry._hydrated or not entry.manifest_url then return Validator.normalize_manifest(entry) end
	local raw, err = self.http.get(entry.manifest_url)
	if not raw then return nil, "manifest fetch failed: " .. err end
	local decoded, derr = self.codec.decode(raw)
	if not decoded then return nil, derr end
	if type(decoded) ~= "table" then return nil, "manifest must decode to a table" end
	for k, v in next, decoded do entry[k] = v end
	entry._hydrated = true
	return Validator.normalize_manifest(entry)
end

function Repository:find(name, constraint)
	local repo, err = self:load(name)
	if not repo then return nil, err end
	local cons = constraint
	if cons and not (type(cons) == "table" and cons._is_constraint) then
		cons = VersionConstraint.parse(cons)
	end
	local best = nil
	for i = 1, #repo do
		local m = self:hydrate(repo[i])
		if m and m.name == name then
			local match = true
			if cons and not cons:matches(m.version) then match = false end
			if match then
				if not best or Util.cmp_version(m.version, best.version) > 0 then best = m end
			end
		end
	end
	if not best then return nil, "package not found: " .. tostring(name) end
	return best
end

function Repository:search(query)
	local repo, err = self:load(query)
	if not repo then return nil, err end
	local needle = string_lower(tostring(query or ""))
	local out = {}
	for i = 1, #repo do
		local m = self:hydrate(repo[i])
		if m then
			local n = string_lower(tostring(m.name or ""))
			local d = string_lower(tostring(m.description or ""))
			if needle == "" or string_find(n, needle, 1, true) or string_find(d, needle, 1, true) then
				out[#out + 1] = {
					name = m.name,
					version = m.version,
					description = m.description,
					dependencies = Util.deepcopy(m.dependencies),
				}
			end
		end
	end
	table_sort(out, function(a, b)
		if a.name == b.name then return Util.cmp_version(a.version, b.version) > 0 end
		return a.name < b.name
	end)
	return out
end

local MultiRepository = {}
MultiRepository.__index = MultiRepository

function MultiRepository.new(repos) return setmetatable({ repos = repos }, MultiRepository) end

function MultiRepository:clear_cache()
	for i = 1, #self.repos do self.repos[i]:clear_cache() end
end

function MultiRepository:find(name, constraint)
	local best, best_priority = nil, nil
	for i = 1, #self.repos do
		local repo = self.repos[i]
		local m = repo:find(name, constraint)
		if m then
			if best == nil or repo.priority > best_priority or
				(repo.priority == best_priority and Util.cmp_version(m.version, best.version) > 0) then
				best = m
				best_priority = repo.priority
			end
		end
	end
	if not best then
		local cstr = constraint
		if cstr and type(cstr) == "table" and cstr._is_constraint then cstr = cstr.text end
		return nil, "package not found: " .. tostring(name) .. (cstr and ("@" .. tostring(cstr)) or "")
	end
	best._source_priority = best_priority
	return best
end

function MultiRepository:search(query)
	local seen, out = {}, {}
	for i = 1, #self.repos do
		local results = self.repos[i]:search(query)
		if results then
			for j = 1, #results do
				local r = results[j]
				local key = r.name .. "@" .. r.version
				if not seen[key] then
					seen[key] = true; out[#out + 1] = r
				end
			end
		end
	end
	table_sort(out, function(a, b)
		if a.name == b.name then return Util.cmp_version(a.version, b.version) > 0 end
		return a.name < b.name
	end)
	return out
end

----------------------------------------------------------------------
-- Resolver
----------------------------------------------------------------------
local Resolver = {}
Resolver.__index = Resolver

function Resolver.new(repository) return setmetatable({ repository = repository }, Resolver) end

function Resolver:resolve_install(name, constraint, state, out)
	state = state or { seen = {}, stack = {}, resolved = {} }
	out = out or {}
	local cons = constraint
	if cons ~= nil and not (type(cons) == "table" and cons._is_constraint) then
		local parsed, perr = VersionConstraint.parse(cons)
		if not parsed then return nil, "invalid version constraint for '" .. tostring(name) .. "': " .. perr end
		cons = parsed
	end

	-- Version conflict detection
	local existing = state.resolved[name]
	if existing then
		if cons and not cons:matches(existing.version) then
			return nil,
				"version conflict for '" ..
				name ..
				"': already resolved to " ..
				existing.version ..
				" (required by '" .. existing.required_by .. "'), but '" .. cons.text .. "' is also required"
		end
		return out
	end

	local m, err = self.repository:find(name, cons)
	if not m then return nil, err end
	local key = m.name .. "@" .. m.version
	if state.seen[key] then return out end
	if state.stack[key] then return nil, "dependency cycle detected at " .. key end
	state.stack[key] = true
	state.resolved[name] = { version = m.version, required_by = state._current_parent or "(root)" }

	local old_parent = state._current_parent
	state._current_parent = m.name
	for i = 1, #m.dependencies do
		local dep = m.dependencies[i]
		local ok, derr = self:resolve_install(dep.name, dep.version, state, out)
		if not ok then return nil, "failed to resolve dependency '" .. dep.name .. "' for '" .. m.name .. "': " .. derr end
	end
	state._current_parent = old_parent

	state.stack[key] = nil
	state.seen[key] = true
	out[#out + 1] = m
	return out
end

local Hooks = {}
function Hooks.run(hooks, name, ctx)
	local fn = hooks and hooks[name]
	if type(fn) ~= "function" then return true end
	local ok, err = pcall(fn, ctx)
	if not ok then return nil, "hook '" .. name .. "' failed: " .. tostring(err) end
	return true
end

----------------------------------------------------------------------
-- Manager Internals
----------------------------------------------------------------------
function Manager:_save() return self.storage:save(self.db) end

function Manager:_acquire_lock()
	local plat = luapm.platform
	local time_fn = plat.os_time or function() return 0 end
	local clock_fn = plat.os_clock or function() return 0 end
	local rename_fn = plat.os_rename

	local lock_path = self.db_path .. ".lock"
	local tmp_path = self.db_path .. ".lock.tmp." .. tostring(time_fn()) .. "." .. tostring(clock_fn())

	local ok = self.fs.write(tmp_path, "lock")
	if not ok then return nil, "failed to write lock temp file" end

	-- If no rename available, skip atomic locking (single-process environments)
	if not rename_fn then
		self._lock_path = tmp_path
		return true
	end

	-- os.rename is atomic on POSIX and Windows
	if rename_fn(tmp_path, lock_path) then
		self._lock_path = lock_path
		return true
	else
		self.fs.remove(tmp_path)
		return nil, "package database is locked by another process"
	end
end

function Manager:_release_lock()
	if self._lock_path then
		self.fs.remove(self._lock_path)
		self._lock_path = nil
	end
end

-- Executes a function while holding the DB lock
function Manager:_with_lock(fn)
	local lock_ok, lock_err = self:_acquire_lock()
	if not lock_ok then return nil, lock_err end
	local results = { pcall(fn) }
	self:_release_lock()
	if results[1] then
		table_remove(results, 1)
		return table_unpack(results)
	end
	return nil, results[2] or "unknown error during locked operation"
end

function Manager:_owner_of(path, ignore_name)
	local norm_path = Util.normalize_path(path)
	for pkg_name, meta in next, self.db.packages do
		if pkg_name ~= ignore_name then
			for i = 1, #(meta.files or {}) do
				if Util.normalize_path(meta.files[i]) == norm_path then return pkg_name end
			end
		end
	end
end

function Manager:_fetch_file_body(file, target)
	local body = file.content
	if body == nil then
		local err
		body, err = self.http.get(file.url)
		if not body then return nil, "file fetch failed for '" .. target .. "': " .. err end
	end
	if file.sha256 then
		local ok, verr = Integrity.verify(body, file.sha256)
		if not ok then return nil, verr end
	end
	return body
end

function Manager:_write_package_files(manifest)
	local written = {}
	for i = 1, #manifest.files do
		local file = manifest.files[i]
		local target, err = Util.safe_join(self.install_root, file.path)
		if not target then
			for j = 1, #written do self.fs.remove(written[j]) end
			return nil, "invalid path '" .. file.path .. "': " .. err
		end
		local owner = self:_owner_of(target, manifest.name)
		if owner then
			for j = 1, #written do self.fs.remove(written[j]) end
			return nil, "file collision: '" .. target .. "' is already owned by package '" .. owner .. "'"
		end
		local ok, err = self.fs.mkdir_p(self.fs.dirname(target))
		if not ok then
			for j = 1, #written do self.fs.remove(written[j]) end
			return nil, err
		end
		local body, ferr = self:_fetch_file_body(file, target)
		if not body then
			for j = 1, #written do self.fs.remove(written[j]) end
			return nil, ferr
		end
		ok, err = self.fs.write(target, body)
		if not ok then
			for j = 1, #written do self.fs.remove(written[j]) end
			return nil, "write failed for '" .. target .. "': " .. err
		end
		written[#written + 1] = target
	end
	return written
end

function Manager:_record_installed(manifest, files)
	local hashes = {}
	for i = 1, #manifest.files do
		local f = manifest.files[i]
		if f.sha256 then
			local target = Util.normalize_path(self.fs.join(self.install_root, f.path))
			hashes[target] = f.sha256
		end
	end
	self.db.packages[manifest.name] = {
		version = manifest.version,
		files = files,
		dependencies = Util.deepcopy(manifest.dependencies),
		description = manifest.description,
		hashes = hashes,
	}
end

function Manager:_erase_package_files(name)
	local meta = self.db.packages[name]
	if not meta then return end
	for i = 1, #(meta.files or {}) do
		self.fs.remove(meta.files[i])
		if self.fs.prune_empty_dirs then self.fs.prune_empty_dirs(self.install_root, meta.files[i]) end
	end
end

-- Topological DFS to collect all orphaned dependencies
function Manager:_collect_orphans(initial_name, to_remove)
	if to_remove[initial_name] then return end
	to_remove[initial_name] = true
	local meta = self.db.packages[initial_name]
	if not meta then return end
	local deps = meta.dependencies or {}
	for i = 1, #deps do
		local dep = deps[i].name
		if self.db.packages[dep] and not to_remove[dep] then
			local still_needed = false
			for pkg_name, pkg_meta in next, self.db.packages do
				if not to_remove[pkg_name] then
					local pdeps = pkg_meta.dependencies or {}
					for j = 1, #pdeps do
						if pdeps[j].name == dep then
							still_needed = true; break
						end
					end
				end
				if still_needed then break end
			end
			if not still_needed then self:_collect_orphans(dep, to_remove) end
		end
	end
end

function Manager:_rollback(snapshot, installed_in_call, files_written)
	self.db = snapshot
	for i = 1, #installed_in_call do
		if not snapshot.packages[installed_in_call[i]] then
			self.db.packages[installed_in_call[i]] = nil
		end
	end
	for i = 1, #files_written do
		self.fs.remove(files_written[i])
		if self.fs.prune_empty_dirs then self.fs.prune_empty_dirs(self.install_root, files_written[i]) end
	end
	self:_save()
end

function Manager:_restore_backup(backed_up, trash_dir)
	for bpath, orig_path in next, backed_up do
		self.fs.mkdir_p(self.fs.dirname(orig_path))
		local content = self.fs.read(bpath)
		if content then self.fs.write(orig_path, content) end
		self.fs.remove(bpath)
	end
	self.fs.remove(trash_dir)
end

-- Shared transactional logic for `install` and `update`
function Manager:_execute_plan(plan, installed_in_call, files_written)
	for i = 1, #plan do
		local m = plan[i]
		local existing = self.db.packages[m.name]
		local skip = existing ~= nil and existing.version == m.version
		if not skip then
			local ctx = { manager = self, manifest = m, action = "install" }
			local ok, hook_err = Hooks.run(self.hooks, "before_install", ctx)
			if not ok then return nil, hook_err end

			local files, werr = self:_write_package_files(m)
			if not files then return nil, werr end

			self:_record_installed(m, files)
			installed_in_call[#installed_in_call + 1] = m.name
			for f = 1, #files do files_written[#files_written + 1] = files[f] end

			ok, hook_err = Hooks.run(self.hooks, "after_install", ctx)
			if not ok then return nil, hook_err end
		end
	end
	return true
end

----------------------------------------------------------------------
-- Public API
----------------------------------------------------------------------
function Manager:install(name, version, opts)
	if not name or name == "" then return nil, "install requires a package name" end
	opts = opts or {}

	return self:_with_lock(function()
		local plan, err = self.resolver:resolve_install(name, version)
		if not plan then return nil, err end

		local db_snapshot = Util.deepcopy(self.db)
		local installed_in_call, files_written = {}, {}

		local ok, exec_err = self:_execute_plan(plan, installed_in_call, files_written)
		if not ok then
			self:_rollback(db_snapshot, installed_in_call, files_written)
			return nil, exec_err
		end

		local pok, perr = self:_save()
		if not pok then
			self:_rollback(db_snapshot, installed_in_call, files_written)
			return nil, perr
		end
		return true
	end)
end

function Manager:remove(name, opts)
	opts = opts or {}
	if opts._internal then return self:_remove_internal(name, opts) end

	return self:_with_lock(function()
		return self:_remove_internal(name, opts)
	end)
end

function Manager:_remove_internal(name, opts)
	local meta = self.db.packages[name]
	if not meta then return nil, "package is not installed: " .. tostring(name) end

	local to_remove = {}
	if opts.orphans then
		self:_collect_orphans(name, to_remove)
	else
		to_remove[name] = true
	end

	-- Verify no external packages depend on what we're removing
	for pkg_name, _ in next, to_remove do
		for blocker_name, blocker_meta in next, self.db.packages do
			if not to_remove[blocker_name] then
				local bdeps = blocker_meta.dependencies or {}
				for j = 1, #bdeps do
					if bdeps[j].name == pkg_name then
						return nil, "cannot remove '" .. pkg_name .. "'; it is required by '" .. blocker_name .. "'"
					end
				end
			end
		end
	end

	if not opts._internal then
		local ctx = {
			manager = self,
			package_name = name,
			metadata = Util.deepcopy(meta),
			action = "remove",
			orphans = opts.orphans == true,
		}
		local ok, err = Hooks.run(self.hooks, "before_remove", ctx)
		if not ok then return nil, err end
	end

	local db_snapshot = Util.deepcopy(self.db)
	for pkg_name, _ in next, to_remove do
		self:_erase_package_files(pkg_name)
		self.db.packages[pkg_name] = nil
	end

	local ok, err = self:_save()
	if not ok then
		self.db = db_snapshot
		return nil, err
	end

	if not opts._internal then
		local ctx = { manager = self, package_name = name, action = "remove", orphans = opts.orphans == true }
		ok, err = Hooks.run(self.hooks, "after_remove", ctx)
		if not ok then return nil, err end
	end
	return true
end

function Manager:list_installed()
	local out = {}
	for name, meta in next, self.db.packages do
		out[name] = {
			version = meta.version,
			files = Util.deepcopy(meta.files),
			dependencies = Util.deepcopy(meta.dependencies),
			description = meta.description,
		}
	end
	return out
end

function Manager:get_installed(name)
	local meta = self.db.packages[name]
	if not meta then return nil, "package is not installed: " .. tostring(name) end
	return {
		name = name,
		version = meta.version,
		files = Util.deepcopy(meta.files),
		dependencies = Util.deepcopy(meta.dependencies),
		description = meta.description,
	}
end

function Manager:is_installed(name, version)
	local meta = self.db.packages[name]
	if not meta then return false end
	if version ~= nil then
		local cons = version
		if not (type(cons) == "table" and cons._is_constraint) then cons = VersionConstraint.parse(cons) end
		if cons and not cons:matches(meta.version) then return false end
	end
	return true
end

function Manager:search(query) return self.repository:search(query) end

function Manager:outdated()
	local out = {}
	for name, meta in next, self.db.packages do
		local latest, err = self.repository:find(name)
		if latest and Util.cmp_version(latest.version, meta.version) > 0 then
			out[#out + 1] = { name = name, current = meta.version, latest = latest.version }
		end
	end
	return out
end

function Manager:verify(name)
	local target_pkgs = name and { name } or (function()
		local t = {}; for n, _ in next, self.db.packages do t[#t + 1] = n end; return t
	end)()

	local results = {}
	for i = 1, #target_pkgs do
		local pkg_name = target_pkgs[i]
		local meta = self.db.packages[pkg_name]
		if not meta then
			results[pkg_name] = { ok = false, errors = { "not installed" } }
		else
			local ok = true
			local errs = {}
			for j = 1, #(meta.files or {}) do
				local file_path = meta.files[j]
				local content = self.fs.read(file_path)
				if not content then
					ok = false
					errs[#errs + 1] = "missing file: " .. file_path
				elseif meta.hashes and meta.hashes[file_path] then
					local v_ok, v_err = Integrity.verify(content, meta.hashes[file_path])
					if not v_ok then
						ok = false
						errs[#errs + 1] = v_err
					end
				end
			end
			results[pkg_name] = { ok = ok, errors = errs }
		end
	end
	return results
end

function Manager:update(name, opts)
	opts = opts or {}
	return self:_with_lock(function()
		local installed = self.db.packages[name]
		if not installed then return nil, "package is not installed: " .. tostring(name) end
		local latest, err = self.repository:find(name)
		if not latest then return nil, err end
		if Util.cmp_version(latest.version, installed.version) <= 0 then
			return true, "already up to date"
		end

		local ctx = {
			manager = self,
			package_name = name,
			from_version = installed.version,
			to_version = latest.version,
			action = "update",
		}
		local ok, hook_err = Hooks.run(self.hooks, "before_update", ctx)
		if not ok then return nil, hook_err end

		local db_snapshot = Util.deepcopy(self.db)
		local installed_in_call, files_written = {}, {}

		-- Backup old files before deleting
		local trash_dir = self.fs.join(self.cache_dir or self.install_root, ".luapm-trash-" .. name)
		self.fs.mkdir_p(trash_dir)
		local old_files = Util.deepcopy(installed.files or {})
		local backed_up = {}
		for i = 1, #old_files do
			local content = self.fs.read(old_files[i])
			if content then
				local bpath = self.fs.join(trash_dir, tostring(i))
				self.fs.write(bpath, content)
				backed_up[bpath] = old_files[i]
			end
			self.fs.remove(old_files[i])
			if self.fs.prune_empty_dirs then self.fs.prune_empty_dirs(self.install_root, old_files[i]) end
		end
		self.db.packages[name] = nil

		local plan, perr = self.resolver:resolve_install(name, latest.version)
		if not plan then
			self:_restore_backup(backed_up, trash_dir)
			self.db = db_snapshot
			self:_save()
			return nil, perr
		end

		ok, err = self:_execute_plan(plan, installed_in_call, files_written)
		if not ok then
			self:_restore_backup(backed_up, trash_dir)
			self:_rollback(db_snapshot, installed_in_call, files_written)
			return nil, err
		end

		-- Success: Discard backup
		for bpath, _ in next, backed_up do self.fs.remove(bpath) end
		self.fs.remove(trash_dir)

		local pok, perr2 = self:_save()
		if not pok then
			self:_rollback(db_snapshot, installed_in_call, files_written)
			return nil, perr2
		end

		ok, hook_err = Hooks.run(self.hooks, "after_update", ctx)
		if not ok then return nil, hook_err end

		-- Optional cleanup of old dependencies
		if opts.orphans then
			local new_deps = self.db.packages[name].dependencies or {}
			local new_deps_set = {}
			for i = 1, #new_deps do new_deps_set[new_deps[i].name] = true end

			local old_deps = installed.dependencies or {}
			for i = 1, #old_deps do
				local dep_name = old_deps[i].name
				if not new_deps_set[dep_name] and self.db.packages[dep_name] then
					local still_needed = false
					for pkg_name, pkg_meta in next, self.db.packages do
						if pkg_name ~= name then
							local pdeps = pkg_meta.dependencies or {}
							for j = 1, #pdeps do
								if pdeps[j].name == dep_name then
									still_needed = true; break
								end
							end
						end
						if still_needed then break end
					end
					if not still_needed then
						self:_remove_internal(dep_name, { orphans = true, _internal = true })
					end
				end
			end
		end
		return true
	end)
end

function Manager:refresh_repo()
	self.repository:clear_cache()
	if self.http.clear_cache then self.http.clear_cache() end
	return true
end

function Manager:get_repository() return self.repository end

function Manager:get_config()
	return {
		repo = self.repo_source,
		repos = Util.deepcopy(self.repo_sources),
		install_root = self.install_root,
		db_path = self.db_path,
		cache_dir = self.cache_dir,
	}
end

----------------------------------------------------------------------
-- Constructor
----------------------------------------------------------------------
function luapm.new(config)
	config = config or {}

	-- Merge user-provided platform overrides
	if config.platform then
		for k, v in next, config.platform do
			luapm.platform[k] = v
		end
	end

	local fs = config.fs or DefaultFS
	local codec = config.codec or DefaultCodec
	local http = config.http or {}
	if not http.get then http.get = config.fetch or DefaultHTTP.get end
	if type(http.get) ~= "function" then error("config.http.get must be a function", 2) end

	local cache_dir = config.cache_dir
	if cache_dir == nil then cache_dir = ".luapm-cache" end
	local cache = Cache.new(fs, cache_dir)
	local http_with_cache = http
	if cache then
		local cached_http = CachedHTTP.new(http.get, cache, fs)
		http_with_cache = setmetatable({}, {
			__index = function(_, k)
				if k == "get" then return function(url) return cached_http:get(url) end end
				if k == "clear_cache" then return function() cached_http:clear_cache() end end
				return http[k]
			end,
		})
	end

	local storage = Storage.new(fs, codec, config.db_path or ".packages")
	local db, err = storage:load()
	if not db then error(err, 2) end

	local repo_specs = {}
	if config.repos then
		for i = 1, #config.repos do
			local r = config.repos[i]
			repo_specs[#repo_specs + 1] = { source = r.source or r.url or r.repo, priority = r.priority or 0 }
		end
	else
		repo_specs[#repo_specs + 1] = { source = config.repo or config.repo_url or "packages.json", priority = 0 }
	end

	local repos = {}
	for i = 1, #repo_specs do
		local spec = repo_specs[i]
		repos[#repos + 1] = Repository.new(spec.source, http_with_cache, codec, spec.priority)
	end
	table_sort(repos, function(a, b) return a.priority > b.priority end)

	local repository = #repos == 1 and repos[1] or MultiRepository.new(repos)
	local resolver = Resolver.new(repository)

	return setmetatable({
		repo_source = repo_specs[1] and repo_specs[1].source,
		repo_sources = repo_specs,
		install_root = config.install_root or ".",
		db_path = config.db_path or ".packages",
		cache_dir = cache_dir,
		hooks = config.hooks or {},
		fs = fs,
		http = http_with_cache,
		codec = codec,
		storage = storage,
		cache = cache,
		repository = repository,
		resolver = resolver,
		db = db,
	}, Manager)
end

luapm.util = Util
luapm.default_fs = DefaultFS
luapm.default_http = DefaultHTTP
luapm.default_codec = DefaultCodec
luapm.VersionConstraint = VersionConstraint
luapm.Integrity = Integrity

--[[ Quick tests
if true then
	local total, passed, failed = 0, 0, 0
	local failures = {}
	local function test(name, fn)
		total = total + 1
		local ok, err = pcall(fn)
		if ok then
			passed = passed + 1
		else
			failed = failed + 1
			failures[#failures + 1] = name
			print(string_format("  FAIL  %s: %s", name, tostring(err)))
		end
	end
	print("[pm] testing...")

	-- Util.trim
	test("Util.trim basic", function()
		assert(Util.trim("  hello  ") == "hello")
		assert(Util.trim("no_spaces") == "no_spaces")
		assert(Util.trim("  both  ") == "both")
	end)

	test("Util.trim empty/nil", function()
		assert(Util.trim("") == "")
		assert(Util.trim(nil) == "")
	end)

	-- Util.quote
	test("Util.quote basic", function()
		assert(Util.quote("hello") == '"hello"')
		assert(Util.quote('say "hi"') == '"say \\"hi\\""')
	end)

	-- Util.is_url
	test("Util.is_url", function()
		assert(Util.is_url("https://example.com") == true)
		assert(Util.is_url("http://x.com") == true)
		assert(Util.is_url("/local/path") == false)
		assert(Util.is_url("") == false)
		assert(Util.is_url(123) == false)
	end)

	-- Util.deepcopy
	test("Util.deepcopy basic", function()
		local t = { a = 1, b = { c = 2 } }
		local c = Util.deepcopy(t)
		assert(c.a == 1)
		assert(c.b.c == 2)
		c.b.c = 99
		assert(t.b.c == 2)
	end)

	test("Util.deepcopy preserves types", function()
		local t = { num = 42, str = "hi", bool = true, nil_val = nil }
		local c = Util.deepcopy(t)
		assert(c.num == 42)
		assert(c.str == "hi")
		assert(c.bool == true)
	end)

	test("Util.deepcopy self-referencing", function()
		local t = { a = 1 }
		t.self = t
		local c = Util.deepcopy(t)
		assert(c.a == 1)
		assert(c.self == c)
		assert(c.self ~= t)
	end)

	-- Util.split_version
	test("Util.split_version basic", function()
		local v = Util.split_version("1.2.3")
		assert(#v == 3 and v[1] == 1 and v[2] == 2 and v[3] == 3)
	end)

	test("Util.split_version nil/default", function()
		local v = Util.split_version(nil)
		assert(#v == 1 and v[1] == 0)
	end)

	test("Util.split_version mixed", function()
		local v = Util.split_version("1.2a.3")
		assert(#v == 3 and v[1] == 1 and v[2] == "2a" and v[3] == 3)
	end)

	-- Util.cmp_version
	test("Util.cmp_version equal", function()
		assert(Util.cmp_version("1.0.0", "1.0.0") == 0)
	end)

	test("Util.cmp_version greater", function()
		assert(Util.cmp_version("2.0.0", "1.9.9") == 1)
	end)

	test("Util.cmp_version less", function()
		assert(Util.cmp_version("1.0.0", "1.1.0") == -1)
	end)

	test("Util.cmp_version different lengths", function()
		assert(Util.cmp_version("1.0", "1.0.0") == -1)
		assert(Util.cmp_version("1.0.1", "1.0") == 1)
	end)

	-- Util.split
	test("Util.split basic", function()
		local parts = Util.split("a,b,c", ",")
		assert(#parts == 3 and parts[1] == "a" and parts[2] == "b" and parts[3] == "c")
	end)

	test("Util.split no match", function()
		local parts = Util.split("abc", ",")
		assert(#parts == 1 and parts[1] == "abc")
	end)

	test("Util.split empty parts", function()
		local parts = Util.split("a,,b", ",")
		assert(#parts == 3 and parts[1] == "a" and parts[2] == "" and parts[3] == "b")
	end)

	-- Util.normalize_path
	test("Util.normalize_path basic", function()
		assert(Util.normalize_path("a/b/c") == "a/b/c")
		assert(Util.normalize_path("a/../b") == "b")
		assert(Util.normalize_path("a/./b") == "a/b")
	end)

	test("Util.normalize_path nil", function()
		assert(Util.normalize_path(nil) == nil)
	end)

	test("Util.normalize_path root", function()
		assert(Util.normalize_path("/a/b") == "/a/b")
	end)

	-- Util.safe_join
	test("Util.safe_join basic", function()
		local ok, err = Util.safe_join("/root", "file.txt")
		assert(ok == "/root/file.txt")
	end)

	test("Util.safe_join reject absolute", function()
		local ok, err = Util.safe_join("/root", "/etc/passwd")
		assert(ok == nil)
	end)

	test("Util.safe_join reject traversal", function()
		local ok, err = Util.safe_join("/root", "../etc/passwd")
		assert(ok == nil)
	end)

	test("Util.safe_join reject drive letter", function()
		local ok, err = Util.safe_join("/root", "C:/Windows")
		assert(ok == nil)
	end)

	test("Util.safe_join nil args", function()
		local ok, err = Util.safe_join(nil, "x")
		assert(ok == nil)
	end)

	-- VersionConstraint.parse
	test("VersionConstraint.parse nil -> any", function()
		local c = VersionConstraint.parse(nil)
		assert(c:matches("1.0.0"))
		assert(c:matches("0.0.1"))
	end)

	test("VersionConstraint.parse exact", function()
		local c = VersionConstraint.parse("1.2.3")
		assert(c:matches("1.2.3"))
		assert(not c:matches("1.2.4"))
	end)

	test("VersionConstraint.parse >=", function()
		local c = VersionConstraint.parse(">=1.0.0")
		assert(c:matches("1.0.0"))
		assert(c:matches("2.0.0"))
		assert(not c:matches("0.9.9"))
	end)

	test("VersionConstraint.parse <", function()
		local c = VersionConstraint.parse("<2.0.0")
		assert(c:matches("1.9.9"))
		assert(not c:matches("2.0.0"))
	end)

	test("VersionConstraint.parse range", function()
		local c = VersionConstraint.parse(">=1.0.0,<2.0.0")
		assert(c:matches("1.5.0"))
		assert(not c:matches("0.9.0"))
		assert(not c:matches("2.0.0"))
	end)

	test("VersionConstraint.parse tilde", function()
		local c = VersionConstraint.parse("~>1.2")
		assert(c:matches("1.2.0"))
		assert(c:matches("1.2.9"))
		assert(not c:matches("1.3.0"))
		assert(not c:matches("1.1.9"))
	end)

	test("VersionConstraint.parse != ", function()
		local c = VersionConstraint.parse("!=1.0.0")
		assert(not c:matches("1.0.0"))
		assert(c:matches("1.0.1"))
	end)

	test("VersionConstraint.parse idempotent", function()
		local c1 = VersionConstraint.parse(">=1.0")
		local c2 = VersionConstraint.parse(c1)
		assert(c1 == c2)
	end)

	-- DefaultCodec.encode_lua / decode_lua roundtrip
	test("Codec encode/decode lua roundtrip", function()
		local original = { name = "test", version = "1.0", count = 42, flag = true, nested = { a = 1 } }
		local encoded = DefaultCodec.encode(original)
		local decoded = DefaultCodec.decode(encoded)
		assert(type(decoded) == "table")
		assert(decoded.name == "test")
		assert(decoded.version == "1.0")
		assert(decoded.count == 42)
		assert(decoded.flag == true)
		assert(decoded.nested.a == 1)
	end)

	test("Codec decode lua sandbox", function()
		local result = DefaultCodec.decode_lua("return 1 + 2")
		assert(result == 3)
	end)

	test("Codec decode lua sandboxed no globals", function()
		local result, err = DefaultCodec.decode_lua("return tostring(1)")
		assert(result == nil)
	end)

	-- DefaultCodec.decode_json
	test("JSON decode object", function()
		local r = DefaultCodec.decode_json('{"a": 1, "b": "hello", "c": true, "d": null}')
		assert(type(r) == "table")
		assert(r.a == 1)
		assert(r.b == "hello")
		assert(r.c == true)
		assert(r.d == nil)
	end)

	test("JSON decode array", function()
		local r = DefaultCodec.decode_json('[1, 2, 3]')
		assert(type(r) == "table")
		assert(#r == 3 and r[1] == 1 and r[2] == 2 and r[3] == 3)
	end)

	test("JSON decode nested", function()
		local r = DefaultCodec.decode_json('{"x": [1, {"y": 2}]}')
		assert(r.x[1] == 1)
		assert(r.x[2].y == 2)
	end)

	test("JSON decode string escapes", function()
		local r = DefaultCodec.decode_json('{"s": "line1\\nline2\\ttab\\"quote"}')
		assert(r.s == "line1\nline2\ttab\"quote")
	end)

	test("JSON decode errors", function()
		local r, err = DefaultCodec.decode_json('{invalid}')
		assert(r == nil)
	end)

	test("JSON decode trailing content", function()
		local r, err = DefaultCodec.decode_json('{"a":1} extra')
		assert(r == nil)
	end)

	test("JSON decode empty object", function()
		local r = DefaultCodec.decode_json('{}')
		assert(type(r) == "table" and next(r) == nil)
	end)

	test("JSON decode empty array", function()
		local r = DefaultCodec.decode_json('[]')
		assert(type(r) == "table" and #r == 0)
	end)

	test("JSON decode numbers", function()
		local r = DefaultCodec.decode_json('{"int": 42, "float": 3.14, "neg": -7, "sci": 1e2}')
		assert(r.int == 42)
		assert(r.float > 3.13 and r.float < 3.15)
		assert(r.neg == -7)
		assert(r.sci == 100)
	end)

	test("JSON decode unicode escape", function()
		local r = DefaultCodec.decode_json('{"c": "\\u0041"}')
		assert(r.c == "A")
	end)

	-- Integrity.sha256
	test("SHA-256 empty string", function()
		local h = Integrity.sha256("")
		assert(h == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
	end)

	test("SHA-256 abc", function()
		local h = Integrity.sha256("abc")
		assert(h == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
	end)

	test("SHA-256 not string", function()
		local h = Integrity.sha256(12345)
		assert(h == nil)
	end)

	-- Integrity.verify
	test("Integrity.verify match", function()
		local data = "hello"
		local hash = Integrity.sha256(data)
		local ok, err = Integrity.verify(data, hash)
		assert(ok == true)
	end)

	test("Integrity.verify mismatch", function()
		local ok, err = Integrity.verify("hello", "0000000000000000000000000000000000000000000000000000000000000000")
		assert(ok == nil)
	end)

	test("Integrity.verify empty/nil skips", function()
		assert(Integrity.verify("anything", nil) == true)
		assert(Integrity.verify("anything", "") == true)
	end)

	test("Integrity.verify algo:hex format", function()
		local data = "test"
		local hash = "sha256:" .. Integrity.sha256(data)
		assert(Integrity.verify(data, hash) == true)
	end)

	test("Integrity.verify unsupported algo", function()
		local ok, err = Integrity.verify("x", "md5:abc")
		assert(ok == nil)
	end)

	-- Validator.normalize_manifest
	test("Validator.normalize_manifest basic", function()
		local m = { name = "foo", version = "1.0", files = { { path = "a.lua", url = "http://x.com/a.lua" } } }
		local r, err = Validator.normalize_manifest(m)
		assert(r ~= nil)
		assert(r.name == "foo")
		assert(#r.files == 1)
	end)

	test("Validator.normalize_manifest missing name", function()
		local r, err = Validator.normalize_manifest({ version = "1.0" })
		assert(r == nil)
	end)

	test("Validator.normalize_manifest shorthand url/path", function()
		local m = { name = "x", version = "1", url = "http://x.com/f.lua", path = "f.lua" }
		local r = Validator.normalize_manifest(m)
		assert(r ~= nil)
		assert(#r.files == 1)
		assert(r.files[1].path == "f.lua")
	end)

	-- Validator.normalize_repo
	test("Validator.normalize_repo array", function()
		local raw = { { name = "a", version = "1" }, { name = "b", version = "2" } }
		local r = Validator.normalize_repo(raw)
		assert(#r == 2)
	end)

	test("Validator.normalize_repo hash", function()
		local raw = { a = { version = "1" }, b = { version = "2" } }
		local r = Validator.normalize_repo(raw)
		assert(#r == 2)
	end)

	test("Validator.normalize_repo packages wrapper", function()
		local raw = { packages = { { name = "x", version = "1" } } }
		local r = Validator.normalize_repo(raw)
		assert(#r == 1)
	end)

	-- Summary
	print(string_format("[pm] %d/%d tests passed (%d failed)", passed, total, failed))
	if failed > 0 then
		print("[pm] FAILURES:")
		for _, n in next, failures do print("  - " .. n) end
	end
	assert(failed == 0, string_format("%d test(s) failed", failed))
end
--]]

-- Export
return luapm
