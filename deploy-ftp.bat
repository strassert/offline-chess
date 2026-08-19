@echo off
REM ---------------------------------------------------------------
REM deploy-ftp.bat
REM Laedt ALLE Dateien des main-Branch von GitHub (als ZIP),
REM entpackt sie und kopiert sie per FTP nach F:\web.
REM Login landet in C:\, daher wird per FTP auf F: gewechselt,
REM der Ordner web angelegt und alle Dateien dort hochgeladen.
REM Nutzt curl + PowerShell (Expand-Archive) + ftp.exe.
REM Die komplette FTP-Antwort wird zusaetzlich in eine Log-Datei
REM auf dem Desktop geschrieben (deploy-ftp.log).
REM
REM Hinweis: Das Repository muss oeffentlich sein, sonst liefert
REM GitHub beim ZIP-Download einen 404.
REM ---------------------------------------------------------------
setlocal

REM --- Konfiguration ---------------------------------------------
set "FTPHOST=strassert.brdev.net"
set "FTPUSER=a"
set "FTPPASS=123"
set "REPO=strassert/offline-chess"
set "BRANCH=main"
set "LOGFILE=%USERPROFILE%\Desktop\deploy-ftp.log"
REM ---------------------------------------------------------------

set "ZIPURL=https://github.com/%REPO%/archive/refs/heads/%BRANCH%.zip"
set "WORKDIR=%TEMP%\offline-chess-dl"
set "ZIPFILE=%TEMP%\offline-chess-%BRANCH%.zip"
set "FTPSCRIPT=%TEMP%\deploy-ftp.txt"

REM Der ZIP-Ordner heisst <reponame>-<branch>, z.B. offline-chess-main.
for %%R in (%REPO%) do set "REPONAME=%%~nxR"
set "SRCDIR=%WORKDIR%\%REPONAME%-%BRANCH%"

echo Pruefe curl...
where curl >nul 2>&1
if errorlevel 1 (
    echo FEHLER: 'curl' wurde nicht gefunden ^(altes Windows?^).
    pause
    exit /b 1
)

echo Raeume altes Arbeitsverzeichnis auf...
if exist "%WORKDIR%" rmdir /s /q "%WORKDIR%"
if exist "%ZIPFILE%" del /q "%ZIPFILE%"

echo Lade %BRANCH%.zip von GitHub...
curl -fsSL "%ZIPURL%" -o "%ZIPFILE%"
if errorlevel 1 (
    echo FEHLER: Download fehlgeschlagen ^(Repo privat oder Branch falsch?^).
    pause
    exit /b 1
)

echo Entpacke ZIP...
powershell -NoProfile -Command "Expand-Archive -LiteralPath '%ZIPFILE%' -DestinationPath '%WORKDIR%' -Force"
if errorlevel 1 (
    echo FEHLER: Entpacken fehlgeschlagen.
    pause
    exit /b 1
)
if not exist "%SRCDIR%" (
    echo FEHLER: Erwarteter Ordner "%SRCDIR%" nicht gefunden.
    pause
    exit /b 1
)

echo Erzeuge FTP-Skript...
> "%FTPSCRIPT%" echo open %FTPHOST%
>>"%FTPSCRIPT%" echo user %FTPUSER% %FTPPASS%
>>"%FTPSCRIPT%" echo binary
>>"%FTPSCRIPT%" echo prompt
>>"%FTPSCRIPT%" echo cd F:
>>"%FTPSCRIPT%" echo mkdir web
>>"%FTPSCRIPT%" echo cd web
>>"%FTPSCRIPT%" echo lcd "%SRCDIR%"
>>"%FTPSCRIPT%" echo mput *
>>"%FTPSCRIPT%" echo bye

echo Lade alle Dateien per FTP hoch nach F:\web ...
echo ------------------------------------------------------------
ftp -n -s:"%FTPSCRIPT%" > "%LOGFILE%" 2>&1
type "%LOGFILE%"
echo ------------------------------------------------------------
echo Log gespeichert unter: %LOGFILE%

echo Raeume auf...
del "%FTPSCRIPT%" >nul 2>&1
del "%ZIPFILE%" >nul 2>&1
rmdir /s /q "%WORKDIR%" >nul 2>&1
echo Fertig.
pause
endlocal
