-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Import all math modules
local AABB = require "aabb"
local Angle = require "angle"
local Camera = require "camera"
local Collision = require "collision"
local Euler = require "euler"
local Matrix4x4 = require "matrix4x4"
local Noise = require "noise"
local OBB = require "obb"
local Plane = require "plane"
local Vector = require "vector"

-- Export
return {
	AABB = AABB,
	Angle = Angle,
	Camera = Camera,
	Collision = Collision,
	Euler = Euler,
	Matrix4x4 = Matrix4x4,
	Noise = Noise,
	OBB = OBB,
	Plane = Plane,
	Vector = Vector,
}
