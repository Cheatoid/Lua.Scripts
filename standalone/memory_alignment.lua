-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Memory alignment utilities for LuaJIT/5.1+

-- Localized global functions for better performance
local error = error
local ipairs = ipairs
local setmetatable = setmetatable
local tostring = tostring
local type = type
local math_floor = math.floor
local math_min = math.min
local math_modf = math.modf
local string_find = string.find
local string_format = string.format
local table_concat = table.concat
local table_insert = table.insert

local memory_alignment = {}

-- Load bits module for bit operations (standalone compatible)
local bit = require "bits"
local is_power_of_two = bit.is_power_of_two

----------------------------------------------------------------------
-- Internal helpers
----------------------------------------------------------------------

--- Truncate a number toward zero.
---@param n number Value to truncate.
---@return integer result Integer part of the value.
local function to_integer(n)
	--return math_floor(n)
	return (math_modf(n))
end

----------------------------------------------------------------------
-- Core predicates
----------------------------------------------------------------------

memory_alignment.is_power_of_two = is_power_of_two
memory_alignment.is_valid_alignment = is_power_of_two

--- Raise an error unless the alignment is a positive power of two.
---@param alignment integer Alignment to validate.
function memory_alignment.assert_valid_alignment(alignment)
	if not memory_alignment.is_valid_alignment(alignment) then
		return error(string_format("invalid alignment %s: must be power of two > 0", tostring(alignment)), 3)
	end
end

--- Test whether a value is a multiple of the alignment.
---@param value number Value to test.
---@param alignment integer Alignment to test against.
---@return boolean aligned True when value is a multiple of alignment.
function memory_alignment.is_aligned(value, alignment)
	if type(value) ~= "number" then return error("value must be number", 2) end
	memory_alignment.assert_valid_alignment(alignment)
	return (value % alignment) == 0
end

----------------------------------------------------------------------
-- Basic alignment math
----------------------------------------------------------------------

--- Round a value up to the alignment boundary.
---@param value number Value to align.
---@param alignment integer Alignment to align to.
---@return integer aligned Aligned value.
function memory_alignment.align_up(value, alignment)
	if type(value) ~= "number" then return error("value must be number", 2) end
	memory_alignment.assert_valid_alignment(alignment)
	if value == 0 then return 0 end
	return math_floor((value + alignment - 1) / alignment) * alignment
end

--- Round a value down to the alignment boundary.
---@param value number Value to align.
---@param alignment integer Alignment to align to.
---@return integer aligned Aligned value.
function memory_alignment.align_down(value, alignment)
	if type(value) ~= "number" then return error("value must be number", 2) end
	memory_alignment.assert_valid_alignment(alignment)
	return math_floor(value / alignment) * alignment
end

--- Count the padding bytes needed to align a value.
---@param value number Value to align.
---@param alignment integer Alignment to align to.
---@return integer padding Bytes to add for alignment.
function memory_alignment.alignment_offset(value, alignment)
	if type(value) ~= "number" then return error("value must be number", 2) end
	memory_alignment.assert_valid_alignment(alignment)
	local mod = value % alignment
	if mod == 0 then return 0 end
	return alignment - mod
end

memory_alignment.padding_needed = memory_alignment.alignment_offset
memory_alignment.calc_padding = memory_alignment.alignment_offset
memory_alignment.offset_to_align = memory_alignment.alignment_offset
memory_alignment.align_size = memory_alignment.align_up
memory_alignment.calc_aligned_size = memory_alignment.align_size

----------------------------------------------------------------------
-- Power of two utilities
----------------------------------------------------------------------

--- Round a value up to a power of two.
---@param n number Value to round up.
---@return integer power Smallest power of two at or above n (1 for n <= 0).
function memory_alignment.next_power_of_two(n)
	if type(n) ~= "number" then return error("n must be number", 2) end
	if n <= 0 then return 1 end
	n = to_integer(n)
	if memory_alignment.is_power_of_two(n) then return n end
	local p = 1
	while p < n do
		p = p * 2
		if p > 2 ^ 53 then break end
	end
	return p
end

memory_alignment.align_to_next_power_of_two = memory_alignment.next_power_of_two
memory_alignment.to_power_of_two = memory_alignment.next_power_of_two

--- Round a value down to a power of two.
---@param n number Value to round down.
---@return integer power Largest power of two at or below n (0 for n < 1).
function memory_alignment.prev_power_of_two(n)
	if type(n) ~= "number" then return error("n must be number", 2) end
	if n < 1 then return 0 end
	n = to_integer(n)
	local p = 1
	while p * 2 <= n do p = p * 2 end
	return p
end

memory_alignment.align_to_prev_power_of_two = memory_alignment.prev_power_of_two

----------------------------------------------------------------------
-- Advanced helpers
----------------------------------------------------------------------

--- Return the largest of several alignments.
---@param ... any Power-of-two alignments, or a single array table.
---@return integer largest Largest alignment (1 when empty).
function memory_alignment.max_alignment(...)
	local max = 1
	local args = { ... }
	if #args == 1 and type(args[1]) == "table" then args = args[1] end
	for _ = 1, #args do
		local a = args[_]
		memory_alignment.assert_valid_alignment(a)
		if a > max then max = a end
	end
	return max
end

--- Return the larger of two alignments.
---@param a integer First alignment.
---@param b integer Second alignment.
---@return integer larger The larger alignment.
function memory_alignment.common_alignment(a, b)
	memory_alignment.assert_valid_alignment(a)
	memory_alignment.assert_valid_alignment(b)
	return (a > b) and a or b
end

--- Compute an array element stride with trailing padding.
---@param element_size integer Element size in bytes.
---@param element_alignment? integer Element alignment (default: element_size).
---@return integer stride Stride including trailing padding.
function memory_alignment.array_stride(element_size, element_alignment)
	if type(element_size) ~= "number" then return error("element_size must be number", 2) end
	return memory_alignment.align_up(element_size, element_alignment or element_size)
end

--- Test whether two offset/size ranges intersect.
---@param offset1 integer First range start.
---@param size1 integer First range size.
---@param offset2 integer Second range start.
---@param size2 integer Second range size.
---@return boolean overlapping True when the ranges intersect.
function memory_alignment.ranges_overlap(offset1, size1, offset2, size2)
	return offset1 < offset2 + size2 and offset2 < offset1 + size1
end

----------------------------------------------------------------------
-- C type database (typical 64-bit LP64)
----------------------------------------------------------------------

local is64 = #tostring {} > #"table: 0x11223344"

memory_alignment.c_types = {
	int8        = { size = 1, alignment = 1 },
	uint8       = { size = 1, alignment = 1 },
	char        = { size = 1, alignment = 1 },
	bool        = { size = 1, alignment = 1 },
	int16       = { size = 2, alignment = 2 },
	uint16      = { size = 2, alignment = 2 },
	short       = { size = 2, alignment = 2 },
	int32       = { size = 4, alignment = 4 },
	uint32      = { size = 4, alignment = 4 },
	int         = { size = 4, alignment = 4 },
	uint        = { size = 4, alignment = 4 },
	float       = { size = 4, alignment = 4 },
	long        = { size = 4, alignment = 4 },
	int64       = { size = 8, alignment = 8 },
	uint64      = { size = 8, alignment = 8 },
	long_long   = { size = 8, alignment = 8 },
	double      = { size = 8, alignment = 8 },
	long_double = { size = 16, alignment = 16 },
	pointer     = { size = is64 and 8 or 4, alignment = is64 and 8 or 4 },
	size_t      = { size = is64 and 8 or 4, alignment = is64 and 8 or 4 },
}

---@alias memory_alignment.Type "int8"|"uint8"|"char"|"bool"|"int16"|"uint16"|"short"|"int32"|"uint32"|"int"|"uint"|"float"|"long"|"int64"|"uint64"|"long_long"|"double"|"long_double"|"pointer"|"size_t"

--- Fetch a copy of a C type size/alignment entry.
---@param type_name string C type key.
---@return table info Size and alignment copy.
function memory_alignment.get_c_type_info(type_name)
	local info = memory_alignment.c_types[type_name]
	if not info then return error("unknown c type: " .. tostring(type_name), 2) end
	return { size = info.size, alignment = info.alignment }
end

--- Override pointer and size_t widths.
---@param ptr_size integer Pointer width, 4 or 8.
function memory_alignment.set_pointer_size(ptr_size)
	if ptr_size ~= 4 and ptr_size ~= 8 then return error("ptr_size must be 4 or 8", 2) end
	memory_alignment.c_types.pointer.size = ptr_size
	memory_alignment.c_types.pointer.alignment = ptr_size
	memory_alignment.c_types.size_t.size = ptr_size
	memory_alignment.c_types.size_t.alignment = ptr_size
end

----------------------------------------------------------------------
-- Internal: resolve element info for a field spec
-- Supports: {type="float", count=16}, {size=4, alignment=4}, {type="int32", bits=4}
----------------------------------------------------------------------

--- Resolve a field spec to element size, alignment and base type name.
---@param f table Field spec with type/size/alignment.
---@return integer size Element size in bytes.
---@return integer alignment Element alignment.
---@return string? base Base type name, or nil for size-only specs.
local function resolve_element_info(f)
	local elem_size, elem_align, base_type_name
	if f.type then
		local info = memory_alignment.c_types[f.type]
		if info then
			elem_size = info.size
			elem_align = info.alignment
			base_type_name = f.type
		else
			-- unknown type but size may be provided, or treat as raw C type with unknown size -> require size
			if f.size then
				elem_size = f.size
				elem_align = f.alignment or memory_alignment.next_power_of_two(f.size)
				base_type_name = f.type
			else
				return error("unknown c type '" .. tostring(f.type) .. "' requires size field", 2)
			end
		end
	elseif f.size then
		elem_size = f.size
		elem_align = f.alignment or memory_alignment.next_power_of_two(f.size)
		base_type_name = f.type
	else
		return error("field must have type or size", 2)
	end
	return elem_size, elem_align, base_type_name
end

----------------------------------------------------------------------
-- Struct layout utilities
----------------------------------------------------------------------

--- Place a field at the next aligned offset.
---@param current_offset integer Running offset.
---@param field_size integer Field size in bytes.
---@param field_alignment integer Field alignment.
---@return integer aligned Aligned field offset.
---@return integer next Offset just past the field.
function memory_alignment.place_field(current_offset, field_size, field_alignment)
	if type(current_offset) ~= "number" then return error("current_offset must be number", 2) end
	if type(field_size) ~= "number" or field_size < 0 then return error("field_size must be >=0", 2) end
	memory_alignment.assert_valid_alignment(field_alignment)
	local aligned_offset = memory_alignment.align_up(current_offset, field_alignment)
	return aligned_offset, aligned_offset + field_size
end

memory_alignment.calc_field_offset = memory_alignment.align_up

---@class memory_alignment.Layout
---@field fields table Field layout entries.
---@field size integer Total struct size including tail padding.
---@field alignment integer Struct alignment.
---@field padding_tail integer Trailing padding bytes.
---@field unpadded_size integer End offset before tail padding.

---@class memory_alignment.FieldSpec
---@field name? string (optional for padding/bitfield)
---@field size integer
---@field alignment integer
---@field type string|memory_alignment.Type (e.g. "float", "int32")
---@field count integer (array, e.g. 16 for float[16])
---@field bits integer (bitfield width, 0 = zero-width force align)
---@field is_padding boolean

---@class memory_alignment.LayoutOpts
---@field pack? integer Cap applied to every field alignment (default: nil).
---@field max_align? integer Ceiling for the struct alignment (default: nil).

--- Calculate full struct layout.
---@param fields memory_alignment.FieldSpec[] Field specs.
---@param opts? memory_alignment.LayoutOpts Optional layout options.
---@return memory_alignment.Layout layout Computed layout with fields, size and alignment.
function memory_alignment.calc_struct_layout(fields, opts)
	if type(fields) ~= "table" then return error("fields must be array table", 2) end
	opts = opts or {}
	local pack = opts.pack
	if pack ~= nil then memory_alignment.assert_valid_alignment(pack) end

	local layout = { fields = {}, size = 0, alignment = 1, padding_tail = 0 }
	local offset = 0
	local max_align = 1
	local current_bitfield_unit -- {offset, size, alignment, bits_total, bits_used}

	for i = 1, #fields do
		local f = fields[i]
		if f.is_padding then
			-- explicit padding field
			if type(f.size) ~= "number" or f.size < 0 then return error(string_format("field %d padding size invalid", i)) end
			-- close bitfield unit
			current_bitfield_unit = nil
			table_insert(layout.fields, {
				name = f.name or ("_pad_" .. i),
				offset = offset,
				size = f.size,
				alignment = 1,
				original_alignment = 1,
				padding_before = 0,
				type = nil,
				is_padding = true,
				is_bitfield = false,
			})
			offset = offset + f.size
		elseif f.bits ~= nil then
			-- BITFIELD
			if type(f.bits) ~= "number" or f.bits < 0 or f.bits ~= math_floor(f.bits) then
				return error(string_format("field %d bits must be integer >=0", i))
			end
			if f.count then return error(string_format("field %d: bitfield cannot have count", i)) end
			local storage_size, storage_align, base_type = resolve_element_info(f)
			local eff_align = storage_align
			if pack then eff_align = math_min(eff_align, pack) end
			memory_alignment.assert_valid_alignment(eff_align)

			if f.bits == 0 then
				-- zero-width bitfield: force alignment to next unit
				if current_bitfield_unit then current_bitfield_unit = nil end
				local aligned = memory_alignment.align_up(offset, eff_align)
				local pad_before = aligned - offset
				table_insert(layout.fields, {
					name = f.name or "",
					offset = aligned,
					size = 0,
					alignment = eff_align,
					original_alignment = storage_align,
					padding_before = pad_before,
					type = f.type or base_type,
					bits = 0,
					bit_offset = 0,
					is_bitfield = true,
					is_zero_width = true,
					storage_size = storage_size,
					is_array = false,
				})
				offset = aligned
				if eff_align > max_align then max_align = eff_align end
			else
				-- non-zero bitfield
				local needs_new = false
				if not current_bitfield_unit then
					needs_new = true
				elseif current_bitfield_unit.size ~= storage_size or current_bitfield_unit.alignment ~= eff_align then
					needs_new = true
				elseif current_bitfield_unit.bits_used + f.bits > current_bitfield_unit.bits_total then
					needs_new = true
				end

				if needs_new then
					local aligned_offset = memory_alignment.align_up(offset, eff_align)
					local padding_before = aligned_offset - offset
					current_bitfield_unit = {
						offset = aligned_offset,
						size = storage_size,
						alignment = eff_align,
						bits_total = storage_size * 8,
						bits_used = f.bits,
					}
					if eff_align > max_align then max_align = eff_align end
					table_insert(layout.fields, {
						name = f.name or ("_bf_" .. i),
						offset = aligned_offset,
						size = storage_size,
						alignment = eff_align,
						original_alignment = storage_align,
						padding_before = padding_before,
						type = f.type or base_type,
						bits = f.bits,
						bit_offset = 0,
						is_bitfield = true,
						is_first_in_unit = true,
						storage_size = storage_size,
						bits_used_in_unit = f.bits,
						is_zero_width = false,
						is_array = false,
						is_unnamed = not f.name or f.name == "",
					})
					offset = aligned_offset + storage_size
				else
					local bit_offset = current_bitfield_unit.bits_used
					current_bitfield_unit.bits_used = current_bitfield_unit.bits_used + f.bits
					table_insert(layout.fields, {
						name = f.name or ("_bf_" .. i),
						offset = current_bitfield_unit.offset,
						size = storage_size,
						alignment = eff_align,
						original_alignment = storage_align,
						padding_before = 0,
						type = f.type or base_type,
						bits = f.bits,
						bit_offset = bit_offset,
						is_bitfield = true,
						is_first_in_unit = false,
						storage_size = storage_size,
						bits_used_in_unit = current_bitfield_unit.bits_used,
						bitfield_unit_offset = current_bitfield_unit.offset,
						is_zero_width = false,
						is_array = false,
						is_unnamed = not f.name or f.name == "",
					})
					-- offset unchanged
				end
			end
		else
			-- REGULAR FIELD OR ARRAY
			current_bitfield_unit = nil
			local elem_size, elem_align, base_type = resolve_element_info(f)
			local is_array = false
			local array_count
			local element_size = elem_size
			local total_size = elem_size
			if f.count and f.count > 1 then
				if type(f.count) ~= "number" or f.count < 1 or f.count ~= math_floor(f.count) then
					return error(string_format("field %d count must be integer >=1", i))
				end
				is_array = true
				array_count = f.count
				total_size = elem_size * f.count
			elseif f.count == 1 then
				is_array = false
				total_size = elem_size
			end

			local eff_align = elem_align
			if pack then eff_align = math_min(eff_align, pack) end
			memory_alignment.assert_valid_alignment(eff_align)

			local aligned_offset = memory_alignment.align_up(offset, eff_align)
			local padding_before = aligned_offset - offset
			if eff_align > max_align then max_align = eff_align end

			table_insert(layout.fields, {
				name = f.name or ("field_" .. i),
				offset = aligned_offset,
				size = total_size,
				alignment = eff_align,
				original_alignment = elem_align,
				padding_before = padding_before,
				type = f.type or base_type,
				is_array = is_array,
				array_count = array_count,
				element_size = element_size,
				is_bitfield = false,
				bits = nil,
			})
			offset = aligned_offset + total_size
		end
	end

	local struct_align = max_align
	if opts.max_align then
		memory_alignment.assert_valid_alignment(opts.max_align)
		struct_align = math_min(struct_align, opts.max_align)
	end

	local total_size = memory_alignment.align_up(offset, struct_align)
	layout.size = total_size
	layout.alignment = struct_align
	layout.padding_tail = total_size - offset
	layout.unpadded_size = offset
	return layout
end

--- Compute struct size and alignment without the full layout.
---@param fields memory_alignment.FieldSpec[] Field specs.
---@param opts? memory_alignment.LayoutOpts Optional layout options.
---@return integer size Total struct size.
---@return integer alignment Struct alignment.
function memory_alignment.calc_struct_size(fields, opts)
	local l = memory_alignment.calc_struct_layout(fields, opts)
	return l.size, l.alignment
end

----------------------------------------------------------------------
-- Builder API
----------------------------------------------------------------------

---@class memory_alignment.Builder
---@field _specs table Field specifications.
---@field _fields table Computed field layouts.
---@field _offset integer Unpadded end offset.
---@field _max_align integer Current struct alignment.
---@field _pack? integer Pack override.
---@field _max_align_opt? integer Max-align override.
---@field _padding_tail integer Trailing padding bytes.
---@field _layout table Computed layout.
local Builder = {}
Builder.__index = Builder

--- Recompute the layout from the current specs.
function Builder:_recalc()
	local layout = memory_alignment.calc_struct_layout(self._specs,
		{ pack = self._pack, max_align = self._max_align_opt })
	self._fields = layout.fields
	self._offset = layout.unpadded_size
	self._max_align = layout.alignment
	self._total_size = layout.size
	self._padding_tail = layout.padding_tail
	self._layout = layout
end

--- Universal add_field supporting many overloads:
--- ```
--- add_field({name="values", type="float", count=16})
--- add_field("values", {type="float", count=16})
--- add_field("values", "float", 16) -> array
--- add_field("flag", "uint32", {bits=1})
--- add_field("a", 4, 4, "int32")
--- ```
---@overload fun(spec: table): memory_alignment.Builder
---@overload fun(name: string, spec: table): memory_alignment.Builder
---@overload fun(name: string, type: string, count?: integer): memory_alignment.Builder
---@overload fun(name: string, size: integer, alignment: integer): memory_alignment.Builder
---@param a? any Field spec table, or field name.
---@param b? any Spec table, type name, or size.
---@param c? any Count, alignment, type name, or spec table.
---@param d? any Bit count, type name, alignment, or opts table.
---@param e? any Count or opts table.
---@return memory_alignment.Builder builder The builder for chaining.
function Builder:add_field(a, b, c, d, e)
	local spec = {}
	if type(a) == "table" then
		spec = a
	else
		spec.name = a
		if type(b) == "table" then
			for k, v in next, b do spec[k] = v end
		elseif type(b) == "string" then
			spec.type = b
			if type(c) == "number" then
				-- could be count or bits? check if d is table with bits or bits in opts
				-- heuristic: if spec has bits in following table, treat c as not count
				-- default: c is count if no bits specified yet
				if type(d) == "table" and d.bits then
					-- b=type, c maybe unused, d=opts
					for k, v in next, d do spec[k] = v end
				elseif type(c) == "number" and type(d) ~= "table" then
					-- if user did add_field("v", "float", 16) -> count
					-- if user did add_field("flag", "uint32", 1) with bits intent? ambiguous
					-- we treat as count unless opts says bits
					spec.count = c
					if type(d) == "table" then for k, v in next, d do spec[k] = v end end
					if type(d) == "number" then spec.bits = d end
				else
					spec.count = nil
				end
			elseif type(c) == "table" then
				for k, v in next, c do spec[k] = v end
			end
		elseif type(b) == "number" then
			spec.size = b
			if type(c) == "number" then
				spec.alignment = c
				if type(d) == "string" then
					spec.type = d
					if type(e) == "table" then
						for k, v in next, e do spec[k] = v end
					elseif type(e) == "number" then
						spec.count = e
					end
				elseif type(d) == "table" then
					for k, v in next, d do spec[k] = v end
				elseif type(d) == "number" then
					spec.count = d
				end
			elseif type(c) == "string" then
				spec.type = c
				if type(d) == "table" then
					for k, v in next, d do spec[k] = v end
				elseif type(d) == "number" then
					spec.count = d
				end
			elseif type(c) == "table" then
				for k, v in next, c do spec[k] = v end
			end
		end
	end

	-- normalize: if count==1, keep as not array for simplicity
	table_insert(self._specs, spec)
	self:_recalc()
	return self
end

--- Add a C-typed field.
---@param name string Field name.
---@param type_name string C type key.
---@return memory_alignment.Builder builder The builder for chaining.
function Builder:add_c_type(name, type_name)
	return self:add_field(name, type_name)
end

--- Add an array field.
---@param name string Field name.
---@param type_name string C type key.
---@param count integer Element count.
---@param opts? table Extra spec keys merged in.
---@return memory_alignment.Builder builder The builder for chaining.
function Builder:add_array(name, type_name, count, opts)
	local spec = { name = name, type = type_name, count = count }
	if opts then for k, v in next, opts do spec[k] = v end end
	table_insert(self._specs, spec)
	self:_recalc()
	return self
end

--- Add a bitfield.
---@param name string Field name.
---@param type_name string C type key.
---@param bits integer Bit width.
---@param opts? table Extra spec keys merged in.
---@return memory_alignment.Builder builder The builder for chaining.
function Builder:add_bitfield(name, type_name, bits, opts)
	if type(bits) ~= "number" then return error("bits must be number", 2) end
	local spec = { name = name, type = type_name, bits = bits }
	if opts then for k, v in next, opts do spec[k] = v end end
	table_insert(self._specs, spec)
	self:_recalc()
	return self
end

--- Add an unnamed bitfield.
---@param type_name string C type key.
---@param bits integer Bit width.
---@return memory_alignment.Builder builder The builder for chaining.
function Builder:add_bitfield_unnamed(type_name, bits)
	return self:add_bitfield("", type_name, bits)
end

--- Add a zero-width bitfield forcing alignment.
---@param type_name? string C type key (default: "int32").
---@return memory_alignment.Builder builder The builder for chaining.
function Builder:add_zero_width_bitfield(type_name)
	local spec = { name = "", type = type_name or "int32", bits = 0 }
	table_insert(self._specs, spec)
	self:_recalc()
	return self
end

--- Add explicit padding bytes.
---@param size integer Padding bytes (0 or greater).
---@return memory_alignment.Builder builder The builder for chaining.
function Builder:add_padding(size)
	if type(size) ~= "number" or size < 0 then return error("padding size must be >=0", 2) end
	table_insert(self._specs, { name = "_pad_" .. (#self._specs + 1), size = size, alignment = 1, is_padding = true })
	self:_recalc()
	return self
end

--- Return the unpadded end offset.
---@return integer offset Unpadded end offset.
function Builder:current_offset()
	return self._offset
end

--- Return the current struct alignment.
---@return integer alignment Current struct alignment.
function Builder:current_alignment()
	return self._max_align
end

--- Return the computed layout.
---@return memory_alignment.Layout layout The computed layout.
function Builder:build()
	return self._layout
end

--- Clear all specs and recompute.
---@return memory_alignment.Builder builder The builder for chaining.
function Builder:reset()
	self._specs = {}
	self:_recalc()
	return self
end

--- Create a struct layout builder.
---@param opts? table Construction options:
--- - `pack` (integer?, default: nil): Cap applied to every field alignment.
--- - `max_align` (integer?, default: nil): Ceiling for the struct alignment.
---@return memory_alignment.Builder builder The new builder.
function memory_alignment.new_builder(opts)
	opts = opts or {}
	local b = setmetatable(
		{ _specs = {}, _fields = {}, _offset = 0, _max_align = 1, _pack = opts.pack, _max_align_opt = opts.max_align },
		Builder)
	if b._pack then memory_alignment.assert_valid_alignment(b._pack) end
	if b._max_align_opt then memory_alignment.assert_valid_alignment(b._max_align_opt) end
	b:_recalc()
	return b
end

----------------------------------------------------------------------
-- Validation helpers
----------------------------------------------------------------------

--- Check that a buffer fits a layout at an offset.
---@param layout memory_alignment.Layout Computed struct layout.
---@param buffer_size integer Available buffer bytes.
---@param base_offset? integer Base offset (default: 0).
---@return boolean ok True when the buffer fits and is aligned.
---@return string? err Reason when the buffer is unusable.
function memory_alignment.validate_buffer(layout, buffer_size, base_offset)
	base_offset = base_offset or 0
	if buffer_size < layout.size then
		return false, string_format("buffer too small: need %d, have %d", layout.size, buffer_size)
	end
	if not memory_alignment.is_aligned(base_offset, layout.alignment) then
		return false, string_format("base offset %d not aligned to %d", base_offset, layout.alignment)
	end
	return true
end

--- Render a layout as multi-line text.
---@param layout memory_alignment.Layout Computed struct layout.
---@return string text Multi-line layout rendering.
function memory_alignment.format_layout(layout)
	local lines = {}
	table_insert(lines,
		string_format(
			"struct { size=%d, align=%d, tail_pad=%d }",
			layout.size,
			layout.alignment,
			layout.padding_tail or 0
		)
	)
	for _, f in ipairs(layout.fields) do
		if f.is_padding then
			table_insert(lines, string_format("  [padding] offset=%d size=%d", f.offset, f.size))
		elseif f.is_bitfield then
			if f.is_zero_width then
				table_insert(lines, string_format("  [zero-width bitfield] offset=%d type=%s", f.offset, f.type or "?"))
			else
				local name = (f.name and f.name ~= "") and f.name or "<unnamed>"
				table_insert(lines,
					string_format("  %s: offset=%d bit_offset=%d bits=%d storage=%d type=%s %s", name, f.offset,
						f.bit_offset or 0, f.bits or 0, f.storage_size or f.size, f.type or "?",
						f.is_first_in_unit and "[start unit]" or "[cont unit]"))
			end
		elseif f.is_array then
			table_insert(lines,
				string_format("  %s[%d]: offset=%d size=%d (elem=%d) align=%d pad_before=%d (%s)", f.name, f.array_count,
					f.offset, f.size, f.element_size, f.alignment, f.padding_before, f.type or ""))
		else
			table_insert(lines,
				string_format("  %s: offset=%d size=%d align=%d pad_before=%d %s", f.name, f.offset, f.size, f.alignment,
					f.padding_before, f.type and ("(" .. f.type .. ")") or ""))
		end
	end
	return table_concat(lines, "\n")
end

----------------------------------------------------------------------
-- FFI cdef generation
----------------------------------------------------------------------

memory_alignment.c_type_to_cdef = {
	int8 = "int8_t",
	uint8 = "uint8_t",
	char = "char",
	bool = "bool",
	int16 = "int16_t",
	uint16 = "uint16_t",
	short = "int16_t",
	int32 = "int32_t",
	uint32 = "uint32_t",
	int = "int32_t",
	uint = "uint32_t",
	float = "float",
	int64 = "int64_t",
	uint64 = "uint64_t",
	long_long = "int64_t",
	double = "double",
	long_double = "long double",
	pointer = "void*",
	size_t = "size_t",
}

--- Map a layout field to a C type name.
---@param field table Layout field entry.
---@return string ctype C type name for the field.
local function infer_c_type_for_field(field)
	if field.type then
		local mapped = memory_alignment.c_type_to_cdef[field.type]
		if mapped then return mapped end
		return field.type
	end
	if field.element_size == 1 then
		return "uint8_t"
	end
	if field.element_size == 2 then
		return "uint16_t"
	end
	if field.element_size == 4 then
		return "uint32_t"
	end
	if field.element_size == 8 then
		return "uint64_t"
	end
	if field.size == 1 then
		return "uint8_t"
	end
	if field.size == 2 then
		return "uint16_t"
	end
	if field.size == 4 then
		return "uint32_t"
	end
	if field.size == 8 then
		return "uint64_t"
	end
	return "uint8_t"
end

--- Look up a C type size in bytes.
---@param c_type string C type name.
---@return integer size Size in bytes (1 when unknown).
local function c_type_size(c_type)
	for k, v in next, memory_alignment.c_type_to_cdef do
		if v == c_type or k == c_type then
			local info = memory_alignment.c_types[k]
			if info then return info.size end
		end
	end
	if c_type == "float" then
		return 4
	end
	if c_type == "double" then
		return 8
	end
	if string_find(c_type, "int8_t", nil, true) or string_find(c_type, "char", nil, true) then
		return 1
	end
	if string_find(c_type, "int16_t", nil, true) then
		return 2
	end
	if string_find(c_type, "int32_t", nil, true) then
		return 4
	end
	if string_find(c_type, "int64_t", nil, true) then
		return 8
	end
	return 1
end

--- Generate a C struct or union declaration from a layout or field array.
---@param layout_or_fields memory_alignment.Layout|table Computed layout or field array.
---@param struct_name? string Struct name (default: "MyStruct").
---@param opts? table Cdef options:
--- - `indent` (string, default: `"  "`): Indent string.
--- - `padding_prefix` (string, default: `"_pad"`): Padding field name prefix.
--- - `explicit_padding` (boolean, default: true): Emit padding fields.
--- - `comment_offsets` (boolean, default: true): Append offset comments.
--- - `use_attribute_aligned` (boolean, default: true): Emit aligned attribute.
--- - `typedef` (boolean, default: true): Emit typedef form.
--- - `use_pragma_pack` (boolean, default: false): Emit pack push/pop.
--- - `pack` (integer?, default: nil): Pack value for pragma and layout calc.
--- - `packed` (boolean, default: false): Emit packed attribute.
--- - `is_union` (boolean, default: false): Emit union instead of struct.
--- - `header` (string?, default: nil): Header line.
---@return string cdef Generated C declaration text.
function memory_alignment.generate_cdef(layout_or_fields, struct_name, opts)
	struct_name = struct_name or "MyStruct"
	opts = opts or {}
	local indent = opts.indent or "  "
	local padding_prefix = opts.padding_prefix or "_pad"
	local explicit_padding = opts.explicit_padding
	if explicit_padding == nil then explicit_padding = true end
	local comment_offsets = opts.comment_offsets
	if comment_offsets == nil then comment_offsets = true end
	local use_aligned = opts.use_attribute_aligned
	if use_aligned == nil then use_aligned = true end

	local layout
	if layout_or_fields.fields and layout_or_fields.size then
		layout = layout_or_fields
	else
		local calc_opts = {}
		if opts.pack then calc_opts.pack = opts.pack end
		layout = memory_alignment.calc_struct_layout(layout_or_fields, calc_opts)
	end

	local lines = {}
	local pad_counter = 0

	if opts.header then table_insert(lines, opts.header) end
	if opts.use_pragma_pack and opts.pack then
		table_insert(lines, string_format("#pragma pack(push, %d)", opts.pack))
	end

	local struct_keyword = opts.is_union and "union" or "struct"
	local packed_attr = ""
	if opts.packed then packed_attr = " __attribute__((packed))" end

	if opts.typedef == false then
		table_insert(lines, string_format("%s%s %s {", struct_keyword, packed_attr, struct_name))
	else
		if packed_attr ~= "" then
			table_insert(lines, string_format("typedef %s%s %s {", struct_keyword, packed_attr, struct_name))
		else
			table_insert(lines, string_format("typedef %s %s {", struct_keyword, struct_name))
		end
	end

	local cur_offset = 0
	local bf_unit_open = false
	local bf_unit_offset = 0
	local bf_unit_size = 0
	local bf_unit_remaining = 0

	local function emit_padding(gap, comment)
		if not explicit_padding or gap <= 0 then return end
		local cmt = comment_offsets and comment or ""
		if gap == 1 then
			table_insert(lines, string_format("%suint8_t %s%d;%s", indent, padding_prefix, pad_counter, cmt))
		else
			table_insert(lines, string_format("%suint8_t %s%d[%d];%s", indent, padding_prefix, pad_counter, gap, cmt))
		end
		pad_counter = pad_counter + 1
	end

	for _, f in ipairs(layout.fields) do
		if f.is_padding then
			bf_unit_open = false
			if explicit_padding then
				local cmt = comment_offsets and string_format(" // offset=%d", f.offset) or ""
				emit_padding(0, "") -- dummy to use helper? directly emit
				if f.size == 1 then
					table_insert(lines, string_format("%suint8_t %s%d;%s", indent, padding_prefix, pad_counter, cmt))
				else
					table_insert(lines,
						string_format("%suint8_t %s%d[%d];%s", indent, padding_prefix, pad_counter, f.size, cmt))
				end
				pad_counter = pad_counter + 1
			end
			cur_offset = f.offset + f.size
		elseif f.is_bitfield then
			if f.is_zero_width then
				-- zero-width: emit and close unit
				local c_type = infer_c_type_for_field(f)
				local cmt = comment_offsets and string_format(" // zero-width, align to %d", f.alignment) or ""
				if f.name and f.name ~= "" then
					table_insert(lines, string_format("%s%s %s : 0;%s", indent, c_type, f.name, cmt))
				else
					table_insert(lines, string_format("%s%s : 0;%s", indent, c_type, cmt))
				end
				bf_unit_open = false
				cur_offset = f.offset
			else
				-- if this bitfield starts a new storage unit, handle gap
				if f.is_first_in_unit then
					if f.offset > cur_offset then
						emit_padding(f.offset - cur_offset,
							comment_offsets and string_format(" // auto padding, gap to offset %d", f.offset) or "")
					end
					bf_unit_open = true
					bf_unit_offset = f.offset
					bf_unit_size = f.storage_size
					bf_unit_remaining = (f.storage_size * 8) - f.bits
					cur_offset = f.offset + f.storage_size
				else
					-- continuation, no offset change
					bf_unit_remaining = bf_unit_remaining - f.bits
				end

				local c_type = infer_c_type_for_field(f)
				local cmt = ""
				if comment_offsets then
					cmt = string_format(" // offset=%d bit_offset=%d bits=%d", f.offset, f.bit_offset or 0, f.bits)
				end

				if f.is_unnamed or f.name == "" then
					table_insert(lines, string_format("%s%s : %d;%s", indent, c_type, f.bits, cmt))
				else
					table_insert(lines, string_format("%s%s %s : %d;%s", indent, c_type, f.name, f.bits, cmt))
				end
			end
		else
			-- regular or array
			bf_unit_open = false
			if f.offset > cur_offset then
				emit_padding(f.offset - cur_offset,
					comment_offsets and string_format(" // auto padding, gap to offset %d", f.offset) or "")
				cur_offset = f.offset
			end

			local c_type = infer_c_type_for_field(f)
			local decl
			if f.is_array then
				decl = string_format("%s %s[%d]", c_type, f.name, f.array_count)
			else
				local type_size = c_type_size(c_type)
				if f.size > type_size and type_size > 0 and f.size % type_size == 0 and not f.is_array then
					local count = math_floor(f.size / type_size)
					if count > 1 then
						decl = string_format("%s %s[%d]", c_type, f.name, count)
					else
						decl = string_format("%s %s", c_type, f.name)
					end
				else
					decl = string_format("%s %s", c_type, f.name)
				end
			end

			local comment = ""
			if comment_offsets then
				if f.is_array then
					comment = string_format(" // offset=%d size=%d (elem=%d count=%d) align=%d", f.offset, f.size,
						f.element_size, f.array_count, f.alignment)
				else
					comment = string_format(" // offset=%d size=%d align=%d", f.offset, f.size, f.alignment)
				end
			end
			table_insert(lines, string_format("%s%s;%s", indent, decl, comment))
			cur_offset = f.offset + f.size
		end
	end

	if layout.padding_tail and layout.padding_tail > 0 and explicit_padding then
		local cmt = comment_offsets and string_format(" // tail padding, struct size %d", layout.size) or ""
		emit_padding(layout.padding_tail, cmt)
	end

	local aligned_attr = ""
	if use_aligned and layout.alignment and layout.alignment > 1 and not opts.packed then
		aligned_attr = string_format(" __attribute__((aligned(%d)))", layout.alignment)
	end

	if opts.typedef == false then
		if aligned_attr ~= "" then
			table_insert(lines, string_format("}%s;", aligned_attr))
		else
			table_insert(lines, "};")
		end
	else
		if aligned_attr ~= "" then
			table_insert(lines, string_format("}%s %s;", aligned_attr, struct_name))
		else
			table_insert(lines, string_format("} %s;", struct_name))
		end
	end

	if opts.use_pragma_pack and opts.pack then
		table_insert(lines, "#pragma pack(pop)")
	end

	return table_concat(lines, "\n")
end

--- Generate a C declaration from a builder.
---@param builder memory_alignment.Builder Configured builder.
---@param struct_name? string Struct name (default: "MyStruct").
---@param opts? table Options forwarded to generate_cdef.
---@return string cdef Generated C declaration text.
function memory_alignment.generate_cdef_from_builder(builder, struct_name, opts)
	if type(builder) ~= "table" or not builder.build then
		return error("builder must be memory_alignment.new_builder() instance", 2)
	end
	return memory_alignment.generate_cdef(builder:build(), struct_name, opts)
end

--- Generate C declarations for several structs.
---@param structs_table table Struct name to field array mapping.
---@param opts? table Options forwarded to generate_cdef.
---@return string defs Concatenated C declarations.
function memory_alignment.generate_cdefs(structs_table, opts)
	opts = opts or {}
	local parts = {}
	for name, def in next, structs_table do
		table_insert(parts, memory_alignment.generate_cdef(def, name, opts))
	end
	return table_concat(parts, "\n\n")
end

-- Export
return memory_alignment
