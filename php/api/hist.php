<?php
/* Vergangene Partien – eigene Ablage, aendert sich nur am Partieende. */
declare(strict_types=1);

const MAX_HIST = 8192;
$file = __DIR__ . '/hist.txt';

header('Cache-Control: no-store');
header('Content-Type: application/json; charset=utf-8');

if (($_SERVER['REQUEST_METHOD'] ?? 'GET') === 'POST') {
    $body = file_get_contents('php://input', false, null, 0, MAX_HIST + 1);
    if ($body === false) {
        $body = '';
    }
    if (strlen($body) > MAX_HIST) {
        http_response_code(413);
        echo json_encode(['error' => 'Historie zu groß']);
        exit;
    }
    $fp = @fopen($file, 'c');
    if ($fp === false) {
        http_response_code(500);
        echo json_encode(['error' => 'Verzeichnis nicht beschreibbar']);
        exit;
    }
    flock($fp, LOCK_EX);
    ftruncate($fp, 0);
    rewind($fp);
    fwrite($fp, $body);
    fflush($fp);
    flock($fp, LOCK_UN);
    fclose($fp);
    echo json_encode(['ok' => true]);
    exit;
}

$hist = '';
if (is_file($file)) {
    $fp = @fopen($file, 'r');
    if ($fp !== false) {
        flock($fp, LOCK_SH);
        $hist = (string) stream_get_contents($fp);
        flock($fp, LOCK_UN);
        fclose($fp);
    }
}
echo json_encode(['s' => $hist], JSON_UNESCAPED_UNICODE);
