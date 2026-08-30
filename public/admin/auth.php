<?php

declare(strict_types=1);

require_once __DIR__ . '/oauth.php';

wavbits_decap_no_store_headers();
wavbits_decap_require_get();

$provider = wavbits_decap_query_string('provider');
$siteId = wavbits_decap_query_string('site_id');
$scope = wavbits_decap_query_string('scope') ?? 'public_repo';

if ($provider !== 'github' || $siteId !== 'wavbits.com' || $scope !== 'public_repo') {
    wavbits_decap_fail(400, 'OAuthリクエストが正しくありません。');
}

try {
    $config = wavbits_decap_load_config();
    wavbits_decap_start_session();
    session_regenerate_id(true);

    $state = bin2hex(random_bytes(32));
    $codeVerifier = rtrim(strtr(base64_encode(random_bytes(64)), '+/', '-_'), '=');
    $codeChallenge = rtrim(
        strtr(base64_encode(hash('sha256', $codeVerifier, true)), '+/', '-_'),
        '=',
    );
    $_SESSION['decap_oauth_state'] = $state;
    $_SESSION['decap_oauth_code_verifier'] = $codeVerifier;
    $_SESSION['decap_oauth_expires_at'] = time() + 600;
    session_write_close();
} catch (Throwable) {
    wavbits_decap_fail(503, 'Decap CMSのOAuth設定を確認してください。');
}

$query = http_build_query(
    [
        'client_id' => $config['client_id'],
        'redirect_uri' => WAVBITS_DECAP_CALLBACK_URL,
        'scope' => 'public_repo',
        'state' => $state,
        'code_challenge' => $codeChallenge,
        'code_challenge_method' => 'S256',
        'allow_signup' => 'false',
    ],
    '',
    '&',
    PHP_QUERY_RFC3986,
);

header('Location: https://github.com/login/oauth/authorize?' . $query, true, 302);
exit;
