-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Features:
-- Frustum culling with AABB vs plane tests (binary and full intersection)
-- Hi-Z occlusion culling with hierarchical depth buffer mipmaps
-- Software occlusion via conservative AABB rasterization
-- Screen-space area estimation for LOD determination
-- Chunk facing mask computation for voxel meshing optimization
-- Advanced pipeline combining frustum, area/LOD, and software occlusion

-- Matrix index: m[(row-1)*4 + col]  (1-based row-major)
--   Row 0: m[1]  m[2]  m[3]  m[4]
--   Row 1: m[5]  m[6]  m[7]  m[8]
--   Row 2: m[9]  m[10] m[11] m[12]
--   Row 3: m[13] m[14] m[15] m[16]
--
-- Vector operations: result = vector * matrix or matrix * vector
--
-- Numeric index mapping:
--   Matrix4x4:  {[1]=m00,[2]=m01,[3]=m02,[4]=m03,
--                [5]=m10,[6]=m11,[7]=m12,[8]=m13,
--                [9]=m20,[10]=m21,[11]=m22,[12]=m23,
--                [13]=m30,[14]=m31,[15]=m32,[16]=m33}
--   Plane:     {[1]=nx, [2]=ny, [3]=nz, [4]=d}
--   Frustum:   {[1]=left, [2]=right, [3]=bottom, [4]=top, [5]=near, [6]=far}
--   AABB:      {[1]=minX, [2]=minY, [3]=minZ, [4]=maxX, [5]=maxY, [6]=maxZ,
--               [7]=centerX, [8]=centerY, [9]=centerZ,
--               [10]=extentsX, [11]=extentsY, [12]=extentsZ}
--   Vector:    {[1]=x, [2]=y, [3]=z} or {[1]=x, [2]=y, [3]=z, [4]=w}
--   Chunk:     {[1]=posX, [2]=posY, [3]=posZ, [4]=aabb, [5]=visible,
--               [6]=frustumVisible, [7]=occluded, [8]=renderQueue}
--   DepthLevel:{[1]=width, [2]=height, [3]=data, [4]=minZ, [5]=maxZ}
--   Stats:     {[1]=total, [2]=frustumCulled, [3]=occlusionCulled, [4]=visible}

-- Localized global functions for better performance
local math_abs, math_ceil, math_floor, math_huge, math_max, math_min, math_rad, math_random, math_sqrt, math_tan =
	math.abs, math.ceil, math.floor, math.huge, math.max, math.min, math.rad, math.random, math.sqrt, math.tan
local string_format = string.format
local table_insert, table_sort = table.insert, table.sort

local CullingSystem = {}

----------------------------------------------------------------------
-- DATA STRUCTURES
----------------------------------------------------------------------

CullingSystem._tempAABBs = {}
CullingSystem._tempPlanes = {}
CullingSystem._chunkPool = {}

--- Create a plane from normal and distance
---@param nx number Normal X component
---@param ny number Normal Y component
---@param nz number Normal Z component
---@param d number Distance from origin
---@return table plane {[1]=nx, [2]=ny, [3]=nz, [4]=d}
function CullingSystem:createPlane(nx, ny, nz, d)
	return { nx, ny, nz, d }
end

--- Create an empty frustum (6 planes)
---@return table frustum Array of 6 planes
function CullingSystem:createFrustum()
	return {
		self:createPlane(0, 0, 0, 0),
		self:createPlane(0, 0, 0, 0),
		self:createPlane(0, 0, 0, 0),
		self:createPlane(0, 0, 0, 0),
		self:createPlane(0, 0, 0, 0),
		self:createPlane(0, 0, 0, 0)
	}
end

--- Create an AABB with precomputed center and extents
---@param minX number
---@param minY number
---@param minZ number
---@param maxX number
---@param maxY number
---@param maxZ number
---@return table aabb {[1]=minX..[6]=maxZ, [7]=centerX..[9]=centerZ, [10]=extentsX..[12]=extentsZ}
function CullingSystem:createAABB(minX, minY, minZ, maxX, maxY, maxZ)
	return {
		minX, minY, minZ,
		maxX, maxY, maxZ,
		(minX + maxX) * 0.5,
		(minY + maxY) * 0.5,
		(minZ + maxZ) * 0.5,
		(maxX - minX) * 0.5,
		(maxY - minY) * 0.5,
		(maxZ - minZ) * 0.5
	}
end

--- Create a chunk with centered AABB
---@param x number Center X position
---@param y number Center Y position
---@param z number Center Z position
---@param size number Chunk size
---@return table chunk {[1]=posX, [2]=posY, [3]=posZ, [4]=aabb, [5]=visible, [6]=frustumVisible, [7]=occluded, [8]=renderQueue}
function CullingSystem:createChunk(x, y, z, size)
	local halfSize = size * 0.5
	return {
		x, y, z,
		self:createAABB(
			x - halfSize, y - halfSize, z - halfSize,
			x + halfSize, y + halfSize, z + halfSize
		),
		false,
		false,
		false,
		0
	}
end

----------------------------------------------------------------------
-- MATRIX MATH HELPERS (FLAT ROW-MAJOR)
----------------------------------------------------------------------

--- Apply row-major matrix to point (point * matrix, treating point as row vector)
--- Matrix stored as 16-element flat array: m[(row-1)*4 + col]
---@param point table Point as {[1]=x, [2]=y, [3]=z, [4]=w}
---@param m table 4x4 matrix as 16-element flat row-major array
---@return table transformed Transformed point
function CullingSystem:transformPointRowMajor(point, m)
	local x, y, z, w = point[1] or 0, point[2] or 0, point[3] or 0, point[4] or 1

	local newX = x * m[1] + y * m[5] + z * m[9] + w * m[13]
	local newY = x * m[2] + y * m[6] + z * m[10] + w * m[14]
	local newZ = x * m[3] + y * m[7] + z * m[11] + w * m[15]
	local newW = x * m[4] + y * m[8] + z * m[12] + w * m[16]

	-- Perspective divide
	if newW ~= 0 then
		local invW = 1.0 / newW
		return { newX * invW, newY * invW, newZ * invW, newW }
	end

	return { newX, newY, newZ, newW }
end

--- Transform direction vector (no translation component)
---@param direction table Direction as {[1]=x, [2]=y, [3]=z}
---@param m table 4x4 matrix as 16-element flat row-major array
---@return table normalized Normalized direction vector
function CullingSystem:transformDirectionRowMajor(direction, m)
	local x, y, z = direction[1] or 0, direction[2] or 0, direction[3] or 0

	local newX = x * m[1] + y * m[5] + z * m[9]
	local newY = x * m[2] + y * m[6] + z * m[10]
	local newZ = x * m[3] + y * m[7] + z * m[11]

	-- Normalize
	local len = math_sqrt(newX ^ 2 + newY ^ 2 + newZ ^ 2)
	if len > 0 then
		return { newX / len, newY / len, newZ / len }
	end

	return { newX, newY, newZ }
end

----------------------------------------------------------------------
-- FRUSTUM PLANE EXTRACTION (ROW-MAJOR, FLAT ARRAY)
----------------------------------------------------------------------

--- Extract frustum planes from a combined view-projection matrix
---@param m table 4x4 matrix as 16-element flat row-major array
---@return table frustum Array of 6 frustum planes
function CullingSystem:extractFrustumFromMatrixRowMajor(m)
	local frustum = self:createFrustum()

	-- Extract columns from flat row-major matrix
	-- Col 0: m[1], m[5], m[9],  m[13]
	-- Col 1: m[2], m[6], m[10], m[14]
	-- Col 2: m[3], m[7], m[11], m[15]
	-- Col 3: m[4], m[8], m[12], m[16]

	-- LEFT PLANE [1]: col0 + col3
	frustum[1][1] = m[1] + m[4]
	frustum[1][2] = m[5] + m[8]
	frustum[1][3] = m[9] + m[12]
	frustum[1][4] = m[13] + m[16]

	-- RIGHT PLANE [2]: col3 - col0
	frustum[2][1] = m[4] - m[1]
	frustum[2][2] = m[8] - m[5]
	frustum[2][3] = m[12] - m[9]
	frustum[2][4] = m[16] - m[13]

	-- BOTTOM PLANE [3]: col1 + col3
	frustum[3][1] = m[2] + m[4]
	frustum[3][2] = m[6] + m[8]
	frustum[3][3] = m[10] + m[12]
	frustum[3][4] = m[14] + m[16]

	-- TOP PLANE [4]: col3 - col1
	frustum[4][1] = m[4] - m[2]
	frustum[4][2] = m[8] - m[6]
	frustum[4][3] = m[12] - m[10]
	frustum[4][4] = m[16] - m[14]

	-- NEAR PLANE [5]: col2
	frustum[5][1] = m[3]
	frustum[5][2] = m[7]
	frustum[5][3] = m[11]
	frustum[5][4] = m[15]

	-- FAR PLANE [6]: col3 - col2
	frustum[6][1] = m[4] - m[3]
	frustum[6][2] = m[8] - m[7]
	frustum[6][3] = m[12] - m[11]
	frustum[6][4] = m[16] - m[15]

	-- Normalize all planes
	for i = 1, 6 do
		local plane = frustum[i]
		local len = math_sqrt(
			plane[1] ^ 2 +
			plane[2] ^ 2 +
			plane[3] ^ 2
		)
		if len > 0.0001 then
			local invLen = 1.0 / len
			plane[1] = plane[1] * invLen
			plane[2] = plane[2] * invLen
			plane[3] = plane[3] * invLen
			plane[4] = plane[4] * invLen
		end
	end

	return frustum
end

--- Extract frustum from separate View and Projection matrices
---@param viewMatrix table 4x4 view matrix
---@param projMatrix table 4x4 projection matrix
---@return table frustum Array of 6 frustum planes
function CullingSystem:extractFrustumFromViewProjSeparate(viewMatrix, projMatrix)
	local vp = self:multiplyMatricesRowMajor(viewMatrix, projMatrix)
	return self:extractFrustumFromMatrixRowMajor(vp)
end

--- Row-major matrix multiplication: result = A * B
--- All matrices are 16-element flat arrays
---@param a table 4x4 matrix A
---@param b table 4x4 matrix B
---@return table result 4x4 result matrix
function CullingSystem:multiplyMatricesRowMajor(a, b)
	local r = {}

	for i = 0, 3 do
		local ai = i * 4
		for j = 1, 4 do
			r[ai + j] =
				a[ai + 1] * b[j] +
				a[ai + 2] * b[4 + j] +
				a[ai + 3] * b[8 + j] +
				a[ai + 4] * b[12 + j]
		end
	end

	return r
end

----------------------------------------------------------------------
-- AABB VS PLANE TESTS (OPTIMIZED FOR ROW-MAJOR WORKFLOW)
----------------------------------------------------------------------

--- Test AABB against a single plane (optimized for inside/outside)
---@param aabb table AABB to test
---@param plane table Plane to test against
---@return boolean inside True if AABB is inside or intersecting the plane
function CullingSystem:testAABBAgainstPlaneOptimized(aabb, plane)
	local px = (plane[1] < 0) and aabb[1] or aabb[4]
	local py = (plane[2] < 0) and aabb[2] or aabb[5]
	local pz = (plane[3] < 0) and aabb[3] or aabb[6]

	local dist = plane[1] * px +
		plane[2] * py +
		plane[3] * pz +
		plane[4]

	return dist >= -0.001
end

--- Full frustum test returning outside/intersecting/inside status
---@param frustum table Array of 6 frustum planes
---@param aabb table AABB to test
---@return string status "outside", "intersecting", or "inside"
function CullingSystem:testFrustumFull(self, frustum, aabb)
	local intersecting = false

	for i = 1, 6 do
		local plane = frustum[i]

		local rx = (plane[1] < 0) and aabb[4] or aabb[1]
		local ry = (plane[2] < 0) and aabb[5] or aabb[2]
		local rz = (plane[3] < 0) and aabb[6] or aabb[3]

		local dist = plane[1] * rx +
			plane[2] * ry +
			plane[3] * rz +
			plane[4]

		if dist < -0.001 then
			return "outside"
		end

		local projectedRadius = aabb[10] * math_abs(plane[1]) +
			aabb[11] * math_abs(plane[2]) +
			aabb[12] * math_abs(plane[3])

		if dist < projectedRadius then
			intersecting = true
		end
	end

	return intersecting and "intersecting" or "inside"
end

--- Binary frustum test (inside/outside only, faster than full test)
---@param frustum table Array of 6 frustum planes
---@param aabb table AABB to test
---@return boolean inside True if AABB is inside or intersecting the frustum
function CullingSystem:testFrustumBinary(frustum, aabb)
	for i = 1, 6 do
		local plane = frustum[i]

		local px = (plane[1] < 0) and aabb[1] or aabb[4]
		local py = (plane[2] < 0) and aabb[2] or aabb[5]
		local pz = (plane[3] < 0) and aabb[3] or aabb[6]

		local dist = plane[1] * px +
			plane[2] * py +
			plane[3] * pz +
			plane[4]

		if dist < -0.001 then
			return false
		end
	end

	return true
end

----------------------------------------------------------------------
-- OCCLUSION CULLING
----------------------------------------------------------------------

--- Create a hierarchical depth buffer (Hi-Z) with multiple mip levels
---@param width number Buffer width in pixels
---@param height number Buffer height in pixels
---@param levels? number Number of mip levels (default: 6)
---@return table depthBuffers Array of depth buffer levels
function CullingSystem:createDepthBuffer(width, height, levels)
	local levels = levels or 6
	local buffers = {}

	local w = width
	local h = height

	for level = 1, levels do
		buffers[level] = {
			w,
			h,
			{},
			{},
			{}
		}

		for i = 1, w * h do
			buffers[level][3][i] = 1.0
			buffers[level][4][i] = 1.0
			buffers[level][5][i] = -1.0
		end

		w = math_ceil(w / 2)
		h = math_ceil(h / 2)
	end

	return buffers
end

--- Update depth buffer after rendering chunk to screen-space quad
---@param depthBuffers table Hi-Z depth buffer
---@param xStart number Start X position
---@param yStart number Start Y position
---@param width number Width of update region
---@param height number Height of update region
---@param depthMap table Depth values to write
function CullingSystem:updateDepthBuffer(depthBuffers, xStart, yStart, width, height, depthMap)
	local level1 = depthBuffers[1]

	local yLimit = math_min(yStart + height - 1, level1[2] - 1)
	local xLimit = math_min(xStart + width - 1, level1[1] - 1)

	for y = yStart, yLimit do
		local baseIdx = y * level1[1] + 1
		for x = xStart, xLimit do
			local idx = baseIdx + x
			local depth = depthMap[(y - yStart) * width + (x - xStart) + 1] or 1.0

			if depth < level1[3][idx] then
				level1[3][idx] = depth
			end
		end
	end
end

--- Build mip levels (conservative min-depth for occlusion queries)
---@param depthBuffers table Hi-Z depth buffer to update
function CullingSystem:buildHiZMipmaps(depthBuffers)
	for level = 2, #depthBuffers do
		local parent = depthBuffers[level - 1]
		local child = depthBuffers[level]

		local pw = parent[1]
		local cw = child[1]
		local ch = child[2]

		for by = 0, ch - 1 do
			local srcBase = (by * 2) * pw + 1
			local destBase = by * cw + 1

			for bx = 0, cw - 1 do
				local idx = destBase + bx

				local d1 = parent[3][srcBase + (bx * 2)] or 1.0
				local d2 = parent[3][srcBase + (bx * 2) + 1] or 1.0
				local d3 = parent[3][srcBase + pw + (bx * 2)] or 1.0
				local d4 = parent[3][srcBase + pw + (bx * 2) + 1] or 1.0

				child[3][idx] = math_min(d1, d2, d3, d4)
			end
		end
	end
end

--- Test AABB occlusion using hierarchical Z-buffer
---@param depthBuffers table Hi-Z depth buffer
---@param aabb table AABB to test
---@param screenProj function Screen projection callback(x, y, z) -> sx, sy, sz
---@param nearZ? number Near plane Z threshold
---@return boolean occluded True if AABB is occluded
function CullingSystem:testOcclusionHiZ(depthBuffers, aabb, screenProj, nearZ)
	local corners = {
		{ aabb[1], aabb[2], aabb[3] },
		{ aabb[4], aabb[2], aabb[3] },
		{ aabb[1], aabb[5], aabb[3] },
		{ aabb[4], aabb[5], aabb[3] },
		{ aabb[1], aabb[2], aabb[6] },
		{ aabb[4], aabb[2], aabb[6] },
		{ aabb[1], aabb[5], aabb[6] },
		{ aabb[4], aabb[5], aabb[6] }
	}

	local minX, maxX, minY, maxY = math_huge, -math_huge, math_huge, -math_huge
	local nearZValue = nearZ or -1

	for i = 1, 8 do
		local sx, sy, sz = screenProj(corners[i][1], corners[i][2], corners[i][3])
		minX = math_min(minX, sx)
		maxX = math_max(maxX, sx)
		minY = math_min(minY, sy)
		maxY = math_max(maxY, sy)

		if sz < nearZValue then nearZValue = sz end
	end

	if minX >= maxX or minY >= maxY then
		return true
	end

	local screenW = depthBuffers[1][1]
	local screenH = depthBuffers[1][2]
	minX = math_floor(math_max(0, minX))
	maxX = math_ceil(math_min(screenW - 1, maxX))
	minY = math_floor(math_max(0, minY))
	maxY = math_ceil(math_min(screenH - 1, maxY))

	for level = #depthBuffers, 1, -1 do
		local buffer = depthBuffers[level]
		local scale = 1.0 / (2 ^ (level - 1))

		local lbx = math_floor(minX * scale)
		local lby = math_floor(minY * scale)
		local ubx = math_ceil(maxX * scale)
		local uby = math_ceil(maxY * scale)

		local bw = buffer[1]
		local bh = buffer[2]

		for by = lby, math_min(uby, bh - 1) do
			local rowBase = by * bw + 1
			for bx = lbx, math_min(ubx, bw - 1) do
				local storedDepth = buffer[3][rowBase + bx] or 1.0

				if nearZValue < storedDepth * 0.995 then
					return false
				end
			end
		end
	end

	return true
end

----------------------------------------------------------------------
-- FRUSTUM CULLING
----------------------------------------------------------------------

--- Frustum-cull a list of chunks. Returns visible chunks and sets chunk[5] = true for visible.
--- Each frame: for chunk in loadedChunks: if chunkAabb intersects cameraFrustum: render
---@param frustum table Array of 6 frustum planes
---@param chunks table Array of chunks to cull
---@return table visible Array of visible chunks
function CullingSystem:frustumCullChunks(frustum, chunks)
	local visible = {}
	for i = 1, #chunks do
		local chunk = chunks[i]
		if self:testFrustumBinary(frustum, chunk[4]) then
			chunk[5] = true
			visible[#visible + 1] = chunk
		else
			chunk[5] = false
		end
	end
	return visible
end

----------------------------------------------------------------------
-- CHUNK BULK CULLING PIPELINE (FRUSTUM + OCCLUSION)
----------------------------------------------------------------------

--- Full culling pipeline combining frustum and Hi-Z occlusion culling
---@param frustum table Array of 6 frustum planes
---@param depthBuffers table Hi-Z depth buffer
---@param chunks table Array of chunks to cull
---@param screenProj function Screen projection callback
---@param nearZ number Near plane Z
---@param farZ number Far plane Z
---@return table stats Culling statistics [total, frustumCulled, occlusionCulled, visible]
function CullingSystem:cullChunksPipeline(frustum, depthBuffers, chunks, screenProj, nearZ, farZ)
	local stats = {
		#chunks,
		0,
		0,
		0
	}

	for i = 1, #chunks do
		local chunk = chunks[i]
		chunk[6] = false
		chunk[7] = false
		chunk[5] = false
	end

	table_sort(chunks, function(a, b)
		local ad = a[4][7] ^ 2 + a[4][8] ^ 2 + a[4][9] ^ 2
		local bd = b[4][7] ^ 2 + b[4][8] ^ 2 + b[4][9] ^ 2
		return ad > bd
	end)

	for i = 1, #chunks do
		local chunk = chunks[i]

		if self:testFrustumBinary(frustum, chunk[4]) then
			chunk[6] = true

			if not self:testOcclusionHiZ(depthBuffers, chunk[4], screenProj, nearZ) then
				chunk[5] = true
				stats[4] = stats[4] + 1
			else
				chunk[7] = true
				stats[3] = stats[3] + 1
			end
		else
			stats[2] = stats[2] + 1
		end
	end

	return stats
end

----------------------------------------------------------------------
-- EXAMPLE USAGE WITH ROW-MAJOR FLAT-ARRAY MATRICES
----------------------------------------------------------------------

--- Demo function showing basic row-major matrix usage
function CullingSystem:demoRowMajorUsage()
	print("==============================================")
	print("VOXEL CULLING DEMO (FLAT ROW-MAJOR)")
	print("==============================================\n")

	local fov = 90
	local aspect = 16.0 / 9.0
	local nearZ = 0.1
	local farZ = 1000.0

	local f = 1.0 / math_tan(math_rad(fov) * 0.5)
	local fn = farZ * nearZ
	local nf = nearZ - farZ

	-- Row-major flat array: m[(row-1)*4 + col]
	--   Row 0: m[1]  m[2]  m[3]  m[4]
	--   Row 1: m[5]  m[6]  m[7]  m[8]
	--   Row 2: m[9]  m[10] m[11] m[12]
	--   Row 3: m[13] m[14] m[15] m[16]
	local projMatrix = {
		f / aspect, 0, 0, 0,
		0, f, 0, 0,
		0, 0, farZ / nf, -1,
		0, 0, fn / nf, 0
	}

	print("Created row-major projection matrix")
	print(string_format("    FOV: %.1f°, Aspect: %.2f, Near: %.3f, Far: %.1f\n",
		fov, aspect, nearZ, farZ))

	local viewMatrix = {
		1, 0, 0, 0,
		0, 1, 0, 0,
		0, 0, 1, 0,
		0, 0, 0, 1
	}

	local vpMatrix = self:multiplyMatricesRowMajor(viewMatrix, projMatrix)
	print("Computed View-Projection matrix\n")

	local frustum = self:extractFrustumFromMatrixRowMajor(vpMatrix)
	print("Frustum planes extracted:")
	print(string_format("    Left:   (%.3f, %.3f, %.3f) d=%.3f",
		frustum[1][1], frustum[1][2], frustum[1][3], frustum[1][4]))
	print(string_format("    Right:  (%.3f, %.3f, %.3f) d=%.3f",
		frustum[2][1], frustum[2][2], frustum[2][3], frustum[2][4]))
	print(string_format("    Top:    (%.3f, %.3f, %.3f) d=%.3f",
		frustum[4][1], frustum[4][2], frustum[4][3], frustum[4][4]))
	print(string_format("    Bottom: (%.3f, %.3f, %.3f) d=%.3f",
		frustum[3][1], frustum[3][2], frustum[3][3], frustum[3][4]))
	print(string_format("    Near:   (%.3f, %.3f, %.3f) d=%.3f",
		frustum[5][1], frustum[5][2], frustum[5][3], frustum[5][4]))
	print(string_format("    Far:    (%.3f, %.3f, %.3f) d=%.3f\n",
		frustum[6][1], frustum[6][2], frustum[6][3], frustum[6][4]))

	local chunks = {}
	for x = -20, 20, 4 do
		for y = -8, 8, 4 do
			for z = -20, 20, 4 do
				if math_random() > 0.2 then
					local chunk = self:createChunk(x * 16, y * 16, z * 16, 16)
					table_insert(chunks, chunk)
				end
			end
		end
	end
	print(string_format("Generated %d sample chunks\n", #chunks))

	-- Frustum-only culling (fast, per-frame)
	local visibleChunks = self:frustumCullChunks(frustum, chunks)
	print("Frustum culling:")
	print(string_format("    Total:     %d", #chunks))
	print(string_format("    Visible:   %d (%.1f%%)", #visibleChunks,
		100 * #visibleChunks / #chunks))
	print(string_format("    Culled:    %d (%.1f%%)\n",
		#chunks - #visibleChunks,
		100 * (#chunks - #visibleChunks) / #chunks))

	-- Full pipeline with Hi-Z occlusion culling
	local screenW = 1920
	local screenH = 1080
	local depthBuffers = self:createDepthBuffer(screenW, screenH, 6)
	print(string_format("Hi-Z depth buffer initialized: %dx%d @ 6 levels\n", screenW, screenH))

	local function rowMajorScreenProj(x, y, z)
		local w = x * projMatrix[4] + y * projMatrix[8] + z * projMatrix[12] + projMatrix[16]
		if math_abs(w) < 0.0001 then w = 0.0001 end

		local ndcX = (x * projMatrix[1] + y * projMatrix[5] + z * projMatrix[9] + projMatrix[13]) / w
		local ndcY = (x * projMatrix[2] + y * projMatrix[6] + z * projMatrix[10] + projMatrix[14]) / w
		local ndcZ = (x * projMatrix[3] + y * projMatrix[7] + z * projMatrix[11] + projMatrix[15]) / w

		local screenX = (ndcX + 1) * 0.5 * screenW
		local screenY = (1 - ndcY) * 0.5 * screenH
		local depth = (ndcZ + 1) * 0.5

		return screenX, screenY, depth
	end

	local stats = self:cullChunksPipeline(frustum, depthBuffers, chunks,
		rowMajorScreenProj, 0.1, 1000.0)

	print("Full pipeline (frustum + occlusion):")
	print(string_format("    Total chunks:      %d", stats[1]))
	print(string_format("    Frustum culled:    %d (%.1f%%)", stats[2],
		100 * stats[2] / stats[1]))
	print(string_format("    Occlusion culled:  %d (%.1f%%)", stats[3],
		100 * stats[3] / (stats[1] - stats[2])))
	print(string_format("    Visible:           %d (%.1f%%)\n", stats[4],
		100 * stats[4] / stats[1]))
end

--CullingSystem:demoRowMajorUsage()

----------------------------------------------------------------------
-- ADVANCED VOXEL RENDERING FEATURES
----------------------------------------------------------------------

--- Estimate the screen-space area (in pixels) of an AABB for LOD determination
---@param aabb table AABB to estimate
---@param cameraPos table Camera position {[1]=x, [2]=y, [3]=z}
---@param projMatrix table Projection matrix
---@param screenHeight number Screen height in pixels
---@return number area Approximate screen area in pixels
function CullingSystem:estimateScreenArea(aabb, cameraPos, projMatrix, screenHeight)
	local dx = aabb[7] - cameraPos[1]
	local dy = aabb[8] - cameraPos[2]
	local dz = aabb[9] - cameraPos[3]
	local distSq = dx * dx + dy * dy + dz * dz

	-- Camera is inside or extremely close to the AABB
	if distSq < 0.01 then return math_huge end

	-- Bounding sphere radius approximation
	local radius = math_max(aabb[10], aabb[11], aabb[12])
	local dist = math_sqrt(distSq)

	-- projMatrix[6] is 'f' (1 / tan(fov/2)) in row-major
	local f = projMatrix[6] or 1.0
	local screenRadius = (radius * f * screenHeight) / (2.0 * dist)

	-- Return approximate area (pi * r^2)
	return 3.14159 * screenRadius * screenRadius
end

--- Conservative AABB Hi-Z rasterization for software occlusion culling
--- Rasterizes a chunk's AABB directly into the CPU Hi-Z buffer using its closest depth.
--- This allows subsequent chunks to be occluded by this chunk without GPU readbacks.
---@param depthBuffers table Hi-Z depth buffer to write to
---@param aabb table AABB to rasterize
---@param screenProj function Screen projection callback
function CullingSystem:rasterizeAABBToHiZ(depthBuffers, aabb, screenProj)
	local corners = {
		{ aabb[1], aabb[2], aabb[3] }, { aabb[4], aabb[2], aabb[3] },
		{ aabb[1], aabb[5], aabb[3] }, { aabb[4], aabb[5], aabb[3] },
		{ aabb[1], aabb[2], aabb[6] }, { aabb[4], aabb[2], aabb[6] },
		{ aabb[1], aabb[5], aabb[6] }, { aabb[4], aabb[5], aabb[6] }
	}

	local minX, maxX, minY, maxY = math_huge, -math_huge, math_huge, -math_huge
	local minZ = math_huge

	for i = 1, 8 do
		local sx, sy, sz = screenProj(corners[i][1], corners[i][2], corners[i][3])
		if sx < minX then minX = sx end
		if sx > maxX then maxX = sx end
		if sy < minY then minY = sy end
		if sy > maxY then maxY = sy end
		if sz < minZ then minZ = sz end -- Conservative: use closest depth
	end

	local screenW = depthBuffers[1][1]
	local screenH = depthBuffers[1][2]
	minX = math_floor(math_max(0, minX))
	maxX = math_ceil(math_min(screenW - 1, maxX))
	minY = math_floor(math_max(0, minY))
	maxY = math_ceil(math_min(screenH - 1, maxY))

	if minX > maxX or minY > maxY or minZ >= 1.0 then return end

	-- Write to Level 0
	local level1 = depthBuffers[1]
	for y = minY, maxY do
		local baseIdx = y * level1[1] + 1
		for x = minX, maxX do
			local idx = baseIdx + x
			if minZ < level1[3][idx] then
				level1[3][idx] = minZ
			end
		end
	end

	-- 3. REGION-BASED MIPMAP UPDATE (Optimization)
	self:updateHiZMipmapsRegion(depthBuffers, minX, minY, maxX, maxY)
end

--- Only rebuilds mipmaps for the affected bounding box region, saving massive CPU time
---@param depthBuffers table Hi-Z depth buffer
---@param minX number Minimum X of affected region
---@param minY number Minimum Y of affected region
---@param maxX number Maximum X of affected region
---@param maxY number Maximum Y of affected region
function CullingSystem:updateHiZMipmapsRegion(depthBuffers, minX, minY, maxX, maxY)
	local pMinX, pMinY, pMaxX, pMaxY = minX, minY, maxX, maxY

	for level = 2, #depthBuffers do
		local parent = depthBuffers[level - 1]
		local child = depthBuffers[level]
		local pw = parent[1]
		local cw = child[1]

		local cMinX = math_floor(pMinX / 2)
		local cMinY = math_floor(pMinY / 2)
		local cMaxX = math_floor(pMaxX / 2)
		local cMaxY = math_floor(pMaxY / 2)

		for by = cMinY, math_min(cMaxY, child[2] - 1) do
			local srcBase = (by * 2) * pw + 1
			local destBase = by * cw + 1
			for bx = cMinX, math_min(cMaxX, cw - 1) do
				local idx = destBase + bx
				local d1 = parent[3][srcBase + (bx * 2)] or 1.0
				local d2 = parent[3][srcBase + (bx * 2) + 1] or 1.0
				local d3 = parent[3][srcBase + pw + (bx * 2)] or 1.0
				local d4 = parent[3][srcBase + pw + (bx * 2) + 1] or 1.0
				child[3][idx] = math_min(d1, d2, d3, d4)
			end
		end
		pMinX, pMinY, pMaxX, pMaxY = cMinX, cMinY, cMaxX, cMaxY
	end
end

--- Compute chunk facing mask for voxel meshing optimization
--- Returns a bitmask of which outer chunk faces are visible to the camera.
--- 1: Left(-X), 2: Right(+X), 4: Bottom(-Y), 8: Top(+Y), 16: Near(-Z), 32: Far(+Z)
--- Use this in your Greedy Meshing algorithm to skip generating guaranteed hidden outer faces.
---@param chunk table Chunk to compute mask for
---@param cameraPos table Camera position {[1]=x, [2]=y, [3]=z}
---@return number mask Bitmask of visible faces
function CullingSystem:computeChunkFacingMask(chunk, cameraPos)
	local aabb = chunk[4]
	local mask = 0
	if cameraPos[1] < aabb[1] then mask = mask + 1 end -- Left
	if cameraPos[1] > aabb[4] then mask = mask + 2 end -- Right
	if cameraPos[2] < aabb[2] then mask = mask + 4 end -- Bottom
	if cameraPos[2] > aabb[5] then mask = mask + 8 end -- Top
	if cameraPos[3] < aabb[3] then mask = mask + 16 end -- Near
	if cameraPos[3] > aabb[6] then mask = mask + 32 end -- Far
	return mask
end

--- Advanced voxel culling pipeline (frustum + area/LOD + software occlusion)
--- Sorts front-to-back, culls by frustum, culls by screen area (LOD), tests Hi-Z, and rasterizes.
---@param frustum table Array of 6 frustum planes
---@param depthBuffers table Hi-Z depth buffer
---@param chunks table Array of chunks to cull
---@param screenProj function Screen projection callback
---@param cameraPos table Camera position {[1]=x, [2]=y, [3]=z}
---@param projMatrix table Projection matrix
---@param screenH number Screen height in pixels
---@param nearZ number Near plane Z
---@param farZ number Far plane Z
---@return table stats Culling statistics
function CullingSystem:cullChunksAdvancedPipeline(frustum, depthBuffers, chunks, screenProj, cameraPos, projMatrix,
												  screenH, nearZ, farZ)
	local stats = {
		total = #chunks,
		frustumCulled = 0,
		areaCulled = 0,
		occlusionCulled = 0,
		visible = 0
	}

	local minPixelArea = 4.0 -- Cull chunks smaller than 4 pixels (or assign to LOD)

	-- Reset states
	for i = 1, #chunks do
		local chunk = chunks[i]
		chunk[5] = false -- visible
		chunk[6] = false -- frustum
		chunk[7] = false -- occluded
		chunk[8] = 0 -- LOD / RenderQueue
	end

	-- Sort Front-to-Back (Crucial for Software Occlusion Culling)
	local cx, cy, cz = cameraPos[1], cameraPos[2], cameraPos[3]
	table_sort(chunks, function(a, b)
		local aabbA, aabbB = a[4], b[4]
		local adx, ady, adz = aabbA[7] - cx, aabbA[8] - cy, aabbA[9] - cz
		local bdx, bdy, bdz = aabbB[7] - cx, aabbB[8] - cy, aabbB[9] - cz
		return (adx * adx + ady * ady + adz * adz) < (bdx * bdx + bdy * bdy + bdz * bdz)
	end)

	for i = 1, #chunks do
		local chunk = chunks[i]
		local aabb = chunk[4]

		if not self:testFrustumBinary(frustum, aabb) then
			-- Frustum culled
			stats.frustumCulled = stats.frustumCulled + 1
		else
			local area = self:estimateScreenArea(aabb, cameraPos, projMatrix, screenH)

			if area < minPixelArea then
				-- Screen-space area too small / LOD culled
				stats.areaCulled = stats.areaCulled + 1
				chunk[8] = -1
			elseif self:testOcclusionHiZ(depthBuffers, aabb, screenProj, nearZ) then
				-- Occluded by previously rasterized geometry
				chunk[7] = true
				stats.occlusionCulled = stats.occlusionCulled + 1
			else
				-- Visible: assign LOD, rasterize into Hi-Z for subsequent chunks
				chunk[6] = true
				chunk[5] = true
				stats.visible = stats.visible + 1

				if area > 10000 then
					chunk[8] = 0
				elseif area > 2000 then
					chunk[8] = 1
				else
					chunk[8] = 2
				end

				self:rasterizeAABBToHiZ(depthBuffers, aabb, screenProj)
			end
		end
	end

	return stats
end

----------------------------------------------------------------------
-- DEMO: ADVANCED VOXEL PIPELINE
----------------------------------------------------------------------
--- Demo function showing advanced voxel culling pipeline with SOC and LOD
function CullingSystem:demoAdvancedVoxelUsage()
	print("\n==============================================")
	print("ADVANCED VOXEL PIPELINE DEMO (SOC + LOD)")
	print("==============================================\n")

	-- Setup Camera & Matrices
	local screenW, screenH = 1920, 1080
	local fov, aspect, nearZ, farZ = 90, 1920 / 1080, 0.1, 1000.0
	local f = 1.0 / math_tan(math_rad(fov) * 0.5)
	local fn, nf = farZ * nearZ, nearZ - farZ

	local projMatrix = {
		f / aspect, 0, 0, 0,
		0, f, 0, 0,
		0, 0, farZ / nf, -1,
		0, 0, fn / nf, 0
	}

	local viewMatrix = { 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1 }
	local vpMatrix = self:multiplyMatricesRowMajor(viewMatrix, projMatrix)
	local frustum = self:extractFrustumFromMatrixRowMajor(vpMatrix)

	-- Generate dense voxel chunks (e.g., 40x40x40 grid)
	local chunks = {}
	for x = -20, 20, 2 do
		for y = -10, 10, 2 do
			for z = -20, 20, 2 do
				if math_random() > 0.1 then -- 90% fill rate
					table_insert(chunks, self:createChunk(x * 16, y * 16, z * 16, 16))
				end
			end
		end
	end
	print(string_format("Generated %d dense voxel chunks", #chunks))

	-- Setup Depth Buffer & Projection Function
	local depthBuffers = self:createDepthBuffer(screenW, screenH, 6)
	local cameraPos = { 0, 0, 0 } -- Camera at origin

	local function rowMajorScreenProj(x, y, z)
		local w = x * projMatrix[4] + y * projMatrix[8] + z * projMatrix[12] + projMatrix[16]
		if math_abs(w) < 0.0001 then w = 0.0001 end
		local ndcX = (x * projMatrix[1] + y * projMatrix[5] + z * projMatrix[9] + projMatrix[13]) / w
		local ndcY = (x * projMatrix[2] + y * projMatrix[6] + z * projMatrix[10] + projMatrix[14]) / w
		local ndcZ = (x * projMatrix[3] + y * projMatrix[7] + z * projMatrix[11] + projMatrix[15]) / w
		return (ndcX + 1) * 0.5 * screenW, (1 - ndcY) * 0.5 * screenH, (ndcZ + 1) * 0.5
	end

	-- Run Advanced Pipeline
	local stats = self:cullChunksAdvancedPipeline(
		frustum, depthBuffers, chunks, rowMajorScreenProj,
		cameraPos, projMatrix, screenH, nearZ, farZ
	)

	print("\nAdvanced Culling Stats:")
	print(string_format("    Total Chunks:      %d", stats.total))
	print(string_format("    Frustum Culled:    %d (%.1f%%)", stats.frustumCulled,
		100 * stats.frustumCulled / stats.total))

	local remaining = stats.total - stats.frustumCulled
	print(string_format("    Area/LOD Culled:   %d (%.1f%% of remaining)", stats.areaCulled,
		100 * stats.areaCulled / math_max(1, remaining)))

	local remaining2 = remaining - stats.areaCulled
	print(string_format("    Occlusion Culled:  %d (%.1f%% of remaining)", stats.occlusionCulled,
		100 * stats.occlusionCulled / math_max(1, remaining2)))
	print(string_format("    Final Visible:     %d (%.1f%% of total)\n", stats.visible, 100 * stats.visible / stats
		.total))

	-- Demonstrate Facing Mask for Meshing
	local sampleChunk = chunks[math_floor(#chunks / 2)]
	local mask = self:computeChunkFacingMask(sampleChunk, cameraPos)
	print(string_format("Meshing Hint for Chunk (X:%.0f Y:%.0f Z:%.0f):", sampleChunk[1], sampleChunk[2],
		sampleChunk[3]))
	print("    Visible Outer Faces Mask: " .. mask)
	print("    (Pass this to Greedy Mesher to skip hidden exterior faces)")
end

--CullingSystem:demoAdvancedVoxelUsage()

-- Export
return CullingSystem
