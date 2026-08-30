#!/usr/bin/env bash
set -Eeuo pipefail

readonly deploy_user="vps"
readonly web_root="/var/www/wavbits.com"
readonly backup_root="/var/backups/wavbits.com"
readonly lock_file="/run/lock/wavbits-deploy.lock"
readonly release_name="wavbits-web-release.tar.gz"
readonly expected_auth_sha="5d323ad9984cadab4e24f6ec78570c07770ced6725ccdf2c3cb5f3f139d05915"
readonly expected_callback_sha="ef1537cb774e450d83b3b6c7106219c725b36f0f9cab87f47a16809b19a84da4"
readonly expected_oauth_sha="81e09b7bf0d5663ef1574cf3d000ce5d5e2ef658797842579c654cbddc59ed54"

die() {
  printf 'deploy-wavbits: %s\n' "$*" >&2
  exit 1
}

[[ "$EUID" -eq 0 ]] || die "must run as root"
[[ -d "$web_root" && ! -L "$web_root" ]] || die "invalid web root: $web_root"

if [[ "${1:-}" == "--check" && "$#" -eq 1 ]]; then
  command -v python3 >/dev/null || die "python3 is required"
  command -v tar >/dev/null || die "tar is required"
  printf 'deploy-wavbits: ready (%s)\n' "$web_root"
  exit 0
fi

[[ "$#" -eq 2 ]] || die "usage: deploy-wavbits COMMIT_SHA RELEASE_SHA256"

readonly commit_sha="$1"
readonly expected_release_sha="$2"

[[ "$commit_sha" =~ ^[0-9a-f]{40}$ ]] || die "invalid commit SHA"
[[ "$expected_release_sha" =~ ^[0-9a-f]{64}$ ]] || die "invalid release SHA-256"

readonly source_dir="/home/$deploy_user/wavbits-web-deploy-$commit_sha"
readonly archive="$source_dir/$release_name"

[[ -d "$source_dir" && ! -L "$source_dir" ]] || die "invalid staging directory"
[[ "$(stat -c '%U:%G:%a' -- "$source_dir")" == "$deploy_user:$deploy_user:700" ]] \
  || die "staging directory must be owned by $deploy_user:$deploy_user with mode 700"
[[ -f "$archive" && ! -L "$archive" ]] || die "invalid release archive"
[[ "$(stat -c '%U:%G' -- "$archive")" == "$deploy_user:$deploy_user" ]] \
  || die "release archive has an unexpected owner"
[[ "$(stat -c '%h' -- "$archive")" == "1" ]] || die "release archive must not be hard-linked"

exec 9>"$lock_file"
flock 9

install -d -o root -g root -m 0700 "$backup_root"
trusted_archive="$(mktemp --tmpdir="$backup_root" .release.XXXXXX)"
install -o root -g root -m 0600 "$archive" "$trusted_archive"
trap 'rm -f -- "$trusted_archive"' EXIT

[[ "$(sha256sum -- "$trusted_archive" | cut -d ' ' -f 1)" == "$expected_release_sha" ]] \
  || die "release archive SHA-256 mismatch"

python3 - "$trusted_archive" <<'PY' || die "release archive validation failed"
import sys
import tarfile
from pathlib import PurePosixPath

archive = sys.argv[1]
required = {
    "index.html",
    "style.css",
    "admin/index.html",
    "admin/config.yml",
    "admin/oauth.php",
    "admin/auth.php",
    "admin/callback.php",
}
allowed_php = {"admin/oauth.php", "admin/auth.php", "admin/callback.php"}
seen = set()
total_size = 0

with tarfile.open(archive, "r:gz") as release:
    members = release.getmembers()
    if not members or len(members) > 10000:
        raise ValueError("unexpected number of archive members")

    for member in members:
        path = PurePosixPath(member.name)
        parts = tuple(part for part in path.parts if part not in ("", "."))

        if path.is_absolute() or ".." in parts:
            raise ValueError(f"unsafe archive path: {member.name}")
        if not parts:
            if member.isdir():
                continue
            raise ValueError("invalid empty archive path")
        if not (member.isfile() or member.isdir()):
            raise ValueError(f"unsupported archive member: {member.name}")

        normalized = "/".join(parts)
        if normalized in seen:
            raise ValueError(f"duplicate archive path: {normalized}")
        seen.add(normalized)

        if member.isfile():
            total_size += member.size
            if member.size > 50 * 1024 * 1024 or total_size > 200 * 1024 * 1024:
                raise ValueError("release archive is too large")
            if normalized.endswith(".php") and normalized not in allowed_php:
                raise ValueError(f"unexpected PHP file: {normalized}")

if not required.issubset(seen):
    raise ValueError(f"missing required files: {sorted(required - seen)}")
PY

staging_dir="$(mktemp -d /var/www/wavbits.com.new.XXXXXX)"
backup_dir="$(mktemp -d --tmpdir="$backup_root" "$(date -u +%Y%m%dT%H%M%SZ)-${commit_sha:0:12}.XXXXXX")"
backup_site="$backup_dir/site"
previous_moved=0
new_activated=0

cleanup() {
  local status="$?"
  trap - EXIT

  if ((status != 0)); then
    printf 'deploy-wavbits: deployment failed; attempting rollback\n' >&2
    if ((new_activated == 1)) && [[ -d "$web_root" && ! -L "$web_root" ]]; then
      mv -- "$web_root" "$backup_dir/failed-site" || true
    fi
    if ((previous_moved == 1)) && [[ -d "$backup_site" && ! -L "$backup_site" ]]; then
      mv -- "$backup_site" "$web_root" || true
    fi
  fi

  if [[ -d "$staging_dir" && ! -L "$staging_dir" ]]; then
    rm -rf -- "$staging_dir"
  fi
  rm -f -- "$trusted_archive"

  exit "$status"
}
trap cleanup EXIT

tar --extract --gzip --file "$trusted_archive" --directory "$staging_dir" \
  --no-same-owner --no-same-permissions

for required_file in \
  index.html \
  style.css \
  admin/index.html \
  admin/config.yml \
  admin/oauth.php \
  admin/auth.php \
  admin/callback.php; do
  [[ -f "$staging_dir/$required_file" && ! -L "$staging_dir/$required_file" ]] \
    || die "missing required deployment file: $required_file"
done

[[ "$(sha256sum -- "$staging_dir/admin/auth.php" | cut -d ' ' -f 1)" == "$expected_auth_sha" ]] \
  || die "admin/auth.php does not match the reviewed deployment command"
[[ "$(sha256sum -- "$staging_dir/admin/callback.php" | cut -d ' ' -f 1)" == "$expected_callback_sha" ]] \
  || die "admin/callback.php does not match the reviewed deployment command"
[[ "$(sha256sum -- "$staging_dir/admin/oauth.php" | cut -d ' ' -f 1)" == "$expected_oauth_sha" ]] \
  || die "admin/oauth.php does not match the reviewed deployment command"

chown -R root:root "$staging_dir"
find "$staging_dir" -type d -exec chmod 0755 {} +
find "$staging_dir" -type f -exec chmod 0644 {} +
restorecon -R "$staging_dir" 2>/dev/null || true

mv -- "$web_root" "$backup_site"
previous_moved=1
mv -- "$staging_dir" "$web_root"
new_activated=1

[[ -s "$web_root/index.html" && -s "$web_root/style.css" ]] \
  || die "deployed site failed required file verification"
[[ "$(sha256sum -- "$web_root/admin/oauth.php" | cut -d ' ' -f 1)" == "$expected_oauth_sha" ]] \
  || die "deployed OAuth endpoint failed SHA-256 verification"

previous_moved=0
new_activated=0
rm -f -- "$trusted_archive"
trap - EXIT
printf 'deploy-wavbits: deployed %s (backup: %s)\n' "$commit_sha" "$backup_dir"
