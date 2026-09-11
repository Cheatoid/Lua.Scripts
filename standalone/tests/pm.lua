-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for pm.lua.
-- Run from this directory:
--   lua pm.lua
--   luajit pm.lua

-- Bootstrap: make requires work from tests/ subdir with plain lua/luajit.
do
	local src = debug.getinfo(1, "S").source
	local dir = src:match("^@(.+/)[^/]+$") or "./"
	local function isfile(p)
		local f = io.open(p, "r")
		if f then
			f:close()
			return true
		end
		return false
	end
	local root
	for _, c in ipairs({ dir, dir .. "../", dir .. "../..//", dir .. "../../..//", "./", "../", "../../" }) do
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
			root .. "vm/?.lua;" .. root .. "require_finder/?.lua;" .. root .. "inventory/?.lua;" .. package.path
	end
	local searchers = package.searchers or package.loaders
	if searchers then
		table.insert(searchers, 2, function(mod)
			if mod:sub(1, 3) == "../" or mod:sub(1, 2) == "./" then
				local clean = mod:gsub("^%./", ""):gsub("^%.%.%/", ""):gsub("^%.%.%/", "")
				local tries = { dir .. "../" .. clean .. ".lua", dir .. "../" .. clean .. "/init.lua", root ..
				clean .. ".lua", root .. clean .. "/init.lua" }
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
local lib = require "pm"
-- Bridging: file-locals used by tests mapped to module exports.
local DefaultCodec = lib.DefaultCodec
local Integrity = lib.Integrity
local Util = lib.Util
local Validator = lib.Validator
local VersionConstraint = lib.VersionConstraint
local string_format = string.format
-- TODO(manual): the following were file-locals with no direct export;
-- verify and export or inline as needed: a, algo, b, content, d, f, file, files, hex, http, match, null, path, pm, s, x, y

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
