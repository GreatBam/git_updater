#!/usr/bin/env bash

set -u

ROOT_DIR="$(cd "${1:-.}" && pwd)"

UPDATED=()
UP_TO_DATE=()
UNPULLED=()

echo "Updating Git repositories under: $ROOT_DIR"
echo

while IFS= read -r gitdir; do
  repo="$(dirname "$gitdir")"

  echo "========================================"
  echo "Repo: $repo"

  cd "$repo" || {
    echo "Cannot enter repo, skipping."
    UNPULLED+=("$repo : cannot enter repo")
    continue
  }

  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Not a valid Git repo, skipping."
    UNPULLED+=("$repo : not a valid Git repo")
    continue
  fi

  branch="$(git branch --show-current)"

  if [[ -z "$branch" ]]; then
    echo "Detached HEAD, skipping."
    UNPULLED+=("$repo : detached HEAD")
    continue
  fi

  if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "Local changes detected, skipping."
    UNPULLED+=("$repo : local changes")
    continue
  fi

  if ! git remote get-url origin >/dev/null 2>&1; then
    echo "No origin remote, skipping."
    UNPULLED+=("$repo : no origin remote")
    continue
  fi

  echo "Current branch: $branch"
  echo "Fetching..."

  if ! git fetch --prune origin; then
    echo "Fetch failed, skipping."
    UNPULLED+=("$repo : fetch failed")
    continue
  fi

  upstream="$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || true)"

  if [[ -z "$upstream" ]]; then
    echo "No upstream configured, skipping."
    UNPULLED+=("$repo : no upstream configured")
    continue
  fi

  local_commit="$(git rev-parse @)"
  remote_commit="$(git rev-parse @{u})"
  base_commit="$(git merge-base @ @{u})"

  if [[ "$local_commit" == "$remote_commit" ]]; then
    echo "Already up to date."
    UP_TO_DATE+=("$repo")
  elif [[ "$local_commit" == "$base_commit" ]]; then
    echo "Fast-forwarding from $upstream..."

    if git pull --ff-only; then
      UPDATED+=("$repo")
    else
      echo "Pull failed."
      UNPULLED+=("$repo : pull failed")
    fi
  elif [[ "$remote_commit" == "$base_commit" ]]; then
    echo "Local branch is ahead of remote, not touching."
    UNPULLED+=("$repo : local branch ahead of remote")
  else
    echo "Branch has diverged, skipping to avoid conflicts."
    UNPULLED+=("$repo : branch diverged")
  fi

  echo
done < <(find "$ROOT_DIR" -type d -name ".git" -prune)

echo
echo "==================== SUMMARY ===================="

echo
echo "Updated: ${#UPDATED[@]}"
if ((${#UPDATED[@]})); then
  printf '  %s\n' "${UPDATED[@]}"
else
  echo "  None"
fi

echo
echo "Already up-to-date: ${#UP_TO_DATE[@]}"
if ((${#UP_TO_DATE[@]})); then
  printf '  %s\n' "${UP_TO_DATE[@]}"
else
  echo "  None"
fi

echo
echo "Need manual attention / not pulled: ${#UNPULLED[@]}"
if ((${#UNPULLED[@]})); then
  printf '  %s\n' "${UNPULLED[@]}"
else
  echo "  None"
fi
