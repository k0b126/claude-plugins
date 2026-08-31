#!/usr/bin/env bash
# Sourced by every cockpit script. Resolves two directories:
#   COCKPIT_ROOT — this install's script dir (replaced on update)
#   COCKPIT_DATA — persistent state: felt.log, metrics.md, caches.
#                  Defaults to ~/.cursor/cockpit (Cursor port of the Claude plugin).
COCKPIT_ROOT="${COCKPIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
COCKPIT_DATA="${COCKPIT_DATA:-$HOME/.cursor/cockpit}"
mkdir -p "$COCKPIT_DATA" 2>/dev/null && chmod 700 "$COCKPIT_DATA" 2>/dev/null || true
[ -f "$COCKPIT_DATA/metrics.md" ] || cp "$COCKPIT_ROOT/metrics.template.md" "$COCKPIT_DATA/metrics.md" 2>/dev/null
export COCKPIT_ROOT COCKPIT_DATA
