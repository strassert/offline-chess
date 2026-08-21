<?php
/* Spielstand lesen und schreiben – Gegenstück zum Node-Server für
   klassisches Webhosting. Der Zustand ist ein einzelner kurzer String. */
declare(strict_types=1);

const MAX_STATE = 65536;
$file = __DIR__ . '/state.txt';

header('Cache-Control: no-store');
header('Content-Type: application/json; charset=utf-8');

function version(string $file): int
{
    clearstatcache(true, $file);
    return is_file($file) ? (int) filemtime($file) : 0;
}

if (($_SERVER['REQUEST_METHOD'] ?? 'GET') === 'POST') {
    $body = file_get_contents('php://input', false, null, 0, MAX_STATE + 1);
    if ($body === false) {
        $body = '';
    }
    if (strlen($body) > MAX_STATE) {
        http_response_code(413);
        echo json_encode(['error' => 'Zustand zu groß']);
        exit;
    }
    // Sperren, damit gleichzeitige Züge sich nicht überschreiben
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
    echo json_encode(['v' => version($file)]);
    exit;
}

$state = '';
if (is_file($file)) {
    $fp = @fopen($file, 'r');
    if ($fp !== false) {
        flock($fp, LOCK_SH);
        $state = (string) stream_get_contents($fp);
        flock($fp, LOCK_UN);
        fclose($fp);
    }
}
echo json_encode(['v' => version($file), 's' => $state], JSON_UNESCAPED_UNICODE);
