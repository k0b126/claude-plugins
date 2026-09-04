---
name: semantic-alignment
description: Change the repo's shared vocabulary without breaking it. Use when a term is being defined or renamed, when prose contradicts the glossary, when a borrowed word needs its tradition and departure stated, or when work is about to introduce vocabulary the glossary does not hold.
---

# Semantic alignment

Refactoring, applied to vocabulary: the concepts stay, only their naming and decomposition change.

**There is no oracle.** *verify* cross-checks the code; *continue* records the diff.

## The contract — read first, stop if absent

`docs/agents/authoring.md` names this repo's glossary, ADR home, and records home. **No contract file → stop and say to run `/setup-anak-skills`.** Never guess the paths.

The rules live in the glossary's own header — read them each run.

## Modes

- **define** — a concept has no term
- **rename** — a term exists and the wrong word is canonical
- **reconcile** — prose and the glossary disagree
- **audit** — a section is read for drift with no term in hand

Every mode walks every station. `rename` is the only one that reaches the sweep.

## The stations

Walk in order; skip none; say which you are at.

**1 · trigger** — say which mode, and what raised it.

**2 · perceive** — gather the raw three, and quote rather than summarise: the passage as written, the glossary entry as written, and **what the code actually does**.

**3 · interpret** — name the concept in one sentence that mentions no word for it. Then find every existing term that could already be it.

**4 · evaluate** — borrow or coin. Search source fields first; borrowing means **quoting the source's own definition**.

**5 · decide** — placement and markers. Constitutive structure goes in the body; merely-current structure goes under a realization marker.

**6 · execute** — write the entry. Definition first, two sentences at most.

**7 · verify** — three checks: **code**, **altitude**, **spread**.

**8 · confirm** — Human Gate; show the entry and verify results; do not answer it yourself.

**9 · continue** — sweep rule-shaped prose if a canonical word changed; write an ADR if the decision is hard to reverse.

## What this skill does not do

It does not rename identifiers. Prose and user-facing strings are this skill's whole surface.

Templates for setup live in `.cursor/authoring/templates/`.
