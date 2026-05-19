#!/bin/bash
set -euo pipefail

# Claude Code Notification hook — enriched toast for multi-instance workflows.
#
# Shows: project name (from cwd), git branch, and notification type.
# Example: "my-project (feat/my-branch) · needs permission"

stdin=$(cat)

cwd=$(echo "$stdin" | jq -r '.cwd // ""')
notification_type=$(echo "$stdin" | jq -r '.notification_type // "idle_prompt"')

# Derive project name from the working directory
project_name=$(basename "$cwd")

# Get current git branch (silently skip if not a git repo or git unavailable)
branch=""
if command -v git &>/dev/null && git -C "$cwd" rev-parse --git-dir &>/dev/null 2>&1; then
  branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" rev-parse --short HEAD 2>/dev/null || true)
fi

# Build context suffix: "project (branch)" or just "project"
if [[ -n "$branch" ]]; then
  context="${project_name} (${branch})"
else
  context="$project_name"
fi

# Map notification_type to a human-readable message
case "$notification_type" in
  idle_prompt)       message="waiting for your input" ;;
  permission_prompt) message="needs your permission" ;;
  auth_success)      message="authentication succeeded" ;;
  elicitation_dialog) message="MCP server needs input" ;;
  *)                 message="needs attention" ;;
esac

# Send notification based on platform
title="Claude Code"
subtitle="$context"

case "$(uname -s)" in
  Darwin)
    if command -v terminal-notifier &>/dev/null; then
      terminal-notifier \
        -title "$title" \
        -subtitle "$subtitle" \
        -message "$message" \
        -ignoreDnD
    elif command -v osascript &>/dev/null; then
      osascript -e "display notification \"$message\" with title \"$title\" subtitle \"$subtitle\""
    fi
    ;;
  Linux)
    if command -v notify-send &>/dev/null; then
      notify-send "$title — $subtitle" "$message"
    fi
    ;;
esac

exit 0
