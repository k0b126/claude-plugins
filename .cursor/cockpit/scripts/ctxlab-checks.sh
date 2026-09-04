#!/usr/bin/env bash
# ctxlab-checks — the frozen canaries. Every 0.5.x/0.6.x change was verified
# against three transcript shapes that existed only in one session; this
# script FABRICATES equivalent synthetic transcripts (no private session data
# is ever committed) and asserts what those canaries asserted. This is the CI
# prepayment: when a pipeline exists, its ctxlab gate is "run this script".
#
# Shapes: (A) no-compact race — lap 1 must equal race, no stint, no box.
#         (B) two laps — lap numbering, stint sparkline+lengths, per-lap mix.
#         (C) just-boxed — truthful empty lap bar, box line present,
#             and the 616% class: tool% must never exceed 100 post-box.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
export COCKPIT_DATA="$tmp/data"   # never touch the real cockpit cache

gen(){ # gen <file> <asst-per-lap...>  — boundary between laps
python3 - "$@" <<'PY'
import json, sys
out=sys.argv[1]; laps=[int(x) for x in sys.argv[2:]]
with open(out,'w') as f:
    for li,n in enumerate(laps):
        if li: f.write(json.dumps({"type":"system","subtype":"compact_boundary","timestamp":f"2026-08-27T{li:02d}:00:00.000Z"})+"\n")
        for i in range(n):
            f.write(json.dumps({"type":"user","message":{"role":"user","content":[{"type":"text","text":f"prompt {i}"}]}})+"\n")
            f.write(json.dumps({"type":"assistant","message":{"role":"assistant","id":f"m{li}-{i}","content":[{"type":"tool_use","input":{"file_path":f"/f{i%3}.ts"}},{"type":"text","text":"ok"}],"usage":{"input_tokens":100,"output_tokens":50,"cache_creation_input_tokens":200,"cache_read_input_tokens":1000+i}}})+"\n")
            f.write(json.dumps({"type":"user","message":{"role":"user","content":[{"type":"tool_result","content":"x"*400}]}})+"\n")
PY
}

pass=0; fail=0
ok(){ echo "  ok: $1"; pass=$((pass+1)); }
bad(){ echo "  FAIL: $1"; fail=$((fail+1)); }
run(){ rm -rf "$COCKPIT_DATA"; python3 "$here/ctxlab.py" "$1"; }

echo "A · no-compact race"
gen "$tmp/a.jsonl" 12
outA=$(run "$tmp/a.jsonl")
grep -q "^lap 1" <<<"$outA" && ok "lap 1" || bad "expected lap 1: $outA"
lapbar=$(grep "^lap" <<<"$outA" | grep -o "▐[^▏]*▏"); racebar=$(grep "^race" <<<"$outA" | grep -o "▐[^▏]*▏")
[ "$lapbar" = "$racebar" ] && ok "lap bar == race bar (race of one lap)" || bad "bars differ: $lapbar vs $racebar"
grep -q "^stint" <<<"$outA" && bad "stint shown with no closed lap" || ok "no stint before first box"
grep -q "^box" <<<"$outA" && bad "box line with no box" || ok "no box line"

echo "B · two laps"
gen "$tmp/b.jsonl" 20 8
outB=$(run "$tmp/b.jsonl")
grep -q "^lap 2" <<<"$outB" && ok "lap 2" || bad "expected lap 2: $outB"
grep -q "stint.*20t" <<<"$outB" && ok "stint carries closed-lap length 20t" || bad "stint missing 20t: $outB"
grep -q "of last" <<<"$outB" && ok "this-lap-vs-last ratio present" || bad "ratio absent"

echo "C · just-boxed (the 616% class)"
gen "$tmp/c.jsonl" 30 0
outC=$(run "$tmp/c.jsonl")
grep -q "lap 2 .*0t" <<<"$outC" && ok "fresh lap 0t" || bad "fresh lap not 0t: $outC"
grep -q "▐············▏" <<<"$outC" && ok "truthful empty bar" || bad "empty bar wrong"
grep -q "^box" <<<"$outC" && ok "box line (the /felt backstop)" || bad "box line absent"
tools=$(grep -o "tool [0-9]*%" <<<"$outC" | grep -o "[0-9]*" || echo 0)
for t in ${tools:-0}; do [ "$t" -le 100 ] && ok "tool% ≤ 100 ($t%) — 616% class closed" || bad "tool% $t% > 100"; done

echo; echo "ctxlab-checks: $pass passed · $fail failed"
[ "$fail" -eq 0 ]
