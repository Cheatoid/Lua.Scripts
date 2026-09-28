-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for noise.lua.
-- Run from this directory:
--   lua noise.lua
--   luajit noise.lua

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
local Noise = require("noise")

local pass_count = 0
local fail_count = 0

local function check(name, cond)
	if cond then
		pass_count = pass_count + 1
	else
		fail_count = fail_count + 1
		print(string.format("[FAIL] %s", name))
	end
end

local function in_range(v, lo, hi)
	return type(v) == "number" and v >= lo and v <= hi and v == v and math.abs(v) ~= math.huge
end

-- new / reseed determinism.
do
	local a = Noise.new(12345)
	local b = Noise.new(12345)
	check("same seed perlin equal", a:perlin2D(0.5, 0.7) == b:perlin2D(0.5, 0.7))
	check("same seed simplex equal", a:simplex2D(0.3, 0.9) == b:simplex2D(0.3, 0.9))
	check("same seed simplex3 equal", a:simplex3D(0.1, 0.2, 0.3) == b:simplex3D(0.1, 0.2, 0.3))
	local c = Noise.new(99999)
	local diff = (a:perlin2D(0.5, 0.7) ~= c:perlin2D(0.5, 0.7))
		or (a:simplex2D(1.5, 2.5) ~= c:simplex2D(1.5, 2.5))
		or (a:perlin3D(0.5, 0.5, 0.5) ~= c:perlin3D(0.5, 0.5, 0.5))
	check("different seed differs", diff == true)
	a:reseed(777)
	local d = Noise.new(777)
	check("reseed matches fresh", a:perlin2D(0.5, 0.5) == d:perlin2D(0.5, 0.5))
	check("reseed stores seed", a.seed == 777)
end

-- hash determinism.
do
	local n = Noise.new(42)
	check("hash repeatable", n:hash(1, 2) == n:hash(1, 2))
	check("hash 3d repeatable", n:hash(1, 2, 3) == n:hash(1, 2, 3))
	check("hash varies", n:hash(1, 2) ~= n:hash(3, 4) or n:hash(1, 2, 3) ~= n:hash(4, 5, 6))
end

-- perlin2D / perlin3D lattice + range + determinism.
do
	local n = Noise.new(42)
	check("perlin2D lattice zero", math.abs(n:perlin2D(0, 0)) < 1e-9)
	check("perlin2D int lattice zero", math.abs(n:perlin2D(5, 7)) < 1e-9)
	check("perlin3D lattice zero", math.abs(n:perlin3D(0, 0, 0)) < 1e-9)
	check("perlin3D int lattice zero", math.abs(n:perlin3D(2, 3, 4)) < 1e-9)
	local ok2 = true
	for i = 1, 20 do
		local v = n:perlin2D(i * 0.37, i * 0.71)
		if not in_range(v, -1, 1) then ok2 = false end
		if n:perlin2D(i * 0.37, i * 0.71) ~= v then ok2 = false end
	end
	check("perlin2D range+determinism", ok2 == true)
	local ok3 = true
	for i = 1, 20 do
		local v = n:perlin3D(i * 0.31, i * 0.17, i * 0.53)
		if not in_range(v, -1, 1) then ok3 = false end
		if n:perlin3D(i * 0.31, i * 0.17, i * 0.53) ~= v then ok3 = false end
	end
	check("perlin3D range+determinism", ok3 == true)
end

-- simplex2D / simplex3D range + determinism.
do
	local n = Noise.new(42)
	local ok = true
	for i = 1, 20 do
		local v = n:simplex2D(i * 0.43, i * 0.29)
		if not in_range(v, -1, 1) then ok = false end
		if n:simplex2D(i * 0.43, i * 0.29) ~= v then ok = false end
	end
	check("simplex2D range+determinism", ok == true)
	local ok3 = true
	for i = 1, 20 do
		local v = n:simplex3D(i * 0.21, i * 0.47, i * 0.13)
		if not in_range(v, -1, 1) then ok3 = false end
		if n:simplex3D(i * 0.21, i * 0.47, i * 0.13) ~= v then ok3 = false end
	end
	check("simplex3D range+determinism", ok3 == true)
end

-- value2D range [0,1].
do
	local n = Noise.new(42)
	local ok = true
	for i = 1, 20 do
		local v = n:value2D(i * 0.33, i * 0.61)
		if not in_range(v, 0, 1) then ok = false end
		if n:value2D(i * 0.33, i * 0.61) ~= v then ok = false end
	end
	check("value2D range+determinism", ok == true)
end

-- worley2D / worley3D all return types + default + unknown.
do
	local n = Noise.new(42)
	local v_val = n:worley2D(0.5, 0.5, "value")
	local v_d = n:worley2D(0.5, 0.5, "distance")
	local v_d2 = n:worley2D(0.5, 0.5, "distance2")
	local v_d2s = n:worley2D(0.5, 0.5, "distance2sub")
	check("worley2D value range", in_range(v_val, 0, 1))
	check("worley2D distance >=0", v_d >= 0 and v_d == v_d)
	check("worley2D distance2 >=0", v_d2 >= 0 and v_d2 == v_d2)
	check("worley2D distance2sub >=0", v_d2s >= 0 and v_d2s == v_d2s)
	check("worley2D default is distance2", n:worley2D(0.5, 0.5) == v_d2)
	check("worley2D unknown is distance", n:worley2D(0.5, 0.5, "bogus") == v_d)
	check("worley2D deterministic", n:worley2D(0.5, 0.5, "distance") == v_d)

	local w_d = n:worley3D(0.5, 0.5, 0.5, "distance")
	local w_d2 = n:worley3D(0.5, 0.5, 0.5, "distance2")
	local w_d2s = n:worley3D(0.5, 0.5, 0.5, "distance2sub")
	check("worley3D distance >=0", w_d >= 0 and w_d == w_d)
	check("worley3D distance2 >=0", w_d2 >= 0 and w_d2 == w_d2)
	check("worley3D distance2sub >=0", w_d2s >= 0 and w_d2s == w_d2s)
	check("worley3D default is distance2", n:worley3D(0.5, 0.5, 0.5) == w_d2)
	check("worley3D unknown is distance", n:worley3D(0.5, 0.5, 0.5, "bogus") == w_d)
	check("worley3D deterministic", n:worley3D(0.5, 0.5, 0.5, "distance2") == w_d2)
end

-- fbm2D / fbm3D defaults + custom noiseFunc.
do
	local n = Noise.new(42)
	local a = n:fbm2D(0.5, 0.5)
	local b = n:fbm2D(0.5, 0.5, 2, 2.0, 0.5, Noise.perlin2D)
	check("fbm2D default range", in_range(a, -1, 1))
	check("fbm2D custom range", in_range(b, -1, 1))
	check("fbm2D deterministic", n:fbm2D(0.5, 0.5, 2) == n:fbm2D(0.5, 0.5, 2))
	local c = n:fbm3D(0.5, 0.5, 0.5)
	local d = n:fbm3D(0.5, 0.5, 0.5, 2, 2.0, 0.5, Noise.perlin3D)
	check("fbm3D default range", in_range(c, -1, 1))
	check("fbm3D custom range", in_range(d, -1, 1))
	check("fbm3D deterministic", n:fbm3D(0.5, 0.5, 0.5, 2) == n:fbm3D(0.5, 0.5, 0.5, 2))
end

-- ridged2D / ridged3D.
do
	local n = Noise.new(42)
	local a = n:ridged2D(0.5, 0.5, 2)
	local b = n:ridged3D(0.5, 0.5, 0.5, 2)
	check("ridged2D finite", a == a and math.abs(a) ~= math.huge)
	check("ridged3D finite", b == b and math.abs(b) ~= math.huge)
	check("ridged2D deterministic", n:ridged2D(0.5, 0.5, 2) == a)
	check("ridged3D deterministic", n:ridged3D(0.5, 0.5, 0.5, 2) == b)
end

-- domainWarp2D / domainWarp3D.
do
	local n = Noise.new(42)
	local a = n:domainWarp2D(0.5, 0.5, 0.5, 1)
	local b = n:domainWarp3D(0.5, 0.5, 0.5, 0.5, 1)
	check("warp2D range", in_range(a, -1, 1))
	check("warp3D range", in_range(b, -1, 1))
	check("warp2D deterministic", n:domainWarp2D(0.5, 0.5, 0.5, 1) == a)
	check("warp3D deterministic", n:domainWarp3D(0.5, 0.5, 0.5, 0.5, 1) == b)
end

-- erosion2D / terraced2D / seamless2D.
do
	local n = Noise.new(42)
	local e = n:erosion2D(0.5, 0.5, 2, 1)
	check("erosion finite", e == e and math.abs(e) ~= math.huge)
	check("erosion deterministic", n:erosion2D(0.5, 0.5, 2, 1) == e)
	local t = n:terraced2D(0.5, 0.5, 4, 0.15)
	check("terraced range", in_range(t, -1, 1))
	check("terraced deterministic", n:terraced2D(0.5, 0.5, 4, 0.15) == t)
	local s = n:seamless2D(0.5, 0.5, 1.0)
	check("seamless range", in_range(s, -1, 1))
	check("seamless deterministic", n:seamless2D(0.5, 0.5, 1.0) == s)
end

-- generateChunk2D / generateChunk3D dims + determinism.
do
	local n = Noise.new(123)
	local c2 = n:generateChunk2D(0, 0, 3, 0.1)
	check("chunk2D rows", c2[0] ~= nil and c2[1] ~= nil and c2[2] ~= nil)
	check("chunk2D cols", c2[0][0] ~= nil and c2[1][2] ~= nil)
	check("chunk2D matches direct", c2[1][2] == n:simplex2D((0 + 2) * 0.1, (0 + 1) * 0.1))
	local c2b = n:generateChunk2D(0, 0, 3, 0.1)
	check("chunk2D repeatable", c2b[1][2] == c2[1][2])
	local c3 = n:generateChunk3D(0, 0, 0, 2, 0.1)
	check("chunk3D dims", c3[0] ~= nil and c3[1] ~= nil and c3[0][0] ~= nil and c3[0][0][1] ~= nil)
	check("chunk3D matches direct", c3[1][0][1] == n:simplex3D((0 + 1) * 0.1, (0 + 0) * 0.1, (0 + 1) * 0.1))
end

-- blendBiomes weighted avg.
do
	local n = Noise.new(42)
	local function flat(x, z) return 1, 5 end
	check("blend flat", n:blendBiomes(0, 0, flat, 1) == 5)
	local function ramp(x, z) return 1, x + z end
	check("blend ramp center", n:blendBiomes(0, 0, ramp, 1) == 0)
end

-- Deprecated aliases exist.
do
	check("alias warp2", Noise.domain_warp2_d == Noise.domainWarp2D)
	check("alias warp3", Noise.domain_warp3_d == Noise.domainWarp3D)
	check("alias chunk2", Noise.generate_chunk2_d == Noise.generateChunk2D)
	check("alias chunk3", Noise.generate_chunk3_d == Noise.generateChunk3D)
	check("alias blend", Noise.blend_biomes == Noise.blendBiomes)
end

print(string.format("\nTests finished: %d passed, %d failed", pass_count, fail_count))
if fail_count > 0 then
	os.exit(1)
end
