#!/usr/bin/env bash
set -Eeuo pipefail

readonly deploy_user="vps"
readonly web_root="/var/www/wavbits.com"
readonly backup_root="/var/backups/wavbits.com"
readonly lock_file="/run/lock/wavbits-deploy.lock"

die() {
  printf 'deploy-wavbits: %s\n' "$*" >&2
  exit 1
}

[[ "$EUID" -eq 0 ]] || die "must run as root"
[[ -d "$web_root" && ! -L "$web_root" ]] || die "invalid web root: $web_root"

if [[ "${1:-}" == "--check" && "$#" -eq 1 ]]; then
  printf 'deploy-wavbits: ready (%s)\n' "$web_root"
  exit 0
fi

[[ "$#" -eq 3 ]] || die "usage: deploy-wavbits COMMIT_SHA INDEX_SHA256 CSS_SHA256"

readonly commit_sha="$1"
readonly expected_index_sha="$2"
readonly expected_css_sha="$3"

[[ "$commit_sha" =~ ^[0-9a-f]{40}$ ]] || die "invalid commit SHA"
[[ "$expected_index_sha" =~ ^[0-9a-f]{64}$ ]] || die "invalid index.html SHA-256"
[[ "$expected_css_sha" =~ ^[0-9a-f]{64}$ ]] || die "invalid style.css SHA-256"

readonly source_dir="/home/$deploy_user/wavbits-web-deploy-$commit_sha"
[[ -d "$source_dir" && ! -L "$source_dir" ]] || die "invalid staging directory"
[[ "$(stat -c '%U:%G:%a' -- "$source_dir")" == "$deploy_user:$deploy_user:700" ]] \
  || die "staging directory must be owned by $deploy_user:$deploy_user with mode 700"

validate_source_file() {
  local path="$1"
  local expected_sha="$2"

  [[ -f "$path" && ! -L "$path" ]] || die "invalid staging file: $path"
  [[ "$(stat -c '%U:%G' -- "$path")" == "$deploy_user:$deploy_user" ]] \
    || die "staging file has an unexpected owner: $path"
  [[ "$(stat -c '%h' -- "$path")" == "1" ]] || die "staging file must not be hard-linked: $path"
  [[ "$(sha256sum -- "$path" | cut -d ' ' -f 1)" == "$expected_sha" ]] \
    || die "SHA-256 mismatch: $path"
}

validate_source_file "$source_dir/index.html" "$expected_index_sha"
validate_source_file "$source_dir/style.css" "$expected_css_sha"

exec 9>"$lock_file"
flock 9

install -d -o root -g root -m 0700 "$backup_root"

index_tmp="$(mktemp --tmpdir="$web_root" .index.html.deploy.XXXXXX)"
css_tmp="$(mktemp --tmpdir="$web_root" .style.css.deploy.XXXXXX)"
backup_dir=""
rollback_ready=0

cleanup() {
  local status="$?"
  trap - EXIT

  if (( status != 0 && rollback_ready == 1 )); then
    printf 'deploy-wavbits: deployment failed; restoring backup\n' >&2
    install -o root -g root -m 0644 "$backup_dir/index.html" "$web_root/index.html" || true
    install -o root -g root -m 0644 "$backup_dir/style.css" "$web_root/style.css" || true
  fi

  rm -f -- "$index_tmp" "$css_tmp"
  exit "$status"
}
trap cleanup EXIT

install -o root -g root -m 0644 "$source_dir/index.html" "$index_tmp"
install -o root -g root -m 0644 "$source_dir/style.css" "$css_tmp"

[[ "$(sha256sum -- "$index_tmp" | cut -d ' ' -f 1)" == "$expected_index_sha" ]] \
  || die "copied index.html failed SHA-256 verification"
[[ "$(sha256sum -- "$css_tmp" | cut -d ' ' -f 1)" == "$expected_css_sha" ]] \
  || die "copied style.css failed SHA-256 verification"

[[ -f "$web_root/index.html" && ! -L "$web_root/index.html" ]] \
  || die "current index.html is missing or unsafe"
[[ -f "$web_root/style.css" && ! -L "$web_root/style.css" ]] \
  || die "current style.css is missing or unsafe"

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
backup_dir="$(mktemp -d --tmpdir="$backup_root" "$timestamp-${commit_sha:0:12}.XXXXXX")"
install -o root -g root -m 0644 "$web_root/index.html" "$backup_dir/index.html"
install -o root -g root -m 0644 "$web_root/style.css" "$backup_dir/style.css"
rollback_ready=1

mv -f -- "$index_tmp" "$web_root/index.html"
mv -f -- "$css_tmp" "$web_root/style.css"

[[ "$(sha256sum -- "$web_root/index.html" | cut -d ' ' -f 1)" == "$expected_index_sha" ]] \
  || die "deployed index.html failed SHA-256 verification"
[[ "$(sha256sum -- "$web_root/style.css" | cut -d ' ' -f 1)" == "$expected_css_sha" ]] \
  || die "deployed style.css failed SHA-256 verification"

rollback_ready=0
printf 'deploy-wavbits: deployed %s (backup: %s)\n' "$commit_sha" "$backup_dir"

