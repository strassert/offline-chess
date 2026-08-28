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
                                         // webcal://… geht auch
const HOSTS  = [];                       // erlaubte Rechnernamen, leer = der aus QUELLE
const FRISCH = 43200;                    // Zwischenspeicher zwölf Stunden
const ANZAHL = 6;                        // so viele kommende Termine ausgeben
/* -------------------------------------------------------------------- */

header('Cache-Control: no-store');
header('Content-Type: application/json; charset=utf-8');

$cache = __DIR__ . '/muell.cache.json';
$lokal = __DIR__ . '/muell.ics';

/* api/muell.php?pruefen=1 sagt beim Einrichten, woran es hakt: Wird die
   Quelle erreicht? Ist es überhaupt ein Kalender? Wie viele Termine kommen
   an? Geprüft wird nur die eingetragene Quelle - eine Adresse von aussen
   nimmt der Endpunkt bewusst nicht entgegen. */
$pruefen = isset($_GET['pruefen']);
if ($pruefen) {
    $b = ['quelle' => QUELLE !== '' ? QUELLE : ($lokal_da = is_file($lokal) ? 'api/muell.ics' : '(nichts eingetragen)'),
          'art' => QUELLE !== '' ? 'Adresse' : (is_file($lokal) ? 'Datei' : 'keine'),
          'zwischenspeicher' => is_file($cache)
              ? (time() - (int) filemtime($cache)) . ' s alt' : 'noch keiner',
          'schreibbar' => is_writable(__DIR__)];
}

/* Frisch genug? Dann gar nicht erst nachsehen. Beim Prüfen aber immer holen. */
if (!$pruefen && is_file($cache) && time() - (int) filemtime($cache) < FRISCH) {
    $roh = (string) file_get_contents($cache);
    if ($roh !== '') { echo $roh; exit; }
}

$ics = '';
if (QUELLE !== '') {
    // Abo-Verweise stehen oft als webcal:// da - das ist https mit anderem Namen
    $adresse = preg_replace('#^webcal://#i', 'https://', QUELLE);
    $teil = parse_url($adresse);
    $host = $teil['host'] ?? '';
    $erlaubt = HOSTS === [] ? [$host] : HOSTS;
    // Nur https und nur der eingetragene Rechner - kein offener Weiterleiter
    if (($teil['scheme'] ?? '') !== 'https' || !in_array($host, $erlaubt, true)) {
        http_response_code(500);
        echo json_encode(['error' => 'Quelle nicht erlaubt (nur https)']);
        exit;
    }
    $ctx = stream_context_create(['http' => [
        'timeout' => 10,
        'header'  => "User-Agent: Startseite/1.0\r\n",
        'follow_location' => 1, 'max_redirects' => 3,
    ]]);
    $ics = (string) @file_get_contents($adresse, false, null, $ctx);
} elseif (is_file($lokal)) {
    $ics = (string) file_get_contents($lokal);
}

if (trim($ics) === '') {
    if ($pruefen) {
        $b['ergebnis'] = QUELLE !== ''
            ? 'Quelle nicht erreichbar oder leer'
            : 'weder QUELLE eingetragen noch api/muell.ics vorhanden';
        echo json_encode($b, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        exit;
    }
    // Nichts Neues - lieber den alten Stand als gar nichts
    if (is_file($cache)) { echo (string) file_get_contents($cache); exit; }
    echo json_encode(['error' => 'nicht eingerichtet']);
    exit;
}
if ($pruefen) {
    $b['bytes'] = strlen($ics);
    $b['kalender'] = strpos($ics, 'BEGIN:VCALENDAR') !== false;
    $b['eintraege'] = substr_count($ics, 'BEGIN:VEVENT');
    $b['anfang'] = mb_substr(trim(str_replace(["\r", "\n"], ' ', $ics)), 0, 120);
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
if ($pruefen) {
    $b['kommende_termine'] = count($termine);
    $b['naechster'] = $termine[0] ?? null;
    $b['ergebnis'] = $termine ? 'in Ordnung' : 'Kalender gelesen, aber kein künftiger Termin';
    echo json_encode($b, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}
echo $aus;
