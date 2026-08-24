# Betrieb auf einem Proxmox-LXC-Container

Alternative zum Betrieb auf der Steuerung: Ein kleiner Node-Server hält den
Spielstand und liefert die Seite aus. Gegenüber dem PLC-Weg entfallen die
Goform-Schnittstelle, die MIME-Konfiguration und das Abfragen im
Sekundentakt.

## Container anlegen

In der Proxmox-Oberfläche einen unprivilegierten LXC-Container erstellen:

| Einstellung | Wert |
|-------------|------|
| Vorlage | Debian 12 oder Ubuntu 24.04 |
| Kerne | 1 (2 für zügigere Analyse) |
| RAM | 512 MB genügen, 1 GB empfohlen |
| Festplatte | 4 GB |
| Netzwerk | feste IP im selben Netz wie die Arbeitsplätze |

Die Engine läuft im Browser der Nutzer, nicht im Container – der Container
braucht daher kaum Leistung.

## Installation

In der Container-Konsole als root – das Skript holt alles Weitere selbst
von GitHub.

> Minimale Debian-Vorlagen bringen weder `curl` noch `wget` mit. Meldet die
> Konsole `curl: command not found`, zuerst nachinstallieren:
>
> ```sh
> apt update && apt install -y curl ca-certificates
> ```
>
> Wer lieber ganz ohne Download-Werkzeug startet, kann auch direkt klonen:
>
> ```sh
> apt update && apt install -y git
> git clone --depth 1 -b lxc-server https://github.com/strassert/offline-chess.git /opt/offline-chess
> sh /opt/offline-chess/server/bootstrap.sh
> ```

```sh
curl -fsSL https://raw.githubusercontent.com/strassert/offline-chess/lxc-server/server/bootstrap.sh | sh
```

Sollte das Repository einmal auf privat stehen, wird zusätzlich ein
GitHub-Token mit Leserecht gebraucht (Einstellungen → Developer settings →
Personal access tokens, Berechtigung *Contents: read*):

```sh
export GITHUB_TOKEN=ghp_xxxxxxxxxxxx
curl -fsSL -H "Authorization: Bearer $GITHUB_TOKEN" \
  https://raw.githubusercontent.com/strassert/offline-chess/lxc-server/server/bootstrap.sh | sh
```

Das Skript installiert fehlende Pakete (git, Node), klont den Branch nach
`/opt/offline-chess`, legt den Dienstbenutzer `chess` an, richtet den
systemd-Dienst ein, startet ihn und prüft, ob er antwortet. Am Ende steht
die fertige Adresse in der Konsole.

Danach ist das Spiel erreichbar unter:

```
http://<container-ip>:8080/
```

Ohne URL-Zusatz – die Seite erkennt den Server selbst.

### Aktualisieren

Derselbe Aufruf noch einmal – oder direkt im Container:

```sh
sh /opt/offline-chess/server/bootstrap.sh
```

Holt den neuen Stand und startet den Dienst neu. Der laufende Spielstand
in `/var/lib/offline-chess/` bleibt erhalten.

### Einstellungen beim Aufruf

| Variable | Bedeutung | Vorgabe |
|----------|-----------|---------|
| `GITHUB_TOKEN` | Token für privates Repository | – |
| `BRANCH` | zu installierender Branch | `lxc-server` |
| `PORT` | Port des Dienstes | `8080` |
| `APP` | Programmverzeichnis | `/opt/offline-chess` |
| `DATA` | Verzeichnis für den Spielstand | `/var/lib/offline-chess` |
| `SKIP_SERVICE` | nur Dateien holen, kein systemd | – |

Beispiel: `PORT=9000 BRANCH=main sh bootstrap.sh`

### Dateien schon im Container?

Liegt das Projekt bereits lokal (per `scp` oder Archiv), richtet
`sh server/install.sh` denselben Dienst ohne GitHub-Zugriff ein.

## Dienst verwalten

```sh
systemctl status offline-chess     # Zustand
systemctl restart offline-chess    # Neustart
journalctl -u offline-chess -f     # Protokoll mitlesen
```

Einstellungen stehen in `/etc/systemd/system/offline-chess.service`:

| Variable | Bedeutung | Vorgabe |
|----------|-----------|---------|
| `PORT` | Port des Servers | `8080` |
| `HOST` | Netzwerkschnittstelle | `0.0.0.0` |
| `ROOT` | Verzeichnis mit `chess.html` | `/opt/offline-chess` |
| `STATE_FILE` | Datei für den Spielstand | `/var/lib/offline-chess/state.txt` |
| `HIST_FILE` | Datei für die Historie | neben `STATE_FILE` als `hist.txt` |

Nach Änderungen `systemctl daemon-reload && systemctl restart offline-chess`.

## Schnittstellen

| Pfad | Zweck |
|------|-------|
| `GET /api/state` | aktueller Spielstand |
| `GET /api/hist` | vergangene Partien |
| `POST /api/hist` | Historie setzen |
| `POST /api/state` | Spielstand setzen (Rumpf = Zustandsstring) |
| `GET /api/events` | Server-Sent Events, schiebt jede Änderung sofort |
| `POST /api/reset` | Spielstand leeren (alle Plätze frei) |
| `GET /api/health` | Zustand des Dienstes, Anzahl Verbindungen |

Hängt eine Partie fest, hilft:

```sh
curl -X POST http://<container-ip>:8080/api/reset
```

## Unterschiede zum PLC-Betrieb

| | Steuerung (`?plc`) | LXC-Container |
|---|---|---|
| Übertragung | Abfrage jede Sekunde | Server-Sent Events, ~100 ms |
| Spielstand | SPS-Variable, Länge begrenzt | Datei, praktisch unbegrenzt |
| Neustart | Variable bleibt | Spielstand wird gespeichert und geladen |
| MIME-Typen | müssen konfiguriert werden | erledigt der Server |
| Aufruf | `chess.html?plc` | einfach die Adresse aufrufen |

Beide Betriebsarten stecken in derselben `chess.html`. `?plc` erzwingt die
Steuerung, `?srv` den Server; ohne Angabe prüft die Seite, ob ein Server
antwortet, und fällt sonst auf den Hotseat-Betrieb zurück.

## Sicherung

Zu sichern ist nur `/var/lib/offline-chess/state.txt` – und das auch nur,
wenn eine laufende Partie überleben soll. In Proxmox genügt ein normaler
Container-Snapshot.
