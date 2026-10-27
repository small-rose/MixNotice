@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul 2>&1
title C-Drive Cleanup - Category A (default: DRY-RUN)

REM =================================================================
REM  clean_c_drive.bat  --  C-drive cleanup, CATEGORY A only
REM  Deletes ONLY caches / backups / logs. Never touches:
REM    - .workbuddy\projects      (conversation records)
REM    - .workbuddy\sessions      (session records)
REM    - .workbuddy\plugins       (installed skills)
REM    - .workbuddy\binaries      (runtime binaries)
REM    - user-...-personal        (memory / MEMORY.md)
REM    - any project source file
REM
REM  USAGE
REM    clean_c_drive.bat          DRY-RUN  (default, deletes NOTHING)
REM    clean_c_drive.bat /dry     DRY-RUN
REM    clean_c_drive.bat /go      REAL deletion, requires typing YES
REM
REM  SAFETY
REM    * whitelist: every path must start with C:\Users\Think
REM    * no wildcards inside the target list itself
REM    * locked files are skipped and reported, never forced
REM    * log file: E:\wbtmp\c_drive_cleanup.log  (NOT on C:)
REM =================================================================

set "LOGDIR=E:\wbtmp"
set "LOGFILE=%LOGDIR%\c_drive_cleanup.log"
if not exist "%LOGDIR%" mkdir "%LOGDIR%" 2>nul

set "MODE=DRY"
if /i "%~1"=="/go"  set "MODE=GO"
if /i "%~1"=="/dry" set "MODE=DRY"

set "SESSION=C:\Users\Think\.workbuddy\workspace\sessions\e28a55f2-8eb7-463c-9764-bfbf8c805d43"

echo =================================================================
echo  C-DRIVE CLEANUP  -  CATEGORY A
echo  Mode: %MODE%
echo  Time: %DATE% %TIME%
echo  Log : %LOGFILE%
echo =================================================================
echo [%DATE% %TIME%] === run start, mode=%MODE% ===>>"%LOGFILE%"

REM ---------------- free space helper ----------------
call :FREE
set "FREE_BEFORE=%FREE_MB%"
echo.
echo Free space on C: %FREE_BEFORE% MB
echo Free C: before = %FREE_BEFORE% MB>>"%LOGFILE%"

REM ---------------- pre-flight integrity check ----------------
echo.
echo --- Pre-flight check (project files must be intact) ---
set "PF=1"
if exist "E:\App\wbWork\MixNoticeApp\app\lib\main.dart" (echo   [OK]   app\lib\main.dart) else (echo   [FAIL] app\lib\main.dart & set "PF=0")
if exist "E:\App\wbWork\MixNoticeApp\app\pubspec.yaml"  (echo   [OK]   app\pubspec.yaml)  else (echo   [FAIL] app\pubspec.yaml  & set "PF=0")
if exist "C:\Users\Think\.workbuddy\projects"           (echo   [OK]   conversation store present) else (echo   [FAIL] conversation store & set "PF=0")
if exist "C:\Users\Think\.workbuddy\plugins"            (echo   [OK]   skills store present)       else (echo   [FAIL] skills store & set "PF=0")
for /f "usebackq delims=" %%N in (`powershell -NoProfile -Command "(Get-ChildItem 'E:\App\wbWork\MixNoticeApp\app\assets\audio' -Filter *.m4a -File -ErrorAction SilentlyContinue).Count"`) do set "M4A=%%N"
echo   [INFO] audio assets (m4a) in project: %M4A%
if "%PF%"=="0" (
  echo   [ABORT] integrity check failed - nothing was changed.
  echo [%DATE% %TIME%] ABORT: integrity check failed>>"%LOGFILE%"
  goto :SUMMARY
)

REM ---------------- GO-mode confirmation ----------------
if /i "%MODE%"=="GO" (
  echo.
  echo  *** REAL DELETION MODE ***
  echo  About to delete the whitelisted cache / backup / log items listed below.
  echo  This is NOT recoverable (no recycle bin).
  set "ANSWER="
  set /p "ANSWER=Type YES (uppercase) to continue, anything else to abort: "
  if /i not "!ANSWER!"=="YES" (
    echo   Aborted by user. Nothing was deleted.
    echo [%DATE% %TIME%] aborted at confirmation>>"%LOGFILE%"
    goto :SUMMARY
  )
)

REM ---------------- targets ----------------
echo.
echo --- Targets ---
call :PROCESS "%SESSION%\modify_backup"
call :PROCESS "C:\Users\Think\.workbuddy\logs\sandbox"
call :PROCESS "C:\Users\Think\.workbuddy\logs\2026-10-25"
call :PROCESS "C:\Users\Think\.workbuddy\logs\2026-10-26"
call :PROCESS "C:\Users\Think\AppData\Local\@genieworkbuddy-desktop-updater"
call :PROCESS "C:\Users\Think\AppData\Local\Temp\workbuddy-update-x64"
for /d %%D in ("C:\Users\Think\AppData\Local\Temp\flutter_tools.*") do call :PROCESS "%%~fD"
call :PROCESS "C:\Users\Think\AppData\Local\pip"
call :PROCESS "C:\Users\Think\AppData\Local\ms-playwright"

:SUMMARY
echo.
echo =================================================================
call :FREE
echo  Free space on C: before %FREE_BEFORE% MB  -^>  after %FREE_MB% MB
echo [%DATE% %TIME%] free before=%FREE_BEFORE% MB after=%FREE_MB% MB>>"%LOGFILE%"
echo.
echo --- Post-check ---
if exist "E:\App\wbWork\MixNoticeApp\app\lib\main.dart" (echo   [OK]   project source still intact) else (echo   [FAIL] project source missing)
if exist "C:\Users\Think\.workbuddy\projects"           (echo   [OK]   conversations still intact)   else (echo   [FAIL] conversations missing)
if exist "C:\Users\Think\.workbuddy\plugins"            (echo   [OK]   skills still intact)          else (echo   [FAIL] skills missing)
echo =================================================================
echo  Done. Log: %LOGFILE%
echo =================================================================
endlocal
exit /b 0

REM ================== subroutines ==================

:FREE
set "FREE_MB=0"
for /f "usebackq delims=" %%A in (`powershell -NoProfile -Command "$v=Get-Volume -DriveLetter C; [math]::Round($v.SizeRemaining/1MB,0)"`) do set "FREE_MB=%%A"
exit /b

:SIZE
set "SZ=0"
for /f "usebackq delims=" %%A in (`powershell -NoProfile -Command "$p='%~1'; $s=(Get-ChildItem -LiteralPath $p -Recurse -Force -File -ErrorAction SilentlyContinue ^| Measure-Object Length -Sum).Sum; if(-not $s){$s=0}; [math]::Round($s/1MB,0)"`) do set "SZ=%%A"
exit /b

:PROCESS
set "T=%~1"
if not defined T exit /b
echo.
echo ----------------------------------------------------------
echo  TARGET: %T%
echo %T% | findstr /i /b /c:"C:\Users\Think" >nul
if errorlevel 1 (
  echo   [SKIP] outside whitelist C:\Users\Think
  echo [%DATE% %TIME%] SKIP whitelist %T%>>"%LOGFILE%"
  exit /b
)
if not exist "%T%" (
  echo   [SKIP] not found, already clean
  exit /b
)
call :SIZE "%T%"
echo   size: %SZ% MB   mode: %MODE%
echo [%DATE% %TIME%] %MODE% %T% %SZ% MB>>"%LOGFILE%"
if /i "%MODE%"=="DRY" (
  echo   [DRY-RUN] would be deleted. Nothing changed.
  exit /b
)
if exist "%T%\" (
  rd /s /q "%T%" 2>nul
) else (
  del /f /q "%T%" 2>nul
)
if exist "%T%" (
  echo   [WARN] still exists - locked by a running process. Skipped safely.
  echo [%DATE% %TIME%] WARN locked %T%>>"%LOGFILE%"
) else (
  echo   [DELETED] %SZ% MB reclaimed
  echo [%DATE% %TIME%] DELETED %T% %SZ% MB>>"%LOGFILE%"
)
exit /b
