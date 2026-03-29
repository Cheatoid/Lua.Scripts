-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Format a UNIX timestamp into a human-readable "time ago" string.
-- Supports:
-- - Custom date formatting function
-- - Custom time source function
-- - Optional exact timestamp suffix
-- - Special case: "now" when diff == 0

-- Localize globals for performance
local os_time     = os.time
local os_date     = os.date
local math_floor  = math.floor
local string_gsub = string.gsub

--- Return a pluralized time unit.
--- @param n number|integer The numeric value.
--- @param singular string The singular form ("second", "minute", etc.)
--- @return string string A properly pluralized string (e.g., "1 minute", "3 minutes")
local function unit(n, singular)
	if n == 1 then
		return "1 " .. singular
	end
	return n .. " " .. singular .. "s"
end

--- Build a natural-language phrase from time components.
--- @param days number|integer Number of days (0 or positive).
--- @param hours number|integer Number of hours (0 or positive).
--- @param minutes number|integer Number of minutes (0 or positive).
--- @param seconds number|integer Number of seconds (0 or positive).
--- @return string string A phrase like "1 hour and 3 minutes" or "2 days, 5 hours and 10 minutes".
local function build_phrase(days, hours, minutes, seconds)
	local t = {}

	if days > 0 then
		t[#t + 1] = unit(days, "day")
	end
	if hours > 0 then
		t[#t + 1] = unit(hours, "hour")
	end
	if minutes > 0 then
		t[#t + 1] = unit(minutes, "minute")
	end
	if seconds > 0 or #t == 0 then
		t[#t + 1] = unit(seconds, "second")
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
	local phrase  = build_phrase(days, hours, minutes, seconds) .. " ago"

	if show_exact then
		local df = date_func or os_date
		local exact = df("%I:%M:%S %p %m/%d/%Y", past_timestamp)
		exact = string_gsub(exact, "^0", "")
		phrase = phrase .. " (" .. exact .. ")"
	end

	return phrase
end

return format_time_ago
