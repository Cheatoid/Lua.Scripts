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

-- Deep table wrapping with Ref* syntax
local data = {
    user = {name = "Alice", age = 25},
    settings = {theme = "dark"}
}
local wrapped = Ref* data -- Shorthand for deep wrapper
-- Now you can access nested properties directly:
print(wrapped.user.name)  -- "Alice"
wrapped.user.age = 26     -- Updates original data
assert(data.age == 26)
```

### Module-Level Operators

```lua
local a = Ref(10)
local b = Ref(5)

-- Use standard module functions for arithmetic
local sum = Ref.add(a, b)  -- 15
local diff = Ref.sub(a, b) -- 5
local prod = Ref.mul(a, b) -- 50
local quot = Ref.div(a, b) -- 2
local mod = Ref.mod(a, b)  -- 0
local pow = Ref.pow(a, b)  -- 100000

-- String concatenation with .. operator
local str1 = Ref.new("hello")
local str2 = Ref.new("world")
local greeting = str1 .. " " .. str2 -- "hello world"

-- Special constructor shorthands:
Ref+ {table} -- merge refs into table
Ref* {table} -- deep wrapper (equivalent to Ref.from_table)
Ref% {table} -- deep-proxy wrapper (equivalent to Ref.from_table with deep=true, proxy=true)
Ref^ {table} -- deep wrapper (equivalent to Ref.from_table with deep=true)
Ref/ {table} -- readonly wrapper (equivalent to Ref.from_table with deep=true, readonly=true)

-- Readonly factory using unary minus
local readonly = -Ref  -- Returns a function that creates readonly refs
local readonly_str = readonly("hello")  -- Same as Ref.new("hello", {readonly = true})
```

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
print(Ref.get(tbl_ref)) -- {x = 1, y = 2} (module syntax)

-- Setting values
num_ref:set(100)
str_ref("world")        -- callable setter
Ref.set(tbl_ref, {x = 3, y = 4})
```

### Reference Types

#### 1. Regular References

```lua
-- Different types of values
local num_ref = Ref.new(42)
local str_ref = Ref.new("hello")
local func_ref = Ref.new(function() return "result" end)
local bool_ref = Ref.new(true)

-- All work the same way
print(num_ref())   -- 42
print(str_ref())   -- "hello"
print(func_ref())  -- "result"
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
```

#### 3. Proxy References

```lua
local table = {name = "Alice", age = 25}
local proxy = Ref.new(table, {proxy = true})

-- Access table properties directly
print(proxy.name)       -- "Alice"
proxy.age = 26          -- Updates the original table
print(table.age)        -- 26
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

#### 5. Nil Sentinel References

```lua
-- Creating a nil Ref creates a special readonly sentinel
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
print(err)     -- "attempt to modify nil sentinel ref"

-- Use case: Constant nil values
local NULL = Ref.new(nil)  -- Perfect for representing null/undefined values
-- NULL is immutable and clearly signals "no value"
```

#### 6. Regular Nil Values

```lua
-- Regular refs can be set to nil (become normal refs with nil value)
local ref = Ref.new("value")
ref:set(nil)  -- Works fine
print(Ref.get(ref))  -- nil
print(Ref.is_nil_sentinel(ref))  -- false (not a sentinel)
print(Ref.is_readonly(ref))  -- false (mutable)

-- Setting to nil after creation
local num_ref = Ref.new(42)
num_ref:set(nil)
print(Ref.get(num_ref))  -- nil

-- Use case: Optional values that may be nil
local optional_field = Ref.new(nil)  -- Start as nil
if some_condition then
    optional_field:set("value")  -- Set when available
end
-- optional_field will be nil if never set, or explicitly set to nil
```

## 🔧 Advanced Features

### Arithmetic Operations

```lua
local a = Ref.new(10)
local b = Ref.new(5)

-- All arithmetic operators work (except with functions)
print(a + b)           -- 15
print(a - b)           -- 5
print(a * b)           -- 50
print(a / b)           -- 2
print(a % b)           -- 0
print(a ^ b)           -- 100000 (power operator)
print(-a)              -- -10

-- Operations create new references
local sum = a + b
print(Ref.get(sum))    -- 15
print(Ref.get(a))      -- 10 (unchanged)

-- Module-level power operator
local power = Ref.pow(a, b)  -- Equivalent to a ^ b
print(Ref.get(power))  -- 100000

-- Note: Functions cannot participate in arithmetic unless they have custom metatables
local func_ref = Ref.new(function() end)
-- This will error: func_ref + b  -- "cannot perform arithmetic on function values"

-- But if functions have custom metatables, those will be used
local vector_a = setmetatable({x = 1}, {__add = function(a, b) return {x = a.x + b.x} end})
local vector_b = setmetatable({x = 2}, {__add = function(a, b) return {x = a.x + b.x} end})
local ref_a = Ref.new(vector_a)
local ref_b = Ref.new(vector_b)
local result = ref_a + ref_b  -- Uses custom __add, returns {x = 3}
```

### Comparison Operations

```lua
local small = Ref.new(1)
local large = Ref.new(100)

print(small < large)   -- true
print(small <= large)  -- true
print(large > small)   -- true
print(large >= small)  -- true

-- Equality comparison
local ref1 = Ref.new("same")
local ref2 = Ref.new("same")
print(ref1 == ref2)    -- true
```

### Functional Operations

```lua
local ref = Ref.new(10)

-- Map: Transform the value
local doubled = Ref.map(ref, function(x)
    return x * 2
end)
print(Ref.get(doubled)) -- 20

-- Update: Transform in place
Ref.update(ref, function(x)
    return x + 5
end)
print(Ref.get(ref))    -- 15
```

### Deep Table Wrapping

```lua
local data = {
    user = {
        name = "Bob",
        scores = {85, 92, 78}
    }
}

-- Create deep wrapper for nested access
--local deep = Ref.from_table(data, {deep = true})
local deep = Ref

-- Access nested properties
print(deep.user.name)         -- "Bob"
print(deep.user.scores[1])    -- 85

-- Modify nested properties
deep.user.scores[1] = 90
print(data.user.scores[1])    -- 90 (original updated)
```

## 🎨 Common Usage Patterns

### 1. Configuration Management

```lua
-- Create a readonly configuration
local config = Ref.new({
    debug = true,
    max_connections = 100,
    timeout = 30
}, {readonly = true})

-- Safe to pass around - can't be accidentally modified
function connect_to_database(settings)
    if settings.debug then
        print("Debug mode enabled")
    end
    -- Use settings.max_connections, etc.
end

connect_to_database(config)
```

### 2. State Management

```lua
-- Application state
local state = Ref.new({
    user = nil,
    logged_in = false,
    page = "home"
})

-- Update state safely
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
-- Create a table-like interface with validation
local user_data = {
    name = "Alice",
    age = 25
}

local user_proxy = Ref.new(user_data, {proxy = true})

-- Add validation through metatable
setmetatable(user_proxy, {
    __newindex = function(table, key, value)
        if key == "age" and (value < 0 or value > 150) then
            error("Invalid age: " .. value)
        end
        rawset(table, key, value)
    end
})

user_proxy.age = 30  -- Works
user_proxy.age = -5  -- Error: Invalid age
```

### 5. Immutable Data Structures

```lua
function create_point(x, y)
    return Ref.new({x = x, y = y}, {readonly = true})
end

local p1 = create_point(10, 20)
local p2 = create_point(5, 15)

-- Points are immutable - safe to share
function distance(p1, p2)
    local dx = p1.x - p2.x
    local dy = p1.y - p2.y
    return math.sqrt(dx*dx + dy*dy)
end

print(distance(p1, p2))  -- 7.07...
```

## 🔍 Reference API

### Creation

```lua
Ref.new(value, options)         -- Create new reference
Ref.from_table(table, options)  -- Create deep wrapper
Ref(value)                      -- Shorthand for Ref.new()
Ref* table                      -- Shorthand for deep wrapper
Ref+ {table}                   -- Merge refs into table
Ref% {table}                   -- Deep-proxy wrapper (deep=true, proxy=true)
Ref^ {table}                   -- Deep wrapper (deep=true)
Ref/ {table}                   -- Readonly wrapper (deep=true, readonly=true)
-Ref                           -- Readonly factory function
local readonly = -Ref
readonly(value)                -- Create readonly ref
```

### Access

```lua
ref()         -- Callable syntax
ref:get()     -- Method syntax
Ref.get(ref)  -- Module syntax
```

### Modification

```lua
ref:set(value)       -- Method syntax
ref(value)           -- Callable syntax
Ref.set(ref, value)  -- Module syntax
```

### Functional

```lua
Ref.map(ref, transform_fn)     -- Transform value
Ref.update(ref, transform_fn)  -- Transform in place
```

### Arithmetic Operators

```lua
-- Infix operators (between references)
a + b  -- Addition
a - b  -- Subtraction  
a * b  -- Multiplication
a / b  -- Division
a % b  -- Modulo
a ^ b  -- Power
-a     -- Negation

-- Standard module functions (equivalent)
Ref.add(a, b)  -- Addition
Ref.sub(a, b)  -- Subtraction
Ref.mul(a, b)  -- Multiplication
Ref.div(a, b)  -- Division
Ref.mod(a, b)  -- Modulo
Ref.pow(a, b)  -- Power

-- String concatenation
a .. b        -- Concatenation (returns new Ref)
```

### Information

```lua
Ref.is(ref)                       -- Is this a reference?
Ref.is_readonly(ref)              -- Is this readonly?
Ref.is_weak(ref)                  -- Is this a weak reference?
Ref.is_nil_sentinel(ref)          -- Is this a nil sentinel?
```

## ⚠️ Important Notes

### Comparison Limitations

Due to Lua's metamethod system, some comparisons don't work as expected:

```lua
local ref = Ref.new("hello")
print(ref == "hello")  -- May not work (Lua limitation)
print("hello" == ref)  -- May not work (Lua limitation)

-- Use Ref.get() for reliable comparisons
print(Ref.get(ref) == "hello")  -- Always works
```

### Nil Value Handling

```lua
-- Ref.new(nil) creates a special readonly sentinel
local nil_ref = Ref.new(nil)
print(Ref.is_nil_sentinel(nil_ref))  -- true
print(Ref.is_readonly(nil_ref))       -- true
print(Ref.get(nil_ref))              -- nil

-- Nil sentinel refs cannot be modified
nil_ref:set("fail")    -- Error: attempt to modify nil sentinel ref

-- Regular refs can be set to nil (become normal refs with nil value)
local ref = Ref.new("value")
ref:set(nil)  -- Works fine
print(Ref.get(ref))  -- nil
print(Ref.is_nil_sentinel(ref))  -- false (not a sentinel)
```

### Performance Considerations

- References are lightweight but add some overhead
- Proxy's references have additional overhead for table access
- Weak references require garbage collection to work properly
- Deep wrapping creates many nested references

## 🎯 Best Practices

1. **Use readonly for configuration** - Prevents accidental modification
2. **Use proxy for table-like APIs** - Provides clean interface
3. **Use weak for caching** - Allows automatic cleanup
4. **Prefer functional operations** - More predictable than mutation
5. **Handle nil specially** - Understand nil sentinel behavior
6. **Test comparisons** - Be aware of Lua limitations

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
