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

Projekt in den Container kopieren (z. B. per `git clone`, `scp` oder als
Archiv) und im Projektverzeichnis als root ausführen:

```sh
sh server/install.sh
```

Das Skript installiert Node, legt den Benutzer `chess` an, kopiert die
Dateien nach `/opt/offline-chess`, richtet den systemd-Dienst ein und
startet ihn.

Danach ist das Spiel erreichbar unter:

```
http://<container-ip>:8080/
```

Ohne URL-Zusatz – die Seite erkennt den Server selbst.

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

Nach Änderungen `systemctl daemon-reload && systemctl restart offline-chess`.

## Schnittstellen

| Pfad | Zweck |
|------|-------|
| `GET /api/state` | aktueller Spielstand |
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
