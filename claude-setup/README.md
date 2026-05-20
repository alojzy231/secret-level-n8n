# Claude Code — Worktree Hooks

Two hooks that make git worktrees with Claude Code zero-friction: automatic setup on open, automatic cleanup on close.

---

## What's included

| File | Hook | What it does |
|------|------|-------------|
| `scripts/worktree-setup.sh` | `SessionStart` | On worktree open: copies `.env` files from the main repo and installs dependencies |
| `scripts/worktree-teardown.sh` | `WorktreeRemove` | On worktree close: runs `git worktree remove --force` to clean up |
| `settings.json.template` | — | Drop-in hook config for `~/.claude/settings.json` |

---

## Background: what is a git worktree?

A git worktree is a second (or third, or fourth) checkout of the same repo in a separate directory, each on its own branch. Claude Code uses them to work on a feature in isolation without touching your main working directory.

The problem: every new worktree is a fresh directory — no `node_modules`, no `.env` files. Without these hooks you'd have to manually copy secrets and run `install` every time. These scripts do it automatically.

---

## How the scripts work

### `worktree-setup.sh` — runs on `SessionStart`

When Claude Code opens a session it passes a JSON payload on stdin with the `cwd`. The script checks whether that `cwd` is a worktree (not the main checkout). If it is:

1. **Copies `.env` files** — scans the main repo for every gitignored `.env*` file and mirrors it into the worktree so secrets are available immediately.
2. **Installs dependencies** — detects the lockfile and runs the right installer:
   - `pnpm-lock.yaml` → `pnpm install`
   - `package-lock.json` → `npm install`
   - `yarn.lock` → `yarn install`
   - `Cargo.lock` → `cargo build`

Outside a worktree the script exits immediately — it's a no-op on normal sessions.

### `worktree-teardown.sh` — runs on `WorktreeRemove`

When Claude Code exits a worktree it fires this script, which runs `git worktree remove --force` to delete the directory and deregister the worktree from git.

> **Warning:** this is unconditional. Uncommitted or unpushed work in the worktree will be lost. Push before exiting.

---

## Installation

### 1. Copy the scripts

```bash
mkdir -p ~/.claude/scripts
cp scripts/worktree-setup.sh ~/.claude/scripts/
cp scripts/worktree-teardown.sh ~/.claude/scripts/
chmod +x ~/.claude/scripts/worktree-setup.sh ~/.claude/scripts/worktree-teardown.sh
```

### 2. Add the hooks to your settings

If you don't have a `~/.claude/settings.json` yet:

```bash
cp settings.json.template ~/.claude/settings.json
```

If you already have one, add the `hooks` block from `settings.json.template` into it. Example of what the merged result should look like:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/scripts/worktree-setup.sh",
            "timeout": 300
          }
        ]
      }
    ],
    "WorktreeRemove": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/scripts/worktree-teardown.sh",
            "timeout": 30
          }
        ]
      }
    ]
  }
}
```

### 3. Install `jq`

Both scripts use `jq` to parse the JSON payload Claude passes on stdin.

```bash
# macOS
brew install jq

# Ubuntu / Debian
sudo apt install jq
```

### 4. Restart Claude Code

The hooks take effect on the next session start.

---

## Verify it's working

Create a worktree via Claude Code (use the `using-git-worktrees` skill or ask Claude to create one). When the worktree session opens you should see output like:

```
[WORKTREE SETUP] new worktree: /path/to/worktree
[WORKTREE SETUP] source repo:  /path/to/main-repo
[WORKTREE SETUP] copied .env
[WORKTREE SETUP] installing dependencies with pnpm…
[WORKTREE SETUP] setup complete
```

When you exit the worktree you should see:

```
[WORKTREE TEARDOWN] removing worktree: /path/to/worktree
[WORKTREE TEARDOWN] worktree removed
```

---

## LLM-friendly setup summary

1. `mkdir -p ~/.claude/scripts`
2. Copy `scripts/worktree-setup.sh` and `scripts/worktree-teardown.sh` → `~/.claude/scripts/`
3. `chmod +x ~/.claude/scripts/worktree-setup.sh ~/.claude/scripts/worktree-teardown.sh`
4. Copy `settings.json.template` → `~/.claude/settings.json` (or merge the `hooks` block if the file already exists)
5. `brew install jq` (or `sudo apt install jq` on Linux)
6. Restart Claude Code

Key paths: scripts in `~/.claude/scripts/`, settings in `~/.claude/settings.json`.
