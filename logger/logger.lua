-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Simple logger library

-- Localized global functions for better performance
local assert = assert
local error = error
local getmetatable = getmetatable
local next = next
local pairs = pairs
local pcall = pcall
local setmetatable = setmetatable
local tostring = tostring
local type = type
local io_open = io.open
local io_stdout = io.stdout
local math_huge = math.huge
local os_date = os.date
local os_time = os.time
local string_format = string.format
local string_gsub = string.gsub
local string_match = string.match
local string_sub = string.sub
local table_concat = table.concat
local table_remove = table.remove
local table_sort = table.sort

----------------------------------------------------------------------
-- Module
----------------------------------------------------------------------

---@class logger
---@field LogLevel logger.LogLevelTable
---@field LogRecord logger.LogRecord
---@field Formatter logger.Formatter
---@field PatternFormatter logger.PatternFormatter
---@field Appender logger.Appender
---@field ConsoleAppender logger.ConsoleAppender
---@field FileAppender logger.FileAppender
---@field MemoryAppender logger.MemoryAppender
---@field Logger logger.Logger
---@field ContextLogger logger.ContextLogger
---@field LogManager logger.LogManager
local logger = {}

----------------------------------------------------------------------
-- Log levels
----------------------------------------------------------------------

---@alias logger.LogLevel number

---@class logger.LogLevelTable
---@field debug logger.LogLevel Lowest standard severity.
---@field info logger.LogLevel Informational message.
---@field warn logger.LogLevel Warning condition.
---@field error logger.LogLevel Error condition.
---@field fatal logger.LogLevel Severe error condition.
---@field off logger.LogLevel Disables logging.
---@field DEBUG logger.LogLevel Alias for `debug`.
---@field INFO logger.LogLevel Alias for `info`.
---@field WARN logger.LogLevel Alias for `warn`.
---@field ERROR logger.LogLevel Alias for `error`.
---@field FATAL logger.LogLevel Alias for `fatal`.
---@field OFF logger.LogLevel Alias for `off`.
local LogLevel = {
	debug = 10,
	info = 20,
	warn = 30,
	error = 40,
	fatal = 50,

	-- A numeric sentinel keeps level comparison simple while leaving room
	-- for custom levels between the standard levels.
	off = math_huge
}

LogLevel.DEBUG = LogLevel.debug
LogLevel.INFO = LogLevel.info
LogLevel.WARN = LogLevel.warn
LogLevel.ERROR = LogLevel.error
LogLevel.FATAL = LogLevel.fatal
LogLevel.OFF = LogLevel.off

logger.LogLevel = LogLevel

---@type table<number, string>
local log_level_names = {
	[LogLevel.debug] = "DEBUG",
	[LogLevel.info] = "INFO",
	[LogLevel.warn] = "WARN",
	[LogLevel.error] = "ERROR",
	[LogLevel.fatal] = "FATAL"
}

---@param level logger.LogLevel
---@return string
local function get_level_name(level)
	return log_level_names[level] or "UNKNOWN"
end

---@param level logger.LogLevel
---@return boolean
local function is_valid_log_level(level)
	return type(level) == "number"
		and level >= LogLevel.debug
		and level <= LogLevel.off
end

---@param level logger.LogLevel
local function assert_valid_log_level(level)
	assert(
		is_valid_log_level(level),
		"invalid log level: " .. tostring(level)
	)
end

----------------------------------------------------------------------
-- Value formatting / copying
----------------------------------------------------------------------

---@param key any
---@return string
local function key_to_string(key)
	if type(key) == "string" then
		return string_format("%q", key)
	end

	return tostring(key)
end

---@param a any
---@param b any
---@return boolean
local function compare_keys(a, b)
	local type_a = type(a)
	local type_b = type(b)

	if type_a ~= type_b then
		return type_a < type_b
	end

	if type_a == "string" or type_a == "number" then
		return a < b
	end

	if type_a == "boolean" then
		if a == b then
			return false
		end

		return not a and b
	end

	return tostring(a) < tostring(b)
end

---@param value any
---@param depth number
---@param state table
---@return string
local function value_to_string(value, depth, state)
	local value_type = type(value)

	if value_type == "string" then
		return string_format("%q", value)
	end

	if value_type == "number"
		or value_type == "boolean"
		or value_type == "nil"
	then
		return tostring(value)
	end

	if value_type ~= "table" then
		return "<" .. value_type .. ">"
	end

	-- Detect recursive references before checking maximum depth so that
	-- recursive values are consistently reported as cycles.
	if state.active[value] then
		return "<cycle>"
	end

	if depth >= state.max_depth then
		return "<max-depth>"
	end

	state.active[value] = true

	local keys = {}

	for key in pairs(value) do
		keys[#keys + 1] = key
	end

	table_sort(keys, compare_keys)

	local parts = {}

	for i = 1, #keys do
		local key = keys[i]

		parts[#parts + 1] =
			key_to_string(key)
			.. "="
			.. value_to_string(value[key], depth + 1, state)
	end

	state.active[value] = nil

	return "{" .. table_concat(parts, ", ") .. "}"
end

---@param value table
---@param max_depth? number
---@return string
local function table_to_string(value, max_depth)
	if type(value) ~= "table" then
		return tostring(value)
	end

	local state = {
		active = {},
		max_depth = max_depth or 5
	}

	return value_to_string(value, 0, state)
end

---@param value any
---@param seen? table<table, table>
---@return any
local function deep_copy(value, seen)
	if type(value) ~= "table" then
		return value
	end

	seen = seen or {}

	local existing = seen[value]

	if existing then
		return existing
	end

	local copy = {}

	seen[value] = copy

	for key, nested_value in next, value do
		local copied_key = deep_copy(key, seen)
		local copied_value = deep_copy(nested_value, seen)

		copy[copied_key] = copied_value
	end

	-- Preserve table metatables when possible.
	--
	-- This allows ordinary typed/context tables to retain their behaviour
	-- while still preventing later mutation of their fields from modifying
	-- the original log context.
	local metatable = getmetatable(value)

	if type(metatable) == "table" then
		setmetatable(copy, metatable)
	end

	return copy
end

---@param object table|userdata
---@param method_name string
---@param interface_name string
local function assert_method(object, method_name, interface_name)
	assert(
		object ~= nil,
		interface_name .. " is required"
	)

	assert(
		type(object[method_name]) == "function",
		interface_name .. " must implement :" .. method_name .. "()"
	)
end

----------------------------------------------------------------------
-- LogRecord
----------------------------------------------------------------------

---@class logger.LogRecord
---@field level logger.LogLevel Numeric severity.
---@field level_name string Uppercase severity name.
---@field message string Fully evaluated message.
---@field timestamp number Unix timestamp returned by `os.time()`.
---@field logger_name string Name of the originating logger.
---@field context table<string, any> Defensive snapshot of structured context.
local LogRecord = {}
LogRecord.__index = LogRecord

--- Creates a new log record with a context snapshot.
---@param level logger.LogLevel
---@param message string
---@param context? table<string, any>
---@param logger_name? string
---@param timestamp? number
---@return logger.LogRecord
function LogRecord.new(level, message, context, logger_name, timestamp)
	assert_valid_log_level(level)

	assert(
		type(message) == "string",
		"LogRecord message must be a string"
	)

	if context ~= nil then
		assert(
			type(context) == "table",
			"LogRecord context must be a table or nil"
		)
	end

	return setmetatable({
		level = level,
		level_name = get_level_name(level),
		message = message,
		timestamp = timestamp or os_time(),
		logger_name = logger_name or "",
		context = deep_copy(context or {}),
	}, LogRecord)
end

--- Creates an independent copy of this record.
---@return logger.LogRecord
function LogRecord:clone()
	return LogRecord.new(
		self.level,
		self.message,
		self.context,
		self.logger_name,
		self.timestamp
	)
end

--- Renders the record as a human-readable line.
---@return string
function LogRecord:__tostring()
	local context = ""

	if next(self.context) ~= nil then
		context = " " .. table_to_string(self.context)
	end

	return string_format(
		"[%s] [%s] %s: %s%s",
		os_date("%Y-%m-%d %H:%M:%S", self.timestamp),
		self.level_name,
		self.logger_name,
		self.message,
		context
	)
end

logger.LogRecord = LogRecord

----------------------------------------------------------------------
-- Formatter
----------------------------------------------------------------------

---@class logger.Formatter
local Formatter = {}
Formatter.__index = Formatter

--- Formats a log record for output.<br>
--- Implementations are intentionally duck-typed.<br>
--- A custom formatter only needs to implement `format(record)`.
---@param record logger.LogRecord
---@return string
function Formatter:format(record)
	error("logger.Formatter:format() must be implemented")
end

logger.Formatter = Formatter

----------------------------------------------------------------------
-- PatternFormatter
----------------------------------------------------------------------

---@alias logger.PatternToken fun(record: logger.LogRecord, formatter: logger.PatternFormatter):string

---@class logger.PatternFormatter : logger.Formatter
---@field pattern string Output pattern.
---@field date_format string Format passed to `os.date`.
---@field context_max_depth number Maximum depth used when serializing context.
---@field strict_patterns boolean Whether unknown pattern tokens raise an error.
---@field tokens table<string, logger.PatternToken> Registered pattern tokens.
local PatternFormatter = {}
PatternFormatter.__index = PatternFormatter
setmetatable(PatternFormatter, { __index = Formatter })

--- Creates a pattern formatter with default tokens.
---@param pattern? string
---@param date_format? string
---@param context_max_depth? number
---@param strict_patterns? boolean
---@return logger.PatternFormatter
function PatternFormatter.new(
	pattern,
	date_format,
	context_max_depth,
	strict_patterns
)
	return setmetatable({
		pattern = pattern or "[%d] [%p] %n: %m%X",
		date_format = date_format or "%Y-%m-%d %H:%M:%S",
		context_max_depth = context_max_depth or 5,
		strict_patterns = strict_patterns == true,
		tokens = {
			d = function(record, formatter)
				return os_date(formatter.date_format, record.timestamp)
			end,

			p = function(record)
				return record.level_name
			end,

			n = function(record)
				return record.logger_name
			end,

			m = function(record)
				return record.message
			end,

			X = function(record, formatter)
				if next(record.context) == nil then
					return ""
				end

				return " " .. table_to_string(
					record.context,
					formatter.context_max_depth
				)
			end,

			["%"] = function()
				return "%"
			end,
		},
	}, PatternFormatter)
end

--- Replaces the output pattern.
---@param pattern string
---@return logger.PatternFormatter
function PatternFormatter:set_pattern(pattern)
	assert(
		type(pattern) == "string",
		"formatter pattern must be a string"
	)

	self.pattern = pattern

	return self
end

--- Returns the current output pattern.
---@return string
function PatternFormatter:get_pattern()
	return self.pattern
end

--- Replaces the date format string.
---@param date_format string
---@return logger.PatternFormatter
function PatternFormatter:set_date_format(date_format)
	assert(
		type(date_format) == "string",
		"date format must be a string"
	)

	self.date_format = date_format

	return self
end

--- Sets the context serialization depth.
---@param max_depth number
---@return logger.PatternFormatter
function PatternFormatter:set_context_max_depth(max_depth)
	assert(
		type(max_depth) == "number" and max_depth >= 0,
		"context max depth must be a non-negative number"
	)

	self.context_max_depth = max_depth

	return self
end

--- Enables or disables strict token checking.
---@param strict boolean
---@return logger.PatternFormatter
function PatternFormatter:set_strict_patterns(strict)
	assert(
		type(strict) == "boolean",
		"strict_patterns must be boolean"
	)

	self.strict_patterns = strict

	return self
end

--- Registers a custom pattern token handler.
---@param token string Single-character token.
---@param handler logger.PatternToken
---@return logger.PatternFormatter
function PatternFormatter:set_token(token, handler)
	assert(
		type(token) == "string"
		and #token == 1
		and string_match(token, "^[%a%d%%]$"),
		"pattern token must be one alphanumeric character or '%'"
	)

	assert(
		type(handler) == "function",
		"pattern token handler must be a function"
	)

	self.tokens[token] = handler

	return self
end

--- Unregisters a pattern token.
---@param token string
---@return logger.PatternFormatter
function PatternFormatter:remove_token(token)
	assert(
		type(token) == "string" and #token == 1,
		"pattern token must be one character"
	)

	self.tokens[token] = nil

	return self
end

--- Renders a record using the output pattern.
---@param record logger.LogRecord
---@return string
function PatternFormatter:format(record)
	return (string_gsub(self.pattern, "%%([%%a-zA-Z0-9])", function(token)
		local handler = self.tokens[token]

		if handler then
			return tostring(handler(record, self))
		end

		if self.strict_patterns then
			error(
				"unknown logger pattern token: %" .. token
			)
		end

		return "%" .. token
	end))
end

--- Returns a short formatter description.
---@return string
function PatternFormatter:__tostring()
	return "PatternFormatter<" .. self.pattern .. ">"
end

logger.PatternFormatter = PatternFormatter

----------------------------------------------------------------------
-- Appender
----------------------------------------------------------------------

---@class logger.Appender
---@field level logger.LogLevel Minimum level accepted by the appender.
local Appender = {}
Appender.__index = Appender

--- Returns the minimum record severity accepted by this appender.
---@return logger.LogLevel
function Appender:get_level()
	return self.level or LogLevel.debug
end

--- Sets the minimum accepted level.
---@param level logger.LogLevel
---@return logger.Appender
function Appender:set_level(level)
	assert_valid_log_level(level)

	self.level = level

	return self
end

--- Checks whether a level is accepted.
---@param level logger.LogLevel
---@return boolean
function Appender:is_enabled(level)
	assert_valid_log_level(level)

	return level < LogLevel.off
		and level >= self:get_level()
end

--- Writes a formatted log record to the appender's destination.<br>
--- Implementations are intentionally duck-typed.<br>
--- A custom appender needs only an `append(formatted_message, record)` method.
---@param formatted_message string
---@param record logger.LogRecord
function Appender:append(formatted_message, record)
	error("logger.Appender:append() must be implemented")
end

logger.Appender = Appender

----------------------------------------------------------------------
-- ConsoleAppender
----------------------------------------------------------------------

---@class logger.ConsoleAppender : logger.Appender
---@field stream table Writable file-like object.
---@field flush_each_write boolean Whether to flush after every message.
---@field level logger.LogLevel Minimum level accepted.
local ConsoleAppender = {}
ConsoleAppender.__index = ConsoleAppender
setmetatable(ConsoleAppender, { __index = Appender })

--- Creates an appender writing to a stream.
---@param stream? table
---@param level? logger.LogLevel
---@param flush_each_write? boolean
---@return logger.ConsoleAppender
function ConsoleAppender.new(stream, level, flush_each_write)
	local self = setmetatable({
		stream = stream or io_stdout,
		level = level or LogLevel.debug,
		flush_each_write = flush_each_write ~= false,
	}, ConsoleAppender)

	assert(
		type(self.stream.write) == "function",
		"console stream must implement :write()"
	)

	return self
end

--- Writes a message to the stream.
---@param formatted_message string
---@param record logger.LogRecord
function ConsoleAppender:append(formatted_message, record)
	self.stream:write(formatted_message)
	self.stream:write("\n")

	if self.flush_each_write
		and type(self.stream.flush) == "function"
	then
		self.stream:flush()
	end
end

logger.ConsoleAppender = ConsoleAppender

----------------------------------------------------------------------
-- FileAppender
----------------------------------------------------------------------

---@class logger.FileAppender : logger.Appender
---@field file? table Open file handle, or nil after closing.
---@field path string File path.
---@field flush_each_write boolean Whether to flush after every message.
---@field closed boolean Whether the appender has been closed.
---@field level logger.LogLevel Minimum level accepted.
local FileAppender = {}
FileAppender.__index = FileAppender
setmetatable(FileAppender, { __index = Appender })

--- Opens a file appender for writing.
---@param path string
---@param mode? string File mode (default: "a").
---@param level? logger.LogLevel
---@param flush_each_write? boolean
---@return logger.FileAppender?
---@return string?
function FileAppender.new(
	path,
	mode,
	level,
	flush_each_write
)
	assert(
		type(path) == "string" and path ~= "",
		"file path must be a non-empty string"
	)

	local file, err = io_open(path, mode or "a")

	if not file then
		return nil, err
	end

	return (setmetatable({
		file = file,
		path = path,
		flush_each_write = flush_each_write ~= false,
		closed = false,
		level = level or LogLevel.debug,
	}, FileAppender)) ---@as logger.FileAppender
end

--- Strict constructor variant that raises when the file cannot be opened.
---@param path string
---@param mode? string
---@param level? logger.LogLevel
---@param flush_each_write? boolean
---@return logger.FileAppender
function FileAppender.open(
	path,
	mode,
	level,
	flush_each_write
)
	local appender, err = FileAppender.new(
		path,
		mode,
		level,
		flush_each_write
	)

	if not appender then
		error(
			"failed to open log file '"
			.. path
			.. "': "
			.. tostring(err)
		)
	end

	return appender
end

--- Checks whether the appender is closed.
---@return boolean
function FileAppender:is_closed()
	return self.closed
end

--- Appends a message to the log file.
---@param formatted_message string
---@param record logger.LogRecord
function FileAppender:append(formatted_message, record)
	if self.closed or not self.file then
		error(
			"cannot append to closed file appender: "
			.. self.path
		)
	end

	self.file:write(formatted_message)
	self.file:write("\n")

	if self.flush_each_write then
		self.file:flush()
	end
end

--- Closes the log file.
---@return boolean
---@return string?
function FileAppender:close()
	if self.closed then
		return true
	end

	local file = self.file

	if not file then
		self.closed = true
		return true
	end

	local ok, err = file:close()

	if not ok then
		return false, err
	end

	self.file = nil
	self.closed = true

	return true
end

--- Returns a short appender description.
---@return string
function FileAppender:__tostring()
	return string_format(
		"FileAppender<%s, %s>",
		self.path,
		self.closed and "closed" or "open"
	)
end

logger.FileAppender = FileAppender

----------------------------------------------------------------------
-- MemoryAppender
----------------------------------------------------------------------

---@class logger.MemoryRecord
---@field message string Formatted message.
---@field record logger.LogRecord Snapshot of the original record.

---@class logger.MemoryAppender : logger.Appender
---@field records logger.MemoryRecord[]
---@field level logger.LogLevel Minimum level accepted.
local MemoryAppender = {}
MemoryAppender.__index = MemoryAppender
setmetatable(MemoryAppender, { __index = Appender })

--- Creates an in-memory capturing appender.
---@param level? logger.LogLevel
---@return logger.MemoryAppender
function MemoryAppender.new(level)
	return setmetatable({
		records = {},
		level = level or LogLevel.debug,
	}, MemoryAppender)
end

--- Stores a message and record snapshot.
---@param formatted_message string
---@param record logger.LogRecord
function MemoryAppender:append(formatted_message, record)
	self.records[#self.records + 1] = {
		message = formatted_message,
		record = record:clone()
	}
end

--- Discards all captured records.
function MemoryAppender:clear()
	self.records = {}
end

--- Returns the number of captured records.
---@return integer
function MemoryAppender:get_count()
	return #self.records
end

--- Returns a copy of the captured records.
---@return logger.MemoryRecord[]
function MemoryAppender:get_records()
	local result = {}

	for i = 1, #self.records do
		result[i] = self.records[i]
	end

	return result
end

logger.MemoryAppender = MemoryAppender

----------------------------------------------------------------------
-- Logger
----------------------------------------------------------------------

---@alias logger.LogMessage string|fun():string

---@alias logger.AppenderErrorHandler fun(logger: logger.Logger, appender: logger.Appender, error_message: string, record: logger.LogRecord)

---@class logger.Logger
---@field name string Logger name.
---@field level? logger.LogLevel Local threshold. `nil` means inherit from parent.
---@field appenders logger.Appender[] Appenders attached directly to this logger.
---@field formatter logger.Formatter Formatter used by this logger.
---@field parent? logger.Logger Parent logger in the hierarchy.
---@field additive boolean Whether records propagate to ancestors.
---@field appender_error_handler? logger.AppenderErrorHandler Optional appender error callback.
local Logger = {}
Logger.__index = Logger

--- Creates a named logger.
---@param name string
---@param formatter? logger.Formatter
---@param parent? logger.Logger
---@return logger.Logger
function Logger.new(name, formatter, parent)
	assert(
		type(name) == "string" and name ~= "",
		"logger name must be a non-empty string"
	)

	if formatter ~= nil then
		assert_method(formatter, "format", "formatter")
	end

	return setmetatable({
		name = name,
		level = nil,
		appenders = {},
		formatter = formatter or PatternFormatter.new(),
		parent = parent,
		additive = true,
		appender_error_handler = nil,
	}, Logger)
end

--- Sets the local level threshold.
---@param level? logger.LogLevel
---@return logger.Logger
function Logger:set_level(level)
	if level ~= nil then
		assert_valid_log_level(level)
	end

	self.level = level

	return self
end

--- Returns the local level, or nil when unset.
---@return logger.LogLevel?
function Logger:get_local_level()
	return self.level
end

--- Resolves the level including inheritance.
---@return logger.LogLevel
function Logger:get_effective_level()
	if self.level ~= nil then
		return self.level
	end

	if self.parent then
		return self.parent:get_effective_level()
	end

	return LogLevel.debug
end

--- Returns the effective threshold for this logger.<br>
--- This is equivalent to `get_effective_level()` and is kept as the primary level query for API compatibility.
---@return logger.LogLevel
function Logger:get_level()
	return self:get_effective_level()
end

--- Checks whether a level will be emitted.
---@param level logger.LogLevel
---@return boolean
function Logger:is_enabled(level)
	assert_valid_log_level(level)

	return level < LogLevel.off
		and level >= self:get_effective_level()
end

--- Returns the logger formatter.
---@return logger.Formatter
function Logger:get_formatter()
	return self.formatter
end

--- Replaces the logger formatter.
---@param formatter logger.Formatter
---@return logger.Logger
function Logger:set_formatter(formatter)
	assert_method(formatter, "format", "formatter")

	self.formatter = formatter

	return self
end

--- Returns the parent logger, if any.
---@return logger.Logger?
function Logger:get_parent()
	return self.parent
end

--- Attaches the logger to a parent.
---@param parent? logger.Logger
---@return logger.Logger
function Logger:set_parent(parent)
	if parent == self then
		error("logger cannot be its own parent")
	end

	local current = parent

	while current do
		if current == self then
			error("logger parent assignment would create a cycle")
		end

		current = current.parent
	end

	self.parent = parent

	return self
end

--- Checks whether records propagate upward.
---@return boolean
function Logger:is_additive()
	return self.additive
end

--- Enables or disables ancestor propagation.
---@param additive boolean
---@return logger.Logger
function Logger:set_additive(additive)
	assert(
		type(additive) == "boolean",
		"additive must be boolean"
	)

	self.additive = additive

	return self
end

--- Attaches an appender to the logger.
---@param appender logger.Appender
---@return logger.Appender
function Logger:add_appender(appender)
	assert_method(appender, "append", "appender")

	self.appenders[#self.appenders + 1] = appender

	return appender
end

--- Checks whether an appender is attached.
---@param appender logger.Appender
---@return boolean
function Logger:has_appender(appender)
	for i = 1, #self.appenders do
		if self.appenders[i] == appender then
			return true
		end
	end

	return false
end

--- Detaches an appender from the logger.
---@param appender logger.Appender
---@return boolean
function Logger:remove_appender(appender)
	for i = 1, #self.appenders do
		if self.appenders[i] == appender then
			table_remove(self.appenders, i)
			return true
		end
	end

	return false
end

--- Detaches all appenders.
function Logger:clear_appenders()
	self.appenders = {}
end

--- Returns a copy of the attached appenders.
---@return logger.Appender[]
function Logger:get_appenders()
	local result = {}

	for i = 1, #self.appenders do
		result[i] = self.appenders[i]
	end

	return result
end

--- Sets the appender error callback.
---@param handler? logger.AppenderErrorHandler
---@return logger.Logger
function Logger:set_appender_error_handler(handler)
	if handler ~= nil then
		assert(
			type(handler) == "function",
			"appender error handler must be a function"
		)
	end

	self.appender_error_handler = handler

	return self
end

---@param appender logger.Appender
---@param record logger.LogRecord
---@param formatted_message string
local function append_to_appender(
	appender,
	record,
	formatted_message,
	owner
)
	local is_enabled = appender.is_enabled

	if type(is_enabled) == "function" then
		local enabled_ok, enabled = pcall(
			is_enabled,
			appender,
			record.level
		)

		if not enabled_ok then
			if owner.appender_error_handler then
				pcall(
					owner.appender_error_handler,
					owner,
					appender,
					tostring(enabled),
					record
				)
			end

			return
		end

		if not enabled then
			return
		end
	end

	local ok, err = pcall(
		appender.append,
		appender,
		formatted_message,
		record
	)

	if ok then
		return
	end

	if owner.appender_error_handler then
		pcall(
			owner.appender_error_handler,
			owner,
			appender,
			tostring(err),
			record
		)
	end
end

--- Emits a record if the level is enabled.
---@param level logger.LogLevel
---@param message logger.LogMessage
---@param context? table<string, any>
---@return boolean emitted
function Logger:log(level, message, context)
	assert_valid_log_level(level)

	-- Do this before evaluating a lazy message or copying context.
	if not self:is_enabled(level) then
		return false
	end

	if type(message) == "function" then
		message = message()
	end

	if type(message) ~= "string" then
		message = tostring(message)
	end

	if context ~= nil then
		assert(
			type(context) == "table",
			"log context must be a table or nil"
		)
	end

	local record = LogRecord.new(
		level,
		message,
		context,
		self.name
	)

	-- Formatter errors intentionally propagate. They generally indicate a
	-- programming/configuration error and should not disappear silently.
	local formatted_message = self.formatter:format(record)

	for i = 1, #self.appenders do
		append_to_appender(
			self.appenders[i],
			record,
			formatted_message,
			self
		)
	end

	-- Propagation does not re-check ancestor logger levels.
	--
	-- The originating logger decides whether the record exists.
	-- Ancestor appenders may independently filter the record via their
	-- own `is_enabled` implementation / minimum level.
	if self.additive then
		local parent = self.parent

		while parent do
			for i = 1, #parent.appenders do
				append_to_appender(
					parent.appenders[i],
					record,
					formatted_message,
					parent
				)
			end

			if not parent.additive then
				break
			end

			parent = parent.parent
		end
	end

	return true
end

--- Formats and emits a message.
---@param level logger.LogLevel
---@param format_string string
---@param ... any
---@return boolean emitted
function Logger:logf(level, format_string, ...)
	assert(
		type(format_string) == "string",
		"format string must be a string"
	)

	-- `string.format` errors intentionally propagate because invalid format
	-- strings are programming errors, unlike destination/appender failures.
	local message = string_format(format_string, ...)

	return self:log(level, message)
end

--- Emits a debug message with optional context.
---@param message logger.LogMessage
---@param context? table<string, any>
---@return boolean emitted
function Logger:debug(message, context)
	return self:log(LogLevel.debug, message, context)
end

--- Emits an info message with optional context.
---@param message logger.LogMessage
---@param context? table<string, any>
---@return boolean emitted
function Logger:info(message, context)
	return self:log(LogLevel.info, message, context)
end

--- Emits a warning message with optional context.
---@param message logger.LogMessage
---@param context? table<string, any>
---@return boolean emitted
function Logger:warn(message, context)
	return self:log(LogLevel.warn, message, context)
end

--- Emits an error message with optional context.
---@param message logger.LogMessage
---@param context? table<string, any>
---@return boolean emitted
function Logger:error(message, context)
	return self:log(LogLevel.error, message, context)
end

--- Emits a fatal message with optional context.
---@param message logger.LogMessage
---@param context? table<string, any>
---@return boolean emitted
function Logger:fatal(message, context)
	return self:log(LogLevel.fatal, message, context)
end

--- Returns a short logger description.
---@return string
function Logger:__tostring()
	return string_format(
		"Logger<%s, level=%s>",
		self.name,
		get_level_name(self:get_effective_level())
	)
end

logger.Logger = Logger

----------------------------------------------------------------------
-- ContextLogger
----------------------------------------------------------------------

--- Lightweight context-bound logger facade.<br>
--- ContextLogger uses composition rather than inheritance.<br>
--- It delegates configuration and hierarchy operations to its underlying `Logger`, while automatically merging bound context into each log call.
---@class logger.ContextLogger
---@field logger logger.Logger Underlying logger.
---@field name string Underlying logger name.
---@field base_context table<string, any> Context automatically attached to records.
local ContextLogger = {}
ContextLogger.__index = ContextLogger

--- Creates a facade binding context to a logger.
---@param base_logger logger.Logger
---@param context table<string, any>
---@return logger.ContextLogger
function ContextLogger.new(base_logger, context)
	assert(
		type(base_logger) == "table",
		"base logger is required"
	)

	assert(
		type(context) == "table",
		"context must be a table"
	)

	return setmetatable({
		logger = base_logger,
		name = base_logger.name,
		base_context = deep_copy(context),
	}, ContextLogger)
end

--- Merges call context over the bound context.
---@param context? table<string, any>
---@return table<string, any>?
function ContextLogger:_merge_context(context)
	if context == nil then
		if next(self.base_context) == nil then
			return nil
		end

		return deep_copy(self.base_context)
	end

	assert(
		type(context) == "table",
		"log context must be a table or nil"
	)

	local merged = deep_copy(self.base_context)

	for key, value in next, context do
		merged[key] = value
	end

	return merged
end

--- Returns the underlying logger.
---@return logger.Logger
function ContextLogger:get_logger()
	return self.logger
end

--- Returns the underlying local level.
---@return logger.LogLevel?
function ContextLogger:get_local_level()
	return self.logger:get_local_level()
end

--- Returns the underlying effective level.
---@return logger.LogLevel
function ContextLogger:get_effective_level()
	return self.logger:get_effective_level()
end

--- Returns the underlying effective threshold.
---@return logger.LogLevel
function ContextLogger:get_level()
	return self.logger:get_level()
end

--- Checks whether a level is enabled.
---@param level logger.LogLevel
---@return boolean
function ContextLogger:is_enabled(level)
	return self.logger:is_enabled(level)
end

--- Returns the underlying formatter.
---@return logger.Formatter
function ContextLogger:get_formatter()
	return self.logger:get_formatter()
end

--- Replaces the underlying formatter.
---@param formatter logger.Formatter
---@return logger.ContextLogger
function ContextLogger:set_formatter(formatter)
	self.logger:set_formatter(formatter)
	return self
end

--- Sets the underlying local level.
---@param level? logger.LogLevel
---@return logger.ContextLogger
function ContextLogger:set_level(level)
	self.logger:set_level(level)
	return self
end

--- Returns the underlying parent logger.
---@return logger.Logger?
function ContextLogger:get_parent()
	return self.logger:get_parent()
end

--- Replaces the underlying parent logger.
---@param parent? logger.Logger
---@return logger.ContextLogger
function ContextLogger:set_parent(parent)
	self.logger:set_parent(parent)
	return self
end

--- Checks underlying ancestor propagation.
---@return boolean
function ContextLogger:is_additive()
	return self.logger:is_additive()
end

--- Toggles underlying ancestor propagation.
---@param additive boolean
---@return logger.ContextLogger
function ContextLogger:set_additive(additive)
	self.logger:set_additive(additive)
	return self
end

--- Attaches an appender to the underlying logger.
---@param appender logger.Appender
---@return logger.Appender
function ContextLogger:add_appender(appender)
	return self.logger:add_appender(appender)
end

--- Detaches an appender from the underlying logger.
---@param appender logger.Appender
---@return boolean
function ContextLogger:remove_appender(appender)
	return self.logger:remove_appender(appender)
end

--- Checks an appender on the underlying logger.
---@param appender logger.Appender
---@return boolean
function ContextLogger:has_appender(appender)
	return self.logger:has_appender(appender)
end

--- Detaches all underlying appenders.
function ContextLogger:clear_appenders()
	self.logger:clear_appenders()
end

--- Returns the underlying attached appenders.
---@return logger.Appender[]
function ContextLogger:get_appenders()
	return self.logger:get_appenders()
end

--- Sets the underlying error callback.
---@param handler? logger.AppenderErrorHandler
---@return logger.ContextLogger
function ContextLogger:set_appender_error_handler(handler)
	self.logger:set_appender_error_handler(handler)
	return self
end

--- Emits a record with merged context.
---@param level logger.LogLevel
---@param message logger.LogMessage
---@param context? table<string, any>
---@return boolean emitted
function ContextLogger:log(level, message, context)
	if not self.logger:is_enabled(level) then
		return false
	end

	return self.logger:log(
		level,
		message,
		self:_merge_context(context)
	)
end

--- Formats a message and emits it.
---@param level logger.LogLevel
---@param format_string string
---@param ... any
---@return boolean emitted
function ContextLogger:logf(level, format_string, ...)
	return self.logger:logf(
		level,
		string_format(format_string, ...),
		self:_merge_context(nil)
	)
end

--- Emits a debug message with merged context.
---@param message logger.LogMessage
---@param context? table<string, any>
---@return boolean emitted
function ContextLogger:debug(message, context)
	return self:log(LogLevel.debug, message, context)
end

--- Emits an info message with merged context.
---@param message logger.LogMessage
---@param context? table<string, any>
---@return boolean emitted
function ContextLogger:info(message, context)
	return self:log(LogLevel.info, message, context)
end

--- Emits a warning message with merged context.
---@param message logger.LogMessage
---@param context? table<string, any>
---@return boolean emitted
function ContextLogger:warn(message, context)
	return self:log(LogLevel.warn, message, context)
end

--- Emits an error message with merged context.
---@param message logger.LogMessage
---@param context? table<string, any>
---@return boolean emitted
function ContextLogger:error(message, context)
	return self:log(LogLevel.error, message, context)
end

--- Emits a fatal message with merged context.
---@param message logger.LogMessage
---@param context? table<string, any>
---@return boolean emitted
function ContextLogger:fatal(message, context)
	return self:log(LogLevel.fatal, message, context)
end

--- Derives a facade with extra context.
---@param context table<string, any>
---@return logger.ContextLogger
function ContextLogger:with_context(context)
	assert(
		type(context) == "table",
		"context must be a table"
	)

	local merged = deep_copy(self.base_context)

	for key, value in next, context do
		merged[key] = value
	end

	return ContextLogger.new(
		self.logger,
		merged
	)
end

--- Returns a short facade description.
---@return string
function ContextLogger:__tostring()
	return string_format(
		"ContextLogger<%s>",
		self.name
	)
end

logger.ContextLogger = ContextLogger

--- Creates a context-bound facade for this logger.
---@param context table<string, any>
---@return logger.ContextLogger
function Logger:with_context(context)
	return ContextLogger.new(self, context)
end

----------------------------------------------------------------------
-- LogManager
----------------------------------------------------------------------

---@class logger.LogManagerConfiguration
---@field level? logger.LogLevel Root logger level.
---@field formatter? logger.Formatter Root formatter.
---@field appenders? logger.Appender[] Root appenders. Replaces existing appenders.

---@class logger.LogManager
---@field loggers table<string, logger.Logger>
---@field root logger.Logger
local LogManager = {
	loggers = {}
}

--- Derives the parent logger name.
---@param name string Logger name.
---@return string? Parent logger name, or nil for root.
local function get_parent_name(name)
	local parent_name = string_match(name, "^(.*)%.[^%.]+$")

	if parent_name and parent_name ~= "" then
		return parent_name
	end

	if name ~= "root" then
		return "root"
	end

	return nil
end

--- Returns or creates the named managed logger.
---@param name string
---@return logger.Logger
function LogManager.get_logger(name)
	assert(
		type(name) == "string" and name ~= "",
		"logger name must be a non-empty string"
	)

	local existing = LogManager.loggers[name]

	if existing then
		return existing
	end

	local parent_name = get_parent_name(name)

	local parent

	if parent_name then
		parent = LogManager.get_logger(parent_name)
	end

	local log = Logger.new(
		name,
		PatternFormatter.new(),
		parent
	)

	LogManager.loggers[name] = log

	return log
end

--- Returns the root logger.
---@return logger.Logger
function LogManager.get_root()
	return LogManager.root
end

--- Applies configuration to the root logger.
---@param config logger.LogManagerConfiguration
function LogManager.configure(config)
	assert(
		type(config) == "table",
		"configuration must be a table"
	)

	local root = LogManager.root

	if config.level ~= nil then
		root:set_level(config.level)
	end

	if config.formatter ~= nil then
		root:set_formatter(config.formatter)
	end

	if config.appenders ~= nil then
		assert(
			type(config.appenders) == "table",
			"configuration appenders must be a table"
		)

		root:clear_appenders()

		for i = 1, #config.appenders do
			root:add_appender(config.appenders[i])
		end
	end
end

--- Orders loggers by name for sorting.
---@param a logger.Logger First logger.
---@param b logger.Logger Second logger.
---@return boolean True when `a` sorts before `b`.
local function compare_name(a, b)
	return a.name < b.name
end

--- Returns all managed loggers sorted by name.
---@return logger.Logger[]
function LogManager.get_loggers()
	local result = {}

	for _, log in next, LogManager.loggers do
		result[#result + 1] = log
	end

	table_sort(result, compare_name)

	return result
end

--- Removes a named logger from the manager cache.<br>
--- Existing external references to the removed logger remain valid, but future calls to `get_logger(name)` may create a new logger instance.<br>
--- By default a logger with children cannot be removed.<br>
--- Pass `recursive=true` to remove the logger and all descendants from the manager cache.
---@param name string
---@param recursive? boolean
---@return boolean removed
function LogManager.remove_logger(name, recursive)
	assert(
		type(name) == "string" and name ~= "",
		"logger name must be a non-empty string"
	)

	if name == "root" then
		return false
	end

	if not LogManager.loggers[name] then
		return false
	end

	local prefix = name .. "."

	local has_children = false

	for logger_name in next, LogManager.loggers do
		if string_sub(logger_name, 1, #prefix) == prefix then
			has_children = true
			break
		end
	end

	if has_children and not recursive then
		return false
	end

	LogManager.loggers[name] = nil

	if recursive then
		for logger_name in next, LogManager.loggers do
			if string_sub(logger_name, 1, #prefix) == prefix then
				LogManager.loggers[logger_name] = nil
			end
		end
	end

	return true
end

-- Create root eagerly so all ordinary managed loggers can inherit from it.
LogManager.root = Logger.new(
	"root",
	PatternFormatter.new(),
	nil
)

LogManager.loggers.root = LogManager.root

logger.LogManager = LogManager

----------------------------------------------------------------------
-- Optional convenience API
----------------------------------------------------------------------

--- Returns or creates the named managed logger.
---@param name string
---@return logger.Logger
function logger.get_logger(name)
	return LogManager.get_logger(name)
end

--- Returns the root logger.
---@return logger.Logger
function logger.get_root_logger()
	return LogManager.get_root()
end

--- Returns the name of a log level.
---@param level logger.LogLevel
---@return string
function logger.get_level_name(level)
	assert_valid_log_level(level)

	return get_level_name(level)
end

--- Applies configuration to the root logger.
---@param config logger.LogManagerConfiguration
---@return logger.Logger
function logger.configure(config)
	LogManager.configure(config)
	return LogManager.root
end

-- Export
return logger
