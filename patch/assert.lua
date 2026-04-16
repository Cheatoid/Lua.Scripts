-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Patch global assert function with an empty function (no-op)
-- Typically only apply this after codebase has been covered and thoroughly tested
-- This is a performance optimization to prevent the overhead of assertions in production

_G.assert = _G.assert or assert

function assert() end

_G.assert = assert
_ENV.assert = assert
return assert
