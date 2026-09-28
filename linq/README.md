# LINQ Libraries

A collection of Lua query libraries providing fluent, chainable sequence
operations (filtering, projection, ordering, grouping, joining, set operations
and aggregates) over tables and iterables. All three files are self-contained
(no dependencies) and covered by test suites under `tests/`.

## Files

| File        | Purpose                                                                                                                                                                                                            | Status |
| ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------ |
| `linq.lua`  | Compact PascalCase API: lazy chains over tables or iterators, ordering/grouping/joining, aggregates, `ToTable`                                                                                                     | Stable |
| `linq2.lua` | Extended PascalCase API: nil-tolerant constructors, `Range`/`Repeat`/`Empty`, `TakeWhile`/`SkipWhile`, set ops, `OrderedEnumerable` with multi-key sorting, `ToList`/`ToArray`/`ToTable`/`ToDictionary`/`ToLookup` | Stable |
| `linq3.lua` | Lowercase API on lazy iterator factories: `from`/`of`/`range`/`repeatValue`/`empty`, full operator set plus `firstOrDefault`/`lastOrDefault`/`singleOrDefault`, `toLookup`, `__tostring`                           | Stable |

## Naming Convention

Method case differs per file and is part of each API - do not mix them:

- `linq.lua`: `PascalCase` (`Linq.new`, `:Where`, `:Select`, `:OrderBy`, `:ToTable`, `:ToArray` alias).
- `linq2.lua`: `PascalCase` (`Linq.new`, `Linq.Range`, `Enumerable:Where`, `:ToList`, `:ToLookup`).
- `linq3.lua`: `camelCase` (`Enumerable.from`, `:where`, `:select`, `:toTable`).

LuaLS annotation types are namespaced per file: `linq.Linq`, `linq2.Linq` /
`linq2.Enumerable` / `linq2.OrderedEnumerable`, `linq3.Enumerable` (plus
`linq3` type aliases such as `Iterator`, `IteratorFactory`, `Predicate`,
`Selector`, `KeySelector`, `Comparer`).

## Features

- Lazy evaluation: query operators build chained iterators; nothing runs until
  a materializer (`ToTable`, `ToList`, `ToArray`, `ToDictionary`, `ToLookup`,
  `Count`, `First`, ...) pulls values through the chain.
- Table or iterator sources (`linq.lua` accepts an iterator function;
  `linq3.lua` additionally wraps existing `Enumerable` instances).
- Nil-tolerant construction in `linq2.lua` (`Linq.new(nil)` and `Linq.new()`
  yield empty sequences) plus a `__call` constructor shorthand.
- Multi-key sorting via `OrderBy` / `ThenBy` (`linq.lua`, `linq2.lua`) and
  `orderBy` / `orderByDescending` (`linq3.lua`).
- Joins and grouping (`Join`, `GroupJoin`, `GroupBy`, `ToLookup`).
- Set operations (`Distinct`, `Union`, `Intersect`, `Except`).
- Aggregates (`Count`, `Sum`, `Average`, `Min`, `Max`, `Aggregate`) and
  quantifiers (`Any`, `All`, `Contains`).
- Element access with defaults (`FirstOrDefault`, `LastOrDefault`,
  `SingleOrDefault`, `ElementAtOrDefault`, `DefaultIfEmpty`).

## Installation

Each file is standalone - copy it or require it by module name:

```lua
local Linq = require "linq"    -- linq.lua
local Linq2 = require "linq2"  -- linq2.lua
local Enumerable = require "linq3" -- linq3.lua
```

## Architecture

Queries are lazy iterator chains. `linq.lua` wraps each stage in a new
`Linq` instance holding either a table or an iterator function (stored as
`_iter_fn` so it never collides with the `:_iter()` method); `ToTable`
appends (never index-assigns) so filtered iterators that preserve source keys
still materialize into dense arrays. `linq2.lua` threads a composed
`_iterator` through `Enumerable` instances, with `OrderedEnumerable`
inheriting the full method set for chained `ThenBy` sorts. `linq3.lua`
builds everything on `IteratorFactory` closures (`fun(): Iterator`), so
sequences are re-iterable and composition stays allocation-light until
materialization.

## Usage

### Quick Start (`linq.lua`)

```lua
local Linq = require "linq"

local result = Linq.From({ 1, 2, 3, 4, 5 })
    :Where(function(v) return v % 2 == 0 end)
    :Select(function(v) return v * 10 end)
    :ToTable()
-- result: { 20, 40 }
```

### Quick Start (`linq2.lua`)

```lua
local Linq = require "linq2"

local result = Linq.new({ 1, 2, 3, 4, 5 })
    :Where(function(v) return v % 2 == 0 end)
    :Select(function(v) return v * 10 end)
    :ToTable()
-- result: { 20, 40 }

local total = Linq.Range(1, 100):Sum() -- 5050
```

### Quick Start (`linq3.lua`)

```lua
local Enumerable = require "linq3"

local result = Enumerable.from({ 1, 2, 3, 4, 5 })
    :where(function(x) return x % 2 == 0 end)
    :select(function(x) return x * 10 end)
    :toTable()
-- result: { 20, 40 }

local words = Enumerable.of("b", "a", "c")
    :orderBy(function(x) return x end)
    :toTable()
-- words: { "a", "b", "c" }
```

## API Reference

### Construction

| `linq.lua`                                            | `linq2.lua`                                                                                       | `linq3.lua`                                                                                          |
| ----------------------------------------------------- | ------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| `Linq.new(src)`, `Linq.From(src)` (table or iterator) | `Linq.new(src)` (nil-safe), call shorthand `Linq(src)`, `Linq.Range`, `Linq.Repeat`, `Linq.Empty` | `Enumerable.from`, `Enumerable.of`, `Enumerable.range`, `Enumerable.repeatValue`, `Enumerable.empty` |

### Filtering and projection

| `linq.lua`                                                         | `linq2.lua`                                                                                                                         | `linq3.lua`                                                                                           |
| ------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| `Where`, `Select`, `SelectMany`, `Distinct`, `Skip`, `Take`, `Zip` | `Where`, `Select`, `SelectMany`, `Distinct`, `Take`, `Skip`, `TakeWhile`, `SkipWhile`, `Reverse`, `Concat`, `Zip`, `DefaultIfEmpty` | `where`, `select`, `selectMany`, `distinct`, `take`, `skip`, `append`, `prepend`, `concat`, `reverse` |

### Ordering, grouping, joining

| `linq.lua`                                                                                   | `linq2.lua`                                                                            | `linq3.lua`                                                                |
| -------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------- | -------------------------------------------------------------------------- |
| `OrderBy`, `OrderByDescending`, `ThenBy`, `ThenByDescending`, `GroupBy`, `Join`, `GroupJoin` | `OrderBy`, `OrderByDescending` (+ `ThenBy` via `OrderedEnumerable`), `Join`, `GroupBy` | `orderBy`, `orderByDescending`, `groupBy`, `toLookup`, `join`, `groupJoin` |

### Set operations, aggregates, element access

| `linq.lua`                                                                            | `linq2.lua`                                                                                                                                                                                                                    | `linq3.lua`                                                                                                                                                                                  |
| ------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Count`, `Sum`, `Average`, `Min`, `Max`, `Any`, `All`, `First`, `Single`, `Aggregate` | `Union`, `Intersect`, `Except`, `Count`, `Sum`, `Average`, `Max`, `Min`, `First`/`FirstOrDefault`, `Last`/`LastOrDefault`, `ElementAt`/`ElementAtOrDefault`, `Single`/`SingleOrDefault`, `Any`, `All`, `Contains`, `Aggregate` | `union`, `intersect`, `except`, `count`, `sum`, `average`, `min`, `max`, `first`/`firstOrDefault`, `last`/`lastOrDefault`, `single`/`singleOrDefault`, `contains`, `any`, `all`, `aggregate` |

### Materializers

| `linq.lua`                                   | `linq2.lua`                                                            | `linq3.lua`                                  |
| -------------------------------------------- | ---------------------------------------------------------------------- | -------------------------------------------- |
| `ToTable`, `ToArray` (alias), `ToDictionary` | `ToList`, `ToArray`, `ToTable`, `ToDictionary`, `ToLookup`, `ToString` | `toTable`, `toDictionary`, `forEach`, `iter` |

## Tests

Each module has a suite under `tests/` (`linq.lua`, `linq2.lua`, `linq3.lua`),
runnable with plain `lua` or `luajit` from the `tests/` directory (each file
bootstraps its own `package.path` and prints `All tests passed` on success).
