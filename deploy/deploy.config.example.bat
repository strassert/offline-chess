@echo off
rem ---------------------------------------------------------------
rem  Vorlage fuer die Zugangsdaten.
rem
rem  1. Diese Datei kopieren und in  deploy.config.bat  umbenennen
rem  2. Werte eintragen
rem
rem  deploy.config.bat wird von .gitignore ausgeschlossen und landet
rem  damit nicht im Repository - dort waere das Passwort oeffentlich.
rem ---------------------------------------------------------------

set "SFTP_HOST=gg2.members.cablelink.at"
set "SFTP_USER=<dein-benutzername>"
set "SFTP_DIR=/"

rem Nur noetig, wenn WinSCP verwendet wird und die Uebertragung ohne
rem Rueckfrage durchlaufen soll. Leer lassen, dann fragt Windows-sftp
rem das Passwort beim Start ab - sicherer, weil es nirgends steht.
set "SFTP_PASS="
