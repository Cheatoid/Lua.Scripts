@echo off
rem Run a Lua script file inside Sandboxie (Sandboxie-Plus compatible).
rem Usage: sandboxie.cmd [options] script.lua [script args...]
rem   Just: sandboxie.cmd script.lua
rem   Options (all optional):
rem     /box:BoxName  Sandboxie box (default: DefaultBox, or %%SANDBOXIE_BOX%%).
rem     /lua:LuaExe   Interpreter (default: lua.exe from PATH, or %%LUA_EXE%%).
rem     /jit          Shorthand for luajit.exe from PATH.
rem     /dir:WorkDir  Working directory (default: script's folder).
rem Examples:
rem   sandboxie.cmd script.lua
rem   sandboxie.cmd script.lua arg1 arg2
rem   sandboxie.cmd /jit script.lua
setlocal EnableDelayedExpansion
set "PF86=%ProgramFiles(x86)%"

rem --- Resolve Start.exe (Plus and classic install locations) ---
set "SBIE_START="
if defined SANDBOXIE_START set "SBIE_START=%SANDBOXIE_START%"
if not defined SBIE_START (
	if exist "%ProgramFiles%\Sandboxie-Plus\Start.exe" set "SBIE_START=%ProgramFiles%\Sandboxie-Plus\Start.exe"
)
if not defined SBIE_START (
	if exist "%ProgramFiles%\Sandboxie\Start.exe" set "SBIE_START=%ProgramFiles%\Sandboxie\Start.exe"
)
if not defined SBIE_START (
	if defined PF86 if exist "%PF86%\Sandboxie\Start.exe" set "SBIE_START=%PF86%\Sandboxie\Start.exe"
)
if not defined SBIE_START (
	echo [sandboxie] ERROR: Start.exe not found. Set SANDBOXIE_START to its full path. 1>&2
	exit /b 9009
)
if not exist "%SBIE_START%" (
	echo [sandboxie] ERROR: Start.exe not found at "%SBIE_START%". 1>&2
	exit /b 9009
)

rem --- Defaults (overridable via env, no flags needed when Lua is in PATH) ---
set "SBIE_BOX=LuaBox"
if defined SANDBOXIE_BOX set "SBIE_BOX=%SANDBOXIE_BOX%"
set "LUA_BIN=lua.exe"
if defined LUA_EXE set "LUA_BIN=%LUA_EXE%"
set "WORKDIR_OVERRIDE="

rem --- Parse leading /box: /lua: /dir: flags ---
:parse_flags
if "%~1"=="" goto :after_flags
set "ARG=%~1"
if /i "%ARG%"=="/?" goto :usage
if /i "%ARG%"=="/h" goto :usage
if /i "%ARG%"=="-h" goto :usage
if /i "%ARG%"=="--help" goto :usage
if /i "%ARG:~0,5%"=="/box:" (
	set "SBIE_BOX=%ARG:~5%"
	shift
	goto :parse_flags
)
if /i "%ARG%"=="/jit" (
	set "LUA_BIN=luajit.exe"
	shift
	goto :parse_flags
)
if /i "%ARG:~0,5%"=="/lua:" (
	set "LUA_BIN=%ARG:~5%"
	shift
	goto :parse_flags
)
if /i "%ARG:~0,5%"=="/dir:" (
	set "WORKDIR_OVERRIDE=%ARG:~5%"
	shift
	goto :parse_flags
)
goto :after_flags
:after_flags

rem --- No script: blank sandboxed cmd in current directory (or /dir: override) ---
if "%~1"=="" goto :blank
rem --- Script file is now %1 (bare name allowed, .lua auto-appended, made absolute) ---
set "SCRIPT=%~1"
shift
if not exist "%SCRIPT%" (
	if exist "%SCRIPT%.lua" set "SCRIPT=%SCRIPT%.lua"
)
if not exist "%SCRIPT%" (
	echo [sandboxie] ERROR: Lua script not found: "%SCRIPT%". 1>&2
	exit /b 2
)
for %%F in ("%SCRIPT%") do set "SCRIPT=%%~fF"

rem --- Collect remaining args verbatim (preserves original quoting) ---
set "TAIL="
:collect_tail
if "%~1"=="" goto :run
set "TAIL=%TAIL% %1"
shift
goto :collect_tail

:run
rem --- Lua is expected in PATH (bare lua.exe/luajit.exe works inside the box too) ---
rem --- Working directory defaults to the script's folder so relative requires work ---
set "WORKDIR=%WORKDIR_OVERRIDE%"
if not defined WORKDIR (
	for %%F in ("%SCRIPT%") do set "WORKDIR=%%~dpF"
)
:have_workdir

echo [sandboxie] box=%SBIE_BOX% lua="%LUA_BIN%" dir="%WORKDIR%" script="%SCRIPT%"%TAIL%
rem NOTE: Sandboxie Start.exe takes /box:Name unquoted; quoting it makes
rem everything after it part of the box name. Workdir is inherited, so pushd.
pushd "%WORKDIR%" || exit /b 1
"%SBIE_START%" /box:%SBIE_BOX% /wait "%LUA_BIN%" "%SCRIPT%"%TAIL%
set "RC=%ERRORLEVEL%"
popd
exit /b %RC%

:blank
rem --- Blank sandboxed prompt: inherit caller's directory unless /dir: given ---
set "WORKDIR=%WORKDIR_OVERRIDE%"
if not defined WORKDIR set "WORKDIR=%CD%"
echo [sandboxie] box=%SBIE_BOX% dir="%WORKDIR%" cmd
pushd "%WORKDIR%" || exit /b 1
"%SBIE_START%" /box:%SBIE_BOX% /wait "cmd.exe" /k ^"set ^"PATHEXT=.EXE;.BAT;.CMD^"^"
set "RC=%ERRORLEVEL%"
popd
exit /b %RC%

:usage
echo Usage: %~nx0 [no args = sandboxed cmd] 1>&2
echo        %~nx0 script.lua [script args...] 1>&2
echo        %~nx0 [/box:BoxName] [/lua:LuaExe] [/jit] [/dir:WorkDir] script.lua [script args...] 1>&2
exit /b 1
