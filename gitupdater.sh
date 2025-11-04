#!/bin/bash

# Pull all clean Git repos in current folder (one level deep)

set -u          # treat unset vars as errors
shopt -s nullglob

# Find only first-level directories (handles spaces/newlines safely)
while IFS= read -r -d '' dir; do
  echo "→ $dir"

  # Skip if not a git repo
  if ! git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "  (skipped: not a Git repo)"
    continue
  fi

  # Skip if there are local changes (tracked OR untracked)
  if git -C "$dir" status --porcelain | grep -q .; then
    echo "  (skipped: local changes present)"
    continue
  fi

  echo "  clean: pulling…"
  if git -C "$dir" pull --ff-only --prune; then
    echo "  ✓ updated"
  else
    echo "  ✗ pull failed"
  fi

done < <(find . -mindepth 1 -maxdepth 1 -type d -print0)
