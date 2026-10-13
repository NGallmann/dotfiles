#!/usr/bin/env bash
# Install Pi with the official managed installer (npm ci of the published lockfile,
# --ignore-scripts, user-owned ~/.pi/agent). Leave a healthy install alone so
# `pi update` owns upgrades. Do not npm install -g: that install does not pin
# transitive dependencies, and `pi update` then tells you to migrate.
set -euo pipefail

managed_root="$HOME/.pi/agent/install"
launcher="$HOME/.pi/agent/bin/pi"
marker="$managed_root/managed-install.json"
tmp_root=""

cleanup() {
  if [[ -n "$tmp_root" ]]; then
    rm -rf "$tmp_root"
  fi
}
trap cleanup EXIT

command -v curl >/dev/null 2>&1 || {
  echo "curl is required to install Pi" >&2
  exit 1
}
command -v jq >/dev/null 2>&1 || {
  echo "jq is required to install Pi" >&2
  exit 1
}

node_is_new_enough() {
  local bin="$1"
  [[ -x "$bin" ]] || return 1
  "$bin" -e 'const [maj, min, patch] = process.versions.node.split(".").map(Number); process.exit(maj > 22 || (maj === 22 && (min > 19 || (min === 19 && patch >= 0))) ? 0 : 1)'
}

managed_pi_ready() {
  local kind schema layout
  [[ -f "$marker" && -x "$launcher" ]] || return 1
  kind=$(jq -r '.kind // empty' "$marker") || return 1
  schema=$(jq -r '.schemaVersion // empty' "$marker") || return 1
  layout=$(jq -r '.layout // empty' "$marker") || return 1
  [[ "$kind" == "pi-managed-install" && "$schema" == "1" && "$layout" == "releases-v1" ]] || return 1
  "$launcher" --version >/dev/null
}

# pi.dev/install.sh installs this Node build, but only after a terminal prompt.
# Bootstrap has no terminal, so do the same download here when Node is too old.
install_standalone_node() {
  local base_dir platform arch dist_base sums_dir node_file node_dir
  case "$(uname -s)" in
    Darwin) platform=darwin ;;
    Linux) platform=linux ;;
    *)
      echo "unsupported operating system for the Pi Node install: $(uname -s)" >&2
      exit 1
      ;;
  esac
  case "$(uname -m)" in
    x86_64 | amd64) arch=x64 ;;
    arm64 | aarch64) arch=arm64 ;;
    *)
      echo "unsupported CPU for the Pi Node install: $(uname -m)" >&2
      exit 1
      ;;
  esac
  if [[ "$platform" == linux ]] && ! command -v xz >/dev/null 2>&1; then
    echo "xz is required to extract Node.js. Install xz-utils and run this again." >&2
    exit 1
  fi
  if ! command -v sha256sum >/dev/null 2>&1 && ! command -v shasum >/dev/null 2>&1; then
    echo "sha256sum or shasum is required to verify the Node.js download" >&2
    exit 1
  fi

  base_dir="${XDG_DATA_HOME:-$HOME/.local/share}/pi-node"
  dist_base="https://nodejs.org/dist/latest-v22.x"
  sums_dir="$tmp_root/node"
  mkdir -p "$sums_dir" "$base_dir"
  curl -fsSL "$dist_base/SHASUMS256.txt" -o "$sums_dir/SHASUMS256.txt"
  node_file=$(awk -v suffix="-$platform-$arch.tar.xz" '
    index($2, "node-v") == 1 && length($2) >= length(suffix) && substr($2, length($2) - length(suffix) + 1) == suffix { print $2; exit }
  ' "$sums_dir/SHASUMS256.txt")
  if [[ -z "$node_file" ]]; then
    echo "no Node.js binary is available for $platform-$arch" >&2
    exit 1
  fi
  curl -fsSL "$dist_base/$node_file" -o "$sums_dir/$node_file"
  awk -v file="$node_file" '$2 == file { print }' "$sums_dir/SHASUMS256.txt" >"$sums_dir/SHASUMS256.selected"
  if command -v sha256sum >/dev/null 2>&1; then
    (cd "$sums_dir" && sha256sum -c SHASUMS256.selected)
  else
    (cd "$sums_dir" && shasum -a 256 -c SHASUMS256.selected)
  fi
  node_dir="$base_dir/${node_file%.tar.xz}"
  rm -rf "$node_dir"
  tar -xf "$sums_dir/$node_file" -C "$base_dir"
  ln -sfn "$node_dir" "$base_dir/current"
}

ensure_node_on_path() {
  local pi_node="${XDG_DATA_HOME:-$HOME/.local/share}/pi-node/current/bin/node"
  if node_is_new_enough "$pi_node"; then
    PATH="$(dirname "$pi_node"):$PATH"
    return 0
  fi
  if command -v node >/dev/null 2>&1 && node_is_new_enough "$(command -v node)"; then
    return 0
  fi
  tmp_root=$(mktemp -d)
  install_standalone_node
  PATH="${XDG_DATA_HOME:-$HOME/.local/share}/pi-node/current/bin:$PATH"
  node_is_new_enough "$(command -v node)"
}

# The installer refuses to replace a pi that is not its managed launcher.
# Drop those directories so a pi-setup wrapper cannot block a repair.
installer_path() {
  local dir clean=()
  local IFS=:
  local -a dirs
  read -ra dirs <<<"$PATH"
  for dir in "${dirs[@]}"; do
    [[ -n "$dir" ]] || continue
    if [[ -e "$dir/pi" || -L "$dir/pi" ]]; then
      if [[ -e "$launcher" && "$dir/pi" -ef "$launcher" ]]; then
        clean+=("$dir")
      fi
      continue
    fi
    clean+=("$dir")
  done
  if ((${#clean[@]} == 0)); then
    echo "installer PATH is empty" >&2
    exit 1
  fi
  IFS=:
  printf '%s' "${clean[*]}"
}

if managed_pi_ready; then
  echo "managed-pi-already-present"
  exit 0
fi

ensure_node_on_path
tmp_root="${tmp_root:-$(mktemp -d)}"
curl -fsSL https://pi.dev/install.sh -o "$tmp_root/install.sh"
# No terminal: the installer continues with install, reinstall, or migrate
# and does not rewrite the shell rc.
env -u PI_LEGACY_INSTALL PATH="$(installer_path)" sh "$tmp_root/install.sh" </dev/null

if ! managed_pi_ready; then
  echo "Pi installer finished but the managed install is not usable" >&2
  exit 1
fi
echo "installed-managed-pi"
