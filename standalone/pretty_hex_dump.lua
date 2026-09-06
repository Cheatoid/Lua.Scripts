-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Localized global functions for better performance
local next = next
local type = type
local tostring = tostring
local tonumber = tonumber
local math_floor = math.floor
local string_byte = string.byte
local string_char = string.char
local string_format = string.format
local string_rep = string.rep
local table_concat = table.concat

--- Check if a byte value represents a printable ASCII character.
---@param b integer Byte value to check (0-255)
---@return boolean boolean True if printable (32-126), false otherwise
local function is_printable(b) return b >= 32 and b <= 126 end

--- Pretty-print binary data (string or table of bytes) as a hex + ASCII grid.<br>
--- This function formats binary data in a traditional hex dump layout with
--- memory addresses, hexadecimal byte representation, and ASCII character display.
---@param data string|table The binary data to dump. Can be either:
--- - string: Binary string data, each character is treated as a byte
--- - table: Dense numeric array of byte values (0-255). Uses numeric for-loop (1..#data)
---@param opts? table Optional configuration table with the following fields:
--- - `bytes_per_row` (number, default: 16): Number of bytes to display per row
--- - `group` (number, default: 4): Visual grouping of hex bytes (0 = no grouping)
--- - `show_ascii` (boolean, default: true): Whether to show ASCII column
--- - `uppercase` (boolean, default: false): Use uppercase hex digits and addresses
--- - `offset_base` (number, default: 0): Starting offset for memory addresses
--- - `pad` (string, default: " "): Character for non-printable ASCII bytes
--- - `print_fn` (function, default: `print`): Function to output each line
--- - `address_width` (number, default: auto-compute): Fixed width (in hex digits) for address column
--- - `prefix` (string, default: ""): Prefix string for each output line
---
---@usage <br>
--- ```
--- -- Basic usage with string data
--- pretty_hex_dump("Hello World!")
---
--- -- Custom formatting
--- pretty_hex_dump(data, {
---   bytes_per_row = 8,
---   group = 2,
---   uppercase = true,
---   show_ascii = false
--- })
---
--- -- Using table data with custom print function
--- local lines = {}
--- pretty_hex_dump({ 0x48, 0x65, 0x6C, 0x6C, 0x6F }, {
---   print_fn = function(line) table.insert(lines, line) end
--- })
--- ```
local function pretty_hex_dump(data, opts)
	opts = opts or {}

	local bytes_per_row = 16
	if opts.bytes_per_row ~= nil then
		bytes_per_row = tonumber(opts.bytes_per_row) or bytes_per_row
	end

	local group = 4
	if opts.group ~= nil then
		group = tonumber(opts.group) or group
		if group < 0 then group = 0 end
	end

	local show_ascii = true
	if opts.show_ascii ~= nil then show_ascii = not not opts.show_ascii end

	local uppercase = false
	if opts.uppercase ~= nil then uppercase = not not opts.uppercase end

	local offset_base = 0
	if opts.offset_base ~= nil then offset_base = tonumber(opts.offset_base) or offset_base end

	local pad = " "
	if opts.pad ~= nil then
		pad = tostring(opts.pad)
		if #pad == 0 then pad = " " end
	end

	local print_fn = print
	if opts.print_fn ~= nil and type(opts.print_fn) == "function" then print_fn = opts.print_fn end

	-- address_width: explicit handling; nil means auto-compute later
	local address_width
	if opts.address_width ~= nil then address_width = tonumber(opts.address_width) end

	local prefix = ""
	if opts.prefix ~= nil then prefix = tostring(opts.prefix) end

	-- Hex formatting helper (localized)
	local hex_fmt = uppercase and "%02X" or "%02x"
	local function byte_to_hex(b) return string_format(hex_fmt, b) end

	-- Left-pad helper (localized)
	local function pad_left(s, len, ch)
		ch = ch or " "
		s = tostring(s or "")
		local sl = #s
		if sl >= len then return s end
		return string_rep(ch, len - sl) .. s
	end

	-- Convert input to dense byte array (1..n)
	local bytes = {}
	if type(data) == "string" then
		-- String input: iterate bytes by index
		local s = data
		local slen = #s
		for i = 1, slen do
			bytes[i] = string_byte(s, i)
		end
	elseif type(data) == "table" then
		-- Table input: use numeric for-loop over #data for performance and predictability.
		-- This assumes the table is a dense array of byte values (common case).
		-- Avoids iterating non-numeric keys or sparse tables unintentionally.
		local n_in = #data
		for i = 1, n_in do
			bytes[i] = tonumber(data[i]) or 0
		end
	else
		-- unsupported type
		print_fn("pretty_hex_dump: unsupported data type: " .. tostring(type(data)))
		return
	end

	local n = #bytes
	if n == 0 then
		print_fn(prefix .. "<empty>")
		return
	end

	-- Auto-compute address_width if not provided
	if not address_width then
		local max_offset = offset_base + n - 1
		local digits = 1
		local tmp = max_offset
		while tmp >= 16 do
			tmp = math_floor(tmp / 16)
			digits = digits + 1
		end
		if digits % 2 == 1 then digits = digits + 1 end
		address_width = digits
	end

	-- Build output lines (store in table then print using next)
	local out_lines = {}
	local i = 1
	while i <= n do
		local offset = offset_base + (i - 1)
		local addr = string_format("%0" .. tostring(address_width) .. "x", offset)
		if uppercase then addr = addr:upper() end

		-- Collect hex and ascii parts for this row
		local hex_parts = {}
		local ascii_parts = {}

		for j = 0, bytes_per_row - 1 do
			local idx = i + j
			if idx <= n then
				local b = bytes[idx] or 0
				hex_parts[#hex_parts + 1] = byte_to_hex(b)
				ascii_parts[#ascii_parts + 1] = (is_printable(b) and string_char(b)) or pad
			else
				-- pad missing bytes to keep columns aligned
				hex_parts[#hex_parts + 1] = "  "
				ascii_parts[#ascii_parts + 1] = pad
			end
		end

		-- Format hex column with optional grouping
		local hex_col
		if group and group > 0 then
			local grouped = {}
			local cnt = 0
			for k = 1, #hex_parts do
				grouped[#grouped + 1] = hex_parts[k]
				cnt = cnt + 1
				if cnt == group and k < #hex_parts then
					grouped[#grouped + 1] = "" -- placeholder for extra spacing
					cnt = 0
				end
			end
			hex_col = table_concat(grouped, " ")
			hex_col = hex_col:gsub("%s+", " ")
			local expected_min = bytes_per_row * 2 + math_floor((bytes_per_row - 1) / group)
			if #hex_col < expected_min then hex_col = pad_left(hex_col, expected_min, " ") end
		else
			hex_col = table_concat(hex_parts, " ")
		end

		local ascii_col = table_concat(ascii_parts, "")
		local line = prefix .. addr .. "  " .. hex_col
		if show_ascii then line = line .. "  |" .. ascii_col .. "|" end
		out_lines[#out_lines + 1] = line

		i = i + bytes_per_row
	end

	-- Print lines using next iterator (keeps consistent output iteration)
	local k, v = next(out_lines, nil)
	while k ~= nil do
		print_fn(v)
		k, v = next(out_lines, k)
	end
end

-- Export
return pretty_hex_dump
