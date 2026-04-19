# Rate Limiter

A simple and flexible rate-limiting library for Lua that supports multiple strategies: Fixed Window, Sliding Window Log,
Token Bucket, and Leaky Bucket.

## Features

- **Multiple Strategies**: Choose from four well-known rate limiting algorithms
- **Simple API**: Unified interface with `consume()` and `check()` methods
- **Custom Time Sources**: Support for testing and alternative clock implementations
- **Zero Dependencies**: Pure Lua implementation
- **Type-Safe**: Includes LuaDocs annotations for IDE support

## Installation

Copy the `rate_limiter.lua` file to your project:

```lua
local rate_limiter = require "rate_limiter"
```

## Usage

### Basic Usage

Create a rate limiter with a strategy and use it to control request rates:

```lua
-- Create a limiter: 10 requests per second using Fixed Window
local limiter = rate_limiter(rate_limiter.strategy.FixedWindow(10, 1))

-- Try to consume a request slot
if limiter:consume() then
    -- Request allowed - process it
    print("Request processed")
else
    -- Rate limited
    print("Rate limited - try again later")
end
```

### Strategies

#### Fixed Window

Simple counter that resets every X seconds. Easy to implement but can allow boundary bursts (2x limit at window
boundaries).

```lua
local FixedWindow = rate_limiter.strategy.FixedWindow
local limiter = rate_limiter(FixedWindow(10, 1)) -- 10 requests per second
```

**Pros**: Simple, low memory
**Cons**: Allows boundary bursts

#### Sliding Window Log

Precise log-based limiter that tracks individual request timestamps. Prevents boundary bursts by using a rolling window.

```lua
local SlidingWindow = rate_limiter.strategy.SlidingWindow
local limiter = rate_limiter(SlidingWindow(10, 1)) -- 10 requests per rolling second
```

**Pros**: Precise, no boundary bursts
**Cons**: Higher memory usage (stores timestamps)

#### Token Bucket

Allows for bursts up to capacity while maintaining an average rate. Tokens are added at a constant rate and consumed per
request.

```lua
local TokenBucket = rate_limiter.strategy.TokenBucket
local limiter = rate_limiter(TokenBucket(10, 20)) -- 10 tokens/sec, burst up to 20
```

**Pros**: Allows controlled bursts, smooths traffic
**Cons**: More complex logic

#### Leaky Bucket

Forces a perfectly steady processing rate by smoothing out bursts. Requests are processed at a constant rate with a
fixed queue capacity.

```lua
local LeakyBucket = rate_limiter.strategy.LeakyBucket
local limiter = rate_limiter(LeakyBucket(10, 5)) -- 10 requests/sec, queue up to 5
```

**Pros**: Steady rate, smooths bursts completely
**Cons**: Adds latency, drops requests when queue is full

### Custom Time Sources

For testing or alternative clock implementations, you can provide a custom time source:

```lua
local mock_time = 0
local function mock_clock()
    return mock_time
end

local limiter = rate_limiter(
    rate_limiter.strategy.FixedWindow(10, 1),
    mock_clock
)

-- Test by advancing time manually
mock_time = 0.5
print(limiter:consume()) -- true
mock_time = 0.6
print(limiter:consume()) -- true
```

### Check vs Consume

- `consume()`: Attempts to consume a request slot. Returns `true` if allowed, `false` if rate-limited. Modifies internal
  state.
- `check()`: Checks if a request would be allowed without consuming a slot. Returns `true` if allowed, `false` if
  rate-limited. Does not modify state.

```lua
-- Check if request would be allowed
if limiter:check() then
    -- Request would be allowed, but we haven't consumed it yet
    -- Useful for pre-flight checks
end

-- Actually consume the slot
if limiter:consume() then
    -- Process the request
end
```

## API Reference

### RateLimiter

Main wrapper class that provides a unified interface for rate limiting strategies.

#### `RateLimiter.new(strategy, time_source?)`

Creates a new RateLimiter instance.

- **strategy**: One of the strategy instances (FixedWindow, SlidingWindow, TokenBucket, LeakyBucket)
- **time_source** (optional): Function returning current time (default: `os.clock()`)

```lua
local limiter = rate_limiter.new(rate_limiter.strategy.FixedWindow(10, 1))
```

#### `limiter:consume()`

Attempt to consume a request slot using the configured strategy.

- **Returns**: `boolean` - `true` if request is allowed, `false` if rate-limited

```lua
if limiter:consume() then
    -- Process request
end
```

#### `limiter:check()`

Check if a request would be allowed without consuming a slot.

- **Returns**: `boolean` - `true` if request would be allowed, `false` if rate-limited

```lua
if limiter:check() then
    -- Request would be allowed
end
```

### Strategies

All strategies implement the `RateLimitStrategy` interface with `consume()` and `check()` methods.

#### FixedWindow

Simple counter that resets every window_size seconds.

- `FixedWindow.new(limit, window_size)`
    - **limit**: Max requests allowed per window
    - **window_size**: Duration of the window in seconds

#### SlidingWindow

Precise log-based limiter that tracks individual request timestamps.

- `SlidingWindow.new(limit, window_size)`
    - **limit**: Max requests allowed in the rolling window
    - **window_size**: Duration of the rolling window in seconds

#### TokenBucket

Allows for bursts up to capacity while maintaining an average rate.

- `TokenBucket.new(rate, capacity)`
    - **rate**: Tokens added per second
    - **capacity**: Max tokens the bucket can hold (burst size)

#### LeakyBucket

Forces a perfectly steady processing rate with a fixed queue capacity.

- `LeakyBucket.new(rate, capacity)`
    - **rate**: Processing rate (requests per second)
    - **capacity**: Max queue size before dropping requests

## Strategy Comparison

| Strategy       | Memory | Precision | Bursts     | Latency | Use Case              |
|----------------|--------|-----------|------------|---------|-----------------------|
| Fixed Window   | Low    | Low       | Yes (2x)   | None    | Simple rate limiting  |
| Sliding Window | Medium | High      | No         | None    | Precise rate limiting |
| Token Bucket   | Low    | Medium    | Controlled | None    | Traffic smoothing     |
| Leaky Bucket   | Low    | High      | None       | Yes     | Steady processing     |

## License

MIT License
