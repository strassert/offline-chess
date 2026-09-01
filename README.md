# Offline-Schach für B&R-Steuerung

Schachspiel als einzelne HTML-Datei, gehostet vom AR-Webserver einer
B&R-SPS. Läuft komplett offline, ohne externe Bibliotheken.

## Dateien

| Datei | Zweck |
|-------|-------|
| `chess.html` | Das Spiel – vollständige Schachregeln, Zugliste, Undo, Brett drehen |
| `zug.html` | Zugsimulator (Shinkansen, S-Bahn Salzburg) – klassisch oder Kindermodus (3+); Einzeldatei, aus [strassert/Test](https://github.com/strassert/Test) gebaut via `build-zug.js` |
| `build-zug.js` | baut `zug.html` neu aus den Quellen des Zugsimulators (`node build-zug.js`) |
| `dashboard.html` | Startseite fürs Webhosting: Anwendungen, dazu Wetter und Abfuhrtermine (siehe [README-WEBHOSTING](README-WEBHOSTING.md#startseite)) |
| `manifest.webmanifest`, `sw.js`, `icon-*.png` | damit die Startseite auf dem Handy als App abgelegt werden kann |
| `deploy/bench.js` | misst den Webspace unter mehreren gleichzeitigen Zugriffen |
| `response.asp` | Rückgabeseite für den Goform-Zugriff (**nur für PLC-Sync nötig**) |
| `stockfish-18-lite-single.js` | Stockfish-Engine (Loader, 21 KB) – **nur für die Zuschauer-Analyse** |
| `stockfish-18-lite-single.wasm` | Stockfish-Engine (7,3 MB) – dito |
| `PV_Access.js` | B&R-Original-Bibliothek für PV-Zugriff (Referenz; `chess.html` bringt die Logik selbst mit) |
| `pvtest.html` | Diagnoseseite: probiert Goform-Request-Formate durch und misst, wie lang ein Wert sein darf, bis der Webserver ihn kürzt |

Die Eröffnungsdatenbank (2833 Eröffnungen, Quelle
[lichess-org/chess-openings](https://github.com/lichess-org/chess-openings),
CC0) steckt komprimiert in `chess.html` – keine zusätzliche Datei nötig.

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
| `chess.html` | Hotseat ohne Steuerung: zwei Personen spielen abwechselnd an einem Bildschirm, mit Auswertung nach Spielende. |
| `chess.html?plc&side=w` | Überspringt die Lobby und belegt direkt Weiß (`b` = Schwarz, `v` = Zuschauer). |
| `chess.html?plc&pv=meineVar` | Abweichender PV-Name (Default: `gChessState`). |
| `chess.html?demo` | Synchronisation zwischen zwei Tabs desselben Browsers (nur zum Testen). |
| `chess.html?plc&selbsttest` | **Versteckt.** Zwei Fenster spielen automatisch eine Partie gegeneinander und melden, wenn ein Zug nicht ankommt (siehe [Selbsttest](#selbsttest)). |

### Lobby

Alle Beteiligten öffnen denselben Link. In der Lobby wird ein **Name**
eingegeben und danach ein Platz gewählt; belegte Plätze sind ausgegraut.
Wer einen Platz hat, kann ihn über *Platz freigeben* abgeben, Zuschauer
kommen über *Platz wählen* zurück zur Auswahl. Falls ein Platz hängen
bleibt (z. B. PC ausgeschaltet), gibt *Plätze zurücksetzen* alles frei.

### Bedenkzeit

Vor dem Start wählen die Spieler den Modus **3 + 2**, **5 + 5** (Minuten
plus Sekunden je Zug) oder **10 Min** (ohne Inkrement). Das Brett bleibt
gesperrt, bis ein Spieler *Spiel starten* drückt. Läuft eine Uhr ab, endet
die Partie und das Ergebnis wird allen angezeigt – ebenso bei Schachmatt
oder Patt.

Es zählt nur die Uhr der Seite am Zug. Jeder Client zählt lokal ab dem
Empfang des Zustands herunter, verbindlich rechnet der ziehende Spieler ab.
Dadurch ist keine Uhrzeit-Synchronisation zwischen den PCs nötig; pro Zug
kann die Anzeige um die Abfragezeit (max. 1 s) abweichen.

### Vergangene Partien und Rangliste

Endet eine Partie, wird sie mit Namen, Ausgang, Zuganzahl und Zeitpunkt
festgehalten. Die letzten **40** Partien stehen in der Lobby und unter der
Auswertung, umschaltbar zwischen *Partien* und *Rangliste*.

Die Rangliste zählt wie im Schach üblich: Sieg 1, Remis ½, Niederlage 0.
Sortiert wird nach Siegquote, bei Gleichstand nach Anzahl der Partien. Wer
weniger als drei Partien hat, wird gedämpft dargestellt – eine Quote aus
einer einzigen Partie sagt wenig.

Den Eintrag schreibt nur der Client, der das Ende auslöst; die anderen
laden ihn nach. Sonst stünde jede Partie mehrfach in der Liste.

#### Eigene Ablage

Die Historie liegt **getrennt vom Spielstand**, weil sie sich nur am
Partieende ändert und viel länger leben soll:

| Betriebsart | Ablage |
|-------------|--------|
| Steuerung | zweite Variable, Vorgabe `gChessHist` (über `?hpv=` änderbar) |
| Node-Server | `hist.txt` neben dem Spielstand |
| PHP-Webhosting | `api/hist.txt` |
| Hotseat | Browser-Speicher (localStorage) |

Gelesen wird sie nur, wenn sie jemand sieht – beim Öffnen der Lobby, beim
Anzeigen der Auswertung und nach einem Partieende, höchstens alle fünf
Sekunden. Im laufenden Spiel bleibt es damit bei einer Abfrage pro Sekunde.

**Variable auf der Steuerung:** `gChessHist : STRING[2000]`, am besten
**remanent** – dann übersteht die Historie einen Neustart der Steuerung.
Ein Eintrag misst höchstens 38 Zeichen, 40 Einträge also rund 1520.

### Anzeige im Spiel

Das Seitenpanel zeigt beide Spieler mit Namen und Restzeit (die Seite am
Zug ist hervorgehoben, unter 30 s wird die Uhr rot) sowie die Namen aller
Zuschauer. Ein Spieler kann nur ziehen, wenn seine Farbe am Zug ist;
Schwarz sieht das Brett gedreht.

#### Größe und Aufteilung

Es gibt keine feste Fenstergröße. Das Brett bemisst sich an dem, was das
Fenster hergibt, und wächst beim Ziehen am Rand mit:

| Fenster | Aufteilung |
|---------|------------|
| breiter als hoch (Desktop, Panel, Handy quer) | Brett links, Panel rechts, beide gleich hoch |
| höher als breit oder schmaler als 600 px | Brett oben, Panel darunter, Seite scrollt |

Ein 1000 × 1000-Panel bekommt damit ein 738er Brett, ein 1920 × 1080-Bildschirm
ein 900er (mehr wird nicht vergeben), ein Handy im Hochformat die volle
Breite. Feldbeschriftung, Markierungen und die Umwandlungsauswahl skalieren
mit. Das läuft ohne JavaScript, allein über CSS – Drehen des Geräts und
Ziehen am Fenster wirken sofort.

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
neu und zeigt eine Auswertung. Auch Spieler bekommen sie – die Engine
startet erst nach Spielende, hilft also während der Partie niemandem. Über
*Auswertung* im Seitenpanel lässt sie sich erneut öffnen.

Das gilt genauso für den **Hotseat-Betrieb** ohne Steuerung: endet die
Partie durch Matt oder Patt, öffnet sich dieselbe Auswertung inklusive
Durchgehen. Die Spieler heißen dort schlicht Weiß und Schwarz. Eine
laufende Bewertung gibt es im Hotseat bewusst nicht – beide sitzen vor
demselben Bildschirm.

Enthalten sind:

- **Eröffnungsname** aus der eingebetteten Datenbank (2833 Eröffnungen)
- **Bewertungsverlauf** als Diagramm – ein Klick springt an die Stelle
- **Genauigkeit** beider Spieler und eine grobe **Wertungsschätzung**
  (erst ab 20 Halbzügen, bewusst nur ein Richtwert)
- **Zugkategorien**: Glanzzug `!!`, Starker Zug `!`, Bester Zug, Gut,
  Buchzug, Ungenau `?!`, Verpasst, Fehler `?`, Grober Fehler `??`
- **Teilgenauigkeit** für Eröffnung, Mittelspiel und Endspiel
- **Schlüsselmomente**: die drei größten Einbrüche der Partie

##### Partie durchgehen

Über *Partie durchgehen* lässt sich die Partie Zug für Zug nachspielen: das
Brett zeigt die jeweilige Stellung, daneben stehen Bewertung, Einstufung des
Zuges und – wenn er nicht der beste war – der Hinweis **„besser: …"**.
Navigation über die Schaltflächen oder die Pfeiltasten.

##### Rechenaufwand

Die Analyse läuft in zwei Runden: zuerst jede Stellung mit Suchtiefe 14,
danach werden nur die kritischen Stellungen (großer Bewertungssprung,
höchstens acht davon) mit Tiefe 17 nachgerechnet. Ohne diese zweite Runde
widerspricht sich die Engine in scharfen Stellungen – sie sieht ein Opfer
erst eine Stellung später und würde ihren eigenen Empfehlungszug abstrafen.

Eine Partie über 33 Halbzüge dauert so rund 16 Sekunden statt 115 Sekunden
bei durchgehend hoher Tiefe. Auf schwächerer Panel-Hardware entsprechend
länger; der Fortschritt wird angezeigt.

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

Zwei Regeln verhindern unsinnige Einstufungen:

- Wer den von der Engine als besten ausgegebenen Zug spielt, verliert
  definitionsgemäß nichts – sonst bestraft die stellungsweise Analyse ihre
  eigene Empfehlung, wenn die Bewertung zwischen zwei Suchen schwankt.
- Ein Buchzug gilt nur als solcher, wenn er die Stellung nicht verdirbt.
  Das Narrenmatt steht als benannte Eröffnung in der Datenbank, `2. g4`
  bleibt trotzdem ein grober Fehler.

### Platzbedarf in der SPS-Variable

Plätze, Namen, Zuschauer, Zeitmodus, Restzeiten und Zugliste liegen
gemeinsam in **einer** Variable:

```
w=<id>:<Name>;b=<id>:<Name>;tc=180+2;tw=<ms>;tb=<ms>;st=run;res=…;v=<id>:<Name>,…|~zrBQ0k
```

Der Kopf ist rund 60–80 Zeichen lang, je Zuschauer kommen ~20 dazu (maximal
8 Zuschauer werden übertragen, ohne Zuschauer entfällt das Feld ganz). Die
Historie liegt seit ihrer Trennung nicht mehr hier drin.

Die Zugliste kostet **2 Zeichen je Halbzug**: Jedes Feld ist ein einziges
Zeichen (Feldindex 0…63), bei einer Umwandlung kommt der Buchstabe des neuen
Steins dazu. Das führende `~` kennzeichnet diese Schreibweise. Ausgeschrieben
(`e2e4 e7e5`, 5 Zeichen je Halbzug) wird weiterhin gelesen, damit ein Client
mit älterer Fassung nicht sofort aussteigt — geschrieben wird sie nicht mehr.

#### Der Stand wächst nicht über die Variable hinaus

Auch zwei Zeichen je Halbzug wären irgendwann zu viel. Deshalb **wächst der
geteilte Stand gar nicht mehr**: Wird er länger als der verfügbare Platz,
tritt an die Stelle der ersten Züge die Stellung, die sie ergeben haben —
als FEN in den Feldern `sp` (bei welchem Halbzug) und `sf` (die Stellung).
Übertragen wird dann nur noch, was danach kam, und beim nächsten Mal rückt
die Momentaufnahme wieder nach. Die Partielänge ist damit unbegrenzt.

**Lokal geht dabei nichts verloren.** Wer von Anfang an dabei ist, behält den
vollständigen Verlauf: Zugliste, Rücknahme und die Auswertung über die ganze
Partie bleiben, wie sie waren. Kürzer sieht es nur die Leitung. Erkennt ein
Client die Momentaufnahme in seinem eigenen Verlauf wieder, hängt er einfach
die neuen Züge an, statt neu aufzubauen.

Nur wer **mitten in einer langen Partie dazukommt** (oder die Seite neu lädt),
bekommt allein die Momentaufnahme. Sein Brett stimmt, aber die Züge davor
kennt er nicht: Für ihn beginnt die Zugliste dort, die Auswertung rechnet ab
dieser Stellung, und eine Eröffnung wird nicht mehr benannt.

Gemessen: 300 Halbzüge über eine auf 255 Zeichen begrenzte Steuerung, der
Stand pendelt dabei zwischen 210 und 240 Zeichen.

**Empfohlen ist trotzdem `STRING[2000]`** — je mehr Platz, desto seltener
die Momentaufnahme und desto länger bleibt der volle Verlauf auf der Leitung.

#### Wenn der Stand trotzdem gekürzt wird

Der Webserver der Steuerung bestätigt einen Schreibvorgang auch dann mit
`200 OK`, wenn er den Wert unterwegs kürzt — die Goform-Schnittstelle
begrenzt ihn in manchen AR-Versionen auf **255 Zeichen, unabhängig von der
angelegten `STRING`-Länge**. Beide Clients sehen dann verschiedene Bretter,
während die Verbindungsanzeige einwandfrei bleibt: Jede einzelne Anfrage ist
schnell und erfolgreich.

Die Anwendung erkennt das inzwischen selbst. Kommt der eigene Stand
zeichengenau gekürzt zurück, steht in der Verbindungsanzeige

```
Stand wird gekürzt
gChessState: nur 255 von 257 Zeichen kommen an
```

Die genannte Zahl ist die tatsächlich gemessene Obergrenze — und die
Anwendung zieht daraus die Folgerung selbst: Ab dann hält sie den Stand
knapp darunter, statt weiter dagegen zu laufen. Die Meldung erscheint also
höchstens einmal, danach läuft die Partie weiter.

**Ohne zu spielen messen:** `pvtest.html` hat dafür den Abschnitt
*Wie viel passt durch?*. Er schreibt Werte wachsender Länge und liest sie
zurück — auf demselben Weg, den das Spiel nimmt — und nennt die Obergrenze
auf das Zeichen genau. Gibt man eine zweite, anders große Variable an
(z. B. `gChessHist`), beantwortet er auch die eigentliche Frage:

- **Beide enden bei derselben Länge** → der Webserver begrenzt, nicht die
  Variable. Vergrößern hilft nicht.
- **Die zweite fasst mehr** → `gChessState` ist zu klein angelegt und lässt
  sich in Automation Studio vergrößern.

Geprüft wird dabei auch, ob alle Zeichen unverfälscht ankommen (`~ | ; = :`
und Umlaute in Spielernamen). Die genannte Variable wird überschrieben —
also nicht während einer laufenden Partie messen.

Mit 255 Zeichen reicht es für rund 90 Halbzüge (45 Züge) — mit der
ausgeschriebenen Zugliste waren es 37.

### Selbsttest

`chess.html?plc&selbsttest` öffnet ein Feld unten rechts mit einem Knopf. Der
öffnet ein zweites Fenster, beide belegen einen Platz und spielen eine
vollständige Partie gegeneinander — **über denselben Weg wie im Betrieb**, mit
`?plc` also wirklich über die Steuerung. Ein Steuerkanal daneben würde genau
das verdecken, was zu prüfen ist, deshalb gibt es keinen: Jedes Fenster zieht
für seine eigene Farbe und sieht das andere nur über den geteilten Spielstand.

Gemessen wird das Steckenbleiben. Nach jedem eigenen Halbzug läuft eine Uhr,
bis der Gegenzug ankommt; bleibt er aus, ist der Test zu Ende und nennt Stelle
und Umstände. Unterwegs wird einmal eine Rücknahme erbeten und beantwortet.

```
ERGEBNIS
  Halbzüge   : 95
  Stand      : 257 Zeichen
  Gegenzug   : Median 2.0 s, längste 2.0 s (48 Messungen)
  Rücknahme  : angenommen, 12 → 10 Halbzüge
  ACHTUNG    : Stand wird gekürzt, nur 255 von 257 Zeichen kommen an
  HÄNGT — nach Halbzug 95 kam 8 s lang kein Gegenzug
```

| Schalter | Bedeutung |
|----------|-----------|
| `&halbzuege=160` | wie weit gespielt wird (4–400) |
| `&geduld=20000` | ab wann ein ausbleibender Zug als Hänger gilt, in ms |
| `&ruecknahme=12` | bei welchem Halbzug die Rücknahme geprobt wird (`0` = gar nicht) |

**Beide Fenster sichtbar nebeneinander lassen.** Ein verdecktes Fenster wird
vom Browser gedrosselt — Chromium bremst die Zeitgeber im Hintergrund bis auf
einen Aufruf je Minute. Der Test erkennt solche Pausen und rechnet sie heraus,
statt sie der Verbindung anzulasten, aber ungebremst läuft er schneller.

Der Spielstand wird dabei überschrieben, also nicht während einer echten
Partie starten. Mit `?demo&selbsttest` läuft dasselbe ohne Steuerung, nur
zwischen zwei Fenstern desselben Browsers.

### Voraussetzungen für `?plc`

1. Globale SPS-Variable, z. B. `gChessState : STRING[1000]`
2. `response.asp` liegt im Web-Root neben `chess.html`
3. In der CPU-Konfiguration unter *ASP Goform configuration*:
   - `Activate ASP Goform` = **on**
   - `ASP Goform readonly mode` = **off** (sonst kann nicht geschrieben werden)
4. MIME-Types für `html` und `asp` konfiguriert, sonst liefert der
   Webserver die Dateien nicht aus

### Funktionsweise der Synchronisation

Der komplette Spielverlauf wird als Zugliste serialisiert (`~zrBQ0k`, siehe
oben) und in der SPS-Variable abgelegt. Jeder Client schreibt nach seinem Zug und
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
