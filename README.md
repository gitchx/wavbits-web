# wavbits.com

> Production: https://wavbits.com  
> Hosting: ConoHa VPS / Apache<br>
> Framework: HTML / Tailwind CSS<br>
> Status: Active  
> Registry: https://github.com/gitchx/site-registry

wavbitsの音楽、ボーカルミックス、オーディオDSP、ソフトウェア開発活動への入口となる静的サイトです。

## Development

Node.js 20 以上を使用します。GitHub Actions とローカル開発では Node.js 24 を推奨します。

```bash
npm ci
npm run dev
```

`src/input.css` を編集すると、配信用の `style.css` が自動生成されます。本番用 CSS を一度だけ生成する場合は `npm run build` を実行します。

## Deployment

`main` にサイト、Tailwind CSS、ビルド設定、デプロイスクリプト、またはデプロイワークフローの変更を push すると、GitHub Actions が CSS をビルドして本番 VPS へ自動デプロイします。手動実行も可能です。

GitHub の `production` Environment に次の Environment Secrets を設定してください。値をリポジトリ、Issue、Actions のログへ貼り付けないでください。

- `VPS_HOST`: `160.251.171.16`
- `VPS_USER`: `vps`
- `VPS_SSH_PRIVATE_KEY`: `vps` のデプロイ専用 SSH 秘密鍵
- `VPS_SSH_KNOWN_HOSTS`: `160.251.171.16` の検証済み known_hosts エントリ

`VPS_SSH_KNOWN_HOSTS` は `ssh-keyscan` の結果を無条件で信用せず、ConoHa のコンソールまたは既に信頼済みの接続で `/etc/ssh/ssh_host_*_key.pub` のフィンガープリントと一致することを確認してから登録します。

### One-time server setup

Actions はユーザーがアップロードしたシェルスクリプトを root で実行しません。リポジトリの `deploy-vps.sh` を、最初の一度だけ固定された root 所有コマンドとしてインストールします。

```bash
scp deploy-vps.sh deploy-vps.sudoers vps@160.251.171.16:/home/vps/
ssh -t vps@160.251.171.16
sudo install -o root -g root -m 0755 /home/vps/deploy-vps.sh /usr/local/sbin/deploy-wavbits
sudo visudo -cf /home/vps/deploy-vps.sudoers
sudo install -o root -g root -m 0440 /home/vps/deploy-vps.sudoers /etc/sudoers.d/wavbits-deploy
sudo visudo -cf /etc/sudoers.d/wavbits-deploy
sudo -n /usr/local/sbin/deploy-wavbits --check
rm -f /home/vps/deploy-vps.sh /home/vps/deploy-vps.sudoers
exit
```

固定コマンドは、`/home/vps/wavbits-web-deploy-<commit SHA>` の `index.html` と `style.css` だけを受け付けます。両ファイルの SHA-256 と所有者を検証し、`/var/backups/wavbits.com` へバックアップしてから `/var/www/wavbits.com` へ配置します。Apache vhost、証明書、DNS、Apache reload には触れません。

### Manual deployment

固定デプロイコマンドの設定後に手動で反映する場合は、WSL のリポジトリルートで次を実行します。

```bash
bash manual-deploy.sh
```
