---
description: Find and fix redundant 'or nil' code smells in Lua files
---

Scan the target directory for `*.lua` files and fix all `or nil` code smells.

Use `$ARGUMENTS` as the target directory path. If no argument is provided, scan the entire workspace.

## Patterns to find and fix

Use `rg` (ripgrep) to find these patterns in Lua code (exclude lines that are comments starting with `---` or `--`).

### Category 1: `condition and value or nil` (redundant or nil)
When `condition` is falsy, Lua short-circuits to `nil`/`false` already. When truthy and `value` is always truthy (table, string, number), `or nil` never fires.
```lua
-- BEFORE (smell: or nil is redundant)
local x = cond and {} or nil
local x = cond and "string" or nil
local x = cond and some_function() or nil

-- AFTER
local x
if cond then
    x = {}
end
```

### Category 2: `condition and true or nil` (pointless boolean normalization)
Same short-circuit redundancy, plus wrapping in `true` is pointless.
```lua
-- BEFORE (smell)
return execute(cmd) and true or nil

-- AFTER
if execute(cmd) then
    return true
end
return nil
```

### Category 3: `condition and nil or value` (inverted - and nil is dead code)
When condition is truthy: `nil or value` = `value`. When falsy: `false or value` = `value`. Always returns `value`. The `and nil` branch is unreachable.
```lua
-- BEFORE (smell: always evaluates to value)
x = cond and nil or fallback
min_bitrate = min_bitrate == math_huge and nil or min_bitrate

-- AFTER (the entire expression is just the fallback value)
x = fallback
-- OR if intent was to set nil when cond is true:
if cond then
    x = nil
else
    x = fallback
end
```

### Category 4: `condition and false or true` (always true, likely a bug)
Same as Category 3. `and false` produces falsy, then `or true` always wins. The condition is dead code.
```lua
-- BEFORE (smell/bug: always true, cond is meaningless)
x = f() and false or true

-- AFTER (preserve the conditional intent)
if f() then
    x = false
else
    x = true
end
-- OR more idiomatically:
x = not f()
```

### Category 5: `condition and nil or true` (inverted - always true, likely a bug)
Same as Category 3 but with `nil` and `true`. The expression always evaluates to `true`. The `and nil` branch is unreachable. This is almost certainly a bug - the developer probably meant `cond and true or nil` or intended a conditional.
```lua
-- BEFORE (smell/bug: always true, cond is meaningless)
x = cond and nil or true

-- AFTER (preserve the conditional intent)
if cond then
    x = nil
else
    x = true
end
```

### Category 6: `x or nil` (pointless normalization)
`x or nil` where `x` is already `nil` when not set (e.g., a table field, a function parameter) - `or nil` is a no-op.
```lua
-- BEFORE (smell)
self.field = value or nil
opts.on_iteration = opts.on_iteration or nil

-- AFTER
self.field = value
opts.on_iteration = opts.on_iteration
```

### Category 7: `tonumber(x) or nil` (redundant - tonumber already returns nil)
`tonumber()` returns `nil` on failure. `or nil` is a no-op.
```lua
-- BEFORE (smell)
address_width = tonumber(opts.address_width) or nil
local n = tonumber(input) or nil

-- AFTER
address_width = tonumber(opts.address_width)
local n = tonumber(input)
```

### Category 8: Other functions that already return nil
Same principle - if a function already returns `nil` on failure, `or nil` is redundant.
```lua
-- BEFORE (smell)
local f = io.open(path) or nil
local val = rawget(tbl, key) or nil

-- AFTER
local f = io.open(path)
local val = rawget(tbl, key)
```

## rg commands to find all occurrences

Run these from the target directory. Filter out comment lines (lines where the first non-whitespace is `--`).

```bash
# Categories 1 & 2: 'and X or nil' (excluding comments)
rg -n -g "*.lua" "\band\b .+ \bor nil\b" <dir> | rg -v "^\S+:\d+:\s*---?"

# Categories 3, 4 & 5: 'and nil or', 'and false or' (inverted patterns - bugs)
rg -n -g "*.lua" "\band (nil|false) or\b" <dir> | rg -v "^\S+:\d+:\s*---?"

# Category 6: lines ending with 'or nil' (excluding comments, doc annotations, and error strings)
rg -n -g "*.lua" "\bor nil\b" <dir> | rg -v "^\S+:\d+:\s*---" | rg -v "error\(" | rg -v "assert\("

# Category 7: 'tonumber(...) or nil'
rg -n -g "*.lua" "tonumber\(.+\) or nil" <dir> | rg -v "^\S+:\d+:\s*---?"

# Category 8: common functions followed by 'or nil'
rg -n -g "*.lua" "(io\.open|rawget|rawset|pcall|xpcall)\(.+\) or nil" <dir> | rg -v "^\S+:\d+:\s*---?"
```

## False positives to IGNORE

Do NOT fix these - they are legitimate uses:

```lua
-- Error message strings containing "or nil" as text
error("expected table or nil, got " .. type(x))

-- Assert messages
assert(type(x) == "table", "x must be table or nil")

-- tonumber on a value that could be `false` (not just nil)
-- `false or nil` = nil, but `nil or nil` = nil, so `or nil` is still redundant here

-- where the middle value of `and X or nil` COULD be falsy (false)
-- e.g., `cond and get_boolean() or nil` - if get_boolean() returns false,
-- `false or nil` = nil instead of false. This is a REAL semantic difference.
-- Only fix when the middle value is GUARANTEED truthy (table, string, nonzero number).

-- `cond and false or true` or `cond and nil or true` - these are BUGS, not just smells.
-- The expression always evaluates to the right side. These SHOULD be fixed (see Categories 3-5).
```

## Fix rules

1. **In table constructors**: Extract the expression into a local variable with an explicit `if`-statement before the table, then use the local in the table.
2. **In function bodies**: Replace the expression with an explicit `if`/`elseif`/`else` block.
3. **In return statements**: Use `if cond then return X end` followed by `return Y`.
4. **Simple assignment**: Replace `x = expr or nil` with `x = expr`.
5. **Nested `and` chains** (e.g., `r2 and r3 and "STR" or nil`): Unwrap into nested `if` statements.
6. **Inverted `and nil or value` / `and false or value`**: This is a **bug** - the expression always returns `value`. The `and nil`/`and false` branch is unreachable. Fix with an explicit `if` that preserves the developer's conditional intent.
7. Always preserve the original semantics. If unsure whether the middle value could be falsy, skip that occurrence.
8. Never add comments unless explicitly requested.
9. Verify the fix by re-running the rg search to confirm no smells remain.

## Examples

### Table constructor fix
```lua
-- BEFORE
local tag = {
    genre = genre_index and ID3V1_GENRES[genre_index] or nil,
}

-- AFTER
local genre
if genre_index then
    genre = ID3V1_GENRES[genre_index]
end

local tag = {
    genre = genre,
}
```

### Nested and-chain fix
```lua
-- BEFORE
ADD = function() return #operands == 3 and (r2 and r3 and "ADD_RR" or nil) or (#operands == 2 and "ADD_RI") end,

-- AFTER
ADD = function()
    if #operands == 3 then
        if r2 and r3 then
            return "ADD_RR"
        end
    elseif #operands == 2 then
        return "ADD_RI"
    end
end,
```

### Inverted `and nil or` fix (bug-fix too)
```lua
-- BEFORE (always returns min_bitrate - the and nil branch is unreachable)
min_bitrate = min_bitrate == math_huge and nil or min_bitrate

-- AFTER (correct intent: nil when no valid bitrate found)
if min_bitrate == math_huge then
    min_bitrate = nil
end
```

### `tonumber() or nil` fix
```lua
-- BEFORE
local address_width = tonumber(opts.address_width) or nil

-- AFTER
local address_width = tonumber(opts.address_width)
```

### `and false or true` fix (bug fix)
```lua
-- BEFORE (always evaluates to true - cond is dead code)
x = f() and false or true

-- AFTER (preserve conditional intent)
if f() then
    x = false
else
    x = true
end
-- OR more idiomatically:
x = not f()
```

### `and nil or true` fix (bug fix)
```lua
-- BEFORE (always evaluates to true - cond is dead code)
x = cond and nil or true

-- AFTER (preserve conditional intent)
if cond then
    x = nil
else
    x = true
end
```
