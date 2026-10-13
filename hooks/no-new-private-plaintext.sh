#!/usr/bin/env bash
# Reject private plaintext that is not already in HEAD.
# Existing tracked lines stay until the user asks to change them.
set -euo pipefail

exclude_file() {
  case "$1" in
    hooks/no-new-private-plaintext.sh | .pre-commit-config.yaml) return 0 ;;
    *.age) return 0 ;;
  esac
  return 1
}

failed=0

flag() {
  printf 'private plaintext must not be published (%s): %s\n' "$2" "$1" >&2
  failed=1
}

check_line() {
  local where="$1"
  local line="$2"
  if printf '%s\n' "$line" | grep -Eq '(^|[^0-9])(10\.[0-9]{1,3}\.[0-9]{1,3}|192\.168\.[0-9]{1,3}|172\.(1[6-9]|2[0-9]|3[01])\.[0-9]{1,3})([^0-9]|$)'; then
    flag "$where" "LAN address"
  fi
}

while IFS=$'\t' read -r file line; do
  [[ -n "$file" ]] || continue
  exclude_file "$file" && continue
  check_line "$file" "$line"
done < <(git diff HEAD --unified=0 -- . ':(exclude)*.age' | awk '
  /^\+\+\+ b\// { file = substr($0, 7); next }
  /^\+/ && !/^\+\+\+/ { print file "\t" substr($0, 2) }
')

while IFS= read -r file; do
  [[ -n "$file" ]] || continue
  exclude_file "$file" && continue
  [[ -f "$file" ]] || continue
  n=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    n=$((n + 1))
    check_line "$file:$n" "$line"
  done <"$file"
done < <(git ls-files --others --exclude-standard)

exit "$failed"
