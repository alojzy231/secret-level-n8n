#!/usr/bin/env bash

input=$(cat)

RESET="\033[0m"
BOLD="\033[1m"
CYAN="\033[36m"        # model
BLUE="\033[34m"        # branch label
MAGENTA="\033[35m"     # branch name
YELLOW="\033[33m"      # worktree
WHITE="\033[37m"       # bar brackets / separators
# context bar colors (remaining): plenty=cyan, half=blue, low=yellow, critical=red
CTX_PLENTY="\033[36m"
CTX_HALF="\033[34m"
CTX_LOW="\033[33m"
CTX_CRITICAL="\033[31m"
# PR state colors
PR_OPEN="\033[32m"     # green
PR_MERGED="\033[35m"   # magenta
PR_CLOSED="\033[31m"   # red
# Uncommitted changes color
CHANGES="\033[33m"     # yellow

# --- Model ---
model=$(echo "$input" | jq -r '.model.display_name // "Unknown model"')

# --- Context progress bar ---
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
remaining=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')

if [ -n "$remaining" ] && [ -n "$used" ]; then
  remaining_int=${remaining%.*}

  # Pick color based on remaining percentage
  if [ "$remaining_int" -ge 60 ]; then
    bar_color="$CTX_PLENTY"
  elif [ "$remaining_int" -ge 30 ]; then
    bar_color="$CTX_HALF"
  elif [ "$remaining_int" -ge 15 ]; then
    bar_color="$CTX_LOW"
  else
    bar_color="$CTX_CRITICAL"
  fi

  context_str="${bar_color}${remaining_int}%${RESET}"
else
  context_str="${WHITE}--%${RESET}"
fi

# --- Git branch (from cwd in input, avoids lock issues) ---
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
branch=""
if [ -n "$cwd" ]; then
  branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null)
fi

# --- Git sync status (ahead/behind remote) ---
SYNC_AHEAD="\033[32m"   # green  — pushed ahead
SYNC_BEHIND="\033[31m"  # red    — need to pull
sync_str=""
if [ -n "$cwd" ] && [ -n "$branch" ]; then
  # fetch only the remote-tracking ref counts without network I/O
  ahead=$(git -C "$cwd" rev-list --no-walk --count "@{u}..HEAD" 2>/dev/null)
  behind=$(git -C "$cwd" rev-list --no-walk --count "HEAD..@{u}" 2>/dev/null)
  if [ -n "$ahead" ] || [ -n "$behind" ]; then
    if [ "${ahead:-0}" -gt 0 ]; then
      sync_str="${sync_str}${SYNC_AHEAD}↑${ahead}${RESET}"
    fi
    if [ "${behind:-0}" -gt 0 ]; then
      [ -n "$sync_str" ] && sync_str="${sync_str} "
      sync_str="${sync_str}${SYNC_BEHIND}↓${behind}${RESET}"
    fi
  fi
fi

# --- Uncommitted changes count (staged + unstaged + untracked) ---
changes_str=""
if [ -n "$cwd" ]; then
  # --no-optional-locks avoids touching .git/index.lock during reads
  changes_count=$(git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  if [ "${changes_count:-0}" -gt 0 ]; then
    changes_str="${CHANGES}~${changes_count}${RESET}"
  fi
fi

# --- Open PR for current branch ---
pr_str=""
if [ -n "$branch" ]; then
  pr_data=$(gh pr view "$branch" --json title,state --jq '"\(.state)|\(.title)"' 2>/dev/null)
  if [ -n "$pr_data" ]; then
    pr_state=$(echo "$pr_data" | cut -d'|' -f1)
    pr_title=$(echo "$pr_data" | cut -d'|' -f4-)
    if [ "$pr_state" = "OPEN" ]; then
      pr_color="$PR_OPEN"
    elif [ "$pr_state" = "MERGED" ]; then
      pr_color="$PR_MERGED"
    else
      pr_color="$PR_CLOSED"
    fi
    pr_str="${pr_color}${pr_title}${RESET}"
  fi
fi

# --- Worktree ---
worktree_name=$(echo "$input" | jq -r '.worktree.name // empty')
worktree_branch=$(echo "$input" | jq -r '.worktree.branch // empty')
worktree_str=""
if [ -n "$worktree_name" ]; then
  if [ -n "$worktree_branch" ]; then
    worktree_str="${YELLOW}worktree: ${BOLD}${worktree_name}${RESET}${YELLOW} (${worktree_branch})${RESET}"
  else
    worktree_str="${YELLOW}worktree: ${BOLD}${worktree_name}${RESET}"
  fi
fi

# --- Compose lines ---
line1="${CYAN}${model}${RESET}"
if [ -n "$branch" ]; then
  line1="${line1}  ${BLUE}branch:${RESET} ${MAGENTA}${branch}${RESET}"
  if [ -n "$sync_str" ]; then
    line1="${line1} ${sync_str}"
  fi
  if [ -n "$changes_str" ]; then
    line1="${line1} ${changes_str}"
  fi
fi

line2="${context_str}"
if [ -n "$pr_str" ]; then
  line2="${line2}  ${pr_str}"
fi
if [ -n "$worktree_str" ]; then
  line2="${line2}  ${worktree_str}"
fi

printf "%b\n%b\n" "$line1" "$line2"
