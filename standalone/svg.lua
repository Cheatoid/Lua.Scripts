-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

--[[
SVG parser library

Usage example:
	local svgparser = require "svgparser"
	local svg = svgparser.parse(svg_string)
	if svg then
		svgparser.traverse(svg, function(node, depth)
			print(string.rep("  ", depth) .. node.tag)
		end)
	end

Node structure:
	Each node is a table with the following fields:
	- tag      : string, element name (e.g. "svg", "path", "rect") or "#text" for text nodes
	- attr     : table of attribute name -> value (raw strings)
	- children : array of child nodes
	- parent   : reference to parent node (nil for root)
	- text     : only for text nodes, contains the text content
	- parsed   : table with parsed data:
		* transform   : list of {type=string, args=table} (if transform attribute present)
		* style       : table of CSS property -> value (if style attribute present)
		* pathData    : list of {command=string, params=table} (for <path> elements)
		* viewBox     : table {x, y, width, height} (for <svg> elements)
		* width/height: parsed length table {value=number, unit=string} (optional)
--]]
local M = {}

-- Localized global functions for better performance
local ipairs = ipairs
local next = next
local tonumber = tonumber
local type = type
local string_byte = string.byte
local string_char = string.char
local string_find = string.find
local string_gmatch = string.gmatch
local string_lower = string.lower
local string_match = string.match
local string_sub = string.sub
local table_insert = table.insert
local table_remove = table.remove

----------------------------------------------------------------------
-- XML parser (limited but suitable for SVG)
----------------------------------------------------------------------

--- Finds the '>' that closes the current tag, ignoring quotes.
---@param s string source The source string.
---@param start_pos integer position The starting position (index of '<').
---@return integer? end_pos The position of the closing '>', or nil if not found.
local function find_tag_end(s, start_pos)
	-- Finds the '>' that closes the current tag, ignoring quotes.
	local len = #s
	local pos = start_pos
	local in_quote = false
	local quote_byte = 0
	while pos <= len do
		local b = string_byte(s, pos)
		if in_quote then
			if b == quote_byte then
				in_quote = false
			end
		else
			if b == 34 or b == 39 then
				in_quote = true
				quote_byte = b
			elseif b == 62 then
				return pos
			end
		end
		pos = pos + 1
	end
	return nil
end

--- Parse a string of attributes into a table.<br>
--- Accepts name="value", name='value', and bare names.
---@param attr_str string attributes The attribute substring.
---@param attr_table table target The table to fill with name -> value pairs.
local function parse_attributes(attr_str, attr_table)
	-- Parses a string of attributes into a table.
	-- Accepts name="value", name='value', and bare names.
	local pos = 1
	local len = #attr_str
	while pos <= len do
		local b = string_byte(attr_str, pos)
		if b == 32 or b == 9 or b == 10 or b == 13 then
			pos = pos + 1
		else
			-- find attribute name
			local name = string_match(attr_str, "^[%w:%-]+", pos)
			if not name then
				-- skip invalid char
				pos = pos + 1
			else
				pos = pos + #name
				-- skip whitespace
				while pos <= len do
					local wb = string_byte(attr_str, pos)
					if wb == 32 or wb == 9 or wb == 10 or wb == 13 then
						pos = pos + 1
					else
						break
					end
				end
				if string_byte(attr_str, pos) == 61 then
					pos = pos + 1
					-- skip whitespace
					while pos <= len do
						local wb = string_byte(attr_str, pos)
						if wb == 32 or wb == 9 or wb == 10 or wb == 13 then
							pos = pos + 1
						else
							break
						end
					end
					local quote = string_byte(attr_str, pos)
					if quote == 34 or quote == 39 then
						pos = pos + 1
						local end_quote = string_find(attr_str, string_char(quote), pos, true)
						if end_quote then
							local value = string_sub(attr_str, pos, end_quote - 1)
							attr_table[name] = value
							pos = end_quote + 1
						else
							-- missing closing quote, take rest
							attr_table[name] = string_sub(attr_str, pos)
							break
						end
					else
						-- unquoted value, read until whitespace or end of tag
						local value = string_match(attr_str, "^[^%s>]+", pos)
						if value then
							attr_table[name] = value
							pos = pos + #value
						end
					end
				else
					-- bare attribute (e.g. "required")
					attr_table[name] = ""
				end
			end
		end
	end
end

--- Core XML parser: builds a tree of nodes from an XML string.<br>
--- Returns a synthetic root node whose children are the top-level elements.
---@param xml_string string source The XML source string.
---@return table root The root node table.
local function parse_xml(xml_string)
	local root = { tag = "__root__", attr = {}, children = {}, parent = nil }
	local stack = { root }
	local pos = 1
	local len = #xml_string

	while pos <= len do
		local b = string_byte(xml_string, pos)
		if b == 60 then
			local next_b = string_byte(xml_string, pos + 1)
			if next_b == 33 then
				-- Comment or CDATA or DOCTYPE
				local after_bang = string_sub(xml_string, pos + 2, pos + 3)
				if after_bang == "--" then
					-- Comment
					local close = string_find(xml_string, "-->", pos + 4, true)
					if not close then break end
					pos = close + 3
				elseif string_sub(xml_string, pos + 2, pos + 8) == "[CDATA[" then
					-- CDATA section
					local close = string_find(xml_string, "]]>", pos + 9, true)
					if not close then break end
					local content = string_sub(xml_string, pos + 9, close - 1)
					local text_node = { tag = "#text", attr = {}, children = {}, parent = stack[#stack], text = content }
					table_insert(stack[#stack].children, text_node)
					pos = close + 3
				else
					-- DOCTYPE or other declaration, skip to '>'
					local close = string_find(xml_string, ">", pos + 2, true)
					if not close then break end
					pos = close + 1
				end
			elseif next_b == 47 then
				-- Closing tag
				local close = string_find(xml_string, ">", pos + 2, true)
				if not close then break end
				local tag_name = string_match(string_sub(xml_string, pos + 2, close - 1), "^%s*([%w:%-]+)")
				if tag_name and #stack > 1 then
					-- Pop stack (assume well-formed)
					table_remove(stack)
				end
				pos = close + 1
			elseif next_b == 63 then
				-- Processing instruction
				local close = string_find(xml_string, "?>", pos + 2, true)
				if not close then break end
				pos = close + 2
			else
				-- Opening tag
				local tag_end = find_tag_end(xml_string, pos)
				if not tag_end then break end
				local tag_content = string_sub(xml_string, pos + 1, tag_end - 1)
				local self_closing = (string_byte(tag_content, -1) == 47)
				if self_closing then
					tag_content = string_sub(tag_content, 1, -2)
				end
				local tag_name, attr_str = string_match(tag_content, "^%s*([%w:%-]+)%s*(.*)$")
				if tag_name then
					local node = { tag = tag_name, attr = {}, children = {}, parent = stack[#stack] }
					parse_attributes(attr_str, node.attr)
					table_insert(stack[#stack].children, node)
					if not self_closing then
						table_insert(stack, node)
					end
				end
				pos = tag_end + 1
			end
		else
			-- Text content
			local next_tag = string_find(xml_string, "<", pos, true)
			if not next_tag then next_tag = len + 1 end
			local text = string_sub(xml_string, pos, next_tag - 1)
			if string_match(text, "%S") then -- ignore whitespace-only text
				local text_node = { tag = "#text", attr = {}, children = {}, parent = stack[#stack], text = text }
				table_insert(stack[#stack].children, text_node)
			end
			pos = next_tag
		end
	end
	return root
end

----------------------------------------------------------------------
-- Path Data Parser (byte-optimized)
----------------------------------------------------------------------

--- Return the number of numeric parameters for an SVG path command byte.
---@param cmd_byte integer byte The command byte (e.g. string.byte("M")).
---@return integer count The number of parameters for the command.
local function get_num_params(cmd_byte)
	-- Convert to uppercase byte for comparison (if lowercase)
	local u = cmd_byte
	if u >= 97 and u <= 122 then
		u = u - 32                     -- to uppercase
	end
	if u == 77 or u == 76 or u == 84 then -- M, L, T
		return 2
	end
	if u == 72 or u == 86 then -- H, V
		return 1
	end
	if u == 67 then -- C
		return 6
	end
	if u == 83 or u == 81 then -- S, Q
		return 4
	end
	if u == 65 then -- A
		return 7
	end
	if u == 90 then -- Z
		return 0
	end
	return 0
end

--- Parse an SVG path `d` attribute into a list of commands.
---@param d string? data The path data string.
---@return table commands The list of {command=string, params=table} entries.
function M.parsePathData(d)
	if not d or d == "" then return {} end
	local commands = {}
	local pos = 1
	local len = #d
	local current_command_byte = nil

	local function skip_separators()
		while pos <= len do
			local b = string_byte(d, pos)
			if b == 32 or b == 9 or b == 10 or b == 13 or b == 44 then
				pos = pos + 1
			else
				break
			end
		end
	end

	local function read_number()
		skip_separators()
		local num = string_match(d, "^[-+]?%d*%.?%d+([eE][-+]?%d+)?", pos)
		if not num then
			-- try flag (0 or 1) without decimal
			local c = string_byte(d, pos)
			if c == 48 or c == 49 then -- '0' or '1'
				num = string_char(c)
				pos = pos + 1
				return tonumber(num)
			end
			return nil
		end
		pos = pos + #num
		return tonumber(num)
	end

	while pos <= len do
		skip_separators()
		if pos > len then break end
		local b = string_byte(d, pos)
		if (b >= 65 and b <= 90) or (b >= 97 and b <= 122) then
			-- command letter
			if b == 90 or b == 122 then
				table_insert(commands, { command = 'Z', params = {} })
				current_command_byte = nil
				pos = pos + 1
			else
				current_command_byte = b
				table_insert(commands, { command = string_char(b), params = {} })
				pos = pos + 1
			end
		else
			-- Must be number or error
			if not current_command_byte then
				-- ignore stray numbers
				break
			end
			local num_params = get_num_params(current_command_byte)
			local params = {}
			for i = 1, num_params do
				local val = read_number()
				if val == nil then
					-- error, stop parsing
					return commands
				end
				params[i] = val
				skip_separators()
			end
			local last = commands[#commands]
			if last then
				last.params = params
			end
		end
	end
	return commands
end

----------------------------------------------------------------------
-- Transform Parser
----------------------------------------------------------------------

--- Parse an SVG `transform` attribute into a list of transform operations.
---@param transform_str string? value The transform attribute string.
---@return table transforms The list of {type=string, args=table} entries.
function M.parseTransform(transform_str)
	if not transform_str or transform_str == "" then return {} end
	local transforms = {}
	local pos = 1
	local len = #transform_str
	while pos <= len do
		local b = string_byte(transform_str, pos)
		if b == 32 or b == 9 or b == 10 or b == 13 or b == 44 then
			pos = pos + 1
		else
			local name, args_str, new_pos = string_match(transform_str, "^([%a]+)%s*%(([^)]*)%)()", pos)
			if name then
				local args = {}
				for arg in string_gmatch(args_str, "[-+]?%d*%.?%d+([eE][-+]?%d+)?") do
					table_insert(args, tonumber(arg))
				end
				table_insert(transforms, { type = name, args = args })
				pos = new_pos
			else
				-- skip invalid char
				pos = pos + 1
			end
		end
	end
	return transforms
end

----------------------------------------------------------------------
-- Style Parser
----------------------------------------------------------------------

--- Parse an SVG `style` attribute into a CSS property table.
---@param style_str string? value The style attribute string.
---@return table style The table of CSS property -> value.
function M.parseStyle(style_str)
	if not style_str or style_str == "" then return {} end
	local style = {}
	for prop, val in string_gmatch(style_str, "%s*([%w%-]+)%s*:%s*([^;]+)") do
		style[prop] = string_match(val, "^%s*(.-)%s*$") -- trim
	end
	return style
end

----------------------------------------------------------------------
-- Color Parser (basic)
----------------------------------------------------------------------

local named_colors = {
	black = { 0, 0, 0 },
	white = { 255, 255, 255 },
	red = { 255, 0, 0 },
	green = { 0, 128, 0 },
	blue = { 0, 0, 255 },
	yellow = { 255, 255, 0 },
	cyan = { 0, 255, 255 },
	magenta = { 255, 0, 255 },
	gray = { 128, 128, 128 },
	grey = { 128, 128, 128 },
	silver = { 192, 192, 192 },
	maroon = { 128, 0, 0 },
	olive = { 128, 128, 0 },
	lime = { 0, 255, 0 },
	aqua = { 0, 255, 255 },
	teal = { 0, 128, 128 },
	navy = { 0, 0, 128 },
	fuchsia = { 255, 0, 255 },
	purple = { 128, 0, 128 },
	transparent = { 0, 0, 0, 0 },
	none = nil,
	currentColor = nil, -- special
	inherit = nil,   -- special
}

--- Parse a CSS color string into normalized RGBA components.<br>
--- Supports named colors, hex (#rgb, #rrggbb), rgb()/rgba(), and percentages.<br>
--- Special values (currentColor, inherit, none) are returned as {special=name}.
---@param color_str string? value The color string.
---@return table? color The color table {r, g, b, a} (0-1 range), {special=name}, or nil when unrecognized.
function M.parseColor(color_str)
	if not color_str then return nil end
	color_str = string_match(color_str, "^%s*(.-)%s*$") -- trim
	if color_str == "" then return nil end

	-- Check named colors
	local lower = string_lower(color_str)
	if named_colors[lower] ~= nil then
		local c = named_colors[lower]
		if c == nil then
			-- special value, return as string
			return { special = lower }
		end
		return { r = c[1] / 255, g = c[2] / 255, b = c[3] / 255, a = c[4] or 1 }
	end

	-- Hex color
	if string_match(color_str, "^#%x%x%x%x%x%x$") then
		local r = tonumber(string_sub(color_str, 2, 3), 16)
		local g = tonumber(string_sub(color_str, 4, 5), 16)
		local b = tonumber(string_sub(color_str, 6, 7), 16)
		return { r = r / 255, g = g / 255, b = b / 255, a = 1 }
	elseif string_match(color_str, "^#%x%x%x$") then
		local r = tonumber(string_sub(color_str, 2, 2) .. string_sub(color_str, 2, 2), 16)
		local g = tonumber(string_sub(color_str, 3, 3) .. string_sub(color_str, 3, 3), 16)
		local b = tonumber(string_sub(color_str, 4, 4) .. string_sub(color_str, 4, 4), 16)
		return { r = r / 255, g = g / 255, b = b / 255, a = 1 }
	end

	-- rgb() / rgba()
	local r, g, b, a = string_match(color_str, "^rgba?%(([%d%.]+)%s*,%s*([%d%.]+)%s*,%s*([%d%.]+)%s*[,/]%s*([%d%.]+)%)$")
	if r then
		return { r = tonumber(r) / 255, g = tonumber(g) / 255, b = tonumber(b) / 255, a = tonumber(a) }
	end
	r, g, b = string_match(color_str, "^rgba?%(([%d%.]+)%s*,%s*([%d%.]+)%s*,%s*([%d%.]+)%)$")
	if r then
		return { r = tonumber(r) / 255, g = tonumber(g) / 255, b = tonumber(b) / 255, a = 1 }
	end

	-- percentages
	r, g, b = string_match(color_str, "^rgba?%(([%d%.]+)%%,%s*([%d%.]+)%%,%s*([%d%.]+)%%)$")
	if r then
		return { r = tonumber(r) / 100, g = tonumber(g) / 100, b = tonumber(b) / 100, a = 1 }
	end

	return nil -- unrecognized
end

----------------------------------------------------------------------
-- Length Parser (simple)
----------------------------------------------------------------------

--- Parse an SVG length string into a value/unit pair.
---@param str string? value The length string (e.g. "10px", "50%", "3.5").
---@return table? length The length table {value=number, unit=string}, or nil if unparseable.
function M.parseLength(str)
	if not str then return nil end
	local value, unit = string_match(str, "^([-+]?%d*%.?%d+)([a-zA-Z%%]*)")
	if value then
		return { value = tonumber(value), unit = unit or "" }
	end
	return nil
end

----------------------------------------------------------------------
-- Tree Processing
----------------------------------------------------------------------

--- Recursively populate the `parsed` field for a node based on its attributes.<br>
--- Handles transform, style, path data, viewBox, width and height.
---@param node table node The node to process.
local function process_node(node)
	if not node or node.tag == "#text" then return end
	local parsed = {}

	-- Transform attribute
	if node.attr.transform then
		parsed.transform = M.parseTransform(node.attr.transform)
	end

	-- Style attribute
	if node.attr.style then
		parsed.style = M.parseStyle(node.attr.style)
	end

	-- Path data
	if node.tag == "path" and node.attr.d then
		parsed.pathData = M.parsePathData(node.attr.d)
	end

	-- viewBox
	if node.tag == "svg" and node.attr.viewBox then
		local x, y, w, h = string_match(node.attr.viewBox,
			"^%s*([-+]?%d*%.?%d+)%s+([-+]?%d*%.?%d+)%s+([-+]?%d*%.?%d+)%s+([-+]?%d*%.?%d+)")
		if x then
			parsed.viewBox = { x = tonumber(x), y = tonumber(y), width = tonumber(w), height = tonumber(h) }
		end
	end

	-- width/height lengths
	if node.attr.width then
		parsed.width = M.parseLength(node.attr.width)
	end
	if node.attr.height then
		parsed.height = M.parseLength(node.attr.height)
	end

	if next(parsed) ~= nil then
		node.parsed = parsed
	end

	-- Recurse
	for _, child in ipairs(node.children) do
		process_node(child)
	end
end

----------------------------------------------------------------------
-- Main parse function
----------------------------------------------------------------------

--- Parse an SVG document string into a node tree.<br>
--- Returns the <svg> node, or nil plus an error message on failure.
---@param svg_string string source The SVG document string.
---@return table? svg The parsed <svg> node, or nil on failure.
---@return string? err The error message on failure, or nil on success.
function M.parse(svg_string)
	if type(svg_string) ~= "string" then
		return nil, "input must be a string"
	end
	local xml_root = parse_xml(svg_string)
	local svg_node
	for _, child in ipairs(xml_root.children) do
		if child.tag == "svg" then
			svg_node = child
			break
		end
	end
	if not svg_node then
		return nil, "no <svg> element found"
	end
	process_node(svg_node)
	return svg_node
end

----------------------------------------------------------------------
-- Tree traversal and utility functions
----------------------------------------------------------------------

--- Depth-first traversal of a node tree, invoking callback on each node.
---@param node table node The node to traverse.
---@param callback function cb The callback receiving (node, depth).
---@param depth? integer depth The starting depth (default: 0).
function M.traverse(node, callback, depth)
	depth = depth or 0
	if not node then return end
	callback(node, depth)
	for _, child in ipairs(node.children) do
		M.traverse(child, callback, depth + 1)
	end
end

--- Find the first node with the given `id` attribute.
---@param svg_node table node The root node to search from.
---@param id string id The id to search for.
---@return table? node The matching node, or nil if not found.
function M.getElementById(svg_node, id)
	local result
	M.traverse(svg_node, function(node)
		if node.attr and node.attr.id == id then
			result = node
		end
	end)
	return result
end

--- Collect all descendant nodes with the given tag name.
---@param svg_node table node The root node to search from.
---@param tag_name string tag The tag name to search for.
---@return table elements The list of matching nodes.
function M.getElementsByTagName(svg_node, tag_name)
	local elements = {}
	M.traverse(svg_node, function(node)
		if node.tag == tag_name then
			table_insert(elements, node)
		end
	end)
	return elements
end

-- Export
return M
