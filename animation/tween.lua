-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Import dependencies
local Animation = require "animation"
local Animator = require "animator"

----------------------------------------------------------------------
-- Tween
----------------------------------------------------------------------

---@class animation.Tween Tween convenience API.
local tween = {}

---@type animation.Animator The default animator instance used by tween.now.
local defaultAnimator = Animator.new()

--- Create a new Animation instance (does not start it).
---@param startValue number Start value.
---@param endValue number End value.
---@param duration number Duration in seconds.
---@param easingFunc? fun(t: number): number|string Optional easing function or string name.
---@param onUpdate? fun(value: number, progress: number) Optional per-frame callback.
---@param onComplete? fun() Optional completion callback.
---@return animation.Animation animation New Animation instance.
---@usage <br>
--- ```
--- local anim = tween.new(0, 100, 1, easing.InOutQuad)
--- -- or use a string name:
--- local anim2 = tween.new(0, 100, 1, "InOutQuad")
--- ```
function tween.new(startValue, endValue, duration, easingFunc, onUpdate, onComplete)
	return Animation.new(startValue, endValue, duration, easingFunc, onUpdate, onComplete)
end

--- Create and immediately start an animation on the default animator.
---@param startValue number Start value.
---@param endValue number End value.
---@param duration number Duration in seconds.
---@param easingFunc? fun(t: number): number|string Optional easing function or string name.
---@param onUpdate? fun(value: number, progress: number) Optional per-frame callback.
---@param onComplete? fun() Optional completion callback.
---@param time? number Optional start time (default: 0).
---@return animation.Animation animation Started Animation instance.
---@usage <br>
--- ```
--- local anim = tween.now(0, 100, 1, easing.InOutQuad, function(v) print(v) end)
--- -- or use a string name:
--- local anim2 = tween.now(0, 100, 1, "InOutQuad", function(v) print(v) end)
--- ```
function tween.now(startValue, endValue, duration, easingFunc, onUpdate, onComplete, time)
	local anim = Animation.new(startValue, endValue, duration, easingFunc, onUpdate, onComplete)
	Animation.start(anim, time or 0)
	Animator.add(defaultAnimator, anim)
	return anim
end

--- Update all animations managed by the default animator.
---@param time number Current time.
---@usage <br>
--- ```
--- tween.update(os.clock())
--- ```
function tween.update(time)
	Animator.update(defaultAnimator, time)
end

--- Remove all animations from the default animator.
---@usage <br>
--- ```
--- tween.clear()
--- ```
function tween.clear()
	Animator.clear(defaultAnimator)
end

--- Check whether the default animator has no active animations.
---@return boolean isIdle True if there are no active animations.
---@usage <br>
--- ```
--- print(tween.isIdle()) -- true
--- ```
function tween.isIdle()
	return Animator.isEmpty(defaultAnimator)
end

--- Get the number of active animations in the default animator.
---@return integer count Number of active animations.
---@usage <br>
--- ```
--- print(tween.count())
--- ```
function tween.count()
	return Animator.count(defaultAnimator)
end

-- Export
return tween
