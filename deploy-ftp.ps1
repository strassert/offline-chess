<#
    deploy-ftp.ps1
    --------------
    Laedt chess.html direkt von GitHub (raw) herunter und kopiert sie
    per FTP nach F:/web/.

    Aufruf (Windows PowerShell):
        powershell -ExecutionPolicy Bypass -File .\deploy-ftp.ps1

    Optional koennen Host, Benutzer und Passwort ueberschrieben werden:
        .\deploy-ftp.ps1 -FtpHost "192.168.0.10" -User "a" -Pass "123"
#>

param(
    # FTP-Server. Der Standard 'localhost' bedeutet: der FTP-Dienst laeuft
    # auf demselben Rechner, dessen Laufwerk F: das Ziel ist. Bei Bedarf
    # anpassen, z.B. auf die IP oder den Hostnamen des Servers.
    [string]$FtpHost = "localhost",

    [string]$User = "a",
    [string]$Pass = "123",

    # Quelle: die immer aktuelle HTML aus dem GitHub-Repository (Branch main).
    [string]$SourceUrl = "https://raw.githubusercontent.com/strassert/offline-chess/main/chess.html",

    # Zielpfad auf dem FTP-Server. Muss dort auf F:/web/ zeigen.
    # Je nach FTP-Serverkonfiguration ist das entweder ein absoluter Pfad
    # wie unten, oder ein relativer Pfad ("/web/chess.html"), wenn F:\
    # bereits das FTP-Stammverzeichnis ist.
    [string]$RemotePath = "F:/web/chess.html"
)

$ErrorActionPreference = "Stop"

# TLS 1.2 fuer den GitHub-Download erzwingen (aeltere .NET-Versionen).
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# 1) HTML von GitHub in eine temporaere Datei laden -----------------------
$tmp = Join-Path $env:TEMP "chess.html"
Write-Host "Lade HTML von GitHub..." -ForegroundColor Cyan
Invoke-WebRequest -Uri $SourceUrl -OutFile $tmp -UseBasicParsing
Write-Host "  -> $tmp ($((Get-Item $tmp).Length) Bytes)" -ForegroundColor Green

# 2) Datei per FTP hochladen ---------------------------------------------
# FTP-URI aufbauen. Backslashes im Pfad zu Slashes normalisieren.
$remote = $RemotePath -replace '\\', '/'
$ftpUri = "ftp://$FtpHost/$($remote.TrimStart('/'))"

Write-Host "Lade nach $ftpUri hoch..." -ForegroundColor Cyan

$request = [System.Net.FtpWebRequest]::Create($ftpUri)
$request.Method      = [System.Net.WebRequestMethods+Ftp]::UploadFile
$request.Credentials = New-Object System.Net.NetworkCredential($User, $Pass)
$request.UseBinary   = $true
$request.UsePassive  = $true
$request.KeepAlive   = $false

$bytes = [System.IO.File]::ReadAllBytes($tmp)
$request.ContentLength = $bytes.Length

$stream = $request.GetRequestStream()
$stream.Write($bytes, 0, $bytes.Length)
$stream.Close()

$response = $request.GetResponse()
Write-Host "  Server: $($response.StatusDescription.Trim())" -ForegroundColor Green
$response.Close()

# 3) Aufraeumen -----------------------------------------------------------
Remove-Item $tmp -ErrorAction SilentlyContinue
Write-Host "Fertig." -ForegroundColor Green
