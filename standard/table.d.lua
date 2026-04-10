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

--- Clear all key-value pairs from a table.<br>
--- Removes all entries from the table in-place.
---@param t table Table to clear.
---@return nil
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

--- Convert a table to a dense array (numeric indices only).<br>
--- Extracts all values from the input table and returns them in a new array with sequential numeric indices.
---@param t table Input table to convert to array.
---@return table array New array containing all values from the input table.
---@usage <br>
--- ```
--- -- Returns: {10, 20, 30}
--- local arr = table.array({a = 10, b = 20, c = 30})
--- for i, v in ipairs(arr) do
---   print(i, v)
--- end
--- ```
function table.array(t) end

--- Extract numeric-indexed elements from a table.<br>
--- Returns a new table containing only elements with numeric indices (1, 2, 3, ...).
---@param t table Input table to extract numeric elements from.
---@param out table|nil Optional output table to copy into (default: new table).
---@return table numeric Table containing only numeric-indexed elements.
---@usage <br>
--- ```
--- local t = {a = 1, b = 2, [3] = 3, [4] = 4}
--- local numeric = table.numeric(t)
--- -- numeric is: {[3] = 3, [4] = 4}
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

--- Extract a slice of elements from an array.<br>
--- Returns a new table containing elements from start_index to end_index (inclusive).<br>
--- Supports negative indexes like string.sub (e.g., -1 = last element, -2 = second to last).
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

--- Rotate an array left by the specified amount.<br>
--- Elements are shifted left, with elements that fall off the beginning wrapping around to the end.
---@param t table Input array to rotate.
---@param amount integer Number of positions to rotate left.
---@return table rotated New array with elements rotated left.
---@usage <br>
--- ```
--- local arr = {1, 2, 3, 4, 5}
--- table.rotate_left(arr, 2) -- {3, 4, 5, 1, 2}
--- ```
function table.rotate_left(t, amount) end

--- Rotate an array right by the specified amount.<br>
--- Elements are shifted right, with elements that fall off the end wrapping around to the beginning.
---@param t table Input array to rotate.
---@param amount integer Number of positions to rotate right.
---@return table rotated New array with elements rotated right.
---@usage <br>
--- ```
--- local arr = {1, 2, 3, 4, 5}
--- table.rotate_right(arr, 2) -- {4, 5, 1, 2, 3}
--- ```
function table.rotate_right(t, amount) end

--- Rotate an array by the specified amount.<br>
--- Positive amounts rotate right, negative amounts rotate left.
---@param t table Input array to rotate.
---@param rotation integer Number of positions to rotate (negative = left, positive = right).
---@return table rotated New array with elements rotated.
---@usage <br>
--- ```
--- local arr = {1, 2, 3, 4, 5}
--- table.rotate(arr, 2)  -- {4, 5, 1, 2, 3} (rotate right 2)
--- table.rotate(arr, -2) -- {3, 4, 5, 1, 2} (rotate left 2)
--- ```
function table.rotate(t, rotation) end

--- Reverse the order of elements in an array.<br>
--- Returns a new array with elements in reverse order (last element becomes first, etc.).
---@param t table Input array to reverse.
---@return table reversed New array with elements in reverse order.
---@usage <br>
--- ```
--- local arr = {1, 2, 3, 4, 5}
--- table.reverse(arr) -- {5, 4, 3, 2, 1}
---
--- local chars = {"a", "b", "c"}
--- table.reverse(chars) -- {"c", "b", "a"}
--- ```
function table.reverse(t) end

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

--- Pretty print a table with proper indentation.<br>
--- Recursively prints table contents with sorted keys and circular reference detection.
---@param t table Table to print.
---@param writer function Writer function (e.g. io.write).
---@param indent integer|nil Initial indentation level (default: 0).
---@param seen table|nil Internal table for tracking circular references (default: {}).
---@usage <br>
--- ```
--- local t = {a = 1, b = {c = 2}}
--- table.print(t) -- Pretty print to console
--- table.print(t, my_writer, 2) -- Custom writer and starting indent
--- ```
function table.print(t, writer, indent, seen) end

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

return table
