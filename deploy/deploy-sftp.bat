@echo off
setlocal enabledelayedexpansion
rem ---------------------------------------------------------------
rem  Laedt das Schachspiel per SFTP auf den Webspace.
rem
rem  Das Passwort wird bei jedem Lauf abgefragt und nirgends gespeichert.
rem  In deploy.config.bat stehen nur Serveradresse, Benutzer und Zielordner.
rem
rem  Bevorzugt wird das in Windows enthaltene sftp - es fragt das Passwort
rem  selbst ab, verdeckt und ohne dass dieses Skript es je zu sehen bekommt.
rem  Nur falls sftp fehlt, springt WinSCP ein.
rem ---------------------------------------------------------------

cd /d "%~dp0.."
set "ROOT=%CD%"

if exist "%~dp0deploy.config.bat" (
  call "%~dp0deploy.config.bat"
) else (
  echo.
  echo   Es fehlt: deploy\deploy.config.bat
  echo   Bitte deploy\deploy.config.example.bat kopieren, umbenennen
  echo   und den Benutzernamen eintragen.
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
for %%F in (chess.html dashboard.html php\.htaccess php\api\state.php php\api\hist.php php\api\speed.php php\api\health.php php\api\reset.php php\api\.htaccess) do (
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

echo.
echo === Uebertragung nach %SFTP_USER%@%SFTP_HOST%%SFTP_DIR% ===

where sftp >nul 2>&1
if not errorlevel 1 goto :usesftp

set "WINSCP="
if exist "%ProgramFiles(x86)%\WinSCP\WinSCP.com" set "WINSCP=%ProgramFiles(x86)%\WinSCP\WinSCP.com"
if exist "%ProgramFiles%\WinSCP\WinSCP.com" set "WINSCP=%ProgramFiles%\WinSCP\WinSCP.com"
if not defined WINSCP (
  where WinSCP.com >nul 2>&1 && set "WINSCP=WinSCP.com"
)
if defined WINSCP goto :usewinscp

echo.
echo   Weder sftp noch WinSCP gefunden.
echo   Entweder unter Windows-Einstellungen ^> Apps ^> Optionale Features
echo   den "OpenSSH-Client" nachinstallieren oder WinSCP ^(winscp.net^).
pause
exit /b 1


rem ================= Weg 1: Windows-eigenes sftp ==================
:usesftp
set "LIST=%TEMP%\chess-sftp-%RANDOM%.txt"
> "%LIST%" echo cd %SFTP_DIR%
>> "%LIST%" echo lcd "%ROOT%"
>> "%LIST%" echo put dashboard.html index.html
>> "%LIST%" echo put chess.html chess.html
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
>> "%LIST%" echo put hist.php
>> "%LIST%" echo put speed.php
>> "%LIST%" echo put health.php
>> "%LIST%" echo put reset.php
>> "%LIST%" echo put .htaccess .htaccess
rem Schreibrecht fuer die Zustandsdatei; scheitert auf manchen Tarifen - egal
>> "%LIST%" echo -chmod 777 .
>> "%LIST%" echo bye

echo   ^(sftp fragt das Passwort gleich selbst ab^)
rem -b schaltet die Passwortabfrage sonst ab
sftp -oBatchMode=no -b "%LIST%" %SFTP_USER%@%SFTP_HOST%
set "RC=!ERRORLEVEL!"
del "%LIST%" >nul 2>&1
goto :done


rem ============ Weg 2: WinSCP, falls sftp fehlt ===================
:usewinscp
echo   ^(WinSCP - Passwort wird verdeckt abgefragt^)
set "PW="
for /f "usebackq delims=" %%P in (`powershell -NoProfile -Command ^
  "$s=Read-Host -AsSecureString 'Passwort'; [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($s))"`) do set "PW=%%P"
if "!PW!"=="" (
  echo   Kein Passwort eingegeben - abgebrochen.
  pause
  exit /b 1
)

rem WinSCP nimmt das Passwort nur aus Befehlszeile oder Skriptdatei entgegen.
rem Die Datei wird direkt nach dem Lauf wieder geloescht.
set "WS=%TEMP%\chess-winscp-%RANDOM%.txt"
> "%WS%" echo option batch continue
>> "%WS%" echo option confirm off
>> "%WS%" echo open sftp://%SFTP_USER%:!PW!@%SFTP_HOST%/ -hostkey="*"
>> "%WS%" echo cd %SFTP_DIR%
>> "%WS%" echo lcd "%ROOT%"
>> "%WS%" echo put dashboard.html index.html
>> "%WS%" echo put chess.html chess.html
if defined WITHENGINE (
  >> "%WS%" echo put stockfish-18-lite-single.js
  >> "%WS%" echo put stockfish-18-lite-single.wasm
)
>> "%WS%" echo put php\.htaccess .htaccess
>> "%WS%" echo mkdir api
>> "%WS%" echo cd api
>> "%WS%" echo lcd "%ROOT%\php\api"
>> "%WS%" echo put state.php
>> "%WS%" echo put hist.php
>> "%WS%" echo put speed.php
>> "%WS%" echo put health.php
>> "%WS%" echo put reset.php
>> "%WS%" echo put .htaccess .htaccess
>> "%WS%" echo chmod 777 .
>> "%WS%" echo exit

"%WINSCP%" /script="%WS%"
set "RC=!ERRORLEVEL!"
set "PW="
del "%WS%" >nul 2>&1
goto :done


:done
echo.
if not "%RC%"=="0" (
  echo === Fehlgeschlagen ^(Code %RC%^) ===
  echo   Benutzername, Serveradresse und Passwort pruefen.
  pause
  exit /b %RC%
)

echo === Fertig ===
echo.
echo   Startseite: https://%SFTP_HOST%/
echo   Schach:     https://%SFTP_HOST%/chess.html
echo   Pruefen:   https://%SFTP_HOST%/api/health.php
echo              muss {"ok":true,...,"writable":true} liefern.
echo.
pause
