-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Shorthand for printing formatted string

-- Localized global functions for better performance
local print = print
local string_format = string.format
local printf = function(...) return print(string_format(...)) end

-- Export
return printf
