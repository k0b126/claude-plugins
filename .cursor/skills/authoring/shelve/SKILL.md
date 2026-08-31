---
name: shelve
description: Decide what a piece of writing IS and where it goes, by the age test. Use when the user asks "where does this go", "what kind of doc is this", "shelve this", or before placing new agent-facing writing.
---

# Shelve

Two questions, asked of a **passage** — never of a file.

1. **The age test** — *what event would make this untrue?* The answer is the type.
2. **The shelf** — *when must this enter an agent's context?*

## The contract — read first, stop if absent

`docs/agents/authoring.md` names this repo's shelf policy and run log. **No contract file → stop and say to run `/setup-anak-skills`.**

## The stations

| Station | What happens |
|---|---|
| **trigger** | scope and mode |
| **perceive** | split into passages, number them |
| **interpret** | age test per passage: event → type |
| **evaluate** | shelf needed vs shelf on |
| **decide** · **stop** | ambiguous passages go to the person |
| **plan** | moves as destination + pointer |
| **execute** | produce a **diff** — do not write to the tree |
| **verify** | checks, pointers, append-only records |
| **confirm** · **stop** | person approves the diff |
| **continue** | apply if approved; append the run log |

## Modes

| Mode | Trigger | Stops at |
|---|---|---|
| `age` | one passage | after interpret |
| `where` | one passage or file | after plan |
| `audit` | file or folder | after evaluate |

No mode named → `where` for one thing, `audit` for many.

## Rules

- **Passage, not file.**
- **Event before type.**
- **A record is never rewritten.**
- **The shelves come from the policy file.**

Append one entry to the run log every run. `felt` is the person's word at **continue**, never filled by the agent.
