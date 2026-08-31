# Using these plugins in Cursor

This repo ships **Claude Code plugins** under `plugins/` and a **Cursor port** under `.cursor/`. The Cursor port reuses the same ideas — session orientation, context instruments, `/felt` marks, and authoring discipline — using Cursor's native skills and hooks.

## What maps where

| Claude Code | Cursor |
|---|---|
| `plugins/cockpit/skills/*` | `.cursor/skills/cockpit/*` |
| `plugins/authoring/skills/*` | `.cursor/skills/authoring/*` |
| `plugins/cockpit/hooks/hooks.json` | `.cursor/hooks.json` |
| `~/.claude/cockpit` (data) | `~/.cursor/cockpit` |
| `~/.claude/settings.json` → `statusLine` | `~/.cursor/cli-config.json` → `statusLine` |
| `~/.claude/projects/*.jsonl` | `~/.cursor/projects/*/agent-transcripts/*.jsonl` |
| `/cockpit:felt` | `/felt` |
| `/authoring:semantic-refactor` | `/semantic-alignment` |
| `/authoring:setup-anak-skills` | `/setup-anak-skills` |
| `/authoring:shelve` | `/shelve` |

## Install into your repo

**Option A — copy (recommended for teams)**

```bash
# From your project root
cp -r /path/to/claude-plugins/.cursor .
chmod +x .cursor/cockpit/scripts/*.sh .cursor/cockpit/scripts/*.py
```

Commit `.cursor/` so Cloud Agents and teammates get the same skills and hooks.

**Option B — skills only (user machine)**

Copy skill folders into `~/.cursor/skills/` if you want them globally without project hooks:

```bash
cp -r .cursor/skills/cockpit/* ~/.cursor/skills/
cp -r .cursor/skills/authoring/* ~/.cursor/skills/
```

Pick project **or** user skills, not both — duplicates load twice.

## First run

1. **Open the repo in Cursor** — skills are discovered from `.cursor/skills/` automatically.

2. **Trust the workspace** — project hooks in `.cursor/hooks.json` only run in trusted workspaces.

3. **CLI statusline (optional)** — in Agent chat, run `/install-statusline` once, or:

   ```bash
   bash .cursor/cockpit/scripts/install-statusline.sh
   ```

   This writes `statusLine` in `~/.cursor/cli-config.json`. Restart Cursor CLI for it to take effect.

4. **Authoring (optional)** — run `/setup-anak-skills` once per repo before `/semantic-alignment` or `/shelve`.

## Cockpit pieces

| Piece | What it does in Cursor |
|---|---|
| `sessionStart` hook | Prints `[where]` · `[family]`/`[lineage]` · clean/dirty · worktrees into `additional_context` |
| `preCompact` hook | Nudges `/felt` before compaction (`user_message`) |
| `/felt` | Append-only mark (DB-first with file fallback) |
| `/explain` | Token/cache cost derivation |
| `/report` | Session shape + daily trend from `~/.cursor/projects/.../agent-transcripts/` |
| Statusline (CLI) | Seven-line instrument + alarm registers (same JSON stdin as Claude Code) |

Persistent state lives in `~/.cursor/cockpit/` (`felt.log`, `metrics.md`, caches). It survives plugin updates.

## Authoring pieces

| Skill | Purpose |
|---|---|
| `/setup-anak-skills` | Writes `docs/agents/authoring.md` and scaffold paths |
| `/semantic-alignment` | Vocabulary refactor with Human Gate at confirm |
| `/shelve` | Age test + shelf placement with logged runs |

Templates: `.cursor/authoring/templates/`.

## Hooks and conflicts

If your project adds its own `sessionStart` hooks in `.cursor/hooks.json`, cockpit's session-start **stands down** when it detects a non-cockpit hook. To force cockpit orientation anyway:

```bash
export COCKPIT_SESSION_START=force
```

Or merge hook commands manually in `hooks.json`.

## Cloud Agents

These hooks run in Cloud Agents when committed to the repo:

- `sessionStart` — **not** supported in cloud (fires too late; see Cursor docs)
- `preCompact` — supported
- `beforeShellExecution`, `afterFileEdit`, etc. — supported

Skills in `.cursor/skills/` are loaded from the repository on Cloud Agents. User-level `~/.cursor/skills/` is **not** copied to cloud VMs.

## Requirements

- `bash`, `jq`, `python3`, `git`
- Optional: `doppler` + `COCKPIT_DB_URL` for DB-backed `/felt` marks
- Optional: repo `scripts/subtree.sh` or `scripts/family.sh` for branch-family display

## Verify scripts

```bash
bash .cursor/cockpit/scripts/ctxlab-checks.sh
```

## Claude Code vs Cursor

Keep using `plugins/` + `claude plugin install` for Claude Code. Use `.cursor/` for Cursor. Both can live in this repo; they share design but not install paths.
