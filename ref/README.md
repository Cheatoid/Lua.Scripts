# Ref Module - A Powerful Reference Wrapper for Lua

A lightweight, flexible reference wrapper system for Lua that provides immutable references, proxy tables, weak
references, and more.

## 🚀 Quick Start

```lua
local Ref = require("ref")

-- Create a simple reference
local ref = Ref.new("Hello, World!")
print(ref())           -- "Hello, World!"
print(ref:get())       -- "Hello, World!"

-- Update the reference
ref:set("New value")
print(ref())           -- "New value"
```

## 📦 Installation

Simply place `ref.lua` in your project and require it:

```lua
local Ref = require("ref")
```

## ℹ️ Quick Syntax Reference

### Shorthand Creation

```lua
local Ref = require("ref")

-- Instead of Ref.new(), you can use Ref() directly
local ref1 = Ref.new("value")     -- Standard syntax
local ref2 = Ref("value")         -- Shorthand syntax (equivalent)

-- Shallow table wrapping with Ref* syntax
local data = {
    user = {name = "Alice", age = 25},
    settings = {theme = "dark"}
}
local shallow = Ref * data -- Shallow wrapper (equivalent to Ref.from_table(data))
-- Each field is a Ref holding the original value:
print(Ref.get(shallow.user).name)  -- "Alice"

-- Deep table wrapping with Ref^ syntax
local deep = Ref ^ data -- Deep wrapper (equivalent to Ref.from_table(data, {deep = true}))
-- Nested tables become proxy Refs:
print(Ref.get(deep.user.name))  -- "Alice" (scalar access in deep mode returns a Ref)
deep.user.age = 26     -- Updates original data via proxy
assert(data.user.age == 26)
```

### Module-Level Operators

```lua
local a = Ref(10)
local b = Ref(5)

-- Module functions for arithmetic (unwrap Refs, operate, return new Ref)
local sum = Ref.add(a, b)  -- Ref holding 15
local diff = Ref.sub(a, b) -- Ref holding 5
local prod = Ref.mul(a, b) -- Ref holding 50
local quot = Ref.div(a, b) -- Ref holding 2
local mod = Ref.mod(a, b)  -- Ref holding 0
local pow = Ref.pow(a, b)  -- Ref holding 100000
print(Ref.get(sum)) -- 15

-- Infix operators are equivalent and also return new Refs
local sum2 = a + b
print(Ref.get(sum2)) -- 15

-- String concatenation with .. operator (returns new Ref)
local str1 = Ref.new("hello")
local str2 = Ref.new("world")
local greeting = str1 .. " " .. str2 -- Ref holding "hello world"
print(Ref.get(greeting)) -- "hello world"

-- Special constructor shorthands (each returns a new table or factory):
local _shallow1 = Ref + {x = 1} -- shallow-wrap: each field becomes a Ref (equivalent to Ref.from_table({x = 1}))
local _shallow2 = Ref * {x = 1} -- shallow-wrap: each field becomes a Ref (equivalent to Ref.from_table({x = 1}))
local _deep_proxy = Ref % {u = {n = 1}} -- deep-proxy wrapper (equivalent to Ref.from_table(tbl, {deep = true, proxy = true}))
local _deep = Ref ^ {u = {n = 1}} -- deep wrapper (equivalent to Ref.from_table(tbl, {deep = true}))
local _ro1 = Ref - {u = {n = 1}} -- readonly deep wrapper (equivalent to Ref.from_table(tbl, {deep = true, readonly = true}))
local _ro2 = Ref / {u = {n = 1}} -- alias for Ref- (readonly deep wrapper)
local _reactive_factory = Ref >> {x = 1} -- reactive proxy factory: (Ref >> tbl)(on_write) -> proxy table

-- Readonly factory using unary minus on the module
local readonly = -Ref  -- Returns a function that creates readonly refs
local readonly_str = readonly("hello")  -- Same as Ref.new("hello", {readonly = true})
```

> Note: `-a` on a Ref *instance* is arithmetic negation (returns new Ref holding `-value`).
> `-Ref` on the *module* is the readonly factory. They share the `__unm` name but apply to different operands.

## 🎯 Core Concepts

### Basic References

References are wrappers around values that provide consistent interfaces:

```lua
-- Different ways to create and use references
local num_ref = Ref.new(42)
local str_ref = Ref.new("hello")
local tbl_ref = Ref.new({x = 1, y = 2})

-- Getting values
print(num_ref())        -- 42 (callable syntax)
print(str_ref:get())    -- "hello" (method syntax)
print(Ref.get(tbl_ref).x) -- 1 (module syntax, scalar tables need Ref.get to reach fields)

-- Setting values
num_ref:set(100)
str_ref("world")        -- callable setter
Ref.set(tbl_ref, {x = 3, y = 4})

-- Explicit nil handling:
-- ref() with 0 args is a getter, ref(v) with 1 arg (even nil) is a setter
local r = Ref.new("hi")
r(nil)              -- sets to nil (same as r:set(nil))
print(Ref.get(r) == nil) -- true
print(r())          -- nil (getter)
```

### Reference Types

#### 1. Regular References

```lua
-- Different types of values
local num_ref = Ref.new(42)
local str_ref = Ref.new("hello")
local func_ref = Ref.new(function() return "result" end)
local bool_ref = Ref.new(true)

-- Scalar access returns the stored value
print(num_ref())   -- 42
print(str_ref())   -- "hello"
print(type(func_ref()))  -- "function" (callable syntax returns the function itself)
print(Ref.get(func_ref)()) -- "result" (unwrap first, then call)
print(bool_ref())  -- true

-- Setting works for all
num_ref:set(100)
str_ref:set("world")
func_ref:set(function() return "updated" end)
bool_ref:set(false)
```

#### 2. Readonly References

```lua
local readonly = Ref.new("data", {readonly = true})
readonly:set("fail")    -- Error: attempt to modify readonly ref

-- Note: readonly on a scalar table only blocks Ref.set / ref(v).
-- The table itself is still mutable via Ref.get(ref).field = ... .
-- Use {proxy = true, readonly = true} for true table immutability (see below).
```

#### 3. Proxy References

```lua
local table = {name = "Alice", age = 25}
local proxy = Ref.new(table, {proxy = true})

-- Access table properties directly
print(proxy.name)       -- "Alice"
proxy.age = 26          -- Updates the original table
print(table.age)        -- 26

-- Calling a proxy returns the underlying table
print(proxy() == table) -- true
print(tostring(proxy) == tostring(table)) -- true

-- Ref.set on a proxy replaces the whole target (stays consistent)
Ref.set(proxy, {name = "Bob", age = 30})
print(proxy.name) -- "Bob"
```

#### 4. Weak References

```lua
local data = {important = "info"}
local weak = Ref.new(data, {weak = true})

data = nil              -- Remove strong reference
collectgarbage("collect")

-- Weak reference may now return nil
print(Ref.get(weak))    -- nil (data was garbage collected)
```

Weak + proxy resolves weakly on each access (no strong capture), so a collected
target reads as `nil` and writes error with `attempt to modify collected weak proxy ref`.

#### 5. Nil Sentinel References

```lua
-- Creating a nil Ref creates a special readonly sentinel
-- All options are ignored for nil (always readonly, never weak/proxy)
local nil_ref = Ref.new(nil)
print(Ref.is_nil_sentinel(nil_ref))  -- true
print(Ref.is_readonly(nil_ref))       -- true
print(Ref.get(nil_ref))              -- nil

-- Nil sentinel refs cannot be modified
nil_ref:set("fail")    -- Error: attempt to modify nil sentinel ref

-- Nil sentinel refs are always readonly
local success, err = pcall(function()
    return nil_ref("attempt")  -- callable setter also fails
end)
print(success)  -- false
print(err)     -- contains "attempt to modify nil sentinel ref"

-- Use case: Constant nil values
local NULL = Ref.new(nil)  -- Perfect for representing null/undefined values
-- NULL is immutable and clearly signals "no value"
```

#### 6. Regular Nil Values

```lua
-- Regular refs can be set to nil (stay normal refs with nil value, NOT sentinels)
local ref = Ref.new("value")
ref:set(nil)  -- Works fine
print(Ref.get(ref))  -- nil
print(Ref.is_nil_sentinel(ref))  -- false (not a sentinel)
print(Ref.is_readonly(ref))  -- false (still mutable)

-- Setting to nil after creation, then back to a value
local num_ref = Ref.new(42)
num_ref:set(nil)
print(Ref.get(num_ref))  -- nil
num_ref:set("back")
print(Ref.get(num_ref))  -- "back"

-- Use case: Optional values that may be nil
-- Do NOT start from Ref.new(nil) (that is an immutable sentinel).
-- Start from a non-nil value (or any placeholder), then set nil when empty:
local optional_field = Ref.new("placeholder")
optional_field:set(nil) -- empty
if some_condition then
    optional_field:set("value")  -- Set when available
end
```

## 🔧 Advanced Features

### Arithmetic Operations

```lua
local a = Ref.new(10)
local b = Ref.new(5)

-- Infix operators work on scalar refs (Refs or mixed Ref + raw are unwrapped)
-- Each operation returns a NEW Ref; operands are unchanged
print(Ref.get(a + b))           -- 15
print(Ref.get(a - b))           -- 5
print(Ref.get(a * b))           -- 50
print(Ref.get(a / b))           -- 2
print(Ref.get(a % b))           -- 0
print(Ref.get(a ^ b))           -- 100000 (power operator)
print(Ref.get(-a))              -- -10 (negation on instance)

-- print() works coincidentally via __tostring, but the value is still a Ref:
local sum = a + b
print(sum)             -- "15" via tostring
print(Ref.get(sum))    -- 15
print(Ref.get(a))      -- 10 (unchanged)

-- Module-level equivalents
local power = Ref.pow(a, b)  -- Equivalent to a ^ b
print(Ref.get(power))  -- 100000

-- Arithmetic only applies to scalar refs, not proxy refs.
-- Proxy refs have no arithmetic metamethods (table + table would error anyway
-- unless the underlying tables define __add etc.).

-- Functions cannot participate in arithmetic:
local func_ref = Ref.new(function() end)
-- This errors: func_ref + b  -- attempt to perform arithmetic on a function value

-- But unwrapped values with custom metatables use those metamethods,
-- and the result is wrapped in a new Ref:
local vector_a = setmetatable({x = 1}, {__add = function(a, b) return {x = a.x + b.x} end})
local vector_b = setmetatable({x = 2}, {__add = function(a, b) return {x = a.x + b.x} end})
local ref_a = Ref.new(vector_a)
local ref_b = Ref.new(vector_b)
local result = ref_a + ref_b  -- Ref holding {x = 3}
print(Ref.get(result).x) -- 3
```

### Comparison Operations

```lua
local small = Ref.new(1)
local large = Ref.new(100)

print(small < large)   -- true (uses __lt)
print(small <= large)  -- true (uses __le)
print(large > small)   -- true (translated to small < large by Lua)
print(large >= small)  -- true (translated to small <= large by Lua)

-- Equality between two scalar Refs sharing the same metatable uses __eq on values:
local ref1 = Ref.new("same")
local ref2 = Ref.new("same")
print(ref1 == ref2)    -- true
```

> Lua only calls `__eq` when both operands share the same metatable, and only
> calls `__lt`/`__le` when at least one operand has the metamethod. Proxy refs use
> per-instance metatables with no comparison metamethods, so proxy comparisons are
> identity-based. For reliable checks use `Ref.get(ref) == value`.

### Functional Operations

```lua
local ref = Ref.new(10)

-- Map: Transform the value into a NEW Ref
local doubled = Ref.map(ref, function(x)
    return x * 2
end)
print(Ref.get(doubled)) -- 20
print(Ref.get(ref)) -- 10 (unchanged)

-- Update: Transform in place (returns self for chaining)
Ref.update(ref, function(x)
    return x + 5
end)
print(Ref.get(ref))    -- 15

-- Colon syntax also works on instances: ref:map(fn), ref:update(fn), ref:get(), ref:set(v)
```

### Deep Table Wrapping

```lua
local data = {
    user = {
        name = "Bob",
        scores = {85, 92, 78}
    }
}

-- Deep wrapper: nested tables become proxy Refs
local deep = Ref.from_table(data, {deep = true})
-- Equivalent shorthands: local deep = Ref ^ data

-- Nested table access:
-- deep.user is a proxy Ref; deep.user.name is a Ref (scalars in deep mode are wrapped)
print(Ref.get(deep.user.name))         -- "Bob"
print(tostring(deep.user.name))        -- "Bob" via __tostring
print(deep.user.scores[1])    -- 85 (scores is a raw table, returned directly)

-- Modify nested properties (writes go to the original table)
deep.user.scores[1] = 90
print(data.user.scores[1])    -- 90 (original updated)

-- Shallow wrapper for contrast:
local shallow = Ref.from_table(data) -- or Ref * data, Ref + data
print(Ref.get(shallow.user).name) -- "Bob" (shallow.user is a scalar Ref holding the table)

-- Cycle safety: from_table does not recurse, so circular tables never hang
local cyc = {x = 1}
cyc.self = cyc
local wrapped = Ref.from_table(cyc, {deep = true})
print(Ref.get(wrapped.x)) -- 1 (no crash)
print(Ref.is(wrapped.self)) -- true (cyclic field becomes a proxy Ref to the original table)
```

### Reactive Proxies

```lua
local tbl = {x = 1}
-- (Ref >> tbl) returns a factory; call it with on_write to get the proxy
-- NOTE: `>>` syntax requires Lua 5.3+. On Lua 5.1 / LuaJIT use
-- Ref.create_reactive_proxy(tbl, on_write) instead (see below).
local proxy = (Ref >> tbl)(function(k, v)
    print("wrote", k, v)
end)
print(proxy.x) -- 1
proxy.x = 10   -- prints "wrote x 10", updates tbl.x

-- Same via module functions (works on all interpreters, including LuaJIT):
local proxy2 = Ref.create_reactive_proxy(tbl, function(k, v) end)
local proxy3 = Ref.reactive(tbl, function(k, v) end) -- alias
```

## 🎨 Common Usage Patterns

### 1. Configuration Management

```lua
-- Use proxy + readonly for true table immutability.
-- Scalar readonly alone does NOT freeze table contents.
local config = Ref.new({
    debug = true,
    max_connections = 100,
    timeout = 30
}, {proxy = true, readonly = true})

-- Safe to pass around - writes error
function connect_to_database(settings)
    if settings.debug then
        print("Debug mode enabled")
    end
    -- Use settings.max_connections, etc.
end

connect_to_database(config)
-- config.debug = false -- Error: attempt to modify readonly ref
```

### 2. State Management

```lua
-- Use proxy for table-like field access, or scalar + Ref.get
local state = Ref.new({
    user = "nobody",
    logged_in = false,
    page = "home"
}, {proxy = true})

-- Update state safely (replaces whole table, proxy stays valid)
function login(username)
    Ref.update(state, function(s)
        return {
            user = username,
            logged_in = true,
            page = "dashboard"
        }
    end)
end

-- Watch for changes (polling example)
function watch_state()
    local last_user = state.user
    while true do
        if state.user ~= last_user then
            print("User changed from", last_user, "to", state.user)
            last_user = state.user
        end
        -- Wait a bit...
    end
end
```

### 3. Caching with Weak References

```lua
local cache = {}

function get_expensive_data(key)
    -- Check cache first
    if cache[key] then
        local data = Ref.get(cache[key])
        if data then
            return data
        end
    end

    -- Generate expensive data
    local data = expensive_computation(key)

    -- Store in weak reference cache
    cache[key] = Ref.new(data, {weak = true})
    return data
end
```

### 4. Proxy Tables for APIs

```lua
-- Create a table-like interface
local user_data = {
    name = "Alice",
    age = 25
}

local user_proxy = Ref.new(user_data, {proxy = true})

-- Do NOT replace the proxy metatable with setmetatable (that destroys proxying).
-- Validate in a helper or observe via a reactive proxy instead:
local function set_age(v)
    if v < 0 or v > 150 then
        error("Invalid age: " .. tostring(v))
    end
    user_proxy.age = v
end

set_age(30)  -- Works, updates user_data.age
-- set_age(-5)  -- Error: Invalid age

-- Observation (logging) pattern:
local observed = Ref.reactive(user_data, function(k, v)
    print("changed", k, v)
end)
```

### 5. Immutable Data Structures

```lua
function create_point(x, y)
    -- proxy + readonly so .x/.y read directly but writes error
    return Ref.new({x = x, y = y}, {proxy = true, readonly = true})
end

local p1 = create_point(10, 20)
local p2 = create_point(5, 15)

-- Points are immutable - safe to share
function distance(a, b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    return math.sqrt(dx*dx + dy*dy)
end

print(distance(p1, p2))  -- 7.07...
-- p1.x = 99 -- Error: attempt to modify readonly ref
```

## 🔍 Reference API

### Creation

```lua
local _r1 = Ref.new(42)                 -- Create new reference; Ref.new(nil) is always an immutable sentinel
local _w1 = Ref.from_table({x = 1})     -- Shallow by default; {deep=true} for deep, {proxy=true} for proxy fields
local _r2 = Ref(42)                     -- Shorthand for Ref.new(42)
local _w2 = Ref * {x = 1}               -- Shallow-wrap (equivalent to Ref.from_table({x = 1}))
local _w3 = Ref + {x = 1}               -- Shallow-wrap into new table (each field Ref_new(v))
local _w4 = Ref % {u = {n = 1}}         -- Deep-proxy wrapper (deep=true, proxy=true)
local _w5 = Ref ^ {u = {n = 1}}         -- Deep wrapper (deep=true)
local _w6 = Ref - {u = {n = 1}}         -- Readonly deep wrapper (deep=true, readonly=true)
local _w7 = Ref / {u = {n = 1}}         -- Alias for Ref- (readonly deep wrapper)
local _fac = Ref >> {x = 1}             -- Reactive factory: (Ref >> tbl)(on_write) -> proxy
local readonly = -Ref                   -- Readonly factory function
local _ro = readonly("hi")              -- Create readonly ref (same as Ref.new("hi", {readonly=true}))
```

Options (`RefOptions`): `proxy?`, `readonly?`, `weak?`, `deep?` (only affects `from_table`).
`nil` values ignore all options and always become readonly sentinels.

### Access

```lua
local ref = Ref.new("hi")
assert(ref() == "hi")         -- Callable getter (0 args); scalar returns value, proxy returns underlying table
assert(ref:get() == "hi")     -- Method syntax (same as Ref.get(ref))
assert(Ref.get(ref) == "hi")  -- Module syntax
assert(tostring(ref) == "hi") -- Same as tostring(Ref.get(ref))
assert(tostring(Ref) == "Ref")
```

### Modification

```lua
local ref = Ref.new(1)
local value = 2
ref:set(value)       -- Method syntax (returns self for chaining)
assert(Ref.get(ref) == 2)
ref(value + 1)       -- Callable setter (1 arg, even nil sets; 0 args gets)
assert(ref() == 3)
Ref.set(ref, value)  -- Module syntax (returns self)
assert(ref() == 2)
```

### Functional

```lua
local ref = Ref.new(5)
local function double(x) return x * 2 end
local mapped = Ref.map(ref, double)     -- Transform value into NEW Ref (also ref:map(fn))
assert(Ref.get(mapped) == 10 and Ref.get(ref) == 5)
Ref.update(ref, double)  -- Transform in place, returns self (also ref:update(fn))
assert(Ref.get(ref) == 10)
```

### Arithmetic Operators

```lua
local a = Ref.new(10)
local b = Ref.new(5)
-- Infix operators (between scalar Refs, or Ref + raw; always return new Ref)
assert(Ref.get(a + b) == 15)  -- Addition
assert(Ref.get(a - b) == 5)   -- Subtraction
assert(Ref.get(a * b) == 50)  -- Multiplication
assert(Ref.get(a / b) == 2)   -- Division
assert(Ref.get(a % b) == 0)   -- Modulo
assert(Ref.get(a ^ b) == 100000) -- Power
assert(Ref.get(-a) == -10)    -- Negation on instance (returns new Ref); -Ref on module is readonly factory

-- Module functions (equivalent, unwrap then operate then wrap)
assert(Ref.get(Ref.add(a, b)) == 15)  -- Addition
assert(Ref.get(Ref.sub(a, b)) == 5)   -- Subtraction
assert(Ref.get(Ref.mul(a, b)) == 50)  -- Multiplication
assert(Ref.get(Ref.div(a, b)) == 2)   -- Division
assert(Ref.get(Ref.mod(a, b)) == 0)   -- Modulo
assert(Ref.get(Ref.pow(a, b)) == 100000) -- Power

-- String concatenation (returns new Ref)
assert(Ref.get(a .. b) == "105") -- Concatenation (tostring both sides, wrap result)
```

### Information

```lua
local ref = Ref.new(42)
assert(Ref.is(ref))                       -- Is this a reference? (boolean, safe for any value)
assert(not Ref.is(42))
assert(not Ref.is_readonly(ref))          -- Is this readonly? (nil sentinels are always readonly)
assert(Ref.is_readonly(Ref.new(nil)))
assert(not Ref.is_weak(ref))              -- Is this a weak reference?
assert(Ref.is_weak(Ref.new({}, {weak = true})))
assert(not Ref.is_nil_sentinel(ref))      -- Is this a nil sentinel? (only Ref.new(nil))
assert(Ref.is_nil_sentinel(Ref.new(nil)))
assert(Ref.unwrap(ref) == 42)             -- Unwrap Ref if present, else return v as-is (also ref:unwrap())
assert(Ref.unwrap("hi") == "hi")
local t = {x = 1}
local p = Ref.create_reactive_proxy(t, function() end)  -- Reactive proxy factory (alias: Ref.reactive)
assert(p.x == 1)
assert(Ref.reactive(t, function() end).x == 1)
```

## ⚠️ Important Notes

### Comparison Limitations

Due to Lua's metamethod system, some comparisons don't work as expected:

```lua
local ref = Ref.new("hello")
print(ref == "hello")  -- false (different metatables, __eq not called)
print("hello" == ref)  -- false (same reason)

-- Ref vs Ref with shared metatable DOES use __eq/__lt/__le:
local r1 = Ref.new("same")
local r2 = Ref.new("same")
print(r1 == r2) -- true

-- Proxy refs have per-instance metatables with no comparison metamethods:
-- proxy comparisons are identity-based. Use Ref.get() for reliability:
print(Ref.get(ref) == "hello")  -- Always works
```

### Nil Value Handling

```lua
-- Ref.new(nil) creates a special readonly sentinel (options ignored)
local nil_ref = Ref.new(nil)
print(Ref.is_nil_sentinel(nil_ref))  -- true
print(Ref.is_readonly(nil_ref))       -- true
print(Ref.get(nil_ref))              -- nil

-- Nil sentinel refs cannot be modified (set, call, or update all error)
nil_ref:set("fail")    -- Error: attempt to modify nil sentinel ref

-- Regular refs can be set to nil and stay mutable (they do NOT become sentinels)
local ref = Ref.new("value")
ref:set(nil)  -- Works fine (also ref(nil) works: 1 arg = setter)
print(Ref.get(ref))  -- nil
print(Ref.is_nil_sentinel(ref))  -- false (not a sentinel)
ref:set("again") -- Works
```

### Proxy Notes

- `Ref.set(proxy, new_table)` replaces the whole target; field access stays consistent.
- `proxy(new_table)` also replaces the target; `proxy()` with no args is a getter.
- Deep mode (`deep=true`) wraps scalar field reads in new Refs each time; compare via `Ref.get()` or `tostring()`, not identity.
- `Ref.from_table` does not recurse into nested tables (it wraps them as proxy Refs), so circular tables never hang.
- Never `setmetatable` a proxy directly; you will discard its `__index/__newindex`.

### Performance Considerations

- References are lightweight but add some overhead
- Proxy references have additional overhead for table access
- Weak references require garbage collection to work properly
- Deep wrapping creates many nested references

## 🎯 Best Practices

1. **Use readonly + proxy for configuration** - Prevents accidental modification (scalar readonly alone does not freeze tables)
2. **Use proxy for table-like APIs** - Provides clean interface; validate via helpers, observe via `Ref.reactive`
3. **Use weak for caching** - Allows automatic cleanup
4. **Prefer functional operations** - More predictable than mutation
5. **Handle nil specially** - `Ref.new(nil)` is immutable; start optionals from non-nil if you need to mutate
6. **Test comparisons** - Be aware of Lua `__eq`/`__lt` limitations; prefer `Ref.get()`; proxies compare by identity

## 📚 Examples

See the test file `ref.tests.lua` for comprehensive usage examples covering all features and edge cases.

## 🤝 Contributing

This module is designed to be lightweight and dependency-free. When contributing:

- Keep the API simple and consistent
- Maintain backward compatibility
- Add tests for new features
- Document edge cases and limitations

## 📄 License

MIT License - Feel free to use in any project.
