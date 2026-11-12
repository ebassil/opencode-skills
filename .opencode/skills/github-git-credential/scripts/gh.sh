#!/usr/bin/env bash
# Run a gh command authenticated with a PAT held in git's in-memory
# credential-cache daemon. The token is never printed, logged, or stored on disk.
#
# Exit 127 means the credential is missing or the helper is not configured:
# the caller must relay the printed FIX instructions to the user verbatim
# (an agent cannot prompt for secrets interactively).
#
# Usage: gh.sh <gh args...>            # e.g. gh.sh issue list -R owner/repo
#        GH_HOST=<host> gh.sh ...      # default host: github.com
set -euo pipefail

host="${GH_HOST:-github.com}"

if ! git config --global --get-all credential.helper 2>/dev/null | grep -q '^cache'; then
  echo "ERROR: git credential.helper 'cache' is not configured globally." >&2
  echo "" >&2
  echo "FIX (user runs this in their own terminal, then retry):" >&2
  echo "  git config --global credential.helper 'cache --timeout=172800'" >&2
  exit 127
fi

tok=$(printf 'protocol=https\nhost=%s\n\n' "$host" \
  | GIT_TERMINAL_PROMPT=0 git credential fill 2>/dev/null \
  | sed -n 's/^password=//p') || true

if [ -z "${tok:-}" ]; then
  echo "ERROR: no cached credential for https://${host} (cache daemon empty, expired, or socket unreachable; check XDG_RUNTIME_DIR)." >&2
  echo "" >&2
  echo "FIX (user MUST run this in their own SSH terminal - the agent cannot prompt for the PAT):" >&2
  cat >&2 <<EOF
  umask 077
  printf 'GitHub PAT: '
  read -rs t; echo
  printf 'protocol=https\nhost=${host}\nusername=<your-github-username>\npassword=%s\n\n' "\$t" | git credential approve
  unset t
EOF
  echo "" >&2
  echo "Notes: the timeout counts from seeding, not from use; reboot or 'git credential-cache exit' wipes it. Verify afterwards with:" >&2
  echo "  printf 'protocol=https\nhost=${host}\n\n' | GIT_TERMINAL_PROMPT=0 git credential fill | sed -n 's/^username=//p'" >&2
  exit 127
fi

GH_TOKEN="$tok" exec gh "$@"
