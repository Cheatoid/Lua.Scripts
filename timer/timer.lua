-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Timer library.
-- Supply a time function and pump timers by calling `tick`/`update` from your tick/update loop.

-- Localized global functions for better performance
local assert = assert
local error = error
local pairs = pairs
local pcall = pcall
local select = select
local setmetatable = setmetatable
local type = type
local os_clock = os.clock
local table_unpack = table.unpack or unpack

---@alias TimerTimeSource fun(): number Function returning current time in seconds.
---@alias TimerCallback fun(...: any) Function invoked when a timer fires.
---@alias TimerStatus "running"|"paused"|"stopped"|"finished"|"removed" Lifecycle status of a timer.
---@alias TimerID string|number Named timer identifier (`simple` generates one).

---@class Timer
---@field _manager TimerManager Owning manager (time source + registry).
---@field _id TimerID Timer identifier.
---@field _delay number Seconds between fires (>= 0). `0` fires every tick.
---@field _repetitions integer Total fires (`0` = infinite).
---@field _callback TimerCallback Function invoked on fire.
---@field _args table Packed callback arguments (`{ n = ... }`).
---@field _status TimerStatus Current lifecycle status.
---@field _reps_left integer Fires remaining (`0` = infinite or exhausted).
---@field _next_fire? number Absolute time of next fire (only when running).
---@field _remaining? number Seconds left frozen while paused.
---@field _auto_remove boolean Remove from manager when repetitions are exhausted.
local Timer = {}
Timer.__index = Timer

---@class TimerOptions
---@field delay? number Seconds between fires (>= 0).
---@field repetitions? integer Total fires (`0` = infinite).
---@field reps? integer Alias of `repetitions`.
---@field fn? TimerCallback Alias of `callback`.
---@field callback? TimerCallback Function invoked on fire.
---@field args? table Array of callback arguments.
---@field autostart? boolean Start immediately (default: true).
---@field auto_remove? boolean Remove when exhausted (default: false, `simple` forces true).

local function normalize_create_args(delay, repetitions, fn, ...)
	local autostart = true
	local auto_remove_override, args

	if type(delay) == "table" then
		local opts = delay
		delay = opts.delay or 0
		repetitions = opts.repetitions
		if repetitions == nil then
			repetitions = opts.reps
		end
		if repetitions == nil then
			repetitions = 1
		end
		fn = opts.fn or opts.callback
		autostart = opts.autostart
		if autostart == nil then
			autostart = true
		end
		if opts.auto_remove ~= nil then
			auto_remove_override = opts.auto_remove
		else
			auto_remove_override = opts.autoRemove
		end
		if opts.args ~= nil then
			assert(type(opts.args) == "table", "args must be an array table")
			args = { n = #opts.args }
			for i = 1, #opts.args do
				args[i] = opts.args[i]
			end
		else
			args = { n = 0 }
		end
	else
		local n = select("#", ...)
		if n > 0 then
			args = { n = n, ... }
		else
			args = { n = 0 }
		end
	end

	return delay, repetitions, fn, args, autostart, auto_remove_override
end

--- Validate core timer fields. Errors on misuse (fail fast).
---@param id TimerID Identifier.
---@param delay number Delay in seconds.
---@param repetitions integer Repetition count.
---@param fn TimerCallback Callback.
local function assert_valid(id, delay, repetitions, fn)
	assert(id ~= nil, "timer id cannot be nil")
	assert(type(delay) == "number" and delay >= 0, "delay must be a number >= 0")
	assert(type(repetitions) == "number" and repetitions >= 0 and repetitions % 1 == 0,
		"repetitions must be an integer >= 0 (0 = infinite)")
	assert(type(fn) == "function", "callback must be a function")
end

--- Create a Timer object bound to a manager (use `manager:create` to register).
---@param manager TimerManager Owning manager.
---@param id TimerID Identifier.
---@param delay number Seconds between fires.
---@param repetitions integer Total fires (`0` = infinite).
---@param fn TimerCallback Callback.
---@param ... any Callback arguments.
---@return Timer timer New (unregistered) timer. Call `:start()` or register via manager.
---@usage <br>
---@usage ```
---@usage local t = Timer.new(manager, "hi", 1, 0, print, "tick")
---@usage ```
function Timer.new(manager, id, delay, repetitions, fn, ...)
	assert(manager ~= nil, "manager cannot be nil")
	local ndelay, nreps, nfn, nargs = normalize_create_args(delay, repetitions, fn, ...)
	assert_valid(id, ndelay, nreps, nfn)
	return setmetatable({
		_manager = manager,
		_id = id,
		_delay = ndelay,
		_repetitions = nreps,
		_callback = nfn,
		_args = nargs,
		_status = "stopped",
		_reps_left = nreps,
		_next_fire = nil,
		_remaining = nil,
		_auto_remove = false,
	}, Timer)
end

Timer.__call = Timer.new

--- Start (or restart) the timer from a full delay.<br>
--- Resets `_reps_left` when the previous run was exhausted.
---@param self Timer The timer.
---@return Timer self Self for chaining.
---@usage <br>
---@usage ```
---@usage t:start()
---@usage ```
function Timer.start(self)
	local now = self._manager:now()
	if self._status == "removed" then
		return error("cannot start a removed timer", 2)
	end
	if self._repetitions > 0 and self._reps_left <= 0 then
		self._reps_left = self._repetitions
	end
	self._status = "running"
	self._remaining = nil
	self._next_fire = now + self._delay
	return self
end

--- Stop the timer without removing it.<br>
--- Keeps `_reps_left`; use `start` to re-arm.
---@param self Timer The timer.
---@return Timer self Self for chaining.
function Timer.stop(self)
	if self._status == "removed" then
		return self
	end
	self._status = "stopped"
	self._next_fire = nil
	self._remaining = nil
	return self
end

--- Pause a running timer, freezing its remaining time.
---@param self Timer The timer.
---@return Timer self Self for chaining.
function Timer.pause(self)
	if self._status ~= "running" then
		return self
	end
	local now = self._manager:now()
	local left = self._next_fire - now
	if left < 0 then
		left = 0
	end
	self._remaining = left
	self._status = "paused"
	self._next_fire = nil
	return self
end

--- Resume a paused timer from its frozen remaining time.
---@param self Timer The timer.
---@return Timer self Self for chaining.
function Timer.resume(self)
	if self._status ~= "paused" then
		return self
	end
	local now = self._manager:now()
	self._status = "running"
	self._next_fire = now + (self._remaining or self._delay)
	self._remaining = nil
	return self
end

Timer.unpause = Timer.resume

--- Toggle pause state: running -> paused, paused -> resumed, stopped/finished -> started.
---@param self Timer The timer.
---@return Timer self Self for chaining.
function Timer.toggle(self)
	if self._status == "running" then
		return self:pause()
	end
	if self._status == "paused" then
		return self:resume()
	end
	return self:start()
end

--- Restart the timer (alias of `start`).
---@param self Timer The timer.
---@return Timer self Self for chaining.
function Timer.restart(self)
	return self:start()
end

--- Remove the timer from its manager.
---@param self Timer The timer.
---@return boolean removed True if it was registered.
function Timer.remove(self)
	return self._manager:remove(self._id)
end

Timer.destroy = Timer.remove

--- Adjust delay / repetitions / callback in place.<br>
--- Keeps current status; when running, re-arms `_next_fire` from now.
---@param self Timer The timer.
---@param delay? number New delay (`nil` = keep).
---@param repetitions? integer New total fires (`nil` = keep, `0` = infinite).
---@param fn? TimerCallback New callback (`nil` = keep).
---@param ... any New callback arguments.
---@return Timer self Self for chaining.
---@usage <br>
---@usage ```
---@usage t:adjust(0.5, 10) -- faster, 10 total fires
---@usage ```
function Timer.adjust(self, delay, repetitions, fn, ...)
	if delay ~= nil then
		assert(type(delay) == "number" and delay >= 0, "delay must be a number >= 0")
		self._delay = delay
	end
	if repetitions ~= nil then
		assert(type(repetitions) == "number" and repetitions >= 0 and repetitions % 1 == 0,
			"repetitions must be an integer >= 0 (0 = infinite)")
		self._repetitions = repetitions
		self._reps_left = repetitions
	end
	if fn ~= nil then
		assert(type(fn) == "function", "callback must be a function")
		self._callback = fn
	end
	local n = select("#", ...)
	if n > 0 then
		self._args = { n = n, ... }
	elseif fn ~= nil then
		self._args = { n = 0 }
	end
	if self._status == "running" then
		self._next_fire = self._manager:now() + self._delay
		self._remaining = nil
	elseif self._status == "paused" then
		self._remaining = self._delay
	end
	return self
end

--- Set a new delay (re-arms when running/paused).
---@param self Timer The timer.
---@param delay number New delay.
---@return Timer self Self for chaining.
function Timer.set_delay(self, delay)
	return self:adjust(delay)
end

--- Set new total repetitions and reset `_reps_left`.
---@param self Timer The timer.
---@param repetitions integer New total (`0` = infinite).
---@return Timer self Self for chaining.
function Timer.set_repetitions(self, repetitions)
	return self:adjust(nil, repetitions)
end

--- Set a new callback (optionally with new arguments).
---@param self Timer The timer.
---@param fn TimerCallback New callback.
---@param ... any New callback arguments.
---@return Timer self Self for chaining.
function Timer.set_callback(self, fn, ...)
	return self:adjust(nil, nil, fn, ...)
end

--- Seconds until next fire (`0` when stopped/finished, frozen value when paused).
---@param self Timer The timer.
---@return number left Seconds remaining.
function Timer.time_left(self)
	if self._status == "paused" then
		return self._remaining or 0
	end
	if self._status ~= "running" or self._next_fire == nil then
		return 0
	end
	local left = self._next_fire - self._manager:now()
	if left < 0 then
		left = 0
	end
	return left
end

--- Fires remaining (`0` = infinite or exhausted).
---@param self Timer The timer.
---@return integer left Remaining fires.
function Timer.reps_left(self)
	return self._reps_left
end

--- Elapsed time since the current interval started.
---@param self Timer The timer.
---@return number elapsed Seconds elapsed in current interval.
function Timer.elapsed(self)
	if self._status == "paused" then
		return self._delay - (self._remaining or 0)
	end
	if self._status ~= "running" or self._next_fire == nil then
		return 0
	end
	local elapsed = self._delay - (self._next_fire - self._manager:now())
	if elapsed < 0 then
		elapsed = 0
	end
	if elapsed > self._delay then
		elapsed = self._delay
	end
	return elapsed
end

---@param self Timer The timer.
---@return TimerID id Identifier.
function Timer.get_id(self)
	return self._id
end

---@param self Timer The timer.
---@return number delay Delay between fires.
function Timer.get_delay(self)
	return self._delay
end

---@param self Timer The timer.
---@return integer repetitions Total repetitions (`0` = infinite).
function Timer.get_repetitions(self)
	return self._repetitions
end

---@param self Timer The timer.
---@return TimerStatus status Current status.
function Timer.get_status(self)
	return self._status
end

---@param self Timer The timer.
---@return boolean running True when ticking.
function Timer.is_running(self)
	return self._status == "running"
end

---@param self Timer The timer.
---@return boolean paused True when paused.
function Timer.is_paused(self)
	return self._status == "paused"
end

---@param self Timer The timer.
---@return boolean stopped True when stopped.
function Timer.is_stopped(self)
	return self._status == "stopped"
end

---@param self Timer The timer.
---@return boolean finished True when repetitions exhausted (and kept, not auto-removed).
function Timer.is_finished(self)
	return self._status == "finished"
end

-- PascalCase aliases (delegate to snake_case).
Timer.Start = Timer.start
Timer.Stop = Timer.stop
Timer.Pause = Timer.pause
Timer.Resume = Timer.resume
Timer.UnPause = Timer.resume
Timer.Toggle = Timer.toggle
Timer.Restart = Timer.restart
Timer.Remove = Timer.remove
Timer.Destroy = Timer.remove
Timer.Adjust = Timer.adjust
Timer.SetDelay = Timer.set_delay
Timer.SetRepetitions = Timer.set_repetitions
Timer.SetCallback = Timer.set_callback
Timer.TimeLeft = Timer.time_left
Timer.RepsLeft = Timer.reps_left
Timer.Elapsed = Timer.elapsed
Timer.GetId = Timer.get_id
Timer.GetDelay = Timer.get_delay
Timer.GetRepetitions = Timer.get_repetitions
Timer.GetStatus = Timer.get_status
Timer.IsRunning = Timer.is_running
Timer.IsPaused = Timer.is_paused
Timer.IsStopped = Timer.is_stopped
Timer.IsFinished = Timer.is_finished

----------------------------------------------------------------------
-- MANAGER
----------------------------------------------------------------------

---@class TimerManager
---@field _timers table<TimerID, Timer> Registry of active timers.
---@field _time_source TimerTimeSource Clock returning seconds.
---@field _on_error? fun(err: any, timer: Timer) Optional error sink for callbacks.
---@field _simple_seq integer Sequence for anonymous `simple` ids.
local Manager = {}
Manager.__index = Manager

--- Create a new independent timer registry.<br>
--- Pass a custom clock for tests or engine time (`CurTime`, `os.clock`, ...).
---@param time_source? TimerTimeSource Clock returning seconds (default: `os.clock`).
---@return TimerManager manager New manager.
---@usage <br>
---@usage ```
---@usage local tm = timer.new(os.clock)
---@usage tm:create("hi", 1, 0, print, "tick")
---@usage ```
function Manager.new(time_source)
	if time_source ~= nil then
		assert(type(time_source) == "function", "time_source must be a function")
	end
	return setmetatable({
		_timers = {},
		_time_source = time_source or os_clock,
		_on_error = nil,
		_simple_seq = 0,
	}, Manager)
end

Manager.__call = Manager.new

--- Replace the clock function (e.g. `CurTime`, mock time in tests).
---@param self TimerManager The manager.
---@param fn TimerTimeSource Clock returning seconds.
---@return TimerManager self Self for chaining.
function Manager.set_time_source(self, fn)
	assert(type(fn) == "function", "time_source must be a function")
	self._time_source = fn
	return self
end

Manager.set_time_function = Manager.set_time_source

--- Get the current clock function.
---@param self TimerManager The manager.
---@return TimerTimeSource fn Clock function.
function Manager.get_time_source(self)
	return self._time_source
end

Manager.get_time_function = Manager.get_time_source

--- Current time according to this manager's clock.
---@param self TimerManager The manager.
---@return number now Seconds.
function Manager.now(self)
	return self._time_source()
end

--- Set an error sink for timer callbacks.<br>
--- When set, callback errors are routed here and other timers still fire.
--- When nil (default), callback errors propagate (fail fast).
---@param self TimerManager The manager.
---@param fn? fun(err: any, timer: Timer) Error sink, or nil to propagate.
---@return TimerManager self Self for chaining.
function Manager.set_error_handler(self, fn)
	if fn ~= nil then
		assert(type(fn) == "function", "error handler must be a function or nil")
	end
	self._on_error = fn
	return self
end

--- Invoke one timer callback, honoring the manager error policy.
---@param self TimerManager The manager.
---@param t Timer Timer being fired.
local function invoke(self, t)
	local cb = t._callback
	local args = t._args
	local n = (args and args.n) or 0
	if self._on_error ~= nil then
		local ok, err
		if n > 0 then
			ok, err = pcall(cb, table_unpack(args, 1, n))
		else
			ok, err = pcall(cb)
		end
		if not ok then
			self._on_error(err, t)
		end
	else
		if n > 0 then
			cb(table_unpack(args, 1, n))
		else
			cb()
		end
	end
end

--- Create (or replace) a named timer.<br>
--- Existing timer with the same id is replaced. Autostarts by default.
---@param self TimerManager The manager.
---@param id TimerID Identifier.
---@param delay number|TimerOptions Delay or options table.
---@param repetitions? integer Total fires (`0` = infinite).
---@param fn? TimerCallback Callback.
---@param ... any Callback arguments.
---@return Timer timer The created timer.
---@usage <br>
---@usage ```
---@usage manager:create("respawn", 5, 1, spawn_player, ply)
---@usage manager:create("blink", { delay = 0.5, repetitions = 0, callback = toggle })
---@usage ```
function Manager.create(self, id, delay, repetitions, fn, ...)
	assert(id ~= nil, "timer id cannot be nil")
	local ndelay, nreps, nfn, nargs, autostart, auto_remove_override =
			normalize_create_args(delay, repetitions, fn, ...)
	assert_valid(id, ndelay, nreps, nfn)
	local old = self._timers[id]
	if old ~= nil then
		old._status = "removed"
		old._next_fire = nil
		old._remaining = nil
		self._timers[id] = nil
	end
	local t = setmetatable({
		_manager = self,
		_id = id,
		_delay = ndelay,
		_repetitions = nreps,
		_callback = nfn,
		_args = nargs,
		_status = "stopped",
		_reps_left = nreps,
		_next_fire = nil,
		_remaining = nil,
		_auto_remove = auto_remove_override or false,
	}, Timer)
	self._timers[id] = t
	if autostart then
		t:start()
	end
	return t
end

--- Create a one-shot anonymous timer.
---@param self TimerManager The manager.
---@param delay number Seconds until fire.
---@param fn TimerCallback Callback.
---@param ... any Callback arguments.
---@return Timer timer The created timer (auto-removed after firing).
---@usage <br>
---@usage ```
---@usage manager:simple(1.5, notify, ply, "hi")
---@usage ```
function Manager.simple(self, delay, fn, ...)
	assert(type(delay) == "number" and delay >= 0, "delay must be a number >= 0")
	assert(type(fn) == "function", "callback must be a function")
	self._simple_seq = self._simple_seq + 1
	local id = "__simple_" .. self._simple_seq
	local n = select("#", ...)
	local args
	if n > 0 then
		args = { n = n, ... }
	else
		args = { n = 0 }
	end
	local t = setmetatable({
		_manager = self,
		_id = id,
		_delay = delay,
		_repetitions = 1,
		_callback = fn,
		_args = args,
		_status = "stopped",
		_reps_left = 1,
		_next_fire = nil,
		_remaining = nil,
		_auto_remove = true,
	}, Timer)
	self._timers[id] = t
	t:start()
	return t
end

--- Get a timer by id (nil when missing).
---@param self TimerManager The manager.
---@param id TimerID Identifier.
---@return Timer? timer Timer, or nil.
function Manager.get(self, id)
	return self._timers[id]
end

--- Check existence.
---@param self TimerManager The manager.
---@param id TimerID Identifier.
---@return boolean exists True when registered.
function Manager.exists(self, id)
	return self._timers[id] ~= nil
end

--- Remove a timer. Safe when missing.
---@param self TimerManager The manager.
---@param id TimerID Identifier.
---@return boolean removed True when something was removed.
function Manager.remove(self, id)
	local t = self._timers[id]
	if t == nil then
		return false
	end
	self._timers[id] = nil
	t._status = "removed"
	t._next_fire = nil
	t._remaining = nil
	return true
end

--- Remove every timer.
---@param self TimerManager The manager.
---@return TimerManager self Self for chaining.
function Manager.remove_all(self)
	for id, t in pairs(self._timers) do
		self._timers[id] = nil
		t._status = "removed"
		t._next_fire = nil
		t._remaining = nil
	end
	return self
end

Manager.clear = Manager.remove_all

--- Number of registered timers.
---@param self TimerManager The manager.
---@return integer count Count.
function Manager.count(self)
	local n = 0
	for _ in pairs(self._timers) do
		n = n + 1
	end
	return n
end

--- List registered timer ids.
---@param self TimerManager The manager.
---@return TimerID[] ids Array of ids.
function Manager.list(self)
	local out = {}
	for id in pairs(self._timers) do
		out[#out + 1] = id
	end
	return out
end

--- Start (or restart) a timer by id.
---@param self TimerManager The manager.
---@param id TimerID Identifier.
---@return boolean ok False when missing.
function Manager.start(self, id)
	local t = self._timers[id]
	if t == nil then
		return false
	end
	t:start()
	return true
end

--- Stop a timer by id (kept, not removed).
---@param self TimerManager The manager.
---@param id TimerID Identifier.
---@return boolean ok False when missing.
function Manager.stop(self, id)
	local t = self._timers[id]
	if t == nil then
		return false
	end
	t:stop()
	return true
end

--- Pause a timer by id.
---@param self TimerManager The manager.
---@param id TimerID Identifier.
---@return boolean ok False when missing.
function Manager.pause(self, id)
	local t = self._timers[id]
	if t == nil then
		return false
	end
	t:pause()
	return true
end

--- Resume a paused timer by identifier.
---@param self TimerManager The manager.
---@param id TimerID Identifier.
---@return boolean ok False when missing.
function Manager.unpause(self, id)
	local t = self._timers[id]
	if t == nil then
		return false
	end
	t:resume()
	return true
end

Manager.resume = Manager.unpause

--- Toggle a timer by id (running -> paused, paused -> resumed, else started).
---@param self TimerManager The manager.
---@param id TimerID Identifier.
---@return boolean ok False when missing.
function Manager.toggle(self, id)
	local t = self._timers[id]
	if t == nil then
		return false
	end
	t:toggle()
	return true
end

--- Adjust a timer by identifier.
---@param self TimerManager The manager.
---@param id TimerID Identifier.
---@param delay? number New delay (`nil` = keep).
---@param repetitions? integer New total (`nil` = keep).
---@param fn? TimerCallback New callback (`nil` = keep).
---@param ... any New callback arguments.
---@return boolean ok False when missing.
function Manager.adjust(self, id, delay, repetitions, fn, ...)
	local t = self._timers[id]
	if t == nil then
		return false
	end
	t:adjust(delay, repetitions, fn, ...)
	return true
end

--- Seconds until next fire, or nil when missing.
---@param self TimerManager The manager.
---@param id TimerID Identifier.
---@return number? left Seconds remaining.
function Manager.time_left(self, id)
	local t = self._timers[id]
	if t == nil then
		return nil
	end
	return t:time_left()
end

--- Fires remaining, or nil when missing. `0` = infinite/exhausted.
---@param self TimerManager The manager.
---@param id TimerID Identifier.
---@return integer? left Remaining fires.
function Manager.reps_left(self, id)
	local t = self._timers[id]
	if t == nil then
		return nil
	end
	return t:reps_left()
end

--- Pause every running timer.
---@param self TimerManager The manager.
---@return TimerManager self Self for chaining.
function Manager.pause_all(self)
	for _, t in pairs(self._timers) do
		t:pause()
	end
	return self
end

--- Resume every paused timer.
---@param self TimerManager The manager.
---@return TimerManager self Self for chaining.
function Manager.resume_all(self)
	for _, t in pairs(self._timers) do
		t:resume()
	end
	return self
end

Manager.unpause_all = Manager.resume_all

--- Stop every timer (kept, not removed).
---@param self TimerManager The manager.
---@return TimerManager self Self for chaining.
function Manager.stop_all(self)
	for _, t in pairs(self._timers) do
		t:stop()
	end
	return self
end

--- Advance all due timers. Call this from your engine tick/update.<br>
--- Fires at most once per timer per call; hitches snap forward instead of bursting.
---@param self TimerManager The manager.
---@param now? number Absolute time (default: `time_source()`). Pass your engine time here.
---@return integer fired Number of callbacks fired.
---@usage <br>
---@usage ```
---@usage -- nanos-world: Server.Subscribe("Tick", function() manager:tick() end)
---@usage -- plain loop: manager:tick(mock_time)
---@usage ```
function Manager.tick(self, now)
	if now == nil then
		now = self._time_source()
	end
	local ids = {}
	for id in pairs(self._timers) do
		ids[#ids + 1] = id
	end
	local fired = 0
	for i = 1, #ids do
		local t = self._timers[ids[i]]
		if t ~= nil and t._status == "running" and t._next_fire ~= nil and now >= t._next_fire then
			local old_next = t._next_fire
			if t._repetitions > 0 then
				t._reps_left = t._reps_left - 1
			end
			fired = fired + 1
			invoke(self, t)
			-- Timer may have been removed or re-armed inside its own callback.
			if self._timers[t._id] == nil or t._status == "removed" then
				-- gone: nothing to do
			elseif t._repetitions > 0 and t._reps_left <= 0 then
				if t._auto_remove then
					self._timers[t._id] = nil
					t._status = "removed"
					t._next_fire = nil
					t._remaining = nil
				else
					t._status = "finished"
					t._next_fire = nil
					t._remaining = nil
				end
			elseif t._status == "running" and t._next_fire == old_next then
				-- Normal cadence, snap forward on hitches (no burst catch-up).
				local next_fire = old_next + t._delay
				if next_fire <= now then
					next_fire = now + t._delay
				end
				t._next_fire = next_fire
			end
		end
	end
	return fired
end

Manager.update = Manager.tick

-- PascalCase aliases (delegate to snake_case).
Manager.SetTimeSource = Manager.set_time_source
Manager.SetTimeFunction = Manager.set_time_source
Manager.GetTimeSource = Manager.get_time_source
Manager.GetTimeFunction = Manager.get_time_source
Manager.Now = Manager.now
Manager.SetErrorHandler = Manager.set_error_handler
Manager.Create = Manager.create
Manager.Simple = Manager.simple
Manager.Get = Manager.get
Manager.Exists = Manager.exists
Manager.Remove = Manager.remove
Manager.RemoveAll = Manager.remove_all
Manager.Clear = Manager.remove_all
Manager.Count = Manager.count
Manager.List = Manager.list
Manager.Start = Manager.start
Manager.Stop = Manager.stop
Manager.Pause = Manager.pause
Manager.UnPause = Manager.unpause
Manager.Resume = Manager.unpause
Manager.Toggle = Manager.toggle
Manager.Adjust = Manager.adjust
Manager.TimeLeft = Manager.time_left
Manager.RepsLeft = Manager.reps_left
Manager.PauseAll = Manager.pause_all
Manager.ResumeAll = Manager.resume_all
Manager.UnPauseAll = Manager.resume_all
Manager.StopAll = Manager.stop_all
Manager.Tick = Manager.tick
Manager.Update = Manager.tick

----------------------------------------------------------------------
-- DEFAULT SINGLETON
----------------------------------------------------------------------

--- Default shared manager using `os.clock`.<br>
--- Use it for simple scripts; create extra managers via `timer.new()` for isolation/tests.
local _default = Manager.new()

---@class TimerModule
---@field new fun(time_source?: TimerTimeSource): TimerManager Create an isolated manager.
---@field __call fun(time_source?: TimerTimeSource): TimerManager Call constructor.
---@field Timer Timer Timer class (OO handles).
---@field Manager TimerManager Manager class.
local timer = setmetatable({
	new = Manager.new,
	Timer = Timer,
	Manager = Manager,
	default = _default,
}, {
	__call = function(_, ...)
		return Manager.new(...)
	end,
})

--- Replace the default clock (e.g. `CurTime`, mock time in tests).
---@param fn TimerTimeSource Clock returning seconds.
function timer.set_time_function(fn)
	_default:set_time_source(fn)
end

timer.set_time_source = timer.set_time_function

--- Get the default clock.
---@return TimerTimeSource fn Clock function.
function timer.get_time_function()
	return _default:get_time_source()
end

timer.get_time_source = timer.get_time_function

--- Default clock reading.
---@return number now Seconds.
function timer.now()
	return _default:now()
end

--- Set the default error sink (nil = propagate).
---@param fn? fun(err: any, timer: Timer) Error sink.
function timer.set_error_handler(fn)
	_default:set_error_handler(fn)
end

--- Create (or replace) a named timer on the default manager.
---@param id TimerID Identifier.
---@param delay number|TimerOptions Delay or options table.
---@param repetitions? integer Total fires (`0` = infinite).
---@param fn? TimerCallback Callback.
---@param ... any Callback arguments.
---@return Timer timer Created timer.
function timer.create(id, delay, repetitions, fn, ...)
	return _default:create(id, delay, repetitions, fn, ...)
end

--- One-shot anonymous timer on the default manager.
---@param delay number Seconds until fire.
---@param fn TimerCallback Callback.
---@param ... any Callback arguments.
---@return Timer timer Created timer.
function timer.simple(delay, fn, ...)
	return _default:simple(delay, fn, ...)
end

--- Check existence on the default manager.
---@param id TimerID Identifier.
---@return boolean exists True when registered.
function timer.exists(id)
	return _default:exists(id)
end

--- Get a timer by id from the default manager.
---@param id TimerID Identifier.
---@return Timer? timer Timer or nil.
function timer.get(id)
	return _default:get(id)
end

--- Remove a timer from the default manager.
---@param id TimerID Identifier.
---@return boolean removed True when something was removed.
function timer.remove(id)
	return _default:remove(id)
end

--- Remove every timer from the default manager.
---@return table self Module table for chaining.
function timer.remove_all()
	_default:remove_all()
	return timer
end

timer.clear = timer.remove_all

--- Number of timers on the default manager.
---@return integer count Count.
function timer.count()
	return _default:count()
end

--- List ids on the default manager.
---@return TimerID[] ids Array of ids.
function timer.list()
	return _default:list()
end

--- Start (or restart) a timer on the default manager.
---@param id TimerID Identifier.
---@return boolean ok False when missing.
function timer.start(id)
	return _default:start(id)
end

--- Stop a timer on the default manager.
---@param id TimerID Identifier.
---@return boolean ok False when missing.
function timer.stop(id)
	return _default:stop(id)
end

--- Pause a timer on the default manager.
---@param id TimerID Identifier.
---@return boolean ok False when missing.
function timer.pause(id)
	return _default:pause(id)
end

--- Resume a paused timer on the default manager.
---@param id TimerID Identifier.
---@return boolean ok False when missing.
function timer.unpause(id)
	return _default:unpause(id)
end

timer.resume = timer.unpause

--- Toggle a timer on the default manager.
---@param id TimerID Identifier.
---@return boolean ok False when missing.
function timer.toggle(id)
	return _default:toggle(id)
end

--- Adjust a timer on the default manager.
---@param id TimerID Identifier.
---@param delay? number New delay.
---@param repetitions? integer New total.
---@param fn? TimerCallback New callback.
---@param ... any New callback arguments.
---@return boolean ok False when missing.
function timer.adjust(id, delay, repetitions, fn, ...)
	return _default:adjust(id, delay, repetitions, fn, ...)
end

--- Seconds until next fire, or nil when missing.
---@param id TimerID Identifier.
---@return number? left Seconds remaining.
function timer.time_left(id)
	return _default:time_left(id)
end

--- Fires remaining, or nil when missing.
---@param id TimerID Identifier.
---@return integer? left Remaining fires.
function timer.reps_left(id)
	return _default:reps_left(id)
end

--- Advance default timers. Call from your engine tick/update.
---@param now? number Absolute time (default: clock). Pass engine time here.
---@return integer fired Number of callbacks fired.
---@usage <br>
---@usage ```
---@usage Server.Subscribe("Tick", function() timer.tick() end)
---@usage ```
function timer.tick(now)
	return _default:tick(now)
end

timer.update = timer.tick

-- PascalCase aliases (delegate to snake_case).
timer.SetTimeFunction = timer.set_time_function
timer.SetTimeSource = timer.set_time_function
timer.GetTimeFunction = timer.get_time_function
timer.GetTimeSource = timer.get_time_function
timer.Now = timer.now
timer.SetErrorHandler = timer.set_error_handler
timer.Create = timer.create
timer.Simple = timer.simple
timer.Exists = timer.exists
timer.Get = timer.get
timer.Remove = timer.remove
timer.RemoveAll = timer.remove_all
timer.Clear = timer.remove_all
timer.Count = timer.count
timer.List = timer.list
timer.Start = timer.start
timer.Stop = timer.stop
timer.Pause = timer.pause
timer.UnPause = timer.unpause
timer.Resume = timer.unpause
timer.Toggle = timer.toggle
timer.Adjust = timer.adjust
timer.TimeLeft = timer.time_left
timer.RepsLeft = timer.reps_left
timer.Tick = timer.tick
timer.Update = timer.tick

-- Export
return timer
