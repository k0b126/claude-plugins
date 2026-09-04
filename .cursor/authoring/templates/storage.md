# Where agent-facing writing goes

A standing rule. It decides where any artifact written for agents is stored,
by two questions an agent can answer alone.

## 1. The age test: what would make this untrue?

Classify a piece of writing by the event that would falsify it, never by what
it calls itself.

| If the answer is… | it is a… | and is stale when… |
|---|---|---|
| nothing — it could only have been *wrong* on the day it was written | **record** | never; corrected only by appending |
| the product moving underneath it, silently | **rule** | the check beside it goes red — or no check exists |
| the next person running it and it failing | **procedure** | someone runs it and it fails |
| someone deciding they prefer otherwise | **preference** | it is reversed out loud |
| the branch merging | **working note** | the branch is gone |
| its condition being met — or the decision it guards being superseded | **tripwire** | never; it becomes a record of what fired |

The type fixes the maintenance regime: a record is append-only and dated; a
rule is short and sits beside the check that enforces it (a rule with no
check is a record wearing a rule's clothes); a procedure is kept alive by use.

## 2. The shelf: when does it enter an agent's context?

| Enters context… | Type | Lives in |
|---|---|---|
| **every session, unasked** | rule · front door | {always-loaded file, e.g. CLAUDE.md / AGENTS.md} |
| **when invoked by name** | procedure | {skills dir · scripts dir} |
| **when searched or linked** | record | {issue tracker · ADR home · records home · module headers} |
| **when the reader chooses a style** | preference | {preferences home} |
| **only this branch** | working note | the PR description · an issue comment |
| **once, then by link** | one-off report | a published artifact, its URL pasted into the record that needed it |
| **when its observer looks** | tripwire | a check script, a hook, a schedule, or a tracked tripwire issue |

A passage on a costlier shelf than its type needs is the waste the age test
exists to find.
