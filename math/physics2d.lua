-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Minimal 2D physics library

----------------------------------------------------------------------
-- Shape IDs
----------------------------------------------------------------------

---@alias ShapeType
--- | 1 # Circle
--- | 2 # AABB
--- | 3 # OBB

local SHAPE_CIRCLE = 1
local SHAPE_AABB   = 2
local SHAPE_OBB    = 3

----------------------------------------------------------------------
-- Shape types
----------------------------------------------------------------------

---@class CircleShape
---@field type 1
---@field radius number

---@class AABBShape
---@field type 2
---@field width number
---@field height number

---@class OBBShape
---@field type 3
---@field width number
---@field height number
---@field angle number Rotation in radians.
---@field axis_x1 number Local X axis X component.
---@field axis_x2 number Local X axis Y component.
---@field axis_y1 number Local Y axis X component.
---@field axis_y2 number Local Y axis Y component.
---@field vertices number[] Cached world-space vertices:
--- [1]=x1, [2]=y1, [3]=x2, [4]=y2,
--- [5]=x3, [6]=y3, [7]=x4, [8]=y4.

---@alias Shape CircleShape|AABBShape|OBBShape

----------------------------------------------------------------------
-- Physics body
----------------------------------------------------------------------

---@class PhysicsBody
---@field position math.vector World-space position.
---@field velocity math.vector World-space velocity.
---@field acceleration math.vector Accumulated per-step acceleration.
---@field gravity math.vector Constant acceleration.
---@field shape_type ShapeType
---@field shape Shape
---@field dynamic boolean Whether the body is integrated.

----------------------------------------------------------------------
-- Physics API
----------------------------------------------------------------------

---@class Physics
---@field SHAPE_CIRCLE 1
---@field SHAPE_AABB 2
---@field SHAPE_OBB 3
local physics      = {
	SHAPE_CIRCLE = SHAPE_CIRCLE,
	SHAPE_AABB = SHAPE_AABB,
	SHAPE_OBB = SHAPE_OBB,
}

----------------------------------------------------------------------
-- Localized global functions for better performance
----------------------------------------------------------------------

local vector       = require "vector"

local Vector2      = vector.new -- NOTE: This is a 3D vector, but we only use the X and Y components for 2D physics.

local math_abs     = math.abs
local math_cos     = math.cos
local math_max     = math.max
local math_min     = math.min
local math_sin     = math.sin
local math_sqrt    = math.sqrt

----------------------------------------------------------------------
-- Bodies
----------------------------------------------------------------------

--- Create a physics body.
---@param x number Initial X position.
---@param y number Initial Y position.
---@return PhysicsBody
function physics.body(x, y)
	return {
		position = Vector2(x, y),
		velocity = Vector2(),
		acceleration = Vector2(),
		gravity = Vector2(),

		shape_type = SHAPE_CIRCLE,
		shape = physics.circle(0),

		dynamic = true,
	}
end

----------------------------------------------------------------------
-- Forces / acceleration
----------------------------------------------------------------------

--- Accumulate acceleration for the current physics step.
---@param body PhysicsBody
---@param acceleration math.vector
function physics.apply_acceleration(body, acceleration)
	local body_acceleration = body.acceleration

	body_acceleration[1] =
		body_acceleration[1] + acceleration[1]

	body_acceleration[2] =
		body_acceleration[2] + acceleration[2]
end

--- Apply a force-like acceleration.<br>
--- This minimal physics implementation does not model mass, so this is equivalent to `apply_acceleration`.
---@param body PhysicsBody
---@param force math.vector
function physics.apply_force(body, force)
	local acceleration = body.acceleration
	acceleration[1] = acceleration[1] + force[1]
	acceleration[2] = acceleration[2] + force[2]
end

--- Set constant gravity acceleration.
---@param body PhysicsBody
---@param gravity math.vector
function physics.set_gravity(body, gravity)
	body.gravity = gravity
end

----------------------------------------------------------------------
-- Integration
----------------------------------------------------------------------

--- Integrate a body using semi-implicit Euler integration.<br>
--- ```
--- velocity += acceleration * dt
--- position += velocity * dt
--- ```
--- Gravity is included as a constant acceleration.
---@param body PhysicsBody
---@param dt number Delta time in seconds.
function physics.integrate(body, dt)
	if not body.dynamic then
		return
	end

	local position = body.position
	local velocity = body.velocity
	local acceleration = body.acceleration
	local gravity = body.gravity

	local vx = velocity[1]
	local vy = velocity[2]

	vx = vx + (acceleration[1] + gravity[1]) * dt
	vy = vy + (acceleration[2] + gravity[2]) * dt

	position[1] = position[1] + vx * dt
	position[2] = position[2] + vy * dt

	velocity[1] = vx
	velocity[2] = vy

	-- Acceleration is accumulated per step.
	acceleration[1] = 0
	acceleration[2] = 0
end

--- Advance a body by one physics step.
---@param body PhysicsBody
---@param dt number Delta time in seconds.
function physics.step(body, dt)
	physics.integrate(body, dt)
end

----------------------------------------------------------------------
-- Shapes
----------------------------------------------------------------------

--- Create a circle shape.
---@param radius number Circle radius.
---@return CircleShape
function physics.circle(radius)
	return {
		type = SHAPE_CIRCLE,
		radius = radius,
	}
end

--- Create an axis-aligned bounding box (AABB).
---@param width number Box width.
---@param height number Box height.
---@return AABBShape
function physics.aabb(width, height)
	return {
		type = SHAPE_AABB,
		width = width,
		height = height,
	}
end

--- Create an oriented bounding box (OBB).
---@param width number Box width.
---@param height number Box height.
---@param angle? number Rotation in radians.
---@return OBBShape
function physics.obb(width, height, angle)
	return {
		type = SHAPE_OBB,

		width = width,
		height = height,

		angle = angle or 0,

		-- Local X axis.
		axis_x1 = 1,
		axis_x2 = 0,

		-- Local Y axis.
		axis_y1 = 0,
		axis_y2 = 1,

		-- World-space vertices.
		--
		-- [1] x1
		-- [2] y1
		-- [3] x2
		-- [4] y2
		-- [5] x3
		-- [6] y3
		-- [7] x4
		-- [8] y4
		vertices = {
			0, 0,
			0, 0,
			0, 0,
			0, 0,
		},
	}
end

----------------------------------------------------------------------
-- Attach shape
----------------------------------------------------------------------

--- Assign a collision shape to a body.
---@param body PhysicsBody
---@param shape Shape
function physics.set_shape(body, shape)
	body.shape = shape
	body.shape_type = shape.type

	if shape.type == SHAPE_OBB then
		physics.update_shape(body)
	end
end

----------------------------------------------------------------------
-- OBB cache
----------------------------------------------------------------------

--- Update cached OBB transform data.<br>
--- This recalculates:
--- * local axes
--- * world-space vertices
---
--- Call after changing:
--- * body.position
--- * shape.width
--- * shape.height
--- * shape.angle
---@param body PhysicsBody
function physics.update_shape(body)
	if body.shape_type ~= SHAPE_OBB then
		return
	end

	local shape = body.shape ---@cast shape OBBShape

	local angle = shape.angle

	local c = math_cos(angle)
	local s = math_sin(angle)

	-- Local X axis.
	shape.axis_x1 = c
	shape.axis_x2 = s

	-- Local Y axis.
	shape.axis_y1 = -s
	shape.axis_y2 = c

	local half_width = shape.width * 0.5
	local half_height = shape.height * 0.5

	-- Rotated half-extents.
	local x1 = c * half_width
	local y1 = s * half_width

	local x2 = -s * half_height
	local y2 = c * half_height

	local position = body.position
	local px = position[1]
	local py = position[2]

	local vertices = shape.vertices

	-- (-X, -Y)
	vertices[1] = px - x1 - x2
	vertices[2] = py - y1 - y2

	-- (+X, -Y)
	vertices[3] = px + x1 - x2
	vertices[4] = py + y1 - y2

	-- (+X, +Y)
	vertices[5] = px + x1 + x2
	vertices[6] = py + y1 + y2

	-- (-X, +Y)
	vertices[7] = px - x1 + x2
	vertices[8] = py - y1 + y2
end

----------------------------------------------------------------------
-- Projection helpers
----------------------------------------------------------------------

--- Project four points onto an axis.
---@param x1 number
---@param y1 number
---@param x2 number
---@param y2 number
---@param x3 number
---@param y3 number
---@param x4 number
---@param y4 number
---@param axis_x number
---@param axis_y number
---@return number minimum
---@return number maximum
local function project_4(
	x1, y1,
	x2, y2,
	x3, y3,
	x4, y4,
	axis_x,
	axis_y
)
	local projection =
		x1 * axis_x +
		y1 * axis_y

	local minimum = projection
	local maximum = projection

	projection =
		x2 * axis_x +
		y2 * axis_y

	if projection < minimum then
		minimum = projection
	elseif projection > maximum then
		maximum = projection
	end

	projection =
		x3 * axis_x +
		y3 * axis_y

	if projection < minimum then
		minimum = projection
	elseif projection > maximum then
		maximum = projection
	end

	projection =
		x4 * axis_x +
		y4 * axis_y

	if projection < minimum then
		minimum = projection
	elseif projection > maximum then
		maximum = projection
	end

	return minimum, maximum
end

--- Project cached OBB vertices onto an axis.
---@param vertices number[]
---@param axis_x number
---@param axis_y number
---@return number minimum
---@return number maximum
local function project_obb(vertices, axis_x, axis_y)
	local projection =
		vertices[1] * axis_x +
		vertices[2] * axis_y

	local minimum = projection
	local maximum = projection

	projection =
		vertices[3] * axis_x +
		vertices[4] * axis_y

	if projection < minimum then
		minimum = projection
	elseif projection > maximum then
		maximum = projection
	end

	projection =
		vertices[5] * axis_x +
		vertices[6] * axis_y

	if projection < minimum then
		minimum = projection
	elseif projection > maximum then
		maximum = projection
	end

	projection =
		vertices[7] * axis_x +
		vertices[8] * axis_y

	if projection < minimum then
		minimum = projection
	elseif projection > maximum then
		maximum = projection
	end

	return minimum, maximum
end

--- Test whether two scalar intervals overlap.
---@param minimum_a number
---@param maximum_a number
---@param minimum_b number
---@param maximum_b number
---@return boolean
local function intervals_overlap(
	minimum_a,
	maximum_a,
	minimum_b,
	maximum_b
)
	return maximum_a >= minimum_b
		and maximum_b >= minimum_a
end

----------------------------------------------------------------------
-- Circle / Circle
----------------------------------------------------------------------

---@param a PhysicsBody
---@param b PhysicsBody
---@return boolean
local function circle_circle(a, b)
	local pa = a.position
	local pb = b.position

	local dx = pb[1] - pa[1]
	local dy = pb[2] - pa[2]

	local shape_a = a.shape ---@cast shape_a CircleShape
	local shape_b = b.shape ---@cast shape_b CircleShape

	local radius =
		shape_a.radius +
		shape_b.radius

	return dx * dx + dy * dy <= radius * radius
end

----------------------------------------------------------------------
-- AABB / AABB
----------------------------------------------------------------------

---@param a PhysicsBody
---@param b PhysicsBody
---@return boolean
local function aabb_aabb(a, b)
	local pa = a.position
	local pb = b.position

	local shape_a = a.shape ---@cast shape_a AABBShape
	local shape_b = b.shape ---@cast shape_b AABBShape

	local half_width_a = shape_a.width * 0.5
	local half_height_a = shape_a.height * 0.5

	local half_width_b = shape_b.width * 0.5
	local half_height_b = shape_b.height * 0.5

	local dx = math_abs(pa[1] - pb[1])
	local dy = math_abs(pa[2] - pb[2])

	return dx <= half_width_a + half_width_b
		and dy <= half_height_a + half_height_b
end

----------------------------------------------------------------------
-- Circle / AABB
----------------------------------------------------------------------

---@param circle PhysicsBody
---@param box PhysicsBody
---@return boolean
local function circle_aabb(circle, box)
	local pc = circle.position
	local pb = box.position

	local shape_circle = circle.shape ---@cast shape_circle CircleShape
	local shape_box = box.shape ---@cast shape_box AABBShape

	local half_width = shape_box.width * 0.5
	local half_height = shape_box.height * 0.5

	local closest_x = math_max(
		pb[1] - half_width,
		math_min(pc[1], pb[1] + half_width)
	)

	local closest_y = math_max(
		pb[2] - half_height,
		math_min(pc[2], pb[2] + half_height)
	)

	local dx = pc[1] - closest_x
	local dy = pc[2] - closest_y

	local radius = shape_circle.radius

	return dx * dx + dy * dy <= radius * radius
end

----------------------------------------------------------------------
-- Circle / OBB
----------------------------------------------------------------------

---@param circle PhysicsBody
---@param box PhysicsBody
---@return boolean
local function circle_obb(circle, box)
	local pc = circle.position
	local pb = box.position

	local shape = box.shape ---@cast shape OBBShape

	local dx = pc[1] - pb[1]
	local dy = pc[2] - pb[2]

	-- Transform circle center into OBB local coordinates.
	local local_x =
		dx * shape.axis_x1 +
		dy * shape.axis_x2

	local local_y =
		dx * shape.axis_y1 +
		dy * shape.axis_y2

	local half_width = shape.width * 0.5
	local half_height = shape.height * 0.5

	local closest_x =
		math_max(-half_width, math_min(local_x, half_width))

	local closest_y =
		math_max(-half_height, math_min(local_y, half_height))

	local difference_x = local_x - closest_x
	local difference_y = local_y - closest_y

	local radius = circle.shape.radius

	return difference_x * difference_x
		+ difference_y * difference_y
		<= radius * radius
end

----------------------------------------------------------------------
-- OBB / OBB
----------------------------------------------------------------------

--- Test two OBBs using the Separating Axis Theorem (SAT).<br>
--- There are four candidate separating axes:
--- * A local X
--- * A local Y
--- * B local X
--- * B local Y
---@param a PhysicsBody
---@param b PhysicsBody
---@return boolean
local function obb_obb(a, b)
	local shape_a = a.shape ---@cast shape_a OBBShape
	local shape_b = b.shape ---@cast shape_b OBBShape

	local vertices_a = shape_a.vertices
	local vertices_b = shape_b.vertices

	local minimum_a
	local maximum_a
	local minimum_b
	local maximum_b

	-- A local X.
	minimum_a, maximum_a =
		project_obb(
			vertices_a,
			shape_a.axis_x1,
			shape_a.axis_x2
		)

	minimum_b, maximum_b =
		project_obb(
			vertices_b,
			shape_a.axis_x1,
			shape_a.axis_x2
		)

	if not intervals_overlap(
			minimum_a,
			maximum_a,
			minimum_b,
			maximum_b
		) then
		return false
	end

	-- A local Y.
	minimum_a, maximum_a =
		project_obb(
			vertices_a,
			shape_a.axis_y1,
			shape_a.axis_y2
		)

	minimum_b, maximum_b =
		project_obb(
			vertices_b,
			shape_a.axis_y1,
			shape_a.axis_y2
		)

	if not intervals_overlap(
			minimum_a,
			maximum_a,
			minimum_b,
			maximum_b
		) then
		return false
	end

	-- B local X.
	minimum_a, maximum_a =
		project_obb(
			vertices_a,
			shape_b.axis_x1,
			shape_b.axis_x2
		)

	minimum_b, maximum_b =
		project_obb(
			vertices_b,
			shape_b.axis_x1,
			shape_b.axis_x2
		)

	if not intervals_overlap(
			minimum_a,
			maximum_a,
			minimum_b,
			maximum_b
		) then
		return false
	end

	-- B local Y.
	minimum_a, maximum_a =
		project_obb(
			vertices_a,
			shape_b.axis_y1,
			shape_b.axis_y2
		)

	minimum_b, maximum_b =
		project_obb(
			vertices_b,
			shape_b.axis_y1,
			shape_b.axis_y2
		)

	if not intervals_overlap(
			minimum_a,
			maximum_a,
			minimum_b,
			maximum_b
		) then
		return false
	end

	return true
end

----------------------------------------------------------------------
-- AABB / OBB
----------------------------------------------------------------------

--- Test an AABB against an OBB using Separating Axis Theorem (SAT).
---@param aabb PhysicsBody
---@param obb PhysicsBody
---@return boolean
local function aabb_obb(aabb, obb)
	local position = aabb.position

	local shape_aabb = aabb.shape ---@cast shape_aabb AABBShape
	local shape_obb = obb.shape ---@cast shape_obb OBBShape

	local half_width = shape_aabb.width * 0.5
	local half_height = shape_aabb.height * 0.5

	local x1 = position[1] - half_width
	local y1 = position[2] - half_height

	local x2 = position[1] + half_width
	local y2 = position[2] - half_height

	local x3 = position[1] + half_width
	local y3 = position[2] + half_height

	local x4 = position[1] - half_width
	local y4 = position[2] + half_height

	local vertices_b = shape_obb.vertices

	local minimum_a
	local maximum_a
	local minimum_b
	local maximum_b

	-- AABB X.
	minimum_a = x1
	maximum_a = x2

	minimum_b, maximum_b =
		project_obb(vertices_b, 1, 0)

	if not intervals_overlap(
			minimum_a,
			maximum_a,
			minimum_b,
			maximum_b
		) then
		return false
	end

	-- AABB Y.
	minimum_a = y1
	maximum_a = y3

	minimum_b, maximum_b =
		project_obb(vertices_b, 0, 1)

	if not intervals_overlap(
			minimum_a,
			maximum_a,
			minimum_b,
			maximum_b
		) then
		return false
	end

	-- OBB X.
	minimum_a, maximum_a =
		project_4(
			x1, y1,
			x2, y2,
			x3, y3,
			x4, y4,
			shape_obb.axis_x1,
			shape_obb.axis_x2
		)

	minimum_b, maximum_b =
		project_obb(
			vertices_b,
			shape_obb.axis_x1,
			shape_obb.axis_x2
		)

	if not intervals_overlap(
			minimum_a,
			maximum_a,
			minimum_b,
			maximum_b
		) then
		return false
	end

	-- OBB Y.
	minimum_a, maximum_a =
		project_4(
			x1, y1,
			x2, y2,
			x3, y3,
			x4, y4,
			shape_obb.axis_y1,
			shape_obb.axis_y2
		)

	minimum_b, maximum_b =
		project_obb(
			vertices_b,
			shape_obb.axis_y1,
			shape_obb.axis_y2
		)

	if not intervals_overlap(
			minimum_a,
			maximum_a,
			minimum_b,
			maximum_b
		) then
		return false
	end

	return true
end

----------------------------------------------------------------------
-- Collision dispatch
----------------------------------------------------------------------

--- Test whether two bodies overlap.<br>
--- Collision dispatch uses numeric shape IDs rather than strings.
---@param a PhysicsBody
---@param b PhysicsBody
---@return boolean
function physics.overlaps(a, b)
	local type_a = a.shape_type
	local type_b = b.shape_type

	if type_a == SHAPE_CIRCLE then
		if type_b == SHAPE_CIRCLE then
			return circle_circle(a, b)
		elseif type_b == SHAPE_AABB then
			return circle_aabb(a, b)
		elseif type_b == SHAPE_OBB then
			return circle_obb(a, b)
		end
	elseif type_a == SHAPE_AABB then
		if type_b == SHAPE_CIRCLE then
			return circle_aabb(b, a)
		elseif type_b == SHAPE_AABB then
			return aabb_aabb(a, b)
		elseif type_b == SHAPE_OBB then
			return aabb_obb(a, b)
		end
	elseif type_a == SHAPE_OBB then
		if type_b == SHAPE_CIRCLE then
			return circle_obb(b, a)
		elseif type_b == SHAPE_AABB then
			return aabb_obb(b, a)
		elseif type_b == SHAPE_OBB then
			return obb_obb(a, b)
		end
	end

	return false
end

physics.check_collision = physics.overlaps -- alias

----------------------------------------------------------------------
-- Ray casting functions
----------------------------------------------------------------------

---@class math.ray
---@field origin math.vector
---@field direction math.vector
---@field max_distance number

--- Ray vs AABB helper function (returns tmin and hit point in local space).
---@param ray math.ray
---@param aabb { min: math.vector, max: math.vector }
---@return number? tmin
---@return math.vector? hit_point
local function ray_vs_aabb_raw(ray, aabb)
	local ox, oy = ray.origin[1], ray.origin[2]
	local dx, dy = ray.direction[1], ray.direction[2]

	local min_x = aabb.min[1] or 0
	local min_y = aabb.min[2] or 0
	local max_x = aabb.max[1] or 0
	local max_y = aabb.max[2] or 0

	local tmin = 0
	local tmax = ray.max_distance

	-- X axis slab test
	if math_abs(dx) < 1e-9 then
		if ox < min_x or ox > max_x then
			return nil
		end
	else
		local inv_d = 1.0 / dx
		local t1 = (min_x - ox) * inv_d
		local t2 = (max_x - ox) * inv_d
		if t1 > t2 then t1, t2 = t2, t1 end
		tmin = math_max(tmin, t1)
		tmax = math_min(tmax, t2)
		if tmin > tmax then return nil end
	end

	-- Y axis slab test
	if math_abs(dy) < 1e-9 then
		if oy < min_y or oy > max_y then
			return nil
		end
	else
		local inv_d = 1.0 / dy
		local t1 = (min_y - oy) * inv_d
		local t2 = (max_y - oy) * inv_d
		if t1 > t2 then t1, t2 = t2, t1 end
		tmin = math_max(tmin, t1)
		tmax = math_min(tmax, t2)
		if tmin > tmax then return nil end
	end

	return tmin, Vector2(ox + dx * tmin, oy + dy * tmin)
end

--- Create a new 2D ray.
---@param origin math.vector 2D point
---@param direction math.vector 2D direction
---@param max_distance number? Maximum trace distance (default: `math.huge`)
---@return math.ray
function physics.ray(origin, direction, max_distance)
	local ox = origin[1] or 0
	local oy = origin[2] or 0
	local dx = direction[1] or 0
	local dy = direction[2] or 0
	local len = math_sqrt(dx * dx + dy * dy)

	if len > 0 then
		dx = dx / len
		dy = dy / len
	end

	return {
		origin = Vector2(ox, oy),
		direction = Vector2(dx, dy),
		max_distance = max_distance or math.huge,
	}
end

--- Test a ray against a circle body.
---@param ray math.ray
---@param body PhysicsBody
---@return number? distance
---@return math.vector? hit_point
function physics.ray_vs_circle(ray, body)
	if type(ray) ~= "table" or type(body) ~= "table" then
		return error("physics.ray_vs_circle requires a ray and a PhysicsBody", 2)
	end

	local ox, oy = ray.origin[1], ray.origin[2]
	local dx, dy = ray.direction[1], ray.direction[2]
	local pos = body.position
	local cx, cy = pos[1], pos[2]
	local circle = body.shape ---@cast circle CircleShape
	local r = circle.radius or 0

	local vx = cx - ox
	local vy = cy - oy

	local tp = vx * dx + vy * dy
	local v_sq = vx * vx + vy * vy
	local r_sq = r * r
	local d_sq = v_sq - (tp * tp)

	if d_sq > r_sq then
		return nil
	end

	local tc = math_sqrt(r_sq - d_sq)
	local t1 = tp - tc
	local t2 = tp + tc

	local t
	if t1 >= 0 and t1 <= ray.max_distance then
		t = t1
	elseif t2 >= 0 and t2 <= ray.max_distance then
		t = t2
	end

	if not t then
		return nil
	end

	return t, Vector2(ox + dx * t, oy + dy * t)
end

--- Test a ray against an AABB body.
---@param ray math.ray
---@param body PhysicsBody
---@return number? distance
---@return math.vector? hit_point
function physics.ray_vs_aabb(ray, body)
	if type(ray) ~= "table" or type(body) ~= "table" then
		return error("physics.ray_vs_aabb requires a ray and a PhysicsBody", 2)
	end

	local ox, oy = ray.origin[1], ray.origin[2]
	local dx, dy = ray.direction[1], ray.direction[2]

	local pos = body.position
	local shape = body.shape ---@cast shape AABBShape
	local half_w = shape.width * 0.5
	local half_h = shape.height * 0.5
	local min_x = pos[1] - half_w
	local max_x = pos[1] + half_w
	local min_y = pos[2] - half_h
	local max_y = pos[2] + half_h

	local tmin = 0
	local tmax = ray.max_distance

	-- X axis slab test
	if math_abs(dx) < 1e-9 then
		if ox < min_x or ox > max_x then
			return nil
		end
	else
		local inv_d = 1.0 / dx
		local t1 = (min_x - ox) * inv_d
		local t2 = (max_x - ox) * inv_d
		if t1 > t2 then t1, t2 = t2, t1 end
		tmin = math_max(tmin, t1)
		tmax = math_min(tmax, t2)
		if tmin > tmax then return nil end
	end

	-- Y axis slab test
	if math_abs(dy) < 1e-9 then
		if oy < min_y or oy > max_y then
			return nil
		end
	else
		local inv_d = 1.0 / dy
		local t1 = (min_y - oy) * inv_d
		local t2 = (max_y - oy) * inv_d
		if t1 > t2 then t1, t2 = t2, t1 end
		tmin = math_max(tmin, t1)
		tmax = math_min(tmax, t2)
		if tmin > tmax then return nil end
	end

	return tmin, Vector2(ox + dx * tmin, oy + dy * tmin)
end

--- Test a ray against a line segment.
---@param ray math.ray
---@param p1 math.vector Segment start point.
---@param p2 math.vector Segment end point.
---@return number? distance
---@return math.vector? hit_point
function physics.ray_vs_segment(ray, p1, p2)
	if type(ray) ~= "table" or type(p1) ~= "table" or type(p2) ~= "table" then
		return error("physics.ray_vs_segment requires a ray and two segment endpoints", 2)
	end

	local ox, oy = ray.origin[1], ray.origin[2]
	local dx, dy = ray.direction[1], ray.direction[2]

	local x1, y1 = p1[1] or 0, p1[2] or 0
	local x2, y2 = p2[1] or 0, p2[2] or 0

	local sx = x2 - x1
	local sy = y2 - y1

	local det = dx * sy - dy * sx
	if math_abs(det) < 1e-9 then
		return nil -- parallel ray and segment
	end

	local qx = x1 - ox
	local qy = y1 - oy

	local t = (qx * sy - qy * sx) / det
	local s = (qx * dy - qy * dx) / det

	if t >= 0 and t <= ray.max_distance and s >= 0 and s <= 1 then
		return t, Vector2(ox + dx * t, oy + dy * t)
	end

	return nil
end

--- Test a ray against an OBB body.
---@param ray math.ray
---@param body PhysicsBody
---@return number? distance
---@return math.vector? hit_point
function physics.ray_vs_obb(ray, body)
	if type(ray) ~= "table" or type(body) ~= "table" then
		return error("physics.ray_vs_obb requires a ray and a PhysicsBody", 2)
	end

	local pos = body.position
	local cx, cy = pos[1], pos[2]
	local shape = body.shape
	local half_w = shape.width * 0.5
	local half_h = shape.height * 0.5
	local angle = shape.angle or 0

	local cos_a = math_cos(-angle)
	local sin_a = math_sin(-angle)

	-- Transform ray into OBB local coordinate space
	local rel_x = ray.origin[1] - cx
	local rel_y = ray.origin[2] - cy

	local local_ox = rel_x * cos_a - rel_y * sin_a
	local local_oy = rel_x * sin_a + rel_y * cos_a

	local local_dx = ray.direction[1] * cos_a - ray.direction[2] * sin_a
	local local_dy = ray.direction[1] * sin_a + ray.direction[2] * cos_a

	local local_ray = {
		origin = { local_ox, local_oy },
		direction = { local_dx, local_dy },
		max_distance = ray.max_distance,
	}

	local local_aabb = {
		min = { -half_w, -half_h },
		max = { half_w, half_h },
	}

	local t, local_hit = ray_vs_aabb_raw(local_ray, local_aabb)
	if not local_hit then
		return nil
	end

	-- Transform hit point back to world space
	local world_cos = math_cos(angle)
	local world_sin = math_sin(angle)
	local world_hit_x = cx + (local_hit[1] * world_cos - local_hit[2] * world_sin)
	local world_hit_y = cy + (local_hit[1] * world_sin + local_hit[2] * world_cos)

	return t, Vector2(world_hit_x, world_hit_y)
end

--- Find the closest point on a line segment to a given point.
---@param point math.vector Target point.
---@param p1 math.vector Segment start point.
---@param p2 math.vector Segment end point.
---@return math.vector closest_point Closest point on segment.
function physics.closest_point_on_segment(point, p1, p2)
	local px = point[1] or 0
	local py = point[2] or 0
	local x1 = p1[1] or 0
	local y1 = p1[2] or 0
	local x2 = p2[1] or 0
	local y2 = p2[2] or 0

	local dx = x2 - x1
	local dy = y2 - y1
	local len_sq = dx * dx + dy * dy

	if len_sq < 1e-9 then
		return Vector2(x1, y1)
	end

	local t = ((px - x1) * dx + (py - y1) * dy) / len_sq
	t = math_max(0, math_min(1, t))

	return Vector2(x1 + t * dx, y1 + t * dy)
end

-- Export
return physics
