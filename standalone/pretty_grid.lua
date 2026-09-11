-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Enhanced pretty grid with shorthand sorting, coercion helpers, and stable in-place merge sort

-- Localized global functions for better performance
local print_fn_default = print
local tonumber = tonumber
local tostring = tostring
local type = type
local math_floor = math.floor
local math_min = math.min
local string_match = string.match
local string_rep = string.rep
local string_sub = string.sub
local table_concat = table.concat
local table_sort = table.sort

----------------------------------------------------------------------
-- Padding helpers
----------------------------------------------------------------------

local function pad_left(val, len, ch)
	ch = ch or " "
	local s = tostring(val or "")
	local slen = #s
	if slen >= len then return s end
	return string_rep(ch, len - slen) .. s
end

local function pad_right(val, len, ch)
	ch = ch or " "
	local s = tostring(val or "")
	local slen = #s
	if slen >= len then return s end
	return s .. string_rep(ch, len - slen)
end

local function pad_center(val, len, ch)
	ch = ch or " "
	local s = tostring(val or "")
	local slen = #s
	if slen >= len then return s end
	local total_pad = len - slen
	local left_pad = math_floor(total_pad / 2)
	local right_pad = total_pad - left_pad
	return string_rep(ch, left_pad) .. s .. string_rep(ch, right_pad)
end

----------------------------------------------------------------------
-- Coercion helpers
----------------------------------------------------------------------

local function coerce_number(v)
	if v == nil then return end -- implicit nil
	if type(v) == "number" then return v end
	return tonumber(v) or 0
end

local function coerce_string(v)
	if v == nil then return end -- implicit nil
	if type(v) == "string" then return v end
	return tostring(v)
end

----------------------------------------------------------------------
-- Header alignment parsing
-- Parse column alignment from header text (markdown-style: :text=left, :text:=center, text:=right, \:=escaped)
-- Returns: cleaned_text, alignment ("left", "center", "right", or nil for default)
----------------------------------------------------------------------

local function parse_header_alignment(s)
	if type(s) ~= "string" then return s end

	if string_sub(s, 1, 1) == "\\" and string_sub(s, 2, 2) == ":" then
		return string_sub(s, 2)
	end

	local starts_with_colon = string_sub(s, 1, 1) == ":"
	local ends_with_colon = string_sub(s, -1) == ":"

	if starts_with_colon and ends_with_colon then
		return string_sub(s, 2, -2), "center"
	end
	if ends_with_colon then
		return string_sub(s, 1, -2), "right"
	end
	if starts_with_colon then
		return string_sub(s, 2), "left"
	end

	return s
end

----------------------------------------------------------------------
-- Sorting helpers
----------------------------------------------------------------------

local function parse_col_shorthand(s)
	if type(s) ~= "string" then return end
	-- expected forms: "col:2", "col:-2", "col: 2", "col:- 2"
	local a = string_match(s, "^%s*col%s*:%s*([%-]?%d+)%s*$")
	if not a then return end
	local idx = tonumber(a)
	if not idx then return end
	local desc = idx < 0
	if idx < 0 then idx = -idx end
	return { col = idx, desc = desc }
end

-- Build normalized sort_cols array from mixed input (strings, tables)
local function normalize_sort_cols(raw)
	if not raw then return nil end
	local out = {}
	for i = 1, #raw do
		local v = raw[i]
		if type(v) == "string" then
			local parsed = parse_col_shorthand(v)
			if parsed then out[#out + 1] = parsed end
		elseif type(v) == "number" then
			out[#out + 1] = { col = v, desc = false }
		elseif type(v) == "table" then
			-- allow { col = n, desc = true/false, key = fn, coerce = "number"/"string"/fn }
			out[#out + 1] = v
		end
	end
	if #out > 0 then return out end
end

-- Normalize sort_keys entries (coerce shorthand)
local function normalize_sort_keys(raw)
	if not raw then return end
	local out = {}
	for i = 1, #raw do
		local e = raw[i]
		if type(e) == "function" then
			out[#out + 1] = { key = e, desc = false }
		elseif type(e) == "table" and e.key then
			out[#out + 1] = e
		end
	end
	if #out > 0 then
		return out
	end
end

-- Build comparator from options (multi-key, per-column coercion, shorthand)
local function build_comparator(opts, ncols)
	opts = opts or {}
	local sc = normalize_sort_cols(opts.sort_cols)
	local sk = normalize_sort_keys(opts.sort_keys)
	-- if single sort_key provided as function
	if opts.sort_key and type(opts.sort_key) == "function" then
		sk = sk or {}
		sk[#sk + 1] = { key = opts.sort_key, desc = not not opts.sort_desc, coerce = opts.coerce }
	end
	-- helper to apply coercion
	local function apply_coerce(val, coerce)
		if not coerce then return val end
		if coerce == "number" then return coerce_number(val) end
		if coerce == "string" then return coerce_string(val) end
		if type(coerce) == "function" then return coerce(val) end
		return val
	end

	if sk then
		return function(a, b)
			for i = 1, #sk do
				local entry = sk[i]
				local keyfn = entry.key
				local coerce = entry.coerce or opts.coerce
				local ka = apply_coerce(keyfn(a), coerce)
				local kb = apply_coerce(keyfn(b), coerce)
				if ka == nil and kb == nil then
				elseif ka == nil then
					return not entry.desc
				elseif kb == nil then
					return entry.desc
				elseif ka ~= kb then
					return entry.desc and ka > kb or ka < kb
				end
			end
			return false
		end
	end

	if sc then
		return function(a, b)
			for i = 1, #sc do
				local rule = sc[i]
				local col = rule.col or i
				local desc = rule.desc
				local keyfn = rule.key
				local coerce = rule.coerce or opts.coerce
				local va
				if type(a) == "table" then
					va = a[col]
				elseif col == 1 then
					va = a
				end
				local vb
				if type(b) == "table" then
					vb = b[col]
				elseif col == 1 then
					vb = b
				end
				if keyfn then
					va = keyfn(va)
					vb = keyfn(vb)
				end
				va = apply_coerce(va, coerce)
				vb = apply_coerce(vb, coerce)
				if va == nil and vb == nil then
				elseif va == nil then
					return not rule.desc
				elseif vb == nil then
					return rule.desc
				elseif va ~= vb then
					return rule.desc and va > vb or va < vb
				end
			end
			return false
		end
	end

	return opts.sort_cmp
end

----------------------------------------------------------------------
-- Stable in-place merge sort
-- works on array-like table t[1..n], comparator cmp(a,b) returns true if a < b
----------------------------------------------------------------------

local function merge_sort_inplace(t, cmp)
	local n = #t
	if n <= 1 then return t end
	-- allocate temp buffer once
	local buf = {}
	-- bottom-up iterative merge to avoid recursion
	local width = 1
	while width < n do
		local i = 1
		while i <= n do
			local left = i
			local mid = math_min(i + width - 1, n)
			local right = math_min(i + 2 * width - 1, n)
			-- merge [left..mid] and [mid+1..right] into buf
			local p, q, k = left, mid + 1, left
			while p <= mid and q <= right do
				if cmp(t[p], t[q]) then
					buf[k] = t[p]
					p = p + 1
				else
					buf[k] = t[q]
					q = q + 1
				end
				k = k + 1
			end
			while p <= mid do
				buf[k] = t[p]
				p = p + 1
				k = k + 1
			end
			while q <= right do
				buf[k] = t[q]
				q = q + 1
				k = k + 1
			end
			-- copy back
			for x = left, right do t[x] = buf[x] end
			i = i + 2 * width
		end
		width = width * 2
	end
	return t
end

----------------------------------------------------------------------
-- Shallow copy
----------------------------------------------------------------------

local function shallow_copy_rows(rows)
	local out = {}
	for i = 1, #rows do out[i] = rows[i] end
	return out
end

--[[
Pretty prints tabular data in a formatted grid with customizable alignment, borders, and sorting.

This function takes tabular data (rows of columns) and formats it into a visually appealing
grid layout with support for custom column widths, alignment, borders, headers, sorting,
and various formatting options.

## Parameters
- **rows** (table|nil): Array of rows to display. Each row can be:
	- A table containing column values (e.g. `{col1, col2, col3}`)
	- A single value for single-column tables
	- nil for empty table
- **cols** (number|nil): Number of columns. If nil, inferred from first row or maximum row length.
- **col_widths** (table|nil): Array of column widths. Fixed widths for specific columns.
	- If provided, only those columns are fixed-width; others auto-size.
	- If nil, all columns auto-size to fit content.
- **opts** (table|nil): Configuration options table with the following fields:

### Formatting Options
- **pad** (string, default: " "): Padding character for cell alignment.
- **sep** (string, default: " | "): Column separator string.
- **truncate** (boolean, default: true): Whether to truncate oversize content with "...".
- **min_width** (number, default: 1): Minimum width for auto-sized columns.
- **print_fn** (function, default: `print`): Function used for output (e.g. print, io.write).

### Border Options
- **border** (boolean|table|nil): Border configuration:
	- false/nil: No borders
	- true: Default borders using "+", "-", "|"
	- table: Custom border characters with fields:
		- **horizontal** (string, default: "-"): Horizontal line character
		- **vertical** (string, default: "|"): Vertical line character
		- **top_left** (string, default: "+"): Top-left corner
		- **top_right** (string, default: "+"): Top-right corner
		- **bottom_left** (string, default: "+"): Bottom-left corner
		- **bottom_right** (string, default: "+"): Bottom-right corner
		- **mid_left** (string, default: "+"): Header separator left corner
		- **mid_right** (string, default: "+"): Header separator right corner
		- **join** (string, default: "+"): Cross intersection character

### Header Options
- **header** (table|nil): Header row array. Supports markdown-style alignment:
	- `":text"`: Left alignment
	- `"text:"`: Right alignment
	- `":text:"`: Center alignment
	- `"\:text"`: Escape colon, display as ":text"

### Alignment Options
- **align** (table|nil): Array of column alignments. Each entry can be:
	- "left" (default)
	- "right"
	- "center"

### Sorting Options
- **sort_cols** (table|nil): Array of column sort specifications:
	- Number: Sort by column index (ascending)
	- String: Shorthand "col:2" (ascending) or "col:-2" (descending)
	- Table: `{col = n, desc = bool, key = fn, coerce = type}`
- **sort_keys** (table|nil): Array of key function specifications:
	- Function: Sort by key function (ascending)
	- Table: `{key = fn, desc = bool, coerce = type}`
- **sort_key** (function|nil): Single key function for sorting.
- **sort_desc** (boolean|nil): Sort descending for single sort_key.
- **sort_cmp** (function|nil): Custom comparator function.
- **coerce** (string|function|nil): Default coercion type:
	- "number": Convert to numbers for comparison
	- "string": Convert to strings for comparison
	- function: Custom coercion function
- **merge_sort** (boolean|nil): Use stable merge sort instead of table.sort.
- **inplace** (boolean|nil): Sort input table in-place instead of copying.

## Returns
- nil: Outputs formatted grid directly via print_fn.

## Examples
```
-- Basic usage
local data = {
	{"Name", "Age", "City"},
	{"Alice", 25, "New York"},
	{"Bob", 30, "Los Angeles"},
	{"Charlie", 35, "Chicago"}
}
pretty_print_grid(data, 3)

-- With borders and custom alignment
pretty_print_grid(data, 3, nil, {
	border = true,
	header = {"Name:", "Age:", ":City:"},  -- left, right, center alignment
	align = {"left", "center", "right"}
})

-- With sorting
pretty_print_grid(data, 3, nil, {
	sort_cols = {"col:2"},  -- sort by second column ascending
	border = true
})

-- Fixed column widths
pretty_print_grid(data, 3, {10, 5, 15}, {
	border = {horizontal = "=", vertical = "|"},
	truncate = false
})
```

## Notes
- Column widths include padding characters.
- Sorting is stable when merge_sort is enabled.
- Nil values are treated as empty strings.
- The function handles mixed row types (tables and single values).
- Header alignment syntax follows markdown table conventions.
]]
local function pretty_print_grid(rows, cols, col_widths, opts)
	opts = opts or {}
	local padch = opts.pad or " "
	local sep = opts.sep or " | "
	local truncate = (opts.truncate == nil) and true or not not opts.truncate
	local minw = tonumber(opts.min_width) or 1
	local print_fn = opts.print_fn or print_fn_default

	-- Border options
	local border = opts.border
	local use_border = border == true or (type(border) == "table")
	local border_h = (type(border) == "table" and border.horizontal) or "-"
	local border_v = (type(border) == "table" and border.vertical) or "|"
	local border_tl = (type(border) == "table" and border.top_left) or "+"
	local border_tr = (type(border) == "table" and border.top_right) or "+"
	local border_bl = (type(border) == "table" and border.bottom_left) or "+"
	local border_br = (type(border) == "table" and border.bottom_right) or "+"
	local border_ml = (type(border) == "table" and border.mid_left) or "+"
	local border_mr = (type(border) == "table" and border.mid_right) or "+"
	local border_j = (type(border) == "table" and border.join) or "+"

	local sep_border = string_rep(border_h, #sep)

	-- Determine number of columns
	local r = rows or {}
	local inferred_cols = cols
	if not inferred_cols then
		if #r > 0 and type(r[1]) == "table" then
			inferred_cols = #r[1]
		else
			inferred_cols = 0
			for i = 1, #r do
				if type(r[i]) == "table" and #r[i] > inferred_cols then inferred_cols = #r[i] end
			end
		end
	end
	local ncols = inferred_cols

	-- Copy rows if not inplace
	local work_rows = opts.inplace and r or shallow_copy_rows(r)

	-- Sorting
	local cmp = build_comparator(opts, ncols)
	if cmp then
		-- stable sort: decorate with original index
		local decorated = {}
		for i = 1, #work_rows do decorated[i] = { key = work_rows[i], idx = i } end
		local function decorated_cmp(a, b)
			local ra, rb = a.key, b.key
			if cmp(ra, rb) then return true end
			if cmp(rb, ra) then return false end
			return a.idx < b.idx
		end
		if opts.merge_sort then
			-- perform stable in-place merge sort on decorated, then strip
			-- we need comparator for decorated elements
			merge_sort_inplace(decorated, decorated_cmp)
		else
			-- fallback to table.sort on decorated
			table_sort(decorated, decorated_cmp)
		end
		for i = 1, #decorated do work_rows[i] = decorated[i].key end
	end

	-- Header alignment (markdown-style: :text=left, :text:=center, text:=right)
	local header_alignments = {}
	local processed_header = {}
	if opts.header and type(opts.header) == "table" then
		for i = 1, ncols do
			local cleaned, align = parse_header_alignment(opts.header[i] or "")
			processed_header[i] = cleaned
			header_alignments[i] = align
		end
	end

	----------------------------------------------------------------------
	-- Compute column widths (Option B: widths include padding)
	----------------------------------------------------------------------

	local widths = {}

	-- fixed-width columns
	local fixed = {}
	if col_widths and type(col_widths) == "table" then
		for i = 1, ncols do
			if col_widths[i] then
				fixed[i] = tonumber(col_widths[i])
			end
		end
	end

	-- initialize widths
	for i = 1, ncols do
		widths[i] = fixed[i] or minw
	end

	-- auto-size only non-fixed columns
	local function consider_cell(c, idx)
		if fixed[idx] then return end
		local s = tostring(c or "")
		local l = #s
		if l > widths[idx] then widths[idx] = l end
	end

	if not next(fixed) then
		if processed_header then
			for j = 1, ncols do consider_cell(processed_header[j] or "", j) end
		end
		for i = 1, #work_rows do
			local row = work_rows[i]
			if type(row) == "table" then
				for j = 1, ncols do consider_cell(row[j] or "", j) end
			else
				consider_cell(row, 1)
			end
		end
	end

	-- enforce fixed widths
	for i = 1, ncols do
		if fixed[i] then widths[i] = fixed[i] end
	end

	----------------------------------------------------------------------
	-- Alignment
	----------------------------------------------------------------------

	local align = {}
	-- Initialize align for actual ncols count, then apply header alignments
	for i = 1, ncols do
		align[i] = (opts.align and opts.align[i]) or "left"
	end
	-- Header alignments override opts.align
	for i = 1, ncols do
		if header_alignments[i] then align[i] = header_alignments[i] end
	end

	----------------------------------------------------------------------
	-- Cell formatting
	----------------------------------------------------------------------

	local function format_cell(val, idx)
		local s = tostring(val or "")
		local w = widths[idx]

		if truncate and #s > w then
			if w > 3 then s = string_sub(s, 1, w - 3) .. "..." else s = string_sub(s, 1, w) end
		end

		local a = align[idx]
		if a == "right" then
			return pad_left(s, w, padch)
		end
		if a == "center" then
			return pad_center(s, w, padch)
		end
		return pad_right(s, w, padch)
	end

	----------------------------------------------------------------------
	-- Build row line
	----------------------------------------------------------------------

	local function build_line(row)
		local parts = {}
		for j = 1, ncols do
			local cell = (type(row) == "table") and row[j] or (j == 1 and row or "")
			parts[#parts + 1] = format_cell(cell, j)
		end
		local content = table_concat(parts, sep)
		-- add one space inside vertical borders
		if use_border then
			return border_v .. " " .. content .. " " .. border_v
		end
		return content
	end

	----------------------------------------------------------------------
	-- Build border line
	----------------------------------------------------------------------

	-- Build horizontal border line so it matches padded row width
	local function build_border_line(left, right)
		local parts = {}
		for j = 1, ncols do
			parts[#parts + 1] = string_rep(border_h, widths[j])
		end
		-- add 1 extra "border_h" on each side to account for the two spaces in rows
		return left
				.. string_rep(border_h, 1)
				.. table_concat(parts, sep_border)
				.. string_rep(border_h, 1)
				.. right
	end

	----------------------------------------------------------------------
	-- Print table
	----------------------------------------------------------------------

	if use_border then print_fn(build_border_line(border_tl, border_tr)) end

	if processed_header and #processed_header > 0 then
		print_fn(build_line(processed_header))
		if use_border then
			print_fn(build_border_line(border_ml, border_mr))
		else
			local parts = {}
			for j = 1, ncols do parts[#parts + 1] = string_rep("-", widths[j]) end
			print_fn(table_concat(parts, string_rep("-", #sep)))
		end
	end

	for i = 1, #work_rows do print_fn(build_line(work_rows[i])) end

	-- Print bottom border
	if use_border then print_fn(build_border_line(border_bl, border_br)) end
end

-- Export
return pretty_print_grid
