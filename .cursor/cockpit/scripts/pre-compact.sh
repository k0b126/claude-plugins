#!/usr/bin/env bash
# preCompact hook — the /felt moment, caught BEFORE the box (Cursor port).
#
# Cursor output: user_message (shown when compaction occurs).
set -uo pipefail
. "$(dirname "$0")/lib.sh"
input=$(cat 2>/dev/null || true)
trig=$(printf '%s' "$input" | jq -r '.trigger // "manual"' 2>/dev/null)
tx=$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)
[ -z "$tx" ] && tx="${CURSOR_TRANSCRIPT_PATH:-${COCKPIT_TRANSCRIPT:-}}"

n="?"; lap="?"
if [ -n "$tx" ] && [ -f "$tx" ]; then
  n=$(tac "$tx" 2>/dev/null | awk '/"subtype":"compact_boundary"|"compact_boundary"/{exit} /"type":"assistant"/{c++} END{print c+0}')
  b=$(grep -cE '"subtype":"compact_boundary"|compact_boundary' "$tx" 2>/dev/null || echo 0)
  lap=$((b+1))
fi

if [ "$trig" = "auto" ]; then
  msg="🏁 lap ${lap} auto-boxed at ~${n}t — the tank ran dry, no choice was made. When you surface: /felt rot|tangled|fine (an auto-box is weather, and weather is worth a mark)"
else
  msg="🏁 boxing lap ${lap} (~${n}t) — how did it feel? /felt rot|tangled|fine — rain or planned?"
fi

jq -cn --arg m "$msg" '{user_message:$m}'
