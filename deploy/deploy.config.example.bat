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

rem Vor der Uebertragung fragt das Skript, ob es den Stand von GitHub
rem holen soll. Wer die Frage nicht will, entscheidet hier ein fuer alle
rem Mal - alles andere (auch nichts eintragen) bedeutet: nachfragen.
rem   set "GIT_PULL=ja"     immer vorher aktualisieren
rem   set "GIT_PULL=nein"   nie, es zaehlt der Ordner wie er ist
set "GIT_PULL="
