-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for memory_alignment.lua.
-- Run from this directory:
--   lua memory_alignment.lua
--   luajit memory_alignment.lua

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
local ma = require "memory_alignment"

if true then
	local string_format = string.format
	local total, passed, failed = 0, 0, 0
	local function test(name, fn)
		total = total + 1
		local ok, err = pcall(fn)
		if ok then
			passed = passed + 1
		else
			failed = failed + 1
			print(string_format("  FAIL  %s: %s", name, tostring(err)))
		end
	end
	local function expect_error(fn, pattern)
		local ok, err = pcall(fn)
		assert(not ok, "expected error but got success: " .. tostring(err))
		if pattern then
			assert(tostring(err):find(pattern, 1, true),
				"error message does not contain '" .. pattern .. "': " .. tostring(err))
		end
	end
	print("[memory_alignment] testing...")

	-- Core predicates
	test("is_power_of_two values", function()
		assert(ma.is_power_of_two(1) == true)
		assert(ma.is_power_of_two(2) == true)
		assert(ma.is_power_of_two(1024) == true)
		assert(ma.is_power_of_two(0) == false)
		assert(ma.is_power_of_two(3) == false)
		assert(ma.is_power_of_two(6) == false)
		assert(ma.is_valid_alignment == ma.is_power_of_two)
	end)

	test("assert_valid_alignment ok and errors", function()
		assert(ma.assert_valid_alignment(8) == nil)
		expect_error(function() ma.assert_valid_alignment(3) end, "power of two")
		expect_error(function() ma.assert_valid_alignment(0) end, "power of two")
		expect_error(function() ma.assert_valid_alignment(-4) end, "power of two")
	end)

	test("is_aligned", function()
		assert(ma.is_aligned(8, 4) == true)
		assert(ma.is_aligned(7, 4) == false)
		assert(ma.is_aligned(0, 8) == true)
		expect_error(function() ma.is_aligned("x", 4) end, "value must be number")
		expect_error(function() ma.is_aligned(8, 3) end, "power of two")
	end)

	-- Basic alignment math
	test("align_up / align_down / offset", function()
		assert(ma.align_up(5, 4) == 8)
		assert(ma.align_up(16, 8) == 16)
		assert(ma.align_up(0, 8) == 0)
		assert(ma.align_up(1, 1) == 1)
		assert(ma.align_down(13, 8) == 8)
		assert(ma.align_down(16, 8) == 16)
		assert(ma.alignment_offset(13, 8) == 3)
		assert(ma.alignment_offset(16, 8) == 0)
		expect_error(function() ma.align_up("x", 4) end, "value must be number")
		expect_error(function() ma.align_down(4, 6) end, "power of two")
	end)

	test("alignment aliases match", function()
		assert(ma.padding_needed == ma.alignment_offset)
		assert(ma.calc_padding == ma.alignment_offset)
		assert(ma.offset_to_align == ma.alignment_offset)
		assert(ma.align_size == ma.align_up)
		assert(ma.calc_aligned_size == ma.align_size)
		assert(ma.padding_needed(13, 8) == 3)
		assert(ma.align_size(5, 4) == 8)
	end)

	-- Power of two utilities
	test("next_power_of_two", function()
		assert(ma.next_power_of_two(0) == 1)
		assert(ma.next_power_of_two(-5) == 1)
		assert(ma.next_power_of_two(1) == 1)
		assert(ma.next_power_of_two(5) == 8)
		assert(ma.next_power_of_two(16) == 16)
		assert(ma.next_power_of_two(17) == 32)
		assert(ma.align_to_next_power_of_two == ma.next_power_of_two)
		assert(ma.to_power_of_two == ma.next_power_of_two)
		expect_error(function() ma.next_power_of_two("x") end, "n must be number")
	end)

	test("prev_power_of_two", function()
		assert(ma.prev_power_of_two(0) == 0)
		assert(ma.prev_power_of_two(1) == 1)
		assert(ma.prev_power_of_two(5) == 4)
		assert(ma.prev_power_of_two(16) == 16)
		assert(ma.prev_power_of_two(17) == 16)
		assert(ma.align_to_prev_power_of_two == ma.prev_power_of_two)
		expect_error(function() ma.prev_power_of_two("x") end, "n must be number")
	end)

	-- Advanced helpers
	test("max_alignment varargs and table", function()
		assert(ma.max_alignment(4, 8, 2) == 8)
		assert(ma.max_alignment(1) == 1)
		assert(ma.max_alignment({ 4, 8 }) == 8)
		assert(ma.max_alignment() == 1)
		expect_error(function() ma.max_alignment(4, 3) end, "power of two")
	end)

	test("common_alignment", function()
		assert(ma.common_alignment(4, 8) == 8)
		assert(ma.common_alignment(8, 4) == 8)
		assert(ma.common_alignment(4, 4) == 4)
		expect_error(function() ma.common_alignment(3, 4) end, "power of two")
		expect_error(function() ma.common_alignment(4, 3) end, "power of two")
	end)

	test("array_stride", function()
		assert(ma.array_stride(3, 4) == 4)
		assert(ma.array_stride(8, 8) == 8)
		assert(ma.array_stride(8) == 8)
		assert(ma.array_stride(10, 4) == 12)
		assert(ma.array_stride(0, 4) == 0)
		expect_error(function() ma.array_stride("x") end, "element_size must be number")
	end)

	test("ranges_overlap", function()
		assert(ma.ranges_overlap(0, 10, 5, 10) == true)
		assert(ma.ranges_overlap(0, 5, 5, 5) == false)
		assert(ma.ranges_overlap(0, 5, 10, 5) == false)
		assert(ma.ranges_overlap(5, 5, 0, 10) == true)
	end)

	-- C type database
	test("get_c_type_info known types", function()
		local i8 = ma.get_c_type_info("int8")
		assert(i8.size == 1 and i8.alignment == 1)
		local i32 = ma.get_c_type_info("int32")
		assert(i32.size == 4 and i32.alignment == 4)
		local dbl = ma.get_c_type_info("double")
		assert(dbl.size == 8 and dbl.alignment == 8)
		local ptr = ma.get_c_type_info("pointer")
		assert(ptr.size == 8 or ptr.size == 4)
		assert(ptr.size == ptr.alignment)
		-- returns a copy, not a live reference
		i8.size = 99
		assert(ma.get_c_type_info("int8").size == 1)
	end)

	test("get_c_type_info unknown errors", function()
		expect_error(function() ma.get_c_type_info("nope") end, "unknown c type")
	end)

	test("set_pointer_size round trip", function()
		local orig_size = ma.get_c_type_info("pointer").size
		ma.set_pointer_size(4)
		assert(ma.get_c_type_info("pointer").size == 4)
		assert(ma.get_c_type_info("size_t").alignment == 4)
		ma.set_pointer_size(8)
		assert(ma.get_c_type_info("pointer").size == 8)
		ma.set_pointer_size(orig_size)
		assert(ma.get_c_type_info("pointer").size == orig_size)
		expect_error(function() ma.set_pointer_size(2) end, "ptr_size must be 4 or 8")
	end)

	-- Struct layout utilities
	test("place_field", function()
		local off, finish = ma.place_field(5, 4, 4)
		assert(off == 8 and finish == 12)
		local off2, finish2 = ma.place_field(8, 4, 4)
		assert(off2 == 8 and finish2 == 12)
		assert(ma.calc_field_offset == ma.align_up)
		expect_error(function() ma.place_field("x", 4, 4) end, "current_offset must be number")
		expect_error(function() ma.place_field(0, -1, 4) end, "field_size must be")
		expect_error(function() ma.place_field(0, 4, 3) end, "power of two")
	end)

	test("calc_struct_layout simple", function()
		local layout = ma.calc_struct_layout({
			{ name = "a", type = "int8" },
			{ name = "b", type = "int32" },
		})
		assert(layout.fields[1].offset == 0)
		assert(layout.fields[1].size == 1)
		assert(layout.fields[2].offset == 4)
		assert(layout.fields[2].padding_before == 3)
		assert(layout.size == 8)
		assert(layout.alignment == 4)
		assert(layout.padding_tail == 0)
	end)

	test("calc_struct_layout array + pack + max_align", function()
		local layout = ma.calc_struct_layout({
			{ name = "v", type = "float", count = 4 },
		})
		assert(layout.fields[1].size == 16)
		assert(layout.size == 16)
		local packed = ma.calc_struct_layout({
			{ name = "a", type = "int8" },
			{ name = "b", type = "int32" },
		}, { pack = 1 })
		assert(packed.fields[2].offset == 1)
		assert(packed.size == 5)
		assert(packed.alignment == 1)
		local capped = ma.calc_struct_layout({
			{ name = "d", type = "double" },
		}, { max_align = 4 })
		assert(capped.alignment == 4)
		assert(capped.size == 8)
	end)

	test("calc_struct_layout explicit padding", function()
		local layout = ma.calc_struct_layout({
			{ name = "a", type = "int8" },
			{ size = 3, is_padding = true },
			{ name = "b", type = "int32" },
		})
		assert(layout.fields[2].is_padding == true)
		assert(layout.fields[2].offset == 1)
		assert(layout.fields[3].offset == 4)
		assert(layout.size == 8)
	end)

	test("calc_struct_layout bitfields share a unit", function()
		local layout = ma.calc_struct_layout({
			{ name = "x", type = "uint8", bits = 3 },
			{ name = "y", type = "uint8", bits = 5 },
		})
		assert(layout.fields[1].offset == 0)
		assert(layout.fields[1].bit_offset == 0)
		assert(layout.fields[2].offset == 0)
		assert(layout.fields[2].bit_offset == 3)
		assert(layout.fields[2].is_first_in_unit == false)
		assert(layout.fields[2].bits_used_in_unit == 8)
		assert(layout.fields[2].bitfield_unit_offset == 0)
		assert(layout.size == 1)
	end)

	test("calc_struct_layout zero-width bitfield forces align", function()
		local layout = ma.calc_struct_layout({
			{ name = "x", type = "uint8", bits = 3 },
			{ type = "uint8", bits = 0 },
			{ name = "y", type = "uint8", bits = 5 },
		})
		assert(layout.fields[2].is_zero_width == true)
		assert(layout.fields[2].size == 0)
		assert(layout.fields[3].offset == 1)
		assert(layout.fields[3].is_first_in_unit == true)
	end)

	test("calc_struct_layout errors", function()
		expect_error(function()
			ma.calc_struct_layout({ { name = "x", type = "uint8", bits = 3, count = 2 } })
		end, "cannot have count")
		expect_error(function()
			ma.calc_struct_layout({ { name = "x", type = "nope" } })
		end, "requires size field")
		expect_error(function() ma.calc_struct_layout({ {} }) end, "must have type or size")
		expect_error(function() ma.calc_struct_layout("nope") end, "must be array table")
		expect_error(function()
			ma.calc_struct_layout({ { name = "x", type = "int32", count = 1.5 } })
		end, "count must be integer")
	end)

	test("calc_struct_size", function()
		local size, alignment = ma.calc_struct_size({
			{ name = "a", type = "int8" },
			{ name = "b", type = "int32" },
		})
		assert(size == 8 and alignment == 4)
	end)

	-- Builder API
	test("builder table + string overloads", function()
		local b = ma.new_builder()
		b:add_field({ name = "a", type = "int8" })
		b:add_field("b", { type = "int32" })
		b:add_field("v", "float", 4)
		local layout = b:build()
		assert(layout.fields[1].offset == 0)
		assert(layout.fields[2].offset == 4)
		assert(layout.fields[3].offset == 8)
		assert(layout.fields[3].size == 16)
		assert(layout.size == 24)
	end)

	test("builder numeric + helpers chain", function()
		local b = ma.new_builder()
		local same = b:add_c_type("x", "int32")
			:add_array("arr", "int16", 4)
			:add_bitfield("f", "uint8", 3)
			:add_bitfield_unnamed("uint8", 2)
			:add_zero_width_bitfield("uint8")
			:add_padding(2)
		assert(same == b, "builder methods chain")
		local layout = b:build()
		assert(layout.fields[1].offset == 0)
		assert(layout.fields[2].size == 8)
		assert(layout.fields[3].bits == 3)
		assert(b:current_offset() == layout.unpadded_size)
		assert(b:current_alignment() == layout.alignment)
		b:reset()
		assert(b:current_offset() == 0)
		assert(#b:build().fields == 0)
	end)

	test("builder add_field bitfield ambiguity", function()
		local b = ma.new_builder()
		b:add_field("flag", "uint32", { bits = 1 })
		local layout = b:build()
		assert(layout.fields[1].is_bitfield == true)
		assert(layout.fields[1].bits == 1)
		expect_error(function() b:add_bitfield("x", "uint8", "nope") end, "bits must be number")
		expect_error(function() b:add_padding(-1) end, "padding size must be")
	end)

	-- Validation + formatting
	test("validate_buffer", function()
		local layout = ma.calc_struct_layout({ { name = "a", type = "int32" } })
		local ok = ma.validate_buffer(layout, 4, 0)
		assert(ok == true)
		local ok2, err2 = ma.validate_buffer(layout, 3, 0)
		assert(ok2 == false and err2:find("too small", 1, true) ~= nil)
		local ok3, err3 = ma.validate_buffer(layout, 8, 2)
		assert(ok3 == false and err3:find("not aligned", 1, true) ~= nil)
	end)

	test("format_layout smoke", function()
		local layout = ma.calc_struct_layout({
			{ name = "a", type = "int8" },
			{ name = "b", type = "int32" },
		})
		local text = ma.format_layout(layout)
		assert(text:find("size=8", 1, true) ~= nil)
		assert(text:find("align=4", 1, true) ~= nil)
		assert(text:find("b: offset=4", 1, true) ~= nil)
	end)

	-- FFI cdef generation
	test("generate_cdef basic struct", function()
		local layout = ma.calc_struct_layout({
			{ name = "a", type = "int8" },
			{ name = "b", type = "int32" },
		})
		local cdef = ma.generate_cdef(layout, "MyStruct")
		assert(cdef:find("typedef struct MyStruct {", 1, true) ~= nil)
		assert(cdef:find("int8_t a;", 1, true) ~= nil)
		assert(cdef:find("int32_t b;", 1, true) ~= nil)
		assert(cdef:find("} __attribute__((aligned(4))) MyStruct;", 1, true) ~= nil)
	end)

	test("generate_cdef from fields + builder + plural", function()
		local cdef = ma.generate_cdef({ { name = "x", type = "float" } }, "S")
		assert(cdef:find("float x;", 1, true) ~= nil)
		local b = ma.new_builder()
		b:add_field("x", "int32")
		local cdef2 = ma.generate_cdef_from_builder(b, "B")
		assert(cdef2:find("int32_t x;", 1, true) ~= nil)
		expect_error(function() ma.generate_cdef_from_builder({}, "B") end, "must be")
		local both = ma.generate_cdefs({
			A = { { name = "x", type = "int8" } },
			B = { { name = "y", type = "int16" } },
		})
		assert(both:find("} A;", 1, true) ~= nil)
		assert(both:find("} __attribute__((aligned(2))) B;", 1, true) ~= nil)
	end)

	test("generate_cdef union + pragma pack", function()
		local cdef = ma.generate_cdef({ { name = "x", type = "int32" } }, "U",
			{ is_union = true, use_pragma_pack = true, pack = 1 })
		assert(cdef:find("union U {", 1, true) ~= nil)
		assert(cdef:find("#pragma pack(push, 1)", 1, true) ~= nil)
		assert(cdef:find("#pragma pack(pop)", 1, true) ~= nil)
		local packed = ma.generate_cdef({
			{ name = "a", type = "int8" },
			{ name = "b", type = "int32" },
		}, "P", { pack = 1 })
		assert(packed:find("int32_t b;", 1, true) ~= nil)
		assert(packed:find("offset=1", 1, true) ~= nil)
		assert(packed:find("_pad", 1, true) == nil)
	end)

	-- Edge cases and numeric paths
	test("next/prev power of two fractions and cap", function()
		assert(ma.next_power_of_two(5.5) == 8)
		assert(ma.prev_power_of_two(5.9) == 4)
		assert(ma.prev_power_of_two(-5) == 0)
		-- huge inputs: loop guard caps at first power above 2^53, but the
		-- bundled bits backend truncates to 32 bits on some runtimes
		-- (is_power_of_two(2^53+2) is true there), so only the lower
		-- bound is portable: the result never shrinks the input.
		assert(ma.next_power_of_two(2 ^ 53 + 2) >= 2 ^ 53 + 2)
	end)

	test("is_aligned unit alignment", function()
		assert(ma.is_aligned(7, 1) == true)
	end)

	test("max_alignment single and invalid", function()
		assert(ma.max_alignment(8) == 8)
		expect_error(function() ma.max_alignment(3) end, "power of two")
		expect_error(function() ma.common_alignment(4, 3) end, "power of two")
	end)

	test("array_stride default-align contract", function()
		assert(ma.array_stride(0, 4) == 0)
		-- default alignment is element_size itself: non-power-of-two sizes fail
		expect_error(function() ma.array_stride(5) end, "power of two")
		expect_error(function() ma.array_stride(3, 3) end, "power of two")
	end)

	test("ranges_overlap extended", function()
		assert(ma.ranges_overlap(5, 5, 5, 5) == true) -- identical
		assert(ma.ranges_overlap(0, 10, 2, 3) == true) -- containment
		assert(ma.ranges_overlap(5, 0, 5, 0) == false) -- zero-size
		assert(ma.ranges_overlap(-5, 10, 0, 1) == true) -- negative offsets
	end)

	test("get_c_type_info full database", function()
		local seen = 0
		for name, info in pairs(ma.c_types) do
			local got = ma.get_c_type_info(name)
			assert(type(got.size) == "number" and got.size >= 1)
			assert(type(got.alignment) == "number" and got.alignment >= 1)
			seen = seen + 1
		end
		assert(seen == 20)
		assert(ma.get_c_type_info("long").size == 4)
		assert(ma.get_c_type_info("short").size == 2)
		assert(ma.get_c_type_info("bool").size == 1)
		assert(ma.get_c_type_info("long_double").size == 16)
	end)

	test("resolve unknown/custom sizes", function()
		local layout = ma.calc_struct_layout({
			{ name = "x", type = "custom", size = 6 },
		})
		assert(layout.fields[1].offset == 0)
		assert(layout.fields[1].size == 6)
		assert(layout.fields[1].alignment == 8) -- next_power_of_two(6)
		local raw = ma.calc_struct_layout({ { name = "raw", size = 6 } })
		assert(raw.fields[1].size == 6)
		assert(raw.fields[1].alignment == 8)
		local given = ma.calc_struct_layout({
			{ name = "x", type = "custom", size = 6, alignment = 2 },
		})
		assert(given.fields[1].alignment == 2)
	end)

	test("count of one is scalar", function()
		local layout = ma.calc_struct_layout({
			{ name = "x", type = "int32", count = 1 },
		})
		assert(layout.fields[1].is_array == false)
		assert(layout.fields[1].size == 4)
		expect_error(function()
			ma.calc_struct_layout({ { name = "x", type = "int32", count = "bad" } })
		end) -- raw comparison error: non-numeric counts are rejected, without the friendly message
	end)

	test("pack and max_align validation", function()
		expect_error(function()
			ma.calc_struct_layout({ { name = "x", type = "int32" } }, { pack = 3 })
		end, "power of two")
		expect_error(function()
			ma.calc_struct_layout({ { name = "x", type = "int32" } }, { max_align = 3 })
		end, "power of two")
	end)

	test("original_alignment preserved under pack", function()
		local layout = ma.calc_struct_layout({
			{ name = "b", type = "int32" },
		}, { pack = 1 })
		assert(layout.fields[1].alignment == 1)
		assert(layout.fields[1].original_alignment == 4)
		local bf = ma.calc_struct_layout({
			{ name = "x", type = "uint32", bits = 4 },
		}, { pack = 1 })
		assert(bf.fields[1].alignment == 1)
		assert(bf.fields[1].original_alignment == 4)
	end)

	test("empty struct layout", function()
		local layout = ma.calc_struct_layout({})
		assert(layout.size == 0)
		assert(layout.alignment == 1)
		assert(#layout.fields == 0)
	end)

	test("explicit padding size validation", function()
		expect_error(function()
			ma.calc_struct_layout({ { size = "x", is_padding = true } })
		end, "padding size invalid")
		expect_error(function()
			ma.calc_struct_layout({ { size = -2, is_padding = true } })
		end, "padding size invalid")
	end)

	test("bitfield new unit on size change and overflow", function()
		local layout = ma.calc_struct_layout({
			{ name = "x", type = "uint8", bits = 8 },
			{ name = "y", type = "uint16", bits = 4 },
		})
		assert(layout.fields[2].offset == 2)
		assert(layout.fields[2].padding_before == 1)
		assert(layout.fields[2].is_first_in_unit == true)
		local over = ma.calc_struct_layout({
			{ name = "x", type = "uint8", bits = 5 },
			{ name = "y", type = "uint8", bits = 4 },
		})
		assert(over.fields[1].bits_used_in_unit == 5)
		assert(over.fields[2].offset == 1)
		assert(over.fields[2].bit_offset == 0)
		assert(over.fields[2].is_first_in_unit == true)
	end)

	test("bitfield invalid widths", function()
		expect_error(function()
			ma.calc_struct_layout({ { name = "x", type = "uint8", bits = 1.5 } })
		end, "bits must be integer")
		expect_error(function()
			ma.calc_struct_layout({ { name = "x", type = "uint8", bits = -1 } })
		end, "bits must be integer")
	end)

	test("unnamed bitfield autoname", function()
		local layout = ma.calc_struct_layout({
			{ type = "uint8", bits = 2 },
		})
		assert(layout.fields[1].name == "_bf_1")
		assert(layout.fields[1].is_unnamed == true)
		assert(layout.fields[1].bit_offset == 0)
	end)

	test("unpadded_size reported", function()
		local layout = ma.calc_struct_layout({
			{ name = "a", type = "int8" },
			{ name = "b", type = "int32" },
		})
		assert(layout.unpadded_size == 8)
		assert(layout.size == 8)
	end)

	-- Builder overloads and options
	test("builder numeric size/align overloads", function()
		local b = ma.new_builder()
		b:add_field("c", 4, 4)
		b:add_field("a", 4, 4, "int32")
		b:add_field("b", 4, 4, "int32", 2)
		local layout = b:build()
		assert(layout.fields[1].offset == 0)
		assert(layout.fields[1].size == 4)
		assert(layout.fields[2].offset == 4)
		assert(layout.fields[3].offset == 8)
		assert(layout.fields[3].size == 8)
		assert(layout.size == 16)
	end)

	test("builder (name, size, align, opts-table)", function()
		local b = ma.new_builder()
		b:add_field("c", 4, 4, {})
		local layout = b:build()
		assert(layout.fields[1].offset == 0)
		assert(layout.fields[1].size == 4)
		b:add_field("e", 4, 4, "int32", {})
		assert(b:build().fields[2].size == 4)
		b:add_field({ name = "tb", type = "uint8", bits = 4 })
		local again = b:build()
		assert(again.fields[3].is_bitfield == true)
		assert(again.fields[3].bits == 4)
	end)

	test("builder pack/max_align options", function()
		local b = ma.new_builder({ pack = 4, max_align = 8 })
		b:add_field("x", "int32")
		assert(b:build().size == 4)
		expect_error(function() ma.new_builder({ pack = 3 }) end, "power of two")
		expect_error(function() ma.new_builder({ max_align = 3 }) end, "power of two")
	end)

	test("builder zero-width default type", function()
		local b = ma.new_builder()
		b:add_zero_width_bitfield()
		local layout = b:build()
		assert(layout.fields[1].is_zero_width == true)
		assert(layout.fields[1].type == "int32")
	end)

	-- format_layout line kinds
	test("format_layout all line kinds", function()
		local layout = ma.calc_struct_layout({
			{ name = "a", type = "int8" },
			{ name = "v", type = "float", count = 2 },
			{ name = "x", type = "uint8", bits = 3 },
			{ type = "uint8", bits = 0 },
			{ size = 2, is_padding = true },
		})
		local text = ma.format_layout(layout)
		assert(text:find("v[2]:", 1, true) ~= nil)
		assert(text:find("bit_offset=0 bits=3", 1, true) ~= nil)
		assert(text:find("zero-width bitfield", 1, true) ~= nil)
		assert(text:find("[padding]", 1, true) ~= nil)
	end)

	-- generate_cdef options matrix
	test("generate_cdef typedef/padding/comments toggles", function()
		local fields = {
			{ name = "a", type = "int8" },
			{ name = "b", type = "int32" },
		}
		local plain = ma.generate_cdef({ { name = "a", type = "int8" } }, "S",
			{ typedef = false })
		assert(plain:find("struct S {", 1, true) ~= nil)
		assert(plain:sub(-2) == "};")
		local nopad = ma.generate_cdef(fields, "S", { explicit_padding = false })
		assert(nopad:find("_pad", 1, true) == nil)
		local nocomment = ma.generate_cdef(fields, "S", { comment_offsets = false })
		assert(nocomment:find("//", 1, true) == nil)
		local packed = ma.generate_cdef(fields, "S", { packed = true })
		assert(packed:find("__attribute__((packed))", 1, true) ~= nil)
		assert(packed:find("aligned(", 1, true) == nil)
		local noaligned = ma.generate_cdef(fields, "S", { use_attribute_aligned = false })
		assert(noaligned:find("aligned(", 1, true) == nil)
		local headed = ma.generate_cdef(fields, "S", { header = "/* H */" })
		assert(headed:sub(1, 7) == "/* H */")
	end)

	test("generate_cdef bitfield lines", function()
		local named = ma.generate_cdef({
			{ name = "x", type = "uint8", bits = 3 },
			{ name = "y", type = "uint8", bits = 5 },
		}, "BF")
		assert(named:find("uint8_t x : 3;", 1, true) ~= nil)
		assert(named:find("bit_offset=3", 1, true) ~= nil)
		local zw = ma.generate_cdef({ { name = "z", type = "uint8", bits = 0 } }, "Z")
		assert(zw:find("uint8_t z : 0;", 1, true) ~= nil)
		local un = ma.generate_cdef({ { type = "uint8", bits = 2 } }, "U")
		assert(un:find("uint8_t : 2;", 1, true) ~= nil)
		local uzw = ma.generate_cdef({ { type = "uint8", bits = 0 } }, "Z")
		assert(uzw:find("uint8_t : 0;", 1, true) ~= nil)
	end)

	test("generate_cdef tail padding and auto array", function()
		local tail = ma.generate_cdef({
			{ name = "a", type = "int32" },
			{ name = "b", type = "int8" },
		}, "T")
		assert(tail:find("_pad", 1, true) ~= nil)
		assert(tail:find("tail padding", 1, true) ~= nil)
		local auto = ma.generate_cdef({ { name = "d", size = 12, alignment = 4 } }, "A")
		assert(auto:find("uint8_t d[12];", 1, true) ~= nil)
		local explicit = ma.generate_cdef(
			{ { name = "x", type = "int8_t", size = 1, alignment = 1 } }, "E")
		assert(explicit:find("int8_t x;", 1, true) ~= nil)
		-- unknown type names pass through; unknown sizes fall back to bytes
		local custom = ma.generate_cdef(
			{ { name = "x", type = "custom", size = 4, alignment = 4 } }, "C")
		assert(custom:find("custom x[4];", 1, true) ~= nil)
	end)

	-- Smoke: invariants and end-to-end pipeline
	test("smoke alignment identities", function()
		for _, a in ipairs({ 1, 2, 4, 8, 16 }) do
			for v = 0, 33 do
				assert(ma.align_up(v, a) % a == 0)
				assert(ma.align_down(v, a) <= v)
				assert(ma.align_up(v, a) - v == ma.alignment_offset(v, a))
				local off, finish = ma.place_field(v, 3, a)
				assert(off == ma.align_up(v, a) and finish == off + 3)
			end
		end
		assert(ma.align_up(2 ^ 40 + 12345, 4096) % 4096 == 0)
	end)

	test("smoke vertex pipeline via builder and layout agree", function()
		local specs = {
			{ name = "position", type = "float", count = 3 },
			{ name = "normal", type = "float", count = 3 },
			{ name = "uv", type = "float", count = 2 },
			{ name = "color", type = "uint32" },
		}
		local direct = ma.calc_struct_layout(specs)
		local b = ma.new_builder()
		for _, s in ipairs(specs) do b:add_field(s) end
		local built = b:build()
		assert(direct.size == 36 and built.size == 36)
		assert(direct.alignment == 4 and built.alignment == 4)
		for i = 1, #specs do
			assert(direct.fields[i].offset == built.fields[i].offset)
		end
		assert(direct.fields[4].offset == 32)
		assert(ma.validate_buffer(built, 36, 0) == true)
		local cdef = ma.generate_cdef(built, "Vertex")
		assert(cdef:find("float position[3];", 1, true) ~= nil)
		assert(cdef:find("uint32_t color;", 1, true) ~= nil)
		local text = ma.format_layout(built)
		assert(text:find("struct { size=36", 1, true) ~= nil)
	end)

	print(string_format("[memory_alignment] %d/%d tests passed (%d failed)", passed, total, failed))
	assert(failed == 0, string_format("%d test(s) failed", failed))
end
