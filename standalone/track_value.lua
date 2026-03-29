-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Localization for better performance
local select = select
local HASH = "#"

--- Creates a value tracker that monitors changes and triggers callbacks.
--- @param initial_value any The initial value to track (optional, defaults to fetch_value result)
--- @param fetch_value function Function to fetch the current value, called with varargs
--- @param on_changed function|nil Callback function triggered when value changes, receives (new_value, old_value)
--- @param ... any Additional arguments passed to fetch_value
--- @return function check function that returns (changed, new_value, old_value)
--- @usage <br>
--- ```
--- local tracker = track_value(0, function() return get_counter() end, function(new, old)
---   print("Value changed from", old, "to", new)
--- end)
--- local changed, new_val = tracker()
--- ```
local function track_value(initial_value, fetch_value, on_changed, ...)
  local value
  if initial_value ~= nil then
    value = initial_value
  else
    value = fetch_value(...)
  end
  --- Checks for value changes and updates the tracked value.
  --- @param ... any Optional new value to set, or empty to fetch using fetch_value
  --- @return boolean changed True if value changed, false otherwise
  --- @return any new_value The new value (or current value if unchanged)
  --- @return any old_value The previous value (only if changed)
  local function check(...)
    local newValue
    if select(HASH, ...) == 0 then
      newValue = fetch_value(value)
    else
      newValue = (...)
    end
    if newValue == value then return false, value end -- unchanged
    local oldValue = value
    value = newValue
    if on_changed then on_changed(newValue, oldValue) end
    return true, newValue, oldValue -- changed
  end
  return check
end

return track_value
