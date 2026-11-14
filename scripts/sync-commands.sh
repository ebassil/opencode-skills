#!/usr/bin/env bash
#
# sync-commands.sh — synchronize commands from a source folder to a destination folder
#
# Every top-level Markdown file of the source is copied to DESTINATION and every
# subfolder is synced recursively, adding, updating and removing files so each
# synced command exactly matches its source. Only .md files become commands
# (nested folders become commands named with "/" separators), so other files are
# skipped. Commands that exist only in the destination are left untouched unless
# --mirror is passed.
#
# Uses rsync when available and falls back to pure bash + coreutils otherwise.

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [SOURCE] [DESTINATION] [options]

Synchronize commands from SOURCE to DESTINATION.

Arguments:
  SOURCE         commands folder to sync from   (default: <repo>/commands)
  DESTINATION    commands folder to sync into   (default: <repo>/.opencode/commands)

Options:
  -m, --mirror   also remove commands from DESTINATION that are not in SOURCE
  -h, --help     show this help and exit

Examples:
  $SCRIPT_NAME
  $SCRIPT_NAME ~/my-commands ~/project/.opencode/commands
EOF
}

positional=()
mirror=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    -m|--mirror) mirror=1 ;;
    -h|--help) usage; exit 0 ;;
    -*)
      echo "$SCRIPT_NAME: unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
    *) positional+=("$1") ;;
  esac
  shift
done

if ((${#positional[@]} > 2)); then
  echo "$SCRIPT_NAME: expected at most 2 arguments, got ${#positional[@]}" >&2
  usage >&2
  exit 1
fi

# defaults are relative to the repository root; passed paths are used as given
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
src="${positional[0]:-$root/commands}"
dst="${positional[1]:-$root/.opencode/commands}"

[[ -d "$src" ]] || { echo "$SCRIPT_NAME: source folder not found: $src" >&2; exit 1; }
mkdir -p "$dst"

use_rsync=0
command -v rsync >/dev/null 2>&1 && use_rsync=1

# sync_dir <source> <destination>: make <destination> an exact copy of <source>
sync_dir() {
  local s="${1%/}" d="${2%/}" rel
  mkdir -p "$d"
  if ((use_rsync)); then
    rsync -a --delete "$s/" "$d/"
    return
  fi
  # copy every file and directory, preserving permissions
  while IFS= read -r -d '' rel; do
    if [[ -d "$s/$rel" ]]; then
      mkdir -p "$d/$rel"
    else
      mkdir -p "$d/$(dirname "$rel")"
      cp -p "$s/$rel" "$d/$rel"
    fi
  done < <(cd "$s" && find . -mindepth 1 -print0)
  # remove files in the destination that no longer exist in the source
  local stale=()
  mapfile -d '' stale < <(cd "$d" && find . -mindepth 1 -depth -print0)
  for rel in ${stale[@]+"${stale[@]}"}; do
    [[ -e "$s/$rel" || -L "$s/$rel" ]] || rm -rf "${d:?}/$rel"
  done
}

synced=0
skipped=0
for entry in "$src"/*; do
  [[ -e "$entry" || -L "$entry" ]] || continue
  name="$(basename "$entry")"
  if [[ -d "$entry" ]]; then
    sync_dir "$entry" "$dst/$name"
    echo "sync  $name"
    synced=$((synced + 1))
  elif [[ "$name" == *.md ]]; then
    cp -p "$entry" "$dst/$name"
    echo "sync  $name"
    synced=$((synced + 1))
  else
    echo "skip  $name (not a .md file)"
    skipped=$((skipped + 1))
  fi
done

if ((mirror)); then
  for entry in "$dst"/*; do
    [[ -e "$entry" || -L "$entry" ]] || continue
    name="$(basename "$entry")"
    if [[ ! -e "$src/$name" && ! -L "$src/$name" ]]; then
      rm -rf "${entry:?}"
      echo "rm    $name (not in $src)"
    fi
  done
fi

echo "done: $synced synced, $skipped skipped -> $dst"
