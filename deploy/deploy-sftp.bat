@echo off
setlocal enabledelayedexpansion
rem ---------------------------------------------------------------
rem  Laedt das Schachspiel per SFTP auf den Webspace.
rem
rem  Zugangsdaten kommen aus deploy.config.bat (liegt neben dieser Datei
rem  und wird bewusst nicht ins Repository aufgenommen).
rem  Vorlage: deploy.config.example.bat kopieren und ausfuellen.
rem
rem  Nutzt WinSCP, wenn vorhanden (laeuft dann ohne Rueckfrage durch),
rem  sonst das in Windows enthaltene sftp - das fragt einmal nach dem
rem  Passwort.
rem ---------------------------------------------------------------

cd /d "%~dp0.."
set "ROOT=%CD%"

if exist "%~dp0deploy.config.bat" (
  call "%~dp0deploy.config.bat"
) else (
  echo.
  echo   Es fehlt: deploy\deploy.config.bat
  echo   Bitte deploy\deploy.config.example.bat kopieren, umbenennen
  echo   und die Zugangsdaten eintragen.
  echo.
  pause
  exit /b 1
)

if "%SFTP_HOST%"=="" set "SFTP_HOST=gg2.members.cablelink.at"
if "%SFTP_DIR%"==""  set "SFTP_DIR=/"

if "%SFTP_USER%"=="" (
  echo   In deploy.config.bat fehlt SFTP_USER.
  pause
  exit /b 1
)

echo.
echo === Dateien pruefen ===
set "MISSING="
for %%F in (chess.html php\.htaccess php\api\state.php php\api\health.php php\api\reset.php php\api\.htaccess) do (
  if not exist "%ROOT%\%%F" set "MISSING=!MISSING! %%F"
)
if not "!MISSING!"=="" (
  echo   Nicht gefunden:!MISSING!
  echo   Das Skript muss aus dem Projektordner heraus laufen.
  pause
  exit /b 1
)
if exist "%ROOT%\stockfish-18-lite-single.wasm" (
  set "WITHENGINE=1"
) else (
  set "WITHENGINE="
  echo   Hinweis: Engine-Dateien fehlen - gespielt werden kann, die Analyse bleibt aus.
)

rem --- Befehlsliste fuer die Uebertragung aufbauen -----------------
set "LIST=%TEMP%\chess-sftp-%RANDOM%.txt"
> "%LIST%" echo cd %SFTP_DIR%
>> "%LIST%" echo lcd "%ROOT%"
>> "%LIST%" echo put chess.html index.html
if defined WITHENGINE (
  >> "%LIST%" echo put stockfish-18-lite-single.js
  >> "%LIST%" echo put stockfish-18-lite-single.wasm
)
>> "%LIST%" echo lcd "%ROOT%\php"
>> "%LIST%" echo put .htaccess .htaccess
>> "%LIST%" echo -mkdir api
>> "%LIST%" echo cd api
>> "%LIST%" echo lcd "%ROOT%\php\api"
>> "%LIST%" echo put state.php
>> "%LIST%" echo put health.php
>> "%LIST%" echo put reset.php
>> "%LIST%" echo put .htaccess .htaccess
rem Schreibrecht fuer die Zustandsdatei; scheitert auf manchen Tarifen - egal
>> "%LIST%" echo -chmod 777 .
>> "%LIST%" echo bye

rem --- WinSCP bevorzugen -------------------------------------------
set "WINSCP="
if exist "%ProgramFiles(x86)%\WinSCP\WinSCP.com" set "WINSCP=%ProgramFiles(x86)%\WinSCP\WinSCP.com"
if exist "%ProgramFiles%\WinSCP\WinSCP.com" set "WINSCP=%ProgramFiles%\WinSCP\WinSCP.com"
if not defined WINSCP (
  where WinSCP.com >nul 2>&1 && set "WINSCP=WinSCP.com"
)

echo.
echo === Uebertragung nach %SFTP_USER%@%SFTP_HOST%%SFTP_DIR% ===

rem Verkettetes "if a if b (..) else (..)" bindet das else an das innere if -
rem darum die Entscheidung vorher in ein Kennzeichen aufloesen.
set "USEWINSCP="
if defined WINSCP if not "%SFTP_PASS%"=="" set "USEWINSCP=1"

if defined USEWINSCP (
  echo   ^(WinSCP, laeuft ohne Rueckfrage^)
  "%WINSCP%" /log="%TEMP%\chess-winscp.log" /command ^
    "option batch continue" ^
    "option confirm off" ^
    "open sftp://%SFTP_USER%:%SFTP_PASS%@%SFTP_HOST%/ -hostkey=""*""" ^
    "cd %SFTP_DIR%" ^
    "lcd ""%ROOT%""" ^
    "put chess.html index.html" ^
    "put stockfish-18-lite-single.js" ^
    "put stockfish-18-lite-single.wasm" ^
    "put php\.htaccess .htaccess" ^
    "mkdir api" ^
    "cd api" ^
    "lcd ""%ROOT%\php\api""" ^
    "put state.php" ^
    "put health.php" ^
    "put reset.php" ^
    "put .htaccess .htaccess" ^
    "chmod 777 ." ^
    "exit"
  set "RC=!ERRORLEVEL!"
) else (
  echo   ^(Windows-sftp - das Passwort wird gleich abgefragt^)
  where sftp >nul 2>&1
  if errorlevel 1 (
    echo.
    echo   Weder WinSCP noch sftp gefunden.
    echo   Entweder WinSCP installieren ^(winscp.net^) oder unter
    echo   Windows-Einstellungen den "OpenSSH-Client" nachinstallieren.
    del "%LIST%" >nul 2>&1
    pause
    exit /b 1
  )
  sftp -oBatchMode=no -b "%LIST%" %SFTP_USER%@%SFTP_HOST%
  set "RC=!ERRORLEVEL!"
)

del "%LIST%" >nul 2>&1

echo.
if not "%RC%"=="0" (
  echo === Fehlgeschlagen ^(Code %RC%^) ===
  echo   Zugangsdaten pruefen. Bei WinSCP steht mehr im Protokoll:
  echo   %TEMP%\chess-winscp.log
  pause
  exit /b %RC%
)

echo === Fertig ===
echo.
echo   Aufrufen:  https://%SFTP_HOST%/
echo   Pruefen:   https://%SFTP_HOST%/api/health.php
echo              muss {"ok":true,...,"writable":true} liefern.
echo.
pause
