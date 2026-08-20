# Offline-Schach für B&R-Steuerung

Schachspiel als einzelne HTML-Datei, gehostet vom AR-Webserver einer
B&R-SPS. Läuft komplett offline, ohne externe Bibliotheken.

## Dateien

| Datei | Zweck |
|-------|-------|
| `chess.html` | Das Spiel – vollständige Schachregeln, Zugliste, Undo, Brett drehen |
| `response.asp` | Rückgabeseite für den Goform-Zugriff (**nur für PLC-Sync nötig**) |
| `stockfish-18-lite-single.js` | Stockfish-Engine (Loader, 21 KB) – **nur für die Zuschauer-Analyse** |
| `stockfish-18-lite-single.wasm` | Stockfish-Engine (7,3 MB) – dito |
| `PV_Access.js` | B&R-Original-Bibliothek für PV-Zugriff (Referenz; `chess.html` bringt die Logik selbst mit) |
| `pvtest.html` | Diagnoseseite, die verschiedene Goform-Request-Formate durchprobiert |

## Deployment

Die Dateien gehören ins Web-Root der USER-Partition. Der Pfad steht in der
CPU-Konfiguration unter *Web Server → Web Server configuration*:

```
Port Number ........... 80
Web root directory .... web\
Default index page .... index.html
```

Im Automation-Studio-Projekt liegen die Dateien dazu unter `USER\web\` und
werden über *Copy directory content to USER partition* beim Transfer
mitgenommen. Auf der Steuerung landen sie dann z. B. unter `F:\web\`.

Aufruf: `http://<PLC-IP>/chess.html`

## Betriebsarten

Die Betriebsart wird über die URL gewählt:

| URL | Verhalten |
|-----|-----------|
| `chess.html?plc` | **Der Link für alle.** Beim Öffnen erscheint die Lobby: Weiß, Schwarz oder zuschauen. |
| `chess.html` | Standalone ohne Steuerung. Zwei Personen spielen abwechselnd an einem Bildschirm. |
| `chess.html?plc&side=w` | Überspringt die Lobby und belegt direkt Weiß (`b` = Schwarz, `v` = Zuschauer). |
| `chess.html?plc&pv=meineVar` | Abweichender PV-Name (Default: `gChessState`). |
| `chess.html?demo` | Synchronisation zwischen zwei Tabs desselben Browsers (nur zum Testen). |

### Lobby

Alle Beteiligten öffnen denselben Link. In der Lobby wird ein **Name**
eingegeben und danach ein Platz gewählt; belegte Plätze sind ausgegraut.
Wer einen Platz hat, kann ihn über *Platz freigeben* abgeben, Zuschauer
kommen über *Platz wählen* zurück zur Auswahl. Falls ein Platz hängen
bleibt (z. B. PC ausgeschaltet), gibt *Plätze zurücksetzen* alles frei.

### Bedenkzeit

Vor dem Start wählen die Spieler den Modus **3 + 2** (3 Minuten plus
2 Sekunden pro Zug) oder **10 Min** (ohne Inkrement). Das Brett bleibt
gesperrt, bis ein Spieler *Spiel starten* drückt. Läuft eine Uhr ab, endet
die Partie und das Ergebnis wird allen angezeigt – ebenso bei Schachmatt
oder Patt.

Es zählt nur die Uhr der Seite am Zug. Jeder Client zählt lokal ab dem
Empfang des Zustands herunter, verbindlich rechnet der ziehende Spieler ab.
Dadurch ist keine Uhrzeit-Synchronisation zwischen den PCs nötig; pro Zug
kann die Anzeige um die Abfragezeit (max. 1 s) abweichen.

### Anzeige im Spiel

Das Seitenpanel zeigt beide Spieler mit Namen und Restzeit (die Seite am
Zug ist hervorgehoben, unter 30 s wird die Uhr rot) sowie die Namen aller
Zuschauer. Ein Spieler kann nur ziehen, wenn seine Farbe am Zug ist;
Schwarz sieht das Brett gedreht.

### Stellungsbewertung für Zuschauer

Wer als Zuschauer beitritt, sieht zusätzlich einen Bewertungsbalken, die
Bewertung aus Sicht von Weiß (z. B. `+0.56`, bei Matt `+M3`) und die
Hauptvariante. Gerechnet wird mit **Stockfish 18 lite** (single-threaded)
in einem Web Worker – lokal im Browser, ohne Internetverbindung. Spieler
sehen die Analyse nicht.

Dafür müssen `stockfish-18-lite-single.js` und
`stockfish-18-lite-single.wasm` neben `chess.html` im `web\`-Verzeichnis
liegen. Zusätzlich sind **MIME-Types** nötig, sonst liefert der AR-Webserver
die Dateien nicht aus:

| File extension | MIME Type |
|----------------|-----------|
| `js` | `application/javascript` |
| `wasm` | `application/wasm` |

Fehlen die Dateien oder die MIME-Einträge, bleibt die Analyse einfach aus –
das Spiel funktioniert unverändert weiter.

#### Auswertung nach der Partie

Sobald eine Partie endet, analysiert **jeder** Client die komplette Partie
neu und zeigt eine Auswertung: Ergebnis, Bewertungsverlauf als Diagramm,
Genauigkeit beider Spieler und die Aufschlüsselung der Züge nach Qualität.
Auch Spieler bekommen sie – die Engine startet erst nach Spielende, hilft
also während der Partie niemandem. Über *Auswertung* im Seitenpanel lässt
sie sich erneut öffnen.

Gerechnet wird mit Suchtiefe 14; eine Partie über 33 Halbzüge braucht auf
einem normalen PC rund drei Sekunden, auf schwächerer Panel-Hardware
entsprechend länger (der Fortschritt wird angezeigt).

#### Zugbewertung

Jeder Zug wird eingestuft, indem die Bewertung vor dem Zug gegen die
Bewertung danach gehalten wird (aus Sicht des Ziehenden). Gemessen wird
dabei der Verlust an **Gewinnwahrscheinlichkeit**, nicht in Zentibauern:
ein Abfall von +8 auf +3 ändert am Ausgang nichts, derselbe Bauernwert in
ausgeglichener Stellung entscheidet dagegen die Partie.

| Verlust (Gewinn-%) | Einstufung | Symbol |
|--------------------|------------|--------|
| < 2 | Bester Zug | – |
| < 10 | Gut | – |
| < 20 | Ungenau | `?!` |
| < 30 | Fehler | `?` |
| ab 30 | Grober Fehler | `??` |

Die Einstufung des letzten Zuges steht unter der Bewertung, die Zugliste
markiert Ungenauigkeiten und schlechter farbig. Bewertet wird nur, solange
die Partie Zug für Zug fortschreitet – wer mitten im Spiel als Zuschauer
dazukommt, sieht Einstufungen erst ab seinem Beitritt.

### Platzbedarf in der SPS-Variable

Plätze, Namen, Zuschauer, Zeitmodus, Restzeiten und Zugliste liegen
gemeinsam in **einer** Variable:

```
w=<id>:<Name>;b=<id>:<Name>;v=<id>:<Name>,…;tc=180+2;tw=<ms>;tb=<ms>;st=run;res=…|e2e4 e7e5
```

Der Kopf ist rund 120 Zeichen lang, je Zuschauer kommen ~20 dazu (maximal
8 Zuschauer werden übertragen), die Zugliste wächst um ~5 Zeichen pro Zug.
Für eine lange Partie mit mehreren Zuschauern sollte die Variable daher
großzügig dimensioniert sein – `STRING[1000]` reicht für etwa 60 Züge mit
voller Zuschauerliste, für längere Partien entsprechend größer wählen.

### Voraussetzungen für `?plc`

1. Globale SPS-Variable, z. B. `gChessState : STRING[1000]`
2. `response.asp` liegt im Web-Root neben `chess.html`
3. In der CPU-Konfiguration unter *ASP Goform configuration*:
   - `Activate ASP Goform` = **on**
   - `ASP Goform readonly mode` = **off** (sonst kann nicht geschrieben werden)
4. MIME-Types für `html` und `asp` konfiguriert, sonst liefert der
   Webserver die Dateien nicht aus

### Funktionsweise der Synchronisation

Der komplette Spielverlauf wird als Zugliste serialisiert (`e2e4 e7e5 g1f3`)
und in der SPS-Variable abgelegt. Jeder Client schreibt nach seinem Zug und
liest einmal pro Sekunde; bei einer Änderung baut er das Brett aus der
Zugliste neu auf. Dadurch sehen beide Seiten immer dieselbe Stellung.

Der Zugriff läuft über die Goform-Schnittstelle des AR-Webservers:

```
POST /goform/ReadWrite
  redirect=/response.asp&variable=<PV>&value=<wert>&write=1   (schreiben)
  redirect=/response.asp&variable=<PV>&value=none&read=1      (lesen)
```

## Einbindung in mapp View

Das Spiel kann über ein **WebViewer**-Widget in einer mapp-View-Seite
angezeigt werden:

| Property | Wert |
|----------|------|
| `host` | *leer* (derselbe Server) |
| `port` | `80` |
| `path` | `chess.html` |
| `query` | `plc` (für den Zwei-PC-Betrieb) |

Hinweis: Der mapp-View-Server (oft Port 81) und der AR-Webserver (Port 80)
sind zwei verschiedene Server. Die Datei wird vom AR-Webserver
ausgeliefert, nicht aus den mapp-View-Resources.
