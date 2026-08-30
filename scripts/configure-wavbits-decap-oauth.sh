#!/usr/bin/env bash
set -euo pipefail

document_root="/var/www/wavbits.com"
oauth_config_file="/etc/httpd/wavbits-decap-oauth.ini"
client_id_file="${WAVBITS_DECAP_CLIENT_ID_FILE:-}"
client_secret_file="${WAVBITS_DECAP_CLIENT_SECRET_FILE:-}"
check_only=false

usage() {
  cat <<'EOF'
Usage:
  sudo ./scripts/configure-wavbits-decap-oauth.sh \
    --client-id-file /path/to/github-client-id \
    --client-secret-file /path/to/github-client-secret
  sudo ./scripts/configure-wavbits-decap-oauth.sh --check

Each credential file must contain exactly one line, must be a regular file
(not a symlink), and must not be readable or writable by group/other users.
EOF
}

while (($#)); do
  case "$1" in
    --client-id-file)
      [[ $# -ge 2 ]] || {
        echo "--client-id-file requires a path." >&2
        exit 2
      }
      client_id_file="$2"
      shift 2
      ;;
    --client-secret-file)
      [[ $# -ge 2 ]] || {
        echo "--client-secret-file requires a path." >&2
        exit 2
      }
      client_secret_file="$2"
      shift 2
      ;;
    --check)
      check_only=true
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ $EUID -ne 0 ]]; then
  echo "Run this script with sudo." >&2
  exit 1
fi

check_php_runtime() {
  command -v php >/dev/null
  php -r 'exit(extension_loaded("curl") && extension_loaded("session") ? 0 : 1);' || {
    echo "PHP cURL and session extensions are required." >&2
    return 1
  }
}

check_installation() {
  local failed=0
  local config_mode
  local config_owner

  for path in \
    "$document_root/admin/index.html" \
    "$document_root/admin/config.yml" \
    "$document_root/admin/oauth.php" \
    "$document_root/admin/auth.php" \
    "$document_root/admin/callback.php" \
    "$oauth_config_file"; do
    if [[ ! -f "$path" || -L "$path" ]]; then
      echo "Missing required regular file: $path" >&2
      failed=1
    fi
  done

  if [[ -f "$oauth_config_file" ]]; then
    config_mode="$(stat -c '%a' -- "$oauth_config_file")"
    config_owner="$(stat -c '%U:%G' -- "$oauth_config_file")"

    if [[ "$config_mode" != "640" || "$config_owner" != "root:apache" ]]; then
      echo "Unexpected OAuth config ownership or mode: $config_owner $config_mode" >&2
      failed=1
    fi

    if ! php -r '
      $config = parse_ini_file($argv[1], false, INI_SCANNER_RAW);
      $valid = is_array($config)
        && isset($config["client_id"], $config["client_secret"])
        && is_string($config["client_id"])
        && is_string($config["client_secret"])
        && preg_match("/\\A[A-Za-z0-9]{16,128}\\z/", $config["client_id"]) === 1
        && preg_match("/\\A[A-Za-z0-9]{32,128}\\z/", $config["client_secret"]) === 1;
      exit($valid ? 0 : 1);
    ' "$oauth_config_file"; then
      echo "OAuth config has an invalid format." >&2
      failed=1
    fi
  fi

  if ! check_php_runtime; then
    failed=1
  fi

  for php_file in oauth.php auth.php callback.php; do
    if [[ -f "$document_root/admin/$php_file" ]] \
      && ! php -l "$document_root/admin/$php_file" >/dev/null; then
      failed=1
    fi
  done

  ((failed == 0)) || return 1
  echo "Decap CMS OAuth configuration is ready."
}

if [[ $check_only == true ]]; then
  check_installation
  exit
fi

if [[ -z "$client_id_file" || -z "$client_secret_file" ]]; then
  echo "Provide both --client-id-file and --client-secret-file." >&2
  exit 1
fi

for credential_file in "$client_id_file" "$client_secret_file"; do
  if [[ ! -f "$credential_file" || -L "$credential_file" ]]; then
    echo "Credential file must be a regular file and not a symbolic link: $credential_file" >&2
    exit 1
  fi

  credential_mode="$(stat -c '%a' -- "$credential_file")"
  if ((8#$credential_mode & 077)); then
    echo "Credential file permissions are too broad ($credential_mode); use chmod 600." >&2
    exit 1
  fi
done

mapfile -t client_id_lines <"$client_id_file"
mapfile -t client_secret_lines <"$client_secret_file"

if ((${#client_id_lines[@]} != 1 || ${#client_secret_lines[@]} != 1)); then
  echo "Each credential file must contain exactly one line." >&2
  unset client_id_lines client_secret_lines
  exit 1
fi

client_id="${client_id_lines[0]}"
client_secret="${client_secret_lines[0]}"

if [[ ! "$client_id" =~ ^[A-Za-z0-9]{16,128}$ ]]; then
  echo "The GitHub OAuth client ID has an invalid format." >&2
  unset client_id client_secret client_id_lines client_secret_lines
  exit 1
fi

if [[ ! "$client_secret" =~ ^[A-Za-z0-9]{32,128}$ ]]; then
  echo "The GitHub OAuth client secret has an invalid format." >&2
  unset client_id client_secret client_id_lines client_secret_lines
  exit 1
fi

check_php_runtime
test -d "$document_root/admin" || {
  echo "Deploy the site with the Decap CMS files before configuring OAuth." >&2
  exit 1
}

staging_config="$(mktemp /etc/httpd/wavbits-decap-oauth.ini.new.XXXXXX)"
cleanup() {
  rm -f -- "$staging_config"
}
trap cleanup EXIT

printf 'client_id=%s\nclient_secret=%s\n' "$client_id" "$client_secret" >"$staging_config"
unset client_id client_secret client_id_lines client_secret_lines

install -m 640 -o root -g apache "$staging_config" "$oauth_config_file"
restorecon "$oauth_config_file" 2>/dev/null || true

check_installation
echo "GitHub OAuth enabled: https://wavbits.com/admin/"
