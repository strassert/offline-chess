#!/usr/bin/env node
/* Schach-Server für einen Proxmox-LXC-Container.
   Hält den geteilten Spielstand im Speicher, schiebt Änderungen per
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

let state = '';
let version = 0;
const clients = new Set();                // offene SSE-Verbindungen

/* ---------- Zustand ---------- */
try {
  state = fs.readFileSync(STATE_FILE, 'utf8');
  console.log('Spielstand geladen (' + state.length + ' Zeichen)');
} catch (e) { /* erster Start: leer beginnen */ }

let saveTimer = null;
function persist() {                      // gebündelt schreiben, nicht bei jedem Zug
  clearTimeout(saveTimer);
  saveTimer = setTimeout(() => {
    fs.writeFile(STATE_FILE, state, err => {
      if (err) console.error('Speichern fehlgeschlagen:', err.message);
    });
  }, 500);
}

function setState(next) {
  if (next === state) return;
  state = next;
  version++;
  const msg = 'data: ' + JSON.stringify({ v: version, s: state }) + '\n\n';
  for (const res of clients) {
    try { res.write(msg); } catch (e) { clients.delete(res); }
  }
  persist();
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

  if (url === '/api/state') {
    if (req.method === 'GET') return sendJson(res, 200, { v: version, s: state });
    if (req.method === 'POST') {
      return readBody(req, body => {
        if (body === null) return sendJson(res, 413, { error: 'zu groß' });
        setState(body);
        sendJson(res, 200, { v: version });
      });
    }
    res.writeHead(405); return res.end();
  }

  if (url === '/api/events') {
    res.writeHead(200, {
      'Content-Type': 'text/event-stream; charset=utf-8',
      'Cache-Control': 'no-store',
      'Connection': 'keep-alive',
      'X-Accel-Buffering': 'no'
    });
    res.write('retry: 2000\n\n');
    res.write('data: ' + JSON.stringify({ v: version, s: state }) + '\n\n');
    clients.add(res);
    // Kommentarzeilen halten die Verbindung durch Proxys hindurch offen
    const ping = setInterval(() => { try { res.write(': ping\n\n'); } catch (e) {} }, 25000);
    req.on('close', () => { clearInterval(ping); clients.delete(res); });
    return;
  }

  if (url === '/api/reset' && req.method === 'POST') {
    setState('');
    return sendJson(res, 200, { v: version });
  }

  if (url === '/api/health') {
    return sendJson(res, 200, { ok: true, version, clients: clients.size,
                                uptime: Math.round(process.uptime()) });
  }

  if (req.method !== 'GET' && req.method !== 'HEAD') { res.writeHead(405); return res.end(); }
  serveFile(req, res, url);
});

server.listen(PORT, HOST, () => {
  console.log('Schach-Server auf http://' + HOST + ':' + PORT);
  console.log('Dateien aus ' + ROOT);
  console.log('Spielstand in ' + STATE_FILE);
});

for (const sig of ['SIGINT', 'SIGTERM']) {
  process.on(sig, () => {
    try { fs.writeFileSync(STATE_FILE, state); } catch (e) {}
    server.close(() => process.exit(0));
    setTimeout(() => process.exit(0), 2000).unref();
  });
}
