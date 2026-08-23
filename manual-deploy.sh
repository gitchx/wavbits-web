#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
deploy_host="${WAVBITS_DEPLOY_HOST:-vps@160.251.171.16}"
commit_sha="$(git -C "$project_dir" rev-parse --verify HEAD)"
remote_dir="/home/vps/wavbits-web-deploy-$commit_sha"

npm --prefix "$project_dir" ci
npm --prefix "$project_dir" run build

index_sha="$(sha256sum "$project_dir/index.html" | cut -d ' ' -f 1)"
css_sha="$(sha256sum "$project_dir/style.css" | cut -d ' ' -f 1)"

cleanup_remote() {
  ssh -o BatchMode=yes "$deploy_host" \
    "rm -f '$remote_dir/index.html' '$remote_dir/style.css'; rmdir '$remote_dir' 2>/dev/null || true" \
    || true
}
trap cleanup_remote EXIT

ssh -o BatchMode=yes "$deploy_host" "install -d -m 700 '$remote_dir'"
scp "$project_dir/index.html" "$project_dir/style.css" "$deploy_host:$remote_dir/"
ssh -t "$deploy_host" \
  "chmod 600 '$remote_dir/index.html' '$remote_dir/style.css' && sudo /usr/local/sbin/deploy-wavbits '$commit_sha' '$index_sha' '$css_sha'"

printf 'Deployment completed: https://wavbits.com\n'
