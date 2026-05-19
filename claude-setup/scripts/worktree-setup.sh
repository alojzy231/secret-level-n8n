#!/usr/bin/env bash
# Fires on SessionStart. When the session opens inside a git worktree (not the
# main checkout), copies gitignored env files from the main repo and installs
# dependencies based on the detected lockfile. Outside a worktree it's a no-op.
# All output goes to stderr so it reaches the terminal and not Claude's context.

set -uo pipefail

PREFIX="[WORKTREE SETUP]"
log()  { echo "$PREFIX $*" >&2; }
warn() { echo "$PREFIX ⚠  $*" >&2; }

# Claude Code passes a JSON payload on stdin with `cwd` = worktree path.
# Fall back to pwd if stdin is empty or jq fails.
payload=$(cat 2>/dev/null || true)
worktree_root=$(echo "$payload" | jq -r '.cwd // empty' 2>/dev/null || true)
[ -z "$worktree_root" ] && worktree_root=$(pwd)

cd "$worktree_root" 2>/dev/null || { warn "cannot cd into $worktree_root"; exit 0; }

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  exit 0
fi

git_common_dir=$(cd "$(git rev-parse --git-common-dir)" && pwd)
main_repo_root=$(dirname "$git_common_dir")

# If the "worktree" is actually the main checkout, there's nothing to set up.
if [ "$worktree_root" = "$main_repo_root" ]; then
  exit 0
fi

log "new worktree: $worktree_root"
log "source repo:  $main_repo_root"

# --- Copy gitignored env files ---
# `git ls-files --others --ignored --exclude-standard` lists files git ignores
# but which exist locally. That's exactly what env files are. Filter for .env
# patterns and skip .env.example (which is checked in and wouldn't appear anyway).
env_files=$(
  cd "$main_repo_root" && \
  git ls-files --others --ignored --exclude-standard \
    | grep -E '(^|/)\.env(\..+)?$' \
    | grep -vE '\.example$' \
    || true
)

if [ -z "$env_files" ]; then
  log "no env files to copy"
else
  while IFS= read -r file; do
    [ -z "$file" ] && continue
    source_path="$main_repo_root/$file"
    target_path="$worktree_root/$file"
    mkdir -p "$(dirname "$target_path")"
    if cp "$source_path" "$target_path"; then
      log "copied $file"
    else
      warn "failed to copy $file"
    fi
  done <<< "$env_files"
fi

# --- Install dependencies ---
cd "$worktree_root"

if [ -f "pnpm-lock.yaml" ]; then
  log "installing dependencies with pnpm (this takes ~30-60s)…"
  if ! pnpm install >&2; then
    warn "pnpm install failed — run \`pnpm install\` to retry"
  fi
elif [ -f "package-lock.json" ]; then
  log "installing dependencies with npm (this takes ~30-60s)…"
  if ! npm install >&2; then
    warn "npm install failed — run \`npm install\` to retry"
  fi
elif [ -f "yarn.lock" ]; then
  log "installing dependencies with yarn (this takes ~30-60s)…"
  if ! yarn install >&2; then
    warn "yarn install failed — run \`yarn install\` to retry"
  fi
elif [ -f "Cargo.lock" ]; then
  log "building rust project with cargo…"
  if ! cargo build >&2; then
    warn "cargo build failed"
  fi
else
  log "no recognized lockfile — skipping install"
fi

log "setup complete"
