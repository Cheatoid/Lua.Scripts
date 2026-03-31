# Require Finder Utility

A Lua utility that uses the `lua_lexer` module to find `require("...")` expressions in Lua source code.

## Features

- **Best-effort detection**: Uses tokenization to accurately identify require expressions
- **Multiple string formats**: Supports regular strings (`"module"`), single quotes (`'module'`), and long strings (
  `[[module]]`)
- **Position tracking**: Provides line and column information for each require
- **Context analysis**: Categorizes requires as relative, absolute, or library modules
- **Multiple output formats**: Raw data, contextual information, or formatted text

## Files

- `require_finder.lua` - Main utility module
- `find_requires.lua` - Standalone command-line script
- `test_require_finder.lua` - Test script with examples
- `README.md` - This documentation

## Usage

### As a Module

```lua
local RequireFinder = require("require_finder")

-- Basic usage
local source = io.open("myfile.lua", "r"):read("*all")
local requires = RequireFinder.findRequires(source)

-- With additional context
local requiresWithContext = RequireFinder.findRequiresWithContext(source)

-- Formatted output
print(RequireFinder.formatResults(requiresWithContext))
```

### Command Line

```bash
# Navigate to the require_finder directory
cd path/to/require_finder

# Scan single file
lua find_requires.lua myfile.lua

# Scan multiple files
lua find_requires.lua file1.lua file2.lua file3.lua

# Scan files in other directories
lua find_requires.lua ../other_folder/script.lua
```

## API Reference

### RequireFinder.findRequires(source, opts)

Finds all `require("...")` expressions in the given source code.

**Parameters:**

- `source` (string) - Lua source code to scan
- `opts` (table|nil) - Options passed to the lexer

**Returns:** Array of require objects with fields:

- `expression` - The complete require expression
- `moduleName` - Clean module name (without quotes)
- `line`, `col` - Start position
- `line2`, `col2` - End position
- `startIdx`, `endIdx` - Byte positions in source

### RequireFinder.findRequiresWithContext(source, opts)

Same as `findRequires` but adds additional context:

**Additional fields:**

- `lineContent` - The complete line containing the require
- `requireType` - "relative", "absolute", or "library"
- `pathComponents` - Array of path components

### RequireFinder.formatResults(requires)

Formats require results for human-readable display.

## Examples

### Detected Patterns

The utility can detect these require patterns:

```lua
-- Regular strings
local json = require("json")
local mod = require('my.module')

-- Long strings
local path = require([[very.long.module.path]])

-- Relative paths
local utils = require(".utils")
local helper = require("..helper")

-- Absolute paths
local config = require("/config/settings")

-- With whitespace
local module = require( "my.module" )
```

### Output Example

```
Found 3 require expression(s):

1. require("json")
   Module: json
   Type: library
   Position: line 2, col 14
   Line: local json = require("json")

2. require(".utils")
   Module: .utils
   Type: relative
   Position: line 5, col 15
   Line: local utils = require(".utils")

3. require("/config/settings")
   Module: /config/settings
   Type: absolute
   Position: line 8, col 16
   Line: local config = require("/config/settings")
```

## Requirements

- Lua 5.1+ or LuaJIT
- `lua_lexer.lua` module

## License

MIT License
