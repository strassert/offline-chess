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

/* Jedes Spiel hat seinen eigenen Stand: ?spiel=vier liegt in state-vier.txt,
   ohne Angabe bleibt es bei state.txt. Nur Kleinbuchstaben und Ziffern sind
   erlaubt - der Name wird zu einem Dateinamen, da darf nichts durchrutschen. */
function raumDatei(string $basis): string
{
    $raum = (string) ($_GET['spiel'] ?? '');
    if ($raum !== '' && preg_match('/^[a-z0-9]{1,8}$/', $raum) === 1) {
        return __DIR__ . '/' . $basis . '-' . $raum . '.txt';
    }
    return __DIR__ . '/' . $basis . '.txt';
}

$file = raumDatei('state');
if (@file_put_contents($file, '') === false) {
    http_response_code(500);
    echo json_encode(['error' => 'Verzeichnis nicht beschreibbar']);
    exit;
}
echo json_encode(['ok' => true]);
