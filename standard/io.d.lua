-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

---@meta

---@class iolib
local io = {}

--- Write values to output buffer.<br>
--- Appends all arguments to the internal buffer and flushes when encountering newline.<br>
--- Respects "print on same line" behavior by only flushing/printing on `\n`.
---@param ... any Values to write.
---@usage <br>
--- ```
--- io.write("Hello", " ", "world") -- prints "Hello world"
--- io.write("Line 1\n") -- prints "Line 1" with newline
--- io.write("No newline yet") -- buffered, not printed yet
--- io.write("\n") -- prints "No newline yet\n"
--- ```
function io.write(...)
end

return io
