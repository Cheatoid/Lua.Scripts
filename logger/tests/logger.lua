-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for logger.lua.
-- Run from this directory:
--   lua logger.lua
--   luajit logger.lua

-- Bootstrap: make requires work from tests/ subdir with plain lua/luajit.
do
	local src = debug.getinfo(1, "S").source
	local dir = src:match("^@(.+/)[^/]+$") or "./"
	local function isfile(p)
		local f = io.open(p, "r")
		if f then
			f:close()
			return true
		end
		return false
	end
	local root
	for _, c in ipairs({ dir, dir .. "../", dir .. "../..//", dir .. "../../..//", "./", "../", "../../" }) do
		if isfile(c .. "standalone/bits.lua") then
			root = c
			break
		end
	end
	root = root or dir .. "../"
	if package then
		package.path = dir ..
			"../?.lua;" ..
			dir ..
			"../?/init.lua;" ..
			dir ..
			"?.lua;" ..
			dir ..
			"?/init.lua;" ..
			root ..
			"?.lua;" ..
			root ..
			"?/init.lua;" ..
			root ..
			"standalone/?.lua;" ..
			root ..
			"math/?.lua;" ..
			root ..
			"collections/?.lua;" ..
			root ..
			"benchmark/?.lua;" ..
			root ..
			"timer/?.lua;" ..
			root ..
			"autocompleter/?.lua;" ..
			root ..
			"permission/?.lua;" ..
			root ..
			"chat_commander/?.lua;" ..
			root .. "vm/?.lua;" .. root .. "require_finder/?.lua;" .. root .. "inventory/?.lua;" .. package.path
	end
	local searchers = package.searchers or package.loaders
	if searchers then
		table.insert(searchers, 2, function(mod)
			if mod:sub(1, 3) == "../" or mod:sub(1, 2) == "./" then
				local clean = mod:gsub("^%./", ""):gsub("^%.%.%/", ""):gsub("^%.%.%/", "")
				local tries = { dir .. "../" .. clean .. ".lua", dir .. "../" .. clean .. "/init.lua", root ..
				clean .. ".lua", root .. clean .. "/init.lua" }
				for _, f in ipairs(tries) do
					if isfile(f) then
						local chunk, err = loadfile(f)
						if chunk then return chunk, f end
					end
				end
			end
			return nil
		end)
	end
end
local lib = require "logger"
local logger = lib
local LogLevel = logger.LogLevel
local LogRecord = logger.LogRecord
local PatternFormatter = logger.PatternFormatter
local ConsoleAppender = logger.ConsoleAppender
local FileAppender = logger.FileAppender
local MemoryAppender = logger.MemoryAppender
local Logger = logger.Logger
local ContextLogger = logger.ContextLogger
local LogManager = logger.LogManager

if true then
	-- Log levels and aliases
	assert(LogLevel.debug == 10, "debug level should be 10")
	assert(LogLevel.info == 20, "info level should be 20")
	assert(LogLevel.warn == 30, "warn level should be 30")
	assert(LogLevel.error == 40, "error level should be 40")
	assert(LogLevel.fatal == 50, "fatal level should be 50")
	assert(LogLevel.off == math.huge, "off level should be math.huge")
	assert(LogLevel.DEBUG == LogLevel.debug, "DEBUG should alias debug")
	assert(LogLevel.INFO == LogLevel.info, "INFO should alias info")
	assert(LogLevel.WARN == LogLevel.warn, "WARN should alias warn")
	assert(LogLevel.ERROR == LogLevel.error, "ERROR should alias error")
	assert(LogLevel.FATAL == LogLevel.fatal, "FATAL should alias fatal")
	assert(LogLevel.OFF == LogLevel.off, "OFF should alias off")
	assert(logger.get_level_name(LogLevel.debug) == "DEBUG", "get_level_name should return DEBUG")
	assert(logger.get_level_name(LogLevel.info) == "INFO", "get_level_name should return INFO")
	assert(logger.get_level_name(LogLevel.warn) == "WARN", "get_level_name should return WARN")
	assert(logger.get_level_name(LogLevel.error) == "ERROR", "get_level_name should return ERROR")
	assert(logger.get_level_name(LogLevel.fatal) == "FATAL", "get_level_name should return FATAL")
	local status, err = pcall(function() logger.get_level_name("info") end)
	assert(not status and string.find(err, "invalid log level"), "get_level_name should fail on bad level")
	status, err = pcall(function() logger.get_level_name(5) end)
	assert(not status and string.find(err, "invalid log level"), "get_level_name should fail below debug")

	-- LogRecord construction and validation
	local record = LogRecord.new(LogLevel.info, "hello")
	assert(record.level == LogLevel.info, "record should keep its level")
	assert(record.level_name == "INFO", "record should resolve its level name")
	assert(record.message == "hello", "record should keep its message")
	assert(type(record.timestamp) == "number", "record should default its timestamp")
	assert(record.logger_name == "", "record should default to an empty logger name")
	assert(next(record.context) == nil, "record should default to an empty context")
	local stamped = LogRecord.new(LogLevel.warn, "m", { a = 1 }, "named", 12345)
	assert(stamped.timestamp == 12345, "record should keep an explicit timestamp")
	assert(stamped.logger_name == "named", "record should keep its logger name")
	assert(stamped.context.a == 1, "record should snapshot its context")
	status, err = pcall(function() LogRecord.new(5, "m") end)
	assert(not status and string.find(err, "invalid log level"), "LogRecord should fail on bad level")
	status, err = pcall(function() LogRecord.new(LogLevel.info, 42) end)
	assert(not status and string.find(err, "must be a string"), "LogRecord should fail on non-string message")
	status, err = pcall(function() LogRecord.new(LogLevel.info, "m", "nope") end)
	assert(not status and string.find(err, "must be a table"), "LogRecord should fail on non-table context")
	-- Context is defensively copied
	local ctx = { nested = { x = 1 } }
	local guarded = LogRecord.new(LogLevel.info, "m", ctx, "n")
	ctx.nested.x = 99
	assert(guarded.context.nested.x == 1, "record context should be a defensive copy")
	-- Clone is independent
	local clone = guarded:clone()
	assert(clone.level == guarded.level and clone.message == guarded.message, "clone should copy fields")
	assert(clone.timestamp == guarded.timestamp, "clone should copy the timestamp")
	clone.context.nested.x = 7
	assert(guarded.context.nested.x == 1, "clone context should be independent")
	-- Tostring with and without context
	local plain = tostring(LogRecord.new(LogLevel.error, "boom", nil, "svc"))
	assert(string.find(plain, "ERROR", 1, true), "tostring should include the level name")
	assert(string.find(plain, "svc", 1, true), "tostring should include the logger name")
	assert(string.find(plain, "boom", 1, true), "tostring should include the message")
	local with_ctx = tostring(LogRecord.new(LogLevel.info, "m", { k = "v" }, "n"))
	assert(string.find(with_ctx, "{", 1, true), "tostring should serialize a non-empty context")
	-- Cycles and sorted keys
	local cyclic = {}
	cyclic.self = cyclic
	local cyclic_text = tostring(LogRecord.new(LogLevel.info, "m", cyclic, "n"))
	assert(string.find(cyclic_text, "<cycle>", 1, true), "tostring should report cycles")
	local ordered = tostring(LogRecord.new(LogLevel.info, "m", { b = 2, a = 1 }, "n"))
	local pos_a = string.find(ordered, '"a"=1', 1, true)
	local pos_b = string.find(ordered, '"b"=2', 1, true)
	assert(pos_a and pos_b and pos_a < pos_b, "tostring should sort context keys")

	-- PatternFormatter
	local formatter = PatternFormatter.new()
	local formatted = formatter:format(LogRecord.new(LogLevel.info, "hello", nil, "n"))
	assert(string.find(formatted, "[INFO]", 1, true), "default pattern should include the level")
	assert(string.find(formatted, "n:", 1, true), "default pattern should include the logger name")
	assert(string.find(formatted, "hello", 1, true), "default pattern should include the message")
	assert(formatter:set_pattern("%m") == formatter, "set_pattern should return self")
	assert(formatter:get_pattern() == "%m", "get_pattern should return the pattern")
	assert(formatter:format(LogRecord.new(LogLevel.info, "hi", nil, "n")) == "hi", "custom pattern should render")
	assert(formatter:format(LogRecord.new(LogLevel.info, "m", nil, "n")) ~= nil, "format should return a string")
	local pct = PatternFormatter.new("100%%")
	assert(pct:format(LogRecord.new(LogLevel.info, "m", nil, "n")) == "100%", "%% should render a literal percent")
	local unknown = PatternFormatter.new("%m%Q")
	assert(unknown:format(LogRecord.new(LogLevel.info, "m", nil, "n")) == "m%Q",
		"unknown tokens should pass through when not strict")
	local strict = PatternFormatter.new("%Q", nil, nil, true)
	status, err = pcall(function() strict:format(LogRecord.new(LogLevel.info, "m", nil, "n")) end)
	assert(not status and string.find(err, "unknown logger pattern token: %Q", 1, true),
		"strict formatter should fail on unknown tokens")
	formatter:set_token("Q", function() return "Q!" end)
	assert(formatter:get_pattern() == "%m", "set_token should not touch the pattern")
	local custom = PatternFormatter.new("%Q")
	custom:set_token("Q", function(record) return record.message .. "!" end)
	assert(custom:format(LogRecord.new(LogLevel.info, "hey", nil, "n")) == "hey!",
		"custom token should render via its handler")
	custom:remove_token("Q")
	assert(custom:format(LogRecord.new(LogLevel.info, "hey", nil, "n")) == "%Q",
		"removed token should pass through literally")
	status, err = pcall(function() formatter:set_token("QQ", function() end) end)
	assert(not status, "set_token should fail on multi-character tokens")
	status, err = pcall(function() formatter:set_token("!", function() end) end)
	assert(not status, "set_token should fail on non-alphanumeric tokens")
	status, err = pcall(function() formatter:set_token("Q", "nope") end)
	assert(not status, "set_token should fail on non-function handlers")
	status, err = pcall(function() formatter:remove_token("QQ") end)
	assert(not status, "remove_token should fail on multi-character tokens")
	status, err = pcall(function() formatter:set_pattern(42) end)
	assert(not status, "set_pattern should fail on non-string patterns")
	status, err = pcall(function() formatter:set_date_format(42) end)
	assert(not status, "set_date_format should fail on non-string formats")
	status, err = pcall(function() formatter:set_context_max_depth(-1) end)
	assert(not status, "set_context_max_depth should fail on negative depth")
	local shallow = PatternFormatter.new(nil, nil, 0)
	local deep_text = shallow:format(LogRecord.new(LogLevel.info, "m", { a = 1 }, "n"))
	assert(string.find(deep_text, "<max-depth>", 1, true), "depth 0 should report max-depth")
	assert(string.find(tostring(formatter), "PatternFormatter<", 1, true),
		"formatter tostring should identify itself")
	status, err = pcall(function() formatter:set_strict_patterns("yes") end)
	assert(not status, "set_strict_patterns should fail on non-boolean values")

	-- Appender base behaviour
	local base = MemoryAppender.new()
	assert(base:get_level() == LogLevel.debug, "appender should default to debug level")
	assert(base:set_level(LogLevel.warn) == base, "set_level should return self")
	assert(base:get_level() == LogLevel.warn, "appender should keep its level")
	assert(base:is_enabled(LogLevel.error), "error should be enabled above warn")
	assert(not base:is_enabled(LogLevel.info), "info should be disabled below warn")
	status, err = pcall(function() base:set_level("high") end)
	assert(not status and string.find(err, "invalid log level"), "set_level should fail on bad level")

	-- ConsoleAppender with a fake stream
	local chunks = {}
	local flushes = 0
	local fake = {
		write = function(self, s) chunks[#chunks + 1] = s end,
		flush = function(self) flushes = flushes + 1 end,
	}
	local console = ConsoleAppender.new(fake)
	console:append("hi", LogRecord.new(LogLevel.info, "hi", nil, "n"))
	assert(chunks[1] == "hi" and chunks[2] == "\n", "console should write message plus newline")
	assert(flushes == 1, "console should flush after each write by default")
	local quiet_chunks = {}
	local quiet = {
		write = function(self, s) quiet_chunks[#quiet_chunks + 1] = s end,
		flush = function(self) error("should not flush") end,
	}
	ConsoleAppender.new(quiet, nil, false):append("hi", LogRecord.new(LogLevel.info, "hi", nil, "n"))
	assert(quiet_chunks[1] == "hi", "console should write without flushing when disabled")
	status, err = pcall(function() ConsoleAppender.new({}) end)
	assert(not status and string.find(err, ":write%(%)"), "console should fail without :write()")

	-- FileAppender against a temp file
	local tmp = (os.getenv("TEMP") or ".") .. "/logger_test_tmp.log"
	local file_appender, open_err = FileAppender.new(tmp, "w")
	assert(file_appender, "file appender should open: " .. tostring(open_err))
	assert(not file_appender:is_closed(), "file appender should start open")
	assert(string.find(tostring(file_appender), "FileAppender<", 1, true),
		"file appender tostring should identify itself")
	assert(string.find(tostring(file_appender), "open", 1, true), "tostring should report open state")
	file_appender:append("line", LogRecord.new(LogLevel.info, "line", nil, "n"))
	assert(file_appender:close(), "close should succeed")
	assert(file_appender:is_closed(), "appender should report closed")
	assert(string.find(tostring(file_appender), "closed", 1, true), "tostring should report closed state")
	assert(file_appender:close(), "second close should succeed")
	status, err = pcall(function() file_appender:append("x", LogRecord.new(LogLevel.info, "x", nil, "n")) end)
	assert(not status and string.find(err, "closed file appender", 1, true),
		"append should fail after close")
	local bad_appender, bad_err = FileAppender.new(tmp .. "_missing_dir_xyz/log.log", "w")
	assert(bad_appender == nil and type(bad_err) == "string", "new should return nil plus error on bad path")
	status, err = pcall(function() FileAppender.open(tmp .. "_missing_dir_xyz/log.log", "w") end)
	assert(not status and string.find(err, "failed to open log file", 1, true),
		"open should raise on bad path")
	local disk = io.open(tmp, "r")
	local content = disk:read("*a")
	disk:close()
	assert(string.find(content, "line", 1, true), "appender should persist written lines")
	os.remove(tmp)

	-- MemoryAppender capture semantics
	local mem = MemoryAppender.new()
	local logged = LogRecord.new(LogLevel.info, "m", { v = 1 }, "n")
	mem:append("fmt", logged)
	logged.context.v = 99
	assert(mem:get_count() == 1, "memory appender should store one record")
	assert(mem:get_records()[1].message == "fmt", "memory appender should keep the message")
	assert(mem:get_records()[1].record.context.v == 1, "stored record should be an isolated clone")
	local snapshot = mem:get_records()
	snapshot[1] = nil
	assert(mem:get_count() == 1, "get_records should return a copy")
	mem:clear()
	assert(mem:get_count() == 0, "clear should discard captured records")

	-- Logger construction and levels
	status, err = pcall(function() Logger.new("") end)
	assert(not status, "logger should fail on empty name")
	status, err = pcall(function() Logger.new("x", {}) end)
	assert(not status, "logger should fail on bad formatter")
	local parent_log = Logger.new("lvl.parent")
	parent_log:set_level(LogLevel.warn)
	local child_log = Logger.new("lvl.child", nil, parent_log)
	assert(child_log:get_local_level() == nil, "child should have no local level by default")
	assert(child_log:get_effective_level() == LogLevel.warn, "child should inherit its level")
	assert(child_log:get_level() == LogLevel.warn, "get_level should match the effective level")
	child_log:set_level(LogLevel.error)
	assert(child_log:get_effective_level() == LogLevel.error, "local level should win over inherited")
	child_log:set_level(nil)
	assert(child_log:get_local_level() == nil, "set_level(nil) should clear the local level")
	status, err = pcall(function() child_log:set_level(5) end)
	assert(not status, "set_level should fail on bad level")
	assert(child_log:is_enabled(LogLevel.error), "error should be enabled above warn")
	assert(not child_log:is_enabled(LogLevel.info), "info should be disabled below warn")
	assert(Logger.new("plain"):get_effective_level() == LogLevel.debug, "default level should be debug")
	-- Formatter accessors
	assert(child_log:get_formatter() ~= nil, "logger should default to a formatter")
	status, err = pcall(function() child_log:set_formatter({}) end)
	assert(not status, "set_formatter should fail on bad formatter")
	-- Parent assignment guards
	status, err = pcall(function() child_log:set_parent(child_log) end)
	assert(not status and string.find(err, "own parent"), "logger cannot be its own parent")
	local loop_a = Logger.new("loop.a")
	local loop_b = Logger.new("loop.b", nil, loop_a)
	status, err = pcall(function() loop_a:set_parent(loop_b) end)
	assert(not status and string.find(err, "cycle"), "parent assignment should fail on cycles")
	assert(child_log:get_parent() == parent_log, "get_parent should return the parent")
	assert(child_log:is_additive(), "logger should be additive by default")
	assert(child_log:set_additive(false) == child_log, "set_additive should return self")
	assert(not child_log:is_additive(), "additive flag should toggle")
	status, err = pcall(function() child_log:set_additive("yes") end)
	assert(not status, "set_additive should fail on non-boolean values")
	child_log:set_additive(true)
	-- Appender management
	local managed = MemoryAppender.new()
	assert(child_log:add_appender(managed) == managed, "add_appender should return the appender")
	assert(child_log:has_appender(managed), "has_appender should find the appender")
	assert(not child_log:has_appender(MemoryAppender.new()), "has_appender should miss unknown appenders")
	local listed = child_log:get_appenders()
	assert(#listed == 1 and listed[1] == managed, "get_appenders should list attached appenders")
	listed[1] = nil
	assert(#child_log:get_appenders() == 1, "get_appenders should return a copy")
	assert(child_log:remove_appender(managed), "remove_appender should detach")
	assert(not child_log:remove_appender(managed), "second remove should report false")
	status, err = pcall(function() child_log:add_appender({}) end)
	assert(not status, "add_appender should fail on bad appenders")
	child_log:add_appender(managed)
	child_log:clear_appenders()
	assert(#child_log:get_appenders() == 0, "clear_appenders should detach everything")
	-- Appender error handler
	local seen = {}
	local function boom() error("boom") end
	child_log:add_appender({ append = boom })
	child_log:set_appender_error_handler(function(lg, app, msg, rec)
		seen.logger, seen.app, seen.msg, seen.rec = lg, app, msg, rec
	end)
	assert(child_log:log(LogLevel.error, "kaboom"), "log should survive appender failure")
	assert(seen.logger == child_log, "handler should receive the logger")
	assert(type(seen.app) == "table", "handler should receive the appender")
	assert(string.find(seen.msg, "boom", 1, true), "handler should receive the error message")
	assert(seen.rec.message == "kaboom", "handler should receive the record")
	child_log:set_appender_error_handler(nil)
	assert(child_log:log(LogLevel.error, "quiet"), "log should survive failure without a handler")
	status, err = pcall(function() child_log:set_appender_error_handler("nope") end)
	assert(not status, "error handler should fail on non-function values")
	child_log:clear_appenders()
	-- Emission paths
	local sink = MemoryAppender.new()
	child_log:add_appender(sink)
	child_log:set_level(LogLevel.warn)
	assert(not child_log:log(LogLevel.info, "skipped"), "filtered log should return false")
	assert(sink:get_count() == 0, "filtered log should emit nothing")
	local lazy_calls = 0
	assert(child_log:log(LogLevel.error, function()
		lazy_calls = lazy_calls + 1
		return "lazy"
	end), "enabled log should return true")
	assert(lazy_calls == 1, "lazy message should be evaluated once")
	assert(sink:get_records()[1].record.message == "lazy", "lazy message should be stored")
	lazy_calls = 0
	assert(not child_log:log(LogLevel.info, function()
		lazy_calls = lazy_calls + 1
		return "never"
	end), "filtered lazy log should return false")
	assert(lazy_calls == 0, "filtered lazy message should not be evaluated")
	assert(child_log:log(LogLevel.error, 42), "non-string message should be accepted")
	assert(sink:get_records()[2].record.message == "42", "non-string message should be coerced")
	status, err = pcall(function() child_log:log(LogLevel.error, "m", "nope") end)
	assert(not status and string.find(err, "must be a table"), "log should fail on non-table context")
	assert(child_log:logf(LogLevel.error, "n=%d", 7), "logf should emit")
	assert(sink:get_records()[3].record.message == "n=7", "logf should format its message")
	status, err = pcall(function() child_log:logf(LogLevel.error, "%d", {}) end)
	assert(not status, "logf should propagate format errors")
	status, err = pcall(function() child_log:logf(LogLevel.error, 42) end)
	assert(not status, "logf should fail on non-string format")
	child_log:set_level(LogLevel.debug)
	assert(child_log:debug("d"), "debug should emit")
	assert(child_log:info("i", { a = 1 }), "info should emit with context")
	assert(child_log:warn("w"), "warn should emit")
	assert(child_log:error("e"), "error should emit")
	assert(child_log:fatal("f"), "fatal should emit")
	assert(string.find(tostring(child_log), "Logger<lvl.child, level=DEBUG>", 1, true),
		"logger tostring should identify itself")
	child_log:clear_appenders()

	-- Appender-level filtering and propagation
	local root_mem = MemoryAppender.new()
	local root_log = LogManager.get_root()
	root_log:clear_appenders()
	root_log:add_appender(root_mem)
	local picky = MemoryAppender.new(LogLevel.error)
	local prop_log = LogManager.get_logger("prop.child")
	prop_log:clear_appenders()
	prop_log:add_appender(picky)
	assert(prop_log:log(LogLevel.info, "filtered"), "log below appender level should still return true")
	assert(picky:get_count() == 0, "appender should filter below its own level")
	assert(root_mem:get_count() == 1, "record should propagate to the root appender")
	assert(prop_log:log(LogLevel.error, "kept"), "error should emit")
	assert(picky:get_count() == 1, "appender should keep accepted records")
	assert(root_mem:get_count() == 2, "accepted record should propagate too")
	prop_log:set_additive(false)
	assert(prop_log:log(LogLevel.error, "local"), "non-additive log should emit")
	assert(picky:get_count() == 2, "local appenders should still fire")
	assert(root_mem:get_count() == 2, "non-additive logger should not propagate")
	prop_log:set_additive(true)
	root_log:clear_appenders()
	LogManager.remove_logger("prop.child", true)

	-- ContextLogger merging and delegation
	local base_mem = MemoryAppender.new()
	local base_log = Logger.new("ctx.base")
	base_log:add_appender(base_mem)
	local bound = ContextLogger.new(base_log, { a = 1, b = 1 })
	assert(bound:log(LogLevel.info, "m", { b = 2 }), "context log should emit")
	local merged = base_mem:get_records()[1].record.context
	assert(merged.a == 1 and merged.b == 2, "call context should win over bound context")
	assert(bound:log(LogLevel.info, "m2"), "log without context should emit")
	assert(base_mem:get_records()[2].record.context.a == 1, "bound context should apply alone")
	local empty_bound = ContextLogger.new(base_log, {})
	assert(empty_bound:log(LogLevel.info, "m3"), "empty base log should emit")
	assert(next(base_mem:get_records()[3].record.context) == nil, "empty contexts should stay empty")
	base_log:set_level(LogLevel.fatal)
	assert(not bound:log(LogLevel.info, "muted"), "disabled context log should return false")
	base_log:set_level(LogLevel.debug)
	assert(bound:logf(LogLevel.info, "v=%d", 3), "context logf should emit")
	assert(base_mem:get_records()[4].record.message == "v=3", "context logf should format")
	local derived = bound:with_context({ c = 3 })
	assert(derived:log(LogLevel.info, "m"), "derived log should emit")
	local dctx = base_mem:get_records()[5].record.context
	assert(dctx.a == 1 and dctx.c == 3, "with_context should merge over the base")
	status, err = pcall(function() ContextLogger.new("nope", {}) end)
	assert(not status, "ContextLogger should fail without a base logger")
	status, err = pcall(function() ContextLogger.new(base_log, "nope") end)
	assert(not status, "ContextLogger should fail on non-table context")
	status, err = pcall(function() bound:with_context("nope") end)
	assert(not status, "with_context should fail on non-table context")
	assert(bound:get_logger() == base_log, "get_logger should return the base logger")
	bound:set_level(LogLevel.error)
	assert(base_log:get_local_level() == LogLevel.error, "set_level should delegate")
	assert(bound:get_level() == LogLevel.error, "get_level should delegate")
	assert(bound:get_formatter() == base_log:get_formatter(), "get_formatter should delegate")
	assert(bound:is_additive() == base_log:is_additive(), "is_additive should delegate")
	base_log:set_level(nil)
	assert(string.find(tostring(bound), "ContextLogger<ctx.base>", 1, true),
		"facade tostring should identify itself")
	-- Logger:with_context entry point
	local via_logger = base_log:with_context({ z = 9 })
	assert(via_logger:log(LogLevel.info, "m"), "logger facade should emit")
	assert(base_mem:get_records()[6].record.context.z == 9, "logger facade should bind context")

	-- LogManager hierarchy and maintenance
	local leaf = LogManager.get_logger("lm.sub.leaf")
	assert(leaf.name == "lm.sub.leaf", "managed logger should keep its name")
	assert(leaf:get_parent().name == "lm.sub", "leaf should parent to lm.sub")
	assert(leaf:get_parent():get_parent().name == "lm", "hierarchy should nest")
	assert(leaf:get_parent():get_parent():get_parent().name == "root", "hierarchy should reach root")
	assert(LogManager.get_logger("lm.sub.leaf") == leaf, "get_logger should cache instances")
	status, err = pcall(function() LogManager.get_logger("") end)
	assert(not status, "get_logger should fail on empty names")
	local listed_all = LogManager.get_loggers()
	for i = 2, #listed_all do
		assert(listed_all[i - 1].name <= listed_all[i].name, "get_loggers should sort by name")
	end
	assert(not LogManager.remove_logger("root"), "root should be protected")
	assert(not LogManager.remove_logger("lm.nope"), "missing logger should report false")
	assert(not LogManager.remove_logger("lm"), "parent with children should block removal")
	assert(not LogManager.remove_logger("lm", false), "explicit non-recursive should block removal")
	local stale = leaf
	assert(LogManager.remove_logger("lm", true), "recursive removal should succeed")
	assert(LogManager.get_logger("lm.sub.leaf") ~= stale, "removed loggers should be recreated")
	LogManager.remove_logger("lm", true)
	-- Configuration entry points
	local root_before = LogManager.get_root()
	assert(logger.get_root_logger() == root_before, "get_root_logger should return root")
	assert(logger.get_logger("lm.cfg") == LogManager.get_logger("lm.cfg"), "module get_logger should delegate")
	status, err = pcall(function() LogManager.configure("nope") end)
	assert(not status, "configure should fail on non-table configs")
	status, err = pcall(function() LogManager.configure({ appenders = "nope" }) end)
	assert(not status, "configure should fail on non-table appenders")
	local cfg_mem = MemoryAppender.new()
	logger.configure({ level = LogLevel.error, appenders = { cfg_mem } })
	assert(root_before:get_effective_level() == LogLevel.error, "configure should set the root level")
	assert(#root_before:get_appenders() == 1, "configure should replace root appenders")
	assert(logger.configure({ level = LogLevel.debug }) == root_before, "configure should return root")
	root_before:clear_appenders()
	root_before:set_level(LogLevel.debug)
	LogManager.remove_logger("lm", true)
	print("All tests passed")
end
