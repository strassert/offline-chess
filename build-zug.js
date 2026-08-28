#!/usr/bin/env node
/*
 * build-zug.js — baut die Einzeldatei-App `zug.html` aus den Quellen des
 * Zugsimulators (Repo strassert/Test: index.html + style.css + game.js).
 *
 * Nutzung:
 *   node build-zug.js                         # holt die Quellen von GitHub (main)
 *   TEST_DIR=/pfad/zu/Test node build-zug.js  # baut aus einem lokalen Test-Checkout
 *
 * Liegt ein Test-Checkout als Nachbarordner (../Test) neben diesem Repo, wird
 * er automatisch verwendet. Ergebnis: zug.html neben diesem Skript.
 *
 * Benötigt Node 18+ (globales fetch) für den GitHub-Weg.
 */
const fs = require("fs");
const path = require("path");

const RAW = "https://raw.githubusercontent.com/strassert/Test/refs/heads/main";
const FILES = ["index.html", "style.css", "game.js"];

function localDir() {
  const cands = [process.env.TEST_DIR, path.join(__dirname, "..", "Test"), path.join(process.cwd(), "Test")];
  for (const c of cands) {
    if (c && fs.existsSync(path.join(c, "game.js"))) return c;
  }
  return null;
}

async function readSource(name, dir) {
  if (dir) return fs.readFileSync(path.join(dir, name), "utf8");
  const url = RAW + "/" + name;
  const r = await fetch(url);
  if (!r.ok) throw new Error("Konnte " + url + " nicht laden: HTTP " + r.status);
  return await r.text();
}

(async () => {
  const dir = localDir();
  const [html0, css, js] = await Promise.all(FILES.map((f) => readSource(f, dir)));

  const html = html0
    .replace(/<link rel="stylesheet" href="style\.css"\s*\/?>/, "<style>\n" + css + "\n</style>")
    .replace(/<script src="game\.js"><\/script>/, "<script>\n" + js + "\n</script>");

  if (html.includes('href="style.css"') || html.includes('src="game.js"')) {
    throw new Error("Einbetten fehlgeschlagen – <link>/<script> nicht wie erwartet gefunden.");
  }

  const out = path.join(__dirname, "zug.html");
  fs.writeFileSync(out, html);
  console.log("✔ zug.html gebaut:", fs.statSync(out).size, "Bytes",
    dir ? "(aus lokalem Test: " + dir + ")" : "(von GitHub main)");
})().catch((e) => { console.error("✖ Fehler:", e.message); process.exit(1); });
