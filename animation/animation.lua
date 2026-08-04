-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Localized global functions for better performance
local error = error
local setmetatable = setmetatable
local type = type

-- Import dependencies
local Easing = require "easing"
local Interpolation = require "interpolation"
local lerp = Interpolation.LerpUnclamped

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------

--- Clamp a number to the [0, 1] range.
---@param n number Value to clamp.
---@return number clamped Clamped value in [0, 1].
local function clamp01(n)
	return n < 0 and 0 or (n > 1 and 1 or n)
end

--- Default easing function (identity / linear).
---@param t number Progress in [0, 1].
---@return number t Unmodified input.
local function defaultEasingFunc(t)
	return t
end

--- Resolve an easing function from a function or string name.
---@param func? fun(t: number): number|string Easing function or string name.
---@return fun(t: number): number resolved The resolved easing function.
local function resolveEasingFunc(func)
	if func == nil then
		return defaultEasingFunc
	end
	if type(func) == "string" then
		local resolved = Easing[func]
		if resolved == nil then
			return error("unknown easing function: " .. tostring(func), 3)
		end
		return resolved
	end
	return func
end

----------------------------------------------------------------------
-- Animation
----------------------------------------------------------------------

---@class animation.Animation
---@field startValue number Start value.
---@field endValue number End value.
---@field duration number Duration in seconds.
---@field easingFunc fun(t: number): number Resolved easing function.
---@field onUpdate? fun(value: number, progress: number) Per-frame callback.
---@field onComplete? fun() Completion callback.
---@field startTime number|nil Start time (set when start is called).
---@field currentValue number Current interpolated value.
---@field isFinished boolean Whether the animation is done.
local animation = {}
animation.__index = animation

--- Create a new Animation instance.
---@param startValue number Start value.
---@param endValue number End value.
---@param duration number Duration in seconds.
---@param easingFunc? fun(t: number): number|string Optional easing function or string name (defaults to linear).
---@param onUpdate? fun(value: number, progress: number) Optional callback on each update.
---@param onComplete? fun() Optional callback when animation finishes.
---@return animation.Animation animation New Animation instance.
---@usage <br>
--- ```
--- local anim = Animation.new(0, 100, 1, easing.InOutQuad, function(value)
---   print(value)
--- end)
--- -- or use a string name:
--- local anim2 = Animation.new(0, 100, 1, "InOutQuad")
--- ```
function animation.new(startValue, endValue, duration, easingFunc, onUpdate, onComplete)
	return setmetatable({
		startValue = startValue,
		endValue = endValue,
		duration = duration,
		easingFunc = resolveEasingFunc(easingFunc),
		onUpdate = onUpdate,
		onComplete = onComplete,
		startTime = nil, -- set when start is called
		currentValue = startValue,
		isFinished = false,
	}, animation)
end

--- Start the animation at the given time.
---@param self animation.Animation The animation instance.
---@param time number Current time.
---@return animation.Animation self The animation instance.
---@usage <br>
--- ```
--- anim:start(os.clock())
--- ```
function animation.start(self, time)
	self.startTime = time
	self.isFinished = false
	self.currentValue = self.startValue
	return self
end

--- Update the animation with the current time.
---@param self animation.Animation The animation instance.
---@param time number Current time.
---@return number currentValue Current interpolated value.
---@usage <br>
--- ```
--- local value = anim:update(os.clock())
--- ```
function animation.update(self, time)
	if self.isFinished then return self.currentValue end

	local elapsed = time - self.startTime
	local progress = elapsed / self.duration

	progress = progress < 1 and progress or 1 --math.min(progress, 1)
	local eased = self.easingFunc(progress)

	self.currentValue = lerp(self.startValue, self.endValue, eased)

	if self.onUpdate then
		self.onUpdate(self.currentValue, progress)
	end

	if progress >= 1 then
		self.isFinished = true
		if self.onComplete then
			self.onComplete()
		end
	end

	return self.currentValue
end

--- Check whether the animation has finished.
---@param self animation.Animation The animation instance.
---@return boolean isFinished True if the animation is done.
---@usage <br>
--- ```
--- if anim:isFinished() then
---   print("done")
--- end
--- ```
function animation.isFinished(self)
	return self.isFinished
end

--- Get the current interpolated value.
---@param self animation.Animation The animation instance.
---@return number currentValue The current value.
---@usage <br>
--- ```
--- print(anim:getValue())
--- ```
function animation.getValue(self)
	return self.currentValue
end

--- Manually set the animation progress.
---@param self animation.Animation The animation instance.
---@param progress number Progress in [0, 1].
---@usage <br>
--- ```
--- anim:setProgress(0.5)
--- ```
function animation.setProgress(self, progress)
	progress = clamp01(progress)
	local eased = self.easingFunc(progress)
	self.currentValue = lerp(self.startValue, self.endValue, eased)
	if self.onUpdate then
		self.onUpdate(self.currentValue, progress)
	end
	if progress < 1 then
		self.isFinished = false
	else
		self.isFinished = true
		if self.onComplete then self.onComplete() end
	end
end

-- Export
return animation
