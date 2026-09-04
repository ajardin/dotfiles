# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository purpose

Personal macOS dotfiles. Each top-level directory (`claude/`, `git/`, `homebrew/`, `terminal/`) is paired with a `Makefile` target that deploys its contents into the user's home directory, almost always via `ln -sf` symlinks. Editing a tracked file therefore takes effect immediately on the live system once the corresponding `make` target has been run at least once — no copy step.

## Common commands

```bash
make help        # default target — list all targets with descriptions
make check       # verify every deployed symlink still points back into this repo
make claude      # symlink claude/ files into ~/.claude/
make git         # symlink git/ files into ~/ (also touches ~/.gitconfig-corporate)
make homebrew    # install Homebrew if missing, then `brew bundle install` from homebrew/Brewfile
make skills-sync # re-vendor claude/skills/ from the upstream mattpocock/skills repo
make terminal    # symlink Ghostty config, fish config + functions, and Starship prompt
```

Targets are independent and idempotent (re-running re-creates symlinks). There is no test suite, linter, or CI.

## Deployment model and gotchas

- `git` target creates `~/.gitconfig-corporate` as an empty file via `touch` — this is intentional. `git/.gitconfig` includes it unconditionally and the `includeIf "gitdir:~/Projects/ajardin/"` block then layers `.gitconfig-opensource` on top for repos under that path. The corporate file stays out of the repo so work-specific `user.email` / signing config can live there without leaking.
- `claude` target symlinks `claude/global.md` to `~/.claude/CLAUDE.md` (Claude Code requires that filename in `~/.claude/`) and `claude/RTK.md` into `~/.claude/`. The repo source is named `global.md` to avoid confusion with this per-repo `CLAUDE.md`. It imports `@RTK.md` and then adds two standing bans: never run SQL directly, and never open a credential file (the ban is stated for `Grep`, `Bash` and subagents too, since the `Read` deny rules in `settings.json` only bind one tool).
- `claude` target also symlinks every directory under `claude/skills/` into `~/.claude/skills/`. These are **directory** symlinks, so the recipe uses `ln -sfn` (without `-n`, a second run would nest the new link inside the existing one). Adding a directory there and re-running `make claude` is enough to wire it up; `make check` picks it up through the same glob. `~/.claude/skills/deploy-prep` predates this and is a real directory, untracked and left alone by both targets.
- `skills-sync` target re-vendors `claude/skills/` **verbatim** from `github.com/mattpocock/skills` (the `skills_repo` / `skills_cache` / `skills_list` variables at the top of the `Makefile`). It keeps a blobless clone under `~/.cache/dotfiles/` and `rsync --delete`s the six selected skill directories over the local copies, excluding each skill's `agents/` folder (Codex-specific YAML). The local files are deliberately kept unmodified so `git diff -- claude/skills` after a sync *is* the upstream changelog — do not edit them in place; if a skill needs adapting, fork it under a different name and drop it from `skills_list`. Only these six are vendored (the upstream repo ships 25 via its plugin): the rest either duplicate the user's own skills or assume a GitHub-Issues-first tracker flow.
- `homebrew` target both installs Homebrew (if absent) **and** runs `brew bundle install` against `homebrew/Brewfile`. `Brewfile.lock.json` is written by Homebrew on bundle runs but is listed in `.gitignore` and deliberately not tracked.
- `terminal` target globs `terminal/fish/functions/*.fish` — adding a new file there and re-running `make terminal` is enough to wire it up. The Ghostty (`terminal/ghostty/config.ghostty` → `~/.config/ghostty/`) and Starship (`terminal/starship/starship.toml` → `~/.config/starship.toml`) symlinks are explicit, so a new file in either directory has to be added to the recipe by hand.

## Claude Code integration

`claude/settings.json` is the user's global Claude Code config (symlinked to `~/.claude/settings.json`). Three parts are load-bearing:

- **RTK PreToolUse hook** (`claude/hooks/rtk-rewrite.sh`) intercepts every `Bash` tool call and delegates to `rtk rewrite` to rewrite commands for token-efficient output. The script is a thin shim — all rewrite rules live in the `rtk` Rust binary, not here. Exit codes from `rtk rewrite` (0 allow, 1 passthrough, 2 deny, 3 ask) drive the hook's response. When editing this hook, preserve the exit-code contract documented in its header.
- **Command-history PostToolUse hook** (`claude/hooks/command-history.sh`) appends every executed `Bash` command to a daily JSONL file under `~/.claude/command-history/`, capturing it *after* the RTK rewrite — i.e. as actually executed. It always exits 0 so a logging failure can never disturb a session; preserve that when editing.
- **Status line** (`claude/statusline.py`) reads JSON from stdin and prints a context-usage bar; thresholds are tuned around the 200k-token auto-compact boundary.

`enabledPlugins` and `extraKnownMarketplaces` in `settings.json` pin the user's plugin set — adding a plugin here is the canonical way to enable it system-wide.

## Conventions for edits

- Keep `Makefile` recipes self-contained and use `${makefile_directory}` (already defined at the top) for absolute paths so targets work regardless of the user's `cwd`.
- Brewfile entries follow the pattern `# <one-line description>` immediately above each `brew`/`cask`. Match this when adding entries.
- Fish functions in `terminal/fish/functions/` follow the one-function-per-file convention required by fish's autoloader; the filename must match the function name.
