-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Noise library (Y is vertical axis here)
-- Features: Perlin, Simplex, Worley, FBM, Ridged, Domain Warping

---@class math.noise
---@field seed number Seed for random generation
---@field perm table  Permutation table for noise generation

local Noise = {}
Noise.__index = Noise

-- Localized global functions for better performance
local math_abs = math.abs
local math_cos = math.cos
local math_floor = math.floor
local math_huge = math.huge
local math_max = math.max
local math_min = math.min
local math_pi = math.pi
local math_random = math.random
local math_sin = math.sin
local math_sqrt = math.sqrt

-- Constants
local PERM_SIZE = 256
local PERM_MASK = 255

-- Precomputed permutation table (standard Perlin reference)
local DEFAULT_PERM = {
	151, 160, 137, 91, 90, 15, 131, 13, 201, 95, 96, 53, 194, 233, 7, 225, 140, 36, 103, 30, 69, 142, 8, 99, 37, 240, 21,
	10, 23, 190, 6, 148, 247, 120, 234, 75, 0, 26, 197, 62, 94, 252, 219, 203, 117, 35, 11, 32, 57, 177, 33, 88, 237,
	149, 56, 87, 174, 20, 125, 136, 171, 168, 68, 175, 74, 165, 71, 134, 139, 48, 27, 166, 77, 146, 158, 231, 83, 111,
	229, 122, 60, 211, 133, 230, 220, 105, 92, 41, 55, 46, 245, 40, 244, 102, 143, 54, 65, 25, 63, 161, 1, 216, 80, 73,
	209, 76, 132, 187, 208, 89, 18, 169, 200, 196, 135, 130, 116, 188, 159, 86, 164, 100, 109, 198, 173, 186, 3, 64, 52,
	217, 226, 250, 124, 123, 5, 202, 38, 147, 118, 126, 255, 82, 85, 212, 207, 206, 59, 227, 47, 16, 58, 17, 182, 189,
	28, 42, 223, 183, 170, 213, 119, 248, 152, 2, 44, 154, 163, 70, 221, 153, 101, 155, 167, 43, 172, 9, 129, 22, 39,
	253, 19, 98, 108, 110, 79, 113, 224, 232, 178, 185, 112, 104, 218, 246, 97, 228, 251, 34, 242, 193, 238, 210, 144,
	12, 191, 179, 162, 241, 81, 51, 145, 235, 249, 14, 239, 107, 49, 192, 214, 31, 181, 199, 106, 157, 184, 84, 204, 176,
	115, 121, 50, 45, 127, 4, 150, 254, 138, 236, 205, 93, 222, 114, 67, 29, 24, 72, 243, 141, 128, 195, 78, 66, 215, 61,
	156, 180
}

-- Gradients for 2D/3D
local GRAD_2D = { { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 }, { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }

local GRAD_3D = {
	{ 1, 1, 0 }, { -1, 1, 0 }, { 1, -1, 0 }, { -1, -1, 0 }, { 1, 0, 1 }, { -1, 0, 1 }, { 1, 0, -1 }, { -1, 0, -1 },
	{ 0, 1, 1 }, { 0, -1, 1 }, { 0, 1, -1 }, { 0, -1, -1 }, { 1, 1, 0 }, { -1, 1, 0 }, { 0, -1, 1 }, { 0, -1, -1 }
}

----------------------------------------------------------------------
-- Internal Utilities
----------------------------------------------------------------------

--- 6t^5 - 15t^4 + 10t^3 fade curve for Perlin noise
---@param t number Value to fade (0-1)
---@return number value Faded value
local function fade(t)
	return t * t * t * (t * (t * 6 - 15) + 10)
end

--- Linear interpolation between two values
---@param a number Start value
---@param b number End value
---@param t number Interpolation factor (0-1)
---@return number value Interpolated value
local function lerp(a, b, t)
	return a + t * (b - a)
end

--- Dot product for 2D gradients
---@param g number[] Gradient vector {x, y}
---@param x number   X coordinate
---@param y number   Y coordinate
---@return number result Dot product result
local function dot2(g, x, y)
	return g[1] * x + g[2] * y
end

--- Dot product for 3D gradients
---@param g number[] Gradient vector {x, y, z}
---@param x number   X coordinate
---@param y number   Y coordinate
---@param z number   Z coordinate
---@return number result Dot product result
local function dot3(g, x, y, z)
	return g[1] * x + g[2] * y + g[3] * z
end

----------------------------------------------------------------------
-- Permutation Table Management
----------------------------------------------------------------------

--- Create a new noise generator instance
---@param seed number | nil Optional seed for random generation (defaults to random)
---@return math.noise instance New noise generator instance
function Noise.new(seed)
	local self = setmetatable({
		seed = seed or math_random(1, 100000),
		perm = {}
	}, Noise)
	self:reseed(self.seed)
	return self
end

--- Reseed the noise generator with a new seed
---@param seed number New seed for random generation
function Noise:reseed(seed)
	self.seed = seed
	-- Shuffle permutation using LCG
	local perm = {}
	for i = 0, PERM_SIZE - 1 do
		perm[i] = DEFAULT_PERM[i + 1] or i
	end

	-- Fisher-Yates shuffle with seeded RNG
	local state = seed
	local function rng()
		state = (state * 1103515245 + 12345) % 2147483648
		return state
	end

	for i = PERM_SIZE - 1, 1, -1 do
		local j = (rng() % (i + 1))
		perm[i], perm[j] = perm[j], perm[i]
	end

	-- Duplicate for overflow safety
	for i = 0, PERM_SIZE - 1 do
		self.perm[i] = perm[i]
		self.perm[i + PERM_SIZE] = perm[i]
	end
end

--- Hash coordinates to get a permutation table value
---@param x number       X coordinate
---@param y number       Y coordinate
---@param z number | nil Z coordinate (defaults to 0)
---@return number value Hashed permutation value
function Noise:hash(x, y, z)
	z = z or 0
	local p = self.perm
	return p[(p[(p[math_floor(x) % PERM_SIZE] + math_floor(y)) % PERM_SIZE] + math_floor(z)) % PERM_SIZE]
end

----------------------------------------------------------------------
-- 2D Perlin Noise
----------------------------------------------------------------------

--- Generate 2D Perlin noise
---@param x number X coordinate
---@param y number Y coordinate
---@return number value Noise value (-1 to 1)
function Noise:perlin2D(x, y)
	local X = math_floor(x) % PERM_SIZE
	local Y = math_floor(y) % PERM_SIZE

	x = x - math_floor(x)
	y = y - math_floor(y)

	local u = fade(x)
	local v = fade(y)

	local p = self.perm

	local A = p[X] + Y
	local AA = p[A]
	local AB = p[A + 1]
	local B = p[X + 1] + Y
	local BA = p[B]
	local BB = p[B + 1]

	-- Unpack gradients manually for speed
	local g1 = GRAD_2D[(p[AA] % 8) + 1]
	local g2 = GRAD_2D[(p[BA] % 8) + 1]
	local g3 = GRAD_2D[(p[AB] % 8) + 1]
	local g4 = GRAD_2D[(p[BB] % 8) + 1]

	local n00 = dot2(g1, x, y)
	local n10 = dot2(g2, x - 1, y)
	local n01 = dot2(g3, x, y - 1)
	local n11 = dot2(g4, x - 1, y - 1)

	return lerp(lerp(n00, n10, u), lerp(n01, n11, u), v)
end

----------------------------------------------------------------------
-- 3D Perlin Noise
----------------------------------------------------------------------

--- Generate 3D Perlin noise
---@param x number X coordinate
---@param y number Y coordinate
---@param z number Z coordinate
---@return number value Noise value (-1 to 1)
function Noise:perlin3D(x, y, z)
	local X = math_floor(x) % PERM_SIZE
	local Y = math_floor(y) % PERM_SIZE
	local Z = math_floor(z) % PERM_SIZE

	x = x - math_floor(x)
	y = y - math_floor(y)
	z = z - math_floor(z)

	local u = fade(x)
	local v = fade(y)
	local w = fade(z)

	local p = self.perm

	local A = p[X] + Y
	local AA = p[A] + Z
	local AB = p[A + 1] + Z
	local B = p[X + 1] + Y
	local BA = p[B] + Z
	local BB = p[B + 1] + Z

	local g1 = GRAD_3D[(p[AA] % 16) + 1]
	local g2 = GRAD_3D[(p[BA] % 16) + 1]
	local g3 = GRAD_3D[(p[AB] % 16) + 1]
	local g4 = GRAD_3D[(p[BB] % 16) + 1]
	local g5 = GRAD_3D[(p[AA + 1] % 16) + 1]
	local g6 = GRAD_3D[(p[BA + 1] % 16) + 1]
	local g7 = GRAD_3D[(p[AB + 1] % 16) + 1]
	local g8 = GRAD_3D[(p[BB + 1] % 16) + 1]

	local n000 = dot3(g1, x, y, z)
	local n100 = dot3(g2, x - 1, y, z)
	local n010 = dot3(g3, x, y - 1, z)
	local n110 = dot3(g4, x - 1, y - 1, z)
	local n001 = dot3(g5, x, y, z - 1)
	local n101 = dot3(g6, x - 1, y, z - 1)
	local n011 = dot3(g7, x, y - 1, z - 1)
	local n111 = dot3(g8, x - 1, y - 1, z - 1)

	return lerp(lerp(lerp(n000, n100, u), lerp(n010, n110, u), v), lerp(lerp(n001, n101, u), lerp(n011, n111, u), v), w)
end

----------------------------------------------------------------------
-- 2D Simplex Noise (faster than Perlin, fewer artifacts)
----------------------------------------------------------------------

--- Generate 2D Simplex noise (faster than Perlin, fewer artifacts)
---@param x number X coordinate
---@param y number Y coordinate
---@return number value Noise value (-1 to 1)
function Noise:simplex2D(x, y)
	-- Skewing/Unskewing constants
	local F2 = 0.5 * (math_sqrt(3.0) - 1.0)
	local G2 = (3.0 - math_sqrt(3.0)) / 6.0

	local s = (x + y) * F2
	local i = math_floor(x + s)
	local j = math_floor(y + s)
	local t = (i + j) * G2

	local X0 = i - t
	local Y0 = j - t
	local x0 = x - X0
	local y0 = y - Y0

	local i1, j1
	if x0 > y0 then
		i1, j1 = 1, 0
	else
		i1, j1 = 0, 1
	end

	local x1 = x0 - i1 + G2
	local y1 = y0 - j1 + G2
	local x2 = x0 - 1.0 + 2.0 * G2
	local y2 = y0 - 1.0 + 2.0 * G2

	local ii = i % PERM_SIZE
	local jj = j % PERM_SIZE

	local p = self.perm

	local n0, n1, n2

	local t0 = 0.5 - x0 * x0 - y0 * y0
	if t0 < 0 then
		n0 = 0.0
	else
		t0 = t0 * t0
		local gi = p[(p[ii] + jj) % PERM_SIZE] % 8 + 1
		n0 = t0 * t0 * dot2(GRAD_2D[gi], x0, y0)
	end

	local t1 = 0.5 - x1 * x1 - y1 * y1
	if t1 < 0 then
		n1 = 0.0
	else
		t1 = t1 * t1
		local gi = p[(p[(ii + i1) % PERM_SIZE] + (jj + j1) % PERM_SIZE) % PERM_SIZE] % 8 + 1
		n1 = t1 * t1 * dot2(GRAD_2D[gi], x1, y1)
	end

	local t2 = 0.5 - x2 * x2 - y2 * y2
	if t2 < 0 then
		n2 = 0.0
	else
		t2 = t2 * t2
		local gi = p[(p[(ii + 1) % PERM_SIZE] + (jj + 1) % PERM_SIZE) % PERM_SIZE] % 8 + 1
		n2 = t2 * t2 * dot2(GRAD_2D[gi], x2, y2)
	end

	return 70.0 * (n0 + n1 + n2)
end

----------------------------------------------------------------------
-- 3D Simplex Noise
----------------------------------------------------------------------

--- Generate 3D Simplex noise
---@param x number X coordinate
---@param y number Y coordinate
---@param z number Z coordinate
---@return number value Noise value (-1 to 1)
function Noise:simplex3D(x, y, z)
	local F3 = 1.0 / 3.0
	local G3 = 1.0 / 6.0

	local s = (x + y + z) * F3
	local i = math_floor(x + s)
	local j = math_floor(y + s)
	local k = math_floor(z + s)
	local t = (i + j + k) * G3

	local X0 = i - t
	local Y0 = j - t
	local Z0 = k - t
	local x0 = x - X0
	local y0 = y - Y0
	local z0 = z - Z0

	local i1, j1, k1, i2, j2, k2

	if x0 >= y0 then
		if y0 >= z0 then
			i1, j1, k1 = 1, 0, 0
			i2, j2, k2 = 1, 1, 0
		elseif x0 >= z0 then
			i1, j1, k1 = 1, 0, 0
			i2, j2, k2 = 1, 0, 1
		else
			i1, j1, k1 = 0, 0, 1
			i2, j2, k2 = 1, 0, 1
		end
	else
		if y0 < z0 then
			i1, j1, k1 = 0, 0, 1
			i2, j2, k2 = 0, 1, 1
		elseif x0 < z0 then
			i1, j1, k1 = 0, 1, 0
			i2, j2, k2 = 0, 1, 1
		else
			i1, j1, k1 = 0, 1, 0
			i2, j2, k2 = 1, 1, 0
		end
	end

	local x1 = x0 - i1 + G3
	local y1 = y0 - j1 + G3
	local z1 = z0 - k1 + G3
	local x2 = x0 - i2 + 2.0 * G3
	local y2 = y0 - j2 + 2.0 * G3
	local z2 = z0 - k2 + 2.0 * G3
	local x3 = x0 - 1.0 + 3.0 * G3
	local y3 = y0 - 1.0 + 3.0 * G3
	local z3 = z0 - 1.0 + 3.0 * G3

	local ii = i % PERM_SIZE
	local jj = j % PERM_SIZE
	local kk = k % PERM_SIZE

	local p = self.perm
	local n0, n1, n2, n3

	local t0 = 0.6 - x0 * x0 - y0 * y0 - z0 * z0
	if t0 < 0 then
		n0 = 0.0
	else
		t0 = t0 * t0
		local gi = p[(p[(p[ii] + jj) % PERM_SIZE] + kk) % PERM_SIZE] % 16 + 1
		n0 = t0 * t0 * dot3(GRAD_3D[gi], x0, y0, z0)
	end

	local t1 = 0.6 - x1 * x1 - y1 * y1 - z1 * z1
	if t1 < 0 then
		n1 = 0.0
	else
		t1 = t1 * t1
		local gi = p
			[(p[(p[(ii + i1) % PERM_SIZE] + (jj + j1) % PERM_SIZE) % PERM_SIZE] + (kk + k1) % PERM_SIZE) % PERM_SIZE]
			% 16
			+ 1
		n1 = t1 * t1 * dot3(GRAD_3D[gi], x1, y1, z1)
	end

	local t2 = 0.6 - x2 * x2 - y2 * y2 - z2 * z2
	if t2 < 0 then
		n2 = 0.0
	else
		t2 = t2 * t2
		local gi = p
			[(p[(p[(ii + i2) % PERM_SIZE] + (jj + j2) % PERM_SIZE) % PERM_SIZE] + (kk + k2) % PERM_SIZE) % PERM_SIZE]
			% 16
			+ 1
		n2 = t2 * t2 * dot3(GRAD_3D[gi], x2, y2, z2)
	end

	local t3 = 0.6 - x3 * x3 - y3 * y3 - z3 * z3
	if t3 < 0 then
		n3 = 0.0
	else
		t3 = t3 * t3
		local gi = p
			[(p[(p[(ii + 1) % PERM_SIZE] + (jj + 1) % PERM_SIZE) % PERM_SIZE] + (kk + 1) % PERM_SIZE) % PERM_SIZE]
			% 16
			+ 1
		n3 = t3 * t3 * dot3(GRAD_3D[gi], x3, y3, z3)
	end

	return 32.0 * (n0 + n1 + n2 + n3)
end

----------------------------------------------------------------------
-- Value Noise (cheaper, good for distant LOD)
----------------------------------------------------------------------

--- Generate 2D value noise (cheaper, good for distant LOD)
---@param x number X coordinate
---@param y number Y coordinate
---@return number value Noise value (0 to 1)
function Noise:value2D(x, y)
	local ix = math_floor(x)
	local iy = math_floor(y)
	local fx = x - ix
	local fy = y - iy

	local u = fade(fx)
	local v = fade(fy)

	local p = self.perm

	local c00 = p[(p[ix % PERM_SIZE] + iy) % PERM_SIZE] / 255.0
	local c10 = p[(p[(ix + 1) % PERM_SIZE] + iy) % PERM_SIZE] / 255.0
	local c01 = p[(p[ix % PERM_SIZE] + iy + 1) % PERM_SIZE] / 255.0
	local c11 = p[(p[(ix + 1) % PERM_SIZE] + iy + 1) % PERM_SIZE] / 255.0

	return lerp(lerp(c00, c10, u), lerp(c01, c11, u), v)
end

----------------------------------------------------------------------
-- Worley/Cellular Noise (caves, ore veins, biome borders)
----------------------------------------------------------------------

--- Generate 2D Worley/cellular noise (caves, ore veins, biome borders)
---@param x          number       X coordinate
---@param y          number       Y coordinate
---@param returnType string | nil Return type: "value", "distance", "distance2", "distance2sub" (defaults to "distance2")
---@return number value Noise value
function Noise:worley2D(x, y, returnType)
	returnType = returnType or "distance2" -- "value", "distance", "distance2", "distance2sub"

	local ix = math_floor(x)
	local iy = math_floor(y)
	local fx = x - ix
	local fy = y - iy

	local minDist = math_huge
	local minDist2 = math_huge
	local closestCell = { 0, 0 }

	-- Check neighboring cells
	for yOffset = -1, 1 do
		for xOffset = -1, 1 do
			local cellX = ix + xOffset
			local cellY = iy + yOffset

			-- Pseudo-random point in cell
			local hash = self:hash(cellX, cellY)
			local px = (hash % 256) / 256.0
			local py = ((hash * 13) % 256) / 256.0

			local dx = fx - (xOffset + px)
			local dy = fy - (yOffset + py)
			local dist = dx * dx + dy * dy

			if dist < minDist then
				minDist2 = minDist
				minDist = dist
				closestCell = { cellX, cellY }
			elseif dist < minDist2 then
				minDist2 = dist
			end
		end
	end

	if returnType == "value" then
		return (self:hash(closestCell[1], closestCell[2]) % 256) / 256.0
	end
	if returnType == "distance" then
		return math_sqrt(minDist)
	end
	if returnType == "distance2" then
		return math_sqrt(minDist2)
	end
	if returnType == "distance2sub" then
		return math_sqrt(minDist2) - math_sqrt(minDist)
	end

	return math_sqrt(minDist)
end

--- Generate 3D Worley/cellular noise
---@param x          number       X coordinate
---@param y          number       Y coordinate
---@param z          number       Z coordinate
---@param returnType string | nil Return type: "distance", "distance2", "distance2sub" (defaults to "distance2")
---@return number value Noise value
function Noise:worley3D(x, y, z, returnType)
	returnType = returnType or "distance2"

	local ix = math_floor(x)
	local iy = math_floor(y)
	local iz = math_floor(z)
	local fx = x - ix
	local fy = y - iy
	local fz = z - iz

	local minDist = math_huge
	local minDist2 = math_huge

	for zOffset = -1, 1 do
		for yOffset = -1, 1 do
			for xOffset = -1, 1 do
				local cellX = ix + xOffset
				local cellY = iy + yOffset
				local cellZ = iz + zOffset

				local hash = self:hash(cellX, cellY, cellZ)
				local px = (hash % 256) / 256.0
				local py = ((hash * 13) % 256) / 256.0
				local pz = ((hash * 37) % 256) / 256.0

				local dx = fx - (xOffset + px)
				local dy = fy - (yOffset + py)
				local dz = fz - (zOffset + pz)
				local dist = dx * dx + dy * dy + dz * dz

				if dist < minDist then
					minDist2 = minDist
					minDist = dist
				elseif dist < minDist2 then
					minDist2 = dist
				end
			end
		end
	end

	if returnType == "distance" then return math_sqrt(minDist) end
	if returnType == "distance2" then return math_sqrt(minDist2) end
	if returnType == "distance2sub" then return math_sqrt(minDist2) - math_sqrt(minDist) end

	return math_sqrt(minDist)
end

----------------------------------------------------------------------
-- Fractal Brownian Motion (layered detail)
----------------------------------------------------------------------

--- Generate 2D Fractal Brownian Motion (layered detail)
---@param x          number         X coordinate
---@param y          number         Y coordinate
---@param octaves    number | nil   Number of octaves (defaults to 6)
---@param lacunarity number | nil   Frequency multiplier per octave (defaults to 2.0)
---@param gain       number | nil   Amplitude multiplier per octave (defaults to 0.5)
---@param noiseFunc  function | nil Base noise function (defaults to simplex2D)
---@return number value Noise value (-1 to 1)
function Noise:fbm2D(x, y, octaves, lacunarity, gain, noiseFunc)
	octaves = octaves or 6
	lacunarity = lacunarity or 2.0
	gain = gain or 0.5
	noiseFunc = noiseFunc or self.simplex2D

	local total = 0
	local amplitude = 1
	local frequency = 1
	local maxValue = 0

	for i = 1, octaves do
		total = total + noiseFunc(self, x * frequency, y * frequency) * amplitude
		maxValue = maxValue + amplitude
		amplitude = amplitude * gain
		frequency = frequency * lacunarity
	end

	return total / maxValue
end

--- Generate 3D Fractal Brownian Motion (layered detail)
---@param x          number         X coordinate
---@param y          number         Y coordinate
---@param z          number         Z coordinate
---@param octaves    number | nil   Number of octaves (defaults to 6)
---@param lacunarity number | nil   Frequency multiplier per octave (defaults to 2.0)
---@param gain       number | nil   Amplitude multiplier per octave (defaults to 0.5)
---@param noiseFunc  function | nil Base noise function (defaults to simplex3D)
---@return number value Noise value (-1 to 1)
function Noise:fbm3D(x, y, z, octaves, lacunarity, gain, noiseFunc)
	octaves = octaves or 6
	lacunarity = lacunarity or 2.0
	gain = gain or 0.5
	noiseFunc = noiseFunc or self.simplex3D

	local total = 0
	local amplitude = 1
	local frequency = 1
	local maxValue = 0

	for i = 1, octaves do
		total = total + noiseFunc(self, x * frequency, y * frequency, z * frequency) * amplitude
		maxValue = maxValue + amplitude
		amplitude = amplitude * gain
		frequency = frequency * lacunarity
	end

	return total / maxValue
end

----------------------------------------------------------------------
-- Ridged Multifractal (mountains, sharp terrain)
----------------------------------------------------------------------

--- Generate 2D ridged multifractal noise (mountains, sharp terrain)
---@param x          number         X coordinate
---@param y          number         Y coordinate
---@param octaves    number | nil   Number of octaves (defaults to 6)
---@param lacunarity number | nil   Frequency multiplier per octave (defaults to 2.0)
---@param gain       number | nil   Amplitude multiplier per octave (defaults to 0.5)
---@param offset     number | nil   Offset for ridge calculation (defaults to 1.0)
---@param noiseFunc  function | nil Base noise function (defaults to simplex2D)
---@return number value Noise value
function Noise:ridged2D(x, y, octaves, lacunarity, gain, offset, noiseFunc)
	octaves = octaves or 6
	lacunarity = lacunarity or 2.0
	gain = gain or 0.5
	offset = offset or 1.0
	noiseFunc = noiseFunc or self.simplex2D

	local total = 0
	local amplitude = 0.5
	local frequency = 1
	local prev = 1.0

	for i = 1, octaves do
		local n = noiseFunc(self, x * frequency, y * frequency)
		local signal = offset - math_abs(n)
		signal = signal * signal
		signal = signal * prev
		prev = signal

		total = total + signal * amplitude
		amplitude = amplitude * gain
		frequency = frequency * lacunarity
	end

	return total
end

--- Generate 3D ridged multifractal noise (mountains, sharp terrain)
---@param x          number         X coordinate
---@param y          number         Y coordinate
---@param z          number         Z coordinate
---@param octaves    number | nil   Number of octaves (defaults to 6)
---@param lacunarity number | nil   Frequency multiplier per octave (defaults to 2.0)
---@param gain       number | nil   Amplitude multiplier per octave (defaults to 0.5)
---@param offset     number | nil   Offset for ridge calculation (defaults to 1.0)
---@param noiseFunc  function | nil Base noise function (defaults to simplex3D)
---@return number value Noise value
function Noise:ridged3D(x, y, z, octaves, lacunarity, gain, offset, noiseFunc)
	octaves = octaves or 6
	lacunarity = lacunarity or 2.0
	gain = gain or 0.5
	offset = offset or 1.0
	noiseFunc = noiseFunc or self.simplex3D

	local total = 0
	local amplitude = 0.5
	local frequency = 1
	local prev = 1.0

	for i = 1, octaves do
		local n = noiseFunc(self, x * frequency, y * frequency, z * frequency)
		local signal = offset - math_abs(n)
		signal = signal * signal
		signal = signal * prev
		prev = signal

		total = total + signal * amplitude
		amplitude = amplitude * gain
		frequency = frequency * lacunarity
	end

	return total
end

----------------------------------------------------------------------
-- Domain Warping (organic terrain distortion)
----------------------------------------------------------------------

--- Generate 2D domain warped noise (organic terrain distortion)
---@param x            number         X coordinate
---@param y            number         Y coordinate
---@param warpStrength number | nil   Strength of warping effect (defaults to 0.5)
---@param octaves      number | nil   Number of octaves for warping (defaults to 3)
---@param noiseFunc    function | nil Base noise function (defaults to simplex2D)
---@return number value Noise value (-1 to 1)
function Noise:domainWarp2D(x, y, warpStrength, octaves, noiseFunc)
	warpStrength = warpStrength or 0.5
	octaves = octaves or 3
	noiseFunc = noiseFunc or self.simplex2D

	local qx = self:fbm2D(x + 0.0, y + 0.0, octaves, 2.0, 0.5, noiseFunc)
	local qy = self:fbm2D(x + 5.2, y + 1.3, octaves, 2.0, 0.5, noiseFunc)

	local rx = self:fbm2D(x + warpStrength * qx + 1.7, y + warpStrength * qy + 9.2, octaves, 2.0, 0.5, noiseFunc)
	local ry = self:fbm2D(x + warpStrength * qx + 8.3, y + warpStrength * qy + 2.8, octaves, 2.0, 0.5, noiseFunc)

	return noiseFunc(self, x + warpStrength * rx, y + warpStrength * ry)
end

--- Generate 3D domain warped noise (organic terrain distortion)
---@param x            number         X coordinate
---@param y            number         Y coordinate
---@param z            number         Z coordinate
---@param warpStrength number | nil   Strength of warping effect (defaults to 0.5)
---@param octaves      number | nil   Number of octaves for warping (defaults to 3)
---@param noiseFunc    function | nil Base noise function (defaults to simplex3D)
---@return number value Noise value (-1 to 1)
function Noise:domainWarp3D(x, y, z, warpStrength, octaves, noiseFunc)
	warpStrength = warpStrength or 0.5
	octaves = octaves or 3
	noiseFunc = noiseFunc or self.simplex3D

	local qx = self:fbm3D(x + 0.0, y + 0.0, z + 0.0, octaves, 2.0, 0.5, noiseFunc)
	local qy = self:fbm3D(x + 5.2, y + 1.3, z + 4.1, octaves, 2.0, 0.5, noiseFunc)
	local qz = self:fbm3D(x + 3.7, y + 8.3, z + 2.5, octaves, 2.0, 0.5, noiseFunc)

	local rx = self:fbm3D(
		x + warpStrength * qx + 1.7, y + warpStrength * qy + 9.2, z + warpStrength * qz + 3.4, octaves, 2.0, 0.5,
		noiseFunc
	)
	local ry = self:fbm3D(
		x + warpStrength * qx + 8.3, y + warpStrength * qy + 2.8, z + warpStrength * qz + 7.1, octaves, 2.0, 0.5,
		noiseFunc
	)
	local rz = self:fbm3D(
		x + warpStrength * qx + 4.5, y + warpStrength * qy + 6.7, z + warpStrength * qz + 1.2, octaves, 2.0, 0.5,
		noiseFunc
	)

	return noiseFunc(self, x + warpStrength * rx, y + warpStrength * ry, z + warpStrength * rz)
end

----------------------------------------------------------------------
-- Terrain-specific Helpers
----------------------------------------------------------------------

--- Generate erosion-like terrain using fBm + ridged combination
---@param x             number         X coordinate
---@param y             number         Y coordinate
---@param baseOctaves   number | nil   Octaves for base terrain (defaults to 4)
---@param detailOctaves number | nil   Octaves for erosion detail (defaults to 3)
---@param noiseFunc     function | nil Base noise function (defaults to simplex2D)
---@return number value Noise value (-1 to 1)
function Noise:erosion2D(x, y, baseOctaves, detailOctaves, noiseFunc)
	noiseFunc = noiseFunc or self.simplex2D

	local base = self:fbm2D(x, y, baseOctaves or 4, 2.0, 0.5, noiseFunc)
	local detail = self:ridged2D(x, y, detailOctaves or 3, 2.0, 0.5, 1.0, noiseFunc)

	-- Combine: base shapes mountains, detail adds erosion channels
	return base * 0.7 + detail * 0.3
end

--- Generate terrace/stepped terrain for voxel aesthetics
---@param x            number         X coordinate
---@param y            number         Y coordinate
---@param terraceCount number | nil   Number of terraces (defaults to 10)
---@param smoothness   number | nil   Blending between terraces (defaults to 0.15)
---@param noiseFunc    function | nil Base noise function (defaults to simplex2D)
---@return number value Noise value (-1 to 1)
function Noise:terraced2D(x, y, terraceCount, smoothness, noiseFunc)
	terraceCount = terraceCount or 10
	smoothness = smoothness or 0.15
	noiseFunc = noiseFunc or self.simplex2D

	local n = noiseFunc(self, x, y) * 0.5 + 0.5 -- Normalize to 0-1
	local terrace = math_floor(n * terraceCount) / terraceCount
	local blend = math_max(0, math_min(1, (n * terraceCount - math_floor(n * terraceCount)) / smoothness))

	return lerp(terrace, terrace + 1 / terraceCount, blend) * 2 - 1
end

--- Generate seamless tiling noise for chunk borders (if not using continuous coords)
---@param x         number         X coordinate
---@param y         number         Y coordinate
---@param scale     number | nil   Scale of seamless pattern (defaults to 1.0)
---@param noiseFunc function | nil Base noise function (defaults to simplex2D)
---@return number value Noise value (-1 to 1)
function Noise:seamless2D(x, y, scale, noiseFunc)
	noiseFunc = noiseFunc or self.simplex2D
	scale = scale or 1.0

	local s = x / scale
	local t = y / scale

	local nx = math_cos(s * 2 * math_pi) / (2 * math_pi)
	local ny = math_cos(t * 2 * math_pi) / (2 * math_pi)
	local nz = math_sin(s * 2 * math_pi) / (2 * math_pi)
	local nw = math_sin(t * 2 * math_pi) / (2 * math_pi)

	-- Use 4D simplex or approximate with 3D
	return self:simplex3D(nx, ny, nz) -- Approximation; true seamless needs 4D
end

----------------------------------------------------------------------
-- Chunk-based Batch Generation (performance critical)
----------------------------------------------------------------------

--- Generate a 2D chunk of noise values (performance critical)
---@param chunkX     number         Chunk X coordinate
---@param chunkZ     number         Chunk Z coordinate
---@param chunkSize  number         Size of chunk in voxels
---@param voxelScale number         Scale of each voxel in world units
---@param noiseFunc  function | nil Base noise function (defaults to simplex2D)
---@vararg any Additional arguments passed to noise function
---@return number[][] data 2D array of noise values
function Noise:generateChunk2D(chunkX, chunkZ, chunkSize, voxelScale, noiseFunc, ...)
	noiseFunc = noiseFunc or self.simplex2D
	local data = {}
	local baseX = chunkX * chunkSize
	local baseZ = chunkZ * chunkSize

	for z = 0, chunkSize - 1 do
		data[z] = {}
		for x = 0, chunkSize - 1 do
			local wx = (baseX + x) * voxelScale
			local wz = (baseZ + z) * voxelScale
			data[z][x] = noiseFunc(self, wx, wz, ...)
		end
	end

	return data
end

--- Generate a 3D chunk of noise values (performance critical)
---@param chunkX     number         Chunk X coordinate
---@param chunkY     number         Chunk Y coordinate
---@param chunkZ     number         Chunk Z coordinate
---@param chunkSize  number         Size of chunk in voxels
---@param voxelScale number         Scale of each voxel in world units
---@param noiseFunc  function | nil Base noise function (defaults to simplex3D)
---@vararg any Additional arguments passed to noise function
---@return number[][][] data 3D array of noise values
function Noise:generateChunk3D(chunkX, chunkY, chunkZ, chunkSize, voxelScale, noiseFunc, ...)
	noiseFunc = noiseFunc or self.simplex3D
	local data = {}
	local baseX = chunkX * chunkSize
	local baseY = chunkY * chunkSize
	local baseZ = chunkZ * chunkSize

	for z = 0, chunkSize - 1 do
		data[z] = {}
		for y = 0, chunkSize - 1 do
			data[z][y] = {}
			for x = 0, chunkSize - 1 do
				local wx = (baseX + x) * voxelScale
				local wy = (baseY + y) * voxelScale
				local wz = (baseZ + z) * voxelScale
				data[z][y][x] = noiseFunc(self, wx, wy, wz, ...)
			end
		end
	end

	return data
end

----------------------------------------------------------------------
-- Biome Blending Utility
----------------------------------------------------------------------

--- Blend biome values using weighted averaging
---@param x            number         X coordinate
---@param z            number         Z coordinate
---@param biomeMap     fun(x: number, z: number): (number, number) Function(x,z) returning biomeID and weight
---@param blendRadius? number         Radius for biome blending (default: 2)
---@param noiseFunc?   fun(x: number, z: number): number Unused parameter for compatibility
---@return number value Blended biome value
function Noise:blendBiomes(x, z, biomeMap, blendRadius, noiseFunc)
	-- biomeMap: function(x,z) returning biomeID and weight
	-- Returns blended height/noise value
	blendRadius = blendRadius or 2

	local totalWeight = 0
	local totalValue = 0

	for dz = -blendRadius, blendRadius do
		for dx = -blendRadius, blendRadius do
			local dist = math_sqrt(dx * dx + dz * dz)
			if dist <= blendRadius then
				local weight = 1.0 - (dist / blendRadius)
				local biomeID, biomeHeight = biomeMap(x + dx, z + dz)
				totalValue = totalValue + biomeHeight * weight
				totalWeight = totalWeight + weight
			end
		end
	end

	return totalValue / totalWeight
end

-- Export
return Noise
