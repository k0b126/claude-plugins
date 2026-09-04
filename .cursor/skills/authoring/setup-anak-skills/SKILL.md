---
name: setup-anak-skills
description: Write the per-repo contract that semantic-alignment and shelve read. Run once per repo, before first use of either.
disable-model-invocation: true
---

# Setup

Scaffold the configuration the authoring skills assume. Prompt-driven: explore, present, confirm, then write.

## 1. Explore

Read what exists; assume nothing:

- `docs/agents/authoring.md` — prior run? If present, show it and offer to amend.
- A glossary: `CONTEXT.md` at root, or anything `AGENTS.md` / `.cursor/rules` names as shared language.
- `docs/adr/`, `docs/record/` — or where this repo keeps decisions and records.
- `docs/agents/storage.md` — a shelf policy may already exist.

## 2. Present and ask

One section, one answer, defaults first:

- **Glossary** — default `CONTEXT.md`, from `.cursor/authoring/templates/glossary-header.md` if absent.
- **ADR home** — default `docs/adr/`.
- **Records home** — default `docs/record/`.
- **Shelve policy + run log** — default `docs/agents/storage.md` from `.cursor/authoring/templates/storage.md` and `docs/record/shelve-runs.md`.

## 3. Write

Write `docs/agents/authoring.md` recording the four paths and the date, then any template files the answers call for. Show every file written.

Done when: `docs/agents/authoring.md` exists, every path in it resolves, and the glossary carries the marker-rules header.

Use `.cursor/authoring/templates/authoring.md` as the contract skeleton.
