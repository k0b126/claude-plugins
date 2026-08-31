#!/usr/bin/env bash
# Claude Code status line — session · where am I · how full is the context.
# Reads the JSON Claude Code passes on stdin (docs: code.claude.com/docs/en/statusline).
. "$(dirname "$0")/lib.sh"
input=$(cat)
j(){ printf '%s' "$input" | jq -r "$1 // empty" 2>/dev/null; }

session=$(j '.session_name'); [ -z "$session" ] && session=$(j '.session_id' | cut -c1-8)
cwd=$(j '.workspace.current_dir'); [ -z "$cwd" ] && cwd=$(j '.cwd')
project=$(j '.workspace.project_dir')
branch=$(git -C "$cwd" branch --show-current 2>/dev/null); [ -z "$branch" ] && branch="detached"
# THE FAMILY, not the spine. The spine ("how did I get here") is printed once by the
# SessionStart hook and scrolls away; this line answers the question asked all day when
# several sessions run in parallel: who is beside me, who is below me, and which of them
# has its own worktree (⑂) so a second session can drive it. "⇄—" is the two-hop rule
# showing its own violation continuously rather than at an audit.
#
# Repo-provided: the repo's own script knows its branch shape. TWO NAMES are accepted and
# both are permanent, not a transition: family.sh is the name since 2026-08-23 (a subtree is
# descendants only; the view shows ancestors too), and subtree.sh still exists on every branch
# the rename has not reached — which today is all of them but anak_dev_ui. Where neither is
# present, fall back to the recorded-parent spine.
#
# The fallback is silent BY DESIGN — it is how the plugin works in a repo with no such script.
# That means a rename is indistinguishable from absence: the family line just quietly becomes
# the spine, with no error. Observed the day of the rename. Hence: try both names.
fam=""
if [ -n "$cwd" ]; then
  root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || true)
  fsh=""
  for cand in family subtree; do
    [ -n "$root" ] && [ -x "$root/scripts/$cand.sh" ] && { fsh="scripts/$cand.sh"; break; }
  done
  if [ -n "$fsh" ]; then
    # Cache on HEAD + the worktree list: the two things that change the answer. ~89ms cold.
    ck="$COCKPIT_DATA/family.$(printf '%s' "$root$branch$fsh" | cksum | cut -d' ' -f1)"
    sig="$(git -C "$root" rev-parse HEAD 2>/dev/null)|$(git -C "$root" worktree list 2>/dev/null | cksum | cut -d' ' -f1)"
    if [ -f "$ck" ] && [ "$(head -1 "$ck")" = "$sig" ]; then fam=$(tail -n +2 "$ck")
    else fam=$(cd "$root" && timeout 3 "./$fsh" "$branch" --line 2>/dev/null || true)
         [ -n "$fam" ] && { printf '%s\n%s\n' "$sig" "$fam" > "$ck"; }
    fi
  fi
fi
# BOTH, since 0.2.1. The spine is the vertical question ("how did I get here", and how
# deep am I); the family is the horizontal one ("who is beside me, where is a free seat").
# Neither substitutes for the other, and the spine's abbreviation already keeps it short.
# 0.3.0: --line now carries the FULL spine with ★ as the pivot, so the separate abbreviated
# spine 0.2.1 printed beside it is gone — it duplicated the parent and self, and the elision
# hid the hops worth seeing. Where subtree.sh is absent the spine still stands alone below.
if [ -n "$fam" ]; then branch="$fam"
else
# Ancestry from recorded parents; abbreviated to root › … › last two hops so it fits.
  path=$("$COCKPIT_ROOT/scripts/lineage-path.sh" "$cwd" "$branch" 2>/dev/null)
  n=$(printf '%s' "$path" | awk -F' › ' '{print NF}')
  if [ "${n:-1}" -gt 3 ]; then
    first=$(printf '%s' "$path" | awk -F' › ' '{print $1}'); last2=$(printf '%s' "$path" | awk -F' › ' '{print $(NF-1)" › "$NF}')
    path="$first › …$((n-3)) › $last2"
  fi
    [ -n "$path" ] && [ "$path" != "$branch" ] && branch="$path"
fi
dirty=$(git -C "$cwd" status --porcelain --untracked-files=no 2>/dev/null | wc -l | tr -d ' ')
# Where: the worktree name if inside .claude/worktrees/, else "main checkout"
case "$cwd" in
  */.cursor/worktrees/*|*/.claude/worktrees/*) where="⑂ ${cwd##*/worktrees/}"; where="${where%%/*}";;
  *) where="main checkout";;
esac
pct=$(j '.context_window.used_percentage' | cut -d. -f1); [ -z "$pct" ] && pct=0
size=$(j '.context_window.context_window_size'); used=$(j '.context_window.total_input_tokens')
model=$(j '.model.display_name'); effort=$(j '.effort.level')
cost=$(j '.cost.total_cost_usd'); [ -n "$cost" ] && cost=$(printf '$%.2f' "$cost")

# ---- Plan limits. The payload carries exactly TWO buckets and no more:
# rate_limits.five_hour and rate_limits.seven_day, each {used_percentage, resets_at}.
# Verified by capturing real stdin on 2026-08-21 — the full field list is 35 paths and
# there is NO per-model bucket. Re-verified the same day with a dump that INCLUDES nulls and
# container keys (the first pass used `paths(scalars)`, which would have hidden a null bucket):
# 47 keys, rate_limits has exactly two children. So a model-specific weekly cap cannot be shown
# here however the plan meters it — `/usage` renders that from a live call the statusline never
# sees, and nothing on disk caches it. The bar below is therefore labelled "all" rather than
# left ambiguous: an unlabelled weekly bar reads as THE weekly limit, which is the one number
# it is not.
five=$(j '.rate_limits.five_hour.used_percentage' | cut -d. -f1)
week=$(j '.rate_limits.seven_day.used_percentage' | cut -d. -f1)
five_at=$(j '.rate_limits.five_hour.resets_at'); week_at=$(j '.rate_limits.seven_day.resets_at')

# "resets_at" is a unix epoch; a countdown is what a person can act on, a timestamp is not.
until_(){ local t=$1 now d h m; [ -z "$t" ] && return; now=$(date +%s); d=$((t-now))
  [ "$d" -le 0 ] && { printf 'now'; return; }
  h=$((d/3600)); m=$(((d%3600)/60))
  if [ "$h" -ge 24 ]; then printf '%dd%dh' "$((h/24))" "$((h%24))"; elif [ "$h" -ge 1 ]; then printf '%dh%02dm' "$h" "$m"; else printf '%dm' "$m"; fi; }
# One colour rule for both bars: the number only matters as it approaches the ceiling.
lim_c(){ local p=${1:-0}; if [ "$p" -ge 90 ]; then printf '\033[1;31m'; elif [ "$p" -ge 75 ]; then printf '\033[31m'; elif [ "$p" -ge 50 ]; then printf '\033[33m'; else printf '\033[32m'; fi; }
minibar(){ local p=${1:-0} i n out=""; n=$((p/20)); for i in 1 2 3 4 5; do [ $i -le $n ] && out="${out}▰" || out="${out}▱"; done; printf '%s' "$out"; }

# Zone — in TOKENS, not percent. Research 2026-08-21: no primary source supports a universal
# cut-off (the "120k" figure has none); degradation is a gradual, model-dependent slope
# (Anthropic: "a performance gradient rather than a hard cliff"). The bands below are anchored
# on the only published numbers, which are policy defaults: Anthropic's server-side compaction
# trips at 150k input tokens; Claude Code compacts near the window (~967k on a 1M model).
# Override per shell: KARANT_ZONE_LOADED_K / KARANT_ZONE_HEAVY_K / KARANT_ZONE_COMPACT_K.
uk=$(( ${used:-0} / 1000 ))
L=${KARANT_ZONE_LOADED_K:-150}; H=${KARANT_ZONE_HEAVY_K:-400}; C=${KARANT_ZONE_COMPACT_K:-900}
if   [ "$uk" -lt "$L" ]; then zone="clear";          c=$'\e[32m'
elif [ "$uk" -lt "$H" ]; then zone="loaded";         c=$'\e[33m'
elif [ "$uk" -lt "$C" ]; then zone="heavy · rot risk"; c=$'\e[31m'
else                          zone="compact soon";   c=$'\e[1;31m'; fi
# One call, six fields. runway.sh caches for 5 minutes, so this costs ~17ms per render.
rw_burn=""; rw_fuel=""; rw_reset=""; rw_proj=""; rw_verdict=""; rw_ratio=""; rw_growth=""
# No weekly bucket (older CLI, another harness) means no scale, and a runway computed
# from nothing renders as "999h ✓ clear" — worse than absent, because it reads as good news.
if [ -x "$COCKPIT_ROOT/scripts/runway.sh" ] && [ -n "$week" ] && [ -n "$week_at" ]; then
  read -r rw_burn rw_fuel rw_reset rw_proj rw_verdict rw_ratio rw_growth < <(
    "$COCKPIT_ROOT/scripts/runway.sh" "${week:-0}" "${week_at:-0}" "$(j '.transcript_path')" 2>/dev/null)
fi

r=$'\e[0m'; d=$'\e[2m'
bar=""; n=$((pct/10)); for i in $(seq 1 10); do [ $i -le $n ] && bar="${bar}█" || bar="${bar}░"; done

# Terminal tab title: session · branch, so VS Code tabs tell sessions apart
printf '\033]0;%s · %s\007' "$session" "$branch"

printf '%s  %s%s%s  %s%s  %s%s%s\n' \
  "$session" "$d" "$where" "$r" "$branch" "$( [ "$dirty" != 0 ] && printf ' ±%s' "$dirty")" \
  "$d" "${model}${effort:+ · $effort}" "$r"
printf '%s%s %3s%% %s%s  %s%s%s%s\n' \
  "$c" "$bar" "$pct" "$zone" "$r" \
  "$d" "$( [ -n "$used" ] && [ -n "$size" ] && printf '%sk/%sk' "$((used/1000))" "$((size/1000))")" \
  "$( [ -n "$rw_growth" ] && [ "$rw_growth" != "-" ] && printf ' ↑%sk/turn' "$rw_growth")${cost:+ · $cost}" "$r"

# Line 4 is appended after this block — see below.
# Line 3 — plan limits. Context (line 2) is this conversation and resets when it ends;
# these are the account's, and they do not.
if [ -n "$five" ] || [ -n "$week" ]; then
  printf '%ssession%s %s%s %2s%%%s%s  %sweek·all%s %s%s %2s%%%s%s\n' \
    "$d" "$r" "$(lim_c "$five")" "$(minibar "$five")" "${five:-0}" "$r" \
    "$d$( [ -n "$five_at" ] && printf ' ↻%s' "$(until_ "$five_at")")$r" \
    "$d" "$r" "$(lim_c "$week")" "$(minibar "$week")" "${week:-0}" "$r" \
    "$d$( [ -n "$week_at" ] && printf ' ↻%s' "$(until_ "$week_at")")$r"
fi

# ---- Line 4: runway. Constant shape, colour by verdict — the position never moves, so
# the eye learns where to look; only the colour and the last word change.
if [ -n "$rw_verdict" ] && [ -n "$week" ]; then
  case "$rw_verdict" in
    over)   rc=$'\e[1;31m'; note="⛔ slow down — cut turns and context, not subagents";;
    tight)  rc=$'\e[33m';   note="⚠ tight — no room for a heavy day";;
    warmup) rc=$'\e[2m';    note="gathering — needs ~15min of activity";;
    *)      rc=$'\e[32m';   note="✓ clear";;
  esac
  if [ "$rw_verdict" = warmup ]; then
    printf '%srunway%s  %sreset %sh%s\n' "$d" "$r" "$rc" "${rw_reset:-?}" "$r"
  else
    printf '%srunway%s  %s%s%%/active-h · ⛽%sh · reset %sh · lands ~%s%%%s  %s%s%s\n' \
      "$d" "$r" "$d" "$rw_burn" "$rw_fuel" "$rw_reset" "$rw_proj" "$r" "$rc" "$note" "$r"
  fi
fi

# ---- goal — the work-graph pace line. INSTRUMENT register (dim), sits between the
# alarm block above and the lap block below. Renders ~/.claude/cockpit/pace.json — a
# CACHE the lens dual-writes; this script NEVER computes graph facts (one head, one
# computation — the lens's). What it does recompute, every render, is the TIME AXIS:
# slack = (due − now) − required_d, because calendar drift is deterministic and local.
# The trend arrow compares live required rate to the rate at the last read: ↗ means
# lock-in approaching on calendar burn alone. Turns since the read = effort poured
# since the strategy picture was taken (an economic meter, banked as actuals by the
# lens on completion). The provenance stamp (run N · age) is the fresh-vs-stale law
# on one token: NEVER render this line without it.
pj="$COCKPIT_DATA/pace.json"
tx=$(j '.transcript_path')
if [ -f "$pj" ]; then
  gl=$(python3 - "$pj" "${tx:-}" 2>/dev/null <<'PYG'
import json,sys,os,datetime as dt
p=json.load(open(sys.argv[1])); tx=sys.argv[2] if len(sys.argv)>2 else ""
now=dt.datetime.now(dt.timezone.utc)
due=dt.datetime.fromisoformat(p["due"].replace("Z","+00:00"))
asof=dt.datetime.fromisoformat(p["asof_ts"].replace("Z","+00:00"))
tt=(due-now).total_seconds()/86400; req=p["required_d"]
slack=tt-req; rate=req/tt if tt>0 else 99
r0=p.get("rate_at_read",rate)
arrow="↗" if rate>r0+0.005 else ("↘" if rate<r0-0.005 else "→")
cells=8; fill=max(0,min(cells,round(slack/3.0*cells)))
bar="▰"*fill+"▱"*(cells-fill)
age=(now-asof).total_seconds(); ah=age/3600
ages=f"{age/60:.0f}m" if ah<1 else (f"{ah:.0f}h" if ah<48 else f"{ah/24:.0f}d")
turns=0
if tx and os.path.isfile(tx):
    iso=p["asof_ts"][:19]
    for line in open(tx,errors="ignore"):
        if '"type":"assistant"' in line and '"isSidechain":true' not in line:
            i=line.find('"timestamp":"')
            if i>=0 and line[i+13:i+32]>=iso: turns+=1
stale=" ⚠" if ah>24 else ""
print(f'{p["goal"]} {tt:.1f}d ▐{bar}▏ slack {slack:.1f}d · req {rate:.2f} {arrow} · head: {p["head"]} · {turns}t   (run {p["asof_run"]} · {ages}{stale})')
PYG
)
  [ -n "$gl" ] && printf '%sgoal    %s%s\n' "$d" "$gl" "$r"
fi

# ---- Lines below: the INSTRUMENT register — dim, no colour, no verdict, same order every
# turn. Candidates the eye learns from; promotion to the alarm register above happens in
# ~/.claude/metrics.md by evidence (the /felt marks), never by looking good once.
if [ -n "$tx" ] && [ -f "$tx" ] && [ -x "$COCKPIT_ROOT/scripts/ctxlab.py" ]; then
  lab=$(timeout 2 python3 "$COCKPIT_ROOT/scripts/ctxlab.py" "$tx" 2>/dev/null)
  [ -n "$lab" ] && printf '%s%s%s\n' "$d" "$lab" "$r"
fi

# ---- Line 7 (conditional): the cold-prefix badge. ALARM register — promoted by mechanism,
# not by marks: the TTL is documented, so "idle > 5 min ⇒ the next turn re-writes the prefix
# at 1.25×" is a fact, not a hypothesis. It is the only instrument that shows the price of a
# turn BEFORE it is paid. A THRESHOLD, not a meter: returning after 22 min costs exactly what
# returning after 6 costs; the minute count only separates "just expired" from "been gone an
# hour". "likely", because a 1-hour breakpoint can keep an entry alive past 5 min (one
# 10.8-min survival was observed) and that is not visible from outside.
# The transcript's mtime tracks the last request to the second (verified), so no parsing.
if [ -n "$tx" ] && [ -f "$tx" ]; then
  idle=$(( $(date +%s) - $(stat -c %Y "$tx" 2>/dev/null || echo 0) ))
  if [ "$idle" -ge 300 ]; then
    im=$((idle/60)); [ "$im" -ge 120 ] && idle_s="$((im/60))h$((im%60))m" || idle_s="${im}m"
    ck=$(( ${used:-0} / 1000 ))
    printf '%sprefix%s  %s❄ idle %s (lease expired) — next turn likely rebuilds ~%sk%s  %sfree moment to compact or /clear%s\n' \
      "$d" "$r" $'\e[36m' "$idle_s" "$ck" "$r" "$d" "$r"
  fi
fi
