---
name: felt
description: Record how the session feels right now. Use when the user says "/felt", "mark this as rot", "this session feels tangled", "feels fine", or wants a timestamped ground-truth mark for later dial comparison.
disable-model-invocation: true
---

# felt

Record the mark in `cockpit_felt` on the ops database when configured, falling back to the file so a mark is NEVER lost to an unreachable database:

```bash
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ); TR="${COCKPIT_TRANSCRIPT:--}"
# WORD = first argument verbatim; NOTE = the rest verbatim
doppler run --project ops --config dev -- bash -c \
  'psql "$COCKPIT_DB_URL" -v ON_ERROR_STOP=1 -c \
   "insert into cockpit_felt (felt_at,transcript,word,note) values (\$\$'"$TS"'\$\$,nullif(\$\$'"$TR"'\$\$,\$\$-\$\$),\$\$'"$WORD"'\$\$,nullif(\$\$'"$NOTE"'\$\$,\$\$\$\$))"' \
  || printf '%s\t%s\t%s\t%s\n' "$TS" "$TR" "$WORD" "$NOTE" \
       >> "${COCKPIT_DATA:-$HOME/.cursor/cockpit}/felt.log"
```

Print back one line — `<TS>\t<TR>\t<word>\t<note>` plus `→ cockpit_felt` or `→ felt.log (db unreachable)` — and nothing else.

One Bash call. Never interpret the mark, never suggest a remedy. The comparison happens later, in `/report`.
