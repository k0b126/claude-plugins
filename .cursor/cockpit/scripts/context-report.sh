#!/usr/bin/env bash
# Why did this session get heavy? — the retrospective half of the context instruments.
#
# The statusline carries the TRIGGER (context size and ↑k/turn). This carries the
# DIAGNOSIS: per-session shape, and the day-by-day trend, so a drift has a visible cause.
#
# WHY THE RATIO IS HERE AND NOT ON THE STATUSLINE. ratio = mean_context ÷ fresh_per_turn,
# algebraically — so a single reading cannot separate "context grew" from "I read less",
# and both raise it. As a TREND beside the two series it decomposes into, it is readable;
# as a lone number beside a bar it misleads. Measured 2026-08-21: the two best ratios in
# this history were the two heaviest sessions.
#
# ONE MESSAGE = SEVERAL JSONL ROWS. An assistant message is written as one row per
# content block (text, thinking, tool_use) and EVERY row repeats the same `usage` object.
# Summing rows double-counts: measured 2026-08-21, 218 rows for 124 messages, inflating
# totals ~1.8x. Deduplicate on .message.id. Ratios survive (both sides inflate together,
# 1:15 vs 1:16) but turn counts and absolute totals do not.
#
# Usage: context-report.sh [days=7]
set -uo pipefail
days=${1:-7}; cut=$(date -d "-$days days" +%F)
. "$(dirname "$0")/lib.sh"
P="$HOME/.cursor/projects"

echo "── Sessions, last $days days ─────────────────────────────────────────────"
printf '%-10s %5s %8s %8s %8s %7s %7s  %s\n' session turns peak mean fresh/tn growth ratio started
find "$P" -path '*/agent-transcripts/*.jsonl' -newermt "$cut" 2>/dev/null | while read -r f; do
  jq -rc 'select(.message.usage!=null)|[(.message.id // "?"), .timestamp,
      ((.message.usage.input_tokens//0)+(.message.usage.output_tokens//0)+(.message.usage.cache_creation_input_tokens//0)),
      (.message.usage.cache_read_input_tokens//0)]|@tsv' "$f" 2>/dev/null \
  | awk -F'\t' -v n="$(basename "$f" .jsonl | cut -c1-10)" '
      seen[$1]++ {next}
      {t++; fresh+=$3; cr+=$4; ctx[t]=$4; if($4>peak)peak=$4; if(t==1)first=$2}
      END{
        if (t < 10) exit;                      # too short to have a shape
        w = t>30 ? 30 : t-1;
        g = w>0 ? (ctx[t]-ctx[t-w])/1000/w : 0;
        printf "%-10s %5d %7.0fk %7.0fk %7.0fk %+6.1fk %6s  %s\n",
          n, t, peak/1000, cr/t/1000, fresh/t/1000, g,
          (fresh>0 ? sprintf("1:%.0f", cr/fresh) : "-"), substr(first,6,11) }'
done | sort -k3 -rn

echo
echo "── Daily trend ───────────────────────────────────────────────────────────"
printf '%-12s %9s %9s %8s %7s  %s\n' day fresh cache-read ratio turns shape
find "$P" -path '*/agent-transcripts/*.jsonl' -newermt "$cut" -print0 2>/dev/null | xargs -0 cat 2>/dev/null \
| jq -rc 'select(.message.usage!=null)|[(.message.id // "?"), (.timestamp[0:10]),
    ((.message.usage.input_tokens//0)+(.message.usage.output_tokens//0)+(.message.usage.cache_creation_input_tokens//0)),
    (.message.usage.cache_read_input_tokens//0)]|@tsv' 2>/dev/null \
| awk -F'\t' -v cut="$cut" 'seen[$1]++ {next} $2>=cut {f[$2]+=$3; c[$2]+=$4; n[$2]++}
    END{ for (d in f) printf "%s\t%.1f\t%.1f\t%d\n", d, f[d]/1e6, c[d]/1e6, n[d] }' \
| sort | awk -F'\t' '{
    r = $2>0 ? $3/$2 : 0;
    bar=""; b=int(r/8); if(b>18)b=18; for(i=0;i<b;i++) bar=bar "▓";
    printf "%-12s %8.1fM %8.1fM  1:%-5.0f %6d  %s\n", $1, $2, $3, r, $4, bar }'
echo
echo "ratio = mean context ÷ fresh per turn. A RISING ratio usually means context is"
echo "sitting and being re-read, not that you got efficient — read it beside the two"
echo "columns it is made of. Growth (↑k/turn) is the number that cannot be flattered."
