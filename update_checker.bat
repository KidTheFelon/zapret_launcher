@echo off
setlocal EnableDelayedExpansion
chcp 65001 > nul

rem Configuration
set "GITHUB_VERSION_URL=https://raw.githubusercontent.com/Flowseal/zapret-discord-youtube/main/.service/version.txt"
set "GITHUB_RELEASE_URL=https://github.com/Flowseal/zapret-discord-youtube/releases/tag/"
set "GITHUB_DOWNLOAD_URL=https://github.com/Flowseal/zapret-discord-youtube/releases/latest/download/zapret-discord-youtube-"
set "GITHUB_VERSION_FILE_URL=https://raw.githubusercontent.com/Flowseal/zapret-discord-youtube/main/.service/version.txt"
set "DOWNLOAD_DIR=%~dp0downloads"
set "VERSION_FILE=%DOWNLOAD_DIR%\version.txt"
set "LOCAL_VERSION_FILE=%~dp0version.txt"

rem Creating download folder
if not exist "%DOWNLOAD_DIR%" mkdir "%DOWNLOAD_DIR%"

rem Getting local version
echo Checking for updates...

rem Reading local version from file
if exist "%LOCAL_VERSION_FILE%" (
    echo [INFO] Reading local version from file
    for /f "delims=" %%A in ('type "%LOCAL_VERSION_FILE%"') do set "LOCAL_VERSION=%%A"
) else (
    echo [WARNING] Local version file not found, creating default
    echo 1.0.0 > "%LOCAL_VERSION_FILE%"
    set "LOCAL_VERSION=1.0.0"
)

rem Cleaning local version from extra characters
set "LOCAL_VERSION=%LOCAL_VERSION: =%"
set "LOCAL_VERSION=%LOCAL_VERSION:`r=%"
set "LOCAL_VERSION=%LOCAL_VERSION:`n=%"

rem Network diagnostics
echo [DIAGNOSTICS] Testing network connectivity...
ping -n 1 8.8.8.8 >nul 2>&1
if !errorlevel! neq 0 (
    echo [WARNING] No internet connection detected
)

rem Downloading current version from GitHub
echo [DOWNLOAD] Downloading current version from GitHub...
if exist "%SystemRoot%\System32\curl.exe" (
    curl -L --connect-timeout 10 --max-time 30 -o "%VERSION_FILE%" "%GITHUB_VERSION_FILE_URL%" >nul 2>&1
) else (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "$url='%GITHUB_VERSION_FILE_URL%';$out='%VERSION_FILE%';try{Invoke-WebRequest -Uri $url -OutFile $out -TimeoutSec 15 -UseBasicParsing ^| Out-Null}catch{Write-Host '[ERROR] Network timeout or blocked'; exit 1}"

)

rem Reading version from downloaded file or from GitHub
if exist "%VERSION_FILE%" (
    echo [INFO] Using downloaded version file
    for /f "delims=" %%A in ('type "%VERSION_FILE%"') do set "GITHUB_VERSION=%%A"
) else (
    echo [INFO] Downloading version from GitHub directly
    for /f "delims=" %%A in ('powershell -command "try{(Invoke-WebRequest -Uri \"%GITHUB_VERSION_URL%\" -Headers @{\"Cache-Control\"=\"no-cache\"} -TimeoutSec 15 -UseBasicParsing).Content.Trim()}catch{Write-Host '[ERROR] GitHub blocked or timeout'; exit 1}" 2^>nul') do set "GITHUB_VERSION=%%A"
)

rem Error handling
if not defined GITHUB_VERSION (
    echo [ERROR] Failed to fetch version from GitHub
    if "%1"=="silent" exit /b 1
    pause
    exit /b 1
)

rem Cleaning version from extra characters
set "GITHUB_VERSION=%GITHUB_VERSION: =%"
set "GITHUB_VERSION=%GITHUB_VERSION:`r=%"
set "GITHUB_VERSION=%GITHUB_VERSION:`n=%"

echo [INFO] Local version: %LOCAL_VERSION%
echo [INFO] GitHub version: %GITHUB_VERSION%

rem Version comparison
if "%LOCAL_VERSION%"=="%GITHUB_VERSION%" (
    echo [INFO] Latest version already installed: %LOCAL_VERSION%
    if exist "%DOWNLOAD_DIR%" (
        echo [CLEANUP] Removing downloads folder: %DOWNLOAD_DIR%
        rmdir /s /q "%DOWNLOAD_DIR%"
    )
    if "%1"=="silent" exit /b 0
    if "%1"=="auto" exit /b 0
    pause
    exit /b 0
)

echo [UPDATE] New version available: %GITHUB_VERSION%
echo [INFO] Current version: %LOCAL_VERSION%
echo [INFO] Release page: %GITHUB_RELEASE_URL%%GITHUB_VERSION%

rem Working modes
if "%1"=="auto" goto auto_download
if "%1"=="silent" goto silent_mode
goto interactive_mode

:auto_download
echo [AUTO] Downloading update automatically...
call :download_update
exit /b 0

rem =====================
rem Stop conflicting services and processes (WinDivert, GoodbyeDPI, winws)
rem =====================
:stop_conflicting
echo [STOP] Stopping conflicting services/processes...
sc stop "WinDivert" >nul 2>&1
sc stop "WinDivert14" >nul 2>&1
sc stop "GoodbyeDPI" >nul 2>&1
taskkill /IM winws.exe /F >nul 2>&1
taskkill /IM WinDivert.exe /F >nul 2>&1
timeout /t 1 >nul 2>&1
sc query "WinDivert" >nul 2>&1 && sc delete "WinDivert" >nul 2>&1
sc query "WinDivert14" >nul 2>&1 && sc delete "WinDivert14" >nul 2>&1
sc query "GoodbyeDPI" >nul 2>&1 && sc delete "GoodbyeDPI" >nul 2>&1
exit /b 0

rem =====================
rem IPSET update (only after successful extraction)
rem =====================
:ipset_update
set "LIST_FILE=%~dp0lists\ipset-all.txt"
set "IPSET_URL=https://raw.githubusercontent.com/Flowseal/zapret-discord-youtube/refs/heads/main/.service/ipset-service.txt"
if exist "%SystemRoot%\System32\curl.exe" (
    curl -L -o "%LIST_FILE%" "%IPSET_URL%" >nul 2>&1
) else (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "$url='%IPSET_URL%';$out='%LIST_FILE%';$dir=[System.IO.Path]::GetDirectoryName($out);if(-not(Test-Path -LiteralPath $dir)){New-Item -ItemType Directory -Path $dir | Out-Null};$res=Invoke-WebRequest -Uri $url -TimeoutSec 10 -UseBasicParsing; if($res.StatusCode -eq 200){$res.Content | Out-File -FilePath $out -Encoding UTF8}else{exit 1}"
)
if !errorlevel! neq 0 (
    echo [WARN] ipset update failed (network or write error)
) else (
    echo [SUCCESS] ipset list updated: %LIST_FILE%
)
exit /b 0

rem =====================
rem Fallback: Expand-Archive for ZIP (works when Shell handler fails)
rem =====================
:fallback_extract_zip
set "_ARCHIVE=%~1"
set "_TARGET=%~2"
echo [FALLBACK] Using Expand-Archive
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop';$src=[System.IO.Path]::GetFullPath('%_ARCHIVE%');$dst=[System.IO.Path]::GetFullPath('%_TARGET%');if(-not(Test-Path -LiteralPath $dst)){New-Item -ItemType Directory -Path $dst | Out-Null};Expand-Archive -Path $src -DestinationPath $dst -Force;"
exit /b %errorlevel%

:silent_mode
echo [SILENT] Update available but not downloading
exit /b 2

:interactive_mode
echo.
set "CHOICE="
set /p "CHOICE=Download update? (Y/N) [Y]: "
if "%CHOICE%"=="" set "CHOICE=Y"
if /i "%CHOICE%"=="y" set "CHOICE=Y"

if /i "%CHOICE%"=="Y" (
    call :download_update
) else (
    echo Update cancelled
    pause
)
exit /b 0

:download_update
echo [DOWNLOAD] Starting download...

rem Skipping version file update here; version will be written after successful extraction

rem Downloading main archive
echo [DOWNLOAD] Downloading main archive...
set "ARCHIVE_PATH=%DOWNLOAD_DIR%\zapret-discord-youtube-%GITHUB_VERSION%.zip"
set "EXTRACT_DIR=%~dp0"
if exist "%SystemRoot%\System32\curl.exe" (
    curl -L --connect-timeout 15 --max-time 120 -o "%ARCHIVE_PATH%" "%GITHUB_DOWNLOAD_URL%%GITHUB_VERSION%.zip"
    if !errorlevel!==0 (
        echo [SUCCESS] Downloaded to: %ARCHIVE_PATH%
        echo [EXTRACT] Extracting to: %EXTRACT_DIR%
        call :extract_archive "%ARCHIVE_PATH%" "%EXTRACT_DIR%"
        if !errorlevel! neq 0 (
            echo [WARN] Extraction failed. Stopping services and retrying...
            call :stop_conflicting
            call :extract_archive "%ARCHIVE_PATH%" "%EXTRACT_DIR%"
            if !errorlevel! neq 0 (
                echo [WARN] Retry failed. Trying ZIP fallback extractor...
                call :fallback_extract_zip "%ARCHIVE_PATH%" "%EXTRACT_DIR%"
                if !errorlevel! neq 0 (
                    echo [ERROR] Extraction failed after all attempts
                    if exist "%TEMP%\update_checker_extract_error.log" (
                        echo [DETAILS]
                        type "%TEMP%\update_checker_extract_error.log"
                    )
                    exit /b 1
                )
            )
        )
        echo [SUCCESS] Extraction completed
        call :ipset_update
        echo %GITHUB_VERSION% > "%LOCAL_VERSION_FILE%"
        echo [SUCCESS] Local version updated to: %GITHUB_VERSION%
        if exist "%DOWNLOAD_DIR%" (
            echo [CLEANUP] Removing downloads folder: %DOWNLOAD_DIR%
            rmdir /s /q "%DOWNLOAD_DIR%"
        )
    ) else (
        echo [ERROR] Download failed with curl
        exit /b 1
    )
) else (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "$url='%GITHUB_DOWNLOAD_URL%%GITHUB_VERSION%.zip';$out='%ARCHIVE_PATH%';try{$res=Invoke-WebRequest -Uri $url -OutFile $out -TimeoutSec 60 -UseBasicParsing;if($res.StatusCode -eq 200){Write-Host '[SUCCESS] Downloaded to:' $out}else{Write-Host '[ERROR] HTTP' $res.StatusCode; exit 1}}catch{Write-Host '[ERROR] Download timeout or blocked'; exit 1}"
    
    if !errorlevel! neq 0 (
        echo [ERROR] Download failed with PowerShell
        exit /b 1
    )
    echo [EXTRACT] Extracting to: %EXTRACT_DIR%
    call :extract_archive "%ARCHIVE_PATH%" "%EXTRACT_DIR%"
    if !errorlevel! neq 0 (
        echo [WARN] Extraction failed. Stopping services and retrying...
        call :stop_conflicting
        call :extract_archive "%ARCHIVE_PATH%" "%EXTRACT_DIR%"
        if !errorlevel! neq 0 (
            echo [WARN] Retry failed. Trying ZIP fallback extractor...
            call :fallback_extract_zip "%ARCHIVE_PATH%" "%EXTRACT_DIR%"
            if !errorlevel! neq 0 (
                echo [ERROR] Extraction failed after all attempts
                if exist "%TEMP%\update_checker_extract_error.log" (
                    echo [DETAILS]
                    type "%TEMP%\update_checker_extract_error.log"
                )
                exit /b 1
            )
        )
    )
    echo [SUCCESS] Extraction completed
    call :ipset_update
    echo %GITHUB_VERSION% > "%LOCAL_VERSION_FILE%"
    echo [SUCCESS] Local version updated to: %GITHUB_VERSION%
    if exist "%DOWNLOAD_DIR%" (
        echo [CLEANUP] Removing downloads folder: %DOWNLOAD_DIR%
        rmdir /s /q "%DOWNLOAD_DIR%"
    )
)

rem Opening download folder
if "%2"=="open" (
    start "" "%DOWNLOAD_DIR%"
)

goto :eof

rem =====================
rem Extraction function(s) - Pure PowerShell, no external tools
rem =====================
:extract_archive
set "_ARCHIVE=%~1"
set "_TARGET=%~2"

if not exist "%_ARCHIVE%" (
    echo [ERROR] Archive not found: %_ARCHIVE%
    exit /b 2
)

rem Determining archive type by extension
set "_EXT=%~x1"
set "_EXT=%_EXT:.=%"

if /i "%_EXT%"=="zip" (
    echo [EXTRACT] Using Shell.Application for ZIP (Unicode-safe)
    powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop';$src=[System.IO.Path]::GetFullPath('%_ARCHIVE%');$dst=[System.IO.Path]::GetFullPath('%_TARGET%');$log=[System.IO.Path]::Combine($env:TEMP,'update_checker_extract_error.log');if(Test-Path $log){Remove-Item -Force $log -ErrorAction SilentlyContinue};if(-not(Test-Path -LiteralPath $dst)){New-Item -ItemType Directory -Path $dst | Out-Null};try{$sh=New-Object -ComObject Shell.Application;$dstFld=$sh.NameSpace($dst);if($null -eq $dstFld){throw 'Destination not accessible'};$srcFld=$sh.NameSpace($src);if($null -eq $srcFld){throw 'ZIP shell handler not available'};$flags=0x10+0x04+0x100+0x200+0x400;$dstFld.CopyHere($srcFld.Items(),$flags);$deadline=(Get-Date).AddSeconds(90);Start-Sleep -Milliseconds 300;while((Get-Date) -lt $deadline){if($dstFld.Items().Count -gt 0){break};Start-Sleep -Milliseconds 300};$expected=Join-Path $dst 'bin\\WinDivert.dll';if(-not(Test-Path -LiteralPath $expected)){'Extraction seems incomplete or blocked. Check file locks/permissions.' | Out-File -FilePath $log -Encoding UTF8;exit 8};exit 0}catch{$_.ToString() | Out-File -FilePath $log -Encoding UTF8;if($_.Exception -is [System.UnauthorizedAccessException]){exit 5}elseif($_.Exception -is [System.IO.IOException]){exit 6}else{exit 7}}"
)

if not !errorlevel!==0 (
    echo [ERROR] PowerShell extraction failed
    if exist "%TEMP%\update_checker_extract_error.log" (
        echo [DETAILS]
        type "%TEMP%\update_checker_extract_error.log"
    )
    exit /b 3
)

exit /b 0
