-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Portable shell/file/search utilities for LuaJIT/5.1+ and later.
--
-- Features:
-- * `os.execute` wrapper with portable stdout/stderr capture via temp files.
-- * Shell quoting for Windows (`cmd.exe`) and POSIX shells.
-- * Command discovery with caching (`command_exists`).
-- * Directory listing (`list`) and ripgrep-backed file enumeration (`find_files`).
-- * Content search via ripgrep/grep (`search`) with match parsing.
-- * File operations (`exists`, `is_file`, `is_directory`, `mkdir`, `remove`, `copy`, `move`).
-- * In-place text replacement via `sd`/`sed` (`replace`, `replace_all`).
-- * Small file helpers (`read_file`, `write_file`) and diagnostics (`get_capabilities`, `describe`).
--
-- Usage example:
-- ```
-- local io_shell = require "standalone/io_shell"
-- local result = io_shell.execute("echo hello")
-- print(result.stdout)
-- local files = io_shell.find_files(".", { pattern = "*.lua" })
-- ```

-- Localized global functions for better performance
local error = error
local ipairs = ipairs
local pairs = pairs
local pcall = pcall
local tonumber = tonumber
local tostring = tostring
local type = type
local io_open = io and io.open
local io_popen = io and io.popen
local os_execute = os and os.execute
local os_remove = os and os.remove
local os_tmpname = os and os.tmpname
local string_find = string.find
local string_format = string.format
local string_gmatch = string.gmatch
local string_gsub = string.gsub
local string_match = string.match
local string_sub = string.sub
local table_concat = table.concat

----------------------------------------------------------------------
-- Types
----------------------------------------------------------------------

---@class io_shell.Options
---@field cwd? string Working directory used for `cd` before running the command (default: current directory).
---@field timeout? number Currently informational; `os.execute` itself cannot enforce a timeout.
---@field env? table<string, string> Environment variables prepended to the command.
---@field capture_stderr? boolean Capture stderr separately (default: true).
---@field raise_on_error? boolean Raise a Lua error when the command fails (default: false).

---@class io_shell.Result
---@field success boolean True when the command exited with code 0.
---@field code? number Process exit code when known, otherwise nil.
---@field stdout string Captured standard output (empty string when nothing was captured).
---@field stderr string Captured standard error (empty string when not captured).
---@field command string The full command string that was executed, including `cd`/env/redirection wrappers.

---@class io_shell.ListOptions
---@field recursive? boolean Recursively enumerate (default: false).
---@field hidden? boolean Include hidden files where supported (default: false).
---@field absolute? boolean Reserved; currently unused, paths are returned as reported by the backend.
---@field directories_only? boolean Return directories only (default: false).
---@field files_only? boolean Return files only (default: false).
---@field pattern? string Optional filename pattern/glob (e.g. "*.lua").
---@field cwd? string Reserved; currently unused, pass the directory via `path` instead.

---@class io_shell.SearchOptions
---@field recursive? boolean Reserved; `rg`/`grep` always recurse (default: true).
---@field hidden? boolean Include hidden files (default: false).
---@field ignore_case? boolean Case-insensitive matching (default: false).
---@field fixed_string? boolean Treat pattern as a literal string rather than regex (default: false).
---@field file_pattern? string Restrict files using a glob such as "*.lua".
---@field max_count? number Maximum matches per file.
---@field context_before? number Lines of context before each match (ripgrep only).
---@field context_after? number Lines of context after each match (ripgrep only).
---@field cwd? string Reserved; currently unused, pass the directory via `path` instead.
---@field include? string|string[] Additional file globs.
---@field exclude? string|string[] Excluded file globs.

---@class io_shell.Match
---@field file string File path containing the match (empty string when unparseable).
---@field line? number 1-based line number when known, otherwise nil.
---@field text string Matched line text (or raw output line when unparseable).
---@field column? number Reserved for future use; currently always nil.

--- Portable shell/file/search helpers.<br>
--- Namespace table holding all public `io_shell.*` functions.
---@class io_shell
local io_shell = {}

----------------------------------------------------------------------
-- Platform detection
----------------------------------------------------------------------

---@alias io_shell.OS "windows"|"linux"|"macos"|"bsd"|"unix"|"unknown"

--- Detected operating system identifier.
---@type io_shell.OS
local detected_os = "unknown"

do
	-- NOTE: sandboxed hosts (e.g. nanos-world without '--enable_unsafe_libs')
	-- replace unsafe functions such as io.popen with stubs that throw
	-- "Called a disabled unsafe function." when invoked. This probe must
	-- therefore never call them directly; everything is pcall-guarded and
	-- degrades to "unknown"/"unix" instead of failing the require.
	local sep
	if type(package) == "table" then
		local ok, res = pcall(function()
			if package.config then return string_sub(package.config, 1, 1) end
		end)
		if ok then sep = res end
	end

	if sep == "\\" then
		detected_os = "windows"
	elseif sep == "/" then
		-- Lua does not expose a completely portable OS identifier.
		-- uname is therefore used when available.
		local uname
		if type(io_popen) == "function" then
			local ok, pipe = pcall(io_popen, "uname -s 2>/dev/null")
			if ok and pipe then
				local ok2, name = pcall(function() return pipe:read("*l") end)
				pcall(function() pipe:close() end)
				if ok2 then uname = name end
			end
		end

		if uname then
			local name = string_gsub(uname, "%s+$", "")

			if name == "Linux" then
				detected_os = "linux"
			elseif name == "Darwin" then
				detected_os = "macos"
			elseif string_find(name, "BSD", 1, true) then
				detected_os = "bsd"
			else
				detected_os = "unix"
			end
		else
			detected_os = "unix"
		end
	end
end

--- Return the detected operating system.
---@return io_shell.OS os Operating system identifier (`"windows"`, `"linux"`, `"macos"`, `"bsd"`, `"unix"` or `"unknown"`).
---@usage <br>
--- ```
--- local io_shell = require "standalone/io_shell"
--- print(io_shell.get_os()) -- "windows" | "linux" | ...
--- ```
function io_shell.get_os()
	return detected_os
end

--- Whether the current OS is Windows.
---@return boolean is_windows True when the detected OS is `"windows"`.
---@usage <br>
--- ```
--- if io_shell.is_windows() then
---   print("running on cmd.exe")
--- end
--- ```
function io_shell.is_windows()
	return detected_os == "windows"
end

--- Whether the current OS is Unix-like.<br>
--- Returns true for `"linux"`, `"macos"`, `"bsd"` and `"unix"`;
--- returns false for `"windows"` and `"unknown"`.
---@return boolean is_unix True when the OS is Unix-like.
---@usage <br>
--- ```
--- if io_shell.is_unix() then
---   print("POSIX shell available")
--- end
--- ```
function io_shell.is_unix()
	return detected_os ~= "windows" and detected_os ~= "unknown"
end

----------------------------------------------------------------------
-- Shell quoting
----------------------------------------------------------------------

--- Quote an argument for the current command shell.<br>
--- This is intended for paths, filenames, patterns, etc.<br>
--- Do not pass an entire command through this function.
---@param value string The raw argument value to quote.
---@return string quoted Shell-quoted argument (double quotes on Windows, single quotes on POSIX).
---@usage <br>
--- ```
--- local cmd = "ls " .. io_shell.quote("my dir/file.lua")
--- local result = io_shell.execute(cmd)
--- ```
function io_shell.quote(value)
	value = tostring(value)

	if io_shell.is_windows() then
		-- cmd.exe quoting.
		--
		-- Double quotes protect spaces and the majority of shell
		-- metacharacters. Percent expansion and delayed expansion are
		-- shell-level features that cannot be completely neutralized
		-- without controlling the environment.
		value = string_gsub(value, '"', '\\"')

		return '"' .. value .. '"'
	end

	-- POSIX shell single-quote escaping:
	--
	-- abc'def -> 'abc'\''def'
	return "'" .. string_gsub(value, "'", "'\\''") .. "'"
end

----------------------------------------------------------------------
-- Utility helpers
----------------------------------------------------------------------

--- Convert an environment value to a shell-safe string.<br>
--- `nil` becomes an empty string; everything else goes through `tostring`.
---@param value any The environment value to stringify.
---@return string str Empty string for nil, otherwise `tostring(value)`.
local function shell_value(value)
	if value == nil then
		return ""
	end

	return tostring(value)
end

--- Strip carriage returns and drop empty lines.<br>
--- Used to normalize captured `dir`/`ls`/`rg` output.
---@param lines string[] Raw split lines.
---@return string[] result Cleaned lines with `"\r"` removed and empty entries dropped.
local function trim_lines(lines)
	local result = {}

	for i = 1, #lines do
		local line = lines[i]

		-- Remove CR from CRLF output.
		line = string_gsub(line, "\r$", "")

		if line ~= "" then
			result[#result + 1] = line
		end
	end

	return result
end

--- Split captured output into lines.<br>
--- Splits on `"\r"` and `"\n"`; empty input yields an empty array.
---@param text string Captured stdout/stderr text.
---@return string[] lines Array of lines without line breaks.
local function split_lines(text)
	local lines = {}

	for line in string_gmatch(text, "[^\r\n]+") do
		lines[#lines + 1] = line
	end

	return lines
end

--- Normalize path separators for the current OS.<br>
--- Converts `"/"` to `"\\"` on Windows and `"\\"` to `"/"` elsewhere.
---@param path string The path to normalize.
---@return string normalized OS-specific path.
local function normalize_path(path)
	if io_shell.is_windows() then
		return (string_gsub(path, "/", "\\"))
	end

	return (string_gsub(path, "\\", "/"))
end

--- Read the entire contents of a file.
---@param path string File path to read.
---@return string? content File contents on success, otherwise nil.
---@return string? error_message Error message on failure, otherwise nil.
---@usage <br>
--- ```
--- local content, err = io_shell.read_file("config.lua")
--- if not content then print("read failed:", err) end
--- ```
function io_shell.read_file(path)
	local file, err = io_open(path, "rb")

	if not file then
		return nil, err
	end

	local content = file:read("*a")
	file:close()

	return content
end

--- Write an entire file.
---@param path string File path to write.
---@param content string Full file contents to store.
---@return boolean success True when the write succeeded.
---@return string? error_message Error message on failure, otherwise nil.
---@usage <br>
--- ```
--- local ok, err = io_shell.write_file("out.txt", "hello")
--- ```
function io_shell.write_file(path, content)
	local file, err = io_open(path, "wb")

	if not file then
		return false, err
	end

	local ok, write_err = file:write(content)

	file:close()

	if not ok then
		return false, write_err
	end

	return true
end

----------------------------------------------------------------------
-- os.execute wrapper
----------------------------------------------------------------------

--- Normalize the highly version-dependent `os.execute` return values.<br>
--- Handles Lua 5.1/LuaJIT numeric status as well as the Lua 5.2+ `true, "exit", code` triple form.
---@param a any First `os.execute` return value.
---@param b any Second `os.execute` return value.
---@param c any Third `os.execute` return value (numeric exit code on 5.2+).
---@return boolean success True when the exit code is 0.
---@return number? code Numeric exit code when known, otherwise nil.
local function normalize_execute_result(a, b, c)
	-- Lua 5.1 / LuaJIT generally:
	--
	--   number -> implementation-specific exit status
	--
	-- Lua 5.2+:
	--
	--   true, "exit", 0
	--   nil, "exit", 1
	--
	if type(a) == "number" then
		return a == 0, a
	end

	if a == true then
		return true, 0
	end

	if c ~= nil then
		return false, tonumber(c)
	end

	return false, nil
end

--- Execute a command and capture stdout/stderr.<br>
--- Output is captured through temporary files because Lua's standard `os.execute` does not provide portable stdout capture.
---@param command string Shell command to run (without output redirection; it is added internally).
---@param options? io_shell.Options Execution options (default: {}).
---@return io_shell.Result result Result table with `success`, `code`, `stdout`, `stderr` and `command`.
---@usage <br>
--- ```
--- local result = io_shell.execute("echo hello")
--- print(result.success, result.code)
--- print(result.stdout)
---
--- local ok = io_shell.execute("exit 1", { raise_on_error = false })
--- ```
function io_shell.execute(command, options)
	options = options or {}

	local stdout_path = os_tmpname()
	local stderr_path = os_tmpname()

	local full_command = command

	if options.cwd then
		if io_shell.is_windows() then
			full_command =
				"cd /d " ..
				io_shell.quote(options.cwd) ..
				" && " ..
				full_command
		else
			full_command =
				"cd " ..
				io_shell.quote(options.cwd) ..
				" && " ..
				full_command
		end
	end

	if options.env then
		local prefix = {}

		for key, value in pairs(options.env) do
			if io_shell.is_windows() then
				prefix[#prefix + 1] =
					"set " ..
					key ..
					"=" ..
					shell_value(value)
			else
				prefix[#prefix + 1] =
					key ..
					"=" ..
					io_shell.quote(shell_value(value))
			end
		end

		if #prefix > 0 then
			if io_shell.is_windows() then
				full_command =
					table_concat(prefix, " && ") ..
					" && " ..
					full_command
			else
				full_command =
					table_concat(prefix, " ") ..
					" " ..
					full_command
			end
		end
	end

	local redirect =
		" > " ..
		io_shell.quote(stdout_path)

	if options.capture_stderr == false then
		redirect =
			redirect ..
			" 2> " ..
			io_shell.quote(stdout_path)
	else
		redirect =
			redirect ..
			" 2> " ..
			io_shell.quote(stderr_path)
	end

	local a, b, c = os_execute(full_command .. redirect)

	local success, code =
		normalize_execute_result(a, b, c)

	local stdout = ""
	local stderr = ""

	do
		local file = io_open(stdout_path, "rb")

		if file then
			stdout = file:read("*a") or ""
			file:close()
		end
	end

	if options.capture_stderr ~= false then
		local file = io_open(stderr_path, "rb")

		if file then
			stderr = file:read("*a") or ""
			file:close()
		end
	end

	os_remove(stdout_path)
	os_remove(stderr_path)

	local result = {
		success = success,
		code = code,
		stdout = stdout,
		stderr = stderr,
		command = full_command,
	}

	if not success and options.raise_on_error then
		return error(
			string_format(
				"command failed (%s): %s\n%s",
				tostring(code),
				full_command,
				stderr
			),
			2
		)
	end

	return result
end

----------------------------------------------------------------------
-- Command discovery
----------------------------------------------------------------------

--- Cached command-availability probes.
---@type table<string, boolean>
local command_cache = {}

--- Check whether an executable/command is available.<br>
--- The result is cached per command name for the process lifetime.
---@param command string Executable name to probe (e.g. `"rg"`, `"grep"`).
---@return boolean available True when the command was found on `PATH`.
---@usage <br>
--- ```
--- if io_shell.command_exists("rg") then
---   print("ripgrep available")
--- end
--- ```
function io_shell.command_exists(command)
	if command_cache[command] ~= nil then
		return command_cache[command]
	end

	local test_command

	if io_shell.is_windows() then
		test_command =
			"where " ..
			io_shell.quote(command) ..
			" >nul 2>nul"
	else
		test_command =
			"command -v " ..
			io_shell.quote(command) ..
			" >/dev/null 2>&1"
	end

	local a, b, c = os_execute(test_command)
	local success = normalize_execute_result(a, b, c)

	command_cache[command] = success

	return success
end

--- Choose the best available content-search backend.<br>
--- Prefers ripgrep (`rg`) and falls back to `grep`.
---@return string backend `"rg"`, `"grep"`, or `""` when neither is available.
local function choose_search_command()
	if io_shell.command_exists("rg") then
		return "rg"
	end

	if io_shell.command_exists("grep") then
		return "grep"
	end

	return ""
end

--- Choose the best available replacement backend.<br>
--- Prefers `sd` and falls back to `sed`.
---@return string backend `"sd"`, `"sed"`, or `""` when neither is available.
local function choose_replace_command()
	if io_shell.command_exists("sd") then
		return "sd"
	end

	if io_shell.command_exists("sed") then
		return "sed"
	end

	return ""
end

----------------------------------------------------------------------
-- Directory / file enumeration
----------------------------------------------------------------------

--- Build a Windows `dir` command.
---@param path string Directory to enumerate.
---@param options io_shell.ListOptions Listing options.
---@return string command Shell command string.
local function build_windows_list_command(path, options)
	local args = {
		"dir",
		"/b",
	}

	if options.files_only then
		args[#args + 1] = "/a-d"
	elseif options.directories_only then
		args[#args + 1] = "/ad"
	else
		args[#args + 1] = "/a"
	end

	if options.recursive then
		args[#args + 1] = "/s"
	end

	if options.pattern then
		path = path .. "\\" .. options.pattern
	end

	args[#args + 1] = io_shell.quote(path)

	return table_concat(args, " ")
end

--- Build a Unix `ls` command.
---@param path string Directory to enumerate.
---@param options io_shell.ListOptions Listing options.
---@return string command Shell command string.
local function build_unix_list_command(path, options)
	local args = {
		"ls",
		"-1",
	}

	if options.hidden then
		args[#args + 1] = "-A"
	end

	if options.directories_only then
		args[#args + 1] = "-d"
	end

	if options.recursive then
		args[#args + 1] = "-R"
	end

	args[#args + 1] = io_shell.quote(path)

	return table_concat(args, " ")
end

--- List files/directories.<br>
--- On Windows this uses `dir`; on Unix-like systems this uses `ls`.<br>
--- For reliable recursive file searches, prefer `find_files()`, which uses ripgrep when available.
---@param path? string Directory to list (default: ".").
---@param options? io_shell.ListOptions Listing options (default: {}).
---@return string[] entries Cleaned output lines.
---@return io_shell.Result result Raw execution result.
---@usage <br>
--- ```
--- local entries = io_shell.list(".")
--- local files = io_shell.list(".", { files_only = true })
--- ```
function io_shell.list(path, options)
	path = normalize_path(path or ".")
	options = options or {}

	local command

	if io_shell.is_windows() then
		command = build_windows_list_command(path, options)
	else
		command = build_unix_list_command(path, options)
	end

	local result = io_shell.execute(command)
	local entries = trim_lines(split_lines(result.stdout))

	return entries, result
end

--- List files only.<br>
--- Forces `files_only` and clears `directories_only` before delegating to `list()`.
---@param path? string Directory to list (default: ".").
---@param options? io_shell.ListOptions Listing options (default: {}).
---@return string[] entries Cleaned output lines.
---@return io_shell.Result result Raw execution result.
---@usage <br>
--- ```
--- local files = io_shell.list_files(".")
--- ```
function io_shell.list_files(path, options)
	options = options or {}

	local copy = {}

	for key, value in pairs(options) do
		copy[key] = value
	end

	copy.files_only = true
	copy.directories_only = false

	return io_shell.list(path, copy)
end

--- List directories only.<br>
--- Forces `directories_only` and clears `files_only` before delegating to `list()`.
---@param path? string Directory to list (default: ".").
---@param options? io_shell.ListOptions Listing options (default: {}).
---@return string[] entries Cleaned output lines.
---@return io_shell.Result result Raw execution result.
---@usage <br>
--- ```
--- local dirs = io_shell.list_directories(".")
--- ```
function io_shell.list_directories(path, options)
	options = options or {}

	local copy = {}

	for key, value in pairs(options) do
		copy[key] = value
	end

	copy.files_only = false
	copy.directories_only = true

	return io_shell.list(path, copy)
end

----------------------------------------------------------------------
-- ripgrep file enumeration
----------------------------------------------------------------------

--- Enumerate files with ripgrep.<br>
--- This is generally the preferred recursive file enumeration API.<br>
--- Falls back to `list_files()` when `rg` is unavailable.
---@param path? string Directory to enumerate (default: ".").
---@param options? io_shell.ListOptions Listing options (default: {}).
---@return string[] entries Cleaned file paths.
---@return io_shell.Result result Raw execution result.
---@usage <br>
--- ```
--- local files = io_shell.find_files(".", { pattern = "*.lua" })
--- ```
function io_shell.find_files(path, options)
	path = normalize_path(path or ".")
	options = options or {}

	if not io_shell.command_exists("rg") then
		return io_shell.list_files(path, options)
	end

	local args = {
		"rg",
		"--files",
	}

	if options.hidden then
		args[#args + 1] = "--hidden"
	end

	if options.pattern then
		args[#args + 1] = "--glob"
		args[#args + 1] = io_shell.quote(options.pattern)
	end

	args[#args + 1] = io_shell.quote(path)

	local result = io_shell.execute(table_concat(args, " "))

	return trim_lines(split_lines(result.stdout)), result
end

----------------------------------------------------------------------
-- Search
----------------------------------------------------------------------

--- Whether an optional boolean flag is explicitly enabled.
---@param value? boolean Flag value to test.
---@return boolean is_enabled True only when `value` is exactly `true`.
local function enabled(value)
	return value == true
end

--- Convert a glob collection to command arguments.
---@param value? string|string[] Single glob or array of globs.
---@param option string CLI flag to prepend before each glob (e.g. "--glob").
---@return string[] args Flat argument list with quoted globs.
local function make_glob_options(value, option)
	local args = {}

	if value == nil then
		return args
	end

	if type(value) == "string" then
		args[#args + 1] = option
		args[#args + 1] = io_shell.quote(value)

		return args
	end

	for _, pattern in ipairs(value) do
		args[#args + 1] = option
		args[#args + 1] = io_shell.quote(pattern)
	end

	return args
end

--- Search file contents using ripgrep or grep.<br>
--- The search pattern is a regex by default.<br>
--- Exit code 1 (no matches) is normalized to success with an empty match list.
---@param pattern string Regex (or literal when `fixed_string` is set) to search for.
---@param path? string Directory/file to search (default: ".").
---@param options? io_shell.SearchOptions Search options (default: {}).
---@return io_shell.Match[] matches Parsed `file:line:text` matches.
---@return io_shell.Result result Raw execution result.
---@usage <br>
--- ```
--- local matches = io_shell.search("TODO", ".", { file_pattern = "*.lua" })
--- for i = 1, #matches do
---   print(matches[i].file .. ":" .. tostring(matches[i].line))
--- end
--- ```
function io_shell.search(pattern, path, options)
	path = normalize_path(path or ".")
	options = options or {}

	local search_command = choose_search_command()

	if search_command == "" then
		return {}, {
			success = false,
			code = nil,
			stdout = "",
			stderr = "Neither rg nor grep is available.",
			command = "",
		}
	end

	local args = {}

	if search_command == "rg" then
		args[#args + 1] = "rg"
		args[#args + 1] = "--line-number"
		args[#args + 1] = "--with-filename"
		args[#args + 1] = "--no-heading"

		if enabled(options.ignore_case) then
			args[#args + 1] = "--ignore-case"
		end

		if enabled(options.fixed_string) then
			args[#args + 1] = "--fixed-strings"
		end

		if enabled(options.hidden) then
			args[#args + 1] = "--hidden"
		end

		if options.max_count then
			args[#args + 1] = "--max-count"
			args[#args + 1] = tostring(options.max_count)
		end

		if options.context_before then
			args[#args + 1] = "--before-context"
			args[#args + 1] = tostring(options.context_before)
		end

		if options.context_after then
			args[#args + 1] = "--after-context"
			args[#args + 1] = tostring(options.context_after)
		end

		local include_options =
			make_glob_options(options.include or options.file_pattern, "--glob")

		for i = 1, #include_options do
			args[#args + 1] = include_options[i]
		end

		local exclude_options =
			make_glob_options(options.exclude, "--glob")

		for i = 1, #exclude_options do
			args[#args + 1] = exclude_options[i]
		end

		args[#args + 1] = "-e"
		args[#args + 1] = io_shell.quote(pattern)
		args[#args + 1] = io_shell.quote(path)
	else
		-- grep fallback.
		args[#args + 1] = "grep"
		args[#args + 1] = "-R"
		args[#args + 1] = "-n"
		args[#args + 1] = "-H"

		if enabled(options.ignore_case) then
			args[#args + 1] = "-i"
		end

		if enabled(options.fixed_string) then
			args[#args + 1] = "-F"
		else
			args[#args + 1] = "-E"
		end

		if options.max_count then
			args[#args + 1] = "-m"
			args[#args + 1] = tostring(options.max_count)
		end

		args[#args + 1] = io_shell.quote(pattern)
		args[#args + 1] = io_shell.quote(path)
	end

	local result = io_shell.execute(table_concat(args, " "))

	-- rg/grep use exit code 1 to mean "no matches".
	if result.code == 1 then
		result.success = true
	end

	local matches = {}

	for line in string_gmatch(result.stdout, "[^\r\n]+") do
		-- rg:
		--
		-- file:line:text
		--
		-- This deliberately splits only the first two `:` characters
		-- so the actual source text may contain colons.
		local file, line_number, text =
			string_match(line, "^(.-):(%d+):(.*)$")

		if file then
			matches[#matches + 1] = {
				file = file,
				line = tonumber(line_number),
				text = text,
			}
		else
			-- grep can occasionally emit a slightly different form.
			matches[#matches + 1] = {
				file = "",
				line = nil,
				text = line,
			}
		end
	end

	return matches, result
end

--- Search a literal string.<br>
--- Forces `fixed_string` before delegating to `search()`.
---@param text string Literal text to search for.
---@param path? string Directory/file to search (default: ".").
---@param options? io_shell.SearchOptions Search options (default: {}).
---@return io_shell.Match[] matches Parsed matches.
---@return io_shell.Result result Raw execution result.
---@usage <br>
--- ```
--- local matches = io_shell.search_text("foo()", ".")
--- ```
function io_shell.search_text(text, path, options)
	options = options or {}

	local copy = {}

	for key, value in pairs(options) do
		copy[key] = value
	end

	copy.fixed_string = true

	return io_shell.search(text, path, copy)
end

--- Search a regular expression.<br>
--- Clears `fixed_string` before delegating to `search()`.
---@param pattern string Regex pattern to search for.
---@param path? string Directory/file to search (default: ".").
---@param options? io_shell.SearchOptions Search options (default: {}).
---@return io_shell.Match[] matches Parsed matches.
---@return io_shell.Result result Raw execution result.
---@usage <br>
--- ```
--- local matches = io_shell.search_regex("foo%s+bar", ".")
--- ```
function io_shell.search_regex(pattern, path, options)
	options = options or {}

	local copy = {}

	for key, value in pairs(options) do
		copy[key] = value
	end

	copy.fixed_string = false

	return io_shell.search(pattern, path, copy)
end

----------------------------------------------------------------------
-- Convenience search APIs
----------------------------------------------------------------------

--- Return whether a pattern occurs anywhere inside the selected files.
---@param pattern string Regex (or literal when `fixed_string` is set) to search for.
---@param path? string Directory/file to search (default: ".").
---@param options? io_shell.SearchOptions Search options (default: {}).
---@return boolean found True when at least one match was found.
---@return io_shell.Result result Raw execution result.
---@usage <br>
--- ```
--- local found = io_shell.contains("FIXME", ".")
--- ```
function io_shell.contains(pattern, path, options)
	local matches, result =
		io_shell.search(pattern, path, options)

	return #matches > 0, result
end

--- Count regex matches.
---@param pattern string Regex (or literal when `fixed_string` is set) to search for.
---@param path? string Directory/file to search (default: ".").
---@param options? io_shell.SearchOptions Search options (default: {}).
---@return number count Number of matches found.
---@return io_shell.Result result Raw execution result.
---@usage <br>
--- ```
--- local n = io_shell.count("TODO", ".")
--- ```
function io_shell.count(pattern, path, options)
	local matches, result =
		io_shell.search(pattern, path, options)

	return #matches, result
end

----------------------------------------------------------------------
-- File operations
----------------------------------------------------------------------

--- Check whether a path exists.
---@param path string File or directory path to test.
---@return boolean exists True when the path exists.
---@usage <br>
--- ```
--- if io_shell.exists("config.lua") then
---   print("found")
--- end
--- ```
function io_shell.exists(path)
	path = normalize_path(path)

	local command

	if io_shell.is_windows() then
		command =
			"if exist " ..
			io_shell.quote(path) ..
			" (exit /b 0) else (exit /b 1)"
	else
		command =
			"test -e " ..
			io_shell.quote(path)
	end

	local a, b, c = os_execute(command)

	return normalize_execute_result(a, b, c)
end

--- Check whether a path is a regular file.
---@param path string Path to test.
---@return boolean is_file True when the path is a regular file.
---@usage <br>
--- ```
--- if io_shell.is_file("data.txt") then
---   print("is file")
--- end
--- ```
function io_shell.is_file(path)
	path = normalize_path(path)

	local command

	if io_shell.is_windows() then
		command =
			"if exist " ..
			io_shell.quote(path) ..
			"\\NUL (exit /b 1) else if exist " ..
			io_shell.quote(path) ..
			" (exit /b 0) else (exit /b 1)"
	else
		command =
			"test -f " ..
			io_shell.quote(path)
	end

	local a, b, c = os_execute(command)

	return normalize_execute_result(a, b, c)
end

--- Check whether a path is a directory.
---@param path string Path to test.
---@return boolean is_directory True when the path is a directory.
---@usage <br>
--- ```
--- if io_shell.is_directory("logs") then
---   print("is dir")
--- end
--- ```
function io_shell.is_directory(path)
	path = normalize_path(path)

	local command

	if io_shell.is_windows() then
		command =
			"if exist " ..
			io_shell.quote(path .. "\\NUL") ..
			" (exit /b 0) else (exit /b 1)"
	else
		command =
			"test -d " ..
			io_shell.quote(path)
	end

	local a, b, c = os_execute(command)

	return normalize_execute_result(a, b, c)
end

--- Create a directory.
---@param path string Directory path to create.
---@param recursive? boolean Create parent directories with `mkdir -p` on Unix (default: false). On Windows `mkdir` already creates intermediates.
---@return boolean success True when the command succeeded.
---@return io_shell.Result result Raw execution result.
---@usage <br>
--- ```
--- local ok = io_shell.mkdir("logs/archive", true)
--- ```
function io_shell.mkdir(path, recursive)
	path = normalize_path(path)

	local command

	if io_shell.is_windows() then
		command = "mkdir " .. io_shell.quote(path)
	else
		if recursive then
			command =
				"mkdir -p " ..
				io_shell.quote(path)
		else
			command =
				"mkdir " ..
				io_shell.quote(path)
		end
	end

	local result = io_shell.execute(command)

	return result.success, result
end

--- Remove a file or directory.
---@param path string File or directory path to remove.
---@param recursive? boolean Remove directories recursively (`rmdir /s` / `rm -rf`) (default: false).
---@return boolean success True when the command succeeded.
---@return io_shell.Result result Raw execution result.
---@usage <br>
--- ```
--- local ok = io_shell.remove("tmp.txt")
--- local ok2 = io_shell.remove("build", true)
--- ```
function io_shell.remove(path, recursive)
	path = normalize_path(path)

	local command

	if io_shell.is_windows() then
		if recursive then
			command =
				"rmdir /s /q " ..
				io_shell.quote(path)
		else
			command =
				"del /f /q " ..
				io_shell.quote(path)
		end
	else
		if recursive then
			command =
				"rm -rf " ..
				io_shell.quote(path)
		else
			command =
				"rm -f " ..
				io_shell.quote(path)
		end
	end

	local result = io_shell.execute(command)

	return result.success, result
end

--- Copy a file.
---@param source string Source file path.
---@param destination string Destination file path.
---@return boolean success True when the command succeeded.
---@return io_shell.Result result Raw execution result.
---@usage <br>
--- ```
--- local ok = io_shell.copy("a.txt", "b.txt")
--- ```
function io_shell.copy(source, destination)
	source = normalize_path(source)
	destination = normalize_path(destination)

	local command

	if io_shell.is_windows() then
		command =
			"copy /y " ..
			io_shell.quote(source) ..
			" " ..
			io_shell.quote(destination)
	else
		command =
			"cp " ..
			io_shell.quote(source) ..
			" " ..
			io_shell.quote(destination)
	end

	local result = io_shell.execute(command)

	return result.success, result
end

--- Move/rename a file.
---@param source string Source file path.
---@param destination string Destination file path.
---@return boolean success True when the command succeeded.
---@return io_shell.Result result Raw execution result.
---@usage <br>
--- ```
--- local ok = io_shell.move("old.txt", "new.txt")
--- ```
function io_shell.move(source, destination)
	source = normalize_path(source)
	destination = normalize_path(destination)

	local command

	if io_shell.is_windows() then
		command =
			"move /y " ..
			io_shell.quote(source) ..
			" " ..
			io_shell.quote(destination)
	else
		command =
			"mv " ..
			io_shell.quote(source) ..
			" " ..
			io_shell.quote(destination)
	end

	local result = io_shell.execute(command)

	return result.success, result
end

----------------------------------------------------------------------
-- sed / sd replacement
----------------------------------------------------------------------

--- Replace text in a file.<br>
--- `sd` is preferred when available because its command-line syntax is considerably easier to work with for regular expressions.
---@param pattern string Regex (or literal when `fixed_string` is set) to replace.
---@param replacement string Replacement text.
---@param path string File path to modify in place.
---@param options? {fixed_string?: boolean, regex?: boolean} Replace options (default: {}).
---@return boolean success True when the command succeeded.
---@return io_shell.Result result Raw execution result.
---@usage <br>
--- ```
--- local ok = io_shell.replace("foo%s+bar", "baz", "test.lua")
--- local ok2 = io_shell.replace("a.b", "a_b", "test.lua", { fixed_string = true })
--- ```
function io_shell.replace(pattern, replacement, path, options)
	options = options or {}

	local replace_command = choose_replace_command()

	if replace_command == "" then
		return false, {
			success = false,
			code = nil,
			stdout = "",
			stderr = "Neither sd nor sed is available.",
			command = "",
		}
	end

	local command

	if replace_command == "sd" then
		local expression

		if options.fixed_string then
			-- sd itself is regex based; escape regex metacharacters.
			local escaped = string_gsub(
				pattern,
				"([%%%^%$%(%)%.%[%]%*%+%-%?])",
				"\\%1"
			)

			expression =
				io_shell.quote(
					escaped ..
					" " ..
					replacement
				)
		else
			expression =
				io_shell.quote(
					pattern ..
					" " ..
					replacement
				)
		end

		command =
			"sd " ..
			expression ..
			" " ..
			io_shell.quote(path)
	else
		-- GNU/BSD sed-compatible form.
		--
		-- Escape delimiter and backslash characters.
		local sed_pattern =
			string_gsub(pattern, "\\", "\\\\")
		sed_pattern =
			string_gsub(sed_pattern, "/", "\\/")

		local sed_replacement =
			string_gsub(replacement, "\\", "\\\\")
		sed_replacement =
			string_gsub(sed_replacement, "/", "\\/")

		command =
			"sed -i " ..
			io_shell.quote(
				"s/" ..
				sed_pattern ..
				"/" ..
				sed_replacement ..
				"/g"
			) ..
			" " ..
			io_shell.quote(path)
	end

	local result = io_shell.execute(command)

	return result.success, result
end

----------------------------------------------------------------------
-- Bulk replacement
----------------------------------------------------------------------

--- Replace matching text in every matching file.<br>
--- Searches first, then applies `replace()` once per unique file.
---@param pattern string Regex (or literal when `fixed_string` is set) to replace.
---@param replacement string Replacement text.
---@param path? string Directory/file to search (default: ".").
---@param search_options? io_shell.SearchOptions Search options (default: nil).
---@param replace_options? {fixed_string?: boolean, regex?: boolean} Replace options (default: nil).
---@return number changed_files Number of files successfully modified.
---@return io_shell.Result[] results Per-file execution results.
---@usage <br>
--- ```
--- local changed = io_shell.replace_all("foo", "bar", ".")
--- ```
function io_shell.replace_all(
	pattern,
	replacement,
	path,
	search_options,
	replace_options
)
	local matches, search_result =
		io_shell.search(
			pattern,
			path,
			search_options
		)

	local changed = 0
	local results = {}

	if not search_result.success then
		return 0, results
	end

	local seen = {}

	for _, match in ipairs(matches) do
		if not seen[match.file] then
			seen[match.file] = true

			local success, result =
				io_shell.replace(
					pattern,
					replacement,
					match.file,
					replace_options
				)

			results[#results + 1] = result

			if success then
				changed = changed + 1
			end
		end
	end

	return changed, results
end

----------------------------------------------------------------------
-- High-level helpers
----------------------------------------------------------------------

--- Return all Lua source files below a directory.
---@param path? string Directory to enumerate (default: ".").
---@return string[] files Matching file paths.
---@return io_shell.Result result Raw execution result.
---@usage <br>
--- ```
--- local files = io_shell.find_lua_files(".")
--- ```
function io_shell.find_lua_files(path)
	return io_shell.find_files(path, {
		recursive = true,
		pattern = "*.lua",
	})
end

--- Return all files matching a glob.
---@param pattern string Glob pattern (e.g. "*.json").
---@param path? string Directory to enumerate (default: ".").
---@return string[] files Matching file paths.
---@return io_shell.Result result Raw execution result.
---@usage <br>
--- ```
--- local files = io_shell.find_by_pattern("*.json", ".")
--- ```
function io_shell.find_by_pattern(pattern, path)
	return io_shell.find_files(path, {
		recursive = true,
		pattern = pattern,
	})
end

--- Search all Lua files recursively.<br>
--- Forces `recursive` and `file_pattern = "*.lua"` before delegating to `search()`.
---@param pattern string Regex (or literal when `fixed_string` is set) to search for.
---@param path? string Directory/file to search (default: ".").
---@param options? io_shell.SearchOptions Search options (default: {}).
---@return io_shell.Match[] matches Parsed matches.
---@return io_shell.Result result Raw execution result.
---@usage <br>
--- ```
--- local matches = io_shell.search_lua("require", ".")
--- ```
function io_shell.search_lua(pattern, path, options)
	options = options or {}

	local copy = {}

	for key, value in pairs(options) do
		copy[key] = value
	end

	copy.recursive = true
	copy.file_pattern = "*.lua"

	return io_shell.search(pattern, path, copy)
end

----------------------------------------------------------------------
-- Diagnostics
----------------------------------------------------------------------

--- Return information about available external tools.
---@return table<string, boolean> capabilities Map of tool names (`rg`, `grep`, `sed`, `sd`, `ls`, `dir`) to availability.
---@usage <br>
--- ```
--- local caps = io_shell.get_capabilities()
--- print(caps.rg)
--- ```
function io_shell.get_capabilities()
	return {
		rg = io_shell.command_exists("rg"),
		grep = io_shell.command_exists("grep"),
		sed = io_shell.command_exists("sed"),
		sd = io_shell.command_exists("sd"),
		ls = io_shell.command_exists("ls"),
		dir = io_shell.is_windows() and true or io_shell.command_exists("dir"),
	}
end

--- Return a human-readable diagnostic description.<br>
--- Lists the detected OS and the availability of each external tool.
---@return string description Multi-line diagnostic string.
---@usage <br>
--- ```
--- print(io_shell.describe())
--- -- OS: linux
--- -- rg: true
--- -- ...
--- ```
function io_shell.describe()
	local capabilities = io_shell.get_capabilities()

	local lines = {
		"OS: " .. io_shell.get_os(),
		"rg: " .. tostring(capabilities.rg),
		"grep: " .. tostring(capabilities.grep),
		"sed: " .. tostring(capabilities.sed),
		"sd: " .. tostring(capabilities.sd),
		"ls: " .. tostring(capabilities.ls),
		"dir: " .. tostring(capabilities.dir),
	}

	return table_concat(lines, "\n")
end

--[[ Quick tests
if true then
	local total, passed, failed = 0, 0, 0
	local function test(name, fn)
		total = total + 1
		local ok, err = pcall(fn)
		if ok then
			passed = passed + 1
		else
			failed = failed + 1
			print(string_format("  FAIL  %s: %s", name, tostring(err)))
		end
	end
	print("[io_shell] testing...")

	local tmp_root = os_tmpname() .. "_io_shell_test"
	io_shell.remove(tmp_root, true)

	test("get_os returns known identifier", function()
		local os_name = io_shell.get_os()
		assert(os_name == "windows" or os_name == "linux" or os_name == "macos" or os_name == "bsd" or os_name == "unix" or
			os_name == "unknown")
	end)

	test("is_windows/is_unix are exclusive booleans", function()
		local w, u = io_shell.is_windows(), io_shell.is_unix()
		assert(type(w) == "boolean" and type(u) == "boolean")
		assert(not (w and u))
	end)

	test("quote wraps value", function()
		local q = io_shell.quote("a b")
		assert(type(q) == "string" and #q > 3)
		assert(string_find(q, "a b", 1, true) ~= nil)
	end)

	test("write_file/read_file roundtrip", function()
		assert(io_shell.mkdir(tmp_root, true))
		local p = tmp_root .. "/hello.txt"
		assert(io_shell.write_file(p, "hello"))
		local content, err = io_shell.read_file(p)
		assert(content == "hello", tostring(err))
	end)

	test("read_file missing returns nil", function()
		local content, err = io_shell.read_file(tmp_root .. "/does_not_exist_xyz.txt")
		assert(content == nil and type(err) == "string")
	end)

	test("execute captures stdout", function()
		local result = io_shell.execute("echo hello")
		assert(type(result) == "table" and type(result.stdout) == "string")
		assert(result.success == true)
		assert(string_find(result.stdout, "hello", 1, true) ~= nil)
	end)

	test("execute failing command reports failure", function()
		local result = io_shell.execute("command_that_does_not_exist_xyz_12345")
		assert(type(result) == "table")
		assert(result.success == false)
	end)

	test("execute raise_on_error raises", function()
		local ok = pcall(io_shell.execute, "command_that_does_not_exist_xyz_12345", { raise_on_error = true })
		assert(ok == false)
	end)

	test("command_exists caches boolean", function()
		local a = io_shell.command_exists("definitely_not_a_real_command_xyz")
		local b = io_shell.command_exists("definitely_not_a_real_command_xyz")
		assert(a == false and b == false)
	end)

	test("exists/is_file/is_directory basics", function()
		local p = tmp_root .. "/hello.txt"
		assert(io_shell.exists(p) == true)
		assert(io_shell.is_file(p) == true)
		assert(type(io_shell.is_directory(tmp_root)) == "boolean")
		assert(io_shell.exists(tmp_root .. "/missing_xyz") == false)
	end)

	test("mkdir nested recursive", function()
		local nested = tmp_root .. "/a/b"
		local ok, result = io_shell.mkdir(nested, true)
		assert(type(ok) == "boolean" and type(result) == "table")
		if ok then
			assert(io_shell.exists(nested) == true)
		end
	end)

	test("list/list_files/list_directories return tables", function()
		local entries, result = io_shell.list(tmp_root)
		assert(type(entries) == "table" and type(result) == "table")
		local files = io_shell.list_files(tmp_root)
		assert(type(files) == "table")
		local dirs = io_shell.list_directories(tmp_root)
		assert(type(dirs) == "table")
	end)

	test("find_files/find_lua_files/find_by_pattern return tables", function()
		assert(io_shell.write_file(tmp_root .. "/sample.lua", "return 1"))
		local files = io_shell.find_files(tmp_root, { pattern = "*.lua" })
		assert(type(files) == "table")
		local lua_files = io_shell.find_lua_files(tmp_root)
		assert(type(lua_files) == "table")
		local by_pat = io_shell.find_by_pattern("*.lua", tmp_root)
		assert(type(by_pat) == "table")
	end)

	test("search/contains/count return tables", function()
		local caps = io_shell.get_capabilities()
		if not (caps.rg or caps.grep) then return end
		assert(io_shell.write_file(tmp_root .. "/search_me.txt", "needle here\nanother line\n"))
		local matches, result = io_shell.search("needle", tmp_root, { fixed_string = true })
		assert(type(matches) == "table" and type(result) == "table")
		assert(#matches >= 1)
		local found = io_shell.contains("needle", tmp_root)
		assert(found == true)
		assert(io_shell.count("needle", tmp_root) >= 1)
	end)

	test("search_text/search_regex/search_lua return tables", function()
		local caps = io_shell.get_capabilities()
		if not (caps.rg or caps.grep) then return end
		assert(type(io_shell.search_text("needle", tmp_root)) == "table")
		assert(type(io_shell.search_regex("nee.dle", tmp_root)) == "table")
		assert(type(io_shell.search_lua("return", tmp_root)) == "table")
	end)

	test("copy/move roundtrip", function()
		local src = tmp_root .. "/hello.txt"
		local dst = tmp_root .. "/copied.txt"
		local moved = tmp_root .. "/moved.txt"
		local ok, res = io_shell.copy(src, dst)
		assert(type(ok) == "boolean" and type(res) == "table")
		if ok then
			assert(io_shell.exists(dst) == true)
			local ok2, res2 = io_shell.move(dst, moved)
			assert(type(ok2) == "boolean" and type(res2) == "table")
			if ok2 then
				assert(io_shell.exists(moved) == true)
			end
		end
	end)

	test("remove file", function()
		local p = tmp_root .. "/to_delete.txt"
		assert(io_shell.write_file(p, "bye"))
		local ok, res = io_shell.remove(p)
		assert(ok == true, "remove failed: " .. tostring(res and res.stdout) .. tostring(res and res.stderr))
		assert(io_shell.exists(p) == false)
	end)

	test("replace/replace_all (when backend available)", function()
		local caps = io_shell.get_capabilities()
		if not (caps.sd or caps.sed) then return end
		if not (caps.rg or caps.grep) then return end
		local p = tmp_root .. "/replace_me.txt"
		assert(io_shell.write_file(p, "foo 123"))
		local ok, res = io_shell.replace("foo", "bar", p)
		assert(type(ok) == "boolean" and type(res) == "table")
		local changed, results = io_shell.replace_all("bar", "baz", tmp_root)
		assert(type(changed) == "number" and type(results) == "table")
	end)

	test("get_capabilities/describe shapes", function()
		local caps = io_shell.get_capabilities()
		assert(type(caps) == "table" and type(caps.rg) == "boolean")
		local desc = io_shell.describe()
		assert(type(desc) == "string" and string_find(desc, "OS:", 1, true) ~= nil)
	end)

	io_shell.remove(tmp_root, true)

	print(string_format("[io_shell] %d/%d tests passed (%d failed)", passed, total, failed))
	assert(failed == 0, string_format("%d test(s) failed", failed))
end
--]]

-- Export
return io_shell
