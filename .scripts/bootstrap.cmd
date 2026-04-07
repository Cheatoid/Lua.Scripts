@echo off
cd /d "%~dp0/.."
git config core.autocrlf false
git config core.longpaths true
rem git config core.hooksPath .git-hooks
