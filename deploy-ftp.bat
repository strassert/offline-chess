@echo off
REM ---------------------------------------------------------------
REM deploy-ftp.bat
REM Laedt chess.html von GitHub und kopiert sie per FTP nach F:\web.
REM Login landet in C:\, daher wird per FTP auf F: gewechselt,
REM der Ordner web angelegt und die Datei dort hochgeladen.
REM Nutzt curl (ab Windows 10 eingebaut) und ftp.exe.
REM Die komplette FTP-Antwort wird zusaetzlich in eine Log-Datei
REM auf dem Desktop geschrieben (deploy-ftp.log).
REM ---------------------------------------------------------------
setlocal

REM --- Konfiguration ---------------------------------------------
set "FTPHOST=strassert.brdev.net"
set "FTPUSER=a"
set "FTPPASS=123"
set "SOURCEURL=https://raw.githubusercontent.com/strassert/offline-chess/main/chess.html"
set "REMOTEFILE=chess.html"
set "LOGFILE=%USERPROFILE%\Desktop\deploy-ftp.log"
REM ---------------------------------------------------------------

set "TMPFILE=%TEMP%\chess.html"
set "FTPSCRIPT=%TEMP%\deploy-ftp.txt"

echo Lade HTML von GitHub...
where curl >nul 2>&1
if errorlevel 1 (
    echo FEHLER: 'curl' wurde nicht gefunden ^(altes Windows?^).
    echo Bitte die PowerShell-Variante deploy-ftp.ps1 verwenden.
    pause
    exit /b 1
)
curl -fsSL "%SOURCEURL%" -o "%TMPFILE%"
if errorlevel 1 (
    echo FEHLER: Download fehlgeschlagen.
    pause
    exit /b 1
)
echo   OK - Datei geladen.

echo Erzeuge FTP-Skript...
> "%FTPSCRIPT%" echo open %FTPHOST%
>>"%FTPSCRIPT%" echo user %FTPUSER% %FTPPASS%
>>"%FTPSCRIPT%" echo binary
>>"%FTPSCRIPT%" echo cd F:
>>"%FTPSCRIPT%" echo mkdir web
>>"%FTPSCRIPT%" echo cd web
>>"%FTPSCRIPT%" echo put "%TMPFILE%" %REMOTEFILE%
>>"%FTPSCRIPT%" echo bye

echo Lade per FTP hoch nach F:\web\%REMOTEFILE% ...
echo ------------------------------------------------------------
REM ftp-Ausgabe gleichzeitig auf Bildschirm und in die Log-Datei.
ftp -n -s:"%FTPSCRIPT%" > "%LOGFILE%" 2>&1
type "%LOGFILE%"
echo ------------------------------------------------------------
echo Log gespeichert unter: %LOGFILE%

del "%FTPSCRIPT%" >nul 2>&1
del "%TMPFILE%" >nul 2>&1
echo Fertig.
pause
endlocal
