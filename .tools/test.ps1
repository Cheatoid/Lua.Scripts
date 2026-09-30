#!/usr/bin/env pwsh
#Requires -Version 7.0

# Author: Cheatoid ~ https://github.com/Cheatoid
# License: MIT

<#
.SYNOPSIS
	Find all tests/*.lua files and run them with luac, lua and luajit.

.DESCRIPTION
	Recursively finds every *.lua file under a */tests/ directory starting
	from the @cheatoid root (the parent of the .tools directory containing
	this script), then:
	  1. luac -p <file> for syntax check (always, including helpers)
	  2. lua <file> executed with the test file's own directory as cwd
	  3. luajit <file> executed the same way
	Headers say "Run from this directory", so each test runs with its own
	folder as working directory. Prints per-file PASS/FAIL/SKIP and a summary.
	Exits 1 when anything fails, 0 when everything passes.

	FILENAME CONVENTION (helpers vs entry points):
	Not every file under */tests/ is standalone runnable. Suite-style
	directories (e.g. astar/tests/) contain an entry-point runner plus
	fragments/helpers that must NOT be executed directly:
	  - run.lua          : suite entry point, EXECUTED (loads test_*.lua)
	  - test_*.lua       : fragments returning function(T), syntax-only
	                       (running them directly exits 0 without asserting
	                       anything -> false PASS)
	  - util.lua         : shared helper returning M, syntax-only
	  - run_one.lua      : debug/single-file aid, syntax-only by default
	                       (duplicates run.lua coverage)
	Files matching SkipRunPatterns get luac -p only, and their lua/luajit
	steps report [SKIP]. Use -RunAll to force the old behavior of executing
	everything.

.PARAMETER Root
	Root folder to scan (default: parent of the .tools directory containing
	this script, i.e. the @cheatoid root).

.PARAMETER Filter
	Wildcard matched against the test file name (default: *.lua).
	Example: -Filter "bits.lua" or -Filter "Heap*".

.PARAMETER Lua
	Explicit path to a lua executable (default: auto-detect).

.PARAMETER Luac
	Explicit path to a luac executable (default: auto-detect).

.PARAMETER LuaJIT
	Explicit path to a luajit executable (default: auto-detect).

.PARAMETER NoLuac
	Skip the luac -p syntax step.

.PARAMETER NoLua
	Skip the lua run step.

.PARAMETER NoLuaJIT
	Skip the luajit run step.

.PARAMETER ParseOnly
	Only run the luac -p syntax check, skipping lua and luajit runs.

.PARAMETER FailFast
	Stop at the first failure instead of running everything.

.PARAMETER SkipRunPatterns
	Basename wildcards (matched with -like, case-insensitive) for files
	that are syntax-checked only and never executed. Default covers the
	astar-style suite layout plus generic helper names.

.PARAMETER RunAll
	Execute every file, including helpers/fragments (legacy behavior).
	Useful to prove a helper is harmless, but test_*.lua / util.lua will
	report vacuous PASS.

.EXAMPLE
	.\.tools\test.ps1
.EXAMPLE
	.\.tools\test.ps1 -Filter "timer.lua"
.EXAMPLE
	.\.tools\test.ps1 -NoLuaJIT
.EXAMPLE
	.\.tools\test.ps1 -ParseOnly
.EXAMPLE
	.\.tools\test.ps1 -RunAll
.EXAMPLE
	.\.tools\test.ps1 -SkipRunPatterns @("test_*.lua", "util.lua")
#>

param(
	[string]$Root = (Split-Path $PSScriptRoot -Parent),
	[string]$Filter = "*.lua",
	[string]$Lua = "",
	[string]$Luac = "",
	[string]$LuaJIT = "",
	[switch]$NoLuac,
	[switch]$NoLua,
	[switch]$NoLuaJIT,
	[Alias('parse-only')][switch]$ParseOnly,
	[switch]$FailFast,
	[string[]]$SkipRunPatterns = @("test_*.lua", "util.lua", "run_one.lua", "run_single.lua", "helper_*.lua", "*_helper.lua", "helpers.lua", "common.lua", "fixtures.lua"),
	[switch]$RunAll
)

if ($PSVersionTable.PSVersion.Major -lt 7) {
	throw 'test.ps1 requires PowerShell 7 or newer. Install PowerShell 7+ and run with pwsh.'
}

if ($ParseOnly) {
	$NoLua = $true
	$NoLuaJIT = $true
}

function Resolve-Tool {
	param(
		[string]$Explicit,
		[string[]]$Names,
		[string[]]$Fallbacks
	)
	if ($Explicit -ne "" -and (Test-Path -LiteralPath $Explicit)) {
		return (Resolve-Path -LiteralPath $Explicit).Path
	}
	foreach ($n in $Names) {
		$cmd = Get-Command $n -ErrorAction SilentlyContinue | Select-Object -First 1
		if ($cmd) { return $cmd.Source }
	}
	foreach ($fb in $Fallbacks) {
		if (Test-Path -LiteralPath $fb) { return $fb }
	}
	return $null
}

$luacExe = Resolve-Tool -Explicit $Luac -Names @("luac") -Fallbacks @("X:\Lua\5.4.9\bin\luac.exe")
$luaExe = Resolve-Tool -Explicit $Lua -Names @("lua") -Fallbacks @("X:\Lua\5.4.9\bin\lua.exe")
$luajitExe = Resolve-Tool -Explicit $LuaJIT -Names @("luajit") -Fallbacks @("X:\luajit-2.1\bin\luajit.exe")

if (-not $NoLuac -and -not $luacExe) {
	Write-Host "WARNING: luac not found, syntax step will be skipped." -ForegroundColor Yellow
	$NoLuac = $true
}
if (-not $NoLua -and -not $luaExe) {
	Write-Host "WARNING: lua not found, lua step will be skipped." -ForegroundColor Yellow
	$NoLua = $true
}
if (-not $NoLuaJIT -and -not $luajitExe) {
	Write-Host "WARNING: luajit not found, luajit step will be skipped." -ForegroundColor Yellow
	$NoLuaJIT = $true
}

Write-Host "Root:    $Root" -ForegroundColor Gray
if (-not $NoLuac) { Write-Host "luac:    $luacExe" -ForegroundColor Gray }
if (-not $NoLua) { Write-Host "lua:     $luaExe" -ForegroundColor Gray }
if (-not $NoLuaJIT) { Write-Host "luajit:  $luajitExe" -ForegroundColor Gray }

try {
	$candidates = Get-ChildItem -Path $Root -Recurse -File -Filter "*.lua" -ErrorAction Stop |
		Where-Object { $_.FullName -match '[\\/]tests[\\/]' } |
		Where-Object { $_.FullName -notmatch '[\\/]\.(git|idea|vscode|kilo|tools)[\\/]' } |
		Where-Object { $_.Name -like $Filter } |
		Sort-Object FullName
}
catch {
	Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
	exit 1
}

if (-not $candidates -or $candidates.Count -eq 0) {
	Write-Host "No test files found under $Root with filter $Filter." -ForegroundColor Yellow
	exit 0
}

Write-Host "Found $($candidates.Count) test file(s)." -ForegroundColor Cyan
if (-not $RunAll -and $SkipRunPatterns -and $SkipRunPatterns.Count -gt 0) {
	Write-Host ("Skip-run: " + ($SkipRunPatterns -join ", ")) -ForegroundColor Gray
} elseif ($RunAll) {
	Write-Host "Skip-run: disabled via -RunAll (helpers/fragments will execute)." -ForegroundColor Gray
}

function Test-SkipRun {
	param([string]$Name)
	if ($RunAll) { return $null }
	foreach ($pat in $SkipRunPatterns) {
		if ($Name -like $pat) { return $pat }
	}
	return $null
}

$luacPass = 0
$luacFail = @()
$luaPass = 0
$luaFail = @()
$luaSkip = @()
$luajitPass = 0
$luajitFail = @()
$luajitSkip = @()
$failed = $false

foreach ($file in $candidates) {
	$rel = try {
		Resolve-Path -LiteralPath $file.FullName -Relative -RelativeBasePath $Root -ErrorAction Stop
	} catch {
		$file.FullName
	}
	$skipPat = Test-SkipRun -Name $file.Name
	$skipRun = ($null -ne $skipPat)
	Write-Host ""
	if ($skipRun) {
		Write-Host "=== $rel === [helper/fragment: $skipPat, syntax-only]" -ForegroundColor DarkGray
	} else {
		Write-Host "=== $rel ===" -ForegroundColor White
	}

	if (-not $NoLuac) {
		& $luacExe -p "$($file.FullName)" 2>&1 | Out-Null
		if ($LASTEXITCODE -eq 0) {
			Write-Host "  [PASS] luac -p" -ForegroundColor Green
			$luacPass++
		} else {
			Write-Host "  [FAIL] luac -p (exit $LASTEXITCODE)" -ForegroundColor Red
			$luacFail += $rel
			$failed = $true
			if ($FailFast) { break }
		}
	}

	if (-not $NoLua) {
		if ($skipRun) {
			Write-Host "  [SKIP] lua (matches $skipPat, run via entry point)" -ForegroundColor DarkGray
			$luaSkip += $rel
		} else {
			Push-Location -LiteralPath $file.DirectoryName
			try {
				$out = & $luaExe "$($file.Name)" 2>&1
				$code = $LASTEXITCODE
			} finally {
				Pop-Location
			}
			if ($code -eq 0) {
				Write-Host "  [PASS] lua" -ForegroundColor Green
				$luaPass++
			} else {
				Write-Host "  [FAIL] lua (exit $code)" -ForegroundColor Red
				$out | ForEach-Object { Write-Host "         $_" -ForegroundColor Gray }
				$luaFail += $rel
				$failed = $true
				if ($FailFast) { break }
			}
		}
	}

	if (-not $NoLuaJIT) {
		if ($skipRun) {
			Write-Host "  [SKIP] luajit (matches $skipPat, run via entry point)" -ForegroundColor DarkGray
			$luajitSkip += $rel
		} else {
			Push-Location -LiteralPath $file.DirectoryName
			try {
				$out = & $luajitExe "$($file.Name)" 2>&1
				$code = $LASTEXITCODE
			} finally {
				Pop-Location
			}
			if ($code -eq 0) {
				Write-Host "  [PASS] luajit" -ForegroundColor Green
				$luajitPass++
			} else {
				Write-Host "  [FAIL] luajit (exit $code)" -ForegroundColor Red
				$out | ForEach-Object { Write-Host "         $_" -ForegroundColor Gray }
				$luajitFail += $rel
				$failed = $true
				if ($FailFast) { break }
			}
		}
	}
}

Write-Host ""
Write-Host "=== SUMMARY ===" -ForegroundColor Cyan
if (-not $NoLuac) {
	Write-Host "luac -p : $luacPass passed, $($luacFail.Count) failed" -ForegroundColor $(if ($luacFail.Count -eq 0) { "Green" } else { "Red" })
	foreach ($f in $luacFail) { Write-Host "  FAIL $f" -ForegroundColor Red }
}
if (-not $NoLua) {
	Write-Host "lua     : $luaPass passed, $($luaFail.Count) failed, $($luaSkip.Count) skipped" -ForegroundColor $(if ($luaFail.Count -eq 0) { "Green" } else { "Red" })
	foreach ($f in $luaFail) { Write-Host "  FAIL $f" -ForegroundColor Red }
	foreach ($f in $luaSkip) { Write-Host "  SKIP $f" -ForegroundColor DarkGray }
}
if (-not $NoLuaJIT) {
	Write-Host "luajit  : $luajitPass passed, $($luajitFail.Count) failed, $($luajitSkip.Count) skipped" -ForegroundColor $(if ($luajitFail.Count -eq 0) { "Green" } else { "Red" })
	foreach ($f in $luajitFail) { Write-Host "  FAIL $f" -ForegroundColor Red }
	foreach ($f in $luajitSkip) { Write-Host "  SKIP $f" -ForegroundColor DarkGray }
}

if ($failed) { exit 1 }
exit 0
