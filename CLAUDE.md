# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository purpose

Personal macOS dotfiles. Each top-level directory (`claude/`, `git/`, `homebrew/`, `terminal/`) is paired with a
`Makefile` target that deploys its contents into the user's home directory, almost always via `ln -sf` symlinks.
Editing a tracked file therefore takes effect immediately on the live system once the corresponding `make` target has
been run at least once — no copy step.

## Common commands

```bash
make help        # default target — list all targets with descriptions
make check       # verify every deployed symlink still points back into this repo
make claude      # symlink claude/ files into ~/.claude/
make git         # symlink git/ files into ~/ (also touches ~/.gitconfig-corporate)
make homebrew    # install Homebrew if missing, then `brew bundle install` from homebrew/Brewfile
make rtk-sync    # re-vendor claude/RTK.md from the installed rtk binary
make skills-sync # re-vendor claude/skills/ from the upstream mattpocock/skills repo
make terminal    # symlink Ghostty config, fish config + functions, and Starship prompt
```

Targets are independent and idempotent (re-running re-creates symlinks). There is no test suite, linter, or CI.

## Deployment model and gotchas

- `git` target creates `~/.gitconfig-corporate` as an empty file via `touch` — this is intentional. `git/.gitconfig`
  includes it unconditionally and the `includeIf "gitdir:~/Projects/ajardin/"` block then layers
  `.gitconfig-opensource` on top for repos under that path. The corporate file stays out of the repo so work-specific
  `user.email` / signing config can live there without leaking.
- `claude` target symlinks `claude/global.md` to `~/.claude/CLAUDE.md` (Claude Code requires that filename in
  `~/.claude/`) and `claude/RTK.md` into `~/.claude/`. The repo source is named `global.md` to avoid confusion with
  this per-repo `CLAUDE.md`. It imports `@RTK.md`, then locks replies to English whatever language the user writes in
  (explicitly *not* content written for others — a PR description or a review comment follows its own audience), and
  adds two standing bans: never run SQL directly, and never open a credential file (the ban is stated for `Grep`,
  `Bash` and subagents too, since the `Read` deny rules in `settings.json` only bind one tool). Between the language
  rule and those bans sit four working rules — `Evidence before claims`, `Scope`, `Handoffs`, `Third-party facts` —
  each derived from a logged failure in the May-September 2026 usage reports. `claude/README.md` records which
  incident produced which rule, so read it before reworking one.
- `claude` target refuses to run when any of its destinations in `~/.claude/` exists as a real file or directory
  instead of a symlink, and deploys nothing until it is removed. The symlinks are deliberately the way an outside
  edit becomes visible: a tool writing `~/.claude/settings.json` in place follows the link and lands in this
  repository, where `git diff` catches it. A tool writing it *atomically* (temp file + `rename`) replaces the link
  with a real file instead, and the unguarded `ln -sf` would then overwrite that with no diff to review — which is
  how the `codebase-memory-mcp` hook registrations were lost. The guard covers the same destinations as `check`,
  skills included.
- `claude` target deploys one hook only (`command-history.sh`) and `rm -f`s the stale
  `~/.claude/hooks/rtk-rewrite.sh` left by earlier deployments, since RTK's hook is now the binary's own
  `rtk hook claude` and needs no file. Drop that `rm -f` once no machine still carries the old symlink.
- `claude` target also symlinks every directory under `claude/skills/` into `~/.claude/skills/`. These are
  **directory** symlinks, so the recipe uses `ln -sfn` (without `-n`, a second run would nest the new link inside the
  existing one). Adding a directory there and re-running `make claude` is enough to wire it up; `make check` picks it
  up through the same glob. That glob runs one way only: `check` iterates the repo and asks whether each skill has a
  symlink, so a real directory dropped straight into `~/.claude/skills/` is invisible to it. Such a skill works on that
  machine and exists nowhere else — `ls -la ~/.claude/skills/` is the only way to spot one.
- `claude/skills/` mixes two kinds of skill, and the difference matters when editing. The **vendored** ones are
  exactly those named in the `Makefile`'s `skills_list` (currently the six from `mattpocock/skills`); everything
  else — `squad-env-branch` today — is hand-written and owned here. `squad-env-branch` carries no hardcoded repo,
  org or author: it derives them from `gh` and reads its squad roster from a per-repo
  `.claude/squad-env-branch.json`, asking for it when that file is missing.
- `skills-sync` target re-vendors the `skills_list` directories **verbatim** from `github.com/mattpocock/skills` (see
  the `skills_repo` / `skills_cache` / `skills_list` variables at the top of the `Makefile`). It keeps a blobless
  clone under `~/.cache/dotfiles/` and `rsync --delete`s each selected skill directory over its local copy, excluding
  the skill's `agents/` folder (Codex-specific YAML). Because the rsync is per-skill, directories outside
  `skills_list` are never touched. Vendored files are deliberately kept unmodified so `git diff -- claude/skills`
  after a sync *is* the upstream changelog — do not edit them in place; if a vendored skill needs adapting, fork it
  under a different name and drop the original from `skills_list`. Only a hand-picked subset is vendored — six today,
  out of roughly 37 upstream skills spread across `engineering/`, `productivity/`, `in-progress/`, `misc/` and
  `deprecated/`. The rest either duplicate the user's own skills, assume a GitHub-Issues-first tracker flow, or are
  upstream's own work-in-progress. `skills_list` is the authoritative answer to "what is vendored"; upstream's tree is
  the authoritative answer to "what exists".
- `claude/RTK.md` is **vendored too** (`rtk init --global` slim-mode output) — same discipline as the skills: never
  hand-edit, re-vendor with `make rtk-sync`, read `git diff -- claude/RTK.md` as the changelog. The gotcha: `rtk-sync`
  runs `rtk init` under a **sandboxed `HOME` and `CLAUDE_CONFIG_DIR`** and copies only `RTK.md` out, because a real
  `rtk init --global` also patches `settings.json` and `global.md`, writing *through* symlinks into tracked files.
  Both variables are needed: rtk resolves its target from `CLAUDE_CONFIG_DIR` in preference to `$HOME/.claude`, so
  overriding `HOME` alone leaves the live config exposed on a machine that exports it. Its dangling last line is
  upstream's, kept verbatim on purpose — see `claude/README.md`.
- `homebrew` target both installs Homebrew (if absent) **and** runs `brew bundle install` against
  `homebrew/Brewfile`. `Brewfile.lock.json` is written by Homebrew on bundle runs but is listed in `.gitignore` and
  deliberately not tracked.
- `terminal` target globs `terminal/fish/functions/*.fish` — adding a new file there and re-running `make terminal` is
  enough to wire it up. The Ghostty (`terminal/ghostty/config.ghostty` → `~/.config/ghostty/`) and Starship
  (`terminal/starship/starship.toml` → `~/.config/starship.toml`) symlinks are explicit, so a new file in either
  directory has to be added to the recipe by hand.

## Claude Code integration

`claude/settings.json` is the user's global Claude Code config (symlinked to `~/.claude/settings.json`). Three parts
are load-bearing:

- **RTK PreToolUse hook** — `"command": "rtk hook claude"`, a subcommand of the `rtk` binary; nothing repo-side
  implements it. This is what `rtk init --global` installs on rtk ≥ 0.47. Upstream also ships a shell hook
  (`hooks/claude/rtk-rewrite.sh`) and its `hooks/` docs still describe it — that is the older path, not a reason to
  switch back. It has no "rtk missing → no-op" guard, so it depends on `brew "rtk"` from `make homebrew`. Diagnose
  with `rtk init --show`, `rtk hook check '<cmd>'` and `rtk verify`.
- **Command-history PostToolUse hook** (`claude/hooks/command-history.sh`) appends every executed `Bash` command to a
  daily JSONL file under `~/.claude/command-history/`, capturing it *after* the RTK rewrite — i.e. as actually
  executed. It always exits 0 so a logging failure can never disturb a session; preserve that when editing.
- **Status line** (`claude/statusline.py`) reads the status-line JSON from stdin and prints one `·`-separated line:
  model, effort level, context-usage bar, `5h` / `7d` rate-limit gauges, git branch. Missing data drops a segment and
  any uncaught failure prints the model name alone — a status line that throws leaves the prompt blank, so preserve
  that when editing.

`enabledPlugins` and `extraKnownMarketplaces` in `settings.json` pin the user's plugin set — adding a plugin here is
the canonical way to enable it system-wide.

`claude/README.md` is the long-form rationale for every one of these choices (each `settings.json` key, the
status-line thresholds, why RTK, why each plugin). Read it before changing anything under `claude/`, and update it in
the same commit.

## Conventions for edits

- Keep `Makefile` recipes self-contained and use `${makefile_directory}` (already defined at the top) for absolute
  paths so targets work regardless of the user's `cwd`.
- Brewfile entries follow the pattern `# <one-line description>` immediately above each `brew`/`cask`. Match this when
  adding entries.
- Fish functions in `terminal/fish/functions/` follow the one-function-per-file convention required by fish's
  autoloader; the filename must match the function name.
- Every Markdown file wraps at 120 columns.
- Commit messages are a single imperative sentence in sentence case, no body, no prefix or scope tag ("Vendor upstream
  Claude skills and add a sync target"). No attribution trailer: `attribution` in `settings.json` is emptied on
  purpose, so strip any `Co-Authored-By` or session footer a tool tries to append.
