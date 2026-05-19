# Claude Code Setup

A collection of hooks, scripts, and a statusline for Claude Code that makes working with git worktrees frictionless and keeps Claude's responses sharp.

---

## What's included

| File | Hook / Feature | What it does |
|------|---------------|-------------|
| `scripts/worktree-setup.sh` | `SessionStart` | On worktree open: copies `.env` files from the main repo and runs `install` |
| `scripts/worktree-teardown.sh` | `WorktreeRemove` | On worktree close: runs `git worktree remove --force` to clean up |
| `scripts/notify.sh` | `Notification` | Desktop toast with project name, branch, and what Claude needs |
| `scripts/you_are_not_right.sh` | `UserPromptSubmit` | Detects sycophantic opening lines and injects a reminder to push back |
| `scripts/statusline-command.sh` | `statusLine` | Two-line status bar: model + branch + sync state + PR title + context % |
| `settings.json.template` | — | Drop-in `~/.claude/settings.json` wiring all of the above |

---

## How each piece works

### `worktree-setup.sh`

Fires every time Claude Code starts a session. It reads the `cwd` from the JSON payload Claude passes on stdin and checks whether it's inside a git worktree (not the main checkout). If it is:

1. **Copies `.env` files** — finds every gitignored `.env*` file in the main repo and mirrors it into the worktree. This means you never have to manually copy secrets when starting a new worktree.
2. **Installs dependencies** — detects `pnpm-lock.yaml`, `package-lock.json`, `yarn.lock`, or `Cargo.lock` and runs the appropriate install command. By the time Claude is ready to work, `node_modules` is already there.

Outside a worktree it exits immediately and does nothing.

### `worktree-teardown.sh`

Fires when Claude Code removes a worktree. Runs `git worktree remove --force` on the worktree path so the directory and the git ref are cleaned up without you having to do it manually.

> **Warning:** this is unconditional — uncommitted or unpushed work in the worktree will be lost. The assumption is you push before exiting.

### `notify.sh`

Fires on every `Notification` event (Claude is waiting for input, needs a permission, an MCP server needs auth, etc.). Sends a desktop toast that shows:

```
Claude Code
my-project (feat/my-feature) · waiting for your input
```

- **macOS:** uses `terminal-notifier` if installed, falls back to `osascript`.
- **Linux:** uses `notify-send`.

### `you_are_not_right.sh`

Fires before every prompt you submit. Scans the last 5 assistant turns in the transcript and looks for sycophantic openers ("You're right", "Absolutely", etc.). If it finds one, it appends a `<system-reminder>` to the next prompt that tells Claude to stop agreeing reflexively and provide substantive technical analysis instead.

This keeps Claude from degenerating into a yes-machine over long sessions.

### `statusline-command.sh`

A two-line status bar rendered at the top of every Claude Code session:

```
claude-sonnet-4-6  branch: main ↑2 ~3
87%  feat: add user auth (OPEN)  worktree: feature-branch (feat/auth)
```

Line 1: model name, current branch, sync status (↑ commits ahead, ↓ commits behind), uncommitted file count.
Line 2: context window remaining %, open PR title (color-coded by state), worktree name if in one.

Requires `gh` (GitHub CLI) for the PR info — it gracefully skips that part if `gh` isn't available or there's no PR.

---

## Installation

### 1. Copy the scripts

```bash
mkdir -p ~/.claude/scripts
cp scripts/* ~/.claude/scripts/
cp scripts/statusline-command.sh ~/.claude/statusline-command.sh
chmod +x ~/.claude/scripts/*.sh ~/.claude/statusline-command.sh
```

### 2. Merge the hooks into your settings

If you don't have a `~/.claude/settings.json` yet:

```bash
cp settings.json.template ~/.claude/settings.json
```

If you already have one, merge the `hooks` and `statusLine` blocks from `settings.json.template` into your existing file. The hooks section is additive — existing hooks are not affected.

### 3. Install dependencies

**`jq`** — required by all scripts to parse the JSON Claude passes on stdin:

```bash
# macOS
brew install jq

# Ubuntu / Debian
sudo apt install jq
```

**`terminal-notifier`** — optional, macOS only, for richer notifications:

```bash
brew install terminal-notifier
```

**`gh`** — optional, for PR info in the statusline:

```bash
brew install gh   # then: gh auth login
```

### 4. Restart Claude Code

The hooks and statusline take effect on the next session start. Open Claude Code and run `/status` or check the top bar — you should see the two-line statusline.

---

## Verify it's working

**Worktree hooks:** create a worktree with Claude Code (`/using-git-worktrees` or via the skill), open it, and watch the terminal — you should see `[WORKTREE SETUP] …` lines as deps install and env files copy.

**Notifications:** let Claude finish a task and go idle — you should get a desktop toast.

**you_are_not_right:** agree with Claude on something obviously wrong in a test session and check that subsequent responses avoid "You're right" openers.

**Statusline:** visible at the top of every Claude Code session once configured.

---

## LLM-friendly setup summary

If you are an AI assistant helping someone install this:

1. `mkdir -p ~/.claude/scripts`
2. Copy all `scripts/*.sh` → `~/.claude/scripts/` and `scripts/statusline-command.sh` → `~/.claude/statusline-command.sh`
3. `chmod +x ~/.claude/scripts/*.sh ~/.claude/statusline-command.sh`
4. Copy `settings.json.template` → `~/.claude/settings.json` (or merge `hooks` + `statusLine` keys if the file already exists)
5. `brew install jq` (required) — `brew install terminal-notifier gh` (optional, macOS)
6. Restart Claude Code

Key paths: all scripts live in `~/.claude/scripts/`, statusline in `~/.claude/statusline-command.sh`, settings wired in `~/.claude/settings.json`.
