-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Polyfill for io.write

local io = io or {}

if not io.write then
	local print = print
	local select = select
	local tostring = tostring
	local string_find = string.find
	local string_sub = string.sub
	local table_concat = table.concat

	-- Try to use io.stdout:write() for proper output without automatic newlines
	local stdout_write = io.stdout and io.stdout.write or false

	-- Internal buffer for io.write
	local buffer = {}

	function io.write(...)
		--local args = { ... }
		for i = 1, select("#", ...) do
			local s = tostring(select(i, ...))
			buffer[#buffer + 1] = s
		end

		-- Check for newlines and print complete lines
		while true do
			local full_text = table_concat(buffer)
			local newline_pos = string_find(full_text, "\n", 1, true)

			if newline_pos then
				-- Print everything up to and including the newline
				local to_print = string_sub(full_text, 1, newline_pos)
				if stdout_write then
					stdout_write(to_print)
				else
					-- Fallback to print() but strip the trailing newline to avoid double newlines
					local without_newline = string_sub(to_print, 1, #to_print - 1)
					print(without_newline)
				end

				-- Keep the remainder in buffer
				local remainder = string_sub(full_text, newline_pos + 1)
				-- Clear buffer
				for i = 1, #buffer do
					buffer[i] = nil
				end
				-- Put remainder back in buffer
				if #remainder > 0 then
					buffer[1] = remainder
				end
			else
				-- No newline, keep everything in buffer
				return
			end
		end
	end
end

return io
