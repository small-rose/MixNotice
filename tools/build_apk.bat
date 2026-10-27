@echo off
REM Thin wrapper so the build helper can be started from Explorer or cmd.
REM All arguments are forwarded to build_apk.ps1.
REM
REM   build_apk.bat -Tag fix11
REM   build_apk.bat -Tag fix11 -Abi universal -Mode release -Stamp
REM   build_apk.bat -Tag fix11 -DryRun
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build_apk.ps1" %*
endlocal
