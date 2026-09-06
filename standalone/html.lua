-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- HTML/XML Parser.
-- Returns a DOM-like tree structure.
--
-- Node shape:
-- {
--   type = "document" | "element" | "text" | "comment" | "cdata" | "doctype" | "pi",
--   tag = string,          -- for element/doctype/pi
--   attrs = table,         -- for element
--   attr_order = table,    -- optional stable attribute order
--   children = table,      -- for document/element
--   content = string,      -- for text/comment/cdata/doctype/pi
--   raw = boolean,         -- for text nodes that should not be escaped
--   self_closing = boolean,-- for element nodes like <br/>
--   void = boolean,        -- for HTML void elements like <br>
-- }

local HTMLParser = {}

-- HTML void elements: no closing tag in normal HTML.
HTMLParser.void_elements = {
	area = true,
	base = true,
	br = true,
	col = true,
	command = true,
	embed = true,
	hr = true,
	img = true,
	input = true,
	keygen = true,
	link = true,
	meta = true,
	param = true,
	source = true,
	track = true,
	wbr = true,
}

-- Elements whose contents are raw text and should not be parsed as HTML.
HTMLParser.raw_text_elements = {
	script = true,
	style = true,
}

----------------------------------------------------------------------
-- Basic utilities
----------------------------------------------------------------------

local function codepoint_to_utf8(cp)
	if type(cp) ~= "number" or cp < 0 or cp > 0x10FFFF then
		return "?"
	end

	-- UTF-16 surrogate range is invalid for UTF-8 conversion.
	if cp >= 0xD800 and cp <= 0xDFFF then
		return "?"
	end

	if cp < 0x80 then
		return string.char(cp)
	elseif cp < 0x800 then
		return string.char(
			0xC0 + math.floor(cp / 0x40),
			0x80 + (cp % 0x40)
		)
	elseif cp < 0x10000 then
		return string.char(
			0xE0 + math.floor(cp / 0x1000),
			0x80 + (math.floor(cp / 0x40) % 0x40),
			0x80 + (cp % 0x40)
		)
	else
		return string.char(
			0xF0 + math.floor(cp / 0x40000),
			0x80 + (math.floor(cp / 0x1000) % 0x40),
			0x80 + (math.floor(cp / 0x40) % 0x40),
			0x80 + (cp % 0x40)
		)
	end
end

local named_entities = {
	amp = "&",
	lt = "<",
	gt = ">",
	quot = '"',
	apos = "'",

	nbsp = codepoint_to_utf8(160),
	copy = codepoint_to_utf8(169),
	reg = codepoint_to_utf8(174),
	trade = codepoint_to_utf8(8482),

	hellip = codepoint_to_utf8(8230),
	mdash = codepoint_to_utf8(8212),
	ndash = codepoint_to_utf8(8211),

	laquo = codepoint_to_utf8(171),
	raquo = codepoint_to_utf8(187),
	ldquo = codepoint_to_utf8(8220),
	rdquo = codepoint_to_utf8(8221),
	lsquo = codepoint_to_utf8(8216),
	rsquo = codepoint_to_utf8(8217),

	bull = codepoint_to_utf8(8226),
	middot = codepoint_to_utf8(183),

	times = codepoint_to_utf8(215),
	divide = codepoint_to_utf8(247),
	deg = codepoint_to_utf8(176),
	plusmn = codepoint_to_utf8(177),

	frac12 = codepoint_to_utf8(189),
	frac14 = codepoint_to_utf8(188),
	frac34 = codepoint_to_utf8(190),

	iexcl = codepoint_to_utf8(161),
	iquest = codepoint_to_utf8(191),
	sect = codepoint_to_utf8(167),
	para = codepoint_to_utf8(182),
	micro = codepoint_to_utf8(181),

	sup2 = codepoint_to_utf8(178),
	sup3 = codepoint_to_utf8(179),
	acute = codepoint_to_utf8(180),
	grave = codepoint_to_utf8(96),
	uml = codepoint_to_utf8(168),
	szlig = codepoint_to_utf8(223),

	yen = codepoint_to_utf8(165),
	pound = codepoint_to_utf8(163),
	cent = codepoint_to_utf8(162),
	euro = codepoint_to_utf8(8364),
}

local function trim(s)
	if type(s) ~= "string" then
		return ""
	end
	return (s:match("^%s*(.-)%s*$"))
end

function HTMLParser.escape_text(s)
	if type(s) ~= "string" then
		s = tostring(s or "")
	end

	s = s:gsub("&", "&amp;")
	s = s:gsub("<", "&lt;")
	s = s:gsub(">", "&gt;")
	return s
end

function HTMLParser.escape_attr(s)
	if type(s) ~= "string" then
		s = tostring(s or "")
	end

	s = s:gsub("&", "&amp;")
	s = s:gsub("<", "&lt;")
	s = s:gsub(">", "&gt;")
	s = s:gsub('"', "&quot;")
	s = s:gsub("'", "&#39;")
	return s
end

local function decode_entities(s)
	if type(s) ~= "string" or s == "" or not s:find("&", 1, true) then
		return s
	end

	-- Hex numeric entities: &#x41; &#X41;
	s = s:gsub("&#x(%x+);", function(hex)
		local cp = tonumber(hex, 16)
		return cp and codepoint_to_utf8(cp) or ""
	end)

	s = s:gsub("&#X(%x+);", function(hex)
		local cp = tonumber(hex, 16)
		return cp and codepoint_to_utf8(cp) or ""
	end)

	-- Decimal numeric entities: &#65;
	s = s:gsub("&#(%d+);", function(dec)
		local cp = tonumber(dec, 10)
		return cp and codepoint_to_utf8(cp) or ""
	end)

	-- Named entities.
	s = s:gsub("&(%a+);", function(name)
		local val = named_entities[name] or named_entities[name:lower()]
		if val then
			return val
		end
		-- Unknown entities are preserved as literal text.
		return "&" .. name .. ";"
	end)

	return s
end

HTMLParser.decode_entities = decode_entities

----------------------------------------------------------------------
-- Parsing helpers
----------------------------------------------------------------------

-- Build a Lua pattern fragment for a tag name.
-- If case_insensitive is true, ASCII letters match both cases.
local function tag_pattern(tag, case_insensitive)
	local out = {}

	for i = 1, #tag do
		local c = tag:sub(i, i)

		if case_insensitive and c:match("%a") then
			out[#out + 1] = "[" .. c:lower() .. c:upper() .. "]"
		elseif c:match("%w") then
			out[#out + 1] = c
		else
			out[#out + 1] = "%" .. c
		end
	end

	return table.concat(out)
end

-- Safely find the end of a tag, ignoring '>' inside quoted attribute values.
local function find_tag_end(html, pos)
	local in_quote

	for i = pos + 1, #html do
		local c = html:sub(i, i)

		if in_quote then
			if c == in_quote then
				in_quote = nil
			end
		else
			if c == '"' or c == "'" then
				in_quote = c
			elseif c == ">" then
				return i
			end
		end
	end

	return nil
end

local function parse_attrs(rest, opts)
	local attrs = {}
	local order = {}

	local pos = 1
	local len = #rest

	while pos <= len do
		-- Skip whitespace.
		local _, ws_end = rest:find("^%s+", pos)
		if ws_end then
			pos = ws_end + 1
		end

		if pos > len then
			break
		end

		-- Broad attribute-name support:
		-- normal HTML/XML names, @click, (click), [attr], *ngIf, etc.
		local _, key_end, key = rest:find("^([^%s=>/]+)", pos)

		if not key then
			-- Skip stray character to avoid infinite loops.
			pos = pos + 1
		else
			pos = key_end + 1

			if opts.lower_case_attrs then
				key = key:lower()
			end

			-- Skip whitespace before optional '='.
			local _, ws_end2 = rest:find("^%s+", pos)
			if ws_end2 then
				pos = ws_end2 + 1
			end

			local value = true

			if pos <= len and rest:sub(pos, pos) == "=" then
				pos = pos + 1

				-- Skip whitespace after '='.
				local _, ws_end3 = rest:find("^%s+", pos)
				if ws_end3 then
					pos = ws_end3 + 1
				end

				local quote = rest:sub(pos, pos)

				if quote == '"' or quote == "'" then
					local close = rest:find(quote, pos + 1, true)
					if close then
						value = rest:sub(pos + 1, close - 1)
						pos = close + 1
					else
						-- Unclosed quoted value: consume the rest.
						value = rest:sub(pos + 1)
						pos = len + 1
					end
				else
					-- Unquoted value.
					local _, val_end, val = rest:find("^([^%s>]+)", pos)
					if val then
						value = val
						pos = val_end + 1
					else
						value = ""
					end
				end

				if opts.decode_entities and type(value) == "string" then
					value = decode_entities(value)
				end
			end

			if attrs[key] == nil then
				order[#order + 1] = key
			end

			-- Last duplicate wins, but original first position is preserved.
			attrs[key] = value
		end
	end

	return attrs, order
end

local function parse_tag(tag_str, opts)
	if type(tag_str) ~= "string" or #tag_str < 2 then
		return nil
	end

	if tag_str:sub(1, 1) ~= "<" then
		return nil
	end

	----------------------------------------------------------------------
	-- Closing tag: </tag>
	----------------------------------------------------------------------
	if tag_str:sub(1, 2) == "</" then
		local inner = tag_str:sub(3, -2)

		local _, _, tag_name = inner:find("^%s*([%a_:][%w:%-_%.]*)")
		if not tag_name then
			return nil
		end

		if opts.lower_case_tags then
			tag_name = tag_name:lower()
		end

		return tag_name, {}, true, false, "element"
	end

	----------------------------------------------------------------------
	-- Processing instruction: <?target content?>
	----------------------------------------------------------------------
	if tag_str:sub(1, 2) == "<?" then
		local inner = tag_str:sub(3)

		if inner:sub(-2) == "?>" then
			inner = inner:sub(1, -3)
		elseif inner:sub(-1) == ">" then
			inner = inner:sub(1, -2)
		end

		local _, name_end, tag_name = inner:find("^%s*([%a_][%w:%-_%.]*)")
		if not tag_name then
			tag_name = "xml"
			name_end = 0
		elseif opts.lower_case_tags then
			tag_name = tag_name:lower()
		end

		local content = trim(inner:sub(name_end + 1))
		return tag_name, {}, false, false, "pi", content
	end

	----------------------------------------------------------------------
	-- Declaration / DOCTYPE / ENTITY etc.: <!...>
	----------------------------------------------------------------------
	if tag_str:sub(1, 2) == "<!" then
		local inner = tag_str:sub(3, -2)

		local _, name_end, tag_name = inner:find("^%s*([%a][%w%-]*)")
		if not tag_name then
			tag_name = "DOCTYPE"
			name_end = 0
		else
			tag_name = tag_name:upper()
		end

		local content = trim(inner:sub(name_end + 1))
		return tag_name, {}, false, false, "doctype", content
	end

	----------------------------------------------------------------------
	-- Normal opening tag: <tag ...>
	----------------------------------------------------------------------
	local inner = tag_str:sub(2, -2)
	local is_self_closing = false

	if inner:sub(-1) == "/" then
		is_self_closing = true
		inner = inner:sub(1, -2)
	end

	local _, name_end, tag_name = inner:find("^%s*([%a_:][%w:%-_%.]*)")
	if not tag_name then
		return nil
	end

	if opts.lower_case_tags then
		tag_name = tag_name:lower()
	end

	local rest = inner:sub(name_end + 1)
	local attrs, order = parse_attrs(rest, opts)

	return tag_name, attrs, false, is_self_closing, "element", nil, order
end

-- Find the closing tag for raw-text elements like <script> and <style>.
-- This requires an actual closing tag, not just a prefix.
local function find_raw_text_end(html, pos, tag_name, opts)
	local pattern = "</%s*"
		.. tag_pattern(tag_name, opts.lower_case_tags)
		.. "%s*/?%s*>"

	return html:find(pattern, pos)
end

local function add_text(nodes, text, opts)
	if text == nil or text == "" then
		return
	end

	local raw = not opts.decode_entities

	if opts.decode_entities then
		text = decode_entities(text)
	end

	local last = nodes[#nodes]

	if last and last.type == "text" and last.raw == raw then
		last.content = last.content .. text
	else
		table.insert(nodes, {
			type = "text",
			content = text,
			raw = raw,
		})
	end
end

local function has_ancestor(ancestors, tag_name)
	for i = #ancestors, 1, -1 do
		if ancestors[i] == tag_name then
			return true
		end
	end
	return false
end

----------------------------------------------------------------------
-- Core recursive parser
----------------------------------------------------------------------

local parse_nodes

parse_nodes = function(html, pos, parent_tag, ancestors, opts)
	local nodes = {}

	while pos <= #html do
		local start = html:find("<", pos, true)

		if not start then
			add_text(nodes, html:sub(pos), opts)
			return nodes, #html + 1
		end

		if start > pos then
			add_text(nodes, html:sub(pos, start - 1), opts)
		end

		pos = start

		----------------------------------------------------------------------
		-- Comment
		----------------------------------------------------------------------
		if html:sub(pos, pos + 3) == "<!--" then
			local end_pos = html:find("-->", pos + 4, true)

			if end_pos then
				if opts.include_comments then
					table.insert(nodes, {
						type = "comment",
						content = html:sub(pos + 4, end_pos - 1),
					})
				end

				pos = end_pos + 3
			else
				add_text(nodes, html:sub(pos), opts)
				return nodes, #html + 1
			end

			----------------------------------------------------------------------
			-- CDATA
			----------------------------------------------------------------------
		elseif html:sub(pos, pos + 8) == "<![CDATA[" then
			local end_pos = html:find("]]>", pos + 9, true)

			if end_pos then
				if opts.include_cdata then
					table.insert(nodes, {
						type = "cdata",
						content = html:sub(pos + 9, end_pos - 1),
					})
				end

				pos = end_pos + 3
			else
				add_text(nodes, html:sub(pos), opts)
				return nodes, #html + 1
			end

			----------------------------------------------------------------------
			-- Tag-like content
			----------------------------------------------------------------------
		else
			local tag_end = find_tag_end(html, pos)

			if not tag_end then
				add_text(nodes, html:sub(pos), opts)
				return nodes, #html + 1
			end

			local tag_str = html:sub(pos, tag_end)

			local tag_name, attrs, is_closing, is_self_closing, tag_type, content, attr_order =
				parse_tag(tag_str, opts)

			if not tag_name then
				-- Probably a bare '<' in text, e.g. "1 < 2".
				add_text(nodes, "<", opts)
				pos = pos + 1
			elseif tag_type == "doctype" or tag_type == "pi" then
				local include = true

				if tag_type == "doctype" and not opts.include_doctype then
					include = false
				end

				if tag_type == "pi" and not opts.include_pi then
					include = false
				end

				if include then
					table.insert(nodes, {
						type = tag_type,
						tag = tag_name,
						content = content or "",
						attrs = attrs or {},
					})
				end

				pos = tag_end + 1
			elseif is_closing then
				if tag_name == parent_tag then
					return nodes, tag_end + 1
				elseif has_ancestor(ancestors, tag_name) then
					-- Let the matching ancestor consume this closing tag.
					-- This recovers from misnested markup like <b><i></b></i>.
					return nodes, start
				else
					if opts.strict then
						return error("Unexpected closing tag </" .. tag_name .. "> at position " .. tostring(pos))
					end

					-- Unmatched closing tag: ignore.
					pos = tag_end + 1
				end
			else
				local node = {
					type = "element",
					tag = tag_name,
					attrs = attrs or {},
					attr_order = attr_order or {},
					children = {},
				}

				if is_self_closing then
					node.self_closing = true
				end

				if not opts.decode_entities then
					node.attr_raw = true
				end

				pos = tag_end + 1

				local is_void = opts.html_void
					and opts.void_elements
					and opts.void_elements[tag_name]

				if is_self_closing or is_void then
					if is_void then
						node.void = true
					end

					table.insert(nodes, node)
				elseif opts.raw_text_elements and opts.raw_text_elements[tag_name] then
					local close_start, close_end = find_raw_text_end(html, pos, tag_name, opts)

					if close_start then
						local text_content = html:sub(pos, close_start - 1)

						if text_content ~= "" then
							table.insert(node.children, {
								type = "text",
								content = text_content,
								raw = true,
							})
						end

						pos = close_end + 1
					else
						local text_content = html:sub(pos)

						if text_content ~= "" then
							table.insert(node.children, {
								type = "text",
								content = text_content,
								raw = true,
							})
						end

						pos = #html + 1
					end

					table.insert(nodes, node)
				else
					table.insert(ancestors, tag_name)

					local children, new_pos = parse_nodes(html, pos, tag_name, ancestors, opts)

					table.remove(ancestors)

					node.children = children
					pos = new_pos

					table.insert(nodes, node)
				end
			end
		end
	end

	return nodes, pos
end

----------------------------------------------------------------------
-- Public parse API
----------------------------------------------------------------------

local function build_options(options)
	local opts = {
		-- HTML is case-insensitive by default.
		lower_case_tags = true,
		lower_case_attrs = false,

		-- Decode entities in normal text and attribute values.
		-- Raw-text elements like <script> and <style> are never decoded.
		decode_entities = true,

		include_comments = true,
		include_cdata = true,
		include_doctype = true,
		include_pi = true,

		-- Treat HTML void elements as self-contained.
		html_void = true,

		-- If true, unexpected closing tags raise errors.
		strict = false,

		void_elements = HTMLParser.void_elements,
		raw_text_elements = HTMLParser.raw_text_elements,
	}

	if type(options) == "table" then
		for k, v in pairs(options) do
			opts[k] = v
		end
	end

	-- XML mode defaults: preserve case and do not use HTML void rules.
	if opts.xml then
		if type(options) ~= "table" or options.lower_case_tags == nil then
			opts.lower_case_tags = false
		end

		if type(options) ~= "table" or options.html_void == nil then
			opts.html_void = false
		end
	end

	return opts
end

function HTMLParser.parse(html, options)
	if type(html) ~= "string" then
		return nil, "html must be a string"
	end

	local opts = build_options(options)
	local nodes = parse_nodes(html, 1, nil, {}, opts)

	return {
		type = "document",
		children = nodes,
	}
end

----------------------------------------------------------------------
-- Serializer
----------------------------------------------------------------------

local function attr_keys(node)
	local seen = {}
	local keys = {}

	if type(node.attr_order) == "table" then
		for _, k in ipairs(node.attr_order) do
			if node.attrs and node.attrs[k] ~= nil and not seen[k] then
				seen[k] = true
				keys[#keys + 1] = k
			end
		end
	end

	local extra = {}

	if type(node.attrs) == "table" then
		for k in pairs(node.attrs) do
			if not seen[k] then
				extra[#extra + 1] = k
			end
		end
	end

	table.sort(extra)

	for _, k in ipairs(extra) do
		keys[#keys + 1] = k
	end

	return keys
end

local function serialize_attrs(node)
	local parts = {}
	local keys = attr_keys(node)

	for _, k in ipairs(keys) do
		local v = node.attrs and node.attrs[k]

		if v ~= nil and v ~= false then
			if v == true then
				parts[#parts + 1] = " " .. k
			else
				local sval = tostring(v)

				if node.attr_raw then
					-- Preserve raw attribute markup, but still make it safe
					-- for double-quoted output.
					sval = sval:gsub('"', "&quot;")
				else
					sval = HTMLParser.escape_attr(sval)
				end

				parts[#parts + 1] = string.format(' %s="%s"', k, sval)
			end
		end
	end

	return table.concat(parts)
end

local function is_text_only(node)
	if not node.children or #node.children == 0 then
		return false
	end

	for _, child in ipairs(node.children) do
		if child.type ~= "text" then
			return false
		end
	end

	return true
end

local serialize_node

serialize_node = function(node, indent, level, opts)
	indent = indent or ""
	level = level or 0
	opts = opts or {}

	local pad = (indent ~= "") and string.rep(indent, level) or ""
	local nl = (indent ~= "") and "\n" or ""

	if node.type == "document" then
		local parts = {}

		for _, child in ipairs(node.children or {}) do
			parts[#parts + 1] = serialize_node(child, indent, level, opts)
		end

		return table.concat(parts, nl)
	elseif node.type == "element" then
		local children = node.children or {}
		local parts = { pad, "<", node.tag, serialize_attrs(node) }

		local void = (#children == 0)
			and (node.void or HTMLParser.void_elements[node.tag])

		local self_close = (#children == 0) and node.self_closing

		if #children == 0 and (self_close or void or opts.xml_empty) then
			if self_close or opts.xml or opts.xml_empty then
				parts[#parts + 1] = " />"
			else
				parts[#parts + 1] = ">"
			end

			return table.concat(parts)
		end

		parts[#parts + 1] = ">"

		-- Render text-only elements inline, even when pretty printing.
		if is_text_only(node) then
			local text_parts = {}

			for _, child in ipairs(children) do
				if child.raw then
					text_parts[#text_parts + 1] = child.content or ""
				else
					text_parts[#text_parts + 1] = HTMLParser.escape_text(child.content or "")
				end
			end

			parts[#parts + 1] = table.concat(text_parts)
			parts[#parts + 1] = "</" .. node.tag .. ">"

			return table.concat(parts)
		end

		if #children > 0 then
			if nl ~= "" then
				parts[#parts + 1] = nl
			end

			local inner = {}

			for _, child in ipairs(children) do
				inner[#inner + 1] = serialize_node(child, indent, level + 1, opts)
			end

			parts[#parts + 1] = table.concat(inner, nl)

			if nl ~= "" then
				parts[#parts + 1] = nl .. pad
			end
		end

		parts[#parts + 1] = "</" .. node.tag .. ">"

		return table.concat(parts)
	elseif node.type == "text" then
		if node.raw then
			return pad .. (node.content or "")
		end

		return pad .. HTMLParser.escape_text(node.content or "")
	elseif node.type == "comment" then
		return pad .. "<!--" .. (node.content or "") .. "-->"
	elseif node.type == "cdata" then
		return pad .. "<![CDATA[" .. (node.content or "") .. "]]>"
	elseif node.type == "doctype" then
		local tag = node.tag or "DOCTYPE"

		if node.content and node.content ~= "" then
			return pad .. "<!" .. tag .. " " .. node.content .. ">"
		end

		return pad .. "<!" .. tag .. ">"
	elseif node.type == "pi" then
		local tag = node.tag or "xml"

		if node.content and node.content ~= "" then
			return pad .. "<?" .. tag .. " " .. node.content .. "?>"
		end

		return pad .. "<?" .. tag .. "?>"
	end

	return ""
end

function HTMLParser.stringify(node, indent, options)
	if not node then
		return ""
	end

	if type(indent) == "table" and options == nil then
		options = indent
		indent = ""
	end

	return serialize_node(node, indent or "", 0, options or {})
end

HTMLParser.to_html = HTMLParser.stringify

----------------------------------------------------------------------
-- Query / traversal utilities
----------------------------------------------------------------------

function HTMLParser.get_text(node, sep)
	local buf = {}

	local function collect(n)
		if not n then
			return
		end

		if n.type == "text" or n.type == "cdata" then
			if n.content then
				buf[#buf + 1] = n.content
			end
		elseif n.children then
			for _, child in ipairs(n.children) do
				collect(child)
			end
		end
	end

	collect(node)

	return table.concat(buf, sep or "")
end

function HTMLParser.walk(node, fn, depth)
	if not node then
		return true
	end

	depth = depth or 0

	if fn(node, depth) == false then
		return false
	end

	if node.children then
		for _, child in ipairs(node.children) do
			if HTMLParser.walk(child, fn, depth + 1) == false then
				return false
			end
		end
	end

	return true
end

local function to_predicate(predicate)
	if type(predicate) == "function" then
		return predicate
	end

	if type(predicate) == "string" then
		local tag = predicate:lower()

		return function(node)
			return node.type == "element"
				and node.tag
				and node.tag:lower() == tag
		end
	end

	return function()
		return false
	end
end

function HTMLParser.find(node, predicate)
	local pred = to_predicate(predicate)
	local found

	HTMLParser.walk(node, function(n, depth)
		if depth > 0 and pred(n, depth) then
			found = n
			return false
		end
	end)

	return found
end

function HTMLParser.find_all(node, predicate)
	local pred = to_predicate(predicate)
	local results = {}

	HTMLParser.walk(node, function(n, depth)
		if depth > 0 and pred(n, depth) then
			results[#results + 1] = n
		end
	end)

	return results
end

function HTMLParser.find_by_tag(node, tag)
	local wanted = type(tag) == "string" and tag:lower() or tag

	return HTMLParser.find(node, function(n)
		return n.type == "element"
			and n.tag
			and n.tag:lower() == wanted
	end)
end

function HTMLParser.find_all_by_tag(node, tag)
	local wanted = type(tag) == "string" and tag:lower() or tag

	return HTMLParser.find_all(node, function(n)
		return n.type == "element"
			and n.tag
			and n.tag:lower() == wanted
	end)
end

function HTMLParser.find_by_attr(node, attr, value)
	return HTMLParser.find(node, function(n)
		if n.type ~= "element" or type(n.attrs) ~= "table" then
			return false
		end

		if value == nil then
			return n.attrs[attr] ~= nil
		end

		return n.attrs[attr] == value
	end)
end

function HTMLParser.find_all_by_attr(node, attr, value)
	return HTMLParser.find_all(node, function(n)
		if n.type ~= "element" or type(n.attrs) ~= "table" then
			return false
		end

		if value == nil then
			return n.attrs[attr] ~= nil
		end

		return n.attrs[attr] == value
	end)
end

-- Very small selector engine:
-- Supports: tag, *, #id, .class, [attr], [attr=value], [attr="value"]
-- Compound selectors like div.class#id[attr=value] are supported.
-- Descendant/child combinators are not supported.
local function selector_predicate(selector)
	local sel = trim(selector or "")

	if sel == "" or sel == "*" then
		return function(node)
			return node.type == "element"
		end
	end

	local tag = sel:match("^([%w%-]+)")
	local id = sel:match("#([%w%-_]+)")
	local class = sel:match("%.([%w%-_]+)")

	local attr, val, attr_exists

	local bracket = sel:match("%[([^%]]+)%]")
	if bracket then
		local a, v = bracket:match("^([%w:%-_@]+)%s*=%s*(.+)$")

		if a then
			attr = a
			v = trim(v)

			local quoted = v:match("^['\"](.*)['\"]$")
			val = quoted or v
		else
			attr_exists = bracket:match("^([%w:%-_@]+)$")
		end
	end

	return function(node)
		if node.type ~= "element" then
			return false
		end

		local attrs = node.attrs or {}

		if tag and (not node.tag or node.tag:lower() ~= tag:lower()) then
			return false
		end

		if id and attrs.id ~= id then
			return false
		end

		if class then
			local class_attr = attrs.class

			if type(class_attr) ~= "string" then
				return false
			end

			local found = false

			for token in class_attr:gmatch("%S+") do
				if token == class then
					found = true
					break
				end
			end

			if not found then
				return false
			end
		end

		if attr and attrs[attr] ~= val then
			return false
		end

		if not attr and attr_exists and attrs[attr_exists] == nil then
			return false
		end

		return true
	end
end

function HTMLParser.query(node, selector)
	return HTMLParser.find_all(node, selector_predicate(selector))
end

function HTMLParser.query_one(node, selector)
	return HTMLParser.find(node, selector_predicate(selector))
end

function HTMLParser.clone(node)
	if type(node) ~= "table" then
		return node
	end

	local copy = {}

	for k, v in pairs(node) do
		copy[k] = HTMLParser.clone(v)
	end

	return copy
end

----------------------------------------------------------------------
-- Tests
----------------------------------------------------------------------

function HTMLParser.run_tests()
	local passed = 0

	local function check(condition, message)
		assert(condition, message)
		passed = passed + 1
	end

	----------------------------------------------------------------------
	-- Escaping and entity decoding
	----------------------------------------------------------------------

	check(
		HTMLParser.escape_text("a & b < c > d") == "a &amp; b &lt; c &gt; d",
		"escape_text failed"
	)

	check(
		HTMLParser.escape_attr("a & \" < > '") == "a &amp; &quot; &lt; &gt; &#39;",
		"escape_attr failed"
	)

	check(
		HTMLParser.decode_entities("&amp;&lt;&gt;&quot;&#39;") == "&<>\"'",
		"decode_entities basic failed"
	)

	check(
		HTMLParser.decode_entities("&#65;&#x42;&#X43;") == "ABC",
		"decode_entities numeric failed"
	)

	check(
		HTMLParser.decode_entities("&unknown;") == "&unknown;",
		"decode_entities unknown failed"
	)

	----------------------------------------------------------------------
	-- Basic parsing
	----------------------------------------------------------------------

	local doc = HTMLParser.parse("<p>Hello</p>")

	check(doc and doc.type == "document", "document root missing")
	check(#doc.children == 1, "expected one child")

	local p = doc.children[1]

	check(p.type == "element" and p.tag == "p", "expected <p> element")
	check(
		#p.children == 1
		and p.children[1].type == "text"
		and p.children[1].content == "Hello",
		"expected text child"
	)

	check(
		HTMLParser.stringify(doc) == "<p>Hello</p>",
		"basic roundtrip failed"
	)

	local nil_doc, err = HTMLParser.parse(nil)
	check(
		nil_doc == nil and err == "html must be a string",
		"non-string input should fail"
	)

	doc = HTMLParser.parse("")
	check(
		doc.type == "document" and #doc.children == 0,
		"empty input should produce empty document"
	)
	check(
		HTMLParser.stringify(doc) == "",
		"empty document should stringify to empty string"
	)

	----------------------------------------------------------------------
	-- Entities in text
	----------------------------------------------------------------------

	doc = HTMLParser.parse("<p>a &amp; b &lt;tag&gt;</p>")

	check(
		doc.children[1].children[1].content == "a & b <tag>",
		"text entity decoding failed"
	)

	check(
		HTMLParser.stringify(doc) == "<p>a &amp; b &lt;tag&gt;</p>",
		"text entity roundtrip failed"
	)

	----------------------------------------------------------------------
	-- Attributes
	----------------------------------------------------------------------

	doc = HTMLParser.parse('<a href="/foo" disabled data-x="1" title=\'single\'>link</a>')
	local a = doc.children[1]

	check(a.attrs.href == "/foo", "attr href failed")
	check(a.attrs.disabled == true, "boolean attr failed")
	check(a.attrs["data-x"] == "1", "attr data-x failed")
	check(a.attrs.title == "single", "single-quoted attr failed")

	check(
		a.attr_order[1] == "href"
		and a.attr_order[2] == "disabled"
		and a.attr_order[3] == "data-x"
		and a.attr_order[4] == "title",
		"attr order preservation failed"
	)

	check(
		HTMLParser.stringify(doc) == '<a href="/foo" disabled data-x="1" title="single">link</a>',
		"attribute roundtrip failed"
	)

	doc = HTMLParser.parse('<a title="a > b & c">x</a>')

	check(
		doc.children[1].attrs.title == "a > b & c",
		"quoted > and bare & failed"
	)

	check(
		HTMLParser.stringify(doc) == '<a title="a &gt; b &amp; c">x</a>',
		"attr escaping failed"
	)

	doc = HTMLParser.parse('<i id="1" id="2"></i>')

	check(
		doc.children[1].attrs.id == "2",
		"duplicate attrs should keep last value"
	)

	check(
		HTMLParser.stringify(doc) == '<i id="2"></i>',
		"duplicate attr serialization failed"
	)

	doc = HTMLParser.parse("<  div class='x'>t</div>")

	check(doc.children[1].tag == "div", "tag with leading spaces failed")
	check(doc.children[1].attrs.class == "x", "attr after leading spaces failed")
	check(
		HTMLParser.stringify(doc) == '<div class="x">t</div>',
		"leading spaces roundtrip failed"
	)

	doc = HTMLParser.parse('<a title=">">x</a>')

	check(
		doc.children[1].attrs.title == ">",
		"greater-than inside quoted attr failed"
	)

	check(
		HTMLParser.stringify(doc) == '<a title="&gt;">x</a>',
		"greater-than attr roundtrip failed"
	)

	doc = HTMLParser.parse('<button (click)="save()" *ngIf="ok" [disabled]="isDisabled">x</button>')
	local button = doc.children[1]

	check(button.attrs["(click)"] == "save()", "template attr (click) failed")
	check(button.attrs["*ngIf"] == "ok", "template attr *ngIf failed")
	check(button.attrs["[disabled]"] == "isDisabled", "template attr [disabled] failed")

	check(
		HTMLParser.stringify(doc) == '<button (click)="save()" *ngIf="ok" [disabled]="isDisabled">x</button>',
		"template attr roundtrip failed"
	)

	----------------------------------------------------------------------
	-- Case handling
	----------------------------------------------------------------------

	doc = HTMLParser.parse("<DIV ID='main'>Hi</DIV>")

	check(doc.children[1].tag == "div", "lower-case tags by default failed")
	check(doc.children[1].attrs.ID == "main", "attr case preserved by default failed")
	check(
		HTMLParser.stringify(doc) == '<div ID="main">Hi</div>',
		"case roundtrip failed"
	)

	doc = HTMLParser.parse("<DIV ID='main'>Hi</DIV>", { lower_case_attrs = true })

	check(doc.children[1].attrs.id == "main", "lower_case_attrs option failed")

	----------------------------------------------------------------------
	-- XML mode
	----------------------------------------------------------------------

	doc = HTMLParser.parse("<Root Attr='x'><Child/></Root>", { xml = true })

	check(doc.children[1].tag == "Root", "xml should preserve tag case")
	check(doc.children[1].attrs.Attr == "x", "xml attr failed")
	check(doc.children[1].children[1].tag == "Child", "xml child failed")
	check(doc.children[1].children[1].self_closing == true, "xml self-closing failed")

	check(
		HTMLParser.stringify(doc) == '<Root Attr="x"><Child /></Root>',
		"xml roundtrip failed"
	)

	----------------------------------------------------------------------
	-- Void elements
	----------------------------------------------------------------------

	doc = HTMLParser.parse("<br><br/><img src='x'>")

	check(#doc.children == 3, "expected three void nodes")
	check(doc.children[1].tag == "br" and not doc.children[1].self_closing, "plain <br> failed")
	check(doc.children[2].tag == "br" and doc.children[2].self_closing == true, "<br/> failed")
	check(doc.children[3].attrs.src == "x", "<img src> failed")

	check(
		HTMLParser.stringify(doc) == '<br><br /><img src="x">',
		"void serialization failed"
	)

	----------------------------------------------------------------------
	-- Raw text elements
	----------------------------------------------------------------------

	doc = HTMLParser.parse("<script>if (a < b && c > d) { alert(1); }</script>")
	local script = doc.children[1]

	check(script.tag == "script", "script tag failed")
	check(
		script.children[1].content == "if (a < b && c > d) { alert(1); }",
		"script raw content failed"
	)
	check(script.children[1].raw == true, "script raw flag failed")

	check(
		HTMLParser.stringify(doc) == "<script>if (a < b && c > d) { alert(1); }</script>",
		"script roundtrip failed"
	)

	doc = HTMLParser.parse("<STYLE>a > b { color: red; }</style>")

	check(doc.children[1].tag == "style", "style tag lower-casing failed")
	check(
		doc.children[1].children[1].content == "a > b { color: red; }",
		"style raw content failed"
	)

	check(
		HTMLParser.stringify(doc) == "<style>a > b { color: red; }</style>",
		"style roundtrip failed"
	)

	doc = HTMLParser.parse('<script>var x = "</scriptfoo>";</script>')

	check(
		doc.children[1].children[1].content == 'var x = "</scriptfoo>";',
		"raw end tag must be exact"
	)

	----------------------------------------------------------------------
	-- Comments, CDATA, DOCTYPE, PI
	----------------------------------------------------------------------

	doc = HTMLParser.parse("<!DOCTYPE html><!-- c --><![CDATA[<x>&]]><?xml version='1.0'?><root/>")

	check(doc.children[1].type == "doctype", "doctype type failed")
	check(doc.children[2].type == "comment", "comment type failed")
	check(doc.children[3].type == "cdata", "cdata type failed")
	check(doc.children[4].type == "pi", "pi type failed")
	check(doc.children[5].type == "element", "element after metadata failed")

	check(
		doc.children[1].tag == "DOCTYPE" and doc.children[1].content == "html",
		"doctype content failed"
	)

	check(doc.children[2].content == " c ", "comment content failed")
	check(doc.children[3].content == "<x>&", "cdata content failed")

	check(
		doc.children[4].tag == "xml" and doc.children[4].content == "version='1.0'",
		"pi content failed"
	)

	check(
		HTMLParser.stringify(doc) == "<!DOCTYPE html><!-- c --><![CDATA[<x>&]]><?xml version='1.0'?><root />",
		"metadata roundtrip failed"
	)

	doc = HTMLParser.parse("<!-- x --><p>a</p>", { include_comments = false })

	check(
		#doc.children == 1 and doc.children[1].tag == "p",
		"include_comments=false failed"
	)

	doc = HTMLParser.parse("<!doctype html><html></html>")

	check(
		HTMLParser.stringify(doc) == "<!DOCTYPE html><html></html>",
		"doctype case normalization failed"
	)

	----------------------------------------------------------------------
	-- Error recovery
	----------------------------------------------------------------------

	doc = HTMLParser.parse("<b><i></b></i>")

	check(doc.children[1].tag == "b", "recovery root failed")
	check(doc.children[1].children[1].tag == "i", "recovery implicit close failed")
	check(#doc.children[1].children[1].children == 0, "recovery i should be empty")

	check(
		HTMLParser.stringify(doc) == "<b><i></i></b>",
		"recovery roundtrip failed"
	)

	doc = HTMLParser.parse("<p>a</div>")

	check(
		#doc.children == 1 and doc.children[1].tag == "p",
		"unmatched closing tag should be ignored"
	)

	check(
		HTMLParser.stringify(doc) == "<p>a</p>",
		"unmatched closing roundtrip failed"
	)

	doc = HTMLParser.parse("<p>1 < 2 & 3</p>")

	check(
		doc.children[1].children[1].content == "1 < 2 & 3",
		"bare < in text failed"
	)

	check(
		HTMLParser.stringify(doc) == "<p>1 &lt; 2 &amp; 3</p>",
		"bare < roundtrip failed"
	)

	doc = HTMLParser.parse('<a title="unclosed>text')

	check(doc.children[1].type == "text", "malformed tag should become text")
	check(
		doc.children[1].content == '<a title="unclosed>text',
		"malformed text content failed"
	)

	check(
		HTMLParser.stringify(doc) == '&lt;a title="unclosed&gt;text',
		"malformed text escaping failed"
	)

	doc = HTMLParser.parse("<!-- oops")

	check(
		doc.children[1].type == "text" and doc.children[1].content == "<!-- oops",
		"unclosed comment should become text"
	)

	check(
		HTMLParser.stringify(doc) == "&lt;!-- oops",
		"unclosed comment escaping failed"
	)

	----------------------------------------------------------------------
	-- decode_entities=false preserves raw markup
	----------------------------------------------------------------------

	doc = HTMLParser.parse("<p>a &amp; b</p>", { decode_entities = false })

	check(
		doc.children[1].children[1].content == "a &amp; b",
		"raw text content when decode disabled failed"
	)

	check(
		doc.children[1].children[1].raw == true,
		"raw flag when decode disabled failed"
	)

	check(
		HTMLParser.stringify(doc) == "<p>a &amp; b</p>",
		"raw text roundtrip failed"
	)

	doc = HTMLParser.parse('<a title="&amp;"></a>', { decode_entities = false })

	check(
		doc.children[1].attrs.title == "&amp;",
		"raw attr content when decode disabled failed"
	)

	check(
		HTMLParser.stringify(doc) == '<a title="&amp;"></a>',
		"raw attr roundtrip failed"
	)

	----------------------------------------------------------------------
	-- Strict mode
	----------------------------------------------------------------------

	local ok = pcall(function()
		HTMLParser.parse("<a></b>", { strict = true })
	end)

	check(not ok, "strict mode should error on unexpected closing tag")

	ok = pcall(function()
		HTMLParser.parse("<a><b></b></a>", { strict = true })
	end)

	check(ok, "strict mode should accept valid nesting")

	----------------------------------------------------------------------
	-- Utilities
	----------------------------------------------------------------------

	doc = HTMLParser.parse("<div>Hello <b>world</b>!</div>")

	check(
		HTMLParser.get_text(doc) == "Hello world!",
		"get_text failed"
	)

	doc = HTMLParser.parse('<ul><li class="a x">1</li><li id="b" class="y">2</li></ul>')

	local first_li = HTMLParser.find_by_tag(doc, "li")
	check(first_li and first_li.children[1].content == "1", "find_by_tag failed")

	local lis = HTMLParser.find_all_by_tag(doc, "li")
	check(#lis == 2, "find_all_by_tag failed")

	local by_id = HTMLParser.find_by_attr(doc, "id", "b")
	check(by_id and by_id.children[1].content == "2", "find_by_attr failed")

	check(#HTMLParser.query(doc, "li") == 2, "query tag failed")

	local q = HTMLParser.query(doc, ".a")
	check(#q == 1 and q[1].attrs.class == "a x", "query class failed")

	q = HTMLParser.query(doc, "#b")
	check(#q == 1 and q[1].attrs.id == "b", "query id failed")

	q = HTMLParser.query(doc, "[class=y]")
	check(#q == 1 and q[1].attrs.class == "y", "query attr value failed")

	q = HTMLParser.query(doc, "[id=b]")
	check(#q == 1, "query attr equals failed")

	q = HTMLParser.query(doc, "[disabled]")
	check(#q == 0, "query attr exists negative failed")

	----------------------------------------------------------------------
	-- Clone
	----------------------------------------------------------------------

	doc = HTMLParser.parse("<p>orig</p>")
	local copy = HTMLParser.clone(doc)

	copy.children[1].children[1].content = "copy"

	check(
		doc.children[1].children[1].content == "orig",
		"clone should not mutate original"
	)

	check(
		copy.children[1].children[1].content == "copy",
		"clone should be mutable"
	)

	----------------------------------------------------------------------
	-- Serialization behavior for user-created nodes
	----------------------------------------------------------------------

	local node = {
		type = "element",
		tag = "a",
		attrs = { b = "1", a = "2" },
		children = {},
	}

	check(
		HTMLParser.stringify(node) == '<a a="2" b="1"></a>',
		"sorted attrs without attr_order failed"
	)

	node = {
		type = "element",
		tag = "input",
		attrs = { disabled = true, hidden = false, value = "x" },
		children = {},
	}

	check(
		HTMLParser.stringify(node) == '<input disabled value="x">',
		"boolean/false attrs and void failed"
	)

	----------------------------------------------------------------------
	-- Pretty printing
	----------------------------------------------------------------------

	doc = HTMLParser.parse("<div><p>Hi</p><ul><li>1</li><li>2</li></ul></div>")

	local pretty = HTMLParser.stringify(doc, "  ")

	local expected = table.concat({
		"<div>",
		"  <p>Hi</p>",
		"  <ul>",
		"    <li>1</li>",
		"    <li>2</li>",
		"  </ul>",
		"</div>",
	}, "\n")

	check(pretty == expected, "pretty printing failed")

	doc = HTMLParser.parse("<!DOCTYPE html><html><body></body></html>")

	pretty = HTMLParser.stringify(doc, "  ")

	expected = table.concat({
		"<!DOCTYPE html>",
		"<html>",
		"  <body></body>",
		"</html>",
	}, "\n")

	check(pretty == expected, "pretty printing with doctype failed")

	print("All " .. passed .. " tests passed!")
	return true
end

--HTMLParser:run_tests()

-- Export
return HTMLParser
