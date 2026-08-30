<?php

declare(strict_types=1);

const WAVBITS_DECAP_ORIGIN = 'https://wavbits.com';
const WAVBITS_DECAP_CALLBACK_URL = WAVBITS_DECAP_ORIGIN . '/admin/callback.php';
const WAVBITS_DECAP_CONFIG_FILE = '/etc/httpd/wavbits-decap-oauth.ini';
const WAVBITS_DECAP_SESSION_NAME = 'wavbits_decap_oauth';

function wavbits_decap_no_store_headers(): void
{
    header('Cache-Control: no-store, max-age=0');
    header('Pragma: no-cache');
    header('Referrer-Policy: no-referrer');
    header('X-Content-Type-Options: nosniff');
    header('X-Frame-Options: DENY');
}

function wavbits_decap_require_get(): void
{
    if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'GET') {
        header('Allow: GET');
        wavbits_decap_fail(405, 'GETリクエストだけを受け付けます。');
    }
}

function wavbits_decap_query_string(string $name): ?string
{
    $value = $_GET[$name] ?? null;

    return is_string($value) ? $value : null;
}

/**
 * @return array{client_id: string, client_secret: string}
 */
function wavbits_decap_load_config(): array
{
    if (!is_file(WAVBITS_DECAP_CONFIG_FILE) || !is_readable(WAVBITS_DECAP_CONFIG_FILE)) {
        throw new RuntimeException('Decap CMSのOAuth設定がVPSにありません。');
    }

    $config = parse_ini_file(WAVBITS_DECAP_CONFIG_FILE, false, INI_SCANNER_RAW);
    $clientId = is_array($config) ? ($config['client_id'] ?? null) : null;
    $clientSecret = is_array($config) ? ($config['client_secret'] ?? null) : null;

    if (
        !is_string($clientId)
        || preg_match('/\A[A-Za-z0-9]{16,128}\z/', $clientId) !== 1
        || !is_string($clientSecret)
        || preg_match('/\A[A-Za-z0-9]{32,128}\z/', $clientSecret) !== 1
    ) {
        throw new RuntimeException('Decap CMSのOAuth設定を読み取れません。');
    }

    return [
        'client_id' => $clientId,
        'client_secret' => $clientSecret,
    ];
}

function wavbits_decap_start_session(): void
{
    ini_set('session.use_only_cookies', '1');
    ini_set('session.use_strict_mode', '1');
    session_name(WAVBITS_DECAP_SESSION_NAME);
    session_set_cookie_params([
        'lifetime' => 600,
        'path' => '/admin/',
        'secure' => true,
        'httponly' => true,
        'samesite' => 'Lax',
    ]);

    if (!session_start()) {
        throw new RuntimeException('OAuthセッションを開始できません。');
    }
}

function wavbits_decap_fail(int $status, string $message): never
{
    http_response_code($status);
    wavbits_decap_no_store_headers();
    header("Content-Security-Policy: default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; frame-ancestors 'none'");
    header('Content-Type: text/html; charset=UTF-8');

    $safeMessage = htmlspecialchars($message, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');

    echo <<<HTML
<!doctype html>
<html lang="ja">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Decap CMS OAuth</title>
  </head>
  <body>
    <h1>認証を完了できませんでした</h1>
    <p>{$safeMessage}</p>
  </body>
</html>
HTML;

    exit;
}

/**
 * @param array<string, string> $payload
 */
function wavbits_decap_render_callback(string $status, array $payload): never
{
    if (!in_array($status, ['success', 'error'], true)) {
        throw new InvalidArgumentException('Invalid callback status.');
    }

    $nonce = base64_encode(random_bytes(18));
    $message = 'authorization:github:' . $status . ':' . json_encode(
        $payload,
        JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS | JSON_HEX_QUOT | JSON_THROW_ON_ERROR,
    );
    $originJson = json_encode(WAVBITS_DECAP_ORIGIN, JSON_UNESCAPED_SLASHES | JSON_THROW_ON_ERROR);
    $messageJson = json_encode(
        $message,
        JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS | JSON_HEX_QUOT | JSON_THROW_ON_ERROR,
    );
    $safeNonce = htmlspecialchars($nonce, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');

    wavbits_decap_no_store_headers();
    header(
        "Content-Security-Policy: default-src 'none'; script-src 'nonce-{$nonce}'; "
        . "style-src 'nonce-{$nonce}'; base-uri 'none'; frame-ancestors 'none'",
    );
    header('Content-Type: text/html; charset=UTF-8');

    echo <<<HTML
<!doctype html>
<html lang="ja">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Decap CMS OAuth</title>
    <style nonce="{$safeNonce}">
      body { font-family: system-ui, sans-serif; margin: 2rem; line-height: 1.6; }
    </style>
  </head>
  <body>
    <p id="status" aria-live="polite">GitHub認証を完了しています…</p>
    <button id="close-window" type="button" hidden>この画面を閉じる</button>
    <script nonce="{$safeNonce}">
      (() => {
        const origin = {$originJson};
        const result = {$messageJson};
        const status = document.getElementById("status");
        const closeButton = document.getElementById("close-window");
        const opener = window.opener;
        const handshake = "authorizing:github";
        let resultSent = false;

        if (!opener) {
          status.textContent = "管理画面を開いたまま、もう一度ログインしてください。";
          return;
        }

        const sendResult = () => {
          if (resultSent) {
            return;
          }

          resultSent = true;
          window.removeEventListener("message", receiveMessage, false);
          opener.postMessage(result, origin);
          status.textContent = "認証結果を送信しました。元の管理画面タブに戻ってください。";
          closeButton.hidden = false;
          closeButton.addEventListener("click", () => window.close(), { once: true });
          window.setTimeout(() => window.close(), 600);
        };

        const receiveMessage = (event) => {
          if (
            event.source !== opener
            || event.origin !== origin
            || event.data !== handshake
          ) {
            return;
          }

          sendResult();
        };

        window.addEventListener("message", receiveMessage, false);
        opener.postMessage(handshake, origin);
        window.setTimeout(sendResult, 400);
      })();
    </script>
  </body>
</html>
HTML;

    exit;
}

if (realpath($_SERVER['SCRIPT_FILENAME'] ?? '') === __FILE__) {
    wavbits_decap_fail(404, 'ページが見つかりません。');
}
