#!/bin/sh
# Schach im LXC-Container einrichten – holt alles von GitHub.
#
#   Öffentliches Repo:
#     curl -fsSL https://raw.githubusercontent.com/strassert/offline-chess/lxc-server/server/bootstrap.sh | sh
#
#   Privates Repo (Token mit Leserecht):
#     export GITHUB_TOKEN=ghp_xxx
#     curl -fsSL -H "Authorization: Bearer $GITHUB_TOKEN" \
#       https://raw.githubusercontent.com/strassert/offline-chess/lxc-server/server/bootstrap.sh | sh
#
# Erneuter Aufruf aktualisiert die Installation und startet den Dienst neu.
#
# Einstellbar über Umgebungsvariablen:
#   REPO=strassert/offline-chess  BRANCH=lxc-server  PORT=8080
#   APP=/opt/offline-chess        DATA=/var/lib/offline-chess
#   GITHUB_TOKEN=…                SKIP_SERVICE=1   (nur Dateien, kein systemd)
set -eu

REPO=${REPO:-strassert/offline-chess}
BRANCH=${BRANCH:-lxc-server}
APP=${APP:-/opt/offline-chess}
DATA=${DATA:-/var/lib/offline-chess}
PORT=${PORT:-8080}
TOKEN=${GITHUB_TOKEN:-}
SKIP_SERVICE=${SKIP_SERVICE:-}
SVCUSER=chess

say() { printf '\n== %s ==\n' "$1"; }
die() { printf '\nFehler: %s\n' "$1" >&2; exit 1; }

[ "$(id -u)" = "0" ] || die "Bitte als root ausführen (im LXC: einfach 'sh bootstrap.sh')."

say "Pakete prüfen"
MISSING=""
command -v git  >/dev/null 2>&1 || MISSING="$MISSING git"
command -v node >/dev/null 2>&1 || MISSING="$MISSING nodejs"
command -v curl >/dev/null 2>&1 || MISSING="$MISSING curl"
[ -f /etc/ssl/certs/ca-certificates.crt ] || MISSING="$MISSING ca-certificates"
if [ -n "$MISSING" ]; then
  echo "Installiere:$MISSING"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  # shellcheck disable=SC2086
  apt-get install -y -qq $MISSING
fi
echo "node $(node --version), git $(git --version | awk '{print $3}')"

case "$(node --version)" in
  v1[0-7].*|v[0-9].*) die "Node ist zu alt ($(node --version)), benötigt wird v18 oder neuer." ;;
esac

say "Quellen holen"
URL="https://github.com/$REPO.git"
[ -n "$TOKEN" ] && URL="https://x-access-token:$TOKEN@github.com/$REPO.git"

if [ -d "$APP/.git" ]; then
  echo "Aktualisiere $APP"
  git -C "$APP" remote set-url origin "$URL"
  git -C "$APP" fetch --depth 1 origin "$BRANCH" \
    || die "Konnte nicht von GitHub laden. Bei privatem Repo GITHUB_TOKEN setzen."
  git -C "$APP" checkout -q -B "$BRANCH" FETCH_HEAD
else
  echo "Klone nach $APP"
  rm -rf "$APP"
  git clone --depth 1 --branch "$BRANCH" "$URL" "$APP" \
    || die "Konnte nicht von GitHub laden. Bei privatem Repo GITHUB_TOKEN setzen."
fi
# Token nicht dauerhaft in der Git-Konfiguration liegen lassen
git -C "$APP" remote set-url origin "https://github.com/$REPO.git"
echo "Stand: $(git -C "$APP" log -1 --format='%h %s')"

[ -f "$APP/chess.html" ] || die "chess.html fehlt im Branch '$BRANCH'."
[ -f "$APP/server/server.js" ] || die "server/server.js fehlt im Branch '$BRANCH'."
if [ ! -f "$APP/stockfish-18-lite-single.wasm" ]; then
  echo "Hinweis: Engine-Dateien fehlen – gespielt werden kann, die Analyse bleibt aus."
fi

say "Benutzer und Verzeichnisse"
id "$SVCUSER" >/dev/null 2>&1 || \
  useradd --system --home "$DATA" --shell /usr/sbin/nologin "$SVCUSER"
mkdir -p "$DATA"
chown -R "$SVCUSER:$SVCUSER" "$DATA"
# Das Programmverzeichnis bleibt root – der Dienst liest dort nur, und git
# verweigert sonst beim nächsten Update die Arbeit ("dubious ownership").
chown -R root:root "$APP"
chmod -R a+rX "$APP"

if [ -n "$SKIP_SERVICE" ]; then
  say "Fertig (ohne Dienst)"
  echo "Start von Hand:  PORT=$PORT ROOT=$APP STATE_FILE=$DATA/state.txt node $APP/server/server.js"
  exit 0
fi

say "Dienst einrichten"
cat > /etc/systemd/system/offline-chess.service <<EOF
[Unit]
Description=Offline-Schach (Server für Netzwerk-Partien)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$SVCUSER
Group=$SVCUSER
WorkingDirectory=$APP
ExecStart=$(command -v node) $APP/server/server.js
Environment=PORT=$PORT
Environment=HOST=0.0.0.0
Environment=ROOT=$APP
Environment=STATE_FILE=$DATA/state.txt
Restart=always
RestartSec=3
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$DATA

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable -q offline-chess
systemctl restart offline-chess

say "Prüfen"
i=0
while [ $i -lt 20 ]; do
  if curl -fsS "http://127.0.0.1:$PORT/api/health" >/dev/null 2>&1; then break; fi
  i=$((i + 1)); sleep 1
done
if curl -fsS "http://127.0.0.1:$PORT/api/health" >/dev/null 2>&1; then
  IP=$(hostname -I 2>/dev/null | awk '{print $1}')
  printf '\nLäuft. Aufrufen unter:  http://%s:%s/\n\n' "${IP:-<container-ip>}" "$PORT"
  echo "Protokoll:  journalctl -u offline-chess -f"
  echo "Update:     sh $APP/server/bootstrap.sh"
else
  echo "Dienst antwortet nicht. Protokoll:"
  journalctl -u offline-chess --no-pager --lines=20 || true
  exit 1
fi
