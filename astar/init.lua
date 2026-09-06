-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Public entry point of the library.
--
-- In game, require is file-relative with "/":
--     local astar = require "astar/init"   -- from a script next to astar/
--
-- See README.md for a full API reference and examples.

-- Import dependencies. Require is file-relative in the game environment:
-- siblings in this folder are required by plain name (see README.md).
local core = require "astar"
local heuristics = require "heuristics"
local graph = require "graph"
local Grid2D = require "grid2d"
local Grid3D = require "grid3d"
local smoothing = require "smoothing"

core.heuristics = heuristics
core.graph = graph
core.Grid2D = Grid2D
core.Grid3D = Grid3D
core.smoothing = smoothing
core.smooth = smoothing.smooth
core.version = "1.0.0"

-- Export
return core
