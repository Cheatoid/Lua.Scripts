-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Localized global functions for better performance
local error = error
local next = next
local setmetatable = setmetatable
local table_insert = table.insert
local table_remove = table.remove

-- Import dependencies
local Animation = require "animation"

----------------------------------------------------------------------
-- Animator
----------------------------------------------------------------------

---@class animation.Animator
---@field animations animation.Animation[] Array of active Animation objects.
local animator = {}
animator.__index = animator

--- Create a new Animator instance.
---@return animation.Animator animator New Animator instance.
---@usage <br>
--- ```
--- local mgr = animator.new()
--- ```
function animator.new()
	return setmetatable({
		animations = {},
	}, animator)
end

--- Add an animation to the animator.
---@param self animation.Animator The animator instance.
---@param animation animation.Animation Animation object (must implement update and isFinished).
---@return animation.Animation animation The added animation.
---@usage <br>
--- ```
--- local anim = Animation.new(0, 100, 1)
--- mgr:add(anim)
--- ```
function animator.add(self, animation)
	if not (animation and animation.update) then
		return error("Animator:add() expected an Animation object", 2)
	end
	table_insert(self.animations, animation)
	return animation
end

--- Remove a specific animation from the animator.
---@param self animation.Animator The animator instance.
---@param animation animation.Animation Animation object to remove.
---@return boolean removed True if the animation was found and removed.
---@usage <br>
--- ```
--- mgr:remove(anim)
--- ```
function animator.remove(self, animation)
	for i, anim in next, self.animations do
		if anim == animation then
			table_remove(self.animations, i)
			return true
		end
	end
	return false
end

--- Update all animations and remove finished ones.
---@param self animation.Animator The animator instance.
---@param time number Current time.
---@usage <br>
--- ```
--- mgr:update(os.clock())
--- ```
function animator.update(self, time)
	for i = #self.animations, 1, -1 do -- NOTE: must be in reverse due to table.remove call
		local anim = self.animations[i]
		Animation.update(anim, time)
		if Animation.isFinished(anim) then
			table_remove(self.animations, i)
		end
	end
end

--- Remove all animations.
---@param self animation.Animator The animator instance.
---@usage <br>
--- ```
--- mgr:clear()
--- ```
function animator.clear(self)
	self.animations = {}
end

--- Check whether the animator has no active animations.
---@param self animation.Animator The animator instance.
---@return boolean isEmpty True if there are no active animations.
---@usage <br>
--- ```
--- print(mgr:isEmpty()) -- true
--- ```
function animator.isEmpty(self)
	return #self.animations == 0
end

--- Get the number of active animations.
---@param self animation.Animator The animator instance.
---@return integer count Number of active animations.
---@usage <br>
--- ```
--- print(mgr:count())
--- ```
function animator.count(self)
	return #self.animations
end

-- Deprecated aliases (naming standard: snake_case). Kept for compatibility.
animator.is_empty = animator.isEmpty

-- Export
return animator
