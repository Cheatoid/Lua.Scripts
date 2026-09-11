-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Custom key-value config (.cfg) file parser
-- Supports:
-- * Key-value pairs: "key" "value"
-- * Nested blocks: "blockname" { ... }
-- * Comments: // line comments and /* block comments */
-- * Quoted strings with escape sequences
-- * Whitespace handling

-- Localized global functions for better performance
local next = next
local tonumber = tonumber
local tostring = tostring
local type = type
local string_find = string.find
local string_gsub = string.gsub
local string_lower = string.lower
local string_sub = string.sub
local table_concat = table.concat
local table_remove = table.remove

local function Ok(value)
	return { ok = true, value = value }
end

local function Err(message)
	return { ok = false, error = message }
end

local function string_substring(self, startIndex, endIndex)
	if endIndex ~= endIndex then
		endIndex = 0
	end
	if endIndex ~= nil and startIndex > endIndex then
		startIndex, endIndex = endIndex, startIndex
	end
	if startIndex >= 0 then
		startIndex = startIndex + 1
	else
		startIndex = 1
	end
	if endIndex ~= nil and endIndex < 0 then
		endIndex = 0
	end
	return string_sub(self, startIndex, endIndex)
end

local function string_split(source, separator, limit)
	if limit == nil then
		limit = 4294967295
	end
	if limit == 0 then
		return {}
	end
	local result = {}
	local resultIndex = 1
	if separator == nil or separator == "" then
		for i = 1, #source do
			result[resultIndex] = string_sub(source, i, i)
			resultIndex = resultIndex + 1
		end
	else
		local currentPos = 1
		while resultIndex <= limit do
			local startPos, endPos = string_find(source, separator, currentPos, true)
			if not startPos then
				break
			end
			result[resultIndex] = string_sub(source, currentPos, startPos - 1)
			resultIndex = resultIndex + 1
			currentPos = endPos + 1
		end
		if resultIndex <= limit then
			result[resultIndex] = string_sub(source, currentPos)
		end
	end
	return result
end

local function string_get_char(self, pos)
	if pos ~= pos then
		pos = 0
	end
	if pos < 1 then
		return ""
	end
	return string_sub(self, pos, pos)
end

local function to_number(value)
	local valueType = type(value)
	if valueType == "number" then
		return value
	end
	if valueType == "string" then
		local numberValue = tonumber(value)
		if numberValue then
			return numberValue
		end
		if value == "inf" then
			return math.huge
		end
		if value == "-inf" then
			return -math.huge
		end
		if (string_gsub(value, "%s", "")) == "" then
			return 0
		end
		return 0 / 0
	end
	if valueType == "boolean" then
		return value and 1 or 0
	end
	return 0 / 0
end

local function number_is_nan(value)
	return value ~= value
end

local function string_trim(self)
	-- \xc2\xa0 - Non-breaking space (U+00A0)
	-- \xef\xbb\xbf - Zero-width non-breaking space / BOM (U+FEFF)
	return (string_gsub(self, "^[%s\xc2\xa0\xef\xbb\xbf]*(.-)[%s\xc2\xa0\xef\xbb\xbf]*$", "%1"))
end

local M = {}

local function parse(content)
	if not content or #content == 0 then
		return Ok { entries = {} }
	end
	-- Remove UTF-8 BOM
	if #content >= 3 and string_substring(content, 0, 3) == "\xef\xbb\xbf" then
		content = string_substring(content, 3)
	end
	if not content or #content == 0 then
		return Ok { entries = {} }
	end
	local normalizedInput = table_concat(
		string_split(content, "\r"),
		""
	)
	local entries = {}
	local position = 1
	local inputLength = #normalizedInput
	local lineNumber = 1
	local columnNumber = 1
	local isInsideBlockComment = false
	local blockNestingStack = {}
	local activeEntryList = entries
	local function captureWhitespace()
		local startPosition = position
		local whitespace = ""
		while position <= inputLength do
			local currentChar = string_get_char(normalizedInput, position)
			-- Only capture spaces and tabs, NOT newlines (newlines are delimiters)
			if currentChar ~= " " and currentChar ~= "\t" then
				break
			end
			whitespace = whitespace .. currentChar
			position = position + 1
			columnNumber = columnNumber + 1
		end
		return whitespace
	end
	local function skipWhitespace()
		while position <= inputLength do
			local currentChar = string_get_char(normalizedInput, position)
			if currentChar ~= " " and currentChar ~= "\t" then
				break
			end
			position = position + 1
			columnNumber = columnNumber + 1
		end
	end
	local function parseString()
		if position > inputLength or string_get_char(normalizedInput, position) ~= "\"" then
			return Err((("Expected opening quote at line " .. tostring(lineNumber)) .. ", column ") ..
				tostring(columnNumber))
		end
		local startPosition = position
		position = position + 1
		columnNumber = columnNumber + 1
		local stringResult = ""
		local isEscaped = false
		while position <= inputLength do
			do
				local currentChar = string_get_char(normalizedInput, position)
				if isEscaped then
					repeat
						local escapeChar = currentChar
						local isMatchedEscape = escapeChar == "n"
						if isMatchedEscape then
							stringResult = stringResult .. "\n"
							break
						end
						isMatchedEscape = isMatchedEscape or escapeChar == "t"
						if isMatchedEscape then
							stringResult = stringResult .. "\t"
							break
						end
						isMatchedEscape = isMatchedEscape or escapeChar == "r"
						if isMatchedEscape then
							stringResult = stringResult .. "\r"
							break
						end
						isMatchedEscape = isMatchedEscape or (escapeChar == "\\" or escapeChar == "\"")
						if isMatchedEscape then
							stringResult = stringResult .. currentChar
							break
						end
						do
							stringResult = stringResult .. "\\" .. currentChar
							break
						end
					until true
					isEscaped = false
					position = position + 1
					columnNumber = columnNumber + 1
					goto __continue11
				end
				if currentChar == "\\" then
					isEscaped = true
					position = position + 1
					columnNumber = columnNumber + 1
					goto __continue11
				end
				if currentChar == "\"" then
					position = position + 1
					columnNumber = columnNumber + 1
					return Ok(stringResult)
				end
				if currentChar == "\n" then
					return Err((("Unterminated string starting at line " .. tostring(lineNumber)) .. ", column ") ..
						tostring(startPosition - columnNumber + #stringResult + 2))
				end
				stringResult = stringResult .. currentChar
				position = position + 1
				columnNumber = columnNumber + 1
			end
			::__continue11::
		end
		return Err((("Unterminated string starting at line " .. tostring(lineNumber)) .. ", column ") ..
			tostring(startPosition - columnNumber + #stringResult + 2))
	end
	local function parseCommand()
		local startPosition = position
		local commandResult = ""
		if position <= inputLength and string_get_char(normalizedInput, position) == "\"" then
			return parseString()
		end
		while position <= inputLength do
			local currentChar = string_get_char(normalizedInput, position)
			if currentChar == " " or currentChar == "\t" or currentChar == "\n" or currentChar == ";" then
				break
			end
			commandResult = commandResult .. currentChar
			position = position + 1
			columnNumber = columnNumber + 1
		end
		if #commandResult == 0 then
			return Err((("Expected command at line " .. tostring(lineNumber)) .. ", column ") .. tostring(startPosition))
		end
		return Ok(commandResult)
	end
	local function parseNumber()
		local startPosition = position
		local numberBuffer = ""
		local hasDecimalPoint = false
		if position <= inputLength and string_get_char(normalizedInput, position) == "-" then
			numberBuffer = numberBuffer .. "-"
			position = position + 1
			columnNumber = columnNumber + 1
		end
		local hasDigitChars = false
		while position <= inputLength do
			local currentChar = string_get_char(normalizedInput, position)
			if currentChar >= "0" and currentChar <= "9" then
				numberBuffer = numberBuffer .. currentChar
				hasDigitChars = true
				position = position + 1
				columnNumber = columnNumber + 1
			elseif currentChar == "." and not hasDecimalPoint then
				numberBuffer = numberBuffer .. currentChar
				hasDecimalPoint = true
				position = position + 1
				columnNumber = columnNumber + 1
			else
				break
			end
		end
		if not hasDigitChars or numberBuffer == "-" or numberBuffer == "." then
			return Err((("Invalid number format at line " .. tostring(lineNumber)) .. ", column ") ..
				tostring(startPosition))
		end
		local parsedNumber = to_number(numberBuffer)
		if number_is_nan(to_number(parsedNumber)) then
			return Err((("Failed to parse number at line " .. tostring(lineNumber)) .. ", column ") ..
				tostring(startPosition))
		end
		return Ok(parsedNumber)
	end
	local function parseArgument()
		local startPosition = position
		if position <= inputLength and string_get_char(normalizedInput, position) == "\"" then
			return parseString()
		end
		local currentChar = string_get_char(normalizedInput, position)
		if currentChar >= "0" and currentChar <= "9" or currentChar == "-" or currentChar == "." then
			local originalPosition = position
			local originalColumnNumber = columnNumber
			local numberParseResult = parseNumber()
			if numberParseResult.ok then
				if position > inputLength or string_get_char(normalizedInput, position) == " " or string_get_char(normalizedInput, position) == "\t" or string_get_char(normalizedInput, position) == "\n" or string_get_char(normalizedInput, position) == ";" or string_get_char(normalizedInput, position) == "}" then
					return numberParseResult
				end
			end
			position = originalPosition
			columnNumber = originalColumnNumber
		end
		local argumentResult = ""
		while position <= inputLength do
			local currentChar = string_get_char(normalizedInput, position)
			if currentChar == " " or currentChar == "\t" or currentChar == "\n" or currentChar == ";" or currentChar == "}" then
				break
			end
			argumentResult = argumentResult .. currentChar
			position = position + 1
			columnNumber = columnNumber + 1
		end
		if #argumentResult == 0 then
			return Err((("Expected argument at line " .. tostring(lineNumber)) .. ", column ") .. tostring(startPosition))
		end
		return Ok(argumentResult)
	end
	local function skipToNextCommand()
		while position <= inputLength do
			local currentChar = string_get_char(normalizedInput, position)
			if currentChar == "\n" or currentChar == ";" then
				break
			end
			position = position + 1
			columnNumber = columnNumber + 1
		end
		if position <= inputLength then
			local currentChar = string_get_char(normalizedInput, position)
			if currentChar == "\n" then
				lineNumber = lineNumber + 1
				columnNumber = 1
			elseif currentChar == ";" then
				columnNumber = columnNumber + 1
			end
			position = position + 1
		end
	end
	while position <= inputLength do
		do
			local leadingWhitespace = captureWhitespace()
			if position > inputLength then
				break
			end
			local currentChar
			if position <= inputLength then
				currentChar = string_get_char(normalizedInput, position)
			else
				goto __continue44
			end
			if currentChar == "\n" then
				lineNumber = lineNumber + 1
				columnNumber = 1
				position = position + 1
				goto __continue44
			end
			if currentChar == ";" then
				position = position + 1
				columnNumber = columnNumber + 1
				goto __continue44
			end
			if isInsideBlockComment then
				local blockCommentEnd = (string_find(
					normalizedInput,
					"*/",
					math.max(position + 1, 1),
					true
				) or 0) - 1
				if blockCommentEnd then
					do
						local index = position
						while index < blockCommentEnd do
							local checkChar = string_get_char(normalizedInput, index)
							if checkChar == "\n" then
								lineNumber = lineNumber + 1
								columnNumber = 1
							else
								columnNumber = columnNumber + 1
							end
							index = index + 1
						end
					end
					isInsideBlockComment = false
					position = blockCommentEnd + 2
					columnNumber = columnNumber + 2
				else
					break
				end
				goto __continue44
			end
			if currentChar == "}" then
				if #blockNestingStack == 0 then
					return Err((("Unexpected closing brace '}' at line " .. tostring(lineNumber)) .. ", column ") ..
						tostring(columnNumber))
				end
				position = position + 1
				columnNumber = columnNumber + 1
				local completedBlock = table_remove(blockNestingStack)
				if #blockNestingStack > 0 then
					local parentBlock = blockNestingStack[#blockNestingStack]
					local parentBlockEntries = parentBlock.entries
					parentBlockEntries[#parentBlockEntries + 1] = completedBlock
					activeEntryList = parentBlock.entries
				else
					entries[#entries + 1] = completedBlock
					activeEntryList = entries
				end
				goto __continue44
			end
			if currentChar == "/" and position + 1 <= inputLength and string_get_char(normalizedInput, position + 1) == "/" then
				skipToNextCommand()
				goto __continue44
			end
			if currentChar == "/" and position + 1 <= inputLength and string_get_char(normalizedInput, position + 1) == "*" then
				local commentEndPos = (string_find(
					normalizedInput,
					"*/",
					math.max(position + 2 + 1, 1),
					true
				) or 0) - 1
				if commentEndPos then
					do
						local index = position
						while index < commentEndPos + 2 do
							local checkChar = string_get_char(normalizedInput, index)
							if checkChar == "\n" then
								lineNumber = lineNumber + 1
								columnNumber = 1
							else
								columnNumber = columnNumber + 1
							end
							index = index + 1
						end
					end
					position = commentEndPos + 2
				else
					isInsideBlockComment = true
					break
				end
				goto __continue44
			end
			if currentChar == "'" then
				return Err((("Invalid character '\"' at line " .. tostring(lineNumber)) .. ", column ") ..
					tostring(columnNumber) .. ". CFG files only support double quotes")
			end
			-- Check if current character is a delimiter before trying to parse a command
			if position <= inputLength then
				local delimiterChar = string_get_char(normalizedInput, position)
				if delimiterChar == "\n" or delimiterChar == ";" then
					-- Handle the delimiter and continue to next iteration
					if delimiterChar == "\n" then
						lineNumber = lineNumber + 1
						columnNumber = 1
					else
						columnNumber = columnNumber + 1
					end
					position = position + 1
					goto __continue44
				end
			end

			-- Check if we're at the end of content before trying to parse a command
			if position > inputLength then
				goto __continue44
			end

			local commandParseResult = parseCommand()
			if not commandParseResult.ok then
				return Err(commandParseResult.error)
			end
			local parsedCommand = commandParseResult.value
			if #parsedCommand == 0 then
				return Err((("Empty command not allowed at line " .. tostring(lineNumber)) .. ", column ") ..
					tostring(columnNumber - #parsedCommand - 2))
			end
			local trailingWhitespace = captureWhitespace()
			-- Check if we're at a delimiter or end - if so, skip this command (no arguments)
			if position > inputLength then
				goto __continue44
			end
			local nextChar = string_get_char(normalizedInput, position)
			if nextChar == "\n" or nextChar == ";" or nextChar == "}" then
				-- Command with no arguments - skip it
				if nextChar == "}" then
					-- Handle closing brace
					if #blockNestingStack == 0 then
						return Err((("Unexpected closing brace '}' at line " .. tostring(lineNumber)) .. ", column ") ..
							tostring(columnNumber))
					end
					position = position + 1
					columnNumber = columnNumber + 1
					local completedBlock = table_remove(blockNestingStack)
					if #blockNestingStack > 0 then
						local parentBlock = blockNestingStack[#blockNestingStack]
						local parentBlockEntries = parentBlock.entries
						parentBlockEntries[#parentBlockEntries + 1] = completedBlock
						activeEntryList = parentBlock.entries
					else
						entries[#entries + 1] = completedBlock
						activeEntryList = entries
					end
				end
				goto __continue44
			end
			if nextChar == "{" then
				position = position + 1
				columnNumber = columnNumber + 1
				local newBlock = {
					name = parsedCommand,
					entries = {},
					lineNumber = lineNumber,
					columnNumber = columnNumber - #parsedCommand - 3,
					leadingWhitespace = leadingWhitespace
				}
				blockNestingStack[#blockNestingStack + 1] = newBlock
				activeEntryList = newBlock.entries
				goto __continue44
			end
			local argsStartPosition = position
			local entryKey
			local entryValue = ""
			local rawEntryValue = ""
			local argsWhitespace = captureWhitespace()
			local firstArgResult = parseArgument()
			if not firstArgResult.ok then
				return Err(firstArgResult.error)
			end
			local firstArgument = firstArgResult.value
			skipWhitespace()
			if position > inputLength then
				if type(firstArgument) == "string" then
					entryKey = firstArgument
					entryValue = ""
				else
					entryValue = firstArgument
				end
				rawEntryValue = string_substring(normalizedInput, argsStartPosition, position)
			else
				local nextChar = string_get_char(normalizedInput, position)
				-- Only parse a second argument if first arg is a number (not a quoted string)
				-- If first arg is a string (key), don't consume the next token as value
				-- This allows "key" "value" "other" "data" to create two separate entries
				if type(firstArgument) ~= "string" and (nextChar == "\"" or nextChar >= "0" and nextChar <= "9" or nextChar == "-" or nextChar == ".") then
					local secondArgResult = parseArgument()
					if not secondArgResult.ok then
						return Err(secondArgResult.error)
					end
					local secondArgument = secondArgResult.value
					entryValue = secondArgument
					rawEntryValue = string_substring(normalizedInput, argsStartPosition, position)
				elseif nextChar == "\n" or nextChar == ";" then
					if type(firstArgument) == "string" then
						entryKey = firstArgument
						entryValue = ""
					else
						entryValue = firstArgument
					end
					rawEntryValue = string_substring(normalizedInput, argsStartPosition, position)
				else
					if type(firstArgument) == "string" then
						entryKey = firstArgument
						-- If next char is a quote, this is a key-only entry
						-- The next quoted string will be handled as a new command
						if nextChar == "\"" then
							entryValue = ""
							rawEntryValue = string_substring(normalizedInput, argsStartPosition, position)
						else
							local remainingValue = ""
							while position <= inputLength do
								local currentChar = string_get_char(normalizedInput, position)
								if currentChar == "\n" or currentChar == ";" or currentChar == "}" then
									break
								end
								remainingValue = remainingValue .. currentChar
								position = position + 1
								columnNumber = columnNumber + 1
							end
							entryValue = string_trim(remainingValue)
							rawEntryValue = string_substring(normalizedInput, argsStartPosition, position)
						end
					else
						entryValue = firstArgument
						rawEntryValue = string_substring(normalizedInput, argsStartPosition, position)
					end
				end
			end
			activeEntryList[#activeEntryList + 1] = {
				command = parsedCommand,
				key = entryKey,
				value = entryValue,
				rawValue = rawEntryValue,
				lineNumber = lineNumber,
				leadingWhitespace = leadingWhitespace,
				trailingWhitespace = trailingWhitespace,
				argsWhitespace = argsWhitespace
			}
		end
		::__continue44::
	end
	if isInsideBlockComment then
		return Err("Unterminated block comment starting before line " .. tostring(lineNumber))
	end
	if #blockNestingStack > 0 then
		local unclosedBlock = blockNestingStack[#blockNestingStack]
		return Err((((("Unterminated block '" .. unclosedBlock.name) .. "' starting at line ") .. tostring(unclosedBlock.lineNumber)) .. ", column ") ..
			tostring(unclosedBlock.columnNumber))
	end
	return Ok { entries = entries }
end

--- Get a string value from a CFG file
---@param cfg table The parsed config object containing entries
---@param entryKey string The key to search for
---@param defaultValue? string The default value to return if key is not found
---@return string value The string value associated with the key, or defaultValue if not found
local function getString(cfg, entryKey, defaultValue)
	for _, entry in next, cfg.entries do
		if entry.key ~= nil and entry.key == entryKey then
			local stringResult
			if type(entry.value) == "string" then
				stringResult = entry.value
			else
				stringResult = tostring(entry.value)
			end
			return stringResult
		end
	end
	return defaultValue or ""
end

--- Get a number value from a CFG file
---@param cfg table The parsed config object containing entries
---@param entryKey string The key to search for
---@param defaultValue? number The default value to return if key is not found or not a number
---@return number value The numeric value associated with the key, or defaultValue if not found
local function getNumber(cfg, entryKey, defaultValue)
	for _, entry in next, cfg.entries do
		if entry.key ~= nil and entry.key == entryKey then
			if type(entry.value) == "number" then
				return entry.value
			else
				local parsedNum = to_number(entry.value)
				local numberResult
				if not number_is_nan(to_number(parsedNum)) then
					numberResult = parsedNum
				else
					numberResult = defaultValue or 0
				end
				return numberResult
			end
		end
	end
	return defaultValue or 0
end

--- Get a boolean value from a CFG file
---@param cfg table The parsed config object containing entries
---@param entryKey string The key to search for
---@param defaultValue? boolean The default value to return if key is not found
---@return boolean value true if the value is "1", "true", "yes", or "on"; false otherwise
local function getBoolean(cfg, entryKey, defaultValue)
	local stringValue = string_lower(getString(cfg, entryKey))
	if stringValue == "" then
		return defaultValue or false
	end
	return stringValue == "1" or stringValue == "true" or stringValue == "yes" or stringValue == "on"
end

--- Find a block by name in a CFG file
---@param cfg table The parsed config object containing entries
---@param blockName string The name of the block to find
---@return table? block The block entry if found, or nil if not found
local function getBlock(cfg, blockName)
	for _, entry in next, cfg.entries do
		if entry.name ~= nil and entry.name == blockName then
			return entry
		end
	end
end

--- Get all entries with a specific key (useful for duplicate keys)
---@param cfg table The parsed config object containing entries
---@param entryKey string The key to search for
---@return table matchingEntries A list of all entries that have the specified key
local function getEntriesByKey(cfg, entryKey)
	local matchingEntries = {}
	for _, entry in next, cfg.entries do
		if entry.key ~= nil and entry.key == entryKey then
			matchingEntries[#matchingEntries + 1] = entry
		end
	end
	return matchingEntries
end

-- Module exports
M.parse = parse
M.getString = getString
M.getNumber = getNumber
M.getBoolean = getBoolean
M.getBlock = getBlock
M.getEntriesByKey = getEntriesByKey

-- Export
return M
