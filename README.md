# Offline-Schach für B&R-Steuerung

Schachspiel als einzelne HTML-Datei, gehostet vom AR-Webserver einer
B&R-SPS. Läuft komplett offline, ohne externe Bibliotheken.

## Dateien

| Datei | Zweck |
|-------|-------|
| `chess.html` | Das Spiel – vollständige Schachregeln, Zugliste, Undo, Brett drehen |
| `response.asp` | Rückgabeseite für den Goform-Zugriff (**nur für PLC-Sync nötig**) |
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
| `chess.html` | Standalone. Zwei Personen spielen abwechselnd an einem Bildschirm (Hotseat). |
| `chess.html?plc` | **Zwei PCs, ein Brett.** Spielstand wird über eine SPS-Variable synchronisiert. |
| `chess.html?plc&pv=meineVar` | Wie oben, aber mit abweichendem PV-Namen (Default: `gChessState`). |
| `chess.html?demo` | Synchronisation zwischen zwei Tabs desselben Browsers (nur zum Testen). |

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
