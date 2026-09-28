-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for culling.lua.
-- Run from this directory:
--   lua culling.lua
--   luajit culling.lua

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
local CS = require("culling")

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

local function near(a, b, eps)
	eps = eps or 1e-6
	return math.abs(a - b) <= eps
end

local IDENT = { 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1 }
local ZERO_M = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }

local function demo_proj()
	local f = 1.0 / math.tan(math.rad(90) * 0.5)
	local aspect = 16.0 / 9.0
	local nearZ, farZ = 0.1, 1000.0
	local fn = farZ * nearZ
	local nf = nearZ - farZ
	return { f / aspect, 0, 0, 0, 0, f, 0, 0, 0, 0, farZ / nf, -1, 0, 0, fn / nf, 0 }
end

local function cube_frustum()
	return {
		{ 1, 0, 0, 1 }, { -1, 0, 0, 1 }, { 0, 1, 0, 1 },
		{ 0, -1, 0, 1 }, { 0, 0, 1, 1 }, { 0, 0, -1, 1 },
	}
end

-- Constructors.
do
	local p = CS:createPlane(1, 2, 3, 4)
	check("createPlane", p[1] == 1 and p[2] == 2 and p[3] == 3 and p[4] == 4)

	local f = CS:createFrustum()
	check("createFrustum len", #f == 6)
	check("createFrustum zeroed", f[1][1] == 0 and f[6][4] == 0)

	local b = CS:createAABB(-1, -1, -1, 1, 1, 1)
	check("createAABB mins", b[1] == -1 and b[2] == -1 and b[3] == -1)
	check("createAABB maxs", b[4] == 1 and b[5] == 1 and b[6] == 1)
	check("createAABB center", b[7] == 0 and b[8] == 0 and b[9] == 0)
	check("createAABB extents", b[10] == 1 and b[11] == 1 and b[12] == 1)

	local c = CS:createChunk(0, 0, 0, 2)
	check("createChunk pos", c[1] == 0 and c[2] == 0 and c[3] == 0)
	check("createChunk aabb", c[4][1] == -1 and c[4][4] == 1)
	check("createChunk flags", c[5] == false and c[6] == false and c[7] == false and c[8] == 0)
end

-- transformPointRowMajor incl w=0 path.
do
	local tp = CS:transformPointRowMajor({ 1, 2, 3, 1 }, IDENT)
	check("transformPoint identity", near(tp[1], 1) and near(tp[2], 2) and near(tp[3], 3) and near(tp[4], 1))
	local tp0 = CS:transformPointRowMajor({ 1, 2, 3, 1 }, ZERO_M)
	check("transformPoint w=0 path", tp0[1] == 0 and tp0[2] == 0 and tp0[3] == 0 and tp0[4] == 0)
	local scale2 = { 2, 0, 0, 0, 0, 2, 0, 0, 0, 0, 2, 0, 0, 0, 0, 1 }
	local tps = CS:transformPointRowMajor({ 1, 1, 1, 1 }, scale2)
	check("transformPoint scale", near(tps[1], 2) and near(tps[2], 2) and near(tps[3], 2))
end

-- transformDirectionRowMajor incl zero-len.
do
	local td = CS:transformDirectionRowMajor({ 1, 0, 0 }, IDENT)
	check("transformDirection identity", near(td[1], 1) and near(td[2], 0) and near(td[3], 0))
	local td0 = CS:transformDirectionRowMajor({ 0, 0, 0 }, IDENT)
	check("transformDirection zero-len", td0[1] == 0 and td0[2] == 0 and td0[3] == 0)
	local td2 = CS:transformDirectionRowMajor({ 5, 0, 0 }, IDENT)
	check("transformDirection normalized", near(td2[1], 1) and near(td2[2], 0))
end

-- extractFrustumFromMatrixRowMajor: identity, proj, tiny-len guard.
do
	local f = CS:extractFrustumFromMatrixRowMajor(IDENT)
	check("extract identity left", near(f[1][1], 1) and near(f[1][4], 1))
	check("extract identity right", near(f[2][1], -1) and near(f[2][4], 1))
	check("extract identity bottom", near(f[3][2], 1) and near(f[3][4], 1))
	check("extract identity top", near(f[4][2], -1) and near(f[4][4], 1))
	check("extract identity near", near(f[5][3], 1) and near(f[5][4], 0))
	check("extract identity far", near(f[6][3], -1) and near(f[6][4], 1))

	local fz = CS:extractFrustumFromMatrixRowMajor(ZERO_M)
	local allzero = true
	for i = 1, 6 do
		if fz[i][1] ~= 0 or fz[i][2] ~= 0 or fz[i][3] ~= 0 or fz[i][4] ~= 0 then allzero = false end
	end
	check("extract zero tiny-guard", allzero == true)

	local pm = demo_proj()
	local fp = CS:extractFrustumFromMatrixRowMajor(pm)
	check("extract proj count", #fp == 6)
	local normalized = true
	for i = 1, 6 do
		local l = math.sqrt(fp[i][1] ^ 2 + fp[i][2] ^ 2 + fp[i][3] ^ 2)
		if not near(l, 1, 1e-5) then normalized = false end
	end
	check("extract proj normalized", normalized == true)
	check("extract proj near", near(fp[5][3], -1, 1e-5))
end

-- extractFrustumFromViewProjSeparate + multiplyMatricesRowMajor.
do
	local pm = demo_proj()
	local vp = CS:extractFrustumFromViewProjSeparate(IDENT, pm)
	local direct = CS:extractFrustumFromMatrixRowMajor(pm)
	local same = true
	for i = 1, 6 do
		for j = 1, 4 do
			if not near(vp[i][j], direct[i][j], 1e-9) then same = false end
		end
	end
	check("separate equals direct", same == true)

	local r = CS:multiplyMatricesRowMajor(IDENT, IDENT)
	local is_ident = true
	for i = 1, 16 do if r[i] ~= IDENT[i] then is_ident = false end end
	check("multiply identity", is_ident == true)

	local A = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 }
	local r2 = CS:multiplyMatricesRowMajor(A, IDENT)
	local sameA = true
	for i = 1, 16 do if r2[i] ~= A[i] then sameA = false end end
	check("multiply A*I==A", sameA == true)
	local B = { 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1 }
	local r3 = CS:multiplyMatricesRowMajor(A, B)
	local exp = { 80, 70, 60, 50, 240, 214, 188, 162, 400, 358, 316, 274, 560, 502, 444, 386 }
	local prod_ok = true
	for i = 1, 16 do if r3[i] ~= exp[i] then prod_ok = false end end
	check("multiply known product", prod_ok == true)
end

-- Plane + frustum tests.
do
	local box = CS:createAABB(-1, -1, -1, 1, 1, 1)
	check("plane pos-normal inside", CS:testAABBAgainstPlaneOptimized(box, { 1, 0, 0, 0 }) == true)
	check("plane neg-normal inside", CS:testAABBAgainstPlaneOptimized(box, { -1, 0, 0, 0 }) == true)
	check("plane pos outside", CS:testAABBAgainstPlaneOptimized(CS:createAABB(-6, -6, -6, -5, -5, -5), { 1, 0, 0, 0 }) == false)
	check("plane neg outside", CS:testAABBAgainstPlaneOptimized(CS:createAABB(5, 5, 5, 6, 6, 6), { -1, 0, 0, 0 }) == false)
	check("plane y branch", CS:testAABBAgainstPlaneOptimized(box, { 0, 1, 0, 0 }) == true)
	check("plane z branch", CS:testAABBAgainstPlaneOptimized(box, { 0, 0, -1, 0 }) == true)

	local fr = cube_frustum()
	check("full inside", CS:testFrustumFull(fr, CS:createAABB(-0.5, -0.5, -0.5, 0.5, 0.5, 0.5)) == "inside")
	check("full intersecting", CS:testFrustumFull(fr, CS:createAABB(0.95, 0, 0, 1.0, 0.5, 0.5)) == "intersecting")
	check("full outside", CS:testFrustumFull(fr, CS:createAABB(5, 5, 5, 6, 6, 6)) == "outside")
	check("full binary inside", CS:testFrustumBinary(fr, CS:createAABB(-0.5, -0.5, -0.5, 0.5, 0.5, 0.5)) == true)
	check("full binary straddle", CS:testFrustumBinary(fr, CS:createAABB(0.8, 0, 0, 1.5, 0.5, 0.5)) == true)
	check("full binary outside", CS:testFrustumBinary(fr, CS:createAABB(5, 5, 5, 6, 6, 6)) == false)
end

-- Depth buffer + HiZ.
do
	local db = CS:createDepthBuffer(8, 8, 2)
	check("depth levels", #db == 2)
	check("depth L0 size", db[1][1] == 8 and db[1][2] == 8)
	check("depth L1 size", db[2][1] == 4 and db[2][2] == 4)
	check("depth init", db[1][3][1] == 1.0)

	local dm = {}
	for i = 1, 4 do dm[i] = 0.5 end
	CS:updateDepthBuffer(db, 0, 0, 2, 2, dm)
	check("update writes min", db[1][3][1] == 0.5)
	CS:updateDepthBuffer(db, 0, 0, 1, 1, { 0.9 })
	check("update keeps min", db[1][3][1] == 0.5)
	CS:buildHiZMipmaps(db)
	check("mipmap min", near(db[2][3][1], 0.5))
end

-- Occlusion: visible vs occluded + degenerate.
do
	local function proj(x, y, z) return x + 4, y + 4, z end
	local db = CS:createDepthBuffer(8, 8, 2)
	local dm = {}
	for i = 1, 64 do dm[i] = 0.05 end
	CS:updateDepthBuffer(db, 0, 0, 8, 8, dm)
	CS:buildHiZMipmaps(db)
	local behind = CS:createAABB(0, 0, 0.8, 1, 1, 0.9)
	local front = CS:createAABB(0, 0, 0.01, 1, 1, 0.02)
	check("occluded true", CS:testOcclusionHiZ(db, behind, proj, 0.1) == true)
	check("occluded false visible", CS:testOcclusionHiZ(db, front, proj, 0.1) == false)
	local function projPoint(x, y, z) return 4, 4, 0.5 end
	check("occluded degenerate true", CS:testOcclusionHiZ(db, behind, projPoint, 0.1) == true)
end

-- frustumCullChunks + cullChunksPipeline stats.
do
	local fr = cube_frustum()
	local c1 = CS:createChunk(0, 0, 0, 1)
	local c2 = CS:createChunk(10, 10, 10, 1)
	local vis = CS:frustumCullChunks(fr, { c1, c2 })
	check("frustumCull count", #vis == 1)
	check("frustumCull flags", c1[5] == true and c2[5] == false)

	local function proj(x, y, z) return x, y, z end
	local db = CS:createDepthBuffer(8, 8, 2)
	local chunks = { CS:createChunk(0, 0, 0, 1), CS:createChunk(10, 10, 10, 1) }
	local stats = CS:cullChunksPipeline(fr, db, chunks, proj, 0.1, 100)
	check("pipeline total", stats[1] == 2)
	check("pipeline frustumCulled", stats[2] == 1)
	check("pipeline visible", stats[4] == 1)
	check("pipeline sum", stats[2] + stats[3] + stats[4] == stats[1])
end

-- estimateScreenArea inside -> inf.
do
	local inside = CS:estimateScreenArea(CS:createAABB(-1, -1, -1, 1, 1, 1), { 0, 0, 0 }, { [6] = 1.0 }, 8)
	check("area inside inf", inside == math.huge)
	local far = CS:estimateScreenArea(CS:createAABB(9, 9, 9, 11, 11, 11), { 0, 0, 0 }, { [6] = 1.0 }, 8)
	check("area far finite", far > 0 and far < math.huge)
	check("area near bigger", CS:estimateScreenArea(CS:createAABB(-1, -1, 4, 1, 1, 6), { 0, 0, 0 }, { [6] = 2.0 }, 800)
		> CS:estimateScreenArea(CS:createAABB(-1, -1, 40, 1, 1, 42), { 0, 0, 0 }, { [6] = 2.0 }, 800))
end

-- rasterizeAABBToHiZ + updateHiZMipmapsRegion.
do
	local function proj(x, y, z) return x + 4, y + 4, z end
	local db = CS:createDepthBuffer(8, 8, 2)
	CS:rasterizeAABBToHiZ(db, CS:createAABB(0, 0, 0.1, 1, 1, 0.2), proj)
	check("raster writes", near(db[1][3][4 * 8 + 4 + 1], 0.1))
	check("raster mip", db[2][3][1] <= 1.0)
	CS:updateHiZMipmapsRegion(db, 0, 0, 2, 2)
	check("region update ok", db[2][3][1] ~= nil)
end

-- computeChunkFacingMask all 6 bits.
do
	local ch = CS:createChunk(1, 1, 1, 2)
	check("mask left", CS:computeChunkFacingMask(ch, { -5, 1, 1 }) == 1)
	check("mask right", CS:computeChunkFacingMask(ch, { 5, 1, 1 }) == 2)
	check("mask bottom", CS:computeChunkFacingMask(ch, { 1, -5, 1 }) == 4)
	check("mask top", CS:computeChunkFacingMask(ch, { 1, 5, 1 }) == 8)
	check("mask near", CS:computeChunkFacingMask(ch, { 1, 1, -5 }) == 16)
	check("mask far", CS:computeChunkFacingMask(ch, { 1, 1, 5 }) == 32)
	check("mask neg corner", CS:computeChunkFacingMask(ch, { -5, -5, -5 }) == 21)
	check("mask pos corner", CS:computeChunkFacingMask(ch, { 5, 5, 5 }) == 42)
	check("mask inside", CS:computeChunkFacingMask(ch, { 1, 1, 1 }) == 0)
end

-- cullChunksAdvancedPipeline: frustum/area/occlusion/visible + LOD.
do
	local fr = cube_frustum()
	local function aproj(x, y, z) return x + 8, y + 8, z end
	local projM = { [6] = 2.0 }
	local c_lod0 = CS:createChunk(0, 0, 0, 1.5)
	local c_lod1 = CS:createChunk(0, 0, 0.5, 0.5)
	local c_lod2 = CS:createChunk(0, 0, 0.2, 0.25)
	local c_tiny = CS:createChunk(0.2, 0.2, 0.2, 0.001)
	local c_out = CS:createChunk(10, 10, 10, 1)
	local chunks = { c_lod0, c_lod1, c_lod2, c_tiny, c_out }
	local db = CS:createDepthBuffer(16, 16, 2)
	local stats = CS:cullChunksAdvancedPipeline(fr, db, chunks, aproj, { 0, -5, 0 }, projM, 800, 0.1, 100)
	check("adv total", stats.total == 5)
	check("adv frustum", stats.frustumCulled >= 1)
	check("adv area", stats.areaCulled >= 1)
	check("adv visible", stats.visible >= 1)
	check("adv sum", stats.frustumCulled + stats.areaCulled + stats.occlusionCulled + stats.visible == stats.total)
	local lods = {}
	for _, c in ipairs(chunks) do
		if c[5] == true then lods[c[8]] = true end
	end
	check("adv lod assigned", lods[0] ~= nil or lods[1] ~= nil or lods[2] ~= nil)
	-- Occlusion branch with pre-filled close depths.
	local db2 = CS:createDepthBuffer(16, 16, 2)
	local fill = {}
	for i = 1, 256 do fill[i] = 0.02 end
	CS:updateDepthBuffer(db2, 0, 0, 16, 16, fill)
	CS:buildHiZMipmaps(db2)
	local oc = { CS:createChunk(0, 0, 0.5, 0.5) }
	local stats2 = CS:cullChunksAdvancedPipeline(fr, db2, oc, aproj, { 0, -5, 0 }, projM, 800, 0.1, 100)
	check("adv occlusion", stats2.occlusionCulled == 1 and stats2.visible == 0)
end

-- snake_case aliases exist.
do
	check("alias create_plane", CS.create_plane == CS.createPlane)
	check("alias create_frustum", CS.create_frustum == CS.createFrustum)
	check("alias create_aabb", CS.create_aabb == CS.createAABB)
	check("alias create_chunk", CS.create_chunk == CS.createChunk)
	check("alias transform_point", CS.transform_point_row_major == CS.transformPointRowMajor)
	check("alias transform_dir", CS.transform_direction_row_major == CS.transformDirectionRowMajor)
	check("alias extract", CS.extract_frustum_from_matrix_row_major == CS.extractFrustumFromMatrixRowMajor)
	check("alias extract_sep", CS.extract_frustum_from_view_proj_separate == CS.extractFrustumFromViewProjSeparate)
	check("alias multiply", CS.multiply_matrices_row_major == CS.multiplyMatricesRowMajor)
	check("alias plane_test", CS.test_aabb_against_plane_optimized == CS.testAABBAgainstPlaneOptimized)
	check("alias full", CS.test_frustum_full == CS.testFrustumFull)
	check("alias binary", CS.test_frustum_binary == CS.testFrustumBinary)
	check("alias depth", CS.create_depth_buffer == CS.createDepthBuffer)
	check("alias update_depth", CS.update_depth_buffer == CS.updateDepthBuffer)
	check("alias build_hiz", CS.build_hi_z_mipmaps == CS.buildHiZMipmaps)
	check("alias occlusion", CS.test_occlusion_hi_z == CS.testOcclusionHiZ)
	check("alias cull", CS.frustum_cull_chunks == CS.frustumCullChunks)
	check("alias pipeline", CS.cull_chunks_pipeline == CS.cullChunksPipeline)
	check("alias area", CS.estimate_screen_area == CS.estimateScreenArea)
	check("alias raster", CS.rasterize_aabb_to_hi_z == CS.rasterizeAABBToHiZ)
	check("alias region", CS.update_hi_z_mipmaps_region == CS.updateHiZMipmapsRegion)
	check("alias facing", CS.compute_chunk_facing_mask == CS.computeChunkFacingMask)
	check("alias advanced", CS.cull_chunks_advanced_pipeline == CS.cullChunksAdvancedPipeline)
end

print(string.format("\nTests finished: %d passed, %d failed", pass_count, fail_count))
if fail_count > 0 then
	os.exit(1)
end
