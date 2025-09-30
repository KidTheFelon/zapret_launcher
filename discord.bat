@echo off
cd /d "%~dp0"
rem Auto-check and update before running Discord
call update_checker.bat auto

rem Starting ALT3 from current folder (first bypass)
echo Starting general (ALT3).bat...
if exist "general (ALT3).bat" (
    start "general-alt3" /min "general (ALT3).bat"
    timeout /t 8 /nobreak > nul
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-CimInstance Win32_Process | Where-Object { $_.Name -ieq 'cmd.exe' -and $_.CommandLine -like '*general (ALT3).bat*' } | ForEach-Object { try { Stop-Process -Id $_.ProcessId -Force -ErrorAction Stop } catch {} }"
) else (
    echo ALT3 файл не найден
)

rem Searching for Discord in standard locations
echo Searching for Discord in standard locations...
set "DISCORD_FOUND="

rem Searching for Discord in app-* (actual versions)
for /d %%D in ("%LOCALAPPDATA%\Discord\app-*") do (
    if exist "%%D\Discord.exe" (
        start "" "%%D\Discord.exe"
        set "DISCORD_FOUND=1"
        goto :discord_found
    )
)

rem Searching for Discord in other standard locations
echo Searching for Discord in other standard locations...
for %%P in (
    "%LOCALAPPDATA%\Discord\Discord.exe"
    "%LOCALAPPDATA%\Discord\Update.exe"
    "%PROGRAMFILES%\Discord\Discord.exe"
    "%PROGRAMFILES(X86)%\Discord\Discord.exe"
    "%APPDATA%\Discord\Discord.exe"
    ) do (
    if exist "%%P" (
        start "" "%%P"
        set "DISCORD_FOUND=1"
        goto :discord_found
    )
)

rem If not found, try via Start Menu
echo Trying to start Discord via Start Menu...
start "" discord

:discord_found
exit
