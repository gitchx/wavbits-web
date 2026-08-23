# wavbits.com

> Production: https://wavbits.com  
> Hosting: VPS / Apache (provider要確認)  
> Framework: HTML / Tailwind CSS<br>
> Status: Active  
> Registry: https://github.com/gitchx/site-registry

wavbitsの音楽、ボーカルミックス、オーディオDSP、ソフトウェア開発活動への入口となる静的サイトです。

## Development

Node.js 20 以上を使用します。

```bash
npm ci
npm run dev
```

`src/input.css` を編集すると、配信用の `style.css` が自動生成されます。本番用 CSS を一度だけ生成する場合は `npm run build` を実行します。

## Deployment

`main` にサイト、Tailwind CSS、ビルド設定、デプロイスクリプト、またはデプロイワークフローの変更を push すると、GitHub Actions が CSS をビルドして本番 VPS へ自動デプロイします。手動実行も可能です。

GitHub の `production` Environment に次の Secrets を設定してください。

- `VPS_HOST`: VPS のホスト名
- `VPS_USER`: SSH 接続ユーザー（`deploy-vps.sh` をパスワードなしで `sudo` 実行できること）
- `VPS_SSH_PRIVATE_KEY`: SSH 秘密鍵
- `VPS_SSH_KNOWN_HOSTS`: VPS の検証済み known_hosts エントリ

### Manual deployment

GitHub Actions の設定完了前に手動で反映する場合は、リポジトリのルートで次を実行します。途中でVPSのsudoパスワード入力を求められます。

```bash
bash manual-deploy.sh
```
