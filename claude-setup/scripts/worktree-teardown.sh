#!/usr/bin/env bash
# Fires on WorktreeRemove. Removes the worktree unconditionally — no safety checks.
# Any uncommitted / unpushed / stashed work will be lost. This is intentional;
# revisit the safety-check story if it starts biting.

set -uo pipefail

PREFIX="[WORKTREE TEARDOWN]"
log()  { echo "$PREFIX $*" >&2; }
warn() { echo "$PREFIX ⚠  $*" >&2; }

payload=$(cat 2>/dev/null || true)
worktree_root=$(echo "$payload" | jq -r '.worktree_path // .cwd // empty' 2>/dev/null || true)
[ -z "$worktree_root" ] && worktree_root=$(pwd)

# If Claude Code already removed the worktree directory, there's nothing to do.
if [ ! -d "$worktree_root" ]; then
  exit 0
fi

cd "$worktree_root" 2>/dev/null || exit 0

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  exit 0
fi

git_common_dir=$(cd "$(git rev-parse --git-common-dir)" && pwd)
main_repo_root=$(dirname "$git_common_dir")

if [ "$worktree_root" = "$main_repo_root" ]; then
  exit 0
fi

log "removing worktree: $worktree_root"
cd "$main_repo_root"
if git worktree remove --force "$worktree_root" >&2; then
  log "worktree removed"
else
  warn "failed to remove worktree — run \`git worktree remove --force $worktree_root\` manually"
fi
