<?php
/* Leert den Spielstand – hilft, wenn eine Partie festhängt. */
declare(strict_types=1);

header('Cache-Control: no-store');
header('Content-Type: application/json; charset=utf-8');

if (($_SERVER['REQUEST_METHOD'] ?? 'GET') !== 'POST') {
    http_response_code(405);
    echo json_encode(['error' => 'Nur POST']);
    exit;
}

$file = __DIR__ . '/state.txt';
if (@file_put_contents($file, '') === false) {
    http_response_code(500);
    echo json_encode(['error' => 'Verzeichnis nicht beschreibbar']);
    exit;
}
echo json_encode(['ok' => true]);
