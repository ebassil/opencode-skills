#!/usr/bin/env bash
#
# sync.sh — synchronize skills and commands from a source root to a destination root
#
# Runs sync-skills.sh followed by sync-commands.sh. With no arguments each
# script uses its own defaults (<repo>/skills -> <repo>/.opencode/skills and
# <repo>/commands -> <repo>/.opencode/commands). With a source and destination
# root, the 'skills' and 'commands' subfolders of each are passed on.

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [SOURCE_ROOT] [DEST_ROOT] [options]

Synchronize skills and commands by calling sync-skills.sh and
sync-commands.sh in sequence.

Arguments:
  SOURCE_ROOT   folder containing 'skills' and 'commands' to sync from
  DEST_ROOT     folder to sync into; receives 'skills' and 'commands'
                subfolders

Options:
  -m, --mirror   also remove entries from the destination that are not in
                 the source (passed on to both scripts)
  -h, --help     show this help and exit

Examples:
  $SCRIPT_NAME
  $SCRIPT_NAME ~/my-opencode ~/project/.opencode
  $SCRIPT_NAME ~/my-opencode ~/project/.opencode --mirror
EOF
}

positional=()
mirror=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -m|--mirror) mirror=(-m) ;;
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

case "${#positional[@]}" in
  0|2) ;;
  1)
    echo "$SCRIPT_NAME: expected SOURCE_ROOT and DEST_ROOT together, or neither" >&2
    usage >&2
    exit 1
    ;;
  *)
    echo "$SCRIPT_NAME: expected at most 2 arguments, got ${#positional[@]}" >&2
    usage >&2
    exit 1
    ;;
esac

if ((${#positional[@]} == 2)); then
  src="${positional[0]}"
  dst="${positional[1]}"
  "$dir/sync-skills.sh" "$src/skills" "$dst/skills" ${mirror[@]+"${mirror[@]}"}
  "$dir/sync-commands.sh" "$src/commands" "$dst/commands" ${mirror[@]+"${mirror[@]}"}
else
  "$dir/sync-skills.sh" ${mirror[@]+"${mirror[@]}"}
  "$dir/sync-commands.sh" ${mirror[@]+"${mirror[@]}"}
fi
