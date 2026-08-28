<?php
/* Gegenstelle für die Upload-Messung: nimmt Daten an, zählt sie und wirft
   sie weg. Es wird nichts gespeichert und nichts weitergereicht.
   GET meldet, dass es den Endpunkt gibt, und wie groß ein Rumpf sein darf. */
declare(strict_types=1);

const MAX_BODY = 8388608;               // 8 MB je Anfrage

header('Cache-Control: no-store');
header('Content-Type: application/json; charset=utf-8');

if (($_SERVER['REQUEST_METHOD'] ?? 'GET') !== 'POST') {
    /* Was PHP tatsächlich durchlässt, entscheidet post_max_size - der Wert
       steht hier, damit die Seite gar nicht erst zu viel schickt. */
    $limit = MAX_BODY;
    $ini = trim((string) ini_get('post_max_size'));
    if ($ini !== '') {
        $n = (int) $ini;
        $e = strtolower(substr($ini, -1));
        if ($e === 'k') { $n *= 1024; }
        elseif ($e === 'm') { $n *= 1048576; }
        elseif ($e === 'g') { $n *= 1073741824; }
        if ($n > 0) { $limit = min($limit, $n); }
    }
    echo json_encode(['ok' => true, 'max' => $limit]);
    exit;
}

$n = 0;
$fp = @fopen('php://input', 'rb');
if ($fp !== false) {
    while (!feof($fp)) {
        $chunk = fread($fp, 65536);
        if ($chunk === false) {
            break;
        }
        $n += strlen($chunk);
        if ($n > MAX_BODY) {
            http_response_code(413);
            echo json_encode(['error' => 'Rumpf zu groß']);
            exit;
        }
    }
    fclose($fp);
}
echo json_encode(['bytes' => $n]);
