# chat_commander

Advanced command parser and dispatcher for (in-game) chat commands with comprehensive autocompletion, flexible argument
parsing, type coercion, validation, and a fluent API.

## Features

- **Fluent API** for intuitive command building
- **Advanced argument parsing** with positional, named (key=value), and mixed support
- **Rich type system** with built-in types (string, number, boolean, integer, any) and custom type registration
- **Multi-type arguments** supporting multiple valid types for same argument
- **Anonymous arguments** with automatic numerical indexing
- **Comprehensive autocompletion** with context-aware suggestions
- **Permission system** with custom validation
- **Enum validation** with case-sensitive matching
- **Escape sequence support** in quoted strings
- **Hexadecimal and binary literals** for number types
- **Varargs support** for capturing remaining arguments
- **Custom validation** at registration and execution time

## Installation

```lua
local chat_commander = require "chat_commander"
```

## Basic Usage

### Standard API

```lua
chat_commander.register_command("teleport", {
    description = "Teleport to coordinates",
    args = {
        { "x", "number" },  -- Simplified syntax: { name, type }
        { "y", type = "number" },  -- Mixed syntax
        { name = "z", type = "number", default = 0 },  -- Optional with default
        { name = "speed", type = "number?" },  -- Optional with ? suffix
    },
    handler = function(ctx, args)
        -- ctx: { raw = string, player = <your player object>, ... }
        -- args: { x = <number>, y = <number>, z = <number>, speed = <number?> }
        print("Teleporting to:", args.x, args.y, args.z)
        if args.speed then
            print("Speed:", args.speed)
        end
    end,
})

local ok, err = chat_commander.handle_line({ player = player }, "/teleport 10 20 30")
```

### Fluent API

For a more expressive syntax, use the fluent builder pattern:

```lua
chat_commander.register_command("teleport")
    :description("Teleport to coordinates")
    :arg("x", "number")
    :arg("y", "number")
    :arg("z", "number", 0)  -- third parameter is default value
    :arg("speed", "number?")  -- ? suffix marks as optional
    :handler(function(ctx, args)
        print("Teleporting to:", args.x, args.y, args.z)
        if args.speed then
            print("Speed:", args.speed)
        end
    end)
    :register()
```

**Fluent API methods:**

- **Basic setup:**
    - `:description(text)` - Set command description
    - `:aliases({ "alt1", "alt2" })` - Set command aliases
    - `:register()` - Register the command (requires handler to be set first)

- **Arguments:**
    - `:arg(name, type)` - Add a named argument
    - `:arg(name, type, default)` - Add a named argument with default value
    - `:arg(type, default)` - Add anonymous argument with default (second param is default if not a string)
    - `:arg(spec)` - Add an argument using table specification (for enum, raw, etc.)
    - `:arg({ "name", "type" })` - Simplified array syntax
    - `:arg({ "name", "type", default })` - Simplified array syntax with default
    - `:arg("type")` - Anonymous argument with type

- **Validation & permissions:**
    - `:handler(fn)` - Set the handler function (required before `:register()`)
    - `:permission(fn)` - Set permission check
    - `:validate(fn)` - Set registration-time validation
    - `:pre_validate(fn)` - Set execution-time validation
    - `:enum({ "choice1", "choice2" })` - Set enum choices for the last added argument
    - `:pass_varargs(true/false)` - Enable/disable passing rest arguments as varargs (enabled by default for fluent API)

**Using aliases with fluent API:**

```lua
chat_commander.cmd("teleport")  -- cmd is an alias for register_command
    :description("Teleport to coordinates")
    :arg("x", "number")
    :arg("y", "number")
    :handler(function(ctx, args) end)
    :register()
```

**Using enums with fluent API:**

```lua
-- Table syntax
chat_commander.register_command("color")
    :description("Set color")
    :arg("color", "string")
    :enum({ "red", "green", "blue" })
    :handler(function(ctx, args)
        print("Color:", args.color)
    end)
    :register()

-- Varargs syntax (more convenient)
chat_commander.register_command("color")
    :description("Set color")
    :arg("color", "string")
    :enum("red", "green", "blue")  -- Varargs automatically creates table
    :handler(function(ctx, args)
        print("Color:", args.color)
    end)
    :register()
```

**Using varargs with fluent API:**

```lua
chat_commander.register_command("echo")
    :description("Echo all arguments")
    :arg("prefix", "string", "")
    :handler(function(ctx, args)
        -- args._rest contains remaining positional arguments
        if args._rest then
            print(args.prefix .. table.concat(args._rest, " "))
        else
            print(args.prefix)
        end
    end)
    :register()

-- Usage: /echo Hello World -> outputs: Hello World
-- Usage: /echo ">>" Hello World -> outputs: >>Hello World
```

**Passing varargs to handler:**

```lua
-- Standard API (opt-in)
chat_commander.register_command("sum", {
    description = "Sum numbers",
    args = {
        { name = "base", type = "number" },
    },
    pass_varargs = true,  -- Enable varargs passing
    handler = function(ctx, args, ...)
        local total = args.base
        for i = 1, select("#", ...) do
            total = total + tonumber(select(i, ...))
        end
        print("Total:", total)
    end,
})

-- Fluent API (enabled by default)
chat_commander.register_command("multiply")
    :description("Multiply numbers")
    :arg("base", "number")
    :handler(function(ctx, args, ...)
        local total = args.base
        for i = 1, select("#", ...) do
            total = total * tonumber(select(i, ...))
        end
        print("Total:", total)
    end)
    :register()

-- Fluent API (disable if needed)
chat_commander.register_command("disabled_varargs")
    :description("Varargs disabled")
    :arg("x", "number")
    :pass_varargs(false)  -- Disable varargs
    :handler(function(ctx, args)
        print("X:", args.x)
    end)
    :register()

-- Usage: /sum 10 20 30 -> outputs: Total: 60
-- Usage: /multiply 2 3 4 -> outputs: Total: 24
```

## Argument Types

### Built-in Types

- `string` / `str` - Text values
- `number` / `num` / `float` - Floating point numbers (aliases for the same type)
- `integer` / `int` - Whole numbers
- `boolean` / `bool` - true/false values (accepts: true, false, yes, no, on, off, 1, 0)
- `any` - Accepts any value without coercion (returns raw string)

**Enums:** Any argument can accept enum values by specifying an `enum` array. Enum values are case-sensitive and
restrict input to the specified choices. Enum suggestions take precedence over type suggestions in autocompletion.

### Custom Types

```lua
-- Register a custom type
chat_commander.register_type("vector3", function(token)
    local x, y, z = token:match("([^,]+),([^,]+),([^,]+)")
    if not x or not y or not z then
        return nil, "expected format: x,y,z"
    end
    return { x = tonumber(x), y = tonumber(y), z = tonumber(z) }
end)

-- Use it in a command
chat_commander.register_command("move", {
    args = {
        { name = "pos", type = "vector3" },
    },
    handler = function(ctx, args)
        print("Moving to:", args.pos.x, args.pos.y, args.pos.z)
    end,
})
```

### Multiple Types

Arguments can accept multiple types by specifying an array:

```lua
chat_commander.register_command("set_value", {
    args = {
        { name = "value", type = { "vector3", "number" } },  -- Accepts vector3 or number
    },
    handler = function(ctx, args)
        -- Tries vector3 first, falls back to number
    end,
})
```

## Argument Syntax

### Standard Syntax

```lua
{ name = "x", type = "number", required = true, default = 10 }
```

### Simplified Syntax

```lua
{ "x", "number" }              -- Array-style: name, type
{ "x", type = "number" }       -- Mixed: name positional, type named
{ name = "x", "number" }       -- Mixed: name named, type positional
{ "x", "number", default = 10 } -- Works with other fields
```

### Anonymous Arguments

If no name is provided, it defaults to the numerical index:

```lua
chat_commander.register_command("cmd", {
    args = {
        { "number" },  -- Becomes 1
        { "string" },  -- Becomes 2
    },
    handler = function(ctx, args)
        print(args[1], args[2])
    end,
})
```

### Optional Arguments with ? Suffix

You can mark arguments as optional by adding a `?` suffix to the type string. This automatically sets
`required = false`:

```lua
-- Standard API
chat_commander.register_command("mycmd", {
    args = {
        { name = "x", type = "number" },      -- Required
        { name = "y", type = "number?" },     -- Optional with ? suffix
        { name = "z", type = { "string?", "number" } },  -- Optional in multi-type
    },
    handler = function(ctx, args)
        print(args.x, args.y, args.z)  -- y and z may be nil
    end,
})

-- Fluent API
chat_commander.register_command("mycmd")
    :arg("x", "number")      -- Required
    :arg("y", "number?")     -- Optional with ? suffix
    :handler(function(ctx, args)
        print(args.x, args.y)  -- y may be nil
    end)
    :register()
```

## Validation

### Enum Validation

```lua
chat_commander.register_command("color", {
    args = {
        { name = "color", type = "string", enum = { "red", "green", "blue" } },
    },
    handler = function(ctx, args)
        print("Color:", args.color)
    end,
})
```

### Custom Validation

#### Registration-time Validation

```lua
chat_commander.register_command("mycmd", {
    args = { ... },
    validate = function(schema)
        -- Custom validation during registration
        if #schema.args < 2 then
            return false, "must have at least 2 arguments"
        end
        return true
    end,
    handler = function(ctx, args) end,
})
```

#### Execution-time Validation

```lua
chat_commander.register_command("mycmd", {
    args = { ... },
    pre_validate = function(ctx, args)
        -- Custom validation before handler execution
        if args.value < 0 then
            return false, "value must be positive"
        end
        return true
    end,
    handler = function(ctx, args) end,
})
```

## Permissions

```lua
chat_commander.register_command("kick", {
    description = "Kick a player",
    args = {
        { name = "player", type = "string" },
    },
    permission = function(ctx, args)
        -- Return true if allowed, false + reason if denied
        if not ctx.player or not ctx.player.is_admin then
            return false, "admin only"
        end
        return true
    end,
    handler = function(ctx, args)
        -- Kick logic
    end,
})

-- Context warning: warns if permission check exists but no context provided
```

## Autocompletion

### Custom Type Suggestions

Custom suggestion handlers now work inside string literals for arguments with custom types:

```lua
chat_commander.register_suggestions("vector3", function(partial)
    local examples = { "0,0,0", "100,100,100", "-50,-50,-50" }
    local matches = {}
    for i = 1, #examples do
        if string.sub(examples[i], 1, #partial) == partial then
            matches[#matches + 1] = examples[i]
        end
    end
    return matches
end)

chat_commander.register_command("teleport", {
    args = {
        { name = "pos", type = "vector3" },
    },
    handler = function(ctx, args)
        -- args.pos will be coerced by the registered type handler
    end,
})

-- Now typing: /teleport "0,0" will show suggestions inside the quotes
local suggestions = chat_commander.suggest_at('/teleport "0,0"', 14)
```

### Using Autocompletion

```lua
local suggestions = chat_commander.suggest_at("/teleport ", 10)
-- Returns: array of suggestion strings
```

## API Reference

### Functions

#### `register_command(name, schema)` / `cmd(name, schema)` / `reg(name, schema)`

Register a new command.

**Parameters:**

- `name` (string): Command name
- `schema` (table?): Optional command schema (if omitted, returns a builder for fluent API)
    - `description` (string?): Command description
    - `aliases` (string[]?): Alternative names
    - `args` (CommandArg[]?): Argument specifications
    - `handler` (function?): Command handler (optional, warned if missing in standard API, required in fluent API)
    - `permission` (function?): Permission check
    - `validate` (function?): Registration-time validation
    - `pre_validate` (function?): Execution-time validation
    - `pass_varargs` (boolean?): Pass rest arguments as varargs to handler (opt-in for standard API, default true for fluent API)

**Returns:**

- `CommandBuilder|CommandSchema`: Builder if schema is nil, otherwise returns the schema table for later modification

**Late Handler Pattern (Standard API Only):**
You can register a command early and set the handler later by modifying the returned schema. This pattern only works
with the standard API - the fluent API requires the handler to be set before calling `:register()`.

```lua
local schema = chat_commander.register_command("mycmd", {
    description = "Command with late handler",
    args = {
        { name = "value", type = "string" },
    },
})

-- Later, set the handler
schema.handler = function(ctx, args)
    print("Value:", args.value)
end
```

**Note:** The fluent API requires the handler to be set before calling `:register()`. If you need to set the handler
later, use the standard API above.

#### `unregister_command(name)` / `unreg(name)`

Unregister a command by name.

#### `handle_line(ctx, raw_line)` / `exec(ctx, raw_line)`

Parse and execute a command line.

**Parameters:**

- `ctx` (table): Context object (e.g. `{ player = player }`)
- `raw_line` (string): Raw command line

**Returns:**

- `ok` (boolean): Success status
- `result` (any): Result or error message

#### `parse_line(raw_line)` / `parse(raw_line)`

Parse a command line without executing it.

**Parameters:**

- `raw_line` (string): Raw command line

**Returns:**

- `ok` (boolean): Success status
- `parsed` (ParsedCommand?): Parsed command or error message

#### `suggest_at(line, caret, options)`

Get autocompletion suggestions for a line at a caret position.

**Parameters:**

- `line` (string): Command line
- `caret` (number): Caret position
- `options` (table?): Autocompleter options

**Returns:**

- `suggestions` (string[]): Array of suggestion strings

#### `register_type(name, coercer)` / `type(name, coercer)`

Register a custom type coercer.

**Parameters:**

- `name` (string): Type name
- `coercer` (function): Coercer function `fun(token: string): (any, string?)`

#### `register_suggestions(name, handler)`

Register a custom suggestion handler.

**Parameters:**

- `name` (string): Type name
- `handler` (function): Suggestion handler `fun(partial: string): string[]`

#### `get_command(name)` / `get(name)`

Get a command's schema by name.

**Parameters:**

- `name` (string): Command name

**Returns:**

- `schema` (CommandSchema?): Command schema, or nil if not found

#### `get_help(name)`

Get help text for a command.

**Parameters:**

- `name` (string): Command name

**Returns:**

- `help` (string): Help text

#### `list_commands()`

List all registered commands.

**Returns:**

- `commands` (string[]): Array of command names

#### `set_prefix(prefix)`

Set the command prefix (default is "/").

**Parameters:**

- `prefix` (string): New prefix

#### `coerce_vector3(token)`

Coerce a string to a vector3 table.

**Parameters:**

- `token` (string): String to coerce

**Returns:**

- `vector3` (table?): Vector3 table, or nil if invalid

## Command Argument Schema

| Field      | Type                      | Description                                                 |
| ---------- | ------------------------- | ----------------------------------------------------------- |
| `name`     | string \| nil             | Argument name (defaults to numerical index if not provided) |
| `type`     | string \| string[] \| nil | Argument type or array of types                             |
| `required` | boolean \| nil            | Required (defaults to true unless default specified)        |
| `default`  | any \| nil                | Default value if optional                                   |
| `enum`     | string[] \| nil           | Enum choices (restricts input to specified values)          |
| `raw`      | boolean \| nil            | Skip coercion and return raw token                          |

**Rest Arguments:**
Any remaining positional arguments after consuming defined arguments are stored in `args._rest` as an array of strings.
When `pass_varargs` is enabled, these are also passed as varargs (`...`) to the handler function for convenience.

## Examples

### Command with Multiple Types

```lua
chat_commander.register_command("spawn", {
    args = {
        { name = "target", type = { "vector3", "number" } },
    },
    handler = function(ctx, args)
        if type(args.target) == "table" then
            -- Vector3: args.target.x, args.target.y, args.target.z
            print("Spawning at:", args.target.x, args.target.y, args.target.z)
        else
            -- Number: use as single coordinate
            print("Spawning at:", args.target, 0, 0)
        end
    end,
})
```

### Command with Late Handler

```lua
-- Register command schema early, set handler later (standard API)
local schema = chat_commander.register_command("future_cmd", {
    description = "Command to be implemented later",
    args = {
        { name = "param", type = "string" },
    },
    handler = function() end,  -- Dummy handler to suppress warning
})

-- Later, set the actual handler
schema.handler = function(ctx, args)
    print("Handling future command:", args.param)
end
```

### Command with Custom Validation

```lua
chat_commander.register_command("admin_only", {
    description = "Admin-only command",
    args = {
        { name = "action", type = "string" },
    },
    validate = function(schema)
        -- Ensure command is only registered in admin mode
        if not IS_ADMIN_MODE then
            return false, "cannot register admin command in non-admin mode"
        end
        return true
    end,
    pre_validate = function(ctx, args)
        -- Check admin status at execution time
        if not ctx.player.is_admin then
            return false, "player is not an admin"
        end
        return true
    end,
    handler = function(ctx, args)
        print("Admin action:", args.action)
    end,
})
```

## Key=Value Syntax

Arguments can be passed using key=value syntax:

```lua
chat_commander.register_command("move", {
    args = {
        { "x", "number" },
        { "y", "number" },
        { "z", "number" },
    },
    handler = function(ctx, args)
        print("Moving to:", args.x, args.y, args.z)
    end,
})

-- Both work the same:
chat_commander.handle_line({}, "/move 10 20 30")
chat_commander.handle_line({}, "/move x=10 y=20 z=30")
chat_commander.handle_line({}, "/move 10 y=20 z=30")  -- Mixed positional and named
```

## Notes

- Command names are case-insensitive (stored in lowercase)
- Argument names are optional and default to numerical index if not provided
- Handlers are optional (warned if missing in standard API, required in fluent API)
- Permission checks warn if no context is provided
- Enum values are case-sensitive
- Multiple types are tried in order (first match wins)
- Enum suggestions take precedence over type suggestions
- "any" type accepts any value without coercion and provides no autocompletion
- Late handler pattern is only available with standard API, not fluent API
- Fluent API requires handler to be set before calling `:register()`
- Fluent API has `pass_varargs` enabled by default (rest arguments passed as varargs to handler)
- Standard API requires `pass_varargs = true` in schema to enable varargs passing
- When `pass_varargs` is enabled, rest arguments are passed as `...` to the handler function
- Duplicate argument names are not allowed and will cause an error during registration
- Adding `?` suffix to a type string (e.g. `"number?"`) automatically marks the argument as optional
- The `suggest_at()` and `context_at()` functions have optional caret parameter (defaults to end of string)
- Custom suggestion handlers registered with `register_suggestions()` work inside string literals for arguments with
  custom types

## License

MIT License - Feel free to use in any project.
