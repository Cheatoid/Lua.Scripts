-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Simple rate-limiting library supporting multiple strategies:
-- Fixed Window, Sliding Window Log, Token Bucket, and Leaky Bucket

-- Localized global functions for better performance
local setmetatable = setmetatable
local math_min = math.min
local os_clock = os.clock
local table_insert = table.insert
local table_remove = table.remove

----------------------------------------------------------------------
-- BASE STRATEGY INTERFACE
----------------------------------------------------------------------

--- Base interface for rate limiting strategies.<br>
--- All strategies must implement `consume` and `check` methods.
---@class RateLimitStrategy
---@field consume fun(self: RateLimitStrategy, now: number): boolean Consume a request slot/token.
---@field check fun(self: RateLimitStrategy, now: number): boolean Check if request would be allowed.

----------------------------------------------------------------------
-- FIXED WINDOW
----------------------------------------------------------------------

--- Fixed Window rate limiting strategy.<br>
--- Simple counter that resets every X seconds.
---@class FixedWindow : RateLimitStrategy
---@field limit number Max requests allowed per window.
---@field window_size number Duration of the window in seconds.
---@field count number Current request count.
---@field window_start number Timestamp when the current window started.
---@field __call fun(limit: number, window_size: number): FixedWindow Call constructor to create instance.
local FixedWindow = {}
FixedWindow.__index = FixedWindow

--- Create a new FixedWindow instance.<br>
--- Resets the counter every window_size seconds.
---@param limit number Max requests allowed per window.
---@param window_size number Duration of the window in seconds.
---@return FixedWindow instance New FixedWindow instance.
---@usage <br>
--- ```
--- local limiter = FixedWindow.new(10, 1) -- 10 requests per second
--- ```
function FixedWindow.new(limit, window_size)
	return setmetatable({
		limit = limit,
		window_size = window_size,
		count = 0,
		window_start = 0,
	}, FixedWindow)
end

FixedWindow.__call = FixedWindow.new

--- Attempt to consume a request slot.<br>
--- Returns true if the request is allowed, false if the limit has been exceeded.<br>
--- Resets the counter if the window has expired.
---@param self FixedWindow The FixedWindow instance.
---@param now number Current timestamp (from os.clock or custom time source).
---@return boolean allowed True if request is allowed, false if rate-limited.
function FixedWindow.consume(self, now)
	if now - self.window_start >= self.window_size then
		self.window_start = now
		self.count = 0
	end
	if self.count < self.limit then
		self.count = self.count + 1
		return true
	end
	return false
end

--- Check if a request would be allowed without consuming a slot.<br>
--- Returns true if the request would be allowed, false if the limit has been exceeded.<br>
--- Does not modify the internal state.
---@param self FixedWindow The FixedWindow instance.
---@param now number Current timestamp (from os.clock or custom time source).
---@return boolean allowed True if request would be allowed, false if rate-limited.
function FixedWindow.check(self, now)
	if now - self.window_start >= self.window_size then
		return 0 < self.limit
	end
	return self.count < self.limit
end

----------------------------------------------------------------------
-- SLIDING WINDOW LOG
----------------------------------------------------------------------

--- Sliding Window Log rate limiting strategy.<br>
--- Precise log-based limiter that prevents boundary bursts by tracking individual request timestamps.
---@class SlidingWindow : RateLimitStrategy
---@field limit number Max requests allowed in the rolling window.
---@field window_size number The duration of the rolling window in seconds.
---@field timestamps number[] Array of request timestamps.
---@field __call fun(limit: number, window_size: number): SlidingWindow Call constructor to create instance.
local SlidingWindow = {}
SlidingWindow.__index = SlidingWindow

--- Create a new SlidingWindow instance.<br>
--- Tracks individual request timestamps for precise rate limiting.<br>
--- Prevents boundary bursts that can occur with fixed window.
---@param limit number Max requests allowed in the rolling window.
---@param window_size number The duration of the rolling window in seconds.
---@return SlidingWindow instance New SlidingWindow instance.
---@usage <br>
--- ```
--- local limiter = SlidingWindow.new(10, 1) -- 10 requests per rolling second
--- ```
function SlidingWindow.new(limit, window_size)
	return setmetatable({
		limit = limit,
		window_size = window_size,
		timestamps = {},
	}, SlidingWindow)
end

SlidingWindow.__call = SlidingWindow.new

--- Attempt to consume a request slot.<br>
--- Returns true if the request is allowed, false if the limit has been exceeded.<br>
--- Removes expired timestamps from the log before checking the limit.
---@param self SlidingWindow The SlidingWindow instance.
---@param now number Current timestamp (from os.clock or custom time source).
---@return boolean allowed True if request is allowed, false if rate-limited.
function SlidingWindow.consume(self, now)
	local threshold = now - self.window_size
	local ts = self.timestamps
	-- Remove expired timestamps from the head of the log
	while #ts > 0 and ts[1] <= threshold do
		table_remove(ts, 1)
	end
	if #ts < self.limit then
		table_insert(ts, now)
		return true
	end
	return false
end

--- Check if a request would be allowed without consuming a slot.<br>
--- Returns true if the request would be allowed, false if the limit has been exceeded.<br>
--- Does not modify the internal state.
---@param self SlidingWindow The SlidingWindow instance.
---@param now number Current timestamp (from os.clock or custom time source).
---@return boolean allowed True if request would be allowed, false if rate-limited.
function SlidingWindow.check(self, now)
	local threshold = now - self.window_size
	local ts = self.timestamps
	-- Count non-expired timestamps
	local count = 0
	for i = 1, #ts do
		if ts[i] > threshold then
			count = count + 1
		end
	end
	return count < self.limit
end

----------------------------------------------------------------------
-- TOKEN BUCKET
----------------------------------------------------------------------

--- Token Bucket rate limiting strategy.<br>
--- Allows for bursts up to capacity while maintaining an average rate.<br>
--- Tokens are added at a constant rate and consumed per request.
---@class TokenBucket : RateLimitStrategy
---@field rate number Tokens added per second.
---@field capacity number Max tokens the bucket can hold (burst size).
---@field tokens number Current token count.
---@field last_update number Timestamp of the last token refill.
---@field __call fun(rate: number, capacity: number): TokenBucket Call constructor to create instance.
local TokenBucket = {}
TokenBucket.__index = TokenBucket

--- Create a new TokenBucket instance.<br>
--- Tokens are added at the specified rate and consumed per request.<br>
--- Allows bursts up to capacity.
---@param rate number Tokens added per second.
---@param capacity number Max tokens the bucket can hold (burst size).
---@return TokenBucket instance New TokenBucket instance.
---@usage <br>
--- ```
--- local limiter = TokenBucket.new(10, 20) -- 10 tokens/sec, burst up to 20
--- ```
function TokenBucket.new(rate, capacity)
	return setmetatable({
		rate = rate,
		capacity = capacity,
		tokens = capacity,
		last_update = 0,
	}, TokenBucket)
end

TokenBucket.__call = TokenBucket.new

--- Attempt to consume a request slot (token).<br>
--- Returns true if the request is allowed, false if no tokens are available.<br>
--- Refills tokens based on elapsed time before checking availability.
---@param self TokenBucket The TokenBucket instance.
---@param now number Current timestamp (from os.clock or custom time source).
---@return boolean allowed True if request is allowed, false if rate-limited.
function TokenBucket.consume(self, now)
	local elapsed = now - self.last_update
	-- Refill bucket based on time passed
	self.tokens = math_min(self.capacity, self.tokens + (elapsed * self.rate))
	self.last_update = now
	if self.tokens >= 1 then
		self.tokens = self.tokens - 1
		return true
	end
	return false
end

--- Check if a request would be allowed without consuming a token.<br>
--- Returns true if a token would be available, false if rate-limited.<br>
--- Does not modify the internal state.
---@param self TokenBucket The TokenBucket instance.
---@param now number Current timestamp (from os.clock or custom time source).
---@return boolean allowed True if request would be allowed, false if rate-limited.
function TokenBucket.check(self, now)
	local elapsed = now - self.last_update
	-- Calculate potential tokens without modifying state
	local potential_tokens = math_min(self.capacity, self.tokens + (elapsed * self.rate))
	return potential_tokens >= 1
end

----------------------------------------------------------------------
-- LEAKY BUCKET
----------------------------------------------------------------------

--- Leaky Bucket rate limiting strategy.<br>
--- Forces a perfectly steady processing rate (smooths out bursts).<br>
--- Requests are processed at a constant rate with a fixed queue capacity.
---@class LeakyBucket : RateLimitStrategy
---@field leak_interval number Time between processing slots (1 / rate).
---@field capacity number Max queue size before dropping requests.
---@field next_free_time number Timestamp when the next processing slot is available.
---@field __call fun(rate: number, capacity: number): LeakyBucket Call constructor to create instance.
local LeakyBucket = {}
LeakyBucket.__index = LeakyBucket

--- Create a new LeakyBucket instance.<br>
--- Processes requests at a constant rate with a fixed queue capacity.<br>
--- Smooths out bursts by enforcing a steady processing rate.
---@param rate number Processing rate (requests per second).
---@param capacity number Max queue size before dropping requests.
---@return LeakyBucket instance New LeakyBucket instance.
---@usage <br>
--- ```
--- local limiter = LeakyBucket.new(10, 5) -- 10 requests/sec, queue up to 5
--- ```
function LeakyBucket.new(rate, capacity)
	return setmetatable({
		leak_interval = 1 / rate,
		capacity = capacity,
		next_free_time = 0,
	}, LeakyBucket)
end

LeakyBucket.__call = LeakyBucket.new

--- Attempt to consume a request slot.<br>
--- Returns true if the request is allowed, false if the queue is at capacity.<br>
--- Calculates wait time based on current queue state.
---@param self LeakyBucket The LeakyBucket instance.
---@param now number Current timestamp (from os.clock or custom time source).
---@return boolean allowed True if request is allowed, false if rate-limited.
function LeakyBucket.consume(self, now)
	-- Reset if the bucket has been idle
	if now > self.next_free_time then
		self.next_free_time = now
	end
	-- Calculate how many "slots" are currently occupied
	local wait_time = self.next_free_time - now
	local current_fill = wait_time / self.leak_interval
	if current_fill < self.capacity then
		self.next_free_time = self.next_free_time + self.leak_interval
		return true
	end
	return false
end

--- Check if a request would be allowed without consuming a slot.<br>
--- Returns true if the request would be allowed, false if the queue is at capacity.<br>
--- Does not modify the internal state.
---@param self LeakyBucket The LeakyBucket instance.
---@param now number Current timestamp (from os.clock or custom time source).
---@return boolean allowed True if request would be allowed, false if rate-limited.
function LeakyBucket.check(self, now)
	-- Calculate effective next_free_time without modifying state
	local effective_next_free = self.next_free_time
	if now > effective_next_free then
		effective_next_free = now
	end
	-- Calculate how many "slots" are currently occupied
	local wait_time = effective_next_free - now
	local current_fill = wait_time / self.leak_interval
	return current_fill < self.capacity
end

----------------------------------------------------------------------
-- MAIN RATE-LIMITER CLASS
----------------------------------------------------------------------

--- Rate Limiter wrapper class for using different strategies.<br>
--- Provides a unified interface for rate limiting with pluggable strategies.<br>
--- Supports custom time sources for testing or alternative clocks.
---@class RateLimiter
---@field strategy RateLimitStrategy The rate limiting strategy instance.
---@field time_source function Function returning current time.
---@field __call fun(strategy: RateLimitStrategy, time_source?: fun(): number): RateLimiter Call constructor to create instance.
local RateLimiter = {}
RateLimiter.__index = RateLimiter

--- Create a new RateLimiter instance.<br>
--- Wraps a strategy instance with a unified interface.<br>
--- Allows custom time sources for testing or alternative clocks.
---@param strategy RateLimitStrategy One of the strategy instances.
---@param time_source? fun(): number Optional function returning current time (default: `os.clock`).
---@return RateLimiter instance New RateLimiter instance.
---@usage <br>
--- ```
--- local limiter = RateLimiter.new(FixedWindow.new(10, 1))
--- if limiter:consume() then
---   -- Process request
--- end
--- ```
function RateLimiter.new(strategy, time_source)
	return setmetatable({
		strategy = strategy,
		time_source = time_source or os_clock,
	}, RateLimiter)
end

RateLimiter.__call = RateLimiter.new

--- Attempt to consume a request slot using the configured strategy.<br>
--- Returns true if the request is allowed, false if rate-limited.<br>
--- Delegates to the underlying strategy's consume method.
---@return boolean allowed True if request is allowed, false if rate-limited.
---@usage <br>
--- ```
--- if limiter:consume() then
---   -- Process request
--- else
---   -- Rate limited
--- end
--- ```
function RateLimiter.consume(self)
	-- Get current time from the injected source and pass to strategy
	return self.strategy.consume(self.strategy, self.time_source())
end

--- Check if a request would be allowed without consuming a slot.<br>
--- Returns true if the request would be allowed, false if rate-limited.<br>
--- Delegates to the underlying strategy's check method.
---@return boolean allowed True if request would be allowed, false if rate-limited.
---@usage <br>
--- ```
--- if limiter:check() then
---   -- Request would be allowed
--- else
---   -- Would be rate limited
--- end
--- ```
function RateLimiter.check(self)
	-- Get current time from the injected source and pass to strategy
	return self.strategy.check(self.strategy, self.time_source())
end

--- Export rate limiter module with strategies.<br>
--- Provides a unified RateLimiter wrapper and individual strategy classes.<br>
--- Strategies can be used directly or wrapped by RateLimiter.
---@class RateLimiterModule
---@field new fun(strategy: RateLimitStrategy, time_source?: fun(): number): RateLimiter Creates a new RateLimiter instance.
---@field __call fun(strategy: RateLimitStrategy, time_source?: fun(): number): RateLimiter Call constructor to create instance.
---@field strategy RateLimitStrategy[] Table containing all strategy classes implementing RateLimitStrategy.
return setmetatable({
	new = RateLimiter.new,
	strategy = {
		FixedWindow = FixedWindow,
		SlidingWindow = SlidingWindow,
		TokenBucket = TokenBucket,
		LeakyBucket = LeakyBucket,
	}
}, {
	__call = function(_, ...) return RateLimiter.new(...) end,
})
