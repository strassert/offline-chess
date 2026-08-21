#!/bin/sh
# Installiert das Schachspiel als Dienst in einem Debian-/Ubuntu-LXC-Container.
# Aufruf als root im entpackten Projektverzeichnis:  sh server/install.sh
set -eu

APP=/opt/offline-chess
DATA=/var/lib/offline-chess
SRC=$(cd "$(dirname "$0")/.." && pwd)

echo "== Node prüfen =="
if ! command -v node >/dev/null 2>&1; then
  echo "Node wird installiert …"
  apt-get update
  apt-get install -y nodejs
fi
node --version

echo "== Benutzer anlegen =="
id chess >/dev/null 2>&1 || useradd --system --home "$DATA" --shell /usr/sbin/nologin chess

echo "== Dateien nach $APP kopieren =="
mkdir -p "$APP/server" "$DATA"
cp "$SRC/chess.html" "$APP/"
cp "$SRC/server/server.js" "$APP/server/"
# Engine-Dateien nur mitnehmen, wenn vorhanden (Analyse ist optional)
for f in stockfish-18-lite-single.js stockfish-18-lite-single.wasm; do
  [ -f "$SRC/$f" ] && cp "$SRC/$f" "$APP/" || echo "Hinweis: $f fehlt – Analyse bleibt aus"
done
chown -R chess:chess "$APP" "$DATA"

echo "== Dienst einrichten =="
cp "$SRC/server/offline-chess.service" /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now offline-chess

echo
echo "Fertig. Status:"
systemctl --no-pager --lines=5 status offline-chess || true
IP=$(hostname -I 2>/dev/null | awk '{print $1}')
echo
echo "Erreichbar unter:  http://${IP:-<container-ip>}:8080/"
