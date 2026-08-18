@echo off
REM ---------------------------------------------------------------
REM deploy-ftp.bat
REM Laedt chess.html von GitHub und kopiert sie per FTP nach F:\web.
REM Login landet in C:\, daher wird per FTP auf F: gewechselt,
REM der Ordner web angelegt und die Datei dort hochgeladen.
REM Nutzt curl (ab Windows 10 eingebaut) und ftp.exe.
REM ---------------------------------------------------------------
setlocal

REM --- Konfiguration ---------------------------------------------
set "FTPHOST=strassert.brdev.net"
set "FTPUSER=a"
set "FTPPASS=123"
set "SOURCEURL=https://raw.githubusercontent.com/strassert/offline-chess/main/chess.html"
set "REMOTEFILE=chess.html"
REM ---------------------------------------------------------------

set "TMPFILE=%TEMP%\chess.html"

echo Lade HTML von GitHub...
curl -fsSL "%SOURCEURL%" -o "%TMPFILE%"
if errorlevel 1 (
    echo FEHLER: Download fehlgeschlagen.
    exit /b 1
)

echo Erzeuge FTP-Skript...
set "FTPSCRIPT=%TEMP%\deploy-ftp.txt"
> "%FTPSCRIPT%" echo open %FTPHOST%
>>"%FTPSCRIPT%" echo user %FTPUSER% %FTPPASS%
>>"%FTPSCRIPT%" echo binary
>>"%FTPSCRIPT%" echo cd F:
>>"%FTPSCRIPT%" echo mkdir web
>>"%FTPSCRIPT%" echo cd web
>>"%FTPSCRIPT%" echo put "%TMPFILE%" %REMOTEFILE%
>>"%FTPSCRIPT%" echo bye

echo Lade per FTP hoch nach F:\web\%REMOTEFILE% ...
ftp -n -s:"%FTPSCRIPT%"

del "%FTPSCRIPT%" >nul 2>&1
del "%TMPFILE%" >nul 2>&1
echo Fertig.
endlocal
