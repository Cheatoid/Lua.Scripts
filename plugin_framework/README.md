# Plugin Framework

A simple but powerful plugin system for Lua with dependency injection, lifecycle management, events, and hot-reloading.

## Table of Contents

- [Overview](#overview)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [PluginManager](#pluginmanager)
    - [Service Registry](#service-registry)
    - [Event Bus](#event-bus)
    - [Plugin Lifecycle](#plugin-lifecycle)
    - [Dynamic Loading](#dynamic-loading)
    - [Hot Reloading](#hot-reloading)
- [Plugin Builder](#plugin-builder)
- [Examples](#examples)
- [API Reference](#api-reference)

## Overview

The Plugin Framework provides:

- **Dependency Injection** - Register and retrieve services across plugins
- **Lifecycle Management** - Init, start, and stop hooks with dependency ordering
- **Event System** - Publish/subscribe pattern for plugin communication
- **Hot Reloading** - Update plugins without restarting
- **Sandboxed Loading** - Load plugins from strings or functions safely

## Installation

```lua
local PluginFramework = require "@cheatoid/plugin_framework/plugin_framework"
local PluginManager = PluginFramework.PluginManager
local Plugin = PluginFramework.Plugin
```

## Quick Start

```lua
local PluginFramework = require "@cheatoid/plugin_framework/plugin_framework"
local PluginManager = PluginFramework.PluginManager
local Plugin = PluginFramework.Plugin

-- Create a manager
local manager = PluginManager.new({ debug = true })

-- Register a service
manager:register_service("logger", {
    log = function(msg) print("[LOG]", msg) end
})

-- Create a plugin using the builder
local my_plugin = Plugin("my_plugin")
    :with_init(function(self, mgr)
        print("Initializing...")
        self.state.count = 0
    end)
    :with_start(function(self)
        print("Starting...")
    end)
    :with_stop(function(self)
        print("Stopping...")
    end)

-- Register and run
manager:register(my_plugin)
manager:init_all()
manager:start_all()
```

## PluginManager

### Service Registry

Register services for dependency injection:

```lua
-- Register a service
manager:register_service("database", {
    query = function(sql) ... end,
    insert = function(data) ... end
})

-- Check if service exists
if manager:has_service("database") then
    print("Database service available")
end

-- Get a service
local db = manager:get_service("database")
db.query("SELECT * FROM users")
```

### Event Bus

Register and emit events:

```lua
-- Register event handler
manager:on("player:join", function(player)
    print("Player joined:", player.name)
end)

-- Emit event
manager:emit("player:join", { name = "Alice", id = 123 })

-- Unregister handler
local handler = function(msg) print(msg) end
manager:on("log", handler)
manager:off("log", handler)
```

### Plugin Lifecycle

Manage plugin registration and lifecycle:

```lua
-- Register a plugin
manager:register(plugin)

-- Check if plugin exists
if manager:has_plugin("my_plugin") then ... end

-- Get a plugin
local p = manager:get_plugin("my_plugin")

-- List all plugins
local names = manager:list_plugins()
for _, name in ipairs(names) do
    print("Plugin:", name)
end

-- Initialize all plugins (respects dependencies)
manager:init_all()

-- Start all plugins
manager:start_all()

-- Stop all plugins (reverse dependency order)
manager:stop_all()

-- Unregister a plugin
manager:unregister("my_plugin")

-- Clean up dead plugins
local cleaned = manager:cleanup_dead_plugins()
```

### Dynamic Loading

Load plugins from strings or functions:

> **Note:** `loadstring` method is an alias of `load_plugin_from_string` and can be used interchangeably.

```lua
-- Load from string
local code = [[
function plugin:init(manager)
    print("Plugin initialized!")
    self.state.value = 42
end
return plugin
]]
local plugin = manager:load_plugin_from_string("dynamic_plugin", code)

-- Load from function
local plugin2 = manager:load_plugin_from_function("func_plugin", function(p)
    p.greet = function() print("Hello!") end
    return p
end)

-- Load with custom state and config
local plugin3 = manager:load_plugin_from_string("custom_plugin", code, {
    state = { value = 100 },
    config = { max_items = 50 }
})
```

### Hot Reloading

Update plugins without restart:

```lua
-- Hot reload from string
local new_code = [[
function plugin:init(manager)
    print("Updated!")
end
return plugin
]]
manager:hot_reload("my_plugin", new_code)

-- Hot reload from function
manager:hot_reload_function("my_plugin", function(p)
    p.updated = true
    return p
end)

-- Generic reload (auto-detects type)
manager:reload("my_plugin", new_code)
```

## Plugin Builder

Create plugins with the fluent API:

```lua
local plugin = Plugin("my_plugin")
    -- Dependencies
    :depends_on("other_plugin", "another_plugin")
    
    -- Lifecycle
    :with_init(function(self, manager)
        -- Called during init_all()
        -- Receives (self, manager)
        self.state.data = {}
    end)
    :with_start(function(self)
        -- Called during start_all()
        -- Receives (self)
        print("Plugin started!")
    end)
    :with_stop(function(self)
        -- Called during stop_all()
        -- Receives (self)
        print("Plugin stopped!")
    end)
    
    -- Configuration
    :with_config({
        max_items = 100,
        enabled = true
    })
    
    -- Enable/disable
    :enable()   -- or :disable(), :toggle()
```

### Plugin State and Config

```lua
-- Access in lifecycle methods or custom functions
function plugin:do_something()
    if not self.enabled then return end
    
    local max = self.config.max_items
    local current = #self.state.data
    
    if current < max then
        table.insert(self.state.data, "item")
    end
end
```

### Plugin Reload

```lua
-- Reload from within a plugin
function plugin:update(code)
    local reloaded = self:reload(code)
    if not reloaded then
        print("Reload failed - plugin has no manager")
    end
    return reloaded
end
```

## Examples

### Complete Plugin Example

```lua
local PluginFramework = require "@cheatoid/plugin_framework/plugin_framework"
local PluginManager = PluginFramework.PluginManager
local Plugin = PluginFramework.Plugin

-- Create manager
local manager = PluginManager.new({ debug = true })

-- Register logger service
manager:register_service("logger", {
    info = function(msg) print("[INFO]", msg) end,
    error = function(msg) print("[ERROR]", msg) end,
})

-- Create counter plugin
local counter = Plugin("counter")
    :with_config({ max_count = 10 })
    :with_init(function(self, mgr)
        self.state.count = 0
        local logger = mgr:get_service("logger")
        logger.info("Counter initialized")
    end)
    :with_start(function(self)
        print("Counter started at", self.state.count)
    end)
    :with_stop(function(self)
        print("Counter stopped at", self.state.count)
    end)

-- Add custom method
function counter:increment()
    if self.state.count < self.config.max_count then
        self.state.count = self.state.count + 1
        return true
    end
    return false
end

-- Register and run
manager:register(counter)
manager:init_all()
manager:start_all()

-- Use the plugin
counter:increment()
print("Count:", counter.state.count)

-- Stop
manager:stop_all()
```

### Plugin with Dependencies

```lua
-- Base plugin
local base = Plugin("base")
    :with_init(function(self)
        self.state.api = { version = "1.0" }
    end)

-- Dependent plugin
local dependent = Plugin("dependent")
    :depends_on("base")
    :with_init(function(self, mgr)
        local base_plugin = mgr:get_plugin("base")
        print("Base API version:", base_plugin.state.api.version)
    end)

-- Register both
manager:register(base)
manager:register(dependent)

-- Base will be initialized before dependent
manager:init_all()
```

### Event Communication

```lua
-- Plugin that emits events
local emitter = Plugin("emitter")
    :with_start(function(self)
        -- Emit custom event
        if self.emit then
            self:emit("custom:event", { data = "test" })
        end
    end)

-- Register event handler on manager
manager:on("custom:event", function(data)
    print("Received:", data.data)
end)

-- Make emit available to plugin via metatable or services
```

## API Reference

### PluginManager

| Method                                      | Description                                                   |
| ------------------------------------------- | ------------------------------------------------------------- |
| `new(opts)`                                 | Create a new manager instance                                 |
| `register_service(name, svc)`               | Register a service                                            |
| `get_service(name)`                         | Get a registered service                                      |
| `has_service(name)`                         | Check if service exists                                       |
| `on(event, handler)`                        | Register event handler                                        |
| `off(event, handler)`                       | Unregister event handler                                      |
| `emit(event, ...)`                          | Emit an event                                                 |
| `register(plugin)`                          | Register a plugin                                             |
| `unregister(name)`                          | Unregister a plugin                                           |
| `get_plugin(name)`                          | Get a plugin by name                                          |
| `has_plugin(name)`                          | Check if plugin exists                                        |
| `list_plugins()`                            | Get list of plugin names                                      |
| `cleanup_dead_plugins()`                    | Remove invalid plugins                                        |
| `init_all()`                                | Initialize all plugins                                        |
| `start_all()`                               | Start all plugins                                             |
| `stop_all()`                                | Stop all plugins                                              |
| `load_plugin_from_string(name, code, opts)` | Load plugin from code (opts can contain state and config)     |
| `loadstring(name, code, opts)`              | Alias for above                                               |
| `load_plugin_from_function(name, fn, opts)` | Load plugin from function (opts can contain state and config) |
| `hot_reload(name, code)`                    | Hot reload from string                                        |
| `hot_reload_function(name, fn)`             | Hot reload from function                                      |
| `reload(name, code)`                        | Generic reload                                                |

### Plugin Builder

| Method             | Description                          |
| ------------------ | ------------------------------------ |
| `depends_on(...)`  | Specify dependencies                 |
| `with_init(fn)`    | Set init function                    |
| `with_start(fn)`   | Set start function                   |
| `with_stop(fn)`    | Set stop function                    |
| `with_config(cfg)` | Set configuration                    |
| `enable()`         | Enable plugin                        |
| `disable()`        | Disable plugin                       |
| `toggle()`         | Toggle enabled state                 |
| `reload(code)`     | Reload plugin (returns nil on error) |

### Plugin Fields

| Field     | Description               |
| --------- | ------------------------- |
| `name`    | Plugin name               |
| `state`   | Plugin state table        |
| `config`  | Plugin configuration      |
| `enabled` | Whether plugin is enabled |
| `deps`    | Array of dependency names |
| `manager` | Weak reference to manager |
| `init`    | Init function             |
| `start`   | Start function            |
| `stop`    | Stop function             |

## License

MIT License
