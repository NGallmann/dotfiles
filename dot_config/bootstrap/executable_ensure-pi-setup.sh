#!/usr/bin/env bash
# Clone the pi-setup repo named by the encrypted URL file and link its wrapper
# in front of the managed Pi launcher. Do not pull; `pi` fast-forwards on start.
set -euo pipefail

url_file="$HOME/.config/bootstrap/pi-setup.url"
link="$HOME/.local/bin/pi"

command -v git >/dev/null 2>&1 || {
  echo "git is required to bootstrap pi-setup" >&2
  exit 1
}

if [[ ! -f "$url_file" ]]; then
  echo "pi-setup URL file is missing: $url_file" >&2
  exit 1
fi

url=$(tr -d '[:space:]' <"$url_file")
case "$url" in
  https://*) ;;
  *)
    echo "pi-setup URL must be an https URL" >&2
    exit 1
    ;;
esac

authority=${url#https://}
authority=${authority%%/*}
case "$authority" in
  "" | *@* | *:*)
    echo "pi-setup URL must be https://host/group/repo with no credentials" >&2
    exit 1
    ;;
esac

repo_path=${url#https://*/}
repo_path=${repo_path%.git}
repo_path=${repo_path%/}
case "$repo_path" in
  "" | /* | *..* | *//* | */ | */*/*/*)
    echo "pi-setup URL path must be group/repo or group/subgroup/repo" >&2
    exit 1
    ;;
  */*) ;;
  *)
    echo "pi-setup URL path must be group/repo or group/subgroup/repo" >&2
    exit 1
    ;;
esac

# This checkout is the private profile repo, so it lives under ~/git/private.
dest="$HOME/git/private/$authority/$repo_path"
normalize() {
  local value="$1"
  value=${value%.git}
  value=${value%/}
  printf '%s' "$value"
}

if [[ -d "$dest/.git" ]]; then
  origin=$(git -C "$dest" remote get-url origin)
  if [[ "$(normalize "$origin")" != "$(normalize "$url")" ]]; then
    echo "pi-setup checkout at $dest has a different origin; leaving it untouched" >&2
    exit 1
  fi
elif [[ -e "$dest" ]]; then
  echo "pi-setup path exists and is not a git checkout: $dest" >&2
  exit 1
else
  mkdir -p "${dest%/*}"
  GIT_TERMINAL_PROMPT=0 git clone -- "$url" "$dest"
  echo "cloned pi-setup to $dest"
fi

wrapper="$dest/scripts/pi"
if [[ ! -x "$wrapper" ]]; then
  echo "pi-setup wrapper is missing: $wrapper" >&2
  exit 1
fi

mkdir -p "${link%/*}"
if [[ -L "$link" ]]; then
  if [[ "$(readlink "$link")" != "$wrapper" ]]; then
    echo "refusing to replace $link -> $(readlink "$link")" >&2
    exit 1
  fi
elif [[ -e "$link" ]]; then
  echo "refusing to replace existing $link" >&2
  exit 1
else
  ln -s "$wrapper" "$link"
  echo "linked $link"
fi
