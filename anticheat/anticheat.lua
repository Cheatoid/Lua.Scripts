-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- AntiCheat core library

-- Localized global functions for better performance
local assert = assert
local collectgarbage = collectgarbage
local error = error
local getmetatable = getmetatable
local ipairs = ipairs
local _loadstring = loadstring or load
local next = next
local pairs = pairs
local pcall = pcall
local setmetatable = setmetatable
local tostring = tostring
local type = type
local debug = debug
local debug_getinfo = debug and debug.getinfo or false
local debug_sethook = debug and debug.sethook or false
local debug_getregistry = debug and debug.getregistry or false
local debug_getupvalue = debug and debug.getupvalue or false
local debug_setupvalue = debug and debug.setupvalue or false
local debug_traceback = debug and debug.traceback or false
local math = math
local math_abs = math.abs
local math_ceil = math.ceil
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local math_random = math.random
local math_sqrt = math.sqrt
local os = os
local os_date = os.date
local string = string
local string_byte = string.byte
local string_dump = string.dump
local string_find = string.find
local string_format = string.format
local string_gmatch = string.gmatch
local string_gsub = string.gsub
local string_lower = string.lower
local string_match = string.match
local table = table
local table_concat = table.concat
local table_insert = table.insert
local table_remove = table.remove
local table_sort = table.sort
local table_unpack = table.unpack or unpack

-- Localized comparison functions for better performance
local function compare_score_desc(a, b)
	return a.score > b.score
end
local function compare_hour_asc(a, b)
	return a.hour < b.hour
end

-- Import dependencies
local math_struct = require "../math/init"

-- Try to create a native XOR function using loadstring/load, otherwise fallback to bit32/bit/manual implementation
local load_ok, bxor = pcall(_loadstring, "return function(a, b) return a ~ b end") -- TODO/FIXME
if load_ok and bxor then
	bxor = bxor()
else
	local bit = bit32 or bit or require "../standalone/bits"
	if bit.bxor then
		-- Fallback to bit library (LuaJIT, Lua 5.1 with bit32/bit library)
		bxor = bit.bxor
	else
		-- Cross-version bitwise XOR function (manual implementation)
		bxor = function(a, b)
			--if type(a) ~= "number" or type(b) ~= "number" then
			--	return 0
			--end
			-- Handle negative numbers by converting to 32-bit unsigned
			a, b = a % 0x100000000, b % 0x100000000
			local result, bit_val = 0, 1
			while a > 0 or b > 0 do
				if (a % 2) ~= (b % 2) then
					result = result + bit_val
				end
				a, b = math_floor(a * 0.5), math_floor(b * 0.5)
				bit_val = bit_val * 2
			end
			return result
		end
	end
end

local M = {}

----------------------------------------------------------------------
-- SECTION: CORE UTIL
----------------------------------------------------------------------

--- Core utility functions and helpers for anti-cheat system
---@class Util
local Util = {}

--- Get current timestamp using high-resolution clock when available
---@return number time Current time in seconds
Util.now = os.clock

--- Check if a value is infinity (positive or negative)
---@param v number Value to check
---@return boolean is_inf True if value is infinity
function Util.is_inf(v)
	return type(v) == "number" and (v == math.huge or v == -math.huge)
end

--- Check if a value is NaN (Not a Number)
---@param v number Value to check
---@return boolean is_nan True if value is NaN
function Util.is_nan(v)
	return type(v) == "number" and v ~= v
end

--- Check if a value is invalid (infinity or NaN)
---@param v number Value to check
---@return boolean is_invalid True if value is infinity or NaN
function Util.is_invalid(v)
	--return Util.is_inf(v) or Util.is_nan(v)
	return type(v) ~= "number" or v == math.huge or v == -math.huge or v ~= v
end

--- Clamp a value between minimum and maximum bounds
---@param x number Value to clamp
---@param lo number Minimum bound
---@param hi number Maximum bound
---@return number clamped Clamped value
function Util.clamp(x, lo, hi)
	-- Validate inputs
	--if Util.is_invalid(x) or Util.is_invalid(lo) or Util.is_invalid(hi) then
	--	return lo or 0
	--end

	-- Ensure bounds are valid
	if lo > hi then
		lo, hi = hi, lo
	end

	if x < lo then return lo end
	if x > hi then return hi end
	return x
end

--- Conditional value utility - return value if condition is truthy, otherwise returns nil implicitly
---@param condition boolean Condition to check
---@param value any Value to return if condition is true
---@return any result Value or nil
function Util.when(condition, value)
	if condition then return value end
end

--- Linear interpolation between two values
---@param a number Start value
---@param b number End value
---@param t number Interpolation factor (0-1)
---@return number result Interpolated value
function Util.lerp(a, b, t)
	-- Validate inputs
	--if Util.is_invalid(a) or Util.is_invalid(b) or Util.is_invalid(t) then
	--	return a or 0
	--end

	local result = a + (b - a) * t

	-- Check if calculation resulted in invalid value
	--if Util.is_invalid(result) then
	--	return a or 0
	--end

	return result
end

--- Calculate 2D vector length
---@param x number X component
---@param y number Y component
---@return number length Vector length
function Util.len2(x, y)
	-- Validate inputs
	--if Util.is_invalid(x) or Util.is_invalid(y) then
	--	return 0
	--end

	local len_sq = x * x + y * y

	-- Check for overflow or invalid result
	--if Util.is_invalid(len_sq) or len_sq < 0 then
	--	return 0
	--end

	return len_sq ^ 0.5
end

--- Calculate 3D vector length
---@param x number X component
---@param y number Y component
---@param z number Z component
---@return number length Vector length
function Util.len3(x, y, z)
	-- Validate inputs
	--if Util.is_invalid(x) or Util.is_invalid(y) or Util.is_invalid(z) then
	--	return 0
	--end

	local len_sq = x * x + y * y + z * z

	-- Check for overflow or invalid result
	--if Util.is_invalid(len_sq) or len_sq < 0 then
	--	return 0
	--end

	return len_sq ^ 0.5
end

--- Safe string conversion that handles errors gracefully
---@param v any Value to convert
---@return string str String representation or error placeholder
function Util.safe_tostring(v)
	local ok, s = pcall(tostring, v)
	return ok and s or "<tostring_error>"
end

--- Create a shallow copy of a table
---@param t table Table to copy
---@return table copy Shallow copy of the table
function Util.shallow_copy(t)
	if type(t) ~= "table" then return t end
	local out = {}
	for k, v in next, t do out[k] = v end
	return out
end

--- Get option value with default fallback
---@param opts? table Options table
---@param key string Option key
---@param default any Default value if option is nil
---@return any value Option value or default
function Util.get_opt(opts, key, default)
	if opts and opts[key] ~= nil then
		return opts[key]
	end
	return default
end

--- Prototype-based class helper with optional base class
---@param name string Class name
---@param base? table Base class to inherit from
---@return table cls New class constructor
local function class(name, base)
	local obj = {
		__name = name
	}
	obj.__index = obj
	return setmetatable(obj, {
		__index = base,
		__call = function(cls, ...)
			local self = setmetatable({}, cls)
			if self.init then self:init(...) end
			return self
		end,
	})
end

Util.class = class -- TODO/FIXME

--- Fixed-capacity ring buffer optimized for newest-first access<br>
--- get(1) = newest, get(size) = oldest
---@class RingBuffer
---@field capacity integer Maximum number of items
---@field buf table Internal storage array
---@field head integer Current write position
---@field size integer Current number of items
local RingBuffer = class("RingBuffer")

--- Initialize ring buffer with specified capacity
---@param self RingBuffer
---@param capacity integer Maximum number of items to store
function RingBuffer:init(capacity)
	self.capacity = math_max(1, tonumber(capacity) or 1)
	self.buf      = {}
	self.head     = 0
	self.size     = 0
end

--- Add a new value to the ring buffer
---@param self RingBuffer
---@param v any Value to add
function RingBuffer:push(v)
	self.head = (self.head % self.capacity) + 1
	self.buf[self.head] = v
	if self.size < self.capacity then self.size = self.size + 1 end
end

--- Get value by index (1 = newest, size = oldest)
---@param self RingBuffer
---@param i integer Index to retrieve
---@return any value Value at index, or nil if invalid
function RingBuffer:get(i)
	if i < 1 or i > self.size then return end
	local idx = self.head - (i - 1)
	while idx < 1 do idx = idx + self.capacity end
	return self.buf[idx]
end

--- Convert buffer to array with newest items first
---@param self RingBuffer
---@return table array Array of items in newest-first order
function RingBuffer:to_array_newest_first()
	local out = {}
	for i = 1, self.size do out[i] = self:get(i) end
	return out
end

--- Clear all items from the buffer
---@param self RingBuffer
function RingBuffer:clear()
	self.buf  = {}
	self.head = 0
	self.size = 0
end

--- Create iterator over items in newest-first order
---@param self RingBuffer
---@return function iterator Iterator function that yields items
function RingBuffer:iter_newest_first()
	local i = 0
	return function()
		i = i + 1
		return self:get(i)
	end
end

Util.RingBuffer = RingBuffer

--- FNV-1a 32-bit non-cryptographic hash for integrity checking
---@param str string Input string to hash
---@return number hash 32-bit hash value
function Util.fnv1a32(str)
	local h = 2166136261
	for i = 1, #str do
		h = bxor(h, string_byte(str, i))
		h = (h * 16777619) % 0x100000000
	end
	return h
end

--- Generate function fingerprint using debug information
---@param fn function Function to fingerprint
---@return string fingerprint Function fingerprint string
function Util.fingerprint_fn(fn)
	if type(fn) ~= "function" then return "<not_function>" end
	local info = debug_getinfo(fn, "Sln")
	if not info then return "<no_debug_info>" end
	return table_concat({
		info.what or "?",
		info.source or "?",
		tostring(info.linedefined or "?"),
		tostring(info.lastlinedefined or "?"),
		info.name or "?",
	}, "|")
end

--- Generate registry entry fingerprint
---@param key any Registry key
---@param value any Registry value
---@return string fingerprint Entry fingerprint
function Util.fingerprint_registry_entry(key, value)
	local key_str = type(key) == "string" and key or tostring(key)
	local value_type = type(value)
	local value_fp = "<unknown>"

	if value_type == "function" then
		value_fp = Util.fingerprint_fn(value)
		-- Add string dump for Lua functions
		local ok, dump = pcall(string_dump, value)
		if ok then
			value_fp = value_fp .. "|" .. Util.fnv1a32(dump)
		end
	elseif value_type == "table" then
		-- Simple table checksum
		local parts = {}
		for k, v in next, value do
			table.insert(parts, tostring(k) .. "=" .. tostring(type(v)))
		end
		table.sort(parts)
		value_fp = Util.fnv1a32(table.concat(parts, ","))
	elseif value_type == "userdata" then
		value_fp = "<userdata>"
	else
		value_fp = tostring(value)
	end

	return table_concat({ key_str, value_type, value_fp }, "|")
end

--- Capture registry baseline
---@return table baseline Registry baseline data
function Util.capture_registry_baseline()
	if not debug or not debug.getregistry then
		return { error = "debug.getregistry unavailable" }
	end

	local registry = debug.getregistry()
	if type(registry) ~= "table" then
		return { error = "registry is not a table" }
	end

	local baseline = {
		timestamp = Util.now(),
		entries = {},
		entry_count = 0,
		checksum = 0
	}

	local fingerprints = {}

	for k, v in next, registry do
		local fp = Util.fingerprint_registry_entry(k, v)
		fingerprints[fp] = (fingerprints[fp] or 0) + 1

		-- Store key type and fingerprint
		local key_type = type(k)
		baseline.entries[fp] = {
			key_type = key_type,
			key = Util.when(key_type == "string", k),
			key_num = Util.when(key_type == "number", k),
			value_type = type(v),
			fingerprint = fp,
			count = 1
		}
		baseline.entry_count = baseline.entry_count + 1
	end

	-- Generate overall checksum
	local sorted_fps = {}
	for fp, count in next, fingerprints do
		table_insert(sorted_fps, fp .. ":" .. count)
	end
	table_sort(sorted_fps)
	baseline.checksum = Util.fnv1a32(table_concat(sorted_fps, "|"))

	return baseline
end

--- Verify registry against baseline
---@param baseline table Original baseline
---@return boolean integrity_ok True if registry matches baseline
---@return table details Verification details
function Util.verify_registry_integrity(baseline)
	if not baseline or baseline.error then
		return false, { error = "invalid baseline" }
	end

	if not debug or not debug.getregistry then
		return false, { error = "debug.getregistry unavailable" }
	end

	local registry = debug.getregistry()
	if type(registry) ~= "table" then
		return false, { error = "registry is not a table" }
	end

	local current = Util.capture_registry_baseline()
	local details = {
		baseline_count = baseline.entry_count,
		current_count = current.entry_count,
		baseline_checksum = baseline.checksum,
		current_checksum = current.checksum,
		added_entries = {},
		removed_entries = {},
		modified_entries = {}
	}

	-- Check entry count
	if baseline.entry_count ~= current.entry_count then
		details.integrity_ok = false
	end

	-- Check checksum
	if baseline.checksum ~= current.checksum then
		details.integrity_ok = false
	end

	-- Detailed comparison
	local baseline_fps = {}
	for fp, entry in next, baseline.entries do
		baseline_fps[fp] = entry
	end

	local current_fps = {}
	for fp, entry in next, current.entries do
		current_fps[fp] = entry
	end

	-- Find added entries
	for fp, entry in next, current_fps do
		if not baseline_fps[fp] then
			details.added_entries[fp] = entry
		end
	end

	-- Find removed entries
	for fp, entry in next, baseline_fps do
		if not current_fps[fp] then
			details.removed_entries[fp] = entry
		end
	end

	details.integrity_ok = (baseline.checksum == current.checksum) and
			(baseline.entry_count == current.entry_count) and
			(next(details.added_entries) == nil) and
			(next(details.removed_entries) == nil)

	return details.integrity_ok, details
end

--- Check if a function is native (C function) using multiple detection methods
---@param fn function Function to check
---@return boolean is_native True if function is native, false if Lua function
---@return string detection_method Method used for detection ("string_dump", "debug.getinfo", "fallback")
function Util.is_native_function(fn)
	if type(fn) ~= "function" then return false, "not_function" end

	-- Method 1: Use string_dump (most reliable - native functions cannot be dumped)
	local dump_ok, dump_result = pcall(string_dump, fn, false)
	if dump_ok then
		-- If string_dump succeeds, it's a Lua function
		return false, "string_dump"
	elseif dump_result and type(dump_result) == "string" and string_find(dump_result, "unable to dump") then
		-- If string_dump fails with "unable to dump", it's a native function
		return true, "string_dump"
	end

	-- Method 2: Fallback to debug.getinfo (may be compromised)
	local dbg = debug
	if dbg and dbg.getinfo then
		local ok, info = pcall(dbg.getinfo, fn, "S")
		if ok and info then
			if info.what == "C" then
				return true, "debug.getinfo"
			elseif info.what == "Lua" then
				return false, "debug.getinfo"
			end
		end
	end

	-- Method 3: Heuristic fallback - check function properties
	local ok, tostring_result = pcall(tostring, fn)
	if ok and type(tostring_result) == "string" then
		-- Native functions typically have "function: 0x..." format without source info
		-- Lua functions may have more detailed tostring output in some implementations
		if string_match(tostring_result, "^function: 0x%x+$") then
			return true, "fallback"
		end
	end

	-- Default assumption - treat as native for safety
	return true, "fallback"
end

--- Verify function integrity using both debug.getinfo and string_dump
---@param fn function Function to verify
---@param expected_type? string Expected type ("native" or "lua"), nil for any
---@return boolean is_valid True if function passes verification
---@return table details Verification details
function Util.verify_function_integrity(fn, expected_type)
	local details = {
		fn_type = type(fn),
		is_native = false,
		detection_method = "none",
		debug_info = nil,
		dump_result = nil,
		verification_passed = false
	}

	if type(fn) ~= "function" then
		return false, details
	end

	-- Get native/Lua classification
	details.is_native, details.detection_method = Util.is_native_function(fn)

	-- Get debug info if available
	local dbg = debug
	if dbg and dbg.getinfo then
		local ok, info = pcall(dbg.getinfo, fn, "Sln")
		if ok then
			details.debug_info = {
				what = info and info.what,
				source = info and info.source,
				linedefined = info and info.linedefined,
				lastlinedefined = info and info.lastlinedefined,
				name = info and info.name
			}
		end
	end

	-- Get dump result if it's a Lua function
	if not details.is_native then
		local ok, dump = pcall(string_dump, fn, false)
		if ok then
			details.dump_result = {
				success = true,
				length = type(dump) == "string" and #dump or 0,
				hash = Util.when(type(dump) == "string", Util.fnv1a32(dump))
			}
		else
			details.dump_result = {
				success = false,
				error = dump
			}
		end
	end

	-- Verify against expected type
	if expected_type then
		if expected_type == "native" and not details.is_native then
			details.verification_passed = false
		elseif expected_type == "lua" and details.is_native then
			details.verification_passed = false
		else
			details.verification_passed = true
		end
	else
		details.verification_passed = true
	end

	-- Additional integrity check: verify debug info matches string_dump results
	if details.debug_info and details.dump_result and details.dump_result.success then
		local debug_says_lua = details.debug_info.what == "Lua"
		local dump_says_lua = not details.is_native

		-- If debug info and string_dump disagree, debug.getinfo may be compromised
		if debug_says_lua ~= dump_says_lua then
			details.verification_passed = false
			details.integrity_violation = "debug_info_mismatch"
		end
	end

	return details.verification_passed, details
end

--- Helper function to validate and initialize numeric values
---@param data table Data table containing the field
---@param field_name string Name of the field to extract
---@param default_value any Default value if field is invalid or missing
---@return any # Validated value or default
local function get_validated_field(data, field_name, default_value)
	default_value = default_value or 0
	local value = data[field_name]
	if value ~= nil and not Util.is_invalid(value) then
		return value
	end
	return default_value
end

M.Util = Util

----------------------------------------------------------------------
-- SECTION: EVENT BUS
----------------------------------------------------------------------

--- Event bus for decoupled communication between components
---@class EventBus
---@field _listeners table Event listeners registry
local EventBus = class("EventBus")

--- Initialize event bus with empty listener registry
---@param self EventBus
function EventBus:init()
	self._listeners = {} -- { [eventType] = { {fn, filter?}, ... } }
end

--- Subscribe to an event type with optional filter
---@param self EventBus
---@param eventType string Event type to listen for
---@param fn function Callback function
---@param filter? function Optional filter function
---@return integer id Subscription ID for later removal
function EventBus:on(eventType, fn, filter)
	if not self._listeners[eventType] then
		self._listeners[eventType] = {}
	end
	local id = #self._listeners[eventType] + 1
	self._listeners[eventType][id] = { fn = fn, filter = filter }
	return id
end

--- Unsubscribe from an event type
---@param self EventBus
---@param eventType string Event type to unsubscribe from
---@param id integer Subscription ID to remove
---@return boolean removed True if subscription was found and removed
function EventBus:off(eventType, id)
	local list = self._listeners[eventType]
	if list and list[id] then
		list[id] = nil
		return true
	end
	return false
end

--- Emit an event to all subscribers
---@param self EventBus
---@param eventType string Event type to emit
---@param data any Event data to pass to subscribers
function EventBus:emit(eventType, data)
	local list = self._listeners[eventType]
	if not list then return end
	for i = 1, #list do
		local entry = list[i]
		if entry then
			if entry.filter and not entry.filter(data) then
				-- skip filtered
			else
				pcall(entry.fn, data)
			end
		end
	end
end

--- Clear listeners for specific event type or all events
---@param self EventBus
---@param eventType? string Event type to clear, or nil to clear all
function EventBus:clear(eventType)
	if eventType then
		self._listeners[eventType] = nil
	else
		self._listeners = {}
	end
end

M.EventBus = EventBus

----------------------------------------------------------------------
-- SECTION: SERVER - SNAPSHOT SYSTEM
----------------------------------------------------------------------

--- Structured state record for a player at a specific point in time
---@class PlayerSnapshot
---@field tick integer Game tick when snapshot was taken
---@field t number Timestamp in seconds
---@field x number X coordinate
---@field y number Y coordinate
---@field z number Z coordinate
---@field vx number X velocity
---@field vy number Y velocity
---@field vz number Z velocity
---@field yaw number Yaw rotation
---@field pitch number Pitch rotation
---@field grounded boolean Whether player is on ground
---@field inputs table Input state (e.g. { forward=true, jump=true })
---@field meta table Additional metadata
local PlayerSnapshot = class("PlayerSnapshot")

--- Initialize player snapshot with position and state data
---@param self PlayerSnapshot
---@param data? table Initial data table
function PlayerSnapshot:init(data)
	data          = data or {}
	self.tick     = data.tick or 0
	self.t        = data.t or 0

	-- Initialize position with validation
	self.x        = get_validated_field(data, "x")
	self.y        = get_validated_field(data, "y")
	self.z        = get_validated_field(data, "z")

	-- Initialize velocity with validation
	self.vx       = get_validated_field(data, "vx")
	self.vy       = get_validated_field(data, "vy")
	self.vz       = get_validated_field(data, "vz")

	-- Initialize angles with validation
	self.yaw      = get_validated_field(data, "yaw")
	self.pitch    = get_validated_field(data, "pitch")

	self.grounded = data.grounded or false
	self.inputs   = data.inputs or {} -- e.g. { forward=true, jump=true }
	self.meta     = data.meta or {}
end

--- High-performance ring buffer optimized for monotonically increasing
--- ticks/timestamps with O(log N) binary search for backtracking
---@class SnapshotBuffer
---@field capacity integer Maximum number of snapshots
---@field _data table Internal storage array
---@field _head integer Next write index
---@field _count integer Current number of snapshots
local SnapshotBuffer = class("SnapshotBuffer")

--- Initialize snapshot buffer with specified capacity
---@param self SnapshotBuffer
---@param capacity integer Maximum number of snapshots to store (minimum 2)
function SnapshotBuffer:init(capacity)
	self.capacity = math_max(2, capacity or 120) -- Need at least 2 for prev/current
	self._data    = {}
	self._head    = 1                           -- Next write index
	self._count   = 0
end

--- Add a new snapshot to the buffer
---@param self SnapshotBuffer
---@param snap PlayerSnapshot Snapshot to add
function SnapshotBuffer:push(snap)
	self._data[self._head] = snap
	if self._count < self.capacity then
		self._count = self._count + 1
	end
	self._head = (self._head % self.capacity) + 1
end

--- Convert 1-based virtual index to physical array index<br>
--- Virtual: 1=oldest, count=newest
---@param self SnapshotBuffer
---@param v_idx integer Virtual index to convert
---@return integer p_idx Physical array index
function SnapshotBuffer:_to_phys(v_idx)
	if self._count < self.capacity then return v_idx end
	return ((self._head + v_idx - 2) % self.capacity) + 1
end

--- Get snapshot by virtual index (1=oldest, count=newest)
---@param self SnapshotBuffer
---@param v_idx integer Virtual index to retrieve
---@return PlayerSnapshot? snapshot Snapshot at index or nil if invalid
function SnapshotBuffer:get(v_idx)
	if v_idx < 1 or v_idx > self._count then return end
	return self._data[self:_to_phys(v_idx)]
end

--- Get the newest snapshot
---@param self SnapshotBuffer
---@return PlayerSnapshot? snapshot Newest snapshot or nil if empty
function SnapshotBuffer:latest() return self:get(self._count) end

--- Get the second newest snapshot
---@param self SnapshotBuffer
---@return PlayerSnapshot? snapshot Previous snapshot or nil if less than 2
function SnapshotBuffer:prev() return self:get(self._count - 1) end

--- Get the current number of snapshots
---@param self SnapshotBuffer
---@return integer count Number of stored snapshots
function SnapshotBuffer:count() return self._count end

--- Find closest snapshot by tick using O(log N) binary search
---@param self SnapshotBuffer
---@param tick integer Tick to search for
---@return PlayerSnapshot? snapshot Closest snapshot or nil if empty
function SnapshotBuffer:find_by_tick(tick)
	if self._count == 0 then return end
	local lo, hi = 1, self._count
	while lo <= hi do
		local mid = math_floor((lo + hi) * 0.5)
		local snap = self:get(mid)
		if snap.tick == tick then
			return snap
		end
		if snap.tick < tick then
			lo = mid + 1
		else
			hi = mid - 1
		end
	end
	-- Return closest match
	if lo > self._count then return self:get(self._count) end
	if hi < 1 then return self:get(1) end
	local s_lo, s_hi = self:get(lo), self:get(hi)
	if not s_lo then return s_hi end
	if not s_hi then return s_lo end
	return math_abs(s_lo.tick - tick) < math_abs(s_hi.tick - tick) and s_lo or s_hi
end

--- Find closest snapshot by timestamp using O(log N) binary search
---@param self SnapshotBuffer
---@param t number Timestamp to search for
---@return PlayerSnapshot? snapshot Closest snapshot or nil if empty
function SnapshotBuffer:find_by_time(t)
	if self._count == 0 then return end
	local lo, hi = 1, self._count
	while lo <= hi do
		local mid = math_floor((lo + hi) * 0.5)
		local snap = self:get(mid)
		if snap.t == t then
			return snap
		end
		if snap.t < t then
			lo = mid + 1
		else
			hi = mid - 1
		end
	end
	if lo > self._count then return self:get(self._count) end
	if hi < 1 then return self:get(1) end
	local s_lo, s_hi = self:get(lo), self:get(hi)
	if not s_lo then return s_hi end
	if not s_hi then return s_lo end
	return math_abs(s_lo.t - t) < math_abs(s_hi.t - t) and s_lo or s_hi
end

--- Get range of snapshots between start_tick and end_tick inclusive
---@param self SnapshotBuffer
---@param start_tick integer Starting tick
---@param end_tick integer Ending tick
---@return table snapshots Array of snapshots in the range
function SnapshotBuffer:get_range(start_tick, end_tick)
	local result = {}
	if self._count == 0 then return result end
	local lo, hi = 1, self._count
	local start_idx = self._count
	-- Binary search for lower bound
	while lo <= hi do
		local mid = math_floor((lo + hi) * 0.5)
		if self:get(mid).tick >= start_tick then
			start_idx = mid
			hi = mid - 1
		else
			lo = mid + 1
		end
	end
	for i = start_idx, self._count do
		local snap = self:get(i)
		if snap.tick > end_tick then break end
		result[#result + 1] = snap
	end
	return result
end

M.Server                = M.Server or {}
M.Server.PlayerSnapshot = PlayerSnapshot
M.Server.SnapshotBuffer = SnapshotBuffer

----------------------------------------------------------------------
-- SECTION: SERVER - CORE TYPES
----------------------------------------------------------------------

--- Violation record for anti-cheat detection events
---@class Violation
---@field kind string Type of violation (e.g. "speed", "teleport")
---@field severity number Severity score (higher = more serious)
---@field evidence table Evidence data supporting the violation
---@field time number Timestamp when violation occurred
local Violation         = class("Violation")

--- Create a new violation record
---@param self Violation
---@param kind string Type of violation
---@param severity number Severity score
---@param evidence table Evidence data
---@param t? number Timestamp (default: `os.clock()`)
function Violation:init(kind, severity, evidence, t)
	self.kind     = kind or "unknown"
	self.severity = tonumber(severity) or 0
	self.evidence = evidence or {}
	self.time     = t or Util.now()
end

--- Movement model configuration for anti-cheat validation
---@class MovementModel
---@field max_walk_speed number Maximum horizontal walking speed
---@field max_sprint_speed number Maximum horizontal sprinting speed
---@field max_vertical_speed number Maximum vertical movement speed
---@field max_acceleration number Maximum acceleration rate
---@field teleport_distance number Maximum allowed teleport distance
---@field position_epsilon number Tolerance for position comparison
---@field world_floor_vertical number Minimum world vertical coordinate
---@field world_ceiling_vertical number Maximum world vertical coordinate
---@field water_level_vertical? number Water level vertical coordinate (nil = no water)
---@field max_airborne_ticks number Maximum ticks allowed while airborne
---@field min_packet_interval number Minimum time between packets (seconds)
---@field max_packet_interval number Maximum time between packets (seconds)
---@field max_yaw_rate number Maximum yaw rotation rate (degrees/second)
---@field max_pitch_rate number Maximum pitch rotation rate (degrees/second)
---@field gravity number Gravity acceleration
local MovementModel = class("MovementModel")

--- Initialize movement model with game-specific parameters
---@param self MovementModel
---@param opts? table Configuration options
function MovementModel:init(opts)
	opts                        = opts or {}
	-- Horizontal
	self.max_walk_speed         = Util.get_opt(opts, "max_walk_speed", 16)
	self.max_sprint_speed       = Util.get_opt(opts, "max_sprint_speed", 24)
	-- Vertical
	self.max_vertical_speed     = Util.get_opt(opts, "max_vertical_speed", 60)
	-- Acceleration
	self.max_acceleration       = Util.get_opt(opts, "max_acceleration", 120)
	-- Teleport
	self.teleport_distance      = Util.get_opt(opts, "teleport_distance", 45)
	-- Epsilon for "same position"
	self.position_epsilon       = Util.get_opt(opts, "position_epsilon", 0.05)
	-- World bounds
	self.world_floor_vertical   = opts.world_floor_vertical
	self.world_ceiling_vertical = opts.world_ceiling_vertical
	-- Water
	self.water_level_vertical   = opts.water_level_vertical
	-- Airborne tolerance
	self.max_airborne_ticks     = Util.get_opt(opts, "max_airborne_ticks", 20)
	-- Packet timing (seconds)
	self.min_packet_interval    = Util.get_opt(opts, "min_packet_interval", 0.01)
	self.max_packet_interval    = Util.get_opt(opts, "max_packet_interval", 0.5)
	-- Rotation
	self.max_yaw_rate           = Util.get_opt(opts, "max_yaw_rate", 720)
	self.max_pitch_rate         = Util.get_opt(opts, "max_pitch_rate", 360)
	-- Gravity
	self.gravity                = Util.get_opt(opts, "gravity", 9.81)
end

--- Player tracking data with movement history and violation scoring
---@class PlayerTrack
---@field playerId any Unique player identifier
---@field model MovementModel Movement model for validation
---@field samples SnapshotBuffer Historical position snapshots
---@field score number Current violation score
---@field lastViolationAt number Timestamp of last violation
---@field state table Current player state tracking
local PlayerTrack = class("PlayerTrack")

--- Initialize player tracking with movement model and history
---@param self PlayerTrack
---@param playerId any Unique player identifier
---@param opts? table Optional configuration options:
--- - `model` (MovementModel, default: `MovementModel()`): Movement model for validation
--- - `sampleCapacity` (number, default: 60): Maximum number of snapshots to keep in history
function PlayerTrack:init(playerId, opts)
	opts                 = opts or {}
	self.playerId        = playerId
	self.model           = Util.get_opt(opts, "model", MovementModel())
	self.samples         = SnapshotBuffer(Util.get_opt(opts, "sampleCapacity", 60))
	self.score           = 0
	self.lastViolationAt = 0
	self.state           = {
		grounded        = false,
		airborneTicks   = 0,
		lastGroundedAt  = 0,
		violationCounts = {},
	}
end

--- Add a new movement sample to the player's history
---@param self PlayerTrack
---@param sample PlayerSnapshot|table New position snapshot
function PlayerTrack:addSample(sample)
	-- Wrap raw tables in PlayerSnapshot if not already
	if type(sample) ~= "table" or not sample.__name or sample.__name ~= "PlayerSnapshot" then
		sample = PlayerSnapshot(sample)
	end
	self.samples:push(sample)
	if sample.grounded then
		self.state.airborneTicks  = 0
		self.state.lastGroundedAt = sample.t
	else
		self.state.airborneTicks = self.state.airborneTicks + 1
	end
	self.state.grounded = sample.grounded or false
end

--- Get the latest snapshot
---@param self PlayerTrack
---@return PlayerSnapshot? snapshot Latest snapshot, or nil if empty
function PlayerTrack:latest() return self.samples:latest() end

--- Get the previous snapshot
---@param self PlayerTrack
---@return PlayerSnapshot? snapshot Previous snapshot, or nil if less than 2
function PlayerTrack:prev() return self.samples:prev() end

--- Access historical snapshot by relative index<br>
--- 1 = newest, 2 = previous, etc.
---@param self PlayerTrack
---@param i integer Relative index from newest
---@return PlayerSnapshot? snapshot Snapshot at index, or nil if invalid
function PlayerTrack:sampleAt(i)
	local count = self.samples:count()
	return self.samples:get(count - (i - 1))
end

--- Backtracking helper: find snapshot by specific tick
---@param self PlayerTrack
---@param tick integer Tick to search for
---@return PlayerSnapshot? snapshot Snapshot at tick, or nil if not found
function PlayerTrack:getSnapshotAtTick(tick) return self.samples:find_by_tick(tick) end

--- Backtracking helper: find snapshot by timestamp
---@param self PlayerTrack
---@param t number Timestamp to search for
---@return PlayerSnapshot? snapshot Snapshot at time, or nil if not found
function PlayerTrack:getSnapshotAtTime(t) return self.samples:find_by_time(t) end

--- Backtracking helper: get snapshots in tick range
---@param self PlayerTrack
---@param start_tick integer Starting tick
---@param end_tick integer Ending tick
---@return table snapshots Array of snapshots in range
function PlayerTrack:getSnapshotRange(start_tick, end_tick) return self.samples:get_range(start_tick, end_tick) end

--- Record a violation and update tracking state
---@param self PlayerTrack
---@param v Violation Violation to record
function PlayerTrack:recordViolation(v)
	self.state.violationCounts[v.kind] =
			(self.state.violationCounts[v.kind] or 0) + 1
	self.lastViolationAt = v.time
end

--- Base class for anti-cheat detection strategies
---@class DetectionStrategy
---@field name string Strategy identifier
---@field enabled boolean Whether strategy is active
---@field severityCap number Maximum severity score for violations
local DetectionStrategy = class("DetectionStrategy")

--- Initialize detection strategy with configuration
---@param self DetectionStrategy
---@param name string Strategy name
---@param opts? table Configuration options
function DetectionStrategy:init(name, opts)
	self.name        = name or "strategy"
	self.enabled     = Util.get_opt(opts, "enabled", true)
	self.severityCap = Util.get_opt(opts, "severityCap", 20)
end

--- Check for violations - override in subclasses
---@param self DetectionStrategy
---@param ctx table Detection context with player data
---@return Violation? violation Detected violation, or nil if none
function DetectionStrategy:check(_ctx)
end

----------------------------------------------------------------------
-- Shared helpers
----------------------------------------------------------------------

--- Shared helper: calculate safe time delta between snapshots
---@param s PlayerSnapshot Current snapshot
---@param p PlayerSnapshot Previous snapshot
---@param minDt? number Minimum time delta threshold
---@return number? dt Safe time delta, or nil if invalid
local function safe_dt(s, p, minDt)
	if not s or not p then return end
	if not s.t or not p.t then return end
	local dt = s.t - p.t
	if dt <= (minDt or 0.05) then return end
	return dt
end

--- Shared helper: calculate position delta between snapshots
---@param s PlayerSnapshot Current snapshot
---@param p PlayerSnapshot Previous snapshot
---@return number dx X position delta
---@return number dy Y position delta
---@return number dz Z position delta
local function pos_delta(s, p)
	-- Validate positions before calculating delta
	if not s or not p then return 0, 0, 0 end
	if Util.is_invalid(s.x) or Util.is_invalid(p.x) or
			Util.is_invalid(s.y) or Util.is_invalid(p.y) or
			Util.is_invalid(s.z) or Util.is_invalid(p.z) then
		return 0, 0, 0
	end

	local dx, dy, dz = (s.x - p.x), (s.y - p.y), (s.z - p.z)

	-- Check if delta calculation resulted in invalid values
	if Util.is_invalid(dx) or Util.is_invalid(dy) or Util.is_invalid(dz) then
		return 0, 0, 0
	end

	return dx, dy, dz
end

----------------------------------------------------------------------
-- SECTION: SERVER - MOVEMENT SIMULATION
----------------------------------------------------------------------

--- Interface for deterministic game physics prediction.<br>
--- You MUST override `simulate()` with your game's specific physics logic
---@class MovementSimulator
local MovementSimulator = class("MovementSimulator")

--- Simulate player movement - must be implemented by game
---@param self MovementSimulator
---@param prevSnap PlayerSnapshot Previous state snapshot
---@param inputs table Input flags (forward, jump, etc.)
---@param dt number Time delta (seconds/ticks)
---@return PlayerSnapshot predicted Predicted next state
function MovementSimulator:simulate(prevSnap, inputs, dt)
	-- prevSnap: PlayerSnapshot
	-- inputs: table of input flags (forward, jump, etc.)
	-- dt: float (seconds/ticks)
	-- Returns: A new PlayerSnapshot representing the predicted state
	return error("MovementSimulator:simulate() must be implemented by the game!")
end

M.Server.MovementSimulator = MovementSimulator

----------------------------------------------------------------------
-- SECTION: SERVER - ANTICHEAT ORCHESTRATOR
----------------------------------------------------------------------

--- Main anti-cheat orchestrator that coordinates detection and response
---@class AntiCheat
---@field model MovementModel Movement validation model
---@field strategies table Detection strategies
---@field tracks table Player tracking data
---@field eventBus? EventBus Event communication system (default: `EventBus()`)
---@field decay_per_second? number Score decay rate per second (default: 0.4)
---@field kick_score? number Score threshold for kicking (default: 20)
---@field ban_score? number Score threshold for banning (default: 60)
---@field max_score? number Maximum possible score (default: 999)
---@field on_violation? fun(playerId: any, violation: Violation) Legacy violation callback
local AntiCheat = class("AntiCheat")

--- Initialize anti-cheat system with configuration
---@param self AntiCheat
---@param opts? table Configuration options
function AntiCheat:init(opts)
	opts = opts or {}
	-- Properly distinguish MovementModel instances from raw opts tables
	if opts.model and type(opts.model) == "table" and opts.model.__name == "MovementModel" then
		self.model = opts.model
	elseif opts.modelOpts and type(opts.modelOpts) == "table" then
		self.model = MovementModel(opts.modelOpts)
	elseif opts.model and type(opts.model) == "table" then
		self.model = MovementModel(opts.model) -- backward-compat
	else
		self.model = MovementModel()
	end

	self.strategies       = {}
	self.tracks           = {}
	self.eventBus         = Util.get_opt(opts, "eventBus", EventBus())
	self.decay_per_second = Util.get_opt(opts, "decay_per_second", 0.4)
	self.kick_score       = Util.get_opt(opts, "kick_score", 20)
	self.ban_score        = Util.get_opt(opts, "ban_score", 60)
	self.max_score        = Util.get_opt(opts, "max_score", 999)
	self.on_violation     = opts.on_violation -- legacy callback(playerId, violation)
end

--- Get or create player tracking data
---@param self AntiCheat
---@param playerId any Unique player identifier
---@return PlayerTrack track Player tracking instance
function AntiCheat:getTrack(playerId)
	if not self.tracks[playerId] then
		self.tracks[playerId] = PlayerTrack(playerId, { model = self.model })
	end
	return self.tracks[playerId]
end

--- Add a detection strategy to the anti-cheat system
---@param self AntiCheat
---@param strategy DetectionStrategy Strategy instance with check method
---@return AntiCheat self For fluent API chaining
function AntiCheat:addStrategy(strategy)
	assert(type(strategy) == "table" and strategy.check,
		"AntiCheat:addStrategy expects a DetectionStrategy with a :check method")
	table_insert(self.strategies, strategy)
	return self -- fluent
end

--- Remove a detection strategy by name
---@param self AntiCheat
---@param name string Strategy name to remove
---@return boolean removed True if strategy was found and removed
function AntiCheat:removeStrategy(name)
	for i, s in next, self.strategies do
		if s.name == name then
			table_remove(self.strategies, i)
			return true
		end
	end
	return false
end

--- Remove all tracking data for a player
---@param self AntiCheat
---@param playerId any Unique player identifier to remove
function AntiCheat:removePlayer(playerId)
	self.tracks[playerId] = nil
end

--- Update player with new movement data and run detection
---@param self AntiCheat
---@param playerId any Unique player identifier
---@param sample PlayerSnapshot|table New movement snapshot
---@return number score Updated violation score
function AntiCheat:updatePlayer(playerId, sample)
	local tr   = self:getTrack(playerId)
	local last = tr:latest()

	-- score decay
	if last and sample and sample.t and last.t then
		local dt = math_max(0, sample.t - last.t)
		tr.score = math_max(0, tr.score - self.decay_per_second * dt)
	end

	tr:addSample(sample)

	local ctx = {
		ac     = self,
		track  = tr,
		model  = tr.model,
		sample = tr:latest(),
		prev   = tr:prev(),
	}

	for i = 1, #self.strategies do
		local strat = self.strategies[i]
		if strat.enabled then
			local ok, v = pcall(strat.check, strat, ctx)
			if ok and v then
				v.severity = Util.clamp(v.severity, 0, strat.severityCap)
				tr.score = Util.clamp(tr.score + v.severity, 0, self.max_score)
				tr:recordViolation(v)
				self.eventBus:emit("violation", { playerId = playerId, violation = v })
				if self.on_violation then pcall(self.on_violation, playerId, v) end
			elseif not ok then
				self.eventBus:emit("strategy_error",
					{ playerId = playerId, strategy = strat.name, error = v })
			end
		end
	end

	return tr.score
end

--- Recommend action based on player's violation score
---@param self AntiCheat
---@param playerId any Unique player identifier
---@return string action Recommended action ("none", "kick", "ban")
---@return number score Current violation score
function AntiCheat:recommendAction(playerId)
	local tr = self.tracks[playerId]
	if not tr then return "none", 0 end
	if tr.score >= self.ban_score then return "ban", tr.score end
	if tr.score >= self.kick_score then return "kick", tr.score end
	return "none", tr.score
end

--- Get current violation score for a player
---@param self AntiCheat
---@param playerId any Unique player identifier
---@return number score Current violation score
function AntiCheat:getPlayerScore(playerId)
	local tr = self.tracks[playerId]
	return tr and tr.score or 0
end

--- Get violation count breakdown for a player
---@param self AntiCheat
---@param playerId any Unique player identifier
---@return table counts Violation counts by type
function AntiCheat:getViolationCounts(playerId)
	local tr = self.tracks[playerId]
	return tr and Util.shallow_copy(tr.state.violationCounts) or {}
end

----------------------------------------------------------------------
-- SECTION: EVIDENCE PIPELINE
----------------------------------------------------------------------

--- Evidence record: small, structured, loggable detection output
---@class Evidence
---@field kind string Evidence type (e.g. "speed", "teleport", "aim_snap")
---@field severity number Normalized severity 0..1
---@field t number Timestamp when evidence was generated
---@field data table Contextual fields (weapon, distance, ping, etc.)
local Evidence = class("Evidence")

--- Create a new evidence record
---@param self Evidence
---@param kind string Evidence type
---@param severity number Severity 0..1
---@param data? table Additional context
---@param t? number Timestamp (default: `os.clock()`)
function Evidence:init(kind, severity, data, t)
	self.kind = kind or "unknown"
	self.severity = Util.clamp(tonumber(severity) or 0, 0, 1)
	self.data = data or {}
	self.t = t or Util.now()
end

--- Create evidence record - utility function
---@param kind string Evidence type
---@param severity number Severity 0..1
---@param data? table Additional context
---@param t? number Timestamp (default: `os.clock()`)
---@return Evidence evidence New evidence record
local function createEvidence(kind, severity, data, t)
	return Evidence(kind, severity, data, t)
end

----------------------------------------------------------------------
-- SECTION: ORCHESTRATOR WITH EVIDENCE PIPELINE
----------------------------------------------------------------------

--- Orchestrator for evidence-first detection with decay and cooldowns
---@class Orchestrator
---@field cfg table Configuration (weights, thresholds, decay, cooldowns)
---@field detectors table Array of detector instances
---@field actions table Action callbacks (warn, kick, ban, flag)
---@field state table Per-player state (score, history, cooldowns)
local Orchestrator = class("Orchestrator")

--- Initialize orchestrator with configuration
---@param self Orchestrator
---@param cfg table Configuration options
---@param detectors table Array of detector instances
---@param actions table Action callbacks
function Orchestrator:init(cfg, detectors, actions)
	self.cfg = cfg or {}
	self.detectors = detectors or {}
	self.actions = actions or {}
	self.state = {} -- per-player state
end

--- Get or create player state
---@param self Orchestrator
---@param pid any Player ID
---@return table state Player state
function Orchestrator:_pstate(pid)
	local s = self.state[pid]
	if not s then
		s = {
			score = 0.0,
			lastActionAt = 0.0,
			lastEvidence = {},
			evidenceHistory = {}
		}
		self.state[pid] = s
	end
	return s
end

--- Process player snapshot through all detectors and decide actions
---@param self Orchestrator
---@param pid any Player ID
---@param snapshot PlayerSnapshot Current player state
---@param dt number Time delta since last update
---@return string? action Action taken (warn, kick, ban, flag, or nil)
function Orchestrator:step(pid, snapshot, dt)
	local ps = self:_pstate(pid)

	-- Apply score decay
	local decay = self.cfg.scoreDecayPerSec or 0.15
	if dt and dt > 0 then
		ps.score = math_max(0.0, ps.score - decay * dt)
	end

	-- Run detectors -> gather evidence
	local newEvidence = {}
	for i = 1, #self.detectors do
		local det = self.detectors[i]
		if det.observe and type(det.observe) == "function" then
			local ok, ev = pcall(det.observe, det, pid, snapshot, dt)
			if ok and ev then
				if type(ev) == "table" then
					for j = 1, #ev do
						local e = ev[j]
						if e and e.kind and e.severity then
							table_insert(newEvidence, e)
						end
					end
				end
			elseif not ok then
				-- Log detector error
				if self.actions.onError then
					self.actions.onError(pid, det.name or "unknown", ev)
				end
			end
		end
	end

	-- Update score based on evidence
	for i = 1, #newEvidence do
		local e = newEvidence[i]
		local weight = self.cfg.weights and self.cfg.weights[e.kind] or 1.0
		ps.score = ps.score + weight * e.severity

		-- Store evidence with context
		table_insert(ps.lastEvidence, e)
		table_insert(ps.evidenceHistory, e)

		-- Limit evidence history size
		if #ps.evidenceHistory > 100 then
			table_remove(ps.evidenceHistory, 1)
		end
	end

	-- Limit last evidence size
	if #ps.lastEvidence > 50 then
		for i = 1, #ps.lastEvidence - 50 do
			table_remove(ps.lastEvidence, 1)
		end
	end

	-- Decide action with cooldown + thresholds
	local now = Util.now()
	local cooldown = self.cfg.actionCooldownSec or 3.0
	if now - ps.lastActionAt < cooldown then
		return nil
	end

	local thresholds = self.cfg.thresholds or {}
	if ps.score >= (thresholds.ban or 9.0) then
		ps.lastActionAt = now
		if self.actions.ban then
			return self.actions.ban(pid, ps.score, ps.lastEvidence)
		end
	elseif ps.score >= (thresholds.kick or 5.0) then
		ps.lastActionAt = now
		if self.actions.kick then
			return self.actions.kick(pid, ps.score, ps.lastEvidence)
		end
	elseif ps.score >= (thresholds.warn or 2.0) then
		ps.lastActionAt = now
		if self.actions.warn then
			return self.actions.warn(pid, ps.score, ps.lastEvidence)
		end
	elseif ps.score >= (thresholds.flag or 1.0) then
		ps.lastActionAt = now
		if self.actions.flag then
			return self.actions.flag(pid, ps.score, ps.lastEvidence)
		end
	end

	return nil
end

--- Reset player state
---@param self Orchestrator
---@param pid any Player ID
function Orchestrator:reset(pid)
	self.state[pid] = nil
	-- Also reset detectors if they support it
	for i = 1, #self.detectors do
		local det = self.detectors[i]
		if det.reset and type(det.reset) == "function" then
			pcall(det.reset, det, pid)
		end
	end
end

--- Update configuration and notify detectors
---@param self Orchestrator
---@param newCfg table New configuration
function Orchestrator:setConfig(newCfg)
	-- Validate configuration
	local validated = self:_validateConfig(newCfg)
	self.cfg = validated

	-- Notify detectors of config change
	for i = 1, #self.detectors do
		local det = self.detectors[i]
		if det.onConfig and type(det.onConfig) == "function" then
			pcall(det.onConfig, det, validated)
		end
	end
end

--- Validate configuration bounds
---@param self Orchestrator
---@param cfg table Configuration to validate
---@return table validated Validated configuration
function Orchestrator:_validateConfig(cfg)
	local validated             = Util.shallow_copy(cfg)

	-- Clamp thresholds to reasonable ranges
	validated.thresholds        = validated.thresholds or {}
	validated.thresholds.warn   = Util.clamp(validated.thresholds.warn or 2.0, 0.0, 999.0)
	validated.thresholds.kick   = Util.clamp(validated.thresholds.kick or 5.0, 0.0, 999.0)
	validated.thresholds.ban    = Util.clamp(validated.thresholds.ban or 9.0, 0.0, 999.0)
	validated.thresholds.flag   = Util.clamp(validated.thresholds.flag or 1.0, 0.0, 999.0)

	-- Validate other parameters
	validated.scoreDecayPerSec  = Util.clamp(validated.scoreDecayPerSec or 0.15, 0.0, 10.0)
	validated.actionCooldownSec = Util.clamp(validated.actionCooldownSec or 3.0, 0.1, 60.0)

	return validated
end

--- Get current player score
---@param self Orchestrator
---@param pid any Player ID
---@return number score Current player score
function Orchestrator:getPlayerScore(pid)
	local ps = self.state[pid]
	return ps and ps.score or 0.0
end

--- Get player evidence history
---@param self Orchestrator
---@param pid any Player ID
---@param maxCount? integer Maximum evidence items to return
---@return table evidence Array of evidence records
function Orchestrator:getPlayerEvidence(pid, maxCount)
	local ps = self.state[pid]
	if not ps then return {} end

	local history = ps.evidenceHistory
	if maxCount and maxCount > 0 and #history > maxCount then
		local result = {}
		local startIdx = #history - maxCount + 1
		for i = startIdx, #history do
			table_insert(result, history[i])
		end
		return result
	end

	return Util.shallow_copy(history)
end

M.Server = {
	Violation                = Violation,
	MovementModel            = MovementModel,
	PlayerTrack              = PlayerTrack,
	DetectionStrategy        = DetectionStrategy,
	AntiCheat                = AntiCheat,
	Evidence                 = Evidence,
	createEvidence           = createEvidence,
	Orchestrator             = Orchestrator,
	Detector                 = Detector,
	BaselinesConfig          = BaselinesConfig,
	EnhancedMovementDetector = EnhancedMovementDetector,
	AimDetector              = AimDetector,
	WeaponAbuseDetector      = WeaponAbuseDetector,
	ConfigManager            = ConfigManager,
	AnalyticsCollector       = AnalyticsCollector,
	ClientGuardHardening     = ClientGuardHardening,
	EnhancedRingBuffer       = EnhancedRingBuffer,
	DeterministicSnapshot    = DeterministicSnapshot,
}

----------------------------------------------------------------------
-- SECTION: DETECTOR INTERFACE
----------------------------------------------------------------------

--- Base detector interface for strict modular detection
---@class Detector
---@field name string Detector identifier
---@field enabled boolean Whether detector is active
---@field cfg table Current configuration
local Detector = class("Detector")

--- Initialize detector with name and configuration
---@param self Detector
---@param name string Detector name
---@param opts? table Configuration options
function Detector:init(name, opts)
	self.name = name or "detector"
	self.enabled = Util.get_opt(opts, "enabled", true)
	self.cfg = opts or {}
end

--- Observe player and return evidence array - must be implemented
---@param self Detector
---@param playerId any Player ID
---@param snapshot PlayerSnapshot Current player state
---@param dt number Time delta
---@return table? evidence Array of evidence records or nil
function Detector:observe(playerId, snapshot, dt)
	return error("Detector:observe() must be implemented by subclass")
end

--- Reset detector state for specific player - optional override
---@param self Detector
---@param playerId any Player ID to reset
function Detector:reset(playerId)
	-- Default: no-op, override if detector has per-player state
end

--- Handle configuration update - optional override
---@param self Detector
---@param newCfg table New configuration
function Detector:onConfig(newCfg)
	self.cfg = newCfg or {}
end

----------------------------------------------------------------------
-- SECTION: PER-WEAPON/PER-MOVEMENT BASELINES
----------------------------------------------------------------------

--- Configuration baselines keyed by weapon and movement state
---@class BaselinesConfig
---@field weapons table Weapon-specific parameters
---@field movement table Movement state parameters
---@field global table Global fallback parameters
local BaselinesConfig = class("BaselinesConfig")

--- Initialize baselines configuration
---@param self BaselinesConfig
---@param cfg? table Configuration data
function BaselinesConfig:init(cfg)
	cfg = cfg or {}

	-- Weapon-specific baselines
	self.weapons = cfg.weapons or {
		pistol = {
			maxFireRate = 12.0, -- shots per second
			recoilRecoveryTime = 0.2,
			aimSpeedLimit = 180.0, -- degrees per second
		},
		rifle = {
			maxFireRate = 8.0,
			recoilRecoveryTime = 0.3,
			aimSpeedLimit = 120.0,
		},
		sniper = {
			maxFireRate = 2.0,
			recoilRecoveryTime = 0.8,
			aimSpeedLimit = 60.0,
		},
		shotgun = {
			maxFireRate = 1.5,
			recoilRecoveryTime = 0.6,
			aimSpeedLimit = 90.0,
		},
	}

	-- Movement state baselines
	self.movement = cfg.movement or {
		walking = {
			maxSpeed = 16.0,
			maxAcceleration = 120.0,
			turnRateLimit = 360.0,
		},
		sprinting = {
			maxSpeed = 24.0,
			maxAcceleration = 180.0,
			turnRateLimit = 270.0,
		},
		crouching = {
			maxSpeed = 8.0,
			maxAcceleration = 80.0,
			turnRateLimit = 180.0,
		},
		airborne = {
			maxSpeed = 60.0,
			maxAcceleration = 200.0,
			turnRateLimit = 720.0,
		},
		swimming = {
			maxSpeed = 12.0,
			maxAcceleration = 60.0,
			turnRateLimit = 240.0,
		},
	}

	-- Global fallback parameters
	self.global = cfg.global or {
		defaultMaxSpeed = 30.0,
		defaultMaxAcceleration = 150.0,
		defaultTurnRate = 360.0,
		defaultFireRate = 10.0,
		positionEpsilon = 0.05,
		velocityEpsilon = 0.1,
		angleEpsilon = 1.0,
	}
end

--- Get weapon-specific baseline with fallback to global
---@param self BaselinesConfig
---@param weaponId string Weapon identifier
---@param parameter string Parameter name
---@return any value Parameter value or global fallback
function BaselinesConfig:getWeaponBaseline(weaponId, parameter)
	local weapon = self.weapons[weaponId]
	if weapon and weapon[parameter] ~= nil then
		return weapon[parameter]
	end
	return self.global["default" .. parameter:sub(1, 1):upper() .. parameter:sub(2)]
end

--- Get movement-specific baseline with fallback to global
---@param self BaselinesConfig
---@param movementState string Movement state (walking, sprinting, etc.)
---@param parameter string Parameter name
---@return any value Parameter value or global fallback
function BaselinesConfig:getMovementBaseline(movementState, parameter)
	local movement = self.movement[movementState]
	if movement and movement[parameter] ~= nil then
		return movement[parameter]
	end
	return self.global["default" .. parameter:sub(1, 1):upper() .. parameter:sub(2)]
end

--- Get combined baseline for weapon+movement state
---@param self BaselinesConfig
---@param weaponId string Weapon identifier
---@param movementState string Movement state
---@param parameter string Parameter name
---@return any value Parameter value with appropriate fallbacks
function BaselinesConfig:getCombinedBaseline(weaponId, movementState, parameter)
	-- Try weapon-specific first
	local weapon = self.weapons[weaponId]
	if weapon and weapon[parameter] ~= nil then
		return weapon[parameter]
	end

	-- Try movement-specific
	local movement = self.movement[movementState]
	if movement and movement[parameter] ~= nil then
		return movement[parameter]
	end

	-- Fall back to global
	return self.global["default" .. parameter:sub(1, 1):upper() .. parameter:sub(2)]
end

--- Update baseline configuration with validation
---@param self BaselinesConfig
---@param newCfg table New configuration
---@param validate boolean Whether to validate bounds
function BaselinesConfig:update(newCfg, validate)
	validate = validate ~= false -- default to true

	if newCfg.weapons then
		for weaponId, params in next, newCfg.weapons do
			if not self.weapons[weaponId] then
				self.weapons[weaponId] = {}
			end
			for param, value in next, params do
				if validate and type(value) == "number" then
					-- Apply reasonable bounds
					if param == "maxFireRate" then
						value = Util.clamp(value, 0.1, 30.0)
					elseif param == "recoilRecoveryTime" then
						value = Util.clamp(value, 0.05, 2.0)
					elseif param == "aimSpeedLimit" then
						value = Util.clamp(value, 30.0, 1080.0)
					end
				end
				self.weapons[weaponId][param] = value
			end
		end
	end

	if newCfg.movement then
		for state, params in next, newCfg.movement do
			if not self.movement[state] then
				self.movement[state] = {}
			end
			for param, value in next, params do
				if validate and type(value) == "number" then
					-- Apply reasonable bounds
					if param == "maxSpeed" then
						value = Util.clamp(value, 1.0, 200.0)
					elseif param == "maxAcceleration" then
						value = Util.clamp(value, 10.0, 500.0)
					elseif param == "turnRateLimit" then
						value = Util.clamp(value, 60.0, 1440.0)
					end
				end
				self.movement[state][param] = value
			end
		end
	end

	if newCfg.global then
		for param, value in next, newCfg.global do
			if validate and type(value) == "number" then
				-- Apply reasonable bounds for global parameters
				if string_find(param, "Speed") then
					value = Util.clamp(value, 1.0, 200.0)
				elseif string_find(param, "Acceleration") then
					value = Util.clamp(value, 10.0, 500.0)
				elseif string_find(param, "Turn") or string_find(param, "Rate") then
					value = Util.clamp(value, 60.0, 1440.0)
				elseif string_find(param, "Epsilon") then
					value = Util.clamp(value, 0.001, 1.0)
				end
			end
			self.global[param] = value
		end
	end
end

----------------------------------------------------------------------
-- SECTION: SERVER - DETECTION STRATEGIES
----------------------------------------------------------------------

--- Speed hack detection strategy
---@class SpeedHackDetection : DetectionStrategy
---@field walk_margin number Tolerance multiplier for walking speed
---@field sprint_margin number Tolerance multiplier for sprinting speed
---@field min_dt number Minimum time delta for validation
---@field severity_scale number Severity scaling factor
local SpeedHackDetection = class("SpeedHackDetection", DetectionStrategy)

--- Initialize speed hack detection
---@param self SpeedHackDetection
---@param opts? table Configuration options
function SpeedHackDetection:init(opts)
	DetectionStrategy.init(self, "speed", opts)
	opts                = opts or {}
	self.walk_margin    = Util.get_opt(opts, "walk_margin", 1.25)
	self.sprint_margin  = Util.get_opt(opts, "sprint_margin", 1.20)
	self.min_dt         = Util.get_opt(opts, "min_dt", 0.05)
	self.severity_scale = Util.get_opt(opts, "severity_scale", 6)
end

--- Check for speed hack violations
---@param self SpeedHackDetection
---@param ctx table Detection context
---@return Violation? violation Speed hack violation or nil
function SpeedHackDetection:check(ctx)
	local s, p = ctx.sample, ctx.prev
	local dt = safe_dt(s, p, self.min_dt)
	if not dt then return end

	local dx, _, dz = pos_delta(s, p)
	local speed = Util.len2(dx, dz) / dt

	local meta = s.meta or {}
	local maxAllowed = ctx.model.max_walk_speed * self.walk_margin
	if meta.sprinting then maxAllowed = ctx.model.max_sprint_speed * self.sprint_margin end

	if speed > maxAllowed then
		local over = speed / math_max(0.001, maxAllowed)
		return Violation("speed", (over - 1) * self.severity_scale, {
			speed = speed,
			maxAllowed = maxAllowed,
			dt = dt,
			dx = dx,
			dz = dz,
			meta = meta,
		}, s.t)
	end
end

--- Teleport detection strategy
---@class TeleportDetection : DetectionStrategy
---@field distance? number Maximum allowed teleport distance (nil = use model)
---@field min_dt number Minimum time delta for validation
---@field severity number Base severity score
---@field ignore_if_server_issued boolean Whether to ignore server-issued teleports
local TeleportDetection = class("TeleportDetection", DetectionStrategy)

--- Initialize teleport detection
---@param self TeleportDetection
---@param opts? table Configuration options
function TeleportDetection:init(opts)
	DetectionStrategy.init(self, "teleport", opts)
	opts                         = opts or {}
	self.distance                = opts.distance
	self.min_dt                  = Util.get_opt(opts, "min_dt", 0.05)
	self.severity                = Util.get_opt(opts, "severity", 12)
	self.ignore_if_server_issued = Util.get_opt(opts, "ignore_if_server_issued", true)
end

--- Check for teleport violations
---@param self TeleportDetection
---@param ctx table Detection context
---@return Violation? violation Teleport violation or nil
function TeleportDetection:check(ctx)
	local s, p = ctx.sample, ctx.prev
	local dt = safe_dt(s, p, self.min_dt)
	if not dt then return end

	local dx, dy, dz = pos_delta(s, p)
	local dist = Util.len3(dx, dy, dz)
	local threshold = self.distance or ctx.model.teleport_distance

	local meta = s.meta or {}
	if self.ignore_if_server_issued and meta.serverTeleport then return end

	if dist > threshold then
		return Violation("teleport", self.severity, {
			dist = dist,
			threshold = threshold,
			dt = dt,
			from = { p.x, p.y, p.z },
			to = { s.x, s.y, s.z },
			meta = meta,
		}, s.t)
	end
end

----------------------------------------------------------------------
-- SECTION: ENHANCED MOVEMENT DETECTION
----------------------------------------------------------------------

--- Enhanced movement detector with physics-consistent checks and lag compensation
---@class EnhancedMovementDetector : Detector
---@field baselines BaselinesConfig Weapon/movement baselines
---@field snapshotBuffer table Per-player snapshot history
---@field lagWindowMs number Lag compensation window in milliseconds
---@field minSamples number Minimum samples for evaluation
local EnhancedMovementDetector = class("EnhancedMovementDetector", Detector)

--- Initialize enhanced movement detector
---@param self EnhancedMovementDetector
---@param opts? table Configuration options
function EnhancedMovementDetector:init(opts)
	Detector.init(self, "enhanced_movement", opts)
	opts = opts or {}

	self.baselines = BaselinesConfig(opts.baselines)
	self.snapshotBuffer = {}                                 -- per-player ring buffers
	self.lagWindowMs = Util.get_opt(opts, "lagWindowMs", 500) -- 500ms window
	self.minSamples = Util.get_opt(opts, "minSamples", 3)
end

--- Get or create player snapshot buffer
---@param self EnhancedMovementDetector
---@param playerId any Player ID
---@return SnapshotBuffer buffer Player's snapshot history
function EnhancedMovementDetector:_getBuffer(playerId)
	if not self.snapshotBuffer[playerId] then
		self.snapshotBuffer[playerId] = SnapshotBuffer(30) -- 30 samples
	end
	return self.snapshotBuffer[playerId]
end

--- Determine movement state from snapshot
---@param self EnhancedMovementDetector
---@param snapshot PlayerSnapshot Player state
---@return string state Movement state
function EnhancedMovementDetector:_getMovementState(snapshot)
	local meta = snapshot.meta or {}

	if meta.swimming then
		return "swimming"
	end
	if not snapshot.grounded then
		return "airborne"
	end
	if meta.crouching then
		return "crouching"
	end
	if meta.sprinting then
		return "sprinting"
	end
	return "walking"
end

--- Validate position delta against physics constraints
---@param self EnhancedMovementDetector
---@param current PlayerSnapshot Current snapshot
---@param previous PlayerSnapshot Previous snapshot
---@param dt number Time delta
---@return table? violations Array of evidence or nil
function EnhancedMovementDetector:_validatePositionDelta(current, previous, dt)
	if not dt or dt <= 0 then return nil end

	local violations = {}
	local movementState = self:_getMovementState(current)
	local meta = current.meta or {}

	-- Get appropriate baselines
	local maxSpeed = self.baselines:getMovementBaseline(movementState, "maxSpeed")
	local maxAccel = self.baselines:getMovementBaseline(movementState, "maxAcceleration")

	-- Calculate position and velocity deltas
	local dx, dy, dz = pos_delta(current, previous)
	local dvx, dvy, dvz = (current.vx or 0) - (previous.vx or 0),
			(current.vy or 0) - (previous.vy or 0),
			(current.vz or 0) - (previous.vz or 0)

	-- Speed validation
	local speed = Util.len3(dx, dy, dz) / dt
	if speed > maxSpeed then
		local severity = Util.clamp((speed - maxSpeed) / maxSpeed, 0, 1)
		table_insert(violations, createEvidence("speed_excess", severity, {
			speed = speed,
			maxSpeed = maxSpeed,
			movementState = movementState,
			dt = dt,
			ping = meta.ping or 0,
		}, current.t))
	end

	-- Acceleration validation
	local accel = Util.len3(dvx, dvy, dvz) / dt
	if accel > maxAccel then
		local severity = Util.clamp((accel - maxAccel) / maxAccel, 0, 1)
		table_insert(violations, createEvidence("acceleration_excess", severity, {
			acceleration = accel,
			maxAcceleration = maxAccel,
			movementState = movementState,
			dt = dt,
			ping = meta.ping or 0,
		}, current.t))
	end

	-- Turn rate validation
	if current.yaw and previous.yaw then
		local dyaw = math_abs(current.yaw - previous.yaw)
		-- Handle angle wrapping
		if dyaw > 180 then dyaw = 360 - dyaw end
		local turnRate = dyaw / dt
		local maxTurnRate = self.baselines:getMovementBaseline(movementState, "turnRateLimit")

		if turnRate > maxTurnRate then
			local severity = Util.clamp((turnRate - maxTurnRate) / maxTurnRate, 0, 1)
			table_insert(violations, createEvidence("turn_rate_excess", severity, {
				turnRate = turnRate,
				maxTurnRate = maxTurnRate,
				movementState = movementState,
				dt = dt,
				ping = meta.ping or 0,
			}, current.t))
		end
	end

	return Util.when(#violations > 0, violations)
end

--- Evaluate player over lag compensation window
---@param self EnhancedMovementDetector
---@param playerId any Player ID
---@param currentSnapshot PlayerSnapshot Current snapshot
---@return table? violations Array of evidence or nil
function EnhancedMovementDetector:_evaluateOverWindow(playerId, currentSnapshot)
	local buffer = self:_getBuffer(playerId)
	local count = buffer:count()

	if count < self.minSamples then return nil end

	local violations = {}
	local windowStart = currentSnapshot.t - (self.lagWindowMs / 1000.0)

	-- Get samples in window
	local windowSamples = {}
	for i = 1, count do
		local sample = buffer:get(i)
		if sample and sample.t >= windowStart then
			table_insert(windowSamples, sample)
		end
	end

	if #windowSamples < self.minSamples then return nil end

	-- Evaluate patterns over window
	local totalSpeed = 0
	local maxSpeed = 0
	local speedSamples = 0

	for i = 2, #windowSamples do
		local prev = windowSamples[i - 1]
		local curr = windowSamples[i]
		local dt = curr.t - prev.t

		if dt > 0.01 then -- minimum dt threshold
			local dx, dy, dz = pos_delta(curr, prev)
			local speed = Util.len3(dx, dy, dz) / dt
			totalSpeed = totalSpeed + speed
			maxSpeed = math_max(maxSpeed, speed)
			speedSamples = speedSamples + 1
		end
	end

	if speedSamples > 0 then
		local avgSpeed = totalSpeed / speedSamples
		local movementState = self:_getMovementState(currentSnapshot)
		local baselineSpeed = self.baselines:getMovementBaseline(movementState, "maxSpeed")

		-- Check for sustained high speed
		if avgSpeed > baselineSpeed * 1.5 then
			local severity = Util.clamp((avgSpeed - baselineSpeed) / baselineSpeed, 0, 1)
			table_insert(violations, createEvidence("sustained_speed", severity, {
				averageSpeed = avgSpeed,
				maxSpeed = maxSpeed,
				baselineSpeed = baselineSpeed,
				movementState = movementState,
				windowSize = #windowSamples,
				ping = currentSnapshot.meta.ping or 0,
			}, currentSnapshot.t))
		end

		-- Check for speed consistency (possible speed hack)
		local speedVariance = 0
		for i = 2, #windowSamples do
			local prev = windowSamples[i - 1]
			local curr = windowSamples[i]
			local dt = curr.t - prev.t

			if dt > 0.01 then
				local dx, dy, dz = pos_delta(curr, prev)
				local speed = Util.len3(dx, dy, dz) / dt
				speedVariance = speedVariance + (speed - avgSpeed) * (speed - avgSpeed)
			end
		end

		if speedSamples > 1 then
			speedVariance = speedVariance / (speedSamples - 1)
			local stdDev = math_sqrt(speedVariance)

			-- Very low variance + high speed = potential speed hack
			if stdDev < avgSpeed * 0.1 and avgSpeed > baselineSpeed * 1.2 then
				local severity = Util.clamp((avgSpeed / baselineSpeed - 1.2) * 2, 0, 1)
				table_insert(violations, createEvidence("unnatural_consistency", severity, {
					averageSpeed = avgSpeed,
					speedStdDev = stdDev,
					baselineSpeed = baselineSpeed,
					movementState = movementState,
					windowSize = #windowSamples,
					ping = currentSnapshot.meta.ping or 0,
				}, currentSnapshot.t))
			end
		end
	end

	return Util.when(#violations > 0, violations)
end

--- Observe player and return movement evidence
---@param self EnhancedMovementDetector
---@param playerId any Player ID
---@param snapshot PlayerSnapshot Current player state
---@param dt number Time delta
---@return table? evidence Array of evidence records or nil
function EnhancedMovementDetector:observe(playerId, snapshot, dt)
	if not self.enabled then return nil end

	local buffer = self:_getBuffer(playerId)
	local previous = buffer:latest()

	-- Add current snapshot to buffer
	buffer:push(snapshot)

	-- If no previous data, return nil
	if not previous then return nil end

	local allViolations = {}

	-- Validate immediate position delta
	local immediateViolations = self:_validatePositionDelta(snapshot, previous, dt)
	if immediateViolations then
		for i = 1, #immediateViolations do
			table_insert(allViolations, immediateViolations[i])
		end
	end

	-- Evaluate over lag compensation window
	local windowViolations = self:_evaluateOverWindow(playerId, snapshot)
	if windowViolations then
		for i = 1, #windowViolations do
			table_insert(allViolations, windowViolations[i])
		end
	end

	return Util.when(#allViolations > 0, allViolations)
end

--- Reset detector state for player
---@param self EnhancedMovementDetector
---@param playerId any Player ID
function EnhancedMovementDetector:reset(playerId)
	self.snapshotBuffer[playerId] = nil
end

--- Handle configuration update
---@param self EnhancedMovementDetector
---@param newCfg table New configuration
function EnhancedMovementDetector:onConfig(newCfg)
	Detector.onConfig(self, newCfg)

	if newCfg.baselines then
		self.baselines:update(newCfg.baselines)
	end

	if newCfg.lagWindowMs then
		self.lagWindowMs = Util.clamp(newCfg.lagWindowMs, 100, 2000)
	end

	if newCfg.minSamples then
		self.minSamples = Util.clamp(newCfg.minSamples, 2, 10)
	end
end

----------------------------------------------------------------------
-- SECTION: AIM DETECTION WITH MULTI-SIGNAL AGREEMENT
----------------------------------------------------------------------

--- Aim detector using multi-signal agreement and robust statistics
---@class AimDetector : Detector
---@field baselines BaselinesConfig Weapon/movement baselines
---@field aimHistory table Per-player aim tracking data
---@field populationStats table Population-level statistics for comparison
---@field minEngagements number Minimum engagements before statistical analysis
---@field signalAgreementThreshold number Threshold for multi-signal agreement
local AimDetector = class("AimDetector", Detector)

--- Initialize aim detector
---@param self AimDetector
---@param opts? table Configuration options
function AimDetector:init(opts)
	Detector.init(self, "aim_detection", opts)
	opts = opts or {}

	self.baselines = BaselinesConfig(opts.baselines)
	self.aimHistory = {} -- per-player tracking
	self.minEngagements = Util.get_opt(opts, "minEngagements", 5)
	self.signalAgreementThreshold = Util.get_opt(opts, "signalAgreementThreshold", 0.7)

	-- Population statistics for robust comparison
	self.populationStats = {
		avgAimSpeed = 120.0, -- degrees per second
		avgSnapAngle = 15.0, -- degrees
		avgTimeToTarget = 0.3, -- seconds
		headshotRatioByDistance = {
			close = 0.4,       -- < 10m
			medium = 0.25,     -- 10-30m
			far = 0.15,        -- > 30m
		}
	}
end

--- Get or create player aim tracking data
---@param self AimDetector
---@param playerId any Player ID
---@return table data Player aim tracking data
function AimDetector:_getPlayerData(playerId)
	if not self.aimHistory[playerId] then
		self.aimHistory[playerId] = {
			engagements = {},
			aimSpeeds = {},
			snapAngles = {},
			timeToTargets = {},
			headshots = 0,
			totalShots = 0,
			lastAngles = nil,
			lastTargetTime = nil,
		}
	end
	return self.aimHistory[playerId]
end

--- Calculate distance between two positions
---@param self AimDetector
---@param pos1 table Position 1 {x, y, z}
---@param pos2 table Position 2 {x, y, z}
---@return number distance 3D distance
function AimDetector:_calculateDistance(pos1, pos2)
	if not pos1 or not pos2 then return 0 end
	local dx, dy, dz = pos1.x - pos2.x, pos1.y - pos2.y, pos1.z - pos2.z
	return Util.len3(dx, dy, dz)
end

--- Detect aim snap events
---@param self AimDetector
---@param currentYaw number Current yaw angle
---@param currentPitch number Current pitch angle
---@param previousYaw number Previous yaw angle
---@param previousPitch number Previous pitch angle
---@param dt number Time delta
---@return table? evidence Aim snap evidence or nil
function AimDetector:_detectAimSnap(currentYaw, currentPitch, previousYaw, previousPitch, dt)
	if not dt or dt <= 0 then return nil end

	-- Calculate angle changes
	local dyaw = math_abs(currentYaw - previousYaw)
	local dpitch = math_abs(currentPitch - previousPitch)

	-- Handle angle wrapping for yaw
	if dyaw > 180 then dyaw = 360 - dyaw end

	local totalAngleChange = math_sqrt(dyaw * dyaw + dpitch * dpitch)
	local angularSpeed = totalAngleChange / dt

	-- Check for snap (sudden large angle change at high speed)
	local snapThreshold = 90.0  -- degrees
	local speedThreshold = 720.0 -- degrees per second

	if totalAngleChange > snapThreshold and angularSpeed > speedThreshold then
		local severity = Util.clamp((angularSpeed - speedThreshold) / speedThreshold, 0, 1)
		return createEvidence("aim_snap", severity, {
			angleChange = totalAngleChange,
			angularSpeed = angularSpeed,
			snapThreshold = snapThreshold,
			speedThreshold = speedThreshold,
			dt = dt,
		})
	end

	return nil
end

--- Analyze aim patterns using robust statistics
---@param self AimDetector
---@param playerId any Player ID
---@return table? evidence Statistical evidence or nil
function AimDetector:_analyzeAimPatterns(playerId)
	local data = self:_getPlayerData(playerId)

	if #data.engagements < self.minEngagements then return nil end

	local violations = {}

	-- Calculate robust statistics (median + MAD)
	local function median(values)
		if #values == 0 then return 0 end
		table_sort(values)
		local mid = math_floor(#values / 2)
		if #values % 2 == 0 then
			return (values[mid] + values[mid + 1]) / 2
		else
			return values[mid + 1]
		end
	end

	local function mad(values, medianVal)
		if #values == 0 then return 0 end
		local deviations = {}
		for i = 1, #values do
			table_insert(deviations, math_abs(values[i] - medianVal))
		end
		return median(deviations)
	end

	-- Analyze aim speed consistency
	local medianAimSpeed = median(data.aimSpeeds)
	local aimSpeedMAD = mad(data.aimSpeeds, medianAimSpeed)

	-- Very low MAD + high speed = potential aimbot
	if aimSpeedMAD < medianAimSpeed * 0.2 and medianAimSpeed > self.populationStats.avgAimSpeed * 1.5 then
		local severity = Util.clamp((medianAimSpeed / self.populationStats.avgAimSpeed - 1.5) * 2, 0, 1)
		table_insert(violations, createEvidence("unnatural_aim_consistency", severity, {
			medianAimSpeed = medianAimSpeed,
			aimSpeedMAD = aimSpeedMAD,
			populationAvg = self.populationStats.avgAimSpeed,
			sampleCount = #data.aimSpeeds,
		}))
	end

	-- Analyze snap frequency
	local medianSnapAngle = median(data.snapAngles)
	if medianSnapAngle > self.populationStats.avgSnapAngle * 2 then
		local severity = Util.clamp((medianSnapAngle / self.populationStats.avgSnapAngle - 2) * 0.5, 0, 1)
		table_insert(violations, createEvidence("excessive_snapping", severity, {
			medianSnapAngle = medianSnapAngle,
			populationAvg = self.populationStats.avgSnapAngle,
			sampleCount = #data.snapAngles,
		}))
	end

	-- Analyze time-to-target consistency
	local medianTimeToTarget = median(data.timeToTargets)
	local timeToTargetMAD = mad(data.timeToTargets, medianTimeToTarget)

	if timeToTargetMAD < medianTimeToTarget * 0.15 and medianTimeToTarget < self.populationStats.avgTimeToTarget * 0.5 then
		local severity = Util.clamp((self.populationStats.avgTimeToTarget / medianTimeToTarget - 2) * 0.3, 0, 1)
		table_insert(violations, createEvidence("superhuman_reflexes", severity, {
			medianTimeToTarget = medianTimeToTarget,
			timeToTargetMAD = timeToTargetMAD,
			populationAvg = self.populationStats.avgTimeToTarget,
			sampleCount = #data.timeToTargets,
		}))
	end

	-- Analyze headshot ratio by distance
	if data.totalShots >= 10 then
		local headshotRatio = data.headshots / data.totalShots
		local expectedRatio = self.populationStats.headshotRatioByDistance.medium -- default to medium

		-- This would need distance information from engagement data
		if headshotRatio > expectedRatio * 2.5 then
			local severity = Util.clamp((headshotRatio / expectedRatio - 2.5) * 0.4, 0, 1)
			table_insert(violations, createEvidence("suspicious_headshot_ratio", severity, {
				headshotRatio = headshotRatio,
				expectedRatio = expectedRatio,
				totalShots = data.totalShots,
				headshots = data.headshots,
			}))
		end
	end

	return Util.when(#violations > 0, violations)
end

--- Check multi-signal agreement
---@param self AimDetector
---@param playerId any Player ID
---@param newEvidence table New evidence to evaluate
---@return boolean agreed Whether multiple signals agree
function AimDetector:_checkSignalAgreement(playerId, newEvidence)
	local data = self:_getPlayerData(playerId)

	-- Count different signal types in recent evidence
	local signalTypes = {}
	for i = 1, #newEvidence do
		local kind = newEvidence[i].kind
		signalTypes[kind] = (signalTypes[kind] or 0) + 1
	end

	-- Check if we have agreement between multiple signals
	local signalCount = 0
	for _, count in next, signalTypes do
		if count > 0 then signalCount = signalCount + 1 end
	end

	-- Require multiple signals for high confidence
	return signalCount >= 2
end

--- Observe player and return aim evidence
---@param self AimDetector
---@param playerId any Player ID
---@param snapshot PlayerSnapshot Current player state
---@param dt number Time delta
---@return table? evidence Array of evidence records or nil
function AimDetector:observe(playerId, snapshot, dt)
	if not self.enabled then return nil end

	local data = self:_getPlayerData(playerId)
	local meta = snapshot.meta or {}
	local violations = {}

	-- Track aim changes
	if snapshot.yaw and snapshot.pitch then
		local currentAngles = { yaw = snapshot.yaw, pitch = snapshot.pitch }

		if data.lastAngles then
			-- Detect aim snaps
			local snapEvidence = self:_detectAimSnap(
				currentAngles.yaw, currentAngles.pitch,
				data.lastAngles.yaw, data.lastAngles.pitch,
				dt
			)
			if snapEvidence then
				table_insert(violations, snapEvidence)
				table_insert(data.snapAngles, snapEvidence.data.angleChange)
			end

			-- Calculate aim speed
			local dyaw = math_abs(currentAngles.yaw - data.lastAngles.yaw)
			if dyaw > 180 then dyaw = 360 - dyaw end
			local dpitch = math_abs(currentAngles.pitch - data.lastAngles.pitch)
			local totalAngleChange = math_sqrt(dyaw * dyaw + dpitch * dpitch)

			if dt and dt > 0 then
				local aimSpeed = totalAngleChange / dt
				table_insert(data.aimSpeeds, aimSpeed)
			end
		end

		data.lastAngles = currentAngles
	end

	-- Track engagements and shots
	if meta.engagementStart then
		table_insert(data.engagements, {
			startTime = snapshot.t,
			weaponId = meta.weaponId,
		})
		data.lastTargetTime = snapshot.t
	end

	if meta.shotFired then
		data.totalShots = data.totalShots + 1

		-- Calculate time to target if we have engagement data
		if data.lastTargetTime and #data.engagements > 0 then
			local timeToTarget = snapshot.t - data.lastTargetTime
			if timeToTarget > 0 and timeToTarget < 2.0 then -- reasonable bounds
				table_insert(data.timeToTargets, timeToTarget)
			end
		end
	end

	if meta.headshot then
		data.headshots = data.headshots + 1
	end

	-- Analyze patterns if we have enough data
	local patternEvidence = self:_analyzeAimPatterns(playerId)
	if patternEvidence then
		for i = 1, #patternEvidence do
			table_insert(violations, patternEvidence[i])
		end
	end

	-- Check multi-signal agreement
	if #violations > 0 and self:_checkSignalAgreement(playerId, violations) then
		-- Boost severity for multi-signal agreement
		for i = 1, #violations do
			violations[i].severity = Util.clamp(violations[i].severity * 1.5, 0, 1)
			violations[i].data.multiSignalAgreement = true
		end
	end

	-- Limit history size to prevent memory bloat
	if #data.aimSpeeds > 100 then
		for i = 1, #data.aimSpeeds - 100 do
			table_remove(data.aimSpeeds, 1)
		end
	end

	if #data.snapAngles > 50 then
		for i = 1, #data.snapAngles - 50 do
			table_remove(data.snapAngles, 1)
		end
	end

	if #data.timeToTargets > 50 then
		for i = 1, #data.timeToTargets - 50 do
			table_remove(data.timeToTargets, 1)
		end
	end

	return Util.when(#violations > 0, violations)
end

--- Reset detector state for player
---@param self AimDetector
---@param playerId any Player ID
function AimDetector:reset(playerId)
	self.aimHistory[playerId] = nil
end

--- Handle configuration update
---@param self AimDetector
---@param newCfg table New configuration
function AimDetector:onConfig(newCfg)
	Detector.onConfig(self, newCfg)

	if newCfg.baselines then
		self.baselines:update(newCfg.baselines)
	end

	if newCfg.minEngagements then
		self.minEngagements = Util.clamp(newCfg.minEngagements, 3, 20)
	end

	if newCfg.signalAgreementThreshold then
		self.signalAgreementThreshold = Util.clamp(newCfg.signalAgreementThreshold, 0.5, 0.9)
	end

	if newCfg.populationStats then
		for key, value in next, newCfg.populationStats do
			if type(value) == "number" and value > 0 then
				self.populationStats[key] = value
			end
		end
	end
end

----------------------------------------------------------------------
-- SECTION: FIRE-RATE VALIDATION AND WEAPON ABUSE DETECTION
----------------------------------------------------------------------

--- Weapon abuse detector with fire-rate validation and ammo tracking
---@class WeaponAbuseDetector : Detector
---@field baselines BaselinesConfig Weapon-specific parameters
---@field weaponStates table Per-player weapon tracking data
---@field toleranceMs number Tolerance window for fire-rate validation (milliseconds)
---@field maxViolations number Maximum violations before high severity
local WeaponAbuseDetector = class("WeaponAbuseDetector", Detector)

--- Initialize weapon abuse detector
---@param self WeaponAbuseDetector
---@param opts? table Configuration options
function WeaponAbuseDetector:init(opts)
	Detector.init(self, "weapon_abuse", opts)
	opts = opts or {}

	self.baselines = BaselinesConfig(opts.baselines)
	self.weaponStates = {}                                  -- per-player weapon tracking
	self.toleranceMs = Util.get_opt(opts, "toleranceMs", 50) -- 50ms tolerance
	self.maxViolations = Util.get_opt(opts, "maxViolations", 5)
end

--- Get or create player weapon state
---@param self WeaponAbuseDetector
---@param playerId any Player ID
---@return table state Player weapon tracking data
function WeaponAbuseDetector:_getPlayerState(playerId)
	if not self.weaponStates[playerId] then
		self.weaponStates[playerId] = {
			currentWeapon = nil,
			lastShotTime = {}, -- per-weapon
			shotCount = {},   -- per-weapon
			violationCount = {}, -- per-weapon
			ammoHistory = {}, -- ammo delta tracking
			reloadHistory = {}, -- reload time tracking
			lastAmmoCount = nil,
		}
	end
	return self.weaponStates[playerId]
end

--- Validate fire-rate against weapon baselines
---@param self WeaponAbuseDetector
---@param playerId any Player ID
---@param weaponId string Weapon identifier
---@param currentTime number Current timestamp
---@return table? evidence Fire-rate violation evidence or nil
function WeaponAbuseDetector:_validateFireRate(playerId, weaponId, currentTime)
	local state = self:_getPlayerState(playerId)
	local maxFireRate = self.baselines:getWeaponBaseline(weaponId, "maxFireRate")

	if not maxFireRate or maxFireRate <= 0 then return nil end

	local lastShotTime = state.lastShotTime[weaponId]
	if not lastShotTime then return nil end

	local timeSinceLastShot = currentTime - lastShotTime
	local minInterval = 1.0 / maxFireRate -- minimum time between shots
	local toleranceWindow = self.toleranceMs / 1000.0

	-- Check if shot is too fast (even with tolerance)
	if timeSinceLastShot < (minInterval - toleranceWindow) then
		local actualFireRate = 1.0 / timeSinceLastShot
		local severity = Util.clamp((actualFireRate - maxFireRate) / maxFireRate, 0, 1)

		return createEvidence("rapid_fire", severity, {
			weaponId = weaponId,
			actualFireRate = actualFireRate,
			maxFireRate = maxFireRate,
			timeSinceLastShot = timeSinceLastShot,
			minInterval = minInterval,
		}, currentTime)
	end

	return nil
end

--- Detect ammo desync exploits
---@param self WeaponAbuseDetector
---@param playerId any Player ID
---@param currentAmmo number Current ammo count
---@param weaponId string Weapon identifier
---@param currentTime number Current timestamp
---@return table? evidence Ammo desync evidence or nil
function WeaponAbuseDetector:_detectAmmoDesync(playerId, currentAmmo, weaponId, currentTime)
	local state = self:_getPlayerState(playerId)

	if state.lastAmmoCount == nil then
		state.lastAmmoCount = currentAmmo
		return nil
	end

	local ammoDelta = currentAmmo - state.lastAmmoCount
	local meta = state.lastShotMeta or {}

	-- Track ammo changes
	table_insert(state.ammoHistory, {
		delta = ammoDelta,
		time = currentTime,
		weaponId = weaponId,
		shotFired = meta.shotFired or false,
	})

	-- Limit history size
	if #state.ammoHistory > 50 then
		table_remove(state.ammoHistory, 1)
	end

	-- Check for suspicious ammo patterns
	local violations = {}

	-- 1. Ammo increase without reload (possible ammo hack)
	if ammoDelta > 0 and not meta.reloadStarted then
		local severity = Util.clamp(ammoDelta / 10.0, 0, 1) -- scale by ammo amount
		table_insert(violations, createEvidence("ammo_increased", severity, {
			ammoDelta = ammoDelta,
			previousAmmo = state.lastAmmoCount,
			currentAmmo = currentAmmo,
			weaponId = weaponId,
		}, currentTime))
	end

	-- 2. No ammo consumption on shot (possible infinite ammo)
	if meta.shotFired and ammoDelta >= 0 then
		local severity = 0.8 -- high severity for this violation
		table_insert(violations, createEvidence("no_ammo_consumption", severity, {
			weaponId = weaponId,
			ammoDelta = ammoDelta,
			shotFired = true,
		}, currentTime))
	end

	-- 3. Check for consistent ammo patterns (possible ammo exploits)
	if #state.ammoHistory >= 10 then
		local positiveDeltas = 0
		local totalDeltas = 0

		for i = 1, #state.ammoHistory do
			if state.ammoHistory[i].delta > 0 then
				positiveDeltas = positiveDeltas + 1
			end
			totalDeltas = totalDeltas + 1
		end

		local positiveRatio = positiveDeltas / totalDeltas
		if positiveRatio > 0.3 then -- more than 30% positive deltas is suspicious
			local severity = Util.clamp((positiveRatio - 0.3) * 2, 0, 1)
			table_insert(violations, createEvidence("suspicious_ammo_pattern", severity, {
				positiveRatio = positiveRatio,
				totalSamples = totalDeltas,
				weaponId = weaponId,
			}, currentTime))
		end
	end

	state.lastAmmoCount = currentAmmo
	return Util.when(#violations > 0, violations)
end

--- Validate reload timing
---@param self WeaponAbuseDetector
---@param playerId any Player ID
---@param weaponId string Weapon identifier
---@param currentTime number Current timestamp
---@return table? evidence Reload timing evidence or nil
function WeaponAbuseDetector:_validateReloadTiming(playerId, weaponId, currentTime)
	local state = self:_getPlayerState(playerId)
	local reloadTime = self.baselines:getWeaponBaseline(weaponId, "reloadTime")

	if not reloadTime or reloadTime <= 0 then return nil end

	local reloadStart = state.reloadHistory[weaponId]
	if not reloadStart then return nil end

	local actualReloadTime = currentTime - reloadStart

	-- Check for instant reload or unusually fast reload
	if actualReloadTime < reloadTime * 0.5 then
		local severity = Util.clamp((reloadTime - actualReloadTime) / reloadTime, 0, 1)
		return createEvidence("instant_reload", severity, {
			weaponId = weaponId,
			actualReloadTime = actualReloadTime,
			expectedReloadTime = reloadTime,
		}, currentTime)
	end

	return nil
end

--- Detect weapon switching exploits
---@param self WeaponAbuseDetector
---@param playerId any Player ID
---@param fromWeapon string Previous weapon
---@param toWeapon string New weapon
---@param currentTime number Current timestamp
---@return table? evidence Weapon switch exploit evidence or nil
function WeaponAbuseDetector:_detectWeaponSwitchExploit(playerId, fromWeapon, toWeapon, currentTime)
	local state = self:_getPlayerState(playerId)

	-- Check for rapid weapon switching to reset fire-rate timers
	if fromWeapon and toWeapon and fromWeapon ~= toWeapon then
		local lastSwitch = state.lastWeaponSwitch
		if lastSwitch and (currentTime - lastSwitch) < 0.1 then -- 100ms threshold
			local severity = 0.6
			return createEvidence("rapid_weapon_switch", severity, {
				fromWeapon = fromWeapon,
				toWeapon = toWeapon,
				switchInterval = currentTime - lastSwitch,
			}, currentTime)
		end
		state.lastWeaponSwitch = currentTime
	end

	return nil
end

--- Observe player and return weapon abuse evidence
---@param self WeaponAbuseDetector
---@param playerId any Player ID
---@param snapshot PlayerSnapshot Current player state
---@param dt number Time delta
---@return table? evidence Array of evidence records or nil
function WeaponAbuseDetector:observe(playerId, snapshot, dt)
	if not self.enabled then return nil end

	local state = self:_getPlayerState(playerId)
	local meta = snapshot.meta or {}
	local violations = {}

	-- Track weapon changes
	local currentWeapon = meta.weaponId or "unknown"
	if state.currentWeapon ~= currentWeapon then
		local switchEvidence = self:_detectWeaponSwitchExploit(playerId, state.currentWeapon, currentWeapon, snapshot.t)
		if switchEvidence then
			table_insert(violations, switchEvidence)
		end
		state.currentWeapon = currentWeapon
	end

	-- Track shot events
	if meta.shotFired then
		-- Validate fire-rate
		local fireRateEvidence = self:_validateFireRate(playerId, currentWeapon, snapshot.t)
		if fireRateEvidence then
			table_insert(violations, fireRateEvidence)
			state.violationCount[currentWeapon] = (state.violationCount[currentWeapon] or 0) + 1
		end

		-- Update shot tracking
		state.lastShotTime[currentWeapon] = snapshot.t
		state.shotCount[currentWeapon] = (state.shotCount[currentWeapon] or 0) + 1
		state.lastShotMeta = meta
	end

	-- Track ammo changes
	if meta.ammoCount ~= nil then
		local ammoEvidence = self:_detectAmmoDesync(playerId, meta.ammoCount, currentWeapon, snapshot.t)
		if ammoEvidence then
			for i = 1, #ammoEvidence do
				table_insert(violations, ammoEvidence[i])
			end
		end
	end

	-- Track reload events
	if meta.reloadStarted then
		state.reloadHistory[currentWeapon] = snapshot.t
	end

	if meta.reloadCompleted then
		local reloadEvidence = self:_validateReloadTiming(playerId, currentWeapon, snapshot.t)
		if reloadEvidence then
			table_insert(violations, reloadEvidence)
		end
		state.reloadHistory[currentWeapon] = nil
	end

	-- Check for repeated violations (pattern abuse)
	local violationCount = state.violationCount[currentWeapon] or 0
	if violationCount >= self.maxViolations then
		local severity = Util.clamp(violationCount / self.maxViolations, 0, 1)
		table_insert(violations, createEvidence("repeated_violations", severity, {
			weaponId = currentWeapon,
			violationCount = violationCount,
			maxViolations = self.maxViolations,
		}, snapshot.t))
	end

	return Util.when(#violations > 0, violations)
end

--- Reset detector state for player
---@param self WeaponAbuseDetector
---@param playerId any Player ID
function WeaponAbuseDetector:reset(playerId)
	self.weaponStates[playerId] = nil
end

--- Handle configuration update
---@param self WeaponAbuseDetector
---@param newCfg table New configuration
function WeaponAbuseDetector:onConfig(newCfg)
	Detector.onConfig(self, newCfg)

	if newCfg.baselines then
		self.baselines:update(newCfg.baselines)
	end

	if newCfg.toleranceMs then
		self.toleranceMs = Util.clamp(newCfg.toleranceMs, 10, 200)
	end

	if newCfg.maxViolations then
		self.maxViolations = Util.clamp(newCfg.maxViolations, 3, 20)
	end
end

----------------------------------------------------------------------
-- SECTION: CONFIGURATION VALIDATION AND HOT-RELOAD
----------------------------------------------------------------------

--- Configuration manager with validation, versioning, and hot-reload
---@class ConfigManager
---@field currentConfig table Current active configuration
---@field configHistory table Configuration version history
---@field validators table Schema validators for different sections
---@field subscribers table Configuration change subscribers
---@field version number Current configuration version
local ConfigManager = class("ConfigManager")

--- Initialize configuration manager
---@param self ConfigManager
---@param initialConfig? table Initial configuration
function ConfigManager:init(initialConfig)
	self.currentConfig = initialConfig or {}
	self.configHistory = {}
	self.validators = {}
	self.subscribers = {}
	self.version = 0

	-- Register default validators
	self:_setupDefaultValidators()

	-- Store initial config
	if initialConfig then
		self:storeConfig(initialConfig, "initial")
	end
end

--- Setup default validators for common configuration sections
---@param self ConfigManager
function ConfigManager:_setupDefaultValidators()
	-- Thresholds validator
	self.validators.thresholds = function(cfg)
		local thresholds = cfg.thresholds or {}
		local validated  = {}

		validated.warn   = Util.clamp(tonumber(thresholds.warn) or 2.0, 0.0, 999.0)
		validated.kick   = Util.clamp(tonumber(thresholds.kick) or 5.0, 0.0, 999.0)
		validated.ban    = Util.clamp(tonumber(thresholds.ban) or 9.0, 0.0, 999.0)
		validated.flag   = Util.clamp(tonumber(thresholds.flag) or 1.0, 0.0, 999.0)

		-- Ensure logical ordering
		if validated.warn > validated.kick then validated.kick = validated.warn + 1.0 end
		if validated.kick > validated.ban then validated.ban = validated.kick + 1.0 end

		return { thresholds = validated }
	end

	-- Weights validator
	self.validators.weights = function(cfg)
		local weights = cfg.weights or {}
		local validated = {}

		for kind, weight in next, weights do
			if type(kind) == "string" and type(weight) == "number" then
				validated[kind] = Util.clamp(weight, 0.1, 10.0)
			end
		end

		return { weights = validated }
	end

	-- Timing validator
	self.validators.timing = function(cfg)
		local timing = cfg.timing or {}
		local validated = {}

		validated.scoreDecayPerSec = Util.clamp(tonumber(timing.scoreDecayPerSec) or 0.15, 0.0, 10.0)
		validated.actionCooldownSec = Util.clamp(tonumber(timing.actionCooldownSec) or 3.0, 0.1, 60.0)
		validated.lagWindowMs = Util.clamp(tonumber(timing.lagWindowMs) or 500, 100, 2000)

		return { timing = validated }
	end

	-- Baselines validator
	self.validators.baselines = function(cfg)
		local baselines = BaselinesConfig()
		if cfg.baselines then
			baselines:update(cfg.baselines, true)
		end
		return { baselines = baselines }
	end
end

--- Validate configuration using registered validators
---@param self ConfigManager
---@param config table Configuration to validate
---@return table validated Validated configuration
---@return table errors Validation errors
function ConfigManager:validateConfig(config)
	local validated = Util.shallow_copy(config)
	local errors = {}

	-- Run all validators
	for sectionName, validator in next, self.validators do
		local ok, result = pcall(validator, config)
		if ok and result then
			for key, value in next, result do
				validated[key] = value
			end
		elseif not ok then
			errors[sectionName] = result or "Unknown validation error"
		end
	end

	return validated, errors
end

--- Compute configuration diff for audit logging
---@param self ConfigManager
---@param oldConfig table Previous configuration
---@param newConfig table New configuration
---@return table diff Configuration differences
function ConfigManager:computeDiff(oldConfig, newConfig)
	local diff = {
		added = {},
		modified = {},
		removed = {},
		timestamp = Util.now(),
		version = self.version + 1
	}

	local function traverse(old, new, path)
		path = path or ""

		-- Check for added/modified keys
		for key, value in next, new do
			local currentPath = path .. "." .. key
			local oldValue = old[key]

			if oldValue == nil then
				diff.added[currentPath] = value
			elseif type(value) ~= type(oldValue) then
				diff.modified[currentPath] = { old = oldValue, new = value }
			elseif type(value) == "table" and type(oldValue) == "table" then
				traverse(oldValue, value, currentPath)
			elseif value ~= oldValue then
				diff.modified[currentPath] = { old = oldValue, new = value }
			end
		end

		-- Check for removed keys
		for key, value in next, old do
			local currentPath = path .. "." .. key
			if new[key] == nil then
				diff.removed[currentPath] = value
			end
		end
	end

	traverse(oldConfig, newConfig)
	return diff
end

--- Store configuration in history
---@param self ConfigManager
---@param config table Configuration to store
---@param reason string Reason for storage
function ConfigManager:storeConfig(config, reason)
	self.version = self.version + 1

	local historyEntry = {
		version = self.version,
		config = Util.shallow_copy(config),
		timestamp = Util.now(),
		reason = reason or "update",
		diff = nil, -- Will be populated if there's a previous config
	}

	-- Compute diff if we have previous config
	if #self.configHistory > 0 then
		local previous = self.configHistory[#self.configHistory].config
		historyEntry.diff = self:computeDiff(previous, config)
	end

	table_insert(self.configHistory, historyEntry)

	-- Limit history size
	if #self.configHistory > 50 then
		table_remove(self.configHistory, 1)
	end
end

--- Apply new configuration with validation and atomic update
---@param self ConfigManager
---@param newConfig table New configuration to apply
---@param reason string Reason for change
---@return boolean success Whether the update was successful
---@return table? errors Validation errors (if any)
function ConfigManager:applyConfig(newConfig, reason)
	reason = reason or "manual_update"

	-- Validate new configuration
	local validated, errors = self:validateConfig(newConfig)

	-- If validation failed, don't apply
	if next(errors) ~= nil then
		return false, errors
	end

	-- Store old config for rollback
	local oldConfig = self.currentConfig

	-- Store new config in history
	self:storeConfig(validated, reason)

	-- Atomic update
	self.currentConfig = validated

	-- Notify subscribers
	self:_notifySubscribers(validated, oldConfig, reason)

	return true
end

--- Subscribe to configuration changes
---@param self ConfigManager
---@param subscriberId string Unique subscriber identifier
---@param callback function Callback function (newConfig, oldConfig, reason)
---@return boolean subscribed Whether subscription was successful
function ConfigManager:subscribe(subscriberId, callback)
	if type(callback) ~= "function" then return false end

	self.subscribers[subscriberId] = callback
	return true
end

--- Unsubscribe from configuration changes
---@param self ConfigManager
---@param subscriberId string Subscriber identifier to remove
---@return boolean unsubscribed Whether unsubscription was successful
function ConfigManager:unsubscribe(subscriberId)
	self.subscribers[subscriberId] = nil
	return true
end

--- Notify all subscribers of configuration change
---@param self ConfigManager
---@param newConfig table New configuration
---@param oldConfig table Previous configuration
---@param reason string Reason for change
function ConfigManager:_notifySubscribers(newConfig, oldConfig, reason)
	for subscriberId, callback in next, self.subscribers do
		local ok, err = pcall(callback, newConfig, oldConfig, reason)
		if not ok then
			-- Log subscriber error but don't fail the update
			print("ConfigManager: Subscriber error for " .. subscriberId .. ": " .. tostring(err))
		end
	end
end

--- Get current configuration
---@param self ConfigManager
---@return table config Current configuration
function ConfigManager:getConfig()
	return Util.shallow_copy(self.currentConfig)
end

--- Get configuration history
---@param self ConfigManager
---@param maxEntries? integer Maximum entries to return
---@return table history Configuration history
function ConfigManager:getHistory(maxEntries)
	local history = Util.shallow_copy(self.configHistory)

	if maxEntries and maxEntries > 0 and #history > maxEntries then
		local result = {}
		local startIdx = #history - maxEntries + 1
		for i = startIdx, #history do
			table_insert(result, history[i])
		end
		return result
	end

	return history
end

--- Rollback to previous configuration version
---@param self ConfigManager
---@param version number Target version to rollback to
---@return boolean success Whether rollback was successful
---@return string? error Error message (if any)
function ConfigManager:rollback(version)
	-- Find target version in history
	local targetEntry
	for i = #self.configHistory, 1, -1 do
		if self.configHistory[i].version == version then
			targetEntry = self.configHistory[i]
			break
		end
	end

	if not targetEntry then
		return false, "Version " .. version .. " not found in history"
	end

	-- Apply rollback
	local oldConfig = self.currentConfig
	self.currentConfig = Util.shallow_copy(targetEntry.config)

	-- Store rollback in history
	self:storeConfig(self.currentConfig, "rollback_to_v" .. version)

	-- Notify subscribers
	self:_notifySubscribers(self.currentConfig, oldConfig, "rollback")

	return true
end

--- Export configuration to string for persistence
---@param self ConfigManager
---@return string exported Serialized configuration
function ConfigManager:export()
	local exportData = {
		version = self.version,
		config = self.currentConfig,
		timestamp = Util.now(),
		exportedBy = "ConfigManager"
	}

	-- Simple JSON-like serialization (basic implementation)
	local function serialize(val, indent)
		indent = indent or ""
		local str = ""

		if type(val) == "table" then
			str = str .. "{\n"
			local first = true
			for k, v in next, val do
				if not first then str = str .. ",\n" end
				first = false
				str = str .. indent .. "  " .. tostring(k) .. ": " .. serialize(v, indent .. "  ")
			end
			str = str .. "\n" .. indent .. "}"
		elseif type(val) == "string" then
			str = str .. '"' .. val .. '"'
		else
			str = str .. tostring(val)
		end

		return str
	end

	return serialize(exportData)
end

--- Import configuration from string
---@param self ConfigManager
---@param data string Serialized configuration data
---@param reason string Reason for import
---@return boolean success Whether import was successful
---@return table? errors Validation errors (if any)
function ConfigManager:import(data, reason)
	reason = reason or "import"

	-- Simple parsing (basic implementation)
	-- In production, use a proper JSON library
	local ok, config = pcall(_loadstring, "return " .. data)
	if not ok or not config then
		return false, { "Invalid configuration data format" }
	end

	local newConfig = config()
	return self:applyConfig(newConfig, reason)
end

----------------------------------------------------------------------
-- SECTION: REPORTING AND ANALYTICS
----------------------------------------------------------------------

--- Analytics collector with evidence sampling and shadow mode support
---@class AnalyticsCollector
---@field evidenceSamples table Per-player evidence samples
---@field shadowMode boolean Whether shadow mode is enabled
---@field reportInterval number Interval between automatic reports (seconds)
---@field maxSamplesPerPlayer number Maximum evidence samples per player
---@field aggregatedStats table Aggregated statistics
---@field lastReportTime number Timestamp of last report
local AnalyticsCollector = class("AnalyticsCollector")

--- Initialize analytics collector
---@param self AnalyticsCollector
---@param opts? table Configuration options
function AnalyticsCollector:init(opts)
	opts = opts or {}

	self.evidenceSamples = {}                                      -- per-player evidence history
	self.shadowMode = Util.get_opt(opts, "shadowMode", false)
	self.reportInterval = Util.get_opt(opts, "reportInterval", 300) -- 5 minutes
	self.maxSamplesPerPlayer = Util.get_opt(opts, "maxSamplesPerPlayer", 100)
	self.aggregatedStats = self:_initializeStats()
	self.lastReportTime = Util.now()
end

--- Initialize aggregated statistics structure
---@param self AnalyticsCollector
---@return table stats Initial statistics structure
function AnalyticsCollector:_initializeStats()
	return {
		totalEvidence = 0,
		evidenceByKind = {},
		evidenceByHour = {},
		playerStats = {},
		severityDistribution = { low = 0, medium = 0, high = 0 },
		detectorPerformance = {},
		trendData = {}
	}
end

--- Add evidence sample for analytics
---@param self AnalyticsCollector
---@param playerId any Player ID
---@param evidence Evidence Evidence record
---@param detectorName string Name of detector that generated evidence
function AnalyticsCollector:addEvidenceSample(playerId, evidence, detectorName)
	if not self.evidenceSamples[playerId] then
		self.evidenceSamples[playerId] = {
			samples = {},
			firstSeen = evidence.t,
			lastSeen = evidence.t,
			totalSeverity = 0,
			violationCount = 0
		}
	end

	local playerData = self.evidenceSamples[playerId]

	-- Add sample with metadata
	local sample = {
		evidence = evidence,
		detectorName = detectorName,
		timestamp = evidence.t,
		shadowMode = self.shadowMode
	}

	table_insert(playerData.samples, sample)
	playerData.lastSeen = evidence.t
	playerData.totalSeverity = playerData.totalSeverity + evidence.severity
	playerData.violationCount = playerData.violationCount + 1

	-- Limit samples per player
	if #playerData.samples > self.maxSamplesPerPlayer then
		table_remove(playerData.samples, 1)
	end

	-- Update aggregated stats
	self:_updateAggregatedStats(evidence, detectorName)
end

--- Update aggregated statistics
---@param self AnalyticsCollector
---@param evidence Evidence Evidence record
---@param detectorName string Detector name
function AnalyticsCollector:_updateAggregatedStats(evidence, detectorName)
	-- Total evidence count
	self.aggregatedStats.totalEvidence = self.aggregatedStats.totalEvidence + 1

	-- Evidence by kind
	self.aggregatedStats.evidenceByKind[evidence.kind] =
			(self.aggregatedStats.evidenceByKind[evidence.kind] or 0) + 1

	-- Evidence by hour
	local hour = os_date("*t", evidence.t).hour
	self.aggregatedStats.evidenceByHour[hour] =
			(self.aggregatedStats.evidenceByHour[hour] or 0) + 1

	-- Severity distribution
	if evidence.severity < 0.3 then
		self.aggregatedStats.severityDistribution.low =
				self.aggregatedStats.severityDistribution.low + 1
	elseif evidence.severity < 0.7 then
		self.aggregatedStats.severityDistribution.medium =
				self.aggregatedStats.severityDistribution.medium + 1
	else
		self.aggregatedStats.severityDistribution.high =
				self.aggregatedStats.severityDistribution.high + 1
	end

	-- Detector performance
	if not self.aggregatedStats.detectorPerformance[detectorName] then
		self.aggregatedStats.detectorPerformance[detectorName] = {
			evidenceCount = 0,
			totalSeverity = 0,
			avgSeverity = 0
		}
	end

	local perf = self.aggregatedStats.detectorPerformance[detectorName]
	perf.evidenceCount = perf.evidenceCount + 1
	perf.totalSeverity = perf.totalSeverity + evidence.severity
	perf.avgSeverity = perf.totalSeverity / perf.evidenceCount
end

--- Generate comprehensive analytics report
---@param self AnalyticsCollector
---@param timeWindow? number Time window for report (seconds, nil = all time)
---@return table report Analytics report
function AnalyticsCollector:generateReport(timeWindow)
	timeWindow = timeWindow or (24 * 3600) -- default 24 hours
	local now = Util.now()
	local cutoff = now - timeWindow

	local report = {
		timestamp = now,
		timeWindow = timeWindow,
		shadowMode = self.shadowMode,
		summary = {},
		playerAnalysis = {},
		evidenceAnalysis = {},
		detectorAnalysis = {},
		trends = {},
		recommendations = {}
	}

	-- Generate summary
	report.summary = self:_generateSummary(cutoff)

	-- Analyze players
	report.playerAnalysis = self:_analyzePlayers(cutoff)

	-- Analyze evidence patterns
	report.evidenceAnalysis = self:_analyzeEvidence(cutoff)

	-- Analyze detector performance
	report.detectorAnalysis = self:_analyzeDetectors(cutoff)

	-- Generate trends
	report.trends = self:_generateTrends(cutoff)

	-- Generate recommendations
	report.recommendations = self:_generateRecommendations(report)

	return report
end

--- Generate report summary
---@param self AnalyticsCollector
---@param cutoff number Time cutoff for analysis
---@return table summary Report summary
function AnalyticsCollector:_generateSummary(cutoff)
	local summary = {
		totalPlayers = 0,
		activePlayers = 0,
		totalEvidence = 0,
		avgSeverity = 0,
		hotspotKinds = {},
		timeRange = { start = cutoff, stop = Util.now() }
	}

	local totalSeverity = 0
	local evidenceCount = 0

	for playerId, playerData in next, self.evidenceSamples do
		summary.totalPlayers = summary.totalPlayers + 1

		-- Check if player was active in time window
		if playerData.lastSeen >= cutoff then
			summary.activePlayers = summary.activePlayers + 1
		end

		-- Count evidence in time window
		for i = 1, #playerData.samples do
			local sample = playerData.samples[i]
			if sample.timestamp >= cutoff then
				evidenceCount = evidenceCount + 1
				totalSeverity = totalSeverity + sample.evidence.severity

				-- Track hotspot evidence kinds
				summary.hotspotKinds[sample.evidence.kind] =
						(summary.hotspotKinds[sample.evidence.kind] or 0) + 1
			end
		end
	end

	summary.totalEvidence = evidenceCount
	summary.avgSeverity = evidenceCount > 0 and (totalSeverity / evidenceCount) or 0

	return summary
end

--- Analyze player behavior patterns
---@param self AnalyticsCollector
---@param cutoff number Time cutoff for analysis
---@return table analysis Player analysis
function AnalyticsCollector:_analyzePlayers(cutoff)
	local analysis = {
		topViolators = {},
		newViolators = {},
		persistentViolators = {},
		recoveringPlayers = {}
	}

	local playerScores = {}

	-- Calculate player scores in time window
	for playerId, playerData in next, self.evidenceSamples do
		local score = 0
		local recentEvidence = 0

		for i = 1, #playerData.samples do
			local sample = playerData.samples[i]
			if sample.timestamp >= cutoff then
				score = score + sample.evidence.severity
				recentEvidence = recentEvidence + 1
			end
		end

		if recentEvidence > 0 then
			playerScores[playerId] = {
				score = score,
				evidenceCount = recentEvidence,
				firstSeen = playerData.firstSeen,
				lastSeen = playerData.lastSeen,
				avgSeverity = score / recentEvidence
			}
		end
	end

	-- Find top violators
	local violators = {}
	for playerId, data in next, playerScores do
		local violator = { playerId = playerId }
		for k, v in next, data do
			violator[k] = v
		end
		table_insert(violators, violator)
	end

	-- Sort by score
	table_sort(violators, compare_score_desc)

	-- Top 10 violators
	for i = 1, math_min(10, #violators) do
		table_insert(analysis.topViolators, violators[i])
	end

	-- Categorize players
	for playerId, data in next, playerScores do
		local timeSinceFirst = cutoff - data.firstSeen
		local timeSinceLast = cutoff - data.lastSeen

		-- New violators (first seen recently)
		if timeSinceFirst < (24 * 3600) then -- last 24 hours
			local newViolator = { playerId = playerId }
			for k, v in next, data do
				newViolator[k] = v
			end
			table_insert(analysis.newViolators, newViolator)
		end

		-- Persistent violators (long history + recent activity)
		if timeSinceFirst > (7 * 24 * 3600) and timeSinceLast < (24 * 3600) then
			local persistentViolator = { playerId = playerId }
			for k, v in next, data do
				persistentViolator[k] = v
			end
			table_insert(analysis.persistentViolators, persistentViolator)
		end

		-- Recovering players (high score but no recent evidence)
		if data.score > 5.0 and timeSinceLast > (2 * 3600) then -- 2 hours
			local recoveringPlayer = { playerId = playerId }
			for k, v in next, data do
				recoveringPlayer[k] = v
			end
			table_insert(analysis.recoveringPlayers, recoveringPlayer)
		end
	end

	return analysis
end

--- Analyze evidence patterns
---@param self AnalyticsCollector
---@param cutoff number Time cutoff for analysis
---@return table analysis Evidence analysis
function AnalyticsCollector:_analyzeEvidence(cutoff)
	local analysis = {
		kindDistribution = {},
		severityTrend = {},
		temporalPatterns = {},
		correlations = {}
	}

	local kindCounts = {}
	local severityByTime = {}
	local hourlyPatterns = {}

	-- Collect evidence data
	for playerId, playerData in next, self.evidenceSamples do
		for i = 1, #playerData.samples do
			local sample = playerData.samples[i]
			if sample.timestamp >= cutoff then
				local evidence = sample.evidence

				-- Kind distribution
				kindCounts[evidence.kind] = (kindCounts[evidence.kind] or 0) + 1

				-- Severity trend (grouped by hour)
				local hour = math_floor(sample.timestamp / 3600)
				if not severityByTime[hour] then
					severityByTime[hour] = { count = 0, totalSeverity = 0 }
				end
				severityByTime[hour].count = severityByTime[hour].count + 1
				severityByTime[hour].totalSeverity = severityByTime[hour].totalSeverity + evidence.severity

				-- Temporal patterns
				local hourOfDay = os_date("*t", sample.timestamp).hour
				hourlyPatterns[hourOfDay] = (hourlyPatterns[hourOfDay] or 0) + 1
			end
		end
	end

	analysis.kindDistribution = kindCounts

	-- Calculate severity trend
	local sortedHours = {}
	for hour, data in next, severityByTime do
		local hourData = { hour = hour }
		for k, v in next, data do
			hourData[k] = v
		end
		table_insert(sortedHours, hourData)
	end
	table_sort(sortedHours, compare_hour_asc)

	for i = 1, #sortedHours do
		local data = sortedHours[i]
		table_insert(analysis.severityTrend, {
			hour = data.hour,
			avgSeverity = data.totalSeverity / data.count,
			count = data.count
		})
	end

	analysis.temporalPatterns = hourlyPatterns

	return analysis
end

--- Analyze detector performance
---@param self AnalyticsCollector
---@param cutoff number Time cutoff for analysis
---@return table analysis Detector analysis
function AnalyticsCollector:_analyzeDetectors(cutoff)
	local analysis = {
		performance = {},
		effectiveness = {},
		falsePositiveRate = {},
		recommendations = {}
	}

	local detectorStats = {}

	-- Collect detector statistics
	for playerId, playerData in next, self.evidenceSamples do
		for i = 1, #playerData.samples do
			local sample = playerData.samples[i]
			if sample.timestamp >= cutoff then
				local detectorName = sample.detectorName

				if not detectorStats[detectorName] then
					detectorStats[detectorName] = {
						evidenceCount = 0,
						totalSeverity = 0,
						uniquePlayers = {},
						hourlyActivity = {}
					}
				end

				local stats = detectorStats[detectorName]
				stats.evidenceCount = stats.evidenceCount + 1
				stats.totalSeverity = stats.totalSeverity + sample.evidence.severity
				stats.uniquePlayers[playerId] = true

				local hour = os_date("*t", sample.timestamp).hour
				stats.hourlyActivity[hour] = (stats.hourlyActivity[hour] or 0) + 1
			end
		end
	end

	-- Calculate performance metrics
	for detectorName, stats in next, detectorStats do
		local uniquePlayerCount = 0
		for _ in next, stats.uniquePlayers do uniquePlayerCount = uniquePlayerCount + 1 end

		analysis.performance[detectorName] = {
			evidenceCount = stats.evidenceCount,
			totalSeverity = stats.totalSeverity,
			avgSeverity = stats.totalSeverity / stats.evidenceCount,
			uniquePlayers = uniquePlayerCount,
			hourlyActivity = stats.hourlyActivity
		}

		-- Effectiveness score (evidence per unique player)
		analysis.effectiveness[detectorName] = stats.evidenceCount / uniquePlayerCount
	end

	return analysis
end

--- Generate trend analysis
---@param self AnalyticsCollector
---@param cutoff number Time cutoff for analysis
---@return table trends Trend data
function AnalyticsCollector:_generateTrends(cutoff)
	local trends = {
		evidenceVolume = {},
		severityTrend = {},
		playerActivity = {}
	}

	-- This would require more sophisticated time-series analysis
	-- For now, provide basic trend indicators

	return trends
end

--- Generate recommendations based on analysis
---@param self AnalyticsCollector
---@param report table Full analytics report
---@return table recommendations Actionable recommendations
function AnalyticsCollector:_generateRecommendations(report)
	local recommendations = {}

	-- High-traffic evidence kinds
	if report.summary.hotspotKinds then
		for kind, count in next, report.summary.hotspotKinds do
			if count > 100 then -- threshold for "high traffic"
				table_insert(recommendations, {
					type = "detector_tuning",
					priority = "medium",
					message = "High volume of '" .. kind .. "' evidence (" .. count ..
							"). Consider adjusting detector sensitivity or baselines.",
					data = { kind = kind, count = count }
				})
			end
		end
	end

	-- Shadow mode recommendations
	if self.shadowMode then
		table_insert(recommendations, {
			type = "shadow_mode",
			priority = "low",
			message = "Shadow mode is active. Consider enabling enforcement after validation period.",
			data = { enabled = true }
		})
	end

	-- Player-based recommendations
	if #report.playerAnalysis.topViolators > 5 then
		table_insert(recommendations, {
			type = "player_monitoring",
			priority = "high",
			message = #report.playerAnalysis.topViolators ..
					" players showing high violation patterns. Consider manual review.",
			data = { violatorCount = #report.playerAnalysis.topViolators }
		})
	end

	return recommendations
end

--- Enable/disable shadow mode
---@param self AnalyticsCollector
---@param enabled boolean Whether to enable shadow mode
function AnalyticsCollector:setShadowMode(enabled)
	self.shadowMode = enabled
end

--- Get player evidence samples
---@param self AnalyticsCollector
---@param playerId any Player ID
---@param maxCount? integer Maximum samples to return
---@return table samples Player evidence samples
function AnalyticsCollector:getPlayerSamples(playerId, maxCount)
	local playerData = self.evidenceSamples[playerId]
	if not playerData then return {} end

	local samples = {}
	local count = math_min(maxCount or #playerData.samples, #playerData.samples)

	-- Return most recent samples
	for i = #playerData.samples, #playerData.samples - count + 1, -1 do
		if i >= 1 then
			table_insert(samples, playerData.samples[i])
		end
	end

	return samples
end

--- Clear old evidence samples
---@param self AnalyticsCollector
---@param olderThan number Remove samples older than this (seconds)
function AnalyticsCollector:cleanup(olderThan)
	local cutoff = Util.now() - olderThan
	local cleaned = 0

	for playerId, playerData in next, self.evidenceSamples do
		local newSamples = {}
		for i = 1, #playerData.samples do
			if playerData.samples[i].timestamp >= cutoff then
				table_insert(newSamples, playerData.samples[i])
			else
				cleaned = cleaned + 1
			end
		end
		playerData.samples = newSamples

		-- Remove players with no recent samples
		if #newSamples == 0 then
			self.evidenceSamples[playerId] = nil
		end
	end

	return cleaned
end

----------------------------------------------------------------------
-- SECTION: CLIENT GUARD HARDENING
----------------------------------------------------------------------

--- Tamper-evident client guard with heartbeat and integrity checks
---@class ClientGuardHardening
---@field heartbeatInterval number Heartbeat interval in seconds
---@field integrityChecks table Integrity check functions
---@field monotonicCounters table Monotonic counters for tamper detection
---@field lastHeartbeat table Last heartbeat timestamps per player
---@field guardState table Current guard state
---@field tamperThreshold number Threshold for tamper detection
local ClientGuardHardening = class("ClientGuardHardening")

--- Initialize client guard hardening
---@param self ClientGuardHardening
---@param opts? table Configuration options
function ClientGuardHardening:init(opts)
	opts = opts or {}

	self.heartbeatInterval = Util.get_opt(opts, "heartbeatInterval", 30) -- 30 seconds
	self.integrityChecks = {}
	self.monotonicCounters = {}
	self.lastHeartbeat = {}
	self.guardState = {}
	self.tamperThreshold = Util.get_opt(opts, "tamperThreshold", 3)

	-- Setup default integrity checks
	self:_setupDefaultIntegrityChecks()
end

--- Setup default integrity checks
---@param self ClientGuardHardening
function ClientGuardHardening:_setupDefaultIntegrityChecks()
	-- Check for debug hooks using registry baseline if available
	self.integrityChecks.debugHooks = function(baseline)
		if not debug or not debug.getregistry then return true end

		-- If baseline is provided, use it for verification
		if baseline and type(baseline) == "table" and baseline.checksum then
			local ok, details = Util.verify_registry_integrity(baseline)
			return ok, details
		end

		-- Fallback to heuristic check
		local registry = debug.getregistry()
		if type(registry) ~= "table" then return false end

		-- Check for suspicious debug entries
		local suspiciousEntries = 0
		for k, v in next, registry do
			if type(k) == "string" and (string_find(k:lower(), "hook") or
						string_find(k:lower(), "debug") or string_find(k:lower(), "trace")) then
				suspiciousEntries = suspiciousEntries + 1
			end
		end

		return suspiciousEntries <= 2 -- Allow some legitimate debug entries
	end

	-- Check global table pollution
	self.integrityChecks.globalPollution = function()
		local globalCount = 0
		local suspiciousGlobals = 0

		for k, v in next, _G do
			globalCount = globalCount + 1
			if type(k) == "string" then
				local kLower = k:lower()
				if string_find(kLower, "hack") or string_find(kLower, "cheat") or
						string_find(kLower, "inject") or string_find(kLower, "bypass") then
					suspiciousGlobals = suspiciousGlobals + 1
				end
			end
		end

		-- Too many globals or suspicious globals detected
		return globalCount < 200 and suspiciousGlobals == 0
	end

	-- Check critical function integrity
	self.integrityChecks.functionIntegrity = function()
		local criticalFunctions = {
			"pcall", "xpcall", "loadstring", "load", "dofile", "require",
			"setmetatable", "getmetatable", "rawset", "rawget", "rawequal"
		}

		for i = 1, #criticalFunctions do
			local fn = _G[criticalFunctions[i]]
			if type(fn) ~= "function" then return false end

			-- Check if function is still native (for critical functions)
			local isNative, method = Util.is_native_function(fn)
			if criticalFunctions[i] == "pcall" and not isNative then
				return false -- pcall should remain native
			end
		end

		return true
	end

	-- Check for memory modifications (basic)
	self.integrityChecks.memoryIntegrity = function()
		-- Collect garbage and check for reasonable memory usage
		collectgarbage("collect")
		local memUsage = collectgarbage("count")

		-- Excessive memory usage might indicate injection
		return memUsage < 100000 -- 100MB threshold
	end
end

--- Register custom integrity check
---@param self ClientGuardHardening
---@param name string Check name
---@param checkFunction function Check function that returns boolean
function ClientGuardHardening:registerIntegrityCheck(name, checkFunction)
	if type(checkFunction) == "function" then
		self.integrityChecks[name] = checkFunction
	end
end

--- Run all integrity checks
---@param self ClientGuardHardening
---@param playerId any Player ID
---@return table results Integrity check results
function ClientGuardHardening:runIntegrityChecks(playerId)
	local results = {
		timestamp = Util.now(),
		passed = 0,
		failed = 0,
		checks = {},
		overall = true
	}

	for checkName, checkFunction in next, self.integrityChecks do
		local ok, passed = pcall(checkFunction)

		results.checks[checkName] = {
			passed = ok and passed or false,
			error = Util.when(not ok, passed or "Check failed")
		}

		if ok and passed then
			results.passed = results.passed + 1
		else
			results.failed = results.failed + 1
			results.overall = false
		end
	end

	return results
end

--- Update monotonic counter
---@param self ClientGuardHardening
---@param playerId any Player ID
---@param counterName string Counter name
---@param value number New counter value
---@return boolean valid Whether counter value is valid (monotonic)
function ClientGuardHardening:updateMonotonicCounter(playerId, counterName, value)
	if not self.monotonicCounters[playerId] then
		self.monotonicCounters[playerId] = {}
	end

	local playerCounters = self.monotonicCounters[playerId]
	local previousValue = playerCounters[counterName]

	-- Initialize counter if not exists
	if previousValue == nil then
		playerCounters[counterName] = value
		return true
	end

	-- Check monotonicity (should only increase)
	if value < previousValue then
		return false -- Counter went backwards, possible tampering
	end

	-- Check for suspicious jumps (too large increase)
	if value > previousValue + 1000 then
		return false -- Suspicious jump
	end

	playerCounters[counterName] = value
	return true
end

--- Process client heartbeat
---@param self ClientGuardHardening
---@param playerId any Player ID
---@param heartbeatData table Heartbeat data from client
---@return table? evidence Tamper evidence or nil
function ClientGuardHardening:processHeartbeat(playerId, heartbeatData)
	local now = Util.now()
	local lastHeartbeat = self.lastHeartbeat[playerId]

	-- Update last heartbeat time
	self.lastHeartbeat[playerId] = now

	local violations = {}

	-- Check heartbeat interval
	if lastHeartbeat then
		local interval = now - lastHeartbeat
		local expectedInterval = self.heartbeatInterval
		local tolerance = expectedInterval * 0.5 -- 50% tolerance

		if interval > (expectedInterval + tolerance) then
			local severity = Util.clamp((interval - expectedInterval) / expectedInterval, 0, 1)
			table_insert(violations, createEvidence("heartbeat_missed", severity, {
				expectedInterval = expectedInterval,
				actualInterval = interval,
				tolerance = tolerance,
			}, now))
		elseif interval < (expectedInterval - tolerance) then
			local severity = Util.clamp((expectedInterval - interval) / expectedInterval, 0, 1)
			table_insert(violations, createEvidence("heartbeat_spam", severity, {
				expectedInterval = expectedInterval,
				actualInterval = interval,
				tolerance = tolerance,
			}, now))
		end
	end

	-- Validate monotonic counters from heartbeat
	if heartbeatData.counters then
		for counterName, value in next, heartbeatData.counters do
			if not self:updateMonotonicCounter(playerId, counterName, value) then
				local severity = 0.8 -- High severity for counter tampering
				table_insert(violations, createEvidence("counter_tampering", severity, {
					counterName = counterName,
					value = value,
				}, now))
			end
		end
	end

	-- Run integrity checks if requested
	if heartbeatData.requestIntegrityCheck then
		local integrityResults = self:runIntegrityChecks(playerId)

		if not integrityResults.overall then
			local severity = Util.clamp(integrityResults.failed / #integrityResults.checks, 0, 1)
			table_insert(violations, createEvidence("integrity_failure", severity, {
				failedChecks = integrityResults.failed,
				totalChecks = #integrityResults.checks,
				checkResults = integrityResults.checks,
			}, now))
		end
	end

	-- Check for guard state consistency
	if heartbeatData.guardState then
		local stateIssues = self:_validateGuardState(playerId, heartbeatData.guardState)
		for i = 1, #stateIssues do
			table_insert(violations, stateIssues[i])
		end
	end

	return Util.when(#violations > 0, violations)
end

--- Validate guard state consistency
---@param self ClientGuardHardening
---@param playerId any Player ID
---@param guardState table Client-reported guard state
---@return table issues Array of state validation issues
function ClientGuardHardening:_validateGuardState(playerId, guardState)
	local issues = {}

	if not self.guardState[playerId] then
		self.guardState[playerId] = {}
	end

	local localState = self.guardState[playerId]

	-- Check for state inconsistencies
	local stateChecks = {
		-- Version should be consistent or increasing
		version = function(client, server)
			return client >= (server or 0)
		end,

		-- Checksum should be different if state changed
		checksum = function(client, server)
			return client ~= server -- Should always be different for each heartbeat
		end,

		-- Enabled features should be consistent
		enabledFeatures = function(client, server)
			return type(client) == "table" and type(server) == "table"
		end
	}

	for checkName, checkFunction in next, stateChecks do
		local clientValue = guardState[checkName]
		local serverValue = localState[checkName]

		if clientValue and not checkFunction(clientValue, serverValue) then
			local severity = 0.6
			table_insert(issues, createEvidence("guard_state_inconsistency", severity, {
				checkName = checkName,
				clientValue = clientValue,
				serverValue = serverValue,
			}, Util.now()))
		end

		-- Update server state
		localState[checkName] = clientValue
	end

	return issues
end

--- Generate client guard challenge
---@param self ClientGuardHardening
---@param playerId any Player ID
---@return table challenge Challenge data for client
function ClientGuardHardening:generateChallenge(playerId)
	local challenge = {
		id = Util.fnv1a32(tostring(playerId) .. tostring(Util.now())),
		timestamp = Util.now(),
		type = "integrity_challenge",
		data = {
			-- Random data for client to process
			random = math_random(1000000, 9999999),
			-- Expected operations
			operations = {
				{ type = "hash",    input = "challenge_test" },
				{ type = "compute", expression = "random * 2 + 7" },
				{ type = "memory",  action = "collect" }
			}
		}
	}

	return challenge
end

--- Validate client challenge response
---@param self ClientGuardHardening
---@param playerId any Player ID
---@param response table Client challenge response
---@return table? evidence Challenge validation evidence or nil
function ClientGuardHardening:validateChallengeResponse(playerId, response)
	local violations = {}
	local now = Util.now()

	-- Check response timestamp (should be recent)
	if response.timestamp then
		local age = now - response.timestamp
		if age > 60 then                            -- Response too old
			local severity = Util.clamp(age / 300, 0, 1) -- Scale over 5 minutes
			table_insert(violations, createEvidence("challenge_response_stale", severity, {
				age = age,
				maxAge = 60,
			}, now))
		end
	end

	-- Validate challenge results
	if response.results then
		local expectedResults = {
			hash = Util.fnv1a32("challenge_test"),
			computed = nil, -- We can't verify this without knowing the random value
			memory = true -- Should return memory collection result
		}

		for operation, result in next, response.results do
			if expectedResults[operation] and result ~= expectedResults[operation] then
				local severity = 0.7
				table_insert(violations, createEvidence("challenge_result_invalid", severity, {
					operation = operation,
					expected = expectedResults[operation],
					actual = result,
				}, now))
			end
		end
	else
		-- No results provided
		local severity = 0.5
		table_insert(violations, createEvidence("challenge_no_results", severity, {
			challengeId = response.challengeId,
		}, now))
	end

	return Util.when(#violations > 0, violations)
end

--- Check for tampering patterns
---@param self ClientGuardHardening
---@param playerId any Player ID
---@return table? evidence Tampering evidence or nil
function ClientGuardHardening:checkTamperingPatterns(playerId)
	local violations = {}

	-- Check heartbeat consistency
	local lastHeartbeat = self.lastHeartbeat[playerId]
	if lastHeartbeat then
		local timeSinceLastHeartbeat = Util.now() - lastHeartbeat
		local maxMissedHeartbeats = 3

		if timeSinceLastHeartbeat > (self.heartbeatInterval * maxMissedHeartbeats) then
			local severity = Util.clamp(timeSinceLastHeartbeat / (self.heartbeatInterval * 10), 0, 1)
			table_insert(violations, createEvidence("extended_silence", severity, {
				timeSinceLastHeartbeat = timeSinceLastHeartbeat,
				maxExpected = self.heartbeatInterval * maxMissedHeartbeats,
			}, Util.now()))
		end
	end

	-- Check integrity check failure patterns
	local playerState = self.guardState[playerId]
	if playerState and playerState.integrityFailures then
		if playerState.integrityFailures >= self.tamperThreshold then
			local severity = Util.clamp(playerState.integrityFailures / (self.tamperThreshold * 2), 0, 1)
			table_insert(violations, createEvidence("repeated_integrity_failures", severity, {
				failureCount = playerState.integrityFailures,
				threshold = self.tamperThreshold,
			}, Util.now()))
		end
	end

	return Util.when(#violations > 0, violations)
end

--- Reset player guard state
---@param self ClientGuardHardening
---@param playerId any Player ID
function ClientGuardHardening:resetPlayer(playerId)
	self.lastHeartbeat[playerId] = nil
	self.monotonicCounters[playerId] = nil
	self.guardState[playerId] = nil
end

--- Get guard statistics
---@param self ClientGuardHardening
---@return table stats Guard statistics
function ClientGuardHardening:getStats()
	local stats = {
		totalPlayers = 0,
		activePlayers = 0,
		integrityChecksRun = 0,
		integrityFailures = 0,
		heartbeatMissed = 0,
		averageHeartbeatInterval = 0
	}

	local totalInterval = 0
	local intervalCount = 0

	for playerId, lastHeartbeat in next, self.lastHeartbeat do
		stats.totalPlayers = stats.totalPlayers + 1

		-- Check if player is active (heartbeat within last 2 minutes)
		if (Util.now() - lastHeartbeat) < 120 then
			stats.activePlayers = stats.activePlayers + 1
		end
	end

	-- Calculate average heartbeat interval from guard state
	for playerId, state in next, self.guardState do
		if state.averageHeartbeatInterval then
			totalInterval = totalInterval + state.averageHeartbeatInterval
			intervalCount = intervalCount + 1
		end

		if state.integrityFailures then
			stats.integrityFailures = stats.integrityFailures + state.integrityFailures
		end

		if state.heartbeatMissed then
			stats.heartbeatMissed = stats.heartbeatMissed + state.heartbeatMissed
		end
	end

	stats.averageHeartbeatInterval = intervalCount > 0 and (totalInterval / intervalCount) or 0

	return stats
end

----------------------------------------------------------------------
-- SECTION: ENHANCED RING BUFFER UTILITIES
----------------------------------------------------------------------

--- Enhanced ring buffer with deterministic snapshot support and optimized operations
---@class EnhancedRingBuffer
---@field capacity integer Maximum number of items
---@field buf table Internal storage array
---@field head integer Current write position
---@field size integer Current number of items
---@field deterministic boolean Whether to maintain deterministic ordering
local EnhancedRingBuffer = class("EnhancedRingBuffer")

--- Initialize enhanced ring buffer
---@param self EnhancedRingBuffer
---@param capacity integer Maximum number of items
---@param opts? table Configuration options
function EnhancedRingBuffer:init(capacity, opts)
	opts = opts or {}

	self.capacity = math_max(1, tonumber(capacity) or 1)
	self.buf = {}
	self.head = 0
	self.size = 0
	self.deterministic = Util.get_opt(opts, "deterministic", true)
end

--- Add item with optional timestamp
---@param self EnhancedRingBuffer
---@param item any Item to add
---@param timestamp? number Timestamp (default: `os.clock()`)
function EnhancedRingBuffer:push(item, timestamp)
	local entry = {
		data = item,
		timestamp = timestamp or Util.now(),
		index = self.size -- Logical index
	}

	self.head = (self.head % self.capacity) + 1
	self.buf[self.head] = entry

	if self.size < self.capacity then
		self.size = self.size + 1
	end
end

--- Get item by logical index
---@param self EnhancedRingBuffer
---@param index integer Logical index (0 = newest, size-1 = oldest)
---@return table? entry Entry with data, timestamp, and index
function EnhancedRingBuffer:get(index)
	if index < 0 or index >= self.size then return nil end

	local physIndex
	if self.deterministic then
		-- Deterministic: 0 = newest, size-1 = oldest
		physIndex = ((self.head - index - 1) % self.capacity) + 1
	else
		-- Standard ring buffer indexing
		physIndex = ((self.head + index) % self.capacity) + 1
	end

	return self.buf[physIndex]
end

--- Get range of items by logical indices
---@param self EnhancedRingBuffer
---@param startIndex integer Start index (0 = newest)
---@param count integer Number of items to get
---@return table items Array of entries
function EnhancedRingBuffer:getRange(startIndex, count)
	local items = {}

	for i = 0, count - 1 do
		local entry = self:get(startIndex + i)
		if entry then
			table_insert(items, entry)
		else
			break
		end
	end

	return items
end

--- Get items in time range
---@param self EnhancedRingBuffer
---@param startTime number Start timestamp
---@param endTime number End timestamp
---@return table items Array of entries in time range
function EnhancedRingBuffer:getTimeRange(startTime, endTime)
	local items = {}

	for i = 0, self.size - 1 do
		local entry = self:get(i)
		if entry and entry.timestamp >= startTime and entry.timestamp <= endTime then
			table_insert(items, entry)
		end
	end

	return items
end

--- Find newest item matching predicate
---@param self EnhancedRingBuffer
---@param predicate fun(entry: table): boolean Predicate
---@return table? entry First matching entry or nil
function EnhancedRingBuffer:find(predicate)
	for i = 0, self.size - 1 do
		local entry = self:get(i)
		if entry and predicate(entry) then
			return entry
		end
	end

	return nil
end

--- Find all items matching predicate
---@param self EnhancedRingBuffer
---@param predicate fun(entry: table): boolean Predicate
---@return table items Array of matching entries
function EnhancedRingBuffer:findAll(predicate)
	local items = {}

	for i = 0, self.size - 1 do
		local entry = self:get(i)
		if entry and predicate(entry) then
			table_insert(items, entry)
		end
	end

	return items
end

--- Get newest item
---@param self EnhancedRingBuffer
---@return table? entry Newest entry or nil
function EnhancedRingBuffer:latest()
	return self:get(0)
end

--- Get oldest item
---@param self EnhancedRingBuffer
---@return table? entry Oldest entry or nil
function EnhancedRingBuffer:oldest()
	return self:get(self.size - 1)
end

--- Clear buffer
---@param self EnhancedRingBuffer
function EnhancedRingBuffer:clear()
	self.buf = {}
	self.head = 0
	self.size = 0
end

--- Create iterator over items (newest to oldest)
---@param self EnhancedRingBuffer
---@return function iterator Iterator function
function EnhancedRingBuffer:iter()
	local i = -1
	return function()
		i = i + 1
		return self:get(i)
	end
end

--- Get buffer statistics
---@param self EnhancedRingBuffer
---@return table stats Buffer statistics
function EnhancedRingBuffer:getStats()
	return {
		capacity = self.capacity,
		size = self.size,
		utilization = self.size / self.capacity,
		oldestTimestamp = self:oldest() and self:oldest().timestamp,
		newestTimestamp = self:latest() and self:latest().timestamp,
		timeSpan = self:oldest() and self:latest() and (self:latest().timestamp - self:oldest().timestamp)
	}
end

----------------------------------------------------------------------
-- SECTION: DETERMINISTIC SNAPSHOT STRUCT
----------------------------------------------------------------------

--- Deterministic snapshot structure with standardized fields
---@class DeterministicSnapshot
---@field tick integer Game tick
---@field timestamp number High-resolution timestamp
---@field position table Position {x, y, z}
---@field velocity table Velocity {vx, vy, vz}
---@field angles table Angles {yaw, pitch, roll}
---@field movement table Movement state
---@field input table Input state
---@field weapon table Weapon state
---@field meta table Additional metadata
local DeterministicSnapshot = class("DeterministicSnapshot")

--- Create deterministic snapshot from raw data
---@param self DeterministicSnapshot
---@param data table Raw snapshot data
function DeterministicSnapshot:init(data)
	data = data or {}

	-- Core fields with validation
	self.tick = self:_validateNumber(data.tick, 0)
	self.timestamp = self:_validateNumber(data.t or data.timestamp, Util.now())

	-- Position with validation
	self.position = {
		x = self:_validateNumber(data.x, 0),
		y = self:_validateNumber(data.y, 0),
		z = self:_validateNumber(data.z, 0)
	}

	-- Velocity with validation
	self.velocity = {
		vx = self:_validateNumber(data.vx, 0),
		vy = self:_validateNumber(data.vy, 0),
		vz = self:_validateNumber(data.vz, 0)
	}

	-- Angles with validation and normalization
	self.angles = {
		yaw = self:_normalizeAngle(data.yaw or data.angle_yaw or 0),
		pitch = self:_clampAngle(data.pitch or data.angle_pitch or 0),
		roll = self:_normalizeAngle(data.roll or 0)
	}

	-- Movement state
	self.movement = {
		grounded = self:_validateBoolean(data.grounded, false),
		swimming = self:_validateBoolean(data.swimming, false),
		crouching = self:_validateBoolean(data.crouching, false),
		sprinting = self:_validateBoolean(data.sprinting, false),
		inVehicle = self:_validateBoolean(data.inVehicle, false),
		onLadder = self:_validateBoolean(data.onLadder, false)
	}

	-- Input state
	self.input = {
		forward = self:_validateBoolean(data.forward or data.input_forward, false),
		backward = self:_validateBoolean(data.backward or data.input_backward, false),
		left = self:_validateBoolean(data.left or data.input_left, false),
		right = self:_validateBoolean(data.right or data.input_right, false),
		jump = self:_validateBoolean(data.jump or data.input_jump, false),
		crouch = self:_validateBoolean(data.crouch or data.input_crouch, false),
		sprint = self:_validateBoolean(data.sprint or data.input_sprint, false),
		fire = self:_validateBoolean(data.fire or data.input_fire, false),
		aim = self:_validateBoolean(data.aim or data.input_aim, false)
	}

	-- Weapon state
	self.weapon = {
		weaponId = data.weaponId or "unknown",
		ammo = self:_validateNumber(data.ammo, 0),
		ammoInClip = self:_validateNumber(data.ammoInClip, 0),
		isReloading = self:_validateBoolean(data.isReloading, false),
		isAiming = self:_validateBoolean(data.isAiming, false),
		fireMode = data.fireMode or "semi"
	}

	-- Network and performance metadata
	self.meta = {
		ping = self:_validateNumber(data.ping, 0),
		jitter = self:_validateNumber(data.jitter, 0),
		packetLoss = self:_validateNumber(data.packetLoss, 0),
		fps = self:_validateNumber(data.fps, 60),
		serverTime = self:_validateNumber(data.serverTime, self.timestamp),
		clientTime = self:_validateNumber(data.clientTime, self.timestamp),
		timeDelta = self:_validateNumber(data.timeDelta, 0)
	}

	-- Store any additional metadata
	if data.meta and type(data.meta) == "table" then
		for k, v in next, data.meta do
			if not self.meta[k] then
				self.meta[k] = v
			end
		end
	end

	-- Generate deterministic hash
	self.hash = self:_generateHash()
end

--- Validate and clamp numeric value
---@param self DeterministicSnapshot
---@param value any Value to validate
---@param default number Default value
---@return number validated Validated number
function DeterministicSnapshot:_validateNumber(value, default)
	local num = tonumber(value)
	if not num or Util.is_invalid(num) then
		return default
	end
	return num
end

--- Validate boolean value
---@param self DeterministicSnapshot
---@param value any Value to validate
---@param default boolean Default value
---@return boolean validated Validated boolean
function DeterministicSnapshot:_validateBoolean(value, default)
	if value == nil then return default end
	return value == true
end

--- Normalize angle to 0-360 range
---@param self DeterministicSnapshot
---@param angle number Angle to normalize
---@return number normalized Normalized angle
function DeterministicSnapshot:_normalizeAngle(angle)
	angle = self:_validateNumber(angle, 0)
	while angle < 0 do angle = angle + 360 end
	while angle >= 360 do angle = angle - 360 end
	return angle
end

--- Clamp pitch angle to -90 to 90 range
---@param self DeterministicSnapshot
---@param angle number Angle to clamp
---@return number clamped Clamped angle
function DeterministicSnapshot:_clampAngle(angle)
	angle = self:_validateNumber(angle, 0)
	return Util.clamp(angle, -90, 90)
end

--- Generate deterministic hash of snapshot
---@param self DeterministicSnapshot
---@return number hash Hash value
function DeterministicSnapshot:_generateHash()
	local hashData = string_format("%d:%.3f:%.3f:%.3f:%.3f:%.3f:%.3f:%.3f:%.3f",
		self.tick,
		self.position.x, self.position.y, self.position.z,
		self.velocity.vx, self.velocity.vy, self.velocity.vz,
		self.angles.yaw, self.angles.pitch
	)
	return Util.fnv1a32(hashData)
end

--- Convert to legacy PlayerSnapshot format
---@param self DeterministicSnapshot
---@return PlayerSnapshot legacy Legacy snapshot
function DeterministicSnapshot:toLegacy()
	return PlayerSnapshot({
		tick = self.tick,
		t = self.timestamp,
		x = self.position.x,
		y = self.position.y,
		z = self.position.z,
		vx = self.velocity.vx,
		vy = self.velocity.vy,
		vz = self.velocity.vz,
		yaw = self.angles.yaw,
		pitch = self.angles.pitch,
		grounded = self.movement.grounded,
		inputs = self.input,
		meta = self.meta
	})
end

--- Calculate distance to another snapshot
---@param self DeterministicSnapshot
---@param other DeterministicSnapshot Other snapshot
---@return number distance 3D distance
function DeterministicSnapshot:distanceTo(other)
	if not other then return 0 end

	local dx = self.position.x - other.position.x
	local dy = self.position.y - other.position.y
	local dz = self.position.z - other.position.z

	return Util.len3(dx, dy, dz)
end

--- Calculate velocity magnitude
---@param self DeterministicSnapshot
---@return number speed Speed magnitude
function DeterministicSnapshot:getSpeed()
	return Util.len3(self.velocity.vx, self.velocity.vy, self.velocity.vz)
end

--- Check if snapshot is valid
---@param self DeterministicSnapshot
---@return boolean valid Whether snapshot is valid
function DeterministicSnapshot:isValid()
	-- Check for invalid values
	if Util.is_invalid(self.timestamp) or Util.is_invalid(self.tick) then
		return false
	end

	-- Check position validity
	if Util.is_invalid(self.position.x) or Util.is_invalid(self.position.y) or Util.is_invalid(self.position.z) then
		return false
	end

	-- Check velocity validity
	if Util.is_invalid(self.velocity.vx) or Util.is_invalid(self.velocity.vy) or Util.is_invalid(self.velocity.vz) then
		return false
	end

	-- Check hash consistency
	local currentHash = self:_generateHash()
	if self.hash ~= currentHash then
		return false
	end

	return true
end

--- Get snapshot summary
---@param self DeterministicSnapshot
---@return table summary Snapshot summary
function DeterministicSnapshot:getSummary()
	return {
		tick = self.tick,
		timestamp = self.timestamp,
		position = { x = self.position.x, y = self.position.y, z = self.position.z },
		speed = self:getSpeed(),
		angles = { yaw = self.angles.yaw, pitch = self.angles.pitch },
		grounded = self.movement.grounded,
		weaponId = self.weapon.weaponId,
		ping = self.meta.ping,
		hash = self.hash
	}
end

--- Create deterministic snapshot from PlayerSnapshot
---@param snapshot PlayerSnapshot Legacy snapshot
---@return DeterministicSnapshot deterministic Deterministic snapshot
function DeterministicSnapshot.fromLegacy(snapshot)
	if not snapshot then return nil end

	return DeterministicSnapshot({
		tick = snapshot.tick,
		t = snapshot.t,
		x = snapshot.x,
		y = snapshot.y,
		z = snapshot.z,
		vx = snapshot.vx,
		vy = snapshot.vy,
		vz = snapshot.vz,
		yaw = snapshot.yaw,
		pitch = snapshot.pitch,
		grounded = snapshot.grounded,
		forward = snapshot.inputs and snapshot.inputs.forward,
		backward = snapshot.inputs and snapshot.inputs.backward,
		left = snapshot.inputs and snapshot.inputs.left,
		right = snapshot.inputs and snapshot.inputs.right,
		jump = snapshot.inputs and snapshot.inputs.jump,
		crouch = snapshot.inputs and snapshot.inputs.crouch,
		sprint = snapshot.inputs and snapshot.inputs.sprint,
		fire = snapshot.inputs and snapshot.inputs.fire,
		aim = snapshot.inputs and snapshot.inputs.aim,
		meta = snapshot.meta
	})
end

----------------------------------------------------------------------
-- SuperJumpDetection
----------------------------------------------------------------------

--- Super jump detection strategy
---@class SuperJumpDetection : DetectionStrategy
---@field max_vy? number Maximum vertical velocity threshold
---@field severity_scale number Severity scaling factor
---@field min_dt number Minimum time delta for validation
local SuperJumpDetection = class("SuperJumpDetection", DetectionStrategy)

--- Initialize super jump detection
---@param self SuperJumpDetection
---@param opts? table Configuration options
function SuperJumpDetection:init(opts)
	DetectionStrategy.init(self, "superjump", opts)
	opts                = opts or {}
	self.max_vy         = opts.max_vy
	self.severity_scale = Util.get_opt(opts, "severity_scale", 8)
	self.min_dt         = Util.get_opt(opts, "min_dt", 0.05)
end

function SuperJumpDetection:check(ctx)
	local s, p = ctx.sample, ctx.prev
	local dt = safe_dt(s, p, self.min_dt)
	if not dt then return end

	local vy = (s.y - p.y) / dt
	local maxVy = self.max_vy or ctx.model.max_vertical_speed

	if vy > maxVy then
		local over = vy / math_max(0.001, maxVy)
		return Violation("superjump", (over - 1) * self.severity_scale, {
			vy = vy,
			maxVy = maxVy,
			dt = dt,
			dy = s.y - p.y,
			meta = s.meta or {},
		}, s.t)
	end
end

----------------------------------------------------------------------
-- FlyHackDetection
----------------------------------------------------------------------

--- Fly hack detection strategy for sustained airborne horizontal movement
---@class FlyHackDetection : DetectionStrategy
---@field min_airborne_ticks integer Minimum airborne ticks before detection
---@field min_horiz_speed number Minimum horizontal speed threshold
---@field min_dt number Minimum time delta for validation
---@field severity_per_tick number Severity score per tick over threshold
local FlyHackDetection = class("FlyHackDetection", DetectionStrategy)

--- Initialize fly hack detection
---@param self FlyHackDetection
---@param opts? table Configuration options
function FlyHackDetection:init(opts)
	DetectionStrategy.init(self, "fly", opts)
	opts                    = opts or {}
	self.min_airborne_ticks = Util.get_opt(opts, "min_airborne_ticks", 10)
	self.min_horiz_speed    = Util.get_opt(opts, "min_horiz_speed", 4.0)
	self.min_dt             = Util.get_opt(opts, "min_dt", 0.05)
	self.severity_per_tick  = Util.get_opt(opts, "severity_per_tick", 0.8)
end

function FlyHackDetection:check(ctx)
	local s = ctx.sample
	if not s then return end
	if ctx.track.state.airborneTicks < self.min_airborne_ticks then return end

	local p = ctx.prev
	local dt = safe_dt(s, p, self.min_dt)
	if not dt then return end

	local dx, _, dz = pos_delta(s, p)
	local speed = Util.len2(dx, dz) / dt

	if speed > self.min_horiz_speed then
		local excess = ctx.track.state.airborneTicks - self.min_airborne_ticks
		return Violation("fly", self.severity_per_tick * (1 + excess * 0.1), {
			airborneTicks = ctx.track.state.airborneTicks,
			horizSpeed = speed,
			meta = s.meta or {},
		}, s.t)
	end
end

----------------------------------------------------------------------
-- AccelerationDetection
----------------------------------------------------------------------

--- Acceleration detection strategy for impossible velocity changes
---@class AccelerationDetection : DetectionStrategy
---@field max_accel? number Maximum acceleration threshold
---@field min_dt number Minimum time delta for validation
---@field severity_scale number Severity scaling factor
local AccelerationDetection = class("AccelerationDetection", DetectionStrategy)

--- Initialize acceleration detection
---@param self AccelerationDetection
---@param opts? table Configuration options
function AccelerationDetection:init(opts)
	DetectionStrategy.init(self, "acceleration", opts)
	opts                = opts or {}
	self.max_accel      = opts.max_accel
	self.min_dt         = Util.get_opt(opts, "min_dt", 0.05)
	self.severity_scale = Util.get_opt(opts, "severity_scale", 5)
end

function AccelerationDetection:check(ctx)
	local s, p = ctx.sample, ctx.prev
	local dt = safe_dt(s, p, self.min_dt)
	if not dt then return end

	-- Need a third sample for velocity estimation
	local pp = ctx.track:sampleAt(3)
	if not pp or not pp.t or not p.t then return end
	local dtPrev = p.t - pp.t
	if dtPrev <= self.min_dt then return end

	-- Current velocity (prefer explicit, fall back to position delta)
	local v1x, v1y, v1z
	if s.vx ~= nil then
		v1x, v1y, v1z = s.vx, s.vy, s.vz
	else
		v1x, v1y, v1z = (s.x - p.x) / dt, (s.y - p.y) / dt, (s.z - p.z) / dt
	end

	-- Previous velocity
	local v0x, v0y, v0z
	if p.vx ~= nil then
		v0x, v0y, v0z = p.vx, p.vy, p.vz
	else
		v0x, v0y, v0z = (p.x - pp.x) / dtPrev, (p.y - pp.y) / dtPrev, (p.z - pp.z) / dtPrev
	end

	local accel = Util.len3(v1x - v0x, v1y - v0y, v1z - v0z) / dt
	local maxA  = self.max_accel or ctx.model.max_acceleration

	if accel > maxA then
		local over = accel / math_max(0.001, maxA)
		return Violation("acceleration", (over - 1) * self.severity_scale, {
			accel = accel,
			maxAccel = maxA,
			dt = dt,
			meta = s.meta or {},
		}, s.t)
	end
end

----------------------------------------------------------------------
-- SimulationDetection
----------------------------------------------------------------------

--- Simulation detection strategy using deterministic physics prediction<br>
--- The most powerful movement validation. Uses a deterministic simulator to predict<br>
--- where the player should be, and compares it to their reported state
---@class SimulationDetection : DetectionStrategy
---@field simulator? MovementSimulator Physics simulator for prediction
---@field position_tolerance number Maximum position deviation tolerance
---@field severity_scale number Severity scaling factor
local SimulationDetection = class("SimulationDetection", DetectionStrategy)

--- Initialize simulation detection
---@param self SimulationDetection
---@param opts? table Configuration options
function SimulationDetection:init(opts)
	DetectionStrategy.init(self, "simulation", opts)
	opts = opts or {}
	self.simulator = opts.simulator -- MovementSimulator instance
	self.position_tolerance = Util.get_opt(opts, "position_tolerance", 1.5)
	self.severity_scale = Util.get_opt(opts, "severity_scale", 5)
end

function SimulationDetection:check(ctx)
	if not self.simulator then return end
	local s, p = ctx.sample, ctx.prev
	if not s or not p then return end
	local dt = s.t - p.t
	if dt <= 0 then return end

	-- Run deterministic simulation from previous state using current reported inputs
	local ok, predicted = pcall(self.simulator.simulate, self.simulator, p, s.inputs or {}, dt)
	if not ok or not predicted then return end

	local dx = s.x - predicted.x
	local dy = s.y - predicted.y
	local dz = s.z - predicted.z
	local dist = Util.len3(dx, dy, dz)

	if dist > self.position_tolerance then
		local over = dist / self.position_tolerance
		return Violation("simulation", (over - 1) * self.severity_scale, {
			predicted = { x = predicted.x, y = predicted.y, z = predicted.z },
			actual    = { x = s.x, y = s.y, z = s.z },
			delta     = dist,
			tolerance = self.position_tolerance,
		}, s.t)
	end
end

----------------------------------------------------------------------
-- HeightViolationDetection
----------------------------------------------------------------------

--- Height violation detection strategy for world boundary violations
---@class HeightViolationDetection : DetectionStrategy
---@field floor_y? number Minimum world Y coordinate (nil = use model)
---@field ceiling_y? number Maximum world Y coordinate (nil = use model)
---@field severity number Base severity score
---@field ignore_if_flying boolean Whether to ignore violations when flying
local HeightViolationDetection = class("HeightViolationDetection", DetectionStrategy)

--- Initialize height violation detection
---@param self HeightViolationDetection
---@param opts? table Configuration options
function HeightViolationDetection:init(opts)
	DetectionStrategy.init(self, "height", opts)
	opts                  = opts or {}
	self.floor_y          = opts.floor_y
	self.ceiling_y        = opts.ceiling_y
	self.severity         = Util.get_opt(opts, "severity", 8)
	self.ignore_if_flying = Util.get_opt(opts, "ignore_if_flying", false)
end

function HeightViolationDetection:check(ctx)
	local s = ctx.sample
	if not s then return end

	local meta = s.meta or {}
	if self.ignore_if_flying and meta.isFlying then return end

	local floor   = self.floor_y or ctx.model.world_floor_y
	local ceiling = self.ceiling_y or ctx.model.world_ceiling_y
	local detail

	if s.y < floor then
		detail = "below_floor"
	elseif s.y > ceiling then
		detail = "above_ceiling"
	end

	if detail then
		return Violation("height", self.severity, {
			y = s.y,
			floor = floor,
			ceiling = ceiling,
			detail = detail,
			meta = meta,
		}, s.t)
	end
end

----------------------------------------------------------------------
-- PacketAnomalyDetection
----------------------------------------------------------------------

--- Packet anomaly detection strategy for timing irregularities
---@class PacketAnomalyDetection : DetectionStrategy
---@field min_interval? number Minimum packet interval threshold (nil = use model)
---@field max_interval? number Maximum packet interval threshold (nil = use model)
---@field severity_scale number Severity scaling factor
local PacketAnomalyDetection = class("PacketAnomalyDetection", DetectionStrategy)

--- Initialize packet anomaly detection
---@param self PacketAnomalyDetection
---@param opts? table Configuration options
function PacketAnomalyDetection:init(opts)
	DetectionStrategy.init(self, "packet_anomaly", opts)
	opts                = opts or {}
	self.min_interval   = opts.min_interval
	self.max_interval   = opts.max_interval
	self.severity_scale = Util.get_opt(opts, "severity_scale", 5)
end

function PacketAnomalyDetection:check(ctx)
	local s, p = ctx.sample, ctx.prev
	if not s or not p or not s.t or not p.t then return end

	local dt = s.t - p.t
	if dt <= 0.001 then return end -- FIX: reject same-tick / out-of-order with small epsilon

	local minI = self.min_interval or ctx.model.min_packet_interval
	local maxI = self.max_interval or ctx.model.max_packet_interval

	if dt < minI then
		local over = minI / math_max(0.0001, dt)
		return Violation("packet_anomaly", (over - 1) * self.severity_scale, {
			dt = dt,
			minInterval = minI,
			detail = "too_fast",
			meta = s.meta or {},
		}, s.t)
	end

	if dt > maxI then
		local over = dt / math_max(0.0001, maxI)
		return Violation("packet_anomaly", (over - 1) * self.severity_scale, {
			dt = dt,
			maxInterval = maxI,
			detail = "too_slow",
			meta = s.meta or {},
		}, s.t)
	end
end

----------------------------------------------------------------------
-- InvalidStateDetection
----------------------------------------------------------------------

---@class ValidationRule
---@field name string Human-readable name for the validation rule
---@field check fun(metadata: table): boolean Function that takes metadata and returns boolean (true = invalid state)

--- Invalid state detection strategy for impossible player state combinations.<br>
--- Detects when player metadata contains logically impossible or inconsistent states
--- such as being both grounded and falling at extreme speeds simultaneously
---@class InvalidStateDetection : DetectionStrategy
---@field severity number Base severity score for invalid state violations
---@field rules ValidationRule[] Array of validation rules with name and check function
local InvalidStateDetection = class("InvalidStateDetection", DetectionStrategy)

--- Initialize invalid state detection strategy
---@param self InvalidStateDetection
---@param opts? table Optional configuration options:
--- - `severity` (number, default: 6): Base severity score
--- - `rules` (table, default: {}): Initial validation rules array
function InvalidStateDetection:init(opts)
	if opts and type(opts) ~= "table" then
		return error("InvalidStateDetection:init - opts must be table or nil", 2)
	end

	DetectionStrategy.init(self, "invalid_state", opts)
	opts          = opts or {}
	self.severity = Util.get_opt(opts, "severity", 6)
	self.rules    = Util.get_opt(opts, "rules", {})

	if type(self.severity) ~= "number" or self.severity < 1 or self.severity > 10 then
		return error("InvalidStateDetection:init - severity must be number between 1-10", 2)
	end
	if type(self.rules) ~= "table" then
		return error("InvalidStateDetection:init - rules must be table", 2)
	end
end

--- Add a new validation rule for detecting invalid states
---@param self InvalidStateDetection
---@param name string Human-readable name for the validation rule
---@param checkFn function Function that receives metadata table and returns boolean (true = invalid state)
---@param checkFn table Player metadata snapshot to validate
---@return InvalidStateDetection self Returns self for method chaining
function InvalidStateDetection:addRule(name, checkFn)
	if type(name) ~= "string" or name == "" then
		return error("InvalidStateDetection:addRule - name must be non-empty string", 2)
	end
	if type(checkFn) ~= "function" then
		return error("InvalidStateDetection:addRule - checkFn must be function", 2)
	end
	table_insert(self.rules, { name = name, check = checkFn })
	return self
end

function InvalidStateDetection:check(ctx)
	local s = ctx.sample
	if not s then return end
	local meta = s.meta or {}
	local violations = {}

	-- Built-in impossible-state rules
	if meta.sprinting and meta.crouching then violations[#violations + 1] = "sprint+crouch" end
	if meta.sprinting and meta.crawling then violations[#violations + 1] = "sprint+crawl" end
	if meta.sprinting and meta.standing_still then violations[#violations + 1] = "sprint+standing_still" end
	if meta.dead and meta.sprinting then violations[#violations + 1] = "dead+sprinting" end
	if meta.dead and meta.moving then violations[#violations + 1] = "dead+moving" end
	if meta.grounded and s.vy and s.vy < -30
	then
		violations[#violations + 1] = "grounded+fast_fall"
	end
	if meta.crouching and meta.jumping then violations[#violations + 1] = "crouch+jump" end

	-- Check for invalid numerical values (infinity/NaN) in position
	if Util.is_invalid(s.x) then violations[#violations + 1] = "invalid_position_x" end
	if Util.is_invalid(s.y) then violations[#violations + 1] = "invalid_position_y" end
	if Util.is_invalid(s.z) then violations[#violations + 1] = "invalid_position_z" end

	-- Check for invalid numerical values (infinity/NaN) in velocity
	if Util.is_invalid(s.vx) then violations[#violations + 1] = "invalid_velocity_x" end
	if Util.is_invalid(s.vy) then violations[#violations + 1] = "invalid_velocity_y" end
	if Util.is_invalid(s.vz) then violations[#violations + 1] = "invalid_velocity_z" end

	-- Check for invalid numerical values (infinity/NaN) in angles
	if Util.is_invalid(s.yaw) then violations[#violations + 1] = "invalid_yaw" end
	if Util.is_invalid(s.pitch) then violations[#violations + 1] = "invalid_pitch" end

	-- Check for invalid numerical values (infinity/NaN) in meta angles
	if meta.yaw and Util.is_invalid(meta.yaw) then violations[#violations + 1] = "invalid_meta_yaw" end
	if meta.pitch and Util.is_invalid(meta.pitch) then violations[#violations + 1] = "invalid_meta_pitch" end

	-- User-supplied rules
	for i = 1, #self.rules do
		local rule = self.rules[i]
		local ok, result = pcall(rule.check, meta)
		if ok and result then violations[#violations + 1] = rule.name end
	end

	if #violations > 0 then
		return Violation("invalid_state", self.severity * #violations, {
			states = violations, meta = meta,
		}, s.t)
	end
end

----------------------------------------------------------------------
-- WaterWalkDetection
----------------------------------------------------------------------

--- Water walk detection strategy for walking on water violations
---@class WaterWalkDetection : DetectionStrategy
---@field water_level_y? number Water level Y coordinate (nil = use model)
---@field tolerance number Distance tolerance from water surface
---@field min_airborne_ticks integer Minimum airborne ticks before detection
---@field severity number Base severity score
local WaterWalkDetection = class("WaterWalkDetection", DetectionStrategy)

--- Initialize water walk detection
---@param self WaterWalkDetection
---@param opts? table Configuration options
function WaterWalkDetection:init(opts)
	DetectionStrategy.init(self, "waterwalk", opts)
	opts                    = opts or {}
	self.water_level_y      = opts.water_level_y
	self.tolerance          = Util.get_opt(opts, "tolerance", 1.0)
	self.min_airborne_ticks = Util.get_opt(opts, "min_airborne_ticks", 5)
	self.severity           = Util.get_opt(opts, "severity", 7)
end

function WaterWalkDetection:check(ctx)
	local s = ctx.sample
	if not s then return end

	local waterY = self.water_level_y or ctx.model.water_level_y
	if not waterY then return end

	local meta = s.meta or {}
	if meta.swimming or meta.in_water or meta.on_boat or meta.on_vehicle then return end

	local nearSurface = math_abs(s.y - waterY) <= self.tolerance
	if not nearSurface then return end

	-- Airborne near water surface
	if ctx.track.state.airborneTicks >= self.min_airborne_ticks then
		return Violation("waterwalk", self.severity, {
			y = s.y,
			waterLevelY = waterY,
			airborneTicks = ctx.track.state.airborneTicks,
			meta = meta,
		}, s.t)
	end

	-- Claims grounded while on water surface
	if s.grounded then
		return Violation("waterwalk", self.severity * 0.5, {
			y = s.y,
			waterLevelY = waterY,
			detail = "grounded_on_water",
			meta = meta,
		}, s.t)
	end
end

----------------------------------------------------------------------
-- NoClipDetection
----------------------------------------------------------------------

--- No-clip detection strategy for solid object collision violations<br>
--- Requires the integrator to supply a collision callback
---@class NoClipDetection : DetectionStrategy
---@field check_collision? function Collision detection function (x,y,z) -> bool (true = solid)
---@field min_distance number Minimum distance before checking collisions
---@field step_size number Step size for collision checking
---@field severity number Base severity score
local NoClipDetection = class("NoClipDetection", DetectionStrategy)

--- Initialize no-clip detection
---@param self NoClipDetection
---@param opts? table Configuration options
function NoClipDetection:init(opts)
	DetectionStrategy.init(self, "noclip", opts)
	opts                 = opts or {}
	self.check_collision = opts.check_collision -- function(x,y,z) -> bool (true = solid)
	self.min_distance    = Util.get_opt(opts, "min_distance", 2.0)
	self.step_size       = Util.get_opt(opts, "step_size", 0.5)
	self.severity        = Util.get_opt(opts, "severity", 10)
end

function NoClipDetection:check(ctx)
	local s, p = ctx.sample, ctx.prev
	if not s or not p then return end
	if not self.check_collision then return end

	local dx, dy, dz = pos_delta(s, p)
	local dist = Util.len3(dx, dy, dz)
	if dist < self.min_distance then return end

	local steps = math.ceil(dist / self.step_size)
	for i = 1, steps - 1 do
		local t         = i / steps
		local cx        = Util.lerp(p.x, s.x, t)
		local cy        = Util.lerp(p.y, s.y, t)
		local cz        = Util.lerp(p.z, s.z, t)
		local ok, solid = pcall(self.check_collision, cx, cy, cz)
		if ok and solid then
			return Violation("noclip", self.severity, {
				from = { p.x, p.y, p.z },
				to = { s.x, s.y, s.z },
				collisionPoint = { cx, cy, cz },
				dist = dist,
				meta = s.meta or {},
			}, s.t)
		end
	end
end

----------------------------------------------------------------------
-- SpinDetection (aimbot / spin-bot indicator)
----------------------------------------------------------------------

--- Spin detection strategy for aimbot and spin-bot detection<br>
--- Detects impossible rotation rates that indicate automated aiming
---@class SpinDetection : DetectionStrategy
---@field max_yaw_rate? number Maximum yaw rotation rate threshold (nil = use model)
---@field max_pitch_rate? number Maximum pitch rotation rate threshold (nil = use model)
---@field min_dt number Minimum time delta for validation
---@field severity_scale number Severity scaling factor
local SpinDetection = class("SpinDetection", DetectionStrategy)

--- Initialize spin detection
---@param self SpinDetection
---@param opts? table Configuration options
function SpinDetection:init(opts)
	DetectionStrategy.init(self, "spin", opts)
	opts                = opts or {}
	self.max_yaw_rate   = opts.max_yaw_rate
	self.max_pitch_rate = opts.max_pitch_rate
	self.min_dt         = Util.get_opt(opts, "min_dt", 0.05)
	self.severity_scale = Util.get_opt(opts, "severity_scale", 4)
end

function SpinDetection:check(ctx)
	local s, p = ctx.sample, ctx.prev
	local dt = safe_dt(s, p, self.min_dt)
	if not dt then return end

	local sMeta              = s.meta or {}
	local pMeta              = p.meta or {}
	local yaw, pitch         = sMeta.yaw, sMeta.pitch
	local prevYaw, prevPitch = pMeta.yaw, pMeta.pitch
	if yaw == nil or pitch == nil or prevYaw == nil or prevPitch == nil then
		return
	end

	local function angleDelta(a, b)
		local d = math_abs(a - b) % 360
		return d > 180 and (360 - d) or d
	end

	local yawRate   = angleDelta(yaw, prevYaw) / dt
	local pitchRate = angleDelta(pitch, prevPitch) / dt
	local maxYawR   = self.max_yaw_rate or ctx.model.max_yaw_rate
	local maxPitchR = self.max_pitch_rate or ctx.model.max_pitch_rate

	local violated  = false
	local details   = {}

	if yawRate > maxYawR then
		violated           = true
		details.yawRate    = yawRate
		details.maxYawRate = maxYawR
	end
	if pitchRate > maxPitchR then
		violated             = true
		details.pitchRate    = pitchRate
		details.maxPitchRate = maxPitchR
	end

	if violated then
		local maxRatio = math_max(
			yawRate / math_max(1, maxYawR),
			pitchRate / math_max(1, maxPitchR)
		)
		return Violation("spin", (maxRatio - 1) * self.severity_scale, details, s.t)
	end
end

----------------------------------------------------------------------
-- PatternAnalysisDetection
----------------------------------------------------------------------

--- Pattern analysis detection strategy for identifying movement patterns<br>
--- Detects repetitive or unnatural movement patterns indicative of bots
---@class PatternAnalysisDetection : DetectionStrategy
---@field history_size integer Number of recent movements to analyze
---@field pattern_threshold number Threshold for pattern similarity
---@field min_samples integer Minimum samples required for analysis
---@field severity_scale number Severity scaling factor
local PatternAnalysisDetection = class("PatternAnalysisDetection", DetectionStrategy)

--- Initialize pattern analysis detection
---@param self PatternAnalysisDetection
---@param opts? table Configuration options
function PatternAnalysisDetection:init(opts)
	DetectionStrategy.init(self, "pattern_analysis", opts)
	opts                   = opts or {}
	self.history_size      = Util.get_opt(opts, "history_size", 20)
	self.pattern_threshold = Util.get_opt(opts, "pattern_threshold", 0.85)
	self.min_samples       = Util.get_opt(opts, "min_samples", 10)
	self.severity_scale    = Util.get_opt(opts, "severity_scale", 6)
end

function PatternAnalysisDetection:check(ctx)
	local track = ctx.track
	if track.samples:count() < self.min_samples then return end

	-- Extract recent movement vectors
	local movements = {}
	for i = 1, math_min(self.history_size, track.samples:count()) do
		local snap = track:sampleAt(i)
		if snap then
			movements[#movements + 1] = { x = snap.x, y = snap.y, z = snap.z }
		end
	end

	if #movements < self.min_samples then return end

	-- Check for repetitive patterns
	local patternScore = self:_analyzePatterns(movements)
	if patternScore > self.pattern_threshold then
		return Violation("pattern_analysis", patternScore * self.severity_scale, {
			patternScore = patternScore,
			sampleCount = #movements,
			meta = ctx.sample.meta or {},
		}, ctx.sample.t)
	end
end

function PatternAnalysisDetection:_analyzePatterns(movements)
	-- Calculate movement vectors between consecutive positions
	local vectors = {}
	for i = 2, #movements do
		local dx = movements[i].x - movements[i - 1].x
		local dy = movements[i].y - movements[i - 1].y
		local dz = movements[i].z - movements[i - 1].z
		vectors[#vectors + 1] = { dx = dx, dy = dy, dz = dz }
	end

	-- Check for repetitive sequences
	local repetitions = 0
	local sequenceLength = 3

	for i = 1, #vectors - sequenceLength * 2 do
		local seq1 = { vectors[i], vectors[i + 1], vectors[i + 2] }
		local foundMatch = false

		for j = i + sequenceLength, #vectors - sequenceLength + 1 do
			local seq2 = { vectors[j], vectors[j + 1], vectors[j + 2] }
			if self:_sequencesMatch(seq1, seq2) then
				repetitions = repetitions + 1
				foundMatch = true
				break
			end
		end
	end

	return math_min(1.0, repetitions / (#vectors / sequenceLength))
end

function PatternAnalysisDetection:_sequencesMatch(seq1, seq2, tolerance)
	tolerance = tolerance or 0.1
	for i = 1, #seq1 do
		local dx = math_abs(seq1[i].dx - seq2[i].dx)
		local dy = math_abs(seq1[i].dy - seq2[i].dy)
		local dz = math_abs(seq1[i].dz - seq2[i].dz)
		if dx + dy + dz > tolerance then return false end
	end
	return true
end

----------------------------------------------------------------------
-- WallDetection
----------------------------------------------------------------------

--- Wall detection strategy for detecting movement through solid objects<br>
--- Enhanced version of NoClipDetection with wall-specific heuristics
---@class WallDetection : DetectionStrategy
---@field check_collision? function Collision detection function
---@field wall_thickness number Minimum wall thickness to detect
---@field penetration_tolerance number Maximum allowed penetration
---@field severity number Base severity score
local WallDetection = class("WallDetection", DetectionStrategy)

--- Initialize wall detection
---@param self WallDetection
---@param opts? table Configuration options
function WallDetection:init(opts)
	DetectionStrategy.init(self, "wall", opts)
	opts                       = opts or {}
	self.check_collision       = opts.check_collision
	self.wall_thickness        = Util.get_opt(opts, "wall_thickness", 1.0)
	self.penetration_tolerance = Util.get_opt(opts, "penetration_tolerance", 0.1)
	self.severity              = Util.get_opt(opts, "severity", 12)
end

function WallDetection:check(ctx)
	local s, p = ctx.sample, ctx.prev
	if not s or not p or not self.check_collision then return end

	-- Check if player moved through a wall
	if self:_checkWallPenetration(p, s) then
		return Violation("wall", self.severity, {
			from = { p.x, p.y, p.z },
			to = { s.x, s.y, s.z },
			wallThickness = self.wall_thickness,
			meta = s.meta or {},
		}, s.t)
	end
end

function WallDetection:_checkWallPenetration(from, to)
	local dx, dy, dz = pos_delta(to, from)
	local dist = Util.len3(dx, dy, dz)

	if dist < self.wall_thickness then return false end

	-- Sample multiple points along the movement path
	local samples = math_max(3, math_floor(dist / 0.5))
	for i = 1, samples do
		local t = i / samples
		local x = Util.lerp(from.x, to.x, t)
		local y = Util.lerp(from.y, to.y, t)
		local z = Util.lerp(from.z, to.z, t)

		local ok, isSolid = pcall(self.check_collision, x, y, z)
		if ok and isSolid then
			return true
		end
	end

	return false
end

----------------------------------------------------------------------
-- Network-Level Detection Strategies
----------------------------------------------------------------------

----------------------------------------------------------------------
-- PacketFloodDetection
----------------------------------------------------------------------

--- Packet flood detection strategy for detecting excessive packet rates<br>
--- Identifies players sending too many packets in short time periods
---@class PacketFloodDetection : DetectionStrategy
---@field max_packets_per_second number Maximum allowed packets per second
---@field window_size number Time window in seconds for analysis
---@field severity_scale number Severity scaling factor
local PacketFloodDetection = class("PacketFloodDetection", DetectionStrategy)

--- Initialize packet flood detection
---@param self PacketFloodDetection
---@param opts? table Configuration options
function PacketFloodDetection:init(opts)
	DetectionStrategy.init(self, "packet_flood", opts)
	opts                        = opts or {}
	self.max_packets_per_second = Util.get_opt(opts, "max_packets_per_second", 60)
	self.window_size            = Util.get_opt(opts, "window_size", 1.0)
	self.severity_scale         = Util.get_opt(opts, "severity_scale", 4)
end

function PacketFloodDetection:check(ctx)
	local s = ctx.sample
	if not s or not s.t then return end

	-- Count packets in the time window
	local packetCount = 0
	local currentTime = s.t

	-- Look back through recent samples
	for i = 1, ctx.track.samples:count() do
		local sample = ctx.track:sampleAt(i)
		if sample and sample.t then
			if currentTime - sample.t <= self.window_size then
				packetCount = packetCount + 1
			else
				break
			end
		end
	end

	local packetsPerSecond = packetCount / self.window_size
	if packetsPerSecond > self.max_packets_per_second then
		local over = packetsPerSecond / self.max_packets_per_second
		return Violation("packet_flood", (over - 1) * self.severity_scale, {
			packetsPerSecond = packetsPerSecond,
			maxAllowed = self.max_packets_per_second,
			windowSize = self.window_size,
			packetCount = packetCount,
			meta = s.meta or {},
		}, s.t)
	end
end

----------------------------------------------------------------------
-- LatencyAnomalyDetection
----------------------------------------------------------------------

--- Latency anomaly detection strategy for detecting unusual latency patterns<br>
--- Identifies players with inconsistent or manipulated latency
---@class LatencyAnomalyDetection : DetectionStrategy
---@field min_latency number Minimum expected latency in ms
---@field max_latency number Maximum expected latency in ms
---@field variance_threshold number Maximum allowed latency variance
---@field sample_size number Number of latency samples to analyze
---@field severity_scale number Severity scaling factor
local LatencyAnomalyDetection = class("LatencyAnomalyDetection", DetectionStrategy)

--- Initialize latency anomaly detection
---@param self LatencyAnomalyDetection
---@param opts? table Configuration options
function LatencyAnomalyDetection:init(opts)
	DetectionStrategy.init(self, "latency_anomaly", opts)
	opts                    = opts or {}
	self.min_latency        = Util.get_opt(opts, "min_latency", 10)
	self.max_latency        = Util.get_opt(opts, "max_latency", 500)
	self.variance_threshold = Util.get_opt(opts, "variance_threshold", 100)
	self.sample_size        = Util.get_opt(opts, "sample_size", 20)
	self.severity_scale     = Util.get_opt(opts, "severity_scale", 5)
end

function LatencyAnomalyDetection:check(ctx)
	local s = ctx.sample
	if not s or not s.t then return end

	-- Collect latency samples from recent packets
	local latencies = {}
	for i = 1, math_min(self.sample_size, ctx.track.samples:count()) do
		local sample = ctx.track:sampleAt(i)
		if sample and sample.meta and sample.meta.latency then
			latencies[#latencies + 1] = sample.meta.latency
		end
	end

	if #latencies < 5 then return end

	-- Calculate statistics
	local mean = 0
	for i = 1, #latencies do
		mean = mean + latencies[i]
	end
	mean = mean / #latencies

	local variance = 0
	for i = 1, #latencies do
		variance = variance + (latencies[i] - mean) ^ 2
	end
	variance = variance / #latencies
	local stdDev = math_sqrt(variance)

	-- Check for anomalies
	local anomalyScore = 0
	if mean < self.min_latency or mean > self.max_latency then
		anomalyScore = anomalyScore + 1
	end
	if stdDev > self.variance_threshold then
		anomalyScore = anomalyScore + 1
	end

	if anomalyScore > 0 then
		return Violation("latency_anomaly", anomalyScore * self.severity_scale, {
			meanLatency = mean,
			standardDeviation = stdDev,
			sampleCount = #latencies,
			anomalyScore = anomalyScore,
			meta = s.meta or {},
		}, s.t)
	end
end

----------------------------------------------------------------------
-- Behavioral Analysis Detection Strategies
----------------------------------------------------------------------

----------------------------------------------------------------------
-- BotDetection
----------------------------------------------------------------------

--- Bot detection strategy for identifying automated player behavior<br>
--- Analyzes input patterns, timing, and consistency indicators
---@class BotDetection : DetectionStrategy
---@field input_consistency_threshold number Threshold for input consistency
---@field reaction_time_variance number Maximum allowed reaction time variance
---@field behavior_window number Time window for behavior analysis
---@field severity_scale number Severity scaling factor
local BotDetection = class("BotDetection", DetectionStrategy)

--- Initialize bot detection
---@param self BotDetection
---@param opts? table Configuration options
function BotDetection:init(opts)
	DetectionStrategy.init(self, "bot", opts)
	opts                             = opts or {}
	self.input_consistency_threshold = Util.get_opt(opts, "input_consistency_threshold", 0.95)
	self.reaction_time_variance      = Util.get_opt(opts, "reaction_time_variance", 50)
	self.behavior_window             = Util.get_opt(opts, "behavior_window", 30)
	self.severity_scale              = Util.get_opt(opts, "severity_scale", 8)
end

function BotDetection:check(ctx)
	local s = ctx.sample
	if not s then return end

	-- Analyze input patterns
	local botScore = 0

	-- Check for superhuman consistency in timing
	if self:_checkInputConsistency(ctx) then
		botScore = botScore + 1
	end

	-- Check for unnatural reaction times
	if self:_checkReactionTimes(ctx) then
		botScore = botScore + 1
	end

	-- Check for perfect aim patterns
	if self:_checkAimPatterns(ctx) then
		botScore = botScore + 1
	end

	if botScore >= 2 then
		return Violation("bot", botScore * self.severity_scale, {
			botScore = botScore,
			indicators = {
				inputConsistency = self:_checkInputConsistency(ctx),
				reactionTimes = self:_checkReactionTimes(ctx),
				aimPatterns = self:_checkAimPatterns(ctx),
			},
			meta = s.meta or {},
		}, s.t)
	end
end

function BotDetection:_checkInputConsistency(ctx)
	-- Analyze timing consistency between inputs
	local intervals = {}
	local count = 0

	for i = 2, math_min(20, ctx.track.samples:count()) do
		local curr = ctx.track:sampleAt(i - 1)
		local prev = ctx.track:sampleAt(i)
		if curr and prev and curr.t and prev.t then
			intervals[#intervals + 1] = curr.t - prev.t
			count = count + 1
		end
	end

	if count < 5 then return false end

	-- Calculate coefficient of variation
	local mean = 0
	for i = 1, #intervals do
		mean = mean + intervals[i]
	end
	mean = mean / #intervals

	local variance = 0
	for i = 1, #intervals do
		variance = variance + (intervals[i] - mean) ^ 2
	end
	variance = variance / #intervals
	local stdDev = math_sqrt(variance)

	local cv = stdDev / mean
	return cv < (1 - self.input_consistency_threshold)
end

function BotDetection:_checkReactionTimes(ctx)
	-- Check for unnaturally consistent reaction times
	local reactionTimes = {}

	for i = 2, math_min(10, ctx.track.samples:count()) do
		local curr = ctx.track:sampleAt(i - 1)
		local prev = ctx.track:sampleAt(i)
		if curr and prev and curr.meta and prev.meta then
			local currReact = curr.meta.reaction_time
			local prevReact = prev.meta.reaction_time
			if currReact and prevReact then
				reactionTimes[#reactionTimes + 1] = math_abs(currReact - prevReact)
			end
		end
	end

	if #reactionTimes < 3 then return false end

	local avgDiff = 0
	for i = 1, #reactionTimes do
		avgDiff = avgDiff + reactionTimes[i]
	end
	avgDiff = avgDiff / #reactionTimes

	return avgDiff < self.reaction_time_variance
end

function BotDetection:_checkAimPatterns(ctx)
	-- Check for perfect aim tracking (no human error)
	local aimErrors = {}

	for i = 2, math_min(10, ctx.track.samples:count()) do
		local curr = ctx.track:sampleAt(i - 1)
		local prev = ctx.track:sampleAt(i)
		if curr and prev and curr.meta and prev.meta then
			local currYaw = curr.meta.yaw
			local currPitch = curr.meta.pitch
			local prevYaw = prev.meta.yaw
			local prevPitch = prev.meta.pitch

			if currYaw and currPitch and prevYaw and prevPitch then
				local yawError = math_abs(currYaw - prevYaw)
				local pitchError = math_abs(currPitch - prevPitch)
				aimErrors[#aimErrors + 1] = yawError + pitchError
			end
		end
	end

	if #aimErrors < 3 then return false end

	local avgError = 0
	for i = 1, #aimErrors do
		avgError = avgError + aimErrors[i]
	end
	avgError = avgError / #aimErrors

	-- Perfect aim (very low error) suggests bot
	return avgError < 0.1
end

----------------------------------------------------------------------
-- AFKDetection
----------------------------------------------------------------------

--- AFK detection strategy for detecting inactive players<br>
--- Monitors lack of meaningful player activity over time
---@class AFKDetection : DetectionStrategy
---@field inactivity_threshold number Time in seconds before considering AFK
---@field position_threshold number Minimum movement to reset AFK timer
---@field input_threshold number Minimum input activity to reset AFK timer
---@field severity number Base severity score
local AFKDetection = class("AFKDetection", DetectionStrategy)

--- Initialize AFK detection
---@param self AFKDetection
---@param opts? table Configuration options
function AFKDetection:init(opts)
	DetectionStrategy.init(self, "afk", opts)
	opts                      = opts or {}
	self.inactivity_threshold = Util.get_opt(opts, "inactivity_threshold", 300) -- 5 minutes
	self.position_threshold   = Util.get_opt(opts, "position_threshold", 0.5)
	self.input_threshold      = Util.get_opt(opts, "input_threshold", 1)
	self.severity             = Util.get_opt(opts, "severity", 3)
end

function AFKDetection:check(ctx)
	local s = ctx.sample
	if not s then return end

	-- Check for any meaningful activity
	local hasMovement = false
	local hasInput = false

	-- Check recent movement
	for i = 1, math_min(10, ctx.track.samples:count()) do
		local sample = ctx.track:sampleAt(i)
		if sample then
			local prev = ctx.track:sampleAt(i + 1)
			if prev then
				local dx, dy, dz = pos_delta(sample, prev)
				local dist = Util.len3(dx, dy, dz)
				if dist > self.position_threshold then
					hasMovement = true
					break
				end
			end
		end
	end

	-- Check input activity
	local meta = s.meta or {}
	if meta.input_count and meta.input_count > self.input_threshold then
		hasInput = true
	end

	-- Calculate inactivity time
	local lastActivityTime = s.t
	if not hasMovement and not hasInput then
		-- Find last activity
		for i = 1, ctx.track.samples:count() do
			local sample = ctx.track:sampleAt(i)
			if sample and sample.meta then
				local sampleMeta = sample.meta
				local hadMovement = false
				local hadInput = false

				if i < ctx.track.samples:count() then
					local nextSample = ctx.track:sampleAt(i + 1)
					if nextSample then
						local dx, dy, dz = pos_delta(nextSample, sample)
						local dist = Util.len3(dx, dy, dz)
						hadMovement = dist > self.position_threshold
					end
				end

				if sampleMeta.input_count and sampleMeta.input_count > self.input_threshold then
					hadInput = true
				end

				if hadMovement or hadInput then
					lastActivityTime = sample.t
					break
				end
			end
		end

		local inactiveTime = s.t - lastActivityTime
		if inactiveTime > self.inactivity_threshold then
			return Violation("afk", self.severity, {
				inactiveTime = inactiveTime,
				threshold = self.inactivity_threshold,
				hasMovement = hasMovement,
				hasInput = hasInput,
				meta = s.meta or {},
			}, s.t)
		end
	end
end

----------------------------------------------------------------------
-- RepetitiveActionDetection
----------------------------------------------------------------------

--- Repetitive action detection strategy for identifying spam behavior<br>
--- Detects excessive repetition of the same actions
---@class RepetitiveActionDetection : DetectionStrategy
---@field action_window number Time window to analyze actions
---@field repetition_threshold number Maximum allowed repetitions
---@field action_types table Types of actions to monitor
---@field severity_scale number Severity scaling factor
local RepetitiveActionDetection = class("RepetitiveActionDetection", DetectionStrategy)

--- Initialize repetitive action detection
---@param self RepetitiveActionDetection
---@param opts? table Configuration options
function RepetitiveActionDetection:init(opts)
	DetectionStrategy.init(self, "repetitive_action", opts)
	opts                      = opts or {}
	self.action_window        = Util.get_opt(opts, "action_window", 5.0)
	self.repetition_threshold = Util.get_opt(opts, "repetition_threshold", 10)
	self.action_types         = Util.get_opt(opts, "action_types", { "attack", "jump", "use" })
	self.severity_scale       = Util.get_opt(opts, "severity_scale", 4)
end

function RepetitiveActionDetection:check(ctx)
	local s = ctx.sample
	if not s then return end

	local meta = s.meta or {}
	local violations = {}

	-- Check each action type
	for i = 1, #self.action_types do
		local actionType = self.action_types[i]
		if meta.actions and meta.actions[actionType] then
			local count = self:_countRecentActions(ctx, actionType)
			if count > self.repetition_threshold then
				violations[#violations + 1] = {
					action = actionType,
					count = count,
					threshold = self.repetition_threshold,
				}
			end
		end
	end

	if #violations > 0 then
		return Violation("repetitive_action", #violations * self.severity_scale, {
			violations = violations,
			window = self.action_window,
			meta = meta,
		}, s.t)
	end
end

function RepetitiveActionDetection:_countRecentActions(ctx, actionType)
	local count = 0
	local currentTime = ctx.sample.t

	for i = 1, ctx.track.samples:count() do
		local sample = ctx.track:sampleAt(i)
		if sample and sample.t and (currentTime - sample.t) <= self.action_window then
			local sampleMeta = sample.meta or {}
			if sampleMeta.actions and sampleMeta.actions[actionType] then
				count = count + sampleMeta.actions[actionType]
			end
		end
	end

	return count
end

----------------------------------------------------------------------
-- Statistical Analysis Detection Strategies
----------------------------------------------------------------------

----------------------------------------------------------------------
-- StatisticalAnomalyDetection
----------------------------------------------------------------------

--- Statistical anomaly detection strategy using statistical analysis<br>
--- Identifies outliers and unusual patterns in player behavior
---@class StatisticalAnomalyDetection : DetectionStrategy
---@field sample_size number Number of samples for statistical analysis
---@field z_threshold number Z-score threshold for anomaly detection
---@field metrics table Metrics to analyze (speed, acceleration, etc.)
---@field severity_scale number Severity scaling factor
local StatisticalAnomalyDetection = class("StatisticalAnomalyDetection", DetectionStrategy)

--- Initialize statistical anomaly detection
---@param self StatisticalAnomalyDetection
---@param opts? table Configuration options
function StatisticalAnomalyDetection:init(opts)
	DetectionStrategy.init(self, "statistical_anomaly", opts)
	opts                = opts or {}
	self.sample_size    = Util.get_opt(opts, "sample_size", 50)
	self.z_threshold    = Util.get_opt(opts, "z_threshold", 3.0)
	self.metrics        = Util.get_opt(opts, "metrics", { "speed", "acceleration", "position" })
	self.severity_scale = Util.get_opt(opts, "severity_scale", 7)
end

function StatisticalAnomalyDetection:check(ctx)
	local track = ctx.track
	if track.samples:count() < self.sample_size then return end

	local anomalies = {}

	-- Analyze each metric
	for i = 1, #self.metrics do
		local metric = self.metrics[i]
		local anomalyScore = self:_analyzeMetric(track, metric)
		if anomalyScore > self.z_threshold then
			anomalies[#anomalies + 1] = {
				metric = metric,
				zScore = anomalyScore,
			}
		end
	end

	if #anomalies > 0 then
		return Violation("statistical_anomaly", #anomalies * self.severity_scale, {
			anomalies = anomalies,
			sampleSize = self.sample_size,
			threshold = self.z_threshold,
			meta = ctx.sample.meta or {},
		}, ctx.sample.t)
	end
end

function StatisticalAnomalyDetection:_analyzeMetric(track, metric)
	local values = {}

	-- Extract metric values from recent samples
	for i = 1, math_min(self.sample_size, track.samples:count()) do
		local sample = track:sampleAt(i)
		if sample then
			local value = self:_extractMetricValue(sample, metric)
			if value then values[#values + 1] = value end
		end
	end

	if #values < 10 then return 0 end

	-- Calculate statistics
	local mean = 0
	for i = 1, #values do mean = mean + values[i] end
	mean = mean / #values

	local variance = 0
	for i = 1, #values do variance = variance + (values[i] - mean) ^ 2 end
	variance = variance / #values
	local stdDev = math_sqrt(variance)

	if stdDev < 0.001 then return 0 end

	-- Calculate Z-score for latest value
	local latest = self:_extractMetricValue(track:latest(), metric)
	if not latest then return 0 end

	return math_abs(latest - mean) / stdDev
end

function StatisticalAnomalyDetection:_extractMetricValue(sample, metric)
	if metric == "speed" then
		if sample.vx and sample.vy and sample.vz then
			return Util.len3(sample.vx, sample.vy, sample.vz)
		end
	elseif metric == "position" then
		return sample.y -- Use height as position metric
	elseif metric == "acceleration" then
		-- Would need previous sample for acceleration calculation
		return nil
	end
	return nil
end

----------------------------------------------------------------------
-- TrendAnalysis
----------------------------------------------------------------------

--- Trend analysis detection strategy for identifying behavioral trends<br>
--- Detects gradual changes in player behavior over time
---@class TrendAnalysis : DetectionStrategy
---@field window_size number Time window for trend analysis
---@field trend_threshold number Threshold for trend significance
---@field metrics table Metrics to analyze for trends
---@field severity_scale number Severity scaling factor
local TrendAnalysis = class("TrendAnalysis", DetectionStrategy)

--- Initialize trend analysis detection
---@param self TrendAnalysis
---@param opts? table Configuration options
function TrendAnalysis:init(opts)
	DetectionStrategy.init(self, "trend_analysis", opts)
	opts                 = opts or {}
	self.window_size     = Util.get_opt(opts, "window_size", 100)
	self.trend_threshold = Util.get_opt(opts, "trend_threshold", 0.1)
	self.metrics         = Util.get_opt(opts, "metrics", { "speed", "height", "violation_rate" })
	self.severity_scale  = Util.get_opt(opts, "severity_scale", 5)
end

function TrendAnalysis:check(ctx)
	local track = ctx.track
	if track.samples:count() < self.window_size then return end

	local suspiciousTrends = {}

	for i = 1, #self.metrics do
		local metric = self.metrics[i]
		local trend = self:_analyzeTrend(track, metric)
		if trend and math_abs(trend.slope) > self.trend_threshold then
			suspiciousTrends[#suspiciousTrends + 1] = trend
		end
	end

	if #suspiciousTrends > 0 then
		return Violation("trend_analysis", #suspiciousTrends * self.severity_scale, {
			trends = suspiciousTrends,
			windowSize = self.window_size,
			threshold = self.trend_threshold,
			meta = ctx.sample.meta or {},
		}, ctx.sample.t)
	end
end

function TrendAnalysis:_analyzeTrend(track, metric)
	local values = {}
	local times = {}

	-- Extract values over time window
	for i = 1, math_min(self.window_size, track.samples:count()) do
		local sample = track:sampleAt(i)
		if sample and sample.t then
			local value = self:_extractTrendValue(sample, metric)
			if value then
				values[#values + 1] = value
				times[#times + 1] = sample.t
			end
		end
	end

	if #values < 10 then return nil end

	-- Simple linear regression to find trend
	local n = #values
	local sumX, sumY, sumXY, sumX2 = 0, 0, 0, 0

	for i = 1, n do
		sumX = sumX + times[i]
		sumY = sumY + values[i]
		sumXY = sumXY + times[i] * values[i]
		sumX2 = sumX2 + times[i] * times[i]
	end

	local slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX)
	local intercept = (sumY - slope * sumX) / n

	return {
		metric = metric,
		slope = slope,
		intercept = intercept,
		correlation = self:_calculateCorrelation(times, values),
	}
end

function TrendAnalysis:_extractTrendValue(sample, metric)
	if metric == "speed" then
		if sample.vx and sample.vy and sample.vz then
			return Util.len3(sample.vx, sample.vy, sample.vz)
		end
	elseif metric == "height" then
		return sample.y
	elseif metric == "violation_rate" then
		-- Would need access to violation history
		return nil
	end
	return nil
end

function TrendAnalysis:_calculateCorrelation(x, y)
	if #x ~= #y or #x < 2 then return 0 end

	local n = #x
	local sumX, sumY, sumXY, sumX2, sumY2 = 0, 0, 0, 0, 0

	for i = 1, n do
		sumX = sumX + x[i]
		sumY = sumY + y[i]
		sumXY = sumXY + x[i] * y[i]
		sumX2 = sumX2 + x[i] * x[i]
		sumY2 = sumY2 + y[i] * y[i]
	end

	local numerator = n * sumXY - sumX * sumY
	local denominator = math_sqrt((n * sumX2 - sumX * sumX) * (n * sumY2 - sumY * sumY))

	if denominator < 0.001 then return 0 end
	return numerator / denominator
end

----------------------------------------------------------------------
-- Machine Learning Detection Engine
----------------------------------------------------------------------

----------------------------------------------------------------------
-- MLDetectionEngine
----------------------------------------------------------------------

--- Machine learning detection engine for advanced pattern recognition<br>
--- Uses simplified ML algorithms for cheat detection
---@class MLDetectionEngine : DetectionStrategy
---@field model_type string Type of ML model to use
---@field training_data table Training data for the model
---@field model table Trained model parameters
---@field feature_extractors table Functions to extract features
---@field severity_scale number Severity scaling factor
local MLDetectionEngine = class("MLDetectionEngine", DetectionStrategy)

--- Initialize ML detection engine
---@param self MLDetectionEngine
---@param opts? table Configuration options
function MLDetectionEngine:init(opts)
	DetectionStrategy.init(self, "ml_detection", opts)
	opts                    = opts or {}
	self.model_type         = Util.get_opt(opts, "model_type", "simple_classifier")
	self.training_data      = Util.get_opt(opts, "training_data", {})
	self.model              = Util.get_opt(opts, "model", {})
	self.feature_extractors = Util.get_opt(opts, "feature_extractors", {
		"movement_features",
		"timing_features",
		"behavioral_features",
	})
	self.severity_scale     = Util.get_opt(opts, "severity_scale", 10)
end

function MLDetectionEngine:check(ctx)
	local track = ctx.track
	if track.samples:count() < 20 then return end

	-- Extract features
	local features = self:_extractFeatures(ctx)
	if not features then return end

	-- Make prediction
	local prediction = self:_predict(features)

	if prediction and prediction.probability > 0.8 then
		return Violation("ml_detection", prediction.probability * self.severity_scale, {
			prediction = prediction,
			features = features,
			modelType = self.model_type,
			meta = ctx.sample.meta or {},
		}, ctx.sample.t)
	end
end

function MLDetectionEngine:_extractFeatures(ctx)
	local features = {}

	for i = 1, #self.feature_extractors do
		local extractor = self.feature_extractors[i]
		local extracted = self:_extractFeatureType(ctx, extractor)
		if extracted then
			for k, v in next, extracted do
				features[k] = v
			end
		end
	end

	return features
end

function MLDetectionEngine:_extractFeatureType(ctx, featureType)
	if featureType == "movement_features" then
		return self:_extractMovementFeatures(ctx)
	end
	if featureType == "timing_features" then
		return self:_extractTimingFeatures(ctx)
	end
	if featureType == "behavioral_features" then
		return self:_extractBehavioralFeatures(ctx)
	end
	return nil
end

function MLDetectionEngine:_extractMovementFeatures(ctx)
	local track = ctx.track
	local features = {}

	-- Recent movement statistics
	local speeds = {}
	for i = 1, math.min(10, track.samples:count()) do
		local sample = track:sampleAt(i)
		if sample and sample.vx and sample.vy and sample.vz then
			speeds[#speeds + 1] = Util.len3(sample.vx, sample.vy, sample.vz)
		end
	end

	if #speeds > 0 then
		local sum = 0
		for i = 1, #speeds do sum = sum + speeds[i] end
		features.avg_speed = sum / #speeds
		features.max_speed = math_max(table_unpack(speeds))
		features.speed_variance = self:_calculateVariance(speeds)
	end

	return features
end

function MLDetectionEngine:_extractTimingFeatures(ctx)
	local track = ctx.track
	local features = {}

	-- Timing consistency
	local intervals = {}
	for i = 2, math.min(10, track.samples:count()) do
		local curr = track:sampleAt(i - 1)
		local prev = track:sampleAt(i)
		if curr and prev and curr.t and prev.t then
			intervals[#intervals + 1] = curr.t - prev.t
		end
	end

	if #intervals > 0 then
		features.avg_interval = self:_calculateMean(intervals)
		features.interval_variance = self:_calculateVariance(intervals)
	end

	return features
end

function MLDetectionEngine:_extractBehavioralFeatures(ctx)
	local features = {}

	-- Violation history
	local track = ctx.track
	features.violation_count = 0
	for kind, count in next, track.state.violationCounts or {} do
		features.violation_count = features.violation_count + count
	end

	-- Activity level
	features.airborne_ticks = track.state.airborneTicks or 0
	features.last_violation_time = track.lastViolationAt or 0

	return features
end

function MLDetectionEngine:_predict(features)
	-- Simplified prediction model (in reality would use trained ML model)
	local score = 0

	-- Simple rule-based scoring as placeholder
	if features.avg_speed and features.avg_speed > 30 then score = score + 0.3 end
	if features.speed_variance and features.speed_variance > 100 then score = score + 0.2 end
	if features.violation_count and features.violation_count > 5 then score = score + 0.4 end
	if features.interval_variance and features.interval_variance < 0.01 then score = score + 0.1 end

	return {
		probability = math_min(1.0, score),
		confidence = 0.7,
		classification = score > 0.5 and "cheat" or "legitimate",
	}
end

function MLDetectionEngine:_calculateVariance(values)
	if #values < 2 then return 0 end

	local mean = self:_calculateMean(values)
	local variance = 0
	for i = 1, #values do
		variance = variance + (values[i] - mean) ^ 2
	end
	return variance / #values
end

function MLDetectionEngine:_calculateMean(values)
	if #values == 0 then return 0 end

	local sum = 0
	for i = 1, #values do sum = sum + values[i] end
	return sum / #values
end

----------------------------------------------------------------------
-- Detection registry
----------------------------------------------------------------------

M.Server.Detections = {
	SpeedHackDetection          = SpeedHackDetection,
	TeleportDetection           = TeleportDetection,
	SuperJumpDetection          = SuperJumpDetection,
	FlyHackDetection            = FlyHackDetection,
	AccelerationDetection       = AccelerationDetection,
	SimulationDetection         = SimulationDetection,
	HeightViolationDetection    = HeightViolationDetection,
	PacketAnomalyDetection      = PacketAnomalyDetection,
	InvalidStateDetection       = InvalidStateDetection,
	WaterWalkDetection          = WaterWalkDetection,
	NoClipDetection             = NoClipDetection,
	SpinDetection               = SpinDetection,
	-- Advanced detection strategies
	PatternAnalysisDetection    = PatternAnalysisDetection,
	WallDetection               = WallDetection,
	PacketFloodDetection        = PacketFloodDetection,
	LatencyAnomalyDetection     = LatencyAnomalyDetection,
	BotDetection                = BotDetection,
	AFKDetection                = AFKDetection,
	RepetitiveActionDetection   = RepetitiveActionDetection,
	-- Statistical and ML detection strategies
	StatisticalAnomalyDetection = StatisticalAnomalyDetection,
	TrendAnalysis               = TrendAnalysis,
	MLDetectionEngine           = MLDetectionEngine,
}

----------------------------------------------------------------------
-- SECTION: SERVER - ACTION EXECUTOR
----------------------------------------------------------------------

--- Configuration options for action executor system
---@class anticheat.ActionExecutor.Options
---@field ac? AntiCheat AntiCheat instance to monitor
---@field eventBus? EventBus Event bus for communication
---@field on_warn? function Callback for warning actions
---@field on_kick? function Callback for kick actions
---@field on_ban? function Callback for ban actions
---@field warn_score? number Score threshold for warnings
---@field kick_score? number Score threshold for kicks
---@field ban_score? number Score threshold for bans
---@field cooldown_per_player? number Cooldown period per player between actions

--- Action executor that automatically responds to anti-cheat violations<br>
--- Evaluates player scores and triggers appropriate actions (warn/kick/ban)
---@class ActionExecutor
---@field ac? AntiCheat AntiCheat instance to monitor
---@field eventBus EventBus Event communication system
---@field actions table Action callbacks (warn, kick, ban)
---@field warn_score number Score threshold for warnings
---@field kick_score number Score threshold for kicks
---@field ban_score number Score threshold for bans
---@field cooldown number Cooldown period per player between actions
---@field _last_action table Track last action times per player
local ActionExecutor = class("ActionExecutor")

--- Initialize action executor with configuration
---@param self ActionExecutor
---@param opts? anticheat.ActionExecutor.Options Configuration options
function ActionExecutor:init(opts)
	opts              = opts or {}
	self.ac           = opts.ac -- AntiCheat instance
	self.eventBus     = Util.get_opt(opts, "eventBus", (self.ac and self.ac.eventBus))
	self.actions      = {
		warn = Util.get_opt(opts, "on_warn", function() end),
		kick = Util.get_opt(opts, "on_kick", function() end),
		ban  = Util.get_opt(opts, "on_ban", function() end),
	}
	self.warn_score   = Util.get_opt(opts, "warn_score", 10)
	self.kick_score   = Util.get_opt(opts, "kick_score", 20)
	self.ban_score    = Util.get_opt(opts, "ban_score", 60)
	self.cooldown     = Util.get_opt(opts, "cooldown_per_player", 5.0)
	self._last_action = {}
end

function ActionExecutor:evaluate(playerId)
	local tr = self.ac.tracks[playerId]
	if not tr then return "none" end
	local score = tr.score
	local t = Util.now()

	local last = self._last_action[playerId]
	if last and (t - last.time) < self.cooldown then return "cooldown" end

	local action = "none"
	if score >= self.ban_score then
		action = "ban"
	elseif score >= self.kick_score then
		action = "kick"
	elseif score >= self.warn_score then
		action = "warn"
	end

	if action ~= "none" then
		pcall(self.actions[action], playerId, score)
		self._last_action[playerId] = { action = action, time = t }
		self.eventBus:emit("action", {
			playerId = playerId, action = action, score = score,
		})
	end
	return action
end

function ActionExecutor:evaluateAll()
	local results = {}
	for pid in next, self.ac.tracks do
		results[pid] = self:evaluate(pid)
	end
	return results
end

M.Server.ActionExecutor = ActionExecutor

----------------------------------------------------------------------
-- SECTION: CLIENT - GUARD SYSTEM
----------------------------------------------------------------------

--- Event record for client-side guard violations and detections
---@class GuardEvent
---@field kind string Type of guard event (e.g. "codeexec.load_block")
---@field severity number Severity score (higher = more serious)
---@field details table Additional evidence and context data
---@field time number Timestamp when event occurred
local GuardEvent = class("GuardEvent")

--- Create a new guard event record
---@param self GuardEvent
---@param kind? string Event type (default: "event")
---@param severity? number Severity score (default: 0)
---@param details? table Event evidence and context
---@param t? number Timestamp (default: `os.clock()`)
function GuardEvent:init(kind, severity, details, t)
	self.kind     = kind or "event"
	self.severity = tonumber(severity) or 0
	self.details  = details or {}
	self.time     = t or Util.now()
end

----------------------------------------------------------------------
-- CodeExecGuard
----------------------------------------------------------------------

--- Code execution guard that monitors and blocks unauthorized code execution<br>
--- Hooks into load, loadstring, dofile, and require functions<br>
--- Enhanced with string_dump validation to detect debug.getinfo tampering
---@class CodeExecGuard
---@field enabled boolean Whether the guard is active
---@field allow_require boolean Whether require statements are allowed
---@field allowed_sources table Allowed source patterns for code execution
---@field on_event? function Event callback function
---@field _orig table Original function references
---@field _installed boolean Whether hooks are installed
---@field verify_debug_integrity boolean Whether to verify debug function integrity
---@field _baseline_debug table Baseline debug function fingerprints
---@field verify_registry_integrity boolean Whether to verify registry integrity
---@field _baseline_registry table Baseline registry fingerprints
local CodeExecGuard = class("CodeExecGuard")

--- Initialize code execution guard
---@param self CodeExecGuard
---@param opts? table Configuration options
function CodeExecGuard:init(opts)
	opts                           = opts or {}
	self.enabled                   = Util.get_opt(opts, "enabled", true)
	self.allow_require             = Util.get_opt(opts, "allow_require", true)
	self.allowed_sources           = Util.get_opt(opts, "allowed_sources", { "@" })
	self.on_event                  = opts.on_event
	self._orig                     = {}
	self._installed                = false
	self.verify_debug_integrity    = Util.get_opt(opts, "verify_debug_integrity", true)
	self._baseline_debug           = {}
	self.verify_registry_integrity = Util.get_opt(opts, "verify_registry_integrity", true)
	self._baseline_registry        = {}

	-- Capture baseline debug function fingerprints
	if self.verify_debug_integrity then
		self:_captureDebugBaseline()
	end

	-- Capture baseline registry fingerprints
	if self.verify_registry_integrity then
		self:_captureRegistryBaseline()
	end
end

function CodeExecGuard:_emit(kind, sev, details)
	if self.on_event then pcall(self.on_event, GuardEvent(kind, sev, details)) end
end

local debug_functions = {
	"getinfo", "gethook", "getlocal", "getregistry", "getupvalue",
	"sethook", "setlocal", "setupvalue", "traceback"
}

--- Capture baseline debug function fingerprints for integrity verification
function CodeExecGuard:_captureDebugBaseline()
	if not debug then return end

	for i = 1, #debug_functions do
		local fn_name = debug_functions[i]
		local fn = debug[fn_name]
		if type(fn) == "function" then
			local is_valid, details = Util.verify_function_integrity(fn, "native")
			self._baseline_debug[fn_name] = {
				is_valid = is_valid,
				details = details,
				timestamp = Util.now()
			}
		end
	end
end

--- Verify debug function integrity against baseline
---@return boolean integrity_ok True if all debug functions pass verification
---@return table verification_results Detailed verification results
function CodeExecGuard:_verifyDebugIntegrity()
	if not self.verify_debug_integrity then return true, {} end

	local results = {}
	local integrity_ok = true

	for fn_name, baseline in next, self._baseline_debug do
		local current_fn = debug and debug[fn_name]
		if type(current_fn) == "function" then
			local is_valid, details = Util.verify_function_integrity(current_fn, "native")
			results[fn_name] = {
				baseline = baseline,
				current = details,
				integrity_ok = is_valid
			}

			if not is_valid then
				integrity_ok = false
				-- Check for specific integrity violations
				if details.integrity_violation == "debug_info_mismatch" then
					self:_emit("codeexec.debug_tampering", 10, {
						function_name = fn_name,
						violation_type = "debug_info_mismatch",
						baseline_method = baseline.details.detection_method,
						current_method = details.detection_method,
						baseline_what = baseline.details.debug_info and baseline.details.debug_info.what,
						current_what = details.debug_info and details.debug_info.what
					})
				elseif not details.is_native then
					self:_emit("codeexec.debug_replacement", 10, {
						function_name = fn_name,
						violation_type = "native_replaced_with_lua",
						baseline_method = baseline.details.detection_method,
						current_method = details.detection_method
					})
				else
					self:_emit("codeexec.debug_modified", 8, {
						function_name = fn_name,
						violation_type = "native_function_modified",
						baseline_method = baseline.details.detection_method,
						current_method = details.detection_method
					})
				end
			end
		else
			integrity_ok = false
			results[fn_name] = {
				baseline = baseline,
				current = { fn_type = type(current_fn) },
				integrity_ok = false
			}
			self:_emit("codeexec.debug_missing", 10, {
				function_name = fn_name,
				violation_type = "debug_function_missing",
				current_type = type(current_fn)
			})
		end
	end

	return integrity_ok, results
end

--- Capture baseline registry fingerprints for integrity verification
function CodeExecGuard:_captureRegistryBaseline()
	if not debug or not debug.getregistry then return end

	self._baseline_registry = Util.capture_registry_baseline()
end

--- Verify registry integrity against baseline
---@return boolean integrity_ok True if registry matches baseline
---@return table verification_results Detailed verification results
function CodeExecGuard:_verifyRegistryIntegrity()
	if not self.verify_registry_integrity then return true, {} end

	if not self._baseline_registry or self._baseline_registry.error then
		return true, { skipped = true, reason = "no baseline" }
	end

	return Util.verify_registry_integrity(self._baseline_registry)
end

local function source_allowed(allowed, src)
	if type(src) ~= "string" then return false end
	allowed = allowed or {}
	for i = 1, #allowed do
		local entry = allowed[i]
		if type(entry) == "function" then
			if entry(src) then return true end
		else
			assert(type(entry) == "string")
			if string_find(src, entry, 1, true) then return true end
		end
	end
	return false
end

function CodeExecGuard:install()
	if not self.enabled or self._installed then return end

	-- Verify debug integrity before installing hooks
	if self.verify_debug_integrity then
		local integrity_ok, results = self:_verifyDebugIntegrity()
		if not integrity_ok then
			self:_emit("codeexec.install_blocked", 10, {
				reason = "debug_integrity_violation",
				verification_results = results
			})
			return false
		end
	end

	-- Verify registry integrity before installing hooks
	if self.verify_registry_integrity then
		local integrity_ok, results = self:_verifyRegistryIntegrity()
		if not integrity_ok then
			self:_emit("codeexec.install_blocked", 10, {
				reason = "registry_integrity_violation",
				verification_results = results
			})
			return false
		end
	end

	self._orig.load       = _G.load
	self._orig.loadstring = _G.loadstring
	self._orig.dofile     = _G.dofile
	self._orig.require    = _G.require

	local allowed         = self.allowed_sources
	local guard           = self

	if type(_G.load) == "function" then
		_G.load = function(chunk, chunkname, mode, env)
			-- Runtime debug integrity verification
			if guard.verify_debug_integrity then
				local integrity_ok, results = guard:_verifyDebugIntegrity()
				if not integrity_ok then
					guard:_emit("codeexec.runtime_tampering", 10, {
						function_name = "load",
						reason = "debug_integrity_violation",
						verification_results = results
					})
					return nil, "blocked by CodeExecGuard - debug integrity violation"
				end
			end

			-- Use both debug.getinfo and string_dump for caller verification
			local dbg = debug
			local src = "<no_source>"
			local debug_integrity_ok = true

			if dbg and dbg.getinfo then
				local ok, info = pcall(dbg.getinfo, 2, "S")
				if ok and info then
					src = info.source or "<no_source>"

					-- Verify debug.getinfo integrity using string_dump
					local is_native, method = Util.is_native_function(dbg.getinfo)
					if method ~= "string_dump" and method ~= "debug.getinfo" then
						-- Inconsistent detection methods detected
						debug_integrity_ok = false
						guard:_emit("codeexec.debug_inconsistency", 9, {
							function_name = "load",
							caller_source = src,
							detection_method = method,
							chunkname = chunkname
						})
					end
				else
					-- debug.getinfo failed unexpectedly
					debug_integrity_ok = false
					guard:_emit("codeexec.debug_failure", 8, {
						function_name = "load",
						error = info,
						chunkname = chunkname
					})
				end
			end

			if not debug_integrity_ok or not source_allowed(allowed, src) then
				guard:_emit("codeexec.load_block", 8,
					{ source = src, chunkname = chunkname, debug_integrity_ok = debug_integrity_ok })
				return nil, "blocked by CodeExecGuard"
			end
			return guard._orig.load(chunk, chunkname, mode, env)
		end
	end

	if type(_G.loadstring) == "function" then
		_G.loadstring = function(str, chunkname)
			local info = debug and debug.getinfo and debug.getinfo(2, "S")
			local src = info and info.source or "<no_source>"
			if not source_allowed(allowed, src) then
				guard:_emit("codeexec.loadstring_block", 10, {
					source = src,
					chunkname = chunkname,
					len = Util.when(type(str) == "string", #str),
				})
				return nil, "blocked by CodeExecGuard"
			end
			return guard._orig.loadstring(str, chunkname)
		end
	end

	if type(_G.dofile) == "function" then
		_G.dofile = function(filename)
			local info = debug and debug.getinfo and debug.getinfo(2, "S")
			local src = info and info.source or "<no_source>"
			if not source_allowed(allowed, src) then
				guard:_emit("codeexec.dofile_block", 9,
					{ source = src, filename = filename })
				return nil, "blocked by CodeExecGuard"
			end
			return guard._orig.dofile(filename)
		end
	end

	if type(_G.require) == "function" then
		_G.require = function(mod)
			if not guard.allowRequire then
				guard:_emit("codeexec.require_block", 9, { mod = mod })
				return nil
			end
			return guard._orig.require(mod)
		end
	end

	self._installed = true
end

function CodeExecGuard:uninstall()
	if not self._installed then return end
	if self._orig.load then _G.load = self._orig.load end
	if self._orig.loadstring then _G.loadstring = self._orig.loadstring end
	if self._orig.dofile then _G.dofile = self._orig.dofile end
	if self._orig.require then _G.require = self._orig.require end
	self._installed = false
end

----------------------------------------------------------------------
-- StackGuard
----------------------------------------------------------------------

--- Stack inspection guard that monitors call stack for suspicious sources<br>
--- Uses debug hooks to periodically scan the call stack for unauthorized code<br>
--- Enhanced with string_dump validation to detect debug.getinfo tampering
---@class StackGuard
---@field enabled boolean Whether the guard is active
---@field hook_mask string Debug hook mask for monitoring
---@field sample_every integer Sample interval for stack scanning
---@field max_scan_depth integer Maximum stack depth to scan
---@field allowed_source_substrings table Allowed source substrings in stack frames
---@field on_event? function Event callback function
---@field verify_debug_integrity boolean Whether to verify debug function integrity
---@field _counter integer Internal counter for sampling
---@field _installed boolean Whether hooks are installed
---@field _baseline_debug table Baseline debug function fingerprints
---@field verify_registry_integrity boolean Whether to verify registry integrity
---@field _baseline_registry table Baseline registry fingerprints
local StackGuard = class("StackGuard")

--- Initialize stack guard
---@param self StackGuard
---@param opts? table Configuration options
function StackGuard:init(opts)
	opts                           = opts or {}
	self.enabled                   = not not opts.enabled
	self.hook_mask                 = Util.get_opt(opts, "hook_mask", "cr")
	self.sample_every              = Util.get_opt(opts, "sample_every", 2000)
	self.max_scan_depth            = Util.get_opt(opts, "max_scan_depth", 20)
	self.allowed_source_substrings = Util.get_opt(opts, "allowed_source_substrings", { "@" })
	self.on_event                  = opts.on_event
	self.verify_debug_integrity    = Util.get_opt(opts, "verify_debug_integrity", true)
	self._counter                  = 0
	self._installed                = false
	self._baseline_debug           = {}
	self.verify_registry_integrity = Util.get_opt(opts, "verify_registry_integrity", true)
	self._baseline_registry        = {}

	-- Capture baseline debug function fingerprints
	if self.verify_debug_integrity then
		self:_captureDebugBaseline()
	end

	-- Capture baseline registry fingerprints
	if self.verify_registry_integrity then
		self:_captureRegistryBaseline()
	end
end

function StackGuard:_emit(kind, sev, details)
	if self.on_event then pcall(self.on_event, GuardEvent(kind, sev, details)) end
end

--- Capture baseline debug function fingerprints for integrity verification
function StackGuard:_captureDebugBaseline()
	if not debug then return end

	local debug_functions = {
		"getinfo", "gethook", "getlocal", "getregistry", "getupvalue",
		"sethook", "setlocal", "setupvalue", "traceback"
	}

	for i = 1, #debug_functions do
		local fn_name = debug_functions[i]
		local fn = debug[fn_name]
		if type(fn) == "function" then
			local is_valid, details = Util.verify_function_integrity(fn, "native")
			self._baseline_debug[fn_name] = {
				is_valid = is_valid,
				details = details,
				timestamp = Util.now()
			}
		end
	end
end

--- Verify debug function integrity against baseline
---@return boolean integrity_ok True if all debug functions pass verification
---@return table verification_results Detailed verification results
function StackGuard:_verifyDebugIntegrity()
	if not self.verify_debug_integrity then return true, {} end

	local results = {}
	local integrity_ok = true

	for fn_name, baseline in next, self._baseline_debug do
		local current_fn = debug and debug[fn_name]
		if type(current_fn) == "function" then
			local is_valid, details = Util.verify_function_integrity(current_fn, "native")
			results[fn_name] = {
				baseline = baseline,
				current = details,
				integrity_ok = is_valid
			}

			if not is_valid then
				integrity_ok = false
				-- Check for specific integrity violations
				if details.integrity_violation == "debug_info_mismatch" then
					self:_emit("stack.debug_tampering", 10, {
						function_name = fn_name,
						violation_type = "debug_info_mismatch",
						baseline_method = baseline.details.detection_method,
						current_method = details.detection_method,
						baseline_what = baseline.details.debug_info and baseline.details.debug_info.what,
						current_what = details.debug_info and details.debug_info.what
					})
				elseif not details.is_native then
					self:_emit("stack.debug_replacement", 10, {
						function_name = fn_name,
						violation_type = "native_replaced_with_lua",
						baseline_method = baseline.details.detection_method,
						current_method = details.detection_method
					})
				else
					self:_emit("stack.debug_modified", 8, {
						function_name = fn_name,
						violation_type = "native_function_modified",
						baseline_method = baseline.details.detection_method,
						current_method = details.detection_method
					})
				end
			end
		else
			integrity_ok = false
			results[fn_name] = {
				baseline = baseline,
				current = { fn_type = type(current_fn) },
				integrity_ok = false
			}
			self:_emit("stack.debug_missing", 10, {
				function_name = fn_name,
				violation_type = "debug_function_missing",
				current_type = type(current_fn)
			})
		end
	end

	return integrity_ok, results
end

--- Capture baseline registry fingerprints for integrity verification
function StackGuard:_captureRegistryBaseline()
	if not debug or not debug.getregistry then return end

	self._baseline_registry = Util.capture_registry_baseline()
end

--- Verify registry integrity against baseline
---@return boolean integrity_ok True if registry matches baseline
---@return table verification_results Detailed verification results
function StackGuard:_verifyRegistryIntegrity()
	if not self.verify_registry_integrity then return true, {} end

	if not self._baseline_registry or self._baseline_registry.error then
		return true, { skipped = true, reason = "no baseline" }
	end

	return Util.verify_registry_integrity(self._baseline_registry)
end

function StackGuard:_scanStack()
	local dbg = debug
	if not (dbg and dbg.getinfo) then
		self:_emit("stack.debug_unavailable", 9, {})
		return
	end

	-- Verify debug integrity before scanning stack
	if self.verify_debug_integrity then
		local integrity_ok, results = self:_verifyDebugIntegrity()
		if not integrity_ok then
			self:_emit("stack.scan_blocked", 10, {
				reason = "debug_integrity_violation",
				verification_results = results
			})
			return
		end
	end

	-- Verify registry integrity before scanning stack
	if self.verify_registry_integrity then
		local integrity_ok, results = self:_verifyRegistryIntegrity()
		if not integrity_ok then
			self:_emit("stack.scan_blocked", 10, {
				reason = "registry_integrity_violation",
				verification_results = results
			})
			return
		end
	end

	-- Verify debug.getinfo integrity using string_dump
	local is_native, method = Util.is_native_function(dbg.getinfo)
	if method ~= "string_dump" and method ~= "debug.getinfo" then
		self:_emit("stack.debug_inconsistency", 9, {
			function_name = "getinfo",
			detection_method = method,
			expected_methods = { "string_dump", "debug.getinfo" }
		})
		return
	end

	for level = 3, self.max_scan_depth do
		local ok, info = pcall(dbg.getinfo, level, "Sln")
		if not ok then
			-- debug.getinfo failed unexpectedly during stack scan
			self:_emit("stack.scan_error", 8, {
				level = level,
				error = info
			})
			break
		end

		if not info then break end

		local src = info.source or "<no_source>"

		-- Additional verification: cross-validate debug info with string_dump for Lua functions
		if info.what == "Lua" then
			-- Try to get the function at this level and verify it's actually a Lua function
			local ok2, func = pcall(dbg.getinfo, level, "f")
			if ok2 and func and func.func then
				local func_is_native, func_method = Util.is_native_function(func.func)
				if func_is_native then
					-- Inconsistency: debug says Lua but string_dump says native
					self:_emit("stack.frame_inconsistency", 9, {
						level = level,
						debug_what = info.what,
						dump_method = func_method,
						source = src,
						name = info.name
					})
				end
			end
		end

		if not source_allowed(self.allowed_source_substrings, src) then
			self:_emit("stack.suspicious_frame", 7, {
				level = level,
				source = src,
				name = info.name,
				linedefined = info.linedefined,
				what = info.what,
				debug_integrity_ok = true
			})
			break
		end
	end
end

function StackGuard:install()
	if not self.enabled or self._installed then return end
	local dbg = debug
	if not (dbg and dbg.sethook) then
		self:_emit("stack.no_debug", 3, {})
		return
	end
	self._counter   = 0
	self._installed = true
	local ref       = self
	dbg.sethook(function()
		ref._counter = ref._counter + 1
		if ref._counter % ref.sampleEvery == 0 then ref:_scanStack() end
	end, self.hookMask)
end

function StackGuard:uninstall()
	local dbg = debug
	if dbg and dbg.sethook then dbg.sethook() end
	self._installed = false
end

----------------------------------------------------------------------
-- IntegrityGuard
----------------------------------------------------------------------

--- Function integrity guard that monitors for function modifications<br>
--- Captures baseline function fingerprints and detects changes over time<br>
--- Enhanced with string_dump validation for robust integrity checking
---@class IntegrityGuard
---@field enabled boolean Whether the guard is active
---@field on_event? function Event callback function
---@field check_every number Check interval in seconds
---@field _last_check number Timestamp of last check
---@field baseline table Baseline function fingerprints
---@field _watched table User-defined function watches
---@field _builtins table Built-in function list for monitoring
---@field verify_debug_integrity boolean Whether to verify debug function integrity
---@field _baseline_debug table Baseline debug function fingerprints
---@field verify_registry_integrity boolean Whether to verify registry integrity
---@field _baseline_registry table Baseline registry fingerprints
local IntegrityGuard = class("IntegrityGuard")

--- Initialize integrity guard
---@param self IntegrityGuard
---@param opts? table Configuration options
function IntegrityGuard:init(opts)
	opts                           = opts or {}
	self.enabled                   = Util.get_opt(opts, "enabled", true)
	self.on_event                  = opts.on_event
	self.check_every               = Util.get_opt(opts, "check_every", 5)
	self.verify_debug_integrity    = Util.get_opt(opts, "verify_debug_integrity", true)
	self._last_check               = 0
	self.baseline                  = {}
	self._watched                  = {} -- { key, fn }  (user-defined watches)
	self._baseline_debug           = {}
	self.verify_registry_integrity = Util.get_opt(opts, "verify_registry_integrity", true)
	self._baseline_registry        = {}
	-- Built-in function list (shared between capture & tick)
	self._builtins                 = {
		{ "tostring",        function() return tostring end },
		{ "pcall",           function() return pcall end },
		{ "next",            function() return next end },
		{ "pairs",           function() return pairs end },
		{ "ipairs",          function() return ipairs end },
		{ "type",            function() return type end },
		{ "load",            function() return load end },
		{ "loadstring",      function() return loadstring end },
		{ "dofile",          function() return dofile end },
		{ "require",         function() return require end },
		{ "collectgarbage",  function() return collectgarbage end },
		{ "math.random",     function() return math and math.random end },
		{ "math.randomseed", function() return math and math.randomseed end },
		{ "string.dump",     function() return string and string_dump end },
		{ "string.format",   function() return string and string_format end },
		{ "debug.getinfo",   function() return debug and debug_getinfo end },
		{ "debug.sethook",   function() return debug and debug_sethook end },
	}

	-- Capture baseline debug function fingerprints
	if self.verify_debug_integrity then
		self:_captureDebugBaseline()
	end

	-- Capture baseline registry fingerprints
	if self.verify_registry_integrity then
		self:_captureRegistryBaseline()
	end
end

function IntegrityGuard:_emit(kind, sev, details)
	if self.on_event then pcall(self.on_event, GuardEvent(kind, sev, details)) end
end

--- Capture baseline debug function fingerprints for integrity verification
function IntegrityGuard:_captureDebugBaseline()
	if not debug then return end

	local debug_functions = {
		"getinfo", "gethook", "getlocal", "getregistry", "getupvalue",
		"sethook", "setlocal", "setupvalue", "traceback"
	}

	for i = 1, #debug_functions do
		local fn_name = debug_functions[i]
		local fn = debug[fn_name]
		if type(fn) == "function" then
			local is_valid, details = Util.verify_function_integrity(fn, "native")
			self._baseline_debug[fn_name] = {
				is_valid = is_valid,
				details = details,
				timestamp = Util.now()
			}
		end
	end
end

--- Verify debug function integrity against baseline
---@return boolean integrity_ok True if all debug functions pass verification
---@return table verification_results Detailed verification results
function IntegrityGuard:_verifyDebugIntegrity()
	if not self.verify_debug_integrity then return true, {} end

	local results = {}
	local integrity_ok = true

	for fn_name, baseline in next, self._baseline_debug do
		local current_fn = debug and debug[fn_name]
		if type(current_fn) == "function" then
			local is_valid, details = Util.verify_function_integrity(current_fn, "native")
			results[fn_name] = {
				baseline = baseline,
				current = details,
				integrity_ok = is_valid
			}

			if not is_valid then
				integrity_ok = false
				-- Check for specific integrity violations
				if details.integrity_violation == "debug_info_mismatch" then
					self:_emit("integrity.debug_tampering", 10, {
						function_name = fn_name,
						violation_type = "debug_info_mismatch",
						baseline_method = baseline.details.detection_method,
						current_method = details.detection_method,
						baseline_what = baseline.details.debug_info and baseline.details.debug_info.what,
						current_what = details.debug_info and details.debug_info.what
					})
				elseif not details.is_native then
					self:_emit("integrity.debug_replacement", 10, {
						function_name = fn_name,
						violation_type = "native_replaced_with_lua",
						baseline_method = baseline.details.detection_method,
						current_method = details.detection_method
					})
				else
					self:_emit("integrity.debug_modified", 8, {
						function_name = fn_name,
						violation_type = "native_function_modified",
						baseline_method = baseline.details.detection_method,
						current_method = details.detection_method
					})
				end
			end
		else
			integrity_ok = false
			results[fn_name] = {
				baseline = baseline,
				current = { fn_type = type(current_fn) },
				integrity_ok = false
			}
			self:_emit("integrity.debug_missing", 10, {
				function_name = fn_name,
				violation_type = "debug_function_missing",
				current_type = type(current_fn)
			})
		end
	end

	return integrity_ok, results
end

--- Capture baseline registry fingerprints for integrity verification
function IntegrityGuard:_captureRegistryBaseline()
	if not debug or not debug.getregistry then return end

	self._baseline_registry = Util.capture_registry_baseline()
end

--- Verify registry integrity against baseline
---@return boolean integrity_ok True if registry matches baseline
---@return table verification_results Detailed verification results
function IntegrityGuard:_verifyRegistryIntegrity()
	if not self.verify_registry_integrity then return true, {} end

	if not self._baseline_registry or self._baseline_registry.error then
		return true, { skipped = true, reason = "no baseline" }
	end

	return Util.verify_registry_integrity(self._baseline_registry)
end

--- Add a custom function to monitor. Call before captureBaseline().
function IntegrityGuard:watch(key, fn)
	if type(fn) == "function" then
		self._watched[#self._watched + 1] = { key = key, fn = fn }
	end
	return self
end

function IntegrityGuard:captureBaseline()
	if not self.enabled then return end

	-- Verify debug integrity before capturing baseline
	if self.verify_debug_integrity then
		local integrity_ok, results = self:_verifyDebugIntegrity()
		if not integrity_ok then
			self:_emit("integrity.baseline_blocked", 10, {
				reason = "debug_integrity_violation",
				verification_results = results
			})
			return
		end
	end

	self.baseline = {}
	for i = 1, #self._builtins do
		local entry = self._builtins[i]
		local fn = entry[2]()
		if type(fn) == "function" then
			-- Use enhanced fingerprinting with string_dump validation
			local is_valid, details = Util.verify_function_integrity(fn)
			self.baseline[entry[1]] = {
				fingerprint = Util.fingerprint_fn(fn),
				verification = details,
				timestamp = Util.now()
			}
		end
	end
	for i = 1, #self._watched do
		local entry = self._watched[i]
		local is_valid, details = Util.verify_function_integrity(entry.fn)
		self.baseline[entry.key] = {
			fingerprint = Util.fingerprint_fn(entry.fn),
			verification = details,
			timestamp = Util.now()
		}
	end
	self._last_check = Util.now()
end

function IntegrityGuard:tick()
	if not self.enabled then return end
	local t = Util.now()
	if (t - self._last_check) < self.check_every then return end
	self._last_check = t

	-- Verify debug integrity before checking function integrity
	if self.verify_debug_integrity then
		local integrity_ok, results = self:_verifyDebugIntegrity()
		if not integrity_ok then
			self:_emit("integrity.tick_blocked", 10, {
				reason = "debug_integrity_violation",
				verification_results = results
			})
			return
		end
	end

	-- Verify registry integrity before checking function integrity
	if self.verify_registry_integrity then
		local integrity_ok, results = self:_verifyRegistryIntegrity()
		if not integrity_ok then
			self:_emit("integrity.tick_blocked", 10, {
				reason = "registry_integrity_violation",
				verification_results = results
			})
			return
		end
	end

	for i = 1, #self._builtins do
		local entry = self._builtins[i]
		local fn = entry[2]()
		if type(fn) == "function" then
			local key = entry[1]
			local is_valid, details = Util.verify_function_integrity(fn)
			local fp = Util.fingerprint_fn(fn)

			if self.baseline[key] then
				local baseline_data = self.baseline[key]
				local baseline_fp = baseline_data.fingerprint

				-- Check fingerprint change
				if fp ~= baseline_fp then
					self:_emit("integrity.changed", 9, {
						key = key,
						baseline = baseline_fp,
						now = fp,
						baseline_verification = baseline_data.verification,
						current_verification = details
					})
				end

				-- Check for debug info vs string_dump inconsistencies
				if details.integrity_violation == "debug_info_mismatch" then
					self:_emit("integrity.debug_inconsistency", 8, {
						key = key,
						baseline_method = baseline_data.verification.detection_method,
						current_method = details.detection_method,
						baseline_what = baseline_data.verification.debug_info and
								baseline_data.verification.debug_info.what,
						current_what = details.debug_info and details.debug_info.what
					})
				end
			end
		end
	end

	for i = 1, #self._watched do
		local entry = self._watched[i]
		local is_valid, details = Util.verify_function_integrity(entry.fn)
		local fp = Util.fingerprint_fn(entry.fn)

		if self.baseline[entry.key] then
			local baseline_data = self.baseline[entry.key]
			local baseline_fp = baseline_data.fingerprint

			-- Check fingerprint change
			if fp ~= baseline_fp then
				self:_emit("integrity.changed", 9, {
					key = entry.key,
					baseline = baseline_fp,
					now = fp,
					baseline_verification = baseline_data.verification,
					current_verification = details
				})
			end

			-- Check for debug info vs string_dump inconsistencies
			if details.integrity_violation == "debug_info_mismatch" then
				self:_emit("integrity.debug_inconsistency", 8, {
					key = entry.key,
					baseline_method = baseline_data.verification.detection_method,
					current_method = details.detection_method,
					baseline_what = baseline_data.verification.debug_info and baseline_data.verification.debug_info.what,
					current_what = details.debug_info and details.debug_info.what
				})
			end
		end
	end
end

----------------------------------------------------------------------
-- GlobalTableGuard
----------------------------------------------------------------------

--- Global table guard that monitors for unauthorized global variable changes<br>
--- Captures baseline global state and detects new variables or type changes
---@class GlobalTableGuard
---@field enabled boolean Whether the guard is active
---@field on_event? function Event callback function
---@field check_every number Check interval in seconds
---@field _last_check number Timestamp of last check
---@field baseline table Baseline global variable types
local GlobalTableGuard = class("GlobalTableGuard")

--- Initialize global table guard
---@param self GlobalTableGuard
---@param opts? table Configuration options
function GlobalTableGuard:init(opts)
	opts             = opts or {}
	self.enabled     = Util.get_opt(opts, "enabled", true)
	self.on_event    = opts.on_event
	self.check_every = Util.get_opt(opts, "check_every", 10)
	self._last_check = 0
	self.baseline    = {}
end

function GlobalTableGuard:_emit(kind, sev, details)
	if self.on_event then pcall(self.on_event, GuardEvent(kind, sev, details)) end
end

function GlobalTableGuard:captureBaseline()
	if not self.enabled then return end
	self.baseline = {}
	for k, v in next, _G do self.baseline[k] = type(v) end
	self._last_check = Util.now()
end

function GlobalTableGuard:tick()
	if not self.enabled then return end
	local t = Util.now()
	if (t - self._last_check) < self.check_every then return end
	self._last_check = t

	for k, v in next, _G do
		if self.baseline[k] == nil then
			self:_emit("global.new_key", 5, { key = k, type = type(v) })
		elseif self.baseline[k] ~= type(v) then
			self:_emit("global.type_changed", 6, {
				key = k, oldType = self.baseline[k], newType = type(v),
			})
		end
	end
end

--- Configuration options for client guard system
---@class anticheat.Client.Options
---@field onEvent? function Event callback function
---@field eventBus? EventBus Event bus for communication
---@field codeEnabled? boolean Enable code execution guard
---@field allowRequire? boolean Allow require statements in code guard
---@field allowedSources? table Allowed source patterns for code guard
---@field stackEnabled? boolean Enable stack guard
---@field hookMask? string Debug hook mask for stack guard
---@field sampleEvery? integer Sample interval for stack guard
---@field maxScanDepth? integer Maximum scan depth for stack guard
---@field allowedSourceSubstrings? table Allowed source substrings for stack guard
---@field integrityEnabled? boolean Enable integrity guard
---@field integrityCheckEvery? number Check interval for integrity guard
---@field globalsEnabled? boolean Enable global table guard
---@field globalsCheckEvery? number Check interval for global table guard

----------------------------------------------------------------------
-- ClientGuard (facade)
----------------------------------------------------------------------

--- Client-side anti-cheat guard facade that coordinates all guard components
---@class ClientGuard
---@field events table Event history
---@field onEvent? function Event callback
---@field eventBus EventBus Event communication system
---@field code CodeExecGuard Code execution guard
---@field stack StackGuard Stack inspection guard
---@field integrity IntegrityGuard Function integrity guard
---@field globals GlobalTableGuard Global table guard
local ClientGuard = class("ClientGuard")

--- Initialize client guard with component configuration
---@param self ClientGuard
---@param opts? anticheat.Client.Options Configuration options
function ClientGuard:init(opts)
	opts          = opts or {}
	self.events   = {}
	self.on_event = opts.on_event
	self.eventBus = Util.get_opt(opts, "eventBus", EventBus())

	local function emit(evt)
		self.events[#self.events + 1] = evt
		if self.on_event then pcall(self.on_event, evt) end
		self.eventBus:emit("guard_event", evt)
	end

	self.code = CodeExecGuard({
		enabled        = opts.codeEnabled,
		allowRequire   = opts.allow_require,
		allowedSources = opts.allowed_sources,
		onEvent        = emit,
	})

	self.stack = StackGuard({
		enabled                 = opts.stackEnabled,
		hookMask                = opts.hookMask,
		sampleEvery             = opts.sample_every,
		maxScanDepth            = opts.max_scan_depth,
		allowedSourceSubstrings = opts.allowed_source_substrings,
		onEvent                 = emit,
	})

	self.integrity = IntegrityGuard({
		enabled    = opts.integrityEnabled,
		checkEvery = Util.get_opt(opts, "integrity_check_every", 5),
		onEvent    = emit,
	})

	self.globals = GlobalTableGuard({
		enabled    = Util.get_opt(opts, "globalsEnabled", true),
		checkEvery = Util.get_opt(opts, "globals_check_every", 10),
		onEvent    = emit,
	})
end

function ClientGuard:install()
	self.integrity:captureBaseline()
	self.globals:captureBaseline()
	self.code:install()
	self.stack:install()
end

function ClientGuard:tick()
	self.integrity:tick()
	self.globals:tick()
end

function ClientGuard:uninstall()
	self.stack:uninstall()
	self.code:uninstall()
end

function ClientGuard:getRecentEvents(count)
	count = count or 10
	local n = #self.events
	local out = {}
	for i = math_max(1, n - count + 1), n do
		out[#out + 1] = self.events[i]
	end
	return out
end

----------------------------------------------------------------------
-- MemoryGuard
----------------------------------------------------------------------

--- Memory guard that monitors for suspicious memory access patterns<br>
--- Detects memory manipulation and unauthorized memory access
---@class MemoryGuard
---@field enabled boolean Whether the guard is active
---@field on_event? function Event callback function
---@field check_every number Check interval in seconds
---@field _last_check number Timestamp of last check
---@field baseline table Baseline memory usage patterns
---@field suspicious_patterns table Known suspicious memory patterns
local MemoryGuard = class("MemoryGuard")

--- Initialize memory guard
---@param self MemoryGuard
---@param opts? table Configuration options
function MemoryGuard:init(opts)
	opts                     = opts or {}
	self.enabled             = Util.get_opt(opts, "enabled", true)
	self.on_event            = opts.on_event
	self.check_every         = Util.get_opt(opts, "check_every", 2)
	self._last_check         = 0
	self.baseline            = {}
	self.suspicious_patterns = {
		"memory_injection",
		"code_cave_detection",
		"unusual_growth",
		"suspicious_allocations",
	}
end

function MemoryGuard:_emit(kind, sev, details)
	if self.on_event then pcall(self.on_event, GuardEvent(kind, sev, details)) end
end

function MemoryGuard:captureBaseline()
	if not self.enabled then return end
	-- Capture baseline memory usage (simplified for Lua)
	self.baseline = {
		gc_count = collectgarbage("count"),
		memory_growth_rate = 0,
		allocation_frequency = 0,
	}
	self._last_check = Util.now()
end

function MemoryGuard:tick()
	if not self.enabled then return end
	local t = Util.now()
	if (t - self._last_check) < self.check_every then return end
	self._last_check = t

	local current = collectgarbage("count")
	local baseline = self.baseline

	-- Check for unusual memory growth
	if baseline.gc_count > 0 then
		local growthRate = (current - baseline.gc_count) / self.check_every
		if growthRate > 1000 then -- 1MB/s growth threshold
			self:_emit("memory.rapid_growth", 6, {
				growthRate = growthRate,
				current = current,
				baseline = baseline.gc_count,
			})
		end
	end

	-- Update baseline
	self.baseline.gc_count = current
end

----------------------------------------------------------------------
-- ProcessGuard
----------------------------------------------------------------------

--- Process guard that monitors for suspicious process activity<br>
--- Detects unauthorized process execution and manipulation
---@class ProcessGuard
---@field enabled boolean Whether the guard is active
---@field on_event? function Event callback function
---@field check_every number Check interval in seconds
---@field _last_check number Timestamp of last check
---@field allowed_processes table List of allowed process names/patterns
---@field suspicious_processes table Known suspicious process patterns
local ProcessGuard = class("ProcessGuard")

--- Initialize process guard
---@param self ProcessGuard
---@param opts? table Configuration options
function ProcessGuard:init(opts)
	opts                      = opts or {}
	self.enabled              = Util.get_opt(opts, "enabled", true)
	self.on_event             = opts.on_event
	self.check_every          = Util.get_opt(opts, "check_every", 5)
	self._last_check          = 0
	self.allowed_processes    = Util.get_opt(opts, "allowed_processes", {})
	self.suspicious_processes = {
		"cheatengine",
		"x64dbg",
		"ollydbg",
		"ida",
		"windbg",
		"processhacker",
		"cheat",
		"hack",
		"trainer",
	}
end

function ProcessGuard:_emit(kind, sev, details)
	if self.on_event then pcall(self.on_event, GuardEvent(kind, sev, details)) end
end

function ProcessGuard:tick()
	if not self.enabled then return end
	local t = Util.now()
	if (t - self._last_check) < self.check_every then return end
	self._last_check = t

	-- In a real implementation, this would interface with system APIs
	-- For Lua, we'll simulate process monitoring
	self:_checkSuspiciousProcesses()
end

function ProcessGuard:_checkSuspiciousProcesses()
	-- Simulated process check - in real implementation would use system APIs
	local runningProcesses = self:_getRunningProcesses()

	for i = 1, #runningProcesses do
		local process = runningProcesses[i]
		if self:_isSuspiciousProcess(process) then
			self:_emit("process.suspicious", 8, {
				process = process,
				detected_at = Util.now(),
			})
		end
	end
end

function ProcessGuard:_getRunningProcesses()
	-- Simulated process list - in real implementation would query system
	return {
		{ name = "game.exe",  pid = 1234 },
		{ name = "steam.exe", pid = 5678 },
	}
end

function ProcessGuard:_isSuspiciousProcess(process)
	local processName = string_lower(process.name)

	for i = 1, #self.suspicious_processes do
		local suspicious = self.suspicious_processes[i]
		if string_find(processName, suspicious, 1, true) then
			return true
		end
	end

	return false
end

----------------------------------------------------------------------
-- FileGuard
----------------------------------------------------------------------

--- File guard that monitors for suspicious file system activity<br>
--- Detects unauthorized file access and modification
---@class FileGuard
---@field enabled boolean Whether the guard is active
---@field on_event? function Event callback function
---@field check_every number Check interval in seconds
---@field _last_check number Timestamp of last check
---@field protected_paths table List of protected file paths
---@field suspicious_extensions table Suspicious file extensions
local FileGuard = class("FileGuard")

--- Initialize file guard
---@param self FileGuard
---@param opts? table Configuration options
function FileGuard:init(opts)
	opts                       = opts or {}
	self.enabled               = Util.get_opt(opts, "enabled", true)
	self.on_event              = opts.on_event
	self.check_every           = Util.get_opt(opts, "check_every", 3)
	self._last_check           = 0
	self.protected_paths       = Util.get_opt(opts, "protected_paths", {})
	self.suspicious_extensions = {
		".dll", ".exe", ".tmp", ".bat", ".cmd", ".scr", ".vbs",
		".js", ".jar", ".lua", ".ps1", ".py", ".so", ".dylib",
	}
end

function FileGuard:_emit(kind, sev, details)
	if self.on_event then pcall(self.on_event, GuardEvent(kind, sev, details)) end
end

function FileGuard:tick()
	if not self.enabled then return end
	local t = Util.now()
	if (t - self._last_check) < self.check_every then return end
	self._last_check = t

	-- Simulated file system monitoring
	self:_checkFileModifications()
end

function FileGuard:_checkFileModifications()
	-- In real implementation, would monitor file system changes
	-- For Lua, we'll simulate the check
	local suspiciousFiles = {
		{ path = "C:/cheats/hack.dll",       action = "created" },
		{ path = "game_folder/injector.exe", action = "modified" },
	}

	for i = 1, #suspiciousFiles do
		local file = suspiciousFiles[i]
		if self:_isSuspiciousFile(file.path) then
			self:_emit("file.suspicious", 7, {
				file = file.path,
				action = file.action,
				detected_at = Util.now(),
			})
		end
	end
end

function FileGuard:_isSuspiciousFile(filePath)
	local path = string_lower(filePath)

	-- Check suspicious extensions
	for i = 1, #self.suspicious_extensions do
		local ext = self.suspicious_extensions[i]
		if string_find(path, ext, - #ext) then
			return true
		end
	end

	-- Check protected paths
	for i = 1, #self.protected_paths do
		local protected = self.protected_paths[i]
		if string_find(path, string_lower(protected), 1, true) then
			return true
		end
	end

	return false
end

M.Client = {
	GuardEvent       = GuardEvent,
	CodeExecGuard    = CodeExecGuard,
	StackGuard       = StackGuard,
	IntegrityGuard   = IntegrityGuard,
	GlobalTableGuard = GlobalTableGuard,
	ClientGuard      = ClientGuard,
	-- Enhanced guards
	MemoryGuard      = MemoryGuard,
	ProcessGuard     = ProcessGuard,
	FileGuard        = FileGuard,
}

----------------------------------------------------------------------
-- SECTION: FACTORY FUNCTIONS
----------------------------------------------------------------------

local DEFAULT_STRATEGIES = {
	speed        = SpeedHackDetection,
	teleport     = TeleportDetection,
	superjump    = SuperJumpDetection,
	fly          = FlyHackDetection,
	acceleration = AccelerationDetection,
	simulation   = SimulationDetection,
	height       = HeightViolationDetection,
	packet       = PacketAnomalyDetection,
	state        = InvalidStateDetection,
	waterwalk    = WaterWalkDetection,
	noclip       = NoClipDetection,
	spin         = SpinDetection,
}

--- Configuration options for server anti-cheat system
---@class anticheat.Server.Options
---@field strategies? table List of strategy names to enable (default: most strategies)
---@field walkMargin? table Per-strategy options (e.g. opts.speed = { walkMargin = 1.5 })
---@field sprintMargin? table Per-strategy sprint options
---@field noDefaultStrategies? boolean If true, add no default strategies
---@field model? MovementModel Movement model instance (takes priority over modelOpts)
---@field model_opts? table Options passed to MovementModel() when no instance given
---@field event_bus? EventBus Event bus for communication
---@field decay_per_second? number Score decay rate per second
---@field kick_score? number Score threshold for kicking
---@field ban_score? number Score threshold for banning
---@field max_score? number Maximum possible score
---@field on_violation? function Legacy violation callback

--- Convenience factory: creates an AntiCheat with a configurable set of default strategies
---@param opts? anticheat.Server.Options Configuration options
---@return AntiCheat ac Configured anti-cheat instance
function M.newServerAntiCheat(opts)
	opts = opts or {}
	local ac = AntiCheat({
		model            = opts.model,
		model_opts       = opts.model_opts,
		event_bus        = opts.event_bus,
		decay_per_second = opts.decay_per_second,
		kick_score       = opts.kick_score,
		ban_score        = opts.ban_score,
		max_score        = opts.max_score,
		on_violation     = opts.on_violation,
	})

	if not opts.noDefaultStrategies then
		local names = Util.get_opt(opts, "strategies", {
			"speed", "teleport", "superjump", "fly",
			"acceleration", "height", "packet", "state",
		})
		for i = 1, #names do
			local name = names[i]
			local Cls = DEFAULT_STRATEGIES[name]
			if Cls then
				local strategyOpts = opts[name] or {}
				ac:addStrategy(Cls(strategyOpts))
			end
		end
	end

	return ac
end

--- Convenience factory: creates an ActionExecutor wired to an AntiCheat
---@param opts? anticheat.ActionExecutor.Options Configuration options
---@return ActionExecutor executor Configured action executor instance
function M.newActionExecutor(opts)
	return ActionExecutor(opts)
end

--- Convenience factory: creates a ClientGuard
---@param opts? anticheat.Client.Options Configuration options
---@return ClientGuard guard Configured client guard instance
function M.newClientGuard(opts)
	return ClientGuard(opts)
end

----------------------------------------------------------------------
-- EXAMPLE USAGE (pseudo-code, not executed)
----------------------------------------------------------------------
--
-- -- SERVER
-- local server = AC.newServerAntiCheat({
--   modelOpts = {
--     maxWalkSpeed = 18, maxSprintSpeed = 28,
--     worldFloorY = -100, worldCeilingY = 3000,
--     waterLevelY = 62,
--   },
--   onViolation = function(pid, v)
--     print("VIOLATION", pid, v.kind, v.severity)
--   end,
--   speed = { walkMargin = 1.3 },       -- per-strategy opts
--   strategies = { "speed","teleport","fly","acceleration","height","state" },
-- })
--
-- -- Add a noclip detector with your world's collision function
-- server:addStrategy(AC.Server.Detections.NoClipDetection({
--   checkCollision = function(x,y,z) return World.IsSolid(x,y,z) end,
-- }))
--
-- -- Wire up ActionExecutor
-- local executor = AC.newActionExecutor({
--   ac        = server,
--   on_warn   = function(pid) Server.SendChat(pid, "Suspicious activity detected") end,
--   on_kick   = function(pid) Server.Kick(pid, "Anti-cheat: kicked") end,
--   on_ban    = function(pid) Server.Ban(pid, "Anti-cheat: banned") end,
-- })
--
-- -- Per-tick:
-- server:updatePlayer(playerId, {
--   t = os.clock(), x = px, y = py, z = pz,
--   vx = pvx, vy = pvy, vz = pvz,
--   grounded = onGround,
--   meta = { sprinting = isSprinting, yaw = yaw, pitch = pitch },
-- })
-- executor:evaluate(playerId)
--
-- -- CLIENT
-- local guard = AC.newClientGuard({
--   onEvent = function(evt) print("GUARD", evt.kind, evt.severity) end,
--   allowedSources = { "@" },
-- })
-- guard:install()
-- -- call guard:tick() in your client update loop
--
-- -- Listen on event bus for decoupled processing
-- server.eventBus:on("violation", function(data)
--   LogViolation(data.playerId, data.violation)
-- end)

----------------------------------------------------------------------
-- SECTION: REPORTING AND ANALYTICS API
----------------------------------------------------------------------

----------------------------------------------------------------------
-- AnalyticsCollector
----------------------------------------------------------------------

--- Analytics collector for gathering and processing anticheat data<br>
--- Provides comprehensive analytics and reporting capabilities
---@class AnalyticsCollector
---@field eventBus EventBus Event bus for data collection
---@field data table Collected analytics data
---@field aggregation_window number Time window for data aggregation
---@field report_interval number Interval between automatic reports
---@field _last_report number Timestamp of last report
local AnalyticsCollector = class("AnalyticsCollector")

--- Initialize analytics collector
---@param self AnalyticsCollector
---@param opts? table Configuration options
function AnalyticsCollector:init(opts)
	opts                    = opts or {}
	self.eventBus           = Util.get_opt(opts, "eventBus", EventBus())
	self.data               = {
		violations = {},
		players = {},
		strategies = {},
		timeline = {},
		summary = {},
	}
	self.aggregation_window = Util.get_opt(opts, "aggregation_window", 3600) -- 1 hour
	self.report_interval    = Util.get_opt(opts, "report_interval", 300)    -- 5 minutes
	self._last_report       = 0

	-- Subscribe to events
	self:_setupEventListeners()
end

function AnalyticsCollector:_setupEventListeners()
	self.eventBus:on("violation", function(data)
		self:_recordViolation(data.playerId, data.violation)
	end)

	self.eventBus:on("action", function(data)
		self:_recordAction(data.playerId, data.action, data.score)
	end)

	self.eventBus:on("guard_event", function(data)
		self:_recordGuardEvent(data)
	end)
end

function AnalyticsCollector:_recordViolation(playerId, violation)
	local timestamp = violation.time or Util.now()

	-- Update violation data
	if not self.data.violations[playerId] then
		self.data.violations[playerId] = {}
	end

	table_insert(self.data.violations[playerId], {
		timestamp = timestamp,
		kind = violation.kind,
		severity = violation.severity,
		evidence = violation.evidence,
	})

	-- Update strategy stats
	if not self.data.strategies[violation.kind] then
		self.data.strategies[violation.kind] = {
			count = 0,
			total_severity = 0,
			players = {},
		}
	end

	local strategy = self.data.strategies[violation.kind]
	strategy.count = strategy.count + 1
	strategy.total_severity = strategy.total_severity + violation.severity
	strategy.players[playerId] = (strategy.players[playerId] or 0) + 1

	-- Update timeline
	table_insert(self.data.timeline, {
		timestamp = timestamp,
		type = "violation",
		playerId = playerId,
		kind = violation.kind,
		severity = violation.severity,
	})
end

function AnalyticsCollector:_recordAction(playerId, action, score)
	local timestamp = Util.now()

	-- Update player data
	if not self.data.players[playerId] then
		self.data.players[playerId] = {
			violations = 0,
			actions = {},
			first_seen = timestamp,
			last_seen = timestamp,
		}
	end

	local player = self.data.players[playerId]
	player.actions[action] = (player.actions[action] or 0) + 1
	player.last_seen = timestamp

	-- Update timeline
	table_insert(self.data.timeline, {
		timestamp = timestamp,
		type = "action",
		playerId = playerId,
		action = action,
		score = score,
	})
end

function AnalyticsCollector:_recordGuardEvent(event)
	local timestamp = event.time or Util.now()

	-- Update timeline with guard events
	table_insert(self.data.timeline, {
		timestamp = timestamp,
		type = "guard_event",
		kind = event.kind,
		severity = event.severity,
		details = event.details,
	})
end

--- Generate analytics report
---@param self AnalyticsCollector
---@param report_type string Type of report ("summary", "detailed", "players", "strategies")
---@param time_window? number Time window in seconds (nil = all data)
---@return table report Analytics report
function AnalyticsCollector:generateReport(report_type, time_window)
	local cutoff_time = time_window and (Util.now() - time_window)

	if report_type == "summary" then
		return self:_generateSummaryReport(cutoff_time)
	end
	if report_type == "detailed" then
		return self:_generateDetailedReport(cutoff_time)
	end
	if report_type == "players" then
		return self:_generatePlayersReport(cutoff_time)
	end
	if report_type == "strategies" then
		return self:_generateStrategiesReport(cutoff_time)
	end
	return self:_generateSummaryReport(cutoff_time)
end

function AnalyticsCollector:_generateSummaryReport(cutoff_time)
	local report = {
		timestamp = Util.now(),
		type = "summary",
		time_window = cutoff_time and (Util.now() - cutoff_time),
		metrics = {},
	}

	-- Count total violations
	local total_violations = 0
	local total_severity = 0
	local unique_players = 0

	for playerId, violations in next, self.data.violations do
		local player_violations = 0
		for _, violation in next, violations do
			if not cutoff_time or violation.timestamp >= cutoff_time then
				total_violations = total_violations + 1
				total_severity = total_severity + violation.severity
				player_violations = player_violations + 1
			end
		end
		if player_violations > 0 then
			unique_players = unique_players + 1
		end
	end

	-- Strategy breakdown
	local strategy_breakdown = {}
	for strategy, data in next, self.data.strategies do
		strategy_breakdown[strategy] = {
			count = data.count,
			avg_severity = data.total_severity / math_max(1, data.count),
			unique_players = self:_countKeys(data.players),
		}
	end

	report.metrics = {
		total_violations = total_violations,
		total_severity = total_severity,
		unique_players = unique_players,
		avg_severity = total_violations > 0 and (total_severity / total_violations) or 0,
		strategy_breakdown = strategy_breakdown,
	}

	return report
end

function AnalyticsCollector:_generateDetailedReport(cutoff_time)
	local report = {
		timestamp = Util.now(),
		type = "detailed",
		time_window = cutoff_time and (Util.now() - cutoff_time),
		violations = {},
		actions = {},
		guard_events = {},
	}

	-- Filter timeline data
	for i = 1, #self.data.timeline do
		local event = self.data.timeline[i]
		if not cutoff_time or event.timestamp >= cutoff_time then
			if event.type == "violation" then
				table_insert(report.violations, event)
			elseif event.type == "action" then
				table_insert(report.actions, event)
			elseif event.type == "guard_event" then
				table_insert(report.guard_events, event)
			end
		end
	end

	return report
end

function AnalyticsCollector:_generatePlayersReport(cutoff_time)
	local report = {
		timestamp = Util.now(),
		type = "players",
		time_window = cutoff_time and (Util.now() - cutoff_time),
		players = {},
	}

	for playerId, player_data in next, self.data.players do
		local violations = 0
		if self.data.violations[playerId] then
			for i = 1, #self.data.violations[playerId] do
				local violation = self.data.violations[playerId][i]
				if not cutoff_time or violation.timestamp >= cutoff_time then
					violations = violations + 1
				end
			end
		end

		if violations > 0 or (not cutoff_time) then
			report.players[playerId] = {
				violations = violations,
				actions = player_data.actions,
				first_seen = player_data.first_seen,
				last_seen = player_data.last_seen,
			}
		end
	end

	return report
end

function AnalyticsCollector:_generateStrategiesReport(cutoff_time)
	local report = {
		timestamp = Util.now(),
		type = "strategies",
		time_window = cutoff_time and (Util.now() - cutoff_time),
		strategies = {},
	}

	for strategy_name, strategy_data in next, self.data.strategies do
		local count = 0
		local total_severity = 0
		local players = {}

		for playerId, player_count in next, strategy_data.players do
			-- Check if player has violations in time window
			if self.data.violations[playerId] then
				for i = 1, #self.data.violations[playerId] do
					local violation = self.data.violations[playerId][i]
					if violation.kind == strategy_name and (not cutoff_time or violation.timestamp >= cutoff_time) then
						count = count + 1
						total_severity = total_severity + violation.severity
						players[playerId] = true
					end
				end
			end
		end

		if count > 0 or (not cutoff_time) then
			report.strategies[strategy_name] = {
				count = count,
				total_severity = total_severity,
				avg_severity = count > 0 and (total_severity / count) or 0,
				unique_players = self:_countKeys(players),
			}
		end
	end

	return report
end

function AnalyticsCollector:_countKeys(tbl)
	local count = 0
	for _ in next, tbl do count = count + 1 end
	return count
end

----------------------------------------------------------------------
-- ReportGenerator
----------------------------------------------------------------------

--- Report generator for creating formatted anticheat reports<br>
--- Supports multiple output formats and customization
---@class ReportGenerator
---@field collector AnalyticsCollector Analytics data source
---@field templates table Report templates for different formats
local ReportGenerator = class("ReportGenerator")

--- Initialize report generator
---@param self ReportGenerator
---@param collector AnalyticsCollector Analytics data collector
function ReportGenerator:init(collector)
	self.collector = collector
	self.templates = {
		html = self:_getHTMLTemplate(),
		json = self:_getJSONTemplate(),
		csv = self:_getCSVTemplate(),
	}
end

--- Generate report in specified format
---@param self ReportGenerator
---@param format string Output format ("html", "json", "csv")
---@param report_type string Type of report ("summary", "detailed", "players", "strategies")
---@param time_window? number Time window in seconds
---@return string formatted_report Formatted report
function ReportGenerator:generate(format, report_type, time_window)
	local template = self.templates[format]
	if not template then
		return error("Unsupported format: " .. tostring(format))
	end

	local data = self.collector:generateReport(report_type, time_window)
	return self:_applyTemplate(template, data, format)
end

function ReportGenerator:_applyTemplate(template, data, format)
	if format == "json" then
		return self:_toJSON(data)
	elseif format == "csv" then
		return self:_toCSV(data)
	elseif format == "html" then
		return self:_toHTML(data)
	else
		return self:_toJSON(data)
	end
end

function ReportGenerator:_toJSON(data)
	local json = {}
	local function serialize(obj)
		if type(obj) == "table" then
			local result = {}
			for k, v in next, obj do
				result[k] = serialize(v)
			end
			return result
		end
		if type(obj) == "string" then
			return string_format("%q", obj)
		end
		return tostring(obj)
	end
	return serialize(data)
end

function ReportGenerator:_toCSV(data)
	-- Simple CSV generation for summary reports
	if data.type == "summary" then
		local csv = "Metric,Value\n"
		for k, v in next, data.metrics do
			if type(v) ~= "table" then
				csv = csv .. k .. "," .. tostring(v) .. "\n"
			end
		end
		return csv
	end
	return "CSV format not supported for this report type"
end

function ReportGenerator:_toHTML(data)
	local html = [[
<!DOCTYPE html>
<html>
<head>
    <title>Anti-Cheat Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background: #f0f0f0; padding: 10px; border-radius: 5px; }
        .metric { margin: 10px 0; }
        .strategy { margin: 5px 0; padding: 5px; background: #f9f9f9; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Anti-Cheat Report</h1>
        <p>Generated: ]] .. os_date("%Y-%m-%d %H:%M:%S") .. [[</p>
        <p>Report Type: ]] .. (data.type or "unknown") .. [[</p>
    </div>
]]

	if data.type == "summary" and data.metrics then
		html = html .. "<h2>Summary Metrics</h2>"
		for k, v in next, data.metrics do
			if type(v) ~= "table" then
				html = html .. '<div class="metric"><strong>' .. k .. ':</strong> ' .. tostring(v) .. '</div>'
			end
		end

		if data.metrics.strategy_breakdown then
			html = html .. "<h2>Strategy Breakdown</h2>"
			for strategy, stats in next, data.metrics.strategy_breakdown do
				html = html .. '<div class="strategy">'
				html = html .. '<strong>' .. strategy .. ':</strong> '
				html = html .. 'Count: ' .. stats.count .. ', '
				html = html .. 'Avg Severity: ' .. string_format("%.2f", stats.avg_severity) .. ', '
				html = html .. 'Unique Players: ' .. stats.unique_players
				html = html .. '</div>'
			end
		end
	end

	return html .. "</body></html>"
end

function ReportGenerator:_getHTMLTemplate()
	return [[<!DOCTYPE html><html><head><title>Anti-Cheat Report</title></head><body>{{content}}</body></html>]]
end

function ReportGenerator:_getJSONTemplate()
	return '{"timestamp": "{{timestamp}}", "content": {{content}}}'
end

function ReportGenerator:_getCSVTemplate()
	return 'Metric,Value\n{{content}}'
end

----------------------------------------------------------------------
-- Configuration Management
----------------------------------------------------------------------

----------------------------------------------------------------------
-- DynamicConfig
----------------------------------------------------------------------

--- Dynamic configuration manager for runtime anticheat configuration<br>
--- Allows hot-reloading of configuration without restart
---@class DynamicConfig
---@field config table Current configuration
---@field config_file string Path to configuration file
---@field watchers table Configuration change watchers
---@field _last_modified number Last modification time of config file
local DynamicConfig = class("DynamicConfig")

--- Initialize dynamic configuration
---@param self DynamicConfig
---@param config_file string Path to configuration file
---@param default_config table Default configuration
function DynamicConfig:init(config_file, default_config)
	self.config_file = config_file
	self.config = default_config or {}
	self.watchers = {}
	self._last_modified = 0

	-- Load initial configuration
	self:load()
end

--- Load configuration from file
---@param self DynamicConfig
---@return boolean success True if configuration loaded successfully
function DynamicConfig:load()
	local file = io.open(self.config_file, "r")
	if not file then return false end

	local content = file:read("*all")
	file:close()

	local ok, loaded_config = pcall(function()
		local func = _loadstring("return " .. content)
		if not func then return nil end
		return func()
	end)

	if ok and type(loaded_config) == "table" then
		self.config = loaded_config
		self:_notifyWatchers()
		return true
	end

	return false
end

--- Save configuration to file
---@param self DynamicConfig
---@return boolean success True if configuration saved successfully
function DynamicConfig:save()
	local file = io.open(self.config_file, "w")
	if not file then return false end

	local content = self:_serializeTable(self.config)
	file:write(content)
	file:close()

	return true
end

--- Get configuration value
---@param self DynamicConfig
---@param key string Configuration key (supports dot notation)
---@param default any Default value if key not found
---@return any value Configuration value
function DynamicConfig:get(key, default)
	local keys = {}
	for k in string_gmatch(key, "[^%.]+") do
		keys[#keys + 1] = k
	end

	local value = self.config
	for i = 1, #keys do
		local k = keys[i]
		if type(value) == "table" and value[k] ~= nil then
			value = value[k]
		else
			return default
		end
	end

	return value
end

--- Set configuration value
---@param self DynamicConfig
---@param key string Configuration key (supports dot notation)
---@param value any New value
function DynamicConfig:set(key, value)
	local keys = {}
	for k in string_gmatch(key, "[^%.]+") do
		keys[#keys + 1] = k
	end

	local current = self.config
	for i = 1, #keys - 1 do
		local k = keys[i]
		if type(current[k]) ~= "table" then
			current[k] = {}
		end
		current = current[k]
	end

	current[keys[#keys]] = value
	self:_notifyWatchers()
end

--- Add configuration change watcher
---@param self DynamicConfig
---@param key string Configuration key to watch
---@param callback function Callback function called when value changes
function DynamicConfig:watch(key, callback)
	if not self.watchers[key] then
		self.watchers[key] = {}
	end
	table_insert(self.watchers[key], callback)
end

function DynamicConfig:_notifyWatchers()
	for key, callbacks in next, self.watchers do
		local value = self:get(key)
		for i = 1, #callbacks do
			local callback = callbacks[i]
			pcall(callback, key, value)
		end
	end
end

function DynamicConfig:_serializeTable(tbl, indent)
	indent = indent or ""
	local result = "{\n"

	for k, v in next, tbl do
		local key = type(k) == "string" and '"' .. k .. '"' or tostring(k)
		local value

		if type(v) == "table" then
			value = self:_serializeTable(v, indent .. "  ")
		elseif type(v) == "string" then
			value = string_format("%q", v)
		else
			value = tostring(v)
		end

		result = result .. indent .. "  " .. key .. " = " .. value .. ",\n"
	end

	return result .. indent .. "}"
end

----------------------------------------------------------------------
-- RuleManager
----------------------------------------------------------------------

--- Rule manager for dynamic rule management<br>
--- Provides runtime rule creation, modification, and removal
---@class RuleManager
---@field rules table Current active rules
---@field rule_history table History of rule changes
---@field config DynamicConfig Configuration manager
local RuleManager = class("RuleManager")

--- Initialize rule manager
---@param self RuleManager
---@param config DynamicConfig Configuration manager
function RuleManager:init(config)
	self.config = config
	self.rules = {}
	self.rule_history = {}

	-- Load existing rules
	self:loadRules()
end

--- Add a new rule
---@param self RuleManager
---@param rule_name string Name of the rule
---@param rule_data table Rule configuration
---@return boolean success True if rule added successfully
function RuleManager:addRule(rule_name, rule_data)
	if self.rules[rule_name] then
		return false -- Rule already exists
	end

	self.rules[rule_name] = {
		data = rule_data,
		created_at = Util.now(),
		enabled = true,
	}

	self:_recordRuleChange("add", rule_name, rule_data)
	self:_saveRules()
	return true
end

--- Update existing rule
---@param self RuleManager
---@param rule_name string Name of the rule
---@param rule_data table New rule configuration
---@return boolean success True if rule updated successfully
function RuleManager:updateRule(rule_name, rule_data)
	if not self.rules[rule_name] then
		return false -- Rule doesn't exist
	end

	local old_data = self.rules[rule_name].data
	self.rules[rule_name].data = rule_data
	self.rules[rule_name].updated_at = Util.now()

	self:_recordRuleChange("update", rule_name, { old = old_data, new = rule_data })
	self:_saveRules()
	return true
end

--- Remove a rule
---@param self RuleManager
---@param rule_name string Name of the rule to remove
---@return boolean success True if rule removed successfully
function RuleManager:removeRule(rule_name)
	if not self.rules[rule_name] then
		return false -- Rule doesn't exist
	end

	local removed_data = self.rules[rule_name]
	self.rules[rule_name] = nil

	self:_recordRuleChange("remove", rule_name, removed_data)
	self:_saveRules()
	return true
end

--- Enable/disable a rule
---@param self RuleManager
---@param rule_name string Name of the rule
---@param enabled boolean Whether rule should be enabled
---@return boolean success True if rule state changed successfully
function RuleManager:setRuleEnabled(rule_name, enabled)
	if not self.rules[rule_name] then
		return false -- Rule doesn't exist
	end

	self.rules[rule_name].enabled = enabled
	self:_recordRuleChange("enable", rule_name, { enabled = enabled })
	self:_saveRules()
	return true
end

--- Get all rules
---@param self RuleManager
---@param enabled_only? boolean Whether to return only enabled rules
---@return table rules List of rules
function RuleManager:getRules(enabled_only)
	local result = {}

	for name, rule in next, self.rules do
		if not enabled_only or rule.enabled then
			result[name] = rule
		end
	end

	return result
end

function RuleManager:loadRules()
	local rules = self.config:get("rules", {})
	for name, data in next, rules do
		self.rules[name] = data
	end
end

function RuleManager:_saveRules()
	self.config:set("rules", self.rules)
end

function RuleManager:_recordRuleChange(action, rule_name, data)
	table_insert(self.rule_history, {
		timestamp = Util.now(),
		action = action,
		rule_name = rule_name,
		data = data,
	})

	-- Keep only last 1000 changes
	if #self.rule_history > 1000 then
		table_remove(self.rule_history, 1)
	end
end

-- Export new components
M.Server.AnalyticsCollector = AnalyticsCollector
M.Server.ReportGenerator = ReportGenerator
M.Server.DynamicConfig = DynamicConfig
M.Server.RuleManager = RuleManager

-- Deprecated aliases (naming standard: snake_case). Kept for compatibility.
PlayerTrack.add_sample = PlayerTrack.addSample
PlayerTrack.sample_at = PlayerTrack.sampleAt
PlayerTrack.get_snapshot_at_tick = PlayerTrack.getSnapshotAtTick
PlayerTrack.get_snapshot_at_time = PlayerTrack.getSnapshotAtTime
PlayerTrack.get_snapshot_range = PlayerTrack.getSnapshotRange
PlayerTrack.record_violation = PlayerTrack.recordViolation
AntiCheat.get_track = AntiCheat.getTrack
AntiCheat.add_strategy = AntiCheat.addStrategy
AntiCheat.remove_strategy = AntiCheat.removeStrategy
AntiCheat.remove_player = AntiCheat.removePlayer
AntiCheat.update_player = AntiCheat.updatePlayer
AntiCheat.recommend_action = AntiCheat.recommendAction
AntiCheat.get_player_score = AntiCheat.getPlayerScore
AntiCheat.get_violation_counts = AntiCheat.getViolationCounts
Orchestrator.set_config = Orchestrator.setConfig
Orchestrator.get_player_evidence = Orchestrator.getPlayerEvidence
Detector.on_config = Detector.onConfig
BaselinesConfig.get_weapon_baseline = BaselinesConfig.getWeaponBaseline
BaselinesConfig.get_movement_baseline = BaselinesConfig.getMovementBaseline
BaselinesConfig.get_combined_baseline = BaselinesConfig.getCombinedBaseline
ConfigManager.validate_config = ConfigManager.validateConfig
ConfigManager.compute_diff = ConfigManager.computeDiff
ConfigManager.store_config = ConfigManager.storeConfig
ConfigManager.apply_config = ConfigManager.applyConfig
ConfigManager.get_config = ConfigManager.getConfig
ConfigManager.get_history = ConfigManager.getHistory
AnalyticsCollector.add_evidence_sample = AnalyticsCollector.addEvidenceSample
AnalyticsCollector.generate_report = AnalyticsCollector.generateReport
AnalyticsCollector.set_shadow_mode = AnalyticsCollector.setShadowMode
AnalyticsCollector.get_player_samples = AnalyticsCollector.getPlayerSamples
integrityChecks.debug_hooks = integrityChecks.debugHooks
integrityChecks.global_pollution = integrityChecks.globalPollution
integrityChecks.function_integrity = integrityChecks.functionIntegrity
integrityChecks.memory_integrity = integrityChecks.memoryIntegrity
ClientGuardHardening.register_integrity_check = ClientGuardHardening.registerIntegrityCheck
ClientGuardHardening.run_integrity_checks = ClientGuardHardening.runIntegrityChecks
ClientGuardHardening.update_monotonic_counter = ClientGuardHardening.updateMonotonicCounter
ClientGuardHardening.process_heartbeat = ClientGuardHardening.processHeartbeat
ClientGuardHardening.generate_challenge = ClientGuardHardening.generateChallenge
ClientGuardHardening.validate_challenge_response = ClientGuardHardening.validateChallengeResponse
ClientGuardHardening.check_tampering_patterns = ClientGuardHardening.checkTamperingPatterns
ClientGuardHardening.reset_player = ClientGuardHardening.resetPlayer
ClientGuardHardening.get_stats = ClientGuardHardening.getStats
EnhancedRingBuffer.get_range = EnhancedRingBuffer.getRange
EnhancedRingBuffer.get_time_range = EnhancedRingBuffer.getTimeRange
EnhancedRingBuffer.find_all = EnhancedRingBuffer.findAll
DeterministicSnapshot.to_legacy = DeterministicSnapshot.toLegacy
DeterministicSnapshot.distance_to = DeterministicSnapshot.distanceTo
DeterministicSnapshot.get_speed = DeterministicSnapshot.getSpeed
DeterministicSnapshot.is_valid = DeterministicSnapshot.isValid
DeterministicSnapshot.get_summary = DeterministicSnapshot.getSummary
DeterministicSnapshot.from_legacy = DeterministicSnapshot.fromLegacy
InvalidStateDetection.add_rule = InvalidStateDetection.addRule
ActionExecutor.evaluate_all = ActionExecutor.evaluateAll
IntegrityGuard.capture_baseline = IntegrityGuard.captureBaseline
ClientGuard.get_recent_events = ClientGuard.getRecentEvents
M.new_server_anti_cheat = M.newServerAntiCheat
M.new_action_executor = M.newActionExecutor
M.new_client_guard = M.newClientGuard
RuleManager.update_rule = RuleManager.updateRule
RuleManager.remove_rule = RuleManager.removeRule
RuleManager.set_rule_enabled = RuleManager.setRuleEnabled
RuleManager.get_rules = RuleManager.getRules
RuleManager.load_rules = RuleManager.loadRules

-- Export
return M
