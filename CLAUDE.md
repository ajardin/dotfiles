# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository purpose

Personal macOS dotfiles. Each top-level directory (`claude/`, `git/`, `homebrew/`, `terminal/`) is paired with a `Makefile` target that deploys its contents into the user's home directory, almost always via `ln -sf` symlinks. Editing a tracked file therefore takes effect immediately on the live system once the corresponding `make` target has been run at least once — no copy step.

## Common commands

```bash
make help        # default target — list all targets with descriptions
make claude      # symlink claude/ files into ~/.claude/
make git         # symlink git/ files into ~/ (also touches ~/.gitconfig-corporate)
make homebrew    # install Homebrew if missing, then `brew bundle install` from homebrew/Brewfile
make terminal    # symlink fish config + functions and Warp themes
```

Targets are independent and idempotent (re-running re-creates symlinks). There is no test suite, linter, or CI.

## Deployment model and gotchas

- `git` target creates `~/.gitconfig-corporate` as an empty file via `touch` — this is intentional. `git/.gitconfig` includes it unconditionally and the `includeIf "gitdir:~/Projects/ajardin/"` block then layers `.gitconfig-opensource` on top for repos under that path. The corporate file stays out of the repo so work-specific `user.email` / signing config can live there without leaking.
- `claude` target symlinks `claude/global.md` to `~/.claude/CLAUDE.md` (Claude Code requires that filename in `~/.claude/`) and `claude/RTK.md` into `~/.claude/`. The repo source is named `global.md` to avoid confusion with this per-repo `CLAUDE.md`; `global.md` only contains `@RTK.md`.
- `homebrew` target both installs Homebrew (if absent) **and** runs `brew bundle install` against `homebrew/Brewfile`. `Brewfile.lock.json` is committed and updated by Homebrew on bundle runs.
- `terminal` target globs `terminal/fish/functions/*.fish` and `terminal/warp/themes/*.yaml` — adding a new file in either directory and re-running `make terminal` is enough to wire it up.

## Claude Code integration

`claude/settings.json` is the user's global Claude Code config (symlinked to `~/.claude/settings.json`). Two parts are load-bearing:

- **RTK PreToolUse hook** (`claude/hooks/rtk-rewrite.sh`) intercepts every `Bash` tool call and delegates to `rtk rewrite` to rewrite commands for token-efficient output. The script is a thin shim — all rewrite rules live in the `rtk` Rust binary, not here. Exit codes from `rtk rewrite` (0 allow, 1 passthrough, 2 deny, 3 ask) drive the hook's response. When editing this hook, preserve the exit-code contract documented in its header.
- **Status line** (`claude/statusline.py`) reads JSON from stdin and prints a context-usage bar; thresholds are tuned around the 200k-token auto-compact boundary.

`enabledPlugins` and `extraKnownMarketplaces` in `settings.json` pin the user's plugin set — adding a plugin here is the canonical way to enable it system-wide.

## Conventions for edits

- Keep `Makefile` recipes self-contained and use `${makefile_directory}` (already defined at the top) for absolute paths so targets work regardless of the user's `cwd`.
- Brewfile entries follow the pattern `# <one-line description>` immediately above each `brew`/`cask`. Match this when adding entries.
- Fish functions in `terminal/fish/functions/` follow the one-function-per-file convention required by fish's autoloader; the filename must match the function name.
