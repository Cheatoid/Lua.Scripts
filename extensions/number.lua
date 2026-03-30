-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Various number-type extensions:
-- - time units and milliseconds
-- - data size and angle conversions (with plural handling)
-- - property helpers (n.from_now, n.ago, n.hms, n:human())
-- - Duration object with arithmetic and formatting (compact and human)
-- - ISO 8601 parsing/formatting
-- - Natural-language parsing (e.g., "in 3 days 4h, 1min, 2s") - commas are optional
-- - Time ago formatting (format_time_ago)
-- - boolean checks (is_even, is_odd, is_positive, is_negative)
-- - utility methods (round, clamp, percent_of, between, times)
-- - formatting helpers (.hex, .HEX, .bin)

------------------------------------------------------------
-- Localized global functions for better performance
------------------------------------------------------------
local setmetatable = setmetatable
local tonumber = tonumber
local tostring = tostring
local type = type
local debug_getmetatable = debug.getmetatable
local debug_setmetatable = debug.setmetatable
local math_floor = math.floor
local math_huge = math.huge
local math_max = math.max
local math_min = math.min
local math_modf = math.modf
local os_time = os.time
local os_date = os.date
local string_find = string.find
local string_format = string.format
local string_gmatch = string.gmatch
local string_gsub = string.gsub
local string_lower = string.lower
local string_match = string.match
local string_sub = string.sub

------------------------------------------------------------
-- Conversion factors (time, data, angles, etc.)
-- These are property-style and return immediately (e.g., 5.kb -> 5120)
------------------------------------------------------------
local CONVERSIONS = {
	-- Time (seconds)
	second = 1,
	seconds = 1,
	sec = 1,
	s = 1,
	minute = 60,
	minutes = 60,
	min = 60,
	m = 60,
	hour = 3600,
	hours = 3600,
	h = 3600,
	day = 86400,
	days = 86400,
	d = 86400,
	week = 604800,
	weeks = 604800,
	w = 604800,
	-- Milliseconds (fractional seconds)
	millisecond = 1 / 1000,
	milliseconds = 1 / 1000,
	ms = 1 / 1000,

	-- Data (bytes)
	byte = 1,
	bytes = 1,
	kb = 1024,
	mb = 1048576,
	gb = 1073741824,
	tb = 1099511627776,

	-- Angles
	deg = math.pi / 180,
	rad = 180 / math.pi,
}

-- Ensure simple plural handling for any keys not explicitly pluralized
do
	local additions = {}
	for k, v in next, CONVERSIONS do
		if not string_find(k, "s$", 1, true) then
			additions[k .. "s"] = v
		end
	end
	for k, v in next, additions do CONVERSIONS[k] = v end
end

-- Time UNITS alias (used for proxy durations)
local UNITS = {
	second = CONVERSIONS.second,
	seconds = CONVERSIONS.seconds,
	sec = CONVERSIONS.sec,
	s = CONVERSIONS.s,
	minute = CONVERSIONS.minute,
	minutes = CONVERSIONS.minutes,
	min = CONVERSIONS.min,
	m = CONVERSIONS.m,
	hour = CONVERSIONS.hour,
	hours = CONVERSIONS.hours,
	h = CONVERSIONS.h,
	day = CONVERSIONS.day,
	days = CONVERSIONS.days,
	d = CONVERSIONS.d,
	week = CONVERSIONS.week,
	weeks = CONVERSIONS.weeks,
	w = CONVERSIONS.w,
	ms = CONVERSIONS.ms,
	millisecond = CONVERSIONS.millisecond,
	milliseconds = CONVERSIONS.milliseconds,
}

------------------------------------------------------------
-- Boolean checks (properties executed immediately)
------------------------------------------------------------
-- @formatting:off
local CHECKS = {
	is_even     = function(n) return n % 2 == 0 end,
	is_odd      = function(n) return n % 2 ~= 0 end,
	is_positive = function(n) return n > 0 end,
	is_negative = function(n) return n < 0 end,
	is_nan      = function(n) return n ~= n end,
	is_inf      = function(n) return n == math_huge or n == -math_huge end,
	is_integer  = function(n) return (math_modf(n)) == n end
}
-- @formatting:on

------------------------------------------------------------
-- Methods (require arguments) - expect 'n' as first arg
------------------------------------------------------------
local METHODS = {
	--- Round to N decimal places
	--- @param n number
	--- @param decimals number|nil
	--- @return number
	round = function(n, decimals)
		local mult = 10 ^ (decimals or 0)
		return math_floor(n * mult + 0.5) / mult
	end,

	--- Clamp between min and max
	--- @param n number
	--- @param min number
	--- @param max number
	--- @return number
	clamp = function(n, min, max)
		return math_min(math_max(n, min), max)
	end,

	--- Percentage calculation: n percent of total
	--- @param n number
	--- @param total number
	--- @return number
	percent_of = function(n, total)
		return (n / 100) * total
	end,

	--- Range check (inclusive)
	--- @param n number
	--- @param min number
	--- @param max number
	--- @return boolean
	between = function(n, min, max)
		return min <= n and n <= max
	end,

	--- Iterator generator: for i in n:times() do ... end
	--- @param n number
	--- @return function
	--- @return nil
	--- @return number
	times = function(n)
		return function(_, i)
			if i < n then return i + 1 end
		end, nil, 0
	end,
}

------------------------------------------------------------
-- Time ago formatting functions
------------------------------------------------------------

--- Return a pluralized time unit.
--- @param n number|integer The numeric value.
--- @param singular string The singular form ("second", "minute", etc.)
--- @return string string A properly pluralized string (e.g., "1 minute", "3 minutes")
local function timeago_unit(n, singular)
	if n == 1 then
		return "1 " .. singular
	end
	return n .. " " .. singular .. "s"
end

--- Build a natural-language phrase from time components. (English only)
--- @param days number|integer Number of days (0 or positive).
--- @param hours number|integer Number of hours (0 or positive).
--- @param minutes number|integer Number of minutes (0 or positive).
--- @param seconds number|integer Number of seconds (0 or positive).
--- @return string string A phrase like "1 hour and 3 minutes" or "2 days, 5 hours and 10 minutes".
local function timeago_build_phrase(days, hours, minutes, seconds)
	local t = {}

	-- English only
	if days > 0 then
		t[#t + 1] = timeago_unit(days, "day")
	end
	if hours > 0 then
		t[#t + 1] = timeago_unit(hours, "hour")
	end
	if minutes > 0 then
		t[#t + 1] = timeago_unit(minutes, "minute")
	end
	if seconds > 0 or #t == 0 then
		t[#t + 1] = timeago_unit(seconds, "second")
	end

	local count = #t
	if count == 1 then
		return t[1]
	end

	local phrase = ""
	for i = 1, count do
		if i == 1 then
			phrase = t[i]
		elseif i == count then
			phrase = phrase .. " and " .. t[i]
		else
			phrase = phrase .. ", " .. t[i]
		end
	end

	return phrase
end

--- Format a timestamp into a "time ago" string.
--- @param past_timestamp number|integer A UNIX timestamp in seconds.
--- @param show_exact boolean Whether to append the exact timestamp in parentheses.
--- @param date_func function A function with the same signature as `os.date`. If omitted, `os.date` is used.
--- @param time_func function A function returning the current UNIX timestamp. If omitted, `os.time` is used.
--- @return string string A human-readable string such as: "a minute and 19 seconds ago (7:10:55 AM 1/1/2020)" or simply "a minute and 19 seconds ago" or "now" when diff == 0.
local function format_time_ago(past_timestamp, show_exact, date_func, time_func)
	local now = (time_func or os_time)()
	local diff = now - past_timestamp
	if diff < 0 then diff = 0 end

	-- Special case
	if diff == 0 then
		return "now"
	end

	local seconds = diff % 60
	local minutes = math_floor(diff / 60) % 60
	local hours   = math_floor(diff / 3600) % 24
	local days    = math_floor(diff / 86400)
	local phrase  = timeago_build_phrase(days, hours, minutes, seconds) .. " ago"

	if show_exact then
		local df = date_func or os_date
		local exact = df("%I:%M:%S %p %m/%d/%Y", past_timestamp)
		exact = string_gsub(exact, "^0", "")
		phrase = phrase .. " (" .. exact .. ")"
	end

	return phrase
end

------------------------------------------------------------
-- Locale table (for human formatting)
------------------------------------------------------------
--- @class LocaleSpec
--- @field day string
--- @field hour string
--- @field minute string
--- @field second string
--- @field millisecond string
--- @field short table
local LOCALES = {
	en = {
		day = "day",
		hour = "hour",
		minute = "minute",
		second = "second",
		millisecond = "millisecond",
		short = { day = "d", hour = "h", minute = "m", second = "s", millisecond = "ms" },
	},
}

------------------------------------------------------------
-- Plural helper
------------------------------------------------------------
--- @param n number
--- @param word string
--- @return string
local function plural(n, word)
	return n .. " " .. word .. (n == 1 and "" or "s")
end

------------------------------------------------------------
-- Duration object (time-focused)
------------------------------------------------------------
---@class Duration
---@field seconds number
local Duration = {}
Duration.__index = Duration

--- Create a Duration object.
--- @param seconds number|integer
--- @return Duration
local function new_duration(seconds)
	return setmetatable({ seconds = seconds }, Duration)
end

function Duration:clone() return new_duration(self.seconds) end

function Duration:add(other) return new_duration(self.seconds + ((type(other) == "table" and other.seconds) or other)) end

function Duration:sub(other) return new_duration(self.seconds - ((type(other) == "table" and other.seconds) or other)) end

function Duration:mul(f) return new_duration(self.seconds * f) end

function Duration:div(d) return new_duration(self.seconds / d) end

function Duration:neg() return new_duration(-self.seconds) end

--- Convert Duration to compact or human-friendly string.
--- @param human boolean|nil If true, returns human-friendly string (e.g., "2 days, 3 hours, 15 minutes"), otherwise returns compact format (e.g., "2:03:15:00").
--- @param opts table|nil Optional configuration options:
---  - `locale` string: Locale code, use LOCALES table (default: "en")
---  - `style` string: "long"|"short" (default: "long")
---  - `include_ms` boolean: Whether to include milliseconds (default: false)
---
--- @return string formatted The formatted duration string
function Duration:hms(human, opts)
	opts = opts or {}
	local locale = opts.locale or "en"
	local style = opts.style or "long"
	local include_ms = opts.include_ms
	local sec_total = self.seconds

	-- handle negative durations
	local negative = false
	if sec_total < 0 then
		negative = true
		sec_total = -sec_total
	end

	-- integer seconds and fractional milliseconds
	local int_sec = math_floor(sec_total)
	local frac = sec_total - int_sec
	local ms = math_floor(frac * 1000 + 0.5) -- rounded ms

	local d = math_floor(int_sec / 86400)
	local rem = int_sec % 86400
	local h = math_floor(rem / 3600); rem = rem % 3600
	local m = math_floor(rem / 60)
	local s = rem % 60

	-- default include_ms behavior
	if not include_ms then
		include_ms = (human and (d == 0 and h == 0 and m == 0 and (s > 0 and ms > 0 or s == 0 and ms > 0)))
	end

	local function fmt_compact()
		if d > 0 then
			return string_format("%02d:%02d:%02d:%02d", d, h, m, s)
		end
		if h > 0 then
			return string_format("%02d:%02d:%02d", h, m, s)
		end
		if m > 0 then
			return string_format("%02d:%02d", m, s)
		end
		if include_ms and ms > 0 then
			return string_format("%02d.%03d", s, ms)
		end
		return string_format("%02d", s)
	end

	local function fmt_human()
		local loc = LOCALES[locale] or LOCALES.en
		local parts = {}
		if d > 0 then
			if style == "short" then
				parts[#parts + 1] = string_format("%d%s", d, loc.short and loc.short.day or "d")
			else
				parts[#parts + 1] = plural(d, loc.day)
			end
		end
		if h > 0 then
			if style == "short" then
				parts[#parts + 1] = string_format("%d%s", h, loc.short and loc.short.hour or "h")
			else
				parts[#parts + 1] = plural(h, loc.hour)
			end
		end
		if m > 0 then
			if style == "short" then
				parts[#parts + 1] = string_format("%d%s", m, loc.short and loc.short.minute or "m")
			else
				parts[#parts + 1] = plural(m, loc.minute)
			end
		end
		if s > 0 then
			if style == "short" then
				parts[#parts + 1] = string_format("%d%s", s, loc.short and loc.short.second or "s")
			else
				parts[#parts + 1] = plural(s, loc.second)
			end
		end
		if include_ms and ms > 0 then
			if style == "short" then
				parts[#parts + 1] = string_format("%d%s", ms, loc.short and loc.short.millisecond or "ms")
			else
				parts[#parts + 1] = plural(ms, loc.millisecond)
			end
		end
		if #parts == 0 then
			if style == "short" then
				return "0" ..
						(LOCALES[locale] and LOCALES[locale].short and LOCALES[locale].short.second or "s")
			end
			return plural(0, LOCALES[locale] and LOCALES[locale].second or "second")
		end
		local out = table.concat(parts, style == "short" and " " or ", ")
		if negative then out = "-" .. out end
		return out
	end

	if human then return fmt_human() end
	local out = fmt_compact()
	if negative then out = "-" .. out end
	return out
end

function Duration:ago() return os_time() - self.seconds end

function Duration:from_now() return os_time() + self.seconds end

function Duration:__tostring() return self:hms(true) end

-- Arithmetic metamethods
function Duration.__add(a, b)
	return new_duration(((type(a) == "table" and a.seconds) or a) +
		((type(b) == "table" and b.seconds) or b))
end

function Duration.__sub(a, b)
	return new_duration(((type(a) == "table" and a.seconds) or a) -
		((type(b) == "table" and b.seconds) or b))
end

function Duration.__mul(a, b)
	return new_duration(((type(a) == "table" and a.seconds) or a) *
		((type(b) == "table" and b.seconds) or b))
end

function Duration.__div(a, b)
	return new_duration(((type(a) == "table" and a.seconds) or a) /
		((type(b) == "table" and b.seconds) or b))
end

function Duration.__unm(a) return new_duration(-a.seconds) end

function Duration.__eq(a, b)
	return ((type(a) == "table" and a.seconds) or a) ==
			((type(b) == "table" and b.seconds) or b)
end

------------------------------------------------------------
-- ISO 8601 parsing/formatting
------------------------------------------------------------
local function parse_iso(iso)
	if type(iso) ~= "string" then return nil, "iso must be a string" end
	local s = string_gsub(iso, "^%s+", "")
	s = string_gsub(s, "%s+$", "")
	if s == "" then return nil, "empty string" end
	if string_sub(s, 1, 1) ~= "P" then return nil, "invalid ISO duration (must start with P)" end
	s = string_sub(s, 2)
	local date_part, time_part = s, ""
	local tpos = string_find(s, "T", 1, true)
	if tpos then
		date_part = string_sub(s, 1, tpos - 1); time_part = string_sub(s, tpos + 1)
	end
	local years = tonumber(string_match(date_part, "(%d+%.?%d*)Y")) or 0
	local months = tonumber(string_match(date_part, "(%d+%.?%d*)M")) or 0
	local weeks = tonumber(string_match(date_part, "(%d+%.?%d*)W")) or 0
	local days = tonumber(string_match(date_part, "(%d+%.?%d*)D")) or 0
	local hours = tonumber(string_match(time_part, "(%d+%.?%d*)H")) or 0
	local minutes = tonumber(string_match(time_part, "(%d+%.?%d*)M")) or 0
	local seconds = tonumber(string_match(time_part, "(%d+%.?%d*)S")) or 0
	local total = 0
	total = total + years * 365 * 86400
	total = total + months * 30 * 86400
	total = total + weeks * 7 * 86400
	total = total + days * 86400
	total = total + hours * 3600
	total = total + minutes * 60
	total = total + seconds
	return new_duration(total)
end

local function duration_to_iso(dur)
	local total = dur.seconds
	if total < 0 then total = -total end
	local days = math_floor(total / 86400)
	local rem = total % 86400
	local hours = math_floor(rem / 3600); rem = rem % 3600
	local minutes = math_floor(rem / 60)
	local seconds = rem % 60
	local frac = seconds - math_floor(seconds)
	local sec_int = math_floor(seconds)
	local s = "P"
	if days > 0 then s = s .. days .. "D" end
	if hours > 0 or minutes > 0 or seconds > 0 or frac > 0 then
		s = s .. "T"
		if hours > 0 then s = s .. hours .. "H" end
		if minutes > 0 then s = s .. minutes .. "M" end
		if sec_int > 0 or frac > 0 then
			if frac > 0 then
				local frac_str = string_format("%.9f", seconds)
				frac_str = string_gsub(frac_str, "^%d+%.", "")
				frac_str = string_gsub(frac_str, "0+$", "")
				s = s .. sec_int .. "." .. frac_str .. "S"
			else
				s = s .. sec_int .. "S"
			end
		end
	end
	if s == "P" then s = "PT0S" end
	return s
end

function Duration:to_iso() return duration_to_iso(self) end

------------------------------------------------------------
-- Natural-language parsing (commas optional)
------------------------------------------------------------
local NAT_UNITS = {}
do
	for k, v in next, CONVERSIONS do NAT_UNITS[string_lower(k)] = v end
	NAT_UNITS["secs"] = NAT_UNITS["seconds"]
	NAT_UNITS["mins"] = NAT_UNITS["minutes"]
	NAT_UNITS["hrs"] = NAT_UNITS["hours"]
	NAT_UNITS["ms"] = NAT_UNITS["ms"] or (1 / 1000)
	NAT_UNITS["millis"] = NAT_UNITS["ms"]
	NAT_UNITS["msec"] = NAT_UNITS["ms"]
	NAT_UNITS["millisecond"] = NAT_UNITS["millisecond"]
	NAT_UNITS["milliseconds"] = NAT_UNITS["milliseconds"]
end

--- Parse a natural-language duration string into a Duration.
--- Accepts tokens like "3 days", "4h", "1min", "2s", "500ms".
--- Commas and "and" are optional separators.
--- Leading "in" is ignored. Trailing "ago" is ignored here (use parse_time_expression for timestamps).
--- @param s string The natural-language duration string to parse (e.g., "3 days and 4 hours").
--- @return Duration|nil duration The parsed duration in seconds, or nil if parsing failed.
--- @return string|nil error Error message if parsing failed, nil otherwise.
local function parse_natural(s)
	if type(s) ~= "string" then return nil, "input must be a string" end
	local raw = s
	local str = string_lower(raw)
	str = string_gsub(str, "^%s+", "")
	str = string_gsub(str, "%s+$", "")
	if str == "" then return nil, "empty string" end

	-- Remove leading "in " if present
	str = string_gsub(str, "^in%s+", "")

	-- Remove commas and the word "and" as optional separators
	str = string_gsub(str, ",", " ")
	str = string_gsub(str, "%band%b()", " ")
	str = string_gsub(str, "%band%s+", " ")
	str = string_gsub(str, "%s+", " ")

	-- Special case: "now"
	if str == "now" then return new_duration(0) end

	local total = 0
	local found = false

	-- Match patterns like "1.5h", "2 h", "30min", "500ms"
	for num, unit in string_gmatch(str, "([%d%.]+)%s*([a-zA-Z]+)") do
		local n = tonumber(num)
		if n then
			local u = NAT_UNITS[unit]
			if not u then
				-- try plural/singular normalization (strip trailing s)
				local unit2 = unit
				if string_sub(unit2, -1) == "s" then unit2 = string_sub(unit2, 1, -2) end
				u = NAT_UNITS[unit2]
			end
			if u then
				total = total + n * u
				found = true
			end
		end
	end

	-- Also support compact sequences like "1d2h30m" without spaces
	if not found then
		for num, unit in string_gmatch(str, "([%d%.]+)([dhmswmy]+)") do
			local n = tonumber(num)
			if n then
				local u = NAT_UNITS[unit]
				if u then
					total = total + n * u
					found = true
				end
			end
		end
	end

	if not found then
		return nil, "no duration tokens found"
	end

	return new_duration(total)
end

--- Parse a natural-language time expression and return either a Duration or a timestamp.
--- If the expression contains "ago" or starts with "in" or contains "from now", this returns a timestamp (number).
--- Otherwise returns a Duration.
--- @param s string
--- @return Duration|number|nil, string|nil
local function parse_time_expression(s)
	if type(s) ~= "string" then return nil, "input must be a string" end
	local raw = s
	local str = string_lower(raw)
	str = string_gsub(str, "^%s+", "")
	str = string_gsub(str, "%s+$", "")
	if str == "" then return nil, "empty string" end

	local has_ago = false
	local has_in = false
	local has_from_now = false

	if string_find(str, "ago", 1, true) then has_ago = true end
	if string_find(str, "^in%s", 1) then has_in = true end
	if string_find(str, "from now", 1, true) then has_from_now = true end

	str = string_gsub(str, "%s*ago%s*$", "")
	str = string_gsub(str, "%s*from%s+now%s*$", "")

	local dur, err = parse_natural(str)
	if not dur then return nil, err end

	if has_ago then return os_time() - dur.seconds end
	if has_in or has_from_now then return os_time() + dur.seconds end
	return dur
end

------------------------------------------------------------
-- Number metatable augmentation (merge everything)
-- Preserves any existing number metatable __index fallback.
------------------------------------------------------------
local existing_mt = debug_getmetatable(0) or {}
local orig_index = existing_mt.__index

-- Proxy metatable for unit access (property-style)
local proxy_mt = {}

function proxy_mt.__call(proxy, n)
	local num = (type(n) == "number") and n or proxy._n
	return new_duration(num * proxy._mul)
end

function proxy_mt.__tostring(a)
	return tostring(a._n * a._mul)
end

function proxy_mt.__add(a, b)
	local asec = a._n * a._mul
	local bsec = (type(b) == "table" and (b._n and b._n * b._mul or b.seconds)) or b
	return asec + bsec
end

function proxy_mt.__sub(a, b)
	local asec = a._n * a._mul
	local bsec = (type(b) == "table" and (b._n and b._n * b._mul or b.seconds)) or b
	return asec - bsec
end

-- Number helper functions (property-style)
local function number_from_now(n) return os_time() + n end
local function number_ago(n) return os_time() - n end
local function number_hms(n) return new_duration(n):hms() end
local function number_hms_human(n, opts) return new_duration(n):hms(true, opts) end

--- Custom __index for numbers.
--- Supports:
--- - CONVERSIONS (5.kb, 3.days, etc.)
--- - UNITS (time proxies: 5.seconds -> proxy)
--- - formatting (.hex, .HEX, .bin)
--- - checks (.is_even, .is_odd, ...)
--- - methods (.round, .clamp, .percent_of, .between, .times)
--- - helpers (.from_now, .ago, .hms, .human)
--- Falls back to any existing number metatable __index.
--- @param n number
--- @param key string
--- @return any
local function number_index(n, key)
	-- A. Conversions (immediate numeric result)
	local conv = CONVERSIONS[key]
	if conv then
		return n * conv
	end

	-- B. Time unit proxies (so 5.seconds + 3.days works)
	local mul = UNITS[key]
	if mul then
		return setmetatable({ _n = n, _mul = mul }, proxy_mt)
	end

	-- C. Formatting
	if key == "hex" then return string_format("%x", n) end
	if key == "HEX" then return string_format("%X", n) end
	if key == "bin" then
		local t, bin = n, ""
		if t == 0 then return "0" end
		while t > 0 do
			bin = (t % 2) .. bin
			t = math_floor(t / 2)
		end
		return bin
	end

	-- D. Boolean checks (immediate)
	local check_func = CHECKS[key]
	if check_func then return check_func(n) end

	-- E. Methods (return closure injecting n)
	local method_func = METHODS[key]
	if method_func then
		return function(...)
			return method_func(n, ...)
		end
	end

	-- F. Time helpers
	if key == "from_now" then return number_from_now(n) end
	if key == "ago" then return number_ago(n) end
	if key == "hms" then return number_hms(n) end
	if key == "hms_human" then return number_hms_human(n) end
	if key == "human" then return function(opts) return new_duration(n):hms(true, opts) end end

	-- G. Fallback to original metatable if present
	if type(orig_index) == "function" then
		return orig_index(n, key)
	elseif type(orig_index) == "table" then
		return orig_index[key]
	end

	-- TODO: index math?
	return nil
end

-- Apply the metatable to all numbers.
-- TODO/FIXME: Route through Lua lib for multiple metatables...
local new_mt = {}
for k, v in next, existing_mt do new_mt[k] = v end
new_mt.__index = number_index
debug_setmetatable(0, new_mt)

------------------------------------------------------------
-- Module exports
------------------------------------------------------------
local M = {
	CONVERSIONS = CONVERSIONS,
	UNITS = UNITS,
	CHECKS = CHECKS,
	METHODS = METHODS,
	plural = plural,
	Duration = Duration,
	new_duration = new_duration,
	parse_iso = parse_iso,
	duration_to_iso = duration_to_iso,
	parse_natural = parse_natural,
	parse_time_expression = parse_time_expression,
	format_time_ago = format_time_ago,
	timeago_unit = timeago_unit,
	timeago_build_phrase = timeago_build_phrase,
	locales = LOCALES,
}

--- Strict ISO parser (errors on invalid)
--- @param iso string
--- @return Duration
function M.from_iso_strict(iso)
	local d, err = parse_iso(iso)
	if not d then return error("Invalid ISO duration: " .. (err or tostring(iso))) end
	return d
end

return M
