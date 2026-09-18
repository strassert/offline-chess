#!/usr/bin/env node
/* Spiele-Server für einen Proxmox-LXC-Container.
   Hält die geteilten Spielstände im Speicher, schiebt Änderungen per
   Server-Sent Events an alle Clients und liefert die statischen Dateien aus.
   Bewusst ohne Fremdpakete – nur Node-Bordmittel. */
'use strict';
const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = +(process.env.PORT || 8080);
const HOST = process.env.HOST || '0.0.0.0';
const ROOT = path.resolve(process.env.ROOT || path.join(__dirname, '..'));
const STATE_FILE = process.env.STATE_FILE || path.join(__dirname, 'state.txt');
const HIST_FILE = process.env.HIST_FILE || path.join(path.dirname(STATE_FILE), 'hist.txt');
const MAX_STATE = 64 * 1024;              // Spielstand ist ein kurzer String

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.wasm': 'application/wasm',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.ico': 'image/x-icon'
};

/* ---------- Räume ----------
   Jedes Spiel hat seinen eigenen Stand: ?spiel=vier liegt in state-vier.txt,
   ohne Angabe bleibt es bei state.txt. Dadurch stören sich Schach und Vier
   gewinnt nicht gegenseitig, und ältere Clients (die den Parameter nicht
   kennen) landen weiter im selben Raum wie bisher. */
const raeume = new Map();
const NAME_OK = /^[a-z0-9]{1,8}$/;

function dateiFuer(basis, raum) {
  if (!raum) return basis;
  const e = path.extname(basis);
  return path.join(path.dirname(basis), path.basename(basis, e) + '-' + raum + e);
}

function raumVon(url) {
  const q = url.indexOf('?');
  if (q < 0) return holeRaum('');
  const name = new URLSearchParams(url.slice(q + 1)).get('spiel') || '';
  return holeRaum(NAME_OK.test(name) ? name : '');
}

function holeRaum(name) {
  let r = raeume.get(name);
  if (r) return r;
  r = { name, state: '', version: 0, hist: '', clients: new Set(), saveTimer: null,
        stateFile: dateiFuer(STATE_FILE, name), histFile: dateiFuer(HIST_FILE, name) };
  try {
    r.state = fs.readFileSync(r.stateFile, 'utf8');
    console.log('Spielstand geladen: ' + path.basename(r.stateFile) +
                ' (' + r.state.length + ' Zeichen)');
  } catch (e) { /* erster Start: leer beginnen */ }
  try {
    r.hist = fs.readFileSync(r.histFile, 'utf8');
    console.log('Historie geladen: ' + path.basename(r.histFile) +
                ' (' + r.hist.length + ' Zeichen)');
  } catch (e) { /* noch keine Partien */ }
  raeume.set(name, r);
  return r;
}

function persist(r) {                     // gebündelt schreiben, nicht bei jedem Zug
  clearTimeout(r.saveTimer);
  r.saveTimer = setTimeout(() => {
    fs.writeFile(r.stateFile, r.state, err => {
      if (err) console.error('Speichern fehlgeschlagen:', err.message);
    });
  }, 500);
}

function setState(r, next) {
  if (next === r.state) return;
  r.state = next;
  r.version++;
  const msg = 'data: ' + JSON.stringify({ v: r.version, s: r.state }) + '\n\n';
  for (const res of r.clients) {
    try { res.write(msg); } catch (e) { r.clients.delete(res); }
  }
  persist(r);
}

/* ---------- Hilfsfunktionen ---------- */
function readBody(req, cb) {
  let data = '', tooBig = false;
  req.on('data', chunk => {
    if (tooBig) return;
    data += chunk;
    if (data.length > MAX_STATE) { tooBig = true; data = ''; }
  });
  req.on('end', () => cb(tooBig ? null : data));
}

function sendJson(res, code, obj) {
  const body = JSON.stringify(obj);
  res.writeHead(code, {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': Buffer.byteLength(body),
    'Cache-Control': 'no-store'
  });
  res.end(body);
}

function serveFile(req, res, urlPath) {
  const rel = decodeURIComponent(urlPath.split('?')[0]);
  const file = path.join(ROOT, rel === '/' ? 'chess.html' : rel);
  if (!file.startsWith(ROOT)) { res.writeHead(403); res.end('Forbidden'); return; }
  fs.stat(file, (err, st) => {
    if (err || !st.isFile()) { res.writeHead(404); res.end('Not found'); return; }
    const type = MIME[path.extname(file).toLowerCase()] || 'application/octet-stream';
    // Die Engine ist mehrere MB groß und ändert sich nie – ruhig lange cachen
    const cache = /\.(wasm|js)$/.test(file) ? 'public, max-age=604800' : 'no-cache';
    res.writeHead(200, { 'Content-Type': type, 'Content-Length': st.size,
                         'Cache-Control': cache });
    fs.createReadStream(file).pipe(res);
  });
}

/* ---------- Server ---------- */
const server = http.createServer((req, res) => {
  const url = req.url || '/';
  const pfad = url.split('?')[0];

  if (pfad === '/api/state') {
    const r = raumVon(url);
    if (req.method === 'GET') return sendJson(res, 200, { v: r.version, s: r.state });
    if (req.method === 'POST') {
      return readBody(req, body => {
        if (body === null) return sendJson(res, 413, { error: 'zu groß' });
        setState(r, body);
        sendJson(res, 200, { v: r.version });
      });
    }
    res.writeHead(405); return res.end();
  }

  // Die Historie aendert sich nur am Partieende - daher eigener Endpunkt
  // und keine Uebertragung im Sekundentakt.
  if (pfad === '/api/hist') {
    const r = raumVon(url);
    if (req.method === 'GET') return sendJson(res, 200, { s: r.hist });
    if (req.method === 'POST') {
      return readBody(req, body => {
        if (body === null) return sendJson(res, 413, { error: 'zu groß' });
        r.hist = body;
        fs.writeFile(r.histFile, r.hist, err => {
          if (err) console.error('Historie speichern fehlgeschlagen:', err.message);
        });
        sendJson(res, 200, { ok: true });
      });
    }
    res.writeHead(405); return res.end();
  }

  if (pfad === '/api/events') {
    const r = raumVon(url);
    res.writeHead(200, {
      'Content-Type': 'text/event-stream; charset=utf-8',
      'Cache-Control': 'no-store',
      'Connection': 'keep-alive',
      'X-Accel-Buffering': 'no'
    });
    res.write('retry: 2000\n\n');
    res.write('data: ' + JSON.stringify({ v: r.version, s: r.state }) + '\n\n');
    r.clients.add(res);
    // Kommentarzeilen halten die Verbindung durch Proxys hindurch offen
    const ping = setInterval(() => { try { res.write(': ping\n\n'); } catch (e) {} }, 25000);
    req.on('close', () => { clearInterval(ping); r.clients.delete(res); });
    return;
  }

  if (pfad === '/api/reset' && req.method === 'POST') {
    const r = raumVon(url);
    setState(r, '');
    return sendJson(res, 200, { v: r.version });
  }

  if (pfad === '/api/health') {
    let clients = 0;
    for (const r of raeume.values()) clients += r.clients.size;
    return sendJson(res, 200, { ok: true, version: raumVon(url).version, clients,
                                raeume: [...raeume.keys()].map(n => n || 'schach'),
                                uptime: Math.round(process.uptime()) });
  }

  if (req.method !== 'GET' && req.method !== 'HEAD') { res.writeHead(405); return res.end(); }
  serveFile(req, res, url);
});

holeRaum('');                             // Schach-Stand gleich beim Start laden

server.listen(PORT, HOST, () => {
  console.log('Spiele-Server auf http://' + HOST + ':' + PORT);
  console.log('Dateien aus ' + ROOT);
  console.log('Spielstände neben ' + STATE_FILE);
});

for (const sig of ['SIGINT', 'SIGTERM']) {
  process.on(sig, () => {
    for (const r of raeume.values()) {
      try { fs.writeFileSync(r.stateFile, r.state); } catch (e) {}
      try { fs.writeFileSync(r.histFile, r.hist); } catch (e) {}
    }
    server.close(() => process.exit(0));
    setTimeout(() => process.exit(0), 2000).unref();
  });
}
