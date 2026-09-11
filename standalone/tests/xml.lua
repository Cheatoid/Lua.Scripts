-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for xml.lua.
-- Run from this directory:
--   lua xml.lua
--   luajit xml.lua

-- Bootstrap: make requires work from tests/ subdir with plain lua/luajit.
do
	local src = debug.getinfo(1, "S").source
	local dir = src:match("^@(.+/)[^/]+$") or "./"
	local function isfile(p)
		local f = io.open(p, "r")
		if f then
			f:close()
			return true
		end
		return false
	end
	local root
	for _, c in ipairs({ dir, dir .. "../", dir .. "../..//", dir .. "../../..//", "./", "../", "../../" }) do
		if isfile(c .. "standalone/bits.lua") then
			root = c
			break
		end
	end
	root = root or dir .. "../"
	if package then
		package.path = dir ..
			"../?.lua;" ..
			dir ..
			"../?/init.lua;" ..
			dir ..
			"?.lua;" ..
			dir ..
			"?/init.lua;" ..
			root ..
			"?.lua;" ..
			root ..
			"?/init.lua;" ..
			root ..
			"standalone/?.lua;" ..
			root ..
			"math/?.lua;" ..
			root ..
			"collections/?.lua;" ..
			root ..
			"benchmark/?.lua;" ..
			root ..
			"timer/?.lua;" ..
			root ..
			"autocompleter/?.lua;" ..
			root ..
			"permission/?.lua;" ..
			root ..
			"chat_commander/?.lua;" ..
			root .. "vm/?.lua;" .. root .. "require_finder/?.lua;" .. root .. "inventory/?.lua;" .. package.path
	end
	local searchers = package.searchers or package.loaders
	if searchers then
		table.insert(searchers, 2, function(mod)
			if mod:sub(1, 3) == "../" or mod:sub(1, 2) == "./" then
				local clean = mod:gsub("^%./", ""):gsub("^%.%.%/", ""):gsub("^%.%.%/", "")
				local tries = { dir .. "../" .. clean .. ".lua", dir .. "../" .. clean .. "/init.lua", root ..
				clean .. ".lua", root .. clean .. "/init.lua" }
				for _, f in ipairs(tries) do
					if isfile(f) then
						local chunk, err = loadfile(f)
						if chunk then return chunk, f end
					end
				end
			end
			return nil
		end)
	end
end
local lib = require "xml"
-- Bridging: file-locals used by tests mapped to module exports.
local XML = lib
local string_format = string.format
-- TODO(manual): the following were file-locals with no direct export;
-- verify and export or inline as needed: attrs, cdata, children, filter, name, text, withPath

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
		local xml_str = [==[
			<data>
				<text>Special chars: &lt; &gt; &amp;</text>
				<binary><![CDATA[Some raw data: \0\1\2]]></binary>
				<!-- This is a comment -->
				<empty attr="value"/>
			</data>
		]==]

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
