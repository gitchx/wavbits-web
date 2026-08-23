#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
deploy_host="${WAVBITS_DEPLOY_HOST:-vps@vps.wavbits.com}"
commit_sha="$(git -C "$project_dir" rev-parse --verify HEAD)"
remote_dir="/home/vps/wavbits-web-deploy-${commit_sha:0:12}"

npm --prefix "$project_dir" ci
npm --prefix "$project_dir" run build

ssh -o BatchMode=yes "$deploy_host" "install -d -m 700 '$remote_dir'"
scp \
  "$project_dir/index.html" \
  "$project_dir/style.css" \
  "$project_dir/deploy-vps.sh" \
  "$deploy_host:$remote_dir/"

# -t allocates a terminal so sudo can securely prompt the operator for a password.
ssh -t "$deploy_host" "sudo bash '$remote_dir/deploy-vps.sh'"
ssh -o BatchMode=yes "$deploy_host" "rm -rf '$remote_dir'"

printf 'Deployment completed: https://wavbits.com\n'
