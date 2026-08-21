<?php
/* Meldet, dass die Server-Betriebsart verfügbar ist – die Seite erkennt
   daran, dass sie nicht im Hotseat-Modus laufen muss. */
declare(strict_types=1);

header('Cache-Control: no-store');
header('Content-Type: application/json; charset=utf-8');

$file = __DIR__ . '/state.txt';
$writable = is_file($file) ? is_writable($file) : is_writable(__DIR__);

echo json_encode([
    'ok'       => true,
    'backend'  => 'php',
    'writable' => $writable,
    'version'  => is_file($file) ? (int) filemtime($file) : 0,
]);
