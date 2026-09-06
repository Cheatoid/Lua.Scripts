# astar - A* Pathfinding

A high-performance, modular, **engine-agnostic** A* pathfinding library in **pure Lua**,
targeting **LuaJIT** (compatible with Lua 5.1+). No FFI, no C dependencies, no engine
bindings. The host application supplies the world through small callbacks, and the core
never knows how nodes are represented.

Suitable for games, simulations, tactical/RTS AI, voxel engines, roguelikes, robotics-style
grids, waypoint graphs, navmesh-style abstractions, and general Lua applications.

```lua
local astar = require "astar/init"

local pathfinder = astar.new({
    neighbors = function(node, emit) ... end, -- or a fast buffered adapter
    heuristic = astar.heuristics.manhattan,
})

local path, info = pathfinder:find(start, goal)
if path then
    for i = 1, #path do print(path[i]) end
end
```

---

## Table of contents

1. [Installation](#installation)
2. [Quick start](#quick-start)
3. [Architecture](#architecture)
4. [API reference](#api-reference)
5. [Graph adapters & neighbor enumeration](#graph-adapters--neighbor-enumeration)
6. [Costs and weighted graphs](#costs-and-weighted-graphs)
7. [Heuristics](#heuristics)
8. [Search modes (A*, Dijkstra, Greedy)](#search-modes)
9. [Search options & budgets](#search-options--budgets)
10. [Incremental search & cancellation](#incremental-search--cancellation)
11. [Reusable search objects & memory](#reusable-search-objects--memory)
12. [Path reconstruction & post-processing](#path-reconstruction--post-processing)
13. [Grid adapters (Grid2D / Grid3D)](#grid-adapters)
14. [Determinism](#determinism)
15. [Performance notes](#performance-notes)
16. [Complexity](#complexity)
17. [Bidirectional search: why it is omitted](#bidirectional-search-why-it-is-omitted)
18. [Testing & benchmarking](#testing--benchmarking)
19. [Limitations](#limitations)

---

## Installation

The library is a single directory tree. Copy `astar/` next to your scripts.
In game, `require` is file-relative and uses `/`, so from a script sitting next
to the folder:

```lua
local astar = require "astar/init"
local graph = require "astar/graph"
local heuristics = require "astar/heuristics"
```

Inside `astar/` itself, siblings are required by plain name (`require "astar"`,
`require "open_set"`, ...), and files under `astar/tests/` use parent-relative
paths (`require "../init"` for the full library, `require "../astar"` for the
core, `require "../open_set"`, ...). Keep those strings as-is.

No build step, no FFI, no external modules. Works on LuaJIT 2.x (recommended) and
Lua 5.1; the source deliberately avoids post-5.1 syntax (no `goto`, no `//`, no
bit operators).

For standalone LuaJIT dev (running `tests/` or `benchmarks/` outside game), the
runners bootstrap `package.path` from their own location so the same file-relative
strings resolve. No manual `package.path` setup is needed.

## Quick start

### Plain graph (adjacency lists)

```lua
local astar = require "astar/init"
local graph = require "astar/graph"

-- adj[node] = array of neighbors, optional parallel cost table
local cfg = graph.from_adjacency({
    a = { "b", "c" },
    b = { "d" },
    c = { "d" },
}, {
    a = { 1, 4 },
    b = { 1 },
    c = { 1 },
})
-- nodes are strings here; positions unknown, so use Dijkstra-style search:
cfg.mode = "dijkstra"

local pf = astar.new(cfg)
local path, info = pf:find("a", "d")
-- path = { "a", "b", "d" }, info.path_cost = 2
```

When you pass a `costs` table to `from_adjacency`, every node key present in `adj`
must have a parallel array in `costs` (the core reads `costs[node][i]` directly).

### 2D grid

```lua
local astar = require "astar/init"

local grid = astar.Grid2D.new({ width = 64, height = 64, diagonal = true })
grid:block(10, 10); grid:block(10, 11)
grid:set_terrain(20, 20, 5)          -- "mud": costs 5x to enter

local pf = astar.new(grid)           -- the grid IS a valid config
local path, info = pf:find(grid:id(1, 1), grid:id(64, 64))
```

### Incremental (frame-budgeted) search

```lua
local search = pathfinder:start(start, goal)
-- in your game loop:
while not search:finished() do
    search:step(1000) -- bounded work per frame
end
local path = search:result()
```

---

## Architecture

```
astar/
    init.lua          public entry point (requires the core plus all adapters,
                      attaches heuristics/graph/Grid2D/Grid3D/smoothing/smooth/version)
    astar.lua         Pathfinder + Search: the A* engine, state, budgets,
                      statistics, iterative path reconstruction
    open_set.lua      binary min-heap with lazy deletion, parallel arrays
    heuristics.lua    built-in heuristics + factories (+ SQRT2/SQRT3 constants)
    graph.lua         adjacency-table adapters
    grid2d.lua        optimized 2D grid adapter (integer ids)
    grid3d.lua        optimized 3D voxel grid adapter (integer ids)
    smoothing.lua     optional path smoothing (string pulling + your LOS)
    tests/            test suite (95 tests: run.lua, run_one.lua, test_*.lua, util.lua)
    benchmarks/       reproducible benchmark suite (bench.lua)
    tools/            luajit.py runner shim (Python + lupa, for envs without luajit)
```

Design boundaries:

* **`astar.lua` (the core) knows nothing about grids, vectors, worlds or engines.**
  It manipulates opaque node keys, scores and a neighbor contract.
* Grid adapters, adjacency adapters and heuristics are **pluggable providers**.
* Result/statistics are plain snapshots built on demand. No result objects are
  allocated per node.

---

## API reference

### `astar.new(cfg) -> Pathfinder`

`cfg` fields:

| field              | type                                       | description                                                                                        |
| ------------------ | ------------------------------------------ | -------------------------------------------------------------------------------------------------- |
| `neighbors`        | `function(node, visitor)`                  | callback-mode neighbor enumeration; call `visitor(neighbor, cost)` per neighbor                    |
| `neighbors_buffer` | `function(node, nbuf, cbuf) -> count`      | buffered mode (fastest): fill `nbuf[i]`/`cbuf[i]` and return the count                             |
| `cost`             | `function(from, to) -> number\|nil\|false` | fallback edge cost, used when enumeration yields no cost (see [Costs](#costs-and-weighted-graphs)) |
| `heuristic`        | `function(node, goal) -> number`           | default: zero (Dijkstra-like)                                                                      |
| `walkable`         | `function(node) -> boolean`                | optional; consulted for endpoints and each node's first discovery                                  |
| `mode`             | `"astar" \| "dijkstra" \| "greedy"`        | default `"astar"`                                                                                  |
| `reopen_closed`    | boolean                                    | re-open closed nodes on improvement; needed only for admissible-but-inconsistent heuristics        |
| `stats`            | boolean (default `true`)                   | when `false`, skips optional bookkeeping (pushes/stale_pops/invalid_edges/max_open)                |

Internally `stats` maps to `collect_stats` on the Pathfinder. When disabled,
`expanded`, `discovered`, `iterations` and `cost_pruned` are still tracked;
`pushes`, `stale_pops`, `invalid_edges` and `max_open` stay at 0.

Provide **exactly one** of `neighbors` / `neighbors_buffer`. Errors (via `error()`) on
missing providers, both providers at once, invalid mode, or non-function fields.
Configuration mistakes fail fast. "No path exists" is *not* an error; it is a result.

A graph adapter object whose fields already match this contract (for example a `Grid2D`
instance, which exposes `neighbors_buffer`, `heuristic` and `walkable`) can be
passed directly: `astar.new(my_grid)`.

### Pathfinder methods

| method                         | returns           | description                                      |
| ------------------------------ | ----------------- | ------------------------------------------------ |
| `pf:find(start, goal, opts?)`  | `path\|nil, info` | one-shot search; fresh Search object per call    |
| `pf:start(start, goal, opts?)` | Search            | begin an incremental search (status `"running"`) |
| `pf:create_search()`           | Search            | create a reusable idle Search object             |

`find` allocates one Search object per call (O(1) tables, grown lazily). For repeated
searches, prefer `create_search()` + `reset()` (see [Reusable search objects](#reusable-search-objects--memory)).

### Search methods

| method                                  | description                                                  |
| --------------------------------------- | ------------------------------------------------------------ |
| `s:reset(start, goal, opts?)`           | (re)initialize; reuses all state via generation stamps       |
| `s:step(n?)`                            | perform up to `n` expansions (default 1); returns the status |
| `s:run()`                               | run to completion (bounded only by the search's own budgets) |
| `s:finished()` / `s:done()`             | `true` unless status is `"running"`                          |
| `s:result(buffer?)` / `s:path(buffer?)` | reconstruct the path (`start -> goal`); returns `path, info` |
| `s:cancel()`                            | cheap, deterministic cancellation                            |
| `s:canceled()`                          | `true` if canceled                                           |
| `s:info()`                              | snapshot of result + statistics (fresh table, safe to keep)  |
| `s:free()`                              | release all large internal tables                            |

`path(buffer)` reuses the caller's array and trims stale tail entries, so `#buffer` is
always correct afterwards. `result` is an alias of `path`. `done` is an alias of
`finished`. `reset` returns `self` so calls chain (`search:reset(a, b):run()`).
`cancel` returns `self`. `free` returns `self` and leaves the object in `"idle"`.

`step(nil)` means 1 expansion. `run()` is `step(2147483647)`. Stepping an idle,
successful, failed or canceled search is a no-op that returns the current status.

### The `info` table

```lua
info = {
    found            -- boolean
    status           -- "idle" | "running" | "success" | "failure" | "canceled"
    canceled         -- boolean
    budget_exhausted -- "iterations" | "nodes" | "cost" | "time" | nil
    endpoint_blocked -- "start" | "goal" | nil (walkable refused an endpoint)
    path_cost        -- number | nil
    path_length      -- number | nil
    expanded         -- nodes expanded (closed after pop)
    discovered       -- unique nodes that entered the open set
    pushes           -- heap pushes (includes re-pushes; 0 when stats disabled)
    stale_pops       -- discarded stale heap entries (0 when stats disabled)
    invalid_edges    -- edges rejected for invalid cost (0 when stats disabled)
    cost_pruned      -- edges skipped by max_cost (always counted)
    max_open         -- peak open-set size (0 when stats disabled)
    iterations       -- engine cycles = heap pops (valid + stale)
}
```

`expanded`, `discovered`, `cost_pruned` and `iterations` are always tracked (the first
three drive budgets except `cost_pruned`, which is diagnostic); the rest can be
disabled with `stats = false` for a leaner hot path.

Useful invariant (with stats enabled, successful search):
`iterations == expanded + 1 + stale_pops`.

### `astar.heuristics`

Coordinate-table heuristics (nodes with `.x`/`.y`/`.z` fields):
`zero`, `manhattan`, `euclidean`, `euclidean_squared`, `chebyshev`, `octile`,
`manhattan3`, `euclidean3`, `chebyshev3`, `constant(c)`.

Grid-id factories (row-major integer ids): `grid_manhattan(width)`,
`grid_octile(width)`, `grid_euclidean(width)`.

Constants: `heuristics.SQRT2`, `heuristics.SQRT3`.

### Other exports

* `astar.Grid2D`, `astar.Grid3D` - grid adapters (see below)
* `astar.graph.from_adjacency(adj, costs?)` - returns a `neighbors_buffer` config.
  When `costs` is given it must provide a parallel array per node in `adj`.
* `astar.graph.from_weighted_adjacency(adj)` - expects
  `adj[node] = { { node = n, cost = c }, ... }`; returns a config.
* `astar.graph.from_edges(edges, symmetric?)` - builds adjacency plus costs from
  `edges = { {a, b, cost?}, ... }` (cost defaults to 1). When `symmetric` is
  truthy each edge is mirrored; when nil/false the graph is directed. Returns
  `cfg, adj, costs` so tests can inspect or mutate the tables.
* `astar.smooth(line_of_sight, path, out?)` / `astar.smoothing.smooth` - path smoothing
* `astar.version` (currently `"1.0.0"`)
* `open_set` is not attached to the public table; `require "astar/open_set"`
  (game, next to the folder) or `require "../open_set"` (from `tests/`)
  loads the heap directly (used by the test suite).

---

## Graph adapters & neighbor enumeration

The neighbor interface is the hottest boundary in the library, so two modes are
supported:

### Buffered mode (recommended for hot paths)

```lua
neighbors_buffer = function(node, nbuf, cbuf)
    -- fill nbuf[i] = neighbor, cbuf[i] = cost (or 0/nil to defer to cost())
    -- return the number of neighbors
end
```

* **Zero allocations per expansion**: the Search object owns both buffers and reuses
  them for every node of every search.
* No closures, no varargs, straight integer-indexed table writes. Ideal for
  LuaJIT traces.
* Entries beyond the returned count are never read; adapters may leave garbage there.
* The adapter **must return the count**. A missing return surfaces as an error in
  the core loop (`for i = 1, count` with nil `count` fails), so contract
  violations fail fast instead of silently producing wrong paths.

### Callback mode (convenient, still allocation-free)

```lua
neighbors = function(node, emit)
    emit(neighbor_a, 1.0)
    emit(neighbor_b) -- cost deferred to cost(from, to)
end
```

* The `emit` visitor **is the Search object itself** (`__call`), so no closure is
  created per node or per search. The core never allocates to enumerate.
* Per-neighbor cost: pass it to `emit(neighbor, cost)`; if omitted (or `0`),
  the core calls `cfg.cost(from, neighbor)`.

Callback mode pays one dynamic call per neighbor; buffered mode pays one table
store. Both are LuaJIT-friendly; the benchmark suite shows the gap is small but
measurable. Use buffered mode for grids/graphs you traverse heavily, callback mode
for everything else.

### Writing your own adapter

An adapter is just a config table (or an object with those fields):

```lua
local pf = astar.new({
    neighbors_buffer = function(node, nbuf, cbuf) ... end,
    heuristic = function(a, b) ... end,
    walkable = function(node) ... end, -- optional
})
```

Node ids may be **any valid Lua table key except nil and NaN**: integers, strings,
tables (by identity), booleans. The core never interprets them.

---

## Costs and weighted graphs

Edge costs are arbitrary positive numbers; the algorithm never assumes cost 1:

```text
grass = 1    road = 0.5    mud = 3    water = 8
```

Cost resolution order per neighbor:

1. If enumeration supplied a cost (`emit(n, c)` or `cbuf[i]`), use it.
2. If it supplied `nil` or `0` (sentinel), call `cfg.cost(from, to)` if present.
3. If there is still no usable cost, the edge is ignored.

**Invalid costs are validated, not silently misused.** The policy:

* `nil` / `false` after fallback: edge absent (skipped, not counted).
* Any number `<= 0`, or `NaN`: edge **rejected** and counted in
  `info.invalid_edges` (when stats are enabled). Zero-cost cycles would break
  termination, so non-positive costs are treated as invalid rather than "free".
  Note `0` without a `cost` fallback stays `0` and is counted as invalid.
* A non-number cost (for example a table) raises an error on purpose.
  Misconfiguration should fail loudly.

This means negative edge weights are never "supported". They are rejected, keeping
termination and correctness guarantees intact.

---

## Heuristics

`h(node, goal) -> number`. The core is representation-agnostic, so choose a heuristic
that matches your node representation (factories are provided for integer grids).

What the terms mean and how they affect behavior:

* **Admissible**: `h(n) <= true remaining cost`. Guarantees A* returns an *optimal*
  path (with positive edge costs).
* **Consistent (monotone)**: `h(n) <= cost(n, m) + h(m)` for every edge. Guarantees
  that the first time a node is popped, its g-score is final. The core then never
  re-opens closed nodes (its default, fastest mode). Every consistent heuristic is
  admissible.
* **Admissible but inconsistent**: optimality requires re-opening closed nodes;
  enable `reopen_closed = true`.
* **Non-admissible** (`euclidean_squared`, `constant(c)`, Greedy mode): faster
  exploration, *no optimality guarantee*; the returned path is still valid and its
  true cost is reported.

Built-in grid heuristics (manhattan/octile/euclidean against their grid cost models)
are admissible and consistent for edge costs >= 1. If your terrain costs can go
below 1, scale your heuristic accordingly or accept suboptimality.

Tips:

* 4-connected grid: manhattan; 8-connected with `sqrt(2)` diagonals: octile;
  free-direction movement: euclidean; 6-connected 3D: manhattan3; 26-connected 3D
  with euclidean step costs: euclidean3.
* Tighter heuristic = fewer expansions. `zero` = Dijkstra (explores uniformly).
* `mode = "dijkstra"` skips the heuristic call entirely. Do not pass `zero`
  manually if you want that last bit of performance.

---

## Search modes

| mode                | f =     | optimal?                           | notes                                                                                   |
| ------------------- | ------- | ---------------------------------- | --------------------------------------------------------------------------------------- |
| `"astar"` (default) | `g + h` | yes, if h is admissible/consistent | standard A*                                                                             |
| `"dijkstra"`        | `g`     | yes                                | h call skipped entirely; uniform exploration                                            |
| `"greedy"`          | `h`     | **no**                             | g still tracked (path cost reporting + `max_cost` still work); very fast when h is good |

All three share one engine; nothing is duplicated. In Greedy mode the goal test
still happens on pop (optimal termination point for A*), while `early_exit`
terminates on first discovery instead.

---

## Search options & budgets

Per-search options (third argument of `find`/`start`/`reset`):

| option           | meaning                                                                                                                                                                                   |
| ---------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `max_iterations` | hard cap on engine cycles (heap pops, valid or stale). Deterministic. `0` = no work allowed.                                                                                              |
| `max_nodes`      | cap on unique discovered nodes                                                                                                                                                            |
| `max_cost`       | cost-limited search: neighbors whose tentative g exceeds it are pruned (a cheaper route may still discover them later). On exhaustion, `budget_exhausted = "cost"` if anything was pruned |
| `budget_seconds` | **opt-in** wall-clock budget (`os.clock`), checked every 256 expansions to keep the clock out of the hot path                                                                             |
| `early_exit`     | stop at the first *discovery* of the goal. Faster, **not optimal** (reports the best path found so far)                                                                                   |

Budgets compose with incremental stepping: `max_iterations` counts across all
`step()` calls of the same search, and per-call pause (`step(n)`) is separate from
budget exhaustion (which finishes the search with status `"failure"` plus
`budget_exhausted` set).

The library **never** consults wall-clock time unless you pass `budget_seconds`;
default behavior is fully deterministic.

---

## Incremental search & cancellation

```lua
local search = pathfinder:start(start, goal)

while not search:finished() do
    search:step(500)          -- bounded work per frame
end

local path, info = search:result()
```

Guarantees:

* **Incremental is identical to one-shot.** Both drive the exact same engine function, and the
  engine pauses only at expansion boundaries (never mid-neighbor-scan). The test
  suite verifies bit-identical paths, costs and counters for step sizes 1, 2, 3, 7
  and 1000 against one-shot runs.
* `search:cancel()` flips the status to `"canceled"` in O(1). Subsequent
  `step()`/`run()` calls are no-ops. The object remains inspectable (`info()`),
  reusable (`reset()`) and releasable (`free()`).
* `search:finished()` is `false` only while status is `"running"`; a fresh idle
  search counts as finished (you cannot step it before `reset`).

---

## Reusable search objects & memory

```lua
local search = pathfinder:create_search()

-- later, many times:
search:reset(start, goal)
search:run()
local path = search:path()
```

* State lives in **flat tables keyed by node** (`g`, `h`, `parent`, `stamps`). They are
  **never cleared between searches**: a generation stamp encoded in `stamps[node]`
  marks entries from older searches as stale, so a new search simply ignores and
  overwrites them. No O(V) clearing, no rehashing from empty. Tables keep their
  high-water capacity.
* `reset()` is cheap: O(1) plus endpoint validation. It also clears stale budget
  options, so an omitted option never inherits the previous search cap.
* `free()` releases everything (fresh tables, heap slots nil-ed) when you want the
  memory back. It leaves the object in `"idle"` and the object stays usable.
* `pf:find()` is a convenience that creates a fresh Search per call. Use it for
  occasional queries; the pooled style above avoids re-growing tables on large
  graphs (the benchmark suite shows a measurable win and much less GC churn).
* Generation overflow is handled: at 2^50 searches the stamp table is replaced once
  and the counter restarts (exercised by a test by poking the internal counter).

---

## Path reconstruction & post-processing

* Reconstruction is **iterative** (no recursion): follow parents goal to start into an
  array, then reverse in place. Deep paths (tens of thousands of nodes, see the
  serpentine benchmark: a 12,880-node path) are safe and fast.
* `search:path(buffer)` reuses your table and trims stale tail slots, so a pooled
  buffer across searches never leaks old entries or lies about `#`.
* The result is ordered `start -> ... -> goal`; `info.path_cost` is the exact
  g-score of the goal. `info.path_length` is the node count.

### Optional smoothing (`smoothing.lua`)

```lua
local astar = require "astar/init"

local function line_of_sight(a, b)
    -- your engine's raycast/grid walk; must be deterministic
end

local straight = astar.smooth(line_of_sight, path, out_buffer?)
```

Greedy string-pulling: repeatedly jumps to the farthest visible node. Deliberately
separate from the core. The core knows nothing about geometry, and you supply
your own LOS predicate (grid raymarch, navmesh test, physics raycast...).
Worst case O(n^2) LOS calls; deterministic scan order. Only removes nodes, so the
output stays valid; `out` reuse trims the tail like `path(buffer)` does.

---

## Grid adapters

### Grid2D

```lua
local grid = astar.Grid2D.new({
    width = 64, height = 64,
    diagonal = false,             -- 8-connectivity when true
    allow_corner_cutting = false, -- diagonals require both orthogonal cells
    blocked = {},                 -- [id] = true
    terrain = {},                 -- [id] = cost multiplier (<= 0 = impassable)
})
```

* Node ids are row-major integers, 1-based: `id = x + width * (y - 1)`.
  `grid:id(x, y)` / `grid:coords(id)` convert. **No coordinate tables are created in
  the hot path**. Neighbor ids are computed with integer arithmetic from one
  `(x, y)` decode per expansion.
* Cost model: straight move = `terrain[dest] or 1`; diagonal = `sqrt(2) * terrain[dest]`.
* Default heuristic matches connectivity: manhattan (4-conn) / octile (8-conn).
  Both are admissible and consistent for terrain >= 1.
* The instance doubles as an `astar.new()` config: `astar.new(grid)`.
* Helpers: `grid:in_bounds(x, y)`, `grid:block(x, y)`, `grid:unblock(x, y)`,
  `grid:set_terrain(x, y, cost)`, `grid:terrain_at(x, y)` (nil when unset, 1 in
  the neighbor loop), `grid:passable(id)`, `grid:coords(id)`, `grid:id(x, y)`.
* `Grid2D.make_heuristic(width, diagonal)` builds the same default heuristic for
  custom grid implementations (manhattan when false, octile when true).
* `grid:validate_path(path)` (debug helper) checks adjacency, blocked cells and
  corner-cutting rules. Returns `true` or `false, err`.

### Grid3D

```lua
local grid = astar.Grid3D.new({
    width = 16, height = 16, depth = 16,
    diagonal = false, -- 26-connectivity when true
    blocked = {},     -- [id] = true
    terrain = {},     -- [id] = cost multiplier (<= 0 = impassable)
})
-- id = x + width * (y - 1) + width * height * (z - 1)
```

* 6-conn: manhattan heuristic, unit face moves. 26-conn: euclidean heuristic,
  step costs = euclidean lengths (`1`, `sqrt(2)`, `sqrt(3)`). These are consistent pairs.
* Uses a precomputed direction table (6 or 26 entries) instead of full unrolling;
  `Grid2D` is the fully unrolled planar hot path.
* Helpers: `grid:id(x, y, z)`, `grid:coords(id)`, `grid:in_bounds(x, y, z)`,
  `grid:block(x, y, z)`, `grid:unblock(x, y, z)`,
  `grid:set_terrain(x, y, z, cost)`, `grid:passable(id)`, plus `heuristic` and
  `walkable` bound to the instance. There is no `validate_path` on Grid3D and no
  `allow_corner_cutting` option: 26-conn moves are admitted on bounds and
  destination passability only.

---

## Determinism

Given identical graph data, identical callback results and identical configuration,
searches are bit-for-bit reproducible:

* The open set orders entries by `(f, h, seq)` where `seq` is a monotonic insertion
  counter. Equal-score nodes pop in discovery order.
* The core never iterates with `pairs` and never relies on Lua hash order.
  The engine loop uses indexed `for i = 1, count` scans only.
* Neighbor visit order is whatever your adapter does. Keep it deterministic and the
  whole search is deterministic. (For grids it is a fixed direction order:
  left/right/up/down then diagonals in Grid2D; dz/dy/dx table order in Grid3D.)
* `os.time`, `math.random` and wall clocks are never consulted internally.
  `budget_seconds` is opt-in and only affects *when* the search stops, not which
  path it would find under deterministic budgets. With `budget_seconds` the
  stop point is intentionally time-based; use deterministic budgets when
  reproducibility matters.

---

## Performance notes

Chosen structures and why (all measured in `benchmarks/bench.lua`):

* **Binary min-heap with lazy deletion** instead of decrease-key. Decrease-key needs
  a node-to-heap-index map and sift-up/down on every improvement; lazy deletion just
  pushes a duplicate and discards stale entries on pop (a single stamp compare).
  With consistent heuristics duplicates are rare, so lazy deletion wins in practice
  and is far harder to get wrong. Stale entries can never corrupt correctness:
  the authoritative scores live in the state tables, and an entry is honored only
  if its node is open *in the current generation*.
* **Four parallel arrays** for the heap (`node/f/h/seq`) instead of entry tables:
  no per-push allocation, array-part access, trace-friendly sift loops
  (hole technique: 4 stores per level, not 8).
* **Flat node-keyed state tables** (`g`, `h`, `parent`, `stamps`) instead of per-node
  objects: zero allocation per discovered node; array-part speed for integer ids.
* **Generation stamps** (`stamps[node] == gen4 + state`) replace table clearing
  between searches: no O(V) clears, retained table capacity, no rehash storms.
* **Buffered neighbor enumeration** with search-owned buffers: zero allocations and
  zero closures per expansion; the callback-mode visitor is the search object
  itself (`__call`), so even the convenient path allocates nothing.
* **Localized globals/fields** in the engine loop (`open`, `stamps`, `g`, `parent`,
  heap arrays, callbacks) so LuaJIT keeps them in registers/upvalues across traces.
* **No `pairs`/`ipairs`/`table.insert`/`table.remove`/recursion** anywhere in the
  engine; no string building; no varargs.
* Mode branches (`astar`/`dijkstra`/`greedy`) are monomorphic per search and
  predictable; Dijkstra skips heuristic calls entirely (it nils the heuristic at
  construction, so a misbehaving heuristic is never called).

Measured behavior (from `benchmarks/bench.lua --quick` on this machine; run it
yourself for your hardware):

* 64x64 grid, 20% walls, manhattan: about 134 expansions per found path, about 0.25 ms/search.
* Reused Search objects beat fresh `find()` clearly on repeated queries with far
  less GC churn (example from section 4: about 140 us/search reused against about
  215 us/search fresh).
* Incremental stepping costs about nothing against one-shot (identical results,
  identical per-search time in section 5).
* Dijkstra/greedy on unreachable goals correctly exhaust the map. Budgets are the
  tool if that matters to you.

---

## Complexity

With V = nodes touched, E = edges scanned:

* **Time**: `O((V + E) log V)` for the binary-heap formulation. Each heap operation
  is `O(log heapsize)`, and heapsize is bounded by V. Lazy deletion adds at most one extra
  `O(log V)` pop per edge relaxation, absorbed by the same bound.
* **Memory**: `O(V)` for scores/parents/stamps plus `O(open-set size)` for the heap
  (bounded by V entries, plus stale duplicates bounded by E). Per *search*, table allocation
  is `O(1)` (tables grow lazily and are reused across searches of the same object).
* These are the bounds the implementation actually exhibits; no stronger guarantee
  (for example Fibonacci-heap `O(E + V log V)`) is claimed.

---

## Bidirectional search: why it is omitted

Bidirectional A* was evaluated and deliberately **not** implemented:

1. **The generic adapter contract has no reverse edges.** Bidirectional search needs
    to expand the goal backwards (`neighbors_inverse`), which every adapter would
    have to supply; for directed graphs it is *different data*, not a mirror.
2. **Correct termination is subtle.** With weighted edges and heuristics, naive
    "stop when frontiers meet" is wrong; correct criteria (for example the
    `top_F + top_B <= best_meeting_cost` condition) require careful coordination of
    two open sets, two g-spaces and a meeting-point bookkeeping that doubles the
    state machine.
3. **Heuristic assumptions differ**. The reverse search needs h(s, x)-style
    symmetric estimates, which arbitrary user heuristics do not guarantee.

For the common cases (symmetric grids, unit or terrain costs), forward A* with a
good heuristic already performs well, and Dijkstra covers the rest. If your domain
really needs it (huge open spaces, exact-uniform costs), a specialized
implementation with a symmetric adapter will beat a generic one anyway. Adding a
half-correct generic version would violate the library's correctness-first contract.

---

## Testing & benchmarking

```sh
# from the astar/ directory, with a standalone LuaJIT:
luajit tests/run.lua
luajit benchmarks/bench.lua # full
luajit benchmarks/bench.lua --quick

# per-file test runs (debugging aid):
luajit tests/run_one.lua test_grid
```

The runners bootstrap `package.path` from their own location, so no manual setup
is needed. Inside the suite all requires stay file-relative with `/`:
`require "../init"` (full library), `require "../astar"` (core),
`require "../open_set"`, `require "../graph"`, `require "../heuristics"`.
Library files keep plain sibling names (`require "astar"`, `require "open_set"`).

`tools/luajit.py` is a convenience runner for environments that lack a `luajit`
binary but have Python plus `lupa` (embedded LuaJIT 2.1); the library itself has no
dependency on it.

The suite (95 tests) covers: basic cases (start==goal, direct/blocked/unreachable,
single-node, empty graph), weighted correctness against hand-computed optima,
cross-heuristic cost agreement, callback-against-buffer equivalence, determinism of
tie-breaking, grids (4/8-conn, terrain, corner cutting, 3D 6/26-conn), incremental
against one-shot equality (step sizes 1, 2, 3, 7, 1000), budgets
(iterations/nodes/cost/time), cancellation, search
reuse across generations (including the generation-overflow path), invalid costs
(negative/zero/NaN), and 14 documented regression tests.

Every bug found during development became a regression test; each one cites its
failure mode in `tests/test_regression.lua`.

---

## Limitations

* Nodes must be valid table keys (not `nil`, not `NaN`). Identity equality (`==`)
  is used for the start check. Tables compare by identity, as expected.
* Heuristics returning `nil` are treated as `0`; returning garbage types will error
  (fail fast). Negative heuristics are user error (documented, unchecked for speed).
* No dynamic edge *insertion during* a search (adapters may compute neighbors
  lazily, but mutating the graph mid-search makes results undefined for that
  search. The next search is unaffected).
* Bidirectional search and jump-point-search are out of scope (see above; JPS also
  requires grid-specific assumptions the core deliberately lacks).
* The built-in grid adapters use per-destination terrain costs with fixed diagonal
  multipliers; exotic movement models (asymmetric diagonals, per-direction costs)
  belong in a custom adapter.
* Grid3D has no corner-cutting rule; Grid2D is the only adapter with
  `allow_corner_cutting`.

---

## License

MIT. Written as a compact, embeddable foundation library. Copy it into your
project and go.
