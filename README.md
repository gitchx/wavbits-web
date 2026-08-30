# wavbits.com

> Production: https://wavbits.com<br>
> Hosting: ConoHa VPS / Apache<br>
> Framework: Astro / Tailwind CSS<br>
> CMS: Decap CMS / GitHub OAuth<br>
> Status: Active<br>
> Registry: https://github.com/gitchx/site-registry

wavbitsの音楽、ボーカルミックス、オーディオDSP、ソフトウェア開発活動への入口となる静的サイトです。公開画面の内容は `src/data/home.json` で管理し、Astroが既存デザインのHTMLを生成します。

## Development

Node.js 22.12以上を使用します。GitHub Actionsとローカル開発ではNode.js 24を推奨します。

```bash
npm ci
npm run dev
```

`src/input.css` はTailwind CSS CLIで `public/style.css` へ生成されます。公開用成果物を作る場合は次を実行します。

```bash
npm run build
```

Astroのproduction buildは `dist/` に生成されます。

## Content management

`https://wavbits.com/admin/` のDecap CMSから、次の内容を追加・編集できます。

- ページタイトル、説明、テーマカラー
- サイト名、タグライン、フッター
- Homeのセクション
- 各セクションのリンク、説明、準備中ラベル
- `public/uploads/` に保存するメディア

現行サイトにはMarkdown記事がないため、CMS導入だけを目的とした記事形式への変更は行っていません。既存のHome内容を `src/data/home.json` へ移し、Decap CMSのfile collectionで管理します。セクションと項目はlist fieldなので、新規追加と並べ替えが可能です。

保存すると `gitchx/wavbits-web` の `main` ブランチへ直接コミットされます。対象ファイルへのpushは既存のGitHub Actionsを起動し、production build後に本番VPSへ反映します。

### Local CMS

`public/admin/config.yml` は `local_backend: true` を設定済みです。2つのターミナルで次を実行します。

```bash
npx decap-server
```

```bash
npm run dev
```

`http://localhost:4321/admin/` を開くと、GitHubへコミットせずローカルの `src/data/home.json` を編集できます。保存後は `git diff` と `npm run build` で確認してください。

## GitHub OAuth

認証は、動作確認済みの `portal.wavbits.com` と同じく、同一VPS上のPHPエンドポイントでGitHub OAuth code flow、PKCE、state検証を行います。

`wavbits-web` は公開リポジトリなので、portalの `repo` scopeではなく、必要最小限の `public_repo` scopeを要求します。GitHub client secretはGit、DocumentRoot、HTML、Apache VirtualHostへ保存せず、VPSの `/etc/httpd/wavbits-decap-oauth.ini` に `root:apache`、mode `640` で配置します。

GitHubの **Settings → Developer settings → OAuth Apps** で、このサイト専用のOAuth Appを作成します。

| 項目 | 値 |
| --- | --- |
| Application name | `wavbits.com Decap CMS` |
| Homepage URL | `https://wavbits.com/admin/` |
| Authorization callback URL | `https://wavbits.com/admin/callback.php` |

`Allow wildcard matching` と `Enable Device Flow` は有効にしません。OAuth proxyはrefresh tokenを保持しないため、`Expire user access tokens` も無効にします。

サイトを先にデプロイし、`scripts/configure-wavbits-decap-oauth.sh` をVPSの `/home/vps/` へ転送します。VPSへログインした状態で、credentialをシェル履歴へ残さずmode `600`の一時ファイルへ保存します。

```bash
umask 077
read -rp "GitHub OAuth client ID: " WAVBITS_DECAP_CLIENT_ID
printf '%s\n' "$WAVBITS_DECAP_CLIENT_ID" > /home/vps/wavbits-decap-client-id
unset WAVBITS_DECAP_CLIENT_ID

read -rsp "GitHub OAuth client secret: " WAVBITS_DECAP_CLIENT_SECRET
printf '\n'
printf '%s\n' "$WAVBITS_DECAP_CLIENT_SECRET" > /home/vps/wavbits-decap-client-secret
unset WAVBITS_DECAP_CLIENT_SECRET
```

ユーザー自身のVPSセッションで次を実行します。

```bash
chmod 750 /home/vps/configure-wavbits-decap-oauth.sh
sudo /home/vps/configure-wavbits-decap-oauth.sh \
  --client-id-file /home/vps/wavbits-decap-client-id \
  --client-secret-file /home/vps/wavbits-decap-client-secret
rm /home/vps/wavbits-decap-client-id /home/vps/wavbits-decap-client-secret
```

設定値を表示せず再検査する場合は次を実行します。

```bash
sudo /home/vps/configure-wavbits-decap-oauth.sh --check
```

最後に `/admin/` を開き、GitHubログイン、Homeの読み込み、保存まで確認します。モバイルブラウザではGitHub認証が別タブで開く場合があります。CMSを使い終えたらDecap CMSからログアウトしてください。

## Deployment

`main` の対象ファイルを更新すると、`.github/workflows/deploy.yml` が次を行います。

1. `npm ci` とAstro production build
2. `dist/` の必須ファイル検査とrelease archive作成
3. release SHA-256を付けたVPS stagingへの転送
4. root所有の固定コマンド `/usr/local/sbin/deploy-wavbits` による検査、バックアップ、切り替え

GitHubの `production` Environmentでは、既存の次のSecretsを使用します。

- `VPS_HOST`
- `VPS_USER`
- `VPS_SSH_PRIVATE_KEY`
- `VPS_SSH_KNOWN_HOSTS`

### One-time deployment command update

従来の固定コマンドは `index.html` と `style.css` だけを受け付けます。Decap CMSのadmin filesを含む `dist/` 全体へ対応するため、今回の変更をmainへ反映する前に、ユーザー自身のVPSセッションで固定コマンドを一度更新します。

先にWSLのリポジトリルートから新しい固定コマンドとOAuth設定スクリプトを転送します。

```bash
scp deploy-vps.sh scripts/configure-wavbits-decap-oauth.sh vps@160.251.171.16:/home/vps/
```

その後、ユーザー自身のVPSセッションで次を実行します。

```bash
sudo install -o root -g root -m 0755 /home/vps/deploy-vps.sh /usr/local/sbin/deploy-wavbits
sudo -n /usr/local/sbin/deploy-wavbits --check
```

新しい固定コマンドはrelease archiveのSHA-256、所有者、mode、path、ファイル種別、容量を検査し、symlink、hardlink、path traversal、想定外のPHPを拒否します。OAuth PHP 3ファイルはレビュー済みSHA-256へ固定しています。これらのPHPを将来変更する場合は、Actionsでデプロイする前に、更新した固定コマンドを同じ手順で再インストールする必要があります。

Apache VirtualHost、証明書、DNS、Apache reloadは変更しません。本番配置先はsite-registryどおり `/var/www/wavbits.com`、バックアップ先は `/var/backups/wavbits.com` です。

### Manual deployment

固定コマンド更新後、WSLのリポジトリルートで次を実行できます。

```bash
bash manual-deploy.sh
```
