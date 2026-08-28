# Betrieb auf klassischem Webhosting (Apache + PHP)

Für Tarife mit FTP-Zugang und PHP, aber ohne Root-Rechte – dort lässt sich
kein Node-Server starten. Die drei Endpunkte, die der Mehrspieler-Betrieb
braucht, liegen deshalb zusätzlich als PHP-Fassung bei.

Getestet gegen Apache 2 mit PHP/FPM (z. B. cablelink `[CL MSP] Linux`).

## Was hochgeladen wird

| Datei | Ziel | Größe |
|-------|------|-------|
| `chess.html` | Wurzel (ggf. als `index.html`) | ~170 KB |
| `stockfish-18-lite-single.js` | Wurzel | 21 KB |
| `stockfish-18-lite-single.wasm` | Wurzel | 7,3 MB |
| `php/.htaccess` | Wurzel als `.htaccess` | 1 KB |
| `php/api/*` | Unterordner `api/` | 3 KB |

Zusammen rund **7,5 MB** – passt in ein 100-MB-Kontingent.

Ergebnis auf dem Webspace:

```
/                        (Wurzel des Uploads)
├── index.html           (die umbenannte chess.html)
├── stockfish-18-lite-single.js
├── stockfish-18-lite-single.wasm
├── .htaccess
└── api/
    ├── .htaccess
    ├── health.php
    ├── hist.php
    ├── reset.php
    └── state.php
```

Die Dateien `api/state.txt` (Spielstand) und `api/hist.txt` (vergangene
Partien) legt PHP selbst an.

## Schritte

1. **Dateien per FTP/SFTP hochladen**, Struktur wie oben. `chess.html` in
   `index.html` umbenennen, damit die Adresse ohne Dateinamen funktioniert.
   Die `.wasm`-Datei **binär** übertragen (die meisten Programme machen das
   automatisch; bei FileZilla notfalls unter *Übertragung → Übertragungstyp
   → Binär* erzwingen).
2. **Schreibrechte für `api/`** setzen – PHP muss dort die Zustandsdatei
   anlegen. Im FTP-Programm Rechte auf `755` stellen; klappt das nicht,
   `775` oder `777` versuchen.
3. **Aufrufen**: `https://gg2.members.cablelink.at/`
   Die Seite erkennt die PHP-Endpunkte selbst – kein URL-Zusatz nötig.

Prüfen lässt sich der Server-Teil direkt:
`https://…/api/health.php` muss `{"ok":true,"backend":"php","writable":true}`
liefern. Steht dort `"writable":false`, fehlen die Schreibrechte aus
Schritt 2.

## Hochladen per Skript (Windows)

Statt von Hand: `deploy\deploy-sftp.bat` überträgt alle Dateien, legt `api/`
an und setzt die Schreibrechte.

Einmalig vorbereiten:

1. `deploy\deploy.config.example.bat` kopieren, in `deploy.config.bat`
   umbenennen und Benutzernamen eintragen.
2. Mehr ist nicht nötig – das Passwort fragt das Skript bei **jedem** Lauf
   ab und speichert es nirgends.

`deploy.config.bat` ist von `.gitignore` ausgeschlossen und landet nicht im
Repository.

Danach genügt ein Doppelklick auf `deploy-sftp.bat`. Am Ende nennt es die
Adresse und die Prüf-URL.

Voraussetzung ist eines von beidem:

- **OpenSSH-Client** – in Windows 10/11 meist vorhanden und der bevorzugte
  Weg: `sftp` fragt das Passwort selbst ab, verdeckt, und das Skript
  bekommt es nie zu sehen. Fehlt er, unter *Einstellungen → Apps →
  Optionale Features* nachinstallieren.
- **WinSCP** (winscp.net) – Rückfallebene, falls `sftp` fehlt. Auch hier
  wird das Passwort verdeckt abgefragt; es liegt allerdings kurz in einer
  temporären Skriptdatei, die sofort nach der Übertragung gelöscht wird.

## Unterordner

Ein Upload nach `/schach/` funktioniert genauso – die Seite bestimmt ihren
Pfad selbst. Dann liegt `api/` unter `/schach/api/`.

## Passwortschutz

**Ohne Schutz kann jeder, der die Adresse kennt, in laufende Partien
schreiben** – es gibt keine Anmeldung und keine serverseitige Zugprüfung.
Bei öffentlich erreichbarem Webspace deshalb den vorbereiteten Abschnitt in
der `.htaccess` einkommentieren:

```apache
AuthType Basic
AuthName "Schach"
AuthUserFile /absoluter/pfad/zu/.htpasswd
Require valid-user
```

Die `.htpasswd` legen die meisten Hoster über ihre Oberfläche an
(„Verzeichnisschutz"); den absoluten Pfad zeigt die Oberfläche an. Der
Schutz greift dann auch für `api/` – genau das ist gewollt.

## Unterschiede zum Node-Betrieb

| | Node (LXC/VPS) | PHP-Webhosting |
|---|---|---|
| Übertragung | Ereignisstrom, ~130 ms | Abfrage jede Sekunde |
| Spielstand | Datei, vom Dienst gehalten | `api/state.txt` |
| Aufwand | Container + Dienst | nur FTP-Upload |
| Voraussetzung | Root-Zugang | PHP, Schreibrecht |

Die Sekunden-Abfrage bedeutet: Züge des Gegners erscheinen bis zu eine
Sekunde später. Für eine gemütliche Partie unerheblich, bei Blitzpartien
merkbar.

## Störungen

| Symptom | Ursache |
|---------|---------|
| Lobby erscheint nicht, Untertitel bleibt „Hotseat" | `api/health.php` nicht erreichbar – Ordner falsch benannt oder PHP aus |
| `"writable":false` | Schreibrechte auf `api/` fehlen |
| Partie hängt, Plätze belegt | `curl -X POST https://…/api/reset.php` oder `api/state.txt` per FTP löschen |
| „Historie kann nicht gespeichert werden (Lesen 404)" | `api/hist.php` wurde nicht mit hochgeladen |
| „… (Schreiben 500)" | Schreibrechte auf `api/` fehlen, siehe `"writable"` in `health.php` |
| Analyse bleibt aus | `.wasm` fehlt, wurde als Text übertragen, oder `.htaccess` mit `AddType application/wasm` fehlt |
