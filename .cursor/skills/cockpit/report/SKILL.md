---
name: report
description: Run the retrospective context report over recent sessions. Use when the user says "/report", "context report", "how heavy were my sessions", or asks what the dials did before a /felt mark.
disable-model-invocation: true
---

Run `.cursor/cockpit/scripts/context-report.sh [days]` (default 7) in one Bash call and show its output verbatim.

Then, only if `${COCKPIT_DATA:-$HOME/.cursor/cockpit}/felt.log` exists and has entries, add one short section: for each mark, the dials from the 20 turns before it (compute with `.cursor/cockpit/scripts/ctxlab.py <transcript>` on the transcript the mark names). Draw no conclusion the numbers do not support.
