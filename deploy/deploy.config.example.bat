@echo off
rem ---------------------------------------------------------------
rem  Vorlage fuer die Servereinstellungen.
rem
rem  1. Diese Datei kopieren und in  deploy.config.bat  umbenennen
rem  2. Benutzernamen eintragen
rem
rem  Hier steht bewusst KEIN Passwort - das Uebertragungsskript fragt es
rem  bei jedem Lauf ab und speichert es nirgends.
rem ---------------------------------------------------------------

set "SFTP_HOST=gg2.members.cablelink.at"
set "SFTP_USER=<dein-benutzername>"
set "SFTP_DIR=/"
