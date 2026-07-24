#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

ENV_EXAMPLES=(
  ".env.example"
  "services/media-arr/.env.example"
  "services/omniroute/config/omniroute.env.example"
)

PLACEHOLDER_RE='replace-with|<[^>]+>|your_|_token>|_key>|_password>|temporary-key|example|changeme|REDACTED'
SECRET_NAME_RE='(TOKEN|SECRET|PASSWORD|KEY|AUTH|CREDENTIAL)'

fail=0
warn=0

info() { printf '[INFO] %s\n' "$*"; }
ok() { printf '[ OK ] %s\n' "$*"; }
warn_msg() { printf '[WARN] %s\n' "$*"; warn=$((warn + 1)); }
fail_msg() { printf '[FAIL] %s\n' "$*"; fail=$((fail + 1)); }

check_example_file() {
  local file="$1"
  local path="$ROOT_DIR/$file"

  if [ ! -f "$path" ]; then
    fail_msg "missing $file"
    return
  fi

  ok "found $file"

  # Secret-like variables in committed examples should look like placeholders,
  # not real values. This is a heuristic, not a replacement for review.
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%%#*}"
    [ -z "${line//[[:space:]]/}" ] && continue
    [[ "$line" != *=* ]] && continue

    local name="${line%%=*}"
    local value="${line#*=}"
    name="${name//[[:space:]]/}"
    value="${value#\"}"
    value="${value%\"}"
    value="${value#\'}"
    value="${value%\'}"

    if [[ "$name" =~ $SECRET_NAME_RE ]]; then
      if [ -z "$value" ]; then
        ok "$file:$name is blank placeholder"
      elif [[ "$value" =~ $PLACEHOLDER_RE ]]; then
        ok "$file:$name uses placeholder"
      else
        fail_msg "$file:$name has a non-placeholder-looking value"
      fi
    fi
  done < "$path"
}

check_env_from_example() {
  local example="$1"
  local actual="${2:-${example%.example}}"
  local example_path="$ROOT_DIR/$example"
  local actual_path="$ROOT_DIR/$actual"

  [ -f "$example_path" ] || return

  if [ ! -f "$actual_path" ]; then
    warn_msg "$actual does not exist yet; copy from $example during restore"
    return
  fi

  local missing=0
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%%#*}"
    [ -z "${line//[[:space:]]/}" ] && continue
    [[ "$line" != *=* ]] && continue
    local key="${line%%=*}"
    key="${key//[[:space:]]/}"
    if ! grep -Eq "^[[:space:]]*${key}=" "$actual_path"; then
      fail_msg "$actual missing key from $example: $key"
      missing=$((missing + 1))
    fi
  done < "$example_path"

  if [ "$missing" -eq 0 ]; then
    ok "$actual contains all keys from $example"
  fi
}

info "checking committed env examples"
for file in "${ENV_EXAMPLES[@]}"; do
  check_example_file "$file"
done

printf '\n'
info "checking local env files when present"
check_env_from_example "services/media-arr/.env.example" "services/media-arr/.env"
check_env_from_example "services/omniroute/config/omniroute.env.example" "services/omniroute/config/omniroute.env"

printf '\nSummary: FAIL=%s WARN=%s\n' "$fail" "$warn"

if [ "$fail" -ne 0 ]; then
  exit 1
fi
