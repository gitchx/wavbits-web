<?php

declare(strict_types=1);

require_once __DIR__ . '/oauth.php';

wavbits_decap_no_store_headers();
wavbits_decap_require_get();

$state = wavbits_decap_query_string('state');
$code = wavbits_decap_query_string('code');
$githubError = wavbits_decap_query_string('error');

try {
    wavbits_decap_start_session();
    $expectedState = $_SESSION['decap_oauth_state'] ?? null;
    $codeVerifier = $_SESSION['decap_oauth_code_verifier'] ?? null;
    $expiresAt = $_SESSION['decap_oauth_expires_at'] ?? null;
    unset(
        $_SESSION['decap_oauth_state'],
        $_SESSION['decap_oauth_code_verifier'],
        $_SESSION['decap_oauth_expires_at'],
    );
    session_write_close();
} catch (Throwable) {
    wavbits_decap_render_callback('error', ['message' => 'OAuthセッションを確認できません。']);
}

if (
    !is_string($expectedState)
    || !is_int($expiresAt)
    || $expiresAt < time()
    || !is_string($codeVerifier)
    || preg_match('/\A[A-Za-z0-9._~-]{43,128}\z/', $codeVerifier) !== 1
    || !is_string($state)
    || preg_match('/\A[a-f0-9]{64}\z/', $state) !== 1
    || !hash_equals($expectedState, $state)
) {
    wavbits_decap_render_callback('error', ['message' => 'OAuthリクエストの有効期限が切れたか、stateが一致しません。']);
}

if ($githubError !== null) {
    wavbits_decap_render_callback('error', ['message' => 'GitHub認証がキャンセルされました。']);
}

if (
    !is_string($code)
    || $code === ''
    || strlen($code) > 512
    || preg_match('/[\r\n]/', $code) === 1
) {
    wavbits_decap_render_callback('error', ['message' => 'GitHubから認証コードを受け取れませんでした。']);
}

try {
    $config = wavbits_decap_load_config();
} catch (Throwable) {
    wavbits_decap_render_callback('error', ['message' => 'Decap CMSのOAuth設定を確認してください。']);
}

if (!extension_loaded('curl')) {
    wavbits_decap_render_callback('error', ['message' => 'VPSでPHP cURL拡張を利用できません。']);
}

$curl = curl_init('https://github.com/login/oauth/access_token');

if ($curl === false) {
    wavbits_decap_render_callback('error', ['message' => 'GitHubへの接続を開始できません。']);
}

curl_setopt_array($curl, [
    CURLOPT_POST => true,
    CURLOPT_POSTFIELDS => http_build_query(
        [
            'client_id' => $config['client_id'],
            'client_secret' => $config['client_secret'],
            'code' => $code,
            'code_verifier' => $codeVerifier,
            'redirect_uri' => WAVBITS_DECAP_CALLBACK_URL,
        ],
        '',
        '&',
        PHP_QUERY_RFC3986,
    ),
    CURLOPT_HTTPHEADER => [
        'Accept: application/json',
        'Content-Type: application/x-www-form-urlencoded',
        'User-Agent: wavbits.com Decap CMS OAuth',
    ],
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_CONNECTTIMEOUT => 5,
    CURLOPT_TIMEOUT => 15,
    CURLOPT_FOLLOWLOCATION => false,
    CURLOPT_PROTOCOLS => CURLPROTO_HTTPS,
    CURLOPT_REDIR_PROTOCOLS => CURLPROTO_HTTPS,
]);

$response = curl_exec($curl);
$responseStatus = curl_getinfo($curl, CURLINFO_RESPONSE_CODE);
$requestFailed = $response === false || curl_errno($curl) !== 0;
curl_close($curl);
unset($config);

if ($requestFailed || $responseStatus !== 200 || !is_string($response)) {
    wavbits_decap_render_callback('error', ['message' => 'GitHubとのトークン交換に失敗しました。']);
}

try {
    $tokenResponse = json_decode($response, true, 16, JSON_THROW_ON_ERROR);
} catch (JsonException) {
    wavbits_decap_render_callback('error', ['message' => 'GitHubから不正な応答を受け取りました。']);
}

$accessToken = is_array($tokenResponse) ? ($tokenResponse['access_token'] ?? null) : null;

if (
    !is_string($accessToken)
    || $accessToken === ''
    || strlen($accessToken) > 512
    || preg_match('/[\r\n]/', $accessToken) === 1
) {
    wavbits_decap_render_callback('error', ['message' => 'GitHubアクセストークンを取得できませんでした。']);
}

wavbits_decap_render_callback('success', ['token' => $accessToken]);
