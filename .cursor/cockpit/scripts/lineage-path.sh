#!/usr/bin/env bash
# Print "develop › anak_dev › … › <branch>" for a branch, from recorded parents.
# Usage: lineage-path.sh <repo-dir> <branch>   (stops after 12 hops or at a cycle)
dir=$1; b=$2; path="$b"; seen=" $b "
for _ in $(seq 1 12); do
  p=$(git -C "$dir" config --get "branch.$b.parent" 2>/dev/null || true)
  [ -z "$p" ] && p=$(git -C "$dir" log --format=%B "$b" 2>/dev/null | sed -n 's/^lineage: parent=\([^ ]*\).*/\1/p' | tail -1)
  [ -z "$p" ] && break
  case "$seen" in *" $p "*) break;; esac
  path="$p › $path"; seen="$seen$p "; b=$p
  [ "$p" = "develop" ] && break
done
printf '%s' "$path"
