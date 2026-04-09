-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

--- XML parser and serializer.
--- Node representation:
--- - Root node: { name = nil, attrs = {}, children = { ... }, text = "..." }
--- - Element node: { name = "tag", attrs = {k=v,...}, children = {...}, text = "..." }
--- - CDATA node: { cdata = "..." }
--- Limitations:
--- - Not a validating parser (no DTD/XSD validation).
--- - Namespace prefixes are preserved syntactically but not resolved.
--- - Attribute order is not preserved (Lua tables are unordered). It could be preserved but requires additional table.
local XML = {}

-- Localized global functions for better performance
local error = error
local pcall = pcall
local tonumber = tonumber
local tostring = tostring
local type = type
local string_byte = string.byte
local string_char = string.char
local string_find = string.find
local string_format = string.format
local string_gsub = string.gsub
local string_match = string.match
local string_sub = string.sub
local table_concat = table.concat
local table_insert = table.insert
local table_remove = table.remove

-- Predefined XML entities
local _PREDEFINED = { lt = "<", gt = ">", amp = "&", apos = "'", quot = '"' }

-- Escape lookup table (for use with string.gsub)
local _ESCAPE_MAP = { ['&'] = "&amp;", ['<'] = "&lt;", ['>'] = "&gt;" }

-- Attribute escape map
local _ATTR_ESCAPE_MAP = { ['&'] = "&amp;", ['"'] = "&quot;" }

--- Compute line/column for an absolute byte position in source (1-based pos).
---@param pos integer position The position in the source.
---@param msg string message The error message.
---@param src string source The source string.
---@return string error The formatted error message.
local function error_at(pos, msg, src)
	local line = 1
	local col = 1
	for i = 1, (pos or 1) - 1 do
		-- Check for newline character (ASCII 10) using byte comparison
		if string_byte(src, i) == 10 then
			line = line + 1
			col = 1
		else
			col = col + 1
		end
	end
	return string_format("XML error at line %d col %d: %s", line, col, msg)
end

local decode_replacer
if utf8 and utf8.char then
	local utf8_char = utf8.char
	function decode_replacer(ent)
		-- ent like "#123", "#x1F", or "amp"
		-- Check for '#' character (ASCII 35) using byte comparison
		if string_byte(ent, 1) == 35 then
			local num = string_sub(ent, 2)
			local base = 10
			-- Check for 'x' (ASCII 120) or 'X' (ASCII 88) for hex notation
			local first_byte = string_byte(num, 1)
			if first_byte == 120 or first_byte == 88 then
				base = 16
				num = string_sub(num, 2)
			end
			local code = tonumber(num, base)
			if code then
				return utf8_char(code)
			end
			return "�"
		end
		return _PREDEFINED[ent] or ("&" .. ent .. ";")
	end
else
	function decode_replacer(ent)
		-- ent like "#123", "#x1F", or "amp"
		-- Check for '#' character (ASCII 35) using byte comparison
		if string_byte(ent, 1) == 35 then
			local num = string_sub(ent, 2)
			local base = 10
			-- Check for 'x' (ASCII 120) or 'X' (ASCII 88) for hex notation
			local first_byte = string_byte(num, 1)
			if first_byte == 120 or first_byte == 88 then
				base = 16
				num = string_sub(num, 2)
			end
			local code = tonumber(num, base)
			if code then
				return string_char(code % 256)
			end
			return "�"
		end
		return _PREDEFINED[ent] or ("&" .. ent .. ";")
	end
end

--- Decode entities: numeric (decimal/hex) and predefined; unknown entities left intact.
---@param s string input The input string.
---@return string decoded The decoded string.
local function decode_entities(s)
	if not s or s == "" then return s end
	return (string_gsub(s, "&(#?[xX]?%w+);", decode_replacer))
end

--- Parse attributes starting at position `pos` in `src`.
--- Returns attributes table and new position (index after attributes, before '>' or '/>').
---@param src string source The source string.
---@param pos integer position The starting position.
---@param src_full string source_full The full source string for error reporting.
---@return table attrs The attributes table.
---@return integer new_pos The new position.
local function parse_attributes(src, pos, src_full)
	local attrs = {}
	--local len = #(src)
	while true do
		-- skip whitespace
		local ws_start = string_match(src, "^%s*()", pos)
		if not ws_start then ws_start = pos end
		pos = ws_start
		-- attribute name pattern: allow letters, digits, underscore, colon, dot, hyphen
		local name, quote, npos = string_match(src, "^([%w:_.%-]+)%s*=%s*(['\"])()", pos)
		if not name then break end
		-- find closing quote (non-greedy)
		local val, vend = string_match(src, "^(.-)" .. quote .. "()", npos)
		if not vend then
			return error(error_at(pos, "Unterminated attribute value", src_full), 2)
		end
		attrs[name] = decode_entities(val)
		pos = vend
	end
	return attrs, pos
end

--- Core parser: builds a DOM-like tree from XML string `src`.
---@param src string source The XML source string.
---@return table root The root node table.
local function parse_node(src)
	local pos = 1
	local len = #(src)
	local root = { name = nil, attrs = {}, children = {}, text = nil }
	local stack = {}
	local cur = root

	while pos <= len do
		-- capture text up to next '<'
		local text, tpos = string_match(src, "^(.-)<()", pos)
		if not text then break end
		if text ~= "" then
			local t = decode_entities(text)
			if cur.text then
				cur.text = cur.text .. t
			else
				cur.text = t
			end
		end
		pos = tpos
		-- comment: <!-- ... -->
		if string_sub(src, pos, pos + 2) == "!--" then
			local _, cend = string_find(src, "-->", pos + 3, true)
			if not cend then error(error_at(pos, "Unterminated comment", src), 2) end
			pos = cend + 1
			-- CDATA: <![CDATA[ ... ]]>
		elseif string_sub(src, pos, pos + 7) == "![CDATA[" then
			local _, cend = string_find(src, "]]>", pos + 8, true)
			if not cend then error(error_at(pos, "Unterminated CDATA section", src), 2) end
			local cdata = string_sub(src, pos + 8, cend - 3)
			cur.children[#cur.children + 1] = { cdata = cdata }
			pos = cend + 1
			-- Processing instruction: <? ... ?>
			-- Check for '?' character (ASCII 63) using byte comparison
		elseif string_byte(src, pos) == 63 then
			local _, cend = string_find(src, "?>", pos + 1, true)
			if not cend then error(error_at(pos, "Unterminated processing instruction", src), 2) end
			pos = cend + 1
			-- End tag: </name>
			-- Check for '/' character (ASCII 47) using byte comparison
		elseif string_byte(src, pos) == 47 then
			local name, vend = string_match(src, "^/%s*([%w:_.%-]+)%s*>()", pos)
			if not name then error(error_at(pos, "Malformed end tag", src), 2) end
			if cur.name ~= name then
				return error(error_at(
					pos, string_format("Mismatched end tag '%s' (expected '%s')", name, tostring(cur.name)), src), 2)
			end
			cur = table_remove(stack)
			pos = vend
			-- Start tag or empty-element tag
		else
			local name, vend = string_match(src, "^%s*([%w:_.%-]+)()", pos)
			if not name then error(error_at(pos, "Malformed start tag", src), 2) end
			local attrs, after = parse_attributes(src, vend, src)
			-- skip optional whitespace
			local ws_after = string_match(src, "^%s*()", after) or after
			local two = string_sub(src, ws_after, ws_after + 1)
			-- Check for "/>" using byte comparison for '/' (ASCII 47)
			if string_byte(two, 1) == 47 then
				local node = { name = name, attrs = attrs, children = {}, text = nil }
				cur.children[#cur.children + 1] = node
				pos = ws_after + 2
			else
				local gtpos = string_match(src, "^%s*>()", after)
				if not gtpos then error(error_at(after, "Expected '>' after start tag", src), 2) end
				local node = { name = name, attrs = attrs, children = {}, text = nil }
				cur.children[#cur.children + 1] = node
				-- push current and descend
				stack[#stack + 1] = cur
				cur = node
				pos = gtpos
			end
		end
	end

	if #stack > 0 then
		return error(error_at(len, "Unclosed tags at end of document", src), 2)
	end

	return root
end

--- Escape text for serialization using precomputed lookup table.
---@param s string input The input string.
---@return string escaped The escaped string.
local function escape_text(s)
	if not s or s == "" then return "" end
	return (string_gsub(s, "[&<>]", _ESCAPE_MAP))
end

--- Serialize a node (root or element) back to XML string.
---@param node table node The node to serialize.
---@return string xml The XML string.
local function serialize_node(node)
	if node.cdata then
		return "<![CDATA[" .. node.cdata .. "]]>"
	end
	if not node.name then
		-- root: serialize children
		local out = {}
		for i = 1, #node.children do out[i] = serialize_node(node.children[i]) end
		return table_concat(out)
	end
	-- element
	local parts = {}
	parts[#parts + 1] = "<" .. node.name
	-- attributes (order not guaranteed)
	for k, v in next, node.attrs do
		-- minimal escaping for attribute values using localized map
		local val = string_gsub(v, "[&\"]", _ATTR_ESCAPE_MAP)
		val = string_gsub(val, "<", "&lt;")
		parts[#parts + 1] = string_format(' %s="%s"', k, val)
	end
	-- empty element?
	if (#node.children == 0 and (not node.text or node.text == "")) then
		parts[#parts + 1] = "/>"
		return table_concat(parts)
	end
	parts[#parts + 1] = ">"
	-- text
	if node.text and node.text ~= "" then
		parts[#parts + 1] = escape_text(node.text)
	end
	-- children
	for i = 1, #node.children do
		parts[#parts + 1] = serialize_node(node.children[i])
	end
	parts[#parts + 1] = "</" .. node.name .. ">"
	return table_concat(parts)
end

--- Parse an XML string and return a DOM-like table or nil plus error.
--- This function calls parse_node protected by pcall because parse_node may throw an error.
--- On success, returns the parsed table.
--- On failure (if parse_node throws), returns nil and an error message string.
---@param xmlString string XML document as a string.
---@return table|nil root The root node table on success, or nil on failure.
---@return string|nil err The error message on failure, or nil on success.
function XML.parse(xmlString)
	assert(type(xmlString) == "string")
	local ok, res = pcall(parse_node, xmlString)
	if not ok then return nil, res end
	return res
end

--- Serialize a parsed node (or root) back to an XML string.
---@param node table node The node returned by XML.parse.
---@return string xml The XML string.
---@return string|nil err The error message on bad input.
function XML.serialize(node)
	assert(type(node) == "table")
	return serialize_node(node)
end

--- Validate that an XML string is well-formed.
--- Returns true if well-formed, or false plus an error message.
---@param xmlString string XML document as a string.
---@return boolean ok True if well-formed.
---@return string|nil err The error message when not ok.
function XML.validate_well_formed(xmlString)
	assert(type(xmlString) == "string")
	local ok, res = pcall(parse_node, xmlString)
	if ok then return true end
	return false, res
end

--- Depth-first iterator over a parsed XML DOM.
--- Returns an iterator function suitable for use in generic for-loops.
--- Yields node and meta tables.
--- Options (opts table, all optional):
--- - `filter` (string) - "element" | "text" | "cdata" | "all" (default: "all")
--- - `withPath` (boolean) - include an XPath-like path string in meta.path (default: false)
--- - `includeRoot` (boolean) - include the root pseudo-node in iteration (default: false)
---@param root table root The DOM root returned by XML.parse.
---@param opts table|nil opts The iteration options.
---@return function iterator The iterator function for use in for-loops.
function XML.iterate(root, opts)
	opts = opts or {}
	local filter = opts.filter or "all"
	local withPath = opts.withPath or false
	local includeRoot = opts.includeRoot or false

	local function want(kind)
		if filter == "all" then return true end
		return filter == kind
	end

	-- Stack frames:
	-- { node = <element>, childIndex = <next child index to visit>, parent = <parent>, pathParts = <table>, indexInParent = <number>, _textYielded = <bool> }
	local stack = {}
	-- push root frame (root may be pseudo-node with name==nil)
	table_insert(stack, {
		node = root,
		childIndex = 1,
		parent = nil,
		pathParts = {},
		indexInParent = nil,
		_textYielded = false
	})

	-- iterator closure
	return function()
		while #stack > 0 do
			local frame = stack[#stack]
			local node = frame.node
			local i = frame.childIndex

			-- Yield the element node itself (first time we see the frame) if appropriate.
			if frame._elementYielded ~= true then
				frame._elementYielded = true
				if node.name ~= nil or includeRoot then
					if node.name ~= nil and want("element") then
						local meta = { type = "element", parent = frame.parent }
						if withPath then
							-- build path from pathParts; if indexInParent present, include it
							local parts = {}
							for k = 1, #frame.pathParts do parts[k] = frame.pathParts[k] end
							if frame.indexInParent then
								parts[#parts + 1] = "/" .. node.name .. "[" .. tostring(frame.indexInParent) .. "]"
							else
								parts[#parts + 1] = "/" .. node.name
							end
							meta.path = table_concat(parts)
							meta.index = frame.indexInParent
						end
						return node, meta
					end
				end
			end

			-- Yield text owned by this element (once) before children
			if node.text and node.text ~= "" and frame._textYielded ~= true then
				frame._textYielded = true
				if want("text") then
					local meta = { type = "text", parent = frame.parent }
					if withPath then
						local parts = {}
						for k = 1, #frame.pathParts do parts[k] = frame.pathParts[k] end
						if node.name then
							parts[#parts + 1] = "/" .. node.name
						else
							parts[#parts + 1] = "/"
						end
						meta.path = table_concat(parts)
					end
					-- return a lightweight text wrapper to distinguish from element nodes
					return { text = node.text }, meta
				end
			end

			-- Visit next child if any
			local children = node.children
			if children and i <= #children then
				local child = children[i]
				-- advance childIndex for next time
				frame.childIndex = i + 1

				-- CDATA node
				if type(child) == "table" and child.cdata ~= nil then
					if want("cdata") then
						local meta = { type = "cdata", parent = node, index = i }
						if withPath then
							local parts = {}
							for k = 1, #frame.pathParts do parts[k] = frame.pathParts[k] end
							if node.name then parts[#parts + 1] = "/" .. node.name end
							parts[#parts + 1] = "/text()"
							meta.path = table_concat(parts)
						end
						return child, meta
						--else
						--	-- skip CDATA and continue loop
					end
				else
					-- child is an element node; push new frame for it
					local childPathParts = {}
					for k = 1, #frame.pathParts do childPathParts[k] = frame.pathParts[k] end
					if node.name then
						-- compute index among previous siblings with same name
						local idx = 1
						for si = 1, i - 1 do
							local sib = children[si]
							if type(sib) == "table" and sib.name == child.name then idx = idx + 1 end
						end
						childPathParts[#childPathParts + 1] = "/" .. (child.name or "") .. "[" .. tostring(idx) .. "]"
						table_insert(stack,
							{
								node = child,
								childIndex = 1,
								parent = node,
								pathParts = childPathParts,
								indexInParent = idx,
								_textYielded = false
							})
					else
						childPathParts[#childPathParts + 1] = "/" .. (child.name or "")
						table_insert(stack, {
							node = child,
							childIndex = 1,
							parent = node,
							pathParts = childPathParts,
							indexInParent = i,
							_textYielded = false
						})
					end
					-- continue loop to process the newly pushed child frame
				end
			else
				-- no more children: pop this frame and continue
				table_remove(stack)
			end
		end
		-- iteration finished
		return nil
	end
end

-- Quick tests
if true then
	-- Test 1: Basic parsing with attributes
	-- Tests parsing a simple XML structure with nested elements and attributes,
	-- then serializes it back and validates well-formedness.
	do
		print("[xml] test start")

		local xml_str = "<root><item id=\"1\">Hello</item><item id=\"2\">World</item></root>"
		local root, err = XML.parse(xml_str)
		if not root then
			print("parse failed:", err); return
		end

		print("[xml] parsed root children:", #root.children)
		for i = 1, #root.children do
			local child = root.children[i]
			print(string_format("child %d: name=%s attrs.id=%s text=%s", i, child.name, child.attrs.id, child.text))
		end

		local serialized = XML.serialize(root)
		print("[xml] serialized:", serialized)

		local ok, err = XML.validate_well_formed(xml_str)
		print("[xml] validate_well_formed:", ok, err)
	end

	-- Test 2: Nested elements with path iteration
	-- Tests parsing nested XML structures and iterating with XPath-like paths.
	-- Demonstrates the withPath option to track element locations.
	do
		local xml_str = [[
			<config>
				<database host="localhost" port="3306">
					<name>mydb</name>
					<user>admin</user>
				</database>
				<settings debug="true">
					<theme>dark</theme>
				</settings>
			</config>
		]]

		local root, err = XML.parse(xml_str)
		if not root then
			print("parse failed:", err); return
		end

		print("[xml] test2 - iterating with path:")
		for node, meta in XML.iterate(root, { withPath = true, filter = "element" }) do
			print(string_format("  %s - name=%s", meta.path or "?", node.name or "(root)"))
		end

		local serialized = XML.serialize(root)
		print("[xml] test2 - serialized length:", #serialized)
	end

	-- Test 3: Special characters, CDATA, comments, and empty elements
	-- Tests parsing XML with entity references (&lt;, &gt;, &amp;), CDATA sections,
	-- comments, and self-closing empty elements. Iterates over all node types.
	do
		local xml_str = [=[
			<data>
				<text>Special chars: &lt; &gt; &amp;</text>
				<binary><![CDATA[Some raw data: \0\1\2]]></binary>
				<!-- This is a comment -->
				<empty attr="value"/>
			</data>
		]=]

		local root, err = XML.parse(xml_str)
		if not root then
			print("parse failed:", err); return
		end

		print("[xml] test3 - iterating all node types:")
		for node, meta in XML.iterate(root, { filter = "all" }) do
			if meta.type == "element" then
				print(string_format("  element: %s attrs=%d", node.name, #node.attrs))
			elseif meta.type == "text" then
				print(string_format("  text: %s", node.text))
			elseif meta.type == "cdata" then
				print(string_format("  cdata: %s", node.cdata))
			end
		end

		local serialized = XML.serialize(root)
		print("[xml] test3 - serialized:\n" .. serialized)
	end

	-- Test 4: Namespaces
	do
		local xml_str =
		'<root xmlns:ns1="http://example.com/ns1"><ns1:element ns1:attr="value">Text</ns1:element></root>'
		local root, err = XML.parse(xml_str)
		if not root then
			print("[xml] test4 parse failed:", err); return
		end
		print("[xml] test4 - namespaces parsed successfully")
		local child = root.children[1]
		print(string_format("  element name: %s, attr: %s", child.name, child.attrs["ns1:attr"]))
	end

	-- Test 5: Self-closing tags
	do
		local xml_str = '<root><item id="1"/><item id="2"/><item id="3"/></root>'
		local root, err = XML.parse(xml_str)
		if not root then
			print("[xml] test5 parse failed:", err); return
		end
		print("[xml] test5 - self-closing tags, children:", #root.children[1].children)
		for i = 1, #root.children[1].children do
			print(string_format("  item %d: attrs.id=%s", i, root.children[1].children[i].attrs.id))
		end
	end

	-- Test 6: Mixed content
	do
		local xml_str = '<p>Hello <b>world</b>! This is <i>mixed</i> content.</p>'
		local root, err = XML.parse(xml_str)
		if not root then
			print("[xml] test6 parse failed:", err); return
		end
		print("[xml] test6 - mixed content")
		for node, meta in XML.iterate(root, { filter = "all" }) do
			if meta.type == "text" and node.text and node.text:match("%S") then
				print(string_format("  text: '%s'", node.text))
			elseif meta.type == "element" then
				print(string_format("  element: %s", node.name))
			end
		end
	end

	-- Test 7: Multiple attributes with special characters
	do
		local xml_str = '<item id="123" name="Test &amp; Demo" desc="Quote: &quot;hello&quot;" enabled="true"/>'
		local root, err = XML.parse(xml_str)
		if not root then
			print("[xml] test7 parse failed:", err); return
		end
		print("[xml] test7 - attributes with special chars")
		local item = root.children[1]
		print(string_format("  id=%s, name=%s, desc=%s, enabled=%s",
			item.attrs.id, item.attrs.name, item.attrs.desc, item.attrs.enabled))
	end

	-- Test 8: Error handling - malformed XML
	do
		local xml_str = '<root><item>Unclosed tag</root>'
		local ok, err = XML.validate_well_formed(xml_str)
		print(string_format("[xml] test8 - malformed XML validation: ok=%s, err=%s", tostring(ok), err or "nil"))
	end

	-- Test 9: Error handling - mismatched tags
	do
		local xml_str = '<root><item></different></root>'
		local ok, err = XML.validate_well_formed(xml_str)
		print(string_format("[xml] test9 - mismatched tags validation: ok=%s, err=%s", tostring(ok), err or "nil"))
	end

	-- Test 10: Processing instruction
	do
		local xml_str = '<?xml version="1.0" encoding="UTF-8"?><root><item>Test</item></root>'
		local root, err = XML.parse(xml_str)
		if not root then
			print("[xml] test10 parse failed:", err); return
		end
		print("[xml] test10 - processing instruction parsed successfully")
	end

	-- Test 11: Numeric entities
	do
		local xml_str = '<root>&#65;&#x42;&lt;</root>'
		local root, err = XML.parse(xml_str)
		if not root then
			print("[xml] test11 parse failed:", err); return
		end
		print(string_format("[xml] test11 - numeric entities decoded: '%s'", root.children[1].text))
	end

	-- Test 12: Deep nesting
	do
		local xml_str = '<a><b><c><d><e><f>deep</f></e></d></c></b></a>'
		local root, err = XML.parse(xml_str)
		if not root then
			print("[xml] test12 parse failed:", err); return
		end
		print("[xml] test12 - deep nesting parsed successfully")
		local depth = 0
		for node, meta in XML.iterate(root, { filter = "element", withPath = true }) do
			local path_depth = 0
			for _ in meta.path:gmatch("/") do
				path_depth = path_depth + 1
			end
			depth = math.max(depth, path_depth)
		end
		print(string_format("  max depth: %d", depth))
	end

	-- Test 13: Whitespace preservation
	do
		local xml_str = '<root>  <item>  text  </item>  </root>'
		local root, err = XML.parse(xml_str)
		if not root then
			print("[xml] test13 parse failed:", err); return
		end
		print("[xml] test13 - whitespace preservation")
		print(string_format("  root text: '%s'", root.children[1].text or "(nil)"))
		print(string_format("  item text: '%s'", root.children[1].children[1].text))
	end

	-- Test 14: Empty document
	do
		local xml_str = ''
		local ok, err = XML.validate_well_formed(xml_str)
		print(string_format("[xml] test14 - empty document: ok=%s", tostring(ok)))
	end

	-- Test 15: Attribute with no value (malformed)
	do
		local xml_str = '<root item="test" disabled/></root>'
		local ok, err = XML.validate_well_formed(xml_str)
		print(string_format("[xml] test15 - attribute validation: ok=%s", tostring(ok)))
	end
end

-- Export
return XML
