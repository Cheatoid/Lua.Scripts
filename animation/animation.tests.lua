-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Quick tests for the Animation library (manually stepped).
-- Run from this directory:
--   lua animation.tests.lua
--   luajit animation.tests.lua
-- Deterministic mock clock: tests never touch `os.clock`.
-- LuaJIT/5.1+ compatible.

package.path = "./?.lua;" .. package.path

local anim = require "init"
local Interpolation = anim.Interpolation
local Easing = anim.Easing
local Animation = anim.Animation
local Animator = anim.Animator
local Tween = anim.Tween

local EPS = 1e-6

local function approx(a, b, eps)
	eps = eps or EPS
	return math.abs(a - b) <= eps
end

local function assert_approx(actual, expected, message)
	assert(approx(actual, expected),
		(message or "values differ") .. string.format(" (expected %.6f, got %.6f)", expected, actual))
end

-- Interpolation sanity (basis for Animation values).
do
	assert(Interpolation.LerpUnclamped(0, 100, 0.5) == 50, "LerpUnclamped(0, 100, 0.5) should be 50")
	assert(Interpolation.Lerp(0, 100, 0.25) == 25, "Lerp alias should match LerpUnclamped")
	assert_approx(Interpolation.LerpUnclamped(10, 20, 0.3), 13, "LerpUnclamped(10, 20, 0.3) should be 13")
end

-- README: Manual Animation Control, driven with a manual clock.
do
	local now = 100
	local updates = {}
	local completed = 0
	local anim = Animation.new(0, 100, 2, "OutBounce",
		function(value, progress) updates[#updates + 1] = { value = value, progress = progress } end,
		function() completed = completed + 1 end)
	assert(anim:getValue() == 0, "new animation value should start at startValue")
	assert(anim:isFinished() == false, "new animation should not be finished")
	assert(type(anim.isFinished) == "function", "isFinished method must remain a function")

	anim:start(now)
	assert(anim:getValue() == 0, "start should reset value to startValue")
	assert(anim:isFinished() == false, "start should clear finished flag")

	local mid = anim:update(now + 1) -- progress 0.5
	assert(#updates >= 1, "onUpdate should fire on update")
	assert_approx(updates[#updates].progress, 0.5, "mid progress should be 0.5")
	assert(mid >= 0 and mid <= 100, "OutBounce mid value should stay in range")
	assert(anim:isFinished() == false, "animation should not be finished at progress 0.5")

	local final = anim:update(now + 2) -- progress 1.0
	assert(final == 100, "final value should equal endValue")
	assert(anim:getValue() == 100, "getValue should return endValue when done")
	assert(anim:isFinished() == true, "animation should be finished at progress 1.0")
	assert(completed == 1, "onComplete should fire exactly once")

	local frozen = anim:update(now + 5)
	assert(frozen == 100, "update after finish should stick at endValue")
	assert(completed == 1, "onComplete should not fire twice")

	anim:start(now + 10) -- restart
	assert(anim:isFinished() == false, "restart should clear finished flag")
	assert(anim:getValue() == 0, "restart should reset value")
end

-- README: String-based easing matches function refs; nil defaults to linear.
do
	local a = Animation.new(0, 100, 1, "InQuad")
	a:start(0)
	assert_approx(a:update(0.5), 25, "InQuad(0.5) over 0->100 should be 25")

	local b = Animation.new(0, 100, 1, Easing.InQuad)
	b:start(0)
	assert_approx(b:update(0.5), 25, "function ref easing should match string name")

	local linear = Animation.new(0, 100, 1) -- nil easing defaults to linear
	linear:start(0)
	assert_approx(linear:update(0.5), 50, "default easing should be linear")

	local ok, err = pcall(function()
		return Animation.new(0, 100, 1, "NoSuchEasing")
	end)
	assert(not ok, "unknown easing name should error")
	assert(string.find(tostring(err), "unknown easing function") ~= nil,
		"unknown easing error should name the problem")
end

-- Internal fields are _-prefixed so they cannot collide with methods.
do
	local anim = Animation.new(0, 10, 1, "InQuad")
	anim:start(0)
	assert(type(anim._isFinished) == "boolean", "_isFinished field should be boolean")
	assert(type(anim._currentValue) == "number", "_currentValue field should be number")
	assert(type(anim._startValue) == "number", "_startValue field should exist")
	assert(anim.isFinished == Animation.isFinished, "isFinished method must not be shadowed by a field")
	assert(anim:isFinished() == false, "method call should report running")
	anim:update(1)
	assert(anim:isFinished() == true, "method call should report finished")
	assert(anim._isFinished == true, "_isFinished field should track finished state")
end

-- README: Manual Progress Control via setProgress().
do
	local completed = 0
	local seen = {}
	local anim = Animation.new(0, 100, 1, "InOutQuad",
		function(value, progress) seen[#seen + 1] = { value = value, progress = progress } end,
		function() completed = completed + 1 end)

	anim:setProgress(0.5) -- InOutQuad(0.5) == 0.5 -> 50
	assert_approx(anim:getValue(), 50, "setProgress(0.5) should give 50 with InOutQuad")
	assert(anim:isFinished() == false, "setProgress(0.5) should not finish")

	anim:setProgress(0.75)
	assert_approx(anim:getValue(), Easing.InOutQuad(0.75) * 100, "setProgress(0.75) should follow easing")
	assert(anim:isFinished() == false, "setProgress(0.75) should not finish")

	anim:setProgress(1.0) -- triggers onComplete
	assert(anim:getValue() == 100, "setProgress(1.0) should jump to end")
	assert(anim:isFinished() == true, "setProgress(1.0) should finish")
	assert(completed == 1, "setProgress(1.0) should trigger onComplete")

	anim:setProgress(0) -- rewind
	assert(anim:getValue() == 0, "setProgress(0) should jump back to start")
	assert(anim:isFinished() == false, "rewind should clear finished flag")

	anim:setProgress(-1) -- clamped
	assert(anim:getValue() == 0, "negative progress should clamp to start")
	anim:setProgress(2) -- clamped
	assert(anim:getValue() == 100, "progress > 1 should clamp to end")
	assert(anim:isFinished() == true, "clamped progress 1 should finish")
end

-- README: Managing Multiple Animations with Animator.
do
	local mgr = Animator.new()
	assert(mgr:isEmpty() == true, "new animator should be empty")
	assert(mgr:count() == 0, "new animator count should be 0")

	local a1 = Animation.new(0, 100, 1, "InQuad")
	a1:start(0)
	local a2 = Animation.new(0, 50, 2, "OutQuad")
	a2:start(0)
	mgr:add(a1)
	mgr:add(a2)
	assert(mgr:count() == 2, "animator should hold 2 animations")

	mgr:update(0.5)
	assert(mgr:count() == 2, "no animation finished at t=0.5")
	assert_approx(a1:getValue(), 25, "a1 at t=0.5 should be 25")
	assert_approx(a2:getValue(), 50 * Easing.OutQuad(0.25), "a2 at t=0.5 should follow OutQuad(0.25)")

	mgr:update(1.0) -- a1 completes and is auto-removed
	assert(mgr:count() == 1, "finished animation should be auto-removed")
	assert(mgr:isEmpty() == false, "animator should not be empty yet")

	mgr:update(2.0) -- a2 completes
	assert(mgr:count() == 0, "all finished animations should be removed")
	assert(mgr:isEmpty() == true, "animator should be empty when all done")

	-- remove / clear.
	local a3 = Animation.new(0, 10, 1)
	a3:start(0)
	mgr:add(a3)
	assert(mgr:remove(a3) == true, "remove should return true for known animation")
	assert(mgr:remove(a3) == false, "second remove should return false")
	mgr:add(a3)
	mgr:add(Animation.new(0, 10, 1))
	mgr:clear()
	assert(mgr:isEmpty() == true, "clear should empty the animator")

	local ok, err = pcall(function() mgr:add({}) end)
	assert(not ok, "adding a non-animation should error")
	assert(string.find(tostring(err), "expected an Animation") ~= nil,
		"bad add error should mention Animation")
end

-- README: Quick Start with Tween, driven with explicit manual times.
do
	Tween.clear()
	assert(Tween.isIdle() == true, "cleared tween should be idle")
	assert(Tween.count() == 0, "cleared tween count should be 0")

	local last = nil
	local done = 0
	Tween.now(0, 1, 0.5, "InOutQuad",
		function(value) last = value end,
		function() done = done + 1 end,
		0) -- explicit start time, no os.clock
	assert(Tween.count() == 1, "Tween.now should register one animation")
	assert(Tween.isIdle() == false, "tween should be busy while running")

	Tween.update(0.25)
	assert_approx(last, 0.5, "tween at half time should be 0.5 with InOutQuad")
	assert(Tween.count() == 1, "tween should still be active halfway")

	Tween.update(0.5)
	assert(last == 1, "tween should reach end value")
	assert(done == 1, "tween onComplete should fire once")
	assert(Tween.count() == 0, "finished tween should be auto-removed")
	assert(Tween.isIdle() == true, "tween should be idle when all done")

	-- Tween.new creates without starting.
	Tween.clear()
	local pending = Tween.new(0, 100, 1, "InQuad")
	assert(pending:isFinished() == false, "Tween.new should create a running-capable animation")
	assert(Tween.count() == 0, "Tween.new should not register on the shared animator")
end

print("All tests passed")
