---
name: explain
description: Explain why a turn was expensive, what cache read costs, why context grew, what fresh or cache_read mean, whether to clear or compact, or any question about token cost. Holds the derivation; read current prices from provider docs rather than memory.
disable-model-invocation: true
---

# explain — the cost mechanism

**Do not restate prices from memory.** Multipliers, TTLs, and per-model minimums drift when providers change them. Read current documentation for any number. What follows is the *derivation*, which does not drift.

## The algorithm, in one sentence

A request renders in a fixed order — `tools` → `system` → `messages` — is hashed at each `cache_control` breakpoint, matched against the **longest byte-identical prefix currently alive**, which is served from stored state while everything after it is processed and written. An entry lives on a short TTL from its last write.

Two facts follow, and almost every question reduces to one of them.

## Fact 1 — context is a running total

`cache_read(N) = cache_read(N−1) + cache_new(N−1)`.

Your message, every tool result, and **the model's own output** all join the context and are re-sent on every later turn.

- **Delegating a large read to a subagent** costs the main thread only the returned summary. Break-even is roughly **4 remaining turns**; past that, delegate.
- Under budget pressure, cut **turns and context**, not subagents.

## Fact 2 — the ladder has two rungs

While the prefix is alive a turn costs ~1× whatever the context size. The instant it is not, the next turn costs ~10×.

A prefix dies exactly two ways:

- **Time** — no request within the TTL.
- **Change** — a byte or parameter differs from that position rightward.

**And therefore:** a cold prefix is the *free* moment to compact or clear.

## Answering

Read the question, name which of the two facts it reduces to, and answer from there. When the question is "what did MY session cost", that is `/report`.
