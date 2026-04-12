-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Standalone utility to find require("...") expressions in Lua source code
-- Uses the lua_lexer module for tokenization

-- Load the lexer (assuming it's in the standalone directory)
local Lexer = require "../standalone/lua_lexer"

local table_concat, table_insert = table.concat, table.insert

---@class RequireFinder
--- Utility class for finding require() expressions in Lua source code
local RequireFinder = {}

--- Find all require("...") expressions in Lua source code
---@param source string The Lua source code to scan
---@param opts table|nil Configuration options (passed to lexer)
---@return table array Array of found require expressions with position info
function RequireFinder.findRequires(source, opts)
	local results = {}

	-- Create lexer instance
	local lex = Lexer.new(source, opts)

	-- State machine for tracking require expressions
	local state = "seeking" -- "seeking", "found_require", "expecting_lparen", "expecting_string"
	local currentRequire = {}

	-- Iterate through tokens
	for tok in lex:tokens() do
		if state == "seeking" then
			-- Look for 'require' identifier
			if tok.type == "Identifier" and tok.value == "require" then
				state = "found_require"
				currentRequire = {
					requireToken = tok,
					line = tok.line,
					col = tok.col,
					startIdx = tok.i,
					endIdx = tok.j
				}
			end
		elseif state == "found_require" then
			-- Expect opening parenthesis after require
			if tok.type == "Punct" and tok.value == "(" then
				state = "expecting_string"
				currentRequire.lparenToken = tok
			else
				-- Reset if we don't find '('
				state = "seeking"
				currentRequire = {}
			end
		elseif state == "expecting_string" then
			-- Expect string literal (require argument)
			if tok.type == "String" or tok.type == "LongString" then
				-- Found a complete require expression
				currentRequire.stringToken = tok
				currentRequire.module = tok.value
				currentRequire.endIdx = tok.j
				currentRequire.col2 = tok.col2
				currentRequire.line2 = tok.line2

				-- Extract the raw require expression from source
				currentRequire.expression = source:sub(currentRequire.startIdx, currentRequire.endIdx)

				-- Clean up the module name (remove quotes)
				local module = currentRequire.module
				if module:sub(1, 1) == '"' or module:sub(1, 1) == "'" then
					module = module:sub(2, -2)
				elseif module:match("^%[=*%[") then
					-- Handle long strings [=[...]=] etc.
					module = module:match("^%[=*%[(.*)%]=*%]$")
				end
				currentRequire.moduleName = module

				table_insert(results, currentRequire)

				-- Reset for next search
				state = "seeking"
				currentRequire = {}
			elseif tok.type == "Whitespace" or tok.type == "Newline" or tok.type == "Comment" then
				-- Skip whitespace/comments while waiting for string
				-- do nothing, continue to next token
			else
				-- Reset if we don't find a string
				state = "seeking"
				currentRequire = {}
			end
		end
	end

	return results
end

RequireFinder.find_requires = RequireFinder.findRequires -- alias

--- Find require expressions with additional context
---@param source string The Lua source code to scan
---@param opts table|nil Configuration options
---@return table array Array of detailed require information
function RequireFinder.findRequiresWithContext(source, opts)
	local requires = RequireFinder.findRequires(source, opts)

	-- Add additional context for each require
	for i, req in ipairs(requires) do
		-- Get line content
		local lines = {}
		for line in source:gmatch("[^\r\n]+") do
			table_insert(lines, line)
		end

		if req.line <= #lines then
			req.lineContent = lines[req.line]
		end

		-- Determine require type (relative, absolute, library)
		local module = req.moduleName
		if module:match("^%.") then
			req.requireType = "relative"
		elseif module:match("^/") then
			req.requireType = "absolute"
		else
			req.requireType = "library"
		end

		-- Extract path components
		req.pathComponents = {}
		for component in module:gmatch("[^%.]+") do
			table_insert(req.pathComponents, component)
		end
	end

	return requires
end

RequireFinder.find_requires_with_context = RequireFinder.findRequiresWithContext -- alias

--- Format require results for display
---@param requires table Array of require expressions
---@return string formattedResults Formatted string output
function RequireFinder.formatResults(requires)
	if #requires == 0 then
		return "No require expressions found."
	end

	local lines = {
		string.format("Found %d require expression(s):", #requires),
		""
	}

	for i = 1, #requires do
		local req = requires[i]
		table_insert(lines, string.format("%d. %s", i, req.expression))
		table_insert(lines, string.format("   Module: %s", req.moduleName))
		table_insert(lines, string.format("   Type: %s", req.requireType or "unknown"))
		table_insert(lines, string.format("   Position: line %d, col %d", req.line, req.col))
		if req.lineContent then
			table_insert(lines, string.format("   Line: %s", req.lineContent:match("^%s*(.-)%s*$")))
		end
		table_insert(lines, "")
	end

	return table_concat(lines, "\n")
end

RequireFinder.format_results = RequireFinder.formatResults -- alias
RequireFinder.format = RequireFinder.formatResults -- alias

-- Export
return RequireFinder
