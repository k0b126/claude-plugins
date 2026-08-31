# Metrics ledger — what each dial is hypothesised to mean, and what it has earned

Two registers on the statusline. A metric's STATUS decides which one it renders in:

| status | register | rendering |
|---|---|---|
| candidate | instrument (`lab` / `ctx` lines) | dim, no colour, no verdict word — a reading |
| promoted | alarm (its own line, above) | coloured, with a verdict — a claim |
| demoted | report only (`context-report.sh`) | never on the statusline |

**Promotion rule.** A candidate is promoted when `/felt` marks show it was elevated in
the 20 turns before ≥3 `rot`/`tangled` marks AND quiet before ≥3 `fine` marks. Small
numbers, but they are your numbers. Demotion needs one written reason.

**Why no colour on a candidate.** The fresh:cache ratio was shown dim and still got read
as a claim, then turned out to be `mean_context ÷ fresh_per_turn` — a quotient that
rewards the rot profile. A colour would have made that worse. Colour is a claim.

## Entries

### ratio — fresh : cache-read   · DEMOTED 2026-08-23
Hypothesis was: efficiency. Reality: algebraically mean_context ÷ fresh_per_turn, so it
cannot separate "context grew" from "I read less"; the two best ratios in the history
(1:83, 1:47) were the two heaviest sessions. Lives in context-report.sh as a trend only.

### areas — distinct code areas in the last 40 reads   · candidate
Hypothesis: interleaving. Predicts `tangled`. Windowed, so non-monotone. Unvalidated:
8e347037 touched 5 areas across 46 files and may simply have been a broad task.

### old — % of context tokens added more than 50 turns ago   · candidate
Hypothesis: age-heaviness precedes `rot`. Monotone within a session (only compaction
resets it) — weak on its own; read beside `live`.

### dup — superseded-read dead weight as % of context   · candidate (weak)
Measured 0–7.4% across 8 sessions. Provably dead, but too small to act on and monotone.
Kept on the line for intuition, unlikely to promote.

### tool — tool-result share of context   · candidate
Hypothesis: high share = context is dumped output, not conversation; predicts `rot`.
Observed 11–71%. The 71% session is this one, which did a great deal of measuring.

### live — % of context whose files were touched in the last 20 turns   · candidate
Hypothesis: low `live` with high `old` = "I rely only on recent context", and the move
is carry-the-live-part-forward (compaction or a handoff, then /clear) — NOT a bare
/clear, which drops the live part too. CAVEAT: measures what I touched, not what the
model used. A dim segment can still inform answers silently.

### prefix age — minutes since the last request on this transcript   · promoted by mechanism
Not a rot signal. Predicts the 10× rung directly (TTL = 5 min), so it needs no marks.
Renders only when idle ≥ 5 min, as the free moment to prune. BUILT 2026-08-23: reads the
transcript's mtime (tracks the last request to the second — verified), so no parsing.
Wording: "idle Nm (lease expired) — next turn likely rebuilds ~Xk". A THRESHOLD, not a
meter: 22 min costs exactly what 6 min costs; the count only says how long ago it happened.
"likely" because a 1-hour breakpoint can keep an entry alive past 5 min (10.8-min survival
observed) and that is invisible from outside.
