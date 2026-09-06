-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- A concise, expressive way to call functions with named parameters and type checking.
-- Provides function wrappers that accept named or positional arguments with runtime validation.

-- Localized global functions for better performance
local error = error
local next = next
local pcall = pcall
local rawget = rawget
local select = select
local setmetatable = setmetatable
local tostring = tostring
local type = type
local debug_getinfo = debug and debug.getinfo
local math_floor = math.floor
local math_huge = math.huge
local math_type = math.type
local string_format = string.format
local string_gmatch = string.gmatch
local string_match = string.match
local string_sub = string.sub
local table_concat = table.concat
local table_unpack = table.unpack or unpack

local M = {}

--- Sentinel value for explicitly passing nil as a named argument.
--- When a parameter is optional and you want to explicitly pass nil, use `M.NULL` instead of `nil`.
local NULL = setmetatable({}, {
	__tostring = function()
		return "concise_call.NULL"
	end,
})

M.NULL = NULL

--- Empty table used as a default for empty named argument tables.
local EMPTY = {}

--- Weak-keyed registry for storing wrapper metadata.
local registry = setmetatable({}, {
	__mode = "k",
})

-- Lua 5.1 fallback for table.pack.
local table_pack = table.pack or function(...)
	return {
		n = select("#", ...),
		...,
	}
end

--- Raises a formatted error with the `concise_call:` prefix.
---@param msg string The error message.
local function raise(msg)
	return error("concise_call: " .. msg, 0)
end

--- Safely converts a value to string, handling NULL and unprintable values.
---@param v any The value to convert.
---@return string s The string representation.
local function safe_tostring(v)
	if v == NULL then
		return "concise_call.NULL"
	end

	local ok, s = pcall(tostring, v)
	if ok then
		return s
	end

	return "<unprintable>"
end

--- Checks if a value is an integer (handles Lua 5.3+ math.type if available).
---@param v any The value to check.
---@return boolean result True if the value is an integer.
local function is_integer_value(v)
	if type(v) ~= "number" then
		return false
	end

	if math_type then
		local mt = math_type(v)

		if mt == "integer" then
			return true
		end

		if mt ~= "float" then
			return false
		end
	end

	return v == math_floor(v) and v ~= math_huge and v ~= -math_huge
end

--- Checks if a key is a positive integer (>= 1).
---@param k any The key to check.
---@return boolean result True if the key is a positive integer.
local function is_positive_integer_key(k)
	return type(k) == "number" and k >= 1 and is_integer_value(k)
end

--- Validates and returns the length of an array-like table with contiguous integer keys.
---@param list table The table to validate.
---@param what string Description prefix for error messages.
---@return number count The number of elements.
local function list_length(list, what)
	local count = 0
	local max = 0

	for k in next, list do
		if not is_positive_integer_key(k) then
			return raise(what .. " must be an array-like table with positive integer keys")
		end

		count = count + 1

		if k > max then
			max = k
		end
	end

	if count ~= max then
		return raise(what .. " has holes or non-contiguous keys")
	end

	return count
end

--- Checks if a table is a non-empty sequence with contiguous integer keys starting at 1.
---@param t any The value to check.
---@return boolean result True if the table is a non-empty sequence.
local function is_sequence_nonempty(t)
	if type(t) ~= "table" then
		return false
	end

	local count = 0
	local max = 0

	for k in next, t do
		if not is_positive_integer_key(k) then
			return false
		end

		count = count + 1

		if k > max then
			max = k
		end
	end

	return count > 0 and count == max
end

--- Invokes a function with arguments from a packed table.
---@param fn function The function to call.
---@param args table The arguments table.
---@param n number The number of arguments to pass.
---@return any ... The return values from the function.
local function invoke(fn, args, n)
	if table_unpack == nil then
		return raise("table.unpack/unpack is not available in this Lua environment")
	end

	return fn(table_unpack(args, 1, n))
end

--- Formats a key for display in error messages.
---@param k any The key to format.
---@return string s The formatted key string.
local function format_key(k)
	if type(k) == "string" then
		return string_format("%q", k)
	end

	return safe_tostring(k)
end

--- Describes a value for display in error messages.
---@param v any The value to describe.
---@return string s The description string.
local function describe_value(v)
	if v == nil then
		return "nil"
	end

	if v == NULL then
		return "concise_call.NULL"
	end

	local tv = type(v)

	if tv == "string" then
		if #v > 50 then
			return string_format("%q...", string_sub(v, 1, 50))
		end

		return string_format("%q", v)
	end

	if tv == "number" or tv == "boolean" then
		return tostring(v)
	end

	return tv
end

--- Trims leading and trailing whitespace from a string.
---@param s string The string to trim.
---@return string s The trimmed string.
local function trim(s)
	return (string_match(s, "^%s*(.-)%s*$"))
end

--- Matches a value against a type specification string (supports `|` for unions).
---@param value any The value to check.
---@param spec string The type specification string.
---@return boolean result True if the value matches the spec.
local function match_type_string(value, spec)
	for part in string_gmatch(spec, "[^|]+") do
		part = trim(part)

		if part == "any" then
			return true
		end

		if value == nil then
			if part == "nil" then
				return true
			end
		else
			if part == "integer" then
				if is_integer_value(value) then
					return true
				end
			elseif type(value) == part then
				return true
			end
		end
	end

	return false
end

--- Matches a value against a type specification (string, function, or table of specs).
---@param value any The value to check.
---@param spec any The type specification.
---@return boolean ok True if the value matches.
---@return string? err Error message if validation failed.
local function match_spec(value, spec)
	if spec == nil or spec == "any" then
		return true
	end

	local ts = type(spec)

	if ts == "string" then
		return match_type_string(value, spec)
	end

	if ts == "function" then
		local ok, res = pcall(spec, value)

		if not ok then
			return false, res
		end

		return res == true
	end

	if ts == "table" then
		local errs = {}

		for i = 1, #spec do
			local ok, err = match_spec(value, spec[i])

			if ok then
				return true
			end

			if err ~= nil then
				errs[#errs + 1] = safe_tostring(err)
			end
		end

		if #errs > 0 then
			return false, table_concat(errs, "; ")
		end

		return false
	end

	return false, "invalid type spec"
end

--- Describes a type specification for display in error messages.
---@param spec any The type specification.
---@return string s The description string.
local function describe_spec(spec)
	if spec == nil then
		return "any"
	end

	local ts = type(spec)

	if ts == "string" then
		return spec
	end

	if ts == "function" then
		return "custom"
	end

	if ts == "table" then
		local parts = {}

		for i = 1, #spec do
			parts[i] = describe_spec(spec[i])
		end

		if #parts > 0 then
			return table_concat(parts, "|")
		end

		return "invalid"
	end

	return safe_tostring(spec)
end

--- Validates the structure of a type specification at definition time.
---@param spec any The type specification to validate.
---@param what string Description prefix for error messages.
local function validate_spec(spec, what)
	if spec == nil or spec == "any" then
		return
	end

	local ts = type(spec)

	if ts == "string" or ts == "function" then
		return
	end

	if ts == "table" then
		local n = list_length(spec, what)

		if n == 0 then
			return raise(what .. " must not be empty")
		end

		for i = 1, n do
			validate_spec(spec[i], what .. "[" .. i .. "]")
		end

		return
	end

	return raise(what .. " must be nil, 'any', string, function, or table of types")
end

--- Deep-copies a type specification table.
---@param spec any The type specification to copy.
---@return any copy The copied specification.
local function copy_spec(spec)
	if type(spec) ~= "table" then
		return spec
	end

	local n = list_length(spec, "type spec table")
	local out = {}

	for i = 1, n do
		out[i] = copy_spec(spec[i])
	end

	return out
end

--- Raises a descriptive error for a parameter validation failure.
---@param meta table The wrapper metadata.
---@param p table The parameter definition.
---@param expected? string Expected type description.
---@param got? string Actual value description.
---@param extra? string Additional context.
local function raise_param(meta, p, expected, got, extra)
	local msg = string_format(
		"%s: parameter '%s' expected %s, got %s",
		meta.name or "<anonymous>",
		p.name,
		expected or "?",
		got or "?"
	)

	if extra and extra ~= "" then
		msg = string_format("%s (%s)", msg, extra)
	end

	return raise(msg)
end

--- Validates a parameter value against its type specification or custom validator.
---@param meta table The wrapper metadata.
---@param p table The parameter definition.
---@param value any The value to validate.
local function validate_value(meta, p, value)
	if p.validator then
		local ok, res = pcall(p.validator, value)

		if not ok then
			raise_param(
				meta,
				p,
				"validator to succeed",
				describe_value(value),
				safe_tostring(res)
			)
		end

		if res ~= true then
			raise_param(
				meta,
				p,
				"validator to return true",
				describe_value(value)
			)
		end

		return
	end

	local ok, err = match_spec(value, p.type)

	if not ok then
		raise_param(
			meta,
			p,
			describe_spec(p.type),
			describe_value(value),
			err and safe_tostring(err) or nil
		)
	end
end

--- Normalizes a user-provided signature table into a canonical parameter list.
---@param sig table The signature table.
---@return table params The normalized parameter list.
---@return table name_set Set of parameter names for fast lookup.
local function normalize_signature(sig)
	local n = list_length(sig, "signature")

	local params = {}
	local name_set = {}

	for i = 1, n do
		local entry = sig[i]

		if type(entry) ~= "table" then
			return raise("signature[" .. i .. "] must be a table")
		end

		local array_name = entry[1]
		local object_name = entry.name

		local has_array_name = type(array_name) == "string"
		local has_object_name = type(object_name) == "string"

		if not has_array_name and not has_object_name then
			return raise("signature[" .. i .. "] must contain a string name")
		end

		if has_array_name and has_object_name and array_name ~= object_name then
			return raise("signature[" .. i .. "] has conflicting names")
		end

		local name = has_array_name and array_name or object_name

		if name == "" then
			return raise("signature[" .. i .. "] has an empty parameter name")
		end

		if name_set[name] then
			return raise("duplicate parameter name: " .. format_key(name))
		end

		local array_type = entry[2]
		local object_type = entry.type

		local has_array_type = array_type ~= nil
		local has_object_type = object_type ~= nil

		local spec

		if has_object_type then
			spec = object_type
		end

		if has_array_type then
			if spec ~= nil and spec ~= array_type then
				return raise("signature[" .. i .. "] has conflicting type specs")
			end

			spec = array_type
		end

		local opt_array = entry[3]
		local opt_object = entry.optional

		if opt_array ~= nil and type(opt_array) ~= "boolean" then
			return raise("signature[" .. i .. "][3] must be a boolean")
		end

		if opt_object ~= nil and type(opt_object) ~= "boolean" then
			return raise("signature[" .. i .. "].optional must be a boolean")
		end

		if opt_array ~= nil and opt_object ~= nil and opt_array ~= opt_object then
			return raise("signature[" .. i .. "] has conflicting optional flags")
		end

		local optional = opt_array == true or opt_object == true

		local validator = entry.validator

		if validator ~= nil and type(validator) ~= "function" then
			return raise("signature[" .. i .. "].validator must be a function")
		end

		local has_default_flag = entry.has_default

		if has_default_flag ~= nil and type(has_default_flag) ~= "boolean" then
			return raise("signature[" .. i .. "].has_default must be a boolean")
		end

		local array_default = entry[4]
		local object_default = entry.default

		local has_array_default = array_default ~= nil
		local has_object_default = object_default ~= nil

		if has_array_default and has_object_default and array_default ~= object_default then
			return raise("signature[" .. i .. "] has conflicting default values")
		end

		local default

		if has_array_default then
			default = array_default
		elseif has_object_default then
			default = object_default
		end

		local has_default = has_array_default
			or has_object_default
			or has_default_flag == true

		if default == NULL then
			default = nil
		end

		validate_spec(spec, "signature[" .. i .. "].type")

		params[i] = {
			name = name,
			type = copy_spec(spec),
			optional = optional,
			validator = validator,
			has_default = has_default,
			default = default,
		}

		name_set[name] = true
	end

	return params, name_set
end

--- Creates a read-only copy of the parameter list for public inspection.
---@param params table The internal parameter list.
---@return table out The public signature table.
local function public_signature(params)
	local out = {}

	for i = 1, #params do
		local p = params[i]

		out[i] = {
			name = p.name,
			type = copy_spec(p.type),
			optional = p.optional,
			validator = p.validator,
			has_default = p.has_default,
			default = p.default,
		}
	end

	return out
end

--- Creates a callable wrapper object with named, positional, and auto call modes.
---@param fn function The original function to wrap.
---@param meta table The wrapper metadata.
---@return table obj The callable wrapper object.
local function create_wrapper(fn, meta)
	local params = meta.params
	local param_count = #params
	local name_set = meta.name_set

	--- Binds named arguments from a table to the parameter list.
	---@param args_table table The named arguments table.
	---@return any ... The return values from the wrapped function.
	local function bind_named(args_table)
		if meta.strict_unknown then
			for k in next, args_table do
				if type(k) ~= "string" or not name_set[k] then
					return raise(
						string_format(
							"%s: unknown named argument %s",
							meta.name or "<anonymous>",
							format_key(k)
						)
					)
				end
			end
		end

		local call_args = {}

		for i = 1, param_count do
			local p = params[i]

			local raw = rawget(args_table, p.name)
			local has_value = (raw ~= nil) or (raw == NULL)

			local value = raw

			if raw == NULL then
				value = nil
			end

			local skip_validation = false

			if not has_value then
				if p.has_default then
					value = p.default
				elseif p.optional then
					value = nil
					skip_validation = true
				else
					raise_param(meta, p, describe_spec(p.type), "missing")
				end
			end

			if not skip_validation and value == nil and p.optional then
				skip_validation = true
			end

			if not skip_validation then
				validate_value(meta, p, value)
			end

			call_args[i] = value
		end

		return invoke(fn, call_args, param_count)
	end

	--- Binds positional arguments from a packed table to the parameter list.
	---@param packed table The packed arguments table (with `.n` field).
	---@return any ... The return values from the wrapped function.
	local function bind_positional(packed)
		if packed.n > param_count and not meta.allow_extra_positional then
			return raise(
				string_format(
					"%s: too many positional arguments (expected at most %d, got %d)",
					meta.name or "<anonymous>",
					param_count,
					packed.n
				)
			)
		end

		local call_args = {}

		for i = 1, param_count do
			local p = params[i]

			local has_value = i <= packed.n
			local value = packed[i]

			if value == NULL then
				value = nil
			end

			local skip_validation = false

			if not has_value then
				if p.has_default then
					value = p.default
				elseif p.optional then
					value = nil
					skip_validation = true
				else
					raise_param(meta, p, describe_spec(p.type), "missing")
				end
			end

			if not skip_validation and value == nil and p.optional then
				skip_validation = true
			end

			if not skip_validation then
				validate_value(meta, p, value)
			end

			call_args[i] = value
		end

		local call_n = param_count

		if meta.allow_extra_positional and packed.n > param_count then
			call_n = packed.n

			for i = param_count + 1, packed.n do
				call_args[i] = packed[i]
			end
		end

		return invoke(fn, call_args, call_n)
	end

	--- Detects whether an auto-detect call should use named mode.
	---@param packed table The packed arguments table.
	---@return boolean use_named True if the call should use named binding.
	local function detect_named_auto(packed)
		if meta.call_style == "named" then
			return true
		end

		if meta.call_style == "positional" then
			return false
		end

		-- Empty call is safer as named.
		if packed.n == 0 then
			return true
		end

		if packed.n == 1 and type(packed[1]) == "table" then
			local t = packed[1]

			-- Empty table is treated as named args, not one positional empty table.
			if next(t) == nil then
				return true
			end

			return not is_sequence_nonempty(t)
		end

		return false
	end

	--- Auto-detects call mode and dispatches to named or positional binding.
	---@return any ... The return values from the wrapped function.
	local function call_auto(...)
		local packed = table_pack(...)
		local use_named = detect_named_auto(packed)

		if use_named then
			if packed.n == 0 then
				return bind_named(EMPTY)
			end

			if packed.n == 1 and type(packed[1]) == "table" then
				return bind_named(packed[1])
			end

			return raise(
				string_format(
					"%s: named call expects zero or one table argument",
					meta.name or "<anonymous>"
				)
			)
		end

		return bind_positional(packed)
	end

	--- Wrapper object returned by `M.register`. Callable via `__call` metamethod.
	--- Provides `.named()`, `.positional()`, and `.call()` methods.
	local obj = {}

	obj.named = function(args)
		if args == nil then
			args = EMPTY
		end

		if type(args) ~= "table" then
			return raise(
				string_format(
					"%s: named arguments must be a table",
					meta.name or "<anonymous>"
				)
			)
		end

		return bind_named(args)
	end

	obj.positional = function(...)
		return bind_positional(table_pack(...))
	end

	-- Plain function escape hatch.
	obj.call = call_auto

	return setmetatable(obj, {
		__call = function(_, ...)
			return call_auto(...)
		end,
		__metatable = "concise_call.wrapper",
	})
end

--- Wraps a function with type-checked named/positional parameter support.<br>
--- Returns a callable table that validates arguments at runtime.<br>
--- Supports named, positional, and auto-detected call styles.
---@param fn function The function to wrap.
---@param signature? table Array of parameter definitions. Each entry is `{name, type, optional, default}`, or a table with `.name`, `.type`, `.optional`, `.default`, `.validator` fields.
---@param opts? table Optional options table:
--- - `name` (string): Explicit name for error messages; defaults to debug info.
--- - `call_style` (string, default: "auto"): "auto"|"named"|"positional".
--- - `strict_unknown` (boolean, default: true): If true, reject unknown named arguments.
--- - `allow_extra_positional` (boolean, default: false): If true, allow extra positional args beyond the signature.
---@return table wrapper Callable wrapper with `.named()`, `.positional()`, `.call()`, and `__call` metamethod.
---@usage <br>
--- ```
--- local add = concise_call.register(function(a, b)
---   return a + b
--- end, {
---   { "a", "number" },
---   { "b", "number" },
--- })
---
--- add(2, 3)             -- positional: 5
--- add({ a = 2, b = 3 }) -- named: 5
--- ```
function M.register(fn, signature, opts)
	if type(fn) ~= "function" then
		return raise("first argument must be a function")
	end

	if signature == nil then
		signature = EMPTY
	end

	if type(signature) ~= "table" then
		return raise("signature must be a table or nil")
	end

	if opts == nil then
		opts = EMPTY
	end

	if type(opts) ~= "table" then
		return raise("opts must be a table")
	end

	local params, name_set = normalize_signature(signature)

	local call_style = opts.call_style or "auto"

	if call_style ~= "auto" and call_style ~= "named" and call_style ~= "positional" then
		return raise("opts.call_style must be 'auto', 'named', or 'positional'")
	end

	local strict_unknown = opts.strict_unknown ~= false
	local allow_extra_positional = opts.allow_extra_positional == true

	local name = opts.name

	if name ~= nil then
		if type(name) ~= "string" or name == "" then
			return raise("opts.name must be a non-empty string")
		end
	else
		if debug_getinfo then
			local ok, info = pcall(debug_getinfo, fn, "n")

			if ok and type(info) == "table" and type(info.name) == "string" and info.name ~= "" then
				name = info.name
			end
		end
	end

	local meta = {
		params = params,
		name_set = name_set,
		name = name,
		call_style = call_style,
		strict_unknown = strict_unknown,
		allow_extra_positional = allow_extra_positional,
	}

	meta.public_signature = public_signature(params)

	local wrapper = create_wrapper(fn, meta)

	registry[wrapper] = meta

	-- Compatibility/metadata fields.
	wrapper.__concise_signature = meta.public_signature
	wrapper.__concise_original = fn
	wrapper.__concise_name = name

	return wrapper
end

--- Retrieves the parameter signature of a wrapper created by `M.register`.<br>
--- Falls back to the `__concise_signature` field for compatibility.
---@param wrapper any The value to inspect.
---@return table? signature Array of parameter definition tables, or nil if not a wrapper.
function M.signature_of(wrapper)
	local meta = registry[wrapper]

	if meta then
		return meta.public_signature
	end

	local t = type(wrapper)

	if t == "function" or t == "table" then
		return wrapper.__concise_signature
	end

	return nil
end

--- Checks whether a value was created by `M.register`.
---@param wrapper any The value to check.
---@return boolean result True if the value is a concise_call wrapper.
function M.is_wrapper(wrapper)
	return registry[wrapper] ~= nil
end

--[=[ Quick tests
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
	print("[concise_call] testing...")

	-- M.register basic
	test("register wraps a function", function()
		local add = M.register(function(a, b)
			return a + b
		end, {
			{ "a", "number" },
			{ "b", "number" },
		})
		assert(type(add) == "table")
		assert(M.is_wrapper(add))
	end)

	-- positional call
	test("positional call", function()
		local add = M.register(function(a, b)
			return a + b
		end, {
			{ "a", "number" },
			{ "b", "number" },
		})
		assert(add(2, 3) == 5)
	end)

	-- named call via __call
	test("named call via __call", function()
		local add = M.register(function(a, b)
			return a + b
		end, {
			{ "a", "number" },
			{ "b", "number" },
		})
		assert(add({ a = 2, b = 3 }) == 5)
	end)

	-- explicit .named() method
	test("explicit .named() method", function()
		local add = M.register(function(a, b)
			return a + b
		end, {
			{ "a", "number" },
			{ "b", "number" },
		})
		assert(add.named({ a = 10, b = 20 }) == 30)
	end)

	-- explicit .positional() method
	test("explicit .positional() method", function()
		local add = M.register(function(a, b)
			return a + b
		end, {
			{ "a", "number" },
			{ "b", "number" },
		})
		assert(add.positional(10, 20) == 30)
	end)

	-- .call() method (auto-detect)
	test(".call() method auto-detect", function()
		local add = M.register(function(a, b)
			return a + b
		end, {
			{ "a", "number" },
			{ "b", "number" },
		})
		assert(add.call(2, 3) == 5)
		assert(add.call({ a = 2, b = 3 }) == 5)
	end)

	-- type validation: correct type passes
	test("correct type passes", function()
		local fn = M.register(function(x)
			return x
		end, { { "x", "string" } })
		assert(fn("hello") == "hello")
	end)

	-- type validation: wrong type errors
	test("wrong type errors", function()
		local fn = M.register(function(x)
			return x
		end, { { "x", "string" } })
		expect_error(function()
			fn(123)
		end, "expected string")
	end)

	-- type validation: nil for required errors
	test("nil for required errors", function()
		local fn = M.register(function(x)
			return x
		end, { { "x", "string" } })
		expect_error(function()
			fn()
		end, "missing")
	end)

	-- optional parameter
	test("optional parameter", function()
		local fn = M.register(function(a, b)
			return a + (b or 0)
		end, {
			{ "a", "number" },
			{ "b", "number", true },
		})
		assert(fn(5) == 5)
		assert(fn(5, 3) == 8)
	end)

	-- optional named parameter
	test("optional named parameter", function()
		local fn = M.register(function(a, b)
			return a + (b or 0)
		end, {
			{ "a", "number" },
			{ "b", "number", true },
		})
		assert(fn({ a = 5 }) == 5)
		assert(fn({ a = 5, b = 3 }) == 8)
	end)

	-- default value
	test("default value", function()
		local fn = M.register(function(a, b)
			return a + b
		end, {
			{ "a", "number" },
			{ "b", "number", false, 10 },
		})
		assert(fn(5) == 15)
		assert(fn(5, 3) == 8)
	end)

	-- default value with named call
	test("default value with named call", function()
		local fn = M.register(function(a, b)
			return a + b
		end, {
			{ "a", "number" },
			{ "b", "number", false, 10 },
		})
		assert(fn({ a = 5 }) == 15)
	end)

	-- M.NULL sentinel for explicit nil
	test("M.NULL sentinel for explicit nil", function()
		local fn = M.register(function(a, b)
			return a, b
		end, {
			{ "a", "number" },
			{ "b", "number", true },
		})
		local x, y = fn({ a = 1, b = M.NULL })
		assert(x == 1)
		assert(y == nil)
	end)

	-- union type spec (table of types)
	test("union type spec", function()
		local fn = M.register(function(x)
			return type(x)
		end, { { "x", { "string", "number" } } })
		assert(fn("hello") == "string")
		assert(fn(42) == "number")
		expect_error(function()
			fn(true)
		end, "expected")
	end)

	-- custom validator
	test("custom validator", function()
		local fn = M.register(function(x)
			return x
		end, {
			{
				"x",
				"number",
				validator = function(v)
					return v > 0
				end,
			},
		})
		assert(fn(5) == 5)
		expect_error(function()
			fn(-1)
		end, "validator")
	end)

	-- call_style "named" forces named mode
	test("call_style 'named' forces named mode", function()
		local fn = M.register(function(a, b)
			return a + b
		end, {
			{ "a", "number" },
			{ "b", "number" },
		}, { call_style = "named" })
		assert(fn({ a = 2, b = 3 }) == 5)
		expect_error(function()
			fn(2, 3)
		end, "named call expects")
	end)

	-- call_style "positional" forces positional mode
	test("call_style 'positional' forces positional mode", function()
		local fn = M.register(function(a, b)
			return a + b
		end, {
			{ "a", "number" },
			{ "b", "number" },
		}, { call_style = "positional" })
		assert(fn(2, 3) == 5)
		expect_error(function()
			fn({ a = 2, b = 3 })
		end, "expected number")
	end)

	-- strict_unknown rejects unknown named args
	test("strict_unknown rejects unknown named args", function()
		local fn = M.register(function(a)
			return a
		end, {
			{ "a", "number" },
		}, { strict_unknown = true })
		expect_error(function()
			fn({ a = 1, z = 99 })
		end, "unknown named argument")
	end)

	-- strict_unknown = false allows unknown named args
	test("strict_unknown = false allows unknown named args", function()
		local fn = M.register(function(a)
			return a
		end, {
			{ "a", "number" },
		}, { strict_unknown = false })
		assert(fn({ a = 1, z = 99 }) == 1)
	end)

	-- allow_extra_positional
	test("allow_extra_positional", function()
		local args = {}
		local fn = M.register(function(a, b)
			args.a = a
			args.b = b
		end, {
			{ "a", "number" },
			{ "b", "number" },
		}, { allow_extra_positional = true })
		fn(1, 2, 3, 4)
		assert(args.a == 1)
		assert(args.b == 2)
	end)

	-- too many positional args without allow_extra_positional
	test("too many positional args without allow_extra_positional", function()
		local fn = M.register(function(a, b)
			return a + b
		end, {
			{ "a", "number" },
			{ "b", "number" },
		})
		expect_error(function()
			fn(1, 2, 3)
		end, "too many positional arguments")
	end)

	-- empty signature (no params)
	test("empty signature (no params)", function()
		local fn = M.register(function()
			return 42
		end)
		assert(fn() == 42)
		assert(fn({}) == 42)
	end)

	-- object-style signature entries
	test("object-style signature entries", function()
		local fn = M.register(function(x)
			return x * 2
		end, {
			{ name = "x", type = "number" },
		})
		assert(fn(5) == 10)
		assert(fn({ x = 5 }) == 10)
	end)

	-- M.signature_of retrieves signature
	test("M.signature_of retrieves signature", function()
		local fn = M.register(function(a, b)
			return a + b
		end, {
			{ "a", "number" },
			{ "b", "number" },
		})
		local sig = M.signature_of(fn)
		assert(type(sig) == "table")
		assert(#sig == 2)
		assert(sig[1].name == "a")
		assert(sig[2].name == "b")
	end)

	-- M.is_wrapper returns false for non-wrappers
	test("M.is_wrapper returns false for non-wrappers", function()
		assert(M.is_wrapper(function() end) == false)
		assert(M.is_wrapper({}) == false)
		assert(M.is_wrapper(42) == false)
		assert(M.is_wrapper(nil) == false)
	end)

	-- __concise_original stores original function
	test("__concise_original stores original function", function()
		local function add(a, b) return a + b end
		local w = M.register(add, {
			{ "a", "number" },
			{ "b", "number" },
		})
		assert(w.__concise_original == add)
	end)

	-- __concise_name stores name
	test("__concise_name stores name", function()
		local w = M.register(function() end, {}, { name = "my_func" })
		assert(w.__concise_name == "my_func")
	end)

	-- opts.name validation
	test("opts.name must be non-empty string", function()
		expect_error(function()
			M.register(function() end, {}, { name = "" })
		end, "non-empty string")
		expect_error(function()
			M.register(function() end, {}, { name = 123 })
		end, "non-empty string")
	end)

	-- register validates fn is a function
	test("register validates fn is a function", function()
		expect_error(function()
			M.register("not a function")
		end, "first argument must be a function")
	end)

	-- register validates signature is a table
	test("register validates signature is a table", function()
		expect_error(function()
			M.register(function() end, "bad")
		end, "signature must be a table or nil")
	end)

	-- register validates opts is a table
	test("register validates opts is a table", function()
		expect_error(function()
			M.register(function() end, {}, "bad")
		end, "opts must be a table")
	end)

	-- duplicate parameter names error
	test("duplicate parameter names error", function()
		expect_error(function()
			M.register(function() end, {
				{ "x", "number" },
				{ "x", "string" },
			})
		end, "duplicate parameter name")
	end)

	-- named call with non-table errors
	test("named call with non-table errors", function()
		local fn = M.register(function(a)
			return a
		end, { { "a", "number" } })
		expect_error(function()
			fn.named("bad")
		end, "named arguments must be a table")
	end)

	-- named call with 2+ args errors in auto mode
	test("named call with 2+ args errors in auto mode", function()
		local fn = M.register(function(a)
			return a
		end, { { "a", "number" } })
		expect_error(function()
			fn(1, 2)
		end, "too many positional arguments")
	end)

	-- error messages include function name
	test("error messages include function name", function()
		local fn = M.register(function(x)
			return x
		end, { { "x", "number" } }, { name = "my_func" })
		expect_error(function()
			fn("bad")
		end, "my_func")
	end)

	-- string type spec "integer"
	test("integer type spec", function()
		local fn = M.register(function(x)
			return x
		end, { { "x", "integer" } })
		assert(fn(5) == 5)
		assert(fn(5.0) == 5)
		expect_error(function()
			fn(5.5)
		end, "expected integer")
	end)

	print(string_format("[concise_call] %d/%d tests passed (%d failed)", passed, total, failed))
	assert(failed == 0, string_format("%d test(s) failed", failed))
end
--]=]

-- Export
return M
