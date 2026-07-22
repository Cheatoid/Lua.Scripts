-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Entity Component System built with the LuaMeta framework.
-- Provides Entity, Component, System, and World primitives plus animation/tweening subsystems.
--
-- local ecs = require "meta/ecs"
-- local world = ecs.World()
-- world:addSystem(MySystem())
-- world:update(timer.frametime())

local luameta = require "init"
local class = luameta.class
local trait = luameta.trait

-- Disable global registration for this module
luameta.pushGlobal(false)

local ecs = {}

--- Abstract base for all component types. Subclass this to define
--- data containers attached to entities. Components are plain classes
--- that hold state (position, velocity, color, etc.) with no behavior.
---@class ecs.Component
local Component = class "Component"
	:abstract()

--- A container for components. Entities are created via `ecs.Entity()` and
--- added to a World. Components are identified by their class table.
---@class ecs.Entity
local Entity = class "Entity"
	:constructor(function(self)
		self._components = {}
	end)
	:method {
		--- Add a component instance to this entity.
		--- The component class is used as the key, so only one instance per class is allowed.
		--- If `self.onComponentAdded` is defined (as a method or callback), it is called.
		---@param componentClass table Component class (created via `class "Name"`).
		---@param ... any Constructor arguments forwarded to `componentClass(...)`.
		---@return table instance The newly created component instance.
		addComponent = function(self, componentClass, ...)
			if self._components[componentClass] then
				error("Component of type " .. tostring(componentClass.name) .. " already exists on entity")
			end
			local instance = componentClass(...)
			self._components[componentClass] = instance
			if self.onComponentAdded then
				self:onComponentAdded(componentClass, instance)
			end
			return instance
		end,
		--- Remove a component by its class.<br>
		--- If `self.onComponentRemoved` is defined, it is called.
		---@param componentClass table Component class to remove.
		---@return table|nil removed The removed instance, or nil if not found.
		removeComponent = function(self, componentClass)
			local removed = self._components[componentClass]
			if removed then
				self._components[componentClass] = nil
				if self.onComponentRemoved then
					self:onComponentRemoved(componentClass, removed)
				end
			end
			return removed
		end,

		--- Retrieve a component by its class.
		---@param componentClass table Component class to look up.
		---@return table|nil instance The component instance, or nil.
		getComponent = function(self, componentClass)
			return self._components[componentClass]
		end,

		--- Check if the entity has a component of the exact class.
		---@param componentClass table Component class to check.
		---@return boolean has True if the component exists.
		hasComponent = function(self, componentClass)
			return self._components[componentClass] ~= nil
		end,

		--- Get all components as a table of `class -> instance`.
		---@return table components
		getComponents = function(self)
			return self._components
		end,

		--- Get all components that are instances of, or inherit from, a given class.
		---@param componentClass table Class to match via `isA`.
		---@return table list Array of matching component instances.
		getComponentsOfType = function(self, componentClass)
			local result = {}
			for _, instance in next, self._components do
				if instance:isA(componentClass) then
					result[#result + 1] = instance
				end
			end
			return result
		end,

		--- Check if any component matches a type (via `isA`).
		---@param componentClass table Class to match.
		---@return boolean has True if at least one component matches.
		hasComponentType = function(self, componentClass)
			for _, instance in next, self._components do
				if instance:isA(componentClass) then
					return true
				end
			end
			return false
		end,
	}

--- Abstract base for all systems. Subclass via `class():extends(System)` and set
--- `requiredComponents` on the class to declare which components an entity must
--- have for `process` to be called.
---
--- Lifecycle (per world:update):
---   1. `beginUpdate(dt)` on all systems
---   2. `process(entity, dt)` for each entity matching `requiredComponents`
---   3. `endUpdate(dt)` on all systems
---@class ecs.System
---@field [parent] table Parent class table (when using `:extends(System)`).
---@usage <br>
--- ```
--- local MySystem = class("MySystem"):extends(System)
---     :static { requiredComponents = { Position, Velocity } }
---     :method {
---         process = function(self, entity, dt)
---             -- logic here
---         end,
---     }
--- ```
local System = class "System"
	:abstract { "process" }
	:static {
		---@type table Array of component classes. Only entities that have ALL of
		--- these components will be passed to `process`. Default `{}`.
		requiredComponents = {},
	}
	:method {
		--- Called once per entity matching `requiredComponents`.<br>
		--- Must be overridden by subclasses.
		---@param entity ecs.Entity
		---@param dt number Delta time since last update
		process = nil,
		--- Called once per world:update before any process calls.
		---@param dt number Delta time
		beginUpdate = function(self, dt) end,
		--- Called once per world:update after all process calls.
		---@param dt number Delta time
		endUpdate = function(self, dt) end,
		--- Called when the system is added to a world.
		---@param world ecs.World
		onAddToWorld = function(self, world) end,
		--- Called when the system is removed from a world.
		---@param world ecs.World
		onRemoveFromWorld = function(self, world) end,
	}

--- Manages a collection of entities and systems. Call `update(dt)` each frame
--- to run the simulation loop that drives all systems.
---@class ecs.World
local World = class "World"
	:constructor(function(self)
		self._entities = {}
		self._systems = {}
		self._entitySet = {}
		self._pendingAdd = {}
		self._pendingRemove = {}
	end)
	:method {
		--- Add an entity to the world. Idempotent (ignores if already present).
		---@param entity ecs.Entity
		addEntity = function(self, entity)
			if self._entitySet[entity] then return end
			self._entities[#self._entities + 1] = entity
			self._entitySet[entity] = true
		end,

		--- Remove an entity from the world by identity. Uses swap-and-pop.
		---@param entity ecs.Entity
		removeEntity = function(self, entity)
			if not self._entitySet[entity] then return end
			self._entitySet[entity] = nil
			local entities = self._entities
			for i = 1, #entities do
				if entities[i] == entity then
					entities[i] = entities[#entities]
					entities[#entities] = nil
					break
				end
			end
		end,

		--- Add a system. Calls `system.onAddToWorld(self)` if defined.
		---@param system ecs.System
		addSystem = function(self, system)
			self._systems[#self._systems + 1] = system
			if system.onAddToWorld then system:onAddToWorld(self) end
		end,

		--- Remove a system by identity. Calls `system.onRemoveFromWorld(self)`.
		---@param system ecs.System
		removeSystem = function(self, system)
			local systems = self._systems
			for i = 1, #systems do
				if systems[i] == system then
					if system.onRemoveFromWorld then system:onRemoveFromWorld(self) end
					systems[i] = systems[#systems]
					systems[#systems] = nil
					break
				end
			end
		end,

		--- Retrieve all entities that have ALL of the given component classes (exact match).
		---@param componentList table Array of component classes.
		---@return table entities Array of matching Entity instances.
		getEntitiesWithComponents = function(self, componentList)
			local result = {}
			local entities = self._entities
			for i = 1, #entities do
				local entity = entities[i]
				local comps = entity._components
				local hasAll = true
				for j = 1, #componentList do
					if not comps[componentList[j]] then
						hasAll = false
						break
					end
				end
				if hasAll then
					result[#result + 1] = entity
				end
			end
			return result
		end,

		--- Retrieve all entities whose component set includes at least one
		--- instance matching the given class (via `isA`, including inheritance).
		---@param componentClass table Class to test via `isA`.
		---@return table entities Array of matching Entity instances.
		getEntitiesWithComponentType = function(self, componentClass)
			local result = {}
			local entities = self._entities
			for i = 1, #entities do
				if entities[i]:hasComponentType(componentClass) then
					result[#result + 1] = entities[i]
				end
			end
			return result
		end,

		--- Run a single update tick. Steps:
		---   1. Flush pending entity removals
		---   2. `beginUpdate(dt)` on all systems
		---   3. For each system, iterate entities in reverse - those matching
		---      `requiredComponents` receive `process(entity, dt)`
		---   4. `endUpdate(dt)` on all systems
		---@param dt number Delta time in seconds since last update.
		update = function(self, dt)
			local pendingRemove = self._pendingRemove
			for i = 1, #pendingRemove do
				self:removeEntity(pendingRemove[i])
			end
			self._pendingRemove = {}

			local systems = self._systems
			for i = 1, #systems do
				systems[i]:beginUpdate(dt)
			end

			local entities = self._entities
			for i = 1, #systems do
				local system = systems[i]
				local required = system.class.requiredComponents
				if #required > 0 then
					for j = #entities, 1, -1 do
						local entity = entities[j]
						local comps = entity._components
						local hasAll = true
						for k = 1, #required do
							if not comps[required[k]] then
								hasAll = false
								break
							end
						end
						if hasAll then
							system:process(entity, dt)
						end
					end
				end
			end

			for i = 1, #systems do
				systems[i]:endUpdate(dt)
			end
		end,

		--- Get the number of entities currently in the world.
		---@return number count
		entityCount = function(self)
			return #self._entities
		end,

		--- Get all entities as an array.
		---@return table entities Array of Entity.
		getEntities = function(self)
			return self._entities
		end,

		--- Remove all entities and systems from the world.
		clear = function(self)
			self._entities = {}
			self._entitySet = {}
			self._systems = {}
		end,
	}

--- Create an entity with one or more component classes in a single call.<br>
--- Arguments are interleaved: `ecs.newEntity(CompA, arg1, arg2, CompB, arg3)`.<br>
--- Each component class is detected via its `.origin.class` descriptor; the
--- following arguments up to the next class become that component's constructor args.
---@param ... table|any Alternating component classes and their constructor arguments.
---@return ecs.Entity entity The newly created entity.
function ecs.newEntity(...)
	local entity = Entity()
	local args = { ... }
	local i = 1
	while i <= #args do
		local item = args[i]
		if type(item) == "table" and item.origin and item.origin.class == item then
			local compClass = item
			local ctorArgs = {}
			i = i + 1
			while i <= #args and not (type(args[i]) == "table" and args[i].origin and args[i].origin.class == args[i]) do
				ctorArgs[#ctorArgs + 1] = args[i]
				i = i + 1
			end
			entity:addComponent(compClass, table.unpack(ctorArgs))
		else
			i = i + 1
		end
	end
	return entity
end

--- Trait for entities that can be rendered. Provides a `render(dt)` method.
---@class ecs.Renderable
trait "Renderable"
	:method {
		--- Called each frame to render the entity.
		---@param dt number Delta time
		render = function(self, dt)
			error("Renderable:render not implemented")
		end
	}

	--- Trait for entities with per-frame update logic. Provides an `update(dt)` method.
---@class ecs.Updatable
trait "Updatable"
	:method {
		--- Called each frame to update the entity.
		---@param dt number Delta time
		update = function(self, dt)
			error("Updatable:update not implemented")
		end
	}

--- 3D position component. Constructor accepts `(x, y, z)` or a vector-like table `{x, y, z}`.
---@class ecs.Position
---@field x number X coordinate (default: 0)
---@field y number Y coordinate (default: 0)
---@field z number Z coordinate (default: 0)
local Position = class "Position"
	:constructor(function(self, x, y, z)
		if type(x) == "table" and x.x then
			self.x, self.y, self.z = x.x, x.y, x.z
		else
			self.x = x or 0
			self.y = y or 0
			self.z = z or 0
		end
	end)

--- 3D velocity component. Constructor accepts `(x, y, z)` or a vector-like table.
---@class ecs.Velocity
---@field x number X velocity component (default: 0)
---@field y number Y velocity component (default: 0)
---@field z number Z velocity component (default: 0)
local Velocity = class "Velocity"
	:constructor(function(self, x, y, z)
		if type(x) == "table" and x.x then
			self.x, self.y, self.z = x.x, x.y, x.z
		else
			self.x = x or 0
			self.y = y or 0
			self.z = z or 0
		end
	end)

--- 3D angle component (pitch, yaw, roll). Constructor accepts `(p, y, r)` or an angle-like table `{p, y, r}`.
---@class ecs.Angle
---@field p number Pitch (default: 0)
---@field y number Yaw (default: 0)
---@field r number Roll (default: 0)
local Angle = class "Angle"
	:constructor(function(self, p, y, r)
		if type(p) == "table" and p.p then
			self.p, self.y, self.r = p.p, p.y, p.r
		else
			self.p = p or 0
			self.y = y or 0
			self.r = r or 0
		end
	end)

--- RGBA color component. Constructor accepts `(r, g, b, a)` or a color-like table `{r, g, b, a}`.
---@class ecs.Color
---@field r number Red channel (0-255, default: 255)
---@field g number Green channel (0-255, default: 255)
---@field b number Blue channel (0-255, default: 255)
---@field a number Alpha channel (0-255, default: 255)
local Color = class "Color"
	:constructor(function(self, r, g, b, a)
		if type(r) == "table" and r.r then
			self.r, self.g, self.b, self.a = r.r, r.g, r.b, r.a or 255
		else
			self.r = r or 255
			self.g = g or 255
			self.b = b or 255
			self.a = a or 255
		end
	end)

--- Easing functions table. Maps easing names to `function(t)` where `t` is
--- in [0, 1]. Supported keys:
---   `linear`, `easeInQuad`, `easeOutQuad`, `easeInOutQuad`,
---   `easeInCubic`, `easeOutCubic`, `easeInOutCubic`,
---   `easeInElastic`, `easeOutElastic`
local easings = {
	linear = function(t) return t end,
	easeInQuad = function(t) return t * t end,
	easeOutQuad = function(t) return t * (2 - t) end,
	easeInOutQuad = function(t) return t < 0.5 and 2 * t * t or -1 + (4 - 2 * t) * t end,
	easeInCubic = function(t) return t * t * t end,
	easeOutCubic = function(t) return (t - 1) ^ 3 + 1 end,
	easeInOutCubic = function(t) return t < 0.5 and 4 * t * t * t or (t - 1) * (2 * t - 2) * (2 * t - 2) + 1 end,
	easeInElastic = function(t) return (0.04 - 0.04 / t) * math.sin(25 * t) + 1 end,
	easeOutElastic = function(t) return 2 ^ (-10 * t) * math.sin((t - 0.075) * (2 * math.pi) / 0.3) + 1 end,
}

--- Apply an easing function by name.
---@param t number Progress in [0, 1].
---@param easing string Easing name from the `easings` table. Falls back to `"linear"` if unknown.
---@return number eased The eased value in [0, 1].
local function applyEasing(t, easing)
	return (easings[easing] or easings.linear)(t)
end

--- Interpolate between two values.<br>
--- Supports numbers, vector-like tables `{x, y, z}`, and generic numeric tables.<br>
--- Non-numeric fields fall back to source value. Non-numeric/non-table values snap
--- at the midpoint (t < 0.5 -> a, else -> b).
---@param a number|table Source value.
---@param b number|table Target value.
---@param t number Interpolation factor in [0, 1].
---@return number|table interpolated
local function lerpValue(a, b, t)
	if type(a) == "number" and type(b) == "number" then
		return a + (b - a) * t
	end
	if type(a) == "table" and type(b) == "table" then
		if a.x then
			return {
				x = a.x + (b.x - a.x) * t,
				y = a.y + (b.y - a.y) * t,
				z = a.z + (b.z - a.z) * t,
			}
		end
		local out = {}
		for k in next, a do
			if type(a[k]) == "number" and type(b[k]) == "number" then
				out[k] = a[k] + (b[k] - a[k]) * t
			else
				out[k] = a[k]
			end
		end
		return out
	end
	return t < 0.5 and a or b
end

--- Sample a keyframe track at a given time.<br>
--- Each keyframe is `{ time, value }` or `{ time, value, easing }`.<br>
--- Supports `"loop"` and `"pingpong"` loop modes.
---@param keyframes table Array of keyframes `{ time, value[, easing] }`, sorted by time.
---@param time number Current time in seconds.
---@param loopMode string `"once"`, `"loop"`, or `"pingpong"`.
---@param duration number|nil Total duration. Defaults to the last keyframe's time.
---@return any value The sampled value, or nil if no keyframes.
local function sampleTrack(keyframes, time, loopMode, duration)
	local n = #keyframes
	if n == 0 then return nil end
	if n == 1 then return keyframes[1][2] end

	local dur = duration or keyframes[n][1]
	if dur <= 0 then return keyframes[n][2] end

	local t = time
	if loopMode == "loop" then
		t = t % dur
	elseif loopMode == "pingpong" then
		local period = dur * 2
		local phase = t % period
		t = phase > dur and (dur * 2 - phase) or phase
	elseif t > dur then
		t = dur
	end

	if t <= keyframes[1][1] then return keyframes[1][2] end
	if t >= keyframes[n][1] then return keyframes[n][2] end

	for i = 1, n - 1 do
		local kfA, kfB = keyframes[i], keyframes[i + 1]
		if t >= kfA[1] and t <= kfB[1] then
			local span = kfB[1] - kfA[1]
			if span == 0 then return kfA[2] end
			local frac = (t - kfA[1]) / span
			if kfA[3] then
				frac = applyEasing(frac, kfA[3])
			end
			return lerpValue(kfA[2], kfB[2], frac)
		end
	end

	return keyframes[n][2]
end

--- Reusable keyframe-based animation data. Add tracks via `addTrack` that target
--- specific component properties with keyframe arrays.
---@class ecs.AnimationClip
---@field tracks table Array of track descriptors: `{ componentClass, property, keyframes }`.
---@field duration number Total duration in seconds (auto-computed from keyframes).
local AnimationClip = class "AnimationClip"
	:constructor(function(self)
		self.tracks = {}
		self.duration = 0
	end)
	:method {
		--- Add a track targeting a component property with keyframes.<br>
		--- Keyframes are `{ time, value }` or `{ time, value, easingName }`, sorted by time.<br>
		--- Updates the clip's duration if the last keyframe's time exceeds it.
		---@param componentClass table Component class to animate.
		---@param property string Property name on the component.
		---@param keyframes table Array of keyframes.
		addTrack = function(self, componentClass, property, keyframes)
			if #keyframes > 0 then
				local last = keyframes[#keyframes]
				if last[1] > self.duration then
					self.duration = last[1]
				end
			end
			self.tracks[#self.tracks + 1] = {
				componentClass = componentClass,
				property = property,
				keyframes = keyframes,
			}
		end,
	}

--- Per-entity component for playback state of an AnimationClip.
---@class ecs.AnimationState
---@field clip ecs.AnimationClip|nil The currently assigned clip.
---@field time number Current playback time in seconds.
---@field speed number Playback speed multiplier (default: 1).
---@field loopMode string `"once"`, `"loop"`, or `"pingpong"`.
---@field weight number Blend weight (default: 1, reserved).
---@field isPlaying boolean Whether the animation is actively playing.
local AnimationState = class "AnimationState"
	:constructor(function(self, clip)
		self.clip = clip or nil
		self.time = 0
		self.speed = 1
		self.loopMode = "once"
		self.weight = 1
		self.isPlaying = true
	end)
	:method {
		--- Start playing a clip from the beginning.
		---@param clip ecs.AnimationClip
		play = function(self, clip)
			self.clip = clip
			self.time = 0
			self.isPlaying = true
		end,
		--- Stop and reset to time 0.
		stop = function(self)
			self.isPlaying = false
			self.time = 0
		end,
		--- Pause playback (keeps current time).
		pause = function(self)
			self.isPlaying = false
		end,
		--- Resume playback from the current time.
		resume = function(self)
			self.isPlaying = true
		end,
		--- Get normalized time in [0, 1] (current time / clip duration).
		---@return number normalized
		getNormalizedTime = function(self)
			if not self.clip or self.clip.duration == 0 then return 0 end
			return self.time / self.clip.duration
		end,
	}

--- Advances AnimationState components each frame and applies the sampled
--- keyframe values to the target component properties.<br>
--- Declares `requiredComponents = { AnimationState }`.
---@class ecs.AnimationSystem: ecs.System
local AnimationSystem = class "AnimationSystem":extends(System)
	:static {
		requiredComponents = { AnimationState },
	}
	:method {
		process = function(self, entity, dt)
			local state = entity:getComponent(AnimationState)
			if not state or not state.isPlaying or not state.clip then return end

			local clip = state.clip
			state.time = state.time + state.speed * dt

			local tracks = clip.tracks
			for i = 1, #tracks do
				local track = tracks[i]
				local value = sampleTrack(track.keyframes, state.time, state.loopMode, clip.duration)
				if value ~= nil then
					local comp = entity:getComponent(track.componentClass)
					if comp then
						local prop = track.property
						if type(value) == "table" and comp[prop] == nil then
							if value.x ~= nil then comp.x = value.x end
							if value.y ~= nil then comp.y = value.y end
							if value.z ~= nil then comp.z = value.z end
						else
							comp[prop] = value
						end
					end
				end
			end

			if state.loopMode == "once" and state.time >= clip.duration then
				state.time = clip.duration
				state.isPlaying = false
			end
		end,
	}

--- Reads Velocity and applies it to Position each frame (Euler integration).<br>
--- Declares `requiredComponents = { Position, Velocity }`.
---@class ecs.MovementSystem: ecs.System
local MovementSystem = class "MovementSystem":extends(System)
	:static {
		requiredComponents = { Position, Velocity },
	}
	:method {
		process = function(self, entity, dt)
			local pos = entity:getComponent(Position)
			local vel = entity:getComponent(Velocity)
			pos.x = pos.x + vel.x * dt
			pos.y = pos.y + vel.y * dt
			pos.z = pos.z + vel.z * dt
		end
	}

--- Target position component. When paired with `MoveTo` and `Position`,
--- the `MoveToSystem` moves the entity toward this target each frame.
---@class ecs.TargetPosition
---@field x number Target X coordinate.
---@field y number Target Y coordinate.
---@field z number Target Z coordinate.
local TargetPosition = class "TargetPosition"
	:constructor(function(self, x, y, z)
		if type(x) == "table" and x.x then
			self.x, self.y, self.z = x.x, x.y, x.z
		else
			self.x = x or 0
			self.y = y or 0
			self.z = z or 0
		end
	end)

--- Movement settings for homing toward a `TargetPosition`. Consumed by `MoveToSystem`.
---@class ecs.MoveTo
---@field speed number Movement speed in units per second.
---@field stoppingDist number Distance at which the entity snaps to target and `arrived` is set.
---@field arrived boolean Set to true once the target is reached.
local MoveTo = class "MoveTo"
	:constructor(function(self, speed, stoppingDist)
		self.speed = speed or 100
		self.stoppingDist = stoppingDist or 1
		self.arrived = false
	end)

--- Moves entities with `Position` + `TargetPosition` + `MoveTo` toward the target
--- each frame at the configured speed. Snaps to target when within `stoppingDist`
--- and sets `move.arrived = true`.
---@class ecs.MoveToSystem: ecs.System
local MoveToSystem = class "MoveToSystem":extends(System)
	:static {
		requiredComponents = { Position, TargetPosition, MoveTo },
	}
	:method {
		process = function(self, entity, dt)
			local pos = entity:getComponent(Position)
			local target = entity:getComponent(TargetPosition)
			local move = entity:getComponent(MoveTo)

			local dx = target.x - pos.x
			local dy = target.y - pos.y
			local dz = target.z - pos.z
			local dist = math.sqrt(dx * dx + dy * dy + dz * dz)

			if dist <= move.stoppingDist then
				pos.x, pos.y, pos.z = target.x, target.y, target.z
				move.arrived = true
				return
			end

			local step = move.speed * dt
			if step >= dist then
				pos.x, pos.y, pos.z = target.x, target.y, target.z
				move.arrived = true
				return
			end

			local ratio = step / dist
			pos.x = pos.x + dx * ratio
			pos.y = pos.y + dy * ratio
			pos.z = pos.z + dz * ratio
		end,
	}

--- Target angle component. When paired with `RotateTo` and `Angle`,
--- the `RotateToSystem` rotates the entity toward this target each frame.
---@class ecs.TargetAngle
---@field p number Target pitch.
---@field y number Target yaw.
---@field r number Target roll.
local TargetAngle = class "TargetAngle"
	:constructor(function(self, p, y, r)
		if type(p) == "table" and p.p then
			self.p, self.y, self.r = p.p, p.y, p.r
		else
			self.p = p or 0
			self.y = y or 0
			self.r = r or 0
		end
	end)

--- Rotation settings for homing toward a `TargetAngle`. Consumed by `RotateToSystem`.
---@class ecs.RotateTo
---@field speed number Rotation speed in degrees per second.
---@field stoppingAngle number Angle difference at which the entity snaps to target and `arrived` is set.
---@field arrived boolean Set to true once the target is reached.
local RotateTo = class "RotateTo"
	:constructor(function(self, speed, stoppingAngle)
		self.speed = speed or 90
		self.stoppingAngle = stoppingAngle or 1
		self.arrived = false
	end)

--- Rotates entities with `Angle` + `TargetAngle` + `RotateTo` toward the target
--- each frame at the configured speed. Snaps to target when within `stoppingAngle`
--- and sets `rotate.arrived = true`.
---@class ecs.RotateToSystem: ecs.System
local RotateToSystem = class "RotateToSystem":extends(System)
	:static {
		requiredComponents = { Angle, TargetAngle, RotateTo },
	}
	:method {
		process = function(self, entity, dt)
			local ang = entity:getComponent(Angle)
			local target = entity:getComponent(TargetAngle)
			local rotate = entity:getComponent(RotateTo)

			local dp = target.p - ang.p
			local dy = target.y - ang.y
			local dr = target.r - ang.r

			-- Normalize yaw to shortest path
			dy = (dy + 180) % 360 - 180

			local dist = math.sqrt(dp * dp + dy * dy + dr * dr)

			if dist <= rotate.stoppingAngle then
				ang.p, ang.y, ang.r = target.p, target.y, target.r
				rotate.arrived = true
				return
			end

			local step = rotate.speed * dt
			if step >= dist then
				ang.p, ang.y, ang.r = target.p, target.y, target.r
				rotate.arrived = true
				return
			end

			local ratio = step / dist
			ang.p = ang.p + dp * ratio
			ang.y = ang.y + dy * ratio
			ang.r = ang.r + dr * ratio
		end,
	}

--- Component that holds all active tween configs for an entity. Added automatically
--- by `ecs.to` / `ecs.from` when first needed. The actual tween configs are
--- plain tables stored in `_tweens`; see `ecs.to` for their field documentation.
---@class ecs.Tween
local Tween = class "Tween"
	:constructor(function(self)
		self._tweens = {}
	end)

--- Internal tween configuration table stored in `Tween._tweens`. Created by `ecs.to` / `ecs.from`.
---@class ecs.TweenConfig
---@field target table Component class to animate.
---@field toValues table Target values `{ prop = value, ... }`.
---@field fromValues table Source values (auto-captured on first frame).
---@field duration number Duration in seconds.
---@field elapsed number Elapsed time.
---@field delay number Initial delay before the tween starts.
---@field easing string Easing function name (from `easings` table). Default `"linear"`.
---@field isPlaying boolean Whether the tween is actively running.
---@field isComplete boolean True when the tween has finished and can be cleaned up.
---@field yoyo boolean If true, reverse after reaching the target.
---@field loop number 0 = once, N = N times, <0 = infinite.
---@field loopsDone number How many loops have completed.
---@field onStart fun(self: ecs.Entity, tw: ecs.TweenConfig)|nil Called on the first frame.
---@field onUpdate fun(self: ecs.Entity, tw: ecs.TweenConfig, progress: number)|nil Called each frame.
---@field onComplete fun(self: ecs.Entity, tw: ecs.TweenConfig)|nil Called when fully done.
---@field onYoyo fun(self: ecs.Entity, tw: ecs.TweenConfig)|nil Called each time a yoyo reversal starts.

---@class ecs.TweenOptions
---@field easing string|nil Easing function name (default: `"linear"`).
---@field delay number|nil Initial delay in seconds (default: 0).
---@field yoyo boolean|nil Reverse after reaching the target (default: false).
---@field loop number|nil 0 = once, N = N times, <0 = infinite (default: 0).
---@field paused boolean|nil Create but don't start playing (default: false).
---@field onStart fun(self: ecs.Entity, tw: ecs.TweenConfig)|nil Called on the first frame.
---@field onUpdate fun(self: ecs.Entity, tw: ecs.TweenConfig, progress: number)|nil Called each frame.
---@field onComplete fun(self: ecs.Entity, tw: ecs.TweenConfig)|nil Called when fully done.
---@field onYoyo fun(self: ecs.Entity, tw: ecs.TweenConfig)|nil Called each time a yoyo reversal starts.

--- Processes all Tween components each frame: advances time, interpolates
--- values, applies them to the target component, and removes completed tweens.<br>
--- Declares `requiredComponents = { Tween }`.
---@class ecs.TweenSystem: ecs.System
local TweenSystem = class "TweenSystem":extends(System)
	:static {
		requiredComponents = { Tween },
	}
	:method {
		process = function(self, entity, dt)
			local tweens = entity:getComponent(Tween)._tweens
			local i = 1
			while i <= #tweens do
				local tw = tweens[i]
				if tw.isPlaying and not tw.isComplete then
					self:_advance(entity, tw, dt)
				end
				if tw.isComplete then
					table.remove(tweens, i)
				else
					i = i + 1
				end
			end
		end,

		_advance = function(self, entity, tw, dt)
			if tw._delayElapsed < tw.delay then
				tw._delayElapsed = tw._delayElapsed + dt
				return
			end

			local comp = entity:getComponent(tw.target)
			if not comp then
				tw.isComplete = true
				return
			end

			if not tw._initialized then
				if tw._swapDirection then
					tw.toValues = {}
					for prop in pairs(tw._specifiedValues) do
						if type(comp[prop]) == "number" then
							tw.fromValues[prop] = tw._specifiedValues[prop]
							tw.toValues[prop] = comp[prop]
						end
					end
				else
					for prop in pairs(tw.toValues) do
						if type(comp[prop]) == "number" then
							tw.fromValues[prop] = comp[prop]
						end
					end
				end
				tw._initialized = true
				if tw.onStart then tw.onStart(entity, tw) end
			end

			tw.elapsed = tw.elapsed + dt
			local progress = math.min(tw.elapsed / tw.duration, 1)
			local eased = applyEasing(progress, tw.easing)

			for prop, toVal in pairs(tw.toValues) do
				local fromVal = tw.fromValues[prop]
				if fromVal ~= nil then
					comp[prop] = lerpValue(fromVal, toVal, eased)
				end
			end

			if tw.onUpdate then tw.onUpdate(entity, tw, progress) end

			if progress >= 1 then
				if tw.yoyo and not tw._returning then
					tw._returning = true
					local tmp = tw.fromValues
					tw.fromValues = tw.toValues
					tw.toValues = tmp
					tw.elapsed = 0
					if tw.onYoyo then tw.onYoyo(entity, tw) end
				elseif tw.loop ~= 0 then
					tw.loopsDone = tw.loopsDone + 1
					if tw.loop < 0 or tw.loopsDone < tw.loop then
						tw.elapsed = 0
						tw._returning = false
						if tw._swapDirection then
							for prop in pairs(tw._specifiedValues) do
								if type(comp[prop]) == "number" then
									tw.fromValues[prop] = comp[prop]
								end
							end
						else
							for prop in pairs(tw.toValues) do
								if type(comp[prop]) == "number" then
									tw.fromValues[prop] = comp[prop]
								end
							end
						end
					else
						tw.isComplete = true
						if tw.onComplete then tw.onComplete(entity, tw) end
					end
				else
					tw.isComplete = true
					if tw.onComplete then tw.onComplete(entity, tw) end
				end
			end
		end,
	}

--- Parse the variadic arguments of `ecs.to` / `ecs.from`.<br>
--- Supports two forms:<br>
---   `(property_string, target_value, duration, opts_table)`<br>
---   `({ prop = value, ... }, duration, opts_table)`
---@param ... any
---@return table values `{ prop = target }`
---@return number|nil duration
---@return ecs.TweenOptions|nil opts
local function parseTweenArgs(...)
	local args = { ... }
	if type(args[1]) == "string" then
		return { [args[1]] = args[2] }, args[3], args[4]
	end
	return args[1], args[2], args[3]
end

--- Tween component properties TO specified target values over time.<br>
--- Automatically adds a Tween component to the entity if one does not exist.<br>
--- The returned TweenConfig table can be mutated (e.g. change `duration` in `onUpdate`).
---@param entity ecs.Entity ECS entity whose component will be animated.
---@param component table Component class to target.
---@param ... string|table|number Either a property name followed by target value, or a table of `{prop=value}`.
---@param opts ecs.TweenOptions|nil Optional configuration (passed as last arg via ...).
---@return ecs.TweenConfig config The tween configuration table (can be mutated).
---@usage <br>
--- ```
--- -- Single property
--- ecs.to(entity, Component, "x", 100, 2, { easing = "easeOutQuad" })
---
--- -- Multiple properties
--- ecs.to(entity, Component, { x = 100, y = 200 }, 1.5)
---
--- -- With full options
--- ecs.to(entity, Component, "size", 2, 3, {
---     easing = "easeOutElastic",
---     delay = 0.5,
---     yoyo = true,
---     loop = 3,
---     paused = false,
---     onStart = function(e, tw) end,
---     onUpdate = function(e, tw, p) end,
---     onComplete = function(e, tw) end,
--- })
--- ```
function ecs.to(entity, component, ...)
	if not entity:hasComponent(Tween) then
		entity:addComponent(Tween)
	end
	local values, duration, opts = parseTweenArgs(...)
	opts = opts or {}

	local tweenComp = entity:getComponent(Tween)
	local config = {
		target = component,
		toValues = values,
		fromValues = {},
		duration = duration or 1,
		elapsed = 0,
		delay = opts.delay or 0,
		_delayElapsed = 0,
		easing = opts.easing or "linear",
		isPlaying = not opts.paused,
		isComplete = false,
		_initialized = false,
		_swapDirection = false,
		yoyo = opts.yoyo or false,
		loop = opts.loop or 0,
		loopsDone = 0,
		_returning = false,
		onStart = opts.onStart,
		onUpdate = opts.onUpdate,
		onComplete = opts.onComplete,
		onYoyo = opts.onYoyo,
	}

	tweenComp._tweens[#tweenComp._tweens + 1] = config
	return config
end

--- Tween component properties FROM the specified values TO their current values.<br>
--- Same calling convention as `ecs.to`, but the specfied values are treated as
--- the starting point and the current component values become the target.
---@param entity ecs.Entity
---@param component table Component class to target.
---@param ... string|table|number Property name + value, or `{prop=value}` table.
---@param opts ecs.TweenOptions|nil Optional configuration (passed as last arg via ...).
---@return ecs.TweenConfig config
---@usage <br>
--- ```
--- -- From a specific value to the current value
--- ecs.from(entity, Component, "x", 0, 1)
--- ecs.from(entity, Component, { x = 0, y = 0 }, 1, { easing = "easeOutQuad" })
--- ```
function ecs.from(entity, component, ...)
	if not entity:hasComponent(Tween) then
		entity:addComponent(Tween)
	end
	local values, duration, opts = parseTweenArgs(...)
	opts = opts or {}

	local tweenComp = entity:getComponent(Tween)
	local config = {
		target = component,
		toValues = {},
		fromValues = {},
		_specifiedValues = values,
		duration = duration or 1,
		elapsed = 0,
		delay = opts.delay or 0,
		_delayElapsed = 0,
		easing = opts.easing or "linear",
		isPlaying = not opts.paused,
		isComplete = false,
		_initialized = false,
		_swapDirection = true,
		yoyo = opts.yoyo or false,
		loop = opts.loop or 0,
		loopsDone = 0,
		_returning = false,
		onStart = opts.onStart,
		onUpdate = opts.onUpdate,
		onComplete = opts.onComplete,
		onYoyo = opts.onYoyo,
	}

	tweenComp._tweens[#tweenComp._tweens + 1] = config
	return config
end

ecs.Entity = Entity
ecs.System = System
ecs.World = World
ecs.AnimationClip = AnimationClip
ecs.AnimationState = AnimationState
ecs.AnimationSystem = AnimationSystem
ecs.MovementSystem = MovementSystem
ecs.Position = Position
ecs.Velocity = Velocity
ecs.Angle = Angle
ecs.Color = Color
ecs.TargetPosition = TargetPosition
ecs.MoveTo = MoveTo
ecs.MoveToSystem = MoveToSystem
ecs.TargetAngle = TargetAngle
ecs.RotateTo = RotateTo
ecs.RotateToSystem = RotateToSystem
ecs.Tween = Tween
ecs.TweenSystem = TweenSystem

-- Restore global registration
luameta.popGlobal()

-- Export
return ecs
