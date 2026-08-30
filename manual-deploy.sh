#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
deploy_host="${WAVBITS_DEPLOY_HOST:-vps@160.251.171.16}"
commit_sha="$(git -C "$project_dir" rev-parse --verify HEAD)"
remote_dir="/home/vps/wavbits-web-deploy-$commit_sha"
release_archive="$project_dir/wavbits-web-release.tar.gz"

npm --prefix "$project_dir" ci
npm --prefix "$project_dir" run build

tar -C "$project_dir/dist" -czf "$release_archive" .
release_sha="$(sha256sum "$release_archive" | cut -d ' ' -f 1)"

cleanup() {
  rm -f -- "$release_archive"
  ssh -o BatchMode=yes "$deploy_host" \
    "rm -f '$remote_dir/wavbits-web-release.tar.gz'; rmdir '$remote_dir' 2>/dev/null || true" \
    || true
}
trap cleanup EXIT

ssh -o BatchMode=yes "$deploy_host" "install -d -m 700 '$remote_dir'"
scp "$release_archive" "$deploy_host:$remote_dir/"
ssh -t "$deploy_host" \
  "chmod 600 '$remote_dir/wavbits-web-release.tar.gz' && sudo /usr/local/sbin/deploy-wavbits '$commit_sha' '$release_sha'"

printf 'Deployment completed: https://wavbits.com\n'
