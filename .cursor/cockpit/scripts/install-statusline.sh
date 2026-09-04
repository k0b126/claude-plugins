#!/usr/bin/env bash
# Point Cursor CLI's statusLine at this install's statusline.sh.
# Writes ~/.cursor/cli-config.json (idempotent; backs up first).
set -euo pipefail
. "$(dirname "$0")/lib.sh"
S="$HOME/.cursor/cli-config.json"
[ -f "$S" ] || echo '{}' > "$S"
bak="$S.bak-$(date +%Y%m%d-%H%M%S)"
cp "$S" "$bak"
echo "backup: $bak"
cmd="$COCKPIT_ROOT/scripts/statusline.sh"
tmp=$(mktemp)
jq --arg c "$cmd" '.statusLine = {type:"command", command:$c, padding:0}' "$S" > "$tmp" && mv "$tmp" "$S"
echo "statusLine → $cmd"
echo "(restart Cursor CLI, or it takes effect on the next session)"
