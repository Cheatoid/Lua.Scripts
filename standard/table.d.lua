-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

---@meta

---@class tablelib
local table = {}

--- Check if a table is empty.<br>
--- Returns true if the table has no key-value pairs.
---@param t table Table to check.
---@return boolean empty True if the table is empty, false otherwise.
---@usage <br>
--- ```
--- local empty = {}
--- local full = {a = 1}
--- print(table.is_empty(empty)) -- true
--- print(table.is_empty(full))  -- false
--- ```
function table.is_empty(t) end

--- Check if a table is a proper array.<br>
--- Returns true if the table has sequential numeric keys starting from 1 with no gaps.
---@param t table Table to check.
---@return boolean is_array True if the table is a proper array, false otherwise.
---@usage <br>
--- ```
--- local arr = {1, 2, 3}
--- local sparse = {1, nil, 3}
--- local map = {a = 1, b = 2}
--- print(table.is_array(arr))    -- true
--- print(table.is_array(sparse)) -- false
--- print(table.is_array(map))    -- false
--- ```
function table.is_array(t) end

--- Check if a table has only numeric keys.<br>
--- Returns true if every key in the table is of type "number".<br>
--- Unlike `table.is_array`, this does not require keys to be sequential or start at 1.
---@param t table Table to check.
---@return boolean is_array_like True if all keys are numbers, false otherwise.
---@usage <br>
--- ```
--- local arr = {1, 2, 3}
--- local sparse = {1, nil, 3}
--- local sparse_map = {[1] = "a", [5] = "b", [10] = "c"}
--- local map = {a = 1, b = 2}
--- print(table.is_array_like(arr))        -- true
--- print(table.is_array_like(sparse))     -- true (nil entries don't create keys)
--- print(table.is_array_like(sparse_map)) -- true (all keys are numbers, but not sequential)
--- print(table.is_array_like(map))        -- false (keys are strings)
--- ```
function table.is_array_like(t) end

--- Check if a table is an enum.<br>
--- Returns true if the table has only string keys and number values, and no metatable.
---@param t table Table to check.
---@return boolean is_enum True if the table is an enum, false otherwise.
---@usage <br>
--- ```
--- local enum = {RED = 1, GREEN = 2, BLUE = 3}
--- local not_enum1 = {a = "hello", b = "world"}
--- local not_enum2 = {1, 2, 3}
--- local mt = setmetatable({x = 1}, {})
--- print(table.is_enum(enum))      -- true
--- print(table.is_enum(not_enum1)) -- false (values are not numbers)
--- print(table.is_enum(not_enum2)) -- false (keys are not strings)
--- print(table.is_enum(mt))        -- false (has metatable)
--- ```
function table.is_enum(t) end

--- Check if a key exists in a table using rawget (bypasses metamethods).<br>
--- Returns true if the key exists in the table (value is not nil).
---@param t table Table to check.
---@param k any Key to check for existence.
---@return boolean exists True if the key exists, false otherwise.
---@usage <br>
--- ```
--- local t = {a = 1, b = 2, c = nil}
--- print(table.has_key(t, "a")) -- true
--- print(table.has_key(t, "b")) -- true
--- print(table.has_key(t, "c")) -- false (value is nil)
--- print(table.has_key(t, "d")) -- false (key doesn't exist)
--- ```
function table.has_key(t, k) end

--- Clear all key-value pairs from a table.<br>
--- Removes all entries from the table in-place.
---@param t table Table to clear.
---@return table t The same table (for chaining).
---@usage <br>
--- ```
--- local t = {a = 1, b = 2, c = 3}
--- table.clear(t)
--- print(next(t)) -- nil (table is now empty)
--- ```
function table.clear(t) end

table.empty = table.clear

--- Count the number of key-value pairs in a table.<br>
--- Returns the total number of entries in the table.
---@param t table Table to count entries in.
---@return integer count Number of key-value pairs in the table.
---@usage <br>
--- ```
--- local t = {a = 1, b = 2, c = 3}
--- print(table.count(t)) -- 3
--- ```
function table.count(t) end

--- Get all keys from a table.<br>
--- Returns an array containing all keys from the input table.
---@param t table Input table to extract keys from.
---@param out table|nil out Optional output table to store keys in (default: new table).
---@return table keys Array containing all keys from the input table.
---@usage <br>
--- ```
--- local t = {a = 1, b = 2, c = 3}
--- local keys = table.keys(t)
--- -- keys might be: {"a", "b", "c"} (order not guaranteed)
--- ```
function table.keys(t, out) end

--- Get all values from a table.<br>
--- Returns an array containing all values from the input table.
---@param t table Input table to extract values from.
---@param out table|nil out Optional output table to store values in (default: new table).
---@return table values Array containing all values from the input table.
---@usage <br>
--- ```
--- local t = {a = 1, b = 2, c = 3}
--- local values = table.values(t)
--- -- values might be: {1, 2, 3} (order not guaranteed)
--- ```
function table.values(t, out) end

--- Get all key-value pairs from a table as array of arrays.<br>
--- Returns an array where each element is a 2-element array {key, value}.
---@param t table Input table to extract key-value pairs from.
---@param out table|nil out Optional output table to store pairs in (default: new table).
---@return table pairs Array of {key, value} arrays.
---@usage <br>
--- ```
--- local t = {a = 1, b = 2}
--- local pairs = table.keys_values(t)
--- -- pairs might be: {{"a", 1}, {"b", 2}} (order not guaranteed)
--- ```
function table.keys_values(t, out) end

--- Get all key-value pairs from a table as array of objects.<br>
--- Returns an array where each element is a table {k = key, v = value}.
---@param t table Input table to extract key-value pairs from.
---@param out table|nil out Optional output table to store pairs in (default: new table).
---@return table pairs Array of {k = key, v = value} tables.
---@usage <br>
--- ```
--- local t = {a = 1, b = 2}
--- local pairs = table.keys_values_named(t)
--- -- pairs might be: {{k = "a", v = 1}, {k = "b", v = 2}} (order not guaranteed)
--- ```
function table.keys_values_named(t, out) end

--- Fast recursive iteration over table with callback function.<br>
--- Calls the provided function for each key-value pair in the table using recursion.
---@param f function Callback function to call for each key-value pair (function(key, value)).
---@param t table Table to iterate over.
---@param ... any Initial key-value pair to start iteration with.
---@usage <br>
--- ```
--- table.fast_iter(function(k, v) print(k, v) end, _G, next(_G))
--- ```
function table.fast_iter(f, t, ...) end

--- Fast iteration over table keys with callback function.<br>
--- Calls the provided function for each key in the table. Returns a function that can be called to continue iteration.
---@param t table Table to iterate over.
---@param f function Callback function to call for each key.
---@return function|nil continuation Function to continue iteration, or nil if table is empty.
---@usage <br>
--- ```
--- local t = {a = 1, b = 2, c = 3}
--- local cont = table.fast_keys(t, function(k) print(k) end)
--- if cont then cont() end -- Continue iteration
--- ```
function table.fast_keys(t, f) end

--- Fast iteration over table values with callback function.<br>
--- Calls the provided function for each value in the table.<br>
--- Returns a function that can be called to continue iteration.
---@param t table Table to iterate over.
---@param f function Callback function to call for each value.
---@return function|nil continuation Function to continue iteration, or nil if table is empty.
---@usage <br>
--- ```
--- local t = {a = 1, b = 2, c = 3}
--- local cont = table.fast_values(t, function(v) print(v) end)
--- if cont then cont() end -- Continue iteration
--- ```
function table.fast_values(t, f) end

--- Fast iteration over table key-value pairs with callback function.<br>
--- Calls the provided function for each key-value pair in the table.<br>
--- Returns a function that can be called to continue iteration.
---@param t table Table to iterate over.
---@param f function Callback function to call for each key-value pair (function(key, value)).
---@return function|nil continuation Function to continue iteration, or nil if table is empty.
---@usage <br>
--- ```
--- local t = {a = 1, b = 2, c = 3}
--- local cont = table.fast_keys_values(t, function(k, v) print(k, v) end)
--- if cont then cont() end -- Continue iteration
--- ```
function table.fast_keys_values(t, f) end

--- Call a method on a table by name with optional arguments.<br>
--- Safely calls a table method if it exists, otherwise does nothing.
---@param t table The table containing the method.
---@param name string The name of the method to call.
---@param ... any Arguments to pass to the method.
---@return ... any Return values from the method, or nil if method doesn't exist.
---@usage <br>
--- ```
--- local obj = {
---   greet    = function(name) return "Hello, " .. name end,
---   farewell = function(name) return "Goodbye, " .. name end
--- }
---
--- table.emit(obj, "greet", "World")    -- "Hello, World"
--- table.emit(obj, "farewell", "Alice") -- "Goodbye, Alice"
--- table.emit(obj, "missing", "test")   -- nil (method doesn't exist)
--- ```
function table.emit(t, name, ...) end

--- Call a method on a table by name, passing the table and name as first arguments.<br>
--- Similar to emit but passes the table and method name as the first two arguments to the function.<br>
--- Useful for method-style functions that expect the table and name as parameters.
---@param t table The table containing the method.
---@param name string The name of the method to call.
---@param ... any Additional arguments to pass to the method.
---@return ... any Return values from the method, or nil if method doesn't exist.
---@usage <br>
--- ```
--- local obj = {
---   greet    = function(self, method, name) return method .. ": Hello, " .. name end,
---   farewell = function(self, method, name) return method .. ": Goodbye, " .. name end
--- }
---
--- table.emit_with_args(obj, "greet", "World")    -- "greet: Hello, World"
--- table.emit_with_args(obj, "farewell", "Alice") -- "farewell: Goodbye, Alice"
--- table.emit_with_args(obj, "missing", "test")   -- nil (method doesn't exist)
--- ```
function table.emit_with_args(t, name, ...) end

--- Call a method on a table by name, passing the table as the first argument (self).<br>
--- Similar to emit, but uses the Lua OOP pattern where the table is passed as the first argument.<br>
--- Useful for calling methods on objects that use the colon syntax convention.
---@param t table The table/object containing the method.
---@param name string The name of the method to call.
---@param ... any Arguments to pass to the method after the table.
---@return ... any Return values from the method, or nil if method doesn't exist.
---@usage <br>
--- ```
--- local obj = {
---   greet    = function(self, name) return "Hello, " .. name end,
---   farewell = function(self, name) return "Goodbye, " .. name end,
---   set_name = function(self, name) self.name = name end
--- }
---
--- table.invoke(obj, "greet", "World")    -- "Hello, World"
--- table.invoke(obj, "farewell", "Alice") -- "Goodbye, Alice"
--- table.invoke(obj, "set_name", "Bob")   -- sets obj.name = "Bob"
--- table.invoke(obj, "missing", "test")   -- nil (method doesn't exist)
--- ```
function table.invoke(t, name, ...) end

--- Initialize a table with values from an optional source table (via rawset) and set its metatable.<br>
--- Copies key-value pairs from `init` into `t` using rawset, bypassing any existing metamethods, then sets the metatable.
---@param t table The table to initialize and assign a metatable to.
---@param mt table The metatable to set on `t`.
---@param init table|nil Optional table of key-value pairs to copy into `t` via rawset.
---@return table t The same table `t` with values copied and metatable set.
---@usage <br>
--- ```
--- local obj = table.initmeta({}, {__index = BaseClass}, {health = 100, name = "Player"})
--- -- obj is now: {health = 100, name = "Player"} with metatable set to {__index = BaseClass}
--- ```
function table.initmeta(t, mt, init) end

--- Iterate over all key-value pairs in a table and call a function for each.<br>
--- Uses next to iterate over all keys (including non-numeric keys).
---@param t table The table to iterate over.
---@param fn function Callback function called with key and value for each pair.
---@usage <br>
--- ```
--- local t = {a = 1, b = 2, c = 3}
--- table.foreach(t, function(k, v)
---   print(k, v) -- prints: a 1, b 2, c 3
--- end)
---
--- local arr = {10, 20, 30}
--- table.foreach(arr, function(k, v)
---   print(k, v) -- prints: 1 10, 2 20, 3 30
--- end)
--- ```
function table.foreach(t, fn) end

--- Apply multiple functions to corresponding elements in an array by index.<br>
--- Each function in the funcs array is applied to the corresponding element in the table by index.<br>
--- Supports both direct call syntax and curried syntax.
---@param t table The table to apply functions to.
---@param funcs function[]|nil Optional array of functions to apply. If nil, returns a function that accepts funcs.
---@usage <br>
--- ```
--- -- Direct call syntax
--- table.foreachi({ 1, 2, 3, 4, 5 }, {
---   function(i, v) print("first", i, v) end,
---   function(i, v) print("second", i, v) end,
---   function(i, v) print("third", i, v) end,
---   function(i, v) print("fourth", i, v) end,
--- })
---
--- -- Curried syntax
--- table.foreachi { 10, 20, 30 } {
---   function(i, v) print(i, v) end,
---   function(i, v) print(i, v * 2) end,
---   function(i, v) print(i, v / 10) end,
--- }
--- ```
function table.foreachi(t, funcs) end

--- Unpack a table into individual return values.<br>
--- Polyfill for Lua 5.1/LuaJIT that uses unpack if table.unpack is not available.
---@param t table Table to unpack.
---@param i integer|nil Starting index (default: 1).
---@param j integer|nil Ending index (default: #t).
---@return ... any Unpacked values from the table.
---@usage <br>
--- ```
--- local t = {10, 20, 30}
--- local a, b, c = table.unpack(t)
--- print(a, b, c) -- 10 20 30
--- ```
function table.unpack(t, i, j) end

--- Pack arguments into a table with n field.<br>
--- Creates a table containing all arguments with an 'n' field indicating the count.
---@param ... any Arguments to pack.
---@return table packed Table containing arguments with n field.
---@usage <br>
--- ```
--- local packed = table.pack(1, 2, 3)
--- -- packed is: {1, 2, 3, n = 3}
--- ```
function table.pack(...) end

--- Unwraps arguments, optionally unpacking a single table argument.<br>
--- If there's exactly one argument and it's a table, unpacks it and returns its contents.<br>
--- Otherwise returns the arguments as-is.
---@param ... any Variable number of arguments to unwrap.
---@return ... any unwrapped The unwrapped arguments, or unpacked table contents if single table argument.
function table.unwrap(...) end

--- Create a shallow copy of a table.<br>
--- Copies all key-value pairs from the source table to a new table (doesn't copy nested tables).
---@param t table Source table to copy.
---@param out table|nil Optional output table to copy into (default: new table).
---@return table copy Shallow copy of the source table.
---@usage <br>
--- ```
--- local original = {a = 1, b = 2}
--- local copy = table.shallow_copy(original)
--- copy.a = 10 -- Doesn't affect original
--- print(original.a) -- 1
--- ```
function table.shallow_copy(t, out) end

--- Create a deep copy of a table.<br>
--- Recursively copies all key-value pairs, including nested tables (handles circular references).
---@param t table Source table to copy.
---@param seen table|nil Internal table for tracking visited tables (for circular reference handling).
---@param out table|nil Optional output table to copy into (default: new table).
---@return table copy Deep copy of the source table.
---@usage <br>
--- ```
--- local original = {a = {x = 1}, b = 2}
--- local copy = table.deep_copy(original)
--- copy.a.x = 10 -- Doesn't affect original
--- print(original.a.x) -- 1
--- ```
function table.deep_copy(t, seen, out) end

--- Create a deep copy of a table with metatables.<br>
--- Recursively copies all key-value pairs including metatables (handles circular references).
---@param t table Source table to copy.
---@param seen table|nil Internal table for tracking visited tables (for circular reference handling).
---@param out table|nil Optional output table to copy into (default: new table).
---@return table copy Deep copy with metatables preserved.
---@usage <br>
--- ```
--- local mt = {__index = function() return "default" end}
--- local original = setmetatable({a = 1}, mt)
--- local copy = table.deep_copy_with_meta(original)
--- -- copy has the same metatable as original
--- ```
function table.deep_copy_with_meta(t, seen, out) end

--- Copy array elements from one table to another.<br>
--- Copies elements from indices 1 to #t of the source table to the output table.<br>
--- Unlike table.array, this only copies existing array elements without reindexing.
---@param t table Source table to copy array elements from.
---@param out table|nil Optional output table to copy into (default: new table).
---@return table copy Table containing the copied array elements.
---@usage <br>
--- ```
--- local source = {10, 20, 30, x = 40}
--- local copy = table.copy_array(source)
--- -- copy is: {10, 20, 30}
---
--- -- Reuse existing table (for performance)
--- local out = {100, 200}
--- table.copy_array({1, 2, 3}, out)
--- -- out is now: {1, 2, 3} (overwrites existing elements)
--- ```
function table.copy_array(t, out) end

--- Convert a table to a dense array (numeric indices only).<br>
--- Extracts all values from the input table and returns them in an array with sequential numeric indices.
---@param t table Input table to convert to array.
---@param out table|nil Optional output table to store values in (default: new table).
---@return table array Array containing all values from the input table.
---@usage <br>
--- ```
--- -- Returns: {10, 20, 30}
--- local arr = table.array({a = 10, b = 20, c = 30})
--- for i, v in ipairs(arr) do
---   print(i, v)
--- end
---
--- -- Reuse existing table (for performance)
--- local out = {}
--- table.array({x = 1, y = 2}, out)
--- -- out is now: {1, 2}
--- ```
function table.array(t, out) end

--- Extract numeric-indexed elements from a table.<br>
--- Copies the array part (indices 1..#t) into a new table.
---@param t table Input table to extract numeric elements from.
---@param out table|nil Optional output table to copy into (default: new table).
---@return table numeric Table containing only numeric-indexed elements.
---@usage <br>
--- ```
--- local t = {10, 20, 30, a = 1}
--- local numeric = table.numeric(t)
--- -- numeric is: {10, 20, 30}
--- ```
function table.numeric(t, out) end

--- Create an enumeration table with bidirectional mapping.<br>
--- Creates a new table where each key maps to its value and each value maps back to its key.
---@param t table Input table to create enumeration from.
---@return table enum New table with bidirectional key-value mapping.
---@usage <br>
--- ```
--- -- Returns: {RED = "red", "red" = "RED", BLUE = "blue", "blue" = "BLUE"}
--- local colors = table.enum({RED = "red", BLUE = "blue"})
--- print(colors.RED)     -- "red"
--- print(colors["red"])  -- "RED"
--- ```
function table.enum(t) end

--- Create an inverse mapping of a table.<br>
--- Creates a new table where values become keys and keys become values.
---@param t table Input table to invert.
---@return table inverted New table with inverted key-value mapping.
---@usage <br>
--- ```
--- -- Returns: {[10] = "a", [20] = "b", [30] = "c"}
--- local inverted = table.inverse({a = 10, b = 20, c = 30})
--- print(inverted[10])  -- "a"
--- print(inverted[20])  -- "b"
--- ```
function table.inverse(t) end

table.invert = table.inverse

--- Ensures a key exists in a table, setting it to a default value if it doesn't.<br>
---@param tbl table The table to check.
---@param key any The key to check.
---@param def any The default value to set if the key doesn't exist.
---@return any any The value of the key (either the existing value or the default value).
function table.ensure(tbl, key, def) end

--- Ensures a key exists in a table, lazily creating it with a factory function if it doesn't.<br>
--- The factory function is only called when the key is missing, and its return value is stored.
---@param tbl table The table to check and modify.
---@param key any The key to check for existence.
---@param def function A factory function that creates the default value. Called with additional arguments.
---@param ... any Additional arguments passed to the factory function.
---@return any any The existing value of the key, or the newly created value from the factory function.
function table.ensure_lazy(tbl, key, def, ...) end

--- Create a case-insensitive wrapper for any table or create a new case-insensitive table.<br>
--- Allows reading/writing string keys regardless of case.
---@param t table|nil The table to wrap. If nil, creates a new empty table.
---@return table table Case-insensitive wrapper for the target table.
function table.make_case_insensitive(t) end

--- Create a case-insensitive wrapper for a table.<br>
--- Returns a proxy table that allows case-insensitive access to string keys while preserving original keys.
---@param t table Input table to make case-insensitive.
---@return table proxy Case-insensitive proxy table that wraps the original.
---@usage <br>
--- ```
--- local config = {Name = "John", Age = 25}
--- local ci_config = table.make_case_insensitive(config)
--- print(ci_config.name)  -- "John" (case-insensitive access)
--- print(ci_config.NAME)  -- "John" (case-insensitive access)
--- ci_config.age = 30     -- Updates original table
--- print(config.Age)      -- 30
--- ```
function table.case_insensitive(t) end

--- Convert all string keys in a table to lowercase.<br>
--- Creates a new table with lowercase versions of all string keys.
---@param t table Input table to convert keys.
---@param out table|nil Optional output table to store results in (default: new table).
---@return table table New table with lowercase keys.
function table.lowercase_keys(t, out) end

table.lowercase = table.lowercase_keys

--- Convert all string keys in a table to uppercase.<br>
--- Creates a new table with uppercase versions of all string keys.
---@param t table Input table to convert keys.
---@param out table|nil Optional output table to store results in (default: new table).
---@return table table New table with uppercase keys.
function table.uppercase_keys(t, out) end

table.uppercase = table.uppercase_keys

--- Remove the first N elements from an array in-place.<br>
--- Efficiently removes the specified number of elements from the beginning of an array by shifting remaining elements.
---@param arr table Array to remove elements from (modified in-place).
---@param numElements integer Number of elements to remove from the beginning (default: 1).
---@return table array The modified array with elements removed.
---@usage <br>
--- ```
--- local arr = {1, 2, 3, 4, 5}
--- table.remove_first(arr, 2)
--- -- arr is now: {3, 4, 5}
---
--- local arr2 = {1, 2}
--- table.remove_first(arr2, 5)
--- -- arr2 is now: {}
--- ```
function table.remove_first(arr, numElements) end

--- Remove the last N elements from an array in-place.<br>
--- Efficiently removes the specified number of elements from the end of an array.
---@param arr table Array to remove elements from (modified in-place).
---@param numElements integer Number of elements to remove from the end (default: 1).
---@return table array The modified array with elements removed.
---@usage <br>
--- ```
--- local arr = {1, 2, 3, 4, 5}
--- table.remove_last(arr, 2)
--- -- arr is now: {1, 2, 3}
---
--- local arr2 = {1, 2}
--- table.remove_last(arr2, 5)
--- -- arr2 is now: {}
--- ```
function table.remove_last(arr, numElements) end

--- Remove duplicate values from a table.<br>
--- Creates a new table containing only the first occurrence of each unique value from the input table.
---@param t table Input table to remove duplicates from.
---@return table unique_table New table with duplicate values removed.
---@usage <br>
--- ```
--- local arr = {1, 2, 3, 2, 4, 1, 5}
--- local unique = table.unique(arr)
--- -- unique is now: {1, 2, 3, 4, 5}
---
--- local mixed = {"a", "b", "a", "c", "b"}
--- local unique_mixed = table.unique(mixed)
--- -- unique_mixed is now: {"a", "b", "c"}
--- ```
function table.unique(t) end

--- Filter a table based on a predicate function.<br>
--- Returns a new table containing entries for which pred(value, key, t) is truthy.<br>
--- Auto-detects arrays vs maps based on length, or can be forced via opts.array.
---@param t table The table to filter.
---@param pred function|nil Predicate function(value, key, t) returning truthy to keep. Default: keeps truthy values.
---@param opts table|nil Options table:
---   - array: true|false|nil - treat as array (true), map (false), or autodetect (nil, default).
---   - keep_keys: true|false - for map mode, keep original keys (default true).
---@return table filtered New table with filtered entries.
---@usage <br>
--- ```
--- -- Filter array (keep even numbers)
--- local arr = {1, 2, 3, 4, 5, 6}
--- local evens = table.filter(arr, function(v) return v % 2 == 0 end)
--- -- evens is: {2, 4, 6}
---
--- -- Filter map (keep values > 10)
--- local map = {a = 5, b = 15, c = 20, d = 3}
--- local big = table.filter(map, function(v) return v > 10 end)
--- -- big is: {b = 15, c = 20}
---
--- -- Force array mode, discard keys
--- local mixed = {a = 1, b = 2, c = 3}
--- local values = table.filter(mixed, nil, {array = true, keep_keys = false})
--- -- values is: {1, 2, 3}
--- ```
function table.filter(t, pred, opts) end

--- Filter a table in-place based on a predicate function.<br>
--- Mutates `t` to keep only entries where pred(value, key, t) is truthy.<br>
--- For arrays, compacts in-place with O(n) writes. For maps, removes non-matching keys.
---@param t table The table to filter (modified in-place).
---@param pred function|nil Predicate function(value, key, t) returning truthy to keep. Default: keeps truthy values.
---@param opts table|nil Options table:
---   - array: true|false|nil - treat as array (true), map (false), or autodetect (nil, default).
---@return table t The same table (for chaining).
---@usage <br>
--- ```
--- -- Filter array in-place
--- local arr = {1, 2, 3, 4, 5, 6}
--- table.filter_inplace(arr, function(v) return v > 3 end)
--- -- arr is now: {4, 5, 6}
---
--- -- Filter map in-place
--- local map = {a = 5, b = 15, c = 20}
--- table.filter_inplace(map, function(v) return v > 10 end)
--- -- map is now: {b = 15, c = 20}
--- ```
function table.filter_inplace(t, pred, opts) end

--- Create an iterator that filters a table based on a predicate.<br>
--- Returns an iterator over (k, v) pairs where pred(value, key, t) is truthy.<br>
--- Lazy evaluation - only processes elements as you iterate.
---@param t table The table to filter.
---@param pred function|nil Predicate function(value, key, t) returning truthy to keep. Default: keeps truthy values.
---@return function iterator Iterator function that returns k, v for matching entries.
---@usage <br>
--- ```
--- local t = {a = 5, b = 15, c = 3, d = 20}
---
--- -- Iterate only over values > 10
--- for k, v in table.filter_iter(t, function(v) return v > 10 end) do
---   print(k, v) -- prints: b 15, d 20
--- end
---
--- -- Filter array (truthy values only)
--- local arr = {1, nil, 3, false, 5}
--- for i, v in table.filter_iter(arr) do
---   print(i, v) -- prints: 1 1, 3 3, 5 5
--- end
--- ```
function table.filter_iter(t, pred) end

--- Extract a slice of elements from an array.<br>
--- Returns a new table containing elements from` start_index` to `end_index` (inclusive).<br>
--- Supports negative indexes like `string.sub` (e.g., -1 = last element, -2 = second to last).
---@param t table Input array to slice from.
---@param start_index integer Starting index (1-based, supports negative, default: 1).
---@param end_index integer|nil Ending index (inclusive, supports negative, default: #t).
---@return table slice New array containing the sliced elements.
---@usage <br>
--- ```
--- local arr = {1, 2, 3, 4, 5}
--- table.slice(arr, 2, 4)    -- {2, 3, 4}
--- table.slice(arr, 3)       -- {3, 4, 5}
--- table.slice(arr, 1, 2)    -- {1, 2}
--- table.slice(arr, -2)      -- {4, 5} (last 2 elements)
--- table.slice(arr, -3, -1)  -- {3, 4, 5} (last 3 elements)
--- table.slice(arr, -4, 2)   -- {2} (4th from last to 2nd)
--- ```
function table.slice(t, start_index, end_index) end

--- Split an array into chunks of specified size.<br>
--- Returns a new array where each element is a sub-array containing up to chunk_size elements.
---@param t table Input array to split into chunks.
---@param chunk_size integer Size of each chunk (must be > 0, default: 1).
---@return table chunks Array of chunk arrays.
---@usage <br>
--- ```
--- local arr = {1, 2, 3, 4, 5, 6, 7}
--- table.chunks(arr, 3) -- {{1, 2, 3}, {4, 5, 6}, {7}}
--- table.chunks(arr, 2) -- {{1, 2}, {3, 4}, {5, 6}, {7}}
--- ```
function table.chunks(t, chunk_size) end

--- Rotate an array left by the specified amount (in-place).<br>
--- Elements are shifted left, with elements that fall off the beginning wrapping around to the end.<br>
--- Modifies the table in-place and returns the same table for chaining.
---@param t table Input array to rotate (modified in-place).
---@param amount integer Number of positions to rotate left.
---@return table t The same table with elements rotated left.
---@usage <br>
--- ```
--- local arr = {1, 2, 3, 4, 5}
--- table.rotate_left(arr, 2)
--- -- arr is now: {3, 4, 5, 1, 2}
--- ```
function table.rotate_left(t, amount) end

--- Rotate an array right by the specified amount (in-place).<br>
--- Elements are shifted right, with elements that fall off the end wrapping around to the beginning.<br>
--- Modifies the table in-place and returns the same table for chaining.
---@param t table Input array to rotate (modified in-place).
---@param amount integer Number of positions to rotate right.
---@return table t The same table with elements rotated right.
---@usage <br>
--- ```
--- local arr = {1, 2, 3, 4, 5}
--- table.rotate_right(arr, 2)
--- -- arr is now: {4, 5, 1, 2, 3}
--- ```
function table.rotate_right(t, amount) end

--- Rotate an array by the specified amount (in-place).<br>
--- Positive amounts rotate right, negative amounts rotate left.<br>
--- Modifies the table in-place and returns the same table for chaining.
---@param t table Input array to rotate (modified in-place).
---@param rotation integer Number of positions to rotate (negative = left, positive = right).
---@return table t The same table with elements rotated.
---@usage <br>
--- ```
--- local arr = {1, 2, 3, 4, 5}
--- table.rotate(arr, 2)
--- -- arr is now: {4, 5, 1, 2, 3} (rotate right 2)
--- table.rotate(arr, -2)
--- -- arr is now: {3, 4, 5, 1, 2} (rotate left 2)
--- ```
function table.rotate(t, rotation) end

--- Create a new array rotated left by the specified amount.<br>
--- Elements are shifted left, with elements that fall off the beginning wrapping around to the end.<br>
--- Returns a new table without modifying the original.
---@param t table Input array to rotate.
---@param amount integer Number of positions to rotate left.
---@return table rotated New array with elements rotated left.
---@usage <br>
--- ```
--- local arr = {1, 2, 3, 4, 5}
--- local rotated = table.rotated_left(arr, 2)
--- -- arr is still: {1, 2, 3, 4, 5}
--- -- rotated is: {3, 4, 5, 1, 2}
--- ```
function table.rotated_left(t, amount) end

--- Create a new array rotated right by the specified amount.<br>
--- Elements are shifted right, with elements that fall off the end wrapping around to the beginning.<br>
--- Returns a new table without modifying the original.
---@param t table Input array to rotate.
---@param amount integer Number of positions to rotate right.
---@return table rotated New array with elements rotated right.
---@usage <br>
--- ```
--- local arr = {1, 2, 3, 4, 5}
--- local rotated = table.rotated_right(arr, 2)
--- -- arr is still: {1, 2, 3, 4, 5}
--- -- rotated is: {4, 5, 1, 2, 3}
--- ```
function table.rotated_right(t, amount) end

--- Create a new array rotated by the specified amount.<br>
--- Positive amounts rotate right, negative amounts rotate left.<br>
--- Returns a new table without modifying the original.
---@param t table Input array to rotate.
---@param rotation integer Number of positions to rotate (negative = left, positive = right).
---@return table rotated New array with elements rotated.
---@usage <br>
--- ```
--- local arr = {1, 2, 3, 4, 5}
--- local rotated = table.rotated(arr, 2)
--- -- arr is still: {1, 2, 3, 4, 5}
--- -- rotated is: {4, 5, 1, 2, 3} (rotate right 2)
--- ```
function table.rotated(t, rotation) end

--- Reverse the order of elements in an array in-place.<br>
--- Reverses the elements in the original table and returns the same table for chaining.
---@param t table Input array to reverse (modified in-place).
---@return table t The same table with elements reversed.
---@usage <br>
--- ```
--- local arr = {1, 2, 3, 4, 5}
--- table.reverse(arr)
--- -- arr is now: {5, 4, 3, 2, 1}
---
--- local chars = {"a", "b", "c"}
--- table.reverse(chars)
--- -- chars is now: {"c", "b", "a"}
--- ```
function table.reverse(t) end

--- Create a new array with elements in reverse order.<br>
--- Returns a new table with elements in reverse order without modifying the original table.
---@param t table Input array to reverse.
---@return table reversed New array with elements in reverse order.
---@usage <br>
--- ```
--- local arr = {1, 2, 3, 4, 5}
--- local rev = table.reversed(arr)
--- -- arr is still: {1, 2, 3, 4, 5}
--- -- rev is now: {5, 4, 3, 2, 1}
---
--- local chars = {"a", "b", "c"}
--- local rev_chars = table.reversed(chars)
--- -- rev_chars is now: {"c", "b", "a"}
--- ```
function table.reversed(t) end

--- Create a switch-case table builder.<br>
--- Provides a fluent interface for building switch-case mappings that can be baked into optimized lookup tables.
---@param value any|nil Optional default value to switch on (can be nil for dynamic evaluation).
---@return table builder A switch-case builder object with chaining methods.
---@usage <br>
--- ```
--- local switch_builder = table.switch()
---   :case("monday", "Start of week")
---   :case("friday", "End of week")
---   :default("Mid week")
---
--- -- Bake into optimized lookup table
--- local lookup = switch_builder:bake()
--- print(lookup["monday"])  -- "Start of week"
--- print(lookup["tuesday"]) -- "Mid week"
---
--- -- Or evaluate dynamically
--- local result = switch_builder:eval("friday") -- "End of week"
--- ```
function table.switch(value) end

--- Create a case function for simple value mapping.<br>
--- Alternative syntax for switch with direct value mapping.
---@param value any The value to switch on.
---@return table case A case object for chaining.
---@usage <br>
--- ```
--- local result = case(status)
---   :when("active", "Running")
---   :when("inactive", "Stopped")
---   :when("error", "Failed")
---   :otherwise("Unknown")
--- ```
function table.case(value) end

--- Create a weak table with weak keys.
---@return table table A table with weak key references.
function table.weak_keys() end

--- Create a weak table with weak values.
---@return table table A table with weak value references.
function table.weak_values() end

--- Create a weak table with weak keys and values.
---@return table table A table with weak key and value references.
function table.weak() end

--- Randomize the order of elements in a table using the Fisher-Yates shuffle algorithm.<br>
--- This function shuffles the elements in-place and returns the same table for chaining.
---@param t table The table to randomize (modified in-place).
---@return table table The same table with elements randomized.
---@usage <br>
--- ```
--- local arr = {1, 2, 3, 4, 5}
--- table.randomize(arr)
--- -- arr might now be: {3, 1, 5, 2, 4}
---
--- local colors = {"red", "green", "blue", "yellow"}
--- table.randomize(colors)
--- -- colors might now be: {"blue", "yellow", "red", "green"}
--- ```
function table.randomize(t) end

--- Adds all values from source table to destination table (array-style append).<br>
--- If dest and source are the same table, no action is taken and dest is returned.
---@param dest table The destination table to add values to.
---@param source table The source table to copy values from.
---@return table dest The destination table with added values.
function table.add(dest, source) end

--- Merges all key-value pairs from source table into destination table.<br>
--- If dest and source are the same table, no action is taken and dest is returned.<br>
--- Unlike table.add, this preserves keys and overwrites existing values.
---@param dest table The destination table to merge into.
---@param source table The source table to copy key-value pairs from.
---@return table dest The destination table with merged values.
function table.merge(dest, source) end

--- Merges key-value pairs from source table into destination table without overwriting.<br>
--- Only copies keys from source that don't already exist in destination.<br>
--- If dest and source are the same table, no action is taken and dest is returned.
---@param dest table The destination table to merge into.
---@param source table The source table to copy key-value pairs from.
---@return table dest The destination table with merged values (existing keys preserved).
function table.merge_preserve(dest, source) end

--- Sorts a table in descending order (highest values first).<br>
--- This is a convenience wrapper around table.sort with a > comparator.
---@param t table The table to sort (modified in-place).
---@return table t The sorted table (same reference, for chaining).
function table.sortdesc(t) end

--- Iterate over a table in sorted key order.<br>
--- Returns an iterator that yields key, value pairs in ascending or descending order based on the keys.
---@param t table The table to iterate.
---@param descending boolean|nil If true, sort in descending order (default: false/ascending).
---@return function iterator Iterator function that returns key, value pairs.
---@usage <br>
--- ```
--- local t = {c = 3, a = 1, b = 2}
--- for k, v in table.sorted(t) do
---   print(k, v) -- a=1, b=2, c=3 (ascending)
--- end
---
--- for k, v in table.sorted(t, true) do
---   print(k, v) -- c=3, b=2, a=1 (descending)
--- end
--- ```
function table.sorted(t, descending) end

--- Sort a table by a key extraction function.<br>
--- Sorts the table in-place using a custom function that extracts a comparison key from each element.
---@param t table The table to sort (modified in-place).
---@param key_func function Function that extracts a comparison key from each element.
---@return table t The sorted table (same reference, for chaining).
---@usage <br>
--- ```
--- local users = {{name = "Alice", age = 30}, {name = "Bob", age = 25}}
--- table.sort_by(users, function(u) return u.age end)
--- -- users is now sorted by age: Bob (25), Alice (30)
--- ```
function table.sort_by(t, key_func) end

--- Sort an array of tables by a specific field.<br>
--- Sorts the array in-place by comparing the specified field in each table element.
---@param t table Array of tables to sort (modified in-place).
---@param field string Field name to sort by.
---@return table t The sorted array (same reference, for chaining).
---@usage <br>
--- ```
--- local items = {{name = "apple", price = 1.5}, {name = "banana", price = 0.5}}
--- table.sort_by_field(items, "price")
--- -- items is now sorted by price: banana (0.5), apple (1.5)
--- ```
function table.sort_by_field(t, field) end

--- Sort a table by a key extraction function (cached keys).<br>
--- Pre-computes keys for each element and sorts in-place.
---@param t table The table to sort (modified in-place).
---@param key_func function Function that extracts a comparison key from each element.
---@return table t The sorted table (same reference, for chaining).
function table.sort_by_key(t, key_func) end

--- Calculate the sum of all numeric values in a table.<br>
--- Non-numeric values are ignored.
---@param t table Table to calculate sum for.
---@return number sum The sum of all numeric values.
---@usage <br>
--- ```
--- local arr = {1, 2, 3, 4, 5}
--- print(table.sum(arr)) -- 15
---
--- local mixed = {10, "hello", 20, nil, 30}
--- print(table.sum(mixed)) -- 60 (non-numeric values ignored)
--- ```
function table.sum(t) end

--- Find the maximum numeric value in a table.<br>
--- Non-numeric values are ignored.
---@param t table Table to search.
---@return number|nil max The maximum numeric value, or nil if no numeric values found.
---@usage <br>
--- ```
--- local arr = {1, 5, 3, 9, 2}
--- print(table.max(arr)) -- 9
---
--- local mixed = {10, "hello", 20}
--- print(table.max(mixed)) -- 20
--- ```
function table.max(t) end

--- Find the minimum numeric value in a table.<br>
--- Non-numeric values are ignored.
---@param t table Table to search.
---@return number|nil min The minimum numeric value, or nil if no numeric values found.
---@usage <br>
--- ```
--- local arr = {1, 5, 3, 9, 2}
--- print(table.min(arr)) -- 1
---
--- local mixed = {10, "hello", 20}
--- print(table.min(mixed)) -- 10
--- ```
function table.min(t) end

--- Calculate the average (mean) of all numeric values in a table.<br>
--- Non-numeric values are ignored. Returns 0 if no numeric values found.
---@param t table Table to calculate average for.
---@return number average The average of all numeric values.
---@usage <br>
--- ```
--- local arr = {1, 2, 3, 4, 5}
--- print(table.average(arr)) -- 3
---
--- local mixed = {10, "hello", 20}
--- print(table.average(mixed)) -- 15
--- ```
function table.average(t) end

table.avg = table.average

--- Calculate the median of all numeric values in a table.<br>
--- Non-numeric values are ignored. Returns 0 if no numeric values found.
---@param t table Table to calculate median for.
---@return number median The median value.
---@usage <br>
--- ```
--- local arr = {1, 2, 3, 4, 5}
--- print(table.median(arr)) -- 3
---
--- local arr2 = {1, 2, 3, 4}
--- print(table.median(arr2)) -- 2.5 (average of 2 and 3)
--- ```
function table.median(t) end

--- Calculate statistics for all numeric values in a table.<br>
--- Returns a table with sum, count, min, max, average, and range.
---@param t table Table to calculate statistics for.
---@return table stats Table containing statistical data.
---@usage <br>
--- ```
--- local arr = {1, 2, 3, 4, 5}
--- local stats = table.stats(arr)
--- print(stats.sum)     -- 15
--- print(stats.count)   -- 5
--- print(stats.min)     -- 1
--- print(stats.max)     -- 5
--- print(stats.average) -- 3
--- print(stats.range)   -- 4
--- ```
function table.stats(t) end

--- Pretty print a table with proper indentation.<br>
--- Recursively prints table contents with sorted keys and circular reference detection.
---@param t table The table to print.
---@param writer function|nil Writer function (default: print).
---@param indent integer|nil Initial indentation level (default: 0).
---@param seen table|nil Internal table for tracking circular references (default: {}).
---@usage <br>
--- ```
--- local t = {a = 1, b = {c = 2}}
--- table.print(t)         -- Uses default print
--- table.print(t, print)  -- Explicit writer
--- table.print(t, my_writer, 2)  -- Custom writer and starting indent
--- ```
function table.print(t, writer, indent, seen) end

--- Retrieve a value from a nested table structure using a path string.<br>
--- Supports dot notation ("a.b.c") and bracket notation (["key"], [1]).
---@param t table The root table to traverse.
---@param path string The path to the value, e.g., "math.clamp", "_G[\"package\"][\"loaded\"]".
---@param separator string|nil Separator for dot notation (default: ".").
---@return any value The value at the path, or nil if not found.
---@usage <br>
--- ```
--- local value = table.get_path(_G, "math.clamp")
--- -- value = math.clamp function
---
--- local value = table.get_path({a = {b = {c = 42}}}, "a.b.c")
--- -- value = 42
---
--- local value = table.get_path({a = {[5] = "hello"}}, "a.[5]")
--- -- value = "hello"
---
--- local value = table.get_path(_G, "package[\"loaded\"][\"table\"]")
--- -- value = table library
---
--- local value = table.get_path({}, "a.b.c")
--- -- value = nil (key 'a' not found)
--- ```
function table.get_path(t, path, separator) end

--- Set a value in a nested table structure using a path string.<br>
--- Supports dot notation ("a.b.c") and bracket notation (["key"], [1]).<br>
--- Creates intermediate tables as needed.<br>
--- Returns nil if the root is not a table, the path is invalid, or if an intermediate path component is not a table.
---@param t table The root table to write into.
---@param path string The path to set the value at, e.g., "a.b.c", "package[\"loaded\"][\"foo\"]".
---@param value any The value to set.
---@param separator|nil string Separator for dot notation (default: ".").
---@return boolean|nil success True on success, nil on failure.
---@usage <br>
--- ```
--- local t = {}
--- table.set_path(t, "a.b.c", 42)
--- print(t.a.b.c) -- 42
---
--- table.set_path(t, "arr.[1]", "hello")
--- print(t.arr[1]) -- "hello"
--- ```
function table.set_path(t, path, value, separator) end

---@class table.TrackOptions
---@field on_read function|nil Called when a value is read: on_read(t, k, v)
---@field on_write function|nil Called when a value is written (fallback if on_create/on_update not set): on_write(t, k, old, v)
---@field on_create function|nil Called when a new key is created: on_create(t, k, v)
---@field on_update function|nil Called when an existing key is updated: on_update(t, k, old, v)
---@field on_delete function|nil Called when a key is deleted: on_delete(t, k, old)

--- Create a proxy table that tracks read/write/delete operations with callbacks.<br>
--- Preserves the original table's metatable and delegates to it for metamethods.
---@param t table The table to track.
---@param opts table.TrackOptions|nil Optional configuration table with callbacks.
---@return table proxy Proxy table that tracks operations.
---@usage <br>
--- ```
--- local t = {a = 1, b = 2}
--- local proxy = table.track(t, {
---   on_read = function(t, k, v) print("read", k, v) end,
---   on_create = function(t, k, v) print("create", k, v) end,
---   on_update = function(t, k, old, v) print("update", k, old, v) end,
---   on_delete = function(t, k, old) print("delete", k, old) end,
--- })
---
--- proxy.a -- read a 1
--- proxy.c = 3 -- create c 3
--- proxy.b = 20 -- update b 2 20
--- proxy.b = nil -- delete b 20
--- ```
function table.track(t, opts) end

table.monitor = table.track

--- Creates a read-only table proxy/wrapper that prevents modifications.<br>
--- Attempts to modify the table will throw an error.
---@param t table The table to make read-only.
---@return table readonly_proxy Read-only proxy table.
---@usage <br>
--- ```
--- local t = {a = 1, b = 2, c = 3}
--- local ro = table.readonly(t)
---
--- print(ro.a) -- 1 (reading works)
--- ro.a = 10   -- Error: attempt to modify a read-only table
--- ```
function table.readonly(t) end

--- Find the first occurrence of a value in a table.<br>
--- Searches for a value and returns its key, or nil if not found.<br>
--- Supports both array-style (numeric keys) and map-style (string keys) tables.
---@param t table Table to search in.
---@param value any Value to search for.
---@return any key The key of the found value, or nil if not found.
---@usage <br>
--- ```
--- local arr = {10, 20, 30, 40}
--- print(table.find(arr, 30)) -- 3
--- print(table.find(arr, 99)) -- nil
---
--- local map = {a = 1, b = 2, c = 3}
--- print(table.find(map, 2)) -- "b"
--- ```
function table.find(t, value) end

--- Iterative table dumper with optional depth limit and filter.<br>
---@param root table The table or value to dump.
---@param start_path string|nil The initial path string (e.g., "_G" or "data").<br>
---@param opts table|nil Optional configuration table:<br>
--- - `max_depth` boolean: maximum depth to traverse (default: nil = unlimited)<br>
--- - `filter`: function(path, key, value) -> boolean (return false to skip)
---@return number count Total amount of lines
---@return table lines Array of lines
function table.dump(root, start_path, opts) end

--- Convenience wrapper that prints directly.
---@param root table The table or value to dump.
---@param start_path string|nil The initial path string.
---@param opts table|nil Optional table with max_depth and/or filter.
function table.dump_print(root, start_path, opts) end

--- Alias of standalone `pretty_print_structure`.<br>
--- Pretty print a tree structure (table or filesystem) with visual hierarchy.
---@param input table|string Tree table or a path string.
---@param opts table|nil Options table (see standalone module for full options).
---@return string output Formatted tree structure.
function table.pretty_print_structure(input, opts) end

--- Alias of standalone `pretty_grid`.<br>
--- Pretty print a 2D table as an aligned text grid.
---@param rows table Array of rows.
---@param cols number|nil Number of columns.
---@param col_widths table|nil Optional fixed column widths.
---@param opts table|nil Options table (see standalone module for full options).
---@return string|nil output Formatted grid string, if the underlying implementation returns it.
function table.pretty_grid(rows, cols, col_widths, opts) end

--- Alias of standalone `pretty_hex_dump`.<br>
--- Pretty-print binary data (string or table of bytes) as a hex + ASCII grid.
---@param data string|table Binary data.
---@param opts table|nil Options table (see standalone module for full options).
function table.pretty_hex_dump(data, opts) end

return table
