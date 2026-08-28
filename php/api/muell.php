<?php
/* Abfuhrtermine für die Startseite.
 *
 * Zwei Wege, je nachdem was die Gemeinde anbietet:
 *
 *  1. Kalender-Adresse (.ics) hier eintragen - die Datei wird einmal je
 *     zwölf Stunden geholt und zwischengespeichert.
 *  2. Keine Adresse: Dann wird eine daneben abgelegte muell.ics gelesen.
 *     Die exportiert man beim Abfallkalender der Gemeinde von Hand und lädt
 *     sie einmal im Jahr mit hoch.
 *
 * Ohne beides meldet der Endpunkt "nicht eingerichtet" und die Startseite
 * blendet die Zeile aus.
 */
declare(strict_types=1);

/* ---- Einstellungen ------------------------------------------------- */
const QUELLE = '';                       // z. B. 'https://…/abfuhrtermine.ics'
const HOSTS  = [];                       // erlaubte Rechnernamen, leer = der aus QUELLE
const FRISCH = 43200;                    // Zwischenspeicher zwölf Stunden
const ANZAHL = 6;                        // so viele kommende Termine ausgeben
/* -------------------------------------------------------------------- */

header('Cache-Control: no-store');
header('Content-Type: application/json; charset=utf-8');

$cache = __DIR__ . '/muell.cache.json';
$lokal = __DIR__ . '/muell.ics';

/* Frisch genug? Dann gar nicht erst nachsehen. */
if (is_file($cache) && time() - (int) filemtime($cache) < FRISCH) {
    $roh = (string) file_get_contents($cache);
    if ($roh !== '') { echo $roh; exit; }
}

$ics = '';
if (QUELLE !== '') {
    $teil = parse_url(QUELLE);
    $host = $teil['host'] ?? '';
    $erlaubt = HOSTS === [] ? [$host] : HOSTS;
    // Nur https und nur der eingetragene Rechner - kein offener Weiterleiter
    if (($teil['scheme'] ?? '') !== 'https' || !in_array($host, $erlaubt, true)) {
        http_response_code(500);
        echo json_encode(['error' => 'Quelle nicht erlaubt']);
        exit;
    }
    $ctx = stream_context_create(['http' => [
        'timeout' => 10,
        'header'  => "User-Agent: Startseite/1.0\r\n",
        'follow_location' => 1, 'max_redirects' => 3,
    ]]);
    $ics = (string) @file_get_contents(QUELLE, false, null, $ctx);
} elseif (is_file($lokal)) {
    $ics = (string) file_get_contents($lokal);
}

if (trim($ics) === '') {
    // Nichts Neues - lieber den alten Stand als gar nichts
    if (is_file($cache)) { echo (string) file_get_contents($cache); exit; }
    echo json_encode(['error' => 'nicht eingerichtet']);
    exit;
}

/* ---- ICS lesen: nur DTSTART und SUMMARY je VEVENT ------------------- */
$ics = str_replace(["\r\n ", "\r\n\t", "\n ", "\n\t"], '', $ics);  // Faltung lösen
$zeilen = preg_split('/\r\n|\n|\r/', $ics) ?: [];
$termine = [];
$heute = date('Y-m-d');
$tag = '';
$was = '';
foreach ($zeilen as $z) {
    if (strpos($z, 'BEGIN:VEVENT') === 0) { $tag = ''; $was = ''; continue; }
    if (strpos($z, 'DTSTART') === 0 && preg_match('/:(\d{8})/', $z, $m)) {
        $tag = substr($m[1], 0, 4) . '-' . substr($m[1], 4, 2) . '-' . substr($m[1], 6, 2);
    } elseif (strpos($z, 'SUMMARY') === 0) {
        $p = strpos($z, ':');
        if ($p !== false) {
            $was = trim(str_replace(['\\,', '\\;', '\\n'], [',', ';', ' '],
                                    substr($z, $p + 1)));
        }
    } elseif (strpos($z, 'END:VEVENT') === 0) {
        if ($tag !== '' && $was !== '' && $tag >= $heute) {
            $termine[] = ['d' => $tag, 't' => mb_substr($was, 0, 40)];
        }
        $tag = ''; $was = '';
    }
}
usort($termine, static fn(array $a, array $b): int => strcmp($a['d'], $b['d']));
$termine = array_slice($termine, 0, ANZAHL);

$aus = json_encode(['stand' => time(), 'termine' => $termine], JSON_UNESCAPED_UNICODE);
@file_put_contents($cache, $aus);        // schlägt fehl, wenn api/ nicht schreibbar ist
echo $aus;
