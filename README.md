# wavbits.com

> Production: https://wavbits.com  
> Hosting: VPS / Apache (provider要確認)  
> Framework: HTML / CSS  
> Status: Active  
> Registry: https://github.com/gitchx/site-registry

wavbitsの音楽、ボーカルミックス、オーディオDSP、ソフトウェア開発活動への入口となる静的サイトです。

## Deployment

`main` に `index.html`、`style.css`、`deploy-vps.sh`、またはデプロイワークフローの変更を push すると、GitHub Actions が本番 VPS へ自動デプロイします。手動実行も可能です。

GitHub の `production` Environment に次の Secrets を設定してください。

- `VPS_HOST`: VPS のホスト名
- `VPS_USER`: SSH 接続ユーザー（`deploy-vps.sh` をパスワードなしで `sudo` 実行できること）
- `VPS_SSH_PRIVATE_KEY`: SSH 秘密鍵
- `VPS_SSH_KNOWN_HOSTS`: VPS の検証済み known_hosts エントリ
