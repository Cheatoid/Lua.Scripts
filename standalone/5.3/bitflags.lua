-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Bitflags library for Lua 5.3+.

--- Checks if the value contains all of the specified flags.
--- @param val integer The current bitmask.
--- @param flags integer The flag or bitmask to check.
--- @return boolean boolean True if all bits in flag are set in val.
local function has_flags(val, flags)
	return (val & flags) == flags
end

--- Checks if the value contains any of the specified flags.
--- @param val integer The current bitmask.
--- @param flags integer A mask of flags to check against.
--- @return boolean boolean True if any bit in flags is set in val.
local function has_any_flags(val, flags)
	return (val & flags) ~= 0
end

--- Adds (sets) the specified flags to the value.
--- @param val integer The current bitmask.
--- @param flags integer The flag or bitmask to add.
--- @return integer integer The new bitmask with flags added.
local function add_flags(val, flags)
	return val | flags
end

--- Removes (clears) the specified flags from the value.
--- @param val integer The current bitmask.
--- @param flags integer The flag or bitmask to remove.
--- @return integer integer The new bitmask with flags removed.
local function remove_flags(val, flags)
	return val & (~flags)
end

--- Toggles (flips) the specified flags in the value.
--- @param val integer The current bitmask.
--- @param flags integer The flag or bitmask to toggle.
--- @return integer integer The new bitmask with flags toggled.
local function toggle_flags(val, flags)
	return val ~ flags
end

--- Inverts (flips) all bits in the value.
--- @param val integer The current bitmask.
--- @return integer integer The inverted bitmask.
local function invert(val)
	return ~val
end

--- Creates a factory function for generating sequential bit flags.
--- Each call to the returned function returns the next power of 2 (1, 2, 4, 8...).
--- @return function function A function that returns a new flag integer.
local function make_enum()
	local bit_index = 0
	return function()
		local flag = 1 << bit_index
		bit_index = bit_index + 1
		return flag
	end
end

-- Export
return {
	has = has_flags,
	has_any = has_any_flags,
	add = add_flags,
	remove = remove_flags,
	toggle = toggle_flags,
	invert = invert,
	make_enum = make_enum,
}
