# Animation

A lightweight, zero-dependency animation library for Lua providing value interpolation, easing functions, and a convenient
tween API.

## Features

- **Value Interpolation**: Animate numeric values from start to end over a duration
- **Easing Functions**: 30+ built-in easing functions (Quad, Cubic, Quart, Quint, Sine, Expo, Circ, Back, Elastic,
  Bounce) in In, Out, and InOut variants
- **String-Based Easing**: Reference easing functions by name (e.g., `"InOutQuad"`) instead of passing function references
- **Animator**: Manage multiple animations with automatic cleanup of finished animations
- **Tween Convenience API**: Quick one-liner animations with a shared global animator
- **Callbacks**: Per-frame `onUpdate` and completion `onComplete` callbacks
- **Manual Control**: Set animation progress manually via `setProgress()`
- **Zero Dependencies**: Pure Lua implementation
- **Type-Safe**: Includes LuaDocs annotations for IDE support

## Installation

```lua
local anim = require "init"
```

This loads the `animation` library via its entry-point (`init.lua`), which exports the following sub-modules:

- `Interpolation` - Linear interpolation functions
- `Easing` - Easing functions
- `Animation` - Core Animation class
- `Animator` - Animator (animation manager)
- `Tween` - Tween convenience API

## Usage

### Quick Start with Tween

The fastest way to get an animation running:

```lua
local anim = require "init"
local Tween = anim.Tween

-- Create and start an animation in one call
local myAnim = Tween.now(0, 100, 1, "InOutQuad", function(value, progress)
    print(value, progress)
end)

-- Call update in your tick/frame/update loop
Tween.update(os.clock())
```

### Using String-Based Easing

Instead of passing a function reference, you can pass a string name:

```lua
local anim = require "init"
local Tween = anim.Tween

local myAnim = Tween.now(0, 100, 1, "InOutQuad", function(value)
    print(value)
end)
```

### Manual Animation Control

Create an Animation instance and control it yourself:

```lua
local anim = require "init"
local Animation = anim.Animation

-- Create animation
local myAnim = Animation.new(0, 100, 2, "OutBounce", function(value, progress)
    print(value)
end)

-- Start it
myAnim:start(os.clock())

-- Update in your loop
local value = myAnim:update(os.clock())
if myAnim:isFinished() then
    print("Animation complete!")
end
```

### Managing Multiple Animations

Use the Animator to manage groups of animations:

```lua
local anim = require "init"
local Animation = anim.Animation
local Animator = anim.Animator

local mgr = Animator.new()

-- Add animations
mgr:add(Animation.new(0, 100, 1, "InQuad"))
mgr:add(Animation.new(0, 50, 2, "OutQuad"))

-- Update all at once (finished ones are auto-removed)
mgr:update(os.clock())

print(mgr:count())  -- Number of active animations
print(mgr:isEmpty()) -- true when all done
```

### Manual Progress Control

Set animation progress directly without time-based updates:

```lua
local anim = require "init"
local Animation = anim.Animation

local myAnim = Animation.new(0, 100, 1, "InOutQuad")

-- Jump to 50% progress
myAnim:setProgress(0.5)

-- Jump to 75% progress
myAnim:setProgress(0.75)

-- Jump to end
myAnim:setProgress(1.0)  -- Triggers onComplete
```

## API Reference

### interpolation

#### `Interpolation.LerpUnclamped(a, b, t)`

Linearly interpolates between two values.

- **a** (number): Start value
- **b** (number): End value
- **t** (number): Interpolation factor (unclamped)
- **Returns**: number

```lua
local anim = require "init"
local v = anim.Interpolation.LerpUnclamped(0, 100, 0.5) -- 50
```

#### `Interpolation.Lerp`

Alias for `LerpUnclamped`.

### easing

All easing functions accept a progress value `t` in the `[0, 1]` range and return an eased value.

#### Available Functions

| Family      | In          | Out          | InOut          |
| ----------- | ----------- | ------------ | -------------- |
| **Quad**    | `InQuad`    | `OutQuad`    | `InOutQuad`    |
| **Cubic**   | `InCubic`   | `OutCubic`   | `InOutCubic`   |
| **Quart**   | `InQuart`   | `OutQuart`   | `InOutQuart`   |
| **Quint**   | `InQuint`   | `OutQuint`   | `InOutQuint`   |
| **Sine**    | `InSine`    | `OutSine`    | `InOutSine`    |
| **Expo**    | `InExpo`    | `OutExpo`    | `InOutExpo`    |
| **Circ**    | `InCirc`    | `OutCirc`    | `InOutCirc`    |
| **Back**    | `InBack`    | `OutBack`    | `InOutBack`    |
| **Elastic** | `InElastic` | `OutElastic` | `InOutElastic` |
| **Bounce**  | `InBounce`  | `OutBounce`  | `InOutBounce`  |

#### `Easing.FunctionName(t)`

- **t** (number): Progress in `[0, 1]`
- **Returns**: number (eased value)

```lua
local anim = require "init"
local eased = anim.Easing.InOutQuad(0.5) -- Returns a value based on the easing curve
```

### Animation

#### `Animation.new(startValue, endValue, duration, easingFunc?, onUpdate?, onComplete?)`

Create a new Animation instance.

- **startValue** (number): Start value
- **endValue** (number): End value
- **duration** (number): Duration in seconds
- **easingFunc** (function\|string\|nil): Easing function or string name (default: linear)
- **onUpdate** (function\|nil): Callback `fun(value: number, progress: number)`
- **onComplete** (function\|nil): Callback `fun()`
- **Returns**: animation.Animation

```lua
local anim = require "init"
local Animation = anim.Animation

local myAnim = Animation.new(0, 100, 1, "InOutQuad", function(value)
    print(value)
end)
```

#### `Animation:start(time)`

Start the animation at the given time.

- **time** (number): Current time (e.g., `os.clock()`)
- **Returns**: self

#### `Animation:update(time)`

Update the animation with the current time. Calls `onUpdate` on each frame and `onComplete` when finished.

- **time** (number): Current time
- **Returns**: number (current interpolated value)

#### `Animation:isFinished()`

Check whether the animation has finished.

- **Returns**: boolean

#### `Animation:getValue()`

Get the current interpolated value.

- **Returns**: number

#### `Animation:setProgress(progress)`

Manually set the animation progress.

- **progress** (number): Progress in `[0, 1]`

### Animator

#### `Animator.new()`

Create a new Animator instance.

- **Returns**: animation.Animator

#### `Animator:add(animation)`

Add an animation to the animator.

- **animation** (animation.Animation): Animation to add
- **Returns**: animation.Animation

#### `Animator:remove(animation)`

Remove a specific animation.

- **animation** (animation.Animation): Animation to remove
- **Returns**: boolean (true if removed)

#### `Animator:update(time)`

Update all animations and automatically remove finished ones.

- **time** (number): Current time

#### `Animator:clear()`

Remove all animations.

#### `Animator:isEmpty()`

Check whether there are no active animations.

- **Returns**: boolean

#### `Animator:count()`

Get the number of active animations.

- **Returns**: integer

### Tween

A convenience API that uses a shared default animator.

#### `Tween.new(startValue, endValue, duration, easingFunc?, onUpdate?, onComplete?)`

Create a new Animation instance (does not start it).

- **Returns**: animation.Animation

#### `Tween.now(startValue, endValue, duration, easingFunc?, onUpdate?, onComplete?, time?)`

Create and immediately start an animation on the default animator.

- **time** (number\|nil): Optional start time (default: 0)
- **Returns**: animation.Animation

#### `Tween.update(time)`

Update all animations managed by the default animator.

- **time** (number): Current time

#### `Tween.clear()`

Remove all animations from the default animator.

#### `Tween.isIdle()`

Check whether the default animator has no active animations.

- **Returns**: boolean

#### `Tween.count()`

Get the number of active animations in the default animator.

- **Returns**: integer

## Examples

### Animate a UI Element

```lua
local anim = require "init"
local Tween = anim.Tween

local progress = 0

Tween.now(0, 1, 0.5, "InOutQuad", function(value, p)
    progress = value
    -- Update UI element width, opacity, etc.
end, function()
    print("Animation complete!")
end)

-- In your render loop:
Tween.update(os.clock())
```

### Sequential Animations

```lua
local anim = require "init"
local Tween = anim.Tween

-- First animation
Tween.now(0, 100, 1, "OutQuad", function(v)
    print("Step 1:", v)
end, function()
    -- Second animation starts after first completes
    Tween.now(100, 200, 1, "InQuad", function(v)
        print("Step 2:", v)
    end)
end)
```

### Multiple Concurrent Animations

```lua
local anim = require "init"
local Tween = anim.Tween

Tween.now(0, 100, 1, "OutQuad", function(v)
    print("X:", v)
end)

Tween.now(0, 50, 2, "InOutSine", function(v)
    print("Y:", v)
end)

-- In your loop:
Tween.update(os.clock())
print(Tween.count()) -- 2 active animations
```

## Notes

- All easing functions clamp input to `[0, 1]` and output eased values in the same range
- The `Back` and `Elastic` easing functions may produce values outside `[0, 1]` (overshoot/bounce)
- String-based easing names must match the function name exactly (e.g., `"InOutQuad"`)
- The tween module uses a single shared animator instance; call `Tween.update()` in your main loop
- Finished animations are automatically removed from the animator on the next `update()` call
- Use `setProgress()` for scrubbing or manual animation control without time-based updates

## License

MIT License
