@echo off
setlocal enabledelayedexpansion
rem ---------------------------------------------------------------
rem  Uebertraegt das Schachspiel per FTP auf die B&R-Steuerung.
rem
rem  Holt die aktuellen Dateien von GitHub und legt sie im
rem  Webverzeichnis der Steuerung ab (Vorgabe F:\web).
rem  Benutzername und Passwort werden bei jedem Lauf abgefragt
rem  und nirgends gespeichert.
rem
rem  ACHTUNG: Auf manchen Steuerungen verweigert der FTP-Zugang das
rem  Schreiben auf der USER-Partition ("550 Permission denied").
rem  Klappt das hier nicht, bleibt der Weg ueber das
rem  Automation-Studio-Projekt (Datei in USER\web, dann Transfer).
rem ---------------------------------------------------------------

set "PLCHOST=strassert.brdev.net"
set "PLCDRIVE=F:"
set "PLCDIR=web"
set "REPO=strassert/offline-chess"
set "BRANCH=main"
set "LOGFILE=%TEMP%\deploy-plc.log"

rem Nur diese Dateien braucht die Steuerung
set "FILES=chess.html response.asp stockfish-18-lite-single.js stockfish-18-lite-single.wasm"

echo.
echo === Schach auf die Steuerung uebertragen ===
echo   Ziel:   %PLCHOST%  ^-^>  %PLCDRIVE%\%PLCDIR%
echo   Quelle: GitHub %REPO% (%BRANCH%)
echo.

where curl >nul 2>&1
if errorlevel 1 (
  echo   FEHLER: curl fehlt ^(sehr altes Windows^).
  pause
  exit /b 1
)
where ftp >nul 2>&1
if errorlevel 1 (
  echo   FEHLER: ftp.exe fehlt. Unter Windows-Features
  echo   "FTP-Client" nachinstallieren.
  pause
  exit /b 1
)

rem --- Dateien von GitHub holen -----------------------------------
set "WORK=%TEMP%\plc-chess-%RANDOM%"
mkdir "%WORK%" 2>nul
echo === Dateien laden ===
for %%F in (%FILES%) do (
  echo   %%F
  curl -fsSL "https://raw.githubusercontent.com/%REPO%/%BRANCH%/%%F" -o "%WORK%\%%F"
  if errorlevel 1 (
    echo   FEHLER beim Laden von %%F
    rmdir /s /q "%WORK%" >nul 2>&1
    pause
    exit /b 1
  )
)

rem Grober Plausibilitaetstest: die Engine ist mehrere MB gross.
for %%F in ("%WORK%\stockfish-18-lite-single.wasm") do set "WSIZE=%%~zF"
if !WSIZE! LSS 1000000 (
  echo.
  echo   FEHLER: Die Engine-Datei ist nur !WSIZE! Bytes gross -
  echo   der Download ist unvollstaendig.
  rmdir /s /q "%WORK%" >nul 2>&1
  pause
  exit /b 1
)

rem --- Zugangsdaten abfragen --------------------------------------
echo.
set "PLCUSER="
set /p "PLCUSER=Benutzername FTP: "
if "!PLCUSER!"=="" (
  echo   Kein Benutzername - abgebrochen.
  rmdir /s /q "%WORK%" >nul 2>&1
  exit /b 1
)
set "PLCPASS="
for /f "usebackq delims=" %%P in (`powershell -NoProfile -Command ^
  "$s=Read-Host -AsSecureString 'Passwort'; [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($s))"`) do set "PLCPASS=%%P"
if "!PLCPASS!"=="" (
  echo   Kein Passwort - abgebrochen.
  rmdir /s /q "%WORK%" >nul 2>&1
  exit /b 1
)

rem --- FTP-Befehle aufbauen ---------------------------------------
rem ftp.exe nimmt Zugangsdaten nur aus der Skriptdatei entgegen.
rem Die Datei wird direkt nach der Uebertragung geloescht.
set "SCRIPT=%TEMP%\plc-ftp-%RANDOM%.txt"
> "%SCRIPT%" echo open %PLCHOST%
>> "%SCRIPT%" echo user !PLCUSER! !PLCPASS!
>> "%SCRIPT%" echo binary
>> "%SCRIPT%" echo prompt
>> "%SCRIPT%" echo lcd "%WORK%"
>> "%SCRIPT%" echo cd %PLCDRIVE%
>> "%SCRIPT%" echo mkdir %PLCDIR%
>> "%SCRIPT%" echo cd %PLCDIR%
for %%F in (%FILES%) do >> "%SCRIPT%" echo put %%F
>> "%SCRIPT%" echo bye

echo.
echo === Uebertragung ===
ftp -n -s:"%SCRIPT%" > "%LOGFILE%" 2>&1
set "PLCPASS="
del "%SCRIPT%" >nul 2>&1
type "%LOGFILE%"
rmdir /s /q "%WORK%" >nul 2>&1

rem --- Ergebnis pruefen -------------------------------------------
rem ftp.exe meldet Fehler nicht ueber den Rueckgabewert, daher wird
rem im Protokoll nach den typischen Fehlercodes gesucht.
echo.
findstr /i /c:"530" /c:"550" /c:"Permission denied" /c:"cannot" "%LOGFILE%" >nul
if not errorlevel 1 (
  echo === Es gab Fehlermeldungen ===
  echo   530 = Anmeldung abgelehnt, 550 = kein Schreibrecht.
  echo   Protokoll: %LOGFILE%
  echo.
  echo   Bei 550 auf der USER-Partition hilft nur der Weg ueber das
  echo   Automation-Studio-Projekt ^(Datei in USER\web, dann Transfer^).
  pause
  exit /b 1
)

echo === Uebertragen ===
echo.
echo   Pruefe http://%PLCHOST%/chess.html ...
for /f %%C in ('curl -s -o nul -w "%%{http_code}" "http://%PLCHOST%/chess.html"') do set "CODE=%%C"
if "!CODE!"=="200" (
  echo   Antwort 200 - die Seite wird ausgeliefert.
) else (
  echo   Antwort !CODE! - noch nicht erreichbar.
  echo   Bei 404 den MIME-Typ fuer html pruefen oder ob %PLCDRIVE%\%PLCDIR%
  echo   wirklich das Webverzeichnis der Steuerung ist.
)

echo.
echo   Spielen:   http://%PLCHOST%/chess.html?plc
echo   Im Browser mit Strg+F5 laden, sonst zeigt er den alten Stand.
echo.
pause
