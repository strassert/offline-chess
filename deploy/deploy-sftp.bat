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

rem ---------------------------------------------------------------
rem  Vor der Uebertragung fragen, ob der Stand von GitHub geholt
rem  werden soll - sonst landet leicht eine alte Fassung auf dem
rem  Webspace. In deploy.config.bat laesst sich das mit
rem      set "GIT_PULL=ja"   bzw.   set "GIT_PULL=nein"
rem  fest vorgeben, dann wird nicht gefragt.
rem ---------------------------------------------------------------
where git >nul 2>&1
if errorlevel 1 goto :nachpull
git -C "%ROOT%" rev-parse --is-inside-work-tree >nul 2>&1
if errorlevel 1 goto :nachpull

set "ZWEIG="
for /f "delims=" %%B in ('git -C "%ROOT%" rev-parse --abbrev-ref HEAD 2^>nul') do set "ZWEIG=%%B"
if "!ZWEIG!"=="" set "ZWEIG=main"
rem Losgeloester HEAD: dann gibt es keinen Zweig zum Nachziehen
if /i "!ZWEIG!"=="HEAD" (
  echo.
  echo === Git ===
  echo   Kein Zweig ausgecheckt - Aktualisieren wird uebersprungen.
  goto :nachpull
)

echo.
echo === Git ===
echo   Ordner: %ROOT%
echo   Zweig:  !ZWEIG!
set "SCHMUTZ="
for /f "delims=" %%C in ('git -C "%ROOT%" status --porcelain 2^>nul') do set "SCHMUTZ=1"
if defined SCHMUTZ echo   Hinweis: es gibt eigene, nicht eingecheckte Aenderungen.

if /i "!GIT_PULL!"=="nein" (
  echo   Aktualisieren uebersprungen ^(GIT_PULL=nein^).
  goto :nachpull
)
if /i "!GIT_PULL!"=="ja" goto :pullen

set "ANTWORT="
set /p "ANTWORT=  Vorher von GitHub aktualisieren? [J/n] "
if not defined ANTWORT set "ANTWORT=J"
if /i "!ANTWORT:~0,1!"=="n" (
  echo   Uebertragen wird der Stand, der jetzt im Ordner liegt.
  goto :nachpull
)

:pullen
echo.
echo   git pull --ff-only origin !ZWEIG!
git -C "%ROOT%" pull --ff-only origin !ZWEIG!
rem Rueckgabe sofort sichern - jeder weitere Befehl wuerde sie ueberschreiben
set "PULLRC=!ERRORLEVEL!"
if "!PULLRC!"=="0" (
  for /f "delims=" %%H in ('git -C "%ROOT%" log -1 --oneline 2^>nul') do echo   Stand: %%H
) else (
  echo.
  echo   Aktualisieren fehlgeschlagen. Ueblicher Grund: eigene Aenderungen
  echo   im Ordner oder ein abweichender Verlauf. Mit  git status  nachsehen.
  set "WEITER="
  set /p "WEITER=  Trotzdem den Stand aus dem Ordner uebertragen? [j/N] "
  if /i not "!WEITER:~0,1!"=="j" (
    echo   Abgebrochen - es wurde nichts uebertragen.
    pause
    exit /b 1
  )
)

:nachpull

echo.
echo === Dateien pruefen ===
set "MISSING="
for %%F in (chess.html dashboard.html manifest.webmanifest sw.js icon-192.png icon-512.png apple-touch-icon.png php\.htaccess php\api\state.php php\api\hist.php php\api\speed.php php\api\muell.php php\api\health.php php\api\reset.php php\api\.htaccess) do (
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
>> "%LIST%" echo put manifest.webmanifest
>> "%LIST%" echo put sw.js
>> "%LIST%" echo put icon-192.png
>> "%LIST%" echo put icon-512.png
>> "%LIST%" echo put apple-touch-icon.png
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
>> "%LIST%" echo put muell.php
>> "%LIST%" echo put health.php
>> "%LIST%" echo put reset.php
>> "%LIST%" echo put .htaccess .htaccess
rem Schreibrecht fuer die Zustandsdatei; scheitert auf manchen Tarifen - egal
>> "%LIST%" echo -chmod 777 .
>> "%LIST%" echo bye

rem Mit hinterlegtem Schluessel fragt sftp nichts mehr; ohne fragt es selbst
set "KEYOPT="
if not "!SFTP_KEY!"=="" (
  if exist "!SFTP_KEY!" (
    set KEYOPT=-i "!SFTP_KEY!"
    echo   ^(Anmeldung mit Schluessel !SFTP_KEY!^)
  ) else (
    echo   Hinweis: SFTP_KEY zeigt auf keine Datei - es wird das Passwort abgefragt.
  )
)
if "!KEYOPT!"=="" echo   ^(sftp fragt das Passwort gleich selbst ab^)
rem -b schaltet die Passwortabfrage sonst ab
sftp !KEYOPT! -oBatchMode=no -b "%LIST%" %SFTP_USER%@%SFTP_HOST%
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
>> "%WS%" echo put manifest.webmanifest
>> "%WS%" echo put sw.js
>> "%WS%" echo put icon-192.png
>> "%WS%" echo put icon-512.png
>> "%WS%" echo put apple-touch-icon.png
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
>> "%WS%" echo put muell.php
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
