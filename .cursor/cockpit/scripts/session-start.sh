#!/usr/bin/env bash
# sessionStart hook — orient the session before work begins (Cursor port).
#
# Cursor hook output: additional_context (agent) + env (session-scoped vars).
# Common stdin fields: workspace_roots[], transcript_path, conversation_id.
set -uo pipefail
. "$(dirname "$0")/lib.sh"
input=$(cat 2>/dev/null || true)

txp=$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)
[ -z "$txp" ] && txp="${CURSOR_TRANSCRIPT_PATH:-}"

OUT=""
say(){ OUT="$OUT$*"$'\n'; }

cwd=$(printf '%s' "$input" | jq -r '.workspace_roots[0] // empty' 2>/dev/null)
[ -z "$cwd" ] && cwd="${CURSOR_PROJECT_DIR:-$PWD}"

git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  jq -nc --arg t "[where] $cwd — not a git repository" '{additional_context:$t}'
  exit 0
}

root=$(git -C "$cwd" rev-parse --show-toplevel)
branch=$(git -C "$cwd" branch --show-current)
[ -z "$branch" ] && branch="detached @ $(git -C "$cwd" rev-parse --short HEAD)"

# Stand down when the project registers its own sessionStart beyond this install.
# Set COCKPIT_SESSION_START=force to always run.
if [ "${COCKPIT_SESSION_START:-}" != "force" ] && [ -f "$root/.cursor/hooks.json" ] && command -v jq >/dev/null 2>&1; then
  ours=$(readlink -f "$COCKPIT_ROOT/scripts/session-start.sh" 2>/dev/null || realpath "$COCKPIT_ROOT/scripts/session-start.sh" 2>/dev/null || echo "")
  while IFS= read -r cmd; do
    [ -z "$cmd" ] && continue
  case "$cmd" in
    *session-start.sh*) continue ;;
  esac
    [ -n "$cmd" ] && exit 0
  done < <(jq -r '.hooks.sessionStart[]?.command // empty' "$root/.cursor/hooks.json" 2>/dev/null)
fi

case "$root" in
  */.cursor/worktrees/*|*/.claude/worktrees/*) name="${root##*/worktrees/}"; where="worktree ⑂ $name";;
  *) where="MAIN CHECKOUT";;
esac

ab=$(git -C "$cwd" rev-list --left-right --count "@{upstream}...HEAD" 2>/dev/null | awk '{printf "behind %s · ahead %s", $1, $2}')
mod=$(git -C "$cwd" status --porcelain --untracked-files=no | wc -l | tr -d ' ')
unt=$(git -C "$cwd" status --porcelain --untracked-files=all | grep -c '^??' || true)
say "[where] $where · branch $branch${ab:+ · $ab} · $root"

if [ -x "$root/scripts/subtree.sh" ] && [ -n "$branch" ] && [ "${branch#detached}" = "$branch" ]; then
  fam=$(cd "$root" && timeout 6 scripts/subtree.sh "$branch" --window 2 --hook 2>/dev/null) || fam="[family] subtree.sh failed — run subtree script manually"
  say "$fam"
else
  path=$("$COCKPIT_ROOT/scripts/lineage-path.sh" "$cwd" "$branch" 2>/dev/null)
  if [ -n "$path" ] && [ "$path" != "$branch" ]; then
    parent=$(git -C "$cwd" config --get "branch.$branch.parent" 2>/dev/null || true)
    say "[lineage] $path · merges from/into: ${parent:-(none recorded)}"
  else
    say "[lineage] no recorded parent for $branch — record one: git config branch.$branch.parent <parent>"
  fi
fi

if [ "$mod" != 0 ]; then
  say "[dirty] $mod tracked file(s) modified (first 5):"
  say "$(git -C "$cwd" status --porcelain --untracked-files=no | head -5 | sed 's/^/        /')"
  say "        These may belong to ANOTHER session sharing this checkout. Never blanket-stash; move by path."
else
  say "[clean] no tracked changes${unt:+ · $unt untracked}"
fi

say "[worktrees]"
while read -r p h b; do
  mark=" "; [ "$p" = "$root" ] && mark="▶"
  say "$(printf '  %s %-62s %s %s' "$mark" "$p" "$h" "$b")"
done < <(git -C "$cwd" worktree list)

if command -v jq >/dev/null 2>&1; then
  if [ -n "$txp" ]; then
    jq -nc --arg t "$OUT" --arg tx "$txp" '{additional_context:$t, env:{COCKPIT_TRANSCRIPT:$tx}}'
  else
    jq -nc --arg t "$OUT" '{additional_context:$t}'
  fi
else
  printf '%s' "$OUT"
fi
