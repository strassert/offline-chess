<#
    deploy-ftp.ps1
    --------------
    Laedt chess.html direkt von GitHub (raw) herunter und kopiert sie
    per FTP nach F:\web.

    Der Login landet in C:\, daher wird per FTP auf Laufwerk F:
    gewechselt, der Ordner "web" angelegt und die Datei dort abgelegt.
    Fuer den Laufwerkswechsel wird der eingebaute ftp.exe-Client genutzt.

    Aufruf (Windows PowerShell):
        powershell -ExecutionPolicy Bypass -File .\deploy-ftp.ps1
#>

param(
    [string]$FtpHost   = "strassert.brdev.net",
    [string]$User      = "a",
    [string]$Pass      = "123",
    [string]$SourceUrl = "https://raw.githubusercontent.com/strassert/offline-chess/main/chess.html",
    [string]$RemoteFile = "chess.html"
)

$ErrorActionPreference = "Stop"

# TLS 1.2 fuer den GitHub-Download erzwingen (aeltere .NET-Versionen).
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# 1) HTML von GitHub in eine temporaere Datei laden -----------------------
$tmp = Join-Path $env:TEMP "chess.html"
Write-Host "Lade HTML von GitHub..." -ForegroundColor Cyan
Invoke-WebRequest -Uri $SourceUrl -OutFile $tmp -UseBasicParsing
Write-Host "  -> $tmp ($((Get-Item $tmp).Length) Bytes)" -ForegroundColor Green

# 2) FTP-Skript fuer ftp.exe erzeugen ------------------------------------
#    cd F:  -> Laufwerk wechseln
#    mkdir web -> Ordner anlegen (Fehler wird ignoriert, falls vorhanden)
#    cd web -> hineinwechseln
#    put   -> Datei hochladen
$ftpScript = Join-Path $env:TEMP "deploy-ftp.txt"
@(
    "open $FtpHost"
    "user $User $Pass"
    "binary"
    "cd F:"
    "mkdir web"
    "cd web"
    "put `"$tmp`" $RemoteFile"
    "bye"
) | Set-Content -Path $ftpScript -Encoding ASCII

Write-Host "Lade per FTP hoch nach F:\web\$RemoteFile ..." -ForegroundColor Cyan
& ftp.exe -n -s:$ftpScript

# 3) Aufraeumen -----------------------------------------------------------
Remove-Item $ftpScript, $tmp -ErrorAction SilentlyContinue
Write-Host "Fertig." -ForegroundColor Green
