# Betrieb auf klassischem Webhosting (Apache + PHP)

Für Tarife mit FTP-Zugang und PHP, aber ohne Root-Rechte – dort lässt sich
kein Node-Server starten. Die drei Endpunkte, die der Mehrspieler-Betrieb
braucht, liegen deshalb zusätzlich als PHP-Fassung bei.

Getestet gegen Apache 2 mit PHP/FPM (z. B. cablelink `[CL MSP] Linux`).

## Was hochgeladen wird

| Datei | Ziel | Größe |
|-------|------|-------|
| `dashboard.html` | Wurzel als `index.html` | 35 KB |
| `chess.html` | Wurzel | ~175 KB |
| `manifest.webmanifest`, `sw.js` | Wurzel – für „Zum Startbildschirm" | 2 KB |
| `icon-192.png`, `icon-512.png`, `apple-touch-icon.png` | Wurzel | 23 KB |
| `stockfish-18-lite-single.js` | Wurzel | 21 KB |
| `stockfish-18-lite-single.wasm` | Wurzel | 7,3 MB |
| `php/.htaccess` | Wurzel als `.htaccess` | 1 KB |
| `php/api/*` | Unterordner `api/` | 5 KB |

Zusammen rund **7,5 MB** – passt in ein 100-MB-Kontingent.

Ergebnis auf dem Webspace:

```
/                        (Wurzel des Uploads)
├── index.html           (die umbenannte dashboard.html – Startseite)
├── chess.html           (das Spiel)
├── manifest.webmanifest
├── sw.js
├── icon-192.png, icon-512.png, apple-touch-icon.png
├── stockfish-18-lite-single.js
├── stockfish-18-lite-single.wasm
├── .htaccess
└── api/
    ├── .htaccess
    ├── health.php
    ├── hist.php
    ├── muell.php
    ├── reset.php
    ├── speed.php
    └── state.php
```

Die Dateien `api/state.txt` (Spielstand) und `api/hist.txt` (vergangene
Partien) legt PHP selbst an.

## Schritte

1. **Dateien per FTP/SFTP hochladen**, Struktur wie oben. `dashboard.html`
   in `index.html` umbenennen, damit die Adresse ohne Dateinamen die
   Startseite zeigt; `chess.html` behält seinen Namen.
   Die `.wasm`-Datei **binär** übertragen (die meisten Programme machen das
   automatisch; bei FileZilla notfalls unter *Übertragung → Übertragungstyp
   → Binär* erzwingen).
2. **Schreibrechte für `api/`** setzen – PHP muss dort die Zustandsdatei
   anlegen. Im FTP-Programm Rechte auf `755` stellen; klappt das nicht,
   `775` oder `777` versuchen.
3. **Aufrufen**: `https://gg2.members.cablelink.at/` zeigt die Startseite
   mit Wetter und Anwendungsauswahl, `…/chess.html` das Spiel. Das Spiel
   erkennt die PHP-Endpunkte selbst – kein URL-Zusatz nötig.

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

## Startseite

`dashboard.html` liegt als `index.html` in der Wurzel. Den Platz bekommen
die **Anwendungen**; Wetter und Abfuhr stehen als schmale Zeilen darüber und
klappen auf, wer mehr sehen will – die Einstellung merkt sich der Browser.
Wie das Spiel ist es eine einzelne Datei ohne Abhängigkeiten; PHP braucht
davon nur die Abfuhrzeile.

**Wetter** kommt von [Open-Meteo](https://open-meteo.com/) – frei nutzbar,
ohne Schlüssel und ohne Anmeldung, direkt aus dem Browser des Besuchers
abgefragt (der Webspace selbst holt nichts). In der Zeile stehen Temperatur,
Zustand, Regenwahrscheinlichkeit, Wind und Sonnenuntergang; aufgeklappt
kommen die nächsten 24 Stunden, sieben Tage und die Nebenwerte dazu. Die letzte gelungene
Antwort liegt im Browser; ist der Dienst gerade nicht erreichbar, bleibt
dieser Stand mit Altersangabe stehen, statt die Seite leer zu lassen.
Aufgefrischt wird alle 15 Minuten, beim Zurückkehren auf die Seite und über
den Knopf unten links.

**Anderer Ort** ohne Änderung der Datei: `?ort=Salzburg&lat=47.80&lon=13.04`
an die Adresse hängen. Dauerhaft: die Werte in `const ORT={…}` am Anfang des
Skriptteils eintragen.

**Weitere Anwendung** aufnehmen – eine Zeile in derselben Liste:

```js
const APPS=[
  { name:'Schach', datei:'chess.html', icon:'chess',
    text:'Zwei Spieler an zwei Rechnern, Zuschauer, Uhr und Auswertung.' }
];
```

Ein eigenes Sinnbild kommt als SVG in `APPICON` dazu; ohne Eintrag bleibt
die Kachel einfach ohne Bild.

### Abfuhrtermine

Die Zeile **Abfuhr** unter dem Wetter zeigt die nächsten vier Termine; was
in den nächsten zwei Tagen ansteht, ist gelb. Sie erscheint nur, wenn es
Daten gibt – ohne Einrichtung bleibt die Seite unverändert.

Die Daten kommen aus einem Abfuhrkalender im ICS-Format. Zwei Wege, je
nachdem was die Gemeinde anbietet, beide in `api/muell.php` oben einstellbar:

1. **Kalender-Adresse**: In `const QUELLE` die `https://…/….ics` eintragen
   (ein `webcal://`-Abo-Verweis geht auch, er wird auf `https` umgesetzt).
   Die Datei wird alle zwölf Stunden geholt und in `api/muell.cache.json`
   zwischengespeichert. Aus Sicherheitsgründen sind nur `https` und der
   Rechner aus dieser Adresse erlaubt – der Endpunkt ist **kein** offener
   Weiterleiter.
2. **Datei von Hand**: Kalender beim Abfallkalender der Gemeinde exportieren,
   als `api/muell.ics` hochladen, `QUELLE` leer lassen. Einmal im Jahr
   erneuern.

Gelesen werden je Termin nur Datum (`DTSTART`) und Bezeichnung (`SUMMARY`);
Vergangenes fällt weg, die nächsten sechs Termine gehen an die Seite.

**Prüfen, ob es klappt:** `https://…/api/muell.php?pruefen=1` holt die Quelle
frisch und sagt, was ankommt – Größe, ob es überhaupt ein Kalender ist, wie
viele Einträge und welcher Termin als nächster gilt. Die Prüfung greift nur
auf die eingetragene Quelle zu; eine Adresse von aussen nimmt der Endpunkt
bewusst nicht entgegen.

```json
{"quelle":"api/muell.ics","art":"Datei","kalender":true,"eintraege":7,
 "kommende_termine":6,"naechster":{"d":"2026-08-29","t":"Restmüll"},
 "ergebnis":"in Ordnung"}
```

**Für Seekirchen am Wallersee** führt der Weg über
<https://www.seekirchen.at/abfallkalender> (GEM2GO/RiS-Kommunal): dort Straße
und Hausnummer wählen, dann steht unter *Ihre Termine im Überblick* der
iCal-Verweis. Weil die Termine je Adresse verschieden sind, hängt die
Kalender-Adresse an genau dieser Auswahl – sie lässt sich nicht allgemein
angeben.

### Zum Startbildschirm hinzufügen

Mit `manifest.webmanifest`, den drei Symbolen und `sw.js` lässt sich die
Startseite auf Handy und Tablet wie eine App ablegen – ohne Adressleiste.

- **Android/Chrome** bietet es von selbst an; zusätzlich erscheint in der
  App-Auswahl eine Kachel *Zum Startbildschirm*.
- **iPhone/iPad** kennt diesen Weg nicht; dort steht die Kachel als
  Anleitung da: *Teilen ▸ Zum Home-Bildschirm*.
- Läuft die Seite bereits als App, verschwindet die Kachel.

`sw.js` fragt **immer zuerst den Server** und greift nur ohne Netz auf den
Zwischenspeicher zurück. Eine neue Fassung ist damit sofort da; es kann
keine alte hängen bleiben. Abrufe unter `api/` werden nie zwischengespeichert.

Wichtig ist der MIME-Eintrag in der `.htaccess`
(`AddType application/manifest+json .webmanifest`) – fehlt er, hält mancher
Server das Manifest für Text und der Browser bietet das Ablegen nicht an.
Und: **Das Ganze braucht HTTPS.** Über `http://` meldet sich kein
Dienstprogramm an.

### Verbindungsmessung

Die Karte **Verbindung** zeigt dreierlei, und die ersten beiden Punkte kosten
so gut wie nichts:

1. **Seitenaufruf** – wie sich die Ladezeit dieser Seite aufteilt (DNS,
   Verbindung, TLS, Wartezeit aufs erste Byte, Übertragung). Die Zahlen
   stehen im Browser ohnehin bereit (`performance`-Schnittstelle), es wird
   nichts zusätzlich abgerufen.
2. **Antwortzeit** – sieben Kopfabfragen auf die Seite selbst, angezeigt wird
   der Median und die Schwankung. Ein paar hundert Bytes.
3. **Durchsatz** – nur auf Knopfdruck: rund 16 MB herunter und 12 MB hinauf,
   je mit einem Zeitbudget von 12 Sekunden. Die letzten fünf Messungen bleiben
   im Browser stehen.

Als Ladung dient beim Download die ohnehin vorhandene Engine-Datei; mit dem
Bereichskopf (`Range`) werden davon 4 MB je Verbindung geholt, vier
Verbindungen parallel – eine allein schöpft schnelle Leitungen nicht aus.
Der Upload geht gegen `api/speed.php`, das die Daten nur zählt und
wegwirft; **gespeichert wird nichts**. Grenze ist 8 MB je Anfrage bzw. was
`post_max_size` zulässt.

Fehlt `speed.php`, wird nur der Download gemessen und die Karte sagt es.

Die Zahlen messen den Weg **zu diesem Server** – eine Untergrenze, kein
Ersatz für einen Anbieter-Test: Ein Shared-Webspace teilt seine Anbindung
mit anderen. Und pro Messung gehen rund 28 MB auf das Traffic-Kontingent,
weshalb Punkt 3 bewusst nicht von selbst läuft.

## Unterordner

Ein Upload nach `/schach/` funktioniert genauso – die Seite bestimmt ihren
Pfad selbst. Dann liegt `api/` unter `/schach/api/`.

## Passwortschutz

**Ohne Schutz kann jeder, der die Adresse kennt, in laufende Partien
schreiben** – es gibt keine Anmeldung und keine serverseitige Zugprüfung.
Dasselbe gilt für `api/speed.php`: Es speichert zwar nichts, nimmt aber
Daten entgegen und verbraucht damit fremdes Kontingent.
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
| „Upload nicht gemessen (api/speed.php fehlt)" | `speed.php` wurde nicht mit hochgeladen |
| Abfuhr-Zeile fehlt | `muell.php` nicht hochgeladen, oder weder `QUELLE` gesetzt noch `api/muell.ics` vorhanden |
| „Zum Startbildschirm" wird nicht angeboten | Seite über `http://` statt `https://` aufgerufen, oder der MIME-Eintrag für `.webmanifest` fehlt |
| Startseite ohne Wetter | Besucher hat keinen Zugang zu `api.open-meteo.com` (Netzsperre, Werbeblocker); der Hinweis auf der Karte nennt den Grund |
