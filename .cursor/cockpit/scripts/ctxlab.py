#!/usr/bin/env python3
"""ctxlab — the instrument register. Reads ONE transcript, prints the dim dials.

DIM, NO COLOUR, SAME ORDER EVERY TURN. These are candidates: readings for the eye to
learn from, never claims. A colour or a verdict word would assert a meaning none of
them has earned yet (the fresh:cache ratio was dim-but-read-as-a-claim, and had to be
evicted). Promotion happens in $COCKPIT_DATA/metrics.md, by evidence, and moves a dial
UP a line into the alarm register.

THE LAP MODEL (0.5.0, 2026-08-27). One compact = one lap; the whole session = the
race; compacting = boxing (a pit stop). You drive the current lap — it is the only
thing the next prompt can affect — so every dial is LAP-scoped. That is a bug fix
wearing a concept: the old `tool` dial divided whole-transcript tool chars by a
freshly-compacted context and read 616% the turn after a compact. A race-scope
numerator over a lap-scope denominator is structurally a lie; scoping both sides to
the lap removes the class, not the instance.

The lines, GROUPED BY SCOPE — the lap block first (it is what you are driving),
the race block after (it is the baseline). The two lap-detail lines are indented
under their head so scope is expressed by structure, not by remembering; `lab`
was renamed `dials` because lab-vs-lap was two meanings one letter apart on
adjacent lines, and this repo has already paid for that pattern once:
  lap N    — turns this lap + mix bar (assistant ▰ / tool ▱ / you ▷), 12 cells = 100%
   ├ dials — areas · old · dup · tool · files, all THIS LAP
   └ ctx   — liveness strip over THIS LAP's added tokens
  (the ├/└ connectors carry the indent IN GLYPHS because the statusline
  renderer may trim leading whitespace — an indent that only exists as
  spaces is an indent the display can silently remove)
  race     — the same mix bar for the whole session
  stint    — compact cadence: sparkline of closed-lap lengths (▁–█ scaled to the
             longest), ▏ = this lap still running · raw lengths · this lap vs
             last · median. Lap length is itself a reading: a lap ends when
             context fills, so more turns per lap = lighter burn per turn.
             Shown once a lap has closed; cadence needs history.
  box      — first ~5 turns of a fresh lap only: the previous lap just closed and
             is judgeable, so this is the /felt moment — was the box rain (rot
             forced it) or planned (chosen to set up the next lap)? Marks go to
             metrics.md; the line retires itself once the lap is underway.

The lap and race bars are the same fixed width on purpose: a stacked bar's only
honest job is composition, so equal widths make lap-vs-race mix drift visible as
boundary offset. Absolute size lives in the `t` count, exact figures in the a·t·u
labels — three encodings, one job each. `t` counts assistant records; sidechains
are skipped everywhere (their tokens are not in this thread's context and their
turns are not this driver's).

Closed laps are archived to $COCKPIT_DATA/laps.<hash>.json (rewritten whole each
recompute, so it is idempotent) — telemetry for after the race: lengths, mix and
boundary timestamps, the dataset for finding a box cadence that fits the terrain.
Deliberately NOT rendered here: the cockpit shows the lap being driven.

Liveness = "did I touch anything from this segment in the last 20 turns" — a file
re-read, or its path appearing in later text. That is what YOU engaged with, not what
the MODEL used; a dim segment can still be informing answers silently. Read the strip
as "what I have stopped engaging with", a hint not a verdict.

Usage: ctxlab.py <transcript.jsonl>
Cached on transcript size+mtime, so it computes once per turn, not per render.
"""
import json, sys, os, hashlib
from collections import Counter, defaultdict

tx = sys.argv[1] if len(sys.argv) > 1 else ""
if not tx or not os.path.isfile(tx): sys.exit(0)
st = os.stat(tx); key = f"{st.st_size}-{int(st.st_mtime)}"
data = os.environ.get("COCKPIT_DATA") or os.path.expanduser("~/.cursor/cockpit")
os.makedirs(data, exist_ok=True)
h = hashlib.md5(tx.encode()).hexdigest()[:8]
cache = f"{data}/ctxlab.{h}"
try:
    k, body = open(cache).read().split("\n", 1)
    if k == key: print(body, end=""); sys.exit(0)
except Exception: pass

turns = []               # per assistant usage-turn, CURRENT LAP only (reset at each box)
mix = [[0, 0, 0]]        # per lap: [user_prompts, assistant_records, tool_calls]
lap_ts = [[None, None]]  # per lap: [started_at, ended_at] boundary timestamps
seen = set(); cur_files = []; cur_text = []
tool_chars = 0; read_chars = Counter(); reads = Counter(); last_tool_file = None

for line in open(tx, errors="ignore"):
    try: d = json.loads(line)
    except Exception: continue
    if d.get("subtype") == "compact_boundary":
        lap_ts[-1][1] = d.get("timestamp")
        mix.append([0, 0, 0]); lap_ts.append([d.get("timestamp"), None])
        # lap-scoped accumulators start over; the closed lap's mix is already banked
        turns = []; cur_files = []; cur_text = []
        tool_chars = 0; read_chars = Counter(); reads = Counter(); last_tool_file = None
        continue
    if d.get("isSidechain"): continue
    t = d.get("type"); m = d.get("message") or {}; c = m.get("content")
    if t == "user":
        if isinstance(c, str) or (isinstance(c, list) and
                any(isinstance(b, dict) and b.get("type") == "text" for b in c)):
            mix[-1][0] += 1
    elif t == "assistant":
        mix[-1][1] += 1
        if isinstance(c, list):
            mix[-1][2] += sum(1 for b in c if isinstance(b, dict) and b.get("type") == "tool_use")
    if isinstance(c, list):
        for b in c:
            if not isinstance(b, dict): continue
            bt = b.get("type")
            if bt == "tool_use":
                p = (b.get("input") or {}).get("file_path")
                if p: cur_files.append(p); reads[p] += 1; last_tool_file = p
            elif bt == "tool_result":
                s = len(str(b.get("content") or "")); tool_chars += s
                if last_tool_file: read_chars[last_tool_file] += s; last_tool_file = None
            elif bt == "text":
                cur_text.append(b.get("text") or "")
    elif isinstance(c, str):
        cur_text.append(c)
    u = m.get("usage")
    if u and m.get("id") and m["id"] not in seen:
        seen.add(m["id"])
        added = (u.get("input_tokens", 0) + u.get("output_tokens", 0)
                 + u.get("cache_creation_input_tokens", 0))
        turns.append({"added": added, "ctx": u.get("cache_read_input_tokens", 0) + added,
                      "files": list(cur_files), "text": " ".join(cur_text)})
        cur_files = []; cur_text = []

race = [sum(x) for x in zip(*mix)]
if race[1] < 5: sys.exit(0)   # too young a race to say anything
lap_no = len(mix); la = mix[-1]

# --- the mix bar: 12 cells, largest remainder, one glyph per actor ------------
def bar(a, t, u, w=12):
    tot = a + t + u
    if tot == 0: return "·" * w
    want = [a * w / tot, t * w / tot, u * w / tot]
    fl = [int(x) for x in want]
    for i in sorted(range(3), key=lambda i: want[i] - fl[i], reverse=True)[:w - sum(fl)]:
        fl[i] += 1
    return "▰" * fl[0] + "▱" * fl[1] + "▷" * fl[2]

def labels(a, t, u):
    tot = max(1, a + t + u)
    return f"a{100 * a // tot} · t{100 * t // tot} · u{100 * u // tot}"

# --- the lap block: head line, then its detail lines indented under it --------
lines = []
lines.append(f"lap {lap_no:<3} {la[1]:>5}t ▐{bar(la[1], la[2], la[0])}▏ {labels(la[1], la[2], la[0])}")

# dials + ctx strip: THIS LAP, and quiet while the lap is too young
n = len(turns)
if n >= 5:
    ctx = turns[-1]["ctx"] or 1
    old_tok = sum(t["added"] for t in turns[:-50]) if n > 50 else 0
    old_pct = 100 * old_tok / max(1, sum(t["added"] for t in turns))
    dup_tok = sum(read_chars[p] * (reads[p] - 1) / reads[p] for p in reads if reads[p] > 1) / 4
    tool_pct = 100 * (tool_chars / 4) / ctx
    def area(p):
        q = p.split("/"); return "/".join(q[:4]) if len(q) > 4 else p
    recent_reads = [p for t in turns[-40:] for p in t["files"]]
    areas = len(set(area(p) for p in recent_reads))
    lines.append(f" ├ dials areas {areas} · old {old_pct:.0f}% · dup {100 * dup_tok / ctx:.1f}% · tool {tool_pct:.0f}% · files {len(reads)}")

    # liveness strip — 10 segments by cumulative tokens added THIS LAP, oldest left.
    total = sum(t["added"] for t in turns) or 1
    recent_text = (" ".join(t["text"] for t in turns[-20:]) + " "
                   + " ".join(" ".join(t["files"]) for t in turns[-20:]))
    seg_files = defaultdict(set); seg_tok = [0] * 10; first_seen = {}
    acc = 0
    for t in turns:
        seg = min(9, int(10 * acc / total)); acc += t["added"]; seg_tok[seg] += t["added"]
        for p in t["files"]:
            if p not in first_seen: first_seen[p] = seg; seg_files[seg].add(p)
    glyph = []
    for s in range(10):
        fs = seg_files[s]
        if not fs and seg_tok[s] == 0: glyph.append("·"); continue
        hits = sum(1 for p in fs if p in recent_text or os.path.basename(p) in recent_text)
        if s >= 8: glyph.append("█")                 # the most recent fifth is live by definition
        elif fs and hits / len(fs) >= 0.5: glyph.append("▓")
        elif hits: glyph.append("▒")
        else: glyph.append("░")
    live_pct = 100 * sum(seg_tok[s] for s in range(10) if glyph[s] in "█▓") / total
    lines.append(f" └ ctx  {''.join(glyph)}  {ctx // 1000}k · live {live_pct:.0f}% · old→new")

# --- the race block: baseline mix, then compact cadence -----------------------
lines.append(f"race    {race[1]:>5}t ▐{bar(race[1], race[2], race[0])}▏ {labels(race[1], race[2], race[0])}")
closed = [m[1] for m in mix[:-1]]
if closed:
    mx = max(closed) or 1
    spark = "".join("▁▂▃▄▅▆▇█"[min(7, int(8 * c / mx))] for c in closed) + "▏"
    srt = sorted(closed); mid = len(srt) // 2
    med = srt[mid] if len(srt) % 2 else (srt[mid - 1] + srt[mid]) // 2
    r = la[1] / max(1, closed[-1])
    ratio = f"×{r:.0f}" if r >= 10 else (f"×{r:.1f}" if r >= 1 else f"×{r:.2f}")
    lens = "/".join(str(c) for c in closed)
    lines.append(f"stint   {spark} {lens}t · {ratio} of last · median {med}t")
    # the /felt moment: the previous lap just closed and is judgeable
    if la[1] < 5:
        lines.append(f"box     lap {lap_no - 1} closed at {closed[-1]}t · /felt it — rain or planned?")
    # telemetry, not cockpit: closed laps to a file for after the race
    try:
        arch = [{"n": i + 1, "user": m[0], "asst": m[1], "tool": m[2],
                 "started": lap_ts[i][0], "ended": lap_ts[i][1]}
                for i, m in enumerate(mix[:-1])]
        with open(f"{data}/laps.{h}.json", "w") as f:
            json.dump({"transcript": tx, "laps": arch}, f)
    except Exception: pass

out = "\n".join(lines) + "\n"
open(cache, "w").write(key + "\n" + out); print(out, end="")
