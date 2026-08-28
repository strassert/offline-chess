#!/usr/bin/env node
/* ---------------------------------------------------------------
   Messung des Webspace unter mehreren gleichzeitigen Zugriffen.

     node deploy/bench.js https://gg2.members.cablelink.at

   Weitere Schalter:
     -p 6      gleichzeitige Verbindungen        (Vorgabe 6)
     -n 120    Anfragen je Messreihe             (Vorgabe 120)
     -c 4      nachgestellte Schach-Clients      (Vorgabe 4)
     -s 20     Sekunden fuer die Dauerlast       (Vorgabe 20)
     --stark   hebt die Obergrenzen an

   Gemessen wird der Weg zum Server, nicht der Server allein: Auf einem
   geteilten Webspace haengt das Ergebnis auch an den Nachbarn und an der
   eigenen Leitung. Und es ist fremde Rechenzeit - deshalb sind die
   Vorgaben bewusst zurueckhaltend.
   --------------------------------------------------------------- */
'use strict';
const http = require('http');
const https = require('https');
const { URL } = require('url');

/* ---- Schalter lesen ---- */
const argv = process.argv.slice(2);
const zahl = (name, vorgabe) => {
  const i = argv.indexOf(name);
  if (i < 0 || !argv[i + 1]) return vorgabe;
  const v = parseInt(argv[i + 1], 10);
  return isNaN(v) ? vorgabe : v;
};
const basis = argv.find(a => /^https?:\/\//.test(a));
if (!basis) {
  console.error('Aufruf: node deploy/bench.js https://server [-p 6] [-n 120] ' +
                '[-c 4] [-s 20] [--stark]');
  process.exit(1);
}
const stark = argv.includes('--stark');
const P = Math.min(zahl('-p', 6), stark ? 64 : 16);
const N = Math.min(zahl('-n', 120), stark ? 2000 : 400);
const C = Math.min(zahl('-c', 4), stark ? 32 : 12);
const S = Math.min(zahl('-s', 20), stark ? 120 : 60);

const wurzel = basis.replace(/\/+$/, '') + '/';
const mod = wurzel.startsWith('https') ? https : http;
const agent = new mod.Agent({ keepAlive: true, maxSockets: Math.max(P, C) + 4 });

/* ---- eine Anfrage, mit Zeitmessung ---- */
function hole(pfad, opt) {
  opt = opt || {};
  return new Promise(fertig => {
    const u = new URL(pfad + (pfad.indexOf('?') < 0 ? '?' : '&') +
                      'b=' + Date.now() + '.' + Math.random(), wurzel);
    const t0 = process.hrtime.bigint();
    let erstes = 0;
    const req = mod.request(u, {
      method: opt.body ? 'POST' : 'GET',
      agent: agent,
      timeout: 20000,
      headers: Object.assign({
        'Accept-Encoding': 'gzip',
        'User-Agent': 'startseite-bench/1'
      }, opt.body ? { 'Content-Type': 'text/plain',
                      'Content-Length': Buffer.byteLength(opt.body) } : {})
    }, res => {
      erstes = Number(process.hrtime.bigint() - t0) / 1e6;
      let bytes = 0;
      res.on('data', d => { bytes += d.length; });
      res.on('end', () => fertig({
        ok: res.statusCode >= 200 && res.statusCode < 400,
        status: res.statusCode,
        ttfb: erstes,
        ms: Number(process.hrtime.bigint() - t0) / 1e6,
        bytes: bytes,
        kopf: res.headers
      }));
    });
    req.on('timeout', () => { req.destroy(new Error('Zeitueberschreitung')); });
    req.on('error', e => fertig({ ok: false, status: 0, fehler: e.message,
                                  ttfb: 0, ms: Number(process.hrtime.bigint() - t0) / 1e6,
                                  bytes: 0, kopf: {} }));
    if (opt.body) req.write(opt.body);
    req.end();
  });
}

/* ---- Kennzahlen ---- */
function auswerten(name, treffer, dauerMs) {
  const gut = treffer.filter(t => t.ok);
  const zeiten = gut.map(t => t.ms).sort((a, b) => a - b);
  const q = p => zeiten.length ? zeiten[Math.min(zeiten.length - 1,
                  Math.floor(zeiten.length * p))] : 0;
  const fehler = treffer.length - gut.length;
  const codes = {};
  treffer.forEach(t => { const k = t.fehler || t.status;
                         codes[k] = (codes[k] || 0) + 1; });
  return {
    name: name, n: treffer.length, fehler: fehler,
    rate: dauerMs > 0 ? (treffer.length / (dauerMs / 1000)) : 0,
    min: zeiten[0] || 0, med: q(0.5), p90: q(0.9), p95: q(0.95),
    max: zeiten[zeiten.length - 1] || 0,
    ttfb: gut.length ? gut.map(t => t.ttfb).sort((a, b) => a - b)[gut.length >> 1] : 0,
    bytes: treffer.reduce((sum, t) => sum + t.bytes, 0),
    codes: codes
  };
}
const ms = v => (v < 10 ? v.toFixed(1) : Math.round(v).toString());
function zeile(r) {
  const leer = (r.n - r.fehler) === 0;          // nichts durchgekommen
  const w = v => (leer ? '   -  ' : ms(v).padStart(6));
  console.log('  ' + r.name.padEnd(22) +
    String(r.n).padStart(5) + ' Anfragen' +
    (r.fehler ? ('  ' + String(r.fehler).padStart(4) + ' FEHLER') : '             ') +
    '  ' + (r.rate.toFixed(1) + '/s').padStart(9) +
    '   Median ' + w(r.med) + ' ms' +
    '   p95 ' + w(r.p95) + ' ms' +
    '   max ' + w(r.max) + ' ms');
}

/* ---- Messreihe: N Anfragen, hoechstens P gleichzeitig ---- */
async function reihe(name, pfad, opt, par, anz) {
  const p = par || P, n = anz || N;
  const treffer = [];
  const t0 = Date.now();
  let offen = 0, gestartet = 0;
  await new Promise(fertig => {
    const nach = () => {
      while (offen < p && gestartet < n) {
        gestartet++; offen++;
        hole(pfad, opt).then(t => {
          treffer.push(t); offen--;
          if (treffer.length === n) fertig(); else nach();
        });
      }
    };
    nach();
  });
  return auswerten(name, treffer, Date.now() - t0);
}

/* ---- Steigerung: wo hoert der Server auf, mitzuwachsen? ----
   Dieselbe Anfrage mit 1, 2, 4, 8 … gleichzeitigen Verbindungen. Steigt der
   Durchsatz nicht mehr, waehrend die Antwortzeiten wachsen, ist die Grenze
   erreicht. */
async function steigerung() {
  const stufen = [1, 2, 4, 8, 16, 32].filter(x => x <= (stark ? 32 : 8));
  const aus = [];
  for (const p of stufen) {
    const r = await reihe(p + ' gleichzeitig', 'api/health.php', null, p,
                          Math.max(20, Math.round(N / 4)));
    zeile(r);
    aus.push({ p: p, rate: r.rate, med: r.med, fehler: r.fehler,
               bytes: r.bytes, n: r.n });
  }
  return aus;
}

/* ---- Dauerlast: C Clients fragen jede Sekunde den Spielstand ab ---- */
async function dauerlast() {
  const treffer = [];
  const t0 = Date.now();
  const client = async () => {
    while (Date.now() - t0 < S * 1000) {
      const runde = Date.now();
      treffer.push(await hole('api/state.php'));
      const rest = 1000 - (Date.now() - runde);
      if (rest > 0) await new Promise(r => setTimeout(r, rest));
    }
  };
  await Promise.all(Array.from({ length: C }, client));
  return auswerten(C + ' Clients, ' + S + ' s', treffer, Date.now() - t0);
}

(async () => {
  console.log('Server : ' + wurzel);
  console.log('Aufbau : ' + P + ' gleichzeitig, ' + N + ' Anfragen je Reihe, ' +
              'Dauerlast ' + C + ' Clients / ' + S + ' s\n');

  /* Was fuer ein Server ist das ueberhaupt? */
  const probe = await hole('index.html');
  if (!probe.ok) {
    console.error('Server antwortet nicht: ' +
                  (probe.fehler || ('HTTP ' + probe.status)));
    process.exit(1);
  }
  const k = probe.kopf;
  console.log('== Server ==');
  console.log('  ' + (k['server'] || 'ohne Server-Kennung') +
              (k['x-powered-by'] ? (' · ' + k['x-powered-by']) : ''));
  console.log('  Komprimierung: ' + (k['content-encoding'] || 'keine') +
              ' · Verbindung: ' + (k['connection'] || 'unbekannt') +
              ' · erste Antwort nach ' + ms(probe.ttfb) + ' ms');

  const reihen = [];
  console.log('\n== Messreihen ==');
  reihen.push(await reihe('Startseite (statisch)', 'index.html'));
  zeile(reihen[reihen.length - 1]);
  reihen.push(await reihe('PHP (health.php)', 'api/health.php'));
  zeile(reihen[reihen.length - 1]);
  reihen.push(await reihe('Spielstand lesen', 'api/state.php'));
  zeile(reihen[reihen.length - 1]);
  reihen.push(await reihe('PHP schreiben (1 KB)', 'api/speed.php',
                          { body: 'x'.repeat(1024) }));
  zeile(reihen[reihen.length - 1]);

  console.log('\n== Steigerung (api/health.php) ==');
  const stufen = await steigerung();

  console.log('\n== Dauerlast wie im Spiel ==');
  const d = await dauerlast();
  zeile(d);

  console.log('\n== Urteil ==');
  const alle = reihen.concat([d], stufen);
  const fehler = alle.reduce((s, r) => s + r.fehler, 0);
  const spiel = d;
  if (fehler) {
    console.log('  ' + fehler + ' Anfragen sind gescheitert - Aufschluesselung:');
    alle.forEach(r => { if (r.fehler) console.log('    ' + r.name + ': ' +
                        JSON.stringify(r.codes)); });
  } else {
    console.log('  Keine einzige Anfrage gescheitert.');
  }
  console.log('  Spielbetrieb mit ' + C + ' Clients: Median ' + ms(spiel.med) +
              ' ms, p95 ' + ms(spiel.p95) + ' ms.');
  if (spiel.p95 < 300 && !spiel.fehler) {
    console.log('  Das reicht fuer fluessiges Spiel - die Abfrage laeuft ' +
                'im Sekundentakt.');
  } else if (spiel.p95 < 1000) {
    console.log('  Spuerbar, aber brauchbar: einzelne Abfragen brauchen laenger ' +
                'als eine halbe Sekunde.');
  } else {
    console.log('  Zu langsam fuer den Sekundentakt - Zuege wuerden verzoegert ' +
                'ankommen.');
  }
  /* Wo bleibt der Durchsatz stehen? Zwei Stufen ohne nennenswerten Zuwachs
     (unter 15 %) gelten als Grenze. */
  let grenze = null;
  for (let i = 1; i < stufen.length; i++) {
    if (stufen[i].rate < stufen[i - 1].rate * 1.15) { grenze = stufen[i - 1]; break; }
  }
  if (grenze) {
    console.log('  Durchsatz waechst bis ' + grenze.p + ' gleichzeitigen Zugriffen ' +
                '(' + grenze.rate.toFixed(1) + '/s), darueber nicht mehr.');
  } else if (stufen.length) {
    console.log('  Durchsatz waechst bis zur hoechsten geprueften Stufe (' +
                stufen[stufen.length - 1].p + ' gleichzeitig, ' +
                stufen[stufen.length - 1].rate.toFixed(1) + '/s) - mit --stark ' +
                'laesst sich weiter gehen.');
  }

  const stat = reihen[0], php = reihen[1];
  if (php.med > stat.med * 3 && php.med > 100) {
    console.log('  PHP kostet deutlich mehr als eine statische Datei (' +
                ms(stat.med) + ' ms gegen ' + ms(php.med) + ' ms) - typisch ' +
                'fuer geteilte Tarife.');
  }
  const menge = alle.reduce((sum, r) => sum + r.bytes, 0);
  console.log('  Dieser Lauf hat rund ' + (menge / 1048576).toFixed(1) +
              ' MB heruntergeladen.');
  console.log('\n  Gemessen wurde der Weg zu diesem Server, samt eigener Leitung.');
})();
