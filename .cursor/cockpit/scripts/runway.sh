#!/usr/bin/env bash
# Runway: how many ACTIVE hours of quota remain at the recent burn rate.
#
# WHY HOURS, NOT PERCENT. "69% used" is an odometer. The decision it feeds is
# "can I keep working the way I am working", and that is planned in hours. So:
# fuel = remaining% ÷ (%-burned per active hour).
#
# WHERE THE NUMBERS COME FROM. Two sources, deliberately:
#   scale  — the LIVE seven_day.used_percentage from the statusline payload. Ground truth.
#   shape  — transcript JSONL under ~/.claude/projects: timestamps give ACTIVE hours
#            (gaps <30min count as working), so % can be divided by hours actually worked
#            rather than by wall-clock, which counts sleep as thrift.
#
# THE ASSUMPTION, STATED. Attributing % across active time assumes burn is roughly even
# while working. Unverified: nothing published says whether CACHE READS meter against the
# rate limit the way fresh tokens do. A sampler pairing % with token deltas over several
# days would settle it; until then treat fuel as a good estimate, not a meter reading.
#
# It also reports THIS SESSION's cumulative fresh:cache ratio from its own transcript.
# Not the payload's current_usage, which is one turn and too noisy to steer by; and not a
# target to maximise — a huge context re-read many times gives a flattering ratio while
# burning more. It is a drift signal: rising fresh share means context churn or many short
# contexts; a large context is visible on the line above.
#
# ONE MESSAGE = SEVERAL JSONL ROWS. An assistant message is written as one row per
# content block (text, thinking, tool_use) and EVERY row repeats the same `usage` object.
# Summing rows double-counts: measured 2026-08-21, 218 rows for 124 messages, inflating
# totals ~1.8x. Deduplicate on .message.id. Ratios survive (both sides inflate together,
# 1:15 vs 1:16) but turn counts and absolute totals do not.
#
# Usage: runway.sh <used_pct> <resets_at_epoch> [transcript]
#   → "burn_per_h fuel_h reset_h projected verdict cache_ratio ctx_growth_k_per_turn"
#
# GROWTH, not the ratio, is the live signal. Algebraically the ratio IS
# mean_context ÷ fresh_per_turn, so it cannot separate "context grew" from "I read less"
# — both raise it. Measured across 14 real sessions on 2026-08-21, the two BEST ratios
# (1:76, 1:47) were the two heaviest sessions (524k and 597k peak, 575 and 690 turns):
# a long session re-reading a large stationary context scores beautifully and is exactly
# the rot profile. Growth in k/turn cannot be flattered that way.
set -uo pipefail
used=${1:-0}; resets=${2:-0}; tx=${3:-}
. "$(dirname "$0")/lib.sh"
CACHE="$COCKPIT_DATA/runway.cache"
# Scanning 4k messages takes ~1s; the statusline renders far more often than that is
# acceptable. Recompute at most every 5 minutes, and key the cache on used% so a jump
# is never shown stale.
if [ -f "$CACHE" ]; then
  read -r c_used c_age c_hours c_ratio c_growth < "$CACHE" 2>/dev/null || true
  now=$(date +%s)
  if [ "${c_used:-x}" = "$used" ] && [ $((now - ${c_age:-0})) -lt 300 ]; then hours=$c_hours; ratio=$c_ratio; growth=$c_growth; fi
fi
if [ -z "${hours:-}" ]; then
  hours=$(find "$HOME/.cursor/projects" -path '*/agent-transcripts/*.jsonl' -mtime -8 -print0 2>/dev/null \
    | xargs -0 cat 2>/dev/null \
    | jq -r 'select(.message.usage != null) | .timestamp' 2>/dev/null \
    | sort \
    | awk -v cut="$(date -d '-7 days' +%F)" '
        $0 >= cut { ts=$0; gsub(/[-T:]/," ",ts); split(ts,a," ");
          e=mktime(a[1]" "a[2]" "a[3]" "a[4]" "a[5]" "int(a[6]));
          if (prev && e-prev < 1800) act += e-prev;
          prev=e }
        END { printf "%.2f", act/3600 }')
  ratio="-"; growth="-"
  if [ -n "$tx" ] && [ -f "$tx" ]; then
    read -r ratio growth < <(jq -r 'select(.message.usage != null)
              | [(.message.id // "?"), ((.message.usage.input_tokens//0)+(.message.usage.output_tokens//0)+(.message.usage.cache_creation_input_tokens//0)),
                 (.message.usage.cache_read_input_tokens//0)] | @tsv' "$tx" 2>/dev/null \
            | awk -F'\t' 'seen[$1]++ {next} {f+=$2; c+=$3; n++; ctx[n]=$3}
                END{
                  if (f>0 && c>0) r=sprintf("1:%.0f", c/f); else r="-";
                  # Growth over the LAST 30 turns — recency matters; a session that
                  # compacted an hour ago should not read as flat forever.
                  w = n>30 ? 30 : n-1;
                  if (w > 0) g = sprintf("%.1f", (ctx[n]-ctx[n-w])/1000/w); else g="-";
                  print r, g }')
  fi
  printf '%s %s %s %s %s\n' "$used" "$(date +%s)" "${hours:-0}" "${ratio:--}" "${growth:--}" > "$CACHE"
fi
awk -v used="$used" -v resets="$resets" -v hours="${hours:-0}" -v now="$(date +%s)" -v ratio="${ratio:--}" -v growth="${growth:--}" '
BEGIN{
  reset_h = resets > 0 ? (resets - now)/3600 : 0;
  if (hours <= 0.2) { print "- - " int(reset_h) " - warmup " ratio " " growth; exit }
  burn = used / hours;                       # % per active hour
  fuel = burn > 0 ? (100 - used)/burn : 999; # active hours until the ceiling
  # Projected assumes the coming days look like the days just past: the same active
  # hours per day continue until reset.
  elapsed_h = reset_h > 0 ? (7*24 - reset_h) : 1;
  proj = elapsed_h > 0 ? used * (7*24) / elapsed_h : used;
  v = proj > 100 ? "over" : (proj >= 90 ? "tight" : "ok");
  printf "%.1f %.1f %.0f %.0f %s %s %s\n", burn, fuel, reset_h, proj, v, ratio, growth;
}'
